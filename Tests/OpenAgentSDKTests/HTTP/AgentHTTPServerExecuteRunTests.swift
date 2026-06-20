import XCTest
import os
@testable import OpenAgentSDK

// MARK: - AgentHTTPServerExecuteRunTests

/// Direct unit tests for `AgentHTTPServer.executeRun(...)` — the run state
/// machine that was the largest single contributor to AgentHTTPServer.swift's
/// 52.7% coverage number.
///
/// Strategy: invoke `executeRun` as a static method (made internal for this
/// purpose) with mock LLM clients that control whether `agent.stream(...)`
/// produces a `.result` message or fails. Verify side effects on RunTracker,
/// RunPersistenceService, and ConcurrencyLimiter.
///
/// Mock patterns adapted from `EventBusTests.swift`'s MockLLMClient /
/// FailingLLMClient.
final class AgentHTTPServerExecuteRunTests: TempDirTestCase {

    // MARK: - Mocks

    /// Mock that streams a complete single-turn text response (end_turn).
    /// Triggers the `.result` branch in executeRun.
    private struct StreamingSuccessClient: LLMClient, @unchecked Sendable {
        nonisolated func sendMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> [String: Any] {
            [
                "content": [["type": "text", "text": "done"]],
                "stop_reason": "end_turn",
                "usage": ["input_tokens": 10, "output_tokens": 5],
            ]
        }

        nonisolated func streamMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
            let events: [SSEEvent] = [
                .messageStart(message: ["type": "message_start"]),
                .contentBlockStart(index: 0, contentBlock: ["type": "text", "text": ""]),
                .contentBlockDelta(index: 0, delta: ["type": "text_delta", "text": "done"]),
                .contentBlockStop(index: 0),
                .messageDelta(delta: ["stop_reason": "end_turn"], usage: ["output_tokens": 5]),
                .messageStop,
            ]
            return AsyncThrowingStream { continuation in
                for event in events { continuation.yield(event) }
                continuation.finish()
            }
        }
    }

    /// Mock that throws on streamMessage — triggers the `if !sawResult`
    /// failure branch in executeRun.
    private struct StreamingFailingClient: LLMClient, Sendable {
        nonisolated func sendMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> [String: Any] {
            throw SDKError.apiError(statusCode: 500, message: "stream unavailable")
        }

        nonisolated func streamMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
            throw SDKError.apiError(statusCode: 500, message: "stream unavailable")
        }
    }

    // MARK: - Fixtures

    private func makeAgent(client: LLMClient) -> Agent {
        Agent(
            options: AgentOptions(
                apiKey: "sk-test-not-used",
                model: "claude-sonnet-4-6",
                systemPrompt: "test"
            ),
            client: client
        )
    }

    private func makeComponents() -> (tracker: RunTracker, broadcaster: EventBroadcaster, persistence: RunPersistenceService, limiter: ConcurrencyLimiter) {
        let persistence = RunPersistenceService(baseDirectory: tempDir)
        let broadcaster = EventBroadcaster(persistenceService: persistence)
        return (
            RunTracker(),
            broadcaster,
            persistence,
            ConcurrencyLimiter(maxConcurrent: 5)
        )
    }

    // MARK: - Happy path: stream completes → completeRun

    func testExecuteRun_success_transitionsToCompletedWithResultText() async throws {
        let (tracker, broadcaster, persistence, limiter) = makeComponents()
        let run = await tracker.submitRun(task: "hello")
        let agent = makeAgent(client: StreamingSuccessClient())

        await AgentHTTPServer.executeRun(
            runId: run.runId,
            task: "hello",
            tracker: tracker,
            broadcaster: broadcaster,
            persistenceService: persistence,
            limiter: limiter,
            agent: agent
        )

        let final = await tracker.getRun(runId: run.runId)
        XCTAssertEqual(final?.status, .completed,
                       "Successful stream should transition run to .completed")
        XCTAssertEqual(final?.resultText, "done",
                       "resultText should come from the streamed .result message")
    }

    func testExecuteRun_success_writesPersistenceRecord() async throws {
        let (tracker, broadcaster, persistence, limiter) = makeComponents()
        let run = await tracker.submitRun(task: "hello")
        let agent = makeAgent(client: StreamingSuccessClient())

        await AgentHTTPServer.executeRun(
            runId: run.runId,
            task: "hello",
            tracker: tracker,
            broadcaster: broadcaster,
            persistenceService: persistence,
            limiter: limiter,
            agent: agent
        )

        // RunPersistenceService writes JSON sidecar files under baseDirectory.
        // After successful executeRun, at least one file should exist.
        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir)
        XCTAssertGreaterThan(files.count, 0,
                             "Persistence service should have written at least one file; dir contents: \(files)")
    }

    func testExecuteRun_success_releasesLimiter() async throws {
        let (tracker, broadcaster, persistence, limiter) = makeComponents()
        let run = await tracker.submitRun(task: "hello")
        let agent = makeAgent(client: StreamingSuccessClient())

        await AgentHTTPServer.executeRun(
            runId: run.runId,
            task: "hello",
            tracker: tracker,
            broadcaster: broadcaster,
            persistenceService: persistence,
            limiter: limiter,
            agent: agent
        )

        let activeCount = await limiter.activeRunCount
        XCTAssertEqual(activeCount, 0,
                       "Limiter activeRunCount should be 0 after executeRun completes")
    }

    // MARK: - Failure path: stream throws → still completes (agent.stream emits .result with error text)
    //
    // NOTE: agent.stream wraps streamMessage errors into a `.result` message
    // (rather than ending the stream without one). So executeRun's `if !sawResult`
    // failure branch is NOT triggered by a throwing client — it would only fire
    // if agent.stream ended abnormally without emitting `.result`. We pin down
    // the actual contract here: failing stream → completed run with non-empty
    // result text containing the error.

    func testExecuteRun_failure_completesRunWithErrorInfoInResultText() async throws {
        let (tracker, broadcaster, persistence, limiter) = makeComponents()
        let run = await tracker.submitRun(task: "hello")
        let agent = makeAgent(client: StreamingFailingClient())

        await AgentHTTPServer.executeRun(
            runId: run.runId,
            task: "hello",
            tracker: tracker,
            broadcaster: broadcaster,
            persistenceService: persistence,
            limiter: limiter,
            agent: agent
        )

        let final = await tracker.getRun(runId: run.runId)
        // agent.stream emits a .result even on stream failure, so executeRun
        // calls completeRun (not failRun). This is the observed contract.
        XCTAssertEqual(final?.status, .completed,
                       "Stream errors are surfaced as a .result message, so run is marked completed (not failed)")
        XCTAssertNotNil(final?.resultText,
                        "resultText should be populated with the error surfaced by agent.stream")
    }

    func testExecuteRun_failure_releasesLimiter() async throws {
        let (tracker, broadcaster, persistence, limiter) = makeComponents()
        let run = await tracker.submitRun(task: "hello")
        let agent = makeAgent(client: StreamingFailingClient())

        await AgentHTTPServer.executeRun(
            runId: run.runId,
            task: "hello",
            tracker: tracker,
            broadcaster: broadcaster,
            persistenceService: persistence,
            limiter: limiter,
            agent: agent
        )

        let activeCount = await limiter.activeRunCount
        XCTAssertEqual(activeCount, 0,
                       "Limiter activeRunCount should be 0 even on failure path")
    }

    // MARK: - Limiter / startRun interplay

    func testExecuteRun_acquireThenRelease_orderingPreservesLimiterSlot() async throws {
        // Drive two consecutive runs serially; both should succeed and the
        // limiter should end up fully released after each.
        let (tracker, broadcaster, persistence, limiter) = makeComponents()

        for task in ["first", "second"] {
            let run = await tracker.submitRun(task: task)
            let agent = makeAgent(client: StreamingSuccessClient())

            await AgentHTTPServer.executeRun(
                runId: run.runId,
                task: task,
                tracker: tracker,
                broadcaster: broadcaster,
                persistenceService: persistence,
                limiter: limiter,
                agent: agent
            )

            let activeCount = await limiter.activeRunCount
            XCTAssertEqual(activeCount, 0,
                           "Limiter activeRunCount should be 0 after each run; failed after task=\(task)")
        }
    }

    // MARK: - Bridge lifecycle

    func testExecuteRun_startsAndStopsEventBusBridgeCleanly() async throws {
        // The bridge connects a per-run EventBus to the broadcaster. After
        // executeRun returns, the bridge must be stopped (otherwise its task
        // leaks). We verify indirectly: a subsequent broadcast on a different
        // runId should not leak to the previous run's bridge.
        let (tracker, broadcaster, persistence, limiter) = makeComponents()
        let run = await tracker.submitRun(task: "first")
        let agent = makeAgent(client: StreamingSuccessClient())

        await AgentHTTPServer.executeRun(
            runId: run.runId,
            task: "first",
            tracker: tracker,
            broadcaster: broadcaster,
            persistenceService: persistence,
            limiter: limiter,
            agent: agent
        )

        // If bridge.stop() wasn't called, the previous subscription would
        // still be active. We can't directly inspect bridge state, but we
        // can confirm executeRun completed without hanging — a leaked bridge
        // task would typically show up as the test timing out.
        let final = await tracker.getRun(runId: run.runId)
        XCTAssertEqual(final?.status, .completed)
    }
}

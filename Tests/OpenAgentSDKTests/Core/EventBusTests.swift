import XCTest
@testable import OpenAgentSDK
import _Concurrency

final class EventBusTests: XCTestCase {

    // MARK: - AC1: publish broadcasts to all subscribers

    func testPublishBroadcastsToAllSubscribers() async {
        let bus = EventBus()
        let stream1 = await bus.subscribe().stream
        let stream2 = await bus.subscribe().stream
        let stream3 = await bus.subscribe().stream

        let event = AgentStartedEvent(sessionId: "s1", task: "test")
        await bus.publish(event)

        var received1: AgentStartedEvent?
        var received2: AgentStartedEvent?
        var received3: AgentStartedEvent?

        for await e in stream1 {
            if let typed = e as? AgentStartedEvent { received1 = typed; break }
        }
        for await e in stream2 {
            if let typed = e as? AgentStartedEvent { received2 = typed; break }
        }
        for await e in stream3 {
            if let typed = e as? AgentStartedEvent { received3 = typed; break }
        }

        XCTAssertNotNil(received1)
        XCTAssertNotNil(received2)
        XCTAssertNotNil(received3)
        XCTAssertEqual(received1?.task, "test")
        XCTAssertEqual(received2?.task, "test")
        XCTAssertEqual(received3?.task, "test")
    }

    // MARK: - AC2: slow subscriber does not block publisher

    func testSlowSubscriberDoesNotBlockPublisher() async {
        let bus = EventBus()
        let _ = await bus.subscribe().stream

        // Publish 200 events rapidly — should not hang even though nobody consumes.
        for i in 0..<200 {
            await bus.publish(AgentStartedEvent(sessionId: "s", task: "task-\(i)"))
        }

        // If we reach here, publish was not blocked.
        XCTAssertTrue(true)
    }

    func testBufferDropsOldestWhenFull() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        // Publish 200 events before consuming any.
        for i in 0..<200 {
            await bus.publish(AgentStartedEvent(sessionId: "s", task: "task-\(i)"))
        }

        // Give the stream time to process buffered items.
        await _Concurrency.Task.yield()

        var collected: [String] = []
        for await event in stream {
            if let typed = event as? AgentStartedEvent {
                collected.append(typed.task)
            }
            if collected.count >= 100 { break }
        }

        // Buffer should contain the latest 100 (task-100 through task-199).
        XCTAssertEqual(collected.count, 100)
        XCTAssertEqual(collected.first, "task-100")
        XCTAssertEqual(collected.last, "task-199")
    }

    // MARK: - AC3: type-filtered subscribe

    func testTypeFilteredSubscribe() async {
        let bus = EventBus()
        let stream = await bus.subscribe(ToolStartedEvent.self)

        await bus.publish(AgentStartedEvent(sessionId: "s", task: "ignored"))
        await bus.publish(ToolStartedEvent(sessionId: "s", toolName: "bash", toolUseId: "tu1", input: nil))

        var received: ToolStartedEvent?
        for await event in stream {
            received = event
            break
        }

        XCTAssertNotNil(received)
        XCTAssertEqual(received?.toolName, "bash")
    }

    // MARK: - AC4: unsubscribe removes subscriber

    func testUnsubscribeRemovesSubscriber() async throws {
        let bus = EventBus()
        let (id, stream) = await bus.subscribe()

        // Publish one event to verify stream works.
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "before"))
        var count = 0
        for await _ in stream {
            count += 1
            if count == 1 { break }
        }
        XCTAssertEqual(count, 1)

        // Unsubscribe.
        await bus.unsubscribe(id)

        // Publish again — stream should not deliver.
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "after"))

        // The stream's continuation should have been finished, so iteration ends.
        var afterCount = 0
        for await _ in stream {
            afterCount += 1
        }
        XCTAssertEqual(afterCount, 0)
    }

    // MARK: - AC5: publish with no subscribers does not crash

    func testPublishWithNoSubscribers() async {
        let bus = EventBus()
        // Should not crash or assert.
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "nobody"))
        XCTAssertTrue(true)
    }

    // MARK: - AC7: actor isolation verification

    func testEventBusIsActor() async {
        let bus = EventBus()
        // Accessing actor methods from concurrent tasks should be safe.
        async let s1 = bus.subscribe()
        async let s2 = bus.subscribe()
        let (sub1, sub2) = await (s1, s2)

        await bus.publish(AgentStartedEvent(sessionId: "s", task: "a"))
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "b"))

        // Both subscribers should get both events.
        var events1: [String] = []
        for await e in sub1.stream {
            if let t = e as? AgentStartedEvent { events1.append(t.task) }
            if events1.count == 2 { break }
        }

        var events2: [String] = []
        for await e in sub2.stream {
            if let t = e as? AgentStartedEvent { events2.append(t.task) }
            if events2.count == 2 { break }
        }

        XCTAssertEqual(events1.sorted(), ["a", "b"])
        XCTAssertEqual(events2.sorted(), ["a", "b"])
    }

    // MARK: - Order guarantee

    func testPublishOrderPreserved() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let events = (0..<50).map { i in AgentStartedEvent(sessionId: "s", task: "t\(i)") }
        for event in events {
            await bus.publish(event)
        }

        var collected: [String] = []
        for await e in stream {
            if let t = e as? AgentStartedEvent { collected.append(t.task) }
            if collected.count == 50 { break }
        }

        let expected = (0..<50).map { "t\($0)" }
        XCTAssertEqual(collected, expected)
    }

    // MARK: - Multiple type-filtered subscribers coexist

    func testMultipleTypeFilteredSubscribers() async {
        let bus = EventBus()
        let toolStream = await bus.subscribe(ToolStartedEvent.self)
        let agentStream = await bus.subscribe(AgentCompletedEvent.self)

        await bus.publish(ToolStartedEvent(sessionId: "s", toolName: "bash", toolUseId: "tu1", input: nil))
        await bus.publish(AgentCompletedEvent(sessionId: "s", totalSteps: 3, durationMs: 100, resultText: "done"))
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "ignored-by-both"))

        var toolEvent: ToolStartedEvent?
        var agentEvent: AgentCompletedEvent?

        for await e in toolStream { toolEvent = e; break }
        for await e in agentStream { agentEvent = e; break }

        XCTAssertNotNil(toolEvent)
        XCTAssertEqual(toolEvent?.toolName, "bash")
        XCTAssertNotNil(agentEvent)
        XCTAssertEqual(agentEvent?.totalSteps, 3)
    }

    // MARK: - Publish multiple event types

    func testPublishMultipleEventTypes() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        await bus.publish(SessionCreatedEvent(sessionId: "s", task: "t", model: "m"))
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "t"))
        await bus.publish(ToolCompletedEvent(sessionId: "s", toolUseId: "tu", toolName: "bash", durationMs: 50, isError: false))
        await bus.publish(LLMCostEvent(sessionId: "s", model: "m", inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.001))

        var collected: [String] = []
        for await e in stream {
            collected.append(String(describing: type(of: e)))
            if collected.count == 4 { break }
        }

        XCTAssertEqual(collected.count, 4)
    }

    // MARK: - onTermination auto-cleanup

    func testOnTerminationAutoCleanup() async {
        let bus = EventBus()

        // Subscribe in a scope so the stream deinitializes.
        do {
            let (_, stream) = await bus.subscribe()
            // Consume one event to verify the stream works.
            await bus.publish(AgentStartedEvent(sessionId: "s", task: "before"))
            for await e in stream {
                _ = e
                break
            }
            // stream goes out of scope here → onTermination fires
        }

        // Give onTermination time to run its cleanup Task.
        await _Concurrency.Task.yield()
        await _Concurrency.Task.yield()
        await _Concurrency.Task.yield()

        // Publish after cleanup — should not crash.
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "after"))
        XCTAssertTrue(true)
    }

    // MARK: - Agent Lifecycle Event Emit Tests

    /// Mock LLM client that returns a simple end_turn response.
    private struct MockLLMClient: LLMClient, @unchecked Sendable {
        let response: [String: Any]

        init(response: [String: Any]? = nil) {
            self.response = response ?? [
                "content": [["type": "text", "text": "done"]],
                "stop_reason": "end_turn",
                "usage": ["input_tokens": 10, "output_tokens": 5],
            ]
        }

        nonisolated func sendMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> [String: Any] {
            return response
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

    /// Mock LLM client that always throws an error.
    private struct FailingLLMClient: LLMClient, Sendable {
        nonisolated func sendMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> [String: Any] {
            throw SDKError.apiError(statusCode: 500, message: "API error")
        }

        nonisolated func streamMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
            throw SDKError.apiError(statusCode: 500, message: "API error")
        }
    }

    private func makeAgentWithEventBus(eventBus: EventBus) -> Agent {
        Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                eventBus: eventBus
            ),
            client: MockLLMClient()
        )
    }

    // AC1 + AC2: prompt() emits AgentStartedEvent + AgentCompletedEvent
    func testPromptEmitsStartedAndCompletedEvents() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let agent = makeAgentWithEventBus(eventBus: bus)

        _ = await agent.prompt("hello")

        var collected: [any AgentEvent] = []
        for await event in stream {
            collected.append(event)
            if collected.count >= 2 { break }
        }

        XCTAssertEqual(collected.count, 2)
        XCTAssertTrue(collected[0] is AgentStartedEvent)
        XCTAssertTrue(collected[1] is AgentCompletedEvent)

        let started = collected[0] as! AgentStartedEvent
        XCTAssertEqual(started.task, "hello")

        let completed = collected[1] as! AgentCompletedEvent
        XCTAssertEqual(completed.totalSteps, 1)
        XCTAssertGreaterThanOrEqual(completed.durationMs, 0)
        XCTAssertEqual(completed.resultText, "done")
    }

    // AC3: prompt() emits AgentFailedEvent on API error
    func testPromptEmitsFailedEventOnError() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                eventBus: bus
            ),
            client: FailingLLMClient()
        )

        _ = await agent.prompt("hello")

        var collected: [any AgentEvent] = []
        for await event in stream {
            collected.append(event)
            if collected.count >= 2 { break }
        }

        XCTAssertTrue(collected[0] is AgentStartedEvent)
        XCTAssertTrue(collected[1] is AgentFailedEvent)

        let failed = collected[1] as! AgentFailedEvent
        XCTAssertTrue(failed.error.contains("API error"))
        XCTAssertEqual(failed.stepsCompleted, 0)
    }

    // AC1 + AC2: stream() emits AgentStartedEvent + AgentCompletedEvent
    func testStreamEmitsStartedAndCompletedEvents() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let agent = makeAgentWithEventBus(eventBus: bus)

        let messageStream = agent.stream("hello")
        // Consume the stream to drive it to completion
        for await _ in messageStream {}

        var collected: [any AgentEvent] = []
        for await event in stream {
            collected.append(event)
            if collected.count >= 2 { break }
        }

        XCTAssertEqual(collected.count, 2)
        XCTAssertTrue(collected[0] is AgentStartedEvent)
        XCTAssertTrue(collected[1] is AgentCompletedEvent)

        let started = collected[0] as! AgentStartedEvent
        XCTAssertEqual(started.task, "hello")

        let completed = collected[1] as! AgentCompletedEvent
        XCTAssertGreaterThanOrEqual(completed.totalSteps, 1)
        XCTAssertGreaterThanOrEqual(completed.durationMs, 0)
    }

    // AC3: stream() emits AgentFailedEvent on API error
    func testStreamEmitsFailedEventOnError() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                eventBus: bus
            ),
            client: FailingLLMClient()
        )

        let messageStream = agent.stream("hello")
        for await _ in messageStream {}

        var collected: [any AgentEvent] = []
        for await event in stream {
            collected.append(event)
            if collected.count >= 2 { break }
        }

        XCTAssertTrue(collected[0] is AgentStartedEvent)
        XCTAssertTrue(collected[1] is AgentFailedEvent)
    }

    // AC7: promptImpl path emits lifecycle events (verified via prompt() above)
    // This test ensures the sessionId is properly forwarded
    func testPromptEventContainsSessionId() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let sessionId = "test-session-123"
        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                sessionId: sessionId,
                eventBus: bus
            ),
            client: MockLLMClient()
        )

        _ = await agent.prompt("hello")

        var collected: [any AgentEvent] = []
        for await event in stream {
            collected.append(event)
            if collected.count >= 2 { break }
        }

        let started = collected[0] as! AgentStartedEvent
        XCTAssertEqual(started.sessionId, sessionId)
        let completed = collected[1] as! AgentCompletedEvent
        XCTAssertEqual(completed.sessionId, sessionId)
    }

    // AC5: resume() emits AgentResumedEvent
    func testResumeEmitsResumedEvent() async throws {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let sessionId = "test-resume-session"
        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                sessionId: sessionId,
                eventBus: bus
            ),
            client: MockLLMClient()
        )

        agent.pause(reason: "test pause")
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 100ms for pause state
        agent.resume(context: "test resume context")

        // Fire-and-forget Task needs brief delay
        try await _Concurrency.Task.sleep(nanoseconds: 200_000_000) // 200ms

        var collected: [any AgentEvent] = []
        for await event in stream {
            collected.append(event)
            if collected.count >= 1 { break }
        }

        XCTAssertEqual(collected.count, 1)
        let resumed = collected[0] as! AgentResumedEvent
        XCTAssertEqual(resumed.sessionId, sessionId)
        XCTAssertEqual(resumed.resumeContext, "test resume context")
    }

    // Stream sessionId forwarding
    func testStreamEventContainsSessionId() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let sessionId = "stream-session-456"
        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                sessionId: sessionId,
                eventBus: bus
            ),
            client: MockLLMClient()
        )

        let messageStream = agent.stream("hello")
        for await _ in messageStream {}

        var collected: [any AgentEvent] = []
        for await event in stream {
            collected.append(event)
            if collected.count >= 2 { break }
        }

        let started = collected[0] as! AgentStartedEvent
        XCTAssertEqual(started.sessionId, sessionId)
        let completed = collected[1] as! AgentCompletedEvent
        XCTAssertEqual(completed.sessionId, sessionId)
    }
}

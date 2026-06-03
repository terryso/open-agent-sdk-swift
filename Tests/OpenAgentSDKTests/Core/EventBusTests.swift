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

        let received1 = await collectFirstMatching(stream: stream1, type: AgentStartedEvent.self)
        let received2 = await collectFirstMatching(stream: stream2, type: AgentStartedEvent.self)
        let received3 = await collectFirstMatching(stream: stream3, type: AgentStartedEvent.self)

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

        let collected = await collectEventsWithTimeout(stream: stream, count: 100) { events in
            events.compactMap { ($0 as? AgentStartedEvent)?.task }
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

        let received = await collectFirstFromTypedStream(stream: stream)

        XCTAssertNotNil(received)
        XCTAssertEqual(received?.toolName, "bash")
    }

    // MARK: - AC4: unsubscribe removes subscriber

    func testUnsubscribeRemovesSubscriber() async throws {
        let bus = EventBus()
        let (id, stream) = await bus.subscribe()

        // Publish one event to verify stream works.
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "before"))
        let count = await collectEventsWithTimeout(stream: stream, count: 1) { _ in [0] }
        XCTAssertEqual(count.count, 1)

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
        let events1 = await collectEventsWithTimeout(stream: sub1.stream, count: 2) { events in
            events.compactMap { ($0 as? AgentStartedEvent)?.task }
        }
        let events2 = await collectEventsWithTimeout(stream: sub2.stream, count: 2) { events in
            events.compactMap { ($0 as? AgentStartedEvent)?.task }
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

        let collected = await collectEventsWithTimeout(stream: stream, count: 50) { evts in
            evts.compactMap { ($0 as? AgentStartedEvent)?.task }
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

        let toolEvent = await collectFirstFromTypedStream(stream: toolStream)
        let agentEvent = await collectFirstFromTypedStream(stream: agentStream)

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

        let collected = await collectEventsWithTimeout(stream: stream, count: 4) { events in
            events.map { String(describing: type(of: $0)) }
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
            let _ = await collectEventsWithTimeout(stream: stream, count: 1) { $0 }
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

    // AC1 + AC2: prompt() emits AgentStartedEvent + LLMCostEvent + AgentCompletedEvent
    func testPromptEmitsStartedAndCompletedEvents() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let agent = makeAgentWithEventBus(eventBus: bus)

        _ = await agent.prompt("hello")

        let collected = await collectEventsWithTimeout(stream: stream, count: 4)

        XCTAssertGreaterThanOrEqual(collected.count, 2)
        XCTAssertTrue(collected[0] is AgentStartedEvent)

        let started = collected[0] as! AgentStartedEvent
        XCTAssertEqual(started.task, "hello")

        let completed = collected.first { $0 is AgentCompletedEvent } as! AgentCompletedEvent
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
                retryConfig: RetryConfig(maxRetries: 0),
                eventBus: bus
            ),
            client: FailingLLMClient()
        )

        _ = await agent.prompt("hello")

        let collected = await collectEventsWithTimeout(stream: stream, count: 3)

        XCTAssertTrue(collected[0] is AgentStartedEvent)
        let failed = collected.first { $0 is AgentFailedEvent } as! AgentFailedEvent
        XCTAssertTrue(failed.error.contains("API error"))
        XCTAssertEqual(failed.stepsCompleted, 0)
    }

    // AC1 + AC2: stream() emits AgentStartedEvent + LLMCostEvent(s) + AgentCompletedEvent
    func testStreamEmitsStartedAndCompletedEvents() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let agent = makeAgentWithEventBus(eventBus: bus)

        let messageStream = agent.stream("hello")
        // Consume the stream to drive it to completion
        for await _ in messageStream {}

        let collected = await collectEventsWithTimeout(stream: stream, count: 4)

        XCTAssertGreaterThanOrEqual(collected.count, 2)
        XCTAssertTrue(collected[0] is AgentStartedEvent)

        let started = collected[0] as! AgentStartedEvent
        XCTAssertEqual(started.task, "hello")

        let completed = collected.first { $0 is AgentCompletedEvent } as! AgentCompletedEvent
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
                retryConfig: RetryConfig(maxRetries: 0),
                eventBus: bus
            ),
            client: FailingLLMClient()
        )

        let messageStream = agent.stream("hello")
        for await _ in messageStream {}

        let collected = await collectEventsWithTimeout(stream: stream, count: 3)

        XCTAssertTrue(collected[0] is AgentStartedEvent)
        XCTAssertNotNil(collected.first { $0 is AgentFailedEvent })
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

        let collected = await collectEventsWithTimeout(stream: stream, count: 4)

        let started = collected[0] as! AgentStartedEvent
        XCTAssertEqual(started.sessionId, sessionId)
        let completed = collected.first { $0 is AgentCompletedEvent } as! AgentCompletedEvent
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

        let collected = await collectEventsWithTimeout(stream: stream, count: 1)

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

        let collected = await collectEventsWithTimeout(stream: stream, count: 4)

        let started = collected[0] as! AgentStartedEvent
        XCTAssertEqual(started.sessionId, sessionId)
        let completed = collected.first { $0 is AgentCompletedEvent } as! AgentCompletedEvent
        XCTAssertEqual(completed.sessionId, sessionId)
    }

    // MARK: - Tool Lifecycle Event Emit Tests (Story 27.3)

    /// A simple tool that returns a fixed result.
    private struct StubTool: ToolProtocol, @unchecked Sendable {
        let name: String
        let description: String = "stub"
        let inputSchema: ToolInputSchema = ["type": "object", "properties": [:]]
        let isReadOnly: Bool = true
        let isError: Bool
        let content: String

        init(name: String = "stub", isError: Bool = false, content: String = "ok") {
            self.name = name
            self.isError = isError
            self.content = content
        }

        func call(input: Any, context: ToolContext) async -> ToolResult {
            return ToolResult(toolUseId: context.toolUseId, content: content, isError: isError)
        }
    }

    // AC1: ToolStartedEvent emitted before tool execution
    func testToolStartedEventEmitted() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let tool = StubTool(name: "bash", isError: false, content: "ok")
        let block = ToolUseBlock(id: "tu-1", name: "bash", input: ["command": "echo hi"])
        let context = ToolContext(
            cwd: "/tmp",
            eventBus: bus,
            sessionId: "sess-1"
        )

        _ = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        let collected = await collectEventsWithTimeout(stream: stream, count: 2)

        XCTAssertTrue(collected[0] is ToolStartedEvent)
        let started = collected[0] as! ToolStartedEvent
        XCTAssertEqual(started.toolName, "bash")
        XCTAssertEqual(started.toolUseId, "tu-1")
        XCTAssertEqual(started.sessionId, "sess-1")
        XCTAssertNotNil(started.input)
    }

    // AC2: ToolCompletedEvent emitted on successful tool execution
    func testToolCompletedEventEmitted() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let tool = StubTool(name: "bash", isError: false, content: "hello")
        let block = ToolUseBlock(id: "tu-2", name: "bash", input: ["command": "echo hi"])
        let context = ToolContext(
            cwd: "/tmp",
            eventBus: bus,
            sessionId: "sess-2"
        )

        _ = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        let collected = await collectEventsWithTimeout(stream: stream, count: 2)

        XCTAssertEqual(collected.count, 2)
        XCTAssertTrue(collected[0] is ToolStartedEvent)
        XCTAssertTrue(collected[1] is ToolCompletedEvent)

        let completed = collected[1] as! ToolCompletedEvent
        XCTAssertEqual(completed.toolName, "bash")
        XCTAssertEqual(completed.toolUseId, "tu-2")
        XCTAssertEqual(completed.sessionId, "sess-2")
        XCTAssertGreaterThanOrEqual(completed.durationMs, 0)
        XCTAssertFalse(completed.isError)
    }

    // AC3: ToolFailedEvent emitted on tool execution failure
    func testToolFailedEventEmitted() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let tool = StubTool(name: "bash", isError: true, content: "command not found")
        let block = ToolUseBlock(id: "tu-3", name: "bash", input: ["command": "bad_cmd"])
        let context = ToolContext(
            cwd: "/tmp",
            eventBus: bus,
            sessionId: "sess-3"
        )

        _ = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        let collected = await collectEventsWithTimeout(stream: stream, count: 2)

        XCTAssertEqual(collected.count, 2)
        XCTAssertTrue(collected[0] is ToolStartedEvent)
        XCTAssertTrue(collected[1] is ToolFailedEvent)

        let failed = collected[1] as! ToolFailedEvent
        XCTAssertEqual(failed.toolName, "bash")
        XCTAssertEqual(failed.toolUseId, "tu-3")
        XCTAssertEqual(failed.sessionId, "sess-3")
        XCTAssertTrue(failed.error.contains("command not found"))
    }

    // AC4: Each tool gets independent Started/Completed events
    func testMultipleToolsGetIndependentEvents() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let tool1 = StubTool(name: "read", isError: false, content: "file1")
        let tool2 = StubTool(name: "bash", isError: false, content: "output")
        let block1 = ToolUseBlock(id: "tu-a", name: "read", input: ["path": "/a"])
        let block2 = ToolUseBlock(id: "tu-b", name: "bash", input: ["command": "ls"])
        let context = ToolContext(
            cwd: "/tmp",
            eventBus: bus,
            sessionId: "sess-multi"
        )

        _ = await ToolExecutor.executeSingleTool(block: block1, tool: tool1, context: context)
        _ = await ToolExecutor.executeSingleTool(block: block2, tool: tool2, context: context)

        let collected = await collectEventsWithTimeout(stream: stream, count: 4)

        XCTAssertEqual(collected.count, 4)
        XCTAssertTrue(collected[0] is ToolStartedEvent)
        XCTAssertTrue(collected[1] is ToolCompletedEvent)
        XCTAssertTrue(collected[2] is ToolStartedEvent)
        XCTAssertTrue(collected[3] is ToolCompletedEvent)

        let started1 = collected[0] as! ToolStartedEvent
        XCTAssertEqual(started1.toolUseId, "tu-a")
        let completed1 = collected[1] as! ToolCompletedEvent
        XCTAssertEqual(completed1.toolUseId, "tu-a")
        XCTAssertEqual(completed1.toolName, "read")

        let started2 = collected[2] as! ToolStartedEvent
        XCTAssertEqual(started2.toolUseId, "tu-b")
        let completed2 = collected[3] as! ToolCompletedEvent
        XCTAssertEqual(completed2.toolUseId, "tu-b")
        XCTAssertEqual(completed2.toolName, "bash")
    }

    // AC6: No events emitted when eventBus is nil
    func testNoEventsWhenEventBusIsNil() async throws {
        let tool = StubTool(name: "bash", isError: false, content: "ok")
        let block = ToolUseBlock(id: "tu-nil", name: "bash", input: ["command": "echo hi"])
        let context = ToolContext(cwd: "/tmp")

        let result = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        // Tool should execute normally without events — just verify the result is returned
        XCTAssertEqual(result.toolUseId, "tu-nil")
        XCTAssertFalse(result.isError)
    }

    // Unknown tool emits ToolFailedEvent
    func testUnknownToolEmitsFailedEvent() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let block = ToolUseBlock(id: "tu-unknown", name: "nonexistent", input: [:])
        let context = ToolContext(
            cwd: "/tmp",
            eventBus: bus,
            sessionId: "sess-unknown"
        )

        _ = await ToolExecutor.executeSingleTool(block: block, tool: nil, context: context)

        let collected = await collectEventsWithTimeout(stream: stream, count: 1)

        XCTAssertEqual(collected.count, 1)
        XCTAssertTrue(collected[0] is ToolFailedEvent)

        let failed = collected[0] as! ToolFailedEvent
        XCTAssertEqual(failed.toolName, "nonexistent")
        XCTAssertEqual(failed.toolUseId, "tu-unknown")
        XCTAssertTrue(failed.error.contains("Unknown tool"))
    }

    // Permission denied emits ToolFailedEvent
    func testPermissionDeniedEmitsFailedEvent() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let writeTool = WriteStubTool(name: "Write")
        let block = ToolUseBlock(id: "tu-perm", name: "Write", input: ["path": "/etc/passwd"])
        let context = ToolContext(
            cwd: "/tmp",
            permissionMode: .plan,
            eventBus: bus,
            sessionId: "sess-perm"
        )

        _ = await ToolExecutor.executeSingleTool(block: block, tool: writeTool, context: context)

        let collected = await collectEventsWithTimeout(stream: stream, count: 1)

        XCTAssertEqual(collected.count, 1)
        XCTAssertTrue(collected[0] is ToolFailedEvent)

        let failed = collected[0] as! ToolFailedEvent
        XCTAssertEqual(failed.toolName, "Write")
        XCTAssertTrue(failed.error.contains("blocked"))
    }

    // Hook blocked path emits ToolFailedEvent
    func testHookBlockedEmitsFailedEvent() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            HookOutput(message: "Blocked by security policy", block: true)
        }))

        let tool = StubTool(name: "bash", isError: false, content: "ok")
        let block = ToolUseBlock(id: "tu-hook", name: "bash", input: ["command": "rm -rf /"])
        let context = ToolContext(
            cwd: "/tmp",
            hookRegistry: registry,
            eventBus: bus,
            sessionId: "sess-hook"
        )

        _ = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        let collected = await collectEventsWithTimeout(stream: stream, count: 1)

        XCTAssertEqual(collected.count, 1)
        XCTAssertTrue(collected[0] is ToolFailedEvent)

        let failed = collected[0] as! ToolFailedEvent
        XCTAssertEqual(failed.toolName, "bash")
        XCTAssertEqual(failed.toolUseId, "tu-hook")
        XCTAssertEqual(failed.sessionId, "sess-hook")
        XCTAssertTrue(failed.error.contains("Blocked by security policy"))
    }

    // canUseTool deny path emits ToolFailedEvent
    func testCanUseToolDenyEmitsFailedEvent() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let tool = StubTool(name: "bash", isError: false, content: "ok")
        let block = ToolUseBlock(id: "tu-deny", name: "bash", input: ["command": "echo hi"])
        let context = ToolContext(
            cwd: "/tmp",
            canUseTool: { _, _, _ in .deny("User rejected this tool") },
            eventBus: bus,
            sessionId: "sess-deny"
        )

        _ = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        let collected = await collectEventsWithTimeout(stream: stream, count: 1)

        XCTAssertEqual(collected.count, 1)
        XCTAssertTrue(collected[0] is ToolFailedEvent)

        let failed = collected[0] as! ToolFailedEvent
        XCTAssertEqual(failed.toolName, "bash")
        XCTAssertEqual(failed.toolUseId, "tu-deny")
        XCTAssertTrue(failed.error.contains("User rejected this tool"))
    }

    // canUseTool allow path emits ToolStartedEvent + ToolCompletedEvent
    func testCanUseToolAllowEmitsStartedAndCompleted() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let tool = StubTool(name: "bash", isError: false, content: "hello world")
        let block = ToolUseBlock(id: "tu-allow", name: "bash", input: ["command": "echo hi"])
        let context = ToolContext(
            cwd: "/tmp",
            canUseTool: { _, _, _ in .allow() },
            eventBus: bus,
            sessionId: "sess-allow"
        )

        _ = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        let collected = await collectEventsWithTimeout(stream: stream, count: 2)

        XCTAssertEqual(collected.count, 2)
        XCTAssertTrue(collected[0] is ToolStartedEvent)
        XCTAssertTrue(collected[1] is ToolCompletedEvent)

        let started = collected[0] as! ToolStartedEvent
        XCTAssertEqual(started.toolName, "bash")
        XCTAssertEqual(started.toolUseId, "tu-allow")
        XCTAssertEqual(started.sessionId, "sess-allow")

        let completed = collected[1] as! ToolCompletedEvent
        XCTAssertEqual(completed.toolName, "bash")
        XCTAssertEqual(completed.toolUseId, "tu-allow")
        XCTAssertGreaterThanOrEqual(completed.durationMs, 0)
        XCTAssertFalse(completed.isError)
    }

    /// A non-read-only stub tool for testing permission paths.
    private struct WriteStubTool: ToolProtocol, @unchecked Sendable {
        let name: String
        let description: String = "write"
        let inputSchema: ToolInputSchema = ["type": "object", "properties": [:]]
        let isReadOnly: Bool = false

        func call(input: Any, context: ToolContext) async -> ToolResult {
            return ToolResult(toolUseId: context.toolUseId, content: "written", isError: false)
        }
    }

    // MARK: - LLM Cost Event Emit Tests (Story 27.4)

    /// Mock LLM client that returns a response with specific token usage.
    private struct CostAwareMockLLMClient: LLMClient, @unchecked Sendable {
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationInputTokens: Int?
        let cacheReadInputTokens: Int?

        init(inputTokens: Int = 100, outputTokens: Int = 50,
             cacheCreationInputTokens: Int? = nil, cacheReadInputTokens: Int? = nil) {
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.cacheCreationInputTokens = cacheCreationInputTokens
            self.cacheReadInputTokens = cacheReadInputTokens
        }

        nonisolated func sendMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> [String: Any] {
            var usage: [String: Any] = [
                "input_tokens": inputTokens,
                "output_tokens": outputTokens,
            ]
            if let v = cacheCreationInputTokens { usage["cache_creation_input_tokens"] = v }
            if let v = cacheReadInputTokens { usage["cache_read_input_tokens"] = v }
            return [
                "content": [["type": "text", "text": "done"]],
                "stop_reason": "end_turn",
                "usage": usage,
            ]
        }

        nonisolated func streamMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
            var deltaUsage: [String: Any] = [
                "input_tokens": 0,
                "output_tokens": outputTokens,
            ]
            if let v = cacheCreationInputTokens { deltaUsage["cache_creation_input_tokens"] = v }
            if let v = cacheReadInputTokens { deltaUsage["cache_read_input_tokens"] = v }
            var msgUsage: [String: Any] = [
                "input_tokens": inputTokens,
            ]
            if let v = cacheCreationInputTokens { msgUsage["cache_creation_input_tokens"] = v }
            if let v = cacheReadInputTokens { msgUsage["cache_read_input_tokens"] = v }
            let events: [SSEEvent] = [
                .messageStart(message: ["type": "message_start", "model": model, "usage": msgUsage]),
                .contentBlockStart(index: 0, contentBlock: ["type": "text", "text": ""]),
                .contentBlockDelta(index: 0, delta: ["type": "text_delta", "text": "done"]),
                .contentBlockStop(index: 0),
                .messageDelta(delta: ["stop_reason": "end_turn"], usage: deltaUsage),
                .messageStop,
            ]
            return AsyncThrowingStream { continuation in
                for event in events { continuation.yield(event) }
                continuation.finish()
            }
        }
    }

    // AC1 + AC5: prompt() emits LLMCostEvent with correct values
    func testPromptEmitsLLMCostEvent() async {
        let bus = EventBus()
        let stream = await bus.subscribe(LLMCostEvent.self)

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                eventBus: bus
            ),
            client: CostAwareMockLLMClient(inputTokens: 100, outputTokens: 50)
        )

        _ = await agent.prompt("hello")

        let costEvent = await collectFirstFromTypedStream(stream: stream)

        XCTAssertNotNil(costEvent)
        XCTAssertEqual(costEvent?.inputTokens, 100)
        XCTAssertEqual(costEvent?.outputTokens, 50)
        XCTAssertEqual(costEvent?.model, "claude-sonnet-4-6")

        let expectedCost = estimateCost(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 100, outputTokens: 50))
        XCTAssertEqual(costEvent!.estimatedCostUsd, expectedCost, accuracy: 0.000001)
    }

    // AC3: Multiple LLM calls emit multiple independent LLMCostEvents
    func testMultiplePromptCallsEmitMultipleCostEvents() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                eventBus: bus
            ),
            client: CostAwareMockLLMClient(inputTokens: 80, outputTokens: 40)
        )

        _ = await agent.prompt("first")
        _ = await agent.prompt("second")
        _ = await agent.prompt("third")

        let collected = await collectEventsWithTimeout(stream: stream, count: 12) { events in
            events.compactMap { $0 as? LLMCostEvent }
        }

        XCTAssertEqual(collected.count, 3)
        for event in collected {
            XCTAssertEqual(event.inputTokens, 80)
            XCTAssertEqual(event.outputTokens, 40)
        }
    }

    // AC4: LLMCostEvent contains cache token data when API returns it
    func testLLMCostEventContainsCacheTokens() async {
        let bus = EventBus()
        let stream = await bus.subscribe(LLMCostEvent.self)

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                eventBus: bus
            ),
            client: CostAwareMockLLMClient(
                inputTokens: 200, outputTokens: 30,
                cacheCreationInputTokens: 150, cacheReadInputTokens: 50
            )
        )

        _ = await agent.prompt("test cache tokens")

        let costEvent = await collectFirstFromTypedStream(stream: stream)

        XCTAssertNotNil(costEvent)
        XCTAssertEqual(costEvent?.cacheCreationInputTokens, 150)
        XCTAssertEqual(costEvent?.cacheReadInputTokens, 50)
    }

    // AC7: No LLMCostEvent when eventBus is nil (zero overhead)
    func testNoLLMCostEventWhenEventBusIsNil() async {
        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper."
            ),
            client: CostAwareMockLLMClient(inputTokens: 100, outputTokens: 50)
        )

        let result = await agent.prompt("hello")
        XCTAssertNotNil(result)
        XCTAssertFalse(result.text.isEmpty)
    }

    // AC2 + AC8: stream() emits LLMCostEvent
    func testStreamEmitsLLMCostEvent() async {
        let bus = EventBus()
        let stream = await bus.subscribe(LLMCostEvent.self)

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                eventBus: bus
            ),
            client: CostAwareMockLLMClient(inputTokens: 120, outputTokens: 60)
        )

        let messageStream = agent.stream("hello")
        for await _ in messageStream {}

        let costEvents = await collectTypedEventsWithTimeout(stream: stream, count: 2)

        XCTAssertGreaterThanOrEqual(costEvents.count, 1)

        let totalInput = costEvents.reduce(0) { $0 + $1.inputTokens }
        let totalOutput = costEvents.reduce(0) { $0 + $1.outputTokens }
        XCTAssertGreaterThanOrEqual(totalInput, 120)
        XCTAssertGreaterThanOrEqual(totalOutput, 60)
    }

    // AC5: estimatedCostUsd matches estimateCost() exactly
    func testEstimatedCostMatchesEstimateCostFunction() async {
        let bus = EventBus()
        let stream = await bus.subscribe(LLMCostEvent.self)

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                eventBus: bus
            ),
            client: CostAwareMockLLMClient(inputTokens: 500, outputTokens: 200)
        )

        _ = await agent.prompt("cost check")

        let costEvent = await collectFirstFromTypedStream(stream: stream)

        XCTAssertNotNil(costEvent)
        let expectedCost = estimateCost(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 500, outputTokens: 200))
        XCTAssertEqual(costEvent!.estimatedCostUsd, expectedCost, accuracy: 0.0000001)
    }

    // MARK: - Session Lifecycle Event Emit Tests (Story 27.5)

    // AC2: prompt() + EventBus + SessionStore → SessionCreatedEvent
    func testPromptEmitsSessionCreatedEvent() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let store = SessionStore(sessionsDir: NSTemporaryDirectory())
        let sessionId = "sess-created-\(UUID().uuidString.prefix(8))"

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                sessionStore: store,
                sessionId: sessionId,
                eventBus: bus
            ),
            client: MockLLMClient()
        )

        _ = await agent.prompt("hello session")

        let collected = await collectEventsWithTimeout(stream: stream, count: 4)

        let sessionCreated = collected.first { $0 is SessionCreatedEvent } as? SessionCreatedEvent
        XCTAssertNotNil(sessionCreated, "SessionCreatedEvent should be emitted")
        XCTAssertEqual(sessionCreated?.sessionId, sessionId)
        XCTAssertEqual(sessionCreated?.task, "hello session")
        XCTAssertEqual(sessionCreated?.model, "claude-sonnet-4-6")
    }

    // AC1: stream() + EventBus + SessionStore → SessionCreatedEvent
    func testStreamEmitsSessionCreatedEvent() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let store = SessionStore(sessionsDir: NSTemporaryDirectory())
        let sessionId = "sess-stream-created-\(UUID().uuidString.prefix(8))"

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                sessionStore: store,
                sessionId: sessionId,
                eventBus: bus
            ),
            client: MockLLMClient()
        )

        let messageStream = agent.stream("hello stream session")
        for await _ in messageStream {}

        let collected = await collectEventsWithTimeout(stream: stream, count: 4)

        let sessionCreated = collected.first { $0 is SessionCreatedEvent } as? SessionCreatedEvent
        XCTAssertNotNil(sessionCreated, "SessionCreatedEvent should be emitted")
        XCTAssertEqual(sessionCreated?.sessionId, sessionId)
        XCTAssertEqual(sessionCreated?.task, "hello stream session")
        XCTAssertEqual(sessionCreated?.model, "claude-sonnet-4-6")
    }

    // AC3: prompt() + EventBus + SessionStore + persistSession → SessionAutoSavedEvent
    func testPromptEmitsSessionAutoSavedEvent() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let tempDir = NSTemporaryDirectory() + "autosave-\(UUID().uuidString.prefix(8))"
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "sess-autosave-\(UUID().uuidString.prefix(8))"

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                sessionStore: store,
                sessionId: sessionId,
                persistSession: true,
                eventBus: bus
            ),
            client: MockLLMClient()
        )

        _ = await agent.prompt("auto-save test")

        let collected = await collectEventsWithTimeout(stream: stream, count: 5)

        let autoSaved = collected.first { $0 is SessionAutoSavedEvent } as? SessionAutoSavedEvent
        XCTAssertNotNil(autoSaved, "SessionAutoSavedEvent should be emitted")
        XCTAssertEqual(autoSaved?.sessionId, sessionId)
        XCTAssertGreaterThanOrEqual(autoSaved?.messageCount ?? 0, 1)
    }

    // AC4: close() + EventBus → SessionClosedEvent
    func testCloseEmitsSessionClosedEvent() async throws {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                sessionId: "sess-close-test",
                eventBus: bus
            ),
            client: MockLLMClient()
        )

        try await agent.close()

        let collected = await collectEventsWithTimeout(stream: stream, count: 1)

        XCTAssertEqual(collected.count, 1)
        let closed = collected[0] as? SessionClosedEvent
        XCTAssertNotNil(closed, "SessionClosedEvent should be emitted")
        XCTAssertEqual(closed?.sessionId, "sess-close-test")
        XCTAssertEqual(closed?.finalStatus, .completed)
    }

    // AC5: No session events when eventBus is nil (zero overhead)
    func testNoSessionEventsWhenEventBusIsNil() async throws {
        let store = SessionStore(sessionsDir: NSTemporaryDirectory())

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                sessionStore: store,
                sessionId: "sess-nil-test",
                persistSession: true
            ),
            client: MockLLMClient()
        )

        // Should execute normally without eventBus
        let result = await agent.prompt("hello no bus")
        XCTAssertNotNil(result)
        XCTAssertFalse(result.text.isEmpty)

        try await agent.close()
    }

    // AC6: prompt() error path → SessionAutoSavedEvent
    func testPromptErrorPathEmitsSessionAutoSavedEvent() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()
        let tempDir = NSTemporaryDirectory() + "autosave-err-\(UUID().uuidString.prefix(8))"
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "sess-err-autosave-\(UUID().uuidString.prefix(8))"

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helper.",
                retryConfig: RetryConfig(maxRetries: 0),
                sessionStore: store,
                sessionId: sessionId,
                persistSession: true,
                eventBus: bus
            ),
            client: FailingLLMClient()
        )

        _ = await agent.prompt("this will fail")

        let collected = await collectEventsWithTimeout(stream: stream, count: 4)

        let autoSaved = collected.first { $0 is SessionAutoSavedEvent } as? SessionAutoSavedEvent
        XCTAssertNotNil(autoSaved, "SessionAutoSavedEvent should be emitted on error path. Events received: \(collected.map { String(describing: type(of: $0)) })")
        XCTAssertEqual(autoSaved?.sessionId, sessionId)
    }

    // MARK: - Timeout-Protected Collection Helpers

    /// Default timeout in nanoseconds (5 seconds).
    private static let defaultTimeoutNs: UInt64 = 5_000_000_000

    /// Collect events from an `AsyncStream<any AgentEvent>` with a timeout.
    /// Returns collected events (may be fewer than `count` if the stream ends or times out).
    private func collectEventsWithTimeout(
        stream: AsyncStream<any AgentEvent>,
        count: Int,
        timeoutNs: UInt64 = EventBusTests.defaultTimeoutNs
    ) async -> [any AgentEvent] {
        await withTaskGroup(of: [any AgentEvent].self, returning: [any AgentEvent].self) { group in
            group.addTask {
                var events: [any AgentEvent] = []
                for await event in stream {
                    events.append(event)
                    if events.count >= count { break }
                }
                return events
            }
            group.addTask {
                try? await _Concurrency.Task.sleep(nanoseconds: timeoutNs)
                return []
            }
            let first = await group.next()!
            group.cancelAll()
            return first
        }
    }

    /// Collect events from an `AsyncStream<any AgentEvent>` with a timeout,
    /// then transform the result using the provided closure.
    private func collectEventsWithTimeout<T>(
        stream: AsyncStream<any AgentEvent>,
        count: Int,
        timeoutNs: UInt64 = EventBusTests.defaultTimeoutNs,
        transform: ([any AgentEvent]) -> T
    ) async -> T {
        let events = await collectEventsWithTimeout(stream: stream, count: count, timeoutNs: timeoutNs)
        return transform(events)
    }

    /// Collect events from a typed `AsyncStream<T>` with a timeout.
    private func collectTypedEventsWithTimeout<T: AgentEvent>(
        stream: AsyncStream<T>,
        count: Int,
        timeoutNs: UInt64 = EventBusTests.defaultTimeoutNs
    ) async -> [T] {
        await withTaskGroup(of: [T].self, returning: [T].self) { group in
            group.addTask {
                var events: [T] = []
                for await event in stream {
                    events.append(event)
                    if events.count >= count { break }
                }
                return events
            }
            group.addTask {
                try? await _Concurrency.Task.sleep(nanoseconds: timeoutNs)
                return []
            }
            let first = await group.next()!
            group.cancelAll()
            return first
        }
    }

    /// Collect the first event from an `AsyncStream<any AgentEvent>` with a timeout,
    /// then attempt to cast it to the specified type.
    private func collectFirstMatching<T: AgentEvent>(
        stream: AsyncStream<any AgentEvent>,
        type: T.Type
    ) async -> T? {
        let events = await collectEventsWithTimeout(stream: stream, count: 1)
        return events.first as? T
    }

    /// Collect the first event from a typed `AsyncStream<T>` with a timeout.
    private func collectFirstFromTypedStream<T: AgentEvent>(
        stream: AsyncStream<T>,
        timeoutNs: UInt64 = EventBusTests.defaultTimeoutNs
    ) async -> T? {
        let events = await collectTypedEventsWithTimeout(stream: stream, count: 1, timeoutNs: timeoutNs)
        return events.first
    }

}

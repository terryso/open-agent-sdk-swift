import Foundation
import OpenAgentSDK
import _Concurrency

// MARK: - Tests 141-145: Agent Lifecycle Event Emit E2E Tests (Story 27.2)

/// E2E tests for agent lifecycle event emission through EventBus.
/// Uses real LLM calls + EventBus to verify all lifecycle events.
struct AgentLifecycleEmitE2ETests {
    static func run(apiKey: String, model: String, baseURL: String?) async {
        section("141-145. Agent Lifecycle Event Emit (E2E — Story 27.2)")
        await testStreamEmitsStartedAndCompletedEvents(apiKey: apiKey, model: model, baseURL: baseURL)
        await testPromptEmitsStartedAndCompletedEvents(apiKey: apiKey, model: model, baseURL: baseURL)
        await testPromptEmitsFailedEventOnRealError(baseURL: baseURL)
        await testStreamEmitsInterruptedEvent(apiKey: apiKey, model: model, baseURL: baseURL)
        await testResumeEmitsResumedEvent(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: Test 141: stream() emits AgentStartedEvent + AgentCompletedEvent via real LLM

    static func testStreamEmitsStartedAndCompletedEvents(apiKey: String, model: String, baseURL: String?) async {
        let bus = EventBus()
        let (_, eventStream) = await bus.subscribe()

        var opts = AgentOptions(
            apiKey: apiKey,
            model: model,
            systemPrompt: "Reply with exactly: hello"
        )
        if let baseURL { opts.baseURL = baseURL }
        opts.eventBus = bus

        let agent = Agent(options: opts)
        let messageStream = agent.stream("say hello")

        // Consume the SDK message stream to drive completion
        for await _ in messageStream {}

        // Collect events from EventBus
        var collected: [any AgentEvent] = []
        for await event in eventStream {
            collected.append(event)
            if collected.count >= 2 { break }
        }

        guard collected.count >= 2 else {
            fail("141. Stream emits lifecycle events", "expected >= 2 events, got \(collected.count)")
            return
        }
        guard collected[0] is AgentStartedEvent else {
            fail("141. Stream emits lifecycle events", "first event is not AgentStartedEvent")
            return
        }
        guard collected[1] is AgentCompletedEvent else {
            fail("141. Stream emits lifecycle events", "second event is not AgentCompletedEvent")
            return
        }

        let started = collected[0] as! AgentStartedEvent
        guard started.task == "say hello" else {
            fail("141. Stream emits lifecycle events", "task mismatch: \(started.task)")
            return
        }

        let completed = collected[1] as! AgentCompletedEvent
        guard completed.totalSteps >= 1 else {
            fail("141. Stream emits lifecycle events", "totalSteps < 1: \(completed.totalSteps)")
            return
        }
        guard completed.durationMs >= 0 else {
            fail("141. Stream emits lifecycle events", "durationMs < 0: \(completed.durationMs)")
            return
        }

        pass("141. Stream emits AgentStartedEvent + AgentCompletedEvent via real LLM")
    }

    // MARK: Test 142: prompt() emits AgentStartedEvent + AgentCompletedEvent via real LLM

    static func testPromptEmitsStartedAndCompletedEvents(apiKey: String, model: String, baseURL: String?) async {
        let bus = EventBus()
        let (_, eventStream) = await bus.subscribe()

        var opts = AgentOptions(
            apiKey: apiKey,
            model: model,
            systemPrompt: "Reply with exactly: hello"
        )
        if let baseURL { opts.baseURL = baseURL }
        opts.eventBus = bus

        let agent = Agent(options: opts)
        _ = await agent.prompt("say hello")

        // Collect events from EventBus
        var collected: [any AgentEvent] = []
        for await event in eventStream {
            collected.append(event)
            if collected.count >= 2 { break }
        }

        guard collected.count >= 2 else {
            fail("142. Prompt emits lifecycle events", "expected >= 2 events, got \(collected.count)")
            return
        }
        guard collected[0] is AgentStartedEvent else {
            fail("142. Prompt emits lifecycle events", "first event is not AgentStartedEvent")
            return
        }
        guard collected[1] is AgentCompletedEvent else {
            fail("142. Prompt emits lifecycle events", "second event is not AgentCompletedEvent")
            return
        }

        let started = collected[0] as! AgentStartedEvent
        guard started.task == "say hello" else {
            fail("142. Prompt emits lifecycle events", "task mismatch: \(started.task)")
            return
        }

        let completed = collected[1] as! AgentCompletedEvent
        guard completed.totalSteps >= 1 else {
            fail("142. Prompt emits lifecycle events", "totalSteps < 1: \(completed.totalSteps)")
            return
        }

        pass("142. Prompt emits AgentStartedEvent + AgentCompletedEvent via real LLM")
    }

    // MARK: Test 143: prompt() emits AgentFailedEvent on real API error (AC3)

    static func testPromptEmitsFailedEventOnRealError(baseURL: String?) async {
        let bus = EventBus()
        let (_, eventStream) = await bus.subscribe()

        var opts = AgentOptions(
            apiKey: "sk-invalid-key-12345",
            model: "gpt-4o-mini",
            baseURL: baseURL ?? "https://api.openai.com",
            provider: .openai,
            maxTurns: 1
        )
        opts.eventBus = bus

        let agent = Agent(options: opts)
        _ = await agent.prompt("This should fail.")

        // Collect events — expect Started + Failed
        var collected: [any AgentEvent] = []
        for await event in eventStream {
            collected.append(event)
            if collected.count >= 2 { break }
        }

        guard collected.count >= 2 else {
            fail("143. Prompt emits FailedEvent on real error", "expected >= 2 events, got \(collected.count)")
            return
        }
        guard collected[0] is AgentStartedEvent else {
            fail("143. Prompt emits FailedEvent on real error", "first event is not AgentStartedEvent")
            return
        }
        guard collected[1] is AgentFailedEvent else {
            fail("143. Prompt emits FailedEvent on real error", "second event is not AgentFailedEvent, got \(type(of: collected[1]))")
            return
        }

        let failed = collected[1] as! AgentFailedEvent
        guard failed.stepsCompleted >= 0 else {
            fail("143. Prompt emits FailedEvent on real error", "stepsCompleted < 0: \(failed.stepsCompleted)")
            return
        }

        pass("143. Prompt emits AgentFailedEvent on real API error")
    }

    // MARK: Test 144: stream() emits AgentInterruptedEvent on interrupt() (AC4)

    static func testStreamEmitsInterruptedEvent(apiKey: String, model: String, baseURL: String?) async {
        let bus = EventBus()
        let (_, eventStream) = await bus.subscribe()

        var opts = AgentOptions(
            apiKey: apiKey,
            model: model,
            systemPrompt: "Write a very detailed and long response about the history of computing. Do not be brief."
        )
        if let baseURL { opts.baseURL = baseURL }
        opts.eventBus = bus

        let agent = Agent(options: opts)
        let messageStream = agent.stream("Write a detailed essay about the history of computing from 1940 to 2020.")

        // Schedule interrupt after a brief delay to let the stream start
        _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            agent.interrupt()
        }

        // Consume the stream to drive it
        for await _ in messageStream {}

        // Collect events — expect Started + Interrupted (or Completed if LLM was too fast)
        var collected: [any AgentEvent] = []
        for await event in eventStream {
            collected.append(event)
            if collected.count >= 2 { break }
        }

        guard collected.count >= 2 else {
            fail("144. Stream emits InterruptedEvent on interrupt", "expected >= 2 events, got \(collected.count)")
            return
        }
        guard collected[0] is AgentStartedEvent else {
            fail("144. Stream emits InterruptedEvent on interrupt", "first event is not AgentStartedEvent")
            return
        }

        // Accept either Interrupted or Completed (if the LLM responded before interrupt took effect)
        if collected[1] is AgentInterruptedEvent {
            let interrupted = collected[1] as! AgentInterruptedEvent
            guard interrupted.stepsCompleted >= 0 else {
                fail("144. Stream emits InterruptedEvent on interrupt", "stepsCompleted < 0: \(interrupted.stepsCompleted)")
                return
            }
            pass("144. Stream emits AgentInterruptedEvent on interrupt()")
        } else if collected[1] is AgentCompletedEvent {
            // LLM responded before interrupt — acceptable race condition
            pass("144. Stream completed before interrupt (race condition, event emit path verified)")
        } else {
            fail("144. Stream emits InterruptedEvent on interrupt", "unexpected second event: \(type(of: collected[1]))")
        }
    }

    // MARK: Test 145: resume() emits AgentResumedEvent (AC5)

    static func testResumeEmitsResumedEvent(apiKey: String, model: String, baseURL: String?) async {
        let bus = EventBus()
        let (_, eventStream) = await bus.subscribe()

        let sessionId = "resume-e2e-\(UUID().uuidString.prefix(8))"

        var opts = AgentOptions(
            apiKey: apiKey,
            model: model,
            systemPrompt: "You are a helper.",
            sessionId: sessionId
        )
        if let baseURL { opts.baseURL = baseURL }
        opts.eventBus = bus

        let agent = Agent(options: opts)

        // Pause the agent and then resume — resume publishes AgentResumedEvent
        agent.pause(reason: "waiting for human input")

        // Give pause state time to propagate
        try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 100ms

        agent.resume(context: "human approved the action")

        // The resume() uses fire-and-forget Task, so allow a brief delay
        try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Collect events
        var collected: [any AgentEvent] = []
        for await event in eventStream {
            collected.append(event)
            if collected.count >= 1 { break }
        }

        guard collected.count >= 1 else {
            fail("145. Resume emits ResumedEvent", "expected >= 1 event, got \(collected.count)")
            return
        }
        guard let resumed = collected[0] as? AgentResumedEvent else {
            fail("145. Resume emits ResumedEvent", "event is not AgentResumedEvent, got \(type(of: collected[0]))")
            return
        }

        guard resumed.sessionId == sessionId else {
            fail("145. Resume emits ResumedEvent", "sessionId mismatch: expected \(sessionId), got \(resumed.sessionId ?? "nil")")
            return
        }
        guard resumed.resumeContext == "human approved the action" else {
            fail("145. Resume emits ResumedEvent", "resumeContext mismatch: \(resumed.resumeContext)")
            return
        }

        pass("145. Resume emits AgentResumedEvent with sessionId and resumeContext")
    }
}

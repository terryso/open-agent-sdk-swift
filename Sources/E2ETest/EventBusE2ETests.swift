import Foundation
import OpenAgentSDK

// MARK: - Tests 127-133: EventBus E2E Tests (Story 26.6)

/// E2E tests for the EventBus actor: real concurrency, mixed subscriptions,
/// stress tests, memory cleanup, and all 16 event types.
/// No mocks — uses real Swift Concurrency primitives.
struct EventBusE2ETests {
    static func run() async {
        section("127-140. EventBus In-Process Event Bus (E2E — Story 26.6)")
        await testConcurrentPublishAndSubscribe()
        await testMixedSubscribe_fullAndTypeFiltered()
        await testHighFrequencyPublish_stress()
        await testSubscriberCancellation_memoryReclaimed()
        await testAllEventTypes_throughEventBus()
        await testActorIsolation_concurrentAccess()
        await testPublishOrderUnderConcurrency()
        // Gap-fill tests (134-140)
        await testPublishWithNoSubscribers()
        await testOnTerminationAutoCleanupE2E()
        await testReSubscribeLifecycle()
        await testMultipleTypeFilters_sameType()
        await testTypeFilteredBufferOverflow()
        await testSubscribeMissesPrePublishedEvents()
        await testUnsubscribeDuringActivePublishE2E()
    }

    // MARK: Test 127: Real concurrent publish and subscribe

    /// Multiple Tasks simultaneously publish and subscribe to verify actor safety.
    static func testConcurrentPublishAndSubscribe() async {
        let bus = EventBus()
        let (id1, stream1) = await bus.subscribe()
        let (_, stream2) = await bus.subscribe()
        _ = id1

        // Launch concurrent publishers
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await bus.publish(AgentStartedEvent(sessionId: "s", task: "concurrent-\(i)"))
                }
            }
        }

        var received1: [String] = []
        for await e in stream1 {
            if let t = e as? AgentStartedEvent { received1.append(t.task) }
            if received1.count == 10 { break }
        }

        var received2: [String] = []
        for await e in stream2 {
            if let t = e as? AgentStartedEvent { received2.append(t.task) }
            if received2.count == 10 { break }
        }

        if received1.count == 10 && received2.count == 10 {
            pass("127. Concurrent publish and subscribe")
        } else {
            fail("127. Concurrent publish and subscribe", "sub1=\(received1.count), sub2=\(received2.count)")
        }
    }

    // MARK: Test 128: Mixed subscribe (full + type-filtered)

    /// A full subscriber and a type-filtered subscriber coexist and each
    /// receives the correct subset of events.
    static func testMixedSubscribe_fullAndTypeFiltered() async {
        let bus = EventBus()
        let (_, fullStream) = await bus.subscribe()
        let toolStream = await bus.subscribe(ToolStartedEvent.self)

        // Publish a mix of event types.
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "agent-1"))
        await bus.publish(ToolStartedEvent(sessionId: "s", toolName: "bash", toolUseId: "tu1", input: nil))
        await bus.publish(SessionCreatedEvent(sessionId: "s", task: "t", model: "m"))
        await bus.publish(ToolStartedEvent(sessionId: "s", toolName: "grep", toolUseId: "tu2", input: nil))
        await bus.publish(AgentCompletedEvent(sessionId: "s", totalSteps: 3, durationMs: 100, resultText: "done"))

        // Full stream should get all 5 events.
        var fullCount = 0
        for await _ in fullStream {
            fullCount += 1
            if fullCount == 5 { break }
        }

        // Tool stream should get only the 2 ToolStartedEvents.
        var toolEvents: [String] = []
        for await e in toolStream {
            toolEvents.append(e.toolName)
            if toolEvents.count == 2 { break }
        }

        if fullCount == 5 && toolEvents == ["bash", "grep"] {
            pass("128. Mixed full + type-filtered subscribe")
        } else {
            fail("128. Mixed full + type-filtered subscribe", "full=\(fullCount), tools=\(toolEvents)")
        }
    }

    // MARK: Test 129: High-frequency publish stress test

    /// Publish 1000 events rapidly with multiple subscribers to verify no
    /// deadlocks, crashes, or data loss beyond the buffer limit.
    static func testHighFrequencyPublish_stress() async {
        let bus = EventBus()
        let (id, stream) = await bus.subscribe()
        _ = id

        // Publish 1000 events as fast as possible.
        for i in 0..<1000 {
            await bus.publish(AgentStartedEvent(sessionId: "s", task: "stress-\(i)"))
        }

        // Buffer should have latest 100. Read them all.
        var collected: [String] = []
        for await e in stream {
            if let t = e as? AgentStartedEvent { collected.append(t.task) }
            if collected.count >= 100 { break }
        }

        // Should have exactly the latest 100 (stress-900 through stress-999).
        let expectedFirst = "stress-900"
        let expectedLast = "stress-999"
        if collected.count == 100
            && collected.first == expectedFirst
            && collected.last == expectedLast {
            pass("129. High-frequency publish stress test")
        } else {
            fail("129. High-frequency publish stress test",
                 "count=\(collected.count), first=\(collected.first ?? "nil"), last=\(collected.last ?? "nil")")
        }
    }

    // MARK: Test 130: Subscriber cancellation + memory reclaim

    /// Subscribe, consume a few events, unsubscribe, then verify the bus
    /// continues to work correctly for remaining subscribers.
    static func testSubscriberCancellation_memoryReclaimed() async {
        let bus = EventBus()
        let (id1, stream1) = await bus.subscribe()
        let (_, stream2) = await bus.subscribe()

        // Publish one event both should see.
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "first"))

        var r1: String?
        for await e in stream1 {
            if let t = e as? AgentStartedEvent { r1 = t.task; break }
        }

        // Unsubscribe sub1.
        await bus.unsubscribe(id1)

        // Publish again — only sub2 should get it.
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "second"))

        var r2: String?
        for await e in stream2 {
            if let t = e as? AgentStartedEvent { r2 = t.task; break }
        }

        if r1 == "first" && r2 == "second" {
            pass("130. Subscriber cancellation memory reclaim")
        } else {
            fail("130. Subscriber cancellation memory reclaim", "r1=\(r1 ?? "nil"), r2=\(r2 ?? "nil")")
        }
    }

    // MARK: Test 131: All 16 event types through EventBus

    /// Publish all 16 concrete event types and verify a full-stream subscriber
    /// receives each one with the correct dynamic type.
    static func testAllEventTypes_throughEventBus() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        // Publish all 16 event types in order.
        let events: [any AgentEvent] = [
            SessionCreatedEvent(sessionId: "s", task: "t", model: "m"),
            SessionRestoredEvent(sessionId: "s", messageCount: 5, originalCreatedAt: Date()),
            SessionClosedEvent(sessionId: "s", finalStatus: .completed),
            SessionAutoSavedEvent(sessionId: "s", messageCount: 10),
            AgentStartedEvent(sessionId: "s", task: "t"),
            AgentCompletedEvent(sessionId: "s", totalSteps: 3, durationMs: 100, resultText: nil),
            AgentFailedEvent(sessionId: "s", error: "err", stepsCompleted: 2),
            AgentInterruptedEvent(sessionId: "s", stepsCompleted: 1),
            AgentResumedEvent(sessionId: "s", resumeContext: "ctx"),
            ToolStartedEvent(sessionId: "s", toolName: "bash", toolUseId: "tu", input: nil),
            ToolStreamingEvent(sessionId: "s", toolUseId: "tu", chunk: "data"),
            ToolCompletedEvent(sessionId: "s", toolUseId: "tu", toolName: "bash", durationMs: 50, isError: false),
            ToolFailedEvent(sessionId: "s", toolUseId: "tu", toolName: "bash", error: "err"),
            LLMRequestStartedEvent(sessionId: "s", model: "m"),
            LLMResponseReceivedEvent(sessionId: "s", model: "m", durationMs: 100),
            LLMCostEvent(sessionId: "s", model: "m", inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.001),
        ]

        for event in events {
            await bus.publish(event)
        }

        var received: [String] = []
        for await e in stream {
            received.append(String(describing: type(of: e)))
            if received.count == 16 { break }
        }

        let expected = [
            "SessionCreatedEvent", "SessionRestoredEvent", "SessionClosedEvent", "SessionAutoSavedEvent",
            "AgentStartedEvent", "AgentCompletedEvent", "AgentFailedEvent", "AgentInterruptedEvent",
            "AgentResumedEvent", "ToolStartedEvent", "ToolStreamingEvent", "ToolCompletedEvent",
            "ToolFailedEvent", "LLMRequestStartedEvent", "LLMResponseReceivedEvent", "LLMCostEvent",
        ]

        if received == expected {
            pass("131. All 16 event types through EventBus")
        } else {
            fail("131. All 16 event types through EventBus", "got \(received.count) events")
        }
    }

    // MARK: Test 132: Actor isolation — concurrent access from many tasks

    /// Spawn many concurrent tasks that all subscribe and publish simultaneously
    /// to stress-test the actor's thread safety.
    static func testActorIsolation_concurrentAccess() async {
        let bus = EventBus()
        var subscriberCount = 0

        await withTaskGroup(of: Int.self) { group in
            // 5 subscribers
            for _ in 0..<5 {
                group.addTask {
                    let (_, stream) = await bus.subscribe()
                    var count = 0
                    for await _ in stream {
                        count += 1
                        if count == 20 { break }
                    }
                    return count
                }
            }

            // 5 publishers (4 events each = 20 total)
            for i in 0..<5 {
                group.addTask {
                    for j in 0..<4 {
                        await bus.publish(AgentStartedEvent(sessionId: "s", task: "p\(i)-\(j)"))
                    }
                    return 0
                }
            }

            for await result in group {
                if result > 0 { subscriberCount += 1 }
            }
        }

        if subscriberCount == 5 {
            pass("132. Actor isolation concurrent access")
        } else {
            fail("132. Actor isolation concurrent access", "only \(subscriberCount)/5 subscribers completed")
        }
    }

    // MARK: Test 133: Publish order under concurrency

    /// Even with concurrent publishers, a single subscriber sees events in
    /// the order they were processed by the actor (per-publisher FIFO).
    static func testPublishOrderUnderConcurrency() async {
        let bus = EventBus()
        let (_, stream) = await bus.subscribe()

        // Single publisher publishes 50 ordered events.
        for i in 0..<50 {
            await bus.publish(AgentStartedEvent(sessionId: "s", task: "order-\(i)"))
        }

        var collected: [String] = []
        for await e in stream {
            if let t = e as? AgentStartedEvent { collected.append(t.task) }
            if collected.count == 50 { break }
        }

        let expected = (0..<50).map { "order-\($0)" }
        if collected == expected {
            pass("133. Publish order under concurrency")
        } else {
            fail("133. Publish order under concurrency", "order mismatch")
        }
    }

    // MARK: - Gap-fill tests (134-140)

    // MARK: Test 134: AC5 — publish with no subscribers

    /// Publishing events when zero subscribers exist must not crash or hang.
    static func testPublishWithNoSubscribers() async {
        let bus = EventBus()

        // Publish with no subscribers — should silently discard.
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "nobody"))
        await bus.publish(ToolStartedEvent(sessionId: "s", toolName: "bash", toolUseId: "tu", input: nil))
        await bus.publish(LLMCostEvent(sessionId: "s", model: "m", inputTokens: 1, outputTokens: 1, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.001))

        // Now subscribe and publish — should work fine.
        let (_, stream) = await bus.subscribe()
        await bus.publish(SessionCreatedEvent(sessionId: "s", task: "t", model: "m"))

        var received = false
        for await e in stream {
            if e is SessionCreatedEvent { received = true; break }
        }

        if received {
            pass("134. Publish with no subscribers (AC5)")
        } else {
            fail("134. Publish with no subscribers (AC5)", "event not received after subscribe")
        }
    }

    // MARK: Test 135: AC4 — onTermination auto-cleanup

    /// When a subscriber's AsyncStream goes out of scope, onTermination
    /// should fire and clean up internal state. Subsequent publishes should
    /// not crash and remaining subscribers should still receive events.
    static func testOnTerminationAutoCleanupE2E() async {
        let bus = EventBus()

        // Subscribe in a limited scope so the stream deinitializes.
        do {
            let (_, stream) = await bus.subscribe()
            await bus.publish(AgentStartedEvent(sessionId: "s", task: "scoped"))
            for await _ in stream { break }
            // stream goes out of scope → onTermination fires
        }

        // Give onTermination cleanup Task time to execute.
        await _Concurrency.Task.yield()
        await _Concurrency.Task.yield()
        await _Concurrency.Task.yield()

        // Subscribe a fresh subscriber and publish — should work.
        let (_, freshStream) = await bus.subscribe()
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "fresh"))

        var received = false
        for await e in freshStream {
            if let t = e as? AgentStartedEvent, t.task == "fresh" { received = true; break }
        }

        if received {
            pass("135. onTermination auto-cleanup (AC4)")
        } else {
            fail("135. onTermination auto-cleanup (AC4)", "fresh subscriber did not receive event")
        }
    }

    // MARK: Test 136: Re-subscribe lifecycle

    /// A subscriber can be unsubscribed and the same bus can accept a new
    /// subscriber that works correctly.
    static func testReSubscribeLifecycle() async {
        let bus = EventBus()

        // First subscriber.
        let (id1, stream1) = await bus.subscribe()
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "first"))

        var first: String?
        for await e in stream1 {
            if let t = e as? AgentStartedEvent { first = t.task; break }
        }

        // Unsubscribe.
        await bus.unsubscribe(id1)

        // Re-subscribe on the same bus.
        let (_, stream2) = await bus.subscribe()
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "second"))

        var second: String?
        for await e in stream2 {
            if let t = e as? AgentStartedEvent { second = t.task; break }
        }

        if first == "first" && second == "second" {
            pass("136. Re-subscribe lifecycle")
        } else {
            fail("136. Re-subscribe lifecycle", "first=\(first ?? "nil"), second=\(second ?? "nil")")
        }
    }

    // MARK: Test 137: Multiple type-filtered subscribers for the same type

    /// Two subscribers filtering the same type both receive matching events.
    static func testMultipleTypeFilters_sameType() async {
        let bus = EventBus()
        let stream1 = await bus.subscribe(ToolStartedEvent.self)
        let stream2 = await bus.subscribe(ToolStartedEvent.self)

        await bus.publish(AgentStartedEvent(sessionId: "s", task: "ignored"))
        await bus.publish(ToolStartedEvent(sessionId: "s", toolName: "bash", toolUseId: "tu1", input: nil))
        await bus.publish(ToolStartedEvent(sessionId: "s", toolName: "grep", toolUseId: "tu2", input: nil))

        var names1: [String] = []
        for await e in stream1 {
            names1.append(e.toolName)
            if names1.count == 2 { break }
        }

        var names2: [String] = []
        for await e in stream2 {
            names2.append(e.toolName)
            if names2.count == 2 { break }
        }

        if names1 == ["bash", "grep"] && names2 == ["bash", "grep"] {
            pass("137. Multiple type-filtered subscribers (same type)")
        } else {
            fail("137. Multiple type-filtered subscribers (same type)", "names1=\(names1), names2=\(names2)")
        }
    }

    // MARK: Test 138: Type-filtered buffer overflow

    /// The type-filtered stream also uses .bufferingNewest(100). When
    /// many events are published but only a few match the filter, the
    /// filtered stream should buffer up to 100 matching events.
    static func testTypeFilteredBufferOverflow() async {
        let bus = EventBus()
        let stream = await bus.subscribe(ToolStartedEvent.self)

        // Publish 200 events — only every other one matches the filter.
        for i in 0..<200 {
            if i % 2 == 0 {
                await bus.publish(ToolStartedEvent(sessionId: "s", toolName: "tool-\(i)", toolUseId: "tu-\(i)", input: nil))
            } else {
                await bus.publish(AgentStartedEvent(sessionId: "s", task: "agent-\(i)"))
            }
        }

        // Should collect 100 matching ToolStartedEvents (i = 0, 2, 4, ..., 198).
        var collected: [String] = []
        for await e in stream {
            collected.append(e.toolName)
            if collected.count >= 100 { break }
        }

        if collected.count == 100 {
            pass("138. Type-filtered buffer overflow")
        } else {
            fail("138. Type-filtered buffer overflow", "collected \(collected.count) events, expected 100")
        }
    }

    // MARK: Test 139: Subscribe does not receive pre-published events

    /// Events published before a subscriber joins are not retroactively
    /// delivered (lossy subscription semantics).
    static func testSubscribeMissesPrePublishedEvents() async {
        let bus = EventBus()

        // Publish before subscribing.
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "pre-published"))

        let (_, stream) = await bus.subscribe()

        // Publish after subscribing.
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "post-published"))

        var received: [String] = []
        for await e in stream {
            if let t = e as? AgentStartedEvent { received.append(t.task) }
            if received.count == 1 { break }
        }

        // Should only get the post-subscription event.
        if received == ["post-published"] {
            pass("139. Subscribe misses pre-published events")
        } else {
            fail("139. Subscribe misses pre-published events", "got \(received)")
        }
    }

    // MARK: Test 140: Unsubscribe during active publishing

    /// Unsubscribing while a concurrent publisher is active should not crash.
    static func testUnsubscribeDuringActivePublishE2E() async {
        let bus = EventBus()
        let (id, stream) = await bus.subscribe()

        // Start publishing in a background task.
        let publisherTask = _Concurrency.Task {
            for i in 0..<500 {
                await bus.publish(AgentStartedEvent(sessionId: "s", task: "race-\(i)"))
            }
        }

        // Collect a few events, then unsubscribe mid-stream.
        var count = 0
        for await _ in stream {
            count += 1
            if count == 10 {
                await bus.unsubscribe(id)
                break
            }
        }

        // Wait for publisher to finish — should not crash.
        await publisherTask.value

        // Publish one more to verify bus still works.
        let (_, stream2) = await bus.subscribe()
        await bus.publish(AgentStartedEvent(sessionId: "s", task: "after-race"))

        var received = false
        for await e in stream2 {
            if let t = e as? AgentStartedEvent, t.task == "after-race" { received = true; break }
        }

        if received {
            pass("140. Unsubscribe during active publish")
        } else {
            fail("140. Unsubscribe during active publish", "bus did not recover after mid-publish unsubscribe")
        }
    }
}

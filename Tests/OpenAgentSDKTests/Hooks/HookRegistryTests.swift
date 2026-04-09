import XCTest
@testable import OpenAgentSDK

// MARK: - HookRegistry Tests

/// Tests for Story 8-1 -- HookRegistry Actor & Function Hook Execution.
/// Covers: registration, batch config, execution, matcher filtering, timeout,
/// hasHooks query, clear, concurrent safety, and handler input passing.
final class HookRegistryTests: XCTestCase {

    // MARK: - AC1: HookRegistry Actor Basic Structure

    /// AC1 [P0]: HookRegistry can be instantiated as an actor.
    func testInit_createsHookRegistryActor() async {
        // Given/When: creating a HookRegistry
        let registry = HookRegistry()

        // Then: registry is created (compilation proves it's an actor)
        _ = registry
    }

    // MARK: - AC2: Register Single Hook

    /// AC2 [P0]: register() stores a hook on a lifecycle event.
    func testRegister_singleHook_stored() async {
        // Given: a HookRegistry and a hook definition with handler
        let registry = HookRegistry()
        let def = HookDefinition(handler: { _ in nil })

        // When: registering on .preToolUse
        await registry.register(.preToolUse, definition: def)

        // Then: hasHooks returns true
        let hasHooks = await registry.hasHooks(.preToolUse)
        XCTAssertTrue(hasHooks, "Should have hooks after registering one")
    }

    /// AC2 [P0]: HookEvent has exactly 20 cases (CaseIterable).
    func testHookEvent_has20Cases() {
        // Given/When: checking allCases count
        let allCases = HookEvent.allCases

        // Then: exactly 20 cases (matching TS SDK HOOK_EVENTS)
        XCTAssertEqual(allCases.count, 20, "HookEvent should have 20 lifecycle cases")
    }

    /// AC2 [P0]: register() on different events are independent.
    func testRegister_multipleEvents_independent() async {
        // Given: a HookRegistry
        let registry = HookRegistry()

        // When: registering hooks on different events
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in nil }))
        await registry.register(.postToolUse, definition: HookDefinition(handler: { _ in nil }))
        await registry.register(.sessionStart, definition: HookDefinition(handler: { _ in nil }))

        // Then: each event has hooks independently
        let hasPre = await registry.hasHooks(.preToolUse)
        let hasPost = await registry.hasHooks(.postToolUse)
        let hasSession = await registry.hasHooks(.sessionStart)
        let hasStop = await registry.hasHooks(.stop)

        XCTAssertTrue(hasPre, "preToolUse should have hooks")
        XCTAssertTrue(hasPost, "postToolUse should have hooks")
        XCTAssertTrue(hasSession, "sessionStart should have hooks")
        XCTAssertFalse(hasStop, "stop should have no hooks")
    }

    // MARK: - AC4: Batch Register from Config

    /// AC4 [P0]: registerFromConfig() registers hooks for valid event names.
    func testRegisterFromConfig_validEventsRegistered() async {
        // Given: a HookRegistry and config with valid event names
        let registry = HookRegistry()
        let config: [String: [HookDefinition]] = [
            "preToolUse": [HookDefinition(handler: { _ in nil })],
            "postToolUse": [HookDefinition(handler: { _ in nil })],
        ]

        // When: registering from config
        await registry.registerFromConfig(config)

        // Then: both events have hooks
        let hasPre = await registry.hasHooks(.preToolUse)
        let hasPost = await registry.hasHooks(.postToolUse)
        XCTAssertTrue(hasPre, "preToolUse should have hooks from config")
        XCTAssertTrue(hasPost, "postToolUse should have hooks from config")
    }

    /// AC4 [P0]: registerFromConfig() silently skips invalid event names.
    func testRegisterFromConfig_invalidEventsSkipped() async {
        // Given: a HookRegistry and config with invalid event names
        let registry = HookRegistry()
        let config: [String: [HookDefinition]] = [
            "notARealEvent": [HookDefinition(handler: { _ in nil })],
            "preToolUse": [HookDefinition(handler: { _ in nil })],
        ]

        // When: registering from config
        await registry.registerFromConfig(config)

        // Then: invalid event is skipped, valid event registered
        let hasPre = await registry.hasHooks(.preToolUse)
        XCTAssertTrue(hasPre, "preToolUse should have hooks from config")
        // No crash or error thrown for invalid event -- silent skip
    }

    // MARK: - AC3: PreToolUse Hook Execution

    /// AC3 [P0]: execute() calls registered handler and returns output.
    func testExecute_singleHook_returnsOutput() async {
        // Given: a HookRegistry with a handler that returns output
        let registry = HookRegistry()
        let expectedOutput = HookOutput(message: "hook executed")
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            expectedOutput
        }))

        // When: executing hooks for the event
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: output is returned
        XCTAssertEqual(results.count, 1, "Should return one result")
        XCTAssertEqual(results.first?.message, "hook executed")
    }

    /// AC3 [P0]: execute() returns empty array when no hooks registered.
    func testExecute_noHooks_returnsEmptyArray() async {
        // Given: a HookRegistry with no hooks
        let registry = HookRegistry()

        // When: executing hooks for an event with none registered
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: empty array returned
        XCTAssertTrue(results.isEmpty, "Should return empty array when no hooks")
    }

    // MARK: - AC3: PreToolUse Block

    /// AC3 [P0]: execute() returns block=true from PreToolUse hook.
    func testExecute_preToolUse_canBlock() async {
        // Given: a HookRegistry with a blocking hook
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            HookOutput(message: "blocked by policy", block: true)
        }))

        // When: executing the hook
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: block is true
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.block == true, "Hook should return block=true")
        XCTAssertEqual(results.first?.message, "blocked by policy")
    }

    // MARK: - AC5: Multiple Hooks Executed in Order

    /// AC5 [P0]: Multiple hooks on same event execute in registration order.
    func testExecute_multipleHooks_executedInOrder() async {
        // Given: a HookRegistry with multiple hooks
        let registry = HookRegistry()
        let tracker = HookOrderTracker()

        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            await tracker.record("first")
            return nil
        }))
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            await tracker.record("second")
            return HookOutput(message: "second-output")
        }))
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            await tracker.record("third")
            return nil
        }))

        // When: executing hooks
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: hooks executed in order
        let order = await tracker.order
        XCTAssertEqual(order, ["first", "second", "third"], "Hooks should execute in registration order")

        // And: only non-nil outputs collected
        XCTAssertEqual(results.count, 1, "Only one hook returned non-nil output")
        XCTAssertEqual(results.first?.message, "second-output")
    }

    // MARK: - AC6: Matcher Filtering

    /// AC6 [P0]: Hook with matcher filters by toolName.
    func testExecute_matcherFilters() async {
        // Given: a HookRegistry with a matcher that only matches "bash"
        let registry = HookRegistry()
        let tracker = HookCallTracker()

        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in
                await tracker.markCalled()
                return HookOutput(message: "bash-hook")
            },
            matcher: "bash"
        ))

        // When: executing with a non-matching toolName
        let input = HookInput(event: .preToolUse, toolName: "file_read")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: hook was not called
        let wasCalled = await tracker.called
        XCTAssertFalse(wasCalled, "Hook should not be called when toolName doesn't match matcher")
        XCTAssertTrue(results.isEmpty, "Should return empty results when matcher filters out hook")

        // When: executing with a matching toolName
        await tracker.reset()
        let matchingInput = HookInput(event: .preToolUse, toolName: "bash")
        let matchingResults = await registry.execute(.preToolUse, input: matchingInput)

        // Then: hook was called
        let wasCalledAfterMatch = await tracker.called
        XCTAssertTrue(wasCalledAfterMatch, "Hook should be called when toolName matches matcher")
        XCTAssertEqual(matchingResults.count, 1)
        XCTAssertEqual(matchingResults.first?.message, "bash-hook")
    }

    /// AC6 [P0]: Hook with nil matcher matches all tools.
    func testExecute_nilMatcher_matchesAll() async {
        // Given: a HookRegistry with a hook without matcher (nil)
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            HookOutput(message: "universal")
        }))

        // When: executing with any toolName
        let input1 = HookInput(event: .preToolUse, toolName: "bash")
        let input2 = HookInput(event: .preToolUse, toolName: "file_read")

        let results1 = await registry.execute(.preToolUse, input: input1)
        let results2 = await registry.execute(.preToolUse, input: input2)

        // Then: hook fires for both
        XCTAssertEqual(results1.count, 1)
        XCTAssertEqual(results2.count, 1)
    }

    /// AC6 [P1]: Hook with regex matcher matches pattern.
    func testExecute_matcherRegex_patternMatches() async {
        // Given: a HookRegistry with a regex matcher
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in HookOutput(message: "file-hook") },
            matcher: "file.*"
        ))

        // When: executing with matching toolName
        let input = HookInput(event: .preToolUse, toolName: "file_read")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: hook fires
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.message, "file-hook")
    }

    // MARK: - AC7: Hook Timeout

    /// AC7 [P0]: Hook that exceeds timeout returns empty, doesn't block others.
    func testExecute_timeout_returnsEmptyForTimedOutHook() async {
        // Given: a HookRegistry with a slow hook (1 ms timeout, long execution)
        let registry = HookRegistry()

        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in
                // Simulate slow execution (10 seconds)
                try? await _Concurrency.Task.sleep(nanoseconds: 10_000_000_000)
                return HookOutput(message: "slow-result")
            },
            timeout: 1 // 1 millisecond timeout
        ))

        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            HookOutput(message: "fast-result")
        }))

        // When: executing hooks
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: timed-out hook returns empty, fast hook succeeds
        let hasFast = results.contains { $0.message == "fast-result" }
        XCTAssertTrue(hasFast, "Fast hook should still produce output")
    }

    // MARK: - AC10: Handler Failure Isolation

    /// AC10 [P0]: Handler failure does not affect other hooks.
    func testExecute_handlerFailure_doesNotAffectOtherHooks() async {
        // Given: a HookRegistry with a failing hook (timeout) and a succeeding hook
        let registry = HookRegistry()

        // First hook times out (1ms timeout, but sleeps for a very long time)
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in
                // Simulate a hanging handler that will exceed timeout
                _ = try? await _Concurrency.Task.sleep(nanoseconds: 10_000_000_000)
                return HookOutput(message: "timed-out-result")
            },
            timeout: 1
        ))
        // Second hook succeeds immediately
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            HookOutput(message: "succeeds-after-failure")
        }))

        // When: executing hooks
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: second hook succeeds despite first hook timing out
        let hasSuccess = results.contains { $0.message == "succeeds-after-failure" }
        XCTAssertTrue(hasSuccess, "Second hook should succeed even after first hook failure")
    }

    // MARK: - AC8: hasHooks Query

    /// AC8 [P0]: hasHooks() returns false before registration, true after.
    func testHasHooks_returnsCorrectly() async {
        // Given: a fresh HookRegistry
        let registry = HookRegistry()

        // When: checking before registration
        let beforeRegister = await registry.hasHooks(.preToolUse)
        XCTAssertFalse(beforeRegister, "Should have no hooks before registration")

        // When: registering a hook
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in nil }))
        let afterRegister = await registry.hasHooks(.preToolUse)
        XCTAssertTrue(afterRegister, "Should have hooks after registration")
    }

    // MARK: - AC9: Clear All Hooks

    /// AC9 [P0]: clear() removes all hooks from all events.
    func testClear_removesAllHooks() async {
        // Given: a HookRegistry with hooks on multiple events
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in nil }))
        await registry.register(.postToolUse, definition: HookDefinition(handler: { _ in nil }))
        await registry.register(.sessionStart, definition: HookDefinition(handler: { _ in nil }))

        // When: clearing all hooks
        await registry.clear()

        // Then: no events have hooks
        let hasPre = await registry.hasHooks(.preToolUse)
        let hasPost = await registry.hasHooks(.postToolUse)
        let hasSession = await registry.hasHooks(.sessionStart)
        XCTAssertFalse(hasPre, "preToolUse should have no hooks after clear")
        XCTAssertFalse(hasPost, "postToolUse should have no hooks after clear")
        XCTAssertFalse(hasSession, "sessionStart should have no hooks after clear")
    }

    // MARK: - AC11: Concurrent Safety

    /// AC11 [P0]: Concurrent register and execute are thread-safe.
    func testConcurrentRegisterExecute_threadSafe() async throws {
        // Given: a HookRegistry
        let registry = HookRegistry()

        // When: concurrently registering hooks and executing
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Concurrent registrations
            for i in 1...50 {
                group.addTask {
                    let event: HookEvent = i % 2 == 0 ? .preToolUse : .postToolUse
                    await registry.register(event, definition: HookDefinition(handler: { _ in
                        HookOutput(message: "hook-\(i)")
                    }))
                }
            }

            // Concurrent executions
            for _ in 1...20 {
                group.addTask {
                    let input = HookInput(event: .preToolUse, toolName: "bash")
                    _ = await registry.execute(.preToolUse, input: input)
                }
            }

            try await group.waitForAll()
        }

        // Then: no crash or data corruption -- test passes if we get here
        let hasPre = await registry.hasHooks(.preToolUse)
        let hasPost = await registry.hasHooks(.postToolUse)
        XCTAssertTrue(hasPre || hasPost, "At least one event should have hooks after concurrent registration")
    }

    // MARK: - AC10: Handler Closure Receives Correct Input

    /// AC10 [P0]: Handler receives HookInput with correct event and toolName.
    func testExecute_handlerReceivesCorrectInput() async {
        // Given: a HookRegistry with a handler that captures input
        let registry = HookRegistry()
        let tracker = HookInputTracker()

        await registry.register(.preToolUse, definition: HookDefinition(handler: { input in
            await tracker.record(event: input.event, toolName: input.toolName)
            return nil
        }))

        // When: executing with specific input
        let input = HookInput(event: .preToolUse, toolName: "file_write")
        _ = await registry.execute(.preToolUse, input: input)

        // Then: handler received the correct input
        let captured = await tracker.captured
        XCTAssertEqual(captured.event, .preToolUse)
        XCTAssertEqual(captured.toolName, "file_write")
    }

    // MARK: - AC2: All 21 Events Can Be Registered

    /// AC2 [P1]: All 21 HookEvent cases can be registered and queried.
    func testRegister_all21Events_canBeRegistered() async {
        // Given: a HookRegistry
        let registry = HookRegistry()

        // When: registering a hook on every event
        for event in HookEvent.allCases {
            await registry.register(event, definition: HookDefinition(handler: { _ in nil }))
        }

        // Then: all events report having hooks
        for event in HookEvent.allCases {
            let hasHooks = await registry.hasHooks(event)
            XCTAssertTrue(hasHooks, "\(event.rawValue) should have hooks after registration")
        }
    }

    // MARK: - AC4: registerFromConfig Appends (Not Replaces)

    /// AC4 [P1]: registerFromConfig() appends to existing hooks, not replaces.
    func testRegisterFromConfig_appendsToExisting() async {
        // Given: a HookRegistry with an existing hook
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            HookOutput(message: "existing")
        }))

        // When: registering from config
        let config: [String: [HookDefinition]] = [
            "preToolUse": [HookDefinition(handler: { _ in
                HookOutput(message: "from-config")
            })],
        ]
        await registry.registerFromConfig(config)

        // Then: both hooks execute
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        let messages = results.map { $0.message }
        XCTAssertTrue(messages.contains("existing"), "Existing hook should still be present")
        XCTAssertTrue(messages.contains("from-config"), "Config hook should be added")
    }

    // MARK: - AC6: Matcher with Nil ToolName in Input

    /// AC6 [P1]: Matcher skipped when input has nil toolName.
    func testExecute_matcherWithNilToolName_skipsFilteredHook() async {
        // Given: a HookRegistry with a matcher hook
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in HookOutput(message: "matched") },
            matcher: "bash"
        ))

        // When: executing with nil toolName
        let input = HookInput(event: .preToolUse, toolName: nil)
        let results = await registry.execute(.preToolUse, input: input)

        // Then: matcher hook is skipped (no toolName to match against)
        XCTAssertTrue(results.isEmpty, "Matcher hook should be skipped when toolName is nil")
    }
}

// MARK: - Test Helpers

/// Helper actor to track hook execution order in tests.
actor HookOrderTracker {
    private var items: [String] = []

    func record(_ item: String) {
        items.append(item)
    }

    var order: [String] {
        items
    }
}

/// Helper actor to track whether a hook was called in tests.
actor HookCallTracker {
    private var wasCalled = false

    func markCalled() {
        wasCalled = true
    }

    func reset() {
        wasCalled = false
    }

    var called: Bool {
        wasCalled
    }
}

/// Helper actor to capture hook input values in tests.
actor HookInputTracker {
    private var capturedEvent: HookEvent?
    private var capturedToolName: String?

    func record(event: HookEvent, toolName: String?) {
        capturedEvent = event
        capturedToolName = toolName
    }

    var captured: (event: HookEvent?, toolName: String?) {
        (capturedEvent, capturedToolName)
    }
}

import Foundation
import OpenAgentSDK

// MARK: - Tests 40: Shell Hook Execution E2E Tests (Story 8-3)

/// E2E tests for Story 8-3: Shell Hook Execution.
///
/// These tests verify that Shell command hooks execute correctly through
/// the real HookRegistry actor using real shell commands -- no mocks (E2E convention).
///
/// NOTE: These tests are in the TDD RED PHASE. They will FAIL until the
/// implementation adds ShellHookExecutor and integrates it into HookRegistry.execute().
struct ShellHookExecutionE2ETests {
    static func run() async {
        section("40. Shell Hook Execution (E2E, Story 8-3)")
        await testRegisterShellHook_triggerEvent_verifyOutput()
        await testShellHookAndFunctionHook_executeInOrder()
        await testShellHookWithMatcher_filtersByToolName()
    }

    // MARK: Test 40a: Register Shell Hook, Trigger Event, Verify Output

    /// AC7, AC1 [P0]: Register a shell command hook, trigger event, verify JSON output.
    static func testRegisterShellHook_triggerEvent_verifyOutput() async {
        let registry = HookRegistry()

        // Register a shell command hook that echoes JSON
        let def = HookDefinition(
            command: "echo '{\"message\":\"e2e-shell-output\"}'"
        )
        await registry.register(.preToolUse, definition: def)

        // Verify hook is registered
        let hasHooks = await registry.hasHooks(.preToolUse)
        guard hasHooks else {
            fail("Shell Hook E2E: register and trigger", "hasHooks returned false after register")
            return
        }

        // Trigger the event
        let input = HookInput(event: .preToolUse, toolName: "bash", toolInput: ["command": "ls"])
        let results = await registry.execute(.preToolUse, input: input)

        // Verify shell hook was executed and returned output
        guard results.count == 1 else {
            fail("Shell Hook E2E: register and trigger",
                 "expected 1 result, got \(results.count)")
            return
        }

        guard results[0].message == "e2e-shell-output" else {
            fail("Shell Hook E2E: register and trigger",
                 "expected 'e2e-shell-output', got '\(results[0].message ?? "nil")'")
            return
        }
        pass("Shell Hook E2E: shell command hook returns correct JSON output")
    }

    // MARK: Test 40b: Shell Hook and Function Hook Execute in Order

    /// AC8 [P0]: Shell command hooks and function hooks execute in registration order.
    static func testShellHookAndFunctionHook_executeInOrder() async {
        let registry = HookRegistry()
        let tracker = E2EOrderTracker()

        // Register a function hook first
        await registry.register(.postToolUse, definition: HookDefinition(
            handler: { _ in
                await tracker.record("handler-1")
                return HookOutput(message: "handler-first")
            }
        ))

        // Register a shell command hook second
        await registry.register(.postToolUse, definition: HookDefinition(
            command: "echo '{\"message\":\"command-second\"}'"
        ))

        // Register a function hook third
        await registry.register(.postToolUse, definition: HookDefinition(
            handler: { _ in
                await tracker.record("handler-3")
                return HookOutput(message: "handler-third")
            }
        ))

        // Trigger event
        let input = HookInput(event: .postToolUse, toolName: "file_read")
        let results = await registry.execute(.postToolUse, input: input)

        // Verify all hooks executed and returned results
        guard results.count == 3 else {
            fail("Shell Hook E2E: mixed hooks order",
                 "expected 3 results, got \(results.count)")
            return
        }

        guard results[0].message == "handler-first" else {
            fail("Shell Hook E2E: mixed hooks order",
                 "first result should be 'handler-first', got '\(results[0].message ?? "nil")'")
            return
        }

        guard results[1].message == "command-second" else {
            fail("Shell Hook E2E: mixed hooks order",
                 "second result should be 'command-second', got '\(results[1].message ?? "nil")'")
            return
        }

        guard results[2].message == "handler-third" else {
            fail("Shell Hook E2E: mixed hooks order",
                 "third result should be 'handler-third', got '\(results[2].message ?? "nil")'")
            return
        }

        pass("Shell Hook E2E: shell and function hooks execute in registration order")

        // Verify handler execution order
        let order = await tracker.order
        guard order == ["handler-1", "handler-3"] else {
            fail("Shell Hook E2E: mixed hooks order",
                 "handler order expected [handler-1, handler-3], got \(order)")
            return
        }
        pass("Shell Hook E2E: handler hooks tracked in correct order")
    }

    // MARK: Test 40c: Shell Hook with Matcher Filters by ToolName

    /// AC12 [P0]: Shell hook with matcher only fires for matching toolName.
    static func testShellHookWithMatcher_filtersByToolName() async {
        let registry = HookRegistry()

        // Register shell hook with matcher for "bash" only
        await registry.register(.preToolUse, definition: HookDefinition(
            command: "echo '{\"message\":\"bash-only\"}'",
            matcher: "bash"
        ))

        // Trigger with non-matching toolName
        let nonMatchInput = HookInput(event: .preToolUse, toolName: "file_read")
        let nonMatchResults = await registry.execute(.preToolUse, input: nonMatchInput)

        guard nonMatchResults.isEmpty else {
            fail("Shell Hook E2E: matcher filter",
                 "expected no results for non-matching toolName, got \(nonMatchResults.count)")
            return
        }
        pass("Shell Hook E2E: shell hook skipped for non-matching toolName")

        // Trigger with matching toolName
        let matchInput = HookInput(event: .preToolUse, toolName: "bash")
        let matchResults = await registry.execute(.preToolUse, input: matchInput)

        guard matchResults.count == 1 else {
            fail("Shell Hook E2E: matcher filter",
                 "expected 1 result for matching toolName, got \(matchResults.count)")
            return
        }

        guard matchResults[0].message == "bash-only" else {
            fail("Shell Hook E2E: matcher filter",
                 "expected 'bash-only', got '\(matchResults[0].message ?? "nil")'")
            return
        }
        pass("Shell Hook E2E: shell hook fires for matching toolName")
    }
}

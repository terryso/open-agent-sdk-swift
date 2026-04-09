import Foundation
import OpenAgentSDK

// MARK: - Tests 38: HookRegistry E2E Tests

/// E2E tests for HookRegistry (Story 8-1).
/// Uses real HookRegistry actor -- no mocks (E2E convention).
struct HookRegistryE2ETests {
    static func run() async {
        section("38. HookRegistry (E2E)")
        await testRegisterAndTrigger_verifyOutput()
        await testMultipleHooks_executeInOrder()
    }

    // MARK: Test 38a: Register Hook and Trigger Event, Verify Output

    static func testRegisterAndTrigger_verifyOutput() async {
        let registry = HookRegistry()
        let tracker = E2ECallTracker()

        let def = HookDefinition(handler: { (input: HookInput) -> HookOutput? in
            await tracker.markCalled()
            return HookOutput(message: "e2e-hook-output", block: false)
        })

        // Register hook on preToolUse
        await registry.register(.preToolUse, definition: def)

        // Verify hook is registered
        let hasHooks = await registry.hasHooks(.preToolUse)
        guard hasHooks else {
            fail("HookRegistry E2E: register and trigger", "hasHooks returned false after register")
            return
        }

        // Trigger the event
        let input = HookInput(event: .preToolUse, toolName: "bash", toolInput: ["command": "ls"])
        let results = await registry.execute(.preToolUse, input: input)

        // Verify hook was called and returned output
        let wasCalled = await tracker.called
        guard wasCalled else {
            fail("HookRegistry E2E: register and trigger", "handler was not called")
            return
        }
        pass("HookRegistry E2E: handler was called on event trigger")

        guard results.count == 1 else {
            fail("HookRegistry E2E: register and trigger", "expected 1 result, got \(results.count)")
            return
        }

        guard results[0].message == "e2e-hook-output" else {
            fail("HookRegistry E2E: register and trigger", "expected 'e2e-hook-output', got '\(results[0].message ?? "nil")'")
            return
        }
        pass("HookRegistry E2E: hook returns correct output after event trigger")
    }

    // MARK: Test 38b: Multiple Hooks Execute in Order

    static func testMultipleHooks_executeInOrder() async {
        let registry = HookRegistry()
        let tracker = E2EOrderTracker()

        // Register 3 hooks in order
        await registry.register(.postToolUse, definition: HookDefinition(handler: { _ in
            await tracker.record("hook-1")
            return HookOutput(message: "first")
        }))
        await registry.register(.postToolUse, definition: HookDefinition(handler: { _ in
            await tracker.record("hook-2")
            return HookOutput(message: "second")
        }))
        await registry.register(.postToolUse, definition: HookDefinition(handler: { _ in
            await tracker.record("hook-3")
            return HookOutput(message: "third")
        }))

        // Trigger event
        let input = HookInput(event: .postToolUse, toolName: "file_read")
        let results = await registry.execute(.postToolUse, input: input)

        // Verify execution order
        let order = await tracker.order

        guard order == ["hook-1", "hook-2", "hook-3"] else {
            fail("HookRegistry E2E: multi-hook order", "expected [hook-1, hook-2, hook-3], got \(order)")
            return
        }
        pass("HookRegistry E2E: multiple hooks execute in registration order")

        // Verify all outputs collected
        guard results.count == 3 else {
            fail("HookRegistry E2E: multi-hook outputs", "expected 3 results, got \(results.count)")
            return
        }

        let messages = results.map { $0.message }
        guard messages == ["first", "second", "third"] else {
            fail("HookRegistry E2E: multi-hook outputs", "expected [first, second, third], got \(messages)")
            return
        }
        pass("HookRegistry E2E: all hook outputs collected in order")
    }
}

// MARK: - E2E Test Helpers

/// Helper actor to track hook execution order in E2E tests.
actor E2EOrderTracker {
    private var items: [String] = []

    func record(_ item: String) {
        items.append(item)
    }

    var order: [String] {
        items
    }
}

/// Helper actor to track whether a hook was called in E2E tests.
actor E2ECallTracker {
    private var wasCalled = false

    func markCalled() {
        wasCalled = true
    }

    var called: Bool {
        wasCalled
    }
}

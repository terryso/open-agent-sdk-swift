import Foundation
import OpenAgentSDK

// MARK: - Tests 39: Hook Integration E2E Tests (Story 8-2)

/// E2E tests for Story 8-2: Function Hook Registration & Execution.
///
/// These tests verify that hooks are actually triggered during real Agent execution.
/// Uses real HookRegistry actor and real LLM API calls -- no mocks (E2E convention).
///
/// NOTE: These tests are in the TDD RED PHASE. They will FAIL until the
/// implementation adds hook trigger points to Agent.prompt()/stream() and
/// ToolExecutor.executeSingleTool().
struct HookIntegrationE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("39. Hook Integration (E2E, Story 8-2)")
        await testSessionStartEnd_hooksTriggeredViaPrompt(
            apiKey: apiKey, model: model, baseURL: baseURL
        )
        await testPreToolUse_blockPreventsToolExecution(
            apiKey: apiKey, model: model, baseURL: baseURL
        )
        await testMultipleHooks_executeInOrderDuringAgentRun(
            apiKey: apiKey, model: model, baseURL: baseURL
        )
    }

    // MARK: Test 39a: SessionStart/SessionEnd Hooks Triggered via prompt()

    /// AC2, AC7 [P0]: sessionStart and sessionEnd hooks fire during Agent.prompt().
    static func testSessionStartEnd_hooksTriggeredViaPrompt(
        apiKey: String, model: String, baseURL: String
    ) async {
        let registry = HookRegistry()
        let tracker = E2ELifecycleTracker()

        // Register sessionStart hook
        await registry.register(.sessionStart, definition: HookDefinition(handler: { input in
            await tracker.record(event: input.event.rawValue)
            return nil
        }))

        // Register sessionEnd hook
        await registry.register(.sessionEnd, definition: HookDefinition(handler: { input in
            await tracker.record(event: input.event.rawValue)
            return nil
        }))

        // Create agent with hookRegistry
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            maxTurns: 1,
            hookRegistry: registry
        )
        let agent = createAgent(options: options)

        // Run prompt
        _ = await agent.prompt("Say 'hook test ok'.")

        // Verify sessionStart was triggered
        let events = await tracker.events
        let hasSessionStart = events.contains("sessionStart")
        guard hasSessionStart else {
            fail("Hook Integration E2E: sessionStart triggered", "sessionStart not in events: \(events)")
            return
        }
        pass("Hook Integration E2E: sessionStart hook triggered during prompt()")

        // Verify sessionEnd was triggered
        let hasSessionEnd = events.contains("sessionEnd")
        guard hasSessionEnd else {
            fail("Hook Integration E2E: sessionEnd triggered", "sessionEnd not in events: \(events)")
            return
        }
        pass("Hook Integration E2E: sessionEnd hook triggered during prompt()")
    }

    // MARK: Test 39b: PreToolUse Hook Blocks Tool Execution via Agent

    /// AC4 [P0]: PreToolUse hook blocks tool execution, agent receives error.
    static func testPreToolUse_blockPreventsToolExecution(
        apiKey: String, model: String, baseURL: String
    ) async {
        let registry = HookRegistry()
        let tracker = E2ECallTracker()

        // Register a blocking PreToolUse hook for "bash" tool
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { input in
                await tracker.markCalled()
                if input.toolName == "bash" {
                    return HookOutput(message: "bash is blocked by policy", block: true)
                }
                return nil
            },
            matcher: "bash"
        ))

        // Create agent with hookRegistry and a bash-capable setup
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            maxTurns: 2,
            hookRegistry: registry
        )
        let agent = createAgent(options: options)

        // Ask the agent to run a bash command
        // The LLM should attempt to use bash tool, which the hook blocks
        let result = await agent.prompt("Use the bash tool to run 'echo hello'.")

        // Verify the preToolUse hook was called
        let wasCalled = await tracker.called
        guard wasCalled else {
            // This may fail if the LLM doesn't choose to use bash tool
            // In that case, the test setup needs adjustment
            fail("Hook Integration E2E: PreToolUse hook called for bash",
                 "hook was not called — LLM may not have used bash tool")
            return
        }
        pass("Hook Integration E2E: PreToolUse hook was called for bash tool")

        // The agent should still complete (not crash)
        guard result.status == .success else {
            fail("Hook Integration E2E: agent completes with blocked tool",
                 "status: \(result.status)")
            return
        }
        pass("Hook Integration E2E: agent completes successfully despite tool block")
    }

    // MARK: Test 39c: Multiple Hooks Execute in Order During Agent Run

    /// AC3 [P0]: Multiple hooks on the same event execute in registration order.
    static func testMultipleHooks_executeInOrderDuringAgentRun(
        apiKey: String, model: String, baseURL: String
    ) async {
        let registry = HookRegistry()
        let tracker = E2EOrderTracker()

        // Register 3 hooks on sessionStart, in order
        await registry.register(.sessionStart, definition: HookDefinition(handler: { _ in
            await tracker.record("hook-1")
            return HookOutput(message: "first")
        }))
        await registry.register(.sessionStart, definition: HookDefinition(handler: { _ in
            await tracker.record("hook-2")
            return HookOutput(message: "second")
        }))
        await registry.register(.sessionStart, definition: HookDefinition(handler: { _ in
            await tracker.record("hook-3")
            return HookOutput(message: "third")
        }))

        // Create agent and run prompt
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            maxTurns: 1,
            hookRegistry: registry
        )
        let agent = createAgent(options: options)
        _ = await agent.prompt("Say 'order test ok'.")

        // Verify hooks executed in order
        let order = await tracker.order
        guard order == ["hook-1", "hook-2", "hook-3"] else {
            fail("Hook Integration E2E: multi-hook order during agent run",
                 "expected [hook-1, hook-2, hook-3], got \(order)")
            return
        }
        pass("Hook Integration E2E: multiple hooks execute in registration order during agent run")
    }
}

// MARK: - E2E Test Helper Actors

/// Tracks lifecycle events in E2E tests.
actor E2ELifecycleTracker {
    private var items: [String] = []

    func record(event: String) {
        items.append(event)
    }

    var events: [String] {
        items
    }
}

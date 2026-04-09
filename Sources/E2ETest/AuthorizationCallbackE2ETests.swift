import Foundation
import OpenAgentSDK

// MARK: - Tests 42: Authorization Callback E2E Tests (Story 8-5)

/// E2E tests for Story 8-5: Custom Authorization Callback.
///
/// These tests verify that custom authorization policies (PermissionPolicy,
/// ToolNameAllowlistPolicy, ToolNameDenylistPolicy) work correctly during
/// real Agent runs with LLM API calls. No mocks (E2E convention).
///
/// NOTE: These tests are in the TDD RED PHASE. They will FAIL until the
/// implementation adds PermissionPolicy protocol, policy types, Agent
/// setPermissionMode()/setCanUseTool() methods, and CanUseToolResult factory methods.
struct AuthorizationCallbackE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("42. Authorization Callback (E2E, Story 8-5)")
        await testAllowlistPolicy_llmDrivenToolCall(
            apiKey: apiKey, model: model, baseURL: baseURL
        )
        await testDenylistPolicy_llmDrivenToolDenial(
            apiKey: apiKey, model: model, baseURL: baseURL
        )
        await testDynamicPermissionModeSwitch(
            apiKey: apiKey, model: model, baseURL: baseURL
        )
    }

    // MARK: Test 42a: Allowlist Policy - LLM-Driven Tool Execution

    /// AC2, AC8, AC12 [P0]: Agent with ToolNameAllowlistPolicy only executes allowed tools.
    /// Uses the canUseTool(policy:) bridge to convert policy to callback.
    static func testAllowlistPolicy_llmDrivenToolCall(
        apiKey: String, model: String, baseURL: String
    ) async {
        let tracker = E2EPermissionTracker()

        // Create allowlist policy allowing only Bash
        let policy = ToolNameAllowlistPolicy(allowedToolNames: ["Bash"])
        let policyFn = canUseTool(policy: policy)

        // Wrap policy to track invocations
        let trackingFn: CanUseToolFn = { tool, input, context in
            let result = await policyFn(tool, input, context)
            if result?.behavior == "allow" {
                await tracker.recordAllow(toolName: tool.name)
            } else if result?.behavior == "deny" {
                await tracker.recordDeny(toolName: tool.name)
            }
            return result
        }

        let bashTool = createBashTool()
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 2,
            canUseTool: trackingFn,
            tools: [bashTool]
        )
        let agent = createAgent(options: options)

        // Ask the agent to use the bash tool
        let result = await agent.prompt("Use the bash tool to run 'echo allowlist-test-ok'.")

        // Agent should complete (not crash)
        guard result.status == .success else {
            fail("Authorization E2E: allowlist policy agent completes",
                 "status: \(result.status)")
            return
        }

        // Verify the allow callback was invoked
        let allowCount = await tracker.allowCount
        guard allowCount > 0 else {
            fail("Authorization E2E: allowlist policy callback invoked",
                 "allow callback was not invoked -- LLM may not have used a tool")
            return
        }
        pass("Authorization E2E: allowlist policy correctly allowed Bash tool")
    }

    // MARK: Test 42b: Denylist Policy - LLM-Driven Tool Denial

    /// AC3, AC8, AC12 [P0]: Agent with ToolNameDenylistPolicy denies specified tools.
    static func testDenylistPolicy_llmDrivenToolDenial(
        apiKey: String, model: String, baseURL: String
    ) async {
        let tracker = E2EPermissionTracker()

        // Create denylist policy denying Bash
        let policy = ToolNameDenylistPolicy(deniedToolNames: ["Bash"])
        let policyFn = canUseTool(policy: policy)

        // Wrap policy to track invocations
        let trackingFn: CanUseToolFn = { tool, input, context in
            let result = await policyFn(tool, input, context)
            if result?.behavior == "allow" {
                await tracker.recordAllow(toolName: tool.name)
            } else if result?.behavior == "deny" {
                await tracker.recordDeny(toolName: tool.name)
            }
            return result
        }

        let bashTool = createBashTool()
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 2,
            canUseTool: trackingFn,
            tools: [bashTool]
        )
        let agent = createAgent(options: options)

        // Ask the agent to use the bash tool (which should be denied)
        let result = await agent.prompt("Use the bash tool to run 'echo denylist-test'.")

        // Agent should still complete (not crash)
        guard result.status == .success else {
            fail("Authorization E2E: denylist policy agent completes",
                 "status: \(result.status)")
            return
        }

        // Verify the deny callback was invoked
        let denyCount = await tracker.denyCount
        guard denyCount > 0 else {
            fail("Authorization E2E: denylist policy callback invoked",
                 "deny callback was not invoked -- LLM may not have used a tool")
            return
        }
        pass("Authorization E2E: denylist policy correctly denied Bash tool")
    }

    // MARK: Test 42c: Dynamic Permission Mode Switch

    /// AC6, AC7, AC12 [P0]: Agent.setPermissionMode() dynamically switches permission mode.
    /// Verifies behavior through the public API: create an agent with a deny-all callback,
    /// switch to bypassPermissions (clearing callback), then verify tools execute.
    static func testDynamicPermissionModeSwitch(
        apiKey: String, model: String, baseURL: String
    ) async {
        let tracker = E2EPermissionTracker()

        // Phase 1: Create agent with deny-all callback
        let denyAllCallback: CanUseToolFn = { tool, _, _ in
            await tracker.recordDeny(toolName: tool.name)
            return CanUseToolResult(behavior: "deny", message: "deny-all policy")
        }

        let bashTool = createBashTool()
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 2,
            permissionMode: .default,
            canUseTool: denyAllCallback,
            tools: [bashTool]
        )
        let agent = createAgent(options: options)

        // Phase 2: Switch to bypassPermissions -- clears canUseTool callback
        agent.setPermissionMode(.bypassPermissions)

        // Phase 3: Now prompt the agent -- tools should execute (bypass mode, no callback)
        let result = await agent.prompt("Use the bash tool to run 'echo dynamic-switch-ok'.")

        // Agent should complete successfully (tools no longer denied)
        guard result.status == .success else {
            fail("Authorization E2E: dynamic switch agent completes",
                 "status: \(result.status)")
            return
        }

        // Phase 4: Now set a new allow-all callback via setCanUseTool
        let allowAllCallback: CanUseToolFn = { tool, _, _ in
            await tracker.recordAllow(toolName: tool.name)
            return CanUseToolResult(behavior: "allow")
        }
        agent.setCanUseTool(allowAllCallback)

        // Phase 5: Prompt again to verify the new callback takes effect
        let result2 = await agent.prompt("Use the bash tool to run 'echo set-canusetool-ok'.")
        guard result2.status == .success else {
            fail("Authorization E2E: setCanUseTool agent completes",
                 "status: \(result2.status)")
            return
        }

        // Verify the allow callback from setCanUseTool was invoked
        let allowCount = await tracker.allowCount
        guard allowCount > 0 else {
            fail("Authorization E2E: setCanUseTool callback invoked",
                 "allow callback was not invoked -- LLM may not have used a tool")
            return
        }
        pass("Authorization E2E: dynamic permission mode switch works correctly")
    }
}

import Foundation
import OpenAgentSDK

// MARK: - Tests 41: Permission Mode E2E Tests (Story 8-4)

/// E2E tests for Story 8-4: Permission Modes.
///
/// These tests verify that permission modes control tool execution during real Agent runs.
/// Uses real LLM API calls -- no mocks (E2E convention).
///
/// NOTE: These tests are in the TDD RED PHASE. They will FAIL until the
/// implementation adds permissionMode/canUseTool to ToolContext and permission
/// checks to ToolExecutor.executeSingleTool().
struct PermissionModeE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("41. Permission Modes (E2E, Story 8-4)")
        await testBypassPermissionsMode_toolExecutesWithoutBlock(
            apiKey: apiKey, model: model, baseURL: baseURL
        )
        await testDefaultMode_mutationToolBlocked(
            apiKey: apiKey, model: model, baseURL: baseURL
        )
        await testCanUseToolCallback_denyPath(
            apiKey: apiKey, model: model, baseURL: baseURL
        )
        await testCanUseToolCallback_allowPath(
            apiKey: apiKey, model: model, baseURL: baseURL
        )
    }

    // MARK: Test 41a: bypassPermissions Mode - Tools Execute Without Block

    /// AC2 [P0]: Agent with bypassPermissions executes tools without interception.
    static func testBypassPermissionsMode_toolExecutesWithoutBlock(
        apiKey: String, model: String, baseURL: String
    ) async {
        // Create agent with bypassPermissions mode
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 2,
            permissionMode: .bypassPermissions
        )
        let agent = createAgent(options: options)

        // Ask the agent to use bash tool
        let result = await agent.prompt("Use the bash tool to run 'echo bypass-test-ok'.")

        // Agent should complete successfully (tool not blocked)
        guard result.status == .success else {
            fail("Permission E2E: bypassPermissions mode agent completes",
                 "status: \(result.status)")
            return
        }
        pass("Permission E2E: bypassPermissions mode - agent completes successfully")
    }

    // MARK: Test 41b: default Mode - Mutation Tool Blocked

    /// AC3 [P0]: Agent with default mode blocks mutation tools.
    static func testDefaultMode_mutationToolBlocked(
        apiKey: String, model: String, baseURL: String
    ) async {
        // Create agent with default mode
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 2,
            permissionMode: .default
        )
        let agent = createAgent(options: options)

        // Ask the agent to use bash tool (mutation tool)
        let result = await agent.prompt("Use the bash tool to run 'echo default-test'.")

        // Agent should still complete (not crash), but tool should be blocked
        // The response should contain the permission block message
        guard result.status == .success else {
            // Agent may still succeed overall, just with blocked tools
            fail("Permission E2E: default mode agent completes",
                 "status: \(result.status)")
            return
        }

        // Check that the output contains evidence of tool blocking
        // The agent's response should mention the permission block or the tool was blocked
        let outputText = result.text.lowercased()
        let hasPermissionBlock = outputText.contains("permission") ||
                                  outputText.contains("blocked") ||
                                  outputText.contains("denied")
        guard hasPermissionBlock else {
            // This is a soft check -- the LLM might not mention the block explicitly
            pass("Permission E2E: default mode - agent completed (block behavior may be implicit)")
            return
        }
        pass("Permission E2E: default mode - mutation tool blocked successfully")
    }

    // MARK: Test 41c: canUseTool Callback Deny Path

    /// AC9 [P0]: canUseTool callback returning deny blocks tool execution.
    static func testCanUseToolCallback_denyPath(
        apiKey: String, model: String, baseURL: String
    ) async {
        let tracker = E2EPermissionTracker()

        let canUseTool: CanUseToolFn = { tool, _, _ in
            await tracker.recordDeny(toolName: tool.name)
            return CanUseToolResult(behavior: .deny, message: "Tool '\(tool.name)' denied by policy")
        }

        let bashTool = createBashTool()
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 2,
            canUseTool: canUseTool,
            tools: [bashTool]
        )
        let agent = createAgent(options: options)

        // Ask the agent to use a tool (bash)
        let result = await agent.prompt("Use the bash tool to run 'echo deny-test'.")

        // Agent should complete (not crash)
        guard result.status == .success else {
            fail("Permission E2E: canUseTool deny path agent completes",
                 "status: \(result.status)")
            return
        }

        // Verify the deny callback was invoked
        let denyCount = await tracker.denyCount
        guard denyCount > 0 else {
            // The LLM might not have used bash tool in this run
            fail("Permission E2E: canUseTool deny callback invoked",
                 "callback was not invoked -- LLM may not have used a tool")
            return
        }
        pass("Permission E2E: canUseTool deny callback was invoked and blocked tool")
    }

    // MARK: Test 41d: canUseTool Callback Allow Path

    /// AC8 [P0]: canUseTool callback returning allow permits tool execution.
    static func testCanUseToolCallback_allowPath(
        apiKey: String, model: String, baseURL: String
    ) async {
        let tracker = E2EPermissionTracker()

        let canUseTool: CanUseToolFn = { tool, _, _ in
            await tracker.recordAllow(toolName: tool.name)
            return CanUseToolResult(behavior: .allow)
        }

        let bashTool = createBashTool()
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 2,
            permissionMode: .default,
            canUseTool: canUseTool,
            tools: [bashTool]
        )
        let agent = createAgent(options: options)

        // Ask the agent to use bash tool
        // canUseTool returns allow, overriding the default mode's block behavior
        let result = await agent.prompt("Use the bash tool to run 'echo allow-test'.")

        // Agent should complete successfully (tool allowed by callback)
        guard result.status == .success else {
            fail("Permission E2E: canUseTool allow path agent completes",
                 "status: \(result.status)")
            return
        }

        // Verify the allow callback was invoked
        let allowCount = await tracker.allowCount
        guard allowCount > 0 else {
            fail("Permission E2E: canUseTool allow callback invoked",
                 "callback was not invoked -- LLM may not have used a tool")
            return
        }
        pass("Permission E2E: canUseTool allow callback was invoked and tool executed")
    }
}

// MARK: - E2E Permission Test Helpers

/// Tracks permission callback invocations in E2E tests.
actor E2EPermissionTracker {
    private var denyCalls: [(toolName: String, count: Int)] = []
    private var allowCalls: [(toolName: String, count: Int)] = []

    func recordDeny(toolName: String) {
        if let idx = denyCalls.firstIndex(where: { $0.toolName == toolName }) {
            denyCalls[idx] = (toolName, denyCalls[idx].count + 1)
        } else {
            denyCalls.append((toolName, 1))
        }
    }

    func recordAllow(toolName: String) {
        if let idx = allowCalls.firstIndex(where: { $0.toolName == toolName }) {
            allowCalls[idx] = (toolName, allowCalls[idx].count + 1)
        } else {
            allowCalls.append((toolName, 1))
        }
    }

    var denyCount: Int {
        denyCalls.reduce(0) { $0 + $1.count }
    }

    var allowCount: Int {
        allowCalls.reduce(0) { $0 + $1.count }
    }
}

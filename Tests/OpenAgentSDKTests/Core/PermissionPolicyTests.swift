import XCTest
@testable import OpenAgentSDK

// MARK: - Permission Policy Test Helpers

/// Mock tool for policy allow/deny testing.
struct PolicyMockTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Mock tool for policy testing"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(toolUseId: context.toolUseId, content: "policy-test-result", isError: false)
    }
}

// MARK: - AC1: PermissionPolicy Protocol

final class PermissionPolicyTests: XCTestCase {

    // MARK: AC1 [P0]: ToolNameAllowlistPolicy - allowed tool returns allow

    /// AC2: A tool name in the allowlist should be allowed.
    func testToolNameAllowlistPolicy_allowedTool_returnsAllow() async throws {
        let policy = ToolNameAllowlistPolicy(allowedToolNames: ["Read", "Glob", "Grep"])
        let tool = PolicyMockTool(name: "Read", isReadOnly: true)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertNotNil(result, "Allowlist policy should return non-nil for allowed tool")
        XCTAssertEqual(result?.behavior, "allow",
                       "Allowed tool should get 'allow' behavior")
    }

    // MARK: AC2 [P0]: ToolNameAllowlistPolicy - denied tool returns deny

    /// AC2: A tool name NOT in the allowlist should be denied.
    func testToolNameAllowlistPolicy_deniedTool_returnsDeny() async throws {
        let policy = ToolNameAllowlistPolicy(allowedToolNames: ["Read", "Glob"])
        let tool = PolicyMockTool(name: "Bash", isReadOnly: false)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertNotNil(result, "Allowlist policy should return non-nil for denied tool")
        XCTAssertEqual(result?.behavior, "deny",
                       "Tool not in allowlist should get 'deny' behavior")
        XCTAssertTrue(result?.message?.contains("Bash") ?? false,
                      "Deny message should mention the tool name")
    }

    // MARK: AC2 [P0]: ToolNameAllowlistPolicy - empty set denies all

    /// AC2: An empty allowlist should deny all tools.
    func testToolNameAllowlistPolicy_emptySet_deniesAll() async throws {
        let policy = ToolNameAllowlistPolicy(allowedToolNames: [])
        let tool = PolicyMockTool(name: "Read", isReadOnly: true)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertNotNil(result, "Empty allowlist should return non-nil")
        XCTAssertEqual(result?.behavior, "deny",
                       "Empty allowlist should deny all tools")
    }

    // MARK: AC3 [P0]: ToolNameDenylistPolicy - denied tool returns deny

    /// AC3: A tool name in the denylist should be denied.
    func testToolNameDenylistPolicy_deniedTool_returnsDeny() async throws {
        let policy = ToolNameDenylistPolicy(deniedToolNames: ["Bash", "Write"])
        let tool = PolicyMockTool(name: "Bash", isReadOnly: false)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertNotNil(result, "Denylist policy should return non-nil for denied tool")
        XCTAssertEqual(result?.behavior, "deny",
                       "Tool in denylist should get 'deny' behavior")
        XCTAssertTrue(result?.message?.contains("Bash") ?? false,
                      "Deny message should mention the tool name")
    }

    // MARK: AC3 [P0]: ToolNameDenylistPolicy - allowed tool returns allow

    /// AC3: A tool name NOT in the denylist should be allowed.
    func testToolNameDenylistPolicy_allowedTool_returnsAllow() async throws {
        let policy = ToolNameDenylistPolicy(deniedToolNames: ["Bash", "Write"])
        let tool = PolicyMockTool(name: "Read", isReadOnly: true)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertNotNil(result, "Denylist policy should return non-nil for allowed tool")
        XCTAssertEqual(result?.behavior, "allow",
                       "Tool not in denylist should get 'allow' behavior")
    }

    // MARK: AC3 [P0]: ToolNameDenylistPolicy - empty set allows all

    /// AC3: An empty denylist should allow all tools.
    func testToolNameDenylistPolicy_emptySet_allowsAll() async throws {
        let policy = ToolNameDenylistPolicy(deniedToolNames: [])
        let tool = PolicyMockTool(name: "Bash", isReadOnly: false)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertNotNil(result, "Empty denylist should return non-nil")
        XCTAssertEqual(result?.behavior, "allow",
                       "Empty denylist should allow all tools")
    }

    // MARK: AC4 [P0]: ReadOnlyPolicy - read-only tool returns allow

    /// AC4: A read-only tool should be allowed under ReadOnlyPolicy.
    func testReadOnlyPolicy_readOnlyTool_returnsAllow() async throws {
        let policy = ReadOnlyPolicy()
        let tool = PolicyMockTool(name: "Read", isReadOnly: true)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertNotNil(result, "ReadOnlyPolicy should return non-nil for read-only tool")
        XCTAssertEqual(result?.behavior, "allow",
                       "Read-only tool should be allowed")
    }

    // MARK: AC4 [P0]: ReadOnlyPolicy - mutation tool returns deny

    /// AC4: A mutation tool should be denied under ReadOnlyPolicy.
    func testReadOnlyPolicy_mutationTool_returnsDeny() async throws {
        let policy = ReadOnlyPolicy()
        let tool = PolicyMockTool(name: "Bash", isReadOnly: false)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertNotNil(result, "ReadOnlyPolicy should return non-nil for mutation tool")
        XCTAssertEqual(result?.behavior, "deny",
                       "Mutation tool should be denied under read-only policy")
        XCTAssertTrue(result?.message?.contains("read-only") ?? false,
                      "Deny message should mention read-only policy")
    }

    // MARK: AC5 [P0]: CompositePolicy - all allow returns allow

    /// AC5: When all sub-policies allow, composite returns allow.
    func testCompositePolicy_allAllow_returnsAllow() async throws {
        let policy = CompositePolicy(policies: [
            ToolNameAllowlistPolicy(allowedToolNames: ["Read", "Bash"]),
            ReadOnlyPolicy()  // This won't trigger for Read (isReadOnly=true)
        ])
        let tool = PolicyMockTool(name: "Read", isReadOnly: true)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertNotNil(result, "CompositePolicy should return non-nil")
        XCTAssertEqual(result?.behavior, "allow",
                       "All-allowing policies should result in allow")
    }

    // MARK: AC5 [P0]: CompositePolicy - one deny returns deny

    /// AC5: When any sub-policy denies, composite returns deny.
    func testCompositePolicy_oneDeny_returnsDeny() async throws {
        let policy = CompositePolicy(policies: [
            ToolNameAllowlistPolicy(allowedToolNames: ["Read", "Bash"]),
            ReadOnlyPolicy()  // Bash is not read-only, so this will deny
        ])
        let tool = PolicyMockTool(name: "Bash", isReadOnly: false)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertNotNil(result, "CompositePolicy should return non-nil")
        XCTAssertEqual(result?.behavior, "deny",
                       "Any deny should make composite return deny")
    }

    // MARK: AC5 [P0]: CompositePolicy - deny short-circuits

    /// AC5: Deny short-circuits evaluation; subsequent policies are not evaluated.
    func testCompositePolicy_denyShortCircuits() async throws {
        // Use a tracking policy to verify short-circuit behavior.
        // If deny short-circuits, the second policy's side-effect should NOT occur.
        let denyPolicy = ToolNameDenylistPolicy(deniedToolNames: ["Bash"])
        let policy = CompositePolicy(policies: [
            denyPolicy,
            ToolNameAllowlistPolicy(allowedToolNames: ["Bash"])
        ])
        let tool = PolicyMockTool(name: "Bash", isReadOnly: false)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        // Even though the second policy would allow Bash, the first deny should win
        XCTAssertEqual(result?.behavior, "deny",
                       "Deny should short-circuit and win over subsequent allow")
    }

    // MARK: AC5 [P0]: CompositePolicy - nil skips

    /// AC5: A policy returning nil is skipped; evaluation continues.
    func testCompositePolicy_nilSkips() async throws {
        // Create a policy that returns nil (no opinion) for all tools
        let nilPolicy = NilOpinionPolicy()
        let allowPolicy = ToolNameAllowlistPolicy(allowedToolNames: ["Read"])

        let policy = CompositePolicy(policies: [nilPolicy, allowPolicy])
        let tool = PolicyMockTool(name: "Read", isReadOnly: true)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertEqual(result?.behavior, "allow",
                       "Nil policy should be skipped, allow policy should take effect")
    }

    // MARK: AC5 [P0]: CompositePolicy - empty policies returns allow

    /// AC5: Empty policy list should default to allow.
    func testCompositePolicy_emptyPolicies_returnsAllow() async throws {
        let policy = CompositePolicy(policies: [])
        let tool = PolicyMockTool(name: "Bash", isReadOnly: false)
        let context = ToolContext(cwd: "/tmp")

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        XCTAssertEqual(result?.behavior, "allow",
                       "Empty policy list should default to allow")
    }

    // MARK: AC8 [P0]: canUseTool(policy:) bridge function

    /// AC8: canUseTool(policy:) bridge converts policy to CanUseToolFn correctly.
    func testCanUseToolPolicy_bridge_returnsExpectedResults() async throws {
        let policy = ToolNameAllowlistPolicy(allowedToolNames: ["Read"])
        let fn = canUseTool(policy: policy)

        let allowedTool = PolicyMockTool(name: "Read", isReadOnly: true)
        let deniedTool = PolicyMockTool(name: "Bash", isReadOnly: false)
        let context = ToolContext(cwd: "/tmp")

        // Test allow path
        let allowResult = await fn(allowedTool, [:], context)
        XCTAssertEqual(allowResult?.behavior, "allow",
                       "Bridge function should delegate allow correctly")

        // Test deny path
        let denyResult = await fn(deniedTool, [:], context)
        XCTAssertEqual(denyResult?.behavior, "deny",
                       "Bridge function should delegate deny correctly")
    }

    // MARK: AC9 [P0]: CanUseToolResult.allow() factory method

    /// AC9: CanUseToolResult.allow() creates an allow result.
    func testCanUseToolResult_allow_createsAllowResult() {
        let result = CanUseToolResult.allow()

        XCTAssertEqual(result.behavior, "allow",
                       "allow() should create result with 'allow' behavior")
        XCTAssertNil(result.message,
                     "allow() should have no message")
    }

    // MARK: AC9 [P0]: CanUseToolResult.deny() factory method

    /// AC9: CanUseToolResult.deny() creates a deny result with message.
    func testCanUseToolResult_deny_createsDenyResult() {
        let result = CanUseToolResult.deny("Access denied")

        XCTAssertEqual(result.behavior, "deny",
                       "deny() should create result with 'deny' behavior")
        XCTAssertEqual(result.message, "Access denied",
                       "deny() should preserve the message")
    }

    // MARK: AC9 [P0]: CanUseToolResult.allowWithInput() factory method

    /// AC9: CanUseToolResult.allowWithInput() creates an allow result with modified input.
    func testCanUseToolResult_allowWithInput_createsResultWithInput() {
        let modifiedInput = ["command": "echo safe"]
        let result = CanUseToolResult.allowWithInput(modifiedInput)

        XCTAssertEqual(result.behavior, "allow",
                       "allowWithInput() should create result with 'allow' behavior")
        XCTAssertNotNil(result.updatedInput,
                        "allowWithInput() should have updatedInput")
    }

    // MARK: AC6 [P0]: Agent.setPermissionMode() updates mode

    /// AC6: Agent.setPermissionMode() changes the permission mode.
    func testAgent_setPermissionMode_updatesMode() async throws {
        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            maxTurns: 2,
            permissionMode: .default
        )
        let agent = Agent(options: options)

        // Verify initial mode
        XCTAssertEqual(agent.options.permissionMode, .default,
                       "Initial mode should be default")

        // Change mode
        agent.setPermissionMode(.bypassPermissions)

        // Verify mode was updated
        XCTAssertEqual(agent.options.permissionMode, .bypassPermissions,
                       "Mode should be updated to bypassPermissions")
    }

    // MARK: AC6 [P0]: Agent.setPermissionMode() clears canUseTool

    /// AC6: Agent.setPermissionMode() clears the canUseTool callback.
    func testAgent_setPermissionMode_clearsCanUseTool() async throws {
        let canUseTool: CanUseToolFn = { _, _, _ in
            return CanUseToolResult(behavior: "allow")
        }
        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            maxTurns: 2,
            canUseTool: canUseTool
        )
        let agent = Agent(options: options)

        // Verify canUseTool is set
        XCTAssertNotNil(agent.options.canUseTool,
                        "canUseTool should be set initially")

        // Change mode
        agent.setPermissionMode(.bypassPermissions)

        // Verify canUseTool was cleared
        XCTAssertNil(agent.options.canUseTool,
                     "setPermissionMode() should clear canUseTool callback")
    }

    // MARK: AC7 [P0]: Agent.setCanUseTool() updates callback

    /// AC7: Agent.setCanUseTool() sets a new canUseTool callback.
    func testAgent_setCanUseTool_updatesCallback() async throws {
        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            maxTurns: 2
        )
        let agent = Agent(options: options)

        // Verify no callback initially
        XCTAssertNil(agent.options.canUseTool,
                     "canUseTool should be nil initially")

        // Set a callback
        let newCallback: CanUseToolFn = { _, _, _ in
            return CanUseToolResult(behavior: "deny", message: "test deny")
        }
        agent.setCanUseTool(newCallback)

        // Verify callback was set
        XCTAssertNotNil(agent.options.canUseTool,
                        "setCanUseTool() should set the callback")
    }

    // MARK: AC7 [P0]: Agent.setCanUseTool(nil) clears callback

    /// AC7: Agent.setCanUseTool(nil) clears the callback.
    func testAgent_setCanUseTool_nil_clearsCallback() async throws {
        let canUseTool: CanUseToolFn = { _, _, _ in
            return CanUseToolResult(behavior: "allow")
        }
        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            maxTurns: 2,
            canUseTool: canUseTool
        )
        let agent = Agent(options: options)

        // Clear the callback
        agent.setCanUseTool(nil)

        // Verify callback was cleared
        XCTAssertNil(agent.options.canUseTool,
                     "setCanUseTool(nil) should clear the callback")
    }

    // MARK: AC10 [P1]: ToolContext permissionMode accessible in policy

    /// AC10: Policy can access permissionMode from ToolContext.
    func testToolContext_permissionMode_accessibleInPolicy() async throws {
        let policy = ContextAwarePolicy()
        let tool = PolicyMockTool(name: "Bash", isReadOnly: false)
        let context = ToolContext(
            cwd: "/tmp",
            permissionMode: .plan
        )

        let result = await policy.evaluate(tool: tool, input: [:], context: context)

        // ContextAwarePolicy should deny under plan mode
        XCTAssertEqual(result?.behavior, "deny",
                       "Policy should be able to read permissionMode from context")
    }
}

// MARK: - Test Helper Policies

/// Policy that always returns nil (no opinion). Used for CompositePolicy nil-skip testing.
struct NilOpinionPolicy: PermissionPolicy, Sendable {
    func evaluate(tool: ToolProtocol, input: Any, context: ToolContext) async -> CanUseToolResult? {
        return nil  // No opinion
    }
}

/// Policy that checks the context's permissionMode. Used for AC10 testing.
struct ContextAwarePolicy: PermissionPolicy, Sendable {
    func evaluate(tool: ToolProtocol, input: Any, context: ToolContext) async -> CanUseToolResult? {
        if context.permissionMode == .plan {
            return .deny("Blocked by plan mode via policy")
        }
        return .allow()
    }
}

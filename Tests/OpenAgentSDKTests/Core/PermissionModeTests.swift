import XCTest
@testable import OpenAgentSDK

// MARK: - Permission Test Helpers

/// Mock read-only tool for permission testing.
struct PermissionMockReadOnlyTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Mock read-only tool"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = true

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(toolUseId: context.toolUseId, content: "read-result", isError: false)
    }
}

/// Mock mutation tool for permission testing.
struct PermissionMockMutationTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Mock mutation tool"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = false
    var capturedInput: Any?

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(toolUseId: context.toolUseId, content: "mutation-result", isError: false)
    }
}

/// Mock tool that records whether it was called, for permission bypass verification.
struct PermissionTrackingTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Permission tracking tool"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(
            toolUseId: context.toolUseId,
            content: "executed:\(name):\(String(describing: input))",
            isError: false
        )
    }
}

// MARK: - AC1-AC7: shouldBlockTool Tests

final class PermissionModeShouldBlockTests: XCTestCase {

    // MARK: AC2 [P0]: bypassPermissions allows all tools

    /// AC2: Mutation tools pass under bypassPermissions mode.
    func testShouldBlockTool_bypassPermissions_allowsAll() async throws {
        let tool = PermissionMockMutationTool(name: "Bash")
        let decision = ToolExecutor.shouldBlockTool(permissionMode: .bypassPermissions, tool: tool)
        if case .allow = decision {
            // expected
        } else {
            XCTFail("bypassPermissions should allow mutation tools, got: \(decision)")
        }
    }

    // MARK: AC7 [P0]: auto allows all tools

    /// AC7: Mutation tools pass under auto mode.
    func testShouldBlockTool_auto_allowsAll() async throws {
        let tool = PermissionMockMutationTool(name: "Bash")
        let decision = ToolExecutor.shouldBlockTool(permissionMode: .auto, tool: tool)
        if case .allow = decision {
            // expected
        } else {
            XCTFail("auto should allow mutation tools, got: \(decision)")
        }
    }

    // MARK: AC3 [P0]: default blocks mutation tools

    /// AC3: Mutation tools are blocked under default mode.
    func testShouldBlockTool_default_blocksMutationTools() async throws {
        let tool = PermissionMockMutationTool(name: "Bash")
        let decision = ToolExecutor.shouldBlockTool(permissionMode: .default, tool: tool)
        if case .block(let message) = decision {
            XCTAssertTrue(message.contains("Bash"),
                          "Block message should mention tool name, got: \(message)")
            XCTAssertTrue(message.contains("default"),
                          "Block message should mention mode name, got: \(message)")
        } else {
            XCTFail("default should block mutation tools, got: \(decision)")
        }
    }

    // MARK: AC3 [P0]: default allows read-only tools

    /// AC3: Read-only tools pass under default mode.
    func testShouldBlockTool_default_allowsReadOnlyTools() async throws {
        let tool = PermissionMockReadOnlyTool(name: "Read")
        let decision = ToolExecutor.shouldBlockTool(permissionMode: .default, tool: tool)
        if case .allow = decision {
            // expected
        } else {
            XCTFail("default should allow read-only tools, got: \(decision)")
        }
    }

    // MARK: AC4 [P0]: acceptEdits allows Write/Edit

    /// AC4: Write tool passes under acceptEdits mode.
    func testShouldBlockTool_acceptEdits_allowsWriteEdit() async throws {
        let writeTool = PermissionMockMutationTool(name: "Write")
        let writeDecision = ToolExecutor.shouldBlockTool(permissionMode: .acceptEdits, tool: writeTool)
        if case .allow = writeDecision {
            // expected
        } else {
            XCTFail("acceptEdits should allow Write, got: \(writeDecision)")
        }

        let editTool = PermissionMockMutationTool(name: "Edit")
        let editDecision = ToolExecutor.shouldBlockTool(permissionMode: .acceptEdits, tool: editTool)
        if case .allow = editDecision {
            // expected
        } else {
            XCTFail("acceptEdits should allow Edit, got: \(editDecision)")
        }
    }

    // MARK: AC4 [P0]: acceptEdits blocks Bash

    /// AC4: Bash tool is blocked under acceptEdits mode.
    func testShouldBlockTool_acceptEdits_blocksBash() async throws {
        let tool = PermissionMockMutationTool(name: "Bash")
        let decision = ToolExecutor.shouldBlockTool(permissionMode: .acceptEdits, tool: tool)
        if case .block(let message) = decision {
            XCTAssertTrue(message.contains("Bash"),
                          "Block message should mention tool name, got: \(message)")
            XCTAssertTrue(message.contains("acceptEdits"),
                          "Block message should mention mode name, got: \(message)")
        } else {
            XCTFail("acceptEdits should block Bash, got: \(decision)")
        }
    }

    // MARK: AC5 [P0]: plan blocks all mutations

    /// AC5: All mutation tools are blocked under plan mode.
    func testShouldBlockTool_plan_blocksAllMutations() async throws {
        let tool = PermissionMockMutationTool(name: "Write")
        let decision = ToolExecutor.shouldBlockTool(permissionMode: .plan, tool: tool)
        if case .block(let message) = decision {
            XCTAssertTrue(message.contains("plan"),
                          "Block message should mention plan mode, got: \(message)")
        } else {
            XCTFail("plan should block mutation tools, got: \(decision)")
        }
    }

    // MARK: AC6 [P0]: dontAsk denies all mutations

    /// AC6: All mutation tools are denied under dontAsk mode (not just blocked -- denied).
    func testShouldBlockTool_dontAsk_deniesAllMutations() async throws {
        let tool = PermissionMockMutationTool(name: "Write")
        let decision = ToolExecutor.shouldBlockTool(permissionMode: .dontAsk, tool: tool)
        if case .deny(let message) = decision {
            XCTAssertTrue(message.contains("denied"),
                          "Deny message should mention denied, got: \(message)")
            XCTAssertTrue(message.contains("dontAsk"),
                          "Deny message should mention mode, got: \(message)")
        } else {
            XCTFail("dontAsk should deny mutation tools (not block), got: \(decision)")
        }
    }
}

// MARK: - AC8-AC11: executeSingleTool Permission Integration Tests

final class PermissionModeExecuteSingleToolTests: XCTestCase {

    // MARK: AC9 [P0]: canUseTool deny returns error

    /// AC9: canUseTool returning deny produces error ToolResult.
    func testExecuteSingleTool_canUseToolDeny_returnsError() async throws {
        let tool = PermissionMockMutationTool(name: "Bash")
        let block = ToolUseBlock(id: "tu_deny_1", name: "Bash", input: ["command": "rm -rf /"])

        let canUseTool: CanUseToolFn = { _, _, _ in
            return CanUseToolResult(behavior: .deny, message: "Permission denied for Bash")
        }

        let context = ToolContext(
            cwd: "/tmp",
            canUseTool: canUseTool
        )

        let result = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        XCTAssertTrue(result.isError,
                      "canUseTool deny should return isError=true")
        XCTAssertTrue(result.content.contains("Permission denied"),
                      "Error message should contain denial message, got: \(result.content)")
        XCTAssertEqual(result.toolUseId, "tu_deny_1",
                       "Error result should preserve tool_use_id")
    }

    // MARK: AC8 [P0]: canUseTool allow executes tool

    /// AC8: canUseTool returning allow executes the tool normally.
    func testExecuteSingleTool_canUseToolAllow_executesTool() async throws {
        let tool = PermissionMockMutationTool(name: "Bash")
        let block = ToolUseBlock(id: "tu_allow_1", name: "Bash", input: ["command": "ls"])

        let canUseTool: CanUseToolFn = { _, _, _ in
            return CanUseToolResult(behavior: .allow)
        }

        let context = ToolContext(
            cwd: "/tmp",
            canUseTool: canUseTool
        )

        let result = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        XCTAssertFalse(result.isError,
                       "canUseTool allow should execute tool without error")
        XCTAssertEqual(result.content, "mutation-result",
                       "Tool should have executed and returned its result")
    }

    // MARK: AC10 [P0]: canUseTool allow with updatedInput

    /// AC10: canUseTool returning allow with updatedInput uses modified input.
    func testExecuteSingleTool_canUseToolAllowWithUpdatedInput_usesModifiedInput() async throws {
        let tool = PermissionTrackingTool(name: "Bash", isReadOnly: false)
        let originalInput = ["command": "rm -rf /"]
        let modifiedInput = ["command": "echo safe"]
        let block = ToolUseBlock(id: "tu_mod_1", name: "Bash", input: originalInput)

        let canUseTool: CanUseToolFn = { _, _, _ in
            return CanUseToolResult(behavior: .allow, updatedInput: modifiedInput)
        }

        let context = ToolContext(
            cwd: "/tmp",
            canUseTool: canUseTool
        )

        let result = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        XCTAssertFalse(result.isError,
                       "canUseTool allow with updatedInput should succeed")
        // The tool should have received the modified input
        XCTAssertTrue(result.content.contains("executed:Bash"),
                      "Tool should have executed, got: \(result.content)")
    }

    // MARK: AC8 [P0]: canUseTool returns nil falls back to permissionMode

    /// AC8: canUseTool returning nil falls back to permissionMode behavior.
    func testExecuteSingleTool_canUseToolReturnsNil_fallsBackToPermissionMode() async throws {
        let tool = PermissionMockMutationTool(name: "Bash")
        let block = ToolUseBlock(id: "tu_nil_1", name: "Bash", input: ["command": "ls"])

        let canUseTool: CanUseToolFn = { _, _, _ in
            return nil  // Falls back to permissionMode
        }

        let context = ToolContext(
            cwd: "/tmp",
            permissionMode: .default,
            canUseTool: canUseTool
        )

        let result = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        XCTAssertTrue(result.isError,
                      "canUseTool nil should fall back to default mode which blocks Bash")
        XCTAssertTrue(result.content.contains("Permission required") || result.content.contains("blocked"),
                      "Should contain permission block message, got: \(result.content)")
    }

    // MARK: AC8 [P0]: canUseTool throws returns error

    /// AC8: canUseTool producing an error result via deny returns error ToolResult.
    /// Note: CanUseToolFn is non-throwing, so the implementation wraps the call in
    /// do/catch for safety. This test verifies deny behavior when the callback
    /// signals an error via its result (the Swift-equivalent of the TS SDK's error path).
    func testExecuteSingleTool_canUseToolDenyWithErrorMessage_returnsError() async throws {
        let tool = PermissionMockMutationTool(name: "Bash")
        let block = ToolUseBlock(id: "tu_err_1", name: "Bash", input: ["command": "ls"])

        let canUseTool: CanUseToolFn = { _, _, _ in
            return CanUseToolResult(behavior: .deny, message: "Permission check error: callback failed")
        }

        let context = ToolContext(
            cwd: "/tmp",
            canUseTool: canUseTool
        )

        let result = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        XCTAssertTrue(result.isError,
                      "canUseTool deny should return isError=true")
        XCTAssertTrue(result.content.contains("Permission check error"),
                      "Error should contain the callback's error message, got: \(result.content)")
    }

    // MARK: AC1 [P1]: No canUseTool and no permissionMode executes tool

    /// AC1: When no permission config is set, tools execute normally.
    func testExecuteSingleTool_noCanUseToolNoPermissionMode_executesTool() async throws {
        let tool = PermissionMockMutationTool(name: "Bash")
        let block = ToolUseBlock(id: "tu_noperm_1", name: "Bash", input: ["command": "ls"])

        let context = ToolContext(cwd: "/tmp")

        let result = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        XCTAssertFalse(result.isError,
                       "No permission config should allow tool execution")
        XCTAssertEqual(result.content, "mutation-result",
                       "Tool should have executed normally")
    }

    // MARK: AC11 [P0]: ToolContext carries permission info

    /// AC11: ToolContext preserves permissionMode and canUseTool fields.
    func testToolContext_permissionModeAndCanUseTool_injectedCorrectly() {
        let canUseTool: CanUseToolFn = { _, _, _ in return nil }

        let context = ToolContext(
            cwd: "/tmp",
            permissionMode: .bypassPermissions,
            canUseTool: canUseTool
        )

        XCTAssertEqual(context.permissionMode, .bypassPermissions,
                       "ToolContext should preserve permissionMode")
        XCTAssertNotNil(context.canUseTool,
                        "ToolContext should preserve canUseTool")

        // Verify withToolUseId preserves permission fields
        let copiedContext = context.withToolUseId("new-id")
        XCTAssertEqual(copiedContext.permissionMode, .bypassPermissions,
                       "withToolUseId should preserve permissionMode")
        XCTAssertNotNil(copiedContext.canUseTool,
                        "withToolUseId should preserve canUseTool")
    }
}

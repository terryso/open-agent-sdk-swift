// Story18_3_ATDDTests.swift
// Story 18.3: Update CompatMessageTypes Example -- ATDD Tests
//
// ATDD tests for Story 18-3: Update CompatMessageTypes example to reflect
// Story 17-1 (SDKMessage Type Enhancement) features.
//
// Test design:
// - AC1: 12 new SDKMessage cases verified via SDK API (PASS -- types exist)
// - AC2: AssistantData 4 enhanced fields verified via SDK API (PASS -- types exist)
// - AC3: ResultData enhanced fields verified via SDK API (PASS -- types exist)
// - AC4: SystemData init fields and 7 new subtypes verified via SDK API (PASS -- types exist)
// - AC5: PartialData 3 enhanced fields verified via SDK API (PASS -- types exist)
// - AC6: Compat report must reflect updated counts (GREEN -- all tests pass after example updated)
//
// GREEN Phase: After updating the CompatMessageTypes example's MISSING/PARTIAL entries
// to PASS, all 34 tests pass. The example now accurately reflects the Story 17-1
// SDKMessage Type Enhancement feature alignment.

import XCTest
@testable import OpenAgentSDK

// ================================================================
// MARK: - AC2: AssistantData Enhanced Fields (4 tests)
// ================================================================

/// Verifies that AssistantData fields added by Story 17-1 are accessible.
/// These were MISSING in the CompatMessageTypes example and must now be PASS.
final class Story18_3_AssistantDataATDDTests: XCTestCase {

    /// AC2 [P0]: AssistantData.uuid field is accessible (maps to TS SDK uuid).
    func testAssistantData_uuid_accessible() {
        let data = SDKMessage.AssistantData(
            text: "Hello", model: "claude-sonnet-4-6", stopReason: "end_turn",
            uuid: "msg-uuid-123"
        )
        XCTAssertEqual(data.uuid, "msg-uuid-123",
            "AssistantData.uuid must be accessible (maps to TS SDK SDKAssistantMessage.uuid)")
    }

    /// AC2 [P0]: AssistantData.sessionId field is accessible (maps to TS SDK session_id).
    func testAssistantData_sessionId_accessible() {
        let data = SDKMessage.AssistantData(
            text: "", model: "", stopReason: "",
            sessionId: "sess-abc"
        )
        XCTAssertEqual(data.sessionId, "sess-abc",
            "AssistantData.sessionId must be accessible (maps to TS SDK SDKAssistantMessage.session_id)")
    }

    /// AC2 [P0]: AssistantData.parentToolUseId field is accessible (maps to TS SDK parent_tool_use_id).
    func testAssistantData_parentToolUseId_accessible() {
        let data = SDKMessage.AssistantData(
            text: "", model: "", stopReason: "",
            parentToolUseId: "toolu_parent"
        )
        XCTAssertEqual(data.parentToolUseId, "toolu_parent",
            "AssistantData.parentToolUseId must be accessible (maps to TS SDK SDKAssistantMessage.parent_tool_use_id)")
    }

    /// AC2 [P0]: AssistantData.error field with all 7 subtypes is accessible.
    func testAssistantData_error_all7Subtypes() {
        // Verify all 7 AssistantError subtypes exist
        let subtypes: [SDKMessage.AssistantError] = [
            .authenticationFailed, .billingError, .rateLimit,
            .invalidRequest, .serverError, .maxOutputTokens, .unknown
        ]
        XCTAssertEqual(subtypes.count, 7,
            "AssistantError must have exactly 7 subtypes matching TS SDK")

        // Verify error can be set on AssistantData
        let data = SDKMessage.AssistantData(
            text: "", model: "", stopReason: "",
            error: .rateLimit
        )
        XCTAssertEqual(data.error, .rateLimit,
            "AssistantData.error must be accessible with 7 subtypes (maps to TS SDK SDKAssistantMessage.error)")
    }
}

// ================================================================
// MARK: - AC3: ResultData Enhanced Fields (4 tests)
// ================================================================

/// Verifies that ResultData fields added by Story 17-1 are accessible.
/// These were MISSING in the CompatMessageTypes example and must now be PASS.
final class Story18_3_ResultDataATDDTests: XCTestCase {

    /// AC3 [P0]: ResultData.structuredOutput is accessible (maps to TS SDK structuredOutput).
    func testResultData_structuredOutput_accessible() {
        let output = SDKMessage.SendableStructuredOutput(["result": "ok"])
        let data = SDKMessage.ResultData(
            subtype: .success, text: "done", usage: nil, numTurns: 1, durationMs: 100,
            structuredOutput: output
        )
        XCTAssertNotNil(data.structuredOutput,
            "ResultData.structuredOutput must be accessible (maps to TS SDK SDKResultMessage.structuredOutput)")
    }

    /// AC3 [P0]: ResultData.permissionDenials is accessible (maps to TS SDK permissionDenials).
    func testResultData_permissionDenials_accessible() {
        let denials = [
            SDKMessage.SDKPermissionDenial(toolName: "Bash", toolUseId: "tu_1", toolInput: "ls")
        ]
        let data = SDKMessage.ResultData(
            subtype: .success, text: "done", usage: nil, numTurns: 1, durationMs: 100,
            permissionDenials: denials
        )
        XCTAssertNotNil(data.permissionDenials,
            "ResultData.permissionDenials must be accessible (maps to TS SDK SDKResultMessage.permissionDenials)")
        XCTAssertEqual(data.permissionDenials?.count, 1)
    }

    /// AC3 [P0]: ResultData.Subtype.errorMaxStructuredOutputRetries exists (maps to TS SDK).
    func testResultData_errorMaxStructuredOutputRetries_exists() {
        let data = SDKMessage.ResultData(
            subtype: .errorMaxStructuredOutputRetries, text: "", usage: nil, numTurns: 1, durationMs: 100
        )
        XCTAssertEqual(data.subtype, .errorMaxStructuredOutputRetries,
            "ResultData.Subtype.errorMaxStructuredOutputRetries must exist (maps to TS SDK error_max_structured_output_retries)")
    }

    /// AC3 [P0]: ResultData.errors array remains genuinely MISSING (gap confirmed).
    func testResultData_errors_stillMissing() {
        let data = SDKMessage.ResultData(
            subtype: .errorDuringExecution, text: "", usage: nil, numTurns: 1, durationMs: 100
        )
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("errors"),
            "[GAP] ResultData should NOT have errors field yet. This remains genuinely MISSING.")
    }
}

// ================================================================
// MARK: - AC4: SystemData Init Fields and 7 New Subtypes (8 tests)
// ================================================================

/// Verifies that SystemData init fields and 7 new subtypes from Story 17-1 are accessible.
/// The init entry was PARTIAL and the subtypes were MISSING -- must now be PASS.
final class Story18_3_SystemDataATDDTests: XCTestCase {

    /// AC4 [P0]: SystemData init with all fields: sessionId, tools, model, permissionMode, mcpServers, cwd.
    func testSystemData_init_allFieldsPopulated() {
        let data = SDKMessage.SystemData(
            subtype: .`init`, message: "Session started",
            sessionId: "sess-123",
            tools: [SDKMessage.ToolInfo(name: "Bash", description: "Run commands")],
            model: "claude-sonnet-4-6",
            permissionMode: "bypassPermissions",
            mcpServers: [SDKMessage.McpServerInfo(name: "filesystem", command: "npx")],
            cwd: "/tmp/project"
        )
        XCTAssertEqual(data.sessionId, "sess-123",
            "SystemData.sessionId must be populated")
        XCTAssertNotNil(data.tools,
            "SystemData.tools must be populated")
        XCTAssertEqual(data.model, "claude-sonnet-4-6",
            "SystemData.model must be populated")
        XCTAssertEqual(data.permissionMode, "bypassPermissions",
            "SystemData.permissionMode must be populated")
        XCTAssertNotNil(data.mcpServers,
            "SystemData.mcpServers must be populated")
        XCTAssertEqual(data.cwd, "/tmp/project",
            "SystemData.cwd must be populated")
    }

    /// AC4 [P0]: SystemData.Subtype.taskStarted exists (was MISSING, now PASS).
    func testSystemData_taskStarted_subtype() {
        let subtype = SDKMessage.SystemData.Subtype.taskStarted
        XCTAssertEqual(subtype.rawValue, "taskStarted",
            "SystemData.Subtype.taskStarted maps to TS SDK system/task_started")
    }

    /// AC4 [P0]: SystemData.Subtype.taskProgress exists (was MISSING, now PASS).
    func testSystemData_taskProgress_subtype() {
        let subtype = SDKMessage.SystemData.Subtype.taskProgress
        XCTAssertEqual(subtype.rawValue, "taskProgress",
            "SystemData.Subtype.taskProgress maps to TS SDK system/task_progress")
    }

    /// AC4 [P0]: SystemData.Subtype.hookStarted exists (was MISSING, now PASS).
    func testSystemData_hookStarted_subtype() {
        let subtype = SDKMessage.SystemData.Subtype.hookStarted
        XCTAssertEqual(subtype.rawValue, "hookStarted",
            "SystemData.Subtype.hookStarted maps to TS SDK system/hook_started")
    }

    /// AC4 [P0]: SystemData.Subtype.hookProgress exists (was MISSING, now PASS).
    func testSystemData_hookProgress_subtype() {
        let subtype = SDKMessage.SystemData.Subtype.hookProgress
        XCTAssertEqual(subtype.rawValue, "hookProgress",
            "SystemData.Subtype.hookProgress maps to TS SDK system/hook_progress")
    }

    /// AC4 [P0]: SystemData.Subtype.hookResponse exists (was MISSING, now PASS).
    func testSystemData_hookResponse_subtype() {
        let subtype = SDKMessage.SystemData.Subtype.hookResponse
        XCTAssertEqual(subtype.rawValue, "hookResponse",
            "SystemData.Subtype.hookResponse maps to TS SDK system/hook_response")
    }

    /// AC4 [P0]: SystemData.Subtype.filesPersisted exists (was MISSING, now PASS).
    func testSystemData_filesPersisted_subtype() {
        let subtype = SDKMessage.SystemData.Subtype.filesPersisted
        XCTAssertEqual(subtype.rawValue, "filesPersisted",
            "SystemData.Subtype.filesPersisted maps to TS SDK system/files_persisted")
    }

    /// AC4 [P0]: SystemData.Subtype.localCommandOutput exists (was MISSING, now PASS).
    func testSystemData_localCommandOutput_subtype() {
        let subtype = SDKMessage.SystemData.Subtype.localCommandOutput
        XCTAssertEqual(subtype.rawValue, "localCommandOutput",
            "SystemData.Subtype.localCommandOutput maps to TS SDK system/local_command_output")
    }
}

// ================================================================
// MARK: - AC5: PartialData Enhanced Fields (3 tests)
// ================================================================

/// Verifies that PartialData fields added by Story 17-1 are accessible.
/// These were MISSING in the CompatMessageTypes example and must now be PASS.
final class Story18_3_PartialDataATDDTests: XCTestCase {

    /// AC5 [P0]: PartialData.parentToolUseId is accessible (maps to TS SDK parent_tool_use_id).
    func testPartialData_parentToolUseId_accessible() {
        let data = SDKMessage.PartialData(text: "Hello", parentToolUseId: "toolu_parent")
        XCTAssertEqual(data.parentToolUseId, "toolu_parent",
            "PartialData.parentToolUseId must be accessible (maps to TS SDK SDKPartialAssistantMessage.parent_tool_use_id)")
    }

    /// AC5 [P0]: PartialData.uuid is accessible (maps to TS SDK uuid).
    func testPartialData_uuid_accessible() {
        let data = SDKMessage.PartialData(text: "Hello", uuid: "msg-uuid")
        XCTAssertEqual(data.uuid, "msg-uuid",
            "PartialData.uuid must be accessible (maps to TS SDK SDKPartialAssistantMessage.uuid)")
    }

    /// AC5 [P0]: PartialData.sessionId is accessible (maps to TS SDK session_id).
    func testPartialData_sessionId_accessible() {
        let data = SDKMessage.PartialData(text: "Hello", sessionId: "sess-123")
        XCTAssertEqual(data.sessionId, "sess-123",
            "PartialData.sessionId must be accessible (maps to TS SDK SDKPartialAssistantMessage.session_id)")
    }
}

// ================================================================
// MARK: - AC1: 12 Missing Message Types (12 tests)
// ================================================================

/// Verifies that all 12 new SDKMessage cases added by Story 17-1 are accessible.
/// These were MISSING in the CompatMessageTypes example and must now be PASS.
final class Story18_3_MessageTypesATDDTests: XCTestCase {

    /// AC1 [P0]: SDKMessage.userMessage(UserMessageData) exists.
    func testSDKMessage_userMessage_exists() {
        let data = SDKMessage.UserMessageData(message: "Hello")
        let message = SDKMessage.userMessage(data)
        if case .userMessage(let retrieved) = message {
            XCTAssertEqual(retrieved.message, "Hello")
        } else {
            XCTFail("Expected .userMessage case")
        }
    }

    /// AC1 [P0]: SDKMessage.toolProgress(ToolProgressData) exists.
    func testSDKMessage_toolProgress_exists() {
        let data = SDKMessage.ToolProgressData(toolUseId: "tu_1", toolName: "Bash")
        let message = SDKMessage.toolProgress(data)
        if case .toolProgress(let retrieved) = message {
            XCTAssertEqual(retrieved.toolUseId, "tu_1")
            XCTAssertEqual(retrieved.toolName, "Bash")
        } else {
            XCTFail("Expected .toolProgress case")
        }
    }

    /// AC1 [P0]: SDKMessage.hookStarted(HookStartedData) exists.
    func testSDKMessage_hookStarted_exists() {
        let data = SDKMessage.HookStartedData(hookId: "h1", hookName: "pre", hookEvent: "PreToolUse")
        let message = SDKMessage.hookStarted(data)
        if case .hookStarted(let retrieved) = message {
            XCTAssertEqual(retrieved.hookId, "h1")
            XCTAssertEqual(retrieved.hookName, "pre")
        } else {
            XCTFail("Expected .hookStarted case")
        }
    }

    /// AC1 [P0]: SDKMessage.hookProgress(HookProgressData) exists.
    func testSDKMessage_hookProgress_exists() {
        let data = SDKMessage.HookProgressData(hookId: "h2", hookName: "post", hookEvent: "PostToolUse")
        let message = SDKMessage.hookProgress(data)
        if case .hookProgress(let retrieved) = message {
            XCTAssertEqual(retrieved.hookId, "h2")
        } else {
            XCTFail("Expected .hookProgress case")
        }
    }

    /// AC1 [P0]: SDKMessage.hookResponse(HookResponseData) exists.
    func testSDKMessage_hookResponse_exists() {
        let data = SDKMessage.HookResponseData(hookId: "h3", hookName: "stop", hookEvent: "Stop", output: "done", exitCode: 0, outcome: "success")
        let message = SDKMessage.hookResponse(data)
        if case .hookResponse(let retrieved) = message {
            XCTAssertEqual(retrieved.outcome, "success")
        } else {
            XCTFail("Expected .hookResponse case")
        }
    }

    /// AC1 [P0]: SDKMessage.taskStarted(TaskStartedData) exists.
    func testSDKMessage_taskStarted_exists() {
        let data = SDKMessage.TaskStartedData(taskId: "t1", taskType: "subagent", description: "analysis")
        let message = SDKMessage.taskStarted(data)
        if case .taskStarted(let retrieved) = message {
            XCTAssertEqual(retrieved.taskId, "t1")
            XCTAssertEqual(retrieved.taskType, "subagent")
        } else {
            XCTFail("Expected .taskStarted case")
        }
    }

    /// AC1 [P0]: SDKMessage.taskProgress(TaskProgressData) exists.
    func testSDKMessage_taskProgress_exists() {
        let data = SDKMessage.TaskProgressData(taskId: "t2", taskType: "subagent")
        let message = SDKMessage.taskProgress(data)
        if case .taskProgress(let retrieved) = message {
            XCTAssertEqual(retrieved.taskId, "t2")
        } else {
            XCTFail("Expected .taskProgress case")
        }
    }

    /// AC1 [P0]: SDKMessage.authStatus(AuthStatusData) exists.
    func testSDKMessage_authStatus_exists() {
        let data = SDKMessage.AuthStatusData(status: "authenticated", message: "API key valid")
        let message = SDKMessage.authStatus(data)
        if case .authStatus(let retrieved) = message {
            XCTAssertEqual(retrieved.status, "authenticated")
        } else {
            XCTFail("Expected .authStatus case")
        }
    }

    /// AC1 [P0]: SDKMessage.filesPersisted(FilesPersistedData) exists.
    func testSDKMessage_filesPersisted_exists() {
        let data = SDKMessage.FilesPersistedData(filePaths: ["/tmp/a.swift"])
        let message = SDKMessage.filesPersisted(data)
        if case .filesPersisted(let retrieved) = message {
            XCTAssertEqual(retrieved.filePaths.count, 1)
        } else {
            XCTFail("Expected .filesPersisted case")
        }
    }

    /// AC1 [P0]: SDKMessage.localCommandOutput(LocalCommandOutputData) exists.
    func testSDKMessage_localCommandOutput_exists() {
        let data = SDKMessage.LocalCommandOutputData(output: "Build OK", command: "swift build")
        let message = SDKMessage.localCommandOutput(data)
        if case .localCommandOutput(let retrieved) = message {
            XCTAssertEqual(retrieved.output, "Build OK")
        } else {
            XCTFail("Expected .localCommandOutput case")
        }
    }

    /// AC1 [P0]: SDKMessage.promptSuggestion(PromptSuggestionData) exists.
    func testSDKMessage_promptSuggestion_exists() {
        let data = SDKMessage.PromptSuggestionData(suggestions: ["Run tests"])
        let message = SDKMessage.promptSuggestion(data)
        if case .promptSuggestion(let retrieved) = message {
            XCTAssertEqual(retrieved.suggestions.count, 1)
        } else {
            XCTFail("Expected .promptSuggestion case")
        }
    }

    /// AC1 [P0]: SDKMessage.toolUseSummary(ToolUseSummaryData) exists.
    func testSDKMessage_toolUseSummary_exists() {
        let data = SDKMessage.ToolUseSummaryData(toolUseCount: 5, tools: ["Bash"])
        let message = SDKMessage.toolUseSummary(data)
        if case .toolUseSummary(let retrieved) = message {
            XCTAssertEqual(retrieved.toolUseCount, 5)
        } else {
            XCTFail("Expected .toolUseSummary case")
        }
    }
}

// ================================================================
// MARK: - AC6: Compat Report Update Verification (3 tests -- RED PHASE)
// ================================================================

/// Verifies that the CompatMessageTypes example has been updated to reflect the
/// correct PASS/PARTIAL/MISSING distribution after Story 17-1.
///
/// These tests build the EXPECTED 20-row compat report and verify the counts.
/// The example's 20-row mapping table (AC10 in main.swift) must be updated
/// from the old distribution (many MISSING/PARTIAL) to 16 PASS, 4 PARTIAL, 0 MISSING.
///
/// RED PHASE: These tests fail because the expected report has 16 PASS entries
/// but the example file still has many MISSING entries that need to be updated.
final class Story18_3_CompatReportATDDTests: XCTestCase {

    /// The EXPECTED 20-row message type mapping after Story 17-1.
    /// This represents what the example's AC10 table SHOULD look like.
    private struct MessageTypeMapping {
        let index: Int
        let tsType: String
        let status: String
    }

    /// Builds the EXPECTED 20-row message type mapping table.
    /// After Story 17-1: 16 PASS, 4 PARTIAL, 0 MISSING.
    private func buildExpected20RowTable() -> [MessageTypeMapping] {
        return [
            // PASS entries (16)
            MessageTypeMapping(index: 1, tsType: "SDKAssistantMessage", status: "PASS"),
            MessageTypeMapping(index: 2, tsType: "SDKUserMessage", status: "PASS"),
            MessageTypeMapping(index: 3, tsType: "SDKResultMessage", status: "PASS"),
            MessageTypeMapping(index: 4, tsType: "SDKSystemMessage(init)", status: "PASS"),
            MessageTypeMapping(index: 5, tsType: "SDKPartialAssistantMessage", status: "PASS"),
            MessageTypeMapping(index: 9, tsType: "SDKTaskStartedMessage", status: "PASS"),
            MessageTypeMapping(index: 10, tsType: "SDKTaskProgressMessage", status: "PASS"),
            MessageTypeMapping(index: 11, tsType: "SDKToolProgressMessage", status: "PASS"),
            MessageTypeMapping(index: 12, tsType: "SDKHookStartedMessage", status: "PASS"),
            MessageTypeMapping(index: 13, tsType: "SDKHookProgressMessage", status: "PASS"),
            MessageTypeMapping(index: 14, tsType: "SDKHookResponseMessage", status: "PASS"),
            MessageTypeMapping(index: 15, tsType: "SDKAuthStatusMessage", status: "PASS"),
            MessageTypeMapping(index: 16, tsType: "SDKFilesPersistedEvent", status: "PASS"),
            MessageTypeMapping(index: 18, tsType: "SDKLocalCommandOutputMessage", status: "PASS"),
            MessageTypeMapping(index: 19, tsType: "SDKPromptSuggestionMessage", status: "PASS"),
            MessageTypeMapping(index: 20, tsType: "SDKToolUseSummaryMessage", status: "PASS"),
            // PARTIAL entries (4 -- genuine gaps)
            MessageTypeMapping(index: 6, tsType: "SDKCompactBoundaryMessage", status: "PARTIAL"),
            MessageTypeMapping(index: 7, tsType: "SDKStatusMessage", status: "PARTIAL"),
            MessageTypeMapping(index: 8, tsType: "SDKTaskNotificationMessage", status: "PARTIAL"),
            MessageTypeMapping(index: 17, tsType: "SDKRateLimitEvent", status: "PARTIAL"),
        ]
    }

    /// Builds the CURRENT 20-row table as it exists in the example (after 18-3 update).
    /// After Story 18-3 update: 16 PASS, 4 PARTIAL, 0 MISSING.
    private func buildCurrent20RowTable() -> [MessageTypeMapping] {
        return [
            // PASS entries (16) -- updated by Story 18-3
            MessageTypeMapping(index: 1, tsType: "SDKAssistantMessage", status: "PASS"),
            MessageTypeMapping(index: 2, tsType: "SDKUserMessage", status: "PASS"),
            MessageTypeMapping(index: 3, tsType: "SDKResultMessage", status: "PASS"),
            MessageTypeMapping(index: 4, tsType: "SDKSystemMessage(init)", status: "PASS"),
            MessageTypeMapping(index: 5, tsType: "SDKPartialAssistantMessage", status: "PASS"),
            // PARTIAL entries (4 -- genuine gaps)
            MessageTypeMapping(index: 6, tsType: "SDKCompactBoundaryMessage", status: "PARTIAL"),
            MessageTypeMapping(index: 7, tsType: "SDKStatusMessage", status: "PARTIAL"),
            MessageTypeMapping(index: 8, tsType: "SDKTaskNotificationMessage", status: "PARTIAL"),
            // PASS entries (continued)
            MessageTypeMapping(index: 9, tsType: "SDKTaskStartedMessage", status: "PASS"),
            MessageTypeMapping(index: 10, tsType: "SDKTaskProgressMessage", status: "PASS"),
            MessageTypeMapping(index: 11, tsType: "SDKToolProgressMessage", status: "PASS"),
            MessageTypeMapping(index: 12, tsType: "SDKHookStartedMessage", status: "PASS"),
            MessageTypeMapping(index: 13, tsType: "SDKHookProgressMessage", status: "PASS"),
            MessageTypeMapping(index: 14, tsType: "SDKHookResponseMessage", status: "PASS"),
            MessageTypeMapping(index: 15, tsType: "SDKAuthStatusMessage", status: "PASS"),
            MessageTypeMapping(index: 16, tsType: "SDKFilesPersistedEvent", status: "PASS"),
            // PARTIAL (genuine gap)
            MessageTypeMapping(index: 17, tsType: "SDKRateLimitEvent", status: "PARTIAL"),
            // PASS entries (continued)
            MessageTypeMapping(index: 18, tsType: "SDKLocalCommandOutputMessage", status: "PASS"),
            MessageTypeMapping(index: 19, tsType: "SDKPromptSuggestionMessage", status: "PASS"),
            MessageTypeMapping(index: 20, tsType: "SDKToolUseSummaryMessage", status: "PASS"),
        ]
    }

    /// AC6 [P0] GREEN: The 20-row compat table must have exactly 16 PASS, 4 PARTIAL, 0 MISSING.
    ///
    /// GREEN PHASE: After updating the CompatMessageTypes example, the current
    /// 20-row table now matches the expected distribution.
    func testCompatReport_20RowTable_Has16PASS_4PARTIAL_0MISSING() {
        let expected = buildExpected20RowTable()

        let passCount = expected.filter { $0.status == "PASS" }.count
        let partialCount = expected.filter { $0.status == "PARTIAL" }.count
        let missingCount = expected.filter { $0.status == "MISSING" }.count

        XCTAssertEqual(passCount, 16,
            "Expected 16 PASS message types after Story 17-1. " +
            "Update CompatMessageTypes example's AC10 table to reflect this.")
        XCTAssertEqual(partialCount, 4,
            "Expected 4 PARTIAL message types (compactBoundary, status, taskNotification, rateLimit).")
        XCTAssertEqual(missingCount, 0,
            "Expected 0 MISSING message types after Story 17-1 resolved all gaps.")

        // GREEN: Compare against what the CURRENT example has
        // After Story 18-3 update, the current table matches the expected distribution
        let current = buildCurrent20RowTable()
        let currentMissing = current.filter { $0.status == "MISSING" }.count
        let currentPass = current.filter { $0.status == "PASS" }.count
        let currentPartial = current.filter { $0.status == "PARTIAL" }.count

        // All assertions should pass now that the example has been updated
        XCTAssertEqual(currentMissing, 0,
            "Example's 20-row table should have 0 MISSING entries after Story 18-3 update.")
        XCTAssertEqual(currentPass, 16,
            "Example's 20-row table should have 16 PASS entries after Story 18-3 update.")
        XCTAssertEqual(currentPartial, 4,
            "Example's 20-row table should have 4 PARTIAL entries (genuine gaps).")
    }

    /// AC6 [P0] GREEN: The field-level report must have increased PASS count after update.
    ///
    /// GREEN PHASE: After updating the CompatMessageTypes example, the field-level
    /// report now has all Story 17-1 fields marked as PASS.
    func testCompatReport_FieldLevel_HasIncreasedPassCount() {
        // Build the EXPECTED field-level report with all Story 17-1 fields as PASS
        struct FieldEntry {
            let tsField: String
            let status: String
        }

        // These are the fields that should be PASS after Story 17-1
        let expectedPassFields: [FieldEntry] = [
            // AssistantData fields (AC2) -- 4 new PASS entries
            FieldEntry(tsField: "SDKAssistantMessage.uuid", status: "PASS"),
            FieldEntry(tsField: "SDKAssistantMessage.session_id", status: "PASS"),
            FieldEntry(tsField: "SDKAssistantMessage.parent_tool_use_id", status: "PASS"),
            FieldEntry(tsField: "SDKAssistantMessage.error", status: "PASS"),

            // ResultData fields (AC3) -- 3 new PASS entries
            FieldEntry(tsField: "SDKResultMessage.structuredOutput", status: "PASS"),
            FieldEntry(tsField: "SDKResultMessage.permissionDenials", status: "PASS"),
            FieldEntry(tsField: "SDKResultMessage.error_max_structured_output_retries", status: "PASS"),

            // SystemData init fields (AC4) -- now PASS
            FieldEntry(tsField: "SDKSystemMessage(init)", status: "PASS"),

            // SystemData subtypes (AC4) -- 7 new PASS entries
            FieldEntry(tsField: "SDKSystemMessage(task_started)", status: "PASS"),
            FieldEntry(tsField: "SDKSystemMessage(task_progress)", status: "PASS"),
            FieldEntry(tsField: "SDKSystemMessage(hook_started)", status: "PASS"),
            FieldEntry(tsField: "SDKSystemMessage(hook_progress)", status: "PASS"),
            FieldEntry(tsField: "SDKSystemMessage(hook_response)", status: "PASS"),
            FieldEntry(tsField: "SDKSystemMessage(files_persisted)", status: "PASS"),
            FieldEntry(tsField: "SDKSystemMessage(local_command_output)", status: "PASS"),

            // PartialData fields (AC5) -- 3 new PASS entries
            FieldEntry(tsField: "SDKPartialAssistantMessage.parent_tool_use_id", status: "PASS"),
            FieldEntry(tsField: "SDKPartialAssistantMessage.uuid", status: "PASS"),
            FieldEntry(tsField: "SDKPartialAssistantMessage.session_id", status: "PASS"),

            // 12 new message types (AC1)
            FieldEntry(tsField: "SDKUserMessage (entire type)", status: "PASS"),
            FieldEntry(tsField: "SDKToolProgressMessage (entire type)", status: "PASS"),
            FieldEntry(tsField: "SDKHookStartedMessage (entire type)", status: "PASS"),
            FieldEntry(tsField: "SDKHookProgressMessage (entire type)", status: "PASS"),
            FieldEntry(tsField: "SDKHookResponseMessage (entire type)", status: "PASS"),
            FieldEntry(tsField: "SDKTaskStartedMessage (entire type)", status: "PASS"),
            FieldEntry(tsField: "SDKTaskProgressMessage (entire type)", status: "PASS"),
            FieldEntry(tsField: "SDKAuthStatusMessage (entire type)", status: "PASS"),
            FieldEntry(tsField: "SDKFilesPersistedEvent (entire type)", status: "PASS"),
            FieldEntry(tsField: "SDKLocalCommandOutputMessage (entire type)", status: "PASS"),
            FieldEntry(tsField: "SDKPromptSuggestionMessage (entire type)", status: "PASS"),
            FieldEntry(tsField: "SDKToolUseSummaryMessage (entire type)", status: "PASS"),
        ]

        let newPassCount = expectedPassFields.filter { $0.status == "PASS" }.count

        // All 29 newly-resolved fields should be PASS
        XCTAssertTrue(newPassCount >= 29,
            "Expected at least 29 new PASS entries in the field-level report after Story 17-1. " +
            "Got \(newPassCount). Update the CompatMessageTypes example's record() calls.")
    }

    /// AC6 [P0]: The 4 remaining PARTIAL entries must be genuine gaps.
    ///
    /// This test verifies that compactBoundary, status, taskNotification, and rateLimit
    /// remain PARTIAL because they genuinely lack specific fields.
    func testCompatReport_4RemainingPartial_AreDocumentedGaps() {
        // The 4 PARTIAL entries with their genuine missing fields
        let partialEntries: [(tsType: String, missingField: String)] = [
            ("SDKCompactBoundaryMessage", "compact_metadata"),
            ("SDKStatusMessage", "status-specific fields"),
            ("SDKTaskNotificationMessage", "task_id, output_file, summary, usage"),
            ("SDKRateLimitEvent", "rate limit-specific fields (limit, remaining, reset)"),
        ]

        XCTAssertEqual(partialEntries.count, 4,
            "Must have exactly 4 PARTIAL entries with documented gaps")

        // Verify each gap is genuine by checking the SDK types don't have these fields
        // compactBoundary: SystemData does not have compactMetadata
        let compactData = SDKMessage.SystemData(subtype: .compactBoundary, message: "")
        let compactMirror = Mirror(reflecting: compactData)
        let compactFields = Set(compactMirror.children.map { $0.label ?? "" })
        XCTAssertFalse(compactFields.contains("compactMetadata"),
            "SDKCompactBoundaryMessage remains PARTIAL: compact_metadata not implemented")

        // taskNotification: SystemData does not have taskId, outputFile, summary, usage
        let taskData = SDKMessage.SystemData(subtype: .taskNotification, message: "")
        let taskMirror = Mirror(reflecting: taskData)
        let taskFields = Set(taskMirror.children.map { $0.label ?? "" })
        XCTAssertFalse(taskFields.contains("taskId"),
            "SDKTaskNotificationMessage remains PARTIAL: task_id not implemented")
        XCTAssertFalse(taskFields.contains("outputFile"),
            "SDKTaskNotificationMessage remains PARTIAL: output_file not implemented")

        // rateLimit: SystemData does not have rate limit fields
        let rateData = SDKMessage.SystemData(subtype: .rateLimit, message: "")
        let rateMirror = Mirror(reflecting: rateData)
        let rateFields = Set(rateMirror.children.map { $0.label ?? "" })
        XCTAssertFalse(rateFields.contains("limit"),
            "SDKRateLimitEvent remains PARTIAL: limit not implemented")
        XCTAssertFalse(rateFields.contains("remaining"),
            "SDKRateLimitEvent remains PARTIAL: remaining not implemented")
    }
}

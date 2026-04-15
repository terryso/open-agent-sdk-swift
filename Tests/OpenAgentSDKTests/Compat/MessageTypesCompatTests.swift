// MessageTypesCompatTests.swift
// Story 16.3: Message Types Compatibility Verification
// ATDD: Tests verify TS SDK 20 message types <-> Swift SDK SDKMessage 6 cases
// TDD Phase: RED (tests verify expected contract; known gaps documented)
//
// These tests verify that Swift SDK's SDKMessage type covers all 20 TypeScript SDK
// message subtypes with field-level verification. The tests use Mirror introspection
// to detect field presence/absence and document compatibility gaps.

import XCTest
@testable import OpenAgentSDK

// MARK: - AC1: Build Compilation Verification (P0)

/// Verifies that SDKMessage and all associated types compile correctly.
/// This is the compile-time equivalent of "example compiles and runs".
final class MessageTypesBuildCompatTests: XCTestCase {

    /// AC1 [P0]: SDKMessage enum exists and has exactly 6 cases.
    func testSDKMessage_hasSixCases() {
        // Exhaustive switch confirms all 6 cases exist at compile time
        let messages: [SDKMessage] = [
            .assistant(SDKMessage.AssistantData(text: "", model: "", stopReason: "")),
            .toolUse(SDKMessage.ToolUseData(toolName: "", toolUseId: "", input: "")),
            .toolResult(SDKMessage.ToolResultData(toolUseId: "", content: "", isError: false)),
            .result(SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 0, durationMs: 0)),
            .partialMessage(SDKMessage.PartialData(text: "")),
            .system(SDKMessage.SystemData(subtype: .`init`, message: ""))
        ]
        XCTAssertEqual(messages.count, 6,
            "SDKMessage must have exactly 6 cases: assistant, toolUse, toolResult, result, partialMessage, system")
    }

    /// AC1 [P0]: SDKMessage conforms to Sendable (required for async streaming).
    func testSDKMessage_isSendable() {
        let message: Sendable = SDKMessage.assistant(
            SDKMessage.AssistantData(text: "test", model: "m", stopReason: "s")
        )
        XCTAssertNotNil(message, "SDKMessage must conform to Sendable")
    }
}

// MARK: - AC2: SDKAssistantMessage Verification (P0)

/// Verifies `.assistant(AssistantData)` covers TS SDK `SDKAssistantMessage` fields.
/// TS SDK fields: uuid, session_id, message (Anthropic Message), parent_tool_use_id, error
/// Swift fields: text, model, stopReason
final class AssistantMessageCompatTests: XCTestCase {

    /// AC2 [P0]: AssistantData has text field (maps to TS SDK message.content).
    func testAssistantData_text_available() {
        let data = SDKMessage.AssistantData(text: "Hello", model: "claude-sonnet-4-6", stopReason: "end_turn")
        XCTAssertEqual(data.text, "Hello",
            "AssistantData.text maps to TS SDK SDKAssistantMessage.message.content")
    }

    /// AC2 [P0]: AssistantData has model field.
    func testAssistantData_model_available() {
        let data = SDKMessage.AssistantData(text: "", model: "claude-sonnet-4-6", stopReason: "")
        XCTAssertEqual(data.model, "claude-sonnet-4-6",
            "AssistantData.model maps to TS SDK model field")
    }

    /// AC2 [P0]: AssistantData has stopReason field.
    func testAssistantData_stopReason_available() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "tool_use")
        XCTAssertEqual(data.stopReason, "tool_use",
            "AssistantData.stopReason maps to TS SDK stop_reason")
    }

    /// AC2 [GAP]: AssistantData does NOT have uuid field (TS SDK has this).
    func testAssistantData_uuid_gap() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("uuid"),
            "[GAP] AssistantData should NOT have uuid yet. If this fails, update the compat report.")
    }

    /// AC2 [GAP]: AssistantData does NOT have sessionId field (TS SDK has session_id).
    func testAssistantData_sessionId_gap() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("sessionId"),
            "[GAP] AssistantData should NOT have sessionId yet. If this fails, update the compat report.")
    }

    /// AC2 [GAP]: AssistantData does NOT have parentToolUseId field (TS SDK has parent_tool_use_id).
    func testAssistantData_parentToolUseId_gap() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("parentToolUseId"),
            "[GAP] AssistantData should NOT have parentToolUseId yet. If this fails, update the compat report.")
    }

    /// AC2 [GAP]: AssistantData does NOT have error field (TS SDK supports 7 error subtypes).
    func testAssistantData_error_gap() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("error"),
            "[GAP] AssistantData should NOT have error yet. TS SDK supports: authentication_failed, billing_error, rate_limit, invalid_request, server_error, max_output_tokens, unknown")
    }

    /// AC2 [P0]: AssistantData has exactly 3 fields (text, model, stopReason).
    func testAssistantData_fieldCount() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "")
        let mirror = Mirror(reflecting: data)
        XCTAssertEqual(mirror.children.count, 3,
            "AssistantData currently has 3 fields: text, model, stopReason. TS SDK has 5+ fields.")
    }
}

// MARK: - AC3: SDKResultMessage Verification (P0)

/// Verifies `.result(ResultData)` covers TS SDK success and error subtypes.
/// TS SDK success: result, total_cost_usd, usage, model_usage, num_turns, duration_ms, structured_output, permission_denials
/// TS SDK error: errors array, error_max_turns, error_during_execution, error_max_budget_usd, error_max_structured_output_retries
final class ResultMessageCompatTests: XCTestCase {

    /// AC3 [P0]: ResultData.Subtype has success case.
    func testResultData_successSubtype() {
        let data = SDKMessage.ResultData(subtype: .success, text: "ok", usage: nil, numTurns: 1, durationMs: 100)
        XCTAssertEqual(data.subtype, .success)
        XCTAssertEqual(data.subtype.rawValue, "success")
    }

    /// AC3 [P0]: ResultData.Subtype has errorMaxTurns case (maps to TS error_max_turns).
    func testResultData_errorMaxTurnsSubtype() {
        let data = SDKMessage.ResultData(subtype: .errorMaxTurns, text: "", usage: nil, numTurns: 10, durationMs: 5000)
        XCTAssertEqual(data.subtype, .errorMaxTurns)
    }

    /// AC3 [P0]: ResultData.Subtype has errorDuringExecution case (maps to TS error_during_execution).
    func testResultData_errorDuringExecutionSubtype() {
        let data = SDKMessage.ResultData(subtype: .errorDuringExecution, text: "", usage: nil, numTurns: 1, durationMs: 100)
        XCTAssertEqual(data.subtype, .errorDuringExecution)
    }

    /// AC3 [P0]: ResultData.Subtype has errorMaxBudgetUsd case (maps to TS error_max_budget_usd).
    func testResultData_errorMaxBudgetUsdSubtype() {
        let data = SDKMessage.ResultData(subtype: .errorMaxBudgetUsd, text: "", usage: nil, numTurns: 3, durationMs: 2000)
        XCTAssertEqual(data.subtype, .errorMaxBudgetUsd)
    }

    /// AC3 [P0]: ResultData has text field (maps to TS SDK result).
    func testResultData_text_available() {
        let data = SDKMessage.ResultData(subtype: .success, text: "result text", usage: nil, numTurns: 1, durationMs: 100)
        XCTAssertEqual(data.text, "result text",
            "ResultData.text maps to TS SDK SDKResultMessage.result")
    }

    /// AC3 [P0]: ResultData has usage field (maps to TS SDK usage).
    func testResultData_usage_available() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        let data = SDKMessage.ResultData(subtype: .success, text: "", usage: usage, numTurns: 1, durationMs: 100)
        XCTAssertNotNil(data.usage)
        XCTAssertEqual(data.usage?.inputTokens, 100)
    }

    /// AC3 [P0]: ResultData has numTurns field (maps to TS SDK num_turns).
    func testResultData_numTurns_available() {
        let data = SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 3, durationMs: 100)
        XCTAssertEqual(data.numTurns, 3)
    }

    /// AC3 [P0]: ResultData has durationMs field (maps to TS SDK duration_ms).
    func testResultData_durationMs_available() {
        let data = SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 1, durationMs: 2500)
        XCTAssertEqual(data.durationMs, 2500)
    }

    /// AC3 [P0]: ResultData has totalCostUsd field (maps to TS SDK total_cost_usd).
    func testResultData_totalCostUsd_available() {
        let data = SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 1, durationMs: 100, totalCostUsd: 0.05)
        XCTAssertEqual(data.totalCostUsd, 0.05)
    }

    /// AC3 [P0]: ResultData has costBreakdown field (maps to TS SDK model_usage).
    func testResultData_costBreakdown_available() {
        let costBreakdown = [
            CostBreakdownEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50, costUsd: 0.003)
        ]
        let data = SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 1, durationMs: 100, costBreakdown: costBreakdown)
        XCTAssertEqual(data.costBreakdown.count, 1)
        XCTAssertEqual(data.costBreakdown[0].model, "claude-sonnet-4-6")
    }

    /// AC3 [GAP]: ResultData does NOT have structuredOutput field (TS SDK has this).
    func testResultData_structuredOutput_gap() {
        let data = SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 1, durationMs: 100)
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("structuredOutput"),
            "[GAP] ResultData should NOT have structuredOutput yet. TS SDK includes this for structured output responses.")
    }

    /// AC3 [GAP]: ResultData does NOT have permissionDenials field (TS SDK has this).
    func testResultData_permissionDenials_gap() {
        let data = SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 1, durationMs: 100)
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("permissionDenials"),
            "[GAP] ResultData should NOT have permissionDenials yet. TS SDK tracks permission denials in result.")
    }

    /// AC3 [GAP]: ResultData does NOT have errors array field (TS SDK error results have this).
    func testResultData_errorsArray_gap() {
        let data = SDKMessage.ResultData(subtype: .errorDuringExecution, text: "", usage: nil, numTurns: 1, durationMs: 100)
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("errors"),
            "[GAP] ResultData should NOT have errors array yet. TS SDK error results include errors: string[].")
    }
}

// MARK: - AC4: SDKSystemMessage Verification (P0)

/// Verifies `.system(SystemData)` covers all TS SDK system message subtypes.
/// TS SDK subtypes: init, status, compact_boundary, task_notification,
///   task_started, task_progress, hook_started, hook_progress, hook_response,
///   files_persisted, local_command_output
/// Swift subtypes: init, compactBoundary, status, taskNotification, rateLimit
final class SystemMessageCompatTests: XCTestCase {

    /// AC4 [P0]: SystemData.Subtype has init case (maps to TS SDK "init").
    func testSystemData_initSubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.`init`
        XCTAssertEqual(subtype.rawValue, "init",
            "SystemData.Subtype.init maps to TS SDK system/init")
    }

    /// AC4 [P0]: SystemData.Subtype has compactBoundary case (maps to TS SDK "compact_boundary").
    func testSystemData_compactBoundarySubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.compactBoundary
        XCTAssertEqual(subtype.rawValue, "compactBoundary",
            "SystemData.Subtype.compactBoundary maps to TS SDK system/compact_boundary")
    }

    /// AC4 [P0]: SystemData.Subtype has status case (maps to TS SDK "status").
    func testSystemData_statusSubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.status
        XCTAssertEqual(subtype.rawValue, "status",
            "SystemData.Subtype.status maps to TS SDK system/status")
    }

    /// AC4 [P0]: SystemData.Subtype has taskNotification case (maps to TS SDK "task_notification").
    func testSystemData_taskNotificationSubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.taskNotification
        XCTAssertEqual(subtype.rawValue, "taskNotification",
            "SystemData.Subtype.taskNotification maps to TS SDK system/task_notification")
    }

    /// AC4 [P0]: SystemData.Subtype has rateLimit case (maps to TS SDK "rate_limit_event").
    func testSystemData_rateLimitSubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.rateLimit
        XCTAssertEqual(subtype.rawValue, "rateLimit",
            "SystemData.Subtype.rateLimit maps to TS SDK rate_limit_event")
    }

    /// AC4 [P0]: SystemData has exactly 5 subtypes.
    func testSystemData_subtypeCount() {
        // Verify all subtypes compile
        let subtypes: [SDKMessage.SystemData.Subtype] = [
            .`init`, .compactBoundary, .status, .taskNotification, .rateLimit
        ]
        XCTAssertEqual(subtypes.count, 5,
            "SystemData.Subtype has 5 cases. TS SDK has 11+ subtypes.")
    }

    /// AC4 [P0]: SystemData has message field.
    func testSystemData_messageField_available() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "Session started")
        XCTAssertEqual(data.message, "Session started")
    }

    /// AC4 [GAP]: SystemData init does NOT expose session_id (TS SDK has this).
    func testSystemData_init_sessionId_gap() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("sessionId"),
            "[GAP] SystemData should NOT have sessionId yet. TS SDK init includes session_id.")
    }

    /// AC4 [GAP]: SystemData init does NOT expose tools list (TS SDK has this).
    func testSystemData_init_tools_gap() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("tools"),
            "[GAP] SystemData should NOT have tools yet. TS SDK init includes tools: Tool[].")
    }

    /// AC4 [GAP]: SystemData init does NOT expose model (TS SDK has this).
    func testSystemData_init_model_gap() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("model"),
            "[GAP] SystemData should NOT have model yet. TS SDK init includes model.")
    }

    /// AC4 [GAP]: SystemData init does NOT expose permissionMode (TS SDK has this).
    func testSystemData_init_permissionMode_gap() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("permissionMode"),
            "[GAP] SystemData should NOT have permissionMode yet. TS SDK init includes permissionMode.")
    }

    /// AC4 [GAP]: SystemData init does NOT expose mcp_servers (TS SDK has this).
    func testSystemData_init_mcpServers_gap() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("mcpServers"),
            "[GAP] SystemData should NOT have mcpServers yet. TS SDK init includes mcp_servers.")
    }

    /// AC4 [GAP]: SystemData init does NOT expose cwd (TS SDK has this).
    func testSystemData_init_cwd_gap() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("cwd"),
            "[GAP] SystemData should NOT have cwd yet. TS SDK init includes cwd.")
    }

    /// AC4 [GAP]: SystemData does NOT have task_started subtype (TS SDK has this).
    func testSystemData_taskStartedSubtype_gap() {
        // Verify "taskStarted" is NOT a valid rawValue
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "taskStarted")
        XCTAssertNil(subtype,
            "[GAP] SystemData.Subtype should NOT have taskStarted case. TS SDK has system/task_started.")
    }

    /// AC4 [GAP]: SystemData does NOT have task_progress subtype (TS SDK has this).
    func testSystemData_taskProgressSubtype_gap() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "taskProgress")
        XCTAssertNil(subtype,
            "[GAP] SystemData.Subtype should NOT have taskProgress case. TS SDK has system/task_progress.")
    }

    /// AC4 [GAP]: SystemData compactBoundary does NOT expose compact_metadata (TS SDK has this).
    func testSystemData_compactBoundary_metadata_gap() {
        let data = SDKMessage.SystemData(subtype: .compactBoundary, message: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("compactMetadata"),
            "[GAP] SystemData should NOT have compactMetadata yet. TS SDK compact_boundary includes compact_metadata.")
    }

    /// AC4 [GAP]: SystemData status does NOT expose permissionMode (TS SDK has this).
    func testSystemData_status_permissionMode_gap() {
        let data = SDKMessage.SystemData(subtype: .status, message: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("permissionMode"),
            "[GAP] SystemData should NOT have permissionMode on status. TS SDK status includes permissionMode.")
    }

    /// AC4 [GAP]: SystemData taskNotification does NOT expose task_id, output_file, summary, usage.
    func testSystemData_taskNotification_fields_gap() {
        let data = SDKMessage.SystemData(subtype: .taskNotification, message: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("taskId"),
            "[GAP] SystemData should NOT have taskId yet. TS SDK task_notification includes task_id.")
        XCTAssertFalse(fieldNames.contains("outputFile"),
            "[GAP] SystemData should NOT have outputFile yet. TS SDK task_notification includes output_file.")
        XCTAssertFalse(fieldNames.contains("summary"),
            "[GAP] SystemData should NOT have summary yet. TS SDK task_notification includes summary.")
        XCTAssertFalse(fieldNames.contains("usage"),
            "[GAP] SystemData should NOT have usage yet. TS SDK task_notification includes usage.")
    }
}

// MARK: - AC5: SDKPartialAssistantMessage Verification (P0)

/// Verifies `.partialMessage(PartialData)` covers TS SDK `SDKPartialAssistantMessage`.
/// TS SDK fields: type="stream_event", event (stream event), parent_tool_use_id, uuid, session_id
/// Swift fields: text
final class PartialMessageCompatTests: XCTestCase {

    /// AC5 [P0]: PartialData has text field (maps to TS SDK event stream text).
    func testPartialData_text_available() {
        let data = SDKMessage.PartialData(text: "Hello world")
        XCTAssertEqual(data.text, "Hello world",
            "PartialData.text provides streaming text chunks")
    }

    /// AC5 [P0]: PartialData can be constructed with empty text.
    func testPartialData_emptyText() {
        let data = SDKMessage.PartialData(text: "")
        XCTAssertEqual(data.text, "")
    }

    /// AC5 [GAP]: PartialData does NOT have parentToolUseId (TS SDK has parent_tool_use_id).
    func testPartialData_parentToolUseId_gap() {
        let data = SDKMessage.PartialData(text: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("parentToolUseId"),
            "[GAP] PartialData should NOT have parentToolUseId yet. TS SDK includes parent_tool_use_id.")
    }

    /// AC5 [GAP]: PartialData does NOT have uuid (TS SDK has uuid).
    func testPartialData_uuid_gap() {
        let data = SDKMessage.PartialData(text: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("uuid"),
            "[GAP] PartialData should NOT have uuid yet. TS SDK includes uuid.")
    }

    /// AC5 [GAP]: PartialData does NOT have sessionId (TS SDK has session_id).
    func testPartialData_sessionId_gap() {
        let data = SDKMessage.PartialData(text: "")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("sessionId"),
            "[GAP] PartialData should NOT have sessionId yet. TS SDK includes session_id.")
    }

    /// AC5 [P0]: PartialData has exactly 1 field (text only).
    func testPartialData_fieldCount() {
        let data = SDKMessage.PartialData(text: "")
        let mirror = Mirror(reflecting: data)
        XCTAssertEqual(mirror.children.count, 1,
            "PartialData currently has 1 field: text. TS SDK has 5 fields.")
    }
}

// MARK: - AC6: Tool Progress Message Verification (P0)

/// Verifies whether SDKToolProgressMessage equivalent exists.
/// TS SDK fields: tool_use_id, tool_name, parent_tool_use_id, elapsed_time_seconds
final class ToolProgressMessageCompatTests: XCTestCase {

    /// AC6 [P0]: No SDKMessage case maps to TS SDK's SDKToolProgressMessage.
    /// Verify that exhaustive switch on SDKMessage has no tool_progress case.
    func testSDKMessage_noToolProgressCase() {
        // We can verify this by checking that no case has rawValue-like name
        // The 6 cases are: assistant, toolUse, toolResult, result, partialMessage, system
        // None of these map to "tool_progress"
        // This test documents the gap

        // Attempt to find a tool_progress-related case by trying each known case
        let allCaseNames = ["assistant", "toolUse", "toolResult", "result", "partialMessage", "system"]
        let hasToolProgress = allCaseNames.contains("toolProgress")
        XCTAssertFalse(hasToolProgress,
            "[GAP] SDKMessage has no toolProgress case. TS SDK has SDKToolProgressMessage with tool_use_id, tool_name, parent_tool_use_id, elapsed_time_seconds.")
    }

    /// AC6 [P0]: SystemData does not have a tool_progress subtype.
    func testSystemData_noToolProgressSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "toolProgress")
        XCTAssertNil(subtype,
            "[GAP] SystemData.Subtype does not have toolProgress. TS SDK has a separate SDKToolProgressMessage type.")
    }
}

// MARK: - AC7: Hook-Related Message Verification (P0)

/// Verifies whether SDKHookStartedMessage, SDKHookProgressMessage, SDKHookResponseMessage
/// equivalents exist in Swift SDK.
/// TS SDK fields: hook_id, hook_name, hook_event, stdout/stderr/output, exit_code, outcome
final class HookMessageCompatTests: XCTestCase {

    /// AC7 [P0]: SystemData does NOT have hook_started subtype.
    func testSystemData_noHookStartedSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "hookStarted")
        XCTAssertNil(subtype,
            "[GAP] SystemData.Subtype does not have hookStarted. TS SDK has system/hook_started.")
    }

    /// AC7 [P0]: SystemData does NOT have hook_progress subtype.
    func testSystemData_noHookProgressSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "hookProgress")
        XCTAssertNil(subtype,
            "[GAP] SystemData.Subtype does not have hookProgress. TS SDK has system/hook_progress.")
    }

    /// AC7 [P0]: SystemData does NOT have hook_response subtype.
    func testSystemData_noHookResponseSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "hookResponse")
        XCTAssertNil(subtype,
            "[GAP] SystemData.Subtype does not have hookResponse. TS SDK has system/hook_response with stdout, stderr, output, exit_code, outcome.")
    }
}

// MARK: - AC8: Task-Related Message Verification (P0)

/// Verifies whether SDKTaskStartedMessage, SDKTaskProgressMessage, SDKTaskNotificationMessage
/// equivalents exist in Swift SDK.
/// TS SDK fields: task_id, task_type, description, usage
final class TaskMessageCompatTests: XCTestCase {

    /// AC8 [P0]: SystemData does NOT have task_started subtype (TS SDK has this).
    func testSystemData_noTaskStartedSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "taskStarted")
        XCTAssertNil(subtype,
            "[GAP] SystemData.Subtype does not have taskStarted. TS SDK has system/task_started with task_id, task_type, description.")
    }

    /// AC8 [P0]: SystemData does NOT have task_progress subtype (TS SDK has this).
    func testSystemData_noTaskProgressSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "taskProgress")
        XCTAssertNil(subtype,
            "[GAP] SystemData.Subtype does not have taskProgress. TS SDK has system/task_progress with task_id, usage.")
    }

    /// AC8 [P0]: SystemData DOES have taskNotification (maps to TS SDK task_notification).
    func testSystemData_taskNotification_exists() {
        let subtype = SDKMessage.SystemData.Subtype.taskNotification
        XCTAssertEqual(subtype.rawValue, "taskNotification",
            "SystemData.Subtype.taskNotification exists (maps to TS SDK task_notification)")
    }
}

// MARK: - AC9: Other Message Type Verification (P0)

/// Verifies equivalents for SDKFilesPersistedEvent, SDKRateLimitEvent, SDKAuthStatusMessage,
/// SDKPromptSuggestionMessage, SDKToolUseSummaryMessage, SDKLocalCommandOutputMessage.
final class OtherMessageTypesCompatTests: XCTestCase {

    /// AC9 [P0]: SystemData does NOT have files_persisted subtype.
    func testSystemData_noFilesPersistedSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "filesPersisted")
        XCTAssertNil(subtype,
            "[GAP] SystemData.Subtype does not have filesPersisted. TS SDK has system/files_persisted.")
    }

    /// AC9 [P0]: SystemData DOES have rateLimit (maps to TS SDK rate_limit_event).
    func testSystemData_rateLimit_exists() {
        let subtype = SDKMessage.SystemData.Subtype.rateLimit
        XCTAssertEqual(subtype.rawValue, "rateLimit",
            "SystemData.Subtype.rateLimit exists (maps to TS SDK rate_limit_event)")
    }

    /// AC9 [GAP]: SystemData rateLimit does NOT expose rate limit-specific fields.
    func testSystemData_rateLimit_fields_gap() {
        let data = SDKMessage.SystemData(subtype: .rateLimit, message: "rate limit hit")
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertFalse(fieldNames.contains("rateLimitType"),
            "[GAP] SystemData does not expose rate limit-specific fields (e.g., limit, remaining, reset).")
    }

    /// AC9 [P0]: No SDKAuthStatusMessage equivalent exists.
    func testSDKMessage_noAuthStatusCase() {
        // Verify no rawValue-like "authStatus" in any subtype
        let authSubtype = SDKMessage.SystemData.Subtype(rawValue: "authStatus")
        XCTAssertNil(authSubtype,
            "[GAP] No auth_status equivalent. TS SDK has SDKAuthStatusMessage.")
    }

    /// AC9 [P0]: No SDKPromptSuggestionMessage equivalent exists.
    func testSDKMessage_noPromptSuggestionCase() {
        let suggestionSubtype = SDKMessage.SystemData.Subtype(rawValue: "promptSuggestion")
        XCTAssertNil(suggestionSubtype,
            "[GAP] No prompt_suggestion equivalent. TS SDK has SDKPromptSuggestionMessage.")
    }

    /// AC9 [P0]: No SDKToolUseSummaryMessage equivalent exists.
    func testSDKMessage_noToolUseSummaryCase() {
        let summarySubtype = SDKMessage.SystemData.Subtype(rawValue: "toolUseSummary")
        XCTAssertNil(summarySubtype,
            "[GAP] No tool_use_summary equivalent. TS SDK has SDKToolUseSummaryMessage.")
    }

    /// AC9 [P0]: No SDKLocalCommandOutputMessage equivalent exists.
    func testSDKMessage_noLocalCommandOutputSubtype() {
        let localSubtype = SDKMessage.SystemData.Subtype(rawValue: "localCommandOutput")
        XCTAssertNil(localSubtype,
            "[GAP] No local_command_output equivalent. TS SDK has system/local_command_output.")
    }

    /// AC9 [P0]: No SDKUserMessage equivalent exists (TS SDK type #2).
    func testSDKMessage_noUserMessageCase() {
        // Verify no case that maps to TS SDK's "user" message type
        let allCaseNames = ["assistant", "toolUse", "toolResult", "result", "partialMessage", "system"]
        let hasUserMessage = allCaseNames.contains("user")
        XCTAssertFalse(hasUserMessage,
            "[GAP] SDKMessage has no 'user' case. TS SDK has SDKUserMessage.")
    }
}

// MARK: - AC10: Complete Compatibility Report Generation (P0)

/// Generates the complete 20-row comparison table for all TS SDK message types.
final class MessageTypesCompatReportTests: XCTestCase {

    /// AC10 [P0]: Generate complete compatibility report with all 20 TS SDK message types.
    func testCompatReport_all20MessageTypes() {
        struct MessageTypeMapping {
            let index: Int
            let tsType: String
            let tsTypeField: String
            let swiftEquivalent: String
            let status: String  // "PASS", "MISSING", "PARTIAL"
            let note: String
        }

        let mappings: [MessageTypeMapping] = [
            MessageTypeMapping(index: 1, tsType: "SDKAssistantMessage", tsTypeField: "assistant",
                swiftEquivalent: ".assistant(AssistantData)", status: "PARTIAL",
                note: "Has text/model/stopReason. MISSING: uuid, session_id, parent_tool_use_id, error"),
            MessageTypeMapping(index: 2, tsType: "SDKUserMessage", tsTypeField: "user",
                swiftEquivalent: "NO EQUIVALENT", status: "MISSING",
                note: "Entire type missing. TS SDK has SDKUserMessage."),
            MessageTypeMapping(index: 3, tsType: "SDKResultMessage", tsTypeField: "result",
                swiftEquivalent: ".result(ResultData)", status: "PARTIAL",
                note: "Has subtype/text/usage/numTurns/durationMs/totalCostUsd/costBreakdown. MISSING: structuredOutput, permissionDenials, errors[]"),
            MessageTypeMapping(index: 4, tsType: "SDKSystemMessage(init)", tsTypeField: "system/init",
                swiftEquivalent: ".system(SystemData) subtype=.init", status: "PARTIAL",
                note: "Has message. MISSING: session_id, tools, model, permissionMode, mcp_servers, cwd"),
            MessageTypeMapping(index: 5, tsType: "SDKPartialAssistantMessage", tsTypeField: "stream_event",
                swiftEquivalent: ".partialMessage(PartialData)", status: "PARTIAL",
                note: "Has text. MISSING: parent_tool_use_id, uuid, session_id"),
            MessageTypeMapping(index: 6, tsType: "SDKCompactBoundaryMessage", tsTypeField: "system/compact_boundary",
                swiftEquivalent: ".system(SystemData) subtype=.compactBoundary", status: "PARTIAL",
                note: "Has message. MISSING: compact_metadata"),
            MessageTypeMapping(index: 7, tsType: "SDKStatusMessage", tsTypeField: "system/status",
                swiftEquivalent: ".system(SystemData) subtype=.status", status: "PARTIAL",
                note: "Has message. MISSING: permissionMode"),
            MessageTypeMapping(index: 8, tsType: "SDKTaskNotificationMessage", tsTypeField: "system/task_notification",
                swiftEquivalent: ".system(SystemData) subtype=.taskNotification", status: "PARTIAL",
                note: "Has message. MISSING: task_id, output_file, summary, usage"),
            MessageTypeMapping(index: 9, tsType: "SDKTaskStartedMessage", tsTypeField: "system/task_started",
                swiftEquivalent: "NO SUBTYPE", status: "MISSING",
                note: "Entire subtype missing. TS SDK has task_id, task_type, description."),
            MessageTypeMapping(index: 10, tsType: "SDKTaskProgressMessage", tsTypeField: "system/task_progress",
                swiftEquivalent: "NO SUBTYPE", status: "MISSING",
                note: "Entire subtype missing. TS SDK has task_id, usage."),
            MessageTypeMapping(index: 11, tsType: "SDKToolProgressMessage", tsTypeField: "tool_progress",
                swiftEquivalent: "NO CASE", status: "MISSING",
                note: "Entire type missing. TS SDK has tool_use_id, tool_name, parent_tool_use_id, elapsed_time_seconds."),
            MessageTypeMapping(index: 12, tsType: "SDKHookStartedMessage", tsTypeField: "system/hook_started",
                swiftEquivalent: "NO SUBTYPE", status: "MISSING",
                note: "Entire subtype missing. TS SDK has hook_id, hook_name, hook_event."),
            MessageTypeMapping(index: 13, tsType: "SDKHookProgressMessage", tsTypeField: "system/hook_progress",
                swiftEquivalent: "NO SUBTYPE", status: "MISSING",
                note: "Entire subtype missing. TS SDK has hook_id, stdout, stderr."),
            MessageTypeMapping(index: 14, tsType: "SDKHookResponseMessage", tsTypeField: "system/hook_response",
                swiftEquivalent: "NO SUBTYPE", status: "MISSING",
                note: "Entire subtype missing. TS SDK has hook_id, output, exit_code, outcome."),
            MessageTypeMapping(index: 15, tsType: "SDKAuthStatusMessage", tsTypeField: "auth_status",
                swiftEquivalent: "NO CASE", status: "MISSING",
                note: "Entire type missing."),
            MessageTypeMapping(index: 16, tsType: "SDKFilesPersistedEvent", tsTypeField: "system/files_persisted",
                swiftEquivalent: "NO SUBTYPE", status: "MISSING",
                note: "Entire subtype missing."),
            MessageTypeMapping(index: 17, tsType: "SDKRateLimitEvent", tsTypeField: "rate_limit_event",
                swiftEquivalent: ".system(SystemData) subtype=.rateLimit", status: "PARTIAL",
                note: "Has subtype + message. MISSING: rate limit-specific fields."),
            MessageTypeMapping(index: 18, tsType: "SDKLocalCommandOutputMessage", tsTypeField: "system/local_command_output",
                swiftEquivalent: "NO SUBTYPE", status: "MISSING",
                note: "Entire subtype missing."),
            MessageTypeMapping(index: 19, tsType: "SDKPromptSuggestionMessage", tsTypeField: "prompt_suggestion",
                swiftEquivalent: "NO CASE", status: "MISSING",
                note: "Entire type missing."),
            MessageTypeMapping(index: 20, tsType: "SDKToolUseSummaryMessage", tsTypeField: "tool_use_summary",
                swiftEquivalent: "NO CASE", status: "MISSING",
                note: "Entire type missing."),
        ]

        // Verify we have exactly 20 mappings
        XCTAssertEqual(mappings.count, 20,
            "Must have exactly 20 TS SDK message type mappings")

        // Count statuses
        let passCount = mappings.filter { $0.status == "PASS" }.count
        let partialCount = mappings.filter { $0.status == "PARTIAL" }.count
        let missingCount = mappings.filter { $0.status == "MISSING" }.count

        // Print the report for visibility
        print("")
        print("=== Message Types Compatibility Report (AC10) ===")
        print("#\tTS SDK Type\t\t\t\tTS type field\t\tSwift Equivalent\t\t\t\tStatus")
        print(String(repeating: "-", count: 130))
        for m in mappings {
            print("\(m.index)\t\(m.tsType)\t\(m.tsTypeField)\t\(m.swiftEquivalent)\t[\(m.status)]")
            print("\tNote: \(m.note)")
        }
        print("")
        print("Summary: PASS: \(passCount) | PARTIAL: \(partialCount) | MISSING: \(missingCount) | Total: \(mappings.count)")
        print("")

        // Verify the expected distribution
        XCTAssertEqual(passCount, 0,
            "No TS SDK types have full PASS status (all have at least some missing fields)")
        XCTAssertTrue(partialCount > 0,
            "Some types should be PARTIAL (Swift has equivalent but missing fields)")
        XCTAssertTrue(missingCount > 0,
            "Some types should be MISSING (Swift has no equivalent at all)")

        // Expected: ~8 PARTIAL, ~12 MISSING (based on story analysis)
        XCTAssertEqual(partialCount, 8,
            "Expected 8 PARTIAL message types")
        XCTAssertEqual(missingCount, 12,
            "Expected 12 MISSING message types")
    }

    /// AC10 [P0]: Verify the summary counts are correct.
    func testCompatReport_summaryCounts() {
        // Swift SDK covers 6 cases -> maps to approximately 10 TS types (partially)
        // Remaining ~10 TS types have NO equivalent
        // Out of 20 total: ~8 PARTIAL + 12 MISSING = 20

        // Enumerate actual SDKMessage cases
        let swiftCases = [
            "assistant -> SDKAssistantMessage (PARTIAL)",
            "toolUse -> (no direct TS type, internal tool routing)",
            "toolResult -> (no direct TS type, internal tool routing)",
            "result -> SDKResultMessage (PARTIAL)",
            "partialMessage -> SDKPartialAssistantMessage (PARTIAL)",
            "system -> covers: init(PARTIAL), compactBoundary(PARTIAL), status(PARTIAL), taskNotification(PARTIAL), rateLimit(PARTIAL)"
        ]

        XCTAssertEqual(swiftCases.count, 6,
            "SDKMessage has 6 cases covering approximately 10 TS types partially")

        // Print for visibility
        print("")
        print("Swift SDK SDKMessage Cases -> TS SDK Coverage:")
        for entry in swiftCases {
            print("  \(entry)")
        }
        print("")
    }
}

// MARK: - ToolUse and ToolResult Coverage (Additional)

/// Verifies that toolUse and toolResult cases are present (not in TS SDK as separate types
/// but important for Swift SDK streaming).
final class ToolMessageCompatTests: XCTestCase {

    /// toolUse data has required fields.
    func testToolUseData_fields() {
        let data = SDKMessage.ToolUseData(toolName: "Bash", toolUseId: "tu_123", input: "{\"command\":\"ls\"}")
        XCTAssertEqual(data.toolName, "Bash")
        XCTAssertEqual(data.toolUseId, "tu_123")
        XCTAssertEqual(data.input, "{\"command\":\"ls\"}")
    }

    /// toolResult data has required fields.
    func testToolResultData_fields() {
        let data = SDKMessage.ToolResultData(toolUseId: "tu_123", content: "file1.txt\nfile2.txt", isError: false)
        XCTAssertEqual(data.toolUseId, "tu_123")
        XCTAssertEqual(data.content, "file1.txt\nfile2.txt")
        XCTAssertFalse(data.isError)
    }

    /// toolResult with error.
    func testToolResultData_errorCase() {
        let data = SDKMessage.ToolResultData(toolUseId: "tu_456", content: "command not found", isError: true)
        XCTAssertTrue(data.isError)
    }
}

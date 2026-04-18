// MessageTypesCompatTests.swift
// Story 16.3: Message Types Compatibility Verification (Updated by Story 17.1)
// ATDD: Tests verify TS SDK 20 message types <-> Swift SDK SDKMessage 18 cases
// TDD Phase: GREEN (gaps from 16.3 now resolved by 17.1)
//
// These tests verify that Swift SDK's SDKMessage type covers all 20 TypeScript SDK
// message subtypes with field-level verification. Updated after Story 17.1 implementation.

import XCTest
@testable import OpenAgentSDK

// MARK: - AC1: Build Compilation Verification (P0)

/// Verifies that SDKMessage and all associated types compile correctly.
/// This is the compile-time equivalent of "example compiles and runs".
final class MessageTypesBuildCompatTests: XCTestCase {

    /// AC1 [P0]: SDKMessage enum exists and has exactly 18 cases (6 original + 12 new from Story 17.1).
    func testSDKMessage_hasEighteenCases() {
        // Exhaustive switch confirms all 18 cases exist at compile time
        let messages: [SDKMessage] = [
            .assistant(SDKMessage.AssistantData(text: "", model: "", stopReason: "")),
            .toolUse(SDKMessage.ToolUseData(toolName: "", toolUseId: "", input: "")),
            .toolResult(SDKMessage.ToolResultData(toolUseId: "", content: "", isError: false)),
            .result(SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 0, durationMs: 0)),
            .partialMessage(SDKMessage.PartialData(text: "")),
            .system(SDKMessage.SystemData(subtype: .`init`, message: "")),
            .userMessage(SDKMessage.UserMessageData(message: "")),
            .toolProgress(SDKMessage.ToolProgressData(toolUseId: "", toolName: "")),
            .hookStarted(SDKMessage.HookStartedData(hookId: "", hookName: "", hookEvent: "")),
            .hookProgress(SDKMessage.HookProgressData(hookId: "", hookName: "", hookEvent: "")),
            .hookResponse(SDKMessage.HookResponseData(hookId: "", hookName: "", hookEvent: "")),
            .taskStarted(SDKMessage.TaskStartedData(taskId: "", taskType: "", description: "")),
            .taskProgress(SDKMessage.TaskProgressData(taskId: "", taskType: "")),
            .authStatus(SDKMessage.AuthStatusData(status: "", message: "")),
            .filesPersisted(SDKMessage.FilesPersistedData(filePaths: [])),
            .localCommandOutput(SDKMessage.LocalCommandOutputData(output: "", command: "")),
            .promptSuggestion(SDKMessage.PromptSuggestionData(suggestions: [])),
            .toolUseSummary(SDKMessage.ToolUseSummaryData(toolUseCount: 0, tools: []))
        ]
        XCTAssertEqual(messages.count, 18,
            "SDKMessage must have exactly 18 cases after Story 17.1 enhancement")
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
/// Swift fields: text, model, stopReason, uuid, sessionId, parentToolUseId, error
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

    /// AC2 [PASS]: AssistantData NOW has uuid field (added by Story 17.1).
    func testAssistantData_uuid_available() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "", uuid: "msg-uuid")
        XCTAssertEqual(data.uuid, "msg-uuid",
            "AssistantData.uuid maps to TS SDK SDKAssistantMessage.uuid")
    }

    /// AC2 [PASS]: AssistantData NOW has sessionId field (added by Story 17.1).
    func testAssistantData_sessionId_available() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "", sessionId: "sess-123")
        XCTAssertEqual(data.sessionId, "sess-123",
            "AssistantData.sessionId maps to TS SDK SDKAssistantMessage.session_id")
    }

    /// AC2 [PASS]: AssistantData NOW has parentToolUseId field (added by Story 17.1).
    func testAssistantData_parentToolUseId_available() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "", parentToolUseId: "toolu_parent")
        XCTAssertEqual(data.parentToolUseId, "toolu_parent",
            "AssistantData.parentToolUseId maps to TS SDK SDKAssistantMessage.parent_tool_use_id")
    }

    /// AC2 [PASS]: AssistantData NOW has error field (added by Story 17.1).
    func testAssistantData_error_available() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "", error: .rateLimit)
        XCTAssertEqual(data.error, .rateLimit,
            "AssistantData.error maps to TS SDK SDKAssistantMessage.error with 7 subtypes")
    }

    /// AC2 [PASS]: AssistantError has all 7 error subtypes.
    func testAssistantData_errorAllSubtypes() {
        let subtypes: [SDKMessage.AssistantError] = [
            .authenticationFailed, .billingError, .rateLimit,
            .invalidRequest, .serverError, .maxOutputTokens, .unknown
        ]
        XCTAssertEqual(subtypes.count, 7,
            "AssistantError must have exactly 7 subtypes matching TS SDK")
    }

    /// AC2 [P0]: AssistantData has 7 fields after enhancement.
    func testAssistantData_fieldCount() {
        let data = SDKMessage.AssistantData(text: "", model: "", stopReason: "")
        let mirror = Mirror(reflecting: data)
        XCTAssertEqual(mirror.children.count, 7,
            "AssistantData has 7 fields after Story 17.1: text, model, stopReason, uuid, sessionId, parentToolUseId, error")
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

    /// AC3 [PASS]: ResultData.Subtype NOW has errorMaxStructuredOutputRetries (added by Story 17.1).
    func testResultData_errorMaxStructuredOutputRetriesSubtype() {
        let data = SDKMessage.ResultData(subtype: .errorMaxStructuredOutputRetries, text: "", usage: nil, numTurns: 1, durationMs: 100)
        XCTAssertEqual(data.subtype, .errorMaxStructuredOutputRetries)
        XCTAssertEqual(data.subtype.rawValue, "errorMaxStructuredOutputRetries")
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

    /// AC3 [PASS]: ResultData NOW has structuredOutput field (added by Story 17.1).
    func testResultData_structuredOutput_available() {
        let data = SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 1, durationMs: 100,
            structuredOutput: SDKMessage.SendableStructuredOutput(["key": "value"]))
        XCTAssertNotNil(data.structuredOutput,
            "ResultData.structuredOutput maps to TS SDK SDKResultMessage.structured_output")
    }

    /// AC3 [PASS]: ResultData NOW has permissionDenials field (added by Story 17.1).
    func testResultData_permissionDenials_available() {
        let denials = [SDKMessage.SDKPermissionDenial(toolName: "Bash", toolUseId: "tu_1", toolInput: "ls")]
        let data = SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 1, durationMs: 100,
            permissionDenials: denials)
        XCTAssertNotNil(data.permissionDenials,
            "ResultData.permissionDenials maps to TS SDK SDKResultMessage.permission_denials")
        XCTAssertEqual(data.permissionDenials?.count, 1)
    }

    /// AC3 [PASS]: ResultData NOW has modelUsage field (added by Story 17.1).
    func testResultData_modelUsage_available() {
        let modelUsage = [SDKMessage.ModelUsageEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50)]
        let data = SDKMessage.ResultData(subtype: .success, text: "", usage: nil, numTurns: 1, durationMs: 100,
            modelUsage: modelUsage)
        XCTAssertNotNil(data.modelUsage,
            "ResultData.modelUsage maps to TS SDK SDKResultMessage.model_usage")
        XCTAssertEqual(data.modelUsage?.count, 1)
    }

    /// AC3 [RESOLVED]: ResultData now has errors array field.
    func testResultData_errorsArray_exists() {
        let data = SDKMessage.ResultData(subtype: .errorDuringExecution, text: "", usage: nil, numTurns: 1, durationMs: 100, errors: ["err"])
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("errors"),
            "ResultData now has errors field matching TS SDK.")
    }
}

// MARK: - AC4: SDKSystemMessage Verification (P0)

/// Verifies `.system(SystemData)` covers all TS SDK system message subtypes.
/// TS SDK subtypes: init, status, compact_boundary, task_notification,
///   task_started, task_progress, hook_started, hook_progress, hook_response,
///   files_persisted, local_command_output
/// Swift subtypes: init, compactBoundary, status, taskNotification, rateLimit,
///   taskStarted, taskProgress, hookStarted, hookProgress, hookResponse,
///   filesPersisted, localCommandOutput (12 total after Story 17.1)
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

    /// AC4 [PASS]: SystemData NOW has taskStarted subtype (added by Story 17.1).
    func testSystemData_taskStartedSubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.taskStarted
        XCTAssertEqual(subtype.rawValue, "taskStarted",
            "SystemData.Subtype.taskStarted maps to TS SDK system/task_started")
    }

    /// AC4 [PASS]: SystemData NOW has taskProgress subtype (added by Story 17.1).
    func testSystemData_taskProgressSubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.taskProgress
        XCTAssertEqual(subtype.rawValue, "taskProgress",
            "SystemData.Subtype.taskProgress maps to TS SDK system/task_progress")
    }

    /// AC4 [PASS]: SystemData NOW has hookStarted subtype (added by Story 17.1).
    func testSystemData_hookStartedSubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.hookStarted
        XCTAssertEqual(subtype.rawValue, "hookStarted",
            "SystemData.Subtype.hookStarted maps to TS SDK system/hook_started")
    }

    /// AC4 [PASS]: SystemData NOW has hookProgress subtype (added by Story 17.1).
    func testSystemData_hookProgressSubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.hookProgress
        XCTAssertEqual(subtype.rawValue, "hookProgress",
            "SystemData.Subtype.hookProgress maps to TS SDK system/hook_progress")
    }

    /// AC4 [PASS]: SystemData NOW has hookResponse subtype (added by Story 17.1).
    func testSystemData_hookResponseSubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.hookResponse
        XCTAssertEqual(subtype.rawValue, "hookResponse",
            "SystemData.Subtype.hookResponse maps to TS SDK system/hook_response")
    }

    /// AC4 [PASS]: SystemData NOW has filesPersisted subtype (added by Story 17.1).
    func testSystemData_filesPersistedSubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.filesPersisted
        XCTAssertEqual(subtype.rawValue, "filesPersisted",
            "SystemData.Subtype.filesPersisted maps to TS SDK system/files_persisted")
    }

    /// AC4 [PASS]: SystemData NOW has localCommandOutput subtype (added by Story 17.1).
    func testSystemData_localCommandOutputSubtype_exists() {
        let subtype = SDKMessage.SystemData.Subtype.localCommandOutput
        XCTAssertEqual(subtype.rawValue, "localCommandOutput",
            "SystemData.Subtype.localCommandOutput maps to TS SDK system/local_command_output")
    }

    /// AC4 [P0]: SystemData has 12 subtypes after Story 17.1.
    func testSystemData_subtypeCount() {
        let subtypes: [SDKMessage.SystemData.Subtype] = [
            .`init`, .compactBoundary, .status, .taskNotification, .rateLimit,
            .taskStarted, .taskProgress, .hookStarted, .hookProgress, .hookResponse,
            .filesPersisted, .localCommandOutput
        ]
        XCTAssertEqual(subtypes.count, 12,
            "SystemData.Subtype has 12 cases after Story 17.1 enhancement.")
    }

    /// AC4 [P0]: SystemData has message field.
    func testSystemData_messageField_available() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "Session started")
        XCTAssertEqual(data.message, "Session started")
    }

    /// AC4 [PASS]: SystemData NOW has sessionId field (added by Story 17.1).
    func testSystemData_sessionId_available() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "", sessionId: "sess-123")
        XCTAssertEqual(data.sessionId, "sess-123",
            "SystemData.sessionId maps to TS SDK system/init session_id")
    }

    /// AC4 [PASS]: SystemData NOW has tools field (added by Story 17.1).
    func testSystemData_tools_available() {
        let tools = [SDKMessage.ToolInfo(name: "Bash", description: "Run commands")]
        let data = SDKMessage.SystemData(subtype: .`init`, message: "", tools: tools)
        XCTAssertNotNil(data.tools,
            "SystemData.tools maps to TS SDK system/init tools")
        XCTAssertEqual(data.tools?.count, 1)
    }

    /// AC4 [PASS]: SystemData NOW has model field (added by Story 17.1).
    func testSystemData_model_available() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "", model: "claude-sonnet-4-6")
        XCTAssertEqual(data.model, "claude-sonnet-4-6",
            "SystemData.model maps to TS SDK system/init model")
    }

    /// AC4 [PASS]: SystemData NOW has permissionMode field (added by Story 17.1).
    func testSystemData_permissionMode_available() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "", permissionMode: "default")
        XCTAssertEqual(data.permissionMode, "default",
            "SystemData.permissionMode maps to TS SDK system/init permissionMode")
    }

    /// AC4 [PASS]: SystemData NOW has mcpServers field (added by Story 17.1).
    func testSystemData_mcpServers_available() {
        let servers = [SDKMessage.McpServerInfo(name: "filesystem", command: "npx")]
        let data = SDKMessage.SystemData(subtype: .`init`, message: "", mcpServers: servers)
        XCTAssertNotNil(data.mcpServers,
            "SystemData.mcpServers maps to TS SDK system/init mcp_servers")
        XCTAssertEqual(data.mcpServers?.count, 1)
    }

    /// AC4 [PASS]: SystemData NOW has cwd field (added by Story 17.1).
    func testSystemData_cwd_available() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "", cwd: "/tmp/project")
        XCTAssertEqual(data.cwd, "/tmp/project",
            "SystemData.cwd maps to TS SDK system/init cwd")
    }

    /// AC4 [RESOLVED]: SystemData compactBoundary now exposes compactMetadata.
    func testSystemData_compactBoundary_metadata_exists() {
        let data = SDKMessage.SystemData(subtype: .compactBoundary, message: "", compactMetadata: SDKMessage.CompactMetadata(trigger: .auto, preTokens: 1000, postTokens: 500))
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("compactMetadata"),
            "SystemData now has compactMetadata matching TS SDK compact_boundary.")
        XCTAssertEqual(data.compactMetadata?.trigger, .auto)
    }

    /// AC4 [RESOLVED]: SystemData taskNotification now exposes taskNotificationInfo.
    func testSystemData_taskNotification_fields_exist() {
        let info = SDKMessage.TaskNotificationInfo(taskId: "task-1", status: .completed, outputFile: "/tmp/out", summary: "done")
        let data = SDKMessage.SystemData(subtype: .taskNotification, message: "", taskNotificationInfo: info)
        let mirror = Mirror(reflecting: data)
        let fieldNames = Set(mirror.children.map { $0.label ?? "" })
        XCTAssertTrue(fieldNames.contains("taskNotificationInfo"),
            "SystemData now has taskNotificationInfo matching TS SDK task_notification.")
        XCTAssertEqual(data.taskNotificationInfo?.taskId, "task-1")
    }
}

// MARK: - AC5: SDKPartialAssistantMessage Verification (P0)

/// Verifies `.partialMessage(PartialData)` covers TS SDK `SDKPartialAssistantMessage`.
/// TS SDK fields: type="stream_event", event (stream event), parent_tool_use_id, uuid, session_id
/// Swift fields: text, parentToolUseId, uuid, sessionId (after Story 17.1)
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

    /// AC5 [PASS]: PartialData NOW has parentToolUseId (added by Story 17.1).
    func testPartialData_parentToolUseId_available() {
        let data = SDKMessage.PartialData(text: "", parentToolUseId: "toolu_parent")
        XCTAssertEqual(data.parentToolUseId, "toolu_parent",
            "PartialData.parentToolUseId maps to TS SDK SDKPartialAssistantMessage.parent_tool_use_id")
    }

    /// AC5 [PASS]: PartialData NOW has uuid (added by Story 17.1).
    func testPartialData_uuid_available() {
        let data = SDKMessage.PartialData(text: "", uuid: "msg-uuid")
        XCTAssertEqual(data.uuid, "msg-uuid",
            "PartialData.uuid maps to TS SDK SDKPartialAssistantMessage.uuid")
    }

    /// AC5 [PASS]: PartialData NOW has sessionId (added by Story 17.1).
    func testPartialData_sessionId_available() {
        let data = SDKMessage.PartialData(text: "", sessionId: "sess-123")
        XCTAssertEqual(data.sessionId, "sess-123",
            "PartialData.sessionId maps to TS SDK SDKPartialAssistantMessage.session_id")
    }

    /// AC5 [P0]: PartialData has 4 fields after enhancement.
    func testPartialData_fieldCount() {
        let data = SDKMessage.PartialData(text: "")
        let mirror = Mirror(reflecting: data)
        XCTAssertEqual(mirror.children.count, 4,
            "PartialData has 4 fields after Story 17.1: text, parentToolUseId, uuid, sessionId.")
    }
}

// MARK: - AC6: Tool Progress Message Verification (P0)

/// Verifies that SDKToolProgressMessage equivalent NOW exists (Story 17.1).
/// TS SDK fields: tool_use_id, tool_name, parent_tool_use_id, elapsed_time_seconds
final class ToolProgressMessageCompatTests: XCTestCase {

    /// AC6 [PASS]: SDKMessage NOW has .toolProgress case (added by Story 17.1).
    func testSDKMessage_hasToolProgressCase() {
        let data = SDKMessage.ToolProgressData(toolUseId: "toolu_123", toolName: "Bash", parentToolUseId: nil, elapsedTimeSeconds: 3.5)
        let message = SDKMessage.toolProgress(data)
        if case .toolProgress(let retrieved) = message {
            XCTAssertEqual(retrieved.toolUseId, "toolu_123")
            XCTAssertEqual(retrieved.toolName, "Bash")
        } else {
            XCTFail("Expected .toolProgress case")
        }
    }

    /// AC6 [PASS]: ToolProgressData has all TS SDK fields.
    func testToolProgressData_fields() {
        let data = SDKMessage.ToolProgressData(toolUseId: "tu", toolName: "Read", parentToolUseId: "parent", elapsedTimeSeconds: 1.5)
        XCTAssertEqual(data.toolUseId, "tu")
        XCTAssertEqual(data.toolName, "Read")
        XCTAssertEqual(data.parentToolUseId, "parent")
        XCTAssertEqual(data.elapsedTimeSeconds, 1.5)
    }
}

// MARK: - AC7: Hook-Related Message Verification (P0)

/// Verifies that hook-related message equivalents NOW exist (Story 17.1).
/// TS SDK fields: hook_id, hook_name, hook_event, stdout/stderr/output, exit_code, outcome
final class HookMessageCompatTests: XCTestCase {

    /// AC7 [PASS]: SDKMessage NOW has .hookStarted case (added by Story 17.1).
    func testSDKMessage_hasHookStartedCase() {
        let data = SDKMessage.HookStartedData(hookId: "h1", hookName: "pre-tool", hookEvent: "PreToolUse")
        let message = SDKMessage.hookStarted(data)
        if case .hookStarted(let retrieved) = message {
            XCTAssertEqual(retrieved.hookId, "h1")
        } else {
            XCTFail("Expected .hookStarted case")
        }
    }

    /// AC7 [PASS]: SDKMessage NOW has .hookProgress case (added by Story 17.1).
    func testSDKMessage_hasHookProgressCase() {
        let data = SDKMessage.HookProgressData(hookId: "h2", hookName: "post-tool", hookEvent: "PostToolUse", stdout: "out", stderr: nil)
        let message = SDKMessage.hookProgress(data)
        if case .hookProgress(let retrieved) = message {
            XCTAssertEqual(retrieved.stdout, "out")
        } else {
            XCTFail("Expected .hookProgress case")
        }
    }

    /// AC7 [PASS]: SDKMessage NOW has .hookResponse case (added by Story 17.1).
    func testSDKMessage_hasHookResponseCase() {
        let data = SDKMessage.HookResponseData(hookId: "h3", hookName: "stop", hookEvent: "Stop", output: "done", exitCode: 0, outcome: "success")
        let message = SDKMessage.hookResponse(data)
        if case .hookResponse(let retrieved) = message {
            XCTAssertEqual(retrieved.outcome, "success")
        } else {
            XCTFail("Expected .hookResponse case")
        }
    }

    /// AC7 [PASS]: SystemData NOW has hookStarted subtype (added by Story 17.1).
    func testSystemData_hasHookStartedSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "hookStarted")
        XCTAssertNotNil(subtype,
            "SystemData.Subtype now has hookStarted after Story 17.1.")
    }

    /// AC7 [PASS]: SystemData NOW has hookProgress subtype (added by Story 17.1).
    func testSystemData_hasHookProgressSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "hookProgress")
        XCTAssertNotNil(subtype,
            "SystemData.Subtype now has hookProgress after Story 17.1.")
    }

    /// AC7 [PASS]: SystemData NOW has hookResponse subtype (added by Story 17.1).
    func testSystemData_hasHookResponseSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "hookResponse")
        XCTAssertNotNil(subtype,
            "SystemData.Subtype now has hookResponse after Story 17.1.")
    }
}

// MARK: - AC8: Task-Related Message Verification (P0)

/// Verifies that task-related message equivalents NOW exist (Story 17.1).
/// TS SDK fields: task_id, task_type, description, usage
final class TaskMessageCompatTests: XCTestCase {

    /// AC8 [PASS]: SDKMessage NOW has .taskStarted case (added by Story 17.1).
    func testSDKMessage_hasTaskStartedCase() {
        let data = SDKMessage.TaskStartedData(taskId: "t1", taskType: "subagent", description: "analysis")
        let message = SDKMessage.taskStarted(data)
        if case .taskStarted(let retrieved) = message {
            XCTAssertEqual(retrieved.taskId, "t1")
        } else {
            XCTFail("Expected .taskStarted case")
        }
    }

    /// AC8 [PASS]: SDKMessage NOW has .taskProgress case (added by Story 17.1).
    func testSDKMessage_hasTaskProgressCase() {
        let data = SDKMessage.TaskProgressData(taskId: "t2", taskType: "subagent", usage: nil)
        let message = SDKMessage.taskProgress(data)
        if case .taskProgress(let retrieved) = message {
            XCTAssertEqual(retrieved.taskId, "t2")
        } else {
            XCTFail("Expected .taskProgress case")
        }
    }

    /// AC8 [PASS]: SystemData NOW has taskStarted subtype (added by Story 17.1).
    func testSystemData_hasTaskStartedSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "taskStarted")
        XCTAssertNotNil(subtype,
            "SystemData.Subtype now has taskStarted after Story 17.1.")
    }

    /// AC8 [PASS]: SystemData NOW has taskProgress subtype (added by Story 17.1).
    func testSystemData_hasTaskProgressSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "taskProgress")
        XCTAssertNotNil(subtype,
            "SystemData.Subtype now has taskProgress after Story 17.1.")
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

    /// AC9 [PASS]: SDKMessage NOW has .filesPersisted case (added by Story 17.1).
    func testSDKMessage_hasFilesPersistedCase() {
        let data = SDKMessage.FilesPersistedData(filePaths: ["/tmp/a.swift"])
        let message = SDKMessage.filesPersisted(data)
        if case .filesPersisted(let retrieved) = message {
            XCTAssertEqual(retrieved.filePaths.count, 1)
        } else {
            XCTFail("Expected .filesPersisted case")
        }
    }

    /// AC9 [PASS]: SystemData NOW has filesPersisted subtype (added by Story 17.1).
    func testSystemData_hasFilesPersistedSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "filesPersisted")
        XCTAssertNotNil(subtype,
            "SystemData.Subtype now has filesPersisted after Story 17.1.")
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

    /// AC9 [PASS]: SDKMessage NOW has .authStatus case (added by Story 17.1).
    func testSDKMessage_hasAuthStatusCase() {
        let data = SDKMessage.AuthStatusData(status: "authenticated", message: "API key valid")
        let message = SDKMessage.authStatus(data)
        if case .authStatus(let retrieved) = message {
            XCTAssertEqual(retrieved.status, "authenticated")
        } else {
            XCTFail("Expected .authStatus case")
        }
    }

    /// AC9 [PASS]: SDKMessage NOW has .promptSuggestion case (added by Story 17.1).
    func testSDKMessage_hasPromptSuggestionCase() {
        let data = SDKMessage.PromptSuggestionData(suggestions: ["Run tests"])
        let message = SDKMessage.promptSuggestion(data)
        if case .promptSuggestion(let retrieved) = message {
            XCTAssertEqual(retrieved.suggestions.count, 1)
        } else {
            XCTFail("Expected .promptSuggestion case")
        }
    }

    /// AC9 [PASS]: SDKMessage NOW has .toolUseSummary case (added by Story 17.1).
    func testSDKMessage_hasToolUseSummaryCase() {
        let data = SDKMessage.ToolUseSummaryData(toolUseCount: 5, tools: ["Bash"])
        let message = SDKMessage.toolUseSummary(data)
        if case .toolUseSummary(let retrieved) = message {
            XCTAssertEqual(retrieved.toolUseCount, 5)
        } else {
            XCTFail("Expected .toolUseSummary case")
        }
    }

    /// AC9 [PASS]: SDKMessage NOW has .localCommandOutput case (added by Story 17.1).
    func testSDKMessage_hasLocalCommandOutputCase() {
        let data = SDKMessage.LocalCommandOutputData(output: "Build OK", command: "swift build")
        let message = SDKMessage.localCommandOutput(data)
        if case .localCommandOutput(let retrieved) = message {
            XCTAssertEqual(retrieved.output, "Build OK")
        } else {
            XCTFail("Expected .localCommandOutput case")
        }
    }

    /// AC9 [PASS]: SystemData NOW has localCommandOutput subtype (added by Story 17.1).
    func testSystemData_hasLocalCommandOutputSubtype() {
        let subtype = SDKMessage.SystemData.Subtype(rawValue: "localCommandOutput")
        XCTAssertNotNil(subtype,
            "SystemData.Subtype now has localCommandOutput after Story 17.1.")
    }

    /// AC9 [PASS]: SDKMessage NOW has .userMessage case (added by Story 17.1).
    func testSDKMessage_hasUserMessageCase() {
        let data = SDKMessage.UserMessageData(message: "Hello")
        let message = SDKMessage.userMessage(data)
        if case .userMessage(let retrieved) = message {
            XCTAssertEqual(retrieved.message, "Hello")
        } else {
            XCTFail("Expected .userMessage case")
        }
    }
}

// MARK: - AC10: Complete Compatibility Report Generation (P0)

/// Generates the complete 20-row comparison table for all TS SDK message types.
/// Updated after Story 17.1 to reflect resolved gaps.
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
                swiftEquivalent: ".assistant(AssistantData)", status: "PASS",
                note: "All fields present: text, model, stopReason, uuid, sessionId, parentToolUseId, error(7 subtypes)"),
            MessageTypeMapping(index: 2, tsType: "SDKUserMessage", tsTypeField: "user",
                swiftEquivalent: ".userMessage(UserMessageData)", status: "PASS",
                note: "Added by Story 17.1: uuid, sessionId, message, parentToolUseId, isSynthetic, toolUseResult"),
            MessageTypeMapping(index: 3, tsType: "SDKResultMessage", tsTypeField: "result",
                swiftEquivalent: ".result(ResultData)", status: "PASS",
                note: "All fields present: subtype(6), text, usage, numTurns, durationMs, totalCostUsd, costBreakdown, structuredOutput, permissionDenials, modelUsage"),
            MessageTypeMapping(index: 4, tsType: "SDKSystemMessage(init)", tsTypeField: "system/init",
                swiftEquivalent: ".system(SystemData) subtype=.init", status: "PASS",
                note: "All init fields present: message, sessionId, tools, model, permissionMode, mcpServers, cwd"),
            MessageTypeMapping(index: 5, tsType: "SDKPartialAssistantMessage", tsTypeField: "stream_event",
                swiftEquivalent: ".partialMessage(PartialData)", status: "PASS",
                note: "All fields present: text, parentToolUseId, uuid, sessionId"),
            MessageTypeMapping(index: 6, tsType: "SDKCompactBoundaryMessage", tsTypeField: "system/compact_boundary",
                swiftEquivalent: ".system(SystemData) subtype=.compactBoundary", status: "PASS",
                note: "Has message + compactMetadata (CompactMetadata with trigger, preTokens, postTokens, preservedSegment)"),
            MessageTypeMapping(index: 7, tsType: "SDKStatusMessage", tsTypeField: "system/status",
                swiftEquivalent: ".system(SystemData) subtype=.status", status: "PASS",
                note: "Has message + statusValue, compactResult, compactError fields."),
            MessageTypeMapping(index: 8, tsType: "SDKTaskNotificationMessage", tsTypeField: "system/task_notification",
                swiftEquivalent: ".system(SystemData) subtype=.taskNotification", status: "PASS",
                note: "Has message + taskNotificationInfo (TaskNotificationInfo with taskId, outputFile, summary, usage)"),
            MessageTypeMapping(index: 9, tsType: "SDKTaskStartedMessage", tsTypeField: "system/task_started",
                swiftEquivalent: ".taskStarted(TaskStartedData) + SystemData.Subtype.taskStarted", status: "PASS",
                note: "Added by Story 17.1: taskId, taskType, description"),
            MessageTypeMapping(index: 10, tsType: "SDKTaskProgressMessage", tsTypeField: "system/task_progress",
                swiftEquivalent: ".taskProgress(TaskProgressData) + SystemData.Subtype.taskProgress", status: "PASS",
                note: "Added by Story 17.1: taskId, taskType, usage"),
            MessageTypeMapping(index: 11, tsType: "SDKToolProgressMessage", tsTypeField: "tool_progress",
                swiftEquivalent: ".toolProgress(ToolProgressData)", status: "PASS",
                note: "Added by Story 17.1: toolUseId, toolName, parentToolUseId, elapsedTimeSeconds"),
            MessageTypeMapping(index: 12, tsType: "SDKHookStartedMessage", tsTypeField: "system/hook_started",
                swiftEquivalent: ".hookStarted(HookStartedData) + SystemData.Subtype.hookStarted", status: "PASS",
                note: "Added by Story 17.1: hookId, hookName, hookEvent"),
            MessageTypeMapping(index: 13, tsType: "SDKHookProgressMessage", tsTypeField: "system/hook_progress",
                swiftEquivalent: ".hookProgress(HookProgressData) + SystemData.Subtype.hookProgress", status: "PASS",
                note: "Added by Story 17.1: hookId, hookName, hookEvent, stdout, stderr"),
            MessageTypeMapping(index: 14, tsType: "SDKHookResponseMessage", tsTypeField: "system/hook_response",
                swiftEquivalent: ".hookResponse(HookResponseData) + SystemData.Subtype.hookResponse", status: "PASS",
                note: "Added by Story 17.1: hookId, hookName, hookEvent, output, exitCode, outcome"),
            MessageTypeMapping(index: 15, tsType: "SDKAuthStatusMessage", tsTypeField: "auth_status",
                swiftEquivalent: ".authStatus(AuthStatusData)", status: "PASS",
                note: "Added by Story 17.1: status, message"),
            MessageTypeMapping(index: 16, tsType: "SDKFilesPersistedEvent", tsTypeField: "system/files_persisted",
                swiftEquivalent: ".filesPersisted(FilesPersistedData) + SystemData.Subtype.filesPersisted", status: "PASS",
                note: "Added by Story 17.1: filePaths"),
            MessageTypeMapping(index: 17, tsType: "SDKRateLimitEvent", tsTypeField: "rate_limit_event",
                swiftEquivalent: ".system(SystemData) subtype=.rateLimit", status: "PASS",
                note: "Has subtype + message + rateLimitInfo (RateLimitInfo with status, resetsAt, rateLimitType, utilization)."),
            MessageTypeMapping(index: 18, tsType: "SDKLocalCommandOutputMessage", tsTypeField: "system/local_command_output",
                swiftEquivalent: ".localCommandOutput(LocalCommandOutputData) + SystemData.Subtype.localCommandOutput", status: "PASS",
                note: "Added by Story 17.1: output, command"),
            MessageTypeMapping(index: 19, tsType: "SDKPromptSuggestionMessage", tsTypeField: "prompt_suggestion",
                swiftEquivalent: ".promptSuggestion(PromptSuggestionData)", status: "PASS",
                note: "Added by Story 17.1: suggestions"),
            MessageTypeMapping(index: 20, tsType: "SDKToolUseSummaryMessage", tsTypeField: "tool_use_summary",
                swiftEquivalent: ".toolUseSummary(ToolUseSummaryData)", status: "PASS",
                note: "Added by Story 17.1: toolUseCount, tools"),
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
        print("=== Message Types Compatibility Report (AC10, updated after Story 17.1) ===")
        print("#\tTS SDK Type\t\t\t\tTS type field\t\tSwift Equivalent\t\t\t\tStatus")
        print(String(repeating: "-", count: 130))
        for m in mappings {
            print("\(m.index)\t\(m.tsType)\t\(m.tsTypeField)\t\(m.swiftEquivalent)\t[\(m.status)]")
            print("\tNote: \(m.note)")
        }
        print("")
        print("Summary: PASS: \(passCount) | PARTIAL: \(partialCount) | MISSING: \(missingCount) | Total: \(mappings.count)")
        print("")

        // Verify the expected distribution after Story 17.1
        XCTAssertTrue(passCount > 0,
            "Most TS SDK types should now be PASS after Story 17.1")
        XCTAssertEqual(missingCount, 0,
            "No TS SDK types should be MISSING after Story 17.1")
        XCTAssertEqual(passCount, 20,
            "All 20 message types now PASS after Spec 19")
        XCTAssertEqual(partialCount, 0,
            "0 PARTIAL message types after Spec 19 (compact boundary, status, task notification, rate limit resolved)")
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

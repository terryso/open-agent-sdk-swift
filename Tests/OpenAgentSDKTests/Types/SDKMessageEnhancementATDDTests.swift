// SDKMessageEnhancementATDDTests.swift
// Story 17.1: SDKMessage Type Enhancement — ATDD (TDD Red Phase)
//
// These tests verify the EXPECTED behavior after implementation of:
// - 12 new SDKMessage cases (AC1)
// - AssistantData field completion (AC2)
// - ResultData field completion (AC3)
// - SystemData init field completion (AC4)
// - PartialData field completion (AC5)
// - Sendable conformance (AC6)
// - AsyncStream integration (AC8)
//
// TDD Phase: RED — All tests will FAIL until the feature is implemented.
// After implementation, these tests should pass (GREEN phase).

import XCTest
@testable import OpenAgentSDK

// MARK: - AC1: 12 New SDKMessage Cases

/// Tests for the 12 new SDKMessage cases that map to TS SDK message types.
/// Each new case should have its own associated data struct with all TS SDK fields.
final class SDKMessageNewCasesATDDTests: XCTestCase {

    // MARK: - AC1.1: UserMessageData

    /// AC1 [P0]: .userMessage case exists and UserMessageData can be constructed with all fields.
    func testUserMessage_caseConstruction() {
        let data = SDKMessage.UserMessageData(
            uuid: "msg-uuid-001",
            sessionId: "session-001",
            message: "Hello, agent!",
            parentToolUseId: "toolu-parent-001",
            isSynthetic: false,
            toolUseResult: nil
        )
        let message = SDKMessage.userMessage(data)

        if case let .userMessage(retrieved) = message {
            XCTAssertEqual(retrieved.uuid, "msg-uuid-001")
            XCTAssertEqual(retrieved.sessionId, "session-001")
            XCTAssertEqual(retrieved.message, "Hello, agent!")
            XCTAssertEqual(retrieved.parentToolUseId, "toolu-parent-001")
            XCTAssertEqual(retrieved.isSynthetic, false)
            XCTAssertNil(retrieved.toolUseResult)
        } else {
            XCTFail("Expected .userMessage case")
        }
    }

    /// AC1 [P0]: UserMessageData supports optional fields as nil.
    func testUserMessage_optionalFieldsNil() {
        let data = SDKMessage.UserMessageData(
            uuid: nil,
            sessionId: nil,
            message: "Hi",
            parentToolUseId: nil,
            isSynthetic: nil,
            toolUseResult: nil
        )
        XCTAssertNil(data.uuid)
        XCTAssertNil(data.sessionId)
        XCTAssertNil(data.parentToolUseId)
        XCTAssertNil(data.isSynthetic)
        XCTAssertNil(data.toolUseResult)
    }

    // MARK: - AC1.2: ToolProgressData

    /// AC1 [P0]: .toolProgress case exists with tool_use_id, tool_name, parent_tool_use_id, elapsed_time_seconds.
    func testToolProgress_caseConstruction() {
        let data = SDKMessage.ToolProgressData(
            toolUseId: "toolu_123",
            toolName: "Bash",
            parentToolUseId: "toolu_parent",
            elapsedTimeSeconds: 3.5
        )
        let message = SDKMessage.toolProgress(data)

        if case let .toolProgress(retrieved) = message {
            XCTAssertEqual(retrieved.toolUseId, "toolu_123")
            XCTAssertEqual(retrieved.toolName, "Bash")
            XCTAssertEqual(retrieved.parentToolUseId, "toolu_parent")
            XCTAssertEqual(retrieved.elapsedTimeSeconds, 3.5)
        } else {
            XCTFail("Expected .toolProgress case")
        }
    }

    /// AC1 [P1]: ToolProgressData optional parentToolUseId can be nil.
    func testToolProgress_optionalParentNil() {
        let data = SDKMessage.ToolProgressData(
            toolUseId: "toolu_456",
            toolName: "Read",
            parentToolUseId: nil,
            elapsedTimeSeconds: nil
        )
        XCTAssertNil(data.parentToolUseId)
        XCTAssertNil(data.elapsedTimeSeconds)
    }

    // MARK: - AC1.3: HookStartedData

    /// AC1 [P0]: .hookStarted case with hook_id, hook_name, hook_event.
    func testHookStarted_caseConstruction() {
        let data = SDKMessage.HookStartedData(
            hookId: "hook-001",
            hookName: "pre-tool-use",
            hookEvent: "PreToolUse"
        )
        let message = SDKMessage.hookStarted(data)

        if case let .hookStarted(retrieved) = message {
            XCTAssertEqual(retrieved.hookId, "hook-001")
            XCTAssertEqual(retrieved.hookName, "pre-tool-use")
            XCTAssertEqual(retrieved.hookEvent, "PreToolUse")
        } else {
            XCTFail("Expected .hookStarted case")
        }
    }

    // MARK: - AC1.4: HookProgressData

    /// AC1 [P0]: .hookProgress case with stdout and stderr.
    func testHookProgress_caseConstruction() {
        let data = SDKMessage.HookProgressData(
            hookId: "hook-002",
            hookName: "post-tool-use",
            hookEvent: "PostToolUse",
            stdout: "progress output",
            stderr: nil
        )
        let message = SDKMessage.hookProgress(data)

        if case let .hookProgress(retrieved) = message {
            XCTAssertEqual(retrieved.hookId, "hook-002")
            XCTAssertEqual(retrieved.stdout, "progress output")
            XCTAssertNil(retrieved.stderr)
        } else {
            XCTFail("Expected .hookProgress case")
        }
    }

    // MARK: - AC1.5: HookResponseData

    /// AC1 [P0]: .hookResponse case with output, exitCode, outcome.
    func testHookResponse_caseConstruction() {
        let data = SDKMessage.HookResponseData(
            hookId: "hook-003",
            hookName: "stop-hook",
            hookEvent: "Stop",
            output: "hook completed",
            exitCode: 0,
            outcome: "success"
        )
        let message = SDKMessage.hookResponse(data)

        if case let .hookResponse(retrieved) = message {
            XCTAssertEqual(retrieved.hookId, "hook-003")
            XCTAssertEqual(retrieved.output, "hook completed")
            XCTAssertEqual(retrieved.exitCode, 0)
            XCTAssertEqual(retrieved.outcome, "success")
        } else {
            XCTFail("Expected .hookResponse case")
        }
    }

    // MARK: - AC1.6: TaskStartedData

    /// AC1 [P0]: .taskStarted case with taskId, taskType, description.
    func testTaskStarted_caseConstruction() {
        let data = SDKMessage.TaskStartedData(
            taskId: "task-001",
            taskType: "subagent",
            description: "Running analysis"
        )
        let message = SDKMessage.taskStarted(data)

        if case let .taskStarted(retrieved) = message {
            XCTAssertEqual(retrieved.taskId, "task-001")
            XCTAssertEqual(retrieved.taskType, "subagent")
            XCTAssertEqual(retrieved.description, "Running analysis")
        } else {
            XCTFail("Expected .taskStarted case")
        }
    }

    // MARK: - AC1.7: TaskProgressData

    /// AC1 [P0]: .taskProgress case with taskId, taskType, usage.
    func testTaskProgress_caseConstruction() {
        let usage = TokenUsage(inputTokens: 500, outputTokens: 200)
        let data = SDKMessage.TaskProgressData(
            taskId: "task-002",
            taskType: "subagent",
            usage: usage
        )
        let message = SDKMessage.taskProgress(data)

        if case let .taskProgress(retrieved) = message {
            XCTAssertEqual(retrieved.taskId, "task-002")
            XCTAssertEqual(retrieved.usage?.inputTokens, 500)
            XCTAssertEqual(retrieved.usage?.outputTokens, 200)
        } else {
            XCTFail("Expected .taskProgress case")
        }
    }

    // MARK: - AC1.8: AuthStatusData

    /// AC1 [P0]: .authStatus case with status and message.
    func testAuthStatus_caseConstruction() {
        let data = SDKMessage.AuthStatusData(
            status: "authenticated",
            message: "API key valid"
        )
        let message = SDKMessage.authStatus(data)

        if case let .authStatus(retrieved) = message {
            XCTAssertEqual(retrieved.status, "authenticated")
            XCTAssertEqual(retrieved.message, "API key valid")
        } else {
            XCTFail("Expected .authStatus case")
        }
    }

    // MARK: - AC1.9: FilesPersistedData

    /// AC1 [P0]: .filesPersisted case with filePaths array.
    func testFilesPersisted_caseConstruction() {
        let data = SDKMessage.FilesPersistedData(
            filePaths: ["/tmp/file1.swift", "/tmp/file2.swift"]
        )
        let message = SDKMessage.filesPersisted(data)

        if case let .filesPersisted(retrieved) = message {
            XCTAssertEqual(retrieved.filePaths.count, 2)
            XCTAssertEqual(retrieved.filePaths[0], "/tmp/file1.swift")
        } else {
            XCTFail("Expected .filesPersisted case")
        }
    }

    // MARK: - AC1.10: LocalCommandOutputData

    /// AC1 [P0]: .localCommandOutput case with output and command.
    func testLocalCommandOutput_caseConstruction() {
        let data = SDKMessage.LocalCommandOutputData(
            output: "Build succeeded",
            command: "swift build"
        )
        let message = SDKMessage.localCommandOutput(data)

        if case let .localCommandOutput(retrieved) = message {
            XCTAssertEqual(retrieved.output, "Build succeeded")
            XCTAssertEqual(retrieved.command, "swift build")
        } else {
            XCTFail("Expected .localCommandOutput case")
        }
    }

    // MARK: - AC1.11: PromptSuggestionData

    /// AC1 [P0]: .promptSuggestion case with suggestions array.
    func testPromptSuggestion_caseConstruction() {
        let data = SDKMessage.PromptSuggestionData(
            suggestions: ["What files changed?", "Run the tests"]
        )
        let message = SDKMessage.promptSuggestion(data)

        if case let .promptSuggestion(retrieved) = message {
            XCTAssertEqual(retrieved.suggestions.count, 2)
            XCTAssertEqual(retrieved.suggestions[0], "What files changed?")
        } else {
            XCTFail("Expected .promptSuggestion case")
        }
    }

    // MARK: - AC1.12: ToolUseSummaryData

    /// AC1 [P0]: .toolUseSummary case with toolUseCount and tools array.
    func testToolUseSummary_caseConstruction() {
        let data = SDKMessage.ToolUseSummaryData(
            toolUseCount: 5,
            tools: ["Bash", "Read", "Write"]
        )
        let message = SDKMessage.toolUseSummary(data)

        if case let .toolUseSummary(retrieved) = message {
            XCTAssertEqual(retrieved.toolUseCount, 5)
            XCTAssertEqual(retrieved.tools.count, 3)
            XCTAssertTrue(retrieved.tools.contains("Bash"))
        } else {
            XCTFail("Expected .toolUseSummary case")
        }
    }

    // MARK: - AC1: Exhaustive Switch with All 18 Cases

    /// AC1 [P0]: SDKMessage has exactly 18 cases (6 original + 12 new).
    func testSDKMessage_has18Cases_exhaustiveSwitch() {
        let messages: [SDKMessage] = [
            .assistant(SDKMessage.AssistantData(text: "a", model: "m", stopReason: "s")),
            .toolUse(SDKMessage.ToolUseData(toolName: "t", toolUseId: "id", input: "{}")),
            .toolResult(SDKMessage.ToolResultData(toolUseId: "id", content: "c", isError: false)),
            .result(SDKMessage.ResultData(subtype: .success, text: "r", usage: nil, numTurns: 1, durationMs: 100)),
            .partialMessage(SDKMessage.PartialData(text: "p")),
            .system(SDKMessage.SystemData(subtype: .`init`, message: "sys")),
            .userMessage(SDKMessage.UserMessageData(uuid: nil, sessionId: nil, message: "u", parentToolUseId: nil, isSynthetic: nil, toolUseResult: nil)),
            .toolProgress(SDKMessage.ToolProgressData(toolUseId: "tp", toolName: "n", parentToolUseId: nil, elapsedTimeSeconds: nil)),
            .hookStarted(SDKMessage.HookStartedData(hookId: "h", hookName: "n", hookEvent: "e")),
            .hookProgress(SDKMessage.HookProgressData(hookId: "h", hookName: "n", hookEvent: "e", stdout: nil, stderr: nil)),
            .hookResponse(SDKMessage.HookResponseData(hookId: "h", hookName: "n", hookEvent: "e", output: nil, exitCode: nil, outcome: nil)),
            .taskStarted(SDKMessage.TaskStartedData(taskId: "t", taskType: "s", description: "d")),
            .taskProgress(SDKMessage.TaskProgressData(taskId: "t", taskType: "s", usage: nil)),
            .authStatus(SDKMessage.AuthStatusData(status: "ok", message: "m")),
            .filesPersisted(SDKMessage.FilesPersistedData(filePaths: [])),
            .localCommandOutput(SDKMessage.LocalCommandOutputData(output: "o", command: "c")),
            .promptSuggestion(SDKMessage.PromptSuggestionData(suggestions: [])),
            .toolUseSummary(SDKMessage.ToolUseSummaryData(toolUseCount: 0, tools: [])),
        ]

        XCTAssertEqual(messages.count, 18, "SDKMessage must have exactly 18 cases after enhancement")

        for message in messages {
            switch message {
            case .assistant: break
            case .toolUse: break
            case .toolResult: break
            case .result: break
            case .partialMessage: break
            case .system: break
            case .userMessage: break
            case .toolProgress: break
            case .hookStarted: break
            case .hookProgress: break
            case .hookResponse: break
            case .taskStarted: break
            case .taskProgress: break
            case .authStatus: break
            case .filesPersisted: break
            case .localCommandOutput: break
            case .promptSuggestion: break
            case .toolUseSummary: break
            }
        }
    }
}

// MARK: - AC2: AssistantData Field Completion

/// Tests for the 4 new fields on AssistantData: uuid, sessionId, parentToolUseId, error.
final class AssistantDataEnhancementATDDTests: XCTestCase {

    /// AC2 [P0]: AssistantData can be constructed with uuid field.
    func testAssistantData_uuidField() {
        let data = SDKMessage.AssistantData(
            text: "Hello",
            model: "claude-sonnet-4-6",
            stopReason: "end_turn",
            uuid: "msg-uuid-123",
            sessionId: nil,
            parentToolUseId: nil,
            error: nil
        )
        XCTAssertEqual(data.uuid, "msg-uuid-123")
    }

    /// AC2 [P0]: AssistantData can be constructed with sessionId field.
    func testAssistantData_sessionIdField() {
        let data = SDKMessage.AssistantData(
            text: "Hello",
            model: "claude-sonnet-4-6",
            stopReason: "end_turn",
            uuid: nil,
            sessionId: "sess-456",
            parentToolUseId: nil,
            error: nil
        )
        XCTAssertEqual(data.sessionId, "sess-456")
    }

    /// AC2 [P0]: AssistantData can be constructed with parentToolUseId field.
    func testAssistantData_parentToolUseIdField() {
        let data = SDKMessage.AssistantData(
            text: "Hello",
            model: "claude-sonnet-4-6",
            stopReason: "end_turn",
            uuid: nil,
            sessionId: nil,
            parentToolUseId: "toolu_parent",
            error: nil
        )
        XCTAssertEqual(data.parentToolUseId, "toolu_parent")
    }

    /// AC2 [P0]: AssistantData can be constructed with error field.
    func testAssistantData_errorField() {
        let error = SDKMessage.AssistantError.authenticationFailed
        let data = SDKMessage.AssistantData(
            text: "",
            model: "claude-sonnet-4-6",
            stopReason: "error",
            uuid: nil,
            sessionId: nil,
            parentToolUseId: nil,
            error: error
        )
        XCTAssertEqual(data.error, .authenticationFailed)
    }

    /// AC2 [P0]: AssistantError has all 7 subtypes from TS SDK.
    func testAssistantError_all7Subtypes() {
        let subtypes: [SDKMessage.AssistantError] = [
            .authenticationFailed,
            .billingError,
            .rateLimit,
            .invalidRequest,
            .serverError,
            .maxOutputTokens,
            .unknown
        ]
        XCTAssertEqual(subtypes.count, 7, "AssistantError must have exactly 7 subtypes matching TS SDK")
    }

    /// AC2 [P0]: Backward compatibility - AssistantData init with only original 3 fields compiles.
    func testAssistantData_backwardCompatibility() {
        let data = SDKMessage.AssistantData(text: "Hello", model: "m", stopReason: "s")
        XCTAssertEqual(data.text, "Hello")
        XCTAssertNil(data.uuid)
        XCTAssertNil(data.sessionId)
        XCTAssertNil(data.parentToolUseId)
        XCTAssertNil(data.error)
    }

    /// AC2 [P1]: AssistantError has correct rawValue strings.
    func testAssistantError_rawValues() {
        XCTAssertEqual(SDKMessage.AssistantError.authenticationFailed.rawValue, "authenticationFailed")
        XCTAssertEqual(SDKMessage.AssistantError.billingError.rawValue, "billingError")
        XCTAssertEqual(SDKMessage.AssistantError.rateLimit.rawValue, "rateLimit")
        XCTAssertEqual(SDKMessage.AssistantError.invalidRequest.rawValue, "invalidRequest")
        XCTAssertEqual(SDKMessage.AssistantError.serverError.rawValue, "serverError")
        XCTAssertEqual(SDKMessage.AssistantError.maxOutputTokens.rawValue, "maxOutputTokens")
        XCTAssertEqual(SDKMessage.AssistantError.unknown.rawValue, "unknown")
    }
}

// MARK: - AC3: ResultData Field Completion

/// Tests for new ResultData fields: structuredOutput, permissionDenials, modelUsage,
/// and new subtype errorMaxStructuredOutputRetries.
final class ResultDataEnhancementATDDTests: XCTestCase {

    /// AC3 [P0]: ResultData.Subtype has errorMaxStructuredOutputRetries case.
    func testResultData_errorMaxStructuredOutputRetries_subtype() {
        let subtype = SDKMessage.ResultData.Subtype.errorMaxStructuredOutputRetries
        XCTAssertEqual(subtype.rawValue, "errorMaxStructuredOutputRetries")
    }

    /// AC3 [P0]: ResultData can be constructed with structuredOutput field.
    func testResultData_structuredOutputField() {
        let structuredOutput = SDKMessage.SendableStructuredOutput(["key": "value", "count": 42] as [String: Any])
        let data = SDKMessage.ResultData(
            subtype: .success,
            text: "Done",
            usage: nil,
            numTurns: 1,
            durationMs: 100,
            structuredOutput: structuredOutput
        )
        XCTAssertNotNil(data.structuredOutput)
    }

    /// AC3 [P0]: ResultData can be constructed with permissionDenials field.
    func testResultData_permissionDenialsField() {
        let denials = [
            SDKMessage.SDKPermissionDenial(toolName: "Bash", toolUseId: "tu_123", toolInput: "rm -rf /")
        ]
        let data = SDKMessage.ResultData(
            subtype: .success,
            text: "Denied",
            usage: nil,
            numTurns: 1,
            durationMs: 100,
            permissionDenials: denials
        )
        XCTAssertEqual(data.permissionDenials?.count, 1)
        XCTAssertEqual(data.permissionDenials?[0].toolName, "Bash")
    }

    /// AC3 [P0]: SDKPermissionDenial struct has all required fields.
    func testSDKPermissionDenial_fields() {
        let denial = SDKMessage.SDKPermissionDenial(
            toolName: "Write",
            toolUseId: "tu_789",
            toolInput: "{\"path\":\"/etc/hosts\"}"
        )
        XCTAssertEqual(denial.toolName, "Write")
        XCTAssertEqual(denial.toolUseId, "tu_789")
        XCTAssertEqual(denial.toolInput, "{\"path\":\"/etc/hosts\"}")
    }

    /// AC3 [P0]: ResultData can be constructed with modelUsage field (distinct from costBreakdown).
    func testResultData_modelUsageField() {
        let modelUsage = [
            SDKMessage.ModelUsageEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50)
        ]
        let data = SDKMessage.ResultData(
            subtype: .success,
            text: "",
            usage: nil,
            numTurns: 1,
            durationMs: 100,
            modelUsage: modelUsage
        )
        XCTAssertEqual(data.modelUsage?.count, 1)
        XCTAssertEqual(data.modelUsage?[0].model, "claude-sonnet-4-6")
    }

    /// AC3 [P1]: modelUsage coexists with costBreakdown.
    func testResultData_modelUsage_coexistsWith_costBreakdown() {
        let modelUsage = [
            SDKMessage.ModelUsageEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50)
        ]
        let costBreakdown = [
            CostBreakdownEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50, costUsd: 0.003)
        ]
        let data = SDKMessage.ResultData(
            subtype: .success,
            text: "",
            usage: nil,
            numTurns: 1,
            durationMs: 100,
            totalCostUsd: 0.003,
            costBreakdown: costBreakdown,
            modelUsage: modelUsage
        )
        XCTAssertEqual(data.costBreakdown.count, 1)
        XCTAssertEqual(data.modelUsage?.count, 1)
    }

    /// AC3 [P0]: Backward compatibility - ResultData init with only original fields compiles.
    func testResultData_backwardCompatibility() {
        let data = SDKMessage.ResultData(
            subtype: .success,
            text: "ok",
            usage: nil,
            numTurns: 1,
            durationMs: 100
        )
        XCTAssertNil(data.structuredOutput)
        XCTAssertNil(data.permissionDenials)
        XCTAssertNil(data.modelUsage)
    }

    /// AC3 [P0]: ResultData.Subtype has all 6 cases (5 original + errorMaxStructuredOutputRetries).
    func testResultData_allSubtypes() {
        let subtypes: [SDKMessage.ResultData.Subtype] = [
            .success,
            .errorMaxTurns,
            .errorDuringExecution,
            .errorMaxBudgetUsd,
            .cancelled,
            .errorMaxStructuredOutputRetries
        ]
        XCTAssertEqual(subtypes.count, 6, "ResultData.Subtype must have exactly 6 cases after enhancement")
    }
}

// MARK: - AC4: SystemData Init Field Completion

/// Tests for new optional fields on SystemData: sessionId, tools, model,
/// permissionMode, mcpServers, cwd, and new subtypes.
final class SystemDataEnhancementATDDTests: XCTestCase {

    /// AC4 [P0]: SystemData can be constructed with sessionId field.
    func testSystemData_sessionIdField() {
        let data = SDKMessage.SystemData(
            subtype: .`init`,
            message: "Session started",
            sessionId: "sess-001"
        )
        XCTAssertEqual(data.sessionId, "sess-001")
    }

    /// AC4 [P0]: SystemData can be constructed with tools field.
    func testSystemData_toolsField() {
        let tools = [
            SDKMessage.ToolInfo(name: "Bash", description: "Run shell commands"),
            SDKMessage.ToolInfo(name: "Read", description: "Read file contents")
        ]
        let data = SDKMessage.SystemData(
            subtype: .`init`,
            message: "Session started",
            tools: tools
        )
        XCTAssertEqual(data.tools?.count, 2)
        XCTAssertEqual(data.tools?[0].name, "Bash")
    }

    /// AC4 [P0]: SystemData can be constructed with model field.
    func testSystemData_modelField() {
        let data = SDKMessage.SystemData(
            subtype: .`init`,
            message: "Session started",
            model: "claude-sonnet-4-6"
        )
        XCTAssertEqual(data.model, "claude-sonnet-4-6")
    }

    /// AC4 [P0]: SystemData can be constructed with permissionMode field.
    func testSystemData_permissionModeField() {
        let data = SDKMessage.SystemData(
            subtype: .`init`,
            message: "Session started",
            permissionMode: "default"
        )
        XCTAssertEqual(data.permissionMode, "default")
    }

    /// AC4 [P0]: SystemData can be constructed with mcpServers field.
    func testSystemData_mcpServersField() {
        let servers = [
            SDKMessage.McpServerInfo(name: "filesystem", command: "npx")
        ]
        let data = SDKMessage.SystemData(
            subtype: .`init`,
            message: "Session started",
            mcpServers: servers
        )
        XCTAssertEqual(data.mcpServers?.count, 1)
        XCTAssertEqual(data.mcpServers?[0].name, "filesystem")
    }

    /// AC4 [P0]: SystemData can be constructed with cwd field.
    func testSystemData_cwdField() {
        let data = SDKMessage.SystemData(
            subtype: .`init`,
            message: "Session started",
            cwd: "/Users/nick/project"
        )
        XCTAssertEqual(data.cwd, "/Users/nick/project")
    }

    /// AC4 [P0]: SystemData.Subtype has taskStarted case.
    func testSystemData_taskStartedSubtype() {
        let subtype = SDKMessage.SystemData.Subtype.taskStarted
        XCTAssertEqual(subtype.rawValue, "taskStarted")
    }

    /// AC4 [P0]: SystemData.Subtype has taskProgress case.
    func testSystemData_taskProgressSubtype() {
        let subtype = SDKMessage.SystemData.Subtype.taskProgress
        XCTAssertEqual(subtype.rawValue, "taskProgress")
    }

    /// AC4 [P0]: SystemData.Subtype has hookStarted case.
    func testSystemData_hookStartedSubtype() {
        let subtype = SDKMessage.SystemData.Subtype.hookStarted
        XCTAssertEqual(subtype.rawValue, "hookStarted")
    }

    /// AC4 [P0]: SystemData.Subtype has hookProgress case.
    func testSystemData_hookProgressSubtype() {
        let subtype = SDKMessage.SystemData.Subtype.hookProgress
        XCTAssertEqual(subtype.rawValue, "hookProgress")
    }

    /// AC4 [P0]: SystemData.Subtype has hookResponse case.
    func testSystemData_hookResponseSubtype() {
        let subtype = SDKMessage.SystemData.Subtype.hookResponse
        XCTAssertEqual(subtype.rawValue, "hookResponse")
    }

    /// AC4 [P0]: SystemData.Subtype has filesPersisted case.
    func testSystemData_filesPersistedSubtype() {
        let subtype = SDKMessage.SystemData.Subtype.filesPersisted
        XCTAssertEqual(subtype.rawValue, "filesPersisted")
    }

    /// AC4 [P0]: SystemData.Subtype has localCommandOutput case.
    func testSystemData_localCommandOutputSubtype() {
        let subtype = SDKMessage.SystemData.Subtype.localCommandOutput
        XCTAssertEqual(subtype.rawValue, "localCommandOutput")
    }

    /// AC4 [P0]: SystemData.Subtype has all 12 subtypes (5 original + 7 new).
    func testSystemData_allSubtypes() {
        let subtypes: [SDKMessage.SystemData.Subtype] = [
            .`init`,
            .compactBoundary,
            .status,
            .taskNotification,
            .rateLimit,
            .taskStarted,
            .taskProgress,
            .hookStarted,
            .hookProgress,
            .hookResponse,
            .filesPersisted,
            .localCommandOutput
        ]
        XCTAssertEqual(subtypes.count, 12, "SystemData.Subtype must have exactly 12 cases after enhancement")
    }

    /// AC4 [P0]: Backward compatibility - SystemData init with only original 2 fields compiles.
    func testSystemData_backwardCompatibility() {
        let data = SDKMessage.SystemData(subtype: .`init`, message: "started")
        XCTAssertEqual(data.message, "started")
        XCTAssertNil(data.sessionId)
        XCTAssertNil(data.tools)
        XCTAssertNil(data.model)
        XCTAssertNil(data.permissionMode)
        XCTAssertNil(data.mcpServers)
        XCTAssertNil(data.cwd)
    }

    /// AC4 [P0]: ToolInfo struct has name and description fields.
    func testToolInfo_fields() {
        let info = SDKMessage.ToolInfo(name: "Bash", description: "Run shell commands")
        XCTAssertEqual(info.name, "Bash")
        XCTAssertEqual(info.description, "Run shell commands")
    }

    /// AC4 [P0]: McpServerInfo struct has name and command fields.
    func testMcpServerInfo_fields() {
        let info = SDKMessage.McpServerInfo(name: "github", command: "npx -y @modelcontextprotocol/server-github")
        XCTAssertEqual(info.name, "github")
        XCTAssertEqual(info.command, "npx -y @modelcontextprotocol/server-github")
    }
}

// MARK: - AC5: PartialData Field Completion

/// Tests for new optional fields on PartialData: parentToolUseId, uuid, sessionId.
final class PartialDataEnhancementATDDTests: XCTestCase {

    /// AC5 [P0]: PartialData can be constructed with parentToolUseId field.
    func testPartialData_parentToolUseIdField() {
        let data = SDKMessage.PartialData(
            text: "Hello",
            parentToolUseId: "toolu_parent_001"
        )
        XCTAssertEqual(data.parentToolUseId, "toolu_parent_001")
    }

    /// AC5 [P0]: PartialData can be constructed with uuid field.
    func testPartialData_uuidField() {
        let data = SDKMessage.PartialData(
            text: "Hello",
            uuid: "msg-uuid-789"
        )
        XCTAssertEqual(data.uuid, "msg-uuid-789")
    }

    /// AC5 [P0]: PartialData can be constructed with sessionId field.
    func testPartialData_sessionIdField() {
        let data = SDKMessage.PartialData(
            text: "Hello",
            sessionId: "sess-abc"
        )
        XCTAssertEqual(data.sessionId, "sess-abc")
    }

    /// AC5 [P0]: PartialData can be constructed with all new fields.
    func testPartialData_allNewFields() {
        let data = SDKMessage.PartialData(
            text: "Streaming",
            parentToolUseId: "toolu_999",
            uuid: "uuid-full",
            sessionId: "sess-full"
        )
        XCTAssertEqual(data.text, "Streaming")
        XCTAssertEqual(data.parentToolUseId, "toolu_999")
        XCTAssertEqual(data.uuid, "uuid-full")
        XCTAssertEqual(data.sessionId, "sess-full")
    }

    /// AC5 [P0]: Backward compatibility - PartialData init with only text compiles.
    func testPartialData_backwardCompatibility() {
        let data = SDKMessage.PartialData(text: "Hello")
        XCTAssertEqual(data.text, "Hello")
        XCTAssertNil(data.parentToolUseId)
        XCTAssertNil(data.uuid)
        XCTAssertNil(data.sessionId)
    }
}

// MARK: - AC6: Sendable Conformance for All New Types

/// Verifies that all new types conform to Sendable protocol.
final class SendableConformanceATDDTests: XCTestCase {

    /// AC6 [P0]: All new message data types conform to Sendable.
    func testAllNewTypes_areSendable() {
        // These assignments will fail to compile if types don't conform to Sendable
        let _: Sendable = SDKMessage.UserMessageData(uuid: nil, sessionId: nil, message: "u", parentToolUseId: nil, isSynthetic: nil, toolUseResult: nil)
        let _: Sendable = SDKMessage.ToolProgressData(toolUseId: "t", toolName: "n", parentToolUseId: nil, elapsedTimeSeconds: nil)
        let _: Sendable = SDKMessage.HookStartedData(hookId: "h", hookName: "n", hookEvent: "e")
        let _: Sendable = SDKMessage.HookProgressData(hookId: "h", hookName: "n", hookEvent: "e", stdout: nil, stderr: nil)
        let _: Sendable = SDKMessage.HookResponseData(hookId: "h", hookName: "n", hookEvent: "e", output: nil, exitCode: nil, outcome: nil)
        let _: Sendable = SDKMessage.TaskStartedData(taskId: "t", taskType: "s", description: "d")
        let _: Sendable = SDKMessage.TaskProgressData(taskId: "t", taskType: "s", usage: nil)
        let _: Sendable = SDKMessage.AuthStatusData(status: "ok", message: "m")
        let _: Sendable = SDKMessage.FilesPersistedData(filePaths: [])
        let _: Sendable = SDKMessage.LocalCommandOutputData(output: "o", command: "c")
        let _: Sendable = SDKMessage.PromptSuggestionData(suggestions: [])
        let _: Sendable = SDKMessage.ToolUseSummaryData(toolUseCount: 0, tools: [])
    }

    /// AC6 [P0]: Supporting types also conform to Sendable.
    func testSupportingTypes_areSendable() {
        let _: Sendable = SDKMessage.AssistantError.authenticationFailed
        let _: Sendable = SDKMessage.SDKPermissionDenial(toolName: "t", toolUseId: "i", toolInput: "{}")
        let _: Sendable = SDKMessage.ModelUsageEntry(model: "m", inputTokens: 1, outputTokens: 2)
        let _: Sendable = SDKMessage.ToolInfo(name: "n", description: "d")
        let _: Sendable = SDKMessage.McpServerInfo(name: "n", command: "c")
    }

    /// AC6 [P0]: Enhanced existing types still conform to Sendable.
    func testEnhancedTypes_stillSendable() {
        let _: Sendable = SDKMessage.AssistantData(text: "a", model: "m", stopReason: "s", uuid: nil, sessionId: nil, parentToolUseId: nil, error: nil)
        let _: Sendable = SDKMessage.ResultData(subtype: .success, text: "t", usage: nil, numTurns: 1, durationMs: 100)
        let _: Sendable = SDKMessage.SystemData(subtype: .`init`, message: "m")
        let _: Sendable = SDKMessage.PartialData(text: "p")
    }
}

// MARK: - AC7: Zero Regression (Placeholder — run full test suite post-implementation)

/// AC7 tests verify that all existing tests pass after changes.
/// The actual regression check is done by running the full test suite (3650+ tests).
/// These tests verify specific backward-compatibility contracts.
final class ZeroRegressionATDDTests: XCTestCase {

    /// AC7 [P0]: All original SDKMessage cases still work with their original init signatures.
    func testOriginalCases_backwardCompat() {
        // AssistantData with original 3 fields
        let assistant = SDKMessage.AssistantData(text: "Hello", model: "claude-sonnet-4-6", stopReason: "end_turn")
        XCTAssertEqual(assistant.text, "Hello")

        // ToolUseData unchanged
        let toolUse = SDKMessage.ToolUseData(toolName: "Bash", toolUseId: "id", input: "{}")
        XCTAssertEqual(toolUse.toolName, "Bash")

        // ToolResultData unchanged
        let toolResult = SDKMessage.ToolResultData(toolUseId: "id", content: "c", isError: false)
        XCTAssertEqual(toolResult.content, "c")

        // ResultData with original fields
        let result = SDKMessage.ResultData(subtype: .success, text: "ok", usage: nil, numTurns: 1, durationMs: 100)
        XCTAssertEqual(result.text, "ok")

        // PartialData with original 1 field
        let partial = SDKMessage.PartialData(text: "p")
        XCTAssertEqual(partial.text, "p")

        // SystemData with original 2 fields
        let system = SDKMessage.SystemData(subtype: .`init`, message: "started")
        XCTAssertEqual(system.message, "started")
    }

    /// AC7 [P1]: text computed property works for all original cases.
    func testTextProperty_originalCases() {
        XCTAssertEqual(SDKMessage.assistant(SDKMessage.AssistantData(text: "a", model: "m", stopReason: "s")).text, "a")
        XCTAssertEqual(SDKMessage.toolUse(SDKMessage.ToolUseData(toolName: "Bash", toolUseId: "id", input: "{}")).text, "Bash")
        XCTAssertEqual(SDKMessage.toolResult(SDKMessage.ToolResultData(toolUseId: "id", content: "c", isError: false)).text, "c")
        XCTAssertEqual(SDKMessage.result(SDKMessage.ResultData(subtype: .success, text: "r", usage: nil, numTurns: 1, durationMs: 100)).text, "r")
        XCTAssertEqual(SDKMessage.partialMessage(SDKMessage.PartialData(text: "p")).text, "p")
        XCTAssertEqual(SDKMessage.system(SDKMessage.SystemData(subtype: .`init`, message: "m")).text, "m")
    }
}

// MARK: - AC8: AsyncStream Integration (Placeholder)

/// AC8 tests verify that new message types work through the AsyncStream<SDKMessage> pipeline.
/// Full integration testing requires Agent.swift modifications.
/// These tests verify the types are compatible with AsyncStream usage.
final class AsyncStreamIntegrationATDDTests: XCTestCase {

    /// AC8 [P1]: New SDKMessage cases can be yielded through an AsyncStream.
    func testAsyncStream_newMessageTypes() async {
        let newMessages: [SDKMessage] = [
            .userMessage(SDKMessage.UserMessageData(uuid: nil, sessionId: nil, message: "hi", parentToolUseId: nil, isSynthetic: nil, toolUseResult: nil)),
            .toolProgress(SDKMessage.ToolProgressData(toolUseId: "tp", toolName: "Bash", parentToolUseId: nil, elapsedTimeSeconds: nil)),
            .hookStarted(SDKMessage.HookStartedData(hookId: "h", hookName: "n", hookEvent: "e")),
            .taskStarted(SDKMessage.TaskStartedData(taskId: "t", taskType: "s", description: "d")),
            .authStatus(SDKMessage.AuthStatusData(status: "ok", message: "m")),
        ]

        // Verify they can be used in an AsyncStream context
        let stream = AsyncStream<SDKMessage> { continuation in
            for message in newMessages {
                continuation.yield(message)
            }
            continuation.finish()
        }

        var collected: [SDKMessage] = []
        for await message in stream {
            collected.append(message)
        }
        XCTAssertEqual(collected.count, 5, "All new message types should be yieldable through AsyncStream")
    }

    /// AC8 [P1]: Enhanced existing types still work through AsyncStream.
    func testAsyncStream_enhancedTypes() async {
        let enhancedMessages: [SDKMessage] = [
            .assistant(SDKMessage.AssistantData(text: "a", model: "m", stopReason: "s", uuid: "uuid-1", sessionId: "sess-1", parentToolUseId: nil, error: nil)),
            .result(SDKMessage.ResultData(subtype: .success, text: "r", usage: nil, numTurns: 1, durationMs: 100, structuredOutput: SDKMessage.SendableStructuredOutput(nil))),
            .system(SDKMessage.SystemData(subtype: .`init`, message: "m", sessionId: "sess-2")),
            .partialMessage(SDKMessage.PartialData(text: "p", uuid: "uuid-3", sessionId: "sess-3")),
        ]

        let stream = AsyncStream<SDKMessage> { continuation in
            for message in enhancedMessages {
                continuation.yield(message)
            }
            continuation.finish()
        }

        var collected: [SDKMessage] = []
        for await message in stream {
            collected.append(message)
        }
        XCTAssertEqual(collected.count, 4, "Enhanced existing types should work through AsyncStream")
    }
}

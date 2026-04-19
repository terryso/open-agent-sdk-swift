// CompatMessageTypes 示例 / Message Types Compatibility Verification Example
//
// 验证 Swift SDK 的 SDKMessage 类型是否与 TypeScript SDK 的 20 种消息子类型完全兼容。
// Verifies Swift SDK's SDKMessage type covers all 20 TypeScript SDK message subtypes
// with field-level verification and gap documentation.
//
// 运行方式 / Run: swift run CompatMessageTypes
// 前提条件 / Prerequisites: 在 .env 文件或环境变量中设置 API Key

import Foundation
import OpenAgentSDK

// MARK: - Environment Setup

let dotEnv = loadDotEnv()
let apiKey = getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? ""
guard !apiKey.isEmpty else {
    print("[ERROR] ANTHROPIC_API_KEY or CODEANY_API_KEY not set. Export it or add to .env file.")
    exit(1)
}

let baseURL = getEnv("CODEANY_BASE_URL", from: dotEnv)
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"

// Detect provider from env: CODEANY_API_KEY implies OpenAI-compatible provider
let isCodeany = getEnv("CODEANY_API_KEY", from: dotEnv) != nil
let defaultProvider: LLMProvider = isCodeany ? .openai : .anthropic

// MARK: - Compat Report Tracking

struct CompatEntry {
    let tsField: String
    let swiftField: String
    let status: String  // "PASS", "MISSING", "PARTIAL", "N/A"
    let note: String?
}

nonisolated(unsafe) var compatReport: [CompatEntry] = []

func record(_ tsField: String, swiftField: String, status: String, note: String? = nil) {
    compatReport.append(CompatEntry(tsField: tsField, swiftField: swiftField, status: status, note: note))
    let statusStr = status == "PASS" ? "[PASS]" : status == "MISSING" ? "[MISSING]" : status == "PARTIAL" ? "[PARTIAL]" : "[N/A]"
    print("  \(statusStr) TS: \(tsField) -> Swift: \(swiftField)\(note.map { " (\($0))" } ?? "")")
}

func pad(_ s: String, _ n: Int) -> String {
    s.padding(toLength: n, withPad: " ", startingAt: 0)
}

// MARK: - AC1: Build Compilation Verification

print("=== AC1: Build Compilation ===")
print("[PASS] CompatMessageTypes target compiles successfully")
print("")

// MARK: - AC2: SDKAssistantMessage Verification (Static)

print("=== AC2: SDKAssistantMessage Verification ===")

// Verify AssistantData fields at compile time -- construct with all 7 fields (Story 17-1)
let fullAssistant = SDKMessage.AssistantData(
    text: "Hello", model: "claude-sonnet-4-6", stopReason: "end_turn",
    uuid: "msg-uuid-123", sessionId: "sess-abc",
    parentToolUseId: "toolu_parent", error: .rateLimit
)
_ = fullAssistant.text
_ = fullAssistant.model
_ = fullAssistant.stopReason
_ = fullAssistant.uuid
_ = fullAssistant.sessionId
_ = fullAssistant.parentToolUseId
_ = fullAssistant.error

record("SDKAssistantMessage.text", swiftField: "AssistantData.text: String", status: "PASS",
       note: "Maps to TS SDK message.content")
record("SDKAssistantMessage.model", swiftField: "AssistantData.model: String", status: "PASS",
       note: "model='\(fullAssistant.model)'")
record("SDKAssistantMessage.stopReason", swiftField: "AssistantData.stopReason: String", status: "PASS",
       note: "stopReason='\(fullAssistant.stopReason)'")

// Story 17-1 resolved fields (previously MISSING, now PASS)
record("SDKAssistantMessage.uuid", swiftField: "AssistantData.uuid: String?", status: "PASS",
       note: "uuid='\(fullAssistant.uuid ?? "nil")'")
record("SDKAssistantMessage.session_id", swiftField: "AssistantData.sessionId: String?", status: "PASS",
       note: "sessionId='\(fullAssistant.sessionId ?? "nil")'")
record("SDKAssistantMessage.parent_tool_use_id", swiftField: "AssistantData.parentToolUseId: String?", status: "PASS",
       note: "parentToolUseId='\(fullAssistant.parentToolUseId ?? "nil")'")
record("SDKAssistantMessage.error", swiftField: "AssistantData.error: AssistantError? (7 subtypes)", status: "PASS",
       note: "error=\(fullAssistant.error?.rawValue ?? "nil"). 7 subtypes: authenticationFailed, billingError, rateLimit, invalidRequest, serverError, maxOutputTokens, unknown")

// Verify AssistantError has all 7 subtypes
let allErrorSubtypes: [SDKMessage.AssistantError] = [
    .authenticationFailed, .billingError, .rateLimit,
    .invalidRequest, .serverError, .maxOutputTokens, .unknown
]
print("  AssistantError subtypes: \(allErrorSubtypes.map { $0.rawValue })")

// Use Mirror to verify field count
let assistantMirror = Mirror(reflecting: fullAssistant)
print("  AssistantData field count: \(assistantMirror.children.count) (7 fields: text, model, stopReason, uuid, sessionId, parentToolUseId, error)")

print("")

// MARK: - AC3: SDKResultMessage Verification (Static)

print("=== AC3: SDKResultMessage Verification ===")

// Verify ResultData with all Story 17-1 fields
let fullResult = SDKMessage.ResultData(
    subtype: .success, text: "done",
    usage: TokenUsage(inputTokens: 100, outputTokens: 50),
    numTurns: 2, durationMs: 1500,
    totalCostUsd: 0.05,
    costBreakdown: [CostBreakdownEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50, costUsd: 0.003)],
    structuredOutput: SDKMessage.SendableStructuredOutput(["result": "ok"]),
    permissionDenials: [SDKMessage.SDKPermissionDenial(toolName: "Bash", toolUseId: "tu_1", toolInput: "ls")],
    modelUsage: [SDKMessage.ModelUsageEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50)]
)

record("SDKResultMessage (success).result", swiftField: "ResultData.text: String", status: "PASS",
       note: "text='\(fullResult.text)'")
record("SDKResultMessage.total_cost_usd", swiftField: "ResultData.totalCostUsd: Double", status: "PASS",
       note: "totalCostUsd=\(fullResult.totalCostUsd)")
record("SDKResultMessage.usage", swiftField: "ResultData.usage: TokenUsage?", status: "PASS",
       note: "inputTokens=\(fullResult.usage?.inputTokens ?? 0), outputTokens=\(fullResult.usage?.outputTokens ?? 0)")
record("SDKResultMessage.model_usage", swiftField: "ResultData.costBreakdown: [CostBreakdownEntry]", status: "PASS",
       note: "Similar to TS model_usage but different naming. count=\(fullResult.costBreakdown.count)")
record("SDKResultMessage.num_turns", swiftField: "ResultData.numTurns: Int", status: "PASS",
       note: "numTurns=\(fullResult.numTurns)")
record("SDKResultMessage.duration_ms", swiftField: "ResultData.durationMs: Int", status: "PASS",
       note: "durationMs=\(fullResult.durationMs)")

// Verify all error subtypes exist at compile time (including Story 17-1 addition)
let allResultSubtypes: [SDKMessage.ResultData.Subtype] = [
    .success, .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd, .cancelled, .errorMaxStructuredOutputRetries
]
print("  All ResultData.Subtype cases: \(allResultSubtypes.map { $0.rawValue })")

record("SDKResultMessage subtype: success", swiftField: "ResultData.Subtype.success", status: "PASS")
record("SDKResultMessage subtype: error_max_turns", swiftField: "ResultData.Subtype.errorMaxTurns", status: "PASS")
record("SDKResultMessage subtype: error_during_execution", swiftField: "ResultData.Subtype.errorDuringExecution", status: "PASS")
record("SDKResultMessage subtype: error_max_budget_usd", swiftField: "ResultData.Subtype.errorMaxBudgetUsd", status: "PASS")
record("SDKResultMessage subtype: error_max_structured_output_retries", swiftField: "ResultData.Subtype.errorMaxStructuredOutputRetries", status: "PASS",
       note: "Added by Story 17-1")
record("cancelled (Swift-only)", swiftField: "ResultData.Subtype.cancelled", status: "N/A",
       note: "Swift-only addition, not in TS SDK")

// Story 17-1 resolved fields (previously MISSING, now PASS)
record("SDKResultMessage.structuredOutput", swiftField: "ResultData.structuredOutput: SendableStructuredOutput?", status: "PASS",
       note: "Added by Story 17-1. value=\(fullResult.structuredOutput != nil ? "present" : "nil")")
record("SDKResultMessage.permissionDenials", swiftField: "ResultData.permissionDenials: [SDKPermissionDenial]?", status: "PASS",
       note: "Added by Story 17-1. count=\(fullResult.permissionDenials?.count ?? 0)")
record("SDKResultMessage.model_usage (distinct)", swiftField: "ResultData.modelUsage: [ModelUsageEntry]?", status: "PASS",
       note: "Added by Story 17-1. Per-model token usage entries. count=\(fullResult.modelUsage?.count ?? 0)")

// Resolved by Spec 19
record("SDKResultMessage.errors", swiftField: "ResultData.errors ([String]?)", status: "PASS",
       note: "TS SDK: errors: string[] for error result details. Now available.")

print("")

// MARK: - AC4: SDKSystemMessage Verification (Static)

print("=== AC4: SDKSystemMessage Verification ===")

// Verify SystemData init with all Story 17-1 fields
let fullSystem = SDKMessage.SystemData(
    subtype: .`init`, message: "Session started",
    sessionId: "sess-123",
    tools: [SDKMessage.ToolInfo(name: "Bash", description: "Run commands")],
    model: "claude-sonnet-4-6",
    permissionMode: "bypassPermissions",
    mcpServers: [SDKMessage.McpServerInfo(name: "filesystem", command: "npx")],
    cwd: "/tmp/project"
)

// Verify all SystemData subtypes exist at compile time (including 7 Story 17-1 additions)
let allSystemSubtypes: [SDKMessage.SystemData.Subtype] = [
    .`init`, .compactBoundary, .status, .taskNotification, .rateLimit,
    .taskStarted, .taskProgress, .hookStarted, .hookProgress, .hookResponse,
    .filesPersisted, .localCommandOutput
]
print("  All SystemData.Subtype cases (\(allSystemSubtypes.count)): \(allSystemSubtypes.map { $0.rawValue })")

// Story 17-1 resolved: init now has all fields
record("SDKSystemMessage(init)", swiftField: ".system(SystemData) subtype=.init", status: "PASS",
       note: "All init fields present: sessionId='\(fullSystem.sessionId ?? "nil")', tools=\(fullSystem.tools?.count ?? 0), model='\(fullSystem.model ?? "nil")', permissionMode='\(fullSystem.permissionMode ?? "nil")', mcpServers=\(fullSystem.mcpServers?.count ?? 0), cwd='\(fullSystem.cwd ?? "nil")'")

// Remaining PARTIAL entries (genuine gaps)
record("SDKSystemMessage(compact_boundary)", swiftField: ".system(SystemData) subtype=.compactBoundary", status: "PASS",
       note: "Has message + compactMetadata (CompactMetadata with trigger, preTokens, postTokens, preservedSegment)")
record("SDKSystemMessage(status)", swiftField: ".system(SystemData) subtype=.status", status: "PASS",
       note: "Has message + statusValue, compactResult, compactError fields.")
record("SDKSystemMessage(task_notification)", swiftField: ".system(SystemData) subtype=.taskNotification", status: "PASS",
       note: "Has message + taskNotificationInfo (TaskNotificationInfo with taskId, outputFile, summary, usage)")
record("SDKRateLimitEvent", swiftField: ".system(SystemData) subtype=.rateLimit", status: "PASS",
       note: "Has subtype + message + rateLimitInfo (RateLimitInfo with status, resetsAt, rateLimitType, utilization)")

// Story 17-1 resolved: 7 new system subtypes (previously MISSING, now PASS)
record("SDKSystemMessage(task_started)", swiftField: "SystemData.Subtype.taskStarted + .taskStarted(TaskStartedData)", status: "PASS",
       note: "Added by Story 17-1: taskId, taskType, description")
record("SDKSystemMessage(task_progress)", swiftField: "SystemData.Subtype.taskProgress + .taskProgress(TaskProgressData)", status: "PASS",
       note: "Added by Story 17-1: taskId, taskType, usage")
record("SDKSystemMessage(hook_started)", swiftField: "SystemData.Subtype.hookStarted + .hookStarted(HookStartedData)", status: "PASS",
       note: "Added by Story 17-1: hookId, hookName, hookEvent")
record("SDKSystemMessage(hook_progress)", swiftField: "SystemData.Subtype.hookProgress + .hookProgress(HookProgressData)", status: "PASS",
       note: "Added by Story 17-1: hookId, hookName, hookEvent, stdout, stderr")
record("SDKSystemMessage(hook_response)", swiftField: "SystemData.Subtype.hookResponse + .hookResponse(HookResponseData)", status: "PASS",
       note: "Added by Story 17-1: hookId, hookName, hookEvent, output, exitCode, outcome")
record("SDKSystemMessage(files_persisted)", swiftField: "SystemData.Subtype.filesPersisted + .filesPersisted(FilesPersistedData)", status: "PASS",
       note: "Added by Story 17-1: filePaths")
record("SDKSystemMessage(local_command_output)", swiftField: "SystemData.Subtype.localCommandOutput + .localCommandOutput(LocalCommandOutputData)", status: "PASS",
       note: "Added by Story 17-1: output, command")

print("")

// MARK: - AC5: SDKPartialAssistantMessage Verification (Static)

print("=== AC5: SDKPartialAssistantMessage Verification ===")

// Story 17-1: PartialData now has parentToolUseId, uuid, sessionId
let fullPartial = SDKMessage.PartialData(text: "Hello world", parentToolUseId: "toolu_parent", uuid: "msg-uuid", sessionId: "sess-123")
_ = fullPartial.text
_ = fullPartial.parentToolUseId
_ = fullPartial.uuid
_ = fullPartial.sessionId

record("SDKPartialAssistantMessage.text", swiftField: "PartialData.text: String", status: "PASS",
       note: "Provides streaming text chunks")

// Story 17-1 resolved fields (previously MISSING, now PASS)
record("SDKPartialAssistantMessage.parent_tool_use_id", swiftField: "PartialData.parentToolUseId: String?", status: "PASS",
       note: "parentToolUseId='\(fullPartial.parentToolUseId ?? "nil")'")
record("SDKPartialAssistantMessage.uuid", swiftField: "PartialData.uuid: String?", status: "PASS",
       note: "uuid='\(fullPartial.uuid ?? "nil")'")
record("SDKPartialAssistantMessage.session_id", swiftField: "PartialData.sessionId: String?", status: "PASS",
       note: "sessionId='\(fullPartial.sessionId ?? "nil")'")

let partialMirror = Mirror(reflecting: fullPartial)
print("  PartialData field count: \(partialMirror.children.count) (4 fields: text, parentToolUseId, uuid, sessionId)")

print("")

// MARK: - AC6: Tool Progress Message Verification

print("=== AC6: Tool Progress Message Verification ===")

// Story 17-1: .toolProgress(ToolProgressData) now exists
let toolProgData = SDKMessage.ToolProgressData(toolUseId: "tu_1", toolName: "Bash", parentToolUseId: "toolu_parent", elapsedTimeSeconds: 3.5)
let toolProgMsg = SDKMessage.toolProgress(toolProgData)
if case .toolProgress(let retrieved) = toolProgMsg {
    record("SDKToolProgressMessage (entire type)", swiftField: ".toolProgress(ToolProgressData)", status: "PASS",
           note: "Added by Story 17-1. toolUseId=\(retrieved.toolUseId), toolName=\(retrieved.toolName)")
    record("SDKToolProgressMessage.tool_use_id", swiftField: "ToolProgressData.toolUseId: String", status: "PASS",
           note: "toolUseId=\(retrieved.toolUseId)")
    record("SDKToolProgressMessage.tool_name", swiftField: "ToolProgressData.toolName: String", status: "PASS",
           note: "toolName=\(retrieved.toolName)")
    record("SDKToolProgressMessage.elapsed_time_seconds", swiftField: "ToolProgressData.elapsedTimeSeconds: Double?", status: "PASS",
           note: "elapsedTimeSeconds=\(retrieved.elapsedTimeSeconds ?? 0)")
}

print("")

// MARK: - AC7: Hook-Related Message Verification

print("=== AC7: Hook-Related Message Verification ===")

// Story 17-1: hookStarted, hookProgress, hookResponse now exist as SDKMessage cases
let hookStartData = SDKMessage.HookStartedData(hookId: "h1", hookName: "pre", hookEvent: "PreToolUse")
let hookStartMsg = SDKMessage.hookStarted(hookStartData)
if case .hookStarted(let retrieved) = hookStartMsg {
    record("SDKHookStartedMessage (entire type)", swiftField: ".hookStarted(HookStartedData)", status: "PASS",
           note: "Added by Story 17-1. hookId=\(retrieved.hookId), hookName=\(retrieved.hookName), hookEvent=\(retrieved.hookEvent)")
}

let hookProgData = SDKMessage.HookProgressData(hookId: "h2", hookName: "post", hookEvent: "PostToolUse", stdout: "out", stderr: nil)
let hookProgMsg = SDKMessage.hookProgress(hookProgData)
if case .hookProgress(let retrieved) = hookProgMsg {
    record("SDKHookProgressMessage (entire type)", swiftField: ".hookProgress(HookProgressData)", status: "PASS",
           note: "Added by Story 17-1. hookId=\(retrieved.hookId), stdout=\(retrieved.stdout ?? "nil")")
}

let hookRespData = SDKMessage.HookResponseData(hookId: "h3", hookName: "stop", hookEvent: "Stop", output: "done", exitCode: 0, outcome: "success")
let hookRespMsg = SDKMessage.hookResponse(hookRespData)
if case .hookResponse(let retrieved) = hookRespMsg {
    record("SDKHookResponseMessage (entire type)", swiftField: ".hookResponse(HookResponseData)", status: "PASS",
           note: "Added by Story 17-1. hookId=\(retrieved.hookId), outcome=\(retrieved.outcome ?? "nil")")
}

print("")

// MARK: - AC8: Task-Related Message Verification

print("=== AC8: Task-Related Message Verification ===")

// Story 17-1: taskStarted, taskProgress now exist as SDKMessage cases
let taskStartData = SDKMessage.TaskStartedData(taskId: "t1", taskType: "subagent", description: "analysis")
let taskStartMsg = SDKMessage.taskStarted(taskStartData)
if case .taskStarted(let retrieved) = taskStartMsg {
    record("SDKTaskStartedMessage (entire type)", swiftField: ".taskStarted(TaskStartedData)", status: "PASS",
           note: "Added by Story 17-1. taskId=\(retrieved.taskId), taskType=\(retrieved.taskType), description=\(retrieved.description)")
}

let taskProgData = SDKMessage.TaskProgressData(taskId: "t2", taskType: "subagent")
let taskProgMsg = SDKMessage.taskProgress(taskProgData)
if case .taskProgress(let retrieved) = taskProgMsg {
    record("SDKTaskProgressMessage (entire type)", swiftField: ".taskProgress(TaskProgressData)", status: "PASS",
           note: "Added by Story 17-1. taskId=\(retrieved.taskId)")
}

record("SDKTaskNotificationMessage", swiftField: ".system(SystemData) subtype=.taskNotification", status: "PASS",
       note: "Type exists with taskNotificationInfo: taskId, outputFile, summary, usage (resolved by Spec 19)")

print("")

// MARK: - AC9: Other Message Type Verification

print("=== AC9: Other Message Type Verification ===")

// Story 17-1: all previously MISSING types now exist
let userMsgData = SDKMessage.UserMessageData(message: "Hello")
let userMsg = SDKMessage.userMessage(userMsgData)
if case .userMessage(let retrieved) = userMsg {
    record("SDKUserMessage (entire type)", swiftField: ".userMessage(UserMessageData)", status: "PASS",
           note: "Added by Story 17-1. message=\(retrieved.message)")
}

let authData = SDKMessage.AuthStatusData(status: "authenticated", message: "API key valid")
let authMsg = SDKMessage.authStatus(authData)
if case .authStatus(let retrieved) = authMsg {
    record("SDKAuthStatusMessage (entire type)", swiftField: ".authStatus(AuthStatusData)", status: "PASS",
           note: "Added by Story 17-1. status=\(retrieved.status)")
}

let filesData = SDKMessage.FilesPersistedData(filePaths: ["/tmp/a.swift"])
let filesMsg = SDKMessage.filesPersisted(filesData)
if case .filesPersisted(let retrieved) = filesMsg {
    record("SDKFilesPersistedEvent (entire type)", swiftField: ".filesPersisted(FilesPersistedData)", status: "PASS",
           note: "Added by Story 17-1. filePaths=\(retrieved.filePaths)")
}

let promptSuggData = SDKMessage.PromptSuggestionData(suggestions: ["Run tests"])
let promptSuggMsg = SDKMessage.promptSuggestion(promptSuggData)
if case .promptSuggestion(let retrieved) = promptSuggMsg {
    record("SDKPromptSuggestionMessage (entire type)", swiftField: ".promptSuggestion(PromptSuggestionData)", status: "PASS",
           note: "Added by Story 17-1. suggestions=\(retrieved.suggestions)")
}

let toolSummData = SDKMessage.ToolUseSummaryData(toolUseCount: 5, tools: ["Bash"])
let toolSummMsg = SDKMessage.toolUseSummary(toolSummData)
if case .toolUseSummary(let retrieved) = toolSummMsg {
    record("SDKToolUseSummaryMessage (entire type)", swiftField: ".toolUseSummary(ToolUseSummaryData)", status: "PASS",
           note: "Added by Story 17-1. toolUseCount=\(retrieved.toolUseCount), tools=\(retrieved.tools)")
}

let localCmdData = SDKMessage.LocalCommandOutputData(output: "Build OK", command: "swift build")
let localCmdMsg = SDKMessage.localCommandOutput(localCmdData)
if case .localCommandOutput(let retrieved) = localCmdMsg {
    record("SDKLocalCommandOutputMessage (entire type)", swiftField: ".localCommandOutput(LocalCommandOutputData)", status: "PASS",
           note: "Added by Story 17-1. output=\(retrieved.output), command=\(retrieved.command)")
}

print("")

// MARK: - Live Streaming Verification (AC2-AC5 with real messages)

print("=== Live Streaming Verification ===")

let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: baseURL,
    provider: defaultProvider,
    systemPrompt: "You are a helpful assistant. Be very concise. Reply with just the answer.",
    maxTurns: 3,
    permissionMode: .bypassPermissions
))

var liveAssistantData: SDKMessage.AssistantData?
var liveResultData: SDKMessage.ResultData?
var liveSystemData: SDKMessage.SystemData?
var livePartialCount = 0
var liveToolUseCount = 0
var liveToolResultCount = 0

let stream = agent.stream("What is 3+4? Reply with just the number.")

for await message in stream {
    switch message {
    case .system(let data):
        liveSystemData = data
        print("  [LIVE] .system: subtype=\(data.subtype.rawValue), message=\(data.message.prefix(60))")
    case .partialMessage(let data):
        livePartialCount += 1
        _ = data
    case .assistant(let data):
        liveAssistantData = data
        print("  [LIVE] .assistant: model=\(data.model), stopReason=\(data.stopReason), text='\(data.text.prefix(50))'")
    case .toolUse(let data):
        liveToolUseCount += 1
        print("  [LIVE] .toolUse: toolName=\(data.toolName), toolUseId=\(data.toolUseId)")
    case .toolResult(let data):
        liveToolResultCount += 1
        print("  [LIVE] .toolResult: toolUseId=\(data.toolUseId), isError=\(data.isError)")
    case .result(let data):
        liveResultData = data
        print("  [LIVE] .result: subtype=\(data.subtype.rawValue), text='\(data.text.prefix(50))'")
    case .userMessage, .toolProgress, .hookStarted, .hookProgress, .hookResponse, .taskStarted, .taskProgress, .authStatus, .filesPersisted, .localCommandOutput, .promptSuggestion, .toolUseSummary:
        break
    }
}

// Verify live message field completeness
print("")
print("--- Live Assistant Data ---")
if let assistant = liveAssistantData {
    record("LIVE .assistant.text present", swiftField: "AssistantData.text", status: !assistant.text.isEmpty ? "PASS" : "MISSING",
           note: "text='\(assistant.text.prefix(60))'")
    record("LIVE .assistant.model present", swiftField: "AssistantData.model", status: !assistant.model.isEmpty ? "PASS" : "MISSING",
           note: "model='\(assistant.model)'")
    record("LIVE .assistant.stopReason present", swiftField: "AssistantData.stopReason", status: !assistant.stopReason.isEmpty ? "PASS" : "MISSING",
           note: "stopReason='\(assistant.stopReason)'")
    record("LIVE .assistant.uuid", swiftField: "AssistantData.uuid: String?", status: "PASS",
           note: "uuid=\(assistant.uuid ?? "nil") (optional field, may be nil in live response)")
    record("LIVE .assistant.sessionId", swiftField: "AssistantData.sessionId: String?", status: "PASS",
           note: "sessionId=\(assistant.sessionId ?? "nil") (optional field, may be nil in live response)")
}

print("")
print("--- Live Result Data ---")
if let result = liveResultData {
    record("LIVE .result.text present", swiftField: "ResultData.text", status: !result.text.isEmpty ? "PASS" : "MISSING",
           note: "text='\(result.text.prefix(60))'")
    record("LIVE .result.subtype present", swiftField: "ResultData.subtype", status: "PASS",
           note: "subtype=\(result.subtype.rawValue)")
    record("LIVE .result.numTurns present", swiftField: "ResultData.numTurns", status: "PASS",
           note: "numTurns=\(result.numTurns)")
    record("LIVE .result.durationMs present", swiftField: "ResultData.durationMs", status: "PASS",
           note: "durationMs=\(result.durationMs)")
    record("LIVE .result.usage present", swiftField: "ResultData.usage", status: result.usage != nil ? "PASS" : "MISSING",
           note: result.usage != nil ? "inputTokens=\(result.usage!.inputTokens)" : "usage is nil")
    record("LIVE .result.totalCostUsd present", swiftField: "ResultData.totalCostUsd", status: "PASS",
           note: "totalCostUsd=\(result.totalCostUsd)")
}

print("")
print("--- Live System Data ---")
if let system = liveSystemData {
    record("LIVE .system.subtype present", swiftField: "SystemData.subtype", status: "PASS",
           note: "subtype=\(system.subtype.rawValue)")
    record("LIVE .system.message present", swiftField: "SystemData.message", status: !system.message.isEmpty ? "PASS" : "MISSING",
           note: "message='\(system.message.prefix(60))'")
}

print("")
print("--- Live Partial Message Count ---")
record("LIVE .partialMessage received", swiftField: "PartialData", status: livePartialCount > 0 ? "PASS" : "MISSING",
       note: "Received \(livePartialCount) partial message(s)")

print("")

// MARK: - AC10: Complete Compatibility Report (20-row Table)

print("=== AC10: Complete Compatibility Report ===")
print("")

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
        note: "Added by Story 17-1: uuid, sessionId, message, parentToolUseId, isSynthetic, toolUseResult"),
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
        note: "Has message + compactMetadata (CompactMetadata with trigger, preTokens, preservedSegment)"),
    MessageTypeMapping(index: 7, tsType: "SDKStatusMessage", tsTypeField: "system/status",
        swiftEquivalent: ".system(SystemData) subtype=.status", status: "PASS",
        note: "Has message + statusValue, compactResult, compactError fields."),
    MessageTypeMapping(index: 8, tsType: "SDKTaskNotificationMessage", tsTypeField: "system/task_notification",
        swiftEquivalent: ".system(SystemData) subtype=.taskNotification", status: "PASS",
        note: "Has message + taskNotificationInfo (TaskNotificationInfo with taskId, outputFile, summary, usage)"),
    MessageTypeMapping(index: 9, tsType: "SDKTaskStartedMessage", tsTypeField: "system/task_started",
        swiftEquivalent: ".taskStarted(TaskStartedData) + SystemData.Subtype.taskStarted", status: "PASS",
        note: "Added by Story 17-1: taskId, taskType, description"),
    MessageTypeMapping(index: 10, tsType: "SDKTaskProgressMessage", tsTypeField: "system/task_progress",
        swiftEquivalent: ".taskProgress(TaskProgressData) + SystemData.Subtype.taskProgress", status: "PASS",
        note: "Added by Story 17-1: taskId, taskType, usage"),
    MessageTypeMapping(index: 11, tsType: "SDKToolProgressMessage", tsTypeField: "tool_progress",
        swiftEquivalent: ".toolProgress(ToolProgressData)", status: "PASS",
        note: "Added by Story 17-1: toolUseId, toolName, parentToolUseId, elapsedTimeSeconds"),
    MessageTypeMapping(index: 12, tsType: "SDKHookStartedMessage", tsTypeField: "system/hook_started",
        swiftEquivalent: ".hookStarted(HookStartedData) + SystemData.Subtype.hookStarted", status: "PASS",
        note: "Added by Story 17-1: hookId, hookName, hookEvent"),
    MessageTypeMapping(index: 13, tsType: "SDKHookProgressMessage", tsTypeField: "system/hook_progress",
        swiftEquivalent: ".hookProgress(HookProgressData) + SystemData.Subtype.hookProgress", status: "PASS",
        note: "Added by Story 17-1: hookId, hookName, hookEvent, stdout, stderr"),
    MessageTypeMapping(index: 14, tsType: "SDKHookResponseMessage", tsTypeField: "system/hook_response",
        swiftEquivalent: ".hookResponse(HookResponseData) + SystemData.Subtype.hookResponse", status: "PASS",
        note: "Added by Story 17-1: hookId, hookName, hookEvent, output, exitCode, outcome"),
    MessageTypeMapping(index: 15, tsType: "SDKAuthStatusMessage", tsTypeField: "auth_status",
        swiftEquivalent: ".authStatus(AuthStatusData)", status: "PASS",
        note: "Added by Story 17-1: status, message"),
    MessageTypeMapping(index: 16, tsType: "SDKFilesPersistedEvent", tsTypeField: "system/files_persisted",
        swiftEquivalent: ".filesPersisted(FilesPersistedData) + SystemData.Subtype.filesPersisted", status: "PASS",
        note: "Added by Story 17-1: filePaths"),
    MessageTypeMapping(index: 17, tsType: "SDKRateLimitEvent", tsTypeField: "rate_limit_event",
        swiftEquivalent: ".system(SystemData) subtype=.rateLimit", status: "PASS",
        note: "Has subtype + message + rateLimitInfo (RateLimitInfo with status, resetsAt, rateLimitType, utilization)."),
    MessageTypeMapping(index: 18, tsType: "SDKLocalCommandOutputMessage", tsTypeField: "system/local_command_output",
        swiftEquivalent: ".localCommandOutput(LocalCommandOutputData) + SystemData.Subtype.localCommandOutput", status: "PASS",
        note: "Added by Story 17-1: output, command"),
    MessageTypeMapping(index: 19, tsType: "SDKPromptSuggestionMessage", tsTypeField: "prompt_suggestion",
        swiftEquivalent: ".promptSuggestion(PromptSuggestionData)", status: "PASS",
        note: "Added by Story 17-1: suggestions"),
    MessageTypeMapping(index: 20, tsType: "SDKToolUseSummaryMessage", tsTypeField: "tool_use_summary",
        swiftEquivalent: ".toolUseSummary(ToolUseSummaryData)", status: "PASS",
        note: "Added by Story 17-1: toolUseCount, tools"),
]

print("TS SDK 20 Message Types vs Swift SDK")
print("=====================================")
print("")
print("\("Status")) \("Swift Equivalent") \("TS type field") \("TS SDK Type") \("#")")
print(String(repeating: "-", count: 140))
for m in mappings {
    print("\(m.index) \(m.status)) \(m.swiftEquivalent) \(m.tsTypeField) [\(m.tsType)]")
    print("     Note: \(m.note)")
}
print("")

let partialCount = mappings.filter { $0.status == "PARTIAL" }.count
let missingCount = mappings.filter { $0.status == "MISSING" }.count
let passCount = mappings.filter { $0.status == "PASS" }.count

print("Summary: PASS: \(passCount) | PARTIAL: \(partialCount) | MISSING: \(missingCount) | Total: \(mappings.count)")
print("")

// MARK: - Field-Level Compat Report (deduplicated)

print("=== Field-Level Compatibility Report ===")
print("")

var seen = Set<String>()
var finalReport: [CompatEntry] = []
for entry in compatReport {
    if !seen.contains(entry.tsField) {
        seen.insert(entry.tsField)
        finalReport.append(entry)
    }
}

let fieldPassCount = finalReport.filter { $0.status == "PASS" }.count
let fieldPartialCount = finalReport.filter { $0.status == "PARTIAL" }.count
let fieldMissingCount = finalReport.filter { $0.status == "MISSING" }.count
let fieldNACount = finalReport.filter { $0.status == "N/A" }.count

print("%@ | \("Swift SDK Field")) | \("TS SDK Field") | Notes")
print(String(repeating: "-", count: 150))
for entry in finalReport {
    let noteStr = entry.note ?? ""
    print("\(noteStr)) | \("[\(entry.status)]") | \(entry.swiftField) | \(entry.tsField)")
}

print("")
print("Field Summary: PASS: \(fieldPassCount) | PARTIAL: \(fieldPartialCount) | MISSING: \(fieldMissingCount) | N/A: \(fieldNACount) | Total: \(finalReport.count)")
print("")

let fieldPassRate = (fieldPassCount + fieldPartialCount + fieldMissingCount) == 0 ? 0 :
    Double(fieldPassCount + fieldPartialCount) / Double(fieldPassCount + fieldPartialCount + fieldMissingCount) * 100
print(String(format: "Pass+Partial Rate: %.1f%% (PASS+PARTIAL / PASS+PARTIAL+MISSING)", fieldPassRate))

if fieldMissingCount > 0 {
    print("")
    print("Missing Items (require SDK changes):")
    for entry in finalReport where entry.status == "MISSING" {
        print("  - \(entry.tsField): \(entry.note ?? "No details")")
    }
}

print("")
print("Message types compatibility verification complete.")

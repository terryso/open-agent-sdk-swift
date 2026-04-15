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

// MARK: - AC1: Build Compilation Verification

print("=== AC1: Build Compilation ===")
print("[PASS] CompatMessageTypes target compiles successfully")
print("")

// MARK: - AC2: SDKAssistantMessage Verification (Static)

print("=== AC2: SDKAssistantMessage Verification ===")

// Verify AssistantData fields at compile time
let assistantData = SDKMessage.AssistantData(text: "Hello", model: "claude-sonnet-4-6", stopReason: "end_turn")
_ = assistantData.text
_ = assistantData.model
_ = assistantData.stopReason

record("SDKAssistantMessage.text", swiftField: "AssistantData.text: String", status: "PASS",
       note: "Maps to TS SDK message.content")
record("SDKAssistantMessage.model", swiftField: "AssistantData.model: String", status: "PASS",
       note: "model='\(assistantData.model)'")
record("SDKAssistantMessage.stopReason", swiftField: "AssistantData.stopReason: String", status: "PASS",
       note: "stopReason='\(assistantData.stopReason)'")

// Known gaps: fields present in TS SDK but missing from Swift
record("SDKAssistantMessage.uuid", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: uuid field for message identification")
record("SDKAssistantMessage.session_id", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: session_id field for session tracking")
record("SDKAssistantMessage.parent_tool_use_id", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: parent_tool_use_id for tool-use chaining context")
record("SDKAssistantMessage.error", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: error field with 7 subtypes (authentication_failed, billing_error, rate_limit, invalid_request, server_error, max_output_tokens, unknown)")

// Use Mirror to verify field count
let assistantMirror = Mirror(reflecting: assistantData)
print("  AssistantData field count: \(assistantMirror.children.count) (TS SDK has 5+ fields)")

print("")

// MARK: - AC3: SDKResultMessage Verification (Static)

print("=== AC3: SDKResultMessage Verification ===")

// Verify ResultData success fields
let successResult = SDKMessage.ResultData(subtype: .success, text: "done", usage: TokenUsage(inputTokens: 100, outputTokens: 50), numTurns: 2, durationMs: 1500, totalCostUsd: 0.05, costBreakdown: [CostBreakdownEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50, costUsd: 0.003)])

record("SDKResultMessage (success).result", swiftField: "ResultData.text: String", status: "PASS",
       note: "text='\(successResult.text)'")
record("SDKResultMessage.total_cost_usd", swiftField: "ResultData.totalCostUsd: Double", status: "PASS",
       note: "totalCostUsd=\(successResult.totalCostUsd)")
record("SDKResultMessage.usage", swiftField: "ResultData.usage: TokenUsage?", status: "PASS",
       note: "inputTokens=\(successResult.usage!.inputTokens), outputTokens=\(successResult.usage!.outputTokens)")
record("SDKResultMessage.model_usage", swiftField: "ResultData.costBreakdown: [CostBreakdownEntry]", status: "PASS",
       note: "Similar to TS model_usage but different naming. count=\(successResult.costBreakdown.count)")
record("SDKResultMessage.num_turns", swiftField: "ResultData.numTurns: Int", status: "PASS",
       note: "numTurns=\(successResult.numTurns)")
record("SDKResultMessage.duration_ms", swiftField: "ResultData.durationMs: Int", status: "PASS",
       note: "durationMs=\(successResult.durationMs)")

// Verify all error subtypes exist at compile time
let allResultSubtypes: [SDKMessage.ResultData.Subtype] = [
    .success, .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd, .cancelled
]
print("  All ResultData.Subtype cases: \(allResultSubtypes.map { $0.rawValue })")

record("SDKResultMessage subtype: success", swiftField: "ResultData.Subtype.success", status: "PASS")
record("SDKResultMessage subtype: error_max_turns", swiftField: "ResultData.Subtype.errorMaxTurns", status: "PASS")
record("SDKResultMessage subtype: error_during_execution", swiftField: "ResultData.Subtype.errorDuringExecution", status: "PASS")
record("SDKResultMessage subtype: error_max_budget_usd", swiftField: "ResultData.Subtype.errorMaxBudgetUsd", status: "PASS")
record("cancelled (Swift-only)", swiftField: "ResultData.Subtype.cancelled", status: "N/A",
       note: "Swift-only addition, not in TS SDK")

// Known gaps
record("SDKResultMessage.structuredOutput", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: structuredOutput for structured output responses")
record("SDKResultMessage.permissionDenials", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: permissionDenials tracking in result")
record("SDKResultMessage.errors", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: errors: string[] for error result details")
record("SDKResultMessage.error_max_structured_output_retries", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: additional error subtype for structured output retry exhaustion")

print("")

// MARK: - AC4: SDKSystemMessage Verification (Static)

print("=== AC4: SDKSystemMessage Verification ===")

// Verify all SystemData subtypes exist at compile time
let allSystemSubtypes: [SDKMessage.SystemData.Subtype] = [
    .`init`, .compactBoundary, .status, .taskNotification, .rateLimit
]
print("  All SystemData.Subtype cases: \(allSystemSubtypes.map { $0.rawValue })")

record("SDKSystemMessage(init)", swiftField: ".system(SystemData) subtype=.init", status: "PARTIAL",
       note: "Has message. MISSING: session_id, tools, model, permissionMode, mcp_servers, cwd")
record("SDKSystemMessage(compact_boundary)", swiftField: ".system(SystemData) subtype=.compactBoundary", status: "PARTIAL",
       note: "Has message. MISSING: compact_metadata")
record("SDKSystemMessage(status)", swiftField: ".system(SystemData) subtype=.status", status: "PARTIAL",
       note: "Has message. MISSING: permissionMode")
record("SDKSystemMessage(task_notification)", swiftField: ".system(SystemData) subtype=.taskNotification", status: "PARTIAL",
       note: "Has message. MISSING: task_id, output_file, summary, usage")
record("SDKRateLimitEvent", swiftField: ".system(SystemData) subtype=.rateLimit", status: "PARTIAL",
       note: "Has subtype + message. MISSING: rate limit-specific fields (limit, remaining, reset)")

// Missing system subtypes
record("SDKSystemMessage(task_started)", swiftField: "No subtype", status: "MISSING",
       note: "TS SDK: system/task_started with task_id, task_type, description")
record("SDKSystemMessage(task_progress)", swiftField: "No subtype", status: "MISSING",
       note: "TS SDK: system/task_progress with task_id, usage")
record("SDKSystemMessage(hook_started)", swiftField: "No subtype", status: "MISSING",
       note: "TS SDK: system/hook_started with hook_id, hook_name, hook_event")
record("SDKSystemMessage(hook_progress)", swiftField: "No subtype", status: "MISSING",
       note: "TS SDK: system/hook_progress with hook_id, stdout, stderr")
record("SDKSystemMessage(hook_response)", swiftField: "No subtype", status: "MISSING",
       note: "TS SDK: system/hook_response with hook_id, output, exit_code, outcome")
record("SDKSystemMessage(files_persisted)", swiftField: "No subtype", status: "MISSING",
       note: "TS SDK: system/files_persisted")
record("SDKSystemMessage(local_command_output)", swiftField: "No subtype", status: "MISSING",
       note: "TS SDK: system/local_command_output")

print("")

// MARK: - AC5: SDKPartialAssistantMessage Verification (Static)

print("=== AC5: SDKPartialAssistantMessage Verification ===")

let partialData = SDKMessage.PartialData(text: "Hello world")
_ = partialData.text

record("SDKPartialAssistantMessage.text", swiftField: "PartialData.text: String", status: "PASS",
       note: "Provides streaming text chunks")

// Known gaps
record("SDKPartialAssistantMessage.parent_tool_use_id", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: parent_tool_use_id for nested tool-use context")
record("SDKPartialAssistantMessage.uuid", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: uuid for message identification")
record("SDKPartialAssistantMessage.session_id", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: session_id for session tracking")

let partialMirror = Mirror(reflecting: partialData)
print("  PartialData field count: \(partialMirror.children.count) (TS SDK has 5 fields)")

print("")

// MARK: - AC6: Tool Progress Message Verification

print("=== AC6: Tool Progress Message Verification ===")

record("SDKToolProgressMessage (entire type)", swiftField: "No SDKMessage case", status: "MISSING",
       note: "TS SDK: tool_use_id, tool_name, parent_tool_use_id, elapsed_time_seconds. Swift has no equivalent.")
record("SDKToolProgressMessage.tool_use_id", swiftField: "N/A", status: "MISSING",
       note: "Field missing because entire type is absent")
record("SDKToolProgressMessage.tool_name", swiftField: "N/A", status: "MISSING",
       note: "Field missing because entire type is absent")
record("SDKToolProgressMessage.elapsed_time_seconds", swiftField: "N/A", status: "MISSING",
       note: "Field missing because entire type is absent")

print("")

// MARK: - AC7: Hook-Related Message Verification

print("=== AC7: Hook-Related Message Verification ===")

record("SDKHookStartedMessage (entire type)", swiftField: "No SystemData subtype", status: "MISSING",
       note: "TS SDK: hook_id, hook_name, hook_event. Swift has no equivalent.")
record("SDKHookProgressMessage (entire type)", swiftField: "No SystemData subtype", status: "MISSING",
       note: "TS SDK: hook_id, stdout, stderr. Swift has no equivalent.")
record("SDKHookResponseMessage (entire type)", swiftField: "No SystemData subtype", status: "MISSING",
       note: "TS SDK: hook_id, output, exit_code, outcome. Swift has no equivalent.")

print("")

// MARK: - AC8: Task-Related Message Verification

print("=== AC8: Task-Related Message Verification ===")

record("SDKTaskStartedMessage (entire type)", swiftField: "No SystemData subtype", status: "MISSING",
       note: "TS SDK: task_id, task_type, description. Swift has no equivalent.")
record("SDKTaskProgressMessage (entire type)", swiftField: "No SystemData subtype", status: "MISSING",
       note: "TS SDK: task_id, usage. Swift has no equivalent.")
record("SDKTaskNotificationMessage", swiftField: ".system(SystemData) subtype=.taskNotification", status: "PARTIAL",
       note: "Type exists but missing typed fields: task_id, output_file, summary, usage")

print("")

// MARK: - AC9: Other Message Type Verification

print("=== AC9: Other Message Type Verification ===")

record("SDKUserMessage (entire type)", swiftField: "No SDKMessage case", status: "MISSING",
       note: "TS SDK: user message type. Swift has no equivalent.")
record("SDKAuthStatusMessage (entire type)", swiftField: "No SDKMessage case", status: "MISSING",
       note: "TS SDK: auth_status message type. Swift has no equivalent.")
record("SDKFilesPersistedEvent (entire type)", swiftField: "No SystemData subtype", status: "MISSING",
       note: "TS SDK: system/files_persisted. Swift has no equivalent.")
record("SDKPromptSuggestionMessage (entire type)", swiftField: "No SDKMessage case", status: "MISSING",
       note: "TS SDK: prompt_suggestion message type. Swift has no equivalent.")
record("SDKToolUseSummaryMessage (entire type)", swiftField: "No SDKMessage case", status: "MISSING",
       note: "TS SDK: tool_use_summary message type. Swift has no equivalent.")
record("SDKLocalCommandOutputMessage (entire type)", swiftField: "No SystemData subtype", status: "MISSING",
       note: "TS SDK: system/local_command_output. Swift has no equivalent.")

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

print("TS SDK 20 Message Types vs Swift SDK")
print("=====================================")
print("")
print(String(format: "%-2s %-35s %-25s %-45s %-8s", "#", "TS SDK Type", "TS type field", "Swift Equivalent", "Status"))
print(String(repeating: "-", count: 140))
for m in mappings {
    print(String(format: "%-2d %-35s %-25s %-45s [%-7s]", m.index, m.tsType, m.tsTypeField, m.swiftEquivalent, m.status))
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

print(String(format: "%-50s | %-55s | %-8s | Notes", "TS SDK Field", "Swift SDK Field"))
print(String(repeating: "-", count: 150))
for entry in finalReport {
    let noteStr = entry.note ?? ""
    print(String(format: "%-50s | %-55s | %-8s | %@", entry.tsField, entry.swiftField, "[\(entry.status)]", noteStr))
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

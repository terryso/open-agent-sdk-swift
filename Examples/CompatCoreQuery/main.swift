// CompatCoreQuery 示例 / Core Query API Compatibility Verification Example
//
// 验证 Swift SDK 的 query() 等效 API 是否与 TypeScript SDK 的核心用法模式完全兼容。
// Verifies Swift SDK's query()-equivalent API is fully compatible with the TypeScript SDK's
// core usage patterns.
//
// 运行方式 / Run: swift run CompatCoreQuery
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
    let status: String  // "PASS", "MISSING", "N/A"
    let note: String?
}

nonisolated(unsafe) var compatReport: [CompatEntry] = []

func record(_ tsField: String, swiftField: String, status: String, note: String? = nil) {
    compatReport.append(CompatEntry(tsField: tsField, swiftField: swiftField, status: status, note: note))
    let statusStr = status == "PASS" ? "[PASS]" : status == "MISSING" ? "[MISSING]" : "[N/A]"
    print("  \(statusStr) TS: \(tsField) -> Swift: \(swiftField)\(note.map { " (\($0))" } ?? "")")
}

// MARK: - AC1: Build Compilation Verification

print("=== AC1: Build Compilation ===")
print("[PASS] CompatCoreQuery target compiles successfully")
print("")

// MARK: - AC2 & AC4: Streaming Query + System Init Verification

print("=== AC2: Basic Streaming Query Verification ===")

let streamAgent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: baseURL,
    provider: defaultProvider,
    systemPrompt: "You are a helpful assistant. Be concise.",
    maxTurns: 3,
    permissionMode: .bypassPermissions
))

var streamedResultData: SDKMessage.ResultData?
var streamedAssistantData: SDKMessage.AssistantData?
var streamedSystemData: SDKMessage.SystemData?

let stream = streamAgent.stream("What is 2+2? Reply with just the number.")

for await message in stream {
    switch message {
    case .system(let data):
        streamedSystemData = data
        print("  Received .system message: subtype=\(data.subtype.rawValue), message=\(data.message)")
    case .partialMessage(let data):
        // Streaming partial text -- no verification needed per event
        _ = data
    case .assistant(let data):
        streamedAssistantData = data
        print("  Received .assistant: model=\(data.model), stopReason=\(data.stopReason)")
    case .toolUse(let data):
        print("  Received .toolUse: \(data.toolName)")
    case .toolResult(let data):
        print("  Received .toolResult: isError=\(data.isError)")
    case .result(let data):
        streamedResultData = data
        print("  Received .result: subtype=\(data.subtype.rawValue), text=\(data.text)")
    }
}

// Verify streaming result fields
print("")
print("--- AC2: Streaming Result Field Verification ---")

if let result = streamedResultData {
    record("query() streaming", swiftField: "agent.stream() -> AsyncStream<SDKMessage>", status: "PASS")

    let hasText = !result.text.isEmpty
    record("result (text)", swiftField: "ResultData.text", status: hasText ? "PASS" : "MISSING",
           note: hasText ? "text='\(result.text.prefix(50))'" : "text is empty")

    let hasUsage = result.usage != nil
    record("usage", swiftField: "ResultData.usage (TokenUsage)", status: hasUsage ? "PASS" : "MISSING",
           note: hasUsage ? "inputTokens=\(result.usage!.inputTokens), outputTokens=\(result.usage!.outputTokens)" : "usage is nil")

    record("num_turns", swiftField: "ResultData.numTurns", status: "PASS",
           note: "numTurns=\(result.numTurns)")

    record("duration_ms", swiftField: "ResultData.durationMs", status: "PASS",
           note: "durationMs=\(result.durationMs)")

    record("total_cost_usd", swiftField: "ResultData.totalCostUsd", status: "PASS",
           note: "totalCostUsd=\(result.totalCostUsd)")

    let hasCostBreakdown = !result.costBreakdown.isEmpty
    record("model_usage", swiftField: "ResultData.costBreakdown ([CostBreakdownEntry])", status: hasCostBreakdown ? "PASS" : "MISSING",
           note: hasCostBreakdown ? "\(result.costBreakdown.count) model(s)" : "costBreakdown is empty")
} else {
    record("streaming result", swiftField: "ResultData", status: "MISSING", note: "No .result message received")
}

// Verify assistant data fields
print("")
print("--- AC2: Assistant Data Verification ---")

if let assistant = streamedAssistantData {
    record("stop_reason", swiftField: "AssistantData.stopReason", status: "PASS",
           note: "stopReason='\(assistant.stopReason)'")

    let hasModel = !assistant.model.isEmpty
    record("model (on AssistantData)", swiftField: "AssistantData.model", status: hasModel ? "PASS" : "MISSING",
           note: "model='\(assistant.model)'")
}

// Verify system init data (AC4)
print("")
print("--- AC4: System Init Message Verification ---")

if let systemData = streamedSystemData, systemData.subtype == .`init` {
    record("SDKSystemMessage.subtype init", swiftField: "SystemData.Subtype.init", status: "PASS")

    let hasMessage = !systemData.message.isEmpty
    record("SDKSystemMessage message", swiftField: "SystemData.message", status: hasMessage ? "PASS" : "MISSING",
           note: "message='\(systemData.message)'")

    // Known gaps: SystemData does not expose session_id, tools, model as typed fields
    record("session_id", swiftField: "Not exposed on SystemData", status: "MISSING",
           note: "TS SDK: SDKSystemMessage(init) includes session_id. Swift: embedded in message string")
    record("tools", swiftField: "Not exposed on SystemData", status: "MISSING",
           note: "TS SDK: SDKSystemMessage(init) includes tools: Tool[]. Swift: not available")
    record("model (on SystemData)", swiftField: "Not exposed on SystemData", status: "MISSING",
           note: "TS SDK: SDKSystemMessage(init) includes model. Swift: not available on SystemData")
} else {
    record("SystemData init", swiftField: "SystemData", status: "MISSING",
           note: "No .system(.init) message received in stream")
}

// MARK: - AC3: Blocking Query Verification

print("")
print("=== AC3: Blocking Query Verification ===")

let blockingAgent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: baseURL,
    provider: defaultProvider,
    systemPrompt: "You are a helpful assistant. Be concise.",
    maxTurns: 3,
    permissionMode: .bypassPermissions
))

let blockingResult = await blockingAgent.prompt("What is the capital of France? Reply with just the city name.")

print("  Blocking response: '\(blockingResult.text)'")

record("query() blocking", swiftField: "agent.prompt() -> QueryResult", status: "PASS")

let hasText = !blockingResult.text.isEmpty
record("result (text)", swiftField: "QueryResult.text", status: hasText ? "PASS" : "MISSING")

record("status", swiftField: "QueryResult.status (QueryStatus)", status: "PASS",
       note: "status=\(blockingResult.status.rawValue)")

let hasUsage = blockingResult.usage.inputTokens > 0 || blockingResult.usage.outputTokens > 0
record("usage", swiftField: "QueryResult.usage (TokenUsage)", status: hasUsage ? "PASS" : "MISSING",
       note: "inputTokens=\(blockingResult.usage.inputTokens), outputTokens=\(blockingResult.usage.outputTokens)")

record("num_turns", swiftField: "QueryResult.numTurns", status: "PASS",
       note: "numTurns=\(blockingResult.numTurns)")

record("duration_ms", swiftField: "QueryResult.durationMs", status: "PASS",
       note: "durationMs=\(blockingResult.durationMs)")

record("total_cost_usd", swiftField: "QueryResult.totalCostUsd", status: "PASS",
       note: "totalCostUsd=\(blockingResult.totalCostUsd)")

let hasCostBreakdown = !blockingResult.costBreakdown.isEmpty
record("model_usage", swiftField: "QueryResult.costBreakdown ([CostBreakdownEntry])", status: hasCostBreakdown ? "PASS" : "MISSING",
       note: hasCostBreakdown ? "\(blockingResult.costBreakdown.count) model(s)" : "costBreakdown is empty")

record("isCancelled", swiftField: "QueryResult.isCancelled", status: "N/A",
       note: "Swift-only addition, not in TS SDK")

// TokenUsage cache fields
let hasCacheCreation = blockingResult.usage.cacheCreationInputTokens != nil
record("cache_creation_input_tokens", swiftField: "TokenUsage.cacheCreationInputTokens",
       status: hasCacheCreation ? "PASS" : "MISSING",
       note: hasCacheCreation ? "value=\(blockingResult.usage.cacheCreationInputTokens!)" : "nil (may not be returned by API)")

let hasCacheRead = blockingResult.usage.cacheReadInputTokens != nil
record("cache_read_input_tokens", swiftField: "TokenUsage.cacheReadInputTokens",
       status: hasCacheRead ? "PASS" : "MISSING",
       note: hasCacheRead ? "value=\(blockingResult.usage.cacheReadInputTokens!)" : "nil (may not be returned by API)")

// MARK: - AC5: Multi-turn Query Verification

print("")
print("=== AC5: Multi-turn Query Verification ===")

let multiTurnAgent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: baseURL,
    provider: defaultProvider,
    systemPrompt: "You are a helpful assistant. Be very concise. Just answer the question directly.",
    maxTurns: 3,
    permissionMode: .bypassPermissions
))

let turn1 = await multiTurnAgent.prompt("My name is Nick and my favorite color is blue. Just acknowledge with 'OK'.")
print("  Turn 1 response: '\(turn1.text)'")

let turn2 = await multiTurnAgent.prompt("What is my name and favorite color?")
print("  Turn 2 response: '\(turn2.text)'")

let remembersName = turn2.text.localizedCaseInsensitiveContains("Nick")
let remembersColor = turn2.text.localizedCaseInsensitiveContains("blue")
let multiTurnPass = remembersName && remembersColor

record("multi-turn context retention", swiftField: "Same Agent instance, consecutive prompt() calls",
       status: multiTurnPass ? "PASS" : "MISSING",
       note: multiTurnPass ? "Agent correctly remembers context across turns" :
           "name=\(remembersName), color=\(remembersColor)")

// MARK: - AC6: Query Interrupt Verification

print("")
print("=== AC6: Query Interrupt Verification ===")

let interruptAgent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: baseURL,
    provider: defaultProvider,
    systemPrompt: "You are a helpful assistant. When asked to count, count each number carefully.",
    maxTurns: 10,
    permissionMode: .bypassPermissions
))

var interruptResultData: SDKMessage.ResultData?

let interruptTask = _Concurrency.Task {
    let interruptStream = interruptAgent.stream("Count from 1 to 100, explaining each number in detail.")
    for await message in interruptStream {
        switch message {
        case .result(let data):
            interruptResultData = data
        default:
            break
        }
    }
}

// Wait briefly then cancel
try? await _Concurrency.Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
interruptTask.cancel()

// Wait for task to complete
let _ = await interruptTask.value

if let cancelledResult = interruptResultData {
    let isCancelled = cancelledResult.subtype == .cancelled
    record("AbortController.abort()", swiftField: "Task.cancel() / Agent.interrupt()", status: "PASS")
    record("cancelled subtype", swiftField: "ResultData.Subtype.cancelled",
           status: isCancelled ? "PASS" : "MISSING",
           note: "subtype=\(cancelledResult.subtype.rawValue)")
} else {
    record("interrupt result", swiftField: "ResultData", status: "MISSING",
           note: "No .result received before/after cancel")
}

// MARK: - AC7: Error Subtype Verification

print("")
print("=== AC7: Error Subtype Verification ===")

// Verify all subtype enum cases exist at compile time
let allSubtypes: [SDKMessage.ResultData.Subtype] = [
    .success, .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd, .cancelled
]
print("  All subtype cases compiled: \(allSubtypes.map { $0.rawValue })")

record("subtype: success", swiftField: "ResultData.Subtype.success", status: "PASS")
record("subtype: error_max_turns", swiftField: "ResultData.Subtype.errorMaxTurns", status: "PASS",
       note: "Swift rawValue uses camelCase")
record("subtype: error_during_execution", swiftField: "ResultData.Subtype.errorDuringExecution", status: "PASS",
       note: "Swift rawValue uses camelCase")
record("subtype: error_max_budget_usd", swiftField: "ResultData.Subtype.errorMaxBudgetUsd", status: "PASS",
       note: "Swift rawValue uses camelCase")
record("cancelled (Swift-only)", swiftField: "ResultData.Subtype.cancelled", status: "N/A",
       note: "Swift-only addition, not in TS SDK")

// Verify errorMaxTurns with maxTurns=1
let maxTurnsAgent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: baseURL,
    provider: defaultProvider,
    systemPrompt: "You are a helpful assistant.",
    maxTurns: 1,
    permissionMode: .bypassPermissions
))

let maxTurnsResult = await maxTurnsAgent.prompt("Read the file at /tmp/test_compat_file.txt and tell me its contents.")
// If the agent doesn't use tools, it may complete in 1 turn with success.
// The errorMaxTurns case occurs when tools are used and the loop hits maxTurns.
print("  maxTurns=1 result: status=\(maxTurnsResult.status.rawValue)")

// Verify errorMaxBudgetUsd with very low budget
let budgetAgent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: baseURL,
    provider: defaultProvider,
    systemPrompt: "You are a helpful assistant. Be very verbose.",
    maxTurns: 10,
    maxBudgetUsd: 0.0001,
    permissionMode: .bypassPermissions
))

let budgetResult = await budgetAgent.prompt("Explain quantum physics in great detail.")
let budgetHit = budgetResult.status == QueryStatus.errorMaxBudgetUsd
print("  maxBudgetUsd=0.0001 result: status=\(budgetResult.status.rawValue)")

if budgetHit {
    record("errorMaxBudgetUsd triggered", swiftField: "QueryStatus.errorMaxBudgetUsd", status: "PASS",
           note: "Budget limit correctly enforced")
} else {
    record("errorMaxBudgetUsd triggered", swiftField: "QueryStatus.errorMaxBudgetUsd", status: "MISSING",
           note: "Budget not exceeded with 0.0001 USD limit")
}

// Known gaps for error results
record("errors: [String]", swiftField: "Not exposed on ResultData/QueryResult", status: "MISSING",
       note: "TS SDK error results include errors: string[] for details")

// MARK: - Known Gaps Documentation

print("")
print("=== Known Gaps Documentation ===")

record("structuredOutput", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: SDKResultMessage includes structuredOutput. Swift: no equivalent")
record("permissionDenials", swiftField: "Not available", status: "MISSING",
       note: "TS SDK: SDKResultMessage includes permissionDenials. Swift: no equivalent")
record("durationApiMs", swiftField: "Not separate (merged into durationMs)", status: "MISSING",
       note: "TS SDK has separate durationApiMs. Swift only has durationMs (total wall-clock)")
record("AsyncIterable input", swiftField: "agent.stream() accepts String only", status: "MISSING",
       note: "TS SDK supports prompt: string | AsyncIterable<SDKUserMessage>")

// MARK: - AC8: Compatibility Report

print("")
print("=== AC8: Compatibility Report ===")
print("")

// Deduplicate entries for final report
var seen = Set<String>()
var finalReport: [CompatEntry] = []
for entry in compatReport {
    if !seen.contains(entry.tsField) {
        seen.insert(entry.tsField)
        finalReport.append(entry)
    }
}

let passCount = finalReport.filter { $0.status == "PASS" }.count
let missingCount = finalReport.filter { $0.status == "MISSING" }.count
let naCount = finalReport.filter { $0.status == "N/A" }.count

print("Core Query API Compatibility Report")
print("====================================")
print("")

print(String(format: "%-35s | %-50s | %-8s | Notes", "TS SDK Field", "Swift SDK Field"))
print(String(repeating: "-", count: 130))
for entry in finalReport {
    let noteStr = entry.note ?? ""
    print(String(format: "%-35s | %-50s | %-8s | %@", entry.tsField, entry.swiftField, "[\(entry.status)]", noteStr))
}

print("")
print("Summary: PASS: \(passCount) | MISSING: \(missingCount) | N/A: \(naCount) | Total: \(finalReport.count)")
print("")

let passRate = finalReport.isEmpty ? 0 : Double(passCount) / Double(passCount + missingCount) * 100
print(String(format: "Pass Rate (excluding N/A): %.1f%%", passRate))

if missingCount > 0 {
    print("")
    print("Missing Fields (require SDK changes):")
    for entry in finalReport where entry.status == "MISSING" {
        print("  - \(entry.tsField): \(entry.note ?? "No details")")
    }
}

print("")
print("Compatibility verification complete.")

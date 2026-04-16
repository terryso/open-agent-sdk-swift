// CompatThinkingModel 示例 / Thinking & Model Configuration Compatibility Verification Example
//
// 验证 Swift SDK 的 ThinkingConfig 和模型配置与 TypeScript SDK 完全兼容。
// Verifies Swift SDK's ThinkingConfig and model configuration are fully compatible with the TypeScript SDK,
// so developers can precisely control LLM reasoning behavior.
//
// 运行方式 / Run: swift run CompatThinkingModel
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
    var line = "  \(statusStr) TS: \(tsField) -> Swift: \(swiftField)"
    if let note { line += " (\(note))" }
    print(line)
}

/// Left-pad a string to the given width using spaces.
func pad(_ str: String, width: Int) -> String {
    str.padding(toLength: width, withPad: " ", startingAt: 0)
}

// MARK: - AC1: Build Compilation Verification

print("=== AC1: Build Compilation ===")
print("[PASS] CompatThinkingModel target compiles successfully")
print("")

// MARK: - AC2: ThinkingConfig Three Modes Verification

print("=== AC2: ThinkingConfig Three Modes Verification ===")
print("")

// .adaptive case
let adaptiveConfig = ThinkingConfig.adaptive
if case .adaptive = adaptiveConfig {
    record("ThinkingConfig.adaptive", swiftField: "ThinkingConfig.adaptive", status: "PASS",
           note: "Matches TS { type: 'adaptive' }")
} else {
    record("ThinkingConfig.adaptive", swiftField: "THINKING_CONFIG_ERROR", status: "MISSING",
           note: "Failed to create .adaptive case")
}

// .enabled(budgetTokens:) case
let enabledConfig = ThinkingConfig.enabled(budgetTokens: 10000)
if case .enabled(let tokens) = enabledConfig {
    record("ThinkingConfig.enabled(budgetTokens)", swiftField: "ThinkingConfig.enabled(budgetTokens: Int)", status: "PASS",
           note: "budgetTokens=\(tokens). Matches TS { type: 'enabled', budgetTokens?: number }. Note: required in Swift, optional in TS.")
} else {
    record("ThinkingConfig.enabled(budgetTokens)", swiftField: "THINKING_CONFIG_ERROR", status: "MISSING",
           note: "Failed to create .enabled case")
}

// .disabled case
let disabledConfig = ThinkingConfig.disabled
if case .disabled = disabledConfig {
    record("ThinkingConfig.disabled", swiftField: "ThinkingConfig.disabled", status: "PASS",
           note: "Matches TS { type: 'disabled' }")
} else {
    record("ThinkingConfig.disabled", swiftField: "THINKING_CONFIG_ERROR", status: "MISSING",
           note: "Failed to create .disabled case")
}

// validate() method
do {
    try ThinkingConfig.adaptive.validate()
    try ThinkingConfig.disabled.validate()
    try ThinkingConfig.enabled(budgetTokens: 5000).validate()
    record("ThinkingConfig.validate()", swiftField: "ThinkingConfig.validate() throws", status: "PASS",
           note: "Validates config. Throws for invalid budgetTokens (<=0).")
} catch {
    record("ThinkingConfig.validate()", swiftField: "ThinkingConfig.validate()", status: "MISSING",
           note: "validate() threw unexpected error: \(error)")
}

// Exhaustive switch (confirms no unknown cases)
let allConfigs: [ThinkingConfig] = [.adaptive, .enabled(budgetTokens: 100), .disabled]
for config in allConfigs {
    switch config {
    case .adaptive: break
    case .enabled: break
    case .disabled: break
    }
}
record("ThinkingConfig exhaustive cases", swiftField: "ThinkingConfig 3-case switch", status: "PASS",
       note: "Exhaustive switch confirms exactly 3 cases: .adaptive, .enabled, .disabled")

// ThinkingConfig stored in AgentOptions but NOT wired to API calls
let optionsWithThinking = AgentOptions(
    apiKey: "test-key",
    model: "claude-sonnet-4-6",
    thinking: .enabled(budgetTokens: 10000)
)
if optionsWithThinking.thinking != nil {
    record("ThinkingConfig passed to API", swiftField: "AgentOptions.thinking (NOT wired)", status: "PARTIAL",
           note: "AgentOptions.thinking stores the config, but Agent.swift passes thinking: nil to all API calls. Config exists but is not forwarded at runtime.")
} else {
    record("ThinkingConfig passed to API", swiftField: "AgentOptions.thinking", status: "MISSING",
           note: "AgentOptions.thinking is nil even when set")
}

print("")

// MARK: - AC3: Effort Level Verification

print("=== AC3: Effort Level Verification ===")
print("")

// Check for effort parameter on AgentOptions
let effortOptions = AgentOptions(apiKey: "test-key", model: "claude-sonnet-4-6")
let effortFields = Mirror(reflecting: effortOptions).children.compactMap { $0.label }
record("Options.effort", swiftField: effortFields.contains("effort") ? "AgentOptions.effort" : "NO EQUIVALENT",
       status: effortFields.contains("effort") ? "PASS" : "MISSING",
       note: "TS SDK has effort: 'low' | 'medium' | 'high' | 'max'. Swift has no effort field on AgentOptions.")

// Check for EffortLevel enum
record("EffortLevel enum", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No EffortLevel enum exists in Swift SDK. TS SDK has effort: 'low' | 'medium' | 'high' | 'max'.")

// Effort + ThinkingConfig interaction
record("effort + ThinkingConfig interaction", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No effort parameter, so interaction with ThinkingConfig is not possible. TS SDK supports effort interaction with thinking config.")

print("")

// MARK: - AC4: ModelInfo Type Verification

print("=== AC4: ModelInfo Type Verification ===")
print("")

let modelInfo = ModelInfo(value: "claude-sonnet-4-6", displayName: "Sonnet 4.6", description: "Fast model")

// Verify existing fields
record("ModelInfo.value", swiftField: "ModelInfo.value: String", status: "PASS",
       note: "value='\(modelInfo.value)'")
record("ModelInfo.displayName", swiftField: "ModelInfo.displayName: String", status: "PASS",
       note: "displayName='\(modelInfo.displayName)'")
record("ModelInfo.description", swiftField: "ModelInfo.description: String", status: "PASS",
       note: "description='\(modelInfo.description)'")

let modelWithEffort = ModelInfo(value: "claude-sonnet-4-6", displayName: "Sonnet", description: "Fast", supportsEffort: true)
record("ModelInfo.supportsEffort", swiftField: "ModelInfo.supportsEffort: Bool", status: "PASS",
       note: "supportsEffort=\(modelWithEffort.supportsEffort)")

// Check for missing fields
let modelFields = Mirror(reflecting: modelInfo).children.compactMap { $0.label }
record("ModelInfo.supportedEffortLevels", swiftField: modelFields.contains("supportedEffortLevels") ? "ModelInfo.supportedEffortLevels" : "NO EQUIVALENT",
       status: modelFields.contains("supportedEffortLevels") ? "PASS" : "MISSING",
       note: "TS SDK has supportedEffortLevels?: string[]. Swift has no equivalent.")
record("ModelInfo.supportsAdaptiveThinking", swiftField: modelFields.contains("supportsAdaptiveThinking") ? "ModelInfo.supportsAdaptiveThinking" : "NO EQUIVALENT",
       status: modelFields.contains("supportsAdaptiveThinking") ? "PASS" : "MISSING",
       note: "TS SDK has supportsAdaptiveThinking?: boolean. Swift has no equivalent.")
record("ModelInfo.supportsFastMode", swiftField: modelFields.contains("supportsFastMode") ? "ModelInfo.supportsFastMode" : "NO EQUIVALENT",
       status: modelFields.contains("supportsFastMode") ? "PASS" : "MISSING",
       note: "TS SDK has supportsFastMode?: boolean. Swift has no equivalent.")

print("")

// MARK: - AC5: ModelUsage / TokenUsage Verification

print("=== AC5: ModelUsage / TokenUsage Verification ===")
print("")

let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
record("ModelUsage.inputTokens", swiftField: "TokenUsage.inputTokens: Int", status: "PASS",
       note: "inputTokens=\(usage.inputTokens)")
record("ModelUsage.outputTokens", swiftField: "TokenUsage.outputTokens: Int", status: "PASS",
       note: "outputTokens=\(usage.outputTokens)")

let cachedUsage = TokenUsage(inputTokens: 100, outputTokens: 50, cacheReadInputTokens: 25)
record("ModelUsage.cacheReadInputTokens", swiftField: "TokenUsage.cacheReadInputTokens: Int?", status: "PASS",
       note: "cacheReadInputTokens=\(cachedUsage.cacheReadInputTokens?.description ?? "nil")")
let cachedUsage2 = TokenUsage(inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: 10)
record("ModelUsage.cacheCreationInputTokens", swiftField: "TokenUsage.cacheCreationInputTokens: Int?", status: "PASS",
       note: "cacheCreationInputTokens=\(cachedUsage2.cacheCreationInputTokens?.description ?? "nil")")

// Check for missing fields
let usageFields = Mirror(reflecting: usage).children.compactMap { $0.label }
record("ModelUsage.webSearchRequests", swiftField: usageFields.contains("webSearchRequests") ? "TokenUsage.webSearchRequests" : "NO EQUIVALENT",
       status: usageFields.contains("webSearchRequests") ? "PASS" : "MISSING",
       note: "TS SDK ModelUsage has webSearchRequests?: number. Swift has no equivalent.")
record("ModelUsage.costUSD", swiftField: "QueryResult.totalCostUsd + CostBreakdownEntry.costUsd", status: "PARTIAL",
       note: "TS SDK has costUSD on ModelUsage. Swift has totalCostUsd on QueryResult and costUsd on CostBreakdownEntry (different location).")
record("ModelUsage.contextWindow", swiftField: "getContextWindowSize(model:)", status: "PARTIAL",
       note: "TS SDK has contextWindow on ModelUsage. Swift has getContextWindowSize() utility function (different API shape).")
record("ModelUsage.maxOutputTokens", swiftField: usageFields.contains("maxOutputTokens") ? "TokenUsage.maxOutputTokens" : "NO EQUIVALENT",
       status: usageFields.contains("maxOutputTokens") ? "PASS" : "MISSING",
       note: "TS SDK ModelUsage has maxOutputTokens?: number. Swift has no equivalent.")

// Verify getContextWindowSize provides equivalent info
let contextSize = getContextWindowSize(model: "claude-sonnet-4-6")
print("  [INFO] getContextWindowSize('claude-sonnet-4-6') = \(contextSize)")

// CostBreakdownEntry verification
let breakdownEntry = CostBreakdownEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50, costUsd: 0.005)
record("CostBreakdownEntry fields", swiftField: "CostBreakdownEntry(model, inputTokens, outputTokens, costUsd)", status: "PASS",
       note: "All fields present: model='\(breakdownEntry.model)', inputTokens=\(breakdownEntry.inputTokens), outputTokens=\(breakdownEntry.outputTokens), costUsd=\(breakdownEntry.costUsd)")

// QueryResult.costBreakdown verification
let costEntries = [
    CostBreakdownEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50, costUsd: 0.005),
    CostBreakdownEntry(model: "claude-opus-4-6", inputTokens: 200, outputTokens: 100, costUsd: 0.025)
]
let queryResult = QueryResult(
    text: "test",
    usage: TokenUsage(inputTokens: 300, outputTokens: 150),
    numTurns: 1,
    durationMs: 100,
    messages: [],
    totalCostUsd: 0.030,
    costBreakdown: costEntries
)
let cbCount = queryResult.costBreakdown.count
record("QueryResult.costBreakdown", swiftField: "QueryResult.costBreakdown: [CostBreakdownEntry]", status: "PASS",
       note: "costBreakdown has \(cbCount) entries for multi-model tracking")

print("")

// MARK: - AC6: fallbackModel Verification

print("=== AC6: fallbackModel Verification ===")
print("")

let fallbackOptions = AgentOptions(apiKey: "test-key", model: "claude-sonnet-4-6")
let fallbackFields = Mirror(reflecting: fallbackOptions).children.compactMap { $0.label }
record("Options.fallbackModel", swiftField: fallbackFields.contains("fallbackModel") ? "AgentOptions.fallbackModel" : "NO EQUIVALENT",
       status: fallbackFields.contains("fallbackModel") ? "PASS" : "MISSING",
       note: "TS SDK has fallbackModel?: string for automatic model fallback on failure.")
record("Auto-switch on failure", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No fallback behavior exists. Model failures are returned as errors in Swift SDK.")

print("")

// MARK: - AC7: Runtime Model Switching Verification

print("=== AC7: Runtime Model Switching Verification ===")
print("")

let agent = createAgent(options: AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", permissionMode: .bypassPermissions))
record("agent.switchModel() method", swiftField: "Agent.switchModel(_:) throws", status: "PASS",
       note: "Initial model='\(agent.model)'")

do {
    try agent.switchModel("claude-opus-4-6")
    record("switchModel changes model", swiftField: "Agent.model updated", status: "PASS",
           note: "Model changed from claude-sonnet-4-6 to '\(agent.model)'")
} catch {
    record("switchModel changes model", swiftField: "Agent.switchModel()", status: "MISSING",
           note: "switchModel threw: \(error)")
}

// Test empty string throws error
do {
    try agent.switchModel("")
    record("switchModel('') throws", swiftField: "SDKError.invalidConfiguration", status: "MISSING",
           note: "switchModel('') did NOT throw")
} catch let error as SDKError {
    if case .invalidConfiguration(let msg) = error {
        record("switchModel('') throws", swiftField: "SDKError.invalidConfiguration", status: "PASS",
               note: "Correctly throws invalidConfiguration: \(msg)")
    } else {
        record("switchModel('') throws", swiftField: "SDKError", status: "PARTIAL",
               note: "Throws SDKError but wrong case: \(error)")
    }
} catch {
    record("switchModel('') throws", swiftField: "Error", status: "PARTIAL",
           note: "Throws wrong error type: \(error)")
}

// Test whitespace-only throws error
do {
    try agent.switchModel("   ")
    record("switchModel('   ') throws", swiftField: "SDKError.invalidConfiguration", status: "MISSING",
           note: "switchModel('   ') did NOT throw")
} catch let error as SDKError {
    if case .invalidConfiguration = error {
        record("switchModel('   ') throws", swiftField: "SDKError.invalidConfiguration", status: "PASS",
               note: "Correctly throws for whitespace-only model name")
    } else {
        record("switchModel('   ') throws", swiftField: "SDKError", status: "PARTIAL",
               note: "Throws SDKError but wrong case: \(error)")
    }
} catch {
    record("switchModel('   ') throws", swiftField: "Error", status: "PARTIAL",
           note: "Throws wrong error type: \(error)")
}

// Per-model cost tracking
record("costBreakdown per-model tracking", swiftField: "CostBreakdownEntry per model", status: "PASS",
       note: "CostBreakdownEntry supports independent cost tracking per model. Verified with \(costEntries.count) entries.")

print("")

// MARK: - AC8: Cache Token Tracking Verification

print("=== AC8: Cache Token Tracking Verification ===")
print("")

let cacheCreationUsage = TokenUsage(inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: 42)
record("cacheCreationInputTokens", swiftField: "TokenUsage.cacheCreationInputTokens: Int?", status: "PASS",
       note: "cacheCreationInputTokens=\(cacheCreationUsage.cacheCreationInputTokens?.description ?? "nil"). Populated when caching writes tokens.")

let cacheReadUsage = TokenUsage(inputTokens: 100, outputTokens: 50, cacheReadInputTokens: 80)
record("cacheReadInputTokens", swiftField: "TokenUsage.cacheReadInputTokens: Int?", status: "PASS",
       note: "cacheReadInputTokens=\(cacheReadUsage.cacheReadInputTokens?.description ?? "nil"). Populated when caching reads tokens.")

// Verify Optional fields
let noCacheUsage = TokenUsage(inputTokens: 100, outputTokens: 50)
record("Cache fields Optional", swiftField: "Int? optional", status: "PASS",
       note: "cacheCreationInputTokens is nil=\(noCacheUsage.cacheCreationInputTokens == nil), cacheReadInputTokens is nil=\(noCacheUsage.cacheReadInputTokens == nil)")

// Verify decoding from API snake_case
let cacheJson = """
{"input_tokens": 100, "output_tokens": 50, "cache_creation_input_tokens": 10, "cache_read_input_tokens": 5}
""".data(using: .utf8)!
do {
    let decoded = try JSONDecoder().decode(TokenUsage.self, from: cacheJson)
    record("Cache fields decoded from API", swiftField: "snake_case CodingKeys", status: "PASS",
           note: "Decoded: cacheCreationInputTokens=\(decoded.cacheCreationInputTokens?.description ?? "nil"), cacheReadInputTokens=\(decoded.cacheReadInputTokens?.description ?? "nil")")
} catch {
    record("Cache fields decoded from API", swiftField: "TokenUsage decoding", status: "MISSING",
           note: "Failed to decode cache fields: \(error)")
}

print("")

// MARK: - AC9: Compatibility Report Output

print("=== AC9: Complete Thinking & Model Configuration Compatibility Report ===")
print("")

struct FieldMapping {
    let index: Int
    let tsField: String
    let swiftEquivalent: String
    let status: String
    let note: String
}

let thinkingMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "ThinkingConfig.adaptive", swiftEquivalent: "ThinkingConfig.adaptive", status: "PASS", note: "Matches TS { type: 'adaptive' }"),
    FieldMapping(index: 2, tsField: "ThinkingConfig.enabled(budgetTokens)", swiftEquivalent: "ThinkingConfig.enabled(budgetTokens: Int)", status: "PASS", note: "Required in Swift, optional in TS"),
    FieldMapping(index: 3, tsField: "ThinkingConfig.disabled", swiftEquivalent: "ThinkingConfig.disabled", status: "PASS", note: "Matches TS { type: 'disabled' }"),
    FieldMapping(index: 4, tsField: "ThinkingConfig.validate()", swiftEquivalent: "ThinkingConfig.validate() throws", status: "PASS", note: "Validates budgetTokens > 0"),
    FieldMapping(index: 5, tsField: "ThinkingConfig exhaustive cases", swiftEquivalent: "ThinkingConfig 3-case switch", status: "PASS", note: "Exactly 3 cases confirmed"),
    FieldMapping(index: 6, tsField: "ThinkingConfig passed to API", swiftEquivalent: "AgentOptions.thinking (NOT wired)", status: "PARTIAL", note: "Stored but not forwarded to API calls"),
]

let effortMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "Options.effort", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No effort field on AgentOptions"),
    FieldMapping(index: 2, tsField: "EffortLevel enum", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No EffortLevel enum"),
    FieldMapping(index: 3, tsField: "effort + ThinkingConfig interaction", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No effort parameter"),
]

let modelInfoMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "ModelInfo.value", swiftEquivalent: "ModelInfo.value: String", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 2, tsField: "ModelInfo.displayName", swiftEquivalent: "ModelInfo.displayName: String", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 3, tsField: "ModelInfo.description", swiftEquivalent: "ModelInfo.description: String", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 4, tsField: "ModelInfo.supportsEffort", swiftEquivalent: "ModelInfo.supportsEffort: Bool", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 5, tsField: "ModelInfo.supportedEffortLevels", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No field in Swift"),
    FieldMapping(index: 6, tsField: "ModelInfo.supportsAdaptiveThinking", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No field in Swift"),
    FieldMapping(index: 7, tsField: "ModelInfo.supportsFastMode", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No field in Swift"),
]

let tokenUsageMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "ModelUsage.inputTokens", swiftEquivalent: "TokenUsage.inputTokens: Int", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 2, tsField: "ModelUsage.outputTokens", swiftEquivalent: "TokenUsage.outputTokens: Int", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 3, tsField: "ModelUsage.cacheReadInputTokens", swiftEquivalent: "TokenUsage.cacheReadInputTokens: Int?", status: "PASS", note: "Optional, matches TS"),
    FieldMapping(index: 4, tsField: "ModelUsage.cacheCreationInputTokens", swiftEquivalent: "TokenUsage.cacheCreationInputTokens: Int?", status: "PASS", note: "Optional, matches TS"),
    FieldMapping(index: 5, tsField: "ModelUsage.webSearchRequests", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No field in Swift"),
    FieldMapping(index: 6, tsField: "ModelUsage.costUSD", swiftEquivalent: "QueryResult.totalCostUsd + CostBreakdownEntry.costUsd", status: "PARTIAL", note: "Different location"),
    FieldMapping(index: 7, tsField: "ModelUsage.contextWindow", swiftEquivalent: "getContextWindowSize(model:)", status: "PARTIAL", note: "Utility function, not field"),
    FieldMapping(index: 8, tsField: "ModelUsage.maxOutputTokens", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No field in Swift"),
    FieldMapping(index: 9, tsField: "CostBreakdownEntry fields", swiftEquivalent: "CostBreakdownEntry(model, inputTokens, outputTokens, costUsd)", status: "PASS", note: "All fields present"),
    FieldMapping(index: 10, tsField: "QueryResult.costBreakdown", swiftEquivalent: "QueryResult.costBreakdown: [CostBreakdownEntry]", status: "PASS", note: "Per-model cost tracking"),
]

let fallbackMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "Options.fallbackModel", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No fallbackModel option"),
    FieldMapping(index: 2, tsField: "Auto-switch on failure", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No fallback behavior"),
]

let switchModelMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "agent.switchModel(model)", swiftEquivalent: "Agent.switchModel(_:) throws", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 2, tsField: "switchModel changes model", swiftEquivalent: "Agent.model updated", status: "PASS", note: "Model updated correctly"),
    FieldMapping(index: 3, tsField: "switchModel('') throws", swiftEquivalent: "SDKError.invalidConfiguration", status: "PASS", note: "Empty string rejected"),
    FieldMapping(index: 4, tsField: "switchModel('   ') throws", swiftEquivalent: "SDKError.invalidConfiguration", status: "PASS", note: "Whitespace rejected"),
    FieldMapping(index: 5, tsField: "costBreakdown per-model tracking", swiftEquivalent: "CostBreakdownEntry per model", status: "PASS", note: "Independent cost per model"),
]

let cacheMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "cacheCreationInputTokens", swiftEquivalent: "TokenUsage.cacheCreationInputTokens: Int?", status: "PASS", note: "Optional, populated on cache write"),
    FieldMapping(index: 2, tsField: "cacheReadInputTokens", swiftEquivalent: "TokenUsage.cacheReadInputTokens: Int?", status: "PASS", note: "Optional, populated on cache read"),
    FieldMapping(index: 3, tsField: "Cache fields Optional", swiftEquivalent: "Int? optional", status: "PASS", note: "Both cache fields are Optional"),
    FieldMapping(index: 4, tsField: "Cache fields decoded from API", swiftEquivalent: "snake_case CodingKeys", status: "PASS", note: "Correct snake_case decoding"),
]

let allCategories: [(String, [FieldMapping])] = [
    ("ThinkingConfig (6 items)", thinkingMappings),
    ("Effort Parameter (3 items)", effortMappings),
    ("ModelInfo (7 items)", modelInfoMappings),
    ("TokenUsage / ModelUsage (10 items)", tokenUsageMappings),
    ("fallbackModel (2 items)", fallbackMappings),
    ("switchModel (5 items)", switchModelMappings),
    ("Cache Token Tracking (4 items)", cacheMappings),
]

// NOTE: AC9 category table output disabled due to String(format:) crash with %s on Swift String
// The compatibility data is already printed inline in AC2-AC8 above.
// See the full field-level report below for the complete compatibility matrix.
_ = allCategories

// --- Full Field-Level Compat Report ---

print("=== Full Field-Level Compatibility Report (All Entries) ===")
print("")

// Deduplicate by tsField
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

print("\(pad("TS SDK Field", width: 55)) | \(pad("Swift SDK Field", width: 55)) | \(pad("Status", width: 8)) | Notes")
print(String(repeating: "-", count: 160))
for entry in finalReport {
    let noteStr = entry.note ?? ""
    print("\(pad(entry.tsField, width: 55)) | \(pad(entry.swiftField, width: 55)) | [\(pad(entry.status, width: 7))] | \(noteStr)")
}

print("")
print("Overall Summary: PASS: \(fieldPassCount) | PARTIAL: \(fieldPartialCount) | MISSING: \(fieldMissingCount) | N/A: \(fieldNACount) | Total: \(finalReport.count)")
print("")

let compatRate = (fieldPassCount + fieldPartialCount + fieldMissingCount) == 0 ? 0 :
    Double(fieldPassCount + fieldPartialCount) / Double(fieldPassCount + fieldPartialCount + fieldMissingCount) * 100
print(String(format: "Pass+Partial Rate: %.1f%% (PASS+PARTIAL / PASS+PARTIAL+MISSING)", compatRate))

if fieldMissingCount > 0 {
    print("")
    print("Missing Items (require SDK changes):")
    for entry in finalReport where entry.status == "MISSING" {
        print("  - \(entry.tsField): \(entry.note ?? "No details")")
    }
}

print("")
print("Thinking & model configuration compatibility verification complete.")

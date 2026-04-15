// CompatOptions 示例 / Agent Options Compatibility Verification Example
//
// 验证 Swift SDK 的 AgentOptions / SDKConfiguration 是否覆盖 TypeScript SDK 的所有 Options 字段。
// Verifies Swift SDK's AgentOptions / SDKConfiguration covers all Options fields from the TypeScript SDK,
// so developers migrating from TypeScript don't have to compromise on functionality.
//
// 运行方式 / Run: swift run CompatOptions
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
    print("  \(statusStr) TS: \(tsField) -> Swift: \(swiftField)\(note.map { " (\($0))" } ?? "")")
}

// MARK: - AC1: Build Compilation Verification

print("=== AC1: Build Compilation ===")
print("[PASS] CompatOptions target compiles successfully")
print("")

// MARK: - AC2: Core Configuration Field-Level Verification (12 fields)

print("=== AC2: Core Configuration Field-Level Verification (12 fields) ===")
print("")

// Create a baseline AgentOptions for field verification
let options = AgentOptions(
    apiKey: apiKey,
    model: "claude-sonnet-4-6",
    systemPrompt: "You are a helpful assistant.",
    maxTurns: 20,
    maxBudgetUsd: 1.0,
    permissionMode: .bypassPermissions,
    cwd: "/tmp",
    mcpServers: ["test": .stdio(McpStdioConfig(command: "echo"))]
)

// 1. allowedTools: string[] -> ToolNameAllowlistPolicy
record("allowedTools: string[]", swiftField: "ToolNameAllowlistPolicy (PermissionPolicy)", status: "PARTIAL",
       note: "No direct AgentOptions field. ToolNameAllowlistPolicy exists in PermissionTypes as runtime policy, not config field.")

// 2. disallowedTools: string[] -> ToolNameDenylistPolicy
record("disallowedTools: string[]", swiftField: "ToolNameDenylistPolicy (PermissionPolicy)", status: "PARTIAL",
       note: "No direct AgentOptions field. ToolNameDenylistPolicy exists in PermissionTypes as runtime policy, not config field.")

// 3. maxTurns: number -> AgentOptions.maxTurns: Int
let _ = options.maxTurns
record("maxTurns: number", swiftField: "AgentOptions.maxTurns: Int", status: "PASS",
       note: "value=\(options.maxTurns)")

// 4. maxBudgetUsd: number -> AgentOptions.maxBudgetUsd: Double?
let _ = options.maxBudgetUsd
record("maxBudgetUsd: number", swiftField: "AgentOptions.maxBudgetUsd: Double?", status: "PASS",
       note: "value=\(options.maxBudgetUsd?.description ?? "nil")")

// 5. model: string -> AgentOptions.model: String
let _ = options.model
record("model: string", swiftField: "AgentOptions.model: String", status: "PASS",
       note: "value='\(options.model)'")

// 6. fallbackModel: string -> NO EQUIVALENT
record("fallbackModel: string", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No fallbackModel property found on AgentOptions or Agent.")

// 7. systemPrompt: string | { type: 'preset', preset, append? } -> AgentOptions.systemPrompt: String?
let _ = options.systemPrompt
record("systemPrompt: string | { type: 'preset' }", swiftField: "AgentOptions.systemPrompt: String?", status: "PARTIAL",
       note: "Swift only supports String?, no preset mode or append mechanism.")

// 8. permissionMode: PermissionMode -> AgentOptions.permissionMode: PermissionMode
let _ = options.permissionMode
record("permissionMode: PermissionMode", swiftField: "AgentOptions.permissionMode: PermissionMode", status: "PASS",
       note: "6 cases: default, acceptEdits, bypassPermissions, plan, dontAsk, auto")

// 9. canUseTool: CanUseTool -> AgentOptions.canUseTool: CanUseToolFn?
let _ = options.canUseTool
record("canUseTool: CanUseTool", swiftField: "AgentOptions.canUseTool: CanUseToolFn?", status: "PASS",
       note: "CanUseToolFn = @Sendable (ToolProtocol, Any, ToolContext) async -> CanUseToolResult?")

// 10. cwd: string -> AgentOptions.cwd: String?
let _ = options.cwd
record("cwd: string", swiftField: "AgentOptions.cwd: String?", status: "PASS",
       note: "value='\(options.cwd ?? "nil")'")

// 11. env: Record<string, string> -> NO EQUIVALENT
record("env: Record<string, string>", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No env override dict on AgentOptions. SDKConfiguration reads from environment but does not accept env overrides.")

// 12. mcpServers: Record<string, McpServerConfig> -> AgentOptions.mcpServers
let _ = options.mcpServers
record("mcpServers: Record<string, McpServerConfig>", swiftField: "AgentOptions.mcpServers: [String: McpServerConfig]?", status: "PASS",
       note: "4 config types: stdio, sse, http, sdk")

print("")

// MARK: - AC3: Advanced Configuration Field-Level Verification (9 fields)

print("=== AC3: Advanced Configuration Field-Level Verification (9 fields) ===")
print("")

// 1. thinking: ThinkingConfig -> AgentOptions.thinking: ThinkingConfig?
let thinkingOptions = AgentOptions(thinking: .enabled(budgetTokens: 10000))
let _ = thinkingOptions.thinking
record("thinking: ThinkingConfig", swiftField: "AgentOptions.thinking: ThinkingConfig?", status: "PASS",
       note: ".adaptive / .enabled(budgetTokens:) / .disabled")

// 2. effort: 'low' | 'medium' | 'high' | 'max' -> NO EQUIVALENT
record("effort: 'low' | 'medium' | 'high' | 'max'", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No effort level property found anywhere in Swift SDK.")

// 3. hooks: Partial<Record<HookEvent, HookCallbackMatcher[]>> -> AgentOptions.hookRegistry: HookRegistry?
let hookOptions = AgentOptions(hookRegistry: HookRegistry())
let _ = hookOptions.hookRegistry
record("hooks: Partial<Record<HookEvent, ...>>", swiftField: "AgentOptions.hookRegistry: HookRegistry?", status: "PARTIAL",
       note: "Swift uses HookRegistry actor (not config dict). 20 HookEvent cases. Different pattern but equivalent capability.")

// 4. sandbox: SandboxSettings -> AgentOptions.sandbox: SandboxSettings?
let sandboxOptions = AgentOptions(sandbox: SandboxSettings(
    allowedReadPaths: ["/project/"],
    allowedWritePaths: ["/project/build/"],
    deniedPaths: ["/etc/"],
    deniedCommands: ["rm"],
    allowedCommands: ["git", "swift"]
))
let _ = sandboxOptions.sandbox
record("sandbox: SandboxSettings", swiftField: "AgentOptions.sandbox: SandboxSettings?", status: "PASS",
       note: "6 fields: allowedReadPaths, allowedWritePaths, deniedPaths, deniedCommands, allowedCommands, allowNestedSandbox")

// 5. agents: Record<string, AgentDefinition> -> AgentDefinition + AgentTool
let agentDef = AgentDefinition(
    name: "Explore",
    description: "Fast agent for exploring codebases.",
    model: "claude-sonnet-4-6",
    systemPrompt: "You are a codebase exploration agent.",
    tools: ["Read", "Glob", "Grep"],
    maxTurns: 10
)
record("agents: Record<string, AgentDefinition>", swiftField: "AgentDefinition (via AgentTool)", status: "PARTIAL",
       note: "AgentDefinition exists (6 fields). Registered via AgentTool at tool level, NOT as AgentOptions top-level dict.")

// Verify AgentDefinition fields
record("AgentDefinition.name", swiftField: "AgentDefinition.name: String", status: "PASS",
       note: "name='\(agentDef.name)'")
record("AgentDefinition.description", swiftField: "AgentDefinition.description: String?", status: "PASS",
       note: "description='\(agentDef.description ?? "nil")'")
record("AgentDefinition.model", swiftField: "AgentDefinition.model: String?", status: "PASS",
       note: "model='\(agentDef.model ?? "nil")'")
record("AgentDefinition.systemPrompt", swiftField: "AgentDefinition.systemPrompt: String?", status: "PASS",
       note: "systemPrompt='\(agentDef.systemPrompt ?? "nil")'")
record("AgentDefinition.tools (allowedTools)", swiftField: "AgentDefinition.tools: [String]?", status: "PASS",
       note: "tools=\(agentDef.tools?.description ?? "nil")")
record("AgentDefinition.maxTurns", swiftField: "AgentDefinition.maxTurns: Int?", status: "PASS",
       note: "maxTurns=\(agentDef.maxTurns?.description ?? "nil")")

// 6. toolConfig: ToolConfig -> NO EQUIVALENT
record("toolConfig: ToolConfig", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No ToolConfig type found in Swift SDK.")

// 7. outputFormat: { type: 'json_schema', schema } -> NO EQUIVALENT
record("outputFormat: { type: 'json_schema', schema }", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No outputFormat property found. Structured output / JSON Schema output not supported.")

// 8. includePartialMessages: boolean -> NO EQUIVALENT
record("includePartialMessages: boolean", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No partial message streaming flag found.")

// 9. promptSuggestions: boolean -> NO EQUIVALENT
record("promptSuggestions: boolean", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No prompt suggestion flag found.")

print("")

// MARK: - AC4: Session Configuration Field-Level Verification (5 fields)

print("=== AC4: Session Configuration Field-Level Verification (5 fields) ===")
print("")

// 1. resume: string -> sessionStore + sessionId mechanism
record("resume: string", swiftField: "AgentOptions.sessionStore + sessionId", status: "PARTIAL",
       note: "No resume field. Session restore achieved via sessionStore + sessionId combo. Different API pattern.")

// 2. continue: boolean -> NO EQUIVALENT
record("continue: boolean", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No continue-last-session flag.")

// 3. forkSession: boolean -> NO EQUIVALENT
record("forkSession: boolean", swiftField: "NO EQUIVALENT", status: "PARTIAL",
       note: "No forkSession flag on AgentOptions. SessionStore has fork capability separately.")

// 4. sessionId: string -> AgentOptions.sessionId: String?
let sessionOptions = AgentOptions(sessionId: "test-session-123")
let _ = sessionOptions.sessionId
record("sessionId: string", swiftField: "AgentOptions.sessionId: String?", status: "PASS",
       note: "value='\(sessionOptions.sessionId ?? "nil")'")

// 5. persistSession: boolean -> implicit via sessionStore
record("persistSession: boolean", swiftField: "AgentOptions.sessionStore (implicit)", status: "PARTIAL",
       note: "No explicit boolean flag. When sessionStore is set, auto-save is implicit.")

print("")

// MARK: - AC5: Extended Configuration Field-Level Verification (11 fields)

print("=== AC5: Extended Configuration Field-Level Verification (11 fields) ===")
print("")

// 1. settingSources: SettingSource[] -> NO EQUIVALENT
record("settingSources: SettingSource[]", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No file-based settings source configuration.")

// 2. plugins: SdkPluginConfig[] -> NO EQUIVALENT
record("plugins: SdkPluginConfig[]", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No plugin loading mechanism.")

// 3. betas: SdkBeta[] -> NO EQUIVALENT
record("betas: SdkBeta[]", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No beta feature flags.")

// 4. executable: 'bun' | 'deno' | 'node' -> N/A
record("executable: 'bun' | 'deno' | 'node'", swiftField: "N/A", status: "N/A",
       note: "Swift runtime, not Node.js.")

// 5. spawnClaudeCodeProcess -> N/A
record("spawnClaudeCodeProcess", swiftField: "N/A", status: "N/A",
       note: "Not applicable to Swift process model.")

// 6. additionalDirectories: string[] -> AgentOptions.skillDirectories (partial)
let dirOptions = AgentOptions(skillDirectories: ["/path/to/skills"])
let _ = dirOptions.skillDirectories
record("additionalDirectories: string[]", swiftField: "AgentOptions.skillDirectories: [String]?", status: "PARTIAL",
       note: "skillDirectories covers skill discovery dirs, not general additional directories.")

// 7. debug: boolean / debugFile: string -> logLevel + logOutput
let debugOptions = AgentOptions(logLevel: .debug, logOutput: .file(URL(fileURLWithPath: "/tmp/sdk.log")))
let _ = debugOptions.logLevel
let _ = debugOptions.logOutput
record("debug: boolean", swiftField: "AgentOptions.logLevel: LogLevel", status: "PARTIAL",
       note: "LogLevel.debug provides equivalent debug output. Different API shape (enum vs boolean).")
record("debugFile: string", swiftField: "AgentOptions.logOutput: .file(URL)", status: "PARTIAL",
       note: "LogOutput.file(URL) provides file-based logging. Different API shape (enum case vs string path).")

// 8. stderr: (data: string) => void -> LogOutput.custom
let customOutput = LogOutput.custom { _ in }
let stderrOptions = AgentOptions(logOutput: customOutput)
let _ = stderrOptions.logOutput
record("stderr: (data: string) => void", swiftField: "AgentOptions.logOutput: .custom(@Sendable (String) -> Void)", status: "PARTIAL",
       note: "LogOutput.custom closure provides stderr-like callback. Different scope (all logs vs stderr only).")

// 9. strictMcpConfig: boolean -> NO EQUIVALENT
record("strictMcpConfig: boolean", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No strict MCP config validation flag.")

// 10. extraArgs: Record<string, string | null> -> NO EQUIVALENT
record("extraArgs: Record<string, string | null>", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No extra argument passthrough mechanism.")

// 11. enableFileCheckpointing: boolean -> NO EQUIVALENT
record("enableFileCheckpointing: boolean", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No file checkpointing system.")

print("")

// MARK: - AC6: ThinkingConfig Type Verification

print("=== AC6: ThinkingConfig Type Verification ===")
print("")

// TS: { type: "adaptive" } -> Swift: .adaptive
let adaptive = ThinkingConfig.adaptive
record("ThinkingConfig { type: 'adaptive' }", swiftField: "ThinkingConfig.adaptive", status: "PASS",
       note: "Exact semantic match.")

// TS: { type: "enabled", budgetTokens?: number } -> Swift: .enabled(budgetTokens: Int)
let enabled = ThinkingConfig.enabled(budgetTokens: 8000)
record("ThinkingConfig { type: 'enabled', budgetTokens }", swiftField: "ThinkingConfig.enabled(budgetTokens: Int)", status: "PASS",
       note: "budgetTokens is required (Int) in Swift, optional in TS.")

// TS: { type: "disabled" } -> Swift: .disabled
let disabled = ThinkingConfig.disabled
record("ThinkingConfig { type: 'disabled' }", swiftField: "ThinkingConfig.disabled", status: "PASS",
       note: "Exact semantic match.")

// Verify all three cases work
switch adaptive {
case .adaptive: print("    .adaptive verified")
case .enabled: print("    unexpected .enabled")
case .disabled: print("    unexpected .disabled")
}
switch enabled {
case .enabled(let tokens): print("    .enabled(budgetTokens: \(tokens)) verified")
case .adaptive: print("    unexpected .adaptive")
case .disabled: print("    unexpected .disabled")
}
switch disabled {
case .disabled: print("    .disabled verified")
case .adaptive: print("    unexpected .adaptive")
case .enabled: print("    unexpected .enabled")
}

// effort level verification
record("effort level: 'low' | 'medium' | 'high' | 'max'", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No effort property found anywhere in Swift SDK (AgentOptions, ThinkingConfig, or elsewhere).")

print("")

// MARK: - AC7: systemPrompt Preset Mode Verification

print("=== AC7: systemPrompt Preset Mode Verification ===")
print("")

// TS supports: string | { type: 'preset', preset: 'claude_code', append?: string }
// Swift supports: String?
record("systemPrompt: string (plain)", swiftField: "AgentOptions.systemPrompt: String?", status: "PASS",
       note: "Plain string supported.")

record("systemPrompt: { type: 'preset', preset: 'claude_code' }", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "Swift only supports String?. No structured type, no preset enum.")

record("systemPrompt: { type: 'preset', append?: string }", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No append/customize-on-preset capability.")

print("")

// MARK: - AC8: outputFormat / Structured Output Verification

print("=== AC8: outputFormat / Structured Output Verification ===")
print("")

record("outputFormat: { type: 'json_schema', schema }", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No outputFormat property on AgentOptions, Agent, or query methods. Structured output not supported.")
record("outputFormat.schema (JSON Schema object)", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "JSON Schema structured output schema not supported.")
record("Migration path", swiftField: "Post-process QueryResult.text", status: "N/A",
       note: "Developers can parse QueryResult.text as JSON and validate against schema manually.")

print("")

// MARK: - AC9: Compatibility Report Output

print("=== AC9: Complete Agent Options Compatibility Report ===")
print("")

// --- Core Configuration Table ---
struct FieldMapping {
    let index: Int
    let tsField: String
    let swiftEquivalent: String
    let status: String
    let note: String
}

let coreMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "allowedTools: string[]", swiftEquivalent: "ToolNameAllowlistPolicy (PermissionPolicy)", status: "PARTIAL", note: "Runtime policy, not config field"),
    FieldMapping(index: 2, tsField: "disallowedTools: string[]", swiftEquivalent: "ToolNameDenylistPolicy (PermissionPolicy)", status: "PARTIAL", note: "Runtime policy, not config field"),
    FieldMapping(index: 3, tsField: "maxTurns: number", swiftEquivalent: "AgentOptions.maxTurns: Int", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 4, tsField: "maxBudgetUsd: number", swiftEquivalent: "AgentOptions.maxBudgetUsd: Double?", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 5, tsField: "model: string", swiftEquivalent: "AgentOptions.model: String", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 6, tsField: "fallbackModel: string", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No fallback model"),
    FieldMapping(index: 7, tsField: "systemPrompt: string | preset", swiftEquivalent: "AgentOptions.systemPrompt: String?", status: "PARTIAL", note: "String only, no preset"),
    FieldMapping(index: 8, tsField: "permissionMode: PermissionMode", swiftEquivalent: "AgentOptions.permissionMode: PermissionMode", status: "PASS", note: "6 cases"),
    FieldMapping(index: 9, tsField: "canUseTool: CanUseTool", swiftEquivalent: "AgentOptions.canUseTool: CanUseToolFn?", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 10, tsField: "cwd: string", swiftEquivalent: "AgentOptions.cwd: String?", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 11, tsField: "env: Record<string, string>", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No env override dict"),
    FieldMapping(index: 12, tsField: "mcpServers: Record<string, McpServerConfig>", swiftEquivalent: "AgentOptions.mcpServers: [String: McpServerConfig]?", status: "PASS", note: "4 config types"),
]

print("Core Configuration (12 fields)")
print("==============================")
print("")
print(String(format: "%-2s %-45s %-50s %-8s | Notes", "#", "TS SDK Field", "Swift Equivalent", "Status"))
print(String(repeating: "-", count: 140))
for m in coreMappings {
    print(String(format: "%-2d %-45s %-50s [%-7s] | %@", m.index, m.tsField, m.swiftEquivalent, m.status, m.note))
}
print("")

let corePass = coreMappings.filter { $0.status == "PASS" }.count
let corePartial = coreMappings.filter { $0.status == "PARTIAL" }.count
let coreMissing = coreMappings.filter { $0.status == "MISSING" }.count
print("Core Summary: PASS: \(corePass) | PARTIAL: \(corePartial) | MISSING: \(coreMissing) | Total: \(coreMappings.count)")
print("")

// --- Advanced Configuration Table ---
let advancedMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "thinking: ThinkingConfig", swiftEquivalent: "AgentOptions.thinking: ThinkingConfig?", status: "PASS", note: ".adaptive/.enabled/.disabled"),
    FieldMapping(index: 2, tsField: "effort: 'low'|'medium'|'high'|'max'", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No effort level"),
    FieldMapping(index: 3, tsField: "hooks: Partial<Record<HookEvent, ...>>", swiftEquivalent: "AgentOptions.hookRegistry: HookRegistry?", status: "PARTIAL", note: "Actor not dict, 20 events"),
    FieldMapping(index: 4, tsField: "sandbox: SandboxSettings", swiftEquivalent: "AgentOptions.sandbox: SandboxSettings?", status: "PASS", note: "6 fields"),
    FieldMapping(index: 5, tsField: "agents: Record<string, AgentDefinition>", swiftEquivalent: "AgentDefinition (via AgentTool)", status: "PARTIAL", note: "Tool-level, not options-level"),
    FieldMapping(index: 6, tsField: "toolConfig: ToolConfig", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No ToolConfig type"),
    FieldMapping(index: 7, tsField: "outputFormat: { type: 'json_schema', schema }", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No structured output"),
    FieldMapping(index: 8, tsField: "includePartialMessages: boolean", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No partial message flag"),
    FieldMapping(index: 9, tsField: "promptSuggestions: boolean", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No prompt suggestion flag"),
]

print("Advanced Configuration (9 fields)")
print("=================================")
print("")
print(String(format: "%-2s %-45s %-50s %-8s | Notes", "#", "TS SDK Field", "Swift Equivalent", "Status"))
print(String(repeating: "-", count: 140))
for m in advancedMappings {
    print(String(format: "%-2d %-45s %-50s [%-7s] | %@", m.index, m.tsField, m.swiftEquivalent, m.status, m.note))
}
print("")

let advPass = advancedMappings.filter { $0.status == "PASS" }.count
let advPartial = advancedMappings.filter { $0.status == "PARTIAL" }.count
let advMissing = advancedMappings.filter { $0.status == "MISSING" }.count
print("Advanced Summary: PASS: \(advPass) | PARTIAL: \(advPartial) | MISSING: \(advMissing) | Total: \(advancedMappings.count)")
print("")

// --- Session Configuration Table ---
let sessionMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "resume: string", swiftEquivalent: "sessionStore + sessionId", status: "PARTIAL", note: "Different API pattern"),
    FieldMapping(index: 2, tsField: "continue: boolean", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No continue flag"),
    FieldMapping(index: 3, tsField: "forkSession: boolean", swiftEquivalent: "SessionStore.fork (separate)", status: "PARTIAL", note: "Capability exists, not on AgentOptions"),
    FieldMapping(index: 4, tsField: "sessionId: string", swiftEquivalent: "AgentOptions.sessionId: String?", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 5, tsField: "persistSession: boolean", swiftEquivalent: "sessionStore (implicit)", status: "PARTIAL", note: "Implicit when sessionStore set"),
]

print("Session Configuration (5 fields)")
print("=================================")
print("")
print(String(format: "%-2s %-45s %-50s %-8s | Notes", "#", "TS SDK Field", "Swift Equivalent", "Status"))
print(String(repeating: "-", count: 140))
for m in sessionMappings {
    print(String(format: "%-2d %-45s %-50s [%-7s] | %@", m.index, m.tsField, m.swiftEquivalent, m.status, m.note))
}
print("")

let sessPass = sessionMappings.filter { $0.status == "PASS" }.count
let sessPartial = sessionMappings.filter { $0.status == "PARTIAL" }.count
let sessMissing = sessionMappings.filter { $0.status == "MISSING" }.count
print("Session Summary: PASS: \(sessPass) | PARTIAL: \(sessPartial) | MISSING: \(sessMissing) | Total: \(sessionMappings.count)")
print("")

// --- Extended Configuration Table ---
let extendedMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "settingSources: SettingSource[]", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No settings source config"),
    FieldMapping(index: 2, tsField: "plugins: SdkPluginConfig[]", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No plugin system"),
    FieldMapping(index: 3, tsField: "betas: SdkBeta[]", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No beta flags"),
    FieldMapping(index: 4, tsField: "executable: 'bun'|'deno'|'node'", swiftEquivalent: "N/A", status: "N/A", note: "Swift runtime"),
    FieldMapping(index: 5, tsField: "spawnClaudeCodeProcess", swiftEquivalent: "N/A", status: "N/A", note: "Not applicable"),
    FieldMapping(index: 6, tsField: "additionalDirectories: string[]", swiftEquivalent: "skillDirectories: [String]?", status: "PARTIAL", note: "Skill dirs only"),
    FieldMapping(index: 7, tsField: "debug: boolean / debugFile: string", swiftEquivalent: "logLevel / logOutput", status: "PARTIAL", note: "Enum vs boolean/string"),
    FieldMapping(index: 8, tsField: "stderr: (data: string) => void", swiftEquivalent: "LogOutput.custom closure", status: "PARTIAL", note: "All logs, not just stderr"),
    FieldMapping(index: 9, tsField: "strictMcpConfig: boolean", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No strict MCP config flag"),
    FieldMapping(index: 10, tsField: "extraArgs: Record<string, string | null>", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No extra arg passthrough"),
    FieldMapping(index: 11, tsField: "enableFileCheckpointing: boolean", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No file checkpointing"),
]

print("Extended Configuration (11 fields)")
print("==================================")
print("")
print(String(format: "%-2s %-45s %-50s %-8s | Notes", "#", "TS SDK Field", "Swift Equivalent", "Status"))
print(String(repeating: "-", count: 140))
for m in extendedMappings {
    print(String(format: "%-2d %-45s %-50s [%-7s] | %@", m.index, m.tsField, m.swiftEquivalent, m.status, m.note))
}
print("")

let extPass = extendedMappings.filter { $0.status == "PASS" }.count
let extPartial = extendedMappings.filter { $0.status == "PARTIAL" }.count
let extMissing = extendedMappings.filter { $0.status == "MISSING" }.count
let extNA = extendedMappings.filter { $0.status == "N/A" }.count
print("Extended Summary: PASS: \(extPass) | PARTIAL: \(extPartial) | MISSING: \(extMissing) | N/A: \(extNA) | Total: \(extendedMappings.count)")
print("")

// --- ThinkingConfig Detail Table ---
let thinkingMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "{ type: 'adaptive' }", swiftEquivalent: "ThinkingConfig.adaptive", status: "PASS", note: "Exact match"),
    FieldMapping(index: 2, tsField: "{ type: 'enabled', budgetTokens? }", swiftEquivalent: "ThinkingConfig.enabled(budgetTokens: Int)", status: "PASS", note: "budgetTokens required in Swift"),
    FieldMapping(index: 3, tsField: "{ type: 'disabled' }", swiftEquivalent: "ThinkingConfig.disabled", status: "PASS", note: "Exact match"),
    FieldMapping(index: 4, tsField: "effort: 'low'|'medium'|'high'|'max'", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No effort level"),
]

print("ThinkingConfig Detail (4 items)")
print("===============================")
print("")
print(String(format: "%-2s %-45s %-50s %-8s | Notes", "#", "TS SDK Type", "Swift Equivalent", "Status"))
print(String(repeating: "-", count: 140))
for m in thinkingMappings {
    print(String(format: "%-2d %-45s %-50s [%-7s] | %@", m.index, m.tsField, m.swiftEquivalent, m.status, m.note))
}
print("")

let thinkPass = thinkingMappings.filter { $0.status == "PASS" }.count
let thinkMissing = thinkingMappings.filter { $0.status == "MISSING" }.count
print("ThinkingConfig Summary: PASS: \(thinkPass) | MISSING: \(thinkMissing) | Total: \(thinkingMappings.count)")
print("")

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

print(String(format: "%-50s | %-55s | %-8s | Notes", "TS SDK Field", "Swift SDK Field"))
print(String(repeating: "-", count: 150))
for entry in finalReport {
    let noteStr = entry.note ?? ""
    print(String(format: "%-50s | %-55s | [%-7s] | %@", entry.tsField, entry.swiftField, entry.status, noteStr))
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
print("Agent options compatibility verification complete.")

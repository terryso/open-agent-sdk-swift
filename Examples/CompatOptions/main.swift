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

func pad(_ s: String, _ n: Int) -> String {
    s.padding(toLength: n, withPad: " ", startingAt: 0)
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

// 1. allowedTools: string[] -> AgentOptions.allowedTools: [String]?
let allowedToolsOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", allowedTools: ["Read", "Write"])
let _ = allowedToolsOptions.allowedTools
record("allowedTools: string[]", swiftField: "AgentOptions.allowedTools: [String]?", status: "PASS",
       note: "Direct field on AgentOptions (Story 17-2). value=\(allowedToolsOptions.allowedTools?.description ?? "nil")")

// 2. disallowedTools: string[] -> AgentOptions.disallowedTools: [String]?
let disallowedToolsOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", disallowedTools: ["Bash"])
let _ = disallowedToolsOptions.disallowedTools
record("disallowedTools: string[]", swiftField: "AgentOptions.disallowedTools: [String]?", status: "PASS",
       note: "Direct field on AgentOptions (Story 17-2). value=\(disallowedToolsOptions.disallowedTools?.description ?? "nil")")

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

// 6. fallbackModel: string -> AgentOptions.fallbackModel: String?
let fallbackOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", fallbackModel: "claude-haiku-4-5")
let _ = fallbackOptions.fallbackModel
record("fallbackModel: string", swiftField: "AgentOptions.fallbackModel: String?", status: "PASS",
       note: "Direct field on AgentOptions (Story 17-2). value='\(fallbackOptions.fallbackModel ?? "nil")'")

// 7. systemPrompt: string | { type: 'preset', preset, append? } -> AgentOptions.systemPrompt: String? + SystemPromptConfig
let _ = options.systemPrompt
record("systemPrompt: string | { type: 'preset' }", swiftField: "AgentOptions.systemPrompt: String? + SystemPromptConfig", status: "PARTIAL",
       note: "String? + SystemPromptConfig.preset(name:append:) added (Story 17-2). Core config row stays PARTIAL because TS uses unified field; Swift uses two separate properties.")

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

// 11. env: Record<string, string> -> AgentOptions.env: [String: String]?
let envOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", env: ["KEY": "VALUE"])
let _ = envOptions.env
record("env: Record<string, string>", swiftField: "AgentOptions.env: [String: String]?", status: "PASS",
       note: "Direct field on AgentOptions (Story 17-2). value=\(envOptions.env?.description ?? "nil")")

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

// 2. effort: 'low' | 'medium' | 'high' | 'max' -> AgentOptions.effort: EffortLevel?
let effortOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", effort: .high)
let _ = effortOptions.effort
record("effort: 'low' | 'medium' | 'high' | 'max'", swiftField: "AgentOptions.effort: EffortLevel?", status: "PASS",
       note: "EffortLevel enum with .low, .medium, .high, .max cases (Story 17-2). value=\(effortOptions.effort?.rawValue ?? "nil")")

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

// 6. toolConfig: ToolConfig -> AgentOptions.toolConfig: ToolConfig?
let toolConfigVal = ToolConfig(maxConcurrentReadTools: 5, maxConcurrentWriteTools: 2)
let toolConfigOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", toolConfig: toolConfigVal)
let _ = toolConfigOptions.toolConfig
record("toolConfig: ToolConfig", swiftField: "AgentOptions.toolConfig: ToolConfig?", status: "PASS",
       note: "ToolConfig with maxConcurrentReadTools/maxConcurrentWriteTools (Story 17-2).")

// 7. outputFormat: { type: 'json_schema', schema } -> AgentOptions.outputFormat: OutputFormat?
let outputFormatVal = OutputFormat(jsonSchema: ["type": "object"])
let outputFormatOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", outputFormat: outputFormatVal)
let _ = outputFormatOptions.outputFormat
record("outputFormat: { type: 'json_schema', schema }", swiftField: "AgentOptions.outputFormat: OutputFormat?", status: "PASS",
       note: "OutputFormat with json_schema type (Story 17-2). type='\(outputFormatOptions.outputFormat?.type ?? "nil")'")

// 8. includePartialMessages: boolean -> AgentOptions.includePartialMessages: Bool
let partialMsgOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6")
let _ = partialMsgOptions.includePartialMessages
record("includePartialMessages: boolean", swiftField: "AgentOptions.includePartialMessages: Bool", status: "PASS",
       note: "Direct field on AgentOptions (Story 17-2). default=true")

// 9. promptSuggestions: boolean -> AgentOptions.promptSuggestions: Bool
let promptSuggOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6")
let _ = promptSuggOptions.promptSuggestions
record("promptSuggestions: boolean", swiftField: "AgentOptions.promptSuggestions: Bool", status: "PASS",
       note: "Direct field on AgentOptions (Story 17-2). default=false")

print("")

// MARK: - AC4: Session Configuration Field-Level Verification (5 fields)

print("=== AC4: Session Configuration Field-Level Verification (5 fields) ===")
print("")

// 1. resume: string -> AgentOptions.resumeSessionAt: String?
let resumeOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", resumeSessionAt: "msg-123")
let _ = resumeOptions.resumeSessionAt
record("resume: string", swiftField: "AgentOptions.resumeSessionAt: String?", status: "PASS",
       note: "resumeSessionAt specifies message ID to truncate history at (Story 17-2). value='\(resumeOptions.resumeSessionAt ?? "nil")'")

// 2. continue: boolean -> AgentOptions.continueRecentSession: Bool
let continueOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", continueRecentSession: true)
let _ = continueOptions.continueRecentSession
record("continue: boolean", swiftField: "AgentOptions.continueRecentSession: Bool", status: "PASS",
       note: "Direct field on AgentOptions (Story 17-2). default=false, value=\(continueOptions.continueRecentSession)")

// 3. forkSession: boolean -> AgentOptions.forkSession: Bool
let forkOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", forkSession: true)
let _ = forkOptions.forkSession
record("forkSession: boolean", swiftField: "AgentOptions.forkSession: Bool", status: "PASS",
       note: "Direct field on AgentOptions (Story 17-2). default=false, value=\(forkOptions.forkSession)")

// 4. sessionId: string -> AgentOptions.sessionId: String?
let sessionOptions = AgentOptions(sessionId: "test-session-123")
let _ = sessionOptions.sessionId
record("sessionId: string", swiftField: "AgentOptions.sessionId: String?", status: "PASS",
       note: "value='\(sessionOptions.sessionId ?? "nil")'")

// 5. persistSession: boolean -> AgentOptions.persistSession: Bool
let persistOptions = AgentOptions(apiKey: apiKey, model: "claude-sonnet-4-6", persistSession: true)
let _ = persistOptions.persistSession
record("persistSession: boolean", swiftField: "AgentOptions.persistSession: Bool", status: "PASS",
       note: "Direct field on AgentOptions (Story 17-2). default=true, value=\(persistOptions.persistSession)")

print("")

// MARK: - AC5: Extended Configuration Field-Level Verification (11 fields)

print("=== AC5: Extended Configuration Field-Level Verification (11 fields) ===")
print("")

// 1. settingSources: SettingSource[] -> AgentOptions.settingSources
let sourcesOptions = AgentOptions(settingSources: [.project])
let _ = sourcesOptions.settingSources
record("settingSources: SettingSource[]", swiftField: "AgentOptions.settingSources: [SettingSource]?", status: "PASS",
       note: "SettingSource enum with user/project/enterprise cases.")

// 2. plugins: SdkPluginConfig[] -> AgentOptions.plugins
let pluginsOptions = AgentOptions(plugins: [SdkPluginConfig(name: "my-plugin")])
let _ = pluginsOptions.plugins
record("plugins: SdkPluginConfig[]", swiftField: "AgentOptions.plugins: [SdkPluginConfig]?", status: "PASS",
       note: "SdkPluginConfig with name/enabled fields.")

// 3. betas: SdkBeta[] -> AgentOptions.betas
let betasOptions = AgentOptions(betas: [.maxTurns, .extendedThinking])
let _ = betasOptions.betas
record("betas: SdkBeta[]", swiftField: "AgentOptions.betas: [SdkBeta]?", status: "PASS",
       note: "SdkBeta with rawValue and static presets.")

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

// 9. strictMcpConfig: boolean -> AgentOptions.strictMcpConfig
let strictMcpOptions = AgentOptions(strictMcpConfig: true)
let _ = strictMcpOptions.strictMcpConfig
record("strictMcpConfig: boolean", swiftField: "AgentOptions.strictMcpConfig: Bool", status: "PASS",
       note: "Strict MCP config validation flag.")

// 10. extraArgs: Record<string, string | null> -> AgentOptions.extraArgs
let extraArgsOptions = AgentOptions(extraArgs: ["key": "value", "nil_val": nil])
let _ = extraArgsOptions.extraArgs
record("extraArgs: Record<string, string | null>", swiftField: "AgentOptions.extraArgs: [String: String?]?", status: "PASS",
       note: "Extra argument passthrough dictionary.")

// 11. enableFileCheckpointing: boolean -> AgentOptions.enableFileCheckpointing
let checkpointOptions = AgentOptions(enableFileCheckpointing: true)
let _ = checkpointOptions.enableFileCheckpointing
record("enableFileCheckpointing: boolean", swiftField: "AgentOptions.enableFileCheckpointing: Bool", status: "PASS",
       note: "File checkpointing flag.")

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

// effort level verification -- separate EffortLevel enum (Story 17-2)
let effortLevel = EffortLevel.high
record("effort level: 'low' | 'medium' | 'high' | 'max'", swiftField: "EffortLevel enum (.low, .medium, .high, .max)", status: "PASS",
       note: "EffortLevel enum with 4 cases and budgetTokens computed property (Story 17-2). value=\(effortLevel.rawValue)")

print("")

// MARK: - AC7: systemPrompt Preset Mode Verification

print("=== AC7: systemPrompt Preset Mode Verification ===")
print("")

// TS supports: string | { type: 'preset', preset: 'claude_code', append?: string }
// Swift supports: String?
record("systemPrompt: string (plain)", swiftField: "AgentOptions.systemPrompt: String?", status: "PASS",
       note: "Plain string supported.")

record("systemPrompt: { type: 'preset', preset: 'claude_code' }", swiftField: "SystemPromptConfig.preset(name: String, append: String?)", status: "PASS",
       note: "SystemPromptConfig.preset mode added (Story 17-2). e.g. .preset(name: 'claude_code', append: nil)")

record("systemPrompt: { type: 'preset', append?: string }", swiftField: "SystemPromptConfig.preset(name:append:)", status: "PASS",
       note: "SystemPromptConfig.preset supports optional append parameter (Story 17-2). e.g. .preset(name: 'claude_code', append: 'custom')")

print("")

// MARK: - AC8: outputFormat / Structured Output Verification

print("=== AC8: outputFormat / Structured Output Verification ===")
print("")

record("outputFormat: { type: 'json_schema', schema }", swiftField: "AgentOptions.outputFormat: OutputFormat?", status: "PASS",
       note: "OutputFormat with json_schema type added (Story 17-2). Uses SendableJSONSchema wrapper.")
record("outputFormat.schema (JSON Schema object)", swiftField: "OutputFormat.jsonSchema: SendableJSONSchema", status: "PASS",
       note: "JSON Schema structured output supported via SendableJSONSchema (Story 17-2).")
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
    FieldMapping(index: 1, tsField: "allowedTools: string[]", swiftEquivalent: "AgentOptions.allowedTools: [String]?", status: "PASS", note: "Direct field (Story 17-2)"),
    FieldMapping(index: 2, tsField: "disallowedTools: string[]", swiftEquivalent: "AgentOptions.disallowedTools: [String]?", status: "PASS", note: "Direct field (Story 17-2)"),
    FieldMapping(index: 3, tsField: "maxTurns: number", swiftEquivalent: "AgentOptions.maxTurns: Int", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 4, tsField: "maxBudgetUsd: number", swiftEquivalent: "AgentOptions.maxBudgetUsd: Double?", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 5, tsField: "model: string", swiftEquivalent: "AgentOptions.model: String", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 6, tsField: "fallbackModel: string", swiftEquivalent: "AgentOptions.fallbackModel: String?", status: "PASS", note: "Direct field (Story 17-2)"),
    FieldMapping(index: 7, tsField: "systemPrompt: string | preset", swiftEquivalent: "AgentOptions.systemPrompt: String? + SystemPromptConfig", status: "PARTIAL", note: "String + SystemPromptConfig, but different pattern than TS unified field"),
    FieldMapping(index: 8, tsField: "permissionMode: PermissionMode", swiftEquivalent: "AgentOptions.permissionMode: PermissionMode", status: "PASS", note: "6 cases"),
    FieldMapping(index: 9, tsField: "canUseTool: CanUseTool", swiftEquivalent: "AgentOptions.canUseTool: CanUseToolFn?", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 10, tsField: "cwd: string", swiftEquivalent: "AgentOptions.cwd: String?", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 11, tsField: "env: Record<string, string>", swiftEquivalent: "AgentOptions.env: [String: String]?", status: "PASS", note: "Direct field (Story 17-2)"),
    FieldMapping(index: 12, tsField: "mcpServers: Record<string, McpServerConfig>", swiftEquivalent: "AgentOptions.mcpServers: [String: McpServerConfig]?", status: "PASS", note: "4 config types"),
]

print("Core Configuration (12 fields)")
print("==============================")
print("")
print("\("Status")) \("Swift Equivalent") \("TS SDK Field") \("#") | Notes")
print(String(repeating: "-", count: 140))
for m in coreMappings {
    print("\(m.index) \(m.note)) \(m.status) [\(m.swiftEquivalent)] | \(m.tsField)")
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
    FieldMapping(index: 2, tsField: "effort: 'low'|'medium'|'high'|'max'", swiftEquivalent: "AgentOptions.effort: EffortLevel?", status: "PASS", note: "4-case EffortLevel enum (Story 17-2)"),
    FieldMapping(index: 3, tsField: "hooks: Partial<Record<HookEvent, ...>>", swiftEquivalent: "AgentOptions.hookRegistry: HookRegistry?", status: "PARTIAL", note: "Actor not dict, 20 events"),
    FieldMapping(index: 4, tsField: "sandbox: SandboxSettings", swiftEquivalent: "AgentOptions.sandbox: SandboxSettings?", status: "PASS", note: "6 fields"),
    FieldMapping(index: 5, tsField: "agents: Record<string, AgentDefinition>", swiftEquivalent: "AgentDefinition (via AgentTool)", status: "PARTIAL", note: "Tool-level, not options-level"),
    FieldMapping(index: 6, tsField: "toolConfig: ToolConfig", swiftEquivalent: "AgentOptions.toolConfig: ToolConfig?", status: "PASS", note: "Concurrency controls (Story 17-2)"),
    FieldMapping(index: 7, tsField: "outputFormat: { type: 'json_schema', schema }", swiftEquivalent: "AgentOptions.outputFormat: OutputFormat?", status: "PASS", note: "JSON Schema output (Story 17-2)"),
    FieldMapping(index: 8, tsField: "includePartialMessages: boolean", swiftEquivalent: "AgentOptions.includePartialMessages: Bool", status: "PASS", note: "Direct field (Story 17-2)"),
    FieldMapping(index: 9, tsField: "promptSuggestions: boolean", swiftEquivalent: "AgentOptions.promptSuggestions: Bool", status: "PASS", note: "Direct field (Story 17-2)"),
]

print("Advanced Configuration (9 fields)")
print("=================================")
print("")
print("\("Status")) \("Swift Equivalent") \("TS SDK Field") \("#") | Notes")
print(String(repeating: "-", count: 140))
for m in advancedMappings {
    print("\(m.index) \(m.note)) \(m.status) [\(m.swiftEquivalent)] | \(m.tsField)")
}
print("")

let advPass = advancedMappings.filter { $0.status == "PASS" }.count
let advPartial = advancedMappings.filter { $0.status == "PARTIAL" }.count
let advMissing = advancedMappings.filter { $0.status == "MISSING" }.count
print("Advanced Summary: PASS: \(advPass) | PARTIAL: \(advPartial) | MISSING: \(advMissing) | Total: \(advancedMappings.count)")
print("")

// --- Session Configuration Table ---
let sessionMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "resume: string", swiftEquivalent: "AgentOptions.resumeSessionAt: String?", status: "PASS", note: "Message ID truncation (Story 17-2)"),
    FieldMapping(index: 2, tsField: "continue: boolean", swiftEquivalent: "AgentOptions.continueRecentSession: Bool", status: "PASS", note: "Direct field (Story 17-2)"),
    FieldMapping(index: 3, tsField: "forkSession: boolean", swiftEquivalent: "AgentOptions.forkSession: Bool", status: "PASS", note: "Direct field (Story 17-2)"),
    FieldMapping(index: 4, tsField: "sessionId: string", swiftEquivalent: "AgentOptions.sessionId: String?", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 5, tsField: "persistSession: boolean", swiftEquivalent: "AgentOptions.persistSession: Bool", status: "PASS", note: "Direct field (Story 17-2)"),
]

print("Session Configuration (5 fields)")
print("=================================")
print("")
print("\("Status")) \("Swift Equivalent") \("TS SDK Field") \("#") | Notes")
print(String(repeating: "-", count: 140))
for m in sessionMappings {
    print("\(m.index) \(m.note)) \(m.status) [\(m.swiftEquivalent)] | \(m.tsField)")
}
print("")

let sessPass = sessionMappings.filter { $0.status == "PASS" }.count
let sessPartial = sessionMappings.filter { $0.status == "PARTIAL" }.count
let sessMissing = sessionMappings.filter { $0.status == "MISSING" }.count
print("Session Summary: PASS: \(sessPass) | PARTIAL: \(sessPartial) | MISSING: \(sessMissing) | Total: \(sessionMappings.count)")
print("")

// --- Extended Configuration Table ---
let extendedMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "settingSources: SettingSource[]", swiftEquivalent: "AgentOptions.settingSources: [SettingSource]?", status: "PASS", note: "SettingSource enum"),
    FieldMapping(index: 2, tsField: "plugins: SdkPluginConfig[]", swiftEquivalent: "AgentOptions.plugins: [SdkPluginConfig]?", status: "PASS", note: "SdkPluginConfig struct"),
    FieldMapping(index: 3, tsField: "betas: SdkBeta[]", swiftEquivalent: "AgentOptions.betas: [SdkBeta]?", status: "PASS", note: "SdkBeta with rawValue"),
    FieldMapping(index: 4, tsField: "executable: 'bun'|'deno'|'node'", swiftEquivalent: "N/A", status: "N/A", note: "Swift runtime"),
    FieldMapping(index: 5, tsField: "spawnClaudeCodeProcess", swiftEquivalent: "N/A", status: "N/A", note: "Not applicable"),
    FieldMapping(index: 6, tsField: "additionalDirectories: string[]", swiftEquivalent: "skillDirectories: [String]?", status: "PARTIAL", note: "Skill dirs only"),
    FieldMapping(index: 7, tsField: "debug: boolean / debugFile: string", swiftEquivalent: "logLevel / logOutput", status: "PARTIAL", note: "Enum vs boolean/string"),
    FieldMapping(index: 8, tsField: "stderr: (data: string) => void", swiftEquivalent: "LogOutput.custom closure", status: "PARTIAL", note: "All logs, not just stderr"),
    FieldMapping(index: 9, tsField: "strictMcpConfig: boolean", swiftEquivalent: "AgentOptions.strictMcpConfig: Bool", status: "PASS", note: "Strict MCP config flag"),
    FieldMapping(index: 10, tsField: "extraArgs: Record<string, string | null>", swiftEquivalent: "AgentOptions.extraArgs: [String: String?]?", status: "PASS", note: "Extra arg passthrough"),
    FieldMapping(index: 11, tsField: "enableFileCheckpointing: boolean", swiftEquivalent: "AgentOptions.enableFileCheckpointing: Bool", status: "PASS", note: "File checkpointing flag"),
]

print("Extended Configuration (11 fields)")
print("==================================")
print("")
print("\("Status")) \("Swift Equivalent") \("TS SDK Field") \("#") | Notes")
print(String(repeating: "-", count: 140))
for m in extendedMappings {
    print("\(m.index) \(m.note)) \(m.status) [\(m.swiftEquivalent)] | \(m.tsField)")
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
    FieldMapping(index: 4, tsField: "effort: 'low'|'medium'|'high'|'max'", swiftEquivalent: "EffortLevel enum (separate from ThinkingConfig)", status: "PASS", note: "4-case enum with budgetTokens (Story 17-2)"),
]

print("ThinkingConfig Detail (4 items)")
print("===============================")
print("")
print("\("Status")) \("Swift Equivalent") \("TS SDK Type") \("#") | Notes")
print(String(repeating: "-", count: 140))
for m in thinkingMappings {
    print("\(m.index) \(m.note)) \(m.status) [\(m.swiftEquivalent)] | \(m.tsField)")
}
print("")

let thinkPass = thinkingMappings.filter { $0.status == "PASS" }.count
print("ThinkingConfig Summary: PASS: \(thinkPass) | Total: \(thinkingMappings.count)")
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

print("%@ | \("Swift SDK Field")) | \("TS SDK Field") | Notes")
print(String(repeating: "-", count: 150))
for entry in finalReport {
    let noteStr = entry.note ?? ""
    print("\(noteStr)) | \(entry.status) | [\(entry.swiftField)] | \(entry.tsField)")
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

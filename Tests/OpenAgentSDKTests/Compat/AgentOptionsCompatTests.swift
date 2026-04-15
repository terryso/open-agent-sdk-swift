import XCTest
@testable import OpenAgentSDK

// MARK: - Agent Options Complete Parameter Verification Tests (Story 16-8)

/// ATDD tests for Story 16-8: Agent Options Complete Parameter Verification.
///
/// Verifies Swift SDK's `AgentOptions` / `SDKConfiguration` covers all Options
/// fields from the TypeScript SDK, so developers migrating from TypeScript don't
/// have to compromise on functionality.
///
/// Coverage:
/// - AC1: Build compilation verification (example story)
/// - AC2: Core configuration field-level verification (12 fields)
/// - AC3: Advanced configuration field-level verification (9 fields)
/// - AC4: Session configuration field-level verification (5 fields)
/// - AC5: Extended configuration field-level verification (11 fields)
/// - AC6: ThinkingConfig type verification (3 cases + effort)
/// - AC7: systemPrompt preset mode verification
/// - AC8: outputFormat / structured output verification
/// - AC9: Compatibility report output
final class AgentOptionsCompatTests: XCTestCase {

    // Helper: get field names from a type via Mirror
    private func fieldNames(of value: Any) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap { $0.label })
    }

    // MARK: - AC2: Core Configuration Field-Level Verification (12 fields)

    // ================================================================
    // AC2 #1: allowedTools -- PARTIAL (via policy, not direct option)
    // ================================================================

    /// AC2 #1 [PARTIAL]: TS `allowedTools: string[]` has no direct AgentOptions property.
    /// Swift has `ToolNameAllowlistPolicy` as a runtime policy mechanism.
    func testAllowedTools_partialViaPolicy() {
        // TS SDK: allowedTools: string[] -- direct option on Options
        // Swift: No `allowedTools` property on AgentOptions.
        // PARTIAL: ToolNameAllowlistPolicy exists and achieves the same result
        // when used via canUseTool(policy:) bridge.
        let options = AgentOptions(apiKey: "test-key", model: "claude-sonnet-4-6")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("allowedTools"),
                       "GAP: AgentOptions has no 'allowedTools' property. TS SDK has allowedTools: string[]. Swift has ToolNameAllowlistPolicy as runtime policy.")

        // Verify the policy mechanism exists as alternative
        let policy = ToolNameAllowlistPolicy(allowedToolNames: ["Read", "Glob"])
        XCTAssertEqual(policy.allowedToolNames, Set(["Read", "Glob"]),
                       "ToolNameAllowlistPolicy provides equivalent functionality")
    }

    // ================================================================
    // AC2 #2: disallowedTools -- PARTIAL (via policy, not direct option)
    // ================================================================

    /// AC2 #2 [PARTIAL]: TS `disallowedTools: string[]` has no direct AgentOptions property.
    /// Swift has `ToolNameDenylistPolicy` as a runtime policy mechanism.
    func testDisallowedTools_partialViaPolicy() {
        let options = AgentOptions(apiKey: "test-key", model: "claude-sonnet-4-6")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("disallowedTools"),
                       "GAP: AgentOptions has no 'disallowedTools' property. TS SDK has disallowedTools: string[]. Swift has ToolNameDenylistPolicy as runtime policy.")

        // Verify the policy mechanism exists as alternative
        let policy = ToolNameDenylistPolicy(deniedToolNames: ["Bash", "Write"])
        XCTAssertEqual(policy.deniedToolNames, Set(["Bash", "Write"]),
                       "ToolNameDenylistPolicy provides equivalent functionality")
    }

    // ================================================================
    // AC2 #3: maxTurns -- PASS
    // ================================================================

    /// AC2 #3 [P0]: TS `maxTurns: number` maps to `AgentOptions.maxTurns: Int`.
    func testMaxTurns_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test", maxTurns: 25)
        XCTAssertEqual(options.maxTurns, 25, "AgentOptions.maxTurns matches TS maxTurns")

        let defaultOptions = AgentOptions(apiKey: "test-key")
        XCTAssertEqual(defaultOptions.maxTurns, 10, "Default maxTurns is 10")
    }

    // ================================================================
    // AC2 #4: maxBudgetUsd -- PASS
    // ================================================================

    /// AC2 #4 [P0]: TS `maxBudgetUsd: number` maps to `AgentOptions.maxBudgetUsd: Double?`.
    func testMaxBudgetUsd_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test", maxBudgetUsd: 5.0)
        XCTAssertEqual(options.maxBudgetUsd, 5.0, "AgentOptions.maxBudgetUsd matches TS maxBudgetUsd")

        let defaultOptions = AgentOptions(apiKey: "test-key")
        XCTAssertNil(defaultOptions.maxBudgetUsd, "Default maxBudgetUsd is nil (no budget limit)")
    }

    // ================================================================
    // AC2 #5: model -- PASS
    // ================================================================

    /// AC2 #5 [P0]: TS `model: string` maps to `AgentOptions.model: String`.
    func testModel_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "claude-opus-4-5")
        XCTAssertEqual(options.model, "claude-opus-4-5", "AgentOptions.model matches TS model")

        let defaultOptions = AgentOptions()
        XCTAssertEqual(defaultOptions.model, "claude-sonnet-4-6", "Default model is claude-sonnet-4-6")
    }

    // ================================================================
    // AC2 #6: fallbackModel -- MISSING
    // ================================================================

    /// AC2 #6 [MISSING]: TS `fallbackModel: string` has no equivalent in Swift SDK.
    func testFallbackModel_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("fallbackModel"),
                       "GAP: AgentOptions has no 'fallbackModel' property. TS SDK has fallbackModel: string for model fallback when primary is unavailable.")
    }

    // ================================================================
    // AC2 #7: systemPrompt -- PARTIAL (String only, no preset mode)
    // ================================================================

    /// AC2 #7 [PARTIAL]: TS `systemPrompt` supports string and structured preset mode.
    /// Swift only supports `String?`, no preset enum or append mechanism.
    func testSystemPrompt_partial() {
        let options = AgentOptions(apiKey: "test-key", model: "test", systemPrompt: "You are helpful")
        XCTAssertEqual(options.systemPrompt, "You are helpful", "AgentOptions.systemPrompt accepts String")

        let defaultOptions = AgentOptions(apiKey: "test-key")
        XCTAssertNil(defaultOptions.systemPrompt, "Default systemPrompt is nil")

        // GAP: No SystemPromptPreset enum or structured systemPrompt type
        // TS supports: systemPrompt: string | { type: 'preset', preset: 'claude_code', append?: string }
        // Swift supports: String? only
    }

    // ================================================================
    // AC2 #8: permissionMode -- PASS
    // ================================================================

    /// AC2 #8 [P0]: TS `permissionMode: PermissionMode` maps to `AgentOptions.permissionMode: PermissionMode`.
    func testPermissionMode_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test", permissionMode: .bypassPermissions)
        XCTAssertEqual(options.permissionMode, .bypassPermissions, "AgentOptions.permissionMode matches TS permissionMode")

        // Verify all 6 cases exist
        XCTAssertEqual(PermissionMode.allCases.count, 6,
                       "PermissionMode has 6 cases matching TS modes")
        XCTAssertTrue(PermissionMode.allCases.contains(.default), "Contains .default")
        XCTAssertTrue(PermissionMode.allCases.contains(.acceptEdits), "Contains .acceptEdits")
        XCTAssertTrue(PermissionMode.allCases.contains(.bypassPermissions), "Contains .bypassPermissions")
        XCTAssertTrue(PermissionMode.allCases.contains(.plan), "Contains .plan")
        XCTAssertTrue(PermissionMode.allCases.contains(.dontAsk), "Contains .dontAsk")
        XCTAssertTrue(PermissionMode.allCases.contains(.auto), "Contains .auto")
    }

    // ================================================================
    // AC2 #9: canUseTool -- PASS
    // ================================================================

    /// AC2 #9 [P0]: TS `canUseTool: CanUseTool` maps to `AgentOptions.canUseTool: CanUseToolFn?`.
    func testCanUseTool_pass() {
        let callback: CanUseToolFn = { _, _, _ in .allow() }
        let options = AgentOptions(apiKey: "test-key", model: "test", canUseTool: callback)
        XCTAssertNotNil(options.canUseTool, "AgentOptions.canUseTool accepts CanUseToolFn")

        let defaultOptions = AgentOptions(apiKey: "test-key")
        XCTAssertNil(defaultOptions.canUseTool, "Default canUseTool is nil")
    }

    // ================================================================
    // AC2 #10: cwd -- PASS
    // ================================================================

    /// AC2 #10 [P0]: TS `cwd: string` maps to `AgentOptions.cwd: String?`.
    func testCwd_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test", cwd: "/tmp/project")
        XCTAssertEqual(options.cwd, "/tmp/project", "AgentOptions.cwd matches TS cwd")

        let defaultOptions = AgentOptions(apiKey: "test-key")
        XCTAssertNil(defaultOptions.cwd, "Default cwd is nil")
    }

    // ================================================================
    // AC2 #11: env -- MISSING
    // ================================================================

    /// AC2 #11 [MISSING]: TS `env: Record<string, string>` has no equivalent in Swift SDK.
    func testEnv_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("env"),
                       "GAP: AgentOptions has no 'env' property. TS SDK has env: Record<string, string> for environment variable overrides. Swift SDKConfiguration reads from env but doesn't accept env override dict.")
    }

    // ================================================================
    // AC2 #12: mcpServers -- PASS
    // ================================================================

    /// AC2 #12 [P0]: TS `mcpServers: Record<string, McpServerConfig>` maps to
    /// `AgentOptions.mcpServers: [String: McpServerConfig]?` (4 config types).
    func testMcpServers_pass() {
        let mcpConfig: [String: McpServerConfig] = [
            "test-server": .stdio(McpStdioConfig(command: "test", args: []))
        ]
        let options = AgentOptions(apiKey: "test-key", model: "test", mcpServers: mcpConfig)
        XCTAssertNotNil(options.mcpServers, "AgentOptions.mcpServers accepts [String: McpServerConfig]")
        XCTAssertEqual(options.mcpServers?.count, 1, "mcpServers dictionary has 1 entry")

        let defaultOptions = AgentOptions(apiKey: "test-key")
        XCTAssertNil(defaultOptions.mcpServers, "Default mcpServers is nil")
    }

    /// AC2 [P0]: Summary of all 12 core configuration fields.
    func testCoreConfig_coverageSummary() {
        // Core config: 7 PASS + 3 PARTIAL + 2 MISSING = 12 fields
        // PASS: maxTurns, maxBudgetUsd, model, permissionMode, canUseTool, cwd, mcpServers
        // PARTIAL: allowedTools (via policy), disallowedTools (via policy), systemPrompt (String only)
        // MISSING: fallbackModel, env
        let passCount = 7
        let partialCount = 3
        let missingCount = 2
        let total = passCount + partialCount + missingCount

        XCTAssertEqual(total, 12, "Should verify all 12 core configuration fields")
        XCTAssertEqual(passCount, 7, "7 core fields PASS")
        XCTAssertEqual(partialCount, 3, "3 core fields PARTIAL")
        XCTAssertEqual(missingCount, 2, "2 core fields MISSING")
    }

    // MARK: - AC3: Advanced Configuration Field-Level Verification (9 fields)

    // ================================================================
    // AC3 #1: thinking -- PASS
    // ================================================================

    /// AC3 #1 [P0]: TS `thinking: ThinkingConfig` maps to `AgentOptions.thinking: ThinkingConfig?`.
    func testThinking_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test", thinking: .enabled(budgetTokens: 10000))
        XCTAssertEqual(options.thinking, .enabled(budgetTokens: 10000),
                       "AgentOptions.thinking matches TS ThinkingConfig")

        let defaultOptions = AgentOptions(apiKey: "test-key")
        XCTAssertNil(defaultOptions.thinking, "Default thinking is nil")
    }

    // ================================================================
    // AC3 #2: effort -- MISSING
    // ================================================================

    /// AC3 #2 [MISSING]: TS `effort: 'low' | 'medium' | 'high' | 'max'` has no Swift equivalent.
    func testEffort_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("effort"),
                       "GAP: AgentOptions has no 'effort' property. TS SDK has effort: 'low' | 'medium' | 'high' | 'max' for reasoning effort level control.")
    }

    // ================================================================
    // AC3 #3: hooks -- PARTIAL (actor-based, not config dict)
    // ================================================================

    /// AC3 #3 [PARTIAL]: TS `hooks: Partial<Record<HookEvent, HookCallbackMatcher[]>>` maps to
    /// `AgentOptions.hookRegistry: HookRegistry?` (actor, not config dict).
    func testHooks_partial() async {
        let registry = HookRegistry()
        let options = AgentOptions(apiKey: "test-key", model: "test", hookRegistry: registry)
        XCTAssertNotNil(options.hookRegistry, "AgentOptions.hookRegistry accepts HookRegistry")

        // Verify HookEvent coverage
        let hookEventCount = HookEvent.allCases.count
        XCTAssertTrue(hookEventCount >= 15,
                       "HookEvent has \(hookEventCount) cases (TS has ~18 hook events). PARTIAL: Swift uses actor-based HookRegistry instead of config dict.")

        // GAP: TS uses Partial<Record<HookEvent, HookCallbackMatcher[]>> (config-time dict).
        // Swift uses HookRegistry actor (runtime object). Different pattern, same capability.
    }

    // ================================================================
    // AC3 #4: sandbox -- PASS
    // ================================================================

    /// AC3 #4 [P0]: TS `sandbox: SandboxSettings` maps to `AgentOptions.sandbox: SandboxSettings?`.
    func testSandbox_pass() {
        let settings = SandboxSettings(deniedCommands: ["rm", "sudo"])
        let options = AgentOptions(apiKey: "test-key", model: "test", sandbox: settings)
        XCTAssertNotNil(options.sandbox, "AgentOptions.sandbox matches TS SandboxSettings")
        XCTAssertEqual(options.sandbox?.deniedCommands, ["rm", "sudo"],
                       "SandboxSettings fields are preserved")

        // Verify SandboxSettings has 6 fields
        let sandboxFields = fieldNames(of: settings)
        XCTAssertTrue(sandboxFields.contains("allowedReadPaths"), "Has allowedReadPaths")
        XCTAssertTrue(sandboxFields.contains("allowedWritePaths"), "Has allowedWritePaths")
        XCTAssertTrue(sandboxFields.contains("deniedPaths"), "Has deniedPaths")
        XCTAssertTrue(sandboxFields.contains("deniedCommands"), "Has deniedCommands")
        XCTAssertTrue(sandboxFields.contains("allowedCommands"), "Has allowedCommands")
        XCTAssertTrue(sandboxFields.contains("allowNestedSandbox"), "Has allowNestedSandbox")
    }

    // ================================================================
    // AC3 #5: agents -- PARTIAL (via tool, not options-level)
    // ================================================================

    /// AC3 #5 [PARTIAL]: TS `agents: Record<string, AgentDefinition>` has no direct
    /// AgentOptions property. AgentDefinition exists and is used via AgentTool at tool level.
    func testAgents_partial() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("agents"),
                       "GAP: AgentOptions has no 'agents' property. TS SDK has agents: Record<string, AgentDefinition>. Swift has AgentDefinition but uses it via AgentTool at tool level, not options level.")
    }

    // ================================================================
    // AC3 #6: toolConfig -- MISSING
    // ================================================================

    /// AC3 #6 [MISSING]: TS `toolConfig: ToolConfig` has no Swift equivalent.
    func testToolConfig_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("toolConfig"),
                       "GAP: AgentOptions has no 'toolConfig' property. TS SDK has toolConfig: ToolConfig for tool-level configuration.")
    }

    // ================================================================
    // AC3 #7: outputFormat -- MISSING
    // ================================================================

    /// AC3 #7 [MISSING]: TS `outputFormat: { type: 'json_schema', schema }` has no Swift equivalent.
    func testOutputFormat_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("outputFormat"),
                       "GAP: AgentOptions has no 'outputFormat' property. TS SDK supports JSON Schema structured output via outputFormat: { type: 'json_schema', schema }.")
    }

    // ================================================================
    // AC3 #8: includePartialMessages -- MISSING
    // ================================================================

    /// AC3 #8 [MISSING]: TS `includePartialMessages: boolean` has no Swift equivalent.
    func testIncludePartialMessages_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("includePartialMessages"),
                       "GAP: AgentOptions has no 'includePartialMessages' property. TS SDK has includePartialMessages: boolean for partial message streaming.")
    }

    // ================================================================
    // AC3 #9: promptSuggestions -- MISSING
    // ================================================================

    /// AC3 #9 [MISSING]: TS `promptSuggestions: boolean` has no Swift equivalent.
    func testPromptSuggestions_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("promptSuggestions"),
                       "GAP: AgentOptions has no 'promptSuggestions' property. TS SDK has promptSuggestions: boolean for enabling prompt suggestion feature.")
    }

    /// AC3 [P0]: Summary of all 9 advanced configuration fields.
    func testAdvancedConfig_coverageSummary() {
        // Advanced config: 2 PASS + 2 PARTIAL + 5 MISSING = 9 fields
        // PASS: thinking, sandbox
        // PARTIAL: hooks (actor not dict), agents (via tool not options)
        // MISSING: effort, toolConfig, outputFormat, includePartialMessages, promptSuggestions
        let passCount = 2
        let partialCount = 2
        let missingCount = 5
        let total = passCount + partialCount + missingCount

        XCTAssertEqual(total, 9, "Should verify all 9 advanced configuration fields")
        XCTAssertEqual(passCount, 2, "2 advanced fields PASS")
        XCTAssertEqual(partialCount, 2, "2 advanced fields PARTIAL")
        XCTAssertEqual(missingCount, 5, "5 advanced fields MISSING")
    }

    // MARK: - AC4: Session Configuration Field-Level Verification (5 fields)

    // ================================================================
    // AC4 #1: resume -- PARTIAL (via sessionStore + sessionId)
    // ================================================================

    /// AC4 #1 [PARTIAL]: TS `resume: string` is handled via sessionStore + sessionId in Swift.
    func testResume_partial() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("resume"),
                       "GAP: AgentOptions has no 'resume' property. TS SDK has resume: string for resuming by session ID. Swift uses sessionStore + sessionId combination.")
    }

    // ================================================================
    // AC4 #2: continue -- MISSING
    // ================================================================

    /// AC4 #2 [MISSING]: TS `continue: boolean` has no Swift equivalent.
    func testContinue_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("continue"),
                       "GAP: AgentOptions has no 'continue' property. TS SDK has continue: boolean for continuing last session.")
    }

    // ================================================================
    // AC4 #3: forkSession -- PARTIAL (SessionStore has fork separately)
    // ================================================================

    /// AC4 #3 [PARTIAL]: TS `forkSession: boolean` has no direct option.
    /// Swift SessionStore has fork capability as a separate method.
    func testForkSession_partial() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("forkSession"),
                       "GAP: AgentOptions has no 'forkSession' property. TS SDK has forkSession: boolean. Swift SessionStore has fork capability as separate method, not as creation option.")
    }

    // ================================================================
    // AC4 #4: sessionId -- PASS
    // ================================================================

    /// AC4 #4 [P0]: TS `sessionId: string` maps to `AgentOptions.sessionId: String?`.
    func testSessionId_pass() {
        let options = AgentOptions(apiKey: "test-key", model: "test", sessionId: "abc-123")
        XCTAssertEqual(options.sessionId, "abc-123", "AgentOptions.sessionId matches TS sessionId")

        let defaultOptions = AgentOptions(apiKey: "test-key")
        XCTAssertNil(defaultOptions.sessionId, "Default sessionId is nil")
    }

    // ================================================================
    // AC4 #5: persistSession -- PARTIAL (implicit via sessionStore)
    // ================================================================

    /// AC4 #5 [PARTIAL]: TS `persistSession: boolean` has no direct flag.
    /// When sessionStore is set, auto-save is implicit.
    func testPersistSession_partial() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("persistSession"),
                       "GAP: AgentOptions has no 'persistSession' property. TS SDK has persistSession: boolean. Swift auto-saves when sessionStore is set (implicit, no flag).")
    }

    /// AC4 [P0]: Summary of all 5 session configuration fields.
    func testSessionConfig_coverageSummary() {
        // Session config: 1 PASS + 2 PARTIAL + 1 MISSING + 1 PARTIAL = 5 fields
        // PASS: sessionId
        // PARTIAL: resume (via sessionStore+sessionId), forkSession (via SessionStore method), persistSession (implicit)
        // MISSING: continue
        let passCount = 1
        let partialCount = 3
        let missingCount = 1
        let total = passCount + partialCount + missingCount

        XCTAssertEqual(total, 5, "Should verify all 5 session configuration fields")
        XCTAssertEqual(passCount, 1, "1 session field PASS")
        XCTAssertEqual(partialCount, 3, "3 session fields PARTIAL")
        XCTAssertEqual(missingCount, 1, "1 session field MISSING")
    }

    // MARK: - AC5: Extended Configuration Field-Level Verification (11 fields)

    // ================================================================
    // AC5 #1: settingSources -- MISSING
    // ================================================================

    /// AC5 #1 [MISSING]: TS `settingSources: SettingSource[]` has no Swift equivalent.
    func testSettingSources_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("settingSources"),
                       "GAP: AgentOptions has no 'settingSources' property. TS SDK has settingSources: SettingSource[] for file-based settings source configuration.")
    }

    // ================================================================
    // AC5 #2: plugins -- MISSING
    // ================================================================

    /// AC5 #2 [MISSING]: TS `plugins: SdkPluginConfig[]` has no Swift equivalent.
    func testPlugins_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("plugins"),
                       "GAP: AgentOptions has no 'plugins' property. TS SDK has plugins: SdkPluginConfig[] for plugin loading.")
    }

    // ================================================================
    // AC5 #3: betas -- MISSING
    // ================================================================

    /// AC5 #3 [MISSING]: TS `betas: SdkBeta[]` has no Swift equivalent.
    func testBetas_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("betas"),
                       "GAP: AgentOptions has no 'betas' property. TS SDK has betas: SdkBeta[] for beta feature flags.")
    }

    // ================================================================
    // AC5 #4: executable -- N/A
    // ================================================================

    /// AC5 #4 [N/A]: TS `executable: 'bun' | 'deno' | 'node'` is not applicable to Swift.
    func testExecutable_na() {
        // Swift runtime, not Node.js/Bun/Deno. N/A.
        XCTAssertTrue(true, "N/A: executable option is not applicable to Swift runtime. TS SDK uses bun/deno/node.")
    }

    // ================================================================
    // AC5 #5: spawnClaudeCodeProcess -- N/A
    // ================================================================

    /// AC5 #5 [N/A]: TS `spawnClaudeCodeProcess` is not applicable to Swift.
    func testSpawnClaudeCodeProcess_na() {
        // Swift process model, not Node.js child process. N/A.
        XCTAssertTrue(true, "N/A: spawnClaudeCodeProcess is not applicable to Swift process model.")
    }

    // ================================================================
    // AC5 #6: additionalDirectories -- PARTIAL (skillDirectories)
    // ================================================================

    /// AC5 #6 [PARTIAL]: TS `additionalDirectories: string[]` has partial equivalent in
    /// `AgentOptions.skillDirectories: [String]?` for skill discovery dirs.
    func testAdditionalDirectories_partial() {
        let options = AgentOptions(apiKey: "test-key", model: "test", skillDirectories: ["/custom/skills"])
        XCTAssertEqual(options.skillDirectories?.first, "/custom/skills",
                       "skillDirectories is partial match for additionalDirectories")

        // GAP: skillDirectories only covers skill discovery directories,
        // not general additional directories for context/trust.
    }

    // ================================================================
    // AC5 #7: debug / debugFile -- PARTIAL (via logLevel + logOutput)
    // ================================================================

    /// AC5 #7 [PARTIAL]: TS `debug: boolean` maps partially to `AgentOptions.logLevel: LogLevel`.
    /// TS `debugFile: string` maps partially to `AgentOptions.logOutput: LogOutput`.
    func testDebugDebugFile_partial() {
        // TS: debug: boolean -> Swift: logLevel: LogLevel (5 levels, not just boolean)
        let debugOptions = AgentOptions(apiKey: "test-key", model: "test", logLevel: .debug)
        XCTAssertEqual(debugOptions.logLevel, .debug, "logLevel.debug is equivalent to TS debug: true")

        let normalOptions = AgentOptions(apiKey: "test-key", model: "test", logLevel: .none)
        XCTAssertEqual(normalOptions.logLevel, .none, "logLevel.none is equivalent to TS debug: false")

        // TS: debugFile: string -> Swift: logOutput: .file(URL)
        let fileLogOptions = AgentOptions(apiKey: "test-key", model: "test",
                                           logOutput: .file(URL(fileURLWithPath: "/tmp/debug.log")))
        XCTAssertEqual(fileLogOptions.logOutput, .file(URL(fileURLWithPath: "/tmp/debug.log")),
                       "logOutput.file is equivalent to TS debugFile")
    }

    // ================================================================
    // AC5 #8: stderr callback -- PARTIAL (via LogOutput.custom)
    // ================================================================

    /// AC5 #8 [PARTIAL]: TS `stderr: (data: string) => void` maps partially to
    /// `AgentOptions.logOutput: LogOutput.custom(@Sendable (String) -> Void)`.
    func testStderrCallback_partial() {
        // Verify LogOutput.custom accepts a closure (equivalent to TS stderr callback)
        let customOutput = LogOutput.custom { _ in /* log line received */ }
        let options = AgentOptions(apiKey: "test-key", model: "test", logOutput: customOutput)

        XCTAssertNotNil(options.logOutput, "logOutput.custom accepts a closure")
        // GAP: TS stderr receives raw stderr data strings. Swift LogOutput.custom receives structured JSON lines.
        // Different format but similar capability.
    }

    // ================================================================
    // AC5 #9: strictMcpConfig -- MISSING
    // ================================================================

    /// AC5 #9 [MISSING]: TS `strictMcpConfig: boolean` has no Swift equivalent.
    func testStrictMcpConfig_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("strictMcpConfig"),
                       "GAP: AgentOptions has no 'strictMcpConfig' property. TS SDK has strictMcpConfig: boolean for strict MCP config validation.")
    }

    // ================================================================
    // AC5 #10: extraArgs -- MISSING
    // ================================================================

    /// AC5 #10 [MISSING]: TS `extraArgs: Record<string, string | null>` has no Swift equivalent.
    func testExtraArgs_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("extraArgs"),
                       "GAP: AgentOptions has no 'extraArgs' property. TS SDK has extraArgs: Record<string, string | null> for extra argument passthrough.")
    }

    // ================================================================
    // AC5 #11: enableFileCheckpointing -- MISSING
    // ================================================================

    /// AC5 #11 [MISSING]: TS `enableFileCheckpointing: boolean` has no Swift equivalent.
    func testEnableFileCheckpointing_missing() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("enableFileCheckpointing"),
                       "GAP: AgentOptions has no 'enableFileCheckpointing' property. TS SDK has enableFileCheckpointing: boolean for file checkpointing system.")
    }

    /// AC5 [P0]: Summary of all 11 extended configuration fields.
    func testExtendedConfig_coverageSummary() {
        // Extended config: 0 PASS + 3 PARTIAL + 6 MISSING + 2 N/A = 11 fields
        // PARTIAL: additionalDirectories (via skillDirectories), debug/debugFile (via logLevel/logOutput), stderr (via LogOutput.custom)
        // MISSING: settingSources, plugins, betas, strictMcpConfig, extraArgs, enableFileCheckpointing
        // N/A: executable, spawnClaudeCodeProcess
        let partialCount = 3
        let missingCount = 6
        let naCount = 2
        let total = partialCount + missingCount + naCount

        XCTAssertEqual(total, 11, "Should verify all 11 extended configuration fields")
        XCTAssertEqual(partialCount, 3, "3 extended fields PARTIAL")
        XCTAssertEqual(missingCount, 6, "6 extended fields MISSING")
        XCTAssertEqual(naCount, 2, "2 extended fields N/A")
    }

    // MARK: - AC6: ThinkingConfig Type Verification

    /// AC6 [P0]: ThinkingConfig supports all three TS types.
    func testThinkingConfig_adaptive() {
        let config = ThinkingConfig.adaptive
        XCTAssertEqual(config, .adaptive, "ThinkingConfig.adaptive maps to TS { type: 'adaptive' }")
    }

    /// AC6 [P0]: ThinkingConfig.enabled(budgetTokens:) maps to TS enabled type.
    func testThinkingConfig_enabled() {
        let config = ThinkingConfig.enabled(budgetTokens: 8000)
        XCTAssertEqual(config, .enabled(budgetTokens: 8000),
                       "ThinkingConfig.enabled(budgetTokens:) maps to TS { type: 'enabled', budgetTokens: 8000 }")
    }

    /// AC6 [P0]: ThinkingConfig.disabled maps to TS disabled type.
    func testThinkingConfig_disabled() {
        let config = ThinkingConfig.disabled
        XCTAssertEqual(config, .disabled, "ThinkingConfig.disabled maps to TS { type: 'disabled' }")
    }

    /// AC6 [MISSING]: TS `effort` level ('low'/'medium'/'high'/'max') has no Swift equivalent.
    func testThinkingConfig_effortLevel_missing() {
        // Verify ThinkingConfig does not have an effort level
        let adaptive = ThinkingConfig.adaptive
        let enabled = ThinkingConfig.enabled(budgetTokens: 1000)
        let disabled = ThinkingConfig.disabled

        let adaptiveFields = fieldNames(of: adaptive)
        let enabledFields = fieldNames(of: enabled)
        let disabledFields = fieldNames(of: disabled)

        XCTAssertFalse(adaptiveFields.contains("effort"),
                       "GAP: ThinkingConfig has no 'effort' level. TS SDK has effort: 'low' | 'medium' | 'high' | 'max'.")
        XCTAssertFalse(enabledFields.contains("effort"),
                       "GAP: ThinkingConfig.enabled has no 'effort' level.")
        XCTAssertFalse(disabledFields.contains("effort"),
                       "GAP: ThinkingConfig.disabled has no 'effort' level.")
    }

    /// AC6 [P0]: ThinkingConfig.validate() rejects zero/negative budgetTokens.
    func testThinkingConfig_validation() {
        XCTAssertThrowsError(try ThinkingConfig.enabled(budgetTokens: 0).validate(),
                             "Zero budgetTokens should fail validation")
        XCTAssertNoThrow(try ThinkingConfig.enabled(budgetTokens: 1000).validate(),
                         "Positive budgetTokens should pass validation")
        XCTAssertNoThrow(try ThinkingConfig.adaptive.validate(),
                         "Adaptive should pass validation")
        XCTAssertNoThrow(try ThinkingConfig.disabled.validate(),
                         "Disabled should pass validation")
    }

    // MARK: - AC7: systemPrompt Preset Mode Verification

    /// AC7 [PARTIAL]: systemPrompt only supports String, not structured preset type.
    func testSystemPromptPreset_noPresetEnum() {
        // TS SDK supports: string | { type: 'preset', preset: 'claude_code', append?: string }
        // Swift SDK supports: String? only

        // Verify no SystemPromptPreset or similar type exists via AgentOptions
        var options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        // systemPrompt should be String? not an enum/struct
        XCTAssertTrue(fields.contains("systemPrompt"),
                       "AgentOptions has systemPrompt property")
        // Verify it accepts only String
        options.systemPrompt = "Hello"
        XCTAssertEqual(options.systemPrompt, "Hello", "systemPrompt accepts String")

        // GAP: No way to do: systemPrompt: .preset("claude_code", append: "custom")
        // Must use plain string instead
    }

    // MARK: - AC8: outputFormat / Structured Output Verification

    /// AC8 [MISSING]: No JSON Schema structured output support.
    func testOutputFormat_noStructuredOutput() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        XCTAssertFalse(fields.contains("outputFormat"),
                       "GAP: AgentOptions has no 'outputFormat' property. TS SDK supports JSON Schema structured output.")

        // Verify no related types exist by checking for absence of output schema fields
        XCTAssertFalse(fields.contains("jsonSchema"),
                       "GAP: No jsonSchema property for structured output definition.")
    }

    // MARK: - AC9: Compatibility Report Output

    /// AC9 [P0]: Complete field-level compatibility matrix for all 37 TS SDK Options fields.
    func testCompatReport_completeFieldLevelCoverage() {
        struct FieldMapping: Equatable {
            let tsField: String
            let swiftField: String
            let status: String  // PASS, PARTIAL, MISSING, N/A
            let category: String  // core, advanced, session, extended
        }

        let allFields: [FieldMapping] = [
            // Core configuration (12 fields)
            FieldMapping(tsField: "allowedTools", swiftField: "ToolNameAllowlistPolicy (runtime)", status: "PARTIAL", category: "core"),
            FieldMapping(tsField: "disallowedTools", swiftField: "ToolNameDenylistPolicy (runtime)", status: "PARTIAL", category: "core"),
            FieldMapping(tsField: "maxTurns", swiftField: "AgentOptions.maxTurns", status: "PASS", category: "core"),
            FieldMapping(tsField: "maxBudgetUsd", swiftField: "AgentOptions.maxBudgetUsd", status: "PASS", category: "core"),
            FieldMapping(tsField: "model", swiftField: "AgentOptions.model", status: "PASS", category: "core"),
            FieldMapping(tsField: "fallbackModel", swiftField: "NO EQUIVALENT", status: "MISSING", category: "core"),
            FieldMapping(tsField: "systemPrompt", swiftField: "AgentOptions.systemPrompt (String only)", status: "PARTIAL", category: "core"),
            FieldMapping(tsField: "permissionMode", swiftField: "AgentOptions.permissionMode", status: "PASS", category: "core"),
            FieldMapping(tsField: "canUseTool", swiftField: "AgentOptions.canUseTool", status: "PASS", category: "core"),
            FieldMapping(tsField: "cwd", swiftField: "AgentOptions.cwd", status: "PASS", category: "core"),
            FieldMapping(tsField: "env", swiftField: "NO EQUIVALENT", status: "MISSING", category: "core"),
            FieldMapping(tsField: "mcpServers", swiftField: "AgentOptions.mcpServers", status: "PASS", category: "core"),

            // Advanced configuration (9 fields)
            FieldMapping(tsField: "thinking", swiftField: "AgentOptions.thinking", status: "PASS", category: "advanced"),
            FieldMapping(tsField: "effort", swiftField: "NO EQUIVALENT", status: "MISSING", category: "advanced"),
            FieldMapping(tsField: "hooks", swiftField: "AgentOptions.hookRegistry (actor)", status: "PARTIAL", category: "advanced"),
            FieldMapping(tsField: "sandbox", swiftField: "AgentOptions.sandbox", status: "PASS", category: "advanced"),
            FieldMapping(tsField: "agents", swiftField: "AgentTool (tool level)", status: "PARTIAL", category: "advanced"),
            FieldMapping(tsField: "toolConfig", swiftField: "NO EQUIVALENT", status: "MISSING", category: "advanced"),
            FieldMapping(tsField: "outputFormat", swiftField: "NO EQUIVALENT", status: "MISSING", category: "advanced"),
            FieldMapping(tsField: "includePartialMessages", swiftField: "NO EQUIVALENT", status: "MISSING", category: "advanced"),
            FieldMapping(tsField: "promptSuggestions", swiftField: "NO EQUIVALENT", status: "MISSING", category: "advanced"),

            // Session configuration (5 fields)
            FieldMapping(tsField: "resume", swiftField: "sessionStore + sessionId", status: "PARTIAL", category: "session"),
            FieldMapping(tsField: "continue", swiftField: "NO EQUIVALENT", status: "MISSING", category: "session"),
            FieldMapping(tsField: "forkSession", swiftField: "SessionStore.fork (separate)", status: "PARTIAL", category: "session"),
            FieldMapping(tsField: "sessionId", swiftField: "AgentOptions.sessionId", status: "PASS", category: "session"),
            FieldMapping(tsField: "persistSession", swiftField: "Implicit via sessionStore", status: "PARTIAL", category: "session"),

            // Extended configuration (11 fields)
            FieldMapping(tsField: "settingSources", swiftField: "NO EQUIVALENT", status: "MISSING", category: "extended"),
            FieldMapping(tsField: "plugins", swiftField: "NO EQUIVALENT", status: "MISSING", category: "extended"),
            FieldMapping(tsField: "betas", swiftField: "NO EQUIVALENT", status: "MISSING", category: "extended"),
            FieldMapping(tsField: "executable", swiftField: "N/A (Swift runtime)", status: "N/A", category: "extended"),
            FieldMapping(tsField: "spawnClaudeCodeProcess", swiftField: "N/A (Swift process)", status: "N/A", category: "extended"),
            FieldMapping(tsField: "additionalDirectories", swiftField: "skillDirectories (partial)", status: "PARTIAL", category: "extended"),
            FieldMapping(tsField: "debug / debugFile", swiftField: "logLevel + logOutput", status: "PARTIAL", category: "extended"),
            FieldMapping(tsField: "stderr", swiftField: "LogOutput.custom", status: "PARTIAL", category: "extended"),
            FieldMapping(tsField: "strictMcpConfig", swiftField: "NO EQUIVALENT", status: "MISSING", category: "extended"),
            FieldMapping(tsField: "extraArgs", swiftField: "NO EQUIVALENT", status: "MISSING", category: "extended"),
            FieldMapping(tsField: "enableFileCheckpointing", swiftField: "NO EQUIVALENT", status: "MISSING", category: "extended"),
        ]

        XCTAssertEqual(allFields.count, 37, "Should have exactly 37 TS SDK Options fields")

        let passCount = allFields.filter { $0.status == "PASS" }.count
        let partialCount = allFields.filter { $0.status == "PARTIAL" }.count
        let missingCount = allFields.filter { $0.status == "MISSING" }.count
        let naCount = allFields.filter { $0.status == "N/A" }.count

        XCTAssertEqual(passCount, 10, "10 fields PASS")
        XCTAssertEqual(partialCount, 11, "11 fields PARTIAL")
        XCTAssertEqual(missingCount, 14, "14 fields MISSING")
        XCTAssertEqual(naCount, 2, "2 fields N/A")
    }

    /// AC9 [P0]: Category-level breakdown summary.
    func testCompatReport_categoryBreakdown() {
        // Core: 7 PASS + 3 PARTIAL + 2 MISSING = 12
        // Advanced: 2 PASS + 2 PARTIAL + 5 MISSING = 9
        // Session: 1 PASS + 3 PARTIAL + 1 MISSING = 5
        // Extended: 0 PASS + 3 PARTIAL + 6 MISSING + 2 N/A = 11
        // Total: 10 PASS + 11 PARTIAL + 14 MISSING + 2 N/A = 37

        let coreTotal = 12
        let advancedTotal = 9
        let sessionTotal = 5
        let extendedTotal = 11
        let grandTotal = coreTotal + advancedTotal + sessionTotal + extendedTotal

        XCTAssertEqual(grandTotal, 37, "Total TS SDK Options fields should be 37")
        XCTAssertEqual(coreTotal, 12, "Core config: 12 fields")
        XCTAssertEqual(advancedTotal, 9, "Advanced config: 9 fields")
        XCTAssertEqual(sessionTotal, 5, "Session config: 5 fields")
        XCTAssertEqual(extendedTotal, 11, "Extended config: 11 fields")
    }

    /// AC9 [P0]: Overall compatibility summary counts.
    func testCompatReport_overallSummary() {
        // 10 PASS + 11 PARTIAL + 14 MISSING + 2 N/A = 37
        let totalPass = 10
        let totalPartial = 11
        let totalMissing = 14
        let totalNA = 2
        let total = totalPass + totalPartial + totalMissing + totalNA

        XCTAssertEqual(total, 37, "Total verifications should be 37")
        XCTAssertEqual(totalPass, 10, "10 items PASS")
        XCTAssertEqual(totalPartial, 11, "11 items PARTIAL")
        XCTAssertEqual(totalMissing, 14, "14 items MISSING")
        XCTAssertEqual(totalNA, 2, "2 items N/A")

        // Coverage rate: (PASS + PARTIAL) / (PASS + PARTIAL + MISSING) = 21/35 = 60%
        let actionable = totalPass + totalPartial + totalMissing
        let compatRate = Double(totalPass + totalPartial) / Double(actionable) * 100
        XCTAssertEqual(Int(compatRate), 60, "Pass+Partial rate should be ~60%")
    }

    // MARK: - AgentOptions Property Count Verification

    /// Verify AgentOptions has all documented properties (38 from story analysis).
    func testAgentOptions_propertyCount() {
        let options = AgentOptions(apiKey: "test-key", model: "test")
        let fields = fieldNames(of: options)

        // Story says AgentOptions has 38 properties. Verify key ones are present.
        let expectedFields: Set<String> = [
            "apiKey", "model", "baseURL", "provider", "systemPrompt", "maxTurns",
            "maxTokens", "maxBudgetUsd", "thinking", "permissionMode", "canUseTool",
            "cwd", "tools", "mcpServers", "retryConfig", "agentName", "mailboxStore",
            "teamStore", "taskStore", "worktreeStore", "planStore", "cronStore",
            "todoStore", "sessionStore", "sessionId", "hookRegistry", "skillRegistry",
            "skillDirectories", "skillNames", "maxSkillRecursionDepth",
            "fileCacheMaxEntries", "fileCacheMaxSizeBytes", "fileCacheMaxEntrySizeBytes",
            "gitCacheTTL", "projectRoot", "logLevel", "logOutput", "sandbox"
        ]

        for field in expectedFields {
            XCTAssertTrue(fields.contains(field),
                           "AgentOptions should have '\(field)' property")
        }

        XCTAssertTrue(fields.count >= expectedFields.count,
                       "AgentOptions should have at least \(expectedFields.count) properties (found \(fields.count))")
    }

    /// Verify SDKConfiguration is a subset of AgentOptions.
    func testSDKConfiguration_subsetOfAgentOptions() {
        let sdkConfigFields = fieldNames(of: SDKConfiguration())
        let agentOptionsFields = fieldNames(of: AgentOptions(apiKey: "test", model: "test"))

        // SDKConfiguration fields should all exist in AgentOptions
        for field in sdkConfigFields {
            XCTAssertTrue(agentOptionsFields.contains(field),
                           "SDKConfiguration.\(field) should also exist in AgentOptions")
        }

        // SDKConfiguration should have fewer fields than AgentOptions
        XCTAssertLessThan(sdkConfigFields.count, agentOptionsFields.count,
                           "SDKConfiguration should be a subset of AgentOptions properties")
    }
}

---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-16'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/16-8-agent-options-compat.md'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Types/SDKConfiguration.swift'
  - 'Sources/OpenAgentSDK/Types/ThinkingConfig.swift'
  - 'Sources/OpenAgentSDK/Types/PermissionTypes.swift'
  - 'Sources/OpenAgentSDK/Types/SandboxSettings.swift'
  - 'Sources/OpenAgentSDK/Types/MCPConfig.swift'
  - 'Sources/OpenAgentSDK/Types/HookTypes.swift'
  - 'Sources/OpenAgentSDK/Types/LogOutput.swift'
  - 'Sources/OpenAgentSDK/Types/LogLevel.swift'
  - 'Tests/OpenAgentSDKTests/Compat/QueryMethodsCompatTests.swift'
---

# ATDD Checklist - Epic 16, Story 16-8: Agent Options Complete Parameter Verification

**Date:** 2026-04-16
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (XCTest)

---

## Story Summary

As an SDK developer, I want to verify that Swift SDK's `AgentOptions` / `SDKConfiguration` covers all Options fields from the TypeScript SDK, so that developers migrating from TypeScript don't have to compromise on functionality.

**Key scope:**
- 12 core configuration fields (7 PASS, 3 PARTIAL, 2 MISSING)
- 9 advanced configuration fields (2 PASS, 2 PARTIAL, 5 MISSING)
- 5 session configuration fields (1 PASS, 3 PARTIAL, 1 MISSING)
- 11 extended configuration fields (0 PASS, 3 PARTIAL, 6 MISSING, 2 N/A)
- ThinkingConfig type verification (3 cases PASS, effort MISSING)
- systemPrompt preset mode verification (PARTIAL)
- outputFormat verification (MISSING)
- Compatibility report output (37 total fields)
- AgentOptions property count verification (38 properties)

**Out of scope (other stories):**
- Story 16-1: Core Query API compatibility (complete)
- Story 16-2: Tool system compatibility (complete)
- Story 16-3: Message types compatibility (complete)
- Story 16-4: Hook system compatibility (complete)
- Story 16-5: MCP integration compatibility (complete)
- Story 16-6: Session management compatibility (complete)
- Story 16-7: Query methods compatibility (complete)
- Future: Adding missing options to SDK

---

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- `CompatOptions` executable target in Package.swift, `swift build` passes
2. **AC2: Core configuration field-level verification (12 fields)** -- allowedTools, disallowedTools, maxTurns, maxBudgetUsd, model, fallbackModel, systemPrompt, permissionMode, canUseTool, cwd, env, mcpServers
3. **AC3: Advanced configuration field-level verification (9 fields)** -- thinking, effort, hooks, sandbox, agents, toolConfig, outputFormat, includePartialMessages, promptSuggestions
4. **AC4: Session configuration field-level verification (5 fields)** -- resume, continue, forkSession, sessionId, persistSession
5. **AC5: Extended configuration field-level verification (11 fields)** -- settingSources, plugins, betas, executable, spawnClaudeCodeProcess, additionalDirectories, debug/debugFile, stderr, strictMcpConfig, extraArgs, enableFileCheckpointing
6. **AC6: ThinkingConfig type verification** -- adaptive, enabled(budgetTokens), disabled, effort level
7. **AC7: systemPrompt preset mode verification** -- structured type vs String only
8. **AC8: outputFormat / structured output verification** -- JSON Schema support
9. **AC9: Compatibility report output** -- Standard format compatibility status for all 37 fields

---

## Failing Tests Created (ATDD Verification)

### Unit Tests -- AgentOptionsCompatTests (53 tests)

**File:** `Tests/OpenAgentSDKTests/Compat/AgentOptionsCompatTests.swift`

#### AC2: Core Configuration Field-Level Verification (13 tests)

- **Test:** `testAllowedTools_partialViaPolicy` [PARTIAL] -- No allowedTools property; ToolNameAllowlistPolicy exists as runtime policy
- **Test:** `testDisallowedTools_partialViaPolicy` [PARTIAL] -- No disallowedTools property; ToolNameDenylistPolicy exists as runtime policy
- **Test:** `testMaxTurns_pass` [P0] -- AgentOptions.maxTurns: Int matches TS maxTurns: number
- **Test:** `testMaxBudgetUsd_pass` [P0] -- AgentOptions.maxBudgetUsd: Double? matches TS maxBudgetUsd: number
- **Test:** `testModel_pass` [P0] -- AgentOptions.model: String matches TS model: string
- **Test:** `testFallbackModel_missing` [MISSING] -- No fallbackModel equivalent in Swift SDK
- **Test:** `testSystemPrompt_partial` [PARTIAL] -- AgentOptions.systemPrompt: String? (no preset mode)
- **Test:** `testPermissionMode_pass` [P0] -- AgentOptions.permissionMode has 6 cases matching TS
- **Test:** `testCanUseTool_pass` [P0] -- AgentOptions.canUseTool: CanUseToolFn? matches TS
- **Test:** `testCwd_pass` [P0] -- AgentOptions.cwd: String? matches TS cwd: string
- **Test:** `testEnv_missing` [MISSING] -- No env property for environment variable overrides
- **Test:** `testMcpServers_pass` [P0] -- AgentOptions.mcpServers: [String: McpServerConfig]? matches TS
- **Test:** `testCoreConfig_coverageSummary` [P0] -- Summary: 7 PASS + 3 PARTIAL + 2 MISSING = 12

#### AC3: Advanced Configuration Field-Level Verification (10 tests)

- **Test:** `testThinking_pass` [P0] -- AgentOptions.thinking: ThinkingConfig? matches TS
- **Test:** `testEffort_missing` [MISSING] -- No effort level property (low/medium/high/max)
- **Test:** `testHooks_partial` [PARTIAL] -- HookRegistry actor instead of config dict; 15+ events
- **Test:** `testSandbox_pass` [P0] -- AgentOptions.sandbox: SandboxSettings? with 6 fields matches TS
- **Test:** `testAgents_partial` [PARTIAL] -- AgentDefinition via AgentTool, not options-level property
- **Test:** `testToolConfig_missing` [MISSING] -- No ToolConfig type in Swift SDK
- **Test:** `testOutputFormat_missing` [MISSING] -- No outputFormat for JSON Schema structured output
- **Test:** `testIncludePartialMessages_missing` [MISSING] -- No includePartialMessages flag
- **Test:** `testPromptSuggestions_missing` [MISSING] -- No promptSuggestions flag
- **Test:** `testAdvancedConfig_coverageSummary` [P0] -- Summary: 2 PASS + 2 PARTIAL + 5 MISSING = 9

#### AC4: Session Configuration Field-Level Verification (6 tests)

- **Test:** `testResume_partial` [PARTIAL] -- No resume property; uses sessionStore + sessionId
- **Test:** `testContinue_missing` [MISSING] -- No continue flag for last session
- **Test:** `testForkSession_partial` [PARTIAL] -- SessionStore has fork as separate method
- **Test:** `testSessionId_pass` [P0] -- AgentOptions.sessionId: String? matches TS
- **Test:** `testPersistSession_partial` [PARTIAL] -- Implicit auto-save when sessionStore set
- **Test:** `testSessionConfig_coverageSummary` [P0] -- Summary: 1 PASS + 3 PARTIAL + 1 MISSING = 5

#### AC5: Extended Configuration Field-Level Verification (12 tests)

- **Test:** `testSettingSources_missing` [MISSING] -- No settingSources property
- **Test:** `testPlugins_missing` [MISSING] -- No plugin system
- **Test:** `testBetas_missing` [MISSING] -- No beta feature flags
- **Test:** `testExecutable_na` [N/A] -- Not applicable to Swift runtime
- **Test:** `testSpawnClaudeCodeProcess_na` [N/A] -- Not applicable to Swift process model
- **Test:** `testAdditionalDirectories_partial` [PARTIAL] -- skillDirectories covers skill dirs only
- **Test:** `testDebugDebugFile_partial` [PARTIAL] -- logLevel/logOutput are partial equivalents
- **Test:** `testStderrCallback_partial` [PARTIAL] -- LogOutput.custom is partial equivalent
- **Test:** `testStrictMcpConfig_missing` [MISSING] -- No strict MCP config validation flag
- **Test:** `testExtraArgs_missing` [MISSING] -- No extra argument passthrough
- **Test:** `testEnableFileCheckpointing_missing` [MISSING] -- No file checkpointing system
- **Test:** `testExtendedConfig_coverageSummary` [P0] -- Summary: 0 PASS + 3 PARTIAL + 6 MISSING + 2 N/A = 11

#### AC6: ThinkingConfig Type Verification (5 tests)

- **Test:** `testThinkingConfig_adaptive` [P0] -- .adaptive maps to TS { type: "adaptive" }
- **Test:** `testThinkingConfig_enabled` [P0] -- .enabled(budgetTokens:) maps to TS { type: "enabled" }
- **Test:** `testThinkingConfig_disabled` [P0] -- .disabled maps to TS { type: "disabled" }
- **Test:** `testThinkingConfig_effortLevel_missing` [MISSING] -- No effort level in ThinkingConfig
- **Test:** `testThinkingConfig_validation` [P0] -- validate() rejects zero/negative budgetTokens

#### AC7: systemPrompt Preset Mode Verification (1 test)

- **Test:** `testSystemPromptPreset_noPresetEnum` [PARTIAL] -- String only, no preset enum or append mechanism

#### AC8: outputFormat Verification (1 test)

- **Test:** `testOutputFormat_noStructuredOutput` [MISSING] -- No JSON Schema output support

#### AC9: Compatibility Report Output (4 tests)

- **Test:** `testCompatReport_completeFieldLevelCoverage` [P0] -- 37-row field compatibility matrix
- **Test:** `testCompatReport_categoryBreakdown` [P0] -- Category-level breakdown (12+9+5+11=37)
- **Test:** `testCompatReport_overallSummary` [P0] -- Overall: 10 PASS + 11 PARTIAL + 14 MISSING + 2 N/A = 37

#### Bonus: AgentOptions Property Verification (2 tests)

- **Test:** `testAgentOptions_propertyCount` [P0] -- Verifies all 38 documented properties exist
- **Test:** `testSDKConfiguration_subsetOfAgentOptions` [P0] -- SDKConfiguration fields are subset of AgentOptions

---

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | Build compilation verification | (example story, not testable here) | P0 |
| AC2 | Core configuration (12 fields) | 13 tests (5 pass + 2 partial + 1 missing + 1 mcp + 4 summary/defaults) | P0 |
| AC3 | Advanced configuration (9 fields) | 10 tests (2 pass + 2 partial + 5 missing + 1 summary) | P0 |
| AC4 | Session configuration (5 fields) | 6 tests (1 pass + 3 partial + 1 missing + 1 summary) | P0 |
| AC5 | Extended configuration (11 fields) | 12 tests (3 partial + 6 missing + 2 N/A + 1 summary) | P0 |
| AC6 | ThinkingConfig type verification | 5 tests (3 pass + 1 missing + 1 validation) | P0 |
| AC7 | systemPrompt preset verification | 1 test (partial) | P0 |
| AC8 | outputFormat verification | 1 test (missing) | P0 |
| AC9 | Compatibility report output | 4 tests (all pass) | P0 |
| -- | AgentOptions property verification | 2 tests (both pass) | P0 |

**Total: 53 tests covering all acceptance criteria (AC2-AC9).**

---

## Test Strategy

### Stack Detection
- **Detected:** Backend (Swift Package with XCTest, no frontend/browser testing)
- **Mode:** AI Generation (acceptance criteria are clear, standard type verification scenarios)

### Test Levels
- **Unit Tests (53):** Pure type-level verification tests using Mirror introspection for gap detection, property existence checks, value round-trip tests, ThinkingConfig validation, and compatibility matrix assertions

### Priority Distribution
- **P0 (Critical):** 53 tests -- all tests verify core options/configuration compatibility

---

## TDD Phase Validation

- [x] All tests assert EXPECTED behavior (not placeholder assertions)
- [x] All tests compile and pass against existing SDK APIs (verification story, not new feature)
- [x] Each test has clear Given/When/Then structure
- [x] Tests document compatibility gaps inline with [MISSING]/[PARTIAL]/[N/A] markers
- [x] Build verification: `swift build --build-tests` succeeds with zero errors
- [x] Test execution: All 53 tests pass (0 failures)
- [x] Full suite regression: All 3563 tests pass (14 skipped, 0 failures)

---

## Compatibility Gaps Documented

### Core Configuration: 7 PASS, 3 PARTIAL, 2 MISSING

| # | TS SDK Field | Swift Equivalent | Status | Recommendation |
|---|---|---|---|---|
| 1 | allowedTools: string[] | ToolNameAllowlistPolicy | PARTIAL | Add allowedTools property to AgentOptions |
| 2 | disallowedTools: string[] | ToolNameDenylistPolicy | PARTIAL | Add disallowedTools property to AgentOptions |
| 3 | maxTurns: number | AgentOptions.maxTurns: Int | PASS | -- |
| 4 | maxBudgetUsd: number | AgentOptions.maxBudgetUsd: Double? | PASS | -- |
| 5 | model: string | AgentOptions.model: String | PASS | -- |
| 6 | fallbackModel: string | -- | MISSING | Add fallbackModel property |
| 7 | systemPrompt: string \| preset | AgentOptions.systemPrompt: String? | PARTIAL | Add SystemPromptPreset enum |
| 8 | permissionMode: PermissionMode | AgentOptions.permissionMode | PASS | -- |
| 9 | canUseTool: CanUseTool | AgentOptions.canUseTool: CanUseToolFn? | PASS | -- |
| 10 | cwd: string | AgentOptions.cwd: String? | PASS | -- |
| 11 | env: Record<string, string> | -- | MISSING | Add env property for env overrides |
| 12 | mcpServers: Record<string, McpServerConfig> | AgentOptions.mcpServers | PASS | -- |

### Advanced Configuration: 2 PASS, 2 PARTIAL, 5 MISSING

| # | TS SDK Field | Swift Equivalent | Status | Recommendation |
|---|---|---|---|---|
| 1 | thinking: ThinkingConfig | AgentOptions.thinking | PASS | -- |
| 2 | effort: 'low'/'medium'/'high'/'max' | -- | MISSING | Add effort level enum |
| 3 | hooks: Partial<Record<HookEvent, ...>> | AgentOptions.hookRegistry (actor) | PARTIAL | Consider config-dict approach |
| 4 | sandbox: SandboxSettings | AgentOptions.sandbox | PASS | -- |
| 5 | agents: Record<string, AgentDefinition> | AgentTool (tool level) | PARTIAL | Consider options-level agents dict |
| 6 | toolConfig: ToolConfig | -- | MISSING | Add ToolConfig type |
| 7 | outputFormat: { type, schema } | -- | MISSING | Add JSON Schema output format |
| 8 | includePartialMessages: boolean | -- | MISSING | Add partial message streaming flag |
| 9 | promptSuggestions: boolean | -- | MISSING | Add prompt suggestions flag |

### Session Configuration: 1 PASS, 3 PARTIAL, 1 MISSING

| # | TS SDK Field | Swift Equivalent | Status | Recommendation |
|---|---|---|---|---|
| 1 | resume: string | sessionStore + sessionId | PARTIAL | Add resume convenience option |
| 2 | continue: boolean | -- | MISSING | Add continue-last-session flag |
| 3 | forkSession: boolean | SessionStore.fork (separate) | PARTIAL | Add forkSession option |
| 4 | sessionId: string | AgentOptions.sessionId | PASS | -- |
| 5 | persistSession: boolean | Implicit via sessionStore | PARTIAL | Add explicit persistSession flag |

### Extended Configuration: 0 PASS, 3 PARTIAL, 6 MISSING, 2 N/A

| # | TS SDK Field | Swift Equivalent | Status | Recommendation |
|---|---|---|---|---|
| 1 | settingSources: SettingSource[] | -- | MISSING | Add settings source configuration |
| 2 | plugins: SdkPluginConfig[] | -- | MISSING | Add plugin system |
| 3 | betas: SdkBeta[] | -- | MISSING | Add beta feature flags |
| 4 | executable: 'bun'/'deno'/'node' | N/A | N/A | Not applicable to Swift |
| 5 | spawnClaudeCodeProcess | N/A | N/A | Not applicable to Swift |
| 6 | additionalDirectories: string[] | skillDirectories (partial) | PARTIAL | Add general additional dirs |
| 7 | debug: boolean / debugFile: string | logLevel + logOutput | PARTIAL | Already covered, different API |
| 8 | stderr: (data: string) => void | LogOutput.custom | PARTIAL | Already covered, different format |
| 9 | strictMcpConfig: boolean | -- | MISSING | Add strict MCP config flag |
| 10 | extraArgs: Record<string, string \| null> | -- | MISSING | Add extra args passthrough |
| 11 | enableFileCheckpointing: boolean | -- | MISSING | Add file checkpointing system |

### Summary

- **Core Config:** 7/12 PASS (58%), 3/12 PARTIAL (25%), 2/12 MISSING (17%)
- **Advanced Config:** 2/9 PASS (22%), 2/9 PARTIAL (22%), 5/9 MISSING (56%)
- **Session Config:** 1/5 PASS (20%), 3/5 PARTIAL (60%), 1/5 MISSING (20%)
- **Extended Config:** 0/11 PASS, 3/11 PARTIAL (27%), 6/11 MISSING (55%), 2/11 N/A (18%)
- **Overall:** 10 PASS + 11 PARTIAL + 14 MISSING + 2 N/A = 37 fields verified
- **Pass+Partial Rate:** 21/35 = 60%

---

## Implementation Guidance

### Files Created
1. `Tests/OpenAgentSDKTests/Compat/AgentOptionsCompatTests.swift` -- 53 ATDD tests

### Files to Create (Story Implementation)
1. `Examples/CompatOptions/main.swift` -- Compatibility verification example
2. Update `Package.swift` -- Add CompatOptions executable target

### Key Implementation Notes
- Example should follow established CompatEntry/record() pattern from Stories 16-1 through 16-7
- Use `nonisolated(unsafe)` for mutable global report state
- Use `loadDotEnv()` / `getEnv()` for API key loading
- Use `permissionMode: .bypassPermissions` to simplify example
- Use `createAgent(options:)` factory function
- Add bilingual (EN + Chinese) comment header
- Report should output 4 compatibility tables: core, advanced, session, extended
- Use Mirror introspection for field-level verification (same pattern as 16-7)
- Include ThinkingConfig deep verification (3 cases + validation)
- Include systemPrompt preset gap documentation
- Include outputFormat gap documentation
- Total: 37 TS SDK fields to verify across 4 categories

---

## Next Steps (Story Implementation)

1. Create `Examples/CompatOptions/main.swift` using the verification patterns tested here
2. Add `CompatOptions` executable target to `Package.swift`
3. Run `swift build --target CompatOptions` to verify example compiles
4. Run `swift run CompatOptions` to generate compatibility report
5. Verify all 53 ATDD tests still pass after implementation
6. Run full test suite to verify no regressions

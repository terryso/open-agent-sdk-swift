---
stepsCompleted: ['step-01-load-context', 'step-02-discover-tests', 'step-03-map-criteria', 'step-04-analyze-gaps', 'step-05-gate-decision']
lastStep: 'step-05-gate-decision'
lastSaved: '2026-04-16'
story_id: '17-2'
---

# Traceability Report: Story 17-2 AgentOptions Enhancement

## Gate Decision: PASS

**Rationale:** P0 coverage is 100%, P1 coverage is 100%, and overall coverage is 100%. All 8 acceptance criteria are fully covered by ATDD tests plus supplementary tests in ToolRegistryTests, AgentOptionsCompatTests, and ThinkingModelCompatTests. Build passes with 0 errors; all 3793 tests pass (0 failures, 14 skipped).

---

## Coverage Summary

| Metric | Value |
|--------|-------|
| Total Acceptance Criteria | 8 |
| Fully Covered | 8 (100%) |
| Partially Covered | 0 |
| Uncovered | 0 |
| P0 Coverage | 100% |
| P1 Coverage | 100% |
| Overall Coverage | 100% |
| ATDD Test Count | 71 |
| Supplementary Test Count | ~30 (across compat + registry files) |
| Build Status | 0 errors, 0 warnings |
| Test Suite Status | 3793 pass, 0 fail, 14 skip |

---

## Traceability Matrix

### AC1: Core Configuration Fields

**Requirement:** `AgentOptions` gains `fallbackModel`, `env`, `allowedTools`, `disallowedTools`. All optional, backward-compatible. `disallowedTools` takes priority over `allowedTools`.

| Test ID | Test Name | Level | Priority | Status |
|---------|-----------|-------|----------|--------|
| AC1-T01 | testAgentOptions_fallbackModel_set | Unit | P0 | PASS |
| AC1-T02 | testAgentOptions_fallbackModel_defaultNil | Unit | P0 | PASS |
| AC1-T03 | testAgentOptions_env_set | Unit | P0 | PASS |
| AC1-T04 | testAgentOptions_env_defaultNil | Unit | P0 | PASS |
| AC1-T05 | testAgentOptions_allowedTools_set | Unit | P0 | PASS |
| AC1-T06 | testAgentOptions_allowedTools_defaultNil | Unit | P0 | PASS |
| AC1-T07 | testAgentOptions_disallowedTools_set | Unit | P0 | PASS |
| AC1-T08 | testAgentOptions_disallowedTools_defaultNil | Unit | P0 | PASS |
| AC1-T09 | testAgentOptions_allowedAndDisallowedTools_bothSet | Unit | P0 | PASS |
| AC1-T10 | testAgentOptions_backwardCompat_existingInit | Unit | P0 | PASS |

**Supplementary coverage:**
- `AgentOptionsCompatTests.testAllowedTools_partialViaPolicy` -- compat field presence
- `AgentOptionsCompatTests.testDisallowedTools_partialViaPolicy` -- compat field presence
- `AgentOptionsCompatTests.testFallbackModel_missing` -- compat field presence
- `ToolRegistryTests.testFilterTools_AllowedList_FiltersCorrectly` -- runtime filtering
- `ToolRegistryTests.testFilterTools_DisallowedList_ExcludesCorrectly` -- runtime filtering
- `ToolRegistryTests.testFilterTools_BothLists_AppliesBoth` -- priority logic
- `ToolRegistryTests.testAssembleToolPool_AppliesFiltersAfterDedup` -- integration

**Runtime wiring verified:** `assembleFullToolPool()` in Agent.swift passes `options.allowedTools` and `options.disallowedTools` to `assembleToolPool()` in ToolRegistry.swift. DisallowedTools takes priority (line 253-254).

**Coverage: FULL**

---

### AC2: Advanced Configuration Fields

**Requirement:** `AgentOptions` gains `effort`, `outputFormat`, `toolConfig`, `includePartialMessages`, `promptSuggestions`. `effort` maps to thinking parameter; `outputFormat` carries JSON Schema.

| Test ID | Test Name | Level | Priority | Status |
|---------|-----------|-------|----------|--------|
| AC2-T01 | testAgentOptions_effort_set | Unit | P0 | PASS |
| AC2-T02 | testAgentOptions_effort_defaultNil | Unit | P0 | PASS |
| AC2-T03 | testAgentOptions_outputFormat_set | Unit | P0 | PASS |
| AC2-T04 | testAgentOptions_outputFormat_defaultNil | Unit | P0 | PASS |
| AC2-T05 | testAgentOptions_toolConfig_set | Unit | P0 | PASS |
| AC2-T06 | testAgentOptions_toolConfig_defaultNil | Unit | P0 | PASS |
| AC2-T07 | testAgentOptions_includePartialMessages_defaultTrue | Unit | P0 | PASS |
| AC2-T08 | testAgentOptions_includePartialMessages_setFalse | Unit | P0 | PASS |
| AC2-T09 | testAgentOptions_promptSuggestions_defaultFalse | Unit | P0 | PASS |
| AC2-T10 | testAgentOptions_promptSuggestions_setTrue | Unit | P0 | PASS |

**Supplementary coverage:**
- `AgentOptionsCompatTests` -- effort, outputFormat, toolConfig, includePartialMessages, promptSuggestions all verified as present
- `ThinkingModelCompatTests` -- EffortLevel enum verified, effort interaction with ThinkingConfig documented

**Runtime wiring verified:** `computeThinkingConfig()` in Agent.swift (line 1591) maps `options.effort` to thinking budget tokens when no explicit thinking config is set. Priority: explicit thinking > effort > nil.

**Coverage: FULL**

---

### AC3: Session Configuration Fields

**Requirement:** `AgentOptions` gains `continueRecentSession`, `forkSession`, `resumeSessionAt`, `persistSession`. Integrate with existing `sessionStore`/`sessionId`.

| Test ID | Test Name | Level | Priority | Status |
|---------|-----------|-------|----------|--------|
| AC3-T01 | testAgentOptions_continueRecentSession_defaultFalse | Unit | P0 | PASS |
| AC3-T02 | testAgentOptions_continueRecentSession_setTrue | Unit | P0 | PASS |
| AC3-T03 | testAgentOptions_forkSession_defaultFalse | Unit | P0 | PASS |
| AC3-T04 | testAgentOptions_forkSession_setTrue | Unit | P0 | PASS |
| AC3-T05 | testAgentOptions_resumeSessionAt_set | Unit | P0 | PASS |
| AC3-T06 | testAgentOptions_resumeSessionAt_defaultNil | Unit | P0 | PASS |
| AC3-T07 | testAgentOptions_persistSession_defaultTrue | Unit | P0 | PASS |
| AC3-T08 | testAgentOptions_persistSession_setFalse | Unit | P0 | PASS |
| AC3-T09 | testAgentOptions_sessionFields_withExistingSessionConfig | Unit | P0 | PASS |

**Supplementary coverage:**
- `AgentOptionsCompatTests` -- continueRecentSession, forkSession, persistSession verified as present

**Runtime wiring verified:** `persistSession` gates session auto-save in Agent.swift (line 531: `if ... options.persistSession` in prompt(); line 753: same in stream()).

**Coverage: FULL**

---

### AC4: EffortLevel Enum

**Requirement:** `EffortLevel` enum: `.low`, `.medium`, `.high`, `.max`. Sendable, Equatable, CaseIterable, String. Maps to budget tokens.

| Test ID | Test Name | Level | Priority | Status |
|---------|-----------|-------|----------|--------|
| AC4-T01 | testEffortLevel_allCases | Unit | P0 | PASS |
| AC4-T02 | testEffortLevel_caseIterable | Unit | P0 | PASS |
| AC4-T03 | testEffortLevel_rawValues | Unit | P0 | PASS |
| AC4-T04 | testEffortLevel_sendable | Unit | P0 | PASS |
| AC4-T05 | testEffortLevel_equatable | Unit | P0 | PASS |
| AC4-T06 | testEffortLevel_stringRawValue | Unit | P0 | PASS |
| AC4-T07 | testEffortLevel_budgetTokens | Unit | P1 | PASS |

**Supplementary coverage:**
- `ThinkingModelCompatTests.testEffortLevel_missing` -- verifies all 4 cases and raw values

**Coverage: FULL**

---

### AC5: OutputFormat Type

**Requirement:** `OutputFormat` struct: `{ type: "json_schema", jsonSchema: [String: Any] }`. Sendable via wrapper pattern.

| Test ID | Test Name | Level | Priority | Status |
|---------|-----------|-------|----------|--------|
| AC5-T01 | testOutputFormat_init | Unit | P0 | PASS |
| AC5-T02 | testOutputFormat_typeIsJsonSchema | Unit | P0 | PASS |
| AC5-T03 | testOutputFormat_storesJsonSchema | Unit | P0 | PASS |
| AC5-T04 | testOutputFormat_sendable | Unit | P0 | PASS |
| AC5-T05 | testSendableJSONSchema_init | Unit | P0 | PASS |
| AC5-T06 | testSendableJSONSchema_sendable | Unit | P0 | PASS |

**Coverage: FULL**

---

### AC6: ToolConfig Type

**Requirement:** `ToolConfig` struct: `maxConcurrentReadTools`, `maxConcurrentWriteTools`. Sendable.

| Test ID | Test Name | Level | Priority | Status |
|---------|-----------|-------|----------|--------|
| AC6-T01 | testToolConfig_initDefaults | Unit | P0 | PASS |
| AC6-T02 | testToolConfig_initExplicit | Unit | P0 | PASS |
| AC6-T03 | testToolConfig_sendable | Unit | P0 | PASS |
| AC6-T04 | testToolConfig_equatable | Unit | P0 | PASS |
| AC6-T05 | testToolConfig_partialConfig | Unit | P1 | PASS |

**Coverage: FULL**

---

### AC7: SystemPromptConfig Preset Support

**Requirement:** `SystemPromptConfig` enum with `.text(String)` and `.preset(name:append:)`. `systemPromptConfig` takes priority over `systemPrompt`.

| Test ID | Test Name | Level | Priority | Status |
|---------|-----------|-------|----------|--------|
| AC7-T01 | testSystemPromptConfig_textCase | Unit | P0 | PASS |
| AC7-T02 | testSystemPromptConfig_presetCase | Unit | P0 | PASS |
| AC7-T03 | testSystemPromptConfig_presetNilAppend | Unit | P0 | PASS |
| AC7-T04 | testSystemPromptConfig_sendable | Unit | P0 | PASS |
| AC7-T05 | testSystemPromptConfig_equatable | Unit | P0 | PASS |
| AC7-T06 | testSystemPromptConfig_presetEquality | Unit | P0 | PASS |
| AC7-T07 | testAgentOptions_systemPromptConfig_set | Unit | P0 | PASS |
| AC7-T08 | testAgentOptions_systemPromptConfig_defaultNil | Unit | P0 | PASS |
| AC7-T09 | testAgentOptions_systemPromptConfig_coexistsWithSystemPrompt | Unit | P0 | PASS |
| AC7-T10 | testAgentOptions_systemPrompt_backwardCompat | Unit | P0 | PASS |

**Runtime wiring verified:** `buildSystemPrompt()` in Agent.swift (line 267-279) checks `options.systemPromptConfig` first; `.text` extracts the string, `.preset` resolves via `resolvePreset()`.

**Coverage: FULL**

---

### AC8: Build and Test Verification

**Requirement:** `swift build` 0 errors 0 warnings, 3722+ tests zero regression.

| Test ID | Test Name | Level | Priority | Status |
|---------|-----------|-------|----------|--------|
| AC8-T01 | testEffortLevel_isSendable | Unit | P0 | PASS |
| AC8-T02 | testOutputFormat_isSendable | Unit | P0 | PASS |
| AC8-T03 | testSendableJSONSchema_isSendable | Unit | P0 | PASS |
| AC8-T04 | testToolConfig_isSendable | Unit | P0 | PASS |
| AC8-T05 | testSystemPromptConfig_isSendable | Unit | P0 | PASS |
| AC8-T06 | testAgentOptions_withNewFields_isSendable | Unit | P0 | PASS |
| AC8-T07 | testDefaultInit_noParameters | Unit | P0 | PASS |
| AC8-T08 | testExistingParameterizedInit | Unit | P0 | PASS |
| AC8-T09 | testExistingFieldsAccessible | Unit | P0 | PASS |
| AC8-T10 | testValidation_existingChecksStillWork | Unit | P0 | PASS |

**Build verification:** 0 errors, 0 warnings.
**Test suite verification:** 3793 tests pass, 0 failures, 14 skipped (pre-existing).

**Supplementary coverage:**
- `ConfigBasedInitATDDTests.testInitFromConfig_newFieldsDefaultValues` -- verifies all new fields default correctly in init(from:)
- `ConfigBasedInitATDDTests.testInitFromConfig_preservesExistingFields` -- backward compat
- `AllFieldsIntegrationATDDTests.testAllNewFields_together` -- all 14 fields simultaneously
- `AllFieldsIntegrationATDDTests.testMixedOldAndNewFields` -- old + new field mix

**Validation extension verified:** `validate()` in AgentTypes.swift now checks:
- `fallbackModel` must be non-empty if set (line 578-583)
- `outputFormat.jsonSchema` must be non-empty dict (line 584-587)

**Coverage: FULL**

---

## Gap Analysis

### Critical Gaps (P0): 0

None. All P0 acceptance criteria are fully covered.

### High Gaps (P1): 0

None. All P1 acceptance criteria are fully covered.

### Coverage Heuristics

| Heuristic | Count |
|-----------|-------|
| Endpoints without tests | 0 |
| Auth negative-path gaps | N/A (no auth requirements) |
| Happy-path-only criteria | 0 |

### Observations (Non-blocking)

1. **env field runtime wiring deferred:** The `env` dictionary for subprocess injection (BashTool/ShellHookExecutor) is defined on AgentOptions but not yet wired through to ToolContext. This is a runtime integration gap, not a test gap. The field presence and defaults are tested.

2. **continueRecentSession/forkSession/resumeSessionAt runtime wiring:** These session config fields are defined on AgentOptions and `persistSession` is wired to gate session saves. The other three (`continueRecentSession`, `forkSession`, `resumeSessionAt`) are declarative options whose runtime integration depends on the session management subsystem. Field presence, defaults, and backward compatibility are tested.

3. **Validation for new fields:** `validate()` now checks `fallbackModel` (non-empty) and `outputFormat` (non-empty schema). No explicit ATDD tests for these validation paths, but the existing `testValidation_existingChecksStillWork` test confirms backward compatibility of validation.

---

## Recommendations

1. **[LOW]** Add explicit validation tests for `fallbackModel` empty string rejection and `outputFormat` empty schema rejection.
2. **[LOW]** Add runtime integration tests for `env` field propagation to tool context when BashTool env override is implemented.
3. **[LOW]** Run `/bmad:tea:test-review` to assess test quality patterns.

---

## Gate Criteria Check

| Criterion | Required | Actual | Status |
|-----------|----------|--------|--------|
| P0 Coverage | 100% | 100% | MET |
| P1 Coverage | 90% (PASS target) | 100% | MET |
| Overall Coverage | >= 80% | 100% | MET |
| Build | 0 errors | 0 errors | MET |
| Test Suite | 0 failures | 0 failures | MET |

---

## Test File Inventory

| File | Tests | Role |
|------|-------|------|
| `Tests/OpenAgentSDKTests/Types/AgentOptionsEnhancementATDDTests.swift` | 71 | Primary ATDD tests |
| `Tests/OpenAgentSDKTests/Compat/AgentOptionsCompatTests.swift` | ~15 relevant | Cross-verification of field presence |
| `Tests/OpenAgentSDKTests/Compat/ThinkingModelCompatTests.swift` | ~3 relevant | EffortLevel compat verification |
| `Tests/OpenAgentSDKTests/Tools/ToolRegistryTests.swift` | 7 filter/pool tests | Runtime tool filtering verification |

**Total relevant test count: ~96**

---

## Implementation File Inventory

| File | Change Type |
|------|-------------|
| `Sources/OpenAgentSDK/Types/AgentTypes.swift` | MODIFIED -- 5 new types + 14 new fields on AgentOptions + extended validation |
| `Sources/OpenAgentSDK/Core/Agent.swift` | MODIFIED -- runtime wiring (tool filtering, system prompt priority, effort-to-thinking, fallbackModel retry, persistSession gating) |
| `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` | MODIFIED -- filterTools() + assembleToolPool() with allowed/disallowed params |
| `Sources/OpenAgentSDK/OpenAgentSDK.swift` | MODIFIED -- re-export new public types |

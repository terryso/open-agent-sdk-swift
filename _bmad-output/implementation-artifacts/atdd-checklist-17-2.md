---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-16'
story_id: '17-2'
inputDocuments:
  - '_bmad-output/implementation-artifacts/17-2-agent-options-enhancement.md'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Sources/OpenAgentSDK/Types/ThinkingConfig.swift'
  - 'Sources/OpenAgentSDK/Types/ModelInfo.swift'
  - 'Tests/OpenAgentSDKTests/Types/AgentOptionsDeepTests.swift'
  - 'Tests/OpenAgentSDKTests/Types/SDKMessageEnhancementATDDTests.swift'
---

# ATDD Checklist -- Story 17.2: AgentOptions Complete Parameters

## Test Stack

- **Detected stack**: backend (Swift Package Manager, XCTest)
- **Framework**: XCTest
- **TDD Phase**: RED (tests fail because feature is not implemented)

## Acceptance Criteria to Test Mapping

| AC | Description | Priority | Test Count | Test Class |
|----|-------------|----------|------------|------------|
| AC1 | Core configuration fields (fallbackModel, env, allowedTools, disallowedTools) | P0 | 10 | CoreConfigFieldsATDDTests |
| AC2 | Advanced configuration fields (effort, outputFormat, toolConfig, includePartialMessages, promptSuggestions) | P0 | 10 | AdvancedConfigFieldsATDDTests |
| AC3 | Session configuration fields (continueRecentSession, forkSession, resumeSessionAt, persistSession) | P0 | 9 | SessionConfigFieldsATDDTests |
| AC4 | EffortLevel enum (low/medium/high/max, Sendable, Equatable, CaseIterable, String, budgetTokens) | P0/P1 | 7 | EffortLevelATDDTests |
| AC5 | OutputFormat type (json_schema, SendableJSONSchema wrapper) | P0 | 6 | OutputFormatATDDTests |
| AC6 | ToolConfig type (maxConcurrentReadTools, maxConcurrentWriteTools, Sendable, Equatable) | P0/P1 | 5 | ToolConfigATDDTests |
| AC7 | SystemPromptConfig preset support (.text, .preset, on AgentOptions) | P0 | 10 | SystemPromptConfigATDDTests + SystemPromptConfigOnOptionsATDDTests |
| AC8 | Build and test / Sendable / backward compatibility | P0 | 10 | AgentOptionsSendableATDDTests + BackwardCompatATDDTests |
| -- | init(from:) config-based init defaults | P0 | 2 | ConfigBasedInitATDDTests |
| -- | Integration: all fields together | P0/P1 | 2 | AllFieldsIntegrationATDDTests |
| **Total** | | | **71** | |

## Test File Created

| File | Path | Test Count | Status |
|------|------|------------|--------|
| AgentOptionsEnhancementATDDTests.swift | `Tests/OpenAgentSDKTests/Types/AgentOptionsEnhancementATDDTests.swift` | 71 | RED (fails compilation -- types and fields don't exist yet) |

## Detailed Test Inventory

### EffortLevelATDDTests (7 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testEffortLevel_allCases | P0 | AC4 | EffortLevel has exactly 4 cases |
| 2 | testEffortLevel_caseIterable | P0 | AC4 | Conforms to CaseIterable |
| 3 | testEffortLevel_rawValues | P0 | AC4 | rawValue strings: "low", "medium", "high", "max" |
| 4 | testEffortLevel_sendable | P0 | AC4 | Conforms to Sendable |
| 5 | testEffortLevel_equatable | P0 | AC4 | Conforms to Equatable |
| 6 | testEffortLevel_stringRawValue | P0 | AC4 | RawRepresentable with String |
| 7 | testEffortLevel_budgetTokens | P1 | AC4 | Maps to thinking budget tokens (1024/5120/10240/32768) |

### OutputFormatATDDTests (6 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testOutputFormat_init | P0 | AC5 | Can be constructed with jsonSchema |
| 2 | testOutputFormat_typeIsJsonSchema | P0 | AC5 | type field is "json_schema" |
| 3 | testOutputFormat_storesJsonSchema | P0 | AC5 | Stores and retrieves jsonSchema dictionary |
| 4 | testOutputFormat_sendable | P0 | AC5 | Conforms to Sendable |
| 5 | testSendableJSONSchema_init | P0 | AC5 | SendableJSONSchema wrapper holds [String: Any] |
| 6 | testSendableJSONSchema_sendable | P0 | AC5 | SendableJSONSchema conforms to Sendable |

### ToolConfigATDDTests (5 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testToolConfig_initDefaults | P0 | AC6 | Default init has all nil fields |
| 2 | testToolConfig_initExplicit | P0 | AC6 | Explicit init sets maxConcurrentReadTools/WriteTools |
| 3 | testToolConfig_sendable | P0 | AC6 | Conforms to Sendable |
| 4 | testToolConfig_equatable | P0 | AC6 | Conforms to Equatable |
| 5 | testToolConfig_partialConfig | P1 | AC6 | Partial configuration (only read tools) |

### SystemPromptConfigATDDTests (6 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testSystemPromptConfig_textCase | P0 | AC7 | .text case wrapping String |
| 2 | testSystemPromptConfig_presetCase | P0 | AC7 | .preset case with name and append |
| 3 | testSystemPromptConfig_presetNilAppend | P0 | AC7 | .preset append is optional |
| 4 | testSystemPromptConfig_sendable | P0 | AC7 | Conforms to Sendable |
| 5 | testSystemPromptConfig_equatable | P0 | AC7 | Conforms to Equatable |
| 6 | testSystemPromptConfig_presetEquality | P0 | AC7 | Equality works for .preset with name+append |

### CoreConfigFieldsATDDTests (11 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testAgentOptions_fallbackModel_set | P0 | AC1 | fallbackModel can be set |
| 2 | testAgentOptions_fallbackModel_defaultNil | P0 | AC1 | fallbackModel defaults to nil |
| 3 | testAgentOptions_env_set | P0 | AC1 | env dictionary can be set |
| 4 | testAgentOptions_env_defaultNil | P0 | AC1 | env defaults to nil |
| 5 | testAgentOptions_allowedTools_set | P0 | AC1 | allowedTools array can be set |
| 6 | testAgentOptions_allowedTools_defaultNil | P0 | AC1 | allowedTools defaults to nil |
| 7 | testAgentOptions_disallowedTools_set | P0 | AC1 | disallowedTools array can be set |
| 8 | testAgentOptions_disallowedTools_defaultNil | P0 | AC1 | disallowedTools defaults to nil |
| 9 | testAgentOptions_allowedAndDisallowedTools_bothSet | P0 | AC1 | Both lists can coexist |
| 10 | testAgentOptions_backwardCompat_existingInit | P0 | AC1 | Existing init without new fields still compiles |

### AdvancedConfigFieldsATDDTests (10 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testAgentOptions_effort_set | P0 | AC2 | effort can be set to EffortLevel |
| 2 | testAgentOptions_effort_defaultNil | P0 | AC2 | effort defaults to nil |
| 3 | testAgentOptions_outputFormat_set | P0 | AC2 | outputFormat can be set |
| 4 | testAgentOptions_outputFormat_defaultNil | P0 | AC2 | outputFormat defaults to nil |
| 5 | testAgentOptions_toolConfig_set | P0 | AC2 | toolConfig can be set |
| 6 | testAgentOptions_toolConfig_defaultNil | P0 | AC2 | toolConfig defaults to nil |
| 7 | testAgentOptions_includePartialMessages_defaultTrue | P0 | AC2 | includePartialMessages defaults to true |
| 8 | testAgentOptions_includePartialMessages_setFalse | P0 | AC2 | includePartialMessages can be set to false |
| 9 | testAgentOptions_promptSuggestions_defaultFalse | P0 | AC2 | promptSuggestions defaults to false |
| 10 | testAgentOptions_promptSuggestions_setTrue | P0 | AC2 | promptSuggestions can be set to true |

### SessionConfigFieldsATDDTests (9 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testAgentOptions_continueRecentSession_defaultFalse | P0 | AC3 | continueRecentSession defaults to false |
| 2 | testAgentOptions_continueRecentSession_setTrue | P0 | AC3 | continueRecentSession can be set to true |
| 3 | testAgentOptions_forkSession_defaultFalse | P0 | AC3 | forkSession defaults to false |
| 4 | testAgentOptions_forkSession_setTrue | P0 | AC3 | forkSession can be set to true |
| 5 | testAgentOptions_resumeSessionAt_set | P0 | AC3 | resumeSessionAt can be set to a UUID |
| 6 | testAgentOptions_resumeSessionAt_defaultNil | P0 | AC3 | resumeSessionAt defaults to nil |
| 7 | testAgentOptions_persistSession_defaultTrue | P0 | AC3 | persistSession defaults to true |
| 8 | testAgentOptions_persistSession_setFalse | P0 | AC3 | persistSession can be set to false |
| 9 | testAgentOptions_sessionFields_withExistingSessionConfig | P0 | AC3 | Session fields integrate with sessionId |

### SystemPromptConfigOnOptionsATDDTests (4 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testAgentOptions_systemPromptConfig_set | P0 | AC7 | systemPromptConfig can be set to .preset |
| 2 | testAgentOptions_systemPromptConfig_defaultNil | P0 | AC7 | systemPromptConfig defaults to nil |
| 3 | testAgentOptions_systemPromptConfig_coexistsWithSystemPrompt | P0 | AC7 | systemPromptConfig and systemPrompt coexist |
| 4 | testAgentOptions_systemPrompt_backwardCompat | P0 | AC7 | systemPrompt works alone (backward compat) |

### ConfigBasedInitATDDTests (2 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testInitFromConfig_newFieldsDefaultValues | P0 | AC1-7 | init(from:) sets all new fields to defaults |
| 2 | testInitFromConfig_preservesExistingFields | P0 | AC8 | init(from:) preserves existing config values |

### AgentOptionsSendableATDDTests (6 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testEffortLevel_isSendable | P0 | AC8 | EffortLevel conforms to Sendable |
| 2 | testOutputFormat_isSendable | P0 | AC8 | OutputFormat conforms to Sendable |
| 3 | testSendableJSONSchema_isSendable | P0 | AC8 | SendableJSONSchema conforms to Sendable |
| 4 | testToolConfig_isSendable | P0 | AC8 | ToolConfig conforms to Sendable |
| 5 | testSystemPromptConfig_isSendable | P0 | AC8 | SystemPromptConfig conforms to Sendable |
| 6 | testAgentOptions_withNewFields_isSendable | P0 | AC8 | AgentOptions with all new fields still Sendable |

### BackwardCompatATDDTests (4 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testDefaultInit_noParameters | P0 | AC8 | Default init still works |
| 2 | testExistingParameterizedInit | P0 | AC8 | Existing parameterized init still works |
| 3 | testExistingFieldsAccessible | P0 | AC8 | All 38 original fields still accessible |
| 4 | testValidation_existingChecksStillWork | P0 | AC8 | Existing validation logic still works |

### AllFieldsIntegrationATDDTests (2 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testAllNewFields_together | P0 | Integration | All new fields can be used simultaneously |
| 2 | testMixedOldAndNewFields | P1 | Integration | Mix of old and new fields works correctly |

## Priority Distribution

| Priority | Count |
|----------|-------|
| P0 | 63 |
| P1 | 8 |
| **Total** | **71** |

## New Types Required by Tests

| Type | Kind | Fields / Cases | Notes |
|------|------|----------------|-------|
| EffortLevel | enum (String, Sendable, Equatable, CaseIterable) | .low, .medium, .high, .max | budgetTokens computed property (1024/5120/10240/32768) |
| OutputFormat | struct (Sendable) | type: String (always "json_schema"), jsonSchema: SendableJSONSchema | Wraps JSON Schema for structured output |
| SendableJSONSchema | struct (@unchecked Sendable) | schema: [String: Any] | Same pattern as SendableStructuredOutput from Story 17-1 |
| ToolConfig | struct (Sendable, Equatable) | maxConcurrentReadTools: Int?, maxConcurrentWriteTools: Int? | Defaults to nil for both |
| SystemPromptConfig | enum (Sendable, Equatable) | .text(String), .preset(name: String, append: String?) | Preset support for system prompt |

## New AgentOptions Fields Required by Tests

| Field | Type | Default | AC |
|-------|------|---------|----|
| fallbackModel | String? | nil | AC1 |
| env | [String: String]? | nil | AC1 |
| allowedTools | [String]? | nil | AC1 |
| disallowedTools | [String]? | nil | AC1 |
| effort | EffortLevel? | nil | AC2 |
| outputFormat | OutputFormat? | nil | AC2 |
| toolConfig | ToolConfig? | nil | AC2 |
| includePartialMessages | Bool | true | AC2 |
| promptSuggestions | Bool | false | AC2 |
| continueRecentSession | Bool | false | AC3 |
| forkSession | Bool | false | AC3 |
| resumeSessionAt | String? | nil | AC3 |
| persistSession | Bool | true | AC3 |
| systemPromptConfig | SystemPromptConfig? | nil | AC7 |

## TDD Red Phase Confirmation

**Status: RED** -- All 71 tests fail to compile because:
1. EffortLevel enum doesn't exist
2. OutputFormat struct doesn't exist
3. SendableJSONSchema struct doesn't exist
4. ToolConfig struct doesn't exist
5. SystemPromptConfig enum doesn't exist
6. 14 new properties don't exist on AgentOptions (fallbackModel, env, allowedTools, disallowedTools, effort, outputFormat, toolConfig, includePartialMessages, promptSuggestions, continueRecentSession, forkSession, resumeSessionAt, persistSession, systemPromptConfig)
7. AgentOptions.init() and init(from:) don't accept new parameters

Compilation errors confirm these tests exercise code that has NOT been implemented yet.

## Key Risks & Assumptions

1. **SendableJSONSchema vs SendableStructuredOutput**: Story 17-1 established the `SendableStructuredOutput` wrapper pattern. The new `SendableJSONSchema` follows the same approach. If the implementation reuses `SendableStructuredOutput` directly instead of creating a new wrapper, the OutputFormat tests may need minor adjustment.
2. **EffortLevel.budgetTokens**: The story specifies budget token mappings (low=1024, medium=5120, high=10240, max=32768). This is implemented as a computed property. If the implementation uses a different approach (e.g., a static method), the test may need adjustment.
3. **InMemorySessionStore**: The session integration test uses `sessionId` only (no `InMemorySessionStore`) since that concrete type doesn't exist in the test target. Session integration testing with a real store will be done during development.
4. **init ordering**: Swift uses labeled arguments so parameter order doesn't matter for callers. Tests use labeled init calls.
5. **No runtime behavior tests**: These ATDD tests cover type definitions, field presence, defaults, and conformance. Runtime behavior (tool filtering, effort-to-thinking wiring, session integration) will be tested during the development phase.

## Next Steps

1. Run `/bmad-dev-story 17-2` to implement the feature (TDD green phase)
2. All 71 ATDD tests should transition from RED to GREEN
3. Run full test suite (3722+ tests) to verify zero regression (AC8)

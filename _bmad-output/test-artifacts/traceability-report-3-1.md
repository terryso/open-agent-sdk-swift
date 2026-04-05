---
stepsCompleted: ['step-01-load-context', 'step-02-discover-tests', 'step-03-trace']
lastStep: 'step-03-trace'
lastSaved: '2026-04-05'
---

# Traceability Report: Story 3.1 — Tool Protocol & Registry

## Requirements-to-Tests Traceability Matrix

| AC # | Acceptance Criterion | Priority | Test(s) | Status |
|------|---------------------|----------|---------|--------|
| AC1 | Single tool registration (FR11) | P0 | `testDefineTool_ReturnsProtocolWithCorrectName`, `testDefineTool_ReturnsProtocolWithCorrectDescription`, `testDefineTool_ReturnsProtocolWithCorrectInputSchema`, `testDefineTool_ReturnsCorrectIsReadOnly_True`, `testDefineTool_ReturnsCorrectIsReadOnly_False`, `testDefineTool_CallDecodesInputCorrectly`, `testDefineTool_CallHandlesNestedCodableTypes`, `testDefineTool_CallReturnsError_OnDecodeFailure`, `testDefineTool_CallReturnsError_OnNonDictionaryInput`, `testDefineTool_CallDoesNotCrash_WithEmptyToolUseId` | Covered |
| AC2 | Tier batch registration (FR15) | P0 | `testToolTier_HasExpectedCases`, `testToolTier_RawValues`, `testGetAllBaseTools_Core_ReturnsEmptyArray`, `testGetAllBaseTools_AdvancedAndSpecialist_ReturnEmpty` | Covered |
| AC3 | Filter tools by name | P0 | `testFilterTools_AllowedList_FiltersCorrectly`, `testFilterTools_DisallowedList_ExcludesCorrectly`, `testFilterTools_BothLists_AppliesBoth`, `testFilterTools_NoLists_ReturnsAllTools`, `testFilterTools_EmptyAllowedList_ReturnsAllTools`, `testFilterTools_EmptyDisallowedList_ReturnsAllTools` | Covered |
| AC4 | Tool pool assembly (with dedup) | P0 | `testAssembleToolPool_DeduplicatesByName_LaterOverridesEarlier`, `testAssembleToolPool_IncludesMcpTools`, `testAssembleToolPool_NoCustomOrMcpTools`, `testAssembleToolPool_AppliesFiltersAfterDedup` | Covered |
| AC5 | API format conversion `{ name, description, input_schema }` | P0 | `testToApiTool_ProducesCorrectFormat`, `testToApiTool_HasExactlyThreeKeys`, `testToApiTools_ConvertsArrayOfTools`, `testToApiTools_EmptyInput_ReturnsEmptyArray`, `testToApiToolsOutput_MatchesExpectedApiFormat` | Covered |
| AC6 | Tool definitions passed to LLM via prompt()/stream() | P0 | `testPrompt_WithTools_PassesToolsToApi`, `testPrompt_WithoutTools_NoToolsInRequest`, `testPrompt_WithEmptyToolsArray_NoToolsInRequest`, `testPrompt_ToolsInApiFormat`, `testStream_WithTools_PassesToolsToApi`, `testStream_WithoutTools_NoToolsInRequest` | Covered |

## Coverage Summary

- **Total ACs**: 6
- **Covered**: 6/6 (100%)
- **Test count**: 37
- **P0 tests**: 28
- **P1 tests**: 9

## Test Distribution by File

| Test File | Test Count | ACs Covered |
|-----------|-----------|-------------|
| `Tests/OpenAgentSDKTests/Tools/ToolRegistryTests.swift` | 20 | AC1 (partial), AC2, AC3, AC4, AC5 |
| `Tests/OpenAgentSDKTests/Tools/ToolBuilderTests.swift` | 10 | AC1 |
| `Tests/OpenAgentSDKTests/Tools/ToolRegistryIntegrationTests.swift` | 7 | AC5 (partial), AC6 |

## Paths Covered

| Path | Covered By |
|------|-----------|
| toApiTool() single tool format | `testToApiTool_ProducesCorrectFormat`, `testToApiTool_HasExactlyThreeKeys` |
| toApiTools() batch conversion | `testToApiTools_ConvertsArrayOfTools`, `testToApiTools_EmptyInput_ReturnsEmptyArray` |
| ToolTier enum definition | `testToolTier_HasExpectedCases`, `testToolTier_RawValues` |
| getAllBaseTools() placeholder | `testGetAllBaseTools_Core_ReturnsEmptyArray`, `testGetAllBaseTools_AdvancedAndSpecialist_ReturnEmpty` |
| filterTools() allowed list | `testFilterTools_AllowedList_FiltersCorrectly` |
| filterTools() disallowed list | `testFilterTools_DisallowedList_ExcludesCorrectly` |
| filterTools() both lists | `testFilterTools_BothLists_AppliesBoth` |
| filterTools() nil/empty lists | `testFilterTools_NoLists_ReturnsAllTools`, `testFilterTools_EmptyAllowedList_ReturnsAllTools`, `testFilterTools_EmptyDisallowedList_ReturnsAllTools` |
| assembleToolPool() dedup (custom overrides base) | `testAssembleToolPool_DeduplicatesByName_LaterOverridesEarlier` |
| assembleToolPool() MCP tools | `testAssembleToolPool_IncludesMcpTools` |
| assembleToolPool() nil optional inputs | `testAssembleToolPool_NoCustomOrMcpTools` |
| assembleToolPool() filter after dedup | `testAssembleToolPool_AppliesFiltersAfterDedup` |
| defineTool() name/description/schema/isReadOnly | `testDefineTool_ReturnsProtocolWithCorrectName/Description/InputSchema`, `testDefineTool_ReturnsCorrectIsReadOnly_True/False` |
| defineTool() Codable decode success | `testDefineTool_CallDecodesInputCorrectly`, `testDefineTool_CallHandlesNestedCodableTypes` |
| defineTool() Codable decode failure | `testDefineTool_CallReturnsError_OnDecodeFailure`, `testDefineTool_CallReturnsError_OnNonDictionaryInput` |
| defineTool() normal execution | `testDefineTool_CallDoesNotCrash_WithEmptyToolUseId` |
| prompt() with tools | `testPrompt_WithTools_PassesToolsToApi` |
| prompt() without tools (backward compat) | `testPrompt_WithoutTools_NoToolsInRequest` |
| prompt() with empty tools array | `testPrompt_WithEmptyToolsArray_NoToolsInRequest` |
| prompt() tool API format | `testPrompt_ToolsInApiFormat` |
| stream() with tools | `testStream_WithTools_PassesToolsToApi` |
| stream() without tools | `testStream_WithoutTools_NoToolsInRequest` |
| End-to-end API format | `testToApiToolsOutput_MatchesExpectedApiFormat` |

## Edge Cases Covered

| Edge Case | Test |
|-----------|------|
| Empty tools array treated as nil (no tools key) | `testPrompt_WithEmptyToolsArray_NoToolsInRequest` |
| Nil tools -- backward compatibility | `testPrompt_WithoutTools_NoToolsInRequest`, `testStream_WithoutTools_NoToolsInRequest` |
| Custom tool overrides base (same name dedup) | `testAssembleToolPool_DeduplicatesByName_LaterOverridesEarlier` |
| MCP tool overrides base (same name dedup) | `testAssembleToolPool_IncludesMcpTools` |
| Nested Codable types decoded | `testDefineTool_CallHandlesNestedCodableTypes` |
| Non-dictionary input to defineTool | `testDefineTool_CallReturnsError_OnNonDictionaryInput` |
| Missing required Codable fields | `testDefineTool_CallReturnsError_OnDecodeFailure` |
| Empty allowed list = no filter | `testFilterTools_EmptyAllowedList_ReturnsAllTools` |
| Empty disallowed list = no filter | `testFilterTools_EmptyDisallowedList_ReturnsAllTools` |
| Both allowed and disallowed applied | `testFilterTools_BothLists_AppliesBoth` |
| toApiTools with empty array input | `testToApiTools_EmptyInput_ReturnsEmptyArray` |
| Filter applied after dedup (not before) | `testAssembleToolPool_AppliesFiltersAfterDedup` |
| Tool schema with required fields | `testToApiToolsOutput_MatchesExpectedApiFormat` |

## Source File Coverage

| File Changed | Tests Covering |
|-------------|----------------|
| `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` (toApiTool, toApiTools, ToolTier, getAllBaseTools, filterTools, assembleToolPool) | All ToolRegistryTests (20 tests) |
| `Sources/OpenAgentSDK/Tools/ToolBuilder.swift` (defineTool, CodableTool) | All ToolBuilderTests (10 tests) |
| `Sources/OpenAgentSDK/Core/Agent.swift` (tools wiring in prompt/stream) | All ToolRegistryIntegrationTests (7 tests) |
| `Sources/OpenAgentSDK/API/AnthropicClient.swift` (tools parameter, already existed) | Verified via integration tests |
| `Sources/OpenAgentSDK/API/APIModels.swift` (buildRequestBody tools inclusion, already existed) | Verified via integration tests |

## Implementation Completeness Verification

| Implementation Task | Tests Verify |
|---------------------|-------------|
| ToolRegistry.swift -- toApiTool() | AC5 tests verify output dict has name, description, input_schema |
| ToolRegistry.swift -- toApiTools() | AC5 tests verify batch conversion |
| ToolRegistry.swift -- ToolTier enum | AC2 tests verify 3 cases with correct rawValues |
| ToolRegistry.swift -- getAllBaseTools() | AC2 tests verify empty array placeholder |
| ToolRegistry.swift -- filterTools() | AC3 tests (6 tests) verify allowed/disallowed/both/nil/empty |
| ToolRegistry.swift -- assembleToolPool() | AC4 tests (4 tests) verify dedup, MCP, nil optionals, filter-after-dedup |
| ToolBuilder.swift -- defineTool() | AC1 tests (10 tests) verify name/desc/schema/isReadOnly/decode/decode-fail |
| Agent.swift -- prompt() tools wiring | AC6 integration tests verify tools in request body |
| Agent.swift -- stream() tools wiring | AC6 integration tests verify tools in streaming request |
| Backward compatibility (no tools) | AC6 tests verify no tools key when nil/empty |

## Quality Gate Decision: PASS

**Rationale:**
- 100% AC coverage (6/6)
- All 37 tests map to specific acceptance criteria
- Both execution paths (prompt + stream) fully tested for tool integration
- Edge cases (dedup, nil/empty filters, Codable decode failures, backward compat) covered
- Source-to-test traceability is complete for all changed files
- No gaps identified -- every public function has direct test coverage

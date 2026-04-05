---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-05'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/3-1-tool-protocol-registry.md'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/API/AnthropicClient.swift'
  - 'Sources/OpenAgentSDK/API/APIModels.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/OpenAgentSDK.swift'
  - 'Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift'
  - 'Tests/OpenAgentSDKTests/API/AnthropicClientTests.swift'
  - 'Tests/OpenAgentSDKTests/Utils/MicroCompactTests.swift'
---

# ATDD Checklist - Epic 3, Story 3.1: Tool Protocol & Registry

**Date:** 2026-04-05
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (XCTest) with Integration Tests

---

## Story Summary

As a developer, I want to register individual tools or tool tiers with an Agent so that the LLM knows which tools are available for execution.

**Key scope:**
- Tool registration, filtering, and deduplication infrastructure
- `toApiTool()` format conversion for Anthropic API
- `defineTool()` factory for custom tool creation with Codable bridging
- Agent integration: passing tool definitions to the API on prompt/stream

**Out of scope (future stories):**
- Concrete tool implementations (3.4-3.7)
- Tool execution / tool_use parsing (3.3)
- Advanced defineTool overloads (3.2)

---

## Acceptance Criteria

1. **AC1: Single tool registration** -- Developer registers a single `ToolProtocol` tool, and it appears in the tool definitions sent to the LLM (FR11).
2. **AC2: Tier batch registration** -- Developer registers a "core" tool tier, and all tools in that tier are registered at once with name, description, and `inputSchema` (FR15).
3. **AC3: Filter tools by name** -- Developer filters tools by name pattern, only matching tools included.
4. **AC4: Tool pool assembly (with dedup)** -- Base + custom tools merged, deduplicated by name (latter overrides former), then filtered.
5. **AC5: API format conversion** -- `toApiTool()` converts `ToolProtocol` to `{ name, description, input_schema }`.
6. **AC6: Tool definitions passed to LLM** -- When Agent calls `prompt()` or `stream()`, registered tools' `inputSchema` is passed as `tools` parameter to the Anthropic API.

---

## Failing Tests Created (RED Phase)

### Unit Tests -- ToolRegistryTests (20 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/ToolRegistryTests.swift` (~300 lines)

- **Test:** `testToApiTool_ProducesCorrectFormat`
  - **Status:** RED -- `toApiTool(_:)` does not exist yet
  - **Verifies:** AC5 -- output has name, description, input_schema keys

- **Test:** `testToApiTool_HasExactlyThreeKeys`
  - **Status:** RED -- `toApiTool(_:)` does not exist yet
  - **Verifies:** AC5 -- exactly 3 keys in output dict (no extra keys)

- **Test:** `testToApiTools_ConvertsArrayOfTools`
  - **Status:** RED -- `toApiTools(_:)` does not exist yet
  - **Verifies:** AC5 -- batch conversion preserves order and count

- **Test:** `testToApiTools_EmptyInput_ReturnsEmptyArray`
  - **Status:** RED -- `toApiTools(_:)` does not exist yet
  - **Verifies:** AC5 -- edge case: empty input returns empty output

- **Test:** `testToolTier_HasExpectedCases`
  - **Status:** RED -- `ToolTier` enum does not exist yet
  - **Verifies:** AC1/AC2 -- enum has core, advanced, specialist cases

- **Test:** `testToolTier_RawValues`
  - **Status:** RED -- `ToolTier` enum does not exist yet
  - **Verifies:** AC1/AC2 -- raw values match string names

- **Test:** `testGetAllBaseTools_Core_ReturnsEmptyArray`
  - **Status:** RED -- `getAllBaseTools(tier:)` does not exist yet
  - **Verifies:** AC2 -- core tier returns empty array (placeholder)

- **Test:** `testGetAllBaseTools_AdvancedAndSpecialist_ReturnEmpty`
  - **Status:** RED -- `getAllBaseTools(tier:)` does not exist yet
  - **Verifies:** AC2 -- other tiers return empty arrays

- **Test:** `testFilterTools_AllowedList_FiltersCorrectly`
  - **Status:** RED -- `filterTools(tools:allowed:disallowed:)` does not exist yet
  - **Verifies:** AC3 -- allowed list includes only matching tools

- **Test:** `testFilterTools_DisallowedList_ExcludesCorrectly`
  - **Status:** RED -- `filterTools(tools:allowed:disallowed:)` does not exist yet
  - **Verifies:** AC3 -- disallowed list excludes matching tools

- **Test:** `testFilterTools_BothLists_AppliesBoth`
  - **Status:** RED -- `filterTools(tools:allowed:disallowed:)` does not exist yet
  - **Verifies:** AC3 -- both lists applied, disallowed takes precedence

- **Test:** `testFilterTools_NoLists_ReturnsAllTools`
  - **Status:** RED -- `filterTools(tools:allowed:disallowed:)` does not exist yet
  - **Verifies:** AC3 -- nil lists return all tools

- **Test:** `testFilterTools_EmptyAllowedList_ReturnsAllTools`
  - **Status:** RED -- `filterTools(tools:allowed:disallowed:)` does not exist yet
  - **Verifies:** AC3 -- empty list treated as no filter

- **Test:** `testFilterTools_EmptyDisallowedList_ReturnsAllTools`
  - **Status:** RED -- `filterTools(tools:allowed:disallowed:)` does not exist yet
  - **Verifies:** AC3 -- empty list treated as no filter

- **Test:** `testAssembleToolPool_DeduplicatesByName_LaterOverridesEarlier`
  - **Status:** RED -- `assembleToolPool(baseTools:customTools:mcpTools:allowed:disallowed:)` does not exist yet
  - **Verifies:** AC4 -- dedup by name, custom overrides base

- **Test:** `testAssembleToolPool_IncludesMcpTools`
  - **Status:** RED -- `assembleToolPool(...)` does not exist yet
  - **Verifies:** AC4 -- MCP tools included in pool, override base

- **Test:** `testAssembleToolPool_NoCustomOrMcpTools`
  - **Status:** RED -- `assembleToolPool(...)` does not exist yet
  - **Verifies:** AC4 -- nil custom/MCP tools works correctly

- **Test:** `testAssembleToolPool_AppliesFiltersAfterDedup`
  - **Status:** RED -- `assembleToolPool(...)` does not exist yet
  - **Verifies:** AC4 -- filters applied after dedup

### Unit Tests -- ToolBuilderTests (10 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/ToolBuilderTests.swift` (~280 lines)

- **Test:** `testDefineTool_ReturnsProtocolWithCorrectName`
  - **Status:** RED -- `defineTool<Input: Codable>(...)` does not exist yet
  - **Verifies:** AC1 -- returned protocol has correct name

- **Test:** `testDefineTool_ReturnsProtocolWithCorrectDescription`
  - **Status:** RED -- `defineTool(...)` does not exist yet
  - **Verifies:** AC1 -- returned protocol has correct description

- **Test:** `testDefineTool_ReturnsProtocolWithCorrectInputSchema`
  - **Status:** RED -- `defineTool(...)` does not exist yet
  - **Verifies:** AC1 -- returned protocol preserves input schema

- **Test:** `testDefineTool_ReturnsCorrectIsReadOnly_True`
  - **Status:** RED -- `defineTool(...)` does not exist yet
  - **Verifies:** AC1 -- isReadOnly=true preserved

- **Test:** `testDefineTool_ReturnsCorrectIsReadOnly_False`
  - **Status:** RED -- `defineTool(...)` does not exist yet
  - **Verifies:** AC1 -- isReadOnly=false preserved

- **Test:** `testDefineTool_CallDecodesInputCorrectly`
  - **Status:** RED -- `defineTool(...)` does not exist yet
  - **Verifies:** AC1 -- call() decodes Codable input and invokes execute closure

- **Test:** `testDefineTool_CallHandlesNestedCodableTypes`
  - **Status:** RED -- `defineTool(...)` does not exist yet
  - **Verifies:** AC1 -- nested Codable types decoded correctly

- **Test:** `testDefineTool_CallReturnsError_OnDecodeFailure`
  - **Status:** RED -- `defineTool(...)` does not exist yet
  - **Verifies:** AC1 -- decoding failure returns isError=true

- **Test:** `testDefineTool_CallReturnsError_OnNonDictionaryInput`
  - **Status:** RED -- `defineTool(...)` does not exist yet
  - **Verifies:** AC1 -- non-dictionary input returns isError=true

- **Test:** `testDefineTool_CallDoesNotCrash_WithEmptyToolUseId`
  - **Status:** RED -- `defineTool(...)` does not exist yet
  - **Verifies:** AC1 -- normal execution produces correct result

### Integration Tests -- ToolRegistryIntegrationTests (7 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/ToolRegistryIntegrationTests.swift` (~350 lines)

- **Test:** `testPrompt_WithTools_PassesToolsToApi`
  - **Status:** RED -- Agent does not pass tools to AnthropicClient yet
  - **Verifies:** AC6 -- prompt() sends tools in API request body

- **Test:** `testPrompt_WithoutTools_NoToolsInRequest`
  - **Status:** RED -- Agent does not pass tools to AnthropicClient yet
  - **Verifies:** AC6 -- no tools key when tools are nil (backward compat)

- **Test:** `testPrompt_WithEmptyToolsArray_NoToolsInRequest`
  - **Status:** RED -- Agent does not pass tools to AnthropicClient yet
  - **Verifies:** AC6 -- empty tools array treated same as nil

- **Test:** `testPrompt_ToolsInApiFormat`
  - **Status:** RED -- Agent does not pass tools to AnthropicClient yet
  - **Verifies:** AC5+AC6 -- tools in request have correct API format

- **Test:** `testStream_WithTools_PassesToolsToApi`
  - **Status:** RED -- Agent does not pass tools to AnthropicClient yet
  - **Verifies:** AC6 -- stream() sends tools in API request body

- **Test:** `testStream_WithoutTools_NoToolsInRequest`
  - **Status:** RED -- Agent does not pass tools to AnthropicClient yet
  - **Verifies:** AC6 -- no tools key in stream request

- **Test:** `testToApiToolsOutput_MatchesExpectedApiFormat`
  - **Status:** RED -- `toApiTools(_:)` does not exist yet
  - **Verifies:** AC5+AC6 -- API format matches Anthropic spec exactly

---

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | Single tool registration | ToolBuilderTests (10 tests), ToolRegistryTests (ToolTier, getAllBaseTools) | P0 |
| AC2 | Tier batch registration | testToolTier_HasExpectedCases, testGetAllBaseTools_* | P0 |
| AC3 | Filter tools by name | testFilterTools_* (6 tests) | P0 |
| AC4 | Tool pool assembly + dedup | testAssembleToolPool_* (4 tests) | P0 |
| AC5 | API format conversion | testToApiTool_*, testToApiTools_*, testToApiToolsOutput_* | P0 |
| AC6 | Tools passed to LLM | testPrompt_*, testStream_* (6 integration tests) | P0 |

**Total: 37 tests covering all 6 acceptance criteria.**

---

## Test Strategy

### Stack Detection
- **Detected:** Backend (Swift Package with XCTest, no frontend/browser testing)
- **Mode:** AI Generation (acceptance criteria are clear, standard API/logic scenarios)

### Test Levels
- **Unit Tests (30):** Pure function tests for ToolRegistry, ToolBuilder, ToolTier
- **Integration Tests (7):** Agent + AnthropicClient interaction via MockURLProtocol

### Priority Distribution
- **P0 (Critical):** 28 tests -- core functionality that must work
- **P1 (Important):** 9 tests -- edge cases and additional coverage

---

## TDD Red Phase Validation

- [x] All tests assert EXPECTED behavior (not placeholder assertions)
- [x] All tests will FAIL until feature is implemented (functions/types do not exist)
- [x] No test uses `XCTSkip` -- tests are designed to fail at compile-time or runtime
- [x] Each test has clear Given/When/Then structure
- [x] Mock objects follow existing test patterns (MockURLProtocol, MockTool)
- [x] Integration tests follow existing AgentLoopTests patterns

---

## Implementation Guidance

### Files to Create
1. `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` -- toApiTool, toApiTools, ToolTier, getAllBaseTools, filterTools, assembleToolPool
2. `Sources/OpenAgentSDK/Tools/ToolBuilder.swift` -- defineTool<Input: Codable>() factory
3. `Sources/OpenAgentSDK/Tools/Core/` -- empty directory placeholder
4. `Sources/OpenAgentSDK/Tools/Advanced/` -- empty directory placeholder
5. `Sources/OpenAgentSDK/Tools/Specialist/` -- empty directory placeholder

### Files to Modify
1. `Sources/OpenAgentSDK/Core/Agent.swift` -- pass tools to AnthropicClient in prompt()/stream()
2. `Sources/OpenAgentSDK/OpenAgentSDK.swift` -- re-export public API

### Key Implementation Notes
- AnthropicClient already accepts `tools` parameter (verified in APIModels.swift)
- AgentOptions.tools already exists (verified in AgentTypes.swift)
- Only Agent.swift needs to wire tools through to the client
- Use Dictionary (not Set) for dedup to preserve insertion order
- defineTool must use JSONSerialization + JSONDecoder bridge for Codable decoding
- No force unwraps -- use guard/let throughout
- No Apple-specific frameworks -- cross-platform compatible

---

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Run `swift build` to verify compilation
2. Run `swift test` to verify tests pass
3. If any tests fail:
   - Fix implementation (feature bug)
   - Or fix test (test bug)
4. Commit passing tests

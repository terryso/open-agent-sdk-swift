---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
lastStep: step-04c-aggregate
lastSaved: '2026-04-11'
workflowType: testarch-atdd
inputDocuments:
  - _bmad-output/implementation-artifacts/11-2-skill-tool-skill-execution.md
  - Sources/OpenAgentSDK/Types/SkillTypes.swift
  - Sources/OpenAgentSDK/Tools/SkillRegistry.swift
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Tools/ToolBuilder.swift
  - Sources/OpenAgentSDK/Core/ToolExecutor.swift
---

# ATDD Checklist - Epic 11, Story 11.2: SkillTool Skill Execution Tool

**Date:** 2026-04-11
**Author:** Nick
**Primary Test Level:** Unit (Swift backend)

---

## Story Summary

Implement SkillTool to allow LLMs to discover and execute registered skills as tools.
Includes ToolRestrictionStack for managing tool restrictions during nested skill execution,
recursion depth limits, self-reference prevention, and model override metadata.

**As a** developer
**I want** the Agent to call registered skills through SkillTool
**So that** skills can be discovered and executed by the LLM as tools

---

## Acceptance Criteria

1. **AC1:** SkillTool registration and LLM discovery -- SkillTool finds skills via registry and returns JSON with promptTemplate
2. **AC2:** Tool restriction stack model -- push/pop restrictions with base tool filtering
3. **AC3:** Nested skill tool restrictions -- multi-level LIFO stack semantics
4. **AC4:** Model override -- SkillTool returns model field in JSON when skill has modelOverride
5. **AC5:** Self-reference cycle prevention -- error when skill restricts .skill
6. **AC6:** Error path tool restriction stack recovery -- defer ensures pop on error
7. **AC7:** Recursion depth limit -- configurable max depth (default 4)
8. **AC8:** Turn budget sharing -- skills share query's maxTurns, no independent budget

---

## Failing Tests Created (RED Phase)

### Unit Tests - SkillTool (18 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift` (475 lines)

| # | Test Name | Priority | AC | Status | Expected Failure |
|---|-----------|----------|-----|--------|-----------------|
| 1 | testCreateSkillTool_returnsToolProtocol | P0 | AC1 | RED | `createSkillTool` not found |
| 2 | testCreateSkillTool_hasValidInputSchema | P0 | AC1 | RED | `createSkillTool` not found |
| 3 | testSkillTool_findsSkillAndReturnsJSON | P0 | AC1 | RED | `createSkillTool` not found |
| 4 | testSkillTool_nonExistentSkill_returnsError | P0 | AC1 | RED | `createSkillTool` not found |
| 5 | testSkillTool_unavailableSkill_returnsError | P1 | AC1 | RED | `createSkillTool` not found |
| 6 | testSkillTool_resolvesByAlias | P1 | AC1 | RED | `createSkillTool` not found |
| 7 | testSkillTool_modelOverride_includedInJSON | P0 | AC4 | RED | `createSkillTool` not found |
| 8 | testSkillTool_noModelOverride_noModelField | P1 | AC4 | RED | `createSkillTool` not found |
| 9 | testSkillTool_selfReferenceRestriction_returnsError | P0 | AC5 | RED | `createSkillTool` not found |
| 10 | testSkillTool_nonSelfRestriction_succeeds | P1 | AC5 | RED | `createSkillTool` not found |
| 11 | testSkillTool_recursionDepthExceeded_returnsError | P0 | AC7 | RED | ToolContext missing fields |
| 12 | testSkillTool_withinDepthLimit_succeeds | P1 | AC7 | RED | ToolContext missing fields |
| 13 | testSkillTool_defaultMaxDepth_is4 | P1 | AC7 | RED | `createSkillTool` not found |
| 14 | testSkillTool_toolRestrictions_includedInJSON | P0 | AC2 | RED | `createSkillTool` not found |
| 15 | testSkillTool_noRestrictions_noAllowedToolsField | P1 | AC2 | RED | `createSkillTool` not found |
| 16 | testSkillTool_noIndependentTurnBudget | P0 | AC8 | RED | `createSkillTool` not found |
| 17 | testSkillTool_optionalArgs_acceptedInInput | P1 | AC1 | RED | `createSkillTool` not found |
| 18 | testSkillTool_withBuiltInCommitSkill | P1 | AC1 | RED | `createSkillTool` not found |

### Unit Tests - ToolRestrictionStack (16 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/ToolRestrictionStackTests.swift` (325 lines)

| # | Test Name | Priority | AC | Status | Expected Failure |
|---|-----------|----------|-----|--------|-----------------|
| 1 | testStack_initialState_isEmpty | P0 | AC2 | RED | `ToolRestrictionStack` not found |
| 2 | testStack_afterPush_isNotEmpty | P0 | AC2 | RED | `ToolRestrictionStack` not found |
| 3 | testStack_pushPop_isEmpty | P0 | AC2 | RED | `ToolRestrictionStack` not found |
| 4 | testCurrentAllowedTools_emptyStack_returnsAllTools | P0 | AC2 | RED | `ToolRestrictionStack` not found |
| 5 | testCurrentAllowedTools_withRestrictions_filtersTools | P0 | AC2 | RED | `ToolRestrictionStack` not found |
| 6 | testCurrentAllowedTools_caseInsensitiveMatching | P1 | AC2 | RED | `ToolRestrictionStack` not found |
| 7 | testStack_popRestores_fullToolSet | P1 | AC2 | RED | `ToolRestrictionStack` not found |
| 8 | testStack_nestedPush_topIsLastPushed | P0 | AC3 | RED | `ToolRestrictionStack` not found |
| 9 | testStack_nestedPop_innerRestores | P0 | AC3 | RED | `ToolRestrictionStack` not found |
| 10 | testStack_nestedPopBoth_restoresFullSet | P0 | AC3 | RED | `ToolRestrictionStack` not found |
| 11 | testStack_tripleNesting_LIFO | P1 | AC3 | RED | `ToolRestrictionStack` not found |
| 12 | testStack_pushWithSkillRestriction_canBeDetected | P0 | AC5 | RED | `ToolRestrictionStack` not found |
| 13 | testStack_popOnEmpty_doesNotCrash | P0 | AC6 | RED | `ToolRestrictionStack` not found |
| 14 | testStack_overPopping_doesNotCrash | P1 | AC6 | RED | `ToolRestrictionStack` not found |
| 15 | testStack_concurrentOperations_doNotCrash | P1 | AC6 | RED | `ToolRestrictionStack` not found |
| 16 | testStack_emptyRestrictions_noToolsAllowed | P1 | AC2 | RED | `ToolRestrictionStack` not found |
| 17 | testStack_nonExistentTool_notIncluded | P1 | AC2 | RED | `ToolRestrictionStack` not found |

---

## Acceptance Criteria Coverage Matrix

| AC | Description | SkillToolTests | StackTests | Total Tests |
|----|-------------|---------------|------------|-------------|
| AC1 | SkillTool registration & discovery | 8 | 0 | 8 |
| AC2 | Tool restriction stack basics | 2 | 8 | 10 |
| AC3 | Nested skill restrictions | 0 | 4 | 4 |
| AC4 | Model override | 2 | 0 | 2 |
| AC5 | Self-reference prevention | 2 | 1 | 3 |
| AC6 | Error path stack recovery | 0 | 3 | 3 |
| AC7 | Recursion depth limit | 3 | 0 | 3 |
| AC8 | Turn budget sharing | 1 | 0 | 1 |
| **Total** | | **18** | **17** | **35** |

---

## Implementation Checklist

### Test Group: SkillTool (AC1, AC4, AC5, AC7, AC8)

**Tasks to make all SkillTool tests pass:**

- [ ] Create `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift`
  - [ ] Define `SkillToolInput` Codable struct (`skill: String`, `args: String?`)
  - [ ] Implement `createSkillTool(registry:)` factory function using `defineTool`
  - [ ] Implement skill lookup via registry.find()
  - [ ] Implement availability check (skill.isAvailable)
  - [ ] Implement self-reference check (restrictions contain .skill)
  - [ ] Implement recursion depth check (context.skillNestingDepth >= maxSkillRecursionDepth)
  - [ ] Return JSON ToolResult with success, commandName, prompt, allowedTools, model
- [ ] Update `Sources/OpenAgentSDK/Types/ToolTypes.swift`
  - [ ] Add `skillRegistry: SkillRegistry?` to ToolContext
  - [ ] Add `restrictionStack: ToolRestrictionStack?` to ToolContext
  - [ ] Add `skillNestingDepth: Int` to ToolContext (default 0)
  - [ ] Add `maxSkillRecursionDepth: Int` to ToolContext (default 4)
  - [ ] Update `withToolUseId` to preserve new fields
  - [ ] Add `withSkillContext(depth:)` convenience method
- [ ] Update `Sources/OpenAgentSDK/Types/AgentTypes.swift`
  - [ ] Add `skillRegistry: SkillRegistry?` to AgentOptions
  - [ ] Add `maxSkillRecursionDepth: Int` to AgentOptions (default 4)
- [ ] Run: `swift build --build-tests` then `swift test --filter SkillToolTests`

### Test Group: ToolRestrictionStack (AC2, AC3, AC5, AC6)

**Tasks to make all ToolRestrictionStack tests pass:**

- [ ] Create `Sources/OpenAgentSDK/Tools/ToolRestrictionStack.swift`
  - [ ] Define `ToolRestrictionStack` as `final class: @unchecked Sendable`
  - [ ] Internal serial DispatchQueue for thread safety
  - [ ] `push(_ restrictions: [ToolRestriction])` method
  - [ ] `pop()` method (graceful on empty stack)
  - [ ] `currentAllowedToolNames(baseTools: [ToolProtocol]) -> [ToolProtocol]`
  - [ ] `isEmpty -> Bool` computed property
  - [ ] Case-insensitive matching: ToolRestriction.rawValue vs ToolProtocol.name
- [ ] Run: `swift build --build-tests` then `swift test --filter ToolRestrictionStackTests`

---

## Running Tests

```bash
# Build test target (verify compilation)
swift build --build-tests

# Run SkillTool tests
swift test --filter SkillToolTests

# Run ToolRestrictionStack tests
swift test --filter ToolRestrictionStackTests

# Run all tests for story 11.2
swift test --filter 'SkillToolTests|ToolRestrictionStackTests'

# Run full test suite
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

- All 35 tests written and failing (compilation errors)
- Failure reasons: missing types (`createSkillTool`, `ToolRestrictionStack`, ToolContext fields)
- Tests assert EXPECTED behavior, not implementation details

### GREEN Phase (DEV Team - Next Steps)

1. Implement `ToolRestrictionStack` first (no dependencies on other new code)
2. Update `ToolContext` with new fields
3. Implement `createSkillTool` factory function
4. Run tests incrementally: `swift test --filter ToolRestrictionStackTests` then `swift test --filter SkillToolTests`
5. Run full test suite to verify no regressions

### REFACTOR Phase (After All Tests Pass)

1. Verify all 35 new tests pass plus existing 2116 tests
2. Review for code quality, thread safety, naming conventions
3. Ensure case-insensitive matching is consistent
4. Run full test suite: `swift test`

---

## Test Execution Evidence

### Initial Build (RED Phase Verification)

**Command:** `swift build --build-tests`

**Result:** Compilation fails with 171 errors

**Key Failure Categories:**
- `cannot find 'createSkillTool' in scope` (18 occurrences)
- `cannot find 'ToolRestrictionStack' in scope` (17 occurrences)
- `extra arguments at positions #3, #4 in call` (ToolContext new fields)
- Cascading type inference errors from missing types

**Summary:**
- Total tests: 35 (18 SkillTool + 17 ToolRestrictionStack)
- Passing: 0 (expected - RED phase)
- Failing: 35 (expected - compilation errors)
- Status: RED phase verified

---

## Notes

- Tests follow existing project patterns (XCTest, @testable import, Given-When-Then comments)
- ToolRestrictionStack tests use `defineTool` to create mock tools (same pattern as existing tests)
- SkillToolTests reference BuiltInSkills.commit for integration validation
- Thread safety tests use DispatchQueue.concurrentPerform (same pattern as SkillRegistryTests)
- All new ToolContext fields are optional with defaults (backward compatible)

---

**Generated by BMad TEA Agent** - 2026-04-11

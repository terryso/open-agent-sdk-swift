---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-11'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/11-1-skill-type-definition-skill-registry.md'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Sources/OpenAgentSDK/Types/ErrorTypes.swift'
  - 'Sources/OpenAgentSDK/Tools/ToolRegistry.swift'
  - 'Sources/OpenAgentSDK/OpenAgentSDK.swift'
  - 'Tests/OpenAgentSDKTests/Types/ToolTypesTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/ToolRegistryTests.swift'
---

# ATDD Checklist - Epic 11, Story 11.1: Skill Type Definition & SkillRegistry

**Date:** 2026-04-11
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (XCTest)

---

## Story Summary

As a developer, I want to define skill types and manage skills through SkillRegistry, so that I can register, find, and list all available skills.

**Key scope:**
- `Skill` struct (value type) with name, description, aliases, userInvocable, toolRestrictions, modelOverride, isAvailable, promptTemplate, whenToUse, argumentHint
- `ToolRestriction` enum with all tool restriction cases
- `BuiltInSkills` namespace enum with static skill properties (commit, review, simplify, debug, test)
- `SkillRegistry` final class with register, find, replace, has, unregister, allSkills, userInvocableSkills, formatSkillsForPrompt, clear methods
- Thread safety via internal serial DispatchQueue

**Out of scope (future stories):**
- SkillTool execution (Story 11.2)
- Built-in skill implementations (Stories 11.3-11.7)
- TokenEstimator (Story 13.3)

---

## Acceptance Criteria

1. **AC1: Skill struct definition and creation** -- Skill struct with all fields, ToolRestriction enum, BuiltInSkills namespace
2. **AC2: SkillRegistry register and find** -- Register skill, find by name, find by alias
3. **AC3: SkillRegistry replace method** -- Replace skill definition, value type isolation
4. **AC4: userInvocableSkills filtering** -- Filter by userInvocable=true
5. **AC5: formatSkillsForPrompt text generation** -- Generate prompt text, 500 token budget, truncate trailing
6. **AC6: isAvailable availability filtering** -- Filter unavailable from userInvocableSkills and formatSkillsForPrompt, find does not filter

---

## Failing Tests Created (RED Phase)

### Unit Tests -- SkillTypesTests (17 tests)

**File:** `Tests/OpenAgentSDKTests/Types/SkillTypesTests.swift` (~270 lines)

- **Test:** `testSkill_CreationWithRequiredFields`
  - **Status:** RED -- `Skill` type does not exist yet
  - **Verifies:** AC1 -- Skill can be created with name and promptTemplate

- **Test:** `testSkill_CreationWithAllFields`
  - **Status:** RED -- `Skill` type does not exist yet
  - **Verifies:** AC1 -- Skill can be created with all optional fields

- **Test:** `testSkill_DefaultValues`
  - **Status:** RED -- `Skill` type does not exist yet
  - **Verifies:** AC1 -- Defaults: description="", aliases=[], userInvocable=true, toolRestrictions=nil, modelOverride=nil

- **Test:** `testSkill_ToolRestrictions_NilMeansNoRestrictions`
  - **Status:** RED -- `Skill` type does not exist yet
  - **Verifies:** AC1 -- nil toolRestrictions means all tools allowed

- **Test:** `testSkill_ToolRestrictions_SpecificTools`
  - **Status:** RED -- `Skill` type does not exist yet
  - **Verifies:** AC1 -- Specific tool restrictions are stored correctly

- **Test:** `testSkill_ValueTypeSemantics`
  - **Status:** RED -- `Skill` type does not exist yet
  - **Verifies:** AC1 -- Value type: modifying a copy does not affect original

- **Test:** `testSkill_IsAvailable_DefaultIsTrue`
  - **Status:** RED -- `Skill` type does not exist yet
  - **Verifies:** AC1 -- isAvailable defaults to { true }

- **Test:** `testSkill_IsAvailable_CustomReturnsFalse`
  - **Status:** RED -- `Skill` type does not exist yet
  - **Verifies:** AC1 -- isAvailable can be customized to return false

- **Test:** `testToolRestriction_HasAllCases`
  - **Status:** RED -- `ToolRestriction` enum does not exist yet
  - **Verifies:** AC1 -- All 21 expected tool restriction cases exist

- **Test:** `testToolRestriction_RawValues`
  - **Status:** RED -- `ToolRestriction` enum does not exist yet
  - **Verifies:** AC1 -- Raw values match tool name strings

- **Test:** `testToolRestriction_CaseIterable`
  - **Status:** RED -- `ToolRestriction` enum does not exist yet
  - **Verifies:** AC1 -- Conforms to CaseIterable with >= 20 cases

- **Test:** `testBuiltInSkills_Commit`
  - **Status:** RED -- `BuiltInSkills` enum does not exist yet
  - **Verifies:** AC1 -- BuiltInSkills.commit returns valid Skill

- **Test:** `testBuiltInSkills_Review`
  - **Status:** RED -- `BuiltInSkills` enum does not exist yet
  - **Verifies:** AC1 -- BuiltInSkills.review returns valid Skill

- **Test:** `testBuiltInSkills_Simplify`
  - **Status:** RED -- `BuiltInSkills` enum does not exist yet
  - **Verifies:** AC1 -- BuiltInSkills.simplify returns valid Skill

- **Test:** `testBuiltInSkills_Debug`
  - **Status:** RED -- `BuiltInSkills` enum does not exist yet
  - **Verifies:** AC1 -- BuiltInSkills.debug returns valid Skill

- **Test:** `testBuiltInSkills_Test`
  - **Status:** RED -- `BuiltInSkills` enum does not exist yet
  - **Verifies:** AC1 -- BuiltInSkills.test returns valid Skill with isAvailable check

- **Test:** `testBuiltInSkills_ReturnsNewInstances`
  - **Status:** RED -- `BuiltInSkills` enum does not exist yet
  - **Verifies:** AC1 -- BuiltInSkills returns new value type instances each access

### Unit Tests -- SkillRegistryTests (27 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/SkillRegistryTests.swift` (~400 lines)

- **Test:** `testRegisterAndFind_ByName`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC2 -- Register and find by name

- **Test:** `testFind_ByAlias`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC2 -- Find by alias

- **Test:** `testFind_NonExistent_ReturnsNil`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC2 -- Non-existent returns nil

- **Test:** `testHas_RegisteredSkill_ReturnsTrue`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC2 -- has() returns true for registered skill

- **Test:** `testHas_NonExistentSkill_ReturnsFalse`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC2 -- has() returns false for non-existent skill

- **Test:** `testRegister_MultipleSkills`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC2 -- Multiple skills can be registered

- **Test:** `testRegister_MultipleAliases`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC2 -- Multiple aliases work for find

- **Test:** `testReplace_UpdatesSkillDefinition`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC3 -- Replace updates skill in registry

- **Test:** `testReplace_ValueTypeIsolation`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC3 -- Old references unaffected after replace

- **Test:** `testReplace_WithAliases`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC3 -- Replace with new aliases

- **Test:** `testUserInvocableSkills_FiltersNonInvocable`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC4 -- Filters userInvocable=false

- **Test:** `testUserInvocableSkills_EmptyRegistry`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC4 -- Empty registry returns empty

- **Test:** `testUserInvocableSkills_FiltersUnavailable`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC4+AC6 -- Also filters unavailable

- **Test:** `testFormatSkillsForPrompt_ContainsSkillInfo`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC5 -- Text contains skill names and descriptions

- **Test:** `testFormatSkillsForPrompt_TokenBudgetLimit`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC5 -- Respects 500 token budget

- **Test:** `testFormatSkillsForPrompt_OnlyIncludesInvocableAndAvailable`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC5+AC6 -- Only userInvocable && available skills

- **Test:** `testFormatSkillsForPrompt_EmptyRegistry`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC5 -- Empty registry returns empty string

- **Test:** `testFormatSkillsForPrompt_TruncatesTrailingSkills`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC5 -- Truncates trailing skills over budget

- **Test:** `testIsAvailable_ExcludedFromUserInvocableSkills`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC6 -- Unavailable excluded from userInvocableSkills

- **Test:** `testIsAvailable_ExcludedFromFormatSkillsForPrompt`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC6 -- Unavailable excluded from formatSkillsForPrompt

- **Test:** `testIsAvailable_FindDoesNotFilter`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC6 -- find() does not filter by availability

- **Test:** `testIsAvailable_FindByAliasDoesNotFilter`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** AC6 -- find by alias also doesn't filter

- **Test:** `testAllSkills_ReturnsAllRegistered`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** allSkills returns all including non-invocable

- **Test:** `testClear_RemovesAllSkills`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** clear() removes all skills and aliases

- **Test:** `testUnregister_RemovesSpecificSkill`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** unregister() removes skill and aliases

- **Test:** `testUnregister_NonExistent_ReturnsFalse`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** unregister() returns false for non-existent

- **Test:** `testConcurrentRegistration_DoesNotCrash`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** Thread safety -- concurrent registrations

- **Test:** `testConcurrentRead_DoesNotCrash`
  - **Status:** RED -- `SkillRegistry` class does not exist yet
  - **Verifies:** Thread safety -- concurrent reads

---

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | Skill struct, ToolRestriction, BuiltInSkills | SkillTypesTests (17 tests) | P0 |
| AC2 | SkillRegistry register + find | SkillRegistryTests (7 tests) | P0 |
| AC3 | SkillRegistry replace | SkillRegistryTests (3 tests) | P0 |
| AC4 | userInvocableSkills filtering | SkillRegistryTests (3 tests) | P0 |
| AC5 | formatSkillsForPrompt text + budget | SkillRegistryTests (5 tests) | P0 |
| AC6 | isAvailable filtering | SkillRegistryTests (4 tests) | P0 |
| -- | Thread safety | SkillRegistryTests (2 tests) | P1 |
| -- | clear/unregister | SkillRegistryTests (3 tests) | P1 |

**Total: 44 tests covering all 6 acceptance criteria.**

---

## Test Strategy

### Stack Detection
- **Detected:** Backend (Swift Package with XCTest, no frontend/browser testing)
- **Mode:** AI Generation (acceptance criteria are clear, standard API/logic scenarios)

### Test Levels
- **Unit Tests (44):** Pure logic tests for Skill struct, ToolRestriction enum, BuiltInSkills namespace, and SkillRegistry class

### Priority Distribution
- **P0 (Critical):** 39 tests -- core functionality that must work
- **P1 (Important):** 5 tests -- edge cases and concurrency safety

---

## TDD Red Phase Validation

- [x] All tests assert EXPECTED behavior (not placeholder assertions)
- [x] All tests will FAIL until feature is implemented (types/classes do not exist)
- [x] No test uses `XCTSkip` -- tests are designed to fail at compile-time
- [x] Each test has clear Given/When/Then structure
- [x] Test helper `makeSkill()` follows existing `makeMockTool()` pattern from ToolRegistryTests
- [x] Build verification: `swift build` succeeds (library clean), `swift build --build-tests` fails with 147 compile errors (RED phase confirmed)

---

## Implementation Guidance

### Files to Create
1. `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- Skill struct, ToolRestriction enum, BuiltInSkills enum
2. `Sources/OpenAgentSDK/Tools/SkillRegistry.swift` -- SkillRegistry final class with DispatchQueue

### Files to Modify
1. `Sources/OpenAgentSDK/OpenAgentSDK.swift` -- Add re-exports for Skill, SkillRegistry, BuiltInSkills, ToolRestriction

### Key Implementation Notes
- Skill is a **struct** (value type) -- must conform to Sendable
- SkillRegistry is a **final class** (not Actor) -- uses internal serial DispatchQueue for thread safety
- ToolRestriction rawValues must match tool name strings exactly
- BuiltInSkills is an enum with **no cases** (pure namespace)
- isAvailable is a `@Sendable () -> Bool` closure
- formatSkillsForPrompt uses simple `utf8.count / 4` token estimation (TokenEstimator in Story 13.3)
- 500 token budget = ~2000 ASCII characters
- No force unwraps -- use guard/let throughout
- No Apple-specific frameworks -- cross-platform compatible

---

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Run `swift build` to verify compilation
2. Run `swift test` to verify all 44 new tests pass (plus existing suite)
3. If any tests fail:
   - Fix implementation (feature bug)
   - Or fix test (test bug)
4. Commit passing tests

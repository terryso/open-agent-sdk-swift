---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-12'
inputDocuments:
  - _bmad-output/implementation-artifacts/11-6-built-in-skill-debug.md
  - Sources/OpenAgentSDK/Types/SkillTypes.swift
  - Sources/OpenAgentSDK/Tools/SkillRegistry.swift
  - Tests/OpenAgentSDKTests/Tools/BuiltInSkills/SimplifySkillTests.swift
---

# ATDD Checklist: Story 11.6 -- Built-in Debug Skill

## TDD Red Phase (Current)

- **Status:** RED -- 19 failing tests, 13 passing tests
- **Test File:** `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/DebugSkillTests.swift`
- **Total Tests:** 32 tests

## Acceptance Criteria Coverage

### AC1: DebugSkill Registration & PromptTemplate Error Analysis & Root Cause Identification (FR53)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testDebugSkill_HasCorrectName` | P0 | PASS | Name is "debug" |
| `testDebugSkill_HasCorrectAliases` | P0 | PASS | Aliases contains "investigate" and "diagnose" |
| `testDebugSkill_IsUserInvocable` | P0 | PASS | userInvocable is true |
| `testDebugSkill_HasCorrectToolRestrictions` | P0 | **FAIL** | toolRestrictions is nil (needs [.bash, .read, .grep, .glob]) |
| `testDebugSkill_IncludesBashForDiagnostics` | P0 | **FAIL** | toolRestrictions is nil, no .bash |
| `testDebugSkill_DoesNotIncludeWriteOrEdit` | P0 | PASS | No .write or .edit in restrictions |
| `testAC1_PromptTemplate_ContainsRootCauseAnalysis` | P0 | PASS | Contains "root cause" |
| `testAC1_PromptTemplate_GuidesUseReadAndGrep` | P0 | **FAIL** | Missing "grep" keyword in template |
| `testAC1_PromptTemplate_GuidesUseBashForDiagnostics` | P0 | PASS | Contains "git log" |
| `testAC1_PromptTemplate_DoesNotInstructDirectFix` | P0 | **FAIL** | Still has "Implement the minimal fix" phrase |
| `testDebugSkill_IsAvailableByDefault` | P1 | PASS | isAvailable returns true |
| `testDebugSkill_HasNonEmptyDescription` | P1 | PASS | Description is non-empty |
| `testAC1_Description_ReflectsDiagnosticPurpose` | P1 | PASS | Description mentions "investigation" |

### AC2: Output Includes Root Cause Analysis, Reproduction Steps, and Fix Suggestions with File:Line References

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAC2_PromptTemplate_RequiresFileAndLineNumberReferences` | P0 | **FAIL** | No explicit file:line format requirement |
| `testAC2_PromptTemplate_ReferencesSpecificFileNames` | P0 | **FAIL** | No "file name" instruction |
| `testAC2_PromptTemplate_ReferencesLineNumbers` | P0 | **FAIL** | No "line number" instruction |
| `testAC2_PromptTemplate_ContainsRootCauseSection` | P0 | PASS | Contains "root cause" |
| `testAC2_PromptTemplate_ContainsReproductionSteps` | P0 | PASS | Contains "Reproduce" |
| `testAC2_PromptTemplate_ContainsFixSuggestions` | P0 | **FAIL** | Missing fix suggestion keywords |
| `testAC2_PromptTemplate_HandlesNoErrorMessage` | P0 | **FAIL** | No handling for missing error info |

### AC3: Multiple Root Causes Sorted by Likelihood

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAC3_PromptTemplate_RequiresRootCauseSorting` | P0 | **FAIL** | No likelihood/possibility sorting instruction |
| `testAC3_PromptTemplate_HandlesMultipleRootCauses` | P0 | **FAIL** | No "multiple root cause" handling |
| `testAC3_PromptTemplate_OrdersMostToLeastLikely` | P1 | **FAIL** | No "most likely" ordering instruction |

### Edge Cases

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testPromptTemplate_HandlesBuildFailureScenario` | P0 | **FAIL** | No build failure guidance |
| `testPromptTemplate_HandlesRuntimeCrashScenario` | P0 | **FAIL** | No runtime crash guidance |

### Registry Integration

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testDebugSkill_CanBeRegisteredAndFound` | P1 | PASS | SkillRegistry integration |
| `testDebugSkill_CanBeFoundByAliasInvestigate` | P1 | PASS | Alias "investigate" lookup |
| `testDebugSkill_CanBeFoundByAliasDiagnose` | P1 | PASS | Alias "diagnose" lookup |
| `testDebugSkill_OverridableViaRegistryReplace` | P0 | PASS | registry.replace() overrides promptTemplate |
| `testDebugSkill_ReturnsNewInstance` | P1 | PASS | Value type semantics |
| `testDebugSkill_HasNoModelOverride` | P1 | PASS | No model override |
| `testDebugSkill_HasNonEmptyPromptTemplate` | P1 | PASS | Non-empty promptTemplate |

## Test Strategy

- **Test Level:** Unit tests (Swift/XCTest)
- **Stack:** Backend (Swift Package Manager)
- **Framework:** XCTest
- **Isolation:** Each test creates fresh `SkillRegistry` instances; no mocks needed
- **Focus:** promptTemplate text content validation and SkillRegistry integration

## Confirmed Failures (TDD Red Phase)

Verified by running `swift test --filter DebugSkillTests` -- 19 failures, 13 passes:

1. **`testDebugSkill_HasCorrectToolRestrictions`** -- toolRestrictions is nil (needs [.bash, .read, .grep, .glob])
2. **`testDebugSkill_IncludesBashForDiagnostics`** -- toolRestrictions is nil, no .bash
3. **`testAC1_PromptTemplate_GuidesUseReadAndGrep`** -- Missing "grep" keyword in template
4. **`testAC1_PromptTemplate_DoesNotInstructDirectFix`** -- Still has "Implement the minimal fix" phrase
5. **`testAC2_PromptTemplate_RequiresFileAndLineNumberReferences`** -- No explicit file:line format requirement
6. **`testAC2_PromptTemplate_ReferencesSpecificFileNames`** -- No "file name" instruction
7. **`testAC2_PromptTemplate_ReferencesLineNumbers`** -- No "line number" instruction
8. **`testAC2_PromptTemplate_ContainsFixSuggestions`** -- Missing fix suggestion keywords
9. **`testAC2_PromptTemplate_HandlesNoErrorMessage`** -- No handling for missing error info
10. **`testAC3_PromptTemplate_RequiresRootCauseSorting`** -- No likelihood/possibility sorting
11. **`testAC3_PromptTemplate_HandlesMultipleRootCauses`** -- No multiple root cause handling
12. **`testAC3_PromptTemplate_OrdersMostToLeastLikely`** -- No most-to-least ordering
13. **`testPromptTemplate_HandlesBuildFailureScenario`** -- No build failure guidance
14. **`testPromptTemplate_HandlesRuntimeCrashScenario`** -- No runtime crash guidance

## Next Steps (TDD Green Phase)

After implementing the promptTemplate update:

1. Update `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- refine `BuiltInSkills.debug` promptTemplate
2. Run tests: `swift test --filter DebugSkillTests`
3. Verify ALL 32 tests PASS (green phase)
4. Run full test suite: `swift test` (ensure no regressions)
5. Commit passing tests and updated promptTemplate

## Implementation Guidance

The promptTemplate must be updated to include:

1. **Add toolRestrictions:** Set `toolRestrictions: [.read, .grep, .glob, .bash]`
2. **Remove "Implement the minimal fix":** Replace with fix suggestion/instruction (diagnostic tool, not auto-fix)
3. **Add file:line format requirement:** Require `path/to/file.swift:行号` format for all findings
4. **Add file name and line number instructions:** Explicit instructions to reference file names and line numbers
5. **Add fix suggestion section:** Explicit "fix suggestion" or "suggested fix" section in output
6. **Add no error message handling:** Handle scenario where user provides no specific error
7. **Add multiple root cause sorting:** Sort by likelihood/possibility when multiple causes found
8. **Add "most likely first" ordering:** Explicit most-to-least-likely direction
9. **Add build failure guidance:** Specific instructions for build failure scenarios
10. **Add runtime crash guidance:** Specific instructions for runtime crash scenarios
11. **Update description:** Make description reflect diagnostic/analysis purpose more precisely
12. **Add Grep tool guidance:** Explicit instruction to use Grep for code search

## Generated Files

- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/DebugSkillTests.swift` -- 32 ATDD tests

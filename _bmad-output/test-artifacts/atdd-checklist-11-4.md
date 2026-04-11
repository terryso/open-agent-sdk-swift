---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-11'
inputDocuments:
  - _bmad-output/implementation-artifacts/11-4-built-in-skill-review.md
  - Sources/OpenAgentSDK/Types/SkillTypes.swift
  - Sources/OpenAgentSDK/Tools/SkillRegistry.swift
  - Tests/OpenAgentSDKTests/Tools/BuiltInSkills/CommitSkillTests.swift
---

# ATDD Checklist: Story 11.4 -- Built-in Review Skill

## TDD Red Phase (Current)

- **Status:** RED -- 12 failing tests, 19 passing tests
- **Test File:** `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/ReviewSkillTests.swift`
- **Total Tests:** 31 tests

## Acceptance Criteria Coverage

### AC1: ReviewSkill Registration & PromptTemplate Multi-Dimensional Review (FR53)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testReviewSkill_HasCorrectName` | P0 | PASS | Name is "review" |
| `testReviewSkill_HasCorrectAliases` | P0 | PASS | Aliases contains "review-pr" and "cr" |
| `testReviewSkill_IsUserInvocable` | P0 | PASS | userInvocable is true |
| `testReviewSkill_HasCorrectToolRestrictions` | P0 | PASS | toolRestrictions = [.bash, .read, .glob, .grep] |
| `testAC1_PromptTemplate_ContainsCorrectnessDimension` | P0 | PASS | Contains "correctness" dimension |
| `testAC1_PromptTemplate_ContainsSecurityDimension` | P0 | PASS | Contains "security" dimension |
| `testAC1_PromptTemplate_ContainsPerformanceDimension` | P0 | PASS | Contains "performance" dimension |
| `testAC1_PromptTemplate_ContainsStyleDimension` | P0 | PASS | Contains "style" dimension |
| `testAC1_PromptTemplate_ContainsTestingCoverageDimension` | P0 | **FAIL** | Must include "testing coverage" (not just "testing") |
| `testReviewSkill_CanBeRegisteredAndFound` | P1 | PASS | SkillRegistry integration |
| `testReviewSkill_CanBeFoundByAliasReviewPR` | P1 | PASS | Alias "review-pr" lookup |
| `testReviewSkill_CanBeFoundByAliasCR` | P1 | PASS | Alias "cr" lookup |
| `testReviewSkill_IsAvailableByDefault` | P1 | PASS | isAvailable returns true |
| `testReviewSkill_HasNonEmptyDescription` | P1 | PASS | Description is non-empty |

### AC2: Review Results Reference Specific Locations

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAC2_PromptTemplate_RequiresFileAndLineNumberReferences` | P0 | **FAIL** | Must require `file:line` format (e.g., `file.swift:42`) |
| `testAC2_PromptTemplate_ReferencesSpecificFileNames` | P0 | PASS | Mentions file names |
| `testAC2_PromptTemplate_ReferencesLineNumbers` | P0 | PASS | Mentions line numbers |

### AC3: Multi-Level Change Source Strategy

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAC3_PromptTemplate_ContainsGitDiffUnstaged` | P0 | PASS | `git diff` for unstaged changes |
| `testAC3_PromptTemplate_ContainsGitDiffCached` | P0 | **FAIL** | Missing `git diff --cached` for staged changes |
| `testAC3_PromptTemplate_ContainsGitDiffHeadTilde1` | P0 | **FAIL** | Missing `git diff HEAD~1` for last commit |
| `testAC3_PromptTemplate_UsesThreeLevelPriority` | P1 | **FAIL** | Needs all three levels in priority order |
| `testAC3_PromptTemplate_DoesNotUseGitDiffMainHead` | P0 | **FAIL** | Currently uses `git diff main...HEAD` (must remove) |
| `testAC3_PromptTemplate_HandlesNoChanges` | P1 | **FAIL** | Missing empty diff handling |

### AC4: Output Sorted by Severity

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAC4_PromptTemplate_ContainsSeverityOrdering` | P0 | **FAIL** | Missing severity ordering instruction |
| `testAC4_PromptTemplate_SecurityFirst` | P0 | **FAIL** | Security not indicated as highest priority |
| `testAC4_PromptTemplate_CorrectnessSecond` | P0 | **FAIL** | Correctness not indicated as second |
| `testAC4_PromptTemplate_TestingLast` | P0 | **FAIL** | Testing not indicated as lowest priority |
| `testAC4_PromptTemplate_DoesNotUseCriticalSuggestionsFormat` | P0 | **FAIL** | Still uses old Critical/Suggestions/Questions format |

### Edge Cases & Registry

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testReviewSkill_ReturnsNewInstance` | P1 | PASS | Value type semantics |
| `testAC4_PromptTemplate_OverridableViaRegistryReplace` | P0 | PASS | registry.replace() overrides promptTemplate |
| `testAC4_RegistryReplace_PreservesAliasLookup` | P0 | PASS | Alias "cr" still works after replace |

## Test Strategy

- **Test Level:** Unit tests (Swift/XCTest)
- **Stack:** Backend (Swift Package Manager)
- **Framework:** XCTest
- **Isolation:** Each test creates fresh `SkillRegistry` instances; no mocks needed
- **Focus:** promptTemplate text content validation and SkillRegistry integration

## Confirmed Failures (TDD Red Phase)

Verified by running `swift test --filter ReviewSkillTests` -- 12 failures, 19 passes:

1. **`testAC1_PromptTemplate_ContainsTestingCoverageDimension`** -- Current template says "Testing" without "coverage"
2. **`testAC2_PromptTemplate_RequiresFileAndLineNumberReferences`** -- No explicit file:line format requirement
3. **`testAC3_PromptTemplate_ContainsGitDiffCached`** -- Missing `git diff --cached`
4. **`testAC3_PromptTemplate_ContainsGitDiffHeadTilde1`** -- Missing `git diff HEAD~1`
5. **`testAC3_PromptTemplate_UsesThreeLevelPriority`** -- Does not have all three levels
6. **`testAC3_PromptTemplate_DoesNotUseGitDiffMainHead`** -- Still contains `git diff main...HEAD`
7. **`testAC3_PromptTemplate_HandlesNoChanges`** -- No handling for empty diff output
8. **`testAC4_PromptTemplate_ContainsSeverityOrdering`** -- No severity ordering instruction
9. **`testAC4_PromptTemplate_SecurityFirst`** -- Security not indicated as highest priority
10. **`testAC4_PromptTemplate_CorrectnessSecond`** -- Correctness not indicated as second
11. **`testAC4_PromptTemplate_TestingLast`** -- Testing not indicated as lowest priority
12. **`testAC4_PromptTemplate_DoesNotUseCriticalSuggestionsFormat`** -- Still uses old Critical/Suggestions/Questions

## Next Steps (TDD Green Phase)

After implementing the promptTemplate update:

1. Update `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- refine `BuiltInSkills.review` promptTemplate
2. Run tests: `swift test --filter ReviewSkillTests`
3. Verify ALL 31 tests PASS (green phase)
4. Run full test suite: `swift test` (ensure no regressions)
5. Commit passing tests and updated promptTemplate

## Implementation Guidance

The promptTemplate must be updated to include:

1. **Three-level change acquisition strategy:** `git diff` (unstaged) -> `git diff --cached` (staged) -> `git diff HEAD~1` (last commit)
2. **Remove `git diff main...HEAD`:** Replace with `git diff HEAD~1`
3. **Five review dimensions with explicit "coverage" wording:** correctness, security, performance, style, testing coverage
4. **File:line references:** Each finding must explicitly require `path/to/file.swift:行号` format
5. **Severity ordering:** security > correctness > performance > style > testing
6. **Remove old Critical/Suggestions/Questions format:** Replace with severity-ordered output
7. **No-changes handling:** Handle empty diff output gracefully

## Generated Files

- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/ReviewSkillTests.swift` -- 31 ATDD tests

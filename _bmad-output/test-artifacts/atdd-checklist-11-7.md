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
  - _bmad-output/implementation-artifacts/11-7-built-in-skill-test.md
  - Sources/OpenAgentSDK/Types/SkillTypes.swift
  - Sources/OpenAgentSDK/Tools/SkillRegistry.swift
  - Tests/OpenAgentSDKTests/Tools/BuiltInSkills/DebugSkillTests.swift
---

# ATDD Checklist: Story 11.7 -- Built-in Test Skill

## TDD Red Phase (Current)

- **Status:** RED -- 14 failing tests, 16 passing tests
- **Test File:** `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/TestSkillTests.swift`
- **Total Tests:** 30 tests

## Acceptance Criteria Coverage

### AC1: TestSkill Registration & PromptTemplate Guides Test Generation and Execution (FR53)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testTestSkill_HasCorrectName` | P0 | PASS | Name is "test" |
| `testTestSkill_HasCorrectAliases` | P0 | PASS | Aliases contains "run-tests" |
| `testTestSkill_IsUserInvocable` | P0 | PASS | userInvocable is true |
| `testTestSkill_HasCorrectToolRestrictions` | P0 | **FAIL** | toolRestrictions has 6 items (includes .edit), needs 5 (bash, read, write, glob, grep) |
| `testTestSkill_DoesNotIncludeEdit` | P0 | **FAIL** | toolRestrictions includes .edit (should be removed) |
| `testAC1_PromptTemplate_ContainsTestGenerationKeywords` | P0 | **FAIL** | Missing "generate test" / "test case" / "write test" keywords |
| `testAC1_PromptTemplate_ContainsTestExecutionKeywords` | P0 | **FAIL** | Missing "run test" / "execute test" / "swift test" keywords |
| `testAC1_PromptTemplate_GuidesUseRead` | P0 | PASS | Contains "read" |
| `testAC1_PromptTemplate_GuidesUseGlob` | P0 | **FAIL** | Missing "glob" keyword |
| `testAC1_PromptTemplate_GuidesUseWrite` | P0 | **FAIL** | Missing "write" keyword |
| `testAC1_PromptTemplate_GuidesUseBash` | P0 | PASS | Contains "run"/"execute" |
| `testTestSkill_HasNonEmptyDescription` | P1 | PASS | Description is non-empty |
| `testAC1_Description_ReflectsTestPurpose` | P1 | PASS | Description mentions "test" |

### AC2: Output Includes Test Code, Execution Results, and Coverage Suggestions

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAC2_PromptTemplate_ContainsCoverageSuggestions` | P0 | **FAIL** | Missing "coverage" / "覆盖率" keywords |
| `testAC2_PromptTemplate_RequiresFileAndLineNumberReferences` | P0 | **FAIL** | No explicit file:line format requirement |
| `testAC2_PromptTemplate_ReferencesSpecificFileNames` | P0 | **FAIL** | No "file name" instruction |
| `testAC2_PromptTemplate_ReferencesLineNumbers` | P0 | **FAIL** | No "line number" instruction |
| `testAC2_PromptTemplate_RequiresComprehensiveTestPaths` | P0 | **FAIL** | No "normal path" / "happy path" keywords |
| `testAC2_PromptTemplate_RequiresBoundaryConditions` | P0 | **FAIL** | No "boundary" / "edge case" keywords |
| `testAC2_PromptTemplate_RequiresErrorHandlingPaths` | P0 | **FAIL** | No "error handling" / "error path" keywords |
| `testAC2_PromptTemplate_ContainsTestExecutionResults` | P0 | **FAIL** | Missing "test result" / "execution result" keywords |
| `testAC2_PromptTemplate_ContainsTestCodeGeneration` | P0 | PASS | Contains "test suite" |

### AC3: Environment Availability Check

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAC3_IsAvailable_WhenPackageSwiftExists` | P0 | PASS | isAvailable returns true when Package.swift exists |
| `testAC3_IsAvailable_ChecksFrameworkIndicators` | P0 | PASS | Closure checks indicator files correctly |

### Registry Integration

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testTestSkill_CanBeRegisteredAndFound` | P1 | PASS | SkillRegistry integration |
| `testTestSkill_CanBeFoundByAliasRunTests` | P1 | PASS | Alias "run-tests" lookup |
| `testTestSkill_OverridableViaRegistryReplace` | P0 | PASS | registry.replace() overrides promptTemplate |
| `testTestSkill_ReturnsNewInstance` | P1 | PASS | Value type semantics |
| `testTestSkill_HasNoModelOverride` | P1 | PASS | No model override |
| `testTestSkill_HasNonEmptyPromptTemplate` | P1 | PASS | Non-empty promptTemplate |

## Test Strategy

- **Test Level:** Unit tests (Swift/XCTest)
- **Stack:** Backend (Swift Package Manager)
- **Framework:** XCTest
- **Isolation:** Each test creates fresh `SkillRegistry` instances; no mocks needed
- **Focus:** promptTemplate text content validation and SkillRegistry integration

## Confirmed Failures (TDD Red Phase)

Verified by running `swift test --filter TestSkillTests` -- 14 failures, 16 passes:

1. **`testTestSkill_HasCorrectToolRestrictions`** -- toolRestrictions has 6 items (includes .edit), needs exactly 5
2. **`testTestSkill_DoesNotIncludeEdit`** -- toolRestrictions includes .edit (must be removed per epics.md)
3. **`testAC1_PromptTemplate_ContainsTestGenerationKeywords`** -- Missing "generate test" / "test case" / "write test"
4. **`testAC1_PromptTemplate_ContainsTestExecutionKeywords`** -- Missing "run test" / "execute test" / "swift test"
5. **`testAC1_PromptTemplate_GuidesUseGlob`** -- Missing "glob" keyword in template
6. **`testAC1_PromptTemplate_GuidesUseWrite`** -- Missing "write" keyword in template
7. **`testAC2_PromptTemplate_ContainsCoverageSuggestions`** -- Missing "coverage" / "覆盖率"
8. **`testAC2_PromptTemplate_RequiresFileAndLineNumberReferences`** -- No file:line format requirement
9. **`testAC2_PromptTemplate_ReferencesSpecificFileNames`** -- No "file name" instruction
10. **`testAC2_PromptTemplate_ReferencesLineNumbers`** -- No "line number" instruction
11. **`testAC2_PromptTemplate_RequiresComprehensiveTestPaths`** -- No normal path keywords
12. **`testAC2_PromptTemplate_RequiresBoundaryConditions`** -- No boundary/edge case keywords
13. **`testAC2_PromptTemplate_RequiresErrorHandlingPaths`** -- No error handling keywords
14. **`testAC2_PromptTemplate_ContainsTestExecutionResults`** -- Missing test result keywords

## Next Steps (TDD Green Phase)

After implementing the promptTemplate update:

1. Update `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- refine `BuiltInSkills.test` promptTemplate
2. Remove `.edit` from `toolRestrictions` (should be `[.bash, .read, .write, .glob, .grep]`)
3. Update `description` to reflect test generation and execution purpose
4. Run tests: `swift test --filter TestSkillTests`
5. Verify ALL 30 tests PASS (green phase)
6. Run full test suite: `swift test` (ensure no regressions)
7. Commit passing tests and updated promptTemplate

## Implementation Guidance

The promptTemplate and metadata must be updated to include:

1. **Remove .edit from toolRestrictions:** Change from `[.bash, .read, .write, .edit, .glob, .grep]` to `[.bash, .read, .write, .glob, .grep]`
2. **Add test generation guidance:** Keywords like "generate test", "test case", "write test"
3. **Add test execution guidance:** Keywords like "run test", "execute test", "swift test"
4. **Add Glob tool guidance:** Explicit instruction to use Glob to find existing test files
5. **Add Write tool guidance:** Explicit instruction to use Write to create/update test files
6. **Add coverage suggestions:** Explicit "coverage" or "覆盖率" section in output
7. **Add file:line format requirement:** Require `path/to/file.swift:行号` format for all findings
8. **Add file name and line number instructions:** Reference file names and line numbers in output
9. **Add normal path testing:** "normal path" or "happy path" test coverage
10. **Add boundary condition testing:** "boundary" or "edge case" test coverage
11. **Add error handling path testing:** "error handling" or "error path" test coverage
12. **Add test execution results:** "test result" or "execution result" output requirement
13. **Update description:** Make description reflect test generation and execution purpose

## Generated Files

- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/TestSkillTests.swift` -- 30 ATDD tests

---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-13'
inputDocuments:
  - _bmad-output/implementation-artifacts/15-1-skills-example.md
  - _bmad-output/planning-artifacts/english/epics.md
  - Sources/OpenAgentSDK/Types/SkillTypes.swift
  - Sources/OpenAgentSDK/Tools/SkillRegistry.swift
  - Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift
  - Tests/OpenAgentSDKTests/Documentation/PermissionsExampleComplianceTests.swift
  - Tests/OpenAgentSDKTests/Documentation/ExamplesComplianceTests.swift
---

# ATDD Checklist: Story 15.1 -- SkillsExample

## TDD Red Phase (Current)

**Phase:** RED -- All tests assert expected behavior and will FAIL until implementation is complete.

- **Stack detected:** backend (Swift SPM, XCTest)
- **Generation mode:** AI generation (backend project, no browser recording needed)
- **Execution mode:** sequential

## Test Files Generated

| # | File | Tests | Level | TDD Phase |
|---|------|-------|-------|-----------|
| 1 | `Tests/OpenAgentSDKTests/Documentation/SkillsExampleComplianceTests.swift` | 38 | Integration | RED |

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Names | Test Level |
|----|-------------|----------|------------|------------|
| AC1 | Example compiles and runs | P0 | `testSkillsExampleDirectoryExists`, `testSkillsExampleMainSwiftExists`, `testSkillsExampleImportsOpenAgentSDK`, `testSkillsExampleImportsFoundation` | Integration |
| AC2 | Built-in skills initialization | P0 | `testSkillsExampleCreatesSkillRegistry`, `testSkillsExampleRegistersAllBuiltInSkills`, `testSkillsExampleRegistersBuiltInSkillsIntoRegistry` | Integration |
| AC3 | List all registered skills | P0 | `testSkillsExampleOutputsAllRegisteredSkills`, `testSkillsExamplePrintsSkillNameDescriptionAndAliases` | Integration |
| AC4 | List user-invocable skills | P0 | `testSkillsExampleOutputsUserInvocableSkills`, `testSkillsExampleDemonstratesFilteringDifference` | Integration |
| AC5 | Register custom skill | P0 | `testSkillsExampleRegistersCustomSkill`, `testSkillsExampleCustomSkillHasPromptTemplate`, `testSkillsExampleCustomSkillHasAliases`, `testSkillsExampleCustomSkillAppearsInAllSkills` | Integration |
| AC6 | Find skill by name and alias | P0 | `testSkillsExampleDemonstratesFindByName`, `testSkillsExampleDemonstratesFindByAlias` | Integration |
| AC7 | Agent invokes skill via LLM | P0 | `testSkillsExampleCreatesAgentWithSkillTool`, `testSkillsExampleAppendsSkillToolToTools`, `testSkillsExampleCreatesAgentWithOptions`, `testSkillsExamplePassesToolsIncludingSkillTool`, `testSkillsExampleUsesBypassPermissions`, `testSkillsExampleSendsQueryToAgent`, `testSkillsExamplePrintsAgentResponse`, `testSkillsExamplePrintsQueryStatistics` | Integration |
| AC8 | Package.swift updated | P0 | `testPackageSwiftContainsSkillsExampleTarget`, `testSkillsExampleTargetDependsOnOpenAgentSDK`, `testSkillsExampleTargetSpecifiesCorrectPath` | Integration |

## Additional Quality Checks

| Category | Test Names | Risk |
|----------|------------|------|
| API key loading pattern | `testSkillsExampleUsesLoadDotEnvPattern`, `testSkillsExampleUsesGetEnvPattern` | P1 |
| No exposed real API keys | `testSkillsExampleDoesNotExposeRealAPIKeys` | P0 |
| Code documentation | `testSkillsExampleHasTopLevelDescriptionComment`, `testSkillsExampleHasMultipleInlineComments`, `testSkillsExampleHasMarkSections` | P1 |
| No force unwrap | `testSkillsExampleDoesNotUseForceUnwrap` | P1 |
| Real API signatures | `testSkillsExampleUsesRealSkillStructInit`, `testSkillsExampleUsesRealQueryResultProperties`, `testSkillsExampleUsesAwaitForPrompt` | P0 |

## Test Strategy

- **Integration/Compliance tests** validate the example file structure, API usage, and code quality
- Tests follow the exact same pattern as `PermissionsExampleComplianceTests` and other existing example compliance tests
- All tests check for file existence, content patterns, and correct API usage
- Tests are self-contained and do not depend on external state (no LLM calls)
- Error paths verified via file existence and content checks

## Implementation Endpoints

The following files need to be created/modified:

1. **Create** `Examples/SkillsExample/main.swift` -- Full SkillsExample source demonstrating:
   - SkillRegistry creation and built-in skill registration
   - Listing all skills and user-invocable skills
   - Custom skill registration with name, description, aliases, promptTemplate
   - Finding skills by name and alias
   - Agent creation with SkillTool and core tools
   - Agent query with skill invocation
   - Query statistics output
2. **Modify** `Package.swift` -- Add SkillsExample executable target following existing pattern

## TDD Red Phase Verification

- **All 38 tests FAIL** (confirmed via `swift test --filter SkillsExampleComplianceTests`)
- Tests compile successfully (no build errors)
- Tests assert EXPECTED behavior (not placeholders)
- Tests will PASS once the SkillsExample is implemented

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Run `swift build` to verify compilation
2. Run `swift test --filter SkillsExampleComplianceTests` to verify all tests PASS
3. If tests fail:
   - Fix implementation (feature bug), OR
   - Fix test (test bug)
4. Run the full test suite to verify no regressions
5. Commit passing tests alongside implementation

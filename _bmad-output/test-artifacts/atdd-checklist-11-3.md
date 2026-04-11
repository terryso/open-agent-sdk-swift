---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-11'
inputDocuments:
  - _bmad-output/implementation-artifacts/11-3-built-in-skill-commit.md
  - Sources/OpenAgentSDK/Types/SkillTypes.swift
  - Sources/OpenAgentSDK/Tools/SkillRegistry.swift
  - Tests/OpenAgentSDKTests/Types/SkillTypesTests.swift
  - Tests/OpenAgentSDKTests/Tools/SkillRegistryTests.swift
---

# ATDD Checklist: Story 11.3 -- Built-in Commit Skill

## TDD Red Phase (Current)

- **Status:** RED -- 6 failing tests, 20 passing tests
- **Test File:** `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/CommitSkillTests.swift`
- **Total Tests:** 26 tests

## Acceptance Criteria Coverage

### AC1: CommitSkill Registration & PromptTemplate Executes Git Analysis (FR53)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testCommitSkill_HasCorrectName` | P0 | PASS | Name is "commit" |
| `testCommitSkill_HasCorrectAliases` | P0 | PASS | Aliases contains "ci" |
| `testCommitSkill_IsUserInvocable` | P0 | PASS | userInvocable is true |
| `testCommitSkill_HasCorrectToolRestrictions` | P0 | PASS | toolRestrictions = [.bash, .read, .glob, .grep] |
| `testAC1_PromptTemplate_ContainsGitStatusShort` | P0 | **FAIL** | promptTemplate contains `git status --short` |
| `testAC1_PromptTemplate_ContainsGitDiffCached` | P0 | PASS | promptTemplate contains `git diff --cached` |
| `testAC1_PromptTemplate_ContainsGitDiffForUnstaged` | P0 | PASS | promptTemplate contains `git diff` for unstaged |
| `testAC1_PromptTemplate_UsesShortFormat` | P1 | **FAIL** | Uses `--short` flag (not plain `git status`) |
| `testCommitSkill_CanBeRegisteredAndFound` | P1 | PASS | SkillRegistry integration |
| `testCommitSkill_CanBeFoundByAlias` | P1 | PASS | Alias "ci" lookup in registry |
| `testCommitSkill_IsAvailableByDefault` | P1 | PASS | isAvailable returns true |
| `testCommitSkill_HasNonEmptyDescription` | P1 | PASS | Description is non-empty |

### AC2: No Staged Changes But Has Unstaged Changes

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAC2_PromptTemplate_ContainsNoStagedHasUnstagedGuidance` | P0 | **FAIL** | Must contain `git add` instruction |
| `testAC2_PromptTemplate_MentionsEmptyStagedDiff` | P0 | PASS | Handles empty `git diff --cached` |
| `testAC2_PromptTemplate_InstructsToListUnstagedFiles` | P1 | PASS | Lists specific unstaged files |

### AC3: No Changes At All

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAC3_PromptTemplate_ContainsNoChangesHandling` | P0 | **FAIL** | Must explicitly handle "no changes" |
| `testAC3_PromptTemplate_SuggestsActionWhenNoChanges` | P1 | PASS | Suggests specific actions |

### AC4: Has Staged Changes Generates Commit Message (Customizable)

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testAC4_PromptTemplate_RequiresImperativeMood` | P0 | PASS | Imperative mood required |
| `testAC4_PromptTemplate_Enforces72CharLimit` | P0 | PASS | 72 character title limit |
| `testAC4_PromptTemplate_DoesNotExecuteGitCommit` | P0 | **FAIL** | Must say "do not commit" |
| `testAC4_PromptTemplate_DoesNotSayCreateTheCommit` | P0 | **FAIL** | Removed "Create the commit" step |
| `testAC4_PromptTemplate_SupportsMultiParagraphFormat` | P1 | PASS | Multi-paragraph format (title + body) |
| `testAC4_PromptTemplate_OverridableViaRegistryReplace` | P0 | PASS | registry.replace() overrides promptTemplate |
| `testAC4_RegistryReplace_PreservesAliasLookup` | P0 | PASS | Alias "ci" still works after replace |

### Edge Cases

| Test | Priority | Status | Description |
|------|----------|--------|-------------|
| `testCommitSkill_ReturnsNewInstance` | P1 | PASS | Value type semantics |
| `testPromptTemplate_DoesNotInstructPushByDefault` | P2 | PASS | No push unless explicitly asked |

## Test Strategy

- **Test Level:** Unit tests (Swift/XCTest)
- **Stack:** Backend (Swift Package Manager)
- **Framework:** XCTest
- **Isolation:** Each test creates fresh `SkillRegistry` instances; no mocks needed
- **Focus:** promptTemplate text content validation and SkillRegistry integration

## Confirmed Failures (TDD Red Phase)

Verified by running `swift test --filter CommitSkillTests` -- 6 failures:

1. **`testAC1_PromptTemplate_ContainsGitStatusShort`** -- Current template uses `git status` not `git status --short`
2. **`testAC1_PromptTemplate_UsesShortFormat`** -- Missing `--short` flag
3. **`testAC2_PromptTemplate_ContainsNoStagedHasUnstagedGuidance`** -- Current template lacks `git add` instruction
4. **`testAC3_PromptTemplate_ContainsNoChangesHandling`** -- Missing explicit "no changes" handling step
5. **`testAC4_PromptTemplate_DoesNotExecuteGitCommit`** -- Current template says "Create the commit", no "do not commit" instruction
6. **`testAC4_PromptTemplate_DoesNotSayCreateTheCommit`** -- "Create the commit" must be removed

## Next Steps (TDD Green Phase)

After implementing the promptTemplate update:

1. Update `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- refine `BuiltInSkills.commit` promptTemplate
2. Run tests: `swift test --filter CommitSkillTests`
3. Verify ALL 26 tests PASS (green phase)
4. Run full test suite: `swift test` (ensure no regressions)
5. Commit passing tests and updated promptTemplate

## Implementation Guidance

The promptTemplate must be updated to include:

1. **Step 1:** Run `git status --short` (not `git status`)
2. **Step 2:** Run `git diff --cached` to check staged changes
3. **Step 3:** If `git diff --cached` is empty, run `git diff` for unstaged changes
   - List specific unstaged files
   - Suggest running `git add` to stage them
   - Do NOT generate a commit message
4. **Step 4:** If both diffs are empty, inform user there are no changes to commit
   - Suggest what to do (create changes, etc.)
5. **Step 5:** If staged changes exist, generate commit message with:
   - Imperative mood
   - Title under 72 characters
   - Multi-paragraph format (title + blank line + body)
   - Do NOT execute `git commit`
   - Do NOT push to remote (unless explicitly asked)

## Generated Files

- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/CommitSkillTests.swift` -- 26 ATDD tests

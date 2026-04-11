import XCTest
@testable import OpenAgentSDK

// MARK: - CommitSkill ATDD Tests (Story 11.3)

/// ATDD tests for Story 11.3 -- Built-in Commit Skill.
///
/// TDD RED PHASE: These tests assert the EXPECTED behavior of the refined
/// CommitSkill promptTemplate. They will FAIL until the promptTemplate is
/// updated to meet all four acceptance criteria (AC1-AC4).
///
/// Coverage:
/// - AC1: promptTemplate executes git analysis (git status --short, git diff --cached, git diff)
/// - AC2: No staged but has unstaged changes handling
/// - AC3: No changes at all handling
/// - AC4: Has staged changes generates commit message (imperative mood, 72 chars, no actual commit)
final class CommitSkillTests: XCTestCase {

    // MARK: - Test Subject

    /// The commit skill under test.
    private var commitSkill: Skill!

    override func setUp() {
        super.setUp()
        commitSkill = BuiltInSkills.commit
    }

    override func tearDown() {
        commitSkill = nil
        super.tearDown()
    }

    // MARK: - AC1: CommitSkill Registration & PromptTemplate Git Analysis

    /// AC1 [P0]: BuiltInSkills.commit has correct name.
    func testCommitSkill_HasCorrectName() {
        // Given: BuiltInSkills.commit
        // Then: name is "commit"
        XCTAssertEqual(commitSkill.name, "commit",
                       "BuiltInSkills.commit should have name 'commit'")
    }

    /// AC1 [P0]: BuiltInSkills.commit has correct aliases including "ci".
    func testCommitSkill_HasCorrectAliases() {
        // Given: BuiltInSkills.commit
        // Then: aliases contains "ci"
        XCTAssertTrue(commitSkill.aliases.contains("ci"),
                      "BuiltInSkills.commit should have alias 'ci'")
    }

    /// AC1 [P0]: BuiltInSkills.commit is user invocable.
    func testCommitSkill_IsUserInvocable() {
        // Given: BuiltInSkills.commit
        // Then: userInvocable is true
        XCTAssertTrue(commitSkill.userInvocable,
                      "BuiltInSkills.commit should be user invocable")
    }

    /// AC1 [P0]: BuiltInSkills.commit has correct tool restrictions.
    func testCommitSkill_HasCorrectToolRestrictions() {
        // Given: BuiltInSkills.commit
        // Then: toolRestrictions includes bash, read, glob, grep
        let restrictions = commitSkill.toolRestrictions
        XCTAssertNotNil(restrictions, "toolRestrictions should not be nil")
        XCTAssertTrue(restrictions?.contains(.bash) ?? false,
                      "Should include .bash for git command execution")
        XCTAssertTrue(restrictions?.contains(.read) ?? false,
                      "Should include .read for file reading")
        XCTAssertTrue(restrictions?.contains(.glob) ?? false,
                      "Should include .glob for file pattern matching")
        XCTAssertTrue(restrictions?.contains(.grep) ?? false,
                      "Should include .grep for content search")
        XCTAssertEqual(restrictions?.count, 4,
                       "Should have exactly 4 tool restrictions")
    }

    /// AC1 [P0]: promptTemplate contains `git status --short` instruction.
    func testAC1_PromptTemplate_ContainsGitStatusShort() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template must contain "git status --short" (not just "git status")
        XCTAssertTrue(template.contains("git status --short"),
                      "AC1 FAIL: promptTemplate must instruct to run 'git status --short' (not 'git status'). " +
                      "Current template does not contain this command.")
    }

    /// AC1 [P0]: promptTemplate contains `git diff --cached` instruction.
    func testAC1_PromptTemplate_ContainsGitDiffCached() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template must contain "git diff --cached"
        XCTAssertTrue(template.contains("git diff --cached"),
                      "AC1 FAIL: promptTemplate must instruct to run 'git diff --cached' to check staged changes")
    }

    /// AC1 [P0]: promptTemplate contains `git diff` instruction (for unstaged changes).
    func testAC1_PromptTemplate_ContainsGitDiffForUnstaged() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template must contain "git diff" for checking unstaged changes
        // Note: it should contain "git diff" separately from "git diff --cached"
        // since both are needed
        XCTAssertTrue(template.contains("git diff"),
                      "AC1 FAIL: promptTemplate must instruct to run 'git diff' for unstaged changes")
    }

    /// AC1 [P1]: promptTemplate uses `git status --short` NOT plain `git status`.
    func testAC1_PromptTemplate_UsesShortFormat() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template should contain "--short" flag for concise output
        // The template should NOT instruct plain "git status" (without --short)
        // as a primary analysis step
        XCTAssertTrue(template.contains("--short"),
                      "AC1 FAIL: promptTemplate should use 'git status --short' for concise output format, " +
                      "not plain 'git status'")
    }

    // MARK: - AC2: No Staged Changes But Has Unstaged Changes

    /// AC2 [P0]: promptTemplate contains guidance for no staged but has unstaged changes.
    /// The template must explicitly suggest `git add` when staged changes are empty
    /// but unstaged changes exist, per the story's acceptance criteria.
    func testAC2_PromptTemplate_ContainsNoStagedHasUnstagedGuidance() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template must explicitly mention "git add" to inform the user
        // to stage their changes before committing
        XCTAssertTrue(template.contains("git add"),
                      "AC2 FAIL: promptTemplate must contain 'git add' instruction for the scenario " +
                      "where there are no staged changes but there are unstaged changes. " +
                      "Should instruct to suggest 'git add' for unstaged files.")
    }

    /// AC2 [P0]: promptTemplate explicitly mentions handling empty staged diff.
    func testAC2_PromptTemplate_MentionsEmptyStagedDiff() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template should have logic for when git diff --cached is empty
        // This could be phrased as "nothing is staged", "no staged changes", etc.
        let hasEmptyStagedLogic =
            template.localizedCaseInsensitiveContains("nothing is staged") ||
            template.localizedCaseInsensitiveContains("no staged changes") ||
            template.localizedCaseInsensitiveContains("nothing staged") ||
            template.localizedCaseInsensitiveContains("not staged") ||
            template.localizedCaseInsensitiveContains("empty") && template.contains("cached")
        XCTAssertTrue(hasEmptyStagedLogic,
                      "AC2 FAIL: promptTemplate must include explicit handling when " +
                      "'git diff --cached' is empty (no staged changes)")
    }

    /// AC2 [P1]: promptTemplate instructs to list unstaged files specifically.
    func testAC2_PromptTemplate_InstructsToListUnstagedFiles() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: when no staged changes exist, template should instruct to
        // list or show the specific unstaged files
        let hasUnstagedFileListing =
            template.localizedCaseInsensitiveContains("unstaged") ||
            template.localizedCaseInsensitiveContains("list") && template.contains("file") ||
            template.localizedCaseInsensitiveContains("show") && template.contains("unstaged")
        XCTAssertTrue(hasUnstagedFileListing,
                      "AC2 FAIL: promptTemplate should instruct to list specific unstaged files " +
                      "when there are no staged changes")
    }

    // MARK: - AC3: No Changes At All

    /// AC3 [P0]: promptTemplate contains handling for no changes at all.
    /// When both git diff --cached and git diff are empty, the template must
    /// explicitly instruct the agent to inform the user. Per the story AC:
    /// "Agent outputs 'no staged changes, please git add first' and suggests specific files"
    func testAC3_PromptTemplate_ContainsNoChangesHandling() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template must explicitly handle the scenario where both
        // git diff --cached AND git diff are empty.
        // The template should mention "no changes" or "nothing to commit"
        // as a distinct step/condition, not just as a passing mention.
        let hasExplicitNoChangesHandling =
            template.localizedCaseInsensitiveContains("no changes") ||
            template.localizedCaseInsensitiveContains("nothing to commit") ||
            template.localizedCaseInsensitiveContains("no need to commit") ||
            template.localizedCaseInsensitiveContains("nothing to commit")
        XCTAssertTrue(hasExplicitNoChangesHandling,
                      "AC3 FAIL: promptTemplate must explicitly handle the scenario where " +
                      "both 'git diff --cached' and 'git diff' are empty (no changes at all). " +
                      "Should include a step for this specific condition.")
    }

    /// AC3 [P1]: promptTemplate suggests specific actions when no changes exist.
    func testAC3_PromptTemplate_SuggestsActionWhenNoChanges() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: when there are no changes, template should suggest
        // what to do (e.g., suggest files, suggest creating changes)
        let hasSuggestion =
            template.localizedCaseInsensitiveContains("suggest") ||
            template.localizedCaseInsensitiveContains("create") ||
            template.localizedCaseInsensitiveContains("make changes") ||
            template.localizedCaseInsensitiveContains("nothing to commit")
        XCTAssertTrue(hasSuggestion,
                      "AC3 FAIL: promptTemplate should suggest specific actions " +
                      "when there are no changes to commit")
    }

    // MARK: - AC4: Has Staged Changes Generates Commit Message

    /// AC4 [P0]: promptTemplate requires imperative mood in commit messages.
    func testAC4_PromptTemplate_RequiresImperativeMood() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template must instruct to use imperative mood
        let hasImperative =
            template.localizedCaseInsensitiveContains("imperative")
        XCTAssertTrue(hasImperative,
                      "AC4 FAIL: promptTemplate must instruct to use imperative mood " +
                      "(e.g., 'Add feature' not 'Added feature')")
    }

    /// AC4 [P0]: promptTemplate enforces 72 character limit on commit title.
    func testAC4_PromptTemplate_Enforces72CharLimit() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template must mention 72 character limit
        let has72CharLimit =
            template.contains("72")
        XCTAssertTrue(has72CharLimit,
                      "AC4 FAIL: promptTemplate must enforce a 72 character limit on commit title")
    }

    /// AC4 [P0]: promptTemplate explicitly says NOT to execute git commit.
    /// Per story dev notes: "Do NOT actually execute git commit, only output suggested commit message"
    func testAC4_PromptTemplate_DoesNotExecuteGitCommit() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template must explicitly instruct NOT to run git commit.
        // The template should state something like "do not execute git commit"
        // or "only output the suggested commit message"
        let hasNoCommitInstruction =
            (template.localizedCaseInsensitiveContains("do not") ||
             template.localizedCaseInsensitiveContains("don't")) &&
            template.localizedCaseInsensitiveContains("commit") &&
            !template.contains("Create the commit")
        XCTAssertTrue(hasNoCommitInstruction,
                      "AC4 FAIL: promptTemplate must explicitly instruct NOT to execute 'git commit'. " +
                      "It should only output a suggested commit message, never actually commit.")
    }

    /// AC4 [P0]: promptTemplate does NOT contain "Create the commit" instruction.
    func testAC4_PromptTemplate_DoesNotSayCreateTheCommit() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template should NOT instruct to actually create the commit
        // The old template had "4. Create the commit" which must be removed
        let hasCreateCommitStep =
            template.contains("Create the commit") ||
            template.contains("create the commit")
        XCTAssertFalse(hasCreateCommitStep,
                       "AC4 FAIL: promptTemplate should NOT contain 'Create the commit' instruction. " +
                       "The skill should only suggest a commit message, not execute git commit.")
    }

    /// AC4 [P1]: promptTemplate supports multi-paragraph commit message format.
    func testAC4_PromptTemplate_SupportsMultiParagraphFormat() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template should mention multi-paragraph format
        // (title + blank line + body)
        let hasMultiParagraph =
            template.localizedCaseInsensitiveContains("body") ||
            template.localizedCaseInsensitiveContains("paragraph") ||
            template.localizedCaseInsensitiveContains("first line") ||
            template.localizedCaseInsensitiveContains("title") && template.localizedCaseInsensitiveContains("description") ||
            template.localizedCaseInsensitiveContains("summary") && template.localizedCaseInsensitiveContains("detail")
        XCTAssertTrue(hasMultiParagraph,
                      "AC4 FAIL: promptTemplate should support multi-paragraph commit message format " +
                      "(title + blank line + body)")
    }

    /// AC4 [P0]: promptTemplate is overridable via registry.replace().
    func testAC4_PromptTemplate_OverridableViaRegistryReplace() {
        // Given: a fresh registry and a custom promptTemplate
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.commit)

        let customTemplate = "Custom commit template: analyze changes and suggest message."
        let customSkill = Skill(
            name: "commit",
            promptTemplate: customTemplate
        )

        // When: replacing the commit skill with a custom promptTemplate
        registry.replace(customSkill)

        // Then: the registry returns the custom promptTemplate
        let found = registry.find("commit")
        XCTAssertNotNil(found, "commit skill should still be registered")
        XCTAssertEqual(found?.promptTemplate, customTemplate,
                       "AC4 FAIL: registry.replace() should allow overriding commit skill's promptTemplate")
    }

    /// AC4 [P0]: registry.replace() preserves ability to find commit by alias.
    func testAC4_RegistryReplace_PreservesAliasLookup() {
        // Given: a registry with the commit skill registered
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.commit)

        // When: replacing with a custom skill that also has alias "ci"
        let customSkill = Skill(
            name: "commit",
            aliases: ["ci"],
            promptTemplate: "Custom template"
        )
        registry.replace(customSkill)

        // Then: alias "ci" still resolves
        let foundByAlias = registry.find("ci")
        XCTAssertNotNil(foundByAlias, "AC4: alias 'ci' should still resolve after replace")
        XCTAssertEqual(foundByAlias?.promptTemplate, "Custom template")
    }

    // MARK: - SkillRegistry Integration

    /// AC1 [P1]: BuiltInSkills.commit can be registered and found in SkillRegistry.
    func testCommitSkill_CanBeRegisteredAndFound() {
        // Given: a fresh registry
        let registry = SkillRegistry()

        // When: registering BuiltInSkills.commit
        registry.register(BuiltInSkills.commit)

        // Then: find by name returns the skill
        let found = registry.find("commit")
        XCTAssertNotNil(found, "commit skill should be findable after registration")
        XCTAssertEqual(found?.name, "commit")
    }

    /// AC1 [P1]: BuiltInSkills.commit can be found by alias "ci" in SkillRegistry.
    func testCommitSkill_CanBeFoundByAlias() {
        // Given: a registry with commit skill registered
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.commit)

        // Then: find by alias "ci" returns the skill
        let found = registry.find("ci")
        XCTAssertNotNil(found, "commit skill should be findable by alias 'ci'")
        XCTAssertEqual(found?.name, "commit")
    }

    /// AC1 [P1]: BuiltInSkills.commit isAvailable defaults to true.
    func testCommitSkill_IsAvailableByDefault() {
        // Given: BuiltInSkills.commit
        // Then: isAvailable returns true (no extra environment check)
        XCTAssertTrue(commitSkill.isAvailable(),
                      "BuiltInSkills.commit should be available by default")
    }

    /// AC1 [P1]: BuiltInSkills.commit description is non-empty and meaningful.
    func testCommitSkill_HasNonEmptyDescription() {
        // Given: BuiltInSkills.commit
        // Then: description is non-empty
        XCTAssertFalse(commitSkill.description.isEmpty,
                       "commit skill should have a non-empty description")
    }

    // MARK: - Edge Cases

    /// [P1]: BuiltInSkills.commit returns a new instance each time (value type).
    func testCommitSkill_ReturnsNewInstance() {
        // Given: two accesses to BuiltInSkills.commit
        let skill1 = BuiltInSkills.commit
        let skill2 = BuiltInSkills.commit

        // Then: they are independent (value type semantics)
        XCTAssertEqual(skill1.name, skill2.name)
        XCTAssertEqual(skill1.promptTemplate, skill2.promptTemplate)
        // Modify one should not affect the other (struct value type)
        // This is inherently guaranteed by Swift structs
    }

    /// [P2]: promptTemplate does not instruct to push to remote.
    func testPromptTemplate_DoesNotInstructPushByDefault() {
        // Given: BuiltInSkills.commit promptTemplate
        let template = commitSkill.promptTemplate

        // Then: template should either not mention push, or explicitly
        // say not to push unless asked
        let mentionsPush = template.localizedCaseInsensitiveContains("push")
        if mentionsPush {
            // If push is mentioned, it must be qualified with "unless explicitly asked"
            let hasExplicitConsent =
                template.localizedCaseInsensitiveContains("unless") &&
                template.localizedCaseInsensitiveContains("asked") ||
                template.localizedCaseInsensitiveContains("explicitly") &&
                template.localizedCaseInsensitiveContains("asked")
            XCTAssertTrue(hasExplicitConsent,
                          "If push is mentioned, it must be qualified with explicit user consent")
        }
        // If push is not mentioned at all, that's also acceptable
    }
}

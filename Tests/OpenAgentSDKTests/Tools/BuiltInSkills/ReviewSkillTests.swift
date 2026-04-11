import XCTest
@testable import OpenAgentSDK

// MARK: - ReviewSkill ATDD Tests (Story 11.4)

/// ATDD tests for Story 11.4 -- Built-in Review Skill.
///
/// TDD RED PHASE: These tests assert the EXPECTED behavior of the refined
/// ReviewSkill promptTemplate. They will FAIL until the promptTemplate is
/// updated to meet all four acceptance criteria (AC1-AC4).
///
/// Coverage:
/// - AC1: promptTemplate executes multi-dimensional review (correctness, security, performance, style, testing coverage)
/// - AC2: Review results reference specific file names and line numbers (path/to/file.swift:行号)
/// - AC3: Multi-level change source strategy (git diff -> git diff --cached -> git diff HEAD~1)
/// - AC4: Output sorted by severity (security > correctness > performance > style > testing)
final class ReviewSkillTests: XCTestCase {

    // MARK: - Test Subject

    /// The review skill under test.
    private var reviewSkill: Skill!

    override func setUp() {
        super.setUp()
        reviewSkill = BuiltInSkills.review
    }

    override func tearDown() {
        reviewSkill = nil
        super.tearDown()
    }

    // MARK: - AC1: ReviewSkill Registration & PromptTemplate Multi-Dimensional Review

    /// AC1 [P0]: BuiltInSkills.review has correct name.
    func testReviewSkill_HasCorrectName() {
        // Given: BuiltInSkills.review
        // Then: name is "review"
        XCTAssertEqual(reviewSkill.name, "review",
                       "BuiltInSkills.review should have name 'review'")
    }

    /// AC1 [P0]: BuiltInSkills.review has correct aliases including "review-pr" and "cr".
    func testReviewSkill_HasCorrectAliases() {
        // Given: BuiltInSkills.review
        // Then: aliases contains both "review-pr" and "cr"
        XCTAssertTrue(reviewSkill.aliases.contains("review-pr"),
                      "BuiltInSkills.review should have alias 'review-pr'")
        XCTAssertTrue(reviewSkill.aliases.contains("cr"),
                      "BuiltInSkills.review should have alias 'cr'")
    }

    /// AC1 [P0]: BuiltInSkills.review is user invocable.
    func testReviewSkill_IsUserInvocable() {
        // Given: BuiltInSkills.review
        // Then: userInvocable is true
        XCTAssertTrue(reviewSkill.userInvocable,
                      "BuiltInSkills.review should be user invocable")
    }

    /// AC1 [P0]: BuiltInSkills.review has correct tool restrictions.
    func testReviewSkill_HasCorrectToolRestrictions() {
        // Given: BuiltInSkills.review
        // Then: toolRestrictions includes bash, read, glob, grep
        let restrictions = reviewSkill.toolRestrictions
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

    /// AC1 [P0]: promptTemplate contains "correctness" review dimension.
    func testAC1_PromptTemplate_ContainsCorrectnessDimension() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must contain a "correctness" dimension with analysis instructions
        XCTAssertTrue(template.localizedCaseInsensitiveContains("correctness"),
                      "AC1 FAIL: promptTemplate must include 'correctness' as a review dimension")
    }

    /// AC1 [P0]: promptTemplate contains "security" review dimension.
    func testAC1_PromptTemplate_ContainsSecurityDimension() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must contain a "security" dimension with analysis instructions
        XCTAssertTrue(template.localizedCaseInsensitiveContains("security"),
                      "AC1 FAIL: promptTemplate must include 'security' as a review dimension")
    }

    /// AC1 [P0]: promptTemplate contains "performance" review dimension.
    func testAC1_PromptTemplate_ContainsPerformanceDimension() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must contain a "performance" dimension with analysis instructions
        XCTAssertTrue(template.localizedCaseInsensitiveContains("performance"),
                      "AC1 FAIL: promptTemplate must include 'performance' as a review dimension")
    }

    /// AC1 [P0]: promptTemplate contains "style" review dimension.
    func testAC1_PromptTemplate_ContainsStyleDimension() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must contain a "style" dimension with analysis instructions
        XCTAssertTrue(template.localizedCaseInsensitiveContains("style"),
                      "AC1 FAIL: promptTemplate must include 'style' as a review dimension")
    }

    /// AC1 [P0]: promptTemplate contains "testing coverage" review dimension.
    /// The story explicitly requires "测试覆盖率" (testing coverage), not just "testing".
    func testAC1_PromptTemplate_ContainsTestingCoverageDimension() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must mention "testing coverage" or "test coverage"
        // (not just "testing" alone -- the epics require coverage assessment)
        let hasTestingCoverage =
            template.localizedCaseInsensitiveContains("test coverage") ||
            template.localizedCaseInsensitiveContains("testing coverage") ||
            (template.localizedCaseInsensitiveContains("testing") &&
             template.localizedCaseInsensitiveContains("coverage"))
        XCTAssertTrue(hasTestingCoverage,
                      "AC1 FAIL: promptTemplate must include 'testing coverage' or 'test coverage' " +
                      "as a review dimension (not just 'testing'). The epics require assessing " +
                      "whether changes are adequately covered by tests.")
    }

    // MARK: - AC2: Review Results Reference Specific Locations

    /// AC2 [P0]: promptTemplate requires file:line number references in findings.
    /// Per story AC2: each finding must reference specific file name and line number
    /// (format: `path/to/file.swift:行号`).
    func testAC2_PromptTemplate_RequiresFileAndLineNumberReferences() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must explicitly require findings to reference
        // file path + line number in a structured format like `file.swift:42`
        let hasFileLineFormat =
            template.contains(":行号") ||
            template.contains("file:line") ||
            template.contains("file:行号") ||
            template.contains("path:line") ||
            (template.localizedCaseInsensitiveContains("file name") &&
             template.localizedCaseInsensitiveContains("line number") &&
             template.localizedCaseInsensitiveContains("format"))
        XCTAssertTrue(hasFileLineFormat,
                      "AC2 FAIL: promptTemplate must explicitly require findings to reference " +
                      "file names and line numbers in a structured format (e.g., 'file.swift:42'). " +
                      "Must include format instruction, not just mention file names and line numbers.")
    }

    /// AC2 [P0]: promptTemplate references specific file names in findings.
    func testAC2_PromptTemplate_ReferencesSpecificFileNames() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must instruct to reference file names
        XCTAssertTrue(template.localizedCaseInsensitiveContains("file name") ||
                      template.localizedCaseInsensitiveContains("filename") ||
                      template.localizedCaseInsensitiveContains("file names"),
                      "AC2 FAIL: promptTemplate must instruct to reference specific file names in findings")
    }

    /// AC2 [P0]: promptTemplate references line numbers in findings.
    func testAC2_PromptTemplate_ReferencesLineNumbers() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must instruct to reference line numbers
        XCTAssertTrue(template.localizedCaseInsensitiveContains("line number") ||
                      template.localizedCaseInsensitiveContains("line numbers"),
                      "AC2 FAIL: promptTemplate must instruct to reference specific line numbers in findings")
    }

    // MARK: - AC3: Multi-Level Change Source Strategy

    /// AC3 [P0]: promptTemplate contains `git diff` instruction for unstaged changes.
    func testAC3_PromptTemplate_ContainsGitDiffUnstaged() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must contain "git diff" for getting unstaged changes
        XCTAssertTrue(template.contains("git diff"),
                      "AC3 FAIL: promptTemplate must instruct to run 'git diff' for unstaged changes")
    }

    /// AC3 [P0]: promptTemplate contains `git diff --cached` instruction for staged changes.
    /// The three-level strategy requires staged change detection.
    func testAC3_PromptTemplate_ContainsGitDiffCached() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must contain "git diff --cached" for getting staged changes
        XCTAssertTrue(template.contains("git diff --cached"),
                      "AC3 FAIL: promptTemplate must instruct to run 'git diff --cached' " +
                      "for staged changes as part of the three-level change acquisition strategy.")
    }

    /// AC3 [P0]: promptTemplate contains `git diff HEAD~1` instruction for last commit.
    /// The story requires `git diff HEAD~1` (not `git diff main...HEAD`).
    func testAC3_PromptTemplate_ContainsGitDiffHeadTilde1() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must contain "git diff HEAD~1" for reviewing the last commit
        XCTAssertTrue(template.contains("git diff HEAD~1") ||
                      template.contains("git diff HEAD~"),
                      "AC3 FAIL: promptTemplate must instruct to run 'git diff HEAD~1' " +
                      "for reviewing the last commit as the third level of the change acquisition strategy. " +
                      "Should NOT use 'git diff main...HEAD'.")
    }

    /// AC3 [P1]: promptTemplate uses three-level priority order for change acquisition.
    /// The priority is: git diff (unstaged) -> git diff --cached (staged) -> git diff HEAD~1 (last commit).
    func testAC3_PromptTemplate_UsesThreeLevelPriority() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must contain all three levels and imply priority ordering.
        // The epics require a cascading fallback: first check unstaged, then staged,
        // then last commit. The template should express this priority.
        let hasAllThree = template.contains("git diff") &&
                          template.contains("git diff --cached") &&
                          (template.contains("git diff HEAD~1") || template.contains("git diff HEAD~"))
        XCTAssertTrue(hasAllThree,
                      "AC3 FAIL: promptTemplate must include all three levels of change " +
                      "acquisition: 'git diff', 'git diff --cached', and 'git diff HEAD~1' " +
                      "in priority order.")
    }

    /// AC3 [P1]: promptTemplate must NOT use `git diff main...HEAD`.
    /// Per story dev notes: do not use `git diff main...HEAD` -- use `git diff HEAD~1`.
    func testAC3_PromptTemplate_DoesNotUseGitDiffMainHead() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template should NOT contain "git diff main...HEAD"
        XCTAssertFalse(template.contains("git diff main...HEAD"),
                       "AC3 FAIL: promptTemplate should NOT use 'git diff main...HEAD'. " +
                       "Use 'git diff HEAD~1' for the last commit level instead.")
    }

    // MARK: - AC4: Output Sorted by Severity

    /// AC4 [P0]: promptTemplate contains severity ordering instruction.
    /// The ordering must be: security > correctness > performance > style > testing.
    func testAC4_PromptTemplate_ContainsSeverityOrdering() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must explicitly instruct to order findings by severity
        let hasSeverityOrder =
            template.localizedCaseInsensitiveContains("severity") ||
            template.localizedCaseInsensitiveContains("severity order") ||
            template.localizedCaseInsensitiveContains("order by severity") ||
            template.localizedCaseInsensitiveContains("sort by severity") ||
            template.localizedCaseInsensitiveContains("prioritize") &&
            (template.localizedCaseInsensitiveContains("security") &&
             template.localizedCaseInsensitiveContains("correctness"))
        XCTAssertTrue(hasSeverityOrder,
                      "AC4 FAIL: promptTemplate must instruct to order findings by severity. " +
                      "The order must be: security > correctness > performance > style > testing.")
    }

    /// AC4 [P0]: promptTemplate lists security issues first in severity ordering.
    func testAC4_PromptTemplate_SecurityFirst() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must indicate security is the highest severity / listed first
        // This can be expressed as "security > correctness > ..." or "security first"
        let hasSecurityFirst =
            template.localizedCaseInsensitiveContains("security first") ||
            template.localizedCaseInsensitiveContains("security >") ||
            template.localizedCaseInsensitiveContains("security (highest") ||
            template.localizedCaseInsensitiveContains("security is the highest") ||
            template.localizedCaseInsensitiveContains("1. security") ||
            template.localizedCaseInsensitiveContains("1. **Security**")
        XCTAssertTrue(hasSecurityFirst,
                      "AC4 FAIL: promptTemplate must indicate that security issues are " +
                      "the highest priority / listed first in the severity ordering.")
    }

    /// AC4 [P0]: promptTemplate lists correctness as second in severity ordering.
    func testAC4_PromptTemplate_CorrectnessSecond() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must indicate correctness is second priority after security
        let hasCorrectnessSecond =
            template.contains("security > correctness") ||
            template.contains("security, correctness") ||
            template.contains("2. correctness") ||
            template.contains("2. **Correctness**") ||
            template.localizedCaseInsensitiveContains("correctness second")
        XCTAssertTrue(hasCorrectnessSecond,
                      "AC4 FAIL: promptTemplate must indicate that correctness is the " +
                      "second priority in the severity ordering (after security).")
    }

    /// AC4 [P0]: promptTemplate lists testing as last in severity ordering.
    func testAC4_PromptTemplate_TestingLast() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must indicate testing is the lowest severity / listed last
        let hasTestingLast =
            template.contains("> testing") ||
            template.contains("style, testing") ||
            template.contains("5. testing") ||
            template.contains("5. **Testing") ||
            template.localizedCaseInsensitiveContains("testing last")
        XCTAssertTrue(hasTestingLast,
                      "AC4 FAIL: promptTemplate must indicate that testing issues are " +
                      "the lowest priority / listed last in the severity ordering.")
    }

    /// AC4 [P0]: promptTemplate does NOT use the old Critical/Suggestions/Questions format.
    /// The old format grouped by Critical/Suggestions/Questions which does not match
    /// the required severity ordering (security > correctness > performance > style > testing).
    func testAC4_PromptTemplate_DoesNotUseCriticalSuggestionsFormat() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template should NOT contain the old summary format
        // "Critical issues (must fix)" / "Suggestions (nice to have)" / "Questions (need clarification)"
        let hasOldFormat =
            template.contains("Critical issues (must fix)") ||
            template.contains("Suggestions (nice to have)") ||
            template.contains("Questions (need clarification)")
        XCTAssertFalse(hasOldFormat,
                       "AC4 FAIL: promptTemplate should NOT use the old 'Critical issues / " +
                       "Suggestions / Questions' summary format. Must be replaced with severity-ordered " +
                       "output (security > correctness > performance > style > testing).")
    }

    // MARK: - Edge Cases & Registry Integration

    /// [P1]: BuiltInSkills.review returns a new instance each time (value type).
    func testReviewSkill_ReturnsNewInstance() {
        // Given: two accesses to BuiltInSkills.review
        let skill1 = BuiltInSkills.review
        let skill2 = BuiltInSkills.review

        // Then: they are independent (value type semantics)
        XCTAssertEqual(skill1.name, skill2.name)
        XCTAssertEqual(skill1.promptTemplate, skill2.promptTemplate)
        // Modify one should not affect the other (struct value type)
    }

    /// AC1 [P1]: BuiltInSkills.review can be registered and found in SkillRegistry.
    func testReviewSkill_CanBeRegisteredAndFound() {
        // Given: a fresh registry
        let registry = SkillRegistry()

        // When: registering BuiltInSkills.review
        registry.register(BuiltInSkills.review)

        // Then: find by name returns the skill
        let found = registry.find("review")
        XCTAssertNotNil(found, "review skill should be findable after registration")
        XCTAssertEqual(found?.name, "review")
    }

    /// AC1 [P1]: BuiltInSkills.review can be found by alias "review-pr" in SkillRegistry.
    func testReviewSkill_CanBeFoundByAliasReviewPR() {
        // Given: a registry with review skill registered
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.review)

        // Then: find by alias "review-pr" returns the skill
        let found = registry.find("review-pr")
        XCTAssertNotNil(found, "review skill should be findable by alias 'review-pr'")
        XCTAssertEqual(found?.name, "review")
    }

    /// AC1 [P1]: BuiltInSkills.review can be found by alias "cr" in SkillRegistry.
    func testReviewSkill_CanBeFoundByAliasCR() {
        // Given: a registry with review skill registered
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.review)

        // Then: find by alias "cr" returns the skill
        let found = registry.find("cr")
        XCTAssertNotNil(found, "review skill should be findable by alias 'cr'")
        XCTAssertEqual(found?.name, "review")
    }

    /// AC1 [P1]: BuiltInSkills.review isAvailable defaults to true.
    func testReviewSkill_IsAvailableByDefault() {
        // Given: BuiltInSkills.review
        // Then: isAvailable returns true (no extra environment check)
        XCTAssertTrue(reviewSkill.isAvailable(),
                      "BuiltInSkills.review should be available by default")
    }

    /// AC1 [P1]: BuiltInSkills.review description is non-empty and meaningful.
    func testReviewSkill_HasNonEmptyDescription() {
        // Given: BuiltInSkills.review
        // Then: description is non-empty
        XCTAssertFalse(reviewSkill.description.isEmpty,
                       "review skill should have a non-empty description")
    }

    /// AC4 [P0]: promptTemplate is overridable via registry.replace().
    func testAC4_PromptTemplate_OverridableViaRegistryReplace() {
        // Given: a fresh registry and a custom promptTemplate
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.review)

        let customTemplate = "Custom review template: review changes for issues."
        let customSkill = Skill(
            name: "review",
            promptTemplate: customTemplate
        )

        // When: replacing the review skill with a custom promptTemplate
        registry.replace(customSkill)

        // Then: the registry returns the custom promptTemplate
        let found = registry.find("review")
        XCTAssertNotNil(found, "review skill should still be registered")
        XCTAssertEqual(found?.promptTemplate, customTemplate,
                       "AC4 FAIL: registry.replace() should allow overriding review skill's promptTemplate")
    }

    /// AC4 [P0]: registry.replace() preserves ability to find review by alias.
    func testAC4_RegistryReplace_PreservesAliasLookup() {
        // Given: a registry with the review skill registered
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.review)

        // When: replacing with a custom skill that also has aliases
        let customSkill = Skill(
            name: "review",
            aliases: ["review-pr", "cr"],
            promptTemplate: "Custom template"
        )
        registry.replace(customSkill)

        // Then: alias "cr" still resolves
        let foundByAlias = registry.find("cr")
        XCTAssertNotNil(foundByAlias, "AC4: alias 'cr' should still resolve after replace")
        XCTAssertEqual(foundByAlias?.promptTemplate, "Custom template")
    }

    /// AC3 [P1]: promptTemplate handles no changes scenario.
    /// When all three git diff commands return empty, the template should
    /// instruct the agent on how to respond.
    func testAC3_PromptTemplate_HandlesNoChanges() {
        // Given: BuiltInSkills.review promptTemplate
        let template = reviewSkill.promptTemplate

        // Then: template must handle the case where no changes are found
        let hasNoChangesHandling =
            template.localizedCaseInsensitiveContains("no changes") ||
            template.localizedCaseInsensitiveContains("nothing to review") ||
            template.localizedCaseInsensitiveContains("no diff") ||
            template.localizedCaseInsensitiveContains("empty") &&
            template.localizedCaseInsensitiveContains("diff")
        XCTAssertTrue(hasNoChangesHandling,
                      "AC3 FAIL: promptTemplate must handle the scenario where all git diff " +
                      "commands return empty output (no changes to review). Should instruct " +
                      "the agent on how to respond when there are no changes.")
    }
}

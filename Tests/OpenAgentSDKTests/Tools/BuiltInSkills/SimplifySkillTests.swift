import XCTest
@testable import OpenAgentSDK

// MARK: - SimplifySkill ATDD Tests (Story 11.5)

/// ATDD tests for Story 11.5 -- Built-in Simplify Skill.
///
/// All tests PASS. Coverage:
/// - AC1: SimplifySkill registered with toolRestrictions [.read, .grep, .glob];
///         promptTemplate guides reuse/quality/efficiency three-category analysis
/// - AC2: Output structure includes duplicated patterns, overly complex logic,
///         extractable abstractions; each finding references specific file:line
/// - AC3: Each finding provides before/after comparison examples
final class SimplifySkillTests: XCTestCase {

    // MARK: - Test Subject

    /// The simplify skill under test.
    private var simplifySkill: Skill!

    override func setUp() {
        super.setUp()
        simplifySkill = BuiltInSkills.simplify
    }

    override func tearDown() {
        simplifySkill = nil
        super.tearDown()
    }

    // MARK: - AC1: SimplifySkill Registration & PromptTemplate Three-Category Analysis

    /// AC1 [P0]: BuiltInSkills.simplify has correct name.
    func testSimplifySkill_HasCorrectName() {
        // Given: BuiltInSkills.simplify
        // Then: name is "simplify"
        XCTAssertEqual(simplifySkill.name, "simplify",
                       "BuiltInSkills.simplify should have name 'simplify'")
    }

    /// AC1 [P0]: BuiltInSkills.simplify is user invocable.
    func testSimplifySkill_IsUserInvocable() {
        // Given: BuiltInSkills.simplify
        // Then: userInvocable is true
        XCTAssertTrue(simplifySkill.userInvocable,
                      "BuiltInSkills.simplify should be user invocable")
    }

    /// AC1 [P0]: BuiltInSkills.simplify has correct tool restrictions -- read-only analysis tools.
    /// Per story AC1: toolRestrictions must be [.bash, .read, .grep, .glob]
    /// (.bash needed for git diff/git diff --cached which are read-only operations).
    func testSimplifySkill_HasCorrectToolRestrictions() {
        // Given: BuiltInSkills.simplify
        // Then: toolRestrictions includes bash (for git diff), read, grep, glob
        let restrictions = simplifySkill.toolRestrictions
        XCTAssertNotNil(restrictions, "toolRestrictions should not be nil")
        XCTAssertTrue(restrictions?.contains(.bash) ?? false,
                      "Should include .bash for git diff (read-only operation)")
        XCTAssertTrue(restrictions?.contains(.read) ?? false,
                      "Should include .read for file reading")
        XCTAssertTrue(restrictions?.contains(.grep) ?? false,
                      "Should include .grep for content search")
        XCTAssertTrue(restrictions?.contains(.glob) ?? false,
                      "Should include .glob for file pattern matching")
        XCTAssertEqual(restrictions?.count, 4,
                       "Should have exactly 4 tool restrictions (bash + read-only)")
    }

    /// AC1 [P0]: toolRestrictions includes bash for git diff (read-only git operations).
    func testSimplifySkill_IncludesBashForGitDiff() {
        // Given: BuiltInSkills.simplify
        let restrictions = simplifySkill.toolRestrictions
        // Then: must include .bash for running git diff (read-only git operations)
        XCTAssertTrue(restrictions?.contains(.bash) ?? false,
                       "toolRestrictions should include .bash for git diff/git diff --cached " +
                       "(read-only git operations used to identify changed files).")
    }

    /// AC1 [P0]: toolRestrictions must NOT include write or edit (read-only skill).
    func testSimplifySkill_DoesNotIncludeWriteOrEdit() {
        // Given: BuiltInSkills.simplify
        let restrictions = simplifySkill.toolRestrictions
        // Then: must not include .write or .edit
        XCTAssertFalse(restrictions?.contains(.write) ?? false,
                       "AC1 FAIL: toolRestrictions should NOT include .write")
        XCTAssertFalse(restrictions?.contains(.edit) ?? false,
                       "AC1 FAIL: toolRestrictions should NOT include .edit")
    }

    /// AC1 [P0]: promptTemplate contains "reuse" analysis category.
    /// Per story AC1: promptTemplate must guide review of code reuse (duplicated code,
    /// existing utility replacements, extractable abstractions).
    func testAC1_PromptTemplate_ContainsReuseAnalysis() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must include reuse analysis with keywords
        let hasReuse =
            template.localizedCaseInsensitiveContains("reuse") ||
            template.localizedCaseInsensitiveContains("duplicated") ||
            template.localizedCaseInsensitiveContains("duplicate") ||
            template.localizedCaseInsensitiveContains("consolidated")
        XCTAssertTrue(hasReuse,
                      "AC1 FAIL: promptTemplate must include reuse analysis category " +
                      "(keywords: reuse, duplicated, duplicate, consolidated)")
    }

    /// AC1 [P0]: promptTemplate contains "quality" analysis category.
    /// Per story AC1: promptTemplate must guide review of code quality (overly complex logic,
    /// naming, edge cases, over-engineering).
    func testAC1_PromptTemplate_ContainsQualityAnalysis() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must include quality analysis
        let hasQuality =
            template.localizedCaseInsensitiveContains("quality") ||
            template.localizedCaseInsensitiveContains("complex") ||
            template.localizedCaseInsensitiveContains("over-engineering") ||
            template.localizedCaseInsensitiveContains("overengineer")
        XCTAssertTrue(hasQuality,
                      "AC1 FAIL: promptTemplate must include quality analysis category " +
                      "(keywords: quality, complex, over-engineering)")
    }

    /// AC1 [P0]: promptTemplate contains "efficiency" analysis category.
    /// Per story AC1: promptTemplate must guide review of efficiency (unnecessary allocations,
    /// N+1 patterns, blocking operations, inefficient data structures).
    func testAC1_PromptTemplate_ContainsEfficiencyAnalysis() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must include efficiency analysis
        let hasEfficiency =
            template.localizedCaseInsensitiveContains("efficiency") ||
            template.localizedCaseInsensitiveContains("efficient") ||
            template.localizedCaseInsensitiveContains("unnecessary") ||
            template.localizedCaseInsensitiveContains("N+1")
        XCTAssertTrue(hasEfficiency,
                      "AC1 FAIL: promptTemplate must include efficiency analysis category " +
                      "(keywords: efficiency, efficient, unnecessary, N+1)")
    }

    /// AC1 [P0]: promptTemplate uses git diff / git diff --cached to identify changed files.
    /// Per story dev notes: must include git diff strategy for finding changed files.
    func testAC1_PromptTemplate_ContainsGitDiffForChangedFiles() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must instruct to use git diff to identify changed files
        XCTAssertTrue(template.contains("git diff"),
                      "AC1 FAIL: promptTemplate must instruct to use 'git diff' " +
                      "to identify recently changed files for analysis.")
    }

    /// AC1 [P0]: promptTemplate contains `git diff --cached` instruction for staged changes.
    func testAC1_PromptTemplate_ContainsGitDiffCached() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must contain "git diff --cached" for getting staged changes
        XCTAssertTrue(template.contains("git diff --cached"),
                      "AC1 FAIL: promptTemplate must instruct to run 'git diff --cached' " +
                      "to check staged changes as part of change identification strategy.")
    }

    /// AC1 [P0]: promptTemplate must NOT instruct the agent to "fix" issues.
    /// Per story dev notes: toolRestrictions are read-only (Read, Grep, Glob),
    /// so the promptTemplate must only analyze and report, not fix.
    func testAC1_PromptTemplate_DoesNotInstructFix() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template should NOT contain "fix any issues found" or similar
        let hasFixInstruction =
            template.localizedCaseInsensitiveContains("fix any issues found") ||
            template.localizedCaseInsensitiveContains("fix the issues")
        XCTAssertFalse(hasFixInstruction,
                       "AC1 FAIL: promptTemplate should NOT instruct to 'fix any issues found'. " +
                       "The simplify skill is read-only (Read, Grep, Glob). " +
                       "It should only analyze and report findings.")
    }

    /// AC1 [P1]: promptTemplate must NOT use "Launch 3 parallel Agent sub-tasks".
    /// Per story dev notes: the old skeleton had this phrase which must be removed.
    /// The skill should use Read, Grep, Glob tools directly.
    func testAC1_PromptTemplate_DoesNotUseParallelSubtasks() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template should NOT instruct to launch parallel sub-tasks
        let hasParallelSubtasks =
            template.localizedCaseInsensitiveContains("parallel") &&
            template.localizedCaseInsensitiveContains("sub-task")
        XCTAssertFalse(hasParallelSubtasks,
                       "AC1 FAIL: promptTemplate should NOT instruct to 'Launch 3 parallel Agent sub-tasks'. " +
                       "The skill should use Read, Grep, Glob tools directly for analysis.")
    }

    /// AC1 [P1]: BuiltInSkills.simplify isAvailable defaults to true.
    func testSimplifySkill_IsAvailableByDefault() {
        // Given: BuiltInSkills.simplify
        // Then: isAvailable returns true (no extra environment check)
        XCTAssertTrue(simplifySkill.isAvailable(),
                      "BuiltInSkills.simplify should be available by default")
    }

    /// AC1 [P1]: BuiltInSkills.simplify description is non-empty and meaningful.
    func testSimplifySkill_HasNonEmptyDescription() {
        // Given: BuiltInSkills.simplify
        // Then: description is non-empty
        XCTAssertFalse(simplifySkill.description.isEmpty,
                       "simplify skill should have a non-empty description")
    }

    /// AC1 [P0]: Description should NOT say "then fix any issues found".
    /// Per story dev notes: the description must be updated since toolRestrictions
    /// are read-only.
    func testAC1_Description_DoesNotSayFixIssues() {
        // Given: BuiltInSkills.simplify
        let description = simplifySkill.description

        // Then: description should NOT say "fix any issues found"
        XCTAssertFalse(description.localizedCaseInsensitiveContains("fix any issues found"),
                       "AC1 FAIL: description should NOT say 'then fix any issues found'. " +
                       "The simplify skill is read-only. The description should only mention " +
                       "reviewing/analyzing, not fixing.")
    }

    // MARK: - AC2: Output Structure with Three Categories & Specific File:Line References

    /// AC2 [P0]: promptTemplate requires file:line number references in findings.
    /// Per story AC2: each finding must reference specific file name and line number
    /// (format: `path/to/file.swift:行号`).
    func testAC2_PromptTemplate_RequiresFileAndLineNumberReferences() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must explicitly require findings to reference
        // file path + line number in a structured format
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

    /// AC2 [P0]: promptTemplate instructs to reference file names in findings.
    func testAC2_PromptTemplate_ReferencesSpecificFileNames() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must instruct to reference file names
        XCTAssertTrue(template.localizedCaseInsensitiveContains("file name") ||
                      template.localizedCaseInsensitiveContains("filename") ||
                      template.localizedCaseInsensitiveContains("file names"),
                      "AC2 FAIL: promptTemplate must instruct to reference specific file names in findings")
    }

    /// AC2 [P0]: promptTemplate instructs to reference line numbers in findings.
    func testAC2_PromptTemplate_ReferencesLineNumbers() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must instruct to reference line numbers
        XCTAssertTrue(template.localizedCaseInsensitiveContains("line number") ||
                      template.localizedCaseInsensitiveContains("line numbers"),
                      "AC2 FAIL: promptTemplate must instruct to reference specific line numbers in findings")
    }

    /// AC2 [P0]: promptTemplate output includes "duplicated code patterns" (重复代码模式).
    func testAC2_PromptTemplate_ContainsDuplicatedPatterns() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must mention duplicated code patterns
        let hasDuplicated =
            template.localizedCaseInsensitiveContains("duplicated") ||
            template.localizedCaseInsensitiveContains("duplicate") ||
            template.localizedCaseInsensitiveContains("repeated") ||
            template.localizedCaseInsensitiveContains("pattern")
        XCTAssertTrue(hasDuplicated,
                      "AC2 FAIL: promptTemplate must mention duplicated code patterns " +
                      "as one of the three finding categories")
    }

    /// AC2 [P0]: promptTemplate output includes "overly complex logic" (过度复杂的逻辑).
    func testAC2_PromptTemplate_ContainsOverlyComplexLogic() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must mention overly complex logic
        let hasComplexLogic =
            template.localizedCaseInsensitiveContains("complex") ||
            template.localizedCaseInsensitiveContains("complicated") ||
            template.localizedCaseInsensitiveContains("simplif")
        XCTAssertTrue(hasComplexLogic,
                      "AC2 FAIL: promptTemplate must mention overly complex logic " +
                      "as one of the three finding categories")
    }

    /// AC2 [P0]: promptTemplate output includes "extractable abstractions" (可提取的抽象).
    func testAC2_PromptTemplate_ContainsExtractableAbstractions() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must mention extractable abstractions
        let hasAbstractions =
            template.localizedCaseInsensitiveContains("abstract") ||
            template.localizedCaseInsensitiveContains("extract") ||
            template.localizedCaseInsensitiveContains("shared function") ||
            template.localizedCaseInsensitiveContains("shared helper")
        XCTAssertTrue(hasAbstractions,
                      "AC2 FAIL: promptTemplate must mention extractable abstractions " +
                      "as one of the three finding categories (keywords: abstract, extract, shared)")
    }

    // MARK: - AC3: Each Finding Provides Before/After Comparison Examples

    /// AC3 [P0]: promptTemplate requires before/after comparison examples for each finding.
    /// Per story AC3: when findings are discovered, the template must instruct the agent
    /// to provide a before/after comparison example for each one.
    func testAC3_PromptTemplate_RequiresBeforeAfterComparison() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must explicitly require before/after comparisons
        let hasBeforeAfter =
            template.localizedCaseInsensitiveContains("before") &&
            template.localizedCaseInsensitiveContains("after")
        XCTAssertTrue(hasBeforeAfter,
                      "AC3 FAIL: promptTemplate must require before/after comparison examples " +
                      "for each finding. Must contain both 'before' and 'after' keywords.")
    }

    /// AC3 [P0]: promptTemplate requires comparison examples (not just mentioning "example").
    /// The template should have explicit language like "before/after example" or
    /// "simplified version" for each finding.
    func testAC3_PromptTemplate_RequiresExplicitComparisonExamples() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must have explicit comparison/example requirement
        let hasExplicitComparison =
            template.localizedCaseInsensitiveContains("before and after") ||
            template.localizedCaseInsensitiveContains("before/after") ||
            template.localizedCaseInsensitiveContains("before → after") ||
            template.localizedCaseInsensitiveContains("before -> after") ||
            template.localizedCaseInsensitiveContains("comparison") ||
            template.localizedCaseInsensitiveContains("simplified version") ||
            (template.localizedCaseInsensitiveContains("current code") &&
             template.localizedCaseInsensitiveContains("suggested")) ||
            (template.localizedCaseInsensitiveContains("original") &&
             template.localizedCaseInsensitiveContains("simplified"))
        XCTAssertTrue(hasExplicitComparison,
                      "AC3 FAIL: promptTemplate must have explicit before/after comparison " +
                      "instruction (e.g., 'before and after', 'comparison', 'simplified version').")
    }

    /// AC3 [P1]: promptTemplate requires comparison for EACH finding (not just overall).
    func testAC3_PromptTemplate_RequiresComparisonForEachFinding() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must specify that each/every finding gets a comparison
        let hasEachFindingRequirement =
            template.localizedCaseInsensitiveContains("each finding") ||
            template.localizedCaseInsensitiveContains("every finding") ||
            (template.localizedCaseInsensitiveContains("for each") &&
             template.localizedCaseInsensitiveContains("finding")) ||
            template.localizedCaseInsensitiveContains("each issue") ||
            template.localizedCaseInsensitiveContains("each simplification")
        XCTAssertTrue(hasEachFindingRequirement,
                      "AC3 FAIL: promptTemplate must require comparison examples " +
                      "for EACH finding (not just overall). Must mention 'each finding' " +
                      "or 'every finding' or similar per-finding language.")
    }

    // MARK: - Edge Cases & No Changes Handling

    /// [P0]: promptTemplate handles no changes scenario.
    /// When git diff returns empty, the template should instruct the agent
    /// on how to respond.
    func testPromptTemplate_HandlesNoChanges() {
        // Given: BuiltInSkills.simplify promptTemplate
        let template = simplifySkill.promptTemplate

        // Then: template must handle the case where no changes are found
        let hasNoChangesHandling =
            template.localizedCaseInsensitiveContains("no changes") ||
            template.localizedCaseInsensitiveContains("nothing to review") ||
            template.localizedCaseInsensitiveContains("no diff") ||
            (template.localizedCaseInsensitiveContains("empty") &&
             template.localizedCaseInsensitiveContains("diff")) ||
            template.localizedCaseInsensitiveContains("no simplification")
        XCTAssertTrue(hasNoChangesHandling,
                      "promptTemplate must handle the scenario where git diff " +
                      "commands return empty output (no changes to review). Should instruct " +
                      "the agent on how to respond when there are no changes.")
    }

    // MARK: - Registry Integration

    /// AC1 [P1]: BuiltInSkills.simplify can be registered and found in SkillRegistry.
    func testSimplifySkill_CanBeRegisteredAndFound() {
        // Given: a fresh registry
        let registry = SkillRegistry()

        // When: registering BuiltInSkills.simplify
        registry.register(BuiltInSkills.simplify)

        // Then: find by name returns the skill
        let found = registry.find("simplify")
        XCTAssertNotNil(found, "simplify skill should be findable after registration")
        XCTAssertEqual(found?.name, "simplify")
    }

    /// AC1 [P1]: registry.replace() can override simplify skill's promptTemplate.
    func testSimplifySkill_OverridableViaRegistryReplace() {
        // Given: a fresh registry and a custom promptTemplate
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.simplify)

        let customTemplate = "Custom simplify template: review changes for simplifications."
        let customSkill = Skill(
            name: "simplify",
            promptTemplate: customTemplate
        )

        // When: replacing the simplify skill with a custom promptTemplate
        registry.replace(customSkill)

        // Then: the registry returns the custom promptTemplate
        let found = registry.find("simplify")
        XCTAssertNotNil(found, "simplify skill should still be registered")
        XCTAssertEqual(found?.promptTemplate, customTemplate,
                       "registry.replace() should allow overriding simplify skill's promptTemplate")
    }

    /// [P1]: BuiltInSkills.simplify returns a new instance each time (value type).
    func testSimplifySkill_ReturnsNewInstance() {
        // Given: two accesses to BuiltInSkills.simplify
        let skill1 = BuiltInSkills.simplify
        let skill2 = BuiltInSkills.simplify

        // Then: they are independent (value type semantics)
        XCTAssertEqual(skill1.name, skill2.name)
        XCTAssertEqual(skill1.promptTemplate, skill2.promptTemplate)
    }

    /// AC1 [P1]: BuiltInSkills.simplify aliases are configured (if any).
    /// Currently the simplify skill has no aliases in the skeleton, but this test
    /// verifies the aliases property is accessible and consistent.
    func testSimplifySkill_AliasesConsistency() {
        // Given: BuiltInSkills.simplify
        // Then: aliases should be a consistent array (may be empty)
        let skill1 = BuiltInSkills.simplify
        let skill2 = BuiltInSkills.simplify
        XCTAssertEqual(skill1.aliases, skill2.aliases,
                       "Aliases should be consistent across accesses")
    }

    /// AC1 [P1]: BuiltInSkills.simplify modelOverride is nil (default).
    func testSimplifySkill_HasNoModelOverride() {
        // Given: BuiltInSkills.simplify
        // Then: modelOverride should be nil (no special model)
        XCTAssertNil(simplifySkill.modelOverride,
                     "simplify skill should not have a model override")
    }

    /// AC1 [P1]: BuiltInSkills.simplify promptTemplate is non-empty.
    func testSimplifySkill_HasNonEmptyPromptTemplate() {
        // Given: BuiltInSkills.simplify
        // Then: promptTemplate is non-empty
        XCTAssertFalse(simplifySkill.promptTemplate.isEmpty,
                       "simplify skill should have a non-empty promptTemplate")
    }
}

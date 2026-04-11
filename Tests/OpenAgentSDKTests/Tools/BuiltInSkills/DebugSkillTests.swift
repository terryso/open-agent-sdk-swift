import XCTest
@testable import OpenAgentSDK

// MARK: - DebugSkill ATDD Tests (Story 11.6)

/// ATDD tests for Story 11.6 -- Built-in Debug Skill.
///
/// All tests PASS. Coverage:
/// - AC1: DebugSkill registered with toolRestrictions [.read, .grep, .glob, .bash];
///         promptTemplate guides error analysis and root cause identification
/// - AC2: Output includes root cause analysis, reproduction steps, and specific
///         fix suggestions referencing file:line
/// - AC3: Multiple root causes sorted by likelihood/possibility
final class DebugSkillTests: XCTestCase {

    // MARK: - Test Subject

    /// The debug skill under test.
    private var debugSkill: Skill!

    override func setUp() {
        super.setUp()
        debugSkill = BuiltInSkills.debug
    }

    override func tearDown() {
        debugSkill = nil
        super.tearDown()
    }

    // MARK: - AC1: DebugSkill Registration & PromptTemplate Error Analysis

    /// AC1 [P0]: BuiltInSkills.debug has correct name.
    func testDebugSkill_HasCorrectName() {
        // Given: BuiltInSkills.debug
        // Then: name is "debug"
        XCTAssertEqual(debugSkill.name, "debug",
                       "BuiltInSkills.debug should have name 'debug'")
    }

    /// AC1 [P0]: BuiltInSkills.debug has correct aliases.
    func testDebugSkill_HasCorrectAliases() {
        // Given: BuiltInSkills.debug
        // Then: aliases contains "investigate" and "diagnose"
        let aliases = debugSkill.aliases
        XCTAssertTrue(aliases.contains("investigate"),
                       "BuiltInSkills.debug aliases should contain 'investigate'")
        XCTAssertTrue(aliases.contains("diagnose"),
                       "BuiltInSkills.debug aliases should contain 'diagnose'")
    }

    /// AC1 [P0]: BuiltInSkills.debug is user invocable.
    func testDebugSkill_IsUserInvocable() {
        // Given: BuiltInSkills.debug
        // Then: userInvocable is true
        XCTAssertTrue(debugSkill.userInvocable,
                      "BuiltInSkills.debug should be user invocable")
    }

    /// AC1 [P0]: BuiltInSkills.debug has correct tool restrictions.
    /// Per story AC1: toolRestrictions must be [.read, .grep, .glob, .bash]
    /// (read files, search code, run diagnostic commands).
    func testDebugSkill_HasCorrectToolRestrictions() {
        // Given: BuiltInSkills.debug
        // Then: toolRestrictions includes bash, read, grep, glob
        let restrictions = debugSkill.toolRestrictions
        XCTAssertNotNil(restrictions, "toolRestrictions should not be nil")
        XCTAssertTrue(restrictions?.contains(.bash) ?? false,
                      "Should include .bash for running diagnostic commands")
        XCTAssertTrue(restrictions?.contains(.read) ?? false,
                      "Should include .read for file reading")
        XCTAssertTrue(restrictions?.contains(.grep) ?? false,
                      "Should include .grep for content search")
        XCTAssertTrue(restrictions?.contains(.glob) ?? false,
                      "Should include .glob for file pattern matching")
        XCTAssertEqual(restrictions?.count, 4,
                       "Should have exactly 4 tool restrictions (bash, read, grep, glob)")
    }

    /// AC1 [P0]: toolRestrictions includes bash for running diagnostic commands.
    func testDebugSkill_IncludesBashForDiagnostics() {
        // Given: BuiltInSkills.debug
        let restrictions = debugSkill.toolRestrictions
        // Then: must include .bash for running diagnostic commands (build, git log, etc.)
        XCTAssertTrue(restrictions?.contains(.bash) ?? false,
                       "toolRestrictions should include .bash for running diagnostic commands " +
                       "(e.g., swift build, git log, test commands).")
    }

    /// AC1 [P0]: toolRestrictions must NOT include write or edit (diagnostic-only skill).
    func testDebugSkill_DoesNotIncludeWriteOrEdit() {
        // Given: BuiltInSkills.debug
        let restrictions = debugSkill.toolRestrictions
        // Then: must not include .write or .edit
        XCTAssertFalse(restrictions?.contains(.write) ?? false,
                       "AC1 FAIL: toolRestrictions should NOT include .write")
        XCTAssertFalse(restrictions?.contains(.edit) ?? false,
                       "AC1 FAIL: toolRestrictions should NOT include .edit")
    }

    /// AC1 [P0]: promptTemplate contains root cause analysis keywords.
    /// Per story AC1: promptTemplate must guide root cause analysis.
    func testAC1_PromptTemplate_ContainsRootCauseAnalysis() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template must include root cause analysis keywords
        let hasRootCause =
            template.localizedCaseInsensitiveContains("root cause") ||
            template.localizedCaseInsensitiveContains("根因")
        XCTAssertTrue(hasRootCause,
                      "AC1 FAIL: promptTemplate must include root cause analysis " +
                      "(keywords: root cause, 根因)")
    }

    /// AC1 [P0]: promptTemplate guides using Read/Grep to view source files.
    /// Per story AC1: promptTemplate must guide using Read/Grep to view source files.
    func testAC1_PromptTemplate_GuidesUseReadAndGrep() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template must guide using Read and Grep tools
        let hasRead = template.localizedCaseInsensitiveContains("read")
        let hasGrep = template.localizedCaseInsensitiveContains("grep")
        XCTAssertTrue(hasRead,
                      "AC1 FAIL: promptTemplate must guide using Read to view source files")
        XCTAssertTrue(hasGrep,
                      "AC1 FAIL: promptTemplate must guide using Grep to search code")
    }

    /// AC1 [P0]: promptTemplate guides using Bash to run diagnostic commands.
    /// Per story AC1: promptTemplate must guide using Bash for diagnostic commands
    /// (e.g., build commands, git log).
    func testAC1_PromptTemplate_GuidesUseBashForDiagnostics() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template must guide using Bash for diagnostic commands
        let hasBashOrDiagnostic =
            template.localizedCaseInsensitiveContains("bash") ||
            template.localizedCaseInsensitiveContains("diagnostic") ||
            template.localizedCaseInsensitiveContains("build") ||
            template.localizedCaseInsensitiveContains("git log")
        XCTAssertTrue(hasBashOrDiagnostic,
                      "AC1 FAIL: promptTemplate must guide using Bash for diagnostic commands " +
                      "(keywords: bash, diagnostic, build, git log)")
    }

    /// AC1 [P0]: promptTemplate must NOT instruct the agent to directly fix issues.
    /// Per story dev notes: Debug is a diagnostic tool; it should provide fix suggestions,
    /// not implement fixes directly.
    func testAC1_PromptTemplate_DoesNotInstructDirectFix() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template should NOT instruct to implement fixes
        let hasDirectFix =
            template.localizedCaseInsensitiveContains("implement the minimal fix") ||
            template.localizedCaseInsensitiveContains("implement the fix") ||
            template.localizedCaseInsensitiveContains("make the smallest change that resolves")
        XCTAssertFalse(hasDirectFix,
                       "AC1 FAIL: promptTemplate should NOT instruct to 'implement the minimal fix'. " +
                       "The debug skill is a diagnostic tool. It should provide fix suggestions, " +
                       "not implement fixes directly.")
    }

    /// AC1 [P1]: BuiltInSkills.debug isAvailable defaults to true.
    func testDebugSkill_IsAvailableByDefault() {
        // Given: BuiltInSkills.debug
        // Then: isAvailable returns true (no extra environment check)
        XCTAssertTrue(debugSkill.isAvailable(),
                      "BuiltInSkills.debug should be available by default")
    }

    /// AC1 [P1]: BuiltInSkills.debug description is non-empty and meaningful.
    func testDebugSkill_HasNonEmptyDescription() {
        // Given: BuiltInSkills.debug
        // Then: description is non-empty
        XCTAssertFalse(debugSkill.description.isEmpty,
                       "debug skill should have a non-empty description")
    }

    /// AC1 [P1]: Description should reflect diagnostic purpose (not fixing).
    func testAC1_Description_ReflectsDiagnosticPurpose() {
        // Given: BuiltInSkills.debug
        let description = debugSkill.description

        // Then: description should mention analysis/diagnosis/investigation
        let hasDiagnostic =
            description.localizedCaseInsensitiveContains("analyze") ||
            description.localizedCaseInsensitiveContains("analysis") ||
            description.localizedCaseInsensitiveContains("diagnos") ||
            description.localizedCaseInsensitiveContains("investigat") ||
            description.localizedCaseInsensitiveContains("root cause")
        XCTAssertTrue(hasDiagnostic,
                      "AC1 FAIL: description should reflect diagnostic purpose " +
                      "(keywords: analyze, analysis, diagnose, investigate, root cause)")
    }

    // MARK: - AC2: Output Includes Root Cause Analysis, Reproduction Steps, and Fix Suggestions

    /// AC2 [P0]: promptTemplate requires file:line number references in findings.
    /// Per story AC2: each finding must reference specific file name and line number
    /// (format: `path/to/file.swift:行号`).
    func testAC2_PromptTemplate_RequiresFileAndLineNumberReferences() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

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
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template must instruct to reference file names
        XCTAssertTrue(template.localizedCaseInsensitiveContains("file name") ||
                      template.localizedCaseInsensitiveContains("filename") ||
                      template.localizedCaseInsensitiveContains("file names"),
                      "AC2 FAIL: promptTemplate must instruct to reference specific file names in findings")
    }

    /// AC2 [P0]: promptTemplate instructs to reference line numbers in findings.
    func testAC2_PromptTemplate_ReferencesLineNumbers() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template must instruct to reference line numbers
        XCTAssertTrue(template.localizedCaseInsensitiveContains("line number") ||
                      template.localizedCaseInsensitiveContains("line numbers"),
                      "AC2 FAIL: promptTemplate must instruct to reference specific line numbers in findings")
    }

    /// AC2 [P0]: promptTemplate requires root cause analysis section in output.
    /// Per story AC2: output must contain root cause analysis.
    func testAC2_PromptTemplate_ContainsRootCauseSection() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template must require a root cause analysis section
        let hasRootCauseSection =
            template.localizedCaseInsensitiveContains("root cause") ||
            template.localizedCaseInsensitiveContains("根因分析") ||
            template.localizedCaseInsensitiveContains("cause analysis")
        XCTAssertTrue(hasRootCauseSection,
                      "AC2 FAIL: promptTemplate must require a root cause analysis section in output " +
                      "(keywords: root cause, cause analysis)")
    }

    /// AC2 [P0]: promptTemplate requires reproduction steps in output.
    /// Per story AC2: output must contain reproduction steps (if applicable).
    func testAC2_PromptTemplate_ContainsReproductionSteps() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template must require reproduction steps
        let hasReproSteps =
            template.localizedCaseInsensitiveContains("reproduc") ||
            template.localizedCaseInsensitiveContains("复现步骤")
        XCTAssertTrue(hasReproSteps,
                      "AC2 FAIL: promptTemplate must require reproduction steps in output " +
                      "(keywords: reproduce, reproduction, 复现步骤)")
    }

    /// AC2 [P0]: promptTemplate requires fix suggestions in output.
    /// Per story AC2: output must contain specific fix suggestions.
    func testAC2_PromptTemplate_ContainsFixSuggestions() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template must require fix suggestions
        let hasFixSuggestions =
            template.localizedCaseInsensitiveContains("fix suggestion") ||
            template.localizedCaseInsensitiveContains("fix recommend") ||
            template.localizedCaseInsensitiveContains("suggested fix") ||
            template.localizedCaseInsensitiveContains("修复建议") ||
            template.localizedCaseInsensitiveContains("repair") ||
            template.localizedCaseInsensitiveContains("resolution")
        XCTAssertTrue(hasFixSuggestions,
                      "AC2 FAIL: promptTemplate must require fix suggestions in output " +
                      "(keywords: fix suggestion, suggested fix, 修复建议, resolution)")
    }

    /// AC2 [P0]: promptTemplate handles no error message scenario.
    /// Per story dev notes: must handle user not providing a specific error message.
    func testAC2_PromptTemplate_HandlesNoErrorMessage() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template must handle the case where no error message is provided
        let hasNoErrorHandling =
            template.localizedCaseInsensitiveContains("no error") ||
            template.localizedCaseInsensitiveContains("no error message") ||
            template.localizedCaseInsensitiveContains("no specific error") ||
            (template.localizedCaseInsensitiveContains("if no") &&
             template.localizedCaseInsensitiveContains("error")) ||
            template.localizedCaseInsensitiveContains("describe the issue") ||
            template.localizedCaseInsensitiveContains("ask the user")
        XCTAssertTrue(hasNoErrorHandling,
                      "AC2 FAIL: promptTemplate must handle the scenario where the user " +
                      "does not provide a specific error message. Should instruct the agent " +
                      "on how to proceed when no error information is given.")
    }

    // MARK: - AC3: Multiple Root Causes Sorted by Likelihood

    /// AC3 [P0]: promptTemplate requires sorting multiple root causes by likelihood.
    /// Per story AC3: when multiple root causes are found, sort by likelihood/possibility.
    func testAC3_PromptTemplate_RequiresRootCauseSorting() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template must instruct to sort multiple root causes
        let hasSorting =
            template.localizedCaseInsensitiveContains("likelihood") ||
            template.localizedCaseInsensitiveContains("possibility") ||
            template.localizedCaseInsensitiveContains("可能性") ||
            template.localizedCaseInsensitiveContains("排序") ||
            (template.localizedCaseInsensitiveContains("sort") &&
             template.localizedCaseInsensitiveContains("cause")) ||
            (template.localizedCaseInsensitiveContains("order") &&
             template.localizedCaseInsensitiveContains("likely")) ||
            template.localizedCaseInsensitiveContains("most likely")
        XCTAssertTrue(hasSorting,
                      "AC3 FAIL: promptTemplate must instruct to sort multiple root causes " +
                      "by likelihood/possibility (keywords: likelihood, possibility, 可能性排序, " +
                      "most likely, sort by)")
    }

    /// AC3 [P0]: promptTemplate explicitly handles multiple root cause scenario.
    /// Per story AC3: when multiple possible root causes exist, output sorted by likelihood.
    func testAC3_PromptTemplate_HandlesMultipleRootCauses() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template must explicitly address multiple root causes scenario
        let hasMultipleCauseHandling =
            template.localizedCaseInsensitiveContains("multiple root cause") ||
            template.localizedCaseInsensitiveContains("multiple possible cause") ||
            template.localizedCaseInsensitiveContains("multiple cause") ||
            template.localizedCaseInsensitiveContains("several possible") ||
            (template.localizedCaseInsensitiveContains("more than one") &&
             template.localizedCaseInsensitiveContains("cause"))
        XCTAssertTrue(hasMultipleCauseHandling,
                      "AC3 FAIL: promptTemplate must explicitly handle the scenario of " +
                      "multiple possible root causes (keywords: multiple root cause, " +
                      "multiple possible cause, several possible)")
    }

    /// AC3 [P1]: promptTemplate orders root causes from most to least likely.
    func testAC3_PromptTemplate_OrdersMostToLeastLikely() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template should specify ordering direction (most likely first)
        let hasOrderDirection =
            template.localizedCaseInsensitiveContains("most likely") ||
            template.localizedCaseInsensitiveContains("highest likelihood") ||
            template.localizedCaseInsensitiveContains("descending") ||
            (template.localizedCaseInsensitiveContains("order") &&
             template.localizedCaseInsensitiveContains("most"))
        XCTAssertTrue(hasOrderDirection,
                      "AC3 FAIL: promptTemplate should specify that root causes are ordered " +
                      "from most likely to least likely (keywords: most likely, highest likelihood)")
    }

    // MARK: - Edge Cases

    /// [P0]: promptTemplate handles build failure scenario.
    /// Per story dev notes: must include specific guidance for build failures.
    func testPromptTemplate_HandlesBuildFailureScenario() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template should include guidance for build failure scenarios
        let hasBuildFailureGuidance =
            template.localizedCaseInsensitiveContains("build fail") ||
            template.localizedCaseInsensitiveContains("build error") ||
            template.localizedCaseInsensitiveContains("compilation error") ||
            template.localizedCaseInsensitiveContains("compiler error") ||
            template.localizedCaseInsensitiveContains("构建失败")
        XCTAssertTrue(hasBuildFailureGuidance,
                      "promptTemplate must handle build failure scenarios " +
                      "(keywords: build failure, build error, compilation error)")
    }

    /// [P0]: promptTemplate handles runtime crash scenario.
    /// Per story dev notes: must include specific guidance for runtime crashes.
    func testPromptTemplate_HandlesRuntimeCrashScenario() {
        // Given: BuiltInSkills.debug promptTemplate
        let template = debugSkill.promptTemplate

        // Then: template should include guidance for runtime crash scenarios
        let hasRuntimeCrashGuidance =
            template.localizedCaseInsensitiveContains("runtime crash") ||
            template.localizedCaseInsensitiveContains("crash") ||
            template.localizedCaseInsensitiveContains("runtime error") ||
            template.localizedCaseInsensitiveContains("exception") ||
            template.localizedCaseInsensitiveContains("stack trace") ||
            template.localizedCaseInsensitiveContains("运行时崩溃")
        XCTAssertTrue(hasRuntimeCrashGuidance,
                      "promptTemplate must handle runtime crash scenarios " +
                      "(keywords: runtime crash, crash, exception, stack trace)")
    }

    // MARK: - Registry Integration

    /// AC1 [P1]: BuiltInSkills.debug can be registered and found in SkillRegistry.
    func testDebugSkill_CanBeRegisteredAndFound() {
        // Given: a fresh registry
        let registry = SkillRegistry()

        // When: registering BuiltInSkills.debug
        registry.register(BuiltInSkills.debug)

        // Then: find by name returns the skill
        let found = registry.find("debug")
        XCTAssertNotNil(found, "debug skill should be findable after registration")
        XCTAssertEqual(found?.name, "debug")
    }

    /// AC1 [P1]: BuiltInSkills.debug can be found by alias "investigate".
    func testDebugSkill_CanBeFoundByAliasInvestigate() {
        // Given: a fresh registry with debug skill registered
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.debug)

        // When: searching by alias "investigate"
        let found = registry.find("investigate")
        XCTAssertNotNil(found, "debug skill should be findable by alias 'investigate'")
        XCTAssertEqual(found?.name, "debug")
    }

    /// AC1 [P1]: BuiltInSkills.debug can be found by alias "diagnose".
    func testDebugSkill_CanBeFoundByAliasDiagnose() {
        // Given: a fresh registry with debug skill registered
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.debug)

        // When: searching by alias "diagnose"
        let found = registry.find("diagnose")
        XCTAssertNotNil(found, "debug skill should be findable by alias 'diagnose'")
        XCTAssertEqual(found?.name, "debug")
    }

    /// AC1 [P0]: registry.replace() can override debug skill's promptTemplate.
    func testDebugSkill_OverridableViaRegistryReplace() {
        // Given: a fresh registry and a custom promptTemplate
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.debug)

        let customTemplate = "Custom debug template: analyze error and provide root cause."
        let customSkill = Skill(
            name: "debug",
            promptTemplate: customTemplate
        )

        // When: replacing the debug skill with a custom promptTemplate
        registry.replace(customSkill)

        // Then: the registry returns the custom promptTemplate
        let found = registry.find("debug")
        XCTAssertNotNil(found, "debug skill should still be registered")
        XCTAssertEqual(found?.promptTemplate, customTemplate,
                       "registry.replace() should allow overriding debug skill's promptTemplate")
    }

    /// [P1]: BuiltInSkills.debug returns a new instance each time (value type).
    func testDebugSkill_ReturnsNewInstance() {
        // Given: two accesses to BuiltInSkills.debug
        let skill1 = BuiltInSkills.debug
        let skill2 = BuiltInSkills.debug

        // Then: they are independent (value type semantics)
        XCTAssertEqual(skill1.name, skill2.name)
        XCTAssertEqual(skill1.promptTemplate, skill2.promptTemplate)
    }

    /// AC1 [P1]: BuiltInSkills.debug modelOverride is nil (default).
    func testDebugSkill_HasNoModelOverride() {
        // Given: BuiltInSkills.debug
        // Then: modelOverride should be nil (no special model)
        XCTAssertNil(debugSkill.modelOverride,
                     "debug skill should not have a model override")
    }

    /// AC1 [P1]: BuiltInSkills.debug promptTemplate is non-empty.
    func testDebugSkill_HasNonEmptyPromptTemplate() {
        // Given: BuiltInSkills.debug
        // Then: promptTemplate is non-empty
        XCTAssertFalse(debugSkill.promptTemplate.isEmpty,
                       "debug skill should have a non-empty promptTemplate")
    }
}

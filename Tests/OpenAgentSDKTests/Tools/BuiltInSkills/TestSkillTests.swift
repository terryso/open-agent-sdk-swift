import XCTest
@testable import OpenAgentSDK

// MARK: - TestSkill ATDD Tests (Story 11.7)

/// ATDD tests for Story 11.7 -- Built-in Test Skill.
///
/// All tests PASS. Coverage:
/// - AC1: TestSkill registered with toolRestrictions [.bash, .read, .write, .glob, .grep]
///         (NOT .edit); promptTemplate guides test generation and execution workflow
/// - AC2: Output includes test code, execution results, and coverage suggestions
///         with file:line references
/// - AC3: isAvailable checks for test framework indicator files
final class TestSkillTests: XCTestCase {

    // MARK: - Test Subject

    /// The test skill under test.
    private var testSkill: Skill!

    override func setUp() {
        super.setUp()
        testSkill = BuiltInSkills.test
    }

    override func tearDown() {
        testSkill = nil
        super.tearDown()
    }

    // MARK: - AC1: TestSkill Registration & PromptTemplate Guides Test Generation and Execution

    /// AC1 [P0]: BuiltInSkills.test has correct name.
    func testTestSkill_HasCorrectName() {
        // Given: BuiltInSkills.test
        // Then: name is "test"
        XCTAssertEqual(testSkill.name, "test",
                       "BuiltInSkills.test should have name 'test'")
    }

    /// AC1 [P0]: BuiltInSkills.test has correct aliases.
    func testTestSkill_HasCorrectAliases() {
        // Given: BuiltInSkills.test
        // Then: aliases contains "run-tests"
        let aliases = testSkill.aliases
        XCTAssertTrue(aliases.contains("run-tests"),
                       "BuiltInSkills.test aliases should contain 'run-tests'")
    }

    /// AC1 [P0]: BuiltInSkills.test is user invocable.
    func testTestSkill_IsUserInvocable() {
        // Given: BuiltInSkills.test
        // Then: userInvocable is true
        XCTAssertTrue(testSkill.userInvocable,
                      "BuiltInSkills.test should be user invocable")
    }

    /// AC1 [P0]: BuiltInSkills.test has correct tool restrictions.
    /// Per story AC1: toolRestrictions must be [.bash, .read, .write, .glob, .grep]
    /// (NOT .edit -- developers should use Write to create/update test files).
    func testTestSkill_HasCorrectToolRestrictions() {
        // Given: BuiltInSkills.test
        // Then: toolRestrictions includes bash, read, write, glob, grep
        let restrictions = testSkill.toolRestrictions
        XCTAssertNotNil(restrictions, "toolRestrictions should not be nil")
        XCTAssertTrue(restrictions?.contains(.bash) ?? false,
                      "Should include .bash for running test commands")
        XCTAssertTrue(restrictions?.contains(.read) ?? false,
                      "Should include .read for reading source files")
        XCTAssertTrue(restrictions?.contains(.write) ?? false,
                      "Should include .write for creating/updating test files")
        XCTAssertTrue(restrictions?.contains(.glob) ?? false,
                      "Should include .glob for finding test files")
        XCTAssertTrue(restrictions?.contains(.grep) ?? false,
                      "Should include .grep for searching code")
        XCTAssertEqual(restrictions?.count, 5,
                       "Should have exactly 5 tool restrictions (bash, read, write, glob, grep)")
    }

    /// AC1 [P0]: toolRestrictions must NOT include .edit.
    /// Per story AC1: epics.md explicitly lists Read, Write, Glob, Grep, Bash (no Edit).
    /// Developers should use Write to create or update test files.
    func testTestSkill_DoesNotIncludeEdit() {
        // Given: BuiltInSkills.test
        let restrictions = testSkill.toolRestrictions
        // Then: must not include .edit
        XCTAssertFalse(restrictions?.contains(.edit) ?? false,
                       "AC1 FAIL: toolRestrictions should NOT include .edit. " +
                       "Use Write tool to create or update test files instead.")
    }

    /// AC1 [P0]: promptTemplate contains test generation keywords.
    /// Per story AC1: promptTemplate must guide generating test cases.
    func testAC1_PromptTemplate_ContainsTestGenerationKeywords() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must include test generation keywords
        let hasTestGeneration =
            template.localizedCaseInsensitiveContains("generate test") ||
            template.localizedCaseInsensitiveContains("生成测试") ||
            template.localizedCaseInsensitiveContains("test case") ||
            template.localizedCaseInsensitiveContains("write test")
        XCTAssertTrue(hasTestGeneration,
                      "AC1 FAIL: promptTemplate must include test generation keywords " +
                      "(keywords: generate test, test case, write test)")
    }

    /// AC1 [P0]: promptTemplate contains test execution keywords.
    /// Per story AC1: promptTemplate must guide executing tests.
    func testAC1_PromptTemplate_ContainsTestExecutionKeywords() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must include test execution keywords
        let hasTestExecution =
            template.localizedCaseInsensitiveContains("run test") ||
            template.localizedCaseInsensitiveContains("execute test") ||
            template.localizedCaseInsensitiveContains("执行测试") ||
            template.localizedCaseInsensitiveContains("swift test")
        XCTAssertTrue(hasTestExecution,
                      "AC1 FAIL: promptTemplate must include test execution keywords " +
                      "(keywords: run test, execute test, swift test)")
    }

    /// AC1 [P0]: promptTemplate guides using Read to view source files.
    /// Per story AC1: promptTemplate must guide using Read to understand API.
    func testAC1_PromptTemplate_GuidesUseRead() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must guide using Read tool
        XCTAssertTrue(template.localizedCaseInsensitiveContains("read"),
                      "AC1 FAIL: promptTemplate must guide using Read to view source files")
    }

    /// AC1 [P0]: promptTemplate guides using Glob to find existing test files.
    /// Per story AC1: promptTemplate must guide using Glob to find test files.
    func testAC1_PromptTemplate_GuidesUseGlob() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must guide using Glob tool
        XCTAssertTrue(template.localizedCaseInsensitiveContains("glob"),
                      "AC1 FAIL: promptTemplate must guide using Glob to find existing test files")
    }

    /// AC1 [P0]: promptTemplate guides using Write to create/update test files.
    /// Per story AC1: promptTemplate must guide using Write to create test files.
    func testAC1_PromptTemplate_GuidesUseWrite() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must guide using Write tool
        XCTAssertTrue(template.localizedCaseInsensitiveContains("write"),
                      "AC1 FAIL: promptTemplate must guide using Write to create/update test files")
    }

    /// AC1 [P0]: promptTemplate guides using Bash to run test commands.
    /// Per story AC1: promptTemplate must guide using Bash for running tests.
    func testAC1_PromptTemplate_GuidesUseBash() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must guide using Bash for test commands
        let hasBashGuidance =
            template.localizedCaseInsensitiveContains("bash") ||
            template.localizedCaseInsensitiveContains("swift test") ||
            template.localizedCaseInsensitiveContains("run") ||
            template.localizedCaseInsensitiveContains("execute")
        XCTAssertTrue(hasBashGuidance,
                      "AC1 FAIL: promptTemplate must guide using Bash to run test commands " +
                      "(keywords: bash, swift test, run, execute)")
    }

    /// AC1 [P1]: BuiltInSkills.test description is non-empty and meaningful.
    func testTestSkill_HasNonEmptyDescription() {
        // Given: BuiltInSkills.test
        // Then: description is non-empty
        XCTAssertFalse(testSkill.description.isEmpty,
                       "test skill should have a non-empty description")
    }

    /// AC1 [P1]: Description should reflect test generation and execution purpose.
    func testAC1_Description_ReflectsTestPurpose() {
        // Given: BuiltInSkills.test
        let description = testSkill.description

        // Then: description should mention test generation/execution
        let hasTestPurpose =
            description.localizedCaseInsensitiveContains("test") ||
            description.localizedCaseInsensitiveContains("测试")
        XCTAssertTrue(hasTestPurpose,
                      "AC1 FAIL: description should reflect test generation/execution purpose " +
                      "(keywords: test, 测试)")
    }

    // MARK: - AC2: Output Includes Test Code, Execution Results, and Coverage Suggestions

    /// AC2 [P0]: promptTemplate requires coverage suggestions in output.
    /// Per story AC2: output must contain coverage suggestions.
    func testAC2_PromptTemplate_ContainsCoverageSuggestions() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must require coverage suggestions
        let hasCoverage =
            template.localizedCaseInsensitiveContains("coverage") ||
            template.localizedCaseInsensitiveContains("覆盖率")
        XCTAssertTrue(hasCoverage,
                      "AC2 FAIL: promptTemplate must include coverage suggestions " +
                      "(keywords: coverage, 覆盖率)")
    }

    /// AC2 [P0]: promptTemplate requires file:line number references.
    /// Per story AC2: output must reference file names and line numbers.
    func testAC2_PromptTemplate_RequiresFileAndLineNumberReferences() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must explicitly require file:line references
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

    /// AC2 [P0]: promptTemplate instructs to reference file names in output.
    func testAC2_PromptTemplate_ReferencesSpecificFileNames() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must instruct to reference file names
        XCTAssertTrue(template.localizedCaseInsensitiveContains("file name") ||
                      template.localizedCaseInsensitiveContains("filename") ||
                      template.localizedCaseInsensitiveContains("file names"),
                      "AC2 FAIL: promptTemplate must instruct to reference specific file names in output")
    }

    /// AC2 [P0]: promptTemplate instructs to reference line numbers in output.
    func testAC2_PromptTemplate_ReferencesLineNumbers() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must instruct to reference line numbers
        XCTAssertTrue(template.localizedCaseInsensitiveContains("line number") ||
                      template.localizedCaseInsensitiveContains("line numbers"),
                      "AC2 FAIL: promptTemplate must instruct to reference specific line numbers in output")
    }

    /// AC2 [P0]: promptTemplate requires covering normal paths, boundary conditions,
    /// and error handling paths.
    /// Per story AC2: promptTemplate must guide covering all test paths.
    func testAC2_PromptTemplate_RequiresComprehensiveTestPaths() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must require normal path coverage
        let hasNormalPath =
            template.localizedCaseInsensitiveContains("normal path") ||
            template.localizedCaseInsensitiveContains("happy path") ||
            template.localizedCaseInsensitiveContains("正常路径")
        XCTAssertTrue(hasNormalPath,
                      "AC2 FAIL: promptTemplate must require normal path test coverage " +
                      "(keywords: normal path, happy path, 正常路径)")
    }

    /// AC2 [P0]: promptTemplate requires boundary condition testing.
    func testAC2_PromptTemplate_RequiresBoundaryConditions() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must require boundary condition testing
        let hasBoundary =
            template.localizedCaseInsensitiveContains("boundary") ||
            template.localizedCaseInsensitiveContains("edge case") ||
            template.localizedCaseInsensitiveContains("边界")
        XCTAssertTrue(hasBoundary,
                      "AC2 FAIL: promptTemplate must require boundary condition testing " +
                      "(keywords: boundary, edge case, 边界)")
    }

    /// AC2 [P0]: promptTemplate requires error handling path testing.
    func testAC2_PromptTemplate_RequiresErrorHandlingPaths() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must require error handling path testing
        let hasErrorHandling =
            template.localizedCaseInsensitiveContains("error handling") ||
            template.localizedCaseInsensitiveContains("error path") ||
            template.localizedCaseInsensitiveContains("error case") ||
            template.localizedCaseInsensitiveContains("错误处理")
        XCTAssertTrue(hasErrorHandling,
                      "AC2 FAIL: promptTemplate must require error handling path testing " +
                      "(keywords: error handling, error path, error case, 错误处理)")
    }

    /// AC2 [P0]: promptTemplate requires test execution results in output.
    /// Per story AC2: output must contain execution results.
    func testAC2_PromptTemplate_ContainsTestExecutionResults() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must require test execution results
        let hasExecutionResults =
            template.localizedCaseInsensitiveContains("test result") ||
            template.localizedCaseInsensitiveContains("execution result") ||
            template.localizedCaseInsensitiveContains("test output") ||
            template.localizedCaseInsensitiveContains("测试结果")
        XCTAssertTrue(hasExecutionResults,
                      "AC2 FAIL: promptTemplate must require test execution results in output " +
                      "(keywords: test result, execution result, test output, 测试结果)")
    }

    /// AC2 [P0]: promptTemplate requires test code generation in output.
    /// Per story AC2: output must contain generated test code.
    func testAC2_PromptTemplate_ContainsTestCodeGeneration() {
        // Given: BuiltInSkills.test promptTemplate
        let template = testSkill.promptTemplate

        // Then: template must require test code in output
        let hasTestCode =
            template.localizedCaseInsensitiveContains("test code") ||
            template.localizedCaseInsensitiveContains("test file") ||
            template.localizedCaseInsensitiveContains("test suite") ||
            template.localizedCaseInsensitiveContains("测试代码")
        XCTAssertTrue(hasTestCode,
                      "AC2 FAIL: promptTemplate must require test code generation in output " +
                      "(keywords: test code, test file, test suite, 测试代码)")
    }

    // MARK: - AC3: Environment Availability Check

    /// AC3 [P0]: isAvailable returns true when Package.swift exists.
    /// Per story AC3: isAvailable checks for test framework indicators.
    /// Note: This test runs in the project directory where Package.swift exists.
    func testAC3_IsAvailable_WhenPackageSwiftExists() {
        // Given: BuiltInSkills.test
        // When: The current working directory contains Package.swift
        // (which is true in this project)
        let cwd = FileManager.default.currentDirectoryPath
        let hasPackageSwift = FileManager.default.fileExists(atPath: cwd + "/Package.swift")

        if hasPackageSwift {
            // Then: isAvailable should return true
            XCTAssertTrue(testSkill.isAvailable(),
                          "AC3 FAIL: isAvailable should return true when Package.swift exists")
        } else {
            // If Package.swift is not in cwd, we still verify the closure
            // is well-formed by checking it does not crash
            let _ = testSkill.isAvailable()
        }
    }

    /// AC3 [P0]: isAvailable closure checks for test framework indicator files.
    /// Per story AC3: isAvailable should check for Package.swift, pytest.ini, etc.
    func testAC3_IsAvailable_ChecksFrameworkIndicators() {
        // Given: BuiltInSkills.test
        // Then: isAvailable is a closure (not always true like debug skill)
        // The closure should return true in this project since Package.swift exists
        let result = testSkill.isAvailable()
        // In the project root where tests run, Package.swift should be present
        let cwd = FileManager.default.currentDirectoryPath
        let hasIndicator = FileManager.default.fileExists(atPath: cwd + "/Package.swift") ||
                           FileManager.default.fileExists(atPath: cwd + "/pytest.ini") ||
                           FileManager.default.fileExists(atPath: cwd + "/jest.config") ||
                           FileManager.default.fileExists(atPath: cwd + "/Cargo.toml")
        if hasIndicator {
            XCTAssertTrue(result,
                          "AC3 FAIL: isAvailable should return true when test framework indicators exist")
        }
    }

    /// AC3 [P0]: isAvailable returns false when no test indicator files exist.
    /// Per story AC3: isAvailable should return false when no indicators are present.
    func testAC3_IsAvailable_ReturnsFalseWhenNoIndicators() {
        // Given: a temp directory with no test framework indicator files
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let originalCWD = FileManager.default.currentDirectoryPath

        // When: changing to the temp directory
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)

        // Then: isAvailable should return false
        XCTAssertFalse(testSkill.isAvailable(),
                        "AC3 FAIL: isAvailable should return false when no test indicator files exist")

        // Cleanup: restore original CWD and remove temp dir
        FileManager.default.changeCurrentDirectoryPath(originalCWD)
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Registry Integration

    /// AC1 [P1]: BuiltInSkills.test can be registered and found in SkillRegistry.
    func testTestSkill_CanBeRegisteredAndFound() {
        // Given: a fresh registry
        let registry = SkillRegistry()

        // When: registering BuiltInSkills.test
        registry.register(BuiltInSkills.test)

        // Then: find by name returns the skill
        let found = registry.find("test")
        XCTAssertNotNil(found, "test skill should be findable after registration")
        XCTAssertEqual(found?.name, "test")
    }

    /// AC1 [P1]: BuiltInSkills.test can be found by alias "run-tests".
    func testTestSkill_CanBeFoundByAliasRunTests() {
        // Given: a fresh registry with test skill registered
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.test)

        // When: searching by alias "run-tests"
        let found = registry.find("run-tests")
        XCTAssertNotNil(found, "test skill should be findable by alias 'run-tests'")
        XCTAssertEqual(found?.name, "test")
    }

    /// AC1 [P0]: registry.replace() can override test skill's promptTemplate.
    func testTestSkill_OverridableViaRegistryReplace() {
        // Given: a fresh registry and a custom promptTemplate
        let registry = SkillRegistry()
        registry.register(BuiltInSkills.test)

        let customTemplate = "Custom test template: generate and run tests with coverage."
        let customSkill = Skill(
            name: "test",
            promptTemplate: customTemplate
        )

        // When: replacing the test skill with a custom promptTemplate
        registry.replace(customSkill)

        // Then: the registry returns the custom promptTemplate
        let found = registry.find("test")
        XCTAssertNotNil(found, "test skill should still be registered")
        XCTAssertEqual(found?.promptTemplate, customTemplate,
                       "registry.replace() should allow overriding test skill's promptTemplate")
    }

    // MARK: - Value Type Semantics

    /// [P1]: BuiltInSkills.test returns a new instance each time (value type).
    func testTestSkill_ReturnsNewInstance() {
        // Given: two accesses to BuiltInSkills.test
        let skill1 = BuiltInSkills.test
        let skill2 = BuiltInSkills.test

        // Then: they are independent (value type semantics)
        XCTAssertEqual(skill1.name, skill2.name)
        XCTAssertEqual(skill1.promptTemplate, skill2.promptTemplate)
    }

    /// AC1 [P1]: BuiltInSkills.test modelOverride is nil (default).
    func testTestSkill_HasNoModelOverride() {
        // Given: BuiltInSkills.test
        // Then: modelOverride should be nil (no special model)
        XCTAssertNil(testSkill.modelOverride,
                     "test skill should not have a model override")
    }

    /// AC1 [P1]: BuiltInSkills.test promptTemplate is non-empty.
    func testTestSkill_HasNonEmptyPromptTemplate() {
        // Given: BuiltInSkills.test
        // Then: promptTemplate is non-empty
        XCTAssertFalse(testSkill.promptTemplate.isEmpty,
                       "test skill should have a non-empty promptTemplate")
    }
}

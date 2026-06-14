import XCTest
@testable import OpenAgentSDK

// MARK: - Skill Types Tests (Story 11.1)

/// Tests for Story 11.1 -- Skill Type Definition & SkillRegistry.
/// Covers: Skill struct, ToolRestriction enum, BuiltInSkills namespace.
final class SkillTypesTests: XCTestCase {

    // MARK: - AC1: Skill struct definition and creation

    /// AC1 [P0]: Skill can be created with required fields (name and promptTemplate).
    func testSkill_CreationWithRequiredFields() {
        // Given: a Skill with minimum required fields
        let skill = Skill(
            name: "commit",
            promptTemplate: "Create a git commit with the staged changes."
        )

        // Then: properties are correctly stored
        XCTAssertEqual(skill.name, "commit")
        XCTAssertEqual(skill.promptTemplate, "Create a git commit with the staged changes.")
    }

    /// AC1 [P0]: Skill can be created with all fields populated.
    func testSkill_CreationWithAllFields() {
        // Given: a Skill with all optional fields
        let skill = Skill(
            name: "commit",
            description: "Create a git commit",
            aliases: ["ci"],
            userInvocable: true,
            toolRestrictions: [.bash, .read, .write],
            modelOverride: nil,
            isAvailable: { true },
            promptTemplate: "Create a commit.",
            whenToUse: "Use when you need to commit code",
            argumentHint: "<message>"
        )

        // Then: all properties are correctly stored
        XCTAssertEqual(skill.name, "commit")
        XCTAssertEqual(skill.description, "Create a git commit")
        XCTAssertEqual(skill.aliases, ["ci"])
        XCTAssertTrue(skill.userInvocable)
        XCTAssertEqual(skill.toolRestrictions?.count, 3)
        XCTAssertTrue(skill.toolRestrictions?.contains(.bash) ?? false)
        XCTAssertTrue(skill.toolRestrictions?.contains(.read) ?? false)
        XCTAssertTrue(skill.toolRestrictions?.contains(.write) ?? false)
        XCTAssertNil(skill.modelOverride)
        XCTAssertEqual(skill.promptTemplate, "Create a commit.")
        XCTAssertEqual(skill.whenToUse, "Use when you need to commit code")
        XCTAssertEqual(skill.argumentHint, "<message>")
    }

    /// AC1 [P0]: Skill has sensible defaults for optional fields.
    func testSkill_DefaultValues() {
        // Given: a Skill created with only required fields
        let skill = Skill(
            name: "test",
            promptTemplate: "Test template"
        )

        // Then: defaults are applied
        XCTAssertEqual(skill.description, "")
        XCTAssertTrue(skill.aliases.isEmpty)
        XCTAssertTrue(skill.userInvocable)
        XCTAssertNil(skill.toolRestrictions)
        XCTAssertNil(skill.modelOverride)
        XCTAssertNil(skill.whenToUse)
        XCTAssertNil(skill.argumentHint)
    }

    /// AC1 [P0]: Skill with toolRestrictions set to nil means no restrictions.
    func testSkill_ToolRestrictions_NilMeansNoRestrictions() {
        // Given: a Skill with nil toolRestrictions
        let skill = Skill(
            name: "unrestricted",
            promptTemplate: "No restrictions"
        )

        // Then: toolRestrictions is nil (meaning all tools allowed)
        XCTAssertNil(skill.toolRestrictions)
    }

    /// AC1 [P0]: Skill with toolRestrictions set to specific tools.
    func testSkill_ToolRestrictions_SpecificTools() {
        // Given: a Skill with specific tool restrictions
        let skill = Skill(
            name: "commit",
            toolRestrictions: [.bash, .read, .write, .edit],
            promptTemplate: "Commit"
        )

        // Then: only those tools are listed
        XCTAssertEqual(skill.toolRestrictions?.count, 4)
        XCTAssertFalse(skill.toolRestrictions?.contains(.glob) ?? true)
    }

    /// AC1 [P1]: Skill is a value type (struct) -- modifying a copy does not affect original.
    func testSkill_ValueTypeSemantics() {
        // Given: a skill
        let skill = Skill(
            name: "commit",
            promptTemplate: "Original"
        )

        // When: creating a new skill with the same name but different template
        let modified = Skill(
            name: skill.name,
            description: skill.description,
            aliases: skill.aliases,
            userInvocable: skill.userInvocable,
            toolRestrictions: skill.toolRestrictions,
            modelOverride: skill.modelOverride,
            isAvailable: skill.isAvailable,
            promptTemplate: "Modified",
            whenToUse: skill.whenToUse,
            argumentHint: skill.argumentHint
        )

        // Then: original is unchanged
        XCTAssertEqual(skill.promptTemplate, "Original")
        XCTAssertEqual(modified.promptTemplate, "Modified")
    }

    /// AC1 [P0]: Skill isAvailable closure defaults to returning true.
    func testSkill_IsAvailable_DefaultIsTrue() {
        // Given: a Skill with default isAvailable
        let skill = Skill(
            name: "commit",
            promptTemplate: "Commit"
        )

        // Then: isAvailable returns true
        XCTAssertTrue(skill.isAvailable())
    }

    /// AC1 [P0]: Skill isAvailable closure can be customized to return false.
    func testSkill_IsAvailable_CustomReturnsFalse() {
        // Given: a Skill with isAvailable returning false
        let skill = Skill(
            name: "test_skill",
            isAvailable: { false },
            promptTemplate: "Test"
        )

        // Then: isAvailable returns false
        XCTAssertFalse(skill.isAvailable())
    }

    // MARK: - AC1: ToolRestriction enum

    /// AC1 [P0]: ToolRestriction enum has all expected cases.
    func testToolRestriction_HasAllCases() {
        // Given: ToolRestriction enum
        let allCases = Set(ToolRestriction.allCases.map(\.rawValue))

        // Then: all expected tool names are present
        let expectedTools: Set<String> = [
            "bash", "read", "write", "edit", "glob", "grep",
            "webFetch", "webSearch", "askUser", "toolSearch",
            "agent", "sendMessage",
            "taskCreate", "taskList", "taskUpdate", "taskGet", "taskStop", "taskOutput",
            "teamCreate", "teamDelete", "notebookEdit",
            "skill"
        ]

        XCTAssertEqual(allCases, expectedTools,
                       "ToolRestriction should have all expected tool restriction cases")
    }

    /// AC1 [P0]: ToolRestriction rawValues match tool name strings.
    func testToolRestriction_RawValues() {
        // Then: raw values match expected strings
        XCTAssertEqual(ToolRestriction.bash.rawValue, "bash")
        XCTAssertEqual(ToolRestriction.read.rawValue, "read")
        XCTAssertEqual(ToolRestriction.write.rawValue, "write")
        XCTAssertEqual(ToolRestriction.edit.rawValue, "edit")
        XCTAssertEqual(ToolRestriction.glob.rawValue, "glob")
        XCTAssertEqual(ToolRestriction.grep.rawValue, "grep")
        XCTAssertEqual(ToolRestriction.webFetch.rawValue, "webFetch")
        XCTAssertEqual(ToolRestriction.webSearch.rawValue, "webSearch")
        XCTAssertEqual(ToolRestriction.skill.rawValue, "skill")
    }

    /// AC1 [P1]: ToolRestriction conforms to CaseIterable.
    func testToolRestriction_CaseIterable() {
        // Given: ToolRestriction enum
        let allCases = ToolRestriction.allCases

        // Then: it has at least 20 cases (all known tools)
        XCTAssertGreaterThanOrEqual(allCases.count, 20,
                                     "ToolRestriction should have all tool cases")
    }

    // MARK: - AC1: BuiltInSkills namespace

    /// AC1 [P0]: BuiltInSkills.commit returns a valid Skill.
    func testBuiltInSkills_Commit() {
        // Given: BuiltInSkills.commit
        let skill = BuiltInSkills.commit

        // Then: it has the expected properties
        XCTAssertEqual(skill.name, "commit")
        XCTAssertFalse(skill.promptTemplate.isEmpty)
        XCTAssertTrue(skill.userInvocable)
    }

    /// AC1 [P0]: BuiltInSkills.review returns a valid Skill.
    func testBuiltInSkills_Review() {
        // Given: BuiltInSkills.review
        let skill = BuiltInSkills.review

        // Then: it has the expected properties
        XCTAssertEqual(skill.name, "review")
        XCTAssertFalse(skill.promptTemplate.isEmpty)
        XCTAssertTrue(skill.userInvocable)
    }

    /// AC1 [P0]: BuiltInSkills.simplify returns a valid Skill.
    func testBuiltInSkills_Simplify() {
        // Given: BuiltInSkills.simplify
        let skill = BuiltInSkills.simplify

        // Then: it has the expected properties
        XCTAssertEqual(skill.name, "simplify")
        XCTAssertFalse(skill.promptTemplate.isEmpty)
        XCTAssertTrue(skill.userInvocable)
    }

    /// AC1 [P0]: BuiltInSkills.debug returns a valid Skill.
    func testBuiltInSkills_Debug() {
        // Given: BuiltInSkills.debug
        let skill = BuiltInSkills.debug

        // Then: it has the expected properties
        XCTAssertEqual(skill.name, "debug")
        XCTAssertFalse(skill.promptTemplate.isEmpty)
        XCTAssertTrue(skill.userInvocable)
    }

    /// AC1 [P0]: BuiltInSkills.test returns a valid Skill with isAvailable checking environment.
    func testBuiltInSkills_Test() {
        // Given: BuiltInSkills.test
        let skill = BuiltInSkills.test

        // Then: it has the expected properties
        XCTAssertEqual(skill.name, "test")
        XCTAssertFalse(skill.promptTemplate.isEmpty)
        XCTAssertTrue(skill.userInvocable)
        // isAvailable checks for test framework -- may be true or false depending on env
        // Just verify it doesn't crash
        _ = skill.isAvailable()
    }

    /// AC1 [P1]: BuiltInSkills returns new instances each time (value type).
    func testBuiltInSkills_ReturnsNewInstances() {
        // Given: two accesses to BuiltInSkills.commit
        let skill1 = BuiltInSkills.commit
        let skill2 = BuiltInSkills.commit

        // Then: they are equal but independent (value type)
        XCTAssertEqual(skill1.name, skill2.name)
        XCTAssertEqual(skill1.promptTemplate, skill2.promptTemplate)
    }

    // MARK: - Story 29.4: Tool Declaration Compatibility Model

    // 本区段为 Story 29.4（Tool Declaration Compatibility Model）的红阶段单元测试。
    // 覆盖 Skill struct 新增字段（toolDeclarations / toolDeclarationDiagnostics）的
    // 向后兼容性（AC4）与 ToolDeclarationStatus enum 的存在性。
    //
    // 红相说明：新字段与新类型在源码中尚不存在，本区段测试在**编译阶段**即失败
    // （Cannot find 'toolDeclarations' / 'toolDeclarationDiagnostics' /
    //  'ToolDeclarationStatus' / 'ToolDeclaration' / 'ToolDeclarationDiagnostics' in scope）。
    // 这是预期的 TDD 红相 —— 绿阶段实现后全部转绿。

    /// AC4 [P0]: Skill 新增的 toolDeclarations / toolDeclarationDiagnostics 字段默认 nil，
    /// 现有调用方（6 个 BuiltInSkills、测试 helper）不破坏。
    func testSkill_ToolDeclarations_DefaultsToNil() {
        // Given: 一个仅用必需字段创建的 Skill（模拟所有现有调用方）
        let skill = Skill(
            name: "compat-skill",
            promptTemplate: "Test"
        )

        // Then: 新字段默认 nil（向后兼容 —— 现有调用不传新参数也编译且行为合理）
        XCTAssertNil(skill.toolDeclarations,
                     "toolDeclarations 默认应为 nil，确保现有 init 调用不破坏")
        XCTAssertNil(skill.toolDeclarationDiagnostics,
                     "toolDeclarationDiagnostics 默认应为 nil")

        // And: 旧字段行为不变（回归保护）
        XCTAssertNil(skill.toolRestrictions)
    }

    /// AC4 [P0]: Skill.init 可显式传入 toolDeclarations / toolDeclarationDiagnostics，
    /// 并被正确存储。
    func testSkill_ToolDeclarations_ExplicitlySet() {
        // Given: 构造一组 ToolDeclaration
        let declarations: [ToolDeclaration] = [
            ToolDeclaration(
                rawName: "Bash",
                normalizedName: "bash",
                pattern: nil,
                status: .recognizedSDK,
                toolRestriction: .bash
            ),
            ToolDeclaration(
                rawName: "mcp__github__list_prs",
                normalizedName: "mcp__github__list_prs",
                pattern: nil,
                status: .recognizedMCP,
                toolRestriction: nil
            ),
        ]
        let diagnostics = ToolDeclarationDiagnostics(
            unsupportedDeclarations: [],
            patternDeclarations: []
        )

        // When: 用新参数创建 Skill
        let skill = Skill(
            name: "explicit-decl",
            toolDeclarations: declarations,
            toolDeclarationDiagnostics: diagnostics,
            promptTemplate: "Test"
        )

        // Then: 新字段被正确存储
        XCTAssertEqual(skill.toolDeclarations?.count, 2)
        XCTAssertEqual(skill.toolDeclarations?.first?.rawName, "Bash")
        XCTAssertEqual(skill.toolDeclarations?.last?.rawName, "mcp__github__list_prs")
        XCTAssertNotNil(skill.toolDeclarationDiagnostics)
    }

    /// AC4 [P0]: Skill.withBaseDir 复制新字段（toolDeclarations / toolDeclarationDiagnostics）。
    func testSkill_WithBaseDir_PreservesToolDeclarations() {
        // Given: 一个带 declarations 的 Skill
        let declarations: [ToolDeclaration] = [
            ToolDeclaration(
                rawName: "Read",
                normalizedName: "read",
                pattern: nil,
                status: .recognizedSDK,
                toolRestriction: .read
            ),
        ]
        let diagnostics = ToolDeclarationDiagnostics(
            unsupportedDeclarations: [],
            patternDeclarations: []
        )
        let original = Skill(
            name: "with-basedir-skill",
            toolDeclarations: declarations,
            toolDeclarationDiagnostics: diagnostics,
            promptTemplate: "Test"
        )

        // When: 调用 withBaseDir
        let copied = original.withBaseDir("/opt/skills/test")

        // Then: 新字段被复制
        XCTAssertEqual(copied.baseDir, "/opt/skills/test")
        XCTAssertEqual(copied.toolDeclarations?.count, 1,
                       "withBaseDir 必须复制 toolDeclarations")
        XCTAssertEqual(copied.toolDeclarations?.first?.rawName, "Read")
        XCTAssertNotNil(copied.toolDeclarationDiagnostics,
                        "withBaseDir 必须复制 toolDeclarationDiagnostics")
    }

    /// AC4 [P0]: Skill.== 比较 toolDeclarations / toolDeclarationDiagnostics。
    func testSkill_Equality_ConsidersToolDeclarations() {
        // Given: 两个除 toolDeclarations 外都相同的 Skill
        let skillA = Skill(
            name: "eq-skill",
            toolDeclarations: [
                ToolDeclaration(
                    rawName: "Bash",
                    normalizedName: "bash",
                    pattern: nil,
                    status: .recognizedSDK,
                    toolRestriction: .bash
                ),
            ],
            promptTemplate: "Test"
        )
        let skillB = Skill(
            name: "eq-skill",
            promptTemplate: "Test"
            // toolDeclarations 默认 nil
        )

        // Then: 二者不相等（toolDeclarations 差异被 == 捕获）
        XCTAssertNotEqual(skillA, skillB,
                          "Skill.== 必须比较 toolDeclarations 字段")

        // And: 两个完全相同的 Skill（含相同 declarations）应相等
        let skillC = Skill(
            name: "eq-skill",
            toolDeclarations: [
                ToolDeclaration(
                    rawName: "Bash",
                    normalizedName: "bash",
                    pattern: nil,
                    status: .recognizedSDK,
                    toolRestriction: .bash
                ),
            ],
            promptTemplate: "Test"
        )
        XCTAssertEqual(skillA, skillC,
                       "相同 declarations 的 Skill 应相等")
    }

    /// AC2 [P1]: ToolDeclarationStatus enum 定义了 story Task 1.3 规定的全部 4 个 case。
    func testToolDeclarationStatus_AllCases() {
        // Given: ToolDeclarationStatus enum 应可按 rawValue 构造全部 4 个 case
        let recognizedSDK = ToolDeclarationStatus(rawValue: "recognizedSDK")
        let recognizedMCP = ToolDeclarationStatus(rawValue: "recognizedMCP")
        let recognizedCustom = ToolDeclarationStatus(rawValue: "recognizedCustom")
        let unknown = ToolDeclarationStatus(rawValue: "unknown")

        // Then: 全部存在（防止实现遗漏 case）
        XCTAssertNotNil(recognizedSDK, "必须有 .recognizedSDK case")
        XCTAssertNotNil(recognizedMCP, "必须有 .recognizedMCP case")
        XCTAssertNotNil(recognizedCustom, "必须有 .recognizedCustom case")
        XCTAssertNotNil(unknown, "必须有 .unknown case")

        // And: 直接引用 case 也能编译（防止 case 名拼写错误）
        _ = ToolDeclarationStatus.recognizedSDK
        _ = ToolDeclarationStatus.recognizedMCP
        _ = ToolDeclarationStatus.recognizedCustom
        _ = ToolDeclarationStatus.unknown
    }
}

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
}

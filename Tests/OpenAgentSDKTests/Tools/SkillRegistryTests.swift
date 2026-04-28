import XCTest
@testable import OpenAgentSDK

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
// MARK: - SkillRegistry Tests (Story 11.1)

/// Tests for Story 11.1 -- SkillRegistry.
/// Covers: register, find, replace, has, unregister, allSkills,
///         userInvocableSkills, formatSkillsForPrompt, clear, thread safety.
final class SkillRegistryTests: XCTestCase {

    // MARK: - Helper: Create a test skill

    /// Creates a simple skill for testing.
    private func makeSkill(
        name: String = "test_skill",
        description: String = "A test skill",
        aliases: [String] = [],
        userInvocable: Bool = true,
        toolRestrictions: [ToolRestriction]? = nil,
        isAvailable: @escaping @Sendable () -> Bool = { true },
        promptTemplate: String = "Test prompt template"
    ) -> Skill {
        Skill(
            name: name,
            description: description,
            aliases: aliases,
            userInvocable: userInvocable,
            toolRestrictions: toolRestrictions,
            isAvailable: isAvailable,
            promptTemplate: promptTemplate
        )
    }

    // MARK: - AC2: SkillRegistry register and find

    /// AC2 [P0]: Registering a skill and finding it by name.
    func testRegisterAndFind_ByName() {
        // Given: a registry and a skill
        let registry = SkillRegistry()
        let skill = makeSkill(name: "commit", description: "Create a commit")

        // When: registering the skill
        registry.register(skill)

        // Then: find by name returns the skill
        let found = registry.find("commit")
        XCTAssertNotNil(found, "find should return the registered skill")
        XCTAssertEqual(found?.name, "commit")
        XCTAssertEqual(found?.description, "Create a commit")
    }

    /// AC2 [P0]: Finding a skill by alias.
    func testFind_ByAlias() {
        // Given: a registry with a skill that has aliases
        let registry = SkillRegistry()
        let skill = makeSkill(name: "commit", aliases: ["ci"])

        // When: registering the skill
        registry.register(skill)

        // Then: find by alias returns the skill
        let found = registry.find("ci")
        XCTAssertNotNil(found, "find should find skill by alias")
        XCTAssertEqual(found?.name, "commit")
    }

    /// AC2 [P0]: Finding a non-existent skill returns nil.
    func testFind_NonExistent_ReturnsNil() {
        // Given: an empty registry
        let registry = SkillRegistry()

        // When: finding a non-existent skill
        let found = registry.find("nonexistent")

        // Then: returns nil
        XCTAssertNil(found, "find should return nil for non-existent skill")
    }

    /// AC2 [P0]: has() returns true for registered skills.
    func testHas_RegisteredSkill_ReturnsTrue() {
        // Given: a registry with a registered skill
        let registry = SkillRegistry()
        registry.register(makeSkill(name: "commit"))

        // Then: has returns true
        XCTAssertTrue(registry.has("commit"))
    }

    /// AC2 [P0]: has() returns false for non-existent skills.
    func testHas_NonExistentSkill_ReturnsFalse() {
        // Given: an empty registry
        let registry = SkillRegistry()

        // Then: has returns false
        XCTAssertFalse(registry.has("nonexistent"))
    }

    /// AC2 [P1]: Registering multiple skills works correctly.
    func testRegister_MultipleSkills() {
        // Given: a registry
        let registry = SkillRegistry()

        // When: registering multiple skills
        registry.register(makeSkill(name: "commit"))
        registry.register(makeSkill(name: "review"))
        registry.register(makeSkill(name: "simplify"))

        // Then: all are findable
        XCTAssertNotNil(registry.find("commit"))
        XCTAssertNotNil(registry.find("review"))
        XCTAssertNotNil(registry.find("simplify"))
    }

    /// AC2 [P1]: Registering a skill with multiple aliases.
    func testRegister_MultipleAliases() {
        // Given: a skill with multiple aliases
        let registry = SkillRegistry()
        let skill = makeSkill(name: "commit", aliases: ["ci", "gitcommit"])

        // When: registering
        registry.register(skill)

        // Then: all aliases find the skill
        XCTAssertNotNil(registry.find("ci"))
        XCTAssertNotNil(registry.find("gitcommit"))
        XCTAssertEqual(registry.find("ci")?.name, "commit")
        XCTAssertEqual(registry.find("gitcommit")?.name, "commit")
    }

    // MARK: - AC3: SkillRegistry replace method

    /// AC3 [P0]: Replacing a skill updates its definition in the registry.
    func testReplace_UpdatesSkillDefinition() {
        // Given: a registry with a registered skill
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "commit",
            promptTemplate: "Original template"
        ))

        // When: replacing with a new prompt template
        let updatedSkill = makeSkill(
            name: "commit",
            promptTemplate: "Updated template"
        )
        registry.replace(updatedSkill)

        // Then: find returns the updated skill
        let found = registry.find("commit")
        XCTAssertEqual(found?.promptTemplate, "Updated template")
    }

    /// AC3 [P0]: Replace maintains value type semantics -- old references are unaffected.
    func testReplace_ValueTypeIsolation() {
        // Given: a registry with a registered skill
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "commit",
            promptTemplate: "Original"
        ))

        // When: getting a reference to the skill before replace
        let originalSkill = registry.find("commit")!
        XCTAssertEqual(originalSkill.promptTemplate, "Original")

        // And: replacing the skill
        registry.replace(makeSkill(
            name: "commit",
            promptTemplate: "Replaced"
        ))

        // Then: the original variable still holds the old value (value type)
        XCTAssertEqual(originalSkill.promptTemplate, "Original")

        // And: the registry has the new value
        XCTAssertEqual(registry.find("commit")?.promptTemplate, "Replaced")
    }

    /// AC3 [P1]: Replacing a skill with aliases preserves aliases.
    func testReplace_WithAliases() {
        // Given: a registry with a skill with aliases
        let registry = SkillRegistry()
        registry.register(makeSkill(name: "commit", aliases: ["ci"]))

        // When: replacing with a new skill that has different aliases
        registry.replace(makeSkill(name: "commit", aliases: ["ci", "c"]))

        // Then: new aliases work
        XCTAssertNotNil(registry.find("ci"))
        XCTAssertNotNil(registry.find("c"))
        XCTAssertEqual(registry.find("c")?.name, "commit")
    }

    // MARK: - AC4: userInvocableSkills filtering

    /// AC4 [P0]: userInvocableSkills returns only skills with userInvocable=true.
    func testUserInvocableSkills_FiltersNonInvocable() {
        // Given: a registry with 3 skills, 2 user-invocable
        let registry = SkillRegistry()
        registry.register(makeSkill(name: "commit", userInvocable: true))
        registry.register(makeSkill(name: "review", userInvocable: true))
        registry.register(makeSkill(name: "internal_tool", userInvocable: false))

        // When: getting user-invocable skills
        let invocable = registry.userInvocableSkills

        // Then: exactly 2 are returned
        XCTAssertEqual(invocable.count, 2)
        let names = Set(invocable.map(\.name))
        XCTAssertTrue(names.contains("commit"))
        XCTAssertTrue(names.contains("review"))
        XCTAssertFalse(names.contains("internal_tool"))
    }

    /// AC4 [P1]: userInvocableSkills returns empty for empty registry.
    func testUserInvocableSkills_EmptyRegistry() {
        // Given: an empty registry
        let registry = SkillRegistry()

        // Then: userInvocableSkills is empty
        XCTAssertTrue(registry.userInvocableSkills.isEmpty)
    }

    /// AC4 [P1]: userInvocableSkills also filters unavailable skills.
    func testUserInvocableSkills_FiltersUnavailable() {
        // Given: a registry with 2 user-invocable skills, 1 unavailable
        let registry = SkillRegistry()
        registry.register(makeSkill(name: "commit", userInvocable: true, isAvailable: { true }))
        registry.register(makeSkill(name: "test_skill", userInvocable: true, isAvailable: { false }))

        // When: getting user-invocable skills
        let invocable = registry.userInvocableSkills

        // Then: only the available skill is returned
        XCTAssertEqual(invocable.count, 1)
        XCTAssertEqual(invocable.first?.name, "commit")
    }

    // MARK: - AC5: formatSkillsForPrompt text generation

    /// AC5 [P0]: formatSkillsForPrompt generates text with skill names and descriptions.
    func testFormatSkillsForPrompt_ContainsSkillInfo() {
        // Given: a registry with registered skills
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "commit",
            description: "Create a git commit"
        ))
        registry.register(makeSkill(
            name: "review",
            description: "Review code changes"
        ))

        // When: formatting skills for prompt
        let text = registry.formatSkillsForPrompt()

        // Then: text contains skill names and descriptions
        XCTAssertTrue(text.contains("commit"), "Should contain skill name")
        XCTAssertTrue(text.contains("Create a git commit"), "Should contain skill description")
        XCTAssertTrue(text.contains("review"), "Should contain skill name")
        XCTAssertTrue(text.contains("Review code changes"), "Should contain skill description")
    }

    /// AC5 [P0]: formatSkillsForPrompt respects the 500 token budget.
    func testFormatSkillsForPrompt_TokenBudgetLimit() {
        // Given: a registry with many skills that would exceed 500 tokens
        let registry = SkillRegistry()
        for i in 0..<50 {
            registry.register(makeSkill(
                name: "skill_\(i)",
                description: String(repeating: "This is a very long description for skill \(i). ", count: 20),
                promptTemplate: "Template \(i)"
            ))
        }

        // When: formatting skills for prompt
        let text = registry.formatSkillsForPrompt()

        // Then: text is within budget (~2000 chars for 500 tokens at 4 chars/token)
        let estimatedTokens = max(1, text.utf8.count / 4)
        XCTAssertLessThanOrEqual(estimatedTokens, 550,
                                  "formatSkillsForPrompt should respect ~500 token budget (allowing small margin)")
    }

    /// AC5 [P0]: formatSkillsForPrompt only includes user-invocable and available skills.
    func testFormatSkillsForPrompt_OnlyIncludesInvocableAndAvailable() {
        // Given: a registry with a mix of invocable/non-invocable/available/unavailable
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "commit",
            description: "Commit tool",
            userInvocable: true,
            isAvailable: { true }
        ))
        registry.register(makeSkill(
            name: "internal",
            description: "Internal tool",
            userInvocable: false,
            isAvailable: { true }
        ))
        registry.register(makeSkill(
            name: "unavailable",
            description: "Unavailable tool",
            userInvocable: true,
            isAvailable: { false }
        ))

        // When: formatting skills for prompt
        let text = registry.formatSkillsForPrompt()

        // Then: only commit appears
        XCTAssertTrue(text.contains("commit"))
        XCTAssertFalse(text.contains("internal"))
        XCTAssertFalse(text.contains("unavailable"))
    }

    /// AC5 [P1]: formatSkillsForPrompt returns empty string for empty registry.
    func testFormatSkillsForPrompt_EmptyRegistry() {
        // Given: an empty registry
        let registry = SkillRegistry()

        // When: formatting
        let text = registry.formatSkillsForPrompt()

        // Then: returns empty string
        XCTAssertTrue(text.isEmpty)
    }

    /// AC5 [P1]: formatSkillsForPrompt truncates trailing skills when over budget.
    func testFormatSkillsForPrompt_TruncatesTrailingSkills() {
        // Given: a registry with many skills
        let registry = SkillRegistry()
        // Register enough skills to exceed budget
        for i in 0..<30 {
            registry.register(makeSkill(
                name: "skill_\(String(format: "%02d", i))",
                description: String(repeating: "Description for skill \(i). ", count: 10)
            ))
        }

        // When: formatting
        let text = registry.formatSkillsForPrompt()

        // Then: earlier skills are present but later ones may be truncated
        XCTAssertTrue(text.contains("skill_00"), "First skill should be present")
        // The last skill should NOT be present (truncated)
        XCTAssertFalse(text.contains("skill_29"), "Last skill should be truncated when over budget")
    }

    // MARK: - AC6: isAvailable availability filtering

    /// AC6 [P0]: isAvailable=false skills are excluded from userInvocableSkills.
    func testIsAvailable_ExcludedFromUserInvocableSkills() {
        // Given: a registry with an unavailable skill
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "test_skill",
            isAvailable: { false }
        ))

        // When: getting user-invocable skills
        let invocable = registry.userInvocableSkills

        // Then: unavailable skill is excluded
        XCTAssertTrue(invocable.isEmpty, "Unavailable skills should be excluded from userInvocableSkills")
    }

    /// AC6 [P0]: isAvailable=false skills are excluded from formatSkillsForPrompt.
    func testIsAvailable_ExcludedFromFormatSkillsForPrompt() {
        // Given: a registry with an unavailable skill
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "unavailable_skill",
            description: "Should not appear",
            isAvailable: { false }
        ))

        // When: formatting for prompt
        let text = registry.formatSkillsForPrompt()

        // Then: unavailable skill is excluded
        XCTAssertFalse(text.contains("unavailable_skill"))
    }

    /// AC6 [P0]: find() does NOT filter by availability -- returns skill regardless.
    func testIsAvailable_FindDoesNotFilter() {
        // Given: a registry with an unavailable skill
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "test",
            isAvailable: { false }
        ))

        // When: finding the skill
        let found = registry.find("test")

        // Then: skill is found even though unavailable
        XCTAssertNotNil(found, "find should return skill regardless of isAvailable status")
        XCTAssertEqual(found?.name, "test")
    }

    /// AC6 [P1]: find by alias also works for unavailable skills.
    func testIsAvailable_FindByAliasDoesNotFilter() {
        // Given: a registry with an unavailable skill with alias
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "test",
            aliases: ["t"],
            isAvailable: { false }
        ))

        // When: finding by alias
        let found = registry.find("t")

        // Then: skill is found via alias
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "test")
    }

    // MARK: - allSkills and clear

    /// allSkills returns all registered skills.
    func testAllSkills_ReturnsAllRegistered() {
        // Given: a registry with 3 skills
        let registry = SkillRegistry()
        registry.register(makeSkill(name: "commit"))
        registry.register(makeSkill(name: "review"))
        registry.register(makeSkill(name: "internal", userInvocable: false))

        // When: getting all skills
        let all = registry.allSkills

        // Then: all 3 are returned (including non-invocable)
        XCTAssertEqual(all.count, 3)
    }

    /// clear removes all registered skills.
    func testClear_RemovesAllSkills() {
        // Given: a registry with skills
        let registry = SkillRegistry()
        registry.register(makeSkill(name: "commit"))
        registry.register(makeSkill(name: "review"))

        // When: clearing
        registry.clear()

        // Then: all skills are removed
        XCTAssertTrue(registry.allSkills.isEmpty)
        XCTAssertNil(registry.find("commit"))
        XCTAssertNil(registry.find("review"))
    }

    /// unregister removes a specific skill by name.
    func testUnregister_RemovesSpecificSkill() {
        // Given: a registry with skills
        let registry = SkillRegistry()
        registry.register(makeSkill(name: "commit", aliases: ["ci"]))
        registry.register(makeSkill(name: "review"))

        // When: unregistering commit
        let removed = registry.unregister("commit")

        // Then: commit is removed, review remains
        XCTAssertTrue(removed, "unregister should return true for existing skill")
        XCTAssertNil(registry.find("commit"))
        XCTAssertNil(registry.find("ci"), "Alias should also be removed")
        XCTAssertNotNil(registry.find("review"))
    }

    /// unregister returns false for non-existent skill.
    func testUnregister_NonExistent_ReturnsFalse() {
        // Given: an empty registry
        let registry = SkillRegistry()

        // When: unregistering a non-existent skill
        let removed = registry.unregister("nonexistent")

        // Then: returns false
        XCTAssertFalse(removed)
    }

    // MARK: - Thread safety (basic smoke test)

    /// Thread safety: concurrent registrations do not crash.
    func testConcurrentRegistration_DoesNotCrash() {
        // Given: a registry
        let registry = SkillRegistry()
        nonisolated(unsafe) let registryRef = registry

        // When: registering skills concurrently
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            registryRef.register(Skill(
                name: "skill_\(i)",
                description: "test",
                aliases: [],
                userInvocable: true,
                toolRestrictions: nil,
                isAvailable: { true },
                promptTemplate: "test"
            ))
        }

        // Then: all skills are registered without crash
        XCTAssertEqual(registry.allSkills.count, 100)
    }

    /// Thread safety: concurrent reads do not crash.
    func testConcurrentRead_DoesNotCrash() {
        // Given: a registry with skills
        let registry = SkillRegistry()
        for i in 0..<50 {
            registry.register(makeSkill(name: "skill_\(i)"))
        }

        // When: reading concurrently
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            _ = registry.find("skill_\(i % 50)")
            _ = registry.userInvocableSkills
            _ = registry.allSkills
        }

        // Then: no crash (test passes if we get here)
    }
}

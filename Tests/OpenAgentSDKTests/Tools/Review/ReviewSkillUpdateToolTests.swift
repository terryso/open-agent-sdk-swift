import XCTest
@testable import OpenAgentSDK

// MARK: - Mock SkillEvolver

private struct MockSkillEvolver: SkillEvolver, Sendable {
    let result: SkillEvolutionResult

    func evolve(skill: Skill, signals: [SkillSignal], config: SkillEvolutionConfig) async throws -> SkillEvolutionResult {
        result
    }
}

private struct ThrowingSkillEvolver: SkillEvolver, Sendable {
    func evolve(skill: Skill, signals: [SkillSignal], config: SkillEvolutionConfig) async throws -> SkillEvolutionResult {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Evolution failed"])
    }
}

final class ReviewSkillUpdateToolTests: XCTestCase {

    private func makeRegistry(withSkill skill: Skill? = nil) -> SkillRegistry {
        let registry = SkillRegistry()
        if let skill { registry.register(skill) }
        return registry
    }

    private func callTool(
        registry: SkillRegistry,
        evolver: any SkillEvolver,
        skillName: String,
        updates: String,
        reason: String
    ) async -> String {
        let tool = createReviewSkillUpdateTool(skillRegistry: registry, skillEvolver: evolver)
        let input: [String: Any] = [
            "skillName": skillName,
            "updates": updates,
            "reason": reason,
        ]
        let context = ToolContext(cwd: "/tmp")
        let result = await tool.call(input: input, context: context)
        return result.content
    }

    private let sampleSkill = Skill(
        name: "test-skill",
        description: "A test skill",
        userInvocable: false,
        promptTemplate: "Do something useful",
        lifecycleState: .active
    )

    // MARK: - Tests

    func testSuccessfulUpdate() async {
        let registry = makeRegistry(withSkill: sampleSkill)
        let evolvedSkill = Skill(
            name: "test-skill",
            description: "Updated description",
            userInvocable: false,
            promptTemplate: "Do something better",
            lifecycleState: .active
        )
        let evolver = MockSkillEvolver(result: SkillEvolutionResult(
            evolvedSkill: evolvedSkill,
            appliedSignals: [],
            skippedSignals: [],
            changes: ["Updated promptTemplate"]
        ))

        let output = await callTool(
            registry: registry,
            evolver: evolver,
            skillName: "test-skill",
            updates: "{\"promptTemplate\": \"Do something better\"}",
            reason: "Improved instructions"
        )

        XCTAssertTrue(output.contains("\"success\": true"))
        XCTAssertTrue(output.contains("test-skill"))

        let updated = registry.find("test-skill")
        XCTAssertEqual(updated?.promptTemplate, "Do something better")
        XCTAssertEqual(updated?.description, "Updated description")
    }

    func testSkillNotFound() async {
        let registry = makeRegistry()
        let evolver = MockSkillEvolver(result: SkillEvolutionResult(
            evolvedSkill: nil,
            appliedSignals: [],
            skippedSignals: [],
            changes: []
        ))

        let output = await callTool(
            registry: registry,
            evolver: evolver,
            skillName: "nonexistent",
            updates: "{\"description\": \"new\"}",
            reason: "test"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("not found"))
    }

    func testInvalidJsonUpdates() async {
        let registry = makeRegistry(withSkill: sampleSkill)
        let evolver = MockSkillEvolver(result: SkillEvolutionResult(
            evolvedSkill: nil,
            appliedSignals: [],
            skippedSignals: [],
            changes: []
        ))

        let output = await callTool(
            registry: registry,
            evolver: evolver,
            skillName: "test-skill",
            updates: "not valid json {{{",
            reason: "test"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("Invalid JSON"))
    }

    func testEvolverError() async {
        let registry = makeRegistry(withSkill: sampleSkill)
        let evolver = ThrowingSkillEvolver()

        let output = await callTool(
            registry: registry,
            evolver: evolver,
            skillName: "test-skill",
            updates: "{\"description\": \"new\"}",
            reason: "test"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("Evolution failed"))
    }

    func testNoEvolvedSkill() async {
        let registry = makeRegistry(withSkill: sampleSkill)
        let evolver = MockSkillEvolver(result: SkillEvolutionResult(
            evolvedSkill: nil,
            appliedSignals: [],
            skippedSignals: [],
            changes: []
        ))

        let output = await callTool(
            registry: registry,
            evolver: evolver,
            skillName: "test-skill",
            updates: "{\"description\": \"new\"}",
            reason: "no change needed"
        )

        XCTAssertTrue(output.contains("\"success\": true"))
        XCTAssertTrue(output.contains("no changes applied"))
    }

    func testMultipleChangesProducesValidJSONArray() async {
        let registry = makeRegistry(withSkill: sampleSkill)
        let evolvedSkill = Skill(
            name: "test-skill",
            description: "Multi-change skill",
            userInvocable: false,
            promptTemplate: "Updated",
            lifecycleState: .active
        )
        let evolver = MockSkillEvolver(result: SkillEvolutionResult(
            evolvedSkill: evolvedSkill,
            appliedSignals: [],
            skippedSignals: [],
            changes: ["Updated promptTemplate", "Changed description"]
        ))

        let output = await callTool(
            registry: registry,
            evolver: evolver,
            skillName: "test-skill",
            updates: "{\"promptTemplate\": \"Updated\"}",
            reason: "multiple changes"
        )

        XCTAssertTrue(output.contains("\"success\": true"))
        // Verify changes is a valid JSON array with 2 separate elements
        XCTAssertTrue(output.contains("\"Updated promptTemplate\""))
        XCTAssertTrue(output.contains("\"Changed description\""))
        // Should NOT be a single concatenated string
        XCTAssertFalse(output.contains("Updated promptTemplate, Changed description"))
    }

    func testEmptySkillName() async {
        let registry = makeRegistry()
        let evolver = MockSkillEvolver(result: SkillEvolutionResult(
            evolvedSkill: nil, appliedSignals: [], skippedSignals: [], changes: []
        ))

        let output = await callTool(
            registry: registry,
            evolver: evolver,
            skillName: "  ",
            updates: "{\"description\": \"new\"}",
            reason: "test"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("must not be empty"))
    }
}

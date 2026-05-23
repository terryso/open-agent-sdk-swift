import XCTest
@testable import OpenAgentSDK

private struct MockEvolver: SkillEvolver, Sendable {
    func evolve(skill: Skill, signals: [SkillSignal], config: SkillEvolutionConfig) async throws -> SkillEvolutionResult {
        SkillEvolutionResult(evolvedSkill: nil, appliedSignals: [], skippedSignals: [], changes: [])
    }
}

final class ReviewToolsTests: XCTestCase {

    func testCreateReviewToolsReturnsFourTools() async {
        let factStore = FactStore(memoryDir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path)
        let registry = SkillRegistry()
        let evolver = MockEvolver()

        let tools = createReviewTools(
            factStore: factStore,
            skillRegistry: registry,
            skillEvolver: evolver
        )

        XCTAssertEqual(tools.count, 4)

        let names = tools.map(\.name)
        XCTAssertTrue(names.contains("review_save_memory"), "Missing review_save_memory")
        XCTAssertTrue(names.contains("review_update_skill"), "Missing review_update_skill")
        XCTAssertTrue(names.contains("review_create_skill"), "Missing review_create_skill")
        XCTAssertTrue(names.contains("review_add_skill_file"), "Missing review_add_skill_file")
    }

    func testAllToolsAreToolProtocol() async {
        let factStore = FactStore(memoryDir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path)
        let registry = SkillRegistry()
        let evolver = MockEvolver()

        let tools = createReviewTools(
            factStore: factStore,
            skillRegistry: registry,
            skillEvolver: evolver
        )

        for tool in tools {
            XCTAssertFalse(tool.name.isEmpty, "Tool name should not be empty")
            XCTAssertFalse(tool.description.isEmpty, "Tool description should not be empty")
            XCTAssertNotNil(tool.inputSchema, "Tool should have an input schema")
        }
    }
}

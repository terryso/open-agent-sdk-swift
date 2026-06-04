import XCTest
@testable import OpenAgentSDK

private struct MockEvolver: SkillEvolver, Sendable {
    func evolve(skill: Skill, signals: [SkillSignal], config: SkillEvolutionConfig) async throws -> SkillEvolutionResult {
        SkillEvolutionResult(evolvedSkill: nil, appliedSignals: [], skippedSignals: [], changes: [])
    }
}

final class ReviewToolsTests: XCTestCase {

    func testCreateReviewToolsReturnsFiveTools() async {
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
        let factStore = FactStore(memoryDir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path)
        let registry = SkillRegistry()
        let evolver = MockEvolver()
        let usageStore = SkillUsageStore(skillsDir: tempDir)

        let tools = createReviewTools(
            factStore: factStore,
            skillRegistry: registry,
            skillEvolver: evolver,
            usageStore: usageStore,
            skillsDir: tempDir
        )

        XCTAssertEqual(tools.count, 5)

        let names = tools.map(\.name)
        XCTAssertTrue(names.contains("review_save_memory"), "Missing review_save_memory")
        XCTAssertTrue(names.contains("review_update_skill"), "Missing review_update_skill")
        XCTAssertTrue(names.contains("review_create_skill"), "Missing review_create_skill")
        XCTAssertTrue(names.contains("review_add_skill_file"), "Missing review_add_skill_file")
        XCTAssertTrue(names.contains("curator_archive_skill"), "Missing curator_archive_skill")
    }

    func testAllToolsAreToolProtocol() async {
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent(UUID().uuidString)
        let factStore = FactStore(memoryDir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path)
        let registry = SkillRegistry()
        let evolver = MockEvolver()
        let usageStore = SkillUsageStore(skillsDir: tempDir)

        let tools = createReviewTools(
            factStore: factStore,
            skillRegistry: registry,
            skillEvolver: evolver,
            usageStore: usageStore,
            skillsDir: tempDir
        )

        for tool in tools {
            XCTAssertFalse(tool.name.isEmpty, "Tool name should not be empty")
            XCTAssertFalse(tool.description.isEmpty, "Tool description should not be empty")
            XCTAssertNotNil(tool.inputSchema, "Tool should have an input schema")
        }
    }
}

import XCTest
@testable import OpenAgentSDK

final class CuratorArchiveToolTests: TempDirTestCase {

    private func makeStore() -> SkillUsageStore {
        SkillUsageStore(skillsDir: tempDir)
    }

    private func callTool(
        registry: SkillRegistry,
        store: SkillUsageStore,
        skillName: String,
        absorbedInto: String? = nil
    ) async -> String {
        let tool = createCuratorArchiveTool(skillRegistry: registry, usageStore: store, skillsDir: "/tmp/test-skills-(UUID().uuidString)")
        var input: [String: Any] = ["skillName": skillName]
        if let absorbedInto { input["absorbedInto"] = absorbedInto }
        let context = ToolContext(cwd: "/tmp")
        let result = await tool.call(input: input, context: context)
        return result.content
    }

    // MARK: - Tests

    func testArchiveSuccess() async throws {
        let registry = SkillRegistry()
        let store = makeStore()

        let skill = Skill(
            name: "test-skill",
            description: "A test skill",
            promptTemplate: "template"
        )
        registry.register(skill)
        try await store.setUsage(skillName: "test-skill", data: SkillUsageData(
            skillName: "test-skill",
            provenance: .agentCreated
        ))

        let output = await callTool(registry: registry, store: store, skillName: "test-skill")

        XCTAssertTrue(output.contains("\"success\":true"))
        XCTAssertTrue(output.contains("test-skill"))
        XCTAssertTrue(output.contains("archived"))

        let archived = registry.find("test-skill")
        XCTAssertNil(archived, "Skill should be unregistered after archive")

        let usage = await store.getUsage(skillName: "test-skill")
        XCTAssertNotNil(usage.lastManagedAt)
    }

    func testArchiveWithAbsorbedInto() async throws {
        let registry = SkillRegistry()
        let store = makeStore()

        let skill = Skill(
            name: "old-skill",
            description: "Old skill",
            promptTemplate: "template"
        )
        registry.register(skill)
        try await store.setUsage(skillName: "old-skill", data: SkillUsageData(
            skillName: "old-skill",
            provenance: .agentCreated
        ))

        let output = await callTool(
            registry: registry,
            store: store,
            skillName: "old-skill",
            absorbedInto: "umbrella-skill"
        )

        XCTAssertTrue(output.contains("\"success\":true"))
        XCTAssertTrue(output.contains("umbrella-skill"))

        let usage = await store.getUsage(skillName: "old-skill")
        XCTAssertEqual(usage.absorbedInto, "umbrella-skill")
    }

    func testArchiveWithoutAbsorbedInto() async throws {
        let registry = SkillRegistry()
        let store = makeStore()

        let skill = Skill(
            name: "pruned-skill",
            description: "Pruned skill",
            promptTemplate: "template"
        )
        registry.register(skill)
        try await store.setUsage(skillName: "pruned-skill", data: SkillUsageData(
            skillName: "pruned-skill",
            provenance: .agentCreated
        ))

        let output = await callTool(registry: registry, store: store, skillName: "pruned-skill")

        XCTAssertTrue(output.contains("\"success\":true"))

        let usage = await store.getUsage(skillName: "pruned-skill")
        XCTAssertNil(usage.absorbedInto)
    }

    func testRejectsNonAgentCreated() async throws {
        let registry = SkillRegistry()
        let store = makeStore()

        let skill = Skill(
            name: "bundled-skill",
            description: "Bundled skill",
            promptTemplate: "template"
        )
        registry.register(skill)
        try await store.setUsage(skillName: "bundled-skill", data: SkillUsageData(
            skillName: "bundled-skill",
            provenance: .bundled
        ))

        let output = await callTool(registry: registry, store: store, skillName: "bundled-skill")

        XCTAssertTrue(output.contains("\"success\":false"))
        XCTAssertTrue(output.contains("Cannot archive non-agent-created skill"))
    }

    func testRejectsPinned() async throws {
        let registry = SkillRegistry()
        let store = makeStore()

        let skill = Skill(
            name: "pinned-skill",
            description: "Pinned skill",
            promptTemplate: "template"
        )
        registry.register(skill)
        try await store.setUsage(skillName: "pinned-skill", data: SkillUsageData(
            skillName: "pinned-skill",
            pinned: true,
            provenance: .agentCreated
        ))

        let output = await callTool(registry: registry, store: store, skillName: "pinned-skill")

        XCTAssertTrue(output.contains("\"success\":false"))
        XCTAssertTrue(output.contains("Cannot archive pinned skill"))
    }

    func testRejectsNonExistentSkill() async throws {
        let registry = SkillRegistry()
        let store = makeStore()

        try await store.setUsage(skillName: "ghost-skill", data: SkillUsageData(
            skillName: "ghost-skill",
            provenance: .agentCreated
        ))

        let output = await callTool(registry: registry, store: store, skillName: "ghost-skill")

        XCTAssertTrue(output.contains("\"success\":false"))
        XCTAssertTrue(output.contains("not found"))
    }

    func testRejectsEmptySkillName() async {
        let registry = SkillRegistry()
        let store = makeStore()

        let output = await callTool(registry: registry, store: store, skillName: "  ")

        XCTAssertTrue(output.contains("\"success\":false"))
        XCTAssertTrue(output.contains("must not be empty"))
    }

    func testRejectsUnknownProvenance() async {
        let registry = SkillRegistry()
        let store = makeStore()

        let skill = Skill(
            name: "unknown-skill",
            description: "Skill with no usage data",
            promptTemplate: "template"
        )
        registry.register(skill)

        let output = await callTool(registry: registry, store: store, skillName: "unknown-skill")

        XCTAssertTrue(output.contains("\"success\":false"))
        XCTAssertTrue(output.contains("Cannot archive non-agent-created skill"))
    }
}

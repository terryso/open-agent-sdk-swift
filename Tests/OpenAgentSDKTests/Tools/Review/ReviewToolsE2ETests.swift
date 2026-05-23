import XCTest
@testable import OpenAgentSDK

// MARK: - Mock SkillEvolver for E2E Tests

private struct E2EEvolver: SkillEvolver, Sendable {
    let evolvedSkill: Skill?

    func evolve(skill: Skill, signals: [SkillSignal], config: SkillEvolutionConfig) async throws -> SkillEvolutionResult {
        SkillEvolutionResult(
            evolvedSkill: evolvedSkill,
            appliedSignals: signals,
            skippedSignals: [],
            changes: evolvedSkill != nil ? ["Updated via E2E evolver"] : []
        )
    }
}

// MARK: - E2E Integration Tests for Story 24.2 Review Tools

final class ReviewToolsE2ETests: XCTestCase {

    // MARK: - Helpers

    private var tmpDirs: [URL] = []

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        tmpDirs.append(dir)
        return dir
    }

    override func tearDown() {
        super.tearDown()
        for dir in tmpDirs {
            try? FileManager.default.removeItem(at: dir)
        }
        tmpDirs.removeAll()
    }

    private func makeToolSet(
        evolvedSkill: Skill? = nil
    ) -> (tools: [ToolProtocol], factStore: FactStore, registry: SkillRegistry, tmpDir: URL) {
        let tmpDir = makeTempDir()
        let factStore = FactStore(memoryDir: tmpDir.appendingPathComponent("facts").path)
        let registry = SkillRegistry()
        let evolver = E2EEvolver(evolvedSkill: evolvedSkill)
        let tools = createReviewTools(factStore: factStore, skillRegistry: registry, skillEvolver: evolver)
        return (tools, factStore, registry, tmpDir)
    }

    private func callTool(
        _ tools: [ToolProtocol],
        name: String,
        input: [String: Any],
        toolUseId: String = "toolu_e2e_001"
    ) async -> ToolResult {
        guard let tool = tools.first(where: { $0.name == name }) else {
            XCTFail("Tool '\(name)' not found in tool set")
            return ToolResult(toolUseId: "error", content: "not found", isError: true)
        }
        let context = ToolContext(cwd: "/tmp", toolUseId: toolUseId)
        return await tool.call(input: input, context: context)
    }

    // MARK: - Tool Name Alignment

    func testToolNamesMatchReviewAgentConfigAllowedTools() async {
        let (tools, _, _, _) = makeToolSet()
        let toolNames = Set(tools.map(\.name))
        let expectedNames = Set(ReviewAgentConfig().allowedTools)

        XCTAssertEqual(toolNames, expectedNames,
            "createReviewTools() must produce tools matching ReviewAgentConfig.allowedTools defaults")
    }

    // MARK: - Full Pipeline: Save Memory → Verify in FactStore

    func testE2E_SaveMemory_PersistsToFactStore() async throws {
        let (tools, factStore, _, _) = makeToolSet()

        let result = await callTool(tools, name: "review_save_memory", input: [
            "domain": "testing",
            "content": "Always use temp directories for file-based tests",
            "kind": "affordance",
            "confidence": 0.95,
        ])

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("\"success\": true"))
        XCTAssertTrue(result.content.contains("testing"))

        let facts = try await factStore.query(domain: "testing")
        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts.first?.content, "Always use temp directories for file-based tests")
        XCTAssertEqual(facts.first?.kind, .affordance)
        XCTAssertEqual(facts.first?.confidence, 0.95)
    }

    // MARK: - Full Pipeline: Create Skill → Verify in SkillRegistry

    func testE2E_CreateSkill_RegistersInSkillRegistry() async {
        let (tools, _, registry, _) = makeToolSet()

        let result = await callTool(tools, name: "review_create_skill", input: [
            "name": "review-e2e-skill",
            "description": "Skill created by E2E test",
            "promptTemplate": "Analyze {{content}} for quality issues",
            "whenToUse": "When reviewing content quality",
        ])

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("\"success\": true"))

        let skill = registry.find("review-e2e-skill")
        XCTAssertNotNil(skill)
        XCTAssertEqual(skill?.description, "Skill created by E2E test")
        XCTAssertFalse(skill!.userInvocable)
        XCTAssertEqual(skill?.lifecycleState, .active)
    }

    // MARK: - Cross-Tool Workflow: Create → Update → Add File

    func testE2E_CreateUpdateAddFileWorkflow() async throws {
        let updatedSkill = Skill(
            name: "workflow-skill",
            description: "Updated description from evolution",
            userInvocable: false,
            promptTemplate: "Enhanced analysis of {{content}}",
            baseDir: makeTempDir().path,
            lifecycleState: .active
        )
        let (tools, _, registry, _) = makeToolSet(evolvedSkill: updatedSkill)

        // Step 1: Create the skill
        let createResult = await callTool(tools, name: "review_create_skill", input: [
            "name": "workflow-skill",
            "description": "Initial description",
            "promptTemplate": "Basic template",
        ], toolUseId: "toolu_step1")
        XCTAssertFalse(createResult.isError)

        // Step 2: Update the skill via evolver
        let updateResult = await callTool(tools, name: "review_update_skill", input: [
            "skillName": "workflow-skill",
            "updates": "{\"description\": \"Updated description from evolution\"}",
            "reason": "E2E workflow test update",
        ], toolUseId: "toolu_step2")
        XCTAssertFalse(updateResult.isError)
        XCTAssertTrue(updateResult.content.contains("\"success\": true"))

        // Verify skill was replaced by evolver result
        let evolved = registry.find("workflow-skill")
        XCTAssertEqual(evolved?.description, "Updated description from evolution")
        XCTAssertEqual(evolved?.promptTemplate, "Enhanced analysis of {{content}}")

        // Step 3: Add a file to the skill
        let fileResult = await callTool(tools, name: "review_add_skill_file", input: [
            "skillName": "workflow-skill",
            "filePath": "references/workflow-guide.md",
            "content": "# Workflow Guide\n\nThis guide documents the E2E workflow.",
        ], toolUseId: "toolu_step3")
        XCTAssertFalse(fileResult.isError)
        XCTAssertTrue(fileResult.content.contains("\"success\": true"))
    }

    // MARK: - Cross-Tool Workflow: Save Memory + Create Skill

    func testE2E_SaveMemoryAndCreateSkillInSequence() async throws {
        let (tools, factStore, registry, _) = makeToolSet()

        // Save a memory fact
        let memoryResult = await callTool(tools, name: "review_save_memory", input: [
            "domain": "code-review",
            "content": "Prefer early returns over nested if-else blocks",
            "kind": "affordance",
        ], toolUseId: "toolu_mem_001")
        XCTAssertFalse(memoryResult.isError)

        // Create a skill based on the observation
        let skillResult = await callTool(tools, name: "review_create_skill", input: [
            "name": "code-review-patterns",
            "description": "Common code review patterns and preferences",
            "promptTemplate": "Check {{code}} for early return opportunities",
        ], toolUseId: "toolu_skill_001")
        XCTAssertFalse(skillResult.isError)

        // Verify both side effects
        let facts = try await factStore.query(domain: "code-review")
        XCTAssertEqual(facts.count, 1)

        let skill = registry.find("code-review-patterns")
        XCTAssertNotNil(skill)
    }

    // MARK: - ToolResult Structure Verification

    func testE2E_ToolResultContainsCorrectToolUseId() async {
        let (tools, _, _, _) = makeToolSet()

        let result = await callTool(tools, name: "review_save_memory", input: [
            "domain": "test",
            "content": "content",
            "kind": "observation",
        ], toolUseId: "toolu_custom_id_123")

        XCTAssertEqual(result.toolUseId, "toolu_custom_id_123")
    }

    func testE2E_ErrorResultHasCorrectStructure() async {
        let (tools, _, _, _) = makeToolSet()

        let result = await callTool(tools, name: "review_save_memory", input: [
            "domain": "test",
            "content": "content",
            "kind": "bad_kind",
        ], toolUseId: "toolu_err_001")

        // Tool returns domain error JSON, but the tool framework doesn't set isError
        // because the execute closure returns a string (not throws). The error is in the content.
        XCTAssertTrue(result.content.contains("\"success\": false"))
        XCTAssertTrue(result.content.contains("Invalid kind"))
        XCTAssertTrue(result.content.contains("bad_kind"))
    }

    func testE2E_MissingRequiredField_ReturnsDecodeError() async {
        let (tools, _, _, _) = makeToolSet()

        // Missing "kind" field which is required
        let result = await callTool(tools, name: "review_save_memory", input: [
            "domain": "test",
            "content": "content",
        ], toolUseId: "toolu_missing_001")

        XCTAssertTrue(result.isError, "Missing required field should produce isError=true from CodableTool")
    }

    // MARK: - Error Cascading Across Tools

    func testE2E_UpdateNonexistentSkill_ReturnsError() async {
        let (tools, _, _, _) = makeToolSet()

        let result = await callTool(tools, name: "review_update_skill", input: [
            "skillName": "ghost-skill",
            "updates": "{\"description\": \"new\"}",
            "reason": "testing nonexistent",
        ])

        XCTAssertTrue(result.content.contains("\"success\": false"))
        XCTAssertTrue(result.content.contains("not found"))
    }

    func testE2E_AddFileToNonexistentSkill_ReturnsError() async {
        let (tools, _, _, _) = makeToolSet()

        let result = await callTool(tools, name: "review_add_skill_file", input: [
            "skillName": "phantom-skill",
            "filePath": "references/guide.md",
            "content": "content",
        ])

        XCTAssertTrue(result.content.contains("\"success\": false"))
        XCTAssertTrue(result.content.contains("not found"))
    }

    // MARK: - Input Schema Validation

    func testE2E_AllToolsHaveNonEmptySchemas() async {
        let (tools, _, _, _) = makeToolSet()

        for tool in tools {
            XCTAssertNotNil(tool.inputSchema, "\(tool.name) should have an inputSchema")
            XCTAssertEqual(tool.inputSchema["type"] as? String, "object",
                "\(tool.name) schema should have type 'object'")
            XCTAssertNotNil(tool.inputSchema["properties"] as? [String: Any],
                "\(tool.name) schema should have properties")
            XCTAssertNotNil(tool.inputSchema["required"] as? [String],
                "\(tool.name) schema should have required fields")
        }
    }

    // MARK: - Multiple Memories in Same Domain

    func testE2E_SaveMultipleFactsToSameDomain() async throws {
        let (tools, factStore, _, _) = makeToolSet()

        for (i, kind) in ["affordance", "avoid", "observation"].enumerated() {
            let result = await callTool(tools, name: "review_save_memory", input: [
                "domain": "multi-test",
                "content": "\(kind) fact #\(i)",
                "kind": kind,
            ], toolUseId: "toolu_multi_\(i)")
            XCTAssertFalse(result.isError)
        }

        let facts = try await factStore.query(domain: "multi-test")
        XCTAssertEqual(facts.count, 3)
    }

    // MARK: - Skill Creation Defaults Verification

    func testE2E_CreatedSkillHasCorrectDefaults() async {
        let (tools, _, registry, _) = makeToolSet()

        _ = await callTool(tools, name: "review_create_skill", input: [
            "name": "defaults-test",
            "description": "Test defaults",
            "promptTemplate": "Template only",
        ])

        let skill = registry.find("defaults-test")
        XCTAssertNotNil(skill)
        XCTAssertEqual(skill?.aliases, [])
        XCTAssertFalse(skill!.userInvocable)
        XCTAssertEqual(skill?.lifecycleState, .active)
        XCTAssertNil(skill?.whenToUse)
    }

    // MARK: - File Tool Path Validation End-to-End

    func testE2E_FileToolRejectsInvalidPath() async {
        let baseDir = makeTempDir().path
        let (tools, _, registry, _) = makeToolSet()
        registry.register(Skill(
            name: "path-test-skill",
            description: "test",
            promptTemplate: "t",
            baseDir: baseDir
        ))

        let result = await callTool(tools, name: "review_add_skill_file", input: [
            "skillName": "path-test-skill",
            "filePath": "malicious/../../../etc/passwd",
            "content": "evil",
        ])

        XCTAssertTrue(result.content.contains("\"success\": false"))
        XCTAssertTrue(result.content.contains("Invalid file path"))
    }

    func testE2E_FileToolRejectsPathTraversal() async {
        let baseDir = makeTempDir().path
        let (tools, _, registry, _) = makeToolSet()
        registry.register(Skill(
            name: "traversal-skill",
            description: "test",
            promptTemplate: "t",
            baseDir: baseDir
        ))

        // references/../../etc/passwd starts with valid prefix but escapes via ..
        let result = await callTool(tools, name: "review_add_skill_file", input: [
            "skillName": "traversal-skill",
            "filePath": "references/../../etc/passwd",
            "content": "evil",
        ])

        XCTAssertTrue(result.content.contains("\"success\": false"))
        XCTAssertTrue(result.content.contains("Path traversal"))
    }

    func testE2E_FileToolAcceptsAllValidPrefixes() async throws {
        let baseDir = makeTempDir().path
        let (tools, _, registry, _) = makeToolSet()
        registry.register(Skill(
            name: "prefix-skill",
            description: "test",
            promptTemplate: "t",
            baseDir: baseDir
        ))

        for prefix in ["references/", "templates/", "scripts/"] {
            let result = await callTool(tools, name: "review_add_skill_file", input: [
                "skillName": "prefix-skill",
                "filePath": "\(prefix)test.txt",
                "content": "content for \(prefix)",
            ], toolUseId: "toolu_prefix_\(prefix)")

            XCTAssertFalse(result.isError, "Should accept prefix: \(prefix)")
            XCTAssertTrue(result.content.contains("\"success\": true"))
        }
    }
}

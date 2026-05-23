import XCTest
@testable import OpenAgentSDK

final class ReviewSkillFileToolTests: XCTestCase {

    private func callTool(
        registry: SkillRegistry,
        skillName: String,
        filePath: String,
        content: String
    ) async -> String {
        let tool = createReviewSkillFileTool(skillRegistry: registry)
        let input: [String: Any] = [
            "skillName": skillName,
            "filePath": filePath,
            "content": content,
        ]
        let context = ToolContext(cwd: "/tmp")
        let result = await tool.call(input: input, context: context)
        return result.content
    }

    private func makeRegistryWithSkill(name: String, baseDir: String?) -> (SkillRegistry, URL?) {
        let registry = SkillRegistry()
        var tmpDir: URL?
        if let baseDir {
            tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        }
        let skill = Skill(
            name: name,
            description: "Test skill",
            promptTemplate: "template",
            baseDir: baseDir ?? tmpDir?.path
        )
        registry.register(skill)
        return (registry, tmpDir)
    }

    // MARK: - Tests

    func testSuccessfulFileWrite() async {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        let registry = SkillRegistry()
        registry.register(Skill(
            name: "file-skill",
            description: "Test skill",
            promptTemplate: "template",
            baseDir: dir.path
        ))

        let output = await callTool(
            registry: registry,
            skillName: "file-skill",
            filePath: "references/guide.md",
            content: "# Guide\n\nThis is a reference guide."
        )

        XCTAssertTrue(output.contains("\"success\": true"))
        XCTAssertTrue(output.contains("file-skill"))

        let filePath = dir.appendingPathComponent("references/guide.md").path
        let content = try? String(contentsOfFile: filePath)
        XCTAssertNotNil(content)
        XCTAssertTrue(content?.contains("# Guide") == true)
    }

    func testInvalidPrefix() async {
        let (registry, tmpDir) = makeRegistryWithSkill(name: "file-skill", baseDir: nil)
        defer { if let d = tmpDir { try? FileManager.default.removeItem(at: d) } }

        let output = await callTool(
            registry: registry,
            skillName: "file-skill",
            filePath: "outside/references/guide.md",
            content: "content"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("Invalid file path"))
    }

    func testAllValidPrefixes() async {
        let prefixes = ["references/", "templates/", "scripts/"]
        for prefix in prefixes {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            let registry = SkillRegistry()
            registry.register(Skill(
                name: "prefix-test",
                description: "test",
                promptTemplate: "t",
                baseDir: dir.path
            ))
            defer { try? FileManager.default.removeItem(at: dir) }

            let output = await callTool(
                registry: registry,
                skillName: "prefix-test",
                filePath: "\(prefix)test.txt",
                content: "content for \(prefix)"
            )

            XCTAssertTrue(output.contains("\"success\": true"), "Failed for prefix: \(prefix)")
        }
    }

    func testSkillNotFound() async {
        let registry = SkillRegistry()

        let output = await callTool(
            registry: registry,
            skillName: "nonexistent",
            filePath: "references/guide.md",
            content: "content"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("not found"))
    }

    func testPathTraversal() async {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        let registry = SkillRegistry()
        registry.register(Skill(
            name: "traversal-skill",
            description: "Test skill",
            promptTemplate: "template",
            baseDir: dir.path
        ))

        let output = await callTool(
            registry: registry,
            skillName: "traversal-skill",
            filePath: "references/../../etc/passwd",
            content: "malicious"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("Path traversal"))
    }

    func testBaseDirIsNil() async {
        let registry = SkillRegistry()
        registry.register(Skill(
            name: "no-dir-skill",
            description: "No baseDir",
            promptTemplate: "template",
            baseDir: nil
        ))

        let output = await callTool(
            registry: registry,
            skillName: "no-dir-skill",
            filePath: "references/guide.md",
            content: "content"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("no base directory"))
    }

    func testEmptySkillName() async {
        let registry = SkillRegistry()

        let output = await callTool(
            registry: registry,
            skillName: "  ",
            filePath: "references/guide.md",
            content: "content"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("must not be empty"))
    }

    func testEmptyFilePath() async {
        let registry = SkillRegistry()
        registry.register(Skill(
            name: "test-skill",
            description: "Test",
            promptTemplate: "t",
            baseDir: nil
        ))

        let output = await callTool(
            registry: registry,
            skillName: "test-skill",
            filePath: "  ",
            content: "content"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("must not be empty"))
    }
}

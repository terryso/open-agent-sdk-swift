import XCTest
@testable import OpenAgentSDK

final class ReviewSkillCreateToolTests: XCTestCase {

    private func callTool(
        registry: SkillRegistry,
        name: String,
        description: String,
        promptTemplate: String,
        whenToUse: String? = nil
    ) async -> String {
        let tool = createReviewSkillCreateTool(skillRegistry: registry)
        var input: [String: Any] = [
            "name": name,
            "description": description,
            "promptTemplate": promptTemplate,
        ]
        if let whenToUse { input["whenToUse"] = whenToUse }
        let context = ToolContext(cwd: "/tmp")
        let result = await tool.call(input: input, context: context)
        return result.content
    }

    // MARK: - Tests

    func testSuccessfulCreation() async {
        let registry = SkillRegistry()

        let output = await callTool(
            registry: registry,
            name: "my-review-skill",
            description: "A skill created by review",
            promptTemplate: "Analyze and improve {{content}}",
            whenToUse: "When reviewing content"
        )

        XCTAssertTrue(output.contains("\"success\": true"))
        XCTAssertTrue(output.contains("my-review-skill"))

        let skill = registry.find("my-review-skill")
        XCTAssertNotNil(skill)
        XCTAssertEqual(skill?.description, "A skill created by review")
        XCTAssertEqual(skill?.promptTemplate, "Analyze and improve {{content}}")
        XCTAssertEqual(skill?.whenToUse, "When reviewing content")
        XCTAssertEqual(skill?.aliases, [])
        XCTAssertFalse(skill!.userInvocable)
        XCTAssertEqual(skill?.lifecycleState, .active)
    }

    func testDuplicateNameError() async {
        let registry = SkillRegistry()
        registry.register(Skill(
            name: "existing-skill",
            description: "Already exists",
            promptTemplate: "template"
        ))

        let output = await callTool(
            registry: registry,
            name: "existing-skill",
            description: "Trying to create duplicate",
            promptTemplate: "new template"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("already exists"))
    }

    func testCreationWithoutOptionalFields() async {
        let registry = SkillRegistry()

        let output = await callTool(
            registry: registry,
            name: "minimal-skill",
            description: "Minimal skill",
            promptTemplate: "Do something"
        )

        XCTAssertTrue(output.contains("\"success\": true"))

        let skill = registry.find("minimal-skill")
        XCTAssertNotNil(skill)
        XCTAssertNil(skill?.whenToUse)
    }

    func testEmptyName() async {
        let registry = SkillRegistry()

        let output = await callTool(
            registry: registry,
            name: "  ",
            description: "valid",
            promptTemplate: "template"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("must not be empty"))
    }

    func testEmptyDescription() async {
        let registry = SkillRegistry()

        let output = await callTool(
            registry: registry,
            name: "my-skill",
            description: "  ",
            promptTemplate: "template"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("must not be empty"))
    }

    func testEmptyPromptTemplate() async {
        let registry = SkillRegistry()

        let output = await callTool(
            registry: registry,
            name: "my-skill",
            description: "valid",
            promptTemplate: "  "
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("must not be empty"))
    }
}

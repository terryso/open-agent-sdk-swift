import Foundation

// MARK: - ReviewSkillCreateInput

private struct ReviewSkillCreateInput: Codable {
    let name: String
    let description: String
    let promptTemplate: String
    let whenToUse: String?
}

// MARK: - createReviewSkillCreateTool

/// Creates the `review_create_skill` tool for the forked review agent.
///
/// Checks for duplicate names, constructs a `Skill` with review-appropriate defaults
/// (`userInvocable: false`, `lifecycleState: .active`), and registers it.
///
/// - Parameter skillRegistry: The registry to register new skills into.
/// - Returns: A `ToolProtocol` instance named `review_create_skill`.
public func createReviewSkillCreateTool(skillRegistry: SkillRegistry) -> ToolProtocol {
    defineTool(
        name: "review_create_skill",
        description: "Create a new background knowledge skill from the conversation review. Review-created skills are not directly user-invocable.",
        inputSchema: [
            "type": "object",
            "properties": [
                "name": ["type": "string", "description": "Unique name for the new skill"],
                "description": ["type": "string", "description": "Human-readable description of what the skill does"],
                "promptTemplate": ["type": "string", "description": "The prompt template for the skill"],
                "whenToUse": ["type": "string", "description": "Optional description of when to use this skill"]
            ],
            "required": ["name", "description", "promptTemplate"]
        ]
    ) { (input: ReviewSkillCreateInput, _: ToolContext) -> String in
        guard !input.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "{\"success\": false, \"error\": \"'name' must not be empty\"}"
        }
        guard !input.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "{\"success\": false, \"error\": \"'description' must not be empty\"}"
        }
        guard !input.promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "{\"success\": false, \"error\": \"'promptTemplate' must not be empty\"}"
        }
        if skillRegistry.has(input.name) {
            return "{\"success\": false, \"error\": \"Skill '\(input.name)' already exists\"}"
        }

        let skill = Skill(
            name: input.name,
            description: input.description,
            aliases: [],
            userInvocable: false,
            promptTemplate: input.promptTemplate,
            whenToUse: input.whenToUse,
            lifecycleState: .active
        )
        skillRegistry.register(skill)

        return "{\"success\": true, \"message\": \"Skill '\(input.name)' created\"}"
    }
}

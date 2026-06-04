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
/// (`userInvocable: false`, `lifecycleState: .active`), writes it to disk as `SKILL.md`,
/// registers it in the skill registry, and marks provenance as `.agentCreated`.
///
/// - Parameters:
///   - skillRegistry: The registry to register new skills into.
///   - usageStore: The store for persisting usage/provenance data.
///   - skillsDir: Root directory for skill storage.
/// - Returns: A `ToolProtocol` instance named `review_create_skill`.
public func createReviewSkillCreateTool(
    skillRegistry: SkillRegistry,
    usageStore: SkillUsageStore,
    skillsDir: String
) -> ToolProtocol {
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
    ) { (input: ReviewSkillCreateInput, _: ToolContext) async -> String in
        guard !input.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return reviewJSONResponse(["success": false, "error": "'name' must not be empty"] as [String: Any])
        }
        guard !input.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return reviewJSONResponse(["success": false, "error": "'description' must not be empty"] as [String: Any])
        }
        guard !input.promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return reviewJSONResponse(["success": false, "error": "'promptTemplate' must not be empty"] as [String: Any])
        }
        if skillRegistry.has(input.name) {
            return reviewJSONResponse([
                "success": false,
                "error": "Skill '\(input.name)' already exists"
            ] as [String: Any])
        }

        do {
            let skillDir = try SkillWriter.write(
                skill: Skill(
                    name: input.name,
                    description: input.description,
                    aliases: [],
                    userInvocable: false,
                    promptTemplate: input.promptTemplate,
                    whenToUse: input.whenToUse,
                    lifecycleState: .active
                ),
                to: skillsDir
            )

            let registeredSkill = Skill(
                name: input.name,
                description: input.description,
                aliases: [],
                userInvocable: false,
                promptTemplate: input.promptTemplate,
                whenToUse: input.whenToUse,
                baseDir: skillDir,
                lifecycleState: .active
            )
            skillRegistry.register(registeredSkill)

            try await usageStore.setProvenance(skillName: input.name, provenance: .agentCreated)

            return reviewJSONResponse([
                "success": true,
                "message": "Skill '\(input.name)' created and saved",
                "path": skillDir,
            ] as [String: Any])
        } catch {
            return reviewJSONResponse([
                "success": false,
                "error": "Failed to persist skill: \(error.localizedDescription)",
            ] as [String: Any])
        }
    }
}

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
        if let err = requireNonEmptyInput(input.name, field: "name") { return err }
        if let err = requireNonEmptyInput(input.description, field: "description") { return err }
        if let err = requireNonEmptyInput(input.promptTemplate, field: "promptTemplate") { return err }
        if skillRegistry.has(input.name) {
            return reviewErrorResponse("Skill '\(input.name)' already exists")
        }

        do {
            let newSkill = Skill(
                name: input.name,
                description: input.description,
                aliases: [],
                userInvocable: false,
                promptTemplate: input.promptTemplate,
                whenToUse: input.whenToUse,
                lifecycleState: .active
            )
            let skillDir = try SkillWriter.write(skill: newSkill, to: skillsDir)
            skillRegistry.register(newSkill.withBaseDir(skillDir))

            try await usageStore.setProvenance(skillName: input.name, provenance: .agentCreated)

            return reviewJSONResponse([
                "success": true,
                "message": "Skill '\(input.name)' created and saved",
                "path": skillDir,
            ] as [String: Any])
        } catch {
            return reviewErrorResponse("Failed to persist skill: \(error.localizedDescription)")
        }
    }
}

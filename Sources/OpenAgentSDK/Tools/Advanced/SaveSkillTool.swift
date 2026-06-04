import Foundation

// MARK: - SaveSkillInput

private struct SaveSkillInput: Codable {
    let name: String
    let description: String
    let promptTemplate: String
    let whenToUse: String?
    let aliases: String?
    let userInvocable: Bool?
}

// MARK: - createSaveSkillTool

/// Creates the `save_skill` tool for runtime skill creation and persistence.
///
/// Writes the skill as a `SKILL.md` file under `<skillsDir>/<name>/`, registers it
/// in the ``SkillRegistry``, and marks its provenance as `.agentCreated` in the
/// ``SkillUsageStore``.
///
/// - Parameters:
///   - skillRegistry: The registry to register the new skill into.
///   - usageStore: The store for persisting usage/provenance data.
///   - skillsDir: Root directory for skill storage (e.g., `~/.axion/skills`).
/// - Returns: A `ToolProtocol` instance named `save_skill`.
public func createSaveSkillTool(
    skillRegistry: SkillRegistry,
    usageStore: SkillUsageStore,
    skillsDir: String
) -> ToolProtocol {
    defineTool(
        name: "save_skill",
        description: "Create and persist a new skill. The skill is saved to disk and available in future sessions. Use this when you identify a reusable pattern, workflow, or user preference during conversation.",
        inputSchema: [
            "type": "object",
            "properties": [
                "name": ["type": "string", "description": "Unique skill name (lowercase, hyphens only, e.g., 'commit-workflow')"],
                "description": ["type": "string", "description": "Human-readable description of what the skill does"],
                "promptTemplate": ["type": "string", "description": "The full prompt template for the skill"],
                "whenToUse": ["type": "string", "description": "Optional: when the agent should use this skill"],
                "aliases": ["type": "string", "description": "Optional: comma-separated list of aliases"],
                "userInvocable": ["type": "boolean", "description": "Whether users can invoke via /command (default: true)"],
            ],
            "required": ["name", "description", "promptTemplate"],
        ]
    ) { (input: SaveSkillInput, _: ToolContext) async -> String in
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Validate name
        guard !name.isEmpty else {
            return reviewJSONResponse(["success": false, "error": "'name' must not be empty"] as [String: Any])
        }
        let validNamePattern = "^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$"
        guard let regex = try? NSRegularExpression(pattern: validNamePattern),
              regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil
        else {
            return reviewJSONResponse([
                "success": false,
                "error": "Skill name must be lowercase alphanumeric with hyphens (pattern: [a-z0-9-], 2+ chars, no leading/trailing hyphens)",
            ] as [String: Any])
        }

        // 2. Check for conflicts with non-agentCreated skills
        if let existing = skillRegistry.find(name) {
            let usageData = await usageStore.getUsage(skillName: name)
            if usageData.provenance != .agentCreated {
                return reviewJSONResponse([
                    "success": false,
                    "error": "Skill '\(name)' already exists with provenance '\(usageData.provenance.rawValue)'. Only agent-created skills can be overwritten.",
                ] as [String: Any])
            }
            _ = existing  // suppress unused warning
        }

        // 3. Parse aliases
        let aliases: [String] = {
            guard let aliasesStr = input.aliases, !aliasesStr.isEmpty else { return [] }
            return aliasesStr
                .components(separatedBy: CharacterSet(charactersIn: ", "))
                .filter { !$0.isEmpty }
        }()

        // 4. Write to disk
        let skill = Skill(
            name: name,
            description: input.description,
            aliases: aliases,
            userInvocable: input.userInvocable ?? true,
            promptTemplate: input.promptTemplate,
            whenToUse: input.whenToUse,
            baseDir: (skillsDir as NSString).appendingPathComponent(name)
        )

        do {
            let skillDir = try SkillWriter.write(skill: skill, to: skillsDir)

            // 5. Register in memory
            let registeredSkill = Skill(
                name: skill.name,
                description: skill.description,
                aliases: skill.aliases,
                userInvocable: skill.userInvocable,
                promptTemplate: skill.promptTemplate,
                whenToUse: skill.whenToUse,
                baseDir: skillDir
            )
            skillRegistry.register(registeredSkill)

            // 6. Mark provenance
            try await usageStore.setProvenance(skillName: name, provenance: .agentCreated)

            return reviewJSONResponse([
                "success": true,
                "message": "Skill '\(name)' created and saved",
                "path": skillDir,
            ] as [String: Any])
        } catch {
            return reviewJSONResponse([
                "success": false,
                "error": "Failed to save skill: \(error.localizedDescription)",
            ] as [String: Any])
        }
    }
}

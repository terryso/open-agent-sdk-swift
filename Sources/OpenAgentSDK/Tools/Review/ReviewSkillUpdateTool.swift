import Foundation

// MARK: - ReviewSkillUpdateInput

private struct ReviewSkillUpdateInput: Codable {
    let skillName: String
    let updates: String
    let reason: String
}

// MARK: - createReviewSkillUpdateTool

/// Creates the `review_update_skill` tool for the forked review agent.
///
/// Looks up the skill in the registry, constructs a `SkillSignal` with `.refinement` type,
/// delegates to `SkillEvolver.evolve()`, replaces the skill if evolution produces a result,
/// and persists the updated skill to disk.
///
/// - Parameters:
///   - skillRegistry: The registry to look up and replace skills.
///   - skillEvolver: The evolver to apply skill changes.
///   - skillsDir: Root directory for skill storage (used when `baseDir` is nil).
/// - Returns: A `ToolProtocol` instance named `review_update_skill`.
public func createReviewSkillUpdateTool(
    skillRegistry: SkillRegistry,
    skillEvolver: any SkillEvolver,
    skillsDir: String
) -> ToolProtocol {
    defineTool(
        name: "review_update_skill",
        description: "Update an existing skill with new information extracted from the conversation review. The tool delegates to the skill evolution pipeline.",
        inputSchema: [
            "type": "object",
            "properties": [
                "skillName": ["type": "string", "description": "Name of the skill to update"],
                "updates": ["type": "string", "description": "JSON string containing fields to update (promptTemplate, description, whenToUse, argumentHint)"],
                "reason": ["type": "string", "description": "Explanation of why the skill needs updating"]
            ],
            "required": ["skillName", "updates", "reason"]
        ]
    ) { (input: ReviewSkillUpdateInput, _: ToolContext) async -> String in
        guard !input.skillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return reviewJSONResponse(["success": false, "error": "'skillName' must not be empty"] as [String: Any])
        }
        guard let skill = skillRegistry.find(input.skillName) else {
            return reviewJSONResponse([
                "success": false,
                "error": "Skill '\(input.skillName)' not found"
            ] as [String: Any])
        }

        guard let updatesData = input.updates.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: updatesData) as? [String: Any] else {
            return reviewJSONResponse(["success": false, "error": "Invalid JSON in updates field"] as [String: Any])
        }

        let signal = SkillSignal.create(
            skillName: input.skillName,
            signalType: .refinement,
            content: input.reason,
            confidence: 0.8,
            source: .conversation,
            metadata: ["updates": input.updates]
        )

        let config = SkillEvolutionConfig(
            maxSignalsPerEvolution: 5,
            minConfidence: 0.3,
            dryRun: false,
            preserveOriginal: true
        )

        do {
            let result = try await skillEvolver.evolve(skill: skill, signals: [signal], config: config)
            if let evolved = result.evolvedSkill {
                // Persist to disk
                let resolvedSkillsDir: String
                if let baseDir = evolved.baseDir, !baseDir.isEmpty {
                    resolvedSkillsDir = (baseDir as NSString).deletingLastPathComponent
                } else {
                    resolvedSkillsDir = skillsDir
                }
                let skillDir = try SkillWriter.write(skill: evolved, to: resolvedSkillsDir)

                // Update registry with correct baseDir
                skillRegistry.replace(evolved.withBaseDir(skillDir))

                return reviewJSONResponse([
                    "success": true,
                    "message": "Skill '\(input.skillName)' updated",
                    "changes": result.changes,
                    "path": skillDir,
                ] as [String: Any])
            }
            return reviewJSONResponse([
                "success": true,
                "message": "Skill '\(input.skillName)' evaluated but no changes applied",
                "changes": [] as [String]
            ] as [String: Any])
        } catch {
            return reviewJSONResponse([
                "success": false,
                "error": error.localizedDescription
            ] as [String: Any])
        }
    }
}

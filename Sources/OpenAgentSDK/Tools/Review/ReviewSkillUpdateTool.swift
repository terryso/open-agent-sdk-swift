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
/// delegates to `SkillEvolver.evolve()`, and replaces the skill if evolution produces a result.
///
/// - Parameters:
///   - skillRegistry: The registry to look up and replace skills.
///   - skillEvolver: The evolver to apply skill changes.
/// - Returns: A `ToolProtocol` instance named `review_update_skill`.
public func createReviewSkillUpdateTool(
    skillRegistry: SkillRegistry,
    skillEvolver: any SkillEvolver
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
            return "{\"success\": false, \"error\": \"'skillName' must not be empty\"}"
        }
        guard let skill = skillRegistry.find(input.skillName) else {
            return "{\"success\": false, \"error\": \"Skill '\(input.skillName)' not found\"}"
        }

        guard let updatesData = input.updates.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: updatesData) as? [String: Any] else {
            return "{\"success\": false, \"error\": \"Invalid JSON in updates field\"}"
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
                skillRegistry.replace(evolved)
                let changesJSON: String
                if result.changes.isEmpty {
                    changesJSON = "[]"
                } else if let data = try? JSONEncoder().encode(result.changes),
                          let encoded = String(data: data, encoding: .utf8) {
                    changesJSON = encoded
                } else {
                    changesJSON = "[]"
                }
                return "{\"success\": true, \"message\": \"Skill '\(input.skillName)' updated\", \"changes\": \(changesJSON)}"
            }
            return "{\"success\": true, \"message\": \"Skill '\(input.skillName)' evaluated but no changes applied\", \"changes\": []}"
        } catch {
            return "{\"success\": false, \"error\": \"\(error.localizedDescription)\"}"
        }
    }
}

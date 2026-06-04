import Foundation

// MARK: - ReviewSkillFileInput

private struct ReviewSkillFileInput: Codable {
    let skillName: String
    let filePath: String
    let content: String
}

// MARK: - Allowed Prefixes

private let allowedFilePathPrefixes = ["references/", "templates/", "scripts/"]

// MARK: - createReviewSkillFileTool

/// Creates the `review_add_skill_file` tool for the forked review agent.
///
/// Validates that the file path starts with an allowed prefix (`references/`, `templates/`, `scripts/`),
/// resolves the absolute path from the skill's `baseDir` (or creates one under `skillsDir`),
/// and writes the file.
///
/// - Parameters:
///   - skillRegistry: The registry to look up skills.
///   - skillsDir: Root directory for skill storage (used when skill has no `baseDir`).
/// - Returns: A `ToolProtocol` instance named `review_add_skill_file`.
public func createReviewSkillFileTool(
    skillRegistry: SkillRegistry,
    skillsDir: String
) -> ToolProtocol {
    defineTool(
        name: "review_add_skill_file",
        description: "Add a supporting file (reference, template, or script) to an existing skill. Only files under references/, templates/, or scripts/ paths are allowed.",
        inputSchema: [
            "type": "object",
            "properties": [
                "skillName": ["type": "string", "description": "Name of the skill to add the file to"],
                "filePath": ["type": "string", "description": "Relative path within the skill directory (must start with references/, templates/, or scripts/)"],
                "content": ["type": "string", "description": "Content to write to the file"]
            ],
            "required": ["skillName", "filePath", "content"]
        ]
    ) { (input: ReviewSkillFileInput, _: ToolContext) -> String in
        guard !input.skillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return reviewJSONResponse(["success": false, "error": "'skillName' must not be empty"] as [String: Any])
        }
        guard !input.filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return reviewJSONResponse(["success": false, "error": "'filePath' must not be empty"] as [String: Any])
        }
        guard let skill = skillRegistry.find(input.skillName) else {
            return reviewJSONResponse([
                "success": false,
                "error": "Skill '\(input.skillName)' not found"
            ] as [String: Any])
        }

        guard allowedFilePathPrefixes.contains(where: { input.filePath.hasPrefix($0) }) else {
            return reviewJSONResponse([
                "success": false,
                "error": "Invalid file path '\(input.filePath)'. Must start with one of: \(allowedFilePathPrefixes.joined(separator: ", "))"
            ] as [String: Any])
        }

        let pathComponents = input.filePath.split(separator: "/", omittingEmptySubsequences: false)
        if pathComponents.contains("..") {
            return reviewJSONResponse([
                "success": false,
                "error": "Invalid file path '\(input.filePath)'. Path traversal ('..') is not allowed"
            ] as [String: Any])
        }

        let baseDir: String
        if let existingBaseDir = skill.baseDir {
            baseDir = existingBaseDir
        } else {
            // Skill was created programmatically — materialize it on disk first
            do {
                let skillDir = try SkillWriter.write(skill: skill, to: skillsDir)
                baseDir = skillDir
                // Update registry with the new baseDir
                let updatedSkill = Skill(
                    name: skill.name,
                    description: skill.description,
                    aliases: skill.aliases,
                    userInvocable: skill.userInvocable,
                    toolRestrictions: skill.toolRestrictions,
                    modelOverride: skill.modelOverride,
                    promptTemplate: skill.promptTemplate,
                    whenToUse: skill.whenToUse,
                    argumentHint: skill.argumentHint,
                    baseDir: skillDir,
                    supportingFiles: skill.supportingFiles,
                    lifecycleState: skill.lifecycleState
                )
                skillRegistry.replace(updatedSkill)
            } catch {
                return reviewJSONResponse([
                    "success": false,
                    "error": "Failed to create skill directory: \(error.localizedDescription)"
                ] as [String: Any])
            }
        }

        let absolutePath = (baseDir as NSString).appendingPathComponent(input.filePath)
        let directory = (absolutePath as NSString).deletingLastPathComponent

        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try input.content.write(toFile: absolutePath, atomically: true, encoding: .utf8)
            return reviewJSONResponse([
                "success": true,
                "message": "File added to skill '\(input.skillName)'"
            ] as [String: Any])
        } catch {
            return reviewJSONResponse([
                "success": false,
                "error": error.localizedDescription
            ] as [String: Any])
        }
    }
}

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
        if let err = requireNonEmptyInput(input.skillName, field: "skillName") { return err }
        if let err = requireNonEmptyInput(input.filePath, field: "filePath") { return err }
        guard let skill = skillRegistry.find(input.skillName) else {
            return reviewErrorResponse("Skill '\(input.skillName)' not found")
        }

        guard allowedFilePathPrefixes.contains(where: { input.filePath.hasPrefix($0) }) else {
            return reviewErrorResponse("Invalid file path '\(input.filePath)'. Must start with one of: \(allowedFilePathPrefixes.joined(separator: ", "))")
        }

        let pathComponents = input.filePath.split(separator: "/", omittingEmptySubsequences: false)
        if pathComponents.contains("..") {
            return reviewErrorResponse("Invalid file path '\(input.filePath)'. Path traversal ('..') is not allowed")
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
                skillRegistry.replace(skill.withBaseDir(skillDir))
            } catch {
                return reviewErrorResponse("Failed to create skill directory: \(error.localizedDescription)")
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
            return reviewErrorResponse(error.localizedDescription)
        }
    }
}

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
/// resolves the absolute path from the skill's `baseDir`, and writes the file.
///
/// - Parameter skillRegistry: The registry to look up skills.
/// - Returns: A `ToolProtocol` instance named `review_add_skill_file`.
public func createReviewSkillFileTool(skillRegistry: SkillRegistry) -> ToolProtocol {
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
            return "{\"success\": false, \"error\": \"'skillName' must not be empty\"}"
        }
        guard !input.filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "{\"success\": false, \"error\": \"'filePath' must not be empty\"}"
        }
        guard let skill = skillRegistry.find(input.skillName) else {
            return "{\"success\": false, \"error\": \"Skill '\(input.skillName)' not found\"}"
        }

        guard allowedFilePathPrefixes.contains(where: { input.filePath.hasPrefix($0) }) else {
            return "{\"success\": false, \"error\": \"Invalid file path '\(input.filePath)'. Must start with one of: \(allowedFilePathPrefixes.joined(separator: ", "))\"}"
        }

        let pathComponents = input.filePath.split(separator: "/", omittingEmptySubsequences: false)
        if pathComponents.contains("..") {
            return "{\"success\": false, \"error\": \"Invalid file path '\(input.filePath)'. Path traversal ('..') is not allowed\"}"
        }

        guard let baseDir = skill.baseDir else {
            return "{\"success\": false, \"error\": \"Skill '\(input.skillName)' has no base directory (programmatically created skills cannot have files added)\"}"
        }

        let absolutePath = (baseDir as NSString).appendingPathComponent(input.filePath)
        let directory = (absolutePath as NSString).deletingLastPathComponent

        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try input.content.write(toFile: absolutePath, atomically: true, encoding: .utf8)
            return "{\"success\": true, \"message\": \"File added to skill '\(input.skillName)'\"}"
        } catch {
            return "{\"success\": false, \"error\": \"\(error.localizedDescription)\"}"
        }
    }
}

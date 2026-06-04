import Foundation

// MARK: - SkillWriter

/// Writes a ``Skill`` to disk as a `SKILL.md` file with YAML frontmatter.
///
/// Used by `SaveSkillTool`, `ReviewSkillCreateTool`, and `ReviewSkillUpdateTool`
/// to persist skills to the filesystem.
public enum SkillWriter {

    /// Writes a skill to disk as `<skillsDir>/<skill.name>/SKILL.md`.
    ///
    /// Creates the skill directory if it doesn't exist. Overwrites an existing SKILL.md.
    ///
    /// - Parameters:
    ///   - skill: The skill to persist.
    ///   - skillsDir: The root skills directory (e.g., `~/.axion/skills`).
    /// - Returns: The absolute path to the skill directory.
    /// - Throws: File system errors.
    @discardableResult
    public static func write(skill: Skill, to skillsDir: String) throws -> String {
        let skillDir = (skillsDir as NSString).appendingPathComponent(skill.name)

        try FileManager.default.createDirectory(
            atPath: skillDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )

        let content = buildSKILLMd(skill)
        let skillMdPath = (skillDir as NSString).appendingPathComponent("SKILL.md")
        try content.write(toFile: skillMdPath, atomically: true, encoding: .utf8)

        return skillDir
    }

    /// Builds the full SKILL.md content from a ``Skill``.
    ///
    /// Format:
    /// ```
    /// ---
    /// name: <name>
    /// description: <description>
    /// when-to-use: <whenToUse>
    /// aliases: <aliases>
    /// ---
    ///
    /// <promptTemplate>
    /// ```
    public static func buildSKILLMd(_ skill: Skill) -> String {
        var frontmatter = "---\n"
        frontmatter += "name: \(skill.name)\n"

        if !skill.description.isEmpty {
            frontmatter += "description: \(escapeYAML(skill.description))\n"
        }
        if let whenToUse = skill.whenToUse, !whenToUse.isEmpty {
            frontmatter += "when-to-use: \(escapeYAML(whenToUse))\n"
        }
        if let argumentHint = skill.argumentHint, !argumentHint.isEmpty {
            frontmatter += "argument-hint: \(escapeYAML(argumentHint))\n"
        }
        if !skill.aliases.isEmpty {
            frontmatter += "aliases: \(skill.aliases.joined(separator: ", "))\n"
        }
        if let model = skill.modelOverride {
            frontmatter += "model: \(model)\n"
        }
        frontmatter += "---\n\n"
        frontmatter += skill.promptTemplate

        return frontmatter
    }

    /// Escapes a string for safe inclusion in a YAML value.
    ///
    /// Wraps in double quotes if the value contains characters that need escaping.
    private static func escapeYAML(_ value: String) -> String {
        let needsQuoting = value.contains(":") || value.contains("#") || value.contains("\"")
            || value.contains("'") || value.contains("\n") || value.hasPrefix(" ")
            || value.hasSuffix(" ")
        if needsQuoting {
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            return "\"\(escaped)\""
        }
        return value
    }
}

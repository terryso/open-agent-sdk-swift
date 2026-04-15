import Foundation

// MARK: - SkillLoader

/// Stateless utility for discovering and loading SKILL.md-based skill packages from the filesystem.
///
/// Follows the progressive disclosure pattern: only the SKILL.md Markdown body is loaded
/// as the prompt template. Supporting files (references, scripts, templates, assets) are
/// discovered and listed as paths but their contents are NOT loaded. The agent loads them
/// on-demand via Read/Bash tools.
///
/// ```swift
/// let skills = SkillLoader.discoverSkills()
/// let skills = SkillLoader.discoverSkills(from: ["/opt/custom-skills"])
/// let filtered = SkillLoader.discoverSkills(from: nil, skillNames: ["polyv-live-cli"])
/// ```
public enum SkillLoader {

    // MARK: - Public API

    /// Discovers and loads skills from standard or specified directories.
    ///
    /// Scans directories in priority order (last-wins). For each directory, finds
    /// subdirectories containing `SKILL.md`, parses the frontmatter and body,
    /// resolves reference paths to absolute paths, and collects supporting file paths.
    ///
    /// - Parameters:
    ///   - directories: Directories to scan. When `nil`, uses default directories.
    ///   - skillNames: Optional whitelist of skill names to include. When `nil`, all are included.
    /// - Returns: Array of discovered `Skill` instances, deduplicated by name with last-wins priority.
    public static func discoverSkills(
        from directories: [String]? = nil,
        skillNames: [String]? = nil
    ) -> [Skill] {
        let dirs = directories ?? defaultSkillDirectories()
        var skillsByName: [String: Skill] = [:]
        var seenRealPaths = Set<String>()

        for dir in dirs {
            let expandedDir = expandTilde(dir)
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: expandedDir) else {
                continue
            }

            for entry in contents {
                let entryPath = expandedDir + "/" + entry
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: entryPath, isDirectory: &isDir),
                      isDir.boolValue else {
                    continue
                }

                let skillFilePath = entryPath + "/SKILL.md"
                guard FileManager.default.fileExists(atPath: skillFilePath) else {
                    continue
                }

                // Deduplicate by real path (resolves symlinks)
                let realPath = standardizePath(entryPath)
                guard !seenRealPaths.contains(realPath) else {
                    continue
                }
                seenRealPaths.insert(realPath)

                if let skill = loadSkillFromDirectory(entryPath) {
                    // If skillNames filter is set, only include matching skills
                    if let allowed = skillNames, !allowed.contains(skill.name) {
                        continue
                    }
                    skillsByName[skill.name] = skill
                }
            }
        }

        return Array(skillsByName.values)
    }

    /// Loads a single skill from a directory containing a SKILL.md file.
    ///
    /// - Parameter skillDir: Absolute path to the skill directory.
    /// - Returns: A parsed `Skill`, or `nil` if the directory doesn't contain a valid SKILL.md.
    public static func loadSkillFromDirectory(_ skillDir: String) -> Skill? {
        let skillFilePath = skillDir + "/SKILL.md"

        guard let content = try? String(contentsOfFile: skillFilePath, encoding: .utf8) else {
            return nil
        }

        guard let frontmatter = parseFrontmatter(content) else {
            return nil
        }

        let name = frontmatter["name"] ?? ((skillDir as NSString).lastPathComponent)
        let description = frontmatter["description"] ?? ""

        var body = extractMarkdownBody(content)
        body = resolveReferencePaths(in: body, baseDir: skillDir)

        let toolRestrictions = parseAllowedTools(frontmatter["allowed-tools"])
        let supportingFiles = findSupportingFiles(in: skillDir)

        return Skill(
            name: name,
            description: description,
            aliases: extractAliases(frontmatter),
            userInvocable: true,
            toolRestrictions: toolRestrictions,
            modelOverride: frontmatter["model"],
            promptTemplate: body,
            whenToUse: frontmatter["when-to-use"] ?? frontmatter["when_to_use"],
            argumentHint: frontmatter["argument-hint"] ?? frontmatter["argument_hint"],
            baseDir: skillDir,
            supportingFiles: supportingFiles
        )
    }

    /// Returns the default skill directories in scan order (lowest to highest priority).
    ///
    /// Priority order (last-wins):
    /// 1. `~/.config/agents/skills` — user-level, lowest
    /// 2. `~/.agents/skills` — user-level
    /// 3. `~/.claude/skills` — user-level
    /// 4. `$PWD/.agents/skills` — project-level
    /// 5. `$PWD/.claude/skills` — project-level, highest
    public static func defaultSkillDirectories() -> [String] {
        var dirs: [String] = []

        if let home = getEnv("HOME") {
            dirs.append(home + "/.config/agents/skills")
            dirs.append(home + "/.agents/skills")
            dirs.append(home + "/.claude/skills")
        }

        if let cwd = getEnv("PWD") ?? (FileManager.default.currentDirectoryPath as String?) {
            dirs.append(cwd + "/.agents/skills")
            dirs.append(cwd + "/.claude/skills")
        }

        return dirs
    }

    // MARK: - Internal

    /// Parses YAML frontmatter into a flat key-value dictionary.
    static func parseFrontmatter(_ content: String) -> [String: String]? {
        let lines = content.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

        var result: [String: String] = [:]
        var endFound = false

        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line == "---" {
                endFound = true
                break
            }
            if let colonRange = line.range(of: ":") {
                let key = String(line[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let value = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                result[key] = value
            }
        }

        return endFound ? result : nil
    }

    /// Extracts the Markdown body after the YAML frontmatter.
    static func extractMarkdownBody(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return content }

        var secondDelimiterIndex: Int?
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                secondDelimiterIndex = i
                break
            }
        }

        guard let endIdx = secondDelimiterIndex else { return content }
        let bodyStart = endIdx + 1
        guard bodyStart < lines.count else { return "" }
        return lines[bodyStart...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolves relative `references/xxx.md` paths in Markdown links to absolute paths.
    static func resolveReferencePaths(in body: String, baseDir: String) -> String {
        let pattern = #"\]\(references/([^)]+\.md)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return body }

        let range = NSRange(body.startIndex..., in: body)
        let matches = regex.matches(in: body, options: [], range: range)

        var result = body
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let pathRange = Range(match.range(at: 1), in: result) else { continue }
            let relativePath = String(result[pathRange])
            let absolutePath = baseDir + "/references/" + relativePath
            result.replaceSubrange(fullRange, with: "](\(absolutePath))")
        }

        return result
    }

    /// Discovers supporting files in the skill directory (recursive one level into subdirectories).
    ///
    /// Returns relative paths (relative to the skill directory). Skips SKILL.md itself.
    static func findSupportingFiles(in skillDir: String) -> [String] {
        var files: [String] = []
        let fm = FileManager.default

        guard let entries = try? fm.contentsOfDirectory(atPath: skillDir) else { return files }

        for entry in entries {
            let fullPath = skillDir + "/" + entry
            var isDir: ObjCBool = false

            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                // Recurse one level into subdirectories
                guard let subEntries = try? fm.contentsOfDirectory(atPath: fullPath) else { continue }
                for subEntry in subEntries {
                    let subPath = fullPath + "/" + subEntry
                    var subIsDir: ObjCBool = false
                    if fm.fileExists(atPath: subPath, isDirectory: &subIsDir), !subIsDir.boolValue {
                        files.append(entry + "/" + subEntry)
                    }
                }
            } else if entry != "SKILL.md" {
                files.append(entry)
            }
        }

        return files.sorted()
    }

    /// Parses the `allowed-tools` frontmatter value into ToolRestriction array.
    static func parseAllowedTools(_ allowedTools: String?) -> [ToolRestriction]? {
        guard let allowedTools = allowedTools, !allowedTools.isEmpty else { return nil }

        let pattern = #"(\w+)(?:\([^)]*\))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }

        let range = NSRange(allowedTools.startIndex..., in: allowedTools)
        let matches = regex.matches(in: allowedTools, options: [], range: range)

        var restrictions: [ToolRestriction] = []
        for match in matches {
            guard let toolRange = Range(match.range(at: 1), in: allowedTools) else { continue }
            let toolName = String(allowedTools[toolRange]).lowercased()
            if let restriction = ToolRestriction.allCases.first(where: { $0.rawValue == toolName }) {
                restrictions.append(restriction)
            }
        }

        return restrictions.isEmpty ? nil : restrictions
    }

    /// Extracts aliases from frontmatter.
    static func extractAliases(_ frontmatter: [String: String]) -> [String] {
        guard let aliasesStr = frontmatter["aliases"] else { return [] }
        return aliasesStr
            .components(separatedBy: CharacterSet(charactersIn: ", "))
            .filter { !$0.isEmpty }
    }

    /// Expands `~` to the user's home directory.
    static func expandTilde(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }
        let home = getEnv("HOME") ?? NSHomeDirectory()
        return home + String(path.dropFirst())
    }

    /// Standardizes a path by resolving symlinks and removing redundant components.
    static func standardizePath(_ path: String) -> String {
        (path as NSString).standardizingPath
    }
}

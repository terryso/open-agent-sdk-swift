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
        let parsedDeclarations = parseToolDeclarations(frontmatter["allowed-tools"])
        let supportingFiles = findSupportingFiles(in: skillDir)

        return Skill(
            name: name,
            description: description,
            aliases: extractAliases(frontmatter),
            userInvocable: true,
            toolRestrictions: toolRestrictions,
            toolDeclarations: parsedDeclarations?.declarations,
            toolDeclarationDiagnostics: parsedDeclarations?.diagnostics,
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
    ///
    /// Supports:
    /// - Simple `key: value` pairs
    /// - Single/double quoted values (`key: 'value'`, `key: "value"`)
    /// - YAML block scalars (`key: >` folded, `key: |` literal, with optional chomp modifiers `-`/`+`)
    /// - Nested mappings (skipped — only top-level string values are captured)
    static func parseFrontmatter(_ content: String) -> [String: String]? {
        let lines = content.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

        var result: [String: String] = [:]
        var endFound = false
        var i = 1

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "---" {
                endFound = true
                break
            }

            // Find first colon (only for top-level keys — no leading whitespace)
            if !line.hasPrefix(" ") && !line.hasPrefix("\t"),
               let colonRange = line.range(of: ":") {
                let key = String(line[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let rawValue = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

                if isBlockScalarIndicator(rawValue) {
                    // YAML block scalar: collect subsequent indented lines
                    let isLiteral = rawValue.hasPrefix("|")
                    let (blockValue, linesConsumed) = collectBlockScalar(lines: lines, startIndex: i + 1, isLiteral: isLiteral)
                    result[key] = blockValue
                    i += linesConsumed
                } else if rawValue.isEmpty {
                    // Value is empty — might be a nested mapping (skip its indented children)
                    // Just store empty string; nested keys are ignored
                    result[key] = ""
                } else {
                    result[key] = stripOuterQuotes(rawValue)
                }
            }
            // Lines starting with whitespace are either block scalar content
            // or nested mapping children — both are handled above or skipped

            i += 1
        }

        return endFound ? result : nil
    }

    /// Returns `true` if the value is a YAML block scalar indicator (`>`, `|-`, `>+`, etc.)
    private static func isBlockScalarIndicator(_ value: String) -> Bool {
        let indicators = [">", ">-", ">+", "|", "|-", "|+"]
        return indicators.contains(value)
    }

    /// Collects lines belonging to a YAML block scalar starting at `startIndex`.
    ///
    /// Folded (`>`) joins lines with spaces; literal (`|`) preserves newlines.
    /// Trailing blank lines are stripped. Returns the resolved value and the number
    /// of lines consumed.
    private static func collectBlockScalar(lines: [String], startIndex: Int, isLiteral: Bool) -> (value: String, consumed: Int) {
        var blockLines: [String] = []
        var j = startIndex

        // Skip leading blank lines
        while j < lines.count && lines[j].trimmingCharacters(in: .whitespaces).isEmpty {
            j += 1
        }

        // Collect indented (or blank) lines
        while j < lines.count {
            let line = lines[j]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // End block at closing --- or non-blank non-indented line
            if trimmed == "---" { break }
            if !trimmed.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t") { break }

            blockLines.append(trimmed)
            j += 1
        }

        // Strip trailing blank lines
        while !blockLines.isEmpty && blockLines.last!.isEmpty {
            blockLines.removeLast()
        }

        // Folded (`>`): join with spaces; Literal (`|`): join with newlines
        let value = blockLines.joined(separator: isLiteral ? "\n" : " ")
        return (value, j - startIndex)
    }

    /// Strips matching outer single or double quotes from a YAML value.
    private static func stripOuterQuotes(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        let start = value.startIndex
        let end = value.index(before: value.endIndex)
        let first = value[start]
        let last = value[end]
        if (first == "'" && last == "'") || (first == "\"" && last == "\"") {
            return String(value[value.index(after: start)..<end])
        }
        return value
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

    /// Parses the `allowed-tools` frontmatter value into a lossless
    /// `(declarations, diagnostics)` tuple (Story 29.4).
    ///
    /// Unlike the legacy `parseAllowedTools(_:) -> [ToolRestriction]?` (which
    /// only preserves enum-mappable names and collapses unresolvable input to
    /// `nil` = unrestricted), this parser preserves:
    ///
    /// - MCP namespaced names (`mcp__github__list_prs`) — full name kept
    /// - Permission pattern text (`Bash(git diff:*)` → `pattern == "git diff:*"`)
    /// - Unknown / custom names — as `ToolDeclaration` with `.unknown` status
    ///
    /// **Critical non-nil semantics (AC2):** when `allowedTools` is a non-empty
    /// string, this function returns a **non-nil** tuple even if every
    /// declaration is `.unknown`. This is the core fix for the legacy "silent
    /// unrestricted" bug — callers can distinguish "explicitly declared but
    /// unresolvable" (non-nil) from "no declaration at all" (nil = unrestricted).
    ///
    /// `nil`/empty input still returns `nil` (no frontmatter field = unrestricted).
    ///
    /// - Parameter allowedTools: Raw `allowed-tools` frontmatter value.
    /// - Returns: `(declarations, diagnostics)` preserving frontmatter order,
    ///   or `nil` when input is `nil`/empty.
    static func parseToolDeclarations(
        _ allowedTools: String?
    ) -> (declarations: [ToolDeclaration], diagnostics: ToolDeclarationDiagnostics)? {
        guard let allowedTools = allowedTools, !allowedTools.isEmpty else {
            return nil
        }

        // Split on comma then trim — more robust than a global regex for
        // preserving tokens containing special characters (e.g. `Bash(git diff:*)`).
        let tokens = allowedTools
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return nil }

        let declarations = tokens.map { tokenizeToolDeclaration($0) }

        let unsupported = declarations.filter { $0.status == .unknown }
        let patterned = declarations.filter { $0.pattern != nil }

        let diagnostics = ToolDeclarationDiagnostics(
            unsupportedDeclarations: unsupported,
            patternDeclarations: patterned
        )

        return (declarations, diagnostics)
    }

    /// Classifies a single trimmed `allowed-tools` token into a `ToolDeclaration`.
    ///
    /// Handles three shapes:
    /// 1. MCP namespaced: `mcp__<server>__<tool>` → `.recognizedMCP`
    /// 2. Pattern form: `Bash(git diff:*)` → split base/pattern, classify base
    /// 3. Plain name: `Read` / `Task` / `UnknownTool` → classify by lookup
    private static func tokenizeToolDeclaration(_ token: String) -> ToolDeclaration {
        let rawName = token

        // Split base name and optional `(...)` pattern BEFORE the MCP check so
        // that an MCP name with a trailing pattern (`mcp__github__list_prs(extra)`)
        // is classified against its bare namespaced base, not the raw token with
        // parens baked in (which would never match a registered MCP tool).
        let (baseName, pattern) = splitBaseAndPattern(token)

        // Detect MCP namespaced form against the base name (pattern already split off).
        if isMCPNamespacedName(baseName) {
            return ToolDeclaration(
                rawName: rawName,
                normalizedName: baseName,  // MCP full name already normalized
                pattern: pattern,
                status: .recognizedMCP,
                toolRestriction: nil
            )
        }

        let lowercasedBase = baseName.lowercased()

        // Recognized Claude Code LLM-facing name? (may or may not have enum case)
        if let restriction = ClaudeCodeToolNames.restriction(forLowercased: lowercasedBase) {
            return ToolDeclaration(
                rawName: rawName,
                normalizedName: lowercasedBase,
                pattern: pattern,
                status: .recognizedSDK,
                toolRestriction: restriction
            )
        }

        // Known Claude Code name without an enum case (e.g. `Task`).
        if ClaudeCodeToolNames.isKnown(lowercasedBase) {
            return ToolDeclaration(
                rawName: rawName,
                normalizedName: lowercasedBase,
                pattern: pattern,
                status: .recognizedSDK,
                toolRestriction: nil
            )
        }

        // Unresolvable — still recorded (non-nil tuple) so caller does not
        // treat the skill as unrestricted.
        return ToolDeclaration(
            rawName: rawName,
            normalizedName: lowercasedBase,
            pattern: pattern,
            status: .unknown,
            toolRestriction: nil
        )
    }

    /// Returns `true` when `name` matches the MCP namespaced convention
    /// `mcp__<server>__<tool>` (server/tool names may not themselves contain
    /// `__`, per `MCPToolDefinition`'s precondition).
    private static func isMCPNamespacedName(_ name: String) -> Bool {
        guard name.hasPrefix("mcp__") else { return false }
        let afterPrefix = String(name.dropFirst("mcp__".count))
        // Must contain exactly one more `__` separator.
        let parts = afterPrefix.components(separatedBy: "__")
        guard parts.count == 2 else { return false }
        let server = parts[0]
        let tool = parts[1]
        return !server.isEmpty && !tool.isEmpty
    }

    /// Splits a token into `(baseName, pattern)`. For `Bash(git diff:*)` →
    /// `("Bash", "git diff:*")`. For `Read` → `("Read", nil)`.
    ///
    /// Edge cases handled (Story 29.4 review):
    /// - `Bash()` (empty parens) → `("Bash", nil)` — an empty pattern is not a
    ///   real pattern declaration, so `nil` avoids a phantom entry in
    ///   `ToolDeclarationDiagnostics.patternDeclarations`.
    /// - `Bash(` (unclosed paren) → `("Bash", nil)` — the dangling `(` is
    ///   stripped from the base so a recognized tool is not silently demoted
    ///   to `.unknown` by a typo. The malformed form is still captured in
    ///   `rawName` verbatim.
    private static func splitBaseAndPattern(_ token: String) -> (base: String, pattern: String?) {
        guard let openParen = token.firstIndex(of: "(") else {
            // No opening paren at all — plain name.
            return (token, nil)
        }
        let base = String(token[..<openParen])
        // Need a closing paren at the end to treat the interior as a pattern.
        guard token.last == ")" else {
            // Unclosed paren (e.g. `Bash(git diff:*`). Strip the dangling `(` so
            // the base name stays recognizable, but record no pattern.
            return (base, nil)
        }
        let patternStart = token.index(after: openParen)
        let patternEnd = token.index(before: token.endIndex)
        guard patternStart < patternEnd else {
            // Empty parens `Bash()` — treat as no pattern.
            return (base, nil)
        }
        let pattern = String(token[patternStart..<patternEnd])
        return (base, pattern)
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

    // MARK: - Claude Code Tool Name Recognition

    /// Lookup table for Claude Code LLM-facing tool names recognized at parse
    /// time even when they have no `ToolRestriction` enum case (e.g. `Task`).
    ///
    /// Per Epic 29 implementation step 3: `Read, Write, Edit, Glob, Grep, Bash,
    /// WebFetch, WebSearch, ToolSearch, AskUser, Skill, Agent, Task`.
    ///
    /// `ToolRestriction` raw values are camelCase (`webFetch`, `webSearch`,
    /// `toolSearch`, `askUser`) while the frontmatter / Claude Code names are
    /// PascalCase. `restrictionByLowercasedName` bridges the two so the parser
    /// can match case-insensitively. Names present in this map are recognized
    /// as SDK names; `knownClaudeCodeOnly` catches names the enum lacks
    /// (currently just `Task`, per the "ToolRestriction gap" design decision).
    private enum ClaudeCodeToolNames {
        /// Lowercased name → ToolRestriction. Covers all enum cases the parser
        /// should recognize (the full enum is broader, but the parser only
        /// surfaces names that Claude Code authors write in frontmatter).
        static let restrictionByLowercasedName: [String: ToolRestriction] = {
            var map: [String: ToolRestriction] = [:]
            for restriction in ToolRestriction.allCases {
                map[restriction.rawValue.lowercased()] = restriction
            }
            return map
        }()

        /// Claude Code names recognized as SDK names but without an enum case.
        static let knownClaudeCodeOnly: Set<String> = ["task"]

        /// Lowercased set of all recognized Claude Code LLM-facing names
        /// (enum-mappable + gap names like `Task`).
        static let knownLowercased: Set<String> = {
            var set = Set(restrictionByLowercasedName.keys)
            set.formUnion(knownClaudeCodeOnly)
            return set
        }()

        static func restriction(forLowercased lowercasedName: String) -> ToolRestriction? {
            restrictionByLowercasedName[lowercasedName]
        }

        static func isKnown(_ lowercasedName: String) -> Bool {
            knownLowercased.contains(lowercasedName)
        }
    }
}

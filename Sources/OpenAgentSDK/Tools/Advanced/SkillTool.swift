import Foundation

// MARK: - SkillToolInput

/// Input structure for the Skill tool.
///
/// Encoded/decoded via Codable bridging in ``defineTool``.
private struct SkillToolInput: Codable {
    /// The skill name or alias to execute.
    let skill: String
    /// Optional arguments passed to the skill.
    let args: String?
}

// MARK: - createSkillTool

/// Creates the Skill tool that allows the LLM to discover and execute registered skills.
///
/// The SkillTool looks up skills by name or alias via the provided ``SkillRegistry``,
/// validates availability, checks recursion depth, prevents self-reference cycles,
/// and returns a JSON result containing the skill's prompt template and metadata.
///
/// The returned tool follows the standard ``ToolProtocol`` pattern and can be registered
/// in the agent's tool pool like any other tool.
///
/// - Parameter registry: The skill registry to look up skills from.
/// - Returns: A ``ToolProtocol`` instance for the Skill tool.
///
/// ```swift
/// let registry = SkillRegistry()
/// registry.register(BuiltInSkills.commit)
/// let skillTool = createSkillTool(registry: registry)
/// ```
public func createSkillTool(registry: SkillRegistry) -> ToolProtocol {
    // Build dynamic description listing all registered skills so the LLM knows what's available
    let skills = registry.allSkills
    let desc: String
    if skills.isEmpty {
        desc = "Execute a registered skill by name. No skills are currently registered."
    } else {
        let skillList = skills.map { skill in
            if skill.aliases.isEmpty {
                return "- \(skill.name): \(skill.description)"
            } else {
                return "- \(skill.name) (aliases: \(skill.aliases.joined(separator: ", "))): \(skill.description)"
            }
        }.joined(separator: "\n")
        desc = """
Execute a registered skill by name. Available skills:
\(skillList)

Skills provide specialized capabilities through prompt templates with optional tool restrictions and model overrides. \
Use this tool when the user's request matches one of the available skills.
"""
    }

    return defineTool(
        name: "Skill",
        description: desc,
        inputSchema: [
            "type": "object",
            "properties": [
                "skill": [
                    "type": "string",
                    "description": "The skill name or alias to execute"
                ],
                "args": [
                    "type": "string",
                    "description": "Optional arguments to pass to the skill"
                ]
            ],
            "required": ["skill"]
        ],
        isReadOnly: false
    ) { (input: SkillToolInput, context: ToolContext) async throws -> ToolExecuteResult in
        // 1. Find skill by name or alias
        guard let skill = registry.find(input.skill) else {
            return ToolExecuteResult(
                content: "Error: Skill \"\(input.skill)\" not found or not registered",
                isError: true
            )
        }

        // 2. Check availability
        guard skill.isAvailable() else {
            return ToolExecuteResult(
                content: "Error: Skill \"\(input.skill)\" is not available in the current environment",
                isError: true
            )
        }

        // 3. Check recursion depth
        let newDepth = context.skillNestingDepth + 1
        guard newDepth <= context.maxSkillRecursionDepth else {
            return ToolExecuteResult(
                content: "Error: Skill recursion depth exceeded: maximum nesting depth is \(context.maxSkillRecursionDepth)",
                isError: true
            )
        }

        // 4. Check self-reference (AC5: skill cannot restrict SkillTool itself)
        if let restrictions = skill.toolRestrictions, restrictions.contains(.skill) {
            return ToolExecuteResult(
                content: "Error: Skill cannot restrict SkillTool itself",
                isError: true
            )
        }

        // 5. Tool restrictions are NOT pushed here.
        // When called via stream(), the restriction stack would block MCP tools
        // because ToolRestriction only knows SDK-internal tool names (bash, read, etc.).
        // Tool restrictions are handled exclusively by executeSkillStream() via
        // options.allowedTools — the SkillTool just returns the restriction metadata
        // in its JSON result so the agent knows the skill's intent.

        // 6. Build JSON result
        var result: [String: Any] = [
            "success": true,
            "commandName": skill.name,
            "prompt": skill.promptTemplate
        ]

        // Include allowedTools for consumers that still read the legacy field.
        // When richer declarations exist, emit their raw names so MCP/custom/pattern
        // entries are not lost. Legacy programmatic skills without declarations keep
        // the historical ToolRestriction rawValue list.
        if let declarations = skill.toolDeclarations {
            result["allowedTools"] = declarations.map(\.rawName)
        } else if let restrictions = skill.toolRestrictions {
            result["allowedTools"] = restrictions.map(\.rawValue)
        }

        // Story 29.5: also surface the richer `toolDeclarations` when present, so the
        // host can distinguish SDK / MCP / unknown / pattern declarations (the legacy
        // `allowedTools` rawValue list cannot represent these). Omitted entirely when the
        // skill has no declarations (programmatic / pre-29.4 skills behave exactly as before).
        if let declarations = skill.toolDeclarations {
            result["toolDeclarations"] = declarations.map { d in
                var entry: [String: Any] = [
                    "rawName": d.rawName,
                    "normalizedName": d.normalizedName,
                    "status": d.status.rawValue,
                    "hasToolRestriction": d.toolRestriction != nil,
                ]
                // nil-safe pattern: omit when absent (keeps legacy-shape consumers happy).
                if let pattern = d.pattern {
                    entry["pattern"] = pattern
                }
                return entry
            }
        }

        // Include model if skill has a model override
        if let modelOverride = skill.modelOverride {
            result["model"] = modelOverride
        }

        // Include baseDir for filesystem-loaded skills (progressive disclosure)
        if let baseDir = skill.baseDir {
            result["baseDir"] = baseDir
        }

        // Include supporting files list so agent knows what's available
        if !skill.supportingFiles.isEmpty {
            result["supportingFiles"] = skill.supportingFiles
        }

        // Serialize to JSON string
        let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{\"success\":true}"

        return ToolExecuteResult(content: jsonString, isError: false)
    }
}

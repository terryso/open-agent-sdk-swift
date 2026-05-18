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
    return defineTool(
        name: "Skill",
        description: "Execute a registered skill by name. Skills provide specialized capabilities through prompt templates with optional tool restrictions and model overrides.",
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

        // 5. Push tool restrictions if present (AC2/AC3/AC6)
        if let restrictions = skill.toolRestrictions {
            context.restrictionStack?.push(restrictions)
        }
        defer {
            if skill.toolRestrictions != nil {
                context.restrictionStack?.pop()
            }
        }

        // 6. Build JSON result
        var result: [String: Any] = [
            "success": true,
            "commandName": skill.name,
            "prompt": skill.promptTemplate
        ]

        // Include allowedTools if skill has tool restrictions
        if let restrictions = skill.toolRestrictions {
            result["allowedTools"] = restrictions.map(\.rawValue)
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

import Foundation

// MARK: - Built-in Agent Definitions

/// Pre-configured agent definitions for common sub-agent types.
///
/// Mirrors the TypeScript SDK's BUILTIN_AGENTS with Explore and Plan types.
private let BUILTIN_AGENTS: [String: AgentDefinition] = [
    "Explore": AgentDefinition(
        name: "Explore",
        description: "Fast agent specialized for exploring codebases. Use for finding files, searching code, and answering questions about the codebase.",
        systemPrompt: "You are a codebase exploration agent. Search through files and code to answer questions. Be thorough but efficient. Use Glob to find files, Grep to search content, and Read to examine files.",
        tools: ["Read", "Glob", "Grep", "Bash"],
        maxTurns: 10
    ),
    "Plan": AgentDefinition(
        name: "Plan",
        description: "Software architect agent for designing implementation plans. Returns step-by-step plans and identifies critical files.",
        systemPrompt: "You are a software architect. Design implementation plans for the given task. Identify critical files, consider trade-offs, and provide step-by-step plans. Use search tools to understand the codebase before planning.",
        tools: ["Read", "Glob", "Grep", "Bash"],
        maxTurns: 10
    ),
]

// MARK: - AgentTool Input

/// Input type for the Agent / Task tools (shared subagent launcher).
///
/// Field names use snake_case to match the LLM-side JSON schema
/// (per project-context.md rule #19).
///
/// Note: This type is intentionally named `AgentToolInput` (not `TaskToolInput`
/// or `Task`) to avoid shadowing Swift Concurrency's `Task` symbol
/// (see project-context.md rule #15).
private struct AgentToolInput: Codable {
    let prompt: String
    let description: String
    let subagent_type: String?
    let model: String?
    let name: String?
    let maxTurns: Int?
    /// Whether to launch the sub-agent in the background.
    let runInBackground: Bool?
    /// Isolation mode for the sub-agent (e.g., "worktree").
    let isolation: String?
    /// Team name for multi-agent coordination.
    let teamName: String?
    /// Permission mode raw value string (parsed to PermissionMode at spawn time).
    let mode: String?
    /// Resume a previously running sub-agent by ID.
    let resume: String?

    private enum CodingKeys: String, CodingKey {
        case prompt
        case description
        case subagent_type
        case model
        case name
        case maxTurns
        case run_in_background
        case isolation
        case team_name
        case mode
        case resume
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prompt = try container.decode(String.self, forKey: .prompt)
        description = try container.decode(String.self, forKey: .description)
        subagent_type = try container.decodeIfPresent(String.self, forKey: .subagent_type)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        maxTurns = try container.decodeIfPresent(Int.self, forKey: .maxTurns)
        runInBackground = try container.decodeIfPresent(Bool.self, forKey: .run_in_background)
        isolation = try container.decodeIfPresent(String.self, forKey: .isolation)
        teamName = try container.decodeIfPresent(String.self, forKey: .team_name)
        mode = try container.decodeIfPresent(String.self, forKey: .mode)
        resume = try container.decodeIfPresent(String.self, forKey: .resume)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(subagent_type, forKey: .subagent_type)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(maxTurns, forKey: .maxTurns)
        try container.encodeIfPresent(runInBackground, forKey: .run_in_background)
        try container.encodeIfPresent(isolation, forKey: .isolation)
        try container.encodeIfPresent(teamName, forKey: .team_name)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encodeIfPresent(resume, forKey: .resume)
    }
}

// MARK: - Subagent Launcher Schema (shared between Agent and Task tools)

private nonisolated(unsafe) let subAgentLauncherSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "prompt": ["type": "string", "description": "The task for the agent to perform"] as [String: Any],
        "description": ["type": "string", "description": "A short (3-5 word) description of the task"] as [String: Any],
        "subagent_type": ["type": "string", "description": "The type of agent to use (e.g., \"Explore\", \"Plan\", or a custom agent name)"] as [String: Any],
        "model": ["type": "string", "description": "Optional model override for this agent"] as [String: Any],
        "name": ["type": "string", "description": "Name for the spawned agent"] as [String: Any],
        "maxTurns": ["type": "integer", "description": "Optional max turns override for this agent"] as [String: Any],
        "run_in_background": ["type": "boolean", "description": "Whether to launch the sub-agent in the background"] as [String: Any],
        "isolation": ["type": "string", "description": "Isolation mode for the sub-agent (e.g., \"worktree\")"] as [String: Any],
        "team_name": ["type": "string", "description": "Team name for multi-agent coordination"] as [String: Any],
        "mode": ["type": "string", "description": "Permission mode for the sub-agent (e.g., \"bypassPermissions\")"] as [String: Any],
        "resume": ["type": "string", "description": "Resume a previously running sub-agent by ID"] as [String: Any],
    ] as [String: Any],
    "required": ["prompt", "description"]
]

// MARK: - Shared Subagent Launcher Factory

/// Shared factory for the subagent launcher tool, used by both the
/// `Agent` and `Task` tool variants (Story 29.1).
///
/// Both public factories (`createAgentTool()` and `createTaskTool()`) delegate
/// to this helper, ensuring identical schema, execution body, and output format.
/// Only the tool `name` and `description` (human-facing prose) differ.
///
/// - Parameters:
///   - name: The LLM-facing tool name (`"Agent"` or `"Task"`).
///   - description: The human-facing description shown to the model.
/// - Returns: A ``ToolProtocol`` instance for the subagent launcher.
private func createSubAgentLauncherTool(name: String, description: String) -> ToolProtocol {
    return defineTool(
        name: name,
        description: description,
        inputSchema: subAgentLauncherSchema,
        isReadOnly: false
    ) { (input: AgentToolInput, context: ToolContext) async throws -> ToolExecuteResult in
        // Guard: spawner must be available
        guard let spawner = context.agentSpawner else {
            return ToolExecuteResult(
                content: "Error: \(name) spawner not available. The \(name) tool requires a SubAgentSpawner to be configured.",
                isError: true
            )
        }

        // Resolve agent definition from built-in types
        let agentType = input.subagent_type ?? "general-purpose"
        let agentDef = BUILTIN_AGENTS[agentType]

        // Resolve PermissionMode from string (if provided)
        let resolvedMode: PermissionMode? = input.mode.flatMap { PermissionMode(rawValue: $0) }

        // Spawn the sub-agent with all parameters
        let result = await spawner.spawn(
            prompt: input.prompt,
            model: input.model ?? agentDef?.model,
            systemPrompt: agentDef?.systemPrompt,
            allowedTools: agentDef?.tools,
            maxTurns: input.maxTurns ?? agentDef?.maxTurns,
            disallowedTools: agentDef?.disallowedTools,
            mcpServers: agentDef?.mcpServers,
            skills: agentDef?.skills,
            runInBackground: input.runInBackground,
            isolation: input.isolation,
            name: input.name,
            teamName: input.teamName,
            mode: resolvedMode,
            resume: input.resume
        )

        // Format output
        var output = result.text
        if !result.toolCalls.isEmpty {
            output += "\n[Tools used: \(result.toolCalls.joined(separator: ", "))]"
        }

        return ToolExecuteResult(content: output, isError: result.isError)
    }
}

// MARK: - Public Factory Functions

/// Creates the Agent tool for spawning sub-agents.
///
/// The Agent tool launches sub-agents to handle complex, multi-step tasks autonomously.
/// Sub-agents have their own context and can run specialized tool sets.
///
/// **Architecture:** This tool uses ``ToolContext/agentSpawner`` (a ``SubAgentSpawner``
/// protocol defined in Types/) to create child agents without importing Core/.
/// The spawner is injected by Core/ when the tool is registered.
///
/// - Returns: A ``ToolProtocol`` instance for the Agent tool.
public func createAgentTool() -> ToolProtocol {
    return createSubAgentLauncherTool(
        name: "Agent",
        description: "Launch a subagent to handle complex, multi-step tasks autonomously. Subagents have their own context and can run specialized tool sets."
    )
}

/// Creates the Task tool — a Claude Code-compatible alias of ``createAgentTool()``.
///
/// `Task` shares the same schema, execution body, and output format as the `Agent` tool.
/// Existing Claude Code workflow skills that emit `Task(subagent_type:, description:, prompt:)`
/// snippets can run unmodified once this tool is registered.
///
/// **Note:** The Swift type name `Task` (Swift Concurrency) is intentionally NOT used —
/// the tool name **string** `"Task"` is fine because it is a runtime identifier, not a type
/// (see project-context.md rule #15). The shared input type remains `AgentToolInput`.
///
/// - Returns: A ``ToolProtocol`` instance for the Task tool.
public func createTaskTool() -> ToolProtocol {
    return createSubAgentLauncherTool(
        name: "Task",
        description: "Launch a subagent to handle complex, multi-step tasks autonomously. Subagents have their own context and can run specialized tool sets. Claude Code-compatible alias of the Agent tool."
    )
}

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

/// Input type for the Agent tool.
///
/// Field names use snake_case to match the LLM-side JSON schema
/// (per project-context.md rule #19).
private struct AgentToolInput: Codable {
    let prompt: String
    let description: String
    let subagent_type: String?
    let model: String?
    let name: String?
    let maxTurns: Int?
}

// MARK: - AgentTool Schema

private nonisolated(unsafe) let agentToolSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "prompt": ["type": "string", "description": "The task for the agent to perform"] as [String: Any],
        "description": ["type": "string", "description": "A short (3-5 word) description of the task"] as [String: Any],
        "subagent_type": ["type": "string", "description": "The type of agent to use (e.g., \"Explore\", \"Plan\", or a custom agent name)"] as [String: Any],
        "model": ["type": "string", "description": "Optional model override for this agent"] as [String: Any],
        "name": ["type": "string", "description": "Name for the spawned agent"] as [String: Any],
        "maxTurns": ["type": "integer", "description": "Optional max turns override for this agent"] as [String: Any],
    ] as [String: Any],
    "required": ["prompt", "description"]
]

// MARK: - Factory Function

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
    return defineTool(
        name: "Agent",
        description: "Launch a subagent to handle complex, multi-step tasks autonomously. Subagents have their own context and can run specialized tool sets.",
        inputSchema: agentToolSchema,
        isReadOnly: false
    ) { (input: AgentToolInput, context: ToolContext) async throws -> ToolExecuteResult in
        // Guard: spawner must be available
        guard let spawner = context.agentSpawner else {
            return ToolExecuteResult(
                content: "Error: Agent spawner not available. The Agent tool requires a SubAgentSpawner to be configured.",
                isError: true
            )
        }

        // Resolve agent definition from built-in types
        let agentType = input.subagent_type ?? "general-purpose"
        let agentDef = BUILTIN_AGENTS[agentType]

        // Spawn the sub-agent
        let result = await spawner.spawn(
            prompt: input.prompt,
            model: input.model ?? agentDef?.model,
            systemPrompt: agentDef?.systemPrompt,
            allowedTools: agentDef?.tools,
            maxTurns: input.maxTurns ?? agentDef?.maxTurns
        )

        // Format output
        var output = result.text
        if !result.toolCalls.isEmpty {
            output += "\n[Tools used: \(result.toolCalls.joined(separator: ", "))]"
        }

        return ToolExecuteResult(content: output, isError: result.isError)
    }
}

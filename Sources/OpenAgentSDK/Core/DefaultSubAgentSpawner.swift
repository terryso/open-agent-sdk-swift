import Foundation

// MARK: - DefaultSubAgentSpawner

/// Concrete implementation of ``SubAgentSpawner`` that creates real ``Agent`` instances.
///
/// This class bridges the Tools/ → Core/ boundary:
/// Tools/Advanced/AgentTool.swift uses the ``SubAgentSpawner`` protocol (defined in Types/),
/// and Core/ provides this concrete implementation via ``ToolContext/agentSpawner``.
///
/// **Architecture compliance:** Defined in Core/ (which can import Agent, AgentOptions).
/// Used in Tools/ via protocol abstraction (no Core/ import needed).
final class DefaultSubAgentSpawner: SubAgentSpawner, @unchecked Sendable {
    private let apiKey: String
    private let baseURL: String?
    private let parentModel: String
    private let parentTools: [ToolProtocol]
    private let provider: LLMProvider
    private let client: (any LLMClient)?

    init(
        apiKey: String,
        baseURL: String?,
        parentModel: String,
        parentTools: [ToolProtocol],
        provider: LLMProvider = .anthropic,
        client: (any LLMClient)? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.parentModel = parentModel
        self.parentTools = parentTools
        self.provider = provider
        self.client = client
    }

    func spawn(
        prompt: String,
        model: String?,
        systemPrompt: String?,
        allowedTools: [String]?,
        maxTurns: Int?
    ) async -> SubAgentResult {
        // 1. Filter out AgentTool to prevent infinite recursion
        var subTools = parentTools.filter { $0.name != "Agent" }

        // 2. If allowedTools specified, further filter to only those tools
        if let allowed = allowedTools, !allowed.isEmpty {
            let allowedSet = Set(allowed)
            subTools = subTools.filter { allowedSet.contains($0.name) }
        }

        // 3. Create sub-agent with resolved configuration
        let resolvedModel = model ?? parentModel
        let resolvedMaxTurns = maxTurns ?? 10

        let options = AgentOptions(
            apiKey: apiKey,
            model: resolvedModel,
            baseURL: baseURL,
            provider: provider,
            systemPrompt: systemPrompt,
            maxTurns: resolvedMaxTurns,
            tools: subTools.isEmpty ? nil : subTools
        )

        let agent: Agent
        if let client = client {
            agent = Agent(options: options, client: client)
        } else {
            agent = Agent(options: options)
        }

        // 4. Execute sub-agent and collect result
        let result = await agent.prompt(prompt)

        let isError = result.status != .success
        let text = result.text.isEmpty
            ? "(Subagent completed with no text output)"
            : result.text

        return SubAgentResult(
            text: text,
            toolCalls: [],
            isError: isError
        )
    }

    /// Enhanced spawn with additional sub-agent configuration parameters.
    ///
    /// Extends the base spawn with disallowedTools filtering, MCP server resolution,
    /// skills configuration, and background launch support.
    func spawn(
        prompt: String,
        model: String?,
        systemPrompt: String?,
        allowedTools: [String]?,
        maxTurns: Int?,
        disallowedTools: [String]?,
        mcpServers: [AgentMcpServerSpec]?,
        skills: [String]?,
        runInBackground: Bool?,
        isolation: String?,
        name: String?,
        teamName: String?,
        mode: PermissionMode?,
        resume: String?
    ) async -> SubAgentResult {
        // 1. Filter out AgentTool to prevent infinite recursion
        var subTools = parentTools.filter { $0.name != "Agent" }

        // 2. If allowedTools specified, further filter to only those tools
        if let allowed = allowedTools, !allowed.isEmpty {
            let allowedSet = Set(allowed)
            subTools = subTools.filter { allowedSet.contains($0.name) }
        }

        // 3. Apply disallowedTools filtering (takes priority over allowedTools)
        if let disallowed = disallowedTools, !disallowed.isEmpty {
            let disallowedSet = Set(disallowed)
            subTools = subTools.filter { !disallowedSet.contains($0.name) }
        }

        // 4. Resolve MCP servers from spec (reference lookup or inline)
        var resolvedMcpServers: [String: McpServerConfig] = [:]
        if let mcpServers {
            for spec in mcpServers {
                switch spec {
                case .reference:
                    // Reference lookup would require parent MCP config access.
                    // For now, references are stored but not resolved at runtime.
                    // Full runtime wiring is deferred to a future story.
                    break
                case .inline(let config):
                    // Use a deterministic key for inline configs
                    let key = "inline-\(resolvedMcpServers.count)"
                    resolvedMcpServers[key] = config
                }
            }
        }

        // 5. Create sub-agent with resolved configuration
        let resolvedModel = model ?? parentModel
        let resolvedMaxTurns = maxTurns ?? 10

        var options = AgentOptions(
            apiKey: apiKey,
            model: resolvedModel,
            baseURL: baseURL,
            provider: provider,
            systemPrompt: systemPrompt,
            maxTurns: resolvedMaxTurns,
            tools: subTools.isEmpty ? nil : subTools
        )

        // Apply MCP servers if any were resolved
        if !resolvedMcpServers.isEmpty {
            options.mcpServers = resolvedMcpServers
        }

        // Apply permission mode if specified
        if let mode {
            options.permissionMode = mode
        }

        // Apply agent name if specified
        if let name {
            options.agentName = name
        }

        // Note: skills, runInBackground, isolation, teamName, and resume
        // are declared fields but full runtime wiring is deferred.
        // These are passed through for future implementation.

        let agent: Agent
        if let client = client {
            agent = Agent(options: options, client: client)
        } else {
            agent = Agent(options: options)
        }

        // Execute sub-agent and collect result
        let result = await agent.prompt(prompt)

        let isError = result.status != .success
        let text = result.text.isEmpty
            ? "(Subagent completed with no text output)"
            : result.text

        return SubAgentResult(
            text: text,
            toolCalls: [],
            isError: isError
        )
    }
}

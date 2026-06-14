import Foundation

// MARK: - SubAgentLauncherNames

/// LLM-facing tool names that can spawn subagents.
///
/// `Agent` is the canonical SDK name; `Task` is the Claude Code-compatible alias
/// (introduced in Story 29.1). Spawner detection AND child filtering must both
/// recognize every name in this list so that:
///   1. Registering only `Task` still injects a spawner into `ToolContext`
///      (prevents the "spawner missing" runtime hole).
///   2. Both names are stripped from the child tool pool by default
///      (prevents unbounded recursive spawning).
enum SubAgentLauncherNames {
    /// Default set of subagent launcher tool names recognized by the SDK.
    /// Order does not matter (membership checks only); kept as `Array` per project rule #46.
    static let `default`: [String] = ["Agent", "Task"]

    /// Returns `true` when `toolName` is one of the default launcher names.
    static func contains(_ toolName: String) -> Bool {
        `default`.contains(toolName)
    }
}

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
        await spawn(
            prompt: prompt,
            model: model,
            systemPrompt: systemPrompt,
            allowedTools: allowedTools,
            maxTurns: maxTurns,
            disallowedTools: nil,
            mcpServers: nil,
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
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
        // 1. Filter tools
        let subTools = filterTools(allowedTools: allowedTools, disallowedTools: disallowedTools)

        // 2. Resolve MCP servers from spec (reference lookup or inline)
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

        // 3. Build options
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

        if !resolvedMcpServers.isEmpty { options.mcpServers = resolvedMcpServers }
        if let mode { options.permissionMode = mode }
        if let name { options.agentName = name }

        // Note: skills, runInBackground, isolation, teamName, and resume
        // are declared fields but full runtime wiring is deferred.

        // 4. Execute and collect result
        return await executeAgent(prompt: prompt, options: options)
    }

    // MARK: - Private

    /// Filter parent tools: strip subagent launcher tools (``SubAgentLauncherNames.default``)
    /// and apply allowed/disallowed lists.
    ///
    /// Default behavior strips BOTH `Agent` and `Task` so that a child cannot recursively
    /// spawn grandchildren without explicit host opt-in. See Story 29.2 AC5.
    private func filterTools(allowedTools: [String]?, disallowedTools: [String]?) -> [ToolProtocol] {
        // Strip all subagent launcher tools by default to prevent recursive spawning.
        // Escape hatch (explicit recursion-allowed config) is deferred to a future story;
        // current default MUST remain "strip both" per Story 29.2 AC5.
        var subTools = parentTools.filter { !SubAgentLauncherNames.contains($0.name) }

        if let allowed = allowedTools, !allowed.isEmpty {
            let allowedSet = Set(allowed)
            subTools = subTools.filter { allowedSet.contains($0.name) }
        }

        if let disallowed = disallowedTools, !disallowed.isEmpty {
            let disallowedSet = Set(disallowed)
            subTools = subTools.filter { !disallowedSet.contains($0.name) }
        }

        return subTools
    }

    /// Test-only thin wrapper around the private ``filterTools`` so unit tests can assert
    /// the filtering contract directly without driving a full `spawn` round-trip.
    ///
    /// Project rule #22 (prefer `internal`) makes this safe: `@testable import OpenAgentSDK`
    /// already has internal access; this adds only a one-line indirection, no new behavior.
    internal func filterToolsForTesting(allowedTools: [String]?, disallowedTools: [String]?) -> [ToolProtocol] {
        return filterTools(allowedTools: allowedTools, disallowedTools: disallowedTools)
    }

    /// Create an Agent with the given options, execute its prompt, and return a SubAgentResult.
    private func executeAgent(prompt: String, options: AgentOptions) async -> SubAgentResult {
        let agent: Agent
        if let client = client {
            agent = Agent(options: options, client: client)
        } else {
            agent = Agent(options: options)
        }

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

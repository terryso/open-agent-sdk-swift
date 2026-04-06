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

    init(
        apiKey: String,
        baseURL: String?,
        parentModel: String,
        parentTools: [ToolProtocol]
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.parentModel = parentModel
        self.parentTools = parentTools
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
            systemPrompt: systemPrompt,
            maxTurns: resolvedMaxTurns,
            tools: subTools.isEmpty ? nil : subTools
        )
        let agent = Agent(options: options)

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
}

import Foundation

/// LLM provider selection for the agent.
public enum LLMProvider: String, Sendable, Equatable {
    case anthropic
    case openai
}

/// Configuration options for creating an agent.
public struct AgentOptions: Sendable {
    public var apiKey: String?
    public var model: String
    public var baseURL: String?
    public var provider: LLMProvider
    public var systemPrompt: String?
    public var maxTurns: Int
    public var maxTokens: Int
    public var maxBudgetUsd: Double?
    public var thinking: ThinkingConfig?
    public var permissionMode: PermissionMode
    public var canUseTool: CanUseToolFn?
    public var cwd: String?
    public var tools: [ToolProtocol]?
    public var mcpServers: [String: McpServerConfig]?
    public var retryConfig: RetryConfig?
    /// Optional agent name for identifying this agent in multi-agent scenarios.
    /// Used by messaging tools (e.g., SendMessage) to identify the sender.
    public var agentName: String?
    /// Optional mailbox store for inter-agent messaging.
    /// Injected into ToolContext for use by messaging tools.
    public var mailboxStore: MailboxStore?
    /// Optional team store for team management.
    /// Injected into ToolContext for use by messaging tools.
    public var teamStore: TeamStore?

    public init(
        apiKey: String? = nil,
        model: String = "claude-sonnet-4-6",
        baseURL: String? = nil,
        provider: LLMProvider = .anthropic,
        systemPrompt: String? = nil,
        maxTurns: Int = 10,
        maxTokens: Int = 16384,
        maxBudgetUsd: Double? = nil,
        thinking: ThinkingConfig? = nil,
        permissionMode: PermissionMode = .default,
        canUseTool: CanUseToolFn? = nil,
        cwd: String? = nil,
        tools: [ToolProtocol]? = nil,
        mcpServers: [String: McpServerConfig]? = nil,
        retryConfig: RetryConfig? = nil,
        agentName: String? = nil,
        mailboxStore: MailboxStore? = nil,
        teamStore: TeamStore? = nil
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.provider = provider
        self.systemPrompt = systemPrompt
        self.maxTurns = maxTurns
        self.maxTokens = maxTokens
        self.maxBudgetUsd = maxBudgetUsd
        self.thinking = thinking
        self.permissionMode = permissionMode
        self.canUseTool = canUseTool
        self.cwd = cwd
        self.tools = tools
        self.mcpServers = mcpServers
        self.retryConfig = retryConfig
        self.agentName = agentName
        self.mailboxStore = mailboxStore
        self.teamStore = teamStore
    }

    /// Create AgentOptions from an SDKConfiguration, using its resolved values
    /// as defaults for the core SDK properties. Agent-specific properties
    /// (systemPrompt, thinking, permissionMode, etc.) retain their defaults.
    ///
    /// - Parameter config: The SDK configuration providing base values.
    public init(from config: SDKConfiguration) {
        self.apiKey = config.apiKey
        self.model = config.model
        self.baseURL = config.baseURL
        self.provider = .anthropic
        self.maxTurns = config.maxTurns
        self.maxTokens = config.maxTokens
        self.systemPrompt = nil
        self.maxBudgetUsd = nil
        self.thinking = nil
        self.permissionMode = .default
        self.canUseTool = nil
        self.cwd = nil
        self.tools = nil
        self.mcpServers = nil
        self.retryConfig = nil
        self.agentName = nil
        self.mailboxStore = nil
        self.teamStore = nil
    }
}

/// Status of a completed agent query.
public enum QueryStatus: String, Sendable, Equatable {
    /// The query completed successfully (terminated by end_turn or stop_sequence).
    case success
    /// The agent loop exceeded the configured maxTurns limit.
    case errorMaxTurns
    /// An API error occurred during execution (HTTP error, network failure, etc.).
    case errorDuringExecution
    /// The accumulated cost exceeded the configured maxBudgetUsd limit.
    case errorMaxBudgetUsd
}

/// Result of a completed agent query.
public struct QueryResult: Sendable {
    public let text: String
    public let usage: TokenUsage
    public let numTurns: Int
    public let durationMs: Int
    public let messages: [SDKMessage]
    public let status: QueryStatus
    public let totalCostUsd: Double

    public init(text: String, usage: TokenUsage, numTurns: Int, durationMs: Int, messages: [SDKMessage], status: QueryStatus = .success, totalCostUsd: Double = 0.0) {
        self.text = text
        self.usage = usage
        self.numTurns = numTurns
        self.durationMs = durationMs
        self.messages = messages
        self.status = status
        self.totalCostUsd = totalCostUsd
    }
}

/// Definition of a sub-agent that can be spawned.
public struct AgentDefinition: Sendable {
    public let name: String
    public let description: String?
    public let model: String?
    public let systemPrompt: String?
    /// Optional list of allowed tool names for the sub-agent.
    /// When nil, the sub-agent inherits all parent tools (minus AgentTool).
    public let tools: [String]?
    /// Optional maximum number of turns for the sub-agent loop.
    /// When nil, defaults to 10.
    public let maxTurns: Int?

    public init(
        name: String,
        description: String? = nil,
        model: String? = nil,
        systemPrompt: String? = nil,
        tools: [String]? = nil,
        maxTurns: Int? = nil
    ) {
        self.name = name
        self.description = description
        self.model = model
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.maxTurns = maxTurns
    }
}

// MARK: - Sub-Agent Spawning

/// Result returned from a sub-agent execution.
public struct SubAgentResult: Sendable, Equatable {
    public let text: String
    public let toolCalls: [String]
    public let isError: Bool

    public init(text: String, toolCalls: [String] = [], isError: Bool = false) {
        self.text = text
        self.toolCalls = toolCalls
        self.isError = isError
    }
}

/// Protocol for spawning sub-agents, defined in Types/ to allow
/// Tools/ to use it without importing Core/.
///
/// Core/ provides the concrete ``DefaultSubAgentSpawner`` implementation.
/// Tools/ accesses the spawner through ``ToolContext/agentSpawner``.
public protocol SubAgentSpawner: Sendable {
    func spawn(
        prompt: String,
        model: String?,
        systemPrompt: String?,
        allowedTools: [String]?,
        maxTurns: Int?
    ) async -> SubAgentResult
}

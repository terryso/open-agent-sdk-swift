import Foundation

/// Configuration options for creating an agent.
public struct AgentOptions: Sendable {
    public var apiKey: String?
    public var model: String
    public var baseURL: String?
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

    public init(
        apiKey: String? = nil,
        model: String = "claude-sonnet-4-6",
        baseURL: String? = nil,
        systemPrompt: String? = nil,
        maxTurns: Int = 10,
        maxTokens: Int = 16384,
        maxBudgetUsd: Double? = nil,
        thinking: ThinkingConfig? = nil,
        permissionMode: PermissionMode = .default,
        canUseTool: CanUseToolFn? = nil,
        cwd: String? = nil,
        tools: [ToolProtocol]? = nil,
        mcpServers: [String: McpServerConfig]? = nil
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
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
}

/// Result of a completed agent query.
public struct QueryResult: Sendable {
    public let text: String
    public let usage: TokenUsage
    public let numTurns: Int
    public let durationMs: Int
    public let messages: [SDKMessage]
    public let status: QueryStatus

    public init(text: String, usage: TokenUsage, numTurns: Int, durationMs: Int, messages: [SDKMessage], status: QueryStatus = .success) {
        self.text = text
        self.usage = usage
        self.numTurns = numTurns
        self.durationMs = durationMs
        self.messages = messages
        self.status = status
    }
}

/// Definition of a sub-agent that can be spawned.
public struct AgentDefinition: Sendable {
    public let name: String
    public let description: String?
    public let model: String?
    public let systemPrompt: String?

    public init(name: String, description: String? = nil, model: String? = nil, systemPrompt: String? = nil) {
        self.name = name
        self.description = description
        self.model = model
        self.systemPrompt = systemPrompt
    }
}

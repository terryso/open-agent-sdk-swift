import Foundation

/// LLM provider selection for the agent.
///
/// Determines which API client implementation is used for communication.
/// The default provider is ``LLMProvider/anthropic``.
public enum LLMProvider: String, Sendable, Equatable {
    /// Anthropic API (Claude models).
    case anthropic
    /// OpenAI-compatible API.
    case openai
}

/// Configuration options for creating an agent.
///
/// `AgentOptions` controls all aspects of agent behavior including model selection,
/// tool registration, session persistence, multi-agent coordination, and permission enforcement.
///
/// ```swift
/// let options = AgentOptions(
///     apiKey: "sk-...",
///     model: "claude-sonnet-4-6",
///     systemPrompt: "You are a helpful assistant.",
///     maxTurns: 20,
///     tools: getAllBaseTools(tier: .core)
/// )
/// let agent = createAgent(options: options)
/// ```
public struct AgentOptions: Sendable {
    /// API key for authenticating with the LLM provider.
    public var apiKey: String?
    /// Model identifier to use for requests. Defaults to `"claude-sonnet-4-6"`.
    public var model: String
    /// Base URL for the LLM API endpoint. `nil` uses the provider default.
    public var baseURL: String?
    /// LLM provider to use. Defaults to ``LLMProvider/anthropic``.
    public var provider: LLMProvider
    /// System prompt for the agent. `nil` means no system prompt.
    public var systemPrompt: String?
    /// Maximum number of agent loop turns. Defaults to `10`.
    public var maxTurns: Int
    /// Maximum number of tokens per request. Defaults to `16384`.
    public var maxTokens: Int
    /// Optional budget limit in USD. When exceeded, the agent loop terminates.
    public var maxBudgetUsd: Double?
    /// Optional thinking/reasoning configuration for the model.
    public var thinking: ThinkingConfig?
    /// Permission mode controlling tool execution behavior. Defaults to ``PermissionMode/default``.
    public var permissionMode: PermissionMode
    /// Optional custom authorization callback for tool execution. Takes priority over `permissionMode`.
    public var canUseTool: CanUseToolFn?
    /// Working directory for tool execution context. Defaults to `nil`.
    public var cwd: String?
    /// Custom tools to register with the agent. `nil` means no custom tools.
    public var tools: [ToolProtocol]?
    /// MCP server configurations for external tool integration.
    public var mcpServers: [String: McpServerConfig]?
    /// Retry configuration for API calls.
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
    /// Optional task store for task management tools.
    /// Injected into ToolContext for use by task tools (TaskCreate, TaskList, etc.).
    public var taskStore: TaskStore?
    /// Optional worktree store for worktree management tools.
    /// Injected into ToolContext for use by worktree tools (EnterWorktree, ExitWorktree).
    public var worktreeStore: WorktreeStore?
    /// Optional plan store for plan management tools.
    /// Injected into ToolContext for use by plan tools (EnterPlanMode, ExitPlanMode).
    public var planStore: PlanStore?
    /// Optional cron store for cron management tools.
    /// Injected into ToolContext for use by cron tools (CronCreate, CronDelete, CronList).
    public var cronStore: CronStore?
    /// Optional todo store for todo management tools.
    /// Injected into ToolContext for use by todo tools (TodoWrite).
    public var todoStore: TodoStore?
    /// Optional session store for session persistence (save/load/restore).
    /// When provided with `sessionId`, Agent will auto-restore and auto-save sessions.
    public var sessionStore: SessionStore?
    /// Optional session ID for restoring a previously saved session.
    /// When provided with `sessionStore`, Agent restores history before prompt/stream
    /// and auto-saves updated messages after completion.
    public var sessionId: String?
    /// Optional hook registry for lifecycle event hooks.
    /// When set, hooks are triggered during Agent execution (FR28).
    public var hookRegistry: HookRegistry?
    /// Optional skill registry for skill execution.
    /// When set, the Skill tool is registered and skills can be discovered and invoked by the LLM.
    public var skillRegistry: SkillRegistry?
    /// Maximum allowed skill recursion depth. Defaults to 4.
    /// Prevents infinite loops when skills call other skills.
    public var maxSkillRecursionDepth: Int
    /// Maximum number of entries in the file cache. Defaults to 100.
    public var fileCacheMaxEntries: Int
    /// Maximum total size of the file cache in bytes. Defaults to 25 MB.
    public var fileCacheMaxSizeBytes: Int
    /// Maximum size of a single file cache entry in bytes. Defaults to 5 MB.
    public var fileCacheMaxEntrySizeBytes: Int

    /// Cache time-to-live for Git context collection, in seconds.
    /// Within this window, repeated calls reuse the cached Git status.
    /// Set to `0` to disable caching. Defaults to 5.0 seconds.
    public var gitCacheTTL: TimeInterval

    /// Explicit project root directory for instruction file discovery.
    /// When `nil`, the SDK discovers the project root by traversing upward
    /// from the current working directory looking for a `.git` directory.
    /// Defaults to `nil` (auto-discover).
    public var projectRoot: String?

    /// Minimum log level for SDK-internal logging. Defaults to ``LogLevel/none`` (silent).
    public var logLevel: LogLevel

    /// Output destination for log entries. Defaults to ``LogOutput/console`` (stderr).
    public var logOutput: LogOutput

    /// Optional sandbox settings for restricting agent tool execution.
    /// When `nil` (default), no sandbox restrictions are applied.
    /// Propagated to ``ToolContext`` for use during tool execution.
    public var sandbox: SandboxSettings?

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
        teamStore: TeamStore? = nil,
        taskStore: TaskStore? = nil,
        worktreeStore: WorktreeStore? = nil,
        planStore: PlanStore? = nil,
        cronStore: CronStore? = nil,
        todoStore: TodoStore? = nil,
        sessionStore: SessionStore? = nil,
        sessionId: String? = nil,
        hookRegistry: HookRegistry? = nil,
        skillRegistry: SkillRegistry? = nil,
        maxSkillRecursionDepth: Int = 4,
        fileCacheMaxEntries: Int = 100,
        fileCacheMaxSizeBytes: Int = 25 * 1024 * 1024,
        fileCacheMaxEntrySizeBytes: Int = 5 * 1024 * 1024,
        gitCacheTTL: TimeInterval = 5.0,
        projectRoot: String? = nil,
        logLevel: LogLevel = .none,
        logOutput: LogOutput = .console,
        sandbox: SandboxSettings? = nil
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
        self.taskStore = taskStore
        self.worktreeStore = worktreeStore
        self.planStore = planStore
        self.cronStore = cronStore
        self.todoStore = todoStore
        self.sessionStore = sessionStore
        self.sessionId = sessionId
        self.hookRegistry = hookRegistry
        self.skillRegistry = skillRegistry
        self.maxSkillRecursionDepth = maxSkillRecursionDepth
        self.fileCacheMaxEntries = fileCacheMaxEntries
        self.fileCacheMaxSizeBytes = fileCacheMaxSizeBytes
        self.fileCacheMaxEntrySizeBytes = fileCacheMaxEntrySizeBytes
        self.gitCacheTTL = gitCacheTTL
        self.projectRoot = projectRoot
        self.logLevel = logLevel
        self.logOutput = logOutput
        self.sandbox = sandbox
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
        self.taskStore = nil
        self.worktreeStore = nil
        self.planStore = nil
        self.cronStore = nil
        self.todoStore = nil
        self.sessionStore = nil
        self.sessionId = nil
        self.hookRegistry = nil
        self.skillRegistry = nil
        self.maxSkillRecursionDepth = 4
        self.fileCacheMaxEntries = config.fileCacheMaxEntries
        self.fileCacheMaxSizeBytes = config.fileCacheMaxSizeBytes
        self.fileCacheMaxEntrySizeBytes = config.fileCacheMaxEntrySizeBytes
        self.gitCacheTTL = config.gitCacheTTL
        self.projectRoot = config.projectRoot
        self.logLevel = config.logLevel
        self.logOutput = config.logOutput
        self.sandbox = config.sandbox
    }

    /// Validate the options, throwing if any configuration is invalid.
    ///
    /// Checks:
    /// - `baseURL` (if non-nil) must be a valid URL string parseable by `URL(string:)`.
    /// - `thinking` (if non-nil) must pass ``ThinkingConfig/validate()``.
    ///
    /// - Throws: ``SDKError/invalidConfiguration`` if any check fails.
    public func validate() throws {
        if let baseURL {
            guard URL(string: baseURL) != nil else {
                throw SDKError.invalidConfiguration("Invalid baseURL: '\(baseURL)' is not a valid URL")
            }
        }
        try thinking?.validate()
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
    /// The query was cancelled by the user (via Task.cancel() or Agent.interrupt()).
    case cancelled
}

/// Per-model cost entry for cost breakdown tracking.
///
/// Each entry records the token usage and estimated cost attributed to a specific
/// model during an agent query. When the model is switched mid-session, multiple
/// entries are produced -- one per model used.
public struct CostBreakdownEntry: Sendable, Equatable {
    /// The model identifier this entry tracks.
    public let model: String
    /// Total input tokens consumed by this model.
    public let inputTokens: Int
    /// Total output tokens produced by this model.
    public let outputTokens: Int
    /// Estimated cost in USD for this model's usage.
    public let costUsd: Double

    public init(model: String, inputTokens: Int, outputTokens: Int, costUsd: Double) {
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costUsd = costUsd
    }
}

/// Result of a completed agent query.
///
/// Contains the final response text, token usage statistics, timing information,
/// all messages collected during the query, and the termination status.
public struct QueryResult: Sendable {
    /// The assistant's response text.
    public let text: String
    /// Token usage statistics for the query.
    public let usage: TokenUsage
    /// Number of agent loop turns completed.
    public let numTurns: Int
    /// Total query duration in milliseconds.
    public let durationMs: Int
    /// Messages collected during the query.
    public let messages: [SDKMessage]
    /// Status indicating how the query terminated.
    public let status: QueryStatus
    /// Total cost in USD for this query.
    public let totalCostUsd: Double
    /// Per-model cost breakdown for this query.
    public let costBreakdown: [CostBreakdownEntry]
    /// Whether the query was cancelled by the user.
    public let isCancelled: Bool

    public init(text: String, usage: TokenUsage, numTurns: Int, durationMs: Int, messages: [SDKMessage], status: QueryStatus = .success, totalCostUsd: Double = 0.0, costBreakdown: [CostBreakdownEntry] = [], isCancelled: Bool = false) {
        self.text = text
        self.usage = usage
        self.numTurns = numTurns
        self.durationMs = durationMs
        self.messages = messages
        self.status = status
        self.totalCostUsd = totalCostUsd
        self.costBreakdown = costBreakdown
        self.isCancelled = isCancelled
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
/// Core/ provides a concrete implementation. Tools/ accesses the spawner
/// through ``ToolContext/agentSpawner``.
public protocol SubAgentSpawner: Sendable {
    func spawn(
        prompt: String,
        model: String?,
        systemPrompt: String?,
        allowedTools: [String]?,
        maxTurns: Int?
    ) async -> SubAgentResult
}

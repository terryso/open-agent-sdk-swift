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

// MARK: - EffortLevel

/// Effort level controlling the model's reasoning depth.
///
/// Maps to API-level thinking budget tokens. Higher effort levels produce
/// more thorough reasoning at the cost of increased latency and token usage.
///
/// ```swift
/// let options = AgentOptions(effort: .high)
/// ```
public enum EffortLevel: String, Sendable, Equatable, CaseIterable {
    /// Low effort -- minimal reasoning, fastest response.
    case low
    /// Medium effort -- balanced reasoning and speed.
    case medium
    /// High effort -- thorough reasoning.
    case high
    /// Maximum effort -- deepest reasoning, highest token usage.
    case max

    /// The thinking budget tokens associated with this effort level.
    ///
    /// Maps to the `budget_tokens` parameter in the API thinking configuration:
    /// - `.low` = 1024 tokens
    /// - `.medium` = 5120 tokens
    /// - `.high` = 10240 tokens
    /// - `.max` = 32768 tokens
    public var budgetTokens: Int {
        switch self {
        case .low: return 1024
        case .medium: return 5120
        case .high: return 10240
        case .max: return 32768
        }
    }
}

// MARK: - SendableJSONSchema

/// A type-erased Sendable wrapper for JSON Schema dictionaries.
///
/// Used by ``OutputFormat`` to hold arbitrary JSON Schema definitions
/// while maintaining Sendable conformance. The schema value is expected
/// to be a valid JSON Schema object but this is not enforced at compile time.
public struct SendableJSONSchema: @unchecked Sendable, Equatable {
    /// The underlying JSON Schema dictionary.
    public let schema: [String: Any]

    /// Creates a SendableJSONSchema wrapping the given schema dictionary.
    ///
    /// - Parameter schema: A JSON Schema dictionary.
    public init(schema: [String: Any]) {
        self.schema = schema
    }

    public static func == (lhs: SendableJSONSchema, rhs: SendableJSONSchema) -> Bool {
        return NSDictionary(dictionary: lhs.schema).isEqual(to: rhs.schema)
    }
}

// MARK: - OutputFormat

/// Output format configuration for structured output requests.
///
/// When set on ``AgentOptions``, requests the API to produce output conforming
/// to the provided JSON Schema.
///
/// ```swift
/// let schema: [String: Any] = [
///     "type": "object",
///     "properties": ["answer": ["type": "string"]]
/// ]
/// let format = OutputFormat(jsonSchema: schema)
/// ```
public struct OutputFormat: Sendable, Equatable {
    /// The format type, always `"json_schema"`.
    public let type: String

    /// The JSON Schema describing the expected output structure.
    private let _jsonSchema: SendableJSONSchema

    /// The JSON Schema dictionary describing the expected output.
    public var jsonSchema: [String: Any] {
        return _jsonSchema.schema
    }

    /// Creates an OutputFormat with the given JSON Schema.
    ///
    /// - Parameter jsonSchema: A JSON Schema dictionary describing the expected output.
    public init(jsonSchema: [String: Any]) {
        self.type = "json_schema"
        self._jsonSchema = SendableJSONSchema(schema: jsonSchema)
    }

    public static func == (lhs: OutputFormat, rhs: OutputFormat) -> Bool {
        return lhs.type == rhs.type && lhs._jsonSchema == rhs._jsonSchema
    }
}

// MARK: - ToolConfig

/// Configuration for tool execution behavior.
///
/// Controls concurrency limits for read and write tool operations.
///
/// ```swift
/// let config = ToolConfig(maxConcurrentReadTools: 5, maxConcurrentWriteTools: 2)
/// ```
public struct ToolConfig: Sendable, Equatable {
    /// Maximum number of concurrent read-only tool executions.
    /// When `nil`, the default concurrency limit is used.
    public let maxConcurrentReadTools: Int?

    /// Maximum number of concurrent write tool executions.
    /// When `nil`, the default concurrency limit is used.
    public let maxConcurrentWriteTools: Int?

    /// Creates a ToolConfig with optional concurrency limits.
    ///
    /// - Parameters:
    ///   - maxConcurrentReadTools: Maximum concurrent read tools. Defaults to `nil`.
    ///   - maxConcurrentWriteTools: Maximum concurrent write tools. Defaults to `nil`.
    public init(maxConcurrentReadTools: Int? = nil, maxConcurrentWriteTools: Int? = nil) {
        self.maxConcurrentReadTools = maxConcurrentReadTools
        self.maxConcurrentWriteTools = maxConcurrentWriteTools
    }
}

// MARK: - SystemPromptConfig

/// Configuration for the agent's system prompt, supporting both plain text and presets.
///
/// ```swift
/// // Plain text prompt
/// let textConfig = SystemPromptConfig.text("You are a helpful assistant.")
///
/// // Preset prompt with optional append
/// let presetConfig = SystemPromptConfig.preset(name: "claude_code", append: "Be concise.")
/// ```
public enum SystemPromptConfig: Sendable, Equatable {
    /// A plain text system prompt.
    case text(String)

    /// A preset system prompt identified by name, with an optional appended string.
    ///
    /// Known preset names include `"claude_code"` (standard Code agent prompt).
    case preset(name: String, append: String?)
}

// MARK: - AgentOptions

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
    /// Directories to scan for SKILL.md-based skill packages.
    /// When `nil`, uses default directories (`~/.agents/skills`, `~/.claude/skills`, etc.).
    /// When set, only the specified directories are scanned.
    /// Skills are automatically discovered, registered in `skillRegistry`, and a SkillTool is injected.
    public var skillDirectories: [String]?
    /// Optional whitelist of skill names to load. When `nil`, all discovered skills are registered.
    /// When set, only skills whose names appear in this list are registered.
    public var skillNames: [String]?
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

    // MARK: - Story 17-2: New Fields

    /// Optional fallback model identifier. When the primary model is unavailable or
    /// fails, the agent will retry with this model.
    public var fallbackModel: String?

    /// Optional environment variables to inject into tool execution context.
    /// Keys and values are both strings, e.g. `["HOME": "/custom/home"]`.
    public var env: [String: String]?

    /// Optional whitelist of tool names the agent is allowed to use.
    /// When `nil`, all registered tools are available. When set, only tools
    /// whose names appear in this list are available to the LLM.
    public var allowedTools: [String]?

    /// Optional blacklist of tool names the agent is denied from using.
    /// Takes priority over `allowedTools` -- if a tool name appears in both
    /// lists, it is blocked.
    public var disallowedTools: [String]?

    /// Optional effort level controlling the model's reasoning depth.
    /// Maps to API-level thinking budget tokens when set.
    public var effort: EffortLevel?

    /// Optional output format for structured output requests.
    /// When set, requests the API to produce output conforming to the
    /// provided JSON Schema.
    public var outputFormat: OutputFormat?

    /// Optional tool behavior configuration controlling concurrency limits.
    public var toolConfig: ToolConfig?

    /// Whether to include partial (streaming) messages in the SDKMessage stream.
    /// Defaults to `true`. Set to `false` to receive only complete messages.
    public var includePartialMessages: Bool

    /// Whether to generate prompt suggestions after the query completes.
    /// Defaults to `false`.
    public var promptSuggestions: Bool

    /// Whether to continue the most recent session for this agent.
    /// When `true` and a session store is configured, the agent will restore
    /// the latest session. Defaults to `false`.
    public var continueRecentSession: Bool

    /// Whether to fork the current session into a new session.
    /// When `true`, the current conversation history is copied into a new session.
    /// Defaults to `false`.
    public var forkSession: Bool

    /// Optional message ID at which to resume the session. When set, the session
    /// history is truncated to this point before the new prompt is appended.
    public var resumeSessionAt: String?

    /// Whether to persist the session after the query completes.
    /// When `true` (default), the agent auto-saves the updated session.
    /// Set to `false` for ephemeral sessions that should not be persisted.
    public var persistSession: Bool

    /// Optional system prompt configuration supporting preset prompts.
    /// When set, takes priority over the plain `systemPrompt` string.
    public var systemPromptConfig: SystemPromptConfig?

    // MARK: - Memberwise Init

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
        skillDirectories: [String]? = nil,
        skillNames: [String]? = nil,
        maxSkillRecursionDepth: Int = 4,
        fileCacheMaxEntries: Int = 100,
        fileCacheMaxSizeBytes: Int = 25 * 1024 * 1024,
        fileCacheMaxEntrySizeBytes: Int = 5 * 1024 * 1024,
        gitCacheTTL: TimeInterval = 5.0,
        projectRoot: String? = nil,
        logLevel: LogLevel = .none,
        logOutput: LogOutput = .console,
        sandbox: SandboxSettings? = nil,
        fallbackModel: String? = nil,
        env: [String: String]? = nil,
        allowedTools: [String]? = nil,
        disallowedTools: [String]? = nil,
        effort: EffortLevel? = nil,
        outputFormat: OutputFormat? = nil,
        toolConfig: ToolConfig? = nil,
        includePartialMessages: Bool = true,
        promptSuggestions: Bool = false,
        continueRecentSession: Bool = false,
        forkSession: Bool = false,
        resumeSessionAt: String? = nil,
        persistSession: Bool = true,
        systemPromptConfig: SystemPromptConfig? = nil
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
        self.skillDirectories = skillDirectories
        self.skillNames = skillNames
        self.maxSkillRecursionDepth = maxSkillRecursionDepth
        self.fileCacheMaxEntries = fileCacheMaxEntries
        self.fileCacheMaxSizeBytes = fileCacheMaxSizeBytes
        self.fileCacheMaxEntrySizeBytes = fileCacheMaxEntrySizeBytes
        self.gitCacheTTL = gitCacheTTL
        self.projectRoot = projectRoot
        self.logLevel = logLevel
        self.logOutput = logOutput
        self.sandbox = sandbox
        self.fallbackModel = fallbackModel
        self.env = env
        self.allowedTools = allowedTools
        self.disallowedTools = disallowedTools
        self.effort = effort
        self.outputFormat = outputFormat
        self.toolConfig = toolConfig
        self.includePartialMessages = includePartialMessages
        self.promptSuggestions = promptSuggestions
        self.continueRecentSession = continueRecentSession
        self.forkSession = forkSession
        self.resumeSessionAt = resumeSessionAt
        self.persistSession = persistSession
        self.systemPromptConfig = systemPromptConfig
    }

    // MARK: - Auto-Discover Skills

    /// Auto-discovers skills from filesystem and sets up the skill registry and tools.
    ///
    /// When `skillDirectories` or `skillNames` is set, this method:
    /// 1. Creates a `SkillRegistry` if one doesn't already exist
    /// 2. Discovers skills from the specified (or default) directories
    /// 3. Filters by `skillNames` if specified
    /// 4. Registers discovered skills into the registry
    /// 5. Injects a `SkillTool` into the `tools` array
    mutating func autoDiscoverSkills() {
        guard skillDirectories != nil || skillNames != nil else { return }

        // Create registry if not already provided
        if skillRegistry == nil {
            skillRegistry = SkillRegistry()
        }

        // Discover and register skills
        let count = skillRegistry!.registerDiscoveredSkills(
            from: skillDirectories,
            skillNames: skillNames
        )

        if count > 0 {
            Logger.shared.info("Agent", "skills_discovered", data: [
                "count": String(count)
            ])

            // Inject SkillTool into tools array
            let skillTool = createSkillTool(registry: skillRegistry!)
            if var existingTools = tools {
                existingTools.append(skillTool)
                tools = existingTools
            } else {
                tools = [skillTool]
            }
        }
    }

    // MARK: - Config-Based Init

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
        // Story 17-2 new fields -- all defaults
        self.fallbackModel = nil
        self.env = nil
        self.allowedTools = nil
        self.disallowedTools = nil
        self.effort = nil
        self.outputFormat = nil
        self.toolConfig = nil
        self.includePartialMessages = true
        self.promptSuggestions = false
        self.continueRecentSession = false
        self.forkSession = false
        self.resumeSessionAt = nil
        self.persistSession = true
        self.systemPromptConfig = nil
    }

    // MARK: - Validation

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
        if let fallbackModel {
            let trimmed = fallbackModel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw SDKError.invalidConfiguration("fallbackModel must be non-empty if set")
            }
        }
        if let outputFormat {
            guard !outputFormat.jsonSchema.isEmpty else {
                throw SDKError.invalidConfiguration("outputFormat.jsonSchema must be a non-empty schema")
            }
        }
        if let allowedTools, allowedTools.isEmpty {
            throw SDKError.invalidConfiguration("allowedTools must be non-empty if set (or nil for all tools)")
        }
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

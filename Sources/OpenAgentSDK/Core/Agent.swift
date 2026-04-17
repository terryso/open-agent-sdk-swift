import Foundation

/// An AI agent that processes prompts using an LLM API.
///
/// `Agent` holds immutable configuration and an internal ``LLMClient`` for
/// communicating with the LLM provider. Create instances using the module-level
/// ``createAgent(options:)`` factory function.
///
/// ## Usage
///
/// ```swift
/// let agent = createAgent(options: AgentOptions(apiKey: "sk-...", model: "claude-sonnet-4-6"))
/// print(agent.model)        // "claude-sonnet-4-6"
/// print(agent.systemPrompt) // nil
/// ```
///
/// - Note: API key is intentionally not exposed as a public property (NFR6).
public class Agent: CustomStringConvertible, CustomDebugStringConvertible, @unchecked Sendable {

    // MARK: - Public Read-Only Properties

    /// The model identifier used for API requests.
    ///
    /// Use ``switchModel(_:)`` to change the model at runtime. The property is
    /// externally read-only but can be mutated internally via ``switchModel(_:)``.
    public private(set) var model: String

    /// The system prompt provided to the agent, or `nil` if none was specified.
    public let systemPrompt: String?

    /// Maximum number of agent loop turns.
    public let maxTurns: Int

    /// Maximum number of tokens per request.
    public let maxTokens: Int

    // MARK: - Internal Properties

    /// Whether the current query has been interrupted via ``interrupt()``.
    /// Checked alongside `_Concurrency.Task.isCancelled` in prompt() and stream() loops.
    /// Uses `nonisolated(unsafe)` because it's a simple Bool flag set by interrupt()
    /// and read cooperatively by the running Task — no locking needed.
    nonisolated(unsafe) private var _interrupted: Bool = false

    /// Whether the agent has been permanently closed via ``close()``.
    /// Once closed, all subsequent prompt/stream/interrupt calls throw.
    /// Protected by ``_closedLock`` for thread-safe reads from concurrent contexts.
    private var _closed: Bool = false

    /// Lock protecting concurrent access to ``_closed``.
    private let _closedLock: NSLock = {
        let lock = NSLock()
        lock.name = "Agent.closedLock"
        return lock
    }()

    /// Reference to stream()'s internal Task for cancellation via interrupt().
    /// Cleared when the stream completes.
    private var _streamTask: _Concurrency.Task<Void, Never>?

    /// The full agent options (used internally for prompt/stream calls).
    var options: AgentOptions

    /// Lock protecting concurrent access to `options` permission-related fields.
    private let _permissionLock: NSLock = {
        let lock = NSLock()
        lock.name = "Agent.permissionLock"
        return lock
    }()

    /// The LLM API client used for communication.
    let client: any LLMClient

    /// Git context collector for injecting repository status into system prompts.
    /// Per-agent instance; cache lifecycle matches the Agent instance.
    private let gitContextCollector = GitContextCollector()

    /// Project document discovery for injecting project-level instructions into system prompts.
    /// Per-agent instance; cache lifecycle matches the Agent instance.
    private let projectDocumentDiscovery = ProjectDocumentDiscovery()

    /// Session memory for retaining key context across queries within the agent's lifetime.
    /// Populated after auto-compact completes; injected into system prompt on subsequent queries.
    private let sessionMemory = SessionMemory()

    /// Stored MCP client manager for runtime management operations.
    /// Set after the first call to ``assembleFullToolPool()`` or ``setMcpServers(_:)``.
    private var mcpClientManager: MCPClientManager?

    // MARK: - Initialization

    /// Create an Agent with the given options.
    ///
    /// The agent stores the options and creates an internal ``LLMClient``
    /// for API communication. If `apiKey` is `nil`, the agent can still be created
    /// but subsequent prompt/stream calls will fail due to missing authentication.
    ///
    /// - Parameter options: The configuration options for this agent.
    public convenience init(options: AgentOptions) {
        self.init(mergedOptions: options, client: nil)
    }

    /// Create an Agent with the given options and a pre-configured ``LLMClient``.
    ///
    /// This initializer is intended for testing and advanced scenarios where the
    /// caller needs to control the client configuration (e.g., custom
    /// URLSession for mock network interception).
    ///
    /// - Parameters:
    ///   - options: The configuration options for this agent.
    ///   - client: A pre-configured ``LLMClient`` instance to use for API calls.
    public convenience init(options: AgentOptions, client: any LLMClient) {
        self.init(mergedOptions: options, client: client)
    }

    /// Create an Agent with a definition and options.
    ///
    /// This initializer accepts an ``AgentDefinition`` (typically used for sub-agents)
    /// alongside standard ``AgentOptions``. Fields from the definition are merged
    /// into the options where applicable.
    ///
    /// - Parameters:
    ///   - definition: The agent definition providing name and optional overrides.
    ///   - options: The configuration options for this agent.
    public convenience init(definition: AgentDefinition, options: AgentOptions) {
        var mergedOptions = options
        if let model = definition.model { mergedOptions.model = model }
        if let prompt = definition.systemPrompt { mergedOptions.systemPrompt = prompt }
        if let maxTurns = definition.maxTurns { mergedOptions.maxTurns = maxTurns }
        self.init(mergedOptions: mergedOptions, client: nil)
    }

    /// Shared designated initializer that all public convenience initializers delegate to.
    ///
    /// - Parameters:
    ///   - mergedOptions: The fully resolved options (definition fields already merged if applicable).
    ///   - prebuiltClient: An optional pre-configured ``LLMClient``. When `nil`, a client
    ///     is created from the options based on the provider.
    private init(mergedOptions: AgentOptions, client prebuiltClient: (any LLMClient)?) {
        self.options = mergedOptions
        self.model = mergedOptions.model
        self.systemPrompt = mergedOptions.systemPrompt
        self.maxTurns = mergedOptions.maxTurns
        self.maxTokens = mergedOptions.maxTokens

        // Configure Logger from agent options if non-default values are provided.
        if mergedOptions.logLevel != .none || mergedOptions.logOutput != .console {
            Logger.configure(level: mergedOptions.logLevel, output: mergedOptions.logOutput)
        }

        // Auto-discover skills from filesystem if skillDirectories or skillNames is specified
        self.options.autoDiscoverSkills()

        // Soft validation: warn on invalid baseURL or thinking config.
        if let baseURL = mergedOptions.baseURL, URL(string: baseURL) == nil {
            Logger.shared.info("Agent", "invalid_config", data: [
                "field": "baseURL",
                "warning": "Invalid baseURL will fall back to provider default"
            ])
        }
        if let thinking = mergedOptions.thinking, case .enabled(let budget) = thinking, budget <= 0 {
            Logger.shared.info("Agent", "invalid_config", data: [
                "field": "thinking.budgetTokens",
                "value": String(budget),
                "warning": "budgetTokens must be positive"
            ])
        }

        // Create the appropriate client based on provider.
        if let prebuiltClient {
            self.client = prebuiltClient
        } else {
            let apiKey = mergedOptions.apiKey ?? ""
            switch mergedOptions.provider {
            case .openai:
                self.client = OpenAIClient(
                    apiKey: apiKey,
                    baseURL: mergedOptions.baseURL
                )
            case .anthropic:
                self.client = AnthropicClient(
                    apiKey: apiKey,
                    baseURL: mergedOptions.baseURL
                )
            }
        }
    }

    // MARK: - Dynamic Permission Switching

    /// Changes the permission mode for subsequent tool executions.
    ///
    /// This also clears any custom `canUseTool` callback, so the new
    /// permission mode takes effect immediately.
    ///
    /// - Parameter mode: The new permission mode to use.
    public func setPermissionMode(_ mode: PermissionMode) {
        _permissionLock.withLock {
            options.permissionMode = mode
            options.canUseTool = nil
        }
    }

    /// Sets a custom authorization callback for subsequent tool executions.
    ///
    /// The callback takes priority over the configured ``AgentOptions/permissionMode``.
    /// To revert to permission-mode-based behavior, call ``setPermissionMode(_:)``.
    ///
    /// - Parameter callback: The authorization callback, or nil to clear it.
    public func setCanUseTool(_ callback: CanUseToolFn?) {
        _permissionLock.withLock {
            options.canUseTool = callback
        }
    }

    // MARK: - Dynamic Model Switching

    /// Switches the LLM model used for subsequent API requests.
    ///
    /// After calling this method, the next ``prompt(_:)`` or ``stream(_:)`` invocation
    /// will use the new model. Any in-progress stream continues to use the model that
    /// was active when it started.
    ///
    /// - Parameter model: The new model identifier. Must be a non-empty, non-whitespace string.
    /// - Throws: ``SDKError/invalidConfiguration`` if the model name is empty or whitespace-only.
    ///   No whitelist validation is performed -- unknown model names are allowed and any
    ///   API errors (e.g., 404) are reported at query time.
    public func switchModel(_ model: String) throws {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SDKError.invalidConfiguration("Model name cannot be empty")
        }
        let oldModel = self.model
        self.model = trimmed
        self.options.model = trimmed
        Logger.shared.info("Agent", "model_switch", data: ["from": oldModel, "to": trimmed])
    }

    // MARK: - Query Cancellation

    /// Interrupts the currently executing query.
    ///
    /// This is a convenience method that cancels the internal task reference
    /// tracking the current ``prompt(_:)`` or ``stream(_:)`` call.
    /// You can also cancel queries directly using `Task.cancel()` on the task
    /// wrapping the prompt/stream call -- both mechanisms are equivalent because
    /// Swift uses cooperative cancellation.
    ///
    /// If no query is currently running, this method does nothing.
    public func interrupt() {
        _interrupted = true
        _streamTask?.cancel()
    }

    // MARK: - File Checkpointing (rewindFiles)

    /// Internal file checkpoint tracking per message ID.
    /// Maps message IDs to the set of file paths written/modified during that turn.
    /// Protected by ``_checkpointLock`` for thread-safe access.
    private var _fileCheckpoints: [String: Set<String>] = [:]

    /// Lock protecting concurrent access to ``_fileCheckpoints``.
    private let _checkpointLock: NSLock = {
        let lock = NSLock()
        lock.name = "Agent.checkpointLock"
        return lock
    }()

    /// Thread-safe read of ``_closed``.
    private var isClosed: Bool {
        _closedLock.withLock { _closed }
    }

    /// Thread-safe write to ``_closed``.
    private func setClosed(_ value: Bool) {
        _closedLock.withLock { _closed = value }
    }

    /// Record a file checkpoint for the current message being processed.
    ///
    /// Called internally by file tools to track which files were modified during a turn.
    /// - Parameters:
    ///   - filePath: The path of the file that was written or modified.
    ///   - messageId: The message ID associated with this checkpoint.
    func recordFileCheckpoint(filePath: String, messageId: String) {
        _checkpointLock.withLock {
            if _fileCheckpoints[messageId] != nil {
                _fileCheckpoints[messageId]?.insert(filePath)
            } else {
                _fileCheckpoints[messageId] = [filePath]
            }
        }
    }

    /// Restores the file system to the state at a given message.
    ///
    /// When `dryRun` is `true`, returns a preview of the files that would be affected
    /// without making any actual changes.
    ///
    /// - Parameters:
    ///   - messageId: The message ID to rewind to.
    ///   - dryRun: When `true`, return a preview without modifying files. Defaults to `false`.
    /// - Returns: A ``RewindResult`` describing the affected files and outcome.
    /// - Note: When no checkpoint exists for the given `messageId`, returns an empty result
    ///   with `success: true` rather than throwing. The `throws` annotation is reserved for
    ///   future content-restoration errors.
    public func rewindFiles(to messageId: String, dryRun: Bool = false) async throws -> RewindResult {
        let files = _checkpointLock.withLock { _fileCheckpoints[messageId] }

        guard let files else {
            return RewindResult(filesAffected: [], success: true, preview: dryRun)
        }

        let affectedFiles = Array(files).sorted()

        if dryRun {
            return RewindResult(filesAffected: affectedFiles, success: true, preview: true)
        }

        // Full mode: lightweight implementation tracks file paths only.
        // Actual content restoration requires a full checkpointing system that
        // stores original content before modification — not yet implemented.
        return RewindResult(filesAffected: affectedFiles, success: false, preview: false)
    }

    // MARK: - Multi-Turn Streaming Input (streamInput)

    /// Supports multi-turn streaming dialog by accepting an `AsyncStream<String>` input.
    ///
    /// Each element from the input stream is treated as a new user message. When the input
    /// stream completes, the final aggregated response is emitted and the stream finishes.
    ///
    /// - Parameter input: An `AsyncStream<String>` producing user messages.
    /// - Returns: An `AsyncStream<SDKMessage>` yielding events for each turn and the final result.
    public func streamInput(_ input: AsyncStream<String>) -> AsyncStream<SDKMessage> {
        // Guard: bail out immediately if already closed
        if isClosed {
            return AsyncStream<SDKMessage> { $0.finish() }
        }
        // Capture sessionId before entering the closure (consistent with stream() pattern).
        let capturedSessionId = options.sessionId
        return AsyncStream<SDKMessage> { continuation in
            let task = _Concurrency.Task {
                for await text in input {
                    if _Concurrency.Task.isCancelled || self.isClosed { break }

                    // Yield a user message event for each incoming chunk
                    continuation.yield(.userMessage(SDKMessage.UserMessageData(
                        sessionId: capturedSessionId,
                        message: text
                    )))

                    // Process this turn via the existing promptImpl logic
                    let result = await self.promptImpl(text)

                    // Yield the result for this turn
                    let subtype: SDKMessage.ResultData.Subtype
                    switch result.status {
                    case .success:
                        subtype = .success
                    case .errorMaxTurns:
                        subtype = .errorMaxTurns
                    case .errorMaxBudgetUsd:
                        subtype = .errorMaxBudgetUsd
                    case .cancelled:
                        subtype = .cancelled
                    case .errorDuringExecution:
                        subtype = .errorDuringExecution
                    }

                    continuation.yield(.result(SDKMessage.ResultData(
                        subtype: subtype,
                        text: result.text,
                        usage: result.usage,
                        numTurns: result.numTurns,
                        durationMs: result.durationMs,
                        totalCostUsd: result.totalCostUsd,
                        costBreakdown: result.costBreakdown
                    )))
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Task Management (stopTask)

    /// Stops a background task by ID.
    ///
    /// Delegates to the configured ``TaskStore`` to remove the task. Throws if no
    /// ``TaskStore`` is configured or the task ID is not found.
    ///
    /// - Parameter taskId: The ID of the task to stop.
    /// - Throws: ``SDKError/invalidConfiguration`` if no TaskStore is configured.
    ///   ``SDKError/notFound`` if the task ID is not found.
    public func stopTask(taskId: String) async throws {
        guard let taskStore = options.taskStore else {
            throw SDKError.invalidConfiguration("TaskStore is not configured. Set AgentOptions.taskStore to use stopTask().")
        }
        let deleted = await taskStore.delete(id: taskId)
        guard deleted else {
            throw SDKError.notFound("Task with ID '\(taskId)' not found.")
        }
    }

    // MARK: - Agent Lifecycle (close)

    /// Permanently closes the agent.
    ///
    /// After calling this method:
    /// - Any active query is interrupted.
    /// - The session is persisted (if a ``SessionStore`` is configured).
    /// - MCP connections are shut down.
    /// - All subsequent calls to ``prompt(_:)`` and ``stream(_:)`` return an error result.
    ///
    /// - Throws: ``SDKError/invalidConfiguration`` if the agent is already closed.
    public func close() async throws {
        // Atomically check-and-set to prevent TOCTOU race between two concurrent close() calls.
        let wasAlreadyClosed = _closedLock.withLock { () -> Bool in
            if _closed { return true }
            _closed = true
            return false
        }
        guard !wasAlreadyClosed else {
            throw SDKError.invalidConfiguration("Agent is already closed.")
        }

        // Interrupt any active query
        interrupt()

        // Persist session marker if sessionStore is configured and persistSession is enabled.
        // We do NOT overwrite with empty messages — the last promptImpl/stream call already
        // saved the full conversation. We only save a marker here if no prior session exists.
        if let sessionStore = options.sessionStore, let sessionId = options.sessionId,
           options.persistSession {
            // Only save if the session doesn't already exist (avoid overwriting real history).
            let existing = try? await sessionStore.load(sessionId: sessionId)
            if existing == nil {
                let metadata = PartialSessionMetadata(
                    cwd: options.cwd ?? FileManager.default.currentDirectoryPath,
                    model: model,
                    summary: nil
                )
                _ = try? await sessionStore.save(sessionId: sessionId, messages: [], metadata: metadata)
            }
        }

        // Shutdown MCP connections
        if let mcpManager = mcpClientManager {
            await mcpManager.shutdown()
            mcpClientManager = nil
        }
    }

    // MARK: - Initialization Info (initializationResult)

    /// Returns initialization metadata including available commands, agents, models, and configuration.
    ///
    /// Provides a snapshot of the agent's capabilities for clients that need to discover
    /// available features (e.g., UI clients rendering command palettes or model selectors).
    ///
    /// - Returns: A ``SDKControlInitializeResponse`` with the current configuration.
    public func initializationResult() -> SDKControlInitializeResponse {
        SDKControlInitializeResponse(
            commands: [],  // Slash commands are TS-specific; Swift SDK has none
            agents: supportedAgents(),
            outputStyle: "default",
            availableOutputStyles: ["default"],
            models: supportedModels(),
            account: nil,
            fastModeState: false
        )
    }

    // MARK: - Model Discovery (supportedModels)

    /// Returns model metadata from the MODEL_PRICING table.
    ///
    /// Converts each entry in the global ``MODEL_PRICING`` dictionary to a ``ModelInfo``
    /// instance with synthesized display names and descriptions.
    ///
    /// - Returns: An array of ``ModelInfo`` instances for all known models.
    public func supportedModels() -> [ModelInfo] {
        MODEL_PRICING.keys.map { modelId in
            let is4x = modelId.hasPrefix("claude-opus-4") || modelId.hasPrefix("claude-sonnet-4") || modelId.hasPrefix("claude-haiku-4")
            let allEffortLevels: [EffortLevel] = [.low, .medium, .high, .max]
            return ModelInfo(
                value: modelId,
                displayName: Self.friendlyName(for: modelId),
                description: Self.modelDescription(for: modelId),
                supportsEffort: is4x,
                supportedEffortLevels: is4x ? allEffortLevels : nil,
                supportsAdaptiveThinking: is4x ? true : nil,
                supportsFastMode: is4x ? true : nil
            )
        }.sorted { $0.value < $1.value }
    }

    // MARK: - Agent Discovery (supportedAgents)

    /// Returns configured sub-agent definitions.
    ///
    /// Returns the built-in sub-agent types (Explore, Plan) when the Agent tool is
    /// configured in the tool pool. Returns an empty array if no Agent tool is present.
    ///
    /// - Note: Sub-agent definitions are discovered at spawn time by the Agent tool.
    ///   This method returns the known built-in types for discovery purposes.
    ///
    /// - Returns: An array of ``AgentInfo`` instances.
    public func supportedAgents() -> [AgentInfo] {
        // Check if the Agent tool is present in the tool pool
        let hasAgentTool = options.tools?.contains(where: { $0.name == "Agent" }) ?? false
        guard hasAgentTool else { return [] }

        // Return the known built-in agent types that the Agent tool supports.
        // These mirror BUILTIN_AGENTS in AgentTool.swift.
        return [
            AgentInfo(
                name: "Explore",
                description: "Fast agent specialized for exploring codebases. Use for finding files, searching code, and answering questions about the codebase.",
                model: nil
            ),
            AgentInfo(
                name: "Plan",
                description: "Software architect agent for designing implementation plans. Returns step-by-step plans and identifies critical files.",
                model: nil
            ),
        ]
    }

    // MARK: - Dynamic Thinking (setMaxThinkingTokens)

    /// Dynamically adjusts the thinking token budget at runtime.
    ///
    /// When `n` is a positive integer, sets the thinking configuration to
    /// ``ThinkingConfig/enabled(budgetTokens:)`` with the given budget.
    /// When `nil`, clears the thinking configuration entirely.
    ///
    /// Thread-safe: uses the internal permission lock for mutation.
    ///
    /// - Parameter n: The new thinking token budget, or `nil` to disable thinking.
    /// - Throws: ``SDKError/invalidConfiguration`` if `n` is zero or negative.
    public func setMaxThinkingTokens(_ n: Int?) throws {
        if let n {
            guard n > 0 else {
                throw SDKError.invalidConfiguration("maxThinkingTokens must be positive, got \(n)")
            }
            _permissionLock.withLock {
                options.thinking = .enabled(budgetTokens: n)
            }
        } else {
            _permissionLock.withLock {
                options.thinking = nil
            }
        }
    }

    /// Returns a user-friendly display name for a model identifier.
    private static func friendlyName(for modelId: String) -> String {
        switch modelId {
        case "claude-opus-4-6": return "Claude Opus 4.6"
        case "claude-sonnet-4-6": return "Claude Sonnet 4.6"
        case "claude-haiku-4-5": return "Claude Haiku 4.5"
        case "claude-sonnet-4-5": return "Claude Sonnet 4.5"
        case "claude-opus-4-5": return "Claude Opus 4.5"
        case "claude-3-5-sonnet": return "Claude 3.5 Sonnet"
        case "claude-3-5-haiku": return "Claude 3.5 Haiku"
        case "claude-3-opus": return "Claude 3 Opus"
        default: return modelId
        }
    }

    /// Returns a brief description for a model identifier.
    private static func modelDescription(for modelId: String) -> String {
        if modelId.hasPrefix("claude-opus") {
            return "Highest capability model for complex reasoning tasks."
        } else if modelId.hasPrefix("claude-sonnet") {
            return "Balanced model for general-purpose tasks."
        } else if modelId.hasPrefix("claude-haiku") {
            return "Fast and efficient model for quick responses."
        }
        return "A Claude model."
    }

    // MARK: - MCP Integration

    /// Assembles the complete tool pool including MCP tools.
    ///
    /// If `options.mcpServers` is configured, creates an MCPClientManager,
    /// connects all servers, and merges their tools with the existing tool pool.
    /// For `.sdk` config types, tools are extracted directly without MCP protocol overhead.
    ///
    /// - Returns: A tuple of (assembled tools, MCPClientManager or nil).
    func assembleFullToolPool() async -> ([ToolProtocol], MCPClientManager?) {
        let baseTools = options.tools ?? []

        guard let mcpServers = options.mcpServers, !mcpServers.isEmpty else {
            return (baseTools, nil)
        }

        let (sdkTools, externalServers) = await Self.processMcpConfigs(mcpServers)

        // Connect external MCP servers (stdio, sse, http)
        var externalTools: [ToolProtocol] = []
        var manager: MCPClientManager? = nil

        if !externalServers.isEmpty {
            let mcpManager = MCPClientManager()
            await mcpManager.connectAll(servers: externalServers)
            externalTools = await mcpManager.getMCPTools()
            manager = mcpManager
        }

        // Store manager for public MCP runtime management API
        self.mcpClientManager = manager

        let allMCPTools = sdkTools + externalTools

        let pool = assembleToolPool(
            baseTools: getAllBaseTools(tier: .core) + getAllBaseTools(tier: .specialist),
            customTools: baseTools,
            mcpTools: allMCPTools,
            allowed: options.allowedTools,
            disallowed: options.disallowedTools
        )

        return (pool, manager)
    }

    // MARK: - MCP Runtime Management

    /// Returns the status of all configured MCP servers.
    ///
    /// If no MCP servers have been configured or connected yet, returns an empty dictionary.
    /// The returned ``McpServerStatus`` values use the 5-case ``McpServerStatusEnum``
    /// matching the TypeScript SDK.
    ///
    /// - Returns: A dictionary mapping server names to their current status.
    public func mcpServerStatus() async -> [String: McpServerStatus] {
        guard let manager = mcpClientManager else {
            return [:]
        }
        return await manager.getStatus()
    }

    /// Reconnects a specific MCP server.
    ///
    /// Disconnects the existing connection and re-establishes it using the original
    /// configuration. Useful for recovering from transient failures.
    ///
    /// - Parameter name: The name of the MCP server to reconnect.
    /// - Throws: ``MCPClientManagerError/serverNotFound`` if no server with the given name exists,
    ///           or an error if the reconnection attempt fails.
    public func reconnectMcpServer(name: String) async throws {
        guard let manager = mcpClientManager else {
            throw MCPClientManagerError.serverNotFound(name)
        }
        try await manager.reconnect(name: name)
    }

    /// Enables or disables a specific MCP server.
    ///
    /// When disabled, the server's connection is closed but its configuration is retained.
    /// When enabled, the server is reconnected using its stored configuration.
    ///
    /// - Parameters:
    ///   - name: The name of the MCP server to toggle.
    ///   - enabled: `true` to enable (reconnect), `false` to disable (disconnect).
    /// - Throws: ``MCPClientManagerError/serverNotFound`` if no server with the given name exists.
    public func toggleMcpServer(name: String, enabled: Bool) async throws {
        guard let manager = mcpClientManager else {
            throw MCPClientManagerError.serverNotFound(name)
        }
        try await manager.toggle(name: name, enabled: enabled)
    }

    /// Dynamically replaces the full MCP server set.
    ///
    /// Compares the new server configurations against existing connections.
    /// Servers present in the new set but not currently connected are added.
    /// Servers currently connected but absent from the new set are removed.
    ///
    /// - Parameter servers: The new set of MCP server configurations.
    /// - Returns: A ``McpServerUpdateResult`` listing added, removed, and errored servers.
    /// - Throws: ``MCPClientManagerError`` if the manager is not initialized.
    public func setMcpServers(_ servers: [String: McpServerConfig]) async throws -> McpServerUpdateResult {
        // Shutdown existing manager to avoid leaking connections
        if let existing = mcpClientManager {
            await existing.shutdown()
        }

        let manager = MCPClientManager()
        self.mcpClientManager = manager

        guard !servers.isEmpty else {
            return McpServerUpdateResult()
        }

        return await manager.setServers(servers)
    }

    // MARK: - Internal Helpers (Reserved for Story 1.5)

    /// Build the system prompt string for API requests.
    ///
    /// Returns the configured system prompt with Git context appended (if available).
    /// If no system prompt is set but Git context exists, returns the Git context alone.
    /// If neither is available, returns `nil`.
    func buildSystemPrompt() -> String? {
        // Resolve base prompt: systemPromptConfig takes priority over systemPrompt (AC7)
        let basePrompt: String?
        if let config = options.systemPromptConfig {
            switch config {
            case .text(let text):
                basePrompt = text
            case .preset(let name, let append):
                // Preset names are resolved to known templates.
                // Currently only "claude_code" is supported; others fall back to the name itself.
                basePrompt = Self.resolvePreset(name: name, append: append)
            }
        } else {
            basePrompt = options.systemPrompt
        }
        let cwd = options.cwd ?? FileManager.default.currentDirectoryPath
        let gitContext = gitContextCollector.collectGitContext(
            cwd: cwd,
            ttl: options.gitCacheTTL
        )

        let projectContext = projectDocumentDiscovery.collectProjectContext(
            cwd: cwd,
            explicitProjectRoot: options.projectRoot
        )

        // Build parts in order: systemPrompt -> git-context -> global-instructions -> project-instructions
        var parts: [String] = []
        if let basePrompt {
            parts.append(basePrompt)
        }
        if let gitContext {
            parts.append(gitContext)
        }
        if let globalInstructions = projectContext.globalInstructions {
            parts.append("<global-instructions>\n\(globalInstructions)\n</global-instructions>")
        }
        if let projectInstructions = projectContext.projectInstructions {
            parts.append("<project-instructions>\n\(projectInstructions)\n</project-instructions>")
        }
        if let sessionMemoryBlock = sessionMemory.formatForPrompt() {
            parts.append(sessionMemoryBlock)
        }

        if parts.isEmpty {
            return nil
        }
        return parts.joined(separator: "\n")
    }

    /// Build the messages array for an API request from a user prompt.
    ///
    /// Wraps the user prompt in the standard Anthropic message format.
    /// - Parameter prompt: The user's input text.
    /// - Returns: An array of message dictionaries suitable for the API.
    func buildMessages(prompt: String) -> [[String: Any]] {
        return [
            ["role": "user", "content": prompt],
        ]
    }

    // MARK: - Prompt (Blocking Response)

    /// Send a prompt to the agent and return the final complete response.
    ///
    /// This blocking method runs the agent loop: sends the user message to the LLM,
    /// accumulates responses across turns, and returns when the loop terminates
    /// (via `end_turn`, reaching `maxTurns`, or an API error).
    ///
    /// - Parameter text: The user's input text to send to the agent.
    /// - Returns: A ``QueryResult`` containing the assistant's text, usage statistics,
    ///   turn count, duration, collected messages, and a ``QueryStatus`` indicating
    ///   how the query terminated.
    public func prompt(_ text: String) async -> QueryResult {
        guard !isClosed else {
            return QueryResult(
                text: "", usage: TokenUsage(inputTokens: 0, outputTokens: 0),
                numTurns: 0, durationMs: 0, messages: [],
                status: .errorDuringExecution
            )
        }
        _interrupted = false
        return await promptImpl(text)
    }

    /// Internal implementation of prompt(), separated for cancellation handler support.
    private func promptImpl(_ text: String) async -> QueryResult {
        let startTime = ContinuousClock.now

        // Hook: sessionStart — trigger before any agent work begins
        if let hookRegistry = options.hookRegistry {
            let hookInput = HookInput(event: .sessionStart, cwd: options.cwd)
            await hookRegistry.execute(.sessionStart, input: hookInput)
        }

        // MCP integration: connect MCP servers and merge tools
        let (mcpTools, mcpManager) = await assembleFullToolPool()

        // Session lifecycle wiring (Story 17-7)
        // Resolve the active session ID based on continueRecentSession / forkSession options.
        // Execution order: continueRecentSession → forkSession → session restore → resumeSessionAt
        var resolvedSessionId = options.sessionId
        if let sessionStore = options.sessionStore {
            // continueRecentSession: if no explicit sessionId, resolve most recent session
            if options.continueRecentSession,
               resolvedSessionId == nil || resolvedSessionId?.isEmpty == true {
                if let sessions = try? await sessionStore.list(), let mostRecent = sessions.first {
                    resolvedSessionId = mostRecent.id
                }
                // If no sessions exist, resolvedSessionId stays nil → new session behavior
            }

            // forkSession: fork the resolved session into a new copy
            if options.forkSession, let sourceId = resolvedSessionId {
                if let forkedId = try? await sessionStore.fork(sourceSessionId: sourceId) {
                    resolvedSessionId = forkedId
                }
                // If fork returns nil (source doesn't exist), keep original sessionId
            }
        }

        // Session restore: load history if sessionStore and resolvedSessionId are configured
        var messages: [[String: Any]]
        if let sessionStore = options.sessionStore, let sessionId = resolvedSessionId {
            if let sessionData = try? await sessionStore.load(sessionId: sessionId) {
                messages = sessionData.messages
            } else {
                messages = []
            }

            // resumeSessionAt: truncate history to the message with matching UUID
            if let resumeAt = options.resumeSessionAt, !messages.isEmpty {
                if let truncateIndex = messages.firstIndex(where: { msg in
                    (msg["uuid"] as? String) == resumeAt || (msg["id"] as? String) == resumeAt
                }) {
                    messages = Array(messages[0...truncateIndex])
                }
                // If UUID not found, keep full history (no truncation, no error)
            }

            // Append new user message to restored (or empty) history
            messages.append(["role": "user", "content": text])
        } else {
            messages = buildMessages(prompt: text)
        }

        var totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
        var totalCostUsd: Double = 0.0
        var turnCount = 0
        var lastAssistantText = ""
        var status: QueryStatus = .success
        var loopExitedCleanly = false
        var maxTokensRecoveryAttempts = 0
        let MAX_TOKENS_RECOVERY = 3
        var compactState = createAutoCompactState()
        var costByModel: [String: CostBreakdownEntry] = [:]
        // Skill system: create restriction stack once before the loop so it persists across turns
        let restrictionStack = options.skillRegistry != nil ? ToolRestrictionStack() : nil
        // File cache: shared across all tool executions in this agent session
        let fileCache = FileCache(
            maxEntries: options.fileCacheMaxEntries,
            maxSizeBytes: options.fileCacheMaxSizeBytes,
            maxEntrySizeBytes: options.fileCacheMaxEntrySizeBytes
        )

        while turnCount < maxTurns {
            // Cancellation check (FR60): cooperative cancellation via Task.isCancelled or interrupt()
            if _Concurrency.Task.isCancelled || _interrupted {
                status = .cancelled
                break
            }

            // Auto-compact if context is too large (FR9)
            if shouldAutoCompact(messages: messages, model: model, state: compactState) {
                let (newMessages, _, newState) = await compactConversation(
                    client: client, model: model,
                    messages: messages, state: compactState,
                    fileCache: fileCache,
                    sessionMemory: sessionMemory
                )
                messages = newMessages
                compactState = newState
            }

            // Build tool definitions for API call (use MCP-merged tool pool)
            let apiTools: [[String: Any]]? = {
                guard !mcpTools.isEmpty else { return nil }
                return toApiTools(mcpTools)
            }()

            let response: [String: Any]
            do {
                // Capture values to satisfy Sendable requirements in the @Sendable closure.
                let retryClient = self.client
                let retryModel = self.model
                let retryMaxTokens = self.maxTokens
                let retrySystemPrompt = self.buildSystemPrompt()
                let retryMessages = messages
                let retryApiTools = apiTools
                let retryCfg = self.options.retryConfig ?? RetryConfig.default
                let retryThinking = Self.computeThinkingConfig(from: self.options)
                response = try await withRetry({
                    try await retryClient.sendMessage(
                        model: retryModel,
                        messages: retryMessages,
                        maxTokens: retryMaxTokens,
                        system: retrySystemPrompt,
                        tools: retryApiTools,
                        toolChoice: nil,
                        thinking: retryThinking,
                        temperature: nil
                    )
                }, retryConfig: retryCfg)
            } catch {
                // Fallback model retry: if a fallbackModel is configured, retry once with it
                if let fallbackModel = self.options.fallbackModel, fallbackModel != self.model {
                    Logger.shared.info("Agent", "fallback_model_retry", data: [
                        "originalModel": self.model,
                        "fallbackModel": fallbackModel
                    ])
                    do {
                        let retryClient = self.client
                        let retryMaxTokens = self.maxTokens
                        let retrySystemPrompt = self.buildSystemPrompt()
                        let retryMessages = messages
                        let retryApiTools = apiTools
                        let retryThinking = Self.computeThinkingConfig(from: self.options)
                        let fallbackResponse = try await retryClient.sendMessage(
                            model: fallbackModel,
                            messages: retryMessages,
                            maxTokens: retryMaxTokens,
                            system: retrySystemPrompt,
                            tools: retryApiTools,
                            toolChoice: nil,
                            thinking: retryThinking,
                            temperature: nil
                        )
                        // Fallback succeeded — use this response in the loop
                        // Temporarily switch model for cost tracking
                        let originalModel = self.model
                        self.model = fallbackModel
                        // Process the fallback response through the normal loop path
                        // by assigning to `response` and continuing below
                        turnCount += 1
                        if let usage = fallbackResponse["usage"] as? [String: Any] {
                            let turnUsage = TokenUsage(
                                inputTokens: usage["input_tokens"] as? Int ?? 0,
                                outputTokens: usage["output_tokens"] as? Int ?? 0
                            )
                            totalUsage = totalUsage + turnUsage
                            let turnCost = estimateCost(model: fallbackModel, usage: turnUsage)
                            totalCostUsd += turnCost
                            costByModel[fallbackModel] = CostBreakdownEntry(
                                model: fallbackModel,
                                inputTokens: turnUsage.inputTokens,
                                outputTokens: turnUsage.outputTokens,
                                costUsd: turnCost
                            )
                        }
                        let content = fallbackResponse["content"]
                        if let content {
                            lastAssistantText += extractText(from: content)
                        }
                        messages.append([
                            "role": "assistant",
                            "content": content ?? []
                        ])
                        let stopReason = fallbackResponse["stop_reason"] as? String ?? ""
                        if stopReason == "end_turn" || stopReason == "stop_sequence" {
                            loopExitedCleanly = true
                        }
                        self.model = originalModel
                        break
                    } catch {
                        // Fallback also failed — fall through to original error handling
                        Logger.shared.error("Agent", "fallback_model_failed", data: [
                            "fallbackModel": fallbackModel,
                            "error": error.localizedDescription
                        ])
                    }
                }

                // Structured log for API error
                let statusCode: String
                let errorMessage: String
                if let sdkError = error as? SDKError, let code = sdkError.statusCode {
                    statusCode = String(code)
                    errorMessage = sdkError.message
                } else if let urlError = error as? URLError {
                    statusCode = String(urlError.errorCode)
                    errorMessage = urlError.localizedDescription
                } else {
                    statusCode = "0"
                    errorMessage = error.localizedDescription
                }
                Logger.shared.error("QueryEngine", "api_error", data: [
                    "statusCode": statusCode,
                    "message": errorMessage
                ])

                // Clean up MCP connections on error
                if let mcpManager {
                    await mcpManager.shutdown()
                }
                // Session auto-save on error: persist whatever messages we have so far
                if let sessionStore = options.sessionStore, let sessionId = resolvedSessionId, options.persistSession {
                    let metadata = PartialSessionMetadata(
                        cwd: options.cwd ?? FileManager.default.currentDirectoryPath,
                        model: model,
                        summary: nil
                    )
                    if let messagesData = try? JSONSerialization.data(withJSONObject: messages, options: []),
                       let deserializedMessages = try? JSONSerialization.jsonObject(with: messagesData, options: []) as? [[String: Any]] {
                        try? await sessionStore.save(sessionId: sessionId, messages: deserializedMessages, metadata: metadata)
                    }
                }
                // Hook: stop — trigger on error path (loop terminated by exception)
                if let hookRegistry = options.hookRegistry {
                    let stopInput = HookInput(event: .stop, cwd: options.cwd)
                    await hookRegistry.execute(.stop, input: stopInput)
                }
                // Hook: sessionEnd — trigger even on error path
                if let hookRegistry = options.hookRegistry {
                    let endInput = HookInput(event: .sessionEnd, cwd: options.cwd)
                    await hookRegistry.execute(.sessionEnd, input: endInput)
                }
                let isCancelled = error is CancellationError
                    || _Concurrency.Task.isCancelled
                    || _interrupted
                    || (error as? URLError)?.code == .cancelled
                let resultStatus: QueryStatus = isCancelled ? .cancelled : .errorDuringExecution
                return QueryResult(
                    text: lastAssistantText,
                    usage: totalUsage,
                    numTurns: turnCount,
                    durationMs: Self.computeDurationMs(ContinuousClock.now - startTime),
                    messages: [],
                    status: resultStatus,
                    totalCostUsd: totalCostUsd,
                    costBreakdown: Array(costByModel.values),
                    isCancelled: isCancelled
                )
            }

            turnCount += 1

            // Parse usage from response
            if let usage = response["usage"] as? [String: Any] {
                let turnUsage = TokenUsage(
                    inputTokens: usage["input_tokens"] as? Int ?? 0,
                    outputTokens: usage["output_tokens"] as? Int ?? 0
                )
                totalUsage = totalUsage + turnUsage
                let turnCost = estimateCost(model: model, usage: turnUsage)
                totalCostUsd += turnCost
                // Track per-model cost breakdown
                let currentModel = model
                if var existing = costByModel[currentModel] {
                    let newInput = existing.inputTokens + turnUsage.inputTokens
                    let newOutput = existing.outputTokens + turnUsage.outputTokens
                    let newCost = existing.costUsd + turnCost
                    costByModel[currentModel] = CostBreakdownEntry(
                        model: currentModel,
                        inputTokens: newInput,
                        outputTokens: newOutput,
                        costUsd: newCost
                    )
                } else {
                    costByModel[currentModel] = CostBreakdownEntry(
                        model: currentModel,
                        inputTokens: turnUsage.inputTokens,
                        outputTokens: turnUsage.outputTokens,
                        costUsd: turnCost
                    )
                }
            }

            // Structured log for LLM response
            let turnDurationMs = Self.computeDurationMs(ContinuousClock.now - startTime)
            if let usage = response["usage"] as? [String: Any] {
                let turnInputTokens = usage["input_tokens"] as? Int ?? 0
                let turnOutputTokens = usage["output_tokens"] as? Int ?? 0
                Logger.shared.debug("QueryEngine", "llm_response", data: [
                    "inputTokens": String(turnInputTokens),
                    "outputTokens": String(turnOutputTokens),
                    "durationMs": String(turnDurationMs),
                    "model": model
                ])
            }

            // Check budget limit after cost accumulation
            if let budget = options.maxBudgetUsd, totalCostUsd > budget {
                status = .errorMaxBudgetUsd
                // Structured log for budget exceeded
                Logger.shared.warn("QueryEngine", "budget_exceeded", data: [
                    "costUsd": String(format: "%.4f", totalCostUsd),
                    "budgetUsd": String(format: "%.4f", budget),
                    "turnsUsed": String(turnCount)
                ])
                // Extract content before breaking so partial text is preserved
                if let content = response["content"] {
                    lastAssistantText = extractText(from: content)
                }
                break
            }

            // Extract content from response
            let content = response["content"]
            let contentBlocks = content as? [[String: Any]] ?? []
            if let content {
                lastAssistantText += extractText(from: content)
            }

            // Add assistant message to conversation history
            messages.append([
                "role": "assistant",
                "content": content ?? []
            ])

            // Check stop_reason
            let stopReason = response["stop_reason"] as? String ?? ""

            // Handle tool_use: extract blocks, execute tools, feed results back
            if stopReason == "tool_use" {
                let toolUseBlocks = ToolExecutor.extractToolUseBlocks(from: contentBlocks)

                if !toolUseBlocks.isEmpty {
                    // Use MCP-merged tool pool for execution
                    let registeredTools = mcpTools
                    // Create agent spawner if AgentTool is registered
                    let spawner: SubAgentSpawner? = {
                        let hasAgentTool = registeredTools.contains { $0.name == "Agent" }
                        guard hasAgentTool else { return nil }
                        return DefaultSubAgentSpawner(
                            apiKey: options.apiKey ?? "",
                            baseURL: options.baseURL,
                            parentModel: model,
                            parentTools: registeredTools,
                            provider: options.provider
                        )
                    }()
                    let toolResults = await ToolExecutor.executeTools(
                        toolUseBlocks: toolUseBlocks,
                        tools: registeredTools,
                        context: ToolContext(
                            cwd: options.cwd ?? FileManager.default.currentDirectoryPath,
                            agentSpawner: spawner,
                            mailboxStore: options.mailboxStore,
                            teamStore: options.teamStore,
                            senderName: options.agentName,
                            taskStore: options.taskStore,
                            worktreeStore: options.worktreeStore,
                            planStore: options.planStore,
                            cronStore: options.cronStore,
                            todoStore: options.todoStore,
                            hookRegistry: options.hookRegistry,
                            permissionMode: options.permissionMode,
                            canUseTool: options.canUseTool,
                            skillRegistry: options.skillRegistry,
                            restrictionStack: restrictionStack,
                            skillNestingDepth: restrictionStack?.nestingDepth ?? 0,
                            maxSkillRecursionDepth: options.maxSkillRecursionDepth,
                            fileCache: fileCache,
                            sandbox: options.sandbox,
                            mcpConnections: nil,
                            env: options.env
                        )
                    )

                    // Micro-compaction: process each result before appending
                    var processedResults: [ToolResult] = []
                    for result in toolResults {
                        let processedContent = await processToolResult(result.content, isError: result.isError)
                        processedResults.append(ToolResult(
                            toolUseId: result.toolUseId,
                            content: processedContent,
                            isError: result.isError
                        ))
                    }

                    // Append tool_result user message
                    messages.append(ToolExecutor.buildToolResultMessage(from: processedResults))

                    // Reset maxTokensRecoveryAttempts (consistent with TS SDK)
                    maxTokensRecoveryAttempts = 0

                    // Continue to next LLM call
                    continue
                }
            }

            // Terminate on end_turn or stop_sequence
            if stopReason == "end_turn" || stopReason == "stop_sequence" {
                loopExitedCleanly = true
                break
            }

            // max_tokens: response was truncated but loop continues.
            // Add a continuation prompt so the model can complete its response.
            // Limited to MAX_TOKENS_RECOVERY attempts to prevent infinite continuation.
            if maxTokensRecoveryAttempts < MAX_TOKENS_RECOVERY {
                maxTokensRecoveryAttempts += 1
                messages.append(["role": "user", "content": "Please continue from where you left off."])
            } else {
                // Recovery attempts exhausted — return partial result with .success
                loopExitedCleanly = true
                break
            }
        }

        // Determine status: if we exhausted maxTurns without a clean stop, it's an error
        // Only override if not already set to a more specific error (e.g., budget exceeded)
        if !loopExitedCleanly, turnCount >= maxTurns, status == .success {
            status = .errorMaxTurns
        }

        // Hook: stop — trigger when agent loop terminates
        if let hookRegistry = options.hookRegistry {
            let stopInput = HookInput(event: .stop, cwd: options.cwd)
            await hookRegistry.execute(.stop, input: stopInput)
        }

        // Clean up MCP connections
        if let mcpManager {
            await mcpManager.shutdown()
        }

        // Session auto-save: persist updated messages if sessionStore is configured and persistSession is true
        if let sessionStore = options.sessionStore, let sessionId = resolvedSessionId, options.persistSession {
            let metadata = PartialSessionMetadata(
                cwd: options.cwd ?? "",
                model: model,
                summary: nil
            )
            // Serialize messages to Data for Sendable compliance when crossing actor boundary
            if let messagesData = try? JSONSerialization.data(withJSONObject: messages, options: []),
               let deserializedMessages = try? JSONSerialization.jsonObject(with: messagesData, options: []) as? [[String: Any]] {
                try? await sessionStore.save(sessionId: sessionId, messages: deserializedMessages, metadata: metadata)
            }
        }

        // Hook: sessionEnd — trigger before returning the result
        if let hookRegistry = options.hookRegistry {
            let endInput = HookInput(event: .sessionEnd, cwd: options.cwd)
            await hookRegistry.execute(.sessionEnd, input: endInput)
        }

        let isCancelled = (status == .cancelled)
        return QueryResult(
            text: lastAssistantText,
            usage: totalUsage,
            numTurns: turnCount,
            durationMs: Self.computeDurationMs(ContinuousClock.now - startTime),
            messages: [],
            status: status,
            totalCostUsd: totalCostUsd,
            costBreakdown: Array(costByModel.values),
            isCancelled: isCancelled
        )
    }

    // MARK: - Stream (AsyncStream Response)

    /// Send a prompt to the agent and return a stream of SDKMessage events.
    ///
    /// This streaming method runs the agent loop: sends the user message to the LLM,
    /// and yields `SDKMessage` events as they arrive. The stream terminates when the
    /// loop ends (via `end_turn`, reaching `maxTurns`, or an API error).
    ///
    /// - Parameter text: The user's input text to send to the agent.
    /// - Returns: An `AsyncStream<SDKMessage>` that yields typed events as the LLM
    ///   processes the request.
    public func stream(_ text: String) -> AsyncStream<SDKMessage> {
        if isClosed {
            return AsyncStream<SDKMessage> { $0.finish() }
        }
        let startTime = ContinuousClock.now
        _interrupted = false

        // Capture immutable values before entering the AsyncStream closure
        // to satisfy Swift 6 strict concurrency requirements.
        let capturedMaxTurns = maxTurns
        let capturedModel = model
        let capturedMaxTokens = maxTokens
        let capturedSystemPrompt = buildSystemPrompt()
        let capturedMessages = buildMessages(prompt: text)
        let capturedClient = client
        let capturedMaxBudgetUsd = options.maxBudgetUsd
        let capturedToolProtocols: [ToolProtocol] = options.tools ?? []
        let capturedCwd = options.cwd ?? FileManager.default.currentDirectoryPath
        let capturedRetryConfig = options.retryConfig ?? RetryConfig.default
        let capturedApiKey = options.apiKey ?? ""
        let capturedBaseURL = options.baseURL
        let capturedProvider = options.provider
        let capturedMailboxStore = options.mailboxStore
        let capturedTeamStore = options.teamStore
        let capturedAgentName = options.agentName
        let capturedTaskStore = options.taskStore
        let capturedWorktreeStore = options.worktreeStore
        let capturedPlanStore = options.planStore
        let capturedCronStore = options.cronStore
        let capturedTodoStore = options.todoStore
        let capturedMcpServers = options.mcpServers
        // Note: permissionMode and canUseTool are read fresh from self.options
        // at each tool execution point to support dynamic permission changes mid-stream.
        // Trade-off: Agent is @unchecked Sendable, so concurrent mutation of options
        // is a theoretical race — but the previous captured-local approach silently
        // broke the setPermissionMode()/setCanUseTool() public APIs.
        let capturedSessionStore = options.sessionStore
        let capturedSessionId = options.sessionId
        let capturedContinueRecentSession = options.continueRecentSession
        let capturedForkSession = options.forkSession
        let capturedResumeSessionAt = options.resumeSessionAt
        let capturedHookRegistry = options.hookRegistry
        let capturedSkillRegistry = options.skillRegistry
        let capturedMaxSkillRecursionDepth = options.maxSkillRecursionDepth
        // Create restriction stack once so it persists across stream turns
        let capturedRestrictionStack = options.skillRegistry != nil ? ToolRestrictionStack() : nil
        // Session memory: shared with agent instance for cross-query retention
        let capturedSessionMemory = sessionMemory
        // File cache: shared across all tool executions in this stream session
        let capturedFileCache = FileCache(
            maxEntries: options.fileCacheMaxEntries,
            maxSizeBytes: options.fileCacheMaxSizeBytes,
            maxEntrySizeBytes: options.fileCacheMaxEntrySizeBytes
        )
        let capturedSandbox = options.sandbox
        let capturedPersistSession = options.persistSession
        let capturedEnv = options.env
        let capturedIncludePartialMessages = options.includePartialMessages

        // Build tool definitions for API call
        let capturedApiTools: [[String: Any]]? = {
            guard let registeredTools = options.tools, !registeredTools.isEmpty else { return nil }
            return toApiTools(registeredTools)
        }()

        // Serialize captured messages to Data for Sendable compliance across
        // the AsyncStream closure boundary, then deserialize inside the Task.
        guard let messagesData = try? JSONSerialization.data(withJSONObject: capturedMessages, options: []) else {
            // If serialization fails, return an immediately-finishing stream
            return AsyncStream<SDKMessage> { $0.finish() }
        }

        // Serialize captured tools to Data for Sendable compliance (may be nil)
        let toolsData = capturedApiTools.flatMap { try? JSONSerialization.data(withJSONObject: $0, options: []) }

        return AsyncStream<SDKMessage> { [self] continuation in
            let task = _Concurrency.Task {
                // Deserialize messages inside the isolated Task context
                guard let decodedMessages = try? JSONSerialization.jsonObject(with: messagesData, options: []) as? [[String: Any]] else {
                    continuation.finish()
                    return
                }
                // Deserialize tools inside the isolated Task context
                var decodedApiTools: [[String: Any]]? = toolsData.flatMap { data in
                    try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
                }

                // MCP integration: connect MCP servers and merge tools
                var allToolProtocols = capturedToolProtocols
                var mcpManager: MCPClientManager? = nil
                if let mcpServers = capturedMcpServers, !mcpServers.isEmpty {
                    let (sdkTools, externalServers) = await Self.processMcpConfigs(mcpServers)

                    var externalTools: [ToolProtocol] = []
                    if !externalServers.isEmpty {
                        let manager = MCPClientManager()
                        await manager.connectAll(servers: externalServers)
                        externalTools = await manager.getMCPTools()
                        mcpManager = manager
                    }

                    // Store for MCP runtime management methods
                    self.mcpClientManager = mcpManager

                    let mcpTools = sdkTools + externalTools
                    if !mcpTools.isEmpty {
                        allToolProtocols = capturedToolProtocols + mcpTools
                        let mcpApiTools = toApiTools(mcpTools)
                        if var existing = decodedApiTools {
                            existing.append(contentsOf: mcpApiTools)
                            decodedApiTools = existing
                        } else {
                            decodedApiTools = mcpApiTools
                        }
                    }
                }
                let mcpManagerForCleanup = mcpManager

                // Ensure MCP connections are always cleaned up, regardless of exit path.
                // defer cannot be async, so fire-and-forget Task is used as a safety net
                // for early returns. The primary cleanup is done synchronously via await
                // after the main loop exits (before continuation.finish()).
                defer {
                    if let mcpManagerForCleanup {
                        _Concurrency.Task {
                            await mcpManagerForCleanup.shutdown()
                        }
                    }
                }

                var messages = decodedMessages

                // Session lifecycle wiring (Story 17-7)
                // Resolve the active session ID based on continueRecentSession / forkSession options.
                // Execution order: continueRecentSession → forkSession → session restore → resumeSessionAt
                var resolvedSessionId = capturedSessionId
                if let sessionStore = capturedSessionStore {
                    // continueRecentSession: if no explicit sessionId, resolve most recent session
                    if capturedContinueRecentSession,
                       resolvedSessionId == nil || resolvedSessionId?.isEmpty == true {
                        if let sessions = try? await sessionStore.list(), let mostRecent = sessions.first {
                            resolvedSessionId = mostRecent.id
                        }
                    }

                    // forkSession: fork the resolved session into a new copy
                    if capturedForkSession, let sourceId = resolvedSessionId {
                        if let forkedId = try? await sessionStore.fork(sourceSessionId: sourceId) {
                            resolvedSessionId = forkedId
                        }
                    }
                }

                // Session restore: load history if sessionStore and resolvedSessionId are configured
                if let sessionStore = capturedSessionStore, let sessionId = resolvedSessionId {
                    if let sessionData = try? await sessionStore.load(sessionId: sessionId) {
                        messages = sessionData.messages
                    } else {
                        messages = []
                    }

                    // resumeSessionAt: truncate history to the message with matching UUID
                    if let resumeAt = capturedResumeSessionAt, !messages.isEmpty {
                        if let truncateIndex = messages.firstIndex(where: { msg in
                            (msg["uuid"] as? String) == resumeAt || (msg["id"] as? String) == resumeAt
                        }) {
                            messages = Array(messages[0...truncateIndex])
                        }
                    }

                    // Append new user message to restored (or empty) history
                    messages.append(["role": "user", "content": text])
                }

                // Hook: sessionStart — trigger before any agent work begins
                if let hookRegistry = capturedHookRegistry {
                    let hookInput = HookInput(event: .sessionStart, cwd: capturedCwd)
                    await hookRegistry.execute(.sessionStart, input: hookInput)
                }

                // Emit system init event with session metadata (Story 17-1 AC8)
                let capturedPermissionMode = _permissionLock.withLock { self.options.permissionMode }
                let initTools: [SDKMessage.ToolInfo]? = capturedToolProtocols.isEmpty
                    ? nil
                    : capturedToolProtocols.map { SDKMessage.ToolInfo(name: $0.name, description: $0.description) }
                let initMcpServers: [SDKMessage.McpServerInfo]? = capturedMcpServers?.compactMap { (name, config) -> SDKMessage.McpServerInfo? in
                    let command: String
                    switch config {
                    case .stdio(let stdioConfig): command = stdioConfig.command
                    case .sse(let transportConfig): command = transportConfig.url
                    case .http(let transportConfig): command = transportConfig.url
                    case .sdk: command = "(in-process)"
                    case .claudeAIProxy(let proxyConfig): command = proxyConfig.url
                    }
                    return SDKMessage.McpServerInfo(name: name, command: command)
                }
                continuation.yield(.system(SDKMessage.SystemData(
                    subtype: .`init`,
                    message: "Session started",
                    sessionId: capturedSessionId,
                    tools: initTools,
                    model: capturedModel,
                    permissionMode: capturedPermissionMode.rawValue,
                    mcpServers: initMcpServers,
                    cwd: capturedCwd
                )))

                // Emit user message event (Story 17-1 AC8)
                continuation.yield(.userMessage(SDKMessage.UserMessageData(
                    sessionId: capturedSessionId,
                    message: text
                )))

                var totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
                var totalCostUsd: Double = 0.0
                var turnCount = 0
                var maxTokensRecoveryAttempts = 0
                var loopExitedCleanly = false
                let MAX_TOKENS_RECOVERY = 3
                var compactState = createAutoCompactState()
                var costByModel: [String: CostBreakdownEntry] = [:]

                while turnCount < capturedMaxTurns {
                    // Cancellation check (FR60): cooperative cancellation via Task.isCancelled
                    if _Concurrency.Task.isCancelled {
                        let finalText = Self.extractCollectedText(messages: messages)
                        await Self.yieldStreamCancelled(
                            continuation: continuation,
                            text: finalText,
                            usage: totalUsage,
                            turnCount: turnCount,
                            startTime: startTime,
                            totalCostUsd: totalCostUsd,
                            costBreakdown: Array(costByModel.values),
                            hookRegistry: capturedHookRegistry,
                            cwd: capturedCwd
                        )
                        return
                    }

                    // Auto-compact if context is too large (FR9)
                    if shouldAutoCompact(messages: messages, model: capturedModel, state: compactState) {
                        let (newMessages, _, newState) = await compactConversation(
                            client: capturedClient, model: capturedModel,
                            messages: messages, state: compactState,
                            fileCache: capturedFileCache,
                            sessionMemory: capturedSessionMemory
                        )
                        messages = newMessages
                        compactState = newState

                        // Emit compact boundary event
                        continuation.yield(.system(SDKMessage.SystemData(
                            subtype: .compactBoundary,
                            message: "Conversation compacted to fit within context window"
                        )))
                    }

                    let eventStream: AsyncThrowingStream<SSEEvent, Error>
                    do {
                        // Capture messages snapshot for the @Sendable closure.
                        let retryClient = capturedClient
                        let retryModel = capturedModel
                        let retryMaxTokens = capturedMaxTokens
                        let retrySystemPrompt = capturedSystemPrompt
                        let retryMessages = messages
                        let retryApiTools = decodedApiTools
                        let retryCfg = capturedRetryConfig
                        let retryThinking = Self.computeThinkingConfig(from: self.options)
                        eventStream = try await withRetry({
                            try await retryClient.streamMessage(
                                model: retryModel,
                                messages: retryMessages,
                                maxTokens: retryMaxTokens,
                                system: retrySystemPrompt,
                                tools: retryApiTools,
                                toolChoice: nil,
                                thinking: retryThinking,
                                temperature: nil
                            )
                        }, retryConfig: retryCfg)
                    } catch {
                        // Structured log for API error in stream
                        let statusCode: String
                        let errorMessage: String
                        if let sdkError = error as? SDKError, let code = sdkError.statusCode {
                            statusCode = String(code)
                            errorMessage = sdkError.message
                        } else if let urlError = error as? URLError {
                            statusCode = String(urlError.errorCode)
                            errorMessage = urlError.localizedDescription
                        } else {
                            statusCode = "0"
                            errorMessage = error.localizedDescription
                        }
                        Logger.shared.error("QueryEngine", "api_error", data: [
                            "statusCode": statusCode,
                            "message": errorMessage
                        ])
                        // API connection error — fire hooks before yielding error
                        if let hookRegistry = capturedHookRegistry {
                            let stopInput = HookInput(event: .stop, cwd: capturedCwd)
                            await hookRegistry.execute(.stop, input: stopInput)
                            let endInput = HookInput(event: .sessionEnd, cwd: capturedCwd)
                            await hookRegistry.execute(.sessionEnd, input: endInput)
                        }
                        Self.yieldStreamError(
                            continuation: continuation, text: "",
                            usage: totalUsage, turnCount: turnCount, startTime: startTime,
                            totalCostUsd: totalCostUsd,
                            costBreakdown: Array(costByModel.values)
                        )
                        return
                    }

                    // Process SSE event stream
                    var accumulatedText = ""
                    var currentModel = capturedModel
                    var currentStopReason = ""
                    // Track all content blocks for assistant message history
                    var contentBlocks: [[String: Any]] = []
                    // Track tool_use blocks being accumulated
                    var toolUseAccumulator: [Int: (id: String, name: String, inputJson: String)] = [:]

                    do {
                        for try await event in eventStream {
                            // Cancellation check inside SSE event loop (FR60)
                            if _Concurrency.Task.isCancelled { break }

                            switch event {
                            case .messageStart(let message):
                                currentModel = message["model"] as? String ?? capturedModel
                                // Extract input_tokens from the nested message.usage object
                                if let msgUsage = message["usage"] as? [String: Any] {
                                    let inputTokens = msgUsage["input_tokens"] as? Int ?? 0
                                    totalUsage = totalUsage + TokenUsage(
                                        inputTokens: inputTokens,
                                        outputTokens: 0
                                    )
                                    // Calculate cost for input tokens at message start
                                    let turnCost = estimateCost(model: currentModel, usage: TokenUsage(inputTokens: inputTokens, outputTokens: 0))
                                    totalCostUsd += turnCost
                                    // Track per-model cost breakdown
                                    let modelKey = currentModel
                                    if var existing = costByModel[modelKey] {
                                        costByModel[modelKey] = CostBreakdownEntry(
                                            model: modelKey,
                                            inputTokens: existing.inputTokens + inputTokens,
                                            outputTokens: existing.outputTokens,
                                            costUsd: existing.costUsd + turnCost
                                        )
                                    } else {
                                        costByModel[modelKey] = CostBreakdownEntry(
                                            model: modelKey,
                                            inputTokens: inputTokens,
                                            outputTokens: 0,
                                            costUsd: turnCost
                                        )
                                    }
                                }

                                // Check budget after input token cost accumulation
                                if let budget = capturedMaxBudgetUsd, totalCostUsd > budget {
                                    let elapsed = ContinuousClock.now - startTime
                                    let durationMs = Self.computeDurationMs(elapsed)
                                    let previousText = messages.compactMap { msg -> String? in
                                        guard let content = msg["content"] as? [[String: Any]] else { return nil }
                                        return content
                                            .filter { $0["type"] as? String == "text" }
                                            .compactMap { $0["text"] as? String }
                                            .joined()
                                    }.joined(separator: " ")

                                    // Structured log for budget exceeded
                                    Logger.shared.warn("QueryEngine", "budget_exceeded", data: [
                                        "costUsd": String(format: "%.4f", totalCostUsd),
                                        "budgetUsd": String(format: "%.4f", budget),
                                        "turnsUsed": String(turnCount)
                                    ])

                                    // Fire hooks before yielding budget error
                                    if let hookRegistry = capturedHookRegistry {
                                        let stopInput = HookInput(event: .stop, cwd: capturedCwd)
                                        await hookRegistry.execute(.stop, input: stopInput)
                                        let endInput = HookInput(event: .sessionEnd, cwd: capturedCwd)
                                        await hookRegistry.execute(.sessionEnd, input: endInput)
                                    }

                                    continuation.yield(.result(SDKMessage.ResultData(
                                        subtype: .errorMaxBudgetUsd,
                                        text: previousText,
                                        usage: totalUsage,
                                        numTurns: turnCount,
                                        durationMs: durationMs,
                                        totalCostUsd: totalCostUsd,
                                        costBreakdown: Array(costByModel.values)
                                    )))
                                    continuation.finish()
                                    return
                                }

                            case .contentBlockDelta(let index, let delta):
                                // Handle text delta
                                if let deltaText = delta["text"] as? String {
                                    accumulatedText += deltaText
                                    if capturedIncludePartialMessages {
                                        continuation.yield(.partialMessage(SDKMessage.PartialData(text: deltaText)))
                                    }
                                }
                                // Handle tool_use input_json_delta
                                if let partialJson = delta["partial_json"] as? String {
                                    if var existing = toolUseAccumulator[index] {
                                        existing.inputJson += partialJson
                                        toolUseAccumulator[index] = existing
                                    }
                                }

                            case .contentBlockStart(let index, let contentBlock):
                                // Track tool_use blocks from contentBlockStart
                                if contentBlock["type"] as? String == "tool_use" {
                                    let id = contentBlock["id"] as? String ?? ""
                                    let name = contentBlock["name"] as? String ?? ""
                                    toolUseAccumulator[index] = (id: id, name: name, inputJson: "")
                                }

                            case .contentBlockStop(let index):
                                // Finalize tool_use block when it stops
                                if let accumulated = toolUseAccumulator[index] {
                                    let block: [String: Any] = [
                                        "type": "tool_use",
                                        "id": accumulated.id,
                                        "name": accumulated.name,
                                        "input": Self.parseInputJson(accumulated.inputJson)
                                    ]
                                    contentBlocks.append(block)

                                    // Emit toolUse event to stream
                                    continuation.yield(.toolUse(SDKMessage.ToolUseData(
                                        toolName: accumulated.name,
                                        toolUseId: accumulated.id,
                                        input: accumulated.inputJson
                                    )))
                                }

                            case .messageDelta(let delta, let usage):
                                currentStopReason = delta["stop_reason"] as? String ?? ""
                                let turnUsage = TokenUsage(
                                    inputTokens: usage["input_tokens"] as? Int ?? 0,
                                    outputTokens: usage["output_tokens"] as? Int ?? 0
                                )
                                totalUsage = totalUsage + turnUsage
                                let turnCost = estimateCost(model: currentModel, usage: turnUsage)
                                totalCostUsd += turnCost
                                // Track per-model cost breakdown
                                let modelKey = currentModel
                                if var existing = costByModel[modelKey] {
                                    costByModel[modelKey] = CostBreakdownEntry(
                                        model: modelKey,
                                        inputTokens: existing.inputTokens + turnUsage.inputTokens,
                                        outputTokens: existing.outputTokens + turnUsage.outputTokens,
                                        costUsd: existing.costUsd + turnCost
                                    )
                                } else {
                                    costByModel[modelKey] = CostBreakdownEntry(
                                        model: modelKey,
                                        inputTokens: turnUsage.inputTokens,
                                        outputTokens: turnUsage.outputTokens,
                                        costUsd: turnCost
                                    )
                                }

                                // Check budget after cost accumulation
                                if let budget = capturedMaxBudgetUsd, totalCostUsd > budget {
                                    let elapsed = ContinuousClock.now - startTime
                                    let durationMs = Self.computeDurationMs(elapsed)
                                    let previousText = messages.compactMap { msg -> String? in
                                        guard let content = msg["content"] as? [[String: Any]] else { return nil }
                                        return content
                                            .filter { $0["type"] as? String == "text" }
                                            .compactMap { $0["text"] as? String }
                                            .joined()
                                    }.joined(separator: " ")
                                    let finalText = previousText.isEmpty ? accumulatedText : "\(previousText) \(accumulatedText)"

                                    // Structured log for budget exceeded
                                    Logger.shared.warn("QueryEngine", "budget_exceeded", data: [
                                        "costUsd": String(format: "%.4f", totalCostUsd),
                                        "budgetUsd": String(format: "%.4f", budget),
                                        "turnsUsed": String(turnCount + 1)
                                    ])

                                    // Fire hooks before yielding budget error
                                    if let hookRegistry = capturedHookRegistry {
                                        let stopInput = HookInput(event: .stop, cwd: capturedCwd)
                                        await hookRegistry.execute(.stop, input: stopInput)
                                        let endInput = HookInput(event: .sessionEnd, cwd: capturedCwd)
                                        await hookRegistry.execute(.sessionEnd, input: endInput)
                                    }

                                    continuation.yield(.result(SDKMessage.ResultData(
                                        subtype: .errorMaxBudgetUsd,
                                        text: finalText,
                                        usage: totalUsage,
                                        numTurns: turnCount + 1,
                                        durationMs: durationMs,
                                        totalCostUsd: totalCostUsd,
                                        costBreakdown: Array(costByModel.values)
                                    )))
                                    continuation.finish()
                                    return
                                }

                            case .messageStop:
                                turnCount += 1

                                // Structured log for LLM response (stream)
                                let streamDurationMs = Self.computeDurationMs(ContinuousClock.now - startTime)
                                Logger.shared.debug("QueryEngine", "llm_response", data: [
                                    "inputTokens": String(totalUsage.inputTokens),
                                    "outputTokens": String(totalUsage.outputTokens),
                                    "durationMs": String(streamDurationMs),
                                    "model": currentModel
                                ])

                                // If there's accumulated text, add it as a text content block
                                if !accumulatedText.isEmpty && !toolUseAccumulator.isEmpty {
                                    // Prepend text block to contentBlocks if we also have tool_use
                                    contentBlocks.insert(["type": "text", "text": accumulatedText], at: 0)
                                } else if !accumulatedText.isEmpty {
                                    contentBlocks.insert(["type": "text", "text": accumulatedText], at: 0)
                                }

                                continuation.yield(.assistant(SDKMessage.AssistantData(
                                    text: accumulatedText,
                                    model: currentModel,
                                    stopReason: currentStopReason
                                )))

                                // Add assistant message to conversation history (with all content blocks)
                                let assistantContent: Any = contentBlocks.isEmpty
                                    ? [["type": "text", "text": accumulatedText]] as [[String: Any]]
                                    : contentBlocks
                                messages.append([
                                    "role": "assistant",
                                    "content": assistantContent
                                ])

                            case .error:
                                // SSE error event — fire hooks before yielding error
                                if let hookRegistry = capturedHookRegistry {
                                    let stopInput = HookInput(event: .stop, cwd: capturedCwd)
                                    await hookRegistry.execute(.stop, input: stopInput)
                                    let endInput = HookInput(event: .sessionEnd, cwd: capturedCwd)
                                    await hookRegistry.execute(.sessionEnd, input: endInput)
                                }
                                Self.yieldStreamError(
                                    continuation: continuation, text: accumulatedText,
                                    usage: totalUsage, turnCount: turnCount, startTime: startTime,
                                    totalCostUsd: totalCostUsd,
                                    costBreakdown: Array(costByModel.values)
                                )
                                return

                            case .ping:
                                break // No SDKMessage yielded for these events
                            }
                        }
                    } catch {
                        // Check if this is a cancellation (not a real error)
                        if error is CancellationError || _Concurrency.Task.isCancelled || (error as? URLError)?.code == .cancelled {
                            let previousText = Self.extractCollectedText(messages: messages)
                            let finalText = previousText.isEmpty ? accumulatedText : "\(previousText) \(accumulatedText)"
                            await Self.yieldStreamCancelled(
                                continuation: continuation,
                                text: finalText,
                                usage: totalUsage,
                                turnCount: turnCount,
                                startTime: startTime,
                                totalCostUsd: totalCostUsd,
                                costBreakdown: Array(costByModel.values),
                                hookRegistry: capturedHookRegistry,
                                cwd: capturedCwd
                            )
                            return
                        }

                        // Stream iteration error — fire hooks before yielding error
                        if let hookRegistry = capturedHookRegistry {
                            let stopInput = HookInput(event: .stop, cwd: capturedCwd)
                            await hookRegistry.execute(.stop, input: stopInput)
                            let endInput = HookInput(event: .sessionEnd, cwd: capturedCwd)
                            await hookRegistry.execute(.sessionEnd, input: endInput)
                        }
                        Self.yieldStreamError(
                            continuation: continuation, text: accumulatedText,
                            usage: totalUsage, turnCount: turnCount, startTime: startTime,
                            totalCostUsd: totalCostUsd,
                            costBreakdown: Array(costByModel.values)
                        )
                        return
                    }

                    // Check termination conditions
                    // Cancellation check after SSE event stream ends (FR60)
                    if _Concurrency.Task.isCancelled {
                        let finalText = Self.extractCollectedText(messages: messages)
                        let partialText = finalText.isEmpty ? accumulatedText : "\(finalText) \(accumulatedText)"
                        await Self.yieldStreamCancelled(
                            continuation: continuation,
                            text: partialText,
                            usage: totalUsage,
                            turnCount: turnCount,
                            startTime: startTime,
                            totalCostUsd: totalCostUsd,
                            costBreakdown: Array(costByModel.values),
                            hookRegistry: capturedHookRegistry,
                            cwd: capturedCwd
                        )
                        return
                    }

                    if currentStopReason == "end_turn" || currentStopReason == "stop_sequence" {
                        loopExitedCleanly = true
                        break
                    }

                    // Handle tool_use: execute tools and feed results back
                    if currentStopReason == "tool_use" && !toolUseAccumulator.isEmpty {
                        // Convert accumulated tool_use data to ToolUseBlock array
                        let toolUseBlocks = toolUseAccumulator.sorted(by: { $0.key < $1.key }).map { _, item in
                            ToolUseBlock(id: item.id, name: item.name, input: Self.parseInputJson(item.inputJson))
                        }

                        if !toolUseBlocks.isEmpty {
                            // Emit tool progress events (Story 17-1 AC8)
                            for block in toolUseBlocks {
                                continuation.yield(.toolProgress(SDKMessage.ToolProgressData(
                                    toolUseId: block.id,
                                    toolName: block.name
                                )))
                            }

                            // Create agent spawner if AgentTool is registered
                            let streamSpawner: SubAgentSpawner? = {
                                let hasAgentTool = allToolProtocols.contains { $0.name == "Agent" }
                                guard hasAgentTool else { return nil }
                                return DefaultSubAgentSpawner(
                                    apiKey: capturedApiKey,
                                    baseURL: capturedBaseURL,
                                    parentModel: capturedModel,
                                    parentTools: allToolProtocols,
                                    provider: capturedProvider
                                )
                            }()
                            let (capturedPermissionMode, capturedCanUseTool) = _permissionLock.withLock {
                                (self.options.permissionMode, self.options.canUseTool)
                            }
                            let toolResults = await ToolExecutor.executeTools(
                                toolUseBlocks: toolUseBlocks,
                                tools: allToolProtocols,
                                context: ToolContext(
                                    cwd: capturedCwd,
                                    agentSpawner: streamSpawner,
                                    mailboxStore: capturedMailboxStore,
                                    teamStore: capturedTeamStore,
                                    senderName: capturedAgentName,
                                    taskStore: capturedTaskStore,
                                    worktreeStore: capturedWorktreeStore,
                                    planStore: capturedPlanStore,
                                    cronStore: capturedCronStore,
                                    todoStore: capturedTodoStore,
                                    hookRegistry: capturedHookRegistry,
                                    permissionMode: capturedPermissionMode,
                                    canUseTool: capturedCanUseTool,
                                    skillRegistry: capturedSkillRegistry,
                                    restrictionStack: capturedRestrictionStack,
                                    skillNestingDepth: capturedRestrictionStack?.nestingDepth ?? 0,
                                    maxSkillRecursionDepth: capturedMaxSkillRecursionDepth,
                                    fileCache: capturedFileCache,
                                    sandbox: capturedSandbox,
                                    mcpConnections: nil,
                                    env: capturedEnv
                                )
                            )

                            // Micro-compaction: process each result
                            var processedResults: [ToolResult] = []
                            for result in toolResults {
                                let processedContent = await Self.processToolResultStatic(
                                    client: capturedClient,
                                    model: capturedModel,
                                    content: result.content,
                                    isError: result.isError
                                )
                                processedResults.append(ToolResult(
                                    toolUseId: result.toolUseId,
                                    content: processedContent,
                                    isError: result.isError
                                ))

                                // Emit toolResult event to stream
                                continuation.yield(.toolResult(SDKMessage.ToolResultData(
                                    toolUseId: result.toolUseId,
                                    content: processedContent,
                                    isError: result.isError
                                )))
                            }

                            // Append tool_result user message
                            messages.append(ToolExecutor.buildToolResultMessage(from: processedResults))

                            // Emit tool use summary (Story 17-1 AC8)
                            let usedToolNames = toolUseBlocks.map { $0.name }
                            continuation.yield(.toolUseSummary(SDKMessage.ToolUseSummaryData(
                                toolUseCount: usedToolNames.count,
                                tools: Array(Set(usedToolNames))
                            )))

                            // Reset maxTokensRecoveryAttempts
                            maxTokensRecoveryAttempts = 0

                            // Continue to next LLM call
                            continue
                        }
                    }

                    // max_tokens: response was truncated but loop continues.
                    // Add a continuation prompt so the model can complete its response.
                    // Limited to MAX_TOKENS_RECOVERY attempts to prevent infinite continuation.
                    if maxTokensRecoveryAttempts < MAX_TOKENS_RECOVERY {
                        maxTokensRecoveryAttempts += 1
                        messages.append(["role": "user", "content": "Please continue from where you left off."])
                    } else {
                        // Recovery attempts exhausted — return partial result with .success
                        loopExitedCleanly = true
                        break
                    }
                }

                // Determine final status and yield result
                let elapsed = ContinuousClock.now - startTime
                let durationMs = Self.computeDurationMs(elapsed)

                let subtype: SDKMessage.ResultData.Subtype =
                    (!loopExitedCleanly && turnCount >= capturedMaxTurns) ? .errorMaxTurns : .success

                // Hook: stop — trigger when agent loop terminates
                if let hookRegistry = capturedHookRegistry {
                    let stopInput = HookInput(event: .stop, cwd: capturedCwd)
                    await hookRegistry.execute(.stop, input: stopInput)
                }

                // Collect all assistant text from conversation history
                let finalText = messages.compactMap { msg -> String? in
                    guard let content = msg["content"] as? [[String: Any]] else { return nil }
                    return content
                        .filter { $0["type"] as? String == "text" }
                        .compactMap { $0["text"] as? String }
                        .joined()
                }.joined()

                continuation.yield(.result(SDKMessage.ResultData(
                    subtype: subtype,
                    text: finalText,
                    usage: totalUsage,
                    numTurns: turnCount,
                    durationMs: durationMs,
                    totalCostUsd: totalCostUsd,
                    costBreakdown: Array(costByModel.values)
                )))
                // MCP cleanup handled by defer block above
                // Primary MCP cleanup — synchronous await on the main exit path.
                // The defer above acts as a safety net for early returns only.
                if let mcpManagerForCleanup {
                    await mcpManagerForCleanup.shutdown()
                }
                // Session auto-save: persist updated messages if sessionStore is configured and persistSession is true
                if let sessionStore = capturedSessionStore, let sessionId = resolvedSessionId, capturedPersistSession {
                    let metadata = PartialSessionMetadata(
                        cwd: capturedCwd,
                        model: capturedModel,
                        summary: nil
                    )
                    // Serialize messages to Data for Sendable compliance when crossing actor boundary
                    if let messagesData = try? JSONSerialization.data(withJSONObject: messages, options: []),
                       let deserializedMessages = try? JSONSerialization.jsonObject(with: messagesData, options: []) as? [[String: Any]] {
                        try? await sessionStore.save(sessionId: sessionId, messages: deserializedMessages, metadata: metadata)
                    }
                }
                // Hook: sessionEnd — trigger before finishing the stream
                if let hookRegistry = capturedHookRegistry {
                    let endInput = HookInput(event: .sessionEnd, cwd: capturedCwd)
                    await hookRegistry.execute(.sessionEnd, input: endInput)
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
            // Store Task reference for interrupt() support
            _streamTask = task
        }
    }

    // MARK: - Private Helpers

    // MARK: System Prompt Preset Resolution (Story 17-2)

    /// Resolves a preset system prompt name to its template text.
    ///
    /// Known presets:
    /// - `"claude_code"`: Standard Code agent prompt optimized for software engineering.
    ///
    /// Unknown preset names return the name itself as a placeholder.
    ///
    /// - Parameters:
    ///   - name: The preset name to resolve.
    ///   - append: Optional text to append after the resolved preset.
    /// - Returns: The resolved prompt string, with append text joined if provided.
    private static func resolvePreset(name: String, append: String?) -> String {
        let template: String
        switch name {
        case "claude_code":
            template = "You are Claude Code, an interactive CLI agent powered by Anthropic's Claude. You help users with software engineering tasks."
        default:
            template = "You are \(name)."
        }
        if let append {
            return template + "\n\n" + append
        }
        return template
    }

    /// Computes the thinking configuration for an API call based on agent options.
    ///
    /// Priority: explicit `thinking` config > `effort` level > `nil`.
    /// When `effort` is set, it maps to a thinking config with the corresponding budget tokens.
    ///
    /// - Parameter options: The agent options to derive thinking config from.
    /// - Returns: The thinking configuration dictionary, or nil if neither is set.
    private static func computeThinkingConfig(from options: AgentOptions) -> [String: Any]? {
        if let thinking = options.thinking {
            switch thinking {
            case .enabled(let budget):
                return ["type": "enabled", "budget_tokens": budget]
            case .disabled:
                return ["type": "disabled"]
            case .adaptive:
                return ["type": "enabled", "budget_tokens": 10000]
            }
        }
        if let effort = options.effort {
            return ["type": "enabled", "budget_tokens": effort.budgetTokens]
        }
        return nil
    }

    // MARK: Micro-Compaction Integration (Story 2.6)

    /// Process a tool result through micro-compaction if it exceeds the threshold.
    ///
    /// This method checks whether a tool result's content exceeds `MICRO_COMPACT_THRESHOLD`
    /// (50,000 characters) and, if so, compresses it using the LLM. Error results are
    /// never compacted. On compression failure, the original content is preserved.
    ///
    /// **Integration point for Epic 3:** When tool execution is added to the agent loop,
    /// call this method on each tool result before appending it to the `messages` array:
    /// ```swift
    /// // In prompt() and stream() after tool execution:
    /// let rawResult = await tool.call(input: toolInput, context: toolContext)
    /// let processedContent = await processToolResult(rawResult.content, isError: rawResult.isError)
    /// messages.append([
    ///     "role": "user",
    ///     "content": [["type": "tool_result", "tool_use_id": rawResult.toolUseId, "content": processedContent]]
    /// ])
    /// ```
    ///
    /// - Parameters:
    ///   - content: The raw tool result content string.
    ///   - isError: Whether the tool result is an error (errors are never compacted).
    /// - Returns: The micro-compacted content (with `[微压缩]` marker) if compression was
    ///   performed, or the original content if no compression was needed or on failure.
    func processToolResult(_ content: String, isError: Bool = false) async -> String {
        guard shouldMicroCompact(content: content, isError: isError) else {
            return content
        }
        return await microCompact(client: client, model: model, content: content)
    }

    /// Static version of processToolResult for use inside stream() closures
    /// where `self` is not available.
    ///
    /// - Parameters:
    ///   - client: The Anthropic client for micro-compaction LLM calls.
    ///   - model: The model identifier.
    ///   - content: The raw tool result content string.
    ///   - isError: Whether the tool result is an error (errors are never compacted).
    /// - Returns: The micro-compacted content or the original if no compaction needed.
    private static func processToolResultStatic(
        client: any LLMClient,
        model: String,
        content: String,
        isError: Bool
    ) async -> String {
        guard shouldMicroCompact(content: content, isError: isError) else {
            return content
        }
        return await microCompact(client: client, model: model, content: content)
    }

    /// Parse a JSON string into a dictionary, returning empty dict on failure.
    ///
    /// Used when converting accumulated tool_use input JSON from SSE deltas.
    /// - Parameter jsonString: The JSON string to parse.
    /// - Returns: The parsed dictionary, or an empty dictionary on failure.
    private static func parseInputJson(_ jsonString: String) -> [String: Any] {
        guard !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    /// Yield an error result to the stream continuation and finish it.
    ///
    /// Used by all three error paths in `stream()` to avoid duplication.
    private static func yieldStreamError(
        continuation: AsyncStream<SDKMessage>.Continuation,
        text: String,
        usage: TokenUsage,
        turnCount: Int,
        startTime: ContinuousClock.Instant,
        totalCostUsd: Double = 0.0,
        costBreakdown: [CostBreakdownEntry] = []
    ) {
        continuation.yield(.result(SDKMessage.ResultData(
            subtype: .errorDuringExecution,
            text: text,
            usage: usage,
            numTurns: turnCount,
            durationMs: computeDurationMs(ContinuousClock.now - startTime),
            totalCostUsd: totalCostUsd,
            costBreakdown: costBreakdown
        )))
        continuation.finish()
    }

    /// Yield a cancelled result event to the stream, fire stop+sessionEnd hooks, and finish.
    /// Used by all 4 cancellation checkpoints in stream() to avoid code duplication (FR60).
    private static func yieldStreamCancelled(
        continuation: AsyncStream<SDKMessage>.Continuation,
        text: String,
        usage: TokenUsage,
        turnCount: Int,
        startTime: ContinuousClock.Instant,
        totalCostUsd: Double,
        costBreakdown: [CostBreakdownEntry],
        hookRegistry: HookRegistry?,
        cwd: String?
    ) async {
        if let hookRegistry = hookRegistry {
            let stopInput = HookInput(event: .stop, cwd: cwd)
            await hookRegistry.execute(.stop, input: stopInput)
        }
        continuation.yield(.result(SDKMessage.ResultData(
            subtype: .cancelled,
            text: text,
            usage: usage,
            numTurns: turnCount,
            durationMs: computeDurationMs(ContinuousClock.now - startTime),
            totalCostUsd: totalCostUsd,
            costBreakdown: costBreakdown
        )))
        if let hookRegistry = hookRegistry {
            let endInput = HookInput(event: .sessionEnd, cwd: cwd)
            await hookRegistry.execute(.sessionEnd, input: endInput)
        }
        continuation.finish()
    }

    /// Compute duration in milliseconds from a Swift `Duration` value.
    ///
    /// - Parameter elapsed: The duration to convert.
    /// - Returns: The duration in whole milliseconds.
    private static func computeDurationMs(_ elapsed: Duration) -> Int {
        Int(elapsed.components.seconds * 1000)
            + Int(elapsed.components.attoseconds / 1_000_000_000_000)
    }

    /// Extract all assistant text from the messages array for cancellation result events.
    private static func extractCollectedText(messages: [[String: Any]]) -> String {
        messages.compactMap { msg -> String? in
            guard let content = msg["content"] as? [[String: Any]] else { return nil }
            return content
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
        }.joined()
    }

    /// Extract plain text from Anthropic API response content blocks.
    ///
    /// The API returns content as an array of blocks, each with a `type` field.
    /// This helper filters for `type == "text"` blocks and joins their text content.
    /// - Parameter content: The raw content value from the API response.
    /// - Returns: The concatenated text from all text blocks, or a string representation
    ///   of the content if it cannot be parsed.
    private func extractText(from content: Any) -> String {
        guard let blocks = content as? [[String: Any]] else {
            return String(describing: content)
        }
        return blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
    }

    // MARK: - CustomStringConvertible (API Key Masking)

    /// A string representation with any sensitive data masked.
    public var description: String {
        "Agent(model: \"\(model)\", systemPrompt: \(systemPrompt.map { "\"\($0)\"" } ?? "nil"), "
            + "maxTurns: \(maxTurns), maxTokens: \(maxTokens))"
    }

    /// A debug representation with any sensitive data masked.
    public var debugDescription: String {
        "Agent(model: \"\(model)\", systemPrompt: \(systemPrompt.map { "\"\($0)\"" } ?? "nil"), "
            + "maxTurns: \(maxTurns), maxTokens: \(maxTokens))"
    }
}

// MARK: - Factory Function

/// Create an agent with the given options.
///
/// If `options` is `nil`, the SDK resolves configuration from environment variables
/// and built-in defaults via ``SDKConfiguration/resolved(overrides:)``.
///
/// ```swift
/// // With explicit options
/// let agent = createAgent(options: AgentOptions(apiKey: "sk-...", model: "claude-opus-4"))
///
/// // With environment variable defaults
/// let agent = createAgent()
/// ```
///
/// - Parameter options: The agent configuration options. Pass `nil` to use
///   resolved SDK defaults from environment variables.
/// - Returns: A configured ``Agent`` instance.
public func createAgent(options: AgentOptions? = nil) -> Agent {
    let resolved: AgentOptions
    if let options {
        resolved = options
    } else {
        let config = SDKConfiguration.resolved()
        resolved = AgentOptions(from: config)
    }
    return Agent(options: resolved)
}

// MARK: - SdkToolWrapper

/// Wraps a `ToolProtocol` to add the MCP namespace prefix for SDK internal tools.
///
/// Unlike `MCPToolDefinition` which wraps external MCP tools (going through MCP protocol),
/// this wrapper directly delegates to the underlying tool with zero overhead -- no
/// serialization, no MCP protocol, no error double-wrapping.
private struct SdkToolWrapper: ToolProtocol, Sendable {
    let serverName: String
    let innerTool: ToolProtocol

    var name: String { "mcp__\(serverName)__\(innerTool.name)" }
    var description: String { innerTool.description }
    var inputSchema: ToolInputSchema { innerTool.inputSchema }
    var isReadOnly: Bool { innerTool.isReadOnly }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return await innerTool.call(input: input, context: context)
    }
}

// MARK: - MCP Config Processing Helper

extension Agent {
    /// Separates SDK configs from external (stdio/sse/http) configs and extracts SDK tools.
    ///
    /// SDK tools are wrapped in `SdkToolWrapper` for namespace prefixing and bypass
    /// MCP protocol entirely. External configs are collected for MCPClientManager.
    ///
    /// - Parameter mcpServers: The full MCP server config dictionary.
    /// - Returns: A tuple of (namespaced SDK tools, external server configs).
    private static func processMcpConfigs(
        _ mcpServers: [String: McpServerConfig]
    ) async -> (sdkTools: [ToolProtocol], externalServers: [String: McpServerConfig]) {
        var externalServers: [String: McpServerConfig] = [:]
        var sdkTools: [ToolProtocol] = []

        for (serverName, config) in mcpServers {
            switch config {
            case .sdk(let sdkConfig):
                let tools = await sdkConfig.server.getTools()
                let namespacedTools: [ToolProtocol] = tools.map { tool in
                    SdkToolWrapper(serverName: sdkConfig.name, innerTool: tool)
                }
                sdkTools.append(contentsOf: namespacedTools)
            default:
                externalServers[serverName] = config
            }
        }

        return (sdkTools, externalServers)
    }
}

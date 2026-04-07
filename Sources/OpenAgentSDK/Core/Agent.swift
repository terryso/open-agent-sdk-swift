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
public class Agent: CustomStringConvertible, CustomDebugStringConvertible {

    // MARK: - Public Read-Only Properties

    /// The model identifier used for API requests.
    public let model: String

    /// The system prompt provided to the agent, or `nil` if none was specified.
    public let systemPrompt: String?

    /// Maximum number of agent loop turns.
    public let maxTurns: Int

    /// Maximum number of tokens per request.
    public let maxTokens: Int

    // MARK: - Internal Properties

    /// The full agent options (used internally for prompt/stream calls).
    let options: AgentOptions

    /// The LLM API client used for communication.
    let client: any LLMClient

    // MARK: - Initialization

    /// Create an Agent with the given options.
    ///
    /// The agent stores the options and creates an internal ``LLMClient``
    /// for API communication. If `apiKey` is `nil`, the agent can still be created
    /// but subsequent prompt/stream calls will fail due to missing authentication.
    ///
    /// - Parameter options: The configuration options for this agent.
    public init(options: AgentOptions) {
        self.options = options
        self.model = options.model
        self.systemPrompt = options.systemPrompt
        self.maxTurns = options.maxTurns
        self.maxTokens = options.maxTokens

        // Create the appropriate client based on provider.
        // Empty API key fallback — calls will fail naturally if no key was provided.
        let apiKey = options.apiKey ?? ""
        switch options.provider {
        case .openai:
            self.client = OpenAIClient(
                apiKey: apiKey,
                baseURL: options.baseURL
            )
        case .anthropic:
            self.client = AnthropicClient(
                apiKey: apiKey,
                baseURL: options.baseURL
            )
        }
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
    public init(options: AgentOptions, client: any LLMClient) {
        self.options = options
        self.model = options.model
        self.systemPrompt = options.systemPrompt
        self.maxTurns = options.maxTurns
        self.maxTokens = options.maxTokens
        self.client = client
    }

    // MARK: - Internal Helpers (Reserved for Story 1.5)

    /// Build the system prompt string for API requests.
    ///
    /// Returns the configured system prompt, or `nil` if none was set.
    /// This is an extension point for future SystemPromptBuilder integration.
    func buildSystemPrompt() -> String? {
        return options.systemPrompt
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
        let startTime = ContinuousClock.now

        var messages = buildMessages(prompt: text)
        var totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
        var totalCostUsd: Double = 0.0
        var turnCount = 0
        var lastAssistantText = ""
        var status: QueryStatus = .success
        var loopExitedCleanly = false
        var maxTokensRecoveryAttempts = 0
        let MAX_TOKENS_RECOVERY = 3
        var compactState = createAutoCompactState()

        while turnCount < maxTurns {
            // Auto-compact if context is too large (FR9)
            if shouldAutoCompact(messages: messages, model: model, state: compactState) {
                let (newMessages, _, newState) = await compactConversation(
                    client: client, model: model,
                    messages: messages, state: compactState
                )
                messages = newMessages
                compactState = newState
            }

            // Build tool definitions for API call
            let apiTools: [[String: Any]]? = {
                guard let registeredTools = options.tools, !registeredTools.isEmpty else { return nil }
                return toApiTools(registeredTools)
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
                response = try await withRetry({
                    try await retryClient.sendMessage(
                        model: retryModel,
                        messages: retryMessages,
                        maxTokens: retryMaxTokens,
                        system: retrySystemPrompt,
                        tools: retryApiTools,
                        toolChoice: nil,
                        thinking: nil,
                        temperature: nil
                    )
                }, retryConfig: retryCfg)
            } catch {
                return QueryResult(
                    text: lastAssistantText,
                    usage: totalUsage,
                    numTurns: turnCount,
                    durationMs: Self.computeDurationMs(ContinuousClock.now - startTime),
                    messages: [],
                    status: .errorDuringExecution,
                    totalCostUsd: totalCostUsd
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
                totalCostUsd += estimateCost(model: model, usage: turnUsage)
            }

            // Check budget limit after cost accumulation
            if let budget = options.maxBudgetUsd, totalCostUsd > budget {
                status = .errorMaxBudgetUsd
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
                    let registeredTools = options.tools ?? []
                    // Create agent spawner if AgentTool is registered
                    let spawner: SubAgentSpawner? = {
                        let hasAgentTool = registeredTools.contains { $0.name == "Agent" }
                        guard hasAgentTool else { return nil }
                        return DefaultSubAgentSpawner(
                            apiKey: options.apiKey ?? "",
                            baseURL: options.baseURL,
                            parentModel: model,
                            parentTools: registeredTools
                        )
                    }()
                    let toolResults = await ToolExecutor.executeTools(
                        toolUseBlocks: toolUseBlocks,
                        tools: registeredTools,
                        context: ToolContext(
                            cwd: options.cwd ?? "",
                            agentSpawner: spawner,
                            mailboxStore: options.mailboxStore,
                            teamStore: options.teamStore,
                            senderName: options.agentName,
                            taskStore: options.taskStore,
                            worktreeStore: options.worktreeStore,
                            planStore: options.planStore
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

        return QueryResult(
            text: lastAssistantText,
            usage: totalUsage,
            numTurns: turnCount,
            durationMs: Self.computeDurationMs(ContinuousClock.now - startTime),
            messages: [],
            status: status,
            totalCostUsd: totalCostUsd
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
        let startTime = ContinuousClock.now

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
        let capturedCwd = options.cwd ?? ""
        let capturedRetryConfig = options.retryConfig ?? RetryConfig.default
        let capturedApiKey = options.apiKey ?? ""
        let capturedBaseURL = options.baseURL
        let capturedMailboxStore = options.mailboxStore
        let capturedTeamStore = options.teamStore
        let capturedAgentName = options.agentName
        let capturedTaskStore = options.taskStore
        let capturedWorktreeStore = options.worktreeStore
        let capturedPlanStore = options.planStore

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

        return AsyncStream<SDKMessage> { continuation in
            let task = _Concurrency.Task {
                // Deserialize messages inside the isolated Task context
                guard let decodedMessages = try? JSONSerialization.jsonObject(with: messagesData, options: []) as? [[String: Any]] else {
                    continuation.finish()
                    return
                }
                // Deserialize tools inside the isolated Task context
                let decodedApiTools: [[String: Any]]? = toolsData.flatMap { data in
                    try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
                }
                var messages = decodedMessages
                var totalUsage = TokenUsage(inputTokens: 0, outputTokens: 0)
                var totalCostUsd: Double = 0.0
                var turnCount = 0
                var maxTokensRecoveryAttempts = 0
                var loopExitedCleanly = false
                let MAX_TOKENS_RECOVERY = 3
                var compactState = createAutoCompactState()

                while turnCount < capturedMaxTurns {
                    // Auto-compact if context is too large (FR9)
                    if shouldAutoCompact(messages: messages, model: capturedModel, state: compactState) {
                        let (newMessages, _, newState) = await compactConversation(
                            client: capturedClient, model: capturedModel,
                            messages: messages, state: compactState
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
                        eventStream = try await withRetry({
                            try await retryClient.streamMessage(
                                model: retryModel,
                                messages: retryMessages,
                                maxTokens: retryMaxTokens,
                                system: retrySystemPrompt,
                                tools: retryApiTools,
                                toolChoice: nil,
                                thinking: nil,
                                temperature: nil
                            )
                        }, retryConfig: retryCfg)
                    } catch {
                        // API connection error — yield error result and terminate
                        Self.yieldStreamError(
                            continuation: continuation, text: "",
                            usage: totalUsage, turnCount: turnCount, startTime: startTime,
                            totalCostUsd: totalCostUsd
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
                                    totalCostUsd += estimateCost(model: currentModel, usage: TokenUsage(inputTokens: inputTokens, outputTokens: 0))
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

                                    continuation.yield(.result(SDKMessage.ResultData(
                                        subtype: .errorMaxBudgetUsd,
                                        text: previousText,
                                        usage: totalUsage,
                                        numTurns: turnCount,
                                        durationMs: durationMs,
                                        totalCostUsd: totalCostUsd
                                    )))
                                    continuation.finish()
                                    return
                                }

                            case .contentBlockDelta(let index, let delta):
                                // Handle text delta
                                if let deltaText = delta["text"] as? String {
                                    accumulatedText += deltaText
                                    continuation.yield(.partialMessage(SDKMessage.PartialData(text: deltaText)))
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
                                totalCostUsd += estimateCost(model: currentModel, usage: turnUsage)

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

                                    continuation.yield(.result(SDKMessage.ResultData(
                                        subtype: .errorMaxBudgetUsd,
                                        text: finalText,
                                        usage: totalUsage,
                                        numTurns: turnCount + 1,
                                        durationMs: durationMs,
                                        totalCostUsd: totalCostUsd
                                    )))
                                    continuation.finish()
                                    return
                                }

                            case .messageStop:
                                turnCount += 1

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
                                // SSE error event — yield error result and terminate
                                Self.yieldStreamError(
                                    continuation: continuation, text: accumulatedText,
                                    usage: totalUsage, turnCount: turnCount, startTime: startTime,
                                    totalCostUsd: totalCostUsd
                                )
                                return

                            case .ping:
                                break // No SDKMessage yielded for these events
                            }
                        }
                    } catch {
                        // Stream iteration error — yield error result and terminate
                        Self.yieldStreamError(
                            continuation: continuation, text: accumulatedText,
                            usage: totalUsage, turnCount: turnCount, startTime: startTime,
                            totalCostUsd: totalCostUsd
                        )
                        return
                    }

                    // Check termination conditions
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
                            // Create agent spawner if AgentTool is registered
                            let streamSpawner: SubAgentSpawner? = {
                                let hasAgentTool = capturedToolProtocols.contains { $0.name == "Agent" }
                                guard hasAgentTool else { return nil }
                                return DefaultSubAgentSpawner(
                                    apiKey: capturedApiKey,
                                    baseURL: capturedBaseURL,
                                    parentModel: capturedModel,
                                    parentTools: capturedToolProtocols
                                )
                            }()
                            let toolResults = await ToolExecutor.executeTools(
                                toolUseBlocks: toolUseBlocks,
                                tools: capturedToolProtocols,
                                context: ToolContext(
                                    cwd: capturedCwd,
                                    agentSpawner: streamSpawner,
                                    mailboxStore: capturedMailboxStore,
                                    teamStore: capturedTeamStore,
                                    senderName: capturedAgentName,
                                    taskStore: capturedTaskStore,
                                    worktreeStore: capturedWorktreeStore,
                                    planStore: capturedPlanStore
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
                    totalCostUsd: totalCostUsd
                )))
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private Helpers

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
        totalCostUsd: Double = 0.0
    ) {
        continuation.yield(.result(SDKMessage.ResultData(
            subtype: .errorDuringExecution,
            text: text,
            usage: usage,
            numTurns: turnCount,
            durationMs: computeDurationMs(ContinuousClock.now - startTime),
            totalCostUsd: totalCostUsd
        )))
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

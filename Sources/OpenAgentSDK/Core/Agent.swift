import Foundation

/// An AI agent that processes prompts using the Anthropic API.
///
/// `Agent` holds immutable configuration and an internal ``AnthropicClient`` for
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

    /// The Anthropic API client (actor) used for communication.
    let client: AnthropicClient

    // MARK: - Initialization

    /// Create an Agent with the given options.
    ///
    /// The agent stores the options and creates an internal ``AnthropicClient``
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

        // AnthropicClient requires a non-nil String — use empty string as fallback.
        // Calls to prompt()/stream() will fail naturally if no key was provided.
        let apiKey = options.apiKey ?? ""
        self.client = AnthropicClient(
            apiKey: apiKey,
            baseURL: options.baseURL
        )
    }

    /// Create an Agent with the given options and a pre-configured ``AnthropicClient``.
    ///
    /// This initializer is intended for testing and advanced scenarios where the
    /// caller needs to control the ``AnthropicClient`` configuration (e.g., custom
    /// URLSession for mock network interception).
    ///
    /// - Parameters:
    ///   - options: The configuration options for this agent.
    ///   - client: A pre-configured ``AnthropicClient`` instance to use for API calls.
    public init(options: AgentOptions, client: AnthropicClient) {
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
        var turnCount = 0
        var lastAssistantText = ""
        var status: QueryStatus = .success

        while turnCount < maxTurns {
            let response: [String: Any]
            do {
                response = try await client.sendMessage(
                    model: model,
                    messages: messages,
                    maxTokens: maxTokens,
                    system: buildSystemPrompt()
                )
            } catch {
                let elapsed = ContinuousClock.now - startTime
                let durationMs = Int(elapsed.components.seconds * 1000)
                    + Int(elapsed.components.attoseconds / 1_000_000_000_000)
                return QueryResult(
                    text: lastAssistantText,
                    usage: totalUsage,
                    numTurns: turnCount,
                    durationMs: durationMs,
                    messages: [],
                    status: .errorDuringExecution
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
            }

            // Extract content from response
            let content = response["content"]
            if let content {
                lastAssistantText = extractText(from: content)
            }

            // Add assistant message to conversation history
            messages.append([
                "role": "assistant",
                "content": content ?? []
            ])

            // Check stop_reason
            let stopReason = response["stop_reason"] as? String ?? ""

            // Terminate on end_turn or stop_sequence
            if stopReason == "end_turn" || stopReason == "stop_sequence" {
                break
            }

            // max_tokens also terminates in this story (no recovery)
            if stopReason == "max_tokens" {
                break
            }
        }

        // Determine status: if we exhausted maxTurns without a clean stop, it's an error
        if turnCount >= maxTurns {
            status = .errorMaxTurns
        }

        // Calculate duration in milliseconds
        let elapsed = ContinuousClock.now - startTime
        let durationMs = Int(elapsed.components.seconds * 1000)
            + Int(elapsed.components.attoseconds / 1_000_000_000_000)

        return QueryResult(
            text: lastAssistantText,
            usage: totalUsage,
            numTurns: turnCount,
            durationMs: durationMs,
            messages: [],
            status: status
        )
    }

    // MARK: - Private Helpers

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

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

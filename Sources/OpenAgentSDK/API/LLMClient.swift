import Foundation

/// A protocol defining the interface for LLM API clients.
///
/// Concrete implementations handle the specifics of different LLM provider APIs
/// (Anthropic, OpenAI-compatible, etc.) while presenting a uniform interface to the Agent.
public protocol LLMClient: Sendable {
    /// Send a non-streaming message request and return the full response.
    ///
    /// The response dictionary uses Anthropic-format structure for compatibility
    /// with the Agent's processing logic.
    nonisolated func sendMessage(
        model: String,
        messages: [[String: Any]],
        maxTokens: Int,
        system: String?,
        tools: [[String: Any]]?,
        toolChoice: [String: Any]?,
        thinking: [String: Any]?,
        temperature: Double?
    ) async throws -> [String: Any]

    /// Send a streaming message request and return an async stream of SSE events.
    ///
    /// The stream yields ``SSEEvent`` values using Anthropic-format event types
    /// for compatibility with the Agent's streaming logic.
    nonisolated func streamMessage(
        model: String,
        messages: [[String: Any]],
        maxTokens: Int,
        system: String?,
        tools: [[String: Any]]?,
        toolChoice: [String: Any]?,
        thinking: [String: Any]?,
        temperature: Double?
    ) async throws -> AsyncThrowingStream<SSEEvent, Error>
}

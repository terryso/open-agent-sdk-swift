import Foundation

/// Streaming message union type for agent communication.
///
/// `SDKMessage` is the primary event type yielded by ``Agent/stream(_:)``. Each case
/// represents a different stage or event in the agent's processing loop. Use a `switch`
/// statement to handle the events you care about:
///
/// ```swift
/// for await message in agent.stream("Hello") {
///     switch message {
///     case .partialMessage(let data):
///         print(data.text, terminator: "")
///     case .result(let data):
///         print("\nDone: \(data.status)")
///     default:
///         break
///     }
/// }
/// ```
public enum SDKMessage: Sendable {
    /// An assistant response with text, model info, and stop reason.
    case assistant(AssistantData)
    /// A tool invocation request from the LLM.
    case toolUse(ToolUseData)
    /// A tool execution result being fed back to the LLM.
    case toolResult(ToolResultData)
    /// The final result of the agent query.
    case result(ResultData)
    /// A partial text chunk during streaming.
    case partialMessage(PartialData)
    /// A system-level event (init, compact boundary, status, etc.).
    case system(SystemData)

    // MARK: - Convenience Computed Properties

    /// Text content, available for all variants.
    public var text: String {
        switch self {
        case .assistant(let data): return data.text
        case .toolUse(let data): return data.toolName
        case .result(let data): return data.text
        case .partialMessage(let data): return data.text
        case .toolResult(let data): return data.content
        case .system(let data): return data.message
        }
    }

    /// Model name, available only for `.assistant`.
    public var model: String? {
        guard case .assistant(let data) = self else { return nil }
        return data.model
    }

    /// Stop reason, available only for `.assistant`.
    public var stopReason: String? {
        guard case .assistant(let data) = self else { return nil }
        return data.stopReason
    }

    /// Tool use ID, available only for `.toolResult`.
    public var toolUseId: String? {
        guard case .toolResult(let data) = self else { return nil }
        return data.toolUseId
    }

    /// Content string, available only for `.toolResult`.
    public var content: String? {
        guard case .toolResult(let data) = self else { return nil }
        return data.content
    }

    /// Whether the tool result is an error, available only for `.toolResult`.
    public var isError: Bool? {
        guard case .toolResult(let data) = self else { return nil }
        return data.isError
    }

    /// Number of turns, available only for `.result`.
    public var numTurns: Int? {
        guard case .result(let data) = self else { return nil }
        return data.numTurns
    }

    /// Duration in milliseconds, available only for `.result`.
    public var durationMs: Int? {
        guard case .result(let data) = self else { return nil }
        return data.durationMs
    }

    /// System message, available only for `.system`.
    public var message: String? {
        guard case .system(let data) = self else { return nil }
        return data.message
    }

    // MARK: - Associated Data Types

    /// Data for an assistant response message.
    public struct AssistantData: Sendable, Equatable {
        /// The text content of the assistant's response.
        public let text: String
        /// The model identifier used for this response.
        public let model: String
        /// The reason the response stopped (e.g., "end_turn", "tool_use", "max_tokens").
        public let stopReason: String

        public init(text: String, model: String, stopReason: String) {
            self.text = text
            self.model = model
            self.stopReason = stopReason
        }
    }

    /// Data for a tool invocation message.
    public struct ToolUseData: Sendable, Equatable {
        /// The name of the tool being invoked.
        public let toolName: String
        /// A unique identifier for this tool use instance.
        public let toolUseId: String
        /// The raw JSON input for the tool call.
        public let input: String

        public init(toolName: String, toolUseId: String, input: String) {
            self.toolName = toolName
            self.toolUseId = toolUseId
            self.input = input
        }
    }

    /// Data for a tool result message.
    public struct ToolResultData: Sendable, Equatable {
        /// The tool use ID this result corresponds to.
        public let toolUseId: String
        /// The content returned by the tool.
        public let content: String
        /// Whether the tool execution resulted in an error.
        public let isError: Bool

        public init(toolUseId: String, content: String, isError: Bool) {
            self.toolUseId = toolUseId
            self.content = content
            self.isError = isError
        }
    }

    /// Final result data from an agent query.
    public struct ResultData: Sendable, Equatable {
        /// The result subtype indicating how the query terminated.
        public enum Subtype: String, Sendable, Equatable {
            /// The query completed successfully.
            case success
            /// The agent loop exceeded the configured maxTurns limit.
            case errorMaxTurns
            /// An API error occurred during execution.
            case errorDuringExecution
            /// The accumulated cost exceeded the configured budget limit.
            case errorMaxBudgetUsd
        }

        /// How the query terminated.
        public let subtype: Subtype
        /// The accumulated response text.
        public let text: String
        /// Token usage for the query, if available.
        public let usage: TokenUsage?
        /// Number of agent loop turns completed.
        public let numTurns: Int
        /// Total query duration in milliseconds.
        public let durationMs: Int
        /// Total cost in USD for this query.
        public let totalCostUsd: Double

        public init(subtype: Subtype, text: String, usage: TokenUsage?, numTurns: Int, durationMs: Int, totalCostUsd: Double = 0.0) {
            self.subtype = subtype
            self.text = text
            self.usage = usage
            self.numTurns = numTurns
            self.durationMs = durationMs
            self.totalCostUsd = totalCostUsd
        }
    }

    /// Partial text data during streaming.
    public struct PartialData: Sendable, Equatable {
        /// The text chunk received in this partial update.
        public let text: String

        public init(text: String) {
            self.text = text
        }
    }

    /// System-level event data.
    public struct SystemData: Sendable, Equatable {
        /// The type of system event.
        public enum Subtype: String, Sendable, Equatable {
            /// Session initialization.
            case `init`
            /// Conversation compaction boundary.
            case compactBoundary
            /// Status update.
            case status
            /// Task notification.
            case taskNotification
            /// Rate limit event.
            case rateLimit
        }

        /// The system event subtype.
        public let subtype: Subtype
        /// A human-readable message describing the event.
        public let message: String

        public init(subtype: Subtype, message: String) {
            self.subtype = subtype
            self.message = message
        }
    }
}

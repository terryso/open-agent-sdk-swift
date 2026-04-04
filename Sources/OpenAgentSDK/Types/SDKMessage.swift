import Foundation

/// Streaming message union type for agent communication.
public enum SDKMessage: Sendable {
    case assistant(AssistantData)
    case toolResult(ToolResultData)
    case result(ResultData)
    case partialMessage(PartialData)
    case system(SystemData)

    // MARK: - Convenience Computed Properties

    /// Text content, available for all variants.
    public var text: String {
        switch self {
        case .assistant(let data): return data.text
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

    public struct AssistantData: Sendable, Equatable {
        public let text: String
        public let model: String
        public let stopReason: String

        public init(text: String, model: String, stopReason: String) {
            self.text = text
            self.model = model
            self.stopReason = stopReason
        }
    }

    public struct ToolResultData: Sendable, Equatable {
        public let toolUseId: String
        public let content: String
        public let isError: Bool

        public init(toolUseId: String, content: String, isError: Bool) {
            self.toolUseId = toolUseId
            self.content = content
            self.isError = isError
        }
    }

    public struct ResultData: Sendable, Equatable {
        public enum Subtype: String, Sendable, Equatable {
            case success
            case errorMaxTurns
            case errorDuringExecution
            case errorMaxBudgetUsd
        }

        public let subtype: Subtype
        public let text: String
        public let usage: TokenUsage?
        public let numTurns: Int
        public let durationMs: Int

        public init(subtype: Subtype, text: String, usage: TokenUsage?, numTurns: Int, durationMs: Int) {
            self.subtype = subtype
            self.text = text
            self.usage = usage
            self.numTurns = numTurns
            self.durationMs = durationMs
        }
    }

    public struct PartialData: Sendable, Equatable {
        public let text: String

        public init(text: String) {
            self.text = text
        }
    }

    public struct SystemData: Sendable, Equatable {
        public enum Subtype: String, Sendable, Equatable {
            case `init`
            case compactBoundary
            case status
            case taskNotification
            case rateLimit
        }

        public let subtype: Subtype
        public let message: String

        public init(subtype: Subtype, message: String) {
            self.subtype = subtype
            self.message = message
        }
    }
}

import Foundation

/// Token usage tracking for LLM API calls.
public struct TokenUsage: Codable, Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
    }

    /// Sum of input and output tokens.
    public var totalTokens: Int {
        inputTokens + outputTokens
    }

    // MARK: - CodingKeys (snake_case API mapping)

    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }

    // MARK: - Addition Operator

    public static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            cacheCreationInputTokens: combineOptional(lhs.cacheCreationInputTokens, rhs.cacheCreationInputTokens),
            cacheReadInputTokens: combineOptional(lhs.cacheReadInputTokens, rhs.cacheReadInputTokens)
        )
    }

    private static func combineOptional(_ a: Int?, _ b: Int?) -> Int? {
        guard let a else { return b }
        guard let b else { return a }
        return a + b
    }
}

import Foundation

/// Token usage tracking for LLM API calls.
///
/// Tracks input and output token counts, including cache-related token usage
/// for Anthropic's prompt caching feature. Supports addition for aggregating
/// usage across multiple turns.
///
/// ```swift
/// let turn1 = TokenUsage(inputTokens: 100, outputTokens: 50)
/// let turn2 = TokenUsage(inputTokens: 200, outputTokens: 75)
/// let total = turn1 + turn2  // inputTokens: 300, outputTokens: 125
/// print(total.totalTokens)   // 425
/// ```
public struct TokenUsage: Codable, Sendable, Equatable {
    /// Number of input (prompt) tokens.
    public let inputTokens: Int
    /// Number of output (completion) tokens.
    public let outputTokens: Int
    /// Number of tokens written to the cache, if available.
    public let cacheCreationInputTokens: Int?
    /// Number of tokens read from the cache, if available.
    public let cacheReadInputTokens: Int?

    /// Creates a new token usage instance.
    ///
    /// - Parameters:
    ///   - inputTokens: Number of input (prompt) tokens.
    ///   - outputTokens: Number of output (completion) tokens.
    ///   - cacheCreationInputTokens: Number of tokens written to the cache. Defaults to `nil`.
    ///   - cacheReadInputTokens: Number of tokens read from the cache. Defaults to `nil`.
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

    /// Adds two token usage instances, summing all fields.
    ///
    /// Cache fields are combined: if both are non-nil they are summed; if one is nil
    /// the other is used.
    ///
    /// - Parameters:
    ///   - lhs: The first token usage.
    ///   - rhs: The second token usage.
    /// - Returns: A new ``TokenUsage`` with combined counts.
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

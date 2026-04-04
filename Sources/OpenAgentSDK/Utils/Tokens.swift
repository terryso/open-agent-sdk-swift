import Foundation

/// Context window sizes for known Anthropic models (in tokens).
private let MODEL_CONTEXT_WINDOWS: [String: Int] = [
    "claude-opus-4-6": 200_000,
    "claude-sonnet-4-6": 200_000,
    "claude-haiku-4-5": 200_000,
    "claude-sonnet-4-5": 200_000,
    "claude-opus-4-5": 200_000,
    "claude-3-5-sonnet": 200_000,
    "claude-3-5-haiku": 200_000,
    "claude-3-opus": 200_000,
]

/// Default context window size for unknown models.
private let DEFAULT_CONTEXT_WINDOW = 200_000

/// Buffer tokens reserved for autocompact operations (Story 2.5).
/// When the conversation approaches the context window limit, this buffer
/// ensures there is room for the system prompt and response after compaction.
public let AUTOCOMPACT_BUFFER_TOKENS: Int = 13_000

/// Estimate cost in USD from token usage and model name.
///
/// Uses fuzzy matching via `model.contains(key)` to match versioned model names
/// (e.g., "claude-sonnet-4-6-20250514" matches "claude-sonnet-4-6").
/// Falls back to claude-sonnet-equivalent pricing for unknown models:
/// `input: 3.0 / 1_000_000`, `output: 15.0 / 1_000_000`.
///
/// - Parameters:
///   - model: The model identifier string (may include version suffixes).
///   - usage: The token usage for this API call.
/// - Returns: The estimated cost in USD.
public func estimateCost(model: String, usage: TokenUsage) -> Double {
    let match = MODEL_PRICING.first { (key, _) in model.contains(key) }
    let pricing = match?.value ?? ModelPricing(
        input: 3.0 / 1_000_000,
        output: 15.0 / 1_000_000
    )
    return Double(usage.inputTokens) * pricing.input
         + Double(usage.outputTokens) * pricing.output
}

/// Get the context window size for a given model.
///
/// Uses fuzzy matching via `model.contains(key)` to match versioned model names.
/// Falls back to a default of 200,000 tokens for unknown models.
///
/// - Parameter model: The model identifier string.
/// - Returns: The context window size in tokens.
public func getContextWindowSize(model: String) -> Int {
    let match = MODEL_CONTEXT_WINDOWS.first { (key, _) in model.contains(key) }
    return match?.value ?? DEFAULT_CONTEXT_WINDOW
}

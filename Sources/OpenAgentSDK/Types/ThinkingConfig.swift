import Foundation

/// Configuration for LLM thinking/reasoning capabilities.
///
/// Controls whether the model uses extended thinking during response generation.
/// Extended thinking can improve response quality for complex reasoning tasks.
///
/// ```swift
/// // Enable thinking with a specific token budget
/// let config = ThinkingConfig.enabled(budgetTokens: 10000)
///
/// // Use adaptive thinking (model decides)
/// let config = ThinkingConfig.adaptive
/// ```
public enum ThinkingConfig: Sendable, Equatable {
    /// The model decides when to use extended thinking.
    case adaptive
    /// Extended thinking is enabled with a specific token budget.
    case enabled(budgetTokens: Int)
    /// Extended thinking is disabled.
    case disabled

    /// Validate the configuration, throwing if invalid.
    ///
    /// - Throws: ``SDKError/invalidConfiguration`` if `budgetTokens` is
    ///   zero or negative for the `.enabled` case.
    public func validate() throws {
        switch self {
        case .enabled(let budgetTokens):
            guard budgetTokens > 0 else {
                throw SDKError.invalidConfiguration(
                    "ThinkingConfig budgetTokens must be positive, got \(budgetTokens)"
                )
            }
        case .adaptive, .disabled:
            break
        }
    }
}

import Foundation

/// Configuration for LLM thinking/reasoning capabilities.
public enum ThinkingConfig: Sendable, Equatable {
    case adaptive
    case enabled(budgetTokens: Int)
    case disabled
}

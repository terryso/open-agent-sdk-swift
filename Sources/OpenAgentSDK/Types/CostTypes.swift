import Foundation

/// Per-model cost entry for CostTracker breakdowns.
public struct ModelCostEntry: Sendable, Equatable {
    /// The model identifier this entry tracks.
    public let model: String
    /// Total input tokens consumed by this model.
    public let inputTokens: Int
    /// Total output tokens produced by this model.
    public let outputTokens: Int
    /// Estimated cost in USD for this model's usage.
    public let estimatedCostUsd: Double

    public init(model: String, inputTokens: Int, outputTokens: Int, estimatedCostUsd: Double) {
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.estimatedCostUsd = estimatedCostUsd
    }
}

/// Aggregated cost summary returned by ``CostTracker/getSummary()``.
public struct CostSummary: Sendable, Equatable {
    /// Total number of LLM API calls across all models.
    public let modelCalls: Int
    /// Total tokens (input + output) across all models.
    public let totalTokens: Int
    /// Estimated total cost in USD across all models.
    public let estimatedCostUsd: Double
    /// Per-model cost breakdown.
    public let costBreakdown: [ModelCostEntry]

    public init(modelCalls: Int, totalTokens: Int, estimatedCostUsd: Double, costBreakdown: [ModelCostEntry]) {
        self.modelCalls = modelCalls
        self.totalTokens = totalTokens
        self.estimatedCostUsd = estimatedCostUsd
        self.costBreakdown = costBreakdown
    }
}

/// Result of a budget check against a configured limit.
public enum BudgetCheckResult: Sendable, Equatable {
    /// The accumulated cost is within the budget.
    case ok
    /// The accumulated cost has exceeded the budget limit.
    case budgetExceeded(currentCost: Double, limit: Double)
}

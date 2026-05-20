import Foundation

/// Tracks token usage and estimated cost across LLM API calls within a single agent run.
///
/// `CostTracker` is a value type (struct) — each `stream()` call creates its own instance
/// and mutates it in the single-threaded agent loop. No shared mutable state, no actor needed.
///
/// ```swift
/// var tracker = CostTracker(model: "claude-sonnet-4-6", maxBudgetUsd: 1.0)
/// tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 1000, outputTokens: 500))
/// if case .budgetExceeded = tracker.checkBudget() { /* stop execution */ }
/// let summary = tracker.getSummary()
/// ```
public struct CostTracker: Sendable {
    /// The primary model identifier.
    public let model: String
    /// Optional budget limit in USD.
    public let maxBudgetUsd: Double?

    // Internal accumulation state
    private var totalInputTokens: Int = 0
    private var totalOutputTokens: Int = 0
    private var estimatedCostUsd: Double = 0.0
    private var modelCalls: Int = 0
    private var costBreakdown: [String: ModelCostEntry] = [:]

    public init(model: String, maxBudgetUsd: Double? = nil) {
        self.model = model
        self.maxBudgetUsd = maxBudgetUsd
    }

    /// Record token usage from an LLM API response.
    ///
    /// Computes cost via ``estimateCost(model:usage:)``, accumulates totals, and
    /// updates the per-model breakdown.
    public mutating func recordUsage(model: String, usage: TokenUsage) {
        let cost = estimateCost(model: model, usage: usage)
        totalInputTokens += usage.inputTokens
        totalOutputTokens += usage.outputTokens
        estimatedCostUsd += cost
        modelCalls += 1

        if var existing = costBreakdown[model] {
            costBreakdown[model] = ModelCostEntry(
                model: model,
                inputTokens: existing.inputTokens + usage.inputTokens,
                outputTokens: existing.outputTokens + usage.outputTokens,
                estimatedCostUsd: existing.estimatedCostUsd + cost
            )
        } else {
            costBreakdown[model] = ModelCostEntry(
                model: model,
                inputTokens: usage.inputTokens,
                outputTokens: usage.outputTokens,
                estimatedCostUsd: cost
            )
        }
    }

    /// Check whether the accumulated cost has exceeded the budget limit.
    public func checkBudget() -> BudgetCheckResult {
        guard let limit = maxBudgetUsd else { return .ok }
        if estimatedCostUsd > limit {
            return .budgetExceeded(currentCost: estimatedCostUsd, limit: limit)
        }
        return .ok
    }

    /// Return a snapshot of all tracked cost data.
    public func getSummary() -> CostSummary {
        CostSummary(
            modelCalls: modelCalls,
            totalTokens: totalInputTokens + totalOutputTokens,
            estimatedCostUsd: estimatedCostUsd,
            costBreakdown: Array(costBreakdown.values)
        )
    }
}

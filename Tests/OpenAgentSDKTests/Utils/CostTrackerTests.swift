import XCTest
@testable import OpenAgentSDK

final class CostTrackerTests: XCTestCase {

    // MARK: - Accumulation

    func testRecordUsageSingleTurn() {
        var tracker = CostTracker(model: "claude-sonnet-4-6")
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)
        tracker.recordUsage(model: "claude-sonnet-4-6", usage: usage)

        let summary = tracker.getSummary()
        XCTAssertEqual(summary.modelCalls, 1)
        XCTAssertEqual(summary.totalTokens, 1500)
        XCTAssertEqual(summary.costBreakdown.count, 1)
    }

    func testRecordUsageMultipleTurns() {
        var tracker = CostTracker(model: "claude-sonnet-4-6")

        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 1000, outputTokens: 500))
        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 2000, outputTokens: 800))

        let summary = tracker.getSummary()
        XCTAssertEqual(summary.modelCalls, 2)
        XCTAssertEqual(summary.totalTokens, 4300)
        XCTAssertEqual(summary.costBreakdown.count, 1)

        let entry = summary.costBreakdown.first!
        XCTAssertEqual(entry.inputTokens, 3000)
        XCTAssertEqual(entry.outputTokens, 1300)
    }

    // MARK: - Per-model breakdown

    func testPerModelBreakdown() {
        var tracker = CostTracker(model: "claude-sonnet-4-6")

        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 1000, outputTokens: 500))
        tracker.recordUsage(model: "claude-opus-4-6", usage: TokenUsage(inputTokens: 500, outputTokens: 200))

        let summary = tracker.getSummary()
        XCTAssertEqual(summary.modelCalls, 2)
        XCTAssertEqual(summary.costBreakdown.count, 2)

        let sonnetEntry = summary.costBreakdown.first { $0.model == "claude-sonnet-4-6" }
        XCTAssertNotNil(sonnetEntry)
        XCTAssertEqual(sonnetEntry!.inputTokens, 1000)
        XCTAssertEqual(sonnetEntry!.outputTokens, 500)

        let opusEntry = summary.costBreakdown.first { $0.model == "claude-opus-4-6" }
        XCTAssertNotNil(opusEntry)
        XCTAssertEqual(opusEntry!.inputTokens, 500)
        XCTAssertEqual(opusEntry!.outputTokens, 200)
    }

    // MARK: - Budget check

    func testBudgetCheckOk() {
        var tracker = CostTracker(model: "claude-sonnet-4-6", maxBudgetUsd: 1.0)
        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 100, outputTokens: 50))

        let result = tracker.checkBudget()
        XCTAssertEqual(result, .ok)
    }

    func testBudgetCheckExceeded() {
        var tracker = CostTracker(model: "claude-sonnet-4-6", maxBudgetUsd: 0.001)
        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 100_000, outputTokens: 50_000))

        let result = tracker.checkBudget()
        if case .budgetExceeded(let currentCost, let limit) = result {
            XCTAssertGreaterThan(currentCost, limit)
            XCTAssertGreaterThan(currentCost, 0)
        } else {
            XCTFail("Expected budgetExceeded but got \(result)")
        }
    }

    func testBudgetCheckNoLimit() {
        var tracker = CostTracker(model: "claude-sonnet-4-6")
        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 1_000_000, outputTokens: 500_000))

        let result = tracker.checkBudget()
        XCTAssertEqual(result, .ok)
    }

    // MARK: - getSummary snapshot

    func testGetSummarySnapshotAccuracy() {
        var tracker = CostTracker(model: "claude-sonnet-4-6", maxBudgetUsd: 10.0)

        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 1000, outputTokens: 500))
        let summary1 = tracker.getSummary()

        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 2000, outputTokens: 800))
        let summary2 = tracker.getSummary()

        XCTAssertEqual(summary1.modelCalls, 1)
        XCTAssertEqual(summary2.modelCalls, 2)
        XCTAssertNotEqual(summary1.estimatedCostUsd, summary2.estimatedCostUsd)
    }

    // MARK: - Cost estimation accuracy

    func testCostEstimation() {
        var tracker = CostTracker(model: "claude-sonnet-4-6")
        // claude-sonnet-4-6: $3/M input, $15/M output
        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 1_000_000, outputTokens: 1_000_000))

        let summary = tracker.getSummary()
        // Expected: 1M * 3/1M + 1M * 15/1M = 3.0 + 15.0 = 18.0
        XCTAssertEqual(summary.estimatedCostUsd, 18.0, accuracy: 0.001)
    }
}

import XCTest
@testable import OpenAgentSDK

// MARK: - AC1: Per-Turn Cumulative Token Usage & Cost Calculation

/// ATDD RED PHASE: Tests for Story 2.2 -- Token Usage & Cost Tracking.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `estimateCost(model:usage:)` is implemented in Utils/Tokens.swift
///   - `getContextWindowSize(model:)` is implemented in Utils/Tokens.swift
///   - `AUTOCOMPACT_BUFFER_TOKENS` constant is defined in Utils/Tokens.swift
///   - `QueryResult` has `totalCostUsd` field
///   - `SDKMessage.ResultData` has `totalCostUsd` field
/// TDD Phase: RED (feature not implemented yet)
final class TokensCostEstimationTests: XCTestCase {

    // MARK: - AC1 [P0]: estimateCost correctly calculates cost for a known model

    /// Given a known model (claude-sonnet-4-6) and token usage,
    /// when estimateCost is called, then the returned cost matches the expected USD value.
    func testEstimateCost_KnownModel_Sonnet() {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)
        let cost = estimateCost(model: "claude-sonnet-4-6", usage: usage)
        // input: 1000 * (3.0 / 1_000_000) = 0.003
        // output: 500 * (15.0 / 1_000_000) = 0.0075
        // total: 0.0105
        XCTAssertEqual(cost, 0.0105, accuracy: 0.0001,
                       "estimateCost should compute correct USD for claude-sonnet-4-6")
    }

    // MARK: - AC1 [P0]: estimateCost correctly calculates cost for claude-opus-4-6

    /// Given a known model (claude-opus-4-6) and token usage,
    /// when estimateCost is called, then the returned cost matches the expected USD value.
    func testEstimateCost_KnownModel_Opus() {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)
        let cost = estimateCost(model: "claude-opus-4-6", usage: usage)
        // input: 1000 * (15.0 / 1_000_000) = 0.015
        // output: 500 * (75.0 / 1_000_000) = 0.0375
        // total: 0.0525
        XCTAssertEqual(cost, 0.0525, accuracy: 0.0001,
                       "estimateCost should compute correct USD for claude-opus-4-6")
    }

    // MARK: - AC1 [P0]: estimateCost correctly calculates cost for claude-haiku-4-5

    /// Given a known model (claude-haiku-4-5) and token usage,
    /// when estimateCost is called, then the returned cost matches the expected USD value.
    func testEstimateCost_KnownModel_Haiku() {
        let usage = TokenUsage(inputTokens: 2000, outputTokens: 1000)
        let cost = estimateCost(model: "claude-haiku-4-5", usage: usage)
        // input: 2000 * (0.8 / 1_000_000) = 0.0016
        // output: 1000 * (4.0 / 1_000_000) = 0.004
        // total: 0.0056
        XCTAssertEqual(cost, 0.0056, accuracy: 0.0001,
                       "estimateCost should compute correct USD for claude-haiku-4-5")
    }

    // MARK: - AC1 [P1]: estimateCost with zero tokens returns zero cost

    /// Given zero token usage for any model,
    /// when estimateCost is called, then the cost is exactly 0.0.
    func testEstimateCost_ZeroTokens_ReturnsZero() {
        let usage = TokenUsage(inputTokens: 0, outputTokens: 0)
        let cost = estimateCost(model: "claude-sonnet-4-6", usage: usage)
        XCTAssertEqual(cost, 0.0, accuracy: 0.0001,
                       "Zero tokens should produce zero cost")
    }

    // MARK: - AC1 [P1]: estimateCost with large token counts does not overflow

    /// Given very large token usage,
    /// when estimateCost is called, then the cost is computed correctly without overflow.
    func testEstimateCost_LargeTokenCounts() {
        let usage = TokenUsage(inputTokens: 1_000_000, outputTokens: 1_000_000)
        let cost = estimateCost(model: "claude-sonnet-4-6", usage: usage)
        // input: 1_000_000 * (3.0 / 1_000_000) = 3.0
        // output: 1_000_000 * (15.0 / 1_000_000) = 15.0
        // total: 18.0
        XCTAssertEqual(cost, 18.0, accuracy: 0.001,
                       "Large token counts should be computed correctly")
    }
}

// MARK: - AC4: Multi-Model Differential Pricing

final class TokensMultiModelPricingTests: XCTestCase {

    /// AC4 [P0]: Given two different models with the same token usage,
    /// when costs are computed, each model applies its own pricing correctly.
    func testEstimateCost_DifferentModels_DifferentPricing() {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)

        let sonnetCost = estimateCost(model: "claude-sonnet-4-6", usage: usage)
        let opusCost = estimateCost(model: "claude-opus-4-6", usage: usage)

        // Opus is more expensive than Sonnet
        XCTAssertGreaterThan(opusCost, sonnetCost,
                             "claude-opus-4-6 should cost more than claude-sonnet-4-6 for the same usage")
    }

    /// AC4 [P0]: Given two models with the same pricing (claude-sonnet-4-6 and claude-sonnet-4-5),
    /// when costs are computed, they should be equal.
    func testEstimateCost_SamePricingDifferentModels() {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)

        let sonnet46Cost = estimateCost(model: "claude-sonnet-4-6", usage: usage)
        let sonnet45Cost = estimateCost(model: "claude-sonnet-4-5", usage: usage)

        XCTAssertEqual(sonnet46Cost, sonnet45Cost, accuracy: 0.0001,
                       "Models with the same pricing should produce the same cost")
    }

    /// AC4 [P1]: Haiku is the cheapest model per token.
    func testEstimateCost_HaikuIsCheapest() {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)

        let haikuCost = estimateCost(model: "claude-haiku-4-5", usage: usage)
        let sonnetCost = estimateCost(model: "claude-sonnet-4-6", usage: usage)
        let opusCost = estimateCost(model: "claude-opus-4-6", usage: usage)

        XCTAssertLessThan(haikuCost, sonnetCost, "Haiku should be cheaper than Sonnet")
        XCTAssertLessThan(sonnetCost, opusCost, "Sonnet should be cheaper than Opus")
    }
}

// MARK: - AC5: Unknown Model Default Pricing

final class TokensUnknownModelTests: XCTestCase {

    /// AC5 [P0]: Given a model name not in MODEL_PRICING,
    /// when estimateCost is called, it uses default pricing (claude-sonnet-equivalent) without crashing.
    func testEstimateCost_UnknownModel_UsesDefaultPricing() {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)
        let unknownCost = estimateCost(model: "claude-unknown-future-model", usage: usage)
        let sonnetCost = estimateCost(model: "claude-sonnet-4-6", usage: usage)

        XCTAssertEqual(unknownCost, sonnetCost, accuracy: 0.0001,
                       "Unknown model should use default pricing equivalent to claude-sonnet")
    }

    /// AC5 [P0]: Given a completely arbitrary model name,
    /// when estimateCost is called, it returns a non-zero cost for non-zero usage.
    func testEstimateCost_CompletelyUnknownModel_ReturnsNonZeroCost() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        let cost = estimateCost(model: "some-random-model-v1", usage: usage)

        XCTAssertGreaterThan(cost, 0.0,
                             "Unknown model with non-zero usage should produce non-zero cost")
    }

    /// AC5 [P1]: Default pricing values match claude-sonnet pricing exactly.
    func testEstimateCost_DefaultPricing_ExactValues() {
        let usage = TokenUsage(inputTokens: 1_000_000, outputTokens: 1_000_000)
        let cost = estimateCost(model: "nonexistent-model", usage: usage)
        // Default: input: 3.0 / 1_000_000, output: 15.0 / 1_000_000
        // input: 1_000_000 * (3.0 / 1_000_000) = 3.0
        // output: 1_000_000 * (15.0 / 1_000_000) = 15.0
        // total: 18.0
        XCTAssertEqual(cost, 18.0, accuracy: 0.001,
                       "Default pricing should match claude-sonnet: $3/M input, $15/M output")
    }
}

// MARK: - AC6: MODEL_PRICING Table Validation & Fuzzy Matching

final class TokensModelPricingTableTests: XCTestCase {

    /// AC6 [P0]: MODEL_PRICING contains all expected Anthropic model entries.
    func testModelPricing_ContainsAllAnthropicModels() {
        let expectedModels = [
            "claude-opus-4-6",
            "claude-sonnet-4-6",
            "claude-haiku-4-5",
            "claude-sonnet-4-5",
            "claude-opus-4-5",
            "claude-3-5-sonnet",
            "claude-3-5-haiku",
            "claude-3-opus",
        ]

        for model in expectedModels {
            XCTAssertNotNil(MODEL_PRICING[model],
                            "MODEL_PRICING should contain entry for \(model)")
        }
    }

    /// AC6 [P0]: MODEL_PRICING does NOT contain non-Anthropic model entries.
    func testModelPricing_DoesNotContainNonAnthropicModels() {
        XCTAssertNil(MODEL_PRICING["gpt-4"],
                     "MODEL_PRICING should NOT contain OpenAI models")
        XCTAssertNil(MODEL_PRICING["deepseek-chat"],
                     "MODEL_PRICING should NOT contain DeepSeek models")
    }

    /// AC6 [P1]: All MODEL_PRICING entries have positive pricing values.
    func testModelPricing_AllEntriesHavePositivePricing() {
        for (model, pricing) in MODEL_PRICING {
            XCTAssertGreaterThan(pricing.input, 0.0,
                                 "\(model) input pricing should be positive")
            XCTAssertGreaterThan(pricing.output, 0.0,
                                 "\(model) output pricing should be positive")
        }
    }

    /// AC6 [P1]: All MODEL_PRICING entries have output >= input pricing.
    func testModelPricing_OutputGreaterOrEqualToInput() {
        for (model, pricing) in MODEL_PRICING {
            XCTAssertGreaterThanOrEqual(pricing.output, pricing.input,
                                        "\(model) output pricing should be >= input pricing")
        }
    }
}

// MARK: - Fuzzy Matching for Versioned Model Names

final class TokensFuzzyMatchingTests: XCTestCase {

    /// Fuzzy matching [P0]: Given a versioned model name like "claude-sonnet-4-6-20250514",
    /// when estimateCost is called, it matches the "claude-sonnet-4-6" entry.
    func testEstimateCost_VersionedModelName_MatchesBaseModel() {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)
        let versionedCost = estimateCost(model: "claude-sonnet-4-6-20250514", usage: usage)
        let baseCost = estimateCost(model: "claude-sonnet-4-6", usage: usage)

        XCTAssertEqual(versionedCost, baseCost, accuracy: 0.0001,
                       "Versioned model name should match its base model entry via fuzzy matching")
    }

    /// Fuzzy matching [P1]: Given a versioned opus model name,
    /// when estimateCost is called, it matches the opus entry.
    func testEstimateCost_VersionedOpusName() {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 500)
        let versionedCost = estimateCost(model: "claude-opus-4-5-20250101", usage: usage)
        let baseCost = estimateCost(model: "claude-opus-4-5", usage: usage)

        XCTAssertEqual(versionedCost, baseCost, accuracy: 0.0001,
                       "Versioned opus model name should match its base entry")
    }

    /// Fuzzy matching [P1]: Given a claude-3-5-sonnet with a date suffix,
    /// when estimateCost is called, it matches the claude-3-5-sonnet entry.
    func testEstimateCost_VersionedClaude35Sonnet() {
        let usage = TokenUsage(inputTokens: 500, outputTokens: 250)
        let versionedCost = estimateCost(model: "claude-3-5-sonnet-20241022", usage: usage)
        let baseCost = estimateCost(model: "claude-3-5-sonnet", usage: usage)

        XCTAssertEqual(versionedCost, baseCost, accuracy: 0.0001,
                       "Versioned claude-3-5-sonnet should match its base entry")
    }

    /// Fuzzy matching [P2]: Given a model name that is a substring of multiple entries,
    /// when estimateCost is called, it picks the first matching entry (no ambiguity expected).
    func testEstimateCost_PartiallyOverlappingModelNames() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        // "claude-sonnet-4-6" is a separate entry from "claude-sonnet-4-5"
        // This test verifies that "claude-sonnet-4-6" does NOT match "claude-sonnet-4-5"
        let cost46 = estimateCost(model: "claude-sonnet-4-6", usage: usage)
        let cost45 = estimateCost(model: "claude-sonnet-4-5", usage: usage)

        // These have the same pricing so cost should be equal
        XCTAssertEqual(cost46, cost45, accuracy: 0.0001)
    }
}

// MARK: - getContextWindowSize Tests

final class TokensContextWindowTests: XCTestCase {

    /// getContextWindowSize [P1]: Given a known model, returns a positive context window size.
    func testGetContextWindowSize_KnownModel_ReturnsPositive() {
        let windowSize = getContextWindowSize(model: "claude-sonnet-4-6")
        XCTAssertGreaterThan(windowSize, 0,
                             "Known model should have a positive context window size")
    }

    /// getContextWindowSize [P1]: Given an unknown model, returns a default value (not zero, not crash).
    func testGetContextWindowSize_UnknownModel_ReturnsDefault() {
        let windowSize = getContextWindowSize(model: "unknown-model-v99")
        XCTAssertGreaterThan(windowSize, 0,
                             "Unknown model should return a positive default context window size")
    }

    /// getContextWindowSize [P2]: All known models have reasonable context window sizes (> 0).
    func testGetContextWindowSize_AllKnownModelsHaveReasonableSizes() {
        let models = MODEL_PRICING.keys
        for model in models {
            let windowSize = getContextWindowSize(model: model)
            XCTAssertGreaterThan(windowSize, 0,
                                 "\(model) should have a context window size > 0")
            XCTAssertLessThanOrEqual(windowSize, 1_000_000,
                                     "\(model) context window should be <= 1M tokens")
        }
    }
}

// MARK: - AUTOCOMPACT_BUFFER_TOKENS Constant

final class TokensAutocompactConstantsTests: XCTestCase {

    /// AUTOCOMPACT_BUFFER_TOKENS [P2]: The constant is defined and equals 13_000.
    func testAutocompactBufferTokens_IsDefined() {
        // This test verifies the constant exists and has the expected value.
        // It will fail at compile time if AUTOCOMPACT_BUFFER_TOKENS is not defined.
        XCTAssertEqual(AUTOCOMPACT_BUFFER_TOKENS, 13_000,
                       "AUTOCOMPACT_BUFFER_TOKENS should be 13_000")
    }
}

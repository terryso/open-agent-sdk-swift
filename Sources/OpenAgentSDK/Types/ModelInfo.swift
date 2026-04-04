import Foundation

/// Model information and metadata.
public struct ModelInfo: Sendable, Equatable {
    public let value: String
    public let displayName: String
    public let description: String
    public let supportsEffort: Bool

    public init(value: String, displayName: String, description: String, supportsEffort: Bool = false) {
        self.value = value
        self.displayName = displayName
        self.description = description
        self.supportsEffort = supportsEffort
    }
}

/// Per-token pricing for a model.
public struct ModelPricing: Sendable, Equatable {
    public let input: Double
    public let output: Double

    public init(input: Double, output: Double) {
        self.input = input
        self.output = output
    }
}

/// Pricing table mapping model IDs to per-token costs (USD).
public let MODEL_PRICING: [String: ModelPricing] = [
    "claude-opus-4-6": ModelPricing(input: 15.0 / 1_000_000, output: 75.0 / 1_000_000),
    "claude-sonnet-4-6": ModelPricing(input: 3.0 / 1_000_000, output: 15.0 / 1_000_000),
    "claude-haiku-4-5": ModelPricing(input: 0.8 / 1_000_000, output: 4.0 / 1_000_000),
    "claude-sonnet-4-5": ModelPricing(input: 3.0 / 1_000_000, output: 15.0 / 1_000_000),
    "claude-opus-4-5": ModelPricing(input: 15.0 / 1_000_000, output: 75.0 / 1_000_000),
    "claude-3-5-sonnet": ModelPricing(input: 3.0 / 1_000_000, output: 15.0 / 1_000_000),
    "claude-3-5-haiku": ModelPricing(input: 0.8 / 1_000_000, output: 4.0 / 1_000_000),
    "claude-3-opus": ModelPricing(input: 15.0 / 1_000_000, output: 75.0 / 1_000_000),
]

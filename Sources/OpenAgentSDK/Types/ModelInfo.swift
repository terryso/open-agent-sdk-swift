import Foundation

/// Model information and metadata.
///
/// Describes a model's identifier, display name, description, and capabilities.
public struct ModelInfo: Sendable, Equatable {
    /// The model identifier string (e.g., "claude-sonnet-4-6").
    public let value: String
    /// A human-readable display name.
    public let displayName: String
    /// A description of the model's capabilities.
    public let description: String
    /// Whether the model supports the effort parameter for controlling response quality.
    public let supportsEffort: Bool

    public init(value: String, displayName: String, description: String, supportsEffort: Bool = false) {
        self.value = value
        self.displayName = displayName
        self.description = description
        self.supportsEffort = supportsEffort
    }
}

/// Per-token pricing for a model (in USD).
///
/// Prices are per million tokens. Use ``MODEL_PRICING`` to look up pricing by model ID.
public struct ModelPricing: Sendable, Equatable {
    /// Price per million input tokens.
    public let input: Double
    /// Price per million output tokens.
    public let output: Double

    public init(input: Double, output: Double) {
        self.input = input
        self.output = output
    }
}

/// Pricing table mapping model IDs to per-token costs (USD).
///
/// Configure custom models at startup via ``registerModel(_:pricing:)``.
/// Mutations are protected by an internal lock for thread safety.
public nonisolated(unsafe) var MODEL_PRICING: [String: ModelPricing] = [
    "claude-opus-4-6": ModelPricing(input: 15.0 / 1_000_000, output: 75.0 / 1_000_000),
    "claude-sonnet-4-6": ModelPricing(input: 3.0 / 1_000_000, output: 15.0 / 1_000_000),
    "claude-haiku-4-5": ModelPricing(input: 0.8 / 1_000_000, output: 4.0 / 1_000_000),
    "claude-sonnet-4-5": ModelPricing(input: 3.0 / 1_000_000, output: 15.0 / 1_000_000),
    "claude-opus-4-5": ModelPricing(input: 15.0 / 1_000_000, output: 75.0 / 1_000_000),
    "claude-3-5-sonnet": ModelPricing(input: 3.0 / 1_000_000, output: 15.0 / 1_000_000),
    "claude-3-5-haiku": ModelPricing(input: 0.8 / 1_000_000, output: 4.0 / 1_000_000),
    "claude-3-opus": ModelPricing(input: 15.0 / 1_000_000, output: 75.0 / 1_000_000),
]

private let _pricingLock: NSLock = {
    let lock = NSLock()
    lock.name = "ModelInfo.pricingLock"
    return lock
}()

/// Register pricing for a custom or updated model.
///
/// Use this to add pricing for models not included in the built-in table,
/// or to override pricing for existing models. Thread-safe.
///
/// - Parameters:
///   - modelId: The model identifier string (e.g., "my-custom-model").
///   - pricing: The per-token pricing for the model.
public func registerModel(_ modelId: String, pricing: ModelPricing) {
    _pricingLock.withLock {
        MODEL_PRICING[modelId] = pricing
    }
}

/// Remove pricing for a previously registered model.
///
/// Has no effect if the model ID is not in the pricing table. Thread-safe.
///
/// - Parameter modelId: The model identifier to remove.
public func unregisterModel(_ modelId: String) {
    _pricingLock.withLock {
        MODEL_PRICING.removeValue(forKey: modelId)
    }
}

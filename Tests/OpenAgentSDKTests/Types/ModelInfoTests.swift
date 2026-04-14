import XCTest
@testable import OpenAgentSDK

final class ModelInfoTests: XCTestCase {

    // MARK: - ModelInfo

    func testModelInfo_creation() {
        let info = ModelInfo(
            value: "claude-sonnet-4-6",
            displayName: "Claude Sonnet 4.6",
            description: "Fast model",
            supportsEffort: true
        )
        XCTAssertEqual(info.value, "claude-sonnet-4-6")
        XCTAssertEqual(info.displayName, "Claude Sonnet 4.6")
        XCTAssertEqual(info.description, "Fast model")
        XCTAssertTrue(info.supportsEffort)
    }

    func testModelInfo_defaultSupportsEffort() {
        let info = ModelInfo(value: "m", displayName: "M", description: "D")
        XCTAssertFalse(info.supportsEffort)
    }

    func testModelInfo_equality() {
        let a = ModelInfo(value: "m", displayName: "M", description: "D", supportsEffort: false)
        let b = ModelInfo(value: "m", displayName: "M", description: "D", supportsEffort: false)
        XCTAssertEqual(a, b)
    }

    func testModelInfo_inequality() {
        let a = ModelInfo(value: "m1", displayName: "M", description: "D")
        let b = ModelInfo(value: "m2", displayName: "M", description: "D")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - ModelPricing

    func testModelPricing_creation() {
        let pricing = ModelPricing(input: 3.0 / 1_000_000, output: 15.0 / 1_000_000)
        XCTAssertEqual(pricing.input, 3.0 / 1_000_000)
        XCTAssertEqual(pricing.output, 15.0 / 1_000_000)
    }

    func testModelPricing_equality() {
        let a = ModelPricing(input: 1.0, output: 2.0)
        let b = ModelPricing(input: 1.0, output: 2.0)
        XCTAssertEqual(a, b)
    }

    func testModelPricing_inequality() {
        let a = ModelPricing(input: 1.0, output: 2.0)
        let b = ModelPricing(input: 1.0, output: 3.0)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - MODEL_PRICING table

    func testModelPricingTable_count() {
        XCTAssertEqual(MODEL_PRICING.count, 8)
    }

    func testModelPricingTable_sonnet46() {
        let p = MODEL_PRICING["claude-sonnet-4-6"]
        XCTAssertNotNil(p)
        XCTAssertEqual(p!.input, 3.0 / 1_000_000, accuracy: 0.000000001)
        XCTAssertEqual(p!.output, 15.0 / 1_000_000, accuracy: 0.000000001)
    }

    func testModelPricingTable_opus46() {
        let p = MODEL_PRICING["claude-opus-4-6"]
        XCTAssertNotNil(p)
        XCTAssertEqual(p!.input, 15.0 / 1_000_000, accuracy: 0.000000001)
        XCTAssertEqual(p!.output, 75.0 / 1_000_000, accuracy: 0.000000001)
    }

    func testModelPricingTable_haiku45() {
        let p = MODEL_PRICING["claude-haiku-4-5"]
        XCTAssertNotNil(p)
        XCTAssertEqual(p!.input, 0.8 / 1_000_000, accuracy: 0.000000001)
        XCTAssertEqual(p!.output, 4.0 / 1_000_000, accuracy: 0.000000001)
    }

    func testModelPricingTable_unknownModelReturnsNil() {
        let p = MODEL_PRICING["unknown-model-xyz"]
        XCTAssertNil(p)
    }

    func testModelPricingTable_legacyModels() {
        XCTAssertNotNil(MODEL_PRICING["claude-3-5-sonnet"])
        XCTAssertNotNil(MODEL_PRICING["claude-3-5-haiku"])
        XCTAssertNotNil(MODEL_PRICING["claude-3-opus"])
    }

    // MARK: - registerModel / unregisterModel

    func testRegisterModel_addsNewModel() {
        let customPricing = ModelPricing(input: 1.0 / 1_000_000, output: 5.0 / 1_000_000)
        registerModel("my-custom-model", pricing: customPricing)
        XCTAssertEqual(MODEL_PRICING["my-custom-model"], customPricing)
        // Cleanup
        unregisterModel("my-custom-model")
    }

    func testRegisterModel_overwritesExisting() {
        let originalCount = MODEL_PRICING.count
        let overridePricing = ModelPricing(input: 0.0, output: 0.0)
        registerModel("claude-sonnet-4-6", pricing: overridePricing)
        XCTAssertEqual(MODEL_PRICING["claude-sonnet-4-6"], overridePricing)
        XCTAssertEqual(MODEL_PRICING.count, originalCount, "Count should stay the same when overwriting")
        // Restore original
        MODEL_PRICING["claude-sonnet-4-6"] = ModelPricing(input: 3.0 / 1_000_000, output: 15.0 / 1_000_000)
    }

    func testUnregisterModel_removesModel() {
        registerModel("temp-model", pricing: ModelPricing(input: 1.0, output: 2.0))
        XCTAssertNotNil(MODEL_PRICING["temp-model"])
        unregisterModel("temp-model")
        XCTAssertNil(MODEL_PRICING["temp-model"])
    }

    func testUnregisterModel_nonexistent_isNoOp() {
        let originalCount = MODEL_PRICING.count
        unregisterModel("nonexistent-model-xyz")
        XCTAssertEqual(MODEL_PRICING.count, originalCount)
    }
}

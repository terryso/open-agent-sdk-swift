import XCTest
@testable import OpenAgentSDK

final class PromptEvolutionTypesTests: XCTestCase {

    private static let testEncoder = JSONEncoder()
    private static let testDecoder = JSONDecoder()

    // MARK: - PromptEvolutionStrategy

    func testStrategyAllCases() {
        XCTAssertEqual(PromptEvolutionStrategy.allCases.count, 4)
        XCTAssertTrue(PromptEvolutionStrategy.allCases.contains(.refine))
        XCTAssertTrue(PromptEvolutionStrategy.allCases.contains(.expand))
        XCTAssertTrue(PromptEvolutionStrategy.allCases.contains(.compress))
        XCTAssertTrue(PromptEvolutionStrategy.allCases.contains(.safety))
    }

    func testStrategyRawValues() {
        XCTAssertEqual(PromptEvolutionStrategy.refine.rawValue, "refine")
        XCTAssertEqual(PromptEvolutionStrategy.expand.rawValue, "expand")
        XCTAssertEqual(PromptEvolutionStrategy.compress.rawValue, "compress")
        XCTAssertEqual(PromptEvolutionStrategy.safety.rawValue, "safety")
    }

    func testStrategyRawValueRoundTrip() {
        for strategy in PromptEvolutionStrategy.allCases {
            XCTAssertEqual(PromptEvolutionStrategy(rawValue: strategy.rawValue), strategy)
        }
    }

    func testStrategyCodableRoundTrip() throws {
        for strategy in PromptEvolutionStrategy.allCases {
            let data = try Self.testEncoder.encode(strategy)
            let decoded = try Self.testDecoder.decode(PromptEvolutionStrategy.self, from: data)
            XCTAssertEqual(decoded, strategy)
        }
    }

    // MARK: - PromptEvolutionConfig

    func testConfigDefaultValues() {
        let config = PromptEvolutionConfig()
        XCTAssertEqual(config.strategies, PromptEvolutionStrategy.allCases)
        XCTAssertEqual(config.evolutionModel, "claude-haiku-4-5-20251001")
        XCTAssertEqual(config.maxTokens, 2048)
        XCTAssertEqual(config.temperature, 0.3, accuracy: 0.001)
        XCTAssertEqual(config.minConversationLength, 6)
        XCTAssertEqual(config.maxChangesPerEvolution, 5)
    }

    func testConfigCustomValues() {
        let config = PromptEvolutionConfig(
            strategies: [.refine, .compress],
            evolutionModel: "claude-sonnet-4-6",
            maxTokens: 4096,
            temperature: 0.7,
            minConversationLength: 10,
            maxChangesPerEvolution: 3
        )
        XCTAssertEqual(config.strategies, [.refine, .compress])
        XCTAssertEqual(config.evolutionModel, "claude-sonnet-4-6")
        XCTAssertEqual(config.maxTokens, 4096)
        XCTAssertEqual(config.temperature, 0.7, accuracy: 0.001)
        XCTAssertEqual(config.minConversationLength, 10)
        XCTAssertEqual(config.maxChangesPerEvolution, 3)
    }

    func testConfigCodableRoundTrip() throws {
        let config = PromptEvolutionConfig(
            strategies: [.expand, .safety],
            evolutionModel: "test-model",
            maxTokens: 1024,
            temperature: 0.5,
            minConversationLength: 4,
            maxChangesPerEvolution: 8
        )
        let data = try Self.testEncoder.encode(config)
        let decoded = try Self.testDecoder.decode(PromptEvolutionConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testConfigEquatable() {
        let a = PromptEvolutionConfig()
        let b = PromptEvolutionConfig()
        XCTAssertEqual(a, b)

        let c = PromptEvolutionConfig(temperature: 0.5)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - PromptEvolutionConfig Validation
    // Note: precondition failures cannot be caught in Swift tests.
    // These tests verify boundary values that ARE accepted.

    func testConfigBoundaryTemperatureValues() {
        let low = PromptEvolutionConfig(temperature: 0.0)
        XCTAssertEqual(low.temperature, 0.0, accuracy: 0.001)

        let high = PromptEvolutionConfig(temperature: 1.0)
        XCTAssertEqual(high.temperature, 1.0, accuracy: 0.001)
    }

    func testConfigMinConversationLengthBoundary() {
        let config = PromptEvolutionConfig(minConversationLength: 2)
        XCTAssertEqual(config.minConversationLength, 2)
    }

    func testConfigSingleStrategy() {
        let config = PromptEvolutionConfig(strategies: [.refine])
        XCTAssertEqual(config.strategies, [.refine])
    }

    func testConfigMaxChangesPerEvolutionMinimum() {
        let config = PromptEvolutionConfig(maxChangesPerEvolution: 1)
        XCTAssertEqual(config.maxChangesPerEvolution, 1)
    }

    // MARK: - PromptChange

    func testChangeConstruction() {
        let change = PromptChange(
            strategy: .refine,
            section: "guidelines",
            original: "old text",
            modified: "new text",
            rationale: "improved clarity"
        )
        XCTAssertEqual(change.strategy, .refine)
        XCTAssertEqual(change.section, "guidelines")
        XCTAssertEqual(change.original, "old text")
        XCTAssertEqual(change.modified, "new text")
        XCTAssertEqual(change.rationale, "improved clarity")
    }

    func testChangeEquality() {
        let a = PromptChange(strategy: .safety, section: "s", original: "o", modified: "m", rationale: "r")
        let b = PromptChange(strategy: .safety, section: "s", original: "o", modified: "m", rationale: "r")
        XCTAssertEqual(a, b)

        let c = PromptChange(strategy: .expand, section: "s", original: "o", modified: "m", rationale: "r")
        XCTAssertNotEqual(a, c)
    }

    func testChangeCodableRoundTrip() throws {
        let change = PromptChange(
            strategy: .compress,
            section: "instructions",
            original: "verbose text",
            modified: "concise text",
            rationale: "reduce verbosity"
        )
        let data = try Self.testEncoder.encode(change)
        let decoded = try Self.testDecoder.decode(PromptChange.self, from: data)
        XCTAssertEqual(decoded, change)
    }

    // MARK: - PromptEvolutionResult

    func testResultConstruction() {
        let result = PromptEvolutionResult(
            shouldEvolve: true,
            evolvedPrompt: "evolved",
            changes: [],
            confidence: 0.85
        )
        XCTAssertTrue(result.shouldEvolve)
        XCTAssertEqual(result.evolvedPrompt, "evolved")
        XCTAssertTrue(result.changes.isEmpty)
        XCTAssertEqual(result.confidence, 0.85, accuracy: 0.001)
    }

    func testResultNoEvolutionFactory() {
        let result = PromptEvolutionResult.noEvolution()
        XCTAssertFalse(result.shouldEvolve)
        XCTAssertNil(result.evolvedPrompt)
        XCTAssertTrue(result.changes.isEmpty)
        XCTAssertEqual(result.confidence, 0, accuracy: 0.001)
    }

    func testResultEquality() {
        let date = Date()
        let a = PromptEvolutionResult(
            shouldEvolve: true,
            evolvedPrompt: "p",
            changes: [],
            confidence: 0.9,
            evolvedAt: date
        )
        let b = PromptEvolutionResult(
            shouldEvolve: true,
            evolvedPrompt: "p",
            changes: [],
            confidence: 0.9,
            evolvedAt: date
        )
        XCTAssertEqual(a, b)
    }

    func testResultInequality() {
        let date = Date()
        let a = PromptEvolutionResult(shouldEvolve: true, evolvedPrompt: "p", changes: [], confidence: 0.9, evolvedAt: date)
        let b = PromptEvolutionResult(shouldEvolve: false, evolvedPrompt: nil, changes: [], confidence: 0.0, evolvedAt: date)
        XCTAssertNotEqual(a, b)
    }

    func testResultConfidenceClampedHigh() {
        let result = PromptEvolutionResult(shouldEvolve: false, evolvedPrompt: nil, changes: [], confidence: 5.0)
        XCTAssertEqual(result.confidence, 1.0, accuracy: 0.001)
    }

    func testResultConfidenceClampedLow() {
        let result = PromptEvolutionResult(shouldEvolve: false, evolvedPrompt: nil, changes: [], confidence: -2.0)
        XCTAssertEqual(result.confidence, 0.0, accuracy: 0.001)
    }

    func testResultConfidenceBoundaryValues() {
        let atZero = PromptEvolutionResult(shouldEvolve: false, evolvedPrompt: nil, changes: [], confidence: 0.0)
        XCTAssertEqual(atZero.confidence, 0.0, accuracy: 0.001)

        let atOne = PromptEvolutionResult(shouldEvolve: false, evolvedPrompt: nil, changes: [], confidence: 1.0)
        XCTAssertEqual(atOne.confidence, 1.0, accuracy: 0.001)
    }
}

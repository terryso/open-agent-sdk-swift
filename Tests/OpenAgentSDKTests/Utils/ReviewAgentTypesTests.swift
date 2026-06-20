import XCTest
@testable import OpenAgentSDK

final class ReviewAgentTypesTests: XCTestCase {

    // MARK: - ReviewAgentConfig

    func testConfigDefaultValues() {
        let config = ReviewAgentConfig()
        XCTAssertTrue(config.reviewMemory)
        XCTAssertTrue(config.reviewSkills)
        XCTAssertEqual(config.maxTurns, 16)
        XCTAssertEqual(config.allowedTools, [
            "review_save_memory",
            "review_update_skill",
            "review_create_skill",
            "review_add_skill_file",
            "curator_archive_skill",
        ])
    }

    func testConfigCustomValues() {
        let config = ReviewAgentConfig(
            reviewMemory: false,
            reviewSkills: true,
            maxTurns: 8,
            allowedTools: ["review_save_memory"]
        )
        XCTAssertFalse(config.reviewMemory)
        XCTAssertTrue(config.reviewSkills)
        XCTAssertEqual(config.maxTurns, 8)
        XCTAssertEqual(config.allowedTools, ["review_save_memory"])
    }

    func testConfigCodableRoundTrip() throws {
        let config = ReviewAgentConfig(
            reviewMemory: true,
            reviewSkills: false,
            maxTurns: 5,
            allowedTools: ["review_update_skill", "review_create_skill"]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(ReviewAgentConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testConfigEquatable() {
        let a = ReviewAgentConfig()
        let b = ReviewAgentConfig()
        XCTAssertEqual(a, b)

        let c = ReviewAgentConfig(maxTurns: 5)
        XCTAssertNotEqual(a, c)
    }

    // Note: precondition validation for maxTurns<=0 and empty allowedTools
    // is enforced at runtime via precondition() and cannot be tested in-process
    // without crashing XCTest. The following invalid constructions trigger
    // preconditionFailure:
    //   ReviewAgentConfig(maxTurns: 0)
    //   ReviewAgentConfig(maxTurns: -1)
    //   ReviewAgentConfig(allowedTools: [])

    // MARK: - ReviewAgentResult

    func testResultConstruction() {
        let result = ReviewAgentResult(
            memoryChanges: ["Added fact about user preference"],
            skillChanges: ["Updated testing skill"],
            summary: "Made 2 changes",
            reviewMessages: [.result(SDKMessage.ResultData(
                subtype: .success,
                text: "done",
                usage: nil,
                numTurns: 1,
                durationMs: 100
            ))]
        )
        XCTAssertEqual(result.memoryChanges, ["Added fact about user preference"])
        XCTAssertEqual(result.skillChanges, ["Updated testing skill"])
        XCTAssertEqual(result.summary, "Made 2 changes")
        XCTAssertEqual(result.reviewMessages.count, 1)
    }

    func testResultEquality() {
        let a = ReviewAgentResult(
            memoryChanges: ["a"],
            skillChanges: ["b"],
            summary: "test",
            reviewMessages: []
        )
        let b = ReviewAgentResult(
            memoryChanges: ["a"],
            skillChanges: ["b"],
            summary: "test",
            reviewMessages: []
        )
        XCTAssertEqual(a, b)
    }

    func testResultInequality() {
        let a = ReviewAgentResult(
            memoryChanges: ["a"],
            skillChanges: [],
            summary: "test",
            reviewMessages: []
        )
        let b = ReviewAgentResult(
            memoryChanges: ["b"],
            skillChanges: [],
            summary: "test",
            reviewMessages: []
        )
        XCTAssertNotEqual(a, b)
    }

    func testNoChangesFactory() {
        let result = ReviewAgentResult.noChanges(summary: "Nothing to save.")
        XCTAssertTrue(result.memoryChanges.isEmpty)
        XCTAssertTrue(result.skillChanges.isEmpty)
        XCTAssertEqual(result.summary, "Nothing to save.")
        XCTAssertTrue(result.reviewMessages.isEmpty)
    }

    // MARK: - didSet precondition paths (covers lines 20, 26)

    /// Setting maxTurns via property assignment triggers the didSet
    /// precondition (must be > 0). Valid value → no crash.
    func testConfig_maxTurnsSetter_acceptsPositiveValue() {
        var config = ReviewAgentConfig()
        config.maxTurns = 32
        XCTAssertEqual(config.maxTurns, 32)
    }

    /// Setting allowedTools via property assignment triggers the didSet
    /// precondition (must be non-empty). Valid value → no crash.
    func testConfig_allowedToolsSetter_acceptsNonEmptyArray() {
        var config = ReviewAgentConfig()
        config.allowedTools = ["review_save_memory", "review_update_skill"]
        XCTAssertEqual(config.allowedTools.count, 2)
    }

    /// Setting promptSuffix via property assignment.
    func testConfig_promptSuffixSetter_acceptsNilAndValue() {
        var config = ReviewAgentConfig()
        XCTAssertNil(config.promptSuffix)
        config.promptSuffix = "Focus on memory facts."
        XCTAssertEqual(config.promptSuffix, "Focus on memory facts.")
        config.promptSuffix = nil
        XCTAssertNil(config.promptSuffix)
    }

    /// Init with custom promptSuffix.
    func testConfig_initWithPromptSuffix() {
        let config = ReviewAgentConfig(promptSuffix: "Additional guidance")
        XCTAssertEqual(config.promptSuffix, "Additional guidance")
    }

    /// Default config has promptSuffix == nil.
    func testConfig_defaultPromptSuffix_isNil() {
        XCTAssertNil(ReviewAgentConfig().promptSuffix)
    }
}

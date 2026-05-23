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
}

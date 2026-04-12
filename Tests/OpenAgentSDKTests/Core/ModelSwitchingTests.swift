import XCTest
@testable import OpenAgentSDK

// MARK: - AC1: Basic Model Switching

/// ATDD RED PHASE: Tests for Story 13.1 -- Runtime Dynamic Model Switching.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Agent` has `switchModel(_:)` method
///   - `Agent.model` is changed from `let` to `public private(set) var`
///   - `CostBreakdownEntry` type is defined
///   - `QueryResult` has `costBreakdown` field
///   - `SDKMessage.ResultData` has `costBreakdown` field
///   - `SDKError.invalidConfiguration` case is added
/// TDD Phase: RED (feature not implemented yet)
final class ModelSwitchBasicTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC1 [P0]: Given an Agent with model "claude-sonnet-4-6",
    /// when developer calls agent.switchModel("claude-opus-4-6"),
    /// then the method returns without error and agent.model is updated.
    func testSwitchModel_UpdatesAgentModelProperty() throws {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        XCTAssertEqual(sut.model, "claude-sonnet-4-6",
                       "Agent should start with the configured model")

        try sut.switchModel("claude-opus-4-6")

        XCTAssertEqual(sut.model, "claude-opus-4-6",
                       "After switchModel, agent.model should reflect the new model")
    }

    /// AC1 [P0]: After switchModel, subsequent prompt() calls send API requests
    /// with the updated model field.
    func testSwitchModel_SubsequentPromptUsesNewModel() async throws {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        // Switch model before any API call
        try sut.switchModel("claude-opus-4-6")

        // Register a mock response for the API endpoint
        let responseDict = makeAgentLoopResponse(
            model: "claude-opus-4-6",
            content: [["type": "text", "text": "Response from Opus"]],
            stopReason: "end_turn",
            inputTokens: 50,
            outputTokens: 100
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Test prompt")

        // Verify the API request used the new model
        let requestBody = AgentLoopMockURLProtocol.lastRequest?.httpBody
        XCTAssertNotNil(requestBody, "API request should have a body")

        if let body = requestBody,
           let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any] {
            let requestModel = json["model"] as? String
            XCTAssertEqual(requestModel, "claude-opus-4-6",
                           "API request model field should be the switched model")
        }

        // Verify the result came back successfully
        XCTAssertEqual(result.text, "Response from Opus")
    }

    /// AC1 [P1]: switchModel also updates internal options.model
    /// so that buildSystemPrompt and other methods see the new model.
    func testSwitchModel_UpdatesInternalOptionsModel() throws {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        try sut.switchModel("claude-haiku-4-5")

        // The public model property should reflect the change
        XCTAssertEqual(sut.model, "claude-haiku-4-5",
                       "After switchModel, the public model property should be updated")
    }
}

// MARK: - AC2: Multi-Model Cost Breakdown

final class ModelSwitchCostBreakdownTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC2 [P0]: When model is switched between two prompt() calls,
    /// the second QueryResult's costBreakdown contains entries for both models.
    func testCostBreakdown_ContainsEntriesAfterModelSwitch() async throws {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        // First prompt with sonnet
        let sonnetResponse = makeAgentLoopResponse(
            id: "msg_sonnet",
            model: "claude-sonnet-4-6",
            content: [["type": "text", "text": "Sonnet response"]],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: sonnetResponse))

        let result1 = await sut.prompt("First query")
        XCTAssertEqual(result1.text, "Sonnet response")

        // Switch to opus
        try sut.switchModel("claude-opus-4-6")

        // Second prompt with opus
        AgentLoopMockURLProtocol.reset()
        let opusResponse = makeAgentLoopResponse(
            id: "msg_opus",
            model: "claude-opus-4-6",
            content: [["type": "text", "text": "Opus response"]],
            stopReason: "end_turn",
            inputTokens: 2000,
            outputTokens: 800
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: opusResponse))

        let result2 = await sut.prompt("Second query")

        // Verify costBreakdown exists on the result
        // costBreakdown should track per-model costs within this single prompt() call
        // Since the second prompt only uses opus, its costBreakdown should have 1 entry
        XCTAssertFalse(result2.costBreakdown.isEmpty,
                       "costBreakdown should not be empty after a prompt call")

        // The opus entry should exist
        let opusEntry = result2.costBreakdown.first { $0.model.contains("opus") }
        XCTAssertNotNil(opusEntry, "costBreakdown should contain an entry for the opus model")
        XCTAssertEqual(opusEntry!.inputTokens, 2000)
        XCTAssertEqual(opusEntry!.outputTokens, 800)
    }

    /// AC2 [P0]: CostBreakdownEntry has the expected fields: model, inputTokens, outputTokens, costUsd.
    func testCostBreakdownEntry_HasCorrectFields() {
        let entry = CostBreakdownEntry(
            model: "claude-sonnet-4-6",
            inputTokens: 1000,
            outputTokens: 500,
            costUsd: 0.0105
        )

        XCTAssertEqual(entry.model, "claude-sonnet-4-6")
        XCTAssertEqual(entry.inputTokens, 1000)
        XCTAssertEqual(entry.outputTokens, 500)
        XCTAssertEqual(entry.costUsd, 0.0105, accuracy: 0.0001)
    }

    /// AC2 [P1]: CostBreakdownEntry is Equatable for test comparisons.
    func testCostBreakdownEntry_IsEquatable() {
        let entry1 = CostBreakdownEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50, costUsd: 0.001)
        let entry2 = CostBreakdownEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50, costUsd: 0.001)
        let entry3 = CostBreakdownEntry(model: "claude-opus-4-6", inputTokens: 100, outputTokens: 50, costUsd: 0.001)

        XCTAssertEqual(entry1, entry2, "Identical entries should be equal")
        XCTAssertNotEqual(entry1, entry3, "Entries with different models should not be equal")
    }

    /// AC2 [P1]: A single-model prompt produces a costBreakdown with one entry,
    /// and the totalCostUsd equals that entry's costUsd.
    func testCostBreakdown_SingleModelCostMatchesTotal() async throws {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Single model"]],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Single model query")

        // costBreakdown should have exactly one entry
        XCTAssertEqual(result.costBreakdown.count, 1,
                       "Single-model prompt should have exactly one costBreakdown entry")

        let entry = result.costBreakdown[0]
        let expectedCost = estimateCost(
            model: "claude-sonnet-4-6",
            usage: TokenUsage(inputTokens: 1000, outputTokens: 500)
        )

        XCTAssertEqual(entry.costUsd, expectedCost, accuracy: 0.0001,
                       "CostBreakdownEntry costUsd should match estimateCost calculation")
        XCTAssertEqual(result.totalCostUsd, expectedCost, accuracy: 0.0001,
                       "totalCostUsd should match the single entry's costUsd")
    }

    /// AC2 [P2]: QueryResult.costBreakdown defaults to empty array when not populated.
    func testCostBreakdown_DefaultsToEmptyArray() {
        let result = QueryResult(
            text: "test",
            usage: TokenUsage(inputTokens: 0, outputTokens: 0),
            numTurns: 0,
            durationMs: 0,
            messages: [],
            status: .success
        )

        XCTAssertTrue(result.costBreakdown.isEmpty,
                      "QueryResult.costBreakdown should default to an empty array")
    }
}

// MARK: - AC3: Empty Model Name Rejection

final class ModelSwitchEmptyNameTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC3 [P0]: Calling switchModel("") throws SDKError.invalidConfiguration.
    func testSwitchModel_EmptyString_ThrowsInvalidConfiguration() {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        XCTAssertThrowsError(try sut.switchModel("")) { error in
            guard let sdkError = error as? SDKError else {
                XCTFail("Expected SDKError, got \(type(of: error))")
                return
            }

            // Verify it is the invalidConfiguration case
            if case .invalidConfiguration(let message) = sdkError {
                XCTAssertTrue(message.lowercased().contains("empty"),
                              "Error message should mention 'empty': \(message)")
            } else {
                XCTFail("Expected .invalidConfiguration case, got \(sdkError)")
            }
        }
    }

    /// AC3 [P0]: After a failed switchModel(""), the agent's model is unchanged.
    func testSwitchModel_EmptyString_DoesNotChangeModel() {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        XCTAssertThrowsError(try sut.switchModel(""))

        XCTAssertEqual(sut.model, "claude-sonnet-4-6",
                       "Agent model should remain unchanged after failed switchModel")
    }

    /// AC3 [P1]: switchModel with whitespace-only string should also be rejected.
    func testSwitchModel_WhitespaceOnly_ThrowsInvalidConfiguration() {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        XCTAssertThrowsError(try sut.switchModel("   ")) { error in
            guard let sdkError = error as? SDKError else {
                XCTFail("Expected SDKError, got \(type(of: error))")
                return
            }

            if case .invalidConfiguration = sdkError {
                // Expected
            } else {
                XCTFail("Expected .invalidConfiguration case, got \(sdkError)")
            }
        }

        XCTAssertEqual(sut.model, "claude-sonnet-4-6",
                       "Agent model should remain unchanged after whitespace-only switchModel")
    }
}

// MARK: - AC4: Unknown Model Name Allowed

final class ModelSwitchUnknownModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC4 [P0]: Calling switchModel with an unknown (but non-empty) model name succeeds.
    func testSwitchModel_UnknownModel_Succeeds() throws {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        XCTAssertNoThrow(try sut.switchModel("future-model-v99"),
                         "switchModel with an unknown model name should not throw")

        XCTAssertEqual(sut.model, "future-model-v99",
                       "Agent model should be updated to the unknown model name")
    }

    /// AC4 [P0]: After switching to an unknown model, prompt() sends the unknown
    /// model name in the API request (no whitelist filtering).
    func testSwitchModel_UnknownModel_ApiRequestUsesUnknownModel() async throws {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        try sut.switchModel("some-new-model-name")

        let responseDict = makeAgentLoopResponse(
            model: "some-new-model-name",
            content: [["type": "text", "text": "Response"]],
            stopReason: "end_turn",
            inputTokens: 50,
            outputTokens: 50
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        _ = await sut.prompt("Test unknown model")

        let requestBody = AgentLoopMockURLProtocol.lastRequest?.httpBody
        XCTAssertNotNil(requestBody, "API request should have a body")

        if let body = requestBody,
           let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any] {
            let requestModel = json["model"] as? String
            XCTAssertEqual(requestModel, "some-new-model-name",
                           "API request should use the unknown model name without whitelist filtering")
        }
    }

    /// AC4 [P1]: Switching back to a known model after using an unknown model works.
    func testSwitchModel_SwitchBackToKnownModel() throws {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        try sut.switchModel("future-model-v99")
        XCTAssertEqual(sut.model, "future-model-v99")

        try sut.switchModel("claude-opus-4-6")
        XCTAssertEqual(sut.model, "claude-opus-4-6",
                       "Should be able to switch back to a known model")
    }

    /// AC4 [P1]: Multiple rapid model switches are all applied correctly.
    func testSwitchModel_MultipleSwitches() throws {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")

        try sut.switchModel("claude-opus-4-6")
        XCTAssertEqual(sut.model, "claude-opus-4-6")

        try sut.switchModel("claude-haiku-4-5")
        XCTAssertEqual(sut.model, "claude-haiku-4-5")

        try sut.switchModel("claude-sonnet-4-6")
        XCTAssertEqual(sut.model, "claude-sonnet-4-6",
                       "Should be able to cycle through models multiple times")
    }
}

// MARK: - SDKError.invalidConfiguration Existence

/// Tests that verify the SDKError.invalidConfiguration case exists.
/// This case is needed by AC3 for rejecting empty model names.
final class SDKErrorInvalidConfigurationTests: XCTestCase {

    /// The .invalidConfiguration case should exist on SDKError.
    func testSDKError_InvalidConfiguration_Exists() {
        let error = SDKError.invalidConfiguration("Test configuration error")

        if case .invalidConfiguration(let message) = error {
            XCTAssertEqual(message, "Test configuration error")
        } else {
            XCTFail("SDKError.invalidConfiguration case should exist and carry a String message")
        }
    }

    /// .invalidConfiguration should be equatable.
    func testSDKError_InvalidConfiguration_IsEquatable() {
        let error1 = SDKError.invalidConfiguration("msg1")
        let error2 = SDKError.invalidConfiguration("msg1")
        let error3 = SDKError.invalidConfiguration("msg2")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
}

// MARK: - CostBreakdownEntry Type Existence

/// Tests verifying that CostBreakdownEntry type exists with the expected shape.
final class CostBreakdownEntryTypeTests: XCTestCase {

    /// CostBreakdownEntry should be initializable with model, inputTokens, outputTokens, costUsd.
    func testCostBreakdownEntry_CanBeInitialized() {
        let entry = CostBreakdownEntry(
            model: "claude-sonnet-4-6",
            inputTokens: 100,
            outputTokens: 50,
            costUsd: 0.00105
        )

        XCTAssertEqual(entry.model, "claude-sonnet-4-6")
        XCTAssertEqual(entry.inputTokens, 100)
        XCTAssertEqual(entry.outputTokens, 50)
        XCTAssertEqual(entry.costUsd, 0.00105, accuracy: 0.00001)
    }

    /// CostBreakdownEntry should conform to Sendable.
    func testCostBreakdownEntry_IsSendable() {
        // This is a compile-time check. If CostBreakdownEntry is not Sendable,
        // this function won't compile.
        let entry = CostBreakdownEntry(model: "test", inputTokens: 0, outputTokens: 0, costUsd: 0.0)
        let _: any Sendable = entry
    }

    /// CostBreakdownEntry should conform to Equatable.
    func testCostBreakdownEntry_ConformsToEquatable() {
        let a = CostBreakdownEntry(model: "m", inputTokens: 1, outputTokens: 2, costUsd: 3.0)
        let b = CostBreakdownEntry(model: "m", inputTokens: 1, outputTokens: 2, costUsd: 3.0)
        XCTAssertEqual(a, b, "CostBreakdownEntry should conform to Equatable")
    }
}

// MARK: - QueryResult.costBreakdown Field

/// Tests verifying that QueryResult has a costBreakdown field.
final class QueryResultCostBreakdownTests: XCTestCase {

    /// QueryResult should accept costBreakdown in its initializer.
    func testQueryResult_AcceptsCostBreakdown() {
        let breakdown = [
            CostBreakdownEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50, costUsd: 0.001),
            CostBreakdownEntry(model: "claude-opus-4-6", inputTokens: 200, outputTokens: 80, costUsd: 0.01)
        ]

        let result = QueryResult(
            text: "test",
            usage: TokenUsage(inputTokens: 300, outputTokens: 130),
            numTurns: 2,
            durationMs: 100,
            messages: [],
            status: .success,
            totalCostUsd: 0.011,
            costBreakdown: breakdown
        )

        XCTAssertEqual(result.costBreakdown.count, 2)
        XCTAssertEqual(result.costBreakdown[0].model, "claude-sonnet-4-6")
        XCTAssertEqual(result.costBreakdown[1].model, "claude-opus-4-6")
    }
}

// MARK: - SDKMessage.ResultData.costBreakdown Field

/// Tests verifying that SDKMessage.ResultData has a costBreakdown field for streaming.
final class ResultDataCostBreakdownTests: XCTestCase {

    /// ResultData should accept costBreakdown in its initializer.
    func testResultData_AcceptsCostBreakdown() {
        let breakdown = [
            CostBreakdownEntry(model: "claude-sonnet-4-6", inputTokens: 100, outputTokens: 50, costUsd: 0.001)
        ]

        let resultData = SDKMessage.ResultData(
            subtype: .success,
            text: "stream result",
            usage: TokenUsage(inputTokens: 100, outputTokens: 50),
            numTurns: 1,
            durationMs: 50,
            totalCostUsd: 0.001,
            costBreakdown: breakdown
        )

        XCTAssertEqual(resultData.costBreakdown.count, 1)
        XCTAssertEqual(resultData.costBreakdown[0].model, "claude-sonnet-4-6")
    }

    /// ResultData costBreakdown defaults to empty when not provided.
    func testResultData_CostBreakdown_DefaultsToEmpty() {
        let resultData = SDKMessage.ResultData(
            subtype: .success,
            text: "stream result",
            usage: TokenUsage(inputTokens: 0, outputTokens: 0),
            numTurns: 1,
            durationMs: 50
        )

        XCTAssertTrue(resultData.costBreakdown.isEmpty,
                      "ResultData.costBreakdown should default to empty array")
    }
}

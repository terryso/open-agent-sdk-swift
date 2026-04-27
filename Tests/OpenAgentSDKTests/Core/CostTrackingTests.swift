import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import OpenAgentSDK

// MARK: - AC2: QueryResult Contains Cost Information

/// ATDD RED PHASE: Tests for Story 2.2 -- Cost Tracking in QueryResult (blocking path).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `QueryResult` has `totalCostUsd: Double` field
///   - `Agent.prompt()` accumulates cost via `estimateCost()` per turn
/// TDD Phase: RED (feature not implemented yet)
final class QueryResultCostTrackingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC2 [P0]: Given a completed blocking agent call, when the developer checks QueryResult,
    /// then totalCostUsd is available and greater than zero for non-zero token usage.
    func testQueryResult_ContainsTotalCostUsd_AfterPrompt() async throws {
        let sut = makeAgentLoopSUT()
        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Hello"]],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Test cost tracking")

        // QueryResult should expose totalCostUsd
        // Expected: 1000 * (3.0 / 1_000_000) + 500 * (15.0 / 1_000_000) = 0.003 + 0.0075 = 0.0105
        XCTAssertGreaterThan(result.totalCostUsd, 0.0,
                             "QueryResult.totalCostUsd should be > 0 for non-zero token usage")
    }

    /// AC2 [P0]: Given a completed blocking agent call with known tokens,
    /// when the developer checks totalCostUsd, it matches the expected calculated cost.
    func testQueryResult_TotalCostUsd_MatchesExpectedCalculation() async throws {
        let sut = makeAgentLoopSUT(model: "claude-sonnet-4-6")
        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Test"]],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Calculate my cost")

        let expectedCost = estimateCost(
            model: "claude-sonnet-4-6",
            usage: TokenUsage(inputTokens: 1000, outputTokens: 500)
        )
        XCTAssertEqual(result.totalCostUsd, expectedCost, accuracy: 0.0001,
                       "totalCostUsd should match estimateCost for the token usage")
    }

    /// AC2 [P1]: Given a multi-turn blocking agent call,
    /// when the developer checks totalCostUsd, it reflects accumulated cost across all turns.
    func testQueryResult_MultiTurn_CostAccumulates() async throws {
        let sut = makeAgentLoopSUT(maxTurns: 5)
        let responses = [
            makeAgentLoopResponse(id: "msg_turn1", stopReason: "max_tokens",
                                   inputTokens: 1000, outputTokens: 500),
            makeAgentLoopResponse(id: "msg_turn2", stopReason: "end_turn",
                                   inputTokens: 2000, outputTokens: 1000),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        let result = await sut.prompt("Multi-turn cost test")

        // Total usage: input 3000, output 1500
        // Cost: (3000 * 3.0 + 1500 * 15.0) / 1_000_000 = (9000 + 22500) / 1_000_000 = 0.0315
        let expectedCost = estimateCost(
            model: "claude-sonnet-4-6",
            usage: TokenUsage(inputTokens: 3000, outputTokens: 1500)
        )
        XCTAssertEqual(result.totalCostUsd, expectedCost, accuracy: 0.0001,
                       "Multi-turn totalCostUsd should accumulate cost across all turns")
    }

    /// AC2 [P1]: Given an API error during prompt(),
    /// when the developer checks QueryResult, totalCostUsd reflects the cost accumulated before the error.
    func testQueryResult_ErrorPath_CostReflectsPartialUsage() async throws {
        let sut = makeAgentLoopSUT()
        let errorBody: [String: Any] = [
            "error": [
                "type": "api_error",
                "message": "Internal server error"
            ]
        ]
        registerAgentLoopMockResponse(
            statusCode: 500,
            body: loopJsonData(from: errorBody)
        )

        let result = await sut.prompt("Trigger error")

        // Error path should still have totalCostUsd (even if 0 for API errors)
        XCTAssertGreaterThanOrEqual(result.totalCostUsd, 0.0,
                                     "Error path QueryResult should have non-negative totalCostUsd")
    }
}

// MARK: - AC3: SDKMessage.ResultData Contains Cost Information (Stream Path)

/// ATDD RED PHASE: Tests for Story 2.2 -- Cost Tracking in SDKMessage.ResultData (stream path).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `SDKMessage.ResultData` has `totalCostUsd: Double` field
///   - `Agent.stream()` accumulates cost via `estimateCost()` per turn
/// TDD Phase: RED (feature not implemented yet)
final class StreamCostTrackingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StreamMockURLProtocol.reset()
    }

    override func tearDown() {
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC3 [P0]: Given a completed stream, when the developer checks the final .result event,
    /// ResultData contains totalCostUsd greater than zero for non-zero token usage.
    func testStreamResult_ContainsTotalCostUsd_AfterStream() async throws {
        let sut = makeStreamSUT()
        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Hello world"],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Test cost tracking")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent, "Should receive a .result event")
        XCTAssertGreaterThan(resultEvent?.totalCostUsd ?? -1, 0.0,
                             "ResultData.totalCostUsd should be > 0 for non-zero token usage")
    }

    /// AC3 [P0]: Given a completed stream with known tokens,
    /// when the developer checks ResultData.totalCostUsd, it matches the expected cost.
    func testStreamResult_TotalCostUsd_MatchesExpected() async throws {
        let sut = makeStreamSUT(model: "claude-sonnet-4-6")
        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Response text"],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Calculate streaming cost")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent, "Should receive a .result event")
        let expectedCost = estimateCost(
            model: "claude-sonnet-4-6",
            usage: TokenUsage(inputTokens: 1000, outputTokens: 500)
        )
        XCTAssertEqual(resultEvent?.totalCostUsd ?? -1, expectedCost, accuracy: 0.0001,
                       "ResultData.totalCostUsd should match estimateCost for the token usage")
    }

    /// AC3 [P1]: Given a multi-turn stream, when the stream completes,
    /// ResultData.totalCostUsd reflects accumulated cost across all turns.
    func testStreamResult_MultiTurn_CostAccumulates() async throws {
        let sut = makeStreamSUT(maxTurns: 5)

        let sseTurn1 = makeSingleTurnSSEBody(
            textDeltas: ["First turn"],
            stopReason: "max_tokens",
            inputTokens: 1000,
            outputTokens: 500
        )
        let sseTurn2 = makeSingleTurnSSEBody(
            textDeltas: ["Second turn"],
            stopReason: "end_turn",
            inputTokens: 2000,
            outputTokens: 1000
        )

        registerSequentialStreamMockResponses([sseTurn1, sseTurn2])

        let stream = sut.stream("Multi-turn cost test")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent, "Should receive a .result event")
        // Total usage: input 3000, output 1500
        let expectedCost = estimateCost(
            model: "claude-sonnet-4-6",
            usage: TokenUsage(inputTokens: 3000, outputTokens: 1500)
        )
        XCTAssertEqual(resultEvent?.totalCostUsd ?? -1, expectedCost, accuracy: 0.0001,
                       "Multi-turn stream totalCostUsd should accumulate cost across all turns")
    }

    /// AC3 [P1]: Given an error during streaming,
    /// when the stream yields the error .result event, ResultData.totalCostUsd reflects partial cost.
    func testStreamResult_ErrorPath_CostReflectsPartialUsage() async throws {
        let sut = makeStreamSUT()
        let errorBody: [String: Any] = [
            "error": [
                "type": "api_error",
                "message": "Internal server error"
            ]
        ]
        registerStreamMockResponse(
            statusCode: 500,
            body: try! JSONSerialization.data(withJSONObject: errorBody, options: [])
        )

        let stream = sut.stream("Trigger error")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent, "Should receive a .result event even on error")
        XCTAssertGreaterThanOrEqual(resultEvent?.totalCostUsd ?? -1, 0.0,
                                     "Error path ResultData should have non-negative totalCostUsd")
    }
}

// MARK: - AC4: Multi-Model Differential Pricing in prompt() and stream()

final class CostTrackingMultiModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC4 [P0]: Given an Agent using claude-opus-4-6 with known token usage,
    /// when prompt() returns, totalCostUsd reflects opus pricing (not sonnet pricing).
    func testPrompt_OpusModel_UsesOpusPricing() async throws {
        let sut = makeAgentLoopSUT(model: "claude-opus-4-6")
        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Opus response"]],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Test opus pricing")

        let expectedOpusCost = estimateCost(
            model: "claude-opus-4-6",
            usage: TokenUsage(inputTokens: 1000, outputTokens: 500)
        )
        // Opus pricing: input 15.0/M, output 75.0/M
        // expectedOpusCost = 0.015 + 0.0375 = 0.0525
        XCTAssertEqual(result.totalCostUsd, expectedOpusCost, accuracy: 0.0001,
                       "Opus model cost should use opus pricing")
    }

    /// AC4 [P1]: Given an Agent using claude-haiku-4-5 with known token usage,
    /// when prompt() returns, totalCostUsd reflects haiku pricing (cheaper).
    func testPrompt_HaikuModel_UsesHaikuPricing() async throws {
        let sut = makeAgentLoopSUT(model: "claude-haiku-4-5")
        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Haiku response"]],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Test haiku pricing")

        let expectedHaikuCost = estimateCost(
            model: "claude-haiku-4-5",
            usage: TokenUsage(inputTokens: 1000, outputTokens: 500)
        )
        // Haiku pricing: input 0.8/M, output 4.0/M
        // expectedHaikuCost = 0.0008 + 0.002 = 0.0028
        XCTAssertEqual(result.totalCostUsd, expectedHaikuCost, accuracy: 0.0001,
                       "Haiku model cost should use haiku pricing")
    }
}

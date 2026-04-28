import XCTest
@testable import OpenAgentSDK

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
// MARK: - AC1 & AC4: Budget Enforcement in Blocking Path (prompt())

/// ATDD RED PHASE: Tests for Story 2.3 — Budget Enforcement in prompt() (blocking path).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `QueryStatus` has `.errorMaxBudgetUsd` case
///   - `Agent.prompt()` checks `options.maxBudgetUsd` after cost accumulation
///   - Budget exceeded stops the loop with graceful error result
/// TDD Phase: RED (feature not implemented yet)
final class BudgetEnforcementPromptTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - SUT Factory

    /// Creates an Agent with budget enforcement configured for blocking path testing.
    func makeBudgetPromptSUT(
        model: String = "claude-sonnet-4-6",
        maxBudgetUsd: Double? = nil,
        maxTurns: Int = 10
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [AgentLoopMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        let client = AnthropicClient(apiKey: "sk-test-budget-key", baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: "sk-test-budget-key",
            model: model,
            maxTurns: maxTurns,
            maxTokens: 4096,
            maxBudgetUsd: maxBudgetUsd,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529])
        )

        return Agent(options: options, client: client)
    }

    // MARK: - AC1: Budget exceeded stops the loop immediately

    /// AC1 [P0]: Given an Agent with maxBudgetUsd=0.001, when cost exceeds the budget
    /// in the first turn, the loop stops immediately and returns an error result.
    func testPrompt_BudgetExceeded_StopsLoop() async throws {
        let sut = makeBudgetPromptSUT(maxBudgetUsd: 0.001, maxTurns: 5)

        // Register 3 turns but budget will be exceeded after turn 1
        // Turn 1: input 1000, output 500 → cost = 0.003 + 0.0075 = 0.0105 >> 0.001
        let responses = [
            makeAgentLoopResponse(id: "msg_1", stopReason: "max_tokens",
                                   inputTokens: 1000, outputTokens: 500),
            makeAgentLoopResponse(id: "msg_2", stopReason: "end_turn",
                                   inputTokens: 500, outputTokens: 200),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        let result = await sut.prompt("Exceed my budget")

        // Loop should have stopped after turn 1 — not continued to turn 2
        XCTAssertEqual(result.numTurns, 1,
                       "Loop should stop immediately after budget exceeded, not continue to turn 2")
    }

    /// AC1 [P0]: Budget exceeded returns a graceful error result — does NOT crash.
    func testPrompt_BudgetExceeded_ReturnsGracefulError() async throws {
        let sut = makeBudgetPromptSUT(maxBudgetUsd: 0.001)

        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Partial response"]],
            stopReason: "max_tokens",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Trigger budget error")

        // Should return a valid result, not crash
        XCTAssertFalse(result.text.isEmpty,
                       "Should preserve partial text accumulated before budget exceeded")
        XCTAssertGreaterThan(result.totalCostUsd, 0.0,
                              "Should report the cost that exceeded the budget")
    }

    /// AC1 [P0]: Budget exceeded does not crash (smoke test with very low budget).
    func testPrompt_BudgetExceeded_DoesNotCrash() async throws {
        let sut = makeBudgetPromptSUT(maxBudgetUsd: 0.0001)

        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Quick"]],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        // Must not throw or crash
        let result = await sut.prompt("Tiny budget test")
        XCTAssertNotNil(result, "Should return a valid result without crashing")
    }

    // MARK: - AC4: QueryResult contains correct status and cost

    /// AC4 [P0]: Given budget exceeded, QueryResult.status == .errorMaxBudgetUsd.
    func testPrompt_BudgetExceeded_CorrectStatusAndCost() async throws {
        let sut = makeBudgetPromptSUT(maxBudgetUsd: 0.005, maxTurns: 3)

        // Turn 1: cost = 1000 * 3.0/M + 500 * 15.0/M = 0.003 + 0.0075 = 0.0105 > 0.005
        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Over budget"]],
            stopReason: "max_tokens",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Over budget test")

        XCTAssertEqual(result.status, .errorMaxBudgetUsd,
                       "Status should be .errorMaxBudgetUsd when budget exceeded")
        XCTAssertGreaterThan(result.totalCostUsd, 0.005,
                              "totalCostUsd should exceed the configured budget")
    }

    // MARK: - AC3: No budget configured — no check

    /// AC3 [P0]: Given no budget (maxBudgetUsd: nil), agent runs normally without budget check.
    func testPrompt_NoBudget_NoCheck() async throws {
        let sut = makeBudgetPromptSUT(maxBudgetUsd: nil, maxTurns: 3)

        let responses = [
            makeAgentLoopResponse(id: "msg_1", stopReason: "max_tokens",
                                   inputTokens: 1000, outputTokens: 500),
            makeAgentLoopResponse(id: "msg_2", stopReason: "end_turn",
                                   inputTokens: 2000, outputTokens: 1000),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        let result = await sut.prompt("No budget limit")

        // Should complete both turns normally
        XCTAssertEqual(result.numTurns, 2,
                       "Without budget, agent should complete all turns normally")
        XCTAssertEqual(result.status, .success,
                       "Without budget, status should be .success")
        // Cost should still be tracked
        XCTAssertGreaterThan(result.totalCostUsd, 0.0,
                              "Cost should still be tracked even without budget enforcement")
    }

    // MARK: - AC6: Budget check timing

    /// AC6 [P1]: Budget check happens after cost accumulation, not before the next turn.
    /// Multi-turn scenario: turn 1 under budget, turn 2 over budget.
    func testPrompt_BudgetCheck_AfterCostAccumulation() async throws {
        let sut = makeBudgetPromptSUT(maxBudgetUsd: 0.010, maxTurns: 5)

        // Turn 1: 500 input + 200 output → cost = 0.0015 + 0.003 = 0.0045 < 0.010 ✓
        // Turn 2: 1000 input + 500 output → cost = 0.003 + 0.0075 = 0.0105
        //   cumulative = 0.0045 + 0.0105 = 0.015 > 0.010 → exceeded!
        let responses = [
            makeAgentLoopResponse(id: "msg_1", stopReason: "max_tokens",
                                   inputTokens: 500, outputTokens: 200),
            makeAgentLoopResponse(id: "msg_2", stopReason: "end_turn",
                                   inputTokens: 1000, outputTokens: 500),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        let result = await sut.prompt("Multi-turn budget test")

        // Turn 1: 0.0045 < 0.010 → continue
        // Turn 2: 0.0045 + 0.0105 = 0.015 > 0.010 → exceeded, break
        XCTAssertEqual(result.numTurns, 2,
                       "Budget should be checked after turn 2 cost accumulation")
        XCTAssertEqual(result.status, .errorMaxBudgetUsd,
                       "Status should be .errorMaxBudgetUsd after cumulative cost exceeds budget")
    }
}

// MARK: - AC2 & AC5: Budget Enforcement in Streaming Path (stream())

/// ATDD RED PHASE: Tests for Story 2.3 — Budget Enforcement in stream() (streaming path).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Agent.stream()` checks `options.maxBudgetUsd` after cost accumulation
///   - Budget exceeded yields `.result(subtype: .errorMaxBudgetUsd)` and terminates
/// TDD Phase: RED (feature not implemented yet)
final class BudgetEnforcementStreamTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StreamMockURLProtocol.reset()
    }

    override func tearDown() {
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - SUT Factory

    /// Creates an Agent with budget enforcement configured for stream testing.
    func makeBudgetStreamSUT(
        model: String = "claude-sonnet-4-6",
        maxBudgetUsd: Double? = nil,
        maxTurns: Int = 10
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StreamMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        let client = AnthropicClient(apiKey: "sk-test-budget-stream", baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: "sk-test-budget-stream",
            model: model,
            maxTurns: maxTurns,
            maxTokens: 4096,
            maxBudgetUsd: maxBudgetUsd,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529])
        )

        return Agent(options: options, client: client)
    }

    // MARK: - AC2: Budget exceeded stops the stream

    /// AC2 [P0]: Given an Agent with maxBudgetUsd=0.001, when streaming cost exceeds the budget,
    /// the stream stops and yields a .result event with .errorMaxBudgetUsd subtype.
    func testStream_BudgetExceeded_StopsStream() async throws {
        let sut = makeBudgetStreamSUT(maxBudgetUsd: 0.001, maxTurns: 5)

        // Use low inputTokens so budget check triggers in messageDelta (output tokens), not messageStart (input tokens).
        // input 10 → cost_input = 10 * 3e-6 = 0.00003 < 0.001 (no trigger at messageStart)
        // output 500 → cost_output = 500 * 15e-6 = 0.0075, cumulative = 0.00753 > 0.001 (trigger at messageDelta)
        let sseTurn1 = makeSingleTurnSSEBody(
            textDeltas: ["Over budget"],
            stopReason: "max_tokens",
            inputTokens: 10,
            outputTokens: 500
        )
        // Turn 2 should NOT be reached
        let sseTurn2 = makeSingleTurnSSEBody(
            textDeltas: ["Should not see this"],
            stopReason: "end_turn",
            inputTokens: 500,
            outputTokens: 200
        )

        registerSequentialStreamMockResponses([sseTurn1, sseTurn2])

        let stream = sut.stream("Exceed budget in stream")

        var resultEvent: SDKMessage.ResultData?
        var partialCount = 0
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
            if case .partialMessage = message {
                partialCount += 1
            }
        }

        // Stream should have stopped — partial text was delivered but turn didn't complete
        XCTAssertGreaterThan(partialCount, 0,
                             "Should have received partial messages before budget check")
        XCTAssertNotNil(resultEvent,
                         "Should yield a .result event when budget exceeded")
        XCTAssertEqual(resultEvent?.subtype, .errorMaxBudgetUsd,
                       "Result subtype should be .errorMaxBudgetUsd")
    }

    /// AC2 [P0]: Budget exceeded yields .errorMaxBudgetUsd result subtype.
    func testStream_BudgetExceeded_ReturnsCorrectSubtype() async throws {
        let sut = makeBudgetStreamSUT(maxBudgetUsd: 0.001)

        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Budget test"],
            stopReason: "max_tokens",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Test stream budget")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent, "Should yield a .result event")
        XCTAssertEqual(resultEvent?.subtype, .errorMaxBudgetUsd,
                       "Result subtype should be .errorMaxBudgetUsd when budget exceeded")
    }

    // MARK: - AC5: Stream result contains correct subtype and cost

    /// AC5 [P0]: Budget exceeded result contains correct totalCostUsd and numTurns.
    func testStream_BudgetExceeded_CorrectSubtypeAndCost() async throws {
        let sut = makeBudgetStreamSUT(maxBudgetUsd: 0.005, maxTurns: 5)

        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Expensive response"],
            stopReason: "max_tokens",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Costly stream")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent, "Should yield a .result event")
        XCTAssertEqual(resultEvent?.subtype, .errorMaxBudgetUsd,
                       "Subtype should be .errorMaxBudgetUsd")
        XCTAssertEqual(resultEvent?.numTurns, 1,
                       "Should report 1 turn when budget exceeded in first turn")
        XCTAssertGreaterThan(resultEvent?.totalCostUsd ?? 0, 0.005,
                              "totalCostUsd should exceed the configured budget")
    }

    // MARK: - AC3: No budget configured — no check (streaming)

    /// AC3 [P0]: Given no budget in stream path, agent runs normally without budget check.
    func testStream_NoBudget_NoCheck() async throws {
        let sut = makeBudgetStreamSUT(maxBudgetUsd: nil, maxTurns: 3)

        let sseTurn1 = makeSingleTurnSSEBody(
            textDeltas: ["First"],
            stopReason: "max_tokens",
            inputTokens: 1000,
            outputTokens: 500
        )
        let sseTurn2 = makeSingleTurnSSEBody(
            textDeltas: ["Second"],
            stopReason: "end_turn",
            inputTokens: 2000,
            outputTokens: 1000
        )

        registerSequentialStreamMockResponses([sseTurn1, sseTurn2])

        let stream = sut.stream("No budget stream test")

        var resultEvent: SDKMessage.ResultData?
        var assistantCount = 0
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
            if case .assistant = message {
                assistantCount += 1
            }
        }

        // Should complete both turns normally
        XCTAssertEqual(assistantCount, 2,
                       "Without budget, stream should complete all turns")
        XCTAssertNotNil(resultEvent)
        XCTAssertEqual(resultEvent?.subtype, .success,
                       "Without budget, result should be .success")
        XCTAssertGreaterThan(resultEvent?.totalCostUsd ?? 0, 0.0,
                              "Cost should still be tracked without budget enforcement")
    }

    // MARK: - AC6: Budget check timing (streaming)

    /// AC6 [P1]: Multi-turn stream — budget exceeded after second turn's cost accumulation.
    func testStream_BudgetCheck_AfterCostAccumulation() async throws {
        // Budget = 0.010
        // Turn 1: 500 input + 200 output → cost = 0.0045 < 0.010 ✓
        // Turn 2: 1000 input + 500 output → cost = 0.0105
        //   cumulative = 0.0045 + 0.0105 = 0.015 > 0.010 → exceeded!
        let sut = makeBudgetStreamSUT(maxBudgetUsd: 0.010, maxTurns: 5)

        let sseTurn1 = makeSingleTurnSSEBody(
            textDeltas: ["Cheap turn"],
            stopReason: "max_tokens",
            inputTokens: 500,
            outputTokens: 200
        )
        let sseTurn2 = makeSingleTurnSSEBody(
            textDeltas: ["Over budget"],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )

        registerSequentialStreamMockResponses([sseTurn1, sseTurn2])

        let stream = sut.stream("Multi-turn stream budget test")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent)
        XCTAssertEqual(resultEvent?.subtype, .errorMaxBudgetUsd,
                       "Should exceed budget after turn 2 cost accumulation")
        XCTAssertEqual(resultEvent?.numTurns, 2,
                       "Should report 2 turns when budget exceeded after second turn")
    }
}

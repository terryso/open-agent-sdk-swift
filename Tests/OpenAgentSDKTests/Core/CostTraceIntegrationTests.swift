import XCTest
@testable import OpenAgentSDK

// MARK: - Story 20.2 E2E Integration Tests: CostTracker + TraceRecorder Agent Loop Wiring

/// Integration tests that verify CostTracker and TraceRecorder are correctly wired
/// into the agent loop. Uses mock URL protocols to simulate API responses without
/// real network calls.
///
/// These tests complement the unit tests in:
/// - `Tests/OpenAgentSDKTests/Utils/CostTrackerTests.swift`
/// - `Tests/OpenAgentSDKTests/Utils/TraceRecorderTests.swift`
/// - `Tests/OpenAgentSDKTests/Utils/TraceEventMappingTests.swift`
final class TraceRecorderStreamIntegrationTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        StreamMockURLProtocol.reset()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TraceIntegration-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - SUT Factory

    func makeTraceStreamSUT(
        model: String = "claude-sonnet-4-6",
        traceEnabled: Bool = false,
        traceBaseURL: String? = nil,
        maxBudgetUsd: Double? = nil,
        maxTurns: Int = 10,
        runId: String? = nil
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StreamMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        let client = AnthropicClient(apiKey: "sk-test-trace-key", baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: "sk-test-trace-key",
            model: model,
            maxTurns: maxTurns,
            maxTokens: 4096,
            maxBudgetUsd: maxBudgetUsd,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529]),
            runId: runId,
            traceEnabled: traceEnabled,
            traceBaseURL: traceBaseURL
        )

        return Agent(options: options, client: client)
    }

    // MARK: - AC5: TraceRecorder creates trace file during stream()

    /// AC5 [P0]: Given traceEnabled=true, when agent.stream() completes, a trace.jsonl
    /// file exists in the traceBaseURL directory.
    func testStream_TraceEnabled_CreatesTraceFile() async throws {
        let runId = "trace-run-\(UUID().uuidString.prefix(8))"
        let traceDir = tempDir.appendingPathComponent(runId, isDirectory: true)
        let sut = makeTraceStreamSUT(traceEnabled: true, traceBaseURL: tempDir.path, runId: runId)

        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Hello"],
            stopReason: "end_turn",
            inputTokens: 100,
            outputTokens: 50
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Test trace creation")
        for await _ in stream {}

        let traceFile = traceDir.appendingPathComponent("trace.jsonl")
        let exists = FileManager.default.fileExists(atPath: traceFile.path)
        XCTAssertTrue(exists, "Trace file should exist at \(traceFile.path) when traceEnabled=true")
    }

    /// AC5 [P0]: Given traceEnabled=true, the trace.jsonl file contains a valid run_done event.
    func testStream_TraceEnabled_ContainsRunDoneEvent() async throws {
        let runId = "run-done-\(UUID().uuidString.prefix(8))"
        let traceDir = tempDir.appendingPathComponent(runId, isDirectory: true)
        let sut = makeTraceStreamSUT(traceEnabled: true, traceBaseURL: tempDir.path, runId: runId)

        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Done"],
            stopReason: "end_turn",
            inputTokens: 100,
            outputTokens: 50
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Test run_done trace event")
        for await _ in stream {}

        let traceFile = traceDir.appendingPathComponent("trace.jsonl")
        let content = try String(contentsOf: traceFile, encoding: .utf8)
        XCTAssertFalse(content.isEmpty, "Trace file should not be empty")

        let lines = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        XCTAssertGreaterThanOrEqual(lines.count, 1, "Trace should have at least one event")

        // Find the run_done event
        var foundRunDone = false
        for line in lines {
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if json["event"] as? String == "run_done" {
                    foundRunDone = true
                    XCTAssertNotNil(json["ts"], "run_done should have timestamp")
                    XCTAssertEqual(json["status"] as? String, "success")
                    XCTAssertNotNil(json["totalCostUsd"])
                    XCTAssertNotNil(json["durationMs"])
                }
            }
        }
        XCTAssertTrue(foundRunDone, "Trace should contain a run_done event")
    }

    /// AC5 [P0]: Given traceEnabled=false (default), no trace file is created.
    func testStream_TraceDisabled_NoTraceFile() async throws {
        let sut = makeTraceStreamSUT(traceEnabled: false, traceBaseURL: tempDir.path)

        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["No trace"],
            stopReason: "end_turn",
            inputTokens: 50,
            outputTokens: 20
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("No trace test")
        for await _ in stream {}

        // Check no new directories were created in tempDir
        let contents = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let traceFiles = contents?.filter { $0.lastPathComponent.hasSuffix("trace.jsonl") } ?? []
        XCTAssertTrue(traceFiles.isEmpty, "No trace file should be created when traceEnabled=false")
    }

    // MARK: - AC6: Custom traceBaseURL

    /// AC6 [P0]: Given a custom traceBaseURL, trace files are written to the specified directory.
    func testStream_CustomTraceBaseURL_WritesToCustomDir() async throws {
        let customDir = tempDir.appendingPathComponent("custom-traces", isDirectory: true)
        try? FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
        let runId = "custom-\(UUID().uuidString.prefix(8))"

        let sut = makeTraceStreamSUT(traceEnabled: true, traceBaseURL: customDir.path, runId: runId)

        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Custom dir"],
            stopReason: "end_turn",
            inputTokens: 50,
            outputTokens: 20
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Custom trace dir test")
        for await _ in stream {}

        let traceFile = customDir.appendingPathComponent("\(runId)/trace.jsonl")
        let exists = FileManager.default.fileExists(atPath: traceFile.path)
        XCTAssertTrue(exists, "Trace file should exist in custom traceBaseURL directory")
    }

    // MARK: - AC8: Multi-turn trace contains correct event sequence

    /// AC8 [P1]: Given a multi-turn stream, the trace file contains one run_done event
    /// with the correct totalSteps.
    func testStream_MultiTurn_TraceContainsRunDoneWithCorrectSteps() async throws {
        let runId = "multi-\(UUID().uuidString.prefix(8))"
        let traceDir = tempDir.appendingPathComponent(runId, isDirectory: true)
        let sut = makeTraceStreamSUT(traceEnabled: true, traceBaseURL: tempDir.path, maxTurns: 5, runId: runId)

        let sseTurn1 = makeSingleTurnSSEBody(
            textDeltas: ["Turn 1"],
            stopReason: "max_tokens",
            inputTokens: 500,
            outputTokens: 200
        )
        let sseTurn2 = makeSingleTurnSSEBody(
            textDeltas: ["Turn 2"],
            stopReason: "end_turn",
            inputTokens: 500,
            outputTokens: 200
        )
        registerSequentialStreamMockResponses([sseTurn1, sseTurn2])

        let stream = sut.stream("Multi-turn trace test")
        for await _ in stream {}

        let traceFile = traceDir.appendingPathComponent("trace.jsonl")
        let content = try String(contentsOf: traceFile, encoding: .utf8)
        let lines = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")

        // Should have exactly 1 run_done event at the end
        let runDoneEvents = lines.compactMap { line -> [String: Any]? in
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["event"] as? String == "run_done" else { return nil }
            return json
        }
        XCTAssertEqual(runDoneEvents.count, 1, "Should have exactly 1 run_done event")
        XCTAssertEqual(runDoneEvents[0]["totalSteps"] as? Int, 2, "run_done should report 2 total steps")
    }

    // MARK: - AC2: Budget exceeded with trace recording

    /// AC2 [P0]: Given budget exceeded during streaming, the trace still captures the run_done event.
    func testStream_BudgetExceeded_TraceRecordsRunDone() async throws {
        let runId = "budget-\(UUID().uuidString.prefix(8))"
        let traceDir = tempDir.appendingPathComponent(runId, isDirectory: true)
        let sut = makeTraceStreamSUT(
            traceEnabled: true,
            traceBaseURL: tempDir.path,
            maxBudgetUsd: 0.005,
            runId: runId
        )

        // Cost = 1000 * 3e-6 + 500 * 15e-6 = 0.003 + 0.0075 = 0.0105 > 0.005
        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Over budget"],
            stopReason: "max_tokens",
            inputTokens: 10,
            outputTokens: 500
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Budget exceeded trace test")
        for await _ in stream {}

        let traceFile = traceDir.appendingPathComponent("trace.jsonl")
        let content = try String(contentsOf: traceFile, encoding: .utf8)

        let lines = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        let runDoneEvents = lines.filter { line in
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            return json["event"] as? String == "run_done"
        }
        XCTAssertGreaterThanOrEqual(runDoneEvents.count, 1,
            "Trace should capture run_done event even when budget exceeded")
    }

    // MARK: - AC7: Trace payload does not contain sensitive data

    /// AC7 [P0]: The trace file should not contain the API key from agent options.
    func testStream_TraceFile_DoesNotContainApiKey() async throws {
        let runId = "sanity-\(UUID().uuidString.prefix(8))"
        let traceDir = tempDir.appendingPathComponent(runId, isDirectory: true)
        let sut = makeTraceStreamSUT(traceEnabled: true, traceBaseURL: tempDir.path, runId: runId)

        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Clean trace"],
            stopReason: "end_turn",
            inputTokens: 50,
            outputTokens: 20
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Sanitize test")
        for await _ in stream {}

        let traceFile = traceDir.appendingPathComponent("trace.jsonl")
        let content = try String(contentsOf: traceFile, encoding: .utf8)

        XCTAssertFalse(content.contains("sk-test-trace-key"),
            "Trace file should not contain the API key")
    }
}

// MARK: - TraceRecorder + Prompt (Blocking) Path Integration

final class TraceRecorderPromptIntegrationTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TracePrompt-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    func makeTracePromptSUT(
        model: String = "claude-sonnet-4-6",
        traceEnabled: Bool = false,
        traceBaseURL: String? = nil,
        maxBudgetUsd: Double? = nil,
        maxTurns: Int = 10,
        runId: String? = nil
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [AgentLoopMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        let client = AnthropicClient(apiKey: "sk-test-prompt-trace", baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: "sk-test-prompt-trace",
            model: model,
            maxTurns: maxTurns,
            maxTokens: 4096,
            maxBudgetUsd: maxBudgetUsd,
            permissionMode: .bypassPermissions,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529]),
            runId: runId,
            traceEnabled: traceEnabled,
            traceBaseURL: traceBaseURL
        )

        return Agent(options: options, client: client)
    }

    // MARK: - Trace file creation in prompt path

    /// AC5 [P0]: Given traceEnabled=true, when agent.prompt() completes,
    /// the trace directory is created (TraceRecorder initializes).
    func testPrompt_TraceEnabled_CreatesTraceDirectory() async throws {
        let runId = "prompt-\(UUID().uuidString.prefix(8))"
        let sut = makeTracePromptSUT(traceEnabled: true, traceBaseURL: tempDir.path, runId: runId)

        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Response"]],
            stopReason: "end_turn",
            inputTokens: 100,
            outputTokens: 50
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        _ = await sut.prompt("Test prompt trace")

        let traceDir = tempDir.appendingPathComponent(runId, isDirectory: true)
        let dirExists = FileManager.default.fileExists(atPath: traceDir.path)
        XCTAssertTrue(dirExists, "Trace directory should be created when traceEnabled=true")
    }

    /// AC5 [P0]: Given traceEnabled=false, no trace directory is created during prompt().
    func testPrompt_TraceDisabled_NoTraceDirectory() async throws {
        let sut = makeTracePromptSUT(traceEnabled: false, traceBaseURL: tempDir.path)

        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Response"]],
            stopReason: "end_turn",
            inputTokens: 50,
            outputTokens: 20
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        _ = await sut.prompt("No trace prompt test")

        let contents = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let subdirs = contents?.filter { $0.hasDirectoryPath } ?? []
        XCTAssertTrue(subdirs.isEmpty, "No trace subdirectories should be created when traceEnabled=false")
    }

    // MARK: - CostTracker integration in prompt path

    /// AC1 [P0]: Given a completed prompt(), the result contains correct cost tracking
    /// that matches CostTracker accumulation logic.
    func testPrompt_CostTracking_MatchesExpectedCost() async throws {
        let sut = makeTracePromptSUT(model: "claude-sonnet-4-6")

        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Cost test"]],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Test cost tracking integration")

        // claude-sonnet-4-6: $3/M input, $15/M output
        // Expected: 1000 * 3e-6 + 500 * 15e-6 = 0.003 + 0.0075 = 0.0105
        let expectedCost = estimateCost(
            model: "claude-sonnet-4-6",
            usage: TokenUsage(inputTokens: 1000, outputTokens: 500)
        )
        XCTAssertEqual(result.totalCostUsd, expectedCost, accuracy: 0.0001,
            "Prompt result cost should match CostTracker accumulation")
    }

    /// AC2 [P0]: Budget enforcement via CostTracker stops the prompt loop.
    func testPrompt_BudgetExceeded_CostTrackerIntegration() async throws {
        let sut = makeTracePromptSUT(maxBudgetUsd: 0.005, maxTurns: 5)

        let responses = [
            makeAgentLoopResponse(id: "msg_1", stopReason: "max_tokens",
                                   inputTokens: 500, outputTokens: 200),
            makeAgentLoopResponse(id: "msg_2", stopReason: "end_turn",
                                   inputTokens: 1000, outputTokens: 500),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        let result = await sut.prompt("Budget test with cost tracker")

        // Turn 1: 500*3e-6 + 200*15e-6 = 0.0015 + 0.003 = 0.0045 < 0.005 -> continue
        // Turn 2: 1000*3e-6 + 500*15e-6 = 0.003 + 0.0075 = 0.0105
        //   cumulative = 0.0045 + 0.0105 = 0.015 > 0.005 -> exceeded
        XCTAssertEqual(result.status, .errorMaxBudgetUsd,
            "Budget should be exceeded via CostTracker integration")
        XCTAssertEqual(result.numTurns, 2,
            "Loop should stop after turn 2 when cost exceeds budget")
    }
}

// MARK: - CostTracker + TraceRecorder Combined Integration

final class CostTraceCombinedIntegrationTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
        StreamMockURLProtocol.reset()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CostTraceCombined-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        AgentLoopMockURLProtocol.reset()
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC1+AC5 [P0]: Given traceEnabled=true and cost tracking active, both systems
    /// produce correct output: trace file with run_done and QueryResult with accurate cost.
    func testStream_CostAndTraceBothActive() async throws {
        let runId = "combined-\(UUID().uuidString.prefix(8))"
        let traceDir = tempDir.appendingPathComponent(runId, isDirectory: true)

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StreamMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        let client = AnthropicClient(apiKey: "sk-test-combined", baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: "sk-test-combined",
            model: "claude-sonnet-4-6",
            maxTurns: 5,
            maxTokens: 4096,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529]),
            runId: runId,
            traceEnabled: true,
            traceBaseURL: tempDir.path
        )
        let sut = Agent(options: options, client: client)

        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Combined test"],
            stopReason: "end_turn",
            inputTokens: 1000,
            outputTokens: 500
        )
        registerStreamMockResponse(body: sseBody)

        var resultData: SDKMessage.ResultData?
        for await message in sut.stream("Test combined cost and trace") {
            if case let .result(data) = message {
                resultData = data
            }
        }

        // Verify cost tracking
        XCTAssertNotNil(resultData)
        let expectedCost = estimateCost(
            model: "claude-sonnet-4-6",
            usage: TokenUsage(inputTokens: 1000, outputTokens: 500)
        )
        XCTAssertEqual(resultData?.totalCostUsd ?? -1, expectedCost, accuracy: 0.0001,
            "Stream result cost should be accurate")

        // Verify trace recording
        let traceFile = traceDir.appendingPathComponent("trace.jsonl")
        let traceContent = try String(contentsOf: traceFile, encoding: .utf8)
        XCTAssertTrue(traceContent.contains("run_done"),
            "Trace should contain run_done event")

        // Verify trace does not contain API key
        XCTAssertFalse(traceContent.contains("sk-test-combined"),
            "Trace should not contain API key")
    }

    /// AC2+AC5 [P1]: Budget exceeded with tracing active — trace captures the event,
    /// cost is accurate.
    func testStream_BudgetExceededWithTrace_CostAndTraceBothCorrect() async throws {
        let runId = "budget-trace-\(UUID().uuidString.prefix(8))"
        let traceDir = tempDir.appendingPathComponent(runId, isDirectory: true)

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StreamMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        let client = AnthropicClient(apiKey: "sk-test-budget-trace", baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: "sk-test-budget-trace",
            model: "claude-sonnet-4-6",
            maxTurns: 5,
            maxTokens: 4096,
            maxBudgetUsd: 0.005,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529]),
            runId: runId,
            traceEnabled: true,
            traceBaseURL: tempDir.path
        )
        let sut = Agent(options: options, client: client)

        // input 10, output 500 → cost = 10*3e-6 + 500*15e-6 = 0.00003 + 0.0075 = 0.00753 > 0.005
        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Over budget"],
            stopReason: "max_tokens",
            inputTokens: 10,
            outputTokens: 500
        )
        registerStreamMockResponse(body: sseBody)

        var resultData: SDKMessage.ResultData?
        for await message in sut.stream("Budget with trace test") {
            if case let .result(data) = message {
                resultData = data
            }
        }

        // Verify budget was exceeded
        XCTAssertEqual(resultData?.subtype, .errorMaxBudgetUsd,
            "Budget should be exceeded")

        // Verify trace captured the event
        let traceFile = traceDir.appendingPathComponent("trace.jsonl")
        let traceContent = try String(contentsOf: traceFile, encoding: .utf8)
        XCTAssertTrue(traceContent.contains("run_done"),
            "Trace should record run_done even when budget exceeded")
    }

    /// Multi-model cost tracking integration: Verify costBreakdown contains per-model entries.
    func testPrompt_MultiModelCostBreakdown() async throws {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [AgentLoopMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        let client = AnthropicClient(apiKey: "sk-test-multi-model", baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: "sk-test-multi-model",
            model: "claude-sonnet-4-6",
            maxTurns: 5,
            maxTokens: 4096,
            permissionMode: .bypassPermissions,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529])
        )
        let sut = Agent(options: options, client: client)

        let responses = [
            makeAgentLoopResponse(id: "msg_1", model: "claude-sonnet-4-6",
                                   stopReason: "max_tokens",
                                   inputTokens: 500, outputTokens: 200),
            makeAgentLoopResponse(id: "msg_2", model: "claude-sonnet-4-6",
                                   stopReason: "end_turn",
                                   inputTokens: 1000, outputTokens: 500),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        let result = await sut.prompt("Multi-model cost breakdown test")

        XCTAssertFalse(result.costBreakdown.isEmpty,
            "Cost breakdown should not be empty")
        XCTAssertEqual(result.numTurns, 2,
            "Should complete 2 turns")
        XCTAssertGreaterThan(result.totalCostUsd, 0,
            "Total cost should be positive")
    }
}

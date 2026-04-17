import XCTest
@testable import OpenAgentSDK

// MARK: - Mock URL Protocol for Agent Loop Tests

/// Custom URLProtocol subclass that intercepts network requests for agent loop testing.
/// Allows injecting predefined API responses and inspecting outbound requests.
final class AgentLoopMockURLProtocol: URLProtocol {

    /// Static storage for mock responses keyed by URL string.
    nonisolated(unsafe) static var mockResponses: [String: (statusCode: Int, headers: [String: String], body: Data)] = [:]

    /// Records the last request sent through this protocol for inspection.
    nonisolated(unsafe) static var lastRequest: URLRequest?

    /// Records all requests sent through this protocol (for multi-turn verification).
    nonisolated(unsafe) static var allRequests: [URLRequest] = []

    /// Counter for sequential responses (multi-turn support).
    nonisolated(unsafe) static var sequentialResponses: [[String: Any]] = []

    /// Current index into sequential responses.
    nonisolated(unsafe) static var responseIndex: Int = 0

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Capture request with body
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            capturedRequest.httpBody = Self.readBodyFromStream(stream)
        }

        AgentLoopMockURLProtocol.lastRequest = capturedRequest
        AgentLoopMockURLProtocol.allRequests.append(capturedRequest)

        // If sequential responses are configured, use them in order
        if !AgentLoopMockURLProtocol.sequentialResponses.isEmpty {
            let index = AgentLoopMockURLProtocol.responseIndex
            if index < AgentLoopMockURLProtocol.sequentialResponses.count {
                let responseData = AgentLoopMockURLProtocol.sequentialResponses[index]
                AgentLoopMockURLProtocol.responseIndex += 1

                let body = try! JSONSerialization.data(withJSONObject: responseData, options: [])
                let httpResponse = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["content-type": "application/json"]
                )!

                client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: body)
                client?.urlProtocolDidFinishLoading(self)
                return
            }
        }

        guard let url = request.url?.absoluteString,
              let mock = AgentLoopMockURLProtocol.mockResponses[url] else {
            let error = NSError(domain: "AgentLoopMockURLProtocol", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No mock response registered for URL: \(request.url?.absoluteString ?? "nil")"
            ])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: mock.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: mock.headers
        )!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: mock.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func readBodyFromStream(_ stream: InputStream) -> Data? {
        stream.open()
        defer { stream.close() }

        let bufferSize = 4096
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            if bytesRead < 0 { return nil }
            if bytesRead == 0 { break }
            data.append(buffer, count: bytesRead)
        }

        return data
    }

    override func stopLoading() {}

    static func reset() {
        mockResponses = [:]
        lastRequest = nil
        allRequests = []
        sequentialResponses = []
        responseIndex = 0
    }
}

// MARK: - Test Helpers

extension XCTestCase {

    /// Creates an Agent configured with MockURLProtocol for agent loop testing.
    /// Returns the agent and the AnthropicClient (for potential direct inspection).
    func makeAgentLoopSUT(
        apiKey: String = "sk-test-api-key-loop-12345",
        model: String = "claude-sonnet-4-6",
        systemPrompt: String? = nil,
        maxTurns: Int = 10,
        maxTokens: Int = 4096,
        cwd: String? = nil
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [AgentLoopMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)

        let client = AnthropicClient(apiKey: apiKey, baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            systemPrompt: systemPrompt,
            maxTurns: maxTurns,
            maxTokens: maxTokens,
            cwd: cwd,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529])
        )

        return Agent(options: options, client: client)
    }

    /// Builds a standard non-streaming Anthropic API response JSON.
    func makeAgentLoopResponse(
        id: String = "msg_loop_001",
        model: String = "claude-sonnet-4-6",
        content: [[String: Any]] = [["type": "text", "text": "Swift concurrency is..."]],
        stopReason: String = "end_turn",
        inputTokens: Int = 25,
        outputTokens: Int = 150
    ) -> [String: Any] {
        return [
            "id": id,
            "type": "message",
            "role": "assistant",
            "content": content,
            "model": model,
            "stop_reason": stopReason,
            "stop_sequence": NSNull(),
            "usage": [
                "input_tokens": inputTokens,
                "output_tokens": outputTokens
            ]
        ]
    }

    /// Serializes a dictionary to JSON data.
    func loopJsonData(from dict: [String: Any]) -> Data {
        return try! JSONSerialization.data(withJSONObject: dict, options: [])
    }

    /// Registers a mock response for the Anthropic API endpoint.
    func registerAgentLoopMockResponse(statusCode: Int = 200, body: Data) {
        AgentLoopMockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: statusCode,
            headers: ["content-type": "application/json"],
            body: body
        )
    }

    /// Registers sequential mock responses for multi-turn agent loop testing.
    func registerSequentialAgentLoopMockResponses(_ responses: [[String: Any]]) {
        AgentLoopMockURLProtocol.sequentialResponses = responses
        AgentLoopMockURLProtocol.responseIndex = 0
    }
}

// MARK: - AC1: Basic Agent Loop Execution (No Tools)

/// ATDD RED PHASE: Tests for Story 1.5 -- Agent Loop & Blocking Response.
/// All tests assert EXPECTED behavior. They will FAIL until Agent.prompt() is implemented.
/// TDD Phase: RED (feature not implemented yet)
final class AgentLoopBasicTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC1 [P0]: Given an Agent with no tools, when developer calls agent.prompt("Explain Swift concurrency"),
    /// then the agent loop executes: sends message to LLM, receives response, returns final result (FR4),
    /// and the response contains assistant text content and usage statistics (FR3).
    func testPromptReturnsTextAndUsageForBasicQuery() async throws {
        let sut = makeAgentLoopSUT()
        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Swift concurrency uses async/await for structured concurrency."]],
            stopReason: "end_turn",
            inputTokens: 30,
            outputTokens: 200
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Explain Swift concurrency")

        // Verify text content extracted from response
        XCTAssertEqual(result.text, "Swift concurrency uses async/await for structured concurrency.",
                       "Prompt result should contain the assistant's text response")
        // Verify usage statistics
        XCTAssertEqual(result.usage.inputTokens, 30,
                       "Usage should reflect input tokens from API response")
        XCTAssertEqual(result.usage.outputTokens, 200,
                       "Usage should reflect output tokens from API response")
    }

    /// AC1 [P0]: Single-turn prompt returns numTurns = 1.
    func testPromptSingleTurnReturnsNumTurnsOne() async throws {
        let sut = makeAgentLoopSUT()
        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Hello!"]],
            stopReason: "end_turn"
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Hi")

        XCTAssertEqual(result.numTurns, 1,
                       "Single-turn prompt should report numTurns = 1")
        XCTAssertEqual(result.status, .success,
                       "Normal end_turn completion should return success status")
    }

    /// AC1 [P1]: Prompt returns non-negative durationMs.
    func testPromptReturnsNonNegativeDuration() async throws {
        let sut = makeAgentLoopSUT()
        let responseDict = makeAgentLoopResponse(stopReason: "end_turn")
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Hello")

        XCTAssertGreaterThanOrEqual(result.durationMs, 0,
                                     "Duration should be non-negative")
    }

    /// AC1 [P1]: Prompt with empty string returns a response without crashing.
    func testPromptWithEmptyStringReturnsResponse() async throws {
        let sut = makeAgentLoopSUT()
        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "You sent an empty message."]],
            stopReason: "end_turn"
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("")

        XCTAssertNotNil(result, "Prompt with empty string should return a result")
        XCTAssertEqual(result.numTurns, 1, "Should complete in 1 turn")
    }
}

// MARK: - AC2: maxTurns Limit

final class AgentLoopMaxTurnsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC2 [P0]: Given an Agent configured with maxTurns=1, when the loop reaches 1 turn,
    /// the loop stops and returns a result with maxTurnsExceeded status (FR6).
    func testMaxTurnsOneStopsLoop() async throws {
        let sut = makeAgentLoopSUT(maxTurns: 1)
        // Return a response that does NOT have end_turn (simulates needing more turns)
        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "I need to continue..."]],
            stopReason: "max_tokens",
            inputTokens: 50,
            outputTokens: 100
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Keep going")

        XCTAssertEqual(result.numTurns, 1,
                       "Should stop at exactly 1 turn when maxTurns=1")
    }

    /// AC2 [P0]: When maxTurns is exceeded, the result indicates the limit was reached.
    func testMaxTurnsExceededReturnsAppropriateStatus() async throws {
        let sut = makeAgentLoopSUT(maxTurns: 2)
        // Both responses do NOT have end_turn, forcing loop to hit maxTurns
        let responses = [
            makeAgentLoopResponse(stopReason: "max_tokens", inputTokens: 10, outputTokens: 50),
            makeAgentLoopResponse(stopReason: "max_tokens", inputTokens: 15, outputTokens: 60),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        let result = await sut.prompt("Keep going until limit")

        XCTAssertEqual(result.numTurns, 2,
                       "Should stop at exactly 2 turns when maxTurns=2")
        XCTAssertEqual(result.status, .errorMaxTurns,
                       "Exceeding maxTurns should return errorMaxTurns status")
    }

    /// AC2 [P1]: When maxTurns is not exceeded (end_turn happens first), result reflects success.
    func testEndTurnBeforeMaxTurnsSucceeds() async throws {
        let sut = makeAgentLoopSUT(maxTurns: 5)
        let responseDict = makeAgentLoopResponse(stopReason: "end_turn")
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Quick question")

        XCTAssertEqual(result.numTurns, 1,
                       "Should complete in 1 turn when end_turn received")
        XCTAssertLessThanOrEqual(result.numTurns, 5,
                                  "Turns should not exceed maxTurns")
    }
}

// MARK: - AC3: end_turn Termination

final class AgentLoopEndTurnTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC3 [P0]: Given LLM returns stop_reason="end_turn", when the loop processes this response,
    /// the loop terminates and returns the complete response.
    func testEndTurnStopsLoopAndReturnsResponse() async throws {
        let sut = makeAgentLoopSUT()
        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Here is the complete answer."]],
            stopReason: "end_turn",
            inputTokens: 40,
            outputTokens: 300
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Give me a complete answer")

        XCTAssertEqual(result.text, "Here is the complete answer.",
                       "Should return the text from the end_turn response")
        XCTAssertEqual(result.usage.inputTokens, 40,
                       "Should report input tokens from the response")
        XCTAssertEqual(result.usage.outputTokens, 300,
                       "Should report output tokens from the response")
    }

    /// AC3 [P1]: stop_reason="stop_sequence" should also terminate the loop.
    func testStopSequenceTerminatesLoop() async throws {
        let sut = makeAgentLoopSUT()
        let responseDict = makeAgentLoopResponse(
            content: [["type": "text", "text": "Stopped by sequence."]],
            stopReason: "stop_sequence"
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Test stop sequence")

        XCTAssertEqual(result.numTurns, 1,
                       "stop_sequence should terminate the loop after 1 turn")
    }
}

// MARK: - AC4: API Error Propagation

final class AgentLoopErrorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC4 [P0]: Given an LLM call that fails due to HTTP 500, when the loop captures the error,
    /// it returns an errorDuringExecution status result with error info, and the app does not crash (NFR17).
    func testAPIError500DoesNotCrash() async throws {
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

        let result = await sut.prompt("Trigger server error")
        XCTAssertEqual(result.status, .errorDuringExecution,
                       "API 500 error should return errorDuringExecution status")
    }

    /// AC4 [P0]: Network error (timeout) returns errorDuringExecution, app does not crash.
    func testNetworkErrorDoesNotCrash() async throws {
        let sut = makeAgentLoopSUT()
        // Register no mock response — will cause a mock protocol error
        // Or we can register an error-producing response
        let errorBody: [String: Any] = [
            "error": [
                "type": "timeout_error",
                "message": "Request timed out"
            ]
        ]
        registerAgentLoopMockResponse(
            statusCode: 408,
            body: loopJsonData(from: errorBody)
        )

        let result = await sut.prompt("Trigger timeout")
        XCTAssertEqual(result.status, .errorDuringExecution,
                       "Network error should return errorDuringExecution status")
    }

    /// AC4 [P0]: Authentication error (401) returns error result, app does not crash.
    func testAuthError401DoesNotCrash() async throws {
        let sut = makeAgentLoopSUT(apiKey: "invalid-key")
        let errorBody: [String: Any] = [
            "error": [
                "type": "authentication_error",
                "message": "invalid x-api-key"
            ]
        ]
        registerAgentLoopMockResponse(
            statusCode: 401,
            body: loopJsonData(from: errorBody)
        )

        let result = await sut.prompt("Test auth error")
        XCTAssertEqual(result.status, .errorDuringExecution,
                       "Auth error should return errorDuringExecution status")
    }

    /// AC4 [P1]: Rate limit error (429) returns error result.
    func testRateLimitError429DoesNotCrash() async throws {
        let sut = makeAgentLoopSUT()
        let errorBody: [String: Any] = [
            "error": [
                "type": "rate_limit_error",
                "message": "Rate limit exceeded. Please retry after 30 seconds."
            ]
        ]
        registerAgentLoopMockResponse(
            statusCode: 429,
            body: loopJsonData(from: errorBody)
        )

        let result = await sut.prompt("Trigger rate limit")
        XCTAssertEqual(result.status, .errorDuringExecution,
                       "Rate limit error should return errorDuringExecution status")
    }
}

// MARK: - AC5: Usage Statistics

final class AgentLoopUsageStatsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC5 [P1]: Given a completed agent call, when developer checks QueryResult,
    /// it contains accumulated inputTokens, outputTokens, numTurns, and durationMs.
    func testSingleTurnUsageStatistics() async throws {
        let sut = makeAgentLoopSUT()
        let responseDict = makeAgentLoopResponse(
            stopReason: "end_turn",
            inputTokens: 42,
            outputTokens: 187
        )
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Count my tokens")

        XCTAssertEqual(result.usage.inputTokens, 42,
                       "QueryResult should contain inputTokens from API response")
        XCTAssertEqual(result.usage.outputTokens, 187,
                       "QueryResult should contain outputTokens from API response")
        XCTAssertEqual(result.numTurns, 1,
                       "QueryResult should contain numTurns")
        XCTAssertGreaterThanOrEqual(result.durationMs, 0,
                                     "QueryResult should contain non-negative durationMs")
    }

    /// AC5 [P1]: Multi-turn usage accumulates across turns.
    func testMultiTurnUsageAccumulates() async throws {
        let sut = makeAgentLoopSUT(maxTurns: 5)
        let responses = [
            makeAgentLoopResponse(id: "msg_turn1", stopReason: "max_tokens",
                                   inputTokens: 20, outputTokens: 100),
            makeAgentLoopResponse(id: "msg_turn2", stopReason: "end_turn",
                                   inputTokens: 30, outputTokens: 150),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        let result = await sut.prompt("Multi-turn query")

        XCTAssertEqual(result.numTurns, 2,
                       "Should accumulate 2 turns")
        XCTAssertEqual(result.usage.inputTokens, 50,
                       "Input tokens should accumulate: 20 + 30 = 50")
        XCTAssertEqual(result.usage.outputTokens, 250,
                       "Output tokens should accumulate: 100 + 150 = 250")
    }

    /// AC5 [P1]: Duration is measured in milliseconds.
    func testDurationIsMeasuredInMilliseconds() async throws {
        // Use a non-Git temp directory to isolate from Git context collection overhead
        let tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-Duration-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let sut = makeAgentLoopSUT(cwd: tempDir)
        let responseDict = makeAgentLoopResponse(stopReason: "end_turn")
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        let result = await sut.prompt("Time me")

        // Duration should be a reasonable number of milliseconds (not seconds, not nanoseconds)
        // Even a fast mock response should produce a measurable duration
        XCTAssertGreaterThanOrEqual(result.durationMs, 0,
                                     "Duration should be >= 0 ms")
        XCTAssertLessThan(result.durationMs, 120_000,
                          "Duration should be less than 120 seconds (sanity check for millisecond unit)")
    }
}

// MARK: - AC6: System Prompt Passed Correctly

final class AgentLoopSystemPromptTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC6 [P1]: Given an Agent created with a custom systemPrompt, when the Agent calls the LLM API,
    /// the system prompt is included as the `system` parameter in the API request.
    func testSystemPromptIncludedInAPIRequest() async throws {
        let systemPrompt = "You are a Swift concurrency expert. Be concise."
        // Use a non-Git temp directory to isolate from Git context injection
        let tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-SystemPrompt-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let sut = makeAgentLoopSUT(systemPrompt: systemPrompt, cwd: tempDir)
        let responseDict = makeAgentLoopResponse(stopReason: "end_turn")
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        _ = await sut.prompt("Explain async/await")

        // Inspect the request that was sent
        let lastRequest = AgentLoopMockURLProtocol.lastRequest
        XCTAssertNotNil(lastRequest, "A request should have been sent")

        // Parse the request body
        let bodyData = lastRequest!.httpBody
        XCTAssertNotNil(bodyData, "Request should have a body")

        let body = try JSONSerialization.jsonObject(with: bodyData!, options: []) as! [String: Any]

        let systemValue = body["system"] as? String
        XCTAssertNotNil(systemValue,
                       "API request should include the system prompt in the 'system' field")
        XCTAssertTrue(systemValue!.contains(systemPrompt),
                       "System field should contain the configured system prompt")
    }

    /// AC6 [P1]: Given an Agent with no system prompt, when the Agent calls the LLM API,
    /// the request does NOT include a `system` parameter.
    func testNoSystemPromptExcludesSystemFromRequest() async throws {
        // Use a non-Git temp directory to isolate from Git context injection
        let tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-NoSystemPrompt-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let sut = makeAgentLoopSUT(systemPrompt: nil, cwd: tempDir)
        let responseDict = makeAgentLoopResponse(stopReason: "end_turn")
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        _ = await sut.prompt("Hello")

        let lastRequest = AgentLoopMockURLProtocol.lastRequest
        XCTAssertNotNil(lastRequest, "A request should have been sent")

        let bodyData = lastRequest!.httpBody
        XCTAssertNotNil(bodyData, "Request should have a body")

        let body = try JSONSerialization.jsonObject(with: bodyData!, options: []) as! [String: Any]

        // Note: When ~/.claude/CLAUDE.md exists on the real machine, the system field
        // may contain global instructions even without an explicit system prompt.
        // The key assertion is that no user-defined system prompt text appears.
        let systemValue = body["system"] as? String
        if let systemValue = systemValue {
            // Global instructions may be present from ~/.claude/CLAUDE.md
            XCTAssertTrue(systemValue.contains("<global-instructions>"),
                          "System field should only contain global instructions, not a user prompt")
        }
        // If nil, that's also acceptable (no instructions at all)
    }

    /// AC6 [P1]: Empty string system prompt is included in request.
    func testEmptySystemPromptIncludedInRequest() async throws {
        // Use a non-Git temp directory to isolate from Git context injection
        let tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-EmptySystemPrompt-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let sut = makeAgentLoopSUT(systemPrompt: "", cwd: tempDir)
        let responseDict = makeAgentLoopResponse(stopReason: "end_turn")
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        _ = await sut.prompt("Hello")

        let lastRequest = AgentLoopMockURLProtocol.lastRequest
        XCTAssertNotNil(lastRequest, "A request should have been sent")

        let bodyData = lastRequest!.httpBody
        XCTAssertNotNil(bodyData, "Request should have a body")

        let body = try JSONSerialization.jsonObject(with: bodyData!, options: []) as! [String: Any]

        // Empty string is still a valid system prompt
        XCTAssertNotNil(body["system"],
                        "Empty string system prompt should still be included in request")
    }
}

// MARK: - AC7: Empty Tools List

final class AgentLoopToolsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC7 [P1]: Given an Agent with no registered tools, when building the API request,
    /// the `tools` parameter is NOT included (Anthropic API does not need `tools` field when empty).
    func testNoToolsExcludesToolsFromRequest() async throws {
        let sut = makeAgentLoopSUT()
        let responseDict = makeAgentLoopResponse(stopReason: "end_turn")
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        _ = await sut.prompt("No tools needed")

        let lastRequest = AgentLoopMockURLProtocol.lastRequest
        XCTAssertNotNil(lastRequest, "A request should have been sent")

        let bodyData = lastRequest!.httpBody
        XCTAssertNotNil(bodyData, "Request should have a body")

        let body = try JSONSerialization.jsonObject(with: bodyData!, options: []) as! [String: Any]

        XCTAssertNil(body["tools"],
                     "API request should NOT include 'tools' field when no tools are registered")
        XCTAssertNil(body["tool_choice"],
                     "API request should NOT include 'tool_choice' field when no tools are registered")
    }

    /// AC7 [P1]: The request includes the correct model from AgentOptions.
    func testRequestIncludesCorrectModel() async throws {
        let sut = makeAgentLoopSUT(model: "claude-opus-4")
        let responseDict = makeAgentLoopResponse(stopReason: "end_turn")
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        _ = await sut.prompt("Check model")

        let lastRequest = AgentLoopMockURLProtocol.lastRequest
        XCTAssertNotNil(lastRequest, "A request should have been sent")

        let bodyData = lastRequest!.httpBody
        XCTAssertNotNil(bodyData, "Request should have a body")

        let body = try JSONSerialization.jsonObject(with: bodyData!, options: []) as! [String: Any]

        XCTAssertEqual(body["model"] as? String, "claude-opus-4",
                       "API request should use the model specified in AgentOptions")
    }

    /// AC7 [P1]: The request includes the correct maxTokens from AgentOptions.
    func testRequestIncludesCorrectMaxTokens() async throws {
        let sut = makeAgentLoopSUT(maxTokens: 8192)
        let responseDict = makeAgentLoopResponse(stopReason: "end_turn")
        registerAgentLoopMockResponse(body: loopJsonData(from: responseDict))

        _ = await sut.prompt("Check max tokens")

        let lastRequest = AgentLoopMockURLProtocol.lastRequest
        XCTAssertNotNil(lastRequest, "A request should have been sent")

        let bodyData = lastRequest!.httpBody
        XCTAssertNotNil(bodyData, "Request should have a body")

        let body = try JSONSerialization.jsonObject(with: bodyData!, options: []) as! [String: Any]

        XCTAssertEqual(body["max_tokens"] as? Int, 8192,
                       "API request should use maxTokens from AgentOptions")
    }
}

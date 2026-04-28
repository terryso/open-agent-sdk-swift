import XCTest
@testable import OpenAgentSDK

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
// MARK: - Mock URL Protocol for Retry Tests (Blocking Path)

/// Custom URLProtocol that supports returning different status codes on sequential requests
/// to simulate transient errors followed by success.
final class RetryMockURLProtocol: URLProtocol {

    /// Sequential responses: each entry is (statusCode, headers, body).
    /// Consumed in order; when exhausted, returns a generic error.
    nonisolated(unsafe) static var sequentialResponses: [(statusCode: Int, headers: [String: String], body: Data)] = []

    /// Current index into sequential responses.
    nonisolated(unsafe) static var responseIndex: Int = 0

    /// Records all requests sent through this protocol.
    nonisolated(unsafe) static var allRequests: [URLRequest] = []

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

        RetryMockURLProtocol.allRequests.append(capturedRequest)

        let index = RetryMockURLProtocol.responseIndex
        if index < RetryMockURLProtocol.sequentialResponses.count {
            let response = RetryMockURLProtocol.sequentialResponses[index]
            RetryMockURLProtocol.responseIndex += 1

            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            )!

            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.body)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            let error = NSError(
                domain: "RetryMockURLProtocol",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No more mock responses (index: \(index))"]
            )
            client?.urlProtocol(self, didFailWithError: error)
        }
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

    private var stopped = false
    override func stopLoading() { stopped = true }

    static func reset() {
        sequentialResponses = []
        responseIndex = 0
        allRequests = []
    }
}

// MARK: - Mock URL Protocol for Retry Tests (Streaming Path)

/// Custom URLProtocol that supports returning error status codes on sequential requests
/// for stream retry testing.
final class RetryStreamMockURLProtocol: URLProtocol {

    /// Sequential responses: each entry is (statusCode, headers, body).
    nonisolated(unsafe) static var sequentialResponses: [(statusCode: Int, headers: [String: String], body: Data)] = []

    /// Current index into sequential responses.
    nonisolated(unsafe) static var responseIndex: Int = 0

    /// Records all requests sent through this protocol.
    nonisolated(unsafe) static var allRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            capturedRequest.httpBody = Self.readBodyFromStream(stream)
        }

        RetryStreamMockURLProtocol.allRequests.append(capturedRequest)

        let index = RetryStreamMockURLProtocol.responseIndex
        if index < RetryStreamMockURLProtocol.sequentialResponses.count {
            let response = RetryStreamMockURLProtocol.sequentialResponses[index]
            RetryStreamMockURLProtocol.responseIndex += 1

            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            )!

            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.body)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            let error = NSError(
                domain: "RetryStreamMockURLProtocol",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No more mock responses (index: \(index))"]
            )
            client?.urlProtocol(self, didFailWithError: error)
        }
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

    private var stopped = false
    override func stopLoading() { stopped = true }

    static func reset() {
        sequentialResponses = []
        responseIndex = 0
        allRequests = []
    }
}

// MARK: - Test Helpers for Retry Tests

extension XCTestCase {

    /// Creates an Agent configured with RetryMockURLProtocol for blocking path retry testing.
    func makeRetryPromptSUT(
        apiKey: String = "sk-test-retry-key-12345",
        model: String = "claude-sonnet-4-6",
        maxTurns: Int = 10
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [RetryMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        let client = AnthropicClient(apiKey: apiKey, baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            maxTurns: maxTurns,
            maxTokens: 4096,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529])
        )

        return Agent(options: options, client: client)
    }

    /// Creates an Agent configured with RetryStreamMockURLProtocol for stream retry testing.
    func makeRetryStreamSUT(
        apiKey: String = "sk-test-retry-stream-key",
        model: String = "claude-sonnet-4-6",
        maxTurns: Int = 10
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [RetryStreamMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        let client = AnthropicClient(apiKey: apiKey, baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            maxTurns: maxTurns,
            maxTokens: 4096,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529])
        )

        return Agent(options: options, client: client)
    }

    /// Builds an error response body for the Anthropic API.
    func makeErrorResponse(errorType: String, message: String) -> Data {
        let dict: [String: Any] = [
            "error": [
                "type": errorType,
                "message": message
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: dict, options: [])
    }

    /// Registers sequential mock responses for retry testing (blocking path).
    /// Each element is a tuple of (statusCode, headers, body).
    func registerRetryMockResponses(_ responses: [(statusCode: Int, headers: [String: String], body: Data)]) {
        RetryMockURLProtocol.sequentialResponses = responses
        RetryMockURLProtocol.responseIndex = 0
    }

    /// Registers sequential mock responses for retry testing (streaming path).
    func registerRetryStreamMockResponses(_ responses: [(statusCode: Int, headers: [String: String], body: Data)]) {
        RetryStreamMockURLProtocol.sequentialResponses = responses
        RetryStreamMockURLProtocol.responseIndex = 0
    }
}

// MARK: - AC1: Transient Error Auto-Retry (Blocking Path)

/// ATDD RED PHASE: Tests for Story 2.4 — Transient error retry in prompt() (blocking path).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Utils/Retry.swift` is created with RetryConfig, isRetryableError, withRetry
///   - `Agent.prompt()` wraps client.sendMessage() in withRetry
/// TDD Phase: RED (feature not implemented yet)
final class RetryPromptTests: XCTestCase {

    override func setUp() {
        super.setUp()
        RetryMockURLProtocol.reset()
    }

    override func tearDown() {
        RetryMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC1 [P0]: HTTP 503 x2 then success on 3rd attempt — prompt() returns success result.
    /// This verifies the retry mechanism recovers from transient server errors.
    func testPrompt_Retry503_ThenSuccess() async throws {
        let sut = makeRetryPromptSUT()

        let successResponse: [String: Any] = [
            "id": "msg_retry_success",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "Recovered after retries"]],
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "stop_sequence": NSNull(),
            "usage": ["input_tokens": 25, "output_tokens": 10]
        ]
        let successBody = try! JSONSerialization.data(withJSONObject: successResponse, options: [])

        registerRetryMockResponses([
            (503, ["content-type": "application/json"], makeErrorResponse(errorType: "api_error", message: "Service unavailable")),
            (503, ["content-type": "application/json"], makeErrorResponse(errorType: "api_error", message: "Service unavailable")),
            (200, ["content-type": "application/json"], successBody),
        ])

        let result = await sut.prompt("Test retry recovery")

        XCTAssertEqual(result.text, "Recovered after retries",
                       "Should return the successful response text after retries")
        XCTAssertEqual(result.status, .success,
                       "Should return success status after retry recovery")
    }

    /// AC1 [P0]: HTTP 429 x4 (exceeds 3 retries) — prompt() returns errorDuringExecution.
    /// This verifies that retry exhaustion produces a graceful error, not a crash.
    func testPrompt_Retry429_Exhausted() async throws {
        let sut = makeRetryPromptSUT()

        // Register 4 rate-limit errors (1 initial + 3 retries = 4 attempts, all fail)
        let rateLimitError = makeErrorResponse(errorType: "rate_limit_error", message: "Rate limit exceeded")
        registerRetryMockResponses([
            (429, ["content-type": "application/json"], rateLimitError),
            (429, ["content-type": "application/json"], rateLimitError),
            (429, ["content-type": "application/json"], rateLimitError),
            (429, ["content-type": "application/json"], rateLimitError),
        ])

        let result = await sut.prompt("Test retry exhaustion")

        XCTAssertEqual(result.status, .errorDuringExecution,
                       "Should return errorDuringExecution after all retries exhausted")
    }

    /// AC1 [P0]: HTTP 500 then success on 2nd attempt — verifies single retry works.
    func testPrompt_Retry500_ThenSuccess() async throws {
        let sut = makeRetryPromptSUT()

        let successResponse: [String: Any] = [
            "id": "msg_500_recovery",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "OK after 500"]],
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "stop_sequence": NSNull(),
            "usage": ["input_tokens": 20, "output_tokens": 8]
        ]
        let successBody = try! JSONSerialization.data(withJSONObject: successResponse, options: [])

        registerRetryMockResponses([
            (500, ["content-type": "application/json"], makeErrorResponse(errorType: "api_error", message: "Internal server error")),
            (200, ["content-type": "application/json"], successBody),
        ])

        let result = await sut.prompt("Test 500 recovery")

        XCTAssertEqual(result.text, "OK after 500",
                       "Should return success after recovering from HTTP 500")
        XCTAssertEqual(result.status, .success,
                       "Should return success status")
    }
}

// MARK: - AC2: Transient Error Auto-Retry (Streaming Path)

/// ATDD RED PHASE: Tests for Story 2.4 — Transient error retry in stream() (streaming path).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Agent.stream()` wraps capturedClient.streamMessage() in withRetry
/// TDD Phase: RED (feature not implemented yet)
final class RetryStreamTests: XCTestCase {

    override func setUp() {
        super.setUp()
        RetryStreamMockURLProtocol.reset()
    }

    override func tearDown() {
        RetryStreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC2 [P0]: HTTP 503 x2 then success on 3rd attempt — stream yields success result.
    func testStream_Retry503_ThenSuccess() async throws {
        let sut = makeRetryStreamSUT()

        let sseSuccessBody = makeSingleTurnSSEBody(
            textDeltas: ["Recovered stream"],
            stopReason: "end_turn",
            inputTokens: 25,
            outputTokens: 10
        )

        registerRetryStreamMockResponses([
            (503, ["content-type": "application/json"], makeErrorResponse(errorType: "api_error", message: "Service unavailable")),
            (503, ["content-type": "application/json"], makeErrorResponse(errorType: "api_error", message: "Service unavailable")),
            (200, ["content-type": "text/event-stream"], sseSuccessBody),
        ])

        let stream = sut.stream("Test stream retry recovery")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent,
                         "Should yield a result event after retry recovery")
        XCTAssertEqual(resultEvent?.subtype, .success,
                       "Should yield success subtype after retry recovery")
    }

    /// AC2 [P0]: HTTP 429 x4 (exceeds 3 retries) — stream yields errorDuringExecution result.
    func testStream_Retry429_Exhausted() async throws {
        let sut = makeRetryStreamSUT()

        let rateLimitError = makeErrorResponse(errorType: "rate_limit_error", message: "Rate limit exceeded")
        registerRetryStreamMockResponses([
            (429, ["content-type": "application/json"], rateLimitError),
            (429, ["content-type": "application/json"], rateLimitError),
            (429, ["content-type": "application/json"], rateLimitError),
            (429, ["content-type": "application/json"], rateLimitError),
        ])

        let stream = sut.stream("Test stream retry exhaustion")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent,
                         "Should yield a result event on retry exhaustion")
        XCTAssertEqual(resultEvent?.subtype, .errorDuringExecution,
                       "Should yield errorDuringExecution after stream retry exhaustion")
    }
}

// MARK: - AC3: max_tokens Continuation Recovery (Blocking Path)

/// ATDD RED PHASE: Tests for Story 2.4 — max_tokens continuation recovery in prompt().
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - max_tokens recovery counter (max 3) is added to prompt()
///   - Continuation prompt text changes from "continue" to "Please continue from where you left off."
/// TDD Phase: RED (feature not implemented yet)
final class MaxTokensRecoveryPromptTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC3 [P0]: max_tokens x2 then end_turn — prompt() returns success with accumulated text.
    func testPrompt_MaxTokensTwice_ThenEndTurn() async throws {
        let sut = makeAgentLoopSUT(maxTurns: 10)

        let responses = [
            makeAgentLoopResponse(
                id: "msg_mt_1",
                content: [["type": "text", "text": "Part 1 "]],
                stopReason: "max_tokens",
                inputTokens: 20,
                outputTokens: 100
            ),
            makeAgentLoopResponse(
                id: "msg_mt_2",
                content: [["type": "text", "text": "Part 2 "]],
                stopReason: "max_tokens",
                inputTokens: 30,
                outputTokens: 100
            ),
            makeAgentLoopResponse(
                id: "msg_mt_3",
                content: [["type": "text", "text": "Part 3"]],
                stopReason: "end_turn",
                inputTokens: 40,
                outputTokens: 50
            ),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        let result = await sut.prompt("Test max_tokens recovery")

        XCTAssertEqual(result.status, .success,
                       "Should return success after max_tokens recovery and end_turn")
        // Text should accumulate from all parts
        XCTAssertTrue(result.text.contains("Part 1"),
                      "Should contain text from first max_tokens response")
        XCTAssertTrue(result.text.contains("Part 2"),
                      "Should contain text from second max_tokens response")
        XCTAssertTrue(result.text.contains("Part 3"),
                      "Should contain text from final end_turn response")
    }

    /// AC3 [P0]: max_tokens x4 (exceeds 3 recovery limit) — prompt() returns success with partial text.
    /// Per story notes: max_tokens recovery exhaustion returns .success (not .errorDuringExecution)
    /// because partial valid text was already obtained.
    func testPrompt_MaxTokensExceedsRecoveryLimit() async throws {
        let sut = makeAgentLoopSUT(maxTurns: 20)

        // 4 max_tokens responses (exceeds the 3-recovery limit)
        let responses = [
            makeAgentLoopResponse(
                id: "msg_mt_1",
                content: [["type": "text", "text": "Part 1 "]],
                stopReason: "max_tokens",
                inputTokens: 20,
                outputTokens: 100
            ),
            makeAgentLoopResponse(
                id: "msg_mt_2",
                content: [["type": "text", "text": "Part 2 "]],
                stopReason: "max_tokens",
                inputTokens: 30,
                outputTokens: 100
            ),
            makeAgentLoopResponse(
                id: "msg_mt_3",
                content: [["type": "text", "text": "Part 3 "]],
                stopReason: "max_tokens",
                inputTokens: 40,
                outputTokens: 100
            ),
            makeAgentLoopResponse(
                id: "msg_mt_4",
                content: [["type": "text", "text": "Part 4"]],
                stopReason: "max_tokens",
                inputTokens: 50,
                outputTokens: 100
            ),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        let result = await sut.prompt("Test max_tokens limit")

        // Should stop after 3 recovery attempts (4 max_tokens total: initial + 3 recoveries)
        // and return partial results with .success status
        XCTAssertEqual(result.status, .success,
                       "max_tokens recovery exhaustion should return .success (not .errorDuringExecution)")
        XCTAssertFalse(result.text.isEmpty,
                       "Should return accumulated partial text even when recovery limit exceeded")
    }

    /// AC3 [P0]: Continuation prompt text is "Please continue from where you left off."
    func testPrompt_MaxTokens_ContinuationPromptText() async throws {
        let sut = makeAgentLoopSUT(maxTurns: 10)

        let responses = [
            makeAgentLoopResponse(
                id: "msg_mt_1",
                content: [["type": "text", "text": "Truncated"]],
                stopReason: "max_tokens",
                inputTokens: 20,
                outputTokens: 100
            ),
            makeAgentLoopResponse(
                id: "msg_mt_2",
                content: [["type": "text", "text": "Complete"]],
                stopReason: "end_turn",
                inputTokens: 30,
                outputTokens: 50
            ),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        _ = await sut.prompt("Test continuation prompt")

        // Verify the second request contains the expected continuation prompt
        let requests = AgentLoopMockURLProtocol.allRequests
        XCTAssertGreaterThanOrEqual(requests.count, 2,
                                     "Should have sent at least 2 requests")

        if requests.count >= 2 {
            let secondRequestBody = requests[1].httpBody
            XCTAssertNotNil(secondRequestBody, "Second request should have a body")

            if let bodyData = secondRequestBody,
               let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
               let messages = body["messages"] as? [[String: Any]] {

                // The last message should be the continuation prompt
                if let lastMessage = messages.last {
                    let content = lastMessage["content"]
                    if let contentStr = content as? String {
                        XCTAssertEqual(contentStr, "Please continue from where you left off.",
                                       "Continuation prompt should match the expected text")
                    } else {
                        XCTFail("Continuation message content should be a string")
                    }
                }
            }
        }
    }
}

// MARK: - AC4: max_tokens Continuation Recovery (Streaming Path)

/// ATDD RED PHASE: Tests for Story 2.4 — max_tokens continuation recovery in stream().
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - max_tokens recovery counter (max 3) is added to stream()
/// TDD Phase: RED (feature not implemented yet)
final class MaxTokensRecoveryStreamTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StreamMockURLProtocol.reset()
    }

    override func tearDown() {
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC4 [P0]: max_tokens x2 then end_turn — stream yields success with accumulated text.
    func testStream_MaxTokensTwice_ThenEndTurn() async throws {
        let sut = makeStreamSUT(maxTurns: 10)

        let sseTurn1 = makeSingleTurnSSEBody(
            textDeltas: ["Part 1"],
            stopReason: "max_tokens",
            inputTokens: 20,
            outputTokens: 100
        )
        let sseTurn2 = makeSingleTurnSSEBody(
            textDeltas: ["Part 2"],
            stopReason: "max_tokens",
            inputTokens: 30,
            outputTokens: 100
        )
        let sseTurn3 = makeSingleTurnSSEBody(
            textDeltas: ["Part 3"],
            stopReason: "end_turn",
            inputTokens: 40,
            outputTokens: 50
        )

        registerSequentialStreamMockResponses([sseTurn1, sseTurn2, sseTurn3])

        let stream = sut.stream("Test stream max_tokens recovery")

        var resultEvent: SDKMessage.ResultData?
        var assistantEvents: [SDKMessage.AssistantData] = []
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
            if case let .assistant(data) = message {
                assistantEvents.append(data)
            }
        }

        XCTAssertNotNil(resultEvent, "Should yield a result event")
        XCTAssertEqual(resultEvent?.subtype, .success,
                       "Should yield success after max_tokens recovery in stream")
        XCTAssertGreaterThanOrEqual(assistantEvents.count, 3,
                                     "Should yield at least 3 assistant events (one per turn)")
    }

    /// AC4 [P0]: max_tokens x4 (exceeds 3 recovery limit) — stream yields success with partial text.
    func testStream_MaxTokensExceedsRecoveryLimit() async throws {
        let sut = makeStreamSUT(maxTurns: 20)

        let sseTurn1 = makeSingleTurnSSEBody(
            textDeltas: ["Part 1"],
            stopReason: "max_tokens",
            inputTokens: 20,
            outputTokens: 100
        )
        let sseTurn2 = makeSingleTurnSSEBody(
            textDeltas: ["Part 2"],
            stopReason: "max_tokens",
            inputTokens: 30,
            outputTokens: 100
        )
        let sseTurn3 = makeSingleTurnSSEBody(
            textDeltas: ["Part 3"],
            stopReason: "max_tokens",
            inputTokens: 40,
            outputTokens: 100
        )
        let sseTurn4 = makeSingleTurnSSEBody(
            textDeltas: ["Part 4"],
            stopReason: "max_tokens",
            inputTokens: 50,
            outputTokens: 100
        )

        registerSequentialStreamMockResponses([sseTurn1, sseTurn2, sseTurn3, sseTurn4])

        let stream = sut.stream("Test stream max_tokens limit")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent, "Should yield a result event")
        XCTAssertEqual(resultEvent?.subtype, .success,
                       "max_tokens recovery exhaustion should yield .success in stream (not .errorDuringExecution)")
        XCTAssertFalse(resultEvent?.text.isEmpty ?? true,
                       "Should contain accumulated partial text")
    }
}

// MARK: - AC5: Non-Transient Errors Not Retried

/// ATDD RED PHASE: Tests for Story 2.4 — Non-transient errors should NOT be retried.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - withRetry is integrated and only retries transient errors
/// TDD Phase: RED (feature not implemented yet)
final class NonRetryableErrorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        RetryMockURLProtocol.reset()
        RetryStreamMockURLProtocol.reset()
    }

    override func tearDown() {
        RetryMockURLProtocol.reset()
        RetryStreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC5 [P0]: HTTP 401 (blocking) — returns error immediately, no retry (1 request total).
    func testPrompt_HTTP401_NoRetry() async throws {
        let sut = makeRetryPromptSUT(apiKey: "sk-test-retry-auth")

        let authError = makeErrorResponse(errorType: "authentication_error", message: "invalid x-api-key")
        registerRetryMockResponses([
            (401, ["content-type": "application/json"], authError),
        ])

        let result = await sut.prompt("Test no retry on 401")

        XCTAssertEqual(result.status, .errorDuringExecution,
                       "HTTP 401 should return errorDuringExecution immediately")
        // Should have sent exactly 1 request (no retry)
        XCTAssertEqual(RetryMockURLProtocol.allRequests.count, 1,
                       "Should send exactly 1 request for non-retryable error (no retry)")
    }

    /// AC5 [P0]: HTTP 403 (blocking) — returns error immediately, no retry (1 request total).
    func testPrompt_HTTP403_NoRetry() async throws {
        let sut = makeRetryPromptSUT()

        let forbiddenError = makeErrorResponse(errorType: "permission_error", message: "Forbidden")
        registerRetryMockResponses([
            (403, ["content-type": "application/json"], forbiddenError),
        ])

        let result = await sut.prompt("Test no retry on 403")

        XCTAssertEqual(result.status, .errorDuringExecution,
                       "HTTP 403 should return errorDuringExecution immediately")
        XCTAssertEqual(RetryMockURLProtocol.allRequests.count, 1,
                       "Should send exactly 1 request for non-retryable error (no retry)")
    }

    /// AC5 [P0]: HTTP 400 (streaming) — returns error immediately, no retry (1 request total).
    func testStream_HTTP400_NoRetry() async throws {
        let sut = makeRetryStreamSUT()

        let badRequestError = makeErrorResponse(errorType: "invalid_request_error", message: "Bad request")
        registerRetryStreamMockResponses([
            (400, ["content-type": "application/json"], badRequestError),
        ])

        let stream = sut.stream("Test no retry on 400 stream")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent, "Should yield a result event")
        XCTAssertEqual(resultEvent?.subtype, .errorDuringExecution,
                       "HTTP 400 in stream should yield errorDuringExecution immediately")
        XCTAssertEqual(RetryStreamMockURLProtocol.allRequests.count, 1,
                       "Should send exactly 1 request for non-retryable stream error (no retry)")
    }

    /// AC5 [P0]: HTTP 401 (streaming) — returns error immediately, no retry.
    func testStream_HTTP401_NoRetry() async throws {
        let sut = makeRetryStreamSUT()

        let authError = makeErrorResponse(errorType: "authentication_error", message: "invalid x-api-key")
        registerRetryStreamMockResponses([
            (401, ["content-type": "application/json"], authError),
        ])

        let stream = sut.stream("Test no retry on 401 stream")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent, "Should yield a result event")
        XCTAssertEqual(resultEvent?.subtype, .errorDuringExecution,
                       "HTTP 401 in stream should yield errorDuringExecution immediately")
        XCTAssertEqual(RetryStreamMockURLProtocol.allRequests.count, 1,
                       "Should send exactly 1 request for non-retryable stream error (no retry)")
    }
}

// MARK: - AC6: API Key Security

/// ATDD RED PHASE: Tests for Story 2.4 — API key is not exposed in error messages.
/// Verifies that the existing AnthropicClient key sanitization works correctly
/// in the context of retry scenarios.
/// TDD Phase: RED (feature not implemented yet)
final class RetryAPIKeySecurityTests: XCTestCase {

    override func setUp() {
        super.setUp()
        RetryMockURLProtocol.reset()
    }

    override func tearDown() {
        RetryMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC6 [P1]: Error messages in retry exhaustion do not contain API key.
    func testRetryExhaustion_ErrorMessageDoesNotContainAPIKey() async throws {
        let testAPIKey = "sk-ant-secret-key-12345-do-not-expose"
        let sut = makeRetryPromptSUT(apiKey: testAPIKey)

        // The error message includes the API key (simulating a poorly sanitized server response)
        let errorWithKey = """
        {"error": {"type": "rate_limit_error", "message": "Key \(testAPIKey) rate limited"}}
        """.data(using: .utf8)!

        // 4 errors to exhaust retries
        registerRetryMockResponses([
            (429, ["content-type": "application/json"], errorWithKey),
            (429, ["content-type": "application/json"], errorWithKey),
            (429, ["content-type": "application/json"], errorWithKey),
            (429, ["content-type": "application/json"], errorWithKey),
        ])

        let result = await sut.prompt("Test API key security on retry exhaustion")

        // The result should not contain the raw API key
        // Note: AnthropicClient.validateHTTPResponse already sanitizes the API key
        // This test verifies the integration — the key should not appear in result text
        XCTAssertFalse(result.text.contains(testAPIKey),
                       "API key should not appear in result text after retry exhaustion")
    }

    /// AC6 [P1]: Error messages from non-transient errors do not contain API key.
    func testNonRetryableError_ErrorMessageDoesNotContainAPIKey() async throws {
        let testAPIKey = "sk-ant-secret-key-67890-do-not-expose"
        let sut = makeRetryPromptSUT(apiKey: testAPIKey)

        let errorWithKey = """
        {"error": {"type": "authentication_error", "message": "Invalid key: \(testAPIKey)"}}
        """.data(using: .utf8)!

        registerRetryMockResponses([
            (401, ["content-type": "application/json"], errorWithKey),
        ])

        let result = await sut.prompt("Test API key security on non-retryable error")

        XCTAssertFalse(result.text.contains(testAPIKey),
                       "API key should not appear in result text for non-retryable errors")
    }
}

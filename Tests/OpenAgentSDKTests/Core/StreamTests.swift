import XCTest
@testable import OpenAgentSDK

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
// MARK: - Mock URL Protocol for Stream Tests

/// Custom URLProtocol subclass that intercepts network requests for stream testing.
/// Supports both SSE-format responses and sequential multi-turn responses.
final class StreamMockURLProtocol: URLProtocol {

    /// Static storage for mock responses keyed by URL string.
    nonisolated(unsafe) static var mockResponses: [String: (statusCode: Int, headers: [String: String], body: Data)] = [:]

    /// Records the last request sent through this protocol for inspection.
    nonisolated(unsafe) static var lastRequest: URLRequest?

    /// Records all requests sent through this protocol (for multi-turn verification).
    nonisolated(unsafe) static var allRequests: [URLRequest] = []

    /// Counter for sequential SSE responses (multi-turn support).
    nonisolated(unsafe) static var sequentialSSEResponses: [Data] = []

    /// Current index into sequential responses.
    nonisolated(unsafe) static var responseIndex: Int = 0

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    /// Whether stopLoading() has been called (task cancelled/finished).
    /// On Linux (FoundationNetworking), the task is removed from the internal TaskRegistry
    /// before stopLoading() is called, so any client call after this will crash.
    private let stopLock = NSLock()
    private var _stopped = false
    private var stopped: Bool {
        get { stopLock.withLock { _stopped } }
        set { stopLock.withLock { _stopped = newValue } }
    }

    override func startLoading() {
        // Capture request with body
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            capturedRequest.httpBody = Self.readBodyFromStream(stream)
        }

        StreamMockURLProtocol.lastRequest = capturedRequest
        StreamMockURLProtocol.allRequests.append(capturedRequest)

        guard !stopped, let activeClient = client else { return }

        // If sequential responses are configured, use them in order
        if !StreamMockURLProtocol.sequentialSSEResponses.isEmpty {
            let index = StreamMockURLProtocol.responseIndex
            if index < StreamMockURLProtocol.sequentialSSEResponses.count {
                let body = StreamMockURLProtocol.sequentialSSEResponses[index]
                StreamMockURLProtocol.responseIndex += 1

                let httpResponse = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["content-type": "text/event-stream"]
                )!

                deliverToClient(activeClient, httpResponse: httpResponse, body: body)
                return
            }
        }

        guard let url = request.url?.absoluteString,
              let mock = StreamMockURLProtocol.mockResponses[url] else {
            let error = NSError(domain: "StreamMockURLProtocol", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No mock response registered for URL: \(request.url?.absoluteString ?? "nil")"
            ])
            if !stopped { activeClient.urlProtocol(self, didFailWithError: error) }
            return
        }

        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: mock.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: mock.headers
        )!

        deliverToClient(activeClient, httpResponse: httpResponse, body: mock.body)
    }

    /// Safely delivers response data to the URLProtocol client.
    /// On Linux (FoundationNetworking), the task registry entry may be removed
    /// before client calls complete. Re-check `stopped` between each client call.
    private func deliverToClient(
        _ activeClient: URLProtocolClient,
        httpResponse: HTTPURLResponse,
        body: Data
    ) {
        guard !stopped else { return }
        activeClient.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        guard !stopped else { return }
        activeClient.urlProtocol(self, didLoad: body)
        guard !stopped else { return }
        activeClient.urlProtocolDidFinishLoading(self)
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

    override func stopLoading() { stopped = true }

    static func reset() {
        mockResponses = [:]
        lastRequest = nil
        allRequests = []
        sequentialSSEResponses = []
        responseIndex = 0
    }
}

// MARK: - Stream Test Helpers

extension XCTestCase {

    /// Creates an Agent configured with StreamMockURLProtocol for stream testing.
    func makeStreamSUT(
        apiKey: String = "sk-test-stream-key-12345",
        model: String = "claude-sonnet-4-6",
        systemPrompt: String? = nil,
        maxTurns: Int = 10,
        maxTokens: Int = 4096
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StreamMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)

        let client = AnthropicClient(apiKey: apiKey, baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            systemPrompt: systemPrompt,
            maxTurns: maxTurns,
            maxTokens: maxTokens,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529])
        )

        return Agent(options: options, client: client)
    }

    /// Builds an SSE response body from individual event/data pairs.
    func buildSSEBody(events: [(event: String, data: String)]) -> Data {
        var body = ""
        for evt in events {
            body += "event: \(evt.event)\n"
            body += "data: \(evt.data)\n\n"
        }
        return Data(body.utf8)
    }

    /// Registers a mock SSE response for the Anthropic API endpoint.
    func registerStreamMockResponse(statusCode: Int = 200, body: Data) {
        StreamMockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: statusCode,
            headers: ["content-type": "text/event-stream"],
            body: body
        )
    }

    /// Registers sequential SSE mock responses for multi-turn stream testing.
    func registerSequentialStreamMockResponses(_ responses: [Data]) {
        StreamMockURLProtocol.sequentialSSEResponses = responses
        StreamMockURLProtocol.responseIndex = 0
    }

    /// Helper: builds a standard single-turn SSE event sequence with the given text deltas
    /// and stop_reason. Returns the SSE body as Data.
    func makeSingleTurnSSEBody(
        textDeltas: [String] = ["Hello world"],
        model: String = "claude-sonnet-4-6",
        stopReason: String = "end_turn",
        inputTokens: Int = 25,
        outputTokens: Int = 10
    ) -> Data {
        var events: [(event: String, data: String)] = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_stream_001","type":"message","role":"assistant","content":[],"model":"\(model)","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":\(inputTokens),"output_tokens":1}}}
                """),
            (event: "content_block_start", data: """
                {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}
                """),
        ]

        for delta in textDeltas {
            events.append((event: "content_block_delta", data: """
                {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\(delta)"}}
                """))
        }

        events.append((event: "content_block_stop", data: """
            {"type":"content_block_stop","index":0}
            """))
        events.append((event: "message_delta", data: """
            {"type":"message_delta","delta":{"stop_reason":"\(stopReason)","stop_sequence":null},"usage":{"output_tokens":\(outputTokens)}}
            """))
        events.append((event: "message_stop", data: """
            {"type":"message_stop"}
            """))

        return buildSSEBody(events: events)
    }
}

// MARK: - AC1: AsyncStream<SDKMessage> Return

/// ATDD RED PHASE: Tests for Story 2.1 -- AsyncStream Streaming Response.
/// All tests assert EXPECTED behavior. They will FAIL until Agent.stream() is implemented.
/// TDD Phase: RED (feature not implemented yet)
final class StreamAsyncStreamTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StreamMockURLProtocol.reset()
    }

    override func tearDown() {
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC1 [P0]: Given an Agent with valid config, when developer calls agent.stream("prompt"),
    /// then an AsyncStream<SDKMessage> is returned immediately and yields SDKMessage events.
    func testStreamReturnsAsyncStreamOfSDKMessage() async throws {
        let sut = makeStreamSUT()
        let sseBody = makeSingleTurnSSEBody(textDeltas: ["Hello", " world"])
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Analyze this code")

        // Collect all events from the stream
        var collectedMessages: [SDKMessage] = []
        for await message in stream {
            collectedMessages.append(message)
        }

        // Should have received at least partialMessage, assistant, and result events
        XCTAssertFalse(collectedMessages.isEmpty,
                       "Stream should yield at least one SDKMessage event")

        // Verify we can pattern-match on SDKMessage cases
        let hasPartial = collectedMessages.contains { if case .partialMessage = $0 { return true } else { return false } }
        let hasAssistant = collectedMessages.contains { if case .assistant = $0 { return true } else { return false } }
        let hasResult = collectedMessages.contains { if case .result = $0 { return true } else { return false } }

        XCTAssertTrue(hasPartial,
                      "Stream should contain .partialMessage events")
        XCTAssertTrue(hasAssistant,
                      "Stream should contain .assistant event")
        XCTAssertTrue(hasResult,
                      "Stream should contain .result event")
    }

    /// AC1 [P2]: stream() with empty string prompt returns a valid stream without crashing.
    func testStreamWithEmptyStringReturnsStream() async throws {
        let sut = makeStreamSUT()
        let sseBody = makeSingleTurnSSEBody(textDeltas: ["You sent an empty message."])
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("")

        var collectedMessages: [SDKMessage] = []
        for await message in stream {
            collectedMessages.append(message)
        }

        XCTAssertFalse(collectedMessages.isEmpty,
                        "Stream should yield events even with empty prompt")
    }
}

// MARK: - AC2: Typed Event Stream

final class StreamTypedEventTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StreamMockURLProtocol.reset()
    }

    override func tearDown() {
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC2 [P0]: Given an active stream, content_block_delta events yield .partialMessage with text increment.
    func testStreamYieldsPartialMessageEvents() async throws {
        let sut = makeStreamSUT()
        let sseBody = makeSingleTurnSSEBody(textDeltas: ["Hello", " world"])
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Test partial")

        var partialTexts: [String] = []
        for await message in stream {
            if case let .partialMessage(data) = message {
                partialTexts.append(data.text)
            }
        }

        XCTAssertEqual(partialTexts.count, 2,
                       "Should yield exactly 2 partialMessage events")
        XCTAssertEqual(partialTexts[0], "Hello",
                       "First partial should be 'Hello'")
        XCTAssertEqual(partialTexts[1], " world",
                       "Second partial should be ' world'")
    }

    /// AC2 [P0]: Given an active stream, message_stop yields .assistant with accumulated text, model, stopReason.
    func testStreamYieldsAssistantEventOnMessageStop() async throws {
        let sut = makeStreamSUT()
        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Swift", " concurrency"],
            model: "claude-sonnet-4-6",
            stopReason: "end_turn"
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Explain async")

        var assistantEvent: SDKMessage.AssistantData?
        for await message in stream {
            if case let .assistant(data) = message {
                assistantEvent = data
            }
        }

        XCTAssertNotNil(assistantEvent,
                        "Should yield an .assistant event")
        XCTAssertEqual(assistantEvent?.text, "Swift concurrency",
                       "Assistant text should be the accumulated full text")
        XCTAssertEqual(assistantEvent?.model, "claude-sonnet-4-6",
                       "Assistant model should match the model from message_start")
        XCTAssertEqual(assistantEvent?.stopReason, "end_turn",
                       "Assistant stopReason should match the stop_reason from message_delta")
    }
}

// MARK: - AC3: Error Events

final class StreamErrorEventTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StreamMockURLProtocol.reset()
    }

    override func tearDown() {
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC3 [P0]: Given an API HTTP error (500), the stream yields .result(subtype: .errorDuringExecution).
    func testStreamYieldsErrorResultOnHTTPError() async throws {
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

        let stream = sut.stream("Trigger server error")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent,
                        "Should yield a .result event even on HTTP error")
        XCTAssertEqual(resultEvent?.subtype, .errorDuringExecution,
                       "Error result subtype should be .errorDuringExecution")
    }

    /// AC3 [P0]: Given an SSE error event in the stream, the stream yields .result(subtype: .errorDuringExecution).
    func testStreamYieldsErrorResultOnSSEErrorEvent() async throws {
        let sut = makeStreamSUT()

        let sseEvents: [(event: String, data: String)] = [
            (event: "message_start", data: """
                {"type":"message_start","message":{"id":"msg_001","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}
                """),
            (event: "error", data: """
                {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}
                """),
        ]
        registerStreamMockResponse(body: buildSSEBody(events: sseEvents))

        let stream = sut.stream("Trigger SSE error")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent,
                        "Should yield a .result event on SSE error event")
        XCTAssertEqual(resultEvent?.subtype, .errorDuringExecution,
                       "SSE error should produce .errorDuringExecution subtype")
    }

    /// AC3 [P0]: Given an error, the stream terminates gracefully (does not hang).
    func testStreamGracefullyTerminatesOnError() async throws {
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

        let stream = sut.stream("Test graceful termination")

        // If stream does not terminate, this loop will hang and the test will timeout
        var messageCount = 0
        for await _ in stream {
            messageCount += 1
        }

        // Stream should have terminated (loop completed)
        XCTAssertGreaterThanOrEqual(messageCount, 1,
                                     "Stream should yield at least a result event before terminating")
    }
}

// MARK: - AC4: end_turn Termination

final class StreamEndTurnTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StreamMockURLProtocol.reset()
    }

    override func tearDown() {
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC4 [P0]: Given stop_reason="end_turn", the stream yields .result(subtype: .success) and terminates.
    func testStreamYieldsResultEventOnEndTurn() async throws {
        let sut = makeStreamSUT()
        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Complete answer."],
            stopReason: "end_turn"
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Give me an answer")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent,
                        "Should yield a .result event on end_turn")
        XCTAssertEqual(resultEvent?.subtype, .success,
                       "end_turn should produce .success subtype")
    }

    /// AC4 [P0]: After end_turn, the stream terminates (iteration completes without hang).
    func testStreamTerminatesOnEndTurn() async throws {
        let sut = makeStreamSUT()
        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Done."],
            stopReason: "end_turn"
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Quick question")

        // This loop must complete without hanging
        var collectedMessages: [SDKMessage] = []
        for await message in stream {
            collectedMessages.append(message)
        }

        // Stream should have ended after result
        let lastMessage = collectedMessages.last
        XCTAssertNotNil(lastMessage,
                        "Stream should have at least one message")

        if case let .result(data) = lastMessage {
            XCTAssertEqual(data.subtype, .success)
        } else {
            XCTFail("Last message should be a .result event")
        }
    }
}

// MARK: - AC5: maxTurns Limit

final class StreamMaxTurnsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StreamMockURLProtocol.reset()
    }

    override func tearDown() {
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC5 [P0]: Given maxTurns=2, when the stream loop reaches 2 turns,
    /// the stream yields .result(subtype: .errorMaxTurns) and terminates.
    func testStreamMaxTurnsLimitEmitsErrorMaxTurns() async throws {
        let sut = makeStreamSUT(maxTurns: 2)

        // First turn: stop_reason is NOT end_turn (forces loop to continue)
        let sseTurn1 = makeSingleTurnSSEBody(
            textDeltas: ["Continuing..."],
            stopReason: "max_tokens",
            inputTokens: 20,
            outputTokens: 50
        )

        // Second turn: also NOT end_turn (loop will hit maxTurns)
        let sseTurn2 = makeSingleTurnSSEBody(
            textDeltas: ["Still going..."],
            stopReason: "max_tokens",
            inputTokens: 30,
            outputTokens: 60
        )

        registerSequentialStreamMockResponses([sseTurn1, sseTurn2])

        let stream = sut.stream("Multi-turn query")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent,
                        "Should yield a .result event when maxTurns is reached")
        XCTAssertEqual(resultEvent?.subtype, .errorMaxTurns,
                       "Reaching maxTurns should produce .errorMaxTurns subtype")
        XCTAssertEqual(resultEvent?.numTurns, 2,
                       "Should report exactly 2 turns when maxTurns=2 is reached")
    }
}

// MARK: - AC6: Usage Statistics

final class StreamUsageStatsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StreamMockURLProtocol.reset()
    }

    override func tearDown() {
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC6 [P0]: Given a completed stream, the result event contains accumulated usage tokens.
    func testStreamResultContainsAccumulatedUsage() async throws {
        let sut = makeStreamSUT()
        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Token counting test."],
            stopReason: "end_turn",
            inputTokens: 42,
            outputTokens: 15
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Count my tokens")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent, "Should have a result event")
        XCTAssertNotNil(resultEvent?.usage, "Result should contain usage")
        XCTAssertEqual(resultEvent?.usage?.inputTokens, 42,
                       "Result usage should contain inputTokens from API response")
        XCTAssertEqual(resultEvent?.usage?.outputTokens, 15,
                       "Result usage should contain outputTokens from API response")
    }

    /// AC6 [P1]: Given a completed stream, the result event contains correct numTurns.
    func testStreamResultContainsNumTurns() async throws {
        let sut = makeStreamSUT()
        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Single turn."],
            stopReason: "end_turn"
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("One turn only")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertEqual(resultEvent?.numTurns, 1,
                       "Single-turn stream should report numTurns = 1")
    }

    /// AC6 [P1]: Given a completed stream, the result event contains non-negative durationMs.
    func testStreamResultContainsDurationMs() async throws {
        let sut = makeStreamSUT()
        let sseBody = makeSingleTurnSSEBody(
            textDeltas: ["Timed."],
            stopReason: "end_turn"
        )
        registerStreamMockResponse(body: sseBody)

        let stream = sut.stream("Time me")

        var resultEvent: SDKMessage.ResultData?
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
        }

        XCTAssertNotNil(resultEvent, "Should have a result event")
        XCTAssertGreaterThanOrEqual(resultEvent?.durationMs ?? -1, 0,
                                     "durationMs should be non-negative")
    }
}

// MARK: - AC7: stream/prompt API Consistency

final class StreamAPISignatureTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StreamMockURLProtocol.reset()
    }

    override func tearDown() {
        StreamMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC7 [P1]: Given an Agent, both stream() and prompt() accept the same parameter signature.
    /// They differ only in return type: AsyncStream<SDKMessage> vs QueryResult.
    func testStreamAndPromptHaveMatchingParameterSignatures() async throws {
        let sut = makeStreamSUT()
        let sseBody = makeSingleTurnSSEBody(textDeltas: ["Response"])
        registerStreamMockResponse(body: sseBody)

        // Both methods should accept just a String parameter
        // prompt() returns QueryResult
        let promptResult: QueryResult = await sut.prompt("test prompt")
        XCTAssertNotNil(promptResult, "prompt() should return a QueryResult")

        // stream() returns AsyncStream<SDKMessage>
        let streamResult: AsyncStream<SDKMessage> = sut.stream("test prompt")

        // Verify stream is usable
        var streamMessages: [SDKMessage] = []
        for await message in streamResult {
            streamMessages.append(message)
        }
        XCTAssertFalse(streamMessages.isEmpty,
                        "stream() should yield SDKMessage events")

        // Compile-time check: both accept String, both are callable on Agent
        // If this compiles, the signatures are consistent
    }
}

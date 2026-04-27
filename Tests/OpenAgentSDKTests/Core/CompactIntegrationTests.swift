import XCTest
@testable import OpenAgentSDK

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
// MARK: - Mock URL Protocol for Compact Integration Tests

/// Custom URLProtocol that supports sequential responses for integration testing
/// of auto-compaction within the Agent loop. The compaction LLM call and subsequent
/// main loop calls all go through this single protocol.
final class CompactIntegrationMockURLProtocol: URLProtocol {

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

        CompactIntegrationMockURLProtocol.allRequests.append(capturedRequest)

        let index = CompactIntegrationMockURLProtocol.responseIndex
        if index < CompactIntegrationMockURLProtocol.sequentialResponses.count {
            let response = CompactIntegrationMockURLProtocol.sequentialResponses[index]
            CompactIntegrationMockURLProtocol.responseIndex += 1

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
                domain: "CompactIntegrationMockURLProtocol",
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

    override func stopLoading() {}

    static func reset() {
        sequentialResponses = []
        responseIndex = 0
        allRequests = []
    }
}

// MARK: - Integration Test Helpers

extension XCTestCase {

    /// Creates an Agent configured with CompactIntegrationMockURLProtocol.
    func makeCompactIntegrationSUT(
        apiKey: String = "sk-test-compact-int-key-12345",
        model: String = "claude-sonnet-4-6",
        maxTurns: Int = 10
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [CompactIntegrationMockURLProtocol.self]
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

    /// Builds a compaction LLM success response.
    func makeIntegrationCompactionResponse(summary: String) -> Data {
        let response: [String: Any] = [
            "id": "msg_compact_int",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": summary]],
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "stop_sequence": NSNull(),
            "usage": ["input_tokens": 500, "output_tokens": 200]
        ]
        return try! JSONSerialization.data(withJSONObject: response, options: [])
    }

    /// Builds a main loop success response (after compaction).
    func makeIntegrationMainResponse(text: String) -> Data {
        let response: [String: Any] = [
            "id": "msg_main_after_compact",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": text]],
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "stop_sequence": NSNull(),
            "usage": ["input_tokens": 30, "output_tokens": 15]
        ]
        return try! JSONSerialization.data(withJSONObject: response, options: [])
    }

    /// Registers sequential mock responses for compact integration testing.
    func registerCompactIntegrationMockResponses(_ responses: [(statusCode: Int, headers: [String: String], body: Data)]) {
        CompactIntegrationMockURLProtocol.sequentialResponses = responses
        CompactIntegrationMockURLProtocol.responseIndex = 0
    }
}

// MARK: - AC1: Auto-Compact Trigger in prompt() (Blocking Path)

/// ATDD RED PHASE: Integration tests for Story 2.5 -- Auto compaction in Agent loops.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Utils/Compact.swift` is created with compaction functions
///   - `Agent.prompt()` checks shouldAutoCompact before API call
///   - `Agent.stream()` checks shouldAutoCompact and emits .system(.compactBoundary)
/// TDD Phase: RED (feature not implemented yet)
final class CompactPromptIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CompactIntegrationMockURLProtocol.reset()
    }

    override func tearDown() {
        CompactIntegrationMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC1 [P0]: prompt() triggers compaction when messages exceed threshold,
    /// then proceeds with compacted messages.
    func testPrompt_TriggersCompaction_WhenTokensExceedThreshold() async throws {
        let sut = makeCompactIntegrationSUT()

        // Build a prompt that will create oversized messages.
        // The threshold is 187,000 tokens for claude-sonnet-4-6.
        // We need the INITIAL message to exceed the threshold.
        // 187,000 tokens * 4 chars/token = 748,000 characters
        let threshold = getAutoCompactThreshold(model: "claude-sonnet-4-6")
        let oversizedContent = String(repeating: "x", count: (threshold + 10_000) * 4)

        // Response 1: Compaction LLM call returns a summary
        // Response 2: Main loop call with compacted messages returns success
        registerCompactIntegrationMockResponses([
            (200, ["content-type": "application/json"],
             makeIntegrationCompactionResponse(summary: "Summary of long conversation.")),
            (200, ["content-type": "application/json"],
             makeIntegrationMainResponse(text: "Continuing after compaction.")),
        ])

        let result = await sut.prompt(oversizedContent)

        XCTAssertEqual(result.status, .success,
                       "Should return success after compaction + main loop call")
        XCTAssertTrue(result.text.contains("Continuing after compaction."),
                      "Should contain the response from after compaction")

        // Should have sent 2 requests: 1 compaction + 1 main loop
        XCTAssertGreaterThanOrEqual(CompactIntegrationMockURLProtocol.allRequests.count, 2,
                                     "Should have sent at least 2 requests (compaction + main loop)")
    }
}

// MARK: - AC2: Auto-Compact Trigger in stream() (Streaming Path)

final class CompactStreamIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CompactIntegrationMockURLProtocol.reset()
    }

    override func tearDown() {
        CompactIntegrationMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC2 [P0]: stream() triggers compaction when messages exceed threshold,
    /// then proceeds with compacted messages.
    func testStream_TriggersCompaction_WhenTokensExceedThreshold() async throws {
        let sut = makeCompactIntegrationSUT()

        let threshold = getAutoCompactThreshold(model: "claude-sonnet-4-6")
        let oversizedContent = String(repeating: "x", count: (threshold + 10_000) * 4)

        // Response 1: Compaction LLM call (blocking, returns JSON)
        // Response 2: Main loop SSE stream call
        let sseMainBody = makeSingleTurnSSEBody(
            textDeltas: ["Continuing after compact"],
            stopReason: "end_turn",
            inputTokens: 25,
            outputTokens: 10
        )

        registerCompactIntegrationMockResponses([
            (200, ["content-type": "application/json"],
             makeIntegrationCompactionResponse(summary: "Stream conversation summary.")),
            (200, ["content-type": "text/event-stream"],
             sseMainBody),
        ])

        let stream = sut.stream(oversizedContent)

        var resultEvent: SDKMessage.ResultData?
        var systemEvents: [SDKMessage.SystemData] = []
        for await message in stream {
            if case let .result(data) = message {
                resultEvent = data
            }
            if case let .system(data) = message {
                systemEvents.append(data)
            }
        }

        XCTAssertNotNil(resultEvent,
                         "Should yield a result event after stream compaction")
        XCTAssertEqual(resultEvent?.subtype, .success,
                       "Should yield success after compaction + stream")
    }

    /// AC3 [P0]: stream() emits .system(.compactBoundary) event after compaction.
    func testStream_EmitsCompactBoundaryEvent_AfterCompaction() async throws {
        let sut = makeCompactIntegrationSUT()

        let threshold = getAutoCompactThreshold(model: "claude-sonnet-4-6")
        let oversizedContent = String(repeating: "x", count: (threshold + 10_000) * 4)

        let sseMainBody = makeSingleTurnSSEBody(
            textDeltas: ["Post-compact response"],
            stopReason: "end_turn",
            inputTokens: 25,
            outputTokens: 10
        )

        registerCompactIntegrationMockResponses([
            (200, ["content-type": "application/json"],
             makeIntegrationCompactionResponse(summary: "Boundary test summary.")),
            (200, ["content-type": "text/event-stream"],
             sseMainBody),
        ])

        let stream = sut.stream(oversizedContent)

        var systemEvents: [SDKMessage.SystemData] = []
        for await message in stream {
            if case let .system(data) = message {
                systemEvents.append(data)
            }
        }

        // Should emit at least one compactBoundary system event
        let compactBoundaryEvents = systemEvents.filter { $0.subtype == .compactBoundary }
        XCTAssertGreaterThanOrEqual(compactBoundaryEvents.count, 1,
                                     "Should emit at least one .system(.compactBoundary) event during stream compaction")
    }
}

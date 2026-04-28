import XCTest
@testable import OpenAgentSDK

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
// MARK: - Mock URL Protocol for Micro-Compact Integration Tests

/// Custom URLProtocol that supports sequential responses for integration testing
/// of micro-compaction within the Agent loop. Compaction LLM calls and main loop
/// calls all go through this single protocol.
final class MicroCompactIntegrationMockURLProtocol: URLProtocol {

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
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            capturedRequest.httpBody = Self.readBodyFromStream(stream)
        }

        MicroCompactIntegrationMockURLProtocol.allRequests.append(capturedRequest)

        guard !stopped, let activeClient = client else { return }

        let index = MicroCompactIntegrationMockURLProtocol.responseIndex
        if index < MicroCompactIntegrationMockURLProtocol.sequentialResponses.count {
            let response = MicroCompactIntegrationMockURLProtocol.sequentialResponses[index]
            MicroCompactIntegrationMockURLProtocol.responseIndex += 1

            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            )!

            deliverToClient(activeClient, httpResponse: httpResponse, body: response.body)
        } else {
            let error = NSError(
                domain: "MicroCompactIntegrationMockURLProtocol",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No more mock responses (index: \(index))"]
            )
            if !stopped { activeClient.urlProtocol(self, didFailWithError: error) }
        }
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
        sequentialResponses = []
        responseIndex = 0
        allRequests = []
    }
}

// MARK: - Integration Test Helpers

extension XCTestCase {

    /// Creates an Agent configured with MicroCompactIntegrationMockURLProtocol.
    func makeMicroCompactIntegrationSUT(
        apiKey: String = "sk-test-micro-compact-key-12345",
        model: String = "claude-sonnet-4-6",
        maxTurns: Int = 10
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MicroCompactIntegrationMockURLProtocol.self]
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

    /// Builds a micro-compaction LLM success response.
    func makeMicroCompactResponse(summary: String) -> Data {
        let response: [String: Any] = [
            "id": "msg_micro_compact_int",
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

    /// Builds a main loop success response (blocking JSON).
    func makeMicroCompactMainResponse(text: String) -> Data {
        let response: [String: Any] = [
            "id": "msg_main_after_micro_compact",
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

    /// Registers sequential mock responses for micro-compact integration testing.
    func registerMicroCompactIntegrationMockResponses(
        _ responses: [(statusCode: Int, headers: [String: String], body: Data)]
    ) {
        MicroCompactIntegrationMockURLProtocol.sequentialResponses = responses
        MicroCompactIntegrationMockURLProtocol.responseIndex = 0
    }
}

// MARK: - AC1: Micro-Compact in prompt() (Blocking Path)

/// ATDD RED PHASE: Integration tests for Story 2.6 -- Micro-compaction in Agent loops.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Utils/Compact.swift` has microCompact, shouldMicroCompact functions
///   - `Agent.prompt()` checks tool results before adding to messages
///   - `Agent.stream()` checks tool results and emits .system(.status) event
/// TDD Phase: RED (feature not implemented yet)
///
/// **PENDING EPIC 3:** These tests require tool execution in the agent loop,
/// which is implemented in Epic 3. The `processToolResult()` helper is in place
/// (Story 2.6), but the agent loop doesn't handle `stop_reason: "tool_use"` yet.
final class MicroCompactPromptIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MicroCompactIntegrationMockURLProtocol.reset()
    }

    override func tearDown() {
        MicroCompactIntegrationMockURLProtocol.reset()
        super.tearDown()
    }

    /// Test that processToolResult micro-compacts large content via the Agent helper.
    /// This directly tests the integration point added to Agent.swift.
    func testProcessToolResult_CompactsLargeContent() async throws {
        let sut = makeMicroCompactIntegrationSUT()

        let largeContent = String(repeating: "file line\n", count: 6_000) // ~60,000 chars
        let summary = "Compressed file: 6000 lines summarized"
        let responseData = makeMicroCompactResponse(summary: summary)

        registerMicroCompactIntegrationMockResponses([
            (200, ["content-type": "application/json"], responseData),
        ])

        let result = await sut.processToolResult(largeContent, isError: false)

        XCTAssertTrue(result.hasPrefix("[微压缩]"),
                      "processToolResult should return micro-compacted content with [微压缩] marker")
        XCTAssertTrue(result.contains(summary),
                      "Result should contain the LLM summary")
    }

    /// Test that processToolResult preserves content below threshold.
    func testProcessToolResult_PreservesContentBelowThreshold() async throws {
        let sut = makeMicroCompactIntegrationSUT()

        let smallContent = String(repeating: "x", count: 49_999)

        let result = await sut.processToolResult(smallContent, isError: false)

        XCTAssertEqual(result, smallContent,
                       "Content below threshold should be returned unchanged")
    }

    /// Test that processToolResult preserves error results regardless of size.
    func testProcessToolResult_PreservesErrorResults() async throws {
        let sut = makeMicroCompactIntegrationSUT()

        let largeError = "Error: " + String(repeating: "e", count: 55_000)

        let result = await sut.processToolResult(largeError, isError: true)

        XCTAssertEqual(result, largeError,
                       "Error results should never be micro-compacted")
    }

    /// AC1 [P0]: prompt() triggers micro-compaction when a tool result exceeds threshold,
    /// then the compacted result is added to messages instead of the full content.
    ///
    /// **PENDING EPIC 3:** Requires tool execution in the agent loop.
    func testPrompt_MicroCompactsLargeToolResult_BeforeAddingToMessages() async throws {
        throw XCTSkip("Requires Epic 3 tool execution in agent loop. processToolResult() is in place.")
    }

    /// AC2 [P0]: prompt() does NOT trigger micro-compaction for tool results below threshold.
    ///
    /// **PENDING EPIC 3:** Requires tool execution in the agent loop.
    func testPrompt_DoesNotCompactBelowThreshold() async throws {
        throw XCTSkip("Requires Epic 3 tool execution in agent loop. processToolResult() is in place.")
    }
}

// MARK: - AC1, AC4: Micro-Compact in stream() (Streaming Path)

final class MicroCompactStreamIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MicroCompactIntegrationMockURLProtocol.reset()
    }

    override func tearDown() {
        MicroCompactIntegrationMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC1 [P0]: stream() triggers micro-compaction when tool result exceeds threshold
    /// and emits a .system(.status) event to notify the consumer.
    ///
    /// **PENDING EPIC 3:** Requires tool execution in the agent loop.
    func testStream_MicroCompactsLargeToolResult_AndEmitsStatusEvent() async throws {
        throw XCTSkip("Requires Epic 3 tool execution in agent loop. processToolResult() is in place.")
    }

    /// AC4 [P0]: stream() preserves original content when micro-compact LLM fails.
    ///
    /// **PENDING EPIC 3:** Requires tool execution in the agent loop.
    func testStream_PreservesOriginal_OnCompactFailure() async throws {
        throw XCTSkip("Requires Epic 3 tool execution in agent loop. processToolResult() is in place.")
    }
}

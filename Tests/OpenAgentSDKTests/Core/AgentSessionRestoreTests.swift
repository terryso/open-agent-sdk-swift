import XCTest
@testable import OpenAgentSDK

// MARK: - Mock URL Protocol for Session Restore Tests

/// Custom URLProtocol subclass that intercepts network requests for session restore testing.
/// Allows injecting predefined API responses and inspecting outbound requests.
final class SessionRestoreMockURLProtocol: URLProtocol {

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
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            capturedRequest.httpBody = Self.readBodyFromStream(stream)
        }

        SessionRestoreMockURLProtocol.lastRequest = capturedRequest
        SessionRestoreMockURLProtocol.allRequests.append(capturedRequest)

        // If sequential responses are configured, use them in order
        if !SessionRestoreMockURLProtocol.sequentialResponses.isEmpty {
            let index = SessionRestoreMockURLProtocol.responseIndex
            if index < SessionRestoreMockURLProtocol.sequentialResponses.count {
                let responseData = SessionRestoreMockURLProtocol.sequentialResponses[index]
                SessionRestoreMockURLProtocol.responseIndex += 1

                guard let body = try? JSONSerialization.data(withJSONObject: responseData, options: []) else {
                    client?.urlProtocol(self, didFailWithError: NSError(domain: "SessionRestoreMockURLProtocol", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize mock response"]))
                    return
                }
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
              let mock = SessionRestoreMockURLProtocol.mockResponses[url] else {
            let error = NSError(domain: "SessionRestoreMockURLProtocol", code: -1, userInfo: [
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

    /// Creates an Agent configured with MockURLProtocol for session restore testing.
    /// Optionally injects a SessionStore and sessionId via AgentOptions.
    func makeSessionRestoreSUT(
        apiKey: String = "sk-test-session-restore-12345",
        model: String = "claude-sonnet-4-6",
        systemPrompt: String? = nil,
        maxTurns: Int = 10,
        maxTokens: Int = 4096,
        sessionStore: SessionStore? = nil,
        sessionId: String? = nil
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [SessionRestoreMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)

        let client = AnthropicClient(apiKey: apiKey, baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            systemPrompt: systemPrompt,
            maxTurns: maxTurns,
            maxTokens: maxTokens,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529]),
            sessionStore: sessionStore,
            sessionId: sessionId
        )

        return Agent(options: options, client: client)
    }

    /// Builds a standard non-streaming Anthropic API response JSON for session restore tests.
    func makeSessionRestoreResponse(
        id: String = "msg_restore_001",
        model: String = "claude-sonnet-4-6",
        content: [[String: Any]] = [["type": "text", "text": "Restored session response"]],
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
    func sessionRestoreJsonData(from dict: [String: Any]) -> Data {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
            fatalError("sessionRestoreJsonData: failed to serialize dictionary - input was not JSON-compatible")
        }
        return data
    }

    /// Registers a mock response for the Anthropic API endpoint.
    func registerSessionRestoreMockResponse(statusCode: Int = 200, body: Data) {
        SessionRestoreMockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: statusCode,
            headers: ["content-type": "application/json"],
            body: body
        )
    }

    /// Registers sequential mock responses for multi-turn session restore testing.
    func registerSequentialSessionRestoreMockResponses(_ responses: [[String: Any]]) {
        SessionRestoreMockURLProtocol.sequentialResponses = responses
        SessionRestoreMockURLProtocol.responseIndex = 0
    }
}

// MARK: - AC1: Agent.prompt() with sessionId Restores History

/// ATDD RED PHASE: Tests for Story 7.2 -- Session Load & Restore.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `AgentOptions` adds `sessionStore` and `sessionId` properties
///   - `Agent.prompt()` implements session restore logic
///   - `Agent.stream()` implements session restore logic
///   - Auto-save after prompt/stream is implemented
/// TDD Phase: RED (feature not implemented yet)
final class AgentPromptSessionRestoreTests: XCTestCase {

    // MARK: - Properties

    private var tempDir: String!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        SessionRestoreMockURLProtocol.reset()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("session-restore-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        SessionRestoreMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC1 [P0]: Given a saved session with prior messages, when developer calls
    /// agent.prompt(text, sessionId: "existing-id") with a sessionStore configured,
    /// then the messages sent to the LLM include the restored history plus the new user message.
    func testPrompt_withSessionId_restoresHistory() async throws {
        // Given: a pre-saved session with conversation history
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "restore-prompt-\(UUID().uuidString)"
        let historyMessages: [[String: Any]] = [
            ["role": "user", "content": "What is Swift?"],
            ["role": "assistant", "content": [
                ["type": "text", "text": "Swift is a programming language by Apple."]
            ] as [[String: Any]]],
        ]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: historyMessages, metadata: metadata)

        // Set up mock LLM response
        let responseDict = makeSessionRestoreResponse(
            content: [["type": "text", "text": "Swift supports concurrency via async/await."]],
            stopReason: "end_turn"
        )
        registerSessionRestoreMockResponse(body: sessionRestoreJsonData(from: responseDict))

        // When: calling prompt with sessionStore and sessionId
        let agent = makeSessionRestoreSUT(sessionStore: store, sessionId: sessionId)
        let result = await agent.prompt("Tell me more about Swift concurrency")

        // Then: the LLM should have received the restored history + new message
        // Inspect the request body to verify message history was included
        let lastRequest = SessionRestoreMockURLProtocol.lastRequest
        XCTAssertNotNil(lastRequest, "A request should have been sent to the LLM API")

        if let bodyData = lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let messages = body["messages"] as? [[String: Any]] {

            // The restored history (2 messages) + the new user message = 3 messages
            // This assertion WILL FAIL until session restore is implemented in prompt()
            XCTAssertGreaterThanOrEqual(messages.count, 3,
                "Messages should include restored history (2) plus new user message (1), got \(messages.count)")

            // First message should be from the restored history
            XCTAssertEqual(messages[0]["role"] as? String, "user",
                "First message should be the restored user message")
        }

        // The result should contain the LLM response
        XCTAssertEqual(result.status, .success,
            "Prompt with restored session should succeed")
        XCTAssertEqual(result.text, "Swift supports concurrency via async/await.",
            "Response should contain the assistant's text")
    }

    /// AC4 [P0]: Given a non-existent sessionId, when developer calls
    /// agent.prompt(text, sessionId: "nonexistent"), then the agent starts
    /// from an empty conversation (same as no sessionId), no error thrown, no crash.
    func testPrompt_nonexistentSessionId_startsFresh() async throws {
        // Given: a SessionStore with NO saved session for this sessionId
        let store = SessionStore(sessionsDir: tempDir)

        // Set up mock LLM response
        let responseDict = makeSessionRestoreResponse(
            content: [["type": "text", "text": "Fresh conversation response"]],
            stopReason: "end_turn"
        )
        registerSessionRestoreMockResponse(body: sessionRestoreJsonData(from: responseDict))

        // When: calling prompt with a non-existent sessionId
        let agent = makeSessionRestoreSUT(
            sessionStore: store,
            sessionId: "nonexistent-session-\(UUID().uuidString)"
        )
        let result = await agent.prompt("Hello from fresh conversation")

        // Then: the agent should behave as if no sessionId was provided
        // No crash, no error -- starts from empty conversation
        XCTAssertEqual(result.status, .success,
            "Prompt with non-existent sessionId should succeed (fresh start)")
        XCTAssertEqual(result.text, "Fresh conversation response",
            "Response should contain the assistant's text")

        // Verify the messages sent to LLM only contain the new user message (no history)
        if let bodyData = SessionRestoreMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let messages = body["messages"] as? [[String: Any]] {

            // Only 1 message (the new user message) since no history was restored
            XCTAssertEqual(messages.count, 1,
                "Messages should only contain the new user message for non-existent sessionId, got \(messages.count)")
        }
    }

    /// AC5 [P0]: Given a completed prompt() with sessionStore configured, when the prompt
    /// finishes, then sessionStore.save() is automatically called to persist updated messages.
    func testPrompt_autoSave_updatesPersistedData() async throws {
        // Given: a pre-saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "autosave-prompt-\(UUID().uuidString)"
        let historyMessages: [[String: Any]] = [
            ["role": "user", "content": "First question"],
            ["role": "assistant", "content": [["type": "text", "text": "First answer"]] as [[String: Any]]],
        ]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: historyMessages, metadata: metadata)

        // Set up mock LLM response
        let responseDict = makeSessionRestoreResponse(
            content: [["type": "text", "text": "Second answer"]],
            stopReason: "end_turn"
        )
        registerSessionRestoreMockResponse(body: sessionRestoreJsonData(from: responseDict))

        // When: calling prompt with sessionStore and sessionId
        let agent = makeSessionRestoreSUT(sessionStore: store, sessionId: sessionId)
        _ = await agent.prompt("Second question")

        // Then: the session should be auto-saved with updated messages
        // The persisted session should now have more messages than the original 2
        let loaded = try await store.load(sessionId: sessionId)

        // This assertion WILL FAIL until auto-save is implemented
        XCTAssertNotNil(loaded, "Session should still exist after auto-save")
        // After restore + new interaction: 2 history + 1 new user + 1 assistant = 4 messages
        XCTAssertGreaterThan(loaded?.messages.count ?? 0, 2,
            "Auto-saved session should have more messages than original history")
    }
}

// MARK: - AC2: Agent.stream() with sessionId Restores History

final class AgentStreamSessionRestoreTests: XCTestCase {

    // MARK: - Properties

    private var tempDir: String!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        SessionRestoreMockURLProtocol.reset()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("stream-restore-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        SessionRestoreMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC2 [P0]: Given a saved session, when developer calls agent.stream(text, sessionId:)
    /// with a sessionStore configured, then the stream events reflect the restored context
    /// and the messages include restored history plus new user message.
    func testStream_withSessionId_restoresHistory() async throws {
        // Given: a pre-saved session with conversation history
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "restore-stream-\(UUID().uuidString)"
        let historyMessages: [[String: Any]] = [
            ["role": "user", "content": "Explain async/await"],
            ["role": "assistant", "content": [["type": "text", "text": "async/await enables structured concurrency."]] as [[String: Any]]],
        ]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: historyMessages, metadata: metadata)

        // Set up mock SSE response
        let sseResponse = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_stream_restore","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":30,"output_tokens":0}}}

        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"AsyncStream is a key part of Swift concurrency."}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":0}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":20}}

        event: message_stop
        data: {"type":"message_stop"}
        """
        let sseData = sseResponse.data(using: .utf8)!
        SessionRestoreMockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: sseData
        )

        // When: calling stream with sessionStore and sessionId
        let agent = makeSessionRestoreSUT(sessionStore: store, sessionId: sessionId)
        let stream = agent.stream("Tell me about AsyncStream")

        // Collect stream events
        var events: [SDKMessage] = []
        for await event in stream {
            events.append(event)
        }

        // Then: stream should produce events with restored context
        XCTAssertFalse(events.isEmpty,
            "Stream should produce SDKMessage events")

        // Verify at least one result event was received
        let resultEvents = events.compactMap { event -> SDKMessage.ResultData? in
            if case .result(let data) = event { return data }
            return nil
        }
        XCTAssertFalse(resultEvents.isEmpty,
            "Stream should produce at least one result event")

        // Verify the LLM received restored history + new message
        if let bodyData = SessionRestoreMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let messages = body["messages"] as? [[String: Any]] {

            // This assertion WILL FAIL until stream session restore is implemented
            XCTAssertGreaterThanOrEqual(messages.count, 3,
                "Stream messages should include restored history (2) plus new user message (1), got \(messages.count)")
        }
    }

    /// AC4 [P0]: Given a non-existent sessionId, when developer calls
    /// agent.stream(text, sessionId: "nonexistent"), then the agent starts from empty
    /// conversation, no error, no crash.
    func testStream_nonexistentSessionId_startsFresh() async throws {
        // Given: a SessionStore with NO saved session
        let store = SessionStore(sessionsDir: tempDir)

        // Set up mock SSE response
        let sseResponse = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_stream_fresh","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}

        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Fresh stream response"}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":0}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":5}}

        event: message_stop
        data: {"type":"message_stop"}
        """
        let sseData = sseResponse.data(using: .utf8)!
        SessionRestoreMockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: sseData
        )

        // When: calling stream with a non-existent sessionId
        let agent = makeSessionRestoreSUT(
            sessionStore: store,
            sessionId: "nonexistent-stream-\(UUID().uuidString)"
        )
        let stream = agent.stream("Hello from fresh stream")

        // Collect stream events
        var events: [SDKMessage] = []
        for await event in stream {
            events.append(event)
        }

        // Then: stream should work as normal (fresh conversation, no crash)
        XCTAssertFalse(events.isEmpty,
            "Stream with non-existent sessionId should produce events")

        let resultEvents = events.compactMap { event -> SDKMessage.ResultData? in
            if case .result(let data) = event { return data }
            return nil
        }
        XCTAssertFalse(resultEvents.isEmpty,
            "Stream with non-existent sessionId should produce result events")

        // Verify only the new user message was sent (no history)
        if let bodyData = SessionRestoreMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let messages = body["messages"] as? [[String: Any]] {

            XCTAssertEqual(messages.count, 1,
                "Messages should only contain the new user message for non-existent sessionId, got \(messages.count)")
        }
    }

    /// AC5 [P0]: Given a completed stream() with sessionStore configured, when the stream
    /// finishes, then sessionStore.save() is automatically called to persist updated messages.
    func testStream_autoSave_updatesPersistedData() async throws {
        // Given: a pre-saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "autosave-stream-\(UUID().uuidString)"
        let historyMessages: [[String: Any]] = [
            ["role": "user", "content": "Stream question 1"],
            ["role": "assistant", "content": [["type": "text", "text": "Stream answer 1"]] as [[String: Any]]],
        ]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: historyMessages, metadata: metadata)

        // Set up mock SSE response
        let sseResponse = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_stream_autosave","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":20,"output_tokens":0}}}

        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Stream answer 2"}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":0}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":10}}

        event: message_stop
        data: {"type":"message_stop"}
        """
        let sseData = sseResponse.data(using: .utf8)!
        SessionRestoreMockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: sseData
        )

        // When: calling stream with sessionStore and sessionId
        let agent = makeSessionRestoreSUT(sessionStore: store, sessionId: sessionId)
        let stream = agent.stream("Stream question 2")

        // Consume stream
        for await _ in stream {}

        // Then: the session should be auto-saved with updated messages
        let loaded = try await store.load(sessionId: sessionId)

        // This assertion WILL FAIL until auto-save in stream is implemented
        XCTAssertNotNil(loaded, "Session should still exist after stream auto-save")
        // Original: 2 messages. After restore + new: should be > 2
        XCTAssertGreaterThan(loaded?.messages.count ?? 0, 2,
            "Auto-saved session should have more messages than original history after stream")
    }
}

// MARK: - AC3: Loaded Messages Compatible with Agent Loop

final class SessionRestoreMessageFormatTests: XCTestCase {

    /// AC3 [P0]: Given messages loaded from SessionStore.load(), when they are passed
    /// to the agent loop (via buildMessages or direct insertion), they are directly
    /// compatible with sendMessage() -- role/content structure is preserved.
    func testRestoredMessages_compatibleWithAgentLoop() async throws {
        // Given: a saved session with properly formatted messages
        let tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("msg-format-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "format-test-\(UUID().uuidString)"

        // Messages in the exact format that Agent uses internally
        let originalMessages: [[String: Any]] = [
            ["role": "user", "content": "Hello"],
            ["role": "assistant", "content": [
                ["type": "text", "text": "Hi there! How can I help?"]
            ] as [[String: Any]]],
            ["role": "user", "content": "Tell me about Swift"],
            ["role": "assistant", "content": [
                ["type": "text", "text": "Swift is a powerful programming language."]
            ] as [[String: Any]]],
        ]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: originalMessages, metadata: metadata)

        // When: loading the session
        let loaded = try await store.load(sessionId: sessionId)
        XCTAssertNotNil(loaded, "Should successfully load the saved session")

        guard let sessionData = loaded else { return }

        // Then: loaded messages should have the same structure as the originals
        XCTAssertEqual(sessionData.messages.count, 4,
            "Should have 4 messages after round-trip")

        // Verify role/content structure is preserved (compatible with sendMessage)
        for (index, message) in sessionData.messages.enumerated() {
            XCTAssertNotNil(message["role"] as? String,
                "Message \(index) should have a 'role' string field")
            XCTAssertNotNil(message["content"],
                "Message \(index) should have a 'content' field")

            let role = message["role"] as? String
            XCTAssertTrue(role == "user" || role == "assistant",
                "Message \(index) role should be 'user' or 'assistant', got '\(role ?? "nil")'")
        }

        // Verify assistant messages have structured content blocks
        let assistantMessages = sessionData.messages.filter { $0["role"] as? String == "assistant" }
        for (index, msg) in assistantMessages.enumerated() {
            if let contentBlocks = msg["content"] as? [[String: Any]] {
                // Structured content blocks -- verify type field exists
                for block in contentBlocks {
                    XCTAssertNotNil(block["type"],
                        "Assistant message \(index) content block should have 'type' field")
                }
            }
            // String content is also valid (simple format)
        }
    }

    /// AC6 [P1]: Given a saved session with 500 messages, when executing restore,
    /// then from SessionStore.load() to agent loop start completes within 200ms.
    func testPerformance_restoreUnder200ms() async throws {
        // Given: a session with 500 messages
        let tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("perf-restore-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "perf-restore-\(UUID().uuidString)"

        var messages: [[String: Any]] = []
        for i in 1...500 {
            messages.append([
                "role": i % 2 == 0 ? "assistant" : "user",
                "content": "Message number \(i) with realistic content about programming topics",
            ])
        }
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

        // When: measuring restore time (load + message parsing)
        let start = ContinuousClock.now
        let loaded = try await store.load(sessionId: sessionId)
        let elapsed = ContinuousClock.now - start

        // Then: restore completes within 200ms
        XCTAssertNotNil(loaded, "Should load the 500-message session")
        let elapsedMs = Int(elapsed.components.seconds) * 1000
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        XCTAssertLessThan(elapsedMs, 200,
            "Restore of 500 messages should complete under 200ms (got \(elapsedMs)ms)")
    }
}

// MARK: - AC5: AgentOptions Integration

final class AgentOptionsSessionStoreTests: XCTestCase {

    /// AC5 [P0]: AgentOptions should accept sessionStore and sessionId parameters.
    /// This test validates that AgentOptions has the required properties.
    func testAgentOptions_hasSessionStoreProperty() async {
        // Given: AgentOptions with sessionStore and sessionId
        let store = SessionStore(sessionsDir: NSTemporaryDirectory())

        // When: creating AgentOptions with sessionStore and sessionId
        let options = AgentOptions(
            apiKey: "sk-test",
            model: "claude-sonnet-4-6",
            sessionStore: store,
            sessionId: "test-session-123"
        )

        // Then: properties should be set correctly
        XCTAssertNotNil(options.sessionStore,
            "sessionStore should be set")
        XCTAssertEqual(options.sessionId, "test-session-123",
            "sessionId should match the provided value")
    }

    /// AC5 [P0]: AgentOptions defaults should have nil sessionStore and nil sessionId.
    func testAgentOptions_defaultSessionPropertiesAreNil() {
        // Given: default AgentOptions
        let options = AgentOptions(apiKey: "sk-test", model: "claude-sonnet-4-6")

        // Then: sessionStore and sessionId should default to nil
        XCTAssertNil(options.sessionStore,
            "Default sessionStore should be nil")
        XCTAssertNil(options.sessionId,
            "Default sessionId should be nil")
    }

    /// AC5 [P0]: AgentOptions init(from:) should set sessionStore and sessionId to nil.
    func testAgentOptions_initFromConfig_sessionPropertiesAreNil() {
        // Given: an SDKConfiguration
        let config = SDKConfiguration(
            apiKey: "sk-test",
            model: "claude-sonnet-4-6",
            baseURL: nil,
            maxTurns: 10,
            maxTokens: 4096
        )

        // When: creating AgentOptions from config
        let options = AgentOptions(from: config)

        // Then: sessionStore and sessionId should be nil
        XCTAssertNil(options.sessionStore,
            "AgentOptions(from:) should default sessionStore to nil")
        XCTAssertNil(options.sessionId,
            "AgentOptions(from:) should default sessionId to nil")
    }
}

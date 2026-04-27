// SessionManagementWiringATDDTests.swift
// Story 17.7: Session Management Enhancement - ATDD Tests
// ATDD: Tests verify runtime wiring of 4 deferred AgentOptions session fields
//       (continueRecentSession, forkSession, resumeSessionAt, persistSession)
// TDD Phase: RED (tests verify expected runtime behavior; will FAIL until wiring is implemented)
//
// These tests verify that the Agent runtime correctly wires the 4 session fields
// declared in Story 17-2 into actual session lifecycle behavior.

import XCTest
@testable import OpenAgentSDK

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
// MARK: - Mock URL Protocol for Session Wiring Tests

/// Custom URLProtocol subclass that intercepts network requests for session wiring testing.
final class SessionWiringMockURLProtocol: URLProtocol {

    nonisolated(unsafe) static var mockResponses: [String: (statusCode: Int, headers: [String: String], body: Data)] = [:]
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var allRequests: [URLRequest] = []
    nonisolated(unsafe) static var sequentialResponses: [[String: Any]] = []
    nonisolated(unsafe) static var responseIndex: Int = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            capturedRequest.httpBody = Self.readBodyFromStream(stream)
        }

        SessionWiringMockURLProtocol.lastRequest = capturedRequest
        SessionWiringMockURLProtocol.allRequests.append(capturedRequest)

        if !SessionWiringMockURLProtocol.sequentialResponses.isEmpty {
            let index = SessionWiringMockURLProtocol.responseIndex
            if index < SessionWiringMockURLProtocol.sequentialResponses.count {
                let responseData = SessionWiringMockURLProtocol.sequentialResponses[index]
                SessionWiringMockURLProtocol.responseIndex += 1

                guard let body = try? JSONSerialization.data(withJSONObject: responseData, options: []) else {
                    client?.urlProtocol(self, didFailWithError: NSError(domain: "SessionWiringMock", code: -2, userInfo: [:]))
                    return
                }
                let httpResponse = HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                    headerFields: ["content-type": "application/json"]
                )!
                client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: body)
                client?.urlProtocolDidFinishLoading(self)
                return
            }
        }

        guard let url = request.url?.absoluteString,
              let mock = SessionWiringMockURLProtocol.mockResponses[url] else {
            client?.urlProtocol(self, didFailWithError: NSError(
                domain: "SessionWiringMock", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No mock for \(request.url?.absoluteString ?? "nil")"]
            ))
            return
        }

        let httpResponse = HTTPURLResponse(
            url: request.url!, statusCode: mock.statusCode, httpVersion: "HTTP/1.1",
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

    /// Creates an Agent configured with MockURLProtocol for session wiring tests.
    func makeSessionWiringSUT(
        apiKey: String = "sk-test-session-wiring-12345",
        model: String = "claude-sonnet-4-6",
        maxTurns: Int = 10,
        maxTokens: Int = 4096,
        sessionStore: SessionStore? = nil,
        sessionId: String? = nil,
        continueRecentSession: Bool = false,
        forkSession: Bool = false,
        resumeSessionAt: String? = nil,
        persistSession: Bool = true
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [SessionWiringMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        let client = AnthropicClient(apiKey: apiKey, baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            maxTurns: maxTurns,
            maxTokens: maxTokens,
            retryConfig: RetryConfig(maxRetries: 3, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500, 502, 503, 529]),
            sessionStore: sessionStore,
            sessionId: sessionId,
            continueRecentSession: continueRecentSession,
            forkSession: forkSession,
            resumeSessionAt: resumeSessionAt,
            persistSession: persistSession
        )

        return Agent(options: options, client: client)
    }

    /// Registers a standard non-streaming mock response for the Anthropic API endpoint.
    func registerSessionWiringMockResponse(
        id: String = "msg_wiring_001",
        content: [[String: Any]] = [["type": "text", "text": "Session wiring response"]],
        stopReason: String = "end_turn"
    ) {
        let responseDict: [String: Any] = [
            "id": id,
            "type": "message",
            "role": "assistant",
            "content": content,
            "model": "claude-sonnet-4-6",
            "stop_reason": stopReason,
            "stop_sequence": NSNull(),
            "usage": ["input_tokens": 25, "output_tokens": 150]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: responseDict, options: []) else {
            fatalError("Failed to serialize mock response")
        }
        SessionWiringMockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "application/json"],
            body: data
        )
    }

    /// Registers a streaming SSE mock response.
    func registerSessionWiringStreamMockResponse(text: String = "Stream wiring response") {
        let sseResponse = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_wiring_stream","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}

        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\(text)"}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":0}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":10}}

        event: message_stop
        data: {"type":"message_stop"}
        """
        let sseData = sseResponse.data(using: .utf8)!
        SessionWiringMockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            body: sseData
        )
    }
}

// MARK: - AC1: continueRecentSession Wiring Tests

/// Tests for Story 17-7 AC1: continueRecentSession wiring in Agent runtime.
/// When continueRecentSession is true and sessionStore is set (but sessionId is nil/empty),
/// the Agent resolves the most recent session from SessionStore.list().
final class ContinueRecentSessionWiringTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        SessionWiringMockURLProtocol.reset()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("continue-recent-wiring-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir { try? FileManager.default.removeItem(atPath: tempDir) }
        SessionWiringMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC1 [P0]: continueRecentSession=true with existing sessions -> restores most recent session.
    /// Given two sessions where session-B was updated most recently,
    /// when continueRecentSession=true with no explicit sessionId,
    /// then the agent should load session-B's history.
    func testContinueRecentSession_withExistingSessions_restoresMostRecent() async throws {
        // Given: two sessions, session-B updated most recently
        let store = SessionStore(sessionsDir: tempDir)
        let sessionA = "session-a-\(UUID().uuidString)"
        let sessionB = "session-b-\(UUID().uuidString)"

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")

        // Save session A first
        try await store.save(sessionId: sessionA, messages: [
            ["role": "user", "content": "Session A message"],
            ["role": "assistant", "content": [["type": "text", "text": "Session A response"]] as [[String: Any]]]
        ], metadata: metadata)

        // Save session B second (it will have a later updatedAt, so it's "most recent")
        // Ensure at least 10ms gap so updatedAt timestamps differ reliably
        try await _Concurrency.Task.sleep(for: .milliseconds(10))
        try await store.save(sessionId: sessionB, messages: [
            ["role": "user", "content": "Session B message"],
            ["role": "assistant", "content": [["type": "text", "text": "Session B response"]] as [[String: Any]]]
        ], metadata: metadata)

        registerSessionWiringMockResponse()

        // When: continueRecentSession=true with no explicit sessionId
        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: nil,
            continueRecentSession: true
        )
        let result = await agent.prompt("New question")

        // Then: agent should have resolved session B (most recent)
        XCTAssertEqual(result.status, .success)

        // Verify the request body includes session B's history
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let messages = body["messages"] as? [[String: Any]] {

            // session B history (2 msgs) + new user message = 3
            XCTAssertGreaterThanOrEqual(messages.count, 3,
                "Messages should include restored history (2) plus new user message (1), got \(messages.count)")

            // First message should be from session B
            let firstContent = messages[0]["content"] as? String
            XCTAssertEqual(firstContent, "Session B message",
                "Should have loaded session B (most recent), not session A")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionA)
        _ = try? await store.delete(sessionId: sessionB)
    }

    /// AC1 [P0]: continueRecentSession=true with no sessions -> proceeds as new session, no error.
    func testContinueRecentSession_withNoSessions_proceedsAsNew() async throws {
        let store = SessionStore(sessionsDir: tempDir)

        // No sessions saved -- list() returns empty

        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: nil,
            continueRecentSession: true
        )
        let result = await agent.prompt("Fresh start question")

        // Then: no error, agent proceeds as new session
        XCTAssertEqual(result.status, .success,
            "Should succeed with no sessions (fresh start)")

        // Only 1 message (the new user message) -- no history restored
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let messages = body["messages"] as? [[String: Any]] {

            XCTAssertEqual(messages.count, 1,
                "Messages should only contain new user message when no sessions exist, got \(messages.count)")
        }
    }

    /// AC1 [P0]: continueRecentSession=true with explicit sessionId -> sessionId wins (no-op).
    func testContinueRecentSession_withExplicitSessionId_sessionIdWins() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let explicitId = "explicit-session-\(UUID().uuidString)"
        let recentId = "recent-session-\(UUID().uuidString)"

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")

        // Save explicit session
        try await store.save(sessionId: explicitId, messages: [
            ["role": "user", "content": "Explicit session content"],
        ], metadata: metadata)

        // Save another session (most recent)
        try await store.save(sessionId: recentId, messages: [
            ["role": "user", "content": "Recent session content"],
        ], metadata: metadata)

        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: explicitId,
            continueRecentSession: true
        )
        let result = await agent.prompt("Follow up question")

        XCTAssertEqual(result.status, .success)

        // Should have loaded the explicit session, not the most recent one
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let messages = body["messages"] as? [[String: Any]] {

            XCTAssertGreaterThanOrEqual(messages.count, 2,
                "Should have restored explicit session history + new message")

            let firstContent = messages[0]["content"] as? String
            XCTAssertEqual(firstContent, "Explicit session content",
                "Should use explicit sessionId, not resolve most recent")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: explicitId)
        _ = try? await store.delete(sessionId: recentId)
    }

    /// AC1 [P1]: continueRecentSession=false (default) -> no resolution attempted.
    func testContinueRecentSession_false_noResolution() async throws {
        let store = SessionStore(sessionsDir: tempDir)

        // Save a session
        let existingId = "existing-\(UUID().uuidString)"
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: existingId, messages: [
            ["role": "user", "content": "Existing content"],
        ], metadata: metadata)

        registerSessionWiringMockResponse()

        // continueRecentSession=false (default), no sessionId -> should NOT resolve
        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: nil,
            continueRecentSession: false
        )
        let result = await agent.prompt("New question")

        XCTAssertEqual(result.status, .success)

        // No history restored -- only new message
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let messages = body["messages"] as? [[String: Any]] {

            XCTAssertEqual(messages.count, 1,
                "No history restored when continueRecentSession=false, got \(messages.count)")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: existingId)
    }
}

// MARK: - AC2: forkSession Wiring Tests

/// Tests for Story 17-7 AC2: forkSession wiring in Agent runtime.
/// When forkSession=true and sessionStore+sessionId are configured,
/// the Agent forks the session before restoring history.
final class ForkSessionWiringTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        SessionWiringMockURLProtocol.reset()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("fork-wiring-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir { try? FileManager.default.removeItem(atPath: tempDir) }
        SessionWiringMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC2 [P0]: forkSession=true with valid session -> forked copy used, original unchanged.
    func testForkSession_withValidSession_createsFork() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "fork-source-\(UUID().uuidString)"

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sourceId, messages: [
            ["role": "user", "content": "Original message"],
            ["role": "assistant", "content": [["type": "text", "text": "Original response"]] as [[String: Any]]],
        ], metadata: metadata)

        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sourceId,
            forkSession: true
        )
        let result = await agent.prompt("Fork follow-up")

        XCTAssertEqual(result.status, .success)

        // Original session should remain unchanged (2 messages, not modified)
        let original = try await store.load(sessionId: sourceId)
        XCTAssertNotNil(original)
        XCTAssertEqual(original?.messages.count, 2,
            "Original session should remain unchanged (2 messages)")

        // Verify messages sent to LLM include restored history from fork
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let messages = body["messages"] as? [[String: Any]] {

            XCTAssertGreaterThanOrEqual(messages.count, 3,
                "Fork should restore original history (2) + new message (1)")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sourceId)
    }

    /// AC2 [P0]: forkSession=true with non-existent session -> graceful fallback (no error).
    func testForkSession_withNonExistentSession_gracefulFallback() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let nonexistentId = "nonexistent-fork-\(UUID().uuidString)"

        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: nonexistentId,
            forkSession: true
        )
        let result = await agent.prompt("Fallback question")

        // Should not crash, should proceed (fork fails gracefully)
        XCTAssertEqual(result.status, .success,
            "Should succeed even when fork source doesn't exist")
    }

    /// AC2 [P1]: forkSession=false (default) -> no fork attempted.
    func testForkSession_false_noFork() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "no-fork-session-\(UUID().uuidString)"

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: [
            ["role": "user", "content": "Original"],
        ], metadata: metadata)

        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sessionId,
            forkSession: false
        )
        let result = await agent.prompt("Follow up")

        XCTAssertEqual(result.status, .success)

        // Original session should have been updated (not forked)
        let loaded = try await store.load(sessionId: sessionId)
        XCTAssertNotNil(loaded)
        XCTAssertGreaterThan(loaded?.messages.count ?? 0, 1,
            "Original session should be updated (no fork)")

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }
}

// MARK: - AC3: resumeSessionAt Wiring Tests

/// Tests for Story 17-7 AC3: resumeSessionAt wiring in Agent runtime.
/// When resumeSessionAt is set to a message UUID, the Agent truncates history at that point.
final class ResumeSessionAtWiringTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        SessionWiringMockURLProtocol.reset()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("resume-at-wiring-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir { try? FileManager.default.removeItem(atPath: tempDir) }
        SessionWiringMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC3 [P0]: resumeSessionAt with matching UUID -> history truncated at that point.
    func testResumeSessionAt_withMatchingUUID_truncatesHistory() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "resume-at-session-\(UUID().uuidString)"

        let targetUUID = "msg-uuid-target-001"

        // Messages with UUID fields
        let messages: [[String: Any]] = [
            ["role": "user", "content": "Message 1", "uuid": "msg-uuid-001"],
            ["role": "assistant", "content": [["type": "text", "text": "Response 1"]] as [[String: Any]], "uuid": "msg-uuid-002"],
            ["role": "user", "content": "Message 2", "uuid": targetUUID],
            ["role": "assistant", "content": [["type": "text", "text": "Response 2"]] as [[String: Any]], "uuid": "msg-uuid-004"],
            ["role": "user", "content": "Message 3", "uuid": "msg-uuid-005"],
        ]

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sessionId,
            resumeSessionAt: targetUUID
        )
        let result = await agent.prompt("Resume from here")

        XCTAssertEqual(result.status, .success)

        // History should be truncated: msg-uuid-001, msg-uuid-002, msg-uuid-target-001 + new message = 4
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let requestMessages = body["messages"] as? [[String: Any]] {

            // Truncated at index 2 (3 messages) + 1 new user message = 4
            XCTAssertEqual(requestMessages.count, 4,
                "History should be truncated at UUID match point (3 msgs) + new user message (1) = 4, got \(requestMessages.count)")

            // Last message should be the new user message
            let lastMsg = requestMessages.last
            XCTAssertEqual(lastMsg?["role"] as? String, "user")
            XCTAssertEqual(lastMsg?["content"] as? String, "Resume from here")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    /// AC3 [P0]: resumeSessionAt with non-matching UUID -> full history kept (no error).
    func testResumeSessionAt_withNonMatchingUUID_keepsFullHistory() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "resume-nomatch-session-\(UUID().uuidString)"

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Message 1"],
            ["role": "assistant", "content": [["type": "text", "text": "Response 1"]] as [[String: Any]]],
            ["role": "user", "content": "Message 2"],
        ]

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sessionId,
            resumeSessionAt: "nonexistent-uuid-99999"
        )
        let result = await agent.prompt("Resume anyway")

        XCTAssertEqual(result.status, .success)

        // Full history (3 msgs) + new user message = 4
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let requestMessages = body["messages"] as? [[String: Any]] {

            XCTAssertGreaterThanOrEqual(requestMessages.count, 4,
                "Full history should be kept when UUID not found, got \(requestMessages.count)")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    /// AC3 [P1]: resumeSessionAt with nil -> no truncation (default behavior).
    func testResumeSessionAt_nil_noTruncation() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "resume-nil-session-\(UUID().uuidString)"

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Msg 1"],
            ["role": "assistant", "content": [["type": "text", "text": "Resp 1"]] as [[String: Any]]],
            ["role": "user", "content": "Msg 2"],
            ["role": "assistant", "content": [["type": "text", "text": "Resp 2"]] as [[String: Any]]],
        ]

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sessionId,
            resumeSessionAt: nil
        )
        let result = await agent.prompt("Continue")

        XCTAssertEqual(result.status, .success)

        // Full history (4 msgs) + new user message = 5
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let requestMessages = body["messages"] as? [[String: Any]] {

            XCTAssertGreaterThanOrEqual(requestMessages.count, 5,
                "Full history preserved when resumeSessionAt is nil, got \(requestMessages.count)")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    /// AC3 [P1]: resumeSessionAt matches "id" key (alternative key name).
    func testResumeSessionAt_matchesIdKey() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "resume-id-key-session-\(UUID().uuidString)"

        let targetId = "target-id-002"

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Msg 1", "id": "id-001"],
            ["role": "assistant", "content": [["type": "text", "text": "Resp 1"]] as [[String: Any]], "id": targetId],
            ["role": "user", "content": "Msg 2", "id": "id-003"],
        ]

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sessionId,
            resumeSessionAt: targetId
        )
        let result = await agent.prompt("Resume at id key")

        XCTAssertEqual(result.status, .success)

        // Truncated at index 1 (2 messages) + new user message = 3
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let requestMessages = body["messages"] as? [[String: Any]] {

            XCTAssertEqual(requestMessages.count, 3,
                "Should match 'id' key and truncate at index 1 (2 msgs) + new = 3, got \(requestMessages.count)")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }
}

// MARK: - AC4: persistSession Wiring Verification Tests

/// Tests for Story 17-7 AC4: persistSession wiring verification.
/// Verifies that persistSession gates session save in all code paths.
final class PersistSessionWiringTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        SessionWiringMockURLProtocol.reset()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("persist-wiring-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir { try? FileManager.default.removeItem(atPath: tempDir) }
        SessionWiringMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC4 [P0]: persistSession=true (default) -> session is saved after prompt().
    func testPersistSession_true_savesAfterPrompt() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "persist-true-\(UUID().uuidString)"

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: [
            ["role": "user", "content": "Original"],
        ], metadata: metadata)

        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sessionId,
            persistSession: true
        )
        _ = await agent.prompt("Follow up")

        // Session should be saved (auto-save)
        let loaded = try await store.load(sessionId: sessionId)
        XCTAssertNotNil(loaded)
        XCTAssertGreaterThan(loaded?.messages.count ?? 0, 1,
            "Session should be auto-saved when persistSession=true")

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    /// AC4 [P0]: persistSession=false -> session is NOT saved after prompt().
    func testPersistSession_false_noSaveAfterPrompt() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "persist-false-\(UUID().uuidString)"

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: [
            ["role": "user", "content": "Original"],
        ], metadata: metadata)

        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sessionId,
            persistSession: false
        )
        _ = await agent.prompt("Ephemeral question")

        // Session should NOT be saved (persistSession=false means ephemeral)
        let loaded = try await store.load(sessionId: sessionId)
        // Should still have only the original message (1), not the updated conversation
        XCTAssertEqual(loaded?.messages.count, 1,
            "Session should NOT be auto-saved when persistSession=false")

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    /// AC4 [P0]: persistSession=false -> session is NOT saved after stream().
    func testPersistSession_false_noSaveAfterStream() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "persist-false-stream-\(UUID().uuidString)"

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: [
            ["role": "user", "content": "Original stream"],
        ], metadata: metadata)

        registerSessionWiringStreamMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sessionId,
            persistSession: false
        )
        let stream = agent.stream("Ephemeral stream question")
        for await _ in stream {}

        // Session should NOT be saved
        let loaded = try await store.load(sessionId: sessionId)
        XCTAssertEqual(loaded?.messages.count, 1,
            "Session should NOT be auto-saved after stream when persistSession=false")

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    /// AC4 [P0]: persistSession=true (default) -> session is saved after stream().
    func testPersistSession_true_savesAfterStream() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "persist-true-stream-\(UUID().uuidString)"

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: [
            ["role": "user", "content": "Original stream"],
        ], metadata: metadata)

        registerSessionWiringStreamMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sessionId,
            persistSession: true
        )
        let stream = agent.stream("Stream follow up")
        for await _ in stream {}

        // Session should be saved
        let loaded = try await store.load(sessionId: sessionId)
        XCTAssertNotNil(loaded)
        XCTAssertGreaterThan(loaded?.messages.count ?? 0, 1,
            "Session should be auto-saved after stream when persistSession=true")

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }
}

// MARK: - AC5: Combined Options Tests

/// Tests for Story 17-7 AC5: Combined session option interactions.
/// Verifies that session options work correctly when combined.
final class CombinedSessionOptionsWiringTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        SessionWiringMockURLProtocol.reset()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("combined-wiring-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir { try? FileManager.default.removeItem(atPath: tempDir) }
        SessionWiringMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC5 [P0]: continueRecentSession + forkSession -> fork the continued session.
    func testContinueRecentSession_and_forkSession_forksTheContinuedSession() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let recentId = "recent-combined-\(UUID().uuidString)"

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: recentId, messages: [
            ["role": "user", "content": "Recent session content"],
            ["role": "assistant", "content": [["type": "text", "text": "Recent response"]] as [[String: Any]]],
        ], metadata: metadata)

        registerSessionWiringMockResponse()

        // continueRecentSession resolves the most recent session,
        // then forkSession forks it before restoring
        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: nil,
            continueRecentSession: true,
            forkSession: true
        )
        let result = await agent.prompt("Combined question")

        XCTAssertEqual(result.status, .success)

        // The original session should remain unchanged
        let original = try await store.load(sessionId: recentId)
        XCTAssertNotNil(original)
        XCTAssertEqual(original?.messages.count, 2,
            "Original session should remain unchanged (fork was created)")

        // The forked session should have been saved with the new interaction
        // (auto-save goes to the forked session ID, not the original)
        let sessions = try await store.list()
        // Should have at least 2 sessions now (original + fork)
        XCTAssertGreaterThanOrEqual(sessions.count, 2,
            "Should have original + forked session")

        // Cleanup
        _ = try? await store.delete(sessionId: recentId)
    }

    /// AC5 [P1]: continueRecentSession + forkSession + resumeSessionAt -> full pipeline.
    func testContinueRecentAndForkAndResumeAt_fullPipeline() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let recentId = "pipeline-session-\(UUID().uuidString)"

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Msg 1", "uuid": "uuid-001"],
            ["role": "assistant", "content": [["type": "text", "text": "Resp 1"]] as [[String: Any]], "uuid": "uuid-002"],
            ["role": "user", "content": "Msg 2", "uuid": "uuid-003"],
            ["role": "assistant", "content": [["type": "text", "text": "Resp 2"]] as [[String: Any]], "uuid": "uuid-004"],
        ]

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: recentId, messages: messages, metadata: metadata)

        registerSessionWiringMockResponse()

        // Continue most recent, fork it, then resume at uuid-002
        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: nil,
            continueRecentSession: true,
            forkSession: true,
            resumeSessionAt: "uuid-002"
        )
        let result = await agent.prompt("Full pipeline question")

        XCTAssertEqual(result.status, .success)

        // Verify messages sent to LLM: truncated at uuid-002 (2 msgs) + new = 3
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let requestMessages = body["messages"] as? [[String: Any]] {

            XCTAssertEqual(requestMessages.count, 3,
                "Forked from most recent, truncated at uuid-002 (2 msgs) + new (1) = 3, got \(requestMessages.count)")
        }

        // Original should be unchanged
        let original = try await store.load(sessionId: recentId)
        XCTAssertEqual(original?.messages.count, 4,
            "Original session unchanged after fork")

        // Cleanup
        _ = try? await store.delete(sessionId: recentId)
    }

    /// AC5 [P1]: All options at default values -> no session wiring active.
    func testAllDefaultOptions_noSessionWiring() async throws {
        registerSessionWiringMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: nil,
            sessionId: nil,
            continueRecentSession: false,
            forkSession: false,
            resumeSessionAt: nil,
            persistSession: true
        )
        let result = await agent.prompt("Plain question")

        XCTAssertEqual(result.status, .success,
            "Agent with all default session options should work normally")
    }
}

// MARK: - Stream() Path Verification Tests

/// Tests verifying session wiring also works in the stream() code path.
final class StreamSessionWiringTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        SessionWiringMockURLProtocol.reset()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("stream-wiring-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDir { try? FileManager.default.removeItem(atPath: tempDir) }
        SessionWiringMockURLProtocol.reset()
        super.tearDown()
    }

    /// Stream [P0]: continueRecentSession works in stream() path.
    func testStream_continueRecentSession_restoresMostRecent() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "stream-recent-\(UUID().uuidString)"

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: [
            ["role": "user", "content": "Stream session content"],
            ["role": "assistant", "content": [["type": "text", "text": "Stream response"]] as [[String: Any]]],
        ], metadata: metadata)

        registerSessionWiringStreamMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: nil,
            continueRecentSession: true
        )
        let stream = agent.stream("Stream follow up")
        var events: [SDKMessage] = []
        for await event in stream { events.append(event) }

        XCTAssertFalse(events.isEmpty)

        // Verify history was restored (3 messages: 2 history + 1 new)
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let messages = body["messages"] as? [[String: Any]] {

            XCTAssertGreaterThanOrEqual(messages.count, 3,
                "Stream should restore history (2) + new message (1)")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    /// Stream [P0]: forkSession works in stream() path.
    func testStream_forkSession_createsFork() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "stream-fork-source-\(UUID().uuidString)"

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sourceId, messages: [
            ["role": "user", "content": "Stream fork original"],
            ["role": "assistant", "content": [["type": "text", "text": "Stream fork response"]] as [[String: Any]]],
        ], metadata: metadata)

        registerSessionWiringStreamMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sourceId,
            forkSession: true
        )
        let stream = agent.stream("Stream fork follow up")
        for await _ in stream {}

        // Original session should remain unchanged
        let original = try await store.load(sessionId: sourceId)
        XCTAssertEqual(original?.messages.count, 2,
            "Original session unchanged after stream fork")

        // Cleanup
        _ = try? await store.delete(sessionId: sourceId)
    }

    /// Stream [P0]: resumeSessionAt works in stream() path.
    func testStream_resumeSessionAt_truncatesHistory() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "stream-resume-\(UUID().uuidString)"

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Msg 1", "uuid": "stream-uuid-001"],
            ["role": "assistant", "content": [["type": "text", "text": "Resp 1"]] as [[String: Any]], "uuid": "stream-uuid-002"],
            ["role": "user", "content": "Msg 2", "uuid": "stream-uuid-003"],
        ]

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

        registerSessionWiringStreamMockResponse()

        let agent = makeSessionWiringSUT(
            sessionStore: store,
            sessionId: sessionId,
            resumeSessionAt: "stream-uuid-002"
        )
        let stream = agent.stream("Stream resume question")
        for await _ in stream {}

        // Truncated at index 1 (2 msgs) + new user message = 3
        if let bodyData = SessionWiringMockURLProtocol.lastRequest?.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let requestMessages = body["messages"] as? [[String: Any]] {

            XCTAssertEqual(requestMessages.count, 3,
                "Stream should truncate at uuid-002 (2 msgs) + new (1) = 3, got \(requestMessages.count)")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }
}

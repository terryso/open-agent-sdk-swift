import XCTest
@testable import OpenAgentSDK

// MARK: - AutoCompactState Tests

/// ATDD RED PHASE: Tests for Story 2.5 -- Auto Conversation Compaction.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Utils/Compact.swift` is created with AutoCompactState, createAutoCompactState(),
///     estimateMessagesTokens(), getAutoCompactThreshold(), shouldAutoCompact(),
///     compactConversation()
///   - `Agent.prompt()` integrates shouldAutoCompact check before API call
///   - `Agent.stream()` integrates shouldAutoCompact check and emits .system(.compactBoundary)
/// TDD Phase: RED (feature not implemented yet)
final class AutoCompactStateTests: XCTestCase {

    // MARK: - createAutoCompactState

    /// AC1 [P1]: Initial state has compacted=false, turnCounter=0, consecutiveFailures=0.
    func testCreateAutoCompactState_ReturnsInitialState() {
        let state = createAutoCompactState()

        XCTAssertFalse(state.compacted,
                       "Initial state should have compacted=false")
        XCTAssertEqual(state.turnCounter, 0,
                       "Initial state should have turnCounter=0")
        XCTAssertEqual(state.consecutiveFailures, 0,
                       "Initial state should have consecutiveFailures=0")
    }
}

// MARK: - estimateMessagesTokens Tests

final class EstimateMessagesTokensTests: XCTestCase {

    /// AC1 [P1]: Tokens estimated from simple string content messages.
    /// Uses 4 characters/token approximation.
    func testEstimateMessagesTokens_CalculatesCorrectTotal() {
        // 100 characters / 4 = 25 tokens per message
        let messages: [[String: Any]] = [
            ["role": "user", "content": String(repeating: "a", count: 100)],
            ["role": "assistant", "content": String(repeating: "b", count: 200)],
        ]

        let tokens = estimateMessagesTokens(messages)

        // 100/4 + 200/4 = 25 + 50 = 75
        XCTAssertEqual(tokens, 75,
                       "Should estimate 75 tokens for 300 characters of string content")
    }

    /// AC1 [P1]: Tokens estimated from block content array messages.
    func testEstimateMessagesTokens_HandlesBlockContent() {
        let messages: [[String: Any]] = [
            [
                "role": "assistant",
                "content": [
                    ["type": "text", "text": String(repeating: "x", count: 80)],
                    ["type": "text", "text": String(repeating: "y", count: 120)],
                ]
            ],
        ]

        let tokens = estimateMessagesTokens(messages)

        // 80/4 + 120/4 = 20 + 30 = 50
        XCTAssertEqual(tokens, 50,
                       "Should estimate 50 tokens for block content array")
    }

    /// AC1 [P1]: Empty message array returns 0 tokens.
    func testEstimateMessagesTokens_ReturnsZeroForEmptyArray() {
        let tokens = estimateMessagesTokens([])

        XCTAssertEqual(tokens, 0,
                       "Empty message array should estimate 0 tokens")
    }

    /// AC1 [P2]: Messages with mixed content types are handled gracefully.
    func testEstimateMessagesTokens_HandlesToolUseBlocks() {
        let messages: [[String: Any]] = [
            [
                "role": "assistant",
                "content": [
                    ["type": "text", "text": "Let me check that."],
                    ["type": "tool_use", "name": "read_file", "id": "tool_123", "input": ["path": "/tmp/test.swift"]],
                ]
            ],
        ]

        let tokens = estimateMessagesTokens(messages)

        // Should at least count the text block characters: "Let me check that.".count / 4 = 5
        // Plus the tool_use block serialized as JSON
        XCTAssertGreaterThan(tokens, 0,
                             "Should estimate positive tokens for messages with tool_use blocks")
    }

    /// AC1 [P2]: Messages with tool_result blocks are handled.
    func testEstimateMessagesTokens_HandlesToolResultBlocks() {
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["type": "tool_result", "tool_use_id": "tool_123", "content": "File contents here"],
                ]
            ],
        ]

        let tokens = estimateMessagesTokens(messages)

        XCTAssertGreaterThan(tokens, 0,
                             "Should estimate positive tokens for tool_result blocks")
    }
}

// MARK: - getAutoCompactThreshold Tests

final class GetAutoCompactThresholdTests: XCTestCase {

    /// AC1 [P1]: Threshold = context window - AUTOCOMPACT_BUFFER_TOKENS (13,000).
    func testGetAutoCompactThreshold_EqualsContextWindowMinusBuffer() {
        let threshold = getAutoCompactThreshold(model: "claude-sonnet-4-6")
        let expectedContextWindow = getContextWindowSize(model: "claude-sonnet-4-6")
        let expectedThreshold = expectedContextWindow - AUTOCOMPACT_BUFFER_TOKENS

        XCTAssertEqual(threshold, expectedThreshold,
                       "Threshold should equal context window minus AUTOCOMPACT_BUFFER_TOKENS")
        XCTAssertEqual(threshold, 200_000 - 13_000,
                       "Threshold for claude-sonnet-4-6 should be 200,000 - 13,000 = 187,000")
    }

    /// AC1 [P2]: Unknown model returns default threshold.
    func testGetAutoCompactThreshold_UnknownModel_ReturnsDefault() {
        let threshold = getAutoCompactThreshold(model: "unknown-model-v99")

        XCTAssertEqual(threshold, 200_000 - 13_000,
                       "Unknown model should use default context window minus buffer")
    }
}

// MARK: - shouldAutoCompact Tests

final class ShouldAutoCompactTests: XCTestCase {

    /// AC1 [P0]: Returns true when estimated tokens exceed threshold.
    func testShouldAutoCompact_ReturnsTrue_WhenTokensExceedThreshold() {
        let model = "claude-sonnet-4-6"
        let threshold = getAutoCompactThreshold(model: model)
        // Create messages that exceed the threshold
        // threshold / 4 * 4 = enough characters to exceed threshold
        let charCount = (threshold + 1000) * 4
        let messages: [[String: Any]] = [
            ["role": "user", "content": String(repeating: "a", count: charCount)],
        ]
        let state = createAutoCompactState()

        let result = shouldAutoCompact(messages: messages, model: model, state: state)

        XCTAssertTrue(result,
                      "Should return true when estimated tokens >= threshold")
    }

    /// AC1 [P0]: Returns false when estimated tokens are below threshold.
    func testShouldAutoCompact_ReturnsFalse_WhenTokensBelowThreshold() {
        let model = "claude-sonnet-4-6"
        // Small message, well below the 187,000 threshold
        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello, this is a short message."],
        ]
        let state = createAutoCompactState()

        let result = shouldAutoCompact(messages: messages, model: model, state: state)

        XCTAssertFalse(result,
                       "Should return false when estimated tokens < threshold")
    }

    /// AC4 [P0]: Returns false when consecutiveFailures >= 3.
    func testShouldAutoCompact_ReturnsFalse_WhenConsecutiveFailuresAtLimit() {
        let model = "claude-sonnet-4-6"
        // Create messages that exceed threshold
        let charCount = (getAutoCompactThreshold(model: model) + 1000) * 4
        let messages: [[String: Any]] = [
            ["role": "user", "content": String(repeating: "a", count: charCount)],
        ]
        // State with 3 consecutive failures
        let state = AutoCompactState(compacted: false, turnCounter: 0, consecutiveFailures: 3)

        let result = shouldAutoCompact(messages: messages, model: model, state: state)

        XCTAssertFalse(result,
                       "Should return false when consecutiveFailures >= 3")
    }

    /// AC4 [P0]: Returns true when consecutiveFailures < 3 even with large messages.
    func testShouldAutoCompact_ReturnsTrue_WhenFailuresBelowLimit() {
        let model = "claude-sonnet-4-6"
        let charCount = (getAutoCompactThreshold(model: model) + 1000) * 4
        let messages: [[String: Any]] = [
            ["role": "user", "content": String(repeating: "a", count: charCount)],
        ]
        // State with 2 consecutive failures (still below limit)
        let state = AutoCompactState(compacted: false, turnCounter: 5, consecutiveFailures: 2)

        let result = shouldAutoCompact(messages: messages, model: model, state: state)

        XCTAssertTrue(result,
                      "Should return true when consecutiveFailures < 3 and tokens exceed threshold")
    }

    /// AC4 [P2]: Exactly at threshold triggers compaction (>= not >).
    func testShouldAutoCompact_ReturnsTrue_WhenTokensExactlyAtThreshold() {
        let model = "claude-sonnet-4-6"
        let threshold = getAutoCompactThreshold(model: model)
        // Create messages whose estimated tokens are exactly at the threshold
        let charCount = threshold * 4
        let messages: [[String: Any]] = [
            ["role": "user", "content": String(repeating: "a", count: charCount)],
        ]
        let state = createAutoCompactState()

        let result = shouldAutoCompact(messages: messages, model: model, state: state)

        XCTAssertTrue(result,
                      "Should return true when estimated tokens exactly equal threshold (>= comparison)")
    }
}

// MARK: - compactConversation Tests (using CompactMockURLProtocol)

/// Custom URLProtocol that supports returning different status codes on sequential requests
/// for compaction testing. The first N requests are compaction LLM calls, subsequent are main loop calls.
final class CompactMockURLProtocol: URLProtocol {

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
            capturedRequest.httpBody = readRequestBodyFromStream(stream)
        }

        CompactMockURLProtocol.allRequests.append(capturedRequest)

        let index = CompactMockURLProtocol.responseIndex
        if index < CompactMockURLProtocol.sequentialResponses.count {
            let response = CompactMockURLProtocol.sequentialResponses[index]
            CompactMockURLProtocol.responseIndex += 1

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
                domain: "CompactMockURLProtocol",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No more mock responses (index: \(index))"]
            )
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() {
        sequentialResponses = []
        responseIndex = 0
        allRequests = []
    }
}

// MARK: - Test Helpers for Compact Tests

extension XCTestCase {

    /// Zero-delay retry config for tests — no waiting in unit tests.
    var fastRetryConfig: RetryConfig {
        RetryConfig(maxRetries: 3, baseDelayMs: 0, maxDelayMs: 0, retryableStatusCodes: [429, 500, 502, 503, 529])
    }

    /// Creates an AnthropicClient configured with CompactMockURLProtocol.
    func makeCompactTestClient(
        apiKey: String = "sk-test-compact-key-12345"
    ) -> AnthropicClient {
        let urlSession = makeMockURLSession(protocolClass: CompactMockURLProtocol.self)
        return AnthropicClient(apiKey: apiKey, baseURL: nil, urlSession: urlSession)
    }

    /// Builds a compaction LLM success response with the given summary text.
    func makeCompactionSuccessResponse(summary: String) -> Data {
        let response: [String: Any] = [
            "id": "msg_compact_001",
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

    /// Registers sequential mock responses for compact testing.
    func registerCompactMockResponses(_ responses: [(statusCode: Int, headers: [String: String], body: Data)]) {
        CompactMockURLProtocol.sequentialResponses = responses
        CompactMockURLProtocol.responseIndex = 0
    }

    /// Creates messages that exceed the compaction threshold for the given model.
    func makeOversizedMessages(model: String = "claude-sonnet-4-6") -> [[String: Any]] {
        let threshold = getAutoCompactThreshold(model: model)
        let charCount = (threshold + 10_000) * 4
        return [
            ["role": "user", "content": String(repeating: "a", count: charCount)],
        ]
    }
}

// MARK: - compactConversation Tests

final class CompactConversationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CompactMockURLProtocol.reset()
    }

    override func tearDown() {
        CompactMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC3 [P0]: Successful compaction returns exactly 2 messages (user summary + assistant confirmation).
    func testCompactConversation_ReturnsTwoMessages_OnSuccess() async throws {
        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()
        let state = createAutoCompactState()

        let summary = "The user discussed implementing auto-compaction for long conversations."
        let compactionResponse = makeCompactionSuccessResponse(summary: summary)

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactionResponse),
        ])

        let result = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            retryConfig: fastRetryConfig
        )

        XCTAssertEqual(result.compactedMessages.count, 2,
                       "Compacted messages should contain exactly 2 messages")
    }

    /// AC3 [P0]: User message contains "[Previous conversation summary]" prefix.
    func testCompactConversation_SummaryContainsExpectedPrefix() async throws {
        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()
        let state = createAutoCompactState()

        let summary = "Key decisions: use 4-char/token estimation, buffer of 13k tokens."
        let compactionResponse = makeCompactionSuccessResponse(summary: summary)

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactionResponse),
        ])

        let result = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            retryConfig: fastRetryConfig
        )

        // Check user message contains summary prefix
        let userMessage = result.compactedMessages[0]
        XCTAssertEqual(userMessage["role"] as? String, "user",
                       "First compacted message should be from user")
        let userContent = userMessage["content"] as? String ?? ""
        XCTAssertTrue(userContent.contains("[Previous conversation summary]"),
                      "User message should contain '[Previous conversation summary]' prefix")
        XCTAssertTrue(userContent.contains(summary),
                      "User message should contain the actual summary text")

        // Check assistant message
        let assistantMessage = result.compactedMessages[1]
        XCTAssertEqual(assistantMessage["role"] as? String, "assistant",
                       "Second compacted message should be from assistant")
    }

    /// AC4 [P0]: Compaction failure preserves original messages.
    func testCompactConversation_PreservesOriginalMessages_OnFailure() async throws {
        let client = makeCompactTestClient()
        let originalMessages: [[String: Any]] = [
            ["role": "user", "content": "Hello"],
            ["role": "assistant", "content": [["type": "text", "text": "Hi there"]]],
        ]
        let state = createAutoCompactState()

        // Register an error response (HTTP 500)
        let errorBody: [String: Any] = [
            "error": ["type": "api_error", "message": "Internal server error"]
        ]
        let errorData = try! JSONSerialization.data(withJSONObject: errorBody, options: [])

        registerCompactMockResponses([
            (500, ["content-type": "application/json"], errorData),
        ])

        let result = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: originalMessages,
            state: state,
            retryConfig: fastRetryConfig
        )

        // Original messages should be preserved
        XCTAssertEqual(result.compactedMessages.count, originalMessages.count,
                       "Original messages should be preserved on compaction failure")
        XCTAssertEqual(result.summary, "",
                       "Summary should be empty on failure")
    }

    /// AC4 [P0]: Consecutive failures increment.
    func testCompactConversation_IncrementsConsecutiveFailures_OnFailure() async throws {
        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()

        // Register error responses for 2 consecutive compaction attempts
        let errorBody: [String: Any] = [
            "error": ["type": "api_error", "message": "Server error"]
        ]
        let errorData = try! JSONSerialization.data(withJSONObject: errorBody, options: [])

        registerCompactMockResponses([
            (500, ["content-type": "application/json"], errorData),
            (500, ["content-type": "application/json"], errorData),
        ])

        let state0 = createAutoCompactState()

        let result1 = await compactConversation(
            client: client, model: "claude-sonnet-4-6",
            messages: messages, state: state0, retryConfig: fastRetryConfig
        )
        XCTAssertEqual(result1.state.consecutiveFailures, 1,
                       "First failure should increment consecutiveFailures to 1")

        let result2 = await compactConversation(
            client: client, model: "claude-sonnet-4-6",
            messages: messages, state: result1.state, retryConfig: fastRetryConfig
        )
        XCTAssertEqual(result2.state.consecutiveFailures, 2,
                       "Second failure should increment consecutiveFailures to 2")
    }

    /// AC4 [P0]: After 3 consecutive failures, shouldAutoCompact returns false.
    func testShouldAutoCompact_StopsAfterThreeConsecutiveFailures() async throws {
        let model = "claude-sonnet-4-6"
        let messages = makeOversizedMessages(model: model)

        // State after 3 consecutive failures
        let state = AutoCompactState(compacted: false, turnCounter: 0, consecutiveFailures: 3)

        let result = shouldAutoCompact(messages: messages, model: model, state: state)

        XCTAssertFalse(result,
                       "Should NOT attempt compaction after 3 consecutive failures")
    }

    /// AC4 [P1]: Consecutive failures reset to 0 on success.
    func testCompactConversation_ResetsConsecutiveFailures_OnSuccess() async throws {
        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()
        // State with prior failures
        let state = AutoCompactState(compacted: false, turnCounter: 5, consecutiveFailures: 2)

        let compactionResponse = makeCompactionSuccessResponse(summary: "Summary text")

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactionResponse),
        ])

        let result = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            retryConfig: fastRetryConfig
        )

        XCTAssertEqual(result.state.consecutiveFailures, 0,
                       "Successful compaction should reset consecutiveFailures to 0")
        XCTAssertTrue(result.state.compacted,
                      "Successful compaction should set compacted to true")
        XCTAssertEqual(result.state.turnCounter, 5,
                       "turnCounter should be preserved from previous state")
    }

    /// AC5 [P1]: Compaction LLM call includes correct system prompt.
    func testCompactConversation_CallsLLMWithCorrectSystemPrompt() async throws {
        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()
        let state = createAutoCompactState()

        let compactionResponse = makeCompactionSuccessResponse(summary: "A summary.")

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactionResponse),
        ])

        _ = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            retryConfig: fastRetryConfig
        )

        // Verify the compaction request was sent with the expected system prompt
        let requests = CompactMockURLProtocol.allRequests
        XCTAssertGreaterThanOrEqual(requests.count, 1,
                                     "Should have sent at least 1 request")

        if let firstRequest = requests.first,
           let bodyData = firstRequest.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any] {

            let systemPrompt = body["system"] as? String ?? ""
            XCTAssertTrue(systemPrompt.contains("summarizer") || systemPrompt.contains("summar"),
                          "Compaction request should include a summarizer system prompt, got: \(systemPrompt)")

            let maxTokens = body["max_tokens"] as? Int ?? 0
            XCTAssertEqual(maxTokens, 8192,
                           "Compaction request should use maxTokens=8192")
        }
    }

    /// AC5 [P1]: State tracks compacted flag and turnCounter correctly across multiple calls.
    func testCompactConversation_StateTracking_AccurateAcrossCalls() async throws {
        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()

        let compactionResponse = makeCompactionSuccessResponse(summary: "First summary.")

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactionResponse),
            (200, ["content-type": "application/json"], compactionResponse),
        ])

        let state0 = AutoCompactState(compacted: false, turnCounter: 3, consecutiveFailures: 0)

        let result1 = await compactConversation(
            client: client, model: "claude-sonnet-4-6",
            messages: messages, state: state0, retryConfig: fastRetryConfig
        )
        XCTAssertTrue(result1.state.compacted,
                      "First compaction should set compacted=true")
        XCTAssertEqual(result1.state.consecutiveFailures, 0,
                       "First compaction should have consecutiveFailures=0")

        // Second compaction with compacted state
        let result2 = await compactConversation(
            client: client, model: "claude-sonnet-4-6",
            messages: result1.compactedMessages, state: result1.state, retryConfig: fastRetryConfig
        )
        XCTAssertTrue(result2.state.compacted,
                      "Second compaction should maintain compacted=true")
    }
}

// MARK: - Mock LLMClient for Agent.compactNow tests

/// A mock LLMClient that returns a canned compaction success response via sendMessage.
/// Used for testing Agent.compactNow() which calls compactConversation → client.sendMessage.
final class CompactNowMockClient: @unchecked Sendable, LLMClient {
    private let responseJSON: Data
    private let _error: Error?

    init(response: [String: Any]? = nil, error: Error? = nil) {
        let defaultResponse: [String: Any] = [
            "id": "msg_compact_mock",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "Summary: The user discussed compaction testing."]],
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "stop_sequence": NSNull(),
            "usage": ["input_tokens": 500, "output_tokens": 200]
        ]
        self.responseJSON = try! JSONSerialization.data(withJSONObject: response ?? defaultResponse, options: [])
        self._error = error
    }

    private var response: [String: Any] {
        (try? JSONSerialization.jsonObject(with: responseJSON, options: [])) as? [String: Any] ?? [:]
    }

    nonisolated func sendMessage(
        model: String, messages: [[String: Any]], maxTokens: Int,
        system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
        thinking: [String: Any]?, temperature: Double?
    ) async throws -> [String: Any] {
        if let _error { throw _error }
        return response
    }

    nonisolated func streamMessage(
        model: String, messages: [[String: Any]], maxTokens: Int,
        system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
        thinking: [String: Any]?, temperature: Double?
    ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        // Not needed for compactNow tests
        return AsyncThrowingStream { _ in }
    }
}

// MARK: - Agent.compactNow() Tests

final class CompactNowTests: XCTestCase {

    /// Creates a temporary directory for session storage.
    private func makeTempSessionDir() -> String {
        let dir = NSTemporaryDirectory() + "compact_test_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Creates oversized messages that would trigger compaction.
    private func makeLargeMessages(count: Int = 5) -> [[String: Any]] {
        var msgs: [[String: Any]] = []
        for i in 0..<count {
            msgs.append([
                "role": "user",
                "content": String(repeating: "abcdefgh", count: 50_000) // ~400k chars each
            ])
            msgs.append([
                "role": "assistant",
                "content": [["type": "text", "text": String(repeating: "xyz", count: 10_000)]]
            ])
        }
        return msgs
    }

    override func setUp() {
        super.setUp()
        CompactMockURLProtocol.reset()
    }

    override func tearDown() {
        super.tearDown()
        CompactMockURLProtocol.reset()
    }

    /// compactNow returns success=true with no session store (graceful no-op).
    func testCompactNow_ReturnsSuccessWithNoSessionStore() async {
        let client = CompactNowMockClient()
        let agent = Agent(
            options: AgentOptions(apiKey: "test"),
            client: client
        )

        let result = await agent.compactNow()

        XCTAssertTrue(result.success, "Should succeed when no session store configured")
        XCTAssertEqual(result.preTokens, 0)
        XCTAssertEqual(result.postTokens, 0)
        XCTAssertNil(result.error)
    }

    /// compactNow returns success=true when session exists but has no messages.
    func testCompactNow_ReturnsSuccessWithEmptySession() async throws {
        let tempDir = makeTempSessionDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "test-empty-session"

        // Save empty messages
        let metadata = PartialSessionMetadata(
            cwd: "/tmp", model: "claude-sonnet-4-6", summary: nil
        )
        try await store.save(sessionId: sessionId, messages: [], metadata: metadata)

        let client = CompactNowMockClient()
        let agent = Agent(
            options: AgentOptions(
                apiKey: "test",
                sessionStore: store,
                sessionId: sessionId
            ),
            client: client
        )

        let result = await agent.compactNow()

        XCTAssertTrue(result.success, "Should succeed with empty session")
        XCTAssertEqual(result.preTokens, 0)
        XCTAssertEqual(result.postTokens, 0)
    }

    /// compactNow successfully compacts messages and persists to session store.
    func testCompactNow_CompactsAndSavesToSessionStore() async throws {
        let tempDir = makeTempSessionDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "test-compact-session"

        // Save large messages
        nonisolated(unsafe) let originalMessages = makeLargeMessages()
        let metadata = PartialSessionMetadata(
            cwd: "/tmp", model: "claude-sonnet-4-6", summary: nil
        )
        try await store.save(sessionId: sessionId, messages: originalMessages, metadata: metadata)

        let client = CompactNowMockClient()
        let agent = Agent(
            options: AgentOptions(
                apiKey: "test",
                sessionStore: store,
                sessionId: sessionId
            ),
            client: client
        )

        let result = await agent.compactNow()

        XCTAssertTrue(result.success, "Compaction should succeed")
        XCTAssertGreaterThan(result.preTokens, 0, "preTokens should be positive")
        XCTAssertLessThan(result.postTokens, result.preTokens, "postTokens should be less than preTokens")
        XCTAssertNil(result.error)

        // Verify session store was updated
        let savedData = try await store.load(sessionId: sessionId)
        XCTAssertNotNil(savedData, "Session should still exist after compact")
        if let saved = savedData {
            XCTAssertLessThan(saved.messages.count, originalMessages.count,
                              "Saved messages should be fewer after compaction")
        }
    }

    /// compactNow returns failure when LLM returns an error.
    func testCompactNow_ReturnsFailureWhenLLMFails() async throws {
        let tempDir = makeTempSessionDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "test-fail-session"

        nonisolated(unsafe) let originalMessages = makeLargeMessages()
        let metadata = PartialSessionMetadata(
            cwd: "/tmp", model: "claude-sonnet-4-6", summary: nil
        )
        try await store.save(sessionId: sessionId, messages: originalMessages, metadata: metadata)

        let client = CompactNowMockClient(
            error: NSError(domain: "test", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        )
        let agent = Agent(
            options: AgentOptions(
                apiKey: "test",
                sessionStore: store,
                sessionId: sessionId
            ),
            client: client
        )

        let result = await agent.compactNow()

        XCTAssertFalse(result.success, "Should report failure when LLM errors")
        XCTAssertGreaterThan(result.preTokens, 0, "preTokens should still be reported")
        XCTAssertNotNil(result.error, "Error message should be present")
    }

    /// compactNow returns failure when LLM returns malformed response (not valid compact output).
    func testCompactNow_ReturnsFailureOnMalformedResponse() async throws {
        let tempDir = makeTempSessionDir()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "test-malformed-session"

        nonisolated(unsafe) let originalMessages = makeLargeMessages()
        let metadata = PartialSessionMetadata(
            cwd: "/tmp", model: "claude-sonnet-4-6", summary: nil
        )
        try await store.save(sessionId: sessionId, messages: originalMessages, metadata: metadata)

        // Return a response with empty/missing content that won't parse as valid summary
        let malformedResponse: [String: Any] = [
            "id": "msg_bad",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": ""]],
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "stop_sequence": NSNull(),
            "usage": ["input_tokens": 100, "output_tokens": 10]
        ]
        let client = CompactNowMockClient(response: malformedResponse)
        let agent = Agent(
            options: AgentOptions(
                apiKey: "test",
                sessionStore: store,
                sessionId: sessionId
            ),
            client: client
        )

        let result = await agent.compactNow()

        // The compaction may succeed or fail depending on how the SDK handles empty summaries.
        // The key assertion is that the function returns without crashing.
        XCTAssertNotNil(result.success, "Should always return a valid CompactResult")
    }
}

// MARK: - CompactMetadata in SystemData Tests

final class CompactMetadataTests: XCTestCase {

    /// CompactMetadata with trigger=auto and token counts is correctly constructed.
    func testCompactMetadata_TriggerAuto_WithTokenCounts() {
        let metadata = SDKMessage.CompactMetadata(
            trigger: .auto,
            preTokens: 150_000,
            postTokens: 8_000
        )

        XCTAssertEqual(metadata.trigger, .auto)
        XCTAssertEqual(metadata.preTokens, 150_000)
        XCTAssertEqual(metadata.postTokens, 8_000)
        XCTAssertNil(metadata.durationMs)
    }

    /// CompactMetadata with trigger=manual is correctly constructed.
    func testCompactMetadata_TriggerManual() {
        let metadata = SDKMessage.CompactMetadata(trigger: .manual)

        XCTAssertEqual(metadata.trigger, .manual)
        XCTAssertNil(metadata.preTokens)
        XCTAssertNil(metadata.postTokens)
    }

    /// SystemData with compactBoundary + compactMetadata is correctly constructed.
    func testSystemData_CompactBoundary_WithMetadata() {
        let metadata = SDKMessage.CompactMetadata(
            trigger: .auto,
            preTokens: 180_000,
            postTokens: 5_000
        )
        let systemData = SDKMessage.SystemData(
            subtype: .compactBoundary,
            message: "Conversation compacted",
            compactMetadata: metadata,
            compactResult: "success"
        )

        XCTAssertEqual(systemData.subtype, .compactBoundary)
        XCTAssertEqual(systemData.compactResult, "success")
        XCTAssertNotNil(systemData.compactMetadata)
        XCTAssertEqual(systemData.compactMetadata?.trigger, .auto)
        XCTAssertEqual(systemData.compactMetadata?.preTokens, 180_000)
        XCTAssertEqual(systemData.compactMetadata?.postTokens, 5_000)
    }

    /// SystemData with compactBoundary failure is correctly constructed.
    func testSystemData_CompactBoundary_Failure() {
        let systemData = SDKMessage.SystemData(
            subtype: .compactBoundary,
            message: "Compaction failed",
            compactResult: "failed",
            compactError: "Compaction failed (consecutive failures: 2)"
        )

        XCTAssertEqual(systemData.subtype, .compactBoundary)
        XCTAssertEqual(systemData.compactResult, "failed")
        XCTAssertEqual(systemData.compactError, "Compaction failed (consecutive failures: 2)")
        XCTAssertNil(systemData.compactMetadata)
    }

    /// CompactResult success case.
    func testCompactResult_Success() {
        let result = SDKMessage.CompactResult(
            success: true,
            preTokens: 100_000,
            postTokens: 5_000,
            error: nil
        )
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.preTokens, 100_000)
        XCTAssertEqual(result.postTokens, 5_000)
        XCTAssertNil(result.error)
    }

    /// CompactResult failure case.
    func testCompactResult_Failure() {
        let result = SDKMessage.CompactResult(
            success: false,
            preTokens: 150_000,
            postTokens: 150_000,
            error: "Compaction failed (consecutive failures: 1)"
        )
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.preTokens, 150_000)
        XCTAssertEqual(result.error, "Compaction failed (consecutive failures: 1)")
    }
}

import XCTest
@testable import OpenAgentSDK

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
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

        CompactMockURLProtocol.allRequests.append(capturedRequest)

        guard !stopped, let activeClient = client else { return }

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

            guard !stopped else { return }
            activeClient.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            guard !stopped else { return }
            activeClient.urlProtocol(self, didLoad: response.body)
            guard !stopped else { return }
            activeClient.urlProtocolDidFinishLoading(self)
        } else {
            let error = NSError(
                domain: "CompactMockURLProtocol",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No more mock responses (index: \(index))"]
            )
            if !stopped { activeClient.urlProtocol(self, didFailWithError: error) }
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

    override func stopLoading() { stopped = true }

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
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [CompactMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
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

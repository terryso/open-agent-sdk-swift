import XCTest
@testable import OpenAgentSDK

// MARK: - ATDD RED PHASE: Story 14.2 -- Structured Log Output
//
// All tests assert EXPECTED behavior. They will FAIL until:
//   - `Agent.swift` adds Logger.shared call sites in promptImpl(), stream(), switchModel()
//   - `ToolExecutor.swift` adds Logger.shared call sites in executeSingleTool()
//   - `Compact.swift` adds Logger.shared call sites in compactConversation()
//
// The Logger API from Story 14.1 is complete. These tests verify that call sites
// emit the correct structured log entries when triggered.
//
// TDD Phase: RED (call sites not implemented yet)

// MARK: - Thread-safe log capture (reused from LoggerTests pattern)

/// Thread-safe box for capturing log lines from @Sendable closures.
private final class LogCapture: @unchecked Sendable {
    private var lines: [String] = []
    private let lock = NSLock()

    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        lines.append(line)
    }

    var all: [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return lines.count
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        lines.removeAll()
    }

    /// Parse the log entry at the given index as a JSON dictionary.
    func parsedEntry(at index: Int) throws -> [String: Any] {
        let line = all[index]
        guard let data = line.data(using: .utf8) else {
            throw NSError(domain: "LogCapture", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Cannot convert log line to data"
            ])
        }
        return try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
    }

    /// Find the first log entry matching the given event name.
    func findEntry(event: String) throws -> [String: Any]? {
        for i in 0..<count {
            let entry = try parsedEntry(at: i)
            if entry["event"] as? String == event {
                return entry
            }
        }
        return nil
    }
}

// MARK: - Mock URL Protocol for Structured Log Tests

/// Custom URLProtocol for intercepting API calls in structured log tests.
/// Reuses the same pattern as AgentLoopMockURLProtocol.
private final class StructuredLogMockURLProtocol: URLProtocol {

    nonisolated(unsafe) static var mockResponses: [String: (statusCode: Int, headers: [String: String], body: Data)] = [:]
    nonisolated(unsafe) static var sequentialResponses: [[String: Any]] = []
    nonisolated(unsafe) static var responseIndex: Int = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if !Self.sequentialResponses.isEmpty {
            let index = Self.responseIndex
            if index < Self.sequentialResponses.count {
                let responseData = Self.sequentialResponses[index]
                Self.responseIndex += 1
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
              let mock = Self.mockResponses[url] else {
            let error = NSError(domain: "StructuredLogMockURLProtocol", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No mock response for \(request.url?.absoluteString ?? "nil")"
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

    override func stopLoading() {}

    static func reset() {
        mockResponses = [:]
        sequentialResponses = []
        responseIndex = 0
    }
}

// MARK: - Test Helpers

private extension XCTestCase {

    /// Configure Logger to capture output into the given buffer at debug level.
    func configureLogCapture(_ capture: LogCapture) {
        Logger.configure(level: .debug, output: .custom { line in
            capture.append(line)
        })
    }

    /// Build a standard Anthropic API response JSON.
    func makeResponse(
        id: String = "msg_struct_001",
        model: String = "claude-sonnet-4-6",
        content: [[String: Any]] = [["type": "text", "text": "Response text"]],
        stopReason: String = "end_turn",
        inputTokens: Int = 100,
        outputTokens: Int = 200
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

    func toJsonData(_ dict: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: dict, options: [])
    }

    func registerMockResponse(statusCode: Int = 200, body: Data) {
        StructuredLogMockURLProtocol.mockResponses["https://api.anthropic.com/v1/messages"] = (
            statusCode: statusCode,
            headers: ["content-type": "application/json"],
            body: body
        )
    }

    func registerSequentialMockResponses(_ responses: [[String: Any]]) {
        StructuredLogMockURLProtocol.sequentialResponses = responses
        StructuredLogMockURLProtocol.responseIndex = 0
    }

    /// Create an Agent with mock URL protocol and Logger configured for log capture.
    func makeStructuredLogSUT(
        model: String = "claude-sonnet-4-6",
        maxTurns: Int = 10,
        maxBudgetUsd: Double? = nil,
        logLevel: LogLevel = .debug,
        capture: LogCapture
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StructuredLogMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)

        let client = AnthropicClient(apiKey: "sk-test-structured-log", baseURL: nil, urlSession: urlSession)

        // Configure Logger BEFORE creating the agent
        Logger.configure(level: logLevel, output: .custom { line in
            capture.append(line)
        })

        let options = AgentOptions(
            apiKey: "sk-test-structured-log",
            model: model,
            maxTurns: maxTurns,
            maxBudgetUsd: maxBudgetUsd,
            retryConfig: RetryConfig(maxRetries: 1, baseDelayMs: 1, maxDelayMs: 1, retryableStatusCodes: [429, 500])
        )

        return Agent(options: options, client: client)
    }
}

// MARK: - AC1: Structured Log Entry Format

final class StructuredLogFormatTests: XCTestCase {

    private var capture: LogCapture!

    override func setUp() {
        super.setUp()
        capture = LogCapture()
        Logger.reset()
        StructuredLogMockURLProtocol.reset()
    }

    override func tearDown() {
        Logger.reset()
        StructuredLogMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC1 [P0]: Given an Agent query executing, when the LLM call completes,
    /// then the structured log entry contains fields: timestamp, level, module, event, data.
    func testStructuredLogEntry_ContainsAllRequiredFields() async throws {
        let sut = makeStructuredLogSUT(capture: capture)
        let responseDict = makeResponse(stopReason: "end_turn")
        registerMockResponse(body: toJsonData(responseDict))

        _ = await sut.prompt("Test query")

        // After promptImpl runs, Logger should have emitted at least one log entry
        XCTAssertGreaterThan(capture.count, 0,
                             "Should have captured at least one log entry after LLM call")

        // Find the llm_response event
        let entry = try XCTUnwrap(capture.findEntry(event: "llm_response"),
                                  "Should find an 'llm_response' log entry")

        // Verify all required fields are present
        XCTAssertNotNil(entry["timestamp"],
                         "Log entry must contain 'timestamp' field")
        XCTAssertNotNil(entry["level"],
                         "Log entry must contain 'level' field")
        XCTAssertNotNil(entry["module"],
                         "Log entry must contain 'module' field")
        XCTAssertNotNil(entry["event"],
                         "Log entry must contain 'event' field")
        XCTAssertNotNil(entry["data"],
                         "Log entry must contain 'data' field")

        // Verify timestamp is a non-empty string (ISO 8601)
        let timestamp = entry["timestamp"] as? String ?? ""
        XCTAssertFalse(timestamp.isEmpty,
                       "Timestamp should be a non-empty ISO 8601 string")

        // Verify module is one of the expected values
        let module = entry["module"] as? String ?? ""
        XCTAssertTrue(["QueryEngine", "ToolExecutor", "Agent"].contains(module),
                       "Module should be QueryEngine, ToolExecutor, or Agent, got: \(module)")

        // Verify data is a dictionary
        let data = entry["data"] as? [String: Any]
        XCTAssertNotNil(data,
                         "Data field should be a dictionary")
    }

    /// AC1 [P0]: Given Logger is configured at .none, when an Agent query executes,
    /// then no log entries are produced (zero-overhead guarantee).
    func testNoLoggingWhenLevelIsNone() async throws {
        let sut = makeStructuredLogSUT(logLevel: .none, capture: capture)
        let responseDict = makeResponse(stopReason: "end_turn")
        registerMockResponse(body: toJsonData(responseDict))

        _ = await sut.prompt("Test query")

        XCTAssertEqual(capture.count, 0,
                       "No log entries should be captured when level is .none")
    }
}

// MARK: - AC2: LLM Response Logging at Debug Level

final class LLMResponseLogTests: XCTestCase {

    private var capture: LogCapture!

    override func setUp() {
        super.setUp()
        capture = LogCapture()
        Logger.reset()
        StructuredLogMockURLProtocol.reset()
    }

    override func tearDown() {
        Logger.reset()
        StructuredLogMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC2 [P0]: Given an Agent query with logLevel = .debug, when each LLM call turn completes,
    /// then Logger outputs event "llm_response" with data: inputTokens, outputTokens, durationMs, model.
    func testLLMResponseLogging_ContainsRequiredDataFields() async throws {
        let sut = makeStructuredLogSUT(capture: capture)
        let responseDict = makeResponse(
            stopReason: "end_turn",
            inputTokens: 1234,
            outputTokens: 567
        )
        registerMockResponse(body: toJsonData(responseDict))

        _ = await sut.prompt("Test query")

        let entry = try XCTUnwrap(capture.findEntry(event: "llm_response"),
                                  "Should find an 'llm_response' log entry")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "llm_response entry should have a 'data' dictionary")

        // Verify required data fields
        XCTAssertNotNil(data["inputTokens"],
                         "llm_response data should contain 'inputTokens'")
        XCTAssertNotNil(data["outputTokens"],
                         "llm_response data should contain 'outputTokens'")
        XCTAssertNotNil(data["durationMs"],
                         "llm_response data should contain 'durationMs'")
        XCTAssertNotNil(data["model"],
                         "llm_response data should contain 'model'")
    }

    /// AC2 [P0]: The llm_response log entry has level "debug".
    func testLLMResponseLogging_LevelIsDebug() async throws {
        let sut = makeStructuredLogSUT(capture: capture)
        let responseDict = makeResponse(stopReason: "end_turn")
        registerMockResponse(body: toJsonData(responseDict))

        _ = await sut.prompt("Test query")

        let entry = try XCTUnwrap(capture.findEntry(event: "llm_response"),
                                  "Should find an 'llm_response' log entry")

        XCTAssertEqual(entry["level"] as? String, "debug",
                       "llm_response should be logged at debug level")
    }

    /// AC2 [P1]: All data values in llm_response are strings (Logger API uses [String: String]).
    func testLLMResponseLogging_DataValuesAreStrings() async throws {
        let sut = makeStructuredLogSUT(capture: capture)
        let responseDict = makeResponse(
            stopReason: "end_turn",
            inputTokens: 1234,
            outputTokens: 567
        )
        registerMockResponse(body: toJsonData(responseDict))

        _ = await sut.prompt("Test query")

        let entry = try XCTUnwrap(capture.findEntry(event: "llm_response"),
                                  "Should find an llm_response entry")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "Should have data dictionary")

        // All data values should be strings (from Logger's [String: String] API)
        let inputTokens = try XCTUnwrap(data["inputTokens"] as? String,
                                        "inputTokens should be a string")
        XCTAssertEqual(inputTokens, "1234",
                       "inputTokens should be '1234'")

        let outputTokens = try XCTUnwrap(data["outputTokens"] as? String,
                                         "outputTokens should be a string")
        XCTAssertEqual(outputTokens, "567",
                       "outputTokens should be '567'")

        let model = try XCTUnwrap(data["model"] as? String,
                                  "model should be a string")
        XCTAssertEqual(model, "claude-sonnet-4-6",
                       "model should match the configured model name")
    }
}

// MARK: - AC3: Tool Execution Logging at Debug Level

final class ToolResultLogTests: XCTestCase {

    private var capture: LogCapture!

    override func setUp() {
        super.setUp()
        capture = LogCapture()
        Logger.reset()
    }

    override func tearDown() {
        Logger.reset()
        super.tearDown()
    }

    /// AC3 [P0]: Given a tool execution with logLevel = .debug, when the tool completes,
    /// then Logger outputs event "tool_result" with data: tool, inputSize, durationMs, outputSize.
    func testToolExecutionLogging_ContainsRequiredDataFields() async throws {
        configureLogCapture(capture)

        let mockTool = MockToolForLogTests(name: "Read", result: String(repeating: "x", count: 100))
        let block = ToolUseBlock(id: "tu_001", name: "Read", input: ["path": "/tmp/test.swift"])
        let context = ToolContext(cwd: "/tmp")

        let _ = await ToolExecutor.executeSingleTool(
            block: block,
            tool: mockTool,
            context: context
        )

        let entry = try XCTUnwrap(capture.findEntry(event: "tool_result"),
                                  "Should find a 'tool_result' log entry after tool execution")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "tool_result entry should have a 'data' dictionary")

        XCTAssertNotNil(data["tool"],
                         "tool_result data should contain 'tool'")
        XCTAssertNotNil(data["durationMs"],
                         "tool_result data should contain 'durationMs'")
        XCTAssertNotNil(data["outputSize"],
                         "tool_result data should contain 'outputSize'")
    }

    /// AC3 [P0]: The tool_result log entry has level "debug".
    func testToolExecutionLogging_LevelIsDebug() async throws {
        configureLogCapture(capture)

        let mockTool = MockToolForLogTests(name: "Grep", result: "match found")
        let block = ToolUseBlock(id: "tu_002", name: "Grep", input: ["pattern": "TODO"])
        let context = ToolContext(cwd: "/tmp")

        let _ = await ToolExecutor.executeSingleTool(
            block: block,
            tool: mockTool,
            context: context
        )

        let entry = try XCTUnwrap(capture.findEntry(event: "tool_result"),
                                  "Should find a 'tool_result' log entry")

        XCTAssertEqual(entry["level"] as? String, "debug",
                       "tool_result should be logged at debug level")
    }

    /// AC3 [P1]: The tool_result data includes outputSize as a string representation
    /// of the byte count of the tool's output.
    func testToolExecutionLogging_IncludesOutputSize() async throws {
        configureLogCapture(capture)

        let outputText = "Hello, World!" // 13 bytes in UTF-8
        let mockTool = MockToolForLogTests(name: "Read", result: outputText)
        let block = ToolUseBlock(id: "tu_003", name: "Read", input: ["path": "/tmp/test.txt"])
        let context = ToolContext(cwd: "/tmp")

        let _ = await ToolExecutor.executeSingleTool(
            block: block,
            tool: mockTool,
            context: context
        )

        let entry = try XCTUnwrap(capture.findEntry(event: "tool_result"),
                                  "Should find a 'tool_result' log entry")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "Should have data dictionary")

        let outputSize = try XCTUnwrap(data["outputSize"] as? String,
                                       "outputSize should be a string")
        XCTAssertEqual(outputSize, String(outputText.utf8.count),
                       "outputSize should be the UTF-8 byte count of the tool output as a string")
    }
}

// MARK: - AC4: Compact Event Logging at Info Level

final class CompactLogTests: XCTestCase {

    private var capture: LogCapture!

    override func setUp() {
        super.setUp()
        capture = LogCapture()
        Logger.reset()
        CompactMockURLProtocol.sequentialResponses = []
        CompactMockURLProtocol.responseIndex = 0
        CompactMockURLProtocol.allRequests = []
    }

    override func tearDown() {
        Logger.reset()
        CompactMockURLProtocol.sequentialResponses = []
        CompactMockURLProtocol.responseIndex = 0
        CompactMockURLProtocol.allRequests = []
        super.tearDown()
    }

    /// AC4 [P0]: Given auto-compact triggers during a query with logLevel >= .info,
    /// when compact completes, then Logger outputs event "compact" with data: trigger, beforeTokens, afterTokens.
    func testCompactLogging_ContainsRequiredDataFields() async throws {
        configureLogCapture(capture)

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [CompactMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)

        let client = AnthropicClient(apiKey: "sk-test", baseURL: nil, urlSession: urlSession)

        let compactResponseBody: [String: Any] = [
            "id": "msg_compact_001",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "Compacted summary of conversation"]],
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "usage": ["input_tokens": 100, "output_tokens": 50]
        ]
        let compactBodyData = try! JSONSerialization.data(withJSONObject: compactResponseBody, options: [])
        CompactMockURLProtocol.sequentialResponses = [
            (statusCode: 200, headers: ["content-type": "application/json"], body: compactBodyData)
        ]
        CompactMockURLProtocol.responseIndex = 0

        let threshold = getAutoCompactThreshold(model: "claude-sonnet-4-6")
        let charCount = (threshold + 5000) * 4
        let messages: [[String: Any]] = [
            ["role": "user", "content": String(repeating: "a", count: charCount)],
        ]
        let state = createAutoCompactState()

        let _ = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            fileCache: FileCache(),
            retryConfig: fastRetryConfig
        )

        let entry = try XCTUnwrap(capture.findEntry(event: "compact"),
                                  "Should find a 'compact' log entry after auto-compact completes")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "compact entry should have a 'data' dictionary")

        XCTAssertNotNil(data["trigger"],
                         "compact data should contain 'trigger'")
        XCTAssertNotNil(data["beforeTokens"],
                         "compact data should contain 'beforeTokens'")
        XCTAssertNotNil(data["afterTokens"],
                         "compact data should contain 'afterTokens'")
    }

    /// AC4 [P0]: The compact log entry has level "info".
    func testCompactLogging_LevelIsInfo() async throws {
        configureLogCapture(capture)

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [CompactMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)

        let client = AnthropicClient(apiKey: "sk-test", baseURL: nil, urlSession: urlSession)

        let compactResponseBody: [String: Any] = [
            "id": "msg_compact_002",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "Summary"]],
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "usage": ["input_tokens": 100, "output_tokens": 50]
        ]
        let compactBodyData = try! JSONSerialization.data(withJSONObject: compactResponseBody, options: [])
        CompactMockURLProtocol.sequentialResponses = [
            (statusCode: 200, headers: ["content-type": "application/json"], body: compactBodyData)
        ]
        CompactMockURLProtocol.responseIndex = 0

        let threshold = getAutoCompactThreshold(model: "claude-sonnet-4-6")
        let charCount = (threshold + 5000) * 4
        let messages: [[String: Any]] = [
            ["role": "user", "content": String(repeating: "a", count: charCount)],
        ]
        let state = createAutoCompactState()

        let _ = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            fileCache: FileCache(),
            retryConfig: fastRetryConfig
        )

        let entry = try XCTUnwrap(capture.findEntry(event: "compact"),
                                  "Should find a 'compact' log entry")

        XCTAssertEqual(entry["level"] as? String, "info",
                       "compact should be logged at info level")
    }

    /// AC4 [P1]: The compact data trigger is "auto" for auto-compact events.
    func testCompactLogging_TriggerIsAuto() async throws {
        configureLogCapture(capture)

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [CompactMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)

        let client = AnthropicClient(apiKey: "sk-test", baseURL: nil, urlSession: urlSession)

        let compactResponseBody: [String: Any] = [
            "id": "msg_compact_003",
            "type": "message",
            "role": "assistant",
            "content": [["type": "text", "text": "Summary"]],
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "usage": ["input_tokens": 100, "output_tokens": 50]
        ]
        let compactBodyData = try! JSONSerialization.data(withJSONObject: compactResponseBody, options: [])
        CompactMockURLProtocol.sequentialResponses = [
            (statusCode: 200, headers: ["content-type": "application/json"], body: compactBodyData)
        ]
        CompactMockURLProtocol.responseIndex = 0

        let threshold = getAutoCompactThreshold(model: "claude-sonnet-4-6")
        let charCount = (threshold + 5000) * 4
        let messages: [[String: Any]] = [
            ["role": "user", "content": String(repeating: "a", count: charCount)],
        ]
        let state = createAutoCompactState()

        let _ = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            fileCache: FileCache(),
            retryConfig: fastRetryConfig
        )

        let entry = try XCTUnwrap(capture.findEntry(event: "compact"),
                                  "Should find a compact entry")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "Should have data dictionary in compact entry")
        XCTAssertEqual(data["trigger"] as? String, "auto",
                       "compact trigger should be 'auto' for auto-compact events")
    }
}

// MARK: - AC5: Budget Exceeded Logging at Warn Level

final class BudgetExceededLogTests: XCTestCase {

    private var capture: LogCapture!

    override func setUp() {
        super.setUp()
        capture = LogCapture()
        Logger.reset()
        StructuredLogMockURLProtocol.reset()
    }

    override func tearDown() {
        Logger.reset()
        StructuredLogMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC5 [P0]: Given budget is exceeded during a query with logLevel >= .warn,
    /// then Logger outputs event "budget_exceeded" with data: costUsd, budgetUsd, turnsUsed.
    func testBudgetExceededLogging_ContainsRequiredDataFields() async throws {
        let sut = makeStructuredLogSUT(maxBudgetUsd: 0.0001, capture: capture)
        let responseDict = makeResponse(
            stopReason: "end_turn",
            inputTokens: 50000,
            outputTokens: 10000
        )
        registerMockResponse(body: toJsonData(responseDict))

        _ = await sut.prompt("Expensive query")

        let entry = try XCTUnwrap(capture.findEntry(event: "budget_exceeded"),
                                  "Should find a 'budget_exceeded' log entry when budget is exceeded")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "budget_exceeded entry should have a 'data' dictionary")

        XCTAssertNotNil(data["costUsd"],
                         "budget_exceeded data should contain 'costUsd'")
        XCTAssertNotNil(data["budgetUsd"],
                         "budget_exceeded data should contain 'budgetUsd'")
        XCTAssertNotNil(data["turnsUsed"],
                         "budget_exceeded data should contain 'turnsUsed'")
    }

    /// AC5 [P0]: The budget_exceeded log entry has level "warn".
    func testBudgetExceededLogging_LevelIsWarn() async throws {
        let sut = makeStructuredLogSUT(maxBudgetUsd: 0.0001, capture: capture)
        let responseDict = makeResponse(
            stopReason: "end_turn",
            inputTokens: 50000,
            outputTokens: 10000
        )
        registerMockResponse(body: toJsonData(responseDict))

        _ = await sut.prompt("Expensive query")

        let entry = try XCTUnwrap(capture.findEntry(event: "budget_exceeded"),
                                  "Should find a 'budget_exceeded' log entry")

        XCTAssertEqual(entry["level"] as? String, "warn",
                       "budget_exceeded should be logged at warn level")
    }

    /// AC5 [P1]: The budget_exceeded data values are correct string representations.
    func testBudgetExceededLogging_DataValuesAreCorrect() async throws {
        let budgetUsd = 0.0001
        let sut = makeStructuredLogSUT(maxBudgetUsd: budgetUsd, capture: capture)
        let responseDict = makeResponse(
            stopReason: "end_turn",
            inputTokens: 50000,
            outputTokens: 10000
        )
        registerMockResponse(body: toJsonData(responseDict))

        _ = await sut.prompt("Expensive query")

        let entry = try XCTUnwrap(capture.findEntry(event: "budget_exceeded"),
                                  "Should find a budget_exceeded entry")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "Should have data dictionary")

        let budgetStr = try XCTUnwrap(data["budgetUsd"] as? String,
                                      "budgetUsd should be a string")
        XCTAssertFalse(budgetStr.isEmpty,
                        "budgetUsd should not be empty")

        let turnsUsed = try XCTUnwrap(data["turnsUsed"] as? String,
                                      "turnsUsed should be a string")
        XCTAssertEqual(turnsUsed, "1",
                       "turnsUsed should be '1' for budget exceeded on first turn")
    }
}

// MARK: - AC6: Error Logging at Error Level

final class APIErrorLogTests: XCTestCase {

    private var capture: LogCapture!

    override func setUp() {
        super.setUp()
        capture = LogCapture()
        Logger.reset()
        StructuredLogMockURLProtocol.reset()
    }

    override func tearDown() {
        Logger.reset()
        StructuredLogMockURLProtocol.reset()
        super.tearDown()
    }

    /// AC6 [P0]: Given an API error occurs with logLevel >= .error,
    /// then Logger outputs event "api_error" with data: statusCode, message.
    func testAPIErrorLogging_ContainsRequiredDataFields() async throws {
        let sut = makeStructuredLogSUT(capture: capture)
        let errorBody: [String: Any] = [
            "error": [
                "type": "rate_limit_error",
                "message": "Rate limited"
            ]
        ]
        registerMockResponse(statusCode: 429, body: toJsonData(errorBody))

        _ = await sut.prompt("Trigger rate limit")

        let entry = try XCTUnwrap(capture.findEntry(event: "api_error"),
                                  "Should find an 'api_error' log entry when API error occurs")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "api_error entry should have a 'data' dictionary")

        XCTAssertNotNil(data["statusCode"],
                         "api_error data should contain 'statusCode'")
        XCTAssertNotNil(data["message"],
                         "api_error data should contain 'message'")
    }

    /// AC6 [P0]: The api_error log entry has level "error".
    func testAPIErrorLogging_LevelIsError() async throws {
        let sut = makeStructuredLogSUT(capture: capture)
        let errorBody: [String: Any] = [
            "error": [
                "type": "api_error",
                "message": "Internal server error"
            ]
        ]
        registerMockResponse(statusCode: 500, body: toJsonData(errorBody))

        _ = await sut.prompt("Trigger server error")

        let entry = try XCTUnwrap(capture.findEntry(event: "api_error"),
                                  "Should find an 'api_error' log entry")

        XCTAssertEqual(entry["level"] as? String, "error",
                       "api_error should be logged at error level")
    }

    /// AC6 [P1]: The api_error data includes the correct statusCode and message.
    func testAPIErrorLogging_IncludesStatusCodeAndMessage() async throws {
        let sut = makeStructuredLogSUT(capture: capture)
        let errorBody: [String: Any] = [
            "error": [
                "type": "rate_limit_error",
                "message": "Rate limited"
            ]
        ]
        registerMockResponse(statusCode: 429, body: toJsonData(errorBody))

        _ = await sut.prompt("Trigger rate limit")

        let entry = try XCTUnwrap(capture.findEntry(event: "api_error"),
                                  "Should find an api_error entry")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "Should have data dictionary")

        let statusCode = try XCTUnwrap(data["statusCode"] as? String,
                                       "statusCode should be a string")
        XCTAssertEqual(statusCode, "429",
                       "statusCode should be '429'")

        let message = try XCTUnwrap(data["message"] as? String,
                                    "message should be a string")
        XCTAssertTrue(message.contains("Rate limited"),
                      "message should contain the error text")
    }
}

// MARK: - AC7: Model Switch Logging at Info Level

final class ModelSwitchLogTests: XCTestCase {

    private var capture: LogCapture!

    override func setUp() {
        super.setUp()
        capture = LogCapture()
        Logger.reset()
    }

    override func tearDown() {
        Logger.reset()
        super.tearDown()
    }

    /// AC7 [P0]: Given agent.switchModel() is called with logLevel >= .info,
    /// then Logger outputs event "model_switch" with data: from, to.
    func testModelSwitchLogging_ContainsRequiredDataFields() async throws {
        configureLogCapture(capture)

        let options = AgentOptions(
            apiKey: "sk-test-model-switch",
            model: "claude-sonnet-4-6"
        )
        let sut = Agent(options: options)

        try sut.switchModel("claude-opus-4-6")

        let entry = try XCTUnwrap(capture.findEntry(event: "model_switch"),
                                  "Should find a 'model_switch' log entry after switchModel()")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "model_switch entry should have a 'data' dictionary")

        XCTAssertNotNil(data["from"],
                         "model_switch data should contain 'from'")
        XCTAssertNotNil(data["to"],
                         "model_switch data should contain 'to'")
    }

    /// AC7 [P0]: The model_switch log entry has level "info".
    func testModelSwitchLogging_LevelIsInfo() async throws {
        configureLogCapture(capture)

        let options = AgentOptions(
            apiKey: "sk-test-model-switch",
            model: "claude-sonnet-4-6"
        )
        let sut = Agent(options: options)

        try sut.switchModel("claude-opus-4-6")

        let entry = try XCTUnwrap(capture.findEntry(event: "model_switch"),
                                  "Should find a 'model_switch' log entry")

        XCTAssertEqual(entry["level"] as? String, "info",
                       "model_switch should be logged at info level")
    }

    /// AC7 [P1]: The model_switch data "from" and "to" contain the correct model names.
    func testModelSwitchLogging_DataFromAndToAreCorrect() async throws {
        configureLogCapture(capture)

        let options = AgentOptions(
            apiKey: "sk-test-model-switch",
            model: "claude-sonnet-4-6"
        )
        let sut = Agent(options: options)

        try sut.switchModel("claude-opus-4-6")

        let entry = try XCTUnwrap(capture.findEntry(event: "model_switch"),
                                  "Should find a model_switch entry")

        let data = try XCTUnwrap(entry["data"] as? [String: Any],
                                 "Should have data dictionary")

        XCTAssertEqual(data["from"] as? String, "claude-sonnet-4-6",
                       "'from' should be the original model")
        XCTAssertEqual(data["to"] as? String, "claude-opus-4-6",
                       "'to' should be the new model")
    }
}

// MARK: - Mock Tool for Structured Log Tests

/// Mock tool that returns a known result string, used for tool execution logging tests.
private struct MockToolForLogTests: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Mock tool for structured log tests"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = true
    let result: String

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(toolUseId: context.toolUseId, content: result, isError: false)
    }
}

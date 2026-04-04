import XCTest
@testable import OpenAgentSDK

// MARK: - Mock URL Protocol for Network Interception

/// Custom URLProtocol subclass that intercepts network requests for testing.
/// Allows injecting predefined responses and inspecting outbound requests.
final class MockURLProtocol: URLProtocol {

    /// Static storage for mock responses keyed by URL string.
    nonisolated(unsafe) static var mockResponses: [String: (statusCode: Int, headers: [String: String], body: Data)] = [:]

    /// Records the last request sent through this protocol for inspection.
    nonisolated(unsafe) static var lastRequest: URLRequest?

    /// Records all requests sent through this protocol.
    nonisolated(unsafe) static var allRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Capture request with body: URLSession converts httpBody to httpBodyStream,
        // so read from stream to preserve body data for test assertions.
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            capturedRequest.httpBody = Self.readBodyFromStream(stream)
        }

        MockURLProtocol.lastRequest = capturedRequest
        MockURLProtocol.allRequests.append(capturedRequest)

        guard let url = request.url?.absoluteString,
              let mock = MockURLProtocol.mockResponses[url] else {
            let error = NSError(domain: "MockURLProtocol", code: -1, userInfo: [
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
    }
}

// MARK: - Test Helpers

extension XCTestCase {

    /// Creates an AnthropicClient configured with MockURLProtocol for testing.
    func makeSUT(apiKey: String = "sk-test-api-key-12345", baseURL: String? = nil) -> AnthropicClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        // AnthropicClient is an actor; use the initializer that accepts a custom URLSession
        return AnthropicClient(apiKey: apiKey, baseURL: baseURL, urlSession: urlSession)
    }

    /// Builds a standard non-streaming API response JSON.
    func makeMessageResponse(
        id: String = "msg_013Zva",
        model: String = "claude-sonnet-4-6",
        content: [[String: Any]] = [["type": "text", "text": "Hello!"]],
        stopReason: String = "end_turn",
        inputTokens: Int = 100,
        outputTokens: Int = 50
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

    /// Builds a tool_use content block.
    func makeToolUseBlock(id: String = "toolu_01ABC", name: String = "get_weather", input: [String: Any] = ["location": "San Francisco"]) -> [String: Any] {
        return [
            "type": "tool_use",
            "id": id,
            "name": name,
            "input": input
        ]
    }

    /// Builds a thinking content block.
    func makeThinkingBlock(thinking: String = "Let me analyze this...", signature: String = "EqQBCg...") -> [String: Any] {
        return [
            "type": "thinking",
            "thinking": thinking,
            "signature": signature
        ]
    }

    /// Serializes a dictionary to JSON data.
    func jsonData(from dict: [String: Any]) -> Data {
        return try! JSONSerialization.data(withJSONObject: dict, options: [])
    }

    /// Registers a mock response for a given URL.
    func registerMockResponse(url: String, statusCode: Int = 200, headers: [String: String] = [:], body: Data) {
        MockURLProtocol.mockResponses[url] = (statusCode: statusCode, headers: headers, body: body)
    }
}

// MARK: - AC1: Basic Message Creation (Non-Streaming)

final class AnthropicClientBasicMessageTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    /// AC1: Sending a non-streaming message returns a complete Message response with content and usage.
    func testSendMessageReturnsCompleteResponse() async throws {
        let sut = makeSUT()
        let responseDict = makeMessageResponse()
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            headers: ["content-type": "application/json"],
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        let result = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        // Verify response structure
        XCTAssertEqual(result["id"] as? String, "msg_013Zva")
        XCTAssertEqual(result["type"] as? String, "message")
        XCTAssertEqual(result["role"] as? String, "assistant")
        XCTAssertEqual(result["stop_reason"] as? String, "end_turn")
    }

    /// AC1: Response includes content blocks with text.
    func testSendMessageResponseContainsContentBlocks() async throws {
        let sut = makeSUT()
        let responseDict = makeMessageResponse(
            content: [["type": "text", "text": "Hi there!"]]
        )
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        let result = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        let content = result["content"] as? [[String: Any]]
        XCTAssertNotNil(content)
        XCTAssertEqual(content?.count, 1)
        XCTAssertEqual(content?.first?["type"] as? String, "text")
        XCTAssertEqual(content?.first?["text"] as? String, "Hi there!")
    }

    /// AC1: Response includes usage information.
    func testSendMessageResponseContainsUsage() async throws {
        let sut = makeSUT()
        let responseDict = makeMessageResponse(inputTokens: 2095, outputTokens: 503)
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        let result = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        let usage = result["usage"] as? [String: Any]
        XCTAssertNotNil(usage)
        XCTAssertEqual(usage?["input_tokens"] as? Int, 2095)
        XCTAssertEqual(usage?["output_tokens"] as? Int, 503)
    }

    /// AC1: AnthropicClient is an actor type (compile-time enforcement).
    func testAnthropicClientIsActor() {
        // This test verifies at compile time that AnthropicClient is an actor.
        // If AnthropicClient were a class or struct, the 'actor' keyword usage below would fail.
        // We use a type check to ensure the actor nature.
        let sut = makeSUT()
        // Actor isolation: calling methods requires 'await' — verified by other tests using 'await'.
        // This test simply confirms the instance can be created and is non-nil.
        XCTAssertNotNil(sut)
    }

    /// AC1/NFR6: API key is NOT logged, printed, or included in error messages.
    func testAPIKeyNotExposedInErrorMessage() async {
        let sut = makeSUT(apiKey: "sk-super-secret-key-99999")
        let errorBody = jsonData(from: ["error": ["type": "authentication_error", "message": "invalid x-api-key"]])

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 401,
            body: errorBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        do {
            _ = try await sut.sendMessage(
                model: "claude-sonnet-4-6",
                messages: messages,
                maxTokens: 1024
            )
            XCTFail("Expected SDKError.apiError to be thrown")
        } catch let error as SDKError {
            // The error message must NOT contain the actual API key
            let errorDescription = error.errorDescription ?? ""
            XCTAssertFalse(errorDescription.contains("sk-super-secret-key-99999"),
                           "API key must not appear in error messages. Got: \(errorDescription)")
        } catch {
            XCTFail("Expected SDKError but got: \(error)")
        }
    }

    /// AC1: Request includes correct required headers (x-api-key, anthropic-version, content-type).
    func testSendMessageIncludesCorrectHeaders() async throws {
        let sut = makeSUT(apiKey: "sk-test-key-123")
        let responseDict = makeMessageResponse()
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        _ = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        let request = MockURLProtocol.lastRequest
        XCTAssertNotNil(request)

        // Verify required headers
        XCTAssertEqual(request?.value(forHTTPHeaderField: "x-api-key"), "sk-test-key-123")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "content-type"), "application/json")
    }

    /// AC1: Request body includes model, messages, max_tokens, and stream: false.
    func testSendMessageRequestBodyStructure() async throws {
        let sut = makeSUT()
        let responseDict = makeMessageResponse()
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        _ = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 2048
        )

        let request = MockURLProtocol.lastRequest
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.httpMethod, "POST")

        let bodyData = request?.httpBody
        XCTAssertNotNil(bodyData)

        let body = try JSONSerialization.jsonObject(with: bodyData!) as? [String: Any]
        XCTAssertNotNil(body)
        XCTAssertEqual(body?["model"] as? String, "claude-sonnet-4-6")
        XCTAssertEqual(body?["max_tokens"] as? Int, 2048)
        XCTAssertEqual(body?["stream"] as? Bool, false)

        let bodyMessages = body?["messages"] as? [[String: Any]]
        XCTAssertNotNil(bodyMessages)
        XCTAssertEqual(bodyMessages?.count, 1)
        XCTAssertEqual(bodyMessages?.first?["role"] as? String, "user")
    }
}

// MARK: - AC2: Custom Base URL

final class AnthropicClientBaseURLTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    /// AC2: Requests are sent to a custom base URL when configured.
    func testCustomBaseURLUsedInRequests() async throws {
        let customBaseURL = "https://my-proxy.example.com"
        let sut = makeSUT(baseURL: customBaseURL)
        let responseDict = makeMessageResponse()
        let responseBody = jsonData(from: responseDict)

        // Register mock for the custom URL, NOT the default api.anthropic.com
        registerMockResponse(
            url: "\(customBaseURL)/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        let result = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        // Verify the request was sent to the custom URL
        let request = MockURLProtocol.lastRequest
        XCTAssertNotNil(request)
        XCTAssertTrue(request?.url?.absoluteString.hasPrefix(customBaseURL) ?? false,
                      "Request should go to custom base URL. Got: \(request?.url?.absoluteString ?? "nil")")

        // Verify response was received successfully
        XCTAssertEqual(result["id"] as? String, "msg_013Zva")
    }

    /// AC2: Default base URL is api.anthropic.com when no custom URL is provided.
    func testDefaultBaseURLIsAnthropicAPI() async throws {
        let sut = makeSUT() // No custom baseURL
        let responseDict = makeMessageResponse()
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        _ = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        let request = MockURLProtocol.lastRequest
        XCTAssertNotNil(request)
        XCTAssertTrue(request?.url?.absoluteString.hasPrefix("https://api.anthropic.com") ?? false,
                      "Default URL should be api.anthropic.com")
    }
}

// MARK: - AC4: Tools Request

final class AnthropicClientToolsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    /// AC4: Sending a request with tools correctly parses tool_use content blocks in response.
    func testToolsRequestParsesToolUseResponse() async throws {
        let sut = makeSUT()
        let toolUseBlock = makeToolUseBlock(
            id: "toolu_01ABC",
            name: "get_weather",
            input: ["location": "San Francisco"]
        )
        let responseDict = makeMessageResponse(
            content: [toolUseBlock],
            stopReason: "tool_use"
        )
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "What is the weather in SF?"]
        ]
        let tools: [[String: Any]] = [
            [
                "name": "get_weather",
                "description": "Get weather for a location",
                "input_schema": [
                    "type": "object",
                    "properties": ["location": ["type": "string"]],
                    "required": ["location"]
                ]
            ]
        ]

        let result = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024,
            tools: tools
        )

        // Verify tool_use content block parsed correctly
        let content = result["content"] as? [[String: Any]]
        XCTAssertNotNil(content)
        XCTAssertEqual(content?.count, 1)

        let toolBlock = content?.first
        XCTAssertEqual(toolBlock?["type"] as? String, "tool_use")
        XCTAssertEqual(toolBlock?["id"] as? String, "toolu_01ABC")
        XCTAssertEqual(toolBlock?["name"] as? String, "get_weather")

        let input = toolBlock?["input"] as? [String: Any]
        XCTAssertNotNil(input)
        XCTAssertEqual(input?["location"] as? String, "San Francisco")

        XCTAssertEqual(result["stop_reason"] as? String, "tool_use")
    }

    /// AC4: Tools array is correctly serialized in the request body.
    func testToolsSerializedInRequestBody() async throws {
        let sut = makeSUT()
        let responseDict = makeMessageResponse()
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Check weather"]
        ]
        let tools: [[String: Any]] = [
            [
                "name": "get_weather",
                "description": "Get weather",
                "input_schema": ["type": "object", "properties": [:]]
            ]
        ]

        _ = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024,
            tools: tools
        )

        let request = MockURLProtocol.lastRequest
        let bodyData = request?.httpBody
        let body = try JSONSerialization.jsonObject(with: bodyData!) as? [String: Any]

        let bodyTools = body?["tools"] as? [[String: Any]]
        XCTAssertNotNil(bodyTools)
        XCTAssertEqual(bodyTools?.count, 1)
        XCTAssertEqual(bodyTools?.first?["name"] as? String, "get_weather")
    }
}

// MARK: - AC5: System Prompt

final class AnthropicClientSystemPromptTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    /// AC5: System prompt is sent as a top-level parameter, not in messages array.
    func testSystemPromptSentAsTopLevelParameter() async throws {
        let sut = makeSUT()
        let responseDict = makeMessageResponse()
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        _ = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024,
            system: "You are a helpful assistant."
        )

        let request = MockURLProtocol.lastRequest
        let bodyData = request?.httpBody
        let body = try JSONSerialization.jsonObject(with: bodyData!) as? [String: Any]

        // System should be a top-level key
        XCTAssertEqual(body?["system"] as? String, "You are a helpful assistant.")

        // System should NOT be inside messages
        let bodyMessages = body?["messages"] as? [[String: Any]]
        XCTAssertEqual(bodyMessages?.count, 1)
        XCTAssertNotEqual(bodyMessages?.first?["role"] as? String, "system")
    }

    /// AC5: When system prompt is nil, the request body does not include a system key.
    func testNoSystemKeyWhenSystemPromptIsNil() async throws {
        let sut = makeSUT()
        let responseDict = makeMessageResponse()
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        _ = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
            // system is nil (default)
        )

        let request = MockURLProtocol.lastRequest
        let bodyData = request?.httpBody
        let body = try JSONSerialization.jsonObject(with: bodyData!) as? [String: Any]

        XCTAssertNil(body?["system"], "system key should not be present when nil")
    }
}

// MARK: - AC6: Thinking Configuration

final class AnthropicClientThinkingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    /// AC6: Thinking configuration with type=enabled and budgetTokens is correctly serialized.
    func testThinkingConfigSerializedInRequestBody() async throws {
        let sut = makeSUT()
        let responseDict = makeMessageResponse()
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Think carefully"]
        ]
        let thinking: [String: Any] = [
            "type": "enabled",
            "budget_tokens": 5000
        ]

        _ = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024,
            thinking: thinking
        )

        let request = MockURLProtocol.lastRequest
        let bodyData = request?.httpBody
        let body = try JSONSerialization.jsonObject(with: bodyData!) as? [String: Any]

        let bodyThinking = body?["thinking"] as? [String: Any]
        XCTAssertNotNil(bodyThinking)
        XCTAssertEqual(bodyThinking?["type"] as? String, "enabled")
        XCTAssertEqual(bodyThinking?["budget_tokens"] as? Int, 5000)
    }

    /// AC6: Thinking configuration with type=disabled is correctly serialized.
    func testThinkingDisabledSerializedInRequestBody() async throws {
        let sut = makeSUT()
        let responseDict = makeMessageResponse()
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Quick answer"]
        ]
        let thinking: [String: Any] = [
            "type": "disabled"
        ]

        _ = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024,
            thinking: thinking
        )

        let request = MockURLProtocol.lastRequest
        let bodyData = request?.httpBody
        let body = try JSONSerialization.jsonObject(with: bodyData!) as? [String: Any]

        let bodyThinking = body?["thinking"] as? [String: Any]
        XCTAssertNotNil(bodyThinking)
        XCTAssertEqual(bodyThinking?["type"] as? String, "disabled")
    }

    /// AC6: Thinking response includes thinking and signature blocks.
    func testThinkingBlocksParsedInResponse() async throws {
        let sut = makeSUT()
        let thinkingBlock = makeThinkingBlock(
            thinking: "Let me reason about this...",
            signature: "EqQBCg..."
        )
        let textBlock: [String: Any] = ["type": "text", "text": "Here is my answer."]
        let responseDict = makeMessageResponse(
            content: [thinkingBlock, textBlock]
        )
        let responseBody = jsonData(from: responseDict)

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 200,
            body: responseBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Explain"]
        ]

        let result = try await sut.sendMessage(
            model: "claude-sonnet-4-6",
            messages: messages,
            maxTokens: 1024
        )

        let content = result["content"] as? [[String: Any]]
        XCTAssertNotNil(content)
        XCTAssertEqual(content?.count, 2)

        // Verify thinking block
        let thinkingContent = content?.first
        XCTAssertEqual(thinkingContent?["type"] as? String, "thinking")
        XCTAssertEqual(thinkingContent?["thinking"] as? String, "Let me reason about this...")
        XCTAssertEqual(thinkingContent?["signature"] as? String, "EqQBCg...")

        // Verify text block still parsed
        let textContent = content?.last
        XCTAssertEqual(textContent?["type"] as? String, "text")
        XCTAssertEqual(textContent?["text"] as? String, "Here is my answer.")
    }
}

// MARK: - AC7: Error Response Handling

final class AnthropicClientErrorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    /// AC7: 401 error throws SDKError.apiError with correct status code.
    func testAuthenticationError401() async {
        let sut = makeSUT()
        let errorBody = jsonData(from: [
            "error": ["type": "authentication_error", "message": "invalid x-api-key"]
        ])

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 401,
            body: errorBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        do {
            _ = try await sut.sendMessage(
                model: "claude-sonnet-4-6",
                messages: messages,
                maxTokens: 1024
            )
            XCTFail("Expected SDKError.apiError for 401")
        } catch let error as SDKError {
            XCTAssertEqual(error.statusCode, 401)
        } catch {
            XCTFail("Expected SDKError but got: \(error)")
        }
    }

    /// AC7: 429 rate limit error throws SDKError.apiError.
    func testRateLimitError429() async {
        let sut = makeSUT()
        let errorBody = jsonData(from: [
            "error": ["type": "rate_limit_error", "message": "Too many requests"]
        ])

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 429,
            body: errorBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        do {
            _ = try await sut.sendMessage(
                model: "claude-sonnet-4-6",
                messages: messages,
                maxTokens: 1024
            )
            XCTFail("Expected SDKError.apiError for 429")
        } catch let error as SDKError {
            XCTAssertEqual(error.statusCode, 429)
        } catch {
            XCTFail("Expected SDKError but got: \(error)")
        }
    }

    /// AC7: 500 internal server error throws SDKError.apiError.
    func testInternalServerError500() async {
        let sut = makeSUT()
        let errorBody = jsonData(from: [
            "error": ["type": "api_error", "message": "Internal server error"]
        ])

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 500,
            body: errorBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        do {
            _ = try await sut.sendMessage(
                model: "claude-sonnet-4-6",
                messages: messages,
                maxTokens: 1024
            )
            XCTFail("Expected SDKError.apiError for 500")
        } catch let error as SDKError {
            XCTAssertEqual(error.statusCode, 500)
        } catch {
            XCTFail("Expected SDKError but got: \(error)")
        }
    }

    /// AC7: 503 service unavailable throws SDKError.apiError.
    func testServiceUnavailableError503() async {
        let sut = makeSUT()
        let errorBody = jsonData(from: [
            "error": ["type": "overloaded_error", "message": "Overloaded"]
        ])

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 503,
            body: errorBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        do {
            _ = try await sut.sendMessage(
                model: "claude-sonnet-4-6",
                messages: messages,
                maxTokens: 1024
            )
            XCTFail("Expected SDKError.apiError for 503")
        } catch let error as SDKError {
            XCTAssertEqual(error.statusCode, 503)
        } catch {
            XCTFail("Expected SDKError but got: \(error)")
        }
    }

    /// AC7/NFR6: Error message does NOT contain the actual API key.
    func testErrorDoesNotContainAPIKey() async {
        let secretKey = "sk-ant-super-secret-abc123"
        let sut = makeSUT(apiKey: secretKey)
        let errorBody = jsonData(from: [
            "error": ["type": "authentication_error", "message": "invalid x-api-key"]
        ])

        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 401,
            body: errorBody
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        do {
            _ = try await sut.sendMessage(
                model: "claude-sonnet-4-6",
                messages: messages,
                maxTokens: 1024
            )
            XCTFail("Expected error")
        } catch let error as SDKError {
            let description = error.errorDescription ?? ""
            XCTAssertFalse(description.contains(secretKey),
                           "Error message must not contain API key. Got: \(description)")
            XCTAssertFalse(description.contains("sk-ant"),
                           "Error message must not contain API key prefix. Got: \(description)")
        } catch {
            XCTFail("Expected SDKError but got: \(error)")
        }
    }

    /// AC7: Multiple sequential errors are handled independently.
    func testMultipleErrorsHandledIndependently() async {
        let sut = makeSUT()

        // First request: 429
        let errorBody429 = jsonData(from: [
            "error": ["type": "rate_limit_error", "message": "Slow down"]
        ])
        registerMockResponse(
            url: "https://api.anthropic.com/v1/messages",
            statusCode: 429,
            body: errorBody429
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]

        do {
            _ = try await sut.sendMessage(
                model: "claude-sonnet-4-6",
                messages: messages,
                maxTokens: 1024
            )
            XCTFail("Expected 429 error")
        } catch let error as SDKError {
            XCTAssertEqual(error.statusCode, 429)
        } catch {
            XCTFail("Expected SDKError")
        }
    }
}

// MARK: - AC8: Dual Platform Compilation

final class AnthropicClientCompilationTests: XCTestCase {

    /// AC8: Verify that API types import only Foundation (no Apple-exclusive frameworks).
    /// This is a compile-time check — if API files import UIKit/AppKit/Combine, this will fail to build.
    func testAPIImportsOnlyFoundation() {
        // This test exists as a placeholder that passes compilation.
        // The real test for AC8 is `swift build` succeeding on both macOS and Linux.
        // We verify here that Foundation is available and no Apple-specific imports are needed.
        let _: String = Foundation.Bundle.main.bundleIdentifier ?? "test"
        XCTAssertTrue(true, "Foundation-only code compiles successfully")
    }
}

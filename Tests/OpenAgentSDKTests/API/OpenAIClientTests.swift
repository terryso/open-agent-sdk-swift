import XCTest
@testable import OpenAgentSDK

final class OpenAIClientTests: XCTestCase {

    // MARK: - Helpers

    private func makeOpenAISUT(
        apiKey: String = "test-key-123",
        baseURL: String = "https://api.test.com/v1"
    ) -> OpenAIClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        return OpenAIClient(apiKey: apiKey, baseURL: baseURL, urlSession: urlSession)
    }

    private func makeOpenAIResponse(
        id: String = "chatcmpl-123",
        model: String = "gpt-4",
        content: String? = "Hello!",
        toolCalls: [[String: Any]]? = nil,
        finishReason: String = "stop",
        promptTokens: Int = 10,
        completionTokens: Int = 20
    ) -> Data {
        var message: [String: Any] = ["role": "assistant"]
        if let content {
            message["content"] = content
        }
        if let toolCalls {
            message["tool_calls"] = toolCalls
        }
        let response: [String: Any] = [
            "id": id,
            "object": "chat.completion",
            "model": model,
            "choices": [
                [
                    "index": 0,
                    "message": message,
                    "finish_reason": finishReason,
                ]
            ],
            "usage": [
                "prompt_tokens": promptTokens,
                "completion_tokens": completionTokens,
                "total_tokens": promptTokens + completionTokens,
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: response, options: [])
    }

    private func makeOpenAIStreamChunk(
        id: String = "chatcmpl-123",
        delta: [String: Any],
        finishReason: String? = nil
    ) -> String {
        var choice: [String: Any] = ["index": 0, "delta": delta]
        if let finishReason {
            choice["finish_reason"] = finishReason
        } else {
            choice["finish_reason"] = NSNull()
        }
        let chunk: [String: Any] = [
            "id": id,
            "object": "chat.completion.chunk",
            "choices": [choice],
        ]
        let data = try! JSONSerialization.data(withJSONObject: chunk, options: [])
        return "data: \(String(data: data, encoding: .utf8)!)"
    }

    private func registerMock(url: String, statusCode: Int = 200, body: Data) {
        MockURLProtocol.mockResponses[url] = (statusCode: statusCode, headers: ["Content-Type": "application/json"], body: body)
    }

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Initialization

    func testInit_defaultBaseURL() {
        let client = makeOpenAISUT(baseURL: "https://api.openai.com/v1")
        // Should not crash — valid URL
        let _ = client
    }

    func testInit_invalidBaseURL_fallsBack() {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)
        // Invalid URL should fall back to default
        let client = OpenAIClient(apiKey: "key", baseURL: "not a valid url:// $%", urlSession: urlSession)
        let _ = client
    }

    // MARK: - sendMessage (non-streaming)

    func testSendMessage_textResponse() async throws {
        let responseBody = makeOpenAIResponse(content: "Hi there!")
        registerMock(url: "https://api.test.com/v1/chat/completions", body: responseBody)

        let client = makeOpenAISUT()
        let result = try await client.sendMessage(
            model: "gpt-4",
            messages: [["role": "user", "content": "hello"]],
            maxTokens: 1024
        )

        XCTAssertEqual(result["type"] as? String, "message")
        XCTAssertEqual(result["role"] as? String, "assistant")

        let content = result["content"] as? [[String: Any]]
        XCTAssertEqual(content?.first?["text"] as? String, "Hi there!")
    }

    func testSendMessage_toolUseResponse() async throws {
        let toolCalls: [[String: Any]] = [
            [
                "id": "call_abc",
                "type": "function",
                "function": [
                    "name": "get_weather",
                    "arguments": "{\"city\": \"SF\"}",
                ],
            ]
        ]
        let responseBody = makeOpenAIResponse(content: nil, toolCalls: toolCalls, finishReason: "tool_calls")
        registerMock(url: "https://api.test.com/v1/chat/completions", body: responseBody)

        let client = makeOpenAISUT()
        let result = try await client.sendMessage(
            model: "gpt-4",
            messages: [["role": "user", "content": "weather?"]],
            maxTokens: 1024
        )

        let content = result["content"] as? [[String: Any]]
        let toolUse = content?.first { $0["type"] as? String == "tool_use" }
        XCTAssertEqual(toolUse?["name"] as? String, "get_weather")
        XCTAssertEqual(toolUse?["id"] as? String, "call_abc")

        let input = toolUse?["input"] as? [String: Any]
        XCTAssertEqual(input?["city"] as? String, "SF")
    }

    func testSendMessage_usageMapping() async throws {
        let responseBody = makeOpenAIResponse(promptTokens: 100, completionTokens: 50)
        registerMock(url: "https://api.test.com/v1/chat/completions", body: responseBody)

        let client = makeOpenAISUT()
        let result = try await client.sendMessage(
            model: "gpt-4",
            messages: [["role": "user", "content": "hi"]],
            maxTokens: 100
        )

        let usage = result["usage"] as? [String: Any]
        XCTAssertEqual(usage?["input_tokens"] as? Int, 100)
        XCTAssertEqual(usage?["output_tokens"] as? Int, 50)
    }

    func testSendMessage_stopReasonMapping() async throws {
        let responseBody = makeOpenAIResponse(finishReason: "stop")
        registerMock(url: "https://api.test.com/v1/chat/completions", body: responseBody)

        let client = makeOpenAISUT()
        let result = try await client.sendMessage(
            model: "gpt-4",
            messages: [["role": "user", "content": "hi"]],
            maxTokens: 100
        )

        XCTAssertEqual(result["stop_reason"] as? String, "end_turn")
    }

    func testSendMessage_httpError_throws() async {
        let errorBody = "{\"error\": {\"message\": \"Invalid API key\"}}".data(using: .utf8)!
        registerMock(
            url: "https://api.test.com/v1/chat/completions",
            statusCode: 401,
            body: errorBody
        )

        let client = makeOpenAISUT()
        do {
            _ = try await client.sendMessage(
                model: "gpt-4",
                messages: [["role": "user", "content": "hi"]],
                maxTokens: 100
            )
            XCTFail("Should have thrown")
        } catch let error as SDKError {
            if case .apiError(let code, _) = error {
                XCTAssertEqual(code, 401)
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendMessage_apiKeyScrubbedFromError() async {
        let apiKey = "secret-key-999"
        let errorBody = "{\"error\": {\"message\": \"Bad key secret-key-999\"}}".data(using: .utf8)!
        registerMock(
            url: "https://api.test.com/v1/chat/completions",
            statusCode: 401,
            body: errorBody
        )

        let client = makeOpenAISUT(apiKey: apiKey)
        do {
            _ = try await client.sendMessage(
                model: "gpt-4",
                messages: [],
                maxTokens: 100
            )
        } catch let error as SDKError {
            // API key should be scrubbed from error messages
            XCTAssertFalse(error.message.contains(apiKey), "Error message should not contain API key")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendMessage_setsBearerAuth() async throws {
        let responseBody = makeOpenAIResponse()
        registerMock(url: "https://api.test.com/v1/chat/completions", body: responseBody)

        let client = makeOpenAISUT(apiKey: "my-key-456")
        _ = try await client.sendMessage(
            model: "gpt-4",
            messages: [],
            maxTokens: 100
        )

        let authHeader = MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer my-key-456")
    }

    func testSendMessage_setsJSONContentType() async throws {
        let responseBody = makeOpenAIResponse()
        registerMock(url: "https://api.test.com/v1/chat/completions", body: responseBody)

        let client = makeOpenAISUT()
        _ = try await client.sendMessage(
            model: "gpt-4",
            messages: [],
            maxTokens: 100
        )

        let contentType = MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "content-type")
        XCTAssertEqual(contentType, "application/json")
    }

    // MARK: - streamMessage

    func testStreamMessage_textStream() async throws {
        let chunk1 = makeOpenAIStreamChunk(delta: ["content": "Hello"])
        let chunk2 = makeOpenAIStreamChunk(delta: ["content": " world"], finishReason: "stop")
        let streamBody = "\(chunk1)\n\n\(chunk2)\n\ndata: [DONE]\n\n".data(using: .utf8)!
        registerMock(url: "https://api.test.com/v1/chat/completions", body: streamBody)

        let client = makeOpenAISUT()
        let stream = try await client.streamMessage(
            model: "gpt-4",
            messages: [["role": "user", "content": "hi"]],
            maxTokens: 100
        )

        var events: [SSEEvent] = []
        for try await event in stream {
            events.append(event)
        }

        // Should have: messageStart, contentBlockStart, contentBlockDelta(s), contentBlockStop, messageDelta, messageStop
        XCTAssertTrue(events.count >= 4, "Should have multiple events, got \(events.count)")

        // First event should be messageStart
        if case .messageStart = events.first {} else {
            XCTFail("First event should be messageStart")
        }

        // Last event should be messageStop
        if case .messageStop = events.last {} else {
            XCTFail("Last event should be messageStop")
        }
    }

    func testStreamMessage_toolCallStream() async throws {
        let chunk1 = makeOpenAIStreamChunk(delta: [
            "tool_calls": [[
                "index": 0,
                "id": "call_1",
                "type": "function",
                "function": ["name": "search", "arguments": ""],
            ]]
        ])
        let chunk2 = makeOpenAIStreamChunk(delta: [
            "tool_calls": [[
                "index": 0,
                "function": ["arguments": "{\"q\": \"test\"}"],
            ]]
        ])
        let chunk3 = makeOpenAIStreamChunk(delta: [:], finishReason: "tool_calls")
        let streamBody = "\(chunk1)\n\n\(chunk2)\n\n\(chunk3)\n\ndata: [DONE]\n\n".data(using: .utf8)!
        registerMock(url: "https://api.test.com/v1/chat/completions", body: streamBody)

        let client = makeOpenAISUT()
        let stream = try await client.streamMessage(
            model: "gpt-4",
            messages: [["role": "user", "content": "search"]],
            maxTokens: 100
        )

        var events: [SSEEvent] = []
        for try await event in stream {
            events.append(event)
        }

        // Should contain tool_use contentBlockStart
        let hasToolBlockStart = events.contains { event in
            if case .contentBlockStart(_, let block) = event {
                return block["type"] as? String == "tool_use"
            }
            return false
        }
        XCTAssertTrue(hasToolBlockStart, "Should contain tool_use contentBlockStart")
    }

    // MARK: - Stop Reason Mapping

    func testStopReason_stop() async throws {
        let body = makeOpenAIResponse(finishReason: "stop")
        registerMock(url: "https://api.test.com/v1/chat/completions", body: body)
        let result = try await makeOpenAISUT().sendMessage(model: "gpt-4", messages: [], maxTokens: 100)
        XCTAssertEqual(result["stop_reason"] as? String, "end_turn")
    }

    func testStopReason_toolCalls() async throws {
        let body = makeOpenAIResponse(finishReason: "tool_calls")
        registerMock(url: "https://api.test.com/v1/chat/completions", body: body)
        let result = try await makeOpenAISUT().sendMessage(model: "gpt-4", messages: [], maxTokens: 100)
        XCTAssertEqual(result["stop_reason"] as? String, "tool_use")
    }

    func testStopReason_length() async throws {
        let body = makeOpenAIResponse(finishReason: "length")
        registerMock(url: "https://api.test.com/v1/chat/completions", body: body)
        let result = try await makeOpenAISUT().sendMessage(model: "gpt-4", messages: [], maxTokens: 100)
        XCTAssertEqual(result["stop_reason"] as? String, "max_tokens")
    }

    // MARK: - Message Conversion

    func testSendMessage_systemPromptConverted() async throws {
        let responseBody = makeOpenAIResponse()
        registerMock(url: "https://api.test.com/v1/chat/completions", body: responseBody)

        let client = makeOpenAISUT()
        _ = try await client.sendMessage(
            model: "gpt-4",
            messages: [["role": "user", "content": "hi"]],
            maxTokens: 100,
            system: "You are a bot."
        )

        // Verify the request body contains system message
        let bodyData = MockURLProtocol.lastRequest?.httpBody
        XCTAssertNotNil(bodyData)
        let bodyJson = try JSONSerialization.jsonObject(with: bodyData!, options: []) as? [String: Any]
        let messages = bodyJson?["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.first?["role"] as? String, "system")
        XCTAssertEqual(messages?.first?["content"] as? String, "You are a bot.")
    }

    func testSendMessage_toolResultMessagesConverted() async throws {
        let responseBody = makeOpenAIResponse()
        registerMock(url: "https://api.test.com/v1/chat/completions", body: responseBody)

        let client = makeOpenAISUT()
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["type": "tool_result", "tool_use_id": "tu_1", "content": "result1"],
                    ["type": "tool_result", "tool_use_id": "tu_2", "content": "result2"],
                ]
            ]
        ]
        _ = try await client.sendMessage(model: "gpt-4", messages: messages, maxTokens: 100)

        let bodyData = MockURLProtocol.lastRequest?.httpBody!
        let bodyJson = try JSONSerialization.jsonObject(with: bodyData!, options: []) as? [String: Any]
        let sentMessages = bodyJson?["messages"] as? [[String: Any]]

        // Tool results should be expanded into separate "tool" role messages
        XCTAssertEqual(sentMessages?.count, 2)
        XCTAssertEqual(sentMessages?[0]["role"] as? String, "tool")
        XCTAssertEqual(sentMessages?[0]["tool_call_id"] as? String, "tu_1")
        XCTAssertEqual(sentMessages?[1]["role"] as? String, "tool")
        XCTAssertEqual(sentMessages?[1]["tool_call_id"] as? String, "tu_2")
    }

    // MARK: - Tool Conversion

    func testSendMessage_toolsConverted() async throws {
        let responseBody = makeOpenAIResponse()
        registerMock(url: "https://api.test.com/v1/chat/completions", body: responseBody)

        let client = makeOpenAISUT()
        let tools: [[String: Any]] = [
            [
                "name": "bash",
                "description": "Run a command",
                "input_schema": ["type": "object", "properties": ["cmd": ["type": "string"]]],
            ]
        ]
        _ = try await client.sendMessage(model: "gpt-4", messages: [], maxTokens: 100, tools: tools)

        let bodyData = MockURLProtocol.lastRequest?.httpBody!
        let bodyJson = try JSONSerialization.jsonObject(with: bodyData!, options: []) as? [String: Any]
        let sentTools = bodyJson?["tools"] as? [[String: Any]]

        XCTAssertEqual(sentTools?.count, 1)
        XCTAssertEqual(sentTools?.first?["type"] as? String, "function")
        let function = sentTools?.first?["function"] as? [String: Any]
        XCTAssertEqual(function?["name"] as? String, "bash")
        XCTAssertNotNil(function?["parameters"])
    }
}

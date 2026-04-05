import XCTest
@testable import OpenAgentSDK

// MARK: - Tool Registry Integration Tests

/// ATDD RED PHASE: Integration tests for Story 3.1 -- Tool Protocol & Registry.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - Agent.swift passes registered tools to AnthropicClient via `tools` parameter
///   - AnthropicClient includes `tools` in the API request body when provided
///   - Empty/nil tools produce no `tools` key in the request (backward compatibility)
/// TDD Phase: RED (feature not implemented yet)
final class ToolRegistryIntegrationTests: XCTestCase {

    // MARK: - Mock URL Protocol for Integration Tests

    /// Custom URLProtocol subclass that intercepts requests to verify tool parameters.
    final class ToolIntegrationMockURLProtocol: URLProtocol {

        nonisolated(unsafe) static var mockResponses: [String: (statusCode: Int, headers: [String: String], body: Data)] = [:]
        nonisolated(unsafe) static var lastRequest: URLRequest?
        nonisolated(unsafe) static var allRequests: [URLRequest] = []

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            var capturedRequest = request
            if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
                capturedRequest.httpBody = Self.readBodyFromStream(stream)
            }
            ToolIntegrationMockURLProtocol.lastRequest = capturedRequest
            ToolIntegrationMockURLProtocol.allRequests.append(capturedRequest)

            guard let url = request.url?.absoluteString,
                  let mock = ToolIntegrationMockURLProtocol.mockResponses[url] else {
                let error = NSError(domain: "ToolIntegrationMock", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "No mock for URL: \(request.url?.absoluteString ?? "nil")"
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
            client?.urlProtocol(self, didFinishLoading: self)
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

    // MARK: - Helper: Create a mock API response

    private func makeSuccessResponse(text: String) -> [String: Any] {
        return [
            "id": "msg_test",
            "type": "message",
            "role": "assistant",
            "content": [
                ["type": "text", "text": text]
            ],
            "model": "claude-sonnet-4-6",
            "stop_reason": "end_turn",
            "usage": ["input_tokens": 10, "output_tokens": 20]
        ]
    }

    private func makeStreamingResponse(text: String) -> Data {
        let events = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_test","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","usage":{"input_tokens":10,"output_tokens":0}}}

        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\(text)"}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":0}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":\(text.count)}}

        event: message_stop
        data: {"type":"message_stop"}

        """
        return Data(events.utf8)
    }

    // MARK: - Helper: Create a mock tool

    private func makeMockTool(name: String = "test_tool", description: String = "A test tool") -> ToolProtocol {
        SimpleMockTool(name: name, description: description)
    }

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        ToolIntegrationMockURLProtocol.reset()
    }

    override func tearDown() {
        ToolIntegrationMockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - AC6: prompt() with tools passes tools to API

    /// AC6 [P0]: prompt() should pass registered tools to the Anthropic API.
    func testPrompt_WithTools_PassesToolsToApi() async {
        // Given: an agent with registered tools
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ToolIntegrationMockURLProtocol.self]
        let session = URLSession(configuration: config)

        let responseDict = makeSuccessResponse(text: "Tool result processed")
        let responseData = try! JSONSerialization.data(withJSONObject: responseDict, options: [])

        ToolIntegrationMockURLProtocol.mockResponses = [
            "https://api.anthropic.com/v1/messages": (200, ["content-type": "application/json"], responseData)
        ]

        let tools = [
            makeMockTool(name: "bash", description: "Run bash commands"),
            makeMockTool(name: "read", description: "Read files")
        ]

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                tools: tools
            ),
            client: AnthropicClient(apiKey: "test-key", urlSession: session)
        )

        // When: calling prompt()
        _ = await agent.prompt("List the files")

        // Then: the API request body contains the tools array
        let request = ToolIntegrationMockURLProtocol.lastRequest
        XCTAssertNotNil(request, "A request should have been made")

        let bodyData = request!.httpBody
        XCTAssertNotNil(bodyData, "Request should have a body")

        let body = try! JSONSerialization.jsonObject(with: bodyData!, options: []) as! [String: Any]

        // Then: the "tools" key is present in the request body
        let toolsArray = body["tools"] as? [[String: Any]]
        XCTAssertNotNil(toolsArray, "Request body should contain 'tools' key when tools are registered")
        XCTAssertEqual(toolsArray?.count, 2, "Request should include exactly 2 tools")

        let toolNames = toolsArray?.compactMap { $0["name"] as? String }
        XCTAssertEqual(toolNames, ["bash", "read"],
                       "Tool names in request should match registered tools")
    }

    /// AC6 [P0]: prompt() without tools should NOT include "tools" key in request.
    func testPrompt_WithoutTools_NoToolsInRequest() async {
        // Given: an agent without tools
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ToolIntegrationMockURLProtocol.self]
        let session = URLSession(configuration: config)

        let responseDict = makeSuccessResponse(text: "Hello!")
        let responseData = try! JSONSerialization.data(withJSONObject: responseDict, options: [])

        ToolIntegrationMockURLProtocol.mockResponses = [
            "https://api.anthropic.com/v1/messages": (200, ["content-type": "application/json"], responseData)
        ]

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6"
            ),
            client: AnthropicClient(apiKey: "test-key", urlSession: session)
        )

        // When: calling prompt()
        _ = await agent.prompt("Hello")

        // Then: the API request body does NOT contain "tools" key
        let request = ToolIntegrationMockURLProtocol.lastRequest
        XCTAssertNotNil(request)

        let bodyData = request!.httpBody!
        let body = try! JSONSerialization.jsonObject(with: bodyData, options: []) as! [String: Any]

        XCTAssertNil(body["tools"],
                      "Request body should NOT contain 'tools' key when no tools are registered")
    }

    /// AC6 [P0]: prompt() with empty tools array should NOT include "tools" key.
    func testPrompt_WithEmptyToolsArray_NoToolsInRequest() async {
        // Given: an agent with an empty tools array
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ToolIntegrationMockURLProtocol.self]
        let session = URLSession(configuration: config)

        let responseDict = makeSuccessResponse(text: "Hello!")
        let responseData = try! JSONSerialization.data(withJSONObject: responseDict, options: [])

        ToolIntegrationMockURLProtocol.mockResponses = [
            "https://api.anthropic.com/v1/messages": (200, ["content-type": "application/json"], responseData)
        ]

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                tools: []
            ),
            client: AnthropicClient(apiKey: "test-key", urlSession: session)
        )

        // When: calling prompt()
        _ = await agent.prompt("Hello")

        // Then: no "tools" key in request body
        let request = ToolIntegrationMockURLProtocol.lastRequest
        XCTAssertNotNil(request)

        let bodyData = request!.httpBody!
        let body = try! JSONSerialization.jsonObject(with: bodyData, options: []) as! [String: Any]

        XCTAssertNil(body["tools"],
                      "Request body should NOT contain 'tools' key when tools array is empty")
    }

    /// AC6 [P0]: prompt() tools should be in correct API format with name, description, input_schema.
    func testPrompt_ToolsInApiFormat() async {
        // Given: an agent with a single tool
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ToolIntegrationMockURLProtocol.self]
        let session = URLSession(configuration: config)

        let responseDict = makeSuccessResponse(text: "Done")
        let responseData = try! JSONSerialization.data(withJSONObject: responseDict, options: [])

        ToolIntegrationMockURLProtocol.mockResponses = [
            "https://api.anthropic.com/v1/messages": (200, ["content-type": "application/json"], responseData)
        ]

        let schema: ToolInputSchema = [
            "type": "object",
            "properties": ["path": ["type": "string"]],
            "required": ["path"]
        ]

        let tools: [ToolProtocol] = [
            SchemaMockTool(name: "read_file", description: "Read a file", inputSchema: schema)
        ]

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                tools: tools
            ),
            client: AnthropicClient(apiKey: "test-key", urlSession: session)
        )

        // When: calling prompt()
        _ = await agent.prompt("Read the file")

        // Then: the tool in the request has the correct API format
        let bodyData = ToolIntegrationMockURLProtocol.lastRequest!.httpBody!
        let body = try! JSONSerialization.jsonObject(with: bodyData, options: []) as! [String: Any]

        let toolsArray = body["tools"] as! [[String: Any]]
        XCTAssertEqual(toolsArray.count, 1)

        let toolDict = toolsArray[0]
        XCTAssertEqual(toolDict["name"] as? String, "read_file")
        XCTAssertEqual(toolDict["description"] as? String, "Read a file")

        let inputSchemaDict = toolDict["input_schema"] as? [String: Any]
        XCTAssertNotNil(inputSchemaDict, "Tool should contain 'input_schema' key")
        XCTAssertEqual(inputSchemaDict?["type"] as? String, "object")
    }

    // MARK: - AC6: stream() with tools passes tools to API

    /// AC6 [P1]: stream() should pass registered tools to the Anthropic API.
    func testStream_WithTools_PassesToolsToApi() async throws {
        // Given: an agent with registered tools
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ToolIntegrationMockURLProtocol.self]
        let session = URLSession(configuration: config)

        let streamData = makeStreamingResponse(text: "Streamed response with tools")
        ToolIntegrationMockURLProtocol.mockResponses = [
            "https://api.anthropic.com/v1/messages": (200, ["content-type": "text/event-stream"], streamData)
        ]

        let tools = [
            makeMockTool(name: "bash", description: "Run bash")
        ]

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                tools: tools
            ),
            client: AnthropicClient(apiKey: "test-key", urlSession: session)
        )

        // When: calling stream()
        let stream = try await agent.stream("Run ls")
        for await _ in stream { /* consume */ }

        // Then: the API request body contains tools
        let request = ToolIntegrationMockURLProtocol.lastRequest
        XCTAssertNotNil(request)

        let bodyData = request!.httpBody!
        let body = try! JSONSerialization.jsonObject(with: bodyData, options: []) as! [String: Any]

        let toolsArray = body["tools"] as? [[String: Any]]
        XCTAssertNotNil(toolsArray, "Stream request should include 'tools' key")
        XCTAssertEqual(toolsArray?.count, 1)

        let toolNames = toolsArray?.compactMap { $0["name"] as? String }
        XCTAssertEqual(toolNames, ["bash"])
    }

    /// AC6 [P1]: stream() without tools should NOT include "tools" in request.
    func testStream_WithoutTools_NoToolsInRequest() async throws {
        // Given: an agent without tools
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ToolIntegrationMockURLProtocol.self]
        let session = URLSession(configuration: config)

        let streamData = makeStreamingResponse(text: "No tools needed")
        ToolIntegrationMockURLProtocol.mockResponses = [
            "https://api.anthropic.com/v1/messages": (200, ["content-type": "text/event-stream"], streamData)
        ]

        let agent = Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6"
            ),
            client: AnthropicClient(apiKey: "test-key", urlSession: session)
        )

        // When: calling stream()
        let stream = try await agent.stream("Hello")
        for await _ in stream { /* consume */ }

        // Then: no "tools" key in request
        let request = ToolIntegrationMockURLProtocol.lastRequest
        XCTAssertNotNil(request)

        let bodyData = request!.httpBody!
        let body = try! JSONSerialization.jsonObject(with: bodyData, options: []) as! [String: Any]

        XCTAssertNil(body["tools"],
                      "Stream request should NOT contain 'tools' key when no tools registered")
    }

    // MARK: - AC5+AC6: End-to-end API format verification

    /// AC5+AC6 [P1]: toApiTools output should be directly passable to the API.
    func testToApiToolsOutput_MatchesExpectedApiFormat() {
        // Given: a tool with a full schema
        let schema: ToolInputSchema = [
            "type": "object",
            "properties": [
                "command": ["type": "string", "description": "The command to run"],
                "timeout": ["type": "integer", "description": "Timeout in seconds"]
            ],
            "required": ["command"]
        ]
        let tool = SchemaMockTool(
            name: "bash",
            description: "Execute a bash command",
            inputSchema: schema
        )

        // When: converting to API format
        let apiTools = toApiTools([tool])

        // Then: each tool dict has exactly the keys Anthropic expects
        XCTAssertEqual(apiTools.count, 1)
        let apiTool = apiTools[0]

        // Verify structure matches Anthropic API spec
        XCTAssertEqual(apiTool["name"] as? String, "bash")
        XCTAssertEqual(apiTool["description"] as? String, "Execute a bash command")

        let inputSchema = apiTool["input_schema"] as? [String: Any]
        XCTAssertNotNil(inputSchema)
        XCTAssertEqual(inputSchema?["type"] as? String, "object")

        let properties = inputSchema?["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        XCTAssertEqual(properties?.count, 2)

        let required = inputSchema?["required"] as? [String]
        XCTAssertEqual(required, ["command"])
    }
}

// MARK: - Mock Tools for Integration Tests

/// Simple mock tool with no schema complexity.
private struct SimpleMockTool: ToolProtocol, Sendable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema = ["type": "object", "properties": [:]]
    let isReadOnly: Bool = true

    func call(input: Any, context: ToolContext) async -> ToolResult {
        ToolResult(toolUseId: "mock", content: "mock", isError: false)
    }
}

/// Mock tool with a custom input schema.
private struct SchemaMockTool: ToolProtocol, Sendable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema
    let isReadOnly: Bool = true

    func call(input: Any, context: ToolContext) async -> ToolResult {
        ToolResult(toolUseId: "mock", content: "mock", isError: false)
    }
}

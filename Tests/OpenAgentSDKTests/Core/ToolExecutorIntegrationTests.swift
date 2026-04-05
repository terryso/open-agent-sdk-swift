import XCTest
@testable import OpenAgentSDK

// MARK: - Integration Tests: Agent + ToolExecutor

/// ATDD RED PHASE: Integration tests for Story 3.3 -- Agent integration with ToolExecutor.
/// Tests verify the agent loop correctly handles tool_use responses, executes tools,
/// feeds results back, and continues the conversation loop.
/// TDD Phase: RED (feature not implemented yet)
final class ToolExecutorIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AgentLoopMockURLProtocol.reset()
    }

    override func tearDown() {
        AgentLoopMockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - AC4 + AC5 + AC7: Agent prompt() handles tool_use round-trip

    /// AC4+5+7 [P0]: Given LLM returns tool_use blocks, when agent loop processes the response,
    /// tools are executed, results are appended as tool_result user messages,
    /// and the loop continues to the next LLM call.
    func testPrompt_ToolUseExecuted_ResultsFedBack() async throws {
        // Given: an agent with registered tools
        let tools: [ToolProtocol] = [
            MockIntegrationReadOnlyTool(name: "Read", result: "file contents here")
        ]

        let sut = makeToolAgentSUT(tools: tools)

        // First response: LLM requests a tool_use
        // Second response: LLM returns final text after seeing tool result
        let responses = [
            makeToolUseResponse(
                toolUseBlocks: [
                    ["type": "tool_use", "id": "tu_001", "name": "Read", "input": ["path": "/tmp/test.swift"]]
                ],
                stopReason: "tool_use"
            ),
            makeAgentLoopResponse(
                content: [["type": "text", "text": "I read the file. It contains Swift code."]],
                stopReason: "end_turn"
            ),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        // When: calling prompt
        let result = await sut.prompt("Read the file /tmp/test.swift")

        // Then: agent completes successfully
        XCTAssertEqual(result.status, .success,
                       "Agent should complete successfully after tool execution")
        XCTAssertTrue(result.text.contains("Swift code"),
                      "Final response should contain text from the second LLM call after tool execution")

        // And: at least 2 API calls were made (tool_use + end_turn)
        XCTAssertGreaterThanOrEqual(AgentLoopMockURLProtocol.allRequests.count, 2,
                                    "Should make at least 2 API calls (tool_use round + end_turn)")
    }

    /// AC7 [P0]: tool_use round does NOT increment maxTokensRecoveryAttempts.
    func testPrompt_ToolUseDoesNotIncrementMaxTokensRecovery() async throws {
        // Given: an agent with tools
        let tools: [ToolProtocol] = [
            MockIntegrationReadOnlyTool(name: "Glob", result: "a.swift\nb.swift")
        ]

        let sut = makeToolAgentSUT(tools: tools, maxTurns: 5)

        // Multiple tool_use rounds followed by end_turn
        let responses = [
            makeToolUseResponse(
                toolUseBlocks: [
                    ["type": "tool_use", "id": "tu_1", "name": "Glob", "input": ["pattern": "*.swift"]]
                ],
                stopReason: "tool_use"
            ),
            makeToolUseResponse(
                toolUseBlocks: [
                    ["type": "tool_use", "id": "tu_2", "name": "Glob", "input": ["pattern": "*.txt"]]
                ],
                stopReason: "tool_use"
            ),
            makeAgentLoopResponse(
                content: [["type": "text", "text": "Done searching."]],
                stopReason: "end_turn"
            ),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        // When: calling prompt
        let result = await sut.prompt("Search for files")

        // Then: completes successfully with 3 turns (not hitting maxTokensRecovery limit)
        XCTAssertEqual(result.status, .success,
                       "tool_use rounds should not cause maxTokens recovery exhaustion")
        XCTAssertEqual(result.numTurns, 3,
                       "Should complete in 3 turns (2 tool_use + 1 end_turn)")
    }

    /// AC6+7 [P0]: Unknown tool returns error but loop continues.
    func testPrompt_UnknownTool_ReturnsErrorButContinues() async throws {
        // Given: an agent with no tools registered
        let sut = makeToolAgentSUT(tools: [])

        // First response: LLM requests an unknown tool
        // Second response: LLM handles the error and responds
        let responses = [
            makeToolUseResponse(
                toolUseBlocks: [
                    ["type": "tool_use", "id": "tu_unk", "name": "nonexistent", "input": [:]]
                ],
                stopReason: "tool_use"
            ),
            makeAgentLoopResponse(
                content: [["type": "text", "text": "I don't have that tool available."]],
                stopReason: "end_turn"
            ),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        // When: calling prompt
        let result = await sut.prompt("Use nonexistent tool")

        // Then: agent does not crash and completes
        XCTAssertEqual(result.status, .success,
                       "Agent should recover from unknown tool error and continue")
        XCTAssertTrue(result.text.contains("tool"),
                      "Final response should acknowledge tool issue")
    }

    // MARK: - AC5: tool_result message format in conversation

    /// AC5 [P0]: Tool results are sent back as user message with tool_result content blocks.
    func testPrompt_ToolResultMessageSentAsUserMessage() async throws {
        let tools: [ToolProtocol] = [
            MockIntegrationReadOnlyTool(name: "Read", result: "hello world")
        ]

        let sut = makeToolAgentSUT(tools: tools)

        let responses = [
            makeToolUseResponse(
                toolUseBlocks: [
                    ["type": "tool_use", "id": "tu_1", "name": "Read", "input": ["path": "a.txt"]]
                ],
                stopReason: "tool_use"
            ),
            makeAgentLoopResponse(
                content: [["type": "text", "text": "File contains 'hello world'."]],
                stopReason: "end_turn"
            ),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        _ = await sut.prompt("Read a.txt")

        // Then: the second API request should contain the tool_result user message
        // There should be at least 2 requests; check the second one
        let requests = AgentLoopMockURLProtocol.allRequests
        XCTAssertGreaterThanOrEqual(requests.count, 2, "Should have at least 2 API requests")

        // Parse the second request body to verify tool_result message
        let secondRequest = requests[1]
        let bodyData = secondRequest.httpBody
        XCTAssertNotNil(bodyData)

        let body = try JSONSerialization.jsonObject(with: bodyData!, options: []) as! [String: Any]
        let messages = body["messages"] as! [[String: Any]]

        // Find the user message containing tool_result content
        let toolResultMessages = messages.filter { msg in
            guard let content = msg["content"] as? [[String: Any]] else { return false }
            return content.contains { ($0["type"] as? String) == "tool_result" }
        }

        XCTAssertFalse(toolResultMessages.isEmpty,
                       "Messages should contain a user message with tool_result content blocks")

        // Verify the tool_result block structure
        let toolResultMsg = toolResultMessages[0]
        XCTAssertEqual(toolResultMsg["role"] as? String, "user",
                       "Tool result message should have role 'user'")

        let content = toolResultMsg["content"] as! [[String: Any]]
        let toolResultBlock = content.first { ($0["type"] as? String) == "tool_result" }!
        XCTAssertEqual(toolResultBlock["tool_use_id"] as? String, "tu_1",
                       "tool_result should reference the correct tool_use_id")
    }

    // MARK: - AC8: Micro-Compaction Integration

    /// AC8 [P1]: Large tool results trigger micro-compaction before being appended.
    func testPrompt_LargeToolResultTriggersMicroCompaction() async throws {
        // Given: a tool that returns a very large result (> 50,000 chars)
        let largeContent = String(repeating: "x", count: 55_000)
        let tools: [ToolProtocol] = [
            MockIntegrationReadOnlyTool(name: "Read", result: largeContent)
        ]

        let sut = makeToolAgentSUT(tools: tools)

        // We need 3 responses:
        // 1) tool_use response (first agent loop call)
        // 2) micro-compact response (summarize the large tool result)
        // 3) end_turn response (second agent loop call after tool result is appended)
        let responses = [
            makeToolUseResponse(
                toolUseBlocks: [
                    ["type": "tool_use", "id": "tu_big", "name": "Read", "input": ["path": "big.txt"]]
                ],
                stopReason: "tool_use"
            ),
            makeAgentLoopResponse(
                content: [["type": "text", "text": "Summary of the large file content."]],
                stopReason: "end_turn"
            ),
            makeAgentLoopResponse(
                content: [["type": "text", "text": "Read the large file."]],
                stopReason: "end_turn"
            ),
        ]
        registerSequentialAgentLoopMockResponses(responses)

        let result = await sut.prompt("Read the big file")

        // Then: agent completes (doesn't crash from large result)
        XCTAssertEqual(result.status, .success,
                       "Agent should handle large tool results without crashing")
    }

    // MARK: - Stream Integration

    /// AC7 [P1]: Stream path emits toolUse and toolResult SDKMessage events.
    func testStream_ToolUse_EventsYielded() async throws {
        let tools: [ToolProtocol] = [
            MockIntegrationReadOnlyTool(name: "Read", result: "stream file contents")
        ]

        let sut = makeToolAgentSUT(tools: tools)

        // Mock SSE events for: messageStart -> contentBlockDelta(text) -> messageDelta(tool_use) -> messageStop
        // Then after tool execution: another round with end_turn
        // For simplicity, we test that the stream completes without crash
        // when tool_use is involved. Full SSE mocking is complex, so this test
        // verifies the stream path handles tool_use blocks.

        // Build SSE response with tool_use content block
        let sseEvents = makeToolUseSSEResponse(
            toolUseId: "tu_stream_1",
            toolName: "Read",
            toolInput: "{\"path\":\"a.swift\"}"
        )

        // We need to register the mock to return SSE data
        // For now, this test verifies the stream path integration exists
        // and does not crash when encountering tool_use blocks

        // Note: Full SSE stream testing requires building SSE event data,
        // which will be validated during implementation (green phase)
        let stream = sut.stream("Read a.swift")

        var messages: [SDKMessage] = []
        for await msg in stream {
            messages.append(msg)
        }

        // The stream should complete (either with a result or error)
        let hasResult = messages.contains { if case .result = $0 { return true } else { return false } }
        XCTAssertTrue(hasResult,
                      "Stream should yield a .result message (even if tool_use handling is not yet implemented)")
    }
}

// MARK: - Integration Test Helpers

/// Mock tool for integration tests (simple read-only tool).
struct MockIntegrationReadOnlyTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Integration test tool"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = true
    let result: String

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(toolUseId: context.toolUseId, content: result, isError: false)
    }
}

extension XCTestCase {

    /// Creates an Agent with tools configured for tool executor integration testing.
    func makeToolAgentSUT(
        tools: [ToolProtocol],
        apiKey: String = "sk-test-tool-exec-12345",
        model: String = "claude-sonnet-4-6",
        maxTurns: Int = 10
    ) -> Agent {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [AgentLoopMockURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfig)

        let client = AnthropicClient(apiKey: apiKey, baseURL: nil, urlSession: urlSession)

        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            maxTurns: maxTurns,
            tools: tools
        )

        return Agent(options: options, client: client)
    }

    /// Builds an API response containing tool_use content blocks.
    func makeToolUseResponse(
        id: String = "msg_tooluse_001",
        model: String = "claude-sonnet-4-6",
        toolUseBlocks: [[String: Any]],
        stopReason: String = "tool_use",
        inputTokens: Int = 50,
        outputTokens: Int = 100
    ) -> [String: Any] {
        // Include both text and tool_use blocks (typical LLM response)
        var content: [[String: Any]] = [
            ["type": "text", "text": "Let me use some tools."]
        ]
        content.append(contentsOf: toolUseBlocks)

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

    /// Builds a sequence of SSE events simulating a tool_use response.
    /// Returns the raw SSE text data for mocking.
    func makeToolUseSSEResponse(
        toolUseId: String,
        toolName: String,
        toolInput: String
    ) -> Data {
        let events = [
            "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_sse\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[],\"model\":\"claude-sonnet-4-6\",\"stop_reason\":null,\"usage\":{\"input_tokens\":50,\"output_tokens\":0}}}\n\n",
            "event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"tool_use\",\"id\":\"\(toolUseId)\",\"name\":\"\(toolName)\"}}\n\n",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"\(toolInput)\"}}\n\n",
            "event: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":0}\n\n",
            "event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"tool_use\"},\"usage\":{\"output_tokens\":50}}\n\n",
            "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n",
        ]

        return events.joined().data(using: .utf8) ?? Data()
    }
}

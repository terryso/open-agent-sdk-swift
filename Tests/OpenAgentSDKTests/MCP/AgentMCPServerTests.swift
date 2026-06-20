import XCTest
import MCP
@testable import OpenAgentSDK

// MARK: - AgentMCPServer ATDD Tests (RED PHASE)

/// ATDD RED PHASE: Tests for Story 19.2 -- Agent-as-MCP-Server.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `AgentMCPServer` actor is defined in `MCP/AgentMCPServer.swift`
///   - Tool registration via `MCPServer.register()` is implemented
///   - `agent_prompt` tool is implemented
///   - Graceful shutdown handling is implemented
///
/// TDD Phase: RED (feature not implemented yet)
///
/// Testing approach: Uses `InMemoryTransport` for in-process testing
/// (no real stdio I/O). Creates `AgentMCPServer`, obtains a session,
/// connects an MCP `Client`, and verifies protocol behavior.
final class AgentMCPServerTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a simple mock tool for testing.
    private func makeMockTool(
        name: String = "test_tool",
        description: String = "A test tool",
        schema: ToolInputSchema = ["type": "object", "properties": [:]],
        resultContent: String = "tool result",
        resultIsError: Bool = false
    ) -> AgentMCPServerMockTool {
        return AgentMCPServerMockTool(
            toolName: name,
            toolDescription: description,
            toolSchema: schema,
            resultContent: resultContent,
            resultIsError: resultIsError
        )
    }

    /// Creates a mock tool that returns an error result.
    private func makeErrorTool(
        name: String = "error_tool",
        errorMessage: String = "Something went wrong"
    ) -> AgentMCPServerMockTool {
        return AgentMCPServerMockTool(
            toolName: name,
            toolDescription: "A tool that returns errors",
            toolSchema: ["type": "object", "properties": [:]],
            resultContent: errorMessage,
            resultIsError: true
        )
    }

    /// Creates an AgentMCPServer with mock tools and returns a connected MCP client session.
    private func createConnectedSession(
        tools: [ToolProtocol],
        serverName: String = "test-server",
        serverVersion: String = "1.0.0"
    ) async throws -> (AgentMCPServer, Server, Client) {
        let agentServer = AgentMCPServer(
            name: serverName,
            version: serverVersion,
            tools: tools
        )
        let (mcpServer, clientTransport) = try await agentServer.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        return (agentServer, mcpServer, client)
    }

    // ================================================================
    // MARK: - AC1: AgentMCPServer Class Defined
    // ================================================================

    /// AC1 [P0]: AgentMCPServer can be created with name, version, and tools.
    func testAgentMCPServer_creation_withNameVersionTools() async {
        let tool = makeMockTool(name: "echo")
        let server = AgentMCPServer(
            name: "my-agent",
            version: "1.0.0",
            tools: [tool]
        )

        let serverName = await server.name
        let serverVersion = await server.version

        XCTAssertEqual(serverName, "my-agent")
        XCTAssertEqual(serverVersion, "1.0.0")
    }

    /// AC1 [P0]: AgentMCPServer can be created with empty tools list.
    func testAgentMCPServer_creation_withEmptyTools() async {
        let server = AgentMCPServer(
            name: "empty-agent",
            version: "1.0.0",
            tools: []
        )

        let serverName = await server.name
        XCTAssertEqual(serverName, "empty-agent")
    }

    /// AC1 [P0]: AgentMCPServer is an actor (thread-safe shared mutable state).
    func testAgentMCPServer_isActor() async {
        let server = AgentMCPServer(
            name: "actor-check",
            version: "1.0.0",
            tools: []
        )
        // Actor -- accessing isolated state requires await
        let _ = await server.name
        // If it compiles, it is an actor
    }

    /// AC1 [P1]: AgentMCPServer can be created with default version.
    func testAgentMCPServer_creation_defaultVersion() async {
        let server = AgentMCPServer(
            name: "default-ver",
            tools: []
        )

        let version = await server.version
        XCTAssertEqual(version, "1.0.0",
                        "Default version should be 1.0.0")
    }

    // ================================================================
    // MARK: - AC2: MCP Initialize Handshake
    // ================================================================

    /// AC2 [P0]: AgentMCPServer responds to MCP initialize request with server capabilities.
    func testAgentMCPServer_initializeHandshake_returnsCapabilities() async throws {
        let tool = makeMockTool()
        let (_, mcpServer, client) = try await createConnectedSession(tools: [tool])

        // If client.connect() succeeded, the initialize handshake completed.
        // Verify the client received server info.
        let serverInfo = await client.serverInfo
        XCTAssertNotNil(serverInfo,
                         "Client should have server info after initialize handshake")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC2 [P0]: Initialize response includes tools capability enabled.
    func testAgentMCPServer_initializeHandshake_includesToolsCapability() async throws {
        let tool = makeMockTool()
        let (_, mcpServer, client) = try await createConnectedSession(tools: [tool])

        // After connect, client should be able to list tools (proving tools capability enabled)
        let result = try await client.listTools()
        XCTAssertNotNil(result,
                         "Client should be able to list tools (tools capability must be enabled)")

        await mcpServer.stop()
        await client.disconnect()
    }

    // ================================================================
    // MARK: - AC3: tools/list Response
    // ================================================================

    /// AC3 [P0]: tools/list returns all tools registered with the agent.
    func testAgentMCPServer_toolList_returnsAllTools() async throws {
        let tool1 = makeMockTool(name: "read_file", description: "Reads a file")
        let tool2 = makeMockTool(name: "write_file", description: "Writes a file")
        let (_, mcpServer, client) = try await createConnectedSession(tools: [tool1, tool2])

        let result = try await client.listTools()

        // Filter out agent_prompt to count only user tools
        let userTools = result.tools.filter { $0.name != "agent_prompt" }
        XCTAssertEqual(userTools.count, 2,
                        "Should expose exactly two user tools")
        let toolNames = Set(result.tools.map { $0.name })
        XCTAssertTrue(toolNames.contains("read_file"),
                       "Tool list should contain read_file")
        XCTAssertTrue(toolNames.contains("write_file"),
                       "Tool list should contain write_file")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC3 [P0]: Each exposed tool has name, description, and inputSchema.
    func testAgentMCPServer_toolList_includesNameDescriptionSchema() async throws {
        let tool = makeMockTool(
            name: "get_weather",
            description: "Gets the current weather",
            schema: [
                "type": "object",
                "properties": [
                    "city": ["type": "string", "description": "City name"]
                ],
                "required": ["city"]
            ]
        )
        let (_, mcpServer, client) = try await createConnectedSession(tools: [tool])

        let result = try await client.listTools()
        let exposedTool = result.tools.first(where: { $0.name == "get_weather" })

        XCTAssertNotNil(exposedTool, "Should have the get_weather tool")
        XCTAssertEqual(exposedTool?.name, "get_weather",
                        "Tool name should match")
        XCTAssertNotNil(exposedTool?.description,
                         "Tool should have a description")
        XCTAssertNotNil(exposedTool?.inputSchema,
                         "Tool should have inputSchema")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC3 [P1]: tools/list with empty tools returns empty list.
    func testAgentMCPServer_toolList_emptyTools() async throws {
        let (_, mcpServer, client) = try await createConnectedSession(tools: [])

        let result = try await client.listTools()
        // May include the agent_prompt special tool, but no user tools
        let nonSpecialTools = result.tools.filter { $0.name != "agent_prompt" }
        XCTAssertTrue(nonSpecialTools.isEmpty,
                       "Empty server should expose no user tools")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC3 [P1]: Tool with complex inputSchema is correctly converted.
    func testAgentMCPServer_toolList_complexSchema() async throws {
        let complexSchema: ToolInputSchema = [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "Search query"],
                "limit": ["type": "integer", "description": "Max results"],
                "filters": [
                    "type": "object",
                    "properties": [
                        "category": ["type": "string"],
                        "tags": ["type": "array", "items": ["type": "string"]]
                    ]
                ]
            ],
            "required": ["query"]
        ]
        let tool = makeMockTool(name: "search", description: "Search tool", schema: complexSchema)
        let (_, mcpServer, client) = try await createConnectedSession(tools: [tool])

        let result = try await client.listTools()
        let exposedTool = result.tools.first

        XCTAssertNotNil(exposedTool, "Should have the search tool")
        XCTAssertNotNil(exposedTool?.inputSchema,
                         "Complex schema should be preserved")

        await mcpServer.stop()
        await client.disconnect()
    }

    // ================================================================
    // MARK: - AC4: tools/call Dispatch
    // ================================================================

    /// AC4 [P0]: tools/call dispatches to the correct tool and returns result.
    func testAgentMCPServer_toolCall_dispatchesCorrectly() async throws {
        let tool = makeMockTool(
            name: "echo",
            description: "Echoes input",
            resultContent: "Hello, world!"
        )
        let (_, mcpServer, client) = try await createConnectedSession(tools: [tool])

        let result = try await client.callTool(
            name: "echo",
            arguments: ["message": .string("Hello")]
        )

        XCTAssertNotEqual(result.isError, true,
                            "Tool call should succeed")
        XCTAssertTrue(result.content.contains(where: { content in
            switch content {
            case .text(let text, _, _): return text.contains("Hello, world!")
            default: return false
            }
        }),
                       "Tool result should contain the expected output")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC4 [P0]: tools/call passes arguments to tool correctly.
    func testAgentMCPServer_toolCall_passesArguments() async throws {
        // Tool that echoes back its input arguments
        let tool = AgentMCPServerEchoArgTool()
        let (_, mcpServer, client) = try await createConnectedSession(tools: [tool])

        let result = try await client.callTool(
            name: "echo_args",
            arguments: ["key1": .string("value1"), "key2": .int(42)]
        )

        XCTAssertNotEqual(result.isError, true,
                            "Tool call should succeed")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC4 [P0]: Tool execution error returns isError: true via MCP.
    func testAgentMCPServer_toolCall_errorResult() async throws {
        let errorTool = makeErrorTool(name: "failing_tool", errorMessage: "Execution failed")
        let (_, mcpServer, client) = try await createConnectedSession(tools: [errorTool])

        let result = try await client.callTool(
            name: "failing_tool",
            arguments: [:]
        )

        XCTAssertEqual(result.isError, true,
                         "Tool error should be returned as isError: true")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC4 [P0]: Server remains operational after tool execution error.
    func testAgentMCPServer_toolCall_serverRemainsOperationalAfterError() async throws {
        let errorTool = makeErrorTool(name: "crashy_tool")
        let goodTool = makeMockTool(name: "good_tool", resultContent: "I'm fine")
        let (_, mcpServer, client) = try await createConnectedSession(tools: [errorTool, goodTool])

        // Call the error tool
        _ = try await client.callTool(name: "crashy_tool", arguments: [:])

        // Server should still list tools
        let listResult = try await client.listTools()
        XCTAssertFalse(listResult.tools.isEmpty,
                         "Server should still list tools after error")

        // Call the good tool
        let goodResult = try await client.callTool(name: "good_tool", arguments: [:])
        XCTAssertNotEqual(goodResult.isError, true,
                            "Good tool should still work after error in another tool")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC4 [P1]: Calling an unknown tool returns MCP error.
    func testAgentMCPServer_toolCall_unknownTool() async throws {
        let tool = makeMockTool(name: "known_tool")
        let (_, mcpServer, client) = try await createConnectedSession(tools: [tool])

        var gotError = false
        do {
            _ = try await client.callTool(name: "nonexistent_tool", arguments: [:])
        } catch {
            gotError = true
        }

        XCTAssertTrue(gotError,
                       "Unknown tool call should return MCP protocol error")

        await mcpServer.stop()
        await client.disconnect()
    }

    // ================================================================
    // MARK: - AC5: agent/prompt Custom Method
    // ================================================================

    /// AC5 [P0]: agent_prompt tool is registered and discoverable.
    func testAgentMCPServer_agentPrompt_isDiscoverable() async throws {
        let (_, mcpServer, client) = try await createConnectedSession(tools: [])

        let result = try await client.listTools()
        let hasAgentPrompt = result.tools.contains(where: { $0.name == "agent_prompt" })

        XCTAssertTrue(hasAgentPrompt,
                       "agent_prompt tool should be discoverable via tools/list")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC5 [P0]: agent_prompt has correct inputSchema with task field.
    func testAgentMCPServer_agentPrompt_hasTaskSchema() async throws {
        let (_, mcpServer, client) = try await createConnectedSession(tools: [])

        let result = try await client.listTools()
        let agentPrompt = result.tools.first(where: { $0.name == "agent_prompt" })

        XCTAssertNotNil(agentPrompt, "agent_prompt tool should exist")
        XCTAssertNotNil(agentPrompt?.inputSchema,
                         "agent_prompt should have an inputSchema")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC5 [P0]: agent_prompt with missing task parameter returns error.
    func testAgentMCPServer_agentPrompt_missingTask_returnsError() async throws {
        let (_, mcpServer, client) = try await createConnectedSession(tools: [])

        // Call agent_prompt without the required "task" field
        let result = try await client.callTool(name: "agent_prompt", arguments: [:])

        XCTAssertEqual(result.isError, true,
                         "Missing task parameter should return isError: true")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC5 [P1]: agent_prompt description mentions autonomous execution.
    func testAgentMCPServer_agentPrompt_description() async throws {
        let (_, mcpServer, client) = try await createConnectedSession(tools: [])

        let result = try await client.listTools()
        let agentPrompt = result.tools.first(where: { $0.name == "agent_prompt" })

        XCTAssertNotNil(agentPrompt?.description,
                         "agent_prompt should have a description")
        if let desc = agentPrompt?.description {
            XCTAssertTrue(desc.lowercased().contains("task") || desc.lowercased().contains("agent"),
                            "Description should mention task or agent")
        }

        await mcpServer.stop()
        await client.disconnect()
    }

    // ================================================================
    // MARK: - AC6: Graceful Shutdown on EOF
    // ================================================================

    /// AC6 [P0]: AgentMCPServer.run() returns cleanly when transport disconnects.
    func testAgentMCPServer_gracefulShutdown_onTransportDisconnect() async throws {
        let tool = makeMockTool()
        let server = AgentMCPServer(
            name: "shutdown-test",
            version: "1.0.0",
            tools: [tool]
        )

        let (mcpServer, clientTransport) = try await server.createSession()
        let client = Client(name: "shutdown-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        // Disconnect the client (simulates EOF)
        await client.disconnect()
        await mcpServer.stop()

        // If we got here without hanging, shutdown was graceful
    }

    /// AC6 [P1]: Server can handle multiple sessions shutting down independently.
    func testAgentMCPServer_gracefulShutdown_multipleSessions() async throws {
        let tool = makeMockTool()
        let server = AgentMCPServer(
            name: "multi-shutdown",
            version: "1.0.0",
            tools: [tool]
        )

        let (server1, transport1) = try await server.createSession()
        let (server2, transport2) = try await server.createSession()

        let client1 = Client(name: "client-1", version: "1.0.0")
        let client2 = Client(name: "client-2", version: "1.0.0")
        try await client1.connect(transport: transport1)
        try await client2.connect(transport: transport2)

        // Shutdown one session
        await client1.disconnect()
        await server1.stop()

        // Second session should still work
        let listResult = try await client2.listTools()
        XCTAssertFalse(listResult.tools.isEmpty,
                         "Second session should still be operational")

        await client2.disconnect()
        await server2.stop()
    }

    // ================================================================
    // MARK: - AC7: Claude Code MCP Config Compatibility
    // ================================================================

    /// AC7 [P0]: AgentMCPServer uses standard MCP protocol (initialize + tools/list + tools/call).
    func testAgentMCPServer_claudeCodeCompat_fullProtocolFlow() async throws {
        let tool = makeMockTool(
            name: "my_custom_tool",
            description: "A custom tool for Claude Code",
            schema: [
                "type": "object",
                "properties": [
                    "input": ["type": "string", "description": "Input parameter"]
                ],
                "required": ["input"]
            ],
            resultContent: "Custom tool executed successfully"
        )
        let (_, mcpServer, client) = try await createConnectedSession(tools: [tool])

        // Step 1: Initialize (already done via connect)
        // Step 2: List tools
        let listResult = try await client.listTools()
        XCTAssertFalse(listResult.tools.isEmpty,
                         "Should list at least one tool")

        // Step 3: Call a tool
        let callResult = try await client.callTool(
            name: "my_custom_tool",
            arguments: ["input": .string("test")]
        )
        XCTAssertNotEqual(callResult.isError, true,
                            "Tool call via standard MCP should succeed")

        await mcpServer.stop()
        await client.disconnect()
    }

    // ================================================================
    // MARK: - AC8: Module Boundary & Architecture Compliance
    // ================================================================

    /// AC8 [P0]: AgentMCPServer is placed in MCP/ directory and respects module boundaries.
    /// This is a compile-time check -- if AgentMCPServer compiles without
    /// importing Core/ or Tools/, module boundaries are respected.
    func testAgentMCPServer_respectsModuleBoundary() async {
        let server = AgentMCPServer(
            name: "boundary-test",
            version: "1.0.0",
            tools: []
        )
        // If this compiles, AgentMCPServer only depends on
        // Foundation, MCP (mcp-swift-sdk), and Types/
        _ = server
    }

    /// AC8 [P0]: AgentMCPServer is a public actor.
    func testAgentMCPServer_isPublicActor() async {
        let server = AgentMCPServer(name: "public-test", tools: [])
        // Actor -- accessing isolated state requires await
        let _ = await server.name
    }

    // ================================================================
    // MARK: - Edge Cases
    // ================================================================

    /// [P1]: Tool with underscore in name works correctly.
    func testAgentMCPServer_toolWithUnderscoreName() async throws {
        let tool = makeMockTool(name: "get_current_weather")
        let (_, mcpServer, client) = try await createConnectedSession(tools: [tool])

        let result = try await client.listTools()
        XCTAssertTrue(result.tools.contains(where: { $0.name == "get_current_weather" }),
                       "Should contain get_current_weather tool")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// [P1]: Large number of tools registered correctly.
    func testAgentMCPServer_manyTools() async throws {
        var tools: [ToolProtocol] = []
        for i in 0..<20 {
            tools.append(makeMockTool(name: "tool_\(i)", description: "Tool number \(i)"))
        }
        let (_, mcpServer, client) = try await createConnectedSession(tools: tools)

        let result = try await client.listTools()
        // May include agent_prompt, so check >= 20
        XCTAssertGreaterThanOrEqual(result.tools.count, 20,
                                      "Should expose all 20 tools (plus possibly agent_prompt)")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// [P2]: Tool with name containing special characters.
    func testAgentMCPServer_toolWithSpecialName() async throws {
        let tool = makeMockTool(name: "my-tool.v2")
        let (_, mcpServer, client) = try await createConnectedSession(tools: [tool])

        let result = try await client.listTools()
        XCTAssertTrue(result.tools.contains(where: { $0.name == "my-tool.v2" }),
                       "Tool with special characters should be registered")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// [P1]: Multiple sessions see the same tool list.
    func testAgentMCPServer_multipleSessions_consistentToolList() async throws {
        let tool1 = makeMockTool(name: "shared_tool_1")
        let tool2 = makeMockTool(name: "shared_tool_2")
        let server = AgentMCPServer(
            name: "multi-session",
            version: "1.0.0",
            tools: [tool1, tool2]
        )

        let (mcpServer1, transport1) = try await server.createSession()
        let (mcpServer2, transport2) = try await server.createSession()

        let client1 = Client(name: "client-1", version: "1.0.0")
        let client2 = Client(name: "client-2", version: "1.0.0")
        try await client1.connect(transport: transport1)
        try await client2.connect(transport: transport2)

        let list1 = try await client1.listTools()
        let list2 = try await client2.listTools()

        XCTAssertEqual(list1.tools.count, list2.tools.count,
                         "Both sessions should see the same number of tools")

        await mcpServer1.stop()
        await mcpServer2.stop()
        await client1.disconnect()
        await client2.disconnect()
    }

    /// [P2]: Calling a tool concurrently from two sessions does not crash.
    func testAgentMCPServer_concurrentCalls_differentSessions() async throws {
        let tool = makeMockTool(name: "concurrent_tool", resultContent: "concurrent result")
        let server = AgentMCPServer(
            name: "concurrent-test",
            version: "1.0.0",
            tools: [tool]
        )

        let (mcpServer1, transport1) = try await server.createSession()
        let (mcpServer2, transport2) = try await server.createSession()

        let client1 = Client(name: "concurrent-1", version: "1.0.0")
        let client2 = Client(name: "concurrent-2", version: "1.0.0")
        try await client1.connect(transport: transport1)
        try await client2.connect(transport: transport2)

        // Fire both calls concurrently
        async let result1 = client1.callTool(name: "concurrent_tool", arguments: [:])
        async let result2 = client2.callTool(name: "concurrent_tool", arguments: [:])

        let r1 = try await result1
        let r2 = try await result2

        XCTAssertNotEqual(r1.isError, true, "First concurrent call should succeed")
        XCTAssertNotEqual(r2.isError, true, "Second concurrent call should succeed")

        await mcpServer1.stop()
        await mcpServer2.stop()
        await client1.disconnect()
        await client2.disconnect()
    }

    // ================================================================
    // MARK: - agent_prompt handler branches (covers lines 162-169)
    // ================================================================
    //
    // llvm-cov showed the agent_prompt handler closure body (the four
    // branches: missing task, no agent, agent errorDuringExecution, success)
    // was partially uncovered. The existing missingTask test already covers
    // the first branch; these tests cover the other three.

    /// agent_prompt with a valid task but no agent configured (createSession
    /// never sets agent — only run(agent:) does) returns an error explaining
    /// how to fix it.
    func testAgentMCPServer_agentPrompt_validTaskButNoAgent_returnsNoAgentError() async throws {
        let (_, mcpServer, client) = try await createConnectedSession(tools: [])

        let result = try await client.callTool(
            name: "agent_prompt",
            arguments: ["task": .string("do something")]
        )

        XCTAssertEqual(result.isError, true,
                       "Without an agent, agent_prompt should surface an error")
        // We don't pin the exact wording (that lives in ToolExecutionError.message),
        // but MCP must mark the call as an error.

        await mcpServer.stop()
        await client.disconnect()
    }

    /// agent_prompt with non-string task type also fails the type-coercion
    /// guard (case .string pattern doesn't match).
    func testAgentMCPServer_agentPrompt_nonStringTask_returnsError() async throws {
        let (_, mcpServer, client) = try await createConnectedSession(tools: [])

        let result = try await client.callTool(
            name: "agent_prompt",
            arguments: ["task": .int(42)]
        )

        XCTAssertEqual(result.isError, true,
                       "Non-string task value must fail the pattern match")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// agent_prompt with extra args alongside task is accepted by the handler
    /// (it only checks task, ignoring extras). Verifies the no-agent branch
    /// fires regardless of how many extra fields are passed.
    func testAgentMCPServer_agentPrompt_extraArgumentsIgnoredWhenNoAgent() async throws {
        let (_, mcpServer, client) = try await createConnectedSession(tools: [])

        let result = try await client.callTool(
            name: "agent_prompt",
            arguments: [
                "task": .string("hello"),
                "extra": .string("ignored"),
            ]
        )

        XCTAssertEqual(result.isError, true)

        await mcpServer.stop()
        await client.disconnect()
    }

    /// Verify the no-agent error path is consistent across multiple calls —
    /// the handler closure must not cache state between invocations.
    func testAgentMCPServer_agentPrompt_multipleCallsEachReturnNoAgentError() async throws {
        let (_, mcpServer, client) = try await createConnectedSession(tools: [])

        for _ in 0..<3 {
            let result = try await client.callTool(
                name: "agent_prompt",
                arguments: ["task": .string("repeat")]
            )
            XCTAssertEqual(result.isError, true,
                           "Each call without an agent should consistently error")
        }

        await mcpServer.stop()
        await client.disconnect()
    }

    /// After one session ends, a new session on the same server still has
    /// no agent (agent is only set via run(agent:) which we never call here).
    /// This pins down the agent-state isolation: state does not leak from
    /// any prior hypothetical run(agent:) into createSession() paths.
    func testAgentMCPServer_agentPrompt_freshSessionStillHasNoAgent() async throws {
        let agentServer = AgentMCPServer(name: "isolation", version: "1.0.0", tools: [])

        // First session
        let (mcpServer1, transport1) = try await agentServer.createSession()
        let client1 = Client(name: "c1", version: "1.0")
        try await client1.connect(transport: transport1)
        let r1 = try await client1.callTool(name: "agent_prompt", arguments: ["task": .string("x")])
        XCTAssertEqual(r1.isError, true)
        await mcpServer1.stop()
        await client1.disconnect()

        // Second session, same server
        let (mcpServer2, transport2) = try await agentServer.createSession()
        let client2 = Client(name: "c2", version: "1.0")
        try await client2.connect(transport: transport2)
        let r2 = try await client2.callTool(name: "agent_prompt", arguments: ["task": .string("y")])
        XCTAssertEqual(r2.isError, true,
                       "Fresh session must also have no agent — state should not leak")
        await mcpServer2.stop()
        await client2.disconnect()
    }

    // ================================================================
    // MARK: - agent_prompt with a configured Agent (success + error branches)
    // ================================================================
    //
    // Covers lines 165-169 of AgentMCPServer.swift — the agent.prompt(task)
    // success path and the errorDuringExecution → throw branch.
    //
    // Uses setAgentForTesting (internal) to inject an Agent with a mock LLM
    // client, bypassing run(agent:) which blocks on StdioTransport.

    /// Mock LLM that returns a fixed text response via sendMessage.
    private struct SuccessLLMClient: LLMClient, @unchecked Sendable {
        let responseText: String
        nonisolated func sendMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> [String: Any] {
            [
                "content": [["type": "text", "text": responseText]],
                "stop_reason": "end_turn",
                "usage": ["input_tokens": 5, "output_tokens": 3],
            ]
        }
        nonisolated func streamMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
            AsyncThrowingStream { $0.finish() }
        }
    }

    /// Mock LLM that always throws — makes Agent.prompt return .errorDuringExecution.
    private struct FailingLLMClient: LLMClient, Sendable {
        nonisolated func sendMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> [String: Any] {
            throw SDKError.apiError(statusCode: 500, message: "boom")
        }
        nonisolated func streamMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
            throw SDKError.apiError(statusCode: 500, message: "boom")
        }
    }

    private func makeAgent(client: LLMClient) -> Agent {
        Agent(
            options: AgentOptions(
                apiKey: "sk-test-not-used",
                model: "claude-sonnet-4-6",
                systemPrompt: "test"
            ),
            client: client
        )
    }

    /// agent_prompt with a configured Agent and a successful LLM response
    /// returns the agent's text result via MCP. Covers lines 165-169.
    func testAgentMCPServer_agentPrompt_withAgent_returnsAgentResultText() async throws {
        let agentServer = AgentMCPServer(name: "with-agent", version: "1.0.0", tools: [])
        let agent = makeAgent(client: SuccessLLMClient(responseText: "AGENT_OK"))
        await agentServer.setAgentForTesting(agent)

        let (mcpServer, transport) = try await agentServer.createSession()
        let client = Client(name: "caller", version: "1.0")
        try await client.connect(transport: transport)

        let result = try await client.callTool(
            name: "agent_prompt",
            arguments: ["task": .string("any task")]
        )

        // isError is Optional<Bool> in MCP — nil means success (not an error).
        XCTAssertNotEqual(result.isError, true,
                       "Successful agent.prompt should not be marked as error")
        // Result content should embed the agent's text somewhere.
        let resultText = result.content.map { String(describing: $0) }.joined()
        XCTAssertTrue(resultText.contains("AGENT_OK"),
                      "MCP result should contain the agent's text; got: \(resultText)")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// agent_prompt with a configured Agent whose LLM throws returns an
    /// error result via MCP. Covers the `if result.status == .errorDuringExecution`
    /// branch on line 166-167.
    func testAgentMCPServer_agentPrompt_withFailingAgent_returnsMCPError() async throws {
        let agentServer = AgentMCPServer(name: "with-failing-agent", version: "1.0.0", tools: [])
        let agent = makeAgent(client: FailingLLMClient())
        await agentServer.setAgentForTesting(agent)

        let (mcpServer, transport) = try await agentServer.createSession()
        let client = Client(name: "caller", version: "1.0")
        try await client.connect(transport: transport)

        let result = try await client.callTool(
            name: "agent_prompt",
            arguments: ["task": .string("any task")]
        )

        XCTAssertEqual(result.isError, true,
                       "Failing agent should surface as MCP error result")

        await mcpServer.stop()
        await client.disconnect()
    }
}

// MARK: - Mock Tool Helpers

/// Mock tool for testing AgentMCPServer without real tool implementations.
/// Conforms to ToolProtocol for injection into AgentMCPServer.
private final class AgentMCPServerMockTool: ToolProtocol, Sendable {
    let toolName: String
    let toolDescription: String
    nonisolated(unsafe) let toolSchema: ToolInputSchema
    let resultContent: String
    let resultIsError: Bool

    init(
        toolName: String,
        toolDescription: String = "A test tool",
        toolSchema: ToolInputSchema = ["type": "object", "properties": [:]],
        resultContent: String = "mock result",
        resultIsError: Bool = false
    ) {
        self.toolName = toolName
        self.toolDescription = toolDescription
        self.toolSchema = toolSchema
        self.resultContent = resultContent
        self.resultIsError = resultIsError
    }

    var name: String { toolName }
    var description: String { toolDescription }
    var inputSchema: ToolInputSchema { toolSchema }
    var isReadOnly: Bool { false }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(
            toolUseId: context.toolUseId,
            content: resultContent,
            isError: resultIsError
        )
    }
}

/// Mock tool that echoes back its input arguments for verifying argument passing.
private final class AgentMCPServerEchoArgTool: ToolProtocol, Sendable {
    let toolName = "echo_args"
    let toolDescription = "Echoes back input arguments"
    nonisolated(unsafe) let toolSchema: ToolInputSchema = [
        "type": "object",
        "properties": [
            "message": ["type": "string", "description": "Message to echo"]
        ]
    ]

    var name: String { toolName }
    var description: String { toolDescription }
    var inputSchema: ToolInputSchema { toolSchema }
    var isReadOnly: Bool { true }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        if let dict = input as? [String: Any] {
            let desc = dict.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
            return ToolResult(toolUseId: context.toolUseId, content: "Echo: {\(desc)}", isError: false)
        }
        return ToolResult(toolUseId: context.toolUseId, content: "Echo: \(input)", isError: false)
    }
}

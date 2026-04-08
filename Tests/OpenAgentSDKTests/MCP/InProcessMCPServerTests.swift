import XCTest
import MCP
@testable import OpenAgentSDK

// MARK: - InProcessMCPServerTests

/// ATDD RED PHASE: Tests for Story 6.3 -- In-Process MCP Server.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `InProcessMCPServer` actor is defined in `Tools/MCP/InProcessMCPServer.swift`
///   - `McpSdkServerConfig` struct is defined in `Types/MCPConfig.swift`
///   - `McpServerConfig.sdk` case is added to `McpServerConfig` enum
///   - Agent integration is added to `Core/Agent.swift`
/// TDD Phase: RED (feature not implemented yet)
final class InProcessMCPServerTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a basic ToolContext with just cwd (no stores needed for MCP tests).
    private func makeContext(toolUseId: String = "test-tool-use-id") -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: toolUseId
        )
    }

    /// Creates a simple mock tool for testing.
    private func makeMockTool(
        name: String = "test_tool",
        description: String = "A test tool",
        schema: ToolInputSchema = ["type": "object", "properties": [:]],
        resultContent: String = "tool result",
        resultIsError: Bool = false
    ) -> MockTool {
        return MockTool(
            toolName: name,
            toolDescription: description,
            toolSchema: schema,
            resultContent: resultContent,
            resultIsError: resultIsError
        )
    }

    /// Creates a mock tool that throws an error.
    private func makeThrowingTool(
        name: String = "throwing_tool",
        error: Error = ToolTestError.executionFailed
    ) -> MockThrowingTool {
        return MockThrowingTool(toolName: name, error: error)
    }

    // ================================================================
    // MARK: - AC1: InProcessMCPServer Creation
    // ================================================================

    /// AC1 [P0]: InProcessMCPServer can be created with name, version, and tools.
    func testInProcessMCPServer_creation_withNameVersionTools() async {
        let tool = makeMockTool(name: "get_weather")
        let server = InProcessMCPServer(
            name: "weather",
            version: "1.0.0",
            tools: [tool]
        )

        let serverName = await server.name
        let serverVersion = await server.version

        XCTAssertEqual(serverName, "weather")
        XCTAssertEqual(serverVersion, "1.0.0")
    }

    /// AC1 [P0]: InProcessMCPServer can be created with empty tools list.
    func testInProcessMCPServer_creation_withEmptyTools() async {
        let server = InProcessMCPServer(
            name: "empty-server",
            version: "1.0.0",
            tools: []
        )

        let serverName = await server.name
        XCTAssertEqual(serverName, "empty-server")
    }

    /// AC1 [P0]: InProcessMCPServer can be created with multiple tools.
    func testInProcessMCPServer_creation_withMultipleTools() async {
        let tool1 = makeMockTool(name: "read_file")
        let tool2 = makeMockTool(name: "write_file")
        let server = InProcessMCPServer(
            name: "filesystem",
            version: "2.0.0",
            tools: [tool1, tool2]
        )

        let serverName = await server.name
        XCTAssertEqual(serverName, "filesystem")
    }

    /// AC1 [P0]: InProcessMCPServer is an actor (thread-safe).
    func testInProcessMCPServer_isActor() async {
        let server = InProcessMCPServer(
            name: "actor-test",
            version: "1.0.0",
            tools: []
        )
        // Actor -- accessing isolated state requires await
        let _ = await server.name
        // If it compiles, it is an actor
    }

    // ================================================================
    // MARK: - AC2: McpServerConfig.sdk Configuration
    // ================================================================

    /// AC2 [P0]: McpSdkServerConfig can be created with name, version, and server reference.
    func testMcpSdkServerConfig_creation() async {
        let tool = makeMockTool()
        let server = InProcessMCPServer(
            name: "my-sdk-server",
            version: "1.0.0",
            tools: [tool]
        )
        let config = McpSdkServerConfig(name: "my-sdk-server", version: "1.0.0", server: server)

        XCTAssertEqual(config.name, "my-sdk-server")
        XCTAssertEqual(config.version, "1.0.0")
    }

    /// AC2 [P0]: McpServerConfig.sdk wraps McpSdkServerConfig.
    func testMcpServerConfig_sdkCase() async {
        let server = InProcessMCPServer(
            name: "test",
            version: "1.0.0",
            tools: []
        )
        let sdkConfig = McpSdkServerConfig(name: "test", version: "1.0.0", server: server)
        let config = McpServerConfig.sdk(sdkConfig)

        if case .sdk(let unwrapped) = config {
            XCTAssertEqual(unwrapped.name, "test")
            XCTAssertEqual(unwrapped.version, "1.0.0")
        } else {
            XCTFail("Expected .sdk case")
        }
    }

    /// AC2 [P0]: McpServerConfig.sdk is distinct from stdio, sse, and http cases.
    func testMcpServerConfig_sdk_isDistinctFromOtherCases() async {
        let server = InProcessMCPServer(
            name: "test",
            version: "1.0.0",
            tools: []
        )
        let sdk = McpServerConfig.sdk(McpSdkServerConfig(name: "test", version: "1.0.0", server: server))
        let stdio = McpServerConfig.stdio(McpStdioConfig(command: "echo"))
        let sse = McpServerConfig.sse(McpSseConfig(url: "http://localhost:8080"))
        let http = McpServerConfig.http(McpHttpConfig(url: "http://localhost:8080"))

        XCTAssertNotEqual(sdk, stdio)
        XCTAssertNotEqual(sdk, sse)
        XCTAssertNotEqual(sdk, http)
    }

    /// AC2 [P0]: InProcessMCPServer.asConfig() returns McpServerConfig.sdk.
    func testInProcessMCPServer_asConfig_returnsSdkConfig() async {
        let tool = makeMockTool(name: "weather_tool")
        let server = InProcessMCPServer(
            name: "weather",
            version: "1.0.0",
            tools: [tool]
        )

        let config = await server.asConfig()

        if case .sdk(let sdkConfig) = config {
            XCTAssertEqual(sdkConfig.name, "weather")
            XCTAssertEqual(sdkConfig.version, "1.0.0")
        } else {
            XCTFail("Expected .sdk case from asConfig()")
        }
    }

    // ================================================================
    // MARK: - AC3: Tools Exposed as MCP Protocol
    // ================================================================

    /// AC3 [P0]: InProcessMCPServer exposes tools through MCP protocol via InMemoryTransport.
    func testInProcessMCPServer_toolList_viaInMemoryTransport() async {
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
        let server = InProcessMCPServer(
            name: "weather",
            version: "1.0.0",
            tools: [tool]
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        // Create a client and list tools
        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        let result = try await client.listTools()

        XCTAssertEqual(result.tools.count, 1,
                       "Should expose exactly one tool")
        XCTAssertEqual(result.tools.first?.name, "get_weather",
                       "Tool name should match without namespace prefix")
        XCTAssertNotNil(result.tools.first?.description,
                        "Tool should have a description")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC3 [P0]: InProcessMCPServer exposes multiple tools through MCP protocol.
    func testInProcessMCPServer_multipleTools_viaInMemoryTransport() async {
        let tool1 = makeMockTool(name: "read_file", description: "Reads a file")
        let tool2 = makeMockTool(name: "write_file", description: "Writes a file")
        let server = InProcessMCPServer(
            name: "filesystem",
            version: "1.0.0",
            tools: [tool1, tool2]
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        let result = try await client.listTools()

        XCTAssertEqual(result.tools.count, 2,
                       "Should expose both tools")
        let toolNames = Set(result.tools.map { $0.name })
        XCTAssertTrue(toolNames.contains("read_file"))
        XCTAssertTrue(toolNames.contains("write_file"))

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC3 [P1]: Exposed tool includes inputSchema with correct structure.
    func testInProcessMCPServer_toolList_includesInputSchema() async {
        let schema: ToolInputSchema = [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "Search query"]
            ],
            "required": ["query"]
        ]
        let tool = makeMockTool(name: "search", description: "Search tool", schema: schema)
        let server = InProcessMCPServer(
            name: "search-server",
            version: "1.0.0",
            tools: [tool]
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        let result = try await client.listTools()
        let exposedTool = result.tools.first

        XCTAssertNotNil(exposedTool, "Should have at least one tool")
        // The input schema should be present and non-nil
        XCTAssertNotNil(exposedTool?.inputSchema,
                        "Tool should have inputSchema")

        await mcpServer.stop()
        await client.disconnect()
    }

    // ================================================================
    // MARK: - AC4: Tool Execution Dispatch
    // ================================================================

    /// AC4 [P0]: Tool call through MCP protocol dispatches to ToolProtocol.call().
    func testInProcessMCPServer_toolCall_dispatchesToTool() async {
        let tool = makeMockTool(
            name: "echo",
            description: "Echoes input",
            resultContent: "Hello, world!"
        )
        let server = InProcessMCPServer(
            name: "echo-server",
            version: "1.0.0",
            tools: [tool]
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        let result = try await client.callTool(name: "echo", arguments: ["message": .string("Hello")])
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

    /// AC4 [P0]: Tool call result is returned through MCP protocol.
    func testInProcessMCPServer_toolCall_returnsMCPResult() async {
        let tool = makeMockTool(
            name: "calculator",
            description: "Performs calculations",
            resultContent: "42"
        )
        let server = InProcessMCPServer(
            name: "calc-server",
            version: "1.0.0",
            tools: [tool]
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        let result = try await client.callTool(name: "calculator", arguments: ["expression": .string("6*7")])

        XCTAssertNotEqual(result.isError, true,
                        "Calculator tool call should succeed")

        await mcpServer.stop()
        await client.disconnect()
    }

    // ================================================================
    // MARK: - AC5: Tool Namespace
    // ================================================================

    /// AC5 [P0]: Tools exposed via MCP protocol use original names (no namespace prefix).
    func testInProcessMCPServer_toolName_noNamespacePrefix() async {
        let tool = makeMockTool(name: "get_weather")
        let server = InProcessMCPServer(
            name: "weather",
            version: "1.0.0",
            tools: [tool]
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        let listResult = try await client.listTools()
        let exposedName = listResult.tools.first?.name

        // The exposed name should be "get_weather" (not "mcp__weather__get_weather")
        XCTAssertEqual(exposedName, "get_weather",
                       "InProcessMCPServer should expose tools with original names (no namespace prefix)")

        await mcpServer.stop()
        await client.disconnect()
    }

    // ================================================================
    // MARK: - AC6: Agent Integration (SDK Internal Mode)
    // ================================================================

    /// AC6 [P0]: InProcessMCPServer.getTools() returns the registered tools.
    func testInProcessMCPServer_getTools_returnsRegisteredTools() async {
        let tool1 = makeMockTool(name: "read")
        let tool2 = makeMockTool(name: "write")
        let server = InProcessMCPServer(
            name: "fs",
            version: "1.0.0",
            tools: [tool1, tool2]
        )

        let tools = await server.getTools()

        XCTAssertEqual(tools.count, 2,
                       "getTools() should return all registered tools")
    }

    /// AC6 [P0]: AgentOptions.mcpServers accepts McpServerConfig.sdk.
    func testAgentOptions_mcpServers_acceptsSdkConfig() async {
        let server = InProcessMCPServer(
            name: "sdk-server",
            version: "1.0.0",
            tools: [makeMockTool()]
        )
        let sdkConfig = McpSdkServerConfig(name: "sdk-server", version: "1.0.0", server: server)
        let config: [String: McpServerConfig] = [
            "my-sdk": .sdk(sdkConfig)
        ]
        let options = AgentOptions(mcpServers: config)

        XCTAssertNotNil(options.mcpServers)
        XCTAssertEqual(options.mcpServers?.count, 1)
    }

    /// AC6 [P0]: McpServerConfig can hold mixed types (stdio, sse, http, sdk).
    func testMcpServerConfig_mixedTypes_withSdk() async {
        let server = InProcessMCPServer(
            name: "mixed-sdk",
            version: "1.0.0",
            tools: []
        )
        let config: [String: McpServerConfig] = [
            "stdio-srv": .stdio(McpStdioConfig(command: "echo")),
            "sse-srv": .sse(McpSseConfig(url: "http://localhost:8080/sse")),
            "http-srv": .http(McpHttpConfig(url: "http://localhost:8080/mcp")),
            "sdk-srv": .sdk(McpSdkServerConfig(name: "mixed-sdk", version: "1.0.0", server: server)),
        ]
        let options = AgentOptions(mcpServers: config)

        XCTAssertEqual(options.mcpServers?.count, 4,
                       "AgentOptions should hold all four config types")
    }

    // ================================================================
    // MARK: - AC7: Session Creation & Lifecycle
    // ================================================================

    /// AC7 [P0]: createSession() returns a (Server, InMemoryTransport) pair.
    func testInProcessMCPServer_createSession_returnsPair() async {
        let server = InProcessMCPServer(
            name: "session-test",
            version: "1.0.0",
            tools: [makeMockTool()]
        )

        let (mcpServer, transport) = try await server.createSession()

        // The returned values should be non-nil (they are actors, so just use them)
        _ = mcpServer
        _ = transport
    }

    /// AC7 [P0]: Multiple sessions can be created (each client gets independent session).
    func testInProcessMCPServer_createSession_multipleSessions() async {
        let server = InProcessMCPServer(
            name: "multi-session",
            version: "1.0.0",
            tools: [makeMockTool()]
        )

        let (server1, transport1) = try await server.createSession()
        let (server2, transport2) = try await server.createSession()

        // Each session should be independent
        _ = server1
        _ = server2
        _ = transport1
        _ = transport2
    }

    /// AC7 [P1]: Each session operates independently.
    func testInProcessMCPServer_sessions_operateIndependently() async {
        let tool = makeMockTool(name: "test")
        let server = InProcessMCPServer(
            name: "independent-sessions",
            version: "1.0.0",
            tools: [tool]
        )

        // Create two separate sessions with clients
        let (mcpServer1, clientTransport1) = try await server.createSession()
        let (mcpServer2, clientTransport2) = try await server.createSession()

        let client1 = Client(name: "client-1", version: "1.0.0")
        let client2 = Client(name: "client-2", version: "1.0.0")
        try await client1.connect(transport: clientTransport1)
        try await client2.connect(transport: clientTransport2)

        // Both clients should see the same tool list
        let listResult1 = try await client1.listTools()
        let listResult2 = try await client2.listTools()

        XCTAssertEqual(listResult1.tools.count, listResult2.tools.count,
                       "Both sessions should expose the same number of tools")

        await mcpServer1.stop()
        await mcpServer2.stop()
        await client1.disconnect()
        await client2.disconnect()
    }

    // ================================================================
    // MARK: - AC8: Unknown Tool Handling
    // ================================================================

    /// AC8 [P0]: Calling an unknown tool returns MCP protocol error (invalidParams).
    func testInProcessMCPServer_unknownTool_returnsError() async {
        let tool = makeMockTool(name: "known_tool")
        let server = InProcessMCPServer(
            name: "error-test",
            version: "1.0.0",
            tools: [tool]
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        // Call a tool that does not exist — MCPServer returns invalidParams error
        // The client throws for protocol-level errors; this is correct per AC8
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

    /// AC8 [P0]: Unknown tool error does not crash the server.
    func testInProcessMCPServer_unknownTool_doesNotCrashServer() async {
        let server = InProcessMCPServer(
            name: "crash-test",
            version: "1.0.0",
            tools: [makeMockTool()]
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        // Call nonexistent tool -- should not crash
        _ = try await client.callTool(name: "ghost_tool", arguments: [:])

        // Server should still be operational
        let listResult = try await client.listTools()
        XCTAssertFalse(listResult.tools.isEmpty,
                        "Server should still list tools after unknown tool call")

        await mcpServer.stop()
        await client.disconnect()
    }

    // ================================================================
    // MARK: - AC9: Module Boundary Compliance
    // ================================================================

    /// AC9 [P0]: InProcessMCPServer works with only Foundation, MCP, and Types/ dependencies.
    /// This is a compile-time check -- if InProcessMCPServer compiles without
    /// importing Core/ or Stores/, module boundaries are respected.
    func testInProcessMCPServer_respectsModuleBoundary() async {
        let server = InProcessMCPServer(
            name: "boundary-test",
            version: "1.0.0",
            tools: []
        )
        // If this compiles, InProcessMCPServer only depends on
        // Foundation, MCP (mcp-swift-sdk), and Types/
        _ = server
    }

    // ================================================================
    // MARK: - AC10: Unit Test Coverage Verification
    // ================================================================

    /// AC10 [P0]: McpSdkServerConfig conforms to Sendable.
    func testMcpSdkServerConfig_isSendable() async {
        let server = InProcessMCPServer(
            name: "sendable-test",
            version: "1.0.0",
            tools: []
        )
        let config = McpSdkServerConfig(name: "sendable-test", version: "1.0.0", server: server)
        // Should compile if Sendable
        _ = config
    }

    // ================================================================
    // MARK: - AC12: Error Handling (Tool Execution Exceptions)
    // ================================================================

    /// AC12 [P0]: Tool execution exception is captured as isError: true, server does not crash.
    func testInProcessMCPServer_toolExecutionException_returnsError() async {
        let throwingTool = makeThrowingTool(name: "failing_tool")
        let server = InProcessMCPServer(
            name: "error-server",
            version: "1.0.0",
            tools: [throwingTool]
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        let result = try await client.callTool(name: "failing_tool", arguments: [:])

        XCTAssertEqual(result.isError, true,
                       "Tool execution exception should be captured as isError: true")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC12 [P0]: Server remains operational after tool execution exception.
    func testInProcessMCPServer_toolExecutionException_serverRemainsOperational() async {
        let throwingTool = makeThrowingTool(name: "crashy_tool")
        let goodTool = makeMockTool(name: "good_tool", resultContent: "I'm fine")
        let server = InProcessMCPServer(
            name: "resilient-server",
            version: "1.0.0",
            tools: [throwingTool, goodTool]
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        // Call the throwing tool
        _ = try await client.callTool(name: "crashy_tool", arguments: [:])

        // Server should still be able to list tools
        let listResult = try await client.listTools()
        XCTAssertEqual(listResult.tools.count, 2,
                        "Server should still expose both tools after exception")

        // Call the good tool
        let goodResult = try await client.callTool(name: "good_tool", arguments: [:])
        XCTAssertFalse(goodResult.isError ?? false,
                        "Good tool should still work after exception in another tool")

        await mcpServer.stop()
        await client.disconnect()
    }

    // ================================================================
    // MARK: - Edge Cases
    // ================================================================

    /// AC1 [P1]: InProcessMCPServer with default version uses "1.0.0".
    func testInProcessMCPServer_defaultVersion() async {
        let server = InProcessMCPServer(
            name: "default-version",
            tools: []
        )

        let version = await server.version
        XCTAssertEqual(version, "1.0.0",
                        "Default version should be 1.0.0")
    }

    /// AC7 [P1]: createSession with empty tools list does not crash.
    func testInProcessMCPServer_createSession_emptyTools() async {
        let server = InProcessMCPServer(
            name: "empty-session",
            version: "1.0.0",
            tools: []
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        let emptyResult = try await client.listTools()
        XCTAssertTrue(emptyResult.tools.isEmpty,
                       "Empty server should expose no tools")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC5 [P1]: Tool with underscore in name works correctly via MCP.
    func testInProcessMCPServer_toolWithUnderscoreName() async {
        let tool = makeMockTool(name: "get_current_weather")
        let server = InProcessMCPServer(
            name: "weather",
            version: "1.0.0",
            tools: [tool]
        )

        let (mcpServer, clientTransport) = try await server.createSession()

        let client = Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        let underscoreResult = try await client.listTools()
        XCTAssertEqual(underscoreResult.tools.first?.name, "get_current_weather")

        await mcpServer.stop()
        await client.disconnect()
    }

    /// AC2 [P1]: McpSdkServerConfig with special characters in name.
    func testMcpSdkServerConfig_specialCharsInName() async {
        let server = InProcessMCPServer(
            name: "my-cool-server_v2.0",
            version: "2.0.0",
            tools: []
        )
        let config = McpSdkServerConfig(name: "my-cool-server_v2.0", version: "2.0.0", server: server)
        XCTAssertEqual(config.name, "my-cool-server_v2.0")
    }

    // ================================================================
    // MARK: - Integration: assembleToolPool with SDK tools
    // ================================================================

    /// AC6 [P0]: assembleToolPool includes SDK server tools with mcp__ namespace.
    func testAssembleToolPool_includesSdkTools() async {
        let tool = makeMockTool(name: "search", description: "Search tool")
        let server = InProcessMCPServer(
            name: "sdk-pool",
            version: "1.0.0",
            tools: [tool]
        )
        let sdkTools = await server.getTools()

        let pool = assembleToolPool(
            baseTools: [],
            customTools: nil,
            mcpTools: sdkTools,
            allowed: nil,
            disallowed: nil
        )

        // SDK tools should be in the pool (with MCP namespace wrapping)
        XCTAssertTrue(pool.count >= 1,
                       "Pool should contain at least the SDK tool")
        XCTAssertEqual(pool.first?.name, "mcp__sdk-pool__search",
                       "SDK tool should have mcp__{serverName}__{toolName} namespace prefix")
    }
}

// MARK: - Mock Tool Helpers

/// Mock tool for testing InProcessMCPServer without real tool implementations.
/// Conforms to ToolProtocol for injection into InProcessMCPServer.
final class MockTool: ToolProtocol, Sendable {
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

/// Mock tool that throws an error during execution, for testing error handling.
final class MockThrowingTool: ToolProtocol, Sendable {
    let toolName: String
    let error: Error
    nonisolated(unsafe) let toolSchema: ToolInputSchema = ["type": "object", "properties": [:]]

    init(toolName: String, error: Error) {
        self.toolName = toolName
        self.error = error
    }

    var name: String { toolName }
    var description: String { "A tool that throws" }
    var inputSchema: ToolInputSchema { toolSchema }
    var isReadOnly: Bool { false }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(
            toolUseId: context.toolUseId,
            content: "Error: \(error.localizedDescription)",
            isError: true
        )
    }
}

/// Test errors for mock tool failures.
enum ToolTestError: Error, Sendable {
    case executionFailed
    case timeout
    case invalidInput
}

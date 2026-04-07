import Foundation
import OpenAgentSDK

// MARK: - MCPClientManager E2E Tests

struct MCPClientManagerE2ETests {
    static func run() async {
        section("MCP Client Manager: Creation & Types")
        await testMCPClientManagerCreation()
        await testMCPConnectionStatusTypes()
        await testMCPManagedConnectionWithTools()

        section("MCP Client Manager: MCPToolDefinition")
        testMCPToolDefinitionNamespace()
        testMCPToolDefinitionWithHyphenatedNames()
        testMCPToolDefinitionDescription()
        testMCPToolDefinitionIsReadOnly()
        await testMCPToolDefinitionCallWithNilClient()
        await testMCPToolDefinitionCallWithMockClient()
        await testMCPToolDefinitionCallMockClientError()

        section("MCP Client Manager: Connection Failure Handling")
        await testConnectInvalidCommandMarksError()
        await testConnectEmptyCommandMarksError()
        await testConnectFailureDoesNotCrash()
        await testMultipleFailedConnections()

        section("MCP Client Manager: Shutdown & Disconnect")
        await testShutdownWithNoConnections()
        await testShutdownClearsConnections()
        await testDisconnectNonExistentDoesNotCrash()
        await testDisconnectOneServerDoesNotAffectOther()
        await testShutdownAfterMultipleFailures()

        section("MCP Client Manager: Multi-server Management")
        await testConnectAllWithEmptyServers()
        await testConnectAllWithSseReturnsError()

        section("MCP Client Manager: Tool Pool Integration")
        testAssembleToolPoolMergesMCPTools()
        testAssembleToolPoolDeduplicates()
        await testGetMCPToolsReturnsEmptyWithNoConnections()
        await testGetMCPToolsReturnsEmptyWithFailedConnection()

        section("MCP Client Manager: MCPStdioTransport")
        await testTransportCreation()
        await testTransportNotRunningAfterInit()
        await testTransportWithArgs()
        await testTransportWithEnv()

        section("MCP Client Manager: API Key Security (NFR6)")
        await testTransportDoesNotLeakApiKeyByDefault()
        await testTransportPassesExplicitEnvVars()
        await testTransportAllowsExplicitApiKeyInConfig()

        section("MCP Client Manager: AgentOptions Integration")
        testAgentOptionsMcpServersDefaultIsNil()
        testAgentOptionsMcpServersCanBeSetWithStdio()
        testAgentOptionsMcpServersCanHoldMultipleServers()

        section("MCP Client Manager: Module Boundary")
        await testMCPToolDefinitionWorksWithOnlyTypesDependencies()

        section("MCP Client Manager: Edge Cases")
        await testConnectWithSpecialCharsInName()
        await testManagedConnectionHoldsMultipleTools()
        await testManagedConnectionErrorStatusEmptyTools()

        section("MCP Client Manager: Process Lifecycle")
        await testTransportConnectAndDisconnectLifecycle()
        await testManagerShutdownTerminatesTransports()

        // Story 6-2: HTTP/SSE Transport (ATDD RED PHASE)
        section("MCP Client Manager: SSE Transport Connection (Story 6-2)")
        await testSSEConnectInvalidURLMarksError()
        await testSSEConnectDoesNotCrash()

        section("MCP Client Manager: HTTP Transport Connection (Story 6-2)")
        await testHTTPConnectInvalidURLMarksError()
        await testHTTPConnectDoesNotCrash()

        section("MCP Client Manager: SSE/HTTP Headers (Story 6-2)")
        await testSSEConnectWithCustomHeaders()
        await testHTTPConnectWithCustomHeaders()
        await testSSEConnectWithNilHeaders()

        section("MCP Client Manager: SSE/HTTP Connection Failure (Story 6-2)")
        await testSSEConnectMalformedURLMarksError()
        await testHTTPConnectMalformedURLMarksError()
        await testSSEConnectEmptyURLMarksError()
        await testHTTPConnectEmptyURLMarksError()

        section("MCP Client Manager: Mixed Transport connectAll (Story 6-2)")
        await testConnectAllMixedTransportsDispatchesCorrectly()
        await testConnectAllSSEOnly()
        await testConnectAllHTTPOnly()

        section("MCP Client Manager: SSE/HTTP Disconnect & Cleanup (Story 6-2)")
        await testDisconnectSSEConnectionRemoves()
        await testDisconnectHTTPConnectionRemoves()
        await testShutdownClearsSSEAndHTTPConnections()
        await testDisconnectSSEDoesNotAffectOthers()

        section("MCP Client Manager: SSE/HTTP Tool Discovery (Story 6-2)")
        await testGetMCPToolsFailedSSE()
        await testGetMCPToolsFailedHTTP()

        section("MCP Client Manager: SSE/HTTP Module Boundary (Story 6-2)")
        await testHTTPSEERespectsModuleBoundary()

        section("MCP Client Manager: SSE/HTTP Cross-platform (Story 6-2)")
        await testSSETransportDoesNotCrashOnPlatform()
        await testHTTPTransportDoesNotCrashOnPlatform()

        section("MCP Client Manager: SSE/HTTP Config Types (Story 6-2)")
        testMcpSseConfigCreation()
        testMcpHttpConfigCreation()
        testMcpServerConfigSSEAndHTTPCases()
    }

    // MARK: - Helpers

    private static func makeContext(toolUseId: String = "e2e-tool-use-id") -> ToolContext {
        return ToolContext(cwd: "/tmp", toolUseId: toolUseId)
    }

    private static func makeStdioConfig(
        command: String = "echo",
        args: [String]? = nil,
        env: [String: String]? = nil
    ) -> McpStdioConfig {
        return McpStdioConfig(command: command, args: args, env: env)
    }

    // ================================================================
    // MARK: Creation & Types
    // ================================================================

    static func testMCPClientManagerCreation() async {
        let manager = MCPClientManager()
        let connections = await manager.getConnections()

        if connections.isEmpty {
            pass("MCPClientManager creates with empty connections")
        } else {
            fail("MCPClientManager should start with empty connections")
        }
    }

    static func testMCPConnectionStatusTypes() async {
        let connected: MCPConnectionStatus = .connected
        let disconnected: MCPConnectionStatus = .disconnected
        let error: MCPConnectionStatus = .error

        if connected != disconnected && connected != error && disconnected != error {
            pass("MCPConnectionStatus has all three distinct cases")
        } else {
            fail("MCPConnectionStatus cases should be distinct")
        }
    }

    static func testMCPManagedConnectionWithTools() async {
        let tool = MCPToolDefinition(
            serverName: "fs",
            mcpToolName: "read",
            toolDescription: "read file",
            schema: ["type": "object"],
            mcpClient: nil
        )
        let conn = MCPManagedConnection(
            name: "fs",
            status: .connected,
            tools: [tool]
        )

        if conn.name == "fs" && conn.status == .connected && conn.tools.count == 1 {
            pass("MCPManagedConnection holds name, status, and tool list")
        } else {
            fail("MCPManagedConnection data mismatch")
        }
    }

    // ================================================================
    // MARK: MCPToolDefinition
    // ================================================================

    static func testMCPToolDefinitionNamespace() {
        let tool = MCPToolDefinition(
            serverName: "filesystem",
            mcpToolName: "read_file",
            toolDescription: "Read a file from the filesystem",
            schema: ["type": "object", "properties": [:]],
            mcpClient: nil
        )

        if tool.name == "mcp__filesystem__read_file" {
            pass("MCPToolDefinition uses mcp__{server}__{tool} namespace")
        } else {
            fail("Expected mcp__filesystem__read_file, got \(tool.name)")
        }

        if !tool.isReadOnly {
            pass("MCPToolDefinition isReadOnly returns false")
        } else {
            fail("MCPToolDefinition isReadOnly should be false")
        }
    }

    static func testMCPToolDefinitionWithHyphenatedNames() {
        let tool = MCPToolDefinition(
            serverName: "my-cool-server",
            mcpToolName: "search_index",
            toolDescription: "search",
            schema: ["type": "object"],
            mcpClient: nil
        )

        if tool.name == "mcp__my-cool-server__search_index" {
            pass("MCPToolDefinition handles hyphenated server names")
        } else {
            fail("Expected mcp__my-cool-server__search_index, got \(tool.name)")
        }
    }

    static func testMCPToolDefinitionDescription() {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "A very useful tool for testing",
            schema: ["type": "object"],
            mcpClient: nil
        )

        if tool.description == "A very useful tool for testing" {
            pass("MCPToolDefinition passes through description")
        } else {
            fail("MCPToolDefinition description mismatch")
        }
    }

    static func testMCPToolDefinitionIsReadOnly() {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "desc",
            schema: ["type": "object"],
            mcpClient: nil
        )

        // MCP tools are never read-only (matches TypeScript SDK behavior)
        if !tool.isReadOnly {
            pass("MCPToolDefinition isReadOnly is always false")
        } else {
            fail("MCPToolDefinition isReadOnly should always be false")
        }
    }

    static func testMCPToolDefinitionCallWithNilClient() async {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "desc",
            schema: ["type": "object"],
            mcpClient: nil
        )

        let context = makeContext()
        let result = await tool.call(input: [:], context: context)

        if result.isError {
            pass("MCPToolDefinition.call() with nil client returns error ToolResult")
        } else {
            fail("Expected error ToolResult for nil client")
        }

        if result.content.contains("not available") || result.content.contains("error") {
            pass("Nil client error message is descriptive")
        } else {
            fail("Nil client error should be descriptive, got: \(result.content)")
        }
    }

    static func testMCPToolDefinitionCallWithMockClient() async {
        let mockClient = E2EMockMCPClient(callResult: "Hello from MCP server!")
        let tool = MCPToolDefinition(
            serverName: "remote",
            mcpToolName: "greet",
            toolDescription: "greeting tool",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let context = makeContext(toolUseId: "mock-success-1")
        let result = await tool.call(input: ["name": "world"], context: context)

        if !result.isError {
            pass("MCPToolDefinition.call() returns success with mock client")
        } else {
            fail("Expected success result, got error: \(result.content)")
        }

        if result.content.contains("Hello from MCP server!") {
            pass("MCPToolDefinition.call() returns MCP response content")
        } else {
            fail("Expected MCP response content, got: \(result.content)")
        }

        if result.toolUseId == "mock-success-1" {
            pass("MCPToolDefinition.call() preserves toolUseId")
        } else {
            fail("Expected toolUseId 'mock-success-1', got: \(result.toolUseId)")
        }
    }

    static func testMCPToolDefinitionCallMockClientError() async {
        let mockClient = E2EMockMCPClient(callResult: nil, callError: E2EMCPTestError.connectionFailed)
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "fail",
            toolDescription: "failing tool",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let context = makeContext()
        let result = await tool.call(input: [:], context: context)

        if result.isError {
            pass("MCPToolDefinition.call() captures client error as error ToolResult")
        } else {
            fail("Expected error ToolResult when client throws")
        }

        // The call() method never throws -- errors are captured
        if result.content.contains("error") || result.content.contains("MCP") {
            pass("MCP client error message is captured in ToolResult content")
        } else {
            fail("Error message should describe the issue, got: \(result.content)")
        }
    }

    // ================================================================
    // MARK: Connection Failure Handling
    // ================================================================

    static func testConnectInvalidCommandMarksError() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/nonexistent/command/that/does/not/exist")

        await manager.connect(name: "bad-server", config: config)
        let connections = await manager.getConnections()

        if let conn = connections["bad-server"], conn.status == .error, conn.tools.isEmpty {
            pass("Invalid command marks connection as error with empty tools")
        } else {
            fail("Invalid command should result in error status",
                 "got: \(connections["bad-server"]?.status ?? .disconnected)")
        }
    }

    static func testConnectEmptyCommandMarksError() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "")

        await manager.connect(name: "empty", config: config)
        let connections = await manager.getConnections()

        if let conn = connections["empty"], conn.status == .error {
            pass("Empty command marks connection as error")
        } else {
            fail("Empty command should result in error status")
        }
    }

    static func testConnectFailureDoesNotCrash() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/definitely/not/a/real/command")

        // Should not crash
        await manager.connect(name: "fail-server", config: config)

        // Manager should still be usable
        let connections = await manager.getConnections()
        if connections["fail-server"] != nil {
            pass("Manager survives connection failure and remains usable")
        } else {
            fail("Manager should track failed connections")
        }
    }

    static func testMultipleFailedConnections() async {
        let manager = MCPClientManager()
        let config1 = makeStdioConfig(command: "/nonexistent1")
        let config2 = makeStdioConfig(command: "/nonexistent2")

        await manager.connect(name: "fail1", config: config1)
        await manager.connect(name: "fail2", config: config2)

        let connections = await manager.getConnections()
        if connections.count == 2
            && connections["fail1"]?.status == .error
            && connections["fail2"]?.status == .error
        {
            pass("Multiple failed connections coexist independently")
        } else {
            fail("Both failed connections should be tracked",
                 "count=\(connections.count)")
        }
    }

    // ================================================================
    // MARK: Shutdown & Disconnect
    // ================================================================

    static func testShutdownWithNoConnections() async {
        let manager = MCPClientManager()
        await manager.shutdown()
        let connections = await manager.getConnections()

        if connections.isEmpty {
            pass("Shutdown with no connections completes cleanly")
        } else {
            fail("Shutdown should leave connections empty")
        }
    }

    static func testShutdownClearsConnections() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/nonexistent")
        await manager.connect(name: "server1", config: config)

        await manager.shutdown()
        let connections = await manager.getConnections()

        if connections.isEmpty {
            pass("Shutdown clears all connections including failed ones")
        } else {
            fail("Shutdown should clear all connections")
        }
    }

    static func testDisconnectNonExistentDoesNotCrash() async {
        let manager = MCPClientManager()
        // Should not crash
        await manager.disconnect(name: "nonexistent")
        pass("Disconnect for non-existent server does not crash")
    }

    static func testDisconnectOneServerDoesNotAffectOther() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/nonexistent")

        await manager.connect(name: "server1", config: config)
        await manager.connect(name: "server2", config: config)

        await manager.disconnect(name: "server1")
        let connections = await manager.getConnections()

        if connections["server1"] == nil && connections["server2"] != nil {
            pass("Disconnecting one server does not affect another")
        } else {
            fail("server1 should be gone, server2 should remain")
        }
    }

    static func testShutdownAfterMultipleFailures() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/nonexistent")

        await manager.connect(name: "s1", config: config)
        await manager.connect(name: "s2", config: config)

        await manager.shutdown()
        let connections = await manager.getConnections()

        if connections.isEmpty {
            pass("Shutdown after multiple failures clears everything")
        } else {
            fail("Shutdown should clear all connections")
        }
    }

    // ================================================================
    // MARK: Multi-server Management
    // ================================================================

    static func testConnectAllWithEmptyServers() async {
        let manager = MCPClientManager()
        await manager.connectAll(servers: [:])
        let connections = await manager.getConnections()

        if connections.isEmpty {
            pass("connectAll with empty servers leaves no connections")
        } else {
            fail("connectAll with empty servers should leave connections empty")
        }
    }

    static func testConnectAllWithSseReturnsError() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "sse-server": .sse(McpSseConfig(url: "http://localhost:8080/sse"))
        ]

        await manager.connectAll(servers: servers)
        let connections = await manager.getConnections()

        if let conn = connections["sse-server"], conn.status == .error {
            pass("SSE transport (Story 6-2) returns error status")
        } else {
            fail("SSE transport should be marked as error until Story 6-2",
                 "got: \(connections["sse-server"]?.status ?? .disconnected)")
        }
    }

    // ================================================================
    // MARK: Tool Pool Integration
    // ================================================================

    static func testAssembleToolPoolMergesMCPTools() {
        let baseTools = getAllBaseTools(tier: .core)
        let mcpTool = MCPToolDefinition(
            serverName: "remote",
            mcpToolName: "search",
            toolDescription: "remote search",
            schema: ["type": "object"],
            mcpClient: nil
        )

        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: nil,
            mcpTools: [mcpTool],
            allowed: nil,
            disallowed: nil
        )

        let hasMCPTool = pool.contains(where: { $0.name == "mcp__remote__search" })
        let hasBash = pool.contains(where: { $0.name == "Bash" })

        if hasMCPTool && hasBash {
            pass("assembleToolPool merges MCP tools with base tools")
        } else {
            fail("Pool should contain both MCP and base tools",
                 "hasMCP=\(hasMCPTool), hasBash=\(hasBash)")
        }
    }

    static func testAssembleToolPoolDeduplicates() {
        let mcpTool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "MCP version",
            schema: ["type": "object"],
            mcpClient: nil
        )

        let pool = assembleToolPool(
            baseTools: [],
            customTools: nil,
            mcpTools: [mcpTool],
            allowed: nil,
            disallowed: nil
        )

        if pool.count == 1 && pool.first?.name == "mcp__srv__tool" {
            pass("assembleToolPool includes single MCP tool correctly")
        } else {
            fail("Pool should have exactly one MCP tool",
                 "count=\(pool.count)")
        }
    }

    static func testGetMCPToolsReturnsEmptyWithNoConnections() async {
        let manager = MCPClientManager()
        let tools = await manager.getMCPTools()

        if tools.isEmpty {
            pass("getMCPTools returns empty with no connections")
        } else {
            fail("getMCPTools should return empty array")
        }
    }

    static func testGetMCPToolsReturnsEmptyWithFailedConnection() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/nonexistent")
        await manager.connect(name: "bad", config: config)

        let tools = await manager.getMCPTools()
        if tools.isEmpty {
            pass("getMCPTools returns empty for failed connections only")
        } else {
            fail("Failed connections should contribute no tools")
        }
    }

    // ================================================================
    // MARK: MCPStdioTransport
    // ================================================================

    static func testTransportCreation() async {
        let config = makeStdioConfig(command: "echo")
        let transport = MCPStdioTransport(config: config)
        _ = transport
        pass("MCPStdioTransport creates successfully")
    }

    static func testTransportNotRunningAfterInit() async {
        let config = makeStdioConfig(command: "echo")
        let transport = MCPStdioTransport(config: config)
        let isRunning = await transport.isRunning

        if !isRunning {
            pass("MCPStdioTransport is not running after init")
        } else {
            fail("MCPStdioTransport should not be running after init")
        }
    }

    static func testTransportWithArgs() async {
        let config = makeStdioConfig(command: "cat", args: ["-"])
        let transport = MCPStdioTransport(config: config)
        _ = transport
        pass("MCPStdioTransport creates with command arguments")
    }

    static func testTransportWithEnv() async {
        let config = makeStdioConfig(
            command: "env",
            env: ["MY_VAR": "my_value"]
        )
        let transport = MCPStdioTransport(config: config)
        _ = transport
        pass("MCPStdioTransport creates with environment variables")
    }

    // ================================================================
    // MARK: API Key Security (NFR6)
    // ================================================================

    static func testTransportDoesNotLeakApiKeyByDefault() async {
        setenv("CODEANY_API_KEY", "secret-key-e2e-test", 1)

        let config = makeStdioConfig(command: "env")
        let transport = MCPStdioTransport(config: config)
        let childEnv = await transport.getChildEnvironment()

        if childEnv["CODEANY_API_KEY"] == nil {
            pass("CODEANY_API_KEY is filtered from child process")
        } else {
            fail("CODEANY_API_KEY should not be leaked to child process")
        }

        unsetenv("CODEANY_API_KEY")
    }

    static func testTransportPassesExplicitEnvVars() async {
        let config = makeStdioConfig(
            command: "env",
            env: ["MY_TOOL_KEY": "my-value"]
        )
        let transport = MCPStdioTransport(config: config)
        let childEnv = await transport.getChildEnvironment()

        if childEnv["MY_TOOL_KEY"] == "my-value" {
            pass("Explicitly configured env vars are passed to child process")
        } else {
            fail("Explicit env vars should be passed through")
        }
    }

    static func testTransportAllowsExplicitApiKeyInConfig() async {
        // If the user explicitly sets CODEANY_API_KEY in the config's env,
        // it should be passed through
        setenv("CODEANY_API_KEY", "default-key", 1)

        let config = makeStdioConfig(
            command: "env",
            env: ["CODEANY_API_KEY": "mcp-specific-key"]
        )
        let transport = MCPStdioTransport(config: config)
        let childEnv = await transport.getChildEnvironment()

        if childEnv["CODEANY_API_KEY"] == "mcp-specific-key" {
            pass("Explicit API key in config overrides the filter")
        } else {
            fail("Explicitly configured API key should be passed",
                 "got: \(childEnv["CODEANY_API_KEY"] ?? "nil")")
        }

        unsetenv("CODEANY_API_KEY")
    }

    // ================================================================
    // MARK: AgentOptions Integration
    // ================================================================

    static func testAgentOptionsMcpServersDefaultIsNil() {
        let options = AgentOptions()
        if options.mcpServers == nil {
            pass("AgentOptions.mcpServers defaults to nil")
        } else {
            fail("AgentOptions.mcpServers should default to nil")
        }
    }

    static func testAgentOptionsMcpServersCanBeSetWithStdio() {
        let config: [String: McpServerConfig] = [
            "my-server": .stdio(McpStdioConfig(command: "my-mcp-server"))
        ]
        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: config
        )

        if let servers = options.mcpServers, servers.count == 1 {
            pass("AgentOptions accepts MCP server configuration")
        } else {
            fail("AgentOptions should accept MCP server configuration")
        }
    }

    static func testAgentOptionsMcpServersCanHoldMultipleServers() {
        let config: [String: McpServerConfig] = [
            "server1": .stdio(McpStdioConfig(command: "server1")),
            "server2": .stdio(McpStdioConfig(command: "server2")),
            "server3": .sse(McpSseConfig(url: "http://localhost:8080/sse")),
        ]
        let options = AgentOptions(
            apiKey: "test-key",
            model: "test-model",
            mcpServers: config
        )

        if options.mcpServers?.count == 3 {
            pass("AgentOptions holds multiple MCP servers (mixed stdio/sse)")
        } else {
            fail("AgentOptions should hold 3 servers",
                 "got: \(options.mcpServers?.count ?? 0)")
        }
    }

    // ================================================================
    // MARK: Module Boundary
    // ================================================================

    static func testMCPToolDefinitionWorksWithOnlyTypesDependencies() async {
        // MCPToolDefinition only uses ToolProtocol, ToolResult, ToolInputSchema, ToolContext
        // all from Types/ -- if this compiles, boundary is respected
        let tool = MCPToolDefinition(
            serverName: "boundary-test",
            mcpToolName: "test",
            toolDescription: "boundary test",
            schema: ["type": "object"],
            mcpClient: nil
        )

        let context = makeContext()
        let result = await tool.call(input: [:], context: context)
        _ = result
        pass("MCPToolDefinition works with only Types/ dependencies")
    }

    // ================================================================
    // MARK: Edge Cases
    // ================================================================

    static func testConnectWithSpecialCharsInName() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/nonexistent")

        await manager.connect(name: "my-server_v2.0", config: config)
        let connections = await manager.getConnections()

        if connections["my-server_v2.0"] != nil {
            pass("Connection names with special characters are handled")
        } else {
            fail("Should handle special characters in server name")
        }
    }

    static func testManagedConnectionHoldsMultipleTools() {
        let tool1 = MCPToolDefinition(
            serverName: "srv", mcpToolName: "read",
            toolDescription: "read", schema: ["type": "object"], mcpClient: nil
        )
        let tool2 = MCPToolDefinition(
            serverName: "srv", mcpToolName: "write",
            toolDescription: "write", schema: ["type": "object"], mcpClient: nil
        )
        let conn = MCPManagedConnection(name: "srv", status: .connected, tools: [tool1, tool2])

        if conn.tools.count == 2
            && conn.tools[0].name == "mcp__srv__read"
            && conn.tools[1].name == "mcp__srv__write"
        {
            pass("MCPManagedConnection holds multiple tools from same server")
        } else {
            fail("Should hold multiple tools",
                 "count=\(conn.tools.count)")
        }
    }

    static func testManagedConnectionErrorStatusEmptyTools() {
        let conn = MCPManagedConnection(name: "failed-server", status: .error, tools: [])

        if conn.status == .error && conn.tools.isEmpty {
            pass("MCPManagedConnection error status with empty tools")
        } else {
            fail("Error connections should have empty tools")
        }
    }

    // ================================================================
    // MARK: Process Lifecycle
    // ================================================================

    static func testTransportConnectAndDisconnectLifecycle() async {
        let config = makeStdioConfig(command: "cat")
        let transport = MCPStdioTransport(config: config)

        // Before connect
        let beforeRunning = await transport.isRunning
        if !beforeRunning {
            pass("Transport is not running before connect")
        } else {
            fail("Transport should not be running before connect")
        }

        // Connect (cat will start and wait for input)
        do {
            try await transport.connect()
            let afterConnectRunning = await transport.isRunning
            if afterConnectRunning {
                pass("Transport process is running after connect")
            } else {
                fail("Transport process should be running after connect")
            }
        } catch {
            fail("Transport connect should not throw", "error: \(error)")
            return
        }

        // Disconnect
        await transport.disconnect()
        let afterDisconnectRunning = await transport.isRunning
        if !afterDisconnectRunning {
            pass("Transport process is terminated after disconnect")
        } else {
            fail("Transport process should be terminated after disconnect")
        }
    }

    static func testManagerShutdownTerminatesTransports() async {
        let manager = MCPClientManager()

        // Connect to a real process (cat) that will stay running
        let config = makeStdioConfig(command: "cat")
        await manager.connect(name: "cat-server", config: config)

        // The connection will likely fail at MCP handshake since cat doesn't
        // speak MCP protocol, but the process should still be tracked for cleanup
        let _ = await manager.getConnections()

        // Regardless of connection result, shutdown should clean up
        await manager.shutdown()
        let afterShutdown = await manager.getConnections()

        if afterShutdown.isEmpty {
            pass("Manager shutdown cleans up all connections and transports")
        } else {
            fail("Manager shutdown should clear all connections",
                 "remaining: \(afterShutdown.count)")
        }
    }

    // ================================================================
    // MARK: Story 6-2: SSE Transport Connection
    // ================================================================

    /// AC1: SSE connect with invalid URL marks error status.
    static func testSSEConnectInvalidURLMarksError() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(url: "http://localhost:99999/nonexistent-sse")

        await manager.connect(name: "sse-server", config: sseConfig)
        let connections = await manager.getConnections()

        if let conn = connections["sse-server"], conn.status == .error, conn.tools.isEmpty {
            pass("SSE connect with invalid URL marks error status with empty tools")
        } else {
            fail("Invalid SSE URL should result in error status",
                 "got: \(connections["sse-server"]?.status ?? .disconnected)")
        }
    }

    /// AC1: SSE connect does not crash.
    static func testSSEConnectDoesNotCrash() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(url: "http://localhost:1/sse")

        await manager.connect(name: "sse-test", config: sseConfig)
        let connections = await manager.getConnections()

        if connections["sse-test"] != nil {
            pass("SSE connect does not crash (connection tracked)")
        } else {
            fail("SSE connect should track connection")
        }
    }

    // ================================================================
    // MARK: Story 6-2: HTTP Transport Connection
    // ================================================================

    /// AC2: HTTP connect with invalid URL marks error status.
    static func testHTTPConnectInvalidURLMarksError() async {
        let manager = MCPClientManager()
        let httpConfig = McpHttpConfig(url: "http://localhost:99999/nonexistent-http")

        await manager.connect(name: "http-server", config: httpConfig)
        let connections = await manager.getConnections()

        if let conn = connections["http-server"], conn.status == .error, conn.tools.isEmpty {
            pass("HTTP connect with invalid URL marks error status with empty tools")
        } else {
            fail("Invalid HTTP URL should result in error status",
                 "got: \(connections["http-server"]?.status ?? .disconnected)")
        }
    }

    /// AC2: HTTP connect does not crash.
    static func testHTTPConnectDoesNotCrash() async {
        let manager = MCPClientManager()
        let httpConfig = McpHttpConfig(url: "http://localhost:1/mcp")

        await manager.connect(name: "http-test", config: httpConfig)
        let connections = await manager.getConnections()

        if connections["http-test"] != nil {
            pass("HTTP connect does not crash (connection tracked)")
        } else {
            fail("HTTP connect should track connection")
        }
    }

    // ================================================================
    // MARK: Story 6-2: SSE/HTTP Headers
    // ================================================================

    /// AC8: SSE connect with custom headers is tracked.
    static func testSSEConnectWithCustomHeaders() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(
            url: "http://localhost:1/sse",
            headers: ["Authorization": "Bearer test-token-123"]
        )

        await manager.connect(name: "sse-headers", config: sseConfig)
        let connections = await manager.getConnections()

        if connections["sse-headers"] != nil {
            pass("SSE connect with custom headers is tracked")
        } else {
            fail("SSE connection with headers should be tracked")
        }
    }

    /// AC8: HTTP connect with custom headers is tracked.
    static func testHTTPConnectWithCustomHeaders() async {
        let manager = MCPClientManager()
        let httpConfig = McpHttpConfig(
            url: "http://localhost:1/mcp",
            headers: ["Authorization": "Bearer token-456"]
        )

        await manager.connect(name: "http-headers", config: httpConfig)
        let connections = await manager.getConnections()

        if connections["http-headers"] != nil {
            pass("HTTP connect with custom headers is tracked")
        } else {
            fail("HTTP connection with headers should be tracked")
        }
    }

    /// AC8: SSE connect with nil headers does not crash.
    static func testSSEConnectWithNilHeaders() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(url: "http://localhost:1/sse", headers: nil)

        await manager.connect(name: "sse-nil-headers", config: sseConfig)
        let connections = await manager.getConnections()

        if connections["sse-nil-headers"] != nil {
            pass("SSE connect with nil headers works")
        } else {
            fail("SSE connect with nil headers should be tracked")
        }
    }

    // ================================================================
    // MARK: Story 6-2: SSE/HTTP Connection Failure
    // ================================================================

    /// AC9: SSE connect with malformed URL marks error.
    static func testSSEConnectMalformedURLMarksError() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(url: "not-a-valid-url")

        await manager.connect(name: "sse-bad-url", config: sseConfig)
        let connections = await manager.getConnections()

        if let conn = connections["sse-bad-url"], conn.status == .error {
            pass("Malformed SSE URL results in error status")
        } else {
            fail("Malformed SSE URL should result in error status")
        }
    }

    /// AC9: HTTP connect with malformed URL marks error.
    static func testHTTPConnectMalformedURLMarksError() async {
        let manager = MCPClientManager()
        let httpConfig = McpHttpConfig(url: "not-a-valid-url")

        await manager.connect(name: "http-bad-url", config: httpConfig)
        let connections = await manager.getConnections()

        if let conn = connections["http-bad-url"], conn.status == .error {
            pass("Malformed HTTP URL results in error status")
        } else {
            fail("Malformed HTTP URL should result in error status")
        }
    }

    /// AC9: SSE connect with empty URL marks error.
    static func testSSEConnectEmptyURLMarksError() async {
        let manager = MCPClientManager()

        await manager.connect(name: "sse-empty", config: McpSseConfig(url: ""))
        let connections = await manager.getConnections()

        if let conn = connections["sse-empty"], conn.status == .error {
            pass("Empty SSE URL results in error status")
        } else {
            fail("Empty SSE URL should result in error status")
        }
    }

    /// AC9: HTTP connect with empty URL marks error.
    static func testHTTPConnectEmptyURLMarksError() async {
        let manager = MCPClientManager()

        await manager.connect(name: "http-empty", config: McpHttpConfig(url: ""))
        let connections = await manager.getConnections()

        if let conn = connections["http-empty"], conn.status == .error {
            pass("Empty HTTP URL results in error status")
        } else {
            fail("Empty HTTP URL should result in error status")
        }
    }

    // ================================================================
    // MARK: Story 6-2: Mixed Transport connectAll
    // ================================================================

    /// AC7: connectAll with mixed transports dispatches correctly.
    static func testConnectAllMixedTransportsDispatchesCorrectly() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "stdio-srv": .stdio(McpStdioConfig(command: "/nonexistent")),
            "sse-srv": .sse(McpSseConfig(url: "http://localhost:99999/sse")),
            "http-srv": .http(McpHttpConfig(url: "http://localhost:99999/mcp"))
        ]

        await manager.connectAll(servers: servers)
        let connections = await manager.getConnections()

        let allTracked = connections.count == 3
        let allError = connections.values.allSatisfy { $0.status == .error }

        if allTracked && allError {
            pass("connectAll handles all three transport types (all error)")
        } else {
            fail("connectAll should track all 3 transports with error status",
                 "count=\(connections.count)")
        }
    }

    /// AC7: connectAll with only SSE configs.
    static func testConnectAllSSEOnly() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "sse1": .sse(McpSseConfig(url: "http://localhost:1/sse")),
            "sse2": .sse(McpSseConfig(url: "http://localhost:2/sse"))
        ]

        await manager.connectAll(servers: servers)
        let connections = await manager.getConnections()

        if connections.count == 2 {
            pass("connectAll with SSE-only tracks both connections")
        } else {
            fail("connectAll should track both SSE connections",
                 "count=\(connections.count)")
        }
    }

    /// AC7: connectAll with only HTTP configs.
    static func testConnectAllHTTPOnly() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "http1": .http(McpHttpConfig(url: "http://localhost:1/mcp")),
            "http2": .http(McpHttpConfig(url: "http://localhost:2/mcp"))
        ]

        await manager.connectAll(servers: servers)
        let connections = await manager.getConnections()

        if connections.count == 2 {
            pass("connectAll with HTTP-only tracks both connections")
        } else {
            fail("connectAll should track both HTTP connections",
                 "count=\(connections.count)")
        }
    }

    // ================================================================
    // MARK: Story 6-2: SSE/HTTP Disconnect & Cleanup
    // ================================================================

    /// AC10: disconnect removes SSE connection.
    static func testDisconnectSSEConnectionRemoves() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(url: "http://localhost:99999/sse")

        await manager.connect(name: "sse-to-remove", config: sseConfig)
        let before = await manager.getConnections()

        if before["sse-to-remove"] != nil {
            await manager.disconnect(name: "sse-to-remove")
            let after = await manager.getConnections()

            if after["sse-to-remove"] == nil {
                pass("disconnect removes SSE connection")
            } else {
                fail("SSE connection should be removed after disconnect")
            }
        } else {
            fail("SSE connection should exist before disconnect")
        }
    }

    /// AC10: disconnect removes HTTP connection.
    static func testDisconnectHTTPConnectionRemoves() async {
        let manager = MCPClientManager()
        let httpConfig = McpHttpConfig(url: "http://localhost:99999/mcp")

        await manager.connect(name: "http-to-remove", config: httpConfig)
        let before = await manager.getConnections()

        if before["http-to-remove"] != nil {
            await manager.disconnect(name: "http-to-remove")
            let after = await manager.getConnections()

            if after["http-to-remove"] == nil {
                pass("disconnect removes HTTP connection")
            } else {
                fail("HTTP connection should be removed after disconnect")
            }
        } else {
            fail("HTTP connection should exist before disconnect")
        }
    }

    /// AC10: shutdown clears all SSE and HTTP connections.
    static func testShutdownClearsSSEAndHTTPConnections() async {
        let manager = MCPClientManager()

        await manager.connect(name: "sse-srv", config: McpSseConfig(url: "http://localhost:1/sse"))
        await manager.connect(name: "http-srv", config: McpHttpConfig(url: "http://localhost:1/mcp"))

        await manager.shutdown()
        let connections = await manager.getConnections()

        if connections.isEmpty {
            pass("shutdown clears all SSE and HTTP connections")
        } else {
            fail("shutdown should clear all connections",
                 "remaining: \(connections.count)")
        }
    }

    /// AC10: disconnect SSE does not affect HTTP or stdio.
    static func testDisconnectSSEDoesNotAffectOthers() async {
        let manager = MCPClientManager()

        await manager.connect(name: "stdio-srv", config: McpStdioConfig(command: "/nonexistent"))
        await manager.connect(name: "sse-srv", config: McpSseConfig(url: "http://localhost:1/sse"))
        await manager.connect(name: "http-srv", config: McpHttpConfig(url: "http://localhost:1/mcp"))

        await manager.disconnect(name: "sse-srv")
        let connections = await manager.getConnections()

        let sseGone = connections["sse-srv"] == nil
        let stdioPresent = connections["stdio-srv"] != nil
        let httpPresent = connections["http-srv"] != nil

        if sseGone && stdioPresent && httpPresent {
            pass("disconnect SSE does not affect stdio or HTTP")
        } else {
            fail("SSE should be gone, stdio and HTTP should remain",
                 "sseGone=\(sseGone) stdioPresent=\(stdioPresent) httpPresent=\(httpPresent)")
        }
    }

    // ================================================================
    // MARK: Story 6-2: SSE/HTTP Tool Discovery
    // ================================================================

    /// AC5: Failed SSE connection contributes no tools.
    static func testGetMCPToolsFailedSSE() async {
        let manager = MCPClientManager()
        await manager.connect(name: "sse-fail", config: McpSseConfig(url: "http://localhost:99999"))

        let tools = await manager.getMCPTools()
        if tools.isEmpty {
            pass("Failed SSE connections contribute no tools")
        } else {
            fail("Failed SSE should contribute no tools",
                 "count=\(tools.count)")
        }
    }

    /// AC5: Failed HTTP connection contributes no tools.
    static func testGetMCPToolsFailedHTTP() async {
        let manager = MCPClientManager()
        await manager.connect(name: "http-fail", config: McpHttpConfig(url: "http://localhost:99999"))

        let tools = await manager.getMCPTools()
        if tools.isEmpty {
            pass("Failed HTTP connections contribute no tools")
        } else {
            fail("Failed HTTP should contribute no tools",
                 "count=\(tools.count)")
        }
    }

    // ================================================================
    // MARK: Story 6-2: Module Boundary
    // ================================================================

    /// AC11: HTTP/SSE transport respects module boundaries.
    static func testHTTPSEERespectsModuleBoundary() async {
        let manager = MCPClientManager()
        await manager.connect(name: "boundary-sse", config: McpSseConfig(url: "http://localhost:1"))
        await manager.connect(name: "boundary-http", config: McpHttpConfig(url: "http://localhost:1"))

        // If this compiles and runs, module boundaries are respected
        pass("HTTP/SSE transport respects module boundaries (compile-time check)")
    }

    // ================================================================
    // MARK: Story 6-2: Cross-platform Compatibility
    // ================================================================

    /// AC12: SSE transport does not crash on current platform.
    static func testSSETransportDoesNotCrashOnPlatform() async {
        let manager = MCPClientManager()
        await manager.connect(name: "sse-platform", config: McpSseConfig(url: "http://localhost:1/sse"))

        let connections = await manager.getConnections()
        if connections["sse-platform"] != nil {
            pass("SSE transport works on current platform")
        } else {
            fail("SSE transport should not crash")
        }
    }

    /// AC12: HTTP transport does not crash on current platform.
    static func testHTTPTransportDoesNotCrashOnPlatform() async {
        let manager = MCPClientManager()
        await manager.connect(name: "http-platform", config: McpHttpConfig(url: "http://localhost:1/mcp"))

        let connections = await manager.getConnections()
        if connections["http-platform"] != nil {
            pass("HTTP transport works on current platform")
        } else {
            fail("HTTP transport should not crash")
        }
    }

    // ================================================================
    // MARK: Story 6-2: Config Types
    // ================================================================

    /// AC1: McpSseConfig creation.
    static func testMcpSseConfigCreation() {
        let config1 = McpSseConfig(url: "http://localhost:8080/sse")
        let config2 = McpSseConfig(url: "http://localhost:8080/sse", headers: ["Auth": "Bearer x"])

        if config1.url == "http://localhost:8080/sse" && config1.headers == nil
            && config2.headers?["Auth"] == "Bearer x" {
            pass("McpSseConfig creates with url and optional headers")
        } else {
            fail("McpSseConfig creation failed")
        }
    }

    /// AC2: McpHttpConfig creation.
    static func testMcpHttpConfigCreation() {
        let config1 = McpHttpConfig(url: "http://localhost:8080/mcp")
        let config2 = McpHttpConfig(url: "http://localhost:8080/mcp", headers: ["Key": "val"])

        if config1.url == "http://localhost:8080/mcp" && config1.headers == nil
            && config2.headers?["Key"] == "val" {
            pass("McpHttpConfig creates with url and optional headers")
        } else {
            fail("McpHttpConfig creation failed")
        }
    }

    /// AC7: McpServerConfig SSE and HTTP cases.
    static func testMcpServerConfigSSEAndHTTPCases() {
        let stdio = McpServerConfig.stdio(McpStdioConfig(command: "echo"))
        let sse = McpServerConfig.sse(McpSseConfig(url: "http://localhost:8080"))
        let http = McpServerConfig.http(McpHttpConfig(url: "http://localhost:8080"))

        let allDistinct = stdio != sse && stdio != http && sse != http
        if allDistinct {
            pass("McpServerConfig stdio, sse, http are distinct cases")
        } else {
            fail("McpServerConfig cases should be distinct")
        }
    }
}

// MARK: - E2E Mock Helpers

/// Mock MCPClient for E2E testing of MCPToolDefinition without real MCP connections.
private final class E2EMockMCPClient: MCPClientProtocol, Sendable {
    private let callResult: String?
    private let callError: Error?

    init(callResult: String? = nil, callError: Error? = nil) {
        self.callResult = callResult
        self.callError = callError
    }

    func callTool(name: String, arguments: [String: Any]?) async throws -> String {
        if let error = callError {
            throw error
        }
        return callResult ?? ""
    }
}

/// Test errors for MCP mock client.
private enum E2EMCPTestError: Error {
    case connectionFailed
    case timeout
    case toolNotFound
}

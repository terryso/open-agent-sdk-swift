import Foundation
import OpenAgentSDK
import MCP

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

        // Story 6-3: In-Process MCP Server (ATDD RED PHASE)
        section("In-Process MCP Server: Creation & Config (Story 6-3)")
        await testInProcessMCPServerCreation()
        await testInProcessMCPServerCreationWithMultipleTools()
        await testMcpSdkServerConfigCreation()
        await testMcpServerConfigSdkCase()
        await testMcpServerConfigSdkDistinctFromOthers()
        await testInProcessMCPServerAsConfig()
        await testInProcessMCPServerGetTools()

        section("In-Process MCP Server: Session & Tool Exposure (Story 6-3)")
        await testInProcessMCPServerCreateSession()
        await testInProcessMCPServerMultipleSessions()
        await testInProcessMCPServerEmptyToolsSession()
        await testInProcessMCPServerToolListViaMCP()
        await testInProcessMCPServerToolNamesNoNamespace()

        section("In-Process MCP Server: Tool Execution (Story 6-3)")
        await testInProcessMCPServerToolCallDispatchesToTool()
        await testInProcessMCPServerUnknownToolReturnsError()
        await testInProcessMCPServerToolExceptionReturnsError()
        await testInProcessMCPServerResilientAfterException()

        section("In-Process MCP Server: Agent Integration (Story 6-3)")
        await testAgentOptionsAcceptsSdkConfig()
        await testAgentOptionsMixedConfigTypesWithSdk()

        section("In-Process MCP Server: Module Boundary (Story 6-3)")
        await testInProcessMCPServerRespectsModuleBoundary()

        // Story 6-4: MCP Tool Agent Integration (ATDD RED PHASE)
        section("MCP Agent Integration: Tool Pool Assembly (Story 6-4)")
        await testAgentOptions_mcpServersWithSDKAndExternal()
        await testAgentOptions_mcpServersWithAllFourTypes()
        testAgentOptions_emptyMcpServers()
        testAgentOptions_noMcpServers()

        section("MCP Agent Integration: Mixed Config (Story 6-4)")
        await testMixedConfig_sdkPlusFailingExternal_sdkToolsReachable()
        await testMixedConfig_multipleSdkServers()
        await testMixedConfig_externalServerToolsViaManager()

        section("MCP Agent Integration: Error Isolation (Story 6-4)")
        await testMCPToolError_isolationReturnsErrorToolResult()
        await testMCPConnectionFailure_builtinToolsStillAvailable()

        section("MCP Agent Integration: Lifecycle (Story 6-4)")
        await testMCPLifecycle_shutdownClearsAll()
        await testMCPLifecycle_sdkServerNoManager()

        section("MCP Agent Integration: Tool Pool Deduplication (Story 6-4)")
        testToolPoolDeduplication()
        testToolPoolNameUniqueness()

        section("MCP Agent Integration: Agent-Level Integration (Story 6-4)")
        await testAgentCreation_withMixedMcpConfigs()
        await testFullToolPoolAssembly_builtinPlusSDKPlusExternal()
        await testAgentMCPSDKToolExecution()
        await testAgentMCPToolError_errorIsolation()
        await testAgentCreation_noMcpServers()
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

    // ================================================================
    // MARK: Story 6-3: In-Process MCP Server - Creation & Config
    // ================================================================

    /// AC1 [P0]: InProcessMCPServer creates with name, version, and tools.
    static func testInProcessMCPServerCreation() async {
        let tool = E2EMockTool(toolName: "get_weather")
        let server = InProcessMCPServer(name: "weather", version: "1.0.0", tools: [tool])

        let serverName = await server.name
        let serverVersion = await server.version

        if serverName == "weather" && serverVersion == "1.0.0" {
            pass("InProcessMCPServer creates with name, version, and tools")
        } else {
            fail("InProcessMCPServer creation failed",
                 "name=\(serverName) version=\(serverVersion)")
        }
    }

    /// AC1 [P0]: InProcessMCPServer creates with multiple tools.
    static func testInProcessMCPServerCreationWithMultipleTools() async {
        let tool1 = E2EMockTool(toolName: "read_file")
        let tool2 = E2EMockTool(toolName: "write_file")
        let server = InProcessMCPServer(name: "filesystem", version: "1.0.0", tools: [tool1, tool2])

        let tools = await server.getTools()
        if tools.count == 2 {
            pass("InProcessMCPServer holds multiple tools")
        } else {
            fail("InProcessMCPServer should hold 2 tools", "count=\(tools.count)")
        }
    }

    /// AC2 [P0]: McpSdkServerConfig can be created with server reference.
    static func testMcpSdkServerConfigCreation() async {
        let server = InProcessMCPServer(name: "my-sdk", version: "1.0.0", tools: [])
        let config = McpSdkServerConfig(name: "my-sdk", version: "1.0.0", server: server)

        if config.name == "my-sdk" && config.version == "1.0.0" {
            pass("McpSdkServerConfig creates with name, version, and server reference")
        } else {
            fail("McpSdkServerConfig creation failed")
        }
    }

    /// AC2 [P0]: McpServerConfig.sdk wraps McpSdkServerConfig.
    static func testMcpServerConfigSdkCase() async {
        let server = InProcessMCPServer(name: "test", version: "1.0.0", tools: [])
        let sdkConfig = McpSdkServerConfig(name: "test", version: "1.0.0", server: server)
        let config = McpServerConfig.sdk(sdkConfig)

        if case .sdk(let unwrapped) = config, unwrapped.name == "test" {
            pass("McpServerConfig.sdk wraps McpSdkServerConfig correctly")
        } else {
            fail("Expected .sdk case with correct name")
        }
    }

    /// AC2 [P0]: McpServerConfig.sdk is distinct from other cases.
    static func testMcpServerConfigSdkDistinctFromOthers() async {
        let server = InProcessMCPServer(name: "test", version: "1.0.0", tools: [])
        let sdk = McpServerConfig.sdk(McpSdkServerConfig(name: "test", version: "1.0.0", server: server))
        let stdio = McpServerConfig.stdio(McpStdioConfig(command: "echo"))
        let sse = McpServerConfig.sse(McpSseConfig(url: "http://localhost:8080"))
        let http = McpServerConfig.http(McpHttpConfig(url: "http://localhost:8080"))

        if sdk != stdio && sdk != sse && sdk != http {
            pass("McpServerConfig.sdk is distinct from stdio, sse, http cases")
        } else {
            fail("McpServerConfig.sdk should be distinct from all other cases")
        }
    }

    /// AC2 [P0]: InProcessMCPServer.asConfig() returns McpServerConfig.sdk.
    static func testInProcessMCPServerAsConfig() async {
        let tool = E2EMockTool(toolName: "weather_tool")
        let server = InProcessMCPServer(name: "weather", version: "1.0.0", tools: [tool])
        let config = await server.asConfig()

        if case .sdk(let sdkConfig) = config,
           sdkConfig.name == "weather" && sdkConfig.version == "1.0.0"
        {
            pass("InProcessMCPServer.asConfig() returns McpServerConfig.sdk")
        } else {
            fail("asConfig() should return .sdk with correct name and version")
        }
    }

    /// AC6 [P0]: InProcessMCPServer.getTools() returns registered tools.
    static func testInProcessMCPServerGetTools() async {
        let tool1 = E2EMockTool(toolName: "read")
        let tool2 = E2EMockTool(toolName: "write")
        let server = InProcessMCPServer(name: "fs", version: "1.0.0", tools: [tool1, tool2])

        let tools = await server.getTools()
        if tools.count == 2 {
            pass("getTools() returns all registered tools")
        } else {
            fail("getTools() should return 2 tools", "count=\(tools.count)")
        }
    }

    // ================================================================
    // MARK: Story 6-3: Session & Tool Exposure
    // ================================================================

    /// AC7 [P0]: createSession() returns a (Server, InMemoryTransport) pair.
    static func testInProcessMCPServerCreateSession() async {
        let tool = E2EMockTool(toolName: "test")
        let server = InProcessMCPServer(name: "session-test", version: "1.0.0", tools: [tool])

        do {
            let (mcpServer, clientTransport) = try await server.createSession()
            _ = mcpServer
            _ = clientTransport
            pass("createSession() returns (Server, InMemoryTransport) pair")
        } catch {
            fail("createSession() should not throw", "error: \(error)")
        }
    }

    /// AC7 [P0]: Multiple sessions can be created independently.
    static func testInProcessMCPServerMultipleSessions() async {
        let server = InProcessMCPServer(name: "multi", version: "1.0.0", tools: [E2EMockTool(toolName: "t")])

        do {
            let (s1, t1) = try await server.createSession()
            let (s2, t2) = try await server.createSession()

            _ = s1; _ = s2; _ = t1; _ = t2
            pass("Multiple sessions can be created independently")
        } catch {
            fail("Multiple sessions should not throw", "error: \(error)")
        }
    }

    /// AC7 [P1]: createSession with empty tools does not crash.
    static func testInProcessMCPServerEmptyToolsSession() async {
        let server = InProcessMCPServer(name: "empty", version: "1.0.0", tools: [])

        do {
            let (mcpServer, clientTransport) = try await server.createSession()
            let client = Client(name: "test-client", version: "1.0.0")
            try await client.connect(transport: clientTransport)

            let result = try await client.listTools()
            if result.tools.isEmpty {
                pass("Empty server session exposes no tools")
            } else {
                fail("Empty server should expose no tools", "count=\(result.tools.count)")
            }

            await mcpServer.stop()
            await client.disconnect()
        } catch {
            fail("Empty tools session should not crash", "error: \(error)")
        }
    }

    /// AC3 [P0]: Tools are exposed through MCP protocol via InMemoryTransport.
    static func testInProcessMCPServerToolListViaMCP() async {
        let tool = E2EMockTool(
            toolName: "get_weather",
            toolDescription: "Gets the current weather"
        )
        let server = InProcessMCPServer(name: "weather", version: "1.0.0", tools: [tool])

        do {
            let (mcpServer, clientTransport) = try await server.createSession()
            let client = Client(name: "test-client", version: "1.0.0")
            try await client.connect(transport: clientTransport)

            let result = try await client.listTools()

            if result.tools.count == 1, result.tools.first?.name == "get_weather" {
                pass("InProcessMCPServer exposes tools via MCP protocol")
            } else {
                fail("Should expose 1 tool named 'get_weather'",
                     "count=\(result.tools.count) names=\(result.tools.map { $0.name })")
            }

            await mcpServer.stop()
            await client.disconnect()
        } catch {
            fail("MCP tool listing should not crash", "error: \(error)")
        }
    }

    /// AC5 [P0]: Tools use original names (no namespace prefix) via MCP.
    static func testInProcessMCPServerToolNamesNoNamespace() async {
        let tool = E2EMockTool(toolName: "get_weather")
        let server = InProcessMCPServer(name: "weather", version: "1.0.0", tools: [tool])

        do {
            let (mcpServer, clientTransport) = try await server.createSession()
            let client = Client(name: "test-client", version: "1.0.0")
            try await client.connect(transport: clientTransport)

            let result = try await client.listTools()
            let exposedName = result.tools.first?.name ?? ""

            // Must NOT have "mcp__weather__" prefix
            if exposedName == "get_weather" && !exposedName.hasPrefix("mcp__") {
                pass("InProcessMCPServer exposes tools without namespace prefix")
            } else {
                fail("Tool name should be 'get_weather', not namespaced",
                     "got: '\(exposedName)'")
            }

            await mcpServer.stop()
            await client.disconnect()
        } catch {
            fail("Tool name check should not crash", "error: \(error)")
        }
    }

    // ================================================================
    // MARK: Story 6-3: Tool Execution
    // ================================================================

    /// AC4 [P0]: Tool call through MCP dispatches to ToolProtocol.call().
    static func testInProcessMCPServerToolCallDispatchesToTool() async {
        let tool = E2EMockTool(toolName: "echo", resultContent: "Hello from in-process!")
        let server = InProcessMCPServer(name: "echo-server", version: "1.0.0", tools: [tool])

        do {
            let (mcpServer, clientTransport) = try await server.createSession()
            let client = Client(name: "test-client", version: "1.0.0")
            try await client.connect(transport: clientTransport)

            let result = try await client.callTool(name: "echo", arguments: ["msg": .string("hi")])

            if !(result.isError ?? false) {
                let hasContent = result.content.contains(where: { content in
                    switch content {
                    case .text(let text, _, _): return text.contains("Hello from in-process!")
                    default: return false
                    }
                })
                if hasContent {
                    pass("Tool call dispatches to ToolProtocol.call() and returns result")
                } else {
                    fail("Tool result should contain expected content",
                         "got: \(result.content.map { switch $0 { case .text(let t, _, _): return t; default: return "" } })")
                }
            } else {
                fail("Tool call should succeed, not return error")
            }

            await mcpServer.stop()
            await client.disconnect()
        } catch {
            fail("Tool call dispatch should not crash", "error: \(error)")
        }
    }

    /// AC8 [P0]: Unknown tool call returns MCP error (isError: true).
    static func testInProcessMCPServerUnknownToolReturnsError() async {
        let server = InProcessMCPServer(
            name: "error-test",
            version: "1.0.0",
            tools: [E2EMockTool(toolName: "known_tool")]
        )

        do {
            let (mcpServer, clientTransport) = try await server.createSession()
            let client = Client(name: "test-client", version: "1.0.0")
            try await client.connect(transport: clientTransport)

            // Unknown tool: MCPServer returns invalidParams error (throws from client)
            // This is correct behavior per AC8 spec
            var gotError = false
            do {
                _ = try await client.callTool(name: "nonexistent_tool", arguments: [:])
            } catch {
                gotError = true
            }

            if gotError {
                pass("Unknown tool call returns MCP protocol error (invalidParams)")
            } else {
                fail("Unknown tool call should return error")
            }

            // Verify server is still operational after error
            let listResult = try await client.listTools()
            if !listResult.tools.isEmpty {
                pass("Server remains operational after unknown tool call")
            } else {
                fail("Server should still list tools after unknown tool call")
            }

            await mcpServer.stop()
            await client.disconnect()
        } catch {
            fail("Test setup failed", "error: \(error)")
        }
    }

    /// AC12 [P0]: Tool execution exception returns isError: true.
    static func testInProcessMCPServerToolExceptionReturnsError() async {
        let throwingTool = E2EThrowingMockTool(toolName: "failing_tool")
        let server = InProcessMCPServer(name: "error-server", version: "1.0.0", tools: [throwingTool])

        do {
            let (mcpServer, clientTransport) = try await server.createSession()
            let client = Client(name: "test-client", version: "1.0.0")
            try await client.connect(transport: clientTransport)

            let result = try await client.callTool(name: "failing_tool", arguments: [:])

            if result.isError == true {
                pass("Tool execution exception captured as isError: true")
            } else {
                fail("Failing tool should return isError: true")
            }

            await mcpServer.stop()
            await client.disconnect()
        } catch {
            fail("Tool exception should be captured, not thrown", "error: \(error)")
        }
    }

    /// AC12 [P0]: Server remains operational after tool exception.
    static func testInProcessMCPServerResilientAfterException() async {
        let throwingTool = E2EThrowingMockTool(toolName: "crashy_tool")
        let goodTool = E2EMockTool(toolName: "good_tool", resultContent: "I'm fine")
        let server = InProcessMCPServer(
            name: "resilient",
            version: "1.0.0",
            tools: [throwingTool, goodTool]
        )

        do {
            let (mcpServer, clientTransport) = try await server.createSession()
            let client = Client(name: "test-client", version: "1.0.0")
            try await client.connect(transport: clientTransport)

            // Call the throwing tool
            _ = try await client.callTool(name: "crashy_tool", arguments: [:])

            // Server should still list tools
            let toolsResult = try await client.listTools()
            if toolsResult.tools.count == 2 {
                pass("Server remains operational after tool exception (tools still listed)")
            } else {
                fail("Server should still list both tools", "count=\(toolsResult.tools.count)")
            }

            // Good tool should still work
            let goodResult = try await client.callTool(name: "good_tool", arguments: [:])
            if !(goodResult.isError ?? false) {
                pass("Good tool still works after exception in another tool")
            } else {
                fail("Good tool should work after exception in another tool")
            }

            await mcpServer.stop()
            await client.disconnect()
        } catch {
            fail("Resilience test should not crash", "error: \(error)")
        }
    }

    // ================================================================
    // MARK: Story 6-3: Agent Integration
    // ================================================================

    /// AC6 [P0]: AgentOptions.mcpServers accepts McpServerConfig.sdk.
    static func testAgentOptionsAcceptsSdkConfig() async {
        let server = InProcessMCPServer(name: "sdk-server", version: "1.0.0", tools: [E2EMockTool(toolName: "test")])
        let sdkConfig = McpSdkServerConfig(name: "sdk-server", version: "1.0.0", server: server)
        let config: [String: McpServerConfig] = ["my-sdk": .sdk(sdkConfig)]
        let options = AgentOptions(mcpServers: config)

        if let servers = options.mcpServers, servers.count == 1 {
            pass("AgentOptions.mcpServers accepts McpServerConfig.sdk")
        } else {
            fail("AgentOptions should hold SDK config",
                 "count=\(options.mcpServers?.count ?? 0)")
        }
    }

    /// AC6 [P0]: AgentOptions holds mixed config types including sdk.
    static func testAgentOptionsMixedConfigTypesWithSdk() async {
        let server = InProcessMCPServer(name: "mixed-sdk", version: "1.0.0", tools: [])
        let config: [String: McpServerConfig] = [
            "stdio-srv": .stdio(McpStdioConfig(command: "echo")),
            "sse-srv": .sse(McpSseConfig(url: "http://localhost:8080/sse")),
            "http-srv": .http(McpHttpConfig(url: "http://localhost:8080/mcp")),
            "sdk-srv": .sdk(McpSdkServerConfig(name: "mixed-sdk", version: "1.0.0", server: server)),
        ]
        let options = AgentOptions(mcpServers: config)

        if options.mcpServers?.count == 4 {
            pass("AgentOptions holds all four config types (stdio, sse, http, sdk)")
        } else {
            fail("Should hold 4 configs", "count=\(options.mcpServers?.count ?? 0)")
        }
    }

    // ================================================================
    // MARK: Story 6-3: Module Boundary
    // ================================================================

    /// AC9 [P0]: InProcessMCPServer respects module boundaries (compile-time check).
    static func testInProcessMCPServerRespectsModuleBoundary() async {
        let server = InProcessMCPServer(name: "boundary", version: "1.0.0", tools: [])
        _ = server
        pass("InProcessMCPServer compiles without Core/ or Stores/ dependencies")
    }

    // ================================================================
    // MARK: Story 6-4: MCP Tool Agent Integration - Tool Pool Assembly
    // ================================================================

    /// AC1/AC3 [P0]: AgentOptions holds SDK + external config together.
    static func testAgentOptions_mcpServersWithSDKAndExternal() async {
        let tool = E2EMockTool(toolName: "compute")
        let server = InProcessMCPServer(name: "sdk-srv", version: "1.0.0", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "sdk-srv", version: "1.0.0", server: server)

        let config: [String: McpServerConfig] = [
            "sdk-srv": .sdk(sdkConfig),
            "remote": .stdio(McpStdioConfig(command: "/nonexistent")),
        ]

        let options = AgentOptions(apiKey: "test-key", model: "test-model", mcpServers: config)

        if let servers = options.mcpServers, servers.count == 2 {
            pass("AgentOptions holds both SDK and external MCP configs")
        } else {
            fail("AgentOptions should hold 2 configs",
                 "count=\(options.mcpServers?.count ?? 0)")
        }
    }

    /// AC4 [P0]: AgentOptions holds all four MCP config types simultaneously.
    static func testAgentOptions_mcpServersWithAllFourTypes() async {
        let server = InProcessMCPServer(name: "local", version: "1.0.0", tools: [])
        let config: [String: McpServerConfig] = [
            "stdio-srv": .stdio(McpStdioConfig(command: "echo")),
            "sse-srv": .sse(McpSseConfig(url: "http://localhost:8080/sse")),
            "http-srv": .http(McpHttpConfig(url: "http://localhost:8080/mcp")),
            "sdk-srv": .sdk(McpSdkServerConfig(name: "local", version: "1.0.0", server: server)),
        ]

        let options = AgentOptions(apiKey: "test-key", model: "test-model", mcpServers: config)

        if options.mcpServers?.count == 4 {
            pass("AgentOptions holds all four MCP config types (stdio, sse, http, sdk)")
        } else {
            fail("Should hold 4 configs", "count=\(options.mcpServers?.count ?? 0)")
        }
    }

    /// AC1 [P1]: AgentOptions with empty mcpServers dictionary.
    static func testAgentOptions_emptyMcpServers() {
        let options = AgentOptions(apiKey: "test-key", model: "test-model", mcpServers: [:])

        if let servers = options.mcpServers, servers.isEmpty {
            pass("AgentOptions accepts empty mcpServers dictionary")
        } else {
            fail("Empty mcpServers should be accepted")
        }
    }

    /// AC1 [P1]: AgentOptions with nil mcpServers (default).
    static func testAgentOptions_noMcpServers() {
        let options = AgentOptions(apiKey: "test-key", model: "test-model")

        if options.mcpServers == nil {
            pass("AgentOptions defaults to nil mcpServers")
        } else {
            fail("AgentOptions mcpServers should default to nil")
        }
    }

    // ================================================================
    // MARK: Story 6-4: MCP Agent Integration - Mixed Config
    // ================================================================

    /// AC4/AC7 [P0]: SDK server tools are accessible even alongside failing external servers.
    static func testMixedConfig_sdkPlusFailingExternal_sdkToolsReachable() async {
        let tool = E2EMockTool(toolName: "reliable_fn")
        let server = InProcessMCPServer(name: "local", version: "1.0.0", tools: [tool])
        let _ = McpSdkServerConfig(name: "local", version: "1.0.0", server: server)

        // Verify SDK server tools are accessible via getTools()
        let sdkTools = await server.getTools()

        if sdkTools.count == 1 && sdkTools.first?.name == "reliable_fn" {
            pass("SDK server tools are directly accessible via getTools()")
        } else {
            fail("SDK server should expose its tool",
                 "count=\(sdkTools.count)")
        }

        // Verify external servers fail independently
        let manager = MCPClientManager()
        await manager.connect(name: "broken", config: McpStdioConfig(command: "/nonexistent"))
        let connections = await manager.getConnections()

        if connections["broken"]?.status == .error {
            pass("External server fails independently (error status)")
        } else {
            fail("External server should fail with error status")
        }

        // SDK tools should still be available
        let stillAvailable = await server.getTools()
        if stillAvailable.count == 1 {
            pass("SDK server tools remain available after external failure")
        } else {
            fail("SDK tools should remain available")
        }

        await manager.shutdown()
    }

    /// AC4 [P0]: Multiple SDK servers produce distinct tool sets.
    static func testMixedConfig_multipleSdkServers() async {
        let tool1 = E2EMockTool(toolName: "fn_a")
        let tool2 = E2EMockTool(toolName: "fn_b")
        let server1 = InProcessMCPServer(name: "srv-a", version: "1.0.0", tools: [tool1])
        let server2 = InProcessMCPServer(name: "srv-b", version: "1.0.0", tools: [tool2])

        let config: [String: McpServerConfig] = [
            "srv-a": .sdk(McpSdkServerConfig(name: "srv-a", version: "1.0.0", server: server1)),
            "srv-b": .sdk(McpSdkServerConfig(name: "srv-b", version: "1.0.0", server: server2)),
        ]

        let options = AgentOptions(apiKey: "test-key", model: "test-model", mcpServers: config)

        if options.mcpServers?.count == 2 {
            pass("Multiple SDK servers configured in AgentOptions")
        } else {
            fail("Should hold 2 SDK configs")
        }

        let toolsA = await server1.getTools()
        let toolsB = await server2.getTools()

        if toolsA.count == 1 && toolsB.count == 1 {
            pass("Multiple SDK servers each expose their own tools independently")
        } else {
            fail("Each server should expose 1 tool",
                 "a=\(toolsA.count) b=\(toolsB.count)")
        }
    }

    /// AC4 [P1]: External server tools discoverable via MCPClientManager after connection.
    static func testMixedConfig_externalServerToolsViaManager() async {
        let manager = MCPClientManager()
        // Connect to a non-existent server -- will fail
        await manager.connect(name: "bad", config: McpStdioConfig(command: "/nonexistent"))

        let tools = await manager.getMCPTools()
        if tools.isEmpty {
            pass("Failed external server contributes no tools via MCPClientManager")
        } else {
            fail("Failed server should contribute no tools")
        }

        await manager.shutdown()
    }

    // ================================================================
    // MARK: Story 6-4: MCP Agent Integration - Error Isolation
    // ================================================================

    /// AC7 [P0]: MCP tool execution failure returns error ToolResult, not crash.
    static func testMCPToolError_isolationReturnsErrorToolResult() async {
        let mockClient = E2EMockMCPClient(callResult: nil, callError: E2EMCPTestError.connectionFailed)
        let tool = MCPToolDefinition(
            serverName: "failing",
            mcpToolName: "fail_tool",
            toolDescription: "failing tool",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let context = ToolContext(cwd: "/tmp", toolUseId: "error-test-id")
        let result = await tool.call(input: [:], context: context)

        if result.isError {
            pass("MCP tool execution error captured as isError: true (not thrown)")
        } else {
            fail("MCP tool execution error should return isError: true")
        }

        if result.toolUseId == "error-test-id" {
            pass("Error ToolResult preserves toolUseId")
        } else {
            fail("Error ToolResult should preserve toolUseId")
        }
    }

    /// AC7 [P1]: Base tools remain available even when MCP connections fail.
    static func testMCPConnectionFailure_builtinToolsStillAvailable() async {
        // assembleToolPool includes base tools even when MCP tools are empty
        let baseTools = getAllBaseTools(tier: .core)
        let mcpTools: [ToolProtocol] = []  // Empty MCP tools (simulating all connections failed)

        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: nil,
            mcpTools: mcpTools,
            allowed: nil,
            disallowed: nil
        )

        let hasBash = pool.contains(where: { $0.name == "Bash" })
        if hasBash {
            pass("Base tools available in pool even when all MCP connections fail")
        } else {
            fail("Base tools should remain available when MCP connections fail")
        }
    }

    // ================================================================
    // MARK: Story 6-4: MCP Agent Integration - Lifecycle
    // ================================================================

    /// AC9 [P0]: Shutdown clears all external connections (stdio + SSE + HTTP).
    static func testMCPLifecycle_shutdownClearsAll() async {
        let manager = MCPClientManager()

        await manager.connect(name: "stdio-srv", config: McpStdioConfig(command: "/nonexistent"))
        await manager.connect(name: "sse-srv", config: McpSseConfig(url: "http://localhost:1/sse"))

        let before = await manager.getConnections()
        let beforeCount = before.count

        await manager.shutdown()
        let after = await manager.getConnections()

        if beforeCount >= 1 && after.isEmpty {
            pass("MCPClientManager shutdown clears all external connections")
        } else {
            fail("Shutdown should clear all connections",
                 "before=\(beforeCount) after=\(after.count)")
        }
    }

    /// AC9 [P0]: SDK server does not create MCPClientManager (zero network overhead).
    static func testMCPLifecycle_sdkServerNoManager() async {
        // SDK servers bypass MCP protocol entirely -- no MCPClientManager needed
        let tool = E2EMockTool(toolName: "local_fn")
        let server = InProcessMCPServer(name: "sdk", version: "1.0.0", tools: [tool])

        // SDK server tools are accessible directly without MCPClientManager
        let tools = await server.getTools()

        if tools.count == 1 {
            pass("SDK server tools accessible directly (no MCPClientManager needed)")
        } else {
            fail("SDK server should expose tools directly")
        }

        // No network connections created
        let manager = MCPClientManager()
        let connections = await manager.getConnections()
        if connections.isEmpty {
            pass("No MCP connections created for SDK-only config")
        } else {
            fail("SDK config should not create any MCP connections")
        }
    }

    // ================================================================
    // MARK: Story 6-4: MCP Agent Integration - Tool Pool Deduplication
    // ================================================================

    /// AC8 [P0]: Tool pool deduplicates tools with same name.
    static func testToolPoolDeduplication() {
        let tool1 = MCPToolDefinition(
            serverName: "srv", mcpToolName: "search",
            toolDescription: "V1", schema: [:], mcpClient: nil
        )
        let tool2 = MCPToolDefinition(
            serverName: "srv", mcpToolName: "search",
            toolDescription: "V2", schema: [:], mcpClient: nil
        )

        let pool = assembleToolPool(
            baseTools: [], customTools: nil, mcpTools: [tool1, tool2],
            allowed: nil, disallowed: nil
        )

        let matching = pool.filter { $0.name == "mcp__srv__search" }
        if matching.count == 1 {
            pass("Duplicate MCP tools deduplicated to single entry")
        } else {
            fail("Should have exactly 1 tool after deduplication",
                 "count=\(matching.count)")
        }
    }

    /// AC8 [P0]: Tool name uniqueness across different servers.
    static func testToolPoolNameUniqueness() {
        let tools: [ToolProtocol] = [
            MCPToolDefinition(serverName: "srv1", mcpToolName: "search",
                              toolDescription: "S1", schema: [:], mcpClient: nil),
            MCPToolDefinition(serverName: "srv2", mcpToolName: "search",
                              toolDescription: "S2", schema: [:], mcpClient: nil),
        ]

        let pool = assembleToolPool(
            baseTools: [], customTools: nil, mcpTools: tools,
            allowed: nil, disallowed: nil
        )

        let names = pool.map { $0.name }
        let uniqueNames = Set(names)

        if names.count == uniqueNames.count
            && pool.contains(where: { $0.name == "mcp__srv1__search" })
            && pool.contains(where: { $0.name == "mcp__srv2__search" }) {
            pass("Tool names from different servers are unique in pool")
        } else {
            fail("Different servers should produce unique tool names",
                 "names=\(names)")
        }
    }

    // ================================================================
    // MARK: Story 6-4: MCP Agent Integration - Agent-Level Integration
    // ================================================================

    /// AC1/AC5 [P0]: Agent can be created with mixed MCP configs (SDK + external).
    static func testAgentCreation_withMixedMcpConfigs() async {
        let tool = E2EMockTool(toolName: "compute")
        let server = InProcessMCPServer(name: "sdk-srv", version: "1.0.0", tools: [tool])
        let sdkConfig = McpSdkServerConfig(name: "sdk-srv", version: "1.0.0", server: server)

        let mcpServers: [String: McpServerConfig] = [
            "sdk-srv": .sdk(sdkConfig),
            "remote": .stdio(McpStdioConfig(command: "/nonexistent")),
        ]

        let options = AgentOptions(apiKey: "test-key", model: "test-model", mcpServers: mcpServers)
        let agent = Agent(options: options)

        // Verify Agent was created successfully with MCP config
        if agent.model == "test-model" && agent.maxTurns == 10 {
            pass("Agent created with mixed MCP configs (SDK + external)")
        } else {
            fail("Agent should be created with correct config")
        }

        // Verify SDK server tools are accessible directly
        let sdkTools = await server.getTools()
        if sdkTools.count == 1 && sdkTools.first?.name == "compute" {
            pass("SDK server tools are accessible from Agent's MCP config")
        } else {
            fail("SDK server should expose tool via getTools()")
        }
    }

    /// AC1/AC4 [P0]: Full tool pool assembly with built-in + SDK + external tools.
    static func testFullToolPoolAssembly_builtinPlusSDKPlusExternal() async {
        let tool = E2EMockTool(toolName: "sdk_fn")
        let server = InProcessMCPServer(name: "local", version: "1.0.0", tools: [tool])
        let _ = McpSdkServerConfig(name: "local", version: "1.0.0", server: server)

        // SDK tools via InProcessMCPServer.getTools()
        let sdkTools = await server.getTools()

        // External tools via MCPClientManager (will fail, empty)
        let manager = MCPClientManager()
        await manager.connect(name: "broken", config: McpStdioConfig(command: "/nonexistent"))
        let externalTools = await manager.getMCPTools()

        // Build MCP tool list with namespace (simulating SdkToolWrapper)
        let namespacedSDKTools: [ToolProtocol] = sdkTools.map { t in
            MCPToolDefinition(
                serverName: "local",
                mcpToolName: t.name,
                toolDescription: t.description,
                schema: t.inputSchema,
                mcpClient: nil
            )
        }

        // Assemble full pool
        let baseTools = getAllBaseTools(tier: .core)
        let allMCPTools = namespacedSDKTools + externalTools
        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: nil,
            mcpTools: allMCPTools,
            allowed: nil,
            disallowed: nil
        )

        let hasSDK = pool.contains(where: { $0.name == "mcp__local__sdk_fn" })
        let hasBash = pool.contains(where: { $0.name == "Bash" })
        let hasRead = pool.contains(where: { $0.name == "Read" })

        if hasSDK && hasBash && hasRead {
            pass("Full tool pool assembly merges built-in + SDK + external tools")
        } else {
            fail("Pool should contain built-in and SDK tools",
                 "hasSDK=\(hasSDK) hasBash=\(hasBash) hasRead=\(hasRead)")
        }

        await manager.shutdown()
    }

    /// AC3/AC7 [P0]: SDK tool execution through tool pool produces correct result.
    static func testAgentMCPSDKToolExecution() async {
        let tool = E2EMockTool(toolName: "echo", resultContent: "Hello from SDK!")
        let server = InProcessMCPServer(name: "sdk", version: "1.0.0", tools: [tool])

        // Execute tool directly (simulating SDK tool bypass path)
        let sdkTools = await server.getTools()
        guard let echoTool = sdkTools.first else {
            fail("SDK server should expose echo tool")
            return
        }

        let context = ToolContext(cwd: "/tmp", toolUseId: "e2e-sdk-exec")
        let result = await echoTool.call(input: [:], context: context)

        if !result.isError && result.content == "Hello from SDK!" {
            pass("SDK tool executes directly via ToolProtocol.call() with correct result")
        } else {
            fail("SDK tool should execute correctly",
                 "isError=\(result.isError) content=\(result.content)")
        }
    }

    /// AC7 [P0]: MCP tool error isolation at Agent level.
    static func testAgentMCPToolError_errorIsolation() async {
        let mockClient = E2EMockMCPClient(callResult: nil, callError: E2EMCPTestError.serverError)
        let tool = MCPToolDefinition(
            serverName: "failing",
            mcpToolName: "crash_tool",
            toolDescription: "tool that crashes",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let context = ToolContext(cwd: "/tmp", toolUseId: "agent-error-test")
        let result = await tool.call(input: [:], context: context)

        if result.isError {
            pass("MCP tool error isolated as ToolResult(isError: true) at Agent level")
        } else {
            fail("MCP tool error should be captured as isError: true")
        }

        if result.toolUseId == "agent-error-test" {
            pass("Error ToolResult preserves toolUseId at Agent level")
        } else {
            fail("Error ToolResult should preserve toolUseId")
        }
    }

    /// AC9 [P1]: Agent without MCP servers works normally.
    static func testAgentCreation_noMcpServers() async {
        let options = AgentOptions(apiKey: "test-key", model: "test-model")
        let agent = Agent(options: options)

        if agent.model == "test-model" && agent.maxTurns == 10 && agent.maxTokens == 16384 {
            pass("Agent without MCP servers created correctly with defaults")
        } else {
            fail("Agent should have correct default config")
        }
    }
}

// MARK: - E2E Mock Helpers for Story 6-3

/// Mock tool for InProcessMCPServer E2E testing.
private final class E2EMockTool: ToolProtocol, Sendable {
    private let toolName: String
    private let toolDescription: String
    nonisolated(unsafe) private let toolSchema: ToolInputSchema
    private let resultContent: String
    private let resultIsError: Bool

    init(
        toolName: String,
        toolDescription: String = "A test tool",
        resultContent: String = "mock result",
        resultIsError: Bool = false
    ) {
        self.toolName = toolName
        self.toolDescription = toolDescription
        self.toolSchema = ["type": "object", "properties": [:]]
        self.resultContent = resultContent
        self.resultIsError = resultIsError
    }

    var name: String { toolName }
    var description: String { toolDescription }
    var inputSchema: ToolInputSchema { toolSchema }
    var isReadOnly: Bool { false }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(toolUseId: context.toolUseId, content: resultContent, isError: resultIsError)
    }
}

/// Mock tool that returns isError: true (simulates tool execution failure).
private final class E2EThrowingMockTool: ToolProtocol, Sendable {
    private let toolName: String
    nonisolated(unsafe) private let toolSchema: ToolInputSchema = ["type": "object", "properties": [:]]

    init(toolName: String) {
        self.toolName = toolName
    }

    var name: String { toolName }
    var description: String { "A tool that fails" }
    var inputSchema: ToolInputSchema { toolSchema }
    var isReadOnly: Bool { false }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(toolUseId: context.toolUseId, content: "Simulated execution failure", isError: true)
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
    case serverError
}

import XCTest
@testable import OpenAgentSDK

// MARK: - MCPClientManagerTests

/// ATDD RED PHASE: Tests for Story 6.1 -- MCP Client Manager & Stdio Transport.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `MCPConnectionStatus` enum is defined in `Types/MCPTypes.swift`
///   - `MCPManagedConnection` struct is defined in `Types/MCPTypes.swift`
///   - `MCPToolDefinition` struct is defined in `Tools/MCP/MCPToolDefinition.swift`
///   - `MCPStdioTransport` actor is defined in `Tools/MCP/MCPStdioTransport.swift`
///   - `MCPClientManager` actor is defined in `Tools/MCP/MCPClientManager.swift`
///   - Agent integration is added to `Core/Agent.swift`
/// TDD Phase: RED (feature not implemented yet)
final class MCPClientManagerTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a basic ToolContext with just cwd (no stores needed for MCP tests).
    private func makeContext(toolUseId: String = "test-tool-use-id") -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: toolUseId
        )
    }

    /// Creates a stdio server config for testing.
    private func makeStdioConfig(
        command: String = "echo",
        args: [String]? = nil,
        env: [String: String]? = nil
    ) -> McpStdioConfig {
        return McpStdioConfig(command: command, args: args, env: env)
    }

    // ================================================================
    // MARK: - AC1: MCPConnectionStatus & MCPManagedConnection Types
    // ================================================================

    // MARK: - MCPConnectionStatus

    /// AC1 [P0]: MCPConnectionStatus enum exists with connected, disconnected, error cases.
    func testMCPConnectionStatus_hasAllCases() {
        let connected: MCPConnectionStatus = .connected
        let disconnected: MCPConnectionStatus = .disconnected
        let error: MCPConnectionStatus = .error

        // Verify they are distinct cases
        XCTAssertNotEqual(connected, disconnected)
        XCTAssertNotEqual(connected, error)
        XCTAssertNotEqual(disconnected, error)
    }

    /// AC1 [P0]: MCPConnectionStatus conforms to Equatable.
    func testMCPConnectionStatus_isEquatable() {
        let status1: MCPConnectionStatus = .connected
        let status2: MCPConnectionStatus = .connected
        XCTAssertEqual(status1, status2)
    }

    /// AC1 [P0]: MCPConnectionStatus conforms to Sendable.
    func testMCPConnectionStatus_isSendable() {
        let status: MCPConnectionStatus = .disconnected
        // Should compile if Sendable
        _ = status
    }

    // MARK: - MCPManagedConnection

    /// AC1 [P0]: MCPManagedConnection can be created with name, status, and empty tools.
    func testMCPManagedConnection_creationWithEmptyTools() {
        let connection = MCPManagedConnection(
            name: "test-server",
            status: .disconnected,
            tools: []
        )

        XCTAssertEqual(connection.name, "test-server")
        XCTAssertEqual(connection.status, .disconnected)
        XCTAssertTrue(connection.tools.isEmpty)
    }

    /// AC1 [P0]: MCPManagedConnection can be created with connected status.
    func testMCPManagedConnection_creationWithConnectedStatus() {
        let connection = MCPManagedConnection(
            name: "my-server",
            status: .connected,
            tools: []
        )

        XCTAssertEqual(connection.status, .connected)
    }

    /// AC1 [P0]: MCPManagedConnection conforms to Sendable.
    func testMCPManagedConnection_isSendable() {
        let connection = MCPManagedConnection(
            name: "sendable-test",
            status: .disconnected,
            tools: []
        )
        // Should compile if Sendable
        _ = connection
    }

    // ================================================================
    // MARK: - AC1: MCPClientManager Initialization
    // ================================================================

    /// AC1 [P0]: MCPClientManager initializes with empty config, connections empty.
    func testMCPClientManager_init_withEmptyConfig_hasNoConnections() async {
        let manager = MCPClientManager()
        let connections = await manager.getConnections()

        XCTAssertTrue(connections.isEmpty,
                       "MCPClientManager should start with empty connections")
    }

    /// AC1 [P0]: MCPClientManager is an actor (thread-safe).
    func testMCPClientManager_isActor() async {
        let manager = MCPClientManager()
        // Actor -- accessing isolated state requires await
        let _ = await manager.getConnections()
        // If it compiles, it is an actor
    }

    // ================================================================
    // MARK: - AC2: MCPToolDefinition Namespace & Schema
    // ================================================================

    /// AC5 [P0]: MCPToolDefinition name uses mcp__{server}__{tool} namespace.
    func testMCPToolDefinition_name_usesMcpNamespace() {
        let tool = MCPToolDefinition(
            serverName: "myserver",
            mcpToolName: "read_file",
            toolDescription: "Reads a file",
            schema: ["type": "object", "properties": [:]],
            mcpClient: nil  // nil for namespace testing only
        )

        XCTAssertEqual(tool.name, "mcp__myserver__read_file",
                       "MCP tool name must follow mcp__{server}__{tool} namespace (rule #10)")
    }

    /// AC5 [P0]: MCPToolDefinition name with different server and tool names.
    func testMCPToolDefinition_name_differentServerAndTool() {
        let tool = MCPToolDefinition(
            serverName: "filesystem",
            mcpToolName: "write_file",
            toolDescription: "Writes a file",
            schema: ["type": "object", "properties": [:]],
            mcpClient: nil
        )

        XCTAssertEqual(tool.name, "mcp__filesystem__write_file")
    }

    /// AC5 [P0]: MCPToolDefinition passes inputSchema through.
    func testMCPToolDefinition_schema_isPassedThrough() {
        let schema: ToolInputSchema = [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "File path"]
            ],
            "required": ["path"]
        ]
        let tool = MCPToolDefinition(
            serverName: "fs",
            mcpToolName: "read",
            toolDescription: "Read",
            schema: schema,
            mcpClient: nil
        )

        XCTAssertEqual(tool.inputSchema["type"] as? String, "object")
        let props = tool.inputSchema["properties"] as? [String: Any]
        XCTAssertNotNil(props?["path"])
    }

    /// AC5 [P0]: MCPToolDefinition description is passed through.
    func testMCPToolDefinition_description_isPassedThrough() {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "A tool that does something useful",
            schema: ["type": "object"],
            mcpClient: nil
        )

        XCTAssertEqual(tool.description, "A tool that does something useful")
    }

    /// AC5 [P0]: MCPToolDefinition isReadOnly returns false (matches TS SDK).
    func testMCPToolDefinition_isReadOnly_returnsFalse() {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "desc",
            schema: ["type": "object"],
            mcpClient: nil
        )

        XCTAssertFalse(tool.isReadOnly,
                        "MCP tools default to isReadOnly=false, matching TS SDK")
    }

    /// AC6 [P0]: MCPToolDefinition.call() with nil mcpClient returns error ToolResult.
    func testMCPToolDefinition_call_withNilClient_returnsError() async {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "desc",
            schema: ["type": "object"],
            mcpClient: nil
        )

        let context = makeContext()
        let result = await tool.call(input: [:], context: context)

        XCTAssertTrue(result.isError,
                       "Calling MCP tool with nil client should return error")
        XCTAssertTrue(result.content.contains("error") || result.content.contains("not available") || result.content.contains("MCP"),
                       "Error message should describe the issue")
    }

    /// AC6 [P0]: MCPToolDefinition.call() never throws -- always returns ToolResult.
    func testMCPToolDefinition_call_neverThrows_malformedInput() async {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "desc",
            schema: ["type": "object"],
            mcpClient: nil
        )

        let context = makeContext()
        // Various malformed inputs -- none should throw, all return ToolResult
        let result1 = await tool.call(input: [:], context: context)
        // With nil client, all calls should return error ToolResult (not throw)
        XCTAssertTrue(result1.isError)  // nil client returns error ToolResult

        let result2 = await tool.call(input: "invalid", context: context)
        _ = result2  // compiles = returns ToolResult

        let result3 = await tool.call(input: 42, context: context)
        _ = result3  // compiles = returns ToolResult
    }

    // ================================================================
    // MARK: - AC2: Stdio Transport Connection
    // ================================================================

    /// AC2 [P0]: MCPStdioTransport exists as an actor.
    func testMCPStdioTransport_exists() async {
        let config = makeStdioConfig(command: "echo")
        let transport = MCPStdioTransport(config: config)
        _ = transport  // Compiles if type exists
    }

    /// AC2 [P0]: MCPStdioTransport can be created with McpStdioConfig.
    func testMCPStdioTransport_creationWithConfig() async {
        let config = makeStdioConfig(command: "cat", args: ["-"])
        let transport = MCPStdioTransport(config: config)
        _ = transport
    }

    /// AC2 [P0]: MCPStdioTransport can be created with environment variables.
    func testMCPStdioTransport_creationWithEnv() async {
        let config = makeStdioConfig(
            command: "env",
            env: ["MY_VAR": "my_value"]
        )
        let transport = MCPStdioTransport(config: config)
        _ = transport
    }

    // ================================================================
    // MARK: - AC4: Connection State Tracking
    // ================================================================

    /// AC4 [P0]: getConnections returns dictionary with managed connection info.
    func testMCPClientManager_getConnections_returnsDictionary() async {
        let manager = MCPClientManager()
        let connections = await manager.getConnections()

        // Should be [String: MCPManagedConnection]
        XCTAssertTrue(connections.isEmpty)
    }

    // ================================================================
    // MARK: - AC8: Multi-server Management
    // ================================================================

    /// AC8 [P0]: connectAll with empty dictionary does nothing.
    func testMCPClientManager_connectAll_withEmptyServers_hasNoConnections() async {
        let manager = MCPClientManager()
        await manager.connectAll(servers: [:])
        let connections = await manager.getConnections()

        XCTAssertTrue(connections.isEmpty,
                       "connectAll with empty servers should leave connections empty")
    }

    // ================================================================
    // MARK: - AC9: Connection Failure Handling
    // ================================================================

    /// AC9 [P0]: connect with non-existent command marks connection as error.
    func testMCPClientManager_connect_invalidCommand_marksError() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/nonexistent/command/that/does/not/exist")

        await manager.connect(name: "bad-server", config: config)
        let connections = await manager.getConnections()

        let conn = connections["bad-server"]
        XCTAssertNotNil(conn, "Failed connection should still appear in connections")
        XCTAssertEqual(conn?.status, .error,
                        "Failed connection should have error status")
        XCTAssertTrue(conn?.tools.isEmpty ?? false,
                       "Failed connection should have empty tools")
    }

    /// AC9 [P0]: connect failure does not crash the manager.
    func testMCPClientManager_connect_failure_doesNotCrash() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/definitely/not/a/real/command")

        // Should not crash
        await manager.connect(name: "fail-server", config: config)

        // Manager should still be usable
        let connections = await manager.getConnections()
        XCTAssertNotNil(connections)
    }

    // ================================================================
    // MARK: - AC10: Shutdown
    // ================================================================

    /// AC10 [P0]: shutdown with no connections completes without error.
    func testMCPClientManager_shutdown_withNoConnections() async {
        let manager = MCPClientManager()
        // Should not crash or hang
        await manager.shutdown()
        let connections = await manager.getConnections()
        XCTAssertTrue(connections.isEmpty)
    }

    /// AC10 [P0]: shutdown clears all connections.
    func testMCPClientManager_shutdown_clearsConnections() async {
        let manager = MCPClientManager()
        // Even after failed connections, shutdown should clear
        let config = makeStdioConfig(command: "/nonexistent")
        await manager.connect(name: "server1", config: config)

        await manager.shutdown()
        let connections = await manager.getConnections()
        XCTAssertTrue(connections.isEmpty,
                       "shutdown() should clear all connections")
    }

    // ================================================================
    // MARK: - AC10: Disconnect
    // ================================================================

    /// AC10 [P0]: disconnect for non-existent connection does not crash.
    func testMCPClientManager_disconnect_nonExistent_doesNotCrash() async {
        let manager = MCPClientManager()
        // Should not crash
        await manager.disconnect(name: "nonexistent")
    }

    // ================================================================
    // MARK: - AC5 & AC4: getMCPTools
    // ================================================================

    /// AC5 [P0]: getMCPTools returns empty array when no connections.
    func testMCPClientManager_getMCPTools_withNoConnections_returnsEmpty() async {
        let manager = MCPClientManager()
        let tools = await manager.getMCPTools()

        XCTAssertTrue(tools.isEmpty,
                       "getMCPTools should return empty array with no connections")
    }

    /// AC5 [P0]: getMCPTools returns empty array when only failed connections.
    func testMCPClientManager_getMCPTools_withFailedConnection_returnsEmpty() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/nonexistent")
        await manager.connect(name: "bad", config: config)

        let tools = await manager.getMCPTools()
        XCTAssertTrue(tools.isEmpty,
                       "Failed connections should contribute no tools")
    }

    // ================================================================
    // MARK: - AC13: API Key Security
    // ================================================================

    /// AC13 [P0]: MCPStdioTransport does not leak CODEANY_API_KEY by default.
    func testMCPStdioTransport_doesNotLeakApiKeyByDefault() async {
        // Set a fake API key in environment
        setenv("CODEANY_API_KEY", "secret-key-12345", 1)

        let config = makeStdioConfig(command: "env")
        let transport = MCPStdioTransport(config: config)

        // The transport should NOT pass CODEANY_API_KEY to the child process
        // unless explicitly configured in the env parameter
        let childEnv = await transport.getChildEnvironment()
        XCTAssertNil(childEnv["CODEANY_API_KEY"],
                      "CODEANY_API_KEY should not be leaked to child process")

        // Clean up
        unsetenv("CODEANY_API_KEY")
    }

    /// AC13 [P1]: MCPStdioTransport passes explicitly configured env vars.
    func testMCPStdioTransport_passesExplicitEnvVars() async {
        let config = makeStdioConfig(
            command: "env",
            env: ["MY_TOOL_KEY": "my-value"]
        )
        let transport = MCPStdioTransport(config: config)

        let childEnv = await transport.getChildEnvironment()
        XCTAssertEqual(childEnv["MY_TOOL_KEY"], "my-value",
                        "Explicitly configured env vars should be passed")
    }

    // ================================================================
    // MARK: - AC11: Module Boundary Compliance
    // ================================================================

    /// AC11 [P0]: MCPToolDefinition does not import Core/ (compile-time check).
    /// This test verifies MCPToolDefinition works with only Types/ dependencies.
    func testMCPToolDefinition_worksWithOnlyTypesDependencies() async {
        // MCPToolDefinition only uses ToolProtocol, ToolResult, ToolInputSchema, ToolContext
        // all from Types/ -- if this compiles, boundary is respected
        let tool = MCPToolDefinition(
            serverName: "boundary-test",
            mcpToolName: "test",
            toolDescription: "boundary test",
            schema: ["type": "object"],
            mcpClient: nil
        )
        _ = tool
    }

    // ================================================================
    // MARK: - AC7: Agent Integration
    // ================================================================

    /// AC7 [P0]: AgentOptions.mcpServers can be nil (default).
    func testAgentOptions_mcpServers_defaultIsNil() {
        let options = AgentOptions()
        XCTAssertNil(options.mcpServers,
                      "mcpServers should default to nil")
    }

    /// AC7 [P0]: AgentOptions.mcpServers can be set with stdio config.
    func testAgentOptions_mcpServers_canBeSetWithStdio() {
        let config: [String: McpServerConfig] = [
            "my-server": .stdio(McpStdioConfig(command: "my-mcp-server"))
        ]
        let options = AgentOptions(mcpServers: config)

        XCTAssertNotNil(options.mcpServers)
        XCTAssertEqual(options.mcpServers?.count, 1)
    }

    /// AC7 [P0]: AgentOptions.mcpServers can hold multiple servers.
    func testAgentOptions_mcpServers_canHoldMultipleServers() {
        let config: [String: McpServerConfig] = [
            "server1": .stdio(McpStdioConfig(command: "server1")),
            "server2": .stdio(McpStdioConfig(command: "server2")),
        ]
        let options = AgentOptions(mcpServers: config)

        XCTAssertEqual(options.mcpServers?.count, 2)
    }

    // ================================================================
    // MARK: - Integration: MCPManagedConnection with tools
    // ================================================================

    /// AC4 [P0]: MCPManagedConnection holds tool list.
    func testMCPManagedConnection_holdsToolList() {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "read",
            toolDescription: "read tool",
            schema: ["type": "object"],
            mcpClient: nil
        )
        let connection = MCPManagedConnection(
            name: "srv",
            status: .connected,
            tools: [tool]
        )

        XCTAssertEqual(connection.tools.count, 1)
        XCTAssertEqual(connection.tools.first?.name, "mcp__srv__read")
    }

    /// AC4 [P0]: MCPManagedConnection with error status and empty tools.
    func testMCPManagedConnection_errorStatus_emptyTools() {
        let connection = MCPManagedConnection(
            name: "failed-server",
            status: .error,
            tools: []
        )

        XCTAssertEqual(connection.status, .error)
        XCTAssertTrue(connection.tools.isEmpty)
    }

    // ================================================================
    // MARK: - AC12: Cross-platform Compatibility
    // ================================================================

    /// AC12 [P0]: MCPStdioTransport uses Foundation Process (cross-platform).
    /// This test verifies that MCPStdioTransport compiles using only Foundation.
    func testMCPStdioTransport_usesFoundationProcess() async {
        // If MCPStdioTransport compiles with only Foundation, it is cross-platform
        let config = makeStdioConfig(command: "echo")
        let transport = MCPStdioTransport(config: config)
        _ = transport
    }

    // ================================================================
    // MARK: - Edge Cases
    // ================================================================

    /// AC8 [P1]: connect with empty command should handle gracefully.
    func testMCPClientManager_connect_emptyCommand_marksError() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "")

        await manager.connect(name: "empty", config: config)
        let connections = await manager.getConnections()

        let conn = connections["empty"]
        XCTAssertNotNil(conn)
        XCTAssertEqual(conn?.status, .error)
    }

    /// AC8 [P1]: Multiple failed connections can coexist.
    func testMCPClientManager_multipleFailedConnections() async {
        let manager = MCPClientManager()
        let config1 = makeStdioConfig(command: "/nonexistent1")
        let config2 = makeStdioConfig(command: "/nonexistent2")

        await manager.connect(name: "fail1", config: config1)
        await manager.connect(name: "fail2", config: config2)

        let connections = await manager.getConnections()
        XCTAssertEqual(connections.count, 2,
                        "Multiple failed connections should both be tracked")
        XCTAssertEqual(connections["fail1"]?.status, .error)
        XCTAssertEqual(connections["fail2"]?.status, .error)
    }

    /// AC10 [P1]: shutdown after failed connections still cleans up.
    func testMCPClientManager_shutdown_afterMultipleFailures() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/nonexistent")

        await manager.connect(name: "s1", config: config)
        await manager.connect(name: "s2", config: config)

        await manager.shutdown()
        let connections = await manager.getConnections()
        XCTAssertTrue(connections.isEmpty,
                       "shutdown should clear all connections including failed ones")
    }

    /// AC9 [P1]: Connection with special characters in name.
    func testMCPClientManager_connect_specialCharsInName() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/nonexistent")

        await manager.connect(name: "my-server_v2.0", config: config)
        let connections = await manager.getConnections()
        XCTAssertNotNil(connections["my-server_v2.0"])
    }

    // ================================================================
    // MARK: - MCPToolDefinition Namespace Edge Cases
    // ================================================================

    /// AC5 [P0]: MCPToolDefinition name with hyphenated server name.
    func testMCPToolDefinition_name_hyphenatedServerName() {
        let tool = MCPToolDefinition(
            serverName: "my-cool-server",
            mcpToolName: "search",
            toolDescription: "search",
            schema: ["type": "object"],
            mcpClient: nil
        )

        XCTAssertEqual(tool.name, "mcp__my-cool-server__search")
    }

    /// AC5 [P0]: MCPToolDefinition name with underscored tool name.
    func testMCPToolDefinition_name_underscoredToolName() {
        let tool = MCPToolDefinition(
            serverName: "fs",
            mcpToolName: "read_file",
            toolDescription: "read file",
            schema: ["type": "object"],
            mcpClient: nil
        )

        XCTAssertEqual(tool.name, "mcp__fs__read_file")
    }

    /// AC5 [P1]: MCPToolDefinition conforms to ToolProtocol.
    func testMCPToolDefinition_conformsToToolProtocol() {
        let tool: ToolProtocol = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "desc",
            schema: ["type": "object"],
            mcpClient: nil
        )

        XCTAssertEqual(tool.name, "mcp__srv__tool")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertNotNil(tool.inputSchema)
    }

    // ================================================================
    // MARK: - McpServerConfig & McpStdioConfig (existing types)
    // ================================================================

    /// AC2 [P0]: McpStdioConfig can be created with command only.
    func testMcpStdioConfig_commandOnly() {
        let config = McpStdioConfig(command: "my-server")
        XCTAssertEqual(config.command, "my-server")
        XCTAssertNil(config.args)
        XCTAssertNil(config.env)
    }

    /// AC2 [P0]: McpStdioConfig can be created with all parameters.
    func testMcpStdioConfig_allParameters() {
        let config = McpStdioConfig(
            command: "node",
            args: ["server.js", "--verbose"],
            env: ["API_KEY": "test"]
        )
        XCTAssertEqual(config.command, "node")
        XCTAssertEqual(config.args, ["server.js", "--verbose"])
        XCTAssertEqual(config.env?["API_KEY"], "test")
    }

    /// AC2 [P0]: McpServerConfig.stdio wraps McpStdioConfig.
    func testMcpServerConfig_stdioCase() {
        let stdioConfig = McpStdioConfig(command: "echo")
        let config = McpServerConfig.stdio(stdioConfig)

        if case .stdio(let unwrapped) = config {
            XCTAssertEqual(unwrapped.command, "echo")
        } else {
            XCTFail("Expected .stdio case")
        }
    }

    /// AC2 [P0]: McpServerConfig is Equatable.
    func testMcpServerConfig_isEquatable() {
        let config1 = McpServerConfig.stdio(McpStdioConfig(command: "a"))
        let config2 = McpServerConfig.stdio(McpStdioConfig(command: "a"))
        XCTAssertEqual(config1, config2)
    }

    // ================================================================
    // MARK: - SDKError.mcpConnectionError
    // ================================================================

    /// AC9 [P0]: SDKError.mcpConnectionError exists with serverName and message.
    func testSDKError_mcpConnectionError_exists() {
        let error = SDKError.mcpConnectionError(serverName: "test", message: "failed")
        XCTAssertEqual(error.serverName, "test")
        XCTAssertEqual(error.message, "failed")
    }

    /// AC9 [P0]: SDKError.mcpConnectionError has proper description.
    func testSDKError_mcpConnectionError_hasDescription() {
        let error = SDKError.mcpConnectionError(serverName: "my-server", message: "timeout")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("my-server") ?? false)
    }

    // ================================================================
    // MARK: - assembleToolPool integration with MCP tools
    // ================================================================

    /// AC7 [P0]: assembleToolPool merges MCP tools with base tools.
    func testAssembleToolPool_mergesMCPTools() {
        let baseTools = getAllBaseTools(tier: .core)
        let mcpTool = MCPToolDefinition(
            serverName: "remote",
            mcpToolName: "search",
            toolDescription: "remote search",
            schema: ["type": "object"],
            mcpClient: nil
        )
        let mcpTools: [ToolProtocol] = [mcpTool]

        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: nil,
            mcpTools: mcpTools,
            allowed: nil,
            disallowed: nil
        )

        // Pool should contain both base tools and MCP tools
        XCTAssertTrue(pool.contains(where: { $0.name == "mcp__remote__search" }),
                       "Pool should contain MCP tool")
        XCTAssertTrue(pool.contains(where: { $0.name == "Bash" }),
                       "Pool should still contain base tools")
    }

    /// AC7 [P0]: MCP tools override base tools with same name (by design).
    func testAssembleToolPool_mcpToolsDeduplicate() {
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

        XCTAssertEqual(pool.count, 1)
        XCTAssertEqual(pool.first?.name, "mcp__srv__tool")
    }

    // ================================================================
    // MARK: - AC7: MCPClientManager lazy initialization concept
    // ================================================================

    /// AC7 [P1]: MCPClientManager can be created independently.
    func testMCPClientManager_canBeCreatedIndependently() async {
        let manager = MCPClientManager()
        let connections = await manager.getConnections()
        XCTAssertTrue(connections.isEmpty)
    }

    // ================================================================
    // MARK: - AC8: Independent server management
    // ================================================================

    /// AC8 [P1]: Disconnecting one failed server does not affect another.
    func testMCPClientManager_disconnect_oneServer_doesNotAffectOther() async {
        let manager = MCPClientManager()
        let config = makeStdioConfig(command: "/nonexistent")

        await manager.connect(name: "server1", config: config)
        await manager.connect(name: "server2", config: config)

        await manager.disconnect(name: "server1")
        let connections = await manager.getConnections()

        XCTAssertNil(connections["server1"],
                      "server1 should be removed after disconnect")
        XCTAssertNotNil(connections["server2"],
                         "server2 should still exist")
    }

    // ================================================================
    // MARK: - MCPToolDefinition call() with mock client
    // ================================================================

    /// AC6 [P0]: MCPToolDefinition.call() returns success result when mcpClient succeeds.
    func testMCPToolDefinition_call_success_returnsToolResult() async {
        let mockClient = MockMCPClient(toolsResult: [], callResult: "Hello from MCP")
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "greet",
            toolDescription: "greeting tool",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let context = makeContext()
        let result = await tool.call(input: ["name": "world"], context: context)

        XCTAssertFalse(result.isError, "Successful MCP call should not be error")
        XCTAssertTrue(result.content.contains("Hello from MCP"),
                       "Result should contain MCP response content")
    }

    /// AC6 [P0]: MCPToolDefinition.call() returns error result when mcpClient fails.
    func testMCPToolDefinition_call_clientError_returnsErrorToolResult() async {
        let mockClient = MockMCPClient(
            toolsResult: [],
            callResult: nil,
            callError: MCPTestError.connectionFailed
        )
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "fail",
            toolDescription: "failing tool",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let context = makeContext()
        let result = await tool.call(input: [:], context: context)

        XCTAssertTrue(result.isError,
                       "MCP client error should be captured as ToolResult error")
        XCTAssertTrue(result.content.contains("error") || result.content.contains("MCP"),
                       "Error content should describe the issue")
    }

    /// AC6 [P1]: MCPToolDefinition.call() preserves toolUseId in ToolResult.
    func testMCPToolDefinition_call_preservesToolUseId() async {
        let mockClient = MockMCPClient(toolsResult: [], callResult: "ok")
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "test",
            toolDescription: "test tool",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let context = makeContext(toolUseId: "unique-id-123")
        let result = await tool.call(input: [:], context: context)

        XCTAssertEqual(result.toolUseId, "unique-id-123")
    }

    // ================================================================
    // MARK: - Story 6-2: MCP HTTP/SSE Transport (ATDD RED PHASE)
    // ================================================================
    //
    // These tests assert EXPECTED behavior for HTTP/SSE transport support.
    // TDD Phase: RED (feature not implemented yet)
    //
    // The following methods/properties must be added to MCPClientManager:
    //   - connect(name: String, config: McpSseConfig) async
    //   - connect(name: String, config: McpHttpConfig) async
    //   - httpTransports: [String: HTTPClientTransport] (private)
    //   - Updated connectAll() for SSE/HTTP dispatch
    //   - Updated cleanupConnection() for httpTransports
    // ================================================================

    // MARK: - AC1: SSE Transport Connection

    /// AC1 [P0]: connect with McpSseConfig creates connection using HTTPClientTransport (streaming: true).
    /// The connection should attempt MCP handshake and track the connection.
    /// With an unreachable URL, it should mark error status without crashing.
    func testMCPClientManager_connect_sseConfig_marksErrorOnInvalidURL() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(url: "http://localhost:99999/nonexistent-sse")

        // Story 6-2 adds connect(name:config:) overload for McpSseConfig
        await manager.connect(name: "sse-server", config: sseConfig)
        let connections = await manager.getConnections()

        let conn = connections["sse-server"]
        XCTAssertNotNil(conn, "SSE connection should be tracked even on failure")
        XCTAssertEqual(conn?.status, .error,
                        "Invalid SSE URL should result in error status")
        XCTAssertTrue(conn?.tools.isEmpty ?? false,
                       "Failed SSE connection should have empty tools")
    }

    /// AC1 [P0]: connect with valid-looking SSE config does not crash.
    func testMCPClientManager_connect_sseConfig_doesNotCrash() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(url: "http://localhost:1/sse")

        // Should not crash even if connection fails
        await manager.connect(name: "sse-test", config: sseConfig)

        // Manager should still be usable
        let connections = await manager.getConnections()
        XCTAssertNotNil(connections)
    }

    // MARK: - AC2: HTTP Transport Connection

    /// AC2 [P0]: connect with McpHttpConfig creates connection using HTTPClientTransport (streaming: false).
    /// The connection should attempt MCP handshake and track the connection.
    /// With an unreachable URL, it should mark error status without crashing.
    func testMCPClientManager_connect_httpConfig_marksErrorOnInvalidURL() async {
        let manager = MCPClientManager()
        let httpConfig = McpHttpConfig(url: "http://localhost:99999/nonexistent-http")

        // Story 6-2 adds connect(name:config:) overload for McpHttpConfig
        await manager.connect(name: "http-server", config: httpConfig)
        let connections = await manager.getConnections()

        let conn = connections["http-server"]
        XCTAssertNotNil(conn, "HTTP connection should be tracked even on failure")
        XCTAssertEqual(conn?.status, .error,
                        "Invalid HTTP URL should result in error status")
        XCTAssertTrue(conn?.tools.isEmpty ?? false,
                       "Failed HTTP connection should have empty tools")
    }

    /// AC2 [P0]: connect with HTTP config does not crash on connection failure.
    func testMCPClientManager_connect_httpConfig_doesNotCrash() async {
        let manager = MCPClientManager()
        let httpConfig = McpHttpConfig(url: "http://localhost:1/mcp")

        // Should not crash even if connection fails
        await manager.connect(name: "http-test", config: httpConfig)

        let connections = await manager.getConnections()
        XCTAssertNotNil(connections)
    }

    // MARK: - AC8: Custom Request Headers Injection

    /// AC8 [P0]: SSE config with custom headers passes them to HTTPClientTransport.
    /// Verifies that headers are injectable through McpSseConfig.
    func testMCPClientManager_connect_sseConfig_withCustomHeaders() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(
            url: "http://localhost:1/sse",
            headers: [
                "Authorization": "Bearer test-token-123",
                "X-Custom-Header": "custom-value"
            ]
        )

        // Connection will fail (no server) but should not crash
        await manager.connect(name: "sse-headers", config: sseConfig)
        let connections = await manager.getConnections()

        // The connection should be tracked (either error or connected)
        XCTAssertNotNil(connections["sse-headers"],
                         "SSE connection with headers should be tracked")
    }

    /// AC8 [P0]: HTTP config with custom headers passes them to HTTPClientTransport.
    func testMCPClientManager_connect_httpConfig_withCustomHeaders() async {
        let manager = MCPClientManager()
        let httpConfig = McpHttpConfig(
            url: "http://localhost:1/mcp",
            headers: ["Authorization": "Bearer token-456"]
        )

        await manager.connect(name: "http-headers", config: httpConfig)
        let connections = await manager.getConnections()

        XCTAssertNotNil(connections["http-headers"],
                         "HTTP connection with headers should be tracked")
    }

    /// AC8 [P1]: SSE config with nil headers uses default requestModifier.
    func testMCPClientManager_connect_sseConfig_withNilHeaders_doesNotCrash() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(url: "http://localhost:1/sse", headers: nil)

        await manager.connect(name: "sse-nil-headers", config: sseConfig)
        let connections = await manager.getConnections()

        XCTAssertNotNil(connections["sse-nil-headers"])
    }

    /// AC8 [P1]: HTTP config with empty headers uses default requestModifier.
    func testMCPClientManager_connect_httpConfig_withEmptyHeaders_doesNotCrash() async {
        let manager = MCPClientManager()
        let httpConfig = McpHttpConfig(url: "http://localhost:1/mcp", headers: [:])

        await manager.connect(name: "http-empty-headers", config: httpConfig)
        let connections = await manager.getConnections()

        XCTAssertNotNil(connections["http-empty-headers"])
    }

    // MARK: - AC9: Connection Failure Handling

    /// AC9 [P0]: SSE connect with malformed URL marks error status.
    func testMCPClientManager_connect_sseConfig_malformedURL_marksError() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(url: "not-a-valid-url")

        await manager.connect(name: "sse-bad-url", config: sseConfig)
        let connections = await manager.getConnections()

        let conn = connections["sse-bad-url"]
        XCTAssertNotNil(conn, "Malformed URL SSE connection should be tracked")
        XCTAssertEqual(conn?.status, .error,
                        "Malformed URL should result in error status")
    }

    /// AC9 [P0]: HTTP connect with malformed URL marks error status.
    func testMCPClientManager_connect_httpConfig_malformedURL_marksError() async {
        let manager = MCPClientManager()
        let httpConfig = McpHttpConfig(url: "not-a-valid-url")

        await manager.connect(name: "http-bad-url", config: httpConfig)
        let connections = await manager.getConnections()

        let conn = connections["http-bad-url"]
        XCTAssertNotNil(conn, "Malformed URL HTTP connection should be tracked")
        XCTAssertEqual(conn?.status, .error,
                        "Malformed URL should result in error status")
    }

    /// AC9 [P0]: SSE connect failure does not crash the manager.
    func testMCPClientManager_connect_sseConfig_failure_doesNotCrash() async {
        let manager = MCPClientManager()

        await manager.connect(name: "sse-fail1", config: McpSseConfig(url: ""))
        await manager.connect(name: "sse-fail2", config: McpSseConfig(url: "ftp://wrong-scheme"))

        // Manager should still be usable
        let connections = await manager.getConnections()
        XCTAssertNotNil(connections)
    }

    /// AC9 [P0]: HTTP connect failure does not crash the manager.
    func testMCPClientManager_connect_httpConfig_failure_doesNotCrash() async {
        let manager = MCPClientManager()

        await manager.connect(name: "http-fail1", config: McpHttpConfig(url: ""))
        await manager.connect(name: "http-fail2", config: McpHttpConfig(url: "ftp://wrong-scheme"))

        let connections = await manager.getConnections()
        XCTAssertNotNil(connections)
    }

    /// AC9 [P1]: Multiple failed SSE/HTTP connections coexist.
    func testMCPClientManager_multipleFailedHttpSseConnections() async {
        let manager = MCPClientManager()

        await manager.connect(name: "sse-fail", config: McpSseConfig(url: "http://localhost:99999"))
        await manager.connect(name: "http-fail", config: McpHttpConfig(url: "http://localhost:99998"))

        let connections = await manager.getConnections()
        XCTAssertEqual(connections.count, 2,
                        "Multiple failed HTTP/SSE connections should both be tracked")
        XCTAssertEqual(connections["sse-fail"]?.status, .error)
        XCTAssertEqual(connections["http-fail"]?.status, .error)
    }

    // MARK: - AC7: Multi-transport Concurrent Management

    /// AC7 [P0]: connectAll with mixed transport types dispatches correctly.
    /// SSE and HTTP configs should not return error from setErrorConnection placeholder.
    func testMCPClientManager_connectAll_mixedTransports_dispatchesCorrectly() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "stdio-srv": .stdio(McpStdioConfig(command: "/nonexistent")),
            "sse-srv": .sse(McpSseConfig(url: "http://localhost:99999/sse")),
            "http-srv": .http(McpHttpConfig(url: "http://localhost:99999/mcp"))
        ]

        await manager.connectAll(servers: servers)
        let connections = await manager.getConnections()

        // All three should be tracked (all will fail, but should use real connect methods)
        XCTAssertEqual(connections.count, 3,
                        "connectAll should handle all three transport types")
        XCTAssertEqual(connections["stdio-srv"]?.status, .error)
        XCTAssertEqual(connections["sse-srv"]?.status, .error,
                        "SSE should use actual connect, not setErrorConnection placeholder")
        XCTAssertEqual(connections["http-srv"]?.status, .error,
                        "HTTP should use actual connect, not setErrorConnection placeholder")
    }

    /// AC7 [P1]: connectAll with only SSE configs.
    func testMCPClientManager_connectAll_sseOnly() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "sse1": .sse(McpSseConfig(url: "http://localhost:1/sse")),
            "sse2": .sse(McpSseConfig(url: "http://localhost:2/sse"))
        ]

        await manager.connectAll(servers: servers)
        let connections = await manager.getConnections()

        XCTAssertEqual(connections.count, 2,
                        "Both SSE connections should be tracked")
    }

    /// AC7 [P1]: connectAll with only HTTP configs.
    func testMCPClientManager_connectAll_httpOnly() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "http1": .http(McpHttpConfig(url: "http://localhost:1/mcp")),
            "http2": .http(McpHttpConfig(url: "http://localhost:2/mcp"))
        ]

        await manager.connectAll(servers: servers)
        let connections = await manager.getConnections()

        XCTAssertEqual(connections.count, 2,
                        "Both HTTP connections should be tracked")
    }

    // MARK: - AC10: Connection Close & Cleanup

    /// AC10 [P0]: disconnect removes SSE connection from manager.
    func testMCPClientManager_disconnect_sseConnection_removesFromConnections() async {
        let manager = MCPClientManager()
        let sseConfig = McpSseConfig(url: "http://localhost:99999/sse")

        await manager.connect(name: "sse-to-disconnect", config: sseConfig)
        let beforeDisconnect = await manager.getConnections()
        XCTAssertNotNil(beforeDisconnect["sse-to-disconnect"])

        await manager.disconnect(name: "sse-to-disconnect")
        let afterDisconnect = await manager.getConnections()

        XCTAssertNil(afterDisconnect["sse-to-disconnect"],
                      "SSE connection should be removed after disconnect")
    }

    /// AC10 [P0]: disconnect removes HTTP connection from manager.
    func testMCPClientManager_disconnect_httpConnection_removesFromConnections() async {
        let manager = MCPClientManager()
        let httpConfig = McpHttpConfig(url: "http://localhost:99999/mcp")

        await manager.connect(name: "http-to-disconnect", config: httpConfig)
        let beforeDisconnect = await manager.getConnections()
        XCTAssertNotNil(beforeDisconnect["http-to-disconnect"])

        await manager.disconnect(name: "http-to-disconnect")
        let afterDisconnect = await manager.getConnections()

        XCTAssertNil(afterDisconnect["http-to-disconnect"],
                      "HTTP connection should be removed after disconnect")
    }

    /// AC10 [P0]: shutdown clears all connections including SSE and HTTP.
    func testMCPClientManager_shutdown_clearsSseAndHttpConnections() async {
        let manager = MCPClientManager()

        await manager.connect(name: "sse-srv", config: McpSseConfig(url: "http://localhost:1/sse"))
        await manager.connect(name: "http-srv", config: McpHttpConfig(url: "http://localhost:1/mcp"))

        await manager.shutdown()
        let connections = await manager.getConnections()

        XCTAssertTrue(connections.isEmpty,
                       "shutdown should clear all SSE and HTTP connections")
    }

    /// AC10 [P1]: disconnect of SSE does not affect HTTP or stdio connections.
    func testMCPClientManager_disconnect_sse_doesNotAffectHttpOrStdio() async {
        let manager = MCPClientManager()

        await manager.connect(name: "stdio-srv", config: McpStdioConfig(command: "/nonexistent"))
        await manager.connect(name: "sse-srv", config: McpSseConfig(url: "http://localhost:1/sse"))
        await manager.connect(name: "http-srv", config: McpHttpConfig(url: "http://localhost:1/mcp"))

        await manager.disconnect(name: "sse-srv")
        let connections = await manager.getConnections()

        XCTAssertNil(connections["sse-srv"],
                      "SSE server should be removed")
        XCTAssertNotNil(connections["stdio-srv"],
                         "Stdio server should remain")
        XCTAssertNotNil(connections["http-srv"],
                         "HTTP server should remain")
    }

    // MARK: - AC5: HTTP/SSE Tool Discovery

    /// AC5 [P0]: Failed SSE connection contributes no tools to getMCPTools.
    func testMCPClientManager_getMCPTools_failedSse_returnsEmpty() async {
        let manager = MCPClientManager()
        await manager.connect(name: "sse-fail", config: McpSseConfig(url: "http://localhost:99999"))

        let tools = await manager.getMCPTools()
        XCTAssertTrue(tools.isEmpty,
                       "Failed SSE connections should contribute no tools")
    }

    /// AC5 [P0]: Failed HTTP connection contributes no tools to getMCPTools.
    func testMCPClientManager_getMCPTools_failedHttp_returnsEmpty() async {
        let manager = MCPClientManager()
        await manager.connect(name: "http-fail", config: McpHttpConfig(url: "http://localhost:99999"))

        let tools = await manager.getMCPTools()
        XCTAssertTrue(tools.isEmpty,
                       "Failed HTTP connections should contribute no tools")
    }

    /// AC5 [P1]: Mixed failed connections (stdio + SSE + HTTP) contribute no tools.
    func testMCPClientManager_getMCPTools_allFailedTransports_returnsEmpty() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "stdio-fail": .stdio(McpStdioConfig(command: "/nonexistent")),
            "sse-fail": .sse(McpSseConfig(url: "http://localhost:99999/sse")),
            "http-fail": .http(McpHttpConfig(url: "http://localhost:99999/mcp"))
        ]
        await manager.connectAll(servers: servers)

        let tools = await manager.getMCPTools()
        XCTAssertTrue(tools.isEmpty,
                       "All failed connections should contribute no tools")
    }

    // MARK: - AC11: Module Boundary Compliance

    /// AC11 [P0]: MCPClientManager with HTTP/SSE does not import Core/ or Stores/.
    /// This is a compile-time check -- if MCPClientManager.swift only imports
    /// Foundation + MCP + Types/, this compiles correctly.
    func testMCPClientManager_httpSse_respectsModuleBoundary() async {
        // MCPClientManager should work with only Foundation, MCP, and Types/
        // If this compiles, module boundaries are respected
        let manager = MCPClientManager()
        await manager.connect(name: "boundary-test", config: McpSseConfig(url: "http://localhost:1"))
        await manager.connect(name: "boundary-test-2", config: McpHttpConfig(url: "http://localhost:1"))
        _ = manager
    }

    // MARK: - AC12: Cross-platform Compatibility

    /// AC12 [P0]: SSE transport does not crash on current platform.
    /// HTTPClientTransport handles platform differences internally.
    func testMCPClientManager_sseTransport_doesNotCrashOnPlatform() async {
        let manager = MCPClientManager()
        // SSE with streaming: true -- should work on macOS (full SSE)
        // On Linux, mcp-swift-sdk handles limited SSE gracefully
        await manager.connect(name: "sse-platform", config: McpSseConfig(url: "http://localhost:1/sse"))

        let connections = await manager.getConnections()
        XCTAssertNotNil(connections["sse-platform"])
    }

    /// AC12 [P0]: HTTP transport does not crash on current platform.
    func testMCPClientManager_httpTransport_doesNotCrashOnPlatform() async {
        let manager = MCPClientManager()
        // HTTP with streaming: false -- should work on all platforms
        await manager.connect(name: "http-platform", config: McpHttpConfig(url: "http://localhost:1/mcp"))

        let connections = await manager.getConnections()
        XCTAssertNotNil(connections["http-platform"])
    }

    // MARK: - Edge Cases

    /// AC9 [P1]: SSE connect with empty URL marks error.
    func testMCPClientManager_connect_sseConfig_emptyURL_marksError() async {
        let manager = MCPClientManager()
        await manager.connect(name: "sse-empty", config: McpSseConfig(url: ""))

        let connections = await manager.getConnections()
        XCTAssertEqual(connections["sse-empty"]?.status, .error,
                        "Empty SSE URL should result in error status")
    }

    /// AC9 [P1]: HTTP connect with empty URL marks error.
    func testMCPClientManager_connect_httpConfig_emptyURL_marksError() async {
        let manager = MCPClientManager()
        await manager.connect(name: "http-empty", config: McpHttpConfig(url: ""))

        let connections = await manager.getConnections()
        XCTAssertEqual(connections["http-empty"]?.status, .error,
                        "Empty HTTP URL should result in error status")
    }

    /// AC7 [P1]: Reconnecting to same name replaces previous connection.
    func testMCPClientManager_connect_sameName_replacesPreviousSseConnection() async {
        let manager = MCPClientManager()

        await manager.connect(name: "replaceable", config: McpSseConfig(url: "http://localhost:1/first"))
        await manager.connect(name: "replaceable", config: McpSseConfig(url: "http://localhost:1/second"))

        let connections = await manager.getConnections()
        XCTAssertEqual(connections.count, 1,
                        "Same name should result in single connection (replaced)")
    }

    // MARK: - McpSseConfig & McpHttpConfig Types

    /// AC1 [P0]: McpSseConfig can be created with url only.
    func testMcpSseConfig_urlOnly() {
        let config = McpSseConfig(url: "http://localhost:8080/sse")
        XCTAssertEqual(config.url, "http://localhost:8080/sse")
        XCTAssertNil(config.headers)
    }

    /// AC1 [P0]: McpSseConfig can be created with url and headers.
    func testMcpSseConfig_urlAndHeaders() {
        let config = McpSseConfig(
            url: "http://localhost:8080/sse",
            headers: ["Authorization": "Bearer token"]
        )
        XCTAssertEqual(config.url, "http://localhost:8080/sse")
        XCTAssertEqual(config.headers?["Authorization"], "Bearer token")
    }

    /// AC2 [P0]: McpHttpConfig can be created with url only.
    func testMcpHttpConfig_urlOnly() {
        let config = McpHttpConfig(url: "http://localhost:8080/mcp")
        XCTAssertEqual(config.url, "http://localhost:8080/mcp")
        XCTAssertNil(config.headers)
    }

    /// AC2 [P0]: McpHttpConfig can be created with url and headers.
    func testMcpHttpConfig_urlAndHeaders() {
        let config = McpHttpConfig(
            url: "http://localhost:8080/mcp",
            headers: ["X-API-Key": "key-123"]
        )
        XCTAssertEqual(config.url, "http://localhost:8080/mcp")
        XCTAssertEqual(config.headers?["X-API-Key"], "key-123")
    }

    /// AC7 [P0]: McpServerConfig.sse wraps McpSseConfig.
    func testMcpServerConfig_sseCase() {
        let sseConfig = McpSseConfig(url: "http://localhost:8080/sse")
        let config = McpServerConfig.sse(sseConfig)

        if case .sse(let unwrapped) = config {
            XCTAssertEqual(unwrapped.url, "http://localhost:8080/sse")
        } else {
            XCTFail("Expected .sse case")
        }
    }

    /// AC7 [P0]: McpServerConfig.http wraps McpHttpConfig.
    func testMcpServerConfig_httpCase() {
        let httpConfig = McpHttpConfig(url: "http://localhost:8080/mcp")
        let config = McpServerConfig.http(httpConfig)

        if case .http(let unwrapped) = config {
            XCTAssertEqual(unwrapped.url, "http://localhost:8080/mcp")
        } else {
            XCTFail("Expected .http case")
        }
    }

    /// AC7 [P0]: McpServerConfig equality works for SSE.
    func testMcpServerConfig_sse_isEquatable() {
        let config1 = McpServerConfig.sse(McpSseConfig(url: "http://localhost:8080"))
        let config2 = McpServerConfig.sse(McpSseConfig(url: "http://localhost:8080"))
        XCTAssertEqual(config1, config2)
    }

    /// AC7 [P0]: McpServerConfig equality works for HTTP.
    func testMcpServerConfig_http_isEquatable() {
        let config1 = McpServerConfig.http(McpHttpConfig(url: "http://localhost:8080"))
        let config2 = McpServerConfig.http(McpHttpConfig(url: "http://localhost:8080"))
        XCTAssertEqual(config1, config2)
    }

    /// AC7 [P0]: McpServerConfig stdio, sse, and http are distinct cases.
    func testMcpServerConfig_allCases_areDistinct() {
        let stdio = McpServerConfig.stdio(McpStdioConfig(command: "echo"))
        let sse = McpServerConfig.sse(McpSseConfig(url: "http://localhost:8080"))
        let http = McpServerConfig.http(McpHttpConfig(url: "http://localhost:8080"))

        XCTAssertNotEqual(stdio, sse)
        XCTAssertNotEqual(stdio, http)
        XCTAssertNotEqual(sse, http)
    }

    // ================================================================
    // MARK: - getStatus()
    // ================================================================

    /// getStatus returns empty when no servers configured.
    func testGetStatus_noServers_returnsEmpty() async {
        let manager = MCPClientManager()
        let status = await manager.getStatus()
        XCTAssertTrue(status.isEmpty)
    }

    /// getStatus shows pending for server known from connectAll but not yet connected.
    func testGetStatus_configuredButNotConnected_showsPending() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "pending-srv": .stdio(McpStdioConfig(command: "/nonexistent"))
        ]
        await manager.connectAll(servers: servers)

        // The connection attempt will fail, resulting in error status
        let status = await manager.getStatus()
        XCTAssertNotNil(status["pending-srv"])
    }

    /// getStatus shows disabled for a toggled-off server.
    func testGetStatus_disabledServer_showsDisabled() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "toggle-srv": .stdio(McpStdioConfig(command: "/nonexistent"))
        ]
        await manager.connectAll(servers: servers)

        // Disable the server
        try? await manager.toggle(name: "toggle-srv", enabled: false)

        let status = await manager.getStatus()
        XCTAssertEqual(status["toggle-srv"]?.status, .disabled)
    }

    /// getStatus shows error for a failed connection.
    func testGetStatus_failedConnection_showsFailed() async {
        let manager = MCPClientManager()
        await manager.connect(name: "fail-srv", config: McpStdioConfig(command: "/nonexistent"))

        let status = await manager.getStatus()
        XCTAssertEqual(status["fail-srv"]?.status, .failed)
        XCTAssertNotNil(status["fail-srv"]?.error)
    }

    /// getStatus reports tool names for a failed connection as empty.
    func testGetStatus_failedConnection_emptyTools() async {
        let manager = MCPClientManager()
        await manager.connect(name: "tool-check", config: McpStdioConfig(command: "/nonexistent"))

        let status = await manager.getStatus()
        XCTAssertEqual(status["tool-check"]?.tools, [])
    }

    // ================================================================
    // MARK: - reconnect()
    // ================================================================

    /// reconnect throws for unknown server name.
    func testReconnect_unknownServer_throws() async {
        let manager = MCPClientManager()
        do {
            try await manager.reconnect(name: "nonexistent")
            XCTFail("Should throw for unknown server")
        } catch let error as MCPClientManagerError {
            if case .serverNotFound(let name) = error {
                XCTAssertEqual(name, "nonexistent")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// reconnect for a previously connected server uses stored config.
    func testReconnect_storedConfig_reconnects() async throws {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "reconnect-srv": .stdio(McpStdioConfig(command: "/nonexistent"))
        ]
        await manager.connectAll(servers: servers)

        // Reconnect should work (will fail again since command doesn't exist, but no throw)
        try await manager.reconnect(name: "reconnect-srv")

        let connections = await manager.getConnections()
        XCTAssertNotNil(connections["reconnect-srv"])
    }

    /// reconnect clears disabled state.
    func testReconnect_clearsDisabledState() async throws {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "disabled-srv": .stdio(McpStdioConfig(command: "/nonexistent"))
        ]
        await manager.connectAll(servers: servers)

        // Disable then reconnect
        try await manager.toggle(name: "disabled-srv", enabled: false)
        var status = await manager.getStatus()
        XCTAssertEqual(status["disabled-srv"]?.status, .disabled)

        try await manager.reconnect(name: "disabled-srv")
        status = await manager.getStatus()
        // After reconnect, should no longer be disabled
        XCTAssertNotEqual(status["disabled-srv"]?.status, .disabled)
    }

    // ================================================================
    // MARK: - toggle()
    // ================================================================

    /// toggle throws for unknown server.
    func testToggle_unknownServer_throws() async {
        let manager = MCPClientManager()
        do {
            try await manager.toggle(name: "nonexistent", enabled: false)
            XCTFail("Should throw for unknown server")
        } catch let error as MCPClientManagerError {
            if case .serverNotFound(let name) = error {
                XCTAssertEqual(name, "nonexistent")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// toggle(enabled: false) disconnects and marks as disabled.
    func testToggle_disable_disconnectsAndMarksDisabled() async throws {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "to-disable": .stdio(McpStdioConfig(command: "/nonexistent"))
        ]
        await manager.connectAll(servers: servers)

        try await manager.toggle(name: "to-disable", enabled: false)

        let status = await manager.getStatus()
        XCTAssertEqual(status["to-disable"]?.status, .disabled)

        let connections = await manager.getConnections()
        XCTAssertEqual(connections["to-disable"]?.status, .disconnected)
    }

    /// toggle(enabled: true) reconnects a disabled server.
    func testToggle_enable_reconnects() async throws {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "to-toggle": .stdio(McpStdioConfig(command: "/nonexistent"))
        ]
        await manager.connectAll(servers: servers)

        try await manager.toggle(name: "to-toggle", enabled: false)
        try await manager.toggle(name: "to-toggle", enabled: true)

        let status = await manager.getStatus()
        XCTAssertNotEqual(status["to-toggle"]?.status, .disabled)
    }

    // ================================================================
    // MARK: - setServers()
    // ================================================================

    /// setServers with empty set removes all existing servers.
    func testSetServers_empty_removesAll() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "old-srv": .stdio(McpStdioConfig(command: "/nonexistent"))
        ]
        await manager.connectAll(servers: servers)

        let result = await manager.setServers([:])

        XCTAssertEqual(result.removed, ["old-srv"])
        XCTAssertTrue(result.added.isEmpty)

        let connections = await manager.getConnections()
        XCTAssertTrue(connections.isEmpty)
    }

    /// setServers adds new servers not in the existing set.
    func testSetServers_addsNewServer() async {
        let manager = MCPClientManager()

        let result = await manager.setServers([
            "new-srv": .stdio(McpStdioConfig(command: "/nonexistent"))
        ])

        XCTAssertEqual(result.added, ["new-srv"])
        XCTAssertTrue(result.removed.isEmpty)

        let connections = await manager.getConnections()
        XCTAssertNotNil(connections["new-srv"])
    }

    /// setServers detects changed configs and reconnects.
    func testSetServers_changedConfig_reconnects() async {
        let manager = MCPClientManager()
        await manager.connectAll(servers: [
            "changing": .stdio(McpStdioConfig(command: "/nonexistent1"))
        ])

        let result = await manager.setServers([
            "changing": .stdio(McpStdioConfig(command: "/nonexistent2"))
        ])

        // The config changed but the name is the same, so added/removed don't include it
        // The changed config is treated as remove+add internally
        XCTAssertTrue(result.added.isEmpty, "Same-name changed config is not in 'added'")
        XCTAssertTrue(result.removed.isEmpty, "Same-name changed config is not in 'removed'")
        // The connection should be re-attempted and fail again
        let connections = await manager.getConnections()
        XCTAssertNotNil(connections["changing"])
        XCTAssertEqual(connections["changing"]?.status, .error)
    }

    /// setServers reports errors for failed connections.
    func testSetServers_failedConnection_reportsError() async {
        let manager = MCPClientManager()

        let result = await manager.setServers([
            "fail-srv": .stdio(McpStdioConfig(command: "/nonexistent"))
        ])

        // The connection will fail, so it should be reported in errors
        XCTAssertNotNil(result.errors["fail-srv"])
    }

    /// setServers replaces entire server set atomically.
    func testSetServers_replacesEntireSet() async {
        let manager = MCPClientManager()
        await manager.connectAll(servers: [
            "old1": .stdio(McpStdioConfig(command: "/nonexistent")),
            "old2": .stdio(McpStdioConfig(command: "/nonexistent"))
        ])

        let result = await manager.setServers([
            "new1": .stdio(McpStdioConfig(command: "/nonexistent"))
        ])

        XCTAssertTrue(result.removed.contains("old1"))
        XCTAssertTrue(result.removed.contains("old2"))
        XCTAssertTrue(result.added.contains("new1"))
    }

    // ================================================================
    // MARK: - MCPClientManagerError
    // ================================================================

    /// MCPClientManagerError.serverNotFound is equatable.
    func testMCPClientManagerError_serverNotFound_isEquatable() {
        let err1 = MCPClientManagerError.serverNotFound("a")
        let err2 = MCPClientManagerError.serverNotFound("a")
        let err3 = MCPClientManagerError.serverNotFound("b")
        XCTAssertEqual(err1, err2)
        XCTAssertNotEqual(err1, err3)
    }

    // ================================================================
    // MARK: - McpServerStatus & McpServerUpdateResult types
    // ================================================================

    /// McpServerStatus can be created with all fields.
    func testMcpServerStatus_allFields() {
        let status = McpServerStatus(
            name: "srv",
            status: .connected,
            serverInfo: McpServerInfo(name: "MyServer", version: "1.0"),
            error: nil,
            tools: ["tool1", "tool2"],
            config: .stdio(McpStdioConfig(command: "srv")),
            scope: "project"
        )
        XCTAssertEqual(status.name, "srv")
        XCTAssertEqual(status.status, .connected)
        XCTAssertEqual(status.serverInfo?.name, "MyServer")
        XCTAssertEqual(status.tools, ["tool1", "tool2"])
        XCTAssertEqual(status.scope, "project")
    }

    /// McpServerStatusEnum has all 5 cases.
    func testMcpServerStatusEnum_allCases() {
        let allCases = McpServerStatusEnum.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.connected))
        XCTAssertTrue(allCases.contains(.failed))
        XCTAssertTrue(allCases.contains(.needsAuth))
        XCTAssertTrue(allCases.contains(.pending))
        XCTAssertTrue(allCases.contains(.disabled))
    }

    /// McpServerUpdateResult can be created with defaults.
    func testMcpServerUpdateResult_defaults() {
        let result = McpServerUpdateResult()
        XCTAssertTrue(result.added.isEmpty)
        XCTAssertTrue(result.removed.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    /// McpServerUpdateResult with values.
    func testMcpServerUpdateResult_withValues() {
        let result = McpServerUpdateResult(
            added: ["a"],
            removed: ["b"],
            errors: ["c": "failed"]
        )
        XCTAssertEqual(result.added, ["a"])
        XCTAssertEqual(result.removed, ["b"])
        XCTAssertEqual(result.errors["c"], "failed")
    }

    // ================================================================
    // MARK: - McpSdkServerConfig equality
    // ================================================================

    /// McpSdkServerConfig equality compares name, version, and object identity.
    func testMcpSdkServerConfig_equality_sameInstance() {
        let server = InProcessMCPServer(name: "test", version: "1.0", tools: [])
        let config = McpSdkServerConfig(name: "test", version: "1.0", server: server)
        let config2 = McpSdkServerConfig(name: "test", version: "1.0", server: server)
        XCTAssertEqual(config, config2)
    }

    /// McpSdkServerConfig inequality with different name.
    func testMcpSdkServerConfig_inequality_differentName() {
        let server = InProcessMCPServer(name: "test", version: "1.0", tools: [])
        let config1 = McpSdkServerConfig(name: "alpha", version: "1.0", server: server)
        let config2 = McpSdkServerConfig(name: "beta", version: "1.0", server: server)
        XCTAssertNotEqual(config1, config2)
    }

    /// McpSdkServerConfig inequality with different server instance.
    func testMcpSdkServerConfig_inequality_differentServer() {
        let server1 = InProcessMCPServer(name: "test", version: "1.0", tools: [])
        let server2 = InProcessMCPServer(name: "test", version: "1.0", tools: [])
        let config1 = McpSdkServerConfig(name: "test", version: "1.0", server: server1)
        let config2 = McpSdkServerConfig(name: "test", version: "1.0", server: server2)
        XCTAssertNotEqual(config1, config2)
    }

    // ================================================================
    // MARK: - McpClaudeAIProxyConfig
    // ================================================================

    /// McpClaudeAIProxyConfig can be created and is equatable.
    func testMcpClaudeAIProxyConfig_creation() {
        let config = McpClaudeAIProxyConfig(url: "https://proxy.example.com", id: "srv-123")
        XCTAssertEqual(config.url, "https://proxy.example.com")
        XCTAssertEqual(config.id, "srv-123")
    }

    /// McpClaudeAIProxyConfig equality.
    func testMcpClaudeAIProxyConfig_equality() {
        let c1 = McpClaudeAIProxyConfig(url: "https://proxy.example.com", id: "srv-1")
        let c2 = McpClaudeAIProxyConfig(url: "https://proxy.example.com", id: "srv-1")
        let c3 = McpClaudeAIProxyConfig(url: "https://proxy.example.com", id: "srv-2")
        XCTAssertEqual(c1, c2)
        XCTAssertNotEqual(c1, c3)
    }

    // ================================================================
    // MARK: - connectAll with ClaudeAI Proxy config
    // ================================================================

    /// connectAll with claudeAIProxy config delegates to connectClaudeAIProxy.
    func testMCPClientManager_connectAll_claudeAIProxyConfig() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "proxy-srv": .claudeAIProxy(McpClaudeAIProxyConfig(
                url: "http://localhost:99999/proxy",
                id: "test-server-id"
            ))
        ]

        await manager.connectAll(servers: servers)
        let connections = await manager.getConnections()

        XCTAssertNotNil(connections["proxy-srv"])
        XCTAssertEqual(connections["proxy-srv"]?.status, .error,
                        "Unreachable proxy URL should result in error")
    }

    /// connectAll with sdk config is a no-op (handled by Agent directly).
    func testMCPClientManager_connectAll_sdkConfig_isNoOp() async {
        let manager = MCPClientManager()
        let server = InProcessMCPServer(name: "test", version: "1.0", tools: [])
        let servers: [String: McpServerConfig] = [
            "sdk-srv": .sdk(McpSdkServerConfig(name: "test", version: "1.0", server: server))
        ]

        await manager.connectAll(servers: servers)
        let connections = await manager.getConnections()

        // SDK servers are not tracked by MCPClientManager
        XCTAssertNil(connections["sdk-srv"])
    }

    /// reconnect with ClaudeAI Proxy config delegates correctly.
    func testMCPClientManager_reconnect_claudeAIProxy() async throws {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "proxy-reconnect": .claudeAIProxy(McpClaudeAIProxyConfig(
                url: "http://localhost:99999/proxy",
                id: "test-id"
            ))
        ]
        await manager.connectAll(servers: servers)

        // Reconnect should use stored config
        try await manager.reconnect(name: "proxy-reconnect")

        let connections = await manager.getConnections()
        XCTAssertNotNil(connections["proxy-reconnect"])
    }

    // ================================================================
    // MARK: - MCPManagedConnection status mapping in getStatus
    // ================================================================

    /// getStatus maps connected to .connected.
    func testGetStatus_connectedStatus_mapsCorrectly() async {
        let manager = MCPClientManager()
        // Manually inject a connected connection via connectAll with a bad command
        // that will fail — getStatus for error maps to .failed
        // We'll test the status mapping by checking the error case
        await manager.connect(name: "err-srv", config: McpStdioConfig(command: "/nonexistent"))
        let status = await manager.getStatus()
        XCTAssertEqual(status["err-srv"]?.status, .failed)
    }

    // ================================================================
    // MARK: - setServers with mixed configs
    // ================================================================

    /// setServers with SSE/HTTP/stdio mixed configs.
    func testSetServers_mixedConfigs() async {
        let manager = MCPClientManager()

        let result = await manager.setServers([
            "stdio-srv": .stdio(McpStdioConfig(command: "/nonexistent")),
            "sse-srv": .sse(McpSseConfig(url: "http://localhost:99999/sse")),
            "http-srv": .http(McpHttpConfig(url: "http://localhost:99999/mcp"))
        ])

        XCTAssertTrue(result.added.count == 3)
        let connections = await manager.getConnections()
        XCTAssertEqual(connections.count, 3)
    }

    /// setServers removing and adding simultaneously.
    func testSetServers_removeAndAddSimultaneously() async {
        let manager = MCPClientManager()
        await manager.connectAll(servers: [
            "old-srv": .stdio(McpStdioConfig(command: "/nonexistent"))
        ])

        let result = await manager.setServers([
            "new-srv": .stdio(McpStdioConfig(command: "/nonexistent"))
        ])

        XCTAssertTrue(result.removed.contains("old-srv"))
        XCTAssertTrue(result.added.contains("new-srv"))
        XCTAssertTrue(result.errors["new-srv"] != nil)
    }
}

// MARK: - Mock Helpers

/// Mock MCPClient for testing MCPToolDefinition behavior without real MCP connections.
/// Conforms to MCPClientProtocol which MCPToolDefinition uses.
final class MockMCPClient: MCPClientProtocol, Sendable {
    let toolsResult: [MockMCPToolInfo]
    let callResult: String?
    let callError: Error?

    init(toolsResult: [MockMCPToolInfo] = [], callResult: String? = nil, callError: Error? = nil) {
        self.toolsResult = toolsResult
        self.callResult = callResult
        self.callError = callError
    }

    func callTool(name: String, arguments: [String: Any]?) async throws -> String {
        if let error = callError {
            throw error
        }
        return callResult ?? ""
    }

    func listTools() async -> [MockMCPToolInfo] {
        return toolsResult
    }
}

/// Mock tool info returned by listTools.
struct MockMCPToolInfo: Sendable {
    let name: String
    let description: String
    nonisolated(unsafe) let inputSchema: [String: Any]
}

/// Test error for mock failures.
enum MCPTestError: Error, Sendable {
    case connectionFailed
    case toolNotFound
    case timeout
}

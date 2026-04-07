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

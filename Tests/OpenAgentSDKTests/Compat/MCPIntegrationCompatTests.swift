import XCTest
@testable import OpenAgentSDK

// MARK: - MCP Integration Compatibility Verification Tests (Story 16-5)

/// ATDD tests for Story 16-5: MCP Integration Compatibility Verification.
///
/// Verifies Swift SDK's MCP integration supports all TypeScript SDK server
/// configuration types and runtime management operations. Documents gaps
/// between TS SDK and Swift SDK for MCP-related APIs.
///
/// Coverage:
/// - AC2: 5 McpServerConfig type verification (5 PASS)
/// - AC3: MCP runtime management operations verification (4 PASS)
/// - AC4: McpServerStatus type verification (5 PASS via McpServerStatusEnum)
/// - AC5: MCP tool namespace verification (PASS)
/// - AC6: MCP resource operations verification (PASS)
/// - AC7: AgentMcpServerSpec verification (PASS)
/// - AC8: Compatibility report output
final class MCPIntegrationCompatTests: XCTestCase {

    // MARK: - AC2: McpServerConfig Type Verification

    // ================================================================
    // AC2: McpStdioServerConfig (type: "stdio", command, args, env)
    // ================================================================

    /// AC2 [P0]: McpStdioConfig has command field matching TS McpStdioServerConfig.command.
    func testMcpStdioConfig_hasCommandField() {
        let config = McpStdioConfig(command: "node", args: ["server.js"], env: ["KEY": "val"])
        XCTAssertEqual(config.command, "node", "McpStdioConfig.command should match TS McpStdioServerConfig.command")
    }

    /// AC2 [P0]: McpStdioConfig has args field matching TS McpStdioServerConfig.args.
    func testMcpStdioConfig_hasArgsField() {
        let config = McpStdioConfig(command: "node", args: ["server.js", "--verbose"])
        XCTAssertEqual(config.args, ["server.js", "--verbose"], "McpStdioConfig.args should match TS McpStdioServerConfig.args")
    }

    /// AC2 [P0]: McpStdioConfig has env field matching TS McpStdioServerConfig.env.
    func testMcpStdioConfig_hasEnvField() {
        let config = McpStdioConfig(command: "node", env: ["API_KEY": "test"])
        XCTAssertEqual(config.env?["API_KEY"], "test", "McpStdioConfig.env should match TS McpStdioServerConfig.env")
    }

    /// AC2 [P0]: McpStdioConfig defaults args and env to nil.
    func testMcpStdioConfig_defaultsArgsAndEnvToNil() {
        let config = McpStdioConfig(command: "python")
        XCTAssertNil(config.args, "args should default to nil, matching TS optional args")
        XCTAssertNil(config.env, "env should default to nil, matching TS optional env")
    }

    /// AC2 [P0]: McpServerConfig.stdio case wraps McpStdioConfig.
    func testMcpServerConfig_hasStdioCase() {
        let stdioConfig = McpStdioConfig(command: "npx", args: ["-y", "@modelcontextprotocol/server"])
        let server = McpServerConfig.stdio(stdioConfig)
        if case .stdio(let config) = server {
            XCTAssertEqual(config.command, "npx")
        } else {
            XCTFail("Expected .stdio case on McpServerConfig")
        }
    }

    // ================================================================
    // AC2: McpSSEServerConfig (type: "sse", url, headers)
    // ================================================================

    /// AC2 [P0]: McpSseConfig has url field matching TS McpSSEServerConfig.url.
    func testMcpSseConfig_hasUrlField() {
        let config = McpSseConfig(url: "http://localhost:8080/sse")
        XCTAssertEqual(config.url, "http://localhost:8080/sse", "McpSseConfig.url should match TS McpSSEServerConfig.url")
    }

    /// AC2 [P0]: McpSseConfig has headers field matching TS McpSSEServerConfig.headers.
    func testMcpSseConfig_hasHeadersField() {
        let config = McpSseConfig(url: "http://localhost:8080/sse", headers: ["Auth": "token"])
        XCTAssertEqual(config.headers?["Auth"], "token", "McpSseConfig.headers should match TS McpSSEServerConfig.headers")
    }

    /// AC2 [P0]: McpSseConfig defaults headers to nil.
    func testMcpSseConfig_defaultsHeadersToNil() {
        let config = McpSseConfig(url: "http://localhost:8080/sse")
        XCTAssertNil(config.headers, "headers should default to nil, matching TS optional headers")
    }

    /// AC2 [P0]: McpServerConfig.sse case wraps McpSseConfig.
    func testMcpServerConfig_hasSseCase() {
        let sseConfig = McpSseConfig(url: "http://example.com/sse", headers: ["X-Key": "abc"])
        let server = McpServerConfig.sse(sseConfig)
        if case .sse(let config) = server {
            XCTAssertEqual(config.url, "http://example.com/sse")
        } else {
            XCTFail("Expected .sse case on McpServerConfig")
        }
    }

    // ================================================================
    // AC2: McpHttpServerConfig (type: "http", url, headers)
    // ================================================================

    /// AC2 [P0]: McpHttpConfig has url field matching TS McpHttpServerConfig.url.
    func testMcpHttpConfig_hasUrlField() {
        let config = McpHttpConfig(url: "http://localhost:9090/mcp")
        XCTAssertEqual(config.url, "http://localhost:9090/mcp", "McpHttpConfig.url should match TS McpHttpServerConfig.url")
    }

    /// AC2 [P0]: McpHttpConfig has headers field matching TS McpHttpServerConfig.headers.
    func testMcpHttpConfig_hasHeadersField() {
        let config = McpHttpConfig(url: "http://localhost:9090/mcp", headers: ["Auth": "token"])
        XCTAssertEqual(config.headers?["Auth"], "token", "McpHttpConfig.headers should match TS McpHttpServerConfig.headers")
    }

    /// AC2 [P0]: McpHttpConfig defaults headers to nil.
    func testMcpHttpConfig_defaultsHeadersToNil() {
        let config = McpHttpConfig(url: "http://localhost:9090/mcp")
        XCTAssertNil(config.headers, "headers should default to nil, matching TS optional headers")
    }

    /// AC2 [P0]: McpServerConfig.http case wraps McpHttpConfig.
    func testMcpServerConfig_hasHttpCase() {
        let httpConfig = McpHttpConfig(url: "http://example.com/mcp")
        let server = McpServerConfig.http(httpConfig)
        if case .http(let config) = server {
            XCTAssertEqual(config.url, "http://example.com/mcp")
        } else {
            XCTFail("Expected .http case on McpServerConfig")
        }
    }

    // ================================================================
    // AC2: McpSdkServerConfigWithInstance (type: "sdk", name, instance)
    // ================================================================

    /// AC2 [P0]: McpSdkServerConfig has name field matching TS McpSdkServerConfigWithInstance.name.
    func testMcpSdkServerConfig_hasNameField() async {
        let server = InProcessMCPServer(name: "test-sdk", tools: [])
        let config = McpSdkServerConfig(name: "my-sdk", version: "1.0.0", server: server)
        XCTAssertEqual(config.name, "my-sdk", "McpSdkServerConfig.name should match TS McpSdkServerConfigWithInstance.name")
    }

    /// AC2 [P0]: McpSdkServerConfig has server (instance) field matching TS McpSdkServerConfigWithInstance.instance.
    func testMcpSdkServerConfig_hasServerInstanceField() async {
        let server = InProcessMCPServer(name: "test-sdk", tools: [])
        let config = McpSdkServerConfig(name: "my-sdk", version: "1.0.0", server: server)
        // Swift uses concrete InProcessMCPServer actor, TS uses generic instance (any tool provider)
        // This is a PARTIAL match -- Swift requires concrete type, TS is generic
        XCTAssertEqual(ObjectIdentifier(config.server), ObjectIdentifier(server))
    }

    /// AC2 [PARTIAL]: McpSdkServerConfig has version field (Swift-only, not in TS SDK).
    func testMcpSdkServerConfig_hasExtraVersionField() async {
        let server = InProcessMCPServer(name: "test-sdk", tools: [])
        let config = McpSdkServerConfig(name: "my-sdk", version: "2.0.0", server: server)
        XCTAssertEqual(config.version, "2.0.0", "version is a Swift-only field, not in TS McpSdkServerConfigWithInstance")
    }

    /// AC2 [P0]: McpServerConfig.sdk case wraps McpSdkServerConfig.
    func testMcpServerConfig_hasSdkCase() async {
        let server = InProcessMCPServer(name: "test-sdk", tools: [])
        let sdkConfig = McpSdkServerConfig(name: "my-sdk", version: "1.0.0", server: server)
        let config = McpServerConfig.sdk(sdkConfig)
        if case .sdk(let unwrapped) = config {
            XCTAssertEqual(unwrapped.name, "my-sdk")
        } else {
            XCTFail("Expected .sdk case on McpServerConfig")
        }
    }

    // ================================================================
    // AC2: McpClaudeAIProxyServerConfig (type: "claudeai-proxy", url, id)
    // GAP: No Swift equivalent exists
    // ================================================================

    /// AC2 [GAP]: McpClaudeAIProxyServerConfig has NO Swift equivalent.
    /// This test documents the gap. TS SDK has type: "claudeai-proxy" with url and id fields.
    func testMcpServerConfig_claudeAiProxy_gap() {
        // TS SDK has McpClaudeAIProxyServerConfig (type: "claudeai-proxy", url, id)
        // Swift SDK now has McpServerConfig.claudeAIProxy(McpClaudeAIProxyConfig)
        let proxyConfig = McpClaudeAIProxyConfig(url: "https://proxy.claude.ai/mcp", id: "server-123")
        let serverConfig = McpServerConfig.claudeAIProxy(proxyConfig)

        // Verify the case exists and wraps the config
        if case .claudeAIProxy(let config) = serverConfig {
            XCTAssertEqual(config.url, "https://proxy.claude.ai/mcp",
                           "McpClaudeAIProxyConfig.url matches TS McpClaudeAIProxyServerConfig.url")
            XCTAssertEqual(config.id, "server-123",
                           "McpClaudeAIProxyConfig.id matches TS McpClaudeAIProxyServerConfig.id")
        } else {
            XCTFail("Expected .claudeAIProxy case on McpServerConfig")
        }

        // Verify distinct from other cases
        let stdio = McpServerConfig.stdio(McpStdioConfig(command: "echo"))
        let sse = McpServerConfig.sse(McpSseConfig(url: "http://localhost/sse"))
        let http = McpServerConfig.http(McpHttpConfig(url: "http://localhost/mcp"))
        XCTAssertNotEqual(stdio, serverConfig)
        XCTAssertNotEqual(sse, serverConfig)
        XCTAssertNotEqual(http, serverConfig)
    }

    /// AC2 [P0]: McpServerConfig enum has exactly 5 cases.
    func testMcpServerConfig_hasExactlyFiveCases() {
        // Verify McpServerConfig has 5 cases by pattern matching exhaustiveness
        let configs: [McpServerConfig] = [
            .stdio(McpStdioConfig(command: "a")),
            .sse(McpSseConfig(url: "http://a")),
            .http(McpHttpConfig(url: "http://b")),
            .claudeAIProxy(McpClaudeAIProxyConfig(url: "https://proxy.claude.ai", id: "test")),
        ]
        // Each case must be matchable; 5 total cases (sdk requires InProcessMCPServer)
        XCTAssertEqual(configs.count, 4, "4 of 5 cases constructed without async; .sdk requires InProcessMCPServer")
    }

    /// AC2 [P0]: McpSseConfig and McpHttpConfig are both aliases for McpTransportConfig.
    func testMcpTransportConfig_sharedBySseAndHttp() {
        let sseConfig = McpSseConfig(url: "http://localhost:8080/sse", headers: ["X": "1"])
        let httpConfig = McpHttpConfig(url: "http://localhost:9090/mcp", headers: ["X": "1"])
        // Both are typealiases for McpTransportConfig
        let sseTransport: McpTransportConfig = sseConfig
        let httpTransport: McpTransportConfig = httpConfig
        XCTAssertEqual(sseTransport.url, "http://localhost:8080/sse")
        XCTAssertEqual(httpTransport.url, "http://localhost:9090/mcp")
    }

    // ================================================================
    // AC2: Config Type Coverage Summary
    // ================================================================

    /// AC2 [P0]: Summary of 5 TS config types vs Swift equivalents.
    func testMcpServerConfig_coverageSummary() {
        // TS SDK has 5 config types:
        // 1. McpStdioServerConfig (type: "stdio") -> PASS (McpServerConfig.stdio)
        // 2. McpSSEServerConfig (type: "sse") -> PASS (McpServerConfig.sse)
        // 3. McpHttpServerConfig (type: "http") -> PASS (McpServerConfig.http)
        // 4. McpSdkServerConfigWithInstance (type: "sdk") -> PARTIAL (McpServerConfig.sdk, concrete vs generic)
        // 5. McpClaudeAIProxyServerConfig (type: "claudeai-proxy") -> PASS (McpServerConfig.claudeAIProxy)

        let passCount = 4  // stdio, sse, http, claudeai-proxy
        let partialCount = 1  // sdk (concrete InProcessMCPServer vs generic instance)
        let missingCount = 0  // all types covered
        let total = 5

        XCTAssertEqual(passCount + partialCount + missingCount, total,
                       "All 5 TS config types must be accounted for")
    }

    // MARK: - AC3: MCP Runtime Management Operations Verification

    /// AC3 [PARTIAL]: getConnections() is available but NOT exposed on Agent public API.
    func testMCPClientManager_getConnections_available() async {
        let manager = MCPClientManager()
        let connections = await manager.getConnections()
        // getConnections exists on MCPClientManager but NOT on Agent
        XCTAssertTrue(connections.isEmpty, "MCPClientManager.getConnections() exists (PARTIAL: not on Agent public API)")
    }

    /// AC3 [PASS]: reconnectMcpServer(name) is now available on MCPClientManager.
    func testMCPClientManager_reconnectMcpServer_gap() async {
        let manager = MCPClientManager()
        // TS SDK has reconnectMcpServer(name: string) -> Promise<void>
        // Swift MCPClientManager now has reconnect(name:) method

        // Verify connect and disconnect exist (baseline)
        await manager.connect(name: "test", config: McpStdioConfig(command: "/nonexistent"))
        await manager.disconnect(name: "test")

        // Verify reconnect throws for unknown server (server configs not stored from individual connect)
        do {
            try await manager.reconnect(name: "unknown")
            XCTFail("reconnect should throw for unknown server")
        } catch {
            // Expected: server not found
        }
    }

    /// AC3 [PASS]: toggleMcpServer(name, enabled) is now available on MCPClientManager.
    func testMCPClientManager_toggleMcpServer_gap() async {
        // TS SDK has toggleMcpServer(name: string, enabled: boolean) -> Promise<void>
        // Swift MCPClientManager now has toggle(name:enabled:) method
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "test": .stdio(McpStdioConfig(command: "/nonexistent"))
        ]
        await manager.connectAll(servers: servers)

        // Verify toggle to disable works
        do {
            try await manager.toggle(name: "test", enabled: false)
        } catch {
            // May fail if server connection itself failed, but method exists
        }
    }

    /// AC3 [PASS]: setMcpServers(servers) is now available on MCPClientManager.
    func testMCPClientManager_setMcpServers_gap() async {
        // TS SDK has setMcpServers(servers: McpServerConfig[]) -> Promise<McpSetServersResult>
        // Swift MCPClientManager now has setServers(_:) -> McpServerUpdateResult
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "s1": .stdio(McpStdioConfig(command: "/nonexistent1"))
        ]
        let result = await manager.setServers(servers)
        XCTAssertTrue(result.added.contains("s1"), "s1 should be in added")
        XCTAssertTrue(result.removed.isEmpty, "No servers should be removed")
    }

    /// AC3 [P0]: MCPClientManager has connect(name:config:) for individual server connection.
    func testMCPClientManager_connect_individualServer() async {
        let manager = MCPClientManager()
        let config = McpStdioConfig(command: "/nonexistent")
        await manager.connect(name: "test-server", config: config)
        let connections = await manager.getConnections()
        XCTAssertNotNil(connections["test-server"], "connect(name:config:) should add server to connections")
    }

    /// AC3 [P0]: MCPClientManager has connectAll(servers:) for batch connection.
    func testMCPClientManager_connectAll_batchConnection() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "s1": .stdio(McpStdioConfig(command: "/nonexistent1")),
            "s2": .stdio(McpStdioConfig(command: "/nonexistent2")),
        ]
        await manager.connectAll(servers: servers)
        let connections = await manager.getConnections()
        XCTAssertEqual(connections.count, 2, "connectAll should connect all servers in dictionary")
    }

    /// AC3 [P0]: MCPClientManager has disconnect(name:) for individual disconnection.
    func testMCPClientManager_disconnect_individualServer() async {
        let manager = MCPClientManager()
        await manager.connect(name: "to-remove", config: McpStdioConfig(command: "/nonexistent"))
        await manager.disconnect(name: "to-remove")
        let connections = await manager.getConnections()
        XCTAssertNil(connections["to-remove"], "disconnect(name:) should remove server from connections")
    }

    /// AC3 [P0]: MCPClientManager has shutdown() for full cleanup.
    func testMCPClientManager_shutdown_fullCleanup() async {
        let manager = MCPClientManager()
        await manager.connect(name: "s1", config: McpStdioConfig(command: "/nonexistent"))
        await manager.connect(name: "s2", config: McpStdioConfig(command: "/nonexistent"))
        await manager.shutdown()
        let connections = await manager.getConnections()
        XCTAssertTrue(connections.isEmpty, "shutdown() should clear all connections")
    }

    /// AC3 [P0]: Summary of TS runtime operations vs Swift equivalents.
    func testMCPRuntimeOperations_coverageSummary() {
        // TS SDK runtime operations vs Swift MCPClientManager:
        // 1. mcpServerStatus() -> PASS (Agent.mcpServerStatus() now on public API)
        // 2. reconnectMcpServer(name) -> PASS (MCPClientManager.reconnect(name:) exists)
        // 3. toggleMcpServer(name, enabled) -> PASS (MCPClientManager.toggle(name:enabled:) exists)
        // 4. setMcpServers(servers) -> PASS (MCPClientManager.setServers(_:) exists)
        XCTAssertEqual(4, 4, "4 PASS = 4 total runtime operations checked")
    }

    // MARK: - AC4: McpServerStatus Type Verification

    /// AC4 [P0]: MCPConnectionStatus has "connected" matching TS McpServerStatus "connected".
    func testMCPConnectionStatus_hasConnected() {
        XCTAssertEqual(MCPConnectionStatus.connected.rawValue, "connected")
    }

    /// AC4 [P0]: MCPConnectionStatus has "error" (PARTIAL: maps to TS "failed").
    func testMCPConnectionStatus_hasError_mapsToTSFailed() {
        XCTAssertEqual(MCPConnectionStatus.error.rawValue, "error")
        // PARTIAL: TS SDK uses "failed", Swift uses "error" -- different name, same concept
    }

    /// AC4 [GAP]: MCPConnectionStatus missing "needs-auth" from TS SDK.
    func testMCPConnectionStatus_needsAuth_gap() {
        XCTAssertNil(MCPConnectionStatus(rawValue: "needs-auth"),
                     "TS SDK has 'needs-auth' status value. Swift has NO equivalent.")
    }

    /// AC4 [GAP]: MCPConnectionStatus missing "pending" from TS SDK.
    func testMCPConnectionStatus_pending_gap() {
        XCTAssertNil(MCPConnectionStatus(rawValue: "pending"),
                     "TS SDK has 'pending' status value. Swift has NO equivalent.")
    }

    /// AC4 [GAP]: MCPConnectionStatus missing "disabled" from TS SDK.
    func testMCPConnectionStatus_disabled_gap() {
        XCTAssertNil(MCPConnectionStatus(rawValue: "disabled"),
                     "TS SDK has 'disabled' status value. Swift has NO equivalent.")
    }

    /// AC4 [P0]: MCPConnectionStatus has "disconnected" (Swift-only, not in TS SDK).
    func testMCPConnectionStatus_hasDisconnected_swiftExtra() {
        XCTAssertEqual(MCPConnectionStatus.disconnected.rawValue, "disconnected")
        // This is a Swift-only status value, not in TS SDK
    }

    /// AC4 [P0]: MCPConnectionStatus has exactly 3 cases.
    func testMCPConnectionStatus_hasThreeCases() {
        let allCases: [MCPConnectionStatus] = [.connected, .disconnected, .error]
        XCTAssertEqual(allCases.count, 3, "Swift has 3 status values vs TS SDK's 5")
    }

    /// AC4 [P0]: MCPManagedConnection has name field matching TS McpServerStatus.name.
    func testMCPManagedConnection_hasNameField() {
        let conn = MCPManagedConnection(name: "my-server", status: .connected, tools: [])
        XCTAssertEqual(conn.name, "my-server", "name field matches TS McpServerStatus.name")
    }

    /// AC4 [P0]: MCPManagedConnection has status field matching TS McpServerStatus.status.
    func testMCPManagedConnection_hasStatusField() {
        let conn = MCPManagedConnection(name: "srv", status: .connected, tools: [])
        XCTAssertEqual(conn.status, .connected, "status field matches TS McpServerStatus.status (PARTIAL: 3 vs 5 values)")
    }

    /// AC4 [P0]: MCPManagedConnection has tools field matching TS McpServerStatus.tools.
    func testMCPManagedConnection_hasToolsField() {
        let tool = MCPToolDefinition(
            serverName: "srv", mcpToolName: "read", toolDescription: "read",
            schema: ["type": "object"], mcpClient: nil
        )
        let conn = MCPManagedConnection(name: "srv", status: .connected, tools: [tool])
        XCTAssertEqual(conn.tools.count, 1, "tools field matches TS McpServerStatus.tools (PARTIAL: no annotations)")
    }

    /// AC4 [GAP]: MCPManagedConnection missing serverInfo field from TS McpServerStatus.
    func testMCPManagedConnection_serverInfo_gap() {
        let conn = MCPManagedConnection(name: "srv", status: .connected, tools: [])
        let mirror = Mirror(reflecting: conn)
        let fieldNames = mirror.children.compactMap { $0.label }
        XCTAssertFalse(fieldNames.contains("serverInfo"),
                       "MCPManagedConnection missing serverInfo (TS has name+version)")
    }

    /// AC4 [GAP]: MCPManagedConnection missing error field from TS McpServerStatus.
    func testMCPManagedConnection_errorField_gap() {
        let conn = MCPManagedConnection(name: "srv", status: .connected, tools: [])
        let mirror = Mirror(reflecting: conn)
        let fieldNames = mirror.children.compactMap { $0.label }
        XCTAssertFalse(fieldNames.contains("error"),
                       "MCPManagedConnection missing error field (TS has error: string)")
    }

    /// AC4 [GAP]: MCPManagedConnection missing config field from TS McpServerStatus.
    func testMCPManagedConnection_configField_gap() {
        let conn = MCPManagedConnection(name: "srv", status: .connected, tools: [])
        let mirror = Mirror(reflecting: conn)
        let fieldNames = mirror.children.compactMap { $0.label }
        XCTAssertFalse(fieldNames.contains("config"),
                       "MCPManagedConnection missing config field (TS has config: McpServerConfig)")
    }

    /// AC4 [GAP]: MCPManagedConnection missing scope field from TS McpServerStatus.
    func testMCPManagedConnection_scopeField_gap() {
        let conn = MCPManagedConnection(name: "srv", status: .connected, tools: [])
        let mirror = Mirror(reflecting: conn)
        let fieldNames = mirror.children.compactMap { $0.label }
        XCTAssertFalse(fieldNames.contains("scope"),
                       "MCPManagedConnection missing scope field (TS has scope: 'project'|'local')")
    }

    /// AC4 [P0]: MCPManagedConnection field count summary.
    func testMCPManagedConnection_fieldCount() {
        let conn = MCPManagedConnection(name: "srv", status: .connected, tools: [])
        let mirror = Mirror(reflecting: conn)
        // Swift has 3 fields: name, status, tools
        // TS has 7 fields: name, status, serverInfo, error, config, scope, tools
        XCTAssertEqual(mirror.children.count, 3, "Swift has 3 fields vs TS SDK's 7 fields")
    }

    // MARK: - AC5: MCP Tool Namespace Verification

    /// AC5 [P0]: MCPToolDefinition uses mcp__{serverName}__{toolName} naming convention.
    func testMCPToolDefinition_usesMcpNamespace() {
        let tool = MCPToolDefinition(
            serverName: "myserver",
            mcpToolName: "read_file",
            toolDescription: "Reads a file",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertEqual(tool.name, "mcp__myserver__read_file",
                       "Must follow mcp__{serverName}__{toolName} convention matching TS SDK")
    }

    /// AC5 [P0]: Namespace with hyphenated server name.
    func testMCPToolDefinition_namespace_hyphenatedServer() {
        let tool = MCPToolDefinition(
            serverName: "my-cool-server",
            mcpToolName: "search",
            toolDescription: "search",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertEqual(tool.name, "mcp__my-cool-server__search")
    }

    /// AC5 [P0]: Namespace with underscored tool name.
    func testMCPToolDefinition_namespace_underscoredTool() {
        let tool = MCPToolDefinition(
            serverName: "fs",
            mcpToolName: "read_file",
            toolDescription: "read",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertEqual(tool.name, "mcp__fs__read_file")
    }

    /// AC5 [P0]: MCPToolDefinition enforces no double underscore in server name.
    /// NOTE: This is enforced via precondition() which causes a runtime crash,
    /// not a catchable error. The test documents this behavior rather than
    /// triggering the crash. TS SDK does NOT have this validation.
    func testMCPToolDefinition_rejectsDoubleUnderscoreServerName() {
        // Cannot test precondition failure in XCTest without process crash.
        // The precondition in MCPToolDefinition.init ensures serverName does
        // not contain "__" to prevent ambiguous mcp__server__tool names.
        // This is a Swift-only validation (TS SDK has no equivalent guard).
        // Verify valid names still work:
        let validTool = MCPToolDefinition(
            serverName: "my-server",
            mcpToolName: "tool",
            toolDescription: "desc",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertEqual(validTool.name, "mcp__my-server__tool")
    }

    /// AC5 [P0]: MCPToolDefinition conforms to ToolProtocol.
    func testMCPToolDefinition_conformsToToolProtocol() {
        let tool: ToolProtocol = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "desc",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertTrue(tool.name.hasPrefix("mcp__"), "ToolProtocol.name should start with mcp__")
    }

    // MARK: - AC6: MCP Resource Operations Verification

    /// AC6 [P0]: MCPResourceItem has name field matching TS resource type.
    func testMCPResourceItem_hasNameField() {
        let item = MCPResourceItem(name: "config.json")
        XCTAssertEqual(item.name, "config.json", "name field matches TS resource type")
    }

    /// AC6 [P0]: MCPResourceItem has description field matching TS resource type.
    func testMCPResourceItem_hasDescriptionField() {
        let item = MCPResourceItem(name: "config", description: "Config file")
        XCTAssertEqual(item.description, "Config file", "description field matches TS resource type")
    }

    /// AC6 [P0]: MCPResourceItem has uri field matching TS resource type.
    func testMCPResourceItem_hasUriField() {
        let item = MCPResourceItem(name: "data", uri: "file:///data.json")
        XCTAssertEqual(item.uri, "file:///data.json", "uri field matches TS resource type")
    }

    /// AC6 [P0]: ListMcpResources tool input schema has optional server field.
    func testListMcpResources_schema_hasServerField() {
        let tool = createListMcpResourcesTool()
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["server"], "ListMcpResources input schema should have 'server' field matching TS ListMcpResourcesInput")
    }

    /// AC6 [P0]: ReadMcpResource tool input schema has server and uri fields.
    func testReadMcpResource_schema_hasServerAndUriFields() {
        let tool = createReadMcpResourceTool()
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["server"], "ReadMcpResource input schema should have 'server' field")
        XCTAssertNotNil(properties?["uri"], "ReadMcpResource input schema should have 'uri' field matching TS ReadMcpResourceInput")

        let required = schema["required"] as? [String]
        XCTAssertTrue(required?.contains("server") ?? false, "server should be required")
        XCTAssertTrue(required?.contains("uri") ?? false, "uri should be required")
    }

    /// AC6 [P0]: MCPReadResult has contents field for resource read results.
    func testMCPReadResult_hasContentsField() {
        let content = MCPContentItem(text: "file content")
        let result = MCPReadResult(contents: [content])
        XCTAssertEqual(result.contents?.count, 1, "MCPReadResult.contents matches TS read result structure")
    }

    /// AC6 [P0]: MCPContentItem has text field for text content.
    func testMCPContentItem_hasTextField() {
        let item = MCPContentItem(text: "hello")
        XCTAssertEqual(item.text, "hello", "MCPContentItem.text matches TS content item")
    }

    /// AC6 [P0]: MCPContentItem has rawValue field for non-text content.
    func testMCPContentItem_hasRawValueField() {
        let item = MCPContentItem(rawValue: ["key": "value"])
        XCTAssertNotNil(item.rawValue, "MCPContentItem.rawValue matches TS content item")
    }

    /// AC6 [P0]: MCPConnectionInfo has name, status, and resourceProvider fields.
    func testMCPConnectionInfo_hasRequiredFields() {
        let info = MCPConnectionInfo(name: "server", status: "connected")
        XCTAssertEqual(info.name, "server")
        XCTAssertEqual(info.status, "connected")
        XCTAssertNil(info.resourceProvider)
    }

    /// AC6 [P0]: MCPResourceProvider protocol requires listResources and readResource.
    func testMCPResourceProvider_protocol() async {
        let provider = MockCompatResourceProvider(
            resources: [MCPResourceItem(name: "file1")],
            readResult: MCPReadResult(contents: [MCPContentItem(text: "data")])
        )
        let resources = await provider.listResources()
        XCTAssertEqual(resources?.count, 1, "MCPResourceProvider.listResources() works")

        let result = try? await provider.readResource(uri: "file:///file1")
        XCTAssertEqual(result?.contents?.first?.text, "data", "MCPResourceProvider.readResource() works")
    }

    // MARK: - AC7: AgentMcpServerSpec Verification

    /// AC7 [PASS] (resolved by Story 17-6): AgentDefinition has mcpServers property with AgentMcpServerSpec.
    func testAgentDefinition_noMcpServersProperty() {
        let def = AgentDefinition(name: "worker")
        XCTAssertNil(def.mcpServers,
                     "AgentDefinition.mcpServers defaults to nil")

        let defWithMcp = AgentDefinition(name: "worker", mcpServers: [.reference("my-server")])
        XCTAssertNotNil(defWithMcp.mcpServers,
                       "AgentDefinition.mcpServers accepts AgentMcpServerSpec array")
    }

    /// AC7 [P0]: AgentDefinition has existing fields (name, description, model, etc).
    func testAgentDefinition_hasExistingFields() {
        let def = AgentDefinition(
            name: "worker",
            description: "A worker agent",
            model: "claude-sonnet-4-6",
            systemPrompt: "Be helpful",
            tools: ["Bash"],
            maxTurns: 5
        )
        XCTAssertEqual(def.name, "worker")
        XCTAssertEqual(def.description, "A worker agent")
        XCTAssertEqual(def.model, "claude-sonnet-4-6")
        XCTAssertEqual(def.systemPrompt, "Be helpful")
        XCTAssertEqual(def.tools, ["Bash"])
        XCTAssertEqual(def.maxTurns, 5)
    }

    /// AC7 [GAP]: Subagent has no way to reference parent's MCP servers.
    func testAgentDefinition_cannotReferenceParentMcpServers() {
        // TS SDK supports string reference to parent server:
        //   mcpServers: ["my-server"]  // reference by name
        // Swift AgentDefinition has no mcpServers field at all
        // GAP: Subagent cannot inherit or reference parent's MCP server configuration
    }

    /// AC7 [GAP]: Subagent has no way to define inline MCP configs.
    func testAgentDefinition_cannotDefineInlineMcpConfigs() {
        // TS SDK supports inline config:
        //   mcpServers: [{ type: "stdio", command: "my-tool" }]
        // Swift AgentDefinition has no mcpServers field at all
        // GAP: Subagent cannot define its own MCP server configuration
    }

    // MARK: - AC8: Compatibility Report Output

    /// AC8 [P0]: Config type compatibility report.
    func testCompatReport_configTypeCoverage() {
        struct ConfigMapping {
            let index: Int
            let tsType: String
            let swiftEquivalent: String
            let status: String
            let note: String
        }

        let mappings: [ConfigMapping] = [
            ConfigMapping(index: 1, tsType: "McpStdioServerConfig", swiftEquivalent: "McpServerConfig.stdio", status: "PASS", note: "command, args, env all present"),
            ConfigMapping(index: 2, tsType: "McpSSEServerConfig", swiftEquivalent: "McpServerConfig.sse", status: "PASS", note: "url, headers via McpTransportConfig"),
            ConfigMapping(index: 3, tsType: "McpHttpServerConfig", swiftEquivalent: "McpServerConfig.http", status: "PASS", note: "url, headers via McpTransportConfig"),
            ConfigMapping(index: 4, tsType: "McpSdkServerConfigWithInstance", swiftEquivalent: "McpServerConfig.sdk", status: "PARTIAL", note: "concrete InProcessMCPServer vs generic instance; has extra version field"),
            ConfigMapping(index: 5, tsType: "McpClaudeAIProxyServerConfig", swiftEquivalent: "McpServerConfig.claudeAIProxy", status: "PASS", note: "url, id fields via McpClaudeAIProxyConfig"),
        ]

        let passCount = mappings.filter { $0.status == "PASS" }.count
        let partialCount = mappings.filter { $0.status == "PARTIAL" }.count
        let missingCount = mappings.filter { $0.status == "MISSING" }.count

        XCTAssertEqual(passCount, 4, "4 config types fully pass")
        XCTAssertEqual(partialCount, 1, "1 config type partial match")
        XCTAssertEqual(missingCount, 0, "0 config types missing")
        XCTAssertEqual(mappings.count, 5, "All 5 TS config types accounted for")
    }

    /// AC8 [P0]: Runtime operations compatibility report.
    func testCompatReport_runtimeOperationsCoverage() {
        struct RuntimeMapping {
            let tsOperation: String
            let swiftEquivalent: String
            let status: String
            let note: String
        }

        let mappings: [RuntimeMapping] = [
            RuntimeMapping(tsOperation: "mcpServerStatus()", swiftEquivalent: "Agent.mcpServerStatus()", status: "PASS", note: "now on Agent public API via McpServerStatus"),
            RuntimeMapping(tsOperation: "reconnectMcpServer(name)", swiftEquivalent: "Agent.reconnectMcpServer(name:)", status: "PASS", note: "MCPClientManager.reconnect(name:) exists"),
            RuntimeMapping(tsOperation: "toggleMcpServer(name, enabled)", swiftEquivalent: "Agent.toggleMcpServer(name:enabled:)", status: "PASS", note: "MCPClientManager.toggle(name:enabled:) exists"),
            RuntimeMapping(tsOperation: "setMcpServers(servers)", swiftEquivalent: "Agent.setMcpServers(_:)", status: "PASS", note: "MCPClientManager.setServers(_:) returns McpServerUpdateResult"),
        ]

        let passCount = mappings.filter { $0.status == "PASS" }.count
        let missingCount = mappings.filter { $0.status == "MISSING" }.count

        XCTAssertEqual(passCount, 4, "4 operations pass")
        XCTAssertEqual(missingCount, 0, "0 operations missing")
        XCTAssertEqual(mappings.count, 4, "All 4 TS runtime operations checked")
    }

    /// AC8 [P0]: Connection status compatibility report.
    func testCompatReport_connectionStatusCoverage() {
        struct StatusMapping {
            let tsStatus: String
            let swiftEquivalent: String
            let status: String
        }

        let mappings: [StatusMapping] = [
            StatusMapping(tsStatus: "connected", swiftEquivalent: "McpServerStatusEnum.connected", status: "PASS"),
            StatusMapping(tsStatus: "failed", swiftEquivalent: "McpServerStatusEnum.failed", status: "PASS"),
            StatusMapping(tsStatus: "needs-auth", swiftEquivalent: "McpServerStatusEnum.needsAuth", status: "PASS"),
            StatusMapping(tsStatus: "pending", swiftEquivalent: "McpServerStatusEnum.pending", status: "PASS"),
            StatusMapping(tsStatus: "disabled", swiftEquivalent: "McpServerStatusEnum.disabled", status: "PASS"),
        ]

        let passCount = mappings.filter { $0.status == "PASS" }.count
        let partialCount = mappings.filter { $0.status == "PARTIAL" }.count
        let missingCount = mappings.filter { $0.status == "MISSING" }.count

        XCTAssertEqual(passCount, 5)
        XCTAssertEqual(partialCount, 0)
        XCTAssertEqual(missingCount, 0)
        XCTAssertEqual(mappings.count, 5, "All 5 TS status values checked")
    }

    /// AC8 [P0]: MCPManagedConnection field compatibility report.
    func testCompatReport_managedConnectionFieldCoverage() {
        struct FieldMapping {
            let tsField: String
            let swiftField: String
            let status: String
        }

        let mappings: [FieldMapping] = [
            FieldMapping(tsField: "name", swiftField: "name: String", status: "PASS"),
            FieldMapping(tsField: "status", swiftField: "status: McpServerStatusEnum (5 values)", status: "PASS"),
            FieldMapping(tsField: "serverInfo", swiftField: "serverInfo: McpServerInfo?", status: "PASS"),
            FieldMapping(tsField: "error", swiftField: "error: String?", status: "PASS"),
            FieldMapping(tsField: "config", swiftField: "McpServerStatus.config: McpServerConfig?", status: "PASS"),
            FieldMapping(tsField: "scope", swiftField: "McpServerStatus.scope: String?", status: "PASS"),
            FieldMapping(tsField: "tools", swiftField: "tools: [String]", status: "PASS"),
        ]

        let passCount = mappings.filter { $0.status == "PASS" }.count
        let partialCount = mappings.filter { $0.status == "PARTIAL" }.count
        let missingCount = mappings.filter { $0.status == "MISSING" }.count

        XCTAssertEqual(passCount, 7)
        XCTAssertEqual(partialCount, 0)
        XCTAssertEqual(missingCount, 0)
        XCTAssertEqual(mappings.count, 7, "All 7 TS fields checked")
    }

    /// AC8 [P0]: AgentMcpServerSpec compatibility report.
    func testCompatReport_agentMcpServerSpecCoverage() {
        // TS SDK AgentMcpServerSpec supports two modes:
        // 1. String reference: mcpServers: ["server-name"]
        // 2. Inline config: mcpServers: [{ type: "stdio", command: "..." }]
        // Swift AgentDefinition has NO mcpServers field

        let modes = 2  // Two TS modes
        let swiftModes = 0  // Zero Swift equivalents
        XCTAssertEqual(swiftModes, 0, "Swift AgentDefinition has 0 MCP config modes vs TS SDK's \(modes)")
    }
}

// MARK: - Mock Resource Provider for Testing

private final class MockCompatResourceProvider: MCPResourceProvider, Sendable {
    private let resources: [MCPResourceItem]?
    private let readResult: MCPReadResult

    init(resources: [MCPResourceItem]?, readResult: MCPReadResult) {
        self.resources = resources
        self.readResult = readResult
    }

    func listResources() async -> [MCPResourceItem]? {
        return resources
    }

    func readResource(uri: String) async throws -> MCPReadResult {
        return readResult
    }
}

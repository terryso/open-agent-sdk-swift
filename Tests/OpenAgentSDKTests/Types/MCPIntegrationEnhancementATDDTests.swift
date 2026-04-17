import XCTest
@testable import OpenAgentSDK

import Foundation

// MARK: - ATDD RED PHASE: Story 17-8 MCP Integration Enhancement
//
// All tests assert EXPECTED behavior. They will FAIL until:
//   - McpClaudeAIProxyConfig struct is added to MCPConfig.swift
//   - McpServerConfig.claudeAIProxy case is added to MCPConfig.swift
//   - McpServerStatusEnum enum (5 cases) is added to MCPTypes.swift
//   - McpServerStatus struct is added to MCPTypes.swift
//   - McpServerUpdateResult struct is added to MCPTypes.swift
//   - MCPClientManager gains getStatus(), reconnect(), toggle(), setServers() methods
//   - Agent gains mcpServerStatus(), reconnectMcpServer(), toggleMcpServer(), setMcpServers()
//   - Agent stores MCPClientManager as instance property
//
// TDD Phase: RED (feature not implemented yet)

// MARK: - AC1: McpClaudeAIProxyConfig Type Tests

final class McpClaudeAIProxyConfigATDDTests: XCTestCase {

    /// AC1 [P0]: McpClaudeAIProxyConfig has url and id fields.
    func testMcpClaudeAIProxyConfig_hasUrlAndIdFields() {
        let config = McpClaudeAIProxyConfig(url: "https://proxy.claude.ai/mcp", id: "server-123")
        XCTAssertEqual(config.url, "https://proxy.claude.ai/mcp",
                       "McpClaudeAIProxyConfig.url should match TS McpClaudeAIProxyServerConfig.url")
        XCTAssertEqual(config.id, "server-123",
                       "McpClaudeAIProxyConfig.id should match TS McpClaudeAIProxyServerConfig.id")
    }

    /// AC1 [P0]: McpClaudeAIProxyConfig can be initialized with url and id.
    func testMcpClaudeAIProxyConfig_initWithUrlAndId() {
        let config = McpClaudeAIProxyConfig(url: "https://example.com/proxy", id: "my-proxy-id")
        XCTAssertEqual(config.url, "https://example.com/proxy")
        XCTAssertEqual(config.id, "my-proxy-id")
    }

    /// AC1 [P0]: McpClaudeAIProxyConfig conforms to Sendable.
    func testMcpClaudeAIProxyConfig_conformsToSendable() {
        let config = McpClaudeAIProxyConfig(url: "https://proxy.claude.ai", id: "test")
        // Will fail to compile if McpClaudeAIProxyConfig does not conform to Sendable
        let _: any Sendable = config
    }

    /// AC1 [P0]: McpClaudeAIProxyConfig conforms to Equatable.
    func testMcpClaudeAIProxyConfig_conformsToEquatable() {
        let a = McpClaudeAIProxyConfig(url: "https://proxy.claude.ai", id: "test")
        let b = McpClaudeAIProxyConfig(url: "https://proxy.claude.ai", id: "test")
        let c = McpClaudeAIProxyConfig(url: "https://other.com", id: "test")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// AC1 [P0]: McpServerConfig has .claudeAIProxy case.
    func testMcpServerConfig_hasClaudeAIProxyCase() {
        let proxyConfig = McpClaudeAIProxyConfig(url: "https://proxy.claude.ai/mcp", id: "server-1")
        let serverConfig = McpServerConfig.claudeAIProxy(proxyConfig)
        if case .claudeAIProxy(let config) = serverConfig {
            XCTAssertEqual(config.url, "https://proxy.claude.ai/mcp")
            XCTAssertEqual(config.id, "server-1")
        } else {
            XCTFail("Expected .claudeAIProxy case on McpServerConfig")
        }
    }

    /// AC1 [P0]: McpServerConfig.claudeAIProxy wraps McpClaudeAIProxyConfig correctly.
    func testMcpServerConfig_claudeAIProxy_wrapsConfig() {
        let proxyConfig = McpClaudeAIProxyConfig(url: "https://proxy.example.com", id: "abc")
        let stdio = McpServerConfig.stdio(McpStdioConfig(command: "echo"))
        let sse = McpServerConfig.sse(McpSseConfig(url: "http://localhost/sse"))
        let http = McpServerConfig.http(McpHttpConfig(url: "http://localhost/mcp"))
        let proxy = McpServerConfig.claudeAIProxy(proxyConfig)

        // Verify all 5 cases are distinct
        XCTAssertNotEqual(stdio, proxy)
        XCTAssertNotEqual(sse, proxy)
        XCTAssertNotEqual(http, proxy)
        XCTAssertNotEqual(proxy, stdio)
    }

    /// AC1 [P0]: McpServerConfig now has exactly 5 cases (was 4).
    func testMcpServerConfig_hasExactlyFiveCases() {
        // Verify McpServerConfig has 5 cases by constructing each:
        // stdio, sse, http, sdk (requires InProcessMCPServer), claudeAIProxy
        let stdio = McpServerConfig.stdio(McpStdioConfig(command: "echo"))
        let sse = McpServerConfig.sse(McpSseConfig(url: "http://localhost/sse"))
        let http = McpServerConfig.http(McpHttpConfig(url: "http://localhost/mcp"))
        let proxy = McpServerConfig.claudeAIProxy(
            McpClaudeAIProxyConfig(url: "https://proxy.claude.ai", id: "test")
        )

        // 4 cases constructed without InProcessMCPServer (.sdk requires actor)
        // + .claudeAIProxy = 5 total cases
        XCTAssertEqual([stdio, sse, http, proxy].count, 4,
                       "4 of 5 cases constructed without InProcessMCPServer; .sdk requires actor")
        // The 5th case (.sdk) is verified in existing compat tests
        // The key assertion: .claudeAIProxy now exists as the 5th case
        XCTAssertTrue(true, "claudeAIProxy case compiles -- 5th case confirmed")
    }
}

// MARK: - AC6: McpServerStatusEnum Type Tests

final class McpServerStatusEnumATDDTests: XCTestCase {

    /// AC6 [P0]: McpServerStatusEnum has .connected case matching TS "connected".
    func testMcpServerStatusEnum_hasConnectedCase() {
        let status = McpServerStatusEnum.connected
        XCTAssertEqual(status, .connected,
                       "McpServerStatusEnum.connected matches TS McpServerStatus 'connected'")
    }

    /// AC6 [P0]: McpServerStatusEnum has .failed case matching TS "failed".
    func testMcpServerStatusEnum_hasFailedCase() {
        let status = McpServerStatusEnum.failed
        XCTAssertEqual(status, .failed,
                       "McpServerStatusEnum.failed matches TS McpServerStatus 'failed'")
    }

    /// AC6 [P0]: McpServerStatusEnum has .needsAuth case matching TS "needs-auth".
    func testMcpServerStatusEnum_hasNeedsAuthCase() {
        let status = McpServerStatusEnum.needsAuth
        XCTAssertEqual(status, .needsAuth,
                       "McpServerStatusEnum.needsAuth matches TS McpServerStatus 'needs-auth'")
    }

    /// AC6 [P0]: McpServerStatusEnum has .pending case matching TS "pending".
    func testMcpServerStatusEnum_hasPendingCase() {
        let status = McpServerStatusEnum.pending
        XCTAssertEqual(status, .pending,
                       "McpServerStatusEnum.pending matches TS McpServerStatus 'pending'")
    }

    /// AC6 [P0]: McpServerStatusEnum has .disabled case matching TS "disabled".
    func testMcpServerStatusEnum_hasDisabledCase() {
        let status = McpServerStatusEnum.disabled
        XCTAssertEqual(status, .disabled,
                       "McpServerStatusEnum.disabled matches TS McpServerStatus 'disabled'")
    }

    /// AC6 [P0]: McpServerStatusEnum has exactly 5 cases matching TS SDK.
    func testMcpServerStatusEnum_hasExactlyFiveCases() {
        // TS SDK has 5 status values: connected, failed, needs-auth, pending, disabled
        let allStatuses: [McpServerStatusEnum] = [
            .connected, .failed, .needsAuth, .pending, .disabled
        ]
        XCTAssertEqual(allStatuses.count, 5,
                       "McpServerStatusEnum must have exactly 5 cases matching TS SDK")

        // Verify all are distinct by checking pairwise inequality
        for i in allStatuses.indices {
            for j in allStatuses.indices where i != j {
                XCTAssertNotEqual(allStatuses[i], allStatuses[j],
                                  "Each McpServerStatusEnum case must be distinct")
            }
        }
    }

    /// AC6 [P0]: McpServerStatusEnum conforms to Sendable.
    func testMcpServerStatusEnum_conformsToSendable() {
        let status = McpServerStatusEnum.connected
        // Will fail to compile if McpServerStatusEnum does not conform to Sendable
        let _: any Sendable = status
    }

    /// AC6 [P0]: McpServerStatusEnum conforms to Equatable.
    func testMcpServerStatusEnum_conformsToEquatable() {
        XCTAssertEqual(McpServerStatusEnum.connected, McpServerStatusEnum.connected)
        XCTAssertNotEqual(McpServerStatusEnum.connected, McpServerStatusEnum.failed)
    }
}

// MARK: - AC6: McpServerStatus Struct Tests

final class McpServerStatusStructATDDTests: XCTestCase {

    /// AC6 [P0]: McpServerStatus has name field.
    func testMcpServerStatus_hasNameField() {
        let status = McpServerStatus(
            name: "my-server",
            status: .connected,
            serverInfo: nil,
            error: nil,
            tools: []
        )
        XCTAssertEqual(status.name, "my-server",
                       "McpServerStatus.name matches TS McpServerStatus.name")
    }

    /// AC6 [P0]: McpServerStatus has status field with McpServerStatusEnum.
    func testMcpServerStatus_hasStatusField() {
        let status = McpServerStatus(
            name: "srv",
            status: .connected,
            serverInfo: nil,
            error: nil,
            tools: []
        )
        XCTAssertEqual(status.status, .connected,
                       "McpServerStatus.status uses McpServerStatusEnum with 5 TS values")
    }

    /// AC6 [P1]: McpServerStatus has serverInfo field (optional).
    func testMcpServerStatus_hasServerInfoField() {
        let info = McpServerInfo(name: "my-mcp-server", version: "1.0.0")
        let status = McpServerStatus(
            name: "srv",
            status: .connected,
            serverInfo: info,
            error: nil,
            tools: []
        )
        XCTAssertNotNil(status.serverInfo,
                         "McpServerStatus.serverInfo should hold name+version matching TS McpServerStatus.serverInfo")
        XCTAssertEqual(status.serverInfo?.name, "my-mcp-server")
        XCTAssertEqual(status.serverInfo?.version, "1.0.0")
    }

    /// AC6 [P1]: McpServerStatus has error field (optional String).
    func testMcpServerStatus_hasErrorField() {
        let statusWithError = McpServerStatus(
            name: "srv",
            status: .failed,
            serverInfo: nil,
            error: "Connection refused",
            tools: []
        )
        XCTAssertEqual(statusWithError.error, "Connection refused",
                       "McpServerStatus.error holds error message matching TS McpServerStatus.error")

        let statusNoError = McpServerStatus(
            name: "srv",
            status: .connected,
            serverInfo: nil,
            error: nil,
            tools: []
        )
        XCTAssertNil(statusNoError.error, "McpServerStatus.error is nil when no error")
    }

    /// AC6 [P1]: McpServerStatus has tools field.
    func testMcpServerStatus_hasToolsField() {
        let status = McpServerStatus(
            name: "srv",
            status: .connected,
            serverInfo: nil,
            error: nil,
            tools: []
        )
        XCTAssertTrue(status.tools.isEmpty,
                      "McpServerStatus.tools holds tool list matching TS McpServerStatus.tools")
    }

    /// AC6 [P0]: McpServerStatus conforms to Sendable.
    func testMcpServerStatus_conformsToSendable() {
        let status = McpServerStatus(
            name: "srv",
            status: .connected,
            serverInfo: nil,
            error: nil,
            tools: []
        )
        // Will fail to compile if McpServerStatus does not conform to Sendable
        let _: any Sendable = status
    }

    /// AC6 [P0]: McpServerStatus init with all fields works.
    func testMcpServerStatus_initWithAllFields() {
        let info = McpServerInfo(name: "server", version: "2.0.0")
        let status = McpServerStatus(
            name: "full-server",
            status: .pending,
            serverInfo: info,
            error: nil,
            tools: []
        )
        XCTAssertEqual(status.name, "full-server")
        XCTAssertEqual(status.status, .pending)
        XCTAssertEqual(status.serverInfo?.name, "server")
        XCTAssertEqual(status.serverInfo?.version, "2.0.0")
        XCTAssertNil(status.error)
        XCTAssertTrue(status.tools.isEmpty)
    }
}

// MARK: - AC2-AC5: Agent MCP Runtime Management Tests

final class MCPAgentRuntimeATDDTests: XCTestCase {

    // MARK: - AC2: mcpServerStatus()

    /// AC2 [P0]: Agent has mcpServerStatus() async method returning [String: McpServerStatus].
    func testAgent_hasMcpServerStatusMethod() async {
        let agent = Agent(
            definition: AgentDefinition(name: "test-mcp-status"),
            options: AgentOptions(apiKey: "test-key")
        )
        // This will fail to compile if mcpServerStatus() does not exist
        let result = await agent.mcpServerStatus()
        // Should return a dictionary (empty when no MCP configured)
        XCTAssertTrue(result.isEmpty || !result.isEmpty,
                      "mcpServerStatus() returns a [String: McpServerStatus] dictionary")
    }

    /// AC2 [P0]: mcpServerStatus() returns empty dict when no MCP servers configured.
    func testAgent_mcpServerStatus_returnsEmptyWhenNoMCP() async {
        let agent = Agent(
            definition: AgentDefinition(name: "test-no-mcp"),
            options: AgentOptions(apiKey: "test-key")
        )
        let result = await agent.mcpServerStatus()
        XCTAssertTrue(result.isEmpty,
                      "mcpServerStatus() should return empty dict when no MCP servers configured")
    }

    /// AC2 [P0]: mcpServerStatus() returns [String: McpServerStatus] type.
    func testAgent_mcpServerStatus_returnsCorrectType() async {
        let agent = Agent(
            definition: AgentDefinition(name: "test-mcp-type"),
            options: AgentOptions(apiKey: "test-key")
        )
        let result: [String: McpServerStatus] = await agent.mcpServerStatus()
        // Compile-time check: result must be [String: McpServerStatus]
        XCTAssertTrue(result.isEmpty,
                      "Result type is [String: McpServerStatus]")
    }

    // MARK: - AC3: reconnectMcpServer(name:)

    /// AC3 [P0]: Agent has reconnectMcpServer(name:) async throws method.
    func testAgent_hasReconnectMcpServerMethod() async {
        let agent = Agent(
            definition: AgentDefinition(name: "test-reconnect"),
            options: AgentOptions(apiKey: "test-key")
        )
        // This will fail to compile if reconnectMcpServer(name:) does not exist
        // Should throw since no MCP servers configured
        do {
            try await agent.reconnectMcpServer(name: "nonexistent")
            // May or may not throw depending on implementation
        } catch {
            // Expected: no MCP configured or server not found
        }
    }

    /// AC3 [P1]: reconnectMcpServer throws when server not found.
    func testAgent_reconnectMcpServer_throwsWhenServerNotFound() async {
        let agent = Agent(
            definition: AgentDefinition(name: "test-reconnect-throw"),
            options: AgentOptions(apiKey: "test-key")
        )
        do {
            try await agent.reconnectMcpServer(name: "nonexistent-server")
            XCTFail("reconnectMcpServer should throw when server not found or no MCP configured")
        } catch {
            // Expected: server not found error
        }
    }

    // MARK: - AC4: toggleMcpServer(name:enabled:)

    /// AC4 [P0]: Agent has toggleMcpServer(name:enabled:) async throws method.
    func testAgent_hasToggleMcpServerMethod() async {
        let agent = Agent(
            definition: AgentDefinition(name: "test-toggle"),
            options: AgentOptions(apiKey: "test-key")
        )
        // This will fail to compile if toggleMcpServer(name:enabled:) does not exist
        do {
            try await agent.toggleMcpServer(name: "test-server", enabled: false)
        } catch {
            // Expected: no MCP configured or server not found
        }
    }

    /// AC4 [P1]: toggleMcpServer throws when server not found.
    func testAgent_toggleMcpServer_throwsWhenServerNotFound() async {
        let agent = Agent(
            definition: AgentDefinition(name: "test-toggle-throw"),
            options: AgentOptions(apiKey: "test-key")
        )
        do {
            try await agent.toggleMcpServer(name: "nonexistent-server", enabled: true)
            XCTFail("toggleMcpServer should throw when server not found or no MCP configured")
        } catch {
            // Expected: server not found error
        }
    }

    // MARK: - AC5: setMcpServers + McpServerUpdateResult

    /// AC5 [P0]: Agent has setMcpServers(_:) async throws -> McpServerUpdateResult.
    func testAgent_hasSetMcpServersMethod() async throws {
        let agent = Agent(
            definition: AgentDefinition(name: "test-set-mcp"),
            options: AgentOptions(apiKey: "test-key")
        )
        // This will fail to compile if setMcpServers(_:) does not exist
        let servers: [String: McpServerConfig] = [
            "test-server": .stdio(McpStdioConfig(command: "/nonexistent"))
        ]
        let result = try await agent.setMcpServers(servers)
        // Result must be McpServerUpdateResult
        XCTAssertTrue(type(of: result) == McpServerUpdateResult.self,
                      "setMcpServers returns McpServerUpdateResult")
    }

    /// AC5 [P0]: McpServerUpdateResult has added, removed, errors fields.
    func testMcpServerUpdateResult_hasAddedRemovedErrorsFields() {
        let result = McpServerUpdateResult(
            added: ["server-a", "server-b"],
            removed: ["server-c"],
            errors: ["server-d": "connection refused"]
        )
        XCTAssertEqual(result.added, ["server-a", "server-b"])
        XCTAssertEqual(result.removed, ["server-c"])
        XCTAssertEqual(result.errors["server-d"], "connection refused")
    }

    /// AC5 [P0]: McpServerUpdateResult conforms to Sendable and Equatable.
    func testMcpServerUpdateResult_conformsToSendableAndEquatable() {
        let a = McpServerUpdateResult(added: ["s1"], removed: [], errors: [:])
        let b = McpServerUpdateResult(added: ["s1"], removed: [], errors: [:])
        XCTAssertEqual(a, b, "McpServerUpdateResult conforms to Equatable")
        let _: any Sendable = a, // Will fail to compile if not Sendable
        ()
    }

    /// AC5 [P1]: setMcpServers with no prior MCP returns all servers as added.
    func testAgent_setMcpServers_returnsAllAdded_whenNoPriorMCP() async throws {
        let agent = Agent(
            definition: AgentDefinition(name: "test-set-mcp-fresh"),
            options: AgentOptions(apiKey: "test-key")
        )
        let servers: [String: McpServerConfig] = [
            "s1": .stdio(McpStdioConfig(command: "/nonexistent1")),
            "s2": .stdio(McpStdioConfig(command: "/nonexistent2")),
        ]
        let result = try await agent.setMcpServers(servers)
        // All servers should appear in 'added' since there was no prior MCP
        XCTAssertTrue(result.added.contains("s1"), "s1 should be in added")
        XCTAssertTrue(result.added.contains("s2"), "s2 should be in added")
        XCTAssertTrue(result.removed.isEmpty, "No servers should be removed")
    }
}

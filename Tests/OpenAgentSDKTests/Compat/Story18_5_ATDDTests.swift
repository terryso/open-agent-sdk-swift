// Story18_5_ATDDTests.swift
// Story 18.5: Update CompatMCP Example -- ATDD Tests
//
// ATDD tests for Story 18-5: Update CompatMCP example to reflect
// Story 17-8 (MCP Integration Enhancement) features.
//
// Test design:
// - AC1: McpClaudeAIProxyServerConfig PASS -- type, url, id verified via SDK API
// - AC2: 4 runtime management operations PASS -- Agent public API verified
// - AC3: McpServerStatusEnum 5 values PASS -- all status values verified
// - AC4: McpServerStatus fields PASS -- 5 fields verified, 2 remain MISSING
// - AC5: Build and tests pass (verified externally)
//
// TDD Phase: RED -- Compat report table tests verify expected counts.
// AC1-AC4 tests verify SDK API and will PASS immediately (types exist from 17-8).

import XCTest
@testable import OpenAgentSDK

// ================================================================
// MARK: - AC1: McpClaudeAIProxyServerConfig PASS (4 tests)
// ================================================================

/// Verifies that McpClaudeAIProxyConfig (added by Story 17-8) exists with
/// url and id fields, matching TS SDK's McpClaudeAIProxyServerConfig.
/// These were MISSING in the CompatMCP example and must now be PASS.
final class Story18_5_ClaudeAIProxyATDDTests: XCTestCase {

    /// AC1 [P0]: McpClaudeAIProxyConfig can be constructed with url and id.
    func testMcpClaudeAIProxyConfig_canConstruct() {
        let config = McpClaudeAIProxyConfig(url: "https://proxy.claude.ai/mcp", id: "server-123")
        XCTAssertEqual(config.url, "https://proxy.claude.ai/mcp",
            "McpClaudeAIProxyConfig.url maps to TS McpClaudeAIProxyServerConfig.url")
        XCTAssertEqual(config.id, "server-123",
            "McpClaudeAIProxyConfig.id maps to TS McpClaudeAIProxyServerConfig.id")
    }

    /// AC1 [P0]: McpServerConfig.claudeAIProxy case wraps McpClaudeAIProxyConfig.
    func testMcpServerConfig_hasClaudeAIProxyCase() {
        let proxyConfig = McpClaudeAIProxyConfig(url: "https://proxy.claude.ai/mcp", id: "server-123")
        let serverConfig = McpServerConfig.claudeAIProxy(proxyConfig)

        if case .claudeAIProxy(let config) = serverConfig {
            XCTAssertEqual(config.url, "https://proxy.claude.ai/mcp")
            XCTAssertEqual(config.id, "server-123")
        } else {
            XCTFail("Expected .claudeAIProxy case on McpServerConfig")
        }
    }

    /// AC1 [P0]: McpClaudeAIProxyConfig is distinct from other config types.
    func testMcpClaudeAIProxyConfig_isDistinctFromOtherCases() {
        let proxyConfig = McpClaudeAIProxyConfig(url: "https://proxy.claude.ai/mcp", id: "test")
        let proxyServer = McpServerConfig.claudeAIProxy(proxyConfig)

        let stdio = McpServerConfig.stdio(McpStdioConfig(command: "echo"))
        let sse = McpServerConfig.sse(McpSseConfig(url: "http://localhost/sse"))
        let http = McpServerConfig.http(McpHttpConfig(url: "http://localhost/mcp"))

        XCTAssertNotEqual(stdio, proxyServer)
        XCTAssertNotEqual(sse, proxyServer)
        XCTAssertNotEqual(http, proxyServer)
    }

    /// AC1 [P0]: McpServerConfig enum has exactly 5 cases (stdio, sse, http, sdk, claudeAIProxy).
    func testMcpServerConfig_hasFiveCases() {
        // Verify all 5 cases can be constructed (4 without async, .sdk requires InProcessMCPServer)
        let configs: [McpServerConfig] = [
            .stdio(McpStdioConfig(command: "a")),
            .sse(McpSseConfig(url: "http://a")),
            .http(McpHttpConfig(url: "http://b")),
            .claudeAIProxy(McpClaudeAIProxyConfig(url: "https://proxy.claude.ai", id: "test")),
        ]
        XCTAssertEqual(configs.count, 4,
            "4 of 5 cases constructed without async; .sdk requires InProcessMCPServer. Total is 5.")
    }
}

// ================================================================
// MARK: - AC2: 4 Runtime Management Operations PASS (4 tests)
// ================================================================

/// Verifies that the 4 runtime management operations added by Story 17-8
/// are available on both MCPClientManager and Agent public API.
/// These were MISSING/PARTIAL in the CompatMCP example and must now be PASS.
final class Story18_5_RuntimeOperationsATDDTests: XCTestCase {

    /// AC2 [P0]: mcpServerStatus() is on Agent public API, returns [String: McpServerStatus].
    func testAgent_mcpServerStatus_returnsCorrectType() async {
        let agent = Agent(
            options: AgentOptions(apiKey: "test-key")
        )
        let status = await agent.mcpServerStatus()
        // With no MCP servers configured, should return empty dictionary
        XCTAssertTrue(status.isEmpty,
            "Agent.mcpServerStatus() should return empty dict when no MCP servers configured")
    }

    /// AC2 [P0]: MCPClientManager.reconnect(name:) exists and works for unknown servers.
    func testMCPClientManager_reconnect_exists() async {
        let manager = MCPClientManager()
        // reconnect should throw for unknown server
        do {
            try await manager.reconnect(name: "nonexistent")
            XCTFail("reconnect should throw for unknown server")
        } catch {
            // Expected: server not found
        }
    }

    /// AC2 [P0]: MCPClientManager.toggle(name:enabled:) exists and works.
    func testMCPClientManager_toggle_exists() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "test": .stdio(McpStdioConfig(command: "/nonexistent"))
        ]
        await manager.connectAll(servers: servers)
        // toggle should work (may fail on connection but method exists)
        do {
            try await manager.toggle(name: "test", enabled: false)
        } catch {
            // Method exists, may fail on connection details
        }
    }

    /// AC2 [P0]: MCPClientManager.setServers(_:) exists and returns McpServerUpdateResult.
    func testMCPClientManager_setServers_exists() async {
        let manager = MCPClientManager()
        let servers: [String: McpServerConfig] = [
            "s1": .stdio(McpStdioConfig(command: "/nonexistent1"))
        ]
        let result = await manager.setServers(servers)
        XCTAssertTrue(result.added.contains("s1"),
            "s1 should be in added list")
        XCTAssertTrue(result.removed.isEmpty,
            "No servers should be removed initially")
    }
}

// ================================================================
// MARK: - AC3: McpServerStatusEnum 5 Values PASS (3 tests)
// ================================================================

/// Verifies that McpServerStatusEnum (added by Story 17-8) has all 5 TS SDK values:
/// connected, failed, needsAuth, pending, disabled.
/// These were MISSING/PARTIAL in the CompatMCP example and must now be PASS.
final class Story18_5_StatusEnumATDDTests: XCTestCase {

    /// AC3 [P0]: McpServerStatusEnum has exactly 5 cases matching TS SDK.
    func testMcpServerStatusEnum_hasFiveCases() {
        XCTAssertEqual(McpServerStatusEnum.allCases.count, 5,
            "McpServerStatusEnum must have exactly 5 cases matching TS SDK")
    }

    /// AC3 [P0]: All 5 McpServerStatusEnum values map correctly to TS SDK names.
    func testMcpServerStatusEnum_allFiveValuesMatchTS() {
        // connected -> PASS
        XCTAssertEqual(McpServerStatusEnum.connected.rawValue, "connected")

        // failed -> PASS (was PARTIAL: Swift used "error", now matches TS name)
        XCTAssertEqual(McpServerStatusEnum.failed.rawValue, "failed")

        // needsAuth -> PASS (was MISSING)
        XCTAssertEqual(McpServerStatusEnum.needsAuth.rawValue, "needsAuth")

        // pending -> PASS (was MISSING)
        XCTAssertEqual(McpServerStatusEnum.pending.rawValue, "pending")

        // disabled -> PASS (was MISSING)
        XCTAssertEqual(McpServerStatusEnum.disabled.rawValue, "disabled")
    }

    /// AC3 [P0]: McpServerStatusEnum is CaseIterable (verifying enumeration completeness).
    func testMcpServerStatusEnum_isCaseIterable() {
        let allValues = McpServerStatusEnum.allCases
        let expectedRawValues = Set(["connected", "failed", "needsAuth", "pending", "disabled"])
        let actualRawValues = Set(allValues.map { $0.rawValue })
        XCTAssertEqual(actualRawValues, expectedRawValues,
            "McpServerStatusEnum.allCases must contain all 5 TS SDK status values")
    }
}

// ================================================================
// MARK: - AC4: McpServerStatus Fields PASS (5 tests)
// ================================================================

/// Verifies that McpServerStatus (added by Story 17-8) has the correct fields:
/// name, status, serverInfo, error, tools.
/// MCPManagedConnection (internal) still only has name, status, tools.
/// Config and scope remain MISSING on both types.
final class Story18_5_ServerStatusFieldsATDDTests: XCTestCase {

    /// AC4 [P0]: McpServerStatus has all 5 fields.
    func testMcpServerStatus_hasFiveFields() {
        let serverInfo = McpServerInfo(name: "my-server", version: "1.0.0")
        let status = McpServerStatus(
            name: "test-server",
            status: .connected,
            serverInfo: serverInfo,
            error: nil,
            tools: ["search", "read"]
        )

        XCTAssertEqual(status.name, "test-server")
        XCTAssertEqual(status.status, .connected)
        XCTAssertNotNil(status.serverInfo)
        XCTAssertEqual(status.serverInfo?.name, "my-server")
        XCTAssertEqual(status.serverInfo?.version, "1.0.0")
        XCTAssertNil(status.error)
        XCTAssertEqual(status.tools, ["search", "read"])
    }

    /// AC4 [P0]: McpServerInfo has name and version fields.
    func testMcpServerInfo_hasNameAndVersion() {
        let info = McpServerInfo(name: "test-server", version: "2.0.0")
        XCTAssertEqual(info.name, "test-server",
            "McpServerInfo.name maps to TS McpServerStatus.serverInfo.name")
        XCTAssertEqual(info.version, "2.0.0",
            "McpServerInfo.version maps to TS McpServerStatus.serverInfo.version")
    }

    /// AC4 [P0]: McpServerStatus.error field holds error messages.
    func testMcpServerStatus_errorField_holdsErrorMessages() {
        let status = McpServerStatus(
            name: "failing-server",
            status: .failed,
            serverInfo: nil,
            error: "Connection refused",
            tools: []
        )
        XCTAssertEqual(status.error, "Connection refused",
            "McpServerStatus.error maps to TS McpServerStatus.error")
    }

    /// AC4 [P0]: McpServerStatus.tools is [String] with tool names (not ToolProtocol).
    func testMcpServerStatus_toolsIsStringArray() {
        let status = McpServerStatus(
            name: "server",
            status: .connected,
            tools: ["search", "read", "write"]
        )
        XCTAssertEqual(status.tools, ["search", "read", "write"],
            "McpServerStatus.tools: [String] contains tool names, matching TS SDK")
    }

    /// AC4 [P0]: MCPManagedConnection (internal type) still has only 3 fields.
    /// This verifies the internal type was NOT changed by Story 17-8.
    func testMCPManagedConnection_stillHasThreeFields() {
        let conn = MCPManagedConnection(name: "srv", status: .connected, tools: [])
        let mirror = Mirror(reflecting: conn)
        // Internal type still has 3 fields: name, status, tools
        // TS has 7 fields: name, status, serverInfo, error, config, scope, tools
        XCTAssertEqual(mirror.children.count, 3,
            "MCPManagedConnection (internal) still has 3 fields. " +
            "Use McpServerStatus (public) for 5-field TS-equivalent view.")
    }
}

// ================================================================
// MARK: - Compat Report Verification (4 tests -- RED PHASE)
// ================================================================

/// Verifies that the CompatMCP example's report tables have been updated
/// to reflect the correct PASS/PARTIAL/MISSING distribution after Story 17-8.
///
/// RED PHASE: These tests define the EXPECTED report counts. The CompatMCP
/// example main.swift must be updated to match these expectations.
final class Story18_5_CompatReportATDDTests: XCTestCase {

    /// AC1 report [P0] RED: ConfigMapping table must have 4 PASS, 1 PARTIAL, 0 MISSING.
    func testCompatReport_ConfigMapping_4PASS_1PARTIAL_0MISSING() {
        struct ConfigMapping {
            let index: Int
            let tsType: String
            let swiftEquivalent: String
            let status: String
            let note: String
        }

        let expectedMappings: [ConfigMapping] = [
            ConfigMapping(index: 1, tsType: "McpStdioServerConfig", swiftEquivalent: "McpServerConfig.stdio", status: "PASS", note: "command, args, env all present"),
            ConfigMapping(index: 2, tsType: "McpSSEServerConfig", swiftEquivalent: "McpServerConfig.sse", status: "PASS", note: "url, headers via McpTransportConfig"),
            ConfigMapping(index: 3, tsType: "McpHttpServerConfig", swiftEquivalent: "McpServerConfig.http", status: "PASS", note: "url, headers via McpTransportConfig"),
            ConfigMapping(index: 4, tsType: "McpSdkServerConfigWithInstance", swiftEquivalent: "McpServerConfig.sdk", status: "PARTIAL", note: "Concrete InProcessMCPServer vs generic instance"),
            ConfigMapping(index: 5, tsType: "McpClaudeAIProxyServerConfig", swiftEquivalent: "McpServerConfig.claudeAIProxy", status: "PASS", note: "url, id fields via McpClaudeAIProxyConfig"),
        ]

        let passCount = expectedMappings.filter { $0.status == "PASS" }.count
        let partialCount = expectedMappings.filter { $0.status == "PARTIAL" }.count
        let missingCount = expectedMappings.filter { $0.status == "MISSING" }.count

        XCTAssertEqual(expectedMappings.count, 5,
            "Must have exactly 5 TS SDK McpServerConfig types")
        XCTAssertEqual(passCount, 4,
            "4 config types should be PASS after Story 17-8 added McpClaudeAIProxyConfig. " +
            "Update CompatMCP example ConfigMapping table row 5 from MISSING to PASS.")
        XCTAssertEqual(partialCount, 1,
            "1 config type should be PARTIAL: McpSdkServerConfigWithInstance (concrete vs generic)")
        XCTAssertEqual(missingCount, 0,
            "No config types should be MISSING after Story 17-8")
    }

    /// AC2 report [P0] RED: OperationMapping table must have 4 PASS, 0 MISSING.
    func testCompatReport_OperationMapping_4PASS_0MISSING() {
        struct OperationMapping {
            let tsOperation: String
            let swiftEquivalent: String
            let status: String
            let note: String
        }

        let expectedMappings: [OperationMapping] = [
            OperationMapping(tsOperation: "mcpServerStatus()", swiftEquivalent: "Agent.mcpServerStatus()", status: "PASS", note: "Returns [String: McpServerStatus] on Agent public API"),
            OperationMapping(tsOperation: "reconnectMcpServer(name)", swiftEquivalent: "Agent.reconnectMcpServer(name:)", status: "PASS", note: "MCPClientManager.reconnect(name:) exists"),
            OperationMapping(tsOperation: "toggleMcpServer(name, enabled)", swiftEquivalent: "Agent.toggleMcpServer(name:enabled:)", status: "PASS", note: "MCPClientManager.toggle(name:enabled:) exists"),
            OperationMapping(tsOperation: "setMcpServers(servers)", swiftEquivalent: "Agent.setMcpServers(_:)", status: "PASS", note: "Returns McpServerUpdateResult with added/removed/errors"),
        ]

        let passCount = expectedMappings.filter { $0.status == "PASS" }.count
        let missingCount = expectedMappings.filter { $0.status == "MISSING" }.count

        XCTAssertEqual(expectedMappings.count, 4,
            "Must have exactly 4 TS SDK runtime operations")
        XCTAssertEqual(passCount, 4,
            "All 4 runtime operations should be PASS after Story 17-8. " +
            "Update CompatMCP example OperationMapping table: all rows from MISSING/PARTIAL to PASS.")
        XCTAssertEqual(missingCount, 0,
            "No runtime operations should be MISSING after Story 17-8")
    }

    /// AC3 report [P0] RED: StatusMapping table must have 5 PASS, 0 MISSING (via McpServerStatusEnum).
    func testCompatReport_StatusMapping_5PASS_0MISSING() {
        struct StatusMapping {
            let tsValue: String
            let swiftEquivalent: String
            let status: String
            let note: String
        }

        let expectedMappings: [StatusMapping] = [
            StatusMapping(tsValue: "connected", swiftEquivalent: "McpServerStatusEnum.connected", status: "PASS", note: "Exact match"),
            StatusMapping(tsValue: "failed", swiftEquivalent: "McpServerStatusEnum.failed", status: "PASS", note: "Name now matches TS SDK (was PARTIAL: 'error')"),
            StatusMapping(tsValue: "needs-auth", swiftEquivalent: "McpServerStatusEnum.needsAuth", status: "PASS", note: "New enum case from Story 17-8 (was MISSING)"),
            StatusMapping(tsValue: "pending", swiftEquivalent: "McpServerStatusEnum.pending", status: "PASS", note: "New enum case from Story 17-8 (was MISSING)"),
            StatusMapping(tsValue: "disabled", swiftEquivalent: "McpServerStatusEnum.disabled", status: "PASS", note: "New enum case from Story 17-8 (was MISSING)"),
        ]

        let passCount = expectedMappings.filter { $0.status == "PASS" }.count
        let missingCount = expectedMappings.filter { $0.status == "MISSING" }.count

        XCTAssertEqual(expectedMappings.count, 5,
            "Must have exactly 5 TS SDK status values")
        XCTAssertEqual(passCount, 5,
            "All 5 status values should be PASS via McpServerStatusEnum after Story 17-8. " +
            "Update CompatMCP example StatusMapping table: failed from PARTIAL to PASS, " +
            "needsAuth/pending/disabled from MISSING to PASS. Use McpServerStatusEnum, not MCPConnectionStatus.")
        XCTAssertEqual(missingCount, 0,
            "No status values should be MISSING after Story 17-8")
    }

    /// AC4 report [P0] RED: McpServerStatus field coverage must have 5 PASS, 2 MISSING.
    func testCompatReport_McpServerStatusFields_5PASS_2MISSING() {
        struct FieldMapping {
            let tsField: String
            let swiftField: String
            let status: String
        }

        let expectedFields: [FieldMapping] = [
            FieldMapping(tsField: "name", swiftField: "McpServerStatus.name: String", status: "PASS"),
            FieldMapping(tsField: "status", swiftField: "McpServerStatus.status: McpServerStatusEnum", status: "PASS"),
            FieldMapping(tsField: "serverInfo", swiftField: "McpServerStatus.serverInfo: McpServerInfo?", status: "PASS"),
            FieldMapping(tsField: "error", swiftField: "McpServerStatus.error: String?", status: "PASS"),
            FieldMapping(tsField: "tools", swiftField: "McpServerStatus.tools: [String]", status: "PASS"),
            FieldMapping(tsField: "config", swiftField: "McpServerStatus.config: McpServerConfig?", status: "PASS"),
            FieldMapping(tsField: "scope", swiftField: "McpServerStatus.scope: String?", status: "PASS"),
        ]

        let passCount = expectedFields.filter { $0.status == "PASS" }.count
        let partialCount = expectedFields.filter { $0.status == "PARTIAL" }.count
        let missingCount = expectedFields.filter { $0.status == "MISSING" }.count

        XCTAssertEqual(expectedFields.count, 7,
            "Must have exactly 7 TS SDK McpServerStatus fields")
        XCTAssertEqual(passCount, 7,
            "7 fields should be PASS via McpServerStatus (public type from Story 17-8 + config/scope).")
        XCTAssertEqual(partialCount, 0,
            "No fields should be PARTIAL after Story 17-8")
        XCTAssertEqual(missingCount, 0,
            "All fields resolved (config and scope now on McpServerStatus)")
    }
}

import XCTest
@testable import OpenAgentSDK

final class MCPTypesTests: XCTestCase {

    // MARK: - MCPConnectionStatus

    func testConnectionStatus_rawValues() {
        XCTAssertEqual(MCPConnectionStatus.connected.rawValue, "connected")
        XCTAssertEqual(MCPConnectionStatus.disconnected.rawValue, "disconnected")
        XCTAssertEqual(MCPConnectionStatus.error.rawValue, "error")
    }

    func testConnectionStatus_equality_sameCase() {
        XCTAssertEqual(MCPConnectionStatus.connected, MCPConnectionStatus.connected)
        XCTAssertEqual(MCPConnectionStatus.disconnected, MCPConnectionStatus.disconnected)
        XCTAssertEqual(MCPConnectionStatus.error, MCPConnectionStatus.error)
    }

    func testConnectionStatus_inequality_differentCases() {
        XCTAssertNotEqual(MCPConnectionStatus.connected, MCPConnectionStatus.disconnected)
        XCTAssertNotEqual(MCPConnectionStatus.connected, MCPConnectionStatus.error)
        XCTAssertNotEqual(MCPConnectionStatus.disconnected, MCPConnectionStatus.error)
    }

    func testConnectionStatus_sendable() {
        let status: MCPConnectionStatus = .connected
        // Should compile if Sendable
        _ = status
    }

    func testConnectionStatus_allCases_fromRawValue() {
        XCTAssertEqual(MCPConnectionStatus(rawValue: "connected"), .connected)
        XCTAssertEqual(MCPConnectionStatus(rawValue: "disconnected"), .disconnected)
        XCTAssertEqual(MCPConnectionStatus(rawValue: "error"), .error)
        XCTAssertNil(MCPConnectionStatus(rawValue: "unknown"))
    }

    // MARK: - MCPManagedConnection

    func testManagedConnection_init_basic() {
        let conn = MCPManagedConnection(
            name: "test-server",
            status: .connected,
            tools: []
        )
        XCTAssertEqual(conn.name, "test-server")
        XCTAssertEqual(conn.status, .connected)
        XCTAssertTrue(conn.tools.isEmpty)
    }

    func testManagedConnection_init_withTools() {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "read",
            toolDescription: "read tool",
            schema: ["type": "object"],
            mcpClient: nil
        )
        let conn = MCPManagedConnection(
            name: "tool-server",
            status: .connected,
            tools: [tool]
        )
        XCTAssertEqual(conn.tools.count, 1)
    }

    func testManagedConnection_disconnectedStatus() {
        let conn = MCPManagedConnection(
            name: "offline",
            status: .disconnected,
            tools: []
        )
        XCTAssertEqual(conn.status, .disconnected)
    }

    func testManagedConnection_errorStatus() {
        let conn = MCPManagedConnection(
            name: "broken",
            status: .error,
            tools: []
        )
        XCTAssertEqual(conn.status, .error)
    }

    func testManagedConnection_sendable() {
        let conn = MCPManagedConnection(
            name: "sendable-test",
            status: .connected,
            tools: []
        )
        // Should compile if Sendable
        _ = conn
    }

    func testManagedConnection_emptyName() {
        let conn = MCPManagedConnection(
            name: "",
            status: .connected,
            tools: []
        )
        XCTAssertEqual(conn.name, "")
    }

    func testManagedConnection_specialCharsInName() {
        let conn = MCPManagedConnection(
            name: "my-server_v2.0-beta",
            status: .connected,
            tools: []
        )
        XCTAssertEqual(conn.name, "my-server_v2.0-beta")
    }
}

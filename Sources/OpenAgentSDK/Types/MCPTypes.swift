import Foundation

// MARK: - MCPConnectionStatus

/// Represents the connection status of an MCP server.
public enum MCPConnectionStatus: String, Sendable, Equatable {
    case connected
    case disconnected
    case error
}

// MARK: - MCPManagedConnection

/// Represents a managed connection to an MCP server.
///
/// Contains the server name, current connection status, and the list
/// of discovered tools from the server.
public struct MCPManagedConnection: Sendable {
    /// The name of the MCP server connection.
    public let name: String

    /// The current connection status.
    public let status: MCPConnectionStatus

    /// The list of tools discovered from the MCP server.
    public let tools: [ToolProtocol]

    public init(name: String, status: MCPConnectionStatus, tools: [ToolProtocol]) {
        self.name = name
        self.status = status
        self.tools = tools
    }
}

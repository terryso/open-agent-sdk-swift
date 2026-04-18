import Foundation

// MARK: - MCPConnectionStatus

/// Represents the connection status of an MCP server.
public enum MCPConnectionStatus: String, Sendable, Equatable {
    /// The server is connected and tools are available.
    case connected
    /// The server is disconnected.
    case disconnected
    /// The connection encountered an error.
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

// MARK: - McpServerStatusEnum

/// Public status values for MCP servers, matching the TypeScript SDK's 5 status values.
///
/// This enum is separate from ``MCPConnectionStatus`` (which has 3 internal cases)
/// to avoid breaking existing consumers while providing the full TS SDK status set.
public enum McpServerStatusEnum: String, Sendable, Equatable, CaseIterable {
    /// The server is connected and tools are available.
    case connected
    /// The connection has failed.
    case failed
    /// The server requires authentication before connecting.
    case needsAuth
    /// The server connection is pending (in progress).
    case pending
    /// The server has been disabled by the user.
    case disabled
}

// MARK: - McpServerInfo

/// Server name and version information for an MCP server.
///
/// Corresponds to the TypeScript SDK's server info field on `McpServerStatus`.
public struct McpServerInfo: Sendable, Equatable {
    /// The server name reported during MCP handshake.
    public let name: String
    /// The server version reported during MCP handshake.
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

// MARK: - McpServerStatus

/// Public-facing status of an MCP server, matching the TypeScript SDK's `McpServerStatus`.
///
/// Provides the server name, connection status, server info, error details,
/// and the list of available tools. Use ``Agent/mcpServerStatus()`` to obtain instances.
public struct McpServerStatus: Sendable, Equatable {
    /// The name of the MCP server.
    public let name: String

    /// The current connection status.
    public let status: McpServerStatusEnum

    /// Server name and version reported during MCP handshake, if available.
    public let serverInfo: McpServerInfo?

    /// Error message if the connection failed, otherwise `nil`.
    public let error: String?

    /// List of tool names available from this server.
    public let tools: [String]

    /// The MCP server configuration used to establish this connection.
    /// Maps to the TypeScript SDK's `config` field on `McpServerStatus`.
    public let config: McpServerConfig?

    /// The scope at which the MCP server is configured (e.g., "project", "user").
    /// Maps to the TypeScript SDK's `scope` field on `McpServerStatus`.
    public let scope: String?

    public init(
        name: String,
        status: McpServerStatusEnum,
        serverInfo: McpServerInfo? = nil,
        error: String? = nil,
        tools: [String] = [],
        config: McpServerConfig? = nil,
        scope: String? = nil
    ) {
        self.name = name
        self.status = status
        self.serverInfo = serverInfo
        self.error = error
        self.tools = tools
        self.config = config
        self.scope = scope
    }
}

// MARK: - McpServerUpdateResult

/// Result of dynamically replacing the MCP server set via ``Agent/setMcpServers(_:)``.
///
/// Corresponds to the TypeScript SDK's `McpSetServersResult` with added, removed,
/// and error information.
public struct McpServerUpdateResult: Sendable, Equatable {
    /// Names of servers that were newly added.
    public let added: [String]
    /// Names of servers that were removed.
    public let removed: [String]
    /// Per-server errors encountered during the update (server name -> error message).
    public let errors: [String: String]

    public init(added: [String] = [], removed: [String] = [], errors: [String: String] = [:]) {
        self.added = added
        self.removed = removed
        self.errors = errors
    }
}

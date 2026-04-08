import Foundation

/// Configuration for MCP server connections.
public enum McpServerConfig: Sendable, Equatable {
    case stdio(McpStdioConfig)
    case sse(McpSseConfig)
    case http(McpHttpConfig)
    case sdk(McpSdkServerConfig)
}

/// Configuration for MCP stdio transport.
public struct McpStdioConfig: Sendable, Equatable {
    public let command: String
    public let args: [String]?
    public let env: [String: String]?

    public init(command: String, args: [String]? = nil, env: [String: String]? = nil) {
        self.command = command
        self.args = args
        self.env = env
    }
}

/// Configuration for MCP SSE transport.
public struct McpSseConfig: Sendable, Equatable {
    public let url: String
    public let headers: [String: String]?

    public init(url: String, headers: [String: String]? = nil) {
        self.url = url
        self.headers = headers
    }
}

/// Configuration for MCP HTTP transport.
public struct McpHttpConfig: Sendable, Equatable {
    public let url: String
    public let headers: [String: String]?

    public init(url: String, headers: [String: String]? = nil) {
        self.url = url
        self.headers = headers
    }
}

/// Configuration for in-process SDK MCP server.
///
/// Holds a reference to an `InProcessMCPServer` actor, allowing the Agent
/// to directly extract tools from it without MCP protocol overhead.
/// `Equatable` is implemented via `ObjectIdentifier` comparison since
/// `InProcessMCPServer` is an actor (reference type).
public struct McpSdkServerConfig: Sendable, Equatable {
    /// Server name.
    public let name: String
    /// Server version.
    public let version: String
    /// Reference to the in-process MCP server.
    public let server: InProcessMCPServer

    public init(name: String, version: String, server: InProcessMCPServer) {
        precondition(!name.contains("__"), "MCP server name '\(name)' contains '__', which would create ambiguous namespaced tool names. Use a single-segment name without double underscores.")
        self.name = name
        self.version = version
        self.server = server
    }

    public static func == (lhs: McpSdkServerConfig, rhs: McpSdkServerConfig) -> Bool {
        ObjectIdentifier(lhs.server) == ObjectIdentifier(rhs.server)
            && lhs.name == rhs.name
            && lhs.version == rhs.version
    }
}

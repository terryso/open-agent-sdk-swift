import Foundation

/// Configuration for MCP server connections.
///
/// Each case represents a different transport mechanism for connecting to an MCP server.
/// Pass a dictionary of these configurations to ``AgentOptions/mcpServers`` to enable
/// MCP tool integration.
public enum McpServerConfig: Sendable, Equatable {
    /// Stdio transport: launches a child process and communicates via stdin/stdout.
    case stdio(McpStdioConfig)
    /// SSE transport: connects to a remote server via Server-Sent Events.
    case sse(McpSseConfig)
    /// HTTP transport: connects to a remote server via HTTP POST requests.
    case http(McpHttpConfig)
    /// SDK transport: directly uses an in-process ``InProcessMCPServer`` without MCP protocol overhead.
    case sdk(McpSdkServerConfig)
}

/// Configuration for MCP stdio transport.
///
/// Launches a child process and communicates via its stdin/stdout pipes.
public struct McpStdioConfig: Sendable, Equatable {
    /// The command to execute (e.g., "npx", "python3").
    public let command: String
    /// Optional arguments to pass to the command.
    public let args: [String]?
    /// Optional environment variables to set for the child process.
    public let env: [String: String]?

    public init(command: String, args: [String]? = nil, env: [String: String]? = nil) {
        self.command = command
        self.args = args
        self.env = env
    }
}

/// Configuration for MCP remote transport (SSE or HTTP).
///
/// Holds the URL and optional headers for connecting to a remote MCP server.
/// Used by both SSE and HTTP transport modes — the transport type is determined
/// by the ``McpServerConfig`` enum case that wraps this config.
public struct McpTransportConfig: Sendable, Equatable {
    /// The URL of the remote endpoint.
    public let url: String
    /// Optional HTTP headers to include in requests.
    public let headers: [String: String]?

    public init(url: String, headers: [String: String]? = nil) {
        self.url = url
        self.headers = headers
    }
}

/// Backward-compatible alias for SSE transport configuration.
/// - SeeAlso: ``McpTransportConfig``
public typealias McpSseConfig = McpTransportConfig

/// Backward-compatible alias for HTTP transport configuration.
/// - SeeAlso: ``McpTransportConfig``
public typealias McpHttpConfig = McpTransportConfig

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

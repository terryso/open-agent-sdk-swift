import Foundation

/// Configuration for MCP server connections.
public enum McpServerConfig: Sendable, Equatable {
    case stdio(McpStdioConfig)
    case sse(McpSseConfig)
    case http(McpHttpConfig)
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

import Foundation
import MCP

// MARK: - InProcessMCPServer

/// Actor that hosts in-process MCP tools for external MCP clients.
///
/// Wraps `ToolProtocol` tools as an MCP server using mcp-swift-sdk's `MCPServer`
/// and `InMemoryTransport`. Supports two usage modes:
///
/// 1. **SDK internal mode:** Via `McpServerConfig.sdk` -> Agent directly adds tools
///    to the tool pool without MCP protocol overhead.
///
/// 2. **External client mode:** External MCP clients connect via `createSession()`
///    -> standard MCP handshake and tool invocation.
///
/// Module boundary compliance: Only imports Foundation, MCP, and Types/ (AC9).
public actor InProcessMCPServer {

    // MARK: - Properties

    /// Server name.
    public let name: String

    /// Server version.
    public let version: String

    /// Registered tools.
    private let tools: [ToolProtocol]

    /// Working directory for ToolContext.
    private let cwd: String

    /// Internal MCPServer instance (created on first use).
    private var mcpServer: MCPServer?

    // MARK: - Initialization

    /// Creates a new InProcessMCPServer with the given configuration.
    ///
    /// - Parameters:
    ///   - name: The server name for identification.
    ///   - version: The server version. Defaults to "1.0.0".
    ///   - tools: The tools to expose via MCP protocol.
    ///   - cwd: Working directory for ToolContext. Defaults to "/".
    public init(
        name: String,
        version: String = "1.0.0",
        tools: [ToolProtocol],
        cwd: String = "/"
    ) {
        self.name = name
        self.version = version
        self.tools = tools
        self.cwd = cwd
    }

    // MARK: - Session Management

    /// Creates a new MCP session with a connected InMemoryTransport pair.
    ///
    /// Each call creates a fresh `Server` instance sharing the same tool definitions,
    /// supporting multiple concurrent clients. The session is fully started and ready
    /// for an MCP client to connect via the returned transport.
    ///
    /// - Returns: A tuple of (Server, InMemoryTransport) where the transport is the
    ///   client-side of a connected pair. Connect an MCP `Client` to this transport.
    public func createSession() async throws -> (Server, InMemoryTransport) {
        let mcpServer = await getOrCreateMCPServer()
        return try await createMCPSession(mcpServer)
    }

    // MARK: - Tool Access (SDK Internal Mode)

    /// Returns the tool list for direct injection (SDK internal mode).
    ///
    /// Used by `Agent.assembleFullToolPool()` to bypass MCP protocol overhead
    /// and directly add tools to the tool pool.
    ///
    /// - Returns: The registered tools.
    public func getTools() -> [ToolProtocol] {
        tools
    }

    // MARK: - Configuration

    /// Generates an McpServerConfig.sdk configuration for use with AgentOptions.
    ///
    /// - Returns: An `McpServerConfig.sdk` wrapping this server.
    public func asConfig() -> McpServerConfig {
        .sdk(McpSdkServerConfig(name: name, version: version, server: self))
    }

    // MARK: - Private Helpers

    /// Lazily creates and caches the MCPServer instance, registering all tools.
    private func getOrCreateMCPServer() async -> MCPServer {
        if let existing = mcpServer {
            return existing
        }

        let server = MCPServer(name: name, version: version)

        // Register each tool as a closure-based MCP tool
        await registerToolsOnMCPServer(tools, server: server, cwd: cwd) { toolName, error in
            // Tool registration failed -- this indicates a bug (duplicate name, etc.)
            assertionFailure("Failed to register tool '\(toolName)' on MCP server: \(error)")
        }

        mcpServer = server
        return server
    }

}

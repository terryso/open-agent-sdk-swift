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
        let session = await mcpServer.createSession()
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        try await session.start(transport: serverTransport)
        return (session, clientTransport)
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
        for tool in tools {
            let toolName = tool.name
            let toolDescription = tool.description
            let inputSchema = schemaToValue(tool.inputSchema)
            let capturedCwd = cwd

            // Capture tool as a Sendable-safe reference for the closure
            // Each tool is already Sendable (ToolProtocol: Sendable)
            let sendableTool = tool

            do {
                try await server.register(
                    name: toolName,
                    description: toolDescription,
                    inputSchema: inputSchema
                ) { (args: [String: Value], context: HandlerContext) async throws -> String in
                    // Convert MCP Value arguments to [String: Any]
                    let inputArgs = args.mapValues { value in
                        Self.mcpValueToAny(value)
                    }

                    // Build ToolContext with cwd and request ID as toolUseId
                    let toolContext = ToolContext(
                        cwd: capturedCwd,
                        toolUseId: ""
                    )

                    // Call the tool (never throws per rule #38)
                    let result = await sendableTool.call(
                        input: inputArgs,
                        context: toolContext
                    )

                    // If the tool returned an error, throw so MCP returns isError: true
                    if result.isError {
                        throw ToolExecutionError(message: result.content)
                    }

                    return result.content
                }
            } catch {
                // Tool registration failed -- this indicates a bug (duplicate name, etc.)
                assertionFailure("Failed to register tool '\(toolName)' on MCP server: \(error)")
            }
        }

        mcpServer = server
        return server
    }

    /// Converts a `ToolInputSchema` (`[String: Any]`) to MCP `Value`.
    ///
    /// Recursively converts dictionary structures to MCP-compatible `Value` types.
    /// This is the inverse of `MCPClientManager.mcpValueToSchema()`.
    private func schemaToValue(_ schema: ToolInputSchema) -> Value {
        .object(schema.mapValues { Self.anyToMCPValue($0) })
    }

    /// Recursively converts a plain Swift value to an MCP `Value`.
    private static func anyToMCPValue(_ value: Any) -> Value {
        switch value {
        case is NSNull: return .null
        case let b as Bool: return .bool(b)
        case let i as Int: return .int(i)
        case let d as Double: return .double(d)
        case let s as String: return .string(s)
        case let arr as [Any]: return .array(arr.map { anyToMCPValue($0) })
        case let dict as [String: Any]: return .object(dict.mapValues { anyToMCPValue($0) })
        default: return .string("\(value)")
        }
    }

    /// Recursively converts an MCP `Value` to a plain Swift value.
    private static func mcpValueToAny(_ value: Value) -> Any {
        switch value {
        case .null: return NSNull()
        case .bool(let b): return b
        case .int(let i): return i
        case .double(let d): return d
        case .string(let s): return s
        case .array(let arr): return arr.map { mcpValueToAny($0) }
        case .object(let dict): return dict.mapValues { mcpValueToAny($0) }
        case .data(_, let data): return data
        }
    }
}

// MARK: - ToolExecutionError

/// Error thrown when a tool execution returns `isError: true`.
///
/// This is caught by MCPServer's CallTool handler and converted to
/// `isError: true` in the MCP response (rule #38).
private struct ToolExecutionError: Error, Sendable {
    let message: String
}

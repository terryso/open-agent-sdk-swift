import Foundation
import MCP

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

// MARK: - MCP Value Conversions

/// Converts a `ToolInputSchema` ( `[String: Any]`) to an MCP `Value.object`.
///
/// Used by MCP server implementations to convert SDK tool schemas to the MCP SDK's `Value` type.
internal func schemaToMCPValue(_ schema: ToolInputSchema) -> Value {
    .object(schema.mapValues { anyToMCPValue($0) })
}

/// Recursively converts a plain Swift value to an MCP `Value`.
///
/// Handles: `NSNull`, `Bool`, `Int`, `Double`, `String`, `[Any]`, `[String: Any]`.
/// Unknown types are stringified via `"\(value)"`.
internal func anyToMCPValue(_ value: Any) -> Value {
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
///
/// Handles all `Value` cases: `.null`, `.bool`, `.int`, `.double`, `.string`, `.array`, `.object`, `.data`.
internal func mcpValueToAny(_ value: Value) -> Any {
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

// MARK: - MCP Tool Registration

/// Error thrown when a tool execution returns `isError: true`.
///
/// This is caught by MCPServer's CallTool handler and converted to
/// `isError: true` in the MCP response (rule #38).
struct ToolExecutionError: Error, Sendable {
    let message: String
}

/// Registers an array of `ToolProtocol` tools as closure-based MCP tools on an `MCPServer`.
///
/// Centralizes the MCP tool registration pattern shared between `InProcessMCPServer` and
/// `AgentMCPServer`: schema conversion → MCP Value argument conversion → ToolContext creation →
/// tool invocation → error result handling.
///
/// - Parameters:
///   - tools: The tools to register.
///   - server: The `MCPServer` to register tools on.
///   - cwd: Working directory passed to `ToolContext` for each tool invocation.
///   - onRegistrationError: Called when a tool registration fails (e.g., duplicate name).
internal func registerToolsOnMCPServer(
    _ tools: [ToolProtocol],
    server: MCPServer,
    cwd: String,
    onRegistrationError: @Sendable (String, Error) -> Void
) async {
    for tool in tools {
        let toolName = tool.name
        let toolDescription = tool.description
        let inputSchema = schemaToMCPValue(tool.inputSchema)
        let sendableTool = tool

        do {
            try await server.register(
                name: toolName,
                description: toolDescription,
                inputSchema: inputSchema
            ) { (args: [String: Value], context: HandlerContext) async throws -> String in
                // Convert MCP Value arguments to [String: Any]
                let inputArgs = args.mapValues { value in
                    mcpValueToAny(value)
                }

                // Build ToolContext with cwd and a generated toolUseId for tracing
                let toolContext = ToolContext(
                    cwd: cwd,
                    toolUseId: UUID().uuidString
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
            onRegistrationError(toolName, error)
        }
    }
}

/// Creates a new MCP session with a connected `InMemoryTransport` pair.
///
/// Centralizes the session creation pattern shared between `InProcessMCPServer` and
/// `AgentMCPServer`: create session → create transport pair → start session.
///
/// - Parameter mcpServer: The `MCPServer` to create a session from.
/// - Returns: A tuple of (Server, InMemoryTransport) for an MCP client to connect to.
internal func createMCPSession(_ mcpServer: MCPServer) async throws -> (Server, InMemoryTransport) {
    let session = await mcpServer.createSession()
    let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
    try await session.start(transport: serverTransport)
    return (session, clientTransport)
}

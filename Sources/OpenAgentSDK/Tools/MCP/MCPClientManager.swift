import Foundation
import MCP

// MARK: - MCPClientManager

/// Actor that manages MCP server connections, process lifecycles, and tool discovery.
///
/// `MCPClientManager` is responsible for:
/// - Launching external MCP server processes via stdio transport
/// - Performing MCP handshake and tool discovery using `MCPClient`
/// - Managing connection lifecycle (connect, disconnect, shutdown)
/// - Wrapping MCP tools as `ToolProtocol` for use in the agent tool pool
///
/// Thread safety is ensured via the actor model -- all mutable state is isolated.
public actor MCPClientManager {

    // MARK: - Properties

    /// Active connections indexed by server name.
    private var connections: [String: MCPManagedConnection] = [:]

    /// MCPClient instances for tool execution, indexed by server name.
    private var clients: [String: MCPClient] = [:]

    /// Transport instances for process termination, indexed by server name.
    private var transports: [String: MCPStdioTransport] = [:]

    // MARK: - Initialization

    /// Creates a new MCPClientManager with no connections.
    public init() {
        // Empty connections by design (AC1)
    }

    // MARK: - Connection Management

    /// Connects to an MCP server using the given stdio configuration.
    ///
    /// Performs the full MCP lifecycle:
    /// 1. Creates a transport and launches the child process
    /// 2. Creates an MCPClient and performs MCP handshake (initialize)
    /// 3. Discovers tools via `listTools()`
    /// 4. Wraps discovered tools as `MCPToolDefinition`
    ///
    /// If any step fails, the connection is tracked with `error` status and empty tools.
    /// The manager does not crash.
    ///
    /// - Parameters:
    ///   - name: The server name for identification and tool namespacing.
    ///   - config: The stdio configuration for the server.
    public func connect(name: String, config: McpStdioConfig) async {
        // Validate command
        guard !config.command.isEmpty else {
            connections[name] = MCPManagedConnection(
                name: name,
                status: .error,
                tools: []
            )
            return
        }

        do {
            // 1. Create transport and launch process
            let transport = MCPStdioTransport(config: config)
            try await transport.connect()
            self.transports[name] = transport

            // 2. Create MCPClient and connect with transport factory
            let mcpClient = MCPClient(
                name: "OpenAgentSDK",
                version: "1.0.0",
                reconnectionOptions: MCPClient.ReconnectionOptions(
                    maxRetries: 2,
                    initialDelay: .seconds(1),
                    maxDelay: .seconds(10),
                    delayGrowFactor: 2.0,
                    healthCheckInterval: nil
                )
            )

            try await mcpClient.connect {
                // Return existing transport for initial connection
                transport
            }
            self.clients[name] = mcpClient

            // 3. Discover tools via listTools()
            let toolsResult = try await mcpClient.listTools()
            let mcpTools: [ToolProtocol] = toolsResult.tools.map { tool in
                MCPToolDefinition(
                    serverName: name,
                    mcpToolName: tool.name,
                    toolDescription: tool.description ?? "",
                    schema: mcpValueToSchema(tool.inputSchema),
                    mcpClient: MCPClientWrapper(client: mcpClient)
                )
            }

            // 4. Store connection with discovered tools
            connections[name] = MCPManagedConnection(
                name: name,
                status: .connected,
                tools: mcpTools
            )
        } catch {
            // Connection failed -- clean up and mark as error
            await cleanupConnection(name: name)
            connections[name] = MCPManagedConnection(
                name: name,
                status: .error,
                tools: []
            )
        }
    }

    /// Connects to all configured MCP servers concurrently.
    ///
    /// For stdio servers, launches the process and performs full MCP handshake.
    /// For SSE/HTTP servers, delegates to the appropriate transport (future stories).
    ///
    /// - Parameter servers: A dictionary of server names to their configurations.
    public func connectAll(servers: [String: McpServerConfig]) async {
        // Connect concurrently for better performance (AC8)
        await withTaskGroup(of: Void.self) { group in
            for (name, config) in servers {
                group.addTask {
                    switch config {
                    case .stdio(let stdioConfig):
                        await self.connect(name: name, config: stdioConfig)
                    case .sse, .http:
                        // SSE/HTTP transports are handled in Story 6-2
                        await self.setErrorConnection(name: name)
                    }
                }
            }
        }
    }

    /// Disconnects a specific server by name.
    ///
    /// Terminates the child process and removes all associated state.
    /// If the server is not found, this is a no-op.
    ///
    /// - Parameter name: The server name to disconnect.
    public func disconnect(name: String) async {
        await cleanupConnection(name: name)
        connections.removeValue(forKey: name)
    }

    /// Shuts down all connections and terminates all child processes.
    public func shutdown() async {
        let names = connections.keys.map { $0 }
        for name in names {
            await cleanupConnection(name: name)
        }
        connections.removeAll()
    }

    // MARK: - Query Methods

    /// Returns all current connections.
    ///
    /// - Returns: A dictionary of server names to their managed connections.
    public func getConnections() -> [String: MCPManagedConnection] {
        connections
    }

    /// Returns all MCP tools from connected servers.
    ///
    /// Only tools from connections with `connected` status are included.
    /// Failed connections contribute no tools.
    ///
    /// - Returns: An array of `ToolProtocol` from all connected servers.
    public func getMCPTools() -> [ToolProtocol] {
        connections.values
            .filter { $0.status == .connected }
            .flatMap { $0.tools }
    }

    // MARK: - Private Helpers

    /// Cleans up a single connection: disconnects MCPClient and terminates transport.
    private func cleanupConnection(name: String) async {
        if let client = clients.removeValue(forKey: name) {
            await client.disconnect()
        }
        if let transport = transports.removeValue(forKey: name) {
            await transport.disconnect()
        }
    }

    /// Sets a connection to error status (for unsupported transport types).
    private func setErrorConnection(name: String) async {
        connections[name] = MCPManagedConnection(
            name: name,
            status: .error,
            tools: []
        )
    }

    /// Converts an MCP `Value` to a `ToolInputSchema` dictionary.
    ///
    /// MCP tool schemas are represented as `Value` (JSON-compatible enum).
    /// Our SDK uses `[String: Any]` for input schemas, so we convert here.
    private func mcpValueToSchema(_ value: MCP.Value) -> ToolInputSchema {
        switch value {
        case .object(let dict):
            return dict.mapValues { mcpValueToAny($0) }
        default:
            return ["type": "object", "properties": [:] as [String: Any]]
        }
    }

    /// Recursively converts an MCP `Value` to a plain Swift value.
    private func mcpValueToAny(_ value: MCP.Value) -> Any {
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

// MARK: - MCPClientWrapper

/// Wraps an `MCPClient` to conform to `MCPClientProtocol`.
///
/// Handles conversion between `[String: Any]` (our SDK's argument format)
/// and `[String: Value]` (MCP SDK's argument format), and extracts text
/// content from `CallTool.Result`.
private struct MCPClientWrapper: MCPClientProtocol, Sendable {
    let client: MCPClient

    func callTool(name: String, arguments: [String: Any]?) async throws -> String {
        let mcpArgs = arguments?.mapValues { anyToMCPValue($0) }
        let result = try await client.callTool(name: name, arguments: mcpArgs)

        // Extract text content from result
        let textParts = result.content.compactMap { content -> String? in
            switch content {
            case .text(let text, _, _):
                return text
            default:
                return nil
            }
        }

        if textParts.isEmpty {
            if result.isError == true {
                return "MCP tool error: empty error response"
            }
            return ""
        }

        return textParts.joined(separator: "\n")
    }

    /// Converts a plain Swift value to an MCP `Value`.
    private func anyToMCPValue(_ value: Any) -> MCP.Value {
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
}

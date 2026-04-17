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

    /// HTTPClientTransport instances for SSE/HTTP connections, indexed by server name.
    private var httpTransports: [String: HTTPClientTransport] = [:]

    /// Original configurations passed to connectAll(), stored for reconnection.
    private var originalConfigs: [String: McpServerConfig] = [:]

    /// Set of server names that have been disabled by the user.
    private var disabledServers: Set<String> = []

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

    // MARK: - HTTP/SSE Connection

    /// Connects to an MCP server using the given transport configuration.
    ///
    /// Uses mcp-swift-sdk's `HTTPClientTransport`. Set `streaming: true` for SSE
    /// transport or `streaming: false` for plain HTTP POST transport.
    /// Performs the full MCP lifecycle:
    /// 1. Validates the URL and creates HTTPClientTransport
    /// 2. Creates an MCPClient and performs MCP handshake (initialize)
    /// 3. Discovers tools via `listTools()`
    /// 4. Wraps discovered tools as `MCPToolDefinition`
    ///
    /// If any step fails, the connection is tracked with `error` status and empty tools.
    /// The manager does not crash.
    ///
    /// - Parameters:
    ///   - name: The server name for identification and tool namespacing.
    ///   - config: The transport configuration (URL and optional headers).
    ///   - streaming: Whether to use SSE streaming mode. Defaults to `true`.
    public func connect(name: String, config: McpTransportConfig, streaming: Bool = true) async {
        await connectHTTP(
            name: name,
            urlString: config.url,
            headers: config.headers,
            streaming: streaming
        )
    }

    /// Shared HTTP/SSE connection implementation.
    ///
    /// - Parameters:
    ///   - name: The server name for identification and tool namespacing.
    ///   - urlString: The URL string to connect to.
    ///   - headers: Optional custom headers to inject into requests.
    ///   - streaming: Whether to use SSE streaming mode (true for SSE, false for HTTP).
    private func connectHTTP(
        name: String,
        urlString: String,
        headers: [String: String]?,
        streaming: Bool
    ) async {
        // Validate URL (only http/https schemes are valid for MCP transport)
        guard !urlString.isEmpty,
              let url = URL(string: urlString),
              let scheme = url.scheme,
              !scheme.isEmpty,
              scheme == "http" || scheme == "https" else {
            connections[name] = MCPManagedConnection(
                name: name,
                status: .error,
                tools: []
            )
            return
        }

        do {
            // 1. Create HTTPClientTransport with request modifier for custom headers
            let requestModifier = makeRequestModifier(headers: headers)
            let transport = HTTPClientTransport(
                endpoint: url,
                streaming: streaming,
                requestModifier: requestModifier
            )
            self.httpTransports[name] = transport

            // 2. Create MCPClient and connect
            let mcpClient = MCPClient(
                name: "OpenAgentSDK",
                version: "1.0.0"
            )

            try await mcpClient.connect {
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
        // Store original configs for reconnection support
        for (name, config) in servers {
            originalConfigs[name] = config
        }

        // Connect concurrently for better performance (AC8)
        await withTaskGroup(of: Void.self) { group in
            for (name, config) in servers {
                group.addTask {
                    switch config {
                    case .stdio(let stdioConfig):
                        await self.connect(name: name, config: stdioConfig)
                    case .sse(let sseConfig):
                        await self.connect(name: name, config: sseConfig, streaming: true)
                    case .http(let httpConfig):
                        await self.connect(name: name, config: httpConfig, streaming: false)
                    case .sdk:
                        // SDK servers are handled directly by Agent, not via MCPClientManager
                        break
                    case .claudeAIProxy(let proxyConfig):
                        await self.connectClaudeAIProxy(name: name, config: proxyConfig)
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

    // MARK: - Runtime Management

    /// Returns the public-facing status of all MCP servers.
    ///
    /// Converts internal ``MCPManagedConnection`` data to public ``McpServerStatus``
    /// with the full 5-value status enum matching the TypeScript SDK.
    ///
    /// - Returns: A dictionary of server names to their public status.
    public func getStatus() -> [String: McpServerStatus] {
        var result: [String: McpServerStatus] = [:]

        // Include all servers: those tracked via originalConfigs and any individually connected
        let allNames = Set(originalConfigs.keys).union(Set(connections.keys))

        for name in allNames {
            if disabledServers.contains(name) {
                result[name] = McpServerStatus(name: name, status: .disabled)
            } else if let connection = connections[name] {
                let statusEnum: McpServerStatusEnum
                switch connection.status {
                case .connected:
                    statusEnum = .connected
                case .error:
                    statusEnum = .failed
                case .disconnected:
                    statusEnum = .pending
                }
                let toolNames = connection.tools.map { tool -> String in
                    tool.name
                }
                result[name] = McpServerStatus(
                    name: name,
                    status: statusEnum,
                    error: connection.status == .error ? "Connection failed" : nil,
                    tools: toolNames
                )
            } else {
                result[name] = McpServerStatus(name: name, status: .pending)
            }
        }

        return result
    }

    /// Reconnects a specific MCP server by disconnecting and re-establishing the connection.
    ///
    /// Uses the original configuration stored from the initial `connectAll()` call.
    ///
    /// - Parameter name: The server name to reconnect.
    /// - Throws: An error if the server name is not found in the stored configurations.
    public func reconnect(name: String) async throws {
        guard let config = originalConfigs[name] else {
            throw MCPClientManagerError.serverNotFound(name)
        }

        // Disconnect existing connection if any
        await cleanupConnection(name: name)
        connections.removeValue(forKey: name)

        // Remove from disabled set so it can reconnect
        disabledServers.remove(name)

        // Reconnect using stored config
        switch config {
        case .stdio(let stdioConfig):
            await connect(name: name, config: stdioConfig)
        case .sse(let sseConfig):
            await connect(name: name, config: sseConfig, streaming: true)
        case .http(let httpConfig):
            await connect(name: name, config: httpConfig, streaming: false)
        case .sdk:
            break
        case .claudeAIProxy(let proxyConfig):
            await connectClaudeAIProxy(name: name, config: proxyConfig)
        }
    }

    /// Enables or disables a specific MCP server.
    ///
    /// When disabled, the server's connection is closed but its configuration is retained
    /// for potential re-enablement. When enabled, the server is reconnected using its
    /// stored configuration.
    ///
    /// - Parameters:
    ///   - name: The server name to toggle.
    ///   - enabled: `true` to enable (reconnect), `false` to disable (disconnect).
    /// - Throws: An error if the server name is not found in the stored configurations.
    public func toggle(name: String, enabled: Bool) async throws {
        guard originalConfigs[name] != nil else {
            throw MCPClientManagerError.serverNotFound(name)
        }

        if enabled {
            disabledServers.remove(name)
            // Reconnect using stored config
            try await reconnect(name: name)
        } else {
            disabledServers.insert(name)
            // Disconnect but keep config
            await cleanupConnection(name: name)
            connections[name] = MCPManagedConnection(
                name: name,
                status: .disconnected,
                tools: []
            )
        }
    }

    /// Dynamically replaces the full MCP server set.
    ///
    /// Compares new server configurations against existing connections:
    /// - Servers in the new set but not currently connected are added.
    /// - Servers currently connected but not in the new set are removed.
    /// - Errors encountered during connection are reported per-server.
    ///
    /// - Parameter servers: The new set of MCP server configurations.
    /// - Returns: A ``McpServerUpdateResult`` with added, removed, and error details.
    public func setServers(_ servers: [String: McpServerConfig]) async -> McpServerUpdateResult {
        let existingNames = Set(originalConfigs.keys)
        let newNames = Set(servers.keys)

        let addedNames = newNames.subtracting(existingNames)
        let removedNames = existingNames.subtracting(newNames)
        var errors: [String: String] = [:]

        // Remove servers no longer in the new set
        for name in removedNames {
            await cleanupConnection(name: name)
            connections.removeValue(forKey: name)
            originalConfigs.removeValue(forKey: name)
            disabledServers.remove(name)
        }

        // Detect changed configs (same name, different config)
        let changedNames = newNames.intersection(existingNames).filter { name in
            originalConfigs[name] != servers[name]
        }

        // Treat changed servers as remove + add
        for name in changedNames {
            await cleanupConnection(name: name)
            connections.removeValue(forKey: name)
            originalConfigs.removeValue(forKey: name)
            disabledServers.remove(name)
        }

        let effectiveAdded = addedNames.union(changedNames)

        // Connect new servers
        for name in effectiveAdded {
            guard let config = servers[name] else { continue }
            originalConfigs[name] = config

            switch config {
            case .stdio(let stdioConfig):
                await connect(name: name, config: stdioConfig)
            case .sse(let sseConfig):
                await connect(name: name, config: sseConfig, streaming: true)
            case .http(let httpConfig):
                await connect(name: name, config: httpConfig, streaming: false)
            case .sdk:
                break
            case .claudeAIProxy(let proxyConfig):
                await connectClaudeAIProxy(name: name, config: proxyConfig)
            }

            // Check if connection failed
            if let connection = connections[name], connection.status == .error {
                errors[name] = "Connection failed"
            }
        }

        return McpServerUpdateResult(
            added: Array(addedNames).sorted(),
            removed: Array(removedNames).sorted(),
            errors: errors
        )
    }

    // MARK: - ClaudeAI Proxy Connection

    /// Connects to an MCP server via the ClaudeAI proxy.
    ///
    /// Uses HTTP transport to the proxy URL with authentication headers
    /// derived from the proxy configuration's `id` field.
    ///
    /// - Parameters:
    ///   - name: The server name for identification and tool namespacing.
    ///   - config: The ClaudeAI proxy configuration.
    private func connectClaudeAIProxy(name: String, config: McpClaudeAIProxyConfig) async {
        let headers: [String: String] = [
            "X-ClaudeAI-Server-ID": config.id
        ]
        await connectHTTP(
            name: name,
            urlString: config.url,
            headers: headers,
            streaming: false
        )
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
        if let httpTransport = httpTransports.removeValue(forKey: name) {
            await httpTransport.disconnect()
        }
    }

    /// Creates a request modifier closure that injects custom headers into HTTP requests.
    ///
    /// - Parameter headers: Optional dictionary of headers to inject.
    /// - Returns: A closure that adds the headers to each URLRequest.
    private func makeRequestModifier(headers: [String: String]?) -> @Sendable (URLRequest) -> URLRequest {
        guard let headers, !headers.isEmpty else {
            return { $0 }
        }
        return { request in
            var modified = request
            for (key, value) in headers {
                modified.addValue(value, forHTTPHeaderField: key)
            }
            return modified
        }
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

// MARK: - MCPClientManagerError

/// Errors thrown by ``MCPClientManager`` runtime management operations.
public enum MCPClientManagerError: Error, Sendable, Equatable {
    /// The specified server name was not found in the stored configurations.
    case serverNotFound(String)
}

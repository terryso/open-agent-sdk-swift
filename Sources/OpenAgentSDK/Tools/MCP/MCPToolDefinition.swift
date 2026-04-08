import Foundation

// MARK: - MCPClientProtocol

/// Protocol defining the interface for communicating with an MCP server client.
///
/// This abstraction allows `MCPToolDefinition` to work with both real MCP clients
/// and mock clients for testing, without depending on the mcp-swift-sdk directly.
///
/// `MCPClientManager` provides concrete implementations that wrap mcp-swift-sdk's
/// `MCPClient`.
public protocol MCPClientProtocol: Sendable {
    /// Call a tool on the MCP server.
    ///
    /// - Parameters:
    ///   - name: The name of the tool to call.
    ///   - arguments: Optional arguments for the tool.
    /// - Returns: The text content from the tool result.
    func callTool(name: String, arguments: [String: Any]?) async throws -> String
}

// MARK: - MCPToolDefinition

/// Wraps an MCP server tool as a `ToolProtocol` for use in the agent tool pool.
///
/// The tool name follows the `mcp__{serverName}__{toolName}` namespace convention
/// (architecture rule #10) to avoid conflicts with built-in tools.
///
/// Error handling follows rule #38/#39: `call()` never throws. All errors are
/// captured as `ToolResult(isError: true)` to prevent disrupting the agent loop.
public struct MCPToolDefinition: ToolProtocol, Sendable {
    /// The MCP server name used for namespacing.
    public let serverName: String

    /// The original MCP tool name (without namespace prefix).
    public let mcpToolName: String

    /// Tool description from the MCP server.
    public let toolDescription: String

    /// Input schema from the MCP server, passed through as-is.
    public nonisolated(unsafe) let schema: ToolInputSchema

    /// The MCP client used for tool execution. Nil if the connection failed.
    private let mcpClient: (any MCPClientProtocol)?

    // MARK: - ToolProtocol Conformance

    /// Namespaced tool name: `mcp__{serverName}__{toolName}`.
    public var name: String {
        "mcp__\(serverName)__\(mcpToolName)"
    }

    public var description: String {
        toolDescription
    }

    public var inputSchema: ToolInputSchema {
        schema
    }

    /// MCP tools are never read-only (matches TypeScript SDK behavior).
    public var isReadOnly: Bool {
        false
    }

    // MARK: - Initialization

    /// Creates a new MCPToolDefinition.
    ///
    /// - Parameters:
    ///   - serverName: The MCP server name for namespacing.
    ///   - mcpToolName: The original MCP tool name.
    ///   - toolDescription: Description from the MCP server.
    ///   - schema: Input schema from the MCP server.
    ///   - mcpClient: The MCP client for tool execution. May be nil for failed connections.
    public init(
        serverName: String,
        mcpToolName: String,
        toolDescription: String,
        schema: ToolInputSchema,
        mcpClient: (any MCPClientProtocol)?
    ) {
        precondition(!serverName.contains("__"), "MCP server name '\(serverName)' contains '__', which would create ambiguous namespaced tool names (mcp__\(serverName)__\(mcpToolName)). Use a single-segment name without double underscores.")
        self.serverName = serverName
        self.mcpToolName = mcpToolName
        self.toolDescription = toolDescription
        self.schema = schema
        self.mcpClient = mcpClient
    }

    // MARK: - ToolProtocol call()

    /// Executes the MCP tool via the underlying MCPClient.
    ///
    /// Errors are captured as `ToolResult(isError: true)` -- this method never throws
    /// (architecture rule #38/#39).
    public func call(input: Any, context: ToolContext) async -> ToolResult {
        guard let mcpClient else {
            return ToolResult(
                toolUseId: context.toolUseId,
                content: "MCP tool error: client not available for \(name)",
                isError: true
            )
        }

        do {
            let arguments = convertToMCPArguments(input)
            let result = try await mcpClient.callTool(name: mcpToolName, arguments: arguments)
            return ToolResult(
                toolUseId: context.toolUseId,
                content: result,
                isError: false
            )
        } catch {
            return ToolResult(
                toolUseId: context.toolUseId,
                content: "MCP tool error: \(error.localizedDescription)",
                isError: true
            )
        }
    }

    // MARK: - Private Helpers

    /// Converts tool input to MCP arguments dictionary.
    private func convertToMCPArguments(_ input: Any) -> [String: Any] {
        if let dict = input as? [String: Any] {
            return dict
        }
        return [:]
    }
}

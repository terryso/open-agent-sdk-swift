import Foundation

// MARK: - Global MCP Connection Storage

/// File-level MCP connection storage (matches TS SDK's module-level variable).
/// Uses nonisolated(unsafe) because connection state is session-scoped
/// and does not require cross-thread synchronization.
nonisolated(unsafe) var mcpConnections: [MCPConnectionInfo] = []

/// Set MCP connections for resource access (called by agent setup).
/// Matches the TS SDK's `setMcpConnections()` pattern.
public func setMcpConnections(_ connections: [MCPConnectionInfo]) {
    mcpConnections = connections
}

// MARK: - Schema

private nonisolated(unsafe) let listMcpResourcesSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "server": [
            "type": "string",
            "description": "Filter by MCP server name"
        ] as [String: Any],
    ] as [String: Any]
]

// MARK: - Factory Function

/// Creates the ListMcpResources tool for listing available resources from connected MCP servers.
///
/// The ListMcpResources tool queries connected MCP servers and returns a formatted
/// list of available resources. Resources can include files, databases, and other
/// data sources exposed by MCP servers.
///
/// **Behavior:**
/// - If no MCP servers are connected, returns "No MCP servers connected."
/// - If a `server` filter is provided, only resources from the matching server are returned.
/// - For each connected server, attempts to list resources via `MCPResourceProvider`.
/// - If a server does not support resource listing, shows an appropriate message.
///
/// **Architecture:** This tool uses file-level `mcpConnections` storage.
/// It does not require an Actor store, ToolContext modifications, or AgentOptions changes.
/// Only imports Foundation and Types/ -- never Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the ListMcpResources tool.
public func createListMcpResourcesTool() -> ToolProtocol {
    return defineTool(
        name: "ListMcpResources",
        description: "List available resources from connected MCP servers. Resources can include files, databases, and other data sources.",
        inputSchema: listMcpResourcesSchema,
        isReadOnly: true
    ) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
        let serverFilter = input["server"] as? String

        // Filter connections by server name if provided
        var connections = mcpConnections
        if let serverFilter = serverFilter, !serverFilter.isEmpty {
            connections = connections.filter { $0.name == serverFilter }
        }

        // No connections case
        if connections.isEmpty {
            return ToolExecuteResult(
                content: "No MCP servers connected.",
                isError: false
            )
        }

        var output: [String] = []
        var skippedDisconnected = 0

        for connection in connections {
            // Only query connected servers
            guard connection.status == "connected" else {
                skippedDisconnected += 1
                continue
            }

            guard let provider = connection.resourceProvider else {
                output.append("Server: \(connection.name) (resource listing not supported)")
                continue
            }

            if let resources = await provider.listResources() {
                output.append("Server: \(connection.name)")
                for resource in resources {
                    let detail = resource.description ?? resource.uri ?? ""
                    output.append("  - \(resource.name): \(detail)")
                }
            } else {
                // Server does not support resource listing
                output.append("Server: \(connection.name) (resource listing not supported)")
            }
        }

        if output.isEmpty {
            if skippedDisconnected > 0 {
                return ToolExecuteResult(
                    content: "No connected MCP servers found. \(skippedDisconnected) server(s) exist but are not in 'connected' status.",
                    isError: false
                )
            }
            return ToolExecuteResult(
                content: "No resources found.",
                isError: false
            )
        }

        return ToolExecuteResult(
            content: output.joined(separator: "\n"),
            isError: false
        )
    }
}

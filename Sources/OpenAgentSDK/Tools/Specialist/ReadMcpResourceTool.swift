import Foundation

// MARK: - Schema

private nonisolated(unsafe) let readMcpResourceSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "server": [
            "type": "string",
            "description": "MCP server name"
        ] as [String: Any],
        "uri": [
            "type": "string",
            "description": "Resource URI to read"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["server", "uri"]
]

// MARK: - Factory Function

/// Creates the ReadMcpResource tool for reading a specific resource from an MCP server.
///
/// The ReadMcpResource tool reads the content of a specific resource identified
/// by its URI from a named MCP server. The resource content is returned as text.
///
/// **Behavior:**
/// - If the specified server is not found in connected MCP servers, returns
///   `is_error: true` with "MCP server not found: {server}".
/// - If the server is found, attempts to read the resource via `MCPResourceProvider`.
/// - On success with content, concatenates text items or JSON-serializes non-text items.
/// - On success with empty/nil contents, returns "Resource read returned no content."
/// - On error, returns `is_error: true` with "Error reading resource: {message}".
///
/// **Architecture:** This tool uses file-level `mcpConnections` storage (defined in
/// ListMcpResourcesTool.swift). It does not require an Actor store, ToolContext
/// modifications, or AgentOptions changes.
/// Only imports Foundation and Types/ -- never Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the ReadMcpResource tool.
public func createReadMcpResourceTool() -> ToolProtocol {
    return defineTool(
        name: "ReadMcpResource",
        description: "Read a specific resource from an MCP server.",
        inputSchema: readMcpResourceSchema,
        isReadOnly: true
    ) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
        guard let server = input["server"] as? String, !server.isEmpty else {
            return ToolExecuteResult(
                content: "Error reading resource: server parameter is required and must be a string",
                isError: true
            )
        }

        guard let uri = input["uri"] as? String, !uri.isEmpty else {
            return ToolExecuteResult(
                content: "Error reading resource: uri parameter is required and must be a string",
                isError: true
            )
        }

        // Find the matching connection
        guard let connection = mcpConnections.first(where: { $0.name == server }) else {
            return ToolExecuteResult(
                content: "MCP server not found: \(server)",
                isError: true
            )
        }

        guard let provider = connection.resourceProvider else {
            return ToolExecuteResult(
                content: "Error reading resource: MCP server \"\(server)\" does not support resource operations",
                isError: true
            )
        }

        do {
            let result = try await provider.readResource(uri: uri)

            guard let contents = result.contents, !contents.isEmpty else {
                return ToolExecuteResult(
                    content: "Resource read returned no content.",
                    isError: false
                )
            }

            // Concatenate content items
            var textParts: [String] = []
            for item in contents {
                if let text = item.text {
                    textParts.append(text)
                } else if let rawValue = item.rawValue {
                    // Serialize non-text content as JSON-like string
                    textParts.append(jsonStringifyValue(rawValue))
                }
            }

            let combined = textParts.joined(separator: "\n")
            if combined.isEmpty {
                return ToolExecuteResult(
                    content: "Resource read returned no content.",
                    isError: false
                )
            }

            return ToolExecuteResult(
                content: combined,
                isError: false
            )
        } catch {
            return ToolExecuteResult(
                content: "Error reading resource: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}

// MARK: - JSON Serialization Helper

/// Serializes an arbitrary value to a JSON-like string representation.
/// Used for non-text MCP content items.
///
/// Note: Unlike ConfigTool's `jsonString` (which wraps strings in quotes),
/// this function returns string values unwrapped. This is intentional:
/// MCP content text is already user-facing and should not be quoted.
private func jsonStringifyValue(_ value: Any) -> String {
    if let str = value as? String { return str }
    if let bool = value as? Bool { return bool ? "true" : "false" }
    if let num = value as? Double {
        return num.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(num))" : "\(num)"
    }
    if let num = value as? Int { return "\(num)" }
    if let arr = value as? [Any] {
        let items = arr.map { jsonStringifyValue($0) }
        return "[\(items.joined(separator: ", "))]"
    }
    if let dict = value as? [String: Any] {
        let pairs = dict.map { "\"\($0.key)\": \(jsonStringifyValue($0.value))" }
        return "{\(pairs.joined(separator: ", "))}"
    }
    return String(describing: value)
}

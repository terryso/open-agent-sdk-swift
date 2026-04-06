import Foundation

// MARK: - Deferred Tools (module-level state)

/// Internal deferred tools storage for search.
/// Set by the agent when it loads additional tool tiers.
/// Uses `nonisolated(unsafe)` because access is serialized by the tool execution
/// lifecycle (tools set before agent loop, cleared after).
nonisolated(unsafe) private var _deferredTools: [ToolProtocol] = []

/// Sets the deferred tools available for search by the ToolSearch tool.
///
/// Called by the agent when it loads additional tool tiers beyond the
/// initially registered tools. These tools can then be discovered
/// by the LLM via the ToolSearch tool.
///
/// - Parameter tools: The array of deferred tools to make searchable.
public func setDeferredTools(_ tools: [ToolProtocol]) {
    _deferredTools = tools
}

// MARK: - Input

/// Input type for the ToolSearch tool.
private struct ToolSearchInput: Codable {
    let query: String
    let max_results: Int?
}

// MARK: - Factory

/// Creates the ToolSearch tool for searching available tools.
///
/// The ToolSearch tool allows an agent to discover tools that are available
/// but not yet loaded. Key behaviors:
///
/// - **Keyword search**: Splits the query into words and matches against
///   tool names and descriptions (case-insensitive).
/// - **Exact name selection**: Queries starting with `select:` perform exact
///   name matching (comma-separated for multiple names).
/// - **Result limiting**: Default `max_results` is 5.
/// - **No results**: Returns a descriptive "no match" message.
/// - **No deferred tools**: Returns an informational message when no
///   deferred tools are available.
///
/// - Returns: A `ToolProtocol` instance for the ToolSearch tool.
public func createToolSearchTool() -> ToolProtocol {
    return defineTool(
        name: "ToolSearch",
        description:
            "Search for additional tools that may be available but not yet loaded. " +
            "Use keyword search or exact name selection with \"select:ToolName\".",
        inputSchema: [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Search query. Use \"select:ToolName\" for exact match or keywords for search."
                ],
                "max_results": [
                    "type": "integer",
                    "description": "Maximum results to return (default: 5)"
                ]
            ],
            "required": ["query"]
        ],
        isReadOnly: true
    ) { (input: ToolSearchInput, context: ToolContext) async throws -> String in
        let maxResults = input.max_results ?? 5

        if _deferredTools.isEmpty {
            return "No deferred tools available."
        }

        if input.query.hasPrefix("select:") {
            // Exact name selection mode
            let namesString = input.query.dropFirst(7) // drop "select:"
            let names = namesString.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            let matches = _deferredTools.filter { tool in
                names.contains(tool.name)
            }
            if matches.isEmpty {
                return "No tools found matching \"\(input.query)\""
            }
            return formatToolList(matches)
        } else {
            // Keyword search mode
            let keywords = input.query.lowercased().split(separator: " ").map(String.init)
            let matches = _deferredTools.filter { tool in
                let searchText = "\(tool.name) \(tool.description)".lowercased()
                return keywords.contains { searchText.contains($0) }
            }
            let limited = Array(matches.prefix(maxResults))
            if limited.isEmpty {
                return "No tools found matching \"\(input.query)\""
            }
            return formatToolList(limited)
        }
    }
}

// MARK: - Formatting

/// Formats a list of tools into a human-readable string.
///
/// Each tool is listed with its name and a truncated description.
///
/// - Parameter tools: The tools to format.
/// - Returns: A formatted string listing all tools.
private func formatToolList(_ tools: [ToolProtocol]) -> String {
    let lines = tools.map { tool in
        let desc = String(tool.description.prefix(200))
        return "- \(tool.name): \(desc)"
    }
    return "Found \(tools.count) tool(s):\n" + lines.joined(separator: "\n")
}

import Foundation

// MARK: - ToolTier

/// Represents a tier of tools that can be registered with an agent.
///
/// Tools are organized into three tiers:
/// - `core`: Essential tools provided by the SDK (bash, read, write, etc.)
/// - `advanced`: More specialized tools for advanced use cases
/// - `specialist`: Domain-specific tools for particular workflows
public enum ToolTier: String, Sendable, CaseIterable {
    case core
    case advanced
    case specialist
}

// MARK: - Tool Registry Functions

/// Converts a single `ToolProtocol` to the Anthropic API tool format.
///
/// The output dictionary contains exactly three keys:
/// - `name`: The tool's name
/// - `description`: The tool's description
/// - `input_schema`: The tool's input schema
///
/// - Parameter tool: The tool to convert.
/// - Returns: A dictionary in the Anthropic API tool format.
public func toApiTool(_ tool: ToolProtocol) -> [String: Any] {
    return [
        "name": tool.name,
        "description": tool.description,
        "input_schema": tool.inputSchema
    ]
}

/// Converts an array of `ToolProtocol` tools to the Anthropic API tool format.
///
/// - Parameter tools: The array of tools to convert.
/// - Returns: An array of dictionaries in the Anthropic API tool format.
public func toApiTools(_ tools: [ToolProtocol]) -> [[String: Any]] {
    return tools.map { toApiTool($0) }
}

/// Returns all base tools for the specified tier.
///
/// For the `.core` tier, returns all 10 built-in tools: Read, Write, Edit, Glob, Grep,
/// Bash, AskUser, ToolSearch, WebFetch, and WebSearch.
/// The `.advanced` and `.specialist` tiers currently return empty arrays.
///
/// - Parameter tier: The tool tier to retrieve.
/// - Returns: An array of tools for the specified tier.
public func getAllBaseTools(tier: ToolTier) -> [ToolProtocol] {
    switch tier {
    case .core:
        return [
            createReadTool(),
            createWriteTool(),
            createEditTool(),
            createGlobTool(),
            createGrepTool(),
            createBashTool(),
            createAskUserTool(),
            createToolSearchTool(),
            createWebFetchTool(),
            createWebSearchTool(),
        ]
    case .advanced:
        return []
    case .specialist:
        return [
            createEnterWorktreeTool(),
            createExitWorktreeTool(),
            createEnterPlanModeTool(),
            createExitPlanModeTool(),
            createCronCreateTool(),
            createCronDeleteTool(),
            createCronListTool(),
            createTodoWriteTool(),
            createLSPTool(),
            createConfigTool(),
            createRemoteTriggerTool(),
            createListMcpResourcesTool(),
            createReadMcpResourceTool(),
        ]
    }
}

/// Filters a list of tools by allowed and disallowed name lists.
///
/// If `allowed` is non-nil and non-empty, only tools whose names appear in the list
/// are included. If `disallowed` is non-nil and non-empty, tools whose names appear
/// in that list are excluded. When both are provided, disallowed takes precedence
/// (a tool in both lists is excluded). Empty lists are treated as nil (no filtering).
///
/// - Parameters:
///   - tools: The tools to filter.
///   - allowed: Optional list of allowed tool names. Nil or empty means no allow filter.
///   - disallowed: Optional list of disallowed tool names. Nil or empty means no disallow filter.
/// - Returns: The filtered array of tools.
public func filterTools(
    tools: [ToolProtocol],
    allowed: [String]?,
    disallowed: [String]?
) -> [ToolProtocol] {
    var filtered = tools

    // Apply allowed list filter (non-nil, non-empty)
    if let allowed, !allowed.isEmpty {
        let allowedSet = Set(allowed)
        filtered = filtered.filter { allowedSet.contains($0.name) }
    }

    // Apply disallowed list filter (non-nil, non-empty)
    if let disallowed, !disallowed.isEmpty {
        let disallowedSet = Set(disallowed)
        filtered = filtered.filter { !disallowedSet.contains($0.name) }
    }

    return filtered
}

/// Assembles a complete tool pool from base, custom, and MCP tools with deduplication and filtering.
///
/// Tools are merged in order: base tools first, then custom tools, then MCP tools.
/// When tools share the same name, the later one overrides the earlier one
/// (custom overrides base, MCP overrides custom/base). Deduplication is performed
/// using a Dictionary to preserve insertion order. After deduplication, the allowed
/// and disallowed filters are applied.
///
/// - Parameters:
///   - baseTools: The base SDK tools.
///   - customTools: Optional custom user-defined tools.
///   - mcpTools: Optional tools from MCP servers.
///   - allowed: Optional list of allowed tool names.
///   - disallowed: Optional list of disallowed tool names.
/// - Returns: The assembled, deduplicated, and filtered tool pool.
public func assembleToolPool(
    baseTools: [ToolProtocol],
    customTools: [ToolProtocol]?,
    mcpTools: [ToolProtocol]?,
    allowed: [String]?,
    disallowed: [String]?
) -> [ToolProtocol] {
    // Combine all tool sources: base + custom + MCP
    var combined = baseTools
    if let customTools {
        combined.append(contentsOf: customTools)
    }
    if let mcpTools {
        combined.append(contentsOf: mcpTools)
    }

    // Deduplicate by name using Dictionary (latter overrides former, preserves order)
    var byName = [String: ToolProtocol]()
    for tool in combined {
        byName[tool.name] = tool
    }

    // Apply filters after dedup
    return filterTools(
        tools: Array(byName.values),
        allowed: allowed,
        disallowed: disallowed
    )
}

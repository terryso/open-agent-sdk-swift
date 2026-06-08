import Foundation

// MARK: - Schema

private nonisolated(unsafe) let configSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "action": [
            "type": "string",
            "enum": ["get", "set", "list"],
            "description": "Operation to perform"
        ] as [String: Any],
        "key": [
            "type": "string",
            "description": "Config key"
        ] as [String: Any],
        "value": [
            "description": "Config value (for set)"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["action"]
]

// MARK: - Factory Function

/// Creates the Config tool for managing session-scoped configuration values.
///
/// The Config tool supports three operations:
/// - `get`: Retrieve a config value by key.
/// - `set`: Store a config value (key + value).
/// - `list`: List all config entries.
///
/// Configuration is stored in memory (session-scoped). Values can be any JSON type.
///
/// **Architecture:** This tool uses a file-level dictionary for config storage.
/// It does not require an Actor store, ToolContext modifications, or AgentOptions changes.
/// Only imports Foundation and Types/ -- never Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the Config tool.
public func createConfigTool() -> ToolProtocol {
    // File-level config storage (matches TS SDK's Map<string, unknown>).
    // Uses nonisolated(unsafe) because session-scoped storage does not need cross-thread sharing.
    nonisolated(unsafe) var configStore: [String: Any] = [:]

    return defineTool(
        name: "Config",
        description: "Get or set configuration values. Supports session-scoped settings.",
        inputSchema: configSchema,
        isReadOnly: false
    ) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
        guard let action = input["action"] as? String else {
            return ToolExecuteResult(content: "action required", isError: true)
        }

        switch action {
        case "get":
            guard let key = input["key"] as? String, !key.isEmpty else {
                return ToolExecuteResult(content: "key required for get", isError: true)
            }
            if let value = configStore[key] {
                return ToolExecuteResult(content: jsonStringify(value), isError: false)
            }
            return ToolExecuteResult(
                content: "Config key \"\(key)\" not found",
                isError: false
            )

        case "set":
            guard let key = input["key"] as? String, !key.isEmpty else {
                return ToolExecuteResult(content: "key required for set", isError: true)
            }
            let value = input["value"]
            configStore[key] = value
            return ToolExecuteResult(
                content: "Config set: \(key) = \(jsonStringify(value))",
                isError: false
            )

        case "list":
            if configStore.isEmpty {
                return ToolExecuteResult(content: "No config values set.", isError: false)
            }
            let lines = configStore.map { "\($0.key) = \(jsonStringify($0.value))" }
            return ToolExecuteResult(content: lines.joined(separator: "\n"), isError: false)

        default:
            return ToolExecuteResult(
                content: "Unknown action: \(action)",
                isError: true
            )
        }
    }
}

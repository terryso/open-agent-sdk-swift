import Foundation

// MARK: - Schema

private nonisolated(unsafe) let remoteTriggerSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "action": [
            "type": "string",
            "enum": ["list", "get", "create", "update", "run"],
            "description": "Operation to perform"
        ] as [String: Any],
        "id": [
            "type": "string",
            "description": "Trigger ID (for get/update/run)"
        ] as [String: Any],
        "name": [
            "type": "string",
            "description": "Trigger name (for create)"
        ] as [String: Any],
        "schedule": [
            "type": "string",
            "description": "Cron schedule (for create/update)"
        ] as [String: Any],
        "prompt": [
            "type": "string",
            "description": "Agent prompt (for create/update)"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["action"]
]

// MARK: - Factory Function

/// Creates the RemoteTrigger tool for managing remote scheduled agent triggers.
///
/// The RemoteTrigger tool is a stub implementation -- all operations return a message
/// indicating that a connected remote backend is required. In standalone SDK mode,
/// users should use CronCreate/CronList/CronDelete for local scheduling.
///
/// **Supported operations (all stubs):**
/// - `list`, `get`, `create`, `update`, `run`
///
/// **Architecture:** This tool is completely stateless. It does not require an Actor store,
/// ToolContext modifications, or AgentOptions changes. Only imports Foundation and Types/.
///
/// - Returns: A ``ToolProtocol`` instance for the RemoteTrigger tool.
public func createRemoteTriggerTool() -> ToolProtocol {
    return defineTool(
        name: "RemoteTrigger",
        description: "Manage remote scheduled agent triggers. Supports list, get, create, update, and run operations.",
        inputSchema: remoteTriggerSchema,
        isReadOnly: false
    ) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
        let action = input["action"] as? String ?? "unknown"
        return ToolExecuteResult(
            content: "RemoteTrigger \(action): This feature requires a connected remote backend. In standalone SDK mode, use CronCreate/CronList/CronDelete for local scheduling.",
            isError: false
        )
    }
}

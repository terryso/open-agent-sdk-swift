import Foundation

// MARK: - TaskGetTool Input

/// Input type for the TaskGet tool.
///
/// Field names match the TS SDK's TaskGet schema.
private struct TaskGetInput: Codable {
    let id: String            // Required
}

// MARK: - TaskGetTool Schema

private nonisolated(unsafe) let taskGetSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": ["type": "string", "description": "Task ID"] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]

// MARK: - Factory Function

/// Creates the TaskGet tool for retrieving full task details from the task store.
///
/// The TaskGet tool allows agents to retrieve complete information about a
/// specific task, including all fields such as subject, status, owner, and output.
///
/// **Architecture:** This tool uses ``ToolContext/taskStore`` (injected by Core/)
/// to access task management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the TaskGet tool.
public func createTaskGetTool() -> ToolProtocol {
    return defineTool(
        name: "TaskGet",
        description: "Get full details of a specific task.",
        inputSchema: taskGetSchema,
        isReadOnly: true
    ) { (input: TaskGetInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        guard let task = await taskStore.get(id: input.id) else {
            return ToolExecuteResult(content: "Task not found: \(input.id)", isError: true)
        }
        var lines = [
            "ID: \(task.id)",
            "Subject: \(task.subject)",
            "Status: \(task.status.rawValue)",
        ]
        if let desc = task.description { lines.append("Description: \(desc)") }
        if let owner = task.owner { lines.append("Owner: \(owner)") }
        lines.append("Created: \(task.createdAt)")
        lines.append("Updated: \(task.updatedAt)")
        if let output = task.output { lines.append("Output: \(output)") }
        return ToolExecuteResult(content: lines.joined(separator: "\n"), isError: false)
    }
}

import Foundation

// MARK: - TaskListTool Input

/// Input type for the TaskList tool.
///
/// Field names match the TS SDK's TaskList schema.
private struct TaskListInput: Codable {
    let status: String?       // Optional filter
    let owner: String?        // Optional filter
}

// MARK: - TaskListTool Schema

private nonisolated(unsafe) let taskListSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "status": ["type": "string", "description": "Filter by status"] as [String: Any],
        "owner": ["type": "string", "description": "Filter by owner"] as [String: Any],
    ] as [String: Any]
    // no required fields
]

// MARK: - Factory Function

/// Creates the TaskList tool for listing tasks from the task store.
///
/// The TaskList tool allows agents to list all tasks or filter by status and/or owner.
/// Returns a formatted list of tasks with their IDs, status, subject, and owner.
///
/// **Architecture:** This tool uses ``ToolContext/taskStore`` (injected by Core/)
/// to access task management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the TaskList tool.
public func createTaskListTool() -> ToolProtocol {
    return defineTool(
        name: "TaskList",
        description: "List all tasks with their status, ownership, and dependencies.",
        inputSchema: taskListSchema,
        isReadOnly: true
    ) { (input: TaskListInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        let status: TaskStatus? = input.status.flatMap { TaskStatus.parse($0) }
        let tasks = await taskStore.list(status: status, owner: input.owner)
        if tasks.isEmpty {
            return ToolExecuteResult(content: "No tasks found.", isError: false)
        }
        let lines = tasks.map { t in
            "[\(t.id)] \(t.status.rawValue.uppercased()) - \(t.subject)\(t.owner != nil ? " (owner: \(t.owner!))" : "")"
        }
        return ToolExecuteResult(content: lines.joined(separator: "\n"), isError: false)
    }
}

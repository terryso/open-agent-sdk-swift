import Foundation

// MARK: - TaskUpdateTool Input

/// Input type for the TaskUpdate tool.
///
/// Field names match the TS SDK's TaskUpdate schema.
private struct TaskUpdateInput: Codable {
    let id: String            // Required
    let status: String?       // Optional
    let description: String?  // Optional
    let owner: String?        // Optional
    let output: String?       // Optional
}

// MARK: - TaskUpdateTool Schema

private nonisolated(unsafe) let taskUpdateSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": ["type": "string", "description": "Task ID"] as [String: Any],
        "status": ["type": "string", "enum": ["pending", "in_progress", "completed", "failed", "cancelled"]] as [String: Any],
        "description": ["type": "string", "description": "Updated description"] as [String: Any],
        "owner": ["type": "string", "description": "New owner"] as [String: Any],
        "output": ["type": "string", "description": "Task output/result"] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]

// MARK: - Factory Function

/// Creates the TaskUpdate tool for updating tasks in the task store.
///
/// The TaskUpdate tool allows agents to update a task's status, description,
/// owner, and/or output. State transitions are validated by the TaskStore.
///
/// **Architecture:** This tool uses ``ToolContext/taskStore`` (injected by Core/)
/// to access task management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the TaskUpdate tool.
public func createTaskUpdateTool() -> ToolProtocol {
    return defineTool(
        name: "TaskUpdate",
        description: "Update a task's status, description, or other properties.",
        inputSchema: taskUpdateSchema,
        isReadOnly: false
    ) { (input: TaskUpdateInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        let status: TaskStatus? = input.status.flatMap { TaskStatus.parse($0) }
        do {
            let task = try await taskStore.update(
                id: input.id,
                status: status,
                description: input.description,
                owner: input.owner,
                output: input.output
            )
            return ToolExecuteResult(
                content: "Task updated: \(task.id) - \(task.status.rawValue) - \"\(task.subject)\"",
                isError: false
            )
        } catch let error as TaskStoreError {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}

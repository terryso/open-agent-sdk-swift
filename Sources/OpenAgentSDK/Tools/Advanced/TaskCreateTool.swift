import Foundation

// MARK: - TaskCreateTool Input

/// Input type for the TaskCreate tool.
///
/// Field names match the TS SDK's TaskCreate schema.
private struct TaskCreateInput: Codable {
    let subject: String       // Required
    let description: String?  // Optional
    let owner: String?        // Optional
    let status: String?       // Optional, "pending" or "in_progress"
}

// MARK: - TaskCreateTool Schema

private nonisolated(unsafe) let taskCreateSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "subject": ["type": "string", "description": "Short task title"] as [String: Any],
        "description": ["type": "string", "description": "Detailed task description"] as [String: Any],
        "owner": ["type": "string", "description": "Task owner/assignee"] as [String: Any],
        "status": ["type": "string", "enum": ["pending", "in_progress"], "description": "Initial status"] as [String: Any],
    ] as [String: Any],
    "required": ["subject"]
]

// MARK: - Factory Function

/// Creates the TaskCreate tool for creating new tasks in the task store.
///
/// The TaskCreate tool allows agents to create tasks with a subject and optional
/// description, owner, and initial status. Tasks default to "pending" status if
/// no status is provided.
///
/// **Architecture:** This tool uses ``ToolContext/taskStore`` (injected by Core/)
/// to access task management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the TaskCreate tool.
public func createTaskCreateTool() -> ToolProtocol {
    return defineTool(
        name: "TaskCreate",
        description: "Create a new task for tracking work progress. Tasks help organize multi-step operations.",
        inputSchema: taskCreateSchema,
        isReadOnly: false
    ) { (input: TaskCreateInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        let initialStatus: TaskStatus = input.status.flatMap { TaskStatus.parse($0) } ?? .pending
        let task = await taskStore.create(
            subject: input.subject,
            description: input.description,
            owner: input.owner,
            status: initialStatus
        )
        return ToolExecuteResult(
            content: "Task created: \(task.id) - \"\(task.subject)\" (\(task.status.rawValue))",
            isError: false
        )
    }
}

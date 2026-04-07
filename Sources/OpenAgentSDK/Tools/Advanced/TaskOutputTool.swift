import Foundation

// MARK: - TaskOutputTool Input

/// Input type for the TaskOutput tool.
///
/// Field names match the TS SDK's TaskOutput schema.
private struct TaskOutputInput: Codable {
    let id: String            // Required
}

// MARK: - TaskOutputTool Schema

private nonisolated(unsafe) let taskOutputSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": ["type": "string", "description": "Task ID"] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]

// MARK: - Factory Function

/// Creates the TaskOutput tool for retrieving a task's output from the task store.
///
/// The TaskOutput tool allows agents to retrieve the output/result of a specific
/// task. If the task has no output yet, it returns "(no output yet)".
///
/// **Architecture:** This tool uses ``ToolContext/taskStore`` (injected by Core/)
/// to access task management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the TaskOutput tool.
public func createTaskOutputTool() -> ToolProtocol {
    return defineTool(
        name: "TaskOutput",
        description: "Get the output/result of a task.",
        inputSchema: taskOutputSchema,
        isReadOnly: true
    ) { (input: TaskOutputInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        guard let task = await taskStore.get(id: input.id) else {
            return ToolExecuteResult(content: "Task not found: \(input.id)", isError: true)
        }
        return ToolExecuteResult(content: task.output ?? "(no output yet)", isError: false)
    }
}

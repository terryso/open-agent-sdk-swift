import Foundation

// MARK: - TaskStopTool Input

/// Input type for the TaskStop tool.
///
/// Field names match the TS SDK's TaskStop schema.
private struct TaskStopInput: Codable {
    let id: String            // Required
    let reason: String?       // Optional
}

// MARK: - TaskStopTool Schema

private nonisolated(unsafe) let taskStopSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": ["type": "string", "description": "Task ID to stop"] as [String: Any],
        "reason": ["type": "string", "description": "Reason for stopping"] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]

// MARK: - Factory Function

/// Creates the TaskStop tool for stopping/cancelling tasks in the task store.
///
/// The TaskStop tool allows agents to cancel a running task by setting its status
/// to "cancelled". An optional reason can be provided, which is recorded in the
/// task's output field.
///
/// **Architecture:** This tool uses ``ToolContext/taskStore`` (injected by Core/)
/// to access task management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the TaskStop tool.
public func createTaskStopTool() -> ToolProtocol {
    return defineTool(
        name: "TaskStop",
        description: "Stop/cancel a running task.",
        inputSchema: taskStopSchema,
        isReadOnly: false
    ) { (input: TaskStopInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        let stopOutput = input.reason.map { "Stopped: \($0)" }
        do {
            _ = try await taskStore.update(id: input.id, status: .cancelled, output: stopOutput)
            return ToolExecuteResult(content: "Task stopped: \(input.id)", isError: false)
        } catch let error as TaskStoreError {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}

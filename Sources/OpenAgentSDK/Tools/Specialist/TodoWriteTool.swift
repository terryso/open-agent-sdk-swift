import Foundation

// MARK: - TodoWrite Input

/// Input type for the TodoWrite tool.
///
/// Field names match the TS SDK's TodoWrite schema.
/// Uses a single `action` field to dispatch to add/toggle/remove/list/clear operations.
private struct TodoWriteInput: Codable {
    let action: String       // Required: add / toggle / remove / list / clear
    let text: String?        // Optional: used by add operation
    let id: Int?             // Optional: used by toggle/remove operations
    let priority: String?    // Optional: used by add operation (high/medium/low)
}

// MARK: - TodoWrite Schema

private nonisolated(unsafe) let todoWriteSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "action": [
            "type": "string",
            "enum": ["add", "toggle", "remove", "list", "clear"],
            "description": "Operation to perform"
        ] as [String: Any],
        "text": [
            "type": "string",
            "description": "Todo item text (for add)"
        ] as [String: Any],
        "id": [
            "type": "number",
            "description": "Todo item ID (for toggle/remove)"
        ] as [String: Any],
        "priority": [
            "type": "string",
            "enum": ["high", "medium", "low"],
            "description": "Priority level (for add)"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["action"]
]

// MARK: - TodoWrite Factory Function

/// Creates the TodoWrite tool for managing a session todo/checklist.
///
/// The TodoWrite tool supports add, toggle, remove, list, and clear operations
/// through a single `action` field, matching the TS SDK's design.
///
/// **Architecture:** This tool uses ``ToolContext/todoStore`` (injected by Core/)
/// to access todo management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the TodoWrite tool.
public func createTodoWriteTool() -> ToolProtocol {
    return defineTool(
        name: "TodoWrite",
        description: "Manage a session todo/checklist. Supports add, toggle, remove, list, and clear operations.",
        inputSchema: todoWriteSchema,
        isReadOnly: false
    ) { (input: TodoWriteInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let todoStore = context.todoStore else {
            return ToolExecuteResult(content: "Error: TodoStore not available.", isError: true)
        }

        switch input.action {
        case "add":
            guard let text = input.text, !text.isEmpty else {
                return ToolExecuteResult(content: "text required", isError: true)
            }
            let priority = input.priority.flatMap { TodoPriority(rawValue: $0) }
            let item = await todoStore.add(text: text, priority: priority)
            return ToolExecuteResult(content: "Todo added: #\(item.id) \"\(item.text)\"", isError: false)

        case "toggle":
            guard let id = input.id else {
                return ToolExecuteResult(content: "id required for toggle", isError: true)
            }
            do {
                let item = try await todoStore.toggle(id: id)
                return ToolExecuteResult(content: "Todo #\(item.id) \(item.done ? "completed" : "reopened")", isError: false)
            } catch let error as TodoStoreError {
                return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
            }

        case "remove":
            guard let id = input.id else {
                return ToolExecuteResult(content: "id required for remove", isError: true)
            }
            do {
                let item = try await todoStore.remove(id: id)
                return ToolExecuteResult(content: "Todo #\(item.id) removed", isError: false)
            } catch let error as TodoStoreError {
                return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
            }

        case "list":
            let items = await todoStore.list()
            if items.isEmpty {
                return ToolExecuteResult(content: "No todos.", isError: false)
            }
            let lines = items.map { t in
                let check = t.done ? "[x]" : "[ ]"
                let prio = t.priority.map { " (\($0.rawValue))" } ?? ""
                return "\(check) #\(t.id) \(t.text)\(prio)"
            }
            return ToolExecuteResult(content: lines.joined(separator: "\n"), isError: false)

        case "clear":
            await todoStore.clear()
            return ToolExecuteResult(content: "All todos cleared.", isError: false)

        default:
            return ToolExecuteResult(content: "Unknown action: \(input.action)", isError: true)
        }
    }
}

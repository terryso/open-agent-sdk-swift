import Foundation

// MARK: - EnterWorktree Input

/// Input type for the EnterWorktree tool.
///
/// Field names match the TS SDK's EnterWorktree schema.
private struct EnterWorktreeInput: Codable {
    let name: String  // Required
}

// MARK: - ExitWorktree Input

/// Input type for the ExitWorktree tool.
///
/// Field names match the TS SDK's ExitWorktree schema.
private struct ExitWorktreeInput: Codable {
    let id: String              // Required
    let action: String?         // Optional: "keep" or "remove", default "remove"
    let discard_changes: Bool?  // Optional: default true for remove action
}

// MARK: - EnterWorktree Schema

private nonisolated(unsafe) let enterWorktreeSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "name": [
            "type": "string",
            "description": "Name for the worktree. Used to create branch and directory name."
        ] as [String: Any],
    ] as [String: Any],
    "required": ["name"]
]

// MARK: - ExitWorktree Schema

private nonisolated(unsafe) let exitWorktreeSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": [
            "type": "string",
            "description": "Worktree ID to exit from"
        ] as [String: Any],
        "action": [
            "type": "string",
            "enum": ["keep", "remove"],
            "description": "Whether to keep or remove the worktree directory. Default: remove"
        ] as [String: Any],
        "discard_changes": [
            "type": "boolean",
            "description": "Whether to discard uncommitted changes when removing. Default: true"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]

// MARK: - EnterWorktree Factory Function

/// Creates the EnterWorktree tool for creating isolated git worktrees.
///
/// The EnterWorktree tool creates a new git worktree in `.claude/worktrees/<name>`,
/// allowing the agent to work on an isolated copy of the repository.
///
/// **Architecture:** This tool uses ``ToolContext/worktreeStore`` (injected by Core/)
/// to access worktree management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the EnterWorktree tool.
public func createEnterWorktreeTool() -> ToolProtocol {
    return defineTool(
        name: "EnterWorktree",
        description: "Create an isolated git worktree for parallel work. The agent will work in the worktree without affecting the main working tree.",
        inputSchema: enterWorktreeSchema,
        isReadOnly: false
    ) { (input: EnterWorktreeInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let worktreeStore = context.worktreeStore else {
            return ToolExecuteResult(content: "Error: WorktreeStore not available.", isError: true)
        }
        do {
            let entry = try await worktreeStore.create(
                name: input.name,
                originalCwd: context.cwd
            )
            return ToolExecuteResult(
                content: "Worktree created: \(entry.id) at \(entry.path) (branch: \(entry.branch))",
                isError: false
            )
        } catch let error as WorktreeStoreError {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        } catch {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - ExitWorktree Factory Function

/// Creates the ExitWorktree tool for exiting and optionally removing git worktrees.
///
/// The ExitWorktree tool removes a tracked worktree. When `action` is `"remove"` (default),
/// the worktree directory is deleted. When `action` is `"keep"`, only the tracking
/// entry is removed, leaving the worktree directory on disk.
///
/// **Architecture:** This tool uses ``ToolContext/worktreeStore`` (injected by Core/)
/// to access worktree management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the ExitWorktree tool.
public func createExitWorktreeTool() -> ToolProtocol {
    return defineTool(
        name: "ExitWorktree",
        description: "Exit and optionally remove a git worktree, returning to the original working directory.",
        inputSchema: exitWorktreeSchema,
        isReadOnly: false
    ) { (input: ExitWorktreeInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let worktreeStore = context.worktreeStore else {
            return ToolExecuteResult(content: "Error: WorktreeStore not available.", isError: true)
        }
        let action = input.action ?? "remove"
        do {
            if action == "keep" {
                _ = try await worktreeStore.keep(id: input.id)
                return ToolExecuteResult(content: "Worktree kept: \(input.id)", isError: false)
            } else {
                let discard = input.discard_changes ?? true
                _ = try await worktreeStore.remove(id: input.id, force: discard)
                return ToolExecuteResult(content: "Worktree removed: \(input.id)", isError: false)
            }
        } catch let error as WorktreeStoreError {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        } catch {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}

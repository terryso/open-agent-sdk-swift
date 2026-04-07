import Foundation

// MARK: - CronCreate Input

/// Input type for the CronCreate tool.
///
/// Field names match the TS SDK's CronCreate schema.
private struct CronCreateInput: Codable {
    let name: String
    let schedule: String
    let command: String
}

// MARK: - CronDelete Input

/// Input type for the CronDelete tool.
///
/// Field names match the TS SDK's CronDelete schema.
private struct CronDeleteInput: Codable {
    let id: String
}

// MARK: - CronList Input

/// Input type for the CronList tool.
///
/// CronList has no input fields (empty properties).
private struct CronListInput: Codable {}

// MARK: - CronCreate Schema

private nonisolated(unsafe) let cronCreateSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "name": [
            "type": "string",
            "description": "Job name"
        ] as [String: Any],
        "schedule": [
            "type": "string",
            "description": "Cron expression (e.g., \"*/5 * * * *\" for every 5 minutes)"
        ] as [String: Any],
        "command": [
            "type": "string",
            "description": "Command or prompt to execute"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["name", "schedule", "command"]
]

// MARK: - CronDelete Schema

private nonisolated(unsafe) let cronDeleteSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": [
            "type": "string",
            "description": "Cron job ID to delete"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]

// MARK: - CronList Schema

private nonisolated(unsafe) let cronListSchema: ToolInputSchema = [
    "type": "object",
    "properties": [:] as [String: Any]
]

// MARK: - CronCreate Factory Function

/// Creates the CronCreate tool for scheduling recurring tasks.
///
/// The CronCreate tool creates a new cron job entry in the ``CronStore``,
/// with an auto-generated ID, the given name, schedule (cron expression),
/// and command. The job is created with `enabled: true`.
///
/// **Architecture:** This tool uses ``ToolContext/cronStore`` (injected by Core/)
/// to access cron management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the CronCreate tool.
public func createCronCreateTool() -> ToolProtocol {
    return defineTool(
        name: "CronCreate",
        description: "Create a scheduled recurring task (cron job). Supports cron expressions for scheduling.",
        inputSchema: cronCreateSchema,
        isReadOnly: false
    ) { (input: CronCreateInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let cronStore = context.cronStore else {
            return ToolExecuteResult(content: "Error: CronStore not available.", isError: true)
        }
        let job = await cronStore.create(name: input.name, schedule: input.schedule, command: input.command)
        return ToolExecuteResult(
            content: "Cron job created: \(job.id) \"\(job.name)\" schedule=\"\(job.schedule)\"",
            isError: false
        )
    }
}

// MARK: - CronDelete Factory Function

/// Creates the CronDelete tool for deleting scheduled cron jobs.
///
/// The CronDelete tool removes a cron job from the ``CronStore`` by ID.
/// If the job does not exist, it returns an error result.
///
/// **Architecture:** This tool uses ``ToolContext/cronStore`` (injected by Core/)
/// to access cron management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the CronDelete tool.
public func createCronDeleteTool() -> ToolProtocol {
    return defineTool(
        name: "CronDelete",
        description: "Delete a scheduled cron job.",
        inputSchema: cronDeleteSchema,
        isReadOnly: false
    ) { (input: CronDeleteInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let cronStore = context.cronStore else {
            return ToolExecuteResult(content: "Error: CronStore not available.", isError: true)
        }
        do {
            _ = try await cronStore.delete(id: input.id)
            return ToolExecuteResult(content: "Cron job deleted: \(input.id)", isError: false)
        } catch let error as CronStoreError {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CronList Factory Function

/// Creates the CronList tool for listing all scheduled cron jobs.
///
/// The CronList tool returns a formatted list of all cron jobs in the ``CronStore``.
/// When no jobs are scheduled, it returns a "No cron jobs scheduled." message.
///
/// **Architecture:** This tool uses ``ToolContext/cronStore`` (injected by Core/)
/// to access cron management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the CronList tool.
public func createCronListTool() -> ToolProtocol {
    return defineTool(
        name: "CronList",
        description: "List all scheduled cron jobs.",
        inputSchema: cronListSchema,
        isReadOnly: true
    ) { (input: CronListInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let cronStore = context.cronStore else {
            return ToolExecuteResult(content: "Error: CronStore not available.", isError: true)
        }
        let jobs = await cronStore.list()
        if jobs.isEmpty {
            return ToolExecuteResult(content: "No cron jobs scheduled.", isError: false)
        }
        let lines = jobs.map { j in
            let check = j.enabled ? "\u{2713}" : "\u{2717}"
            let truncatedCommand = String(j.command.prefix(50))
            return "[\(j.id)] \(check) \"\(j.name)\" schedule=\"\(j.schedule)\" command=\"\(truncatedCommand)\""
        }
        return ToolExecuteResult(content: lines.joined(separator: "\n"), isError: false)
    }
}

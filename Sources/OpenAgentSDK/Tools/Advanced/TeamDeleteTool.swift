import Foundation

// MARK: - TeamDeleteTool Input

/// Input type for the TeamDelete tool.
///
/// Field names match the TS SDK's TeamDelete schema.
private struct TeamDeleteInput: Codable {
    let id: String  // Required
}

// MARK: - TeamDeleteTool Schema

private nonisolated(unsafe) let teamDeleteSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": ["type": "string", "description": "Team ID to disband"] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]

// MARK: - Factory Function

/// Creates the TeamDelete tool for disbanding teams.
///
/// The TeamDelete tool allows agents to disband (delete) a team by its ID.
/// It validates the team exists and is not already disbanded before removal.
///
/// **Architecture:** This tool uses ``ToolContext/teamStore`` (injected by Core/)
/// to access team management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the TeamDelete tool.
public func createTeamDeleteTool() -> ToolProtocol {
    return defineTool(
        name: "TeamDelete",
        description: "Disband a team and clean up resources.",
        inputSchema: teamDeleteSchema,
        isReadOnly: false
    ) { (input: TeamDeleteInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let teamStore = context.teamStore else {
            return ToolExecuteResult(content: "Error: TeamStore not available.", isError: true)
        }
        do {
            let team = await teamStore.get(id: input.id)
            let teamName = team?.name ?? input.id
            _ = try await teamStore.delete(id: input.id)
            return ToolExecuteResult(content: "Team disbanded: \(teamName)", isError: false)
        } catch let error as TeamStoreError {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}

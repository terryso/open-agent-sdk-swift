import Foundation

// MARK: - TeamCreateTool Input

/// Input type for the TeamCreate tool.
///
/// Field names match the TS SDK's TeamCreate schema.
private struct TeamCreateInput: Codable {
    let name: String                // Required
    let members: [String]?          // Optional, member name array
    let task_description: String?   // Optional, matches TS SDK schema field name
}

// MARK: - TeamCreateTool Schema

private nonisolated(unsafe) let teamCreateSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "name": ["type": "string", "description": "Team name"] as [String: Any],
        "members": [
            "type": "array",
            "items": ["type": "string"] as [String: Any],
            "description": "List of agent/teammate names"
        ] as [String: Any],
        "task_description": ["type": "string", "description": "Description of the team's mission"] as [String: Any],
    ] as [String: Any],
    "required": ["name"]
]

// MARK: - Factory Function

/// Creates the TeamCreate tool for creating multi-agent teams.
///
/// The TeamCreate tool allows agents to create a new team with a name and optional
/// member list. Members are specified as name strings and converted to ``TeamMember``
/// instances with a default ``TeamRole/member`` role.
///
/// **Architecture:** This tool uses ``ToolContext/teamStore`` (injected by Core/)
/// to access team management infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the TeamCreate tool.
public func createTeamCreateTool() -> ToolProtocol {
    return defineTool(
        name: "TeamCreate",
        description: "Create a multi-agent team for coordinated work. Assigns a lead and manages member composition.",
        inputSchema: teamCreateSchema,
        isReadOnly: false
    ) { (input: TeamCreateInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let teamStore = context.teamStore else {
            return ToolExecuteResult(content: "Error: TeamStore not available.", isError: true)
        }
        let members: [TeamMember] = input.members?.map { TeamMember(name: $0) } ?? []
        let team = await teamStore.create(
            name: input.name,
            members: members,
            leaderId: "self"
        )
        return ToolExecuteResult(
            content: "Team created: \(team.id) \"\(team.name)\" with \(team.members.count) members",
            isError: false
        )
    }
}

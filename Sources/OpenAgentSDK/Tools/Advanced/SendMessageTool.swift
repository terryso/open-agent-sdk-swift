import Foundation

// MARK: - SendMessageTool Input

/// Input type for the SendMessage tool.
///
/// Field names match the TS SDK's SendMessage schema.
private struct SendMessageInput: Codable {
    let to: String        // Teammate name or "*" for broadcast
    let message: String   // Message content
}

// MARK: - SendMessageTool Schema

private nonisolated(unsafe) let sendMessageToolSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "to": ["type": "string", "description": "Recipient: teammate name, or \"*\" for broadcast to all teammates"] as [String: Any],
        "message": ["type": "string", "description": "Plain text message to send"] as [String: Any],
    ] as [String: Any],
    "required": ["to", "message"]
]

// MARK: - Factory Function

/// Creates the SendMessage tool for inter-agent communication within a team.
///
/// The SendMessage tool allows agents to send direct or broadcast messages
/// to teammates. It validates team membership and delivers messages through
/// the ``MailboxStore`` actor.
///
/// **Architecture:** This tool uses ``ToolContext/mailboxStore``,
/// ``ToolContext/teamStore``, and ``ToolContext/senderName`` (injected by Core/)
/// to access messaging and team infrastructure without importing Core/ or Stores/.
///
/// - Returns: A ``ToolProtocol`` instance for the SendMessage tool.
public func createSendMessageTool() -> ToolProtocol {
    return defineTool(
        name: "SendMessage",
        description: "Send a message to another agent in the team. Use teammate name for direct message or \"*\" to broadcast to all teammates.",
        inputSchema: sendMessageToolSchema,
        isReadOnly: false
    ) { (input: SendMessageInput, context: ToolContext) async throws -> ToolExecuteResult in
        // Guard: MailboxStore must be available
        guard let mailboxStore = context.mailboxStore else {
            return ToolExecuteResult(
                content: "Error: MailboxStore not available. The SendMessage tool requires messaging infrastructure.",
                isError: true
            )
        }

        // Guard: TeamStore must be available
        guard let teamStore = context.teamStore else {
            return ToolExecuteResult(
                content: "Error: TeamStore not available. The SendMessage tool requires team management.",
                isError: true
            )
        }

        // Guard: Sender name must be available
        guard let senderName = context.senderName else {
            return ToolExecuteResult(
                content: "Error: Sender name not available. The SendMessage tool requires agent identity.",
                isError: true
            )
        }

        // Find the sender's team
        guard let team = await teamStore.getTeamForAgent(agentName: senderName) else {
            return ToolExecuteResult(
                content: "Error: Agent '\(senderName)' is not a member of any team.",
                isError: true
            )
        }

        if input.to == "*" {
            // Broadcast to all teammates
            await mailboxStore.broadcast(from: senderName, content: input.message)
            return ToolExecuteResult(
                content: "Message broadcast to all teammates in team '\(team.name)'.",
                isError: false
            )
        }

        // Validate recipient is a team member
        let isMember = team.members.contains { $0.name == input.to }
        guard isMember else {
            let memberList = team.members.map { $0.name }.joined(separator: ", ")
            return ToolExecuteResult(
                content: "Error: '\(input.to)' is not a member of team '\(team.name)'. Available members: \(memberList).",
                isError: true
            )
        }

        // Send direct message
        await mailboxStore.send(from: senderName, to: input.to, content: input.message)
        return ToolExecuteResult(
            content: "Message sent to \(input.to).",
            isError: false
        )
    }
}

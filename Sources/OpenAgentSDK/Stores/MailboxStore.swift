import Foundation

/// Thread-safe mailbox store for inter-agent messaging.
public actor MailboxStore {

    // MARK: - Properties

    private var mailboxes: [String: [AgentMessage]] = [:]
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Send a message to a specific agent.
    public func send(from: String, to: String, content: String, type: AgentMessageType = .text) {
        let message = AgentMessage(
            from: from,
            to: to,
            content: content,
            timestamp: dateFormatter.string(from: Date()),
            type: type
        )
        if mailboxes[to] == nil {
            mailboxes[to] = []
        }
        mailboxes[to]?.append(message)
    }

    /// Broadcast a message to all known agents (agents with existing mailboxes).
    public func broadcast(from: String, content: String, type: AgentMessageType = .text) {
        let timestamp = dateFormatter.string(from: Date())
        for (agentName, _) in mailboxes {
            let message = AgentMessage(
                from: from,
                to: agentName,
                content: content,
                timestamp: timestamp,
                type: type
            )
            mailboxes[agentName]?.append(message)
        }
    }

    /// Read all messages for an agent and clear the mailbox.
    /// - Returns: All pending messages for the agent (empty array if none).
    public func read(agentName: String) -> [AgentMessage] {
        guard let messages = mailboxes[agentName] else {
            return []
        }
        mailboxes[agentName] = []
        return messages
    }

    /// Check whether an agent has pending messages.
    public func hasMessages(for agentName: String) -> Bool {
        guard let messages = mailboxes[agentName] else { return false }
        return !messages.isEmpty
    }

    /// Clear a specific agent's mailbox.
    public func clear(agentName: String) {
        guard mailboxes[agentName] != nil else { return }
        mailboxes[agentName] = []
    }

    /// Clear all mailboxes.
    public func clearAll() {
        for (agentName, _) in mailboxes {
            mailboxes[agentName] = []
        }
    }
}

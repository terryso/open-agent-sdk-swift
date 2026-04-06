import Foundation

// MARK: - TaskStatus

/// Status of a task in the task store.
public enum TaskStatus: String, Sendable, Equatable, Codable, CaseIterable {
    case pending
    case inProgress
    case completed
    case failed
    case cancelled
}

// MARK: - Task

/// A task entry in the task store.
public struct Task: Sendable, Equatable, Codable {
    public let id: String
    public var subject: String
    public var description: String?
    public var status: TaskStatus
    public var owner: String?
    public let createdAt: String
    public var updatedAt: String
    public var output: String?
    public var blockedBy: [String]?
    public var blocks: [String]?
    public var metadata: [String: String]?

    public init(
        id: String,
        subject: String,
        description: String? = nil,
        status: TaskStatus = .pending,
        owner: String? = nil,
        createdAt: String,
        updatedAt: String,
        output: String? = nil,
        blockedBy: [String]? = nil,
        blocks: [String]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.subject = subject
        self.description = description
        self.status = status
        self.owner = owner
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.output = output
        self.blockedBy = blockedBy
        self.blocks = blocks
        self.metadata = metadata
    }
}

// MARK: - AgentMessageType

/// Type of inter-agent message.
public enum AgentMessageType: String, Sendable, Equatable, Codable {
    case text
    case shutdownRequest
    case shutdownResponse
    case planApprovalResponse
}

// MARK: - AgentMessage

/// A message in the inter-agent mailbox system.
public struct AgentMessage: Sendable, Equatable, Codable {
    public let from: String
    public let to: String
    public let content: String
    public let timestamp: String
    public let type: AgentMessageType

    public init(
        from: String,
        to: String,
        content: String,
        timestamp: String,
        type: AgentMessageType = .text
    ) {
        self.from = from
        self.to = to
        self.content = content
        self.timestamp = timestamp
        self.type = type
    }
}

// MARK: - TaskStoreError

/// Errors thrown by TaskStore operations.
public enum TaskStoreError: Error, Equatable, LocalizedError, Sendable {
    case taskNotFound(id: String)
    case invalidStatusTransition(from: TaskStatus, to: TaskStatus)

    public var errorDescription: String? {
        switch self {
        case .taskNotFound(let id):
            return "Task not found: \(id)"
        case .invalidStatusTransition(let from, let to):
            return "Cannot transition task from \(from.rawValue) to \(to.rawValue)"
        }
    }
}

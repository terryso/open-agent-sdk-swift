import Foundation

// MARK: - TaskStatus

/// Status of a task in the task store.
public enum TaskStatus: String, Sendable, Equatable, Codable, CaseIterable {
    case pending
    case inProgress
    case completed
    case failed
    case cancelled

    /// Parse a status string, accepting both camelCase ("inProgress") and snake_case ("in_progress").
    public static func parse(_ string: String) -> TaskStatus? {
        if let direct = TaskStatus(rawValue: string) { return direct }
        // Convert snake_case to camelCase and retry
        let camel = string
            .split(separator: "_")
            .enumerated()
            .map { $0.offset == 0 ? String($0.element) : String($0.element).capitalized }
            .joined()
        return TaskStatus(rawValue: camel)
    }
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

// MARK: - TeamStatus

/// Status of a team in the team store.
public enum TeamStatus: String, Sendable, Equatable, Codable, CaseIterable {
    case active
    case disbanded
}

// MARK: - TeamRole

/// Role of a member within a team.
public enum TeamRole: String, Sendable, Equatable, Codable, CaseIterable {
    case leader
    case member
}

// MARK: - TeamMember

/// A member in a team.
public struct TeamMember: Sendable, Equatable, Codable {
    public let name: String
    public let role: TeamRole

    public init(name: String, role: TeamRole = .member) {
        self.name = name
        self.role = role
    }
}

// MARK: - Team

/// A team in the multi-agent coordination system.
public struct Team: Sendable, Equatable, Codable {
    public let id: String
    public let name: String
    public var members: [TeamMember]
    public let leaderId: String
    public let createdAt: String  // ISO 8601
    public var status: TeamStatus

    public init(
        id: String,
        name: String,
        members: [TeamMember] = [],
        leaderId: String = "self",
        createdAt: String,
        status: TeamStatus = .active
    ) {
        self.id = id
        self.name = name
        self.members = members
        self.leaderId = leaderId
        self.createdAt = createdAt
        self.status = status
    }
}

// MARK: - AgentRegistryEntry

/// An entry in the agent registry for tracking active sub-agents.
public struct AgentRegistryEntry: Sendable, Equatable, Codable {
    public let agentId: String
    public let name: String
    public let agentType: String
    public let registeredAt: String  // ISO 8601

    public init(
        agentId: String,
        name: String,
        agentType: String,
        registeredAt: String
    ) {
        self.agentId = agentId
        self.name = name
        self.agentType = agentType
        self.registeredAt = registeredAt
    }
}

// MARK: - TeamStoreError

/// Errors thrown by TeamStore operations.
public enum TeamStoreError: Error, Equatable, LocalizedError, Sendable {
    case teamNotFound(id: String)
    case teamAlreadyDisbanded(id: String)
    case memberNotFound(teamId: String, memberName: String)

    public var errorDescription: String? {
        switch self {
        case .teamNotFound(let id):
            return "Team not found: \(id)"
        case .teamAlreadyDisbanded(let id):
            return "Team already disbanded: \(id)"
        case .memberNotFound(let teamId, let memberName):
            return "Member '\(memberName)' not found in team \(teamId)"
        }
    }
}

// MARK: - AgentRegistryError

/// Errors thrown by AgentRegistry operations.
public enum AgentRegistryError: Error, Equatable, LocalizedError, Sendable {
    case agentNotFound(id: String)
    case duplicateAgentName(name: String)

    public var errorDescription: String? {
        switch self {
        case .agentNotFound(let id):
            return "Agent not found: \(id)"
        case .duplicateAgentName(let name):
            return "Agent with name '\(name)' is already registered"
        }
    }
}

// MARK: - WorktreeStatus

/// Status of a worktree entry.
public enum WorktreeStatus: String, Sendable, Equatable, Codable {
    case active
    case removed
}

// MARK: - WorktreeEntry

/// A worktree entry tracked by the WorktreeStore.
public struct WorktreeEntry: Sendable, Equatable, Codable {
    public let id: String
    public let path: String
    public let branch: String
    public let originalCwd: String
    public let createdAt: String
    public var status: WorktreeStatus

    public init(
        id: String,
        path: String,
        branch: String,
        originalCwd: String,
        createdAt: String,
        status: WorktreeStatus = .active
    ) {
        self.id = id
        self.path = path
        self.branch = branch
        self.originalCwd = originalCwd
        self.createdAt = createdAt
        self.status = status
    }
}

// MARK: - WorktreeStoreError

/// Errors thrown by WorktreeStore operations.
public enum WorktreeStoreError: Error, Equatable, LocalizedError, Sendable {
    case worktreeNotFound(id: String)
    case gitCommandFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .worktreeNotFound(let id):
            return "Worktree not found: \(id)"
        case .gitCommandFailed(let message):
            return "Git command failed: \(message)"
        }
    }
}

// MARK: - PlanStatus

/// Status of a plan entry.
public enum PlanStatus: String, Sendable, Equatable, Codable {
    case active
    case completed
    case discarded
}

// MARK: - PlanEntry

/// A plan entry tracked by the PlanStore.
public struct PlanEntry: Sendable, Equatable, Codable {
    public let id: String
    public var content: String?
    public var approved: Bool
    public var status: PlanStatus
    public let createdAt: String
    public var updatedAt: String

    public init(
        id: String,
        content: String? = nil,
        approved: Bool = false,
        status: PlanStatus = .active,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.content = content
        self.approved = approved
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - PlanStoreError

/// Errors thrown by PlanStore operations.
public enum PlanStoreError: Error, Equatable, LocalizedError, Sendable {
    case planNotFound(id: String)
    case noActivePlan
    case alreadyInPlanMode

    public var errorDescription: String? {
        switch self {
        case .planNotFound(let id):
            return "Plan not found: \(id)"
        case .noActivePlan:
            return "No active plan. Enter plan mode first."
        case .alreadyInPlanMode:
            return "Already in plan mode."
        }
    }
}

// MARK: - CronJob

/// A cron job tracked by the CronStore.
public struct CronJob: Sendable, Equatable, Codable {
    public let id: String
    public let name: String
    public let schedule: String
    public let command: String
    public var enabled: Bool
    public let createdAt: String
    public var lastRunAt: String?
    public var nextRunAt: String?

    public init(
        id: String,
        name: String,
        schedule: String,
        command: String,
        enabled: Bool = true,
        createdAt: String,
        lastRunAt: String? = nil,
        nextRunAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.schedule = schedule
        self.command = command
        self.enabled = enabled
        self.createdAt = createdAt
        self.lastRunAt = lastRunAt
        self.nextRunAt = nextRunAt
    }
}

// MARK: - CronStoreError

/// Errors thrown by CronStore operations.
public enum CronStoreError: Error, Equatable, LocalizedError, Sendable {
    case cronJobNotFound(id: String)

    public var errorDescription: String? {
        switch self {
        case .cronJobNotFound(let id):
            return "Cron job not found: \(id)"
        }
    }
}

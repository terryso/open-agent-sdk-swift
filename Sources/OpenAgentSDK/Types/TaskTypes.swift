import Foundation

// MARK: - TaskStatus

/// Status of a task in the task store.
///
/// Tasks progress through a state machine: `pending` -> `inProgress` -> `completed`/`failed`/`cancelled`.
/// Terminal states (`completed`, `failed`, `cancelled`) cannot transition further.
public enum TaskStatus: String, Sendable, Equatable, Codable, CaseIterable {
    /// The task is waiting to be started.
    case pending
    /// The task is currently being worked on.
    case inProgress
    /// The task has been completed successfully.
    case completed
    /// The task has failed.
    case failed
    /// The task has been cancelled.
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
///
/// Tasks track work items with status, ownership, dependencies, and metadata.
/// Created via ``TaskStore/create(subject:description:owner:status:)``.
public struct Task: Sendable, Equatable, Codable {
    /// The unique task identifier (e.g., "task_1").
    public let id: String
    /// A brief title for the task.
    public var subject: String
    /// An optional detailed description.
    public var description: String?
    /// The current task status.
    public var status: TaskStatus
    /// The agent or user assigned to this task.
    public var owner: String?
    /// ISO 8601 timestamp when the task was created.
    public let createdAt: String
    /// ISO 8601 timestamp when the task was last updated.
    public var updatedAt: String
    /// Optional output or result from the task.
    public var output: String?
    /// Task IDs that must complete before this task can start.
    public var blockedBy: [String]?
    /// Task IDs that this task blocks from starting.
    public var blocks: [String]?
    /// Optional key-value metadata.
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
///
/// Used by ``MailboxStore`` to categorize messages between agents.
public enum AgentMessageType: String, Sendable, Equatable, Codable {
    /// A plain text message.
    case text
    /// A request for the receiving agent to shut down.
    case shutdownRequest
    /// A response to a shutdown request.
    case shutdownResponse
    /// A response to a plan approval request.
    case planApprovalResponse
}

// MARK: - AgentMessage

/// A message in the inter-agent mailbox system.
///
/// Messages are sent via ``MailboxStore`` and contain sender/recipient info,
/// content, timestamp, and a message type.
public struct AgentMessage: Sendable, Equatable, Codable {
    /// The sender's agent name.
    public let from: String
    /// The recipient's agent name.
    public let to: String
    /// The message content.
    public let content: String
    /// ISO 8601 timestamp when the message was sent.
    public let timestamp: String
    /// The type of message.
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
    /// The team is active and operational.
    case active
    /// The team has been disbanded.
    case disbanded
}

// MARK: - TeamRole

/// Role of a member within a team.
public enum TeamRole: String, Sendable, Equatable, Codable, CaseIterable {
    /// The team leader with coordination responsibilities.
    case leader
    /// A regular team member.
    case member
}

// MARK: - TeamMember

/// A member in a team.
///
/// Each member has a name and a role within the team.
public struct TeamMember: Sendable, Equatable, Codable {
    /// The agent name of the team member.
    public let name: String
    /// The role of this member within the team.
    public let role: TeamRole

    public init(name: String, role: TeamRole = .member) {
        self.name = name
        self.role = role
    }
}

// MARK: - Team

/// A team in the multi-agent coordination system.
///
/// Teams group agents together with defined roles for coordinated work.
/// Created via ``TeamStore/create(name:members:leaderId:)``.
public struct Team: Sendable, Equatable, Codable {
    /// The unique team identifier.
    public let id: String
    /// The team name.
    public let name: String
    /// The members of the team.
    public var members: [TeamMember]
    /// The identifier of the team leader.
    public let leaderId: String
    /// ISO 8601 timestamp when the team was created.
    public let createdAt: String
    /// The current team status.
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
///
/// Contains identifying information about a registered agent including its ID,
/// name, type, and registration timestamp.
public struct AgentRegistryEntry: Sendable, Equatable, Codable {
    /// The unique agent identifier.
    public let agentId: String
    /// The human-readable agent name.
    public let name: String
    /// The agent type classification.
    public let agentType: String
    /// ISO 8601 timestamp when the agent was registered.
    public let registeredAt: String

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
    /// The worktree is active and tracked.
    case active
    /// The worktree has been removed from tracking.
    case removed
}

// MARK: - WorktreeEntry

/// A worktree entry tracked by the ``WorktreeStore``.
///
/// Represents a Git worktree created for isolated development work.
public struct WorktreeEntry: Sendable, Equatable, Codable {
    /// The unique worktree identifier.
    public let id: String
    /// The filesystem path of the worktree.
    public let path: String
    /// The Git branch name for the worktree.
    public let branch: String
    /// The original working directory where the worktree was created from.
    public let originalCwd: String
    /// ISO 8601 timestamp when the worktree was created.
    public let createdAt: String
    /// The current status of the worktree.
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
    /// The plan is currently active (in plan mode).
    case active
    /// The plan has been completed and approved.
    case completed
    /// The plan has been discarded.
    case discarded
}

// MARK: - PlanEntry

/// A plan entry tracked by the ``PlanStore``.
///
/// Plans capture structured planning content created during plan mode.
public struct PlanEntry: Sendable, Equatable, Codable {
    /// The unique plan identifier.
    public let id: String
    /// The plan content text.
    public var content: String?
    /// Whether the plan has been approved.
    public var approved: Bool
    /// The current plan status.
    public var status: PlanStatus
    /// ISO 8601 timestamp when the plan was created.
    public let createdAt: String
    /// ISO 8601 timestamp when the plan was last updated.
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

/// A cron job tracked by the ``CronStore``.
///
/// Represents a scheduled job with a cron expression, command, and execution tracking.
public struct CronJob: Sendable, Equatable, Codable {
    /// The unique cron job identifier.
    public let id: String
    /// A human-readable name for the job.
    public let name: String
    /// The cron expression (e.g., "*/5 * * * *").
    public let schedule: String
    /// The command or prompt to execute.
    public let command: String
    /// Whether the job is enabled. Defaults to `true`.
    public var enabled: Bool
    /// ISO 8601 timestamp when the job was created.
    public let createdAt: String
    /// ISO 8601 timestamp of the last run, if any.
    public var lastRunAt: String?
    /// ISO 8601 timestamp of the next scheduled run, if computed.
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

// MARK: - TodoPriority

/// Priority level for a todo item.
public enum TodoPriority: String, Sendable, Equatable, Codable, CaseIterable {
    /// High priority.
    case high
    /// Medium priority.
    case medium
    /// Low priority.
    case low
}

// MARK: - TodoItem

/// A todo item tracked by the ``TodoStore``.
///
/// Represents a checklist item with text, completion status, and optional priority.
public struct TodoItem: Sendable, Equatable, Codable {
    /// The unique numeric identifier.
    public let id: Int
    /// The todo item text.
    public let text: String
    /// Whether the item is completed.
    public var done: Bool
    /// Optional priority level.
    public var priority: TodoPriority?

    public init(
        id: Int,
        text: String,
        done: Bool = false,
        priority: TodoPriority? = nil
    ) {
        self.id = id
        self.text = text
        self.done = done
        self.priority = priority
    }
}

// MARK: - TodoStoreError

/// Errors thrown by TodoStore operations.
public enum TodoStoreError: Error, Equatable, LocalizedError, Sendable {
    case todoNotFound(id: Int)

    public var errorDescription: String? {
        switch self {
        case .todoNotFound(let id):
            return "Todo #\(id) not found"
        }
    }
}

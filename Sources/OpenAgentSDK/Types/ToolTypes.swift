import Foundation

/// JSON Schema dictionary type for tool input definitions.
public typealias ToolInputSchema = [String: Any]

/// Protocol defining a tool that can be executed by the agent.
public protocol ToolProtocol: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: ToolInputSchema { get }
    var isReadOnly: Bool { get }

    func call(input: Any, context: ToolContext) async -> ToolResult
}

/// Result returned from a tool execution.
public struct ToolResult: Sendable, Equatable {
    public let toolUseId: String
    public let content: String
    public let isError: Bool

    public init(toolUseId: String, content: String, isError: Bool) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}

/// Structured result returned by tool execution closures that need to
/// explicitly signal success or error.
public struct ToolExecuteResult: Sendable, Equatable {
    public let content: String
    public let isError: Bool

    public init(content: String, isError: Bool) {
        self.content = content
        self.isError = isError
    }
}

/// Context provided to tool executions.
public struct ToolContext: Sendable {
    public let cwd: String
    public let toolUseId: String
    /// Optional sub-agent spawner for tools that need to create child agents.
    /// Set by Core/ when AgentTool is registered. Nil when sub-agent spawning
    /// is not available (e.g., no Agent tool in the tool set).
    public let agentSpawner: (any SubAgentSpawner)?
    /// Optional mailbox store for inter-agent messaging tools (e.g., SendMessage).
    /// Injected by Core/ when the tool set includes messaging-capable tools.
    public let mailboxStore: MailboxStore?
    /// Optional team store for team lookup in messaging tools (e.g., SendMessage).
    /// Injected by Core/ when the tool set includes messaging-capable tools.
    public let teamStore: TeamStore?
    /// Optional sender name identifying the current agent in multi-agent scenarios.
    /// Used by messaging tools to identify the message sender.
    public let senderName: String?
    /// Optional task store for task management tools (e.g., TaskCreate, TaskList).
    /// Injected by Core/ when the tool set includes task management tools.
    public let taskStore: TaskStore?
    /// Optional worktree store for worktree management tools (e.g., EnterWorktree, ExitWorktree).
    /// Injected by Core/ when the tool set includes worktree management tools.
    public let worktreeStore: WorktreeStore?
    /// Optional plan store for plan management tools (e.g., EnterPlanMode, ExitPlanMode).
    /// Injected by Core/ when the tool set includes plan management tools.
    public let planStore: PlanStore?
    /// Optional cron store for cron management tools (e.g., CronCreate, CronDelete, CronList).
    /// Injected by Core/ when the tool set includes cron management tools.
    public let cronStore: CronStore?
    /// Optional todo store for todo management tools (e.g., TodoWrite).
    /// Injected by Core/ when the tool set includes todo management tools.
    public let todoStore: TodoStore?
    /// Optional hook registry for lifecycle event hooks.
    /// Injected by Core/ from AgentOptions.hookRegistry for use in ToolExecutor.
    public let hookRegistry: HookRegistry?
    /// Optional permission mode controlling tool execution behavior.
    /// Injected by Core/ from AgentOptions.permissionMode.
    public let permissionMode: PermissionMode?
    /// Optional permission check callback for custom authorization.
    /// Injected by Core/ from AgentOptions.canUseTool.
    public let canUseTool: CanUseToolFn?

    public init(
        cwd: String,
        toolUseId: String = "",
        agentSpawner: (any SubAgentSpawner)? = nil,
        mailboxStore: MailboxStore? = nil,
        teamStore: TeamStore? = nil,
        senderName: String? = nil,
        taskStore: TaskStore? = nil,
        worktreeStore: WorktreeStore? = nil,
        planStore: PlanStore? = nil,
        cronStore: CronStore? = nil,
        todoStore: TodoStore? = nil,
        hookRegistry: HookRegistry? = nil,
        permissionMode: PermissionMode? = nil,
        canUseTool: CanUseToolFn? = nil
    ) {
        self.cwd = cwd
        self.toolUseId = toolUseId
        self.agentSpawner = agentSpawner
        self.mailboxStore = mailboxStore
        self.teamStore = teamStore
        self.senderName = senderName
        self.taskStore = taskStore
        self.worktreeStore = worktreeStore
        self.planStore = planStore
        self.cronStore = cronStore
        self.todoStore = todoStore
        self.hookRegistry = hookRegistry
        self.permissionMode = permissionMode
        self.canUseTool = canUseTool
    }

    /// Returns a copy of this context with the toolUseId replaced.
    ///
    /// Used by ToolExecutor to preserve all injected stores while updating
    /// the per-call tool use ID.
    public func withToolUseId(_ id: String) -> ToolContext {
        ToolContext(
            cwd: cwd, toolUseId: id,
            agentSpawner: agentSpawner, mailboxStore: mailboxStore,
            teamStore: teamStore, senderName: senderName,
            taskStore: taskStore, worktreeStore: worktreeStore,
            planStore: planStore, cronStore: cronStore,
            todoStore: todoStore,
            hookRegistry: hookRegistry,
            permissionMode: permissionMode,
            canUseTool: canUseTool
        )
    }
}

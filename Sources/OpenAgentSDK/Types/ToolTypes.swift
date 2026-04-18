import Foundation

/// JSON Schema dictionary type for tool input definitions.
public typealias ToolInputSchema = [String: Any]

// MARK: - ToolAnnotations

/// Hints describing a tool's behavior, matching the Anthropic API tool annotations format.
///
/// These hints help the LLM decide when and how to invoke a tool. They are optional
/// and default to conservative values when not specified.
///
/// - Note: Defaults match the TypeScript SDK: `destructiveHint` defaults to `true`,
///         all others default to `false`.
public struct ToolAnnotations: Sendable, Equatable {
    /// If `true`, the tool only reads data without performing side effects.
    public let readOnlyHint: Bool

    /// If `true`, the tool may perform destructive (irreversible) operations.
    /// Defaults to `true` to be conservative — tools are assumed destructive unless
    /// explicitly annotated otherwise.
    public let destructiveHint: Bool

    /// If `true`, calling the tool with the same inputs multiple times produces
    /// the same result (no additional side effects).
    public let idempotentHint: Bool

    /// If `true`, the tool may interact with external entities or services
    /// beyond the local environment.
    public let openWorldHint: Bool

    public init(
        readOnlyHint: Bool = false,
        destructiveHint: Bool = true,
        idempotentHint: Bool = false,
        openWorldHint: Bool = false
    ) {
        self.readOnlyHint = readOnlyHint
        self.destructiveHint = destructiveHint
        self.idempotentHint = idempotentHint
        self.openWorldHint = openWorldHint
    }
}

// MARK: - ToolContent

/// Represents a typed content item in a tool result, supporting multi-modal responses.
///
/// Mirrors the Anthropic API's `content` array format for tool results,
/// which can contain text, images, and embedded resources.
public enum ToolContent: Sendable, Equatable {
    /// A plain text content block.
    case text(String)

    /// An image content block with raw data and MIME type.
    case image(data: Data, mimeType: String)

    /// A resource content block referencing an external resource by URI.
    case resource(uri: String, name: String?)
}

// MARK: - Typed Tool Output Structures

/// Typed output from a file read tool, providing structured access to file contents.
///
/// Maps to the TypeScript SDK's `ReadOutput` type.
public struct ReadOutput: Sendable, Equatable {
    /// The file path that was read.
    public let filePath: String
    /// The content of the file (cat -n formatted with line numbers).
    public let content: String

    public init(filePath: String, content: String) {
        self.filePath = filePath
        self.content = content
    }
}

/// Typed output from a file edit tool, providing structured patch information.
///
/// Maps to the TypeScript SDK's `EditOutput` type.
public struct EditOutput: Sendable, Equatable {
    /// The file path that was edited.
    public let filePath: String
    /// The old string that was replaced.
    public let oldContent: String
    /// The new string that replaced it.
    public let newContent: String
    /// Whether the edit replaced all occurrences.
    public let replaceAll: Bool
    /// Human-readable result message.
    public let message: String

    public init(filePath: String, oldContent: String, newContent: String, replaceAll: Bool = false, message: String = "") {
        self.filePath = filePath
        self.oldContent = oldContent
        self.newContent = newContent
        self.replaceAll = replaceAll
        self.message = message
    }
}

/// Typed output from a bash command execution, with separated stdout and stderr.
///
/// Maps to the TypeScript SDK's `BashOutput` type.
public struct BashOutput: Sendable, Equatable {
    /// Standard output from the command.
    public let stdout: String
    /// Standard error from the command.
    public let stderr: String
    /// Exit code of the command. `nil` if the command was terminated by signal.
    public let exitCode: Int32?
    /// Whether the command was interrupted.
    public let interrupted: Bool

    public init(stdout: String, stderr: String, exitCode: Int32?, interrupted: Bool = false) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.interrupted = interrupted
    }
}

// MARK: - ToolProtocol

/// Protocol defining a tool that can be executed by the agent.
public protocol ToolProtocol: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: ToolInputSchema { get }
    var isReadOnly: Bool { get }

    /// Optional hints describing the tool's behavior for LLM guidance.
    /// Defaults to `nil` via protocol extension; existing tools are unaffected.
    var annotations: ToolAnnotations? { get }

    func call(input: Any, context: ToolContext) async -> ToolResult
}

/// Default implementation so existing tool implementations compile without modification.
extension ToolProtocol {
    public var annotations: ToolAnnotations? { nil }
}

// MARK: - ToolResult

/// Result returned from a tool execution.
public struct ToolResult: Sendable, Equatable {
    public let toolUseId: String

    /// The stored plain-text content string (backward compatible).
    private let _content: String

    /// Optional typed content array for multi-modal tool responses.
    public let typedContent: [ToolContent]?

    /// Whether the tool execution resulted in an error.
    public let isError: Bool

    /// The text content of the result.
    ///
    /// When `typedContent` is set, this returns the concatenation of all `.text` items.
    /// When `typedContent` is `nil`, returns the stored string.
    public var content: String {
        if let typedContent {
            let textItems = typedContent.compactMap { item -> String? in
                if case .text(let text) = item { return text }
                return nil
            }
            if !textItems.isEmpty {
                return textItems.joined()
            }
        }
        return _content
    }

    /// Creates a `ToolResult` with plain text content (backward compatible).
    public init(toolUseId: String, content: String, isError: Bool) {
        self.toolUseId = toolUseId
        self._content = content
        self.typedContent = nil
        self.isError = isError
    }

    /// Creates a `ToolResult` with typed content items.
    ///
    /// The `content` computed property will derive its value from `.text` items
    /// in the `typedContent` array. If no `.text` items exist, falls back
    /// to an empty string.
    public init(toolUseId: String, typedContent: [ToolContent], isError: Bool) {
        self.toolUseId = toolUseId
        self._content = ""
        self.typedContent = typedContent
        self.isError = isError
    }

    /// Creates a `ToolResult` preserving both text content and typed content.
    ///
    /// Used by `ToolExecutor` when rewrapping `ToolExecuteResult` into `ToolResult`
    /// to avoid dropping typed content during the dispatch layer.
    init(toolUseId: String, content: String, typedContent: [ToolContent]?, isError: Bool) {
        self.toolUseId = toolUseId
        self._content = content
        self.typedContent = typedContent
        self.isError = isError
    }

    public static func == (lhs: ToolResult, rhs: ToolResult) -> Bool {
        lhs.toolUseId == rhs.toolUseId &&
        lhs.content == rhs.content &&
        lhs.typedContent == rhs.typedContent &&
        lhs.isError == rhs.isError
    }
}

// MARK: - ToolExecuteResult

/// Structured result returned by tool execution closures that need to
/// explicitly signal success or error.
public struct ToolExecuteResult: Sendable, Equatable {
    /// The stored plain-text content string (backward compatible).
    private let _content: String

    /// Optional typed content array for multi-modal tool responses.
    public let typedContent: [ToolContent]?

    /// Whether the tool execution resulted in an error.
    public let isError: Bool

    /// The text content of the result.
    ///
    /// When `typedContent` is set, this returns the concatenation of all `.text` items.
    /// When `typedContent` is `nil`, returns the stored string.
    public var content: String {
        if let typedContent {
            let textItems = typedContent.compactMap { item -> String? in
                if case .text(let text) = item { return text }
                return nil
            }
            if !textItems.isEmpty {
                return textItems.joined()
            }
        }
        return _content
    }

    /// Creates a `ToolExecuteResult` with plain text content (backward compatible).
    public init(content: String, isError: Bool) {
        self._content = content
        self.typedContent = nil
        self.isError = isError
    }

    /// Creates a `ToolExecuteResult` with typed content items.
    public init(typedContent: [ToolContent], isError: Bool) {
        self._content = ""
        self.typedContent = typedContent
        self.isError = isError
    }

    public static func == (lhs: ToolExecuteResult, rhs: ToolExecuteResult) -> Bool {
        lhs.content == rhs.content &&
        lhs.typedContent == rhs.typedContent &&
        lhs.isError == rhs.isError
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
    /// Optional skill registry for skill execution tools (SkillTool).
    /// Injected by Core/ from AgentOptions.skillRegistry.
    public let skillRegistry: SkillRegistry?
    /// Optional tool restriction stack for managing tool availability during skill execution.
    /// Injected by Core/ when the tool set includes the Skill tool.
    public let restrictionStack: ToolRestrictionStack?
    /// Current skill nesting depth (incremented on each nested skill call).
    /// Used by SkillTool to detect recursion depth exceedance.
    public let skillNestingDepth: Int
    /// Maximum allowed skill recursion depth. Defaults to 4.
    /// Configurable via AgentOptions.maxSkillRecursionDepth.
    public let maxSkillRecursionDepth: Int
    /// Optional file cache for caching file contents across tool executions.
    /// Injected by Core/ when the agent is created. Nil when file caching is not enabled.
    public let fileCache: FileCache?

    /// Optional sandbox settings for restricting tool execution.
    /// Injected by Core/ from AgentOptions.sandbox. Nil when no sandbox is configured.
    public let sandbox: SandboxSettings?
    /// Optional MCP connection list for MCP resource tools (ListMcpResources, ReadMcpResource).
    /// Injected by Core/ at tool execution time. Nil when no MCP connections are configured.
    public let mcpConnections: [MCPConnectionInfo]?

    /// Optional environment variables to inject into subprocess execution context.
    /// Injected by Core/ from AgentOptions.env. Used by BashTool and ShellHookExecutor
    /// to set environment variables for child processes. Nil when no custom env is configured.
    public let env: [String: String]?

    /// Suggested permission update operations for the CanUseTool callback,
    /// matching TS SDK's `suggestions` parameter.
    public let suggestions: [PermissionUpdateAction]?

    /// A path that was blocked by the permission system, matching TS SDK's `blockedPath`.
    public let blockedPath: String?

    /// The reason for a permission decision, matching TS SDK's `decisionReason`.
    public let decisionReason: String?

    /// The ID of the agent making the permission request, matching TS SDK's `agentID`.
    public let agentId: String?

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
        canUseTool: CanUseToolFn? = nil,
        skillRegistry: SkillRegistry? = nil,
        restrictionStack: ToolRestrictionStack? = nil,
        skillNestingDepth: Int = 0,
        maxSkillRecursionDepth: Int = 4,
        fileCache: FileCache? = nil,
        sandbox: SandboxSettings? = nil,
        mcpConnections: [MCPConnectionInfo]? = nil,
        env: [String: String]? = nil,
        suggestions: [PermissionUpdateAction]? = nil,
        blockedPath: String? = nil,
        decisionReason: String? = nil,
        agentId: String? = nil
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
        self.skillRegistry = skillRegistry
        self.restrictionStack = restrictionStack
        self.skillNestingDepth = skillNestingDepth
        self.maxSkillRecursionDepth = maxSkillRecursionDepth
        self.fileCache = fileCache
        self.sandbox = sandbox
        self.mcpConnections = mcpConnections
        self.env = env
        self.suggestions = suggestions
        self.blockedPath = blockedPath
        self.decisionReason = decisionReason
        self.agentId = agentId
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
            canUseTool: canUseTool,
            skillRegistry: skillRegistry,
            restrictionStack: restrictionStack,
            skillNestingDepth: skillNestingDepth,
            maxSkillRecursionDepth: maxSkillRecursionDepth,
            fileCache: fileCache,
            sandbox: sandbox,
            mcpConnections: mcpConnections,
            env: env,
            suggestions: suggestions,
            blockedPath: blockedPath,
            decisionReason: decisionReason,
            agentId: agentId
        )
    }

    /// Returns a copy of this context with an incremented skill nesting depth.
    ///
    /// Used by SkillTool to track nested skill calls and detect recursion.
    ///
    /// - Parameter depth: The new skill nesting depth value.
    /// - Returns: A copy of this context with the updated depth.
    public func withSkillContext(depth: Int) -> ToolContext {
        ToolContext(
            cwd: cwd, toolUseId: toolUseId,
            agentSpawner: agentSpawner, mailboxStore: mailboxStore,
            teamStore: teamStore, senderName: senderName,
            taskStore: taskStore, worktreeStore: worktreeStore,
            planStore: planStore, cronStore: cronStore,
            todoStore: todoStore,
            hookRegistry: hookRegistry,
            permissionMode: permissionMode,
            canUseTool: canUseTool,
            skillRegistry: skillRegistry,
            restrictionStack: restrictionStack,
            skillNestingDepth: depth,
            maxSkillRecursionDepth: maxSkillRecursionDepth,
            fileCache: fileCache,
            sandbox: sandbox,
            mcpConnections: mcpConnections,
            env: env,
            suggestions: suggestions,
            blockedPath: blockedPath,
            decisionReason: decisionReason,
            agentId: agentId
        )
    }
}

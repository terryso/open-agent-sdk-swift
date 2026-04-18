import Foundation

/// Lifecycle events for the hook system.
///
/// Each case represents a point in the agent's lifecycle where hooks can be registered
/// to intercept, observe, or modify behavior.
public enum HookEvent: String, Sendable, Equatable, CaseIterable {
    /// Triggered before a tool is executed.
    case preToolUse
    /// Triggered after a tool completes successfully.
    case postToolUse
    /// Triggered after a tool execution fails.
    case postToolUseFailure
    /// Triggered when an agent session starts.
    case sessionStart
    /// Triggered when an agent session ends.
    case sessionEnd
    /// Triggered when the agent loop terminates.
    case stop
    /// Triggered when a sub-agent is spawned.
    case subagentStart
    /// Triggered when a sub-agent completes.
    case subagentStop
    /// Triggered when a user submits a prompt.
    case userPromptSubmit
    /// Triggered when a permission check occurs.
    case permissionRequest
    /// Triggered when a permission is denied.
    case permissionDenied
    /// Triggered when a task is created.
    case taskCreated
    /// Triggered when a task is completed.
    case taskCompleted
    /// Triggered when configuration changes.
    case configChange
    /// Triggered when the working directory changes.
    case cwdChanged
    /// Triggered when a file changes.
    case fileChanged
    /// Triggered for notification events.
    case notification
    /// Triggered before conversation compaction.
    case preCompact
    /// Triggered after conversation compaction.
    case postCompact
    /// Triggered when a teammate becomes idle.
    case teammateIdle
    /// Triggered during agent setup initialization.
    case setup
    /// Triggered when a worktree is created.
    case worktreeCreate
    /// Triggered when a worktree is removed.
    case worktreeRemove
}

/// Input data provided to hook handlers.
///
/// Contains contextual information about the event being processed, including
/// the event type, optional tool information, and session context.
///
/// - Note: Uses `@unchecked Sendable` because `toolInput`/`toolOutput` hold
///   dynamic `Any?` values that cannot be statically verified as Sendable.
public struct HookInput: @unchecked Sendable {
    /// The lifecycle event that triggered this hook.
    public let event: HookEvent
    /// The name of the tool being executed, if applicable.
    public let toolName: String?
    /// The raw input to the tool, if applicable.
    public let toolInput: Any?
    /// The raw output from the tool, if applicable.
    public let toolOutput: Any?
    /// The tool use ID, if applicable.
    public let toolUseId: String?
    /// The session ID, if applicable.
    public let sessionId: String?
    /// The current working directory, if applicable.
    public let cwd: String?
    /// An error message, if applicable.
    public let error: String?
    /// Path to the conversation transcript file.
    public let transcriptPath: String?
    /// The current permission mode (e.g., "default", "plan").
    public let permissionMode: String?
    /// The unique identifier of the agent instance.
    public let agentId: String?
    /// The type of agent (e.g., "orchestrator", "researcher").
    public let agentType: String?
    /// Whether a stop hook is currently active (Stop event).
    public let stopHookActive: Bool?
    /// The last message from the assistant (Stop/SubagentStop events).
    public let lastAssistantMessage: String?
    /// The trigger type for compaction ("manual" or "auto", PreCompact event).
    public let trigger: String?
    /// Custom instructions for compaction (PreCompact event).
    public let customInstructions: String?
    /// Suggested permission decisions (PermissionRequest event).
    public let permissionSuggestions: [String]?
    /// Whether the tool failure was caused by an interrupt (PostToolUseFailure event).
    public let isInterrupt: Bool?
    /// Path to the sub-agent's transcript file (SubagentStop event).
    public let agentTranscriptPath: String?

    public init(
        event: HookEvent,
        toolName: String? = nil,
        toolInput: Any? = nil,
        toolOutput: Any? = nil,
        toolUseId: String? = nil,
        sessionId: String? = nil,
        cwd: String? = nil,
        error: String? = nil,
        transcriptPath: String? = nil,
        permissionMode: String? = nil,
        agentId: String? = nil,
        agentType: String? = nil,
        stopHookActive: Bool? = nil,
        lastAssistantMessage: String? = nil,
        trigger: String? = nil,
        customInstructions: String? = nil,
        permissionSuggestions: [String]? = nil,
        isInterrupt: Bool? = nil,
        agentTranscriptPath: String? = nil
    ) {
        self.event = event
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolOutput = toolOutput
        self.toolUseId = toolUseId
        self.sessionId = sessionId
        self.cwd = cwd
        self.error = error
        self.transcriptPath = transcriptPath
        self.permissionMode = permissionMode
        self.agentId = agentId
        self.agentType = agentType
        self.stopHookActive = stopHookActive
        self.lastAssistantMessage = lastAssistantMessage
        self.trigger = trigger
        self.customInstructions = customInstructions
        self.permissionSuggestions = permissionSuggestions
        self.isInterrupt = isInterrupt
        self.agentTranscriptPath = agentTranscriptPath
    }
}

/// Hook decision types matching TS SDK's `decision: 'approve' | 'block'`.
public enum HookDecision: String, Sendable, Equatable {
    /// Approve the operation.
    case approve
    /// Block the operation.
    case block
}

/// Output returned from hook handlers.
///
/// Hooks can return a `HookOutput` to influence agent behavior by providing messages,
/// updating permissions, blocking operations, or sending notifications.
///
/// - Note: Uses `@unchecked Sendable` for compatibility with dynamic `Any?` values.
///   The `updatedInput` and `updatedMCPToolOutput` fields are excluded from `Equatable`
///   comparison because they contain `Any?` values.
public struct HookOutput: @unchecked Sendable, Equatable {
    /// An optional log or status message from the hook.
    public let message: String?
    /// An optional permission update to apply.
    public let permissionUpdate: PermissionUpdate?
    /// Whether to block the current operation. Defaults to `false`.
    public let block: Bool
    /// An optional notification to send to the user.
    public let notification: HookNotification?
    /// An optional system message to inject into the conversation.
    public let systemMessage: String?
    /// An optional reason explaining the hook's decision.
    public let reason: String?
    /// An optional updated input to replace the original tool input (PreToolUse hooks).
    public let updatedInput: [String: Any]?
    /// Additional context to provide alongside the hook result.
    public let additionalContext: String?
    /// A permission decision from the hook (allow/deny/ask).
    public let permissionDecision: PermissionDecision?
    /// An optional updated MCP tool output (PostToolUse hooks).
    public let updatedMCPToolOutput: Any?
    /// Explicit hook decision matching TS SDK's `decision: 'approve' | 'block'`.
    public let decision: HookDecision?

    public init(
        message: String? = nil,
        permissionUpdate: PermissionUpdate? = nil,
        block: Bool = false,
        notification: HookNotification? = nil,
        systemMessage: String? = nil,
        reason: String? = nil,
        updatedInput: [String: Any]? = nil,
        additionalContext: String? = nil,
        permissionDecision: PermissionDecision? = nil,
        updatedMCPToolOutput: Any? = nil,
        decision: HookDecision? = nil
    ) {
        self.message = message
        self.permissionUpdate = permissionUpdate
        self.block = block
        self.notification = notification
        self.systemMessage = systemMessage
        self.reason = reason
        self.updatedInput = updatedInput
        self.additionalContext = additionalContext
        self.permissionDecision = permissionDecision
        self.updatedMCPToolOutput = updatedMCPToolOutput
        self.decision = decision
    }

    /// Convenience initializer that sets both `block` and `decision` from a single decision value.
    public init(decision: HookDecision, message: String? = nil, permissionUpdate: PermissionUpdate? = nil, notification: HookNotification? = nil, systemMessage: String? = nil, reason: String? = nil, updatedInput: [String: Any]? = nil, additionalContext: String? = nil, permissionDecision: PermissionDecision? = nil, updatedMCPToolOutput: Any? = nil) {
        self.message = message
        self.permissionUpdate = permissionUpdate
        self.block = decision == .block
        self.notification = notification
        self.systemMessage = systemMessage
        self.reason = reason
        self.updatedInput = updatedInput
        self.additionalContext = additionalContext
        self.permissionDecision = permissionDecision
        self.updatedMCPToolOutput = updatedMCPToolOutput
        self.decision = decision
    }

    public static func == (lhs: HookOutput, rhs: HookOutput) -> Bool {
        lhs.message == rhs.message
            && lhs.permissionUpdate == rhs.permissionUpdate
            && lhs.block == rhs.block
            && lhs.notification == rhs.notification
            && lhs.systemMessage == rhs.systemMessage
            && lhs.reason == rhs.reason
            && lhs.additionalContext == rhs.additionalContext
            && lhs.permissionDecision == rhs.permissionDecision
            && lhs.decision == rhs.decision
        // Note: updatedInput ([String: Any]?) and updatedMCPToolOutput (Any?)
        // are excluded from equality comparison because they contain non-Equatable types.
    }
}

/// Permission behaviors for hook-driven permission updates.
///
/// Use `.allow` to permit tool execution, `.deny` to block it, or `.ask`
/// to defer the decision back to the user.
public enum PermissionBehavior: String, Sendable, Equatable, CaseIterable {
    case allow = "allow"
    case deny = "deny"
    /// Defer the decision back to the user, matching TS SDK's "ask" behavior.
    case ask = "ask"
}

/// Permission decisions returned by hooks.
///
/// Unlike `PermissionBehavior` (which is used in the permission system with only
/// allow/deny), `PermissionDecision` includes an `ask` case for hook-specific
/// scenarios where the hook defers the decision back to the user.
public enum PermissionDecision: String, Sendable, Equatable, CaseIterable {
    /// Allow the operation.
    case allow = "allow"
    /// Deny the operation.
    case deny = "deny"
    /// Defer the decision back to the user.
    case ask = "ask"
}

/// A permission update from a hook.
///
/// Dynamically changes tool permissions during hook execution.
public struct PermissionUpdate: Sendable, Equatable {
    /// The tool name to update permissions for.
    public let tool: String
    /// The new permission behavior.
    public let behavior: PermissionBehavior

    public init(tool: String, behavior: PermissionBehavior) {
        self.tool = tool
        self.behavior = behavior
    }
}

/// Severity levels for hook notifications.
///
/// Use `.info` for general messages, `.warning` for potential issues,
/// `.error` for failures, and `.debug` for diagnostic information.
/// Unknown string values from external sources fall back to `.info`.
public enum HookNotificationLevel: String, Sendable, Equatable, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case debug = "debug"

    /// Initialize from a string, falling back to `.info` for unknown values.
    public init(_ string: String) {
        self = HookNotificationLevel(rawValue: string) ?? .info
    }
}

/// A notification from a hook.
///
/// Provides a user-visible notification with title, body text, and severity level.
public struct HookNotification: Sendable, Equatable {
    /// The notification title.
    public let title: String
    /// The notification body text.
    public let body: String
    /// The severity level. Defaults to `.info`.
    public let level: HookNotificationLevel

    public init(title: String, body: String, level: HookNotificationLevel = .info) {
        self.title = title
        self.body = body
        self.level = level
    }
}

/// Definition of a hook handler.
///
/// A hook can be either a function handler or a shell command. Use `matcher`
/// to filter hooks to specific tool names via regex, and `timeout` to prevent
/// long-running hooks from blocking the agent loop.
///
/// - Note: Uses `@unchecked Sendable` because closures cannot be statically verified.
public struct HookDefinition: @unchecked Sendable {
    /// An optional shell command to execute. Input is passed via stdin as JSON.
    public let command: String?
    /// An optional function handler to invoke.
    public let handler: (@Sendable (HookInput) async -> HookOutput?)?
    /// An optional regex pattern to match against the tool name. Nil matches all tools.
    public let matcher: String?
    /// Timeout in milliseconds for the hook execution. Defaults to 30,000ms.
    public let timeout: Int?

    public init(
        command: String? = nil,
        handler: (@Sendable (HookInput) async -> HookOutput?)? = nil,
        matcher: String? = nil,
        timeout: Int? = nil
    ) {
        self.command = command
        self.handler = handler
        self.matcher = matcher
        self.timeout = timeout
    }
}

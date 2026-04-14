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

    public init(
        event: HookEvent,
        toolName: String? = nil,
        toolInput: Any? = nil,
        toolOutput: Any? = nil,
        toolUseId: String? = nil,
        sessionId: String? = nil,
        cwd: String? = nil,
        error: String? = nil
    ) {
        self.event = event
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolOutput = toolOutput
        self.toolUseId = toolUseId
        self.sessionId = sessionId
        self.cwd = cwd
        self.error = error
    }
}

/// Output returned from hook handlers.
///
/// Hooks can return a `HookOutput` to influence agent behavior by providing messages,
/// updating permissions, blocking operations, or sending notifications.
///
/// - Note: Uses `@unchecked Sendable` for compatibility with dynamic `Any?` values.
public struct HookOutput: @unchecked Sendable {
    /// An optional log or status message from the hook.
    public let message: String?
    /// An optional permission update to apply.
    public let permissionUpdate: PermissionUpdate?
    /// Whether to block the current operation. Defaults to `false`.
    public let block: Bool
    /// An optional notification to send to the user.
    public let notification: HookNotification?

    public init(
        message: String? = nil,
        permissionUpdate: PermissionUpdate? = nil,
        block: Bool = false,
        notification: HookNotification? = nil
    ) {
        self.message = message
        self.permissionUpdate = permissionUpdate
        self.block = block
        self.notification = notification
    }
}

/// Permission behaviors for hook-driven permission updates.
///
/// Use `.allow` to permit tool execution or `.deny` to block it.
public enum PermissionBehavior: String, Sendable, Equatable, CaseIterable {
    case allow = "allow"
    case deny = "deny"
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

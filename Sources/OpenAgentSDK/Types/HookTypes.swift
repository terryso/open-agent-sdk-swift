import Foundation

/// Lifecycle events for the hook system.
public enum HookEvent: String, Sendable, Equatable, CaseIterable {
    case preToolUse
    case postToolUse
    case postToolUseFailure
    case sessionStart
    case sessionEnd
    case stop
    case subagentStart
    case subagentStop
    case userPromptSubmit
    case permissionRequest
    case permissionDenied
    case taskCreated
    case taskCompleted
    case configChange
    case cwdChanged
    case fileChanged
    case notification
    case preCompact
    case postCompact
    case teammateIdle
}

/// Input data provided to hook handlers.
/// Note: Uses `@unchecked Sendable` because `toolInput`/`toolOutput` hold
/// dynamic `Any?` values that cannot be statically verified as Sendable.
public struct HookInput: @unchecked Sendable {
    public let event: HookEvent
    public let toolName: String?
    public let toolInput: Any?
    public let toolOutput: Any?
    public let toolUseId: String?
    public let sessionId: String?
    public let cwd: String?
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
public struct HookOutput: @unchecked Sendable {
    public let message: String?
    public let permissionUpdate: PermissionUpdate?
    public let block: Bool
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

/// Permission update from a hook.
public struct PermissionUpdate: Sendable, Equatable {
    public let tool: String
    public let behavior: String

    public init(tool: String, behavior: String) {
        self.tool = tool
        self.behavior = behavior
    }
}

/// Notification from a hook.
public struct HookNotification: Sendable, Equatable {
    public let title: String
    public let body: String
    public let level: String

    public init(title: String, body: String, level: String = "info") {
        self.title = title
        self.body = body
        self.level = level
    }
}

/// Definition of a hook handler.
public struct HookDefinition: @unchecked Sendable {
    public let command: String?
    public let handler: (@Sendable (HookInput) async -> HookOutput?)?
    public let matcher: String?
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

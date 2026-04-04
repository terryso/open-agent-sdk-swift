import Foundation

/// Permission modes controlling tool execution behavior.
public enum PermissionMode: String, Sendable, Equatable, CaseIterable {
    case `default`
    case acceptEdits
    case bypassPermissions
    case plan
    case dontAsk
    case auto
}

/// Result of a permission check for tool usage.
/// Note: Uses `@unchecked Sendable` because `updatedInput` holds a dynamic
/// `Any?` value. Equality comparison excludes `updatedInput` since `Any?`
/// cannot be compared at compile time.
public struct CanUseToolResult: @unchecked Sendable, Equatable {
    public let behavior: String
    public let updatedInput: Any?
    public let message: String?

    public init(behavior: String, updatedInput: Any? = nil, message: String? = nil) {
        self.behavior = behavior
        self.updatedInput = updatedInput
        self.message = message
    }

    public static func == (lhs: CanUseToolResult, rhs: CanUseToolResult) -> Bool {
        lhs.behavior == rhs.behavior && lhs.message == rhs.message
    }
}

/// Closure type for custom tool permission checks.
public typealias CanUseToolFn = @Sendable (ToolProtocol, Any, ToolContext) async -> CanUseToolResult?

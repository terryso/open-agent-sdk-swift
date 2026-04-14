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
    public let behavior: PermissionBehavior
    public let updatedInput: Any?
    public let message: String?

    public init(behavior: PermissionBehavior, updatedInput: Any? = nil, message: String? = nil) {
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

// MARK: - CanUseToolResult Factory Methods

extension CanUseToolResult {
    /// Creates an allow result.
    public static func allow() -> CanUseToolResult {
        CanUseToolResult(behavior: .allow)
    }

    /// Creates a deny result with a message.
    public static func deny(_ message: String) -> CanUseToolResult {
        CanUseToolResult(behavior: .deny, message: message)
    }

    /// Creates an allow result with modified input.
    public static func allowWithInput(_ updatedInput: Any) -> CanUseToolResult {
        CanUseToolResult(behavior: .allow, updatedInput: updatedInput)
    }
}

// MARK: - PermissionPolicy Protocol

/// Protocol for defining custom tool authorization policies.
///
/// A `PermissionPolicy` evaluates whether a tool should be allowed to execute
/// based on the tool, its input, and the execution context. Policies can be
/// composed using ``CompositePolicy`` for complex authorization scenarios.
///
/// Usage:
/// ```swift
/// let policy = ToolNameAllowlistPolicy(allowedToolNames: ["Read", "Glob", "Grep"])
/// agent.setCanUseTool(canUseTool(policy: policy))
/// ```
public protocol PermissionPolicy: Sendable {
    /// Evaluates whether the tool execution should be allowed.
    ///
    /// - Parameters:
    ///   - tool: The tool being evaluated.
    ///   - input: The raw input for the tool call.
    ///   - context: The execution context with permission info.
    /// - Returns: A ``CanUseToolResult`` with the decision, or `nil` to defer
    ///   to the next policy or the default permission mode behavior.
    func evaluate(
        tool: ToolProtocol,
        input: Any,
        context: ToolContext
    ) async -> CanUseToolResult?
}

// MARK: - ToolNameAllowlistPolicy

/// Policy that allows only tools whose names are in a specified set.
///
/// Tools not in the allowlist are denied. An empty allowlist denies all tools.
public struct ToolNameAllowlistPolicy: PermissionPolicy, Sendable, Equatable {
    /// The set of tool names that are allowed to execute.
    public let allowedToolNames: Set<String>

    public init(allowedToolNames: Set<String>) {
        self.allowedToolNames = allowedToolNames
    }

    public func evaluate(tool: ToolProtocol, input: Any, context: ToolContext) async -> CanUseToolResult? {
        if allowedToolNames.contains(tool.name) {
            return .allow()
        }
        return .deny("Tool \"\(tool.name)\" not in allowlist")
    }
}

// MARK: - ToolNameDenylistPolicy

/// Policy that denies tools whose names are in a specified set.
///
/// Tools not in the denylist are allowed. An empty denylist allows all tools.
public struct ToolNameDenylistPolicy: PermissionPolicy, Sendable, Equatable {
    /// The set of tool names that are denied.
    public let deniedToolNames: Set<String>

    public init(deniedToolNames: Set<String>) {
        self.deniedToolNames = deniedToolNames
    }

    public func evaluate(tool: ToolProtocol, input: Any, context: ToolContext) async -> CanUseToolResult? {
        if deniedToolNames.contains(tool.name) {
            return .deny("Tool \"\(tool.name)\" is denied")
        }
        return .allow()
    }
}

// MARK: - ReadOnlyPolicy

/// Policy that allows only read-only tools.
///
/// Any tool with `isReadOnly == false` is denied. This is similar to
/// `.plan` permission mode but implemented through the policy interface.
public struct ReadOnlyPolicy: PermissionPolicy, Sendable, Equatable {
    public init() {}

    public func evaluate(tool: ToolProtocol, input: Any, context: ToolContext) async -> CanUseToolResult? {
        if tool.isReadOnly {
            return .allow()
        }
        return .deny("Tool \"\(tool.name)\" denied: read-only policy active")
    }
}

// MARK: - CompositePolicy

/// Policy that composes multiple sub-policies and evaluates them in order.
///
/// Evaluation rules:
/// - Any sub-policy returning deny causes the entire composite to deny (short-circuit).
/// - Sub-policies returning nil (no opinion) are skipped.
/// - If all sub-policies allow or have no opinion, the result is allow.
/// - An empty policy list defaults to allow.
public struct CompositePolicy: PermissionPolicy, Sendable {
    /// The ordered list of sub-policies to evaluate.
    public let policies: [PermissionPolicy]

    public init(policies: [PermissionPolicy]) {
        self.policies = policies
    }

    public func evaluate(tool: ToolProtocol, input: Any, context: ToolContext) async -> CanUseToolResult? {
        for policy in policies {
            if let result = await policy.evaluate(tool: tool, input: input, context: context) {
                if result.behavior == .deny {
                    return result  // Any deny -> overall deny (short-circuit)
                }
                // allow or allowWithInput -> continue checking other policies
            }
            // nil -> this policy has no opinion, continue to next
        }
        // All policies allowed or had no opinion -> allow
        return .allow()
    }
}

// MARK: - Policy-to-Callback Bridge

/// Creates a ``CanUseToolFn`` closure from a ``PermissionPolicy``.
///
/// This bridge function converts a policy into the callback format expected
/// by ``AgentOptions/canUseTool`` and ``Agent/setCanUseTool(_:)``.
///
/// - Parameter policy: The permission policy to use for authorization decisions.
/// - Returns: A ``CanUseToolFn`` closure that delegates to the policy's `evaluate()` method.
public func canUseTool(policy: PermissionPolicy) -> CanUseToolFn {
    return { tool, input, context in
        await policy.evaluate(tool: tool, input: input, context: context)
    }
}

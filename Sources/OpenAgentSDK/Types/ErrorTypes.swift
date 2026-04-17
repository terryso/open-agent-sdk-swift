import Foundation

/// Unified error type for the OpenAgentSDK.
///
/// `SDKError` uses associated values to carry context about each error type.
/// Convenience computed properties provide typed access to associated values.
///
/// ```swift
/// do {
///     let result = try await someOperation()
/// } catch let error as SDKError {
///     switch error {
///     case .apiError(let statusCode, let message):
///         print("API error \(statusCode): \(message)")
///     case .budgetExceeded(let cost, let turns):
///         print("Budget exceeded: $\(cost) after \(turns) turns")
///     default:
///         print(error.localizedDescription)
///     }
/// }
/// ```
public enum SDKError: Error, Equatable, LocalizedError, Sendable {
    /// An HTTP API error with status code and message.
    case apiError(statusCode: Int, message: String)
    /// A tool execution error.
    case toolExecutionError(toolName: String, message: String)
    /// Budget limit exceeded with the cost and turns used.
    case budgetExceeded(cost: Double, turnsUsed: Int)
    /// Maximum turns limit exceeded.
    case maxTurnsExceeded(turnsUsed: Int)
    /// A session persistence error.
    case sessionError(message: String)
    /// An MCP server connection error.
    case mcpConnectionError(serverName: String, message: String)
    /// A tool execution was denied by the permission system.
    case permissionDenied(tool: String, reason: String)
    /// The operation was aborted.
    case abortError
    /// An invalid configuration was provided.
    case invalidConfiguration(String)
    /// A requested resource was not found.
    case notFound(String)

    // MARK: - Computed Properties for Associated Value Access

    /// HTTP status code, available only for `.apiError`.
    public var statusCode: Int? {
        guard case .apiError(let code, _) = self else { return nil }
        return code
    }

    /// Human-readable message for the error.
    public var message: String {
        switch self {
        case .apiError(_, let msg),
             .toolExecutionError(_, let msg),
             .sessionError(let msg),
             .mcpConnectionError(_, let msg),
             .invalidConfiguration(let msg),
             .notFound(let msg):
            return msg
        case .permissionDenied(_, let reason):
            return reason
        case .budgetExceeded:
            return "Budget exceeded"
        case .maxTurnsExceeded:
            return "Max turns exceeded"
        case .abortError:
            return "Aborted"
        }
    }

    /// Tool name, available only for `.toolExecutionError`.
    public var toolName: String? {
        guard case .toolExecutionError(let name, _) = self else { return nil }
        return name
    }

    /// Cost at time of budget exceedance, available only for `.budgetExceeded`.
    public var cost: Double? {
        guard case .budgetExceeded(let cost, _) = self else { return nil }
        return cost
    }

    /// Turns used, available for `.budgetExceeded` and `.maxTurnsExceeded`.
    public var turnsUsed: Int? {
        switch self {
        case .budgetExceeded(_, let turns): return turns
        case .maxTurnsExceeded(let turns): return turns
        default: return nil
        }
    }

    /// MCP server name, available only for `.mcpConnectionError`.
    public var serverName: String? {
        guard case .mcpConnectionError(let name, _) = self else { return nil }
        return name
    }

    /// Tool name for permission denial, available only for `.permissionDenied`.
    public var tool: String? {
        guard case .permissionDenied(let name, _) = self else { return nil }
        return name
    }

    /// Reason for permission denial, available only for `.permissionDenied`.
    public var reason: String? {
        guard case .permissionDenied(_, let reason) = self else { return nil }
        return reason
    }

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .toolExecutionError(let toolName, let message):
            return "Tool execution error in \(toolName): \(message)"
        case .budgetExceeded(let cost, let turnsUsed):
            return "Budget exceeded: $\(String(format: "%.4f", cost)) used after \(turnsUsed) turns"
        case .maxTurnsExceeded(let turnsUsed):
            return "Maximum turns exceeded: \(turnsUsed) turns used"
        case .sessionError(let message):
            return "Session error: \(message)"
        case .mcpConnectionError(let serverName, let message):
            return "MCP connection error for \(serverName): \(message)"
        case .permissionDenied(let tool, let reason):
            return "Permission denied for \(tool): \(reason)"
        case .abortError:
            return "Operation aborted"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        }
    }
}

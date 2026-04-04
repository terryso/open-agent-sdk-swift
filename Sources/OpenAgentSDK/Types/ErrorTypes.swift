import Foundation

/// Unified error type for the OpenAgentSDK.
public enum SDKError: Error, Equatable, LocalizedError, Sendable {
    case apiError(statusCode: Int, message: String)
    case toolExecutionError(toolName: String, message: String)
    case budgetExceeded(cost: Double, turnsUsed: Int)
    case maxTurnsExceeded(turnsUsed: Int)
    case sessionError(message: String)
    case mcpConnectionError(serverName: String, message: String)
    case permissionDenied(tool: String, reason: String)
    case abortError

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
             .mcpConnectionError(_, let msg):
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
        }
    }
}

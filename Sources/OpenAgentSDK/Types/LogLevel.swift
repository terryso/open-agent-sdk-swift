import Foundation

/// Log verbosity levels for the SDK's internal logging system.
///
/// Higher rawValue means more verbose output. Use these levels to control
/// how much diagnostic information the SDK emits during operation.
///
/// ```swift
/// // Set to debug for maximum verbosity during development
/// let config = SDKConfiguration(logLevel: .debug)
///
/// // Set to error for production (only errors are logged)
/// let config = SDKConfiguration(logLevel: .error)
///
/// // Set to none for zero-overhead silent mode
/// let config = SDKConfiguration(logLevel: .none)
/// ```
public enum LogLevel: Int, Comparable, CaseIterable, Sendable {
    /// No logging at all. Zero overhead -- all log calls are guarded and skip immediately.
    case none = 0
    /// Only error conditions are logged.
    case error = 1
    /// Warnings and errors are logged.
    case warn = 2
    /// Informational messages, warnings, and errors are logged.
    case info = 3
    /// All messages are logged, including verbose debug output.
    case debug = 4

    // MARK: - Comparable

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - CustomStringConvertible

extension LogLevel: CustomStringConvertible {
    /// Lowercase name string for use in structured log output.
    public var description: String {
        switch self {
        case .none: return "none"
        case .error: return "error"
        case .warn: return "warn"
        case .info: return "info"
        case .debug: return "debug"
        }
    }
}

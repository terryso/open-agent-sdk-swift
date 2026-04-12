import Foundation

/// Output destination for log entries produced by ``Logger``.
///
/// ```swift
/// // Write to stderr (default)
/// let output = LogOutput.console
///
/// // Append to a file
/// let output = LogOutput.file(URL(fileURLWithPath: "/var/log/sdk.log"))
///
/// // Custom handler (e.g., send to Datadog/ELK)
/// let output = LogOutput.custom { jsonLine in
///     myLogAggregator.ingest(jsonLine)
/// }
/// ```
public enum LogOutput: Sendable {
    /// Write structured JSON lines to stderr (FileHandle.standardError).
    case console
    /// Append structured JSON lines to the file at the given URL.
    case file(URL)
    /// Pass each JSON line string to the developer-provided closure.
    case custom(@Sendable (String) -> Void)
}

// MARK: - Equatable

extension LogOutput: Equatable {
    /// Custom closures always compare as equal (closures cannot be compared for equality).
    public static func == (lhs: LogOutput, rhs: LogOutput) -> Bool {
        switch (lhs, rhs) {
        case (.console, .console):
            return true
        case (.file(let lhsURL), .file(let rhsURL)):
            return lhsURL == rhsURL
        case (.custom, .custom):
            return true
        default:
            return false
        }
    }
}

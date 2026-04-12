import Foundation

/// SDK-internal structured logger with configurable level and output destination.
///
/// `Logger` provides a singleton instance accessed via ``shared``. Configure the
/// logger using ``configure(level:output:)`` or reset it for testing with ``reset()``.
///
/// ## Zero-Overhead Guarantee
///
/// When ``level`` is ``LogLevel/none``, every log method (`debug`, `info`, `warn`, `error`)
/// returns immediately via a `guard` check. No ``LogEntry`` is created, no string
/// formatting occurs, and no output is dispatched.
///
/// ## Thread Safety
///
/// All mutable state is protected by an internal `NSLock`. The logger uses
/// `final class` + lock rather than an actor to avoid `await` at every call site,
/// which would conflict with the zero-overhead design goal.
///
/// ## Usage
///
/// ```swift
/// // Configure before creating agents (or let Agent init configure it)
/// Logger.configure(level: .debug, output: .console)
///
/// // Log at various levels
/// Logger.shared.info("QueryEngine", "Starting query", data: ["queryId": "abc123"])
/// Logger.shared.error("APIClient", "RequestFailed", data: ["statusCode": "429"])
///
/// // Reset in test tearDown
/// Logger.reset()
/// ```
public final class Logger: @unchecked Sendable {

    // MARK: - Singleton

    /// The shared logger instance. Read-only access; configure via ``configure(level:output:)``.
    public static let shared = Logger()

    // MARK: - Public Properties

    /// Current log level. Messages below this level are silently discarded.
    public private(set) var level: LogLevel

    /// Number of log entries that have been output since the last reset.
    /// Useful in tests to verify logging behavior.
    public private(set) var outputCount: Int

    // MARK: - Private Properties

    /// Current output destination.
    private var output: LogOutput

    /// Lock protecting all mutable state.
    private let lock = NSLock()

    /// Cached date formatter for ISO 8601 timestamps with milliseconds.
    /// `ISO8601DateFormatter` is not `Sendable` but is safe to use from
    /// multiple threads because we only call the read-only `string(from:)` method.
    private nonisolated(unsafe) static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Initialization

    private init() {
        self.level = .none
        self.output = .console
        self.outputCount = 0
    }

    // MARK: - Configuration

    /// Configure the shared logger's level and output destination.
    ///
    /// This replaces the current configuration. Call ``reset()`` to restore defaults.
    ///
    /// - Parameters:
    ///   - level: The minimum log level for output.
    ///   - output: Where log entries are written.
    public static func configure(level: LogLevel, output: LogOutput) {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        shared.level = level
        shared.output = output
        shared.outputCount = 0
    }

    /// Reset the shared logger to defaults (level: `.none`, output: `.console`, outputCount: 0).
    ///
    /// Call this in test `tearDown()` to ensure test isolation.
    public static func reset() {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        shared.level = .none
        shared.output = .console
        shared.outputCount = 0
    }

    // MARK: - Per-Level Convenience Methods

    /// Log a debug-level message.
    ///
    /// - Parameters:
    ///   - module: The SDK module emitting the log (e.g., "QueryEngine", "ToolExecutor").
    ///   - event: A short event identifier (e.g., "QueryStarted", "ToolExecuted").
    ///   - data: Optional key-value data to include in the structured log entry.
    public func debug(_ module: String, _ event: String, data: [String: String] = [:]) {
        guard level >= .debug else { return }
        log(level: .debug, module: module, event: event, data: data)
    }

    /// Log an info-level message.
    ///
    /// - Parameters:
    ///   - module: The SDK module emitting the log.
    ///   - event: A short event identifier.
    ///   - data: Optional key-value data to include in the structured log entry.
    public func info(_ module: String, _ event: String, data: [String: String] = [:]) {
        guard level >= .info else { return }
        log(level: .info, module: module, event: event, data: data)
    }

    /// Log a warning-level message.
    ///
    /// - Parameters:
    ///   - module: The SDK module emitting the log.
    ///   - event: A short event identifier.
    ///   - data: Optional key-value data to include in the structured log entry.
    public func warn(_ module: String, _ event: String, data: [String: String] = [:]) {
        guard level >= .warn else { return }
        log(level: .warn, module: module, event: event, data: data)
    }

    /// Log an error-level message.
    ///
    /// - Parameters:
    ///   - module: The SDK module emitting the log.
    ///   - event: A short event identifier.
    ///   - data: Optional key-value data to include in the structured log entry.
    public func error(_ module: String, _ event: String, data: [String: String] = [:]) {
        guard level >= .error else { return }
        log(level: .error, module: module, event: event, data: data)
    }

    // MARK: - Core Log Method

    /// Create a log entry, serialize to JSON, and dispatch to the current output.
    private func log(level: LogLevel, module: String, event: String, data: [String: String]) {
        let timestamp = Self.dateFormatter.string(from: Date())
        // Build JSON manually for simplicity and performance
        let dataEntries = data.map { "\"\(escapeJSON($0.key))\":\"\(escapeJSON($0.value))\"" }.joined(separator: ",")
        let jsonLine = """
        {"timestamp":"\(timestamp)","level":"\(level.description)","module":"\(escapeJSON(module))","event":"\(escapeJSON(event))","data":{\(dataEntries)}}
        """

        lock.lock()
        let currentOutput = output
        outputCount += 1
        dispatchOutput(currentOutput, jsonLine: jsonLine)
        lock.unlock()
    }

    /// Dispatch a JSON line to the given output destination.
    /// Called while holding `lock` to serialize file writes and output counting.
    private func dispatchOutput(_ output: LogOutput, jsonLine: String) {
        switch output {
        case .console:
            FileHandle.standardError.write(jsonLine.appending("\n").data(using: .utf8) ?? Data())
        case .file(let url):
            // Append to file
            if let data = (jsonLine.appending("\n").data(using: .utf8)) {
                if FileManager.default.fileExists(atPath: url.path) {
                    if let handle = try? FileHandle(forWritingTo: url) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    // Create directory if needed and write
                    try? data.write(to: url, options: .atomic)
                }
            }
        case .custom(let handler):
            handler(jsonLine)
        }
    }

    // MARK: - JSON Escaping

    /// Escape special characters for JSON string values per RFC 8259.
    private func escapeJSON(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\u{08}", with: "\\b")
            .replacingOccurrences(of: "\u{0C}", with: "\\f")
    }
}

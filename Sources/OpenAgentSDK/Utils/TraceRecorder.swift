import Foundation

/// Records SDK execution events as JSONL trace files for debugging and observability.
///
/// `TraceRecorder` is an actor — file I/O is serialized via actor isolation. When
/// ``AgentOptions/traceEnabled`` is `true`, the agent loop creates a `TraceRecorder`
/// and writes one JSONL line per ``SDKMessage`` event.
///
/// ```swift
/// let recorder = try TraceRecorder(runId: "run-123", baseURL: URL(fileURLWithPath: "/tmp/traces"))
/// await recorder.record(event: "step_start", payload: ["tool": "Bash", "toolUseId": "tu_1"])
/// await recorder.close()
/// ```
public actor TraceRecorder {
    private var fileHandle: FileHandle?
    private let fileURL: URL

    /// Keys whose values are stripped during sanitization.
    private static let sensitiveKeys: Set<String> = [
        "apiKey", "api_key", "secret", "token", "password", "credential", "authorization"
    ]

    /// Regex patterns for redacting sensitive string values.
    private static let sensitivePatterns: [String] = ["sk-", "key-"]

    /// Reusable date formatter for trace timestamps (protected by actor isolation).
    private let timestampFormatter = ISO8601DateFormatter()

    /// Create a trace recorder that writes to `{baseURL}/{runId}/trace.jsonl`.
    ///
    /// - Parameters:
    ///   - runId: Unique run identifier used as the directory name.
    ///   - baseURL: Base directory for trace files. When `nil`, defaults to `~/.open-agent-sdk/traces/`.
    /// - Throws: File system errors during directory creation or file opening.
    public init(runId: String, baseURL: URL?) throws {
        let resolvedBase = baseURL ?? TraceRecorder.defaultBaseURL()
        let dir = resolvedBase.appendingPathComponent(runId, isDirectory: true)
        self.fileURL = dir.appendingPathComponent("trace.jsonl", isDirectory: false)

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        self.fileHandle = try FileHandle(forWritingTo: fileURL)
    }

    /// Append a JSONL trace event line with auto-generated `ts` and `event` fields.
    ///
    /// Silent on write failure — trace errors must not interrupt agent execution.
    public func record(event: String, payload: [String: Any] = [:]) {
        guard let handle = fileHandle else { return }

        var entry: [String: Any] = [
            "ts": timestampFormatter.string(from: Date()),
            "event": event
        ]
        let sanitized = Self.sanitizePayload(payload)
        for (key, value) in sanitized {
            entry[key] = value
        }

        guard let data = try? JSONSerialization.data(withJSONObject: entry),
              var jsonLine = String(data: data, encoding: .utf8)
        else { return }

        jsonLine.append("\n")
        guard let lineData = jsonLine.data(using: .utf8) else { return }

        do {
            try handle.seekToEnd()
            handle.write(lineData)
        } catch {
            // Silent failure — trace errors must not interrupt execution
        }
    }

    /// Flush and close the trace file.
    public func close() {
        guard let handle = fileHandle else { return }
        try? handle.synchronize()
        try? handle.close()
        fileHandle = nil
    }

    deinit {
        guard let handle = fileHandle else { return }
        try? handle.synchronize()
        try? handle.close()
    }

    // MARK: - Sanitization

    /// Strip sensitive keys and redact sensitive patterns in string values.
    static func sanitizePayload(_ payload: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in payload {
            if sensitiveKeys.contains(key) { continue }
            result[key] = redactValue(value)
        }
        return result
    }

    /// Recursively redact sensitive patterns in string values.
    private static func redactValue(_ value: Any) -> Any {
        if let str = value as? String {
            var result = str
            for pattern in sensitivePatterns {
                if result.hasPrefix(pattern) {
                    return "[REDACTED]"
                }
            }
            return result
        }
        if let dict = value as? [String: Any] {
            return sanitizePayload(dict)
        }
        if let arr = value as? [Any] {
            return arr.map { redactValue($0) }
        }
        return value
    }

    /// Default trace directory: `~/.open-agent-sdk/traces/`
    public static func defaultBaseURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".open-agent-sdk/traces", isDirectory: true)
    }
}

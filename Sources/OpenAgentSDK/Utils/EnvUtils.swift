import Foundation

/// Read an environment variable by name.
///
/// Uses `ProcessInfo.processInfo.environment` which is available
/// on both macOS (Foundation) and Linux (Swift Foundation).
///
/// - Parameter key: The environment variable name.
/// - Returns: The value as a String, or nil if unset or empty.
internal func getEnv(_ key: String) -> String? {
    guard let value = ProcessInfo.processInfo.environment[key],
          !value.isEmpty else {
        return nil
    }
    return value
}

/// Load key-value pairs from a `.env` file in the current working directory.
///
/// Reads `.env` from the process working directory, parses `KEY=VALUE` lines,
/// and returns them as a dictionary. Lines starting with `#` and empty lines are skipped.
///
/// - Parameter path: Custom path to the `.env` file. Defaults to `./.env`.
/// - Returns: A dictionary of environment variable names to values.
public func loadDotEnv(path: String? = nil) -> [String: String] {
    let envPath = path ?? (FileManager.default.currentDirectoryPath + "/.env")
    guard let content = try? String(contentsOfFile: envPath, encoding: .utf8) else { return [:] }
    var env: [String: String] = [:]
    for line in content.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        guard let eqRange = trimmed.range(of: "=") else { continue }
        let key = String(trimmed[..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let value = String(trimmed[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        env[key] = value
    }
    return env
}

/// Read an environment variable, falling back to a `.env` dictionary.
///
/// Priority: process environment > `.env` file values.
///
/// - Parameters:
///   - key: The environment variable name.
///   - dotEnv: A dictionary loaded by ``loadDotEnv(path:)``.
/// - Returns: The value as a String, or nil if not found in either source.
public func getEnv(_ key: String, from dotEnv: [String: String]) -> String? {
    if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
        return value
    }
    return dotEnv[key]
}

/// Validate that a string identifier does not contain path traversal sequences.
///
/// Checks that the value is non-empty and does not contain `/`, `\`, or `..`
/// which could be used for directory traversal attacks.
///
/// - Parameters:
///   - value: The identifier to validate (session ID, domain name, etc.).
///   - label: Human-readable label for error messages (e.g., "Session ID", "Domain name").
/// - Throws: ``SDKError/sessionError(message:)`` if validation fails.
internal func validatePathSafeIdentifier(_ value: String, label: String) throws {
    guard !value.isEmpty else {
        throw SDKError.sessionError(message: "\(label) must not be empty")
    }
    let forbidden = ["/", "\\", ".."]
    for component in forbidden {
        if value.contains(component) {
            throw SDKError.sessionError(message: "\(label) contains invalid character: '\(component)'")
        }
    }
}

/// The user's home directory, resolved cross-platform.
///
/// On Linux, reads `HOME` from the C environment (falls back to `/tmp`).
/// On Apple platforms, uses `NSHomeDirectory()` which is sandbox-aware.
internal let defaultHomeDir: String = {
    #if os(Linux)
    if let homeEnv = getenv("HOME") {
        return String(cString: homeEnv)
    } else {
        return "/tmp"
    }
    #else
    return NSHomeDirectory()
    #endif
}()

/// The default skills directory path (`~/.open-agent-sdk/skills`).
internal let defaultSkillsDir: String = (defaultHomeDir as NSString).appendingPathComponent(".open-agent-sdk/skills")

/// Resolve the skills directory from a custom path or the default.
///
/// - Parameter customDir: Optional custom directory path. Falls back to ``defaultSkillsDir``.
/// - Returns: The resolved skills directory path.
internal func resolveSkillsDir(customDir: String?) -> String {
    if let custom = customDir {
        return custom
    }
    return defaultSkillsDir
}

/// Atomically write data to a file in the given directory.
///
/// Creates the directory if needed (with 0o700 permissions), writes to a temporary file,
/// then renames to the final path. Cleans up the temp file on failure.
///
/// - Parameters:
///   - data: The data to write.
///   - directory: The directory to write in.
///   - fileName: The final file name (e.g., ".usage.json").
///   - contentType: Human-readable description for error messages (e.g., "skill usage data").
internal func atomicWriteJSON(data: Data, toDirectory directory: String, fileName: String, contentType: String) throws {
    do {
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    } catch {
        throw SDKError.sessionError(
            message: "Failed to create directory: \(error.localizedDescription)"
        )
    }

    let tempFileName = "\(fileName).tmp.\(UUID().uuidString)"
    let tempFilePath = (directory as NSString).appendingPathComponent(tempFileName)
    let filePath = (directory as NSString).appendingPathComponent(fileName)

    do {
        try data.write(to: URL(fileURLWithPath: tempFilePath), options: .atomic)
        if FileManager.default.fileExists(atPath: filePath) {
            try FileManager.default.removeItem(atPath: filePath)
        }
        try FileManager.default.moveItem(atPath: tempFilePath, toPath: filePath)
    } catch {
        try? FileManager.default.removeItem(atPath: tempFilePath)
        throw SDKError.sessionError(
            message: "Failed to write \(contentType) at \(filePath): \(error.localizedDescription)"
        )
    }
}

/// Create a pre-configured ISO8601 date formatter with internet datetime and fractional seconds.
///
/// Returns a new `ISO8601DateFormatter` configured with `.withInternetDateTime` and
/// `.withFractionalSeconds` format options. Each call creates a fresh instance,
/// making it safe to use from any isolation context (actors, nonisolated code, etc.).
///
/// - Returns: A configured `ISO8601DateFormatter`.
internal func makeISO8601DateFormatter() -> ISO8601DateFormatter {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}

/// The default memory directory path (`~/.agent/memory`).
internal let defaultMemoryDir: String = (defaultHomeDir as NSString).appendingPathComponent(".agent/memory")

/// Resolve the memory directory from a custom path or the default.
///
/// - Parameter customDir: Optional custom directory path. Falls back to ``defaultMemoryDir``.
/// - Returns: The resolved memory directory path.
internal func resolveMemoryDir(customDir: String?) -> String {
    if let custom = customDir {
        return custom
    }
    return defaultMemoryDir
}

/// Get the default OpenAI-compatible base URL.
///
/// Priority: `CODEANY_BASE_URL` environment variable > built-in default.
/// The default points to a common OpenAI-compatible endpoint. Override via
/// `CODEANY_BASE_URL` in `.env` or process environment to use a different provider
/// (DeepSeek, Ollama, OpenAI, etc.).
///
/// - Parameter dotEnv: A dictionary loaded by ``loadDotEnv(path:)``.
/// - Returns: The base URL string for the OpenAI-compatible API endpoint.
public func getDefaultOpenAIBaseURL(from dotEnv: [String: String] = [:]) -> String {
    getEnv("CODEANY_BASE_URL", from: dotEnv)
        ?? "https://open.bigmodel.cn/api/coding/paas/v4"
}

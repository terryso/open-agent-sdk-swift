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

/// Normalize a file path for comparison by resolving `.`, `..`, redundant slashes, and symlinks.
///
/// Standardizes the path using `NSString.standardizingPath`, then resolves symlinks.
/// Falls back to the standardized path if symlink resolution fails (e.g., broken symlink).
///
/// - Parameter path: The file path to normalize.
/// - Returns: The normalized path string.
internal func normalizePath(_ path: String) -> String {
    let standardized = (path as NSString).standardizingPath
    let url = URL(fileURLWithPath: standardized)
    let resolved = url.resolvingSymlinksInPath().path
    return resolved.isEmpty ? standardized : resolved
}

/// Ensure a directory exists, creating it with 0o700 permissions if needed.
///
/// A shared helper for store classes that need to create directories before writing files.
/// Wraps `FileManager.createDirectory` with the standard SDKError mapping.
///
/// - Parameters:
///   - path: The directory path to create.
///   - label: Human-readable description for error messages (e.g., "memory directory", "session directory").
/// - Throws: ``SDKError/sessionError(message:)`` if directory creation fails.
internal func ensureDirectoryExists(atPath path: String, label: String = "directory") throws {
    do {
        try FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    } catch {
        throw SDKError.sessionError(message: "Failed to create \(label): \(error.localizedDescription)")
    }
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
    try ensureDirectoryExists(atPath: directory)

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

/// The default sessions directory path (`~/.open-agent-sdk/sessions`).
internal let defaultSessionsDir: String = (defaultHomeDir as NSString).appendingPathComponent(".open-agent-sdk/sessions")

/// The default traces directory path (`~/.open-agent-sdk/traces`).
internal let defaultTracesDir: String = (defaultHomeDir as NSString).appendingPathComponent(".open-agent-sdk/traces")

/// The default API runs directory path (`~/.open-agent-sdk/api-runs`).
internal let defaultApiRunsDir: String = (defaultHomeDir as NSString).appendingPathComponent(".open-agent-sdk/api-runs")

/// Resolve the sessions directory from a custom path or the default.
///
/// - Parameter customDir: Optional custom directory path. Falls back to ``defaultSessionsDir``.
/// - Returns: The resolved sessions directory path.
internal func resolveSessionsDir(customDir: String?) -> String {
    if let custom = customDir {
        return custom
    }
    return defaultSessionsDir
}

/// djb2 hash algorithm for deterministic string hashing.
///
/// Produces a hex string hash of the input using the djb2 algorithm.
/// Used for generating deterministic IDs from content strings.
///
/// - Parameter string: The string to hash.
/// - Returns: A hexadecimal string representation of the hash.
internal func djb2Hash(_ string: String) -> String {
    var hash: UInt64 = 5381
    for byte in string.utf8 {
        hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
    }
    return String(hash, radix: 16)
}

/// Create a pre-configured JSON encoder with SDK-standard settings.
///
/// Returns a `JSONEncoder` with `.prettyPrinted` and `.sortedKeys` output formatting
/// and `.iso8601` date encoding strategy. Each call creates a fresh instance.
///
/// - Returns: A configured `JSONEncoder`.
internal func makeSDKJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}

/// Create a pre-configured JSON decoder with SDK-standard settings.
///
/// Returns a `JSONDecoder` with `.iso8601` date decoding strategy.
/// Each call creates a fresh instance.
///
/// - Returns: A configured `JSONDecoder`.
internal func makeSDKJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}

/// Serialize an arbitrary value to a JSON-like string representation.
///
/// Handles String, Int, Double, Bool, Array, Dictionary, and nil.
/// When `quoteStrings` is true (default), string values are wrapped in double quotes
/// (suitable for config display). When false, strings are returned unwrapped
/// (suitable for already-user-facing MCP content text).
///
/// - Parameters:
///   - value: The value to serialize. Nil returns `"null"`.
///   - quoteStrings: Whether to wrap string values in double quotes. Defaults to `true`.
/// - Returns: A JSON-like string representation.
internal func jsonStringify(_ value: Any?, quoteStrings: Bool = true) -> String {
    guard let value = value else { return "null" }
    if let str = value as? String { return quoteStrings ? "\"\(str)\"" : str }
    if let bool = value as? Bool { return bool ? "true" : "false" }
    if let num = value as? Double {
        return num.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(num))" : "\(num)"
    }
    if let num = value as? Int { return "\(num)" }
    if let arr = value as? [Any] {
        let items = arr.map { jsonStringify($0, quoteStrings: quoteStrings) }
        return "[\(items.joined(separator: ", "))]"
    }
    if let dict = value as? [String: Any] {
        let pairs = dict.map { "\"\($0.key)\": \(jsonStringify($0.value, quoteStrings: quoteStrings))" }
        return "{\(pairs.joined(separator: ", "))}"
    }
    return String(describing: value)
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

/// Get the optional Anthropic-compatible base URL.
///
/// Priority: `ANTHROPIC_BASE_URL` environment variable > no override.
/// When nil, the Anthropic client uses its built-in default endpoint.
///
/// - Parameter dotEnv: A dictionary loaded by ``loadDotEnv(path:)``.
/// - Returns: The Anthropic-compatible base URL string, or nil for provider default.
public func getDefaultAnthropicBaseURL(from dotEnv: [String: String] = [:]) -> String? {
    getEnv("ANTHROPIC_BASE_URL", from: dotEnv)
}

// MARK: - YAML Helpers

/// Escape special characters in a string for safe inclusion in a YAML double-quoted value.
///
/// Escapes backslashes, double quotes, and newlines.
///
/// - Parameter value: The string to escape.
/// - Returns: The escaped string (without surrounding quotes).
internal func yamlEscape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
}

/// Quote a YAML value, wrapping in double quotes if it contains special characters.
///
/// Wraps the value in double quotes (with escaping) when it contains characters that
/// would be ambiguous in unquoted YAML context (`:`, `#`, quotes, leading/trailing spaces)
/// or is a YAML reserved word (`true`, `false`, `null`, `yes`, `no`, `on`, `off`, `y`, `n`)
/// or is empty. Otherwise returns the value unquoted.
///
/// - Parameter value: The string to quote.
/// - Returns: The safely quoted or unquoted YAML value string.
internal func yamlQuote(_ value: String) -> String {
    let yamlReserved: Set<String> = ["true", "false", "null", "yes", "no", "on", "off", "y", "n"]
    if value.contains(":") || value.contains("#") || value.contains("'") || value.contains("\"")
        || value.contains("\n") || yamlReserved.contains(value.lowercased()) || value.isEmpty
        || value.hasPrefix(" ") || value.hasSuffix(" ") {
        return "\"\(yamlEscape(value))\""
    }
    return value
}

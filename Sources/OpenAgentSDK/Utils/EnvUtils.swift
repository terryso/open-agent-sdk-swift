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

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

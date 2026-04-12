import Foundation

/// Path normalization utility for sandbox enforcement.
///
/// Resolves filesystem paths to their canonical absolute form, handling:
/// - Relative path components (`..`, `.`)
/// - Symlink resolution via `URL.resolvingSymlinksInPath()`
/// - Trailing slash standardization
///
/// Uses `URL` and `FileManager` APIs exclusively (NOT POSIX `realpath`)
/// for cross-platform compatibility.
///
/// This utility is used by both ``SandboxSettings`` path matching and
/// ``SandboxChecker`` enforcement logic, and is designed for reuse in
/// Stories 14.4 and 14.5.
enum SandboxPathNormalizer {

    /// Normalize a filesystem path to its canonical absolute form.
    ///
    /// - Resolves `.` and `..` segments
    /// - Resolves symlinks using `URL.resolvingSymlinksInPath()`
    /// - Converts relative paths to absolute (relative to CWD)
    /// - Standardizes trailing slashes (removed)
    ///
    /// On normalization failure (broken symlink, etc.), returns the original
    /// path rather than crashing.
    ///
    /// - Parameter path: The path to normalize.
    /// - Returns: The normalized absolute path.
    public static func normalize(_ path: String) -> String {
        guard !path.isEmpty else {
            return ""
        }

        let url = URL(fileURLWithPath: path)
        let resolved = url.resolvingSymlinksInPath()

        let resolvedPath = resolved.path

        // Standardize: remove trailing slash (unless root "/")
        if resolvedPath.count > 1 && resolvedPath.hasSuffix("/") {
            return String(resolvedPath.dropLast())
        }

        return resolvedPath
    }
}

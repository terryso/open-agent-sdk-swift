import Foundation

/// Cross-platform utility for resolving platform-specific paths.
///
/// Provides a single source of truth for shell and home-directory resolution
/// across macOS and Linux, replacing hardcoded paths and scattered conditional logic.
enum PlatformUtils {

    /// Resolves the shell executable path.
    ///
    /// Search order: `$SHELL` env var → `/bin/bash` → `/usr/bin/bash` → `/bin/sh`.
    /// Falls back to `/bin/sh` as the POSIX guaranteed minimum.
    static func shellPath() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"],
           !shell.isEmpty,
           FileManager.default.isExecutableFile(atPath: shell) {
            return shell
        }
        let candidates = ["/bin/bash", "/usr/bin/bash", "/bin/sh"]
        let fm = FileManager.default
        for path in candidates {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        return "/bin/sh"
    }

    /// Resolves the user's home directory.
    ///
    /// Search order: `$HOME` env var → `NSHomeDirectory()` (macOS) → `/tmp` (Linux fallback).
    static func homeDirectory() -> String {
        if let home = ProcessInfo.processInfo.environment["HOME"],
           !home.isEmpty {
            return home
        }
        #if os(macOS)
        return NSHomeDirectory()
        #else
        return "/tmp"
        #endif
    }
}

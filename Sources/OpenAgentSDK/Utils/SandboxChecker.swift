import Foundation

/// Stateless enforcement utility for sandbox restrictions.
///
/// `SandboxChecker` provides static methods for checking whether paths and commands
/// are permitted under sandbox settings. It encapsulates all sandbox enforcement
/// logic so that Stories 14.4 and 14.5 only need to call one method.
///
/// ## Usage (Stories 14.4 and 14.5)
///
/// ```swift
/// // In FileReadTool (Story 14.4):
/// if let sandbox = context.sandbox {
///     try SandboxChecker.checkPath(input.filePath, for: .read, settings: sandbox)
/// }
///
/// // In BashTool (Story 14.5):
/// if let sandbox = context.sandbox {
///     try SandboxChecker.checkCommand(input.command, settings: sandbox)
/// }
/// ```
///
/// Logger integration: denials are logged at `.info` level because they represent
/// important security events.
enum SandboxChecker {

    // MARK: - Path Checking

    /// Check whether a path is allowed for the given operation.
    ///
    /// Uses normalized prefix matching with segment boundary enforcement:
    /// - `/project/` matches `/project/src/file.swift` (trailing slash ensures boundary)
    /// - `/project/` does NOT match `/project-backup/file.swift`
    ///
    /// - Parameters:
    ///   - path: The path to check.
    ///   - operation: Whether this is a `.read` or `.write` operation.
    ///   - settings: The sandbox settings to apply.
    /// - Returns: `true` if the path is allowed, `false` otherwise.
    public static func isPathAllowed(
        _ path: String,
        for operation: SandboxOperation,
        settings: SandboxSettings
    ) -> Bool {
        // No restrictions configured: all paths allowed
        if settings.allowedReadPaths.isEmpty
            && settings.allowedWritePaths.isEmpty
            && settings.deniedPaths.isEmpty {
            return true
        }

        let normalizedPath = SandboxPathNormalizer.normalize(path)

        // Check denied paths first (takes precedence)
        for deniedPath in settings.deniedPaths {
            let normalizedDenied = SandboxPathNormalizer.normalize(deniedPath)
            if isPrefixMatch(normalizedPath: normalizedPath, configuredPath: normalizedDenied) {
                return false
            }
        }

        // Check allowed paths based on operation
        switch operation {
        case .read:
            if settings.allowedReadPaths.isEmpty {
                return true // No read restrictions, all reads allowed
            }
            return settings.allowedReadPaths.contains { allowedPath in
                let normalizedAllowed = SandboxPathNormalizer.normalize(allowedPath)
                return isPrefixMatch(normalizedPath: normalizedPath, configuredPath: normalizedAllowed)
            }

        case .write:
            if settings.allowedWritePaths.isEmpty {
                return true // No write restrictions, all writes allowed
            }
            return settings.allowedWritePaths.contains { allowedPath in
                let normalizedAllowed = SandboxPathNormalizer.normalize(allowedPath)
                return isPrefixMatch(normalizedPath: normalizedPath, configuredPath: normalizedAllowed)
            }
        }
    }

    /// Verify a path is allowed and throw if denied.
    ///
    /// - Parameters:
    ///   - path: The path to check.
    ///   - operation: The operation type (`.read` or `.write`).
    ///   - settings: The sandbox settings to apply.
    /// - Throws: ``SDKError/permissionDenied(tool:reason:)`` if the path is denied.
    public static func checkPath(
        _ path: String,
        for operation: SandboxOperation,
        settings: SandboxSettings
    ) throws {
        guard isPathAllowed(path, for: operation, settings: settings) else {
            let toolName = operation == .read ? "Read" : "Write"
            let reason = "path '\(path)' is outside allowed \(operation.rawValue) scope"

            Logger.shared.info("SandboxChecker", "sandbox_denial", data: [
                "type": "path_\(operation.rawValue)",
                "value": path,
                "reason": reason
            ])

            throw SDKError.permissionDenied(tool: toolName, reason: reason)
        }
    }

    // MARK: - Command Checking

    /// Check whether a command is allowed under the given settings.
    ///
    /// - If ``SandboxSettings/allowedCommands`` is non-nil (allowlist mode):
    ///   only listed commands are permitted.
    /// - If ``SandboxSettings/allowedCommands`` is `nil` (blocklist mode):
    ///   all commands except ``SandboxSettings/deniedCommands`` are permitted.
    /// - If no restrictions are configured: all commands are allowed.
    ///
    /// - Parameters:
    ///   - command: The command to check (may be a full path like `/usr/bin/rm`).
    ///   - settings: The sandbox settings to apply.
    /// - Returns: `true` if the command is allowed, `false` otherwise.
    public static func isCommandAllowed(
        _ command: String,
        settings: SandboxSettings
    ) -> Bool {
        // No restrictions configured: all commands allowed
        if settings.deniedCommands.isEmpty && settings.allowedCommands == nil {
            return true
        }

        let basename = extractCommandBasename(command)

        // Allowlist mode: only listed commands are permitted
        if let allowed = settings.allowedCommands {
            return allowed.contains(basename)
        }

        // Blocklist mode: deny listed commands
        return !settings.deniedCommands.contains(basename)
    }

    /// Verify a command is allowed and throw if denied.
    ///
    /// - Parameters:
    ///   - command: The command to check.
    ///   - settings: The sandbox settings to apply.
    /// - Throws: ``SDKError/permissionDenied(tool:reason:)`` if the command is denied.
    public static func checkCommand(
        _ command: String,
        settings: SandboxSettings
    ) throws {
        let basename = extractCommandBasename(command)

        guard isCommandAllowed(command, settings: settings) else {
            let reason = "command '\(basename)' is denied by sandbox policy"

            Logger.shared.info("SandboxChecker", "sandbox_denial", data: [
                "type": "command",
                "value": basename,
                "reason": reason
            ])

            throw SDKError.permissionDenied(tool: "Bash", reason: reason)
        }
    }

    // MARK: - Internal Helpers

    /// Check prefix match with path-segment boundary enforcement.
    ///
    /// A configured path `/project/` matches input `/project/src/file.swift`
    /// but NOT `/project-backup/file.swift`.
    private static func isPrefixMatch(normalizedPath: String, configuredPath: String) -> Bool {
        // Ensure consistent trailing slash handling for segment boundary
        let normalizedConfigured: String
        if configuredPath.hasSuffix("/") {
            normalizedConfigured = configuredPath
        } else {
            // Without trailing slash, add one for segment boundary check
            normalizedConfigured = configuredPath + "/"
        }

        // Check if input path starts with configured path (with segment boundary)
        if normalizedPath.hasPrefix(normalizedConfigured) {
            return true
        }

        // Also check exact match (configured path without trailing slash == input path)
        if normalizedPath == configuredPath {
            return true
        }

        return false
    }

    /// Extract the basename from a command string.
    ///
    /// The first whitespace-delimited token is treated as the command; all
    /// arguments are discarded before basename extraction.
    ///
    /// - `rm -rf /tmp/test` -> `rm`
    /// - `/usr/bin/rm -rf` -> `rm`
    /// - `rm` -> `rm`
    /// - `\rm` -> `rm` (strips leading backslash)
    /// - `"rm" -rf` -> `rm` (strips surrounding quotes)
    static func extractCommandBasename(_ command: String) -> String {
        var cmd = command.trimmingCharacters(in: .whitespaces)

        // Strip leading backslash
        if cmd.hasPrefix("\\") {
            cmd = String(cmd.dropFirst())
        }

        // Strip surrounding quotes from the first token
        if (cmd.hasPrefix("\"") && cmd.hasSuffix("\""))
            || (cmd.hasPrefix("'") && cmd.hasSuffix("'")) {
            cmd = String(cmd.dropFirst().dropLast())
        }

        // Extract only the first token (the command) before any arguments
        if let spaceRange = cmd.rangeOfCharacter(from: .whitespaces) {
            cmd = String(cmd[..<spaceRange.lowerBound])
        }

        // Strip surrounding quotes from the isolated first token
        // (handles cases like `"rm" -rf` where quotes only wrap the command)
        if (cmd.hasPrefix("\"") && cmd.hasSuffix("\""))
            || (cmd.hasPrefix("'") && cmd.hasSuffix("'")) {
            cmd = String(cmd.dropFirst().dropLast())
        }

        // Extract basename from path
        if cmd.contains("/") {
            return URL(fileURLWithPath: cmd).lastPathComponent
        }

        return cmd
    }
}

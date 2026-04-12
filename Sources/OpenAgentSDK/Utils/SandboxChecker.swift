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
/// ## Known Limitations (Command Filtering)
///
/// Blocklist mode (``SandboxSettings/deniedCommands``) is best-effort.
/// The following bypass vectors are **not** covered:
/// - **Pipe attacks**: `echo payload | bash`
/// - **Interpreter escape**: `python -c "..."`, `node -e "..."`
/// - **exec built-in**: `exec rm -rf /tmp`
/// - **Legitimate destructive commands**: `find / -delete`
///
/// **Production environments should use allowlist mode** (``SandboxSettings/allowedCommands``)
/// for strong security. Allowlist mode only permits explicitly listed commands,
/// blocking all unknown vectors by default.
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

        // Check for subshell invocation: bash -c "cmd"
        switch extractSubshellCommand(command) {
        case .innerCommand(let innerCmd):
            return isCommandAllowed(innerCmd, settings: settings)
        case .unparseable:
            return false // Deny by default for unparseable patterns
        case .notSubshell:
            break
        }

        // Check for command substitution: $(cmd) or `cmd`
        let substitutions = extractCommandSubstitution(command)
        if !substitutions.isEmpty {
            for innerCmd in substitutions {
                let innerBasename = extractCommandBasename(innerCmd)
                if let allowed = settings.allowedCommands {
                    if !allowed.contains(innerBasename) {
                        return false
                    }
                } else if settings.deniedCommands.contains(innerBasename) {
                    return false
                }
            }
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
    /// Performs three-phase checking:
    /// 1. Shell metacharacter detection (subshell, command substitution, escape bypasses)
    /// 2. Basename extraction from command path
    /// 3. Allowlist/blocklist matching
    ///
    /// - Parameters:
    ///   - command: The command to check.
    ///   - settings: The sandbox settings to apply.
    /// - Throws: ``SDKError/permissionDenied(tool:reason:)`` if the command is denied.
    public static func checkCommand(
        _ command: String,
        settings: SandboxSettings
    ) throws {
        // Phase 1: No restrictions configured -- all commands allowed
        guard !settings.deniedCommands.isEmpty || settings.allowedCommands != nil else {
            return
        }

        // Phase 2: Shell metacharacter detection (subshell, substitution, escape bypasses)
        try checkShellMetacharacters(command, settings: settings)

        // Phase 3: Basename extraction + allowlist/blocklist matching
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

    // MARK: - Shell Metacharacter Detection

    /// Known shell binary names used in subshell invocations (e.g. `bash -c "cmd"`).
    private static let shellBinaries = ["bash", "sh", "zsh", "dash", "ksh"]

    /// Result of subshell command extraction.
    private enum SubshellExtraction {
        /// The command is not a subshell invocation.
        case notSubshell
        /// The inner command was successfully extracted.
        case innerCommand(String)
        /// A subshell pattern was detected but could not be reliably parsed (deny by default).
        case unparseable
    }

    /// Detect and handle shell metacharacter bypass attempts.
    ///
    /// This method inspects the command string for patterns that could be used to
    /// circumvent the sandbox's command filtering:
    /// - **Subshell invocation**: `bash -c "cmd"`, `sh -c "cmd"`, `zsh -c "cmd"`, etc.
    /// - **Command substitution**: `$(cmd)` or `` `cmd` ``
    /// - **Escape/quote bypasses**: `\cmd`, `"cmd"`, `'cmd'` (handled by ``extractCommandBasename(_:)``)
    ///
    /// If metacharacters cannot be reliably parsed, the command is denied by default.
    ///
    /// - Parameters:
    ///   - command: The raw command string to inspect.
    ///   - settings: The sandbox settings to apply.
    /// - Throws: ``SDKError/permissionDenied(tool:reason:)`` if a bypass is detected or parsing is ambiguous.
    static func checkShellMetacharacters(
        _ command: String,
        settings: SandboxSettings
    ) throws {
        let trimmed = command.trimmingCharacters(in: .whitespaces)

        // Check for subshell invocation: bash -c "cmd", sh -c 'cmd', etc.
        switch extractSubshellCommand(trimmed) {
        case .innerCommand(let innerCmd):
            // Recursively check the inner command
            try checkCommand(innerCmd, settings: settings)
            return
        case .unparseable:
            // Deny by default for unparseable subshell patterns
            let reason = "command contains unparseable shell metacharacters"
            Logger.shared.info("SandboxChecker", "sandbox_denial", data: [
                "type": "unparseable_metachar",
                "value": trimmed,
                "reason": reason
            ])
            throw SDKError.permissionDenied(tool: "Bash", reason: reason)
        case .notSubshell:
            break // Continue to other checks
        }

        // Check for command substitution: $(cmd) or `cmd`
        let substitutions = extractCommandSubstitution(trimmed)
        for innerCmd in substitutions {
            let innerBasename = extractCommandBasename(innerCmd)
            if let allowed = settings.allowedCommands {
                if !allowed.contains(innerBasename) {
                    let reason = "command '\(innerBasename)' is denied by sandbox policy (detected in substitution)"
                    Logger.shared.info("SandboxChecker", "sandbox_denial", data: [
                        "type": "command_substitution",
                        "value": innerBasename,
                        "reason": reason
                    ])
                    throw SDKError.permissionDenied(tool: "Bash", reason: reason)
                }
            } else if !settings.deniedCommands.isEmpty {
                if settings.deniedCommands.contains(innerBasename) {
                    let reason = "command '\(innerBasename)' is denied by sandbox policy (detected in substitution)"
                    Logger.shared.info("SandboxChecker", "sandbox_denial", data: [
                        "type": "command_substitution",
                        "value": innerBasename,
                        "reason": reason
                    ])
                    throw SDKError.permissionDenied(tool: "Bash", reason: reason)
                }
            }
        }
    }

    /// Extract the inner command from a subshell invocation pattern.
    ///
    /// Matches patterns like:
    /// - `bash -c "rm -rf /tmp"` -> `.innerCommand("rm -rf /tmp")`
    /// - `sh -c 'rm -rf /tmp'` -> `.innerCommand("rm -rf /tmp")`
    /// - `/bin/bash -c "rm -rf /tmp"` -> `.innerCommand("rm -rf /tmp")`
    /// - `bash -c "bash -c 'rm -rf /tmp'"` -> `.unparseable` (deeply nested)
    ///
    /// Returns `.notSubshell` if the command does not match a subshell pattern.
    private static func extractSubshellCommand(_ command: String) -> SubshellExtraction {
        // Extract the first token (command name) and get its basename
        var firstToken = command
        if let spaceRange = firstToken.rangeOfCharacter(from: .whitespaces) {
            firstToken = String(firstToken[..<spaceRange.lowerBound])
        }

        // Strip leading backslash and quotes from the first token
        if firstToken.hasPrefix("\\") {
            firstToken = String(firstToken.dropFirst())
        }
        if (firstToken.hasPrefix("\"") && firstToken.hasSuffix("\""))
            || (firstToken.hasPrefix("'") && firstToken.hasSuffix("'")) {
            firstToken = String(firstToken.dropFirst().dropLast())
        }

        // Extract basename if it's a path
        let basename: String
        if firstToken.contains("/") {
            basename = URL(fileURLWithPath: firstToken).lastPathComponent
        } else {
            basename = firstToken
        }

        // Only proceed if the command is a known shell binary
        guard shellBinaries.contains(basename) else {
            return .notSubshell
        }

        // Find the "-c" flag and extract its argument
        // Pattern: <shell> [-options...] -c <command_string>
        let remaining = command.trimmingCharacters(in: .whitespaces)

        // Find "-c" flag as a standalone argument (surrounded by whitespace)
        // Uses character-by-character scan to handle both spaces and tabs.
        let chars = Array(remaining)
        var cFlagEnd: Int? = nil
        var i = 0
        while i < chars.count - 2 {
            // Look for: whitespace + '-' + 'c' + whitespace-or-end
            if chars[i].isWhitespace && chars[i + 1] == "-" && chars[i + 2] == "c" {
                if i + 3 >= chars.count || chars[i + 3].isWhitespace {
                    // Found " -c " or " -c" at end
                    cFlagEnd = i + 3
                    break
                }
            }
            i += 1
        }

        guard let flagEnd = cFlagEnd else {
            // No -c flag found -- shell without -c is just the shell itself
            return .notSubshell
        }

        // Check if there's nothing after -c (no argument -- unparseable)
        let afterFlag = remaining[remaining.index(remaining.startIndex, offsetBy: flagEnd)...]
            .trimmingCharacters(in: .whitespaces)
        if afterFlag.isEmpty {
            return .unparseable
        }

        var afterC = afterFlag

        // Strip surrounding quotes from the -c argument
        if afterC.hasPrefix("\"") && afterC.hasSuffix("\"") {
            afterC = String(afterC.dropFirst().dropLast())
        } else if afterC.hasPrefix("'") && afterC.hasSuffix("'") {
            afterC = String(afterC.dropFirst().dropLast())
        }

        // Check for nested subshell patterns (unparseable)
        // If the inner command itself starts with a shell binary, it's deeply nested
        let innerFirstToken: String
        if let spaceRange = afterC.rangeOfCharacter(from: .whitespaces) {
            innerFirstToken = String(afterC[..<spaceRange.lowerBound])
        } else {
            innerFirstToken = afterC
        }

        if shellBinaries.contains(innerFirstToken) {
            // Deeply nested: deny by default (unparseable)
            return .unparseable
        }

        return afterC.isEmpty ? .unparseable : .innerCommand(afterC)
    }

    /// Extract all inner commands from command substitution patterns.
    ///
    /// Matches patterns like:
    /// - `$(rm -rf /tmp)` -> `["rm -rf /tmp"]`
    /// - `$(rm) && $(sudo ...)` -> `["rm", "sudo ..."]`
    /// - `` `rm -rf /tmp` `` -> `["rm -rf /tmp"]`
    ///
    /// Returns an empty array if no substitution pattern is found.
    private static func extractCommandSubstitution(_ command: String) -> [String] {
        var results: [String] = []

        // Extract all $() substitutions
        var searchStart = command.startIndex
        while let dollarRange = command.range(of: "$(", options: .literal, range: searchStart..<command.endIndex) {
            let afterDollarParen = command[dollarRange.upperBound...]
            if let closeParen = afterDollarParen.firstIndex(of: ")") {
                let inner = String(afterDollarParen[..<closeParen]).trimmingCharacters(in: .whitespaces)
                if !inner.isEmpty {
                    results.append(inner)
                }
                searchStart = command.index(after: closeParen)
            } else {
                break
            }
        }

        // Extract all backtick substitutions
        var backtickStart = command.startIndex
        while let firstBacktick = command.range(of: "`", range: backtickStart..<command.endIndex).map({ $0.lowerBound }) {
            let afterFirst = command[firstBacktick...]
            let afterDrop = afterFirst.dropFirst()
            if let secondBacktick = afterDrop.firstIndex(of: "`") {
                let inner = String(afterDrop[..<secondBacktick]).trimmingCharacters(in: .whitespaces)
                if !inner.isEmpty {
                    results.append(inner)
                }
                backtickStart = command.index(after: secondBacktick)
            } else {
                break
            }
        }

        return results
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

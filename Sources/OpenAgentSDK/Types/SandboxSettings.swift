import Foundation

/// Operation type for sandbox path access checks.
///
/// Used by ``SandboxChecker/isPathAllowed(_:for:settings:)`` to distinguish
/// between read and write access permissions.
public enum SandboxOperation: String, Sendable, Equatable {
    /// Read access to a filesystem path.
    case read
    /// Write (modify/create/delete) access to a filesystem path.
    case write
}

/// Configuration for sandbox restrictions on agent tool execution.
///
/// `SandboxSettings` controls what commands and filesystem paths an agent is
/// allowed to access during tool execution. It supports two modes:
///
/// - **Blocklist mode** (default): All commands are allowed except those in
///   ``deniedCommands``. All paths are allowed except those in ``deniedPaths``.
/// - **Allowlist mode**: When ``allowedCommands`` is set to a non-nil array,
///   only the listed commands are permitted. This takes precedence over the blocklist.
///
/// Path restrictions use prefix matching with segment boundary enforcement.
/// For example, `/project/` matches `/project/src/file.swift` but NOT
/// `/project-backup/file.swift`.
///
/// ## Usage
///
/// ```swift
/// // Blocklist mode: deny dangerous commands
/// let settings = SandboxSettings(deniedCommands: ["rm", "sudo", "chmod"])
///
/// // Allowlist mode: only allow specific commands
/// let settings = SandboxSettings(allowedCommands: ["git", "swift", "xcodebuild"])
///
/// // Filesystem restrictions
/// let settings = SandboxSettings(
///     allowedReadPaths: ["/project/"],
///     allowedWritePaths: ["/project/build/"],
///     deniedPaths: ["/etc/", "/var/"]
/// )
/// ```
///
/// Use ``SandboxChecker`` for enforcement logic (path/command validation).
public struct SandboxSettings: Sendable, Equatable, CustomStringConvertible {

    /// Paths allowed for read operations. Empty array means all reads are allowed
    /// (unless restricted by ``deniedPaths``).
    public var allowedReadPaths: [String]

    /// Paths allowed for write operations. Empty array means all writes are allowed
    /// (unless restricted by ``deniedPaths``).
    public var allowedWritePaths: [String]

    /// Paths explicitly denied for both read and write operations.
    /// Takes precedence over ``allowedReadPaths`` and ``allowedWritePaths``.
    public var deniedPaths: [String]

    /// Commands denied in blocklist mode. Only effective when ``allowedCommands``
    /// is `nil`.
    public var deniedCommands: [String]

    /// Commands allowed in allowlist mode. When `nil`, blocklist mode is active.
    /// When set to a non-nil array (even empty), only listed commands are permitted.
    public var allowedCommands: [String]?

    /// Whether nested sandbox creation is allowed. Defaults to `false`.
    public var allowNestedSandbox: Bool

    /// Create sandbox settings with all fields optional.
    ///
    /// - Parameters:
    ///   - allowedReadPaths: Paths allowed for reading. Defaults to empty (all allowed).
    ///   - allowedWritePaths: Paths allowed for writing. Defaults to empty (all allowed).
    ///   - deniedPaths: Paths denied for all operations. Defaults to empty.
    ///   - deniedCommands: Commands denied in blocklist mode. Defaults to empty.
    ///   - allowedCommands: Commands allowed in allowlist mode. Defaults to `nil` (blocklist mode).
    ///   - allowNestedSandbox: Whether nested sandbox is allowed. Defaults to `false`.
    public init(
        allowedReadPaths: [String] = [],
        allowedWritePaths: [String] = [],
        deniedPaths: [String] = [],
        deniedCommands: [String] = [],
        allowedCommands: [String]? = nil,
        allowNestedSandbox: Bool = false
    ) {
        self.allowedReadPaths = allowedReadPaths
        self.allowedWritePaths = allowedWritePaths
        self.deniedPaths = deniedPaths
        self.deniedCommands = deniedCommands
        self.allowedCommands = allowedCommands
        self.allowNestedSandbox = allowNestedSandbox
    }

    /// A string representation of the sandbox settings for debugging.
    public var description: String {
        var parts: [String] = []
        if !allowedReadPaths.isEmpty {
            parts.append("allowedReadPaths: \(allowedReadPaths)")
        }
        if !allowedWritePaths.isEmpty {
            parts.append("allowedWritePaths: \(allowedWritePaths)")
        }
        if !deniedPaths.isEmpty {
            parts.append("deniedPaths: \(deniedPaths)")
        }
        if !deniedCommands.isEmpty {
            parts.append("deniedCommands: \(deniedCommands)")
        }
        if let allowed = allowedCommands {
            parts.append("allowedCommands: \(allowed)")
        }
        if allowNestedSandbox {
            parts.append("allowNestedSandbox: true")
        }
        return "SandboxSettings(\(parts.joined(separator: ", ")))"
    }
}

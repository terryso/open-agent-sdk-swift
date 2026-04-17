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

/// Network sandbox configuration controlling network access restrictions.
///
/// `SandboxNetworkConfig` defines which network operations are permitted
/// when a sandbox is active. It mirrors the TypeScript SDK's `SandboxNetworkConfig`
/// type to ensure API surface alignment.
///
/// ## Topics
///
/// ### Fields
/// - ``allowedDomains``
/// - ``allowManagedDomainsOnly``
/// - ``allowLocalBinding``
/// - ``allowUnixSockets``
/// - ``allowAllUnixSockets``
/// - ``httpProxyPort``
/// - ``socksProxyPort``
public struct SandboxNetworkConfig: Sendable, Equatable, CustomStringConvertible {

    /// List of domains allowed for network access. Empty array means no domains
    /// are explicitly allowed (behavior depends on other settings).
    public var allowedDomains: [String]

    /// When `true`, only managed (system-controlled) domains are permitted.
    public var allowManagedDomainsOnly: Bool

    /// When `true`, binding to local addresses is permitted.
    public var allowLocalBinding: Bool

    /// When `true`, Unix domain socket connections are permitted.
    public var allowUnixSockets: Bool

    /// When `true`, all Unix domain sockets are permitted (broadens ``allowUnixSockets``).
    public var allowAllUnixSockets: Bool

    /// Optional HTTP proxy port for routing network traffic through a proxy.
    public var httpProxyPort: Int?

    /// Optional SOCKS proxy port for routing network traffic through a SOCKS proxy.
    public var socksProxyPort: Int?

    /// Create network sandbox configuration with optional fields.
    ///
    /// - Parameters:
    ///   - allowedDomains: Domains permitted for access. Defaults to empty.
    ///   - allowManagedDomainsOnly: Restrict to managed domains only. Defaults to `false`.
    ///   - allowLocalBinding: Allow local address binding. Defaults to `false`.
    ///   - allowUnixSockets: Allow Unix domain sockets. Defaults to `false`.
    ///   - allowAllUnixSockets: Allow all Unix sockets. Defaults to `false`.
    ///   - httpProxyPort: HTTP proxy port. Defaults to `nil`.
    ///   - socksProxyPort: SOCKS proxy port. Defaults to `nil`.
    public init(
        allowedDomains: [String] = [],
        allowManagedDomainsOnly: Bool = false,
        allowLocalBinding: Bool = false,
        allowUnixSockets: Bool = false,
        allowAllUnixSockets: Bool = false,
        httpProxyPort: Int? = nil,
        socksProxyPort: Int? = nil
    ) {
        self.allowedDomains = allowedDomains
        self.allowManagedDomainsOnly = allowManagedDomainsOnly
        self.allowLocalBinding = allowLocalBinding
        self.allowUnixSockets = allowUnixSockets
        self.allowAllUnixSockets = allowAllUnixSockets
        self.httpProxyPort = httpProxyPort
        self.socksProxyPort = socksProxyPort
    }

    public var description: String {
        "SandboxNetworkConfig(domains: \(allowedDomains), managedOnly: \(allowManagedDomainsOnly), localBinding: \(allowLocalBinding), unixSockets: \(allowUnixSockets), allUnixSockets: \(allowAllUnixSockets), httpProxy: \(httpProxyPort.map { "\($0)" } ?? "none"), socksProxy: \(socksProxyPort.map { "\($0)" } ?? "none"))"
    }
}

/// Configuration for custom ripgrep binary and arguments.
///
/// `RipgrepConfig` allows specifying a custom ripgrep executable path
/// and optional arguments, mirroring the TypeScript SDK's `ripgrep` field.
///
/// ## Topics
///
/// ### Fields
/// - ``command``
/// - ``args``
public struct RipgrepConfig: Sendable, Equatable, CustomStringConvertible {

    /// Path or name of the ripgrep executable to use.
    public var command: String

    /// Optional arguments to pass to the ripgrep command.
    public var args: [String]?

    /// Create ripgrep configuration.
    ///
    /// - Parameters:
    ///   - command: Path or name of the ripgrep executable.
    ///   - args: Optional arguments for the command. Defaults to `nil`.
    public init(command: String, args: [String]? = nil) {
        self.command = command
        self.args = args
    }

    public var description: String {
        if let args {
            return "RipgrepConfig(command: \(command), args: \(args))"
        }
        return "RipgrepConfig(command: \(command))"
    }
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

    /// When `true` and sandbox is active, BashTool skips the `canUseTool`
    /// authorization check and auto-executes. Commands still run through
    /// ``SandboxChecker/checkCommand(_:settings:)`` for enforcement.
    /// Defaults to `false`.
    public var autoAllowBashIfSandboxed: Bool

    /// When `true`, the model may request unsandboxed execution. This field
    /// stores the configuration intent; actual runtime escape-hatch behavior
    /// is additive for future use. Defaults to `false`.
    public var allowUnsandboxedCommands: Bool

    /// Category-based violation suppression rules. Keys are violation categories
    /// (e.g., `"file"`, `"network"`, `"command"`) and values are arrays of
    /// patterns to suppress. Defaults to `nil` (no suppression).
    public var ignoreViolations: [String: [String]]?

    /// Controls whether nested sandbox environments can use weaker restrictions.
    /// Different semantics from ``allowNestedSandbox`` which controls whether
    /// nested sandbox is allowed at all. Defaults to `false`.
    public var enableWeakerNestedSandbox: Bool

    /// Network sandbox configuration. When `nil`, network restrictions are not
    /// applied. Defaults to `nil`.
    public var network: SandboxNetworkConfig?

    /// Custom ripgrep configuration specifying the executable path and optional
    /// arguments. When `nil`, the default ripgrep behavior is used.
    /// Defaults to `nil`.
    public var ripgrep: RipgrepConfig?

    /// Create sandbox settings with all fields optional.
    ///
    /// All new parameters have backward-compatible defaults. Existing call sites
    /// remain unbroken when using positional or named parameters for the original
    /// 6 fields.
    ///
    /// - Parameters:
    ///   - allowedReadPaths: Paths allowed for reading. Defaults to empty (all allowed).
    ///   - allowedWritePaths: Paths allowed for writing. Defaults to empty (all allowed).
    ///   - deniedPaths: Paths denied for all operations. Defaults to empty.
    ///   - deniedCommands: Commands denied in blocklist mode. Defaults to empty.
    ///   - allowedCommands: Commands allowed in allowlist mode. Defaults to `nil` (blocklist mode).
    ///   - allowNestedSandbox: Whether nested sandbox is allowed. Defaults to `false`.
    ///   - autoAllowBashIfSandboxed: Auto-approve Bash when sandboxed. Defaults to `false`.
    ///   - allowUnsandboxedCommands: Allow model to request unsandboxed execution. Defaults to `false`.
    ///   - ignoreViolations: Category-based violation suppression. Defaults to `nil`.
    ///   - enableWeakerNestedSandbox: Allow weaker nested sandbox restrictions. Defaults to `false`.
    ///   - network: Network sandbox configuration. Defaults to `nil`.
    ///   - ripgrep: Custom ripgrep configuration. Defaults to `nil`.
    public init(
        allowedReadPaths: [String] = [],
        allowedWritePaths: [String] = [],
        deniedPaths: [String] = [],
        deniedCommands: [String] = [],
        allowedCommands: [String]? = nil,
        allowNestedSandbox: Bool = false,
        autoAllowBashIfSandboxed: Bool = false,
        allowUnsandboxedCommands: Bool = false,
        ignoreViolations: [String: [String]]? = nil,
        enableWeakerNestedSandbox: Bool = false,
        network: SandboxNetworkConfig? = nil,
        ripgrep: RipgrepConfig? = nil
    ) {
        self.allowedReadPaths = allowedReadPaths
        self.allowedWritePaths = allowedWritePaths
        self.deniedPaths = deniedPaths
        self.deniedCommands = deniedCommands
        self.allowedCommands = allowedCommands
        self.allowNestedSandbox = allowNestedSandbox
        self.autoAllowBashIfSandboxed = autoAllowBashIfSandboxed
        self.allowUnsandboxedCommands = allowUnsandboxedCommands
        self.ignoreViolations = ignoreViolations
        self.enableWeakerNestedSandbox = enableWeakerNestedSandbox
        self.network = network
        self.ripgrep = ripgrep
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
        if autoAllowBashIfSandboxed {
            parts.append("autoAllowBashIfSandboxed: true")
        }
        if allowUnsandboxedCommands {
            parts.append("allowUnsandboxedCommands: true")
        }
        if let ignoreViolations {
            parts.append("ignoreViolations: \(ignoreViolations)")
        }
        if enableWeakerNestedSandbox {
            parts.append("enableWeakerNestedSandbox: true")
        }
        if let network {
            parts.append("network: \(network)")
        }
        if let ripgrep {
            parts.append("ripgrep: \(ripgrep)")
        }
        return "SandboxSettings(\(parts.joined(separator: ", ")))"
    }
}

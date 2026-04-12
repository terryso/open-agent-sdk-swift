import Foundation

/// SDK configuration resolved from environment variables and/or programmatic values.
///
/// `SDKConfiguration` provides a clean way to configure the SDK through either
/// environment variables (`CODEANY_API_KEY`, `CODEANY_MODEL`, `CODEANY_BASE_URL`)
/// or programmatic construction. Use ``resolved(overrides:)`` to merge both sources
/// with programmatic values taking precedence.
///
/// ## Environment Variable Mapping
///
/// | Environment Variable | Property   | Default (if unset) |
/// |----------------------|------------|--------------------|
/// | `CODEANY_API_KEY`    | `apiKey`   | `nil`              |
/// | `CODEANY_MODEL`      | `model`    | `"claude-sonnet-4-6"` |
/// | `CODEANY_BASE_URL`   | `baseURL`  | `nil`              |
///
/// ## Usage
///
/// ```swift
/// // Programmatic configuration
/// let config = SDKConfiguration(apiKey: "sk-...", model: "claude-sonnet-4-6")
///
/// // From environment variables
/// let config = SDKConfiguration.fromEnvironment()
///
/// // Merge: programmatic overrides > env vars > defaults
/// let config = SDKConfiguration.resolved(overrides: myConfig)
/// ```
public struct SDKConfiguration: Sendable, Equatable, CustomStringConvertible,
    CustomDebugStringConvertible
{

    /// API key for authenticating with the LLM provider.
    public var apiKey: String?

    /// Model identifier to use for requests.
    public var model: String

    /// Base URL for the LLM API endpoint. `nil` uses the provider default.
    public var baseURL: String?

    /// Maximum number of agent loop turns.
    public var maxTurns: Int

    /// Maximum number of tokens per request.
    public var maxTokens: Int

    /// Maximum number of entries in the file cache. Defaults to 100.
    public var fileCacheMaxEntries: Int

    /// Maximum total size of the file cache in bytes. Defaults to 25 MB.
    public var fileCacheMaxSizeBytes: Int

    /// Maximum size of a single file cache entry in bytes. Defaults to 5 MB.
    public var fileCacheMaxEntrySizeBytes: Int

    /// Cache time-to-live for Git context collection, in seconds.
    /// Within this window, repeated calls reuse the cached Git status.
    /// Set to `0` to disable caching (every call refreshes). Defaults to 5.0 seconds.
    public var gitCacheTTL: TimeInterval

    /// Explicit project root directory for instruction file discovery.
    /// When `nil`, the SDK discovers the project root by traversing upward
    /// from the current working directory looking for a `.git` directory.
    /// Defaults to `nil` (auto-discover).
    public var projectRoot: String?

    /// Minimum log level for SDK-internal logging. Defaults to ``LogLevel/none`` (silent).
    public var logLevel: LogLevel

    /// Output destination for log entries. Defaults to ``LogOutput/console`` (stderr).
    public var logOutput: LogOutput

    /// Optional sandbox settings for restricting agent tool execution.
    /// When `nil` (default), no sandbox restrictions are applied.
    public var sandbox: SandboxSettings?

    /// Default model used when none is specified.
    public static let defaultModel = "claude-sonnet-4-6"

    /// Default maximum number of agent loop turns.
    public static let defaultMaxTurns = 10

    /// Default maximum number of tokens per request.
    public static let defaultMaxTokens = 16384

    // MARK: - Programmatic Initializer

    /// Create a configuration programmatically.
    ///
    /// All parameters are optional and have sensible defaults.
    /// This initializer does not read any environment variables.
    ///
    /// - Parameters:
    ///   - apiKey: API key for the LLM provider. Defaults to `nil`.
    ///   - model: Model identifier. Defaults to `"claude-sonnet-4-6"`.
    ///   - baseURL: Custom API base URL. Defaults to `nil`.
    ///   - maxTurns: Maximum agent loop turns. Defaults to `10`.
    ///   - maxTokens: Maximum tokens per request. Defaults to `16384`.
    ///   - fileCacheMaxEntries: Maximum cached file entries. Defaults to `100`.
    ///   - fileCacheMaxSizeBytes: Maximum total cache size in bytes. Defaults to `25 MB`.
    ///   - fileCacheMaxEntrySizeBytes: Maximum single cache entry size in bytes. Defaults to `5 MB`.
    public init(
        apiKey: String? = nil,
        model: String = "claude-sonnet-4-6",
        baseURL: String? = nil,
        maxTurns: Int = 10,
        maxTokens: Int = 16384,
        fileCacheMaxEntries: Int = 100,
        fileCacheMaxSizeBytes: Int = 25 * 1024 * 1024,
        fileCacheMaxEntrySizeBytes: Int = 5 * 1024 * 1024,
        gitCacheTTL: TimeInterval = 5.0,
        projectRoot: String? = nil,
        logLevel: LogLevel = .none,
        logOutput: LogOutput = .console,
        sandbox: SandboxSettings? = nil
    ) {
        self.apiKey = Self.sanitizeAPIKey(apiKey)
        self.model = model
        self.baseURL = baseURL
        self.maxTurns = maxTurns
        self.maxTokens = maxTokens
        self.fileCacheMaxEntries = fileCacheMaxEntries
        self.fileCacheMaxSizeBytes = fileCacheMaxSizeBytes
        self.fileCacheMaxEntrySizeBytes = fileCacheMaxEntrySizeBytes
        self.gitCacheTTL = gitCacheTTL
        self.projectRoot = projectRoot
        self.logLevel = logLevel
        self.logOutput = logOutput
        self.sandbox = sandbox
    }

    // MARK: - Environment Variable Parsing

    /// Create a configuration by reading environment variables.
    ///
    /// Reads `CODEANY_API_KEY`, `CODEANY_MODEL`, and `CODEANY_BASE_URL`
    /// from the process environment. Values not set in the environment
    /// fall back to defaults.
    ///
    /// - Returns: A configuration populated from environment variables.
    public static func fromEnvironment() -> SDKConfiguration {
        let envAPIKey = getEnv("CODEANY_API_KEY")
        let envModel = getEnv("CODEANY_MODEL") ?? Self.defaultModel
        let envBaseURL = getEnv("CODEANY_BASE_URL")

        return SDKConfiguration(
            apiKey: envAPIKey,
            model: envModel,
            baseURL: envBaseURL
        )
    }

    // MARK: - Merge (Programmatic Overrides + Environment Fallback)

    /// Resolve configuration by merging programmatic overrides with environment variables.
    ///
    /// Priority order (highest to lowest):
    /// 1. Programmatic overrides (non-nil / non-default values)
    /// 2. Environment variables (`CODEANY_*`)
    /// 3. Built-in defaults
    ///
    /// For `apiKey` and `baseURL`: a non-nil override takes precedence; otherwise
    /// the environment variable is used.
    /// For `model`, `maxTurns`, `maxTokens`: the override value is always used.
    /// Only Optional fields fall back to environment variables.
    ///
    /// - Parameter overrides: Programmatic configuration values. Pass `nil` to use
    ///   only environment variables and defaults.
    /// - Returns: The resolved configuration.
    public static func resolved(overrides: SDKConfiguration? = nil) -> SDKConfiguration {
        let env = fromEnvironment()

        guard let overrides = overrides else {
            return env
        }

        return SDKConfiguration(
            apiKey: overrides.apiKey ?? env.apiKey,
            model: overrides.model,
            baseURL: overrides.baseURL ?? env.baseURL,
            maxTurns: overrides.maxTurns,
            maxTokens: overrides.maxTokens,
            fileCacheMaxEntries: overrides.fileCacheMaxEntries,
            fileCacheMaxSizeBytes: overrides.fileCacheMaxSizeBytes,
            fileCacheMaxEntrySizeBytes: overrides.fileCacheMaxEntrySizeBytes,
            gitCacheTTL: overrides.gitCacheTTL,
            projectRoot: overrides.projectRoot,
            logLevel: overrides.logLevel,
            logOutput: overrides.logOutput,
            sandbox: overrides.sandbox ?? env.sandbox
        )
    }

    // MARK: - CustomStringConvertible (API Key Masking)

    /// A string representation with the API key masked as `"***"`.
    public var description: String {
        "SDKConfiguration(apiKey: \(maskedAPIKey), model: \"\(model)\", "
            + "baseURL: \(baseURL.map { "\"\($0)\"" } ?? "nil"), "
            + "maxTurns: \(maxTurns), maxTokens: \(maxTokens), "
            + "fileCacheMaxEntries: \(fileCacheMaxEntries), "
            + "fileCacheMaxSizeBytes: \(fileCacheMaxSizeBytes), "
            + "fileCacheMaxEntrySizeBytes: \(fileCacheMaxEntrySizeBytes), "
            + "gitCacheTTL: \(gitCacheTTL), "
            + "projectRoot: \(projectRoot.map { "\"\($0)\"" } ?? "nil"), "
            + "logLevel: \(logLevel.description), "
            + "logOutput: \(logOutputDescription), "
            + "sandbox: \(sandbox?.description ?? "nil"))"
    }

    /// A debug representation with the API key masked as `"***"`.
    public var debugDescription: String {
        "SDKConfiguration(apiKey: \(maskedAPIKey), model: \"\(model)\", "
            + "baseURL: \(baseURL.map { "\"\($0)\"" } ?? "nil"), "
            + "maxTurns: \(maxTurns), maxTokens: \(maxTokens), "
            + "fileCacheMaxEntries: \(fileCacheMaxEntries), "
            + "fileCacheMaxSizeBytes: \(fileCacheMaxSizeBytes), "
            + "fileCacheMaxEntrySizeBytes: \(fileCacheMaxEntrySizeBytes), "
            + "gitCacheTTL: \(gitCacheTTL), "
            + "projectRoot: \(projectRoot.map { "\"\($0)\"" } ?? "nil"), "
            + "logLevel: \(logLevel.description), "
            + "logOutput: \(logOutputDescription), "
            + "sandbox: \(sandbox?.description ?? "nil"))"
    }

    /// Description of logOutput for display (masks custom closure).
    private var logOutputDescription: String {
        switch logOutput {
        case .console:
            return ".console"
        case .file(let url):
            return ".file(\(url.path))"
        case .custom:
            return ".custom(<closure>)"
        }
    }

    // MARK: - Internal Helpers

    /// Mask the API key for safe display in logs and descriptions.
    private var maskedAPIKey: String {
        guard let key = apiKey, !key.isEmpty else {
            return "nil"
        }
        return "\"***\""
    }

    /// Sanitize an API key: treat empty or whitespace-only strings as nil.
    private static func sanitizeAPIKey(_ key: String?) -> String? {
        guard let key = key, !key.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        return key
    }
}

import Foundation

/// Result of collecting project-level instruction files.
///
/// Contains global instructions (from `~/.claude/CLAUDE.md`) and
/// project instructions (from `{projectRoot}/CLAUDE.md` and `{projectRoot}/AGENT.md`)
/// as separate optional strings.
public struct ProjectContextResult: Sendable, Equatable {
    /// Global instructions loaded from `~/.claude/CLAUDE.md`, or `nil` if not found.
    public let globalInstructions: String?

    /// Project instructions loaded from `{projectRoot}/CLAUDE.md` and/or
    /// `{projectRoot}/AGENT.md` (merged, CLAUDE.md first), or `nil` if neither exists.
    public let projectInstructions: String?

    public init(globalInstructions: String? = nil, projectInstructions: String? = nil) {
        self.globalInstructions = globalInstructions
        self.projectInstructions = projectInstructions
    }
}

/// Discovers and loads project-level instruction files (CLAUDE.md, AGENT.md)
/// and global instruction files (~/.claude/CLAUDE.md) for injection into
/// the agent's system prompt.
///
/// ## Project Root Discovery
///
/// 1. If `explicitProjectRoot` is provided, use it directly.
/// 2. Otherwise, traverse upward from `cwd` looking for a `.git` directory.
/// 3. If no `.git` directory is found, use `cwd` as the project root.
///
/// ## File Search List
///
/// - Global: `~/.claude/CLAUDE.md`
/// - Project: `{projectRoot}/CLAUDE.md`, `{projectRoot}/AGENT.md`
///
/// ## Truncation
///
/// Files larger than 100 KB are truncated to 100 KB with a comment appended
/// indicating the original size.
///
/// ## Caching
///
/// Results are cached per `cwd` + `explicitProjectRoot` combination. Within
/// the same Agent instance, repeated calls return the cached result without
/// re-reading files. The cache is invalidated when the parameters change.
///
/// ## Thread Safety
///
/// Uses `final class` + `@unchecked Sendable` + `NSLock` pattern (consistent
/// with `GitContextCollector` and `FileCache`). All mutable state is protected
/// by the lock.
public final class ProjectDocumentDiscovery: @unchecked Sendable {

    // MARK: - Private State

    /// Lock protecting all mutable cache state.
    private let lock = NSLock()

    /// Cached result for the current parameters.
    private var cachedResult: ProjectContextResult?

    /// The cwd + projectRoot combination for which the cache is valid.
    private var cachedCacheKey: String?

    /// Maximum file size in kilobytes before truncation is applied.
    private static let maxSizeKB = 100

    // MARK: - Initialization

    /// Create a new ProjectDocumentDiscovery.
    public init() {}

    // MARK: - Public API

    /// Collect project document context from the filesystem.
    ///
    /// - Parameters:
    ///   - cwd: The current working directory (used for project root discovery).
    ///   - explicitProjectRoot: An explicit project root path. When provided,
    ///     discovery traversal is skipped and this path is used directly.
    ///   - homeDirectory: Override for the user's home directory. Used in tests
    ///     to avoid reading the real `~/.claude/CLAUDE.md`. Defaults to `nil`
    ///     (uses `PlatformUtils.homeDirectory()`).
    /// - Returns: A `ProjectContextResult` with global and project instructions.
    public func collectProjectContext(
        cwd: String,
        explicitProjectRoot: String?,
        homeDirectory: String? = nil
    ) -> ProjectContextResult {
        let normalizedCwd = normalizePath(cwd)
        let normalizedProjectRoot = explicitProjectRoot.map { normalizePath($0) }
        let cacheKey = "\(normalizedCwd)|\(normalizedProjectRoot ?? "nil")"

        // Check cache
        lock.lock()
        if let cached = cachedResult, cachedCacheKey == cacheKey {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Determine project root
        let projectRoot: String
        if let explicit = normalizedProjectRoot {
            projectRoot = explicit
        } else {
            projectRoot = discoverProjectRoot(from: normalizedCwd)
        }

        // Read global instructions: ~/.claude/CLAUDE.md
        let home = homeDirectory ?? PlatformUtils.homeDirectory()
        let globalClaudeDir = (home as NSString).appendingPathComponent(".claude")
        let globalClaudeMdPath = (globalClaudeDir as NSString).appendingPathComponent("CLAUDE.md")
        let globalInstructions = readFileContent(at: globalClaudeMdPath)

        // Read project instructions: CLAUDE.md + AGENT.md
        var projectParts: [String] = []
        let claudeMdPath = (projectRoot as NSString).appendingPathComponent("CLAUDE.md")
        if let claudeContent = readFileContent(at: claudeMdPath) {
            projectParts.append(claudeContent)
        }

        let agentMdPath = (projectRoot as NSString).appendingPathComponent("AGENT.md")
        if let agentContent = readFileContent(at: agentMdPath) {
            projectParts.append(agentContent)
        }

        let projectInstructions: String? = projectParts.isEmpty
            ? nil
            : projectParts.joined(separator: "\n\n")

        let result = ProjectContextResult(
            globalInstructions: globalInstructions,
            projectInstructions: projectInstructions
        )

        // Update cache
        lock.lock()
        cachedResult = result
        cachedCacheKey = cacheKey
        lock.unlock()

        return result
    }

    // MARK: - Private Helpers

    /// Discover the project root by traversing upward from `cwd` looking for a
    /// `.git` directory. If none is found, returns `cwd` itself.
    ///
    /// - Parameter cwd: The starting directory for traversal.
    /// - Returns: The discovered project root path.
    private func discoverProjectRoot(from cwd: String) -> String {
        let fm = FileManager.default
        var currentPath = normalizePath(cwd)

        // Traverse up looking for .git directory
        while true {
            let gitPath = (currentPath as NSString).appendingPathComponent(".git")
            if fm.fileExists(atPath: gitPath) {
                return currentPath
            }

            // Move up one directory
            let parent = (currentPath as NSString).deletingLastPathComponent
            if parent == currentPath {
                // Reached filesystem root without finding .git
                break
            }
            currentPath = parent
        }

        // Fallback: use cwd
        return normalizePath(cwd)
    }

    /// Read file content at the given path, applying truncation for large files
    /// and gracefully handling non-UTF-8 encoding.
    ///
    /// - Parameters:
    ///   - path: The file path to read.
    ///   - maxSizeKB: Maximum file size in kilobytes before truncation (default 100).
    /// - Returns: The file content string, or `nil` if the file does not exist
    ///   or cannot be decoded as UTF-8.
    private func readFileContent(at path: String, maxSizeKB: Int = maxSizeKB) -> String? {
        let fm = FileManager.default

        guard fm.fileExists(atPath: path) else {
            return nil
        }

        guard let data = fm.contents(atPath: path) else {
            return nil
        }

        // Attempt to decode as UTF-8
        guard let content = String(data: data, encoding: .utf8) else {
            // Non-UTF-8 file: skip gracefully (Logger.warn placeholder)
            return nil
        }

        let maxBytes = maxSizeKB * 1024

        // Truncate if exceeds max size
        if data.count > maxBytes {
            // Truncate by UTF-8 byte boundary to stay within maxBytes
            var truncated = ""
            var byteCount = 0
            for scalar in content.unicodeScalars {
                let scalarBytes = scalar.utf8.count
                if byteCount + scalarBytes > maxBytes { break }
                truncated.unicodeScalars.append(scalar)
                byteCount += scalarBytes
            }
            let originalSizeKB = data.count / 1024
            return truncated + "\n<!-- 文件过大，已截断，原大小 \(originalSizeKB) KB -->"
        }

        return content
    }

    /// Normalize a file path for cache key comparison.
    ///
    /// Resolves `.`, `..`, redundant slashes, and symlinks.
    private func normalizePath(_ path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        let url = URL(fileURLWithPath: standardized)
        let resolved = url.resolvingSymlinksInPath().path
        return resolved.isEmpty ? standardized : resolved
    }
}

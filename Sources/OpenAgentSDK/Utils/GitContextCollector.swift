import Foundation

/// Collects Git repository context (branch, status, recent commits) for injection
/// into the agent's system prompt.
///
/// `GitContextCollector` executes Git commands via `Process` to gather repository
/// status information, formats it into an XML block, and caches the result with
/// a configurable TTL. Thread safety is provided by an internal `NSLock`.
///
/// ## Output Format
///
/// When running inside a Git repository, the collected context is wrapped in
/// `<git-context>...</git-context>` tags:
///
/// ```
/// <git-context>
/// Branch: feature/skills
/// Main branch: main
/// Git user: nick
/// Status:
/// M src/Skills.swift
/// A src/SkillRegistry.swift
/// Recent commits:
/// - abc1234: add skill registry
/// - def5678: initial tool system
/// </git-context>
/// ```
///
/// ## Caching
///
/// Results are cached per `cwd` with a configurable TTL. Within the TTL window,
/// repeated calls return the cached result without executing Git commands.
/// Set `ttl: 0` to disable caching entirely.
///
/// ## Thread Safety
///
/// Uses `final class` + `@unchecked Sendable` + `NSLock` pattern (consistent
/// with `FileCache`). All mutable state is protected by the lock.
public final class GitContextCollector: @unchecked Sendable {

    // MARK: - Private State

    /// Lock protecting all mutable cache state.
    private let lock = NSLock()

    /// Cached Git context string (the `<git-context>...</git-context>` block).
    private var cachedContext: String?

    /// The working directory for which the cache is valid.
    private var cachedCwd: String?

    /// Timestamp of the last cache update.
    private var cacheTimestamp: Date = .distantPast

    /// Maximum length for `git status --short` output before truncation.
    private static let maxStatusLength = 2000

    // MARK: - Initialization

    /// Create a new GitContextCollector.
    public init() {}

    // MARK: - Public API

    /// Collect Git context for the given working directory.
    ///
    /// If a cached result exists for the same `cwd` and the TTL has not expired,
    /// returns the cached result immediately. Otherwise, executes Git commands
    /// to collect fresh context.
    ///
    /// - Parameters:
    ///   - cwd: The working directory to collect Git context from.
    ///   - ttl: Cache time-to-live in seconds. Use `0` to disable caching.
    /// - Returns: A formatted `<git-context>...</git-context>` string, or `nil`
    ///   if `cwd` is not inside a Git repository.
    public func collectGitContext(cwd: String, ttl: TimeInterval) -> String? {
        // Normalize cwd for cache key comparison
        let normalizedCwd = normalizePath(cwd)

        lock.lock()
        // Check cache: same cwd and within TTL
        if ttl > 0,
           let cached = cachedContext,
           let cachedCwd = cachedCwd,
           cachedCwd == normalizedCwd
        {
            let elapsed = Date().timeIntervalSince(cacheTimestamp)
            if elapsed < ttl {
                lock.unlock()
                return cached
            }
        }
        lock.unlock()

        // Collect fresh context (outside lock to avoid holding it during Process execution)
        guard let context = collectFreshContext(cwd: cwd) else {
            return nil
        }

        // Update cache
        lock.lock()
        cachedContext = context
        cachedCwd = normalizedCwd
        cacheTimestamp = Date()
        lock.unlock()

        return context
    }

    // MARK: - Private Helpers

    /// Execute a Git command via `Process` and return its trimmed output.
    ///
    /// - Parameters:
    ///   - command: The Git command to execute (e.g., "git rev-parse --abbrev-ref HEAD").
    ///   - cwd: The working directory for the command.
    ///   - timeoutMs: Timeout in milliseconds (default 5000).
    /// - Returns: The trimmed standard output, or `nil` on failure.
    private func runGitCommand(_ command: String, cwd: String, timeoutMs: Int = 5000) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()

            // Apply timeout
            if #available(macOS 13.0, *) {
                let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
                while process.isRunning && Date() < deadline {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.01))
                }
                if process.isRunning {
                    process.terminate()
                    return nil
                }
            } else {
                // Fallback for older macOS: just wait
                process.waitUntilExit()
            }

            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (output?.isEmpty ?? true) ? nil : output
        } catch {
            return nil
        }
    }

    /// Detect the main branch name (prefers "main", falls back to "master").
    ///
    /// - Parameter cwd: The working directory of the Git repository.
    /// - Returns: "main", "master", or `nil` if neither branch exists.
    private func detectMainBranch(cwd: String) -> String? {
        // Check if "main" branch exists
        if let output = runGitCommand("git branch -l main", cwd: cwd),
           output.contains("main") {
            return "main"
        }
        // Check if "master" branch exists
        if let output = runGitCommand("git branch -l master", cwd: cwd),
           output.contains("master") {
            return "master"
        }
        return nil
    }

    /// Collect fresh Git context by executing Git commands.
    ///
    /// - Parameter cwd: The working directory to collect from.
    /// - Returns: A formatted `<git-context>` block, or `nil` if not a Git repo.
    private func collectFreshContext(cwd: String) -> String? {
        // Step 1: Verify this is a Git repository
        guard runGitCommand("git rev-parse --git-dir", cwd: cwd) != nil else {
            return nil
        }

        // Step 2: Get current branch
        let branch = runGitCommand("git rev-parse --abbrev-ref HEAD", cwd: cwd) ?? "unknown"

        // Step 3: Detect main branch
        let mainBranch = detectMainBranch(cwd: cwd)

        // Step 4: Get Git user name
        let gitUser = runGitCommand("git config user.name", cwd: cwd)

        // Step 5: Get git status (with truncation)
        var statusSection = ""
        if let rawStatus = runGitCommand("git status --short", cwd: cwd) {
            if rawStatus.utf8.count > Self.maxStatusLength {
                // Count the number of changed files
                let fileCount = rawStatus.components(separatedBy: "\n").filter { !$0.isEmpty }.count
                // Truncate by UTF-8 byte boundary to stay within maxStatusLength bytes
                var truncated = ""
                var byteCount = 0
                for scalar in rawStatus.unicodeScalars {
                    let scalarBytes = scalar.utf8.count
                    if byteCount + scalarBytes > Self.maxStatusLength { break }
                    truncated.unicodeScalars.append(scalar)
                    byteCount += scalarBytes
                }
                statusSection = truncated + "\n... (output truncated, \(fileCount) total file changes)"
            } else {
                statusSection = rawStatus
            }
        }

        // Step 6: Get recent commits
        var commitsSection = ""
        // First check if there are any commits (git rev-parse HEAD succeeds)
        if runGitCommand("git rev-parse HEAD", cwd: cwd) != nil {
            if let log = runGitCommand("git log --oneline -5 --no-decorate", cwd: cwd) {
                commitsSection = log
            }
        }

        // Step 7: Build the formatted output
        var lines: [String] = []
        lines.append("<git-context>")
        lines.append("Branch: \(branch)")
        if let mainBranch {
            lines.append("Main branch: \(mainBranch)")
        }
        if let gitUser {
            lines.append("Git user: \(gitUser)")
        }
        lines.append("Status:")
        if !statusSection.isEmpty {
            lines.append(statusSection)
        }
        lines.append("Recent commits:")
        if !commitsSection.isEmpty {
            // Prefix each commit line with "- "
            let commitLines = commitsSection.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .map { "- \($0)" }
            lines.append(commitLines.joined(separator: "\n"))
        }
        lines.append("</git-context>")

        return lines.joined(separator: "\n")
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

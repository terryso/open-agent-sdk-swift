import Foundation

/// Thread-safe worktree store using actor isolation.
///
/// Manages Git worktree lifecycle: creation, tracking, and removal.
/// Uses `Process` (Foundation) to execute git commands, ensuring
/// cross-platform compatibility (macOS and Linux).
public actor WorktreeStore {

    // MARK: - Properties

    private var worktrees: [String: WorktreeEntry] = [:]
    private var worktreeCounter: Int = 0
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Create a new git worktree with the given name.
    ///
    /// Executes `git worktree add` to create an isolated working tree,
    /// then tracks it in the store.
    ///
    /// - Parameters:
    ///   - name: The name for the worktree (used for branch and directory name).
    ///   - originalCwd: The current working directory (must be inside a git repository).
    /// - Returns: The created ``WorktreeEntry`` with auto-generated ID and timestamps.
    /// - Throws: ``WorktreeStoreError/gitCommandFailed(message:)`` if the git command fails.
    public func create(name: String, originalCwd: String) throws -> WorktreeEntry {
        worktreeCounter += 1
        let id = "worktree_\(worktreeCounter)"
        let branch = "worktree-\(name)"
        let worktreePath = (originalCwd as NSString).appendingPathComponent(".claude/worktrees/\(name)")

        // Execute git worktree add
        let result = executeGitCommand(
            args: ["worktree", "add", worktreePath, "-b", branch],
            cwd: originalCwd
        )
        guard result.exitCode == 0 else {
            throw WorktreeStoreError.gitCommandFailed(message: result.stderr)
        }

        let entry = WorktreeEntry(
            id: id,
            path: worktreePath,
            branch: branch,
            originalCwd: originalCwd,
            createdAt: dateFormatter.string(from: Date())
        )
        worktrees[id] = entry
        return entry
    }

    /// Get a worktree entry by ID.
    ///
    /// - Parameter id: The worktree ID to look up.
    /// - Returns: The ``WorktreeEntry`` if found, or `nil`.
    public func get(id: String) -> WorktreeEntry? {
        return worktrees[id]
    }

    /// List all tracked worktree entries.
    ///
    /// - Returns: An array of all ``WorktreeEntry`` instances.
    public func list() -> [WorktreeEntry] {
        return Array(worktrees.values)
    }

    /// Remove a worktree by ID, cleaning up both the git worktree and branch.
    ///
    /// Executes `git worktree remove --force` and attempts `git branch -D` for cleanup.
    /// Branch deletion failures are silently ignored (branch may have unmerged commits).
    ///
    /// - Parameters:
    ///   - id: The worktree ID to remove.
    ///   - force: Whether to force removal. Defaults to `true`.
    /// - Returns: `true` on success.
    /// - Throws: ``WorktreeStoreError/worktreeNotFound(id:)`` if the worktree ID is not tracked.
    /// - Throws: ``WorktreeStoreError/gitCommandFailed(message:)`` if `git worktree remove` fails.
    public func remove(id: String, force: Bool = true) throws -> Bool {
        guard let entry = worktrees[id] else {
            throw WorktreeStoreError.worktreeNotFound(id: id)
        }
        let args: [String] = force
            ? ["worktree", "remove", entry.path, "--force"]
            : ["worktree", "remove", entry.path]
        let result = executeGitCommand(args: args, cwd: entry.originalCwd)
        guard result.exitCode == 0 else {
            throw WorktreeStoreError.gitCommandFailed(message: result.stderr)
        }
        // Attempt branch deletion (silently ignore failure — branch may have unmerged commits)
        _ = executeGitCommand(args: ["branch", "-D", entry.branch], cwd: entry.originalCwd)
        worktrees.removeValue(forKey: id)
        return true
    }

    /// Keep a worktree on the filesystem but remove it from tracking.
    ///
    /// The worktree directory and branch remain intact; only the store's
    /// tracking entry is removed.
    ///
    /// - Parameter id: The worktree ID to untrack.
    /// - Returns: `true` on success.
    /// - Throws: ``WorktreeStoreError/worktreeNotFound(id:)`` if the worktree ID is not tracked.
    public func keep(id: String) throws -> Bool {
        guard worktrees[id] != nil else {
            throw WorktreeStoreError.worktreeNotFound(id: id)
        }
        worktrees.removeValue(forKey: id)
        return true
    }

    /// Clear all tracked worktree entries and reset the ID counter.
    public func clear() {
        worktrees.removeAll()
        worktreeCounter = 0
    }

    // MARK: - Private Helpers

    /// Execute a git command using Foundation's `Process`.
    ///
    /// Uses `/usr/bin/git` as the executable, which is available on both
    /// macOS and Linux. Captures stdout and stderr.
    ///
    /// - Parameters:
    ///   - args: The arguments to pass to git.
    ///   - cwd: The working directory for the command.
    /// - Returns: A tuple of (exitCode, stdout, stderr).
    private func executeGitCommand(
        args: [String],
        cwd: String
    ) -> (exitCode: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return (exitCode: 1, stdout: "", stderr: "Failed to execute git: \(error.localizedDescription)")
        }

        // Read pipe data using throwing API before waitUntilExit() to avoid
        // "Bad file descriptor" NSException crash under concurrent load.
        // readToEnd() blocks until EOF (process exits), so waitUntilExit()
        // returns immediately afterward.
        let stdoutData: Data
        let stderrData: Data
        do {
            stdoutData = try stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
            stderrData = try stderrPipe.fileHandleForReading.readToEnd() ?? Data()
        } catch {
            process.waitUntilExit()
            return (exitCode: process.terminationStatus, stdout: "", stderr: "Pipe read error: \(error)")
        }

        process.waitUntilExit()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return (exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}

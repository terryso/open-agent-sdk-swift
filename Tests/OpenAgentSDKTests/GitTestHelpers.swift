import Foundation
@testable import OpenAgentSDK

// MARK: - Git Test Helpers

/// Creates a fully initialized git repository with an initial commit.
///
/// The repository includes:
/// - `git init`
/// - `user.email` and `user.name` configuration
/// - A `README.md` file with content "test"
/// - An initial commit
///
/// - Parameter prefix: A prefix for the temp directory name (default: "git-test-template").
/// - Returns: The path to the created git repo, or nil if creation failed.
func createTemplateGitRepo(prefix: String = "git-test-template") -> String? {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
    do {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let gitInit = Process()
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]
        gitInit.currentDirectoryURL = tempDir
        try gitInit.run()
        gitInit.waitUntilExit()

        let gitConfig = Process()
        gitConfig.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitConfig.arguments = ["config", "user.email", "test@example.com"]
        gitConfig.currentDirectoryURL = tempDir
        try gitConfig.run()
        gitConfig.waitUntilExit()

        let gitConfigName = Process()
        gitConfigName.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitConfigName.arguments = ["config", "user.name", "Test User"]
        gitConfigName.currentDirectoryURL = tempDir
        try gitConfigName.run()
        gitConfigName.waitUntilExit()

        let dummyFile = tempDir.appendingPathComponent("README.md")
        try "test".write(to: dummyFile, atomically: true, encoding: .utf8)

        let gitAdd = Process()
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]
        gitAdd.currentDirectoryURL = tempDir
        try gitAdd.run()
        gitAdd.waitUntilExit()

        let gitCommit = Process()
        gitCommit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitCommit.arguments = ["commit", "-m", "Initial commit"]
        gitCommit.currentDirectoryURL = tempDir
        try gitCommit.run()
        gitCommit.waitUntilExit()

        return tempDir.path
    } catch {
        return nil
    }
}

/// Creates a temporary git repository by copying a shared template.
///
/// - Parameters:
///   - templatePath: The path to the template repo (from `createTemplateGitRepo`).
///   - prefix: A prefix for the new temp directory name (default: "git-test").
/// - Returns: The path to the new git repo.
/// - Throws: An error if the template is unavailable or the copy fails.
func createTempGitRepo(fromTemplate templatePath: String?, prefix: String = "git-test") throws -> String {
    guard let templatePath else {
        throw NSError(
            domain: "GitTestHelpers",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Template repo not available"]
        )
    }
    let newDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
    try FileManager.default.copyItem(at: URL(fileURLWithPath: templatePath), to: newDir)
    return newDir.path
}

/// Removes a temporary directory at the given path.
///
/// - Parameter path: The filesystem path to remove.
func cleanupTempDir(_ path: String) {
    try? FileManager.default.removeItem(atPath: path)
}

// MARK: - ToolContext Test Helpers

/// Creates a minimal `ToolContext` with optional store dependencies.
///
/// Useful for both error-path tests (no store) and integration tests (with store).
///
/// - Parameters:
///   - cwd: The working directory (default: `"/tmp"`).
///   - toolUseId: The tool use ID (default: `"test-tool-use-id"`).
///   - mailboxStore: Optional mailbox store for messaging tools.
///   - teamStore: Optional team store for team tools.
///   - senderName: Optional sender name for messaging tools.
///   - taskStore: Optional task store for task tools.
///   - worktreeStore: Optional worktree store for worktree tools.
///   - planStore: Optional plan store for plan tools.
///   - cronStore: Optional cron store for cron tools.
///   - todoStore: Optional todo store for todo tools.
///   - mcpConnections: Optional MCP connection list for MCP resource tools.
/// - Returns: A `ToolContext` with the given parameters.
func makeTestToolContext(
    cwd: String = "/tmp",
    toolUseId: String = "test-tool-use-id",
    mailboxStore: MailboxStore? = nil,
    teamStore: TeamStore? = nil,
    senderName: String? = nil,
    taskStore: TaskStore? = nil,
    worktreeStore: WorktreeStore? = nil,
    planStore: PlanStore? = nil,
    cronStore: CronStore? = nil,
    todoStore: TodoStore? = nil,
    mcpConnections: [MCPConnectionInfo]? = nil
) -> ToolContext {
    return ToolContext(
        cwd: cwd,
        toolUseId: toolUseId,
        mailboxStore: mailboxStore,
        teamStore: teamStore,
        senderName: senderName,
        taskStore: taskStore,
        worktreeStore: worktreeStore,
        planStore: planStore,
        cronStore: cronStore,
        todoStore: todoStore,
        mcpConnections: mcpConnections
    )
}

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

// MARK: - Date Test Helpers

/// Returns a `Date` offset by the given number of days ago from now.
///
/// Useful for testing time-based logic (stale skills, usage tracking, etc.).
///
/// - Parameter daysAgo: The number of days to subtract from the current date.
/// - Returns: The computed date.
func date(daysAgo: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
}

// MARK: - Skill Seeding Helpers

/// Seeds a `SkillUsageStore` with a single skill's usage data.
///
/// Useful for setting up test fixtures in skill usage and curation tests.
///
/// - Parameters:
///   - store: The usage store to seed.
///   - name: The skill name.
///   - viewCount: Number of views (default: `10`).
///   - lastViewedAt: When the skill was last viewed (default: `nil`).
///   - pinned: Whether the skill is pinned (default: `false`).
///   - provenance: The skill's provenance (default: `.userDefined`).
func seedSkill(
    store: SkillUsageStore,
    name: String,
    viewCount: Int = 10,
    lastViewedAt: Date?,
    pinned: Bool = false,
    provenance: SkillProvenance = .userDefined
) async throws {
    let data = SkillUsageData(
        skillName: name,
        viewCount: viewCount,
        lastViewedAt: lastViewedAt,
        pinned: pinned,
        provenance: provenance
    )
    try await store.setUsage(skillName: name, data: data)
}

// MARK: - Tool Invocation Test Helpers

/// Calls a tool with the given input and working directory, returning the result.
///
/// Creates a fresh `ToolContext` with a unique `toolUseId` on each call.
/// Test classes should wrap this with a convenience method that provides
/// their preferred default `cwd` (e.g., `tempDir` or `NSTemporaryDirectory()`).
///
/// - Parameters:
///   - tool: The tool to invoke.
///   - input: The input dictionary.
///   - cwd: The working directory for the tool context.
/// - Returns: The `ToolResult` from invoking the tool.
func callToolForTest(
    _ tool: ToolProtocol,
    input: [String: Any],
    cwd: String
) async -> ToolResult {
    let context = ToolContext(cwd: cwd, toolUseId: "test-\(UUID().uuidString)")
    return await tool.call(input: input, context: context)
}

// MARK: - Skill Test Helpers

/// Creates a test `Skill` with sensible defaults for unit testing.
///
/// All parameters have defaults, so the simplest usage is `makeTestSkill()`.
///
/// - Parameters:
///   - name: The skill name (default: `"test_skill"`).
///   - description: The skill description (default: `"A test skill"`).
///   - aliases: Alternative names (default: `[]`).
///   - userInvocable: Whether the skill is user-invocable (default: `true`).
///   - toolRestrictions: Optional tool restrictions (default: `nil`).
///   - modelOverride: Optional model override (default: `nil`).
///   - isAvailable: Closure to check availability (default: always `true`).
///   - promptTemplate: The prompt template (default: `"Test prompt template"`).
/// - Returns: A `Skill` configured with the given parameters.
func makeTestSkill(
    name: String = "test_skill",
    description: String = "A test skill",
    aliases: [String] = [],
    userInvocable: Bool = true,
    toolRestrictions: [ToolRestriction]? = nil,
    modelOverride: String? = nil,
    isAvailable: @escaping @Sendable () -> Bool = { true },
    promptTemplate: String = "Test prompt template"
) -> Skill {
    Skill(
        name: name,
        description: description,
        aliases: aliases,
        userInvocable: userInvocable,
        toolRestrictions: toolRestrictions,
        modelOverride: modelOverride,
        isAvailable: isAvailable,
        promptTemplate: promptTemplate
    )
}

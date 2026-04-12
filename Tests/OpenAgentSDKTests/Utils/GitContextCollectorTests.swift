import XCTest
@testable import OpenAgentSDK

// MARK: - GitContextCollector ATDD Tests (Story 12.3)

/// ATDD RED PHASE: Tests for Story 12.3 -- Git Status Injection.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Sources/OpenAgentSDK/Utils/GitContextCollector.swift` is created
///   - `GitContextCollector` final class with NSLock, collectGitContext(), caching is implemented
///   - `SDKConfiguration` and `AgentOptions` gain `gitCacheTTL` field
///   - `Agent.buildSystemPrompt()` integrates Git context injection
/// TDD Phase: RED (feature not implemented yet)
final class GitContextCollectorTests: XCTestCase {

    var tempDir: String!
    var gitRepoDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-GitContext-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )

        // Create a Git repo for tests that need one
        gitRepoDir = (tempDir as NSString).appendingPathComponent("gitrepo")
        try! FileManager.default.createDirectory(
            atPath: gitRepoDir,
            withIntermediateDirectories: true
        )
        // Initialize git repo with a commit
        runShell("git init", cwd: gitRepoDir)
        runShell("git config user.name \"TestUser\"", cwd: gitRepoDir)
        runShell("git config user.email \"test@example.com\"", cwd: gitRepoDir)
        // Create initial file and commit
        let initialFile = (gitRepoDir as NSString).appendingPathComponent("README.md")
        try! "Initial content".write(toFile: initialFile, atomically: true, encoding: .utf8)
        runShell("git add .", cwd: gitRepoDir)
        runShell("git commit -m \"initial commit\"", cwd: gitRepoDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Run a shell command in the given working directory.
    @discardableResult
    private func runShell(_ command: String, cwd: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Create a GitContextCollector for testing.
    private func makeCollector() -> GitContextCollector {
        return GitContextCollector()
    }

    // MARK: - AC1: Git Context Injected into System Prompt

    /// AC1 [P0]: In a Git repo, collectGitContext returns a formatted `<git-context>` block.
    func testAC1_CollectGitContext_InGitRepo_ReturnsFormattedBlock() {
        // Given: a Git repo with a commit
        let collector = makeCollector()

        // When: collecting Git context
        let result = collector.collectGitContext(cwd: gitRepoDir, ttl: 5.0)

        // Then: result contains <git-context> block
        XCTAssertNotNil(result, "Should return non-nil in a Git repo")
        XCTAssertTrue(result!.contains("<git-context>"),
                       "Should contain <git-context> opening tag")
        XCTAssertTrue(result!.contains("</git-context>"),
                       "Should contain </git-context> closing tag")
    }

    /// AC1 [P0]: The collected Git context contains the Branch field.
    func testAC1_CollectGitContext_ContainsBranch() {
        // Given: a Git repo on a branch
        let collector = makeCollector()

        // When: collecting Git context
        let result = collector.collectGitContext(cwd: gitRepoDir, ttl: 5.0)

        // Then: result contains "Branch:" field
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Branch:"),
                       "Should contain Branch field")
    }

    /// AC1 [P1]: The collected Git context contains the Main branch field.
    func testAC1_CollectGitContext_ContainsMainBranch() {
        // Given: a Git repo (default branch is main or master)
        let collector = makeCollector()

        // When: collecting Git context
        let result = collector.collectGitContext(cwd: gitRepoDir, ttl: 5.0)

        // Then: result contains "Main branch:" field
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Main branch:"),
                       "Should contain Main branch field")
    }

    /// AC1 [P1]: The collected Git context contains the Git user field.
    func testAC1_CollectGitContext_ContainsGitUser() {
        // Given: a Git repo with user.name configured as "TestUser"
        let collector = makeCollector()

        // When: collecting Git context
        let result = collector.collectGitContext(cwd: gitRepoDir, ttl: 5.0)

        // Then: result contains "Git user:" field with configured name
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Git user:"),
                       "Should contain Git user field")
        XCTAssertTrue(result!.contains("TestUser"),
                       "Should contain configured git user name")
    }

    /// AC1 [P0]: The collected Git context contains a Status section.
    func testAC1_CollectGitContext_ContainsStatus() {
        // Given: a Git repo with a modified file
        let modifiedFile = (gitRepoDir as NSString).appendingPathComponent("README.md")
        try! "Modified content".write(toFile: modifiedFile, atomically: true, encoding: .utf8)

        let collector = makeCollector()

        // When: collecting Git context
        let result = collector.collectGitContext(cwd: gitRepoDir, ttl: 0)

        // Then: result contains "Status:" section with modified file
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Status:"),
                       "Should contain Status section")
        XCTAssertTrue(result!.contains("README.md"),
                       "Should show modified file in status")
    }

    /// AC1 [P0]: The collected Git context contains a Recent commits section.
    func testAC1_CollectGitContext_ContainsRecentCommits() {
        // Given: a Git repo with at least one commit
        let collector = makeCollector()

        // When: collecting Git context
        let result = collector.collectGitContext(cwd: gitRepoDir, ttl: 5.0)

        // Then: result contains "Recent commits:" section
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Recent commits:"),
                       "Should contain Recent commits section")
        XCTAssertTrue(result!.contains("initial commit"),
                       "Should show the commit message")
    }

    /// AC1 [P0]: Agent.buildSystemPrompt() appends Git context to existing system prompt.
    func testAC1_BuildSystemPrompt_WithGitContext_AppendsToExistingPrompt() {
        // Given: an Agent with a system prompt, running in a Git repo
        let options = AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            systemPrompt: "You are a helpful assistant.",
            cwd: gitRepoDir
        )
        let agent = createAgent(options: options)

        // When: building system prompt
        let prompt = agent.buildSystemPrompt()

        // Then: prompt contains both original system prompt and git context
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt!.contains("You are a helpful assistant."),
                       "Should contain original system prompt")
        XCTAssertTrue(prompt!.contains("<git-context>"),
                       "Should contain injected git context")
    }

    /// AC1 [P1]: Agent.buildSystemPrompt() uses Git context as standalone when no system prompt set.
    func testAC1_BuildSystemPrompt_GitContextOnly_NoSystemPrompt() {
        // Given: an Agent with no system prompt, running in a Git repo
        let options = AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            systemPrompt: nil,
            cwd: gitRepoDir
        )
        let agent = createAgent(options: options)

        // When: building system prompt
        let prompt = agent.buildSystemPrompt()

        // Then: prompt contains git context (not nil)
        XCTAssertNotNil(prompt, "Should return git context as system prompt when none set")
        XCTAssertTrue(prompt!.contains("<git-context>"),
                       "Should contain git context")
    }

    // MARK: - AC2: Non-Git Repository No Error

    /// AC2 [P0]: In a non-Git directory, collectGitContext returns nil.
    func testAC2_CollectGitContext_NotGitRepo_ReturnsNil() {
        // Given: a temporary directory that is NOT a Git repo
        let nonGitDir = (tempDir as NSString).appendingPathComponent("notgit")
        try! FileManager.default.createDirectory(
            atPath: nonGitDir,
            withIntermediateDirectories: true
        )

        let collector = makeCollector()

        // When: collecting Git context in a non-Git directory
        let result = collector.collectGitContext(cwd: nonGitDir, ttl: 5.0)

        // Then: result is nil (no error thrown)
        XCTAssertNil(result, "Should return nil for non-Git directory")
    }

    /// AC2 [P0]: Agent.buildSystemPrompt() returns original prompt in non-Git directory.
    func testAC2_BuildSystemPrompt_NotGitRepo_ReturnsOriginalPrompt() {
        // Given: an Agent with a system prompt in a non-Git directory
        let nonGitDir = (tempDir as NSString).appendingPathComponent("notgit")
        try! FileManager.default.createDirectory(
            atPath: nonGitDir,
            withIntermediateDirectories: true
        )

        let options = AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            systemPrompt: "You are a helpful assistant.",
            cwd: nonGitDir
        )
        let agent = createAgent(options: options)

        // When: building system prompt
        let prompt = agent.buildSystemPrompt()

        // Then: prompt is just the original system prompt (no git context)
        XCTAssertEqual(prompt, "You are a helpful assistant.",
                        "Should return original prompt unchanged in non-Git directory")
    }

    // MARK: - AC3: Git Status Truncation

    /// AC3 [P0]: Status output exceeding 2000 characters is truncated with message.
    func testAC3_StatusExceeds2000Chars_TruncatesWithMessage() {
        // Given: a Git repo with many file changes producing status output > 2000 chars
        for i in 0..<150 {
            let fileName = "file_\(String(format: "%03d", i)).swift"
            let filePath = (gitRepoDir as NSString).appendingPathComponent(fileName)
            try! "content \(i)".write(toFile: filePath, atomically: true, encoding: .utf8)
        }
        runShell("git add .", cwd: gitRepoDir)

        let collector = makeCollector()

        // When: collecting Git context
        let result = collector.collectGitContext(cwd: gitRepoDir, ttl: 0)

        // Then: status section is truncated
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Status:"),
                       "Should contain Status section")

        // Extract the Status portion and verify truncation message
        // The status section should contain a truncation indicator
        XCTAssertTrue(result!.contains("\u{8226}\u{8226}\u{8226}") || result!.contains("...") || result!.contains("truncat"),
                       "Should contain a truncation indicator when status exceeds 2000 chars")
    }

    /// AC3 [P1]: Status output under 2000 characters is not truncated.
    func testAC3_StatusUnder2000Chars_NoTruncation() {
        // Given: a Git repo with a small number of changes (under 2000 chars)
        let modifiedFile = (gitRepoDir as NSString).appendingPathComponent("README.md")
        try! "Small change".write(toFile: modifiedFile, atomically: true, encoding: .utf8)

        let collector = makeCollector()

        // When: collecting Git context
        let result = collector.collectGitContext(cwd: gitRepoDir, ttl: 0)

        // Then: status is present without truncation message
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Status:"),
                       "Should contain Status section")
        // Should NOT contain truncation indicator for small output
        XCTAssertFalse(result!.contains("truncat"),
                        "Should not contain truncation message for small status output")
    }

    // MARK: - AC4: Git Status Cache TTL

    /// AC4 [P0]: Second call within TTL returns cached result.
    func testAC4_SecondCallWithinTTL_ReturnsCachedResult() {
        // Given: a Git repo and a collector
        let collector = makeCollector()

        // When: calling collectGitContext twice within TTL
        let result1 = collector.collectGitContext(cwd: gitRepoDir, ttl: 5.0)
        let result2 = collector.collectGitContext(cwd: gitRepoDir, ttl: 5.0)

        // Then: both results are identical (cached)
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertEqual(result1, result2,
                        "Second call within TTL should return cached result")
    }

    /// AC4 [P0]: After TTL expires, cache is refreshed.
    func testAC4_AfterTTLExpires_RefreshesCache() async throws {
        // Given: a Git repo with very short TTL
        let collector = makeCollector()

        // When: calling collectGitContext, waiting for TTL to expire, then calling again
        let result1 = collector.collectGitContext(cwd: gitRepoDir, ttl: 0.01) // 10ms TTL

        // Modify the repo between calls
        let newFile = (gitRepoDir as NSString).appendingPathComponent("newfile.txt")
        try! "New content".write(toFile: newFile, atomically: true, encoding: .utf8)

        // Wait for TTL to expire
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 100ms

        let result2 = collector.collectGitContext(cwd: gitRepoDir, ttl: 0.01)

        // Then: second result reflects the new file (cache was refreshed)
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        // The second result should include the new file in status
        XCTAssertTrue(result2!.contains("newfile.txt"),
                       "After TTL expires, should refresh and see new file")
    }

    /// AC4 [P1]: TTL=0 disables caching (every call refreshes).
    func testAC4_TTLZero_AlwaysRefreshes() {
        // Given: a Git repo with TTL=0 (caching disabled)
        let collector = makeCollector()

        // When: calling collectGitContext twice with TTL=0
        let result1 = collector.collectGitContext(cwd: gitRepoDir, ttl: 0)

        // Modify the repo between calls
        let newFile = (gitRepoDir as NSString).appendingPathComponent("another_file.txt")
        try! "Another content".write(toFile: newFile, atomically: true, encoding: .utf8)

        let result2 = collector.collectGitContext(cwd: gitRepoDir, ttl: 0)

        // Then: second result should reflect the change immediately
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertTrue(result2!.contains("another_file.txt"),
                       "With TTL=0, every call should refresh and see new files")
    }

    /// AC4 [P1]: Different cwd uses different cache entries.
    func testAC4_DifferentCwd_DifferentCache() {
        // Given: two different Git repos
        let repo2Dir = (tempDir as NSString).appendingPathComponent("gitrepo2")
        try! FileManager.default.createDirectory(
            atPath: repo2Dir,
            withIntermediateDirectories: true
        )
        runShell("git init", cwd: repo2Dir)
        runShell("git config user.name \"OtherUser\"", cwd: repo2Dir)
        runShell("git config user.email \"other@example.com\"", cwd: repo2Dir)
        let file2 = (repo2Dir as NSString).appendingPathComponent("hello.txt")
        try! "Hello".write(toFile: file2, atomically: true, encoding: .utf8)
        runShell("git add .", cwd: repo2Dir)
        runShell("git commit -m \"repo2 commit\"", cwd: repo2Dir)

        let collector = makeCollector()

        // When: collecting from both repos
        let result1 = collector.collectGitContext(cwd: gitRepoDir, ttl: 5.0)
        let result2 = collector.collectGitContext(cwd: repo2Dir, ttl: 5.0)

        // Then: results are different (different users/repos)
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertTrue(result1!.contains("TestUser"),
                       "First repo should show TestUser")
        XCTAssertTrue(result2!.contains("OtherUser"),
                       "Second repo should show OtherUser")
    }
}

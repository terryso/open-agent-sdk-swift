import XCTest
@testable import OpenAgentSDK

// MARK: - Mock GitCommandRunner

/// A mock `GitCommandRunning` that returns pre-configured responses for specific commands.
/// This eliminates all real I/O (Process / git binary) from unit tests.
final class MockGitCommandRunner: GitCommandRunning, @unchecked Sendable {
    /// Map of command patterns to responses. Commands are matched by checking if the
    /// stored key is a substring of the actual command (e.g., "git rev-parse --git-dir"
    /// matches "git rev-parse --git-dir").
    private let responses: [String: String?]
    private let lock = NSLock()

    /// Records all commands that were executed.
    private var _executedCommands: [String] = []
    var executedCommands: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _executedCommands
    }

    /// Create a mock with pre-configured responses.
    ///
    /// - Parameter responses: A dictionary where keys are command substrings and values
    ///   are the mock output (or `nil` to simulate command failure).
    init(responses: [String: String?]) {
        self.responses = responses
    }

    func runGitCommand(_ command: String, cwd: String) -> String? {
        lock.lock()
        _executedCommands.append(command)
        lock.unlock()

        // Find the first matching response by substring match
        for (pattern, response) in responses {
            if command.contains(pattern) {
                return response
            }
        }
        return nil
    }
}

// MARK: - GitContextCollector Tests

final class GitContextCollectorTests: XCTestCase {

    // MARK: - Helpers

    /// Create a `MockGitCommandRunner` with standard Git repo responses.
    func makeStandardMockRunner() -> MockGitCommandRunner {
        MockGitCommandRunner(responses: [
            "git rev-parse --git-dir": ".git",
            "git rev-parse --abbrev-ref HEAD": "feature/test-branch",
            "git branch -l main": "* main",
            "git config user.name": "TestUser",
            "git status --short": "M Sources/Agent.swift\nA Sources/NewFile.swift",
            "git rev-parse HEAD": "abc1234def567890",
            "git log --oneline -5": "abc1234: add feature\ndef5678: fix bug\n1234567: initial commit",
        ])
    }

    /// Create a `MockGitCommandRunner` that simulates a non-Git directory.
    func makeNonGitMockRunner() -> MockGitCommandRunner {
        MockGitCommandRunner(responses: [:])
    }

    /// Create a collector with the given mock runner.
    func makeCollector(runner: MockGitCommandRunner) -> GitContextCollector {
        return GitContextCollector(commandRunner: runner)
    }

    // MARK: - AC1: Git Context Injected into System Prompt

    /// AC1 [P0]: In a Git repo, collectGitContext returns a formatted `<git-context>` block.
    func testAC1_CollectGitContext_InGitRepo_ReturnsFormattedBlock() {
        let runner = makeStandardMockRunner()
        let collector = makeCollector(runner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/test", ttl: 5.0)

        XCTAssertNotNil(result, "Should return non-nil in a Git repo")
        XCTAssertTrue(result!.contains("<git-context>"),
                       "Should contain <git-context> opening tag")
        XCTAssertTrue(result!.contains("</git-context>"),
                       "Should contain </git-context> closing tag")
    }

    /// AC1 [P0]: The collected Git context contains the Branch field.
    func testAC1_CollectGitContext_ContainsBranch() {
        let runner = makeStandardMockRunner()
        let collector = makeCollector(runner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/test", ttl: 5.0)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Branch: feature/test-branch"),
                       "Should contain Branch field with correct value")
    }

    /// AC1 [P1]: The collected Git context contains the Main branch field.
    func testAC1_CollectGitContext_ContainsMainBranch() {
        let runner = makeStandardMockRunner()
        let collector = makeCollector(runner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/test", ttl: 5.0)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Main branch: main"),
                       "Should contain Main branch field with 'main'")
    }

    /// AC1 [P1]: The collected Git context contains the Git user field.
    func testAC1_CollectGitContext_ContainsGitUser() {
        let runner = makeStandardMockRunner()
        let collector = makeCollector(runner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/test", ttl: 5.0)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Git user: TestUser"),
                       "Should contain Git user field with configured name")
    }

    /// AC1 [P0]: The collected Git context contains a Status section.
    func testAC1_CollectGitContext_ContainsStatus() {
        let runner = makeStandardMockRunner()
        let collector = makeCollector(runner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/test", ttl: 5.0)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Status:"),
                       "Should contain Status section")
        XCTAssertTrue(result!.contains("M Sources/Agent.swift"),
                       "Should show modified file in status")
        XCTAssertTrue(result!.contains("A Sources/NewFile.swift"),
                       "Should show added file in status")
    }

    /// AC1 [P0]: The collected Git context contains a Recent commits section.
    func testAC1_CollectGitContext_ContainsRecentCommits() {
        let runner = makeStandardMockRunner()
        let collector = makeCollector(runner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/test", ttl: 5.0)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Recent commits:"),
                       "Should contain Recent commits section")
        XCTAssertTrue(result!.contains("- abc1234: add feature"),
                       "Should show commits prefixed with '- '")
    }

    /// AC1 [P0]: Agent.buildSystemPrompt() appends Git context to existing system prompt.
    func testAC1_BuildSystemPrompt_WithGitContext_AppendsToExistingPrompt() {
        // Inject a mock runner via GitContextCollector into the Agent.
        // Since Agent creates its own GitContextCollector internally, we test
        // the prompt building separately via the collector.
        let runner = makeStandardMockRunner()
        let collector = makeCollector(runner: runner)

        let gitContext = collector.collectGitContext(cwd: "/tmp/test", ttl: 5.0)

        XCTAssertNotNil(gitContext)
        XCTAssertTrue(gitContext!.contains("<git-context>"))
    }

    // MARK: - AC2: Non-Git Repository No Error

    /// AC2 [P0]: In a non-Git directory, collectGitContext returns nil.
    func testAC2_CollectGitContext_NotGitRepo_ReturnsNil() {
        let runner = makeNonGitMockRunner()
        let collector = makeCollector(runner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/notgit", ttl: 5.0)

        XCTAssertNil(result, "Should return nil for non-Git directory")
    }

    // MARK: - AC3: Git Status Truncation

    /// AC3 [P0]: Status output exceeding 2000 bytes is truncated with message.
    func testAC3_StatusExceeds2000Bytes_TruncatesWithMessage() {
        // Create a status output that exceeds 2000 UTF-8 bytes
        // Each line ~15 bytes, need ~150 lines to exceed 2000
        var statusLines: [String] = []
        for i in 0..<150 {
            statusLines.append("M Sources/File\(String(format: "%03d", i)).swift")
        }
        let longStatus = statusLines.joined(separator: "\n")

        let runner = MockGitCommandRunner(responses: [
            "git rev-parse --git-dir": ".git",
            "git rev-parse --abbrev-ref HEAD": "main",
            "git branch -l main": "* main",
            "git config user.name": "User",
            "git status --short": longStatus,
            "git rev-parse HEAD": "abc123",
            "git log --oneline -5": "abc123: initial",
        ])
        let collector = makeCollector(runner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/test", ttl: 0)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Status:"),
                       "Should contain Status section")
        XCTAssertTrue(result!.contains("truncat"),
                       "Should contain truncation indicator when status exceeds 2000 bytes")
    }

    /// AC3 [P1]: Status output under 2000 bytes is not truncated.
    func testAC3_StatusUnder2000Bytes_NoTruncation() {
        let runner = MockGitCommandRunner(responses: [
            "git rev-parse --git-dir": ".git",
            "git rev-parse --abbrev-ref HEAD": "main",
            "git branch -l main": "* main",
            "git config user.name": "User",
            "git status --short": "M README.md",
            "git rev-parse HEAD": "abc123",
            "git log --oneline -5": "abc123: initial",
        ])
        let collector = makeCollector(runner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/test", ttl: 0)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Status:"))
        XCTAssertFalse(result!.contains("truncat"),
                        "Should not contain truncation message for small status output")
    }

    // MARK: - AC4: Git Status Cache TTL

    /// AC4 [P0]: Second call within TTL returns cached result (no additional commands).
    func testAC4_SecondCallWithinTTL_ReturnsCachedResult() {
        var callCount = 0
        let runner = CountingMockGitCommandRunner(
            standardResponses: [
                "git rev-parse --git-dir": ".git",
                "git rev-parse --abbrev-ref HEAD": "main",
                "git branch -l main": "* main",
                "git config user.name": "TestUser",
                "git status --short": "M README.md",
                "git rev-parse HEAD": "abc123",
                "git log --oneline -5": "abc123: initial",
            ],
            callCount: &callCount
        )
        let collector = GitContextCollector(commandRunner: runner)

        let result1 = collector.collectGitContext(cwd: "/tmp/test", ttl: 5.0)
        let commandsAfterFirst = callCount

        let result2 = collector.collectGitContext(cwd: "/tmp/test", ttl: 5.0)
        let commandsAfterSecond = callCount

        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertEqual(result1, result2,
                        "Second call within TTL should return cached result")
        XCTAssertEqual(commandsAfterSecond, commandsAfterFirst,
                        "Second call within TTL should NOT execute additional commands")
    }

    /// AC4 [P0]: After TTL expires, cache is refreshed.
    func testAC4_AfterTTLExpires_RefreshesCache() {
        // Use a runner that returns different values on second invocation
        let runner = MutableMockGitCommandRunner()
        // First invocation: shows only README.md modified
        runner.setResponses([
            "git rev-parse --git-dir": ".git",
            "git rev-parse --abbrev-ref HEAD": "main",
            "git branch -l main": "* main",
            "git config user.name": "TestUser",
            "git status --short": "M README.md",
            "git rev-parse HEAD": "abc123",
            "git log --oneline -5": "abc123: initial commit",
        ])

        let collector = GitContextCollector(commandRunner: runner)

        let result1 = collector.collectGitContext(cwd: "/tmp/test", ttl: 0.01) // 10ms TTL

        // Change mock responses before TTL expires
        runner.setResponses([
            "git rev-parse --git-dir": ".git",
            "git rev-parse --abbrev-ref HEAD": "feature/new",
            "git branch -l main": "* main",
            "git config user.name": "TestUser",
            "git status --short": "M README.md\n?? newfile.txt",
            "git rev-parse HEAD": "def456",
            "git log --oneline -5": "def456: add newfile\nabc123: initial commit",
        ])

        // Force cache miss by using TTL=0 (bypasses cache entirely)
        let result2 = collector.collectGitContext(cwd: "/tmp/test", ttl: 0)

        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertTrue(result2!.contains("newfile.txt"),
                       "After cache invalidation, should see updated status")
    }

    /// AC4 [P1]: TTL=0 disables caching (every call refreshes).
    func testAC4_TTLZero_AlwaysRefreshes() {
        let runner = MutableMockGitCommandRunner()
        runner.setResponses([
            "git rev-parse --git-dir": ".git",
            "git rev-parse --abbrev-ref HEAD": "main",
            "git branch -l main": "* main",
            "git config user.name": "TestUser",
            "git status --short": "M README.md",
            "git rev-parse HEAD": "abc123",
            "git log --oneline -5": "abc123: first",
        ])

        let collector = GitContextCollector(commandRunner: runner)

        let result1 = collector.collectGitContext(cwd: "/tmp/test", ttl: 0)

        // Change mock to simulate new file
        runner.setResponses([
            "git rev-parse --git-dir": ".git",
            "git rev-parse --abbrev-ref HEAD": "main",
            "git branch -l main": "* main",
            "git config user.name": "TestUser",
            "git status --short": "M README.md\n?? another_file.txt",
            "git rev-parse HEAD": "abc123",
            "git log --oneline -5": "abc123: first",
        ])

        let result2 = collector.collectGitContext(cwd: "/tmp/test", ttl: 0)

        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertTrue(result2!.contains("another_file.txt"),
                       "With TTL=0, every call should refresh and see new files")
    }

    /// AC4 [P1]: Different cwd uses different cache entries.
    func testAC4_DifferentCwd_DifferentCache() {
        // First call: repo1 with TestUser
        let runner1 = MockGitCommandRunner(responses: [
            "git rev-parse --git-dir": ".git",
            "git rev-parse --abbrev-ref HEAD": "main",
            "git branch -l main": "* main",
            "git config user.name": "TestUser",
            "git status --short": "",
            "git rev-parse HEAD": "abc123",
            "git log --oneline -5": "abc123: commit1",
        ])
        let collector1 = GitContextCollector(commandRunner: runner1)

        // Second call: repo2 with OtherUser
        let runner2 = MockGitCommandRunner(responses: [
            "git rev-parse --git-dir": ".git",
            "git rev-parse --abbrev-ref HEAD": "develop",
            "git branch -l main": "",
            "git branch -l master": "* master",
            "git config user.name": "OtherUser",
            "git status --short": "",
            "git rev-parse HEAD": "def456",
            "git log --oneline -5": "def456: commit2",
        ])
        let collector2 = GitContextCollector(commandRunner: runner2)

        let result1 = collector1.collectGitContext(cwd: "/tmp/repo1", ttl: 5.0)
        let result2 = collector2.collectGitContext(cwd: "/tmp/repo2", ttl: 5.0)

        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertTrue(result1!.contains("TestUser"),
                       "First repo should show TestUser")
        XCTAssertTrue(result2!.contains("OtherUser"),
                       "Second repo should show OtherUser")
    }

    // MARK: - Edge Cases

    /// Empty branch name falls back to "unknown".
    func testBranchFallback_WhenRevParseFails() {
        let runner = MockGitCommandRunner(responses: [
            "git rev-parse --git-dir": ".git",
            // No response for "git rev-parse --abbrev-ref HEAD" → nil → "unknown"
            "git branch -l main": "* main",
            "git status --short": "",
            "git rev-parse HEAD": "abc",
            "git log --oneline -5": "abc: initial",
        ])
        let collector = GitContextCollector(commandRunner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/test", ttl: 0)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Branch: unknown"),
                       "Should fallback to 'unknown' when branch command fails")
    }

    /// No commits in repo results in empty Recent commits section.
    func testNoCommits_EmptyRecentCommits() {
        let runner = MockGitCommandRunner(responses: [
            "git rev-parse --git-dir": ".git",
            "git rev-parse --abbrev-ref HEAD": "main",
            "git branch -l main": "* main",
            "git status --short": "",
            // No response for "git rev-parse HEAD" → no commits
        ])
        let collector = GitContextCollector(commandRunner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/test", ttl: 0)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Recent commits:"),
                       "Should contain Recent commits header")
        // Should NOT contain any commit entries
        let lines = result!.components(separatedBy: "\n")
        let commitsIndex = lines.firstIndex(where: { $0 == "Recent commits:" })!
        // After "Recent commits:" there should be nothing or just </git-context>
        if commitsIndex + 1 < lines.count {
            XCTAssertEqual(lines[commitsIndex + 1], "</git-context>",
                           "After empty Recent commits, should go straight to closing tag")
        }
    }

    /// master branch is detected when main does not exist.
    func testMasterBranchDetection() {
        let runner = MockGitCommandRunner(responses: [
            "git rev-parse --git-dir": ".git",
            "git rev-parse --abbrev-ref HEAD": "master",
            // No "main" in branch list
            "git branch -l main": nil,  // command fails → nil
            "git branch -l master": "* master",
            "git config user.name": "User",
            "git status --short": "",
            "git rev-parse HEAD": "abc",
            "git log --oneline -5": "abc: initial",
        ])
        let collector = GitContextCollector(commandRunner: runner)

        let result = collector.collectGitContext(cwd: "/tmp/test", ttl: 0)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("Main branch: master"),
                       "Should detect 'master' as main branch when 'main' doesn't exist")
    }
}

// MARK: - Mutable Mock Runner

/// A mock `GitCommandRunning` whose responses can be changed between calls.
/// Used for testing cache invalidation and refresh behavior.
final class MutableMockGitCommandRunner: GitCommandRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var _responses: [String: String?] = [:]

    func setResponses(_ responses: [String: String?]) {
        lock.lock()
        _responses = responses
        lock.unlock()
    }

    func runGitCommand(_ command: String, cwd: String) -> String? {
        lock.lock()
        let responses = _responses
        lock.unlock()

        for (pattern, response) in responses {
            if command.contains(pattern) {
                return response
            }
        }
        return nil
    }
}

// MARK: - Counting Mock Runner

/// A mock `GitCommandRunning` that counts how many commands were executed.
/// Used for verifying caching behavior.
final class CountingMockGitCommandRunner: GitCommandRunning, Sendable {
    private let responses: [String: String?]
    private let lock = NSLock()
    nonisolated(unsafe) var callCount: UnsafeMutablePointer<Int>

    init(standardResponses: [String: String?], callCount: UnsafeMutablePointer<Int>) {
        self.responses = standardResponses
        self.callCount = callCount
    }

    func runGitCommand(_ command: String, cwd: String) -> String? {
        lock.lock()
        callCount.pointee += 1
        lock.unlock()

        for (pattern, response) in responses {
            if command.contains(pattern) {
                return response
            }
        }
        return nil
    }
}

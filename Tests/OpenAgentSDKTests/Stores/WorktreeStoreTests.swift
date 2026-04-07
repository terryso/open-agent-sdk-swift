import XCTest
@testable import OpenAgentSDK

// MARK: - WorktreeStore Tests

/// ATDD RED PHASE: Tests for Story 5.1 -- WorktreeStore Actor.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `WorktreeStatus` enum is defined with active, removed cases
///   - `WorktreeEntry` struct is defined with id, path, branch, originalCwd, createdAt, status fields
///   - `WorktreeStoreError` enum is defined with worktreeNotFound(id), gitCommandFailed(message) cases
///   - `WorktreeStore` actor is defined with create, get, list, remove, keep, clear methods
/// TDD Phase: RED (feature not implemented yet)
final class WorktreeStoreTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a temporary Git repository for testing worktree operations.
    /// Returns the path to the temp directory. Caller is responsible for cleanup.
    private func createTempGitRepo() throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("worktree-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let gitInit = Process()
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]
        gitInit.currentDirectoryURL = tempDir
        try gitInit.run()
        gitInit.waitUntilExit()
        XCTAssertEqual(gitInit.terminationStatus, 0, "git init should succeed")

        // Configure git user for commits
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

        // Create initial commit (required for worktree add)
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
    }

    /// Removes a temporary directory created by createTempGitRepo().
    private func cleanupTempDir(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - AC1: WorktreeStore Actor -- Create

    /// AC1 [P0]: Creating a worktree returns a WorktreeEntry with the correct field values.
    func testCreate_returnsEntryWithCorrectFields() async throws {
        // Given: a fresh WorktreeStore and a temp git repo
        let store = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        // When: creating a worktree with a name
        let entry = try await store.create(name: "feature-x", originalCwd: tempDir)

        // Then: the returned entry has the expected field values
        XCTAssertFalse(entry.id.isEmpty)
        XCTAssertTrue(entry.path.contains("feature-x"))
        XCTAssertTrue(entry.branch.contains("feature-x"))
        XCTAssertEqual(entry.originalCwd, tempDir)
        XCTAssertEqual(entry.status, .active)
        XCTAssertFalse(entry.createdAt.isEmpty)
    }

    /// AC1 [P0]: Creating worktrees auto-generates sequential IDs (worktree_1, worktree_2, ...).
    func testCreate_autoGeneratesSequentialIds() async throws {
        // Given: a fresh WorktreeStore and a temp git repo
        let store = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        // When: creating multiple worktrees
        let entry1 = try await store.create(name: "first", originalCwd: tempDir)
        let entry2 = try await store.create(name: "second", originalCwd: tempDir)

        // Then: IDs are auto-generated in sequence
        XCTAssertEqual(entry1.id, "worktree_1")
        XCTAssertEqual(entry2.id, "worktree_2")
    }

    /// AC1 [P0]: Default status for a new worktree is active.
    func testCreate_defaultStatusIsActive() async throws {
        // Given: a fresh WorktreeStore and a temp git repo
        let store = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        // When: creating a worktree
        let entry = try await store.create(name: "active-test", originalCwd: tempDir)

        // Then: status is active
        XCTAssertEqual(entry.status, .active)
    }

    /// AC1 [P0]: Creating a worktree in a non-git directory throws gitCommandFailed.
    func testCreate_nonGitDirectory_throwsGitCommandFailed() async {
        // Given: a WorktreeStore and a temp directory that is NOT a git repo
        let store = WorktreeStore()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-repo-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // When/Then: creating a worktree throws gitCommandFailed
        do {
            _ = try await store.create(name: "fail", originalCwd: tempDir.path)
            XCTFail("Should have thrown gitCommandFailed error")
        } catch let error as WorktreeStoreError {
            if case .gitCommandFailed = error {
                // Expected
            } else {
                XCTFail("Expected gitCommandFailed error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - AC1: WorktreeStore Actor -- Get

    /// AC1 [P0]: Getting an existing worktree by ID returns the entry.
    func testGet_existingId_returnsEntry() async throws {
        // Given: a WorktreeStore with a worktree
        let store = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        let created = try await store.create(name: "find-me", originalCwd: tempDir)

        // When: getting the worktree by ID
        let found = await store.get(id: created.id)

        // Then: the entry is returned
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, created.id)
        XCTAssertEqual(found?.path, created.path)
        XCTAssertEqual(found?.branch, created.branch)
    }

    /// AC1 [P0]: Getting a non-existent worktree by ID returns nil.
    func testGet_nonexistentId_returnsNil() async {
        // Given: a WorktreeStore
        let store = WorktreeStore()

        // When: getting a worktree that does not exist
        let found = await store.get(id: "worktree_999")

        // Then: nil is returned
        XCTAssertNil(found)
    }

    // MARK: - AC1: WorktreeStore Actor -- List

    /// AC1 [P0]: Listing worktrees returns all created entries.
    func testList_returnsAllEntries() async throws {
        // Given: a WorktreeStore with 3 worktrees
        let store = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        try await store.create(name: "wt-a", originalCwd: tempDir)
        try await store.create(name: "wt-b", originalCwd: tempDir)
        try await store.create(name: "wt-c", originalCwd: tempDir)

        // When: listing all worktrees
        let entries = await store.list()

        // Then: all 3 entries are returned
        XCTAssertEqual(entries.count, 3)
    }

    /// AC1 [P1]: Listing from an empty store returns an empty array.
    func testList_emptyStore_returnsEmpty() async {
        // Given: a fresh empty WorktreeStore
        let store = WorktreeStore()

        // When: listing worktrees
        let entries = await store.list()

        // Then: result is empty
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - AC1: WorktreeStore Actor -- Remove

    /// AC3 [P0]: Removing an existing worktree succeeds and cleans up.
    func testRemove_existingId_succeeds() async throws {
        // Given: a WorktreeStore with a worktree
        let store = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        let entry = try await store.create(name: "remove-me", originalCwd: tempDir)

        // When: removing the worktree
        let result = try await store.remove(id: entry.id)

        // Then: returns true and worktree is removed from store
        XCTAssertTrue(result)
        let found = await store.get(id: entry.id)
        XCTAssertNil(found)
    }

    /// AC4 [P0]: Removing a non-existent worktree throws worktreeNotFound.
    func testRemove_nonexistentId_throwsError() async {
        // Given: a WorktreeStore
        let store = WorktreeStore()

        // When/Then: removing a non-existent worktree throws
        do {
            _ = try await store.remove(id: "worktree_999")
            XCTFail("Should have thrown worktreeNotFound error")
        } catch let error as WorktreeStoreError {
            if case .worktreeNotFound(let id) = error {
                XCTAssertEqual(id, "worktree_999")
            } else {
                XCTFail("Expected worktreeNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// AC3 [P0]: Removing a worktree with force=true uses --force flag.
    func testRemove_withForce_succeeds() async throws {
        // Given: a WorktreeStore with a worktree
        let store = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        let entry = try await store.create(name: "force-remove", originalCwd: tempDir)

        // When: removing with force
        let result = try await store.remove(id: entry.id, force: true)

        // Then: succeeds
        XCTAssertTrue(result)
    }

    // MARK: - AC1: WorktreeStore Actor -- Keep

    /// AC3 [P0]: Keeping an existing worktree removes tracking but preserves filesystem.
    func testKeep_existingId_succeeds() async throws {
        // Given: a WorktreeStore with a worktree
        let store = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        let entry = try await store.create(name: "keep-me", originalCwd: tempDir)

        // Verify the path exists on filesystem
        XCTAssertTrue(FileManager.default.fileExists(atPath: entry.path))

        // When: keeping the worktree (remove tracking only)
        let result = try await store.keep(id: entry.id)

        // Then: returns true, tracking removed, but filesystem preserved
        XCTAssertTrue(result)
        let found = await store.get(id: entry.id)
        XCTAssertNil(found)

        // Filesystem path should still exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: entry.path))
    }

    /// AC4 [P0]: Keeping a non-existent worktree throws worktreeNotFound.
    func testKeep_nonexistentId_throwsError() async {
        // Given: a WorktreeStore
        let store = WorktreeStore()

        // When/Then: keeping a non-existent worktree throws
        do {
            _ = try await store.keep(id: "worktree_999")
            XCTFail("Should have thrown worktreeNotFound error")
        } catch let error as WorktreeStoreError {
            if case .worktreeNotFound(let id) = error {
                XCTAssertEqual(id, "worktree_999")
            } else {
                XCTFail("Expected worktreeNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - AC1: WorktreeStore Actor -- Clear

    /// AC1 [P1]: Clearing the store resets all worktrees and the counter.
    func testClear_resetsStore() async throws {
        // Given: a WorktreeStore with worktrees
        let store = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        try await store.create(name: "wt-1", originalCwd: tempDir)
        try await store.create(name: "wt-2", originalCwd: tempDir)

        // When: clearing the store
        await store.clear()

        // Then: store is empty and counter is reset
        let entries = await store.list()
        XCTAssertTrue(entries.isEmpty)

        // Counter reset means next worktree gets worktree_1 again
        let newEntry = try await store.create(name: "new", originalCwd: tempDir)
        XCTAssertEqual(newEntry.id, "worktree_1")
    }

    // MARK: - AC1: WorktreeStore Actor -- Thread Safety

    /// AC1 [P0]: Concurrent access to WorktreeStore does not crash (actor isolation).
    func testWorktreeStore_concurrentAccess() async throws {
        // Given: a WorktreeStore
        let store = WorktreeStore()
        let tempDir = try createTempGitRepo()
        defer { cleanupTempDir(tempDir) }

        // When: creating worktrees concurrently from multiple tasks
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    _ = try await store.create(name: "concurrent-\(i)", originalCwd: tempDir)
                }
            }
        }

        // Then: all worktrees were created without crash
        let entries = await store.list()
        XCTAssertEqual(entries.count, 10)
    }

    // MARK: - Types: WorktreeStatus

    /// AC1 [P0]: WorktreeStatus enum has expected raw values.
    func testWorktreeStatus_rawValues() {
        XCTAssertEqual(WorktreeStatus.active.rawValue, "active")
        XCTAssertEqual(WorktreeStatus.removed.rawValue, "removed")
    }

    // MARK: - Types: WorktreeEntry

    /// AC1 [P0]: WorktreeEntry is Equatable.
    func testWorktreeEntry_equality() {
        let entry1 = WorktreeEntry(
            id: "worktree_1",
            path: "/tmp/test",
            branch: "worktree-test",
            originalCwd: "/tmp/repo",
            createdAt: "2025-01-01T00:00:00Z",
            status: .active
        )
        let entry2 = WorktreeEntry(
            id: "worktree_1",
            path: "/tmp/test",
            branch: "worktree-test",
            originalCwd: "/tmp/repo",
            createdAt: "2025-01-01T00:00:00Z",
            status: .active
        )
        XCTAssertEqual(entry1, entry2)
    }

    /// AC1 [P0]: WorktreeEntry is Codable (round-trip encode/decode).
    func testWorktreeEntry_codable() throws {
        let entry = WorktreeEntry(
            id: "worktree_1",
            path: "/tmp/test",
            branch: "worktree-test",
            originalCwd: "/tmp/repo",
            createdAt: "2025-01-01T00:00:00Z",
            status: .active
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(WorktreeEntry.self, from: data)
        XCTAssertEqual(decoded, entry)
    }

    // MARK: - Types: WorktreeStoreError

    /// AC1 [P0]: WorktreeStoreError.worktreeNotFound has correct error description.
    func testWorktreeStoreError_worktreeNotFound_description() {
        let error = WorktreeStoreError.worktreeNotFound(id: "worktree_42")
        XCTAssertTrue(error.localizedDescription.contains("worktree_42"))
    }

    /// AC1 [P0]: WorktreeStoreError.gitCommandFailed has correct error description.
    func testWorktreeStoreError_gitCommandFailed_description() {
        let error = WorktreeStoreError.gitCommandFailed(message: "fatal: not a git repository")
        XCTAssertTrue(error.localizedDescription.contains("not a git repository"))
    }

    /// AC1 [P0]: WorktreeStoreError is Equatable.
    func testWorktreeStoreError_equality() {
        let error1 = WorktreeStoreError.worktreeNotFound(id: "worktree_1")
        let error2 = WorktreeStoreError.worktreeNotFound(id: "worktree_1")
        let error3 = WorktreeStoreError.worktreeNotFound(id: "worktree_2")
        let error4 = WorktreeStoreError.gitCommandFailed(message: "fail")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        XCTAssertNotEqual(error1, error4)
    }
}

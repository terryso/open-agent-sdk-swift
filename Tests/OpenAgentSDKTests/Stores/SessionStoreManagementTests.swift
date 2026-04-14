import XCTest
@testable import OpenAgentSDK

// MARK: - SessionStore Management Tests

/// ATDD RED PHASE: Tests for Story 7.4 -- Session Management (List, Rename, Tag, Delete).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `SessionMetadata` gains `tag: String?` property
///   - `PartialSessionMetadata` gains `tag: String?` property
///   - `SessionStore.list() throws -> [SessionMetadata]` is implemented
///   - `SessionStore.rename(sessionId:newTitle:) throws` is implemented
///   - `SessionStore.tag(sessionId:tag:) throws` is implemented
///   - `save()` serializes tag field, `load()` deserializes tag field
/// TDD Phase: RED (feature not implemented yet)
final class SessionStoreManagementTests: XCTestCase {

    // MARK: - Properties

    private var tempDir: String!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("session-mgmt-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        super.tearDown()
    }

    // MARK: - Helpers

    /// Create a sample session with a given number of messages and return its ID.
    private func createSampleSession(
        store: SessionStore,
        sessionId: String,
        messageCount: Int,
        summary: String? = nil,
        tag: String? = nil
    ) async throws {
        var messages: [[String: Any]] = []
        for i in 0..<messageCount {
            messages.append([
                "role": i % 2 == 0 ? "user" : "assistant",
                "content": "Message \(i)",
            ])
        }
        let metadata = PartialSessionMetadata(
            cwd: "/home/test",
            model: "test-model",
            summary: summary,
            tag: tag
        )
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
    }

    // MARK: - AC1: list() returns all session metadata sorted by updatedAt desc

    /// AC1 [P0]: list() returns empty array when no sessions exist.
    func testList_emptyDir_returnsEmptyArray() async throws {
        // Given: a SessionStore with an empty directory
        let emptyDir = (tempDir as NSString).appendingPathComponent("empty-sessions")
        try FileManager.default.createDirectory(atPath: emptyDir, withIntermediateDirectories: true)
        let store = SessionStore(sessionsDir: emptyDir)

        // When: listing sessions
        let sessions = try await store.list()

        // Then: empty array is returned
        XCTAssertTrue(sessions.isEmpty, "list() should return empty array for empty directory")
    }

    /// AC1 [P0]: list() returns sessions sorted by updatedAt descending (most recent first).
    func testList_multipleSessions_returnsSortedByUpdatedAt() async throws {
        // Given: multiple sessions saved at different times
        let store = SessionStore(sessionsDir: tempDir)

        // Create sessions with small delays to ensure different updatedAt values
        let id1 = "session-alpha-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: id1, messageCount: 2, summary: "First session")
        try await _Concurrency.Task.sleep(nanoseconds: 50_000_000) // 50ms

        let id2 = "session-beta-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: id2, messageCount: 3, summary: "Second session")
        try await _Concurrency.Task.sleep(nanoseconds: 50_000_000) // 50ms

        let id3 = "session-gamma-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: id3, messageCount: 1, summary: "Third session")

        // When: listing sessions
        let sessions = try await store.list()

        // Then: returns 3 sessions sorted by updatedAt descending
        XCTAssertEqual(sessions.count, 3, "list() should return 3 sessions")

        // Verify descending order (most recently updated first)
        if sessions.count >= 2 {
            XCTAssertGreaterThanOrEqual(
                sessions[0].updatedAt,
                sessions[1].updatedAt,
                "Sessions should be sorted by updatedAt descending"
            )
        }
        if sessions.count >= 3 {
            XCTAssertGreaterThanOrEqual(
                sessions[1].updatedAt,
                sessions[2].updatedAt,
                "Sessions should be sorted by updatedAt descending"
            )
        }

        // Verify most recently saved session (id3) is first
        XCTAssertEqual(sessions.first?.id, id3, "Most recently updated session should be first")
    }

    // MARK: - AC7: SessionMetadata tag field

    /// AC7 [P0]: list() returns metadata with tag field populated when set.
    func testList_includesTagInMetadata() async throws {
        // Given: a session saved with a tag
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "tagged-session-\(UUID().uuidString)"
        try await createSampleSession(
            store: store,
            sessionId: sessionId,
            messageCount: 2,
            summary: "Tagged session",
            tag: "important"
        )

        // When: listing sessions
        let sessions = try await store.list()

        // Then: metadata includes the tag
        XCTAssertEqual(sessions.count, 1, "Should find one session")
        XCTAssertEqual(sessions.first?.tag, "important", "Tag should be 'important'")
    }

    /// AC8 [P0]: list() skips invalid directories (missing/corrupt transcript.json).
    func testList_skipsInvalidDirectories() async throws {
        // Given: a sessions directory with valid and invalid sessions
        let store = SessionStore(sessionsDir: tempDir)

        // Create a valid session
        let validId = "valid-session-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: validId, messageCount: 2)

        // Create an invalid directory (no transcript.json)
        let invalidDir = (tempDir as NSString).appendingPathComponent("invalid-session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: invalidDir, withIntermediateDirectories: true)

        // Create a directory with corrupt JSON
        let corruptId = "corrupt-session-\(UUID().uuidString)"
        let corruptDir = (tempDir as NSString).appendingPathComponent(corruptId)
        try FileManager.default.createDirectory(atPath: corruptDir, withIntermediateDirectories: true)
        let corruptPath = (corruptDir as NSString).appendingPathComponent("transcript.json")
        try Data("not valid json{{{}".utf8).write(to: URL(fileURLWithPath: corruptPath))

        // When: listing sessions
        let sessions = try await store.list()

        // Then: only the valid session is returned
        XCTAssertEqual(sessions.count, 1, "list() should skip invalid directories and return only valid sessions")
        XCTAssertEqual(sessions.first?.id, validId, "Only the valid session should be returned")
    }

    // MARK: - AC2: rename() updates summary and updatedAt

    /// AC2 [P0]: rename() updates the session summary (and updatedAt).
    func testRename_updatesSummary() async throws {
        // Given: a saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "rename-session-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sessionId, messageCount: 3, summary: "Original Title")

        // Capture original state
        let originalData = try await store.load(sessionId: sessionId)
        let originalUpdatedAt = originalData?.metadata.updatedAt
        let originalCreatedAt = originalData?.metadata.createdAt

        // Small delay to ensure updatedAt changes
        try await _Concurrency.Task.sleep(nanoseconds: 50_000_000) // 50ms

        // When: renaming the session
        try await store.rename(sessionId: sessionId, newTitle: "Renamed Title")

        // Then: summary is updated, updatedAt is newer, messages unchanged
        let renamedData = try await store.load(sessionId: sessionId)
        XCTAssertEqual(renamedData?.metadata.summary, "Renamed Title", "Summary should be updated")
        XCTAssertEqual(renamedData?.metadata.messageCount, 3, "Message count should be preserved")
        XCTAssertEqual(renamedData?.messages.count, 3, "Messages should be preserved")
        XCTAssertEqual(renamedData?.metadata.createdAt, originalCreatedAt, "createdAt should be preserved")

        // updatedAt should be more recent than original
        XCTAssertNotEqual(renamedData?.metadata.updatedAt, originalUpdatedAt, "updatedAt should be updated")
    }

    /// AC2 [P0]: rename() on non-existent session is silent success (no error thrown).
    func testRename_nonexistent_silentSuccess() async throws {
        // Given: a SessionStore with no sessions
        let store = SessionStore(sessionsDir: tempDir)

        // When: renaming a non-existent session
        // Then: no error is thrown (silent success)
        try await store.rename(sessionId: "nonexistent-id", newTitle: "New Title")
        // Reaching this point means no error was thrown -- test passes
    }

    // MARK: - AC3: tag() adds/removes tag

    /// AC3 [P0]: tag() adds a tag to session metadata.
    func testTag_addsTagToMetadata() async throws {
        // Given: a saved session without a tag
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "tag-session-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sessionId, messageCount: 2, summary: "No tag yet")

        // Verify no tag initially
        let initialData = try await store.load(sessionId: sessionId)
        XCTAssertNil(initialData?.metadata.tag, "Initial tag should be nil")

        // When: tagging the session
        try await store.tag(sessionId: sessionId, tag: "work")

        // Then: tag is persisted
        let taggedData = try await store.load(sessionId: sessionId)
        XCTAssertEqual(taggedData?.metadata.tag, "work", "Tag should be 'work'")
        XCTAssertEqual(taggedData?.metadata.messageCount, 2, "Messages should be preserved")
    }

    /// AC3 [P0]: tag(sessionId:, tag: nil) removes an existing tag.
    func testTag_nilRemovesTag() async throws {
        // Given: a saved session with a tag
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "untag-session-\(UUID().uuidString)"
        try await createSampleSession(
            store: store,
            sessionId: sessionId,
            messageCount: 2,
            summary: "Tagged session",
            tag: "to-remove"
        )

        // Verify tag exists
        let taggedData = try await store.load(sessionId: sessionId)
        XCTAssertEqual(taggedData?.metadata.tag, "to-remove", "Tag should exist before removal")

        // When: setting tag to nil
        try await store.tag(sessionId: sessionId, tag: nil)

        // Then: tag is cleared
        let untaggedData = try await store.load(sessionId: sessionId)
        XCTAssertNil(untaggedData?.metadata.tag, "Tag should be nil after clearing")
    }

    // MARK: - AC4: delete() returns Bool

    /// AC4 [P0]: delete() on existing session returns true and removes directory.
    func testDelete_existing_returnsTrue() async throws {
        // Given: a saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "delete-existing-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sessionId, messageCount: 1)

        // When: deleting the session
        let result = try await store.delete(sessionId: sessionId)

        // Then: returns true and session is gone
        XCTAssertTrue(result, "delete() should return true for existing session")
        let loaded = try await store.load(sessionId: sessionId)
        XCTAssertNil(loaded, "Session should no longer be loadable after delete")
    }

    /// AC4 [P0]: delete() on non-existent session returns false.
    func testDelete_nonexistent_returnsFalse() async throws {
        // Given: a SessionStore
        let store = SessionStore(sessionsDir: tempDir)

        // When: deleting a non-existent session
        let result = try await store.delete(sessionId: "nonexistent-id")

        // Then: returns false
        XCTAssertFalse(result, "delete() should return false for non-existent session")
    }

    // MARK: - AC6: Thread Safety

    /// AC6,FR27 [P0]: Concurrent list/rename/tag/delete operations complete safely.
    func testConcurrentManagementOperations_noDataCorruption() async throws {
        // Given: multiple saved sessions
        let store = SessionStore(sessionsDir: tempDir)
        var sessionIds: [String] = []
        for i in 0..<5 {
            let id = "concurrent-\(i)-\(UUID().uuidString)"
            try await createSampleSession(store: store, sessionId: id, messageCount: 3, summary: "Session \(i)")
            sessionIds.append(id)
        }

        // When: performing concurrent management operations
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Concurrent renames
            for (index, id) in sessionIds.enumerated() {
                group.addTask {
                    try await store.rename(sessionId: id, newTitle: "Renamed \(index)")
                }
            }
            // Concurrent tags
            for (index, id) in sessionIds.enumerated() {
                group.addTask {
                    try await store.tag(sessionId: id, tag: "tag-\(index)")
                }
            }
            // Concurrent list
            for _ in 0..<5 {
                group.addTask {
                    _ = try await store.list()
                }
            }
            // Concurrent delete of last session
            if let lastId = sessionIds.last {
                group.addTask {
                    _ = try await store.delete(sessionId: lastId)
                }
            }
            try await group.waitForAll()
        }

        // Then: all operations completed without crash or data corruption
        let remaining = try await store.list()
        // 4 sessions remain (1 deleted), all should be loadable
        XCTAssertEqual(remaining.count, 4, "4 sessions should remain after deleting 1")

        for session in remaining {
            let loaded = try await store.load(sessionId: session.id)
            XCTAssertNotNil(loaded, "Session \(session.id) should be loadable after concurrent operations")
        }
    }

    // MARK: - AC5: Performance

    /// AC5,NFR4 [P1]: list() of 10 sessions with 500 messages each completes under 200ms.
    func testPerformance_listUnder200ms() async throws {
        // Given: 10 sessions with 500 messages each
        let store = SessionStore(sessionsDir: tempDir)
        for i in 0..<10 {
            let id = "perf-session-\(i)-\(UUID().uuidString)"
            try await createSampleSession(store: store, sessionId: id, messageCount: 500)
        }

        // When: measuring list() time
        let start = ContinuousClock.now
        let sessions = try await store.list()
        let elapsed = ContinuousClock.now - start

        // Then: list completes under 200ms
        XCTAssertEqual(sessions.count, 10, "Should list all 10 sessions")
        let elapsedMs = Int(elapsed.components.seconds) * 1000
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        XCTAssertLessThan(elapsedMs, 200, "list() of 10x500-message sessions should complete under 200ms (got \(elapsedMs)ms)")
    }

    // MARK: - AC7: Backward Compatibility

    /// AC7 [P0]: SessionMetadata loaded from JSON without tag field has tag = nil.
    func testTag_backwardCompatible_missingTagLoadsAsNil() async throws {
        // Given: a session file saved without a tag field (simulating old format)
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "legacy-session-\(UUID().uuidString)"
        let sessionDir = (tempDir as NSString).appendingPathComponent(sessionId)
        try FileManager.default.createDirectory(atPath: sessionDir, withIntermediateDirectories: true)

        // Write a legacy-format JSON without tag field
        let legacyJSON: [String: Any] = [
            "metadata": [
                "id": sessionId,
                "cwd": "/home/legacy",
                "model": "legacy-model",
                "createdAt": "2026-01-01T00:00:00.000Z",
                "updatedAt": "2026-01-01T00:00:00.000Z",
                "messageCount": 1,
            ] as [String: Any],
            "messages": [["role": "user", "content": "Legacy message"]] as [[String: Any]],
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: legacyJSON, options: [.prettyPrinted, .sortedKeys])
        let transcriptPath = (sessionDir as NSString).appendingPathComponent("transcript.json")
        FileManager.default.createFile(atPath: transcriptPath, contents: jsonData, attributes: [.posixPermissions: 0o600])

        // When: loading the legacy session
        let loaded = try await store.load(sessionId: sessionId)

        // Then: tag is nil (backward compatible)
        XCTAssertNotNil(loaded, "Legacy session should load successfully")
        XCTAssertNil(loaded?.metadata.tag, "Tag should be nil when not present in JSON")
        XCTAssertEqual(loaded?.metadata.id, sessionId, "ID should be correct")
        XCTAssertEqual(loaded?.metadata.messageCount, 1, "messageCount should be correct")
    }
}

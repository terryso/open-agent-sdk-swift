import XCTest
@testable import OpenAgentSDK

// MARK: - SessionStore Tests

/// ATDD RED PHASE: Tests for Story 7.1 -- SessionStore Actor & JSON Persistence.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `SessionStore.swift` is created in `Sources/OpenAgentSDK/Stores/`
///   - `PartialSessionMetadata` type is defined
///   - `SessionStore` actor is defined with save, load, delete methods
///   - `getSessionsDir()` resolves home directory correctly
/// TDD Phase: RED (feature not implemented yet)
final class SessionStoreTests: XCTestCase {

    // MARK: - Properties

    private var tempDir: String!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("session-store-tests-\(UUID().uuidString)")
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

    // MARK: - AC1: SessionStore Actor Basic Structure

    /// AC1 [P0]: SessionStore can be instantiated as an actor with default init.
    func testInit_createsSessionStoreActor() async {
        // Given/When: creating a SessionStore with custom directory
        let store = SessionStore(sessionsDir: tempDir)

        // Then: store is created (compilation proves it's an actor)
        _ = store
    }

    /// AC1 [P0]: SessionStore can be instantiated with custom sessions directory.
    func testInit_withCustomDir_createsSessionStore() async {
        // Given: a custom directory path
        let customDir = (tempDir as NSString).appendingPathComponent("custom-sessions")

        // When: creating SessionStore with custom directory
        let store = SessionStore(sessionsDir: customDir)

        // Then: store is created successfully
        _ = store
    }

    // MARK: - AC2: Save Session to JSON File

    /// AC2 [P0]: save() creates directory structure and transcript.json file.
    func testSave_createsDirectoryAndFile() async throws {
        // Given: a SessionStore and messages to save
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "test-session-\(UUID().uuidString)"
        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"],
            ["role": "assistant", "content": "Hi there!"],
        ]
        let metadata = PartialSessionMetadata(
            cwd: "/home/user",
            model: "gpt-4",
            summary: "Test session"
        )

        // When: saving the session
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

        // Then: directory and file exist
        let sessionDir = (tempDir as NSString).appendingPathComponent(sessionId)
        var isDir: ObjCBool = false
        let dirExists = FileManager.default.fileExists(atPath: sessionDir, isDirectory: &isDir)
        XCTAssertTrue(dirExists && isDir.boolValue, "Session directory should exist")

        let transcriptPath = (sessionDir as NSString).appendingPathComponent("transcript.json")
        let fileExists = FileManager.default.fileExists(atPath: transcriptPath)
        XCTAssertTrue(fileExists, "transcript.json should exist")
    }

    /// AC2,NFR10 [P0]: Saved file has 0600 permissions (user read/write only).
    func testSave_filePermissions0600() async throws {
        // Given: a SessionStore and messages to save
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "perm-test-\(UUID().uuidString)"
        let messages: [[String: Any]] = [["role": "user", "content": "test"]]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test-model")

        // When: saving the session
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

        // Then: file has 0600 permissions
        let sessionDir = (tempDir as NSString).appendingPathComponent(sessionId)
        let transcriptPath = (sessionDir as NSString).appendingPathComponent("transcript.json")
        let attrs = try FileManager.default.attributesOfItem(atPath: transcriptPath)
        let permissions = attrs[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o600, "File should have 0600 permissions (rw-------)")
    }

    // MARK: - AC3: Session Load

    /// AC3 [P0]: load() returns SessionData with correct metadata and messages.
    func testLoad_returnsCorrectSessionData() async throws {
        // Given: a saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "load-test-\(UUID().uuidString)"
        let messages: [[String: Any]] = [
            ["role": "user", "content": "What is Swift?"],
            ["role": "assistant", "content": "Swift is a programming language."],
        ]
        let metadata = PartialSessionMetadata(
            cwd: "/Users/test",
            model: "gpt-4",
            summary: "Swift discussion"
        )
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

        // When: loading the session
        let loaded = try await store.load(sessionId: sessionId)

        // Then: SessionData is returned with correct content
        XCTAssertNotNil(loaded, "Should return SessionData for existing session")
        XCTAssertEqual(loaded?.metadata.id, sessionId)
        XCTAssertEqual(loaded?.metadata.model, "gpt-4")
        XCTAssertEqual(loaded?.metadata.cwd, "/Users/test")
        XCTAssertEqual(loaded?.metadata.messageCount, 2)
        XCTAssertEqual(loaded?.metadata.summary, "Swift discussion")
        XCTAssertEqual(loaded?.messages.count, 2)
        XCTAssertEqual(loaded?.messages[0]["role"] as? String, "user")
        XCTAssertEqual(loaded?.messages[1]["role"] as? String, "assistant")
    }

    /// AC3 [P0]: load() returns nil for non-existent session.
    func testLoad_nonexistentSession_returnsNil() async throws {
        // Given: a SessionStore
        let store = SessionStore(sessionsDir: tempDir)

        // When: loading a session that does not exist
        let loaded = try await store.load(sessionId: "nonexistent-session-id")

        // Then: nil is returned
        XCTAssertNil(loaded, "Should return nil for non-existent session")
    }

    // MARK: - AC4: Session Delete

    /// AC4 [P0]: delete() removes session directory and returns true.
    func testDelete_removesSessionDirectory() async throws {
        // Given: a saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "delete-test-\(UUID().uuidString)"
        let messages: [[String: Any]] = [["role": "user", "content": "to delete"]]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

        // When: deleting the session
        let result = try await store.delete(sessionId: sessionId)

        // Then: returns true and directory is gone
        XCTAssertTrue(result, "Should return true for successful delete")

        let sessionDir = (tempDir as NSString).appendingPathComponent(sessionId)
        let dirExists = FileManager.default.fileExists(atPath: sessionDir)
        XCTAssertFalse(dirExists, "Session directory should be removed after delete")
    }

    /// AC4 [P0]: delete() returns false for non-existent session.
    func testDelete_nonexistentSession_returnsFalse() async throws {
        // Given: a SessionStore
        let store = SessionStore(sessionsDir: tempDir)

        // When: deleting a session that does not exist
        let result = try await store.delete(sessionId: "nonexistent-session-id")

        // Then: returns false
        XCTAssertFalse(result, "Should return false for non-existent session")
    }

    // MARK: - AC5: Concurrent Safety

    /// AC5,FR27 [P0]: Concurrent saves complete without data loss.
    func testConcurrentSave_noDataLoss() async throws {
        // Given: a SessionStore
        let store = SessionStore(sessionsDir: tempDir)

        // When: saving multiple sessions concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 1...20 {
                group.addTask {
                    let sessionId = "concurrent-\(i)-\(UUID().uuidString)"
                    let messages: [[String: Any]] = [
                        ["role": "user", "content": "Message \(i)"],
                    ]
                    let metadata = PartialSessionMetadata(
                        cwd: "/tmp",
                        model: "test",
                        summary: "Concurrent test \(i)"
                    )
                    try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
                }
            }
            try await group.waitForAll()
        }

        // Then: all sessions were saved without crash or data loss
        // Verify by loading each one
        let contents = try FileManager.default.contentsOfDirectory(atPath: tempDir)
        let sessionDirs = contents.filter { $0.hasPrefix("concurrent-") }
        XCTAssertEqual(sessionDirs.count, 20, "All 20 concurrent sessions should be saved")

        for dirName in sessionDirs {
            let loaded = try await store.load(sessionId: dirName)
            XCTAssertNotNil(loaded, "Session \(dirName) should be loadable after concurrent save")
            XCTAssertEqual(loaded?.messages.count, 1, "Session \(dirName) should have 1 message")
        }
    }

    // MARK: - AC7: Message Serialization Format

    /// AC7 [P0]: Save and load empty message list round-trip preserves data.
    func testSaveLoad_emptyMessages() async throws {
        // Given: a SessionStore and empty messages
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "empty-msg-\(UUID().uuidString)"
        let messages: [[String: Any]] = []
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test-model")

        // When: saving and loading
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
        let loaded = try await store.load(sessionId: sessionId)

        // Then: empty messages are preserved
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.messages.isEmpty, true, "Empty messages should round-trip")
        XCTAssertEqual(loaded?.metadata.messageCount, 0)
    }

    /// AC7 [P0]: Save and load preserves complex message content round-trip.
    func testSaveLoad_messageSerializationRoundTrip() async throws {
        // Given: a SessionStore with complex messages
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "serialize-\(UUID().uuidString)"
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": "Complex message with special chars: \u{1F600} <>&\"'",
                "timestamp": "2026-04-08T12:00:00.000Z",
            ],
            [
                "role": "assistant",
                "content": [
                    "type": "text",
                    "text": "Response with nested structure",
                ] as [String: Any],
            ],
        ]
        let metadata = PartialSessionMetadata(
            cwd: "/home/user/project",
            model: "glm-5.1",
            summary: "Complex serialization test"
        )

        // When: saving and loading
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
        let loaded = try await store.load(sessionId: sessionId)

        // Then: messages are preserved with correct structure
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.messages.count, 2)
        XCTAssertEqual(loaded?.messages[0]["role"] as? String, "user")
        XCTAssertEqual(loaded?.messages[1]["role"] as? String, "assistant")
        // Verify nested structure survives round-trip
        let nestedContent = loaded?.messages[1]["content"] as? [String: Any]
        XCTAssertNotNil(nestedContent, "Nested content should deserialize")
        XCTAssertEqual(nestedContent?["type"] as? String, "text")
    }

    // MARK: - AC8: Home Directory Resolution

    /// AC8 [P0]: Custom directory injection overrides default home directory.
    func testGetSessionsDir_resolvesHomeDirectory() async throws {
        // Given: a custom directory
        let customDir = (tempDir as NSString).appendingPathComponent("injected-dir")
        let store = SessionStore(sessionsDir: customDir)

        // When: saving to the custom directory
        let sessionId = "dir-test-\(UUID().uuidString)"
        let messages: [[String: Any]] = [["role": "user", "content": "test"]]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

        // Then: file is created in the custom directory (not home)
        let sessionDir = (customDir as NSString).appendingPathComponent(sessionId)
        let fileExists = FileManager.default.fileExists(atPath: sessionDir)
        XCTAssertTrue(fileExists, "File should be in custom directory, not home directory")
    }

    /// AC8 [P0]: Default init uses home directory path for sessions.
    func testGetSessionsDir_defaultUsesHomeDirectory() async {
        // Given: a SessionStore with default init (no custom dir)
        let store = SessionStore()

        // When: saving a session
        let sessionId = "home-dir-test-\(UUID().uuidString)"
        let messages: [[String: Any]] = [["role": "user", "content": "test"]]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")

        // Then: save should succeed (proving default dir works)
        // We use a do/catch because we can't predict the exact home dir path in tests
        do {
            try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)

            // Cleanup: delete the session we just created in the real directory
            let deleted = try await store.delete(sessionId: sessionId)
            XCTAssertTrue(deleted, "Should be able to delete the test session from home dir")
        } catch {
            XCTFail("Default home directory save should not throw: \(error)")
        }
    }

    // MARK: - AC6: Performance Requirements

    /// AC6,NFR4 [P1]: Save of 500 messages completes under 200ms.
    func testPerformance_saveUnder200ms() async throws {
        // Given: a SessionStore and 500 messages
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "perf-test-\(UUID().uuidString)"
        var messages: [[String: Any]] = []
        for i in 1...500 {
            messages.append([
                "role": i % 2 == 0 ? "assistant" : "user",
                "content": "Message number \(i) with some content to make it realistic",
            ])
        }
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")

        // When: measuring save time
        let start = ContinuousClock.now
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
        let elapsed = ContinuousClock.now - start

        // Then: save completes under 200ms
        let elapsedMs = Int(elapsed.components.seconds) * 1000
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        XCTAssertLessThan(elapsedMs, 200, "Save of 500 messages should complete under 200ms (got \(elapsedMs)ms)")
    }

    // MARK: - Security: Path Traversal Validation

    /// Path traversal: sessionId with ".." should throw.
    func testSave_pathTraversal_throws() async {
        let store = SessionStore(sessionsDir: tempDir)
        let messages: [[String: Any]] = [["role": "user", "content": "test"]]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")

        do {
            try await store.save(sessionId: "../etc/passwd", messages: messages, metadata: metadata)
            XCTFail("Should throw for path traversal sessionId")
        } catch let error as SDKError {
            if case .sessionError = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// Path traversal: sessionId with "/" should throw.
    func testSave_slashInSessionId_throws() async {
        let store = SessionStore(sessionsDir: tempDir)
        let messages: [[String: Any]] = [["role": "user", "content": "test"]]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")

        do {
            try await store.save(sessionId: "foo/bar", messages: messages, metadata: metadata)
            XCTFail("Should throw for sessionId with slash")
        } catch let error as SDKError {
            if case .sessionError = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// Empty sessionId should throw.
    func testSave_emptySessionId_throws() async {
        let store = SessionStore(sessionsDir: tempDir)
        let messages: [[String: Any]] = [["role": "user", "content": "test"]]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")

        do {
            try await store.save(sessionId: "", messages: messages, metadata: metadata)
            XCTFail("Should throw for empty sessionId")
        } catch let error as SDKError {
            if case .sessionError = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Data Integrity: createdAt Preservation

    /// Re-saving a session preserves the original createdAt timestamp.
    func testSave_reSave_preservesCreatedAt() async throws {
        let store = SessionStore(sessionsDir: tempDir)
        let sessionId = "resave-test-\(UUID().uuidString)"
        let messages1: [[String: Any]] = [["role": "user", "content": "first"]]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")

        // First save
        try await store.save(sessionId: sessionId, messages: messages1, metadata: metadata)
        let firstLoad = try await store.load(sessionId: sessionId)
        let originalCreatedAt = firstLoad?.metadata.createdAt

        // Small delay to ensure timestamps differ if bug exists
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Re-save with new messages
        let messages2: [[String: Any]] = [["role": "user", "content": "first"], ["role": "assistant", "content": "second"]]
        try await store.save(sessionId: sessionId, messages: messages2, metadata: metadata)
        let secondLoad = try await store.load(sessionId: sessionId)

        // Then: createdAt is preserved, updatedAt is updated
        XCTAssertEqual(secondLoad?.metadata.createdAt, originalCreatedAt, "createdAt should be preserved on re-save")
        XCTAssertEqual(secondLoad?.metadata.messageCount, 2, "messageCount should reflect new messages")
    }
}

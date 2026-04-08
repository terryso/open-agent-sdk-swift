import XCTest
@testable import OpenAgentSDK

// MARK: - SessionStore Fork Tests

/// ATDD RED PHASE: Tests for Story 7.3 -- Session Fork.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `SessionStore.fork(sourceSessionId:newSessionId:upToMessageIndex:)` is implemented
/// TDD Phase: RED (feature not implemented yet)
final class SessionStoreForkTests: XCTestCase {

    // MARK: - Properties

    private var tempDir: String!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("session-fork-tests-\(UUID().uuidString)")
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
        messageCount: Int
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
            summary: "Sample session for fork testing"
        )
        try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
    }

    // MARK: - AC1: Basic Fork

    /// AC1 [P0]: fork() creates a new session with all messages copied from source.
    func testFork_createsNewSessionWithAllMessages() async throws {
        // Given: a saved session with multiple messages
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-basic-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 5)

        // When: forking the session
        let forkId = try await store.fork(sourceSessionId: sourceId)

        // Then: a new session ID is returned (non-nil, different from source)
        XCTAssertNotNil(forkId, "fork() should return a new session ID")
        XCTAssertNotEqual(forkId, sourceId, "Fork ID should differ from source ID")

        // And: the forked session has all messages
        let sourceData = try await store.load(sessionId: sourceId)
        let forkData = try await store.load(sessionId: forkId!)
        XCTAssertNotNil(forkData, "Forked session should be loadable")
        XCTAssertEqual(forkData?.messages.count, sourceData?.messages.count, "Forked session should have same number of messages")

        // And: message content matches
        for i in 0..<(sourceData?.messages.count ?? 0) {
            XCTAssertEqual(
                forkData?.messages[i]["content"] as? String,
                sourceData?.messages[i]["content"] as? String,
                "Message \(i) content should match between source and fork"
            )
        }
    }

    /// AC1 [P0]: fork() does not modify the original session.
    func testFork_doesNotModifyOriginalSession() async throws {
        // Given: a saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-original-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 4)

        // Capture original state
        let originalData = try await store.load(sessionId: sourceId)
        let originalMessageCount = originalData?.messages.count
        let originalSummary = originalData?.metadata.summary

        // When: forking the session
        _ = try await store.fork(sourceSessionId: sourceId)

        // Then: original session is unchanged
        let afterForkData = try await store.load(sessionId: sourceId)
        XCTAssertEqual(afterForkData?.messages.count, originalMessageCount, "Original session message count should not change")
        XCTAssertEqual(afterForkData?.metadata.summary, originalSummary, "Original session summary should not change")
        XCTAssertEqual(afterForkData?.metadata.id, sourceId, "Original session ID should not change")
    }

    // MARK: - AC2: Fork with Message Index Truncation

    /// AC2 [P0]: fork() with upToMessageIndex truncates messages at the specified index.
    func testFork_withMessageIndex_truncatesMessages() async throws {
        // Given: a saved session with 10 messages
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-truncate-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 10)

        // When: forking with upToMessageIndex = 4 (inclusive, so messages 0-4)
        let forkId = try await store.fork(sourceSessionId: sourceId, upToMessageIndex: 4)

        // Then: forked session has 5 messages (indices 0 through 4, inclusive)
        XCTAssertNotNil(forkId)
        let forkData = try await store.load(sessionId: forkId!)
        XCTAssertEqual(forkData?.messages.count, 5, "Forked session should have 5 messages (0...4)")
    }

    /// AC2 [P0]: fork() with upToMessageIndex = 0 produces a single-message fork.
    func testFork_withMessageIndexZero_producesSingleMessage() async throws {
        // Given: a saved session with 5 messages
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-trunc-zero-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 5)

        // When: forking with upToMessageIndex = 0
        let forkId = try await store.fork(sourceSessionId: sourceId, upToMessageIndex: 0)

        // Then: forked session has exactly 1 message
        XCTAssertNotNil(forkId)
        let forkData = try await store.load(sessionId: forkId!)
        XCTAssertEqual(forkData?.messages.count, 1, "Forked session should have exactly 1 message")
    }

    /// AC2 [P1]: fork() with out-of-range upToMessageIndex throws an error.
    func testFork_withOutOfRangeIndex_throwsError() async throws {
        // Given: a saved session with 3 messages
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-oob-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 3)

        // When: forking with upToMessageIndex beyond the array bounds
        do {
            _ = try await store.fork(sourceSessionId: sourceId, upToMessageIndex: 10)
            XCTFail("fork() should throw for out-of-range upToMessageIndex")
        } catch let error as SDKError {
            // Then: throws SDKError.sessionError
            if case .sessionError = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// AC2 [P1]: fork() with negative upToMessageIndex throws an error.
    func testFork_withNegativeIndex_throwsError() async throws {
        // Given: a saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-neg-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 5)

        // When: forking with negative upToMessageIndex
        do {
            _ = try await store.fork(sourceSessionId: sourceId, upToMessageIndex: -1)
            XCTFail("fork() should throw for negative upToMessageIndex")
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

    // MARK: - AC3: Custom New Session ID

    /// AC3 [P0]: fork() with custom newSessionId uses the provided ID.
    func testFork_withCustomSessionId_usesProvidedId() async throws {
        // Given: a saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-custom-id-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 3)

        // When: forking with a custom session ID
        let customId = "my-custom-fork-\(UUID().uuidString)"
        let forkId = try await store.fork(sourceSessionId: sourceId, newSessionId: customId)

        // Then: returned ID matches the custom ID
        XCTAssertEqual(forkId, customId, "fork() should return the custom session ID")

        // And: session is loadable with the custom ID
        let forkData = try await store.load(sessionId: customId)
        XCTAssertNotNil(forkData, "Forked session should be loadable with custom ID")
        XCTAssertEqual(forkData?.metadata.id, customId)
    }

    /// AC3 [P0]: fork() with nil newSessionId auto-generates a UUID.
    func testFork_withNilSessionId_autoGeneratesUUID() async throws {
        // Given: a saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-auto-id-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 2)

        // When: forking without specifying newSessionId
        let forkId = try await store.fork(sourceSessionId: sourceId)

        // Then: returned ID is a valid UUID format
        XCTAssertNotNil(forkId)
        XCTAssertFalse(forkId!.isEmpty, "Auto-generated ID should not be empty")
        // Verify it is a valid UUID by parsing
        XCTAssertNotNil(UUID(uuidString: forkId!), "Auto-generated ID should be a valid UUID")
    }

    /// AC3 [P1]: fork() with invalid newSessionId (path traversal) throws.
    func testFork_withInvalidSessionId_throwsError() async throws {
        // Given: a saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-invalid-id-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 2)

        // When: forking with a path traversal session ID
        do {
            _ = try await store.fork(sourceSessionId: sourceId, newSessionId: "../etc/passwd")
            XCTFail("fork() should throw for path traversal newSessionId")
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

    // MARK: - AC4: Source Session Does Not Exist

    /// AC4 [P0]: fork() returns nil for non-existent source session.
    func testFork_nonexistentSource_returnsNil() async throws {
        // Given: a SessionStore (no sessions saved)
        let store = SessionStore(sessionsDir: tempDir)

        // When: forking from a non-existent session
        let forkId = try await store.fork(sourceSessionId: "nonexistent-session-id")

        // Then: returns nil without throwing
        XCTAssertNil(forkId, "fork() should return nil for non-existent source")
    }

    // MARK: - AC5: Forked Session Metadata

    /// AC5 [P0]: fork() sets correct metadata on the forked session.
    func testFork_metadata_correctCreatedAtAndSummary() async throws {
        // Given: a saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-metadata-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 6)

        // When: forking the session
        let forkId = try await store.fork(sourceSessionId: sourceId)

        // Then: forked session metadata is correct
        XCTAssertNotNil(forkId)
        let forkData = try await store.load(sessionId: forkId!)

        // createdAt should be recent (fork time, not original time)
        XCTAssertNotNil(forkData?.metadata.createdAt, "createdAt should be set")

        // summary should indicate fork source
        XCTAssertNotNil(forkData?.metadata.summary, "Summary should be set")
        XCTAssertTrue(
            forkData?.metadata.summary?.contains(sourceId) ?? false,
            "Summary should reference the source session ID: got \(forkData?.metadata.summary ?? "nil")"
        )
        XCTAssertTrue(
            forkData?.metadata.summary?.contains("Forked") ?? false,
            "Summary should contain 'Forked': got \(forkData?.metadata.summary ?? "nil")"
        )

        // messageCount should reflect the copied messages
        XCTAssertEqual(forkData?.metadata.messageCount, 6, "messageCount should match source message count")

        // cwd and model should be inherited from source
        XCTAssertEqual(forkData?.metadata.cwd, "/home/test", "cwd should be inherited from source")
        XCTAssertEqual(forkData?.metadata.model, "test-model", "model should be inherited from source")
    }

    /// AC5 [P0]: fork() with truncation sets correct messageCount in metadata.
    func testFork_withTruncation_metadataReflectsTruncatedCount() async throws {
        // Given: a saved session with 8 messages
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-trunc-meta-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 8)

        // When: forking with upToMessageIndex = 3
        let forkId = try await store.fork(sourceSessionId: sourceId, upToMessageIndex: 3)

        // Then: metadata messageCount reflects truncated count
        XCTAssertNotNil(forkId)
        let forkData = try await store.load(sessionId: forkId!)
        XCTAssertEqual(forkData?.metadata.messageCount, 4, "messageCount should reflect 4 truncated messages (0...3)")
    }

    // MARK: - AC7: Performance Requirements

    /// AC7,NFR4 [P1]: fork() with 500 messages completes under 200ms.
    func testFork_performanceUnder200ms() async throws {
        // Given: a saved session with 500 messages
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-perf-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 500)

        // When: measuring fork time
        let start = ContinuousClock.now
        let forkId = try await store.fork(sourceSessionId: sourceId)
        let elapsed = ContinuousClock.now - start

        // Then: fork completes under 200ms
        XCTAssertNotNil(forkId)
        let elapsedMs = Int(elapsed.components.seconds) * 1000
            + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
        XCTAssertLessThan(elapsedMs, 200, "Fork of 500 messages should complete under 200ms (got \(elapsedMs)ms)")
    }

    // MARK: - AC8: Thread Safety

    /// AC8,FR27 [P0]: Concurrent forks from the same source complete safely without data corruption.
    func testFork_concurrentForks_noDataCorruption() async throws {
        // Given: a saved session
        let store = SessionStore(sessionsDir: tempDir)
        let sourceId = "source-concurrent-\(UUID().uuidString)"
        try await createSampleSession(store: store, sessionId: sourceId, messageCount: 5)

        // When: forking concurrently from the same source
        let forkIds: [String?] = try await withThrowingTaskGroup(of: String?.self) { group in
            for i in 0..<10 {
                group.addTask {
                    try await store.fork(sourceSessionId: sourceId, newSessionId: "concurrent-fork-\(i)-\(UUID().uuidString)")
                }
            }
            var results: [String?] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        // Then: all forks succeed with unique IDs
        let successfulForks = forkIds.compactMap { $0 }
        XCTAssertEqual(successfulForks.count, 10, "All 10 concurrent forks should succeed")

        // And: all forked sessions are loadable and correct
        for forkId in successfulForks {
            let forkData = try await store.load(sessionId: forkId)
            XCTAssertNotNil(forkData, "Forked session \(forkId) should be loadable")
            XCTAssertEqual(forkData?.messages.count, 5, "Forked session should have 5 messages")
        }

        // And: original session is unchanged
        let sourceData = try await store.load(sessionId: sourceId)
        XCTAssertEqual(sourceData?.messages.count, 5, "Source session should still have 5 messages")
    }

    /// AC8,FR27 [P1]: Concurrent forks from different sources complete safely.
    func testFork_concurrentForks_differentSources_noDataCorruption() async throws {
        // Given: multiple saved sessions
        let store = SessionStore(sessionsDir: tempDir)
        var sourceIds: [String] = []
        for i in 0..<5 {
            let sourceId = "multi-source-\(i)-\(UUID().uuidString)"
            try await createSampleSession(store: store, sessionId: sourceId, messageCount: i + 1)
            sourceIds.append(sourceId)
        }

        // When: forking each source concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, sourceId) in sourceIds.enumerated() {
                group.addTask {
                    _ = try await store.fork(
                        sourceSessionId: sourceId,
                        newSessionId: "diff-fork-\(index)-\(UUID().uuidString)"
                    )
                }
            }
            try await group.waitForAll()
        }

        // Then: all source sessions remain unchanged
        for (index, sourceId) in sourceIds.enumerated() {
            let sourceData = try await store.load(sessionId: sourceId)
            XCTAssertEqual(
                sourceData?.messages.count,
                index + 1,
                "Source session \(sourceId) should have \(index + 1) messages"
            )
        }
    }
}

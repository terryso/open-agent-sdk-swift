import Foundation
import OpenAgentSDK

// MARK: - Tests 37: Session Management E2E Tests

/// E2E tests for session management (Story 7-4): list, rename, tag, delete.
/// Uses real filesystem -- no mocks (E2E convention).
/// These tests will fail to compile until list(), rename(), tag() are implemented
/// and SessionMetadata/PartialSessionMetadata gain tag field.
struct SessionManagementE2ETests {
    static func run() async {
        section("37. Session Management (E2E)")
        await testListSessions_metadataComplete()
        await testRenameThenList_updated()
        await testTagThenLoad_persisted()
        await testDeleteThenList_removed()
    }

    // MARK: Test 37a: List Sessions -- metadata complete and sorted

    /// AC1,AC10 [P0]: Create multiple sessions -> list() -> verify metadata complete and sorted.
    static func testListSessions_metadataComplete() async {
        let store = SessionStore()
        var sessionIds: [String] = []

        // Step 1: Create 3 sessions with different content
        for i in 0..<3 {
            let sessionId = "e2e-mgmt-list-\(i)-\(UUID().uuidString)"
            sessionIds.append(sessionId)
            let messages: [[String: Any]] = [
                ["role": "user", "content": "List test message \(i)"],
                ["role": "assistant", "content": "Response \(i)"],
            ]
            let metadata = PartialSessionMetadata(
                cwd: "/tmp",
                model: "e2e-test",
                summary: "Management test session \(i)",
                tag: i == 0 ? "important" : nil
            )

            do {
                try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
            } catch {
                fail("Session management E2E: list setup save \(i)", "threw: \(error)")
                // Cleanup partial sessions
                for id in sessionIds { _ = try? await store.delete(sessionId: id) }
                return
            }
            // Small delay for distinct timestamps
            if i < 2 {
                try? await _Concurrency.Task.sleep(nanoseconds: 50_000_000)
            }
        }
        pass("Session management E2E: created 3 test sessions")

        // Step 2: List sessions
        let sessions: [SessionMetadata]
        do {
            sessions = try await store.list()
        } catch {
            fail("Session management E2E: list()", "threw: \(error)")
            for id in sessionIds { _ = try? await store.delete(sessionId: id) }
            return
        }

        // Step 3: Verify metadata
        if sessions.count >= 3 {
            pass("Session management E2E: list returns \(sessions.count) sessions (>=3)")
        } else {
            fail("Session management E2E: list returns >= 3 sessions", "got \(sessions.count)")
        }

        // Verify sorting (most recent first)
        var sortedCorrectly = true
        for i in 0..<(sessions.count - 1) {
            if sessions[i].updatedAt < sessions[i + 1].updatedAt {
                sortedCorrectly = false
                break
            }
        }
        if sortedCorrectly {
            pass("Session management E2E: list sorted by updatedAt descending")
        } else {
            fail("Session management E2E: list sorted by updatedAt descending", "order incorrect")
        }

        // Verify each session has complete metadata fields
        let testSessions = sessions.filter { $0.id.hasPrefix("e2e-mgmt-list-") }
        for session in testSessions {
            if !session.id.isEmpty && !session.model.isEmpty && !session.cwd.isEmpty {
                pass("Session management E2E: session \(session.id.prefix(20)) has complete metadata")
            } else {
                fail("Session management E2E: session metadata complete", "missing fields in \(session.id)")
            }
        }

        // Verify tagged session has tag
        let taggedSessions = testSessions.filter { $0.tag == "important" }
        if taggedSessions.count == 1 {
            pass("Session management E2E: tagged session has tag 'important'")
        } else {
            fail("Session management E2E: tagged session has tag 'important'", "found \(taggedSessions.count)")
        }

        // Cleanup
        for id in sessionIds { _ = try? await store.delete(sessionId: id) }
    }

    // MARK: Test 37b: Rename -> List -> verify updated

    /// AC2,AC10 [P0]: rename() -> list() -> verify summary updated in metadata.
    static func testRenameThenList_updated() async {
        let store = SessionStore()
        let sessionId = "e2e-mgmt-rename-\(UUID().uuidString)"

        // Step 1: Create a session
        let messages: [[String: Any]] = [
            ["role": "user", "content": "Rename test"],
            ["role": "assistant", "content": "Response"],
        ]
        let metadata = PartialSessionMetadata(
            cwd: "/tmp",
            model: "e2e-test",
            summary: "Original Name"
        )

        do {
            try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
            pass("Session management E2E: rename setup save succeeds")
        } catch {
            fail("Session management E2E: rename setup save", "threw: \(error)")
            return
        }

        // Step 2: Rename the session
        do {
            try await store.rename(sessionId: sessionId, newTitle: "Renamed Session")
            pass("Session management E2E: rename succeeds")
        } catch {
            fail("Session management E2E: rename", "threw: \(error)")
            _ = try? await store.delete(sessionId: sessionId)
            return
        }

        // Step 3: List and verify the renamed session
        let sessions: [SessionMetadata]
        do {
            sessions = try await store.list()
        } catch {
            fail("Session management E2E: list after rename", "threw: \(error)")
            _ = try? await store.delete(sessionId: sessionId)
            return
        }

        let renamedSession = sessions.first { $0.id == sessionId }
        if let session = renamedSession {
            if session.summary == "Renamed Session" {
                pass("Session management E2E: rename updated summary to 'Renamed Session'")
            } else {
                fail("Session management E2E: rename updated summary", "got: \(session.summary ?? "nil")")
            }

            if session.messageCount == 2 {
                pass("Session management E2E: rename preserved message count")
            } else {
                fail("Session management E2E: rename preserved message count", "got: \(session.messageCount)")
            }
        } else {
            fail("Session management E2E: renamed session found in list", "session not found")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    // MARK: Test 37c: Tag -> Load -> verify persisted

    /// AC3,AC10 [P0]: tag() -> load() -> verify tag persisted across read.
    static func testTagThenLoad_persisted() async {
        let store = SessionStore()
        let sessionId = "e2e-mgmt-tag-\(UUID().uuidString)"

        // Step 1: Create a session
        let messages: [[String: Any]] = [
            ["role": "user", "content": "Tag test"],
        ]
        let metadata = PartialSessionMetadata(
            cwd: "/tmp",
            model: "e2e-test",
            summary: "Tag test session"
        )

        do {
            try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
            pass("Session management E2E: tag setup save succeeds")
        } catch {
            fail("Session management E2E: tag setup save", "threw: \(error)")
            return
        }

        // Step 2: Tag the session
        do {
            try await store.tag(sessionId: sessionId, tag: "e2e-tag")
            pass("Session management E2E: tag succeeds")
        } catch {
            fail("Session management E2E: tag", "threw: \(error)")
            _ = try? await store.delete(sessionId: sessionId)
            return
        }

        // Step 3: Load and verify tag persisted
        if let loaded = try? await store.load(sessionId: sessionId) {
            if loaded.metadata.tag == "e2e-tag" {
                pass("Session management E2E: tag persisted after load")
            } else {
                fail("Session management E2E: tag persisted", "got: \(loaded.metadata.tag ?? "nil")")
            }
        } else {
            fail("Session management E2E: load after tag", "returned nil")
        }

        // Step 4: Clear the tag
        do {
            try await store.tag(sessionId: sessionId, tag: nil)
            pass("Session management E2E: clear tag (nil) succeeds")
        } catch {
            fail("Session management E2E: clear tag", "threw: \(error)")
            _ = try? await store.delete(sessionId: sessionId)
            return
        }

        // Step 5: Verify tag cleared
        if let loaded = try? await store.load(sessionId: sessionId) {
            if loaded.metadata.tag == nil {
                pass("Session management E2E: tag cleared (nil) after setting to nil")
            } else {
                fail("Session management E2E: tag cleared", "got: \(loaded.metadata.tag ?? "nil")")
            }
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    // MARK: Test 37d: Delete -> List -> verify removed

    /// AC4,AC10 [P0]: delete() -> list() -> verify session removed from list.
    static func testDeleteThenList_removed() async {
        let store = SessionStore()
        let sessionId1 = "e2e-mgmt-del-1-\(UUID().uuidString)"
        let sessionId2 = "e2e-mgmt-del-2-\(UUID().uuidString)"

        // Step 1: Create two sessions
        do {
            try await store.save(
                sessionId: sessionId1,
                messages: [["role": "user", "content": "Delete test"]],
                metadata: PartialSessionMetadata(cwd: "/tmp", model: "e2e-test", summary: "To delete")
            )
            try await store.save(
                sessionId: sessionId2,
                messages: [["role": "user", "content": "Delete test"]],
                metadata: PartialSessionMetadata(cwd: "/tmp", model: "e2e-test", summary: "To delete")
            )
            pass("Session management E2E: delete setup (2 sessions saved)")
        } catch {
            fail("Session management E2E: delete setup", "threw: \(error)")
            return
        }

        // Step 2: Delete the first session
        let deleted: Bool
        do {
            deleted = try await store.delete(sessionId: sessionId1)
        } catch {
            fail("Session management E2E: delete", "threw: \(error)")
            _ = try? await store.delete(sessionId: sessionId2)
            return
        }

        if deleted {
            pass("Session management E2E: delete returns true")
        } else {
            fail("Session management E2E: delete returns true", "returned false")
        }

        // Step 3: List and verify session1 is gone
        let sessions: [SessionMetadata]
        do {
            sessions = try await store.list()
        } catch {
            fail("Session management E2E: list after delete", "threw: \(error)")
            _ = try? await store.delete(sessionId: sessionId2)
            return
        }

        let deletedSessionPresent = sessions.contains { $0.id == sessionId1 }
        let remainingSessionPresent = sessions.contains { $0.id == sessionId2 }

        if !deletedSessionPresent {
            pass("Session management E2E: deleted session not in list")
        } else {
            fail("Session management E2E: deleted session not in list", "session still present")
        }

        if remainingSessionPresent {
            pass("Session management E2E: remaining session still in list")
        } else {
            fail("Session management E2E: remaining session still in list", "session missing")
        }

        // Step 4: Verify delete of non-existent session returns false
        let deleteAgain: Bool
        do {
            deleteAgain = try await store.delete(sessionId: sessionId1)
        } catch {
            fail("Session management E2E: delete non-existent", "threw: \(error)")
            _ = try? await store.delete(sessionId: sessionId2)
            return
        }

        if !deleteAgain {
            pass("Session management E2E: delete non-existent returns false")
        } else {
            fail("Session management E2E: delete non-existent returns false", "returned true")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId2)
    }
}

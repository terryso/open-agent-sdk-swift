import Foundation
import OpenAgentSDK

// MARK: - Tests 34: SessionStore E2E Tests

/// E2E tests for SessionStore JSON persistence (Story 7-1).
/// Uses real filesystem -- no mocks (E2E convention).
/// These tests will fail to compile until SessionStore is implemented.
struct SessionStoreE2ETests {
    static func run() async {
        section("34. SessionStore JSON Persistence (E2E)")
        await testSaveLoadRoundTrip()
        await testFilePermissions()
        await testDirectoryAutoCreation()
        await testConcurrentSaves()
        await testDeleteSession()
    }

    // MARK: Test 34a: Save and Load Round Trip

    static func testSaveLoadRoundTrip() async {
        let store = SessionStore()
        let sessionId = "e2e-roundtrip-\(UUID().uuidString)"
        let messages: [[String: Any]] = [
            ["role": "user", "content": "What is the capital of France?"],
            ["role": "assistant", "content": "The capital of France is Paris."],
            ["role": "user", "content": "And Germany?"],
            ["role": "assistant", "content": "The capital of Germany is Berlin."],
        ]
        let metadata = PartialSessionMetadata(
            cwd: "/Users/test/project",
            model: "glm-5.1",
            summary: "Geography Q&A session"
        )

        do {
            try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
            pass("SessionStore E2E: save succeeds on real filesystem")
        } catch {
            fail("SessionStore E2E: save succeeds on real filesystem", "threw: \(error)")
            return
        }

        let loaded: SessionData?
        do {
            loaded = try await store.load(sessionId: sessionId)
        } catch {
            fail("SessionStore E2E: load returns correct session data", "threw: \(error)")
            return
        }
        if let loaded {
            if loaded.metadata.id == sessionId
                && loaded.metadata.model == "glm-5.1"
                && loaded.metadata.messageCount == 4
                && loaded.messages.count == 4
            {
                pass("SessionStore E2E: load returns correct session data")
            } else {
                fail(
                    "SessionStore E2E: load returns correct session data",
                    "id=\(loaded.metadata.id) model=\(loaded.metadata.model) count=\(loaded.metadata.messageCount)"
                )
            }
        } else {
            fail("SessionStore E2E: load returns correct session data", "returned nil")
        }

        // Cleanup
        let deleted = (try? await store.delete(sessionId: sessionId)) ?? false
        if deleted {
            pass("SessionStore E2E: cleanup delete succeeds")
        } else {
            fail("SessionStore E2E: cleanup delete succeeds")
        }
    }

    // MARK: Test 34b: File Permissions

    static func testFilePermissions() async {
        let store = SessionStore()
        let sessionId = "e2e-perms-\(UUID().uuidString)"
        let messages: [[String: Any]] = [
            ["role": "user", "content": "Permission test"],
        ]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")

        do {
            try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
        } catch {
            fail("SessionStore E2E: file permissions setup", "threw: \(error)")
            return
        }

        // Find the session directory -- use home directory resolution
        #if os(Linux)
        let home: String
        if let homeEnv = getenv("HOME") {
            home = String(cString: homeEnv)
        } else {
            home = "/tmp"
        }
        #else
        let home = NSHomeDirectory()
        #endif
        let sessionsDir = (home as NSString).appendingPathComponent(".open-agent-sdk/sessions")
        let sessionDir = (sessionsDir as NSString).appendingPathComponent(sessionId)
        let transcriptPath = (sessionDir as NSString).appendingPathComponent("transcript.json")

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: transcriptPath)
            if let perms = attrs[.posixPermissions] as? Int, perms == 0o600 {
                pass("SessionStore E2E: transcript.json has 0600 permissions")
            } else {
                let actualPerms = attrs[.posixPermissions] as? Int ?? -1
                fail(
                    "SessionStore E2E: transcript.json has 0600 permissions",
                    "got: \(String(format: "0%o", actualPerms))"
                )
            }
        } catch {
            fail("SessionStore E2E: transcript.json has 0600 permissions", "stat failed: \(error)")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    // MARK: Test 34c: Directory Auto-Creation

    static func testDirectoryAutoCreation() async {
        let store = SessionStore()
        let sessionId = "e2e-autocreate-\(UUID().uuidString)"

        // Ensure the session directory does NOT exist before save
        #if os(Linux)
        let home = String(cString: getenv("HOME") ?? "/tmp")
        #else
        let home = NSHomeDirectory()
        #endif
        let sessionsDir = (home as NSString).appendingPathComponent(".open-agent-sdk/sessions")
        let sessionDir = (sessionsDir as NSString).appendingPathComponent(sessionId)

        // Verify directory does not exist
        let existedBefore = FileManager.default.fileExists(atPath: sessionDir)

        let messages: [[String: Any]] = [["role": "user", "content": "Auto-create test"]]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")

        do {
            try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
        } catch {
            fail("SessionStore E2E: directory auto-creation save", "threw: \(error)")
            return
        }

        // Verify directory was created
        var isDir: ObjCBool = false
        let existsAfter = FileManager.default.fileExists(atPath: sessionDir, isDirectory: &isDir)

        if !existedBefore && existsAfter && isDir.boolValue {
            pass("SessionStore E2E: save auto-creates session directory")
        } else {
            fail(
                "SessionStore E2E: save auto-creates session directory",
                "existedBefore=\(existedBefore) existsAfter=\(existsAfter) isDir=\(isDir.boolValue)"
            )
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    // MARK: Test 34d: Concurrent Saves

    static func testConcurrentSaves() async {
        let store = SessionStore()
        let sessionId = "e2e-concurrent-\(UUID().uuidString)"
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")
        let msgs1: [[String: Any]] = [["role": "user", "content": "Save 1"]]
        let msgs2: [[String: Any]] = [["role": "user", "content": "Save 2"]]

        // Launch two concurrent saves to the same session
        async let save1 = store.save(sessionId: sessionId, messages: msgs1, metadata: metadata)
        async let save2 = store.save(sessionId: sessionId, messages: msgs2, metadata: metadata)

        var saveErrors = 0
        do { try await save1 } catch { saveErrors += 1 }
        do { try await save2 } catch { saveErrors += 1 }

        if saveErrors == 0 {
            pass("SessionStore E2E: concurrent saves complete without crash")
        } else {
            fail("SessionStore E2E: concurrent saves complete without crash", "\(saveErrors) errors")
        }

        // Verify session is loadable and data is valid (last-write-wins — content from either save)
        if let loaded = try? await store.load(sessionId: sessionId) {
            if loaded.metadata.id == sessionId && loaded.messages.count == 1 {
                let content = loaded.messages[0]["content"] as? String ?? ""
                if content == "Save 1" || content == "Save 2" {
                    pass("SessionStore E2E: session data valid after concurrent saves")
                } else {
                    fail("SessionStore E2E: session data valid after concurrent saves", "unexpected content: \(content)")
                }
            } else {
                fail("SessionStore E2E: session data valid after concurrent saves", "id=\(loaded.metadata.id) count=\(loaded.messages.count)")
            }
        } else {
            fail("SessionStore E2E: session data valid after concurrent saves", "load returned nil")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    // MARK: Test 34e: Delete Session

    static func testDeleteSession() async {
        let store = SessionStore()
        let sessionId = "e2e-delete-\(UUID().uuidString)"
        let messages: [[String: Any]] = [["role": "user", "content": "Delete test"]]
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test")

        // Save first
        do {
            try await store.save(sessionId: sessionId, messages: messages, metadata: metadata)
        } catch {
            fail("SessionStore E2E: delete setup save", "threw: \(error)")
            return
        }

        // Delete existing session
        do {
            let deleted = try await store.delete(sessionId: sessionId)
            if deleted {
                pass("SessionStore E2E: delete existing session returns true")
            } else {
                fail("SessionStore E2E: delete existing session returns true", "returned false")
            }
        } catch {
            fail("SessionStore E2E: delete existing session returns true", "threw: \(error)")
        }

        // Verify session is gone
        if let _ = try? await store.load(sessionId: sessionId) {
            fail("SessionStore E2E: deleted session is gone", "session still loadable")
        } else {
            pass("SessionStore E2E: deleted session is gone")
        }

        // Delete nonexistent session
        do {
            let deleted = try await store.delete(sessionId: "nonexistent-\(UUID().uuidString)")
            if !deleted {
                pass("SessionStore E2E: delete nonexistent session returns false")
            } else {
                fail("SessionStore E2E: delete nonexistent session returns false", "returned true")
            }
        } catch {
            fail("SessionStore E2E: delete nonexistent session returns false", "threw: \(error)")
        }
    }
}

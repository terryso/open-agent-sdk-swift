import Foundation
import OpenAgentSDK

// MARK: - Tests 36: Session Fork E2E Tests

/// E2E tests for session fork (Story 7-3).
/// Uses real filesystem and real LLM API calls -- no mocks (E2E convention).
/// These tests will fail until SessionStore.fork() is implemented.
struct SessionForkE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("36. Session Fork (E2E)")
        await testFullSessionForkAndRestore(apiKey: apiKey, model: model, baseURL: baseURL)
        await testTruncatedForkRestore(apiKey: apiKey, model: model, baseURL: baseURL)
        await testForkThenContinueConversation(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: Test 36a: Full Session Fork -> Restore -> Verify Message Integrity

    /// AC1,AC5,AC6,AC10 [P0]: Fork a full session, restore via agent, verify all messages intact.
    static func testFullSessionForkAndRestore(apiKey: String, model: String, baseURL: String) async {
        let store = SessionStore()
        let sourceId = "e2e-fork-full-\(UUID().uuidString)"

        // Step 1: Create and save a session with multiple messages
        let messages: [[String: Any]] = [
            ["role": "user", "content": "Remember the city Paris."],
            ["role": "assistant", "content": ["type": "text", "text": "I'll remember Paris."] as [String: Any]],
            ["role": "user", "content": "Also remember the number 99."],
            ["role": "assistant", "content": ["type": "text", "text": "I'll remember the number 99."] as [String: Any]],
        ]
        let metadata = PartialSessionMetadata(
            cwd: "/tmp",
            model: model,
            summary: "Fork source session"
        )

        do {
            // Serialize messages for Sendable compliance
            let messagesData = try JSONSerialization.data(withJSONObject: messages, options: [])
            guard let sendableMessages = try JSONSerialization.jsonObject(with: messagesData, options: []) as? [[String: Any]] else {
                fail("Session fork E2E: save source session", "failed to deserialize messages")
                return
            }
            try await store.save(sessionId: sourceId, messages: sendableMessages, metadata: metadata)
            pass("Session fork E2E: source session saved (4 messages)")
        } catch {
            fail("Session fork E2E: save source session", "threw: \(error)")
            return
        }

        // Step 2: Fork the session
        let forkId: String?
        do {
            forkId = try await store.fork(sourceSessionId: sourceId)
        } catch {
            fail("Session fork E2E: fork succeeds", "threw: \(error)")
            _ = try? await store.delete(sessionId: sourceId)
            return
        }

        guard let unwrappedForkId = forkId else {
            fail("Session fork E2E: fork returns ID", "returned nil")
            _ = try? await store.delete(sessionId: sourceId)
            return
        }
        pass("Session fork E2E: fork succeeds (new ID: \(unwrappedForkId.prefix(16))...)")

        // Step 3: Verify forked session has all messages
        if let forkData = try? await store.load(sessionId: unwrappedForkId) {
            if forkData.messages.count == 4 {
                pass("Session fork E2E: forked session has 4 messages")
            } else {
                fail("Session fork E2E: forked session has 4 messages", "got \(forkData.messages.count)")
            }

            // Verify summary contains fork source info
            if let summary = forkData.metadata.summary, summary.contains(sourceId) {
                pass("Session fork E2E: forked session summary references source")
            } else {
                fail("Session fork E2E: forked session summary references source",
                     "summary: \(forkData.metadata.summary ?? "nil")")
            }
        } else {
            fail("Session fork E2E: load forked session", "returned nil")
        }

        // Step 4: Restore forked session via agent and continue conversation
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 3,
            sessionStore: store,
            sessionId: unwrappedForkId
        )
        let agent = createAgent(options: options)

        let result = await agent.prompt("What city and number did I ask you to remember?")

        if result.status == .success {
            pass("Session fork E2E: restore forked session via prompt succeeds")
        } else {
            fail("Session fork E2E: restore forked session via prompt succeeds", "status: \(result.status)")
        }

        // The response should reference both Paris and 99
        let responseText = result.text.lowercased()
        let mentionsParis = responseText.contains("paris")
        let mentions99 = responseText.contains("99")

        if mentionsParis {
            pass("Session fork E2E: restored context includes city (Paris)")
        } else {
            fail("Session fork E2E: restored context includes city (Paris)",
                 "response: \(result.text.prefix(100))")
        }

        if mentions99 {
            pass("Session fork E2E: restored context includes number (99)")
        } else {
            fail("Session fork E2E: restored context includes number (99)",
                 "response: \(result.text.prefix(100))")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sourceId)
        _ = try? await store.delete(sessionId: unwrappedForkId)
    }

    // MARK: Test 36b: Truncated Fork -> Restore -> Verify Message Count

    /// AC2,AC5,AC6,AC10 [P0]: Fork with truncation, restore via agent, verify truncated messages.
    static func testTruncatedForkRestore(apiKey: String, model: String, baseURL: String) async {
        let store = SessionStore()
        let sourceId = "e2e-fork-trunc-\(UUID().uuidString)"

        // Step 1: Create a 6-message session
        let messages: [[String: Any]] = [
            ["role": "user", "content": "My name is Bob."],
            ["role": "assistant", "content": ["type": "text", "text": "Hello Bob!"] as [String: Any]],
            ["role": "user", "content": "I like apples."],
            ["role": "assistant", "content": ["type": "text", "text": "Apples are great!"] as [String: Any]],
            ["role": "user", "content": "I also like oranges."],
            ["role": "assistant", "content": ["type": "text", "text": "Oranges are delicious too!"] as [String: Any]],
        ]
        let metadata = PartialSessionMetadata(
            cwd: "/tmp",
            model: model,
            summary: "Truncated fork source"
        )

        do {
            let messagesData = try JSONSerialization.data(withJSONObject: messages, options: [])
            guard let sendableMessages = try JSONSerialization.jsonObject(with: messagesData, options: []) as? [[String: Any]] else {
                fail("Session fork E2E: save truncated source", "failed to deserialize messages")
                return
            }
            try await store.save(sessionId: sourceId, messages: sendableMessages, metadata: metadata)
            pass("Session fork E2E: truncated source saved (6 messages)")
        } catch {
            fail("Session fork E2E: save truncated source", "threw: \(error)")
            return
        }

        // Step 2: Fork with upToMessageIndex = 1 (only first 2 messages: name exchange)
        let forkId: String?
        do {
            forkId = try await store.fork(sourceSessionId: sourceId, upToMessageIndex: 1)
        } catch {
            fail("Session fork E2E: truncated fork succeeds", "threw: \(error)")
            _ = try? await store.delete(sessionId: sourceId)
            return
        }

        guard let unwrappedForkId = forkId else {
            fail("Session fork E2E: truncated fork returns ID", "returned nil")
            _ = try? await store.delete(sessionId: sourceId)
            return
        }

        // Step 3: Verify truncated fork has only 2 messages
        if let forkData = try? await store.load(sessionId: unwrappedForkId) {
            if forkData.messages.count == 2 {
                pass("Session fork E2E: truncated fork has 2 messages (0...1)")
            } else {
                fail("Session fork E2E: truncated fork has 2 messages", "got \(forkData.messages.count)")
            }
        } else {
            fail("Session fork E2E: load truncated fork", "returned nil")
        }

        // Step 4: Restore truncated fork and verify it only knows the name
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 3,
            sessionStore: store,
            sessionId: unwrappedForkId
        )
        let agent = createAgent(options: options)

        let result = await agent.prompt("What is my name and what fruits do I like?")

        if result.status == .success {
            pass("Session fork E2E: restore truncated fork succeeds")
        } else {
            fail("Session fork E2E: restore truncated fork succeeds", "status: \(result.status)")
        }

        let responseText = result.text.lowercased()
        // Should know the name (Bob) since first 2 messages were preserved
        let mentionsBob = responseText.contains("bob")
        // Should NOT reliably know about apples/oranges since those messages were truncated
        if mentionsBob {
            pass("Session fork E2E: truncated fork knows name (Bob)")
        } else {
            fail("Session fork E2E: truncated fork knows name (Bob)",
                 "response: \(result.text.prefix(100))")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sourceId)
        _ = try? await store.delete(sessionId: unwrappedForkId)
    }

    // MARK: Test 36c: Fork Then Continue -> Verify Sessions Diverge

    /// AC1,AC6,AC10 [P0]: Fork a session, continue both independently, verify divergence.
    static func testForkThenContinueConversation(apiKey: String, model: String, baseURL: String) async {
        let store = SessionStore()
        let sourceId = "e2e-fork-diverge-\(UUID().uuidString)"

        // Step 1: Create initial session
        let messages: [[String: Any]] = [
            ["role": "user", "content": "My favorite color is blue."],
            ["role": "assistant", "content": ["type": "text", "text": "Blue is a beautiful color!"] as [String: Any]],
        ]
        let metadata = PartialSessionMetadata(
            cwd: "/tmp",
            model: model,
            summary: "Divergence test source"
        )

        do {
            let messagesData = try JSONSerialization.data(withJSONObject: messages, options: [])
            guard let sendableMessages = try JSONSerialization.jsonObject(with: messagesData, options: []) as? [[String: Any]] else {
                fail("Session fork E2E: save divergence source", "failed to deserialize messages")
                return
            }
            try await store.save(sessionId: sourceId, messages: sendableMessages, metadata: metadata)
            pass("Session fork E2E: divergence source saved")
        } catch {
            fail("Session fork E2E: save divergence source", "threw: \(error)")
            return
        }

        // Step 2: Fork the session
        let forkId: String?
        do {
            forkId = try await store.fork(sourceSessionId: sourceId)
        } catch {
            fail("Session fork E2E: divergence fork succeeds", "threw: \(error)")
            _ = try? await store.delete(sessionId: sourceId)
            return
        }

        guard let unwrappedForkId = forkId else {
            fail("Session fork E2E: divergence fork returns ID", "returned nil")
            _ = try? await store.delete(sessionId: sourceId)
            return
        }
        pass("Session fork E2E: divergence fork created")

        // Step 3: Continue the original session
        let originalOptions = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 3,
            sessionStore: store,
            sessionId: sourceId
        )
        let originalAgent = createAgent(options: originalOptions)
        let originalResult = await originalAgent.prompt("Tell me my favorite color.")

        if originalResult.status == .success {
            pass("Session fork E2E: continue original session succeeds")
        } else {
            fail("Session fork E2E: continue original session succeeds", "status: \(originalResult.status)")
        }

        // Step 4: Continue the forked session with a different prompt
        let forkOptions = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 3,
            sessionStore: store,
            sessionId: unwrappedForkId
        )
        let forkAgent = createAgent(options: forkOptions)
        let forkResult = await forkAgent.prompt("What is my favorite color?")

        if forkResult.status == .success {
            pass("Session fork E2E: continue forked session succeeds")
        } else {
            fail("Session fork E2E: continue forked session succeeds", "status: \(forkResult.status)")
        }

        // Step 5: Verify both sessions are independent (check message counts differ after continuation)
        if let originalData = try? await store.load(sessionId: sourceId),
           let forkData = try? await store.load(sessionId: unwrappedForkId) {
            // Both should have more than 2 messages now
            if originalData.messages.count > 2 && forkData.messages.count > 2 {
                pass("Session fork E2E: both sessions grew independently (original: \(originalData.messages.count), fork: \(forkData.messages.count))")
            } else {
                fail("Session fork E2E: both sessions grew independently",
                     "original: \(originalData.messages.count), fork: \(forkData.messages.count)")
            }

            // Verify sessions have different IDs
            if originalData.metadata.id != forkData.metadata.id {
                pass("Session fork E2E: sessions have different IDs")
            } else {
                fail("Session fork E2E: sessions have different IDs", "both are \(originalData.metadata.id)")
            }
        } else {
            fail("Session fork E2E: load both sessions after continuation", "one or both returned nil")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sourceId)
        _ = try? await store.delete(sessionId: unwrappedForkId)
    }
}

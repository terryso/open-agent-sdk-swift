import Foundation
import OpenAgentSDK

// MARK: - Tests 35: Session Restore E2E Tests

/// E2E tests for session load & restore (Story 7-2).
/// Uses real filesystem and real LLM API calls -- no mocks (E2E convention).
/// These tests will fail until AgentOptions has sessionStore/sessionId properties
/// and Agent.prompt()/stream() implement session restore logic.
struct SessionRestoreE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("35. Session Load & Restore (E2E)")
        await testSaveRestoreRoundTrip(apiKey: apiKey, model: model, baseURL: baseURL)
        await testMultiTurnRestore(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: Test 35a: Save → Restore → Continue Conversation (Round Trip)

    /// AC1,AC5,AC8 [P0]: Save a session, then restore it via agent.prompt(sessionId:)
    /// and continue the conversation. Verify the restored context is used.
    static func testSaveRestoreRoundTrip(apiKey: String, model: String, baseURL: String) async {
        let store = SessionStore()
        let sessionId = "e2e-restore-roundtrip-\(UUID().uuidString)"

        // Step 1: Save initial conversation history
        let initialMessages: [[String: Any]] = [
            ["role": "user", "content": "Remember the number 42."],
            ["role": "assistant", "content": [["type": "text", "text": "I'll remember the number 42."]] as [[String: Any]]],
        ]
        let metadata = PartialSessionMetadata(
            cwd: "/tmp",
            model: model,
            summary: "Number memory test"
        )

        let initialMessageCount = initialMessages.count
        do {
            // Serialize messages for Sendable compliance when crossing actor boundary
            let messagesData = try JSONSerialization.data(withJSONObject: initialMessages, options: [])
            guard let sendableMessages = try JSONSerialization.jsonObject(with: messagesData, options: []) as? [[String: Any]] else {
                fail("Session restore E2E: initial session saved", "failed to deserialize messages")
                return
            }
            try await store.save(sessionId: sessionId, messages: sendableMessages, metadata: metadata)
            pass("Session restore E2E: initial session saved")
        } catch {
            fail("Session restore E2E: initial session saved", "threw: \(error)")
            return
        }

        // Step 2: Restore session and continue conversation via prompt()
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            maxTurns: 3,
            sessionStore: store,
            sessionId: sessionId
        )
        let agent = createAgent(options: options)

        let result = await agent.prompt("What number did I ask you to remember?")

        // Step 3: Verify the restored context was used
        if result.status == .success {
            pass("Session restore E2E: prompt with sessionId succeeds")
        } else {
            fail("Session restore E2E: prompt with sessionId succeeds", "status: \(result.status)")
        }

        // The response should reference the remembered number (42)
        if result.text.contains("42") {
            pass("Session restore E2E: response uses restored context (mentions 42)")
        } else {
            fail("Session restore E2E: response uses restored context (mentions 42)",
                 "response: \(result.text.prefix(100))")
        }

        // Step 4: Verify auto-save updated the session
        if let updated = try? await store.load(sessionId: sessionId) {
            if updated.messages.count > initialMessageCount {
                pass("Session restore E2E: auto-save updated session (\(updated.messages.count) messages)")
            } else {
                fail("Session restore E2E: auto-save updated session",
                     "still has \(updated.messages.count) messages, expected more than \(initialMessageCount)")
            }
        } else {
            fail("Session restore E2E: auto-save updated session", "could not load session")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }

    // MARK: Test 35b: Multi-Turn Restore Verification

    /// AC1,AC2,AC8 [P0]: Save a multi-turn conversation, restore it, and verify
    /// all previous turns are included in the context sent to the LLM.
    static func testMultiTurnRestore(apiKey: String, model: String, baseURL: String) async {
        let store = SessionStore()
        let sessionId = "e2e-restore-multiturn-\(UUID().uuidString)"

        // Step 1: Save a multi-turn conversation
        let multiTurnMessages: [[String: Any]] = [
            ["role": "user", "content": "My name is Alice."],
            ["role": "assistant", "content": [["type": "text", "text": "Hello Alice! Nice to meet you."]] as [[String: Any]]],
            ["role": "user", "content": "I live in Tokyo."],
            ["role": "assistant", "content": [["type": "text", "text": "Tokyo is a wonderful city!"]] as [[String: Any]]],
        ]
        let metadata = PartialSessionMetadata(
            cwd: "/tmp",
            model: model,
            summary: "Multi-turn personal info test"
        )

        do {
            // Serialize messages for Sendable compliance when crossing actor boundary
            let messagesData = try JSONSerialization.data(withJSONObject: multiTurnMessages, options: [])
            guard let sendableMessages = try JSONSerialization.jsonObject(with: messagesData, options: []) as? [[String: Any]] else {
                fail("Session restore E2E: multi-turn session saved", "failed to deserialize messages")
                return
            }
            try await store.save(sessionId: sessionId, messages: sendableMessages, metadata: metadata)
            pass("Session restore E2E: multi-turn session saved (4 messages)")
        } catch {
            fail("Session restore E2E: multi-turn session saved", "threw: \(error)")
            return
        }

        // Step 2: Restore and ask a question that requires both name and location
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            maxTurns: 3,
            sessionStore: store,
            sessionId: sessionId
        )
        let agent = createAgent(options: options)

        let result = await agent.prompt("What is my name and where do I live?")

        // The response should reference both the name (Alice) and location (Tokyo)
        if result.status == .success {
            pass("Session restore E2E: multi-turn prompt succeeds")
        } else {
            fail("Session restore E2E: multi-turn prompt succeeds", "status: \(result.status)")
        }

        let responseText = result.text.lowercased()
        let mentionsName = responseText.contains("alice")
        let mentionsLocation = responseText.contains("tokyo")

        if mentionsName {
            pass("Session restore E2E: response references restored name (Alice)")
        } else {
            fail("Session restore E2E: response references restored name (Alice)",
                 "response: \(result.text.prefix(100))")
        }

        if mentionsLocation {
            pass("Session restore E2E: response references restored location (Tokyo)")
        } else {
            fail("Session restore E2E: response references restored location (Tokyo)",
                 "response: \(result.text.prefix(100))")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: sessionId)
    }
}

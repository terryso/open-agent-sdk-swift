import XCTest
@testable import OpenAgentSDK

// MARK: - MailboxStore Tests

/// ATDD RED PHASE: Tests for Story 4.1 -- MailboxStore Actor.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `TaskTypes.swift` is created in `Sources/OpenAgentSDK/Types/`
///   - `MailboxStore.swift` is created in `Sources/OpenAgentSDK/Stores/`
///   - `AgentMessage` struct is defined with from, to, content, timestamp, type
///   - `AgentMessageType` enum is defined with text, shutdownRequest, shutdownResponse, planApprovalResponse
///   - `MailboxStore` actor is defined with send, broadcast, read, hasMessages, clear, clearAll methods
/// TDD Phase: RED (feature not implemented yet)
final class MailboxStoreTests: XCTestCase {

    // MARK: - AC5: MailboxStore Message Delivery

    /// AC5 [P0]: Sending a message delivers it to the recipient's mailbox.
    func testSend_messageDeliveredToRecipient() async {
        // Given: a MailboxStore
        let store = MailboxStore()

        // When: sending a message from agent-1 to agent-2
        await store.send(from: "agent-1", to: "agent-2", content: "Hello agent-2")

        // Then: agent-2's mailbox contains the message
        let messages = await store.read(agentName: "agent-2")
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.from, "agent-1")
        XCTAssertEqual(messages.first?.to, "agent-2")
        XCTAssertEqual(messages.first?.content, "Hello agent-2")
        XCTAssertEqual(messages.first?.type, .text)
    }

    /// AC5 [P0]: Multiple messages sent to the same recipient are queued in order.
    func testSend_multipleMessages_queuedInOrder() async {
        // Given: a MailboxStore
        let store = MailboxStore()

        // When: sending multiple messages to agent-2
        await store.send(from: "agent-1", to: "agent-2", content: "First")
        await store.send(from: "agent-1", to: "agent-2", content: "Second")
        await store.send(from: "agent-1", to: "agent-2", content: "Third")

        // Then: messages are queued in send order
        let messages = await store.read(agentName: "agent-2")
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].content, "First")
        XCTAssertEqual(messages[1].content, "Second")
        XCTAssertEqual(messages[2].content, "Third")
    }

    /// AC5 [P0]: Reading from a mailbox returns all messages and clears it.
    func testRead_returnsAndClearsMessages() async {
        // Given: a MailboxStore with messages for agent-2
        let store = MailboxStore()
        await store.send(from: "agent-1", to: "agent-2", content: "Message 1")
        await store.send(from: "agent-1", to: "agent-2", content: "Message 2")

        // When: reading agent-2's mailbox
        let messages = await store.read(agentName: "agent-2")

        // Then: all messages are returned
        XCTAssertEqual(messages.count, 2)

        // And: subsequent read returns empty (mailbox was cleared)
        let secondRead = await store.read(agentName: "agent-2")
        XCTAssertTrue(secondRead.isEmpty)
    }

    /// AC5 [P0]: Reading from an empty mailbox returns an empty array.
    func testRead_emptyMailbox_returnsEmpty() async {
        // Given: a fresh MailboxStore
        let store = MailboxStore()

        // When: reading from an agent that has no mailbox
        let messages = await store.read(agentName: "unknown-agent")

        // Then: returns empty array (not an error)
        XCTAssertTrue(messages.isEmpty)
    }

    // MARK: - AC5: MailboxStore Broadcast

    /// AC5 [P0]: Broadcasting delivers a message to all known mailboxes.
    func testBroadcast_deliversToAllMailboxes() async {
        // Given: a MailboxStore with known agents (mailboxes created by prior sends)
        let store = MailboxStore()
        await store.send(from: "system", to: "agent-1", content: "init")
        await store.send(from: "system", to: "agent-2", content: "init")
        await store.send(from: "system", to: "agent-3", content: "init")

        // Clear initialization messages
        _ = await store.read(agentName: "agent-1")
        _ = await store.read(agentName: "agent-2")
        _ = await store.read(agentName: "agent-3")

        // When: broadcasting a message
        await store.broadcast(from: "coordinator", content: "All hands on deck")

        // Then: all known agents receive the broadcast
        let msgs1 = await store.read(agentName: "agent-1")
        let msgs2 = await store.read(agentName: "agent-2")
        let msgs3 = await store.read(agentName: "agent-3")

        XCTAssertEqual(msgs1.count, 1)
        XCTAssertEqual(msgs2.count, 1)
        XCTAssertEqual(msgs3.count, 1)

        XCTAssertEqual(msgs1.first?.content, "All hands on deck")
        XCTAssertEqual(msgs2.first?.content, "All hands on deck")
        XCTAssertEqual(msgs3.first?.content, "All hands on deck")

        XCTAssertEqual(msgs1.first?.from, "coordinator")
        XCTAssertEqual(msgs1.first?.type, .text)
    }

    // MARK: - AC5: MailboxStore hasMessages

    /// AC5 [P0]: hasMessages returns true when the agent has pending messages.
    func testHasMessages_withMessages_returnsTrue() async {
        // Given: a MailboxStore with a message for agent-1
        let store = MailboxStore()
        await store.send(from: "agent-2", to: "agent-1", content: "Hello")

        // When: checking if agent-1 has messages
        let hasMessages = await store.hasMessages(for: "agent-1")

        // Then: returns true
        XCTAssertTrue(hasMessages)
    }

    /// AC5 [P0]: hasMessages returns false when the agent has no messages.
    func testHasMessages_noMessages_returnsFalse() async {
        // Given: a fresh MailboxStore
        let store = MailboxStore()

        // When: checking an agent with no messages
        let hasMessages = await store.hasMessages(for: "agent-1")

        // Then: returns false
        XCTAssertFalse(hasMessages)
    }

    // MARK: - AC5: MailboxStore Clear

    /// AC5 [P1]: Clearing a specific agent's mailbox only affects that mailbox.
    func testClearAgent_clearsOnlyTargetMailbox() async {
        // Given: a MailboxStore with messages for two agents
        let store = MailboxStore()
        await store.send(from: "system", to: "agent-1", content: "For agent-1")
        await store.send(from: "system", to: "agent-2", content: "For agent-2")

        // When: clearing only agent-1's mailbox
        await store.clear(agentName: "agent-1")

        // Then: agent-1's mailbox is empty
        let msgs1 = await store.read(agentName: "agent-1")
        XCTAssertTrue(msgs1.isEmpty)

        // And: agent-2's mailbox is unaffected
        let msgs2 = await store.read(agentName: "agent-2")
        XCTAssertEqual(msgs2.count, 1)
        XCTAssertEqual(msgs2.first?.content, "For agent-2")
    }

    /// AC5 [P1]: Clearing all mailboxes empties everything.
    func testClearAll_clearsEverything() async {
        // Given: a MailboxStore with messages for multiple agents
        let store = MailboxStore()
        await store.send(from: "system", to: "agent-1", content: "Msg 1")
        await store.send(from: "system", to: "agent-2", content: "Msg 2")
        await store.send(from: "system", to: "agent-3", content: "Msg 3")

        // When: clearing all mailboxes
        await store.clearAll()

        // Then: all mailboxes are empty
        let msgs1 = await store.read(agentName: "agent-1")
        let msgs2 = await store.read(agentName: "agent-2")
        let msgs3 = await store.read(agentName: "agent-3")

        XCTAssertTrue(msgs1.isEmpty)
        XCTAssertTrue(msgs2.isEmpty)
        XCTAssertTrue(msgs3.isEmpty)
    }

    // MARK: - AC4: MailboxStore Actor Thread Safety

    /// AC4 [P0]: Concurrent access to MailboxStore does not crash (actor isolation).
    func testMailboxStore_concurrentAccess() async {
        // Given: a MailboxStore
        let store = MailboxStore()

        // Pre-create mailboxes
        await store.send(from: "init", to: "agent-1", content: "init")
        await store.send(from: "init", to: "agent-2", content: "init")
        _ = await store.read(agentName: "agent-1")
        _ = await store.read(agentName: "agent-2")

        // When: sending messages concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 1...50 {
                group.addTask {
                    await store.send(from: "sender-\(i)", to: "agent-1", content: "Msg \(i)")
                }
            }
            for i in 1...50 {
                group.addTask {
                    await store.send(from: "sender-\(i)", to: "agent-2", content: "Msg \(i)")
                }
            }
        }

        // Then: all messages were delivered without crash
        let msgs1 = await store.read(agentName: "agent-1")
        let msgs2 = await store.read(agentName: "agent-2")
        XCTAssertEqual(msgs1.count, 50)
        XCTAssertEqual(msgs2.count, 50)
    }

    // MARK: - Ghost Entry Regression Tests

    /// Reading from a nonexistent agent should NOT create a ghost mailbox entry.
    /// After reading from "unknown", broadcasting should NOT deliver to "unknown".
    func testRead_nonexistentAgent_doesNotCreateGhostEntry() async {
        // Given: a MailboxStore with a known agent
        let store = MailboxStore()
        await store.send(from: "system", to: "agent-1", content: "init")

        // When: reading from an unknown agent (should not create entry)
        _ = await store.read(agentName: "ghost-agent")

        // And: broadcasting a message
        await store.broadcast(from: "system", content: "broadcast")

        // Then: agent-1 receives the broadcast but ghost-agent does not
        let msgs1 = await store.read(agentName: "agent-1")
        let msgsGhost = await store.read(agentName: "ghost-agent")

        XCTAssertEqual(msgs1.count, 2) // init + broadcast
        XCTAssertTrue(msgsGhost.isEmpty) // ghost-agent should have no mailbox
    }

    /// Clearing a nonexistent agent should NOT create a ghost mailbox entry.
    func testClear_nonexistentAgent_doesNotCreateGhostEntry() async {
        // Given: a MailboxStore with a known agent
        let store = MailboxStore()
        await store.send(from: "system", to: "agent-1", content: "init")

        // When: clearing a nonexistent agent's mailbox
        await store.clear(agentName: "ghost-agent")

        // And: broadcasting a message
        await store.broadcast(from: "system", content: "broadcast")

        // Then: agent-1 receives the broadcast but ghost-agent does not
        let msgs1 = await store.read(agentName: "agent-1")
        let msgsGhost = await store.read(agentName: "ghost-agent")

        XCTAssertEqual(msgs1.count, 2) // init + broadcast
        XCTAssertTrue(msgsGhost.isEmpty)
    }
}

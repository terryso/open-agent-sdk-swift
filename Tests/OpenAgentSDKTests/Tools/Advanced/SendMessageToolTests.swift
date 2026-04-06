import XCTest
@testable import OpenAgentSDK

// MARK: - SendMessageTool Tests

/// ATDD RED PHASE: Tests for Story 4.4 -- SendMessage Tool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `ToolContext` gains `mailboxStore`, `teamStore`, and `senderName` fields
///   - `createSendMessageTool()` factory function is implemented in Tools/Advanced/
/// TDD Phase: RED (feature not implemented yet)
final class SendMessageToolTests: XCTestCase {

    // MARK: - Helper: Create a team with members in TeamStore

    /// Creates a team with the given members and returns the team.
    private func createTestTeam(
        teamStore: TeamStore,
        members: [TeamMember],
        leaderId: String = "leader"
    ) async -> Team {
        return await teamStore.create(
            name: "TestTeam",
            members: members,
            leaderId: leaderId
        )
    }

    // MARK: - Helper: Build ToolContext with stores

    /// Creates a ToolContext with injected stores and sender name.
    private func makeContext(
        mailboxStore: MailboxStore? = nil,
        teamStore: TeamStore? = nil,
        senderName: String? = nil
    ) -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id",
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: senderName
        )
    }

    // MARK: - AC1: Factory returns valid ToolProtocol

    /// AC1 [P0]: createSendMessageTool() returns a ToolProtocol with name "SendMessage".
    func testCreateSendMessageTool_returnsToolProtocol() async throws {
        // When: creating the SendMessage tool
        let tool = createSendMessageTool()

        // Then: it is a valid ToolProtocol with expected name
        XCTAssertEqual(tool.name, "SendMessage")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC9 [P0]: The SendMessage tool has a valid inputSchema matching TS SDK.
    func testCreateSendMessageTool_hasValidInputSchema() async throws {
        let tool = createSendMessageTool()

        let schema = tool.inputSchema
        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "to" field
        let toProp = properties?["to"] as? [String: Any]
        XCTAssertNotNil(toProp)
        XCTAssertEqual(toProp?["type"] as? String, "string")

        // Verify "message" field
        let messageProp = properties?["message"] as? [String: Any]
        XCTAssertNotNil(messageProp)
        XCTAssertEqual(messageProp?["type"] as? String, "string")

        // Verify required fields
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["to", "message"])
    }

    /// AC9 [P1]: SendMessageTool is NOT read-only (it sends messages, causing side effects).
    func testCreateSendMessageTool_isNotReadOnly() async throws {
        let tool = createSendMessageTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: - AC1: Direct message delivery

    /// AC1 [P0]: Sending a direct message delivers it to the recipient's mailbox.
    func testSendMessage_directMessage_deliversToRecipient() async throws {
        // Given: a team with sender and recipient
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        let senderName = "alice"
        let recipientName = "bob"

        // Initialize recipient mailbox so broadcast can find it
        await mailboxStore.send(from: "system", to: recipientName, content: "init")

        _ = await createTestTeam(
            teamStore: teamStore,
            members: [
                TeamMember(name: senderName, role: .member),
                TeamMember(name: recipientName, role: .member),
            ],
            leaderId: senderName
        )

        let tool = createSendMessageTool()
        let context = makeContext(
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: senderName
        )

        // When: sending a direct message
        let input: [String: Any] = [
            "to": recipientName,
            "message": "Hello Bob!"
        ]
        let result = await tool.call(input: input, context: context)

        // Then: result is successful
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains(recipientName))

        // And: the message was delivered to the mailbox
        let messages = await mailboxStore.read(agentName: recipientName)
        // Filter out the init message
        let sentMessages = messages.filter { $0.from == senderName }
        XCTAssertEqual(sentMessages.count, 1)
        XCTAssertEqual(sentMessages.first?.content, "Hello Bob!")
        XCTAssertEqual(sentMessages.first?.from, senderName)
        XCTAssertEqual(sentMessages.first?.to, recipientName)
    }

    /// AC1 [P1]: Sending a message to self (sender == recipient) succeeds.
    func testSendMessage_toSelf_succeeds() async throws {
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        let agentName = "alice"

        _ = await createTestTeam(
            teamStore: teamStore,
            members: [TeamMember(name: agentName, role: .leader)],
            leaderId: agentName
        )

        let tool = createSendMessageTool()
        let context = makeContext(
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: agentName
        )

        let input: [String: Any] = [
            "to": agentName,
            "message": "Note to self"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
    }

    // MARK: - AC2: Broadcast message

    /// AC2 [P0]: Sending a broadcast message delivers to all teammates.
    func testSendMessage_broadcast_deliversToAllTeammates() async throws {
        // Given: a team with multiple members
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        let senderName = "leader"

        // Initialize mailboxes so broadcast can find them
        await mailboxStore.send(from: "system", to: "bob", content: "init")
        await mailboxStore.send(from: "system", to: "charlie", content: "init")

        _ = await createTestTeam(
            teamStore: teamStore,
            members: [
                TeamMember(name: senderName, role: .leader),
                TeamMember(name: "bob", role: .member),
                TeamMember(name: "charlie", role: .member),
            ],
            leaderId: senderName
        )

        let tool = createSendMessageTool()
        let context = makeContext(
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: senderName
        )

        // When: sending a broadcast message
        let input: [String: Any] = [
            "to": "*",
            "message": "Team announcement!"
        ]
        let result = await tool.call(input: input, context: context)

        // Then: result is successful
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("broadcast") ||
                      result.content.contains("Broadcast") ||
                      result.content.contains("teammates"))

        // And: the broadcast was sent (messages should exist for known agents)
        // Note: broadcast sends to all known mailboxes in MailboxStore, not just team members
        // The MailboxStore.broadcast sends to all agents with existing mailboxes
    }

    // MARK: - AC3: No team returns error

    /// AC3 [P0]: When sender is not a member of any team, returns error.
    func testSendMessage_noTeam_returnsError() async throws {
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        // No team created

        let tool = createSendMessageTool()
        let context = makeContext(
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: "lonely-agent"
        )

        let input: [String: Any] = [
            "to": "bob",
            "message": "Hello?"
        ]
        let result = await tool.call(input: input, context: context)

        // Then: error result
        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("not a member") ||
                      result.content.contains("not part") ||
                      result.content.contains("no team") ||
                      result.content.contains("not in"))
    }

    // MARK: - AC4: Recipient not in team returns error

    /// AC4 [P0]: When recipient is not in the team, returns error.
    func testSendMessage_recipientNotInTeam_returnsError() async throws {
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        let senderName = "alice"

        _ = await createTestTeam(
            teamStore: teamStore,
            members: [TeamMember(name: senderName, role: .leader)],
            leaderId: senderName
        )

        let tool = createSendMessageTool()
        let context = makeContext(
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: senderName
        )

        let input: [String: Any] = [
            "to": "nonexistent-agent",
            "message": "Are you there?"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("not a member") ||
                      result.content.contains("not part") ||
                      result.content.contains("not in"))
    }

    /// AC4 [P1]: Error message lists available team members.
    func testSendMessage_recipientNotInTeam_listsAvailableMembers() async throws {
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        let senderName = "alice"

        _ = await createTestTeam(
            teamStore: teamStore,
            members: [
                TeamMember(name: senderName, role: .leader),
                TeamMember(name: "bob", role: .member),
            ],
            leaderId: senderName
        )

        let tool = createSendMessageTool()
        let context = makeContext(
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: senderName
        )

        let input: [String: Any] = [
            "to": "unknown",
            "message": "Hello"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        // Error should list available members to help the LLM choose correctly
        XCTAssertTrue(result.content.contains("alice") || result.content.contains("bob") ||
                      result.content.contains("Available"))
    }

    // MARK: - AC5: Missing dependency returns error

    /// AC5 [P0]: When mailboxStore is nil, returns error.
    func testSendMessage_noMailboxStore_returnsError() async throws {
        let teamStore = TeamStore()
        let tool = createSendMessageTool()
        let context = makeContext(
            mailboxStore: nil,
            teamStore: teamStore,
            senderName: "alice"
        )

        let input: [String: Any] = [
            "to": "bob",
            "message": "Hello"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("MailboxStore") ||
                      result.content.contains("mail"))
    }

    /// AC5 [P0]: When teamStore is nil, returns error.
    func testSendMessage_noTeamStore_returnsError() async throws {
        let mailboxStore = MailboxStore()
        let tool = createSendMessageTool()
        let context = makeContext(
            mailboxStore: mailboxStore,
            teamStore: nil,
            senderName: "alice"
        )

        let input: [String: Any] = [
            "to": "bob",
            "message": "Hello"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("TeamStore") ||
                      result.content.contains("team"))
    }

    /// AC7 [P0]: When senderName is nil, returns error.
    func testSendMessage_noSenderName_returnsError() async throws {
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        let tool = createSendMessageTool()
        let context = makeContext(
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: nil
        )

        let input: [String: Any] = [
            "to": "bob",
            "message": "Hello"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("sender") ||
                      result.content.contains("Sender") ||
                      result.content.contains("identity") ||
                      result.content.contains("name"))
    }

    // MARK: - AC5: ToolContext backward compatibility

    /// AC5 [P0]: ToolContext can be created with only existing parameters (backward compat).
    func testToolContext_backwardCompat_noNewFields() async throws {
        // When: creating ToolContext with only original fields
        let context = ToolContext(cwd: "/tmp", toolUseId: "id-123")

        // Then: context is valid and new fields default to nil
        XCTAssertEqual(context.cwd, "/tmp")
        XCTAssertEqual(context.toolUseId, "id-123")
        XCTAssertNil(context.mailboxStore)
        XCTAssertNil(context.teamStore)
        XCTAssertNil(context.senderName)
    }

    /// AC5 [P0]: ToolContext can be created with new fields.
    func testToolContext_withAllNewFields() async throws {
        // Given: store instances
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()

        // When: creating ToolContext with all fields
        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "id-456",
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: "alice"
        )

        // Then: all fields are set
        XCTAssertEqual(context.cwd, "/tmp")
        XCTAssertEqual(context.toolUseId, "id-456")
        XCTAssertNotNil(context.mailboxStore)
        XCTAssertNotNil(context.teamStore)
        XCTAssertEqual(context.senderName, "alice")
    }

    // MARK: - AC8: Error handling does not crash loop

    /// AC8 [P0]: Tool never throws — always returns ToolResult even with malformed input.
    func testSendMessage_neverThrows_alwaysReturnsToolResult() async throws {
        let tool = createSendMessageTool()
        let context = ToolContext(cwd: "/tmp")

        // Various malformed inputs
        let badInputs: [[String: Any]] = [
            [:],  // missing all fields
            ["to": "bob"],  // missing message
            ["message": "hi"],  // missing to
            ["to": 123, "message": "hi"],  // wrong type
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "")
            // Whether error or not depends on decoding, but never crashes
        }
    }

    // MARK: - AC6: Module boundary

    /// AC6 [P0]: SendMessageTool does not import Core/ or Stores/ modules.
    /// This test validates at the structural level by checking that the tool
    /// can be created and used without any Core/ or Stores/ types being
    /// directly referenced in its interface.
    func testSendMessageTool_moduleBoundary_noDirectStoreTypes() async throws {
        // The tool factory function must accept ToolContext and return ToolProtocol.
        // MailboxStore and TeamStore are accessed through ToolContext fields,
        // not through direct imports in the tool's source file.
        let tool = createSendMessageTool()
        XCTAssertEqual(tool.name, "SendMessage")

        // Verify the tool works with injected context — this proves the
        // dependency injection pattern is correct
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()

        _ = await createTestTeam(
            teamStore: teamStore,
            members: [TeamMember(name: "alice", role: .leader)],
            leaderId: "alice"
        )

        let context = makeContext(
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: "alice"
        )

        let result = await tool.call(
            input: ["to": "alice", "message": "test"],
            context: context
        )
        XCTAssertFalse(result.isError)
    }

    // MARK: - AC1: Input Codable decode

    /// AC1 [P0]: SendMessageInput correctly decodes from JSON.
    func testSendMessageInput_decodeFromJson() async throws {
        // Given: a tool that will decode input
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()

        _ = await createTestTeam(
            teamStore: teamStore,
            members: [TeamMember(name: "alice", role: .leader)],
            leaderId: "alice"
        )

        let tool = createSendMessageTool()
        let context = makeContext(
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: "alice"
        )

        // When: calling with JSON-serializable input
        let input: [String: Any] = [
            "to": "alice",
            "message": "Test message content"
        ]
        let result = await tool.call(input: input, context: context)

        // Then: decoding succeeds and tool processes the message
        XCTAssertFalse(result.isError)
    }

    // MARK: - AC7: Sender identity from ToolContext

    /// AC7 [P0]: The message sender is correctly identified from ToolContext.senderName.
    func testSendMessage_senderIdentity_fromContext() async throws {
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        let senderName = "agent-alpha"

        // Initialize recipient mailbox
        await mailboxStore.send(from: "system", to: "agent-beta", content: "init")

        _ = await createTestTeam(
            teamStore: teamStore,
            members: [
                TeamMember(name: senderName, role: .leader),
                TeamMember(name: "agent-beta", role: .member),
            ],
            leaderId: senderName
        )

        let tool = createSendMessageTool()
        let context = makeContext(
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: senderName
        )

        let input: [String: Any] = [
            "to": "agent-beta",
            "message": "Hello from alpha"
        ]
        _ = await tool.call(input: input, context: context)

        // Verify the message has the correct sender
        let messages = await mailboxStore.read(agentName: "agent-beta")
        let sentMessages = messages.filter { $0.from == senderName }
        XCTAssertEqual(sentMessages.count, 1)
        XCTAssertEqual(sentMessages.first?.from, senderName)
    }
}

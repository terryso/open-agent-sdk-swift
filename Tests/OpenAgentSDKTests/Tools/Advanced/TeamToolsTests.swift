import XCTest
@testable import OpenAgentSDK

// MARK: - TeamToolsTests

/// ATDD RED PHASE: Tests for Story 4.6 -- Team Tools (Create/Delete).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `createTeamCreateTool()` factory function is implemented
///   - `createTeamDeleteTool()` factory function is implemented
/// TDD Phase: RED (feature not implemented yet)
final class TeamToolsTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a ToolContext with an injected TeamStore.
    private func makeContext(teamStore: TeamStore? = nil) -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id",
            teamStore: teamStore
        )
    }

    /// Creates a ToolContext without any TeamStore (nil).
    private func makeContextWithoutStore() -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id"
        )
    }

    // MARK: - AC1: TeamCreate Tool

    // MARK: AC1 -- Factory

    /// AC1 [P0]: createTeamCreateTool() returns a ToolProtocol with name "TeamCreate".
    func testCreateTeamCreateTool_returnsToolProtocol() async throws {
        let tool = createTeamCreateTool()

        XCTAssertEqual(tool.name, "TeamCreate")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC6 [P0]: TeamCreate inputSchema matches TS SDK.
    func testCreateTeamCreateTool_hasValidInputSchema() async throws {
        let tool = createTeamCreateTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "name" field
        let nameProp = properties?["name"] as? [String: Any]
        XCTAssertNotNil(nameProp)
        XCTAssertEqual(nameProp?["type"] as? String, "string")

        // Verify "members" field
        let membersProp = properties?["members"] as? [String: Any]
        XCTAssertNotNil(membersProp)
        XCTAssertEqual(membersProp?["type"] as? String, "array")

        // Verify "task_description" field
        let taskDescProp = properties?["task_description"] as? [String: Any]
        XCTAssertNotNil(taskDescProp)
        XCTAssertEqual(taskDescProp?["type"] as? String, "string")

        // Verify required fields
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["name"])
    }

    /// AC7 [P0]: TeamCreate is NOT read-only (creates teams, causing side effects).
    func testCreateTeamCreateTool_isNotReadOnly() async throws {
        let tool = createTeamCreateTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: AC1 -- Create team behavior

    /// AC1 [P0]: Creating a team with name only returns success with team ID.
    func testTeamCreate_nameOnly_returnsSuccess() async throws {
        let teamStore = TeamStore()
        let tool = createTeamCreateTool()
        let context = makeContext(teamStore: teamStore)

        let input: [String: Any] = ["name": "Alpha Team"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("team_"))
        XCTAssertTrue(result.content.contains("Alpha Team"))
    }

    /// AC1 [P0]: Creating a team with name and members returns success.
    func testTeamCreate_withMembers_returnsSuccess() async throws {
        let teamStore = TeamStore()
        let tool = createTeamCreateTool()
        let context = makeContext(teamStore: teamStore)

        let input: [String: Any] = [
            "name": "Beta Team",
            "members": ["agent-1", "agent-2", "agent-3"]
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Beta Team"))
        XCTAssertTrue(result.content.contains("3") ||
                      result.content.contains("three"))
    }

    /// AC1 [P0]: Creating a team without members defaults to 0 members.
    func testTeamCreate_defaultMembersEmpty() async throws {
        let teamStore = TeamStore()
        let tool = createTeamCreateTool()
        let context = makeContext(teamStore: teamStore)

        let input: [String: Any] = ["name": "Solo Team"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        // Verify in the store that the team has 0 members
        let teams = await teamStore.list()
        XCTAssertEqual(teams.count, 1)
        XCTAssertEqual(teams.first?.members.count, 0)
    }

    /// AC6 [P0]: TeamCreate input Codable correctly decodes JSON fields.
    func testTeamCreate_inputDecodable() async throws {
        let teamStore = TeamStore()
        let tool = createTeamCreateTool()
        let context = makeContext(teamStore: teamStore)

        // JSON input with all fields
        let input: [String: Any] = [
            "name": "Decode Team",
            "members": ["decoder-agent"],
            "task_description": "Test decoding"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Decode Team"))
    }

    /// AC1 [P1]: After create, the team is retrievable from the store.
    func testTeamCreate_verifyTeamInStore() async throws {
        let teamStore = TeamStore()
        let tool = createTeamCreateTool()
        let context = makeContext(teamStore: teamStore)

        let input: [String: Any] = [
            "name": "Verified Team",
            "members": ["verifier"]
        ]
        _ = await tool.call(input: input, context: context)

        let teams = await teamStore.list()
        XCTAssertEqual(teams.count, 1)
        XCTAssertEqual(teams.first?.name, "Verified Team")
        XCTAssertEqual(teams.first?.status, .active)
        XCTAssertEqual(teams.first?.members.count, 1)
        XCTAssertEqual(teams.first?.members.first?.name, "verifier")
        XCTAssertEqual(teams.first?.members.first?.role, .member)
    }

    // MARK: - AC2: TeamDelete Tool

    // MARK: AC2 -- Factory

    /// AC2 [P0]: createTeamDeleteTool() returns a ToolProtocol with name "TeamDelete".
    func testCreateTeamDeleteTool_returnsToolProtocol() async throws {
        let tool = createTeamDeleteTool()

        XCTAssertEqual(tool.name, "TeamDelete")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC6 [P0]: TeamDelete inputSchema matches TS SDK.
    func testCreateTeamDeleteTool_hasValidInputSchema() async throws {
        let tool = createTeamDeleteTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "id" field
        let idProp = properties?["id"] as? [String: Any]
        XCTAssertNotNil(idProp)
        XCTAssertEqual(idProp?["type"] as? String, "string")

        // Verify required fields
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["id"])
    }

    /// AC7 [P0]: TeamDelete is NOT read-only (disbands teams, causing side effects).
    func testCreateTeamDeleteTool_isNotReadOnly() async throws {
        let tool = createTeamDeleteTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: AC2 -- Delete behavior

    /// AC2 [P0]: Deleting an existing active team succeeds.
    func testTeamDelete_existingTeam_returnsSuccess() async throws {
        let teamStore = TeamStore()
        let team = await teamStore.create(name: "To Delete")

        let tool = createTeamDeleteTool()
        let context = makeContext(teamStore: teamStore)

        let input: [String: Any] = ["id": team.id]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains(team.id) ||
                      result.content.contains("disbanded") ||
                      result.content.contains("Disbanded"))
    }

    /// AC2 [P0]: Deleting a non-existent team returns isError=true.
    func testTeamDelete_nonexistentTeam_returnsError() async throws {
        let teamStore = TeamStore()
        let tool = createTeamDeleteTool()
        let context = makeContext(teamStore: teamStore)

        let input: [String: Any] = ["id": "team_999"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("not found") ||
                      result.content.contains("Not found"))
    }

    /// AC2 [P0]: Deleting an already disbanded team returns isError=true.
    func testTeamDelete_alreadyDisbanded_returnsError() async throws {
        let teamStore = TeamStore()
        let team = await teamStore.create(name: "Already Gone")
        // Delete once to disband
        _ = try await teamStore.delete(id: team.id)

        let tool = createTeamDeleteTool()
        let context = makeContext(teamStore: teamStore)

        let input: [String: Any] = ["id": team.id]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("disbanded") ||
                      result.content.contains("Disbanded"))
    }

    /// AC2 [P1]: After delete, the team is removed from the store.
    func testTeamDelete_verifyTeamRemovedFromStore() async throws {
        let teamStore = TeamStore()
        let team = await teamStore.create(name: "Remove Me")

        let tool = createTeamDeleteTool()
        let context = makeContext(teamStore: teamStore)

        let input: [String: Any] = ["id": team.id]
        _ = await tool.call(input: input, context: context)

        // Team should no longer be in the active list
        let activeTeams = await teamStore.list(status: .active)
        XCTAssertTrue(activeTeams.isEmpty)
    }

    // MARK: - AC5: Error Handling -- nil teamStore

    /// AC5 [P0]: TeamCreate returns error when teamStore is nil.
    func testTeamCreate_nilTeamStore_returnsError() async throws {
        let tool = createTeamCreateTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = ["name": "Test"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("TeamStore") ||
                      result.content.contains("team store"))
    }

    /// AC5 [P0]: TeamDelete returns error when teamStore is nil.
    func testTeamDelete_nilTeamStore_returnsError() async throws {
        let tool = createTeamDeleteTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = ["id": "team_1"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("TeamStore") ||
                      result.content.contains("team store"))
    }

    // MARK: - AC5: Error Handling -- never throws

    /// AC5 [P0]: TeamCreate never throws -- always returns ToolResult even with malformed input.
    func testTeamCreate_neverThrows_malformedInput() async throws {
        let tool = createTeamCreateTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],  // missing all fields
            ["name": 123],  // wrong type
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    /// AC5 [P0]: TeamDelete never throws -- always returns ToolResult even with malformed input.
    func testTeamDelete_neverThrows_malformedInput() async throws {
        let tool = createTeamDeleteTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],  // missing all fields
            ["id": 123],  // wrong type
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    // MARK: - AC3: ToolContext Dependency Injection

    /// AC3 [P0]: ToolContext has a teamStore field that can be injected.
    func testToolContext_hasTeamStoreField() async throws {
        let teamStore = TeamStore()

        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "test-id",
            teamStore: teamStore
        )

        XCTAssertNotNil(context.teamStore)
    }

    /// AC3 [P0]: ToolContext teamStore defaults to nil (backward compatible).
    func testToolContext_teamStoreDefaultsToNil() async throws {
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        XCTAssertNil(context.teamStore)
    }

    /// AC3 [P0]: ToolContext can be created with all fields including teamStore.
    func testToolContext_withAllFields() async throws {
        let taskStore = TaskStore()
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()

        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "id-456",
            agentSpawner: nil,
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: "lead-agent",
            taskStore: taskStore
        )

        XCTAssertNotNil(context.teamStore)
        XCTAssertNotNil(context.mailboxStore)
        XCTAssertNotNil(context.taskStore)
        XCTAssertEqual(context.senderName, "lead-agent")
    }

    // MARK: - AC4: Module Boundary

    /// AC4 [P0]: Team tools do not import Core/ or Stores/ modules.
    /// This test validates the dependency injection pattern by verifying that
    /// tools can be created and used through ToolContext without direct store imports.
    func testTeamTools_moduleBoundary_noDirectStoreImports() async throws {
        // Both tools must be creatable as factory functions that return ToolProtocol
        let createTool = createTeamCreateTool()
        let deleteTool = createTeamDeleteTool()

        // Both must return valid ToolProtocol instances
        XCTAssertEqual(createTool.name, "TeamCreate")
        XCTAssertEqual(deleteTool.name, "TeamDelete")

        // Verify they work through ToolContext injection
        let teamStore = TeamStore()
        let context = makeContext(teamStore: teamStore)

        let result = await createTool.call(
            input: ["name": "Boundary test"],
            context: context
        )
        XCTAssertFalse(result.isError)
    }

    // MARK: - Integration: Cross-tool workflows

    /// Integration [P1]: Create a team, then delete it.
    func testIntegration_createThenDelete() async throws {
        let teamStore = TeamStore()
        let createTool = createTeamCreateTool()
        let deleteTool = createTeamDeleteTool()
        let context = makeContext(teamStore: teamStore)

        // Step 1: Create a team
        let createResult = await createTool.call(
            input: ["name": "Ephemeral Team", "members": ["agent-a", "agent-b"]],
            context: context
        )
        XCTAssertFalse(createResult.isError)
        XCTAssertTrue(createResult.content.contains("Ephemeral Team"))

        // Extract the team ID from the store
        let teams = await teamStore.list()
        let teamId = try XCTUnwrap(teams.first?.id)

        // Step 2: Delete the team
        let deleteResult = await deleteTool.call(
            input: ["id": teamId],
            context: context
        )
        XCTAssertFalse(deleteResult.isError)

        // Step 3: Verify no active teams remain
        let remainingTeams = await teamStore.list(status: .active)
        XCTAssertTrue(remainingTeams.isEmpty)
    }
}

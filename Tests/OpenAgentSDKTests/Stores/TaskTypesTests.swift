import XCTest
@testable import OpenAgentSDK

// MARK: - TaskTypes Tests

/// ATDD RED PHASE: Tests for Story 4.1 -- Type Definitions (AC6).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `TaskTypes.swift` is created in `Sources/OpenAgentSDK/Types/`
///   - `TaskStatus` enum is defined with all required cases
///   - `Task` struct is defined with all required fields
///   - `AgentMessage` struct is defined with all required fields
///   - `AgentMessageType` enum is defined with all required cases
/// TDD Phase: RED (feature not implemented yet)
final class TaskTypesTests: XCTestCase {

    // MARK: - AC6: TaskStatus enum

    /// AC6 [P0]: TaskStatus enum has all required cases and is CaseIterable.
    func testTaskStatus_isCaseIterable() {
        // Given: the TaskStatus enum
        // Then: it has exactly 5 cases
        XCTAssertEqual(TaskStatus.allCases.count, 5)

        // And: all required cases exist
        let expectedRawValues: Set<String> = ["pending", "inProgress", "completed", "failed", "cancelled"]
        let actualRawValues = Set(TaskStatus.allCases.map { $0.rawValue })
        XCTAssertEqual(actualRawValues, expectedRawValues)
    }

    // MARK: - AC6: Task struct

    /// AC6 [P0]: Task struct has all required fields.
    func testTask_hasRequiredFields() {
        // Given: a Task instance
        let task = Task(
            id: "task_1",
            subject: "Test task",
            description: "A test",
            status: .pending,
            owner: "agent-1",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )

        // Then: all required fields are accessible
        XCTAssertEqual(task.id, "task_1")
        XCTAssertEqual(task.subject, "Test task")
        XCTAssertEqual(task.description, "A test")
        XCTAssertEqual(task.status, .pending)
        XCTAssertEqual(task.owner, "agent-1")
        XCTAssertEqual(task.createdAt, "2026-01-01T00:00:00Z")
        XCTAssertEqual(task.updatedAt, "2026-01-01T00:00:00Z")
    }

    /// AC6 [P0]: Task conforms to Sendable.
    func testTask_implementsSendable() {
        // Given: a Task instance
        let task = Task(
            id: "task_1",
            subject: "Sendable test",
            status: .pending,
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )

        // Then: Task can be used in a Sendable context (compiles)
        // This test verifies Sendable conformance at compile time
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(task)
    }

    // MARK: - AC6: AgentMessage struct

    /// AC6 [P0]: AgentMessage struct has all required fields.
    func testAgentMessage_hasRequiredFields() {
        // Given: an AgentMessage instance
        let message = AgentMessage(
            from: "agent-1",
            to: "agent-2",
            content: "Hello",
            timestamp: "2026-01-01T00:00:00Z",
            type: .text
        )

        // Then: all required fields are accessible
        XCTAssertEqual(message.from, "agent-1")
        XCTAssertEqual(message.to, "agent-2")
        XCTAssertEqual(message.content, "Hello")
        XCTAssertEqual(message.timestamp, "2026-01-01T00:00:00Z")
        XCTAssertEqual(message.type, .text)
    }

    // MARK: - AC6: AgentMessageType enum

    /// AC6 [P0]: AgentMessageType enum has all required cases.
    func testAgentMessageType_hasAllCases() {
        // Given: the AgentMessageType enum
        // Then: all required cases exist and compile
        let text = AgentMessageType.text
        let shutdownRequest = AgentMessageType.shutdownRequest
        let shutdownResponse = AgentMessageType.shutdownResponse
        let planApprovalResponse = AgentMessageType.planApprovalResponse

        // And: raw values match expected strings
        XCTAssertEqual(text.rawValue, "text")
        XCTAssertEqual(shutdownRequest.rawValue, "shutdownRequest")
        XCTAssertEqual(shutdownResponse.rawValue, "shutdownResponse")
        XCTAssertEqual(planApprovalResponse.rawValue, "planApprovalResponse")
    }

    // MARK: - AC6 (Story 4.2): TeamStatus enum

    /// AC6 [P0]: TeamStatus enum has all required cases and is CaseIterable.
    func testTeamStatus_allCases() {
        // Given: the TeamStatus enum
        // Then: it has exactly 2 cases
        XCTAssertEqual(TeamStatus.allCases.count, 2)

        // And: all required cases exist
        let expectedRawValues: Set<String> = ["active", "disbanded"]
        let actualRawValues = Set(TeamStatus.allCases.map { $0.rawValue })
        XCTAssertEqual(actualRawValues, expectedRawValues)
    }

    // MARK: - AC6 (Story 4.2): TeamRole enum

    /// AC6 [P0]: TeamRole enum has all required cases and is CaseIterable.
    func testTeamRole_allCases() {
        // Given: the TeamRole enum
        // Then: it has exactly 2 cases
        XCTAssertEqual(TeamRole.allCases.count, 2)

        // And: all required cases exist
        let expectedRawValues: Set<String> = ["leader", "member"]
        let actualRawValues = Set(TeamRole.allCases.map { $0.rawValue })
        XCTAssertEqual(actualRawValues, expectedRawValues)
    }

    // MARK: - AC6 (Story 4.2): Team struct

    /// AC6 [P0]: Team struct has all required fields and is Codable.
    func testTeam_hasRequiredFields() {
        // Given: a Team instance
        let team = Team(
            id: "team_1",
            name: "Test team",
            members: [TeamMember(name: "alice", role: .leader)],
            leaderId: "coordinator",
            createdAt: "2026-01-01T00:00:00.000Z",
            status: .active
        )

        // Then: all required fields are accessible
        XCTAssertEqual(team.id, "team_1")
        XCTAssertEqual(team.name, "Test team")
        XCTAssertEqual(team.members.count, 1)
        XCTAssertEqual(team.leaderId, "coordinator")
        XCTAssertEqual(team.createdAt, "2026-01-01T00:00:00.000Z")
        XCTAssertEqual(team.status, .active)
    }

    /// AC6 [P0]: Team struct is Codable (round-trip encoding/decoding).
    func testTeam_codableRoundTrip() throws {
        // Given: a Team instance
        let team = Team(
            id: "team_1",
            name: "Codable team",
            members: [
                TeamMember(name: "alice", role: .leader),
                TeamMember(name: "bob", role: .member)
            ],
            leaderId: "self",
            createdAt: "2026-01-01T00:00:00.000Z",
            status: .active
        )

        // When: encoding and decoding
        let data = try JSONEncoder().encode(team)
        let decoded = try JSONDecoder().decode(Team.self, from: data)

        // Then: the decoded team matches the original
        XCTAssertEqual(decoded, team)
    }

    /// AC6 [P0]: Team conforms to Sendable.
    func testTeam_implementsSendable() {
        // Given: a Team instance
        let team = Team(
            id: "team_1",
            name: "Sendable test",
            createdAt: "2026-01-01T00:00:00.000Z"
        )

        // Then: Team can be used in a Sendable context (compiles)
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(team)
    }

    // MARK: - AC6 (Story 4.2): TeamMember struct

    /// AC6 [P0]: TeamMember struct has all required fields.
    func testTeamMember_hasRequiredFields() {
        // Given: a TeamMember instance
        let member = TeamMember(name: "alice", role: .leader)

        // Then: fields are accessible
        XCTAssertEqual(member.name, "alice")
        XCTAssertEqual(member.role, .leader)
    }

    /// AC6 [P0]: TeamMember default role is member.
    func testTeamMember_defaultRoleIsMember() {
        // Given: a TeamMember created without specifying role
        let member = TeamMember(name: "bob")

        // Then: default role is .member
        XCTAssertEqual(member.role, .member)
    }

    /// AC6 [P0]: TeamMember is Codable (round-trip encoding/decoding).
    func testTeamMember_codableRoundTrip() throws {
        // Given: a TeamMember instance
        let member = TeamMember(name: "carol", role: .leader)

        // When: encoding and decoding
        let data = try JSONEncoder().encode(member)
        let decoded = try JSONDecoder().decode(TeamMember.self, from: data)

        // Then: the decoded member matches the original
        XCTAssertEqual(decoded, member)
    }

    // MARK: - AC6 (Story 4.2): AgentRegistryEntry struct

    /// AC6 [P0]: AgentRegistryEntry struct has all required fields.
    func testAgentRegistryEntry_hasRequiredFields() {
        // Given: an AgentRegistryEntry instance
        let entry = AgentRegistryEntry(
            agentId: "agent-001",
            name: "researcher",
            agentType: "Explore",
            registeredAt: "2026-01-01T00:00:00.000Z"
        )

        // Then: all required fields are accessible
        XCTAssertEqual(entry.agentId, "agent-001")
        XCTAssertEqual(entry.name, "researcher")
        XCTAssertEqual(entry.agentType, "Explore")
        XCTAssertEqual(entry.registeredAt, "2026-01-01T00:00:00.000Z")
    }

    /// AC6 [P0]: AgentRegistryEntry is Codable (round-trip encoding/decoding).
    func testAgentRegistryEntry_codableRoundTrip() throws {
        // Given: an AgentRegistryEntry instance
        let entry = AgentRegistryEntry(
            agentId: "agent-001",
            name: "researcher",
            agentType: "Explore",
            registeredAt: "2026-01-01T00:00:00.000Z"
        )

        // When: encoding and decoding
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(AgentRegistryEntry.self, from: data)

        // Then: the decoded entry matches the original
        XCTAssertEqual(decoded, entry)
    }

    /// AC6 [P0]: AgentRegistryEntry conforms to Sendable.
    func testAgentRegistryEntry_implementsSendable() {
        // Given: an AgentRegistryEntry instance
        let entry = AgentRegistryEntry(
            agentId: "agent-001",
            name: "researcher",
            agentType: "Explore",
            registeredAt: "2026-01-01T00:00:00.000Z"
        )

        // Then: entry can be used in a Sendable context (compiles)
        func acceptSendable<T: Sendable>(_ value: T) { _ = value }
        acceptSendable(entry)
    }

    // MARK: - AC6 (Story 4.2): TeamStoreError

    /// AC6 [P0]: TeamStoreError has correct localized descriptions.
    func testTeamStoreError_localizedDescriptions() {
        // Given: TeamStoreError cases
        let notFound = TeamStoreError.teamNotFound(id: "team_1")
        let disbanded = TeamStoreError.teamAlreadyDisbanded(id: "team_2")
        let memberNotFound = TeamStoreError.memberNotFound(teamId: "team_1", memberName: "alice")

        // Then: each error has a meaningful description
        XCTAssertTrue(notFound.errorDescription?.contains("team_1") == true)
        XCTAssertTrue(disbanded.errorDescription?.contains("team_2") == true)
        XCTAssertTrue(memberNotFound.errorDescription?.contains("alice") == true)
        XCTAssertTrue(memberNotFound.errorDescription?.contains("team_1") == true)
    }

    // MARK: - AC6 (Story 4.2): AgentRegistryError

    /// AC6 [P0]: AgentRegistryError has correct localized descriptions.
    func testAgentRegistryError_localizedDescriptions() {
        // Given: AgentRegistryError cases
        let notFound = AgentRegistryError.agentNotFound(id: "agent-001")
        let duplicateName = AgentRegistryError.duplicateAgentName(name: "researcher")

        // Then: each error has a meaningful description
        XCTAssertTrue(notFound.errorDescription?.contains("agent-001") == true)
        XCTAssertTrue(duplicateName.errorDescription?.contains("researcher") == true)
    }
}

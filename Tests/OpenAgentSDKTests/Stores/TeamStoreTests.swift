import XCTest
@testable import OpenAgentSDK

// MARK: - TeamStore Tests

/// ATDD RED PHASE: Tests for Story 4.2 -- TeamStore Actor.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `TeamStatus` enum is defined with active, disbanded cases
///   - `TeamRole` enum is defined with leader, member cases
///   - `TeamMember` struct is defined with name, role fields
///   - `Team` struct is defined with id, name, members, leaderId, createdAt, status fields
///   - `TeamStoreError` enum is defined with teamNotFound, teamAlreadyDisbanded, memberNotFound cases
///   - `TeamStore` actor is defined with create, get, list, delete, addMember, removeMember, getTeamForAgent, clear methods
/// TDD Phase: RED (feature not implemented yet)
final class TeamStoreTests: XCTestCase {

    // MARK: - AC2: TeamStore CRUD -- Create

    /// AC2 [P0]: Creating a team returns a Team with the correct field values.
    func testCreateTeam_returnsTeamWithCorrectFields() async {
        // Given: a fresh TeamStore
        let store = TeamStore()

        // When: creating a team with name, members, and leaderId
        let members: [TeamMember] = [
            TeamMember(name: "agent-1", role: .member),
            TeamMember(name: "agent-2", role: .member)
        ]
        let team = await store.create(
            name: "Alpha Team",
            members: members,
            leaderId: "coordinator"
        )

        // Then: the returned team has the expected field values
        XCTAssertEqual(team.name, "Alpha Team")
        XCTAssertEqual(team.members.count, 2)
        XCTAssertEqual(team.leaderId, "coordinator")
        XCTAssertEqual(team.status, .active)
        XCTAssertNotNil(team.id)
        XCTAssertFalse(team.createdAt.isEmpty)
    }

    /// AC2 [P0]: Creating teams auto-generates sequential IDs (team_1, team_2, ...).
    func testCreateTeam_autoGeneratesId() async {
        // Given: a fresh TeamStore
        let store = TeamStore()

        // When: creating multiple teams
        let team1 = await store.create(name: "First")
        let team2 = await store.create(name: "Second")
        let team3 = await store.create(name: "Third")

        // Then: IDs are auto-generated in sequence
        XCTAssertEqual(team1.id, "team_1")
        XCTAssertEqual(team2.id, "team_2")
        XCTAssertEqual(team3.id, "team_3")
    }

    /// AC2 [P0]: Default status for a new team is active.
    func testCreateTeam_defaultStatusIsActive() async {
        // Given: a fresh TeamStore
        let store = TeamStore()

        // When: creating a team without specifying status
        let team = await store.create(name: "Default status team")

        // Then: status is active
        XCTAssertEqual(team.status, .active)
    }

    /// AC2 [P0]: Creating a team with members preserves the member list.
    func testCreateTeam_withMembers() async {
        // Given: a fresh TeamStore
        let store = TeamStore()

        // When: creating a team with member list
        let members = [
            TeamMember(name: "alice", role: .leader),
            TeamMember(name: "bob", role: .member),
            TeamMember(name: "carol", role: .member)
        ]
        let team = await store.create(name: "Team with members", members: members)

        // Then: members list is preserved with names and roles
        XCTAssertEqual(team.members.count, 3)
        XCTAssertEqual(team.members[0].name, "alice")
        XCTAssertEqual(team.members[0].role, .leader)
        XCTAssertEqual(team.members[1].name, "bob")
        XCTAssertEqual(team.members[1].role, .member)
        XCTAssertEqual(team.members[2].name, "carol")
    }

    /// AC2 [P1]: Default leaderId is "self".
    func testCreateTeam_defaultLeaderId() async {
        // Given: a fresh TeamStore
        let store = TeamStore()

        // When: creating a team without specifying leaderId
        let team = await store.create(name: "Default leader")

        // Then: leaderId defaults to "self"
        XCTAssertEqual(team.leaderId, "self")
    }

    // MARK: - AC2: TeamStore CRUD -- Get

    /// AC2 [P0]: Getting an existing team by ID returns the team.
    func testGetTeam_existingId_returnsTeam() async {
        // Given: a TeamStore with a team
        let store = TeamStore()
        let created = await store.create(name: "Find me")

        // When: getting the team by ID
        let found = await store.get(id: created.id)

        // Then: the team is returned
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, created.id)
        XCTAssertEqual(found?.name, "Find me")
    }

    /// AC2 [P0]: Getting a non-existent team by ID returns nil.
    func testGetTeam_nonexistentId_returnsNil() async {
        // Given: a TeamStore
        let store = TeamStore()

        // When: getting a team that does not exist
        let found = await store.get(id: "team_999")

        // Then: nil is returned
        XCTAssertNil(found)
    }

    // MARK: - AC2: TeamStore CRUD -- List

    /// AC2 [P0]: Listing teams returns all created teams.
    func testListTeams_returnsAllTeams() async {
        // Given: a TeamStore with 3 teams
        let store = TeamStore()
        await store.create(name: "Team A")
        await store.create(name: "Team B")
        await store.create(name: "Team C")

        // When: listing all teams
        let teams = await store.list()

        // Then: all 3 teams are returned
        XCTAssertEqual(teams.count, 3)
    }

    /// AC2 [P1]: Listing teams can filter by status.
    func testListTeams_filterByStatus() async {
        // Given: a TeamStore with teams in different statuses
        let store = TeamStore()
        let team1 = await store.create(name: "Active team")
        let team2 = await store.create(name: "Another active")

        // Disband team2
        _ = try? await store.delete(id: team2.id)

        // When: listing teams filtered by status
        let activeTeams = await store.list(status: .active)

        // Then: only active teams are returned
        XCTAssertEqual(activeTeams.count, 1)
        XCTAssertEqual(activeTeams.first?.id, team1.id)
    }

    /// AC2 [P1]: Listing from an empty store returns an empty array.
    func testListTeams_emptyStore_returnsEmpty() async {
        // Given: a fresh empty TeamStore
        let store = TeamStore()

        // When: listing teams
        let teams = await store.list()

        // Then: result is empty
        XCTAssertTrue(teams.isEmpty)
    }

    // MARK: - AC2: TeamStore CRUD -- Delete

    /// AC2 [P0]: Deleting an existing team returns true and removes it.
    func testDeleteTeam_existingId_returnsTrue() async throws {
        // Given: a TeamStore with a team
        let store = TeamStore()
        let team = await store.create(name: "Delete me")

        // When: deleting the team
        let result = try await store.delete(id: team.id)

        // Then: returns true and team status is disbanded
        XCTAssertTrue(result)
        let fetched = await store.get(id: team.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.status, .disbanded)
    }

    /// AC1 [P0]: Deleting a non-existent team throws teamNotFound error.
    func testDeleteTeam_nonexistentId_throwsError() async {
        // Given: a TeamStore
        let store = TeamStore()

        // When/Then: deleting a non-existent team throws
        do {
            _ = try await store.delete(id: "team_999")
            XCTFail("Should have thrown teamNotFound error")
        } catch let error as TeamStoreError {
            if case .teamNotFound(let id) = error {
                XCTAssertEqual(id, "team_999")
            } else {
                XCTFail("Expected teamNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// AC2 [P0]: Deleting an already disbanded team throws teamAlreadyDisbanded.
    func testDeleteTeam_alreadyDisbanded_throwsError() async throws {
        // Given: a TeamStore with a disbanded (deleted) team
        let store = TeamStore()
        let team = await store.create(name: "Disbanded team")

        // First delete succeeds (marks disbanded and removes)
        _ = try await store.delete(id: team.id)

        // When/Then: trying to delete again throws teamNotFound (since it was removed)
        do {
            _ = try await store.delete(id: team.id)
            XCTFail("Should have thrown error for already disbanded team")
        } catch let error as TeamStoreError {
            // After delete, the team is removed, so teamNotFound is expected
            if case .teamNotFound = error {
                // Expected: team was removed from the store
            } else if case .teamAlreadyDisbanded = error {
                // Also acceptable: if implementation keeps disbanded teams in memory
            } else {
                XCTFail("Expected teamNotFound or teamAlreadyDisbanded, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - AC3: TeamStore Member Operations

    /// AC3 [P0]: Adding a member to an active team succeeds.
    func testAddMember_toActiveTeam_succeeds() async throws {
        // Given: an active team
        let store = TeamStore()
        let team = await store.create(name: "Active team")

        // When: adding a new member
        let newMember = TeamMember(name: "new-agent", role: .member)
        let updated = try await store.addMember(teamId: team.id, member: newMember)

        // Then: the member is added
        XCTAssertEqual(updated.members.count, 1)
        XCTAssertEqual(updated.members.first?.name, "new-agent")
        XCTAssertEqual(updated.members.first?.role, .member)
    }

    /// AC3 [P0]: Adding a member to a disbanded team throws an error.
    func testAddMember_toDisbandedTeam_throwsError() async throws {
        // Given: a disbanded team
        let store = TeamStore()
        let team = await store.create(name: "Soon disbanded")
        _ = try await store.delete(id: team.id)

        // When/Then: adding a member to the disbanded team throws
        do {
            let newMember = TeamMember(name: "late-agent", role: .member)
            _ = try await store.addMember(teamId: team.id, member: newMember)
            XCTFail("Should have thrown an error for disbanded team")
        } catch let error as TeamStoreError {
            if case .teamNotFound = error {
                // Expected: team was removed
            } else if case .teamAlreadyDisbanded = error {
                // Also acceptable: explicit disbanded check
            } else {
                XCTFail("Expected teamNotFound or teamAlreadyDisbanded, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// AC3 [P0]: Removing an existing member from a team succeeds.
    func testRemoveMember_existingMember_succeeds() async throws {
        // Given: a team with members
        let store = TeamStore()
        let members = [
            TeamMember(name: "alice", role: .leader),
            TeamMember(name: "bob", role: .member)
        ]
        let team = await store.create(name: "Team with members", members: members)

        // When: removing a member
        let updated = try await store.removeMember(teamId: team.id, agentName: "bob")

        // Then: the member is removed
        XCTAssertEqual(updated.members.count, 1)
        XCTAssertEqual(updated.members.first?.name, "alice")
    }

    /// AC3 [P0]: Removing a non-existent member throws memberNotFound error.
    func testRemoveMember_nonexistentMember_throwsError() async {
        // Given: a team with one member
        let store = TeamStore()
        let members = [TeamMember(name: "alice", role: .leader)]
        let team = await store.create(name: "Team", members: members)

        // When/Then: removing a non-existent member throws
        do {
            _ = try await store.removeMember(teamId: team.id, agentName: "nonexistent")
            XCTFail("Should have thrown memberNotFound error")
        } catch let error as TeamStoreError {
            if case .memberNotFound(let teamId, let memberName) = error {
                XCTAssertEqual(teamId, team.id)
                XCTAssertEqual(memberName, "nonexistent")
            } else {
                XCTFail("Expected memberNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// AC3 [P0]: Removing a member from a non-existent team throws teamNotFound.
    func testRemoveMember_nonexistentTeam_throwsError() async {
        // Given: a TeamStore
        let store = TeamStore()

        // When/Then: removing a member from a non-existent team throws
        do {
            _ = try await store.removeMember(teamId: "team_999", agentName: "alice")
            XCTFail("Should have thrown teamNotFound error")
        } catch let error as TeamStoreError {
            if case .teamNotFound(let id) = error {
                XCTAssertEqual(id, "team_999")
            } else {
                XCTFail("Expected teamNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - AC3: TeamStore Agent Lookup

    /// AC3 [P0]: Finding the team for a given agent returns the correct team.
    func testGetTeamForAgent_returnsCorrectTeam() async {
        // Given: multiple teams with different members
        let store = TeamStore()
        let members1 = [
            TeamMember(name: "alice", role: .leader),
            TeamMember(name: "bob", role: .member)
        ]
        let members2 = [
            TeamMember(name: "carol", role: .leader),
            TeamMember(name: "dave", role: .member)
        ]
        _ = await store.create(name: "Team 1", members: members1)
        let team2 = await store.create(name: "Team 2", members: members2)

        // When: finding the team for "dave"
        let found = await store.getTeamForAgent(agentName: "dave")

        // Then: the correct team is returned
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, team2.id)
        XCTAssertEqual(found?.name, "Team 2")
    }

    /// AC3 [P1]: Finding the team for a non-existent agent returns nil.
    func testGetTeamForAgent_nonexistentAgent_returnsNil() async {
        // Given: a TeamStore with teams
        let store = TeamStore()
        _ = await store.create(name: "Team 1", members: [TeamMember(name: "alice", role: .leader)])

        // When: finding the team for an agent not in any team
        let found = await store.getTeamForAgent(agentName: "unknown")

        // Then: nil is returned
        XCTAssertNil(found)
    }

    /// AC3 [P1]: Finding the team for an agent in a disbanded team returns nil.
    func testGetTeamForAgent_disbandedTeam_returnsNil() async throws {
        // Given: a disbanded team
        let store = TeamStore()
        let members = [TeamMember(name: "alice", role: .leader)]
        let team = await store.create(name: "Disbanded", members: members)
        _ = try await store.delete(id: team.id)

        // When: finding the team for "alice" who was in the disbanded team
        let found = await store.getTeamForAgent(agentName: "alice")

        // Then: nil is returned (disbanded teams are not active)
        XCTAssertNil(found)
    }

    // MARK: - AC2: TeamStore CRUD -- Clear

    /// AC2 [P1]: Clearing the store resets all teams and the counter.
    func testClearTeams_resetsStore() async {
        // Given: a TeamStore with teams
        let store = TeamStore()
        await store.create(name: "Team A")
        await store.create(name: "Team B")

        // When: clearing the store
        await store.clear()

        // Then: store is empty and counter is reset
        let teams = await store.list()
        XCTAssertTrue(teams.isEmpty)

        // Counter reset means next team gets team_1 again
        let newTeam = await store.create(name: "New team")
        XCTAssertEqual(newTeam.id, "team_1")
    }

    // MARK: - AC1: TeamStore Actor Thread Safety

    /// AC1 [P0]: Concurrent access to TeamStore does not crash (actor isolation).
    func testTeamStore_concurrentAccess() async {
        // Given: a TeamStore
        let store = TeamStore()

        // When: creating teams concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 1...100 {
                group.addTask {
                    _ = await store.create(name: "Concurrent team \(i)")
                }
            }
        }

        // Then: all teams were created without crash
        let teams = await store.list()
        XCTAssertEqual(teams.count, 100)
    }
}

import XCTest
@testable import OpenAgentSDK

// MARK: - AgentRegistry Tests

/// ATDD RED PHASE: Tests for Story 4.2 -- AgentRegistry Actor.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `AgentRegistryEntry` struct is defined with agentId, name, agentType, registeredAt fields
///   - `AgentRegistryError` enum is defined with agentNotFound, duplicateAgentName cases
///   - `AgentRegistry` actor is defined with register, unregister, get, getByName, list, listByType, clear methods
/// TDD Phase: RED (feature not implemented yet)
final class AgentRegistryTests: XCTestCase {

    // MARK: - AC5: AgentRegistry Registration

    /// AC5 [P0]: Registering an agent returns an entry with the correct fields.
    func testRegister_returnsEntryWithCorrectFields() async throws {
        // Given: a fresh AgentRegistry
        let registry = AgentRegistry()

        // When: registering a new agent
        let entry = try await registry.register(
            agentId: "agent-001",
            name: "researcher",
            agentType: "Explore"
        )

        // Then: the entry has the correct fields
        XCTAssertEqual(entry.agentId, "agent-001")
        XCTAssertEqual(entry.name, "researcher")
        XCTAssertEqual(entry.agentType, "Explore")
        XCTAssertFalse(entry.registeredAt.isEmpty)
    }

    /// AC5 [P0]: Registering an agent auto-generates a timestamp.
    func testRegister_autoGeneratesTimestamp() async throws {
        // Given: a fresh AgentRegistry
        let registry = AgentRegistry()

        // When: registering an agent
        let entry = try await registry.register(
            agentId: "agent-001",
            name: "researcher",
            agentType: "Explore"
        )

        // Then: registeredAt is a valid ISO 8601 timestamp
        XCTAssertFalse(entry.registeredAt.isEmpty)
        // ISO 8601 format should contain 'T' separator
        XCTAssertTrue(entry.registeredAt.contains("T"))
    }

    /// AC5 [P0]: Registering with a duplicate name throws duplicateAgentName error.
    func testRegister_duplicateName_throwsError() async throws {
        // Given: a registry with a registered agent
        let registry = AgentRegistry()
        _ = try await registry.register(
            agentId: "agent-001",
            name: "researcher",
            agentType: "Explore"
        )

        // When/Then: registering another agent with the same name throws
        do {
            _ = try await registry.register(
                agentId: "agent-002",
                name: "researcher",
                agentType: "Plan"
            )
            XCTFail("Should have thrown duplicateAgentName error")
        } catch let error as AgentRegistryError {
            if case .duplicateAgentName(let name) = error {
                XCTAssertEqual(name, "researcher")
            } else {
                XCTFail("Expected duplicateAgentName error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - AC5: AgentRegistry Unregistration

    /// AC5 [P0]: Unregistering an existing agent returns true.
    func testUnregister_existingAgent_returnsTrue() async throws {
        // Given: a registry with a registered agent
        let registry = AgentRegistry()
        _ = try await registry.register(
            agentId: "agent-001",
            name: "researcher",
            agentType: "Explore"
        )

        // When: unregistering the agent
        let result = await registry.unregister(agentId: "agent-001")

        // Then: returns true and agent is gone
        XCTAssertTrue(result)
        let found = await registry.get(agentId: "agent-001")
        XCTAssertNil(found)
    }

    /// AC5 [P0]: Unregistering a non-existent agent returns false.
    func testUnregister_nonexistentAgent_returnsFalse() async {
        // Given: a fresh AgentRegistry
        let registry = AgentRegistry()

        // When: unregistering an agent that does not exist
        let result = await registry.unregister(agentId: "agent-999")

        // Then: returns false
        XCTAssertFalse(result)
    }

    // MARK: - AC5: AgentRegistry Lookup by ID

    /// AC5 [P0]: Getting an agent by ID returns the entry.
    func testGet_byAgentId_returnsEntry() async throws {
        // Given: a registry with a registered agent
        let registry = AgentRegistry()
        _ = try await registry.register(
            agentId: "agent-001",
            name: "researcher",
            agentType: "Explore"
        )

        // When: getting by agent ID
        let entry = await registry.get(agentId: "agent-001")

        // Then: the correct entry is returned
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.agentId, "agent-001")
        XCTAssertEqual(entry?.name, "researcher")
        XCTAssertEqual(entry?.agentType, "Explore")
    }

    /// AC5 [P0]: Getting a non-existent agent by ID returns nil.
    func testGet_nonexistentAgentId_returnsNil() async {
        // Given: a fresh AgentRegistry
        let registry = AgentRegistry()

        // When: getting a non-existent agent
        let entry = await registry.get(agentId: "agent-999")

        // Then: nil is returned
        XCTAssertNil(entry)
    }

    // MARK: - AC5: AgentRegistry Lookup by Name

    /// AC5 [P0]: Getting an agent by name returns the entry.
    func testGetByName_returnsEntry() async throws {
        // Given: a registry with a registered agent
        let registry = AgentRegistry()
        _ = try await registry.register(
            agentId: "agent-001",
            name: "researcher",
            agentType: "Explore"
        )

        // When: getting by name
        let entry = await registry.getByName(name: "researcher")

        // Then: the correct entry is returned
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.agentId, "agent-001")
        XCTAssertEqual(entry?.name, "researcher")
    }

    /// AC5 [P0]: Getting an agent by non-existent name returns nil.
    func testGetByName_nonexistent_returnsNil() async {
        // Given: a fresh AgentRegistry
        let registry = AgentRegistry()

        // When: getting by a name that does not exist
        let entry = await registry.getByName(name: "nonexistent")

        // Then: nil is returned
        XCTAssertNil(entry)
    }

    // MARK: - AC5: AgentRegistry List

    /// AC5 [P0]: Listing returns all registered agents.
    func testList_returnsAllEntries() async throws {
        // Given: a registry with 3 agents
        let registry = AgentRegistry()
        _ = try await registry.register(agentId: "agent-1", name: "researcher", agentType: "Explore")
        _ = try await registry.register(agentId: "agent-2", name: "planner", agentType: "Plan")
        _ = try await registry.register(agentId: "agent-3", name: "coder", agentType: "Code")

        // When: listing all agents
        let agents = await registry.list()

        // Then: all 3 agents are returned
        XCTAssertEqual(agents.count, 3)
    }

    /// AC5 [P1]: Listing from an empty registry returns empty array.
    func testList_emptyRegistry_returnsEmpty() async {
        // Given: a fresh AgentRegistry
        let registry = AgentRegistry()

        // When: listing agents
        let agents = await registry.list()

        // Then: result is empty
        XCTAssertTrue(agents.isEmpty)
    }

    /// AC5 [P0]: Listing by type filters correctly.
    func testListByType_filtersCorrectly() async throws {
        // Given: a registry with agents of different types
        let registry = AgentRegistry()
        _ = try await registry.register(agentId: "agent-1", name: "researcher", agentType: "Explore")
        _ = try await registry.register(agentId: "agent-2", name: "planner", agentType: "Plan")
        _ = try await registry.register(agentId: "agent-3", name: "explorer2", agentType: "Explore")

        // When: listing by type "Explore"
        let exploreAgents = await registry.listByType(agentType: "Explore")

        // Then: only Explore agents are returned
        XCTAssertEqual(exploreAgents.count, 2)
        XCTAssertTrue(exploreAgents.allSatisfy { $0.agentType == "Explore" })
    }

    // MARK: - AC5: AgentRegistry Name Index Consistency

    /// AC5 [P0]: Unregistering an agent also clears the name index.
    func testUnregister_removesFromNameIndex() async throws {
        // Given: a registry with a registered agent
        let registry = AgentRegistry()
        _ = try await registry.register(
            agentId: "agent-001",
            name: "researcher",
            agentType: "Explore"
        )

        // When: unregistering the agent
        _ = await registry.unregister(agentId: "agent-001")

        // Then: name lookup also returns nil
        let byName = await registry.getByName(name: "researcher")
        XCTAssertNil(byName)

        // And: the name can be re-registered
        let reEntry = try await registry.register(
            agentId: "agent-002",
            name: "researcher",
            agentType: "Plan"
        )
        XCTAssertEqual(reEntry.agentId, "agent-002")
        XCTAssertEqual(reEntry.name, "researcher")
    }

    // MARK: - AC5: AgentRegistry Clear

    /// AC5 [P1]: Clearing the registry resets everything.
    func testClear_resetsRegistry() async throws {
        // Given: a registry with agents
        let registry = AgentRegistry()
        _ = try await registry.register(agentId: "agent-1", name: "researcher", agentType: "Explore")
        _ = try await registry.register(agentId: "agent-2", name: "planner", agentType: "Plan")

        // When: clearing the registry
        await registry.clear()

        // Then: registry is empty
        let agents = await registry.list()
        XCTAssertTrue(agents.isEmpty)

        // And: name index is also cleared
        let byName = await registry.getByName(name: "researcher")
        XCTAssertNil(byName)
    }

    // MARK: - AC4: AgentRegistry Actor Thread Safety

    /// AC4 [P0]: Concurrent access to AgentRegistry does not crash (actor isolation).
    func testAgentRegistry_concurrentAccess() async {
        // Given: an AgentRegistry
        let registry = AgentRegistry()

        // When: registering agents concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 1...100 {
                group.addTask {
                    _ = try? await registry.register(
                        agentId: "agent-\(i)",
                        name: "agent-\(i)",
                        agentType: "Worker"
                    )
                }
            }
        }

        // Then: all agents were registered without crash
        let agents = await registry.list()
        XCTAssertEqual(agents.count, 100)
    }
}

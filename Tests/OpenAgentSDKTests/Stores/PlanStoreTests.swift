import XCTest
@testable import OpenAgentSDK

// MARK: - PlanStore Tests

/// ATDD RED PHASE: Tests for Story 5.2 -- PlanStore Actor.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `PlanStatus` enum is defined with active, completed, discarded cases
///   - `PlanEntry` struct is defined with id, content, approved, status, createdAt, updatedAt fields
///   - `PlanStoreError` enum is defined with planNotFound(id), noActivePlan, alreadyInPlanMode cases
///   - `PlanStore` actor is defined with enterPlanMode, exitPlanMode, getCurrentPlan, isActive, get, list, clear methods
/// TDD Phase: RED (feature not implemented yet)
final class PlanStoreTests: XCTestCase {

    // MARK: - AC1: PlanStore Actor -- enterPlanMode

    /// AC1 [P0]: Entering plan mode returns a PlanEntry with correct field values.
    func testEnterPlanMode_returnsEntryWithCorrectFields() async throws {
        // Given: a fresh PlanStore
        let store = PlanStore()

        // When: entering plan mode
        let entry = try await store.enterPlanMode()

        // Then: the returned entry has the expected field values
        XCTAssertFalse(entry.id.isEmpty)
        XCTAssertEqual(entry.status, .active)
        XCTAssertFalse(entry.approved)
        XCTAssertNil(entry.content)
        XCTAssertFalse(entry.createdAt.isEmpty)
    }

    /// AC1 [P0]: Entering plan mode auto-generates sequential IDs (plan_1, plan_2, ...).
    func testEnterPlanMode_autoGeneratesSequentialIds() async throws {
        // Given: a fresh PlanStore
        let store = PlanStore()

        // When: entering plan mode multiple times (with exits in between)
        let entry1 = try await store.enterPlanMode()
        _ = try await store.exitPlanMode(plan: "first plan", approved: true)

        let entry2 = try await store.enterPlanMode()
        _ = try await store.exitPlanMode(plan: "second plan", approved: true)

        let entry3 = try await store.enterPlanMode()

        // Then: IDs are auto-generated in sequence
        XCTAssertEqual(entry1.id, "plan_1")
        XCTAssertEqual(entry2.id, "plan_2")
        XCTAssertEqual(entry3.id, "plan_3")
    }

    /// AC1 [P0]: Default status for a new plan is active.
    func testEnterPlanMode_defaultStatusIsActive() async throws {
        // Given: a fresh PlanStore
        let store = PlanStore()

        // When: entering plan mode
        let entry = try await store.enterPlanMode()

        // Then: status is active
        XCTAssertEqual(entry.status, .active)
    }

    /// AC1 [P0]: Entering plan mode when already active throws alreadyInPlanMode.
    func testEnterPlanMode_duplicate_throwsAlreadyInPlanMode() async throws {
        // Given: a PlanStore that is already in plan mode
        let store = PlanStore()
        _ = try await store.enterPlanMode()

        // When/Then: entering plan mode again throws alreadyInPlanMode
        do {
            _ = try await store.enterPlanMode()
            XCTFail("Should have thrown alreadyInPlanMode error")
        } catch let error as PlanStoreError {
            if case .alreadyInPlanMode = error {
                // Expected
            } else {
                XCTFail("Expected alreadyInPlanMode error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - AC3: PlanStore Actor -- exitPlanMode

    /// AC3 [P0]: Exiting plan mode with plan content and approved flag returns completed entry.
    func testExitPlanMode_withPlanAndApproved_returnsCompletedEntry() async throws {
        // Given: a PlanStore in plan mode
        let store = PlanStore()
        _ = try await store.enterPlanMode()

        // When: exiting with plan content and approved=true
        let entry = try await store.exitPlanMode(plan: "Step 1: Design\nStep 2: Implement", approved: true)

        // Then: entry has completed status with content and approved flag
        XCTAssertEqual(entry.status, .completed)
        XCTAssertEqual(entry.content, "Step 1: Design\nStep 2: Implement")
        XCTAssertTrue(entry.approved)
    }

    /// AC3 [P0]: Exiting plan mode without plan content still completes.
    func testExitPlanMode_withoutPlan_returnsCompletedEntry() async throws {
        // Given: a PlanStore in plan mode
        let store = PlanStore()
        _ = try await store.enterPlanMode()

        // When: exiting without plan content
        let entry = try await store.exitPlanMode(plan: nil, approved: nil)

        // Then: entry is completed with nil content
        XCTAssertEqual(entry.status, .completed)
        XCTAssertNil(entry.content)
    }

    /// AC3 [P0]: Exiting plan mode when no plan is active throws noActivePlan.
    func testExitPlanMode_noActivePlan_throwsNoActivePlan() async {
        // Given: a PlanStore not in plan mode
        let store = PlanStore()

        // When/Then: exiting throws noActivePlan
        do {
            _ = try await store.exitPlanMode(plan: "test", approved: true)
            XCTFail("Should have thrown noActivePlan error")
        } catch let error as PlanStoreError {
            if case .noActivePlan = error {
                // Expected
            } else {
                XCTFail("Expected noActivePlan error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// AC3 [P0]: When approved is nil, it defaults to true.
    func testExitPlanMode_approvedDefaultsToTrue() async throws {
        // Given: a PlanStore in plan mode
        let store = PlanStore()
        _ = try await store.enterPlanMode()

        // When: exiting with approved=nil (should default to true)
        let entry = try await store.exitPlanMode(plan: "test plan", approved: nil)

        // Then: approved defaults to true
        XCTAssertTrue(entry.approved)
    }

    // MARK: - AC11: PlanStore Actor -- getCurrentPlan

    /// AC11 [P0]: getCurrentPlan returns the active plan entry.
    func testGetCurrentPlan_withActivePlan_returnsEntry() async throws {
        // Given: a PlanStore in plan mode
        let store = PlanStore()
        let created = try await store.enterPlanMode()

        // When: getting the current plan
        let current = await store.getCurrentPlan()

        // Then: the active plan is returned
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.id, created.id)
        XCTAssertEqual(current?.status, .active)
    }

    /// AC11 [P0]: getCurrentPlan returns nil when no plan is active.
    func testGetCurrentPlan_noActivePlan_returnsNil() async {
        // Given: a PlanStore not in plan mode
        let store = PlanStore()

        // When: getting the current plan
        let current = await store.getCurrentPlan()

        // Then: nil is returned
        XCTAssertNil(current)
    }

    // MARK: - AC11: PlanStore Actor -- isActive

    /// AC11 [P0]: isActive returns true after entering plan mode, false after exiting.
    func testIsActive_trueAfterEnter_falseAfterExit() async throws {
        // Given: a fresh PlanStore
        let store = PlanStore()

        // Then: initially not active
        let initiallyActive = await store.isActive()
        XCTAssertFalse(initiallyActive)

        // When: entering plan mode
        _ = try await store.enterPlanMode()

        // Then: active
        let afterEnter = await store.isActive()
        XCTAssertTrue(afterEnter)

        // When: exiting plan mode
        _ = try await store.exitPlanMode(plan: "done", approved: true)

        // Then: not active
        let afterExit = await store.isActive()
        XCTAssertFalse(afterExit)
    }

    // MARK: - AC1: PlanStore Actor -- get

    /// AC1 [P0]: Getting an existing plan by ID returns the entry.
    func testGet_existingId_returnsEntry() async throws {
        // Given: a PlanStore with a completed plan
        let store = PlanStore()
        let created = try await store.enterPlanMode()
        _ = try await store.exitPlanMode(plan: "plan content", approved: true)

        // When: getting the plan by ID
        let found = await store.get(id: created.id)

        // Then: the entry is returned
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, created.id)
        XCTAssertEqual(found?.content, "plan content")
        XCTAssertEqual(found?.status, .completed)
    }

    /// AC1 [P0]: Getting a non-existent plan by ID returns nil.
    func testGet_nonexistentId_returnsNil() async {
        // Given: a PlanStore
        let store = PlanStore()

        // When: getting a plan that does not exist
        let found = await store.get(id: "plan_999")

        // Then: nil is returned
        XCTAssertNil(found)
    }

    // MARK: - AC1: PlanStore Actor -- list

    /// AC1 [P1]: Listing plans returns all stored entries.
    func testList_returnsAllEntries() async throws {
        // Given: a PlanStore with 3 plans (enter/exit cycle)
        let store = PlanStore()

        _ = try await store.enterPlanMode()
        _ = try await store.exitPlanMode(plan: "first", approved: true)

        _ = try await store.enterPlanMode()
        _ = try await store.exitPlanMode(plan: "second", approved: false)

        _ = try await store.enterPlanMode()
        // Third plan is still active

        // When: listing all plans
        let entries = await store.list()

        // Then: all 3 entries are returned
        XCTAssertEqual(entries.count, 3)
    }

    /// AC1 [P1]: Listing from an empty store returns an empty array.
    func testList_emptyStore_returnsEmpty() async {
        // Given: a fresh empty PlanStore
        let store = PlanStore()

        // When: listing plans
        let entries = await store.list()

        // Then: result is empty
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - AC1: PlanStore Actor -- clear

    /// AC1 [P1]: Clearing the store resets all plans and the counter.
    func testClear_resetsStore() async throws {
        // Given: a PlanStore with plans
        let store = PlanStore()

        _ = try await store.enterPlanMode()
        _ = try await store.exitPlanMode(plan: "first", approved: true)

        _ = try await store.enterPlanMode()
        _ = try await store.exitPlanMode(plan: "second", approved: true)

        // When: clearing the store
        await store.clear()

        // Then: store is empty and counter is reset
        let entries = await store.list()
        XCTAssertTrue(entries.isEmpty)

        let isActive = await store.isActive()
        XCTAssertFalse(isActive)

        // Counter reset means next plan gets plan_1 again
        let newEntry = try await store.enterPlanMode()
        XCTAssertEqual(newEntry.id, "plan_1")
    }

    // MARK: - AC1: PlanStore Actor -- Thread Safety

    /// AC1 [P0]: Concurrent access to PlanStore does not crash (actor isolation).
    func testPlanStore_concurrentAccess() async throws {
        // Given: a PlanStore
        let store = PlanStore()

        // When: performing concurrent enter/exit cycles
        // Actor isolation serializes calls, so enter/exit pairs from different
        // tasks may interleave. We use a retry approach to handle collisions.
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    // Retry loop handles interleaving with other concurrent tasks
                    var succeeded = false
                    while !succeeded {
                        do {
                            let entry = try await store.enterPlanMode()
                            _ = try await store.exitPlanMode(plan: "plan \(i)", approved: true)
                            // Verify entry was created
                            let found = await store.get(id: entry.id)
                            XCTAssertNotNil(found)
                            succeeded = true
                        } catch PlanStoreError.alreadyInPlanMode {
                            // Another task is in plan mode; yield and retry
                            await _Concurrency.Task.yield()
                        }
                    }
                }
            }
        }

        // Then: all 10 plans were created without crash
        let entries = await store.list()
        XCTAssertEqual(entries.count, 10)
    }

    // MARK: - Types: PlanStatus

    /// AC1 [P0]: PlanStatus enum has expected raw values.
    func testPlanStatus_rawValues() {
        XCTAssertEqual(PlanStatus.active.rawValue, "active")
        XCTAssertEqual(PlanStatus.completed.rawValue, "completed")
        XCTAssertEqual(PlanStatus.discarded.rawValue, "discarded")
    }

    // MARK: - Types: PlanEntry

    /// AC1 [P0]: PlanEntry is Equatable.
    func testPlanEntry_equality() {
        let entry1 = PlanEntry(
            id: "plan_1",
            content: nil,
            approved: false,
            status: .active,
            createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T00:00:00Z"
        )
        let entry2 = PlanEntry(
            id: "plan_1",
            content: nil,
            approved: false,
            status: .active,
            createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T00:00:00Z"
        )
        XCTAssertEqual(entry1, entry2)
    }

    /// AC1 [P0]: PlanEntry is Codable (round-trip encode/decode).
    func testPlanEntry_codable() throws {
        let entry = PlanEntry(
            id: "plan_1",
            content: "My plan",
            approved: true,
            status: .completed,
            createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T01:00:00Z"
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(PlanEntry.self, from: data)
        XCTAssertEqual(decoded, entry)
    }

    // MARK: - Types: PlanStoreError

    /// AC1 [P0]: PlanStoreError is Equatable.
    func testPlanStoreError_equality() {
        let error1 = PlanStoreError.planNotFound(id: "plan_1")
        let error2 = PlanStoreError.planNotFound(id: "plan_1")
        let error3 = PlanStoreError.planNotFound(id: "plan_2")
        let error4 = PlanStoreError.noActivePlan
        let error5 = PlanStoreError.alreadyInPlanMode

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        XCTAssertNotEqual(error1, error4)
        XCTAssertNotEqual(error4, error5)
    }

    /// AC1 [P0]: PlanStoreError.planNotFound has correct error description.
    func testPlanStoreError_planNotFound_description() {
        let error = PlanStoreError.planNotFound(id: "plan_42")
        XCTAssertTrue(error.localizedDescription.contains("plan_42"))
    }

    /// AC1 [P0]: PlanStoreError.noActivePlan has correct error description.
    func testPlanStoreError_noActivePlan_description() {
        let error = PlanStoreError.noActivePlan
        XCTAssertTrue(error.localizedDescription.contains("No active plan"))
    }

    /// AC1 [P0]: PlanStoreError.alreadyInPlanMode has correct error description.
    func testPlanStoreError_alreadyInPlanMode_description() {
        let error = PlanStoreError.alreadyInPlanMode
        XCTAssertTrue(error.localizedDescription.contains("Already in plan mode"))
    }
}

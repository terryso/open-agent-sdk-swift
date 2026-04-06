import XCTest
@testable import OpenAgentSDK

// MARK: - TaskStore Tests

/// ATDD RED PHASE: Tests for Story 4.1 -- TaskStore Actor.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `TaskTypes.swift` is created in `Sources/OpenAgentSDK/Types/`
///   - `TaskStore.swift` is created in `Sources/OpenAgentSDK/Stores/`
///   - `TaskStatus` enum is defined with pending, inProgress, completed, failed, cancelled
///   - `Task` struct is defined with id, subject, description, status, owner, etc.
///   - `TaskStore` actor is defined with create, list, get, update, delete, clear methods
///   - `TaskStoreError` enum is defined with taskNotFound, invalidStatusTransition cases
/// TDD Phase: RED (feature not implemented yet)
final class TaskStoreTests: XCTestCase {

    // MARK: - AC3: TaskStore CRUD -- Create

    /// AC3 [P0]: Creating a task returns a Task with the correct field values.
    func testCreateTask_returnsTaskWithCorrectFields() async {
        // Given: a fresh TaskStore
        let store = TaskStore()

        // When: creating a task with subject, description, and owner
        let task = await store.create(
            subject: "Build feature X",
            description: "Implement the new feature",
            owner: "agent-1"
        )

        // Then: the returned task has the expected field values
        XCTAssertEqual(task.subject, "Build feature X")
        XCTAssertEqual(task.description, "Implement the new feature")
        XCTAssertEqual(task.owner, "agent-1")
        XCTAssertEqual(task.status, .pending)
        XCTAssertNotNil(task.id)
        XCTAssertFalse(task.createdAt.isEmpty)
        XCTAssertFalse(task.updatedAt.isEmpty)
    }

    /// AC3 [P0]: Creating tasks auto-generates sequential IDs (task_1, task_2, ...).
    func testCreateTask_autoGeneratesId() async {
        // Given: a fresh TaskStore
        let store = TaskStore()

        // When: creating multiple tasks
        let task1 = await store.create(subject: "First")
        let task2 = await store.create(subject: "Second")
        let task3 = await store.create(subject: "Third")

        // Then: IDs are auto-generated in sequence
        XCTAssertEqual(task1.id, "task_1")
        XCTAssertEqual(task2.id, "task_2")
        XCTAssertEqual(task3.id, "task_3")
    }

    /// AC3 [P0]: Default status for a new task is pending.
    func testCreateTask_defaultStatusIsPending() async {
        // Given: a fresh TaskStore
        let store = TaskStore()

        // When: creating a task without specifying status
        let task = await store.create(subject: "Default status task")

        // Then: status is pending
        XCTAssertEqual(task.status, .pending)
    }

    // MARK: - AC3: TaskStore CRUD -- List

    /// AC3 [P0]: Listing tasks returns all created tasks.
    func testListTasks_returnsAllTasks() async {
        // Given: a TaskStore with 3 tasks
        let store = TaskStore()
        await store.create(subject: "Task A")
        await store.create(subject: "Task B")
        await store.create(subject: "Task C")

        // When: listing all tasks
        let tasks = await store.list()

        // Then: all 3 tasks are returned
        XCTAssertEqual(tasks.count, 3)
    }

    /// AC3 [P0]: Listing tasks can filter by status.
    func testListTasks_filterByStatus() async {
        // Given: a TaskStore with tasks in different statuses
        let store = TaskStore()
        let task1 = await store.create(subject: "Pending task")
        let task2 = await store.create(subject: "Progress task", status: .inProgress)

        // When: listing tasks filtered by status
        let pendingTasks = await store.list(status: .pending)
        let inProgressTasks = await store.list(status: .inProgress)

        // Then: only matching tasks are returned
        XCTAssertEqual(pendingTasks.count, 1)
        XCTAssertEqual(pendingTasks.first?.id, task1.id)
        XCTAssertEqual(inProgressTasks.count, 1)
        XCTAssertEqual(inProgressTasks.first?.id, task2.id)
    }

    /// AC3 [P0]: Listing tasks can filter by owner.
    func testListTasks_filterByOwner() async {
        // Given: a TaskStore with tasks owned by different agents
        let store = TaskStore()
        await store.create(subject: "Agent1 task", owner: "agent-1")
        await store.create(subject: "Agent2 task", owner: "agent-2")
        await store.create(subject: "Agent1 another", owner: "agent-1")

        // When: listing tasks filtered by owner
        let agent1Tasks = await store.list(owner: "agent-1")

        // Then: only matching tasks are returned
        XCTAssertEqual(agent1Tasks.count, 2)
        XCTAssertTrue(agent1Tasks.allSatisfy { $0.owner == "agent-1" })
    }

    /// AC3 [P0]: Listing from an empty store returns an empty array.
    func testListTasks_emptyStore_returnsEmpty() async {
        // Given: a fresh empty TaskStore
        let store = TaskStore()

        // When: listing tasks
        let tasks = await store.list()

        // Then: result is empty
        XCTAssertTrue(tasks.isEmpty)
    }

    // MARK: - AC3: TaskStore CRUD -- Get

    /// AC3 [P0]: Getting an existing task by ID returns the task.
    func testGetTask_existingId_returnsTask() async {
        // Given: a TaskStore with a task
        let store = TaskStore()
        let created = await store.create(subject: "Find me")

        // When: getting the task by ID
        let found = await store.get(id: created.id)

        // Then: the task is returned
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, created.id)
        XCTAssertEqual(found?.subject, "Find me")
    }

    /// AC3 [P0]: Getting a non-existent task by ID returns nil.
    func testGetTask_nonexistentId_returnsNil() async {
        // Given: a TaskStore
        let store = TaskStore()

        // When: getting a task that does not exist
        let found = await store.get(id: "task_999")

        // Then: nil is returned
        XCTAssertNil(found)
    }

    // MARK: - AC2: TaskStore Status Transitions

    /// AC2 [P0]: Status can transition from pending to inProgress.
    func testUpdateTask_statusTransition_pendingToInProgress() async throws {
        // Given: a task in pending status
        let store = TaskStore()
        let task = await store.create(subject: "Transition test")

        // When: updating to inProgress
        let updated = try await store.update(id: task.id, status: .inProgress)

        // Then: status is now inProgress
        XCTAssertEqual(updated.status, .inProgress)
    }

    /// AC2 [P0]: Status can transition from inProgress to completed.
    func testUpdateTask_statusTransition_inProgressToCompleted() async throws {
        // Given: a task in inProgress status
        let store = TaskStore()
        let task = await store.create(subject: "Complete me", status: .inProgress)

        // When: updating to completed
        let updated = try await store.update(id: task.id, status: .completed)

        // Then: status is now completed
        XCTAssertEqual(updated.status, .completed)
    }

    /// AC2 [P0]: Status can transition from inProgress to failed.
    func testUpdateTask_statusTransition_inProgressToFailed() async throws {
        // Given: a task in inProgress status
        let store = TaskStore()
        let task = await store.create(subject: "Fail me", status: .inProgress)

        // When: updating to failed
        let updated = try await store.update(id: task.id, status: .failed)

        // Then: status is now failed
        XCTAssertEqual(updated.status, .failed)
    }

    /// AC2 [P0]: Status can transition from inProgress to cancelled.
    func testUpdateTask_statusTransition_inProgressToCancelled() async throws {
        // Given: a task in inProgress status
        let store = TaskStore()
        let task = await store.create(subject: "Cancel me", status: .inProgress)

        // When: updating to cancelled
        let updated = try await store.update(id: task.id, status: .cancelled)

        // Then: status is now cancelled
        XCTAssertEqual(updated.status, .cancelled)
    }

    /// AC2 [P0]: Completed status is terminal -- cannot transition away.
    func testUpdateTask_invalidTransition_completedIsTerminal() async {
        // Given: a completed task
        let store = TaskStore()
        let task = await store.create(subject: "Done", status: .completed)

        // When/Then: attempting to transition from completed to pending throws
        do {
            _ = try await store.update(id: task.id, status: .pending)
            XCTFail("Should have thrown an error for invalid transition from completed")
        } catch let error as TaskStoreError {
            if case .invalidStatusTransition(let from, let to) = error {
                XCTAssertEqual(from, .completed)
                XCTAssertEqual(to, .pending)
            } else {
                XCTFail("Expected invalidStatusTransition error, got: \(error)")
            }
        }
    }

    /// AC2 [P0]: Failed status is terminal -- cannot transition away.
    func testUpdateTask_invalidTransition_failedIsTerminal() async {
        // Given: a failed task
        let store = TaskStore()
        let task = await store.create(subject: "Already failed", status: .failed)

        // When/Then: attempting to transition from failed to inProgress throws
        do {
            _ = try await store.update(id: task.id, status: .inProgress)
            XCTFail("Should have thrown an error for invalid transition from failed")
        } catch let error as TaskStoreError {
            if case .invalidStatusTransition(let from, let to) = error {
                XCTAssertEqual(from, .failed)
                XCTAssertEqual(to, .inProgress)
            } else {
                XCTFail("Expected invalidStatusTransition error, got: \(error)")
            }
        }
    }

    /// AC2 [P0]: Cancelled status is terminal -- cannot transition away.
    func testUpdateTask_invalidTransition_cancelledIsTerminal() async {
        // Given: a cancelled task
        let store = TaskStore()
        let task = await store.create(subject: "Already cancelled", status: .cancelled)

        // When/Then: attempting to transition from cancelled to pending throws
        do {
            _ = try await store.update(id: task.id, status: .pending)
            XCTFail("Should have thrown an error for invalid transition from cancelled")
        } catch let error as TaskStoreError {
            if case .invalidStatusTransition(let from, let to) = error {
                XCTAssertEqual(from, .cancelled)
                XCTAssertEqual(to, .pending)
            } else {
                XCTFail("Expected invalidStatusTransition error, got: \(error)")
            }
        }
    }

    // MARK: - AC3: TaskStore CRUD -- Update (other)

    /// AC3 [P0]: Updating a non-existent task throws taskNotFound error.
    func testUpdateTask_nonexistentId_returnsError() async {
        // Given: a TaskStore
        let store = TaskStore()

        // When/Then: updating a non-existent task throws
        do {
            _ = try await store.update(id: "task_999", status: .inProgress)
            XCTFail("Should have thrown taskNotFound error")
        } catch let error as TaskStoreError {
            if case .taskNotFound(let id) = error {
                XCTAssertEqual(id, "task_999")
            } else {
                XCTFail("Expected taskNotFound error, got: \(error)")
            }
        }
    }

    /// AC3 [P1]: Updating a task changes the updatedAt timestamp.
    func testUpdateTask_updatesTimestamp() async throws {
        // Given: a task with a creation timestamp
        let store = TaskStore()
        let task = await store.create(subject: "Timestamp test")
        let originalUpdatedAt = task.updatedAt

        // Small delay to ensure timestamp difference
        try await _Concurrency.Task.sleep(nanoseconds: 10_000_000) // 10ms

        // When: updating the task
        let updated = try await store.update(id: task.id, status: .inProgress)

        // Then: updatedAt has changed
        XCTAssertNotEqual(updated.updatedAt, originalUpdatedAt)
    }

    /// AC3 [P1]: Updating a task with only description (no status change) still updates timestamp.
    func testUpdateTask_descriptionOnly_updatesTimestamp() async throws {
        // Given: a task
        let store = TaskStore()
        let task = await store.create(subject: "Desc update test")
        let originalUpdatedAt = task.updatedAt

        // Small delay to ensure timestamp difference
        try await _Concurrency.Task.sleep(nanoseconds: 10_000_000) // 10ms

        // When: updating only the description (no status change)
        let updated = try await store.update(id: task.id, description: "Updated description")

        // Then: description is updated and timestamp changed
        XCTAssertEqual(updated.description, "Updated description")
        XCTAssertEqual(updated.status, .pending) // status unchanged
        XCTAssertNotEqual(updated.updatedAt, originalUpdatedAt)
    }

    // MARK: - AC3: TaskStore CRUD -- Delete

    /// AC3 [P0]: Deleting an existing task returns true.
    func testDeleteTask_existingId_returnsTrue() async {
        // Given: a TaskStore with a task
        let store = TaskStore()
        let task = await store.create(subject: "Delete me")

        // When: deleting the task
        let result = await store.delete(id: task.id)

        // Then: returns true and task is gone
        XCTAssertTrue(result)
        let fetched = await store.get(id: task.id)
        XCTAssertNil(fetched)
    }

    /// AC3 [P1]: Deleting a non-existent task returns false.
    func testDeleteTask_nonexistentId_returnsFalse() async {
        // Given: a TaskStore
        let store = TaskStore()

        // When: deleting a task that does not exist
        let result = await store.delete(id: "task_999")

        // Then: returns false
        XCTAssertFalse(result)
    }

    // MARK: - AC3: TaskStore CRUD -- Clear

    /// AC3 [P1]: Clearing the store resets all tasks and the counter.
    func testClearTasks_resetsStore() async {
        // Given: a TaskStore with tasks
        let store = TaskStore()
        await store.create(subject: "Task A")
        await store.create(subject: "Task B")

        // When: clearing the store
        await store.clear()

        // Then: store is empty and counter is reset
        let tasks = await store.list()
        XCTAssertTrue(tasks.isEmpty)

        // Counter reset means next task gets task_1 again
        let newTask = await store.create(subject: "New task")
        XCTAssertEqual(newTask.id, "task_1")
    }

    // MARK: - AC1: TaskStore Actor Thread Safety

    /// AC1 [P0]: Concurrent access to TaskStore does not crash (actor isolation).
    func testTaskStore_concurrentAccess() async {
        // Given: a TaskStore
        let store = TaskStore()

        // When: creating tasks concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 1...100 {
                group.addTask {
                    _ = await store.create(subject: "Concurrent task \(i)")
                }
            }
        }

        // Then: all tasks were created without crash
        let tasks = await store.list()
        XCTAssertEqual(tasks.count, 100)
    }
}

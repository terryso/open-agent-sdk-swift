import XCTest
@testable import OpenAgentSDK

// MARK: - TaskToolsTests

/// ATDD RED PHASE: Tests for Story 4.5 -- Task Tools (Create/List/Update/Get/Stop/Output).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `ToolContext` gains `taskStore` field
///   - `AgentOptions` gains `taskStore` field
///   - `createTaskCreateTool()` factory function is implemented
///   - `createTaskListTool()` factory function is implemented
///   - `createTaskUpdateTool()` factory function is implemented
///   - `createTaskGetTool()` factory function is implemented
///   - `createTaskStopTool()` factory function is implemented
///   - `createTaskOutputTool()` factory function is implemented
///   - Core/Agent.swift injects taskStore into ToolContext at creation points
/// TDD Phase: RED (feature not implemented yet)
final class TaskToolsTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a ToolContext with an injected TaskStore.
    private func makeContext(taskStore: TaskStore? = nil) -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id",
            taskStore: taskStore
        )
    }

    /// Creates a ToolContext without any TaskStore (nil).
    private func makeContextWithoutStore() -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id"
        )
    }

    // MARK: - AC1: TaskCreate Tool

    // MARK: AC1 — Factory

    /// AC1 [P0]: createTaskCreateTool() returns a ToolProtocol with name "TaskCreate".
    func testCreateTaskCreateTool_returnsToolProtocol() async throws {
        let tool = createTaskCreateTool()

        XCTAssertEqual(tool.name, "TaskCreate")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC1 [P0]: TaskCreate inputSchema matches TS SDK.
    func testCreateTaskCreateTool_hasValidInputSchema() async throws {
        let tool = createTaskCreateTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "subject" field
        let subjectProp = properties?["subject"] as? [String: Any]
        XCTAssertNotNil(subjectProp)
        XCTAssertEqual(subjectProp?["type"] as? String, "string")

        // Verify "description" field
        let descProp = properties?["description"] as? [String: Any]
        XCTAssertNotNil(descProp)
        XCTAssertEqual(descProp?["type"] as? String, "string")

        // Verify "owner" field
        let ownerProp = properties?["owner"] as? [String: Any]
        XCTAssertNotNil(ownerProp)
        XCTAssertEqual(ownerProp?["type"] as? String, "string")

        // Verify "status" field
        let statusProp = properties?["status"] as? [String: Any]
        XCTAssertNotNil(statusProp)
        XCTAssertEqual(statusProp?["type"] as? String, "string")

        // Verify required fields
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["subject"])
    }

    /// AC1 [P0]: TaskCreate is NOT read-only (creates tasks, causing side effects).
    func testCreateTaskCreateTool_isNotReadOnly() async throws {
        let tool = createTaskCreateTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: AC1 — Create task behavior

    /// AC1 [P0]: Creating a task with subject only returns success with task ID.
    func testTaskCreate_subjectOnly_returnsSuccess() async throws {
        let taskStore = TaskStore()
        let tool = createTaskCreateTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["subject": "Build feature X"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("task_"))
        XCTAssertTrue(result.content.contains("Build feature X"))
        XCTAssertTrue(result.content.contains("pending"))
    }

    /// AC1 [P0]: Creating a task with all optional fields stores them correctly.
    func testTaskCreate_allFields_returnsSuccess() async throws {
        let taskStore = TaskStore()
        let tool = createTaskCreateTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = [
            "subject": "Full task",
            "description": "Detailed description",
            "owner": "agent-1"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Full task"))

        // Verify the task was stored correctly
        let tasks = await taskStore.list()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.subject, "Full task")
        XCTAssertEqual(tasks.first?.description, "Detailed description")
        XCTAssertEqual(tasks.first?.owner, "agent-1")
    }

    /// AC1 [P0]: Default status for a new task is "pending".
    func testTaskCreate_defaultStatusIsPending() async throws {
        let taskStore = TaskStore()
        let tool = createTaskCreateTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["subject": "Default status task"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("pending"))

        let tasks = await taskStore.list()
        XCTAssertEqual(tasks.first?.status, .pending)
    }

    /// AC1 [P1]: Creating a task with initial status "in_progress".
    func testTaskCreate_withInitialStatus_inProgress() async throws {
        let taskStore = TaskStore()
        let tool = createTaskCreateTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = [
            "subject": "Active task",
            "status": "in_progress"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("in_progress") ||
                      result.content.contains("inProgress") ||
                      result.content.contains("IN_PROGRESS") ||
                      result.content.contains("INPROGRESS"))

        let tasks = await taskStore.list()
        XCTAssertEqual(tasks.first?.status, .inProgress)
    }

    /// AC1 [P0]: TaskCreate input Codable correctly decodes JSON fields.
    func testTaskCreate_inputDecodable() async throws {
        let taskStore = TaskStore()
        let tool = createTaskCreateTool()
        let context = makeContext(taskStore: taskStore)

        // JSON input with all fields
        let input: [String: Any] = [
            "subject": "Decode test",
            "description": "Testing decode",
            "owner": "agent-decoder",
            "status": "pending"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
    }

    // MARK: - AC2: TaskList Tool

    // MARK: AC2 — Factory

    /// AC2 [P0]: createTaskListTool() returns a ToolProtocol with name "TaskList".
    func testCreateTaskListTool_returnsToolProtocol() async throws {
        let tool = createTaskListTool()

        XCTAssertEqual(tool.name, "TaskList")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC2 [P0]: TaskList inputSchema matches TS SDK.
    func testCreateTaskListTool_hasValidInputSchema() async throws {
        let tool = createTaskListTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "status" field
        let statusProp = properties?["status"] as? [String: Any]
        XCTAssertNotNil(statusProp)
        XCTAssertEqual(statusProp?["type"] as? String, "string")

        // Verify "owner" field
        let ownerProp = properties?["owner"] as? [String: Any]
        XCTAssertNotNil(ownerProp)
        XCTAssertEqual(ownerProp?["type"] as? String, "string")

        // No required fields for TaskList
        let required = schema["required"] as? [String]
        XCTAssertNil(required)
    }

    /// AC2 [P0]: TaskList IS read-only.
    func testCreateTaskListTool_isReadOnly() async throws {
        let tool = createTaskListTool()
        XCTAssertTrue(tool.isReadOnly)
    }

    // MARK: AC2 — List behavior

    /// AC2 [P0]: Listing tasks returns all created tasks.
    func testTaskList_returnsAllTasks() async throws {
        let taskStore = TaskStore()
        _ = await taskStore.create(subject: "Task A")
        _ = await taskStore.create(subject: "Task B")
        _ = await taskStore.create(subject: "Task C")

        let tool = createTaskListTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Task A"))
        XCTAssertTrue(result.content.contains("Task B"))
        XCTAssertTrue(result.content.contains("Task C"))
    }

    /// AC2 [P0]: Listing tasks can filter by status.
    func testTaskList_filterByStatus() async throws {
        let taskStore = TaskStore()
        _ = await taskStore.create(subject: "Pending task")
        _ = await taskStore.create(subject: "Progress task", status: .inProgress)

        let tool = createTaskListTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["status": "in_progress"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Progress task"))
        // Should NOT contain the pending task
        XCTAssertFalse(result.content.contains("Pending task"))
    }

    /// AC2 [P0]: Listing tasks can filter by owner.
    func testTaskList_filterByOwner() async throws {
        let taskStore = TaskStore()
        _ = await taskStore.create(subject: "Agent1 task", owner: "agent-1")
        _ = await taskStore.create(subject: "Agent2 task", owner: "agent-2")

        let tool = createTaskListTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["owner": "agent-1"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Agent1 task"))
        XCTAssertFalse(result.content.contains("Agent2 task"))
    }

    /// AC2 [P0]: Listing from an empty store returns "No tasks found".
    func testTaskList_emptyStore_returnsNoTasks() async throws {
        let taskStore = TaskStore()
        let tool = createTaskListTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("No tasks") ||
                      result.content.contains("no tasks"))
    }

    // MARK: - AC3: TaskUpdate Tool

    // MARK: AC3 — Factory

    /// AC3 [P0]: createTaskUpdateTool() returns a ToolProtocol with name "TaskUpdate".
    func testCreateTaskUpdateTool_returnsToolProtocol() async throws {
        let tool = createTaskUpdateTool()

        XCTAssertEqual(tool.name, "TaskUpdate")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC3 [P0]: TaskUpdate inputSchema matches TS SDK.
    func testCreateTaskUpdateTool_hasValidInputSchema() async throws {
        let tool = createTaskUpdateTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "id" field
        let idProp = properties?["id"] as? [String: Any]
        XCTAssertNotNil(idProp)
        XCTAssertEqual(idProp?["type"] as? String, "string")

        // Verify "status" field
        let statusProp = properties?["status"] as? [String: Any]
        XCTAssertNotNil(statusProp)

        // Verify "output" field
        let outputProp = properties?["output"] as? [String: Any]
        XCTAssertNotNil(outputProp)

        // Verify required fields
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["id"])
    }

    /// AC3 [P0]: TaskUpdate is NOT read-only.
    func testCreateTaskUpdateTool_isNotReadOnly() async throws {
        let tool = createTaskUpdateTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: AC3 — Update behavior

    /// AC3 [P0]: Updating a task's status succeeds.
    func testTaskUpdate_status_succeeds() async throws {
        let taskStore = TaskStore()
        let task = await taskStore.create(subject: "Update me")

        let tool = createTaskUpdateTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = [
            "id": task.id,
            "status": "in_progress"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains(task.id))
    }

    /// AC3 [P0]: Updating a task's description, owner, and output.
    func testTaskUpdate_multipleFields_succeeds() async throws {
        let taskStore = TaskStore()
        let task = await taskStore.create(subject: "Multi update")

        let tool = createTaskUpdateTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = [
            "id": task.id,
            "description": "Updated desc",
            "owner": "new-owner",
            "output": "Task result output"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        // Verify fields were updated in the store
        let updatedTask = await taskStore.get(id: task.id)
        XCTAssertNotNil(updatedTask)
        XCTAssertEqual(updatedTask?.description, "Updated desc")
        XCTAssertEqual(updatedTask?.owner, "new-owner")
        XCTAssertEqual(updatedTask?.output, "Task result output")
    }

    /// AC3 [P0]: Updating a non-existent task returns error.
    func testTaskUpdate_taskNotFound_returnsError() async throws {
        let taskStore = TaskStore()
        let tool = createTaskUpdateTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = [
            "id": "task_999",
            "status": "in_progress"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("not found") ||
                      result.content.contains("Not found"))
    }

    /// AC3 [P0]: Invalid status transition returns error (completed -> pending).
    func testTaskUpdate_invalidStatusTransition_returnsError() async throws {
        let taskStore = TaskStore()
        let task = await taskStore.create(subject: "Terminal task", status: .completed)

        let tool = createTaskUpdateTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = [
            "id": task.id,
            "status": "pending"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("transition") ||
                      result.content.contains("Transition") ||
                      result.content.contains("Cannot"))
    }

    /// AC3 [P0]: TaskUpdate input Codable correctly decodes JSON fields.
    func testTaskUpdate_inputDecodable() async throws {
        let taskStore = TaskStore()
        let task = await taskStore.create(subject: "Decode test")

        let tool = createTaskUpdateTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = [
            "id": task.id,
            "status": "in_progress",
            "description": "Updated",
            "owner": "agent-1",
            "output": "Result"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
    }

    // MARK: - AC4: TaskGet Tool

    // MARK: AC4 — Factory

    /// AC4 [P0]: createTaskGetTool() returns a ToolProtocol with name "TaskGet".
    func testCreateTaskGetTool_returnsToolProtocol() async throws {
        let tool = createTaskGetTool()

        XCTAssertEqual(tool.name, "TaskGet")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC4 [P0]: TaskGet inputSchema matches TS SDK.
    func testCreateTaskGetTool_hasValidInputSchema() async throws {
        let tool = createTaskGetTool()
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

    /// AC4 [P0]: TaskGet IS read-only.
    func testCreateTaskGetTool_isReadOnly() async throws {
        let tool = createTaskGetTool()
        XCTAssertTrue(tool.isReadOnly)
    }

    // MARK: AC4 — Get behavior

    /// AC4 [P0]: Getting an existing task returns full task details.
    func testTaskGet_existingTask_returnsFullDetails() async throws {
        let taskStore = TaskStore()
        let task = await taskStore.create(
            subject: "Detailed task",
            description: "A description",
            owner: "agent-1"
        )

        let tool = createTaskGetTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["id": task.id]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains(task.id))
        XCTAssertTrue(result.content.contains("Detailed task"))
        XCTAssertTrue(result.content.contains("pending"))
        XCTAssertTrue(result.content.contains("agent-1"))
    }

    /// AC4 [P0]: Getting a non-existent task returns error.
    func testTaskGet_nonexistentTask_returnsError() async throws {
        let taskStore = TaskStore()
        let tool = createTaskGetTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["id": "task_999"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("not found") ||
                      result.content.contains("Not found"))
    }

    // MARK: - AC5: TaskStop Tool

    // MARK: AC5 — Factory

    /// AC5 [P0]: createTaskStopTool() returns a ToolProtocol with name "TaskStop".
    func testCreateTaskStopTool_returnsToolProtocol() async throws {
        let tool = createTaskStopTool()

        XCTAssertEqual(tool.name, "TaskStop")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC5 [P0]: TaskStop inputSchema matches TS SDK.
    func testCreateTaskStopTool_hasValidInputSchema() async throws {
        let tool = createTaskStopTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "id" field
        let idProp = properties?["id"] as? [String: Any]
        XCTAssertNotNil(idProp)
        XCTAssertEqual(idProp?["type"] as? String, "string")

        // Verify "reason" field
        let reasonProp = properties?["reason"] as? [String: Any]
        XCTAssertNotNil(reasonProp)
        XCTAssertEqual(reasonProp?["type"] as? String, "string")

        // Verify required fields
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["id"])
    }

    /// AC5 [P0]: TaskStop is NOT read-only.
    func testCreateTaskStopTool_isNotReadOnly() async throws {
        let tool = createTaskStopTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: AC5 — Stop behavior

    /// AC5 [P0]: Stopping a pending task changes its status to cancelled.
    func testTaskStop_pendingTask_succeeds() async throws {
        let taskStore = TaskStore()
        let task = await taskStore.create(subject: "Stop me")

        let tool = createTaskStopTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["id": task.id]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("stopped") ||
                      result.content.contains("Stopped") ||
                      result.content.contains("cancelled") ||
                      result.content.contains(task.id))

        // Verify status in store
        let updatedTask = await taskStore.get(id: task.id)
        XCTAssertEqual(updatedTask?.status, .cancelled)
    }

    /// AC5 [P0]: Stopping a task with reason records the reason.
    func testTaskStop_withReason_recordsReason() async throws {
        let taskStore = TaskStore()
        let task = await taskStore.create(subject: "Stop with reason")

        let tool = createTaskStopTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = [
            "id": task.id,
            "reason": "Priority changed"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        // Verify the reason is recorded in the output
        let updatedTask = await taskStore.get(id: task.id)
        XCTAssertNotNil(updatedTask)
        XCTAssertNotNil(updatedTask?.output)
        XCTAssertTrue(updatedTask?.output?.contains("Priority changed") == true)
    }

    /// AC5 [P0]: Stopping a non-existent task returns error.
    func testTaskStop_nonexistentTask_returnsError() async throws {
        let taskStore = TaskStore()
        let tool = createTaskStopTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["id": "task_999"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC5 [P1]: Stopping a completed task returns transition error.
    func testTaskStop_completedTask_returnsTransitionError() async throws {
        let taskStore = TaskStore()
        let task = await taskStore.create(subject: "Already done", status: .completed)

        let tool = createTaskStopTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["id": task.id]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("transition") ||
                      result.content.contains("Transition") ||
                      result.content.contains("Cannot"))
    }

    // MARK: - AC6: TaskOutput Tool

    // MARK: AC6 — Factory

    /// AC6 [P0]: createTaskOutputTool() returns a ToolProtocol with name "TaskOutput".
    func testCreateTaskOutputTool_returnsToolProtocol() async throws {
        let tool = createTaskOutputTool()

        XCTAssertEqual(tool.name, "TaskOutput")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC6 [P0]: TaskOutput inputSchema matches TS SDK.
    func testCreateTaskOutputTool_hasValidInputSchema() async throws {
        let tool = createTaskOutputTool()
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

    /// AC6 [P0]: TaskOutput IS read-only.
    func testCreateTaskOutputTool_isReadOnly() async throws {
        let tool = createTaskOutputTool()
        XCTAssertTrue(tool.isReadOnly)
    }

    // MARK: AC6 — Output behavior

    /// AC6 [P0]: Getting output of a task with output returns the output.
    func testTaskOutput_withOutput_returnsOutput() async throws {
        let taskStore = TaskStore()
        let task = await taskStore.create(subject: "Output task")
        _ = try await taskStore.update(id: task.id, output: "The result is 42")

        let tool = createTaskOutputTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["id": task.id]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("The result is 42"))
    }

    /// AC6 [P0]: Getting output of a task without output returns "(no output yet)".
    func testTaskOutput_noOutput_returnsNoOutputYet() async throws {
        let taskStore = TaskStore()
        let task = await taskStore.create(subject: "No output task")

        let tool = createTaskOutputTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["id": task.id]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("no output") ||
                      result.content.contains("No output"))
    }

    /// AC6 [P0]: Getting output of a non-existent task returns error.
    func testTaskOutput_nonexistentTask_returnsError() async throws {
        let taskStore = TaskStore()
        let tool = createTaskOutputTool()
        let context = makeContext(taskStore: taskStore)

        let input: [String: Any] = ["id": "task_999"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("not found") ||
                      result.content.contains("Not found"))
    }

    // MARK: - AC7: ToolContext Dependency Injection

    /// AC7 [P0]: ToolContext has a taskStore field that can be injected.
    func testToolContext_hasTaskStoreField() async throws {
        let taskStore = TaskStore()

        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "test-id",
            taskStore: taskStore
        )

        XCTAssertNotNil(context.taskStore)
    }

    /// AC7 [P0]: ToolContext taskStore defaults to nil (backward compatible).
    func testToolContext_taskStoreDefaultsToNil() async throws {
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        XCTAssertNil(context.taskStore)
    }

    /// AC7 [P0]: ToolContext can be created with all original fields (backward compat).
    func testToolContext_backwardCompat_noTaskStore() async throws {
        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "id-123",
            mailboxStore: nil,
            teamStore: nil,
            senderName: nil
        )

        XCTAssertEqual(context.cwd, "/tmp")
        XCTAssertEqual(context.toolUseId, "id-123")
        XCTAssertNil(context.taskStore)
    }

    /// AC7 [P0]: ToolContext can be created with all fields including taskStore.
    func testToolContext_withAllFields() async throws {
        let taskStore = TaskStore()
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()

        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "id-456",
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: "alice",
            taskStore: taskStore
        )

        XCTAssertNotNil(context.taskStore)
        XCTAssertNotNil(context.mailboxStore)
        XCTAssertNotNil(context.teamStore)
        XCTAssertEqual(context.senderName, "alice")
    }

    // MARK: - AC9: Error Handling — nil taskStore

    /// AC9 [P0]: TaskCreate returns error when taskStore is nil.
    func testTaskCreate_nilTaskStore_returnsError() async throws {
        let tool = createTaskCreateTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = ["subject": "Test"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("TaskStore") ||
                      result.content.contains("task"))
    }

    /// AC9 [P0]: TaskList returns error when taskStore is nil.
    func testTaskList_nilTaskStore_returnsError() async throws {
        let tool = createTaskListTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC9 [P0]: TaskUpdate returns error when taskStore is nil.
    func testTaskUpdate_nilTaskStore_returnsError() async throws {
        let tool = createTaskUpdateTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = ["id": "task_1"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC9 [P0]: TaskGet returns error when taskStore is nil.
    func testTaskGet_nilTaskStore_returnsError() async throws {
        let tool = createTaskGetTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = ["id": "task_1"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC9 [P0]: TaskStop returns error when taskStore is nil.
    func testTaskStop_nilTaskStore_returnsError() async throws {
        let tool = createTaskStopTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = ["id": "task_1"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC9 [P0]: TaskOutput returns error when taskStore is nil.
    func testTaskOutput_nilTaskStore_returnsError() async throws {
        let tool = createTaskOutputTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = ["id": "task_1"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    // MARK: - AC9: Error Handling — never throws

    /// AC9 [P0]: TaskCreate never throws — always returns ToolResult even with malformed input.
    func testTaskCreate_neverThrows_malformedInput() async throws {
        let tool = createTaskCreateTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],  // missing all fields
            ["subject": 123],  // wrong type
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    /// AC9 [P0]: TaskUpdate never throws — always returns ToolResult even with malformed input.
    func testTaskUpdate_neverThrows_malformedInput() async throws {
        let tool = createTaskUpdateTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],  // missing all fields
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    // MARK: - AC8: Module Boundary

    /// AC8 [P0]: Task tools do not import Core/ or Stores/ modules.
    /// This test validates the dependency injection pattern by verifying that
    /// tools can be created and used through ToolContext without direct store imports.
    func testTaskTools_moduleBoundary_noDirectStoreImports() async throws {
        // All six tools must be creatable as factory functions that return ToolProtocol
        let createTool = createTaskCreateTool()
        let listTool = createTaskListTool()
        let updateTool = createTaskUpdateTool()
        let getTool = createTaskGetTool()
        let stopTool = createTaskStopTool()
        let outputTool = createTaskOutputTool()

        // All must return valid ToolProtocol instances
        XCTAssertEqual(createTool.name, "TaskCreate")
        XCTAssertEqual(listTool.name, "TaskList")
        XCTAssertEqual(updateTool.name, "TaskUpdate")
        XCTAssertEqual(getTool.name, "TaskGet")
        XCTAssertEqual(stopTool.name, "TaskStop")
        XCTAssertEqual(outputTool.name, "TaskOutput")

        // Verify they work through ToolContext injection
        let taskStore = TaskStore()
        let context = makeContext(taskStore: taskStore)

        let result = await createTool.call(
            input: ["subject": "Boundary test"],
            context: context
        )
        XCTAssertFalse(result.isError)
    }

    // MARK: - Integration: Cross-tool workflows

    /// Integration [P1]: Create a task, then list it.
    func testIntegration_createThenList() async throws {
        let taskStore = TaskStore()
        let createTool = createTaskCreateTool()
        let listTool = createTaskListTool()
        let context = makeContext(taskStore: taskStore)

        // Create a task
        _ = await createTool.call(
            input: ["subject": "Integration task"],
            context: context
        )

        // List tasks
        let listResult = await listTool.call(input: [:], context: context)

        XCTAssertFalse(listResult.isError)
        XCTAssertTrue(listResult.content.contains("Integration task"))
    }

    /// Integration [P1]: Create -> Get -> Update -> Get Output -> Stop -> Get Output.
    func testIntegration_fullWorkflow() async throws {
        let taskStore = TaskStore()
        let createTool = createTaskCreateTool()
        let getTool = createTaskGetTool()
        let updateTool = createTaskUpdateTool()
        let outputTool = createTaskOutputTool()
        let stopTool = createTaskStopTool()
        let context = makeContext(taskStore: taskStore)

        // Step 1: Create
        let createResult = await createTool.call(
            input: ["subject": "Workflow task", "owner": "agent-1"],
            context: context
        )
        XCTAssertFalse(createResult.isError)

        // Extract task ID from create result content
        let taskId = await {
            let tasks = await taskStore.list()
            return tasks.first?.id ?? ""
        }()

        // Step 2: Get
        let getResult = await getTool.call(
            input: ["id": taskId],
            context: context
        )
        XCTAssertFalse(getResult.isError)
        XCTAssertTrue(getResult.content.contains("Workflow task"))

        // Step 3: Update status to in_progress
        let updateResult = await updateTool.call(
            input: ["id": taskId, "status": "in_progress"],
            context: context
        )
        XCTAssertFalse(updateResult.isError)

        // Step 4: Update output
        _ = await updateTool.call(
            input: ["id": taskId, "output": "Work completed successfully"],
            context: context
        )

        // Step 5: Get output
        let outputResult = await outputTool.call(
            input: ["id": taskId],
            context: context
        )
        XCTAssertFalse(outputResult.isError)
        XCTAssertTrue(outputResult.content.contains("Work completed successfully"))

        // Step 6: Stop the task (note: in_progress -> cancelled is valid)
        let stopResult = await stopTool.call(
            input: ["id": taskId, "reason": "Done early"],
            context: context
        )
        XCTAssertFalse(stopResult.isError)
    }

    /// Integration [P1]: Create -> Stop -> Output shows reason.
    func testIntegration_createThenStopThenOutput() async throws {
        let taskStore = TaskStore()
        let createTool = createTaskCreateTool()
        let stopTool = createTaskStopTool()
        let outputTool = createTaskOutputTool()
        let context = makeContext(taskStore: taskStore)

        // Create
        _ = await createTool.call(
            input: ["subject": "Stop test task"],
            context: context
        )

        let taskId = await {
            let tasks = await taskStore.list()
            return tasks.first?.id ?? ""
        }()

        // Stop with reason
        _ = await stopTool.call(
            input: ["id": taskId, "reason": "Aborted"],
            context: context
        )

        // Get output -- should contain the reason
        let outputResult = await outputTool.call(
            input: ["id": taskId],
            context: context
        )
        XCTAssertFalse(outputResult.isError)
        XCTAssertTrue(outputResult.content.contains("Aborted"))
    }
}

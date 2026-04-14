import XCTest
@testable import OpenAgentSDK

// MARK: - TaskTypesExtendedTests

/// Unit tests for TaskTypes edge cases not covered by TaskTypesTests or TaskToolsTests.
/// Focuses on TaskStatus.parse(), Codable round-trips, and error type behaviors.
final class TaskTypesExtendedTests: XCTestCase {

    // MARK: - TaskStatus.parse() — camelCase direct match

    /// parse() returns correct status for exact camelCase rawValues.
    func testTaskStatus_parse_camelCase_exactMatch() {
        XCTAssertEqual(TaskStatus.parse("pending"), .pending)
        XCTAssertEqual(TaskStatus.parse("inProgress"), .inProgress)
        XCTAssertEqual(TaskStatus.parse("completed"), .completed)
        XCTAssertEqual(TaskStatus.parse("failed"), .failed)
        XCTAssertEqual(TaskStatus.parse("cancelled"), .cancelled)
    }

    // MARK: - TaskStatus.parse() — snake_case conversion

    /// parse() converts "in_progress" to .inProgress.
    func testTaskStatus_parse_snakeCase_inProgress() {
        XCTAssertEqual(TaskStatus.parse("in_progress"), .inProgress)
    }

    /// parse() handles single-segment snake_case values (no underscores).
    func testTaskStatus_parse_snakeCase_singleSegment() {
        // These don't have underscores, so they should match directly as rawValues
        XCTAssertEqual(TaskStatus.parse("pending"), .pending)
        XCTAssertEqual(TaskStatus.parse("completed"), .completed)
        XCTAssertEqual(TaskStatus.parse("failed"), .failed)
        XCTAssertEqual(TaskStatus.parse("cancelled"), .cancelled)
    }

    // MARK: - TaskStatus.parse() — invalid values

    /// parse() returns nil for completely unknown strings.
    func testTaskStatus_parse_unknownString_returnsNil() {
        XCTAssertNil(TaskStatus.parse("unknown"))
        XCTAssertNil(TaskStatus.parse(""))
        XCTAssertNil(TaskStatus.parse("PENDING"))
    }

    /// parse() returns nil for snake_case strings that don't match any case.
    func testTaskStatus_parse_invalidSnakeCase_returnsNil() {
        XCTAssertNil(TaskStatus.parse("in_review"))
        XCTAssertNil(TaskStatus.parse("not_started"))
    }

    // MARK: - TaskStatus Codable round-trip

    /// TaskStatus encodes and decodes correctly through Codable.
    func testTaskStatus_codableRoundTrip() throws {
        for status in TaskStatus.allCases {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TaskStatus.self, from: encoded)
            XCTAssertEqual(decoded, status, "Round-trip failed for \(status.rawValue)")
        }
    }

    // MARK: - Task Codable round-trip with all optional fields

    /// Task with all optional fields set encodes and decodes correctly.
    func testTask_codableRoundTrip_allFields() throws {
        let task = Task(
            id: "task_42",
            subject: "Complex task",
            description: "A detailed description",
            status: .inProgress,
            owner: "agent-1",
            createdAt: "2026-01-15T10:30:00Z",
            updatedAt: "2026-01-15T11:00:00Z",
            output: "Result data",
            blockedBy: ["task_1", "task_2"],
            blocks: ["task_3"],
            metadata: ["priority": "high", "source": "manual"]
        )

        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)

        XCTAssertEqual(decoded, task)
        XCTAssertEqual(decoded.blockedBy, ["task_1", "task_2"])
        XCTAssertEqual(decoded.blocks, ["task_3"])
        XCTAssertEqual(decoded.metadata?["priority"], "high")
    }

    /// Task with no optional fields encodes and decodes correctly.
    func testTask_codableRoundTrip_minimalFields() throws {
        let task = Task(
            id: "task_99",
            subject: "Minimal task",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )

        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)

        XCTAssertEqual(decoded, task)
        XCTAssertNil(decoded.description)
        XCTAssertNil(decoded.owner)
        XCTAssertNil(decoded.output)
        XCTAssertNil(decoded.blockedBy)
        XCTAssertNil(decoded.blocks)
        XCTAssertNil(decoded.metadata)
    }

    // MARK: - AgentMessage Codable round-trip

    /// AgentMessage encodes and decodes correctly.
    func testAgentMessage_codableRoundTrip() throws {
        let message = AgentMessage(
            from: "lead",
            to: "worker",
            content: "Start task 1",
            timestamp: "2026-02-01T08:00:00Z",
            type: .text
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(AgentMessage.self, from: data)

        XCTAssertEqual(decoded, message)
    }

    /// AgentMessage with non-default type encodes and decodes correctly.
    func testAgentMessage_codableRoundTrip_shutdownRequest() throws {
        let message = AgentMessage(
            from: "coordinator",
            to: "worker",
            content: "Please shut down",
            timestamp: "2026-02-01T09:00:00Z",
            type: .shutdownRequest
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(AgentMessage.self, from: data)

        XCTAssertEqual(decoded.type, .shutdownRequest)
        XCTAssertEqual(decoded.content, "Please shut down")
    }

    // MARK: - TaskStoreError

    /// TaskStoreError.taskNotFound has correct localized description.
    func testTaskStoreError_taskNotFound_description() {
        let error = TaskStoreError.taskNotFound(id: "task_42")
        XCTAssertEqual(error.errorDescription, "Task not found: task_42")
    }

    /// TaskStoreError.invalidStatusTransition has correct localized description.
    func testTaskStoreError_invalidTransition_description() {
        let error = TaskStoreError.invalidStatusTransition(from: .completed, to: .pending)
        let desc = error.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("completed") == true)
        XCTAssertTrue(desc?.contains("pending") == true)
    }

    /// TaskStoreError conforms to Equatable.
    func testTaskStoreError_equatable() {
        let err1 = TaskStoreError.taskNotFound(id: "task_1")
        let err2 = TaskStoreError.taskNotFound(id: "task_1")
        let err3 = TaskStoreError.taskNotFound(id: "task_2")
        let err4 = TaskStoreError.invalidStatusTransition(from: .pending, to: .completed)

        XCTAssertEqual(err1, err2)
        XCTAssertNotEqual(err1, err3)
        XCTAssertNotEqual(err1, err4)
    }

    // MARK: - PlanEntry and PlanStatus

    /// PlanStatus has all required cases.
    func testPlanStatus_allCases() {
        // PlanStatus is not CaseIterable; verify rawValues directly
        XCTAssertNotNil(PlanStatus(rawValue: "active"))
        XCTAssertNotNil(PlanStatus(rawValue: "completed"))
        XCTAssertNotNil(PlanStatus(rawValue: "discarded"))
    }

    /// PlanEntry can be created with all fields.
    func testPlanEntry_allFields() {
        let plan = PlanEntry(
            id: "plan_1",
            content: "## Plan\n- Step 1\n- Step 2",
            approved: true,
            status: .completed,
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T01:00:00Z"
        )

        XCTAssertEqual(plan.id, "plan_1")
        XCTAssertEqual(plan.content, "## Plan\n- Step 1\n- Step 2")
        XCTAssertTrue(plan.approved)
        XCTAssertEqual(plan.status, .completed)
    }

    /// PlanEntry defaults: approved=false, status=active.
    func testPlanEntry_defaults() {
        let plan = PlanEntry(
            id: "plan_2",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )

        XCTAssertFalse(plan.approved)
        XCTAssertEqual(plan.status, .active)
        XCTAssertNil(plan.content)
    }

    // MARK: - CronJob

    /// CronJob can be created with all fields.
    func testCronJob_allFields() {
        let job = CronJob(
            id: "cron_1",
            name: "Daily sync",
            schedule: "0 9 * * *",
            command: "sync-data",
            enabled: true,
            createdAt: "2026-01-01T00:00:00Z",
            lastRunAt: "2026-01-02T09:00:00Z",
            nextRunAt: "2026-01-03T09:00:00Z"
        )

        XCTAssertEqual(job.id, "cron_1")
        XCTAssertEqual(job.schedule, "0 9 * * *")
        XCTAssertTrue(job.enabled)
        XCTAssertNotNil(job.lastRunAt)
        XCTAssertNotNil(job.nextRunAt)
    }

    /// CronJob defaults: enabled=true, lastRunAt=nil, nextRunAt=nil.
    func testCronJob_defaults() {
        let job = CronJob(
            id: "cron_2",
            name: "Backup",
            schedule: "0 0 * * *",
            command: "backup",
            createdAt: "2026-01-01T00:00:00Z"
        )

        XCTAssertTrue(job.enabled)
        XCTAssertNil(job.lastRunAt)
        XCTAssertNil(job.nextRunAt)
    }

    // MARK: - TodoItem and TodoPriority

    /// TodoPriority has all required cases.
    func testTodoPriority_allCases() {
        XCTAssertEqual(TodoPriority.allCases.count, 3)
        XCTAssertTrue(TodoPriority.allCases.contains(.high))
        XCTAssertTrue(TodoPriority.allCases.contains(.medium))
        XCTAssertTrue(TodoPriority.allCases.contains(.low))
    }

    /// TodoItem can be created with all fields.
    func testTodoItem_allFields() {
        let item = TodoItem(id: 1, text: "Write tests", done: true, priority: .high)

        XCTAssertEqual(item.id, 1)
        XCTAssertEqual(item.text, "Write tests")
        XCTAssertTrue(item.done)
        XCTAssertEqual(item.priority, .high)
    }

    /// TodoItem defaults: done=false, priority=nil.
    func testTodoItem_defaults() {
        let item = TodoItem(id: 2, text: "Review code")

        XCTAssertFalse(item.done)
        XCTAssertNil(item.priority)
    }

    // MARK: - WorktreeEntry

    /// WorktreeEntry can be created with all fields.
    func testWorktreeEntry_allFields() {
        let entry = WorktreeEntry(
            id: "wt_1",
            path: "/repo/.claude/worktrees/feature-1",
            branch: "feature-1",
            originalCwd: "/repo",
            createdAt: "2026-01-01T00:00:00Z",
            status: .active
        )

        XCTAssertEqual(entry.id, "wt_1")
        XCTAssertEqual(entry.branch, "feature-1")
        XCTAssertEqual(entry.status, .active)
    }

    /// WorktreeEntry defaults: status=active.
    func testWorktreeEntry_defaults() {
        let entry = WorktreeEntry(
            id: "wt_2",
            path: "/repo/.claude/worktrees/fix-bug",
            branch: "fix-bug",
            originalCwd: "/repo",
            createdAt: "2026-01-01T00:00:00Z"
        )

        XCTAssertEqual(entry.status, .active)
    }

    // MARK: - Store error descriptions

    /// PlanStoreError has correct localized descriptions.
    func testPlanStoreError_descriptions() {
        XCTAssertEqual(
            PlanStoreError.planNotFound(id: "plan_1").errorDescription,
            "Plan not found: plan_1"
        )
        XCTAssertEqual(
            PlanStoreError.noActivePlan.errorDescription,
            "No active plan. Enter plan mode first."
        )
        XCTAssertEqual(
            PlanStoreError.alreadyInPlanMode.errorDescription,
            "Already in plan mode."
        )
    }

    /// CronStoreError has correct localized description.
    func testCronStoreError_description() {
        XCTAssertEqual(
            CronStoreError.cronJobNotFound(id: "cron_1").errorDescription,
            "Cron job not found: cron_1"
        )
    }

    /// TodoStoreError has correct localized description.
    func testTodoStoreError_description() {
        XCTAssertEqual(
            TodoStoreError.todoNotFound(id: 5).errorDescription,
            "Todo #5 not found"
        )
    }

    /// WorktreeStoreError has correct localized descriptions.
    func testWorktreeStoreError_descriptions() {
        XCTAssertEqual(
            WorktreeStoreError.worktreeNotFound(id: "wt_1").errorDescription,
            "Worktree not found: wt_1"
        )
        let gitError = WorktreeStoreError.gitCommandFailed(message: "fatal: not a git repo")
        XCTAssertTrue(gitError.errorDescription?.contains("fatal: not a git repo") == true)
    }
}

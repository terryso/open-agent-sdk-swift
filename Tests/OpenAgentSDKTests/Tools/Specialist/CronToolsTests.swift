import XCTest
@testable import OpenAgentSDK

// MARK: - CronToolsTests

/// ATDD RED PHASE: Tests for Story 5.3 -- Cron Tools (CronCreate / CronDelete / CronList).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `createCronCreateTool()` factory function is implemented
///   - `createCronDeleteTool()` factory function is implemented
///   - `createCronListTool()` factory function is implemented
///   - `CronStore` actor is implemented with create/delete/list methods
///   - `CronJob`, `CronStoreError` types are defined
///   - `ToolContext` has `cronStore` field injected
/// TDD Phase: RED (feature not implemented yet)
final class CronToolsTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a ToolContext with an injected CronStore.
    private func makeContext(cronStore: CronStore? = nil) -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id",
            cronStore: cronStore
        )
    }

    /// Creates a ToolContext without any CronStore (nil).
    private func makeContextWithoutStore() -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id"
        )
    }

    // MARK: - AC2: CronCreate Tool -- Factory

    /// AC2 [P0]: createCronCreateTool() returns a ToolProtocol with name "CronCreate".
    func testCreateCronCreateTool_returnsToolProtocol() async throws {
        let tool = createCronCreateTool()

        XCTAssertEqual(tool.name, "CronCreate")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC6 [P0]: CronCreate inputSchema matches TS SDK (name, schedule, command -- all required).
    func testCreateCronCreateTool_hasValidInputSchema() async throws {
        let tool = createCronCreateTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "name" field (string, required)
        let nameProp = properties?["name"] as? [String: Any]
        XCTAssertNotNil(nameProp)
        XCTAssertEqual(nameProp?["type"] as? String, "string")

        // Verify "schedule" field (string, required)
        let scheduleProp = properties?["schedule"] as? [String: Any]
        XCTAssertNotNil(scheduleProp)
        XCTAssertEqual(scheduleProp?["type"] as? String, "string")

        // Verify "command" field (string, required)
        let commandProp = properties?["command"] as? [String: Any]
        XCTAssertNotNil(commandProp)
        XCTAssertEqual(commandProp?["type"] as? String, "string")

        // Verify required fields
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["name", "schedule", "command"])
    }

    /// AC7 [P0]: CronCreate is NOT read-only (modifies CronStore state).
    func testCreateCronCreateTool_isNotReadOnly() async throws {
        let tool = createCronCreateTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: - AC2: CronCreate Tool -- Behavior

    /// AC2 [P0]: Creating a cron job returns success with confirmation message.
    func testCronCreate_success_returnsConfirmation() async throws {
        let cronStore = CronStore()
        let tool = createCronCreateTool()
        let context = makeContext(cronStore: cronStore)

        let input: [String: Any] = [
            "name": "Daily Report",
            "schedule": "0 9 * * *",
            "command": "generate-report"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("cron_1") || result.content.contains("Daily Report"))
    }

    /// AC2 [P0]: CronCreate confirmation includes the job ID.
    func testCronCreate_success_includesJobId() async throws {
        let cronStore = CronStore()
        let tool = createCronCreateTool()
        let context = makeContext(cronStore: cronStore)

        let input: [String: Any] = [
            "name": "Hourly Cleanup",
            "schedule": "0 * * * *",
            "command": "cleanup"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("cron_1"))
    }

    /// AC5 [P0]: CronCreate returns error when cronStore is nil.
    func testCronCreate_nilCronStore_returnsError() async throws {
        let tool = createCronCreateTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = [
            "name": "test",
            "schedule": "* * * * *",
            "command": "cmd"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("CronStore") ||
                      result.content.contains("cron store"))
    }

    // MARK: - AC3: CronDelete Tool -- Factory

    /// AC3 [P0]: createCronDeleteTool() returns a ToolProtocol with name "CronDelete".
    func testCreateCronDeleteTool_returnsToolProtocol() async throws {
        let tool = createCronDeleteTool()

        XCTAssertEqual(tool.name, "CronDelete")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC6 [P0]: CronDelete inputSchema matches TS SDK (id -- required).
    func testCreateCronDeleteTool_hasValidInputSchema() async throws {
        let tool = createCronDeleteTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "id" field (string, required)
        let idProp = properties?["id"] as? [String: Any]
        XCTAssertNotNil(idProp)
        XCTAssertEqual(idProp?["type"] as? String, "string")

        // Verify required fields
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["id"])
    }

    /// AC7 [P0]: CronDelete is NOT read-only (modifies CronStore state).
    func testCreateCronDeleteTool_isNotReadOnly() async throws {
        let tool = createCronDeleteTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: - AC3: CronDelete Tool -- Behavior

    /// AC3 [P0]: Deleting an existing cron job returns success with confirmation.
    func testCronDelete_success_returnsConfirmation() async throws {
        let cronStore = CronStore()
        let job = await cronStore.create(name: "delete-me", schedule: "*/5 * * * *", command: "cmd")

        let tool = createCronDeleteTool()
        let context = makeContext(cronStore: cronStore)

        let input: [String: Any] = ["id": job.id]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains(job.id))
    }

    /// AC3 [P0]: Deleting a non-existent cron job returns isError=true.
    func testCronDelete_nonexistentJob_returnsError() async throws {
        let cronStore = CronStore()

        let tool = createCronDeleteTool()
        let context = makeContext(cronStore: cronStore)

        let input: [String: Any] = ["id": "cron_999"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("cron_999") ||
                      result.content.contains("not found"))
    }

    /// AC5 [P0]: CronDelete returns error when cronStore is nil.
    func testCronDelete_nilCronStore_returnsError() async throws {
        let tool = createCronDeleteTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = ["id": "cron_1"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("CronStore") ||
                      result.content.contains("cron store"))
    }

    // MARK: - AC4: CronList Tool -- Factory

    /// AC4 [P0]: createCronListTool() returns a ToolProtocol with name "CronList".
    func testCreateCronListTool_returnsToolProtocol() async throws {
        let tool = createCronListTool()

        XCTAssertEqual(tool.name, "CronList")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC6 [P0]: CronList inputSchema matches TS SDK (empty properties).
    func testCreateCronListTool_hasValidInputSchema() async throws {
        let tool = createCronListTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // CronList has no fields (empty properties)
        XCTAssertTrue(properties?.isEmpty ?? false,
                      "CronList should have empty properties")

        // No required fields
        let required = schema["required"] as? [String]
        XCTAssertNil(required, "CronList should have no required fields")
    }

    /// AC7 [P0]: CronList IS read-only (query only, does not modify state).
    func testCreateCronListTool_isReadOnly() async throws {
        let tool = createCronListTool()
        XCTAssertTrue(tool.isReadOnly)
    }

    // MARK: - AC4: CronList Tool -- Behavior

    /// AC4 [P0]: Listing cron jobs when there are jobs returns formatted list.
    func testCronList_withJobs_returnsFormattedList() async throws {
        let cronStore = CronStore()
        _ = await cronStore.create(name: "Daily Standup", schedule: "0 9 * * 1-5", command: "run-standup")
        _ = await cronStore.create(name: "Weekly Report", schedule: "0 17 * * 5", command: "generate-report")

        let tool = createCronListTool()
        let context = makeContext(cronStore: cronStore)

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Daily Standup"))
        XCTAssertTrue(result.content.contains("Weekly Report"))
    }

    /// AC4 [P0]: Listing cron jobs when empty returns "No cron jobs scheduled." message.
    func testCronList_empty_returnsNoJobsMessage() async throws {
        let cronStore = CronStore()

        let tool = createCronListTool()
        let context = makeContext(cronStore: cronStore)

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("No cron jobs scheduled"))
    }

    /// AC5 [P0]: CronList returns error when cronStore is nil.
    func testCronList_nilCronStore_returnsError() async throws {
        let tool = createCronListTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("CronStore") ||
                      result.content.contains("cron store"))
    }

    // MARK: - AC9: Error Handling -- never throws

    /// AC9 [P0]: CronCreate never throws -- always returns ToolResult even with malformed input.
    func testCronCreate_neverThrows_malformedInput() async throws {
        let tool = createCronCreateTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],                          // empty dict (missing required fields)
            ["name": 123],                // wrong type
            ["unexpected": "field"],      // unexpected fields
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    /// AC9 [P0]: CronDelete never throws -- always returns ToolResult even with malformed input.
    func testCronDelete_neverThrows_malformedInput() async throws {
        let tool = createCronDeleteTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],                  // empty dict (missing required id)
            ["id": 123],          // wrong type
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    /// AC9 [P0]: CronList never throws -- always returns ToolResult.
    func testCronList_neverThrows_malformedInput() async throws {
        let tool = createCronListTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],
            ["unexpected": "field"],
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    // MARK: - AC10: ToolContext Dependency Injection

    /// AC10 [P0]: ToolContext has a cronStore field that can be injected.
    func testToolContext_hasCronStoreField() async throws {
        let cronStore = CronStore()

        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "test-id",
            cronStore: cronStore
        )

        XCTAssertNotNil(context.cronStore)
    }

    /// AC10 [P0]: ToolContext cronStore defaults to nil (backward compatible).
    func testToolContext_cronStoreDefaultsToNil() async throws {
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        XCTAssertNil(context.cronStore)
    }

    /// AC10 [P0]: ToolContext can be created with all fields including cronStore.
    func testToolContext_withAllFieldsIncludingCronStore() async throws {
        let taskStore = TaskStore()
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        let worktreeStore = WorktreeStore()
        let planStore = PlanStore()
        let cronStore = CronStore()

        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "id-789",
            agentSpawner: nil,
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: "lead-agent",
            taskStore: taskStore,
            worktreeStore: worktreeStore,
            planStore: planStore,
            cronStore: cronStore
        )

        XCTAssertNotNil(context.cronStore)
        XCTAssertNotNil(context.planStore)
        XCTAssertNotNil(context.worktreeStore)
        XCTAssertNotNil(context.teamStore)
        XCTAssertNotNil(context.taskStore)
        XCTAssertNotNil(context.mailboxStore)
        XCTAssertEqual(context.senderName, "lead-agent")
    }

    // MARK: - AC8: Module Boundary

    /// AC8 [P0]: Cron tools do not import Core/ or Stores/ modules.
    /// This test validates the dependency injection pattern by verifying that
    /// tools can be created and used through ToolContext without direct store imports.
    func testCronTools_moduleBoundary_noDirectStoreImports() async throws {
        // All three tools must be creatable as factory functions that return ToolProtocol
        let createTool = createCronCreateTool()
        let deleteTool = createCronDeleteTool()
        let listTool = createCronListTool()

        // All must return valid ToolProtocol instances
        XCTAssertEqual(createTool.name, "CronCreate")
        XCTAssertEqual(deleteTool.name, "CronDelete")
        XCTAssertEqual(listTool.name, "CronList")

        // Verify they work through ToolContext injection
        let cronStore = CronStore()
        let context = makeContext(cronStore: cronStore)

        // CronCreate should succeed
        let createResult = await createTool.call(
            input: ["name": "boundary-test", "schedule": "*/5 * * * *", "command": "test"],
            context: context
        )
        XCTAssertFalse(createResult.isError)

        // CronList should succeed
        let listResult = await listTool.call(input: [:], context: context)
        XCTAssertFalse(listResult.isError)

        // CronDelete should succeed
        let deleteResult = await deleteTool.call(input: ["id": "cron_1"], context: context)
        XCTAssertFalse(deleteResult.isError)
    }

    // MARK: - Integration: Cross-tool workflows

    /// Integration [P1]: Create a cron job, list it, then delete it -- full lifecycle.
    func testIntegration_createListDelete_fullLifecycle() async throws {
        let cronStore = CronStore()
        let createTool = createCronCreateTool()
        let deleteTool = createCronDeleteTool()
        let listTool = createCronListTool()
        let context = makeContext(cronStore: cronStore)

        // Step 1: List initially empty
        let initialList = await listTool.call(input: [:], context: context)
        XCTAssertFalse(initialList.isError)
        XCTAssertTrue(initialList.content.contains("No cron jobs scheduled"))

        // Step 2: Create a cron job
        let createResult = await createTool.call(
            input: ["name": "Integration Test", "schedule": "0 9 * * *", "command": "run-test"],
            context: context
        )
        XCTAssertFalse(createResult.isError)
        XCTAssertTrue(createResult.content.contains("cron_1"))

        // Step 3: List should show the job
        let afterCreateList = await listTool.call(input: [:], context: context)
        XCTAssertFalse(afterCreateList.isError)
        XCTAssertTrue(afterCreateList.content.contains("Integration Test"))

        // Step 4: Delete the job
        let deleteResult = await deleteTool.call(input: ["id": "cron_1"], context: context)
        XCTAssertFalse(deleteResult.isError)
        XCTAssertTrue(deleteResult.content.contains("cron_1"))

        // Step 5: List should be empty again
        let afterDeleteList = await listTool.call(input: [:], context: context)
        XCTAssertFalse(afterDeleteList.isError)
        XCTAssertTrue(afterDeleteList.content.contains("No cron jobs scheduled"))
    }

    /// Integration [P1]: Create multiple cron jobs and list them all.
    func testIntegration_createMultiple_listAll() async throws {
        let cronStore = CronStore()
        let createTool = createCronCreateTool()
        let listTool = createCronListTool()
        let context = makeContext(cronStore: cronStore)

        // Create 3 cron jobs
        _ = await createTool.call(
            input: ["name": "Job A", "schedule": "*/5 * * * *", "command": "cmd-a"],
            context: context
        )
        _ = await createTool.call(
            input: ["name": "Job B", "schedule": "0 * * * *", "command": "cmd-b"],
            context: context
        )
        _ = await createTool.call(
            input: ["name": "Job C", "schedule": "0 0 * * *", "command": "cmd-c"],
            context: context
        )

        // List should show all 3 jobs
        let listResult = await listTool.call(input: [:], context: context)
        XCTAssertFalse(listResult.isError)
        XCTAssertTrue(listResult.content.contains("Job A"))
        XCTAssertTrue(listResult.content.contains("Job B"))
        XCTAssertTrue(listResult.content.contains("Job C"))
    }
}

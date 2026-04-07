import XCTest
@testable import OpenAgentSDK

// MARK: - PlanToolsTests

/// ATDD RED PHASE: Tests for Story 5.2 -- Plan Tools (EnterPlanMode / ExitPlanMode).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `createEnterPlanModeTool()` factory function is implemented
///   - `createExitPlanModeTool()` factory function is implemented
///   - `PlanStore` actor is implemented with enterPlanMode/exitPlanMode methods
///   - `PlanEntry`, `PlanStatus`, `PlanStoreError` types are defined
///   - `ToolContext` has `planStore` field injected
/// TDD Phase: RED (feature not implemented yet)
final class PlanToolsTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a ToolContext with an injected PlanStore.
    private func makeContext(planStore: PlanStore? = nil) -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id",
            planStore: planStore
        )
    }

    /// Creates a ToolContext without any PlanStore (nil).
    private func makeContextWithoutStore() -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id"
        )
    }

    // MARK: - AC2: EnterPlanMode Tool -- Factory

    /// AC2 [P0]: createEnterPlanModeTool() returns a ToolProtocol with name "EnterPlanMode".
    func testCreateEnterPlanModeTool_returnsToolProtocol() async throws {
        let tool = createEnterPlanModeTool()

        XCTAssertEqual(tool.name, "EnterPlanMode")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC6 [P0]: EnterPlanMode inputSchema matches TS SDK (empty properties).
    func testCreateEnterPlanModeTool_hasValidInputSchema() async throws {
        let tool = createEnterPlanModeTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // EnterPlanMode has no fields (empty properties)
        XCTAssertTrue(properties?.isEmpty ?? false,
                      "EnterPlanMode should have empty properties")

        // No required fields
        let required = schema["required"] as? [String]
        XCTAssertNil(required, "EnterPlanMode should have no required fields")
    }

    /// AC7 [P0]: EnterPlanMode is NOT read-only (modifies PlanStore state).
    func testCreateEnterPlanModeTool_isNotReadOnly() async throws {
        let tool = createEnterPlanModeTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: - AC2: EnterPlanMode Tool -- Behavior

    /// AC2 [P0]: Entering plan mode returns success with confirmation message.
    func testEnterPlanMode_success_returnsConfirmation() async throws {
        let planStore = PlanStore()
        let tool = createEnterPlanModeTool()
        let context = makeContext(planStore: planStore)

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("plan mode") ||
                      result.content.contains("Plan mode"))
    }

    /// AC4 [P0]: Entering plan mode when already active returns "Already in plan mode" (NOT isError).
    func testEnterPlanMode_alreadyInPlanMode_returnsAlreadyInPlanMessage() async throws {
        let planStore = PlanStore()
        // First enter plan mode
        _ = try await planStore.enterPlanMode()

        let tool = createEnterPlanModeTool()
        let context = makeContext(planStore: planStore)

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        // This is NOT an error -- TS SDK returns a normal message
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Already in plan mode") ||
                      result.content.contains("already in plan mode"))
    }

    /// AC5 [P0]: EnterPlanMode returns error when planStore is nil.
    func testEnterPlanMode_nilPlanStore_returnsError() async throws {
        let tool = createEnterPlanModeTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("PlanStore") ||
                      result.content.contains("plan store"))
    }

    // MARK: - AC3: ExitPlanMode Tool -- Factory

    /// AC3 [P0]: createExitPlanModeTool() returns a ToolProtocol with name "ExitPlanMode".
    func testCreateExitPlanModeTool_returnsToolProtocol() async throws {
        let tool = createExitPlanModeTool()

        XCTAssertEqual(tool.name, "ExitPlanMode")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC6 [P0]: ExitPlanMode inputSchema matches TS SDK.
    func testCreateExitPlanModeTool_hasValidInputSchema() async throws {
        let tool = createExitPlanModeTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "plan" field (string, optional)
        let planProp = properties?["plan"] as? [String: Any]
        XCTAssertNotNil(planProp)
        XCTAssertEqual(planProp?["type"] as? String, "string")

        // Verify "approved" field (boolean, optional)
        let approvedProp = properties?["approved"] as? [String: Any]
        XCTAssertNotNil(approvedProp)
        XCTAssertEqual(approvedProp?["type"] as? String, "boolean")

        // No required fields -- both are optional
        let required = schema["required"] as? [String]
        XCTAssertNil(required, "ExitPlanMode should have no required fields")
    }

    /// AC7 [P0]: ExitPlanMode is NOT read-only (modifies PlanStore state).
    func testCreateExitPlanModeTool_isNotReadOnly() async throws {
        let tool = createExitPlanModeTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: - AC3: ExitPlanMode Tool -- Behavior

    /// AC3 [P0]: Exiting plan mode with plan content and approved returns success.
    func testExitPlanMode_withPlanAndApproved_returnsSuccess() async throws {
        let planStore = PlanStore()
        _ = try await planStore.enterPlanMode()

        let tool = createExitPlanModeTool()
        let context = makeContext(planStore: planStore)

        let input: [String: Any] = [
            "plan": "Step 1: Design\nStep 2: Implement",
            "approved": true
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("approved") ||
                      result.content.contains("Approved"))
    }

    /// AC3 [P0]: Exiting plan mode when not in plan mode returns isError=true.
    func testExitPlanMode_notInPlanMode_returnsError() async throws {
        let planStore = PlanStore()
        // No active plan

        let tool = createExitPlanModeTool()
        let context = makeContext(planStore: planStore)

        let input: [String: Any] = ["plan": "test"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("plan mode") ||
                      result.content.contains("Plan mode") ||
                      result.content.contains("Not in plan"))
    }

    /// AC5 [P0]: ExitPlanMode returns error when planStore is nil.
    func testExitPlanMode_nilPlanStore_returnsError() async throws {
        let tool = createExitPlanModeTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = ["plan": "test"]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("PlanStore") ||
                      result.content.contains("plan store"))
    }

    // MARK: - AC9: Error Handling -- never throws

    /// AC9 [P0]: EnterPlanMode never throws -- always returns ToolResult even with malformed input.
    func testEnterPlanMode_neverThrows_malformedInput() async throws {
        let tool = createEnterPlanModeTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],                    // empty dict (valid for EnterPlanMode)
            ["unexpected": "field"], // unexpected fields
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    /// AC9 [P0]: ExitPlanMode never throws -- always returns ToolResult even with malformed input.
    func testExitPlanMode_neverThrows_malformedInput() async throws {
        let tool = createExitPlanModeTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],                    // empty dict
            ["plan": 123],          // wrong type
            ["approved": "yes"],    // wrong type
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    // MARK: - AC10: ToolContext Dependency Injection

    /// AC10 [P0]: ToolContext has a planStore field that can be injected.
    func testToolContext_hasPlanStoreField() async throws {
        let planStore = PlanStore()

        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "test-id",
            planStore: planStore
        )

        XCTAssertNotNil(context.planStore)
    }

    /// AC10 [P0]: ToolContext planStore defaults to nil (backward compatible).
    func testToolContext_planStoreDefaultsToNil() async throws {
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        XCTAssertNil(context.planStore)
    }

    /// AC10 [P0]: ToolContext can be created with all fields including planStore.
    func testToolContext_withAllFieldsIncludingPlanStore() async throws {
        let taskStore = TaskStore()
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        let worktreeStore = WorktreeStore()
        let planStore = PlanStore()

        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "id-789",
            agentSpawner: nil,
            mailboxStore: mailboxStore,
            teamStore: teamStore,
            senderName: "lead-agent",
            taskStore: taskStore,
            worktreeStore: worktreeStore,
            planStore: planStore
        )

        XCTAssertNotNil(context.planStore)
        XCTAssertNotNil(context.worktreeStore)
        XCTAssertNotNil(context.teamStore)
        XCTAssertNotNil(context.taskStore)
        XCTAssertNotNil(context.mailboxStore)
        XCTAssertEqual(context.senderName, "lead-agent")
    }

    // MARK: - AC8: Module Boundary

    /// AC8 [P0]: Plan tools do not import Core/ or Stores/ modules.
    /// This test validates the dependency injection pattern by verifying that
    /// tools can be created and used through ToolContext without direct store imports.
    func testPlanTools_moduleBoundary_noDirectStoreImports() async throws {
        // Both tools must be creatable as factory functions that return ToolProtocol
        let enterTool = createEnterPlanModeTool()
        let exitTool = createExitPlanModeTool()

        // Both must return valid ToolProtocol instances
        XCTAssertEqual(enterTool.name, "EnterPlanMode")
        XCTAssertEqual(exitTool.name, "ExitPlanMode")

        // Verify they work through ToolContext injection
        let planStore = PlanStore()
        let context = makeContext(planStore: planStore)

        // EnterPlanMode should succeed
        let enterResult = await enterTool.call(input: [:], context: context)
        XCTAssertFalse(enterResult.isError)

        // ExitPlanMode should succeed
        let exitResult = await exitTool.call(
            input: ["plan": "test plan", "approved": true],
            context: context
        )
        XCTAssertFalse(exitResult.isError)
    }

    // MARK: - Integration: Cross-tool workflows

    /// Integration [P1]: Enter plan mode, then exit with plan content.
    func testIntegration_enterThenExitPlanMode() async throws {
        let planStore = PlanStore()
        let enterTool = createEnterPlanModeTool()
        let exitTool = createExitPlanModeTool()
        let context = makeContext(planStore: planStore)

        // Step 1: Enter plan mode
        let enterResult = await enterTool.call(input: [:], context: context)
        XCTAssertFalse(enterResult.isError)

        // Verify plan is active in store
        let isActive = await planStore.isActive()
        XCTAssertTrue(isActive)

        // Step 2: Exit plan mode with content
        let exitResult = await exitTool.call(
            input: ["plan": "Step 1: Design\nStep 2: Build\nStep 3: Test", "approved": true],
            context: context
        )
        XCTAssertFalse(exitResult.isError)

        // Step 3: Verify no active plan
        let stillActive = await planStore.isActive()
        XCTAssertFalse(stillActive)

        // Step 4: Verify plan was stored
        let entries = await planStore.list()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.status, .completed)
        XCTAssertEqual(entries.first?.approved, true)
    }

    /// Integration [P1]: Double-enter returns already-in-plan-mode message.
    func testIntegration_enterPlanModeTwice_returnsAlreadyInPlanMode() async throws {
        let planStore = PlanStore()
        let enterTool = createEnterPlanModeTool()
        let context = makeContext(planStore: planStore)

        // Step 1: Enter plan mode successfully
        let firstEnter = await enterTool.call(input: [:], context: context)
        XCTAssertFalse(firstEnter.isError)

        // Step 2: Enter again -- should return "already in plan mode" message (not error)
        let secondEnter = await enterTool.call(input: [:], context: context)
        XCTAssertFalse(secondEnter.isError)
        XCTAssertTrue(secondEnter.content.contains("Already in plan mode") ||
                      secondEnter.content.contains("already in plan mode"))

        // Step 3: Verify only one plan was created
        let entries = await planStore.list()
        XCTAssertEqual(entries.count, 1)
    }
}

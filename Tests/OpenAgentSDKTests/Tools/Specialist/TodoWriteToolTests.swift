import XCTest
@testable import OpenAgentSDK

// MARK: - TodoWriteToolTests

/// ATDD RED PHASE: Tests for Story 5.4 -- TodoWrite Tool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `createTodoWriteTool()` factory function is implemented
///   - `TodoStore` actor is implemented with add/toggle/remove/list/clear methods
///   - `TodoItem`, `TodoPriority`, `TodoStoreError` types are defined
///   - `ToolContext` has `todoStore` field injected
/// TDD Phase: RED (feature not implemented yet)
final class TodoWriteToolTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a ToolContext with an injected TodoStore.
    private func makeContext(todoStore: TodoStore? = nil) -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id",
            todoStore: todoStore
        )
    }

    /// Creates a ToolContext without any TodoStore (nil).
    private func makeContextWithoutStore() -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id"
        )
    }

    // MARK: - AC2: TodoWrite Tool -- add operation

    /// AC2 [P0]: Adding a todo item returns success with confirmation message containing id and text.
    func testTodoWrite_add_success_returnsConfirmation() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "add",
            "text": "Buy groceries"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("#1") || result.content.contains("Buy groceries"))
    }

    /// AC2 [P0]: Adding a todo item confirmation includes the auto-generated id.
    func testTodoWrite_add_success_includesId() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "add",
            "text": "Write tests"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("#1"))
    }

    /// AC2 [P0]: Adding a todo item with priority stores the priority.
    func testTodoWrite_add_withPriority_returnsConfirmation() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "add",
            "text": "Urgent task",
            "priority": "high"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Urgent task"))
    }

    /// AC2 [P0]: Multiple adds generate sequential IDs.
    func testTodoWrite_add_sequentialIds() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let result1 = await tool.call(
            input: ["action": "add", "text": "first"] as [String: Any],
            context: context
        )
        let result2 = await tool.call(
            input: ["action": "add", "text": "second"] as [String: Any],
            context: context
        )

        XCTAssertFalse(result1.isError)
        XCTAssertFalse(result2.isError)
        XCTAssertTrue(result1.content.contains("#1"))
        XCTAssertTrue(result2.content.contains("#2"))
    }

    // MARK: - AC15: add missing text validation

    /// AC15 [P0]: Add action with missing text returns is_error=true.
    func testTodoWrite_add_missingText_returnsError() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "add"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("text required"))
    }

    /// AC15 [P0]: Add action with empty text returns is_error=true.
    func testTodoWrite_add_emptyText_returnsError() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "add",
            "text": ""
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("text required"))
    }

    // MARK: - AC3: TodoWrite Tool -- toggle operation

    /// AC3 [P0]: Toggling a todo item returns "completed" when marking done.
    func testTodoWrite_toggle_success_returnsCompleted() async throws {
        let todoStore = TodoStore()
        _ = await todoStore.add(text: "toggle me")
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "toggle",
            "id": 1
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("completed"))
    }

    /// AC3 [P0]: Toggling a completed todo item returns "reopened".
    func testTodoWrite_toggle_reopened_returnsReopened() async throws {
        let todoStore = TodoStore()
        _ = await todoStore.add(text: "already done")
        _ = try await todoStore.toggle(id: 1) // complete it first
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "toggle",
            "id": 1
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("reopened"))
    }

    /// AC3 [P0]: Toggling a non-existent todo item returns is_error=true.
    func testTodoWrite_toggle_nonexistentItem_returnsError() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "toggle",
            "id": 999
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("999") ||
                      result.content.contains("not found"))
    }

    /// AC3 [P0]: Toggle action without id returns error.
    func testTodoWrite_toggle_missingId_returnsError() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "toggle"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("id required"))
    }

    // MARK: - AC4: TodoWrite Tool -- remove operation

    /// AC4 [P0]: Removing an existing todo item returns success with confirmation.
    func testTodoWrite_remove_success_returnsConfirmation() async throws {
        let todoStore = TodoStore()
        _ = await todoStore.add(text: "remove me")
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "remove",
            "id": 1
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("#1") &&
                      result.content.contains("removed"))
    }

    /// AC4 [P0]: Removing a non-existent todo item returns is_error=true.
    func testTodoWrite_remove_nonexistentItem_returnsError() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "remove",
            "id": 999
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("999") ||
                      result.content.contains("not found"))
    }

    /// AC4 [P0]: Remove action without id returns error.
    func testTodoWrite_remove_missingId_returnsError() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "remove"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("id required"))
    }

    // MARK: - AC5: TodoWrite Tool -- list operation

    /// AC5 [P0]: Listing todo items returns formatted list with all items.
    func testTodoWrite_list_withItems_returnsFormattedList() async throws {
        let todoStore = TodoStore()
        _ = await todoStore.add(text: "Buy groceries", priority: .high)
        _ = await todoStore.add(text: "Write tests")

        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "list"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Buy groceries"))
        XCTAssertTrue(result.content.contains("Write tests"))
        XCTAssertTrue(result.content.contains("high"))
    }

    /// AC5 [P0]: Listing todo items uses [x] for done items and [ ] for pending.
    func testTodoWrite_list_showsCheckmarks() async throws {
        let todoStore = TodoStore()
        _ = await todoStore.add(text: "pending item")
        _ = await todoStore.add(text: "done item")
        _ = try await todoStore.toggle(id: 2) // mark item 2 as done

        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "list"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("[ ]"))
        XCTAssertTrue(result.content.contains("[x]"))
    }

    /// AC5 [P0]: Listing when no items returns "No todos." message.
    func testTodoWrite_list_empty_returnsNoTodosMessage() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "list"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("No todos."))
    }

    // MARK: - AC6: TodoWrite Tool -- clear operation

    /// AC6 [P0]: Clearing all todos returns "All todos cleared." confirmation.
    func testTodoWrite_clear_success_returnsConfirmation() async throws {
        let todoStore = TodoStore()
        _ = await todoStore.add(text: "item 1")
        _ = await todoStore.add(text: "item 2")

        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "clear"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("All todos cleared."))
    }

    /// AC6 [P0]: After clear, the store is empty (verified via list).
    func testTodoWrite_clear_emptiesStore() async throws {
        let todoStore = TodoStore()
        _ = await todoStore.add(text: "item 1")
        _ = await todoStore.add(text: "item 2")

        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        // Clear
        _ = await tool.call(input: ["action": "clear"] as [String: Any], context: context)

        // Verify empty via list
        let listResult = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        XCTAssertTrue(listResult.content.contains("No todos."))
    }

    // MARK: - AC7: TodoStore missing error

    /// AC7 [P0]: All actions return error when todoStore is nil -- add.
    func testTodoWrite_add_nilTodoStore_returnsError() async throws {
        let tool = createTodoWriteTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = [
            "action": "add",
            "text": "test"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("TodoStore") ||
                      result.content.contains("todo store"))
    }

    /// AC7 [P0]: All actions return error when todoStore is nil -- toggle.
    func testTodoWrite_toggle_nilTodoStore_returnsError() async throws {
        let tool = createTodoWriteTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = [
            "action": "toggle",
            "id": 1
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("TodoStore") ||
                      result.content.contains("todo store"))
    }

    /// AC7 [P0]: All actions return error when todoStore is nil -- remove.
    func testTodoWrite_remove_nilTodoStore_returnsError() async throws {
        let tool = createTodoWriteTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = [
            "action": "remove",
            "id": 1
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("TodoStore") ||
                      result.content.contains("todo store"))
    }

    /// AC7 [P0]: All actions return error when todoStore is nil -- list.
    func testTodoWrite_list_nilTodoStore_returnsError() async throws {
        let tool = createTodoWriteTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = [
            "action": "list"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("TodoStore") ||
                      result.content.contains("todo store"))
    }

    /// AC7 [P0]: All actions return error when todoStore is nil -- clear.
    func testTodoWrite_clear_nilTodoStore_returnsError() async throws {
        let tool = createTodoWriteTool()
        let context = makeContextWithoutStore()

        let input: [String: Any] = [
            "action": "clear"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("TodoStore") ||
                      result.content.contains("todo store"))
    }

    // MARK: - AC8: inputSchema matches TS SDK

    /// AC8 [P0]: TodoWrite tool has name "TodoWrite".
    func testTodoWriteTool_hasCorrectName() async throws {
        let tool = createTodoWriteTool()

        XCTAssertEqual(tool.name, "TodoWrite")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC8 [P0]: TodoWrite inputSchema matches TS SDK (action required, text/id/priority optional).
    func testTodoWriteTool_hasValidInputSchema() async throws {
        let tool = createTodoWriteTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "action" field (string, required, enum)
        let actionProp = properties?["action"] as? [String: Any]
        XCTAssertNotNil(actionProp)
        XCTAssertEqual(actionProp?["type"] as? String, "string")
        let actionEnum = actionProp?["enum"] as? [String]
        XCTAssertEqual(actionEnum, ["add", "toggle", "remove", "list", "clear"])

        // Verify "text" field (string, optional)
        let textProp = properties?["text"] as? [String: Any]
        XCTAssertNotNil(textProp)
        XCTAssertEqual(textProp?["type"] as? String, "string")

        // Verify "id" field (number, optional)
        let idProp = properties?["id"] as? [String: Any]
        XCTAssertNotNil(idProp)
        XCTAssertEqual(idProp?["type"] as? String, "number")

        // Verify "priority" field (string, optional, enum)
        let priorityProp = properties?["priority"] as? [String: Any]
        XCTAssertNotNil(priorityProp)
        XCTAssertEqual(priorityProp?["type"] as? String, "string")
        let priorityEnum = priorityProp?["enum"] as? [String]
        XCTAssertEqual(priorityEnum, ["high", "medium", "low"])

        // Verify required fields -- only "action"
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["action"])
    }

    // MARK: - AC9: isReadOnly classification

    /// AC9 [P0]: TodoWrite is NOT read-only (modifies TodoStore state).
    func testTodoWriteTool_isNotReadOnly() async throws {
        let tool = createTodoWriteTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: - AC14: unknown action validation

    /// AC14 [P0]: Unknown action returns is_error=true with unknown action message.
    func testTodoWrite_unknownAction_returnsError() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        let input: [String: Any] = [
            "action": "unknown_action"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("Unknown action") ||
                      result.content.contains("unknown_action"))
    }

    // MARK: - AC11: Error handling never throws

    /// AC11 [P0]: TodoWrite never throws -- always returns ToolResult even with malformed input.
    func testTodoWrite_neverThrows_malformedInput() async throws {
        let tool = createTodoWriteTool()
        let context = makeContextWithoutStore()

        let badInputs: [[String: Any]] = [
            [:],                          // empty dict (missing required action)
            ["action": 123],              // wrong type for action
            ["unexpected": "field"],      // unexpected fields
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    // MARK: - AC12: ToolContext dependency injection

    /// AC12 [P0]: ToolContext has a todoStore field that can be injected.
    func testToolContext_hasTodoStoreField() async throws {
        let todoStore = TodoStore()

        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "test-id",
            todoStore: todoStore
        )

        XCTAssertNotNil(context.todoStore)
    }

    /// AC12 [P0]: ToolContext todoStore defaults to nil (backward compatible).
    func testToolContext_todoStoreDefaultsToNil() async throws {
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        XCTAssertNil(context.todoStore)
    }

    /// AC12 [P0]: ToolContext can be created with all fields including todoStore.
    func testToolContext_withAllFieldsIncludingTodoStore() async throws {
        let taskStore = TaskStore()
        let mailboxStore = MailboxStore()
        let teamStore = TeamStore()
        let worktreeStore = WorktreeStore()
        let planStore = PlanStore()
        let cronStore = CronStore()
        let todoStore = TodoStore()

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
            cronStore: cronStore,
            todoStore: todoStore
        )

        XCTAssertNotNil(context.todoStore)
        XCTAssertNotNil(context.cronStore)
        XCTAssertNotNil(context.planStore)
        XCTAssertNotNil(context.worktreeStore)
        XCTAssertNotNil(context.teamStore)
        XCTAssertNotNil(context.taskStore)
        XCTAssertNotNil(context.mailboxStore)
        XCTAssertEqual(context.senderName, "lead-agent")
    }

    // MARK: - AC10: Module boundary

    /// AC10 [P0]: TodoWrite tool does not import Core/ or Stores/ modules.
    /// This test validates the dependency injection pattern by verifying that
    /// the tool can be created and used through ToolContext without direct store imports.
    func testTodoWriteTool_moduleBoundary_noDirectStoreImports() async throws {
        let tool = createTodoWriteTool()

        // Tool must be creatable as factory function returning ToolProtocol
        XCTAssertEqual(tool.name, "TodoWrite")

        // Verify it works through ToolContext injection
        let todoStore = TodoStore()
        let context = makeContext(todoStore: todoStore)

        // add should succeed
        let addResult = await tool.call(
            input: ["action": "add", "text": "boundary test"] as [String: Any],
            context: context
        )
        XCTAssertFalse(addResult.isError)

        // list should succeed
        let listResult = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        XCTAssertFalse(listResult.isError)

        // toggle should succeed
        let toggleResult = await tool.call(input: ["action": "toggle", "id": 1] as [String: Any], context: context)
        XCTAssertFalse(toggleResult.isError)

        // remove should succeed
        let removeResult = await tool.call(input: ["action": "remove", "id": 1] as [String: Any], context: context)
        XCTAssertFalse(removeResult.isError)

        // clear should succeed
        let clearResult = await tool.call(input: ["action": "clear"] as [String: Any], context: context)
        XCTAssertFalse(clearResult.isError)
    }

    // MARK: - Integration: Cross-tool workflow

    /// Integration [P1]: Add -> list -> toggle -> list -> remove -> list -> clear -- full lifecycle.
    func testIntegration_addListToggleRemoveClear_fullLifecycle() async throws {
        let todoStore = TodoStore()
        let tool = createTodoWriteTool()
        let context = makeContext(todoStore: todoStore)

        // Step 1: List initially empty
        let initialList = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        XCTAssertFalse(initialList.isError)
        XCTAssertTrue(initialList.content.contains("No todos."))

        // Step 2: Add a todo item
        let addResult = await tool.call(
            input: ["action": "add", "text": "Buy groceries", "priority": "high"] as [String: Any],
            context: context
        )
        XCTAssertFalse(addResult.isError)
        XCTAssertTrue(addResult.content.contains("#1"))

        // Step 3: Add another item
        let addResult2 = await tool.call(
            input: ["action": "add", "text": "Write tests"] as [String: Any],
            context: context
        )
        XCTAssertFalse(addResult2.isError)
        XCTAssertTrue(addResult2.content.contains("#2"))

        // Step 4: List should show both items
        let afterAddList = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        XCTAssertFalse(afterAddList.isError)
        XCTAssertTrue(afterAddList.content.contains("Buy groceries"))
        XCTAssertTrue(afterAddList.content.contains("Write tests"))
        XCTAssertTrue(afterAddList.content.contains("high"))

        // Step 5: Toggle first item to completed
        let toggleResult = await tool.call(input: ["action": "toggle", "id": 1] as [String: Any], context: context)
        XCTAssertFalse(toggleResult.isError)
        XCTAssertTrue(toggleResult.content.contains("completed"))

        // Step 6: List should show [x] for item 1
        let afterToggleList = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        XCTAssertFalse(afterToggleList.isError)
        XCTAssertTrue(afterToggleList.content.contains("[x]"))
        XCTAssertTrue(afterToggleList.content.contains("[ ]"))

        // Step 7: Remove item 2
        let removeResult = await tool.call(input: ["action": "remove", "id": 2] as [String: Any], context: context)
        XCTAssertFalse(removeResult.isError)
        XCTAssertTrue(removeResult.content.contains("#2") && removeResult.content.contains("removed"))

        // Step 8: List should show only item 1
        let afterRemoveList = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        XCTAssertFalse(afterRemoveList.isError)
        XCTAssertTrue(afterRemoveList.content.contains("Buy groceries"))
        XCTAssertFalse(afterRemoveList.content.contains("Write tests"))

        // Step 9: Clear all
        let clearResult = await tool.call(input: ["action": "clear"] as [String: Any], context: context)
        XCTAssertFalse(clearResult.isError)
        XCTAssertTrue(clearResult.content.contains("All todos cleared."))

        // Step 10: List should be empty
        let afterClearList = await tool.call(input: ["action": "list"] as [String: Any], context: context)
        XCTAssertFalse(afterClearList.isError)
        XCTAssertTrue(afterClearList.content.contains("No todos."))
    }
}

---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-07'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/5-4-todo-store-tools.md'
  - 'Tests/OpenAgentSDKTests/Stores/TodoStoreTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Specialist/TodoWriteToolTests.swift'
  - 'Sources/OpenAgentSDK/Stores/CronStore.swift'
  - 'Sources/OpenAgentSDK/Tools/Specialist/CronTools.swift'
---

# ATDD Checklist - Epic 5, Story 4: TodoStore & TodoWrite Tool

**Date:** 2026-04-07
**Author:** Nick
**Primary Test Level:** Unit (XCTest)

---

## Story Summary

As a developer, I want my Agent to manage todo items, so it can track and update task progress.

**As a** SDK developer
**I want** TodoStore Actor and TodoWrite tool
**So that** agents can add, toggle, remove, list, and clear todo items through the tool interface

---

## Acceptance Criteria

1. **AC1: TodoStore Actor** -- TodoStore implements actor-isolated add/toggle/remove/get/list/clear with thread safety; tracks TodoItem state (id, text, done, priority).
2. **AC2: TodoWrite -- add** -- Adding a todo with text and optional priority creates entry with auto-increment id, done=false, returns confirmation.
3. **AC3: TodoWrite -- toggle** -- Toggling an item by id inverts done flag, returns "completed" or "reopened". Returns is_error=true for missing id.
4. **AC4: TodoWrite -- remove** -- Removing by id deletes entry and returns confirmation. Returns is_error=true for missing id.
5. **AC5: TodoWrite -- list** -- Lists all items formatted with [x]/[ ] prefix. Returns "No todos." when empty.
6. **AC6: TodoWrite -- clear** -- Clears all items and resets counter. Returns "All todos cleared.".
7. **AC7: TodoStore missing** -- When todoStore is nil in ToolContext, all actions return is_error=true.
8. **AC8: inputSchema matches TS SDK** -- action (required, enum: add/toggle/remove/list/clear), text (optional), id (optional number), priority (optional, enum: high/medium/low).
9. **AC9: isReadOnly** -- TodoWrite returns false (modifies TodoStore state).
10. **AC10: Module boundary** -- TodoStore in Stores/ imports only Foundation+Types; TodoWriteTool in Tools/Specialist/ imports only Foundation+Types.
11. **AC11: Error handling** -- Errors captured as ToolExecuteResult(isError:true), never thrown from tool handlers.
12. **AC12: ToolContext DI** -- todoStore injected via ToolContext, consistent with CronTool/PlanTool patterns.
13. **AC13: TodoStore state queries** -- get(id:) returns item or nil; list() returns all; clear() resets all state.
14. **AC14: Unknown action** -- Unknown action values return is_error=true.
15. **AC15: add missing text** -- add action with empty or missing text returns is_error=true with "text required".

---

## Failing Tests Created (RED Phase)

### Unit Tests -- TodoStore (27 tests)

**File:** `Tests/OpenAgentSDKTests/Stores/TodoStoreTests.swift`

- **Test:** testAdd_returnsItemWithCorrectFields
  - **Status:** RED - TodoStore/TodoItem types not yet implemented
  - **Verifies:** AC1 -- add returns TodoItem with correct fields (id=1, text, done=false, priority=nil)

- **Test:** testAdd_autoGeneratesSequentialIds
  - **Status:** RED - TodoStore not yet implemented
  - **Verifies:** AC1 -- sequential integer IDs (1, 2, 3)

- **Test:** testAdd_defaultDoneIsFalse
  - **Status:** RED - TodoItem not yet implemented
  - **Verifies:** AC1 -- done defaults to false

- **Test:** testAdd_doesNotThrow
  - **Status:** RED - TodoStore not yet implemented
  - **Verifies:** AC1 -- add is a pure append, never throws

- **Test:** testAdd_withPriority_storesPriority
  - **Status:** RED - TodoStore/TodoPriority not yet implemented
  - **Verifies:** AC1 -- add with priority stores .high correctly

- **Test:** testAdd_withMediumPriority_storesPriority
  - **Status:** RED - TodoPriority not yet implemented
  - **Verifies:** AC1 -- add with priority stores .medium correctly

- **Test:** testAdd_withLowPriority_storesPriority
  - **Status:** RED - TodoPriority not yet implemented
  - **Verifies:** AC1 -- add with priority stores .low correctly

- **Test:** testToggle_existingId_flipsDoneToTrue
  - **Status:** RED - TodoStore not yet implemented
  - **Verifies:** AC1 -- toggle flips done from false to true

- **Test:** testToggle_completedItem_flipsDoneBackToFalse
  - **Status:** RED - TodoStore not yet implemented
  - **Verifies:** AC1 -- toggle flips done back from true to false

- **Test:** testToggle_nonexistentId_throwsTodoNotFound
  - **Status:** RED - TodoStoreError not yet implemented
  - **Verifies:** AC1 -- toggle throws todoNotFound for missing id

- **Test:** testRemove_existingId_succeeds
  - **Status:** RED - TodoStore not yet implemented
  - **Verifies:** AC1 -- remove deletes item from store

- **Test:** testRemove_nonexistentId_throwsTodoNotFound
  - **Status:** RED - TodoStoreError not yet implemented
  - **Verifies:** AC1 -- remove throws todoNotFound for missing id

- **Test:** testGet_existingId_returnsItem
  - **Status:** RED - TodoStore not yet implemented
  - **Verifies:** AC13 -- get retrieves item by id

- **Test:** testGet_nonexistentId_returnsNil
  - **Status:** RED - TodoStore not yet implemented
  - **Verifies:** AC13 -- get returns nil for missing id

- **Test:** testList_returnsAllItems
  - **Status:** RED - TodoStore not yet implemented
  - **Verifies:** AC13 -- list returns all added items sorted by id

- **Test:** testList_emptyStore_returnsEmpty
  - **Status:** RED - TodoStore not yet implemented
  - **Verifies:** AC13 -- list returns empty array for empty store

- **Test:** testClear_resetsStore
  - **Status:** RED - TodoStore not yet implemented
  - **Verifies:** AC13 -- clear resets items and counter

- **Test:** testTodoStore_concurrentAccess
  - **Status:** RED - TodoStore not yet implemented
  - **Verifies:** AC1 -- actor isolation survives concurrent access

- **Test:** testTodoItem_equality
  - **Status:** RED - TodoItem type not yet implemented
  - **Verifies:** AC1 -- TodoItem conforms to Equatable

- **Test:** testTodoItem_codable
  - **Status:** RED - TodoItem type not yet implemented
  - **Verifies:** AC1 -- TodoItem conforms to Codable (full round-trip)

- **Test:** testTodoItem_codable_withNilPriority
  - **Status:** RED - TodoItem type not yet implemented
  - **Verifies:** AC1 -- Codable round-trip with nil priority

- **Test:** testTodoPriority_allCases
  - **Status:** RED - TodoPriority not yet implemented
  - **Verifies:** AC1 -- TodoPriority has exactly high/medium/low

- **Test:** testTodoPriority_rawValues
  - **Status:** RED - TodoPriority not yet implemented
  - **Verifies:** AC1 -- raw values match "high"/"medium"/"low"

- **Test:** testTodoStoreError_equality
  - **Status:** RED - TodoStoreError not yet implemented
  - **Verifies:** AC1 -- TodoStoreError conforms to Equatable

- **Test:** testTodoStoreError_todoNotFound_description
  - **Status:** RED - TodoStoreError not yet implemented
  - **Verifies:** AC1 -- todoNotFound error description includes id

### Unit Tests -- TodoWriteTool (32 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/TodoWriteToolTests.swift`

- **Test:** testTodoWrite_add_success_returnsConfirmation
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC2 -- add returns success with confirmation

- **Test:** testTodoWrite_add_success_includesId
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC2 -- add confirmation includes auto-generated id

- **Test:** testTodoWrite_add_withPriority_returnsConfirmation
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC2 -- add with priority returns confirmation

- **Test:** testTodoWrite_add_sequentialIds
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC2 -- multiple adds generate sequential IDs

- **Test:** testTodoWrite_add_missingText_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC15 -- add with missing text returns is_error=true

- **Test:** testTodoWrite_add_emptyText_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC15 -- add with empty text returns is_error=true

- **Test:** testTodoWrite_toggle_success_returnsCompleted
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC3 -- toggle returns "completed"

- **Test:** testTodoWrite_toggle_reopened_returnsReopened
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC3 -- toggle returns "reopened"

- **Test:** testTodoWrite_toggle_nonexistentItem_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC3 -- toggle returns is_error=true for missing id

- **Test:** testTodoWrite_toggle_missingId_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC3 -- toggle without id returns error

- **Test:** testTodoWrite_remove_success_returnsConfirmation
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC4 -- remove returns success with confirmation

- **Test:** testTodoWrite_remove_nonexistentItem_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC4 -- remove returns is_error=true for missing id

- **Test:** testTodoWrite_remove_missingId_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC4 -- remove without id returns error

- **Test:** testTodoWrite_list_withItems_returnsFormattedList
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC5 -- list returns formatted output with items and priority

- **Test:** testTodoWrite_list_showsCheckmarks
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC5 -- list uses [x] for done and [ ] for pending

- **Test:** testTodoWrite_list_empty_returnsNoTodosMessage
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC5 -- list returns "No todos." when empty

- **Test:** testTodoWrite_clear_success_returnsConfirmation
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC6 -- clear returns "All todos cleared."

- **Test:** testTodoWrite_clear_emptiesStore
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC6 -- clear empties the store (verified via list)

- **Test:** testTodoWrite_add_nilTodoStore_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC7 -- add returns is_error=true when todoStore is nil

- **Test:** testTodoWrite_toggle_nilTodoStore_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC7 -- toggle returns is_error=true when todoStore is nil

- **Test:** testTodoWrite_remove_nilTodoStore_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC7 -- remove returns is_error=true when todoStore is nil

- **Test:** testTodoWrite_list_nilTodoStore_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC7 -- list returns is_error=true when todoStore is nil

- **Test:** testTodoWrite_clear_nilTodoStore_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC7 -- clear returns is_error=true when todoStore is nil

- **Test:** testTodoWriteTool_hasCorrectName
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC8 -- tool name is "TodoWrite"

- **Test:** testTodoWriteTool_hasValidInputSchema
  - **Status:** RED - todoWriteSchema not yet implemented
  - **Verifies:** AC8 -- schema has action (required, enum), text, id, priority fields

- **Test:** testTodoWriteTool_isNotReadOnly
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC9 -- TodoWrite isReadOnly = false

- **Test:** testTodoWrite_unknownAction_returnsError
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC14 -- unknown action returns is_error=true

- **Test:** testTodoWrite_neverThrows_malformedInput
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC11 -- tool never throws, always returns ToolResult

- **Test:** testToolContext_hasTodoStoreField
  - **Status:** RED - ToolContext.todoStore not yet added
  - **Verifies:** AC12 -- ToolContext has todoStore field

- **Test:** testToolContext_todoStoreDefaultsToNil
  - **Status:** RED - ToolContext.todoStore not yet added
  - **Verifies:** AC12 -- todoStore defaults to nil (backward compatible)

- **Test:** testToolContext_withAllFieldsIncludingTodoStore
  - **Status:** RED - ToolContext.todoStore not yet added
  - **Verifies:** AC12 -- ToolContext accepts all stores including todoStore

- **Test:** testTodoWriteTool_moduleBoundary_noDirectStoreImports
  - **Status:** RED - createTodoWriteTool() not yet implemented
  - **Verifies:** AC10 -- tool works via ToolContext injection, no direct store imports

- **Test:** testIntegration_addListToggleRemoveClear_fullLifecycle
  - **Status:** RED - All TodoStore/TodoWrite not yet implemented
  - **Verifies:** AC2-AC6 -- full add-list-toggle-remove-clear lifecycle

---

## Implementation Checklist

### Task 1: Define Todo Types (AC: #1, #10)

**File:** `Sources/OpenAgentSDK/Types/TaskTypes.swift`

**Tasks to make TodoStore type tests pass:**

- [ ] Add `TodoPriority` enum with high, medium, low cases
- [ ] Add `TodoItem` struct with id (Int), text (String), done (Bool), priority (TodoPriority?)
- [ ] Add `TodoStoreError` enum with todoNotFound(id: Int) case
- [ ] Ensure all conform to Sendable, Equatable, Codable
- [ ] Run tests: `swift test --filter TodoStoreTests`

### Task 2: Implement TodoStore Actor (AC: #1, #13)

**File:** `Sources/OpenAgentSDK/Stores/TodoStore.swift` (new file)

**Tasks to make TodoStore tests pass:**

- [ ] Create `TodoStore` actor with private items dictionary [Int: TodoItem] and counter
- [ ] Implement `add(text:priority:)` returning TodoItem with auto-incremented id, done=false
- [ ] Implement `toggle(id:)` throwing TodoStoreError.todoNotFound, inverting done
- [ ] Implement `remove(id:)` throwing TodoStoreError.todoNotFound, deleting item
- [ ] Implement `get(id:)` returning optional TodoItem
- [ ] Implement `list()` returning [TodoItem] sorted by id
- [ ] Implement `clear()` resetting items and counter
- [ ] Run tests: `swift test --filter TodoStoreTests`

### Task 3: Extend ToolContext (AC: #12)

**File:** `Sources/OpenAgentSDK/Types/ToolTypes.swift`

**Tasks to make ToolContext tests pass:**

- [ ] Add `todoStore: TodoStore?` field to ToolContext
- [ ] Add todoStore parameter to init with default value nil
- [ ] Run tests: `swift test --filter TodoWriteToolTests/testToolContext`

### Task 4: Implement TodoWrite Tool (AC: #2-#9, #11, #14, #15)

**File:** `Sources/OpenAgentSDK/Tools/Specialist/TodoWriteTool.swift` (new file)

**Tasks to make TodoWriteTool tests pass:**

- [ ] Define `TodoWriteInput` Codable struct with action, text, id, priority
- [ ] Define `todoWriteSchema` matching TS SDK
- [ ] Implement `createTodoWriteTool()` factory function with isReadOnly=false
- [ ] add: validate text non-empty, call store.add(), return confirmation
- [ ] toggle: validate id, call store.toggle(), return "completed"/"reopened"
- [ ] remove: validate id, call store.remove(), return confirmation
- [ ] list: call store.list(), format with [x]/[ ] prefix, return "No todos." if empty
- [ ] clear: call store.clear(), return "All todos cleared."
- [ ] default: return is_error=true for unknown action
- [ ] Handle nil todoStore returning is_error=true for all actions
- [ ] Catch TodoStoreError returning is_error=true
- [ ] Run tests: `swift test --filter TodoWriteToolTests`

### Task 5: Update Module Entry (AC: #10)

**File:** `Sources/OpenAgentSDK/OpenAgentSDK.swift`

- [ ] Add re-export comments for TodoStore and TodoWrite tool

### Task 6: Integration & Agent Wiring

**Files:** `Sources/OpenAgentSDK/Types/AgentTypes.swift`, `Sources/OpenAgentSDK/Core/Agent.swift`

- [ ] Add `todoStore: TodoStore?` to AgentOptions
- [ ] Inject todoStore into ToolContext in Agent.swift prompt()/stream()

### Task 7: E2E Tests (future, after implementation)

**Files:** `Sources/E2ETest/`

- [ ] Add TodoStore E2E section
- [ ] Add Agent+TodoStore integration test

---

## Running Tests

```bash
# Run all failing tests for this story (will fail until implementation)
swift test --filter TodoStoreTests
swift test --filter TodoWriteToolTests

# Run specific test file
swift test --filter TodoStoreTests
swift test --filter TodoWriteToolTests

# Build only (verify compilation)
swift build
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All tests written and designed to fail
- Test files follow established patterns (CronStoreTests, CronToolsTests)
- Implementation checklist created with task-to-test mapping
- 59 total tests covering all 15 acceptance criteria

**Verification:**

- All tests fail due to missing types (TodoStore, TodoItem, TodoPriority, TodoStoreError, factory functions)
- Failure messages are clear: "use of unresolved identifier" or "cannot find type"
- Tests fail due to missing implementation, not test bugs

---

### GREEN Phase (DEV Team - Next Steps)

1. **Start with Task 1** (types) -- makes TodoItem/TodoPriority/TodoStoreError tests pass
2. **Task 2** (TodoStore actor) -- makes TodoStore operation tests pass
3. **Task 3** (ToolContext) -- makes ToolContext injection tests pass
4. **Task 4** (TodoWrite tool) -- makes all TodoWriteTool tests pass
5. **Tasks 5-6** (wiring) -- completes the feature

---

## Acceptance Criteria Coverage Matrix

| AC | Description | TodoStoreTests | TodoWriteToolTests |
|----|-------------|----------------|-------------------|
| AC1 | TodoStore Actor | testAdd_*, testToggle_*, testRemove_*, testGet_*, testList_*, testClear_*, testTodoStore_concurrentAccess, testTodoItem_*, testTodoPriority_*, testTodoStoreError_* | -- |
| AC2 | TodoWrite -- add | -- | testTodoWrite_add_success_*, testTodoWrite_add_sequentialIds |
| AC3 | TodoWrite -- toggle | -- | testTodoWrite_toggle_success_*, testTodoWrite_toggle_reopened_*, testTodoWrite_toggle_nonexistentItem_*, testTodoWrite_toggle_missingId_* |
| AC4 | TodoWrite -- remove | -- | testTodoWrite_remove_success_*, testTodoWrite_remove_nonexistentItem_*, testTodoWrite_remove_missingId_* |
| AC5 | TodoWrite -- list | -- | testTodoWrite_list_withItems_*, testTodoWrite_list_showsCheckmarks, testTodoWrite_list_empty_* |
| AC6 | TodoWrite -- clear | -- | testTodoWrite_clear_success_*, testTodoWrite_clear_emptiesStore |
| AC7 | TodoStore missing | -- | testTodoWrite_add_nilTodoStore_*, testTodoWrite_toggle_nilTodoStore_*, testTodoWrite_remove_nilTodoStore_*, testTodoWrite_list_nilTodoStore_*, testTodoWrite_clear_nilTodoStore_* |
| AC8 | inputSchema match | -- | testTodoWriteTool_hasCorrectName, testTodoWriteTool_hasValidInputSchema |
| AC9 | isReadOnly | -- | testTodoWriteTool_isNotReadOnly |
| AC10 | Module boundary | -- | testTodoWriteTool_moduleBoundary_noDirectStoreImports |
| AC11 | Error handling | -- | testTodoWrite_neverThrows_malformedInput |
| AC12 | ToolContext DI | -- | testToolContext_hasTodoStoreField, testToolContext_todoStoreDefaultsToNil, testToolContext_withAllFieldsIncludingTodoStore |
| AC13 | State queries | testGet_*, testList_*, testClear_* | (indirectly via tool tests) |
| AC14 | Unknown action | -- | testTodoWrite_unknownAction_returnsError |
| AC15 | add missing text | -- | testTodoWrite_add_missingText_returnsError, testTodoWrite_add_emptyText_returnsError |

---

## Notes

- TodoStore uses Int IDs (not String like CronStore) -- matching TS SDK
- TodoWrite is a single multi-action tool (unlike CronStore's 3 separate tools)
- TodoStore.add never throws (pure append, same as CronStore.create)
- TodoWrite.isReadOnly=false for the entire tool (even though list is read-only)
- All patterns follow Story 5-3 (CronStore) as the closest reference
- nonisolated(unsafe) required for schema dictionary constants in Swift concurrency model
- ID type is Int (matching TS SDK's number type), inputSchema uses "type": "number"

---

**Generated by BMad TEA Agent** - 2026-04-07

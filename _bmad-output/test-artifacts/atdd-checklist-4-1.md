---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-06'
inputDocuments:
  - _bmad-output/implementation-artifacts/4-1-task-store-mailbox-store.md
  - Sources/OpenAgentSDK/Types/ErrorTypes.swift
  - Sources/OpenAgentSDK/Types/SDKMessage.swift
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/OpenAgentSDK.swift
---

# ATDD Checklist: Story 4.1 -- TaskStore & MailboxStore

## TDD Red Phase (Current)

**Phase:** RED -- All tests assert expected behavior and will FAIL until implementation is complete.

- **Stack detected:** backend (Swift SPM, XCTest)
- **Generation mode:** AI generation (backend project, no browser recording needed)
- **Execution mode:** sequential (yolo mode)

## Test Files Generated

| # | File | Tests | Level | TDD Phase |
|---|------|-------|-------|-----------|
| 1 | `Tests/OpenAgentSDKTests/Stores/TaskStoreTests.swift` | 17 | Unit | RED |
| 2 | `Tests/OpenAgentSDKTests/Stores/MailboxStoreTests.swift` | 11 | Unit | RED |
| 3 | `Tests/OpenAgentSDKTests/Stores/TaskTypesTests.swift` | 6 | Unit | RED |
|   | **Total** | **34** | | |

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Names | Test Level |
|----|-------------|----------|------------|------------|
| AC1 | TaskStore Actor thread-safe | P0 | `testTaskStore_concurrentAccess` | Unit |
| AC2 | TaskStore task status transitions | P0 | `testUpdateTask_statusTransition_pendingToInProgress`, `testUpdateTask_statusTransition_inProgressToCompleted`, `testUpdateTask_statusTransition_inProgressToFailed`, `testUpdateTask_statusTransition_inProgressToCancelled`, `testUpdateTask_invalidTransition_completedIsTerminal`, `testUpdateTask_invalidTransition_failedIsTerminal`, `testUpdateTask_invalidTransition_cancelledIsTerminal` | Unit |
| AC3 | TaskStore CRUD operations | P0 | `testCreateTask_returnsTaskWithCorrectFields`, `testCreateTask_autoGeneratesId`, `testCreateTask_defaultStatusIsPending`, `testListTasks_returnsAllTasks`, `testListTasks_filterByStatus`, `testListTasks_filterByOwner`, `testListTasks_emptyStore_returnsEmpty`, `testGetTask_existingId_returnsTask`, `testGetTask_nonexistentId_returnsNil`, `testDeleteTask_existingId_returnsTrue`, `testDeleteTask_nonexistentId_returnsFalse`, `testClearTasks_resetsStore` | Unit |
| AC4 | MailboxStore Actor thread-safe | P0 | `testMailboxStore_concurrentAccess` | Unit |
| AC5 | MailboxStore message delivery | P0 | `testSend_messageDeliveredToRecipient`, `testSend_multipleMessages_queuedInOrder`, `testRead_returnsAndClearsMessages`, `testRead_emptyMailbox_returnsEmpty`, `testBroadcast_deliversToAllMailboxes`, `testHasMessages_withMessages_returnsTrue`, `testHasMessages_noMessages_returnsFalse`, `testClearAgent_clearsOnlyTargetMailbox`, `testClearAll_clearsEverything` | Unit |
| AC6 | Type definitions complete | P0 | `testTaskStatus_isCaseIterable`, `testTask_hasRequiredFields`, `testTask_implementsSendable`, `testAgentMessage_hasRequiredFields`, `testAgentMessageType_hasAllCases` | Unit |
| AC7 | Module boundary compliance | P0 | Verified by architecture (Stores/ only depends on Types/) | Static |
| AC8 | Actor test patterns | P0 | All TaskStore/MailboxStore tests use `await` for actor-isolated methods | Unit |

## Edge Cases and Error Scenarios

| Scenario | Test | Risk |
|----------|------|------|
| Update non-existent task | `testUpdateTask_nonexistentId_returnsError` | P0 |
| Invalid status transition (completed terminal) | `testUpdateTask_invalidTransition_completedIsTerminal` | P0 |
| Invalid status transition (failed terminal) | `testUpdateTask_invalidTransition_failedIsTerminal` | P0 |
| Invalid status transition (cancelled terminal) | `testUpdateTask_invalidTransition_cancelledIsTerminal` | P0 |
| Update timestamp changes on update | `testUpdateTask_updatesTimestamp` | P1 |
| Read from nonexistent agent mailbox | `testRead_emptyMailbox_returnsEmpty` | P0 |
| Clear one mailbox does not affect others | `testClearAgent_clearsOnlyTargetMailbox` | P1 |
| Concurrent access to TaskStore | `testTaskStore_concurrentAccess` | P0 |
| Concurrent access to MailboxStore | `testMailboxStore_concurrentAccess` | P0 |
| Auto-generated IDs increment atomically | `testCreateTask_autoGeneratesId` | P0 |
| Delete non-existent task returns false | `testDeleteTask_nonexistentId_returnsFalse` | P1 |
| Clear resets counter | `testClearTasks_resetsStore` | P1 |

## Test Strategy

- **Unit tests** for all TaskStore CRUD operations (create, list, get, update, delete, clear)
- **Unit tests** for all MailboxStore messaging operations (send, broadcast, read, hasMessages, clear, clearAll)
- **Unit tests** for TaskStatus, Task, AgentMessage, AgentMessageType type definitions
- **Status transition validation** covering all valid paths and all terminal state rejections
- **Concurrent access tests** verify actor isolation (no crashes under concurrent load)
- **Error path tests** for update nonexistent task, invalid transitions
- All tests follow existing naming convention: `test{MethodName}_{scenario}_{expectedBehavior}`
- All actor-isolated method calls use `await` (Swift actor pattern)
- Error assertions use `TaskStoreError` enum matching

## Implementation Endpoints

The following Swift source files need to be created:

1. **Create** `Sources/OpenAgentSDK/Types/TaskTypes.swift` -- `Task`, `TaskStatus`, `AgentMessage`, `AgentMessageType`, `TaskStoreError`
2. **Create** `Sources/OpenAgentSDK/Stores/TaskStore.swift` -- `public actor TaskStore`
3. **Create** `Sources/OpenAgentSDK/Stores/MailboxStore.swift` -- `public actor MailboxStore`
4. **Modify** `Sources/OpenAgentSDK/OpenAgentSDK.swift` -- Re-export new public types

## Red Phase Verification

- `TaskStore` symbol does NOT exist in `Sources/` -- confirmed via glob
- `MailboxStore` symbol does NOT exist in `Sources/` -- confirmed via glob
- `TaskStatus` enum does NOT exist in `Types/` -- confirmed via glob
- `AgentMessage` struct does NOT exist in `Types/` -- confirmed via glob
- `Stores/` directory does NOT exist in `Sources/` -- confirmed via ls
- Tests will fail at compile time with unresolved symbols -- expected TDD red phase behavior
- `swift build` compiles the library successfully (tests cannot compile until types are defined)

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Create `Sources/OpenAgentSDK/Types/TaskTypes.swift` with all type definitions
2. Create `Sources/OpenAgentSDK/Stores/TaskStore.swift` with actor implementation
3. Create `Sources/OpenAgentSDK/Stores/MailboxStore.swift` with actor implementation
4. Update `Sources/OpenAgentSDK/OpenAgentSDK.swift` with re-exports
5. Run `swift build` to verify compilation
6. Run `swift test` to verify all tests PASS
7. Verify `Stores/` files only import Foundation and Types/ (module boundary rule)

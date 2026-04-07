---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-07'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/5-3-cron-store-tools.md'
  - 'Tests/OpenAgentSDKTests/Stores/CronStoreTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Specialist/CronToolsTests.swift'
  - 'Sources/OpenAgentSDK/Stores/PlanStore.swift'
  - 'Sources/OpenAgentSDK/Tools/Specialist/PlanTools.swift'
---

# ATDD Checklist - Epic 5, Story 3: CronStore & Cron Tools

**Date:** 2026-04-07
**Author:** Nick
**Primary Test Level:** Unit (XCTest)

---

## Story Summary

As a developer, I want my Agent to create and manage cron jobs, so it can set up recurring or one-shot reminders.

**As a** SDK developer
**I want** CronStore Actor and CronCreate/CronDelete/CronList tools
**So that** agents can schedule, query, and remove cron jobs through the tool interface

---

## Acceptance Criteria

1. **AC1: CronStore Actor** -- CronStore implements actor-isolated create/delete/get/list/clear with thread safety; tracks CronJob state (id, name, schedule, command, enabled, createdAt, lastRunAt, nextRunAt).
2. **AC2: CronCreate Tool** -- Factory function creates CronCreate tool; when called with name/schedule/command, creates job in CronStore and returns confirmation with id.
3. **AC3: CronDelete Tool** -- Factory function creates CronDelete tool; when called with id, removes job or returns is_error=true if not found.
4. **AC4: CronList Tool** -- Factory function creates CronList tool; lists all jobs or returns "No cron jobs scheduled." when empty.
5. **AC5: CronStore missing error** -- When cronStore is nil in ToolContext, all cron tools return is_error=true.
6. **AC6: inputSchema matches TS SDK** -- CronCreate has name/schedule/command (all required); CronDelete has id (required); CronList has empty properties.
7. **AC7: isReadOnly classification** -- CronCreate=false, CronDelete=false, CronList=true.
8. **AC8: Module boundary compliance** -- CronStore in Stores/ imports only Foundation+Types; CronTools in Tools/Specialist/ imports only Foundation+Types.
9. **AC9: Error handling** -- Errors captured as ToolExecuteResult(isError:true), never thrown from tool handlers.
10. **AC10: ToolContext dependency injection** -- cronStore injected via ToolContext, consistent with WorktreeTool/PlanTool patterns.
11. **AC11: CronStore state queries** -- get(id:) returns job or nil; list() returns all; clear() resets all state.

---

## Failing Tests Created (RED Phase)

### Unit Tests -- CronStore (20 tests)

**File:** `Tests/OpenAgentSDKTests/Stores/CronStoreTests.swift`

- **Test:** testCreate_returnsJobWithCorrectFields
  - **Status:** RED - CronStore/CronJob types not yet implemented
  - **Verifies:** AC1 -- create returns CronJob with correct fields (id, name, schedule, command, enabled, createdAt)

- **Test:** testCreate_autoGeneratesSequentialIds
  - **Status:** RED - CronStore not yet implemented
  - **Verifies:** AC1 -- sequential IDs (cron_1, cron_2, cron_3)

- **Test:** testCreate_defaultEnabledIsTrue
  - **Status:** RED - CronJob not yet implemented
  - **Verifies:** AC1 -- enabled defaults to true

- **Test:** testCreate_doesNotThrow
  - **Status:** RED - CronStore not yet implemented
  - **Verifies:** AC1 -- create is a pure append, never throws

- **Test:** testDelete_existingId_succeeds
  - **Status:** RED - CronStore not yet implemented
  - **Verifies:** AC1 -- delete removes job from store

- **Test:** testDelete_nonexistentId_throwsCronJobNotFound
  - **Status:** RED - CronStoreError not yet implemented
  - **Verifies:** AC1, AC3 -- delete throws cronJobNotFound for missing id

- **Test:** testGet_existingId_returnsJob
  - **Status:** RED - CronStore not yet implemented
  - **Verifies:** AC11 -- get retrieves job by id

- **Test:** testGet_nonexistentId_returnsNil
  - **Status:** RED - CronStore not yet implemented
  - **Verifies:** AC11 -- get returns nil for missing id

- **Test:** testList_returnsAllJobs
  - **Status:** RED - CronStore not yet implemented
  - **Verifies:** AC11 -- list returns all created jobs

- **Test:** testList_emptyStore_returnsEmpty
  - **Status:** RED - CronStore not yet implemented
  - **Verifies:** AC11 -- list returns empty array for empty store

- **Test:** testClear_resetsStore
  - **Status:** RED - CronStore not yet implemented
  - **Verifies:** AC11 -- clear resets jobs and counter

- **Test:** testCronStore_concurrentAccess
  - **Status:** RED - CronStore not yet implemented
  - **Verifies:** AC1 -- actor isolation survives concurrent access

- **Test:** testCronJob_equality
  - **Status:** RED - CronJob type not yet implemented
  - **Verifies:** AC1 -- CronJob conforms to Equatable

- **Test:** testCronJob_codable
  - **Status:** RED - CronJob type not yet implemented
  - **Verifies:** AC1 -- CronJob conforms to Codable (full round-trip)

- **Test:** testCronJob_codable_withNilOptionals
  - **Status:** RED - CronJob type not yet implemented
  - **Verifies:** AC1 -- Codable round-trip with nil optional fields

- **Test:** testCronStoreError_equality
  - **Status:** RED - CronStoreError not yet implemented
  - **Verifies:** AC1 -- CronStoreError conforms to Equatable

- **Test:** testCronStoreError_cronJobNotFound_description
  - **Status:** RED - CronStoreError not yet implemented
  - **Verifies:** AC1 -- cronJobNotFound error description includes id

### Unit Tests -- CronTools (25 tests)

**File:** `Tests/OpenAgentSDKTests/Tools/Specialist/CronToolsTests.swift`

- **Test:** testCreateCronCreateTool_returnsToolProtocol
  - **Status:** RED - createCronCreateTool() not yet implemented
  - **Verifies:** AC2 -- factory returns ToolProtocol named "CronCreate"

- **Test:** testCreateCronCreateTool_hasValidInputSchema
  - **Status:** RED - cronCreateSchema not yet implemented
  - **Verifies:** AC6 -- schema has name/schedule/command (all required)

- **Test:** testCreateCronCreateTool_isNotReadOnly
  - **Status:** RED - createCronCreateTool() not yet implemented
  - **Verifies:** AC7 -- CronCreate isReadOnly = false

- **Test:** testCronCreate_success_returnsConfirmation
  - **Status:** RED - CronStore/createCronCreateTool not yet implemented
  - **Verifies:** AC2 -- create returns success with confirmation

- **Test:** testCronCreate_success_includesJobId
  - **Status:** RED - CronStore not yet implemented
  - **Verifies:** AC2 -- create confirmation includes auto-generated ID

- **Test:** testCronCreate_nilCronStore_returnsError
  - **Status:** RED - createCronCreateTool not yet implemented
  - **Verifies:** AC5 -- returns is_error=true when cronStore is nil

- **Test:** testCreateCronDeleteTool_returnsToolProtocol
  - **Status:** RED - createCronDeleteTool() not yet implemented
  - **Verifies:** AC3 -- factory returns ToolProtocol named "CronDelete"

- **Test:** testCreateCronDeleteTool_hasValidInputSchema
  - **Status:** RED - cronDeleteSchema not yet implemented
  - **Verifies:** AC6 -- schema has id (required)

- **Test:** testCreateCronDeleteTool_isNotReadOnly
  - **Status:** RED - createCronDeleteTool() not yet implemented
  - **Verifies:** AC7 -- CronDelete isReadOnly = false

- **Test:** testCronDelete_success_returnsConfirmation
  - **Status:** RED - CronStore/createCronDeleteTool not yet implemented
  - **Verifies:** AC3 -- delete returns success with deleted id

- **Test:** testCronDelete_nonexistentJob_returnsError
  - **Status:** RED - CronStore/createCronDeleteTool not yet implemented
  - **Verifies:** AC3 -- delete returns is_error=true for missing job

- **Test:** testCronDelete_nilCronStore_returnsError
  - **Status:** RED - createCronDeleteTool not yet implemented
  - **Verifies:** AC5 -- returns is_error=true when cronStore is nil

- **Test:** testCreateCronListTool_returnsToolProtocol
  - **Status:** RED - createCronListTool() not yet implemented
  - **Verifies:** AC4 -- factory returns ToolProtocol named "CronList"

- **Test:** testCreateCronListTool_hasValidInputSchema
  - **Status:** RED - cronListSchema not yet implemented
  - **Verifies:** AC6 -- schema has empty properties, no required fields

- **Test:** testCreateCronListTool_isReadOnly
  - **Status:** RED - createCronListTool() not yet implemented
  - **Verifies:** AC7 -- CronList isReadOnly = true

- **Test:** testCronList_withJobs_returnsFormattedList
  - **Status:** RED - CronStore/createCronListTool not yet implemented
  - **Verifies:** AC4 -- list returns formatted output with job names

- **Test:** testCronList_empty_returnsNoJobsMessage
  - **Status:** RED - CronStore/createCronListTool not yet implemented
  - **Verifies:** AC4 -- list returns "No cron jobs scheduled." when empty

- **Test:** testCronList_nilCronStore_returnsError
  - **Status:** RED - createCronListTool not yet implemented
  - **Verifies:** AC5 -- returns is_error=true when cronStore is nil

- **Test:** testCronCreate_neverThrows_malformedInput
  - **Status:** RED - createCronCreateTool not yet implemented
  - **Verifies:** AC9 -- tool never throws, always returns ToolResult

- **Test:** testCronDelete_neverThrows_malformedInput
  - **Status:** RED - createCronDeleteTool not yet implemented
  - **Verifies:** AC9 -- tool never throws, always returns ToolResult

- **Test:** testCronList_neverThrows_malformedInput
  - **Status:** RED - createCronListTool not yet implemented
  - **Verifies:** AC9 -- tool never throws, always returns ToolResult

- **Test:** testToolContext_hasCronStoreField
  - **Status:** RED - ToolContext.cronStore not yet added
  - **Verifies:** AC10 -- ToolContext has cronStore field

- **Test:** testToolContext_cronStoreDefaultsToNil
  - **Status:** RED - ToolContext.cronStore not yet added
  - **Verifies:** AC10 -- cronStore defaults to nil (backward compatible)

- **Test:** testToolContext_withAllFieldsIncludingCronStore
  - **Status:** RED - ToolContext.cronStore not yet added
  - **Verifies:** AC10 -- ToolContext accepts all stores including cronStore

- **Test:** testCronTools_moduleBoundary_noDirectStoreImports
  - **Status:** RED - Cron tools not yet implemented
  - **Verifies:** AC8 -- tools work via ToolContext injection, no direct store imports

- **Test:** testIntegration_createListDelete_fullLifecycle
  - **Status:** RED - All cron tools not yet implemented
  - **Verifies:** AC2, AC3, AC4 -- full create-list-delete lifecycle

- **Test:** testIntegration_createMultiple_listAll
  - **Status:** RED - All cron tools not yet implemented
  - **Verifies:** AC2, AC4 -- create multiple jobs and list them all

---

## Implementation Checklist

### Task 1: Define Cron Types (AC: #1, #8)

**File:** `Sources/OpenAgentSDK/Types/TaskTypes.swift`

**Tasks to make CronStore type tests pass:**

- [ ] Add `CronJob` struct with id, name, schedule, command, enabled, createdAt, lastRunAt, nextRunAt
- [ ] Add `CronStoreError` enum with cronJobNotFound(id) case
- [ ] Ensure both conform to Sendable, Equatable, Codable
- [ ] Run tests: `swift test --filter CronStoreTests`

### Task 2: Implement CronStore Actor (AC: #1, #11)

**File:** `Sources/OpenAgentSDK/Stores/CronStore.swift` (new file)

**Tasks to make CronStore tests pass:**

- [ ] Create `CronStore` actor with private jobs dictionary and jobCounter
- [ ] Implement `create(name:schedule:command:)` returning CronJob with auto-generated ID
- [ ] Implement `delete(id:)` throwing CronStoreError.cronJobNotFound
- [ ] Implement `get(id:)` returning optional CronJob
- [ ] Implement `list()` returning [CronJob]
- [ ] Implement `clear()` resetting jobs and counter
- [ ] Use ISO8601DateFormatter with .withInternetDateTime and .withFractionalSeconds
- [ ] Run tests: `swift test --filter CronStoreTests`

### Task 3: Extend ToolContext (AC: #10)

**File:** `Sources/OpenAgentSDK/Types/ToolTypes.swift`

**Tasks to make ToolContext tests pass:**

- [ ] Add `cronStore: CronStore?` field to ToolContext
- [ ] Add cronStore parameter to init with default value nil
- [ ] Run tests: `swift test --filter CronToolsTests/testToolContext`

### Task 4: Implement CronCreate Tool (AC: #2, #5, #6, #7, #8, #9)

**File:** `Sources/OpenAgentSDK/Tools/Specialist/CronTools.swift` (new file)

**Tasks to make CronCreate tests pass:**

- [ ] Define `CronCreateInput` Codable struct with name, schedule, command
- [ ] Define `cronCreateSchema` with name/schedule/command (all required)
- [ ] Implement `createCronCreateTool()` factory function with isReadOnly=false
- [ ] Handle nil cronStore returning is_error=true
- [ ] Return confirmation with job ID and name
- [ ] Run tests: `swift test --filter CronToolsTests/testCreateCronCreateTool`

### Task 5: Implement CronDelete Tool (AC: #3, #5, #6, #7, #8, #9)

**File:** `Sources/OpenAgentSDK/Tools/Specialist/CronTools.swift` (same file)

**Tasks to make CronDelete tests pass:**

- [ ] Define `CronDeleteInput` Codable struct with id
- [ ] Define `cronDeleteSchema` with id (required)
- [ ] Implement `createCronDeleteTool()` factory function with isReadOnly=false
- [ ] Handle nil cronStore returning is_error=true
- [ ] Catch CronStoreError.cronJobNotFound returning is_error=true
- [ ] Run tests: `swift test --filter CronToolsTests/testCreateCronDeleteTool`

### Task 6: Implement CronList Tool (AC: #4, #5, #6, #7, #8, #9)

**File:** `Sources/OpenAgentSDK/Tools/Specialist/CronTools.swift` (same file)

**Tasks to make CronList tests pass:**

- [ ] Define `CronListInput` empty Codable struct
- [ ] Define `cronListSchema` with empty properties
- [ ] Implement `createCronListTool()` factory function with isReadOnly=true
- [ ] Handle nil cronStore returning is_error=true
- [ ] Format output: checkmark, name, schedule, truncated command
- [ ] Return "No cron jobs scheduled." when empty
- [ ] Run tests: `swift test --filter CronToolsTests/testCreateCronListTool`

### Task 7: Update Module Entry (AC: #8)

**File:** `Sources/OpenAgentSDK/OpenAgentSDK.swift`

- [ ] Add re-export comments for CronStore and Cron tools

### Task 8: Integration & Agent Wiring

**Files:** `Sources/OpenAgentSDK/Types/AgentTypes.swift`, `Sources/OpenAgentSDK/Core/Agent.swift`

- [ ] Add `cronStore: CronStore?` to AgentOptions
- [ ] Inject cronStore into ToolContext in Agent.swift prompt()/stream()

### Task 9: E2E Tests (future, after implementation)

**Files:** `Sources/E2ETest/StoreTests.swift`, `Sources/E2ETest/IntegrationTests.swift`

- [ ] Add CronStore E2E section to StoreTests
- [ ] Add Agent+CronStore integration test to IntegrationTests
- [ ] Update main.swift section numbers

---

## Running Tests

```bash
# Run all failing tests for this story (will fail until implementation)
swift test --filter CronStoreTests
swift test --filter CronToolsTests

# Run specific test file
swift test --filter CronStoreTests
swift test --filter CronToolsTests

# Build only (verify compilation)
swift build
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- All tests written and designed to fail
- Test files follow established patterns (PlanStoreTests, PlanToolsTests)
- Implementation checklist created with task-to-test mapping
- 45 total tests covering all 11 acceptance criteria

**Verification:**

- All tests will fail due to missing types (CronStore, CronJob, CronStoreError, factory functions)
- Failure messages are clear: "use of unresolved identifier" or "cannot find type"
- Tests fail due to missing implementation, not test bugs

---

### GREEN Phase (DEV Team - Next Steps)

1. **Start with Task 1** (types) -- makes CronJob/CronStoreError tests pass
2. **Task 2** (CronStore actor) -- makes CronStore operation tests pass
3. **Task 3** (ToolContext) -- makes ToolContext injection tests pass
4. **Tasks 4-6** (Cron tools) -- makes all CronTools tests pass
5. **Tasks 7-8** (wiring) -- completes the feature

---

## Acceptance Criteria Coverage Matrix

| AC | Description | CronStoreTests | CronToolsTests |
|----|-------------|----------------|----------------|
| AC1 | CronStore Actor | testCreate_*, testDelete_*, testGet_*, testList_*, testClear_*, testCronStore_concurrentAccess, testCronJob_*, testCronStoreError_* | -- |
| AC2 | CronCreate Tool | -- | testCreateCronCreateTool_*, testCronCreate_success_* |
| AC3 | CronDelete Tool | -- | testCreateCronDeleteTool_*, testCronDelete_success_*, testCronDelete_nonexistentJob_* |
| AC4 | CronList Tool | -- | testCreateCronListTool_*, testCronList_withJobs_*, testCronList_empty_* |
| AC5 | CronStore missing | -- | testCronCreate_nilCronStore_*, testCronDelete_nilCronStore_*, testCronList_nilCronStore_* |
| AC6 | inputSchema match | -- | testCreateCronCreateTool_hasValidInputSchema, testCreateCronDeleteTool_hasValidInputSchema, testCreateCronListTool_hasValidInputSchema |
| AC7 | isReadOnly | -- | testCreateCronCreateTool_isNotReadOnly, testCreateCronDeleteTool_isNotReadOnly, testCreateCronListTool_isReadOnly |
| AC8 | Module boundary | -- | testCronTools_moduleBoundary_noDirectStoreImports |
| AC9 | Error handling | -- | testCronCreate_neverThrows_*, testCronDelete_neverThrows_*, testCronList_neverThrows_* |
| AC10 | ToolContext DI | -- | testToolContext_hasCronStoreField, testToolContext_cronStoreDefaultsToNil, testToolContext_withAllFieldsIncludingCronStore |
| AC11 | State queries | testGet_*, testList_*, testClear_* | (indirectly via tool tests) |

---

## Notes

- CronStore is simpler than PlanStore/WorktreeStore -- no active state tracking, no git operations
- CronStore.create never throws (pure append, unlike PlanStore.enterPlanMode which can throw alreadyInPlanMode)
- CronList is the only read-only tool among the three (isReadOnly=true)
- All patterns follow Story 5-2 (PlanStore) as the closest reference
- nonisolated(unsafe) required for schema dictionary constants in Swift concurrency model

---

**Generated by BMad TEA Agent** - 2026-04-07

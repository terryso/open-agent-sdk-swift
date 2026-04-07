---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
lastStep: step-04-generate-tests
lastSaved: '2026-04-07'
storyId: 5-2
storyTitle: PlanStore & Plan Tools (EnterPlanMode / ExitPlanMode)
inputDocuments:
  - _bmad-output/implementation-artifacts/5-2-plan-store-tools.md
  - Sources/OpenAgentSDK/Types/TaskTypes.swift
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Sources/OpenAgentSDK/Stores/WorktreeStore.swift
  - Sources/OpenAgentSDK/Tools/Specialist/WorktreeTools.swift
  - Tests/OpenAgentSDKTests/Stores/WorktreeStoreTests.swift
  - Tests/OpenAgentSDKTests/Tools/Specialist/WorktreeToolsTests.swift
---

# ATDD Checklist -- Story 5-2: PlanStore & Plan Tools

## Generation Mode: AI Generation (Backend/Swift)

**Stack:** backend (Swift Package Manager, XCTest)
**Framework:** XCTest
**TDD Phase:** RED (failing tests)

---

## Test Strategy: AC-to-Test Mapping

### PlanStoreTests.swift (Unit Level)

| # | AC | Priority | Test Name | Level | Description |
|---|----|----------|-----------|-------|-------------|
| 1 | AC1 | P0 | `testEnterPlanMode_returnsEntryWithCorrectFields` | Unit | enterPlanMode creates PlanEntry with correct id, status=active, approved=false, content=nil |
| 2 | AC1 | P0 | `testEnterPlanMode_autoGeneratesSequentialIds` | Unit | Sequential IDs: plan_1, plan_2, ... |
| 3 | AC1 | P0 | `testEnterPlanMode_defaultStatusIsActive` | Unit | New plan status defaults to .active |
| 4 | AC1 | P0 | `testEnterPlanMode_duplicate_throwsAlreadyInPlanMode` | Unit | Entering plan mode when already active throws PlanStoreError.alreadyInPlanMode |
| 5 | AC3 | P0 | `testExitPlanMode_withPlanAndApproved_returnsCompletedEntry` | Unit | Exiting with plan content and approved=true updates status to completed |
| 6 | AC3 | P0 | `testExitPlanMode_withoutPlan_returnsCompletedEntry` | Unit | Exiting without plan content still completes |
| 7 | AC3 | P0 | `testExitPlanMode_noActivePlan_throwsNoActivePlan` | Unit | Exiting when no plan active throws PlanStoreError.noActivePlan |
| 8 | AC3 | P0 | `testExitPlanMode_approvedDefaultsToTrue` | Unit | When approved is nil, defaults to true |
| 9 | AC11 | P0 | `testGetCurrentPlan_withActivePlan_returnsEntry` | Unit | Returns active plan entry |
| 10 | AC11 | P0 | `testGetCurrentPlan_noActivePlan_returnsNil` | Unit | Returns nil when no active plan |
| 11 | AC11 | P0 | `testIsActive_trueAfterEnter_falseAfterExit` | Unit | isActive reflects plan mode state |
| 12 | AC1 | P0 | `testGet_existingId_returnsEntry` | Unit | Get by ID returns correct plan |
| 13 | AC1 | P0 | `testGet_nonexistentId_returnsNil` | Unit | Get by non-existent ID returns nil |
| 14 | AC1 | P1 | `testList_returnsAllEntries` | Unit | List returns all stored plans |
| 15 | AC1 | P1 | `testList_emptyStore_returnsEmpty` | Unit | Empty store returns empty list |
| 16 | AC1 | P1 | `testClear_resetsStore` | Unit | Clear empties store and resets counter |
| 17 | AC1 | P0 | `testPlanStore_concurrentAccess` | Unit | Concurrent access via actor isolation (no crash) |
| 18 | AC1 | P0 | `testPlanStatus_rawValues` | Unit | PlanStatus raw values: active, completed, discarded |
| 19 | AC1 | P0 | `testPlanEntry_equality` | Unit | PlanEntry Equatable conformance |
| 20 | AC1 | P0 | `testPlanEntry_codable` | Unit | PlanEntry Codable round-trip |
| 21 | AC1 | P0 | `testPlanStoreError_equality` | Unit | PlanStoreError Equatable conformance |
| 22 | AC1 | P0 | `testPlanStoreError_planNotFound_description` | Unit | Error description for planNotFound |
| 23 | AC1 | P0 | `testPlanStoreError_noActivePlan_description` | Unit | Error description for noActivePlan |
| 24 | AC1 | P0 | `testPlanStoreError_alreadyInPlanMode_description` | Unit | Error description for alreadyInPlanMode |

### PlanToolsTests.swift (Unit Level)

| # | AC | Priority | Test Name | Level | Description |
|---|----|----------|-----------|-------|-------------|
| 25 | AC2 | P0 | `testCreateEnterPlanModeTool_returnsToolProtocol` | Unit | Factory returns ToolProtocol with name "EnterPlanMode" |
| 26 | AC6 | P0 | `testCreateEnterPlanModeTool_hasValidInputSchema` | Unit | inputSchema: type=object, empty properties, no required fields |
| 27 | AC7 | P0 | `testCreateEnterPlanModeTool_isNotReadOnly` | Unit | isReadOnly == false |
| 28 | AC2 | P0 | `testEnterPlanMode_success_returnsConfirmation` | Unit | Successful enter returns non-error confirmation |
| 29 | AC4 | P0 | `testEnterPlanMode_alreadyInPlanMode_returnsAlreadyInPlanMessage` | Unit | When already in plan mode, returns "Already in plan mode" (NOT isError) |
| 30 | AC5 | P0 | `testEnterPlanMode_nilPlanStore_returnsError` | Unit | planStore=nil returns isError=true |
| 31 | AC3 | P0 | `testCreateExitPlanModeTool_returnsToolProtocol` | Unit | Factory returns ToolProtocol with name "ExitPlanMode" |
| 32 | AC6 | P0 | `testCreateExitPlanModeTool_hasValidInputSchema` | Unit | inputSchema: type=object, properties has plan(string) and approved(boolean), no required |
| 33 | AC7 | P0 | `testCreateExitPlanModeTool_isNotReadOnly` | Unit | isReadOnly == false |
| 34 | AC3 | P0 | `testExitPlanMode_withPlanAndApproved_returnsSuccess` | Unit | Exit with plan content and approved=true returns success |
| 35 | AC3 | P0 | `testExitPlanMode_notInPlanMode_returnsError` | Unit | Exit without active plan returns isError=true |
| 36 | AC5 | P0 | `testExitPlanMode_nilPlanStore_returnsError` | Unit | planStore=nil returns isError=true |
| 37 | AC9 | P0 | `testEnterPlanMode_neverThrows_malformedInput` | Unit | Tool never throws, always returns ToolResult |
| 38 | AC9 | P0 | `testExitPlanMode_neverThrows_malformedInput` | Unit | Tool never throws, always returns ToolResult |
| 39 | AC10 | P0 | `testToolContext_hasPlanStoreField` | Unit | ToolContext has planStore field |
| 40 | AC10 | P0 | `testToolContext_planStoreDefaultsToNil` | Unit | ToolContext.planStore defaults to nil |
| 41 | AC10 | P0 | `testToolContext_withAllFieldsIncludingPlanStore` | Unit | ToolContext can be created with all fields |
| 42 | AC8 | P0 | `testPlanTools_moduleBoundary_noDirectStoreImports` | Unit | Tools work through injection, no direct store imports |
| 43 | -- | P1 | `testIntegration_enterThenExitPlanMode` | Integration | Enter plan mode then exit with plan content |
| 44 | -- | P1 | `testIntegration_enterPlanModeTwice_returnsAlreadyInPlanMode` | Integration | Double-enter returns already-in-plan-mode message |

---

## TDD Red Phase Requirements

All tests assert **expected** behavior. They will **FAIL** until:

1. `PlanStatus` enum defined with `active`, `completed`, `discarded` cases
2. `PlanEntry` struct defined with `id`, `content`, `approved`, `status`, `createdAt`, `updatedAt` fields
3. `PlanStoreError` enum defined with `planNotFound(id)`, `noActivePlan`, `alreadyInPlanMode` cases
4. `PlanStore` actor implemented with `enterPlanMode()`, `exitPlanMode(plan:approved:)`, `getCurrentPlan()`, `isActive()`, `get(id:)`, `list()`, `clear()` methods
5. `ToolContext` has `planStore: PlanStore?` field
6. `AgentOptions` has `planStore: PlanStore?` field
7. `createEnterPlanModeTool()` factory function implemented
8. `createExitPlanModeTool()` factory function implemented

---

## Test Files Created

1. `Tests/OpenAgentSDKTests/Stores/PlanStoreTests.swift` -- PlanStore actor unit tests (24 tests)
2. `Tests/OpenAgentSDKTests/Tools/Specialist/PlanToolsTests.swift` -- Plan tools unit + integration tests (20 tests)

**Total: 44 tests across 2 files**

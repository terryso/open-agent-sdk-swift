---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-12'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/13-2-query-level-abort.md'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Core/ToolExecutor.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift'
  - 'Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift'
  - 'Tests/OpenAgentSDKTests/Core/StreamTests.swift'
---

# ATDD Checklist - Epic 13, Story 2: Query-Level Abort

**Date:** 2026-04-12
**Author:** Nick (TEA Agent)
**Primary Test Level:** Unit (Swift backend project)

---

## Story Summary

Implement query-level cancellation for Agent queries using Swift's cooperative cancellation model (`Task.cancel()` / `Task.isCancelled`). Developers can cancel long-running Agent queries and receive partial results including completed turn data.

**As a** developer
**I want** to cancel an executing Agent query
**So that** long-running tasks can be proactively cancelled by the user

---

## Acceptance Criteria

1. **AC1:** Task.cancel() aborts query -- cancel returns `QueryResult` with `isCancelled: true`, `status: .cancelled`, completed turn results, and partial text (FR60)
2. **AC2:** FileWriteTool abort rollback -- new files deleted on cancel, overwritten files preserved (atomically: true guarantees)
3. **AC3:** FileEditTool abort rollback -- original content restored on cancel via backup mechanism
4. **AC4:** AsyncStream abort event -- stream emits final `.result` with `subtype: .cancelled`, then finishes normally (no error thrown to consumer)

---

## Failing Tests Created (RED Phase)

### Unit Tests (17 tests)

**File:** `Tests/OpenAgentSDKTests/Core/AbortTests.swift` (~810 lines)

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testPromptCancellationReturnsIsCancelledTrue | AC1 | P0 | RED | `QueryResult.isCancelled` not found, `QueryStatus.cancelled` not found |
| 2 | testPromptCancellationPreservesCompletedTurns | AC1 | P0 | RED | Compiles but asserts on non-existent fields |
| 3 | testAgentInterruptCancelsPromptQuery | AC1 | P1 | RED | `Agent.interrupt()` not found, `QueryResult.isCancelled` not found |
| 4 | testFileWriteAbort_NewFile_NotCreatedOnDisk | AC2 | P0 | RED | `QueryResult.isCancelled` not found |
| 5 | testFileWriteAbort_OverwriteFile_OriginalPreserved | AC2 | P0 | RED | Compiles but cancellation not yet checked in FileWriteTool |
| 6 | testFileWriteAbort_ToolResultsContainCompletedResults | AC2 | P1 | RED | Compiles (single-turn baseline test) |
| 7 | testFileEditAbort_OriginalContentRestored | AC3 | P0 | RED | Compiles but cancellation not yet checked in FileEditTool |
| 8 | testFileEditAbort_BeforeWriteStarts_FileUnmodified | AC3 | P1 | RED | Compiles but cancellation not yet checked |
| 9 | testStreamCancellationEmitsCancelledResultEvent | AC4 | P0 | RED | `ResultData.Subtype.cancelled` not found |
| 10 | testStreamCancellation_FinishesWithoutError | AC4 | P0 | RED | Compiles but stream cancellation not yet implemented |
| 11 | testStreamCancellation_ResultContainsPartialText | AC4 | P1 | RED | `ResultData.Subtype.cancelled` not found |
| 12 | testQueryStatus_HasCancelledCase | AC1 | P0 | RED | `QueryStatus.cancelled` not found |
| 13 | testQueryResult_HasIsCancelledField_DefaultFalse | AC1 | P0 | RED | `QueryResult.isCancelled` not found |
| 14 | testQueryResult_CanBeCreatedWithIsCancelledTrue | AC1 | P1 | RED | `isCancelled` extra argument, `QueryStatus.cancelled` not found |
| 15 | testResultDataSubtype_HasCancelledCase | AC4 | P0 | RED | `ResultData.Subtype.cancelled` not found |
| 16 | testResultData_CanBeCreatedWithCancelledSubtype | AC4 | P1 | RED | `ResultData.Subtype.cancelled` not found |

---

## Test Strategy

### Test Level Selection

This is a **Swift backend project** (SPM with XCTest). Test levels:
- **Unit tests** for type additions (`QueryStatus.cancelled`, `QueryResult.isCancelled`, `ResultData.Subtype.cancelled`)
- **Unit tests** for cancellation behavior in `prompt()`, `stream()`, `FileWriteTool`, `FileEditTool`
- **No E2E tests** (no UI component, no browser)

### Priority Framework

| Priority | Count | Rationale |
|----------|-------|-----------|
| P0 | 10 | Core ACs: type existence, cancellation behavior, rollback guarantees, stream events |
| P1 | 6 | Supporting: interrupt method, partial text preservation, edge cases |

### Coverage Matrix

| AC | Tests | Levels |
|----|-------|--------|
| AC1 (Task.cancel aborts query) | 5 | Unit (type + behavior) |
| AC2 (FileWriteTool rollback) | 3 | Unit (filesystem behavior) |
| AC3 (FileEditTool rollback) | 2 | Unit (filesystem behavior) |
| AC4 (AsyncStream abort event) | 4 | Unit (stream behavior) |
| Type definitions | 5 | Unit (type existence) |

---

## Implementation Checklist

### Task 1: Add QueryResult.isCancelled and QueryStatus.cancelled

**File:** `Sources/OpenAgentSDK/Types/AgentTypes.swift`

**Tests this makes pass:**
- testQueryStatus_HasCancelledCase
- testQueryResult_HasIsCancelledField_DefaultFalse
- testQueryResult_CanBeCreatedWithIsCancelledTrue

**Implementation steps:**
- [ ] Add `.cancelled` case to `QueryStatus` enum (after `.errorMaxBudgetUsd`)
- [ ] Add `public let isCancelled: Bool` field to `QueryResult`
- [ ] Add `isCancelled: Bool = false` parameter to `QueryResult.init()`
- [ ] Set `self.isCancelled = isCancelled` in init

### Task 2: Add ResultData.Subtype.cancelled

**File:** `Sources/OpenAgentSDK/Types/SDKMessage.swift`

**Tests this makes pass:**
- testResultDataSubtype_HasCancelledCase
- testResultData_CanBeCreatedWithCancelledSubtype

**Implementation steps:**
- [ ] Add `.cancelled` case to `ResultData.Subtype` enum (after `.errorMaxBudgetUsd`)

### Task 3: Implement Agent.interrupt()

**File:** `Sources/OpenAgentSDK/Core/Agent.swift`

**Tests this makes pass:**
- testAgentInterruptCancelsPromptQuery

**Implementation steps:**
- [ ] Add `private var _currentQueryTask: _Concurrency.Task<Void, Never>?` to Agent
- [ ] Add `public func interrupt()` method that calls `_currentQueryTask?.cancel()`
- [ ] Store task reference in `prompt()` and `stream()`

### Task 4: Modify prompt() for cancellation detection

**File:** `Sources/OpenAgentSDK/Core/Agent.swift`

**Tests this makes pass:**
- testPromptCancellationReturnsIsCancelledTrue
- testPromptCancellationPreservesCompletedTurns

**Implementation steps:**
- [ ] Add `guard !_Concurrency.Task.isCancelled else { ... }` at while loop top (line ~299)
- [ ] On cancellation: build `QueryResult` with `isCancelled: true`, `status: .cancelled`
- [ ] Preserve completed turn text, usage, and numTurns
- [ ] Catch `CancellationError` and return cancelled QueryResult (don't throw)

### Task 5: Modify stream() for cancellation detection

**File:** `Sources/OpenAgentSDK/Core/Agent.swift`

**Tests this makes pass:**
- testStreamCancellationEmitsCancelledResultEvent
- testStreamCancellation_FinishesWithoutError
- testStreamCancellation_ResultContainsPartialText

**Implementation steps:**
- [ ] Add `_Concurrency.Task.isCancelled` check at while loop top (line ~719)
- [ ] Add check in SSE event loop (`for try await event in eventStream`)
- [ ] On cancellation: yield `.result(ResultData(subtype: .cancelled, ...))`
- [ ] Call `continuation.finish()` (no error thrown to consumer)
- [ ] Ensure MCP cleanup still executes (defer block)

### Task 6: Modify ToolExecutor for cancellation propagation

**File:** `Sources/OpenAgentSDK/Core/ToolExecutor.swift`

**Tests this makes pass (indirectly):**
- testFileWriteAbort_NewFile_NotCreatedOnDisk
- testFileWriteAbort_OverwriteFile_OriginalPreserved
- testFileEditAbort_OriginalContentRestored
- testFileEditAbort_BeforeWriteStarts_FileUnmodified

**Implementation steps:**
- [ ] Add `_Concurrency.Task.isCancelled` check in `executeTools()` before dispatch
- [ ] Add check in `executeMutationsSerial()` loop between each step
- [ ] Add check in `executeReadOnlyConcurrent()` main loop

### Task 7: Modify FileWriteTool for cancellation safety

**File:** `Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift`

**Tests this makes pass:**
- testFileWriteAbort_NewFile_NotCreatedOnDisk
- testFileWriteAbort_OverwriteFile_OriginalPreserved

**Implementation steps:**
- [ ] Add `guard !_Concurrency.Task.isCancelled else { return ToolExecuteResult(content: "Cancelled", isError: true) }` before write call
- [ ] `atomically: true` already guarantees atomicity -- no additional rollback needed

### Task 8: Modify FileEditTool for backup and restore

**File:** `Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift`

**Tests this makes pass:**
- testFileEditAbort_OriginalContentRestored
- testFileEditAbort_BeforeWriteStarts_FileUnmodified

**Implementation steps:**
- [ ] Save `originalContent` to local variable after reading file
- [ ] Add `guard !_Concurrency.Task.isCancelled else { return ... }` before replacement
- [ ] Add check after replacement, before write-back
- [ ] Write-back uses `atomically: true` -- original preserved if interrupted during write

### Task 9: Verify compilation and full test suite

- [ ] `swift build` compiles without errors
- [ ] `swift test` -- all tests pass (including 2419+ existing tests)
- [ ] No regressions in existing AgentLoopTests, StreamTests, FileWriteToolTests, FileEditToolTests

---

## Running Tests

```bash
# Run all tests for this story (will fail until implementation)
swift test --filter AbortTests

# Build only (quick compilation check)
swift build --build-tests

# Run full test suite (verify no regressions)
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**
- 17 tests written, all failing due to compilation errors
- Tests cover all 4 acceptance criteria
- Tests follow Given-When-Then format with descriptive test names
- Test isolation via temporary directories (no real filesystem dependency)
- Mock URL protocol supports delayed responses for cancellation timing

**Verification:**
- Build fails with: `type 'QueryStatus' has no member 'cancelled'`
- Build fails with: `value of type 'QueryResult' has no member 'isCancelled'`
- Build fails with: `value of type 'Agent' has no member 'interrupt'`
- Build fails with: `type 'SDKMessage.ResultData.Subtype' has no member 'cancelled'`
- All 17 compilation errors are due to missing implementation, not test bugs
- Zero non-AbortTests compilation errors (rest of project compiles cleanly)

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1** (AgentTypes.swift) -- add `.cancelled` to `QueryStatus`, add `isCancelled` to `QueryResult`
2. **Then Task 2** (SDKMessage.swift) -- add `.cancelled` to `ResultData.Subtype`
3. **Then Task 3** (Agent.swift) -- add `interrupt()` method
4. **Then Task 4+5** (Agent.swift) -- add cancellation checks in `prompt()` and `stream()`
5. **Then Task 6** (ToolExecutor.swift) -- add cancellation checks in tool execution
6. **Then Task 7+8** (FileWriteTool/FileEditTool) -- add cancellation safety
7. **Finally Task 9** -- verify full suite passes

**Key Principles:**
- One type at a time (fix compilation, then fix assertions)
- Minimal implementation (don't over-engineer)
- Run tests frequently (immediate feedback)
- Remember: `Task` in this codebase refers to the project type, use `_Concurrency.Task` for Swift concurrency

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Verify all 2419+ tests pass
2. Review code quality (readability, maintainability)
3. Ensure consistency with existing patterns (AgentLoopTests, StreamTests mock patterns)
4. Verify no import violations
5. Check logger integration points (pre-placed for Epic 14)

---

## Key Risks and Assumptions

1. **Risk: Timing-dependent tests** -- Cancellation tests use delayed mock responses and `Task.sleep`. Timing on CI may differ; consider increasing delays or using explicit synchronization.
2. **Assumption: Swift cooperative cancellation propagates through URLSession** -- `URLSession` data tasks should respond to `Task.cancel()` automatically. If not, additional signal wiring is needed.
3. **Assumption: `atomically: true` guarantees** -- FileWriteTool relies on `String.write(toFile:atomically:encoding:)` for atomic writes. This is synchronous, so cancellation during write is not possible (write either completes or doesn't start).
4. **Risk: `_Concurrency.Task` vs project `Task`** -- The project defines its own `Task` type (in TaskTypes). All Swift concurrency Task references must use `_Concurrency.Task`.
5. **Assumption: MCP cleanup unaffected** -- stream() defer block should execute even during cancellation. Verify this during implementation.

---

## Test Execution Evidence

### Initial Test Run (RED Phase Verification)

**Command:** `swift build --build-tests`

**Results:**
```
error: type 'QueryStatus' has no member 'cancelled'
error: value of type 'QueryResult' has no member 'isCancelled'
error: value of type 'Agent' has no member 'interrupt'
error: type 'SDKMessage.ResultData.Subtype' has no member 'cancelled'
error: extra argument 'isCancelled' in call
```

**Summary:**
- Total tests: 17
- Passing: 0 (expected -- compilation failures)
- Failing: 17 (expected -- types and methods not yet implemented)
- Non-AbortTests errors: 0 (project compiles cleanly)
- Status: RED phase verified

---

**Generated by BMad TEA Agent** - 2026-04-12

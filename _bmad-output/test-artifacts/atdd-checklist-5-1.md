---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-07'
inputDocuments:
  - _bmad-output/implementation-artifacts/5-1-worktree-store-tools.md
  - Tests/OpenAgentSDKTests/Stores/WorktreeStoreTests.swift
  - Tests/OpenAgentSDKTests/Tools/Specialist/WorktreeToolsTests.swift
---

# ATDD Checklist: Story 5.1 -- WorktreeStore & Worktree Tools

## TDD Red Phase (Current)

**Status:** RED -- All tests fail to compile because feature types/functions do not exist yet.

- **Unit Tests (Store):** 17 tests in `WorktreeStoreTests.swift`
- **Unit Tests (Tools):** 20 tests in `WorktreeToolsTests.swift`
- **Total:** 37 tests

## Acceptance Criteria Coverage

| AC # | Criterion | Test File(s) | Tests | Priority |
|------|-----------|-------------|-------|----------|
| AC1 | WorktreeStore Actor -- thread-safe CRUD | WorktreeStoreTests | testCreate_returnsEntryWithCorrectFields, testCreate_autoGeneratesSequentialIds, testCreate_defaultStatusIsActive, testGet_existingId_returnsEntry, testGet_nonexistentId_returnsNil, testList_returnsAllEntries, testList_emptyStore_returnsEmpty, testRemove_existingId_succeeds, testKeep_existingId_succeeds, testClear_resetsStore, testWorktreeStore_concurrentAccess, testWorktreeStatus_rawValues, testWorktreeEntry_equality, testWorktreeEntry_codable, testWorktreeStoreError_worktreeNotFound_description, testWorktreeStoreError_gitCommandFailed_description, testWorktreeStoreError_equality | P0-P1 |
| AC2 | EnterWorktree tool -- creates worktree | WorktreeToolsTests | testCreateEnterWorktreeTool_returnsToolProtocol, testCreateEnterWorktreeTool_hasValidInputSchema, testCreateEnterWorktreeTool_isNotReadOnly, testEnterWorktree_withName_returnsSuccess, testEnterWorktree_trackedInStore, testEnterWorktree_inputDecodable | P0 |
| AC3 | ExitWorktree tool -- remove/keep | WorktreeToolsTests | testCreateExitWorktreeTool_returnsToolProtocol, testCreateExitWorktreeTool_hasValidInputSchema, testCreateExitWorktreeTool_isNotReadOnly, testExitWorktree_actionRemove_returnsSuccess, testExitWorktree_defaultActionIsRemove, testExitWorktree_actionKeep_returnsSuccess | P0 |
| AC4 | Worktree not found error | WorktreeStoreTests, WorktreeToolsTests | testRemove_nonexistentId_throwsError, testKeep_nonexistentId_throwsError, testExitWorktree_nonexistentWorktree_returnsError | P0 |
| AC5 | Non-git repo error | WorktreeStoreTests, WorktreeToolsTests | testCreate_nonGitDirectory_throwsGitCommandFailed, testEnterWorktree_nonGitDirectory_returnsError | P0 |
| AC6 | inputSchema matches TS SDK | WorktreeToolsTests | testCreateEnterWorktreeTool_hasValidInputSchema, testCreateExitWorktreeTool_hasValidInputSchema | P0 |
| AC7 | isReadOnly = false for both | WorktreeToolsTests | testCreateEnterWorktreeTool_isNotReadOnly, testCreateExitWorktreeTool_isNotReadOnly | P0 |
| AC8 | Module boundary compliance | WorktreeToolsTests | testWorktreeTools_moduleBoundary_noDirectStoreImports | P0 |
| AC9 | Error handling never interrupts loop | WorktreeToolsTests | testEnterWorktree_nilWorktreeStore_returnsError, testExitWorktree_nilWorktreeStore_returnsError, testEnterWorktree_neverThrows_malformedInput, testExitWorktree_neverThrows_malformedInput | P0 |
| AC10 | ToolContext dependency injection | WorktreeToolsTests | testToolContext_hasWorktreeStoreField, testToolContext_worktreeStoreDefaultsToNil, testToolContext_withAllFieldsIncludingWorktree | P0 |
| AC11 | POSIX cross-platform Process | WorktreeStoreTests | (implicit in createTempGitRepo helper, verified by all store tests) | P1 |

## Test Distribution by Priority

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 30 | Critical paths -- must pass for feature acceptance |
| P1 | 7 | Important but secondary scenarios |
| **Total** | **37** | |

## Test Levels

| Level | Tests | File |
|-------|-------|------|
| Unit (Store) | 17 | Tests/OpenAgentSDKTests/Stores/WorktreeStoreTests.swift |
| Unit (Tools) | 20 | Tests/OpenAgentSDKTests/Tools/Specialist/WorktreeToolsTests.swift |

Note: This is a backend Swift project. No E2E/browser tests apply. Tests use real `git` commands via Foundation `Process` for integration-level validation of git worktree operations.

## Generated Files

| File | Purpose |
|------|---------|
| `Tests/OpenAgentSDKTests/Stores/WorktreeStoreTests.swift` | WorktreeStore Actor unit tests |
| `Tests/OpenAgentSDKTests/Tools/Specialist/WorktreeToolsTests.swift` | EnterWorktree + ExitWorktree tool tests |

## Prerequisites Verified

- [x] Story approved with clear acceptance criteria (11 ACs)
- [x] Test framework configured (XCTest / Swift Package Manager)
- [x] Stack detected: backend (Swift)
- [x] Existing patterns inspected (TeamStoreTests, TeamToolsTests as reference)
- [x] No worktree-related code exists yet (pure RED phase)

## TDD Red Phase Validation

- [x] All tests reference types/methods that do not exist yet
- [x] All tests assert EXPECTED behavior (not placeholder assertions)
- [x] Build fails with compilation errors (confirmed)
- [x] Error types reference non-existent symbols: WorktreeStore, WorktreeEntry, WorktreeStatus, WorktreeStoreError, createEnterWorktreeTool, createExitWorktreeTool, ToolContext.worktreeStore

## Risks and Assumptions

1. **Git dependency**: Store tests require `git` to be available on the system. Tests create temporary git repos and clean up after themselves.
2. **Filesystem side effects**: EnterWorktree and ExitWorktree create/remove directories. Tests use temp directories with cleanup.
3. **Concurrent test safety**: Actor isolation test creates 10 concurrent worktrees -- this is safe due to actor semantics but depends on filesystem speed.
4. **ToolContext backward compatibility**: Tests verify that ToolContext can be created without worktreeStore (defaults to nil).

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Define types in `Sources/OpenAgentSDK/Types/TaskTypes.swift`: WorktreeEntry, WorktreeStatus, WorktreeStoreError
2. Add `worktreeStore` field to `ToolContext` in `Types/ToolTypes.swift`
3. Add `worktreeStore` field to `AgentOptions` in `Types/AgentTypes.swift`
4. Implement `WorktreeStore` actor in `Sources/OpenAgentSDK/Stores/WorktreeStore.swift`
5. Implement `createEnterWorktreeTool()` and `createExitWorktreeTool()` in `Sources/OpenAgentSDK/Tools/Specialist/WorktreeTools.swift`
6. Update `Core/Agent.swift` to inject worktreeStore into ToolContext
7. Update `OpenAgentSDK.swift` to re-export new types
8. Run `swift build --build-tests` to verify compilation
9. Run `swift test` to verify all 37 tests pass (GREEN phase)
10. Commit passing tests

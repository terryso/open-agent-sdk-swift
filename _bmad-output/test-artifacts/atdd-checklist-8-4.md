---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-09'
inputDocuments:
  - _bmad-output/implementation-artifacts/8-4-permission-modes.md
  - Sources/OpenAgentSDK/Types/PermissionTypes.swift
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Core/ToolExecutor.swift
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Tests/OpenAgentSDKTests/Core/ToolExecutorTests.swift
  - Sources/E2ETest/HookRegistryE2ETests.swift
  - Sources/E2ETest/HookIntegrationE2ETests.swift
---

# ATDD Checklist: Story 8-4 -- Permission Modes

## TDD Red Phase (Current)

**All tests will FAIL until the implementation is complete.** Tests reference `ToolExecutor.shouldBlockTool()` and `ToolContext(permissionMode:canUseTool:)` which do not yet exist. The ToolExecutor.executeSingleTool() method also needs to be updated to add permission checks. This is intentional -- TDD red phase.

### Compilation Errors (Expected)

All errors stem from:
1. `ToolExecutor.shouldBlockTool(permissionMode:tool:)` does not exist yet -- needs to be added to ToolExecutor
2. `ToolExecutor.PermissionDecision` enum does not exist yet
3. `ToolContext` does not accept `permissionMode` and `canUseTool` parameters yet
4. `executeSingleTool()` does not perform permission checks yet

These will resolve once Tasks 1-2 are implemented (ToolContext extension + ToolExecutor permission logic).

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest (unit), custom harness (E2E)
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | PermissionMode enum to behavior mapping | P0 | Unit | `testShouldBlockTool_default_blocksMutationTools`, `testShouldBlockTool_default_allowsReadOnlyTools` |
| AC2 | bypassPermissions mode | P0 | Unit, E2E | `testShouldBlockTool_bypassPermissions_allowsAll`, `testBypassPermissionsMode_toolExecutesWithoutBlock` (E2E) |
| AC3 | default mode | P0 | Unit, E2E | `testShouldBlockTool_default_blocksMutationTools`, `testShouldBlockTool_default_allowsReadOnlyTools`, `testDefaultMode_mutationToolBlocked` (E2E) |
| AC4 | acceptEdits mode | P0 | Unit | `testShouldBlockTool_acceptEdits_allowsWriteEdit`, `testShouldBlockTool_acceptEdits_blocksBash` |
| AC5 | plan mode | P0 | Unit | `testShouldBlockTool_plan_blocksAllMutations` |
| AC6 | dontAsk mode | P0 | Unit | `testShouldBlockTool_dontAsk_deniesAllMutations` |
| AC7 | auto mode | P0 | Unit | `testShouldBlockTool_auto_allowsAll` |
| AC8 | canUseTool callback priority | P0 | Unit, E2E | `testExecuteSingleTool_canUseToolReturnsNil_fallsBackToPermissionMode`, `testCanUseToolCallback_denyPath` (E2E), `testCanUseToolCallback_allowPath` (E2E) |
| AC9 | canUseTool deny behavior | P0 | Unit | `testExecuteSingleTool_canUseToolDeny_returnsError` |
| AC10 | canUseTool allow + updatedInput | P0 | Unit | `testExecuteSingleTool_canUseToolAllowWithUpdatedInput_usesModifiedInput` |
| AC11 | ToolContext carries permission info | P0 | Unit | `testToolContext_permissionModeAndCanUseTool_injectedCorrectly` |
| AC12 | Unit test coverage | -- | Unit | 15 unit tests in `PermissionModeTests.swift` |
| AC13 | E2E test coverage | -- | E2E | 4 E2E tests in `PermissionModeE2ETests.swift` |

## Test Summary

- **Total Tests:** 19 (15 unit + 4 E2E)
- **Unit Tests:** 15 (all in `Tests/OpenAgentSDKTests/Core/PermissionModeTests.swift`)
- **E2E Tests:** 4 (all in `Sources/E2ETest/PermissionModeE2ETests.swift`)
- **All tests will FAIL until feature is implemented** (compilation failure -- methods/types don't exist)

## Unit Test Plan (Tests/OpenAgentSDKTests/Core/PermissionModeTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testShouldBlockTool_bypassPermissions_allowsAll` | AC2 | P0 | Mutation tool passes under bypassPermissions |
| 2 | `testShouldBlockTool_auto_allowsAll` | AC7 | P0 | Mutation tool passes under auto |
| 3 | `testShouldBlockTool_default_blocksMutationTools` | AC3 | P0 | Mutation tool blocked under default |
| 4 | `testShouldBlockTool_default_allowsReadOnlyTools` | AC3 | P0 | Read-only tool passes under default |
| 5 | `testShouldBlockTool_acceptEdits_allowsWriteEdit` | AC4 | P0 | Write/Edit pass under acceptEdits |
| 6 | `testShouldBlockTool_acceptEdits_blocksBash` | AC4 | P0 | Bash blocked under acceptEdits |
| 7 | `testShouldBlockTool_plan_blocksAllMutations` | AC5 | P0 | All mutation tools blocked under plan |
| 8 | `testShouldBlockTool_dontAsk_deniesAllMutations` | AC6 | P0 | All mutation tools denied under dontAsk |
| 9 | `testExecuteSingleTool_canUseToolDeny_returnsError` | AC9 | P0 | canUseTool returning deny produces error ToolResult |
| 10 | `testExecuteSingleTool_canUseToolAllow_executesTool` | AC8 | P0 | canUseTool returning allow executes the tool |
| 11 | `testExecuteSingleTool_canUseToolAllowWithUpdatedInput_usesModifiedInput` | AC10 | P0 | canUseTool with updatedInput modifies tool input |
| 12 | `testExecuteSingleTool_canUseToolReturnsNil_fallsBackToPermissionMode` | AC8 | P0 | canUseTool returning nil falls back to permissionMode |
| 13 | `testExecuteSingleTool_canUseToolThrows_returnsError` | AC8 | P0 | canUseTool throwing returns error ToolResult |
| 14 | `testExecuteSingleTool_noCanUseToolNoPermissionMode_executesTool` | AC1 | P1 | No permission config means tool executes normally |
| 15 | `testToolContext_permissionModeAndCanUseTool_injectedCorrectly` | AC11 | P0 | ToolContext preserves permissionMode and canUseTool fields |

## E2E Test Plan (Sources/E2ETest/PermissionModeE2ETests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testBypassPermissionsMode_toolExecutesWithoutBlock` | AC2 | P0 | Agent with bypassPermissions executes tools without interception |
| 2 | `testDefaultMode_mutationToolBlocked` | AC3 | P0 | Agent with default mode blocks mutation tools |
| 3 | `testCanUseToolCallback_denyPath` | AC9 | P0 | canUseTool callback returning deny blocks tool |
| 4 | `testCanUseToolCallback_allowPath` | AC8 | P0 | canUseTool callback returning allow permits tool |

## Next Steps (TDD Green Phase)

After implementing the feature (Tasks 1-3):

1. **Task 1:** Modify `Sources/OpenAgentSDK/Types/ToolTypes.swift` -- Add permissionMode, canUseTool to ToolContext
2. **Task 2:** Modify `Sources/OpenAgentSDK/Core/ToolExecutor.swift` -- Add shouldBlockTool(), PermissionDecision, permission checks in executeSingleTool()
3. **Task 3:** Modify `Sources/OpenAgentSDK/Core/Agent.swift` -- Inject permission fields into ToolContext construction
4. Run `swift build` -- verify compilation
5. Run `swift test` -- verify unit tests pass
6. Run `swift run E2ETest` -- verify E2E tests pass
7. Run full test suite and report total count

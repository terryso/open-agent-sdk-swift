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
  - _bmad-output/implementation-artifacts/8-3-shell-hook-execution.md
  - Sources/OpenAgentSDK/Types/HookTypes.swift
  - Sources/OpenAgentSDK/Hooks/HookRegistry.swift
  - Sources/OpenAgentSDK/Tools/Core/BashTool.swift
  - Tests/OpenAgentSDKTests/Hooks/HookRegistryTests.swift
  - Tests/OpenAgentSDKTests/Hooks/HookIntegrationTests.swift
  - Sources/E2ETest/HookRegistryE2ETests.swift
  - Sources/E2ETest/HookIntegrationE2ETests.swift
---

# ATDD Checklist: Story 8-3 -- Shell Hook Execution

## TDD Red Phase (Current)

**All tests will FAIL until the implementation is complete.** Tests reference `ShellHookExecutor` which does not yet exist, so they will not compile. The HookRegistry.execute() method also needs to be updated to handle the `command` field. This is intentional -- TDD red phase.

### Compilation Errors (Expected)

All errors are `cannot find 'ShellHookExecutor' in scope` because `ShellHookExecutor.swift` has not been created yet. Additionally, tests that register `HookDefinition(command:)` without a handler will be skipped by the current HookRegistry.execute() which only processes definitions with handlers. These will resolve once Tasks 1-2 are implemented.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | ShellHookExecutor execution engine | P0 | Unit | `testExecute_validCommand_returnsOutput`, `testExecute_usesFoundationProcess` |
| AC2 | JSON stdin/stdout protocol | P0 | Unit | `testExecute_jsonStdout_parsesAsHookOutput`, `testExecute_nonJsonOutput_treatedAsMessage` |
| AC3 | Environment variable passing | P0 | Unit | `testExecute_environmentVariables_setCorrectly`, `testExecute_environmentVariables_emptyWhenNil` |
| AC4 | Shell hook timeout | P0 | Unit | `testExecute_timeout_terminatesProcess`, `testRegistryExecute_commandTimeout_returnsNoResult` |
| AC5 | Non-zero exit code handling | P0 | Unit | `testExecute_nonZeroExitCode_returnsNil`, `testExecute_exitCode2_returnsNil`, `testExecute_emptyOutput_returnsNil` |
| AC6 | Input sanitization (stdin pipe) | P0 | Unit | `testExecute_specialCharactersInInput_passedViaStdin`, `testExecute_commandFailure_returnsNil` |
| AC7 | HookRegistry.execute() integration | P0 | Unit, E2E | `testRegistryExecute_commandHook_returnsOutput`, `testRegistryExecute_noHandlerNoCommand_skipsDefinition`, `testRegistryExecute_handlerAndCommand_handlerTakesPriority` (unit), `testRegisterShellHook_triggerEvent_verifyOutput` (E2E) |
| AC8 | Shell + function hook coexistence | P0 | Unit, E2E | `testRegistryExecute_mixedHandlerAndCommand_executesInOrder` (unit), `testShellHookAndFunctionHook_executeInOrder` (E2E) |
| AC9 | Cross-platform support | P1 | Unit | `testExecute_usesFoundationProcess` |
| AC10 | Unit test coverage | -- | Unit | 20 unit tests in `ShellHookExecutorTests.swift` |
| AC11 | E2E test coverage | -- | E2E | 3 E2E tests in `ShellHookExecutionE2ETests.swift` |
| AC12 | Matcher filtering for shell hooks | P0 | Unit, E2E | `testRegistryExecute_commandHookWithMatcher_filtersCorrectly`, `testRegistryExecute_commandHookNoMatcher_matchesAll`, `testRegistryExecute_commandHookRegexMatcher_matchesPattern` (unit), `testShellHookWithMatcher_filtersByToolName` (E2E) |

## Test Summary

- **Total Tests:** 23 (20 unit + 3 E2E)
- **Unit Tests:** 20 (all in `Tests/OpenAgentSDKTests/Hooks/ShellHookExecutorTests.swift`)
- **E2E Tests:** 3 (all in `Sources/E2ETest/ShellHookExecutionE2ETests.swift`)
- **All tests will FAIL until feature is implemented** (compilation failure -- ShellHookExecutor doesn't exist)

## Unit Test Plan (Tests/OpenAgentSDKTests/Hooks/ShellHookExecutorTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testExecute_validCommand_returnsOutput` | AC1 | P0 | Executes a shell command and returns JSON output |
| 2 | `testExecute_jsonStdout_parsesAsHookOutput` | AC2 | P0 | Stdin JSON is passed, stdout JSON is parsed as HookOutput |
| 3 | `testExecute_nonJsonOutput_treatedAsMessage` | AC2 | P0 | Non-JSON stdout is wrapped as HookOutput(message:) |
| 4 | `testExecute_environmentVariables_setCorrectly` | AC3 | P0 | HOOK_EVENT, HOOK_TOOL_NAME, HOOK_SESSION_ID, HOOK_CWD are set |
| 5 | `testExecute_environmentVariables_emptyWhenNil` | AC3 | P1 | Optional env vars are empty strings when input fields are nil |
| 6 | `testExecute_timeout_terminatesProcess` | AC4 | P0 | Command exceeding timeout returns nil |
| 7 | `testExecute_nonZeroExitCode_returnsNil` | AC5 | P0 | Exit code 1 returns nil |
| 8 | `testExecute_exitCode2_returnsNil` | AC5 | P1 | Exit code 2 returns nil |
| 9 | `testExecute_emptyOutput_returnsNil` | AC5 | P0 | Empty stdout returns nil |
| 10 | `testExecute_commandFailure_returnsNil` | AC6 | P0 | Non-existent command returns nil (no crash) |
| 11 | `testExecute_specialCharactersInInput_passedViaStdin` | AC6 | P0 | Special characters in input are safely piped via stdin |
| 12 | `testRegistryExecute_commandHook_returnsOutput` | AC7 | P0 | HookRegistry executes shell command when handler is nil |
| 13 | `testRegistryExecute_noHandlerNoCommand_skipsDefinition` | AC7 | P0 | Definition with no handler and no command is skipped |
| 14 | `testRegistryExecute_handlerAndCommand_handlerTakesPriority` | AC7 | P0 | Handler takes priority over command when both are set |
| 15 | `testRegistryExecute_mixedHandlerAndCommand_executesInOrder` | AC8 | P0 | Shell and function hooks execute in registration order |
| 16 | `testRegistryExecute_commandHookWithMatcher_filtersCorrectly` | AC12 | P0 | Shell hook with matcher filters by toolName |
| 17 | `testRegistryExecute_commandHookNoMatcher_matchesAll` | AC12 | P0 | Shell hook with nil matcher matches all toolNames |
| 18 | `testRegistryExecute_commandHookRegexMatcher_matchesPattern` | AC12 | P1 | Shell hook with regex matcher matches pattern |
| 19 | `testRegistryExecute_commandTimeout_returnsNoResult` | AC4 | P0 | Shell hook timeout in HookRegistry terminates and doesn't block others |
| 20 | `testExecute_usesFoundationProcess` | AC9 | P1 | Verifies Foundation Process API is used (cross-platform) |

## E2E Test Plan (Sources/E2ETest/ShellHookExecutionE2ETests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testRegisterShellHook_triggerEvent_verifyOutput` | AC7, AC1 | P0 | Register shell hook, trigger event, verify JSON output |
| 2 | `testShellHookAndFunctionHook_executeInOrder` | AC8 | P0 | Shell and function hooks execute in registration order |
| 3 | `testShellHookWithMatcher_filtersByToolName` | AC12 | P0 | Shell hook with matcher only fires for matching toolName |

## Next Steps (TDD Green Phase)

After implementing the feature (Tasks 1-2):

1. **Task 1:** Create `Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift` -- Shell command hook executor
2. **Task 2:** Modify `Sources/OpenAgentSDK/Hooks/HookRegistry.swift` -- execute() to add command branch
3. Run `swift build` -- verify compilation
4. Run `swift test` -- verify unit tests pass
5. Run `swift run E2ETest` -- verify E2E tests pass
6. Run full test suite and report total count

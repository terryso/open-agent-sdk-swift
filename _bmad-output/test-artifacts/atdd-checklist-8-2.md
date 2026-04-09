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
  - _bmad-output/implementation-artifacts/8-2-function-hook-registration-execution.md
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Types/HookTypes.swift
  - Sources/OpenAgentSDK/Hooks/HookRegistry.swift
  - Sources/OpenAgentSDK/Core/ToolExecutor.swift
  - Sources/OpenAgentSDK/Core/Agent.swift
  - Tests/OpenAgentSDKTests/Hooks/HookRegistryTests.swift
  - Sources/E2ETest/HookRegistryE2ETests.swift
---

# ATDD Checklist: Story 8-2 -- Function Hook Registration & Execution

## TDD Red Phase (Current)

**All tests will FAIL until the implementation is complete.** Tests reference types, properties, and functions that do not yet exist (`AgentOptions.hookRegistry`, `ToolContext.hookRegistry`, `createHookRegistry()`, ToolExecutor hook integration), so they will not compile. This is intentional -- TDD red phase.

### Compilation Errors (Expected)

All errors are `extra argument 'hookRegistry' in call` because `AgentOptions.init()` does not yet have the `hookRegistry` parameter. The unit tests also reference `createHookRegistry()` which does not exist yet. These will resolve once Tasks 1-6 are implemented.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | AgentOptions.hookRegistry injection | P0 | Unit | `testAgentOptions_hookRegistry_defaultNil`, `testAgentOptions_hookRegistry_injectable`, `testAgentOptions_fromConfig_hookRegistryNil`, `testToolContext_hookRegistry_defaultNil`, `testToolContext_hookRegistry_preservedInWithToolUseId` |
| AC2 | SessionStart hook execution | P0 | Unit, E2E | `testAgentPrompt_sessionStartHookTriggered` (unit), `testSessionStartEnd_hooksTriggeredViaPrompt` (E2E) |
| AC3 | Multiple hooks in order | P0 | E2E | `testMultipleHooks_executeInOrderDuringAgentRun` |
| AC4 | PreToolUse hook blocks tool | P0 | Unit, E2E | `testPreToolUse_hookBlocksExecution`, `testPreToolUse_hookAllowsExecution` (unit), `testPreToolUse_blockPreventsToolExecution` (E2E) |
| AC5 | PostToolUse hook receives output | P0 | Unit | `testPostToolUse_hookReceivesToolOutput` |
| AC6 | PostToolUseFailure hook receives error | P0 | Unit | `testPostToolUseFailure_hookReceivesError` |
| AC7 | SessionEnd hook execution | P0 | Unit, E2E | `testAgentPrompt_sessionEndHookTriggered` (unit), `testSessionStartEnd_hooksTriggeredViaPrompt` (E2E) |
| AC8 | Stop hook execution | P0 | Unit | `testAgentPrompt_stopHookTriggered` |
| AC9 | hookRegistry nil no side effects | P0 | Unit | `testHookRegistryNil_noSideEffects`, `testHookRegistryNil_unknownTool_stillReturnsError` |
| AC10 | createHookRegistry factory | P0 | Unit | `testCreateHookRegistry_withoutConfig_returnsEmptyRegistry`, `testCreateHookRegistry_withConfig_registersHooks` |
| AC11 | Unit test coverage | -- | Unit | All 15 unit tests in `HookIntegrationTests.swift` |
| AC12 | E2E test coverage | -- | E2E | 3 E2E tests in `HookIntegrationE2ETests.swift` |

## Test Summary

- **Total Tests:** 18 (15 unit + 3 E2E)
- **Unit Tests:** 15 (all in `Tests/OpenAgentSDKTests/Hooks/HookIntegrationTests.swift`)
- **E2E Tests:** 3 (all in `Sources/E2ETest/HookIntegrationE2ETests.swift`)
- **All tests will FAIL until feature is implemented** (compilation failure -- properties/functions don't exist)

## Unit Test Plan (Tests/OpenAgentSDKTests/Hooks/HookIntegrationTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testCreateHookRegistry_withoutConfig_returnsEmptyRegistry` | AC10 | P0 | Factory returns empty registry |
| 2 | `testCreateHookRegistry_withConfig_registersHooks` | AC10 | P0 | Factory with config registers hooks |
| 3 | `testAgentOptions_hookRegistry_defaultNil` | AC1 | P0 | AgentOptions.hookRegistry defaults to nil |
| 4 | `testAgentOptions_hookRegistry_injectable` | AC1 | P0 | AgentOptions.hookRegistry can be injected |
| 5 | `testAgentOptions_fromConfig_hookRegistryNil` | AC1 | P1 | AgentOptions(from:) initializes hookRegistry to nil |
| 6 | `testToolContext_hookRegistry_defaultNil` | AC1 | P0 | ToolContext.hookRegistry defaults to nil |
| 7 | `testToolContext_hookRegistry_preservedInWithToolUseId` | AC1 | P0 | hookRegistry preserved when copying ToolContext |
| 8 | `testPreToolUse_hookBlocksExecution` | AC4 | P0 | PreToolUse hook blocks tool execution |
| 9 | `testPreToolUse_hookAllowsExecution` | AC4 | P0 | PreToolUse hook allows tool execution |
| 10 | `testPostToolUse_hookReceivesToolOutput` | AC5 | P0 | PostToolUse hook receives tool output |
| 11 | `testPostToolUseFailure_hookReceivesError` | AC6 | P0 | PostToolUseFailure hook receives error info |
| 12 | `testHookRegistryNil_noSideEffects` | AC9 | P0 | Nil hookRegistry has no side effects |
| 13 | `testHookRegistryNil_unknownTool_stillReturnsError` | AC9 | P0 | Unknown tool still errors with nil hookRegistry |
| 14 | `testAgentPrompt_sessionStartHookTriggered` | AC2 | P0 | sessionStart hook structure test |
| 15 | `testAgentPrompt_sessionEndHookTriggered` | AC7 | P0 | sessionEnd hook structure test |
| 16 | `testAgentPrompt_stopHookTriggered` | AC8 | P0 | stop hook structure test |

## E2E Test Plan (Sources/E2ETest/HookIntegrationE2ETests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testSessionStartEnd_hooksTriggeredViaPrompt` | AC2, AC7 | P0 | sessionStart/End hooks fire during prompt() |
| 2 | `testPreToolUse_blockPreventsToolExecution` | AC4 | P0 | PreToolUse block prevents bash tool execution |
| 3 | `testMultipleHooks_executeInOrderDuringAgentRun` | AC3 | P0 | Multiple hooks execute in order during agent run |

## Next Steps (TDD Green Phase)

After implementing the feature (Tasks 1-6):

1. **Task 1:** Add `hookRegistry: HookRegistry?` to `AgentOptions` (in `Types/AgentTypes.swift`)
2. **Task 2:** Add `hookRegistry: HookRegistry?` to `ToolContext` (in `Types/ToolTypes.swift`)
3. **Task 3:** Add `createHookRegistry()` factory function (in `Hooks/HookRegistry.swift`)
4. **Task 4:** Integrate hooks into `Agent.prompt()` (in `Core/Agent.swift`)
5. **Task 5:** Integrate hooks into `Agent.stream()` (in `Core/Agent.swift`)
6. **Task 6:** Integrate PreToolUse/PostToolUse into `ToolExecutor.executeSingleTool()` (in `Core/ToolExecutor.swift`)
7. Run `swift build` -- verify compilation
8. Run `swift test` -- verify unit tests pass
9. Run `swift run E2ETest` -- verify E2E tests pass
10. Run full test suite and report total count

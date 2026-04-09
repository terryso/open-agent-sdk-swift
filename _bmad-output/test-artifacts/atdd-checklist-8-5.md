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
  - _bmad-output/implementation-artifacts/8-5-custom-authorization-callback.md
  - Sources/OpenAgentSDK/Types/PermissionTypes.swift
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Sources/OpenAgentSDK/Core/Agent.swift
  - Tests/OpenAgentSDKTests/Core/PermissionModeTests.swift
  - Sources/E2ETest/PermissionModeE2ETests.swift
---

# ATDD Checklist: Story 8-5 -- Custom Authorization Callback

## TDD Red Phase (Current)

**All tests will FAIL until the implementation is complete.** Tests reference types and methods that do not yet exist:

1. `PermissionPolicy` protocol does not exist yet
2. `ToolNameAllowlistPolicy` struct does not exist yet
3. `ToolNameDenylistPolicy` struct does not exist yet
4. `ReadOnlyPolicy` struct does not exist yet
5. `CompositePolicy` struct does not exist yet
6. `canUseTool(policy:)` global function does not exist yet
7. `CanUseToolResult.allow()`, `.deny()`, `.allowWithInput()` static factory methods do not exist yet
8. `Agent.setPermissionMode(_:)` method does not exist yet
9. `Agent.setCanUseTool(_:)` method does not exist yet
10. `Agent.options` is `let` (immutable) -- needs to be changed to `var`

These will resolve once Tasks 1-3 are implemented.

### Compilation Errors (Expected)

All errors stem from:
1. `PermissionPolicy` protocol not defined in `PermissionTypes.swift`
2. `ToolNameAllowlistPolicy`, `ToolNameDenylistPolicy`, `ReadOnlyPolicy`, `CompositePolicy` not defined
3. `canUseTool(policy:)` global function not defined
4. `CanUseToolResult` static factory methods not defined
5. `Agent` does not have `setPermissionMode()` or `setCanUseTool()` methods
6. `Agent.options` is `let` -- tests that call `agent.options.permissionMode` after mutation will fail

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest (unit), custom harness (E2E)
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | PermissionPolicy protocol | P0 | Unit | `testCanUseToolPolicy_bridge_returnsExpectedResults` (uses protocol) |
| AC2 | ToolNameAllowlistPolicy | P0 | Unit, E2E | `testToolNameAllowlistPolicy_allowedTool_returnsAllow`, `testToolNameAllowlistPolicy_deniedTool_returnsDeny`, `testToolNameAllowlistPolicy_emptySet_deniesAll`, `testAllowlistPolicy_llmDrivenToolCall` (E2E) |
| AC3 | ToolNameDenylistPolicy | P0 | Unit, E2E | `testToolNameDenylistPolicy_deniedTool_returnsDeny`, `testToolNameDenylistPolicy_allowedTool_returnsAllow`, `testToolNameDenylistPolicy_emptySet_allowsAll`, `testDenylistPolicy_llmDrivenToolDenial` (E2E) |
| AC4 | ReadOnlyPolicy | P0 | Unit | `testReadOnlyPolicy_readOnlyTool_returnsAllow`, `testReadOnlyPolicy_mutationTool_returnsDeny` |
| AC5 | CompositePolicy | P0 | Unit | `testCompositePolicy_allAllow_returnsAllow`, `testCompositePolicy_oneDeny_returnsDeny`, `testCompositePolicy_denyShortCircuits`, `testCompositePolicy_nilSkips`, `testCompositePolicy_emptyPolicies_returnsAllow` |
| AC6 | Agent.setPermissionMode() | P0 | Unit, E2E | `testAgent_setPermissionMode_updatesMode`, `testAgent_setPermissionMode_clearsCanUseTool`, `testDynamicPermissionModeSwitch` (E2E) |
| AC7 | Agent.setCanUseTool() | P0 | Unit | `testAgent_setCanUseTool_updatesCallback`, `testAgent_setCanUseTool_nil_clearsCallback` |
| AC8 | PermissionPolicyToFn bridge | P0 | Unit, E2E | `testCanUseToolPolicy_bridge_returnsExpectedResults`, `testAllowlistPolicy_llmDrivenToolCall` (E2E) |
| AC9 | CanUseToolResult factory methods | P0 | Unit | `testCanUseToolResult_allow_createsAllowResult`, `testCanUseToolResult_deny_createsDenyResult`, `testCanUseToolResult_allowWithInput_createsResultWithInput` |
| AC10 | ToolContext permission info | P1 | Unit | `testToolContext_permissionMode_accessibleInPolicy` |
| AC11 | Unit test coverage | -- | Unit | 20 unit tests in `PermissionPolicyTests.swift` |
| AC12 | E2E test coverage | -- | E2E | 3 E2E tests in `AuthorizationCallbackE2ETests.swift` |

## Test Summary

- **Total Tests:** 23 (20 unit + 3 E2E)
- **Unit Tests:** 20 (all in `Tests/OpenAgentSDKTests/Core/PermissionPolicyTests.swift`)
- **E2E Tests:** 3 (all in `Sources/E2ETest/AuthorizationCallbackE2ETests.swift`)
- **All tests will FAIL until feature is implemented** (compilation failure -- types/methods don't exist)

## Unit Test Plan (Tests/OpenAgentSDKTests/Core/PermissionPolicyTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testToolNameAllowlistPolicy_allowedTool_returnsAllow` | AC2 | P0 | Tool in allowlist gets allow |
| 2 | `testToolNameAllowlistPolicy_deniedTool_returnsDeny` | AC2 | P0 | Tool not in allowlist gets deny |
| 3 | `testToolNameAllowlistPolicy_emptySet_deniesAll` | AC2 | P0 | Empty allowlist denies all |
| 4 | `testToolNameDenylistPolicy_deniedTool_returnsDeny` | AC3 | P0 | Tool in denylist gets deny |
| 5 | `testToolNameDenylistPolicy_allowedTool_returnsAllow` | AC3 | P0 | Tool not in denylist gets allow |
| 6 | `testToolNameDenylistPolicy_emptySet_allowsAll` | AC3 | P0 | Empty denylist allows all |
| 7 | `testReadOnlyPolicy_readOnlyTool_returnsAllow` | AC4 | P0 | Read-only tool passes |
| 8 | `testReadOnlyPolicy_mutationTool_returnsDeny` | AC4 | P0 | Mutation tool denied |
| 9 | `testCompositePolicy_allAllow_returnsAllow` | AC5 | P0 | All-allowing policies result in allow |
| 10 | `testCompositePolicy_oneDeny_returnsDeny` | AC5 | P0 | Any deny makes composite deny |
| 11 | `testCompositePolicy_denyShortCircuits` | AC5 | P0 | Deny short-circuits evaluation |
| 12 | `testCompositePolicy_nilSkips` | AC5 | P0 | Nil policies are skipped |
| 13 | `testCompositePolicy_emptyPolicies_returnsAllow` | AC5 | P0 | Empty policy list defaults to allow |
| 14 | `testCanUseToolPolicy_bridge_returnsExpectedResults` | AC8 | P0 | Bridge function delegates correctly |
| 15 | `testCanUseToolResult_allow_createsAllowResult` | AC9 | P0 | allow() factory creates allow result |
| 16 | `testCanUseToolResult_deny_createsDenyResult` | AC9 | P0 | deny() factory creates deny result with message |
| 17 | `testCanUseToolResult_allowWithInput_createsResultWithInput` | AC9 | P0 | allowWithInput() creates result with modified input |
| 18 | `testAgent_setPermissionMode_updatesMode` | AC6 | P0 | setPermissionMode updates the mode |
| 19 | `testAgent_setPermissionMode_clearsCanUseTool` | AC6 | P0 | setPermissionMode clears canUseTool |
| 20 | `testAgent_setCanUseTool_updatesCallback` | AC7 | P0 | setCanUseTool sets a new callback |
| 21 | `testAgent_setCanUseTool_nil_clearsCallback` | AC7 | P0 | setCanUseTool(nil) clears the callback |
| 22 | `testToolContext_permissionMode_accessibleInPolicy` | AC10 | P1 | Policy can read permissionMode from ToolContext |

## E2E Test Plan (Sources/E2ETest/AuthorizationCallbackE2ETests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testAllowlistPolicy_llmDrivenToolCall` | AC2, AC8, AC12 | P0 | Allowlist policy with LLM-driven tool execution |
| 2 | `testDenylistPolicy_llmDrivenToolDenial` | AC3, AC8, AC12 | P0 | Denylist policy with LLM-driven tool denial |
| 3 | `testDynamicPermissionModeSwitch` | AC6, AC7, AC12 | P0 | Dynamic setPermissionMode + setCanUseTool switching |

## Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `Tests/OpenAgentSDKTests/Core/PermissionPolicyTests.swift` | Created | 22 unit tests |
| `Sources/E2ETest/AuthorizationCallbackE2ETests.swift` | Created | 3 E2E tests |
| `Sources/E2ETest/main.swift` | Modified | Added Section 42 |

## Next Steps (TDD Green Phase)

After implementing the feature (Tasks 1-3):

1. **Task 1:** Modify `Sources/OpenAgentSDK/Types/PermissionTypes.swift` -- Add PermissionPolicy protocol, 4 policy types, CanUseToolResult extension, canUseTool() bridge function
2. **Task 2:** Modify `Sources/OpenAgentSDK/Core/Agent.swift` -- Add setPermissionMode(), setCanUseTool(), change `options` from `let` to `var`
3. **Task 3:** Modify `Sources/OpenAgentSDK/OpenAgentSDK.swift` -- Ensure new public types are re-exported
4. Run `swift build` -- verify compilation
5. Run `swift test` -- verify unit tests pass
6. Run `swift run E2ETest` -- verify E2E tests pass
7. Run full test suite and report total count

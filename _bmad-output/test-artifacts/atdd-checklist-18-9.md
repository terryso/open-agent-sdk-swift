---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
lastStep: step-04-generate-tests
lastSaved: '2026-04-18'
storyId: '18-9'
storyTitle: 'Update CompatPermissions Example'
inputDocuments:
  - '_bmad-output/implementation-artifacts/18-9-update-compat-permissions.md'
  - 'Examples/CompatPermissions/main.swift'
  - 'Tests/OpenAgentSDKTests/Compat/PermissionSystemCompatTests.swift'
  - 'Tests/OpenAgentSDKTests/Compat/Story18_8_ATDDTests.swift'
  - 'Sources/OpenAgentSDK/Types/PermissionTypes.swift'
  - 'Sources/OpenAgentSDK/Types/HookTypes.swift'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
---

# ATDD Checklist: Story 18-9 -- Update CompatPermissions Example

## Story Summary

Update `Examples/CompatPermissions/main.swift` and verify `PermissionSystemCompatTests.swift` to reflect the features added by Story 17-5 (Permission System Enhancement). This is a pure update story -- no new production code, only updating MISSING/PARTIAL to PASS in the example report.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend framework)
- **Generation Mode:** AI Generation (backend project)
- **Test Framework:** XCTest (Swift native)

## Acceptance Criteria -> Test Mapping

### AC1: PermissionUpdate 6 operations PASS

| # | Test Method | Priority | Level | Status |
|---|-------------|----------|-------|--------|
| 1 | testAC1_addRules_pass | P0 | Unit | PASS |
| 2 | testAC1_replaceRules_pass | P0 | Unit | PASS |
| 3 | testAC1_removeRules_pass | P0 | Unit | PASS |
| 4 | testAC1_setMode_pass | P0 | Unit | PASS |
| 5 | testAC1_addDirectories_pass | P0 | Unit | PASS |
| 6 | testAC1_removeDirectories_pass | P0 | Unit | PASS |
| 7 | testAC1_updateMappings_6PASS | P0 | Unit | PASS |

### AC2: CanUseTool extended params PASS

| # | Test Method | Priority | Level | Status |
|---|-------------|----------|-------|--------|
| 1 | testAC2_signal_pass | P0 | Unit | PASS |
| 2 | testAC2_suggestions_pass | P0 | Unit | PASS |
| 3 | testAC2_blockedPath_pass | P0 | Unit | PASS |
| 4 | testAC2_decisionReason_pass | P0 | Unit | PASS |
| 5 | testAC2_toolUseID_pass | P0 | Unit | PASS |
| 6 | testAC2_agentID_pass | P0 | Unit | PASS |
| 7 | testAC2_canUseMappings_8PASS | P0 | Unit | PASS |

### AC3: CanUseToolResult extended fields PASS

| # | Test Method | Priority | Level | Status |
|---|-------------|----------|-------|--------|
| 1 | testAC3_updatedPermissions_pass | P0 | Unit | PASS |
| 2 | testAC3_interrupt_pass | P0 | Unit | PASS |
| 3 | testAC3_toolUseID_pass | P0 | Unit | PASS |
| 4 | testAC3_resultMappings_8PASS | P0 | Unit | PASS |

### AC4: PermissionBehavior.ask PASS

| # | Test Method | Priority | Level | Status |
|---|-------------|----------|-------|--------|
| 1 | testAC4_askBehavior_pass | P0 | Unit | PASS |
| 2 | testAC4_askBehavior_statusIsPass | P0 | Unit | PASS |

### AC5: PermissionUpdateDestination 5 destinations PASS

| # | Test Method | Priority | Level | Status |
|---|-------------|----------|-------|--------|
| 1 | testAC5_allDestinations_pass | P0 | Unit | PASS |
| 2 | testAC5_destinationMappings_5PASS | P0 | Unit | PASS |

### AC6: SDKPermissionDenial PASS

| # | Test Method | Priority | Level | Status |
|---|-------------|----------|-------|--------|
| 1 | testAC6_sdkPermissionDenialType_pass | P0 | Unit | PASS |
| 2 | testAC6_resultDataPermissionDenials_pass | P0 | Unit | PASS |

### AC7: Summary counts updated

| # | Test Method | Priority | Level | Status |
|---|-------------|----------|-------|--------|
| 1 | testAC7_canUseToolSummary_8PASS | P0 | Unit | PASS |
| 2 | testAC7_canUseToolResultSummary_8PASS | P0 | Unit | PASS |
| 3 | testAC7_updateOperationsSummary_6PASS | P0 | Unit | PASS |
| 4 | testAC7_overallPermissionCompatReport | P0 | Unit | PASS |

### AC8: Build and tests pass

- Verified externally via `swift build` and full test suite run

## Summary Statistics

- **Total tests generated:** 28
- **Test classes:** 7
- **Test file:** `Tests/OpenAgentSDKTests/Compat/Story18_9_ATDDTests.swift`
- **Test level:** Unit (XCTest)
- **Priority:** All P0

## TDD Phase Note

This is a pure update story (compat report alignment). The underlying SDK types were implemented by Story 17-5, so the ATDD tests verify the expected post-implementation state. All tests pass immediately because the types exist. The "red phase" is represented by the fact that `main.swift` still shows MISSING/PARTIAL statuses that need updating.

## Items Unchanged (do NOT update)

| Item | Status | Reason |
|------|--------|--------|
| allowDangerouslySkipPermissions | PARTIAL | Design difference: Swift uses explicit .bypassPermissions mode |

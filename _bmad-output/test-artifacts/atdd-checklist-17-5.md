---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
lastStep: step-04c-aggregate
lastSaved: '2026-04-17'
storyId: '17-5'
storyTitle: 'Permission System Enhancement'
tddPhase: 'RED'
inputDocuments:
  - '_bmad-output/implementation-artifacts/17-5-permission-system-enhancement.md'
  - 'Sources/OpenAgentSDK/Types/PermissionTypes.swift'
  - 'Sources/OpenAgentSDK/Types/HookTypes.swift'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Sources/OpenAgentSDK/Core/ToolExecutor.swift'
  - 'Tests/OpenAgentSDKTests/Types/PermissionTypesTests.swift'
  - 'Tests/OpenAgentSDKTests/Types/ToolContextExtendedTests.swift'
  - 'Tests/OpenAgentSDKTests/Compat/HookSystemCompatTests.swift'
---

# ATDD Checklist: Story 17-5 Permission System Enhancement

## Preflight Summary

- **Story:** 17-5 Permission System Enhancement
- **Stack:** Backend (Swift)
- **Framework:** XCTest
- **Mode:** AI Generation (backend, no browser)
- **TDD Phase:** RED (failing tests before implementation)

## Acceptance Criteria -> Test Mapping

### AC1: PermissionUpdateDestination (5 cases)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 1.1 | PermissionUpdateDestination has 5 cases (CaseIterable) | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 1.2 | userSettings rawValue equals "userSettings" | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 1.3 | projectSettings rawValue equals "projectSettings" | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 1.4 | localSettings rawValue equals "localSettings" | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 1.5 | session rawValue equals "session" | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 1.6 | cliArg rawValue equals "cliArg" | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 1.7 | Conforms to Sendable | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 1.8 | Conforms to Equatable | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 1.9 | init from rawValue works (valid + nil for unknown) | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 1.10 | Compat: all 5 destinations exist per TS SDK | Compat | P0 | PermissionSystemCompatTests.swift | RED |

### AC1: PermissionBehavior.ask

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 2.1 | PermissionBehavior has ask case (rawValue "ask") | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 2.2 | PermissionBehavior.ask rawValue is "ask" | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 2.3 | PermissionBehavior.allCases includes ask (count = 3) | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 2.4 | Compat: PermissionBehavior ask exists per TS SDK | Compat | P0 | PermissionSystemCompatTests.swift | RED |

### AC1: PermissionUpdateOperation (6 cases)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 3.1 | addRules(rules:behavior:) with associated values | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 3.2 | replaceRules(rules:behavior:) with associated values | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 3.3 | removeRules(rules:) with associated values | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 3.4 | setMode(mode:) with PermissionMode | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 3.5 | addDirectories(directories:) with string array | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 3.6 | removeDirectories(directories:) with string array | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 3.7 | Conforms to Sendable | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 3.8 | Conforms to Equatable (same case + values = equal) | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 3.9 | Inequality for different cases | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 3.10 | addRules works with .ask behavior | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 3.11 | Compat: all 6 operations exist per TS SDK | Compat | P0 | PermissionSystemCompatTests.swift | RED |

### AC1: PermissionUpdateAction (operation + destination wrapper)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 4.1 | Wraps operation with non-nil destination | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 4.2 | Destination can be nil | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 4.3 | Conforms to Sendable | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 4.4 | Conforms to Equatable (same op + dest = equal) | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 4.5 | Inequality with different destinations | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 4.6 | Inequality with different operations | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |

### AC2: CanUseToolResult Extension (3 new fields)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 5.1 | updatedPermissions field defaults to nil | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 5.2 | interrupt field defaults to nil | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 5.3 | toolUseID field defaults to nil | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 5.4 | Can create with updatedPermissions set | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 5.5 | Can create with interrupt set | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 5.6 | Can create with toolUseID set | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 5.7 | Backward compat: existing init compiles | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 5.8 | Equality still works with new fields | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 5.9 | Factory methods (.allow, .deny, .allowWithInput) still work | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 5.10 | Compat: field presence check for updatedPermissions | Compat | P0 | PermissionSystemCompatTests.swift | RED |
| 5.11 | Compat: field presence check for interrupt | Compat | P0 | PermissionSystemCompatTests.swift | RED |
| 5.12 | Compat: field presence check for toolUseID | Compat | P0 | PermissionSystemCompatTests.swift | RED |

### AC2: ToolContext Extension (4 new fields)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 6.1 | suggestions field defaults to nil | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 6.2 | blockedPath field defaults to nil | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 6.3 | decisionReason field defaults to nil | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 6.4 | agentId field defaults to nil | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 6.5 | Can create with all new fields set | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 6.6 | Backward compat: existing init compiles | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 6.7 | withToolUseId preserves all new fields | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 6.8 | withSkillContext preserves all new fields | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 6.9 | Existing call sites compile without modification | Unit | P1 | PermissionSystemEnhancementATDDTests.swift | RED |
| 6.10 | Compat: field presence check for suggestions | Compat | P0 | PermissionSystemCompatTests.swift | RED |
| 6.11 | Compat: field presence check for blockedPath | Compat | P0 | PermissionSystemCompatTests.swift | RED |
| 6.12 | Compat: field presence check for decisionReason | Compat | P0 | PermissionSystemCompatTests.swift | RED |
| 6.13 | Compat: field presence check for agentId | Compat | P0 | PermissionSystemCompatTests.swift | RED |

### AC3: SDKPermissionDenial Integration

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 7.1 | SDKPermissionDenial type accessible | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 7.2 | SDKPermissionDenial conforms to Sendable | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 7.3 | SDKPermissionDenial conforms to Equatable | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 7.4 | ResultData.permissionDenials field exists and defaults nil | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 7.5 | ResultData.permissionDenials can be populated | Unit | P0 | PermissionSystemEnhancementATDDTests.swift | RED |
| 7.6 | Compat: SDKPermissionDenial type verified | Compat | P0 | PermissionSystemCompatTests.swift | RED |
| 7.7 | Compat: ResultData.permissionDenials verified | Compat | P0 | PermissionSystemCompatTests.swift | RED |

### AC4: Build and Compat Report

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 8.1 | Compat: full gap report shows 21 RESOLVED, 0 MISSING | Compat | P0 | PermissionSystemCompatTests.swift | RED |
| 8.2 | swift build zero errors zero warnings | Build | P0 | (CLI verification) | PENDING |
| 8.3 | 3900+ existing tests pass | Regression | P0 | (CLI verification) | PENDING |

## Test File Summary

| File | Tests | Classes |
|---|---|---|
| PermissionSystemEnhancementATDDTests.swift | 40 | 7 |
| PermissionSystemCompatTests.swift | 25 | 7 |
| **Total** | **65** | **14** |

## TDD Red Phase Status

- All tests assert EXPECTED behavior
- All tests will FAIL until feature is implemented
- This is INTENTIONAL (TDD red phase)

## Notes

- PermissionUpdateDestination, PermissionUpdateOperation, PermissionUpdateAction are new types to be added to PermissionTypes.swift
- PermissionBehavior.ask is a single case addition to HookTypes.swift
- ToolContext gets 4 new optional fields with nil defaults (backward compatible)
- CanUseToolResult gets 3 new optional fields with nil defaults (backward compatible)
- SDKPermissionDenial was added by Story 17-1; this story verifies integration only
- ToolExecutor does NOT currently wire permissionDenials; the test for ResultData permissionDenials
  verifies the field exists, but ToolExecutor wiring is AC3 scope
- No E2E tests: pure backend unit/compat tests per project conventions

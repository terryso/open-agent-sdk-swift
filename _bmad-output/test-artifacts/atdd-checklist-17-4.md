---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
lastStep: step-04c-aggregate
lastSaved: '2026-04-17'
storyId: '17-4'
storyTitle: 'Hook System Enhancement'
tddPhase: 'RED'
inputDocuments:
  - '_bmad-output/implementation-artifacts/17-4-hook-system-enhancement.md'
  - 'Sources/OpenAgentSDK/Types/HookTypes.swift'
  - 'Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift'
  - 'Tests/OpenAgentSDKTests/Compat/HookSystemCompatTests.swift'
  - 'Tests/OpenAgentSDKTests/Types/HookTypesTests.swift'
---

# ATDD Checklist: Story 17-4 Hook System Enhancement

## Preflight Summary

- **Story:** 17-4 Hook System Enhancement
- **Stack:** Backend (Swift)
- **Framework:** XCTest
- **Mode:** AI Generation (backend, no browser)
- **TDD Phase:** RED (failing tests before implementation)

## Acceptance Criteria -> Test Mapping

### AC1: 3 Missing HookEvent Cases (setup, worktreeCreate, worktreeRemove)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 1.1 | HookEvent.setup rawValue equals "setup" | Unit | P0 | HookTypesTests.swift | RED |
| 1.2 | HookEvent.worktreeCreate rawValue equals "worktreeCreate" | Unit | P0 | HookTypesTests.swift | RED |
| 1.3 | HookEvent.worktreeRemove rawValue equals "worktreeRemove" | Unit | P0 | HookTypesTests.swift | RED |
| 1.4 | HookEvent.allCases.count is 23 (20 existing + 3 new) | Unit | P0 | HookTypesTests.swift | RED |
| 1.5 | Compat: testHookEvent_setup_gap -> XCTAssertNotNil | Compat | P0 | HookSystemCompatTests.swift | RED |
| 1.6 | Compat: testHookEvent_worktreeCreate_gap -> XCTAssertNotNil | Compat | P0 | HookSystemCompatTests.swift | RED |
| 1.7 | Compat: testHookEvent_worktreeRemove_gap -> XCTAssertNotNil | Compat | P0 | HookSystemCompatTests.swift | RED |
| 1.8 | Compat: testHookEvent_coverageSummary -> 18 pass, 0 missing | Compat | P0 | HookSystemCompatTests.swift | RED |
| 1.9 | Compat: testHookEvent_has23Cases (updated from 20) | Compat | P0 | HookSystemCompatTests.swift | RED |

### AC2: HookInput Base Fields (transcriptPath, permissionMode, agentId, agentType)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 2.1 | HookInput has transcriptPath field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 2.2 | HookInput has permissionMode field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 2.3 | HookInput has agentId field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 2.4 | HookInput has agentType field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 2.5 | HookInput init with all new base fields compiles | Unit | P0 | HookTypesTests.swift | RED |
| 2.6 | HookInput backward compat: existing call sites compile (8 args) | Unit | P1 | HookTypesTests.swift | RED |
| 2.7 | Compat: testHookInput_transcriptPath_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 2.8 | Compat: testHookInput_permissionMode_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 2.9 | Compat: testHookInput_agentId_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 2.10 | Compat: testHookInput_agentType_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 2.11 | Compat: testHookInput_fieldCount -> updated from 8 to 20 | Compat | P0 | HookSystemCompatTests.swift | RED |

### AC3: Per-Event HookInput Fields (8 fields)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 3.1 | HookInput has stopHookActive field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 3.2 | HookInput has lastAssistantMessage field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 3.3 | HookInput has trigger field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 3.4 | HookInput has customInstructions field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 3.5 | HookInput has permissionSuggestions field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 3.6 | HookInput has isInterrupt field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 3.7 | HookInput has agentTranscriptPath field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 3.8 | Compat: testHookInput_isInterrupt_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 3.9 | Compat: testHookInput_stopHookActive_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 3.10 | Compat: testHookInput_lastAssistantMessage_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 3.11 | Compat: testHookInput_agentTranscriptPath_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 3.12 | Compat: testHookInput_preCompact_trigger_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 3.13 | Compat: testHookInput_preCompact_customInstructions_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 3.14 | Compat: testHookInput_permissionRequest_permissionSuggestions_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |

### AC4: HookOutput Fields + PermissionDecision Enum

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 4.1 | PermissionDecision has allow, deny, ask cases | Unit | P0 | HookTypesTests.swift | RED |
| 4.2 | PermissionDecision rawValues match names | Unit | P0 | HookTypesTests.swift | RED |
| 4.3 | PermissionDecision is CaseIterable with 3 cases | Unit | P0 | HookTypesTests.swift | RED |
| 4.4 | PermissionDecision conforms to Sendable, Equatable | Unit | P0 | HookTypesTests.swift | RED |
| 4.5 | HookOutput has systemMessage field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 4.6 | HookOutput has reason field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 4.7 | HookOutput has updatedInput field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 4.8 | HookOutput has additionalContext field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 4.9 | HookOutput has permissionDecision field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 4.10 | HookOutput has updatedMCPToolOutput field with default nil | Unit | P0 | HookTypesTests.swift | RED |
| 4.11 | HookOutput backward compat: existing 4-arg init compiles | Unit | P1 | HookTypesTests.swift | RED |
| 4.12 | HookOutput Equatable still works with new fields | Unit | P0 | HookTypesTests.swift | RED |
| 4.13 | Compat: testHookOutput_systemMessage_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 4.14 | Compat: testHookOutput_reason_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 4.15 | Compat: testHookOutput_updatedInput_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 4.16 | Compat: testHookOutput_additionalContext_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 4.17 | Compat: testHookOutput_updatedMCPToolOutput_gap -> field exists | Compat | P0 | HookSystemCompatTests.swift | RED |
| 4.18 | Compat: testHookOutput_fieldCount -> updated from 4 to 10 | Compat | P0 | HookSystemCompatTests.swift | RED |
| 4.19 | Compat: testPermissionBehavior_ask_gap -> PermissionDecision has ask | Compat | P0 | HookSystemCompatTests.swift | RED |

### AC5: ShellHookExecutor JSON Parsing

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 5.1 | parseHookOutput parses systemMessage | Unit | P0 | ShellHookExecutorTests.swift | RED |
| 5.2 | parseHookOutput parses reason | Unit | P0 | ShellHookExecutorTests.swift | RED |
| 5.3 | parseHookOutput parses updatedInput as dict | Unit | P0 | ShellHookExecutorTests.swift | RED |
| 5.4 | parseHookOutput parses additionalContext | Unit | P0 | ShellHookExecutorTests.swift | RED |
| 5.5 | parseHookOutput parses permissionDecision | Unit | P0 | ShellHookExecutorTests.swift | RED |
| 5.6 | parseHookOutput parses updatedMCPToolOutput | Unit | P0 | ShellHookExecutorTests.swift | RED |
| 5.7 | ShellHookExecutor stdin JSON includes transcriptPath | Unit | P1 | ShellHookExecutorTests.swift | RED |
| 5.8 | ShellHookExecutor stdin JSON includes permissionMode | Unit | P1 | ShellHookExecutorTests.swift | RED |
| 5.9 | ShellHookExecutor stdin JSON includes agentId | Unit | P1 | ShellHookExecutorTests.swift | RED |
| 5.10 | ShellHookExecutor stdin JSON includes agentType | Unit | P1 | ShellHookExecutorTests.swift | RED |

## Summary Statistics

- **Total test scenarios:** 57
- **P0 (must pass):** 53
- **P1 (should pass):** 4
- **Test files modified:** 3 (HookSystemCompatTests.swift, HookTypesTests.swift, ShellHookExecutorTests.swift)
- **TDD Phase:** RED (all tests fail until implementation)
- **Compilation errors:** 181 (all expected -- missing types, fields, init params)
- **Unique error categories:** 30 (covering all 20 gap items)

## TDD RED Phase Verification

Build command: `swift build --build-tests`
Result: **FAILS** with 181 compilation errors -- all referencing missing types/fields from Story 17-4 scope.

Error breakdown:
- `cannot find 'PermissionDecision' in scope` -- new enum needed
- `value of type 'HookInput' has no member 'xxx'` -- 11 new fields needed
- `value of type 'HookOutput' has no member 'xxx'` -- 6 new fields needed
- `extra argument 'xxx' in call` -- init signatures need updating
- HookEvent rawValue lookups for setup/worktreeCreate/worktreeRemove return nil

## Test Files

1. `Tests/OpenAgentSDKTests/Compat/HookSystemCompatTests.swift` - Gap tests flipped to pass expectations
2. `Tests/OpenAgentSDKTests/Types/HookTypesTests.swift` - New unit tests for enhanced types
3. `Tests/OpenAgentSDKTests/Hooks/ShellHookExecutorTests.swift` - New parsing tests for enhanced fields

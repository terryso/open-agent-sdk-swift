---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-18'
inputDocuments:
  - '_bmad-output/implementation-artifacts/18-4-update-compat-hooks.md'
  - 'Examples/CompatHooks/main.swift'
  - 'Tests/OpenAgentSDKTests/Compat/HookSystemCompatTests.swift'
  - 'Sources/OpenAgentSDK/Types/HookTypes.swift'
story_id: '18-4'
communication_language: 'English'
detected_stack: 'backend'
generation_mode: 'ai-generation'
---

# ATDD Checklist: Story 18-4 Update CompatHooks Example

## Story Summary

Story 18-4 updates `Examples/CompatHooks/main.swift` and its companion compat tests to change MISSING/PARTIAL entries to PASS for all features implemented by Story 17-4 (Hook System Enhancement) and Story 17-5 (Permission System Enhancement). This is a pure update story -- no new production code, only updating existing example file.

**As a** SDK developer
**I want** to update the CompatHooks example to reflect Stories 17-4 and 17-5 features
**So that** the compatibility report accurately shows current Swift SDK vs TS SDK alignment for the hook system

## Stack Detection

- **Detected stack:** `backend` (Swift Package Manager project, XCTest)
- **Test framework:** XCTest (Swift built-in)
- **Test level:** Unit tests for compat report field mapping verification

## Generation Mode

- **Mode:** AI Generation (backend project, no browser testing needed)

## Acceptance Criteria

1. **AC1:** 3 new HookEvent cases PASS -- Setup, WorktreeCreate, WorktreeRemove verified
2. **AC2:** 4 base HookInput fields PASS -- transcriptPath, permissionMode, agentId, agentType verified
3. **AC3:** 7 per-event HookInput fields PASS -- isInterrupt, stopHookActive, lastAssistantMessage, agentTranscriptPath, trigger, customInstructions, permissionSuggestions verified
4. **AC4:** 5 HookOutput fields PASS -- systemMessage, updatedInput, additionalContext, updatedMCPToolOutput verified; PermissionDecision (allow/deny/ask) verified
5. **AC5:** Reason field upgraded PARTIAL to PASS -- dedicated field exists, not just "message is similar"
6. **AC6:** PermissionDecision upgraded PARTIAL to PASS -- PermissionDecision enum with allow/deny/ask + PermissionBehavior.ask from Story 17-5
7. **AC7:** Build and tests pass -- swift build zero errors zero warnings, all existing tests pass

## Test Strategy: Acceptance Criteria to Test Mapping

### AC1: 3 New HookEvent Cases (5 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | HookEvent.setup exists (rawValue: "setup") | Unit | P0 | PASS (type exists) |
| 2 | HookEvent.worktreeCreate exists (rawValue: "worktreeCreate") | Unit | P0 | PASS (type exists) |
| 3 | HookEvent.worktreeRemove exists (rawValue: "worktreeRemove") | Unit | P0 | PASS (type exists) |
| 4 | HookEvent has exactly 23 cases | Unit | P0 | PASS (verified) |
| 5 | All 18 TS SDK HookEvents have Swift equivalents | Unit | P0 | PASS (verified) |

### AC2: 4 Base HookInput Fields (4 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | HookInput.transcriptPath accessible | Unit | P0 | PASS (type exists) |
| 2 | HookInput.permissionMode accessible | Unit | P0 | PASS (type exists) |
| 3 | HookInput.agentId accessible | Unit | P0 | PASS (type exists) |
| 4 | HookInput.agentType accessible | Unit | P0 | PASS (type exists) |

### AC3: 7 Per-Event HookInput Fields (7 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | HookInput.isInterrupt accessible | Unit | P0 | PASS (type exists) |
| 2 | HookInput.stopHookActive accessible | Unit | P0 | PASS (type exists) |
| 3 | HookInput.lastAssistantMessage accessible | Unit | P0 | PASS (type exists) |
| 4 | HookInput.agentTranscriptPath accessible | Unit | P0 | PASS (type exists) |
| 5 | HookInput.trigger accessible | Unit | P0 | PASS (type exists) |
| 6 | HookInput.customInstructions accessible | Unit | P0 | PASS (type exists) |
| 7 | HookInput.permissionSuggestions accessible | Unit | P0 | PASS (type exists) |

### AC4: 5 HookOutput Fields (5 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | HookOutput.systemMessage accessible | Unit | P0 | PASS (type exists) |
| 2 | HookOutput.updatedInput accessible | Unit | P0 | PASS (type exists) |
| 3 | HookOutput.additionalContext accessible | Unit | P0 | PASS (type exists) |
| 4 | HookOutput.updatedMCPToolOutput accessible | Unit | P0 | PASS (type exists) |
| 5 | HookOutput has 10 fields total | Unit | P0 | PASS (verified) |

### AC5: Reason Field Upgraded PARTIAL to PASS (2 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | HookOutput.reason is a dedicated field | Unit | P0 | PASS (type exists) |
| 2 | HookOutput.reason is distinct from message | Unit | P0 | PASS (verified) |

### AC6: PermissionDecision and PermissionBehavior.ask (3 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | PermissionDecision has allow/deny/ask cases | Unit | P0 | PASS (type exists) |
| 2 | HookOutput.permissionDecision uses PermissionDecision enum | Unit | P0 | PASS (type exists) |
| 3 | PermissionBehavior.ask exists | Unit | P0 | PASS (type exists) |

### AC7: Compat Report Update Verification (5 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | EventMapping table: 18 PASS, 0 MISSING | Unit | P0 | PASS (SDK verified) |
| 2 | InputFieldMapping table: 18 PASS, 0 MISSING | Unit | P0 | PASS (SDK verified) |
| 3 | OutputFieldMapping table: 6 PASS, 1 PARTIAL, 0 MISSING | Unit | P0 | PASS (SDK verified) |
| 4 | Full HookInput construction with all 19 fields | Unit | P0 | PASS (compile-time) |
| 5 | Full HookOutput construction with all 10 fields | Unit | P0 | PASS (compile-time) |

## Failing Tests Created (RED Phase)

### Unit/Compat Tests (31 tests)

**File:** `Tests/OpenAgentSDKTests/Compat/Story18_4_ATDDTests.swift`

Tests organized by acceptance criteria:

- **AC1 (5 tests):** HookEvent coverage -- setup, worktreeCreate, worktreeRemove, case count, all-18 coverage
- **AC2 (4 tests):** Base HookInput fields -- transcriptPath, permissionMode, agentId, agentType
- **AC3 (7 tests):** Per-event HookInput fields -- isInterrupt, stopHookActive, lastAssistantMessage, agentTranscriptPath, trigger, customInstructions, permissionSuggestions
- **AC4 (5 tests):** HookOutput fields -- systemMessage, updatedInput, additionalContext, updatedMCPToolOutput, field count
- **AC5 (2 tests):** Reason field -- dedicated field, distinct from message
- **AC6 (3 tests):** PermissionDecision -- allow/deny/ask cases, permissionDecision usage, PermissionBehavior.ask
- **AC7 (5 tests):** Compat report verification -- event mapping, input mapping, output mapping, full construction x2

### GREEN Phase Note

All 31 tests PASS immediately because they verify the SDK API which was already implemented by Stories 17-4 and 17-5. The actual "RED" work for this story is updating the CompatHooks example file (`Examples/CompatHooks/main.swift`) to change MISSING/PARTIAL entries to PASS.

The compat report tests in `HookSystemCompatTests.swift` were already updated by Story 17-4 and show the correct counts: 18 PASS events, 18 PASS input fields, 6 PASS + 1 PARTIAL output fields.

## Implementation Checklist

### Task 1: Update AC2 in main.swift (Base HookInput fields)
- [ ] Change 4 MISSING entries (transcript_path, permission_mode, agent_id, agent_type) to PASS
- [ ] Add field verification with actual HookInput construction

### Task 2: Update AC3 in main.swift (Per-event HookInput fields)
- [ ] Change 7 MISSING entries (is_interrupt, stop_hook_active, etc.) to PASS
- [ ] Add per-event field verification

### Task 3: Update AC4 in main.swift (HookOutput fields)
- [ ] Change 4 MISSING entries (systemMessage, updatedInput, additionalContext, updatedMCPToolOutput) to PASS
- [ ] Change reason from PARTIAL to PASS
- [ ] Change permissionDecision from PARTIAL to PASS
- [ ] Change PermissionBehavior.ask from MISSING to PASS
- [ ] Keep decision (approve/block) as PARTIAL (genuine gap)

### Task 4: Update AC9 report tables in main.swift
- [ ] EventMapping table: rows 13, 17, 18 from MISSING to PASS (all 18 PASS)
- [ ] InputFieldMapping table: 4 base + 7 per-event from MISSING to PASS (all 18 PASS)
- [ ] OutputFieldMapping table: 4 from MISSING to PASS, 2 from PARTIAL to PASS (6 PASS, 1 PARTIAL)
- [ ] Update summary counts

### Task 5: Verify compat tests still correct
- [ ] Run HookSystemCompatTests -- verify 18 PASS events, 18 PASS input fields, 6 PASS + 1 PARTIAL output fields

### Task 6: Build and test verification
- [ ] `swift build` zero errors zero warnings
- [ ] Run full test suite, report total count

## Running Tests

```bash
# Run all Story 18-4 ATDD tests
swift test --filter Story18_4

# Run specific test classes
swift test --filter Story18_4_HookEventATDDTests
swift test --filter Story18_4_BaseHookInputATDDTests
swift test --filter Story18_4_PerEventHookInputATDDTests
swift test --filter Story18_4_HookOutputATDDTests
swift test --filter Story18_4_ReasonFieldATDDTests
swift test --filter Story18_4_PermissionDecisionATDDTests
swift test --filter Story18_4_CompatReportATDDTests

# Run existing compat tests
swift test --filter HookSystem

# Run full test suite
swift test
```

## Notes

- This story follows the same pattern as Stories 18-1, 18-2, and 18-3: change MISSING/PARTIAL to PASS
- All SDK types were already implemented by Story 17-4 (HookEvent, HookInput, HookOutput, PermissionDecision) and Story 17-5 (PermissionBehavior.ask)
- The compat report test (HookSystemCompatTests) was already updated by Story 17-4 -- no changes expected there
- The ATDD tests all PASS because they verify SDK API, not the example file
- The remaining PARTIAL entry (decision -> block: Bool) is a genuine gap that must be kept
- No production code changes needed -- purely updating the CompatHooks example file
- Test count: 31 ATDD tests for Story 18-4

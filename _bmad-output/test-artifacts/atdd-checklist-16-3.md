---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-15'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/16-3-message-types-compat.md'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Tests/OpenAgentSDKTests/Compat/CoreQueryCompatTests.swift'
  - 'Examples/CompatCoreQuery/main.swift'
  - 'Examples/CompatToolSystem/main.swift'
---

# ATDD Checklist - Epic 16, Story 16-3: Message Types Compatibility Verification

**Date:** 2026-04-15
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (XCTest)

---

## Story Summary

As an SDK developer, I want to verify that Swift SDK's `SDKMessage` covers all 20 TypeScript SDK message subtypes with their fields, so that consumer code handling the message stream can correctly process every event.

**Key scope:**
- SDKMessage 6 enum cases vs TS SDK's 20 message types
- Field-level verification for each associated data type
- SystemData subtype coverage (5 Swift subtypes vs 11+ TS SDK subtypes)
- Gap documentation for missing message types and fields
- Complete 20-row compatibility report

**Out of scope (other stories):**
- Story 16-1: Core Query API compatibility (already complete)
- Story 16-2: Tool system compatibility (already complete)
- Future: Adding missing message types to SDK

---

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- `CompatMessageTypes` executable target in Package.swift, `swift build` passes
2. **AC2: SDKAssistantMessage verification** -- AssistantData fields vs TS SDK (uuid, session_id, message, parent_tool_use_id, error)
3. **AC3: SDKResultMessage verification** -- ResultData success/error subtype fields vs TS SDK
4. **AC4: SDKSystemMessage verification** -- SystemData subtypes vs TS SDK (init, status, compact_boundary, task_notification, + 7 missing subtypes)
5. **AC5: SDKPartialAssistantMessage verification** -- PartialData fields vs TS SDK
6. **AC6: Tool progress message verification** -- SDKToolProgressMessage equivalent check
7. **AC7: Hook-related message verification** -- HookStarted/Progress/Response message checks
8. **AC8: Task-related message verification** -- TaskStarted/Progress/Notification message checks
9. **AC9: Other message type verification** -- FilesPersisted, RateLimit, AuthStatus, PromptSuggestion, ToolUseSummary, LocalCommandOutput
10. **AC10: Complete compatibility report** -- 20-row comparison table with per-type status

---

## Failing Tests Created (ATDD Verification)

### Unit Tests -- MessageTypesCompatTests (68 tests)

**File:** `Tests/OpenAgentSDKTests/Compat/MessageTypesCompatTests.swift`

#### AC1: Build Compilation Verification (2 tests)

- **Test:** `testSDKMessage_hasSixCases`
  - **Verifies:** AC1 -- SDKMessage enum has exactly 6 cases, all compile
  - **Priority:** P0

- **Test:** `testSDKMessage_isSendable`
  - **Verifies:** AC1 -- SDKMessage conforms to Sendable for async streaming
  - **Priority:** P0

#### AC2: SDKAssistantMessage Verification (8 tests)

- **Test:** `testAssistantData_text_available` [P0]
- **Test:** `testAssistantData_model_available` [P0]
- **Test:** `testAssistantData_stopReason_available` [P0]
- **Test:** `testAssistantData_uuid_gap` [GAP]
- **Test:** `testAssistantData_sessionId_gap` [GAP]
- **Test:** `testAssistantData_parentToolUseId_gap` [GAP]
- **Test:** `testAssistantData_error_gap` [GAP]
- **Test:** `testAssistantData_fieldCount` [P0]

#### AC3: SDKResultMessage Verification (13 tests)

- **Test:** `testResultData_successSubtype` [P0]
- **Test:** `testResultData_errorMaxTurnsSubtype` [P0]
- **Test:** `testResultData_errorDuringExecutionSubtype` [P0]
- **Test:** `testResultData_errorMaxBudgetUsdSubtype` [P0]
- **Test:** `testResultData_text_available` [P0]
- **Test:** `testResultData_usage_available` [P0]
- **Test:** `testResultData_numTurns_available` [P0]
- **Test:** `testResultData_durationMs_available` [P0]
- **Test:** `testResultData_totalCostUsd_available` [P0]
- **Test:** `testResultData_costBreakdown_available` [P0]
- **Test:** `testResultData_structuredOutput_gap` [GAP]
- **Test:** `testResultData_permissionDenials_gap` [GAP]
- **Test:** `testResultData_errorsArray_gap` [GAP]

#### AC4: SDKSystemMessage Verification (18 tests)

- **Test:** `testSystemData_initSubtype_exists` [P0]
- **Test:** `testSystemData_compactBoundarySubtype_exists` [P0]
- **Test:** `testSystemData_statusSubtype_exists` [P0]
- **Test:** `testSystemData_taskNotificationSubtype_exists` [P0]
- **Test:** `testSystemData_rateLimitSubtype_exists` [P0]
- **Test:** `testSystemData_subtypeCount` [P0]
- **Test:** `testSystemData_messageField_available` [P0]
- **Test:** `testSystemData_init_sessionId_gap` [GAP]
- **Test:** `testSystemData_init_tools_gap` [GAP]
- **Test:** `testSystemData_init_model_gap` [GAP]
- **Test:** `testSystemData_init_permissionMode_gap` [GAP]
- **Test:** `testSystemData_init_mcpServers_gap` [GAP]
- **Test:** `testSystemData_init_cwd_gap` [GAP]
- **Test:** `testSystemData_taskStartedSubtype_gap` [GAP]
- **Test:** `testSystemData_taskProgressSubtype_gap` [GAP]
- **Test:** `testSystemData_compactBoundary_metadata_gap` [GAP]
- **Test:** `testSystemData_status_permissionMode_gap` [GAP]
- **Test:** `testSystemData_taskNotification_fields_gap` [GAP]

#### AC5: SDKPartialAssistantMessage Verification (6 tests)

- **Test:** `testPartialData_text_available` [P0]
- **Test:** `testPartialData_emptyText` [P0]
- **Test:** `testPartialData_parentToolUseId_gap` [GAP]
- **Test:** `testPartialData_uuid_gap` [GAP]
- **Test:** `testPartialData_sessionId_gap` [GAP]
- **Test:** `testPartialData_fieldCount` [P0]

#### AC6: Tool Progress Message Verification (2 tests)

- **Test:** `testSDKMessage_noToolProgressCase` [P0]
- **Test:** `testSystemData_noToolProgressSubtype` [P0]

#### AC7: Hook-Related Message Verification (3 tests)

- **Test:** `testSystemData_noHookStartedSubtype` [P0]
- **Test:** `testSystemData_noHookProgressSubtype` [P0]
- **Test:** `testSystemData_noHookResponseSubtype` [P0]

#### AC8: Task-Related Message Verification (3 tests)

- **Test:** `testSystemData_noTaskStartedSubtype` [P0]
- **Test:** `testSystemData_noTaskProgressSubtype` [P0]
- **Test:** `testSystemData_taskNotification_exists` [P0]

#### AC9: Other Message Type Verification (8 tests)

- **Test:** `testSystemData_noFilesPersistedSubtype` [P0]
- **Test:** `testSystemData_rateLimit_exists` [P0]
- **Test:** `testSystemData_rateLimit_fields_gap` [GAP]
- **Test:** `testSDKMessage_noAuthStatusCase` [P0]
- **Test:** `testSDKMessage_noPromptSuggestionCase` [P0]
- **Test:** `testSDKMessage_noToolUseSummaryCase` [P0]
- **Test:** `testSDKMessage_noLocalCommandOutputSubtype` [P0]
- **Test:** `testSDKMessage_noUserMessageCase` [P0]

#### AC10: Complete Compatibility Report (2 tests)

- **Test:** `testCompatReport_all20MessageTypes` [P0] -- Full 20-row mapping table with PASS/PARTIAL/MISSING
- **Test:** `testCompatReport_summaryCounts` [P0] -- Verifies 6 Swift cases, summary distribution

#### Additional: ToolUse and ToolResult Coverage (3 tests)

- **Test:** `testToolUseData_fields` [P0]
- **Test:** `testToolResultData_fields` [P0]
- **Test:** `testToolResultData_errorCase` [P0]

---

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | Build compilation verification | 2 tests | P0 |
| AC2 | SDKAssistantMessage verification | 8 tests (4 field + 4 gap) | P0 |
| AC3 | SDKResultMessage verification | 13 tests (10 field + 3 gap) | P0 |
| AC4 | SDKSystemMessage verification | 18 tests (7 field + 11 gap) | P0 |
| AC5 | SDKPartialAssistantMessage verification | 6 tests (2 field + 3 gap + 1 count) | P0 |
| AC6 | Tool progress message verification | 2 tests | P0 |
| AC7 | Hook-related message verification | 3 tests | P0 |
| AC8 | Task-related message verification | 3 tests | P0 |
| AC9 | Other message type verification | 8 tests (2 field + 5 gap + 1 fields) | P0 |
| AC10 | Complete compatibility report | 2 tests | P0 |

**Total: 68 tests covering all 10 acceptance criteria.**

---

## Test Strategy

### Stack Detection
- **Detected:** Backend (Swift Package with XCTest, no frontend/browser testing)
- **Mode:** AI Generation (acceptance criteria are clear, standard API verification scenarios)

### Test Levels
- **Unit Tests (68):** Pure type-level verification tests using Mirror introspection for gap detection

### Priority Distribution
- **P0 (Critical):** 68 tests -- all tests verify core message type compatibility

---

## TDD Phase Validation

- [x] All tests assert EXPECTED behavior (not placeholder assertions)
- [x] All tests compile and pass against existing SDK APIs (verification story, not new feature)
- [x] Each test has clear Given/When/Then structure
- [x] Tests document compatibility gaps inline with [GAP] markers
- [x] Build verification: `swift build --build-tests` succeeds with no errors
- [x] Test execution: All 68 tests pass (0 failures)

---

## Compatibility Gaps Documented

### Missing Message Types (12 of 20 TS types have NO Swift equivalent)

| # | TS SDK Type | Gap Status | Recommendation |
|---|------------|------------|----------------|
| 2 | SDKUserMessage | MISSING | Add `.user(UserData)` case to SDKMessage |
| 9 | SDKTaskStartedMessage | MISSING | Add `taskStarted` to SystemData.Subtype |
| 10 | SDKTaskProgressMessage | MISSING | Add `taskProgress` to SystemData.Subtype |
| 11 | SDKToolProgressMessage | MISSING | Add `.toolProgress(ToolProgressData)` case |
| 12 | SDKHookStartedMessage | MISSING | Add `hookStarted` to SystemData.Subtype |
| 13 | SDKHookProgressMessage | MISSING | Add `hookProgress` to SystemData.Subtype |
| 14 | SDKHookResponseMessage | MISSING | Add `hookResponse` to SystemData.Subtype |
| 15 | SDKAuthStatusMessage | MISSING | Add `.authStatus(AuthStatusData)` case |
| 16 | SDKFilesPersistedEvent | MISSING | Add `filesPersisted` to SystemData.Subtype |
| 18 | SDKLocalCommandOutputMessage | MISSING | Add `localCommandOutput` to SystemData.Subtype |
| 19 | SDKPromptSuggestionMessage | MISSING | Add `.promptSuggestion(PromptSuggestionData)` case |
| 20 | SDKToolUseSummaryMessage | MISSING | Add `.toolUseSummary(ToolUseSummaryData)` case |

### Partial Message Types (8 of 20 TS types have Swift equivalent with missing fields)

| # | TS SDK Type | Swift Equivalent | Missing Fields |
|---|------------|-----------------|----------------|
| 1 | SDKAssistantMessage | .assistant(AssistantData) | uuid, session_id, parent_tool_use_id, error |
| 3 | SDKResultMessage | .result(ResultData) | structuredOutput, permissionDenials, errors[] |
| 4 | SDKSystemMessage(init) | .system(.init) | session_id, tools, model, permissionMode, mcp_servers, cwd |
| 5 | SDKPartialAssistantMessage | .partialMessage(PartialData) | parent_tool_use_id, uuid, session_id |
| 6 | SDKCompactBoundaryMessage | .system(.compactBoundary) | compact_metadata |
| 7 | SDKStatusMessage | .system(.status) | permissionMode |
| 8 | SDKTaskNotificationMessage | .system(.taskNotification) | task_id, output_file, summary, usage |
| 17 | SDKRateLimitEvent | .system(.rateLimit) | rate limit-specific fields |

### Summary

- **PASS (full coverage):** 0 types
- **PARTIAL (has equivalent, missing fields):** 8 types (40%)
- **MISSING (no equivalent):** 12 types (60%)

---

## Implementation Guidance

### Files Created
1. `Tests/OpenAgentSDKTests/Compat/MessageTypesCompatTests.swift` -- 68 ATDD tests

### Files to Create (Story Implementation)
1. `Examples/CompatMessageTypes/main.swift` -- Compatibility verification example
2. Update `Package.swift` -- Add CompatMessageTypes executable target

### Key Implementation Notes
- Example should follow CompatCoreQuery pattern: CompatEntry, record(), bilingual comments
- Use `nonisolated(unsafe)` for mutable global report state
- Use `loadDotEnv()` / `getEnv()` for API key loading
- Use `permissionMode: .bypassPermissions` to simplify example
- Run a live query to capture real messages for field-level comparison
- Report should output per-type compatibility table with PASS/PARTIAL/MISSING
- Include summary with pass rate calculation

---

## Next Steps (Story Implementation)

1. Create `Examples/CompatMessageTypes/main.swift` using the verification patterns tested here
2. Add `CompatMessageTypes` executable target to `Package.swift`
3. Run `swift build` to verify example compiles
4. Run `swift run CompatMessageTypes` to generate compatibility report
5. Verify all 68 ATDD tests still pass after implementation

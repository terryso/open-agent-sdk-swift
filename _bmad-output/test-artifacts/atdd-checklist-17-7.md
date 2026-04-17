---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-17'
storyId: '17-7'
storyTitle: 'Session Management Enhancement'
tddPhase: 'RED'
inputDocuments:
  - '_bmad-output/implementation-artifacts/17-7-session-management-enhancement.md'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Stores/SessionStore.swift'
  - 'Tests/OpenAgentSDKTests/Core/AgentSessionRestoreTests.swift'
  - 'Tests/OpenAgentSDKTests/Compat/SessionManagementCompatTests.swift'
---

# ATDD Checklist: Story 17-7 Session Management Enhancement

## Preflight Summary

- **Story:** 17-7 Session Management Enhancement
- **Stack:** Backend (Swift)
- **Framework:** XCTest
- **Mode:** AI Generation (backend, no browser)
- **TDD Phase:** RED (failing tests before implementation)

## Acceptance Criteria -> Test Mapping

### AC1: continueRecentSession wiring (resolve most recent session from list())

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 1.1 | continueRecentSession=true with existing sessions -> restores most recent | Unit | P0 | SessionManagementWiringATDDTests.swift | RED |
| 1.2 | continueRecentSession=true with no sessions -> proceeds as new session | Unit | P0 | SessionManagementWiringATDDTests.swift | RED |
| 1.3 | continueRecentSession=true with explicit sessionId -> sessionId wins (no-op) | Unit | P0 | SessionManagementWiringATDDTests.swift | GREEN |
| 1.4 | continueRecentSession=false (default) -> no resolution attempted | Unit | P1 | SessionManagementWiringATDDTests.swift | GREEN |

### AC2: forkSession wiring (fork session before restore)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 2.1 | forkSession=true with valid session -> forked copy used, original unchanged | Unit | P0 | SessionManagementWiringATDDTests.swift | RED |
| 2.2 | forkSession=true with non-existent session -> graceful fallback | Unit | P0 | SessionManagementWiringATDDTests.swift | GREEN |
| 2.3 | forkSession=false (default) -> no fork attempted | Unit | P1 | SessionManagementWiringATDDTests.swift | GREEN |

### AC3: resumeSessionAt wiring (truncate history at message UUID)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 3.1 | resumeSessionAt with matching UUID -> history truncated | Unit | P0 | SessionManagementWiringATDDTests.swift | RED |
| 3.2 | resumeSessionAt with non-matching UUID -> full history kept | Unit | P0 | SessionManagementWiringATDDTests.swift | GREEN |
| 3.3 | resumeSessionAt with nil -> no truncation (default) | Unit | P1 | SessionManagementWiringATDDTests.swift | GREEN |
| 3.4 | resumeSessionAt matches "id" key (alternative key name) | Unit | P1 | SessionManagementWiringATDDTests.swift | RED |

### AC4: persistSession wiring verification

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 4.1 | persistSession=true -> session saved after prompt() | Unit | P0 | SessionManagementWiringATDDTests.swift | GREEN |
| 4.2 | persistSession=false -> session NOT saved after prompt() | Unit | P0 | SessionManagementWiringATDDTests.swift | GREEN |
| 4.3 | persistSession=false -> session NOT saved after stream() | Unit | P0 | SessionManagementWiringATDDTests.swift | GREEN |
| 4.4 | persistSession=true -> session saved after stream() | Unit | P0 | SessionManagementWiringATDDTests.swift | GREEN |

### AC5: Combined options and stream() path

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 5.1 | continueRecentSession + forkSession -> fork the continued session | Unit | P0 | SessionManagementWiringATDDTests.swift | RED |
| 5.2 | continueRecentSession + forkSession + resumeSessionAt -> full pipeline | Unit | P1 | SessionManagementWiringATDDTests.swift | RED |
| 5.3 | All options at default values -> no session wiring active | Unit | P1 | SessionManagementWiringATDDTests.swift | GREEN |
| 5.4 | Stream: continueRecentSession works in stream() path | Unit | P0 | SessionManagementWiringATDDTests.swift | RED |
| 5.5 | Stream: forkSession works in stream() path | Unit | P0 | SessionManagementWiringATDDTests.swift | RED |
| 5.6 | Stream: resumeSessionAt works in stream() path | Unit | P0 | SessionManagementWiringATDDTests.swift | RED |

## Test File Summary

| File | Tests | Classes |
|---|---|---|
| SessionManagementWiringATDDTests.swift | 21 | 6 |
| **Total** | **21** | **6** |

## TDD Red Phase Status

- **10 tests FAIL** (RED -- new wiring features not yet implemented)
- **11 tests PASS** (GREEN -- default behavior, already-wired persistSession, baselines)
- All failures are EXPECTED (TDD red phase)
- **4055 total tests** in full suite (21 new + 4034 baseline)
- **0 regressions** in existing tests

### RED Tests (10 failures, all expected)

1. `testContinueRecentSession_withExistingSessions_restoresMostRecent` - continueRecentSession not wired in promptImpl()
2. `testForkSession_withValidSession_createsFork` - forkSession not wired in promptImpl()
3. `testResumeSessionAt_withMatchingUUID_truncatesHistory` - resumeSessionAt not wired in promptImpl()
4. `testResumeSessionAt_matchesIdKey` - resumeSessionAt not wired (alternative key check)
5. `testContinueRecentSession_and_forkSession_forksTheContinuedSession` - combined continue+fork not wired
6. `testContinueRecentAndForkAndResumeAt_fullPipeline` - full pipeline not wired
7. `testStream_continueRecentSession_restoresMostRecent` - continueRecentSession not wired in stream()
8. `testStream_forkSession_createsFork` - forkSession not wired in stream()
9. `testStream_resumeSessionAt_truncatesHistory` - resumeSessionAt not wired in stream()

### GREEN Tests (11 passing)

1. `testContinueRecentSession_withNoSessions_proceedsAsNew` - no sessions = fresh start
2. `testContinueRecentSession_withExplicitSessionId_sessionIdWins` - explicit ID bypasses continue
3. `testContinueRecentSession_false_noResolution` - disabled = no action
4. `testForkSession_withNonExistentSession_gracefulFallback` - graceful on missing source
5. `testForkSession_false_noFork` - disabled = no action
6. `testResumeSessionAt_withNonMatchingUUID_keepsFullHistory` - missing UUID = full history
7. `testResumeSessionAt_nil_noTruncation` - nil = no action
8. `testPersistSession_true_savesAfterPrompt` - already wired
9. `testPersistSession_false_noSaveAfterPrompt` - already wired
10. `testPersistSession_false_noSaveAfterStream` - already wired
11. `testPersistSession_true_savesAfterStream` - already wired
12. `testAllDefaultOptions_noSessionWiring` - defaults = normal behavior

## Implementation Guidance

### Injection Points (from story dev notes)

**promptImpl() flow:**
1. Before line 360 session restore block: wire `continueRecentSession`
2. After continue resolution, before session restore: wire `forkSession`
3. After line 362 session restore, before line 367 append: wire `resumeSessionAt`

**stream() closure flow:**
1. Before line 922 session restore block: wire `continueRecentSession` (using captured vars)
2. After continue resolution, before session restore: wire `forkSession` (using captured vars)
3. After line 924 session restore, before line 929 append: wire `resumeSessionAt`

### Execution Order

continueRecentSession -> forkSession -> session restore -> resumeSessionAt -> append user message

### Key Design Notes

- All new logic guarded by field checks (only executes when option is non-default)
- Use `try?` for session operations (graceful fallback, no thrown errors)
- Capture new variables for stream() Sendable compliance
- No SessionStore changes needed (list(), fork(), load() already exist)
- No new types needed

## Notes

- persistSession is already fully wired (verified by 4 passing tests in AC4)
- continueRecentSession is the only option that needs a new captured variable for stream() (sessionId can change)
- forkSession needs to capture the resolved/forked sessionId for subsequent save operations
- resumeSessionAt operates on already-loaded messages (no new session operations needed)
- No E2E tests with mocks per CLAUDE.md

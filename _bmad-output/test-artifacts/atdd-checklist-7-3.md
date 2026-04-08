---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-08'
inputDocuments:
  - _bmad-output/implementation-artifacts/7-3-session-fork.md
  - Sources/OpenAgentSDK/Stores/SessionStore.swift
  - Sources/OpenAgentSDK/Types/SessionTypes.swift
  - Sources/OpenAgentSDK/Types/ErrorTypes.swift
  - Sources/OpenAgentSDK/Core/Agent.swift
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Tests/OpenAgentSDKTests/Stores/SessionStoreTests.swift
  - Sources/E2ETest/SessionStoreE2ETests.swift
  - Sources/E2ETest/SessionRestoreE2ETests.swift
  - Sources/E2ETest/TestHarness.swift
  - Sources/E2ETest/main.swift
---

# ATDD Checklist: Story 7-3 -- Session Fork

## TDD Red Phase (Current)

**All tests will FAIL until `SessionStore.fork()` is implemented.** Tests reference functionality that does not yet exist:
- `SessionStore.fork(sourceSessionId:newSessionId:upToMessageIndex:)` method (not yet added)
- Forked session metadata (summary with "Forked from" prefix)
- `upToMessageIndex` truncation logic

This is intentional -- TDD red phase.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | Basic fork creates new session with all messages | P0 | Unit | `testFork_createsNewSessionWithAllMessages` |
| AC1 | Fork does not modify original session | P0 | Unit | `testFork_doesNotModifyOriginalSession` |
| AC2 | Fork with upToMessageIndex truncates messages | P0 | Unit | `testFork_withMessageIndex_truncatesMessages` |
| AC2 | Fork with upToMessageIndex=0 produces single message | P0 | Unit | `testFork_withMessageIndexZero_producesSingleMessage` |
| AC2 | Fork with out-of-range index throws error | P1 | Unit | `testFork_withOutOfRangeIndex_throwsError` |
| AC2 | Fork with negative index throws error | P1 | Unit | `testFork_withNegativeIndex_throwsError` |
| AC3 | Fork with custom newSessionId uses provided ID | P0 | Unit | `testFork_withCustomSessionId_usesProvidedId` |
| AC3 | Fork with nil newSessionId auto-generates UUID | P0 | Unit | `testFork_withNilSessionId_autoGeneratesUUID` |
| AC3 | Fork with invalid newSessionId (path traversal) throws | P1 | Unit | `testFork_withInvalidSessionId_throwsError` |
| AC4 | Non-existent source returns nil | P0 | Unit | `testFork_nonexistentSource_returnsNil` |
| AC5 | Forked metadata has correct createdAt and summary | P0 | Unit | `testFork_metadata_correctCreatedAtAndSummary` |
| AC5 | Truncated fork has correct messageCount in metadata | P0 | Unit | `testFork_withTruncation_metadataReflectsTruncatedCount` |
| AC7 | Performance: 500-message fork under 200ms | P1 | Unit | `testFork_performanceUnder200ms` |
| AC8 | Concurrent forks from same source safe | P0 | Unit | `testFork_concurrentForks_noDataCorruption` |
| AC8 | Concurrent forks from different sources safe | P1 | Unit | `testFork_concurrentForks_differentSources_noDataCorruption` |
| AC1,5,6,10 | Full session fork -> restore -> verify integrity | P0 | E2E | `testFullSessionForkAndRestore` |
| AC2,5,6,10 | Truncated fork -> restore -> verify message count | P0 | E2E | `testTruncatedForkRestore` |
| AC1,6,10 | Fork then continue -> verify sessions diverge | P0 | E2E | `testForkThenContinueConversation` |

## Test Summary

- **Total Tests:** 18 (15 unit + 3 E2E)
- **Unit Tests:** 15 (all in `Tests/OpenAgentSDKTests/Stores/SessionStoreForkTests.swift`)
  - Single test class: `SessionStoreForkTests`
- **E2E Tests:** 3 (all in `Sources/E2ETest/SessionForkE2ETests.swift`)
  - Struct: `SessionForkE2ETests` with static methods
- **Red Phase Status:**
  - 15 unit tests: FAILING (expected -- `fork()` not implemented)
  - 3 E2E tests: FAILING (expected -- `fork()` not implemented)

## Unit Test Plan (Tests/OpenAgentSDKTests/Stores/SessionStoreForkTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testFork_createsNewSessionWithAllMessages` | AC1 | P0 | Basic fork copies all messages to new session |
| 2 | `testFork_doesNotModifyOriginalSession` | AC1 | P0 | Original session unchanged after fork |
| 3 | `testFork_withMessageIndex_truncatesMessages` | AC2 | P0 | Fork with upToMessageIndex truncates at index |
| 4 | `testFork_withMessageIndexZero_producesSingleMessage` | AC2 | P0 | Fork with index=0 yields single message |
| 5 | `testFork_withOutOfRangeIndex_throwsError` | AC2 | P1 | Out-of-range index throws SDKError.sessionError |
| 6 | `testFork_withNegativeIndex_throwsError` | AC2 | P1 | Negative index throws SDKError.sessionError |
| 7 | `testFork_withCustomSessionId_usesProvidedId` | AC3 | P0 | Custom newSessionId is used for fork |
| 8 | `testFork_withNilSessionId_autoGeneratesUUID` | AC3 | P0 | Nil newSessionId generates valid UUID |
| 9 | `testFork_withInvalidSessionId_throwsError` | AC3 | P1 | Path traversal newSessionId throws error |
| 10 | `testFork_nonexistentSource_returnsNil` | AC4 | P0 | Non-existent source returns nil (no throw) |
| 11 | `testFork_metadata_correctCreatedAtAndSummary` | AC5 | P0 | Forked session metadata correct (createdAt, summary, cwd, model) |
| 12 | `testFork_withTruncation_metadataReflectsTruncatedCount` | AC5 | P0 | Truncated fork messageCount matches actual count |
| 13 | `testFork_performanceUnder200ms` | AC7,NFR4 | P1 | 500-message fork completes under 200ms |
| 14 | `testFork_concurrentForks_noDataCorruption` | AC8,FR27 | P0 | 10 concurrent forks from same source safe |
| 15 | `testFork_concurrentForks_differentSources_noDataCorruption` | AC8,FR27 | P1 | Concurrent forks from different sources safe |

## E2E Test Plan (Sources/E2ETest/SessionForkE2ETests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testFullSessionForkAndRestore` | AC1,AC5,AC6,AC10 | P0 | Fork full session -> restore via Agent -> verify context (Paris + 99) |
| 2 | `testTruncatedForkRestore` | AC2,AC5,AC6,AC10 | P0 | Fork with truncation -> restore -> verify limited context (Bob only) |
| 3 | `testForkThenContinueConversation` | AC1,AC6,AC10 | P0 | Fork -> continue both sessions -> verify they diverge independently |

## Implementation Guidance

### Files to Modify

1. **`Sources/OpenAgentSDK/Stores/SessionStore.swift`** -- Add fork() method:
   - `public func fork(sourceSessionId: String, newSessionId: String? = nil, upToMessageIndex: Int? = nil) throws -> String?`
   - Load source session via existing `load()` method
   - Return nil if source doesn't exist
   - Truncate messages array if `upToMessageIndex` provided (inclusive, bounds-checked)
   - Generate UUID or use provided newSessionId
   - Validate newSessionId via existing `validateSessionId()`
   - Save new session via existing `save()` with fork metadata

### Files NOT to Modify

- `Types/SessionTypes.swift` -- SessionData, PartialSessionMetadata already defined
- `Types/ErrorTypes.swift` -- SDKError.sessionError already defined
- `Core/Agent.swift` -- Agent restore mechanism already compatible with forked sessions
- `Types/AgentTypes.swift` -- AgentOptions already has sessionStore/sessionId

### Key Implementation Details

- `SessionStore` is an actor -- `fork()` benefits from actor isolation for thread safety
- `load()` returns `SessionData?` -- nil when session doesn't exist
- `save()` accepts `PartialSessionMetadata` -- no need to construct full `SessionMetadata`
- `save()` handles file permissions (0600), directory creation (0700), and JSON serialization
- `validateSessionId()` already checks for path traversal -- reuse for newSessionId
- `upToMessageIndex` is inclusive (0...upToIndex) and bounds-checked
- Summary format: "Forked from session {sourceSessionId}"
- createdAt is set to current time (not preserved from source) -- save() handles this for new sessions

## Validation Results

- [x] Prerequisites satisfied (SessionStore from Story 7-1, restore from Story 7-2 both implemented)
- [x] Test files created correctly (1 unit test file, 1 E2E test file)
- [x] Checklist matches all 10 acceptance criteria from story
- [x] Tests designed to fail before implementation (all 18 tests failing on red phase)
- [x] No orphaned browser sessions (backend project, no browser)
- [x] Temp artifacts stored in `_bmad-output/test-artifacts/`
- [x] E2E tests registered in main.swift (Section 36)
- [x] Unit tests follow existing naming convention: `test{MethodName}_{scenario}_{expectedBehavior}`
- [x] E2E tests use real filesystem (no mocks) per project convention
- [x] Fork E2E tests use same message serialization pattern as SessionRestoreE2ETests

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Add `fork(sourceSessionId:newSessionId:upToMessageIndex:)` to `SessionStore.swift`
2. Run `swift build` to verify compilation (E2E tests will now compile)
3. Run `swift test --filter "SessionStoreFork"` to verify unit tests pass
4. Run `swift run E2ETest` to verify E2E tests pass
5. Run full test suite to verify no regressions
6. Commit passing tests

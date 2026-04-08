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
  - _bmad-output/implementation-artifacts/7-2-session-load-restore.md
  - Sources/OpenAgentSDK/Core/Agent.swift
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Sources/OpenAgentSDK/Stores/SessionStore.swift
  - Sources/OpenAgentSDK/Types/SessionTypes.swift
  - Sources/OpenAgentSDK/Types/ErrorTypes.swift
  - Sources/OpenAgentSDK/API/LLMClient.swift
  - Tests/OpenAgentSDKTests/Core/AgentLoopTests.swift
  - Tests/OpenAgentSDKTests/Stores/SessionStoreTests.swift
  - Sources/E2ETest/SessionStoreE2ETests.swift
  - Sources/E2ETest/TestHarness.swift
---

# ATDD Checklist: Story 7-2 -- Session Load & Restore

## TDD Red Phase (Current)

**All tests will FAIL until session restore is implemented in Agent.** Tests reference functionality that does not yet exist:
- `AgentOptions.sessionStore` and `AgentOptions.sessionId` properties (not yet added)
- `Agent.prompt()` session restore logic (not yet implemented)
- `Agent.stream()` session restore logic (not yet implemented)
- Auto-save after prompt/stream (not yet implemented)

This is intentional -- TDD red phase.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | Restore with Agent.prompt() | P0 | Unit | `testPrompt_withSessionId_restoresHistory` |
| AC2 | Restore with Agent.stream() | P0 | Unit | `testStream_withSessionId_restoresHistory` |
| AC3 | Loaded messages compatible with agent loop | P0 | Unit | `testRestoredMessages_compatibleWithAgentLoop` |
| AC4 | Non-existent sessionId handling | P0 | Unit | `testPrompt_nonexistentSessionId_startsFresh`, `testStream_nonexistentSessionId_startsFresh` |
| AC5 | SessionStore integration (AgentOptions) | P0 | Unit | `testAgentOptions_hasSessionStoreProperty`, `testAgentOptions_defaultSessionPropertiesAreNil`, `testAgentOptions_initFromConfig_sessionPropertiesAreNil` |
| AC5 | Auto-save after prompt/stream | P0 | Unit | `testPrompt_autoSave_updatesPersistedData`, `testStream_autoSave_updatesPersistedData` |
| AC6 | Performance (<200ms for 500 messages) | P1 | Unit | `testPerformance_restoreUnder200ms` |
| AC7 | Unit test coverage | -- | Unit | All 11 unit tests above |
| AC8 | E2E test coverage | -- | E2E | `testSaveRestoreRoundTrip`, `testMultiTurnRestore` |

## Test Summary

- **Total Tests:** 13 (11 unit + 2 E2E)
- **Unit Tests:** 11 (all in `Tests/OpenAgentSDKTests/Core/AgentSessionRestoreTests.swift`)
  - 4 test classes: AgentPromptSessionRestoreTests (3), AgentStreamSessionRestoreTests (3), SessionRestoreMessageFormatTests (2), AgentOptionsSessionStoreTests (3)
- **E2E Tests:** 2 (all in `Sources/E2ETest/SessionRestoreE2ETests.swift`)
- **Red Phase Status:**
  - 8 tests FAILING (expected -- session restore not implemented)
  - 3 tests PASSING (message format + performance tests work with existing SessionStore)

## Unit Test Plan (Tests/OpenAgentSDKTests/Core/AgentSessionRestoreTests.swift)

| # | Test Class | Test Method | AC | Priority | Description |
|---|-----------|-------------|-----|----------|-------------|
| 1 | AgentPromptSessionRestoreTests | `testPrompt_withSessionId_restoresHistory` | AC1 | P0 | prompt() restores history and sends to LLM with new message |
| 2 | AgentPromptSessionRestoreTests | `testPrompt_nonexistentSessionId_startsFresh` | AC4 | P0 | prompt() with non-existent sessionId starts from empty conversation |
| 3 | AgentPromptSessionRestoreTests | `testPrompt_autoSave_updatesPersistedData` | AC5 | P0 | prompt() auto-saves updated messages after completion |
| 4 | AgentStreamSessionRestoreTests | `testStream_withSessionId_restoresHistory` | AC2 | P0 | stream() restores history and sends to LLM with new message |
| 5 | AgentStreamSessionRestoreTests | `testStream_nonexistentSessionId_startsFresh` | AC4 | P0 | stream() with non-existent sessionId starts from empty conversation |
| 6 | AgentStreamSessionRestoreTests | `testStream_autoSave_updatesPersistedData` | AC5 | P0 | stream() auto-saves updated messages after completion |
| 7 | SessionRestoreMessageFormatTests | `testRestoredMessages_compatibleWithAgentLoop` | AC3 | P0 | Loaded messages preserve role/content structure for sendMessage() |
| 8 | SessionRestoreMessageFormatTests | `testPerformance_restoreUnder200ms` | AC6,NFR4 | P1 | Restore of 500 messages completes within 200ms |
| 9 | AgentOptionsSessionStoreTests | `testAgentOptions_hasSessionStoreProperty` | AC5 | P0 | AgentOptions accepts sessionStore and sessionId parameters |
| 10 | AgentOptionsSessionStoreTests | `testAgentOptions_defaultSessionPropertiesAreNil` | AC5 | P0 | AgentOptions defaults have nil sessionStore and sessionId |
| 11 | AgentOptionsSessionStoreTests | `testAgentOptions_initFromConfig_sessionPropertiesAreNil` | AC5 | P0 | AgentOptions(from:) sets session properties to nil |

## E2E Test Plan (Sources/E2ETest/SessionRestoreE2ETests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testSaveRestoreRoundTrip` | AC1,AC5,AC8 | P0 | Save session -> restore via prompt() -> verify context -> verify auto-save |
| 2 | `testMultiTurnRestore` | AC1,AC2,AC8 | P0 | Save multi-turn -> restore -> verify all turns in context |

## Implementation Guidance

### Files to Modify

1. **`Sources/OpenAgentSDK/Types/AgentTypes.swift`** -- Add to `AgentOptions`:
   - `public var sessionStore: SessionStore?` property
   - `public var sessionId: String?` property
   - Update both `init()` and `init(from:)` with nil defaults

2. **`Sources/OpenAgentSDK/Core/Agent.swift`** -- Add restore logic:
   - In `prompt()`: Load session before buildMessages, save after loop
   - In `stream()`: Load session before stream, save after stream
   - Handle non-existent sessionId (nil from load -> empty start)

### Files NOT to Modify

- `Stores/SessionStore.swift` -- load() and save() already satisfy requirements
- `Types/SessionTypes.swift` -- SessionData and PartialSessionMetadata already defined
- `Types/ErrorTypes.swift` -- SDKError.sessionError already defined

### Key Implementation Details

- `SessionStore` is an actor -- all calls need `await`
- `load()` returns `SessionData?` -- nil means session doesn't exist
- Messages format `[[String: Any]]` is directly compatible with Agent internals
- Use `try? await sessionStore.load()` for silent failure on non-existent sessions
- Use `try? await sessionStore.save()` to avoid save failures affecting main flow
- AgentOptions is a struct (Sendable) -- actor references (SessionStore) are naturally Sendable

## Validation Results

- [x] Prerequisites satisfied (SessionStore from Story 7-1 is implemented)
- [x] Test files created correctly (1 unit test file, 1 E2E test file)
- [x] Checklist matches all 8 acceptance criteria from story
- [x] Tests designed to fail before implementation (8 failing, 3 passing on existing infra)
- [x] No orphaned browser sessions (backend project, no browser)
- [x] Temp artifacts stored in `_bmad-output/test-artifacts/`
- [x] Unit tests compile and run (8 expected failures)
- [x] E2E tests compile and register in main.swift
- [x] Full test suite passes (no regressions from new test files)

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Add `sessionStore` and `sessionId` to `AgentOptions`
2. Implement restore logic in `Agent.prompt()` and `Agent.stream()`
3. Implement auto-save after loop completion
4. Uncomment the commented-out property assignments in test files
5. Remove placeholder `XCTFail` assertions in AgentOptionsSessionStoreTests
6. Run `swift build` to verify compilation
7. Run `swift test --filter "AgentSessionRestore"` to verify unit tests pass
8. Run `swift run E2ETest` to verify E2E tests pass
9. Run full test suite to verify no regressions
10. Commit passing tests

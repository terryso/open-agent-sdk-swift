---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
lastStep: step-04c-aggregate
lastSaved: '2026-04-08'
inputDocuments:
  - _bmad-output/implementation-artifacts/7-1-session-store-json-persistence.md
  - Sources/OpenAgentSDK/Types/SessionTypes.swift
  - Sources/OpenAgentSDK/Types/ErrorTypes.swift
  - Sources/OpenAgentSDK/Stores/TaskStore.swift
  - Sources/OpenAgentSDK/Utils/EnvUtils.swift
  - Tests/OpenAgentSDKTests/Stores/TaskStoreTests.swift
  - Sources/E2ETest/StoreTests.swift
  - Sources/E2ETest/TestHarness.swift
---

# ATDD Checklist: Story 7-1 -- SessionStore Actor & JSON Persistence

## TDD Red Phase (Current)

**All tests will FAIL until `SessionStore` is implemented.** Tests reference types that do not yet exist (`SessionStore`, `PartialSessionMetadata`), so they will not compile. This is intentional -- TDD red phase.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | SessionStore Actor basic structure | P0 | Unit | `testInit_createsSessionStoreActor` |
| AC2 | Save session to JSON file | P0 | Unit | `testSave_createsDirectoryAndFile`, `testSave_filePermissions0600` |
| AC2 | Save session to JSON file | P0 | E2E | `testSaveLoad_roundTrip` |
| AC3 | Session load | P0 | Unit | `testLoad_returnsCorrectSessionData`, `testLoad_nonexistentSession_returnsNil` |
| AC4 | Session delete | P0 | Unit | `testDelete_removesSessionDirectory`, `testDelete_nonexistentSession_returnsFalse` |
| AC5 | Concurrent safety | P0 | Unit | `testConcurrentSave_noDataLoss` |
| AC6 | Performance (<200ms for 500 messages) | P1 | Unit | `testPerformance_saveUnder200ms` |
| AC7 | Message serialization format | P0 | Unit | `testSaveLoad_messageSerializationRoundTrip` |
| AC8 | Home directory resolution | P0 | Unit | `testGetSessionsDir_resolvesHomeDirectory` |
| AC9 | Unit test coverage | -- | Unit | All unit tests above |
| AC10 | E2E test coverage | -- | E2E | `testSaveLoad_roundTrip`, `testFilePermissions`, `testDirectoryAutoCreation` |

## Test Summary

- **Total Tests:** 13 (10 unit + 3 E2E)
- **Unit Tests:** 10 (all in `Tests/OpenAgentSDKTests/Stores/SessionStoreTests.swift`)
- **E2E Tests:** 3 (all in `Sources/E2ETest/SessionStoreE2ETests.swift`)
- **All tests will FAIL until feature is implemented** (compilation failure -- types don't exist)

## Unit Test Plan (Tests/OpenAgentSDKTests/Stores/SessionStoreTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testInit_createsSessionStoreActor` | AC1 | P0 | SessionStore can be instantiated as an actor |
| 2 | `testSave_createsDirectoryAndFile` | AC2 | P0 | save() creates directory structure and transcript.json |
| 3 | `testSave_filePermissions0600` | AC2,NFR10 | P0 | Saved file has 0600 permissions (user read/write only) |
| 4 | `testLoad_returnsCorrectSessionData` | AC3 | P0 | load() returns SessionData with correct metadata and messages |
| 5 | `testLoad_nonexistentSession_returnsNil` | AC3 | P0 | load() returns nil for non-existent session |
| 6 | `testDelete_removesSessionDirectory` | AC4 | P0 | delete() removes session directory and returns true |
| 7 | `testDelete_nonexistentSession_returnsFalse` | AC4 | P0 | delete() returns false for non-existent session |
| 8 | `testConcurrentSave_noDataLoss` | AC5,FR27 | P0 | Concurrent saves complete without data loss |
| 9 | `testGetSessionsDir_resolvesHomeDirectory` | AC8 | P0 | Custom directory injection works correctly |
| 10 | `testSaveLoad_emptyMessages` | AC7 | P0 | Save and load empty message list round-trip |
| 11 | `testPerformance_saveUnder200ms` | AC6,NFR4 | P1 | Save of 500 messages completes under 200ms |

## E2E Test Plan (Sources/E2ETest/SessionStoreE2ETests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testSaveLoad_roundTrip` | AC2,AC3 | P0 | Save then load preserves messages and metadata |
| 2 | `testFilePermissions` | AC2,NFR10 | P0 | File permissions are 0600 on real filesystem |
| 3 | `testDirectoryAutoCreation` | AC2 | P0 | Directory is auto-created when saving to new path |

## Implementation Guidance

### Types to Create

1. **`Sources/OpenAgentSDK/Stores/SessionStore.swift`** -- `actor SessionStore`
   - `init(sessionsDir: String? = nil)`
   - `func save(sessionId: String, messages: [[String: Any]], metadata: PartialSessionMetadata) throws`
   - `func load(sessionId: String) -> SessionData?`
   - `func delete(sessionId: String) -> Bool`
   - `private func getSessionsDir() -> String`
   - `private func getSessionPath(_ sessionId: String) -> String`

2. **`PartialSessionMetadata`** type (can be in SessionTypes.swift or SessionStore.swift)
   - Subset of SessionMetadata fields needed for save input: cwd, model, summary (optional)

### Existing Types to Use (DO NOT MODIFY)

- `SessionMetadata` (Types/SessionTypes.swift) -- full metadata struct
- `SessionData` (Types/SessionTypes.swift) -- metadata + messages container
- `SDKError.sessionError(message:)` (Types/ErrorTypes.swift) -- typed errors

### Key Implementation Details

- Use `FileManager.default.createDirectory(withIntermediateDirectories:)` for mkdir -p
- Use `JSONSerialization.data(withJSONObject:options:.prettyPrinted)` for serialization
- Set file permissions via `[.posixPermissions: 0o600]` on `createFile`
- Set directory permissions via `[.posixPermissions: 0o700]` on `createDirectory`
- macOS: `NSHomeDirectory()`, Linux: `getenv("HOME")` fallback `/tmp`

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Run `swift build` to verify compilation
2. Run `swift test` to verify unit tests pass
3. Run `swift run E2ETest` to verify E2E tests pass
4. Verify SessionStore does NOT import Core/ (module boundary rule)
5. Run full test suite to verify no regressions
6. Commit passing tests

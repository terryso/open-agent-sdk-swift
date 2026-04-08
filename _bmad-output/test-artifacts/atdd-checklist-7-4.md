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
  - _bmad-output/implementation-artifacts/7-4-session-management-list-rename-tag-delete.md
  - Sources/OpenAgentSDK/Stores/SessionStore.swift
  - Sources/OpenAgentSDK/Types/SessionTypes.swift
  - Sources/OpenAgentSDK/Types/ErrorTypes.swift
  - Tests/OpenAgentSDKTests/Stores/SessionStoreTests.swift
  - Tests/OpenAgentSDKTests/Stores/SessionStoreForkTests.swift
  - Sources/E2ETest/SessionStoreE2ETests.swift
  - Sources/E2ETest/SessionForkE2ETests.swift
  - Sources/E2ETest/TestHarness.swift
  - Sources/E2ETest/main.swift
---

# ATDD Checklist: Story 7-4 -- Session Management (List, Rename, Tag, Delete)

## TDD Red Phase (Current)

**All tests will FAIL until the following are implemented:**
- `SessionMetadata` gains a `tag: String?` property
- `PartialSessionMetadata` gains a `tag: String?` property
- `SessionStore.list() throws -> [SessionMetadata]` method
- `SessionStore.rename(sessionId:newTitle:) throws` method
- `SessionStore.tag(sessionId:tag:) throws` method
- `SessionStore.save()` serializes the `tag` field
- `SessionStore.load()` deserializes the `tag` field (backward-compatible)

This is intentional -- TDD red phase.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | list() returns all session metadata sorted by updatedAt desc | P0 | Unit | `testList_emptyDir_returnsEmptyArray`, `testList_multipleSessions_returnsSortedByUpdatedAt` |
| AC1,AC8 | list() skips invalid/corrupt directories | P0 | Unit | `testList_skipsInvalidDirectories` |
| AC2 | rename() updates summary, updatedAt; silent on missing | P0 | Unit | `testRename_updatesSummary`, `testRename_nonexistent_silentSuccess` |
| AC3 | tag() adds/removes tag, updates updatedAt | P0 | Unit | `testTag_addsTagToMetadata`, `testTag_nilRemovesTag` |
| AC4 | delete() returns true for existing, false for missing | P0 | Unit | `testDelete_existing_returnsTrue`, `testDelete_nonexistent_returnsFalse` |
| AC5 | Performance: list/rename/tag/delete under 200ms for 500-message sessions | P1 | Unit | `testPerformance_listUnder200ms` |
| AC6 | Concurrent management operations safe | P0 | Unit | `testConcurrentManagementOperations_noDataCorruption` |
| AC7 | SessionMetadata tag field backward-compatible | P0 | Unit | `testTag_backwardCompatible_missingTagLoadsAsNil`, `testList_includesTagInMetadata` |
| AC9 | Unit test coverage (listed above) | P0 | Unit | All unit tests in this checklist |
| AC10 | E2E test coverage | P0 | E2E | `testListSessions_metadataComplete`, `testRenameThenList_updated`, `testTagThenLoad_persisted`, `testDeleteThenList_removed` |

## Test Summary

- **Total Tests:** 16 (12 unit + 4 E2E)
- **Unit Tests:** 12 (all in `Tests/OpenAgentSDKTests/Stores/SessionStoreManagementTests.swift`)
  - Single test class: `SessionStoreManagementTests`
- **E2E Tests:** 4 (all in `Sources/E2ETest/SessionManagementE2ETests.swift`)
  - Struct: `SessionManagementE2ETests` with static methods
- **Red Phase Status:**
  - 12 unit tests: FAILING (expected -- `list()`, `rename()`, `tag()` not implemented; `tag` field not added)
  - 4 E2E tests: FAILING (expected -- same reasons)

## Unit Test Plan (Tests/OpenAgentSDKTests/Stores/SessionStoreManagementTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testList_emptyDir_returnsEmptyArray` | AC1 | P0 | list() on empty directory returns empty array |
| 2 | `testList_multipleSessions_returnsSortedByUpdatedAt` | AC1 | P0 | list() returns sessions sorted by updatedAt descending |
| 3 | `testList_includesTagInMetadata` | AC7 | P0 | list() returns metadata with tag field populated |
| 4 | `testList_skipsInvalidDirectories` | AC8 | P0 | list() skips corrupt/missing transcript.json directories |
| 5 | `testRename_updatesSummary` | AC2 | P0 | rename() changes summary and updatedAt preserves messages |
| 6 | `testRename_nonexistent_silentSuccess` | AC2 | P0 | rename() on non-existent session returns without error |
| 7 | `testTag_addsTagToMetadata` | AC3 | P0 | tag() sets tag on session metadata |
| 8 | `testTag_nilRemovesTag` | AC3 | P0 | tag(sessionId:, tag: nil) removes existing tag |
| 9 | `testDelete_existing_returnsTrue` | AC4 | P0 | delete() removes existing session and returns true |
| 10 | `testDelete_nonexistent_returnsFalse` | AC4 | P0 | delete() on non-existent session returns false |
| 11 | `testConcurrentManagementOperations_noDataCorruption` | AC6 | P0 | Concurrent list/rename/tag/delete complete safely |
| 12 | `testPerformance_listUnder200ms` | AC5 | P1 | list() of 10 sessions with 500 messages each under 200ms |
| 13 | `testTag_backwardCompatible_missingTagLoadsAsNil` | AC7 | P0 | Old JSON without tag field loads with tag = nil |

## E2E Test Plan (Sources/E2ETest/SessionManagementE2ETests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testListSessions_metadataComplete` | AC1,AC10 | P0 | Create multiple sessions -> list() -> verify metadata complete and sorted |
| 2 | `testRenameThenList_updated` | AC2,AC10 | P0 | rename() -> list() -> verify summary updated in metadata |
| 3 | `testTagThenLoad_persisted` | AC3,AC10 | P0 | tag() -> load() -> verify tag persisted across read |
| 4 | `testDeleteThenList_removed` | AC4,AC10 | P0 | delete() -> list() -> verify session removed from list |

## Implementation Guidance

### Files to Modify

1. **`Sources/OpenAgentSDK/Types/SessionTypes.swift`**:
   - Add `tag: String?` to `SessionMetadata` (with default `nil` in init)
   - Add `tag: String?` to `PartialSessionMetadata` (with default `nil` in init)

2. **`Sources/OpenAgentSDK/Stores/SessionStore.swift`**:
   - Add `public func list() throws -> [SessionMetadata]`
   - Add `public func rename(sessionId: String, newTitle: String) throws`
   - Add `public func tag(sessionId: String, tag: String?) throws`
   - Update `save()` to serialize `tag` field when non-nil
   - Update `load()` to deserialize `tag` field (missing = nil, backward-compatible)
   - Verify existing `delete()` satisfies AC4 (already implemented)

### Files NOT to Modify

- `Core/Agent.swift` -- management operations don't involve Agent loop
- `Types/ErrorTypes.swift` -- SDKError.sessionError already sufficient

### Key Implementation Details

- `list()` scans sessions directory, calls `load()` per subdirectory, skips failures, sorts by updatedAt desc
- `rename()` loads -> updates summary -> saves (preserves createdAt via loadExistingCreatedAt)
- `tag()` loads -> sets tag -> saves (nil clears tag)
- `delete()` already implemented in Story 7-1 -- just verify it meets AC4
- Actor isolation guarantees thread safety for concurrent operations
- `PartialSessionMetadata` tag parameter must default to `nil` to avoid breaking existing callers

## Validation Results

- [x] Prerequisites satisfied (SessionStore from Story 7-1, restore from Story 7-2, fork from Story 7-3)
- [x] Test files created correctly (1 unit test file, 1 E2E test file)
- [x] Checklist matches all 10 acceptance criteria from story
- [x] Tests designed to fail before implementation (all 16 tests failing on red phase)
- [x] No orphaned browser sessions (backend project, no browser)
- [x] Temp artifacts stored in `_bmad-output/test-artifacts/`
- [x] E2E tests registered in main.swift (Section 37)
- [x] Unit tests follow existing naming convention: `test{MethodName}_{scenario}_{expectedBehavior}`
- [x] E2E tests use real filesystem (no mocks) per project convention
- [x] Unit tests use temp directory injection via `SessionStore(sessionsDir:)` for isolation

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Add `tag: String?` to `SessionMetadata` and `PartialSessionMetadata` in `SessionTypes.swift`
2. Add `list()`, `rename()`, `tag()` methods to `SessionStore.swift`
3. Update `save()` and `load()` for tag serialization/deserialization
4. Run `swift build` to verify compilation
5. Run `swift test --filter "SessionStoreManagement"` to verify unit tests pass
6. Run `swift run E2ETest` to verify E2E tests pass
7. Run full test suite to verify no regressions
8. Commit passing tests

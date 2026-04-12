---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-12'
story_id: '12-2'
story_name: 'Cache Tool and Compaction Integration'
tdd_phase: 'RED'
inputDocuments:
  - '_bmad-output/implementation-artifacts/12-2-cache-tool-and-compaction-integration.md'
  - 'Sources/OpenAgentSDK/Utils/FileCache.swift'
  - 'Sources/OpenAgentSDK/Utils/Compact.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/FileReadTool.swift'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Tests/OpenAgentSDKTests/Utils/FileCacheTests.swift'
  - 'Tests/OpenAgentSDKTests/Utils/CompactTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Core/FileReadToolTests.swift'
---

# ATDD Checklist: Story 12.2 -- Cache Tool and Compaction Integration

## TDD Red Phase (Current)

**Status: RED** -- All tests reference unimplemented APIs and will not compile until features are implemented.

### Test Files Created

| File | Tests | Priority Coverage | Status |
|------|-------|-------------------|--------|
| `Tests/OpenAgentSDKTests/Utils/FileCacheIntegrationTests.swift` | 17 | P0: 8, P1: 7, P2: 2 | RED (compilation errors) |
| `Tests/OpenAgentSDKTests/Utils/CompactCacheIntegrationTests.swift` | 7 | P0: 4, P1: 2, P2: 1 | RED (compilation errors) |

**Total: 24 failing tests** (all in TDD RED phase)

---

## Acceptance Criteria Coverage

### AC1: Partial Read Cache Hit

> Given FileReadTool supports partial reads (offset=100, limit=50), when the full file (1000 lines) is cached, returns lines 100-149 without disk access, and `cache.stats.diskReadCount` does not increase.

| Test | Priority | Covers |
|------|----------|--------|
| `testAC1_PartialReadCacheHit_ReturnsCorrectSlice_NoDiskReadCountIncrement` | P0 | Offset/limit from cached content, diskReadCount not incremented |
| `testAC1_FirstDiskRead_IncrementsDiskReadCount` | P1 | First read from disk increments diskReadCount |
| `testAC1_MultipleReadsSameFile_OnlyOneDiskReadCountIncrement` | P2 | Repeated reads only increment once |
| `testRecordDiskRead_IncrementsDiskReadCount` | P0 | recordDiskRead() method exists and works |
| `testRecordDiskRead_MultipleCalls_TrackedCorrectly` | P1 | Multiple calls tracked correctly |

**New API required:**
- `FileCache.recordDiskRead()` -- increments `_stats.diskReadCount` under lock

**Modification required:**
- `FileReadTool.swift` -- call `context.fileCache?.recordDiskRead()` in the disk-read path (before `context.fileCache?.set()`)

### AC2: Get Modified Files Since Last Compaction

> Given auto-compaction executes, when compression logic calls `cache.getModifiedFiles(since: lastCompactTime)`, returns list of file paths modified since last compaction, usable for generating compaction diff summaries.

| Test | Priority | Covers |
|------|----------|--------|
| `testAC2_GetModifiedFiles_ReturnsSetAndInvalidatedPaths` | P0 | set() and invalidate() both track modifications |
| `testAC2_GetDoesNotTrackInModifiedPaths` | P0 | get() does NOT add to modifiedPaths |
| `testAC2_GetModifiedFiles_FutureDate_ReturnsEmpty` | P1 | Future date returns empty |
| `testAC2_GetModifiedFiles_FiltersByTimestamp` | P1 | Time-based filtering works |
| `testAC2_UpdateExistingEntry_UpdatesModificationTime` | P1 | Re-set updates modification time |
| `testAC2_ConcurrentModifiedPathsAccess_DoesNotCrash` | P2 | Thread safety for modifiedPaths |
| `testAutoCompactState_HasLastCompactTime_DefaultsToDistantPast` | P0 | AutoCompactState.lastCompactTime field |
| `testAutoCompactState_PreservesLastCompactTime` | P1 | State preserves lastCompactTime |
| `testCompactConversation_WithFileCache_IncludesModifiedFiles` | P0 | compactConversation uses fileCache |
| `testCompactConversation_WithNilFileCache_WorksNormally` | P0 | Backwards compatible (nil fileCache) |
| `testCompactConversation_UpdatesLastCompactTime_OnSuccess` | P1 | Updates lastCompactTime on success |
| `testCompactConversation_DoesNotUpdateLastCompactTime_OnFailure` | P1 | No update on failure |
| `testCompactConversation_PromptFormat_IncludesModifiedFilesSection` | P2 | Prompt includes modified files |

**New APIs required:**
- `FileCache.modifiedPaths: [String: Date]` (private, lock-protected)
- `FileCache.getModifiedFiles(since: Date) -> [String]`
- `AutoCompactState.lastCompactTime: Date` field
- `compactConversation(fileCache: FileCache?)` parameter

**Modifications required:**
- `FileCache.set()` -- record modification time in `modifiedPaths`
- `FileCache.invalidate()` -- record modification time in `modifiedPaths`
- `FileCache.clear()` -- clear `modifiedPaths` dictionary
- `Compact.swift` -- `compactConversation()` accepts optional `fileCache` parameter
- `Compact.swift` -- `buildCompactionPrompt()` accepts modified files list
- `Compact.swift` -- `AutoCompactState` gains `lastCompactTime` field
- `createAutoCompactState()` -- initialize `lastCompactTime` to `Date.distantPast`

### AC3: Cache Clear at Session End

> Given Agent session ends, when `cache.clear()` is called, then `cache.stats.totalEntries == 0` and cache memory is freed.

| Test | Priority | Covers |
|------|----------|--------|
| `testAC3_Clear_SetsTotalEntriesToZero` | P0 | totalEntries == 0 after clear |
| `testAC3_Clear_SetsTotalSizeBytesToZero` | P0 | totalSizeBytes == 0 after clear |
| `testAC3_Clear_ClearsModifiedPaths` | P0 | modifiedPaths also cleared |
| `testAC3_Clear_NoEntriesRetrievable` | P1 | No entries retrievable after clear |

**Modifications required:**
- `FileCache.clear()` -- also clear `modifiedPaths` dictionary

---

## Compilation Errors (Expected -- TDD Red Phase)

These errors confirm the tests correctly reference unimplemented APIs:

1. `value of type 'FileCache' has no member 'getModifiedFiles'` (6 occurrences)
2. `value of type 'FileCache' has no member 'recordDiskRead'` (4 occurrences)
3. `value of type 'AutoCompactState' has no member 'lastCompactTime'` (3 occurrences)
4. `extra argument 'lastCompactTime' in call` (1 occurrence)
5. `extra argument 'fileCache' in call` (5 occurrences)
6. `'nil' requires a contextual type` (3 occurrences -- side effect of extra argument)

---

## Implementation Checklist

### Task 1: FileCache Modification Tracking

- [ ] Add `private var modifiedPaths: [String: Date]` to FileCache (protected by lock)
- [ ] Update `set()` to record `modifiedPaths[normalized] = Date()`
- [ ] Update `invalidate()` to record `modifiedPaths[normalized] = Date()`
- [ ] Implement `public func getModifiedFiles(since: Date) -> [String]`
- [ ] Update `clear()` to also clear `modifiedPaths`
- [ ] Implement `public func recordDiskRead()` to increment `_stats.diskReadCount`

### Task 2: Verify Partial Read Cache Hit

- [ ] Add `recordDiskRead()` call in `FileReadTool.swift` disk-read path
- [ ] Verify existing offset/limit logic works from cache

### Task 3: Compact Integration

- [ ] Add `lastCompactTime: Date` to `AutoCompactState`
- [ ] Update `createAutoCompactState()` to set `lastCompactTime = Date.distantPast`
- [ ] Add `fileCache: FileCache?` parameter to `compactConversation()`
- [ ] Before compaction: call `fileCache?.getModifiedFiles(since: state.lastCompactTime)`
- [ ] Inject modified files list into compaction prompt
- [ ] After success: update `lastCompactTime` to `Date()`

### Task 4: Session Cleanup

- [ ] Verify/ensure Agent clears fileCache at session end

---

## Next Steps (TDD Green Phase)

After implementing the features above:

1. Run `swift build --build-tests` to verify compilation
2. Run `swift test` to verify tests pass (green phase)
3. Run full test suite to verify no regressions
4. Commit passing tests

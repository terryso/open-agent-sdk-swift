---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-12'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/12-1-filecache-lru-cache-implementation.md'
  - 'Sources/OpenAgentSDK/Types/SDKConfiguration.swift'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/FileReadTool.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift'
  - 'Tests/OpenAgentSDKTests/Utils/RetryTests.swift'
  - 'Tests/OpenAgentSDKTests/Tools/Core/FileReadToolTests.swift'
---

# ATDD Checklist - Epic 12, Story 12.1: FileCache LRU Cache Implementation

**Date:** 2026-04-12
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit (XCTest)

---

## Story Summary

As a developer, I want the SDK to maintain an LRU cache of file contents so that repeated reads of the same file do not require disk I/O.

**Key scope:**
- `FileCache` final class with NSLock for thread safety (O(1) lookup via Dictionary + doubly-linked list LRU)
- `CacheEntry` struct (content: String, sizeBytes: Int, timestamp: Date)
- `CacheStats` struct (hitCount, missCount, evictionCount, oversizedSkipCount, diskReadCount, totalEntries, totalSizeBytes)
- LRU eviction from tail (least recently accessed), get/set move to head
- `SDKConfiguration` additions: fileCacheMaxEntries, fileCacheMaxSizeBytes, fileCacheMaxEntrySizeBytes
- `ToolContext` addition: fileCache: FileCache?
- `FileReadTool` integration: cache hit returns content without disk I/O
- `FileWriteTool`/`FileEditTool` integration: invalidate cache on write/edit
- Path normalization: `..` traversal, symlink resolution, broken symlink fallback, macOS case-insensitive

**Out of scope (future stories):**
- Story 12.2: Cache + compression integration
- Story 12.3: Git status injection
- Story 12.4: Project document discovery

---

## Acceptance Criteria

1. **AC1: FileCache basic structure with hit/miss stats** -- FileCache (final class, NSLock, default maxEntries=100, maxSizeBytes=25MB, maxEntrySizeBytes=5MB), first read -> missCount=1, oversized files skip cache (oversizedSkipCount), total size exceeds maxSizeBytes triggers LRU eviction
2. **AC2: SDKConfiguration cache params configurable** -- fileCacheMaxEntries, fileCacheMaxSizeBytes, fileCacheMaxEntrySizeBytes with defaults, overridable via init
3. **AC3: Cache hit no disk I/O** -- cached file returns content on second read, hitCount=1, no disk I/O
4. **AC4: LRU evicts least recently accessed** -- full cache (100 entries), 101st file evicts oldest-accessed entry, evictionCount increases
5. **AC5: Cache invalidation on write/edit** -- FileWriteTool/FileEditTool modification -> cache.get(path) returns nil
6. **AC6: Path normalization (.. traversal)** -- `/project/../project/src/main.swift` and `/project/src/main.swift` hit same cache entry
7. **AC7: Symlink resolution** -- symlink resolves to same cache entry as real path
8. **AC8: Broken symlink safe fallback** -- broken symlink does not crash, returns nil, falls back to disk read
9. **AC9: macOS case-insensitive path handling** -- case-insensitive paths resolve to same cache entry on macOS

---

## Failing Tests Created (RED Phase)

### Unit Tests -- FileCacheTests (28 tests)

**File:** `Tests/OpenAgentSDKTests/Utils/FileCacheTests.swift`

- **Test:** `testFileCache_FirstGet_MissCountIncreases`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC1 -- First get on empty cache -> missCount=1

- **Test:** `testFileCache_SetThenGet_HitCountIncreases`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC1, AC3 -- set then get -> hitCount=1

- **Test:** `testFileCache_SetThenGet_ReturnsCachedContent`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC1, AC3 -- get returns the content that was set

- **Test:** `testFileCache_OversizedFile_SkipsCache`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC1 -- Entry exceeding maxEntrySizeBytes is not cached, oversizedSkipCount increases

- **Test:** `testFileCache_TotalSizeExceedsMax_EvictsLRU`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC1 -- Total size exceeds maxSizeBytes triggers eviction

- **Test:** `testFileCache_EntryCountExceedsMax_EvictsLRU`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC1, AC4 -- Entry count exceeds maxEntries triggers eviction

- **Test:** `testFileCache_LRU_EvictsLeastRecentlyAccessed`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC4 -- Full cache: access entry 0, insert 101st, entry 1 is evicted (not entry 0)

- **Test:** `testFileCache_Invalidate_RemovesEntry`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC5 -- invalidate removes entry, subsequent get returns nil

- **Test:** `testFileCache_Invalidate_DecreasesTotalSize`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC5 -- invalidate decreases currentSizeBytes

- **Test:** `testFileCache_Invalidate_NonExistentPath_NoOp`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC5 -- invalidating non-existent path does not crash or change stats

- **Test:** `testFileCache_Clear_RemovesAllEntries`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** clear() removes all entries, resets totalSizeBytes

- **Test:** `testFileCache_Clear_ResetsTotalSize`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** clear() resets totalSizeBytes to 0

- **Test:** `testFileCache_CacheStats_AllFields`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC1 -- CacheStats has all expected fields

- **Test:** `testFileCache_DefaultConfiguration`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC1 -- Default maxEntries=100, maxSizeBytes=25MB, maxEntrySizeBytes=5MB

- **Test:** `testFileCache_CustomConfiguration`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC1, AC2 -- Custom init params are respected

- **Test:** `testFileCache_PathNormalization_DotDotTraversal`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC6 -- `/project/../project/src/main.swift` and `/project/src/main.swift` hit same entry

- **Test:** `testFileCache_PathNormalization_DotSegments`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC6 -- `./` and `.` segments are resolved

- **Test:** `testFileCache_PathNormalization_RedundantSlashes`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC6 -- Redundant slashes are normalized

- **Test:** `testFileCache_SymlinkResolution_SameEntry`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC7 -- symlink path and real path hit same cache entry

- **Test:** `testFileCache_BrokenSymlink_DoesNotCrash`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC8 -- broken symlink get does not crash, returns nil

- **Test:** `testFileCache_BrokenSymlink_FallbackToOriginalPath`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC8 -- broken symlink uses fallback path normalization

- **Test:** `testFileCache_CaseInsensitive_macOS`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC9 -- case-differing paths resolve to same entry on macOS

- **Test:** `testFileCache_SetUpdatesExistingEntry`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** set on existing key updates content and size

- **Test:** `testFileCache_GetMovesToHead_LRUOrder`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC4 -- get moves entry to head, affects LRU eviction order

- **Test:** `testFileCache_ConcurrentAccess_DoesNotCrash`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** NSLock thread safety -- concurrent get/set/invalidate no crash

- **Test:** `testFileCache_ConcurrentAccess_StatsAccurate`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** NSLock thread safety -- concurrent access preserves stat accuracy

- **Test:** `testFileCache_Set_SingleEntrySizeTracking`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** totalSizeBytes correctly tracks single entry size

- **Test:** `testFileCache_EvictionCount_Tracked`
  - **Status:** RED -- `FileCache` type does not exist yet
  - **Verifies:** AC4 -- evictionCount is incremented for each evicted entry

### Unit Tests -- SDKConfigurationCacheTests (4 tests)

**File:** `Tests/OpenAgentSDKTests/Utils/SDKConfigurationCacheTests.swift`

- **Test:** `testSDKConfiguration_DefaultCacheParams`
  - **Status:** RED -- `fileCacheMaxEntries` etc. do not exist yet
  - **Verifies:** AC2 -- Default values: 100, 25*1024*1024, 5*1024*1024

- **Test:** `testSDKConfiguration_CustomCacheParams`
  - **Status:** RED -- `fileCacheMaxEntries` etc. do not exist yet
  - **Verifies:** AC2 -- Custom values override defaults

- **Test:** `testSDKConfiguration_CacheParams_Equatable`
  - **Status:** RED -- `fileCacheMaxEntries` etc. do not exist yet
  - **Verifies:** AC2 -- Equatable auto-synthesis works with new fields

- **Test:** `testSDKConfiguration_CacheParams_InDescription`
  - **Status:** RED -- `fileCacheMaxEntries` etc. do not exist yet
  - **Verifies:** AC2 -- New fields appear in description/debugDescription

### Unit Tests -- ToolContextFileCacheTests (5 tests)

**File:** `Tests/OpenAgentSDKTests/Types/ToolContextFileCacheTests.swift`

- **Test:** `testToolContext_fileCache_DefaultNil`
  - **Status:** RED -- `ToolContext.fileCache` does not exist yet
  - **Verifies:** AC5 -- Default fileCache is nil, does not break existing code

- **Test:** `testToolContext_fileCache_Injected`
  - **Status:** RED -- `ToolContext.fileCache` does not exist yet
  - **Verifies:** AC5 -- fileCache can be injected via init

- **Test:** `testToolContext_withToolUseId_PreservesFileCache`
  - **Status:** RED -- `ToolContext.fileCache` does not exist yet
  - **Verifies:** AC5 -- withToolUseId() preserves fileCache reference

- **Test:** `testToolContext_withSkillContext_PreservesFileCache`
  - **Status:** RED -- `ToolContext.fileCache` does not exist yet
  - **Verifies:** AC5 -- withSkillContext() preserves fileCache reference

- **Test:** `testToolContext_Equatable_WithFileCache`
  - **Status:** RED -- `ToolContext.fileCache` does not exist yet
  - **Verifies:** ToolContext equality works with fileCache field

---

## Acceptance Criteria Coverage

| AC | Description | Tests | Priority |
|----|-------------|-------|----------|
| AC1 | FileCache basic structure + stats | FileCacheTests (10 tests) | P0 |
| AC2 | SDKConfiguration cache params | SDKConfigurationCacheTests (4 tests) | P0 |
| AC3 | Cache hit no disk I/O | FileCacheTests (2 tests) | P0 |
| AC4 | LRU evicts least recently accessed | FileCacheTests (5 tests) | P0 |
| AC5 | Cache invalidation on write/edit | FileCacheTests (3 tests) + ToolContextFileCacheTests (5 tests) | P0 |
| AC6 | Path normalization (.. traversal) | FileCacheTests (3 tests) | P0 |
| AC7 | Symlink resolution | FileCacheTests (1 test) | P0 |
| AC8 | Broken symlink safe fallback | FileCacheTests (2 tests) | P0 |
| AC9 | macOS case-insensitive | FileCacheTests (1 test) | P0 |
| -- | Thread safety (NSLock) | FileCacheTests (2 tests) | P1 |
| -- | clear() / size tracking | FileCacheTests (3 tests) | P1 |
| -- | Stats accuracy | FileCacheTests (1 test) | P1 |

**Total: 37 tests covering all 9 acceptance criteria.**

---

## Test Strategy

### Stack Detection
- **Detected:** Backend (Swift Package with XCTest, no frontend/browser testing)
- **Mode:** AI Generation (acceptance criteria are clear, standard algorithm/data-structure scenarios)

### Test Levels
- **Unit Tests (37):** Pure logic tests for FileCache LRU, CacheStats, SDKConfiguration, ToolContext

### Priority Distribution
- **P0 (Critical):** 29 tests -- core functionality that must work
- **P1 (Important):** 8 tests -- edge cases, concurrency safety, and stats accuracy

---

## TDD Red Phase Validation

- [x] All tests assert EXPECTED behavior (not placeholder assertions)
- [x] All tests will FAIL until feature is implemented (types/classes/properties do not exist)
- [x] No test uses `XCTSkip` -- tests are designed to fail at compile-time
- [x] Each test has clear Given/When/Then structure
- [x] Test helpers follow existing patterns (tempDir setUp/tearDown like FileReadToolTests)
- [x] Build verification: `swift build` succeeds (library clean), `swift build --build-tests` fails (RED phase confirmed)

---

## Implementation Guidance

### Files to Create
1. `Sources/OpenAgentSDK/Utils/FileCache.swift` -- FileCache final class, CacheEntry, CacheStats, LRU doubly-linked list
2. `Tests/OpenAgentSDKTests/Utils/FileCacheTests.swift` -- FileCache unit tests
3. `Tests/OpenAgentSDKTests/Utils/SDKConfigurationCacheTests.swift` -- SDKConfiguration cache params tests
4. `Tests/OpenAgentSDKTests/Types/ToolContextFileCacheTests.swift` -- ToolContext fileCache tests

### Files to Modify
1. `Sources/OpenAgentSDK/Types/SDKConfiguration.swift` -- Add fileCacheMaxEntries, fileCacheMaxSizeBytes, fileCacheMaxEntrySizeBytes
2. `Sources/OpenAgentSDK/Types/ToolTypes.swift` -- Add fileCache: FileCache? to ToolContext
3. `Sources/OpenAgentSDK/Tools/Core/FileReadTool.swift` -- Integrate cache reads
4. `Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift` -- Invalidate cache on write
5. `Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift` -- Invalidate cache on edit
6. `Sources/OpenAgentSDK/Core/Agent.swift` or `QueryEngine.swift` -- Create FileCache instance, inject into ToolContext

### Key Implementation Notes
- FileCache is a **final class** (not Actor) -- uses internal NSLock for thread safety
- LRU: Dictionary<String, ListNode> + doubly-linked list (head/tail pointers)
- CacheEntry is a **struct** (content: String, sizeBytes: Int, timestamp: Date)
- CacheStats is a **struct** with all counter fields
- Path normalization uses URL.resolvingSymlinksInPath() (NOT POSIX realpath)
- macOS case-insensitive uses FileManager.fileSystemRepresentation
- No force unwraps -- guard/let throughout
- FileCache? optional in ToolContext avoids breaking existing call sites
- oversizedSkipCount tracks skipped large files
- evictionCount tracks evicted entries
- maxEntrySizeBytes default = 5*1024*1024 (5MB)
- maxSizeBytes default = 25*1024*1024 (25MB)
- maxEntries default = 100

---

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Run `swift build` to verify compilation
2. Run `swift test` to verify all 37 new tests pass (plus existing suite)
3. If any tests fail:
   - Fix implementation (feature bug)
   - Or fix test (test bug)
4. Commit passing tests

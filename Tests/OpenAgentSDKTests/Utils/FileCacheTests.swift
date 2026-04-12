import XCTest
@testable import OpenAgentSDK

// MARK: - FileCache ATDD Tests (Story 12.1)

/// ATDD RED PHASE: Tests for Story 12.1 -- FileCache LRU Cache Implementation.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Sources/OpenAgentSDK/Utils/FileCache.swift` is created
///   - `FileCache` final class with NSLock, CacheEntry, CacheStats are implemented
///   - LRU doubly-linked list with O(1) get/set/invalidate/eviction is implemented
///   - Path normalization with symlink resolution and case-insensitive handling
/// TDD Phase: RED (feature not implemented yet)
final class FileCacheTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-FileCache-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a FileCache with default configuration.
    private func makeCache() -> FileCache {
        return FileCache()
    }

    /// Creates a FileCache with custom configuration.
    private func makeCache(
        maxEntries: Int,
        maxSizeBytes: Int,
        maxEntrySizeBytes: Int
    ) -> FileCache {
        return FileCache(
            maxEntries: maxEntries,
            maxSizeBytes: maxSizeBytes,
            maxEntrySizeBytes: maxEntrySizeBytes
        )
    }

    /// Writes a test file and returns its path.
    @discardableResult
    private func writeTestFile(name: String, content: String) -> String {
        let path = (tempDir as NSString).appendingPathComponent(name)
        try! content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    /// Creates a symlink at `linkPath` pointing to `targetPath`.
    private func createSymlink(linkPath: String, targetPath: String) {
        try! FileManager.default.createSymbolicLink(
            atPath: linkPath,
            withDestinationPath: targetPath
        )
    }

    // MARK: - AC1: FileCache Basic Structure with Hit/Miss Stats

    /// AC1 [P0]: First get on empty cache increments missCount.
    func testFileCache_FirstGet_MissCountIncreases() {
        // Given: an empty FileCache
        let cache = makeCache()

        // When: getting a path that has never been set
        let result = cache.get("/nonexistent/path.swift")

        // Then: result is nil, missCount is 1
        XCTAssertNil(result, "Empty cache get should return nil")
        XCTAssertEqual(cache.stats.missCount, 1,
                       "First get on empty cache should increment missCount to 1")
        XCTAssertEqual(cache.stats.hitCount, 0,
                       "hitCount should be 0 after a miss")
    }

    /// AC1 [P0]: set then get increments hitCount.
    func testFileCache_SetThenGet_HitCountIncreases() {
        // Given: a FileCache with one entry
        let cache = makeCache()
        cache.set("/project/src/main.swift", content: "Hello World")

        // When: getting the same path
        let result = cache.get("/project/src/main.swift")

        // Then: result is the cached content, hitCount is 1
        XCTAssertEqual(result, "Hello World",
                       "get should return the cached content")
        XCTAssertEqual(cache.stats.hitCount, 1,
                       "hitCount should be 1 after a cache hit")
    }

    /// AC1, AC3 [P0]: set stores content, get returns it exactly.
    func testFileCache_SetThenGet_ReturnsCachedContent() {
        // Given: a FileCache
        let cache = makeCache()
        let content = "line 1\nline 2\nline 3"

        // When: setting content and then getting it
        cache.set("/project/src/app.swift", content: content)
        let result = cache.get("/project/src/app.swift")

        // Then: the exact content is returned
        XCTAssertEqual(result, content,
                       "get should return the exact content that was set")
    }

    /// AC1 [P0]: Entry exceeding maxEntrySizeBytes is not cached.
    func testFileCache_OversizedFile_SkipsCache() {
        // Given: a FileCache with maxEntrySizeBytes = 10
        let cache = makeCache(
            maxEntries: 100,
            maxSizeBytes: 25 * 1024 * 1024,
            maxEntrySizeBytes: 10
        )
        let bigContent = String(repeating: "A", count: 100) // 100 bytes > 10 byte limit

        // When: setting an oversized entry
        cache.set("/project/large_file.swift", content: bigContent)

        // Then: entry is not cached, oversizedSkipCount increases
        XCTAssertNil(cache.get("/project/large_file.swift"),
                     "Oversized entry should not be cached")
        XCTAssertEqual(cache.stats.oversizedSkipCount, 1,
                       "oversizedSkipCount should be 1")
        XCTAssertEqual(cache.stats.totalEntries, 0,
                       "totalEntries should remain 0")
    }

    /// AC1 [P0]: Total size exceeding maxSizeBytes triggers LRU eviction.
    func testFileCache_TotalSizeExceedsMax_EvictsLRU() {
        // Given: a cache with maxSizeBytes = 20 bytes
        let cache = makeCache(
            maxEntries: 100,
            maxSizeBytes: 20,
            maxEntrySizeBytes: 15
        )

        // When: setting entries that exceed total size limit
        cache.set("/file1.txt", content: "1234567890") // 10 bytes
        cache.set("/file2.txt", content: "ABCDEFGHIJ") // 10 bytes -> total 20

        // Now set a third entry that will push total over limit
        cache.set("/file3.txt", content: "KL") // 2 bytes -> need to evict

        // Then: eviction occurs and oldest entry is removed
        XCTAssertGreaterThanOrEqual(cache.stats.evictionCount, 1,
                                    "evictionCount should be >= 1")
        XCTAssertLessThanOrEqual(cache.stats.totalSizeBytes, 20,
                                 "totalSizeBytes should be within maxSizeBytes")
    }

    /// AC1, AC4 [P0]: Entry count exceeding maxEntries triggers eviction.
    func testFileCache_EntryCountExceedsMax_EvictsLRU() {
        // Given: a cache with maxEntries = 3
        let cache = makeCache(
            maxEntries: 3,
            maxSizeBytes: 25 * 1024 * 1024,
            maxEntrySizeBytes: 5 * 1024 * 1024
        )

        // When: setting 4 entries (exceeds maxEntries of 3)
        cache.set("/file1.txt", content: "one")
        cache.set("/file2.txt", content: "two")
        cache.set("/file3.txt", content: "three")
        cache.set("/file4.txt", content: "four") // should trigger eviction

        // Then: eviction occurs
        XCTAssertGreaterThanOrEqual(cache.stats.evictionCount, 1,
                                    "evictionCount should be >= 1 after exceeding maxEntries")
        XCTAssertEqual(cache.stats.totalEntries, 3,
                       "totalEntries should not exceed maxEntries")
    }

    /// AC4 [P0]: Full cache evicts the least recently accessed entry (not most recent).
    func testFileCache_LRU_EvictsLeastRecentlyAccessed() {
        // Given: a cache with maxEntries = 3, filled with entries
        let cache = makeCache(
            maxEntries: 3,
            maxSizeBytes: 25 * 1024 * 1024,
            maxEntrySizeBytes: 5 * 1024 * 1024
        )

        cache.set("/file1.txt", content: "one")   // oldest (LRU tail)
        cache.set("/file2.txt", content: "two")
        cache.set("/file3.txt", content: "three")  // newest (LRU head)

        // Access file1 to move it to head (most recently used)
        _ = cache.get("/file1.txt")

        // When: inserting a 4th entry (triggers eviction)
        cache.set("/file4.txt", content: "four")

        // Then: file2 is evicted (was least recently accessed)
        // file1 was recently accessed, file3 was recently set, so file2 is LRU
        XCTAssertNil(cache.get("/file2.txt"),
                     "file2 should be evicted as least recently accessed")
        // file1 should still be cached (it was accessed)
        XCTAssertNotNil(cache.get("/file1.txt"),
                        "file1 should still be cached (recently accessed)")
        XCTAssertEqual(cache.stats.evictionCount, 1,
                       "evictionCount should be exactly 1")
    }

    // MARK: - AC5: Cache Invalidation on Write/Edit

    /// AC5 [P0]: invalidate removes the cache entry.
    func testFileCache_Invalidate_RemovesEntry() {
        // Given: a cache with an entry
        let cache = makeCache()
        cache.set("/project/src/main.swift", content: "Hello")

        // When: invalidating the path
        cache.invalidate("/project/src/main.swift")

        // Then: get returns nil
        XCTAssertNil(cache.get("/project/src/main.swift"),
                     "Invalidated entry should return nil on get")
    }

    /// AC5 [P0]: invalidate decreases the total size.
    func testFileCache_Invalidate_DecreasesTotalSize() {
        // Given: a cache with an entry
        let cache = makeCache()
        cache.set("/project/src/main.swift", content: "Hello") // 5 bytes

        // When: invalidating the path
        cache.invalidate("/project/src/main.swift")

        // Then: totalSizeBytes is 0
        XCTAssertEqual(cache.stats.totalSizeBytes, 0,
                       "totalSizeBytes should be 0 after invalidating all entries")
    }

    /// AC5 [P0]: invalidating a non-existent path is a no-op.
    func testFileCache_Invalidate_NonExistentPath_NoOp() {
        // Given: an empty cache
        let cache = makeCache()

        // When: invalidating a non-existent path
        cache.invalidate("/does/not/exist.swift")

        // Then: no crash, no stats change
        XCTAssertEqual(cache.stats.totalEntries, 0,
                       "totalEntries should remain 0")
        XCTAssertEqual(cache.stats.evictionCount, 0,
                       "evictionCount should remain 0")
    }

    // MARK: - clear()

    /// clear() removes all entries.
    func testFileCache_Clear_RemovesAllEntries() {
        // Given: a cache with multiple entries
        let cache = makeCache()
        cache.set("/file1.txt", content: "one")
        cache.set("/file2.txt", content: "two")
        cache.set("/file3.txt", content: "three")

        // When: clearing the cache
        cache.clear()

        // Then: all entries are removed
        XCTAssertEqual(cache.stats.totalEntries, 0,
                       "totalEntries should be 0 after clear")
        XCTAssertNil(cache.get("/file1.txt"),
                     "Entry should not exist after clear")
    }

    /// clear() resets totalSizeBytes to 0.
    func testFileCache_Clear_ResetsTotalSize() {
        // Given: a cache with entries
        let cache = makeCache()
        cache.set("/file1.txt", content: "content")

        // When: clearing
        cache.clear()

        // Then: totalSizeBytes is 0
        XCTAssertEqual(cache.stats.totalSizeBytes, 0,
                       "totalSizeBytes should be 0 after clear")
    }

    // MARK: - AC1: CacheStats

    /// AC1 [P0]: CacheStats has all expected fields with correct types.
    func testFileCache_CacheStats_AllFields() {
        // Given: a fresh cache
        let cache = makeCache()
        let stats = cache.stats

        // Then: all fields exist and have zero defaults
        XCTAssertEqual(stats.hitCount, 0, "hitCount should start at 0")
        XCTAssertEqual(stats.missCount, 0, "missCount should start at 0")
        XCTAssertEqual(stats.evictionCount, 0, "evictionCount should start at 0")
        XCTAssertEqual(stats.oversizedSkipCount, 0, "oversizedSkipCount should start at 0")
        XCTAssertEqual(stats.diskReadCount, 0, "diskReadCount should start at 0")
        XCTAssertEqual(stats.totalEntries, 0, "totalEntries should start at 0")
        XCTAssertEqual(stats.totalSizeBytes, 0, "totalSizeBytes should start at 0")
    }

    // MARK: - Configuration

    /// AC1 [P0]: Default configuration values.
    func testFileCache_DefaultConfiguration() {
        // Given: a cache with default config
        let cache = makeCache()

        // Then: defaults match story spec
        XCTAssertEqual(cache.maxEntries, 100,
                       "Default maxEntries should be 100")
        XCTAssertEqual(cache.maxSizeBytes, 25 * 1024 * 1024,
                       "Default maxSizeBytes should be 25MB")
        XCTAssertEqual(cache.maxEntrySizeBytes, 5 * 1024 * 1024,
                       "Default maxEntrySizeBytes should be 5MB")
    }

    /// AC1, AC2 [P0]: Custom configuration values are respected.
    func testFileCache_CustomConfiguration() {
        // Given: a cache with custom config
        let cache = makeCache(
            maxEntries: 50,
            maxSizeBytes: 10 * 1024 * 1024,
            maxEntrySizeBytes: 2 * 1024 * 1024
        )

        // Then: custom values are used
        XCTAssertEqual(cache.maxEntries, 50)
        XCTAssertEqual(cache.maxSizeBytes, 10 * 1024 * 1024)
        XCTAssertEqual(cache.maxEntrySizeBytes, 2 * 1024 * 1024)
    }

    // MARK: - AC6: Path Normalization (Dot-Dot Traversal)

    /// AC6 [P0]: `..` traversal resolves to same cache key.
    func testFileCache_PathNormalization_DotDotTraversal() {
        // Given: a cache with an entry
        let cache = makeCache()
        cache.set("/project/src/main.swift", content: "Hello")

        // When: accessing with `..` path
        let result = cache.get("/project/../project/src/main.swift")

        // Then: same cache entry is hit
        XCTAssertEqual(result, "Hello",
                       "Dot-dot path should resolve to same cache entry")
        XCTAssertEqual(cache.stats.hitCount, 1,
                       "Should be a cache hit")
    }

    /// AC6 [P0]: `./` and `.` segments are resolved.
    func testFileCache_PathNormalization_DotSegments() {
        // Given: a cache with an entry
        let cache = makeCache()
        cache.set("/project/src/main.swift", content: "Hello")

        // When: accessing with `./` prefix
        let result = cache.get("/project/./src/./main.swift")

        // Then: same cache entry is hit
        XCTAssertEqual(result, "Hello",
                       "Dot-segment path should resolve to same cache entry")
    }

    /// AC6 [P0]: Redundant slashes are normalized.
    func testFileCache_PathNormalization_RedundantSlashes() {
        // Given: a cache with an entry
        let cache = makeCache()
        cache.set("/project/src/main.swift", content: "Hello")

        // When: accessing with redundant slashes
        let result = cache.get("//project//src//main.swift")

        // Then: same cache entry is hit
        XCTAssertEqual(result, "Hello",
                       "Redundant slash path should resolve to same cache entry")
    }

    // MARK: - AC7: Symlink Resolution

    /// AC7 [P0]: Symlink path and real path hit same cache entry.
    func testFileCache_SymlinkResolution_SameEntry() {
        // Given: a real directory and a symlink pointing to it
        let realDir = (tempDir as NSString).appendingPathComponent("real")
        let linkDir = (tempDir as NSString).appendingPathComponent("link")
        try! FileManager.default.createDirectory(
            atPath: realDir, withIntermediateDirectories: true
        )
        createSymlink(linkPath: linkDir, targetPath: realDir)

        let cache = makeCache()
        let realPath = (realDir as NSString).appendingPathComponent("file.swift")
        let linkPath = (linkDir as NSString).appendingPathComponent("file.swift")

        // Write a file via the real path
        try! "content".write(toFile: realPath, atomically: true, encoding: .utf8)

        // When: set via real path, get via symlink path
        cache.set(realPath, content: "cached content")
        let result = cache.get(linkPath)

        // Then: same cache entry is hit
        XCTAssertEqual(result, "cached content",
                       "Symlink path should resolve to same cache entry as real path")
    }

    // MARK: - AC8: Broken Symlink Safe Fallback

    /// AC8 [P0]: Broken symlink does not crash.
    func testFileCache_BrokenSymlink_DoesNotCrash() {
        // Given: a broken symlink (target does not exist)
        let linkPath = (tempDir as NSString).appendingPathComponent("broken_link")
        let nonexistentTarget = (tempDir as NSString).appendingPathComponent("nonexistent_target")
        // Create symlink to nonexistent target
        createSymlink(linkPath: linkPath, targetPath: nonexistentTarget)

        let cache = makeCache()

        // When: getting a path through the broken symlink
        // This should NOT crash
        let filePath = (linkPath as NSString).appendingPathComponent("file.swift")
        let result = cache.get(filePath)

        // Then: returns nil without crashing
        XCTAssertNil(result,
                     "Broken symlink path should return nil without crashing")
    }

    /// AC8 [P0]: Broken symlink falls back to original path.
    func testFileCache_BrokenSymlink_FallbackToOriginalPath() {
        // Given: a broken symlink
        let linkPath = (tempDir as NSString).appendingPathComponent("broken_link2")
        let nonexistentTarget = (tempDir as NSString).appendingPathComponent("nonexistent_target2")
        createSymlink(linkPath: linkPath, targetPath: nonexistentTarget)

        let cache = makeCache()

        // When: getting a path through the broken symlink
        let filePath = (linkPath as NSString).appendingPathComponent("file.swift")
        _ = cache.get(filePath)

        // Then: missCount is incremented (it's a miss, not a crash)
        XCTAssertEqual(cache.stats.missCount, 1,
                       "Broken symlink should count as a miss")
    }

    // MARK: - AC9: macOS Case-Insensitive Path Handling

    /// AC9 [P0]: Case-differing paths resolve to same entry on macOS.
    func testFileCache_CaseInsensitive_macOS() {
        #if os(macOS)
        // Given: a real file on macOS (case-insensitive filesystem)
        let filePath = writeTestFile(name: "main.swift", content: "original")
        let cache = makeCache()

        // On macOS, the temp directory is case-insensitive by default
        // Construct an alternate-case path
        let altPath = filePath.lowercased() != filePath
            ? filePath.lowercased()
            : filePath.uppercased()

        // When: set with one case, get with another
        cache.set(filePath, content: "cached")
        let result = cache.get(altPath)

        // Then: same cache entry is hit (macOS resolves case-insensitively)
        XCTAssertEqual(result, "cached",
                       "Case-differing paths should resolve to same cache entry on macOS")
        #else
        // On non-macOS, this test is not applicable
        XCTAssertNotNil(true, "Skipped on non-macOS platform")
        #endif
    }

    // MARK: - Additional Edge Cases

    /// set on existing key updates content and size.
    func testFileCache_SetUpdatesExistingEntry() {
        // Given: a cache with one entry
        let cache = makeCache()
        cache.set("/file.txt", content: "old")

        // When: setting the same key with new content
        cache.set("/file.txt", content: "new content")

        // Then: content is updated, size is updated
        let result = cache.get("/file.txt")
        XCTAssertEqual(result, "new content",
                       "Content should be updated")
        XCTAssertEqual(cache.stats.totalEntries, 1,
                       "totalEntries should still be 1 (updated, not added)")
        XCTAssertEqual(cache.stats.totalSizeBytes, "new content".utf8.count,
                       "totalSizeBytes should reflect updated content size")
    }

    /// get moves entry to head, affecting LRU eviction order.
    func testFileCache_GetMovesToHead_LRUOrder() {
        // Given: a cache with maxEntries = 3
        let cache = makeCache(
            maxEntries: 3,
            maxSizeBytes: 25 * 1024 * 1024,
            maxEntrySizeBytes: 5 * 1024 * 1024
        )
        cache.set("/oldest.txt", content: "1")
        cache.set("/middle.txt", content: "2")
        cache.set("/newest.txt", content: "3")

        // When: getting the oldest entry (moves to head)
        _ = cache.get("/oldest.txt")

        // Then: inserting a new entry evicts /middle.txt (now LRU tail)
        cache.set("/new.txt", content: "4")

        XCTAssertNil(cache.get("/middle.txt"),
                     "middle should be evicted (it became LRU tail after oldest was accessed)")
        XCTAssertNotNil(cache.get("/oldest.txt"),
                        "oldest should remain (it was recently accessed)")
    }

    /// Single entry size tracking.
    func testFileCache_Set_SingleEntrySizeTracking() {
        // Given: an empty cache
        let cache = makeCache()

        // When: setting an entry
        let content = "Hello, World!"
        cache.set("/file.txt", content: content)

        // Then: totalSizeBytes equals the content's byte size
        XCTAssertEqual(cache.stats.totalSizeBytes, content.utf8.count,
                       "totalSizeBytes should equal the content byte size")
    }

    /// Eviction count tracks each evicted entry.
    func testFileCache_EvictionCount_Tracked() {
        // Given: a cache with maxEntries = 2
        let cache = makeCache(
            maxEntries: 2,
            maxSizeBytes: 25 * 1024 * 1024,
            maxEntrySizeBytes: 5 * 1024 * 1024
        )
        cache.set("/file1.txt", content: "1")
        cache.set("/file2.txt", content: "2")

        // When: inserting 3 more entries (each triggers one eviction)
        cache.set("/file3.txt", content: "3") // evicts file1
        cache.set("/file4.txt", content: "4") // evicts file2
        cache.set("/file5.txt", content: "5") // evicts file3

        // Then: evictionCount = 3
        XCTAssertEqual(cache.stats.evictionCount, 3,
                       "evictionCount should track each evicted entry")
    }

    // MARK: - Thread Safety (NSLock)

    /// NSLock thread safety: concurrent get/set/invalidate does not crash.
    func testFileCache_ConcurrentAccess_DoesNotCrash() {
        // Given: a cache
        let cache = makeCache()
        let iterations = 100
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) let unsafeCache = cache

        // When: concurrently accessing from multiple queues
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        for i in 0..<iterations {
            queue.async {
                unsafeCache.set("/file_\(i).txt", content: "content_\(i)")
                _ = unsafeCache.get("/file_\(i).txt")
                unsafeCache.invalidate("/file_\(i).txt")
                semaphore.signal()
            }
        }

        // Then: no crash, no hang (wait for all operations)
        for _ in 0..<iterations {
            XCTAssertEqual(
                semaphore.wait(timeout: .now() + 10),
                .success,
                "All concurrent operations should complete within timeout"
            )
        }
    }

    /// NSLock thread safety: concurrent access preserves stat accuracy.
    func testFileCache_ConcurrentAccess_StatsAccurate() {
        // Given: a cache
        let cache = makeCache()
        let iterations = 50
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) let unsafeCache = cache

        // Pre-populate entries
        for i in 0..<iterations {
            cache.set("/stat_file_\(i).txt", content: "content_\(i)")
        }

        // When: concurrent gets (all should hit)
        let queue = DispatchQueue(label: "test.stats", attributes: .concurrent)
        for i in 0..<iterations {
            queue.async {
                _ = unsafeCache.get("/stat_file_\(i).txt")
                semaphore.signal()
            }
        }

        // Then: hitCount should equal iterations
        for _ in 0..<iterations {
            XCTAssertEqual(
                semaphore.wait(timeout: .now() + 10),
                .success,
                "All concurrent gets should complete within timeout"
            )
        }
        XCTAssertEqual(cache.stats.hitCount, iterations,
                       "hitCount should equal number of concurrent gets")
    }
}

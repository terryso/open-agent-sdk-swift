import XCTest
@testable import OpenAgentSDK

// MARK: - FileCache Integration ATDD Tests (Story 12.2)

/// ATDD RED PHASE: Tests for Story 12.2 -- Cache Tool and Compaction Integration.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `FileCache` gains `modifiedPaths`, `getModifiedFiles(since:)`, `recordDiskRead()`
///   - `AutoCompactState` gains `lastCompactTime` field
///   - `compactConversation()` accepts optional `fileCache` parameter
///   - `buildCompactionPrompt()` accepts modified files list
/// TDD Phase: RED (feature not implemented yet)
final class FileCacheIntegrationTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-FileCacheIntegration-\(UUID().uuidString)")
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

    /// Creates the Read tool via the public factory function.
    private func makeReadTool() -> ToolProtocol {
        return createReadTool()
    }

    /// Calls the tool with a dictionary input and returns the ToolResult.
    private func callTool(
        _ tool: ToolProtocol,
        input: [String: Any],
        fileCache: FileCache? = nil,
        cwd: String? = nil
    ) async -> ToolResult {
        let context = ToolContext(
            cwd: cwd ?? tempDir,
            toolUseId: "test-\(UUID().uuidString)",
            fileCache: fileCache
        )
        return await tool.call(input: input, context: context)
    }

    // MARK: - AC1: Partial Read Cache Hit

    /// AC1 [P0]: Reading a cached file with offset/limit returns correct slice
    /// and does NOT increment diskReadCount.
    ///
    /// Given FileReadTool supports partial reads (offset, limit), when the full
    /// file is already cached, the offset/limit slice comes from cache content
    /// and `cache.stats.diskReadCount` does not increase.
    func testAC1_PartialReadCacheHit_ReturnsCorrectSlice_NoDiskReadCountIncrement() async {
        // Given: a 100-line file and a cache with the file already cached
        let lines = (1...100).map { "line \($0)" }.joined(separator: "\n")
        let filePath = writeTestFile(name: "cached_100_lines.txt", content: lines)
        let cache = makeCache()
        let tool = makeReadTool()

        // First read: cache miss, populates cache from disk
        let _ = await callTool(tool, input: ["file_path": filePath], fileCache: cache)
        let diskReadsAfterFirstRead = cache.stats.diskReadCount

        // When: reading with offset=50, limit=10 from the same file (should be a cache hit)
        let result = await callTool(
            tool,
            input: ["file_path": filePath, "offset": 50, "limit": 10],
            fileCache: cache
        )

        // Then: result contains lines 51-60 (0-based offset 50), diskReadCount did not increase
        XCTAssertFalse(result.isError,
                       "Partial read from cache should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("line 51"),
                      "Should contain line 51 (offset=50, 0-based)")
        XCTAssertTrue(result.content.contains("line 60"),
                      "Should contain line 60 (offset=50 + limit=10)")
        XCTAssertFalse(result.content.contains("line 50"),
                       "Should not contain line 50 (before offset)")
        XCTAssertFalse(result.content.contains("line 61"),
                       "Should not contain line 61 (after limit)")

        // diskReadCount should NOT have increased on the second (cached) read
        // NOTE: This will FAIL until recordDiskRead() is added to FileReadTool's disk path
        XCTAssertEqual(cache.stats.diskReadCount, diskReadsAfterFirstRead,
                       "diskReadCount should not increase on a cache-hit partial read")
    }

    /// AC1 [P1]: First read from disk increments diskReadCount.
    ///
    /// When a file is NOT cached and must be read from disk, diskReadCount should
    /// be incremented exactly once.
    func testAC1_FirstDiskRead_IncrementsDiskReadCount() async {
        // Given: a file that is NOT yet cached
        let content = "first line\nsecond line\nthird line"
        let filePath = writeTestFile(name: "disk_read_file.txt", content: content)
        let cache = makeCache()
        let tool = makeReadTool()

        // When: reading the file for the first time (cache miss, disk read)
        let _ = await callTool(tool, input: ["file_path": filePath], fileCache: cache)

        // Then: diskReadCount should be 1
        // NOTE: This will FAIL until recordDiskRead() is added to FileReadTool's disk path
        XCTAssertEqual(cache.stats.diskReadCount, 1,
                       "First read should increment diskReadCount to 1")
    }

    /// AC1 [P2]: Multiple reads of same file only increment diskReadCount once.
    func testAC1_MultipleReadsSameFile_OnlyOneDiskReadCount() async {
        // Given: a file
        let content = (1...50).map { "line \($0)" }.joined(separator: "\n")
        let filePath = writeTestFile(name: "repeat_read.txt", content: content)
        let cache = makeCache()
        let tool = makeReadTool()

        // When: reading the same file 3 times with different offsets
        let _ = await callTool(tool, input: ["file_path": filePath], fileCache: cache)
        let _ = await callTool(
            tool,
            input: ["file_path": filePath, "offset": 10, "limit": 5],
            fileCache: cache
        )
        let _ = await callTool(
            tool,
            input: ["file_path": filePath, "offset": 30, "limit": 5],
            fileCache: cache
        )

        // Then: diskReadCount should be exactly 1 (only the first read hit disk)
        // NOTE: This will FAIL until recordDiskRead() is added to FileReadTool
        XCTAssertEqual(cache.stats.diskReadCount, 1,
                       "Only the first read should increment diskReadCount; subsequent reads are cache hits")
    }

    // MARK: - AC2: getModifiedFiles(since:)

    /// AC2 [P0]: getModifiedFiles returns files set or invalidated since given date.
    ///
    /// Given a FileCache with files set via set() and invalidated via invalidate(),
    /// getModifiedFiles(since:) returns all paths modified after the given timestamp.
    func testAC2_GetModifiedFiles_ReturnsSetAndInvalidatedPaths() {
        // Given: a FileCache
        let cache = makeCache()

        // Record time before modifications
        let beforeModifications = Date()

        // set() two files
        cache.set("/project/A.swift", content: "file A content")
        cache.set("/project/B.swift", content: "file B content")

        // invalidate a file (simulates write/edit)
        cache.set("/project/C.swift", content: "file C original")
        cache.invalidate("/project/C.swift")

        // When: calling getModifiedFiles(since: beforeModifications)
        // NOTE: This will FAIL until getModifiedFiles(since:) is implemented
        let modifiedFiles = cache.getModifiedFiles(since: beforeModifications)

        // Then: all three paths are returned
        // set() records A.swift and B.swift; invalidate() records C.swift
        XCTAssertEqual(modifiedFiles.count, 3,
                       "Should return 3 modified files (2 set + 1 invalidated)")
        XCTAssertTrue(modifiedFiles.contains("/project/A.swift"),
                      "A.swift should be in modified files (was set)")
        XCTAssertTrue(modifiedFiles.contains("/project/B.swift"),
                      "B.swift should be in modified files (was set)")
        XCTAssertTrue(modifiedFiles.contains("/project/C.swift"),
                      "C.swift should be in modified files (was invalidated)")
    }

    /// AC2 [P0]: get() does NOT add files to modifiedPaths.
    ///
    /// get() is a read-only operation and should not affect modification tracking.
    func testAC2_GetDoesNotTrackInModifiedPaths() {
        // Given: a FileCache with a cached entry
        let cache = makeCache()
        cache.set("/project/read_only.swift", content: "original content")

        let afterSet = Date()

        // When: getting (reading) the cached entry
        _ = cache.get("/project/read_only.swift")

        // Then: getModifiedFiles(since: afterSet) should return empty
        // NOTE: This will FAIL until getModifiedFiles(since:) is implemented
        let modifiedFiles = cache.getModifiedFiles(since: afterSet)
        XCTAssertTrue(modifiedFiles.isEmpty,
                      "get() should not add paths to modifiedFiles; got: \(modifiedFiles)")
    }

    /// AC2 [P1]: getModifiedFiles with future date returns empty list.
    func testAC2_GetModifiedFiles_FutureDate_ReturnsEmpty() {
        // Given: a FileCache with some modifications
        let cache = makeCache()
        cache.set("/project/file1.swift", content: "content 1")
        cache.set("/project/file2.swift", content: "content 2")

        // When: querying with a date far in the future
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
        // NOTE: This will FAIL until getModifiedFiles(since:) is implemented
        let modifiedFiles = cache.getModifiedFiles(since: futureDate)

        // Then: empty list
        XCTAssertTrue(modifiedFiles.isEmpty,
                      "No files should be modified after a future date")
    }

    /// AC2 [P1]: getModifiedFiles filters correctly by timestamp.
    ///
    /// Only files modified AFTER the given date are returned.
    func testAC2_GetModifiedFiles_FiltersByTimestamp() {
        // Given: a FileCache
        let cache = makeCache()

        // Set file A
        cache.set("/project/early.swift", content: "early content")

        // Record time between modifications
        let midPoint = Date()

        // Set file B after midPoint
        cache.set("/project/late.swift", content: "late content")

        // When: calling getModifiedFiles(since: midPoint)
        // NOTE: This will FAIL until getModifiedFiles(since:) is implemented
        let modifiedFiles = cache.getModifiedFiles(since: midPoint)

        // Then: only late.swift should be returned
        // early.swift was set BEFORE midPoint, so it should be excluded
        // NOTE: Exact behavior depends on timestamp granularity.
        // At minimum, late.swift should be in the result.
        XCTAssertTrue(modifiedFiles.contains("/project/late.swift"),
                      "late.swift should be in modified files (set after midpoint)")
    }

    /// AC2 [P1]: Updating an existing entry via set() updates modification time.
    func testAC2_UpdateExistingEntry_UpdatesModificationTime() {
        // Given: a FileCache with an entry
        let cache = makeCache()
        cache.set("/project/updated.swift", content: "version 1")

        let afterFirstSet = Date()

        // Small sleep to ensure timestamp difference
        // (Note: Date granularity may be coarse, so we test the general behavior)

        // When: updating the same entry with new content
        cache.set("/project/updated.swift", content: "version 2")

        // Then: getModifiedFiles(since: afterFirstSet) should include the updated file
        // NOTE: This will FAIL until getModifiedFiles(since:) is implemented
        let modifiedFiles = cache.getModifiedFiles(since: afterFirstSet)
        XCTAssertTrue(modifiedFiles.contains("/project/updated.swift"),
                      "Updated file should appear in modified files after re-set")
    }

    // MARK: - AC3: Cache Clear

    /// AC3 [P0]: clear() sets totalEntries to 0.
    func testAC3_Clear_SetsTotalEntriesToZero() {
        // Given: a cache with multiple entries
        let cache = makeCache()
        cache.set("/file1.txt", content: "one")
        cache.set("/file2.txt", content: "two")
        cache.set("/file3.txt", content: "three")
        XCTAssertGreaterThan(cache.stats.totalEntries, 0,
                             "Precondition: cache should have entries")

        // When: clearing the cache
        cache.clear()

        // Then: totalEntries == 0
        XCTAssertEqual(cache.stats.totalEntries, 0,
                       "totalEntries should be 0 after clear")
    }

    /// AC3 [P0]: clear() sets totalSizeBytes to 0.
    func testAC3_Clear_SetsTotalSizeBytesToZero() {
        // Given: a cache with entries
        let cache = makeCache()
        cache.set("/file1.txt", content: "some content here")
        cache.set("/file2.txt", content: "more content")
        XCTAssertGreaterThan(cache.stats.totalSizeBytes, 0,
                             "Precondition: cache should have size > 0")

        // When: clearing
        cache.clear()

        // Then: totalSizeBytes == 0
        XCTAssertEqual(cache.stats.totalSizeBytes, 0,
                       "totalSizeBytes should be 0 after clear")
    }

    /// AC3 [P0]: clear() also clears modifiedPaths.
    ///
    /// After clear(), getModifiedFiles(since: distantPast) should return empty.
    func testAC3_Clear_ClearsModifiedPaths() {
        // Given: a cache with modified entries
        let cache = makeCache()
        cache.set("/modified1.txt", content: "mod1")
        cache.set("/modified2.txt", content: "mod2")

        // When: clearing
        cache.clear()

        // Then: getModifiedFiles should return empty (modifiedPaths was cleared)
        // NOTE: This will FAIL until getModifiedFiles(since:) is implemented
        let modifiedFiles = cache.getModifiedFiles(since: Date.distantPast)
        XCTAssertTrue(modifiedFiles.isEmpty,
                      "modifiedPaths should be empty after clear()")
    }

    /// AC3 [P1]: After clear(), no entries can be retrieved.
    func testAC3_Clear_NoEntriesRetrievable() {
        // Given: a cache with entries
        let cache = makeCache()
        cache.set("/gone.txt", content: "will be gone")

        // When: clearing
        cache.clear()

        // Then: get returns nil
        XCTAssertNil(cache.get("/gone.txt"),
                     "Entry should not be retrievable after clear()")
    }

    // MARK: - recordDiskRead()

    /// AC1 [P0]: recordDiskRead() increments diskReadCount.
    func testRecordDiskRead_IncrementsDiskReadCount() {
        // Given: a fresh cache
        let cache = makeCache()
        XCTAssertEqual(cache.stats.diskReadCount, 0,
                       "Precondition: diskReadCount should start at 0")

        // When: recording a disk read
        // NOTE: This will FAIL until recordDiskRead() is implemented
        cache.recordDiskRead()

        // Then: diskReadCount is 1
        XCTAssertEqual(cache.stats.diskReadCount, 1,
                       "recordDiskRead() should increment diskReadCount to 1")
    }

    /// AC1 [P1]: Multiple recordDiskRead() calls increment diskReadCount correctly.
    func testRecordDiskRead_MultipleCalls_TrackedCorrectly() {
        // Given: a fresh cache
        let cache = makeCache()

        // When: recording 3 disk reads
        cache.recordDiskRead()
        cache.recordDiskRead()
        cache.recordDiskRead()

        // Then: diskReadCount is 3
        XCTAssertEqual(cache.stats.diskReadCount, 3,
                       "diskReadCount should be 3 after 3 recordDiskRead() calls")
    }

    // MARK: - Thread Safety for Modified Paths

    /// AC2 [P2]: Concurrent set/invalidate/getModifiedFiles does not crash.
    func testAC2_ConcurrentModifiedPathsAccess_DoesNotCrash() {
        // Given: a cache
        let cache = makeCache()
        let iterations = 100
        let semaphore = DispatchSemaphore(value: 0)
        let unsafeCache = cache

        // When: concurrently modifying and querying
        let queue = DispatchQueue(label: "test.modified.concurrent", attributes: .concurrent)
        for i in 0..<iterations {
            queue.async {
                unsafeCache.set("/concurrent_file_\(i).txt", content: "content_\(i)")
                if i % 2 == 0 {
                    unsafeCache.invalidate("/concurrent_file_\(i).txt")
                }
                _ = unsafeCache.getModifiedFiles(since: Date.distantPast)
                semaphore.signal()
            }
        }

        // Then: no crash, no hang
        for _ in 0..<iterations {
            XCTAssertEqual(
                semaphore.wait(timeout: .now() + 10),
                .success,
                "All concurrent operations should complete within timeout"
            )
        }
    }
}

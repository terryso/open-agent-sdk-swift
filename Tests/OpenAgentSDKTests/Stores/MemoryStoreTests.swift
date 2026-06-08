import XCTest
@testable import OpenAgentSDK

// MARK: - MemoryStore Tests

/// ATDD RED PHASE: Tests for Story 19.1 -- Cross-run Memory Store.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `KnowledgeEntry` struct is defined with id, content, tags, createdAt, sourceRunId fields
///   - `KnowledgeQueryFilter` struct is defined with tags, olderThan, newerThan, limit fields
///   - `MemoryStoreProtocol` is defined with save, query, delete, listDomains methods
///   - `InMemoryStore` actor is defined implementing MemoryStoreProtocol
///   - `FileBasedMemoryStore` actor is defined implementing MemoryStoreProtocol
///   - `AgentOptions.memoryStore` property is added
///   - `ToolContext.memoryStore` field is added
/// TDD Phase: RED (feature not implemented yet)
final class MemoryStoreTests: TempDirTestCase {

    // MARK: - Helper: Create KnowledgeEntry

    private func makeEntry(
        content: String = "test knowledge",
        tags: [String] = [],
        sourceRunId: String? = nil,
        createdAt: Date = Date()
    ) -> KnowledgeEntry {
        KnowledgeEntry(
            id: UUID().uuidString,
            content: content,
            tags: tags,
            createdAt: createdAt,
            sourceRunId: sourceRunId
        )
    }

    // MARK: - AC1: KnowledgeEntry Types

    /// AC1 [P0]: KnowledgeEntry can be constructed with all fields.
    func testKnowledgeEntry_construction() {
        let entry = KnowledgeEntry(
            id: "test-id",
            content: "test content",
            tags: ["tag1", "tag2"],
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceRunId: "run-123"
        )
        XCTAssertEqual(entry.id, "test-id")
        XCTAssertEqual(entry.content, "test content")
        XCTAssertEqual(entry.tags, ["tag1", "tag2"])
        XCTAssertEqual(entry.createdAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(entry.sourceRunId, "run-123")
    }

    /// AC1 [P0]: KnowledgeEntry is Equatable.
    func testKnowledgeEntry_equality() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let entry1 = KnowledgeEntry(id: "a", content: "x", tags: [], createdAt: date, sourceRunId: nil)
        let entry2 = KnowledgeEntry(id: "a", content: "x", tags: [], createdAt: date, sourceRunId: nil)
        XCTAssertEqual(entry1, entry2)
    }

    /// AC1 [P0]: KnowledgeEntry is Sendable (compilation proves it).
    func testKnowledgeEntry_sendable() {
        let entry = KnowledgeEntry(id: "a", content: "x", tags: [], createdAt: Date(), sourceRunId: nil)
        // If this compiles, KnowledgeEntry is Sendable
        let _: any Sendable = entry
    }

    /// AC1 [P0]: KnowledgeEntry sourceRunId can be nil.
    func testKnowledgeEntry_nilSourceRunId() {
        let entry = KnowledgeEntry(id: "a", content: "x", tags: [], createdAt: Date(), sourceRunId: nil)
        XCTAssertNil(entry.sourceRunId)
    }

    // MARK: - AC1: KnowledgeQueryFilter Types

    /// AC1 [P0]: KnowledgeQueryFilter can be constructed with all-nil fields (match all).
    func testKnowledgeQueryFilter_defaultConstruction() {
        let filter = KnowledgeQueryFilter(tags: nil, olderThan: nil, newerThan: nil, limit: nil)
        XCTAssertNil(filter.tags)
        XCTAssertNil(filter.olderThan)
        XCTAssertNil(filter.newerThan)
        XCTAssertNil(filter.limit)
    }

    /// AC1 [P0]: KnowledgeQueryFilter is Equatable.
    func testKnowledgeQueryFilter_equality() {
        let filter1 = KnowledgeQueryFilter(tags: ["a"], olderThan: nil, newerThan: nil, limit: 10)
        let filter2 = KnowledgeQueryFilter(tags: ["a"], olderThan: nil, newerThan: nil, limit: 10)
        XCTAssertEqual(filter1, filter2)
    }

    /// AC1 [P0]: KnowledgeQueryFilter is Sendable (compilation proves it).
    func testKnowledgeQueryFilter_sendable() {
        let filter = KnowledgeQueryFilter(tags: nil, olderThan: nil, newerThan: nil, limit: nil)
        let _: any Sendable = filter
    }

    // MARK: - AC1: MemoryStoreProtocol

    /// AC1 [P0]: MemoryStoreProtocol is Sendable (can be used in concurrency context).
    func testMemoryStoreProtocol_isSendable() {
        // Compilation test: if InMemoryStore conforms to MemoryStoreProtocol
        // and MemoryStoreProtocol: Sendable, this compiles
        let store: any MemoryStoreProtocol = InMemoryStore()
        let _: any Sendable = store
    }

    // MARK: - AC2: InMemoryStore -- Save

    /// AC2 [P0]: InMemoryStore can be instantiated with default init.
    func testInMemoryStore_init() async {
        let store = InMemoryStore()
        _ = store
    }

    /// AC2 [P0]: save() stores an entry that can be queried back.
    func testInMemoryStore_save_andQuery() async throws {
        // Given: a fresh InMemoryStore
        let store = InMemoryStore()
        let entry = makeEntry(content: "hello world", tags: ["greeting"])

        // When: saving to domain "test"
        try await store.save(domain: "test", knowledge: entry)

        // Then: querying returns the entry
        let results = try await store.query(domain: "test", filter: nil)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "hello world")
        XCTAssertEqual(results.first?.tags, ["greeting"])
    }

    /// AC2 [P0]: save() appends multiple entries to same domain.
    func testInMemoryStore_save_appendsMultiple() async throws {
        // Given: a fresh InMemoryStore
        let store = InMemoryStore()
        let entry1 = makeEntry(content: "first")
        let entry2 = makeEntry(content: "second")

        // When: saving two entries to same domain
        try await store.save(domain: "test", knowledge: entry1)
        try await store.save(domain: "test", knowledge: entry2)

        // Then: both entries are returned
        let results = try await store.query(domain: "test", filter: nil)
        XCTAssertEqual(results.count, 2)
    }

    /// AC2 [P0]: save() stores entries in separate domains independently.
    func testInMemoryStore_save_separateDomains() async throws {
        // Given: a fresh InMemoryStore
        let store = InMemoryStore()
        let entry1 = makeEntry(content: "domain-a")
        let entry2 = makeEntry(content: "domain-b")

        // When: saving to different domains
        try await store.save(domain: "alpha", knowledge: entry1)
        try await store.save(domain: "beta", knowledge: entry2)

        // Then: each domain has its own entries
        let alphaResults = try await store.query(domain: "alpha", filter: nil)
        let betaResults = try await store.query(domain: "beta", filter: nil)
        XCTAssertEqual(alphaResults.count, 1)
        XCTAssertEqual(betaResults.count, 1)
        XCTAssertEqual(alphaResults.first?.content, "domain-a")
        XCTAssertEqual(betaResults.first?.content, "domain-b")
    }

    // MARK: - AC2: InMemoryStore -- Query

    /// AC2 [P0]: query() with nil filter returns all entries in domain.
    func testInMemoryStore_query_nilFilter_returnsAll() async throws {
        // Given: a store with 3 entries
        let store = InMemoryStore()
        try await store.save(domain: "test", knowledge: makeEntry(content: "a"))
        try await store.save(domain: "test", knowledge: makeEntry(content: "b"))
        try await store.save(domain: "test", knowledge: makeEntry(content: "c"))

        // When: querying with nil filter
        let results = try await store.query(domain: "test", filter: nil)

        // Then: all 3 entries returned
        XCTAssertEqual(results.count, 3)
    }

    /// AC2 [P0]: query() with tag filter returns only matching entries.
    func testInMemoryStore_query_tagFilter() async throws {
        // Given: a store with tagged entries
        let store = InMemoryStore()
        try await store.save(domain: "test", knowledge: makeEntry(content: "swift", tags: ["lang"]))
        try await store.save(domain: "test", knowledge: makeEntry(content: "python", tags: ["lang"]))
        try await store.save(domain: "test", knowledge: makeEntry(content: "docker", tags: ["ops"]))

        // When: filtering by tag "lang"
        let filter = KnowledgeQueryFilter(tags: ["lang"], olderThan: nil, newerThan: nil, limit: nil)
        let results = try await store.query(domain: "test", filter: filter)

        // Then: only "lang" tagged entries returned
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.tags.contains("lang") })
    }

    /// AC2 [P0]: query() with date range filter returns only entries in range.
    func testInMemoryStore_query_dateRange() async throws {
        // Given: entries at different dates
        let store = InMemoryStore()
        let oldDate = Date(timeIntervalSinceNow: -86400 * 10) // 10 days ago
        let recentDate = Date(timeIntervalSinceNow: -86400) // 1 day ago
        let now = Date()

        try await store.save(domain: "test", knowledge: makeEntry(content: "old", createdAt: oldDate))
        try await store.save(domain: "test", knowledge: makeEntry(content: "recent", createdAt: recentDate))
        try await store.save(domain: "test", knowledge: makeEntry(content: "now", createdAt: now))

        // When: filtering for entries newer than 2 days ago
        let cutoff = Date(timeIntervalSinceNow: -86400 * 2)
        let filter = KnowledgeQueryFilter(tags: nil, olderThan: nil, newerThan: cutoff, limit: nil)
        let results = try await store.query(domain: "test", filter: filter)

        // Then: only recent and now entries returned
        XCTAssertEqual(results.count, 2)
        let contents = results.map(\.content)
        XCTAssertTrue(contents.contains("recent"))
        XCTAssertTrue(contents.contains("now"))
    }

    /// AC2 [P1]: query() with limit returns at most limit entries.
    func testInMemoryStore_query_limit() async throws {
        // Given: 5 entries
        let store = InMemoryStore()
        for i in 1...5 {
            try await store.save(domain: "test", knowledge: makeEntry(content: "entry-\(i)"))
        }

        // When: querying with limit 3
        let filter = KnowledgeQueryFilter(tags: nil, olderThan: nil, newerThan: nil, limit: 3)
        let results = try await store.query(domain: "test", filter: filter)

        // Then: at most 3 entries returned
        XCTAssertLessThanOrEqual(results.count, 3)
    }

    /// AC2 [P0]: query() on non-existent domain returns empty array.
    func testInMemoryStore_query_emptyDomain() async throws {
        // Given: a fresh store
        let store = InMemoryStore()

        // When: querying a domain that has never been written to
        let results = try await store.query(domain: "nonexistent", filter: nil)

        // Then: empty array returned
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - AC2: InMemoryStore -- Delete

    /// AC2 [P0]: delete() removes entries older than the given date.
    func testInMemoryStore_delete_olderThan() async throws {
        // Given: entries at different dates
        let store = InMemoryStore()
        let oldDate = Date(timeIntervalSinceNow: -86400 * 10)
        let recentDate = Date()

        try await store.save(domain: "test", knowledge: makeEntry(content: "old", createdAt: oldDate))
        try await store.save(domain: "test", knowledge: makeEntry(content: "recent", createdAt: recentDate))

        // When: deleting entries older than 5 days ago
        let cutoff = Date(timeIntervalSinceNow: -86400 * 5)
        let deletedCount = try await store.delete(domain: "test", olderThan: cutoff)

        // Then: 1 entry deleted
        XCTAssertEqual(deletedCount, 1)

        // And: only recent entry remains
        let remaining = try await store.query(domain: "test", filter: nil)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.content, "recent")
    }

    /// AC2 [P0]: delete() on empty domain returns 0.
    func testInMemoryStore_delete_emptyDomain() async throws {
        // Given: a fresh store
        let store = InMemoryStore()

        // When: deleting from empty domain
        let deleted = try await store.delete(domain: "test", olderThan: Date())

        // Then: 0 returned
        XCTAssertEqual(deleted, 0)
    }

    // MARK: - AC2: InMemoryStore -- listDomains

    /// AC2 [P0]: listDomains() returns sorted domain names.
    func testInMemoryStore_listDomains() async throws {
        // Given: entries in multiple domains
        let store = InMemoryStore()
        try await store.save(domain: "charlie", knowledge: makeEntry())
        try await store.save(domain: "alpha", knowledge: makeEntry())
        try await store.save(domain: "bravo", knowledge: makeEntry())

        // When: listing domains
        let domains = try await store.listDomains()

        // Then: domains are returned sorted alphabetically
        XCTAssertEqual(domains, ["alpha", "bravo", "charlie"])
    }

    /// AC2 [P0]: listDomains() returns empty array for fresh store.
    func testInMemoryStore_listDomains_empty() async throws {
        // Given: a fresh store
        let store = InMemoryStore()

        // When: listing domains
        let domains = try await store.listDomains()

        // Then: empty array
        XCTAssertTrue(domains.isEmpty)
    }

    // MARK: - AC4: Auto-Expiry

    /// AC4 [P0]: InMemoryStore auto-expires entries exceeding maxAge on query.
    func testInMemoryStore_autoExpiry() async throws {
        // Given: an InMemoryStore with short maxAge
        let store = InMemoryStore(maxAge: 1.0) // 1 second

        // And: an old entry
        let oldEntry = KnowledgeEntry(
            id: UUID().uuidString,
            content: "expired knowledge",
            tags: [],
            createdAt: Date(timeIntervalSinceNow: -5), // 5 seconds ago
            sourceRunId: nil
        )
        try await store.save(domain: "test", knowledge: oldEntry)

        // When: querying after maxAge has elapsed
        let results = try await store.query(domain: "test", filter: nil)

        // Then: expired entry is not returned
        XCTAssertTrue(results.isEmpty)
    }

    /// AC4 [P0]: InMemoryStore does not expire entries within maxAge.
    func testInMemoryStore_noExpiry_withinMaxAge() async throws {
        // Given: an InMemoryStore with long maxAge
        let store = InMemoryStore(maxAge: 2_592_000) // 30 days

        // And: a recent entry
        let recentEntry = makeEntry(content: "fresh knowledge", createdAt: Date())
        try await store.save(domain: "test", knowledge: recentEntry)

        // When: querying
        let results = try await store.query(domain: "test", filter: nil)

        // Then: entry is returned
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "fresh knowledge")
    }

    /// AC4 [P1]: InMemoryStore default maxAge is 30 days (2_592_000 seconds).
    func testInMemoryStore_defaultMaxAge() async throws {
        // Given: a default InMemoryStore
        let store = InMemoryStore()

        // And: an entry from 29 days ago (should NOT be expired)
        let twentyNineDaysAgo = Date(timeIntervalSinceNow: -86400 * 29)
        let entry = makeEntry(content: "not expired yet", createdAt: twentyNineDaysAgo)
        try await store.save(domain: "test", knowledge: entry)

        // When: querying
        let results = try await store.query(domain: "test", filter: nil)

        // Then: entry is still returned (within 30-day default)
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - AC2: InMemoryStore -- Thread Safety

    /// AC2 [P0]: Concurrent access to InMemoryStore does not crash (actor isolation).
    func testInMemoryStore_concurrentAccess() async throws {
        // Given: an InMemoryStore
        let store = InMemoryStore()

        // When: saving entries concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 1...20 {
                group.addTask {
                    let entry = KnowledgeEntry(
                        id: "concurrent-\(i)",
                        content: "concurrent-\(i)",
                        tags: [],
                        createdAt: Date(),
                        sourceRunId: nil
                    )
                    try? await store.save(domain: "concurrent-test", knowledge: entry)
                }
            }
        }

        // Then: all 20 entries were created without crash
        let results = try await store.query(domain: "concurrent-test", filter: nil)
        XCTAssertEqual(results.count, 20)
    }

    // MARK: - AC3: FileBasedMemoryStore -- Init & Save

    /// AC3 [P0]: FileBasedMemoryStore can be instantiated with custom directory.
    func testFileBasedMemoryStore_init_customDir() async {
        // Given: a temp directory
        let store = FileBasedMemoryStore(memoryDir: tempDir)
        _ = store
    }

    /// AC3 [P0]: FileBasedMemoryStore save() creates domain JSON file on disk.
    func testFileBasedMemoryStore_save_createsFile() async throws {
        // Given: a FileBasedMemoryStore
        let store = FileBasedMemoryStore(memoryDir: tempDir)
        let entry = makeEntry(content: "persisted", tags: ["test"])

        // When: saving an entry
        try await store.save(domain: "calculator", knowledge: entry)

        // Then: domain file exists on disk
        let filePath = (tempDir as NSString).appendingPathComponent("calculator.json")
        let exists = FileManager.default.fileExists(atPath: filePath)
        XCTAssertTrue(exists, "calculator.json should exist after save")
    }

    /// AC3,NFR10 [P0]: FileBasedMemoryStore saves files with 0600 permissions.
    func testFileBasedMemoryStore_save_filePermissions() async throws {
        // Given: a FileBasedMemoryStore
        let store = FileBasedMemoryStore(memoryDir: tempDir)
        let entry = makeEntry(content: "secure")

        // When: saving an entry
        try await store.save(domain: "secure-test", knowledge: entry)

        // Then: file has 0600 permissions
        let filePath = (tempDir as NSString).appendingPathComponent("secure-test.json")
        let attrs = try FileManager.default.attributesOfItem(atPath: filePath)
        let permissions = attrs[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o600, "File should have 0600 permissions")
    }

    /// AC3 [P0]: FileBasedMemoryStore directory has 0700 permissions.
    func testFileBasedMemoryStore_dirPermissions() async throws {
        // Given: a FileBasedMemoryStore with a new subdirectory
        let subDir = (tempDir as NSString).appendingPathComponent("subdir-test")
        let store = FileBasedMemoryStore(memoryDir: subDir)
        let entry = makeEntry(content: "dir test")

        // When: saving triggers directory creation
        try await store.save(domain: "test", knowledge: entry)

        // Then: directory has 0700 permissions
        let attrs = try FileManager.default.attributesOfItem(atPath: subDir)
        let permissions = attrs[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o700, "Directory should have 0700 permissions")
    }

    // MARK: - AC3: FileBasedMemoryStore -- Persistence

    /// AC3 [P0]: FileBasedMemoryStore persists entries across instances.
    func testFileBasedMemoryStore_persistence_acrossInstances() async throws {
        // Given: save an entry with first instance
        let store1 = FileBasedMemoryStore(memoryDir: tempDir)
        let entry = makeEntry(content: "survives restart")
        try await store1.save(domain: "persist", knowledge: entry)

        // When: creating a new instance pointing to same directory
        let store2 = FileBasedMemoryStore(memoryDir: tempDir)
        let results = try await store2.query(domain: "persist", filter: nil)

        // Then: the entry is loaded from disk
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "survives restart")
    }

    /// AC3 [P0]: FileBasedMemoryStore loads multiple domains on init.
    func testFileBasedMemoryStore_persistence_multipleDomains() async throws {
        // Given: save entries in multiple domains
        let store1 = FileBasedMemoryStore(memoryDir: tempDir)
        try await store1.save(domain: "domain-a", knowledge: makeEntry(content: "a"))
        try await store1.save(domain: "domain-b", knowledge: makeEntry(content: "b"))

        // When: creating a new instance
        let store2 = FileBasedMemoryStore(memoryDir: tempDir)
        let domains = try await store2.listDomains()

        // Then: both domains are loaded
        XCTAssertTrue(domains.contains("domain-a"))
        XCTAssertTrue(domains.contains("domain-b"))
    }

    // MARK: - AC3: FileBasedMemoryStore -- Query

    /// AC3 [P0]: FileBasedMemoryStore query() returns entries from in-memory cache.
    func testFileBasedMemoryStore_query_returnsCachedEntries() async throws {
        // Given: a store with entries
        let store = FileBasedMemoryStore(memoryDir: tempDir)
        try await store.save(domain: "test", knowledge: makeEntry(content: "cached-1"))
        try await store.save(domain: "test", knowledge: makeEntry(content: "cached-2"))

        // When: querying
        let results = try await store.query(domain: "test", filter: nil)

        // Then: entries are returned from cache
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - AC3: FileBasedMemoryStore -- Delete

    /// AC3 [P0]: FileBasedMemoryStore delete() removes entries and rewrites file.
    func testFileBasedMemoryStore_delete_rewritesFile() async throws {
        // Given: a store with old and new entries
        let store = FileBasedMemoryStore(memoryDir: tempDir)
        let oldDate = Date(timeIntervalSinceNow: -86400 * 10)
        let recentDate = Date()

        try await store.save(domain: "test", knowledge: makeEntry(content: "old", createdAt: oldDate))
        try await store.save(domain: "test", knowledge: makeEntry(content: "recent", createdAt: recentDate))

        // When: deleting old entries
        let cutoff = Date(timeIntervalSinceNow: -86400 * 5)
        let deleted = try await store.delete(domain: "test", olderThan: cutoff)

        // Then: 1 entry deleted
        XCTAssertEqual(deleted, 1)

        // And: remaining entry is the recent one
        let remaining = try await store.query(domain: "test", filter: nil)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.content, "recent")
    }

    /// AC3 [P0]: FileBasedMemoryStore delete() removes file when domain becomes empty.
    func testFileBasedMemoryStore_delete_removesFileWhenEmpty() async throws {
        // Given: a store with one entry
        let store = FileBasedMemoryStore(memoryDir: tempDir)
        let oldDate = Date(timeIntervalSinceNow: -86400 * 10)
        try await store.save(domain: "to-delete", knowledge: makeEntry(content: "only-one", createdAt: oldDate))

        // When: deleting all entries
        let cutoff = Date()
        let deleted = try await store.delete(domain: "to-delete", olderThan: cutoff)

        // Then: entry is deleted
        XCTAssertEqual(deleted, 1)

        // And: file is removed from disk
        let filePath = (tempDir as NSString).appendingPathComponent("to-delete.json")
        let exists = FileManager.default.fileExists(atPath: filePath)
        XCTAssertFalse(exists, "Domain file should be removed when empty")
    }

    // MARK: - AC3: FileBasedMemoryStore -- listDomains

    /// AC3 [P0]: FileBasedMemoryStore listDomains() returns sorted domain names.
    func testFileBasedMemoryStore_listDomains_sorted() async throws {
        // Given: entries in multiple domains
        let store = FileBasedMemoryStore(memoryDir: tempDir)
        try await store.save(domain: "z-domain", knowledge: makeEntry())
        try await store.save(domain: "a-domain", knowledge: makeEntry())
        try await store.save(domain: "m-domain", knowledge: makeEntry())

        // When: listing domains
        let domains = try await store.listDomains()

        // Then: sorted alphabetically
        XCTAssertEqual(domains, ["a-domain", "m-domain", "z-domain"])
    }

    // MARK: - AC6: Corrupt Entry Resilience

    /// AC6 [P0]: FileBasedMemoryStore skips corrupt JSON files without crashing.
    func testFileBasedMemoryStore_corruptFile_skipsEntry() async throws {
        // Given: a corrupt JSON file in the memory directory
        let corruptPath = (tempDir as NSString).appendingPathComponent("corrupt.json")
        try "{ this is not valid json }}}".write(
            toFile: corruptPath,
            atomically: true,
            encoding: .utf8
        )

        // And: a valid domain file
        let store1 = FileBasedMemoryStore(memoryDir: tempDir)
        try await store1.save(domain: "valid", knowledge: makeEntry(content: "ok"))

        // When: creating a new instance (triggers init load)
        let store2 = FileBasedMemoryStore(memoryDir: tempDir)

        // Then: valid domain is accessible, corrupt domain is skipped
        let domains = try await store2.listDomains()
        XCTAssertTrue(domains.contains("valid"), "Valid domain should be loaded")

        // And: corrupt domain does not appear (or appears empty)
        let corruptResults = try await store2.query(domain: "corrupt", filter: nil)
        XCTAssertTrue(corruptResults.isEmpty, "Corrupt domain should yield empty results")
    }

    /// AC6 [P0]: FileBasedMemoryStore handles empty JSON array file gracefully.
    func testFileBasedMemoryStore_emptyArrayFile() async throws {
        // Given: an empty array JSON file
        let emptyPath = (tempDir as NSString).appendingPathComponent("empty.json")
        try "[]".write(
            toFile: emptyPath,
            atomically: true,
            encoding: .utf8
        )

        // When: creating a new instance
        let store = FileBasedMemoryStore(memoryDir: tempDir)

        // Then: no crash, domain returns empty
        let results = try await store.query(domain: "empty", filter: nil)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Domain Name Validation

    /// AC3 [P0]: FileBasedMemoryStore rejects empty domain name.
    func testFileBasedMemoryStore_emptyDomain_throws() async {
        let store = FileBasedMemoryStore(memoryDir: tempDir)
        let entry = makeEntry()

        do {
            try await store.save(domain: "", knowledge: entry)
            XCTFail("Should throw for empty domain name")
        } catch let error as SDKError {
            if case .sessionError = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// AC3 [P0]: FileBasedMemoryStore rejects domain name with path traversal "..".
    func testFileBasedMemoryStore_pathTraversal_throws() async {
        let store = FileBasedMemoryStore(memoryDir: tempDir)
        let entry = makeEntry()

        do {
            try await store.save(domain: "../etc/passwd", knowledge: entry)
            XCTFail("Should throw for path traversal domain")
        } catch let error as SDKError {
            if case .sessionError = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// AC3 [P0]: FileBasedMemoryStore rejects domain name with "/".
    func testFileBasedMemoryStore_slashInDomain_throws() async {
        let store = FileBasedMemoryStore(memoryDir: tempDir)
        let entry = makeEntry()

        do {
            try await store.save(domain: "foo/bar", knowledge: entry)
            XCTFail("Should throw for domain with slash")
        } catch let error as SDKError {
            if case .sessionError = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// AC3 [P0]: FileBasedMemoryStore rejects domain name with "\\".
    func testFileBasedMemoryStore_backslashInDomain_throws() async {
        let store = FileBasedMemoryStore(memoryDir: tempDir)
        let entry = makeEntry()

        do {
            try await store.save(domain: "foo\\bar", knowledge: entry)
            XCTFail("Should throw for domain with backslash")
        } catch let error as SDKError {
            if case .sessionError = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - AC4: FileBasedMemoryStore Auto-Expiry

    /// AC4 [P0]: FileBasedMemoryStore auto-expires entries exceeding maxAge on query.
    func testFileBasedMemoryStore_autoExpiry() async throws {
        // Given: a FileBasedMemoryStore with short maxAge
        let store = FileBasedMemoryStore(memoryDir: tempDir, maxAge: 1.0)

        // And: an old entry
        let oldEntry = KnowledgeEntry(
            id: UUID().uuidString,
            content: "expired",
            tags: [],
            createdAt: Date(timeIntervalSinceNow: -5),
            sourceRunId: nil
        )
        try await store.save(domain: "test", knowledge: oldEntry)

        // When: querying
        let results = try await store.query(domain: "test", filter: nil)

        // Then: expired entry not returned
        XCTAssertTrue(results.isEmpty)
    }

    /// AC4 [P1]: FileBasedMemoryStore default maxAge is 30 days.
    func testFileBasedMemoryStore_defaultMaxAge() async throws {
        // Given: a default FileBasedMemoryStore
        let store = FileBasedMemoryStore(memoryDir: tempDir)

        // And: an entry from 29 days ago (should NOT be expired)
        let twentyNineDaysAgo = Date(timeIntervalSinceNow: -86400 * 29)
        let entry = makeEntry(content: "not expired yet", createdAt: twentyNineDaysAgo)
        try await store.save(domain: "test", knowledge: entry)

        // When: querying
        let results = try await store.query(domain: "test", filter: nil)

        // Then: entry is still returned
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - AC3: FileBasedMemoryStore -- Concurrent Safety

    /// AC3 [P0]: Concurrent saves to FileBasedMemoryStore complete without data loss.
    func testFileBasedMemoryStore_concurrentAccess() async throws {
        // Given: a FileBasedMemoryStore
        let store = FileBasedMemoryStore(memoryDir: tempDir)

        // When: saving entries concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    let entry = KnowledgeEntry(
                        id: "concurrent-\(i)",
                        content: "concurrent-\(i)",
                        tags: [],
                        createdAt: Date(),
                        sourceRunId: nil
                    )
                    try await store.save(domain: "concurrent-test", knowledge: entry)
                }
            }
            try await group.waitForAll()
        }

        // Then: all entries were saved
        let results = try await store.query(domain: "concurrent-test", filter: nil)
        XCTAssertEqual(results.count, 10)
    }

    // MARK: - AC3: FileBasedMemoryStore -- Default Directory

    /// AC3 [P0]: FileBasedMemoryStore default init uses ~/.agent/memory/ path.
    func testFileBasedMemoryStore_defaultDir_savesSuccessfully() async {
        // Given: a FileBasedMemoryStore with default init
        let store = FileBasedMemoryStore()
        let entry = makeEntry(content: "default dir test")

        // Then: save should succeed (proving default dir works)
        do {
            try await store.save(domain: "test-default-dir", knowledge: entry)

            // Cleanup
            let cutoff = Date(timeIntervalSinceNow: 86400) // delete all
            _ = try await store.delete(domain: "test-default-dir", olderThan: cutoff)
        } catch {
            XCTFail("Default directory save should not throw: \(error)")
        }
    }

    // MARK: - AC5: AgentOptions Integration

    /// AC5 [P0]: AgentOptions has a memoryStore property.
    func testAgentOptions_hasMemoryStoreProperty() {
        // Given: default AgentOptions
        let options = AgentOptions(model: "test")

        // Then: memoryStore property exists and is nil by default
        XCTAssertNil(options.memoryStore)
    }

    /// AC5 [P0]: AgentOptions can be initialized with a memoryStore.
    func testAgentOptions_initWithMemoryStore() async {
        // Given: an InMemoryStore
        let store = InMemoryStore()

        // When: creating AgentOptions with memoryStore
        let options = AgentOptions(model: "test", memoryStore: store)

        // Then: memoryStore is set
        XCTAssertNotNil(options.memoryStore)
    }

    // MARK: - AC5: ToolContext Integration

    /// AC5 [P0]: ToolContext has a memoryStore field.
    func testToolContext_hasMemoryStoreField() async throws {
        // Given: a ToolContext with memoryStore set
        let store = InMemoryStore()
        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tuid",
            todoStore: nil,
            memoryStore: store
        )

        // Then: memoryStore is accessible
        XCTAssertNotNil(context.memoryStore)
    }

    /// AC5 [P0]: ToolContext.withToolUseId() preserves memoryStore.
    func testToolContext_withToolUseId_preservesMemoryStore() async throws {
        // Given: a ToolContext with memoryStore
        let store = InMemoryStore()
        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "original",
            todoStore: nil,
            memoryStore: store
        )

        // When: copying with new toolUseId
        let copy = context.withToolUseId("new-id")

        // Then: memoryStore is preserved
        XCTAssertNotNil(copy.memoryStore)
    }
}

import XCTest
@testable import OpenAgentSDK

final class FactStoreTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("fact-store-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        super.tearDown()
    }

    private func makeFact(
        domain: String = "test",
        kind: MemoryKind = .affordance,
        content: String = "test fact",
        status: MemoryFactStatus = .candidate
    ) -> MemoryFact {
        MemoryFact(
            id: MemoryFact.factId(kind: kind, description: content),
            domain: domain,
            content: content,
            status: status,
            confidence: 0.7,
            evidenceCount: 1,
            source: .observation,
            kind: kind,
            createdAt: Date(),
            lastVerifiedAt: Date()
        )
    }

    // MARK: - Save and Query CRUD

    func testSaveAndQuery() async throws {
        let store = FactStore(memoryDir: tempDir)
        let fact = makeFact()
        try await store.save(domain: "test", fact: fact)

        let results = try await store.query(domain: "test")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, fact.id)
    }

    func testUpsertBehavior() async throws {
        let store = FactStore(memoryDir: tempDir)
        let fact1 = makeFact(content: "original")
        try await store.save(domain: "test", fact: fact1)

        let fact2 = MemoryFact(
            id: fact1.id, domain: "test", content: "updated",
            status: .active, confidence: 0.9, evidenceCount: 3,
            source: .observation, kind: .affordance,
            createdAt: fact1.createdAt, lastVerifiedAt: Date()
        )
        try await store.save(domain: "test", fact: fact2)

        let results = try await store.query(domain: "test")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "updated")
        XCTAssertEqual(results.first?.status, .active)
    }

    // MARK: - Query Filtering

    func testQueryFilterByStatus() async throws {
        let store = FactStore(memoryDir: tempDir)
        let candidate = makeFact(content: "c1", status: .candidate)
        let active = makeFact(content: "c2", status: .active)
        try await store.saveAll(domain: "test", facts: [candidate, active])

        let candidates = try await store.query(domain: "test", filter: FactFilter(status: .candidate))
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.status, .candidate)

        let actives = try await store.query(domain: "test", filter: FactFilter(status: .active))
        XCTAssertEqual(actives.count, 1)
    }

    func testQueryFilterByKind() async throws {
        let store = FactStore(memoryDir: tempDir)
        let aff = makeFact(kind: .affordance, content: "aff")
        let avo = makeFact(kind: .avoid, content: "avo")
        try await store.saveAll(domain: "test", facts: [aff, avo])

        let results = try await store.query(domain: "test", filter: FactFilter(kind: .avoid))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.kind, .avoid)
    }

    // MARK: - Lazy Migration from KnowledgeEntry Files

    func testLazyMigrationFromKnowledgeEntry() async throws {
        // Write a legacy KnowledgeEntry file
        let dateFormatter = makeISO8601DateFormatter()
        let now = dateFormatter.string(from: Date())

        let legacyJSON: [[String: Any]] = [
            [
                "id": "legacy-1",
                "content": "legacy knowledge",
                "tags": ["affordance", "test"],
                "createdAt": now
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: legacyJSON, options: .prettyPrinted)
        let legacyPath = (tempDir as NSString).appendingPathComponent("mydomain.json")
        FileManager.default.createFile(atPath: legacyPath, contents: data)

        let store = FactStore(memoryDir: tempDir)
        let results = try await store.query(domain: "mydomain")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "legacy-1")
        XCTAssertEqual(results.first?.content, "legacy knowledge")
        XCTAssertEqual(results.first?.status, .candidate)
        XCTAssertEqual(results.first?.kind, .affordance)
        XCTAssertEqual(results.first?.evidenceCount, 1)

        // Verify new format file was created
        let newPath = (tempDir as NSString).appendingPathComponent("mydomain-facts.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: newPath))
    }

    // MARK: - listDomains

    func testListDomainsDiscoversBothFormats() async throws {
        let store = FactStore(memoryDir: tempDir)

        // Write new format
        let fact = makeFact(domain: "newdomain")
        try await store.save(domain: "newdomain", fact: fact)

        // Write legacy format
        let dateFormatter = makeISO8601DateFormatter()
        let now = dateFormatter.string(from: Date())
        let legacyJSON: [[String: Any]] = [["id": "l1", "content": "c", "tags": [], "createdAt": now]]
        let data = try JSONSerialization.data(withJSONObject: legacyJSON, options: .prettyPrinted)
        let legacyPath = (tempDir as NSString).appendingPathComponent("legacydomain.json")
        FileManager.default.createFile(atPath: legacyPath, contents: data)

        let domains = try await store.listDomains()
        XCTAssertTrue(domains.contains("newdomain"))
        XCTAssertTrue(domains.contains("legacydomain"))
    }

    // MARK: - Domain Validation

    func testRejectsEmptyDomainName() async {
        let store = FactStore(memoryDir: tempDir)
        let fact = makeFact()
        do {
            try await store.save(domain: "", fact: fact)
            XCTFail("Expected error for empty domain name")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("empty"))
        }
    }

    func testRejectsDomainWithSlash() async {
        let store = FactStore(memoryDir: tempDir)
        let fact = makeFact()
        do {
            try await store.save(domain: "evil/path", fact: fact)
            XCTFail("Expected error for domain with slash")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("invalid character"))
        }
    }

    func testRejectsDomainWithDotDot() async {
        let store = FactStore(memoryDir: tempDir)
        let fact = makeFact()
        do {
            try await store.save(domain: "..", fact: fact)
            XCTFail("Expected error for domain with ..")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("invalid character"))
        }
    }

    // MARK: - Combined Filter

    func testQueryWithCombinedStatusAndKindFilter() async throws {
        let store = FactStore(memoryDir: tempDir)
        let facts = [
            makeFact(kind: .affordance, content: "aff-cand", status: .candidate),
            makeFact(kind: .affordance, content: "aff-act", status: .active),
            makeFact(kind: .avoid, content: "avo-cand", status: .candidate),
            makeFact(kind: .avoid, content: "avo-act", status: .active),
        ]
        try await store.saveAll(domain: "test", facts: facts)

        let result = try await store.query(
            domain: "test",
            filter: FactFilter(status: .active, kind: .avoid)
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.content, "avo-act")
    }

    func testQueryNonExistentDomainReturnsEmpty() async throws {
        let store = FactStore(memoryDir: tempDir)
        let results = try await store.query(domain: "nonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Corrupt File Handling

    func testHandlesCorruptJsonFile() async throws {
        let corruptPath = (tempDir as NSString).appendingPathComponent("corrupt-facts.json")
        FileManager.default.createFile(atPath: corruptPath, contents: Data("not valid json".utf8))

        let store = FactStore(memoryDir: tempDir)
        let results = try await store.query(domain: "corrupt")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Delete

    func testDeleteRemovesDomain() async throws {
        let store = FactStore(memoryDir: tempDir)
        let fact = makeFact()
        try await store.save(domain: "test", fact: fact)

        try await store.delete(domain: "test")
        let results = try await store.query(domain: "test")
        XCTAssertTrue(results.isEmpty)
    }
}

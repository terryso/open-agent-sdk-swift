import XCTest
@testable import OpenAgentSDK

final class MemoryBundleImportServiceTests: TempDirTestCase {

    private func makeBundle(
        schemaVersion: Int = 1,
        domains: [(String, [MemoryFact])] = []
    ) -> Data {
        let exported = domains.map { domain, facts in
            ExportedDomain(domain: domain, facts: facts)
        }
        let bundle = MemoryBundle(schemaVersion: schemaVersion, exportedAt: Date(), memories: exported)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return (try! encoder.encode(bundle))
    }

    private func makeFact(
        id: String = "fact-1",
        domain: String = "test",
        confidence: Double = 0.8,
        evidenceCount: Int = 2
    ) -> MemoryFact {
        MemoryFact(
            id: id, domain: domain, content: "import test",
            status: .active, confidence: confidence, evidenceCount: evidenceCount,
            source: .observation, kind: .affordance,
            createdAt: Date(), lastVerifiedAt: Date()
        )
    }

    func testImportWithValidBundle() async throws {
        let fact = makeFact()
        let data = makeBundle(domains: [("test", [fact])])

        let store = FactStore(memoryDir: tempDir)
        let service = MemoryBundleImportService()
        let result = try await service.importBundle(from: data, store: store)

        XCTAssertEqual(result.domainsProcessed, 1)
        XCTAssertEqual(result.factsImported, 1)
        XCTAssertEqual(result.factsMerged, 0)
    }

    func testDowngradeForcesCandidateAndCapsConfidence() async throws {
        let fact = makeFact(confidence: 0.9, evidenceCount: 5) // active, high confidence
        let data = makeBundle(domains: [("test", [fact])])

        let store = FactStore(memoryDir: tempDir)
        let service = MemoryBundleImportService()
        _ = try await service.importBundle(from: data, store: store)

        let results = try await store.query(domain: "test")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.status, .candidate)
        XCTAssertEqual(results.first?.confidence, 0.55)
        XCTAssertEqual(results.first?.source, .imported)
    }

    func testMergeWithExistingFacts() async throws {
        let existing = MemoryFact(
            id: "same-id", domain: "test", content: "existing",
            status: .candidate, confidence: 0.4, evidenceCount: 1,
            source: .observation, kind: .affordance,
            createdAt: Date(), lastVerifiedAt: Date()
        )

        let store = FactStore(memoryDir: tempDir)
        try await store.save(domain: "test", fact: existing)

        let incoming = makeFact(id: "same-id", confidence: 0.9, evidenceCount: 3)
        let data = makeBundle(domains: [("test", [incoming])])

        let service = MemoryBundleImportService()
        let result = try await service.importBundle(from: data, store: store)

        XCTAssertEqual(result.factsMerged, 1)
        XCTAssertEqual(result.factsImported, 0)

        let results = try await store.query(domain: "test")
        XCTAssertEqual(results.count, 1)
        // After merge: incoming gets downgraded to 0.55 conf, candidate status
        // Merge: stronger status wins (existing candidate == incoming candidate), max confidence (0.55 > 0.4)
        XCTAssertEqual(results.first?.confidence, 0.55)
    }

    func testRejectInvalidSchemaVersion() async throws {
        let data = makeBundle(schemaVersion: 99)

        let store = FactStore(memoryDir: tempDir)
        let service = MemoryBundleImportService()

        do {
            _ = try await service.importBundle(from: data, store: store)
            XCTFail("Expected error for invalid schema version")
        } catch let error as MemoryBundleError {
            if case .invalidBundle(let reason) = error {
                XCTAssertTrue(reason.contains("Unsupported schema_version"))
            } else {
                XCTFail("Unexpected error type")
            }
        }
    }

    func testImportResultCounts() async throws {
        let facts = [makeFact(id: "a"), makeFact(id: "b"), makeFact(id: "c")]
        let data = makeBundle(domains: [("d1", [facts[0]]), ("d2", [facts[1], facts[2]])])

        let store = FactStore(memoryDir: tempDir)
        let service = MemoryBundleImportService()
        let result = try await service.importBundle(from: data, store: store)

        XCTAssertEqual(result.domainsProcessed, 2)
        XCTAssertEqual(result.factsImported, 3)
        XCTAssertEqual(result.factsMerged, 0)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Import from URL

    func testImportFromURL() async throws {
        let fact = makeFact()
        let data = makeBundle(domains: [("test", [fact])])

        let fileURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("bundle.json"))
        try data.write(to: fileURL)

        let store = FactStore(memoryDir: tempDir)
        let service = MemoryBundleImportService()
        let result = try await service.importBundle(from: fileURL, store: store)

        XCTAssertEqual(result.factsImported, 1)
    }

    // MARK: - Invalid JSON

    func testRejectsInvalidJSON() async throws {
        let invalidData = Data("not json at all".utf8)
        let store = FactStore(memoryDir: tempDir)
        let service = MemoryBundleImportService()

        do {
            _ = try await service.importBundle(from: invalidData, store: store)
            XCTFail("Expected error for invalid JSON")
        } catch let error as MemoryBundleError {
            if case .invalidBundle(let reason) = error {
                XCTAssertTrue(reason.contains("Invalid JSON"))
            } else {
                XCTFail("Unexpected error type")
            }
        }
    }

    // MARK: - Merge with stronger existing status

    func testMergePreservesStrongerExistingStatus() async throws {
        let existing = MemoryFact(
            id: "same-id", domain: "test", content: "existing",
            status: .active, confidence: 0.9, evidenceCount: 3,
            source: .observation, kind: .affordance,
            createdAt: Date(), lastVerifiedAt: Date()
        )

        let store = FactStore(memoryDir: tempDir)
        try await store.save(domain: "test", fact: existing)

        // Incoming active fact — gets downgraded to candidate, confidence 0.55
        let incoming = makeFact(id: "same-id", confidence: 0.8, evidenceCount: 2)
        let data = makeBundle(domains: [("test", [incoming])])

        let service = MemoryBundleImportService()
        _ = try await service.importBundle(from: data, store: store)

        let results = try await store.query(domain: "test")
        XCTAssertEqual(results.count, 1)
        // Existing active > incoming candidate, so status should stay active
        XCTAssertEqual(results.first?.status, .active)
    }

    // MARK: - Evidence count capped at 5

    func testMergeCapsEvidenceCountAtFive() async throws {
        let existing = MemoryFact(
            id: "same-id", domain: "test", content: "existing",
            status: .candidate, confidence: 0.3, evidenceCount: 3,
            source: .observation, kind: .affordance,
            createdAt: Date(), lastVerifiedAt: Date()
        )

        let store = FactStore(memoryDir: tempDir)
        try await store.save(domain: "test", fact: existing)

        let incoming = makeFact(id: "same-id", confidence: 0.8, evidenceCount: 4)
        let data = makeBundle(domains: [("test", [incoming])])

        let service = MemoryBundleImportService()
        _ = try await service.importBundle(from: data, store: store)

        let results = try await store.query(domain: "test")
        XCTAssertEqual(results.count, 1)
        // 3 (existing) + 4 (incoming after downgrade) = 7, capped at 5
        XCTAssertEqual(results.first?.evidenceCount, 5)
    }

    // MARK: - Multiple domains

    func testImportMultipleDomains() async throws {
        let f1 = makeFact(id: "a", domain: "alpha")
        let f2 = makeFact(id: "b", domain: "beta")
        let data = makeBundle(domains: [("alpha", [f1]), ("beta", [f2])])

        let store = FactStore(memoryDir: tempDir)
        let service = MemoryBundleImportService()
        let result = try await service.importBundle(from: data, store: store)

        XCTAssertEqual(result.domainsProcessed, 2)
        XCTAssertEqual(result.factsImported, 2)

        let alpha = try await store.query(domain: "alpha")
        let beta = try await store.query(domain: "beta")
        XCTAssertEqual(alpha.count, 1)
        XCTAssertEqual(beta.count, 1)
    }

    // MARK: - Non-existent file

    func testRejectsNonExistentFile() async throws {
        let missingURL = URL(fileURLWithPath: "/tmp/nonexistent-bundle-\(UUID().uuidString).json")
        let store = FactStore(memoryDir: tempDir)
        let service = MemoryBundleImportService()

        do {
            _ = try await service.importBundle(from: missingURL, store: store)
            XCTFail("Expected error for non-existent file")
        } catch let error as MemoryBundleError {
            if case .invalidBundle(let reason) = error {
                XCTAssertTrue(reason.contains("Cannot read file"))
            } else {
                XCTFail("Unexpected error type")
            }
        }
    }
}

import XCTest
@testable import OpenAgentSDK

final class MemoryBundleExportServiceTests: TempDirTestCase {

    private func makeFact(domain: String = "test") -> MemoryFact {
        MemoryFact.create(domain: domain, kind: .affordance, description: "export test \(UUID().uuidString)")
    }

    func testExportAllIncludesAllDomains() async throws {
        let store = FactStore(memoryDir: tempDir)
        try await store.save(domain: "d1", fact: makeFact(domain: "d1"))
        try await store.save(domain: "d2", fact: makeFact(domain: "d2"))

        let service = MemoryBundleExportService()
        let bundle = try await service.exportAll(store: store)

        XCTAssertEqual(bundle.memories.count, 2)
        XCTAssertEqual(bundle.schemaVersion, 1)
        let domainNames = bundle.memories.map { $0.domain }.sorted()
        XCTAssertEqual(domainNames, ["d1", "d2"])
    }

    func testExportDomainForSingleDomain() async throws {
        let store = FactStore(memoryDir: tempDir)
        try await store.save(domain: "target", fact: makeFact(domain: "target"))
        try await store.save(domain: "other", fact: makeFact(domain: "other"))

        let service = MemoryBundleExportService()
        let bundle = try await service.exportDomain(store: store, domain: "target")

        XCTAssertEqual(bundle.memories.count, 1)
        XCTAssertEqual(bundle.memories.first?.domain, "target")
    }

    func testWriteBundleProducesValidJSON() async throws {
        let store = FactStore(memoryDir: tempDir)
        let fact = makeFact()
        try await store.save(domain: "test", fact: fact)

        let service = MemoryBundleExportService()
        let bundle = try await service.exportAll(store: store)

        let fileURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("bundle.json"))
        try service.writeBundle(bundle, to: fileURL)

        let data = try Data(contentsOf: fileURL)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(jsonObject)

        // Verify it can be decoded back
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MemoryBundle.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.memories.count, 1)
    }

    // MARK: - Empty Store

    func testExportAllFromEmptyStore() async throws {
        let store = FactStore(memoryDir: tempDir)
        let service = MemoryBundleExportService()
        let bundle = try await service.exportAll(store: store)

        XCTAssertEqual(bundle.schemaVersion, 1)
        XCTAssertTrue(bundle.memories.isEmpty)
    }

    // MARK: - Multiple Facts Per Domain

    func testExportDomainWithMultipleFacts() async throws {
        let store = FactStore(memoryDir: tempDir)
        let f1 = MemoryFact.create(domain: "test", kind: .affordance, description: "fact a")
        let f2 = MemoryFact.create(domain: "test", kind: .avoid, description: "fact b")
        try await store.saveAll(domain: "test", facts: [f1, f2])

        let service = MemoryBundleExportService()
        let bundle = try await service.exportDomain(store: store, domain: "test")

        XCTAssertEqual(bundle.memories.count, 1)
        XCTAssertEqual(bundle.memories.first?.facts.count, 2)
    }

    // MARK: - Bundle uses snake_case JSON keys

    func testBundleJsonUsesSnakeCaseKeys() async throws {
        let store = FactStore(memoryDir: tempDir)
        try await store.save(domain: "test", fact: makeFact())

        let service = MemoryBundleExportService()
        let bundle = try await service.exportAll(store: store)

        let fileURL = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent("snake.json"))
        try service.writeBundle(bundle, to: fileURL)

        let rawJSON = try String(contentsOf: fileURL)
        XCTAssertTrue(rawJSON.contains("\"schema_version\""))
        XCTAssertTrue(rawJSON.contains("\"exported_at\""))
    }
}

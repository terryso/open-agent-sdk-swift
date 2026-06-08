import XCTest
@testable import OpenAgentSDK

final class FrozenSnapshotTests: TempDirTestCase {

    // MARK: - FrozenSnapshot

    func testSnapshotCreation() {
        let facts = [
            MemoryFact.create(domain: "testing", kind: .affordance, description: "Fact 1"),
            MemoryFact.create(domain: "testing", kind: .avoid, description: "Fact 2"),
        ]
        let snapshot = FrozenSnapshot(domain: "testing", facts: facts)
        XCTAssertEqual(snapshot.domain, "testing")
        XCTAssertEqual(snapshot.facts.count, 2)
        XCTAssertFalse(snapshot.snapshotId.isEmpty)
    }

    func testSnapshotEquality() {
        let frozenAt = Date()
        let facts = [MemoryFact.create(domain: "nav", kind: .observation, description: "test")]
        let s1 = FrozenSnapshot(domain: "nav", facts: facts, frozenAt: frozenAt)
        let s2 = FrozenSnapshot(domain: "nav", facts: facts, frozenAt: frozenAt)
        XCTAssertEqual(s1, s2)
    }

    func testSnapshotDeterministicId() {
        let frozenAt = Date()
        let s1 = FrozenSnapshot(domain: "testing", facts: [], frozenAt: frozenAt)
        let s2 = FrozenSnapshot(domain: "testing", facts: [], frozenAt: frozenAt)
        XCTAssertEqual(s1.snapshotId, s2.snapshotId)
    }

    func testSnapshotCodable() throws {
        let facts = [MemoryFact.create(domain: "testing", kind: .affordance, description: "Codable test")]
        let snapshot = FrozenSnapshot(domain: "testing", facts: facts)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(FrozenSnapshot.self, from: data)
        XCTAssertEqual(decoded.domain, snapshot.domain)
        XCTAssertEqual(decoded.facts.count, snapshot.facts.count)
        XCTAssertEqual(decoded.snapshotId, snapshot.snapshotId)
    }

    // MARK: - FactStore.snapshot()

    private func makeFactStore() -> FactStore {
        FactStore(memoryDir: tempDir)
    }

    func testSnapshotReturnsDeepCopy() async throws {
        let store = makeFactStore()
        let fact = MemoryFact.create(domain: "testing", kind: .affordance, description: "Original")
        try await store.save(domain: "testing", fact: fact)

        let snapshot = try await store.snapshot(domain: "testing")
        XCTAssertEqual(snapshot.facts.count, 1)

        // Mutate store — snapshot should be unaffected
        let fact2 = MemoryFact.create(domain: "testing", kind: .avoid, description: "New fact")
        try await store.save(domain: "testing", fact: fact2)

        let freshSnapshot = try await store.snapshot(domain: "testing")
        XCTAssertEqual(freshSnapshot.facts.count, 2)
        XCTAssertEqual(snapshot.facts.count, 1, "Original snapshot should be unaffected")
    }

    func testSnapshotNonexistentDomainReturnsEmpty() async throws {
        let store = makeFactStore()
        let snapshot = try await store.snapshot(domain: "nonexistent")
        XCTAssertEqual(snapshot.facts.count, 0)
        XCTAssertEqual(snapshot.domain, "nonexistent")
    }

    // MARK: - FactStore.rollback()

    func testRollbackRestoresFacts() async throws {
        let store = makeFactStore()
        let fact1 = MemoryFact.create(domain: "testing", kind: .affordance, description: "Fact 1")
        try await store.save(domain: "testing", fact: fact1)

        let snapshot = try await store.snapshot(domain: "testing")

        // Add more facts
        let fact2 = MemoryFact.create(domain: "testing", kind: .avoid, description: "Fact 2")
        try await store.save(domain: "testing", fact: fact2)
        let facts = try await store.query(domain: "testing")
        XCTAssertEqual(facts.count, 2)

        // Rollback to snapshot
        try await store.rollback(to: snapshot)
        let restored = try await store.query(domain: "testing")
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.content, "Fact 1")
    }

    func testRollbackPreservesOtherDomains() async throws {
        let store = makeFactStore()

        // Save facts in two domains
        let factA = MemoryFact.create(domain: "alpha", kind: .affordance, description: "Alpha fact")
        let factB = MemoryFact.create(domain: "beta", kind: .avoid, description: "Beta fact")
        try await store.save(domain: "alpha", fact: factA)
        try await store.save(domain: "beta", fact: factB)

        let snapshot = try await store.snapshot(domain: "alpha")

        // Mutate alpha
        let factA2 = MemoryFact.create(domain: "alpha", kind: .observation, description: "Alpha fact 2")
        try await store.save(domain: "alpha", fact: factA2)

        // Rollback alpha
        try await store.rollback(to: snapshot)

        let alphaFacts = try await store.query(domain: "alpha")
        XCTAssertEqual(alphaFacts.count, 1)
        XCTAssertEqual(alphaFacts.first?.content, "Alpha fact")

        let betaFacts = try await store.query(domain: "beta")
        XCTAssertEqual(betaFacts.count, 1, "Beta domain should be unaffected")
        XCTAssertEqual(betaFacts.first?.content, "Beta fact")
    }

    func testRollbackThrowsOnInvalidDomain() async throws {
        let store = makeFactStore()
        let snapshot = FrozenSnapshot(domain: "../etc", facts: [])
        do {
            try await store.rollback(to: snapshot)
            XCTFail("Expected error for path traversal domain")
        } catch {
            // Expected
        }
    }
}

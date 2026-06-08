import XCTest
@testable import OpenAgentSDK

final class MemoryFactTests: XCTestCase {

    private static let testEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let testDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Deterministic ID Generation

    func testSameInputProducesSameId() {
        let id1 = MemoryFact.factId(kind: .affordance, description: "Use SwiftUI for UI")
        let id2 = MemoryFact.factId(kind: .affordance, description: "Use SwiftUI for UI")
        XCTAssertEqual(id1, id2)
    }

    func testDifferentInputsProduceDifferentIds() {
        let id1 = MemoryFact.factId(kind: .affordance, description: "Use SwiftUI for UI")
        let id2 = MemoryFact.factId(kind: .avoid, description: "Use SwiftUI for UI")
        XCTAssertNotEqual(id1, id2)

        let id3 = MemoryFact.factId(kind: .affordance, description: "Use UIKit for UI")
        XCTAssertNotEqual(id1, id3)
    }

    func testNormalizationOfDescription() {
        let id1 = MemoryFact.factId(kind: .observation, description: "  Hello World  ")
        let id2 = MemoryFact.factId(kind: .observation, description: "hello world")
        XCTAssertEqual(id1, id2)
    }

    // MARK: - Create Factory

    func testCreateSetsDefaults() {
        let fact = MemoryFact.create(domain: "test", kind: .affordance, description: "test fact")
        XCTAssertEqual(fact.status, .candidate)
        XCTAssertEqual(fact.evidenceCount, 1)
        XCTAssertEqual(fact.confidence, 0.5)
        XCTAssertEqual(fact.source, .observation)
        XCTAssertEqual(fact.domain, "test")
        XCTAssertEqual(fact.content, "test fact")
        XCTAssertEqual(fact.kind, .affordance)
        XCTAssertEqual(fact.id, MemoryFact.factId(kind: .affordance, description: "test fact"))
    }

    func testCreateClampsConfidence() {
        let high = MemoryFact.create(domain: "test", kind: .avoid, description: "x", confidence: 2.0)
        XCTAssertEqual(high.confidence, 1.0)

        let low = MemoryFact.create(domain: "test", kind: .avoid, description: "y", confidence: -0.5)
        XCTAssertEqual(low.confidence, 0.0)
    }

    // MARK: - Normalize

    func testNormalizeClampsConfidence() {
        let over = MemoryFact(
            id: "1", domain: "d", content: "c", status: .candidate,
            confidence: 1.5, evidenceCount: 1, source: .observation,
            kind: .affordance, createdAt: Date(), lastVerifiedAt: Date()
        )
        let normalized = MemoryFact.normalize(over)
        XCTAssertEqual(normalized.confidence, 1.0)
    }

    func testNormalizeClampsEvidenceCount() {
        let under = MemoryFact(
            id: "1", domain: "d", content: "c", status: .candidate,
            confidence: 0.5, evidenceCount: -3, source: .observation,
            kind: .affordance, createdAt: Date(), lastVerifiedAt: Date()
        )
        let normalized = MemoryFact.normalize(under)
        XCTAssertEqual(normalized.evidenceCount, 0)
    }

    // MARK: - Unicode and Edge Cases

    func testFactIdWithUnicodeDescription() {
        let id1 = MemoryFact.factId(kind: .observation, description: "中文测试")
        let id2 = MemoryFact.factId(kind: .observation, description: "中文测试")
        XCTAssertEqual(id1, id2)
        XCTAssertFalse(id1.isEmpty)
    }

    func testFactIdWithEmptyDescription() {
        let id = MemoryFact.factId(kind: .affordance, description: "")
        XCTAssertFalse(id.isEmpty)
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let now = Date()
        let fact = MemoryFact(
            id: "abc123", domain: "coding", content: "Don't force unwrap",
            status: .candidate, confidence: 0.8, evidenceCount: 1,
            source: .observation, kind: .avoid,
            createdAt: now, lastVerifiedAt: now
        )
        let data = try Self.testEncoder.encode(fact)

        let decoded = try Self.testDecoder.decode(MemoryFact.self, from: data)

        XCTAssertEqual(decoded.id, fact.id)
        XCTAssertEqual(decoded.domain, fact.domain)
        XCTAssertEqual(decoded.content, fact.content)
        XCTAssertEqual(decoded.status, fact.status)
        XCTAssertEqual(decoded.confidence, fact.confidence)
        XCTAssertEqual(decoded.evidenceCount, fact.evidenceCount)
        XCTAssertEqual(decoded.source, fact.source)
        XCTAssertEqual(decoded.kind, fact.kind)
    }
}

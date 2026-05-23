import XCTest
@testable import OpenAgentSDK

final class ReviewMemoryToolTests: XCTestCase {

    // MARK: - Helper: Real FactStore with temp directory

    private func makeFactStore() -> (FactStore, URL) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = FactStore(memoryDir: tmp.path)
        return (store, tmp)
    }

    private func callTool(
        factStore: FactStore,
        domain: String,
        content: String,
        kind: String,
        confidence: Double? = nil
    ) async -> String {
        let tool = createReviewMemoryTool(factStore: factStore)
        var input: [String: Any] = [
            "domain": domain,
            "content": content,
            "kind": kind,
        ]
        if let confidence { input["confidence"] = confidence }
        let context = ToolContext(cwd: "/tmp")
        let result = await tool.call(input: input, context: context)
        return result.content
    }

    // MARK: - Tests

    func testSuccessfulSave() async {
        let (store, tmp) = makeFactStore()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let output = await callTool(
            factStore: store,
            domain: "testing",
            content: "Always use mock FactStore in unit tests",
            kind: "affordance",
            confidence: 0.9
        )

        XCTAssertTrue(output.contains("\"success\": true"))
        XCTAssertTrue(output.contains("testing"))

        let facts = try? await store.query(domain: "testing")
        XCTAssertEqual(facts?.count, 1)
        XCTAssertEqual(facts?.first?.domain, "testing")
        XCTAssertEqual(facts?.first?.content, "Always use mock FactStore in unit tests")
        XCTAssertEqual(facts?.first?.kind, .affordance)
    }

    func testInvalidKind() async {
        let (store, tmp) = makeFactStore()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let output = await callTool(
            factStore: store,
            domain: "testing",
            content: "some content",
            kind: "invalid_kind"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("Invalid kind"))
        XCTAssertTrue(output.contains("invalid_kind"))
    }

    func testDefaultConfidence() async {
        let (store, tmp) = makeFactStore()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let output = await callTool(
            factStore: store,
            domain: "navigation",
            content: "Use absolute paths",
            kind: "avoid",
            confidence: nil
        )

        XCTAssertTrue(output.contains("\"success\": true"))

        let facts = try? await store.query(domain: "navigation")
        XCTAssertEqual(facts?.first?.confidence, 0.7)
    }

    func testAllValidKinds() async {
        let (store, tmp) = makeFactStore()
        defer { try? FileManager.default.removeItem(at: tmp) }

        for kind in ["affordance", "avoid", "observation"] {
            let output = await callTool(
                factStore: store,
                domain: "test-\(kind)",
                content: "\(kind) content",
                kind: kind
            )
            XCTAssertTrue(output.contains("\"success\": true"), "Failed for kind: \(kind)")
        }
    }

    func testFactStoreErrorPropagation() async {
        // Use an invalid directory to force FactStore.save to throw
        let store = FactStore(memoryDir: "/dev/null/impossible-path-\(UUID().uuidString)")
        let output = await callTool(
            factStore: store,
            domain: "error-test",
            content: "This should fail",
            kind: "affordance"
        )

        XCTAssertTrue(output.contains("\"success\": false"), "Expected failure when FactStore.save throws")
    }

    func testEmptyDomain() async {
        let (store, tmp) = makeFactStore()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let output = await callTool(
            factStore: store,
            domain: "  ",
            content: "some content",
            kind: "affordance"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("must not be empty"))
    }

    func testEmptyContent() async {
        let (store, tmp) = makeFactStore()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let output = await callTool(
            factStore: store,
            domain: "testing",
            content: "  ",
            kind: "affordance"
        )

        XCTAssertTrue(output.contains("\"success\": false"))
        XCTAssertTrue(output.contains("must not be empty"))
    }
}

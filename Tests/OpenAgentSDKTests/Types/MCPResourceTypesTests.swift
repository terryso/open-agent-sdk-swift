import XCTest
@testable import OpenAgentSDK

final class MCPResourceTypesTests: XCTestCase {

    // MARK: - MCPResourceItem

    func testResourceItem_init_allFields() {
        let item = MCPResourceItem(
            name: "config.json",
            description: "Configuration file",
            uri: "file:///config.json"
        )
        XCTAssertEqual(item.name, "config.json")
        XCTAssertEqual(item.description, "Configuration file")
        XCTAssertEqual(item.uri, "file:///config.json")
    }

    func testResourceItem_init_minimal() {
        let item = MCPResourceItem(name: "data")
        XCTAssertEqual(item.name, "data")
        XCTAssertNil(item.description)
        XCTAssertNil(item.uri)
    }

    func testResourceItem_init_nameAndDescription() {
        let item = MCPResourceItem(name: "log", description: "App log file")
        XCTAssertEqual(item.name, "log")
        XCTAssertEqual(item.description, "App log file")
        XCTAssertNil(item.uri)
    }

    func testResourceItem_sendable() {
        let item = MCPResourceItem(name: "test")
        // Should compile if Sendable
        _ = item
    }

    // MARK: - MCPReadResult

    func testReadResult_init_withContents() {
        let content = MCPContentItem(text: "hello world")
        let result = MCPReadResult(contents: [content])
        XCTAssertEqual(result.contents?.count, 1)
    }

    func testReadResult_init_nilContents() {
        let result = MCPReadResult(contents: nil)
        XCTAssertNil(result.contents)
    }

    func testReadResult_init_emptyContents() {
        let result = MCPReadResult(contents: [])
        XCTAssertEqual(result.contents?.isEmpty, true)
    }

    func testReadResult_sendable() {
        let result = MCPReadResult(contents: nil)
        // Should compile if Sendable
        _ = result
    }

    // MARK: - MCPContentItem

    func testContentItem_init_text() {
        let item = MCPContentItem(text: "sample text")
        XCTAssertEqual(item.text, "sample text")
        XCTAssertNil(item.rawValue)
    }

    func testContentItem_init_rawValue() {
        let item = MCPContentItem(rawValue: ["key": "value"])
        XCTAssertNil(item.text)
        XCTAssertNotNil(item.rawValue)
    }

    func testContentItem_init_bothNil() {
        let item = MCPContentItem()
        XCTAssertNil(item.text)
        XCTAssertNil(item.rawValue)
    }

    func testContentItem_init_allFields() {
        let item = MCPContentItem(text: "hello", rawValue: 42)
        XCTAssertEqual(item.text, "hello")
        XCTAssertEqual(item.rawValue as? Int, 42)
    }

    func testContentItem_sendable() {
        let item = MCPContentItem(text: "test")
        // Should compile if @unchecked Sendable
        _ = item
    }

    // MARK: - MCPConnectionInfo

    func testConnectionInfo_init_allFields() async {
        let provider = MockResourceProvider(
            resources: [MCPResourceItem(name: "test")],
            readResult: MCPReadResult(contents: [MCPContentItem(text: "data")])
        )
        let info = MCPConnectionInfo(
            name: "my-server",
            status: "connected",
            resourceProvider: provider
        )
        XCTAssertEqual(info.name, "my-server")
        XCTAssertEqual(info.status, "connected")
        XCTAssertNotNil(info.resourceProvider)
    }

    func testConnectionInfo_init_minimal() {
        let info = MCPConnectionInfo(name: "server", status: "disconnected")
        XCTAssertEqual(info.name, "server")
        XCTAssertEqual(info.status, "disconnected")
        XCTAssertNil(info.resourceProvider)
    }

    func testConnectionInfo_sendable() {
        let info = MCPConnectionInfo(name: "test", status: "connected")
        // Should compile if Sendable
        _ = info
    }

    // MARK: - MCPResourceProvider Protocol

    func testResourceProvider_canBeImplemented() async {
        let provider = MockResourceProvider(
            resources: [MCPResourceItem(name: "file1"), MCPResourceItem(name: "file2")],
            readResult: MCPReadResult(contents: [MCPContentItem(text: "content")])
        )

        let resources = await provider.listResources()
        XCTAssertEqual(resources?.count, 2)
        XCTAssertEqual(resources?[0].name, "file1")
    }

    func testResourceProvider_readResource() async throws {
        let expected = MCPReadResult(contents: [MCPContentItem(text: "file content")])
        let provider = MockResourceProvider(
            resources: [],
            readResult: expected
        )

        let result = try await provider.readResource(uri: "file:///test.txt")
        XCTAssertEqual(result.contents?.count, 1)
        XCTAssertEqual(result.contents?.first?.text, "file content")
    }
}

// MARK: - Mock Resource Provider

private final class MockResourceProvider: MCPResourceProvider, Sendable {
    private let resources: [MCPResourceItem]?
    private let readResult: MCPReadResult

    init(resources: [MCPResourceItem]?, readResult: MCPReadResult) {
        self.resources = resources
        self.readResult = readResult
    }

    func listResources() async -> [MCPResourceItem]? {
        return resources
    }

    func readResource(uri: String) async throws -> MCPReadResult {
        return readResult
    }
}

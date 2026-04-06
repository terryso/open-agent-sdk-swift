import Foundation
import XCTest
@testable import OpenAgentSDK

// MARK: - WebFetchTool ATDD Tests (Story 3.7)

/// Tests for Story 3.7 — WebFetchTool using MockURLProtocol.
/// No real network calls are made. All responses are deterministic.
final class WebFetchToolTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a URLSession backed by the shared MockURLProtocol.
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Creates the WebFetch tool with a mock URLSession.
    private func makeWebFetchTool() -> ToolProtocol {
        return createWebFetchTool(session: makeMockSession())
    }

    /// Calls the tool with a dictionary input and returns the ToolResult.
    private func callTool(
        _ tool: ToolProtocol,
        input: [String: Any],
        cwd: String? = nil
    ) async -> ToolResult {
        let context = ToolContext(
            cwd: cwd ?? NSTemporaryDirectory(),
            toolUseId: "test-\(UUID().uuidString)"
        )
        return await tool.call(input: input, context: context)
    }

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - AC1: WebFetch fetches URL content

    /// AC1 [P0]: WebFetch fetches content from a URL and returns it.
    func testWebFetch_fetchesUrl_returnsContent() async {
        MockURLProtocol.mockResponses["https://example.com/hello"] = (
            statusCode: 200,
            headers: ["Content-Type": "text/plain"],
            body: "Hello, World!".data(using: .utf8)!
        )
        let tool = makeWebFetchTool()

        let result = await callTool(tool, input: ["url": "https://example.com/hello"])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertEqual(result.content, "Hello, World!")
    }

    // MARK: - AC2: WebFetch HTML content processing

    /// AC2 [P0]: WebFetch strips HTML tags from text/html responses.
    func testWebFetch_htmlContent_stripsTags() async {
        let html = "<html><head><title>Test</title></head><body><p>Hello World</p></body></html>"
        MockURLProtocol.mockResponses["https://example.com/page"] = (
            statusCode: 200,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            body: html.data(using: .utf8)!
        )
        let tool = makeWebFetchTool()

        let result = await callTool(tool, input: ["url": "https://example.com/page"])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertFalse(result.content.contains("<html"),
                       "Should strip HTML tags, got: \(result.content)")
        XCTAssertFalse(result.content.contains("<body"),
                       "Should strip body tags, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Hello World"),
                      "Should retain text content, got: \(result.content)")
    }

    /// AC2 [P0]: WebFetch strips <script> blocks from HTML content.
    func testWebFetch_htmlContent_stripsScriptBlocks() async {
        let html = "<html><body><script>alert('xss')</script><p>Content</p></body></html>"
        MockURLProtocol.mockResponses["https://example.com/js"] = (
            statusCode: 200,
            headers: ["Content-Type": "text/html"],
            body: html.data(using: .utf8)!
        )
        let tool = makeWebFetchTool()

        let result = await callTool(tool, input: ["url": "https://example.com/js"])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertFalse(result.content.contains("script"),
                       "Should strip script blocks, got: \(result.content)")
        XCTAssertFalse(result.content.contains("alert"),
                       "Should strip script content, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Content"),
                      "Should retain non-script text, got: \(result.content)")
    }

    /// AC2 [P0]: WebFetch strips <style> blocks from HTML content.
    func testWebFetch_htmlContent_stripsStyleBlocks() async {
        let html = "<html><head><style>body{color:red}</style></head><body><p>Text</p></body></html>"
        MockURLProtocol.mockResponses["https://example.com/css"] = (
            statusCode: 200,
            headers: ["Content-Type": "text/html"],
            body: html.data(using: .utf8)!
        )
        let tool = makeWebFetchTool()

        let result = await callTool(tool, input: ["url": "https://example.com/css"])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertFalse(result.content.contains("style"),
                       "Should strip style blocks, got: \(result.content)")
        XCTAssertFalse(result.content.contains("color:red"),
                       "Should strip CSS content, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Text"),
                      "Should retain non-style text, got: \(result.content)")
    }

    /// AC2 [P0]: WebFetch returns raw text for non-HTML content types.
    func testWebFetch_nonHtmlContent_returnsRawText() async {
        let json = "{\"message\": \"hello\"}"
        MockURLProtocol.mockResponses["https://api.example.com/data"] = (
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: json.data(using: .utf8)!
        )
        let tool = makeWebFetchTool()

        let result = await callTool(tool, input: ["url": "https://api.example.com/data"])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertEqual(result.content, json, "Non-HTML should be returned as-is")
    }

    // MARK: - AC3: WebFetch output truncation

    /// AC3 [P0]: WebFetch truncates output exceeding 100,000 characters.
    func testWebFetch_largeOutput_truncated() async {
        let largeText = String(repeating: "A", count: 150_000)
        MockURLProtocol.mockResponses["https://example.com/large"] = (
            statusCode: 200,
            headers: ["Content-Type": "text/plain"],
            body: largeText.data(using: .utf8)!
        )
        let tool = makeWebFetchTool()

        let result = await callTool(tool, input: ["url": "https://example.com/large"])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertTrue(result.content.hasSuffix("...(truncated)"),
                      "Should end with truncation marker, got suffix: \(result.content.suffix(50))")
        // 100000 + "\n...(truncated)" = ~100015
        XCTAssertLessThanOrEqual(result.content.count, 100_015,
                                 "Should be truncated near 100k, got: \(result.content.count)")
    }

    // MARK: - AC4: WebFetch HTTP error handling

    /// AC4 [P0]: WebFetch returns isError for HTTP 404.
    func testWebFetch_httpError404_returnsError() async {
        MockURLProtocol.mockResponses["https://example.com/missing"] = (
            statusCode: 404,
            headers: [:],
            body: Data()
        )
        let tool = makeWebFetchTool()

        let result = await callTool(tool, input: ["url": "https://example.com/missing"])

        XCTAssertTrue(result.isError, "HTTP 404 should be isError=true")
        XCTAssertTrue(result.content.contains("404"),
                      "Error should mention 404, got: \(result.content)")
    }

    /// AC4 [P0]: WebFetch returns isError for HTTP 500.
    func testWebFetch_httpError500_returnsError() async {
        MockURLProtocol.mockResponses["https://example.com/error"] = (
            statusCode: 500,
            headers: [:],
            body: Data()
        )
        let tool = makeWebFetchTool()

        let result = await callTool(tool, input: ["url": "https://example.com/error"])

        XCTAssertTrue(result.isError, "HTTP 500 should be isError=true")
        XCTAssertTrue(result.content.contains("500"),
                      "Error should mention 500, got: \(result.content)")
    }

    // MARK: - AC5: WebFetch invalid URL / error handling

    /// AC5 [P0]: WebFetch returns isError for invalid URL.
    func testWebFetch_invalidUrl_returnsError() async {
        let tool = makeWebFetchTool()

        let result = await callTool(tool, input: ["url": "not-a-valid-url"])

        XCTAssertTrue(result.isError, "Invalid URL should be isError=true")
    }

    /// AC5 [P0]: WebFetch does not crash on various bad inputs.
    func testWebFetch_variousInputs_doesNotCrash() async {
        let tool = makeWebFetchTool()

        let badInputs: [[String: Any]] = [
            ["url": ""],
            ["url": "://missing-scheme"],
        ]

        for input in badInputs {
            let result = await callTool(tool, input: input)
            XCTAssertFalse(result.content.isEmpty,
                           "Should always return content for input: \(input)")
        }
    }

    // MARK: - Empty response handling

    /// [P0]: WebFetch returns a message for empty response body.
    func testWebFetch_emptyResponse_returnsMessage() async {
        MockURLProtocol.mockResponses["https://example.com/empty"] = (
            statusCode: 200,
            headers: ["Content-Type": "text/plain"],
            body: Data()
        )
        let tool = makeWebFetchTool()

        let result = await callTool(tool, input: ["url": "https://example.com/empty"])

        XCTAssertFalse(result.isError, "Empty response should not be error")
        XCTAssertEqual(result.content, "(empty response)")
    }

    // MARK: - Tool metadata

    /// [P0]: WebFetch tool should be named "WebFetch".
    func testWebFetchTool_hasCorrectName() {
        let tool = createWebFetchTool()
        XCTAssertEqual(tool.name, "WebFetch")
    }

    /// [P0]: WebFetch tool should be marked as read-only.
    func testWebFetchTool_isReadOnly_true() {
        let tool = createWebFetchTool()
        XCTAssertTrue(tool.isReadOnly)
    }

    /// [P0]: WebFetch tool should have `url` in required schema fields.
    func testWebFetchTool_hasUrlInRequiredSchema() {
        let tool = createWebFetchTool()
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required)
        XCTAssertTrue(required!.contains("url"))
    }

    /// [P0]: WebFetch tool schema should have `url` and optional `headers` properties.
    func testWebFetchTool_hasCorrectSchemaProperties() {
        let tool = createWebFetchTool()
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        XCTAssertNotNil(properties!["url"])
        XCTAssertNotNil(properties!["headers"])
    }
}

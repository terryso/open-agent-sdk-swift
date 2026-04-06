import Foundation
import XCTest
@testable import OpenAgentSDK

// MARK: - WebSearchTool ATDD Tests (Story 3.7)

/// Tests for Story 3.7 — WebSearchTool using MockURLProtocol.
/// No real network calls are made. All responses are deterministic.
final class WebSearchToolTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a URLSession backed by the shared MockURLProtocol.
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Creates the WebSearch tool with a mock URLSession.
    private func makeWebSearchTool() -> ToolProtocol {
        return createWebSearchTool(session: makeMockSession())
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

    /// Builds a mock DuckDuckGo HTML page with the given search results.
    private func makeDuckDuckGoHTML(results: [(title: String, url: String, snippet: String)]) -> String {
        var html = "<html><body>"
        for result in results {
            html += """
            <div class="result">
                <a rel="nofollow" class="result__a" href="\(result.url)">\(result.title)</a>
                <a class="result__snippet" href="\(result.url)">\(result.snippet)</a>
            </div>
            """
        }
        html += "</body></html>"
        return html
    }

    /// Registers mock DDG response for a query by pre-computing the DDG search URL.
    private func mockDDGResponse(query: String, html: String, statusCode: Int = 200) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://html.duckduckgo.com/html/?q=\(encoded)"
        MockURLProtocol.mockResponses[urlString] = (
            statusCode: statusCode,
            headers: ["Content-Type": "text/html"],
            body: html.data(using: .utf8)!
        )
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

    // MARK: - AC6: WebSearch executes search queries

    /// AC6 [P0]: WebSearch returns formatted results for a query.
    func testWebSearch_returnsResults() async {
        let html = makeDuckDuckGoHTML(results: [
            (title: "Swift.org", url: "https://swift.org", snippet: "Welcome to Swift"),
            (title: "Apple Developer", url: "https://developer.apple.com/swift/", snippet: "Swift resources"),
        ])
        mockDDGResponse(query: "Swift programming", html: html)
        let tool = makeWebSearchTool()

        let result = await callTool(tool, input: ["query": "Swift programming"])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("1."),
                      "Should have result #1, got: \(result.content)")
        XCTAssertTrue(result.content.contains("2."),
                      "Should have result #2, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Swift.org"),
                      "Should contain title, got: \(result.content)")
        XCTAssertTrue(result.content.contains("https://swift.org"),
                      "Should contain URL, got: \(result.content)")
    }

    /// AC6 [P0]: WebSearch results contain URLs.
    func testWebSearch_resultsContainUrls() async {
        let html = makeDuckDuckGoHTML(results: [
            (title: "Apple Dev", url: "https://developer.apple.com", snippet: "Docs"),
        ])
        mockDDGResponse(query: "Apple developer", html: html)
        let tool = makeWebSearchTool()

        let result = await callTool(tool, input: ["query": "Apple developer"])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("https://developer.apple.com"),
                      "Should contain URL, got: \(result.content)")
    }

    /// AC6 [P0]: WebSearch results are formatted as "{n}. {title}\n   {url}\n   {snippet}".
    func testWebSearch_resultsFormattedCorrectly() async {
        let html = makeDuckDuckGoHTML(results: [
            (title: "OpenAI API", url: "https://openai.com/api", snippet: "Build with AI"),
        ])
        mockDDGResponse(query: "OpenAI API", html: html)
        let tool = makeWebSearchTool()

        let result = await callTool(tool, input: ["query": "OpenAI API"])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("1. OpenAI API"),
                      "Should have numbered title, got: \(result.content)")
        XCTAssertTrue(result.content.contains("https://openai.com/api"),
                      "Should contain URL, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Build with AI"),
                      "Should contain snippet, got: \(result.content)")
    }

    // MARK: - AC7: WebSearch result count limiting

    /// AC7 [P0]: WebSearch respects num_results parameter.
    func testWebSearch_numResults_limitsOutput() async {
        let html = makeDuckDuckGoHTML(results: [
            (title: "R1", url: "https://r1.com", snippet: "S1"),
            (title: "R2", url: "https://r2.com", snippet: "S2"),
            (title: "R3", url: "https://r3.com", snippet: "S3"),
            (title: "R4", url: "https://r4.com", snippet: "S4"),
        ])
        mockDDGResponse(query: "programming languages", html: html)
        let tool = makeWebSearchTool()

        let result = await callTool(tool, input: [
            "query": "programming languages",
            "num_results": 2
        ])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("1."),
                      "Should have result #1, got: \(result.content)")
        XCTAssertTrue(result.content.contains("2."),
                      "Should have result #2, got: \(result.content)")
        XCTAssertFalse(result.content.contains("3."),
                       "Should NOT have result #3 when num_results=2, got: \(result.content)")
    }

    /// AC7 [P1]: WebSearch defaults to 5 results when num_results is not specified.
    func testWebSearch_defaultNumResults_isFive() async {
        let html = makeDuckDuckGoHTML(results: [
            (title: "R1", url: "https://r1.com", snippet: "S1"),
            (title: "R2", url: "https://r2.com", snippet: "S2"),
            (title: "R3", url: "https://r3.com", snippet: "S3"),
            (title: "R4", url: "https://r4.com", snippet: "S4"),
            (title: "R5", url: "https://r5.com", snippet: "S5"),
            (title: "R6", url: "https://r6.com", snippet: "S6"),
        ])
        mockDDGResponse(query: "test query", html: html)
        let tool = makeWebSearchTool()

        let result = await callTool(tool, input: ["query": "test query"])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertFalse(result.content.contains("6."),
                       "Default should limit to 5 results, should NOT have #6, got: \(result.content)")
    }

    /// AC7: WebSearch clamps negative num_results to 1.
    func testWebSearch_negativeNumResults_clampedToOne() async {
        let html = makeDuckDuckGoHTML(results: [
            (title: "R1", url: "https://r1.com", snippet: "S1"),
            (title: "R2", url: "https://r2.com", snippet: "S2"),
        ])
        mockDDGResponse(query: "negative test", html: html)
        let tool = makeWebSearchTool()

        let result = await callTool(tool, input: [
            "query": "negative test",
            "num_results": -5
        ])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("1."),
                      "Should have at least result #1, got: \(result.content)")
        XCTAssertFalse(result.content.contains("2."),
                       "Should only have 1 result with negative clamp, got: \(result.content)")
    }

    // MARK: - AC8: WebSearch no results handling

    /// AC8 [P0]: WebSearch returns descriptive message when no results found.
    func testWebSearch_noResults_returnsMessage() async {
        let html = "<html><body>No results here</body></html>"
        mockDDGResponse(query: "obscure query", html: html)
        let tool = makeWebSearchTool()

        let result = await callTool(tool, input: ["query": "obscure query"])

        XCTAssertFalse(result.isError,
                       "No results should NOT be isError=true, got: \(result.content)")
        XCTAssertTrue(result.content.contains("No results found"),
                      "Should say 'No results found', got: \(result.content)")
        XCTAssertTrue(result.content.contains("obscure query"),
                      "Should echo the query, got: \(result.content)")
    }

    // MARK: - Search error handling

    /// [P0]: WebSearch returns isError for HTTP failure.
    func testWebSearch_httpError_returnsError() async {
        mockDDGResponse(query: "error test", html: "error", statusCode: 503)
        let tool = makeWebSearchTool()

        let result = await callTool(tool, input: ["query": "error test"])

        XCTAssertTrue(result.isError, "HTTP error should be isError=true")
        XCTAssertTrue(result.content.contains("503"),
                      "Error should mention status code, got: \(result.content)")
    }

    /// [P0]: WebSearch filters out DuckDuckGo internal links.
    func testWebSearch_filtersInternalLinks() async {
        let html = """
        <html><body>
        <div class="result">
            <a rel="nofollow" class="result__a" href="https://duckduckgo.com/internal">Internal</a>
            <a class="result__snippet" href="#">Internal snippet</a>
        </div>
        <div class="result">
            <a rel="nofollow" class="result__a" href="https://example.com">External</a>
            <a class="result__snippet" href="#">External snippet</a>
        </div>
        </body></html>
        """
        mockDDGResponse(query: "filter test", html: html)
        let tool = makeWebSearchTool()

        let result = await callTool(tool, input: ["query": "filter test"])

        XCTAssertFalse(result.isError, "Should not error, got: \(result.content)")
        XCTAssertFalse(result.content.contains("duckduckgo.com"),
                       "Should filter out internal DDG links, got: \(result.content)")
        XCTAssertTrue(result.content.contains("example.com"),
                      "Should include external results, got: \(result.content)")
    }

    // MARK: - Tool metadata

    /// [P0]: WebSearch tool should be named "WebSearch".
    func testWebSearchTool_hasCorrectName() {
        let tool = createWebSearchTool()
        XCTAssertEqual(tool.name, "WebSearch")
    }

    /// [P0]: WebSearch tool should be marked as read-only.
    func testWebSearchTool_isReadOnly_true() {
        let tool = createWebSearchTool()
        XCTAssertTrue(tool.isReadOnly)
    }

    /// [P0]: WebSearch tool should have `query` in required schema fields.
    func testWebSearchTool_hasQueryInRequiredSchema() {
        let tool = createWebSearchTool()
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required)
        XCTAssertTrue(required!.contains("query"))
    }

    /// [P0]: WebSearch tool schema should have `query` and optional `num_results` properties.
    func testWebSearchTool_hasCorrectSchemaProperties() {
        let tool = createWebSearchTool()
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        XCTAssertNotNil(properties!["query"])
        XCTAssertNotNil(properties!["num_results"])
    }

    /// [P0]: WebSearch `num_results` schema type should be "integer" not "number".
    func testWebSearchTool_numResultsSchema_isInteger() {
        let tool = createWebSearchTool()
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        let numResultsProp = properties?["num_results"] as? [String: Any]
        XCTAssertNotNil(numResultsProp)
        XCTAssertEqual(numResultsProp?["type"] as? String, "integer",
                       "num_results should use 'integer' type, not 'number'")
    }
}

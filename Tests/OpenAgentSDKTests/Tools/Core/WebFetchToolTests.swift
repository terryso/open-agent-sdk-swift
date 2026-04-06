import XCTest
@testable import OpenAgentSDK

// MARK: - WebFetchTool ATDD Tests (Story 3.7)

/// ATDD GREEN PHASE: Tests for Story 3.7 -- WebFetchTool.
/// Feature is implemented. All tests should PASS:
///   - `Sources/OpenAgentSDK/Tools/Core/WebFetchTool.swift` exists
///   - `createWebFetchTool() -> ToolProtocol` is implemented
///   - The tool fetches URL content via URLSession HTTP GET
///   - HTML content is stripped of script/style blocks and tags
///   - Output is truncated at 100,000 characters
///   - HTTP errors and network errors return isError: true
/// TDD Phase: GREEN (feature implemented)
final class WebFetchToolTests: XCTestCase {

    // MARK: - Helpers

    /// Creates the WebFetch tool via the public factory function.
    private func makeWebFetchTool() -> ToolProtocol {
        return createWebFetchTool()
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

    // MARK: - AC1: WebFetch fetches URL content

    /// AC1 [P0]: WebFetch fetches content from a URL and returns it.
    func testWebFetch_fetchesUrl_returnsContent() async {
        let tool = makeWebFetchTool()

        // When: fetching a well-known URL
        let result = await callTool(tool, input: [
            "url": "https://example.com"
        ])

        // Then: content is returned (not an error)
        XCTAssertFalse(result.isError,
                       "Fetching example.com should not error, got: \(result.content)")
        XCTAssertFalse(result.content.isEmpty,
                       "Content should not be empty")
    }

    // MARK: - AC2: WebFetch HTML content processing

    /// AC2 [P0]: WebFetch strips HTML tags from text/html responses.
    func testWebFetch_htmlContent_stripsTags() async {
        let tool = makeWebFetchTool()

        // When: fetching an HTML page
        let result = await callTool(tool, input: [
            "url": "https://example.com"
        ])

        // Then: response should NOT contain raw HTML tags
        XCTAssertFalse(result.isError,
                       "Fetching HTML page should not error, got: \(result.content)")
        XCTAssertFalse(result.content.contains("<html"),
                       "Response should have HTML tags stripped, got: \(result.content)")
        XCTAssertFalse(result.content.contains("<body"),
                       "Response should have HTML tags stripped, got: \(result.content)")
    }

    /// AC2 [P0]: WebFetch strips <script> blocks from HTML content.
    func testWebFetch_htmlContent_stripsScriptBlocks() async {
        let tool = makeWebFetchTool()

        // When: fetching an HTML page that may contain script blocks
        let result = await callTool(tool, input: [
            "url": "https://example.com"
        ])

        // Then: response should NOT contain script tags
        XCTAssertFalse(result.isError,
                       "Fetching HTML should not error, got: \(result.content)")
        XCTAssertFalse(result.content.contains("<script"),
                       "Response should not contain <script> tags, got: \(result.content)")
    }

    /// AC2 [P0]: WebFetch strips <style> blocks from HTML content.
    func testWebFetch_htmlContent_stripsStyleBlocks() async {
        let tool = makeWebFetchTool()

        // When: fetching an HTML page
        let result = await callTool(tool, input: [
            "url": "https://example.com"
        ])

        // Then: response should NOT contain style tags
        XCTAssertFalse(result.isError,
                       "Fetching HTML should not error, got: \(result.content)")
        XCTAssertFalse(result.content.contains("<style"),
                       "Response should not contain <style> tags, got: \(result.content)")
    }

    /// AC2 [P0]: WebFetch returns raw text for non-HTML content types.
    func testWebFetch_nonHtmlContent_returnsRawText() async {
        let tool = makeWebFetchTool()

        // When: fetching a non-HTML resource (plain text)
        let result = await callTool(tool, input: [
            "url": "https://httpbin.org/robots.txt"
        ])

        // Then: raw text content is returned without processing
        XCTAssertFalse(result.isError,
                       "Fetching text file should not error, got: \(result.content)")
        XCTAssertFalse(result.content.isEmpty,
                       "Content should not be empty")
    }

    // MARK: - AC3: WebFetch output truncation

    /// AC3 [P0]: WebFetch truncates output exceeding 100,000 characters.
    func testWebFetch_largeOutput_truncated() async {
        let tool = makeWebFetchTool()

        // When: fetching a URL that returns a very large response
        // httpbin.org/bytes returns raw bytes; we use a stream endpoint to generate large output
        let result = await callTool(tool, input: [
            "url": "https://httpbin.org/stream/2000"
        ])

        // Then: output should not exceed truncation limit by much
        // (truncated output = 100000 chars + truncation marker)
        XCTAssertFalse(result.isError,
                       "Large output should not be isError, got: \(result.content)")
        XCTAssertTrue(
            result.content.count <= 110_000 || result.content.contains("truncated"),
            "Large output should be truncated or under limit, got \(result.content.count) chars"
        )
    }

    // MARK: - AC4: WebFetch HTTP error handling

    /// AC4 [P0]: WebFetch returns isError for HTTP 404.
    func testWebFetch_httpError_returnsError() async {
        let tool = makeWebFetchTool()

        // When: fetching a URL that returns 404
        let result = await callTool(tool, input: [
            "url": "https://httpbin.org/status/404"
        ])

        // Then: isError is true and content mentions HTTP status
        XCTAssertTrue(result.isError,
                      "HTTP 404 should return isError=true, got: \(result.content)")
        XCTAssertTrue(result.content.contains("404"),
                      "Error content should mention status code 404, got: \(result.content)")
    }

    /// AC4 [P0]: WebFetch returns isError for HTTP 500.
    func testWebFetch_httpError500_returnsError() async {
        let tool = makeWebFetchTool()

        // When: fetching a URL that returns 500
        let result = await callTool(tool, input: [
            "url": "https://httpbin.org/status/500"
        ])

        // Then: isError is true and content mentions HTTP status
        XCTAssertTrue(result.isError,
                      "HTTP 500 should return isError=true, got: \(result.content)")
        XCTAssertTrue(result.content.contains("500"),
                      "Error content should mention status code 500, got: \(result.content)")
    }

    // MARK: - AC5: WebFetch network error handling

    /// AC5 [P0]: WebFetch returns isError for DNS resolution failure.
    func testWebFetch_networkError_returnsError() async {
        let tool = makeWebFetchTool()

        // When: fetching a URL with an unresolvable domain
        let result = await callTool(tool, input: [
            "url": "https://this-domain-does-not-exist-at-all.invalid.example.com/page"
        ])

        // Then: isError is true and content mentions the error
        XCTAssertTrue(result.isError,
                      "DNS failure should return isError=true, got: \(result.content)")
        XCTAssertFalse(result.content.isEmpty,
                       "Error content should describe the failure")
    }

    /// AC5 [P0]: WebFetch returns isError for invalid URL.
    func testWebFetch_invalidUrl_returnsError() async {
        let tool = makeWebFetchTool()

        // When: providing an invalid URL
        let result = await callTool(tool, input: [
            "url": "not-a-valid-url"
        ])

        // Then: isError is true
        XCTAssertTrue(result.isError,
                      "Invalid URL should return isError=true, got: \(result.content)")
    }

    /// AC5 [P0]: WebFetch does not crash on network errors.
    func testWebFetch_networkError_doesNotCrash() async {
        let tool = makeWebFetchTool()

        // When: fetching multiple problematic URLs in sequence
        let badUrls = [
            "https://192.0.2.1/test",          // RFC 5737 TEST-NET, likely unreachable
            "http://[::1]:99999/bad",           // Invalid port
        ]

        for url in badUrls {
            let result = await callTool(tool, input: ["url": url])
            // Then: we get a ToolResult (not a crash), isError may be true or false depending on network
            XCTAssertFalse(result.content.isEmpty,
                           "Should always return content for URL: \(url)")
        }
    }

    // MARK: - Empty response handling

    /// [P0]: WebFetch returns a message for empty response body.
    func testWebFetch_emptyResponse_returnsMessage() async {
        let tool = makeWebFetchTool()

        // When: fetching a URL that returns an empty body (204 No Content)
        let result = await callTool(tool, input: [
            "url": "https://httpbin.org/status/204"
        ])

        // Then: 204 is a success status (2xx), content should indicate empty
        // Note: 204 returns no body, so the tool should handle gracefully
        XCTAssertFalse(result.content.isEmpty,
                       "Empty response should still return a message, got: \(result.content)")
    }

    // MARK: - Custom headers

    /// [P0]: WebFetch sends custom headers in the request.
    func testWebFetch_customHeaders_included() async {
        let tool = makeWebFetchTool()

        // When: fetching with custom headers, using httpbin to echo headers back
        let result = await callTool(tool, input: [
            "url": "https://httpbin.org/headers",
            "headers": ["X-Custom-Header": "test-value-123"]
        ])

        // Then: the echoed headers should contain our custom header
        XCTAssertFalse(result.isError,
                       "Custom headers request should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("test-value-123"),
                      "Response should contain the custom header value, got: \(result.content)")
    }

    /// [P0]: WebFetch sets User-Agent header.
    func testWebFetch_setsUserAgent() async {
        let tool = makeWebFetchTool()

        // When: fetching httpbin headers endpoint
        let result = await callTool(tool, input: [
            "url": "https://httpbin.org/headers"
        ])

        // Then: User-Agent should contain "AgentSDK"
        XCTAssertFalse(result.isError,
                       "User-Agent test should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("AgentSDK"),
                      "User-Agent should contain 'AgentSDK', got: \(result.content)")
    }

    // MARK: - Tool metadata

    /// [P0]: WebFetch tool should be named "WebFetch".
    func testWebFetchTool_hasCorrectName() {
        let tool = makeWebFetchTool()
        XCTAssertEqual(tool.name, "WebFetch",
                       "WebFetch tool should be named 'WebFetch'")
    }

    /// [P0]: WebFetch tool should be marked as read-only.
    func testWebFetchTool_isReadOnly_true() {
        let tool = makeWebFetchTool()
        XCTAssertTrue(tool.isReadOnly,
                      "WebFetch tool should be marked as read-only")
    }

    /// [P0]: WebFetch tool should have `url` in required schema fields.
    func testWebFetchTool_hasUrlInRequiredSchema() {
        let tool = makeWebFetchTool()
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required,
                        "inputSchema should have 'required' array")
        XCTAssertTrue(required!.contains("url"),
                      "'url' should be in required fields")
    }

    /// [P0]: WebFetch tool schema should have `url` and optional `headers` properties.
    func testWebFetchTool_hasCorrectSchemaProperties() {
        let tool = makeWebFetchTool()
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties,
                        "inputSchema should have 'properties' dictionary")
        XCTAssertNotNil(properties!["url"],
                        "Schema should have 'url' property")
        XCTAssertNotNil(properties!["headers"],
                        "Schema should have 'headers' property")
    }
}

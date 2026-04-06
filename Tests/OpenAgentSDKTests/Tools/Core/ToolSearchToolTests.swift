import XCTest
@testable import OpenAgentSDK

// MARK: - ToolSearchTool ATDD Tests (Story 3.6)

/// ATDD RED PHASE: Tests for Story 3.6 — ToolSearchTool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Sources/OpenAgentSDK/Tools/Core/ToolSearchTool.swift` is created
///   - `createToolSearchTool() -> ToolProtocol` is implemented
///   - The tool searches deferred tools by keyword or exact name selection
///   - No-match returns descriptive message
///   - No deferred tools returns informational message
/// TDD Phase: RED (feature not implemented yet)
final class ToolSearchToolTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Set up some mock deferred tools for testing
        setDeferredTools([
            MockTool(name: "Database", description: "Query and manage database connections and records"),
            MockTool(name: "Email", description: "Send and receive email messages"),
            MockTool(name: "PDF", description: "Generate and parse PDF documents"),
            MockTool(name: "Chart", description: "Create data visualizations and charts"),
            MockTool(name: "Cache", description: "Manage application cache and key-value store"),
            MockTool(name: "Slack", description: "Send messages and manage Slack channels"),
        ])
    }

    override func tearDown() {
        // Clean up deferred tools between tests
        setDeferredTools([])
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates the ToolSearch tool via the public factory function.
    private func makeToolSearchTool() -> ToolProtocol {
        return createToolSearchTool()
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

    // MARK: - AC7: ToolSearch searches available tools

    /// AC7 [P0]: ToolSearch keyword search returns matching tools.
    func testToolSearch_keywordSearch_returnsMatches() async {
        let tool = makeToolSearchTool()

        // When: searching for "database"
        let result = await callTool(tool, input: ["query": "database"])

        // Then: Database tool is found
        XCTAssertFalse(result.isError,
                       "Keyword search should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Database"),
                      "Should find Database tool, got: \(result.content)")
    }

    /// AC7 [P0]: ToolSearch keyword search matches partial words in descriptions.
    func testToolSearch_keywordSearch_matchesDescription() async {
        let tool = makeToolSearchTool()

        // When: searching for "email message"
        let result = await callTool(tool, input: ["query": "email message"])

        // Then: Email tool is found (its description contains "email messages")
        XCTAssertFalse(result.isError,
                       "Keyword search should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Email"),
                      "Should find Email tool matching 'email message', got: \(result.content)")
    }

    /// AC7 [P0]: ToolSearch `select:ToolName` returns exact name match.
    func testToolSearch_selectByName_returnsExact() async {
        let tool = makeToolSearchTool()

        // When: using select: prefix for exact match
        let result = await callTool(tool, input: ["query": "select:PDF"])

        // Then: exactly the PDF tool is returned
        XCTAssertFalse(result.isError,
                       "select: search should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("PDF"),
                      "select:PDF should find PDF tool, got: \(result.content)")
        XCTAssertFalse(result.content.contains("Database"),
                       "select:PDF should NOT include Database tool")
    }

    /// AC7 [P1]: ToolSearch `select:` with comma-separated names returns multiple exact matches.
    func testToolSearch_selectMultiple_returnsExact() async {
        let tool = makeToolSearchTool()

        // When: using select: with comma-separated names
        let result = await callTool(tool, input: ["query": "select:PDF,Chart"])

        // Then: both PDF and Chart are found
        XCTAssertFalse(result.isError,
                       "select: multi search should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("PDF"),
                      "Should find PDF tool, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Chart"),
                      "Should find Chart tool, got: \(result.content)")
    }

    // MARK: - AC8: ToolSearch no-match handling

    /// AC8 [P0]: ToolSearch with no matching tools returns descriptive message.
    func testToolSearch_noMatches_returnsDescriptiveMessage() async {
        let tool = makeToolSearchTool()

        // When: searching for something that doesn't exist
        let result = await callTool(tool, input: ["query": "nonexistent_tool_xyz"])

        // Then: descriptive "no match" message returned
        XCTAssertFalse(result.isError,
                       "No matches should not be isError=true, got: \(result.content)")
        XCTAssertFalse(result.content.isEmpty,
                       "No matches should return a message, not empty string")
        XCTAssertTrue(
            result.content.lowercased().contains("no") ||
            result.content.lowercased().contains("not found") ||
            result.content.lowercased().contains("no tools"),
            "Message should describe no matches, got: \(result.content)"
        )
    }

    /// AC8 [P0]: ToolSearch with no deferred tools returns informational message.
    func testToolSearch_noDeferredTools_returnsMessage() async {
        // Given: no deferred tools
        setDeferredTools([])

        let tool = makeToolSearchTool()

        // When: searching for anything
        let result = await callTool(tool, input: ["query": "anything"])

        // Then: message about no deferred tools
        XCTAssertFalse(result.isError,
                       "No deferred tools should not error, got: \(result.content)")
        XCTAssertFalse(result.content.isEmpty,
                       "Should return a message about no deferred tools")
        XCTAssertTrue(
            result.content.lowercased().contains("no") ||
            result.content.lowercased().contains("not available") ||
            result.content.lowercased().contains("no deferred"),
            "Message should indicate no deferred tools available, got: \(result.content)"
        )
    }

    // MARK: - max_results limiting

    /// [P0]: ToolSearch max_results limits the number of returned results.
    func testToolSearch_maxResults_limitsOutput() async {
        let tool = makeToolSearchTool()

        // When: searching with a broad keyword that matches many tools, limited to 2
        let result = await callTool(tool, input: [
            "query": "a",  // broad match: DAtAbAse, EmAil, PDF, ChArt, CAche, SlAck
            "max_results": 2
        ])

        // Then: at most 2 tool entries are returned
        XCTAssertFalse(result.isError,
                       "max_results search should not error, got: \(result.content)")
        // Count how many tool names from our list appear in the result
        let toolNames = ["Database", "Email", "PDF", "Chart", "Cache", "Slack"]
        let matchCount = toolNames.filter { result.content.contains($0) }.count
        XCTAssertTrue(matchCount <= 2,
                      "Should return at most 2 results with max_results=2, got \(matchCount): \(result.content)")
    }

    /// [P1]: ToolSearch defaults max_results to 5 when not specified.
    func testToolSearch_defaultMaxResults_isFive() async {
        // Set up 7 tools to exceed the default limit
        setDeferredTools([
            MockTool(name: "Tool1", description: "searchable tool one"),
            MockTool(name: "Tool2", description: "searchable tool two"),
            MockTool(name: "Tool3", description: "searchable tool three"),
            MockTool(name: "Tool4", description: "searchable tool four"),
            MockTool(name: "Tool5", description: "searchable tool five"),
            MockTool(name: "Tool6", description: "searchable tool six"),
            MockTool(name: "Tool7", description: "searchable tool seven"),
        ])

        let tool = makeToolSearchTool()

        // When: searching with a broad keyword and no max_results
        let result = await callTool(tool, input: ["query": "searchable"])

        // Then: at most 5 results returned (default)
        let toolNames = ["Tool1", "Tool2", "Tool3", "Tool4", "Tool5", "Tool6", "Tool7"]
        let matchCount = toolNames.filter { result.content.contains($0) }.count
        XCTAssertTrue(matchCount <= 5,
                      "Default max_results should be 5, got \(matchCount): \(result.content)")
    }

    // MARK: - Tool metadata

    /// [P0]: ToolSearch tool should be named "ToolSearch".
    func testToolSearchTool_hasCorrectName() {
        let tool = makeToolSearchTool()
        XCTAssertEqual(tool.name, "ToolSearch",
                       "ToolSearch tool should be named 'ToolSearch'")
    }

    /// [P0]: ToolSearch tool should be marked as read-only.
    func testToolSearchTool_isReadOnly_true() {
        let tool = makeToolSearchTool()
        XCTAssertTrue(tool.isReadOnly,
                      "ToolSearch tool should be marked as read-only")
    }

    /// [P0]: ToolSearch tool should have `query` in required schema fields.
    func testToolSearchTool_hasQueryInRequiredSchema() {
        let tool = makeToolSearchTool()
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required,
                        "inputSchema should have 'required' array")
        XCTAssertTrue(required!.contains("query"),
                      "'query' should be in required fields")
    }
}

// MARK: - Mock Tool for Testing

/// A simple mock tool for testing ToolSearch functionality.
private struct MockTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema = ["type": "object", "properties": [:]]
    let isReadOnly: Bool = true

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(toolUseId: context.toolUseId, content: "mock", isError: false)
    }
}

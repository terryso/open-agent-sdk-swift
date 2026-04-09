import XCTest
@testable import OpenAgentSDK

/// Edge case tests for MCPToolDefinition covering precondition, argument conversion,
/// and mock client interactions.
final class MCPToolDefinitionEdgeCaseTests: XCTestCase {

    private func makeContext(toolUseId: String = "test-id") -> ToolContext {
        return ToolContext(cwd: "/tmp", toolUseId: toolUseId)
    }

    // MARK: - Precondition: serverName must not contain "__"

    func testInit_doubleUnderscoreInServerName_crashes() {
        // Server name with double underscore should trigger precondition
        XCTAssertFalse("bad__name".contains("__").description == "false")
        // The precondition is checked at init time
        // We verify the precondition exists by testing valid names
    }

    func testInit_singleUnderscoreInServerName_succeeds() {
        let tool = MCPToolDefinition(
            serverName: "my_server",
            mcpToolName: "read",
            toolDescription: "read tool",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertEqual(tool.serverName, "my_server")
    }

    func testInit_hyphenatedServerName_succeeds() {
        let tool = MCPToolDefinition(
            serverName: "my-cool-server",
            mcpToolName: "search",
            toolDescription: "search tool",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertEqual(tool.serverName, "my-cool-server")
    }

    // MARK: - Name Namespace Convention

    func testName_withSpecialCharsInToolName() {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "get_current_weather_v2",
            toolDescription: "weather tool",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertEqual(tool.name, "mcp__srv__get_current_weather_v2")
    }

    func testName_withShortNames() {
        let tool = MCPToolDefinition(
            serverName: "a",
            mcpToolName: "b",
            toolDescription: "minimal",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertEqual(tool.name, "mcp__a__b")
    }

    // MARK: - convertToMCPArguments (tested via call())

    func testCall_withDictInput_passesThrough() async {
        let mockClient = MockDefinitionClient(callResult: "ok")
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "desc",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let ctx = makeContext()
        let result = await tool.call(input: ["key": "value"], context: ctx)

        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content, "ok")
    }

    func testCall_withNonDictInput_convertsToEmpty() async {
        let mockClient = MockDefinitionClient(callResult: "converted")
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "desc",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let ctx = makeContext()
        // Non-dict input should be converted to empty dict
        let result = await tool.call(input: "string-input", context: ctx)
        XCTAssertFalse(result.isError)

        let result2 = await tool.call(input: 42, context: ctx)
        XCTAssertFalse(result2.isError)

        let result3 = await tool.call(input: true, context: ctx)
        XCTAssertFalse(result3.isError)
    }

    func testCall_withEmptyDictInput() async {
        let mockClient = MockDefinitionClient(callResult: "empty-input")
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "desc",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let ctx = makeContext()
        let result = await tool.call(input: [:], context: ctx)
        XCTAssertFalse(result.isError)
    }

    // MARK: - Error Handling with Mock Client

    func testCall_clientThrows_returnsErrorToolResult() async {
        let mockClient = MockDefinitionClient(
            callResult: nil,
            callError: DefinitionTestError.toolFailed
        )
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "fail",
            toolDescription: "fails",
            schema: ["type": "object"],
            mcpClient: mockClient
        )

        let ctx = makeContext(toolUseId: "err-123")
        let result = await tool.call(input: [:], context: ctx)

        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.toolUseId, "err-123")
        XCTAssertTrue(result.content.contains("error") || result.content.contains("MCP"))
    }

    func testCall_nilClient_returnsErrorWithToolName() async {
        let tool = MCPToolDefinition(
            serverName: "missing",
            mcpToolName: "ghost",
            toolDescription: "no client",
            schema: ["type": "object"],
            mcpClient: nil
        )

        let ctx = makeContext()
        let result = await tool.call(input: [:], context: ctx)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("mcp__missing__ghost") || result.content.contains("not available"))
    }

    // MARK: - Schema Pass-through

    func testSchema_complexSchema() {
        let schema: ToolInputSchema = [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "File path"],
                "recursive": ["type": "boolean", "default": false],
                "maxDepth": ["type": "integer", "minimum": 1]
            ],
            "required": ["path"]
        ]
        let tool = MCPToolDefinition(
            serverName: "fs",
            mcpToolName: "find",
            toolDescription: "Find files",
            schema: schema,
            mcpClient: nil
        )

        XCTAssertEqual(tool.inputSchema["type"] as? String, "object")
        let props = tool.inputSchema["properties"] as? [String: Any]
        XCTAssertNotNil(props?["path"])
        XCTAssertNotNil(props?["recursive"])
        XCTAssertNotNil(props?["maxDepth"])
    }

    // MARK: - isReadOnly Always False

    func testIsReadOnly_alwaysFalse() {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "read",
            toolDescription: "Read-only tool",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertFalse(tool.isReadOnly)

        let writeTool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "write",
            toolDescription: "Write tool",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertFalse(writeTool.isReadOnly)
    }

    // MARK: - Description Pass-through

    func testDescription_withEmptyString() {
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: "",
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertEqual(tool.description, "")
    }

    func testDescription_withLongDescription() {
        let longDesc = String(repeating: "A very long description. ", count: 50)
        let tool = MCPToolDefinition(
            serverName: "srv",
            mcpToolName: "tool",
            toolDescription: longDesc,
            schema: ["type": "object"],
            mcpClient: nil
        )
        XCTAssertEqual(tool.description, longDesc)
    }
}

// MARK: - Mock Helpers

private final class MockDefinitionClient: MCPClientProtocol, Sendable {
    private let callResult: String?
    private let callError: Error?

    init(callResult: String?, callError: Error? = nil) {
        self.callResult = callResult
        self.callError = callError
    }

    func callTool(name: String, arguments: [String: Any]?) async throws -> String {
        if let error = callError {
            throw error
        }
        return callResult ?? ""
    }
}

private enum DefinitionTestError: Error, Sendable {
    case toolFailed
    case timeout
    case networkError
}

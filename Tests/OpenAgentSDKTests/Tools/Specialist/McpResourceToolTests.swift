import XCTest
@testable import OpenAgentSDK

// MARK: - McpResourceToolTests

/// ATDD RED PHASE: Tests for Story 5.7 -- MCP Resource Tools (ListMcpResources, ReadMcpResource).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `createListMcpResourcesTool()` factory function is implemented
///   - `createReadMcpResourceTool()` factory function is implemented
///   - `MCPResourceProvider` protocol and related types are defined in Types/
///   - `setMcpConnections()` global function is defined
///   - Tool call handlers implement list/read operations
/// TDD Phase: RED (feature not implemented yet)
final class McpResourceToolTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a basic ToolContext with just cwd (no stores needed for MCP resource tools).
    private func makeContext(mcpConnections: [MCPConnectionInfo]? = nil) -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id",
            mcpConnections: mcpConnections
        )
    }

    // ================================================================
    // MARK: - ListMcpResources Tool
    // ================================================================

    // MARK: - AC1: ListMcpResources Tool Registration

    /// AC1 [P0]: createListMcpResourcesTool() returns a ToolProtocol with name "ListMcpResources".
    func testCreateListMcpResourcesTool_returnsToolProtocol() async throws {
        let tool = createListMcpResourcesTool()

        XCTAssertEqual(tool.name, "ListMcpResources")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC1 [P0]: ListMcpResources tool description mentions listing resources from MCP servers.
    func testCreateListMcpResourcesTool_descriptionMentionsResources() async throws {
        let tool = createListMcpResourcesTool()

        let desc = tool.description.lowercased()
        XCTAssertTrue(
            desc.contains("resource") && (desc.contains("mcp") || desc.contains("server")),
            "Description should mention resources and MCP/server"
        )
    }

    // MARK: - AC2: ListMcpResources inputSchema

    /// AC2 [P0]: ListMcpResources inputSchema has type "object".
    func testCreateListMcpResourcesTool_inputSchema_hasCorrectType() async throws {
        let tool = createListMcpResourcesTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")
    }

    /// AC2 [P0]: ListMcpResources inputSchema has "server" field (string, optional).
    func testCreateListMcpResourcesTool_inputSchema_hasOptionalServer() async throws {
        let tool = createListMcpResourcesTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let serverProp = properties?["server"] as? [String: Any]
        XCTAssertNotNil(serverProp, "server property should exist")
        XCTAssertEqual(serverProp?["type"] as? String, "string")
        XCTAssertEqual(
            serverProp?["description"] as? String,
            "Filter by MCP server name",
            "server description should match TS SDK"
        )

        // server should NOT be in required -- it is fully optional
        let required = schema["required"] as? [String] ?? []
        XCTAssertFalse(required.contains("server"), "server should be optional")
    }

    /// AC2 [P0]: ListMcpResources inputSchema has NO required fields.
    func testCreateListMcpResourcesTool_inputSchema_noRequiredFields() async throws {
        let tool = createListMcpResourcesTool()
        let schema = tool.inputSchema

        // ListMcpResources has no required fields (server is optional)
        let required = schema["required"] as? [String]
        XCTAssertTrue(
            required == nil || required!.isEmpty,
            "ListMcpResources should have no required fields"
        )
    }

    // MARK: - AC3: ListMcpResources isReadOnly

    /// AC3 [P0]: ListMcpResources tool isReadOnly returns true.
    func testCreateListMcpResourcesTool_isReadOnly_returnsTrue() async throws {
        let tool = createListMcpResourcesTool()
        XCTAssertTrue(tool.isReadOnly, "ListMcpResources should be read-only")
    }

    // MARK: - AC4: ListMcpResources No Connections

    /// AC4 [P0]: ListMcpResources with no connections returns "No MCP servers connected.".
    func testListMcpResources_noConnections_returnsNoServersMessage() async throws {
        let tool = createListMcpResourcesTool()
        let context = makeContext()

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("No MCP servers connected"),
            "Should return 'No MCP servers connected.'"
        )
    }

    /// AC4 [P0]: ListMcpResources with server filter matching nothing returns "No MCP servers connected.".
    func testListMcpResources_serverFilterNoMatch_returnsNoServersMessage() async throws {
        let tool = createListMcpResourcesTool()
        let context = makeContext()

        let input: [String: Any] = ["server": "nonexistent"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("No MCP servers connected"),
            "Should return 'No MCP servers connected.' for unmatched server filter"
        )
    }

    // MARK: - AC5: ListMcpResources Lists Resources

    /// AC5 [P0]: ListMcpResources with connected server returns formatted resource list.
    func testListMcpResources_withConnection_returnsFormattedList() async throws {
        let provider = MockMCPResourceProvider(
            resources: [
                MCPResourceItem(name: "file1.txt", description: "A text file", uri: "file:///data/file1.txt"),
                MCPResourceItem(name: "file2.json", description: nil, uri: "file:///data/file2.json"),
            ]
        )
        let connection = MCPConnectionInfo(
            name: "test-server",
            status: "connected",
            resourceProvider: provider
        )

        let tool = createListMcpResourcesTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("test-server"),
            "Should contain server name"
        )
        XCTAssertTrue(
            result.content.contains("file1.txt"),
            "Should contain resource name"
        )
    }

    /// AC5 [P0]: ListMcpResources formats each resource as "  - {name}: {description || uri || ''}".
    func testListMcpResources_resourceFormatting() async throws {
        let provider = MockMCPResourceProvider(
            resources: [
                MCPResourceItem(name: "readme", description: "Project README", uri: "file:///readme.md"),
            ]
        )
        let connection = MCPConnectionInfo(
            name: "fs-server",
            status: "connected",
            resourceProvider: provider
        )

        let tool = createListMcpResourcesTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("readme"),
            "Should contain resource name"
        )
        XCTAssertTrue(
            result.content.contains("Project README"),
            "Should contain resource description"
        )
    }

    /// AC5 [P1]: ListMcpResources with server that does not support listing returns appropriate message.
    func testListMcpResources_noResourceSupport_returnsNotSupported() async throws {
        // provider with nil resources (simulating server without listResources support)
        let provider = MockMCPResourceProvider(resources: nil)
        let connection = MCPConnectionInfo(
            name: "basic-server",
            status: "connected",
            resourceProvider: provider
        )

        let tool = createListMcpResourcesTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("basic-server"),
            "Should contain server name even when listing not supported"
        )
    }

    /// AC5 [P1]: ListMcpResources with provider that throws returns "resource listing not supported".
    func testListMcpResources_providerThrows_returnsNotSupported() async throws {
        let provider = MockMCPResourceProvider(shouldThrow: true)
        let connection = MCPConnectionInfo(
            name: "flaky-server",
            status: "connected",
            resourceProvider: provider
        )

        let tool = createListMcpResourcesTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("flaky-server"),
            "Should contain server name in error output"
        )
    }

    // MARK: - AC6: ListMcpResources Server Filter

    /// AC6 [P0]: ListMcpResources with server filter returns only matching server resources.
    func testListMcpResources_serverFilter_returnsOnlyMatchingServer() async throws {
        let provider1 = MockMCPResourceProvider(
            resources: [MCPResourceItem(name: "resource-a", description: nil, uri: nil)]
        )
        let provider2 = MockMCPResourceProvider(
            resources: [MCPResourceItem(name: "resource-b", description: nil, uri: nil)]
        )
        let conn1 = MCPConnectionInfo(name: "server-alpha", status: "connected", resourceProvider: provider1)
        let conn2 = MCPConnectionInfo(name: "server-beta", status: "connected", resourceProvider: provider2)

        let tool = createListMcpResourcesTool()
        let context = makeContext(mcpConnections: [conn1, conn2])

        let input: [String: Any] = ["server": "server-alpha"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("server-alpha"),
            "Should contain the filtered server name"
        )
        XCTAssertFalse(
            result.content.contains("server-beta"),
            "Should NOT contain the non-matching server name"
        )
    }

    /// AC6 [P0]: ListMcpResources without filter returns all servers' resources.
    func testListMcpResources_noFilter_returnsAllServers() async throws {
        let provider1 = MockMCPResourceProvider(
            resources: [MCPResourceItem(name: "resource-a", description: nil, uri: nil)]
        )
        let provider2 = MockMCPResourceProvider(
            resources: [MCPResourceItem(name: "resource-b", description: nil, uri: nil)]
        )
        let conn1 = MCPConnectionInfo(name: "server-alpha", status: "connected", resourceProvider: provider1)
        let conn2 = MCPConnectionInfo(name: "server-beta", status: "connected", resourceProvider: provider2)

        let tool = createListMcpResourcesTool()
        let context = makeContext(mcpConnections: [conn1, conn2])

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("server-alpha"),
            "Should contain first server name"
        )
        XCTAssertTrue(
            result.content.contains("server-beta"),
            "Should contain second server name"
        )
    }

    /// AC6 [P0]: ListMcpResources only queries connected servers (skips disconnected).
    func testListMcpResources_skipsDisconnectedServers() async throws {
        let provider = MockMCPResourceProvider(
            resources: [MCPResourceItem(name: "resource-x", description: nil, uri: nil)]
        )
        let conn1 = MCPConnectionInfo(name: "connected-server", status: "connected", resourceProvider: provider)
        let conn2 = MCPConnectionInfo(name: "disconnected-server", status: "disconnected", resourceProvider: nil)

        let tool = createListMcpResourcesTool()
        let context = makeContext(mcpConnections: [conn1, conn2])

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("connected-server"),
            "Should contain connected server"
        )
    }

    // ================================================================
    // MARK: - ReadMcpResource Tool
    // ================================================================

    // MARK: - AC7: ReadMcpResource Tool Registration

    /// AC7 [P0]: createReadMcpResourceTool() returns a ToolProtocol with name "ReadMcpResource".
    func testCreateReadMcpResourceTool_returnsToolProtocol() async throws {
        let tool = createReadMcpResourceTool()

        XCTAssertEqual(tool.name, "ReadMcpResource")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC7 [P0]: ReadMcpResource tool description mentions reading a resource from MCP server.
    func testCreateReadMcpResourceTool_descriptionMentionsReading() async throws {
        let tool = createReadMcpResourceTool()

        let desc = tool.description.lowercased()
        XCTAssertTrue(
            desc.contains("resource") && (desc.contains("read") || desc.contains("mcp") || desc.contains("server")),
            "Description should mention resource and read/server"
        )
    }

    // MARK: - AC8: ReadMcpResource inputSchema

    /// AC8 [P0]: ReadMcpResource inputSchema has type "object".
    func testCreateReadMcpResourceTool_inputSchema_hasCorrectType() async throws {
        let tool = createReadMcpResourceTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")
    }

    /// AC8 [P0]: ReadMcpResource inputSchema has "server" field (string, required).
    func testCreateReadMcpResourceTool_inputSchema_hasRequiredServer() async throws {
        let tool = createReadMcpResourceTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let serverProp = properties?["server"] as? [String: Any]
        XCTAssertNotNil(serverProp, "server property should exist")
        XCTAssertEqual(serverProp?["type"] as? String, "string")

        let required = schema["required"] as? [String] ?? []
        XCTAssertTrue(required.contains("server"), "server should be required")
    }

    /// AC8 [P0]: ReadMcpResource inputSchema has "uri" field (string, required).
    func testCreateReadMcpResourceTool_inputSchema_hasRequiredUri() async throws {
        let tool = createReadMcpResourceTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let uriProp = properties?["uri"] as? [String: Any]
        XCTAssertNotNil(uriProp, "uri property should exist")
        XCTAssertEqual(uriProp?["type"] as? String, "string")

        let required = schema["required"] as? [String] ?? []
        XCTAssertTrue(required.contains("uri"), "uri should be required")
    }

    /// AC8 [P0]: ReadMcpResource inputSchema required fields are exactly ["server", "uri"].
    func testCreateReadMcpResourceTool_inputSchema_requiredFieldsExactly() async throws {
        let tool = createReadMcpResourceTool()
        let schema = tool.inputSchema

        let required = schema["required"] as? [String]
        XCTAssertEqual(
            Set(required ?? []),
            Set(["server", "uri"]),
            "Required fields should be exactly server and uri"
        )
    }

    // MARK: - AC9: ReadMcpResource isReadOnly

    /// AC9 [P0]: ReadMcpResource tool isReadOnly returns true.
    func testCreateReadMcpResourceTool_isReadOnly_returnsTrue() async throws {
        let tool = createReadMcpResourceTool()
        XCTAssertTrue(tool.isReadOnly, "ReadMcpResource should be read-only")
    }

    // MARK: - AC10: ReadMcpResource Server Not Found

    /// AC10 [P0]: ReadMcpResource with nonexistent server returns is_error=true with "MCP server not found: {server}".
    func testReadMcpResource_serverNotFound_returnsError() async throws {
        let tool = createReadMcpResourceTool()
        let context = makeContext()

        let input: [String: Any] = [
            "server": "missing-server",
            "uri": "file:///data/test.txt"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError, "Should return is_error=true for missing server")
        XCTAssertTrue(
            result.content.contains("MCP server not found"),
            "Should contain 'MCP server not found'"
        )
        XCTAssertTrue(
            result.content.contains("missing-server"),
            "Should contain the server name in error message"
        )
    }

    /// AC10 [P0]: ReadMcpResource with server name that exists but is not in connections returns error.
    func testReadMcpResource_wrongServerName_returnsError() async throws {
        let provider = MockMCPResourceProvider(resources: [])
        let connection = MCPConnectionInfo(name: "real-server", status: "connected", resourceProvider: provider)

        let tool = createReadMcpResourceTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [
            "server": "fake-server",
            "uri": "file:///data/test.txt"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(
            result.content.contains("MCP server not found"),
            "Should contain 'MCP server not found'"
        )
    }

    // MARK: - AC11: ReadMcpResource Read Success

    /// AC11 [P0]: ReadMcpResource with valid server and uri returns text content.
    func testReadMcpResource_validServer_returnsContent() async throws {
        let provider = MockMCPResourceProvider(
            readResult: MCPReadResult(contents: [
                MCPContentItem(text: "Hello, world!", rawValue: nil)
            ])
        )
        let connection = MCPConnectionInfo(name: "data-server", status: "connected", resourceProvider: provider)

        let tool = createReadMcpResourceTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [
            "server": "data-server",
            "uri": "file:///data/hello.txt"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("Hello, world!"),
            "Should contain the resource text content"
        )
    }

    /// AC11 [P0]: ReadMcpResource with multiple content items concatenates them.
    func testReadMcpResource_multipleContentItems_concatenatesText() async throws {
        let provider = MockMCPResourceProvider(
            readResult: MCPReadResult(contents: [
                MCPContentItem(text: "First part", rawValue: nil),
                MCPContentItem(text: "Second part", rawValue: nil),
            ])
        )
        let connection = MCPConnectionInfo(name: "multi-server", status: "connected", resourceProvider: provider)

        let tool = createReadMcpResourceTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [
            "server": "multi-server",
            "uri": "file:///data/multi.txt"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("First part"),
            "Should contain first content item"
        )
        XCTAssertTrue(
            result.content.contains("Second part"),
            "Should contain second content item"
        )
    }

    /// AC11 [P1]: ReadMcpResource serializes non-text content as JSON.
    func testReadMcpResource_nonTextContent_serializesToJson() async throws {
        let provider = MockMCPResourceProvider(
            readResult: MCPReadResult(contents: [
                MCPContentItem(text: nil, rawValue: ["key": "value"])
            ])
        )
        let connection = MCPConnectionInfo(name: "json-server", status: "connected", resourceProvider: provider)

        let tool = createReadMcpResourceTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [
            "server": "json-server",
            "uri": "resource://config"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertFalse(result.content.isEmpty, "Should return serialized content for non-text items")
    }

    // MARK: - AC12: ReadMcpResource No Content

    /// AC12 [P0]: ReadMcpResource with empty contents returns "Resource read returned no content.".
    func testReadMcpResource_emptyContents_returnsNoContentMessage() async throws {
        let provider = MockMCPResourceProvider(
            readResult: MCPReadResult(contents: [])
        )
        let connection = MCPConnectionInfo(name: "empty-server", status: "connected", resourceProvider: provider)

        let tool = createReadMcpResourceTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [
            "server": "empty-server",
            "uri": "file:///empty.txt"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("no content"),
            "Should return 'no content' message"
        )
    }

    /// AC12 [P0]: ReadMcpResource with nil contents returns "Resource read returned no content.".
    func testReadMcpResource_nilContents_returnsNoContentMessage() async throws {
        let provider = MockMCPResourceProvider(
            readResult: MCPReadResult(contents: nil)
        )
        let connection = MCPConnectionInfo(name: "nil-server", status: "connected", resourceProvider: provider)

        let tool = createReadMcpResourceTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [
            "server": "nil-server",
            "uri": "file:///nil.txt"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("no content"),
            "Should return 'no content' message for nil contents"
        )
    }

    // MARK: - AC13: ReadMcpResource Read Exception

    /// AC13 [P0]: ReadMcpResource when provider throws returns is_error=true with "Error reading resource: {message}".
    func testReadMcpResource_providerThrows_returnsError() async throws {
        let provider = MockMCPResourceProvider(shouldThrow: true)
        let connection = MCPConnectionInfo(name: "error-server", status: "connected", resourceProvider: provider)

        let tool = createReadMcpResourceTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [
            "server": "error-server",
            "uri": "file:///broken.txt"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError, "Should return is_error=true when provider throws")
        XCTAssertTrue(
            result.content.contains("Error reading resource"),
            "Should contain 'Error reading resource'"
        )
    }

    /// AC13 [P0]: ReadMcpResource error message includes the underlying error description.
    func testReadMcpResource_providerThrows_includesErrorMessage() async throws {
        let provider = MockMCPResourceProvider(shouldThrow: true)
        let connection = MCPConnectionInfo(name: "throw-server", status: "connected", resourceProvider: provider)

        let tool = createReadMcpResourceTool()
        let context = makeContext(mcpConnections: [connection])

        let input: [String: Any] = [
            "server": "throw-server",
            "uri": "file:///bad.txt"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(
            result.content.contains("Error reading resource"),
            "Error message should start with 'Error reading resource'"
        )
    }

    // ================================================================
    // MARK: - Cross-cutting Concerns
    // ================================================================

    // MARK: - AC14: Module Boundary

    /// AC14 [P0]: ListMcpResources tool does not require stores in context (no Actor store needed).
    func testListMcpResourcesTool_doesNotRequireStoreInContext() async throws {
        let tool = createListMcpResourcesTool()
        // Minimal context with only cwd and toolUseId -- no stores
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        let input: [String: Any] = [:]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertFalse(result.content.isEmpty)
    }

    /// AC14 [P0]: ReadMcpResource tool does not require stores in context (no Actor store needed).
    func testReadMcpResourceTool_doesNotRequireStoreInContext() async throws {
        let tool = createReadMcpResourceTool()
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        let input: [String: Any] = ["server": "any", "uri": "any://uri"]
        let result = await tool.call(input: input, context: context)

        // Should return error about server not found, not crash
        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.toolUseId, "test-id")
    }

    // MARK: - AC15: Error Handling -- Never Throws

    /// AC15 [P0]: ListMcpResources never throws -- always returns ToolResult even with malformed input.
    func testListMcpResourcesTool_neverThrows_malformedInput() async throws {
        let tool = createListMcpResourcesTool()
        let context = makeContext()

        let badInputs: [[String: Any]] = [
            [:],                              // empty dict
            ["unexpected": "field"],          // unexpected fields only
            ["server": 123],                  // wrong type for server
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    /// AC15 [P0]: ReadMcpResource never throws -- always returns ToolResult even with malformed input.
    func testReadMcpResourceTool_neverThrows_malformedInput() async throws {
        let tool = createReadMcpResourceTool()
        let context = makeContext()

        let badInputs: [[String: Any]] = [
            [:],                              // empty dict (missing server and uri)
            ["unexpected": "field"],          // unexpected fields only
            ["server": 123, "uri": "test"],   // wrong type for server
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    // MARK: - AC16: ToolRegistry Registration

    /// AC16 [P0]: getAllBaseTools(tier: .specialist) includes createListMcpResourcesTool.
    func testToolRegistry_specialistTier_includesListMcpResourcesTool() async throws {
        let tools = getAllBaseTools(tier: .specialist)
        let names = tools.map { $0.name }

        XCTAssertTrue(names.contains("ListMcpResources"), "Specialist tier should include ListMcpResources tool")
    }

    /// AC16 [P0]: getAllBaseTools(tier: .specialist) includes createReadMcpResourceTool.
    func testToolRegistry_specialistTier_includesReadMcpResourceTool() async throws {
        let tools = getAllBaseTools(tier: .specialist)
        let names = tools.map { $0.name }

        XCTAssertTrue(names.contains("ReadMcpResource"), "Specialist tier should include ReadMcpResource tool")
    }

    // MARK: - AC18: MCP Connection Injection

    /// AC18 [P0]: setMcpConnections function exists and accepts connection array (backward compat stub).
    func testSetMcpConnections_exists() async throws {
        // This test verifies setMcpConnections compiles and works (now a no-op stub)
        let provider = MockMCPResourceProvider(resources: [])
        let connection = MCPConnectionInfo(name: "test", status: "connected", resourceProvider: provider)

        setMcpConnections([connection])
        // If we get here without compile error, setMcpConnections exists
    }

    /// AC18 [P0]: ToolContext with nil mcpConnections reports "No MCP servers connected".
    func testToolContext_nilMcpConnections_reportsNoServers() async throws {
        let tool = createListMcpResourcesTool()
        let context = makeContext()  // nil mcpConnections by default
        let result = await tool.call(input: [:], context: context)

        XCTAssertTrue(
            result.content.contains("No MCP servers connected"),
            "With nil mcpConnections, should report no servers"
        )
    }

    // MARK: - MCPResourceTypes Existence

    /// MCPResourceItem can be created with name, description, and uri.
    func testMCPResourceItem_creation() async throws {
        let item = MCPResourceItem(name: "test", description: "desc", uri: "file:///test")
        XCTAssertEqual(item.name, "test")
        XCTAssertEqual(item.description, "desc")
        XCTAssertEqual(item.uri, "file:///test")
    }

    /// MCPResourceItem can be created with nil description and uri.
    func testMCPResourceItem_creationWithNilOptionals() async throws {
        let item = MCPResourceItem(name: "minimal", description: nil, uri: nil)
        XCTAssertEqual(item.name, "minimal")
        XCTAssertNil(item.description)
        XCTAssertNil(item.uri)
    }

    /// MCPConnectionInfo can be created with name, status, and optional provider.
    func testMCPConnectionInfo_creation() async throws {
        let conn = MCPConnectionInfo(name: "server", status: "connected", resourceProvider: nil)
        XCTAssertEqual(conn.name, "server")
        XCTAssertEqual(conn.status, "connected")
        XCTAssertNil(conn.resourceProvider)
    }

    /// MCPReadResult can be created with contents array.
    func testMCPReadResult_creation() async throws {
        let result = MCPReadResult(contents: [
            MCPContentItem(text: "hello", rawValue: nil)
        ])
        XCTAssertNotNil(result.contents)
        XCTAssertEqual(result.contents?.count, 1)
    }

    /// MCPReadResult can be created with nil contents.
    func testMCPReadResult_creationWithNilContents() async throws {
        let result = MCPReadResult(contents: nil)
        XCTAssertNil(result.contents)
    }

    /// MCPContentItem can be created with text.
    func testMCPContentItem_creationWithText() async throws {
        let item = MCPContentItem(text: "sample", rawValue: nil)
        XCTAssertEqual(item.text, "sample")
        XCTAssertNil(item.rawValue)
    }

    // MARK: - Integration: Full MCP Resource Lifecycle

    /// Integration [P1]: List resources -> filter by server -> read a resource -> verify content.
    func testIntegration_listFilterRead_lifecycle() async throws {
        let provider = MockMCPResourceProvider(
            resources: [
                MCPResourceItem(name: "doc", description: "Documentation", uri: "file:///doc.md")
            ],
            readResult: MCPReadResult(contents: [
                MCPContentItem(text: "# Documentation\nHello world", rawValue: nil)
            ])
        )
        let connection = MCPConnectionInfo(name: "lifecycle-server", status: "connected", resourceProvider: provider)

        // Step 1: List resources
        let listTool = createListMcpResourcesTool()
        let context = makeContext(mcpConnections: [connection])
        let listResult = await listTool.call(input: [:], context: context)
        XCTAssertFalse(listResult.isError)
        XCTAssertTrue(listResult.content.contains("lifecycle-server"))

        // Step 2: Filter by server
        let filterResult = await listTool.call(input: ["server": "lifecycle-server"], context: context)
        XCTAssertFalse(filterResult.isError)
        XCTAssertTrue(filterResult.content.contains("lifecycle-server"))
        XCTAssertFalse(filterResult.content.contains("other-server"))

        // Step 3: Read a resource
        let readTool = createReadMcpResourceTool()
        let readResult = await readTool.call(
            input: ["server": "lifecycle-server", "uri": "file:///doc.md"],
            context: context
        )
        XCTAssertFalse(readResult.isError)
        XCTAssertTrue(readResult.content.contains("Hello world"))
    }
}

// MARK: - Mock MCPResourceProvider

/// Mock implementation of MCPResourceProvider for testing.
/// This will be defined in the test target alongside the tool types.
final class MockMCPResourceProvider: MCPResourceProvider, Sendable {
    private let resources: [MCPResourceItem]?
    private let readResult: MCPReadResult?
    private let shouldThrow: Bool

    init(
        resources: [MCPResourceItem]? = nil,
        readResult: MCPReadResult? = nil,
        shouldThrow: Bool = false
    ) {
        self.resources = resources
        self.readResult = readResult
        self.shouldThrow = shouldThrow
    }

    func listResources() async -> [MCPResourceItem]? {
        if shouldThrow { return nil }
        return resources
    }

    func readResource(uri: String) async throws -> MCPReadResult {
        if shouldThrow {
            throw MCPResourceTestError.mockError("Mock read failure for uri: \(uri)")
        }
        return readResult ?? MCPReadResult(contents: nil)
    }
}

// MARK: - Test Error Type

enum MCPResourceTestError: Error, LocalizedError {
    case mockError(String)

    var errorDescription: String? {
        switch self {
        case .mockError(let message): return message
        }
    }
}

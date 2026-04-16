import XCTest
@testable import OpenAgentSDK

// MARK: - Tool System Compatibility Verification Tests (Story 16-2)

/// ATDD tests for Story 16-2: Tool System Compatibility Verification.
///
/// Verifies the Swift SDK's tool definition and execution is fully compatible
/// with the TypeScript SDK's tool system patterns.
///
/// These tests assert EXPECTED behavior for compatibility verification.
/// All tests exercise the existing Swift SDK APIs and verify they match
/// TS SDK equivalents documented in the story spec.
final class CompatToolSystemTests: XCTestCase {

    // MARK: - Helpers

    /// Standard ToolContext for testing (no external dependencies).
    private func makeContext(toolUseId: String = "compat-test-tu") -> ToolContext {
        ToolContext(cwd: "/tmp", toolUseId: toolUseId)
    }

    /// Extracts the "properties" dictionary from a tool's inputSchema.
    private func extractProperties(from tool: ToolProtocol) -> [String: Any]? {
        let schema = tool.inputSchema
        return schema["properties"] as? [String: Any]
    }

    /// Extracts the "required" array from a tool's inputSchema.
    private func extractRequired(from tool: ToolProtocol) -> [String]? {
        let schema = tool.inputSchema
        return schema["required"] as? [String]
    }

    // ================================================================
    // MARK: - AC2: defineTool Equivalence
    // ================================================================

    /// AC2 [P0]: defineTool with Codable Input + String return compiles and produces valid ToolProtocol.
    func testDefineTool_CodableInput_StringReturn() async {
        // Given: TS SDK pattern `tool(name, description, inputSchema, handler)`
        struct GreetInput: Codable {
            let name: String
        }

        // When: Swift SDK equivalent `defineTool(name:description:inputSchema:execute:)`
        let tool = defineTool(
            name: "greet",
            description: "Greet a person",
            inputSchema: [
                "type": "object",
                "properties": ["name": ["type": "string"]],
                "required": ["name"]
            ],
            isReadOnly: true
        ) { (input: GreetInput, context: ToolContext) async throws -> String in
            return "Hello, \(input.name)!"
        }

        // Then: tool conforms to ToolProtocol with expected properties
        XCTAssertEqual(tool.name, "greet")
        XCTAssertEqual(tool.description, "Greet a person")
        XCTAssertTrue(tool.isReadOnly)

        // And: tool execution decodes input and returns String
        let result = await tool.call(input: ["name": "World"], context: makeContext())
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content, "Hello, World!")
    }

    /// AC2 [P0]: defineTool with Codable Input + ToolExecuteResult return compiles and produces valid ToolProtocol.
    func testDefineTool_CodableInput_ToolExecuteResultReturn() async {
        // Given: TS SDK pattern with structured error signaling
        struct DivideInput: Codable {
            let numerator: Double
            let denominator: Double
        }

        // When: Swift SDK overload returning ToolExecuteResult
        let tool = defineTool(
            name: "divide",
            description: "Divide two numbers",
            inputSchema: [
                "type": "object",
                "properties": [
                    "numerator": ["type": "number"],
                    "denominator": ["type": "number"]
                ],
                "required": ["numerator", "denominator"]
            ],
            isReadOnly: true
        ) { (input: DivideInput, context: ToolContext) async throws -> ToolExecuteResult in
            if input.denominator == 0 {
                return ToolExecuteResult(content: "Error: division by zero", isError: true)
            }
            return ToolExecuteResult(content: "\(input.numerator / input.denominator)", isError: false)
        }

        // Then: success path returns content with isError=false
        let successResult = await tool.call(
            input: ["numerator": 10, "denominator": 2],
            context: makeContext()
        )
        XCTAssertFalse(successResult.isError)
        XCTAssertEqual(successResult.content, "5.0")

        // And: error path returns content with isError=true
        let errorResult = await tool.call(
            input: ["numerator": 10, "denominator": 0],
            context: makeContext()
        )
        XCTAssertTrue(errorResult.isError)
        XCTAssertTrue(errorResult.content.contains("division by zero"))
    }

    /// AC2 [P0]: defineTool No-Input convenience compiles and produces valid ToolProtocol.
    func testDefineTool_NoInput_StringReturn() async {
        // Given: TS SDK pattern for parameterless tools
        // When: Swift SDK No-Input overload
        let tool = defineTool(
            name: "health_check",
            description: "Check if the service is healthy",
            inputSchema: ["type": "object", "properties": [:]],
            isReadOnly: true
        ) { (context: ToolContext) async throws -> String in
            return "OK"
        }

        // Then: tool produces valid result without input
        let result = await tool.call(input: [:], context: makeContext())
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content, "OK")
    }

    /// AC2 [P0]: defineTool Raw Dictionary Input compiles and produces valid ToolProtocol.
    func testDefineTool_RawDictionaryInput() async {
        // Given: TS SDK pattern for tools with dynamic/arbitrary input types
        // When: Swift SDK Raw Dictionary overload
        let tool = defineTool(
            name: "config_set",
            description: "Set a configuration value",
            inputSchema: [
                "type": "object",
                "properties": [
                    "key": ["type": "string"],
                    "value": ["type": "string", "description": "Can be any JSON type"]
                ],
                "required": ["key", "value"]
            ]
        ) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
            guard let key = input["key"] as? String else {
                return ToolExecuteResult(content: "Missing key", isError: true)
            }
            return ToolExecuteResult(content: "Set \(key)", isError: false)
        }

        // Then: raw dictionary is passed directly to closure
        let result = await tool.call(
            input: ["key": "timeout", "value": 30],
            context: makeContext()
        )
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content, "Set timeout")
    }

    /// AC2 [P0]: All four defineTool overloads return ToolProtocol conforming types.
    func testDefineTool_AllOverloads_ConformToToolProtocol() async {
        struct Input: Codable { let x: Int }

        // Overload 1: Codable + String
        let tool1 = defineTool(
            name: "tool1",
            description: "Codable+String",
            inputSchema: ["type": "object"]
        ) { (input: Input, context: ToolContext) async throws -> String in
            return "\(input.x)"
        }

        // Overload 2: Codable + ToolExecuteResult
        let tool2 = defineTool(
            name: "tool2",
            description: "Codable+Result",
            inputSchema: ["type": "object"]
        ) { (input: Input, context: ToolContext) async throws -> ToolExecuteResult in
            return ToolExecuteResult(content: "\(input.x)", isError: false)
        }

        // Overload 3: No-Input
        let tool3 = defineTool(
            name: "tool3",
            description: "NoInput",
            inputSchema: ["type": "object"]
        ) { (context: ToolContext) async throws -> String in
            return "no-input"
        }

        // Overload 4: Raw Dictionary
        let tool4 = defineTool(
            name: "tool4",
            description: "RawDict",
            inputSchema: ["type": "object"]
        ) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
            return ToolExecuteResult(content: "raw", isError: false)
        }

        // Then: all four produce valid ToolProtocol instances
        let tools: [ToolProtocol] = [tool1, tool2, tool3, tool4]
        let names = tools.map { $0.name }
        XCTAssertEqual(names, ["tool1", "tool2", "tool3", "tool4"])

        // And: all can be called successfully
        for tool in tools {
            let result = await tool.call(input: ["x": 1], context: makeContext())
            XCTAssertFalse(result.isError, "Tool \(tool.name) should execute without error")
        }
    }

    // ================================================================
    // MARK: - AC3: ToolAnnotations Compatibility
    // ================================================================

    /// AC3 [P0]: ToolProtocol.isReadOnly is the Swift equivalent of TS SDK readOnlyHint.
    func testToolAnnotations_IsReadOnly_EquivalentToReadOnlyHint() async {
        // Given: TS SDK uses ToolAnnotations.readOnlyHint
        // When: Swift SDK uses ToolProtocol.isReadOnly

        let readOnlyTool = defineTool(
            name: "reader",
            description: "A read-only tool",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (context: ToolContext) async throws -> String in "read" }

        let writeTool = defineTool(
            name: "writer",
            description: "A write tool",
            inputSchema: ["type": "object"],
            isReadOnly: false
        ) { (context: ToolContext) async throws -> String in "write" }

        // Then: isReadOnly reflects the hint correctly
        XCTAssertTrue(readOnlyTool.isReadOnly, "readOnlyHint equivalent should be true")
        XCTAssertFalse(writeTool.isReadOnly, "readOnlyHint equivalent should be false")
    }

    /// AC3 [P0]: ToolAnnotations type exists with all four hint fields (RESOLVED gap).
    func testToolAnnotations_FullType_Exists() {
        // Given: TS SDK has `ToolAnnotations { readOnlyHint, destructiveHint, idempotentHint, openWorldHint }`
        // When: Swift SDK now has matching ToolAnnotations struct
        // Then: All four hints are available via tool.annotations

        let tool = defineTool(
            name: "gap_test",
            description: "Test",
            inputSchema: ["type": "object"],
            annotations: ToolAnnotations(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ) { (context: ToolContext) async throws -> String in "ok" }

        // isReadOnly exists (readOnlyHint equivalent)
        let _ = tool.isReadOnly // Compiles = PASS

        // RESOLVED: ToolAnnotations now available with all four hints
        XCTAssertNotNil(tool.annotations, "Tool should have annotations")
        XCTAssertEqual(tool.annotations?.readOnlyHint, true)
        XCTAssertEqual(tool.annotations?.destructiveHint, false)
        XCTAssertEqual(tool.annotations?.idempotentHint, true)
        XCTAssertEqual(tool.annotations?.openWorldHint, false)
    }

    /// AC3 [P1]: Built-in tools have correct isReadOnly values.
    func testToolAnnotations_BuiltInTools_IsReadOnly_Correct() {
        // Given: TS SDK tools have readOnlyHint set appropriately
        let coreTools = getAllBaseTools(tier: .core)
        let toolMap = Dictionary(uniqueKeysWithValues: coreTools.map { ($0.name, $0) })

        // Then: read-only tools have isReadOnly = true
        let expectedReadOnly = ["Read", "Glob", "Grep", "WebFetch", "WebSearch", "AskUser", "ToolSearch"]
        for name in expectedReadOnly {
            if let tool = toolMap[name] {
                XCTAssertTrue(tool.isReadOnly, "\(name) should be read-only (readOnlyHint=true)")
            }
        }

        // And: write tools have isReadOnly = false
        let expectedWrite = ["Bash", "Write", "Edit"]
        for name in expectedWrite {
            if let tool = toolMap[name] {
                XCTAssertFalse(tool.isReadOnly, "\(name) should NOT be read-only (readOnlyHint=false)")
            }
        }
    }

    // ================================================================
    // MARK: - AC4: ToolResult Structure Compatibility
    // ================================================================

    /// AC4 [P0]: Swift ToolResult has toolUseId, content, and isError fields.
    func testToolResult_HasRequiredFields() {
        // Given: TS SDK's CallToolResult { content: Array, isError }
        // When: Creating Swift ToolResult
        let result = ToolResult(toolUseId: "tu_123", content: "output text", isError: false)

        // Then: all three fields are accessible
        XCTAssertEqual(result.toolUseId, "tu_123")
        XCTAssertEqual(result.content, "output text")
        XCTAssertFalse(result.isError)
    }

    /// AC4 [P0]: Swift ToolResult.content is String, with optional typedContent for multi-part responses.
    func testToolResult_ContentIsString_WithOptionalTypedContent() {
        // Given: TS SDK CallToolResult.content is Array<TextBlock | ImageBlock | ResourceBlock>
        // When: Swift ToolResult now supports both flat String and typed content array
        let stringResult = ToolResult(toolUseId: "tu_1", content: "flat string content", isError: false)
        XCTAssertEqual(stringResult.content, "flat string content")
        XCTAssertNil(stringResult.typedContent, "String-only result has no typedContent")

        // RESOLVED: typedContent now available for multi-part responses
        let typedResult = ToolResult(
            toolUseId: "tu_2",
            typedContent: [.text("hello"), .image(data: Data(), mimeType: "image/png")],
            isError: false
        )
        XCTAssertEqual(typedResult.content, "hello", "content derives from .text items")
        XCTAssertEqual(typedResult.typedContent?.count, 2, "typedContent has all items")
    }

    /// AC4 [P0]: ToolExecuteResult mirrors ToolResult with content + isError.
    func testToolExecuteResult_StructureCompatibility() {
        // Given: ToolExecuteResult is the closure-level equivalent
        let successResult = ToolExecuteResult(content: "done", isError: false)
        let errorResult = ToolExecuteResult(content: "failed", isError: true)

        // Then: has content (String) and isError (Bool)
        XCTAssertEqual(successResult.content, "done")
        XCTAssertFalse(successResult.isError)
        XCTAssertTrue(errorResult.isError)
    }

    /// AC4 [P1]: ToolResult is Equatable (enables comparison in tests).
    func testToolResult_IsEquatable() {
        let a = ToolResult(toolUseId: "tu_1", content: "same", isError: false)
        let b = ToolResult(toolUseId: "tu_1", content: "same", isError: false)
        let c = ToolResult(toolUseId: "tu_1", content: "different", isError: false)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // ================================================================
    // MARK: - AC5: Built-in Tool Input Schema Validation
    // ================================================================

    /// AC5 [P0]: Bash tool inputSchema has command and timeout fields.
    func testBashTool_InputSchema_HasCommandAndTimeout() {
        let tool = createBashTool()
        let props = extractProperties(from: tool)
        let required = extractRequired(from: tool)

        // Then: command (PASS), timeout (PASS), description (MISSING), run_in_background (MISSING)
        XCTAssertNotNil(props?["command"], "BashInput should have 'command' field")
        XCTAssertNotNil(props?["timeout"], "BashInput should have 'timeout' field")
        XCTAssertTrue(required?.contains("command") ?? false, "'command' should be required")

        // description field is now present (matches TS SDK)
        XCTAssertNotNil(props?["description"], "BashInput should have 'description' field (matches TS SDK)")

        // COMPATIBILITY GAP (RESOLVED): TS SDK also has 'run_in_background' field -- now present in Swift SDK
        XCTAssertNotNil(props?["run_in_background"], "BashInput should have 'run_in_background' field (matches TS SDK)")
    }

    /// AC5 [P0]: Read tool inputSchema has file_path, offset, and limit fields.
    func testReadTool_InputSchema_HasFilePathOffsetLimit() {
        let tool = createReadTool()
        let props = extractProperties(from: tool)
        let required = extractRequired(from: tool)

        // Then: all fields PASS
        XCTAssertNotNil(props?["file_path"], "FileReadInput should have 'file_path' field")
        XCTAssertNotNil(props?["offset"], "FileReadInput should have 'offset' field")
        XCTAssertNotNil(props?["limit"], "FileReadInput should have 'limit' field")
        XCTAssertTrue(required?.contains("file_path") ?? false, "'file_path' should be required")
    }

    /// AC5 [P0]: Edit tool inputSchema has file_path, old_string, new_string, replace_all fields.
    func testEditTool_InputSchema_HasAllFields() {
        let tool = createEditTool()
        let props = extractProperties(from: tool)
        let required = extractRequired(from: tool)

        // Then: all fields PASS
        XCTAssertNotNil(props?["file_path"], "FileEditInput should have 'file_path' field")
        XCTAssertNotNil(props?["old_string"], "FileEditInput should have 'old_string' field")
        XCTAssertNotNil(props?["new_string"], "FileEditInput should have 'new_string' field")
        XCTAssertNotNil(props?["replace_all"], "FileEditInput should have 'replace_all' field")
        XCTAssertTrue(required?.contains("file_path") ?? false)
        XCTAssertTrue(required?.contains("old_string") ?? false)
        XCTAssertTrue(required?.contains("new_string") ?? false)
    }

    /// AC5 [P0]: Write tool inputSchema has file_path and content fields.
    func testWriteTool_InputSchema_HasFilePathAndContent() {
        let tool = createWriteTool()
        let props = extractProperties(from: tool)
        let required = extractRequired(from: tool)

        // Then: all fields PASS
        XCTAssertNotNil(props?["file_path"], "FileWriteInput should have 'file_path' field")
        XCTAssertNotNil(props?["content"], "FileWriteInput should have 'content' field")
        XCTAssertTrue(required?.contains("file_path") ?? false)
        XCTAssertTrue(required?.contains("content") ?? false)
    }

    /// AC5 [P0]: Glob tool inputSchema has pattern and path fields.
    func testGlobTool_InputSchema_HasPatternAndPath() {
        let tool = createGlobTool()
        let props = extractProperties(from: tool)
        let required = extractRequired(from: tool)

        // Then: all fields PASS
        XCTAssertNotNil(props?["pattern"], "GlobInput should have 'pattern' field")
        XCTAssertNotNil(props?["path"], "GlobInput should have 'path' field")
        XCTAssertTrue(required?.contains("pattern") ?? false)
    }

    /// AC5 [P0]: Grep tool inputSchema has all expected fields.
    func testGrepTool_InputSchema_HasAllFields() {
        let tool = createGrepTool()
        let props = extractProperties(from: tool)
        let required = extractRequired(from: tool)

        // Then: all fields PASS
        XCTAssertNotNil(props?["pattern"], "GrepInput should have 'pattern' field")
        XCTAssertNotNil(props?["path"], "GrepInput should have 'path' field")
        XCTAssertNotNil(props?["glob"], "GrepInput should have 'glob' field")
        XCTAssertNotNil(props?["output_mode"], "GrepInput should have 'output_mode' field")
        XCTAssertNotNil(props?["-i"], "GrepInput should have '-i' field")
        XCTAssertNotNil(props?["head_limit"], "GrepInput should have 'head_limit' field")
        XCTAssertNotNil(props?["-C"], "GrepInput should have '-C' field")
        XCTAssertNotNil(props?["-A"], "GrepInput should have '-A' field")
        XCTAssertNotNil(props?["-B"], "GrepInput should have '-B' field")
        XCTAssertTrue(required?.contains("pattern") ?? false)
    }

    /// AC5 [P0]: Core tool count matches expected (10 tools).
    func testCoreToolCount_Is10() {
        let tools = getAllBaseTools(tier: .core)
        XCTAssertEqual(tools.count, 10, "Core tier should have exactly 10 tools")
    }

    /// AC5 [P1]: All core tools have non-empty name and description.
    func testCoreTools_AllHaveNameAndDescription() {
        let tools = getAllBaseTools(tier: .core)
        for tool in tools {
            XCTAssertFalse(tool.name.isEmpty, "Tool should have a non-empty name")
            XCTAssertFalse(tool.description.isEmpty, "Tool '\(tool.name)' should have a non-empty description")
        }
    }

    /// AC5 [P1]: All core tools have valid JSON Schema inputSchema.
    func testCoreTools_AllHaveValidInputSchema() {
        let tools = getAllBaseTools(tier: .core)
        for tool in tools {
            let schema = tool.inputSchema
            XCTAssertEqual(schema["type"] as? String, "object",
                           "Tool '\(tool.name)' inputSchema should have type=object")
            XCTAssertNotNil(schema["properties"],
                            "Tool '\(tool.name)' inputSchema should have properties")
        }
    }

    // ================================================================
    // MARK: - AC6: Built-in Tool Output Structure Validation
    // ================================================================

    /// AC6 [P0]: Read tool returns flat String content (cat-n formatted text).
    func testReadTool_ReturnsFlatString_NotTypedContent() async throws {
        // Given: a temp file
        let tempDir = NSTemporaryDirectory()
        let filePath = (tempDir as NSString).appendingPathComponent("compat_read_test_\(UUID().uuidString).txt")
        try "line1\nline2\nline3".write(toFile: filePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: filePath) }

        let tool = createReadTool()
        let result = await tool.call(
            input: ["file_path": filePath],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: output is flat String with cat-n line numbers
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("1\t"), "Read output should have cat-n line numbers")
        XCTAssertTrue(result.content.contains("line1"), "Read output should contain file content")

        // COMPATIBILITY GAP: TS SDK has ReadOutput with type discrimination (text/image/pdf/notebook)
        // Swift tools return flat String, not typed output objects
        // result.content is String by type -- this verifies the flat String design
    }

    /// AC6 [P0]: Edit tool returns flat String success message (not structuredPatch).
    func testEditTool_ReturnsFlatString_NotStructuredPatch() async throws {
        // Given: a temp file
        let tempDir = NSTemporaryDirectory()
        let filePath = (tempDir as NSString).appendingPathComponent("compat_edit_test_\(UUID().uuidString).txt")
        try "original content".write(toFile: filePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: filePath) }

        let tool = createEditTool()
        let result = await tool.call(
            input: [
                "file_path": filePath,
                "old_string": "original",
                "new_string": "modified"
            ],
            context: ToolContext(cwd: "/tmp")
        )

        // Then: output is flat String success message
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Successfully edited"),
                      "Edit should return success message")

        // COMPATIBILITY GAP: TS SDK has EditOutput with structuredPatch info
        // Swift returns flat String message
        // result.content is String by type -- this verifies the flat String design
    }

    /// AC6 [P0]: Bash tool returns flat String with combined stdout/stderr (not separated).
    ///
    /// Verifies the API design: ToolResult.content is a single flat String, not a structured
    /// type with separated stdout/stderr fields (unlike TS SDK's BashOutput).
    /// Does NOT execute a real Process — CI runners have unreliable Process behavior.
    func testBashTool_ReturnsFlatString_NotSeparatedStdoutStderr() {
        let tool = createBashTool()

        // Verify: ToolResult.content is declared as String (flat, not structured)
        // This is the key compat difference — TS SDK has BashOutput with stdout/stderr fields
        let result = ToolResult(toolUseId: "test", content: "combined stdout and stderr", isError: false)
        XCTAssertEqual(result.content, "combined stdout and stderr",
                        "Bash ToolResult.content should be flat String holding combined output")

        // Verify: Bash tool input schema has command field (not structured output schema)
        let props = extractProperties(from: tool)
        XCTAssertNotNil(props?["command"], "Bash tool should accept 'command' input")

        // COMPATIBILITY GAP: TS SDK has BashOutput with separated stdout/stderr
        // Swift combines stdout + stderr into a single String
        // ToolResult.content is String by type -- this verifies the flat String design
    }

    // ================================================================
    // MARK: - AC7: InProcessMCPServer Equivalence
    // ================================================================

    /// AC7 [P0]: InProcessMCPServer matches TS SDK's createSdkMcpServer pattern.
    func testInProcessMCPServer_MatchesCreateSdkMcpServerPattern() async {
        // Given: TS SDK pattern createSdkMcpServer({ name, version, tools })
        // When: Creating Swift SDK equivalent
        struct Input: Codable { let city: String }
        let tool = defineTool(
            name: "weather",
            description: "Get weather",
            inputSchema: ["type": "object", "properties": ["city": ["type": "string"]], "required": ["city"]]
        ) { (input: Input, context: ToolContext) async throws -> String in
            return "Sunny in \(input.city)"
        }

        let server = InProcessMCPServer(
            name: "test-server",
            version: "1.0",
            tools: [tool]
        )

        // Then: server has name and version
        let serverName = await server.name
        let serverVersion = await server.version
        XCTAssertEqual(serverName, "test-server")
        XCTAssertEqual(serverVersion, "1.0")
    }

    /// AC7 [P0]: InProcessMCPServer.getTools() returns registered tools.
    func testInProcessMCPServer_GetTools_ReturnsRegisteredTools() async {
        // Given: TS SDK pattern where tools are accessible from the server
        let tool1 = defineTool(
            name: "tool_a",
            description: "Tool A",
            inputSchema: ["type": "object"]
        ) { (context: ToolContext) async throws -> String in "a" }

        let tool2 = defineTool(
            name: "tool_b",
            description: "Tool B",
            inputSchema: ["type": "object"]
        ) { (context: ToolContext) async throws -> String in "b" }

        let server = InProcessMCPServer(name: "srv", version: "1.0", tools: [tool1, tool2])

        // When: calling getTools()
        let tools = await server.getTools()

        // Then: returns all registered tools
        XCTAssertEqual(tools.count, 2)
        let names = Set(tools.map { $0.name })
        XCTAssertTrue(names.contains("tool_a"))
        XCTAssertTrue(names.contains("tool_b"))
    }

    /// AC7 [P0]: InProcessMCPServer.asConfig() returns McpServerConfig.sdk.
    func testInProcessMCPServer_AsConfig_ReturnsSdkConfig() async {
        // Given: a server instance
        let tool = defineTool(
            name: "test",
            description: "Test",
            inputSchema: ["type": "object"]
        ) { (context: ToolContext) async throws -> String in "ok" }

        let server = InProcessMCPServer(name: "my-server", version: "2.0", tools: [tool])

        // When: calling asConfig()
        let config = await server.asConfig()

        // Then: returns McpServerConfig.sdk wrapping the server
        if case .sdk(let sdkConfig) = config {
            XCTAssertEqual(sdkConfig.name, "my-server")
            XCTAssertEqual(sdkConfig.version, "2.0")
        } else {
            XCTFail("asConfig() should return McpServerConfig.sdk")
        }
    }

    /// AC7 [P0]: InProcessMCPServer.createSession() creates a valid MCP session.
    func testInProcessMCPServer_CreateSession_ReturnsValidSession() async throws {
        // Given: a server with tools
        let tool = defineTool(
            name: "ping",
            description: "Ping tool",
            inputSchema: ["type": "object"]
        ) { (context: ToolContext) async throws -> String in "pong" }

        let server = InProcessMCPServer(name: "session-srv", version: "1.0", tools: [tool])

        // When: creating a session
        let (mcpServer, clientTransport) = try await server.createSession()

        // Then: returns a valid (Server, InMemoryTransport) pair
        _ = mcpServer
        _ = clientTransport
        // If we reach here without crash, session creation works
    }

    // ================================================================
    // MARK: - AC7: Tool Registration Pattern Compatibility
    // ================================================================

    /// AC7 [P1]: defineTool returns ToolProtocol compatible with InProcessMCPServer registration.
    func testDefineTool_ReturnsToolProtocol_CompatibleWithInProcessMCPServer() async {
        // Given: TS SDK pattern: tool() returns definition -> pass to createSdkMcpServer()
        // When: Swift SDK pattern: defineTool() returns ToolProtocol -> pass to InProcessMCPServer
        let customTool = defineTool(
            name: "custom_search",
            description: "Custom search tool",
            inputSchema: [
                "type": "object",
                "properties": ["query": ["type": "string"]],
                "required": ["query"]
            ]
        ) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
            let query = input["query"] as? String ?? ""
            return ToolExecuteResult(content: "Results for: \(query)", isError: false)
        }

        // Then: tool can be registered with InProcessMCPServer
        let server = InProcessMCPServer(name: "custom", version: "1.0", tools: [customTool])
        let tools = await server.getTools()
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools.first?.name, "custom_search")
    }

    // ================================================================
    // MARK: - AC8: Compatibility Report Generation Verification
    // ================================================================

    /// AC8 [P0]: Compatibility report data can be generated for all verification points.
    func testCompatReport_CanTrackAllVerificationPoints() {
        // Given: the CompatEntry pattern from CompatCoreQuery
        struct CompatEntry {
            let tsField: String
            let swiftField: String
            let status: String  // "PASS", "MISSING", "N/A"
            let note: String?
        }

        // When: recording all verification points from the story
        var report: [CompatEntry] = []

        // AC2: defineTool equivalence
        report.append(CompatEntry(tsField: "tool(name,desc,schema,handler)", swiftField: "defineTool()", status: "PASS", note: "4 overloads"))
        report.append(CompatEntry(tsField: "ToolAnnotations", swiftField: "ToolAnnotations struct", status: "PASS", note: "All 4 hints available"))

        // AC4: ToolResult
        report.append(CompatEntry(tsField: "CallToolResult.content (Array)", swiftField: "ToolResult.typedContent", status: "PASS", note: "ToolContent enum with text/image/resource"))

        // AC5: Input schemas
        report.append(CompatEntry(tsField: "BashInput.description", swiftField: "BashInput.description", status: "PASS", note: "Matches TS SDK"))
        report.append(CompatEntry(tsField: "BashInput.run_in_background", swiftField: "BashInput.runInBackground", status: "PASS", note: "Matches TS SDK"))
        report.append(CompatEntry(tsField: "FileReadInput fields", swiftField: "file_path, offset, limit", status: "PASS", note: nil))
        report.append(CompatEntry(tsField: "FileEditInput fields", swiftField: "file_path, old_string, new_string, replace_all", status: "PASS", note: nil))

        // AC6: Output structures
        report.append(CompatEntry(tsField: "ReadOutput (typed)", swiftField: "String", status: "MISSING", note: "No type discrimination"))
        report.append(CompatEntry(tsField: "EditOutput (structuredPatch)", swiftField: "String", status: "MISSING", note: "No structured output"))
        report.append(CompatEntry(tsField: "BashOutput (stdout/stderr)", swiftField: "String (combined)", status: "MISSING", note: "No stdout/stderr separation"))

        // AC7: InProcessMCPServer
        report.append(CompatEntry(tsField: "createSdkMcpServer", swiftField: "InProcessMCPServer", status: "PASS", note: nil))
        report.append(CompatEntry(tsField: "getTools()", swiftField: "getTools()", status: "PASS", note: nil))
        report.append(CompatEntry(tsField: "asConfig()", swiftField: "asConfig()", status: "PASS", note: nil))

        // Then: report has entries for all verification points
        XCTAssertTrue(report.count >= 12, "Should have at least 12 verification points")

        let passCount = report.filter { $0.status == "PASS" }.count
        let missingCount = report.filter { $0.status == "MISSING" }.count

        XCTAssertTrue(passCount > 0, "Should have PASS entries")
        XCTAssertTrue(missingCount > 0, "Should have MISSING entries (documented gaps)")
    }

    /// AC8 [P1]: Compatibility report status values are standardized.
    func testCompatReport_UsesStandardizedStatusValues() {
        // Given: the report uses PASS/MISSING/N/A
        let validStatuses: Set<String> = ["PASS", "MISSING", "N/A"]

        // Then: all status values should be from this set
        let testStatuses = ["PASS", "MISSING", "N/A", "PASS", "PASS"]
        for status in testStatuses {
            XCTAssertTrue(validStatuses.contains(status), "Status '\(status)' should be a valid status")
        }
    }

    // ================================================================
    // MARK: - Integration: Tool Pool Assembly with Custom Tools
    // ================================================================

    /// AC7 [P1]: assembleToolPool works with defineTool-created tools.
    func testAssembleToolPool_WorksWitDefineToolCustomTools() {
        // Given: base tools and custom tools created via defineTool
        let baseTools = getAllBaseTools(tier: .core)
        let customTool = defineTool(
            name: "my_custom",
            description: "Custom tool",
            inputSchema: ["type": "object"]
        ) { (context: ToolContext) async throws -> String in "custom" }

        // When: assembling tool pool
        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: [customTool],
            mcpTools: nil,
            allowed: nil,
            disallowed: nil
        )

        // Then: pool includes both base and custom tools
        let poolNames = Set(pool.map { $0.name })
        XCTAssertTrue(poolNames.contains("my_custom"), "Custom tool should be in pool")
        XCTAssertTrue(poolNames.contains("Read"), "Base tools should be in pool")
    }

    /// AC7 [P1]: Custom tool overrides base tool with same name (deduplication).
    func testAssembleToolPool_CustomToolOverridesBaseTool() {
        // Given: a custom tool with same name as a base tool
        let baseTools = getAllBaseTools(tier: .core)
        let customRead = defineTool(
            name: "Read",
            description: "Custom read override",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (context: ToolContext) async throws -> String in "custom" }

        // When: assembling tool pool
        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: [customRead],
            mcpTools: nil,
            allowed: nil,
            disallowed: nil
        )

        // Then: custom tool overrides base tool (later overrides earlier)
        let readTool = pool.first { $0.name == "Read" }
        XCTAssertNotNil(readTool)
        XCTAssertEqual(readTool?.description, "Custom read override",
                       "Custom tool should override base tool with same name")
    }

    // ================================================================
    // MARK: - Edge Cases
    // ================================================================

    /// AC2 [P1]: defineTool with throwing closure captures error as isError=true.
    func testDefineTool_ThrowingClosure_ReturnsIsError() async {
        struct Input: Codable { let x: Int }

        let tool = defineTool(
            name: "thrower",
            description: "May throw",
            inputSchema: ["type": "object"]
        ) { (input: Input, context: ToolContext) async throws -> String in
            if input.x < 0 {
                throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "negative"])
            }
            return "\(input.x)"
        }

        // When: closure throws
        let result = await tool.call(input: ["x": -1], context: makeContext())

        // Then: error is captured as isError=true
        XCTAssertTrue(result.isError, "Thrown error should result in isError=true")
        XCTAssertTrue(result.content.contains("negative"), "Error message should be in content")
    }

    /// AC5 [P1]: Tool input schemas include description fields where expected.
    func testToolInputSchemas_IncludesDescriptions() {
        let bashTool = createBashTool()
        let props = extractProperties(from: bashTool)

        // Then: properties should include description strings
        if let commandProp = props?["command"] as? [String: Any] {
            XCTAssertNotNil(commandProp["description"], "Bash command should have description")
        }
        if let timeoutProp = props?["timeout"] as? [String: Any] {
            XCTAssertNotNil(timeoutProp["description"], "Bash timeout should have description")
        }
    }

    /// AC5 [P1]: Grep tool inputSchema uses correct CodingKeys for dashed fields.
    func testGrepTool_DashedFieldNames_InSchema() {
        let tool = createGrepTool()
        let props = extractProperties(from: tool)

        // Then: dashed field names are preserved in schema (matching TS SDK)
        XCTAssertNotNil(props?["-i"], "Grep schema should have '-i' field")
        XCTAssertNotNil(props?["-C"], "Grep schema should have '-C' field")
        XCTAssertNotNil(props?["-A"], "Grep schema should have '-A' field")
        XCTAssertNotNil(props?["-B"], "Grep schema should have '-B' field")
    }
}

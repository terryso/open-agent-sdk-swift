import XCTest
@testable import OpenAgentSDK

// MARK: - defineTool End-to-End Integration Tests (Story 3.2)

/// ATDD Integration tests for Story 3.2 -- End-to-end custom tool invocation.
/// These tests simulate what the tool executor (Story 3.3) will do:
/// 1. LLM returns a `tool_use` content block with `id` and `input`
/// 2. Tool executor finds the registered tool by name
/// 3. Tool executor calls `tool.call(input:context:)` with the raw input dict
///    and a ToolContext containing the toolUseId
/// 4. Tool executor receives the ToolResult and formats it as a `tool_result` message
final class DefineToolIntegrationTests: XCTestCase {

    // MARK: - Helpers

    /// Simulates a tool_use content block returned by the LLM.
    private func buildToolUseBlock(id: String, name: String, input: [String: Any]) -> [String: Any] {
        return [
            "type": "tool_use",
            "id": id,
            "name": name,
            "input": input
        ]
    }

    /// Creates a simple custom tool for testing.
    private func makeUpperCaseTool() -> ToolProtocol {
        struct UpperInput: Codable {
            let text: String
        }

        return defineTool(
            name: "upper_case",
            description: "Convert text to uppercase",
            inputSchema: [
                "type": "object",
                "properties": ["text": ["type": "string"]],
                "required": ["text"]
            ],
            isReadOnly: true
        ) { (input: UpperInput, context: ToolContext) async -> String in
            return input.text.uppercased()
        }
    }

    /// Creates a custom tool that throws on execution.
    private func makeFailingTool() -> ToolProtocol {
        struct Input: Codable {
            let value: String
        }

        return defineTool(
            name: "failing_tool",
            description: "A tool that always fails",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: Input, context: ToolContext) async throws -> String in
            throw NSError(domain: "tool", code: 1, userInfo: [NSLocalizedDescriptionKey: "Intentional failure"])
        }
    }

    /// Safely extracts tool_use fields from a mock LLM block, failing the test if missing.
    private func extractToolUseFields(
        from block: [String: Any],
        file: StaticString = #file,
        line: UInt = #line
    ) -> (toolUseId: String, input: [String: Any])? {
        guard let toolUseId = block["id"] as? String else {
            XCTFail("Missing 'id' in tool_use block", file: file, line: line)
            return nil
        }
        guard let input = block["input"] as? [String: Any] else {
            XCTFail("Missing 'input' dictionary in tool_use block", file: file, line: line)
            return nil
        }
        return (toolUseId, input)
    }

    // MARK: - AC2: End-to-End Custom Tool Invocation (Simulated)

    /// AC2 [P0]: Given a tool_use block from the LLM, the tool decodes JSON input,
    /// executes the closure, and returns the correct ToolResult.
    func testEndToEnd_CustomTool_DecodesAndExecutes() async {
        let tool = makeUpperCaseTool()
        let toolUseBlock = buildToolUseBlock(
            id: "toolu_e2e_001",
            name: "upper_case",
            input: ["text": "hello world"]
        )

        guard let fields = extractToolUseFields(from: toolUseBlock) else { return }
        let context = ToolContext(cwd: "/workspace", toolUseId: fields.toolUseId)

        let result = await tool.call(input: fields.input, context: context)

        XCTAssertFalse(result.isError,
                       "Tool execution should succeed")
        XCTAssertEqual(result.content, "HELLO WORLD",
                       "Tool should have converted text to uppercase")
        XCTAssertEqual(result.toolUseId, "toolu_e2e_001",
                       "ToolResult.toolUseId should match the LLM-provided tool_use_id")
    }

    /// AC2 [P0]: Given invalid JSON input from the LLM, the tool returns isError=true.
    func testEndToEnd_CustomTool_InvalidInput_ReturnsError() async {
        let tool = makeUpperCaseTool()
        let toolUseBlock = buildToolUseBlock(
            id: "toolu_e2e_002",
            name: "upper_case",
            input: ["wrong_field": "value"]
        )

        guard let fields = extractToolUseFields(from: toolUseBlock) else { return }
        let context = ToolContext(cwd: "/workspace", toolUseId: fields.toolUseId)

        let result = await tool.call(input: fields.input, context: context)

        XCTAssertTrue(result.isError,
                       "Invalid input should produce isError=true")
        XCTAssertEqual(result.toolUseId, "toolu_e2e_002",
                       "toolUseId should still be set even when decode fails")
    }

    /// AC3 [P0]: Given a tool whose closure throws, the error is caught and isError=true.
    func testEndToEnd_CustomTool_ClosureError_CaughtGracefully() async {
        let tool = makeFailingTool()
        let toolUseBlock = buildToolUseBlock(
            id: "toolu_e2e_003",
            name: "failing_tool",
            input: ["value": "test"]
        )

        guard let fields = extractToolUseFields(from: toolUseBlock) else { return }
        let context = ToolContext(cwd: "/workspace", toolUseId: fields.toolUseId)

        let result = await tool.call(input: fields.input, context: context)

        XCTAssertTrue(result.isError,
                       "Closure error should be caught and returned as isError=true")
        XCTAssertTrue(result.content.contains("Intentional failure") || result.content.contains("Error"),
                       "Error content should describe what went wrong, got: \(result.content)")
        XCTAssertEqual(result.toolUseId, "toolu_e2e_003",
                       "toolUseId should be set even when closure throws")
    }

    /// AC4 [P0]: toolUseId correctly propagates from tool_use block through to ToolResult.
    func testEndToEnd_ToolUseId_PropagationFromLLMBlock() async {
        struct CSVInput: Codable {
            let path: String
        }

        let tool = defineTool(
            name: "parse_csv",
            description: "Parse CSV file",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: CSVInput, context: ToolContext) async -> String in
            return "Parsed \(input.path)"
        }

        let toolUseId = "toolu_01JAXYZ123ABC"
        let input: [String: Any] = ["path": "/data/sales.csv"]
        let context = ToolContext(cwd: "/home/user", toolUseId: toolUseId)

        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.toolUseId, "toolu_01JAXYZ123ABC",
                       "toolUseId must match exactly what the LLM provided")
        XCTAssertEqual(result.content, "Parsed /data/sales.csv")
    }

    /// AC5 [P0]: Structured result (ToolExecuteResult) integrates end-to-end.
    func testEndToEnd_StructuredResult_ToolExecuteResult() async {
        struct Input: Codable {
            let filename: String
        }

        let tool = defineTool(
            name: "validate_file",
            description: "Validate a file exists",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: Input, context: ToolContext) async -> ToolExecuteResult in
            return ToolExecuteResult(
                content: "File does not exist: \(input.filename)",
                isError: true
            )
        }

        let toolUseId = "toolu_struct_001"
        let input: [String: Any] = ["filename": "nonexistent.txt"]
        let context = ToolContext(cwd: "/tmp", toolUseId: toolUseId)

        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError,
                       "Structured error should produce isError=true in ToolResult")
        XCTAssertEqual(result.content, "File does not exist: nonexistent.txt")
        XCTAssertEqual(result.toolUseId, "toolu_struct_001")
    }

    /// AC1 [P1]: No-input tool works end-to-end in simulated tool executor flow.
    func testEndToEnd_NoInputTool_WorksInToolExecutorFlow() async {
        let tool = defineTool(
            name: "health_check",
            description: "Check system health",
            inputSchema: ["type": "object", "properties": [:]],
            isReadOnly: true
        ) { (context: ToolContext) async -> String in
            return "healthy (cwd: \(context.cwd))"
        }

        let toolUseId = "toolu_health_001"
        let input: [String: Any] = [:]
        let context = ToolContext(cwd: "/production", toolUseId: toolUseId)

        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content, "healthy (cwd: /production)")
        XCTAssertEqual(result.toolUseId, "toolu_health_001")
    }

    // MARK: - AC2: Multiple Tools, Selective Invocation

    /// AC2 [P1]: When multiple tools are registered, the correct one is invoked by name.
    func testEndToEnd_MultipleTools_CorrectToolInvoked() async {
        struct EchoInput: Codable { let msg: String }
        struct ReverseInput: Codable { let text: String }

        let echoTool = defineTool(
            name: "echo",
            description: "Echo input",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: EchoInput, context: ToolContext) async -> String in
            return input.msg
        }

        let reverseTool = defineTool(
            name: "reverse",
            description: "Reverse text",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: ReverseInput, context: ToolContext) async -> String in
            return String(input.text.reversed())
        }

        let toolsByName: [String: ToolProtocol] = [
            "echo": echoTool,
            "reverse": reverseTool
        ]

        let toolUseBlock = buildToolUseBlock(
            id: "toolu_multi_001",
            name: "reverse",
            input: ["text": "hello"]
        )

        // Safely extract and look up tool
        guard let toolName = toolUseBlock["name"] as? String else {
            XCTFail("Missing 'name' in tool_use block")
            return
        }
        guard let tool = toolsByName[toolName] else {
            XCTFail("Tool '\(toolName)' not found in registry")
            return
        }
        guard let input = toolUseBlock["input"] as? [String: Any] else {
            XCTFail("Missing 'input' in tool_use block")
            return
        }
        guard let toolUseId = toolUseBlock["id"] as? String else {
            XCTFail("Missing 'id' in tool_use block")
            return
        }
        let context = ToolContext(cwd: "/tmp", toolUseId: toolUseId)

        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content, "olleh",
                       "Reverse tool should have reversed the input")
        XCTAssertEqual(result.toolUseId, "toolu_multi_001")
    }
}

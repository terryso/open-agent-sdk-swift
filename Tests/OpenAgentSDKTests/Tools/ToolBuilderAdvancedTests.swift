import XCTest
@testable import OpenAgentSDK

// MARK: - defineTool Advanced Tests (Story 3.2)

/// ATDD RED PHASE: Tests for Story 3.2 -- Custom Tool defineTool Extensions.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `CodableTool.call()` wraps executeClosure in do/catch (AC3)
///   - `ToolContext` gains a `toolUseId` field (AC4)
///   - `ToolExecuteResult` type is defined (AC5)
///   - New `defineTool` overloads are added for structured results and no-input tools (AC5, AC1)
///   - `ToolProtocol.call()` propagates toolUseId from context to ToolResult (AC4)
/// TDD Phase: RED (feature not implemented yet)
final class ToolBuilderAdvancedTests: XCTestCase {

    // MARK: - AC3: Execute Closure Error Capture

    /// AC3 [P0]: When the execute closure throws an error, the tool returns ToolResult(isError: true).
    func testDefineTool_ExecuteClosureThrows_CaughtAsIsError() async {
        // Given: a tool whose execute closure throws
        struct Input: Codable {
            let value: String
        }

        struct ToolExecutionError: Error {}

        let tool = defineTool(
            name: "failing_tool",
            description: "A tool that throws",
            inputSchema: ["type": "object", "properties": ["value": ["type": "string"]]],
            isReadOnly: true
        ) { (input: Input, context: ToolContext) async throws -> String in
            throw ToolExecutionError()
        }

        // When: calling with valid input (decode succeeds but closure throws)
        let rawInput: [String: Any] = ["value": "test"]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: rawInput, context: context)

        // Then: the error is caught and returned as isError=true
        XCTAssertTrue(result.isError,
                       "Execute closure error should be caught and returned as isError=true, got isError=false")
    }

    /// AC3 [P0]: When the execute closure throws, the error message is included in ToolResult.content.
    func testDefineTool_ExecuteClosureThrows_ErrorMessageIncluded() async {
        // Given: a tool whose execute closure throws a descriptive error
        struct Input: Codable {
            let x: Int
        }

        struct DescriptiveError: Error, LocalizedError {
            let errorDescription: String? = "File not found at /tmp/missing.txt"
        }

        let tool = defineTool(
            name: "descriptive_fail",
            description: "Throws descriptive error",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: Input, context: ToolContext) async throws -> String in
            throw DescriptiveError()
        }

        // When: calling with valid input
        let rawInput: [String: Any] = ["x": 42]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: rawInput, context: context)

        // Then: the error message is captured in content
        XCTAssertTrue(result.isError,
                       "Should be an error result")
        XCTAssertTrue(result.content.contains("Error") || result.content.contains("not found"),
                       "Error content should include the error description, got: \(result.content)")
    }

    /// AC3 [P1]: When the execute closure throws a generic Error, it is still caught.
    func testDefineTool_ExecuteClosureThrows_GenericErrorCaught() async {
        // Given: a tool that throws a generic NSError
        struct Input: Codable {}

        let tool = defineTool(
            name: "generic_fail",
            description: "Throws generic error",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: Input, context: ToolContext) async throws -> String in
            throw NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "generic failure"])
        }

        // When: calling the tool
        let rawInput: [String: Any] = [:]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: rawInput, context: context)

        // Then: error is caught
        XCTAssertTrue(result.isError, "Generic NSError should be caught as isError=true")
        XCTAssertTrue(result.content.contains("generic failure") || result.content.contains("Error"),
                       "Content should contain error information, got: \(result.content)")
    }

    // MARK: - AC4: toolUseId Propagation via ToolContext

    /// AC4 [P0]: ToolContext should have a toolUseId field.
    func testToolContext_HasToolUseIdField() {
        // Given/When: creating a ToolContext with toolUseId
        let context = ToolContext(cwd: "/tmp", toolUseId: "toolu_abc123")

        // Then: toolUseId is accessible
        XCTAssertEqual(context.toolUseId, "toolu_abc123",
                       "ToolContext should expose toolUseId field")
    }

    /// AC4 [P0]: toolUseId from ToolContext propagates to ToolResult.
    func testDefineTool_ToolUseId_PropagatedViaContext() async {
        // Given: a tool that should propagate toolUseId
        struct Input: Codable {
            let command: String
        }

        let tool = defineTool(
            name: "run_cmd",
            description: "Run a command",
            inputSchema: ["type": "object"],
            isReadOnly: false
        ) { (input: Input, context: ToolContext) async -> String in
            return "Executed: \(input.command)"
        }

        // When: calling with a context that has a toolUseId
        let rawInput: [String: Any] = ["command": "ls -la"]
        let context = ToolContext(cwd: "/home", toolUseId: "toolu_xyz789")

        let result = await tool.call(input: rawInput, context: context)

        // Then: the ToolResult's toolUseId matches the one from context
        XCTAssertEqual(result.toolUseId, "toolu_xyz789",
                       "ToolResult.toolUseId should be populated from ToolContext.toolUseId")
        XCTAssertFalse(result.isError, "Should succeed")
        XCTAssertEqual(result.content, "Executed: ls -la")
    }

    /// AC4 [P0]: Empty toolUseId in context results in empty toolUseId in result.
    func testDefineTool_ToolUseId_EmptyWhenNotProvided() async {
        // Given: a tool called with the old ToolContext(cwd:) initializer
        struct Input: Codable {
            let x: Int
        }

        let tool = defineTool(
            name: "simple",
            description: "Simple tool",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: Input, context: ToolContext) async -> String in
            return "\(input.x)"
        }

        // When: calling with context that has no toolUseId (empty string)
        let rawInput: [String: Any] = ["x": 7]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: rawInput, context: context)

        // Then: toolUseId in result is empty (backward compatible)
        XCTAssertEqual(result.toolUseId, "",
                       "When context has no toolUseId, result should have empty toolUseId")
    }

    // MARK: - AC5: Structured Return Value (ToolExecuteResult)

    /// AC5 [P0]: ToolExecuteResult type should exist with content and isError fields.
    func testToolExecuteResult_ExistsWithCorrectFields() {
        // Given/When: creating a ToolExecuteResult
        let successResult = ToolExecuteResult(content: "Success!", isError: false)
        let errorResult = ToolExecuteResult(content: "Something went wrong", isError: true)

        // Then: fields are accessible
        XCTAssertEqual(successResult.content, "Success!")
        XCTAssertFalse(successResult.isError)
        XCTAssertEqual(errorResult.content, "Something went wrong")
        XCTAssertTrue(errorResult.isError)
    }

    /// AC5 [P0]: defineTool overload accepting ToolExecuteResult closure works for success.
    func testDefineTool_StructuredResult_Success() async {
        // Given: a tool using the structured result overload
        struct Input: Codable {
            let query: String
        }

        let tool = defineTool(
            name: "search",
            description: "Search for items",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: Input, context: ToolContext) async -> ToolExecuteResult in
            return ToolExecuteResult(content: "Found 3 results for '\(input.query)'", isError: false)
        }

        // When: calling the tool
        let rawInput: [String: Any] = ["query": "swift"]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: rawInput, context: context)

        // Then: result reflects the structured output
        XCTAssertFalse(result.isError,
                       "Structured success should produce isError=false")
        XCTAssertEqual(result.content, "Found 3 results for 'swift'",
                       "Content should match the structured result")
    }

    /// AC5 [P0]: defineTool overload with ToolExecuteResult propagates isError=true.
    func testDefineTool_StructuredResult_IsErrorTrue() async {
        // Given: a tool that returns a structured error result
        struct Input: Codable {
            let path: String
        }

        let tool = defineTool(
            name: "check_file",
            description: "Check if file exists",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: Input, context: ToolContext) async -> ToolExecuteResult in
            return ToolExecuteResult(content: "File not found: \(input.path)", isError: true)
        }

        // When: calling the tool
        let rawInput: [String: Any] = ["path": "/nonexistent"]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: rawInput, context: context)

        // Then: isError propagates from ToolExecuteResult to ToolResult
        XCTAssertTrue(result.isError,
                       "Structured error should produce isError=true in ToolResult")
        XCTAssertEqual(result.content, "File not found: /nonexistent")
    }

    // MARK: - AC1: No-Input Convenience Overload

    /// AC1 [P1]: defineTool overload without Codable Input type works correctly.
    func testDefineTool_NoInputOverload_Works() async {
        // Given: a tool defined without an Input type (convenience overload)
        let tool = defineTool(
            name: "ping",
            description: "Ping the system",
            inputSchema: ["type": "object", "properties": [:]],
            isReadOnly: true
        ) { (context: ToolContext) async -> String in
            return "pong from \(context.cwd)"
        }

        // When: calling the tool with an empty dictionary
        let rawInput: [String: Any] = [:]
        let context = ToolContext(cwd: "/workspace")

        let result = await tool.call(input: rawInput, context: context)

        // Then: the tool returns the expected output
        XCTAssertFalse(result.isError,
                       "No-input tool should succeed")
        XCTAssertEqual(result.content, "pong from /workspace",
                       "No-input tool should receive context and return correct result")
    }

    /// AC1 [P1]: No-input tool still receives ToolContext with toolUseId.
    func testDefineTool_NoInputOverload_GetsContext() async {
        // Given: a no-input tool that needs context
        let tool = defineTool(
            name: "list_tools",
            description: "List available tools",
            inputSchema: ["type": "object", "properties": [:]],
            isReadOnly: true
        ) { (context: ToolContext) async -> String in
            return "cwd=\(context.cwd), toolUseId=\(context.toolUseId)"
        }

        // When: calling with context that has toolUseId
        let rawInput: [String: Any] = [:]
        let context = ToolContext(cwd: "/home", toolUseId: "toolu_ctx_test")

        let result = await tool.call(input: rawInput, context: context)

        // Then: context fields are accessible inside the closure
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content, "cwd=/home, toolUseId=toolu_ctx_test")
    }

    // MARK: - AC1: Backward Compatibility

    /// AC1 [P0]: Existing defineTool<Input: Codable>(...) calls still work unchanged.
    func testDefineTool_BackwardCompatibility_ExistingSignatureStillWorks() async {
        // Given: a tool using the original defineTool signature from Story 3.1
        struct CSVInput: Codable {
            let path: String
            let delimiter: String
        }

        let tool = defineTool(
            name: "parse_csv",
            description: "Parse a CSV file",
            inputSchema: [
                "type": "object",
                "properties": [
                    "path": ["type": "string"],
                    "delimiter": ["type": "string"]
                ],
                "required": ["path"]
            ],
            isReadOnly: true
        ) { (input: CSVInput, context: ToolContext) async -> String in
            return "Parsed \(input.path) with delimiter '\(input.delimiter)'"
        }

        // When: calling with valid input
        let rawInput: [String: Any] = ["path": "/data/file.csv", "delimiter": ","]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: rawInput, context: context)

        // Then: the original signature still works
        XCTAssertFalse(result.isError,
                       "Backward-compatible defineTool should still work")
        XCTAssertEqual(result.content, "Parsed /data/file.csv with delimiter ','")
    }

    /// AC1 [P0]: Backward compat -- tool defined with old signature still returns empty toolUseId.
    func testDefineTool_BackwardCompatibility_DefaultToolUseId() async {
        // Given: a tool defined with the old signature, called without toolUseId
        struct Input: Codable {
            let value: Int
        }

        let tool = defineTool(
            name: "double",
            description: "Double a number",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: Input, context: ToolContext) async -> String in
            return "\(input.value * 2)"
        }

        // When: calling with ToolContext(cwd:) -- no toolUseId
        let rawInput: [String: Any] = ["value": 21]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: rawInput, context: context)

        // Then: toolUseId defaults to empty string (backward compatible)
        XCTAssertEqual(result.toolUseId, "",
                       "Default toolUseId should be empty string for backward compat")
        XCTAssertEqual(result.content, "42")
    }
}

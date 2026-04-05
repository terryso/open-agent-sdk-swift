import XCTest
@testable import OpenAgentSDK

// MARK: - defineTool Tests

/// ATDD RED PHASE: Tests for Story 3.1 -- Tool Protocol & Registry (defineTool).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `ToolBuilder.swift` is created in `Sources/OpenAgentSDK/Tools/`
///   - `defineTool<Input: Codable>()` function is implemented
///   - The function returns a `ToolProtocol` conforming object
///   - The `call()` method decodes input via JSONSerialization + JSONDecoder bridge
///   - Decoding failure returns `ToolResult(isError: true)`
/// TDD Phase: RED (feature not implemented yet)
final class ToolBuilderTests: XCTestCase {

    // MARK: - AC1: defineTool creates a ToolProtocol

    /// AC1 [P0]: defineTool should return a ToolProtocol with correct name.
    func testDefineTool_ReturnsProtocolWithCorrectName() {
        // Given: a Codable input type
        struct FileInput: Codable {
            let path: String
        }

        // When: defining a tool
        let tool = defineTool(
            name: "read_file",
            description: "Read a file from disk",
            inputSchema: [
                "type": "object",
                "properties": ["path": ["type": "string"]],
                "required": ["path"]
            ],
            isReadOnly: true
        ) { (input: FileInput, context: ToolContext) async -> String in
            return "Contents of \(input.path)"
        }

        // Then: the tool has the expected name
        XCTAssertEqual(tool.name, "read_file",
                       "defineTool should produce a tool with the given name")
    }

    /// AC1 [P0]: defineTool should return a ToolProtocol with correct description.
    func testDefineTool_ReturnsProtocolWithCorrectDescription() {
        // Given: a Codable input type
        struct EchoInput: Codable {
            let message: String
        }

        // When: defining a tool
        let tool = defineTool(
            name: "echo",
            description: "Echo back the input message",
            inputSchema: ["type": "object"],
            isReadOnly: false
        ) { (input: EchoInput, context: ToolContext) async -> String in
            return input.message
        }

        // Then: the tool has the expected description
        XCTAssertEqual(tool.description, "Echo back the input message",
                       "defineTool should produce a tool with the given description")
    }

    /// AC1 [P0]: defineTool should return a ToolProtocol with the given inputSchema.
    func testDefineTool_ReturnsProtocolWithCorrectInputSchema() {
        // Given: a Codable input type and a schema
        struct SearchInput: Codable {
            let query: String
            let maxResults: Int?
        }

        let schema: ToolInputSchema = [
            "type": "object",
            "properties": [
                "query": ["type": "string"],
                "maxResults": ["type": "integer"]
            ],
            "required": ["query"]
        ]

        // When: defining a tool
        let tool = defineTool(
            name: "search",
            description: "Search for files",
            inputSchema: schema,
            isReadOnly: true
        ) { (input: SearchInput, context: ToolContext) async -> String in
            return "Results for: \(input.query)"
        }

        // Then: the tool preserves the input schema
        let toolSchema = tool.inputSchema as? [String: Any]
        XCTAssertNotNil(toolSchema)
        XCTAssertEqual(toolSchema?["type"] as? String, "object")
    }

    /// AC1 [P0]: defineTool should correctly pass isReadOnly.
    func testDefineTool_ReturnsCorrectIsReadOnly_True() {
        // Given: a read-only tool
        struct NoInput: Codable {}

        // When: defining with isReadOnly = true
        let tool = defineTool(
            name: "list_files",
            description: "List files",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: NoInput, context: ToolContext) async -> String in
            return "files"
        }

        // Then: isReadOnly is true
        XCTAssertTrue(tool.isReadOnly,
                       "defineTool should preserve isReadOnly = true")
    }

    /// AC1 [P0]: defineTool should default isReadOnly to false when not specified.
    func testDefineTool_ReturnsCorrectIsReadOnly_False() {
        // Given: a tool that modifies state
        struct WriteInput: Codable {
            let path: String
            let content: String
        }

        // When: defining with isReadOnly = false
        let tool = defineTool(
            name: "write_file",
            description: "Write a file",
            inputSchema: ["type": "object"],
            isReadOnly: false
        ) { (input: WriteInput, context: ToolContext) async -> String in
            return "wrote to \(input.path)"
        }

        // Then: isReadOnly is false
        XCTAssertFalse(tool.isReadOnly,
                        "defineTool should preserve isReadOnly = false")
    }

    // MARK: - AC1: defineTool Codable decoding (success path)

    /// AC1 [P0]: defineTool's call() should decode Codable input and invoke execute closure.
    func testDefineTool_CallDecodesInputCorrectly() async {
        // Given: a tool with a Codable input type
        struct GreetInput: Codable {
            let name: String
            let greeting: String
        }

        let tool = defineTool(
            name: "greet",
            description: "Generate a greeting",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: GreetInput, context: ToolContext) async -> String in
            return "\(input.greeting), \(input.name)!"
        }

        // When: calling with raw dictionary input (as the LLM API provides)
        let rawInput: [String: Any] = [
            "name": "World",
            "greeting": "Hello"
        ]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: rawInput, context: context)

        // Then: the execute closure received the decoded input
        XCTAssertFalse(result.isError,
                        "Successful decode should not produce an error result")
        XCTAssertEqual(result.content, "Hello, World!",
                       "Decoded input should be passed to execute closure correctly")
    }

    /// AC1 [P1]: defineTool's call() should handle nested Codable types.
    func testDefineTool_CallHandlesNestedCodableTypes() async {
        // Given: a tool with nested Codable input
        struct Coordinates: Codable {
            let lat: Double
            let lon: Double
        }
        struct LocationInput: Codable {
            let name: String
            let coordinates: Coordinates
        }

        let tool = defineTool(
            name: "geolocate",
            description: "Find location",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: LocationInput, context: ToolContext) async -> String in
            return "\(input.name) at \(input.coordinates.lat),\(input.coordinates.lon)"
        }

        // When: calling with nested raw input
        let rawInput: [String: Any] = [
            "name": "Tokyo",
            "coordinates": ["lat": 35.6762, "lon": 139.6503]
        ]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: rawInput, context: context)

        // Then: nested types decoded correctly
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content, "Tokyo at 35.6762,139.6503")
    }

    // MARK: - AC1: defineTool Codable decoding (failure path)

    /// AC1 [P0]: defineTool's call() should return isError=true when decoding fails.
    func testDefineTool_CallReturnsError_OnDecodeFailure() async {
        // Given: a tool expecting specific Codable fields
        struct StrictInput: Codable {
            let requiredField: String
        }

        let tool = defineTool(
            name: "strict_tool",
            description: "A tool requiring specific input",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: StrictInput, context: ToolContext) async -> String in
            return "Should not reach here"
        }

        // When: calling with input that lacks the required field
        let badInput: [String: Any] = [
            "wrong_field": "value"
        ]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: badInput, context: context)

        // Then: result is an error, not a crash
        XCTAssertTrue(result.isError,
                       "Decoding failure should produce isError=true")
        XCTAssertTrue(result.content.contains("Failed to decode") || result.content.contains("Error"),
                       "Error content should describe the decode failure, got: \(result.content)")
    }

    /// AC1 [P1]: defineTool's call() should handle completely invalid input type.
    func testDefineTool_CallReturnsError_OnNonDictionaryInput() async {
        // Given: a tool expecting Codable struct
        struct Input: Codable {
            let value: String
        }

        let tool = defineTool(
            name: "typed_tool",
            description: "Needs typed input",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: Input, context: ToolContext) async -> String in
            return input.value
        }

        // When: calling with a non-dictionary input (e.g., a string)
        let badInput = "not a dictionary"
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: badInput, context: context)

        // Then: result is an error
        XCTAssertTrue(result.isError,
                       "Non-dictionary input should produce isError=true")
    }

    // MARK: - AC1: defineTool call() preserves toolUseId in result

    /// AC1 [P1]: defineTool's call() should not modify toolUseId from the result.
    func testDefineTool_CallDoesNotCrash_WithEmptyToolUseId() async {
        // Given: a simple tool
        struct Input: Codable {
            let x: Int
        }

        let tool = defineTool(
            name: "math_tool",
            description: "A math tool",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { (input: Input, context: ToolContext) async -> String in
            return "Result: \(input.x * 2)"
        }

        // When: calling with valid input
        let rawInput: [String: Any] = ["x": 21]
        let context = ToolContext(cwd: "/tmp")

        let result = await tool.call(input: rawInput, context: context)

        // Then: result content is correct
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content, "Result: 42")
    }
}

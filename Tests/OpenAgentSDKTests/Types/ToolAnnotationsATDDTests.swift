import XCTest
@testable import OpenAgentSDK

// MARK: - ToolAnnotations ATDD Tests (Story 17-3)

/// ATDD RED PHASE: Tests for Story 17-3 AC1 -- ToolAnnotations type.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `ToolAnnotations` struct is added to `Types/ToolTypes.swift` with 4 Bool fields
///   - `ToolProtocol` gains an optional `annotations: ToolAnnotations?` property
///   - Protocol extension provides default `nil` implementation for `annotations`
///   - `ToolAnnotations` conforms to `Sendable` and `Equatable`
///   - All `defineTool()` overloads accept an `annotations` parameter
///   - `toApiTool()` includes `"annotations"` key when non-nil
/// TDD Phase: RED (feature not implemented yet)
final class ToolAnnotationsATDDTests: XCTestCase {

    // MARK: - AC1: ToolAnnotations struct existence and fields

    /// AC1 [P0]: ToolAnnotations type should exist with 4 hint fields.
    func testToolAnnotations_ExistsWithFourHintFields() {
        // Given: the TS SDK has ToolAnnotations with 4 hints
        // When: creating a ToolAnnotations instance
        let annotations = ToolAnnotations(
            readOnlyHint: true,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: false
        )

        // Then: all 4 fields are accessible
        XCTAssertTrue(annotations.readOnlyHint,
                       "readOnlyHint should be true")
        XCTAssertFalse(annotations.destructiveHint,
                        "destructiveHint should be false")
        XCTAssertTrue(annotations.idempotentHint,
                       "idempotentHint should be true")
        XCTAssertFalse(annotations.openWorldHint,
                        "openWorldHint should be false")
    }

    /// AC1 [P0]: ToolAnnotations default values match TS SDK defaults.
    /// TS SDK defaults: readOnlyHint=false, destructiveHint=true, idempotentHint=false, openWorldHint=false
    func testToolAnnotations_DefaultValues_MatchTsSdk() {
        // Given: TS SDK defaults destructiveHint to true, rest to false
        // When: creating ToolAnnotations with defaults
        let annotations = ToolAnnotations()

        // Then: defaults match TS SDK
        XCTAssertFalse(annotations.readOnlyHint,
                        "Default readOnlyHint should be false")
        XCTAssertTrue(annotations.destructiveHint,
                       "Default destructiveHint should be true (TS SDK default)")
        XCTAssertFalse(annotations.idempotentHint,
                        "Default idempotentHint should be false")
        XCTAssertFalse(annotations.openWorldHint,
                        "Default openWorldHint should be false")
    }

    // MARK: - AC1: ToolAnnotations Sendable conformance

    /// AC1 [P0]: ToolAnnotations should conform to Sendable.
    func testToolAnnotations_ConformsToSendable() {
        // Given: a ToolAnnotations instance
        let annotations = ToolAnnotations(readOnlyHint: true)

        // Then: it can be used in a Sendable context
        let _: any Sendable = annotations
    }

    // MARK: - AC1: ToolAnnotations Equatable conformance

    /// AC1 [P0]: ToolAnnotations should conform to Equatable.
    func testToolAnnotations_ConformsToEquatable() {
        // Given: two identical ToolAnnotations
        let a = ToolAnnotations(readOnlyHint: true, destructiveHint: false)
        let b = ToolAnnotations(readOnlyHint: true, destructiveHint: false)

        // Then: they are equal
        XCTAssertEqual(a, b)
    }

    /// AC1 [P0]: ToolAnnotations inequality works.
    func testToolAnnotations_Inequality() {
        // Given: two different ToolAnnotations
        let a = ToolAnnotations(readOnlyHint: true)
        let b = ToolAnnotations(readOnlyHint: false)

        // Then: they are not equal
        XCTAssertNotEqual(a, b)
    }

    // MARK: - AC1: ToolProtocol.annotations property

    /// AC1 [P0]: ToolProtocol should have an optional annotations property.
    func testToolProtocol_HasOptionalAnnotationsProperty() {
        // Given: a tool conforming to ToolProtocol
        struct AnnotatedTool: ToolProtocol, @unchecked Sendable {
            let name = "annotated_tool"
            let description = "An annotated tool"
            let inputSchema: ToolInputSchema = ["type": "object"]
            let isReadOnly = true
            let annotations: ToolAnnotations? = ToolAnnotations(readOnlyHint: true)

            func call(input: Any, context: ToolContext) async -> ToolResult {
                ToolResult(toolUseId: context.toolUseId, content: "ok", isError: false)
            }
        }

        // When: creating the tool
        let tool = AnnotatedTool()

        // Then: annotations is accessible and non-nil
        XCTAssertNotNil(tool.annotations,
                         "ToolProtocol should have annotations property")
        XCTAssertTrue(tool.annotations?.readOnlyHint ?? false,
                       "Annotations readOnlyHint should be true")
    }

    /// AC1 [P0]: ToolProtocol annotations should default to nil via protocol extension.
    func testToolProtocol_AnnotationsDefaultToNil() {
        // Given: a tool that does NOT specify annotations (existing tool pattern)
        struct LegacyTool: ToolProtocol, @unchecked Sendable {
            let name = "legacy_tool"
            let description = "A legacy tool without annotations"
            let inputSchema: ToolInputSchema = ["type": "object"]
            let isReadOnly = true

            func call(input: Any, context: ToolContext) async -> ToolResult {
                ToolResult(toolUseId: context.toolUseId, content: "legacy", isError: false)
            }
        }

        // When: creating a legacy tool
        let tool = LegacyTool()

        // Then: annotations is nil (protocol extension default)
        XCTAssertNil(tool.annotations,
                      "Default annotations should be nil for existing tools")
    }

    /// AC1 [P0]: All existing ToolProtocol conformances compile without modification.
    /// This tests backward compatibility - annotations is optional with default nil.
    func testToolProtocol_ExistingConformances_CompileWithoutModification() {
        // Given: a tool using the minimal ToolProtocol conformance (pre-17-3 style)
        struct MinimalTool: ToolProtocol, @unchecked Sendable {
            let name = "minimal"
            let description = "Minimal tool"
            let inputSchema: ToolInputSchema = ["type": "object"]
            let isReadOnly = false

            func call(input: Any, context: ToolContext) async -> ToolResult {
                ToolResult(toolUseId: context.toolUseId, content: "minimal", isError: false)
            }
        }

        // When: creating the tool (should compile without adding annotations)
        let tool = MinimalTool()

        // Then: tool works normally, annotations defaults to nil
        XCTAssertEqual(tool.name, "minimal")
        XCTAssertNil(tool.annotations)
    }

    // MARK: - AC1: defineTool() with annotations parameter

    /// AC1 [P0]: defineTool (Codable+String) accepts annotations parameter.
    func testDefineTool_CodableString_AcceptsAnnotations() {
        // Given: a tool with annotations
        struct Input: Codable { let path: String }

        // When: defining a tool with annotations
        let annotations = ToolAnnotations(readOnlyHint: true, destructiveHint: false)
        let tool = defineTool(
            name: "safe_read",
            description: "A safe read tool",
            inputSchema: ["type": "object"],
            isReadOnly: true,
            annotations: annotations
        ) { (input: Input, context: ToolContext) async throws -> String in
            return "Contents of \(input.path)"
        }

        // Then: tool has annotations set
        XCTAssertNotNil(tool.annotations,
                         "Tool defined with annotations should have non-nil annotations")
        XCTAssertTrue(tool.annotations?.readOnlyHint ?? false)
    }

    /// AC1 [P0]: defineTool (Codable+ToolExecuteResult) accepts annotations parameter.
    func testDefineTool_CodableResult_AcceptsAnnotations() {
        // Given: a tool with annotations returning ToolExecuteResult
        struct Input: Codable { let x: Int }

        // When: defining a tool with annotations
        let annotations = ToolAnnotations(destructiveHint: true)
        let tool = defineTool(
            name: "dangerous_op",
            description: "A dangerous tool",
            inputSchema: ["type": "object"],
            isReadOnly: false,
            annotations: annotations
        ) { (input: Input, context: ToolContext) async throws -> ToolExecuteResult in
            return ToolExecuteResult(content: "\(input.x)", isError: false)
        }

        // Then: tool has annotations with destructiveHint=true
        XCTAssertNotNil(tool.annotations)
        XCTAssertTrue(tool.annotations?.destructiveHint ?? false)
    }

    /// AC1 [P0]: defineTool (NoInput) accepts annotations parameter.
    func testDefineTool_NoInput_AcceptsAnnotations() {
        // Given: a no-input tool with annotations
        let annotations = ToolAnnotations(readOnlyHint: true, idempotentHint: true)
        let tool = defineTool(
            name: "health_check",
            description: "Health check",
            inputSchema: ["type": "object"],
            isReadOnly: true,
            annotations: annotations
        ) { (context: ToolContext) async throws -> String in
            return "OK"
        }

        // Then: tool has annotations
        XCTAssertNotNil(tool.annotations)
        XCTAssertTrue(tool.annotations?.idempotentHint ?? false)
    }

    /// AC1 [P0]: defineTool (Raw Dictionary) accepts annotations parameter.
    func testDefineTool_RawDictionary_AcceptsAnnotations() {
        // Given: a raw dictionary tool with annotations
        let annotations = ToolAnnotations(openWorldHint: true)
        let tool = defineTool(
            name: "web_tool",
            description: "A web tool",
            inputSchema: ["type": "object"],
            isReadOnly: false,
            annotations: annotations
        ) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
            return ToolExecuteResult(content: "web result", isError: false)
        }

        // Then: tool has annotations with openWorldHint=true
        XCTAssertNotNil(tool.annotations)
        XCTAssertTrue(tool.annotations?.openWorldHint ?? false)
    }

    /// AC1 [P0]: defineTool annotations parameter defaults to nil (backward compatibility).
    func testDefineTool_AnnotationsDefaultsToNil() {
        // Given: a tool defined without annotations (backward compat)
        struct Input: Codable { let x: Int }

        // When: defining without annotations parameter
        let tool = defineTool(
            name: "no_annotations",
            description: "No annotations",
            inputSchema: ["type": "object"]
        ) { (input: Input, context: ToolContext) async throws -> String in
            return "\(input.x)"
        }

        // Then: annotations is nil (backward compatible)
        XCTAssertNil(tool.annotations,
                      "Tool defined without annotations should have nil annotations")
    }

    // MARK: - AC1: toApiTool() includes annotations

    /// AC1 [P0]: toApiTool() includes annotations dict when tool has annotations.
    func testToApiTool_IncludesAnnotations_WhenPresent() {
        // Given: a tool with annotations
        struct Input: Codable { let path: String }
        let annotations = ToolAnnotations(
            readOnlyHint: true,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: false
        )
        let tool = defineTool(
            name: "annotated_read",
            description: "Annotated read",
            inputSchema: ["type": "object"],
            isReadOnly: true,
            annotations: annotations
        ) { (input: Input, context: ToolContext) async throws -> String in
            return "content"
        }

        // When: converting to API format
        let apiTool = toApiTool(tool)

        // Then: "annotations" key is present with correct values
        let annotationsDict = apiTool["annotations"] as? [String: Any]
        XCTAssertNotNil(annotationsDict,
                         "toApiTool should include 'annotations' key when tool has annotations")
        XCTAssertEqual(annotationsDict?["readOnlyHint"] as? Bool, true)
        XCTAssertEqual(annotationsDict?["destructiveHint"] as? Bool, false)
        XCTAssertEqual(annotationsDict?["idempotentHint"] as? Bool, true)
        XCTAssertEqual(annotationsDict?["openWorldHint"] as? Bool, false)
    }

    /// AC1 [P0]: toApiTool() does NOT include annotations key when tool has nil annotations.
    func testToApiTool_ExcludesAnnotations_WhenNil() {
        // Given: a tool without annotations
        let tool = defineTool(
            name: "no_annotations",
            description: "No annotations",
            inputSchema: ["type": "object"]
        ) { (context: ToolContext) async throws -> String in "ok" }

        // When: converting to API format
        let apiTool = toApiTool(tool)

        // Then: "annotations" key is NOT present
        XCTAssertNil(apiTool["annotations"],
                      "toApiTool should NOT include 'annotations' key when annotations is nil")
    }

    /// AC1 [P1]: toApiTool() still has 3 base keys when annotations is nil.
    func testToApiTool_StillHasThreeBaseKeys_WhenAnnotationsNil() {
        // Given: a tool without annotations
        let tool = defineTool(
            name: "base_only",
            description: "Base keys only",
            inputSchema: ["type": "object"]
        ) { (context: ToolContext) async throws -> String in "ok" }

        // When: converting to API format
        let apiTool = toApiTool(tool)

        // Then: exactly 3 keys (name, description, input_schema)
        XCTAssertEqual(apiTool.count, 3,
                        "toApiTool without annotations should have exactly 3 keys")
    }

    /// AC1 [P1]: toApiTool() has 4 keys when annotations is present.
    func testToApiTool_HasFourKeys_WhenAnnotationsPresent() {
        // Given: a tool with annotations
        let annotations = ToolAnnotations(readOnlyHint: true)
        let tool = defineTool(
            name: "four_keys",
            description: "Four keys",
            inputSchema: ["type": "object"],
            annotations: annotations
        ) { (context: ToolContext) async throws -> String in "ok" }

        // When: converting to API format
        let apiTool = toApiTool(tool)

        // Then: 4 keys (name, description, input_schema, annotations)
        XCTAssertEqual(apiTool.count, 4,
                        "toApiTool with annotations should have exactly 4 keys")
    }
}

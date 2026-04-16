import XCTest
@testable import OpenAgentSDK

// MARK: - Tool System Enhancement Integration ATDD Tests (Story 17-3)

/// ATDD RED PHASE: Integration tests for Story 17-3 -- Tool System Enhancement.
/// Tests the cross-cutting concerns: defineTool with annotations, toApiTool with
/// annotations, ToolResult typed content through the tool execution pipeline.
/// TDD Phase: RED (feature not implemented yet)
final class ToolSystemEnhancementATDDTests: XCTestCase {

    // MARK: - Helpers

    /// Standard ToolContext for testing.
    private func makeContext(toolUseId: String = "enhancement-test-tu") -> ToolContext {
        ToolContext(cwd: "/tmp", toolUseId: toolUseId)
    }

    // MARK: - AC1+AC4: defineTool with annotations flows through toApiTool

    /// AC1+AC4 [P0]: Tool defined with annotations appears correctly in toApiTools output.
    func testAnnotatedTool_FlowsThroughToApiTools() {
        // Given: multiple tools, some with annotations
        struct Input: Codable { let x: Int }

        let annotatedTool = defineTool(
            name: "safe_query",
            description: "A safe query tool",
            inputSchema: ["type": "object"],
            isReadOnly: true,
            annotations: ToolAnnotations(readOnlyHint: true, destructiveHint: false)
        ) { (input: Input, context: ToolContext) async throws -> String in
            return "\(input.x)"
        }

        let unannotatedTool = defineTool(
            name: "plain_tool",
            description: "A plain tool",
            inputSchema: ["type": "object"]
        ) { (input: Input, context: ToolContext) async throws -> String in
            return "plain"
        }

        // When: converting both to API format
        let apiTools = toApiTools([annotatedTool, unannotatedTool])

        // Then: first tool has annotations, second does not
        XCTAssertEqual(apiTools.count, 2)

        let firstAnnotations = apiTools[0]["annotations"] as? [String: Any]
        XCTAssertNotNil(firstAnnotations,
                         "Annotated tool should have 'annotations' in API output")
        XCTAssertEqual(firstAnnotations?["readOnlyHint"] as? Bool, true)

        let secondAnnotations = apiTools[1]["annotations"] as? [String: Any]
        XCTAssertNil(secondAnnotations,
                      "Unannotated tool should NOT have 'annotations' in API output")
    }

    /// AC1 [P1]: Built-in tools have appropriate annotations (most nil, Bash has destructiveHint).
    func testBuiltInTools_HaveDefaultNilAnnotations() {
        // Given: all core tools
        let tools = getAllBaseTools(tier: .core)

        // Then: most have nil annotations, except Bash which declares destructiveHint=true
        for tool in tools {
            if tool.name == "Bash" {
                // Bash is explicitly annotated as destructive
                XCTAssertNotNil(tool.annotations,
                                "Bash should have annotations (destructive)")
                XCTAssertEqual(tool.annotations?.destructiveHint, true,
                                "Bash should have destructiveHint=true")
            } else {
                XCTAssertNil(tool.annotations,
                              "Built-in tool '\(tool.name)' should have nil annotations by default")
            }
        }
    }

    /// AC1 [P1]: Built-in specialist tools have nil annotations by default.
    func testSpecialistTools_HaveDefaultNilAnnotations() {
        // Given: all specialist tools
        let tools = getAllBaseTools(tier: .specialist)

        // Then: none have annotations
        for tool in tools {
            XCTAssertNil(tool.annotations,
                          "Specialist tool '\(tool.name)' should have nil annotations by default")
        }
    }

    // MARK: - AC2: Typed content through tool execution pipeline

    /// AC2 [P0]: Tool returning ToolExecuteResult with typedContent produces correct ToolResult.
    func testToolExecution_PreservesTypedContent() async {
        // Given: a tool that returns typed content
        struct Input: Codable { let query: String }

        let tool = defineTool(
            name: "search_with_image",
            description: "Search returning text and image",
            inputSchema: ["type": "object"]
        ) { (input: Input, context: ToolContext) async throws -> ToolExecuteResult in
            return ToolExecuteResult(
                typedContent: [
                    .text("Found results for: \(input.query)"),
                    .image(data: Data([0x89, 0x50]), mimeType: "image/png")
                ],
                isError: false
            )
        }

        // When: executing the tool
        let result = await tool.call(input: ["query": "test"], context: makeContext())

        // Then: ToolResult has typedContent preserved
        XCTAssertFalse(result.isError)
        XCTAssertNotNil(result.typedContent,
                         "ToolResult should have typedContent from ToolExecuteResult")
        XCTAssertEqual(result.typedContent?.count, 2)

        // And: content derives from typedContent
        XCTAssertEqual(result.content, "Found results for: test",
                        "ToolResult.content should derive from .text items in typedContent")
    }

    /// AC2 [P0]: Tool returning plain String still works (backward compat).
    func testToolExecution_PlainString_StillWorks() async {
        // Given: a tool returning plain String (pre-17-3 style)
        struct Input: Codable { let name: String }

        let tool = defineTool(
            name: "greet",
            description: "Greet someone",
            inputSchema: ["type": "object"]
        ) { (input: Input, context: ToolContext) async throws -> String in
            return "Hello, \(input.name)!"
        }

        // When: executing the tool
        let result = await tool.call(input: ["name": "World"], context: makeContext())

        // Then: content is the plain string
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content, "Hello, World!")
        XCTAssertNil(result.typedContent,
                      "Plain string tool should have nil typedContent")
    }

    /// AC2 [P1]: Raw dictionary tool with typed content.
    func testRawDictionaryTool_WithTypedContent() async {
        // Given: a raw dictionary tool returning typed content
        let tool = defineTool(
            name: "raw_typed",
            description: "Raw tool with typed output",
            inputSchema: ["type": "object"]
        ) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
            return ToolExecuteResult(
                typedContent: [.text("raw result")],
                isError: false
            )
        }

        // When: executing
        let result = await tool.call(input: [:], context: makeContext())

        // Then: typedContent is preserved through pipeline
        XCTAssertFalse(result.isError)
        XCTAssertNotNil(result.typedContent)
        XCTAssertEqual(result.content, "raw result")
    }

    // MARK: - AC1: Annotations consistency with isReadOnly

    /// AC1 [P1]: When annotations.readOnlyHint is set, it should be consistent with isReadOnly.
    func testAnnotations_ReadOnlyHint_ConsistentWithIsReadOnly() {
        // Given: a tool with isReadOnly=true and readOnlyHint=true
        struct Input: Codable { let x: Int }
        let consistentTool = defineTool(
            name: "consistent",
            description: "Consistent tool",
            inputSchema: ["type": "object"],
            isReadOnly: true,
            annotations: ToolAnnotations(readOnlyHint: true)
        ) { (input: Input, context: ToolContext) async throws -> String in "ok" }

        // Then: both agree
        XCTAssertTrue(consistentTool.isReadOnly)
        XCTAssertTrue(consistentTool.annotations?.readOnlyHint ?? false)
    }

    // MARK: - AC1+AC4: assembleToolPool with annotated tools

    /// AC1 [P1]: assembleToolPool works with tools that have annotations.
    func testAssembleToolPool_WithAnnotatedTools() {
        // Given: base tools and a custom annotated tool
        let baseTools = getAllBaseTools(tier: .core)
        let customAnnotated = defineTool(
            name: "custom_annotated",
            description: "Custom tool with annotations",
            inputSchema: ["type": "object"],
            isReadOnly: true,
            annotations: ToolAnnotations(readOnlyHint: true, idempotentHint: true)
        ) { (context: ToolContext) async throws -> String in "custom" }

        // When: assembling tool pool
        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: [customAnnotated],
            mcpTools: nil,
            allowed: nil,
            disallowed: nil
        )

        // Then: custom tool with annotations is in pool
        let custom = pool.first { $0.name == "custom_annotated" }
        XCTAssertNotNil(custom)
        XCTAssertNotNil(custom?.annotations)
        XCTAssertTrue(custom?.annotations?.idempotentHint ?? false)
    }

    /// AC1 [P1]: Custom annotated tool overrides base tool (dedup works with annotations).
    func testAssembleToolPool_AnnotatedOverride_BaseTool() {
        // Given: base tools and custom annotated override
        let baseTools = getAllBaseTools(tier: .core)
        let customRead = defineTool(
            name: "Read",
            description: "Custom annotated read",
            inputSchema: ["type": "object"],
            isReadOnly: true,
            annotations: ToolAnnotations(readOnlyHint: true, idempotentHint: true)
        ) { (context: ToolContext) async throws -> String in "custom" }

        // When: assembling
        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: [customRead],
            mcpTools: nil,
            allowed: nil,
            disallowed: nil
        )

        // Then: custom Read overrides base Read with annotations
        let readTool = pool.first { $0.name == "Read" }
        XCTAssertNotNil(readTool)
        XCTAssertEqual(readTool?.description, "Custom annotated read")
        XCTAssertNotNil(readTool?.annotations)
    }

    // MARK: - AC1+AC2+AC3: Full integration (all features together)

    /// Integration [P1]: defineTool with annotations + ToolContent result works end-to-end.
    func testFullIntegration_AnnotatedToolWithTypedContent() async {
        // Given: a tool with annotations that returns typed content
        struct Input: Codable { let url: String }

        let tool = defineTool(
            name: "fetch_resource",
            description: "Fetch a web resource",
            inputSchema: ["type": "object"],
            isReadOnly: true,
            annotations: ToolAnnotations(
                readOnlyHint: true,
                destructiveHint: false,
                idempotentHint: true,
                openWorldHint: true
            )
        ) { (input: Input, context: ToolContext) async throws -> ToolExecuteResult in
            return ToolExecuteResult(
                typedContent: [
                    .text("Fetched from: \(input.url)"),
                    .resource(uri: input.url, name: "resource.html")
                ],
                isError: false
            )
        }

        // When: executing and converting to API format
        let result = await tool.call(
            input: ["url": "https://example.com"],
            context: makeContext(toolUseId: "tu_integration")
        )
        let apiTool = toApiTool(tool)

        // Then: execution result has typed content
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.toolUseId, "tu_integration")
        XCTAssertNotNil(result.typedContent)
        XCTAssertEqual(result.typedContent?.count, 2)
        XCTAssertEqual(result.content, "Fetched from: https://example.com")

        // And: API format has annotations
        let annotations = apiTool["annotations"] as? [String: Any]
        XCTAssertNotNil(annotations)
        let readOnly = annotations?["readOnlyHint"] as? Bool
        let openWorld = annotations?["openWorldHint"] as? Bool
        XCTAssertEqual(readOnly, true)
        XCTAssertEqual(openWorld, true)
    }
}

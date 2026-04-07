import XCTest
@testable import OpenAgentSDK

// MARK: - toApiTool Tests

/// ATDD RED PHASE: Tests for Story 3.1 -- Tool Protocol & Registry.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `ToolRegistry.swift` is created in `Sources/OpenAgentSDK/Tools/`
///   - `toApiTool(_:)` converts a `ToolProtocol` to `{ name, description, input_schema }`
///   - `toApiTools(_:)` converts an array of `ToolProtocol` to API format
///   - `ToolTier` enum is defined with `core`, `advanced`, `specialist` cases
///   - `getAllBaseTools(tier:)` is implemented
///   - `filterTools(tools:allowed:disallowed:)` is implemented
///   - `assembleToolPool(baseTools:customTools:mcpTools:allowed:disallowed:)` is implemented
/// TDD Phase: RED (feature not implemented yet)
final class ToolRegistryTests: XCTestCase {

    // MARK: - Helper: Create a mock tool for testing

    /// Creates a simple mock tool conforming to ToolProtocol for testing.
    private func makeMockTool(
        name: String = "test_tool",
        description: String = "A test tool",
        inputSchema: ToolInputSchema = ["type": "object", "properties": [:]],
        isReadOnly: Bool = false
    ) -> ToolProtocol {
        MockTool(
            name: name,
            description: description,
            inputSchema: inputSchema,
            isReadOnly: isReadOnly
        )
    }

    // MARK: - AC5: toApiTool format conversion

    /// AC5 [P0]: toApiTool() should produce the correct Anthropic API format
    /// with name, description, and input_schema keys.
    func testToApiTool_ProducesCorrectFormat() {
        // Given: a tool with known properties
        let schema: ToolInputSchema = [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "File path"]
            ],
            "required": ["path"]
        ]
        let tool = makeMockTool(
            name: "read_file",
            description: "Read a file from disk",
            inputSchema: schema
        )

        // When: converting to API format
        let apiTool = toApiTool(tool)

        // Then: the output dictionary has the required keys
        XCTAssertEqual(apiTool["name"] as? String, "read_file",
                       "toApiTool should preserve tool name")
        XCTAssertEqual(apiTool["description"] as? String, "Read a file from disk",
                       "toApiTool should preserve tool description")

        // Then: input_schema key exists and matches the original schema
        let inputSchemaDict = apiTool["input_schema"] as? [String: Any]
        XCTAssertNotNil(inputSchemaDict,
                        "toApiTool output must contain 'input_schema' key")
        XCTAssertEqual(inputSchemaDict?["type"] as? String, "object",
                       "input_schema should preserve 'type' field")
    }

    /// AC5 [P0]: toApiTool() should produce exactly 3 keys: name, description, input_schema.
    func testToApiTool_HasExactlyThreeKeys() {
        // Given: a valid tool
        let tool = makeMockTool(name: "bash", description: "Run a bash command")

        // When: converting to API format
        let apiTool = toApiTool(tool)

        // Then: the dictionary contains exactly 3 keys
        XCTAssertEqual(apiTool.count, 3,
                       "toApiTool should produce exactly 3 keys: name, description, input_schema")
        XCTAssertTrue(apiTool.keys.contains("name"),
                      "toApiTool output must contain 'name' key")
        XCTAssertTrue(apiTool.keys.contains("description"),
                      "toApiTool output must contain 'description' key")
        XCTAssertTrue(apiTool.keys.contains("input_schema"),
                      "toApiTool output must contain 'input_schema' key")
    }

    // MARK: - AC5: toApiTools (batch conversion)

    /// AC5 [P0]: toApiTools() should convert an array of tools.
    func testToApiTools_ConvertsArrayOfTools() {
        // Given: multiple tools
        let tools = [
            makeMockTool(name: "tool_a", description: "Tool A"),
            makeMockTool(name: "tool_b", description: "Tool B"),
            makeMockTool(name: "tool_c", description: "Tool C")
        ]

        // When: converting to API format
        let apiTools = toApiTools(tools)

        // Then: produces an array with matching count and names
        XCTAssertEqual(apiTools.count, 3, "toApiTools should convert all tools")
        let names = apiTools.compactMap { $0["name"] as? String }
        XCTAssertEqual(names, ["tool_a", "tool_b", "tool_c"],
                       "toApiTools should preserve tool order and names")
    }

    /// AC5 [P0]: toApiTools() with empty array should return empty array.
    func testToApiTools_EmptyInput_ReturnsEmptyArray() {
        // Given: no tools
        let tools: [ToolProtocol] = []

        // When: converting to API format
        let apiTools = toApiTools(tools)

        // Then: returns empty array
        XCTAssertTrue(apiTools.isEmpty,
                       "toApiTools with empty input should return empty array")
    }

    // MARK: - AC1: ToolTier enum

    /// AC1 [P0]: ToolTier enum should have core, advanced, specialist cases.
    func testToolTier_HasExpectedCases() {
        // Given: ToolTier enum
        // When: enumerating all cases
        let allCases = ToolTier.allCases

        // Then: it has exactly the expected cases
        XCTAssertEqual(allCases.count, 3,
                       "ToolTier should have exactly 3 cases")
        XCTAssertTrue(allCases.contains(.core),
                      "ToolTier should have a 'core' case")
        XCTAssertTrue(allCases.contains(.advanced),
                      "ToolTier should have an 'advanced' case")
        XCTAssertTrue(allCases.contains(.specialist),
                      "ToolTier should have a 'specialist' case")
    }

    /// AC1 [P0]: ToolTier rawValue should match string names.
    func testToolTier_RawValues() {
        // Given: ToolTier enum with raw values
        // Then: raw values match expected strings
        XCTAssertEqual(ToolTier.core.rawValue, "core")
        XCTAssertEqual(ToolTier.advanced.rawValue, "advanced")
        XCTAssertEqual(ToolTier.specialist.rawValue, "specialist")
    }

    // MARK: - AC2: getAllBaseTools

    /// AC2 [P0]: getAllBaseTools(tier: .core) should return an empty array in this story
    /// (core tools are implemented in stories 3.4-3.7).
    func testGetAllBaseTools_Core_ReturnsFileTools() {
        // Given: file tools implemented in Story 3.4
        // When: requesting core tier tools
        let tools = getAllBaseTools(tier: .core)
        let names = Set(tools.map { $0.name })

        // Then: core tier includes Read, Write, Edit
        XCTAssertTrue(names.contains("Read"),
                       "Core tier should include Read tool")
        XCTAssertTrue(names.contains("Write"),
                       "Core tier should include Write tool")
        XCTAssertTrue(names.contains("Edit"),
                       "Core tier should include Edit tool")
    }

    /// AC2 [P0]: getAllBaseTools for advanced/specialist tiers should return empty arrays.
    func testGetAllBaseTools_AdvancedAndSpecialist_ReturnEmpty() {
        // Given: no tools implemented yet
        // When: requesting other tiers
        let advancedTools = getAllBaseTools(tier: .advanced)
        let specialistTools = getAllBaseTools(tier: .specialist)

        // Then: advanced returns empty, specialist has registered tools
        XCTAssertTrue(advancedTools.isEmpty,
                       "getAllBaseTools(.advanced) should return empty array")
        XCTAssertTrue(!specialistTools.isEmpty,
                       "getAllBaseTools(.specialist) should contain registered tools")
    }

    // MARK: - AC3: filterTools

    /// AC3 [P0]: filterTools with allowed list should only include matching tools.
    func testFilterTools_AllowedList_FiltersCorrectly() {
        // Given: tools with different names
        let tools = [
            makeMockTool(name: "bash"),
            makeMockTool(name: "read"),
            makeMockTool(name: "write")
        ]

        // When: filtering to only allow "bash" and "read"
        let filtered = filterTools(tools: tools, allowed: ["bash", "read"], disallowed: nil)

        // Then: only bash and read remain
        XCTAssertEqual(filtered.count, 2)
        let names = filtered.map { $0.name }
        XCTAssertTrue(names.contains("bash"))
        XCTAssertTrue(names.contains("read"))
        XCTAssertFalse(names.contains("write"))
    }

    /// AC3 [P0]: filterTools with disallowed list should exclude matching tools.
    func testFilterTools_DisallowedList_ExcludesCorrectly() {
        // Given: tools with different names
        let tools = [
            makeMockTool(name: "bash"),
            makeMockTool(name: "read"),
            makeMockTool(name: "write")
        ]

        // When: disallowing "write"
        let filtered = filterTools(tools: tools, allowed: nil, disallowed: ["write"])

        // Then: bash and read remain, write is excluded
        XCTAssertEqual(filtered.count, 2)
        let names = filtered.map { $0.name }
        XCTAssertTrue(names.contains("bash"))
        XCTAssertTrue(names.contains("read"))
        XCTAssertFalse(names.contains("write"))
    }

    /// AC3 [P1]: filterTools with both allowed and disallowed applies both.
    /// Disallowed takes precedence (if a tool is in both lists, it is excluded).
    func testFilterTools_BothLists_AppliesBoth() {
        // Given: tools
        let tools = [
            makeMockTool(name: "bash"),
            makeMockTool(name: "read"),
            makeMockTool(name: "write"),
            makeMockTool(name: "glob")
        ]

        // When: allowing bash, read, write but disallowing write
        let filtered = filterTools(
            tools: tools,
            allowed: ["bash", "read", "write"],
            disallowed: ["write"]
        )

        // Then: only bash and read remain
        XCTAssertEqual(filtered.count, 2)
        let names = filtered.map { $0.name }
        XCTAssertTrue(names.contains("bash"))
        XCTAssertTrue(names.contains("read"))
        XCTAssertFalse(names.contains("write"))
        XCTAssertFalse(names.contains("glob"))
    }

    /// AC3 [P1]: filterTools with nil/empty lists returns all tools.
    func testFilterTools_NoLists_ReturnsAllTools() {
        // Given: 3 tools
        let tools = [
            makeMockTool(name: "bash"),
            makeMockTool(name: "read"),
            makeMockTool(name: "write")
        ]

        // When: no allow or disallow lists
        let filtered = filterTools(tools: tools, allowed: nil, disallowed: nil)

        // Then: all tools returned
        XCTAssertEqual(filtered.count, 3)
    }

    /// AC3 [P1]: filterTools with empty allowed list returns all tools.
    func testFilterTools_EmptyAllowedList_ReturnsAllTools() {
        // Given: 3 tools
        let tools = [
            makeMockTool(name: "bash"),
            makeMockTool(name: "read"),
            makeMockTool(name: "write")
        ]

        // When: empty allowed list
        let filtered = filterTools(tools: tools, allowed: [], disallowed: nil)

        // Then: all tools returned (empty list = no filter)
        XCTAssertEqual(filtered.count, 3,
                       "Empty allowed list should not filter (treated as nil)")
    }

    /// AC3 [P1]: filterTools with empty disallowed list returns all tools.
    func testFilterTools_EmptyDisallowedList_ReturnsAllTools() {
        // Given: 3 tools
        let tools = [
            makeMockTool(name: "bash"),
            makeMockTool(name: "read"),
            makeMockTool(name: "write")
        ]

        // When: empty disallowed list
        let filtered = filterTools(tools: tools, allowed: nil, disallowed: [])

        // Then: all tools returned
        XCTAssertEqual(filtered.count, 3,
                       "Empty disallowed list should not filter (treated as nil)")
    }

    // MARK: - AC4: assembleToolPool (deduplication)

    /// AC4 [P0]: assembleToolPool should deduplicate by name, with later tools overriding earlier.
    func testAssembleToolPool_DeduplicatesByName_LaterOverridesEarlier() {
        // Given: base tools with "bash" and "read", custom tools with "bash" (overridden)
        let baseTools = [
            makeMockTool(name: "bash", description: "Base bash"),
            makeMockTool(name: "read", description: "Base read")
        ]
        let customTools = [
            makeMockTool(name: "bash", description: "Custom bash"),
            makeMockTool(name: "grep", description: "Custom grep")
        ]

        // When: assembling the tool pool
        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: customTools,
            mcpTools: nil,
            allowed: nil,
            disallowed: nil
        )

        // Then: 3 unique tools, bash is the custom version
        XCTAssertEqual(pool.count, 3, "Should have 3 unique tools after dedup")
        let bashTool = pool.first { $0.name == "bash" }
        XCTAssertNotNil(bashTool)
        XCTAssertEqual(bashTool?.description, "Custom bash",
                       "Custom tool should override base tool with same name")
        let names = Set(pool.map { $0.name })
        XCTAssertEqual(names, ["bash", "read", "grep"])
    }

    /// AC4 [P0]: assembleToolPool should include MCP tools and deduplicate with them.
    func testAssembleToolPool_IncludesMcpTools() {
        // Given: base and MCP tools
        let baseTools = [
            makeMockTool(name: "bash", description: "Base bash"),
            makeMockTool(name: "read", description: "Base read")
        ]
        let mcpTools = [
            makeMockTool(name: "mcp_search", description: "MCP search"),
            makeMockTool(name: "bash", description: "MCP bash")
        ]

        // When: assembling the tool pool
        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: nil,
            mcpTools: mcpTools,
            allowed: nil,
            disallowed: nil
        )

        // Then: MCP tools included, MCP bash overrides base bash
        XCTAssertEqual(pool.count, 3)
        let bashTool = pool.first { $0.name == "bash" }
        XCTAssertEqual(bashTool?.description, "MCP bash",
                       "MCP tool should override base tool")
    }

    /// AC4 [P1]: assembleToolPool with nil custom/MCP tools works correctly.
    func testAssembleToolPool_NoCustomOrMcpTools() {
        // Given: only base tools
        let baseTools = [
            makeMockTool(name: "bash"),
            makeMockTool(name: "read")
        ]

        // When: assembling with no custom or MCP tools
        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: nil,
            mcpTools: nil,
            allowed: nil,
            disallowed: nil
        )

        // Then: all base tools present
        XCTAssertEqual(pool.count, 2)
    }

    /// AC4 [P1]: assembleToolPool applies allowed/disallowed filters after dedup.
    func testAssembleToolPool_AppliesFiltersAfterDedup() {
        // Given: base and custom tools with dedup
        let baseTools = [
            makeMockTool(name: "bash"),
            makeMockTool(name: "read"),
            makeMockTool(name: "write")
        ]
        let customTools = [
            makeMockTool(name: "grep")
        ]

        // When: assembling with filter allowing only bash and grep
        let pool = assembleToolPool(
            baseTools: baseTools,
            customTools: customTools,
            mcpTools: nil,
            allowed: ["bash", "grep"],
            disallowed: nil
        )

        // Then: only allowed tools after dedup
        XCTAssertEqual(pool.count, 2)
        let names = Set(pool.map { $0.name })
        XCTAssertEqual(names, ["bash", "grep"])
    }
}

// MARK: - Mock Tool Implementation (for testing)

/// A simple mock tool for testing purposes.
/// Conforms to ToolProtocol and Sendable.
private struct MockTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema
    let isReadOnly: Bool

    func call(input: Any, context: ToolContext) async -> ToolResult {
        ToolResult(toolUseId: "mock", content: "mock result", isError: false)
    }
}

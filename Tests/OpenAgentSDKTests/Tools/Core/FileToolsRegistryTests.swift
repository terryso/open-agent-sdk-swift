import XCTest
@testable import OpenAgentSDK

// MARK: - Core File Tools Registry Integration Tests (Story 3.4)

/// ATDD RED PHASE: Tests for Story 3.4, 3.5, 3.6 & 3.7 — ToolRegistry core tier integration.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `getAllBaseTools(tier: .core)` returns Read, Write, Edit, Glob, Grep, Bash, AskUser, ToolSearch tools
///   - Each tool has correct name, schema, and isReadOnly properties
/// TDD Phase: RED (feature not implemented yet)
final class FileToolsRegistryTests: XCTestCase {

    // MARK: - AC8: getAllBaseTools(.core) includes file tools

    /// AC8 [P0]: getAllBaseTools(.core) returns Read, Write, and Edit tools.
    func testGetAllBaseTools_coreTier_includesFileTools() {
        // When: requesting core tier tools
        let tools = getAllBaseTools(tier: .core)

        // Then: Read, Write, Edit are all present
        let names = Set(tools.map { $0.name })
        XCTAssertTrue(names.contains("Read"),
                      "Core tier should include Read tool, got: \(names)")
        XCTAssertTrue(names.contains("Write"),
                      "Core tier should include Write tool, got: \(names)")
        XCTAssertTrue(names.contains("Edit"),
                      "Core tier should include Edit tool, got: \(names)")
    }

    /// AC8 [P0]: Each core file tool has a valid inputSchema with properties and required fields.
    func testGetAllBaseTools_coreTier_toolsHaveCorrectSchema() {
        // Given: core tier tools
        let tools = getAllBaseTools(tier: .core)
        let toolMap = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })

        // Then: Read tool schema
        let readTool = toolMap["Read"]
        XCTAssertNotNil(readTool, "Read tool should be present in core tier")
        if let readSchema = readTool?.inputSchema as? [String: Any] {
            let readProps = readSchema["properties"] as? [String: Any]
            XCTAssertNotNil(readProps,
                            "Read tool schema should have 'properties'")
            XCTAssertTrue(readProps!.keys.contains("file_path"),
                          "Read tool should have 'file_path' property")
        }

        // Then: Write tool schema
        let writeTool = toolMap["Write"]
        XCTAssertNotNil(writeTool, "Write tool should be present in core tier")
        if let writeSchema = writeTool?.inputSchema as? [String: Any] {
            let writeProps = writeSchema["properties"] as? [String: Any]
            XCTAssertNotNil(writeProps,
                            "Write tool schema should have 'properties'")
            XCTAssertTrue(writeProps!.keys.contains("file_path"),
                          "Write tool should have 'file_path' property")
            XCTAssertTrue(writeProps!.keys.contains("content"),
                          "Write tool should have 'content' property")
        }

        // Then: Edit tool schema
        let editTool = toolMap["Edit"]
        XCTAssertNotNil(editTool, "Edit tool should be present in core tier")
        if let editSchema = editTool?.inputSchema as? [String: Any] {
            let editProps = editSchema["properties"] as? [String: Any]
            XCTAssertNotNil(editProps,
                            "Edit tool schema should have 'properties'")
            XCTAssertTrue(editProps!.keys.contains("file_path"),
                          "Edit tool should have 'file_path' property")
            XCTAssertTrue(editProps!.keys.contains("old_string"),
                          "Edit tool should have 'old_string' property")
            XCTAssertTrue(editProps!.keys.contains("new_string"),
                          "Edit tool should have 'new_string' property")
        }
    }

    /// AC8 [P0]: Read tool is read-only; Write and Edit are not.
    func testGetAllBaseTools_coreTier_readOnlyProperty() {
        // Given: core tier tools
        let tools = getAllBaseTools(tier: .core)
        let toolMap = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })

        // Then: Read is read-only
        let readTool = toolMap["Read"]
        XCTAssertNotNil(readTool)
        XCTAssertTrue(readTool!.isReadOnly,
                      "Read tool should be marked isReadOnly=true")

        // Then: Write is NOT read-only
        let writeTool = toolMap["Write"]
        XCTAssertNotNil(writeTool)
        XCTAssertFalse(writeTool!.isReadOnly,
                       "Write tool should NOT be marked isReadOnly")

        // Then: Edit is NOT read-only
        let editTool = toolMap["Edit"]
        XCTAssertNotNil(editTool)
        XCTAssertFalse(editTool!.isReadOnly,
                       "Edit tool should NOT be marked isReadOnly")
    }

    /// AC8 [P1]: getAllBaseTools(.advanced) and .specialist still return empty arrays.
    func testGetAllBaseTools_nonCoreTiers_stillReturnEmpty() {
        // When: requesting non-core tiers
        let advancedTools = getAllBaseTools(tier: .advanced)
        let specialistTools = getAllBaseTools(tier: .specialist)

        // Then: advanced is still empty, specialist has registered tools
        XCTAssertTrue(advancedTools.isEmpty,
                      "Advanced tier should still be empty")
        XCTAssertTrue(!specialistTools.isEmpty,
                      "Specialist tier should contain registered tools")
    }

    /// AC8 [P1]: Core tools can be converted to API format without errors.
    func testGetAllBaseTools_coreTier_toApiToolsFormat() {
        // Given: core tier tools
        let tools = getAllBaseTools(tier: .core)

        // When: converting to API format
        let apiTools = toApiTools(tools)

        // Then: each has name, description, input_schema
        XCTAssertEqual(apiTools.count, tools.count,
                       "API tools count should match source tools count")
        for apiTool in apiTools {
            XCTAssertTrue(apiTool["name"] is String,
                          "API tool should have string 'name'")
            XCTAssertTrue(apiTool["description"] is String,
                          "API tool should have string 'description'")
            XCTAssertNotNil(apiTool["input_schema"],
                            "API tool should have 'input_schema'")
        }
    }

    // MARK: - AC7: Glob/Grep registered in core tier (Story 3.5)

    /// AC7 [P0]: getAllBaseTools(.core) includes Glob and Grep tools.
    func testGetAllBaseTools_coreTier_includesGlobAndGrep() {
        // When: requesting core tier tools
        let tools = getAllBaseTools(tier: .core)

        // Then: Glob and Grep are present alongside Read, Write, Edit
        let names = Set(tools.map { $0.name })
        XCTAssertTrue(names.contains("Glob"),
                      "Core tier should include Glob tool, got: \(names)")
        XCTAssertTrue(names.contains("Grep"),
                      "Core tier should include Grep tool, got: \(names)")
        // Also verify pre-existing tools still present
        XCTAssertTrue(names.contains("Read"),
                      "Core tier should still include Read tool")
        XCTAssertTrue(names.contains("Write"),
                      "Core tier should still include Write tool")
        XCTAssertTrue(names.contains("Edit"),
                      "Core tier should still include Edit tool")
    }

    /// AC7 [P0]: Glob and Grep are both marked as isReadOnly=true.
    func testGetAllBaseTools_coreTier_globGrepAreReadOnly() {
        // Given: core tier tools
        let tools = getAllBaseTools(tier: .core)
        let toolMap = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })

        // Then: Glob is read-only
        let globTool = toolMap["Glob"]
        XCTAssertNotNil(globTool, "Glob tool should be present in core tier")
        XCTAssertTrue(globTool!.isReadOnly,
                      "Glob tool should be marked isReadOnly=true")

        // Then: Grep is read-only
        let grepTool = toolMap["Grep"]
        XCTAssertNotNil(grepTool, "Grep tool should be present in core tier")
        XCTAssertTrue(grepTool!.isReadOnly,
                      "Grep tool should be marked isReadOnly=true")
    }

    /// Core tier returns all 10 tools (Read, Write, Edit, Glob, Grep, Bash, AskUser, ToolSearch, WebFetch, WebSearch).
    func testGetAllBaseTools_coreTier_returnsTenTools() {
        // When: requesting core tier tools
        let tools = getAllBaseTools(tier: .core)

        // Then: exactly 10 tools
        XCTAssertEqual(tools.count, 10,
                       "Core tier should return exactly 10 tools, got \(tools.count): \(tools.map { $0.name })")
    }

    // MARK: - AC9: Bash, AskUser, ToolSearch registered in core tier (Story 3.6)

    /// AC9 [P0]: getAllBaseTools(.core) includes Bash, AskUser, and ToolSearch tools.
    func testGetAllBaseTools_coreTier_includesBashAskUserToolSearch() {
        // When: requesting core tier tools
        let tools = getAllBaseTools(tier: .core)

        // Then: Bash, AskUser, and ToolSearch are present alongside existing tools
        let names = Set(tools.map { $0.name })
        XCTAssertTrue(names.contains("Bash"),
                      "Core tier should include Bash tool, got: \(names)")
        XCTAssertTrue(names.contains("AskUser"),
                      "Core tier should include AskUser tool, got: \(names)")
        XCTAssertTrue(names.contains("ToolSearch"),
                      "Core tier should include ToolSearch tool, got: \(names)")
        // Also verify pre-existing tools still present
        XCTAssertTrue(names.contains("Read"),
                      "Core tier should still include Read tool")
        XCTAssertTrue(names.contains("Write"),
                      "Core tier should still include Write tool")
        XCTAssertTrue(names.contains("Edit"),
                      "Core tier should still include Edit tool")
        XCTAssertTrue(names.contains("Glob"),
                      "Core tier should still include Glob tool")
        XCTAssertTrue(names.contains("Grep"),
                      "Core tier should still include Grep tool")
    }

    /// AC9 [P0]: Bash is NOT read-only (it is a mutation tool).
    func testGetAllBaseTools_coreTier_bashIsNotReadOnly() {
        // Given: core tier tools
        let tools = getAllBaseTools(tier: .core)
        let toolMap = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })

        // Then: Bash is NOT read-only
        let bashTool = toolMap["Bash"]
        XCTAssertNotNil(bashTool, "Bash tool should be present in core tier")
        XCTAssertFalse(bashTool!.isReadOnly,
                       "Bash tool should NOT be marked isReadOnly (it is a mutation tool)")
    }

    /// AC9 [P0]: AskUser and ToolSearch are both marked as isReadOnly=true.
    func testGetAllBaseTools_coreTier_askUserToolSearchAreReadOnly() {
        // Given: core tier tools
        let tools = getAllBaseTools(tier: .core)
        let toolMap = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })

        // Then: AskUser is read-only
        let askUserTool = toolMap["AskUser"]
        XCTAssertNotNil(askUserTool, "AskUser tool should be present in core tier")
        XCTAssertTrue(askUserTool!.isReadOnly,
                      "AskUser tool should be marked isReadOnly=true")

        // Then: ToolSearch is read-only
        let toolSearchTool = toolMap["ToolSearch"]
        XCTAssertNotNil(toolSearchTool, "ToolSearch tool should be present in core tier")
        XCTAssertTrue(toolSearchTool!.isReadOnly,
                      "ToolSearch tool should be marked isReadOnly=true")
    }

    // MARK: - AC9: WebFetch, WebSearch registered in core tier (Story 3.7)

    /// AC9 [P0]: getAllBaseTools(.core) includes WebFetch and WebSearch tools.
    func testGetAllBaseTools_coreTier_includesWebFetchAndWebSearch() {
        // When: requesting core tier tools
        let tools = getAllBaseTools(tier: .core)

        // Then: WebFetch and WebSearch are present alongside all existing tools
        let names = Set(tools.map { $0.name })
        XCTAssertTrue(names.contains("WebFetch"),
                      "Core tier should include WebFetch tool, got: \(names)")
        XCTAssertTrue(names.contains("WebSearch"),
                      "Core tier should include WebSearch tool, got: \(names)")
        // Also verify all pre-existing tools still present
        XCTAssertTrue(names.contains("Read"),
                      "Core tier should still include Read tool")
        XCTAssertTrue(names.contains("Write"),
                      "Core tier should still include Write tool")
        XCTAssertTrue(names.contains("Edit"),
                      "Core tier should still include Edit tool")
        XCTAssertTrue(names.contains("Glob"),
                      "Core tier should still include Glob tool")
        XCTAssertTrue(names.contains("Grep"),
                      "Core tier should still include Grep tool")
        XCTAssertTrue(names.contains("Bash"),
                      "Core tier should still include Bash tool")
        XCTAssertTrue(names.contains("AskUser"),
                      "Core tier should still include AskUser tool")
        XCTAssertTrue(names.contains("ToolSearch"),
                      "Core tier should still include ToolSearch tool")
    }

    /// AC9 [P0]: WebFetch and WebSearch are both marked as isReadOnly=true.
    func testGetAllBaseTools_coreTier_webToolsAreReadOnly() {
        // Given: core tier tools
        let tools = getAllBaseTools(tier: .core)
        let toolMap = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })

        // Then: WebFetch is read-only
        let webFetchTool = toolMap["WebFetch"]
        XCTAssertNotNil(webFetchTool, "WebFetch tool should be present in core tier")
        XCTAssertTrue(webFetchTool!.isReadOnly,
                      "WebFetch tool should be marked isReadOnly=true")

        // Then: WebSearch is read-only
        let webSearchTool = toolMap["WebSearch"]
        XCTAssertNotNil(webSearchTool, "WebSearch tool should be present in core tier")
        XCTAssertTrue(webSearchTool!.isReadOnly,
                      "WebSearch tool should be marked isReadOnly=true")
    }

    /// AC9 [P0]: Core tier returns all 10 tools (Read, Write, Edit, Glob, Grep, Bash, AskUser, ToolSearch, WebFetch, WebSearch).
    func testGetAllBaseTools_coreTier_includesAllTenTools() {
        // When: requesting core tier tools
        let tools = getAllBaseTools(tier: .core)

        // Then: exactly 10 tools
        XCTAssertEqual(tools.count, 10,
                       "Core tier should return exactly 10 tools (Read, Write, Edit, Glob, Grep, Bash, AskUser, ToolSearch, WebFetch, WebSearch), got \(tools.count): \(tools.map { $0.name })")
    }
}

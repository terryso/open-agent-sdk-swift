import XCTest
@testable import OpenAgentSDK

// MARK: - ConfigToolTests

/// ATDD RED PHASE: Tests for Story 5.6 -- Config Tool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `createConfigTool()` factory function is implemented
///   - `configSchema` input schema is defined
///   - Tool call handler implements get/set/list operations
///   - JSON serialization helper is implemented
/// TDD Phase: RED (feature not implemented yet)
final class ConfigToolTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a basic ToolContext with just cwd (no stores needed for Config tool).
    private func makeContext() -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id"
        )
    }

    // MARK: - AC1: ConfigTool Registration

    /// AC1 [P0]: createConfigTool() returns a ToolProtocol with name "Config".
    func testCreateConfigTool_returnsToolProtocol() async throws {
        let tool = createConfigTool()

        XCTAssertEqual(tool.name, "Config")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC1 [P0]: Config tool description matches TS SDK description.
    func testCreateConfigTool_descriptionMatchesTSSdk() async throws {
        let tool = createConfigTool()

        let desc = tool.description.lowercased()
        XCTAssertTrue(
            desc.contains("config") && (desc.contains("get") || desc.contains("set") || desc.contains("configuration")),
            "Description should mention config and get/set/configuration"
        )
    }

    // MARK: - AC8: ConfigTool isReadOnly

    /// AC8 [P0]: Config tool isReadOnly returns false (set operation modifies config state).
    func testCreateConfigTool_isReadOnly_returnsFalse() async throws {
        let tool = createConfigTool()
        XCTAssertFalse(tool.isReadOnly, "Config tool should NOT be read-only (set modifies state)")
    }

    // MARK: - AC9: ConfigTool inputSchema Matches TS SDK

    /// AC9 [P0]: Config inputSchema has type "object".
    func testCreateConfigTool_inputSchema_hasCorrectType() async throws {
        let tool = createConfigTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")
    }

    /// AC9 [P0]: Config inputSchema has "action" in required array.
    func testCreateConfigTool_inputSchema_actionIsRequired() async throws {
        let tool = createConfigTool()
        let schema = tool.inputSchema

        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["action"])
    }

    /// AC9 [P0]: Config inputSchema action enum contains get, set, list.
    func testCreateConfigTool_inputSchema_actionEnum_hasGetSetList() async throws {
        let tool = createConfigTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let actionProp = properties?["action"] as? [String: Any]
        let enumValues = actionProp?["enum"] as? [String]

        XCTAssertNotNil(enumValues, "action should have enum values")
        let expectedEnums = ["get", "set", "list"]
        XCTAssertEqual(Set(enumValues!), Set(expectedEnums),
                       "action enum should contain get, set, list")
    }

    /// AC9 [P0]: Config inputSchema has key field (string, optional).
    func testCreateConfigTool_inputSchema_hasOptionalKey() async throws {
        let tool = createConfigTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let keyProp = properties?["key"] as? [String: Any]
        XCTAssertNotNil(keyProp, "key property should exist")
        XCTAssertEqual(keyProp?["type"] as? String, "string")

        let required = schema["required"] as? [String] ?? []
        XCTAssertFalse(required.contains("key"), "key should be optional")
    }

    /// AC9 [P0]: Config inputSchema has value field (optional, no type constraint -- any type).
    func testCreateConfigTool_inputSchema_hasOptionalValue() async throws {
        let tool = createConfigTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let valueProp = properties?["value"] as? [String: Any]
        XCTAssertNotNil(valueProp, "value property should exist")

        // value should NOT be in required
        let required = schema["required"] as? [String] ?? []
        XCTAssertFalse(required.contains("value"), "value should be optional")
    }

    // MARK: - AC3: Config get Missing Key Error

    /// AC3 [P0]: Config get with missing key returns is_error=true with "key required for get".
    func testConfigGet_missingKey_returnsError() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        let input: [String: Any] = [
            "action": "get"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError, "Missing key should return error")
        XCTAssertTrue(
            result.content.lowercased().contains("key"),
            "Error should mention key"
        )
    }

    // MARK: - AC2: Config get Operation

    /// AC2 [P0]: Config get with existing key returns the stored value.
    func testConfigGet_existingKey_returnsValue() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        // First set a value
        let setInput: [String: Any] = [
            "action": "set",
            "key": "testKey",
            "value": "hello"
        ]
        _ = await tool.call(input: setInput, context: context)

        // Then get it
        let getInput: [String: Any] = [
            "action": "get",
            "key": "testKey"
        ]
        let result = await tool.call(input: getInput, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("hello"), "Should return the stored value")
    }

    /// AC2 [P0]: Config get with non-existent key returns "not found" message.
    func testConfigGet_nonExistentKey_returnsNotFound() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        let input: [String: Any] = [
            "action": "get",
            "key": "nonExistentKey"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("not found") || result.content.contains("nonExistentKey"),
            "Should indicate key was not found"
        )
    }

    // MARK: - AC5: Config set Missing Key Error

    /// AC5 [P0]: Config set with missing key returns is_error=true with "key required for set".
    func testConfigSet_missingKey_returnsError() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        let input: [String: Any] = [
            "action": "set",
            "value": "something"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError, "Missing key should return error")
        XCTAssertTrue(
            result.content.lowercased().contains("key"),
            "Error should mention key"
        )
    }

    // MARK: - AC4: Config set Operation

    /// AC4 [P0]: Config set stores value and returns confirmation message.
    func testConfigSet_withKeyAndValue_returnsConfirmation() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        let input: [String: Any] = [
            "action": "set",
            "key": "mySetting",
            "value": "myValue"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("mySetting"),
            "Confirmation should contain the key name"
        )
    }

    /// AC4 [P0]: Config set with numeric value stores correctly.
    func testConfigSet_numericValue_storesCorrectly() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        // Set a numeric value
        let setInput: [String: Any] = [
            "action": "set",
            "key": "port",
            "value": 8080
        ]
        let setResult = await tool.call(input: setInput, context: context)
        XCTAssertFalse(setResult.isError)

        // Get it back
        let getInput: [String: Any] = [
            "action": "get",
            "key": "port"
        ]
        let result = await tool.call(input: getInput, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("8080"), "Should return the numeric value")
    }

    /// AC4 [P0]: Config set with boolean value stores correctly.
    func testConfigSet_booleanValue_storesCorrectly() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        let setInput: [String: Any] = [
            "action": "set",
            "key": "enabled",
            "value": true
        ]
        _ = await tool.call(input: setInput, context: context)

        let getInput: [String: Any] = [
            "action": "get",
            "key": "enabled"
        ]
        let result = await tool.call(input: getInput, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.lowercased().contains("true"),
            "Should return boolean value"
        )
    }

    /// AC4 [P1]: Config set overwrites existing value.
    func testConfigSet_overwritesExistingValue() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        // Set initial value
        let setInput1: [String: Any] = [
            "action": "set",
            "key": "overwriteKey",
            "value": "first"
        ]
        _ = await tool.call(input: setInput1, context: context)

        // Overwrite
        let setInput2: [String: Any] = [
            "action": "set",
            "key": "overwriteKey",
            "value": "second"
        ]
        _ = await tool.call(input: setInput2, context: context)

        // Get should return "second"
        let getInput: [String: Any] = [
            "action": "get",
            "key": "overwriteKey"
        ]
        let result = await tool.call(input: getInput, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("second"),
            "Should return the overwritten value"
        )
    }

    // MARK: - AC6: Config list Operation

    /// AC6 [P0]: Config list with no values returns "No config values set.".
    func testConfigList_empty_returnsNoValuesMessage() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        let input: [String: Any] = [
            "action": "list"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("No config values set"),
            "Empty list should return 'No config values set.'"
        )
    }

    /// AC6 [P0]: Config list with values returns all entries.
    func testConfigList_withValues_returnsAllEntries() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        // Set multiple values
        let set1: [String: Any] = ["action": "set", "key": "alpha", "value": "1"]
        let set2: [String: Any] = ["action": "set", "key": "beta", "value": "2"]
        _ = await tool.call(input: set1, context: context)
        _ = await tool.call(input: set2, context: context)

        // List all
        let input: [String: Any] = ["action": "list"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("alpha"), "List should contain 'alpha'")
        XCTAssertTrue(result.content.contains("beta"), "List should contain 'beta'")
    }

    /// AC6 [P0]: Config list format is key = JSON(value) per line.
    func testConfigList_format_perLine() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        let setInput: [String: Any] = ["action": "set", "key": "fmtTest", "value": "val"]
        _ = await tool.call(input: setInput, context: context)

        let input: [String: Any] = ["action": "list"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("="),
            "Each line should contain ' = ' between key and value"
        )
    }

    // MARK: - AC7: Config Unknown Action Error

    /// AC7 [P0]: Config unknown action returns is_error=true with "Unknown action: {action}".
    func testConfig_unknownAction_returnsError() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        let input: [String: Any] = [
            "action": "delete"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError, "Unknown action should return error")
        XCTAssertTrue(
            result.content.contains("Unknown action") || result.content.contains("delete"),
            "Error should mention the unknown action"
        )
    }

    // MARK: - AC15: Error Handling -- Never Throws

    /// AC15 [P0]: Config tool never throws -- always returns ToolResult even with malformed input.
    func testConfigTool_neverThrows_malformedInput() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        let badInputs: [[String: Any]] = [
            [:],                              // empty dict (missing action)
            ["unexpected": "field"],          // unexpected fields only
            ["action": 123],                  // wrong type for action
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    // MARK: - AC14: Module Boundary

    /// AC14 [P0]: Config tool does not require stores in context (no Actor store needed).
    func testConfigTool_doesNotRequireStoreInContext() async throws {
        let tool = createConfigTool()
        // Minimal context with only cwd and toolUseId -- no stores
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        // list operation should work without any store
        let input: [String: Any] = ["action": "list"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertFalse(result.content.isEmpty)
    }

    // MARK: - AC18: No Actor Store Needed

    /// AC18 [P0]: ConfigTool works with bare ToolContext (no dependency injection).
    func testConfigTool_noActorStoreNeeded() async throws {
        let tool = createConfigTool()
        let context = ToolContext(cwd: "/tmp", toolUseId: "bare-context")

        // set + get should work with no stores
        let setInput: [String: Any] = ["action": "set", "key": "bare", "value": "works"]
        let setResult = await tool.call(input: setInput, context: context)
        XCTAssertFalse(setResult.isError)

        let getInput: [String: Any] = ["action": "get", "key": "bare"]
        let result = await tool.call(input: getInput, context: context)
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("works"))
    }

    // MARK: - Integration: Full Config Lifecycle

    /// Integration [P1]: set -> get -> list -> set (overwrite) -> get -> list lifecycle.
    func testIntegration_fullConfigLifecycle() async throws {
        let tool = createConfigTool()
        let context = makeContext()

        // Step 1: List initially empty
        let initialList = await tool.call(input: ["action": "list"], context: context)
        XCTAssertFalse(initialList.isError)
        XCTAssertTrue(initialList.content.contains("No config values set"))

        // Step 2: Set a value
        let setResult = await tool.call(
            input: ["action": "set", "key": "theme", "value": "dark"],
            context: context
        )
        XCTAssertFalse(setResult.isError)

        // Step 3: Get it back
        let getResult = await tool.call(
            input: ["action": "get", "key": "theme"],
            context: context
        )
        XCTAssertFalse(getResult.isError)
        XCTAssertTrue(getResult.content.contains("dark"))

        // Step 4: List shows the entry
        let listResult = await tool.call(input: ["action": "list"], context: context)
        XCTAssertFalse(listResult.isError)
        XCTAssertTrue(listResult.content.contains("theme"))

        // Step 5: Overwrite
        _ = await tool.call(
            input: ["action": "set", "key": "theme", "value": "light"],
            context: context
        )

        // Step 6: Get updated value
        let updatedResult = await tool.call(
            input: ["action": "get", "key": "theme"],
            context: context
        )
        XCTAssertFalse(updatedResult.isError)
        XCTAssertTrue(updatedResult.content.contains("light"))
    }

    // MARK: - AC16: ToolRegistry Registration

    /// AC16 [P0]: getAllBaseTools(tier: .specialist) includes createConfigTool.
    func testToolRegistry_specialistTier_includesConfigTool() async throws {
        let tools = getAllBaseTools(tier: .specialist)
        let names = tools.map { $0.name }

        XCTAssertTrue(names.contains("Config"), "Specialist tier should include Config tool")
    }
}

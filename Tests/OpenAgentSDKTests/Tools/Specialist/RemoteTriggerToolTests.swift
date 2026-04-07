import XCTest
@testable import OpenAgentSDK

// MARK: - RemoteTriggerToolTests

/// ATDD RED PHASE: Tests for Story 5.6 -- RemoteTrigger Tool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `createRemoteTriggerTool()` factory function is implemented
///   - `RemoteTriggerInput` Codable struct is defined
///   - `remoteTriggerSchema` input schema is defined
///   - Tool call handler returns stub message for all actions
/// TDD Phase: RED (feature not implemented yet)
final class RemoteTriggerToolTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a basic ToolContext with just cwd (no stores needed for RemoteTrigger tool).
    private func makeContext() -> ToolContext {
        return ToolContext(
            cwd: "/tmp",
            toolUseId: "test-tool-use-id"
        )
    }

    // MARK: - AC10: RemoteTriggerTool Registration

    /// AC10 [P0]: createRemoteTriggerTool() returns a ToolProtocol with name "RemoteTrigger".
    func testCreateRemoteTriggerTool_returnsToolProtocol() async throws {
        let tool = createRemoteTriggerTool()

        XCTAssertEqual(tool.name, "RemoteTrigger")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC10 [P0]: RemoteTrigger tool description mentions remote triggers.
    func testCreateRemoteTriggerTool_descriptionMentionsRemoteTriggers() async throws {
        let tool = createRemoteTriggerTool()

        let desc = tool.description.lowercased()
        XCTAssertTrue(
            desc.contains("remote") || desc.contains("trigger"),
            "Description should mention remote or trigger"
        )
    }

    // MARK: - AC12: RemoteTriggerTool isReadOnly

    /// AC12 [P0]: RemoteTrigger tool isReadOnly returns false (conceptually has write operations).
    func testCreateRemoteTriggerTool_isReadOnly_returnsFalse() async throws {
        let tool = createRemoteTriggerTool()
        XCTAssertFalse(tool.isReadOnly, "RemoteTrigger tool should NOT be read-only")
    }

    // MARK: - AC13: RemoteTriggerTool inputSchema Matches TS SDK

    /// AC13 [P0]: RemoteTrigger inputSchema has type "object".
    func testCreateRemoteTriggerTool_inputSchema_hasCorrectType() async throws {
        let tool = createRemoteTriggerTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")
    }

    /// AC13 [P0]: RemoteTrigger inputSchema has "action" in required array.
    func testCreateRemoteTriggerTool_inputSchema_actionIsRequired() async throws {
        let tool = createRemoteTriggerTool()
        let schema = tool.inputSchema

        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["action"])
    }

    /// AC13 [P0]: RemoteTrigger inputSchema action enum contains all 5 values.
    func testCreateRemoteTriggerTool_inputSchema_actionEnum_hasAllFiveValues() async throws {
        let tool = createRemoteTriggerTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let actionProp = properties?["action"] as? [String: Any]
        let enumValues = actionProp?["enum"] as? [String]

        XCTAssertNotNil(enumValues, "action should have enum values")
        let expectedEnums = ["list", "get", "create", "update", "run"]
        XCTAssertEqual(Set(enumValues!), Set(expectedEnums),
                       "action enum should contain list, get, create, update, run")
    }

    /// AC13 [P0]: RemoteTrigger inputSchema has id field (string, optional).
    func testCreateRemoteTriggerTool_inputSchema_hasOptionalId() async throws {
        let tool = createRemoteTriggerTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let idProp = properties?["id"] as? [String: Any]
        XCTAssertNotNil(idProp, "id property should exist")
        XCTAssertEqual(idProp?["type"] as? String, "string")

        let required = schema["required"] as? [String] ?? []
        XCTAssertFalse(required.contains("id"), "id should be optional")
    }

    /// AC13 [P0]: RemoteTrigger inputSchema has name field (string, optional).
    func testCreateRemoteTriggerTool_inputSchema_hasOptionalName() async throws {
        let tool = createRemoteTriggerTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let nameProp = properties?["name"] as? [String: Any]
        XCTAssertNotNil(nameProp, "name property should exist")
        XCTAssertEqual(nameProp?["type"] as? String, "string")

        let required = schema["required"] as? [String] ?? []
        XCTAssertFalse(required.contains("name"), "name should be optional")
    }

    /// AC13 [P0]: RemoteTrigger inputSchema has schedule field (string, optional).
    func testCreateRemoteTriggerTool_inputSchema_hasOptionalSchedule() async throws {
        let tool = createRemoteTriggerTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let scheduleProp = properties?["schedule"] as? [String: Any]
        XCTAssertNotNil(scheduleProp, "schedule property should exist")
        XCTAssertEqual(scheduleProp?["type"] as? String, "string")

        let required = schema["required"] as? [String] ?? []
        XCTAssertFalse(required.contains("schedule"), "schedule should be optional")
    }

    /// AC13 [P0]: RemoteTrigger inputSchema has prompt field (string, optional).
    func testCreateRemoteTriggerTool_inputSchema_hasOptionalPrompt() async throws {
        let tool = createRemoteTriggerTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let promptProp = properties?["prompt"] as? [String: Any]
        XCTAssertNotNil(promptProp, "prompt property should exist")
        XCTAssertEqual(promptProp?["type"] as? String, "string")

        let required = schema["required"] as? [String] ?? []
        XCTAssertFalse(required.contains("prompt"), "prompt should be optional")
    }

    // MARK: - AC11: RemoteTrigger Stub Implementation

    /// AC11 [P0]: RemoteTrigger list action returns stub message.
    func testRemoteTrigger_list_returnsStubMessage() async throws {
        let tool = createRemoteTriggerTool()
        let context = makeContext()

        let input: [String: Any] = ["action": "list"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("RemoteTrigger") && result.content.contains("list"),
            "Should contain 'RemoteTrigger list' in stub message"
        )
        XCTAssertTrue(
            result.content.contains("remote backend") || result.content.contains("standalone"),
            "Should mention remote backend or standalone mode"
        )
    }

    /// AC11 [P0]: RemoteTrigger get action returns stub message.
    func testRemoteTrigger_get_returnsStubMessage() async throws {
        let tool = createRemoteTriggerTool()
        let context = makeContext()

        let input: [String: Any] = ["action": "get", "id": "trigger-1"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("RemoteTrigger") && result.content.contains("get"),
            "Should contain 'RemoteTrigger get' in stub message"
        )
    }

    /// AC11 [P0]: RemoteTrigger create action returns stub message.
    func testRemoteTrigger_create_returnsStubMessage() async throws {
        let tool = createRemoteTriggerTool()
        let context = makeContext()

        let input: [String: Any] = [
            "action": "create",
            "name": "daily-report",
            "schedule": "0 9 * * *",
            "prompt": "Generate daily report"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("RemoteTrigger") && result.content.contains("create"),
            "Should contain 'RemoteTrigger create' in stub message"
        )
    }

    /// AC11 [P0]: RemoteTrigger update action returns stub message.
    func testRemoteTrigger_update_returnsStubMessage() async throws {
        let tool = createRemoteTriggerTool()
        let context = makeContext()

        let input: [String: Any] = [
            "action": "update",
            "id": "trigger-1",
            "schedule": "0 10 * * *"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("RemoteTrigger") && result.content.contains("update"),
            "Should contain 'RemoteTrigger update' in stub message"
        )
    }

    /// AC11 [P0]: RemoteTrigger run action returns stub message.
    func testRemoteTrigger_run_returnsStubMessage() async throws {
        let tool = createRemoteTriggerTool()
        let context = makeContext()

        let input: [String: Any] = ["action": "run", "id": "trigger-1"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("RemoteTrigger") && result.content.contains("run"),
            "Should contain 'RemoteTrigger run' in stub message"
        )
    }

    /// AC11 [P0]: All stub messages mention CronCreate/CronList/CronDelete alternatives.
    func testRemoteTrigger_stubMentionsCronAlternatives() async throws {
        let tool = createRemoteTriggerTool()
        let context = makeContext()

        let actions = ["list", "get", "create", "update", "run"]
        for action in actions {
            let input: [String: Any] = ["action": action]
            let result = await tool.call(input: input, context: context)

            XCTAssertTrue(
                result.content.contains("CronCreate") || result.content.contains("CronList") || result.content.contains("CronDelete"),
                "Stub for action '\(action)' should mention CronCreate/CronList/CronDelete alternatives"
            )
        }
    }

    // MARK: - AC15: Error Handling -- Never Throws

    /// AC15 [P0]: RemoteTrigger tool never throws -- always returns ToolResult even with malformed input.
    func testRemoteTriggerTool_neverThrows_malformedInput() async throws {
        let tool = createRemoteTriggerTool()
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

    /// AC14 [P0]: RemoteTrigger tool does not require stores in context (no Actor store needed).
    func testRemoteTriggerTool_doesNotRequireStoreInContext() async throws {
        let tool = createRemoteTriggerTool()
        // Minimal context with only cwd and toolUseId -- no stores
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        let input: [String: Any] = ["action": "list"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertFalse(result.content.isEmpty)
    }

    // MARK: - AC16: ToolRegistry Registration

    /// AC16 [P0]: getAllBaseTools(tier: .specialist) includes createRemoteTriggerTool.
    func testToolRegistry_specialistTier_includesRemoteTriggerTool() async throws {
        let tools = getAllBaseTools(tier: .specialist)
        let names = tools.map { $0.name }

        XCTAssertTrue(names.contains("RemoteTrigger"), "Specialist tier should include RemoteTrigger tool")
    }
}

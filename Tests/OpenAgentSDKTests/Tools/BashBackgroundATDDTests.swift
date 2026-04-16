import XCTest
@testable import OpenAgentSDK

// MARK: - BashInput.run_in_background ATDD Tests (Story 17-3)

/// ATDD RED PHASE: Tests for Story 17-3 AC3 -- BashInput.run_in_background.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `BashInput` gains a `runInBackground: Bool?` field
///   - Bash tool's inputSchema includes `"run_in_background"` property
///   - When `runInBackground == true`, the tool returns immediately with a backgroundTaskId
///   - Background task tracking is implemented
/// TDD Phase: RED (feature not implemented yet)
final class BashBackgroundATDDTests: XCTestCase {

    // MARK: - Helpers

    /// Creates the Bash tool via the public factory function.
    private func makeBashTool() -> ToolProtocol {
        return createBashTool()
    }

    /// Calls the tool with a dictionary input and returns the ToolResult.
    private func callTool(
        _ tool: ToolProtocol,
        input: [String: Any],
        cwd: String? = nil
    ) async -> ToolResult {
        let context = ToolContext(
            cwd: cwd ?? NSTemporaryDirectory(),
            toolUseId: "test-\(UUID().uuidString)"
        )
        return await tool.call(input: input, context: context)
    }

    // MARK: - AC3: BashInput schema includes run_in_background

    /// AC3 [P0]: Bash tool inputSchema should include "run_in_background" property.
    func testBashTool_InputSchema_IncludesRunInBackground() {
        // Given: the Bash tool
        let tool = makeBashTool()

        // When: inspecting the inputSchema properties
        let props = tool.inputSchema["properties"] as? [String: Any]

        // Then: "run_in_background" is present in the schema
        XCTAssertNotNil(props?["run_in_background"],
                         "Bash inputSchema should include 'run_in_background' property")
    }

    /// AC3 [P1]: run_in_background schema has correct type and description.
    func testBashTool_RunInBackground_SchemaHasCorrectType() {
        // Given: the Bash tool
        let tool = makeBashTool()
        let props = tool.inputSchema["properties"] as? [String: Any]

        // When: inspecting the run_in_background property definition
        let runInBackgroundProp = props?["run_in_background"] as? [String: Any]

        // Then: it should have type "boolean" and a description
        XCTAssertEqual(runInBackgroundProp?["type"] as? String, "boolean",
                        "run_in_background should be type 'boolean'")
        XCTAssertNotNil(runInBackgroundProp?["description"],
                         "run_in_background should have a description")
    }

    /// AC3 [P1]: run_in_background is NOT in the required fields.
    func testBashTool_RunInBackground_NotRequired() {
        // Given: the Bash tool
        let tool = makeBashTool()
        let required = tool.inputSchema["required"] as? [String]

        // Then: "run_in_background" is NOT in the required array
        XCTAssertFalse(required?.contains("run_in_background") ?? false,
                        "run_in_background should be optional (not in required)")
    }

    // MARK: - AC3: Background execution behavior

    /// AC3 [P0]: When runInBackground is true, Bash returns immediately with a background task ID.
    func testBash_RunInBackground_ReturnsBackgroundTaskId() async {
        // Given: the Bash tool
        let tool = makeBashTool()

        // When: executing a long-running command in the background
        let result = await callTool(tool, input: [
            "command": "sleep 5",
            "run_in_background": true
        ])

        // Then: result is NOT an error
        XCTAssertFalse(result.isError,
                         "Background execution should not return error, got: \(result.content)")

        // And: result contains a background task ID
        XCTAssertTrue(result.content.contains("Background task started"),
                       "Should indicate background task started, got: \(result.content)")

        // And: result contains a task ID (UUID format or similar)
        XCTAssertTrue(result.content.contains("ID:"),
                      "Should contain task ID, got: \(result.content)")
    }

    /// AC3 [P0]: When runInBackground is false (or not set), Bash executes normally (blocking).
    func testBash_RunInBackground_False_ExecutesNormally() async {
        // Given: the Bash tool
        let tool = makeBashTool()

        // When: executing with run_in_background = false
        let result = await callTool(tool, input: [
            "command": "echo blocking",
            "run_in_background": false
        ])

        // Then: command executes normally (blocking)
        XCTAssertFalse(result.isError,
                         "Normal execution should succeed, got: \(result.content)")
        XCTAssertTrue(result.content.contains("blocking"),
                       "Should contain command output, got: \(result.content)")
    }

    /// AC3 [P0]: When runInBackground is not specified, Bash executes normally (blocking).
    func testBash_RunInBackground_Unset_ExecutesNormally() async {
        // Given: the Bash tool
        let tool = makeBashTool()

        // When: executing without run_in_background parameter
        let result = await callTool(tool, input: [
            "command": "echo normal"
        ])

        // Then: command executes normally (blocking, same as pre-17-3 behavior)
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("normal"),
                       "Should execute normally without run_in_background, got: \(result.content)")
    }

    /// AC3 [P1]: Background execution returns quickly (does not wait for command to finish).
    func testBash_RunInBackground_ReturnsQuickly() async {
        // Given: the Bash tool and a long-running command
        let tool = makeBashTool()
        let start = Date()

        // When: executing a 5-second command in background
        let result = await callTool(tool, input: [
            "command": "sleep 5",
            "run_in_background": true
        ])

        let elapsed = Date().timeIntervalSince(start)

        // Then: should return within 2 seconds (not wait for 5s)
        XCTAssertLessThan(elapsed, 2.0,
                           "Background command should return quickly, took \(elapsed)s")
        XCTAssertFalse(result.isError)
    }

    /// AC3 [P1]: Background command with description field still works.
    func testBash_RunInBackground_WithDescription() async {
        // Given: the Bash tool
        let tool = makeBashTool()

        // When: executing a background command with a description
        let result = await callTool(tool, input: [
            "command": "sleep 1",
            "description": "A background sleep",
            "run_in_background": true
        ])

        // Then: it still works
        XCTAssertFalse(result.isError,
                         "Background with description should work, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Background task started"),
                       "Should indicate background task started")
    }

    // MARK: - AC3: Backward compatibility

    /// AC3 [P0]: All existing Bash tool behaviors still work without run_in_background.
    func testBash_BackwardCompat_ExistingBehaviorsWork() async {
        let tool = makeBashTool()

        // Simple echo
        let echo = await callTool(tool, input: ["command": "echo compat"])
        XCTAssertFalse(echo.isError)
        XCTAssertTrue(echo.content.contains("compat"))

        // Non-zero exit code (not isError)
        let exitCode = await callTool(tool, input: ["command": "exit 1"])
        XCTAssertFalse(exitCode.isError,
                         "Exit code 1 should NOT be isError (backward compat)")
        XCTAssertTrue(exitCode.content.contains("Exit code: 1"),
                       "Should still include exit code in output")

        // Timeout still works
        let timeout = await callTool(tool, input: [
            "command": "sleep 30",
            "timeout": 100
        ])
        XCTAssertTrue(timeout.isError || timeout.content.lowercased().contains("timeout"),
                       "Timeout should still work (backward compat)")
    }
}

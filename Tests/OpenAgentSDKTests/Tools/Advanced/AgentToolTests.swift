import XCTest
@testable import OpenAgentSDK

// MARK: - Mock SubAgentSpawner

/// Mock spawner for testing AgentTool without real API calls.
/// Records call parameters for assertion and returns configurable results.
final class MockSubAgentSpawner: SubAgentSpawner, @unchecked Sendable {
    let result: SubAgentResult
    private(set) var spawnCalls: [SpawnCall] = []
    private let lock = NSLock()

    struct SpawnCall: Sendable {
        let prompt: String
        let model: String?
        let systemPrompt: String?
        let allowedTools: [String]?
        let maxTurns: Int?
    }

    init(result: SubAgentResult) {
        self.result = result
    }

    func spawn(
        prompt: String,
        model: String?,
        systemPrompt: String?,
        allowedTools: [String]?,
        maxTurns: Int?
    ) async -> SubAgentResult {
        lock.lock()
        spawnCalls.append(SpawnCall(
            prompt: prompt,
            model: model,
            systemPrompt: systemPrompt,
            allowedTools: allowedTools,
            maxTurns: maxTurns
        ))
        lock.unlock()
        return result
    }
}

// MARK: - AgentTool Tests

/// ATDD RED PHASE: Tests for Story 4.3 -- Agent Tool (Sub-Agent Spawn).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `AgentDefinition` gains `tools` and `maxTurns` fields
///   - `SubAgentSpawner` protocol is defined in Types/
///   - `SubAgentResult` struct is defined in Types/
///   - `ToolContext` gains `agentSpawner` field
///   - `createAgentTool()` factory function is implemented in Tools/Advanced/
/// TDD Phase: RED (feature not implemented yet)
final class AgentToolTests: XCTestCase {

    // MARK: - AC1: createAgentTool returns valid ToolProtocol

    /// AC1 [P0]: createAgentTool() returns a ToolProtocol with name "Agent".
    func testCreateAgentTool_returnsToolProtocol() async throws {
        // When: creating the Agent tool
        let tool = createAgentTool()

        // Then: it is a valid ToolProtocol
        XCTAssertEqual(tool.name, "Agent")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertFalse(tool.isReadOnly)
    }

    /// AC1 [P0]: The Agent tool has a valid inputSchema.
    func testCreateAgentTool_hasValidInputSchema() async throws {
        let tool = createAgentTool()

        let schema = tool.inputSchema
        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        XCTAssertNotNil(properties?["prompt"])
        XCTAssertNotNil(properties?["description"])

        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["prompt", "description"])
    }

    // MARK: - AC2: Sub-agent execution returns result to parent

    /// AC2 [P0]: When spawner succeeds, AgentTool returns successful ToolResult.
    func testAgentTool_success_returnsTextResult() async throws {
        // Given: a spawner that returns success
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Exploration complete. Found 5 files.",
            toolCalls: [],
            isError: false
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        // When: calling the tool with valid input
        let input: [String: Any] = [
            "prompt": "Find all Swift files in the project",
            "description": "Find Swift files"
        ]
        let result = await tool.call(input: input, context: context)

        // Then: result is successful
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Exploration complete"))
    }

    /// AC2 [P0]: When spawner returns error, AgentTool returns isError ToolResult.
    func testAgentTool_spawnerError_returnsIsError() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Subagent error: API connection failed",
            toolCalls: [],
            isError: true
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Do something",
            "description": "Test task"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("Subagent error"))
    }

    // MARK: - AC3: Built-in agent types

    /// AC3 [P0]: Using "Explore" subagent_type passes Explore system prompt to spawner.
    func testAgentTool_exploreType_passesExploreSystemPrompt() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Found 3 files",
            toolCalls: ["Glob", "Grep"],
            isError: false
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Find test files",
            "description": "Find tests",
            "subagent_type": "Explore"
        ]
        _ = await tool.call(input: input, context: context)

        // Then: spawner was called with Explore's system prompt
        XCTAssertEqual(mockSpawner.spawnCalls.count, 1)
        let call = mockSpawner.spawnCalls[0]
        XCTAssertNotNil(call.systemPrompt)
        XCTAssertTrue(call.systemPrompt?.contains("exploration") == true ||
                       call.systemPrompt?.contains("Explore") == true ||
                       call.systemPrompt?.contains("codebase") == true)
    }

    /// AC3 [P0]: Using "Explore" type passes allowed tools to spawner.
    func testAgentTool_exploreType_passesAllowedTools() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Done",
            toolCalls: [],
            isError: false
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Search code",
            "description": "Search",
            "subagent_type": "Explore"
        ]
        _ = await tool.call(input: input, context: context)

        let call = mockSpawner.spawnCalls[0]
        XCTAssertNotNil(call.allowedTools)
        let tools = call.allowedTools ?? []
        XCTAssertTrue(tools.contains("Read"))
        XCTAssertTrue(tools.contains("Glob"))
        XCTAssertTrue(tools.contains("Grep"))
        XCTAssertTrue(tools.contains("Bash"))
    }

    /// AC3 [P0]: Using "Plan" subagent_type passes Plan system prompt.
    func testAgentTool_planType_passesPlanSystemPrompt() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Plan created",
            toolCalls: [],
            isError: false
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Plan the authentication feature",
            "description": "Plan auth",
            "subagent_type": "Plan"
        ]
        _ = await tool.call(input: input, context: context)

        let call = mockSpawner.spawnCalls[0]
        XCTAssertNotNil(call.systemPrompt)
        XCTAssertTrue(call.systemPrompt?.contains("architect") == true ||
                       call.systemPrompt?.contains("Plan") == true ||
                       call.systemPrompt?.contains("implementation plan") == true)
    }

    // MARK: - AC4: Tool call summary in output

    /// AC4 [P0]: Tool calls are included in the output summary.
    func testAgentTool_success_includesToolCallSummary() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Found 3 files",
            toolCalls: ["Glob", "Grep", "Read"],
            isError: false
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Search",
            "description": "Search"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.content.contains("[Tools used:"))
        XCTAssertTrue(result.content.contains("Glob"))
        XCTAssertTrue(result.content.contains("Grep"))
        XCTAssertTrue(result.content.contains("Read"))
    }

    /// AC4 [P1]: No tool calls produces output without tool summary.
    func testAgentTool_noToolCalls_noSummaryInOutput() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Simple answer",
            toolCalls: [],
            isError: false
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "What is 2+2?",
            "description": "Math"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.content.contains("[Tools used:"))
    }

    // MARK: - AC5: Model override

    /// AC5 [P0]: Custom model parameter overrides the default.
    func testAgentTool_customModel_overridesDefault() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Done",
            toolCalls: [],
            isError: false
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Quick search",
            "description": "Search",
            "model": "claude-haiku-4-5-20251001"
        ]
        _ = await tool.call(input: input, context: context)

        let call = mockSpawner.spawnCalls[0]
        XCTAssertEqual(call.model, "claude-haiku-4-5-20251001")
    }

    /// AC5 [P1]: No model parameter passes nil to spawner (inherits parent).
    func testAgentTool_noModel_passesNilToSpawner() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Done",
            toolCalls: [],
            isError: false
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Quick search",
            "description": "Search"
        ]
        _ = await tool.call(input: input, context: context)

        let call = mockSpawner.spawnCalls[0]
        XCTAssertNil(call.model)
    }

    // MARK: - AC6: No spawner error handling

    /// AC6 [P0]: When agentSpawner is nil, returns error ToolResult.
    func testAgentTool_noSpawner_returnsErrorMessage() async throws {
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp")  // no agentSpawner

        let input: [String: Any] = [
            "prompt": "Do something",
            "description": "Task"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("spawner") ||
                       result.content.contains("not available") ||
                       result.content.contains("SubAgentSpawner"))
    }

    // MARK: - AC9: Error handling does not crash parent loop

    /// AC9 [P0]: Tool never throws — always returns ToolResult.
    func testAgentTool_neverThrows_alwaysReturnsToolResult() async throws {
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp")  // no spawner

        // Various malformed inputs
        let badInputs: [[String: Any]] = [
            [:],  // missing required fields
            ["prompt": ""],  // missing description
            ["description": "test"],  // missing prompt
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "")
            // Error or not depends on decoding, but never crashes
        }
    }

    // MARK: - maxTurns parameter

    /// AC5 [P1]: Custom maxTurns is passed through to spawner.
    func testAgentTool_customMaxTurns_passedToSpawner() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Done",
            toolCalls: [],
            isError: false
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Quick task",
            "description": "Quick",
            "maxTurns": 5
        ]
        _ = await tool.call(input: input, context: context)

        let call = mockSpawner.spawnCalls[0]
        XCTAssertEqual(call.maxTurns, 5)
    }

    // MARK: - isReadOnly

    /// AC1 [P1]: AgentTool is NOT read-only (it spawns sub-agents that may write).
    func testCreateAgentTool_isNotReadOnly() async throws {
        let tool = createAgentTool()
        XCTAssertFalse(tool.isReadOnly)
    }
}

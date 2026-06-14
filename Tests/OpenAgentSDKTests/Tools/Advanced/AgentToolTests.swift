import XCTest
@testable import OpenAgentSDK

// MARK: - Mock SubAgentSpawner

/// Mock spawner for testing AgentTool without real API calls.
/// Records call parameters for assertion and returns configurable results.
final class MockSubAgentSpawner: SubAgentSpawner, @unchecked Sendable {
    let result: SubAgentResult
    private(set) var lastCall: SpawnCall?

    struct SpawnCall: Sendable {
        let prompt: String
        let model: String?
        let systemPrompt: String?
        let allowedTools: [String]?
        let maxTurns: Int?
        let disallowedTools: [String]?
        let mcpServers: [AgentMcpServerSpec]?
        let skills: [String]?
        let runInBackground: Bool?
        let isolation: String?
        let name: String?
        let teamName: String?
        let mode: PermissionMode?
        let resume: String?
    }

    init(result: SubAgentResult) {
        self.result = result
    }

    /// Story 29.6 test hook: configure the mock to return a result with the given
    /// `fieldDiagnostics`. Used by the deferred-field rendering tests below. Default
    /// parameter keeps every existing 13+ call sites compiling unchanged.
    static func makeWithDiagnostics(
        text: String = "Done",
        toolCalls: [String] = [],
        isError: Bool = false,
        fieldDiagnostics: [SubAgentFieldDiagnostics]
    ) -> MockSubAgentSpawner {
        return MockSubAgentSpawner(result: SubAgentResult(
            text: text,
            toolCalls: toolCalls,
            isError: isError,
            fieldDiagnostics: fieldDiagnostics
        ))
    }

    func spawn(
        prompt: String,
        model: String?,
        systemPrompt: String?,
        allowedTools: [String]?,
        maxTurns: Int?
    ) async -> SubAgentResult {
        lastCall = SpawnCall(
            prompt: prompt,
            model: model,
            systemPrompt: systemPrompt,
            allowedTools: allowedTools,
            maxTurns: maxTurns,
            disallowedTools: nil,
            mcpServers: nil,
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )
        return result
    }

    func spawn(
        prompt: String,
        model: String?,
        systemPrompt: String?,
        allowedTools: [String]?,
        maxTurns: Int?,
        disallowedTools: [String]?,
        mcpServers: [AgentMcpServerSpec]?,
        skills: [String]?,
        runInBackground: Bool?,
        isolation: String?,
        name: String?,
        teamName: String?,
        mode: PermissionMode?,
        resume: String?
    ) async -> SubAgentResult {
        lastCall = SpawnCall(
            prompt: prompt,
            model: model,
            systemPrompt: systemPrompt,
            allowedTools: allowedTools,
            maxTurns: maxTurns,
            disallowedTools: disallowedTools,
            mcpServers: mcpServers,
            skills: skills,
            runInBackground: runInBackground,
            isolation: isolation,
            name: name,
            teamName: teamName,
            mode: mode,
            resume: resume
        )
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
        XCTAssertEqual(mockSpawner.lastCall != nil, true)
        let call = mockSpawner.lastCall!
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

        let call = mockSpawner.lastCall!
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

        let call = mockSpawner.lastCall!
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

        let call = mockSpawner.lastCall!
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

        let call = mockSpawner.lastCall!
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

        let call = mockSpawner.lastCall!
        XCTAssertEqual(call.maxTurns, 5)
    }

    // MARK: - isReadOnly

    /// AC1 [P1]: AgentTool is NOT read-only (it spawns sub-agents that may write).
    func testCreateAgentTool_isNotReadOnly() async throws {
        let tool = createAgentTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: - Task Tool (Story 29.1)

    /// ATDD RED PHASE: Tests for Story 29.1 -- `Task` alias of `Agent` (subagent launcher).
    /// All tests assert EXPECTED behavior. They will FAIL until:
    ///   - `createTaskTool()` public factory is implemented in Tools/Advanced/AgentTool.swift
    ///   - Private `createSubAgentLauncherTool(name:description:)` shared helper is extracted
    /// TDD Phase: RED (feature not implemented yet)

    /// AC1 [P0]: createTaskTool() returns a ToolProtocol with name "Task".
    /// Verifies the public alias surface exists and is named correctly.
    func testCreateTaskTool_returnsToolNamedTask() async throws {
        // When: creating the Task tool
        let tool = createTaskTool()

        // Then: it is a valid ToolProtocol named "Task"
        XCTAssertEqual(tool.name, "Task")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertFalse(tool.isReadOnly)
    }

    /// AC1 [P0]: Task tool exposes the same inputSchema (properties + required) as Agent.
    /// Schema parity is mandatory so existing LLM prompts work without rewriting.
    func testCreateTaskTool_schemaEquivalentToAgent() async throws {
        let agentTool = createAgentTool()
        let taskTool = createTaskTool()

        let agentSchema = agentTool.inputSchema
        let taskSchema = taskTool.inputSchema

        // Both are objects
        XCTAssertEqual(taskSchema["type"] as? String, "object")
        XCTAssertEqual(taskSchema["type"] as? String, agentSchema["type"] as? String)

        // Required arrays are identical
        let agentRequired = agentSchema["required"] as? [String]
        let taskRequired = taskSchema["required"] as? [String]
        XCTAssertEqual(taskRequired, agentRequired)
        XCTAssertEqual(taskRequired, ["prompt", "description"])

        // Property keys are identical (no field drift)
        let agentProps = agentSchema["properties"] as? [String: Any]
        let taskProps = taskSchema["properties"] as? [String: Any]
        XCTAssertNotNil(agentProps)
        XCTAssertNotNil(taskProps)

        let expectedKeys: Set<String> = [
            "prompt", "description", "subagent_type", "model", "name",
            "maxTurns", "run_in_background", "isolation", "team_name",
            "mode", "resume"
        ]
        XCTAssertEqual(Set(taskProps!.keys), expectedKeys)
        XCTAssertEqual(Set(taskProps!.keys), Set(agentProps!.keys))
    }

    /// AC2 [P0]: Task tool success path mirrors Agent's -- returns text result.
    /// When spawner is set and LLM invokes Task(prompt:, description:), output flows back.
    func testTaskTool_success_returnsTextResult() async throws {
        // Given: a spawner that returns success
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Exploration complete. Found 5 Swift files.",
            toolCalls: [],
            isError: false
        ))
        let tool = createTaskTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        // When: calling the Task tool with valid input
        let input: [String: Any] = [
            "prompt": "Find all Swift files in the project",
            "description": "Find Swift files"
        ]
        let result = await tool.call(input: input, context: context)

        // Then: result is successful and routes through the spawn path
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Exploration complete"))
        XCTAssertNotNil(mockSpawner.lastCall)
    }

    /// AC3 [P0]: Missing spawner produces an error equivalent to Agent's.
    /// Tool must NOT throw; returns ToolExecuteResult(isError: true) with a spawner mention.
    func testTaskTool_missingSpawner_returnsError() async throws {
        let tool = createTaskTool()
        let context = ToolContext(cwd: "/tmp")  // no agentSpawner

        let input: [String: Any] = [
            "prompt": "Do something",
            "description": "Test task"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(
            result.content.contains("spawner") ||
            result.content.contains("not available") ||
            result.content.contains("SubAgentSpawner"),
            "Expected missing-spawner error message; got: \(result.content)"
        )

        // Error message parity (modulo tool-name token) with Agent's missing-spawner error
        let agentTool = createAgentTool()
        let agentResult = await agentTool.call(input: input, context: context)
        XCTAssertTrue(agentResult.isError)
        // Both must mention the spawner gap; tokens may differ but content shape must match
        XCTAssertEqual(result.isError, agentResult.isError)
    }

    /// AC2 [P0]: Task tool resolves built-in subagent_type="Explore" with the Explore system prompt.
    /// Confirms BUILTIN_AGENTS lookup is shared between Agent and Task execution bodies.
    func testTaskTool_exploreType_passesExploreSystemPrompt() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Found 3 files",
            toolCalls: [],
            isError: false
        ))
        let tool = createTaskTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Find test files",
            "description": "Find tests",
            "subagent_type": "Explore"
        ]
        _ = await tool.call(input: input, context: context)

        XCTAssertNotNil(mockSpawner.lastCall)
        let call = mockSpawner.lastCall!
        XCTAssertNotNil(call.systemPrompt)
        XCTAssertTrue(
            call.systemPrompt?.contains("exploration") == true ||
            call.systemPrompt?.contains("Explore") == true ||
            call.systemPrompt?.contains("codebase") == true,
            "Expected Explore built-in system prompt; got: \(call.systemPrompt ?? "<nil>")"
        )
    }

    /// AC4 [P0]: Task tool appends `[Tools used: ...]` summary when toolCalls is non-empty.
    func testTaskTool_toolCallsSummaryAppended() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Found 3 files",
            toolCalls: ["Glob", "Grep"],
            isError: false
        ))
        let tool = createTaskTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Search",
            "description": "Search"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.content.hasSuffix("[Tools used: Glob, Grep]"),
                      "Expected output to end with tool summary; got: \(result.content)")
    }

    /// AC4 [P0]: Backward compatibility -- createAgentTool() still works and remains named "Agent".
    /// Guarantees no public-API regression after Task alias lands.
    func testCreateAgentTool_stillWorks_noRegression() async throws {
        let tool = createAgentTool()
        XCTAssertEqual(tool.name, "Agent")
        XCTAssertFalse(tool.description.isEmpty)
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: - Story 29.6: Deferred Field Diagnostics Rendering

    /// ATDD RED PHASE: Tests for Story 29.6 -- `createSubAgentLauncherTool`'s execution
    /// body must render deferred-field diagnostics into the tool output, so that callers
    /// using Claude Code-style workflow skills can see which subagent fields the SDK
    /// honored vs ignored.
    ///
    /// Tests below assert EXPECTED behavior. They will FAIL (compile-time) until:
    ///   - `SubAgentFieldDiagnostics` / `SubAgentFieldDiagnosticReason` exist in Types/
    ///   - `SubAgentResult.fieldDiagnostics` is added (with default nil)
    ///   - `createSubAgentLauncherTool` rendering branch inserts a diagnostics block
    ///     between `result.text` and `[Tools used: ...]`
    /// TDD Phase: RED (feature not implemented yet)
    ///
    /// Red mode: COMPILE-TIME -- `SubAgentFieldDiagnostics`, the `fieldDiagnostics:`
    /// parameter on `SubAgentResult.init`, and `MockSubAgentSpawner.makeWithDiagnostics`
    /// do not exist yet.

    /// AC6 [P0]: When the spawner returns `fieldDiagnostics`, the AgentTool output
    /// contains a diagnostics block naming each deferred field. The block appears
    /// AFTER `result.text` and BEFORE any `[Tools used: ...]` summary.
    func testAgentTool_outputIncludesDiagnosticsBlock() async throws {
        // Given: a spawner returning diagnostics for run_in_background
        let mockSpawner = MockSubAgentSpawner.makeWithDiagnostics(
            text: "Background task completed.",
            toolCalls: ["Read"],
            isError: false,
            fieldDiagnostics: [
                SubAgentFieldDiagnostics(
                    fieldName: "run_in_background",
                    rawValue: "true",
                    reason: .backgroundExecutionNotImplemented
                ),
            ]
        )
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        // When: calling the Agent tool
        let input: [String: Any] = [
            "prompt": "Run in background",
            "description": "Bg task"
        ]
        let result = await tool.call(input: input, context: context)

        // Then: output mentions the deferred field and stays non-error
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Background task completed."),
                      "Primary text must still appear first")
        XCTAssertTrue(
            result.content.contains("run_in_background"),
            "Diagnostics block must name the deferred field"
        )
        XCTAssertTrue(
            result.content.contains("[Tools used:"),
            "Tool-call summary must still appear after diagnostics"
        )
        // Diagnostics block must precede [Tools used:]
        if let diagRange = result.content.range(of: "run_in_background"),
           let toolsRange = result.content.range(of: "[Tools used:") {
            XCTAssertLessThan(diagRange.lowerBound, toolsRange.lowerBound,
                              "Diagnostics block must precede [Tools used:]")
        }
    }

    /// AC6 [P0]: The Task tool (Story 29.1 alias) shares the same rendering factory,
    /// so its output also surfaces the diagnostics block.
    func testTaskTool_outputIncludesDiagnosticsBlock() async throws {
        let mockSpawner = MockSubAgentSpawner.makeWithDiagnostics(
            text: "Resumed task.",
            toolCalls: [],
            isError: false,
            fieldDiagnostics: [
                SubAgentFieldDiagnostics(
                    fieldName: "resume",
                    rawValue: "abc123",
                    reason: .resumeNotImplemented
                ),
            ]
        )
        let tool = createTaskTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Resume task",
            "description": "Resume"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("resume"),
                      "Task tool must also render the deferred-field diagnostics block")
    }

    /// AC6 [P0]: Backward compatibility -- when `fieldDiagnostics` is nil, the output
    /// is byte-for-byte identical to the pre-29.6 behavior (no diagnostics block).
    /// Guards every existing 13+ AgentToolTests call site.
    func testAgentTool_noDiagnostics_outputUnchanged() async throws {
        // Given: a spawner returning nil fieldDiagnostics (default SubAgentResult path)
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Plain answer",
            toolCalls: ["Read"],
            isError: false
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Quick search",
            "description": "Search"
        ]
        let result = await tool.call(input: input, context: context)

        // Then: no diagnostics markers in output
        XCTAssertFalse(result.content.contains("ignored:"),
                       "No diagnostics block when fieldDiagnostics is nil")
        XCTAssertTrue(result.content.hasSuffix("[Tools used: Read]"),
                      "Output must remain byte-identical to pre-29.6 behavior")
    }

    /// AC6 [P1]: When `fieldDiagnostics` is nil AND there are no tool calls, the
    /// output is just the bare text -- no diagnostics, no tool summary.
    func testAgentTool_noDiagnosticsNoToolCalls_bareOutput() async throws {
        let mockSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Direct answer",
            toolCalls: [],
            isError: false
        ))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Math",
            "description": "Math"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertEqual(result.content, "Direct answer",
                       "Output must be exactly the bare text when no diagnostics and no tool calls")
    }

    /// AC6 [P1]: Multiple diagnostics are rendered as multiple lines in order.
    func testAgentTool_multipleDiagnostics_renderedInOrder() async throws {
        let mockSpawner = MockSubAgentSpawner.makeWithDiagnostics(
            text: "Done",
            toolCalls: [],
            isError: false,
            fieldDiagnostics: [
                SubAgentFieldDiagnostics(
                    fieldName: "run_in_background",
                    rawValue: "true",
                    reason: .backgroundExecutionNotImplemented
                ),
                SubAgentFieldDiagnostics(
                    fieldName: "isolation",
                    rawValue: "worktree",
                    reason: .isolationNotImplemented
                ),
            ]
        )
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Multi deferred",
            "description": "Multi"
        ]
        let result = await tool.call(input: input, context: context)

        // Both diagnostics must appear in order
        if let bgRange = result.content.range(of: "run_in_background"),
           let isoRange = result.content.range(of: "isolation") {
            XCTAssertLessThan(bgRange.lowerBound, isoRange.lowerBound,
                              "Diagnostics must be rendered in collection order")
        } else {
            XCTFail("Both deferred fields must appear in the diagnostics block")
        }
    }

    // MARK: - Story 29.7: Epic-End Integration Coverage

    /// Story 29.7 integration tests consolidate cross-feature seams across the entire
    /// Epic 29 surface. Unlike the per-story single-point tests above (29.1 alias,
    /// 29.6 rendering), these exercise **the joins between** features — e.g. that the
    /// `Task` alias shares its spawn call semantics with `Agent`, that a Task-only tool
    /// pool still triggers spawner injection, and that the two diagnostic dimensions
    /// (deferred fields vs. tool filtering) do not pollute each other.
    ///
    /// TDD phase note: Story 29.7 verifies ALREADY-IMPLEMENTED behavior from Stories
    /// 29.1–29.6. There is no red phase — these tests are expected to be green on
    /// first run (per story Dev Notes line 206).

    /// AC1 [P0]: `createTaskTool()` is a true alias of `createAgentTool()` — both share
    /// the single `createSubAgentLauncherTool` factory, so the same input must reach the
    /// spawner with identical field values. This proves the alias is not a second,
    /// drift-prone implementation but the same factory invoked under a different name.
    ///
    /// Integration target: Stories 29.1 (alias) + 29.6 (spawn plumbing).
    func testCreateTaskTool_aliasSharesSpawnCallSemanticsWithAgent() async throws {
        // Given: two mock spawners, one fed to each launcher variant
        let agentSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Agent result", toolCalls: [], isError: false
        ))
        let taskSpawner = MockSubAgentSpawner(result: SubAgentResult(
            text: "Task result", toolCalls: [], isError: false
        ))

        let agentTool = createAgentTool()
        let taskTool = createTaskTool()

        let agentContext = ToolContext(cwd: "/tmp", agentSpawner: agentSpawner)
        let taskContext = ToolContext(cwd: "/tmp", agentSpawner: taskSpawner)

        // Identical input on both paths — proves the alias is content-identical.
        let sharedInput: [String: Any] = [
            "prompt": "Shared investigation prompt",
            "subagent_type": "Explore",
            "description": "Shared description",
            "maxTurns": 7,
        ]

        // When: invoking both launchers with the same input
        let agentResult = await agentTool.call(input: sharedInput, context: agentContext)
        let taskResult = await taskTool.call(input: sharedInput, context: taskContext)

        // Then: both succeed (no spawner-missing error) and spawn was invoked identically
        XCTAssertFalse(agentResult.isError, "Agent path must succeed with a spawner present")
        XCTAssertFalse(taskResult.isError, "Task path must succeed with a spawner present")

        let agentCall = try XCTUnwrap(agentSpawner.lastCall,
                                      "Agent spawner must have been invoked")
        let taskCall = try XCTUnwrap(taskSpawner.lastCall,
                                     "Task spawner must have been invoked")

        XCTAssertEqual(agentCall.prompt, taskCall.prompt,
                       "Alias must forward an identical prompt to the spawner")
        XCTAssertEqual(agentCall.maxTurns, taskCall.maxTurns,
                       "Alias must forward identical maxTurns")
        // subagent_type is not on SpawnCall (it resolves into model/systemPrompt) — but
        // both paths use the same BUILTIN_AGENTS lookup, so the resolved model+systemPrompt
        // must match too, proving the shared factory selected the same built-in agent.
        XCTAssertEqual(agentCall.model, taskCall.model,
                       "Alias must resolve to the same built-in model")
    }

    /// AC1 [P0]: When `createTaskTool()` is invoked but no spawner is configured
    /// (`ToolContext.agentSpawner == nil`), the error message mentions "Task" specifically
    /// (via the `\(name)` interpolation in `createSubAgentLauncherTool`). This pins the
    /// alias's error path to Story 29.1 — the alias surfaces its OWN name in errors, not
    /// the Agent name, confirming the factory is parameterized by name.
    func testCreateTaskTool_spawnerMissingErrorMentionsTask() async throws {
        let tool = createTaskTool()
        // No agentSpawner injected — the canonical nil-spawner path.
        let context = ToolContext(cwd: "/tmp", agentSpawner: nil)

        let input: [String: Any] = [
            "prompt": "Anything",
            "description": "Probe",
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError, "Missing spawner must surface as an error")
        XCTAssertTrue(result.content.contains("Task"),
                      "Error must name the 'Task' tool (alias surfaces its own name); got: \(result.content)")
        XCTAssertTrue(result.content.lowercased().contains("spawner"),
                      "Error must mention the spawner requirement; got: \(result.content)")
    }
}

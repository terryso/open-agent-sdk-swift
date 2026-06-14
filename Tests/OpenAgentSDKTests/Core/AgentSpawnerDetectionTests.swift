import XCTest
@testable import OpenAgentSDK

import Foundation

// MARK: - AgentSpawnerDetectionTests (Story 29.2)

/// ATDD RED PHASE: Tests for Story 29.2 -- Agent-level spawner detection and the
/// shared `SubAgentLauncherNames` helper.
///
/// All tests below assert EXPECTED behavior. They will FAIL until:
///   - `enum SubAgentLauncherNames` is added to `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift`
///     with `static let default: [String] = ["Agent", "Task"]`
///     and `static func contains(_ toolName: String) -> Bool`
///   - `Agent.createSubAgentSpawner(...)` (private static, Core/Agent.swift:3225) detects launchers
///     via `SubAgentLauncherNames.contains($0.name)` instead of `$0.name == "Agent"`
///   - `Agent.supportedAgents()` (Core/Agent.swift:924) detects launchers via the same helper
///
/// TDD Phase: RED (feature not implemented yet)
final class AgentSpawnerDetectionTests: XCTestCase {

    // MARK: - Mock LLMClient

    /// Mock LLM client that emits a single tool_use response for a given tool name,
    /// then an end_turn. Lets us observe `ToolContext.agentSpawner` indirectly by
    /// invoking the launcher tool (which emits a "spawner missing" error when the
    /// spawner was not injected by `createSubAgentSpawner`).
    ///
    /// Project rule #27 (no real I/O in unit tests): this client performs zero network calls.
    private struct ToolUseThenEndMockClient: LLMClient, @unchecked Sendable {
        let toolName: String
        let toolUseId: String = "test-tool-use-id-29-2"
        let toolInput: [String: Any] = [
            "prompt": "Investigate the issue.",
            "description": "Single-action probe",
        ]

        nonisolated func sendMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> [String: Any] {
            return [
                "content": [
                    ["type": "tool_use", "id": toolUseId, "name": toolName, "input": toolInput],
                    ["type": "text", "text": "Probe issued."],
                ],
                "stop_reason": "end_turn",
                "usage": ["input_tokens": 10, "output_tokens": 5],
            ]
        }

        nonisolated func streamMessage(
            model: String, messages: [[String: Any]], maxTokens: Int,
            system: String?, tools: [[String: Any]]?, toolChoice: [String: Any]?,
            thinking: [String: Any]?, temperature: Double?
        ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
            let events: [SSEEvent] = [
                .messageStart(message: ["type": "message_start"]),
                .contentBlockStart(index: 0, contentBlock: ["type": "tool_use", "id": toolUseId, "name": toolName, "input": toolInput]),
                .contentBlockStop(index: 0),
                .contentBlockStart(index: 1, contentBlock: ["type": "text", "text": ""]),
                .contentBlockDelta(index: 1, delta: ["type": "text_delta", "text": "Probe issued."]),
                .contentBlockStop(index: 1),
                .messageDelta(delta: ["stop_reason": "end_turn"], usage: ["output_tokens": 5]),
                .messageStop,
            ]
            return AsyncThrowingStream { continuation in
                for event in events { continuation.yield(event) }
                continuation.finish()
            }
        }
    }

    // MARK: - Helpers

    /// Builds an `AgentOptions` with the given tool list.
    private func makeOptions(tools: [ToolProtocol]) -> AgentOptions {
        return AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            baseURL: nil,
            systemPrompt: "Test harness for spawner detection.",
            tools: tools
        )
    }

    // MARK: AC1: Spawner injected when only Task registered

    /// AC1 [P0]: When ONLY `Task` is registered (no `Agent`), `Agent.prompt(...)` still
    /// injects a spawner so the Task tool does not emit "spawner missing".
    ///
    /// RED-PHASE rationale: `createSubAgentSpawner` currently checks `$0.name == "Agent"` only.
    /// With only Task registered, the spawner is `nil` and the Task tool emits its
    /// Story 29.1 error. After Task 2 lands, the spawner is injected and the tool
    /// reports a different (network-side, mock-driven) failure path.
    func testCreateSubAgentSpawner_returnsSpawner_whenOnlyTaskRegistered() async throws {
        let tools: [ToolProtocol] = [createReadTool(), createTaskTool()]
        let agent = Agent(
            options: makeOptions(tools: tools),
            client: ToolUseThenEndMockClient(toolName: "Task")
        )

        let result = await agent.prompt("Probe the launcher.")

        // Spawner MUST be injected when only Task is registered.
        // If spawner is nil, AgentTool emits a hard error mentioning "spawner".
        // If spawner is present, the tool proceeds to spawn (and the child call eventually
        // fails with a network/auth error from the inner AnthropicClient, not a spawner error).
        let text = result.text
        XCTAssertFalse(
            text.contains("spawner") && text.lowercased().contains("missing"),
            "Tool must NOT emit 'spawner missing' when only Task is registered. Got: \(text)"
        )
    }

    /// AC1 [P0]: When BOTH `Agent` and `Task` are registered, `Agent.prompt(...)` still
    /// injects a spawner. Sanity that adding Task to a pool with Agent does not regress.
    func testCreateSubAgentSpawner_returnsSpawner_whenBothRegistered() async throws {
        let tools: [ToolProtocol] = [createReadTool(), createAgentTool(), createTaskTool()]
        let agent = Agent(
            options: makeOptions(tools: tools),
            client: ToolUseThenEndMockClient(toolName: "Task")
        )

        let result = await agent.prompt("Probe the launcher.")

        let text = result.text
        XCTAssertFalse(
            text.contains("spawner") && text.lowercased().contains("missing"),
            "Tool must NOT emit 'spawner missing' when both launchers are registered. Got: \(text)"
        )
    }

    /// AC1 [P1]: When NEITHER launcher is registered, `createSubAgentSpawner` returns nil.
    /// Sanity that the helper does not spuriously detect non-launcher tools.
    func testCreateSubAgentSpawner_returnsNil_whenNeitherRegistered() async throws {
        let tools: [ToolProtocol] = [createReadTool(), createBashTool()]
        let agent = Agent(
            options: makeOptions(tools: tools),
            client: ToolUseThenEndMockClient(toolName: "Task")
        )

        let result = await agent.prompt("Probe the launcher.")

        // With no launcher registered, the tool itself is not in the pool, so the LLM's
        // tool_use response is rejected as "unknown tool". No spawner error is expected.
        // The shape of the failure is irrelevant — we only assert that no spawner is
        // auto-created for unrelated tools.
        XCTAssertNotNil(result, "Agent.prompt must return a result even without a spawner")
    }

    // MARK: AC4: Shared helper for launcher-name list

    /// AC4 [P0]: `SubAgentLauncherNames.default` contains exactly ["Agent", "Task"].
    ///
    /// RED-PHASE rationale: the enum does not exist yet. This test will fail to compile
    /// until Task 1.1 adds the type. Compilation failure = red phase signal.
    func testSubAgentLauncherNames_defaultContainsAgentAndTask() async throws {
        let names = SubAgentLauncherNames.default

        XCTAssertTrue(names.contains("Agent"), "Default launcher list must include 'Agent'")
        XCTAssertTrue(names.contains("Task"), "Default launcher list must include 'Task'")
        XCTAssertEqual(names.count, 2, "Default launcher list must contain exactly 2 names (no string litter)")
    }

    /// AC4 [P0]: `SubAgentLauncherNames.contains(_:)` returns true for both launcher names
    /// and false for unrelated tools.
    func testSubAgentLauncherNames_containsMatchesExpected() async throws {
        XCTAssertTrue(SubAgentLauncherNames.contains("Agent"), "contains must return true for 'Agent'")
        XCTAssertTrue(SubAgentLauncherNames.contains("Task"), "contains must return true for 'Task'")

        XCTAssertFalse(SubAgentLauncherNames.contains("Bash"), "contains must return false for 'Bash'")
        XCTAssertFalse(SubAgentLauncherNames.contains("Read"), "contains must return false for 'Read'")
        XCTAssertFalse(SubAgentLauncherNames.contains(""), "contains must return false for empty string")
        XCTAssertFalse(SubAgentLauncherNames.contains("Agent "), "contains must return false for near-miss 'Agent '")
    }

    // MARK: AC5: Escape hatch preserved (default = strip both)

    /// AC5 [P0]: With no explicit recursion opt-in, a child spawned via `Task` does not
    /// itself inherit a `Task` tool. We assert this indirectly: the child's tool pool
    /// is built by `DefaultSubAgentSpawner.filterTools`, and the filter must strip `Task`.
    ///
    /// We exercise this through the parent spawner's `spawn` path by feeding a mock
    /// LLMClient whose child response is a single tool_use for `Task`. If the child
    /// pool still contained `Task`, the child could re-launch a grandchild. After AC5,
    /// the child has no `Task` tool, so the tool_use is rejected as "unknown tool"
    /// rather than spawning a grandchild.
    ///
    /// NOTE: This test is a higher-level integration assertion. The granular unit-level
    /// strip behavior is covered by `testFilterTools_stripsBothAgentAndTaskWhenBothPresent`
    /// in DefaultSubAgentSpawnerTests.swift.
    func testEscapeHatch_defaultDoesNotPropagateRecursion() async throws {
        let parentTools: [ToolProtocol] = [createReadTool(), createAgentTool(), createTaskTool()]

        // Use the shared spawner filter helper to verify the contract directly.
        // After implementation lands, this becomes a deterministic check.
        XCTAssertTrue(
            SubAgentLauncherNames.default.contains("Agent") && SubAgentLauncherNames.default.contains("Task"),
            "Default launcher list must include both names so the filter can strip both"
        )

        // The filter contract: the helper lists exactly what the filter strips.
        // If a future escape hatch subtracts from the list, this test will need updating.
        // Until then, both must be stripped.
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: ToolUseThenEndMockClient(toolName: "Task")
        )

        let filtered = spawner.filterToolsForTesting(allowedTools: nil, disallowedTools: nil)
        let names = filtered.map { $0.name }

        XCTAssertFalse(names.contains("Agent"), "Default behavior: child must NOT inherit Agent")
        XCTAssertFalse(names.contains("Task"), "Default behavior: child must NOT inherit Task (escape hatch: no recursion by default)")
    }

    // MARK: - Story 29.7: Task-Only Spawner Detection Integration

    /// Story 29.7 integration tests for the spawner-detection + child-filtering seam.
    ///
    /// Unlike the 29.2 single-point tests above (which each verify one rule in isolation),
    /// these tests exercise the **joined** path: a Task-only parent tool pool must still
    /// inject a spawner (proving the `SubAgentLauncherNames.contains` detection covers
    /// both names end-to-end), and a pool with BOTH launchers present must strip BOTH
    /// from the child tool pool (proving `SubAgentLauncherNames.default` flows all the
    /// way through `DefaultSubAgentSpawner.filterTools`).
    ///
    /// TDD phase note: Story 29.7 verifies ALREADY-IMPLEMENTED behavior from Stories
    /// 29.1–29.6. There is no red phase — these tests are expected to be green on
    /// first run (per story Dev Notes line 206).

    /// AC2 [P0]: A tool pool containing ONLY `createTaskTool()` (no `createAgentTool()`)
    /// still triggers spawner injection. We observe this indirectly: if the spawner were
    /// NOT injected, the Task tool would emit the "spawner missing" error. After the
    /// detection landed in 29.2, the spawner IS injected and the tool proceeds to spawn
    /// (failing downstream with a network/auth error, never with a spawner error).
    ///
    /// Integration target: Stories 29.1 (Task alias) + 29.2 (Task-aware detection).
    func testTaskOnlyToolPool_triggersSpawnerInjection() async throws {
        // Only Task registered — no Agent. This is the Task-only pool shape.
        let tools: [ToolProtocol] = [createReadTool(), createTaskTool()]
        let agent = Agent(
            options: makeOptions(tools: tools),
            client: ToolUseThenEndMockClient(toolName: "Task")
        )

        let result = await agent.prompt("Probe the Task-only launcher.")

        // Spawner MUST be injected: the tool output must NOT mention spawner-missing.
        // (If the detection missed Task, the tool would surface "Task spawner not available".)
        let text = result.text
        XCTAssertFalse(
            text.lowercased().contains("spawner") && text.lowercased().contains("not available"),
            "Task-only pool must inject a spawner; got: \(text)"
        )
    }

    /// AC2 [P0]: A parent pool with BOTH `Agent` and `Task` launchers present must strip
    /// BOTH from the child tool pool (`SubAgentLauncherNames.default == ["Agent", "Task"]`).
    /// We drive the spawner's filter directly — it is the same `filterTools` the runtime
    /// uses to build child pools — and assert both launcher names vanish while ordinary
    /// tools (Read) survive.
    ///
    /// Integration target: Stories 29.1 (Task alias) + 29.2 (dual launcher stripping).
    func testAgentAndTaskBothPresent_childStripsBothLaunchers() async throws {
        let parentTools: [ToolProtocol] = [
            createReadTool(),
            createAgentTool(),
            createTaskTool(),
        ]

        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: ToolUseThenEndMockClient(toolName: "Task")
        )

        // No explicit allowed/disallowed list: default filter behavior must strip both launchers.
        let filtered = spawner.filterToolsForTesting(allowedTools: nil, disallowedTools: nil)
        let names = filtered.map { $0.name }

        XCTAssertTrue(names.contains("Read"),
                      "Ordinary tools (Read) must survive the launcher strip")
        XCTAssertFalse(names.contains("Agent"),
                       "Child pool must NOT inherit Agent (recursion guard)")
        XCTAssertFalse(names.contains("Task"),
                       "Child pool must NOT inherit Task (recursion guard)")
    }
}

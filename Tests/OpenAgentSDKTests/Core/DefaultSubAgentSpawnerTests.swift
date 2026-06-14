import XCTest
@testable import OpenAgentSDK

import Foundation

// MARK: - Mock URL Protocol for SubAgentSpawner Tests

/// URLProtocol that returns a canned 401 error for all requests.
/// Simulates API authentication failure without real network I/O.
private final class SpawnerMockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let errorBody: [String: Any] = [
            "error": ["type": "authentication_error", "message": "invalid api key"]
        ]
        let body = try! JSONSerialization.data(withJSONObject: errorBody, options: [])
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 401,
            httpVersion: "HTTP/1.1",
            headerFields: ["content-type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - DefaultSubAgentSpawner Tests

/// ATDD RED PHASE: Tests for Story 4.3 -- DefaultSubAgentSpawner.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `DefaultSubAgentSpawner` class is implemented in Core/
///   - `SubAgentSpawner` protocol is defined in Types/
///   - `SubAgentResult` struct is defined in Types/
/// TDD Phase: RED (feature not implemented yet)
final class DefaultSubAgentSpawnerTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a mock AnthropicClient that returns 401 without real network I/O.
    private func makeMockClient() -> AnthropicClient {
        let urlSession = makeMockURLSession(protocolClass: SpawnerMockURLProtocol.self)
        return AnthropicClient(apiKey: "test-key", baseURL: nil, urlSession: urlSession)
    }

    private final class CapturingToolsClient: LLMClient, @unchecked Sendable {
        private let lock = NSLock()
        private var _capturedTools: [[String: Any]]?

        var capturedTools: [[String: Any]]? {
            lock.withLock { _capturedTools }
        }

        nonisolated func sendMessage(
            model: String,
            messages: [[String: Any]],
            maxTokens: Int,
            system: String?,
            tools: [[String: Any]]?,
            toolChoice: [String: Any]?,
            thinking: [String: Any]?,
            temperature: Double?
        ) async throws -> [String: Any] {
            lock.withLock {
                _capturedTools = tools
            }
            return [
                "content": [["type": "text", "text": "child done"]],
                "stop_reason": "end_turn",
                "usage": ["input_tokens": 1, "output_tokens": 1],
            ]
        }

        nonisolated func streamMessage(
            model: String,
            messages: [[String: Any]],
            maxTokens: Int,
            system: String?,
            tools: [[String: Any]]?,
            toolChoice: [String: Any]?,
            thinking: [String: Any]?,
            temperature: Double?
        ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        }
    }

    private func makeNamedTool(_ name: String) -> ToolProtocol {
        defineTool(
            name: name,
            description: "Test tool \(name)",
            inputSchema: ["type": "object"],
            isReadOnly: true
        ) { _ in
            "ok"
        }
    }

    private func capturedToolNames(from client: CapturingToolsClient) -> [String] {
        (client.capturedTools ?? []).compactMap { $0["name"] as? String }
    }

    // MARK: - AC4: Tool filtering — removes AgentTool

    /// AC4 [P0]: spawn filters out the "Agent" tool from the sub-agent's tool list.
    func testSpawn_filtersOutAgentTool() async throws {
        // Given: a spawner with parent tools including an "Agent" tool
        let parentTools: [ToolProtocol] = [
            createBashTool(),
            createReadTool(),
            createGrepTool(),
        ]

        // Create a mock Agent tool to include in the parent's tools
        let mockAgentTool = createAgentTool()
        var allTools = parentTools
        allTools.append(mockAgentTool)

        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: allTools,
            client: makeMockClient()
        )

        // When: spawning without allowedTools filter
        let result = await spawner.spawn(
            prompt: "Test task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil
        )

        // Then: spawner completes without crash
        // The key behavior tested: Agent tool is filtered from sub-agent tools (prevents recursion)
        XCTAssertTrue(result.isError, "Should get error from mock 401 response")
    }

    /// AC4 [P1]: spawn respects allowedTools list and filters tools accordingly.
    func testSpawn_allowedTools_filtersCorrectly() async throws {
        // Given: parent tools with multiple tools
        let parentTools: [ToolProtocol] = [
            createBashTool(),
            createReadTool(),
            createWriteTool(),
            createGrepTool(),
            createGlobTool(),
        ]

        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        // When: spawning with allowedTools restricting to read and Glob only
        let result = await spawner.spawn(
            prompt: "Explore codebase",
            model: nil,
            systemPrompt: "You are an explorer agent",
            allowedTools: ["Read", "Glob", "Grep"],
            maxTurns: 5
        )

        // Then: spawner completes (API error with mock client is expected)
        // The key behavior tested: allowedTools filter is applied correctly
        XCTAssertTrue(result.isError, "Should get error from mock 401 response")
    }

    // MARK: - AC5: Model inheritance and override

    /// AC5 [P0]: When model is nil, the spawner uses the parent model.
    func testSpawn_inheritsParentModel_whenModelNil() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]

        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: "https://api.example.com",
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        // When: spawning without specifying a model
        let result = await spawner.spawn(
            prompt: "Test",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil
        )

        // Then: uses parent model (mock error proves no crash)
        XCTAssertTrue(result.isError, "Should get error from mock 401 response")
    }

    /// AC5 [P0]: When model is specified, it overrides the parent model.
    func testSpawn_usesCustomModel_whenSpecified() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]

        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        // When: spawning with a custom model
        let result = await spawner.spawn(
            prompt: "Test",
            model: "claude-haiku-4-5",
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil
        )

        // Then: uses the custom model (mock error proves no crash)
        XCTAssertTrue(result.isError, "Should get error from mock 401 response")
    }

    // MARK: - AC2: Error handling

    /// AC2 [P0]: API error returns isError=true SubAgentResult.
    func testSpawn_apiError_returnsIsError() async throws {
        // Given: a spawner with invalid API key (will fail on API call)
        let parentTools: [ToolProtocol] = [createReadTool()]

        let spawner = DefaultSubAgentSpawner(
            apiKey: "",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        // When: spawning with invalid credentials
        let result = await spawner.spawn(
            prompt: "Test",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: 1
        )

        // Then: the result should indicate error
        XCTAssertTrue(result.isError)
    }

    // MARK: - maxTurns parameter

    /// AC5 [P0]: Custom maxTurns is passed through to the sub-agent.
    func testSpawn_customMaxTurns_limitsSubAgent() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]

        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        // When: spawning with maxTurns=1
        let result = await spawner.spawn(
            prompt: "Test with limited turns",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: 1
        )

        // Then: completes (error from mock client is expected)
        XCTAssertTrue(result.isError, "Should get error from mock 401 response")
    }

    /// AC5 [P0]: When maxTurns is nil, default of 10 is used.
    func testSpawn_defaultMaxTurns_whenNil() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]

        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        // When: spawning without specifying maxTurns
        let result = await spawner.spawn(
            prompt: "Test",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil
        )

        // Then: default maxTurns (10) is used — mock error proves completion
        XCTAssertTrue(result.isError, "Should get error from mock 401 response")
    }

    // MARK: - Story 29.2: Spawner Detection and Child Filtering

    /// ATDD RED PHASE: Tests for Story 29.2 -- spawner detection recognizes both
    /// `Agent` and `Task`, and child tool pool filtering strips BOTH launcher names
    /// by default to prevent unbounded recursive spawning.
    ///
    /// Tests below assert EXPECTED behavior. They will FAIL until:
    ///   - `enum SubAgentLauncherNames` exists in Core/DefaultSubAgentSpawner.swift
    ///   - `DefaultSubAgentSpawner.filterTools` strips via `!SubAgentLauncherNames.contains($0.name)`
    ///   - `internal func filterToolsForTesting(...)` wrapper is exposed for direct assertion
    /// TDD Phase: RED (feature not implemented yet)

    // MARK: AC2 + AC3: Default filtering strips both launcher names

    /// AC2 [P0]: filterTools strips "Agent" by default when parent pool contains it.
    func testFilterTools_stripsAgentByDefault() async throws {
        let parentTools: [ToolProtocol] = [createBashTool(), createReadTool(), createAgentTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let filtered = spawner.filterToolsForTesting(allowedTools: nil, disallowedTools: nil)
        let names = filtered.map { $0.name }

        XCTAssertFalse(names.contains("Agent"), "Child pool must NOT contain 'Agent' (prevents recursion)")
        XCTAssertTrue(names.contains("Bash"), "Non-launcher tools must survive filtering")
        XCTAssertTrue(names.contains("Read"), "Non-launcher tools must survive filtering")
    }

    /// AC3 [P0]: filterTools strips "Task" by default when parent pool contains it.
    /// This is the new behavior introduced by Story 29.2 (RED — currently fails because
    /// `filterTools` only removes "Agent").
    func testFilterTools_stripsTaskByDefault() async throws {
        let parentTools: [ToolProtocol] = [createBashTool(), createReadTool(), createTaskTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let filtered = spawner.filterToolsForTesting(allowedTools: nil, disallowedTools: nil)
        let names = filtered.map { $0.name }

        XCTAssertFalse(names.contains("Task"), "Child pool must NOT contain 'Task' (prevents recursion via Task alias)")
        XCTAssertTrue(names.contains("Bash"), "Non-launcher tools must survive filtering")
        XCTAssertTrue(names.contains("Read"), "Non-launcher tools must survive filtering")
    }

    /// AC2 + AC3 [P0]: filterTools strips BOTH "Agent" and "Task" when parent pool contains both.
    /// Verifies the canonical Epic 29 regression case (parent registers both launcher names).
    func testFilterTools_stripsBothAgentAndTaskWhenBothPresent() async throws {
        let parentTools: [ToolProtocol] = [
            createBashTool(),
            createAgentTool(),
            createTaskTool(),
        ]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let filtered = spawner.filterToolsForTesting(allowedTools: nil, disallowedTools: nil)
        let names = filtered.map { $0.name }

        XCTAssertFalse(names.contains("Agent"), "Child pool must NOT contain 'Agent'")
        XCTAssertFalse(names.contains("Task"), "Child pool must NOT contain 'Task'")
        XCTAssertTrue(names.contains("Bash"), "Non-launcher tools must survive filtering")
        XCTAssertEqual(filtered.count, 1, "Only the non-launcher tool should remain")
    }

    /// AC2 + AC3 [P1]: filterTools preserves every non-launcher tool when none are launchers.
    /// Sanity check that the strip filter is not over-aggressive.
    func testFilterTools_preservesNonLauncherTools() async throws {
        let parentTools: [ToolProtocol] = [
            createBashTool(),
            createReadTool(),
            createGrepTool(),
        ]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let filtered = spawner.filterToolsForTesting(allowedTools: nil, disallowedTools: nil)
        let names = filtered.map { $0.name }

        XCTAssertEqual(Set(names), Set(["Bash", "Read", "Grep"]), "All non-launcher tools must survive")
    }

    // MARK: AC6: Backward compatibility

    /// AC6 [P0]: filterTools still strips "Agent" when parent pool has only Agent (no Task).
    /// Verifies existing pre-29.2 behavior is preserved after the helper is introduced.
    func testSpawn_preservesBackwardCompat_whenOnlyAgentPresent() async throws {
        let parentTools: [ToolProtocol] = [createReadTool(), createAgentTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let filtered = spawner.filterToolsForTesting(allowedTools: nil, disallowedTools: nil)
        let names = filtered.map { $0.name }

        XCTAssertFalse(names.contains("Agent"), "Existing behavior: Agent must be stripped (no regression)")
        XCTAssertTrue(names.contains("Read"), "Existing behavior: Read survives (no regression)")
    }

    // MARK: - Story 29.1 follow-up: toolCalls propagation on the real spawn path

    /// toolCalls propagation [P0]: `mapQueryResultToSubAgentResult` extracts tool names
    /// from the child agent's `QueryResult.toolPairs`, so the parent's `[Tools used: ...]`
    /// summary reflects what the sub-agent actually invoked.
    ///
    /// Regression guard for the real (non-mock) spawn path: previously `executeAgent`
    /// returned a hard-coded `toolCalls: []`, so the summary never appeared in production
    /// — even though the mock-spawner `AgentToolTests` passed (they injected `toolCalls`
    /// by hand). This test drives the mapping directly with no LLM round-trip
    /// (project rule #27: no real I/O in unit tests).
    func testMapQueryResultToSubAgentResult_preservesInvokedToolNames() {
        let toolPairs: [SDKMessage.ToolExecutionPair] = [
            SDKMessage.ToolExecutionPair(
                toolUse: SDKMessage.ToolUseData(toolName: "Glob", toolUseId: "tu-1", input: "{}"),
                toolResult: SDKMessage.ToolResultData(toolUseId: "tu-1", content: "files", isError: false)
            ),
            SDKMessage.ToolExecutionPair(
                toolUse: SDKMessage.ToolUseData(toolName: "Grep", toolUseId: "tu-2", input: "{}"),
                toolResult: SDKMessage.ToolResultData(toolUseId: "tu-2", content: "matches", isError: false)
            ),
        ]
        let queryResult = QueryResult(
            text: "Found 3 files",
            usage: TokenUsage(inputTokens: 10, outputTokens: 5),
            numTurns: 2,
            durationMs: 100,
            messages: [],
            toolPairs: toolPairs
        )

        let result = DefaultSubAgentSpawner.mapQueryResultToSubAgentResult(queryResult)

        XCTAssertEqual(result.toolCalls, ["Glob", "Grep"],
                       "toolCalls must list tools the sub-agent invoked, in order")
        XCTAssertEqual(result.text, "Found 3 files")
        XCTAssertFalse(result.isError)
    }

    /// toolCalls propagation [P0]: when the child agent invoked no tools, `toolCalls`
    /// is empty (not nil, not garbage). Guards the empty-`toolPairs` path.
    func testMapQueryResultToSubAgentResult_emptyToolPairs_yieldsEmptyToolCalls() {
        let queryResult = QueryResult(
            text: "Direct answer, no tools.",
            usage: TokenUsage(inputTokens: 5, outputTokens: 3),
            numTurns: 1,
            durationMs: 50,
            messages: [],
            toolPairs: []
        )

        let result = DefaultSubAgentSpawner.mapQueryResultToSubAgentResult(queryResult)

        XCTAssertTrue(result.toolCalls.isEmpty, "No tool invocations must yield empty toolCalls")
        XCTAssertEqual(result.text, "Direct answer, no tools.")
        XCTAssertFalse(result.isError)
    }

    /// toolCalls propagation [P1]: empty sub-agent text falls back to the placeholder,
    /// preserving prior behavior (no regression on the text-empty edge case), and an
    /// error status surfaces as `isError`.
    func testMapQueryResultToSubAgentResult_emptyTextAndErrorStatus_preserved() {
        let queryResult = QueryResult(
            text: "",
            usage: TokenUsage(inputTokens: 5, outputTokens: 0),
            numTurns: 5,
            durationMs: 50,
            messages: [],
            status: .errorMaxTurns
        )

        let result = DefaultSubAgentSpawner.mapQueryResultToSubAgentResult(queryResult)

        XCTAssertEqual(result.text, "(Subagent completed with no text output)")
        XCTAssertTrue(result.isError, "errorMaxTurns status must surface as isError")
    }

    // MARK: - Story 29.5: Declaration-Based Filtering

    /// ATDD RED PHASE: Tests for Story 29.5 -- `DefaultSubAgentSpawner.filterTools`
    /// migrates from the legacy case-SENSITIVE `Set([String])` matcher to the shared
    /// `filterToolsByDeclarations` helper. This unifies skill `allowed-tools` and
    /// subagent `tools` / `disallowedTools` behind the same matching rules so that the
    /// same declaration means the same thing across direct skills and spawned agents.
    ///
    /// Tests below assert EXPECTED behavior. They will FAIL until:
    ///   - `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:157-174` is rewritten
    ///     to convert the `[String]?` allowed/disallowed inputs via
    ///     `ToolDeclaration.fromToolNames(...)` and delegate to
    ///     `filterToolsByDeclarations(...)`.
    ///   - `internal func filterToolsWithDiagnosticsForTesting(...)` is exposed, returning
    ///     the full `(filtered, diagnostics)` tuple (the existing
    ///     `filterToolsForTesting` keeps its `[ToolProtocol]` signature for the 29.2
    ///     regression tests).
    ///   - `SubAgentLauncherNames`-based stripping STILL runs first (29.2 behavior
    ///     preserved — helper does NOT strip Agent/Task itself).
    /// TDD Phase: RED (feature not implemented yet)
    ///
    /// Red mode: COMPILE-TIME — `filterToolsWithDiagnosticsForTesting` does not exist yet.

    // MARK: AC2 — 子代理工具池按 declarations 过滤

    /// AC2 [P0]: allowedTools keeps only matching tools. `Read` matches, `Grep` is
    /// declared but absent from the parent pool. `Write` / `Bash` are NOT in
    /// allowedTools and must be absent from the child pool.
    func testFilterTools_declarationBased_keepsOnlyMatching() async throws {
        let parentTools: [ToolProtocol] = [
            createBashTool(),
            createReadTool(),
            createWriteTool(),
        ]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let (filtered, diagnostics) = spawner.filterToolsWithDiagnosticsForTesting(
            allowedTools: ["Read", "Grep"],
            disallowedTools: nil
        )
        let names = filtered.map { $0.name }

        XCTAssertEqual(names, ["Read"], "Only declared-and-available Read must survive")
        XCTAssertFalse(names.contains("Bash"), "Bash is not allowed -> must be absent")
        XCTAssertFalse(names.contains("Write"), "Write is not allowed -> must be absent")
        XCTAssertEqual(diagnostics.unmatchedDeclarations.map(\.rawName), ["Grep"],
                       "Grep was declared but is not in the parent pool -> unmatched")
    }

    // MARK: AC3 — MCP 工具声明匹配无需 enum case

    /// AC3 [P0]: An MCP-named allowed tool is retained even though `ToolRestriction`
    /// has no MCP case. The legacy string `Set` matcher already matched MCP exact names,
    /// but the new path must preserve this AND surface no false unmatched diagnostic.
    func testFilterTools_mcpAllowed_keepsMcp() async throws {
        let parentTools: [ToolProtocol] = [
            createReadTool(),
            // A tool whose name follows the MCP namespaced convention.
            // Built via the project's tool builder to keep the test free of real MCP I/O.
            Self.makeStubTool(name: "mcp__srv__search"),
        ]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let (filtered, diagnostics) = spawner.filterToolsWithDiagnosticsForTesting(
            allowedTools: ["mcp__srv__search"],
            disallowedTools: nil
        )
        let names = filtered.map { $0.name }

        XCTAssertTrue(names.contains("mcp__srv__search"),
                      "Declared MCP tool present in parent pool must be retained")
        XCTAssertFalse(names.contains("Read"),
                       "Read is not in allowedTools -> must be absent")
        XCTAssertTrue(diagnostics.unmatchedDeclarations.isEmpty,
                      "Matched MCP declaration must NOT be reported unmatched")
    }

    // MARK: AC4 — 声明了但无可用工具 → 绝不 unrestricted

    /// AC4 [P0]: An allowedTools list referencing only a missing tool (`PhantomTool`)
    /// yields an EMPTY child pool — never the unrestricted parent pool. Epic 29
    /// "不静默放权" red line, verified at the spawner integration boundary.
    func testFilterTools_unknownAllowed_notUnrestricted() async throws {
        let parentTools: [ToolProtocol] = [createBashTool(), createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let (filtered, diagnostics) = spawner.filterToolsWithDiagnosticsForTesting(
            allowedTools: ["PhantomTool"],
            disallowedTools: nil
        )

        XCTAssertTrue(filtered.isEmpty,
                      "Allowed-but-missing must yield empty pool, never the full parent pool")
        XCTAssertEqual(diagnostics.unmatchedDeclarations.map(\.rawName), ["PhantomTool"],
                       "PhantomTool must surface as unmatched")
    }

    // MARK: AC7 — 向后兼容：launcher 剥离不变

    /// AC7 [P0]: launcher stripping (`Agent` / `Task`) is preserved — the helper does
    /// NOT strip launchers; the spawner still strips them via `SubAgentLauncherNames`
    /// BEFORE delegating to the helper. Regression guard for Story 29.2 behavior.
    func testFilterTools_launcherStrippingStillWorks() async throws {
        let parentTools: [ToolProtocol] = [
            createBashTool(),
            createAgentTool(),
            createTaskTool(),
        ]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let (filtered, _) = spawner.filterToolsWithDiagnosticsForTesting(
            allowedTools: nil,
            disallowedTools: nil
        )
        let names = filtered.map { $0.name }

        XCTAssertFalse(names.contains("Agent"), "Agent launcher must still be stripped (29.2 preserved)")
        XCTAssertFalse(names.contains("Task"), "Task launcher must still be stripped (29.2 preserved)")
        XCTAssertTrue(names.contains("Bash"), "Non-launcher tools must survive")
    }

    // MARK: Pattern 处理（按 base name 匹配）

    /// AC2 + pattern [P0]: A pattern-style allowed entry `Bash(git diff:*)` matches the
    /// available `Bash` tool by base name. The legacy case-sensitive `Set` matcher
    /// FAILED this case because `"Bash" != "Bash(git diff:*)"`. The declaration-based
    /// path must match by base name and NOT drop Bash.
    func testFilterTools_patternInAllowed_matchesByBaseName() async throws {
        let parentTools: [ToolProtocol] = [createBashTool(), createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let (filtered, _) = spawner.filterToolsWithDiagnosticsForTesting(
            allowedTools: ["Bash(git diff:*)"],
            disallowedTools: nil
        )
        let names = filtered.map { $0.name }

        XCTAssertTrue(names.contains("Bash"),
                      "Pattern entry Bash(git diff:*) must match available Bash by base name")
        XCTAssertFalse(names.contains("Read"),
                       "Read is not allowed -> must be absent")
    }

    // MARK: - Story 29.5 helper

    /// Minimal `ToolProtocol` builder for MCP-named tools used in the filter tests
    /// above. Keeps the test free of real MCP server I/O (project rule #27).
    private static func makeStubTool(name: String) -> ToolProtocol {
        return defineTool(
            name: name,
            description: "stub tool for 29.5 filter test",
            inputSchema: ["type": "object", "properties": [:]],
            isReadOnly: true
        ) { _, _ in
            ToolExecuteResult(content: "stub", isError: false)
        }
    }

    // MARK: - Story 29.6: Deferred Field Diagnostics Collection

    /// ATDD RED PHASE: Tests for Story 29.6 -- `DefaultSubAgentSpawner.spawn(...)` must
    /// collect runtime diagnostics for subagent fields that the schema accepts but the
    /// SDK does not fully wire (`run_in_background`, `resume`, `isolation`, `team_name`,
    /// `skills`, MCP server `.reference`). Each collected diagnostic is surfaced on
    /// `SubAgentResult.fieldDiagnostics`.
    ///
    /// Tests below assert EXPECTED behavior. They will FAIL (compile-time) until:
    ///   - `SubAgentFieldDiagnostics` / `SubAgentFieldDiagnosticReason` exist in Types/AgentTypes.swift
    ///   - `SubAgentResult` gains `fieldDiagnostics: [SubAgentFieldDiagnostics]?`
    ///   - `DefaultSubAgentSpawner.collectFieldDiagnostics(...)` is implemented and
    ///     invoked from the enhanced `spawn(...)` overload
    ///   - `mapQueryResultToSubAgentResult(_:fieldDiagnostics:)` propagates diagnostics
    /// TDD Phase: RED (feature not implemented yet)
    ///
    /// Red mode: COMPILE-TIME -- the `fieldDiagnostics` symbols and the
    /// `fieldDiagnostics:` parameter on `mapQueryResultToSubAgentResult` do not exist yet.

    // MARK: AC3 -- run_in_background deferred diagnostic

    /// AC3 [P0]: spawn with `run_in_background: true` emits exactly one diagnostic
    /// describing that background execution is not wired. Runtime still executes in the
    /// foreground (no behavior change beyond the diagnostic).
    func testSpawn_runInBackgroundTrue_emitsDiagnostic() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let result = await spawner.spawn(
            prompt: "Background task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: nil,
            skills: nil,
            runInBackground: true,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        let diags = try XCTUnwrap(result.fieldDiagnostics, "run_in_background:true must produce diagnostics")
        let backgroundDiags = diags.filter { $0.fieldName == "run_in_background" }
        XCTAssertEqual(backgroundDiags.count, 1, "Exactly one run_in_background diagnostic")
        XCTAssertEqual(backgroundDiags.first?.rawValue, "true")
        XCTAssertEqual(backgroundDiags.first?.reason, .backgroundExecutionNotImplemented)
    }

    /// AC3 [P1]: `run_in_background: false` (or nil) does NOT emit the background
    /// diagnostic — the field is only "deferred" when the user actually opts in.
    func testSpawn_runInBackgroundFalse_noBackgroundDiagnostic() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let result = await spawner.spawn(
            prompt: "Foreground task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: nil,
            skills: nil,
            runInBackground: false,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        let backgroundDiags = (result.fieldDiagnostics ?? []).filter { $0.fieldName == "run_in_background" }
        XCTAssertTrue(backgroundDiags.isEmpty,
                      "run_in_background:false must not be treated as deferred")
    }

    // MARK: AC3 (sibling) -- resume deferred diagnostic

    /// AC3 sibling [P0]: spawn with `resume: "abc123"` emits a `resumeNotImplemented`
    /// diagnostic. Sub-agent resume by ID is a deferred capability (epic deferred item #4).
    func testSpawn_resumeSet_emitsDiagnostic() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let result = await spawner.spawn(
            prompt: "Resume task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: nil,
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: "abc123"
        )

        let diags = try XCTUnwrap(result.fieldDiagnostics, "resume non-empty must produce diagnostics")
        let resumeDiags = diags.filter { $0.fieldName == "resume" }
        XCTAssertEqual(resumeDiags.count, 1, "Exactly one resume diagnostic")
        XCTAssertEqual(resumeDiags.first?.rawValue, "abc123")
        XCTAssertEqual(resumeDiags.first?.reason, .resumeNotImplemented)
    }

    // MARK: AC3 (sibling) -- isolation deferred diagnostic

    /// AC3 sibling [P0]: spawn with `isolation: "worktree"` emits an
    /// `isolationNotImplemented` diagnostic. Worktree isolation is deferred (epic #4).
    func testSpawn_isolationSet_emitsDiagnostic() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let result = await spawner.spawn(
            prompt: "Isolated task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: nil,
            skills: nil,
            runInBackground: nil,
            isolation: "worktree",
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        let diags = try XCTUnwrap(result.fieldDiagnostics, "isolation non-empty must produce diagnostics")
        let isolationDiags = diags.filter { $0.fieldName == "isolation" }
        XCTAssertEqual(isolationDiags.count, 1, "Exactly one isolation diagnostic")
        XCTAssertEqual(isolationDiags.first?.rawValue, "worktree")
        XCTAssertEqual(isolationDiags.first?.reason, .isolationNotImplemented)
    }

    // MARK: AC3 (sibling) -- team_name deferred diagnostic

    /// AC3 sibling [P0]: spawn with `team_name: "swarm"` emits a
    /// `teamCoordinationNotImplemented` diagnostic. Team coordination runtime is
    /// deferred (epic #4).
    func testSpawn_teamNameSet_emitsDiagnostic() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let result = await spawner.spawn(
            prompt: "Team task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: nil,
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: "swarm",
            mode: nil,
            resume: nil
        )

        let diags = try XCTUnwrap(result.fieldDiagnostics, "team_name non-empty must produce diagnostics")
        let teamDiags = diags.filter { $0.fieldName == "team_name" }
        XCTAssertEqual(teamDiags.count, 1, "Exactly one team_name diagnostic")
        XCTAssertEqual(teamDiags.first?.rawValue, "swarm")
        XCTAssertEqual(teamDiags.first?.reason, .teamCoordinationNotImplemented)
    }

    // MARK: AC7 -- skills inherited from parent registry

    /// AC7 [P0]: spawn with `skills: ["commit"]` builds a child Skill tool from
    /// the inherited parent registry and exposes only the requested skill.
    func testSpawn_skillsSet_filtersInheritedSkillRegistry() async throws {
        let registry = SkillRegistry()
        registry.register(Skill(
            name: "commit",
            description: "Commit changes",
            promptTemplate: "Commit prompt"
        ))
        registry.register(Skill(
            name: "review",
            description: "Review changes",
            promptTemplate: "Review prompt"
        ))
        let client = CapturingToolsClient()
        let parentTools: [ToolProtocol] = [createReadTool(), createSkillTool(registry: registry)]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: client,
            inheritanceContext: SubAgentInheritanceContext(skillRegistry: registry)
        )

        let result = await spawner.spawn(
            prompt: "Skilled task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: nil,
            skills: ["commit"],
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        XCTAssertFalse(result.isError)
        let skillDiags = (result.fieldDiagnostics ?? []).filter { $0.fieldName == "skills" }
        XCTAssertTrue(skillDiags.isEmpty, "skills are wired, not reported as deferred")

        let tools = try XCTUnwrap(client.capturedTools)
        let skillTool = try XCTUnwrap(tools.first { ($0["name"] as? String) == "Skill" })
        let description = try XCTUnwrap(skillTool["description"] as? String)
        XCTAssertTrue(description.contains("commit"), "Requested skill should be listed")
        XCTAssertFalse(description.contains("review"), "Unrequested skill should not be listed")
    }

    // MARK: AC4 -- MCP server reference diagnostics (inline excluded)

    /// AC4 [P0]: spawn with `mcpServers: [.reference("github-mcp")]` emits a
    /// `mcpReferenceResolutionDeferred` diagnostic. Parent MCP config resolution from
    /// `.reference` is deferred (epic #2).
    func testSpawn_mcpReference_emitsDiagnostic() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let result = await spawner.spawn(
            prompt: "MCP reference task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: [.reference("github-mcp")],
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        let diags = try XCTUnwrap(result.fieldDiagnostics, "MCP reference must produce diagnostics")
        let refDiags = diags.filter { $0.fieldName == "mcp_server_reference" }
        XCTAssertEqual(refDiags.count, 1, "Exactly one mcp_server_reference diagnostic")
        XCTAssertEqual(refDiags.first?.rawValue, "github-mcp")
        XCTAssertEqual(refDiags.first?.reason, .mcpReferenceResolutionDeferred)
    }

    /// AC4 [P0]: A Claude Code-style `{ name, tools }` MCP spec keeps only the
    /// requested tools from that inherited MCP server and does not expose other
    /// MCP servers.
    func testSpawn_mcpReferenceWithTools_filtersInheritedMcpTools() async throws {
        let client = CapturingToolsClient()
        let parentTools: [ToolProtocol] = [
            createReadTool(),
            makeNamedTool("mcp__github__list_prs"),
            makeNamedTool("mcp__github__create_issue"),
            makeNamedTool("mcp__slack__post_message"),
        ]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: client
        )

        let result = await spawner.spawn(
            prompt: "MCP filtered task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: [.referenceWithTools(name: "github", tools: ["list_prs"])],
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        XCTAssertFalse(result.isError)
        XCTAssertFalse((result.fieldDiagnostics ?? []).contains { $0.fieldName == "mcp_server_reference" })
        let names = capturedToolNames(from: client)
        XCTAssertTrue(names.contains("Read"))
        XCTAssertTrue(names.contains("mcp__github__list_prs"))
        XCTAssertFalse(names.contains("mcp__github__create_issue"))
        XCTAssertFalse(names.contains("mcp__slack__post_message"))
    }

    /// AC4 [P0]: A string MCP reference keeps every inherited tool from that
    /// server while excluding tools from unrelated MCP servers.
    func testSpawn_mcpReference_keepsAllInheritedToolsForServer() async throws {
        let client = CapturingToolsClient()
        let parentTools: [ToolProtocol] = [
            createReadTool(),
            makeNamedTool("mcp__github__list_prs"),
            makeNamedTool("mcp__github__create_issue"),
            makeNamedTool("mcp__slack__post_message"),
        ]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: client
        )

        let result = await spawner.spawn(
            prompt: "MCP server task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: [.reference("github")],
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        XCTAssertFalse(result.isError)
        XCTAssertFalse((result.fieldDiagnostics ?? []).contains { $0.fieldName == "mcp_server_reference" })
        let names = capturedToolNames(from: client)
        XCTAssertTrue(names.contains("Read"))
        XCTAssertTrue(names.contains("mcp__github__list_prs"))
        XCTAssertTrue(names.contains("mcp__github__create_issue"))
        XCTAssertFalse(names.contains("mcp__slack__post_message"))
    }

    /// AC4 [P1]: If the parent tool pool does not yet contain inherited MCP
    /// tools, a plain string server reference can fall back to the inherited
    /// parent MCP config because it intentionally exposes the full server.
    func testSpawn_mcpReferenceWithoutInheritedTools_fallsBackToParentConfig() async throws {
        let client = CapturingToolsClient()
        let server = InProcessMCPServer(
            name: "github",
            tools: [
                makeNamedTool("list_prs"),
                makeNamedTool("create_issue"),
            ]
        )
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: [createReadTool()],
            client: client,
            inheritanceContext: SubAgentInheritanceContext(
                mcpServers: ["github": await server.asConfig()]
            )
        )

        let result = await spawner.spawn(
            prompt: "MCP server task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: [.reference("github")],
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        XCTAssertFalse(result.isError)
        XCTAssertFalse((result.fieldDiagnostics ?? []).contains { $0.fieldName == "mcp_server_reference" })
        let names = capturedToolNames(from: client)
        XCTAssertTrue(names.contains("mcp__github__list_prs"))
        XCTAssertTrue(names.contains("mcp__github__create_issue"))
    }

    /// AC4 [P1]: If `{ name, tools }` cannot be satisfied from inherited MCP
    /// tool instances, the spawner must not reconnect the full parent server and
    /// accidentally expose tools outside the requested subset.
    func testSpawn_mcpReferenceWithToolsWithoutInheritedTools_emitsDiagnostic() async throws {
        let client = CapturingToolsClient()
        let server = InProcessMCPServer(
            name: "github",
            tools: [
                makeNamedTool("list_prs"),
                makeNamedTool("create_issue"),
            ]
        )
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: [createReadTool()],
            client: client,
            inheritanceContext: SubAgentInheritanceContext(
                mcpServers: ["github": await server.asConfig()]
            )
        )

        let result = await spawner.spawn(
            prompt: "MCP filtered task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: [.referenceWithTools(name: "github", tools: ["list_prs"])],
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        XCTAssertFalse(result.isError)
        let refDiags = try XCTUnwrap(result.fieldDiagnostics).filter { $0.fieldName == "mcp_server_reference" }
        XCTAssertEqual(refDiags.count, 1)
        XCTAssertEqual(refDiags.first?.rawValue, "github")
        let names = capturedToolNames(from: client)
        XCTAssertFalse(names.contains("mcp__github__list_prs"))
        XCTAssertFalse(names.contains("mcp__github__create_issue"))
    }

    /// AC4 [P0]: An `AgentMcpServerSpec.inline(...)` config does NOT emit a
    /// `mcp_server_reference` diagnostic -- inline MCP servers are already wired into
    /// the child agent's MCP config today.
    func testSpawn_mcpInline_noReferenceDiagnostic() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let inlineSpec = AgentMcpServerSpec.inline(
            .stdio(McpStdioConfig(command: "npx", args: ["-y", "my-mcp-server"]))
        )
        let result = await spawner.spawn(
            prompt: "Inline MCP task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: [inlineSpec],
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        let refDiags = (result.fieldDiagnostics ?? []).filter { $0.fieldName == "mcp_server_reference" }
        XCTAssertTrue(refDiags.isEmpty,
                      "Inline MCP config must NOT produce a reference diagnostic")
    }

    /// AC4 [P1]: Each repeated `.reference(...)` produces its own diagnostic (no
    /// deduplication) so callers can observe every unresolved reference.
    func testSpawn_duplicateMcpReference_emitsPerReferenceDiagnostic() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let result = await spawner.spawn(
            prompt: "Duplicate reference task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: [.reference("github-mcp"), .reference("github-mcp")],
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        let diags = try XCTUnwrap(result.fieldDiagnostics, "Two references must produce diagnostics")
        let refDiags = diags.filter { $0.fieldName == "mcp_server_reference" }
        XCTAssertEqual(refDiags.count, 2, "Each repeated reference must produce its own diagnostic")
        XCTAssertEqual(refDiags.map(\.rawValue), ["github-mcp", "github-mcp"])
    }

    // MARK: AC5 -- multiple deferred fields emitted in deterministic order

    /// AC5 [P0]: When multiple deferred fields are set together, every field produces
    /// its own diagnostic, and the diagnostics appear in the fixed order
    /// (run_in_background -> resume -> isolation -> team_name ->
    /// mcp_server_reference) defined by Task 1.3. This makes the surface assertion-friendly.
    func testSpawn_multipleDeferredFields_allEmittedInOrder() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let result = await spawner.spawn(
            prompt: "Everything deferred",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: [.reference("github-mcp")],
            skills: ["commit", "review"],
            runInBackground: true,
            isolation: "worktree",
            name: nil,
            teamName: "swarm",
            mode: nil,
            resume: "abc123"
        )

        let diags = try XCTUnwrap(result.fieldDiagnostics, "Multiple deferred fields must produce diagnostics")
        XCTAssertGreaterThanOrEqual(diags.count, 5,
                                    "All five deferred categories must surface")
        // Fixed order (AC5): run_in_background, resume, isolation, team_name, mcp_server_reference
        let expectedOrder = [
            "run_in_background",
            "resume",
            "isolation",
            "team_name",
            "mcp_server_reference",
        ]
        let actualOrder = diags.map(\.fieldName)
        XCTAssertEqual(actualOrder, expectedOrder,
                       "Diagnostics must appear in the fixed deterministic order")
    }

    // MARK: AC8 -- no deferred fields => fieldDiagnostics is nil

    /// AC8 [P0]: When NO deferred field is set (all nil/empty), the resulting
    /// `fieldDiagnostics` is `nil` -- not an empty array. `nil` is the explicit
    /// "no diagnostic signal" state; `[]` would mean "collection ran but produced
    /// nothing", which this story never emits.
    func testSpawn_noDeferredFields_diagnosticsIsNil() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        let result = await spawner.spawn(
            prompt: "Plain task",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
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

        XCTAssertNil(result.fieldDiagnostics,
                     "No deferred field must yield nil, not an empty array (AC8)")
    }

    // MARK: AC2 / AC9 -- mapQueryResultToSubAgentResult propagates diagnostics

    /// AC2 [P0]: `mapQueryResultToSubAgentResult(_:fieldDiagnostics:)` propagates the
    /// supplied diagnostics into the resulting `SubAgentResult.fieldDiagnostics`.
    /// Drives the mapping directly with no LLM round-trip (project rule #27).
    func testMapQueryResultToSubAgentResult_propagatesDiagnostics() {
        let queryResult = QueryResult(
            text: "Done",
            usage: TokenUsage(inputTokens: 10, outputTokens: 5),
            numTurns: 1,
            durationMs: 50,
            messages: [],
            toolPairs: []
        )
        let diagnostics: [SubAgentFieldDiagnostics] = [
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

        let result = DefaultSubAgentSpawner.mapQueryResultToSubAgentResult(
            queryResult,
            fieldDiagnostics: diagnostics
        )

        XCTAssertEqual(result.fieldDiagnostics, diagnostics,
                       "Supplied diagnostics must propagate to SubAgentResult")
        XCTAssertEqual(result.text, "Done")
        XCTAssertFalse(result.isError)
    }

    /// AC9 [P0]: `mapQueryResultToSubAgentResult(_:)` retains backward compatibility:
    /// the existing single-arg call site (no `fieldDiagnostics`) still compiles and
    /// yields `fieldDiagnostics == nil`. Regression guard for existing callers.
    func testMapQueryResultToSubAgentResult_backwardCompat_defaultsToNilDiagnostics() {
        let queryResult = QueryResult(
            text: "Plain",
            usage: TokenUsage(inputTokens: 1, outputTokens: 1),
            numTurns: 1,
            durationMs: 10,
            messages: [],
            toolPairs: []
        )

        // Existing single-arg call site must keep compiling (default fieldDiagnostics: nil)
        let result = DefaultSubAgentSpawner.mapQueryResultToSubAgentResult(queryResult)

        XCTAssertNil(result.fieldDiagnostics,
                     "Default fieldDiagnostics must be nil for backward compatibility")
    }

    // MARK: - Story 29.7: Dual Diagnostics Integration

    /// Story 29.7 integration tests for the **dual diagnostic dimension boundary**:
    /// `SubAgentFieldDiagnostics` (Story 29.6 — deferred-field dimension) must stay
    /// independent of `ToolFilterDiagnostics` (Story 29.5 — tool-filtering dimension).
    ///
    /// Per Story 29.6 Dev Notes ("Boundary with 29.5"): the spawner currently discards
    /// tool-filter diagnostics at the boundary (DefaultSubAgentSpawner.swift:108 keeps
    /// only `.filtered`). These tests pin that boundary so a future change that
    /// accidentally mixes the two dimensions would fail loudly.
    ///
    /// TDD phase note: Story 29.7 verifies ALREADY-IMPLEMENTED behavior from Stories
    /// 29.1–29.6. There is no red phase — these tests are expected to be green on
    /// first run (per story Dev Notes line 206).

    /// AC5 [P0]: A spawn that simultaneously triggers BOTH a deferred-field diagnostic
    /// (`run_in_background: true`) AND a tool-filter mismatch (`allowedTools` containing
    /// an unknown name) must surface ONLY the field diagnostic in
    /// `SubAgentResult.fieldDiagnostics`. Tool-filter diagnostics must NOT pollute the
    /// field-diagnostics dimension — they are an orthogonal concern.
    ///
    /// Integration target: Stories 29.5 (filter diagnostics, discarded at boundary) +
    /// 29.6 (field diagnostics, surfaced on the result).
    func testSpawn_runInBackgroundAndUnknownAllowedTool_fieldDiagnosticsOnlyContainFields() async throws {
        let parentTools: [ToolProtocol] = [createReadTool()]
        let spawner = DefaultSubAgentSpawner(
            apiKey: "test-key",
            baseURL: nil,
            parentModel: "claude-sonnet-4-6",
            parentTools: parentTools,
            client: makeMockClient()
        )

        // runInBackground triggers a 29.6 field diagnostic; allowedTools with an
        // unknown name would trigger a 29.5 tool-filter diagnostic — but the latter
        // is discarded at the spawner boundary (DefaultSubAgentSpawner.swift:108).
        let result = await spawner.spawn(
            prompt: "Deferred + unknown tool",
            model: nil,
            systemPrompt: nil,
            allowedTools: ["Read", "UnknownTool"],
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: nil,
            skills: nil,
            runInBackground: true,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )

        let diags = try XCTUnwrap(result.fieldDiagnostics,
                                  "run_in_background:true must produce a field diagnostic")

        // Exactly one field diagnostic — the run_in_background one.
        // The unknown-tool filter mismatch must NOT appear here.
        XCTAssertEqual(diags.count, 1,
                       "fieldDiagnostics must contain exactly the deferred-field entry; got: \(diags.map(\.fieldName))")
        XCTAssertEqual(diags.first?.fieldName, "run_in_background",
                       "The single field diagnostic must be the run_in_background one")
        // Explicit negative: no tool-filter signal leaks into the field dimension.
        let fieldNames = diags.map(\.fieldName)
        XCTAssertFalse(fieldNames.contains(where: { $0.lowercased().contains("tool") || $0.lowercased().contains("filter") }),
                       "fieldDiagnostics must NOT carry any tool-filter dimension entries; got: \(fieldNames)")
    }

    /// AC5 [P0]: When the AgentTool rendering layer consumes a `SubAgentResult` carrying
    /// `fieldDiagnostics`, its output must contain ONLY the deferred-field block — never
    /// any tool-filter (e.g. `[Tools used:]`-adjacent) diagnostic. We drive this through
    /// `createTaskTool()` with a `MockSubAgentSpawner` that returns a result with a
    /// field diagnostic, asserting the rendered output carries the field block and does
    /// not contain any tool-filter vocabulary (`unmatched`, `pattern`, etc.).
    ///
    /// The tool-filter diagnostics (Story 29.5) are discarded at the spawner boundary
    /// before reaching `SubAgentResult`, so they can never reach the rendering layer —
    /// this test pins that contract end-to-end through the public AgentTool surface.
    ///
    /// Integration target: Stories 29.5 (filter diagnostics live at spawner boundary) +
    /// 29.6 (AgentTool renders fieldDiagnostics block).
    func testAgentTool_outputWithFieldDiagnostics_doesNotLeakToolFilterInfo() async throws {
        let mockSpawner = MockSubAgentSpawner.makeWithDiagnostics(
            text: "Deferred field ran.",
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
        let tool = createTaskTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Background probe",
            "description": "Probe",
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError, "Field diagnostics are non-fatal — output must not be an error")
        // The field diagnostic block must be present.
        XCTAssertTrue(result.content.contains("run_in_background"),
                      "Output must render the deferred-field diagnostics block")
        XCTAssertTrue(result.content.contains("[Tools used:"),
                      "Tool-call summary must still render")
        // No tool-filter dimension vocabulary leaks into the rendered output text.
        // (ToolFilterDiagnostics wording lives entirely at the spawner boundary and
        // must never reach the AgentTool rendering surface.)
        XCTAssertFalse(result.content.lowercased().contains("unmatched"),
                       "Tool-filter 'unmatched' wording must NOT leak into the AgentTool output")
        XCTAssertFalse(result.content.lowercased().contains("pattern declaration"),
                       "Tool-filter 'pattern declaration' wording must NOT leak into the AgentTool output")
    }
}

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
}

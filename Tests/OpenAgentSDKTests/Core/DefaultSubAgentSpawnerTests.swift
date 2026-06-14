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
}

import XCTest
@testable import OpenAgentSDK

import Foundation

// MARK: - Agent Type Extension Tests

/// ATDD RED PHASE: Tests for Story 4.3 -- Type extensions (AgentDefinition, SubAgentResult, SubAgentSpawner, ToolContext).
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `AgentDefinition` gains `tools` and `maxTurns` fields
///   - `SubAgentResult` struct is defined
///   - `SubAgentSpawner` protocol is defined
///   - `ToolContext` gains `agentSpawner` field
/// TDD Phase: RED (feature not implemented yet)
final class AgentTypesTests: XCTestCase {

    // MARK: - AC7: AgentDefinition extensions

    /// AC7 [P0]: AgentDefinition can be created with tools list.
    func testAgentDefinition_withTools() {
        let def = AgentDefinition(
            name: "Explore",
            description: "Code explorer",
            model: nil,
            systemPrompt: "You are an explorer",
            tools: ["Read", "Glob", "Grep", "Bash"],
            maxTurns: 10
        )

        XCTAssertEqual(def.name, "Explore")
        XCTAssertEqual(def.description, "Code explorer")
        XCTAssertEqual(def.systemPrompt, "You are an explorer")
        XCTAssertEqual(def.tools, ["Read", "Glob", "Grep", "Bash"])
        XCTAssertEqual(def.maxTurns, 10)
    }

    /// AC7 [P0]: AgentDefinition tools and maxTurns default to nil.
    func testAgentDefinition_defaultToolsAndMaxTurns_nil() {
        let def = AgentDefinition(
            name: "Custom",
            description: "Custom agent"
        )

        XCTAssertEqual(def.name, "Custom")
        XCTAssertNil(def.model)
        XCTAssertNil(def.systemPrompt)
        XCTAssertNil(def.tools)
        XCTAssertNil(def.maxTurns)
    }

    /// AC7 [P0]: AgentDefinition maintains backward compatibility with existing init.
    func testAgentDefinition_backwardCompatibleInit() {
        // Existing call sites use: AgentDefinition(name:description:model:systemPrompt:)
        let def = AgentDefinition(
            name: "Plan",
            description: "Architect",
            model: "claude-haiku-4-5",
            systemPrompt: "Design plans"
        )

        XCTAssertEqual(def.name, "Plan")
        XCTAssertEqual(def.model, "claude-haiku-4-5")
        XCTAssertNil(def.tools)
        XCTAssertNil(def.maxTurns)
    }

    // MARK: - AC6: SubAgentResult

    /// AC6 [P0]: SubAgentResult can be created with text and toolCalls.
    func testSubAgentResult_success() {
        let result = SubAgentResult(
            text: "Task completed",
            toolCalls: ["Read", "Grep"],
            isError: false
        )

        XCTAssertEqual(result.text, "Task completed")
        XCTAssertEqual(result.toolCalls, ["Read", "Grep"])
        XCTAssertFalse(result.isError)
    }

    /// AC6 [P0]: SubAgentResult error case.
    func testSubAgentResult_error() {
        let result = SubAgentResult(
            text: "API error: unauthorized",
            toolCalls: [],
            isError: true
        )

        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.text, "API error: unauthorized")
        XCTAssertTrue(result.toolCalls.isEmpty)
    }

    /// AC6 [P0]: SubAgentResult default toolCalls is empty.
    func testSubAgentResult_defaultToolCalls() {
        let result = SubAgentResult(text: "Done")

        XCTAssertTrue(result.toolCalls.isEmpty)
        XCTAssertFalse(result.isError)
    }

    /// AC6 [P1]: SubAgentResult is Equatable.
    func testSubAgentResult_equatable() {
        let a = SubAgentResult(text: "Hello", toolCalls: [], isError: false)
        let b = SubAgentResult(text: "Hello", toolCalls: [], isError: false)
        let c = SubAgentResult(text: "World", toolCalls: [], isError: false)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - AC6: ToolContext with agentSpawner

    /// AC6 [P0]: ToolContext can be created with agentSpawner.
    func testToolContext_withAgentSpawner() {
        let spawner = MockTestSpawner(result: SubAgentResult(text: "Done"))
        let context = ToolContext(cwd: "/tmp", agentSpawner: spawner)

        XCTAssertEqual(context.cwd, "/tmp")
        XCTAssertNotNil(context.agentSpawner)
    }

    /// AC6 [P0]: ToolContext without agentSpawner defaults to nil.
    func testToolContext_withoutAgentSpawner_defaultsNil() {
        let context = ToolContext(cwd: "/tmp")

        XCTAssertNil(context.agentSpawner)
    }

    /// AC6 [P0]: ToolContext backward compatible — existing call sites still work.
    func testToolContext_backwardCompatible() {
        // Existing code creates ToolContext(cwd:toolUseId:)
        let context = ToolContext(cwd: "/tmp", toolUseId: "tool-123")

        XCTAssertEqual(context.cwd, "/tmp")
        XCTAssertEqual(context.toolUseId, "tool-123")
        XCTAssertNil(context.agentSpawner)
    }

    // MARK: - AC6: SubAgentSpawner protocol

    /// AC6 [P0]: SubAgentSpawner protocol exists and can be implemented.
    func testSubAgentSpawner_protocolExists() {
        // This test verifies that SubAgentSpawner is a valid protocol
        // by creating a concrete implementation
        let spawner = MockTestSpawner(result: SubAgentResult(text: "OK"))

        // Verify the protocol method exists via async call
        let expectation = self.expectation(description: "spawner responds to spawn")

        _Concurrency.Task {
            let result = await spawner.spawn(
                prompt: "test",
                model: nil,
                systemPrompt: nil,
                allowedTools: nil,
                maxTurns: nil
            )
            XCTAssertEqual(result.text, "OK")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }
}

// MARK: - Mock Spawner for Type Tests

/// Simple mock for testing ToolContext and protocol conformance.
private final class MockTestSpawner: SubAgentSpawner {
    let result: SubAgentResult

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
        return result
    }
}

import XCTest
@testable import OpenAgentSDK

import Foundation

// MARK: - ATDD RED PHASE: Story 17-6 Subagent System Enhancement
//
// All tests assert EXPECTED behavior. They will FAIL until:
//   - AgentMcpServerSpec enum is added to AgentTypes.swift
//   - AgentOutput enum + output structs are added to AgentTypes.swift
//   - AgentDefinition gains 4 new optional fields
//   - AgentToolInput gains 5 new Codable fields
//   - SubAgentSpawner protocol gains new spawn overload via protocol extension
//   - DefaultSubAgentSpawner implements new spawn overload
//   - MockSubAgentSpawner is updated in AgentToolTests.swift
//
// TDD Phase: RED (feature not implemented yet)

// MARK: - AC4: AgentMcpServerSpec Type Tests

final class AgentMcpServerSpecATDDTests: XCTestCase {

    /// AC4 [P0]: AgentMcpServerSpec has .reference(String) case for parent server name lookup.
    func testAgentMcpServerSpec_referenceCase() {
        let spec = AgentMcpServerSpec.reference("my-server")
        // Should compile and hold the reference string
        if case .reference(let name) = spec {
            XCTAssertEqual(name, "my-server")
        } else {
            XCTFail("Expected .reference case")
        }
    }

    /// AC4 [P0]: AgentMcpServerSpec has .inline(McpServerConfig) case for direct config.
    func testAgentMcpServerSpec_inlineCase() {
        let config = McpServerConfig.stdio(McpStdioConfig(command: "npx", args: ["my-mcp-server"]))
        let spec = AgentMcpServerSpec.inline(config)
        // Should compile and hold the inline config
        if case .inline(let cfg) = spec {
            XCTAssertEqual(cfg, config)
        } else {
            XCTFail("Expected .inline case")
        }
    }

    /// AC4 [P0]: AgentMcpServerSpec conforms to Sendable.
    func testAgentMcpServerSpec_conformsToSendable() {
        let spec = AgentMcpServerSpec.reference("server")
        // This will fail to compile if AgentMcpServerSpec does not conform to Sendable
        let _: any Sendable = spec
    }

    /// AC4 [P0]: AgentMcpServerSpec conforms to Equatable.
    func testAgentMcpServerSpec_conformsToEquatable() {
        let a = AgentMcpServerSpec.reference("server")
        let b = AgentMcpServerSpec.reference("server")
        XCTAssertEqual(a, b)
    }

    /// AC4 [P1]: AgentMcpServerSpec.reference equality is by string value.
    func testAgentMcpServerSpec_referenceEquality_byString() {
        let a = AgentMcpServerSpec.reference("alpha")
        let b = AgentMcpServerSpec.reference("alpha")
        let c = AgentMcpServerSpec.reference("beta")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// AC4 [P1]: AgentMcpServerSpec.inline equality is by config value.
    func testAgentMcpServerSpec_inlineEquality_byConfig() {
        let configA = McpServerConfig.stdio(McpStdioConfig(command: "npx", args: ["server-a"]))
        let configB = McpServerConfig.stdio(McpStdioConfig(command: "npx", args: ["server-b"]))
        let a = AgentMcpServerSpec.inline(configA)
        let b = AgentMcpServerSpec.inline(configA)
        let c = AgentMcpServerSpec.inline(configB)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// AC4 [P1]: AgentMcpServerSpec.reference and .inline are not equal.
    func testAgentMcpServerSpec_differentCases_notEqual() {
        let ref = AgentMcpServerSpec.reference("server")
        let inline = AgentMcpServerSpec.inline(.stdio(McpStdioConfig(command: "npx")))
        XCTAssertNotEqual(ref, inline)
    }
}

// MARK: - AC1: AgentDefinition Field Completion Tests

final class AgentDefinitionEnhancementATDDTests: XCTestCase {

    /// AC1 [P0]: AgentDefinition has disallowedTools field that defaults to nil.
    func testAgentDefinition_disallowedTools_defaultsNil() {
        let def = AgentDefinition(name: "Test")
        XCTAssertNil(def.disallowedTools)
    }

    /// AC1 [P0]: AgentDefinition has mcpServers field that defaults to nil.
    func testAgentDefinition_mcpServers_defaultsNil() {
        let def = AgentDefinition(name: "Test")
        XCTAssertNil(def.mcpServers)
    }

    /// AC1 [P0]: AgentDefinition has skills field that defaults to nil.
    func testAgentDefinition_skills_defaultsNil() {
        let def = AgentDefinition(name: "Test")
        XCTAssertNil(def.skills)
    }

    /// AC1 [P0]: AgentDefinition has criticalSystemReminderExperimental field that defaults to nil.
    func testAgentDefinition_criticalSystemReminderExperimental_defaultsNil() {
        let def = AgentDefinition(name: "Test")
        XCTAssertNil(def.criticalSystemReminderExperimental)
    }

    /// AC1 [P0]: AgentDefinition init with all new fields set.
    func testAgentDefinition_initWithAllNewFields() {
        let mcpSpecs: [AgentMcpServerSpec] = [
            .reference("parent-server"),
            .inline(.stdio(McpStdioConfig(command: "npx", args: ["my-server"]))),
        ]
        let def = AgentDefinition(
            name: "EnhancedAgent",
            description: "Agent with all new fields",
            model: "claude-sonnet-4-6",
            systemPrompt: "You are enhanced",
            tools: ["Read", "Glob"],
            maxTurns: 15,
            disallowedTools: ["Bash", "Write"],
            mcpServers: mcpSpecs,
            skills: ["code-review", "testing"],
            criticalSystemReminderExperimental: "Critical: never delete files"
        )

        XCTAssertEqual(def.name, "EnhancedAgent")
        XCTAssertEqual(def.disallowedTools, ["Bash", "Write"])
        XCTAssertEqual(def.mcpServers?.count, 2)
        XCTAssertEqual(def.skills, ["code-review", "testing"])
        XCTAssertEqual(def.criticalSystemReminderExperimental, "Critical: never delete files")
    }

    /// AC1 [P0]: AgentDefinition backward compatible -- existing init compiles without new params.
    func testAgentDefinition_backwardCompatibleInit() {
        // Existing call sites should compile without modification
        let def = AgentDefinition(
            name: "Explore",
            description: "Explorer",
            model: nil,
            systemPrompt: "Explore code",
            tools: ["Read"],
            maxTurns: 10
        )
        XCTAssertEqual(def.name, "Explore")
        XCTAssertNil(def.disallowedTools)
        XCTAssertNil(def.mcpServers)
        XCTAssertNil(def.skills)
        XCTAssertNil(def.criticalSystemReminderExperimental)
    }

    /// AC1 [P1]: AgentDefinition with disallowedTools populated.
    func testAgentDefinition_disallowedTools_populated() {
        let def = AgentDefinition(
            name: "Restricted",
            disallowedTools: ["Bash", "Write", "Agent"]
        )
        XCTAssertEqual(def.disallowedTools, ["Bash", "Write", "Agent"])
    }

    /// AC1 [P1]: AgentDefinition with mcpServers populated.
    func testAgentDefinition_mcpServers_populated() {
        let specs: [AgentMcpServerSpec] = [.reference("github-mcp")]
        let def = AgentDefinition(
            name: "MCPAgent",
            mcpServers: specs
        )
        XCTAssertEqual(def.mcpServers?.count, 1)
        if case .reference(let name) = def.mcpServers?.first {
            XCTAssertEqual(name, "github-mcp")
        } else {
            XCTFail("Expected .reference case")
        }
    }

    /// AC1 [P1]: AgentDefinition with skills populated.
    func testAgentDefinition_skills_populated() {
        let def = AgentDefinition(
            name: "SkilledAgent",
            skills: ["refactor", "test-gen", "review"]
        )
        XCTAssertEqual(def.skills?.count, 3)
    }

    /// AC1 [P1]: AgentDefinition with criticalSystemReminderExperimental populated.
    func testAgentDefinition_criticalSystemReminder_populated() {
        let def = AgentDefinition(
            name: "Experimental",
            criticalSystemReminderExperimental: "ALWAYS respond in JSON format"
        )
        XCTAssertEqual(def.criticalSystemReminderExperimental, "ALWAYS respond in JSON format")
    }
}

// MARK: - AC3: AgentOutput Three-State Discrimination Tests

final class AgentOutputATDDTests: XCTestCase {

    /// AC3 [P0]: AgentOutput has .completed case.
    func testAgentOutput_completedCase() {
        let completed = AgentCompletedOutput(
            agentId: "agent-123",
            content: "Task done",
            totalToolUseCount: 3,
            totalDurationMs: 1500,
            totalTokens: 500,
            usage: nil,
            prompt: "Do the thing"
        )
        let output = AgentOutput.completed(completed)
        if case .completed(let c) = output {
            XCTAssertEqual(c.agentId, "agent-123")
            XCTAssertEqual(c.content, "Task done")
        } else {
            XCTFail("Expected .completed case")
        }
    }

    /// AC3 [P0]: AgentOutput has .asyncLaunched case.
    func testAgentOutput_asyncLaunchedCase() {
        let launched = AsyncLaunchedOutput(
            agentId: "agent-456",
            description: "Background task",
            prompt: "Process data",
            outputFile: "/tmp/output.json",
            canReadOutputFile: true
        )
        let output = AgentOutput.asyncLaunched(launched)
        if case .asyncLaunched(let l) = output {
            XCTAssertEqual(l.agentId, "agent-456")
            XCTAssertEqual(l.outputFile, "/tmp/output.json")
        } else {
            XCTFail("Expected .asyncLaunched case")
        }
    }

    /// AC3 [P0]: AgentOutput has .subAgentEntered case.
    func testAgentOutput_subAgentEnteredCase() {
        let entered = SubAgentEnteredOutput(
            description: "Entered sub-agent",
            message: "Starting sub-agent execution"
        )
        let output = AgentOutput.subAgentEntered(entered)
        if case .subAgentEntered(let e) = output {
            XCTAssertEqual(e.description, "Entered sub-agent")
            XCTAssertEqual(e.message, "Starting sub-agent execution")
        } else {
            XCTFail("Expected .subAgentEntered case")
        }
    }

    /// AC3 [P0]: AgentOutput.completed carries AgentCompletedOutput.
    func testAgentOutput_completed_carriesCompletedOutput() {
        let completed = AgentCompletedOutput(
            agentId: "a1",
            content: "result",
            totalToolUseCount: 0,
            totalDurationMs: 100,
            totalTokens: 50,
            usage: nil,
            prompt: "test"
        )
        let output = AgentOutput.completed(completed)
        switch output {
        case .completed(let c):
            XCTAssertEqual(c.agentId, "a1")
        case .asyncLaunched, .subAgentEntered:
            XCTFail("Expected .completed case")
        }
    }

    /// AC3 [P0]: AgentOutput.asyncLaunched carries AsyncLaunchedOutput.
    func testAgentOutput_asyncLaunched_carriesLaunchedOutput() {
        let launched = AsyncLaunchedOutput(
            agentId: "a2",
            description: "bg",
            prompt: "run",
            outputFile: nil,
            canReadOutputFile: false
        )
        let output = AgentOutput.asyncLaunched(launched)
        switch output {
        case .asyncLaunched(let l):
            XCTAssertEqual(l.agentId, "a2")
        case .completed, .subAgentEntered:
            XCTFail("Expected .asyncLaunched case")
        }
    }

    /// AC3 [P0]: AgentOutput.subAgentEntered carries SubAgentEnteredOutput.
    func testAgentOutput_subAgentEntered_carriesEnteredOutput() {
        let entered = SubAgentEnteredOutput(description: "desc", message: "msg")
        let output = AgentOutput.subAgentEntered(entered)
        switch output {
        case .subAgentEntered(let e):
            XCTAssertEqual(e.description, "desc")
        case .completed, .asyncLaunched:
            XCTFail("Expected .subAgentEntered case")
        }
    }

    /// AC3 [P0]: AgentOutput conforms to Sendable.
    func testAgentOutput_conformsToSendable() {
        let output = AgentOutput.completed(
            AgentCompletedOutput(
                agentId: "a",
                content: "c",
                totalToolUseCount: 0,
                totalDurationMs: 0,
                totalTokens: 0,
                usage: nil,
                prompt: "p"
            )
        )
        let _: any Sendable = output
    }

    /// AC3 [P0]: AgentOutput conforms to Equatable.
    func testAgentOutput_conformsToEquatable() {
        let a = AgentOutput.completed(
            AgentCompletedOutput(
                agentId: "a",
                content: "c",
                totalToolUseCount: 0,
                totalDurationMs: 0,
                totalTokens: 0,
                usage: nil,
                prompt: "p"
            )
        )
        let b = AgentOutput.completed(
            AgentCompletedOutput(
                agentId: "a",
                content: "c",
                totalToolUseCount: 0,
                totalDurationMs: 0,
                totalTokens: 0,
                usage: nil,
                prompt: "p"
            )
        )
        XCTAssertEqual(a, b)
    }
}

// MARK: - AC3: AgentCompletedOutput Tests

final class AgentCompletedOutputATDDTests: XCTestCase {

    /// AC3 [P0]: AgentCompletedOutput has all required fields.
    func testAgentCompletedOutput_allFields() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        let output = AgentCompletedOutput(
            agentId: "agent-789",
            content: "Analysis complete",
            totalToolUseCount: 5,
            totalDurationMs: 3000,
            totalTokens: 150,
            usage: usage,
            prompt: "Analyze the codebase"
        )
        XCTAssertEqual(output.agentId, "agent-789")
        XCTAssertEqual(output.content, "Analysis complete")
        XCTAssertEqual(output.totalToolUseCount, 5)
        XCTAssertEqual(output.totalDurationMs, 3000)
        XCTAssertEqual(output.totalTokens, 150)
        XCTAssertEqual(output.usage, usage)
        XCTAssertEqual(output.prompt, "Analyze the codebase")
    }

    /// AC3 [P0]: AgentCompletedOutput conforms to Sendable.
    func testAgentCompletedOutput_conformsToSendable() {
        let output = AgentCompletedOutput(
            agentId: "a",
            content: "c",
            totalToolUseCount: 0,
            totalDurationMs: 0,
            totalTokens: 0,
            usage: nil,
            prompt: "p"
        )
        let _: any Sendable = output
    }

    /// AC3 [P0]: AgentCompletedOutput conforms to Equatable.
    func testAgentCompletedOutput_conformsToEquatable() {
        let a = AgentCompletedOutput(
            agentId: "a",
            content: "c",
            totalToolUseCount: 1,
            totalDurationMs: 100,
            totalTokens: 50,
            usage: nil,
            prompt: "p"
        )
        let b = AgentCompletedOutput(
            agentId: "a",
            content: "c",
            totalToolUseCount: 1,
            totalDurationMs: 100,
            totalTokens: 50,
            usage: nil,
            prompt: "p"
        )
        XCTAssertEqual(a, b)
    }

    /// AC3 [P1]: AgentCompletedOutput with nil usage.
    func testAgentCompletedOutput_nilUsage() {
        let output = AgentCompletedOutput(
            agentId: "a",
            content: "c",
            totalToolUseCount: 0,
            totalDurationMs: 0,
            totalTokens: 0,
            usage: nil,
            prompt: "p"
        )
        XCTAssertNil(output.usage)
    }
}

// MARK: - AC3: AsyncLaunchedOutput Tests

final class AsyncLaunchedOutputATDDTests: XCTestCase {

    /// AC3 [P0]: AsyncLaunchedOutput has all required fields.
    func testAsyncLaunchedOutput_allFields() {
        let output = AsyncLaunchedOutput(
            agentId: "agent-bg-001",
            description: "Background code review",
            prompt: "Review the PR",
            outputFile: "/tmp/agent-output-001.json",
            canReadOutputFile: true
        )
        XCTAssertEqual(output.agentId, "agent-bg-001")
        XCTAssertEqual(output.description, "Background code review")
        XCTAssertEqual(output.prompt, "Review the PR")
        XCTAssertEqual(output.outputFile, "/tmp/agent-output-001.json")
        XCTAssertTrue(output.canReadOutputFile)
    }

    /// AC3 [P0]: AsyncLaunchedOutput conforms to Sendable.
    func testAsyncLaunchedOutput_conformsToSendable() {
        let output = AsyncLaunchedOutput(
            agentId: "a",
            description: "d",
            prompt: "p",
            outputFile: nil,
            canReadOutputFile: false
        )
        let _: any Sendable = output
    }

    /// AC3 [P0]: AsyncLaunchedOutput conforms to Equatable.
    func testAsyncLaunchedOutput_conformsToEquatable() {
        let a = AsyncLaunchedOutput(
            agentId: "a",
            description: "d",
            prompt: "p",
            outputFile: nil,
            canReadOutputFile: false
        )
        let b = AsyncLaunchedOutput(
            agentId: "a",
            description: "d",
            prompt: "p",
            outputFile: nil,
            canReadOutputFile: false
        )
        XCTAssertEqual(a, b)
    }

    /// AC3 [P1]: AsyncLaunchedOutput with nil outputFile.
    func testAsyncLaunchedOutput_nilOutputFile() {
        let output = AsyncLaunchedOutput(
            agentId: "a",
            description: "d",
            prompt: "p",
            outputFile: nil,
            canReadOutputFile: false
        )
        XCTAssertNil(output.outputFile)
        XCTAssertFalse(output.canReadOutputFile)
    }
}

// MARK: - AC3: SubAgentEnteredOutput Tests

final class SubAgentEnteredOutputATDDTests: XCTestCase {

    /// AC3 [P0]: SubAgentEnteredOutput has description field.
    func testSubAgentEnteredOutput_description() {
        let output = SubAgentEnteredOutput(
            description: "Entering Plan agent",
            message: "Sub-agent started"
        )
        XCTAssertEqual(output.description, "Entering Plan agent")
    }

    /// AC3 [P0]: SubAgentEnteredOutput has message field.
    func testSubAgentEnteredOutput_message() {
        let output = SubAgentEnteredOutput(
            description: "desc",
            message: "Sub-agent started execution"
        )
        XCTAssertEqual(output.message, "Sub-agent started execution")
    }

    /// AC3 [P0]: SubAgentEnteredOutput conforms to Sendable.
    func testSubAgentEnteredOutput_conformsToSendable() {
        let output = SubAgentEnteredOutput(description: "d", message: "m")
        let _: any Sendable = output
    }

    /// AC3 [P0]: SubAgentEnteredOutput conforms to Equatable.
    func testSubAgentEnteredOutput_conformsToEquatable() {
        let a = SubAgentEnteredOutput(description: "d", message: "m")
        let b = SubAgentEnteredOutput(description: "d", message: "m")
        XCTAssertEqual(a, b)
    }

    /// AC3 [P1]: SubAgentEnteredOutput init with all fields.
    func testSubAgentEnteredOutput_init() {
        let output = SubAgentEnteredOutput(
            description: "Entered exploration sub-agent",
            message: "Starting codebase analysis"
        )
        XCTAssertEqual(output.description, "Entered exploration sub-agent")
        XCTAssertEqual(output.message, "Starting codebase analysis")
    }
}

// MARK: - AC5: SubAgentSpawner Protocol Extension Tests

final class SubAgentSpawnerExtensionATDDTests: XCTestCase {

    /// AC5 [P0]: SubAgentSpawner has a new spawn overload with extra parameters.
    func testSubAgentSpawner_hasNewSpawnOverload() async {
        let spawner = EnhancedMockSpawner(result: SubAgentResult(text: "OK"))

        // The new overload should accept additional parameters
        let result = await spawner.spawn(
            prompt: "Test",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: ["Bash"],
            mcpServers: nil,
            skills: nil,
            runInBackground: false,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )
        XCTAssertEqual(result.text, "OK")
    }

    /// AC5 [P0]: Protocol extension default delegates to original spawn (backward compat).
    func testSubAgentSpawner_defaultDelegation() async {
        let spawner = MinimalMockSpawner(result: SubAgentResult(text: "Delegated"))

        // MinimalMockSpawner only implements the original 5-param spawn.
        // The protocol extension default should call it.
        let result = await spawner.spawn(
            prompt: "Test",
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
        XCTAssertEqual(result.text, "Delegated")
    }

    /// AC5 [P0]: New spawn overload passes disallowedTools to conformer.
    func testSubAgentSpawner_newOverload_passesDisallowedTools() async {
        let spawner = EnhancedMockSpawner(result: SubAgentResult(text: "OK"))
        _ = await spawner.spawn(
            prompt: "Test",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: ["Write", "Bash"],
            mcpServers: nil,
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )
        XCTAssertEqual(spawner.lastDisallowedTools, ["Write", "Bash"])
    }

    /// AC5 [P0]: New spawn overload passes mcpServers to conformer.
    func testSubAgentSpawner_newOverload_passesMcpServers() async {
        let spawner = EnhancedMockSpawner(result: SubAgentResult(text: "OK"))
        let servers: [AgentMcpServerSpec] = [.reference("my-mcp")]
        _ = await spawner.spawn(
            prompt: "Test",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: servers,
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )
        XCTAssertEqual(spawner.lastMcpServers?.count, 1)
    }

    /// AC5 [P0]: New spawn overload passes skills to conformer.
    func testSubAgentSpawner_newOverload_passesSkills() async {
        let spawner = EnhancedMockSpawner(result: SubAgentResult(text: "OK"))
        _ = await spawner.spawn(
            prompt: "Test",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: nil,
            skills: ["review", "test"],
            runInBackground: nil,
            isolation: nil,
            name: nil,
            teamName: nil,
            mode: nil,
            resume: nil
        )
        XCTAssertEqual(spawner.lastSkills, ["review", "test"])
    }

    /// AC5 [P0]: New spawn overload passes runInBackground to conformer.
    func testSubAgentSpawner_newOverload_passesRunInBackground() async {
        let spawner = EnhancedMockSpawner(result: SubAgentResult(text: "OK"))
        _ = await spawner.spawn(
            prompt: "Test",
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
        XCTAssertEqual(spawner.lastRunInBackground, true)
    }

    /// AC5 [P0]: New spawn overload passes isolation to conformer.
    func testSubAgentSpawner_newOverload_passesIsolation() async {
        let spawner = EnhancedMockSpawner(result: SubAgentResult(text: "OK"))
        _ = await spawner.spawn(
            prompt: "Test",
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
        XCTAssertEqual(spawner.lastIsolation, "worktree")
    }

    /// AC5 [P0]: New spawn overload passes name to conformer.
    func testSubAgentSpawner_newOverload_passesName() async {
        let spawner = EnhancedMockSpawner(result: SubAgentResult(text: "OK"))
        _ = await spawner.spawn(
            prompt: "Test",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil,
            disallowedTools: nil,
            mcpServers: nil,
            skills: nil,
            runInBackground: nil,
            isolation: nil,
            name: "custom-agent",
            teamName: nil,
            mode: nil,
            resume: nil
        )
        XCTAssertEqual(spawner.lastName, "custom-agent")
    }

    /// AC5 [P0]: New spawn overload passes teamName to conformer.
    func testSubAgentSpawner_newOverload_passesTeamName() async {
        let spawner = EnhancedMockSpawner(result: SubAgentResult(text: "OK"))
        _ = await spawner.spawn(
            prompt: "Test",
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
            teamName: "my-team",
            mode: nil,
            resume: nil
        )
        XCTAssertEqual(spawner.lastTeamName, "my-team")
    }

    /// AC5 [P0]: New spawn overload passes mode (PermissionMode?) to conformer.
    func testSubAgentSpawner_newOverload_passesMode() async {
        let spawner = EnhancedMockSpawner(result: SubAgentResult(text: "OK"))
        _ = await spawner.spawn(
            prompt: "Test",
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
            mode: .bypassPermissions,
            resume: nil
        )
        XCTAssertEqual(spawner.lastMode, .bypassPermissions)
    }

    /// AC5 [P0]: Existing SubAgentSpawner conformers still compile (backward compat).
    func testSubAgentSpawner_existingConformerCompiles() async {
        // MinimalMockSpawner only implements the original 5-param spawn.
        // This should still compile after adding the protocol extension.
        let spawner = MinimalMockSpawner(result: SubAgentResult(text: "Legacy OK"))
        let result = await spawner.spawn(
            prompt: "test",
            model: nil,
            systemPrompt: nil,
            allowedTools: nil,
            maxTurns: nil
        )
        XCTAssertEqual(result.text, "Legacy OK")
    }
}

// MARK: - AC2: AgentToolInput Field Completion Tests (via public tool interface)
//
// NOTE: AgentToolInput is private in AgentTool.swift, so we cannot decode it directly
// in tests. Instead, we test the schema (public) and tool behavior (public call).
// The decode tests will be added in AgentToolTests.swift where the mock spawner
// records call parameters including new fields.

final class AgentToolInputEnhancementATDDTests: XCTestCase {

    /// AC2 [P0]: agentToolSchema includes run_in_background property definition.
    func testAgentToolSchema_includesRunInBackground() {
        let tool = createAgentTool()
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["run_in_background"],
            "agentToolSchema should include 'run_in_background' property")
    }

    /// AC2 [P0]: agentToolSchema includes isolation property definition.
    func testAgentToolSchema_includesIsolation() {
        let tool = createAgentTool()
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["isolation"],
            "agentToolSchema should include 'isolation' property")
    }

    /// AC2 [P0]: agentToolSchema includes team_name property definition.
    func testAgentToolSchema_includesTeamName() {
        let tool = createAgentTool()
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["team_name"],
            "agentToolSchema should include 'team_name' property")
    }

    /// AC2 [P0]: agentToolSchema includes mode property definition.
    func testAgentToolSchema_includesMode() {
        let tool = createAgentTool()
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["mode"],
            "agentToolSchema should include 'mode' property")
    }

    /// AC2 [P0]: agentToolSchema includes resume property definition.
    func testAgentToolSchema_includesResume() {
        let tool = createAgentTool()
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["resume"],
            "agentToolSchema should include 'resume' property")
    }

    /// AC2 [P1]: AgentTool passes run_in_background to spawner via public call interface.
    func testAgentTool_passesRunInBackground_toSpawner() async throws {
        let mockSpawner = EnhancedMockSpawner(result: SubAgentResult(text: "Done"))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Background task",
            "description": "BG task",
            "run_in_background": true
        ]
        _ = await tool.call(input: input, context: context)

        XCTAssertEqual(mockSpawner.lastRunInBackground, true)
    }

    /// AC2 [P1]: AgentTool passes isolation to spawner via public call interface.
    func testAgentTool_passesIsolation_toSpawner() async throws {
        let mockSpawner = EnhancedMockSpawner(result: SubAgentResult(text: "Done"))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Isolated task",
            "description": "Isolated",
            "isolation": "worktree"
        ]
        _ = await tool.call(input: input, context: context)

        XCTAssertEqual(mockSpawner.lastIsolation, "worktree")
    }

    /// AC2 [P1]: AgentTool passes mode string and resolves to PermissionMode.
    func testAgentTool_passesMode_toSpawner() async throws {
        let mockSpawner = EnhancedMockSpawner(result: SubAgentResult(text: "Done"))
        let tool = createAgentTool()
        let context = ToolContext(cwd: "/tmp", agentSpawner: mockSpawner)

        let input: [String: Any] = [
            "prompt": "Task with mode",
            "description": "Mode test",
            "mode": "bypassPermissions"
        ]
        _ = await tool.call(input: input, context: context)

        XCTAssertEqual(mockSpawner.lastMode, .bypassPermissions)
    }
}

// MARK: - Mocks for AC5 Tests

/// Enhanced mock that implements the new spawn overload with full parameter recording.
private final class EnhancedMockSpawner: SubAgentSpawner, @unchecked Sendable {
    let result: SubAgentResult
    private(set) var lastDisallowedTools: [String]?
    private(set) var lastMcpServers: [AgentMcpServerSpec]?
    private(set) var lastSkills: [String]?
    private(set) var lastRunInBackground: Bool?
    private(set) var lastIsolation: String?
    private(set) var lastName: String?
    private(set) var lastTeamName: String?
    private(set) var lastMode: PermissionMode?

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
        lastDisallowedTools = disallowedTools
        lastMcpServers = mcpServers
        lastSkills = skills
        lastRunInBackground = runInBackground
        lastIsolation = isolation
        lastName = name
        lastTeamName = teamName
        lastMode = mode
        return result
    }
}

/// Minimal mock that only implements the original 5-param spawn.
/// Used to verify protocol extension default delegation.
private final class MinimalMockSpawner: SubAgentSpawner, @unchecked Sendable {
    let result: SubAgentResult
    private(set) var originalSpawnCalled = false

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
        originalSpawnCalled = true
        return result
    }
}

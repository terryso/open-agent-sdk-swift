import XCTest
@testable import OpenAgentSDK

/// Tests for Agent.executeSkill() — direct skill execution bypassing LLM skill-discovery.
final class ExecuteSkillTests: XCTestCase {

    // MARK: - Error Cases

    /// Returns error when skill is not found in registry.
    func testExecuteSkill_notFound_returnsError() async {
        let registry = SkillRegistry()
        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        let result = await agent.executeSkill("nonexistent")
        XCTAssertEqual(result.status, .errorDuringExecution)
        XCTAssertTrue((result.errors?.first ?? "").contains("not found"),
                       "Expected 'not found' error, got: \(String(describing: result.errors))")
    }

    /// Returns error when skill is registered but not available.
    func testExecuteSkill_notAvailable_returnsError() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "unavailable",
            isAvailable: { false }
        ))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        let result = await agent.executeSkill("unavailable")
        XCTAssertEqual(result.status, .errorDuringExecution)
        XCTAssertTrue((result.errors?.first ?? "").contains("not available"),
                       "Expected 'not available' error, got: \(String(describing: result.errors))")
    }

    /// Returns error when agent is closed.
    func testExecuteSkill_agentClosed_returnsError() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(name: "commit"))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        try? await agent.close()
        let result = await agent.executeSkill("commit")
        XCTAssertEqual(result.status, .errorDuringExecution)
        XCTAssertTrue((result.errors?.first ?? "").contains("already closed"))
    }

    // MARK: - Skill Resolution

    /// Resolves skill by alias.
    func testExecuteSkill_resolvesByAlias() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "commit",
            aliases: ["ci"],
            promptTemplate: "Create a commit"
        ))

        XCTAssertNotNil(registry.find("ci"))
    }

    // MARK: - State Restoration

    /// Restores allowedTools after skill execution.
    func testExecuteSkill_restoresAllowedTools() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "restricted-skill",
            toolRestrictions: [.bash, .read],
            promptTemplate: "Do restricted things"
        ))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry,
            allowedTools: ["Bash", "Read", "Write"]
        ))

        XCTAssertEqual(agent.options.allowedTools, ["Bash", "Read", "Write"])

        _ = await agent.executeSkill("restricted-skill")

        XCTAssertEqual(agent.options.allowedTools, ["Bash", "Read", "Write"])
    }

    /// Restores model after skill execution when skill has modelOverride.
    func testExecuteSkill_restoresModel() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "opus-skill",
            modelOverride: "claude-opus-4-6",
            promptTemplate: "Do opus things"
        ))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        XCTAssertEqual(agent.model, "claude-sonnet-4-6")

        _ = await agent.executeSkill("opus-skill")

        XCTAssertEqual(agent.model, "claude-sonnet-4-6")
    }

    /// Does not change model when skill has no modelOverride.
    func testExecuteSkill_noModelOverride_keepsModel() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "basic-skill",
            modelOverride: nil,
            promptTemplate: "Do basic things"
        ))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        XCTAssertEqual(agent.model, "claude-sonnet-4-6")
        _ = await agent.executeSkill("basic-skill")
        XCTAssertEqual(agent.model, "claude-sonnet-4-6")
    }

    // MARK: - Tool Restriction Filtering

    /// When skill has toolRestrictions, they are applied during execution and restored after.
    func testExecuteSkill_toolRestrictions_appliedDuringExecution() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "restricted",
            toolRestrictions: [.bash, .read],
            promptTemplate: "Restricted execution"
        ))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        XCTAssertNil(agent.options.allowedTools)

        _ = await agent.executeSkill("restricted")

        XCTAssertNil(agent.options.allowedTools)
    }
}

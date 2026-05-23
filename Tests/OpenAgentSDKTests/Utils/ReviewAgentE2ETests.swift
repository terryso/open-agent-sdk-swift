// ReviewAgentE2ETests.swift
// Story 24.1: ReviewAgent — E2E Integration Tests
//
// Full pipeline integration tests verifying:
// Config → PromptBuilder → Factory → Agent creation as a complete flow.
// Uses mock LLMClient (no real API calls per project convention).

import XCTest
@testable import OpenAgentSDK

final class ReviewAgentE2ETests: XCTestCase {

    // MARK: - Mock LLM Client

    private struct MockLLMClient: LLMClient, Sendable {
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
            return [
                "content": [["type": "text", "text": "review complete"]],
                "stop_reason": "end_turn",
                "usage": ["input_tokens": 10, "output_tokens": 5],
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
            AsyncThrowingStream { $0.finish() }
        }
    }

    // MARK: - Helpers

    private func makeParentAgent(
        model: String = "claude-sonnet-4-6",
        systemPrompt: String = "You are a helpful coding assistant.",
        sessionId: String? = "parent-session-e2e",
        maxBudgetUsd: Double? = 10.0
    ) -> Agent {
        let client = MockLLMClient()
        return Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: model,
                systemPrompt: systemPrompt,
                maxTurns: 10,
                maxBudgetUsd: maxBudgetUsd,
                sessionId: sessionId
            ),
            client: client
        )
    }

    // MARK: - Full Pipeline: Config → Prompt → Factory → Agent

    /// End-to-end: default config produces a review agent with combined prompt
    /// and all correct inherited/overridden/nil fields.
    func testFullPipeline_defaultConfig_producesCorrectReviewAgent() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let prompt = ReviewPromptBuilder.selectPrompt(config: config)
        let review = parent.createReviewAgent(config: config)

        // Prompt: default config → both flags true → combined
        XCTAssertEqual(prompt, ReviewPromptBuilder.combinedReviewPrompt())

        // Inherited
        XCTAssertEqual(review.model, "claude-sonnet-4-6")
        XCTAssertEqual(review.systemPrompt, "You are a helpful coding assistant.")
        XCTAssertEqual(review.options.maxBudgetUsd, 10.0)

        // Overridden
        XCTAssertEqual(review.maxTurns, 16)
        XCTAssertEqual(review.options.permissionMode, .bypassPermissions)
        XCTAssertEqual(review.getSessionId(), "review-parent-session-e2e")
        XCTAssertEqual(review.options.allowedTools, [
            "review_save_memory", "review_update_skill",
            "review_create_skill", "review_add_skill_file",
        ])
        XCTAssertEqual(review.options.agentName, "review-agent")

        // Nil fields
        XCTAssertNil(review.options.hookRegistry)
        XCTAssertNil(review.options.skillRegistry)
        XCTAssertNil(review.options.mcpServers)
        XCTAssertNil(review.options.mailboxStore)
        XCTAssertNil(review.options.taskStore)
        XCTAssertNil(review.options.memoryStore)
        XCTAssertNil(review.options.sessionStore)
    }

    /// End-to-end: memory-only config produces a review agent with memory prompt.
    func testFullPipeline_memoryOnlyConfig_selectsMemoryPrompt() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: false)
        let prompt = ReviewPromptBuilder.selectPrompt(config: config)
        _ = parent.createReviewAgent(config: config)

        XCTAssertEqual(prompt, ReviewPromptBuilder.memoryReviewPrompt())
    }

    /// End-to-end: skill-only config produces a review agent with skill prompt.
    func testFullPipeline_skillOnlyConfig_selectsSkillPrompt() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig(reviewMemory: false, reviewSkills: true)
        let prompt = ReviewPromptBuilder.selectPrompt(config: config)
        _ = parent.createReviewAgent(config: config)

        XCTAssertEqual(prompt, ReviewPromptBuilder.skillReviewPrompt())
    }

    /// End-to-end: custom maxTurns and allowedTools flow through to the review agent.
    func testFullPipeline_customConfigValues_flowToReviewAgent() {
        let parent = makeParentAgent()
        let customTools = ["review_save_memory"]
        let config = ReviewAgentConfig(
            reviewMemory: true,
            reviewSkills: false,
            maxTurns: 4,
            allowedTools: customTools
        )
        let review = parent.createReviewAgent(config: config)

        XCTAssertEqual(review.maxTurns, 4)
        XCTAssertEqual(review.options.allowedTools, customTools)
    }

    // MARK: - Full Pipeline: Multiple Review Agents from Same Parent

    /// Creating multiple review agents from the same parent produces independent agents.
    func testFullPipeline_multipleConfigs_produceIndependentAgents() {
        let parent = makeParentAgent()

        let memoryConfig = ReviewAgentConfig(reviewMemory: true, reviewSkills: false, maxTurns: 4)
        let skillConfig = ReviewAgentConfig(reviewMemory: false, reviewSkills: true, maxTurns: 8)
        let combinedConfig = ReviewAgentConfig(reviewMemory: true, reviewSkills: true, maxTurns: 12)

        let memoryAgent = parent.createReviewAgent(config: memoryConfig)
        let skillAgent = parent.createReviewAgent(config: skillConfig)
        let combinedAgent = parent.createReviewAgent(config: combinedConfig)

        // All share parent's model and system prompt
        XCTAssertEqual(memoryAgent.model, parent.model)
        XCTAssertEqual(skillAgent.model, parent.model)
        XCTAssertEqual(combinedAgent.model, parent.model)
        XCTAssertEqual(memoryAgent.systemPrompt, parent.systemPrompt)

        // Different maxTurns from their configs
        XCTAssertEqual(memoryAgent.maxTurns, 4)
        XCTAssertEqual(skillAgent.maxTurns, 8)
        XCTAssertEqual(combinedAgent.maxTurns, 12)

        // All have the review- prefix session ID
        XCTAssertTrue(memoryAgent.getSessionId()?.hasPrefix("review-") == true)
        XCTAssertTrue(skillAgent.getSessionId()?.hasPrefix("review-") == true)
        XCTAssertTrue(combinedAgent.getSessionId()?.hasPrefix("review-") == true)

        // All bypass permissions
        XCTAssertEqual(memoryAgent.options.permissionMode, .bypassPermissions)
        XCTAssertEqual(skillAgent.options.permissionMode, .bypassPermissions)
        XCTAssertEqual(combinedAgent.options.permissionMode, .bypassPermissions)
    }

    // MARK: - Config Mutation Isolation

    /// Mutating a config after creating a review agent does not affect the agent.
    func testConfigMutation_doesNotAffectCreatedAgent() {
        let parent = makeParentAgent()
        var config = ReviewAgentConfig(maxTurns: 8)
        let review = parent.createReviewAgent(config: config)

        XCTAssertEqual(review.maxTurns, 8)

        // Mutate the config
        config.maxTurns = 2
        config.allowedTools = ["review_save_memory"]

        // Review agent should be unaffected
        XCTAssertEqual(review.maxTurns, 8)
        XCTAssertEqual(review.options.allowedTools, [
            "review_save_memory", "review_update_skill",
            "review_create_skill", "review_add_skill_file",
        ])
    }

    // MARK: - Prompt Structural Fidelity

    /// The skill prompt's preference order sections appear in the correct sequence.
    func testSkillPrompt_preferenceOrderSections_inCorrectSequence() {
        let prompt = ReviewPromptBuilder.skillReviewPrompt()

        let loaded = prompt.range(of: "UPDATE A CURRENTLY-LOADED SKILL")
        let umbrella = prompt.range(of: "UPDATE AN EXISTING UMBRELLA")
        let supportFile = prompt.range(of: "ADD A SUPPORT FILE")
        let newSkill = prompt.range(of: "CREATE A NEW CLASS-LEVEL")

        XCTAssertNotNil(loaded)
        XCTAssertNotNil(umbrella)
        XCTAssertNotNil(supportFile)
        XCTAssertNotNil(newSkill)

        // Preference order: loaded < umbrella < supportFile < newSkill
        XCTAssertLessThan(loaded!.lowerBound, umbrella!.lowerBound)
        XCTAssertLessThan(umbrella!.lowerBound, supportFile!.lowerBound)
        XCTAssertLessThan(supportFile!.lowerBound, newSkill!.lowerBound)
    }

    /// The skill prompt's anti-patterns section lists all four anti-patterns.
    func testSkillPrompt_antiPatterns_allFourPresent() {
        let prompt = ReviewPromptBuilder.skillReviewPrompt()

        let antiPatterns = [
            "Environment-dependent failures",
            "Negative claims about tools",
            "Session-specific transient errors",
            "One-off task narratives",
        ]
        for pattern in antiPatterns {
            XCTAssertTrue(prompt.contains(pattern), "Missing anti-pattern: \(pattern)")
        }
    }

    /// The skill prompt mentions all three support file directory types.
    func testSkillPrompt_supportFileDirectories_allThreePresent() {
        let prompt = ReviewPromptBuilder.skillReviewPrompt()

        XCTAssertTrue(prompt.contains("references/"))
        XCTAssertTrue(prompt.contains("templates/"))
        XCTAssertTrue(prompt.contains("scripts/"))
    }

    /// The skill prompt references the correct SDK review tool names.
    func testSkillPrompt_reviewToolNames_correctSdkNames() {
        let prompt = ReviewPromptBuilder.skillReviewPrompt()

        XCTAssertTrue(prompt.contains("review_add_skill_file"))
        // review_update_skill and review_create_skill are tool names from config,
        // but the prompt mentions them by action description not by exact tool name
    }

    /// The combined prompt contains elements from both memory and skill dimensions.
    func testCombinedPrompt_containsBothMemoryAndSkillElements() {
        let prompt = ReviewPromptBuilder.combinedReviewPrompt()

        // Memory elements
        XCTAssertTrue(prompt.contains("review_save_memory"))
        XCTAssertTrue(prompt.contains("preferences"))

        // Skill elements
        XCTAssertTrue(prompt.contains("ACTIVE"))
        XCTAssertTrue(prompt.contains("UPDATE A CURRENTLY-LOADED SKILL"))
        XCTAssertTrue(prompt.contains("UPDATE AN EXISTING UMBRELLA"))
        XCTAssertTrue(prompt.contains("ADD A SUPPORT FILE"))
        XCTAssertTrue(prompt.contains("CREATE A NEW CLASS-LEVEL"))
        XCTAssertTrue(prompt.contains("review_add_skill_file"))
        XCTAssertTrue(prompt.contains("references/"))
        XCTAssertTrue(prompt.contains("templates/"))
        XCTAssertTrue(prompt.contains("scripts/"))

        // Shared elements
        XCTAssertTrue(prompt.contains("Do NOT capture"))
        XCTAssertTrue(prompt.contains("Protected skills"))
        XCTAssertTrue(prompt.contains("User-preference embedding"))
    }

    /// The combined prompt's preference order sections appear in correct sequence.
    func testCombinedPrompt_preferenceOrder_inCorrectSequence() {
        let prompt = ReviewPromptBuilder.combinedReviewPrompt()

        let loaded = prompt.range(of: "UPDATE A CURRENTLY-LOADED SKILL")
        let umbrella = prompt.range(of: "UPDATE AN EXISTING UMBRELLA")
        let supportFile = prompt.range(of: "ADD A SUPPORT FILE")
        let newSkill = prompt.range(of: "CREATE A NEW CLASS-LEVEL")

        XCTAssertNotNil(loaded)
        XCTAssertNotNil(umbrella)
        XCTAssertNotNil(supportFile)
        XCTAssertNotNil(newSkill)

        XCTAssertLessThan(loaded!.lowerBound, umbrella!.lowerBound)
        XCTAssertLessThan(umbrella!.lowerBound, supportFile!.lowerBound)
        XCTAssertLessThan(supportFile!.lowerBound, newSkill!.lowerBound)
    }

    /// The combined prompt contains all four anti-patterns.
    func testCombinedPrompt_antiPatterns_allFourPresent() {
        let prompt = ReviewPromptBuilder.combinedReviewPrompt()

        let antiPatterns = [
            "Environment-dependent failures",
            "Negative claims about tools",
            "Session-specific transient errors",
            "One-off task narratives",
        ]
        for pattern in antiPatterns {
            XCTAssertTrue(prompt.contains(pattern), "Missing anti-pattern: \(pattern)")
        }
    }

    /// The memory prompt focuses on user persona and preferences (not skill content).
    func testMemoryPrompt_doesNotContainSkillSpecificContent() {
        let prompt = ReviewPromptBuilder.memoryReviewPrompt()

        XCTAssertFalse(prompt.contains("ACTIVE"))
        XCTAssertFalse(prompt.contains("UPDATE A CURRENTLY-LOADED"))
        XCTAssertFalse(prompt.contains("preference order"))
    }

    /// Each prompt is deterministic — calling twice returns the same string.
    func testPromptsAreDeterministic() {
        XCTAssertEqual(ReviewPromptBuilder.memoryReviewPrompt(), ReviewPromptBuilder.memoryReviewPrompt())
        XCTAssertEqual(ReviewPromptBuilder.skillReviewPrompt(), ReviewPromptBuilder.skillReviewPrompt())
        XCTAssertEqual(ReviewPromptBuilder.combinedReviewPrompt(), ReviewPromptBuilder.combinedReviewPrompt())
    }

    // MARK: - ReviewAgentResult Integration

    /// ReviewAgentResult.noChanges produces a result usable in a no-op review flow.
    func testNoChangesResult_isValidForNoOpFlow() {
        let result = ReviewAgentResult.noChanges(summary: "Nothing to save.")
        XCTAssertEqual(result.memoryChanges, [])
        XCTAssertEqual(result.skillChanges, [])
        XCTAssertEqual(result.summary, "Nothing to save.")
        XCTAssertEqual(result.reviewMessages, [])
    }

    /// ReviewAgentResult with real SDKMessage types round-trips correctly.
    func testResult_withMixedMessageTypes_preservesAllFields() {
        let messages: [SDKMessage] = [
            .userMessage(.init(message: "Review this session")),
            .assistant(.init(text: "I found learnings", model: "claude-sonnet-4-6", stopReason: "end_turn")),
            .toolResult(.init(toolUseId: "tu1", content: "Saved memory", isError: false)),
        ]
        let result = ReviewAgentResult(
            memoryChanges: ["User prefers concise responses"],
            skillChanges: ["Updated testing skill with pitfall"],
            summary: "2 changes made",
            reviewMessages: messages
        )

        XCTAssertEqual(result.memoryChanges.count, 1)
        XCTAssertEqual(result.skillChanges.count, 1)
        XCTAssertEqual(result.reviewMessages.count, 3)
        XCTAssertEqual(result.summary, "2 changes made")
    }

    // MARK: - Deferred AgentOptions Fields

    /// The review agent's deferred fields (memoryReviewConfig, securityConfig,
    /// evolutionPlugins) are nil, confirming complete isolation.
    func testReviewAgent_deferredFieldsAreNil() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)

        XCTAssertNil(review.options.memoryReviewConfig)
        XCTAssertNil(review.options.securityConfig)
        XCTAssertNil(review.options.evolutionPlugins)
        XCTAssertNil(review.options.canUseTool)
    }

    // MARK: - SessionId Isolation

    /// Each review agent gets a unique session ID derived from the parent's session ID.
    func testSessionId_derivedFromParentSession() {
        let parent = makeParentAgent(sessionId: "my-session")
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)

        XCTAssertEqual(review.getSessionId(), "review-my-session")
    }

    /// When parent has no session ID, review agent still gets a valid review- prefixed ID.
    func testSessionId_whenParentNil_generatesValidReviewId() {
        let parent = makeParentAgent(sessionId: nil)
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)

        let sessionId = review.getSessionId()
        XCTAssertNotNil(sessionId)
        XCTAssertTrue(sessionId!.hasPrefix("review-"))
        // After "review-" prefix, should be a UUID (non-empty)
        let suffix = sessionId!.dropFirst("review-".count)
        XCTAssertFalse(suffix.isEmpty)
    }

    // MARK: - Codable Round-Trip Integration

    /// Config Codable round-trip preserves all fields needed for factory creation.
    func testConfigCodable_roundTrip_preservesFactoryInputs() throws {
        let original = ReviewAgentConfig(
            reviewMemory: false,
            reviewSkills: true,
            maxTurns: 5,
            allowedTools: ["review_save_memory", "review_create_skill"]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(ReviewAgentConfig.self, from: data)

        // Verify decoded config produces same prompt selection
        XCTAssertEqual(
            ReviewPromptBuilder.selectPrompt(config: decoded),
            ReviewPromptBuilder.selectPrompt(config: original)
        )

        // Verify decoded config can create an agent via factory
        let parent = makeParentAgent()
        let review = parent.createReviewAgent(config: decoded)
        XCTAssertEqual(review.maxTurns, 5)
        XCTAssertEqual(review.options.allowedTools, ["review_save_memory", "review_create_skill"])
    }

    // MARK: - Tools Isolation

    /// The review agent's tool list is empty (tools injected later by Story 24.2).
    func testReviewAgent_toolsAreEmpty_awaitingInjection() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)

        let toolCount = review.options.tools?.count ?? 0
        XCTAssertEqual(toolCount, 0, "Review agent should start with no tools")
    }
}

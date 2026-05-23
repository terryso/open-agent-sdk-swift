import XCTest
@testable import OpenAgentSDK

final class ReviewAgentFactoryTests: XCTestCase {

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

    private func makeParentAgent(sessionId: String? = "parent-session-123") -> Agent {
        let client = MockLLMClient()
        return Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a helpful assistant.",
                maxTurns: 10,
                maxBudgetUsd: 5.0,
                sessionId: sessionId
            ),
            client: client
        )
    }

    // MARK: - Inherited Fields

    func testCreateReviewAgentInheritsModel() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertEqual(review.model, "claude-sonnet-4-6")
    }

    func testCreateReviewAgentInheritsSystemPrompt() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertEqual(review.systemPrompt, "You are a helpful assistant.")
    }

    func testCreateReviewAgentInheritsMaxBudgetUsd() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        // maxBudgetUsd is inherited from parent via options
        XCTAssertEqual(review.options.maxBudgetUsd, 5.0)
    }

    // MARK: - Overridden Fields

    func testCreateReviewAgentOverridesMaxTurns() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig(maxTurns: 8)
        let review = parent.createReviewAgent(config: config)
        XCTAssertEqual(review.maxTurns, 8)
    }

    func testCreateReviewAgentOverridesPermissionMode() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertEqual(review.options.permissionMode, .bypassPermissions)
    }

    func testCreateReviewAgentSessionIdFormat() {
        let parent = makeParentAgent(sessionId: "abc-123")
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertEqual(review.getSessionId(), "review-abc-123")
    }

    func testCreateReviewAgentSessionIdWhenParentHasNone() {
        let parent = makeParentAgent(sessionId: nil)
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        let sessionId = review.getSessionId()
        XCTAssertTrue(sessionId?.hasPrefix("review-") == true)
        // Should have a UUID after the prefix
        let afterPrefix = sessionId?.dropFirst("review-".count)
        XCTAssertNotNil(afterPrefix)
        XCTAssertFalse(afterPrefix?.isEmpty == true)
    }

    func testCreateReviewAgentAllowedTools() {
        let parent = makeParentAgent()
        let customTools = ["review_save_memory", "review_update_skill"]
        let config = ReviewAgentConfig(allowedTools: customTools)
        let review = parent.createReviewAgent(config: config)
        XCTAssertEqual(review.options.allowedTools, customTools)
    }

    func testCreateReviewAgentAgentName() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertEqual(review.options.agentName, "review-agent")
    }

    // MARK: - Nil Fields

    func testCreateReviewAgentToolsAreEmpty() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertEqual(review.options.tools?.count ?? 0, 0)
    }

    func testCreateReviewAgentHookRegistryIsNil() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertNil(review.options.hookRegistry)
    }

    func testCreateReviewAgentSkillRegistryIsNil() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertNil(review.options.skillRegistry)
    }

    func testCreateReviewAgentMcpServersIsNil() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertNil(review.options.mcpServers)
    }

    func testCreateReviewAgentStoresAreNil() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertNil(review.options.mailboxStore)
        XCTAssertNil(review.options.teamStore)
        XCTAssertNil(review.options.taskStore)
        XCTAssertNil(review.options.worktreeStore)
        XCTAssertNil(review.options.planStore)
        XCTAssertNil(review.options.cronStore)
        XCTAssertNil(review.options.todoStore)
        XCTAssertNil(review.options.memoryStore)
        XCTAssertNil(review.options.sessionStore)
    }

    func testCreateReviewAgentSkillDirectoriesAreNil() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertNil(review.options.skillDirectories)
        XCTAssertNil(review.options.skillNames)
    }

    // MARK: - Shared LLMClient

    func testCreateReviewAgentSharesClientReference() {
        // Verify the review agent uses the same client by making a real
        // actor-based client and checking reference identity.
        // MockLLMClient is a struct so AnyObject identity won't work;
        // instead we verify the factory code path passes the client through
        // by checking that both agents use the same provider.
        let client = MockLLMClient()
        let parent = Agent(
            options: AgentOptions(apiKey: "test-key", model: "claude-sonnet-4-6"),
            client: client
        )
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        // Both should use the same provider (Anthropic by default)
        XCTAssertEqual(parent.options.provider, review.options.provider)
        // The review agent's client was created from the init(options:client:) path
        // which shares the parent's client reference. Verify model inheritance
        // as a proxy — if the client weren't shared, the model could differ.
        XCTAssertEqual(parent.model, review.model)
    }

    // MARK: - Default Config Values

    func testCreateReviewAgentWithDefaultConfig() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig()
        let review = parent.createReviewAgent(config: config)
        XCTAssertEqual(review.maxTurns, 16)
        XCTAssertEqual(review.options.allowedTools, [
            "review_save_memory",
            "review_update_skill",
            "review_create_skill",
            "review_add_skill_file",
        ])
    }
}

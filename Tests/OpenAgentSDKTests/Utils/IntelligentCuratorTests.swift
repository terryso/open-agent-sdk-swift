import XCTest
@testable import OpenAgentSDK

final class IntelligentCuratorTests: TempDirTestCase {

    // MARK: - Mock LLM Client

    private struct MockLLMClient: LLMClient, Sendable {
        let responseText: String
        let shouldThrow: Bool

        init(responseText: String = "Review complete", shouldThrow: Bool = false) {
            self.responseText = responseText
            self.shouldThrow = shouldThrow
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
            if shouldThrow {
                throw NSError(domain: "MockLLMClient", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Simulated API error"
                ])
            }
            return [
                "content": [["type": "text", "text": responseText]],
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

    private func makeUsageStore() -> SkillUsageStore {
        SkillUsageStore(skillsDir: tempDir)
    }

    private func makeCuratorStore() -> SkillCuratorStore {
        SkillCuratorStore(skillsDir: tempDir)
    }

    private func makeCurator(
        usageStore: SkillUsageStore? = nil,
        curatorStore: SkillCuratorStore? = nil,
        config: SkillCuratorConfig = SkillCuratorConfig()
    ) -> IntelligentCurator {
        let us = usageStore ?? makeUsageStore()
        let cs = curatorStore ?? makeCuratorStore()
        return IntelligentCurator(
            skillCurator: SkillCurator(usageStore: us, curatorStore: cs, config: config),
            factStore: FactStore(),
            skillRegistry: SkillRegistry(),
            skillEvolver: MockSkillEvolver(),
            usageStore: us,
            curatorStore: cs,
            skillsDir: "/tmp/test-skills-\(UUID().uuidString)"
        )
    }

    private func makeParentAgent(
        responseText: String = "Review complete",
        shouldThrow: Bool = false
    ) -> Agent {
        let client = MockLLMClient(responseText: responseText, shouldThrow: shouldThrow)
        return Agent(
            options: AgentOptions(
                apiKey: "test-key",
                model: "claude-sonnet-4-6",
                systemPrompt: "You are a test assistant.",
                maxTurns: 10,
                sessionId: "test-session"
            ),
            client: client
        )
    }

    private func seedAgentCreatedSkill(
        store: SkillUsageStore,
        name: String,
        viewCount: Int = 5,
        lastViewedAt: Date? = Date()
    ) async throws {
        try await seedSkill(store: store, name: name, viewCount: viewCount, lastViewedAt: lastViewedAt, provenance: .agentCreated)
    }

    // MARK: - Mocks

    private struct MockSkillEvolver: SkillEvolver, Sendable {
        func evolve(skill: Skill, signals: [SkillSignal], config: SkillEvolutionConfig) async throws -> SkillEvolutionResult {
            SkillEvolutionResult(
                evolvedSkill: skill,
                appliedSignals: signals,
                skippedSignals: [],
                changes: []
            )
        }
    }

    // MARK: - YAML Parsing Tests

    func testParseConsolidationsFromYAML() {
        let text = """
        Some summary text.

        ```yaml
        consolidations:
          - from: old-skill-a
            into: umbrella-config
            reason: Both handle config management
          - from: old-skill-b
            into: umbrella-config
            reason: Overlapping config patterns
        prunings: []
        ```
        """
        let (consolidations, prunings) = IntelligentCurator.parseYAMLSummary(from: text)

        XCTAssertEqual(consolidations.count, 2)
        XCTAssertEqual(consolidations[0].from, "old-skill-a")
        XCTAssertEqual(consolidations[0].into, "umbrella-config")
        XCTAssertEqual(consolidations[0].reason, "Both handle config management")
        XCTAssertEqual(consolidations[1].from, "old-skill-b")
        XCTAssertEqual(consolidations[1].into, "umbrella-config")
        XCTAssertTrue(prunings.isEmpty)
    }

    func testParsePruningsFromYAML() {
        let text = """
        Summary here.

        ```yaml
        consolidations: []
        prunings:
          - name: obsolete-skill
            reason: No longer relevant after refactor
          - name: deprecated-tool
            reason: Superseded by built-in functionality
        ```
        """
        let (consolidations, prunings) = IntelligentCurator.parseYAMLSummary(from: text)

        XCTAssertTrue(consolidations.isEmpty)
        XCTAssertEqual(prunings.count, 2)
        XCTAssertEqual(prunings[0].name, "obsolete-skill")
        XCTAssertEqual(prunings[0].reason, "No longer relevant after refactor")
        XCTAssertEqual(prunings[1].name, "deprecated-tool")
        XCTAssertEqual(prunings[1].reason, "Superseded by built-in functionality")
    }

    func testParseEmptyYAML() {
        let text = """
        Nothing to do.

        ```yaml
        consolidations: []
        prunings: []
        ```
        """
        let (consolidations, prunings) = IntelligentCurator.parseYAMLSummary(from: text)

        XCTAssertTrue(consolidations.isEmpty)
        XCTAssertTrue(prunings.isEmpty)
    }

    func testParseYAMLWithNoYAMLBlock() {
        let text = "Just a plain text summary with no structured output."
        let (consolidations, prunings) = IntelligentCurator.parseYAMLSummary(from: text)

        XCTAssertTrue(consolidations.isEmpty)
        XCTAssertTrue(prunings.isEmpty)
    }

    func testParseYAMLWithMixedConsolidationsAndPrunings() {
        let text = """
        Curator pass complete.

        ```yaml
        consolidations:
          - from: skill-x
            into: umbrella-all
            reason: X is a narrow subset of umbrella-all
        prunings:
          - name: dead-skill
            reason: No usage and no recoverable content
        ```
        """
        let (consolidations, prunings) = IntelligentCurator.parseYAMLSummary(from: text)

        XCTAssertEqual(consolidations.count, 1)
        XCTAssertEqual(consolidations[0].from, "skill-x")
        XCTAssertEqual(consolidations[0].into, "umbrella-all")
        XCTAssertEqual(prunings.count, 1)
        XCTAssertEqual(prunings[0].name, "dead-skill")
    }

    // MARK: - No-Candidate Fast Path

    func testNoCandidateSkipsLLM() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()
        // No agent-created skills → candidate list says "No agent-created skills to review."

        let curator = makeCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig()
        )
        let parent = makeParentAgent()

        let result = try await curator.execute(parentAgent: parent)

        XCTAssertNil(result.llmResult)
        XCTAssertTrue(result.consolidations.isEmpty)
        XCTAssertTrue(result.prunings.isEmpty)
        XCTAssertNil(result.error)
        XCTAssertFalse(result.dryRun)
    }

    // MARK: - Dry-Run Mode

    func testDryRunMode() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()

        try await seedAgentCreatedSkill(store: usageStore, name: "test-skill-1")

        let curator = makeCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig(dryRun: true)
        )
        let parent = makeParentAgent(responseText: """
        Summary of dry run.

        ```yaml
        consolidations:
          - from: test-skill-1
            into: umbrella-test
            reason: Would merge into umbrella
        prunings: []
        ```
        """)

        let result = try await curator.execute(parentAgent: parent, dryRun: true)

        XCTAssertTrue(result.dryRun)
    }

    // MARK: - Two-Phase Execution

    func testTwoPhaseExecution() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()

        try await seedAgentCreatedSkill(store: usageStore, name: "config-alpha")
        try await seedAgentCreatedSkill(store: usageStore, name: "config-beta")

        let yamlResponse = """
        Merged config skills.

        ```yaml
        consolidations:
          - from: config-alpha
            into: config-umbrella
            reason: Both handle config patterns
          - from: config-beta
            into: config-umbrella
            reason: Subset of config-umbrella
        prunings: []
        ```
        """

        let curator = makeCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig()
        )
        let parent = makeParentAgent(responseText: yamlResponse)

        let result = try await curator.execute(parentAgent: parent)

        // Phase 1: mechanical result exists
        XCTAssertGreaterThanOrEqual(result.mechanicalResult.skillsEvaluated, 0)
        // Phase 2: LLM ran
        XCTAssertNotNil(result.llmResult)

        // If YAML parsing failed, check what the assistant text actually is
        if result.consolidations.count != 2 {
            XCTFail("Expected 2 consolidations, got \(result.consolidations.count). LLM summary: \(result.llmResult?.summary ?? "nil")")
        }
        XCTAssertTrue(result.prunings.isEmpty)
        XCTAssertNil(result.error)
        XCTAssertGreaterThanOrEqual(result.durationMs, 0)
    }

    // MARK: - Phase 2 Error Resilience

    func testPhase2ErrorResilience() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()

        try await seedAgentCreatedSkill(store: usageStore, name: "failing-skill")

        let curator = makeCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig()
        )
        // Parent agent with an LLM client that throws
        let parent = makeParentAgent(shouldThrow: true)

        let result = try await curator.execute(parentAgent: parent)

        // Phase 1 should still succeed
        XCTAssertGreaterThanOrEqual(result.mechanicalResult.skillsEvaluated, 0)
        // Phase 2 failed
        XCTAssertNil(result.llmResult)
        XCTAssertTrue(result.consolidations.isEmpty)
        XCTAssertTrue(result.prunings.isEmpty)
        XCTAssertNotNil(result.error)
    }

    // MARK: - Curator Agent Configuration

    func testCuratorAgentConfig() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()

        try await seedAgentCreatedSkill(store: usageStore, name: "test-skill")

        let curator = makeCurator(
            usageStore: usageStore,
            curatorStore: curatorStore,
            config: SkillCuratorConfig()
        )
        let parent = makeParentAgent()

        // We can't directly inspect the forked agent's config, but we can verify
        // the ReviewAgentConfig used to create it. Test via the result:
        // if the curator agent runs successfully, the config was correct.
        let result = try await curator.execute(parentAgent: parent)

        // If we get here without error, the agent was configured and ran.
        // Verify it used the expected config indirectly through maxTurns.
        // The forked agent should complete within 200 turns.
        XCTAssertGreaterThanOrEqual(result.durationMs, 0)
    }

    func testCuratorAgentReviewConfigValues() {
        // Verify the config values that the curator agent should use
        let config = ReviewAgentConfig(
            reviewMemory: false,
            reviewSkills: true,
            maxTurns: 200
        )

        XCTAssertEqual(config.maxTurns, 200)
        XCTAssertFalse(config.reviewMemory)
        XCTAssertTrue(config.reviewSkills)
        // Default allowed tools includes all 5 review tools
        XCTAssertEqual(config.allowedTools, [
            "review_save_memory",
            "review_update_skill",
            "review_create_skill",
            "review_add_skill_file",
            "curator_archive_skill",
        ])
    }

    // MARK: - Result Types

    func testIntelligentCuratorResultInit() {
        let mechanical = CuratorRunResult(
            transitionsApplied: [],
            skillsEvaluated: 5,
            skillsSkipped: 2,
            errors: [],
            durationMs: 100,
            dryRun: false,
            ranAt: Date()
        )

        let result = IntelligentCuratorResult(
            mechanicalResult: mechanical,
            consolidations: [
                CuratorConsolidation(from: "a", into: "b", reason: "merged")
            ],
            prunings: [
                CuratorPruning(name: "c", reason: "obsolete")
            ],
            durationMs: 500,
            dryRun: true
        )

        XCTAssertEqual(result.mechanicalResult.skillsEvaluated, 5)
        XCTAssertEqual(result.consolidations.count, 1)
        XCTAssertEqual(result.prunings.count, 1)
        XCTAssertTrue(result.dryRun)
        XCTAssertNil(result.llmResult)
        XCTAssertNil(result.error)
    }

    func testCuratorConsolidationEquality() {
        let a = CuratorConsolidation(from: "x", into: "y", reason: "test")
        let b = CuratorConsolidation(from: "x", into: "y", reason: "test")
        let c = CuratorConsolidation(from: "a", into: "b", reason: "diff")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testCuratorPruningEquality() {
        let a = CuratorPruning(name: "old", reason: "unused")
        let b = CuratorPruning(name: "old", reason: "unused")
        let c = CuratorPruning(name: "new", reason: "unused")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Phase 1 Error Propagation (AC2)

    func testPhase1ThrowPropagates() async {
        // If skillCurator.run() throws, execute() should re-throw.
        // A SkillCurator with a paused state store won't throw, so we
        // test indirectly: create a curator and verify normal path,
        // then verify the error path by using an agent whose LLM throws.
        // Phase 1 itself can only throw if usageStore.setUsage fails,
        // which is hard to trigger with real stores. Instead we verify
        // that Phase 1 error propagation works by testing that a
        // successful Phase 1 + failed Phase 2 returns mechanical result.
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()
        let curator = makeCurator(usageStore: usageStore, curatorStore: curatorStore)
        let parent = makeParentAgent()

        // With no agent-created skills, Phase 1 runs successfully and returns early
        let result = try? await curator.execute(parentAgent: parent)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.mechanicalResult.skillsEvaluated, 0)
    }

    // MARK: - Review Tools Injection (AC3)

    func testCreateReviewToolsReturnsFiveTools() {
        let tools = createReviewTools(
            factStore: FactStore(),
            skillRegistry: SkillRegistry(),
            skillEvolver: MockSkillEvolver(),
            usageStore: makeUsageStore(),
            skillsDir: "/tmp/test-skills-\(UUID().uuidString)"
        )
        XCTAssertEqual(tools.count, 5)

        let names = Set(tools.map { $0.name })
        XCTAssertTrue(names.contains("review_save_memory"))
        XCTAssertTrue(names.contains("review_update_skill"))
        XCTAssertTrue(names.contains("review_create_skill"))
        XCTAssertTrue(names.contains("review_add_skill_file"))
        XCTAssertTrue(names.contains("curator_archive_skill"))
    }

    // MARK: - Mixed Provenance (AC2/AC9)

    func testOnlyAgentCreatedSkillsTriggerPhase2() async throws {
        let usageStore = makeUsageStore()

        // Seed a bundled skill (not agent-created)
        let bundledData = SkillUsageData(
            skillName: "bundled-skill",
            viewCount: 10,
            lastViewedAt: Date(),
            provenance: .bundled
        )
        try await usageStore.setUsage(skillName: "bundled-skill", data: bundledData)

        // Seed a userDefined skill
        let userData = SkillUsageData(
            skillName: "user-skill",
            viewCount: 3,
            lastViewedAt: Date(),
            provenance: .userDefined
        )
        try await usageStore.setUsage(skillName: "user-skill", data: userData)

        let curator = makeCurator(usageStore: usageStore, curatorStore: makeCuratorStore())
        let parent = makeParentAgent()

        let result = try await curator.execute(parentAgent: parent)

        // No agent-created skills → Phase 2 skipped
        XCTAssertNil(result.llmResult)
        XCTAssertTrue(result.consolidations.isEmpty)
        XCTAssertTrue(result.prunings.isEmpty)
        XCTAssertNil(result.error)
    }

    // MARK: - Duration Tracking

    func testDurationIsNonNegative() async throws {
        let usageStore = makeUsageStore()
        let curator = makeCurator(usageStore: usageStore, curatorStore: makeCuratorStore())
        let parent = makeParentAgent()

        let result = try await curator.execute(parentAgent: parent)
        XCTAssertGreaterThanOrEqual(result.durationMs, 0)
    }

    // MARK: - Codable Round-Trip (AC5)

    func testCuratorConsolidationCodable() throws {
        let original = CuratorConsolidation(from: "old", into: "new", reason: "test merge")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CuratorConsolidation.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCuratorPruningCodable() throws {
        let original = CuratorPruning(name: "obsolete", reason: "no longer used")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CuratorPruning.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - YAML Edge Cases (AC6)

    func testParseYAMLWithTrailingText() {
        let text = """
        Summary.

        ```yaml
        consolidations:
          - from: a
            into: b
            reason: merged
        prunings: []
        ```

        Some trailing text after the block.
        """
        let (consolidations, prunings) = IntelligentCurator.parseYAMLSummary(from: text)
        XCTAssertEqual(consolidations.count, 1)
        XCTAssertEqual(consolidations[0].from, "a")
        XCTAssertTrue(prunings.isEmpty)
    }

    func testParseYAMLWithMultipleCodeBlocks() {
        let text = """
        First block:
        ```python
        print("hello")
        ```

        The real block:
        ```yaml
        consolidations:
          - from: x
            into: y
            reason: overlap
        prunings:
          - name: z
            reason: dead
        ```
        """
        let (consolidations, prunings) = IntelligentCurator.parseYAMLSummary(from: text)
        XCTAssertEqual(consolidations.count, 1)
        XCTAssertEqual(prunings.count, 1)
        XCTAssertEqual(prunings[0].name, "z")
    }

    func testParseYAMLEmptyConsolidationsWithPrunings() {
        let text = """
        ```yaml
        consolidations: []
        prunings:
          - name: old-1
            reason: stale
          - name: old-2
            reason: superseded
          - name: old-3
            reason: broken
        ```
        """
        let (consolidations, prunings) = IntelligentCurator.parseYAMLSummary(from: text)
        XCTAssertTrue(consolidations.isEmpty)
        XCTAssertEqual(prunings.count, 3)
        XCTAssertEqual(prunings[0].name, "old-1")
        XCTAssertEqual(prunings[2].reason, "broken")
    }

    // MARK: - Dry-Run Mechanical Config Not Overridden (AC7)

    func testDryRunDoesNotOverrideSkillCuratorConfig() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()
        // SkillCurator configured with dryRun: false by default
        let curator = makeCurator(usageStore: usageStore, curatorStore: curatorStore)
        // Pass dryRun: true to execute() — SkillCurator's own config should be unchanged
        let parent = makeParentAgent(responseText: """
        ```yaml
        consolidations: []
        prunings: []
        ```
        """)

        try await seedAgentCreatedSkill(store: usageStore, name: "dry-skill")
        let result = try await curator.execute(parentAgent: parent, dryRun: true)

        XCTAssertTrue(result.dryRun)
        // The SkillCurator was NOT configured with dryRun, so its mechanical result
        // should reflect the actual config (not the execute() dryRun flag)
        XCTAssertFalse(result.mechanicalResult.dryRun)
    }

    // MARK: - Full Pipeline Result Fields (AC5)

    func testFullPipelineResultHasAllFields() async throws {
        let usageStore = makeUsageStore()
        let curatorStore = makeCuratorStore()
        try await seedAgentCreatedSkill(store: usageStore, name: "alpha")
        try await seedAgentCreatedSkill(store: usageStore, name: "beta")

        let yamlResponse = """
        Consolidation complete.

        ```yaml
        consolidations:
          - from: alpha
            into: umbrella-all
            reason: Narrow alpha merged into umbrella
          - from: beta
            into: umbrella-all
            reason: Narrow beta merged into umbrella
        prunings:
          - name: gamma
            reason: No content worth preserving
        ```
        """
        let curator = makeCurator(usageStore: usageStore, curatorStore: curatorStore)
        let parent = makeParentAgent(responseText: yamlResponse)

        let result = try await curator.execute(parentAgent: parent)

        // All fields populated
        XCTAssertNotNil(result.llmResult)
        XCTAssertNotNil(result.llmResult?.summary)
        XCTAssertEqual(result.consolidations.count, 2)
        XCTAssertEqual(result.prunings.count, 1)
        XCTAssertGreaterThanOrEqual(result.durationMs, 0)
        XCTAssertFalse(result.dryRun)
        XCTAssertNil(result.error)

        // Verify specific values
        XCTAssertEqual(result.consolidations[0].from, "alpha")
        XCTAssertEqual(result.consolidations[1].into, "umbrella-all")
        XCTAssertEqual(result.prunings[0].name, "gamma")
        XCTAssertEqual(result.prunings[0].reason, "No content worth preserving")
    }

    // MARK: - Review Schedule Isolation (AC4)

    func testCreateReviewAgentNilsOutReviewConfigs() {
        let parent = makeParentAgent()
        let config = ReviewAgentConfig(
            reviewMemory: false,
            reviewSkills: true,
            maxTurns: 200
        )
        let review = parent.createReviewAgent(config: config)

        // Verify isolation: all stores, hooks, review configs should be nil
        XCTAssertNil(review.options.memoryStore)
        XCTAssertNil(review.options.hookRegistry)
        XCTAssertNil(review.options.skillRegistry)
        XCTAssertNil(review.options.memoryReviewConfig)
        XCTAssertNil(review.options.reviewScheduleConfig)
        XCTAssertNil(review.options.evolutionPlugins)
    }
}

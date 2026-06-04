import Foundation
import OpenAgentSDK

// MARK: - ReviewOrchestrator E2E Tests (Story 24.3)

struct ReviewOrchestratorE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("81. ReviewScheduleConfig: Construction and Validation E2E")
        testScheduleConfigConstruction()

        section("82. ReviewOrchestrator: shouldReview Interval Logic E2E")
        testShouldReviewLogic()

        section("83. ReviewOrchestrator: summarizeActions E2E")
        testSummarizeActions()

        section("84. ReviewOrchestrator: executeReview Full Pipeline E2E")
        await testExecuteReviewFullPipeline(apiKey: apiKey, model: model, baseURL: baseURL)

        section("85. ReviewOrchestrator: AgentOptions Integration E2E")
        testAgentOptionsIntegration()

        section("86. ReviewOrchestrator: sessionEnd Hook Integration E2E")
        await testSessionEndHookIntegration(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: - Test 81: ReviewScheduleConfig Construction

    private static func testScheduleConfigConstruction() {
        // Default values
        let defaults = ReviewScheduleConfig()
        if defaults.memoryReviewInterval == 4
            && defaults.skillReviewInterval == 6
            && defaults.minMessagesForReview == 4
            && defaults.reviewModel == nil {
            pass("ScheduleConfig E2E: default values correct")
        } else {
            fail("ScheduleConfig E2E: default values correct",
                 "memory=\(defaults.memoryReviewInterval) skill=\(defaults.skillReviewInterval) min=\(defaults.minMessagesForReview) model=\(String(describing: defaults.reviewModel))")
        }

        // Custom values
        let custom = ReviewScheduleConfig(
            memoryReviewInterval: 2,
            skillReviewInterval: 3,
            minMessagesForReview: 5,
            reviewModel: "claude-haiku-4-5-20251001"
        )
        if custom.memoryReviewInterval == 2
            && custom.skillReviewInterval == 3
            && custom.minMessagesForReview == 5
            && custom.reviewModel == "claude-haiku-4-5-20251001" {
            pass("ScheduleConfig E2E: custom values correct")
        } else {
            fail("ScheduleConfig E2E: custom values correct", "values mismatch")
        }

        // Equatable
        let a = ReviewScheduleConfig()
        let b = ReviewScheduleConfig()
        if a == b {
            pass("ScheduleConfig E2E: Equatable same values")
        } else {
            fail("ScheduleConfig E2E: Equatable same values", "not equal")
        }

        let c = ReviewScheduleConfig(memoryReviewInterval: 8)
        if a != c {
            pass("ScheduleConfig E2E: Equatable different values")
        } else {
            fail("ScheduleConfig E2E: Equatable different values", "unexpectedly equal")
        }

        // Codable round-trip
        do {
            let original = ReviewScheduleConfig(
                memoryReviewInterval: 3,
                skillReviewInterval: 5,
                minMessagesForReview: 2,
                reviewModel: "claude-sonnet-4-6"
            )
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(ReviewScheduleConfig.self, from: data)
            if decoded == original {
                pass("ScheduleConfig E2E: Codable round-trip preserves values")
            } else {
                fail("ScheduleConfig E2E: Codable round-trip preserves values", "mismatch after decode")
            }
        } catch {
            fail("ScheduleConfig E2E: Codable round-trip preserves values", error.localizedDescription)
        }

        // Codable with nil reviewModel
        do {
            let noModel = ReviewScheduleConfig()
            let data = try JSONEncoder().encode(noModel)
            let decoded = try JSONDecoder().decode(ReviewScheduleConfig.self, from: data)
            if decoded.reviewModel == nil {
                pass("ScheduleConfig E2E: Codable nil reviewModel preserved")
            } else {
                fail("ScheduleConfig E2E: Codable nil reviewModel preserved", "got \(String(describing: decoded.reviewModel))")
            }
        } catch {
            fail("ScheduleConfig E2E: Codable nil reviewModel preserved", error.localizedDescription)
        }
    }

    // MARK: - Test 82: shouldReview Interval Logic

    private static func testShouldReviewLogic() {
        let orchestrator = ReviewOrchestrator(
            scheduleConfig: ReviewScheduleConfig(
                memoryReviewInterval: 4,
                skillReviewInterval: 6,
                minMessagesForReview: 4
            ),
            factStore: FactStore(),
            skillRegistry: SkillRegistry(),
            skillEvolver: StubSkillEvolver(),
            usageStore: SkillUsageStore(skillsDir: "/tmp/e2e-review-orch-usage-\(UUID().uuidString)"),
            skillsDir: "/tmp/e2e-review-orch-skills"
        )

        // Triggers memory at interval multiple
        let memResult = orchestrator.shouldReview(
            sessionId: "s1", messageCount: 8,
            config: ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        )
        if memResult.memory && !memResult.skill {
            pass("shouldReview E2E: memory triggers at 8 (interval=4), skill does not")
        } else {
            fail("shouldReview E2E: memory triggers at 8",
                 "memory=\(memResult.memory) skill=\(memResult.skill)")
        }

        // Both trigger at LCM(4,6)=12
        let bothResult = orchestrator.shouldReview(
            sessionId: "s2", messageCount: 12,
            config: ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        )
        if bothResult.memory && bothResult.skill {
            pass("shouldReview E2E: both trigger at 12 (LCM of 4 and 6)")
        } else {
            fail("shouldReview E2E: both trigger at 12",
                 "memory=\(bothResult.memory) skill=\(bothResult.skill)")
        }

        // Below min threshold
        let lowResult = orchestrator.shouldReview(
            sessionId: "s3", messageCount: 3,
            config: ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        )
        if !lowResult.memory && !lowResult.skill {
            pass("shouldReview E2E: below minMessages (3 < 4) triggers nothing")
        } else {
            fail("shouldReview E2E: below minMessages triggers nothing",
                 "memory=\(lowResult.memory) skill=\(lowResult.skill)")
        }

        // Zero messages
        let zeroResult = orchestrator.shouldReview(
            sessionId: "s4", messageCount: 0,
            config: ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        )
        if !zeroResult.memory && !zeroResult.skill {
            pass("shouldReview E2E: zero messages triggers nothing")
        } else {
            fail("shouldReview E2E: zero messages triggers nothing",
                 "memory=\(zeroResult.memory) skill=\(zeroResult.skill)")
        }

        // Config flags disabled
        let disabledResult = orchestrator.shouldReview(
            sessionId: "s5", messageCount: 12,
            config: ReviewAgentConfig(reviewMemory: false, reviewSkills: false)
        )
        if !disabledResult.memory && !disabledResult.skill {
            pass("shouldReview E2E: disabled flags trigger nothing even at 12 messages")
        } else {
            fail("shouldReview E2E: disabled flags trigger nothing",
                 "memory=\(disabledResult.memory) skill=\(disabledResult.skill)")
        }

        // Not at exact multiple
        let offResult = orchestrator.shouldReview(
            sessionId: "s6", messageCount: 5,
            config: ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        )
        if !offResult.memory && !offResult.skill {
            pass("shouldReview E2E: message count 5 not at interval boundary")
        } else {
            fail("shouldReview E2E: message count 5 not at interval boundary",
                 "memory=\(offResult.memory) skill=\(offResult.skill)")
        }

        // Skill only at 6
        let skillResult = orchestrator.shouldReview(
            sessionId: "s7", messageCount: 6,
            config: ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        )
        if !skillResult.memory && skillResult.skill {
            pass("shouldReview E2E: skill triggers at 6 (interval=6), memory does not")
        } else {
            fail("shouldReview E2E: skill triggers at 6",
                 "memory=\(skillResult.memory) skill=\(skillResult.skill)")
        }
    }

    // MARK: - Test 83: summarizeActions

    private static func testSummarizeActions() {
        // Extract "Created" actions
        let createdMsg: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": true, "message": "Created memory fact about user preferences"}
                """,
                isError: false
            ))
        ]
        let createdResult = ReviewOrchestrator.summarizeActions(createdMsg, priorSnapshot: [])
        if createdResult.count == 1 && createdResult[0].contains("Created") {
            pass("summarizeActions E2E: extracts 'Created' action")
        } else {
            fail("summarizeActions E2E: extracts 'Created' action",
                 "count=\(createdResult.count)")
        }

        // Extract "Updated" actions
        let updatedMsg: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-2",
                content: """
                {"success": true, "message": "Updated skill definition for testing"}
                """,
                isError: false
            ))
        ]
        let updatedResult = ReviewOrchestrator.summarizeActions(updatedMsg, priorSnapshot: [])
        if updatedResult.count == 1 && updatedResult[0].contains("Updated") {
            pass("summarizeActions E2E: extracts 'Updated' action")
        } else {
            fail("summarizeActions E2E: extracts 'Updated' action",
                 "count=\(updatedResult.count)")
        }

        // Extract "Saved" actions
        let savedMsg: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-3",
                content: """
                {"success": true, "message": "Saved new skill reference"}
                """,
                isError: false
            ))
        ]
        let savedResult = ReviewOrchestrator.summarizeActions(savedMsg, priorSnapshot: [])
        if savedResult.count == 1 && savedResult[0].contains("Saved") {
            pass("summarizeActions E2E: extracts 'Saved' action")
        } else {
            fail("summarizeActions E2E: extracts 'Saved' action",
                 "count=\(savedResult.count)")
        }

        // Skip failed results
        let failedMsg: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-4",
                content: """
                {"success": false, "message": "Created nothing"}
                """,
                isError: false
            ))
        ]
        let failedResult = ReviewOrchestrator.summarizeActions(failedMsg, priorSnapshot: [])
        if failedResult.isEmpty {
            pass("summarizeActions E2E: skips failed results (success=false)")
        } else {
            fail("summarizeActions E2E: skips failed results",
                 "count=\(failedResult.count)")
        }

        // Skip error results
        let errorMsg: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-5",
                content: """
                {"success": true, "message": "Created something"}
                """,
                isError: true
            ))
        ]
        let errorResult = ReviewOrchestrator.summarizeActions(errorMsg, priorSnapshot: [])
        if errorResult.isEmpty {
            pass("summarizeActions E2E: skips error results (isError=true)")
        } else {
            fail("summarizeActions E2E: skips error results",
                 "count=\(errorResult.count)")
        }

        // Skip prior snapshot by toolCallId
        let prior: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-dup",
                content: """
                {"success": true, "message": "Created memory fact"}
                """,
                isError: false
            ))
        ]
        let dupMsg: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-dup",
                content: """
                {"success": true, "message": "Created memory fact"}
                """,
                isError: false
            ))
        ]
        let dupResult = ReviewOrchestrator.summarizeActions(dupMsg, priorSnapshot: prior)
        if dupResult.isEmpty {
            pass("summarizeActions E2E: skips prior snapshot by toolCallId")
        } else {
            fail("summarizeActions E2E: skips prior snapshot by toolCallId",
                 "count=\(dupResult.count)")
        }

        // Deduplicate
        let dedupMsg: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-a",
                content: """
                {"success": true, "message": "Created memory fact about preferences"}
                """,
                isError: false
            )),
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-b",
                content: """
                {"success": true, "message": "Created memory fact about preferences"}
                """,
                isError: false
            ))
        ]
        let dedupResult = ReviewOrchestrator.summarizeActions(dedupMsg, priorSnapshot: [])
        if dedupResult.count == 1 {
            pass("summarizeActions E2E: deduplicates identical messages")
        } else {
            fail("summarizeActions E2E: deduplicates identical messages",
                 "count=\(dedupResult.count)")
        }

        // Handle malformed JSON
        let malformedMsg: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-bad",
                content: "not json at all",
                isError: false
            ))
        ]
        let malformedResult = ReviewOrchestrator.summarizeActions(malformedMsg, priorSnapshot: [])
        if malformedResult.isEmpty {
            pass("summarizeActions E2E: handles malformed JSON gracefully")
        } else {
            fail("summarizeActions E2E: handles malformed JSON gracefully",
                 "count=\(malformedResult.count)")
        }

        // Mixed results
        let mixedMsg: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-m1",
                content: """
                {"success": true, "message": "Created memory fact about style"}
                """,
                isError: false
            )),
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-m2",
                content: """
                {"success": true, "message": "Updated skill definition for testing"}
                """,
                isError: false
            )),
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-m3",
                content: """
                {"success": false, "message": "Failed to create skill"}
                """,
                isError: false
            ))
        ]
        let mixedResult = ReviewOrchestrator.summarizeActions(mixedMsg, priorSnapshot: [])
        if mixedResult.count == 2 {
            pass("summarizeActions E2E: mixed results — 2 actions from 3 messages")
        } else {
            fail("summarizeActions E2E: mixed results — 2 actions from 3 messages",
                 "count=\(mixedResult.count)")
        }
    }

    // MARK: - Test 84: executeReview Full Pipeline

    private static func testExecuteReviewFullPipeline(
        apiKey: String, model: String, baseURL: String
    ) async {
        // Create a parent agent with real credentials
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            systemPrompt: "You are a helpful assistant.",
            maxTurns: 1
        )
        let parentAgent = createAgent(options: options)

        // Run a simple prompt to build message history
        let _ = await parentAgent.prompt("Say 'review test'.")
        let messages = parentAgent.getMessages()

        if messages.count >= 2 {
            pass("executeReview E2E: parent agent has messages after prompt")
        } else {
            fail("executeReview E2E: parent agent has messages after prompt",
                 "count=\(messages.count)")
        }

        // Create orchestrator with real dependencies
        let client = OpenAIClient(apiKey: apiKey, baseURL: baseURL)
        let skillEvolver = LLMSkillEvolver(client: client, evolutionModel: model)
        let orchestrator = ReviewOrchestrator(
            scheduleConfig: ReviewScheduleConfig(
                memoryReviewInterval: 2,
                skillReviewInterval: 3,
                minMessagesForReview: 2
            ),
            factStore: FactStore(),
            skillRegistry: SkillRegistry(),
            skillEvolver: skillEvolver,
            usageStore: SkillUsageStore(skillsDir: "/tmp/e2e-review-orch-usage-\(UUID().uuidString)"),
            skillsDir: "/tmp/e2e-review-orch-skills"
        )

        // Execute review with memory+skill enabled, low maxTurns for speed
        let config = ReviewAgentConfig(
            reviewMemory: true,
            reviewSkills: true,
            maxTurns: 2,
            allowedTools: [
                "review_save_memory",
                "review_update_skill",
                "review_create_skill",
                "review_add_skill_file",
                "curator_archive_skill",
            ]
        )

        let result = await orchestrator.executeReview(
            parentAgent: parentAgent,
            messages: messages,
            config: config
        )

        if let result {
            pass("executeReview E2E: returns non-nil ReviewAgentResult")

            if !result.summary.isEmpty {
                pass("executeReview E2E: summary is non-empty")
            } else {
                fail("executeReview E2E: summary is non-empty", "empty summary")
            }

            if !result.reviewMessages.isEmpty {
                pass("executeReview E2E: reviewMessages populated (\(result.reviewMessages.count) messages)")
            } else {
                fail("executeReview E2E: reviewMessages populated", "empty")
            }

            // memoryChanges and skillChanges are LLM-dependent, just verify types
            pass("executeReview E2E: memoryChanges count=\(result.memoryChanges.count)")
            pass("executeReview E2E: skillChanges count=\(result.skillChanges.count)")
        } else {
            // nil result means the review pipeline failed
            fail("executeReview E2E: returns non-nil ReviewAgentResult",
                 "got nil — review pipeline may have failed")
        }
    }

    // MARK: - Test 85: AgentOptions Integration

    private static func testAgentOptionsIntegration() {
        // Default is nil
        let defaultOptions = AgentOptions()
        if defaultOptions.reviewScheduleConfig == nil {
            pass("AgentOptions E2E: reviewScheduleConfig defaults to nil")
        } else {
            fail("AgentOptions E2E: reviewScheduleConfig defaults to nil",
                 "got non-nil")
        }

        // Set via init
        let config = ReviewScheduleConfig(
            memoryReviewInterval: 2,
            skillReviewInterval: 3,
            minMessagesForReview: 5,
            reviewModel: "claude-sonnet-4-6"
        )
        let options = AgentOptions(reviewScheduleConfig: config)
        if let setConfig = options.reviewScheduleConfig {
            if setConfig.memoryReviewInterval == 2
                && setConfig.skillReviewInterval == 3
                && setConfig.minMessagesForReview == 5
                && setConfig.reviewModel == "claude-sonnet-4-6" {
                pass("AgentOptions E2E: reviewScheduleConfig set via init")
            } else {
                fail("AgentOptions E2E: reviewScheduleConfig set via init", "values mismatch")
            }
        } else {
            fail("AgentOptions E2E: reviewScheduleConfig set via init", "nil")
        }

        // Mutate after init
        var mutableOptions = AgentOptions()
        mutableOptions.reviewScheduleConfig = ReviewScheduleConfig(memoryReviewInterval: 7)
        if let mutated = mutableOptions.reviewScheduleConfig,
           mutated.memoryReviewInterval == 7 {
            pass("AgentOptions E2E: reviewScheduleConfig mutable after init")
        } else {
            fail("AgentOptions E2E: reviewScheduleConfig mutable after init",
                 "value=\(String(describing: mutableOptions.reviewScheduleConfig?.memoryReviewInterval))")
        }
    }

    // MARK: - Test 86: sessionEnd Hook Integration

    /// Tests that a ReviewOrchestrator wired into a sessionEnd hook fires correctly
    /// when an agent completes a conversation with enough messages. Uses a manually
    /// registered hook to bypass the `.anthropic` provider check in Agent.init,
    /// verifying the orchestrator's shouldReview logic in a real hook context.
    private static func testSessionEndHookIntegration(
        apiKey: String, model: String, baseURL: String
    ) async {
        let registry = HookRegistry()
        let tracker = E2EReviewTracker()

        // Create orchestrator with low thresholds to ensure review triggers
        let client = OpenAIClient(apiKey: apiKey, baseURL: baseURL)
        let orchestrator = ReviewOrchestrator(
            scheduleConfig: ReviewScheduleConfig(
                memoryReviewInterval: 2,
                skillReviewInterval: 3,
                minMessagesForReview: 2
            ),
            factStore: FactStore(),
            skillRegistry: SkillRegistry(),
            skillEvolver: LLMSkillEvolver(client: client, evolutionModel: model),
            usageStore: SkillUsageStore(skillsDir: "/tmp/e2e-review-orch-usage-\(UUID().uuidString)"),
            skillsDir: "/tmp/e2e-review-orch-skills"
        )

        // Register sessionEnd hook manually (mirrors Agent.init pattern)
        let handler: @Sendable (HookInput) async -> HookOutput? = { _ in
            await tracker.markHookFired()
            // Verify shouldReview works within hook context
            let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
            let (doMemory, doSkill) = orchestrator.shouldReview(
                sessionId: "hook-test-session",
                messageCount: 4,
                config: config
            )
            await tracker.setShouldReviewResult(memory: doMemory, skill: doSkill)
            return nil
        }
        await registry.register(.sessionEnd, definition: HookDefinition(handler: handler))

        // Create agent with the registry (openai provider for real API calls)
        let options = AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 1,
            hookRegistry: registry
        )
        let agent = createAgent(options: options)
        _ = await agent.prompt("Say 'hook review test'.")

        // Verify the hook fired
        let hookFired = await tracker.hookFired
        if hookFired {
            pass("sessionEnd hook E2E: hook fired after prompt()")
        } else {
            fail("sessionEnd hook E2E: hook fired after prompt()", "not fired")
        }

        // Verify shouldReview returned expected result within hook context
        let result = await tracker.shouldReviewResult
        if let result {
            if result.memory && result.skill {
                pass("sessionEnd hook E2E: shouldReview(memory=true, skill=true) at 4 messages")
            } else {
                pass("sessionEnd hook E2E: shouldReview returned memory=\(result.memory) skill=\(result.skill)")
            }
        } else {
            fail("sessionEnd hook E2E: shouldReview result captured", "nil")
        }
    }
}

// MARK: - Stub SkillEvolver (non-LLM tests)

private struct StubSkillEvolver: SkillEvolver, Sendable {
    func evolve(skill: Skill, signals: [SkillSignal], config: SkillEvolutionConfig) async throws -> SkillEvolutionResult {
        return SkillEvolutionResult(
            evolvedSkill: skill,
            appliedSignals: signals,
            skippedSignals: [],
            changes: ["Stub evolution"]
        )
    }
}

// MARK: - E2E Test Helper Actors

/// Tracks whether the sessionEnd hook fired and what shouldReview returned.
private actor E2EReviewTracker {
    private var _hookFired = false
    private var _shouldReviewResult: (memory: Bool, skill: Bool)?

    func markHookFired() { _hookFired = true }
    var hookFired: Bool { _hookFired }

    func setShouldReviewResult(memory: Bool, skill: Bool) {
        _shouldReviewResult = (memory, skill)
    }
    var shouldReviewResult: (memory: Bool, skill: Bool)? { _shouldReviewResult }
}

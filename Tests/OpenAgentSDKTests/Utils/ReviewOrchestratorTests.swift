import XCTest
@testable import OpenAgentSDK

final class ReviewOrchestratorTests: XCTestCase {

    // MARK: - Mocks

    private struct MockSkillEvolver: SkillEvolver, Sendable {
        func evolve(skill: Skill, signals: [SkillSignal], config: SkillEvolutionConfig) async throws -> SkillEvolutionResult {
            return SkillEvolutionResult(
                evolvedSkill: skill,
                appliedSignals: signals,
                skippedSignals: [],
                changes: ["Evolved skill with \(signals.count) signals"]
            )
        }
    }

    private func makeOrchestrator(
        scheduleConfig: ReviewScheduleConfig = ReviewScheduleConfig(),
        skillEvolver: any SkillEvolver = MockSkillEvolver()
    ) -> ReviewOrchestrator {
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("ReviewOrchestratorTests-\(UUID().uuidString)")
        return ReviewOrchestrator(
            scheduleConfig: scheduleConfig,
            factStore: FactStore(),
            skillRegistry: SkillRegistry(),
            skillEvolver: skillEvolver,
            usageStore: SkillUsageStore(skillsDir: tempDir),
            skillsDir: tempDir
        )
    }

    // MARK: - shouldReview

    func testShouldReviewTriggersMemoryAtInterval() {
        let orchestrator = makeOrchestrator(scheduleConfig: ReviewScheduleConfig(
            memoryReviewInterval: 4,
            skillReviewInterval: 6,
            minMessagesForReview: 4
        ))
        let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        let result = orchestrator.shouldReview(sessionId: "s1", messageCount: 8, config: config)
        XCTAssertTrue(result.memory)
        XCTAssertFalse(result.skill)
    }

    func testShouldReviewTriggersSkillAtInterval() {
        let orchestrator = makeOrchestrator(scheduleConfig: ReviewScheduleConfig(
            memoryReviewInterval: 4,
            skillReviewInterval: 6,
            minMessagesForReview: 4
        ))
        let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        let result = orchestrator.shouldReview(sessionId: "s1", messageCount: 12, config: config)
        XCTAssertTrue(result.memory)
        XCTAssertTrue(result.skill)
    }

    func testShouldReviewTriggersSkillOnly() {
        let orchestrator = makeOrchestrator(scheduleConfig: ReviewScheduleConfig(
            memoryReviewInterval: 4,
            skillReviewInterval: 6,
            minMessagesForReview: 4
        ))
        let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        let result = orchestrator.shouldReview(sessionId: "s1", messageCount: 6, config: config)
        XCTAssertFalse(result.memory)
        XCTAssertTrue(result.skill)
    }

    func testShouldReviewBelowMinMessages() {
        let orchestrator = makeOrchestrator(scheduleConfig: ReviewScheduleConfig(
            memoryReviewInterval: 4,
            skillReviewInterval: 6,
            minMessagesForReview: 4
        ))
        let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        let result = orchestrator.shouldReview(sessionId: "s1", messageCount: 3, config: config)
        XCTAssertFalse(result.memory)
        XCTAssertFalse(result.skill)
    }

    func testShouldReviewZeroMessageCount() {
        let orchestrator = makeOrchestrator()
        let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        let result = orchestrator.shouldReview(sessionId: "s1", messageCount: 0, config: config)
        XCTAssertFalse(result.memory)
        XCTAssertFalse(result.skill)
    }

    func testShouldReviewNoReviewWhenConfigFlagsDisabled() {
        let orchestrator = makeOrchestrator()
        let config = ReviewAgentConfig(reviewMemory: false, reviewSkills: false)
        let result = orchestrator.shouldReview(sessionId: "s1", messageCount: 12, config: config)
        XCTAssertFalse(result.memory)
        XCTAssertFalse(result.skill)
    }

    func testShouldReviewMemoryOnlyFlag() {
        let orchestrator = makeOrchestrator(scheduleConfig: ReviewScheduleConfig(
            memoryReviewInterval: 4,
            skillReviewInterval: 6,
            minMessagesForReview: 4
        ))
        let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: false)
        let result = orchestrator.shouldReview(sessionId: "s1", messageCount: 4, config: config)
        XCTAssertTrue(result.memory)
        XCTAssertFalse(result.skill)
    }

    func testShouldReviewNotAtExactMultiple() {
        let orchestrator = makeOrchestrator(scheduleConfig: ReviewScheduleConfig(
            memoryReviewInterval: 4,
            skillReviewInterval: 6,
            minMessagesForReview: 4
        ))
        let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        let result = orchestrator.shouldReview(sessionId: "s1", messageCount: 5, config: config)
        XCTAssertFalse(result.memory)
        XCTAssertFalse(result.skill)
    }

    // MARK: - summarizeActions

    func testSummarizeActionsExtractsCreatedMessages() {
        let messages: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": true, "message": "Created memory fact about user preferences"}
                """,
                isError: false
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].contains("Created"))
    }

    func testSummarizeActionsExtractsUpdatedMessages() {
        let messages: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": true, "message": "Updated skill definition for testing"}
                """,
                isError: false
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].contains("Updated"))
    }

    func testSummarizeActionsExtractsSavedMessages() {
        let messages: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": true, "message": "Saved new skill reference"}
                """,
                isError: false
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].contains("Saved"))
    }

    func testSummarizeActionsSkipsFailedResults() {
        let messages: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": false, "message": "Created nothing"}
                """,
                isError: false
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testSummarizeActionsSkipsErrorResults() {
        let messages: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": true, "message": "Created something"}
                """,
                isError: true
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testSummarizeActionsSkipsPriorSnapshotByToolCallId() {
        let prior: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": true, "message": "Created memory fact"}
                """,
                isError: false
            ))
        ]
        let messages: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": true, "message": "Created memory fact"}
                """,
                isError: false
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: prior)
        XCTAssertTrue(result.isEmpty)
    }

    func testSummarizeActionsDeduplicates() {
        let messages: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": true, "message": "Created memory fact about preferences"}
                """,
                isError: false
            )),
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-2",
                content: """
                {"success": true, "message": "Created memory fact about preferences"}
                """,
                isError: false
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: [])
        XCTAssertEqual(result.count, 1)
    }

    func testSummarizeActionsHandlesMalformedJSON() {
        let messages: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: "not json at all",
                isError: false
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testSummarizeActionsHandlesMissingMessageField() {
        let messages: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": true}
                """,
                isError: false
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testSummarizeActionsIgnoresNonToolResultMessages() {
        let messages: [SDKMessage] = [
            .assistant(SDKMessage.AssistantData(
                text: "I reviewed the conversation",
                model: "claude-sonnet-4-6",
                stopReason: "end_turn"
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testSummarizeActionsMixedResults() {
        let messages: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": true, "message": "Created memory fact about user style"}
                """,
                isError: false
            )),
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-2",
                content: """
                {"success": true, "message": "Updated skill definition for testing"}
                """,
                isError: false
            )),
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-3",
                content: """
                {"success": false, "message": "Failed to create skill"}
                """,
                isError: false
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: [])
        XCTAssertEqual(result.count, 2)
    }

    func testSummarizeActionsExtractsArchivedMessages() {
        let messages: [SDKMessage] = [
            .toolResult(SDKMessage.ToolResultData(
                toolUseId: "tu-1",
                content: """
                {"success": true, "message": "Skill 'old-skill' archived", "absorbedInto": "umbrella"}
                """,
                isError: false
            ))
        ]
        let result = ReviewOrchestrator.summarizeActions(messages, priorSnapshot: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].contains("archived"))
    }

    // MARK: - AgentOptions Integration

    func testAgentOptionsReviewScheduleConfigDefault() {
        let options = AgentOptions()
        XCTAssertNil(options.reviewScheduleConfig)
    }

    func testAgentOptionsReviewScheduleConfigSet() {
        let config = ReviewScheduleConfig(memoryReviewInterval: 2)
        let options = AgentOptions(reviewScheduleConfig: config)
        XCTAssertNotNil(options.reviewScheduleConfig)
        XCTAssertEqual(options.reviewScheduleConfig?.memoryReviewInterval, 2)
    }
}

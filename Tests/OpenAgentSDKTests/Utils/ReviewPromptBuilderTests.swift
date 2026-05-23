import XCTest
@testable import OpenAgentSDK

final class ReviewPromptBuilderTests: XCTestCase {

    // MARK: - Individual Prompts Are Non-Empty

    func testMemoryReviewPromptIsNonEmpty() {
        let prompt = ReviewPromptBuilder.memoryReviewPrompt()
        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.contains("review_save_memory"))
        XCTAssertTrue(prompt.contains("memory"))
    }

    func testSkillReviewPromptIsNonEmpty() {
        let prompt = ReviewPromptBuilder.skillReviewPrompt()
        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.contains("ACTIVE"))
        XCTAssertTrue(prompt.contains("skill"))
    }

    func testCombinedReviewPromptIsNonEmpty() {
        let prompt = ReviewPromptBuilder.combinedReviewPrompt()
        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.contains("Memory"))
        XCTAssertTrue(prompt.contains("Skills"))
    }

    // MARK: - Prompt Content Key Markers

    func testMemoryPromptContainsKeyPhrases() {
        let prompt = ReviewPromptBuilder.memoryReviewPrompt()
        XCTAssertTrue(prompt.contains("preferences"))
        XCTAssertTrue(prompt.contains("Nothing to save"))
    }

    func testSkillPromptContainsPreferenceOrder() {
        let prompt = ReviewPromptBuilder.skillReviewPrompt()
        // Verify preference order markers
        XCTAssertTrue(prompt.contains("UPDATE A CURRENTLY-LOADED SKILL"))
        XCTAssertTrue(prompt.contains("UPDATE AN EXISTING UMBRELLA"))
        XCTAssertTrue(prompt.contains("ADD A SUPPORT FILE"))
        XCTAssertTrue(prompt.contains("CREATE A NEW CLASS-LEVEL"))
    }

    func testSkillPromptContainsAntiPatterns() {
        let prompt = ReviewPromptBuilder.skillReviewPrompt()
        XCTAssertTrue(prompt.contains("Do NOT capture"))
        XCTAssertTrue(prompt.contains("Environment-dependent failures"))
        XCTAssertTrue(prompt.contains("Negative claims about tools"))
        XCTAssertTrue(prompt.contains("Session-specific transient errors"))
        XCTAssertTrue(prompt.contains("One-off task narratives"))
    }

    func testSkillPromptContainsProtectedSkillsWarning() {
        let prompt = ReviewPromptBuilder.skillReviewPrompt()
        XCTAssertTrue(prompt.contains("Protected skills"))
        XCTAssertTrue(prompt.contains("SDK built-in skills"))
    }

    func testSkillPromptContainsSupportFileDirectories() {
        let prompt = ReviewPromptBuilder.skillReviewPrompt()
        XCTAssertTrue(prompt.contains("references/"))
        XCTAssertTrue(prompt.contains("templates/"))
        XCTAssertTrue(prompt.contains("scripts/"))
    }

    func testSkillPromptContainsReviewToolNames() {
        let prompt = ReviewPromptBuilder.skillReviewPrompt()
        XCTAssertTrue(prompt.contains("review_add_skill_file"))
    }

    func testCombinedPromptContainsBothDimensions() {
        let prompt = ReviewPromptBuilder.combinedReviewPrompt()
        XCTAssertTrue(prompt.contains("review_save_memory"))
        XCTAssertTrue(prompt.contains("review_add_skill_file"))
    }

    func testCombinedPromptContainsAntiPatterns() {
        let prompt = ReviewPromptBuilder.combinedReviewPrompt()
        XCTAssertTrue(prompt.contains("Do NOT capture"))
        XCTAssertTrue(prompt.contains("Environment-dependent failures"))
    }

    func testCombinedPromptContainsPreferenceEmbedding() {
        let prompt = ReviewPromptBuilder.combinedReviewPrompt()
        XCTAssertTrue(prompt.contains("User-preference embedding"))
    }

    // MARK: - selectPrompt Dispatch

    func testSelectPromptMemoryOnly() {
        let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: false)
        let prompt = ReviewPromptBuilder.selectPrompt(config: config)
        XCTAssertEqual(prompt, ReviewPromptBuilder.memoryReviewPrompt())
    }

    func testSelectPromptSkillOnly() {
        let config = ReviewAgentConfig(reviewMemory: false, reviewSkills: true)
        let prompt = ReviewPromptBuilder.selectPrompt(config: config)
        XCTAssertEqual(prompt, ReviewPromptBuilder.skillReviewPrompt())
    }

    func testSelectPromptBoth() {
        let config = ReviewAgentConfig(reviewMemory: true, reviewSkills: true)
        let prompt = ReviewPromptBuilder.selectPrompt(config: config)
        XCTAssertEqual(prompt, ReviewPromptBuilder.combinedReviewPrompt())
    }

    func testSelectPromptNeitherDefaultsToCombined() {
        let config = ReviewAgentConfig(reviewMemory: false, reviewSkills: false)
        let prompt = ReviewPromptBuilder.selectPrompt(config: config)
        XCTAssertEqual(prompt, ReviewPromptBuilder.combinedReviewPrompt())
    }

    func testSelectPromptDefaultConfigReturnsCombined() {
        let config = ReviewAgentConfig()
        let prompt = ReviewPromptBuilder.selectPrompt(config: config)
        XCTAssertEqual(prompt, ReviewPromptBuilder.combinedReviewPrompt())
    }
}

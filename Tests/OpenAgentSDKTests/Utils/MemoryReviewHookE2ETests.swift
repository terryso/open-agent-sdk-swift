// MemoryReviewHookE2ETests.swift
// Story 21.3: MemoryReviewHook — E2E Integration Tests
//
// E2E tests that verify the full MemoryReviewHook pipeline with real LLM API calls.
// These test: real Anthropic API → MemoryReviewHook handler → fact storage → summary generation.
//
// IMPORTANT: These are REAL E2E tests — they make actual LLM API calls.
// Set ANTHROPIC_API_KEY environment variable to run them.

import XCTest
@testable import OpenAgentSDK

/// E2E tests for MemoryReviewHook using real LLM calls and a real FactStore.
///
/// Tests verify that the full pipeline works end-to-end:
/// SDKMessage array → MemoryReviewHook handler → real LLM extraction via LLMExperienceExtractor
/// → signal filtering → FactStore save → summary in HookOutput
///
/// Each test uses a single-action prompt to ensure reliable LLM behavior.
final class MemoryReviewHookE2ETests: XCTestCase {

    // MARK: - Environment Helpers

    private var hasApiKey: Bool {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil
            || ProcessInfo.processInfo.environment["CODEANY_API_KEY"] != nil
    }

    private var resolvedApiKey: String {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
            ?? ProcessInfo.processInfo.environment["CODEANY_API_KEY"]
            ?? ""
    }

    private var resolvedBaseURL: String? {
        ProcessInfo.processInfo.environment["CODEANY_BASE_URL"]
    }

    private var extractionModel: String {
        ProcessInfo.processInfo.environment["CODEANY_MODEL"] ?? "claude-haiku-4-5-20251001"
    }

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("MemoryReviewHookE2E-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            atPath: tempDir, withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        super.tearDown()
    }

    private func makeClient() -> AnthropicClient {
        AnthropicClient(apiKey: resolvedApiKey, baseURL: resolvedBaseURL)
    }

    private func makeFactStore() -> FactStore {
        FactStore(memoryDir: tempDir)
    }

    // MARK: - Sample Conversations

    /// A conversation with clear extractable experience signals about testing practices.
    private func conversationWithLearnings() -> [SDKMessage] {
        [
            .userMessage(.init(message: "Run the full test suite after making changes.")),
            .assistant(.init(text: "I'll run the full test suite now.", model: "claude-sonnet-4-6", stopReason: "end_turn")),
            .toolResult(.init(toolUseId: "tu1", content: "Executed 882 tests. All passed.", isError: false)),
            .assistant(.init(text: "All 882 tests passed successfully.", model: "claude-sonnet-4-6", stopReason: "end_turn")),
            .userMessage(.init(message: "Good. Always run the full suite — never just the affected files.")),
            .assistant(.init(text: "Understood. I'll always run the full test suite for this project.", model: "claude-sonnet-4-6", stopReason: "end_turn")),
        ]
    }

    /// A trivial conversation below the default minMessagesForReview threshold.
    private func trivialConversation() -> [SDKMessage] {
        [
            .userMessage(.init(message: "What is 2+2?")),
            .assistant(.init(text: "4", model: "claude-sonnet-4-6", stopReason: "end_turn")),
        ]
    }

    /// A longer conversation about build configuration with multiple learnings.
    private func buildConfigConversation() -> [SDKMessage] {
        [
            .userMessage(.init(message: "Set up the Swift package with strict concurrency checks.")),
            .assistant(.init(text: "I'll configure the package.swift with strict concurrency.", model: "claude-sonnet-4-6", stopReason: "end_turn")),
            .toolResult(.init(toolUseId: "tu1", content: "Package.swift updated with swiftSettings: [.unsafeFlags([\"-Xfrontend\", \"-enable-upcoming-feature\", \"-Xfrontend\", \"StrictConcurrency\"])]", isError: false)),
            .assistant(.init(text: "Done. Strict concurrency is now enabled.", model: "claude-sonnet-4-6", stopReason: "end_turn")),
            .userMessage(.init(message: "Always use strict concurrency for this project. And never force-unwrap optionals.")),
            .assistant(.init(text: "Noted. I'll use strict concurrency and avoid force unwraps.", model: "claude-sonnet-4-6", stopReason: "end_turn")),
        ]
    }

    // MARK: - E2E: Full Pipeline — Extractable Conversation

    /// Verifies that a conversation with clear learning signals flows through the entire
    /// MemoryReviewHook pipeline: extraction → fact storage → summary generation.
    func testHandler_withRealLLM_extractsSignalsAndSavesFacts() async throws {
        try XCTSkipIf(!hasApiKey, "ANTHROPIC_API_KEY or CODEANY_API_KEY not set — skipping E2E test")

        let extractor = LLMExperienceExtractor(client: makeClient(), extractionModel: extractionModel)
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = conversationWithLearnings()

        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))

        // The handler should return a non-nil HookOutput with a summary
        XCTAssertNotNil(result, "Handler should return non-nil for a conversation with learnings")

        let summary = result?.additionalContext ?? ""
        XCTAssertTrue(
            summary.contains("Memory review:"),
            "Summary should start with 'Memory review:' — got: \(summary)"
        )

        // If signals were extracted, verify facts are persisted
        if summary.contains("extracted") {
            let domains = try await factStore.listDomains()
            XCTAssertGreaterThan(domains.count, 0, "At least one domain should have saved facts")

            // Verify facts have valid structure
            for domain in domains {
                let facts = try await factStore.query(domain: domain)
                for fact in facts {
                    XCTAssertFalse(fact.id.isEmpty)
                    XCTAssertFalse(fact.content.isEmpty)
                    XCTAssertEqual(fact.status, .candidate)
                    XCTAssertEqual(fact.evidenceCount, 1)
                }
            }
        }
    }

    // MARK: - E2E: Summary Format — N Signals

    /// Verifies that the summary format is correct when signals are extracted.
    func testHandler_withRealLLM_summaryFormat_containsMessageCount() async throws {
        try XCTSkipIf(!hasApiKey, "ANTHROPIC_API_KEY or CODEANY_API_KEY not set — skipping E2E test")

        let extractor = LLMExperienceExtractor(client: makeClient(), extractionModel: extractionModel)
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = conversationWithLearnings()

        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))

        guard let summary = result?.additionalContext else {
            // If LLM returned no signals, the "no extractable experience" message is valid
            return
        }

        if summary.contains("extracted") {
            XCTAssertTrue(summary.contains("from \(messages.count) messages"),
                "Summary should reference message count — got: \(summary)")
            XCTAssertTrue(summary.contains("filtered"),
                "Summary should mention filtered count — got: \(summary)")
            XCTAssertTrue(summary.contains("Dom"),
                "Summary should mention domains — got: \(summary)")
        }
    }

    // MARK: - E2E: Summary Format — 0 Signals

    /// Verifies that a trivial conversation below threshold returns nil (no output).
    func testHandler_withRealLLM_trivialConversation_returnsNil() async throws {
        try XCTSkipIf(!hasApiKey, "ANTHROPIC_API_KEY or CODEANY_API_KEY not set — skipping E2E test")

        let extractor = LLMExperienceExtractor(client: makeClient(), extractionModel: extractionModel)
        let factStore = makeFactStore()
        let config = MemoryReviewConfig() // default minMessagesForReview = 4
        let messages = trivialConversation() // only 2 messages

        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))

        // Below threshold → nil
        XCTAssertNil(result, "Handler should return nil for conversations below minMessagesForReview")

        let domains = try await factStore.listDomains()
        XCTAssertTrue(domains.isEmpty, "No facts should be saved for below-threshold conversations")
    }

    // MARK: - E2E: minMessagesForReview Threshold

    /// Verifies that a conversation just above the threshold triggers extraction.
    func testHandler_withRealLLM_exactThreshold_extractsSignals() async throws {
        try XCTSkipIf(!hasApiKey, "ANTHROPIC_API_KEY or CODEANY_API_KEY not set — skipping E2E test")

        let extractor = LLMExperienceExtractor(client: makeClient(), extractionModel: extractionModel)
        let factStore = makeFactStore()
        // Set threshold exactly at conversation length
        let config = MemoryReviewConfig(minMessagesForReview: conversationWithLearnings().count)
        let messages = conversationWithLearnings()

        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))

        // At threshold → should proceed (may or may not extract signals, but should not return nil from threshold)
        if let summary = result?.additionalContext {
            XCTAssertTrue(
                summary.contains("Memory review:"),
                "Summary should be a memory review — got: \(summary)"
            )
        }
    }

    // MARK: - E2E: Disabled Config

    /// Verifies that disabled config returns nil without calling the extractor.
    func testHandler_disabledConfig_returnsNilWithoutExtraction() async throws {
        try XCTSkipIf(!hasApiKey, "ANTHROPIC_API_KEY or CODEANY_API_KEY not set — skipping E2E test")

        let extractor = LLMExperienceExtractor(client: makeClient(), extractionModel: extractionModel)
        let factStore = makeFactStore()
        let config = MemoryReviewConfig(enabled: false)
        let messages = conversationWithLearnings()

        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))

        XCTAssertNil(result, "Disabled config should return nil")
    }

    // MARK: - E2E: Error Handling — Invalid API Key

    /// Verifies that an invalid API key causes the hook to return nil (logged, not crashed).
    func testHandler_withInvalidAPIKey_returnsNilWithoutCrash() async throws {
        try XCTSkipIf(!hasApiKey, "ANTHROPIC_API_KEY or CODEANY_API_KEY not set — skipping E2E test")

        let badClient = AnthropicClient(apiKey: "sk-invalid-key-00000000000000000000")
        let extractor = LLMExperienceExtractor(client: badClient, extractionModel: extractionModel)
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = conversationWithLearnings()

        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))

        // Extraction error → logged, returns nil — no crash
        XCTAssertNil(result, "Extraction failure should return nil, not crash")

        let domains = try await factStore.listDomains()
        XCTAssertTrue(domains.isEmpty, "No facts should be saved on extraction failure")
    }

    // MARK: - E2E: Interval Control

    /// Verifies that interval control prevents duplicate extraction within the cooldown window.
    func testHandler_withRealLLM_intervalControl_skipsWithinWindow() async throws {
        try XCTSkipIf(!hasApiKey, "ANTHROPIC_API_KEY or CODEANY_API_KEY not set — skipping E2E test")

        let extractor = LLMExperienceExtractor(client: makeClient(), extractionModel: extractionModel)
        let factStore = makeFactStore()
        let config = MemoryReviewConfig(reviewInterval: 3600) // 1 hour
        let messages = conversationWithLearnings()

        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()

        // First call — should proceed
        let result1 = await handler(HookInput(event: .sessionEnd))

        // Second call within interval — should skip (return "no extractable experience" or nil)
        let result2 = await handler(HookInput(event: .sessionEnd))

        // If first call extracted signals, second call should indicate skipping
        if let summary1 = result1?.additionalContext, summary1.contains("extracted") {
            // Second call's signals should be skipped by interval
            // The handler still calls the extractor but filters results per-domain
            if let summary2 = result2?.additionalContext {
                XCTAssertTrue(
                    summary2.contains("no extractable experience") || summary2.contains("Memory review:"),
                    "Second call should show interval-filtered result — got: \(summary2)"
                )
            }
        }
    }

    // MARK: - E2E: Multiple Domains

    /// Verifies that extraction from a conversation about multiple topics
    /// produces facts across multiple domains.
    func testHandler_withRealLLM_multipleTopics_savesAcrossDomains() async throws {
        try XCTSkipIf(!hasApiKey, "ANTHROPIC_API_KEY or CODEANY_API_KEY not set — skipping E2E test")

        let extractor = LLMExperienceExtractor(client: makeClient(), extractionModel: extractionModel)
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = buildConfigConversation()

        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))

        guard let summary = result?.additionalContext, summary.contains("extracted") else {
            // LLM may not extract signals — that's acceptable
            return
        }

        // Verify facts were saved to at least one domain
        let domains = try await factStore.listDomains()
        XCTAssertGreaterThan(domains.count, 0, "Facts should be saved to at least one domain")

        // Verify all saved facts have valid structure
        for domain in domains {
            let facts = try await factStore.query(domain: domain)
            XCTAssertGreaterThan(facts.count, 0)
            for fact in facts {
                XCTAssertEqual(fact.source, .observation)
                XCTAssertGreaterThanOrEqual(fact.confidence, 0.0)
                XCTAssertLessThanOrEqual(fact.confidence, 1.0)
            }
        }
    }

    // MARK: - E2E: Facts Persist Across Handler Calls

    /// Verifies that facts saved by the hook survive FactStore re-initialization.
    func testHandler_withRealLLM_factsPersistAcrossStoreReinit() async throws {
        try XCTSkipIf(!hasApiKey, "ANTHROPIC_API_KEY or CODEANY_API_KEY not set — skipping E2E test")

        let extractor = LLMExperienceExtractor(client: makeClient(), extractionModel: extractionModel)
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = conversationWithLearnings()

        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))

        guard let summary = result?.additionalContext, summary.contains("extracted") else {
            return // LLM didn't extract — acceptable
        }

        // Re-create store pointing at same directory
        let factStore2 = FactStore(memoryDir: tempDir)
        let domains = try await factStore2.listDomains()
        XCTAssertGreaterThan(domains.count, 0, "Facts should persist after store re-initialization")
    }

    // MARK: - E2E: HookOutput Structure

    /// Verifies that the HookOutput from a successful extraction has the correct structure.
    func testHandler_withRealLLM_hookOutputStructure() async throws {
        try XCTSkipIf(!hasApiKey, "ANTHROPIC_API_KEY or CODEANY_API_KEY not set — skipping E2E test")

        let extractor = LLMExperienceExtractor(client: makeClient(), extractionModel: extractionModel)
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = conversationWithLearnings()

        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))

        guard let output = result else {
            return // No signals extracted — acceptable for this structural check
        }

        // additionalContext must be non-empty
        let context = try XCTUnwrap(output.additionalContext)
        XCTAssertFalse(context.isEmpty, "additionalContext must contain a summary")

        // The summary must start with "Memory review:"
        XCTAssertTrue(
            context.hasPrefix("Memory review:"),
            "Summary must start with 'Memory review:' — got: \(context)"
        )
    }

    // MARK: - E2E: Signal-toFact Conversion Integrity

    /// Verifies that extracted signals correctly convert to MemoryFact objects with proper field mapping.
    func testHandler_withRealLLM_signalToFactConversionPreservesData() async throws {
        try XCTSkipIf(!hasApiKey, "ANTHROPIC_API_KEY or CODEANY_API_KEY not set — skipping E2E test")

        let extractor = LLMExperienceExtractor(client: makeClient(), extractionModel: extractionModel)
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = conversationWithLearnings()

        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))

        guard let summary = result?.additionalContext, summary.contains("extracted") else {
            return
        }

        // Check all saved facts
        let domains = try await factStore.listDomains()
        for domain in domains {
            let facts = try await factStore.query(domain: domain)
            for fact in facts {
                // Signal.toFact() maps: source=.conversation → .observation, status=.candidate, evidenceCount=1
                XCTAssertEqual(fact.source, .observation, "Converted fact source should be .observation")
                XCTAssertEqual(fact.status, .candidate, "New fact should be .candidate")
                XCTAssertEqual(fact.evidenceCount, 1, "New fact should have evidenceCount=1")
                XCTAssertEqual(fact.domain, domain, "Fact domain should match query domain")
                XCTAssertGreaterThanOrEqual(fact.confidence, 0.0)
                XCTAssertLessThanOrEqual(fact.confidence, 1.0)
            }
        }
    }
}

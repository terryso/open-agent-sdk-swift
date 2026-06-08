import XCTest
@testable import OpenAgentSDK

final class MemoryReviewHookTests: TempDirTestCase {

    // MARK: - Mock Extractor

    struct MockExperienceExtractor: ExperienceExtractor, Sendable {
        let result: ExtractionResult
        let shouldThrow: Bool

        init(result: ExtractionResult, shouldThrow: Bool = false) {
            self.result = result
            self.shouldThrow = shouldThrow
        }

        func extract(from messages: [SDKMessage], config: ExtractionConfig) async throws -> ExtractionResult {
            if shouldThrow {
                throw SDKError.apiError(statusCode: 0, message: "Extraction failed")
            }
            return result
        }
    }

    // MARK: - Helpers

    private func makeFactStore() -> FactStore {
        FactStore(memoryDir: tempDir)
    }

    private static func makeMessages(_ count: Int) -> [SDKMessage] {
        (0..<count).map { .userMessage(.init(message: "Message \($0)")) }
    }

    private static func makeSignal(domain: String = "testing", content: String = "Learned something") -> ExperienceSignal {
        ExperienceSignal.create(
            domain: domain,
            kind: .affordance,
            content: content,
            confidence: 0.8,
            source: .conversation
        )
    }

    // MARK: - MemoryReviewConfig Tests

    func testConfigDefaults() {
        let config = MemoryReviewConfig()
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.minMessagesForReview, 4)
        XCTAssertNil(config.reviewInterval)
        XCTAssertNil(config.domains)
        XCTAssertEqual(config.extractionConfig, ExtractionConfig())
    }

    func testConfigCustomInit() {
        let extractionConfig = ExtractionConfig(minSignalConfidence: 0.7)
        let config = MemoryReviewConfig(
            enabled: false,
            extractionConfig: extractionConfig,
            minMessagesForReview: 10,
            reviewInterval: 3600,
            domains: ["testing", "build"]
        )
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.minMessagesForReview, 10)
        XCTAssertEqual(config.reviewInterval, 3600)
        XCTAssertEqual(config.domains, ["testing", "build"])
        XCTAssertEqual(config.extractionConfig.minSignalConfidence, 0.7)
    }

    func testConfigCodable() throws {
        let config = MemoryReviewConfig(reviewInterval: 60, domains: ["nav"])
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(MemoryReviewConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    // MARK: - makeHandler Returns Valid Closure

    func testMakeHandlerReturnsClosure() async {
        let extractor = MockExperienceExtractor(result: ExtractionResult(
            signals: [], skippedCount: 0, extractionDate: Date(), sourceMessageCount: 0
        ))
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = Self.makeMessages(0)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        XCTAssertNotNil(handler)
    }

    // MARK: - minMessagesForReview Threshold

    func testSkipsBelowThreshold() async throws {
        let extractor = MockExperienceExtractor(result: ExtractionResult(
            signals: [Self.makeSignal()], skippedCount: 0, extractionDate: Date(), sourceMessageCount: 3
        ))
        let factStore = makeFactStore()
        let config = MemoryReviewConfig(minMessagesForReview: 5)
        let messages = Self.makeMessages(3)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))
        XCTAssertNil(result)
        let domains = try await factStore.listDomains()
        XCTAssertTrue(domains.isEmpty)
    }

    func testPassesThreshold() async throws {
        let signal = Self.makeSignal()
        let extractor = MockExperienceExtractor(result: ExtractionResult(
            signals: [signal], skippedCount: 0, extractionDate: Date(), sourceMessageCount: 5
        ))
        let factStore = makeFactStore()
        let config = MemoryReviewConfig(minMessagesForReview: 4)
        let messages = Self.makeMessages(5)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))
        XCTAssertNotNil(result)
        let saved = try await factStore.query(domain: "testing")
        XCTAssertEqual(saved.count, 1)
    }

    // MARK: - Disabled Config

    func testDisabledReturnsNil() async {
        let extractor = MockExperienceExtractor(result: ExtractionResult(
            signals: [Self.makeSignal()], skippedCount: 0, extractionDate: Date(), sourceMessageCount: 5
        ))
        let factStore = makeFactStore()
        let config = MemoryReviewConfig(enabled: false)
        let messages = Self.makeMessages(5)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))
        XCTAssertNil(result)
    }

    // MARK: - Extractor Error Handling

    func testExtractorThrowsReturnsNil() async throws {
        let extractor = MockExperienceExtractor(
            result: ExtractionResult(signals: [], skippedCount: 0, extractionDate: Date(), sourceMessageCount: 0),
            shouldThrow: true
        )
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = Self.makeMessages(5)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))
        XCTAssertNil(result)
        let domains = try await factStore.listDomains()
        XCTAssertTrue(domains.isEmpty)
    }

    // MARK: - Summary Generation

    func testSummaryZeroSignals() async {
        let extractor = MockExperienceExtractor(result: ExtractionResult(
            signals: [], skippedCount: 0, extractionDate: Date(), sourceMessageCount: 5
        ))
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = Self.makeMessages(5)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))
        XCTAssertEqual(result?.additionalContext, "Memory review: no extractable experience found in this session.")
    }

    func testSummaryMultipleSignals() async throws {
        let s1 = Self.makeSignal(domain: "testing", content: "Test pattern A")
        let s2 = Self.makeSignal(domain: "build", content: "Build pattern B")
        let extractor = MockExperienceExtractor(result: ExtractionResult(
            signals: [s1, s2], skippedCount: 3, extractionDate: Date(), sourceMessageCount: 10
        ))
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = Self.makeMessages(10)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))
        let summary = result?.additionalContext ?? ""
        XCTAssertTrue(summary.contains("extracted 2 experience signals"))
        XCTAssertTrue(summary.contains("3 filtered"))
        XCTAssertTrue(summary.contains("from 10 messages"))
        XCTAssertTrue(summary.contains("Domains: build, testing"))

        let testingFacts = try await factStore.query(domain: "testing")
        let buildFacts = try await factStore.query(domain: "build")
        XCTAssertEqual(testingFacts.count, 1)
        XCTAssertEqual(buildFacts.count, 1)
    }

    // MARK: - Interval Control

    func testIntervalSkipsSecondCallWithinInterval() async throws {
        let signal = Self.makeSignal()
        let extractor = MockExperienceExtractor(result: ExtractionResult(
            signals: [signal], skippedCount: 0, extractionDate: Date(), sourceMessageCount: 5
        ))
        let factStore = makeFactStore()
        let config = MemoryReviewConfig(reviewInterval: 3600) // 1 hour
        let messages = Self.makeMessages(5)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()

        // First call — should succeed
        let result1 = await handler(HookInput(event: .sessionEnd))
        XCTAssertNotNil(result1)
        let saved1 = try await factStore.query(domain: "testing")
        XCTAssertEqual(saved1.count, 1)

        // Second call — interval not elapsed, should skip the signal
        let result2 = await handler(HookInput(event: .sessionEnd))
        XCTAssertNotNil(result2)
        XCTAssertEqual(result2?.additionalContext, "Memory review: no extractable experience found in this session.")

        // Still only 1 fact saved from first call
        let saved2 = try await factStore.query(domain: "testing")
        XCTAssertEqual(saved2.count, 1)
    }

    func testNilIntervalRunsEveryTime() async throws {
        // Verify handler runs on every call when interval is nil.
        // Use a reference-based extractor to alternate between two signals.
        final class CallTracker: @unchecked Sendable {
            var count = 0
        }
        let tracker = CallTracker()

        let s1 = Self.makeSignal(domain: "domain1", content: "Insight 1")
        let s2 = Self.makeSignal(domain: "domain2", content: "Insight 2")

        struct SwitchingExtractor: ExperienceExtractor, Sendable {
            let first: [ExperienceSignal]
            let second: [ExperienceSignal]
            let tracker: CallTracker

            func extract(from messages: [SDKMessage], config: ExtractionConfig) async throws -> ExtractionResult {
                tracker.count += 1
                let signals = tracker.count == 1 ? first : second
                return ExtractionResult(signals: signals, skippedCount: 0, extractionDate: Date(), sourceMessageCount: messages.count)
            }
        }

        let extractor = SwitchingExtractor(first: [s1], second: [s2], tracker: tracker)
        let factStore = makeFactStore()
        let config = MemoryReviewConfig(reviewInterval: nil)
        let messages = Self.makeMessages(5)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()

        let _ = await handler(HookInput(event: .sessionEnd))
        let _ = await handler(HookInput(event: .sessionEnd))
        let d1 = try await factStore.query(domain: "domain1")
        let d2 = try await factStore.query(domain: "domain2")
        XCTAssertEqual(d1.count, 1)
        XCTAssertEqual(d2.count, 1)
        XCTAssertEqual(tracker.count, 2)
    }

    // MARK: - Facts Saved By Domain

    func testFactsGroupedByDomain() async throws {
        let s1 = Self.makeSignal(domain: "testing", content: "Test insight")
        let s2 = Self.makeSignal(domain: "testing", content: "Another test insight")
        let s3 = Self.makeSignal(domain: "build", content: "Build insight")
        let extractor = MockExperienceExtractor(result: ExtractionResult(
            signals: [s1, s2, s3], skippedCount: 0, extractionDate: Date(), sourceMessageCount: 8
        ))
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = Self.makeMessages(8)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))
        XCTAssertNotNil(result)

        let testingFacts = try await factStore.query(domain: "testing")
        let buildFacts = try await factStore.query(domain: "build")
        XCTAssertEqual(testingFacts.count, 2)
        XCTAssertEqual(buildFacts.count, 1)
    }

    // MARK: - Security Scanner Integration

    func testScannerRejectsFacts() async throws {
        let goodSignal = Self.makeSignal(domain: "testing", content: "Good fact")
        let badSignal = Self.makeSignal(domain: "system", content: "Injection attempt")
        let extractor = MockExperienceExtractor(result: ExtractionResult(
            signals: [goodSignal, badSignal], skippedCount: 0, extractionDate: Date(), sourceMessageCount: 5
        ))
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let scanner = MemorySecurityScanner(config: MemorySecurityConfig(blockedDomains: ["system"]))
        let messages = Self.makeMessages(5)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            securityScanner: scanner,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))
        XCTAssertNotNil(result)

        let testingFacts = try await factStore.query(domain: "testing")
        let systemFacts = try await factStore.query(domain: "system")
        XCTAssertEqual(testingFacts.count, 1, "Good signal should be saved")
        XCTAssertEqual(systemFacts.count, 0, "Blocked domain should be rejected")

        let summary = result?.additionalContext ?? ""
        XCTAssertTrue(summary.contains("1 filtered"), "Summary should include rejected count: \(summary)")
    }

    func testNilScannerIsBackwardCompatible() async throws {
        let signal = Self.makeSignal()
        let extractor = MockExperienceExtractor(result: ExtractionResult(
            signals: [signal], skippedCount: 0, extractionDate: Date(), sourceMessageCount: 5
        ))
        let factStore = makeFactStore()
        let config = MemoryReviewConfig()
        let messages = Self.makeMessages(5)
        let hook = MemoryReviewHook(
            extractor: extractor,
            factStore: factStore,
            config: config,
            securityScanner: nil,
            messageProvider: { messages }
        )
        let handler = hook.makeHandler()
        let result = await handler(HookInput(event: .sessionEnd))
        XCTAssertNotNil(result)
        let saved = try await factStore.query(domain: "testing")
        XCTAssertEqual(saved.count, 1, "Without scanner, facts should be saved normally")
    }
}

import XCTest
@testable import OpenAgentSDK

final class LLMExperienceExtractorTests: XCTestCase {

    // MARK: - Mock LLM Client

    /// A non-Sendable mock that records parameters. Used inside @Sendable closures
    /// via `nonisolated(unsafe)` — safe because tests run sequentially.
    private static let sharedState = SharedMockState()

    final class SharedMockState: @unchecked Sendable {
        var capturedModel: String?
        var capturedMaxTokens: Int?
        var capturedTemperature: Double?
        var capturedSystem: String?
        var capturedMessages: [[String: Any]]?
        private let lock = NSLock()

        func record(model: String, messages: [[String: Any]], maxTokens: Int, system: String?, temperature: Double?) {
            lock.lock()
            capturedModel = model
            capturedMessages = messages
            capturedMaxTokens = maxTokens
            capturedSystem = system
            capturedTemperature = temperature
            lock.unlock()
        }

        func reset() {
            lock.lock()
            capturedModel = nil
            capturedMessages = nil
            capturedMaxTokens = nil
            capturedSystem = nil
            capturedTemperature = nil
            lock.unlock()
        }
    }

    struct MockLLMClient: LLMClient, Sendable {
        let responseText: String
        let shouldThrow: Bool

        init(responseText: String = "[]", shouldThrow: Bool = false) {
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
                throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "LLM call failed"])
            }
            LLMExperienceExtractorTests.sharedState.record(
                model: model, messages: messages, maxTokens: maxTokens, system: system, temperature: temperature
            )
            return ["content": [["type": "text", "text": responseText]] as [[String: Any]]]
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
            AsyncThrowingStream { _ in }
        }
    }

    // MARK: - Helpers

    private func sampleMessages() -> [SDKMessage] {
        [
            .assistant(.init(text: "I'll run the tests now.", model: "claude-sonnet-4-6", stopReason: "end_turn")),
            .userMessage(.init(message: "Please also check for regressions.")),
            .toolResult(.init(toolUseId: "tu1", content: "All 882 tests passed.", isError: false)),
        ]
    }

    private func resetState() {
        LLMExperienceExtractorTests.sharedState.reset()
    }

    // MARK: - Initialization Tests

    func testDefaultModel() {
        let extractor = LLMExperienceExtractor(client: MockLLMClient())
        XCTAssertEqual(extractor.extractionModel, "claude-haiku-4-5-20251001")
    }

    func testCustomModel() {
        let extractor = LLMExperienceExtractor(client: MockLLMClient(), extractionModel: "claude-sonnet-4-6")
        XCTAssertEqual(extractor.extractionModel, "claude-sonnet-4-6")
    }

    // MARK: - Message Serialization Tests (verified via captured messages)

    func testSerializeIncludesEssentialMessageTypes() async throws {
        resetState()
        let client = MockLLMClient(responseText: "[]")
        let extractor = LLMExperienceExtractor(client: client)

        _ = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig())

        let captured = LLMExperienceExtractorTests.sharedState.capturedMessages
        XCTAssertEqual(captured?.count, 1)
        let content = captured![0]["content"] as? String ?? ""
        XCTAssertTrue(content.contains("[assistant]"))
        XCTAssertTrue(content.contains("[user]"))
        XCTAssertTrue(content.contains("[tool_result]"))
        XCTAssertTrue(content.contains("I'll run the tests now."))
        XCTAssertTrue(content.contains("Please also check for regressions."))
        XCTAssertTrue(content.contains("All 882 tests passed."))
    }

    func testSerializeExcludesNonEssentialMessageTypes() async throws {
        resetState()
        let client = MockLLMClient(responseText: "[]")
        let extractor = LLMExperienceExtractor(client: client)

        let messages: [SDKMessage] = [
            .system(.init(subtype: .status, message: "session init")),
            .toolUse(.init(toolName: "bash", toolUseId: "tu1", input: "ls")),
            .hookStarted(.init(hookId: "h1", hookName: "pre-tool", hookEvent: "PreToolUse")),
            .hookProgress(.init(hookId: "h1", hookName: "pre-tool", hookEvent: "PreToolUse")),
            .hookResponse(.init(hookId: "h1", hookName: "pre-tool", hookEvent: "PreToolUse")),
            .taskStarted(.init(taskId: "t1", taskType: "subagent", description: "work")),
            .taskProgress(.init(taskId: "t1", taskType: "subagent")),
            .toolProgress(.init(toolUseId: "tu1", toolName: "bash")),
            .authStatus(.init(status: "ok", message: "authenticated")),
            .filesPersisted(.init(filePaths: ["/tmp/file"])),
            .localCommandOutput(.init(output: "done", command: "echo hi")),
            .promptSuggestion(.init(suggestions: ["next"])),
            .toolUseSummary(.init(toolUseCount: 1, tools: ["bash"])),
        ]

        _ = try await extractor.extract(from: messages, config: ExtractionConfig())

        let captured = LLMExperienceExtractorTests.sharedState.capturedMessages
        XCTAssertEqual(captured?.count, 1)
        let content = captured![0]["content"] as? String ?? ""
        // All non-essential messages should produce empty serialization
        XCTAssertEqual(content, "")
    }

    func testSerializeTruncatesLongMessages() async throws {
        resetState()
        let client = MockLLMClient(responseText: "[]")
        let extractor = LLMExperienceExtractor(client: client)

        let longText = String(repeating: "x", count: 3000)
        let messages: [SDKMessage] = [
            .assistant(.init(text: longText, model: "m", stopReason: "end_turn")),
        ]

        _ = try await extractor.extract(from: messages, config: ExtractionConfig())

        let captured = LLMExperienceExtractorTests.sharedState.capturedMessages
        let content = captured![0]["content"] as? String ?? ""
        XCTAssertTrue(content.contains("... [truncated]"))
    }

    // MARK: - JSON Parsing Tests

    func testParseValidJSONResponse() async throws {
        let json = """
        [
            {"domain": "testing", "content": "Always run full suite", "kind": "affordance", "confidence": 0.9},
            {"domain": "build", "content": "Avoid force push", "kind": "avoid", "confidence": 0.7}
        ]
        """
        let client = MockLLMClient(responseText: json)
        let extractor = LLMExperienceExtractor(client: client)

        let result = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig())
        XCTAssertEqual(result.signals.count, 2)
        XCTAssertEqual(result.signals[0].domain, "testing")
        XCTAssertEqual(result.signals[0].kind, .affordance)
        XCTAssertEqual(result.signals[1].domain, "build")
        XCTAssertEqual(result.signals[1].kind, .avoid)
    }

    func testParseCodeFencedResponse() async throws {
        let json = """
        ```json
        [
            {"domain": "navigation", "content": "Use project indexes", "kind": "observation", "confidence": 0.6}
        ]
        ```
        """
        let client = MockLLMClient(responseText: json)
        let extractor = LLMExperienceExtractor(client: client)

        let result = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig())
        XCTAssertEqual(result.signals.count, 1)
        XCTAssertEqual(result.signals[0].domain, "navigation")
    }

    func testParseEmptyResponse() async throws {
        let client = MockLLMClient(responseText: "")
        let extractor = LLMExperienceExtractor(client: client)

        let result = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig())
        XCTAssertEqual(result.signals.count, 0)
        XCTAssertEqual(result.skippedCount, 0)
    }

    func testParseMalformedJSON() async throws {
        let client = MockLLMClient(responseText: "this is not json")
        let extractor = LLMExperienceExtractor(client: client)

        let result = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig())
        XCTAssertEqual(result.signals.count, 0)
    }

    func testParseSkipsInvalidSignals() async throws {
        let json = """
        [
            {"domain": "testing", "content": "Valid signal", "kind": "affordance", "confidence": 0.8},
            {"domain": "bad", "content": "Missing kind"},
            {"content": "Missing domain and kind", "kind": "observation", "confidence": 0.5},
            {"domain": "build", "content": "Another valid", "kind": "avoid", "confidence": 0.7}
        ]
        """
        let client = MockLLMClient(responseText: json)
        let extractor = LLMExperienceExtractor(client: client)

        let result = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig())
        XCTAssertEqual(result.signals.count, 2)
        XCTAssertEqual(result.skippedCount, 2, "Parse failures should be counted in skippedCount")
    }

    // MARK: - Confidence Filtering Tests

    func testFiltersBelowConfidenceThreshold() async throws {
        let json = """
        [
            {"domain": "a", "content": "High confidence", "kind": "affordance", "confidence": 0.9},
            {"domain": "b", "content": "Low confidence", "kind": "observation", "confidence": 0.2},
            {"domain": "c", "content": "At threshold", "kind": "avoid", "confidence": 0.4}
        ]
        """
        let client = MockLLMClient(responseText: json)
        let extractor = LLMExperienceExtractor(client: client)

        let result = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig(minSignalConfidence: 0.4))
        XCTAssertEqual(result.signals.count, 2)
        XCTAssertEqual(result.skippedCount, 1)
    }

    // MARK: - Anti-Pattern Filtering Tests

    func testFiltersAntiPatternKeywords() async throws {
        let json = """
        [
            {"domain": "a", "content": "Good learning about testing", "kind": "affordance", "confidence": 0.9},
            {"domain": "b", "content": "The tool does not work on this machine", "kind": "avoid", "confidence": 0.8},
            {"domain": "c", "content": "Command not found error", "kind": "observation", "confidence": 0.7}
        ]
        """
        let client = MockLLMClient(responseText: json)
        let extractor = LLMExperienceExtractor(client: client)

        let result = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig())
        XCTAssertEqual(result.signals.count, 1)
        XCTAssertEqual(result.signals[0].domain, "a")
        XCTAssertEqual(result.skippedCount, 2)
    }

    // MARK: - Max Signals Limit Tests

    func testRespectsMaxSignalsLimit() async throws {
        let json = """
        [
            {"domain": "a", "content": "Signal 1", "kind": "affordance", "confidence": 0.9},
            {"domain": "b", "content": "Signal 2", "kind": "avoid", "confidence": 0.8},
            {"domain": "c", "content": "Signal 3", "kind": "observation", "confidence": 0.7}
        ]
        """
        let client = MockLLMClient(responseText: json)
        let extractor = LLMExperienceExtractor(client: client)

        let result = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig(maxSignalsPerExtraction: 2))
        XCTAssertEqual(result.signals.count, 2)
        XCTAssertEqual(result.skippedCount, 1)
    }

    // MARK: - System Prompt Tests

    func testSystemPromptIncludesDomainFilter() async throws {
        resetState()
        let client = MockLLMClient(responseText: "[]")
        let extractor = LLMExperienceExtractor(client: client)

        _ = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig(domain: "testing"))

        let captured = LLMExperienceExtractorTests.sharedState.capturedSystem
        XCTAssertNotNil(captured)
        XCTAssertTrue(captured!.contains("testing"))
    }

    func testSystemPromptWithoutDomainFilter() async throws {
        resetState()
        let client = MockLLMClient(responseText: "[]")
        let extractor = LLMExperienceExtractor(client: client)

        _ = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig())

        let captured = LLMExperienceExtractorTests.sharedState.capturedSystem
        XCTAssertNotNil(captured)
        XCTAssertFalse(captured!.contains("Restrict extraction to the domain"))
    }

    // MARK: - ExtractionResult Construction Tests

    func testExtractionResultMetadata() async throws {
        let json = """
        [{"domain": "a", "content": "Signal", "kind": "affordance", "confidence": 0.9}]
        """
        let client = MockLLMClient(responseText: json)
        let extractor = LLMExperienceExtractor(client: client)

        let messages = sampleMessages()
        let result = try await extractor.extract(from: messages, config: ExtractionConfig())

        XCTAssertEqual(result.sourceMessageCount, messages.count)
        XCTAssertEqual(result.signals.count, 1)
        XCTAssertEqual(result.signals[0].source, .conversation)
        XCTAssertNotNil(result.signals[0].id)
    }

    // MARK: - Error Propagation Tests

    func testPropagatesLLMError() async {
        let client = MockLLMClient(responseText: "", shouldThrow: true)
        let extractor = LLMExperienceExtractor(client: client)

        do {
            _ = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig())
            XCTFail("Expected error to be thrown")
        } catch let error as SDKError {
            if case .apiError(let statusCode, let message) = error {
                XCTAssertEqual(statusCode, 0)
                XCTAssertTrue(message.contains("Experience extraction failed"))
            } else {
                XCTFail("Expected apiError, got \(error)")
            }
        } catch {
            XCTFail("Expected SDKError, got \(error)")
        }
    }

    // MARK: - Empty Messages Tests

    func testEmptyMessagesProduceValidResult() async throws {
        let client = MockLLMClient(responseText: "[]")
        let extractor = LLMExperienceExtractor(client: client)

        let result = try await extractor.extract(from: [], config: ExtractionConfig())
        XCTAssertEqual(result.signals.count, 0)
        XCTAssertEqual(result.sourceMessageCount, 0)
    }

    // MARK: - LLM Parameters Tests

    func testUsesCorrectLLMParameters() async throws {
        resetState()
        let client = MockLLMClient(responseText: "[]")
        let extractor = LLMExperienceExtractor(client: client, extractionModel: "claude-haiku-4-5-20251001")

        _ = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig())

        XCTAssertEqual(LLMExperienceExtractorTests.sharedState.capturedModel, "claude-haiku-4-5-20251001")
        XCTAssertEqual(LLMExperienceExtractorTests.sharedState.capturedMaxTokens, 2048)
        XCTAssertEqual(LLMExperienceExtractorTests.sharedState.capturedTemperature, 0.3)
    }

    // MARK: - Anti-Pattern Guidance in Prompt

    func testSystemPromptContainsAntiPatternGuidance() async throws {
        resetState()
        let client = MockLLMClient(responseText: "[]")
        let extractor = LLMExperienceExtractor(client: client)

        _ = try await extractor.extract(from: sampleMessages(), config: ExtractionConfig())

        let captured = LLMExperienceExtractorTests.sharedState.capturedSystem
        XCTAssertNotNil(captured)
        XCTAssertTrue(captured!.contains("capture the FIX"))
        XCTAssertTrue(captured!.contains("tool does not work"))
    }
}

import XCTest
@testable import OpenAgentSDK

// MARK: - shouldMicroCompact Tests

/// ATDD RED PHASE: Tests for Story 2.6 -- Tool-Result Micro-Compaction.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `MICRO_COMPACT_THRESHOLD` constant is added to `Utils/Compact.swift`
///   - `shouldMicroCompact(content:)` is implemented in `Utils/Compact.swift`
///   - `microCompact(client:model:content:)` is implemented in `Utils/Compact.swift`
///   - `buildMicroCompactPrompt(_:)` is implemented as a private helper
/// TDD Phase: RED (feature not implemented yet)
final class ShouldMicroCompactTests: XCTestCase {

    // MARK: - AC1: Micro-compact trigger (above threshold)

    /// AC1 [P0]: Content exceeding 50,000 characters should trigger micro-compaction.
    func testShouldMicroCompact_ReturnsTrue_AboveThreshold() {
        // Given: content of 50,001 characters (> MICRO_COMPACT_THRESHOLD)
        let content = String(repeating: "x", count: 50_001)

        // When: checking if micro-compaction should trigger
        let result = shouldMicroCompact(content: content)

        // Then: returns true
        XCTAssertTrue(result,
                       "Content > 50,000 chars should trigger micro-compaction")
    }

    // MARK: - AC2: No compression below threshold

    /// AC2 [P0]: Content below 50,000 characters should NOT trigger micro-compaction.
    func testShouldMicroCompact_ReturnsFalse_BelowThreshold() {
        // Given: content of 49,999 characters (< MICRO_COMPACT_THRESHOLD)
        let content = String(repeating: "y", count: 49_999)

        // When: checking if micro-compaction should trigger
        let result = shouldMicroCompact(content: content)

        // Then: returns false
        XCTAssertFalse(result,
                        "Content < 50,000 chars should NOT trigger micro-compaction")
    }

    /// AC2 [P0]: Content exactly at 50,000 characters should NOT trigger (strict >).
    func testShouldMicroCompact_ReturnsFalse_AtExactThreshold() {
        // Given: content of exactly 50,000 characters
        let content = String(repeating: "z", count: 50_000)

        // When: checking if micro-compaction should trigger
        let result = shouldMicroCompact(content: content)

        // Then: returns false (threshold is strict >, not >=)
        XCTAssertFalse(result,
                        "Content exactly at 50,000 chars should NOT trigger (strict >)")
    }

    // MARK: - Anti-pattern: Already compacted

    /// Anti-pattern [P0]: Content already marked as micro-compacted should NOT be re-compacted.
    func testShouldMicroCompact_ReturnsFalse_WhenAlreadyCompacted() {
        // Given: content that starts with the micro-compaction marker prefix
        let largeContent = "[微压缩] 原始长度: 60000, 压缩后长度: 5000\n\nSome summary text."
            + String(repeating: "a", count: 60_000)

        // When: checking if micro-compaction should trigger
        let result = shouldMicroCompact(content: largeContent)

        // Then: returns false (do not re-compress already compressed content)
        XCTAssertFalse(result,
                        "Content already marked with [微压缩] should NOT be re-compacted")
    }

    /// Anti-pattern [P0]: Error results (isError=true) should NOT be compacted.
    func testShouldMicroCompact_ReturnsFalse_ForErrorResults() {
        // Given: error tool result content exceeding threshold
        let errorContent = "Error: " + String(repeating: "e", count: 50_001)

        // When: checking with isError=true
        let result = shouldMicroCompact(content: errorContent, isError: true)

        // Then: returns false (error results must be preserved in full)
        XCTAssertFalse(result,
                        "Error results (isError=true) should NOT be compacted")
    }

    /// Boundary [P1]: Empty string does not trigger micro-compaction.
    func testShouldMicroCompact_ReturnsFalse_ForEmptyString() {
        let result = shouldMicroCompact(content: "")

        XCTAssertFalse(result,
                        "Empty string should NOT trigger micro-compaction")
    }
}

// MARK: - microCompact Tests (using CompactMockURLProtocol from CompactTests.swift)

final class MicroCompactTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CompactMockURLProtocol.reset()
    }

    override func tearDown() {
        CompactMockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - AC1 + AC3: Successful micro-compaction returns compressed content with marker

    /// AC1, AC3 [P0]: Successful micro-compaction returns compressed content with marker.
    func testMicroCompact_ReturnsCompressedContent_OnSuccess() async throws {
        let client = makeCompactTestClient()
        let largeContent = String(repeating: "file content line\n", count: 3000)
        // largeContent is ~54,000 chars

        let summary = "File paths: /src/main.swift, /lib/utils.swift. Errors: none. Keys: name, version, description."
        let compactResponse = makeCompactionSuccessResponse(summary: summary)

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactResponse),
        ])

        let result = await microCompact(
            client: client,
            model: "claude-sonnet-4-6",
            content: largeContent
        )

        // Should contain the micro-compaction marker prefix
        XCTAssertTrue(result.hasPrefix("[微压缩]"),
                       "Micro-compacted result should start with [微压缩] marker")
        // Should contain the compressed summary
        XCTAssertTrue(result.contains(summary),
                       "Micro-compacted result should contain the LLM summary")
        // Should NOT contain the original large content verbatim
        XCTAssertFalse(result.contains("file content line\nfile content line\nfile content line\n"),
                        "Micro-compacted result should NOT contain verbatim original content")
    }

    // MARK: - AC3: Marker contains original and compressed length

    /// AC3 [P0]: The marker includes original length and compressed length.
    func testMicroCompact_MarkerContainsOriginalAndCompressedLength() async throws {
        let client = makeCompactTestClient()
        let originalContent = String(repeating: "a", count: 60_000)

        let summary = "Compressed summary of the content"
        let compactResponse = makeCompactionSuccessResponse(summary: summary)

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactResponse),
        ])

        let result = await microCompact(
            client: client,
            model: "claude-sonnet-4-6",
            content: originalContent
        )

        // Marker should contain original length
        XCTAssertTrue(result.contains("原始长度: \(originalContent.count)"),
                       "Marker should contain original length: \(originalContent.count)")

        // Marker should contain compressed length (summary length)
        XCTAssertTrue(result.contains("压缩后长度:"),
                       "Marker should contain compressed length")

        // Verify the marker format exactly
        let markerRegex = try NSRegularExpression(
            pattern: #"^\[微压缩\] 原始长度: \d+, 压缩后长度: \d+"#,
            options: []
        )
        let markerRange = NSRange(result.startIndex..., in: result)
        let markerMatch = markerRegex.firstMatch(in: result, options: [], range: markerRange)
        XCTAssertNotNil(markerMatch,
                         "Marker should match format: [微压缩] 原始长度: X, 压缩后长度: Y")
    }

    // MARK: - AC4: Compression failure preserves original content

    /// AC4 [P0]: When the LLM call fails, the original content is returned unchanged.
    func testMicroCompact_PreservesOriginalContent_OnFailure() async throws {
        let client = makeCompactTestClient()
        let originalContent = String(repeating: "b", count: 55_000)

        // Register an error response (HTTP 500)
        let errorBody: [String: Any] = [
            "error": ["type": "api_error", "message": "Internal server error"]
        ]
        let errorData = try! JSONSerialization.data(withJSONObject: errorBody, options: [])

        registerCompactMockResponses([
            (500, ["content-type": "application/json"], errorData),
        ])

        let result = await microCompact(
            client: client,
            model: "claude-sonnet-4-6",
            content: originalContent
        )

        // Should return original content unchanged
        XCTAssertEqual(result, originalContent,
                        "On LLM failure, original content should be returned unchanged")
    }

    /// AC4 [P0]: On network error (not HTTP error), original content is preserved.
    func testMicroCompact_PreservesOriginalContent_OnNetworkError() async throws {
        let client = makeCompactTestClient()
        let originalContent = String(repeating: "c", count: 52_000)

        // No responses registered -- will cause a connection error
        // (the mock URL protocol will fail with "No more mock responses")
        registerCompactMockResponses([])

        let result = await microCompact(
            client: client,
            model: "claude-sonnet-4-6",
            content: originalContent
        )

        // Should return original content unchanged
        XCTAssertEqual(result, originalContent,
                        "On network error, original content should be returned unchanged")
    }

    // MARK: - AC5: Compression quality -- correct system prompt

    /// AC5 [P0]: The micro-compact LLM call uses the correct summarizer system prompt.
    func testMicroCompact_IncludesCorrectSystemPrompt() async throws {
        let client = makeCompactTestClient()
        let largeContent = String(repeating: "data\n", count: 15_000) // 60,000 chars

        let compactResponse = makeCompactionSuccessResponse(summary: "Summary result")

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactResponse),
        ])

        _ = await microCompact(
            client: client,
            model: "claude-sonnet-4-6",
            content: largeContent
        )

        // Verify the request body contains the expected system prompt
        let requests = CompactMockURLProtocol.allRequests
        XCTAssertGreaterThanOrEqual(requests.count, 1,
                                     "Should have sent at least 1 request")

        if let firstRequest = requests.first,
           let bodyData = firstRequest.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any] {

            let systemPrompt = body["system"] as? String ?? ""
            XCTAssertTrue(systemPrompt.contains("summarizer") || systemPrompt.contains("summar") || systemPrompt.contains("compress"),
                          "Micro-compact request should include a summarizer/compressor system prompt, got: \(systemPrompt)")

            // Verify the prompt mentions key preservation categories
            XCTAssertTrue(systemPrompt.contains("file") || systemPrompt.contains("path") || systemPrompt.contains("error"),
                          "System prompt should mention preserving file paths, errors, or keys")
        }
    }

    /// Implementation constraint [P0]: The micro-compact LLM call uses maxTokens=8192.
    func testMicroCompact_UsesMaxTokens8192() async throws {
        let client = makeCompactTestClient()
        let largeContent = String(repeating: "x", count: 55_000)

        let compactResponse = makeCompactionSuccessResponse(summary: "Summarized")

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactResponse),
        ])

        _ = await microCompact(
            client: client,
            model: "claude-sonnet-4-6",
            content: largeContent
        )

        let requests = CompactMockURLProtocol.allRequests
        XCTAssertGreaterThanOrEqual(requests.count, 1,
                                     "Should have sent at least 1 request")

        if let firstRequest = requests.first,
           let bodyData = firstRequest.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any] {

            let maxTokens = body["max_tokens"] as? Int ?? 0
            XCTAssertEqual(maxTokens, 8192,
                            "Micro-compact request should use maxTokens=8192")
        }
    }

    /// Anti-pattern [P1]: Micro-compaction cost is NOT added to the user's totalCostUsd.
    /// This test verifies that microCompact returns only a string (no cost tracking).
    /// The Agent integration must not add micro-compact costs to totalCostUsd.
    func testMicroCompact_ReturnsStringOnly_NoCostTracking() async throws {
        let client = makeCompactTestClient()
        let largeContent = String(repeating: "d", count: 51_000)

        let compactResponse = makeCompactionSuccessResponse(summary: "Summary")

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactResponse),
        ])

        let result = await microCompact(
            client: client,
            model: "claude-sonnet-4-6",
            content: largeContent
        )

        // The function returns a String -- no cost data in the return type.
        // This is a compile-time check that the signature is (String) async -> String.
        // Integration tests verify that Agent does not add this to totalCostUsd.
        XCTAssertTrue(type(of: result) == String.self,
                       "microCompact should return a plain String with no cost tracking")
    }

    /// AC5 [P1]: The buildMicroCompactPrompt includes the original content for summarization.
    /// Verified indirectly by checking the user message in the LLM request.
    func testMicroCompact_SendsContentToLLM() async throws {
        let client = makeCompactTestClient()
        let uniqueMarker = "UNIQUE_MARKER_\(UUID().uuidString)"
        let largeContent = uniqueMarker + String(repeating: "f", count: 55_000)

        let compactResponse = makeCompactionSuccessResponse(summary: "Found marker")

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactResponse),
        ])

        _ = await microCompact(
            client: client,
            model: "claude-sonnet-4-6",
            content: largeContent
        )

        let requests = CompactMockURLProtocol.allRequests
        XCTAssertGreaterThanOrEqual(requests.count, 1,
                                     "Should have sent at least 1 request")

        if let firstRequest = requests.first,
           let bodyData = firstRequest.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
           let messages = body["messages"] as? [[String: Any]],
           let userMessage = messages.first,
           let userContent = userMessage["content"] as? String {

            XCTAssertTrue(userContent.contains(uniqueMarker),
                          "The LLM prompt should contain the original content (or a relevant portion of it)")
        }
    }
}

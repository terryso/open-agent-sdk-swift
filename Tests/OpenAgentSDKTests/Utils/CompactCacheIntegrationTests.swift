import XCTest
@testable import OpenAgentSDK

// MARK: - Compact + FileCache Integration ATDD Tests (Story 12.2)

/// ATDD RED PHASE: Tests for Story 12.2 -- Compact and FileCache integration.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `AutoCompactState` gains `lastCompactTime: Date` field
///   - `compactConversation()` accepts optional `fileCache: FileCache?` parameter
///   - `buildCompactionPrompt()` accepts modified files list parameter
///   - Compaction prompt includes recently modified files info
/// TDD Phase: RED (feature not implemented yet)
final class CompactCacheIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CompactMockURLProtocol.reset()
    }

    override func tearDown() {
        CompactMockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a FileCache for testing.
    private func makeCache() -> FileCache {
        return FileCache()
    }

    // MARK: - AutoCompactState.lastCompactTime

    /// AC2 [P0]: AutoCompactState has lastCompactTime initialized to distantPast.
    func testAutoCompactState_HasLastCompactTime_DefaultsToDistantPast() {
        // When: creating initial auto compact state
        let state = createAutoCompactState()

        // Then: lastCompactTime should be Date.distantPast
        // NOTE: This will FAIL until AutoCompactState gains lastCompactTime field
        XCTAssertEqual(state.lastCompactTime, Date.distantPast,
                       "Initial lastCompactTime should be Date.distantPast")
    }

    /// AC2 [P1]: AutoCompactState preserves lastCompactTime across state transitions.
    func testAutoCompactState_PreservesLastCompactTime() {
        // Given: a state with a specific lastCompactTime
        let specificTime = Date()
        // NOTE: This will FAIL until AutoCompactState gains lastCompactTime field
        let state = AutoCompactState(
            compacted: true,
            turnCounter: 3,
            consecutiveFailures: 0,
            lastCompactTime: specificTime
        )

        // Then: lastCompactTime is preserved
        XCTAssertEqual(state.lastCompactTime, specificTime,
                       "lastCompactTime should be preserved in the state")
    }

    // MARK: - compactConversation with fileCache parameter

    /// AC2 [P0]: compactConversation accepts optional fileCache parameter.
    ///
    /// When fileCache is provided and has modified files, the compaction prompt
    /// should include the modified file list.
    func testCompactConversation_WithFileCache_IncludesModifiedFiles() async throws {
        // Given: a cache with recently modified files
        let cache = makeCache()
        cache.set("/project/ModifiedFile1.swift", content: "content 1")
        cache.set("/project/ModifiedFile2.swift", content: "content 2")

        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()
        let state = createAutoCompactState()

        let summary = "Summary with modified files context."
        let compactionResponse = makeCompactionSuccessResponse(summary: summary)

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactionResponse),
        ])

        // When: calling compactConversation with fileCache
        // NOTE: This will FAIL until compactConversation gains fileCache parameter
        let result = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            fileCache: cache,
            retryConfig: fastRetryConfig
        )

        // Then: compaction succeeds (returns 2 messages)
        XCTAssertEqual(result.compactedMessages.count, 2,
                       "Compacted messages should contain exactly 2 messages")

        // And: the LLM request body should contain modified file paths
        let requests = CompactMockURLProtocol.allRequests
        XCTAssertGreaterThanOrEqual(requests.count, 1,
                                     "Should have sent at least 1 request")

        if let firstRequest = requests.first,
           let bodyData = firstRequest.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any] {

            // The user message content should mention the modified files
            let messages = body["messages"] as? [[String: Any]] ?? []
            let userMessageContent = messages
                .compactMap { $0["content"] as? String }
                .joined(separator: " ")

            let containsModifiedFile1 = userMessageContent.contains("ModifiedFile1.swift")
            let containsModifiedFile2 = userMessageContent.contains("ModifiedFile2.swift")

            XCTAssertTrue(containsModifiedFile1 || containsModifiedFile2,
                          "Compaction prompt should mention at least one modified file path, got: \(userMessageContent.prefix(500))")
        }
    }

    /// AC2 [P0]: compactConversation works normally when fileCache is nil.
    ///
    /// When no FileCache is provided, compaction should work as before (backwards compatible).
    func testCompactConversation_WithNilFileCache_WorksNormally() async throws {
        // Given: no file cache
        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()
        let state = createAutoCompactState()

        let summary = "Standard compaction summary."
        let compactionResponse = makeCompactionSuccessResponse(summary: summary)

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactionResponse),
        ])

        // When: calling compactConversation WITHOUT fileCache (nil)
        // NOTE: This will FAIL until compactConversation gains fileCache parameter
        // But existing tests call without fileCache, so we test with the new signature
        let result = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            fileCache: nil,
            retryConfig: fastRetryConfig
        )

        // Then: compaction succeeds as before
        XCTAssertEqual(result.compactedMessages.count, 2,
                       "Compacted messages should contain exactly 2 messages even without fileCache")
    }

    /// AC2 [P1]: compactConversation updates lastCompactTime after successful compaction.
    func testCompactConversation_UpdatesLastCompactTime_OnSuccess() async throws {
        // Given: initial state with distantPast as lastCompactTime
        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()
        let state = createAutoCompactState()

        let beforeCompact = Date()

        let compactionResponse = makeCompactionSuccessResponse(summary: "Summary.")

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactionResponse),
        ])

        // When: compaction succeeds
        let result = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            fileCache: nil,
            retryConfig: fastRetryConfig
        )

        // Then: lastCompactTime should be updated to a recent time
        // NOTE: This will FAIL until AutoCompactState gains lastCompactTime
        XCTAssertGreaterThanOrEqual(result.state.lastCompactTime, beforeCompact,
                                     "lastCompactTime should be updated after successful compaction")
    }

    /// AC2 [P1]: compactConversation does NOT update lastCompactTime on failure.
    func testCompactConversation_DoesNotUpdateLastCompactTime_OnFailure() async throws {
        // Given: initial state
        let client = makeCompactTestClient()
        let originalMessages: [[String: Any]] = [
            ["role": "user", "content": "Hello"],
        ]
        let state = createAutoCompactState()
        let originalLastCompactTime = state.lastCompactTime

        // Register an error response
        let errorBody: [String: Any] = [
            "error": ["type": "api_error", "message": "Server error"]
        ]
        let errorData = try! JSONSerialization.data(withJSONObject: errorBody, options: [])

        registerCompactMockResponses([
            (500, ["content-type": "application/json"], errorData),
        ])

        // When: compaction fails
        let result = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: originalMessages,
            state: state,
            fileCache: nil,
            retryConfig: fastRetryConfig
        )

        // Then: lastCompactTime should NOT be updated
        XCTAssertEqual(result.state.lastCompactTime, originalLastCompactTime,
                       "lastCompactTime should remain unchanged on compaction failure")
    }

    /// AC2 [P2]: Compaction prompt format includes modified files section.
    func testCompactConversation_PromptFormat_IncludesModifiedFilesSection() async throws {
        // Given: a cache with modifications
        let cache = makeCache()
        cache.set("/src/FeatureA.swift", content: "feature A")
        cache.set("/src/FeatureB.swift", content: "feature B")

        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()
        let state = createAutoCompactState()

        let compactionResponse = makeCompactionSuccessResponse(summary: "Summary.")

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactionResponse),
        ])

        // When: calling compactConversation with fileCache
        _ = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            fileCache: cache,
            retryConfig: fastRetryConfig
        )

        // Then: the prompt sent to the LLM should include a section about recently modified files
        let requests = CompactMockURLProtocol.allRequests
        XCTAssertGreaterThanOrEqual(requests.count, 1)

        if let firstRequest = requests.first,
           let bodyData = firstRequest.httpBody,
           let body = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any] {

            let messagesArray = body["messages"] as? [[String: Any]] ?? []
            let allContent = messagesArray
                .compactMap { $0["content"] as? String }
                .joined(separator: "\n")

            // The prompt should contain some reference to recently modified files
            let hasModifiedFilesReference =
                allContent.contains("Recently modified") ||
                allContent.contains("modified files") ||
                allContent.contains("FeatureA") ||
                allContent.contains("FeatureB")

            XCTAssertTrue(hasModifiedFilesReference,
                          "Compaction prompt should reference recently modified files or file names")
        }
    }
}

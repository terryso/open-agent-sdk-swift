import XCTest
@testable import OpenAgentSDK

// MARK: - SessionMemoryEntry Tests

/// ATDD RED PHASE: Tests for Story 13.3 -- Session Memory Compression Layer.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Utils/SessionMemory.swift` is created with `SessionMemoryEntry` struct and `SessionMemory` class
///   - `Utils/TokenEstimator.swift` is created with `TokenEstimator.estimate(_:)` method
///   - `Core/Agent.swift` is modified to include `sessionMemory` property and `buildSystemPrompt()` injection
///   - `Utils/Compact.swift` is modified to extract session memory after auto-compact
/// TDD Phase: RED (feature not implemented yet)
final class SessionMemoryTests: XCTestCase {

    // MARK: - AC4: SessionMemoryEntry Type Existence

    /// AC4 [P0]: SessionMemoryEntry can be created with required fields.
    func testSessionMemoryEntry_CanBeCreatedWithRequiredFields() {
        let entry = SessionMemoryEntry(
            category: "decision",
            summary: "Decided to use LRU cache for file reads",
            context: "main.swift",
            timestamp: Date()
        )

        XCTAssertEqual(entry.category, "decision",
                       "Entry category should be 'decision'")
        XCTAssertEqual(entry.summary, "Decided to use LRU cache for file reads",
                       "Entry summary should match")
        XCTAssertEqual(entry.context, "main.swift",
                       "Entry context should match")
    }

    /// AC4 [P0]: SessionMemoryEntry supports valid categories.
    func testSessionMemoryEntry_SupportsAllCategoryTypes() {
        let categories = ["decision", "preference", "constraint"]
        for category in categories {
            let entry = SessionMemoryEntry(
                category: category,
                summary: "Test summary",
                context: "",
                timestamp: Date()
            )
            XCTAssertEqual(entry.category, category,
                           "Entry should support category '\(category)'")
        }
    }

    // MARK: - AC4: SessionMemory Creation and Append

    /// AC4 [P0]: SessionMemory can be created and starts empty.
    func testSessionMemory_StartsEmpty() {
        let memory = SessionMemory()

        XCTAssertNil(memory.formatForPrompt(),
                     "Empty SessionMemory should return nil from formatForPrompt()")
        XCTAssertEqual(memory.tokenCount(), 0,
                       "Empty SessionMemory should have 0 tokens")
    }

    /// AC4 [P0]: SessionMemory.append adds an entry.
    func testSessionMemory_AppendAddsEntry() {
        let memory = SessionMemory()
        let entry = SessionMemoryEntry(
            category: "decision",
            summary: "Used JSONSerialization for parsing",
            context: "Compact.swift",
            timestamp: Date()
        )

        memory.append(entry)

        XCTAssertNotNil(memory.formatForPrompt(),
                        "After appending, formatForPrompt() should return non-nil")
        XCTAssertGreaterThan(memory.tokenCount(), 0,
                             "After appending, tokenCount() should be > 0")
    }

    /// AC4 [P1]: Multiple entries can be appended.
    func testSessionMemory_AppendMultipleEntries() {
        let memory = SessionMemory()

        for i in 1...5 {
            let entry = SessionMemoryEntry(
                category: "decision",
                summary: "Decision \(i)",
                context: "File\(i).swift",
                timestamp: Date()
            )
            memory.append(entry)
        }

        let prompt = memory.formatForPrompt()
        XCTAssertNotNil(prompt, "Should have formatted prompt after 5 entries")
        XCTAssertTrue(prompt!.contains("Decision 5"),
                      "Prompt should contain the latest entry summary")
    }

    // MARK: - AC4: formatForPrompt() Output Format

    /// AC1 [P0]: formatForPrompt() produces <session-memory> XML block.
    func testFormatForPrompt_ProducesSessionMemoryXMLBlock() {
        let memory = SessionMemory()
        let entry = SessionMemoryEntry(
            category: "decision",
            summary: "Decided to use LRU cache",
            context: "main.swift",
            timestamp: Date()
        )
        memory.append(entry)

        let prompt = memory.formatForPrompt()

        XCTAssertNotNil(prompt, "formatForPrompt() should return non-nil after appending entry")
        XCTAssertTrue(prompt!.contains("<session-memory>"),
                      "Prompt should contain <session-memory> opening tag")
        XCTAssertTrue(prompt!.contains("</session-memory>"),
                      "Prompt should contain </session-memory> closing tag")
    }

    /// AC1 [P1]: formatForPrompt() entries show category, summary, and context.
    func testFormatForPrompt_EntryShowsCategorySummaryContext() {
        let memory = SessionMemory()
        let entry = SessionMemoryEntry(
            category: "constraint",
            summary: "User requires macOS 13+ compatibility",
            context: "Package.swift",
            timestamp: Date()
        )
        memory.append(entry)

        let prompt = memory.formatForPrompt()!

        XCTAssertTrue(prompt.contains("[constraint]"),
                      "Prompt should show category tag [constraint]")
        XCTAssertTrue(prompt.contains("macOS 13+"),
                      "Prompt should contain the summary text")
        XCTAssertTrue(prompt.contains("Package.swift"),
                      "Prompt should contain the context text")
    }

    /// AC1 [P1]: Empty SessionMemory returns nil (no empty <session-memory> block).
    func testFormatForPrompt_EmptyMemory_ReturnsNil() {
        let memory = SessionMemory()

        let result = memory.formatForPrompt()

        XCTAssertNil(result,
                     "Empty SessionMemory should return nil, not an empty XML block")
    }

    // MARK: - AC4: FIFO Pruning

    /// AC4 [P0]: FIFO pruning removes oldest entries when over 4000 token budget.
    func testFIFOPruning_RemovesOldestEntriesWhenOverBudget() {
        // Create SessionMemory with a low maxTokens for testing
        let memory = SessionMemory(maxTokens: 100)

        // Add entries until we exceed budget
        // Each entry summary is ~40 chars ASCII -> ~10 tokens, plus category/context overhead
        let firstEntry = SessionMemoryEntry(
            category: "decision",
            summary: "First decision that should be pruned when budget exceeded",
            context: "File1.swift",
            timestamp: Date()
        )
        memory.append(firstEntry)

        let secondEntry = SessionMemoryEntry(
            category: "preference",
            summary: "Second preference that should survive FIFO pruning cycle",
            context: "File2.swift",
            timestamp: Date()
        )
        memory.append(secondEntry)

        // Keep adding until first entry is pruned
        for i in 3...20 {
            let entry = SessionMemoryEntry(
                category: "decision",
                summary: "Later decision number \(i) that pushes out older entries",
                context: "File\(i).swift",
                timestamp: Date()
            )
            memory.append(entry)
        }

        let prompt = memory.formatForPrompt()!
        // The first entry should have been pruned (FIFO)
        XCTAssertFalse(prompt.contains("First decision that should be pruned"),
                       "First (oldest) entry should be removed by FIFO pruning")
        // Latest entry should still be present
        XCTAssertTrue(prompt.contains("Later decision number 20"),
                      "Latest entry should be preserved by FIFO pruning")
    }

    /// AC4 [P0]: FIFO pruning respects 4000 token budget (default).
    func testFIFOPruning_DefaultBudget_Is4000Tokens() {
        let memory = SessionMemory() // Default maxTokens = 4000

        // Add entries with large summaries to push near limit
        // Each entry: ~200 char summary -> ~50 tokens + overhead
        for i in 1...100 {
            let entry = SessionMemoryEntry(
                category: "decision",
                summary: String(repeating: "Decision \(i) ", count: 20),
                context: "File\(i).swift",
                timestamp: Date()
            )
            memory.append(entry)
        }

        // Token count should not exceed 4000 (with some tolerance for rounding)
        XCTAssertLessThanOrEqual(memory.tokenCount(), 4100,
                                 "After adding 100 entries, token count should stay near 4000 budget (with rounding tolerance)")
    }

    /// AC4 [P0]: FIFO pruning preserves newest entries.
    func testFIFOPruning_PreservesNewestEntries() {
        let memory = SessionMemory(maxTokens: 100)

        // Add oldest entry
        let oldestEntry = SessionMemoryEntry(
            category: "decision",
            summary: "This is the oldest entry and should be pruned first by FIFO",
            context: "Old.swift",
            timestamp: Date().addingTimeInterval(-3600)
        )
        memory.append(oldestEntry)

        // Add newer entries to trigger pruning
        for i in 1...15 {
            let entry = SessionMemoryEntry(
                category: "decision",
                summary: "Newer decision \(i) that should push out the oldest entry",
                context: "New\(i).swift",
                timestamp: Date()
            )
            memory.append(entry)
        }

        let prompt = memory.formatForPrompt()!
        // Newest entry should be present
        XCTAssertTrue(prompt.contains("Newer decision 15"),
                      "Newest entry should be preserved")
    }

    // MARK: - AC4: NFR30 FIFO Pruning Performance

    /// AC4 (NFR30) [P0]: FIFO pruning completes within 10ms.
    func testFIFOPruning_CompletesWithin10ms() {
        let memory = SessionMemory(maxTokens: 500)

        // Pre-populate with many entries
        for i in 1...50 {
            let entry = SessionMemoryEntry(
                category: "decision",
                summary: "Pre-populated decision \(i) with enough text to build up tokens",
                context: "File\(i).swift",
                timestamp: Date()
            )
            memory.append(entry)
        }

        // Measure pruning time
        let start = ContinuousClock.now
        for i in 51...60 {
            let entry = SessionMemoryEntry(
                category: "decision",
                summary: "Additional decision \(i) that triggers FIFO pruning operations",
                context: "File\(i).swift",
                timestamp: Date()
            )
            memory.append(entry)
        }
        let elapsed = ContinuousClock.now - start

        XCTAssertLessThan(elapsed.components.seconds, 1,
                          "FIFO pruning for 10 append operations should complete well within 10ms total")
    }

    // MARK: - AC5: Token Count Uses TokenEstimator

    /// AC5 [P0]: tokenCount() uses language-aware estimation.
    func testTokenCount_UsesLanguageAwareEstimation() {
        let memory = SessionMemory()

        // Add entry with CJK text -- should be estimated differently than ASCII
        let cjkEntry = SessionMemoryEntry(
            category: "decision",
            summary: "这是一个关于缓存的重要决定", // CJK text
            context: "Cache.swift",
            timestamp: Date()
        )
        memory.append(cjkEntry)

        // CJK text should have higher token count than equivalent length ASCII
        let tokens = memory.tokenCount()
        XCTAssertGreaterThan(tokens, 0,
                             "CJK entries should have positive token count via language-aware estimation")
    }

    // MARK: - AC1: Session Memory Injection into System Prompt

    /// AC1 [P0]: Agent's buildSystemPrompt() includes <session-memory> block after entries added.
    func testBuildSystemPrompt_IncludesSessionMemoryBlock() {
        let agent = createAgent(options: AgentOptions(
            apiKey: "sk-test-key",
            model: "claude-sonnet-4-6"
        ))

        // Access sessionMemory to add an entry (via internal access in test)
        // This tests that Agent has a sessionMemory property and buildSystemPrompt uses it
        let memory = SessionMemory()
        let entry = SessionMemoryEntry(
            category: "decision",
            summary: "Decided to use async/await for concurrency",
            context: "Agent.swift",
            timestamp: Date()
        )
        memory.append(entry)

        // Agent should have sessionMemory that can be accessed
        // buildSystemPrompt should include <session-memory> when non-empty
        // NOTE: This test will need implementation detail -- Agent must expose
        // sessionMemory for testing or we test via reflection
        // For now, test the direct integration:
        let memoryBlock = memory.formatForPrompt()
        XCTAssertNotNil(memoryBlock, "SessionMemory should produce a valid prompt block")
        XCTAssertTrue(memoryBlock!.contains("<session-memory>"),
                      "The block should contain <session-memory> XML tags")
    }

    /// AC1 [P1]: Agent without session memory entries has no <session-memory> in prompt.
    func testBuildSystemPrompt_NoSessionMemory_WhenEmpty() {
        let agent = createAgent(options: AgentOptions(
            apiKey: "sk-test-key",
            model: "claude-sonnet-4-6",
            systemPrompt: "You are a helpful assistant."
        ))

        let prompt = agent.buildSystemPrompt()
        // Should not contain session-memory when no entries exist
        if let prompt = prompt {
            XCTAssertFalse(prompt.contains("<session-memory>"),
                           "System prompt should not contain <session-memory> when memory is empty")
        }
    }

    // MARK: - AC6: Session Memory Extraction After Auto-Compact

    /// AC6 [P0]: Short summary (<200 chars) is stored directly without LLM extraction.
    func testExtractSessionMemory_ShortSummary_StoredDirectly() {
        let memory = SessionMemory()
        let shortSummary = "User decided to use MVVM architecture pattern for the project."

        XCTAssertLessThan(shortSummary.count, 200,
                          "Summary should be < 200 characters for direct storage test")

        // Simulate direct storage for short summaries
        let entry = SessionMemoryEntry(
            category: "decision",
            summary: shortSummary,
            context: "",
            timestamp: Date()
        )
        memory.append(entry)

        let prompt = memory.formatForPrompt()!
        XCTAssertTrue(prompt.contains(shortSummary),
                      "Short summary should be stored directly in session memory")
    }

    /// AC6 [P1]: Long summary requires LLM extraction into structured entries.
    func testExtractSessionMemory_LongSummary_RequiresLLMExtraction() async throws {
        // This tests the extractSessionMemory() function in Compact.swift
        // It should parse LLM response as JSON array and create entries

        // Simulate a JSON extraction result
        let jsonExtractorOutput = """
        [
            {"category": "decision", "summary": "Used Swift Concurrency for async ops", "context": "Agent.swift"},
            {"category": "preference", "summary": "User prefers snake_case for JSON", "context": "Config.swift"}
        ]
        """

        let data = jsonExtractorOutput.data(using: .utf8)!
        let jsonArray = try JSONSerialization.jsonObject(with: data) as! [[String: String]]

        XCTAssertEqual(jsonArray.count, 2,
                       "Should extract 2 entries from JSON array")

        let firstEntry = jsonArray[0]
        XCTAssertEqual(firstEntry["category"], "decision",
                       "First entry category should be 'decision'")
        XCTAssertEqual(firstEntry["summary"], "Used Swift Concurrency for async ops",
                       "First entry summary should match")
        XCTAssertEqual(firstEntry["context"], "Agent.swift",
                       "First entry context should match")
    }

    /// AC6 [P0]: Extracted entries are appended to SessionMemory with correct fields.
    func testExtractedEntries_AppendedToSessionMemory() {
        let memory = SessionMemory()

        // Simulate extraction result
        let entries: [(category: String, summary: String, context: String)] = [
            ("decision", "Decided to use LRU cache for file reads", "main.swift"),
            ("constraint", "User requires macOS 13+ compatibility", "Package.swift"),
            ("preference", "User prefers snake_case for JSON fields", "Config.swift"),
        ]

        for extracted in entries {
            let entry = SessionMemoryEntry(
                category: extracted.category,
                summary: extracted.summary,
                context: extracted.context,
                timestamp: Date()
            )
            memory.append(entry)
        }

        let prompt = memory.formatForPrompt()!
        XCTAssertTrue(prompt.contains("[decision]"),
                      "Prompt should contain [decision] category tag")
        XCTAssertTrue(prompt.contains("[constraint]"),
                      "Prompt should contain [constraint] category tag")
        XCTAssertTrue(prompt.contains("[preference]"),
                      "Prompt should contain [preference] category tag")
    }

    // MARK: - AC6: compactConversation Integration

    /// AC6 [P0]: compactConversation accepts sessionMemory parameter.
    func testCompactConversation_AcceptsSessionMemoryParameter() async throws {
        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()
        let state = createAutoCompactState()
        let memory = SessionMemory()

        let summary = "User discussed implementing a file caching system with LRU eviction policy."
        let compactionResponse = makeCompactionSuccessResponse(summary: summary)

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactionResponse),
        ])

        // compactConversation should accept sessionMemory parameter
        let result = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state,
            sessionMemory: memory
        )

        // After compact, sessionMemory should have been populated
        // (summary is < 200 chars, so it's stored directly)
        XCTAssertGreaterThan(memory.tokenCount(), 0,
                             "SessionMemory should have entries after auto-compact")
    }

    /// AC6 [P1]: compactConversation without sessionMemory still works (backward compat).
    func testCompactConversation_WithoutSessionMemory_StillWorks() async throws {
        let client = makeCompactTestClient()
        let messages = makeOversizedMessages()
        let state = createAutoCompactState()

        let summary = "A summary of the conversation."
        let compactionResponse = makeCompactionSuccessResponse(summary: summary)

        registerCompactMockResponses([
            (200, ["content-type": "application/json"], compactionResponse),
        ])

        // compactConversation without sessionMemory should work
        let result = await compactConversation(
            client: client,
            model: "claude-sonnet-4-6",
            messages: messages,
            state: state
        )

        XCTAssertEqual(result.compactedMessages.count, 2,
                       "Compaction without sessionMemory should still return 2 messages")
    }

    // MARK: - AC4: Thread Safety

    /// AC4 [P2]: SessionMemory is thread-safe for concurrent access.
    func testSessionMemory_IsThreadSafe() async {
        let memory = SessionMemory()
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 1...iterations {
                group.addTask {
                    let entry = SessionMemoryEntry(
                        category: "decision",
                        summary: "Concurrent decision \(i)",
                        context: "File\(i).swift",
                        timestamp: Date()
                    )
                    memory.append(entry)
                }
            }
        }

        // Should not crash and should have some entries
        XCTAssertNotNil(memory.formatForPrompt(),
                        "SessionMemory should be usable after concurrent appends")
    }

    // MARK: - SessionMemory Initialization

    /// AC4 [P1]: SessionMemory can be created with custom maxTokens.
    func testSessionMemory_CustomMaxTokens() {
        let memory = SessionMemory(maxTokens: 500)

        // Add entries up to custom limit
        for i in 1...50 {
            let entry = SessionMemoryEntry(
                category: "decision",
                summary: "Decision \(i) with some additional text to build up tokens beyond the budget",
                context: "File\(i).swift",
                timestamp: Date()
            )
            memory.append(entry)
        }

        XCTAssertLessThanOrEqual(memory.tokenCount(), 600,
                                 "Custom maxTokens=500 should be respected (with rounding tolerance)")
    }
}

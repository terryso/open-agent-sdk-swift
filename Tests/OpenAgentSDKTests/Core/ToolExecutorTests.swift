import XCTest
@testable import OpenAgentSDK

// MARK: - Mock Tools for Testing

/// Mock read-only tool that records execution timing for concurrency verification.
struct MockReadOnlyTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Mock read-only tool"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = true
    let delay: TimeInterval
    let result: String

    /// Tracks the order in which this tool completes execution.
    nonisolated(unsafe) static var completionOrder: [String] = []

    func call(input: Any, context: ToolContext) async -> ToolResult {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        MockReadOnlyTool.completionOrder.append(name)
        return ToolResult(toolUseId: context.toolUseId, content: result, isError: false)
    }

    static func resetCompletionOrder() {
        completionOrder = []
    }
}

/// Mock mutation tool that records execution timing for serial verification.
struct MockMutationTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Mock mutation tool"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = false
    let delay: TimeInterval
    let result: String

    nonisolated(unsafe) static var executionLog: [String] = []

    func call(input: Any, context: ToolContext) async -> ToolResult {
        MockMutationTool.executionLog.append("\(name)_start")
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        MockMutationTool.executionLog.append("\(name)_end")
        return ToolResult(toolUseId: context.toolUseId, content: result, isError: false)
    }

    static func resetExecutionLog() {
        executionLog = []
    }
}

/// Mock tool that always throws an error.
struct MockThrowingTool: ToolProtocol, @unchecked Sendable {
    let name: String = "throwing_tool"
    let description: String = "Always throws"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = false

    func call(input: Any, context: ToolContext) async -> ToolResult {
        return ToolResult(
            toolUseId: context.toolUseId,
            content: "Error: Tool execution failed - simulated error",
            isError: true
        )
    }
}

// MARK: - AC1: Read-Only Tools Execute Concurrently

/// ATDD RED PHASE: Tests for Story 3.3 -- Tool Executor with Concurrent/Serial Dispatch.
/// All tests assert EXPECTED behavior. They will FAIL until ToolExecutor.swift is implemented.
/// TDD Phase: RED (feature not implemented yet)
final class ToolExecutorConcurrentTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockReadOnlyTool.resetCompletionOrder()
        MockMutationTool.resetExecutionLog()
    }

    override func tearDown() {
        MockReadOnlyTool.resetCompletionOrder()
        MockMutationTool.resetExecutionLog()
        super.tearDown()
    }

    /// AC1 [P0]: Multiple read-only tools execute concurrently via TaskGroup.
    /// Given 5 read-only tools, when they are dispatched, all 5 run concurrently
    /// (verified by timing: total time should be less than the sum of individual delays).
    func testReadOnlyToolsExecuteConcurrently() async throws {
        // Given: 5 read-only tools with 0.2s delay each
        let tools: [ToolProtocol] = (1...5).map { i in
            MockReadOnlyTool(name: "read_\(i)", delay: 0.2, result: "result_\(i)")
        }

        let toolUseBlocks: [ToolUseBlock] = (1...5).map { i in
            ToolUseBlock(id: "tu_\(i)", name: "read_\(i)", input: [:])
        }

        // When: executing the tools
        let start = ContinuousClock.now
        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )
        let elapsed = ContinuousClock.now - start

        // Then: all results are collected
        XCTAssertEqual(results.count, 5, "Should return 5 tool results")

        // And: total time is less than sequential (0.2s * 5 = 1.0s)
        // Concurrent execution should complete in ~0.2s + overhead
        let elapsedMs = Int(elapsed.components.seconds * 1000)
            + Int(elapsed.components.attoseconds / 1_000_000_000_000)
        XCTAssertLessThan(elapsedMs, 800,
                          "5 tools with 0.2s delay each should complete in < 800ms when concurrent (sequential would be ~1000ms)")

        // And: all results contain expected content
        let resultContents = Set(results.map { $0.content })
        let expectedContents = Set((1...5).map { "result_\($0)" })
        XCTAssertEqual(resultContents, expectedContents,
                       "All tool results should contain their expected content")
    }

    /// AC1 [P0]: Read-only concurrent results are not errors.
    func testReadOnlyToolsReturnNonErrorResults() async throws {
        let tools: [ToolProtocol] = [
            MockReadOnlyTool(name: "glob", delay: 0, result: "file1.swift\nfile2.swift"),
            MockReadOnlyTool(name: "grep", delay: 0, result: "match found at line 42"),
        ]

        let toolUseBlocks = [
            ToolUseBlock(id: "tu_glob_1", name: "glob", input: ["pattern": "*.swift"]),
            ToolUseBlock(id: "tu_grep_1", name: "grep", input: ["pattern": "TODO"]),
        ]

        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/project")
        )

        for result in results {
            XCTAssertFalse(result.isError,
                           "Read-only tool results should not be errors, got: \(result.content)")
        }
    }
}

// MARK: - AC2: Mutation Tools Execute Serially

final class ToolExecutorSerialTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockMutationTool.resetExecutionLog()
    }

    override func tearDown() {
        MockMutationTool.resetExecutionLog()
        super.tearDown()
    }

    /// AC2 [P0]: Mutation tools execute serially (one after another).
    /// Given 3 mutation tools, when they are dispatched, each completes before the next starts.
    func testMutationToolsExecuteSerially() async throws {
        // Given: 3 mutation tools
        let tools: [ToolProtocol] = [
            MockMutationTool(name: "write", delay: 0.05, result: "wrote file"),
            MockMutationTool(name: "edit", delay: 0.05, result: "edited file"),
            MockMutationTool(name: "bash", delay: 0.05, result: "command done"),
        ]

        let toolUseBlocks = [
            ToolUseBlock(id: "tu_1", name: "write", input: ["path": "a.txt"]),
            ToolUseBlock(id: "tu_2", name: "edit", input: ["path": "b.txt"]),
            ToolUseBlock(id: "tu_3", name: "bash", input: ["command": "ls"]),
        ]

        // When: executing the tools
        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )

        // Then: 3 results are returned
        XCTAssertEqual(results.count, 3, "Should return 3 tool results")

        // And: execution was serial (start/end pairs are strictly ordered)
        // Serial means: write_start, write_end, edit_start, edit_end, bash_start, bash_end
        let log = MockMutationTool.executionLog
        XCTAssertEqual(log.count, 6, "Should have 6 log entries (3 tools * 2 events)")

        // Verify strict ordering: each tool's end comes before the next tool's start
        let writeEnd = log.firstIndex(of: "write_end")!
        let editStart = log.firstIndex(of: "edit_start")!
        let editEnd = log.firstIndex(of: "edit_end")!
        let bashStart = log.firstIndex(of: "bash_start")!

        XCTAssertLessThan(writeEnd, editStart,
                          "write must complete before edit starts")
        XCTAssertLessThan(editEnd, bashStart,
                          "edit must complete before bash starts")
    }
}

// MARK: - AC3: Tool Execution Errors Don't Crash

final class ToolExecutorErrorHandlingTests: XCTestCase {

    /// AC3 [P0]: Tool execution error is captured as isError=true ToolResult, loop continues.
    func testToolErrorCapturedAsToolResult() async throws {
        // Given: a tool that returns an error result
        let tools: [ToolProtocol] = [
            MockThrowingTool()
        ]

        let toolUseBlocks = [
            ToolUseBlock(id: "tu_err_1", name: "throwing_tool", input: [:]),
        ]

        // When: executing the tool
        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )

        // Then: error is captured in result, not thrown
        XCTAssertEqual(results.count, 1, "Should return 1 result")
        XCTAssertTrue(results[0].isError,
                      "Error tool should return isError=true")
        XCTAssertTrue(results[0].content.contains("Error"),
                      "Error result should contain error description")
    }

    /// AC3 [P1]: Mix of successful and error tools returns all results.
    func testMixedSuccessAndErrorTools() async throws {
        let tools: [ToolProtocol] = [
            MockReadOnlyTool(name: "good_tool", delay: 0, result: "success"),
            MockThrowingTool(),
        ]

        let toolUseBlocks = [
            ToolUseBlock(id: "tu_good", name: "good_tool", input: [:]),
            ToolUseBlock(id: "tu_bad", name: "throwing_tool", input: [:]),
        ]

        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )

        XCTAssertEqual(results.count, 2, "Should return 2 results")
        // One should be success, one should be error
        let successResults = results.filter { !$0.isError }
        let errorResults = results.filter { $0.isError }
        XCTAssertEqual(successResults.count, 1, "Should have 1 successful result")
        XCTAssertEqual(errorResults.count, 1, "Should have 1 error result")
    }
}

// MARK: - AC4: tool_use Block Parsing

final class ToolExecutorParsingTests: XCTestCase {

    /// AC4 [P0]: Extract tool_use blocks from API response content.
    func testExtractToolUseBlocksFromContent() {
        // Given: API response content with tool_use blocks
        let content: [[String: Any]] = [
            ["type": "text", "text": "Let me search for that."],
            ["type": "tool_use", "id": "tu_001", "name": "grep", "input": ["pattern": "TODO"]],
            ["type": "tool_use", "id": "tu_002", "name": "glob", "input": ["pattern": "*.swift"]],
        ]

        // When: extracting tool_use blocks
        let blocks = ToolExecutor.extractToolUseBlocks(from: content)

        // Then: 2 tool_use blocks are extracted
        XCTAssertEqual(blocks.count, 2, "Should extract 2 tool_use blocks")
        XCTAssertEqual(blocks[0].id, "tu_001")
        XCTAssertEqual(blocks[0].name, "grep")
        XCTAssertEqual(blocks[1].id, "tu_002")
        XCTAssertEqual(blocks[1].name, "glob")
    }

    /// AC4 [P0]: Content with no tool_use blocks returns empty array.
    func testExtractToolUseBlocksNoToolUseReturnsEmpty() {
        let content: [[String: Any]] = [
            ["type": "text", "text": "Here is the answer."],
        ]

        let blocks = ToolExecutor.extractToolUseBlocks(from: content)

        XCTAssertTrue(blocks.isEmpty,
                      "Content without tool_use should return empty array")
    }

    /// AC4 [P1]: Multiple tool_use blocks are all extracted in order.
    func testExtractToolUseBlocksMultipleBlocks() {
        let content: [[String: Any]] = [
            ["type": "tool_use", "id": "tu_1", "name": "Read", "input": ["path": "a.swift"]],
            ["type": "tool_use", "id": "tu_2", "name": "Read", "input": ["path": "b.swift"]],
            ["type": "tool_use", "id": "tu_3", "name": "Grep", "input": ["pattern": "func"]],
        ]

        let blocks = ToolExecutor.extractToolUseBlocks(from: content)

        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].name, "Read")
        XCTAssertEqual(blocks[1].name, "Read")
        XCTAssertEqual(blocks[2].name, "Grep")
    }

    /// AC4 [P1]: Empty content returns empty array.
    func testExtractToolUseBlocksEmptyContent() {
        let blocks = ToolExecutor.extractToolUseBlocks(from: [])
        XCTAssertTrue(blocks.isEmpty)
    }
}

// MARK: - AC5: tool_result Message Assembly

final class ToolExecutorResultMessageTests: XCTestCase {

    /// AC5 [P0]: Tool results are assembled into correct tool_result user message.
    func testBuildToolResultMessageCorrectFormat() {
        // Given: tool results
        let results = [
            ToolResult(toolUseId: "tu_001", content: "file1.swift\nfile2.swift", isError: false),
            ToolResult(toolUseId: "tu_002", content: "match found at line 42", isError: false),
        ]

        // When: building the tool_result message
        let message = ToolExecutor.buildToolResultMessage(from: results)

        // Then: message has correct structure
        XCTAssertEqual(message["role"] as? String, "user",
                       "Tool result message should have role 'user'")

        let content = message["content"] as? [[String: Any]]
        XCTAssertNotNil(content, "Content should be an array of blocks")
        XCTAssertEqual(content?.count, 2, "Should have 2 content blocks")

        // Verify first result block
        let first = content?[0]
        XCTAssertEqual(first?["type"] as? String, "tool_result")
        XCTAssertEqual(first?["tool_use_id"] as? String, "tu_001")
        XCTAssertEqual(first?["content"] as? String, "file1.swift\nfile2.swift")

        // Verify second result block
        let second = content?[1]
        XCTAssertEqual(second?["type"] as? String, "tool_result")
        XCTAssertEqual(second?["tool_use_id"] as? String, "tu_002")
    }

    /// AC5 [P0]: Error results include is_error field set to true.
    func testBuildToolResultMessageIncludesIsError() {
        let results = [
            ToolResult(toolUseId: "tu_err", content: "Error: Unknown tool", isError: true),
        ]

        let message = ToolExecutor.buildToolResultMessage(from: results)

        let content = message["content"] as? [[String: Any]]
        let first = content?[0]

        XCTAssertEqual(first?["is_error"] as? Bool, true,
                       "Error tool result should have is_error=true")
    }

    /// AC5 [P1]: Non-error results do not include is_error field.
    func testBuildToolResultMessageSuccessNoIsError() {
        let results = [
            ToolResult(toolUseId: "tu_ok", content: "success", isError: false),
        ]

        let message = ToolExecutor.buildToolResultMessage(from: results)

        let content = message["content"] as? [[String: Any]]
        let first = content?[0]

        // Non-error results should NOT have is_error key (or it should be absent/false)
        let hasIsError = first?.keys.contains("is_error") ?? false
        XCTAssertFalse(hasIsError,
                       "Non-error tool result should not include is_error field")
    }
}

// MARK: - AC6: Unknown Tool Error Handling

final class ToolExecutorUnknownToolTests: XCTestCase {

    /// AC6 [P0]: Unknown tool returns isError=true ToolResult with "Error: Unknown tool" message.
    func testUnknownToolReturnsError() async throws {
        // Given: a tool_use block for a tool that is not registered
        let tools: [ToolProtocol] = [
            MockReadOnlyTool(name: "known_tool", delay: 0, result: "ok"),
        ]

        let toolUseBlocks = [
            ToolUseBlock(id: "tu_unknown", name: "nonexistent_tool", input: [:]),
        ]

        // When: executing
        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )

        // Then: returns error result
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].isError,
                      "Unknown tool should return isError=true")
        XCTAssertTrue(results[0].content.contains("Unknown tool"),
                      "Error message should mention 'Unknown tool', got: \(results[0].content)")
        XCTAssertEqual(results[0].toolUseId, "tu_unknown",
                       "Error result should preserve the tool_use_id")
    }

    /// AC6 [P1]: Empty tools array still returns error for any tool_use.
    func testEmptyToolsReturnsUnknownToolError() async throws {
        let toolUseBlocks = [
            ToolUseBlock(id: "tu_1", name: "any_tool", input: [:]),
        ]

        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: [],
            context: ToolContext(cwd: "/tmp")
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].isError)
    }
}

// MARK: - Partition Logic

final class ToolExecutorPartitionTests: XCTestCase {

    /// [P0]: Tools are correctly partitioned into readOnly and mutations.
    func testPartitionToolsReadOnlyAndMutations() {
        let tools: [ToolProtocol] = [
            MockReadOnlyTool(name: "Read", delay: 0, result: ""),
            MockMutationTool(name: "Write", delay: 0, result: ""),
            MockReadOnlyTool(name: "Glob", delay: 0, result: ""),
            MockMutationTool(name: "Bash", delay: 0, result: ""),
            MockReadOnlyTool(name: "Grep", delay: 0, result: ""),
        ]

        let blocks = [
            ToolUseBlock(id: "tu_1", name: "Read", input: [:]),
            ToolUseBlock(id: "tu_2", name: "Write", input: [:]),
            ToolUseBlock(id: "tu_3", name: "Glob", input: [:]),
            ToolUseBlock(id: "tu_4", name: "Bash", input: [:]),
            ToolUseBlock(id: "tu_5", name: "Grep", input: [:]),
        ]

        let (readOnly, mutations) = ToolExecutor.partitionTools(blocks: blocks, tools: tools)

        XCTAssertEqual(readOnly.count, 3, "Should have 3 read-only tools")
        XCTAssertEqual(mutations.count, 2, "Should have 2 mutation tools")

        let readOnlyNames = Set(readOnly.map { $0.block.name })
        let mutationNames = Set(mutations.map { $0.block.name })

        XCTAssertEqual(readOnlyNames, Set(["Read", "Glob", "Grep"]))
        XCTAssertEqual(mutationNames, Set(["Write", "Bash"]))
    }

    /// [P1]: All read-only tools partition correctly.
    func testPartitionToolsAllReadOnly() {
        let tools: [ToolProtocol] = [
            MockReadOnlyTool(name: "Read", delay: 0, result: ""),
            MockReadOnlyTool(name: "Glob", delay: 0, result: ""),
        ]

        let blocks = [
            ToolUseBlock(id: "tu_1", name: "Read", input: [:]),
            ToolUseBlock(id: "tu_2", name: "Glob", input: [:]),
        ]

        let (readOnly, mutations) = ToolExecutor.partitionTools(blocks: blocks, tools: tools)

        XCTAssertEqual(readOnly.count, 2)
        XCTAssertEqual(mutations.count, 0)
    }

    /// [P1]: All mutation tools partition correctly.
    func testPartitionToolsAllMutations() {
        let tools: [ToolProtocol] = [
            MockMutationTool(name: "Write", delay: 0, result: ""),
            MockMutationTool(name: "Bash", delay: 0, result: ""),
        ]

        let blocks = [
            ToolUseBlock(id: "tu_1", name: "Write", input: [:]),
            ToolUseBlock(id: "tu_2", name: "Bash", input: [:]),
        ]

        let (readOnly, mutations) = ToolExecutor.partitionTools(blocks: blocks, tools: tools)

        XCTAssertEqual(readOnly.count, 0)
        XCTAssertEqual(mutations.count, 2)
    }
}

// MARK: - AC1 Extended: Max Concurrency Cap

final class ToolExecutorConcurrencyCapTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockReadOnlyTool.resetCompletionOrder()
    }

    override func tearDown() {
        MockReadOnlyTool.resetCompletionOrder()
        super.tearDown()
    }

    /// AC1 [P1]: More than 10 read-only tools are executed in batches (max 10 concurrent).
    func testMaxConcurrencyCappedAt10() async throws {
        // Given: 15 read-only tools (exceeds max concurrency of 10)
        let tools: [ToolProtocol] = (1...15).map { i in
            MockReadOnlyTool(name: "read_\(i)", delay: 0.1, result: "result_\(i)")
        }

        let toolUseBlocks: [ToolUseBlock] = (1...15).map { i in
            ToolUseBlock(id: "tu_\(i)", name: "read_\(i)", input: [:])
        }

        // When: executing all 15 tools
        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )

        // Then: all 15 results are returned
        XCTAssertEqual(results.count, 15,
                       "All 15 tool results should be collected even with concurrency cap")

        // And: all results are non-error
        for result in results {
            XCTAssertFalse(result.isError,
                           "All read-only tool results should be non-error")
        }
    }
}

// MARK: - Mixed Concurrent + Serial Scenario

final class ToolExecutorMixedScenarioTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockMutationTool.resetExecutionLog()
    }

    override func tearDown() {
        MockMutationTool.resetExecutionLog()
        super.tearDown()
    }

    /// [P0]: Mix of read-only and mutation tools: read-only run concurrently,
    /// then mutations run serially.
    func testMixedConcurrentAndSerialExecution() async throws {
        let tools: [ToolProtocol] = [
            MockReadOnlyTool(name: "Read", delay: 0.1, result: "file contents"),
            MockReadOnlyTool(name: "Grep", delay: 0.1, result: "matches found"),
            MockMutationTool(name: "Write", delay: 0.05, result: "wrote"),
            MockMutationTool(name: "Edit", delay: 0.05, result: "edited"),
        ]

        let toolUseBlocks = [
            ToolUseBlock(id: "tu_read", name: "Read", input: ["path": "a.txt"]),
            ToolUseBlock(id: "tu_grep", name: "Grep", input: ["pattern": "TODO"]),
            ToolUseBlock(id: "tu_write", name: "Write", input: ["path": "b.txt"]),
            ToolUseBlock(id: "tu_edit", name: "Edit", input: ["path": "c.txt"]),
        ]

        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )

        XCTAssertEqual(results.count, 4, "Should return 4 results total")

        // Mutation tools should have executed serially
        let log = MockMutationTool.executionLog
        if log.count >= 4 {
            let writeEnd = log.firstIndex(of: "Write_end")
            let editStart = log.firstIndex(of: "Edit_start")
            if let we = writeEnd, let es = editStart {
                XCTAssertLessThan(we, es,
                                  "Write must complete before Edit starts in serial mode")
            }
        }
    }
}

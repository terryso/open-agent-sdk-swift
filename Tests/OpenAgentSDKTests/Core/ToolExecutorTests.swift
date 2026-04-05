import XCTest
@testable import OpenAgentSDK

// MARK: - Thread-Safe Test Tracker

/// Thread-safe tracker for recording tool execution events in tests.
/// Uses an actor to prevent data races from concurrent tool completions.
actor ToolTestTracker {
    private var order: [String] = []
    private var log: [String] = []

    func appendOrder(_ name: String) {
        order.append(name)
    }

    func appendLog(_ entry: String) {
        log.append(entry)
    }

    func getOrder() -> [String] {
        order
    }

    func getLog() -> [String] {
        log
    }

    func reset() {
        order = []
        log = []
    }
}

// MARK: - Mock Tools for Testing

/// Mock read-only tool that records execution timing for concurrency verification.
struct MockReadOnlyTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Mock read-only tool"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = true
    let delay: TimeInterval
    let result: String

    static let tracker = ToolTestTracker()

    func call(input: Any, context: ToolContext) async -> ToolResult {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        await MockReadOnlyTool.tracker.appendOrder(name)
        return ToolResult(toolUseId: context.toolUseId, content: result, isError: false)
    }

    static func resetCompletionOrder() async {
        await tracker.reset()
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

    static let tracker = ToolTestTracker()

    func call(input: Any, context: ToolContext) async -> ToolResult {
        await MockMutationTool.tracker.appendLog("\(name)_start")
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        await MockMutationTool.tracker.appendLog("\(name)_end")
        return ToolResult(toolUseId: context.toolUseId, content: result, isError: false)
    }

    static func resetExecutionLog() async {
        await tracker.reset()
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

    override func setUp() async throws {
        try await super.setUp()
        await MockReadOnlyTool.resetCompletionOrder()
        await MockMutationTool.resetExecutionLog()
    }

    override func tearDown() async throws {
        await MockReadOnlyTool.resetCompletionOrder()
        await MockMutationTool.resetExecutionLog()
        try await super.tearDown()
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
        XCTAssertLessThan(elapsedMs, 2500,
                          "5 tools with 0.2s delay each should complete in < 2500ms when concurrent (sequential would be ~1000ms)")

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

    override func setUp() async throws {
        try await super.setUp()
        await MockMutationTool.resetExecutionLog()
    }

    override func tearDown() async throws {
        await MockMutationTool.resetExecutionLog()
        try await super.tearDown()
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
        let log = await MockMutationTool.tracker.getLog()
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


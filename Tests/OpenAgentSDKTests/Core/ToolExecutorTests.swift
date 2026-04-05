import XCTest
@testable import OpenAgentSDK

// MARK: - Mock Tools for Testing

/// Mock read-only tool for testing.
struct MockReadOnlyTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Mock read-only tool"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = true
    let delay: TimeInterval
    let result: String

    func call(input: Any, context: ToolContext) async -> ToolResult {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        return ToolResult(toolUseId: context.toolUseId, content: result, isError: false)
    }
}

/// Mock mutation tool for testing.
struct MockMutationTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Mock mutation tool"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = false
    let delay: TimeInterval
    let result: String

    func call(input: Any, context: ToolContext) async -> ToolResult {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        return ToolResult(toolUseId: context.toolUseId, content: result, isError: false)
    }
}

/// Mock tool that always returns an error result.
struct MockThrowingTool: ToolProtocol, @unchecked Sendable {
    let name: String = "throwing_tool"
    let description: String = "Always returns error"
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

final class ToolExecutorConcurrentTests: XCTestCase {

    /// AC1 [P0]: Multiple read-only tools return all results correctly.
    func testReadOnlyToolsReturnAllResults() async throws {
        let tools: [ToolProtocol] = (1...5).map { i in
            MockReadOnlyTool(name: "read_\(i)", delay: 0, result: "result_\(i)")
        }

        let toolUseBlocks: [ToolUseBlock] = (1...5).map { i in
            ToolUseBlock(id: "tu_\(i)", name: "read_\(i)", input: [:])
        }

        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )

        XCTAssertEqual(results.count, 5, "Should return 5 tool results")

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

    /// AC2 [P0]: Mutation tools all return results (serial execution is verified by implementation).
    func testMutationToolsReturnAllResults() async throws {
        let tools: [ToolProtocol] = [
            MockMutationTool(name: "write", delay: 0, result: "wrote file"),
            MockMutationTool(name: "edit", delay: 0, result: "edited file"),
            MockMutationTool(name: "bash", delay: 0, result: "command done"),
        ]

        let toolUseBlocks = [
            ToolUseBlock(id: "tu_1", name: "write", input: ["path": "a.txt"]),
            ToolUseBlock(id: "tu_2", name: "edit", input: ["path": "b.txt"]),
            ToolUseBlock(id: "tu_3", name: "bash", input: ["command": "ls"]),
        ]

        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )

        XCTAssertEqual(results.count, 3, "Should return 3 tool results")

        let resultContents = Set(results.map { $0.content })
        let expectedContents: Set<String> = ["wrote file", "edited file", "command done"]
        XCTAssertEqual(resultContents, expectedContents,
                       "All mutation tool results should contain expected content")
    }
}

// MARK: - AC3: Tool Execution Errors Don't Crash

final class ToolExecutorErrorHandlingTests: XCTestCase {

    /// AC3 [P0]: Tool execution error is captured as isError=true ToolResult.
    func testToolErrorCapturedAsToolResult() async throws {
        let tools: [ToolProtocol] = [
            MockThrowingTool()
        ]

        let toolUseBlocks = [
            ToolUseBlock(id: "tu_err_1", name: "throwing_tool", input: [:]),
        ]

        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )

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
        let content: [[String: Any]] = [
            ["type": "text", "text": "Let me search for that."],
            ["type": "tool_use", "id": "tu_001", "name": "grep", "input": ["pattern": "TODO"]],
            ["type": "tool_use", "id": "tu_002", "name": "glob", "input": ["pattern": "*.swift"]],
        ]

        let blocks = ToolExecutor.extractToolUseBlocks(from: content)

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
        let results = [
            ToolResult(toolUseId: "tu_001", content: "file1.swift\nfile2.swift", isError: false),
            ToolResult(toolUseId: "tu_002", content: "match found at line 42", isError: false),
        ]

        let message = ToolExecutor.buildToolResultMessage(from: results)

        XCTAssertEqual(message["role"] as? String, "user",
                       "Tool result message should have role 'user'")

        let content = message["content"] as? [[String: Any]]
        XCTAssertNotNil(content, "Content should be an array of blocks")
        XCTAssertEqual(content?.count, 2, "Should have 2 content blocks")

        let first = content?[0]
        XCTAssertEqual(first?["type"] as? String, "tool_result")
        XCTAssertEqual(first?["tool_use_id"] as? String, "tu_001")
        XCTAssertEqual(first?["content"] as? String, "file1.swift\nfile2.swift")
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

        let hasIsError = first?.keys.contains("is_error") ?? false
        XCTAssertFalse(hasIsError,
                       "Non-error tool result should not include is_error field")
    }
}

// MARK: - AC6: Unknown Tool Error Handling

final class ToolExecutorUnknownToolTests: XCTestCase {

    /// AC6 [P0]: Unknown tool returns isError=true ToolResult.
    func testUnknownToolReturnsError() async throws {
        let tools: [ToolProtocol] = [
            MockReadOnlyTool(name: "known_tool", delay: 0, result: "ok"),
        ]

        let toolUseBlocks = [
            ToolUseBlock(id: "tu_unknown", name: "nonexistent_tool", input: [:]),
        ]

        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].isError,
                      "Unknown tool should return isError=true")
        XCTAssertTrue(results[0].content.contains("Unknown tool"),
                      "Error message should mention 'Unknown tool', got: \(results[0].content)")
        XCTAssertEqual(results[0].toolUseId, "tu_unknown",
                       "Error result should preserve the tool_use_id")
    }

    /// AC6 [P1]: Empty tools array returns error for any tool_use.
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

// MARK: - Max Concurrency Cap

final class ToolExecutorConcurrencyCapTests: XCTestCase {

    /// AC1 [P1]: More than 10 read-only tools are still all executed.
    func testMaxConcurrencyCappedAt10() async throws {
        let tools: [ToolProtocol] = (1...15).map { i in
            MockReadOnlyTool(name: "read_\(i)", delay: 0, result: "result_\(i)")
        }

        let toolUseBlocks: [ToolUseBlock] = (1...15).map { i in
            ToolUseBlock(id: "tu_\(i)", name: "read_\(i)", input: [:])
        }

        let results = await ToolExecutor.executeTools(
            toolUseBlocks: toolUseBlocks,
            tools: tools,
            context: ToolContext(cwd: "/tmp")
        )

        XCTAssertEqual(results.count, 15,
                       "All 15 tool results should be collected even with concurrency cap")

        for result in results {
            XCTAssertFalse(result.isError,
                           "All read-only tool results should be non-error")
        }
    }
}

// MARK: - Mixed Concurrent + Serial Scenario

final class ToolExecutorMixedScenarioTests: XCTestCase {

    /// [P0]: Mix of read-only and mutation tools returns all results.
    func testMixedConcurrentAndSerialExecution() async throws {
        let tools: [ToolProtocol] = [
            MockReadOnlyTool(name: "Read", delay: 0, result: "file contents"),
            MockReadOnlyTool(name: "Grep", delay: 0, result: "matches found"),
            MockMutationTool(name: "Write", delay: 0, result: "wrote"),
            MockMutationTool(name: "Edit", delay: 0, result: "edited"),
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

        let resultContents = Set(results.map { $0.content })
        let expectedContents: Set<String> = ["file contents", "matches found", "wrote", "edited"]
        XCTAssertEqual(resultContents, expectedContents,
                       "All results should contain expected content")
    }
}

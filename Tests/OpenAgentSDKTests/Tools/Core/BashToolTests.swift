import XCTest
@testable import OpenAgentSDK

// MARK: - BashTool ATDD Tests (Story 3.6)

/// ATDD RED PHASE: Tests for Story 3.6 — BashTool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Sources/OpenAgentSDK/Tools/Core/BashTool.swift` is created
///   - `createBashTool() -> ToolProtocol` is implemented
///   - The tool executes shell commands via /bin/bash -c
///   - Timeout handling, output truncation, stderr capture work
///   - Working directory from ToolContext.cwd is respected
/// TDD Phase: RED (feature not implemented yet)
final class BashToolTests: XCTestCase {

    // MARK: - Helpers

    /// Creates the Bash tool via the public factory function.
    private func makeBashTool() -> ToolProtocol {
        return createBashTool()
    }

    /// Calls the tool with a dictionary input and returns the ToolResult.
    private func callTool(
        _ tool: ToolProtocol,
        input: [String: Any],
        cwd: String? = nil
    ) async -> ToolResult {
        let context = ToolContext(
            cwd: cwd ?? NSTemporaryDirectory(),
            toolUseId: "test-\(UUID().uuidString)"
        )
        return await tool.call(input: input, context: context)
    }

    // MARK: - AC1: Bash tool executes Shell commands

    /// AC1 [P0]: Bash tool executes a simple command and returns stdout.
    func testBash_executesCommand_returnsOutput() async {
        let tool = makeBashTool()

        // When: executing a simple echo command
        let result = await callTool(tool, input: ["command": "echo hello"])

        // Then: output contains the command result
        XCTAssertFalse(result.isError,
                       "Simple echo should not return error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("hello"),
                      "Output should contain 'hello', got: \(result.content)")
    }

    /// AC1 [P0]: Bash tool captures stderr separately.
    func testBash_capturesStderr() async {
        let tool = makeBashTool()

        // When: executing a command that writes to stderr
        let result = await callTool(tool, input: ["command": "echo errormsg >&2"])

        // Then: stderr output is captured in result
        XCTAssertFalse(result.isError,
                       "Stderr capture should not be isError, got: \(result.content)")
        XCTAssertTrue(result.content.contains("errormsg"),
                      "Output should contain stderr text, got: \(result.content)")
    }

    /// AC1 [P0]: Bash tool uses ToolContext.cwd as the working directory.
    func testBash_usesCwd() async {
        let tool = makeBashTool()
        let tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-Bash-Cwd-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        // When: executing pwd with a specific cwd
        let result = await callTool(tool, input: ["command": "pwd"], cwd: tempDir)

        // Then: output reflects the working directory
        XCTAssertFalse(result.isError,
                       "pwd should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains(tempDir),
                      "pwd output should match cwd, got: \(result.content)")
    }

    // MARK: - AC2: Bash tool timeout handling

    /// AC2 [P0]: Bash tool kills a process that exceeds the configured timeout.
    func testBash_timeout_killsProcess() async {
        let tool = makeBashTool()

        // When: executing a long-running command with a short timeout (1 second)
        let result = await callTool(tool, input: [
            "command": "sleep 30",
            "timeout": 1000  // 1 second in milliseconds
        ])

        // Then: the process is killed and a timeout-related message is returned
        XCTAssertTrue(
            result.isError || result.content.lowercased().contains("timeout") ||
            result.content.lowercased().contains("terminated"),
            "Timed-out process should indicate timeout or termination, got: \(result.content)"
        )
    }

    // MARK: - AC3: Bash tool output truncation

    /// AC3 [P0]: Bash tool truncates output exceeding 100,000 characters.
    func testBash_largeOutput_truncated() async {
        let tool = makeBashTool()

        // When: executing a command that produces more than 100,000 characters
        // Generate ~150,000 chars: 150 lines of 1000 'x' chars each
        let result = await callTool(tool, input: [
            "command": "python3 -c \"print('x' * 1000 * 150, end='')\""
        ])

        // Then: output is truncated (should not be 150,000+ chars)
        // Truncated output should be roughly 100,000 chars + truncation marker
        XCTAssertFalse(result.isError,
                       "Large output should not be isError, got: \(result.content)")
        XCTAssertTrue(
            result.content.contains("truncated") || result.content.count <= 110_000,
            "Large output should be truncated or under the limit, got \(result.content.count) chars"
        )
    }

    // MARK: - AC4: Bash tool non-zero exit code

    /// AC4 [P0]: Bash tool includes exit code info for non-zero exits, but does NOT set isError.
    func testBash_nonZeroExitCode_includedInOutput() async {
        let tool = makeBashTool()

        // When: executing a command that exits with non-zero code
        let result = await callTool(tool, input: ["command": "exit 42"])

        // Then: output contains exit code info
        XCTAssertTrue(result.content.contains("42") || result.content.contains("exit"),
                      "Non-zero exit code should be included in output, got: \(result.content)")
        // And: non-zero exit code is NOT treated as an error
        XCTAssertFalse(result.isError,
                       "Non-zero exit code should NOT be isError=true, got: \(result.content)")
    }

    // MARK: - AC10: POSIX cross-platform Shell execution

    /// AC10 [P0]: Bash tool works via /bin/bash on both macOS and Linux.
    func testBash_posixShellExecution() async {
        let tool = makeBashTool()

        // When: executing a POSIX-compatible command
        let result = await callTool(tool, input: ["command": "echo posix_ok && echo $SHELL"])

        // Then: command executes successfully using /bin/bash
        XCTAssertFalse(result.isError,
                       "POSIX shell execution should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("posix_ok"),
                      "Should execute POSIX commands, got: \(result.content)")
    }

    // MARK: - Error handling

    /// [P0]: Bash tool returns isError=true when process cannot be started.
    func testBash_processError_returnsError() async {
        let tool = makeBashTool()

        // When: executing a command with an impossible working directory
        let result = await callTool(tool, input: ["command": "echo test"], cwd: "/nonexistent/path/that/does/not/exist")

        // Then: error result returned
        XCTAssertTrue(result.isError,
                      "Invalid working directory should return isError=true, got: \(result.content)")
    }

    // MARK: - Timeout clamping

    /// [P1]: Bash tool clamps timeout to maximum of 600 seconds (600000 ms).
    func testBash_timeoutClampedToMax() async {
        let tool = makeBashTool()

        // When: executing a fast command with an absurdly large timeout
        let result = await callTool(tool, input: [
            "command": "echo clamped",
            "timeout": 999999999  // way over 600000ms max
        ])

        // Then: command still completes successfully (timeout was clamped, not errored)
        XCTAssertFalse(result.isError,
                       "Clamped timeout should still allow execution, got: \(result.content)")
        XCTAssertTrue(result.content.contains("clamped"),
                      "Should complete with clamped timeout, got: \(result.content)")
    }

    /// [P1]: Bash tool defaults timeout to 120 seconds when not specified.
    func testBash_defaultTimeout_allowsFastCommand() async {
        let tool = makeBashTool()

        // When: executing a fast command with no timeout specified (default 120s)
        let result = await callTool(tool, input: ["command": "echo default_timeout"])

        // Then: command completes within default timeout
        XCTAssertFalse(result.isError,
                       "Default timeout should allow fast commands, got: \(result.content)")
        XCTAssertTrue(result.content.contains("default_timeout"),
                      "Should complete with default timeout, got: \(result.content)")
    }

    // MARK: - Tool metadata

    /// [P0]: Bash tool should be named "Bash".
    func testBashTool_hasCorrectName() {
        let tool = makeBashTool()
        XCTAssertEqual(tool.name, "Bash",
                       "Bash tool should be named 'Bash'")
    }

    /// [P0]: Bash tool should NOT be marked as read-only (it is a mutation tool).
    func testBashTool_isReadOnly_false() {
        let tool = makeBashTool()
        XCTAssertFalse(tool.isReadOnly,
                       "Bash tool should NOT be marked as read-only")
    }

    /// [P0]: Bash tool should have `command` in required schema fields.
    func testBashTool_hasCommandInRequiredSchema() {
        let tool = makeBashTool()
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required,
                        "inputSchema should have 'required' array")
        XCTAssertTrue(required!.contains("command"),
                      "'command' should be in required fields")
    }
}

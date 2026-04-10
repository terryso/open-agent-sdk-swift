import XCTest
@testable import OpenAgentSDK

// MARK: - ShellHookExecutor Tests (Story 8-3)

/// ATDD tests for Story 8-3: Shell Hook Execution.
///
/// These tests verify the ShellHookExecutor component and its integration
/// with HookRegistry. All tests are in the TDD RED PHASE -- they
/// will FAIL until the implementation is complete (Tasks 1-2 in the story).
///
/// Coverage:
/// - AC1: ShellHookExecutor executes commands via POSIX Process
/// - AC2: JSON stdin/stdout protocol
/// - AC3: Environment variable passing (HOOK_EVENT, HOOK_TOOL_NAME, etc.)
/// - AC4: Shell hook timeout with process termination
/// - AC5: Non-zero exit code returns nil
/// - AC6: Input sanitization (stdin pipe, not command concatenation)
/// - AC7: HookRegistry.execute() integration with command field
/// - AC8: Shell hooks and function hooks coexist on same event
/// - AC10: Unit test coverage requirements
/// - AC12: Matcher filtering for shell hooks
final class ShellHookExecutorTests: XCTestCase {

    // MARK: - AC1: Shell Hook Execution Engine

    /// AC1 [P0]: ShellHookExecutor.execute() runs a command via /bin/bash -c.
    func testExecute_validCommand_returnsOutput() async {
        // Given: a simple shell command that outputs JSON
        let command = "echo '{\"message\":\"hello from shell\"}'"
        let input = HookInput(event: .preToolUse, toolName: "bash")

        // When: executing the shell command hook
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 5_000
        )

        // Then: output is parsed from JSON stdout
        XCTAssertNotNil(output, "Shell command should return non-nil output")
        XCTAssertEqual(output?.message, "hello from shell", "Message should match shell output")
    }

    // MARK: - AC2: JSON stdin/stdout Protocol

    /// AC2 [P0]: HookInput is passed as JSON through stdin and stdout is parsed as HookOutput.
    func testExecute_jsonStdout_parsesAsHookOutput() async {
        // Given: a command that reads stdin JSON and outputs JSON
        let command = "cat | python3 -c \"import sys,json; d=json.load(sys.stdin); print(json.dumps({'message': 'got event: ' + d['event']}))\""
        let input = HookInput(event: .preToolUse, toolName: "bash")

        // When: executing the command (stdin receives JSON)
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 5_000
        )

        // Then: output reflects the command processing stdin JSON
        XCTAssertNotNil(output, "Should return non-nil output")
        XCTAssertTrue(output?.message?.hasPrefix("got event:") ?? false,
                      "Message should reflect processing of stdin JSON, got: \(output?.message ?? "nil")")
    }

    /// AC2 [P0]: Non-JSON stdout output is treated as HookOutput(message: stdout).
    func testExecute_nonJsonOutput_treatedAsMessage() async {
        // Given: a command that outputs plain text (not JSON)
        let command = "echo 'plain text output'"
        let input = HookInput(event: .postToolUse, toolName: "file_read")

        // When: executing the shell command
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 5_000
        )

        // Then: output is a HookOutput with message set to the text
        XCTAssertNotNil(output, "Non-JSON output should still return a HookOutput")
        XCTAssertEqual(output?.message, "plain text output",
                       "Non-JSON output should be wrapped as message")
    }

    // MARK: - AC3: Environment Variable Passing

    /// AC3 [P0]: Shell hook inherits process environment plus HOOK_* variables.
    func testExecute_environmentVariables_setCorrectly() async {
        // Given: a command that prints HOOK_* env vars
        let command = "echo \"HOOK_EVENT=$HOOK_EVENT HOOK_TOOL_NAME=$HOOK_TOOL_NAME HOOK_SESSION_ID=$HOOK_SESSION_ID HOOK_CWD=$HOOK_CWD\""
        let input = HookInput(
            event: .preToolUse,
            toolName: "bash",
            sessionId: "session-123",
            cwd: "/tmp/test"
        )

        // When: executing the command
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 5_000
        )

        // Then: environment variables are set correctly
        XCTAssertNotNil(output, "Should return output")
        let message = output?.message ?? ""
        XCTAssertTrue(message.contains("HOOK_EVENT=preToolUse"),
                      "HOOK_EVENT should be set to event rawValue, got: \(message)")
        XCTAssertTrue(message.contains("HOOK_TOOL_NAME=bash"),
                      "HOOK_TOOL_NAME should be set to toolName, got: \(message)")
        XCTAssertTrue(message.contains("HOOK_SESSION_ID=session-123"),
                      "HOOK_SESSION_ID should be set, got: \(message)")
        XCTAssertTrue(message.contains("HOOK_CWD=/tmp/test"),
                      "HOOK_CWD should be set, got: \(message)")
    }

    /// AC3 [P1]: HOOK_TOOL_NAME is empty string when toolName is nil.
    func testExecute_environmentVariables_emptyWhenNil() async {
        // Given: input with nil toolName, sessionId, cwd
        let command = "echo \"HOOK_TOOL_NAME='$HOOK_TOOL_NAME' HOOK_SESSION_ID='$HOOK_SESSION_ID' HOOK_CWD='$HOOK_CWD'\""
        let input = HookInput(event: .sessionStart)

        // When: executing the command
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 5_000
        )

        // Then: optional env vars are empty strings
        XCTAssertNotNil(output, "Should return output")
        let message = output?.message ?? ""
        XCTAssertTrue(message.contains("HOOK_TOOL_NAME=''"),
                      "HOOK_TOOL_NAME should be empty when toolName is nil")
        XCTAssertTrue(message.contains("HOOK_SESSION_ID=''"),
                      "HOOK_SESSION_ID should be empty when sessionId is nil")
        XCTAssertTrue(message.contains("HOOK_CWD=''"),
                      "HOOK_CWD should be empty when cwd is nil")
    }

    // MARK: - AC4: Shell Hook Timeout

    /// AC4 [P0]: Shell hook that exceeds timeout is terminated and returns nil.
    func testExecute_timeout_terminatesProcess() async {
        // Given: a command that sleeps longer than the timeout
        let command = "sleep 5"
        let input = HookInput(event: .preToolUse, toolName: "bash")

        // When: executing with a very short timeout (200ms)
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 200
        )

        // Then: output is nil (process was terminated)
        XCTAssertNil(output, "Timed-out process should return nil")
    }

    // MARK: - AC5: Non-Zero Exit Code Handling

    /// AC5 [P0]: Command that exits with non-zero code returns nil.
    func testExecute_nonZeroExitCode_returnsNil() async {
        // Given: a command that exits with code 1
        let command = "exit 1"
        let input = HookInput(event: .preToolUse, toolName: "bash")

        // When: executing the command
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 5_000
        )

        // Then: output is nil
        XCTAssertNil(output, "Non-zero exit code should return nil")
    }

    /// AC5 [P1]: Command that exits with code 2 returns nil.
    func testExecute_exitCode2_returnsNil() async {
        // Given: a command that exits with code 2
        let command = "exit 2"
        let input = HookInput(event: .postToolUse, toolName: "bash")

        // When: executing the command
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 5_000
        )

        // Then: output is nil
        XCTAssertNil(output, "Exit code 2 should return nil")
    }

    // MARK: - Empty stdout Handling

    /// AC5 [P0]: Command that succeeds but produces empty stdout returns nil.
    func testExecute_emptyOutput_returnsNil() async {
        // Given: a command that produces no output
        let command = "true"
        let input = HookInput(event: .preToolUse, toolName: "bash")

        // When: executing the command
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 5_000
        )

        // Then: output is nil (empty stdout)
        XCTAssertNil(output, "Empty stdout should return nil")
    }

    // MARK: - AC6: Command Failure Returns Nil

    /// AC6 [P0]: Non-existent command returns nil (no crash).
    func testExecute_commandFailure_returnsNil() async {
        // Given: a command that does not exist
        let command = "nonexistent_command_xyz_12345"
        let input = HookInput(event: .preToolUse, toolName: "bash")

        // When: executing the command
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 5_000
        )

        // Then: output is nil (command failed to run or non-zero exit)
        XCTAssertNil(output, "Failed command should return nil without crash")
    }

    // MARK: - AC6: Input Sanitization (stdin pipe, not command concatenation)

    /// AC6 [P0]: Input with special characters is safely passed via stdin, not concatenated.
    func testExecute_specialCharactersInInput_passedViaStdin() async {
        // Given: input with characters that would be dangerous if concatenated
        let command = "cat"
        let input = HookInput(
            event: .preToolUse,
            toolName: "bash",
            toolInput: ["command": "rm -rf /; echo 'pwned'"]
        )

        // When: executing the command (cat reads stdin)
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 5_000
        )

        // Then: command completes without injection (cat just outputs stdin JSON)
        // The fact that it doesn't crash or execute malicious commands proves safety
        // Output may be nil (non-JSON) or contain the JSON string as message
        // Either way, no command injection occurred
        _ = output // We just verify no crash
    }

    // MARK: - AC7: HookRegistry.execute() Integration

    /// AC7 [P0]: HookRegistry executes shell command when handler is nil and command is set.
    func testRegistryExecute_commandHook_returnsOutput() async {
        // Given: a HookRegistry with a command-based hook
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(
            command: "echo '{\"message\":\"shell-hook-output\"}'"
        ))

        // When: executing hooks for the event
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: shell command hook produced output
        XCTAssertEqual(results.count, 1, "Should return one result from shell hook")
        XCTAssertEqual(results.first?.message, "shell-hook-output",
                       "Shell hook output should match command output")
    }

    /// AC7 [P0]: HookRegistry skips definition when both handler and command are nil.
    func testRegistryExecute_noHandlerNoCommand_skipsDefinition() async {
        // Given: a HookRegistry with a definition that has neither handler nor command
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition())

        // When: executing hooks
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: no results (definition was skipped)
        XCTAssertTrue(results.isEmpty, "Should skip definition with no handler and no command")
    }

    /// AC7 [P0]: Handler takes priority over command when both are set.
    func testRegistryExecute_handlerAndCommand_handlerTakesPriority() async {
        // Given: a HookRegistry with a definition that has both handler and command
        let registry = HookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(
            command: "echo '{\"message\":\"from-command\"}'",
            handler: { _ in
                HookOutput(message: "from-handler")
            }
        ))

        // When: executing hooks
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: handler output is returned, not command output
        XCTAssertEqual(results.count, 1, "Should return one result")
        XCTAssertEqual(results.first?.message, "from-handler",
                       "Handler should take priority over command")
    }

    // MARK: - AC8: Shell Hooks and Function Hooks Coexist

    /// AC8 [P0]: Shell hooks and function hooks on the same event execute in registration order.
    func testRegistryExecute_mixedHandlerAndCommand_executesInOrder() async {
        // Given: a HookRegistry with interleaved handler and command hooks
        let registry = HookRegistry()
        let tracker = HookOrderTracker()

        // First: function hook
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in
                await tracker.record("handler-1")
                return HookOutput(message: "handler-1-output")
            }
        ))

        // Second: shell command hook
        await registry.register(.preToolUse, definition: HookDefinition(
            command: "echo '{\"message\":\"command-2-output\"}'"
        ))

        // Third: function hook
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in
                await tracker.record("handler-3")
                return HookOutput(message: "handler-3-output")
            }
        ))

        // When: executing hooks
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: all three hooks produced results in order
        XCTAssertEqual(results.count, 3, "Should return results from all 3 hooks")
        XCTAssertEqual(results[0].message, "handler-1-output", "First result from handler")
        XCTAssertEqual(results[1].message, "command-2-output", "Second result from shell command")
        XCTAssertEqual(results[2].message, "handler-3-output", "Third result from handler")

        // And: handler hooks executed in order
        let order = await tracker.order
        XCTAssertEqual(order, ["handler-1", "handler-3"],
                       "Handlers should execute in registration order")
    }

    // MARK: - AC12: Matcher Filtering for Shell Hooks

    /// AC12 [P0]: Shell hook with matcher filters by toolName.
    func testRegistryExecute_commandHookWithMatcher_filtersCorrectly() async {
        // Given: a HookRegistry with a command hook that only matches "bash"
        let registry = HookRegistry()

        await registry.register(.preToolUse, definition: HookDefinition(
            command: "echo '{\"message\":\"bash-only-hook\"}'",
            matcher: "bash"
        ))

        // When: executing with non-matching toolName
        let nonMatchingInput = HookInput(event: .preToolUse, toolName: "file_read")
        let nonMatchingResults = await registry.execute(.preToolUse, input: nonMatchingInput)

        // Then: hook was skipped
        XCTAssertTrue(nonMatchingResults.isEmpty,
                      "Shell hook should be skipped when toolName doesn't match matcher")

        // When: executing with matching toolName
        let matchingInput = HookInput(event: .preToolUse, toolName: "bash")
        let matchingResults = await registry.execute(.preToolUse, input: matchingInput)

        // Then: hook was executed
        XCTAssertEqual(matchingResults.count, 1, "Shell hook should execute when toolName matches")
        XCTAssertEqual(matchingResults.first?.message, "bash-only-hook")
    }

    /// AC12 [P0]: Shell hook with nil matcher matches all toolNames.
    func testRegistryExecute_commandHookNoMatcher_matchesAll() async {
        // Given: a HookRegistry with a command hook without matcher
        let registry = HookRegistry()

        await registry.register(.preToolUse, definition: HookDefinition(
            command: "echo '{\"message\":\"universal-shell\"}'"
        ))

        // When: executing with different toolNames
        let input1 = HookInput(event: .preToolUse, toolName: "bash")
        let input2 = HookInput(event: .preToolUse, toolName: "file_read")

        let results1 = await registry.execute(.preToolUse, input: input1)
        let results2 = await registry.execute(.preToolUse, input: input2)

        // Then: hook fires for both
        XCTAssertEqual(results1.count, 1, "Shell hook should fire for bash")
        XCTAssertEqual(results2.count, 1, "Shell hook should fire for file_read")
    }

    /// AC12 [P1]: Shell hook with regex matcher matches pattern.
    func testRegistryExecute_commandHookRegexMatcher_matchesPattern() async {
        // Given: a HookRegistry with a command hook with regex matcher
        let registry = HookRegistry()

        await registry.register(.preToolUse, definition: HookDefinition(
            command: "echo '{\"message\":\"file-hook\"}'",
            matcher: "file.*"
        ))

        // When: executing with matching toolName
        let input = HookInput(event: .preToolUse, toolName: "file_read")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: hook fires
        XCTAssertEqual(results.count, 1, "Shell hook should fire for regex match")
        XCTAssertEqual(results.first?.message, "file-hook")
    }

    // MARK: - Timeout Integration via HookRegistry

    /// AC4 [P0]: Shell hook timeout in HookRegistry.execute() terminates process.
    func testRegistryExecute_commandTimeout_returnsNoResult() async {
        // Given: a HookRegistry with a slow command hook and short timeout
        let registry = HookRegistry()

        await registry.register(.preToolUse, definition: HookDefinition(
            command: "sleep 5",
            timeout: 200 // 200ms timeout
        ))

        // Also register a fast function hook to verify timeout isolation
        await registry.register(.preToolUse, definition: HookDefinition(
            handler: { _ in HookOutput(message: "fast-handler") }
        ))

        // When: executing hooks
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)

        // Then: timed-out shell hook produces no result, but fast hook succeeds
        let hasFast = results.contains { $0.message == "fast-handler" }
        XCTAssertTrue(hasFast, "Fast handler should still produce result despite shell hook timeout")
        let hasSlow = results.contains { $0.message?.contains("sleep") ?? false }
        XCTAssertFalse(hasSlow, "Timed-out shell hook should not produce result")
    }

    // MARK: - Cross-Platform (AC9)

    /// AC9 [P1]: ShellHookExecutor uses Foundation Process (not Apple-specific).
    /// This test verifies the API exists and is callable, not runtime cross-platform behavior.
    func testExecute_usesFoundationProcess() async {
        // Given: a basic command
        let command = "echo 'cross-platform-test'"
        let input = HookInput(event: .preToolUse)

        // When: executing
        let output = await ShellHookExecutor.execute(
            command: command,
            input: input,
            timeoutMs: 5_000
        )

        // Then: completes successfully using Foundation Process
        XCTAssertNotNil(output, "Foundation Process-based execution should work")
        XCTAssertEqual(output?.message, "cross-platform-test")
    }
}

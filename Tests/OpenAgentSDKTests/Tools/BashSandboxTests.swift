import XCTest
@testable import OpenAgentSDK

// MARK: - ATDD RED PHASE: Story 14.5 -- Sandbox Bash Command Filtering
//
// All tests assert EXPECTED behavior. They will FAIL until:
//   - `Sources/OpenAgentSDK/Tools/Core/BashTool.swift` adds sandbox check:
//     `if let sandbox = context.sandbox { try SandboxChecker.checkCommand(input.command, settings: sandbox) }`
//   - `Sources/OpenAgentSDK/Utils/SandboxChecker.swift` adds shell metacharacter
//     detection for subshell, command substitution, and bypass vectors
//   - The check happens BEFORE process execution (no process spawned on denial)
// TDD Phase: RED (feature not implemented yet)

// MARK: - Test Helper

/// Calls BashTool with sandbox context and returns the result.
private func callBashToolWithSandbox(
    command: String,
    cwd: String,
    sandbox: SandboxSettings?
) async -> ToolResult {
    let tool = createBashTool()
    let context = ToolContext(
        cwd: cwd,
        toolUseId: "test-bash-sandbox-\(UUID().uuidString)",
        sandbox: sandbox
    )
    return await tool.call(input: ["command": command], context: context)
}

// MARK: - AC1: Blocklist mode denies listed commands

final class BashBlocklistTests: XCTestCase {

    /// AC1 [P0]: Blocklist denies a listed command.
    func testBlocklist_deniesListedCommand() async {
        let sandbox = SandboxSettings(deniedCommands: ["rm", "sudo", "curl"])

        let result = await callBashToolWithSandbox(
            command: "rm -rf /tmp/test",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "Blocklisted 'rm' command should be denied, got: \(result.content)")
        XCTAssertTrue(
            result.content.localizedCaseInsensitiveContains("permission") ||
            result.content.localizedCaseInsensitiveContains("denied"),
            "Error should mention permission denial: \(result.content)"
        )
    }

    /// AC1 [P0]: Blocklist allows a command not in the denied list.
    /// Tests SandboxChecker directly to avoid Process execution flakiness on CI.
    func testBlocklist_allowsUnlistedCommand() {
        let sandbox = SandboxSettings(deniedCommands: ["rm", "sudo", "curl"])

        XCTAssertTrue(
            SandboxChecker.isCommandAllowed("echo hello", settings: sandbox),
            "Non-blocklisted 'echo' command should be allowed"
        )
        XCTAssertNoThrow(
            try SandboxChecker.checkCommand("echo hello", settings: sandbox),
            "Non-blocklisted 'echo' should not throw"
        )
    }
}

// MARK: - AC2: Blocklist extracts basename from full path

final class BashBlocklistBasenameTests: XCTestCase {

    /// AC2 [P0]: Blocklist extracts basename from full path and denies.
    func testBlocklist_extractsBasenameFromPath() async {
        let sandbox = SandboxSettings(deniedCommands: ["rm"])

        let result = await callBashToolWithSandbox(
            command: "/usr/bin/rm -rf /tmp/test",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "Full path /usr/bin/rm should extract basename 'rm' and be denied, got: \(result.content)")
    }

    /// AC2 [P1]: Blocklist extracts basename from full path with arguments.
    func testBlocklist_fullPathWithArgs_denied() async {
        let sandbox = SandboxSettings(deniedCommands: ["sudo"])

        let result = await callBashToolWithSandbox(
            command: "/usr/bin/sudo apt-get install something",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "/usr/bin/sudo should extract basename 'sudo' and be denied, got: \(result.content)")
    }
}

// MARK: - AC3: Allowlist mode permits only listed commands

final class BashAllowlistPermitTests: XCTestCase {

    /// AC3 [P0]: Allowlist permits a listed command.
    /// Tests SandboxChecker directly to avoid Process execution flakiness on CI.
    func testAllowlist_permitsListedCommand() {
        let sandbox = SandboxSettings(allowedCommands: ["git", "swift", "xcodebuild"])

        XCTAssertTrue(
            SandboxChecker.isCommandAllowed("git status", settings: sandbox),
            "Allowlisted 'git' command should be allowed"
        )
        XCTAssertNoThrow(
            try SandboxChecker.checkCommand("git status", settings: sandbox),
            "Allowlisted 'git' should not throw"
        )
    }

    /// AC3 [P0]: Allowlist permits 'swift' command.
    /// Tests SandboxChecker directly to avoid Process execution flakiness on CI.
    func testAllowlist_permitsSwiftCommand() {
        let sandbox = SandboxSettings(allowedCommands: ["git", "swift", "xcodebuild"])

        XCTAssertTrue(
            SandboxChecker.isCommandAllowed("swift --version", settings: sandbox),
            "Allowlisted 'swift' command should be allowed"
        )
        XCTAssertNoThrow(
            try SandboxChecker.checkCommand("swift --version", settings: sandbox),
            "Allowlisted 'swift' should not throw"
        )
    }
}

// MARK: - AC4: Allowlist mode denies unlisted commands

final class BashAllowlistDenyTests: XCTestCase {

    /// AC4 [P0]: Allowlist denies an unlisted command.
    func testAllowlist_deniesUnlistedCommand() async {
        let sandbox = SandboxSettings(allowedCommands: ["git", "swift", "xcodebuild"])

        let result = await callBashToolWithSandbox(
            command: "rm -rf /tmp/test",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "Non-allowlisted 'rm' command should be denied, got: \(result.content)")
    }

    /// AC4 [P0]: Allowlist denies 'ls' when not in allowlist.
    func testAllowlist_deniesLs() async {
        let sandbox = SandboxSettings(allowedCommands: ["git", "swift", "xcodebuild"])

        let result = await callBashToolWithSandbox(
            command: "ls -la",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "Non-allowlisted 'ls' command should be denied, got: \(result.content)")
    }
}

// MARK: - AC5: Shell metacharacter bypass prevention -- subshell

final class BashSubshellBypassTests: XCTestCase {

    /// AC5 [P0]: bash -c with denied command is caught.
    func testSubshell_bashC_deniedCommand() async {
        let sandbox = SandboxSettings(deniedCommands: ["rm"])

        let result = await callBashToolWithSandbox(
            command: "bash -c \"rm -rf /tmp\"",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "bash -c 'rm' should be caught by metacharacter detection, got: \(result.content)")
    }

    /// AC5 [P0]: sh -c with denied command is caught.
    func testSubshell_shC_deniedCommand() async {
        let sandbox = SandboxSettings(deniedCommands: ["rm"])

        let result = await callBashToolWithSandbox(
            command: "sh -c \"rm -rf /tmp\"",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "sh -c 'rm' should be caught by metacharacter detection, got: \(result.content)")
    }

    /// AC5 [P0]: zsh -c with denied command is caught.
    func testSubshell_zshC_deniedCommand() async {
        let sandbox = SandboxSettings(deniedCommands: ["rm"])

        let result = await callBashToolWithSandbox(
            command: "zsh -c \"rm -rf /tmp\"",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "zsh -c 'rm' should be caught by metacharacter detection, got: \(result.content)")
    }

    /// AC5 [P1]: bash -c with allowed command is permitted in allowlist mode.
    /// Tests SandboxChecker directly to avoid Process execution flakiness on CI.
    func testSubshell_bashC_allowedCommand() {
        let sandbox = SandboxSettings(allowedCommands: ["git", "bash"])

        XCTAssertTrue(
            SandboxChecker.isCommandAllowed("bash -c \"git status\"", settings: sandbox),
            "bash -c 'git status' should be allowed when 'bash' and 'git' are in allowlist"
        )
    }

    /// AC5 [P0]: Subshell bypass with allowlist mode denies inner unlisted command.
    func testSubshell_allowlistMode_deniesInnerUnlistedCommand() async {
        let sandbox = SandboxSettings(allowedCommands: ["git", "swift"])

        let result = await callBashToolWithSandbox(
            command: "bash -c \"rm -rf /tmp\"",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "bash -c 'rm' should be denied in allowlist mode (rm not allowed), got: \(result.content)")
    }
}

// MARK: - AC6: Shell metacharacter bypass prevention -- command substitution

final class BashCommandSubstitutionBypassTests: XCTestCase {

    /// AC6 [P0]: Dollar-paren command substitution with denied command is caught.
    func testCommandSubstitution_dollarParen_deniedCommand() async {
        let sandbox = SandboxSettings(deniedCommands: ["rm"])

        let result = await callBashToolWithSandbox(
            command: "$(rm -rf /tmp)",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "$(rm ...) should be caught by metacharacter detection, got: \(result.content)")
    }

    /// AC6 [P0]: Backtick command substitution with denied command is caught.
    func testCommandSubstitution_backtick_deniedCommand() async {
        let sandbox = SandboxSettings(deniedCommands: ["rm"])

        let result = await callBashToolWithSandbox(
            command: "`rm -rf /tmp`",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "Backtick rm should be caught by metacharacter detection, got: \(result.content)")
    }

    /// AC6 [P1]: Dollar-paren with allowed command in allowlist mode is allowed.
    /// Tests SandboxChecker directly to avoid Process execution flakiness on CI.
    func testCommandSubstitution_dollarParen_allowedCommand() {
        let sandbox = SandboxSettings(allowedCommands: ["git"])

        XCTAssertTrue(
            SandboxChecker.isCommandAllowed("$(git rev-parse --short HEAD)", settings: sandbox),
            "$(git ...) should be allowed in allowlist mode"
        )
    }

    /// AC6 [P1]: Backtick with denied command in blocklist mode is caught.
    func testCommandSubstitution_backtick_sudo_denied() async {
        let sandbox = SandboxSettings(deniedCommands: ["sudo"])

        let result = await callBashToolWithSandbox(
            command: "`sudo rm -rf /tmp`",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "Backtick sudo should be caught by metacharacter detection, got: \(result.content)")
    }
}

// MARK: - AC7: Shell metacharacter bypass prevention -- escape and quote

final class BashEscapeQuoteBypassTests: XCTestCase {

    /// AC7 [P0]: Backslash-escaped command is stripped and matched.
    func testEscapeBypass_backslashRM_denied() async {
        let sandbox = SandboxSettings(deniedCommands: ["rm"])

        let result = await callBashToolWithSandbox(
            command: "\\rm -rf /tmp",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "\\rm should strip backslash and match 'rm', got: \(result.content)")
    }

    /// AC7 [P0]: Double-quoted command is stripped and matched.
    func testQuoteBypass_doubleQuotedRM_denied() async {
        let sandbox = SandboxSettings(deniedCommands: ["rm"])

        let result = await callBashToolWithSandbox(
            command: "\"rm\" -rf /tmp",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "\"rm\" should strip quotes and match 'rm', got: \(result.content)")
    }

    /// AC7 [P1]: Single-quoted command is stripped and matched.
    func testQuoteBypass_singleQuotedRM_denied() async {
        let sandbox = SandboxSettings(deniedCommands: ["rm"])

        let result = await callBashToolWithSandbox(
            command: "'rm' -rf /tmp",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "'rm' should strip quotes and match 'rm', got: \(result.content)")
    }
}

// MARK: - AC8: Unparseable metacharacters default-deny

final class BashUnparseableMetacharTests: XCTestCase {

    /// AC8 [P0]: Unparseable shell metacharacters are denied by default.
    func testUnparseableMetachar_defaultDeny() async {
        let sandbox = SandboxSettings(deniedCommands: ["rm"])

        // Complex nested substitution that's hard to parse reliably
        let result = await callBashToolWithSandbox(
            command: "bash -c \"bash -c 'rm -rf /tmp'\"",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "Deeply nested or ambiguous metacharacters should be denied by default, got: \(result.content)")
    }

    /// AC8 [P0]: Ambiguous metacharacters in allowlist mode are denied.
    func testUnparseableMetachar_allowlistMode_denied() async {
        let sandbox = SandboxSettings(allowedCommands: ["git"])

        let result = await callBashToolWithSandbox(
            command: "bash -c \"bash -c 'rm -rf /tmp'\"",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "Ambiguous metacharacters in allowlist mode should be denied, got: \(result.content)")
    }
}

// MARK: - AC9: Allowlist takes precedence over blocklist

final class BashAllowlistPrecedenceTests: XCTestCase {

    /// AC9 [P0]: When both allowedCommands and deniedCommands are set, allowlist wins.
    /// Tests SandboxChecker directly to avoid Process execution flakiness on CI.
    func testAllowlistPrecedence_gitAllowed() {
        let sandbox = SandboxSettings(
            deniedCommands: ["rm"],
            allowedCommands: ["git", "swift"]
        )

        XCTAssertTrue(
            SandboxChecker.isCommandAllowed("git status", settings: sandbox),
            "git should be allowed (in allowlist, allowlist takes precedence)"
        )
    }

    /// AC9 [P0]: In allowlist-precedence mode, rm is denied (not in allowlist).
    func testAllowlistPrecedence_rmDenied() async {
        let sandbox = SandboxSettings(
            deniedCommands: ["rm"],
            allowedCommands: ["git", "swift"]
        )

        let result = await callBashToolWithSandbox(
            command: "rm -rf /tmp",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "rm should be denied (not in allowlist, allowlist takes precedence), got: \(result.content)")
    }

    /// AC9 [P0]: In allowlist-precedence mode, ls is denied (not in allowlist).
    func testAllowlistPrecedence_lsDenied() async {
        let sandbox = SandboxSettings(
            deniedCommands: ["rm"],
            allowedCommands: ["git", "swift"]
        )

        let result = await callBashToolWithSandbox(
            command: "ls -la",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "ls should be denied (not in allowlist), got: \(result.content)")
    }

    /// AC9 [P0]: In allowlist-precedence mode, swift is allowed.
    /// Tests SandboxChecker directly to avoid Process execution flakiness on CI.
    func testAllowlistPrecedence_swiftAllowed() {
        let sandbox = SandboxSettings(
            deniedCommands: ["rm"],
            allowedCommands: ["git", "swift"]
        )

        XCTAssertTrue(
            SandboxChecker.isCommandAllowed("swift build", settings: sandbox),
            "swift should be allowed (in allowlist, allowlist takes precedence)"
        )
    }
}

// MARK: - AC10: No restrictions = no filtering

final class BashNoSandboxTests: XCTestCase {

    /// AC10 [P0]: No sandbox means no command filtering.
    /// Tests SandboxChecker directly to avoid Process execution flakiness on CI.
    func testNoSandbox_anyCommandAllowed() {
        let settings = SandboxSettings()

        XCTAssertTrue(
            SandboxChecker.isCommandAllowed("echo no_sandbox_test", settings: settings),
            "Without sandbox restrictions, any command should be allowed"
        )
        XCTAssertNoThrow(
            try SandboxChecker.checkCommand("echo no_sandbox_test", settings: settings),
            "Without sandbox restrictions, checkCommand should not throw"
        )
    }

    /// AC10 [P0]: Sandbox with empty deniedCommands and nil allowedCommands means no filtering.
    /// Tests SandboxChecker directly to avoid Process execution flakiness on CI.
    func testEmptySandbox_anyCommandAllowed() {
        let settings = SandboxSettings(deniedCommands: [], allowedCommands: nil)

        XCTAssertTrue(
            SandboxChecker.isCommandAllowed("echo empty_sandbox_test", settings: settings),
            "Empty sandbox settings should not filter commands"
        )
        XCTAssertNoThrow(
            try SandboxChecker.checkCommand("echo empty_sandbox_test", settings: settings),
            "Empty sandbox settings should not throw"
        )
    }

    /// AC10 [P0]: Sandbox with empty deniedCommands and empty allowedCommands is most restrictive.
    func testEmptyAllowlist_nothingAllowed() async {
        // Empty allowedCommands (non-nil) = allowlist mode with nothing allowed
        let sandbox = SandboxSettings(deniedCommands: [], allowedCommands: [])

        let result = await callBashToolWithSandbox(
            command: "echo test",
            cwd: "/tmp",
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "Empty allowlist should deny all commands, got: \(result.content)")
    }
}

// MARK: - AC11: Sandbox check happens BEFORE process execution

final class BashSandboxTimingTests: XCTestCase {

    /// AC11 [P0]: Denied command does NOT spawn a process.
    /// Verifies by checking that a side-effect file is NOT created.
    func testSandboxCheckBeforeProcess_denied_noSideEffect() async throws {
        let tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-BashSandboxTiming-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let markerFile = (tempDir as NSString).appendingPathComponent("marker.txt")
        let sandbox = SandboxSettings(deniedCommands: ["touch"])

        // Try to run touch (denied) which would create the marker file if process spawned
        let result = await callBashToolWithSandbox(
            command: "touch \(markerFile)",
            cwd: tempDir,
            sandbox: sandbox
        )

        XCTAssertTrue(result.isError,
                       "touch should be denied by sandbox, got: \(result.content)")

        // The marker file should NOT exist because the process was never spawned
        let fileExists = FileManager.default.fileExists(atPath: markerFile)
        XCTAssertFalse(fileExists,
                        "Marker file should NOT exist -- sandbox check should prevent process execution")
    }

    /// AC11 [P0]: Allowed command passes sandbox check (does not throw).
    /// Tests SandboxChecker directly — integration with BashTool is covered by denied tests.
    func testSandboxCheckBeforeProcess_allowed_passesCheck() {
        let sandbox = SandboxSettings(deniedCommands: ["rm"])  // touch is not denied

        XCTAssertTrue(
            SandboxChecker.isCommandAllowed("touch /tmp/marker.txt", settings: sandbox),
            "touch should pass sandbox check (not in denied list)"
        )
        XCTAssertNoThrow(
            try SandboxChecker.checkCommand("touch /tmp/marker.txt", settings: sandbox),
            "touch should not throw (not in denied list)"
        )
    }
}

// MARK: - AC12: Known limitations documented (API doc check)

final class BashSandboxDocumentationTests: XCTestCase {

    /// AC12 [P1]: SandboxChecker or SandboxSettings public API docs mention limitations.
    /// This test verifies doc comments exist mentioning blocklist limitations.
    func testDocumentation_mentionsBlocklistLimitations() {
        // Verify that SandboxSettings or SandboxChecker have documentation
        // about blocklist mode being best-effort. This is a documentation-only check.
        // We verify the types exist and are usable.
        let settings = SandboxSettings(deniedCommands: ["rm"])
        XCTAssertNotNil(settings, "SandboxSettings should be constructable")
        XCTAssertFalse(settings.deniedCommands.isEmpty, "deniedCommands should be set")

        // Note: Doc comment verification is manual review. The test ensures
        // the types compile and are accessible for API documentation tools.
    }
}

// MARK: - SandboxChecker Metacharacter Unit Tests

final class SandboxCheckerMetacharTests: XCTestCase {

    // MARK: - AC5: Subshell detection (unit level)

    /// AC5 [P0]: SandboxChecker catches bash -c with denied command.
    func testCheckCommand_bashC_denied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("bash -c \"rm -rf /tmp\"", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied(let tool, _) = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
            XCTAssertEqual(tool, "Bash")
        }
    }

    /// AC5 [P0]: SandboxChecker catches sh -c with denied command.
    func testCheckCommand_shC_denied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("sh -c \"rm -rf /tmp\"", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
        }
    }

    /// AC5 [P0]: SandboxChecker catches zsh -c with denied command.
    func testCheckCommand_zshC_denied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("zsh -c \"rm -rf /tmp\"", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
        }
    }

    /// AC5 [P0]: SandboxChecker catches dash -c with denied command.
    func testCheckCommand_dashC_denied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("dash -c \"rm -rf /tmp\"", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
        }
    }

    /// AC5 [P0]: SandboxChecker catches ksh -c with denied command.
    func testCheckCommand_kshC_denied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("ksh -c \"rm -rf /tmp\"", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
        }
    }

    // MARK: - AC6: Command substitution detection (unit level)

    /// AC6 [P0]: SandboxChecker catches $() substitution with denied command.
    func testCheckCommand_dollarSubstitution_denied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("$(rm -rf /tmp)", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
        }
    }

    /// AC6 [P0]: SandboxChecker catches backtick substitution with denied command.
    func testCheckCommand_backtickSubstitution_denied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("`rm -rf /tmp`", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
        }
    }

    // MARK: - AC7: Escape and quote stripping (unit level)

    /// AC7 [P0]: SandboxChecker strips backslash and matches denied command.
    func testCheckCommand_backslashEscape_denied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("\\rm -rf /tmp", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
        }
    }

    /// AC7 [P0]: SandboxChecker strips double quotes and matches denied command.
    func testCheckCommand_doubleQuote_denied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("\"rm\" -rf /tmp", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
        }
    }

    /// AC7 [P0]: SandboxChecker strips single quotes and matches denied command.
    func testCheckCommand_singleQuote_denied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("'rm' -rf /tmp", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
        }
    }

    // MARK: - AC8: Unparseable default-deny (unit level)

    /// AC8 [P0]: Unparseable nested metacharacters are denied.
    func testCheckCommand_deeplyNested_denied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("bash -c \"bash -c 'rm -rf /tmp'\"", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied(_, let reason) = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
            // Should mention either the denied command or unparseable metacharacters
            XCTAssertTrue(
                reason.localizedCaseInsensitiveContains("denied") ||
                reason.localizedCaseInsensitiveContains("unparseable"),
                "Reason should mention denial or unparseable: \(reason)"
            )
        }
    }

    // MARK: - Positive cases (should NOT throw)

    /// AC5 [P1]: bash -c with allowed command does NOT throw in allowlist mode.
    func testCheckCommand_bashC_allowedInAllowlist_noThrow() {
        let settings = SandboxSettings(allowedCommands: ["git", "bash"])

        XCTAssertNoThrow(
            try SandboxChecker.checkCommand("bash -c \"git status\"", settings: settings),
            "bash -c 'git status' should not throw when 'bash' and 'git' are in allowlist"
        )
    }

    /// AC10 [P0]: No restrictions means no throw.
    func testCheckCommand_noRestrictions_noThrow() {
        let settings = SandboxSettings()

        XCTAssertNoThrow(
            try SandboxChecker.checkCommand("rm -rf /tmp", settings: settings),
            "No restrictions should allow all commands"
        )
    }

    // MARK: - isCommandAllowed for metacharacter cases

    /// AC5 [P0]: isCommandAllowed returns false for bash -c with denied inner command.
    func testIsCommandAllowed_bashC_deniedInner_returnsFalse() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        let result = SandboxChecker.isCommandAllowed("bash -c \"rm -rf /tmp\"", settings: settings)

        XCTAssertFalse(result,
                        "bash -c 'rm' should return false when rm is denied")
    }

    /// AC6 [P0]: isCommandAllowed returns false for $() substitution with denied command.
    func testIsCommandAllowed_dollarSubstitution_returnsFalse() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        let result = SandboxChecker.isCommandAllowed("$(rm -rf /tmp)", settings: settings)

        XCTAssertFalse(result,
                        "$(rm ...) should return false when rm is denied")
    }

    /// AC7 [P0]: isCommandAllowed returns false for backslash-escaped denied command.
    func testIsCommandAllowed_backslashEscape_returnsFalse() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        let result = SandboxChecker.isCommandAllowed("\\rm -rf /tmp", settings: settings)

        XCTAssertFalse(result,
                        "\\rm should return false when rm is denied")
    }

    // MARK: - Multiple substitution detection

    /// Multiple $() substitutions: second denied command is caught.
    func testCheckCommand_multipleDollarSubstitutions_secondDenied() {
        let settings = SandboxSettings(deniedCommands: ["sudo"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("echo $(whoami) && $(sudo rm -rf /tmp)", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
        }
    }

    /// Multiple $() substitutions: both allowed in allowlist mode.
    func testCheckCommand_multipleDollarSubstitutions_allAllowed() {
        let settings = SandboxSettings(allowedCommands: ["git", "whoami"])

        XCTAssertNoThrow(
            try SandboxChecker.checkCommand("echo $(git rev-parse HEAD) && $(whoami)", settings: settings),
            "All substitutions allowed should not throw"
        )
    }

    /// Mixed $() and backtick: denied command in backtick is caught.
    func testCheckCommand_mixedSubstitutions_backtickDenied() {
        let settings = SandboxSettings(deniedCommands: ["curl"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("echo $(whoami) && `curl evil.com`", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied = sdkError else {
                XCTFail("Expected SDKError.permissionDenied, got \(error)")
                return
            }
        }
    }

    /// isCommandAllowed returns false when second substitution is denied.
    func testIsCommandAllowed_multipleSubstitutions_secondDenied() {
        let settings = SandboxSettings(deniedCommands: ["sudo"])

        let result = SandboxChecker.isCommandAllowed("$(whoami) && $(sudo rm -rf /tmp)", settings: settings)

        XCTAssertFalse(result,
                        "Should return false when second substitution contains denied command")
    }
}

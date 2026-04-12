import XCTest
@testable import OpenAgentSDK

// MARK: - ATDD RED PHASE: Story 14.3 -- SandboxSettings Configuration Model
//
// All tests assert EXPECTED behavior. They will FAIL until:
//   - `Types/SandboxSettings.swift` is created with SandboxSettings struct + SandboxOperation enum
//   - `Utils/SandboxPathNormalizer.swift` is created with path normalization utility
//   - `Utils/SandboxChecker.swift` is created with enforcement logic
//   - `Types/SDKConfiguration.swift` is modified to add sandbox field
//   - `Types/AgentTypes.swift` is modified to add sandbox field to AgentOptions
//   - `Types/ToolTypes.swift` is modified to add sandbox field to ToolContext
// TDD Phase: RED (feature not implemented yet)

// MARK: - Test helper for capturing log output in @Sendable closures

/// Thread-safe box for capturing log lines from @Sendable closures.
private final class LogCapture: @unchecked Sendable {
    private var lines: [String] = []
    private let lock = NSLock()

    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        lines.append(line)
    }

    var all: [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return lines.count
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        lines.removeAll()
    }
}

// MARK: - AC1: SandboxSettings struct with all restriction fields

final class SandboxSettingsStructTests: XCTestCase {

    /// AC1 [P0]: SandboxSettings can be created with default empty values (no restrictions).
    func testSandboxSettings_DefaultInit_HasNoRestrictions() {
        let settings = SandboxSettings()

        XCTAssertEqual(settings.allowedReadPaths, [],
                       "Default allowedReadPaths should be empty")
        XCTAssertEqual(settings.allowedWritePaths, [],
                       "Default allowedWritePaths should be empty")
        XCTAssertEqual(settings.deniedPaths, [],
                       "Default deniedPaths should be empty")
        XCTAssertEqual(settings.deniedCommands, [],
                       "Default deniedCommands should be empty")
        XCTAssertNil(settings.allowedCommands,
                      "Default allowedCommands should be nil")
        XCTAssertEqual(settings.allowNestedSandbox, false,
                       "Default allowNestedSandbox should be false")
    }

    /// AC1 [P0]: SandboxSettings can be created with all fields explicitly set.
    func testSandboxSettings_ExplicitInit_AllFieldsSet() {
        let settings = SandboxSettings(
            allowedReadPaths: ["/project/src"],
            allowedWritePaths: ["/project/build"],
            deniedPaths: ["/etc", "/var"],
            deniedCommands: ["rm", "sudo"],
            allowedCommands: ["git", "swift"],
            allowNestedSandbox: true
        )

        XCTAssertEqual(settings.allowedReadPaths, ["/project/src"])
        XCTAssertEqual(settings.allowedWritePaths, ["/project/build"])
        XCTAssertEqual(settings.deniedPaths, ["/etc", "/var"])
        XCTAssertEqual(settings.deniedCommands, ["rm", "sudo"])
        XCTAssertEqual(settings.allowedCommands, ["git", "swift"])
        XCTAssertEqual(settings.allowNestedSandbox, true)
    }

    /// AC1 [P0]: SandboxSettings conforms to Sendable.
    func testSandboxSettings_ConformsToSendable() {
        let settings = SandboxSettings()
        func expectSendable<T: Sendable>(_ value: T) -> Bool { true }
        XCTAssertTrue(expectSendable(settings),
                      "SandboxSettings must conform to Sendable")
    }

    /// AC1 [P0]: SandboxSettings conforms to Equatable.
    func testSandboxSettings_ConformsToEquatable() {
        let settings1 = SandboxSettings(deniedCommands: ["rm"])
        let settings2 = SandboxSettings(deniedCommands: ["rm"])
        let settings3 = SandboxSettings(deniedCommands: ["sudo"])

        XCTAssertEqual(settings1, settings2,
                       "Same settings should be equal")
        XCTAssertNotEqual(settings1, settings3,
                           "Different settings should not be equal")
    }

    /// AC1 [P1]: SandboxSettings conforms to CustomStringConvertible.
    func testSandboxSettings_ConformsToCustomStringConvertible() {
        let settings = SandboxSettings(deniedCommands: ["rm", "sudo"])
        let description = settings.description

        XCTAssertFalse(description.isEmpty,
                        "Description should not be empty")
        XCTAssertTrue(description.contains("rm") || description.contains("deniedCommands"),
                      "Description should contain field information")
    }

    /// AC1 [P1]: SandboxSettings with empty allowedCommands array (not nil) means allowlist mode with nothing allowed.
    func testSandboxSettings_EmptyAllowedCommandsArray_IsAllowlistMode() {
        let settings = SandboxSettings(allowedCommands: [])

        // Empty array is NOT nil -- allowlist mode is active, nothing allowed
        XCTAssertNotNil(settings.allowedCommands,
                         "allowedCommands should be non-nil (empty array)")
        XCTAssertEqual(settings.allowedCommands?.count, 0,
                        "allowedCommands should be empty array")
    }
}

// MARK: - AC2: Path matching uses normalized prefix matching

final class SandboxPathMatchingTests: XCTestCase {

    /// AC2 [P0]: Allowed read path with trailing slash matches subdirectory.
    func testPathMatching_TrailingSlashMatchesSubdirectory() {
        let settings = SandboxSettings(allowedReadPaths: ["/project/"])

        let result = SandboxChecker.isPathAllowed(
            "/project/src/file.swift", for: .read, settings: settings
        )

        XCTAssertTrue(result,
                       "/project/ should match /project/src/file.swift")
    }

    /// AC2 [P0]: Allowed read path without trailing slash does NOT match sibling directory.
    func testPathMatching_TrailingSlashDoesNotMatchSibling() {
        let settings = SandboxSettings(allowedReadPaths: ["/project/"])

        let result = SandboxChecker.isPathAllowed(
            "/project-backup/file.swift", for: .read, settings: settings
        )

        XCTAssertFalse(result,
                        "/project/ should NOT match /project-backup/file.swift")
    }

    /// AC2 [P0]: Path without trailing slash matches direct child.
    func testPathMatching_NoTrailingSlashMatchesDirectChild() {
        let settings = SandboxSettings(allowedReadPaths: ["/project"])

        let result = SandboxChecker.isPathAllowed(
            "/project/file.swift", for: .read, settings: settings
        )

        XCTAssertTrue(result,
                       "/project should match /project/file.swift")
    }

    /// AC2 [P1]: Path with dot-dot traversal is resolved before matching.
    func testPathMatching_DotDotTraversalIsResolved() {
        let settings = SandboxSettings(allowedReadPaths: ["/project/"])

        let result = SandboxChecker.isPathAllowed(
            "/project/src/../secret/file.swift", for: .read, settings: settings
        )

        // After resolving .., path becomes /project/secret/file.swift which is still under /project/
        XCTAssertTrue(result,
                       "/project/src/../secret/file.swift resolved should match /project/")
    }

    /// AC2 [P1]: Denied path takes precedence over allowed path.
    func testPathMatching_DeniedPathOverridesAllowed() {
        let settings = SandboxSettings(
            allowedReadPaths: ["/project/"],
            deniedPaths: ["/project/secret/"]
        )

        let allowedResult = SandboxChecker.isPathAllowed(
            "/project/src/file.swift", for: .read, settings: settings
        )
        let deniedResult = SandboxChecker.isPathAllowed(
            "/project/secret/keys.pem", for: .read, settings: settings
        )

        XCTAssertTrue(allowedResult,
                       "Non-denied subdirectory should be allowed")
        XCTAssertFalse(deniedResult,
                        "Denied subdirectory should be blocked even if under allowed path")
    }

    /// AC2 [P1]: Write operation checks allowedWritePaths, not allowedReadPaths.
    func testPathMatching_WriteOperationChecksWritePaths() {
        let settings = SandboxSettings(
            allowedReadPaths: ["/project/"],
            allowedWritePaths: ["/project/build/"]
        )

        let writeAllowed = SandboxChecker.isPathAllowed(
            "/project/build/output.swift", for: .write, settings: settings
        )
        let writeDenied = SandboxChecker.isPathAllowed(
            "/project/src/file.swift", for: .write, settings: settings
        )

        XCTAssertTrue(writeAllowed,
                       "Write to allowedWritePaths should be allowed")
        XCTAssertFalse(writeDenied,
                        "Write outside allowedWritePaths should be denied")
    }

    /// AC2 [P1]: Empty path restriction lists mean all paths are allowed.
    func testPathMatching_EmptyRestrictions_AllowAll() {
        let settings = SandboxSettings()

        let readResult = SandboxChecker.isPathAllowed(
            "/any/path/file.txt", for: .read, settings: settings
        )
        let writeResult = SandboxChecker.isPathAllowed(
            "/any/path/file.txt", for: .write, settings: settings
        )

        XCTAssertTrue(readResult,
                       "Empty settings should allow all reads")
        XCTAssertTrue(writeResult,
                       "Empty settings should allow all writes")
    }
}

// MARK: - AC3: Command blocklist (default mode)

final class CommandBlocklistTests: XCTestCase {

    /// AC3 [P0]: Command not in denied list is allowed.
    func testBlocklist_CommandNotDenied_IsAllowed() {
        let settings = SandboxSettings(deniedCommands: ["rm", "sudo", "chmod"])

        let result = SandboxChecker.isCommandAllowed("git", settings: settings)

        XCTAssertTrue(result,
                       "git is not in denied list, should be allowed")
    }

    /// AC3 [P0]: Command in denied list is blocked.
    func testBlocklist_CommandDenied_IsBlocked() {
        let settings = SandboxSettings(deniedCommands: ["rm", "sudo", "chmod"])

        let result = SandboxChecker.isCommandAllowed("rm", settings: settings)

        XCTAssertFalse(result,
                        "rm is in denied list, should be blocked")
    }

    /// AC3 [P0]: Command with arguments extracts first token for matching (AC3 spec example).
    func testBlocklist_CommandWithArguments_ExtractsBasename() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        // AC3 spec: "rm -rf /tmp/test" should match denied "rm"
        let result = SandboxChecker.isCommandAllowed("rm -rf /tmp/test", settings: settings)

        XCTAssertFalse(result,
                        "rm -rf /tmp/test should extract basename 'rm' and match denied list")
    }

    /// AC3 [P1]: Command with full path extracts basename for matching.
    func testBlocklist_FullPathExtractsBasename() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        let result = SandboxChecker.isCommandAllowed("/usr/bin/rm", settings: settings)

        XCTAssertFalse(result,
                        "/usr/bin/rm should extract basename 'rm' and match denied list")
    }

    /// AC3 [P1]: Full path with arguments extracts basename correctly.
    func testBlocklist_FullPathWithArguments_ExtractsBasename() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        let result = SandboxChecker.isCommandAllowed("/usr/bin/rm -rf /tmp/test", settings: settings)

        XCTAssertFalse(result,
                        "/usr/bin/rm -rf /tmp/test should extract basename 'rm' and match denied list")
    }

    /// AC3 [P1]: No command restrictions means all commands allowed.
    func testBlocklist_NoRestrictions_AllowsAll() {
        let settings = SandboxSettings()

        let result = SandboxChecker.isCommandAllowed("rm", settings: settings)

        XCTAssertTrue(result,
                       "With no restrictions, all commands should be allowed")
    }

    /// AC3 [P1]: Command matching is case-sensitive.
    func testBlocklist_CaseSensitive() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        let upperResult = SandboxChecker.isCommandAllowed("RM", settings: settings)

        // Case-sensitive: "RM" != "rm"
        XCTAssertTrue(upperResult,
                       "Command matching should be case-sensitive: RM != rm")
    }
}

// MARK: - AC4: Command allowlist mode

final class CommandAllowlistTests: XCTestCase {

    /// AC4 [P0]: When allowedCommands is set, only listed commands are permitted.
    func testAllowlist_OnlyListedCommandsAllowed() {
        let settings = SandboxSettings(
            deniedCommands: ["rm"],
            allowedCommands: ["git", "swift", "xcodebuild"]
        )

        let gitAllowed = SandboxChecker.isCommandAllowed("git", settings: settings)
        let rmDenied = SandboxChecker.isCommandAllowed("rm", settings: settings)

        XCTAssertTrue(gitAllowed,
                       "git should be allowed (in allowlist)")
        XCTAssertFalse(rmDenied,
                        "rm should be denied (not in allowlist)")
    }

    /// AC4 [P0]: Allowlist takes precedence over blocklist.
    func testAllowlist_TakesPrecedenceOverBlocklist() {
        let settings = SandboxSettings(
            deniedCommands: ["git"],
            allowedCommands: ["git", "swift"]
        )

        // git is in BOTH denied and allowed lists
        // Allowlist takes precedence: git should be ALLOWED
        let result = SandboxChecker.isCommandAllowed("git", settings: settings)

        XCTAssertTrue(result,
                       "Allowlist takes precedence: git is in allowlist so it should be allowed")
    }

    /// AC4 [P0]: Command not in allowlist is denied.
    func testAllowlist_CommandNotInList_IsDenied() {
        let settings = SandboxSettings(allowedCommands: ["git"])

        let result = SandboxChecker.isCommandAllowed("npm", settings: settings)

        XCTAssertFalse(result,
                        "npm is not in allowlist, should be denied")
    }

    /// AC4 [P1]: Empty allowlist means no commands allowed (most restrictive).
    func testAllowlist_EmptyArray_NothingAllowed() {
        let settings = SandboxSettings(allowedCommands: [])

        let result = SandboxChecker.isCommandAllowed("git", settings: settings)

        XCTAssertFalse(result,
                        "Empty allowlist should deny all commands")
    }

    /// AC4 [P1]: When allowedCommands is nil, blocklist mode is active.
    func testAllowlist_NilUsesBlocklistMode() {
        let settings = SandboxSettings(
            deniedCommands: ["rm"],
            allowedCommands: nil
        )

        let gitAllowed = SandboxChecker.isCommandAllowed("git", settings: settings)
        let rmDenied = SandboxChecker.isCommandAllowed("rm", settings: settings)

        XCTAssertTrue(gitAllowed,
                       "Blocklist mode: git not in denied list -> allowed")
        XCTAssertFalse(rmDenied,
                        "Blocklist mode: rm in denied list -> denied")
    }
}

// MARK: - AC5: SDKConfiguration integration

final class SandboxSDKConfigurationTests: XCTestCase {

    /// AC5 [P0]: SDKConfiguration has a sandbox field with default nil.
    func testSDKConfiguration_HasSandboxField_DefaultNil() {
        let config = SDKConfiguration()

        XCTAssertNil(config.sandbox,
                      "Default sandbox should be nil")
    }

    /// AC5 [P0]: SDKConfiguration can be created with sandbox settings.
    func testSDKConfiguration_CanSetSandbox() {
        let settings = SandboxSettings(deniedCommands: ["rm"])
        let config = SDKConfiguration(sandbox: settings)

        XCTAssertNotNil(config.sandbox,
                         "Sandbox should be settable")
        XCTAssertEqual(config.sandbox?.deniedCommands, ["rm"],
                        "Sandbox settings should be preserved")
    }

    /// AC5 [P1]: SDKConfiguration includes sandbox in description.
    func testSDKConfiguration_SandboxInDescription() {
        let settings = SandboxSettings(deniedCommands: ["rm"])
        let config = SDKConfiguration(sandbox: settings)
        let description = config.description

        XCTAssertTrue(description.contains("sandbox"),
                       "Description should mention sandbox field")
    }

    /// AC5 [P0]: SDKConfiguration with same sandbox values are equal.
    func testSDKConfiguration_SandboxEquality() {
        let settings1 = SandboxSettings(deniedCommands: ["rm"])
        let settings2 = SandboxSettings(deniedCommands: ["rm"])
        let config1 = SDKConfiguration(sandbox: settings1)
        let config2 = SDKConfiguration(sandbox: settings2)

        XCTAssertEqual(config1, config2,
                        "Configurations with same sandbox should be equal")

        let settings3 = SandboxSettings(deniedCommands: ["sudo"])
        let config3 = SDKConfiguration(sandbox: settings3)
        XCTAssertNotEqual(config1, config3,
                            "Configurations with different sandbox should not be equal")
    }

    /// AC5 [P1]: SDKConfiguration.resolved merges sandbox from overrides.
    func testSDKConfiguration_ResolvedMergesSandbox() {
        let overrides = SDKConfiguration(sandbox: SandboxSettings(deniedCommands: ["rm"]))
        let resolved = SDKConfiguration.resolved(overrides: overrides)

        XCTAssertNotNil(resolved.sandbox,
                         "resolved() should use override sandbox")
        XCTAssertEqual(resolved.sandbox?.deniedCommands, ["rm"],
                        "resolved() sandbox should match override")
    }
}

// MARK: - AC6: AgentOptions passthrough

final class SandboxAgentOptionsTests: XCTestCase {

    /// AC6 [P0]: AgentOptions has a sandbox field with default nil.
    func testAgentOptions_HasSandboxField_DefaultNil() {
        let options = AgentOptions()

        XCTAssertNil(options.sandbox,
                      "Default sandbox should be nil")
    }

    /// AC6 [P0]: AgentOptions can be created with sandbox settings.
    func testAgentOptions_CanSetSandbox() {
        let settings = SandboxSettings(deniedCommands: ["rm"])
        let options = AgentOptions(sandbox: settings)

        XCTAssertNotNil(options.sandbox,
                         "Sandbox should be settable in AgentOptions")
        XCTAssertEqual(options.sandbox?.deniedCommands, ["rm"],
                        "Sandbox settings should be preserved in AgentOptions")
    }

    /// AC6 [P1]: AgentOptions init from config propagates sandbox.
    func testAgentOptions_InitFromConfig_PropagatesSandbox() {
        let settings = SandboxSettings(deniedCommands: ["rm"])
        let config = SDKConfiguration(sandbox: settings)
        let options = AgentOptions(from: config)

        XCTAssertNotNil(options.sandbox,
                         "AgentOptions(from:) should propagate sandbox from config")
        XCTAssertEqual(options.sandbox?.deniedCommands, ["rm"],
                        "Sandbox settings should be preserved through config->options")
    }
}

// MARK: - AC7: SandboxPathNormalizer utility

final class SandboxPathNormalizerTests: XCTestCase {

    /// AC7 [P0]: Normalizes path with dot-dot traversal.
    func testPathNormalizer_ResolvesDotDot() {
        let input = "/project/../etc/passwd"
        let normalized = SandboxPathNormalizer.normalize(input)

        XCTAssertFalse(normalized.contains(".."),
                        "Normalized path should not contain '..'")
        XCTAssertTrue(normalized.hasPrefix("/"),
                       "Normalized path should be absolute")
    }

    /// AC7 [P0]: Normalizes relative path to absolute.
    func testPathNormalizer_ResolvesRelativePath() {
        let input = "relative/path/to/file.swift"
        let normalized = SandboxPathNormalizer.normalize(input)

        XCTAssertTrue(normalized.hasPrefix("/"),
                       "Relative path should be resolved to absolute")
    }

    /// AC7 [P0]: Already-normalized path stays the same.
    func testPathNormalizer_AlreadyNormalized_StaysSame() {
        let input = "/absolute/path/to/file.swift"
        let normalized = SandboxPathNormalizer.normalize(input)

        XCTAssertEqual(normalized, input,
                        "Already-normalized absolute path should stay the same")
    }

    /// AC7 [P1]: Normalizes path with dot segments.
    func testPathNormalizer_ResolvesDotSegments() {
        let input = "/project/./src/../build/file.swift"
        let normalized = SandboxPathNormalizer.normalize(input)

        XCTAssertFalse(normalized.contains("/./"),
                        "Normalized path should not contain '/./'")
        XCTAssertFalse(normalized.contains(".."),
                        "Normalized path should not contain '..'")
    }

    /// AC7 [P1]: Trailing slashes are standardized.
    func testPathNormalizer_TrailingSlashStandardized() {
        let input = "/project/src/"
        let normalized = SandboxPathNormalizer.normalize(input)

        // Either trailing slash is removed or kept consistently
        let trimmed = normalized.hasSuffix("/") ? String(normalized.dropLast()) : normalized
        XCTAssertTrue(trimmed == "/project/src",
                       "Trailing slash should be standardized: got \(normalized)")
    }

    /// AC7 [P1]: Empty path returns something safe (not crash).
    func testPathNormalizer_EmptyPath_DoesNotCrash() {
        let normalized = SandboxPathNormalizer.normalize("")

        // Should not crash; may return empty or "/"
        XCTAssertTrue(normalized.isEmpty || normalized == "/",
                      "Empty path should return empty or root, got: \(normalized)")
    }

    /// AC7 [P1]: Normalization uses URL.resolvingSymlinksInPath, not POSIX realpath.
    func testPathNormalizer_UsesURLAPI() {
        // This test verifies behavior, not implementation. The implementation
        // should use URL(fileURLWithPath:).resolvingSymlinksInPath().path
        let input = "/tmp/../var"
        let normalized = SandboxPathNormalizer.normalize(input)

        // Resolved should not contain ".."
        XCTAssertFalse(normalized.contains(".."),
                        "Path should be resolved without dot-dot segments")
    }
}

// MARK: - AC8: SandboxChecker utility

final class SandboxCheckerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Logger.reset()
    }

    override func tearDown() {
        Logger.reset()
        super.tearDown()
    }

    // MARK: - isPathAllowed

    /// AC8 [P0]: SandboxChecker.isPathAllowed returns true for unrestricted settings.
    func testSandboxChecker_IsPathAllowed_NoRestrictions_ReturnsTrue() {
        let settings = SandboxSettings()

        let result = SandboxChecker.isPathAllowed("/any/path", for: .read, settings: settings)

        XCTAssertTrue(result,
                       "No restrictions should allow all paths")
    }

    /// AC8 [P0]: SandboxChecker.isPathAllowed returns false for denied path.
    func testSandboxChecker_IsPathAllowed_DeniedPath_ReturnsFalse() {
        let settings = SandboxSettings(deniedPaths: ["/etc/"])

        let result = SandboxChecker.isPathAllowed("/etc/passwd", for: .read, settings: settings)

        XCTAssertFalse(result,
                        "Denied path should return false")
    }

    /// AC8 [P0]: SandboxChecker.isPathAllowed returns true for path under allowed read paths.
    func testSandboxChecker_IsPathAllowed_AllowedReadPath_ReturnsTrue() {
        let settings = SandboxSettings(allowedReadPaths: ["/project/"])

        let result = SandboxChecker.isPathAllowed("/project/src/file.swift", for: .read, settings: settings)

        XCTAssertTrue(result,
                       "Path under allowedReadPaths should return true")
    }

    /// AC8 [P1]: SandboxChecker.isPathAllowed checks write paths for write operation.
    func testSandboxChecker_IsPathAllowed_WriteChecksWritePaths() {
        let settings = SandboxSettings(allowedWritePaths: ["/project/build/"])

        let allowed = SandboxChecker.isPathAllowed("/project/build/output", for: .write, settings: settings)
        let denied = SandboxChecker.isPathAllowed("/project/src/file.swift", for: .write, settings: settings)

        XCTAssertTrue(allowed,
                       "Write to allowedWritePaths should be true")
        XCTAssertFalse(denied,
                        "Write outside allowedWritePaths should be false")
    }

    // MARK: - isCommandAllowed

    /// AC8 [P0]: SandboxChecker.isCommandAllowed returns true for unrestricted settings.
    func testSandboxChecker_IsCommandAllowed_NoRestrictions_ReturnsTrue() {
        let settings = SandboxSettings()

        let result = SandboxChecker.isCommandAllowed("rm", settings: settings)

        XCTAssertTrue(result,
                       "No restrictions should allow all commands")
    }

    /// AC8 [P0]: SandboxChecker.isCommandAllowed returns false for denied command.
    func testSandboxChecker_IsCommandAllowed_DeniedCommand_ReturnsFalse() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        let result = SandboxChecker.isCommandAllowed("rm", settings: settings)

        XCTAssertFalse(result,
                        "Denied command should return false")
    }

    /// AC8 [P0]: SandboxChecker.isCommandAllowed in allowlist mode returns false for unlisted command.
    func testSandboxChecker_IsCommandAllowed_AllowlistMode_ReturnsFalseForUnlisted() {
        let settings = SandboxSettings(allowedCommands: ["git"])

        let result = SandboxChecker.isCommandAllowed("rm", settings: settings)

        XCTAssertFalse(result,
                        "Unlisted command in allowlist mode should return false")
    }

    // MARK: - checkPath (throws)

    /// AC8 [P0]: SandboxChecker.checkPath throws SDKError.permissionDenied for denied path.
    func testSandboxChecker_CheckPath_ThrowsPermissionDenied() {
        let settings = SandboxSettings(deniedPaths: ["/etc/"])

        XCTAssertThrowsError(
            try SandboxChecker.checkPath("/etc/passwd", for: .read, settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError else {
                XCTFail("Expected SDKError, got \(type(of: error))")
                return
            }
            guard case .permissionDenied(let tool, let reason) = sdkError else {
                XCTFail("Expected .permissionDenied, got \(sdkError)")
                return
            }
            XCTAssertEqual(tool, "Read",
                            "Tool name should be 'Read' for read operation")
            XCTAssertTrue(reason.contains("path") || reason.contains("scope"),
                           "Reason should mention path restriction: \(reason)")
        }
    }

    /// AC8 [P0]: SandboxChecker.checkPath does NOT throw for allowed path.
    func testSandboxChecker_CheckPath_AllowedPath_DoesNotThrow() {
        let settings = SandboxSettings(allowedReadPaths: ["/project/"])

        XCTAssertNoThrow(
            try SandboxChecker.checkPath("/project/file.swift", for: .read, settings: settings),
            "Allowed path should not throw"
        )
    }

    // MARK: - checkCommand (throws)

    /// AC8 [P0]: SandboxChecker.checkCommand throws SDKError.permissionDenied for denied command.
    func testSandboxChecker_CheckCommand_ThrowsPermissionDenied() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("rm", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError else {
                XCTFail("Expected SDKError, got \(type(of: error))")
                return
            }
            guard case .permissionDenied(let tool, let reason) = sdkError else {
                XCTFail("Expected .permissionDenied, got \(sdkError)")
                return
            }
            XCTAssertEqual(tool, "Bash",
                            "Tool name should be 'Bash' for command check")
            XCTAssertTrue(reason.contains("command") || reason.contains("denied"),
                           "Reason should mention command denial: \(reason)")
        }
    }

    /// AC8 [P0]: SandboxChecker.checkCommand does NOT throw for allowed command.
    func testSandboxChecker_CheckCommand_AllowedCommand_DoesNotThrow() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertNoThrow(
            try SandboxChecker.checkCommand("git", settings: settings),
            "Allowed command should not throw"
        )
    }

    // MARK: - Error message conventions

    /// AC8 [P1]: checkPath error message follows convention.
    func testSandboxChecker_CheckPath_ErrorMessageConvention() {
        let settings = SandboxSettings(deniedPaths: ["/etc/"])

        XCTAssertThrowsError(
            try SandboxChecker.checkPath("/etc/passwd", for: .read, settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied(_, let reason) = sdkError else {
                XCTFail("Expected SDKError.permissionDenied")
                return
            }
            XCTAssertTrue(reason.contains("outside") || reason.contains("allowed") || reason.contains("scope"),
                           "Path denial reason should use convention: \(reason)")
        }
    }

    /// AC8 [P1]: checkCommand error message follows convention.
    func testSandboxChecker_CheckCommand_ErrorMessageConvention() {
        let settings = SandboxSettings(deniedCommands: ["rm"])

        XCTAssertThrowsError(
            try SandboxChecker.checkCommand("rm", settings: settings)
        ) { error in
            guard let sdkError = error as? SDKError,
                  case .permissionDenied(_, let reason) = sdkError else {
                XCTFail("Expected SDKError.permissionDenied")
                return
            }
            XCTAssertTrue(reason.contains("denied") || reason.contains("sandbox"),
                           "Command denial reason should use convention: \(reason)")
        }
    }

    // MARK: - Logger integration for denials

    /// AC8 [P1]: SandboxChecker logs denials at info level.
    func testSandboxChecker_LogsDenialAtInfoLevel() {
        let capture = LogCapture()
        Logger.configure(level: .debug, output: .custom { line in
            capture.append(line)
        })

        let settings = SandboxSettings(deniedCommands: ["rm"])
        _ = try? SandboxChecker.checkCommand("rm", settings: settings)

        XCTAssertTrue(capture.count > 0,
                       "SandboxChecker should log denial events")
        XCTAssertTrue(capture.all[0].contains("info") || capture.all[0].contains("denial"),
                       "Log should be at info level or contain 'denial'")
    }
}

// MARK: - ToolContext integration

final class SandboxToolContextTests: XCTestCase {

    /// AC6 [P0]: ToolContext has a sandbox field with default nil.
    func testToolContext_HasSandboxField_DefaultNil() {
        let context = ToolContext(cwd: "/tmp")

        XCTAssertNil(context.sandbox,
                      "Default sandbox in ToolContext should be nil")
    }

    /// AC6 [P0]: ToolContext can be created with sandbox settings.
    func testToolContext_CanSetSandbox() {
        let settings = SandboxSettings(deniedCommands: ["rm"])
        let context = ToolContext(cwd: "/tmp", sandbox: settings)

        XCTAssertNotNil(context.sandbox,
                         "Sandbox should be settable in ToolContext")
        XCTAssertEqual(context.sandbox?.deniedCommands, ["rm"],
                        "Sandbox settings should be preserved in ToolContext")
    }
}

// MARK: - SandboxOperation enum

final class SandboxOperationTests: XCTestCase {

    /// AC2 [P0]: SandboxOperation has read and write cases.
    func testSandboxOperation_HasReadAndWriteCases() {
        let readOp: SandboxOperation = .read
        let writeOp: SandboxOperation = .write

        // This verifies the cases exist at compile time
        XCTAssertNotEqual(readOp, writeOp,
                           ".read and .write should be distinct cases")
    }

    /// AC2 [P1]: SandboxOperation conforms to Sendable.
    func testSandboxOperation_ConformsToSendable() {
        func expectSendable<T: Sendable>(_ value: T) -> Bool { true }
        XCTAssertTrue(expectSendable(SandboxOperation.read),
                       "SandboxOperation must conform to Sendable")
        XCTAssertTrue(expectSendable(SandboxOperation.write),
                       "SandboxOperation must conform to Sendable")
    }

    /// AC2 [P1]: SandboxOperation conforms to Equatable.
    func testSandboxOperation_ConformsToEquatable() {
        XCTAssertEqual(SandboxOperation.read, SandboxOperation.read,
                        "Same operations should be equal")
        XCTAssertNotEqual(SandboxOperation.read, SandboxOperation.write,
                            "Different operations should not be equal")
    }
}

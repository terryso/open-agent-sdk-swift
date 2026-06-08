import XCTest
import Foundation

// MARK: - ATDD Tests for Story 15-2: SandboxExample
// TDD RED PHASE: These tests will FAIL until Examples/SandboxExample/ is created
// and Package.swift is updated with the SandboxExample executableTarget.

final class SandboxExampleComplianceTests: XCTestCase {

    // MARK: - Helpers

    private func examplePath() -> String {
        return DocumentationTestHelpers.examplesDir() + "/SandboxExample/main.swift"
    }

    // MARK: - AC9: Package.swift executableTarget Configured

    func testPackageSwiftContainsSandboxExampleTarget() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("SandboxExample"),
            "Package.swift should contain SandboxExample executable target"
        )
    }

    func testSandboxExampleTargetDependsOnOpenAgentSDK() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("SandboxExample"),
            "Package.swift should contain SandboxExample target before checking dependencies"
        )
        let targetRange = content.range(of: "SandboxExample")
        XCTAssertNotNil(targetRange, "Should find SandboxExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "SandboxExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testSandboxExampleTargetSpecifiesCorrectPath() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("SandboxExample"),
            "Package.swift should contain SandboxExample target before checking path"
        )
        let targetRange = content.range(of: "SandboxExample")
        XCTAssertNotNil(targetRange, "Should find SandboxExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/SandboxExample"),
                    "SandboxExample target should specify path: 'Examples/SandboxExample'"
                )
            }
        }
    }

    // MARK: - AC1: SandboxExample Directory and File Exist

    func testSandboxExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: DocumentationTestHelpers.examplesDir() + "/SandboxExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/SandboxExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/SandboxExample/ should be a directory")
    }

    func testSandboxExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/SandboxExample/main.swift should exist"
        )
    }

    func testSandboxExampleImportsOpenAgentSDK() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "SandboxExample should import OpenAgentSDK"
        )
    }

    func testSandboxExampleImportsFoundation() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import Foundation"),
            "SandboxExample should import Foundation"
        )
    }

    // MARK: - AC1: Code Quality

    func testSandboxExampleHasTopLevelDescriptionComment() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "SandboxExample should start with a descriptive comment block"
        )
    }

    func testSandboxExampleHasMultipleInlineComments() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 5,
            "SandboxExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testSandboxExampleHasMarkSections() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("MARK:"),
            "SandboxExample should use MARK section comments for organization"
        )
    }

    func testSandboxExampleDoesNotUseForceUnwrap() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            XCTAssertFalse(
                trimmed.contains("try!"),
                "SandboxExample should not use 'try!' force-try"
            )
        }
    }

    // MARK: - AC2: File System Path Restrictions

    func testSandboxExampleCreatesSandboxSettingsWithPathRestrictions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("SandboxSettings("),
            "SandboxExample should create SandboxSettings instances for path restrictions"
        )
    }

    func testSandboxExampleDemonstratesAllowedReadPaths() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("allowedReadPaths:"),
            "SandboxExample should demonstrate allowedReadPaths configuration"
        )
    }

    func testSandboxExampleDemonstratesAllowedWritePaths() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("allowedWritePaths:"),
            "SandboxExample should demonstrate allowedWritePaths configuration"
        )
    }

    func testSandboxExampleDemonstratesDeniedPaths() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("deniedPaths:"),
            "SandboxExample should demonstrate deniedPaths configuration"
        )
    }

    func testSandboxExampleUsesSandboxSettingsInit() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should have at least 2 SandboxSettings instances (path + command configs)
        let settingsOccurrences = content.components(separatedBy: "SandboxSettings(").count - 1
        XCTAssertGreaterThanOrEqual(
            settingsOccurrences, 2,
            "SandboxExample should create at least 2 SandboxSettings instances (path + command)"
        )
    }

    // MARK: - AC3: Command Blocklist (deniedCommands)

    func testSandboxExampleCreatesBlocklistSandboxSettings() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("deniedCommands:"),
            "SandboxExample should create SandboxSettings with deniedCommands for blocklist mode"
        )
    }

    func testSandboxExampleBlocklistContainsDangerousCommands() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should include at least "rm" in the blocklist (standard dangerous command)
        XCTAssertTrue(
            content.contains("\"rm\""),
            "SandboxExample blocklist should include 'rm' as a dangerous command example"
        )
    }

    func testSandboxExampleDemonstratesBlocklistRejection() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should show catching/handling of permissionDenied for blocklist
        XCTAssertTrue(
            content.contains("SandboxChecker"),
            "SandboxExample should use SandboxChecker to demonstrate command checking"
        )
    }

    func testSandboxExampleUsesDeniedCommandsParameter() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // The deniedCommands parameter should contain at least "rm" and "sudo"
        // (per story AC: "deniedCommands: ["rm", "sudo"]")
        XCTAssertTrue(
            content.contains("deniedCommands:") && content.contains("\"rm\""),
            "SandboxExample should show deniedCommands containing dangerous commands like 'rm'"
        )
    }

    // MARK: - AC4: Command Allowlist (allowedCommands)

    func testSandboxExampleCreatesAllowlistSandboxSettings() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("allowedCommands:"),
            "SandboxExample should create SandboxSettings with allowedCommands for allowlist mode"
        )
    }

    func testSandboxExampleAllowlistContainsSafeCommands() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Per story AC: allowedCommands: ["git", "swift"]
        XCTAssertTrue(
            content.contains("\"git\""),
            "SandboxExample allowlist should include 'git' as a safe command example"
        )
    }

    func testSandboxExampleDemonstratesAllowlistAcceptance() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should show that allowlisted commands are permitted
        // Either via SandboxChecker.isCommandAllowed or checkCommand succeeding
        let usesCheck = content.contains("checkCommand(") || content.contains("isCommandAllowed(")
        XCTAssertTrue(
            usesCheck,
            "SandboxExample should demonstrate command checking (checkCommand or isCommandAllowed)"
        )
    }

    func testSandboxExampleUsesAllowedCommandsParameter() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // allowedCommands should be set to a non-nil array (not nil which is blocklist mode)
        // Look for the pattern: allowedCommands: [ ... ] (non-nil array)
        XCTAssertTrue(
            content.contains("allowedCommands:"),
            "SandboxExample should use allowedCommands parameter with explicit array value"
        )
    }

    // MARK: - AC5: Path Traversal and Symlink Resolution

    func testSandboxExampleDemonstratesPathTraversalProtection() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should show path traversal protection (e.g., /project/subdir/../../../etc/passwd)
        let hasTraversal = content.contains("../") || content.contains("..")
        XCTAssertTrue(
            hasTraversal,
            "SandboxExample should demonstrate path traversal protection with '..' patterns"
        )
    }

    func testSandboxExampleReferencesDotDotPathPattern() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should explicitly reference a path containing ".." to show traversal
        XCTAssertTrue(
            content.contains("../"),
            "SandboxExample should reference '../' path pattern to demonstrate traversal protection"
        )
    }

    func testSandboxExampleDemonstratesSymlinkResolution() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should mention symlinks or use SandboxPathNormalizer for symlink resolution
        let mentionsSymlink = content.contains("symlink") || content.contains("Symlink") ||
                              content.contains("symbolic link") || content.contains("resolvingSymlinksInPath")
        XCTAssertTrue(
            mentionsSymlink,
            "SandboxExample should mention symlink resolution in comments or code"
        )
    }

    func testSandboxExampleUsesSandboxPathNormalizer() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("SandboxPathNormalizer"),
            "SandboxExample should use SandboxPathNormalizer for path normalization demo"
        )
    }

    // MARK: - AC6: Shell Metacharacter Detection

    func testSandboxExampleDemonstratesSubshellDetection() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should show bash -c detection
        XCTAssertTrue(
            content.contains("bash -c") || content.contains("sh -c") || content.contains("zsh -c"),
            "SandboxExample should demonstrate subshell detection (bash -c, sh -c, etc.)"
        )
    }

    func testSandboxExampleReferencesBashDashC() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should reference "bash -c" explicitly (string literal in example)
        XCTAssertTrue(
            content.contains("bash -c"),
            "SandboxExample should reference 'bash -c' pattern for subshell detection demo"
        )
    }

    func testSandboxExampleDemonstratesCommandSubstitution() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should show command substitution detection: $(...) or backtick
        let hasSubstitution = content.contains("$(") || content.contains("`rm")
        XCTAssertTrue(
            hasSubstitution,
            "SandboxExample should demonstrate command substitution detection ($() or backtick)"
        )
    }

    func testSandboxExampleDemonstratesEscapeBypassDetection() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should show escape bypass: \rm or "rm" patterns
        let hasEscape = content.contains("\\rm") || content.contains("\\\"rm\\\"") ||
                        content.contains("\"rm\"")
        XCTAssertTrue(
            hasEscape,
            "SandboxExample should demonstrate escape/quote bypass detection (\\rm or \"rm\")"
        )
    }

    // MARK: - AC7: Permission Denied Error Handling

    func testSandboxExampleCatchesPermissionDeniedError() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should use do/try/catch to catch permissionDenied errors
        XCTAssertTrue(
            content.contains("catch") && content.contains("try"),
            "SandboxExample should demonstrate try/catch for permissionDenied errors"
        )
    }

    func testSandboxExampleUsesSandboxCheckerCheckPath() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("SandboxChecker") && content.contains("checkPath("),
            "SandboxExample should use SandboxChecker.checkPath() for path validation"
        )
    }

    func testSandboxExampleUsesSandboxCheckerCheckCommand() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("SandboxChecker") && content.contains("checkCommand("),
            "SandboxExample should use SandboxChecker.checkCommand() for command validation"
        )
    }

    // MARK: - AC8: Allowlist vs Blocklist Comparison

    func testSandboxExampleDemonstratesAllowlistVsBlocklist() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should have both deniedCommands and allowedCommands to show comparison
        XCTAssertTrue(
            content.contains("deniedCommands:") && content.contains("allowedCommands:"),
            "SandboxExample should demonstrate both blocklist (deniedCommands) and allowlist (allowedCommands) modes"
        )
    }

    func testSandboxExampleShowsBehaviorDifference() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should show that git is allowed in allowlist but rm is denied
        // Both "git" and "rm" should appear as test commands
        XCTAssertTrue(
            content.contains("\"git\"") && content.contains("\"rm\""),
            "SandboxExample should test both 'git' (allowed) and 'rm' (denied) to show behavioral difference"
        )
    }

    // MARK: - AC10: API Key Safety and Environment Patterns

    func testSandboxExampleDoesNotExposeRealAPIKeys() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            if line.contains("sk-") && !line.contains("sk-...") && !line.contains("sk-xxx") {
                let afterSk = line.components(separatedBy: "sk-")
                if afterSk.count > 1 {
                    let remainder = afterSk[1].trimmingCharacters(in: .whitespaces)
                    let isPlaceholder = remainder.hasPrefix("...") ||
                        remainder.hasPrefix("xxx") ||
                        remainder.hasPrefix("your") ||
                        remainder.hasPrefix("<")
                    XCTAssertTrue(
                        isPlaceholder,
                        "SandboxExample should not contain a real-looking API key"
                    )
                }
            }
        }
    }

    func testSandboxExampleUsesLoadDotEnvPattern() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("loadDotEnv()"),
            "SandboxExample should use loadDotEnv() helper pattern"
        )
    }

    func testSandboxExampleUsesGetEnvPattern() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("getEnv("),
            "SandboxExample should use getEnv() helper pattern for API key loading"
        )
    }
}

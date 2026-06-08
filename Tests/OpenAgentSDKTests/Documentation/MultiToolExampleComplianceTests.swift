import XCTest
import Foundation

// MARK: - ATDD Tests for Story 10-1: MultiToolExample (Multi-Tool Orchestration Example)
// TDD RED PHASE: These tests will FAIL until Examples/MultiToolExample/ is created
// and Package.swift is updated with the MultiToolExample executableTarget.

final class MultiToolExampleComplianceTests: XCTestCase {

    // MARK: - Helpers

    private func multiToolExamplePath() -> String {
        return DocumentationTestHelpers.examplesDir() + "/MultiToolExample/main.swift"
    }

    // MARK: - AC5: Package.swift executableTarget Configured

    func testPackageSwiftContainsMultiToolExampleTarget() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("MultiToolExample"),
            "Package.swift should contain MultiToolExample executable target"
        )
    }

    func testMultiToolExampleTargetDependsOnOpenAgentSDK() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("MultiToolExample"),
            "Package.swift should contain MultiToolExample target before checking dependencies"
        )
        // Find the executableTarget definition for MultiToolExample
        let targetRange = content.range(of: "MultiToolExample")
        XCTAssertNotNil(targetRange, "Should find MultiToolExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "MultiToolExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testMultiToolExampleTargetSpecifiesCorrectPath() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("MultiToolExample"),
            "Package.swift should contain MultiToolExample target before checking path"
        )
        let targetRange = content.range(of: "MultiToolExample")
        XCTAssertNotNil(targetRange, "Should find MultiToolExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/MultiToolExample"),
                    "MultiToolExample target should specify path: 'Examples/MultiToolExample'"
                )
            }
        }
    }

    // MARK: - AC1: MultiToolExample Directory and File Exist

    func testMultiToolExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: DocumentationTestHelpers.examplesDir() + "/MultiToolExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/MultiToolExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/MultiToolExample/ should be a directory")
    }

    func testMultiToolExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: multiToolExamplePath()),
            "Examples/MultiToolExample/main.swift should exist"
        )
    }

    func testMultiToolExampleImportsOpenAgentSDK() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "MultiToolExample should import OpenAgentSDK"
        )
    }

    func testMultiToolExampleImportsFoundation() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        XCTAssertTrue(
            content.contains("import Foundation"),
            "MultiToolExample should import Foundation for ProcessInfo"
        )
    }

    func testMultiToolExampleUsesCreateAgent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        XCTAssertTrue(
            content.contains("createAgent("),
            "MultiToolExample should use createAgent() factory function"
        )
    }

    func testMultiToolExampleRegistersCoreTools() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        XCTAssertTrue(
            content.contains("getAllBaseTools(tier: .core)"),
            "MultiToolExample should register all core tools via getAllBaseTools(tier: .core)"
        )
    }

    func testMultiToolExampleUsesBypassPermissions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        XCTAssertTrue(
            content.contains(".bypassPermissions"),
            "MultiToolExample should set permissionMode to .bypassPermissions"
        )
    }

    // MARK: - AC2: Uses Streaming API for Real-Time Events

    func testMultiToolExampleUsesStreamingAPI() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        XCTAssertTrue(
            content.contains("for await") && content.contains("agent.stream("),
            "MultiToolExample should use 'for await ... in agent.stream(...)' pattern"
        )
    }

    func testMultiToolExampleHandlesPartialMessage() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        XCTAssertTrue(
            content.contains(".partialMessage"),
            "MultiToolExample should handle .partialMessage case for incremental text"
        )
    }

    func testMultiToolExampleHandlesToolUseEvent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        XCTAssertTrue(
            content.contains(".toolUse"),
            "MultiToolExample should handle .toolUse case to display tool invocations"
        )
    }

    func testMultiToolExampleHandlesToolResultEvent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        XCTAssertTrue(
            content.contains(".toolResult"),
            "MultiToolExample should handle .toolResult case to display tool results"
        )
    }

    // MARK: - AC3: Demonstrates Multi-Tool Orchestration

    func testMultiToolExampleHasMultiStepSystemPrompt() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        // System prompt should guide the agent to use multiple tools
        XCTAssertTrue(
            content.contains("systemPrompt:"),
            "MultiToolExample should define a systemPrompt"
        )
        // The prompt sent to the agent should require multi-step orchestration
        XCTAssertTrue(
            content.contains("agent.stream(") || content.contains("stream("),
            "MultiToolExample should send a prompt that requires multi-tool orchestration"
        )
    }

    func testMultiToolExampleDisplaysToolNameAndInput() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        // Should display tool name and input from ToolUseData
        let hasToolName = content.contains("toolName") || content.contains("data.toolName")
        XCTAssertTrue(
            hasToolName,
            "MultiToolExample should display tool name from .toolUse event data"
        )
    }

    // MARK: - AC4: Final Output Includes Task Summary and Statistics

    func testMultiToolExampleHandlesResultEvent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        XCTAssertTrue(
            content.contains(".result("),
            "MultiToolExample should handle .result case for final statistics"
        )
    }

    func testMultiToolExampleDisplaysUsageStatistics() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        // Should display numTurns and usage from result data
        let hasTurns = content.contains("numTurns") || content.contains("data.numTurns")
        XCTAssertTrue(
            hasTurns,
            "MultiToolExample should display numTurns from result data"
        )

        // Should display cost information
        let hasCost = content.contains("totalCostUsd") || content.contains("cost")
        XCTAssertTrue(
            hasCost,
            "MultiToolExample should display cost information from result data"
        )
    }

    func testMultiToolExampleSafelyUnwrapsOptionalUsage() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        // data.usage is Optional<TokenUsage> so should use if let or guard let
        let hasSafeUnwrap = content.contains("if let usage") || content.contains("guard let usage")
        XCTAssertTrue(
            hasSafeUnwrap,
            "MultiToolExample should safely unwrap optional data.usage with 'if let' or 'guard let'"
        )
    }

    // MARK: - AC7: Clear Comments and No Exposed Keys

    func testMultiToolExampleHasTopLevelDescriptionComment() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "MultiToolExample should start with a descriptive comment block"
        )
    }

    func testMultiToolExampleHasMultipleInlineComments() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 3,
            "MultiToolExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testMultiToolExampleDoesNotExposeRealAPIKeys() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
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
                        "MultiToolExample should not contain a real-looking API key"
                    )
                }
            }
        }
    }

    func testMultiToolExampleUsesPlaceholderOrEnvVarForAPIKey() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        if content.contains("apiKey:") {
            let usesPlaceholder = content.contains("sk-...") || content.contains("sk-xxx")
            let usesEnvVar = content.contains("ProcessInfo.processInfo.environment") ||
                content.contains("ANTHROPIC_API_KEY") ||
                content.contains("CODEANY_API_KEY")
            XCTAssertTrue(
                usesPlaceholder || usesEnvVar,
                "MultiToolExample should use 'sk-...' placeholder or environment variable for apiKey"
            )
        }
    }

    func testMultiToolExampleDoesNotUseForceUnwrap() throws {
        let content = try DocumentationTestHelpers.requireFileContent(multiToolExamplePath())
        // Check for try! and force unwrap patterns (but allow string interpolation with !)
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            // Check for try!
            XCTAssertFalse(
                trimmed.contains("try!"),
                "MultiToolExample should not use 'try!' force-try"
            )
        }
    }
}

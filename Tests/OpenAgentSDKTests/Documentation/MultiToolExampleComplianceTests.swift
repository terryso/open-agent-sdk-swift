import XCTest
import Foundation

// MARK: - ATDD Tests for Story 10-1: MultiToolExample (Multi-Tool Orchestration Example)
// TDD RED PHASE: These tests will FAIL until Examples/MultiToolExample/ is created
// and Package.swift is updated with the MultiToolExample executableTarget.

final class MultiToolExampleComplianceTests: XCTestCase {

    // MARK: - Helper: Resolve project root

    /// Walk upward from the test bundle to find the directory containing Package.swift.
    private func projectRoot() -> String {
        let fileManager = FileManager.default
        var dir = fileManager.currentDirectoryPath
        for _ in 0..<10 {
            let packagePath = dir + "/Package.swift"
            if fileManager.fileExists(atPath: packagePath) {
                return dir
            }
            dir = dir + "/.."
        }
        return fileManager.currentDirectoryPath
    }

    private func examplesDir() -> String {
        return projectRoot() + "/Examples"
    }

    private func multiToolExamplePath() -> String {
        return examplesDir() + "/MultiToolExample/main.swift"
    }

    private func fileContent(_ path: String) -> String? {
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    private func packageSwiftContent() -> String {
        let path = projectRoot() + "/Package.swift"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            XCTFail("Package.swift should be readable")
            return ""
        }
        return content
    }

    // MARK: - AC5: Package.swift executableTarget Configured

    func testPackageSwiftContainsMultiToolExampleTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("MultiToolExample"),
            "Package.swift should contain MultiToolExample executable target"
        )
    }

    func testMultiToolExampleTargetDependsOnOpenAgentSDK() {
        let content = packageSwiftContent()
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
        let content = packageSwiftContent()
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
            atPath: examplesDir() + "/MultiToolExample",
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

    func testMultiToolExampleImportsOpenAgentSDK() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "MultiToolExample should import OpenAgentSDK"
        )
    }

    func testMultiToolExampleImportsFoundation() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import Foundation"),
            "MultiToolExample should import Foundation for ProcessInfo"
        )
    }

    func testMultiToolExampleUsesCreateAgent() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent("),
            "MultiToolExample should use createAgent() factory function"
        )
    }

    func testMultiToolExampleRegistersCoreTools() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("getAllBaseTools(tier: .core)"),
            "MultiToolExample should register all core tools via getAllBaseTools(tier: .core)"
        )
    }

    func testMultiToolExampleUsesBypassPermissions() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".bypassPermissions"),
            "MultiToolExample should set permissionMode to .bypassPermissions"
        )
    }

    // MARK: - AC2: Uses Streaming API for Real-Time Events

    func testMultiToolExampleUsesStreamingAPI() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("for await") && content.contains("agent.stream("),
            "MultiToolExample should use 'for await ... in agent.stream(...)' pattern"
        )
    }

    func testMultiToolExampleHandlesPartialMessage() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".partialMessage"),
            "MultiToolExample should handle .partialMessage case for incremental text"
        )
    }

    func testMultiToolExampleHandlesToolUseEvent() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".toolUse"),
            "MultiToolExample should handle .toolUse case to display tool invocations"
        )
    }

    func testMultiToolExampleHandlesToolResultEvent() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".toolResult"),
            "MultiToolExample should handle .toolResult case to display tool results"
        )
    }

    // MARK: - AC3: Demonstrates Multi-Tool Orchestration

    func testMultiToolExampleHasMultiStepSystemPrompt() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
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

    func testMultiToolExampleDisplaysToolNameAndInput() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        // Should display tool name and input from ToolUseData
        let hasToolName = content.contains("toolName") || content.contains("data.toolName")
        XCTAssertTrue(
            hasToolName,
            "MultiToolExample should display tool name from .toolUse event data"
        )
    }

    // MARK: - AC4: Final Output Includes Task Summary and Statistics

    func testMultiToolExampleHandlesResultEvent() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".result("),
            "MultiToolExample should handle .result case for final statistics"
        )
    }

    func testMultiToolExampleDisplaysUsageStatistics() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
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

    func testMultiToolExampleSafelyUnwrapsOptionalUsage() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        // data.usage is Optional<TokenUsage> so should use if let or guard let
        let hasSafeUnwrap = content.contains("if let usage") || content.contains("guard let usage")
        XCTAssertTrue(
            hasSafeUnwrap,
            "MultiToolExample should safely unwrap optional data.usage with 'if let' or 'guard let'"
        )
    }

    // MARK: - AC7: Clear Comments and No Exposed Keys

    func testMultiToolExampleHasTopLevelDescriptionComment() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "MultiToolExample should start with a descriptive comment block"
        )
    }

    func testMultiToolExampleHasMultipleInlineComments() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 3,
            "MultiToolExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testMultiToolExampleDoesNotExposeRealAPIKeys() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
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

    func testMultiToolExampleUsesPlaceholderOrEnvVarForAPIKey() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
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

    func testMultiToolExampleDoesNotUseForceUnwrap() {
        guard let content = fileContent(multiToolExamplePath()) else {
            XCTFail("Examples/MultiToolExample/main.swift should be readable")
            return
        }
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

import XCTest
import Foundation

// MARK: - ATDD Tests for Story 10-2: CustomSystemPromptExample
// TDD RED PHASE: These tests will FAIL until Examples/CustomSystemPromptExample/ is created
// and Package.swift is updated with the CustomSystemPromptExample executableTarget.

final class CustomSystemPromptExampleComplianceTests: XCTestCase {

    // MARK: - Helpers

    private func examplePath() -> String {
        return DocumentationTestHelpers.examplesDir() + "/CustomSystemPromptExample/main.swift"
    }

    // MARK: - AC5: Package.swift executableTarget Configured

    func testPackageSwiftContainsCustomSystemPromptExampleTarget() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("CustomSystemPromptExample"),
            "Package.swift should contain CustomSystemPromptExample executable target"
        )
    }

    func testCustomSystemPromptExampleTargetDependsOnOpenAgentSDK() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("CustomSystemPromptExample"),
            "Package.swift should contain CustomSystemPromptExample target before checking dependencies"
        )
        let targetRange = content.range(of: "CustomSystemPromptExample")
        XCTAssertNotNil(targetRange, "Should find CustomSystemPromptExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "CustomSystemPromptExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testCustomSystemPromptExampleTargetSpecifiesCorrectPath() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("CustomSystemPromptExample"),
            "Package.swift should contain CustomSystemPromptExample target before checking path"
        )
        let targetRange = content.range(of: "CustomSystemPromptExample")
        XCTAssertNotNil(targetRange, "Should find CustomSystemPromptExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/CustomSystemPromptExample"),
                    "CustomSystemPromptExample target should specify path: 'Examples/CustomSystemPromptExample'"
                )
            }
        }
    }

    // MARK: - AC1: CustomSystemPromptExample Directory and File Exist

    func testCustomSystemPromptExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: DocumentationTestHelpers.examplesDir() + "/CustomSystemPromptExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/CustomSystemPromptExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/CustomSystemPromptExample/ should be a directory")
    }

    func testCustomSystemPromptExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/CustomSystemPromptExample/main.swift should exist"
        )
    }

    func testCustomSystemPromptExampleImportsOpenAgentSDK() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "CustomSystemPromptExample should import OpenAgentSDK"
        )
    }

    func testCustomSystemPromptExampleImportsFoundation() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import Foundation"),
            "CustomSystemPromptExample should import Foundation for ProcessInfo"
        )
    }

    func testCustomSystemPromptExampleUsesCreateAgent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("createAgent("),
            "CustomSystemPromptExample should use createAgent() factory function"
        )
    }

    func testCustomSystemPromptExampleUsesBypassPermissions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".bypassPermissions"),
            "CustomSystemPromptExample should set permissionMode to .bypassPermissions"
        )
    }

    // MARK: - AC2: Uses Blocking API (agent.prompt())

    func testCustomSystemPromptExampleUsesBlockingPromptAPI() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("agent.prompt("),
            "CustomSystemPromptExample should use agent.prompt() for blocking query (not streaming)"
        )
    }

    func testCustomSystemPromptExampleDoesNotUseStreamingAPI() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // This example is specifically about blocking API; should NOT use stream()
        let usesStreaming = content.contains("agent.stream(")
        XCTAssertFalse(
            usesStreaming,
            "CustomSystemPromptExample should NOT use agent.stream() — this example demonstrates blocking prompt API"
        )
    }

    // MARK: - AC3: Agent Reply Style Matches System Prompt

    func testCustomSystemPromptExampleDefinesSpecializedSystemPrompt() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("systemPrompt:"),
            "CustomSystemPromptExample should define a systemPrompt in AgentOptions"
        )
        // The system prompt should define a specialized role (e.g., code reviewer)
        // that guides reply style and format
        let hasSpecializedRole = content.contains("code review") ||
            content.contains("Code Review") ||
            content.contains("senior") ||
            content.contains("expert") ||
            content.contains("specialist") ||
            content.contains("professional")
        XCTAssertTrue(
            hasSpecializedRole,
            "CustomSystemPromptExample systemPrompt should define a specialized role (e.g., code review expert)"
        )
    }

    func testCustomSystemPromptExampleSystemPromptGuidesFormat() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // The system prompt should guide the response format
        let hasFormatGuidance = content.contains("format") ||
            content.contains("structure") ||
            content.contains("JSON") ||
            content.contains("markdown") ||
            content.contains("list") ||
            content.contains("bullet") ||
            content.contains("structured")
        XCTAssertTrue(
            hasFormatGuidance,
            "CustomSystemPromptExample systemPrompt should guide the reply format/structure"
        )
    }

    func testCustomSystemPromptExampleDoesNotRegisterTools() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // This example showcases pure conversation with system prompt, no tools
        let hasTools = content.contains("tools:") && !content.contains("tools: nil")
        XCTAssertFalse(
            hasTools,
            "CustomSystemPromptExample should NOT register tools — it demonstrates pure conversation with system prompt"
        )
    }

    // MARK: - AC4: Demonstrates Complete QueryResult Fields

    func testCustomSystemPromptExampleDisplaysResponseText() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let hasText = content.contains("result.text") || content.contains(".text")
        XCTAssertTrue(
            hasText,
            "CustomSystemPromptExample should display result.text (response text)"
        )
    }

    func testCustomSystemPromptExampleDisplaysStatus() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("result.status") || content.contains(".status"),
            "CustomSystemPromptExample should display result.status"
        )
    }

    func testCustomSystemPromptExampleDisplaysNumTurns() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("numTurns") || content.contains("result.numTurns"),
            "CustomSystemPromptExample should display result.numTurns"
        )
    }

    func testCustomSystemPromptExampleDisplaysDurationMs() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("durationMs") || content.contains("result.durationMs"),
            "CustomSystemPromptExample should display result.durationMs"
        )
    }

    func testCustomSystemPromptExampleDisplaysTokenUsage() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("inputTokens") || content.contains("usage.inputTokens"),
            "CustomSystemPromptExample should display result.usage.inputTokens"
        )
        XCTAssertTrue(
            content.contains("outputTokens") || content.contains("usage.outputTokens"),
            "CustomSystemPromptExample should display result.usage.outputTokens"
        )
    }

    func testCustomSystemPromptExampleDisplaysCost() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("totalCostUsd") || content.contains("result.totalCostUsd"),
            "CustomSystemPromptExample should display result.totalCostUsd"
        )
    }

    // MARK: - AC6: Uses Actual Public API

    func testCustomSystemPromptExampleAgentOptionsUsesRealParameterNames() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        if content.contains("AgentOptions(") {
            let validParams = [
                "apiKey:", "model:", "systemPrompt:", "maxTurns:",
                "permissionMode:"
            ]
            var foundParams = 0
            for param in validParams {
                if content.contains(param) {
                    foundParams += 1
                }
            }
            XCTAssertGreaterThanOrEqual(
                foundParams, 3,
                "CustomSystemPromptExample AgentOptions should use at least 3 real parameter names"
            )
        }
    }

    func testCustomSystemPromptExampleQueryResultMatchesSourceType() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // QueryResult properties should match source: text, usage, numTurns, durationMs, status, totalCostUsd
        let requiredProperties = ["text", "numTurns", "durationMs", "totalCostUsd"]
        for prop in requiredProperties {
            XCTAssertTrue(
                content.contains(prop),
                "CustomSystemPromptExample should access QueryResult property '\(prop)' matching source type"
            )
        }
    }

    func testCustomSystemPromptExampleUsesAwaitForPrompt() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("await agent.prompt("),
            "CustomSystemPromptExample should use 'await agent.prompt()' — the blocking async API"
        )
    }

    // MARK: - AC7: Clear Comments and No Exposed Keys

    func testCustomSystemPromptExampleHasTopLevelDescriptionComment() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "CustomSystemPromptExample should start with a descriptive comment block"
        )
    }

    func testCustomSystemPromptExampleHasMultipleInlineComments() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 3,
            "CustomSystemPromptExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testCustomSystemPromptExampleDoesNotExposeRealAPIKeys() throws {
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
                        "CustomSystemPromptExample should not contain a real-looking API key"
                    )
                }
            }
        }
    }

    func testCustomSystemPromptExampleUsesPlaceholderOrEnvVarForAPIKey() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        if content.contains("apiKey:") {
            let usesPlaceholder = content.contains("sk-...") || content.contains("sk-xxx")
            let usesEnvVar = content.contains("ProcessInfo.processInfo.environment") ||
                content.contains("ANTHROPIC_API_KEY")
            XCTAssertTrue(
                usesPlaceholder || usesEnvVar,
                "CustomSystemPromptExample should use 'sk-...' placeholder or environment variable for apiKey"
            )
        }
    }

    func testCustomSystemPromptExampleDoesNotUseForceUnwrap() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            // Check for try!
            XCTAssertFalse(
                trimmed.contains("try!"),
                "CustomSystemPromptExample should not use 'try!' force-try"
            )
        }
    }
}

import XCTest
import Foundation

// MARK: - ATDD Tests for Story 10-3: PromptAPIExample (Blocking Prompt API Example)
// TDD RED PHASE: These tests will FAIL until Examples/PromptAPIExample/ is created
// and Package.swift is updated with the PromptAPIExample executableTarget.

final class PromptAPIExampleComplianceTests: XCTestCase {

    // MARK: - Helper: Resolve project root

    /// Walk upward from this test file to find the directory containing Package.swift.
    private func projectRoot() -> String {
        let fileManager = FileManager.default
        let testFileDir = URL(fileURLWithPath: #file).deletingLastPathComponent().path
        var dir = testFileDir
        for _ in 0..<10 {
            let packagePath = dir + "/Package.swift"
            if fileManager.fileExists(atPath: packagePath) {
                return dir
            }
            let parent = URL(fileURLWithPath: dir).deletingLastPathComponent().path
            if parent == dir { break }
            dir = parent
        }
        return testFileDir
    }

    private func examplesDir() -> String {
        return projectRoot() + "/Examples"
    }

    private func examplePath() -> String {
        return examplesDir() + "/PromptAPIExample/main.swift"
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

    func testPackageSwiftContainsPromptAPIExampleTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("PromptAPIExample"),
            "Package.swift should contain PromptAPIExample executable target"
        )
    }

    func testPromptAPIExampleTargetDependsOnOpenAgentSDK() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("PromptAPIExample"),
            "Package.swift should contain PromptAPIExample target before checking dependencies"
        )
        let targetRange = content.range(of: "PromptAPIExample")
        XCTAssertNotNil(targetRange, "Should find PromptAPIExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "PromptAPIExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testPromptAPIExampleTargetSpecifiesCorrectPath() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("PromptAPIExample"),
            "Package.swift should contain PromptAPIExample target before checking path"
        )
        let targetRange = content.range(of: "PromptAPIExample")
        XCTAssertNotNil(targetRange, "Should find PromptAPIExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/PromptAPIExample"),
                    "PromptAPIExample target should specify path: 'Examples/PromptAPIExample'"
                )
            }
        }
    }

    // MARK: - AC1: PromptAPIExample Directory and File Exist

    func testPromptAPIExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: examplesDir() + "/PromptAPIExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/PromptAPIExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/PromptAPIExample/ should be a directory")
    }

    func testPromptAPIExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/PromptAPIExample/main.swift should exist"
        )
    }

    func testPromptAPIExampleImportsOpenAgentSDK() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "PromptAPIExample should import OpenAgentSDK"
        )
    }

    func testPromptAPIExampleImportsFoundation() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import Foundation"),
            "PromptAPIExample should import Foundation for ProcessInfo"
        )
    }

    func testPromptAPIExampleUsesCreateAgent() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent("),
            "PromptAPIExample should use createAgent() factory function"
        )
    }

    func testPromptAPIExampleUsesBypassPermissions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".bypassPermissions"),
            "PromptAPIExample should set permissionMode to .bypassPermissions"
        )
    }

    // MARK: - AC2: Uses Blocking agent.prompt() API

    func testPromptAPIExampleUsesBlockingPromptAPI() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("agent.prompt("),
            "PromptAPIExample should use agent.prompt() for blocking query (not streaming)"
        )
    }

    func testPromptAPIExampleDoesNotUseStreamingAPI() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        // This example is specifically about blocking API; should NOT use stream()
        let usesStreaming = content.contains("agent.stream(")
        XCTAssertFalse(
            usesStreaming,
            "PromptAPIExample should NOT use agent.stream() — this example demonstrates blocking prompt API"
        )
    }

    // MARK: - AC3: Displays Complete QueryResult Fields

    func testPromptAPIExampleDisplaysResponseText() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("result.text"),
            "PromptAPIExample should display result.text (response text)"
        )
    }

    func testPromptAPIExampleDisplaysStatus() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("result.status"),
            "PromptAPIExample should display result.status (QueryStatus enum)"
        )
    }

    func testPromptAPIExampleDisplaysNumTurns() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("numTurns"),
            "PromptAPIExample should display result.numTurns"
        )
    }

    func testPromptAPIExampleDisplaysDurationMs() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("durationMs"),
            "PromptAPIExample should display result.durationMs"
        )
    }

    func testPromptAPIExampleDisplaysTokenUsage() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("inputTokens"),
            "PromptAPIExample should display result.usage.inputTokens"
        )
        XCTAssertTrue(
            content.contains("outputTokens"),
            "PromptAPIExample should display result.usage.outputTokens"
        )
    }

    func testPromptAPIExampleDisplaysCost() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("totalCostUsd"),
            "PromptAPIExample should display result.totalCostUsd"
        )
    }

    // MARK: - AC4: Registers Core Tools for Agent Tool Execution

    func testPromptAPIExampleRegistersCoreTools() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("getAllBaseTools(tier: .core)"),
            "PromptAPIExample should register all core tools via getAllBaseTools(tier: .core)"
        )
    }

    func testPromptAPIExamplePassesToolsToAgentOptions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        // Verify tools parameter is passed in AgentOptions (not defaulting to nil)
        let hasToolsParam = content.contains("tools:")
        XCTAssertTrue(
            hasToolsParam,
            "PromptAPIExample should pass tools: parameter in AgentOptions"
        )
    }

    func testPromptAPIExampleDefinesSystemPrompt() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("systemPrompt:"),
            "PromptAPIExample should define a systemPrompt in AgentOptions"
        )
    }

    // MARK: - AC6: Uses Actual Public API Signatures

    func testPromptAPIExampleAgentOptionsUsesRealParameterNames() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        if content.contains("AgentOptions(") {
            let validParams = [
                "apiKey:", "model:", "systemPrompt:", "maxTurns:",
                "permissionMode:", "tools:"
            ]
            var foundParams = 0
            for param in validParams {
                if content.contains(param) {
                    foundParams += 1
                }
            }
            XCTAssertGreaterThanOrEqual(
                foundParams, 4,
                "PromptAPIExample AgentOptions should use at least 4 real parameter names"
            )
        }
    }

    func testPromptAPIExampleQueryResultMatchesSourceType() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        // QueryResult properties should match source: text, usage, numTurns, durationMs, status, totalCostUsd
        let requiredProperties = ["text", "numTurns", "durationMs", "totalCostUsd"]
        for prop in requiredProperties {
            XCTAssertTrue(
                content.contains(prop),
                "PromptAPIExample should access QueryResult property '\(prop)' matching source type"
            )
        }
    }

    func testPromptAPIExampleUsesAwaitForPrompt() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("await agent.prompt("),
            "PromptAPIExample should use 'await agent.prompt()' — the blocking async API"
        )
    }

    func testPromptAPIExampleUsesCreateAgentWithOptions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent(options:") || content.contains("createAgent(options: "),
            "PromptAPIExample should use createAgent(options: AgentOptions(...))"
        )
    }

    // MARK: - AC7: Clear Comments and No Exposed Keys

    func testPromptAPIExampleHasTopLevelDescriptionComment() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "PromptAPIExample should start with a descriptive comment block"
        )
    }

    func testPromptAPIExampleHasMultipleInlineComments() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 3,
            "PromptAPIExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testPromptAPIExampleDoesNotExposeRealAPIKeys() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
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
                        "PromptAPIExample should not contain a real-looking API key"
                    )
                }
            }
        }
    }

    func testPromptAPIExampleUsesPlaceholderOrEnvVarForAPIKey() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        if content.contains("apiKey:") {
            let usesPlaceholder = content.contains("sk-...") || content.contains("sk-xxx")
            let usesEnvVar = content.contains("ProcessInfo.processInfo.environment") ||
                content.contains("ANTHROPIC_API_KEY")
            XCTAssertTrue(
                usesPlaceholder || usesEnvVar,
                "PromptAPIExample should use 'sk-...' placeholder or environment variable for apiKey"
            )
        }
    }

    func testPromptAPIExampleDoesNotUseForceUnwrap() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PromptAPIExample/main.swift should be readable")
            return
        }
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            // Check for try!
            XCTAssertFalse(
                trimmed.contains("try!"),
                "PromptAPIExample should not use 'try!' force-try"
            )
        }
    }
}

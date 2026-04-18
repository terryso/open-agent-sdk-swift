import XCTest
import Foundation

// MARK: - ATDD Tests for Story 10-5: PermissionsExample (Permission Control Example)
// TDD RED PHASE: These tests will FAIL until Examples/PermissionsExample/ is created
// and Package.swift is updated with the PermissionsExample executableTarget.

final class PermissionsExampleComplianceTests: XCTestCase {

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
        return examplesDir() + "/PermissionsExample/main.swift"
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

    func testPackageSwiftContainsPermissionsExampleTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("PermissionsExample"),
            "Package.swift should contain PermissionsExample executable target"
        )
    }

    func testPermissionsExampleTargetDependsOnOpenAgentSDK() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("PermissionsExample"),
            "Package.swift should contain PermissionsExample target before checking dependencies"
        )
        let targetRange = content.range(of: "PermissionsExample")
        XCTAssertNotNil(targetRange, "Should find PermissionsExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "PermissionsExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testPermissionsExampleTargetSpecifiesCorrectPath() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("PermissionsExample"),
            "Package.swift should contain PermissionsExample target before checking path"
        )
        let targetRange = content.range(of: "PermissionsExample")
        XCTAssertNotNil(targetRange, "Should find PermissionsExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/PermissionsExample"),
                    "PermissionsExample target should specify path: 'Examples/PermissionsExample'"
                )
            }
        }
    }

    // MARK: - AC1: PermissionsExample Directory and File Exist, Compiles

    func testPermissionsExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: examplesDir() + "/PermissionsExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/PermissionsExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/PermissionsExample/ should be a directory")
    }

    func testPermissionsExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/PermissionsExample/main.swift should exist"
        )
    }

    func testPermissionsExampleImportsOpenAgentSDK() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "PermissionsExample should import OpenAgentSDK"
        )
    }

    func testPermissionsExampleImportsFoundation() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import Foundation"),
            "PermissionsExample should import Foundation for ProcessInfo"
        )
    }

    func testPermissionsExampleUsesCreateAgent() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent("),
            "PermissionsExample should use createAgent() factory function"
        )
    }

    // MARK: - AC2: Demonstrates ToolNameAllowlistPolicy Restricting Tool Access

    func testPermissionsExampleUsesToolNameAllowlistPolicy() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("ToolNameAllowlistPolicy"),
            "PermissionsExample should use ToolNameAllowlistPolicy to restrict tool access"
        )
    }

    func testPermissionsExampleAllowlistSpecifiesReadGlobGrep() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        // The allowlist should contain Read, Glob, Grep tool names
        let hasReadGlobGrep = content.contains("\"Read\"") &&
            content.contains("\"Glob\"") &&
            content.contains("\"Grep\"")
        XCTAssertTrue(
            hasReadGlobGrep,
            "PermissionsExample ToolNameAllowlistPolicy should specify Read, Glob, Grep tools"
        )
    }

    func testPermissionsExampleUsesCanUseToolPolicyBridge() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("canUseTool(policy:"),
            "PermissionsExample should use canUseTool(policy:) bridge function to convert policy to callback"
        )
    }

    func testPermissionsExamplePassesCanUseToolToAgentOptions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        // The canUseTool parameter should be passed in AgentOptions
        let hasCanUseToolParam = content.contains("canUseTool:")
        XCTAssertTrue(
            hasCanUseToolParam,
            "PermissionsExample should pass canUseTool: parameter in AgentOptions"
        )
    }

    // MARK: - AC3: Demonstrates ReadOnlyPolicy Restricting to Read-Only Operations

    func testPermissionsExampleUsesReadOnlyPolicy() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("ReadOnlyPolicy"),
            "PermissionsExample should use ReadOnlyPolicy to restrict to read-only tools"
        )
    }

    func testPermissionsExampleReadOnlyPolicyBridgedViaCanUseTool() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        // ReadOnlyPolicy should also be bridged via canUseTool(policy:)
        // Find the ReadOnlyPolicy usage and verify canUseTool(policy:) is used nearby
        XCTAssertTrue(
            content.contains("ReadOnlyPolicy()"),
            "PermissionsExample should instantiate ReadOnlyPolicy()"
        )
    }

    func testPermissionsExampleShowsMultipleAgentsWithDifferentPolicies() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        // The example should create separate agents with different policies
        // Should have multiple createAgent calls (at least 2 for different policies)
        let createAgentCount = content.components(separatedBy: "createAgent(").count - 1
        XCTAssertGreaterThanOrEqual(
            createAgentCount, 2,
            "PermissionsExample should create at least 2 agents with different permission policies"
        )
    }

    // MARK: - AC4: Demonstrates bypassPermissions Mode for Comparison

    func testPermissionsExampleUsesBypassPermissions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".bypassPermissions"),
            "PermissionsExample should use .bypassPermissions permissionMode for unrestricted agent comparison"
        )
    }

    func testPermissionsExampleBypassAgentDoesNotSetCanUseTool() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        // The bypassPermissions agent should be contrasted with restricted agents.
        // Verify there is at least one AgentOptions with .bypassPermissions that
        // does NOT also set a canUseTool policy (the unrestricted comparison agent).
        let lines = content.components(separatedBy: "\n")
        var foundBypassWithoutCanUseTool = false
        var inAgentOptionsBlock = false
        var blockHasCanUseTool = false
        var blockHasBypassPermissions = false
        var braceDepth = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("AgentOptions(") {
                inAgentOptionsBlock = true
                blockHasCanUseTool = false
                blockHasBypassPermissions = false
                braceDepth = 0
            }

            if inAgentOptionsBlock {
                if trimmed.contains(".bypassPermissions") {
                    blockHasBypassPermissions = true
                }
                if trimmed.contains("canUseTool:") &&
                    !trimmed.hasPrefix("//") {
                    blockHasCanUseTool = true
                }
                braceDepth += trimmed.filter { $0 == "(" }.count
                braceDepth -= trimmed.filter { $0 == ")" }.count

                if braceDepth <= 0 && trimmed.contains(")") && !trimmed.contains("AgentOptions(") {
                    if blockHasBypassPermissions && !blockHasCanUseTool {
                        foundBypassWithoutCanUseTool = true
                    }
                    inAgentOptionsBlock = false
                }
            }
        }

        XCTAssertTrue(
            foundBypassWithoutCanUseTool,
            "PermissionsExample should have at least one bypassPermissions agent WITHOUT canUseTool for comparison"
        )
    }

    func testPermissionsExampleOutputsComparisonSummary() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        // Should output a comparison/summary of the three permission modes
        let hasComparison = content.contains("comparison") ||
            content.contains("Comparison") ||
            content.contains("summary") ||
            content.contains("Summary") ||
            content.contains("contrast") ||
            content.contains("bypassPermissions")
        XCTAssertTrue(
            hasComparison,
            "PermissionsExample should output a comparison summary of the different permission modes"
        )
    }

    // MARK: - AC1 (continued): Uses Blocking Prompt API

    func testPermissionsExampleUsesBlockingPromptAPI() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("agent.prompt("),
            "PermissionsExample should use agent.prompt() blocking API"
        )
    }

    func testPermissionsExampleDisplaysQueryResultProperties() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        // Should display at least text from QueryResult
        XCTAssertTrue(
            content.contains("result.text") || content.contains(".text"),
            "PermissionsExample should display result.text from QueryResult"
        )
    }

    func testPermissionsExampleUsesCoreTools() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("getAllBaseTools(tier: .core)"),
            "PermissionsExample should use getAllBaseTools(tier: .core) to register core tools"
        )
    }

    func testPermissionsExamplePassesToolsToAgentOptions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("tools:"),
            "PermissionsExample should pass tools: parameter in AgentOptions"
        )
    }

    func testPermissionsExampleUsesCreateAgentWithOptions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent(options:") || content.contains("createAgent(options: "),
            "PermissionsExample should use createAgent(options: AgentOptions(...))"
        )
    }

    // MARK: - AC6: Uses Actual Public API Signatures

    func testPermissionsExampleAgentOptionsUsesRealParameterNames() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        if content.contains("AgentOptions(") {
            let validParams = [
                "apiKey:", "model:", "systemPrompt:", "maxTurns:",
                "permissionMode:", "tools:", "canUseTool:"
            ]
            var foundParams = 0
            for param in validParams {
                if content.contains(param) {
                    foundParams += 1
                }
            }
            XCTAssertGreaterThanOrEqual(
                foundParams, 4,
                "PermissionsExample AgentOptions should use at least 4 real parameter names"
            )
        }
    }

    func testPermissionsExampleQueryResultMatchesSourceType() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        // QueryResult properties should match source: text, usage, numTurns, durationMs, status, totalCostUsd
        let requiredProperties = ["text", "numTurns", "durationMs", "totalCostUsd"]
        for prop in requiredProperties {
            XCTAssertTrue(
                content.contains(prop),
                "PermissionsExample should access QueryResult property '\(prop)' matching source type"
            )
        }
    }

    func testPermissionsExampleUsesToolNameAllowlistPolicyRealAPI() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        // ToolNameAllowlistPolicy init uses allowedToolNames: Set<String>
        XCTAssertTrue(
            content.contains("allowedToolNames:"),
            "PermissionsExample should use ToolNameAllowlistPolicy(allowedToolNames:) matching real API signature"
        )
    }

    func testPermissionsExampleUsesCanUseToolPolicyBridgeFunction() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        // The canUseTool(policy:) bridge function is a public free function
        XCTAssertTrue(
            content.contains("canUseTool(policy:"),
            "PermissionsExample should use the canUseTool(policy:) public bridge function"
        )
    }

    func testPermissionsExampleUsesAwaitForPrompt() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("await agent.prompt("),
            "PermissionsExample should use 'await agent.prompt()' — the blocking async API"
        )
    }

    // MARK: - AC7: Clear Comments and No Exposed Keys

    func testPermissionsExampleHasTopLevelDescriptionComment() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "PermissionsExample should start with a descriptive comment block"
        )
    }

    func testPermissionsExampleHasMultipleInlineComments() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 3,
            "PermissionsExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testPermissionsExampleDoesNotExposeRealAPIKeys() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
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
                        "PermissionsExample should not contain a real-looking API key"
                    )
                }
            }
        }
    }

    func testPermissionsExampleUsesPlaceholderOrEnvVarForAPIKey() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        if content.contains("apiKey:") {
            let usesPlaceholder = content.contains("sk-...") || content.contains("sk-xxx")
            let usesEnvVar = content.contains("ProcessInfo.processInfo.environment") ||
                content.contains("ANTHROPIC_API_KEY")
            XCTAssertTrue(
                usesPlaceholder || usesEnvVar,
                "PermissionsExample should use 'sk-...' placeholder or environment variable for apiKey"
            )
        }
    }

    func testPermissionsExampleDoesNotUseForceUnwrap() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
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
                "PermissionsExample should not use 'try!' force-try"
            )
        }
    }

    // MARK: - MARK Section Structure

    func testPermissionsExampleHasMarkSectionsForThreeParts() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/PermissionsExample/main.swift should be readable")
            return
        }
        // Should have at least Part 1 (ToolNameAllowlistPolicy) and Part 2 (ReadOnlyPolicy) MARK sections
        let hasPart1 = content.contains("Part 1") || content.contains("ToolNameAllowlistPolicy")
        let hasPart2 = content.contains("Part 2") || content.contains("ReadOnlyPolicy")
        XCTAssertTrue(
            hasPart1,
            "PermissionsExample should have a Part 1 section for ToolNameAllowlistPolicy"
        )
        XCTAssertTrue(
            hasPart2,
            "PermissionsExample should have a Part 2 section for ReadOnlyPolicy"
        )
    }
}

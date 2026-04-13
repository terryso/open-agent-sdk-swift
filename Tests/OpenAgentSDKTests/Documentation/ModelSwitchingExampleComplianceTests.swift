import XCTest
import Foundation

// MARK: - ATDD Tests for Story 15-4: ModelSwitchingExample
// ATDD Compliance Tests: Verify ModelSwitchingExample satisfies all acceptance criteria.
// These tests validate file structure, code patterns, and API usage in the example.

final class ModelSwitchingExampleComplianceTests: XCTestCase {

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

    private func examplePath() -> String {
        return examplesDir() + "/ModelSwitchingExample/main.swift"
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

    // MARK: - AC6: Package.swift executableTarget Configured

    func testPackageSwiftContainsModelSwitchingExampleTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("ModelSwitchingExample"),
            "Package.swift should contain ModelSwitchingExample executable target"
        )
    }

    func testModelSwitchingExampleTargetDependsOnOpenAgentSDK() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("ModelSwitchingExample"),
            "Package.swift should contain ModelSwitchingExample target before checking dependencies"
        )
        let targetRange = content.range(of: "ModelSwitchingExample")
        XCTAssertNotNil(targetRange, "Should find ModelSwitchingExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "ModelSwitchingExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testModelSwitchingExampleTargetSpecifiesCorrectPath() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("ModelSwitchingExample"),
            "Package.swift should contain ModelSwitchingExample target before checking path"
        )
        let targetRange = content.range(of: "ModelSwitchingExample")
        XCTAssertNotNil(targetRange, "Should find ModelSwitchingExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/ModelSwitchingExample"),
                    "ModelSwitchingExample target should specify path: 'Examples/ModelSwitchingExample'"
                )
            }
        }
    }

    // MARK: - AC1: ModelSwitchingExample Directory and File Existence

    func testModelSwitchingExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: examplesDir() + "/ModelSwitchingExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/ModelSwitchingExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/ModelSwitchingExample/ should be a directory")
    }

    func testModelSwitchingExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/ModelSwitchingExample/main.swift should exist"
        )
    }

    func testModelSwitchingExampleImportsOpenAgentSDK() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "ModelSwitchingExample should import OpenAgentSDK"
        )
    }

    func testModelSwitchingExampleImportsFoundation() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import Foundation"),
            "ModelSwitchingExample should import Foundation"
        )
    }

    // MARK: - AC1: Code Quality

    func testModelSwitchingExampleHasTopLevelDescriptionComment() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "ModelSwitchingExample should start with a descriptive comment block"
        )
    }

    func testModelSwitchingExampleHasMultipleInlineComments() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 5,
            "ModelSwitchingExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testModelSwitchingExampleHasMarkSections() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        let markCount = content.components(separatedBy: "MARK:").count - 1
        XCTAssertGreaterThanOrEqual(
            markCount, 2,
            "ModelSwitchingExample should have at least 2 MARK sections (Part 1, Part 2)"
        )
    }

    func testModelSwitchingExampleDoesNotUseForceUnwrap() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            XCTAssertFalse(
                trimmed.contains("try!"),
                "ModelSwitchingExample should not use 'try!' force-try"
            )
        }
    }

    func testModelSwitchingExampleDoesNotExposeRealAPIKeys() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertFalse(
            content.contains("sk-ant-api03") || content.contains("sk-proj-"),
            "ModelSwitchingExample should not contain real API keys"
        )
    }

    func testModelSwitchingExampleUsesLoadDotEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("loadDotEnv()"),
            "ModelSwitchingExample should use loadDotEnv() helper pattern"
        )
    }

    func testModelSwitchingExampleUsesGetEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("getEnv("),
            "ModelSwitchingExample should use getEnv() helper pattern for API key loading"
        )
    }

    // MARK: - AC2: Default Model Query

    func testModelSwitchingExampleCreatesAgentWithDefaultModel() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent("),
            "ModelSwitchingExample should create an Agent using createAgent()"
        )
    }

    func testModelSwitchingExampleReferencesClaudeSonnet() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("claude-sonnet-4-6") || content.contains("sonnet"),
            "ModelSwitchingExample should reference claude-sonnet-4-6 as the default model"
        )
    }

    func testModelSwitchingExampleUsesPromptAPI() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("agent.prompt(") || content.contains(".prompt("),
            "ModelSwitchingExample should use agent.prompt() to execute queries"
        )
    }

    func testModelSwitchingExampleExecutesFirstQuery() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        // Should contain "await" for the async prompt call and capture the result
        XCTAssertTrue(
            content.contains("await"),
            "ModelSwitchingExample should use await for async prompt calls"
        )
        // Should have a result variable to store query output
        XCTAssertTrue(
            content.contains("result") || content.contains("Result"),
            "ModelSwitchingExample should capture query result"
        )
    }

    func testModelSwitchingExampleUsesBypassPermissions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("bypassPermissions") || content.contains(".bypassPermissions"),
            "ModelSwitchingExample should use permissionMode: .bypassPermissions"
        )
    }

    // MARK: - AC3: Model Switching

    func testModelSwitchingExampleCallsSwitchModel() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("switchModel("),
            "ModelSwitchingExample should call agent.switchModel() to change model"
        )
    }

    func testModelSwitchingExampleSwitchesToOpus() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("claude-opus-4-6") || content.contains("opus"),
            "ModelSwitchingExample should switch to claude-opus-4-6 model"
        )
    }

    func testModelSwitchingExampleExecutesSecondQuery() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        // Count prompt calls -- should have at least 2 queries (before and after switch)
        let promptCount = content.components(separatedBy: ".prompt(").count - 1
        XCTAssertGreaterThanOrEqual(
            promptCount, 2,
            "ModelSwitchingExample should execute at least 2 queries (one before switch, one after)"
        )
    }

    func testModelSwitchingExampleVerifiesModelAfterSwitch() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        // Should inspect agent.model after switching to verify the change
        XCTAssertTrue(
            content.contains("agent.model"),
            "ModelSwitchingExample should inspect agent.model to verify the switch"
        )
    }

    // MARK: - AC4: Cost Breakdown

    func testModelSwitchingExampleReferencesCostBreakdown() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("costBreakdown"),
            "ModelSwitchingExample should reference costBreakdown on QueryResult"
        )
    }

    func testModelSwitchingExampleDemonstratesPerModelCostEntries() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        // Should iterate over costBreakdown entries and display per-model info
        let hasIteration = content.contains("for ") && content.contains("costBreakdown")
        XCTAssertTrue(
            hasIteration || content.contains("CostBreakdownEntry"),
            "ModelSwitchingExample should iterate over costBreakdown entries or reference CostBreakdownEntry"
        )
    }

    func testModelSwitchingExampleDisplaysTokenCounts() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        // Should reference inputTokens and outputTokens from the cost breakdown or usage
        XCTAssertTrue(
            content.contains("inputTokens") && content.contains("outputTokens"),
            "ModelSwitchingExample should display inputTokens and outputTokens from cost entries"
        )
    }

    func testModelSwitchingExampleDisplaysCostUsd() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("costUsd") || content.contains("totalCostUsd"),
            "ModelSwitchingExample should display costUsd or totalCostUsd"
        )
    }

    func testModelSwitchingExamplePrintsUsageInfo() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        // Should print usage/token information after queries
        XCTAssertTrue(
            content.contains("usage") || content.contains("Tokens"),
            "ModelSwitchingExample should print token usage information"
        )
    }

    // MARK: - AC5: Error Handling for Empty Model

    func testModelSwitchingExampleDemonstratesEmptyModelError() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        // Should call switchModel("") or switchModel with empty string
        XCTAssertTrue(
            content.contains("switchModel(\"\")") || content.contains("switchModel( \"\""),
            "ModelSwitchingExample should demonstrate calling switchModel with empty string"
        )
    }

    func testModelSwitchingExampleUsesTryCatch() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("do {") || content.contains("do{"),
            "ModelSwitchingExample should use do/catch block for error handling"
        )
        XCTAssertTrue(
            content.contains("catch"),
            "ModelSwitchingExample should have catch clause"
        )
    }

    func testModelSwitchingExampleCatchesSDKError() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("SDKError"),
            "ModelSwitchingExample should catch SDKError.invalidConfiguration"
        )
    }

    func testModelSwitchingExampleCatchesInvalidConfiguration() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("invalidConfiguration"),
            "ModelSwitchingExample should catch SDKError.invalidConfiguration specifically"
        )
    }

    func testModelSwitchingExampleVerifiesModelUnchangedAfterError() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        // After the failed switchModel(""), should verify agent.model is unchanged
        // Look for agent.model reference after catch or in a verification step
        let modelRefCount = content.components(separatedBy: "agent.model").count - 1
        XCTAssertGreaterThanOrEqual(
            modelRefCount, 2,
            "ModelSwitchingExample should reference agent.model at least twice (once for confirmation after switch, once for verification after error)"
        )
    }

    // MARK: - AC1 / Build Verification: assert() usage for compliance testing

    func testModelSwitchingExampleUsesAssertions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/ModelSwitchingExample/main.swift should be readable")
            return
        }
        // The example should use assert() for key validations so compliance tests can verify behavior
        XCTAssertTrue(
            content.contains("assert("),
            "ModelSwitchingExample should use assert() for key validations"
        )
    }
}

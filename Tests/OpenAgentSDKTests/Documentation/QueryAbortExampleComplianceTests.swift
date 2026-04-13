import XCTest
import Foundation

// MARK: - ATDD Tests for Story 15-5: QueryAbortExample
// TDD RED PHASE: These tests will FAIL until Examples/QueryAbortExample/ is created
// and Package.swift is updated with the QueryAbortExample executableTarget.

final class QueryAbortExampleComplianceTests: XCTestCase {

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
        return examplesDir() + "/QueryAbortExample/main.swift"
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

    func testPackageSwiftContainsQueryAbortExampleTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("QueryAbortExample"),
            "Package.swift should contain QueryAbortExample executable target"
        )
    }

    func testQueryAbortExampleTargetDependsOnOpenAgentSDK() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("QueryAbortExample"),
            "Package.swift should contain QueryAbortExample target before checking dependencies"
        )
        let targetRange = content.range(of: "QueryAbortExample")
        XCTAssertNotNil(targetRange, "Should find QueryAbortExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "QueryAbortExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testQueryAbortExampleTargetSpecifiesCorrectPath() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("QueryAbortExample"),
            "Package.swift should contain QueryAbortExample target before checking path"
        )
        let targetRange = content.range(of: "QueryAbortExample")
        XCTAssertNotNil(targetRange, "Should find QueryAbortExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/QueryAbortExample"),
                    "QueryAbortExample target should specify path: 'Examples/QueryAbortExample'"
                )
            }
        }
    }

    // MARK: - AC1: QueryAbortExample Directory and File Existence

    func testQueryAbortExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: examplesDir() + "/QueryAbortExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/QueryAbortExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/QueryAbortExample/ should be a directory")
    }

    func testQueryAbortExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/QueryAbortExample/main.swift should exist"
        )
    }

    func testQueryAbortExampleImportsOpenAgentSDK() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "QueryAbortExample should import OpenAgentSDK"
        )
    }

    func testQueryAbortExampleImportsFoundation() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import Foundation"),
            "QueryAbortExample should import Foundation"
        )
    }

    // MARK: - AC1: Code Quality

    func testQueryAbortExampleHasTopLevelDescriptionComment() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "QueryAbortExample should start with a descriptive comment block"
        )
    }

    func testQueryAbortExampleHasMultipleInlineComments() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 5,
            "QueryAbortExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testQueryAbortExampleHasMarkSections() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        let markCount = content.components(separatedBy: "MARK:").count - 1
        XCTAssertGreaterThanOrEqual(
            markCount, 3,
            "QueryAbortExample should have at least 3 MARK sections (Part 1, Part 2, Part 3)"
        )
    }

    func testQueryAbortExampleDoesNotUseForceUnwrap() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            XCTAssertFalse(
                trimmed.contains("try!"),
                "QueryAbortExample should not use 'try!' force-try"
            )
        }
    }

    func testQueryAbortExampleDoesNotExposeRealAPIKeys() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertFalse(
            content.contains("sk-ant-api03") || content.contains("sk-proj-"),
            "QueryAbortExample should not contain real API keys"
        )
    }

    func testQueryAbortExampleUsesLoadDotEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("loadDotEnv()"),
            "QueryAbortExample should use loadDotEnv() helper pattern"
        )
    }

    func testQueryAbortExampleUsesGetEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("getEnv("),
            "QueryAbortExample should use getEnv() helper pattern for API key loading"
        )
    }

    func testQueryAbortExampleUsesBypassPermissions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("bypassPermissions") || content.contains(".bypassPermissions"),
            "QueryAbortExample should use permissionMode: .bypassPermissions"
        )
    }

    func testQueryAbortExampleUsesCreateAgent() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent("),
            "QueryAbortExample should create an Agent using createAgent()"
        )
    }

    // MARK: - AC2: Task.cancel() Cancellation

    func testQueryAbortExampleUsesTaskBlock() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        // Should use Task { } to wrap agent queries for cancellation
        let taskBlockCount = content.components(separatedBy: "Task {").count - 1
            + content.components(separatedBy: "Task{").count - 1
        XCTAssertGreaterThanOrEqual(
            taskBlockCount, 1,
            "QueryAbortExample should use Task { } block to wrap query for cancellation"
        )
    }

    func testQueryAbortExampleCallsTaskCancel() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".cancel()"),
            "QueryAbortExample should call task.cancel() to cancel the running query"
        )
    }

    func testQueryAbortExampleUsesTaskSleep() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        // Should use Task.sleep for delay before cancellation
        XCTAssertTrue(
            content.contains("Task.sleep") || content.contains("sleep(for:"),
            "QueryAbortExample should use Task.sleep(for:) for delay before cancellation"
        )
    }

    func testQueryAbortExampleChecksIsCancelled() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("isCancelled"),
            "QueryAbortExample should check result.isCancelled after cancellation"
        )
    }

    func testQueryAbortExampleUsesPromptAPI() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("agent.prompt(") || content.contains(".prompt("),
            "QueryAbortExample should use agent.prompt() to execute queries"
        )
    }

    func testQueryAbortExampleUsesAwait() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("await"),
            "QueryAbortExample should use await for async prompt calls"
        )
    }

    // MARK: - AC3: Agent.interrupt() Cancellation

    func testQueryAbortExampleCallsAgentInterrupt() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("agent.interrupt()") || content.contains(".interrupt()"),
            "QueryAbortExample should call agent.interrupt() to cancel the running query"
        )
    }

    func testQueryAbortExampleDemonstratesSecondCancellationMechanism() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        // Should demonstrate both Task.cancel() and agent.interrupt()
        let hasTaskCancel = content.contains(".cancel()")
        let hasInterrupt = content.contains("interrupt()")
        XCTAssertTrue(
            hasTaskCancel && hasInterrupt,
            "QueryAbortExample should demonstrate both Task.cancel() and Agent.interrupt() mechanisms"
        )
    }

    // MARK: - AC4: Partial Results Handling

    func testQueryAbortExampleInspectsPartialText() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        // Should inspect result.text for partial output
        XCTAssertTrue(
            content.contains("result.text") || content.contains(".text"),
            "QueryAbortExample should inspect result.text for partial output after cancellation"
        )
    }

    func testQueryAbortExampleInspectsNumTurns() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("numTurns"),
            "QueryAbortExample should inspect result.numTurns for completed turns after cancellation"
        )
    }

    func testQueryAbortExampleInspectsUsage() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        // Should reference usage for token counts after cancellation
        XCTAssertTrue(
            content.contains("usage") || content.contains("Tokens"),
            "QueryAbortExample should inspect result.usage for token usage after cancellation"
        )
    }

    // MARK: - AC5: Stream Cancellation

    func testQueryAbortExampleUsesStreamAPI() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("agent.stream(") || content.contains(".stream("),
            "QueryAbortExample should use agent.stream() API for streaming cancellation demo"
        )
    }

    func testQueryAbortExampleIteratesAsyncStream() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("for await"),
            "QueryAbortExample should iterate over AsyncStream with 'for await' pattern"
        )
    }

    func testQueryAbortExampleHandlesSDKMessageResult() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".result(") || content.contains("case .result"),
            "QueryAbortExample should handle .result case in SDKMessage stream events"
        )
    }

    func testQueryAbortExampleChecksCancelledSubtype() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".cancelled") || content.contains("cancelled"),
            "QueryAbortExample should check for .cancelled subtype in stream result events"
        )
    }

    func testQueryAbortExampleHasThreeParts() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        // Should have three distinct parts: Task.cancel(), Agent.interrupt(), Stream
        let partCount = content.components(separatedBy: "Part ").count - 1
            + content.components(separatedBy: "PART ").count - 1
        XCTAssertGreaterThanOrEqual(
            partCount, 3,
            "QueryAbortExample should have at least 3 parts (Task.cancel, Agent.interrupt, Stream)"
        )
    }

    // MARK: - AC1 / Build Verification: assert() usage for compliance testing

    func testQueryAbortExampleUsesAssertions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/QueryAbortExample/main.swift should be readable")
            return
        }
        // The example should use assert() for key validations so compliance tests can verify behavior
        XCTAssertTrue(
            content.contains("assert("),
            "QueryAbortExample should use assert() for key validations"
        )
    }
}

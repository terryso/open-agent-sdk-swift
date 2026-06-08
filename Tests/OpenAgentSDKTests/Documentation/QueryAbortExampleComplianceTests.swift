import XCTest
import Foundation

// MARK: - ATDD Tests for Story 15-5: QueryAbortExample
// TDD RED PHASE: These tests will FAIL until Examples/QueryAbortExample/ is created
// and Package.swift is updated with the QueryAbortExample executableTarget.

final class QueryAbortExampleComplianceTests: XCTestCase {

    // MARK: - Helpers

    private func examplePath() -> String {
        return DocumentationTestHelpers.examplesDir() + "/QueryAbortExample/main.swift"
    }

    // MARK: - AC6: Package.swift executableTarget Configured

    func testPackageSwiftContainsQueryAbortExampleTarget() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("QueryAbortExample"),
            "Package.swift should contain QueryAbortExample executable target"
        )
    }

    func testQueryAbortExampleTargetDependsOnOpenAgentSDK() {
        let content = DocumentationTestHelpers.packageSwiftContent()
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
        let content = DocumentationTestHelpers.packageSwiftContent()
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
            atPath: DocumentationTestHelpers.examplesDir() + "/QueryAbortExample",
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

    func testQueryAbortExampleImportsOpenAgentSDK() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "QueryAbortExample should import OpenAgentSDK"
        )
    }

    func testQueryAbortExampleImportsFoundation() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import Foundation"),
            "QueryAbortExample should import Foundation"
        )
    }

    // MARK: - AC1: Code Quality

    func testQueryAbortExampleHasTopLevelDescriptionComment() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "QueryAbortExample should start with a descriptive comment block"
        )
    }

    func testQueryAbortExampleHasMultipleInlineComments() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 5,
            "QueryAbortExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testQueryAbortExampleHasMarkSections() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let markCount = content.components(separatedBy: "MARK:").count - 1
        XCTAssertGreaterThanOrEqual(
            markCount, 3,
            "QueryAbortExample should have at least 3 MARK sections (Part 1, Part 2, Part 3)"
        )
    }

    func testQueryAbortExampleDoesNotUseForceUnwrap() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
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

    func testQueryAbortExampleDoesNotExposeRealAPIKeys() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertFalse(
            content.contains("sk-ant-api03") || content.contains("sk-proj-"),
            "QueryAbortExample should not contain real API keys"
        )
    }

    func testQueryAbortExampleUsesLoadDotEnvPattern() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("loadDotEnv()"),
            "QueryAbortExample should use loadDotEnv() helper pattern"
        )
    }

    func testQueryAbortExampleUsesGetEnvPattern() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("getEnv("),
            "QueryAbortExample should use getEnv() helper pattern for API key loading"
        )
    }

    func testQueryAbortExampleUsesBypassPermissions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("bypassPermissions") || content.contains(".bypassPermissions"),
            "QueryAbortExample should use permissionMode: .bypassPermissions"
        )
    }

    func testQueryAbortExampleUsesCreateAgent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("createAgent("),
            "QueryAbortExample should create an Agent using createAgent()"
        )
    }

    // MARK: - AC2: Task.cancel() Cancellation

    func testQueryAbortExampleUsesTaskBlock() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should use Task { } to wrap agent queries for cancellation
        let taskBlockCount = content.components(separatedBy: "Task {").count - 1
            + content.components(separatedBy: "Task{").count - 1
        XCTAssertGreaterThanOrEqual(
            taskBlockCount, 1,
            "QueryAbortExample should use Task { } block to wrap query for cancellation"
        )
    }

    func testQueryAbortExampleCallsTaskCancel() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".cancel()"),
            "QueryAbortExample should call task.cancel() to cancel the running query"
        )
    }

    func testQueryAbortExampleUsesTaskSleep() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should use Task.sleep for delay before cancellation
        XCTAssertTrue(
            content.contains("Task.sleep") || content.contains("sleep(for:"),
            "QueryAbortExample should use Task.sleep(for:) for delay before cancellation"
        )
    }

    func testQueryAbortExampleChecksIsCancelled() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("isCancelled"),
            "QueryAbortExample should check result.isCancelled after cancellation"
        )
    }

    func testQueryAbortExampleUsesPromptAPI() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("agent.prompt(") || content.contains(".prompt("),
            "QueryAbortExample should use agent.prompt() to execute queries"
        )
    }

    func testQueryAbortExampleUsesAwait() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("await"),
            "QueryAbortExample should use await for async prompt calls"
        )
    }

    // MARK: - AC3: Agent.interrupt() Cancellation

    func testQueryAbortExampleCallsAgentInterrupt() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("agent.interrupt()") || content.contains(".interrupt()"),
            "QueryAbortExample should call agent.interrupt() to cancel the running query"
        )
    }

    func testQueryAbortExampleDemonstratesSecondCancellationMechanism() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should demonstrate both Task.cancel() and agent.interrupt()
        let hasTaskCancel = content.contains(".cancel()")
        let hasInterrupt = content.contains("interrupt()")
        XCTAssertTrue(
            hasTaskCancel && hasInterrupt,
            "QueryAbortExample should demonstrate both Task.cancel() and Agent.interrupt() mechanisms"
        )
    }

    // MARK: - AC4: Partial Results Handling

    func testQueryAbortExampleInspectsPartialText() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should inspect result.text for partial output
        XCTAssertTrue(
            content.contains("result.text") || content.contains(".text"),
            "QueryAbortExample should inspect result.text for partial output after cancellation"
        )
    }

    func testQueryAbortExampleInspectsNumTurns() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("numTurns"),
            "QueryAbortExample should inspect result.numTurns for completed turns after cancellation"
        )
    }

    func testQueryAbortExampleInspectsUsage() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should reference usage for token counts after cancellation
        XCTAssertTrue(
            content.contains("usage") || content.contains("Tokens"),
            "QueryAbortExample should inspect result.usage for token usage after cancellation"
        )
    }

    // MARK: - AC5: Stream Cancellation

    func testQueryAbortExampleUsesStreamAPI() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("agent.stream(") || content.contains(".stream("),
            "QueryAbortExample should use agent.stream() API for streaming cancellation demo"
        )
    }

    func testQueryAbortExampleIteratesAsyncStream() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("for await"),
            "QueryAbortExample should iterate over AsyncStream with 'for await' pattern"
        )
    }

    func testQueryAbortExampleHandlesSDKMessageResult() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".result(") || content.contains("case .result"),
            "QueryAbortExample should handle .result case in SDKMessage stream events"
        )
    }

    func testQueryAbortExampleChecksCancelledSubtype() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".cancelled") || content.contains("cancelled"),
            "QueryAbortExample should check for .cancelled subtype in stream result events"
        )
    }

    func testQueryAbortExampleHasThreeParts() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should have three distinct parts: Task.cancel(), Agent.interrupt(), Stream
        let partCount = content.components(separatedBy: "Part ").count - 1
            + content.components(separatedBy: "PART ").count - 1
        XCTAssertGreaterThanOrEqual(
            partCount, 3,
            "QueryAbortExample should have at least 3 parts (Task.cancel, Agent.interrupt, Stream)"
        )
    }

    // MARK: - AC1 / Build Verification: assert() usage for compliance testing

    func testQueryAbortExampleUsesAssertions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // The example should use assert() for key validations so compliance tests can verify behavior
        XCTAssertTrue(
            content.contains("assert("),
            "QueryAbortExample should use assert() for key validations"
        )
    }
}

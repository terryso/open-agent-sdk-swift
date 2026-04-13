import XCTest
import Foundation

// MARK: - ATDD Tests for Story 15-7: MultiTurnExample
// TDD RED PHASE: These tests will FAIL until Examples/MultiTurnExample/ is created
// and Package.swift is updated with the MultiTurnExample executableTarget.

final class MultiTurnExampleComplianceTests: XCTestCase {

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
        return examplesDir() + "/MultiTurnExample/main.swift"
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

    // MARK: - AC7: Package.swift executableTarget Configured

    func testPackageSwiftContainsMultiTurnExampleTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("MultiTurnExample"),
            "Package.swift should contain MultiTurnExample executable target"
        )
    }

    func testMultiTurnExampleTargetDependsOnOpenAgentSDK() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("MultiTurnExample"),
            "Package.swift should contain MultiTurnExample target before checking dependencies"
        )
        let targetRange = content.range(of: "MultiTurnExample")
        XCTAssertNotNil(targetRange, "Should find MultiTurnExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "MultiTurnExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testMultiTurnExampleTargetSpecifiesCorrectPath() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("MultiTurnExample"),
            "Package.swift should contain MultiTurnExample target before checking path"
        )
        let targetRange = content.range(of: "MultiTurnExample")
        XCTAssertNotNil(targetRange, "Should find MultiTurnExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/MultiTurnExample"),
                    "MultiTurnExample target should specify path: 'Examples/MultiTurnExample'"
                )
            }
        }
    }

    // MARK: - AC1: MultiTurnExample Directory and File Existence

    func testMultiTurnExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: examplesDir() + "/MultiTurnExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/MultiTurnExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/MultiTurnExample/ should be a directory")
    }

    func testMultiTurnExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/MultiTurnExample/main.swift should exist"
        )
    }

    func testMultiTurnExampleImportsOpenAgentSDK() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "MultiTurnExample should import OpenAgentSDK"
        )
    }

    func testMultiTurnExampleImportsFoundation() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import Foundation"),
            "MultiTurnExample should import Foundation"
        )
    }

    // MARK: - AC1: Code Quality

    func testMultiTurnExampleHasTopLevelDescriptionComment() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "MultiTurnExample should start with a descriptive comment block"
        )
    }

    func testMultiTurnExampleHasMultipleInlineComments() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 5,
            "MultiTurnExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testMultiTurnExampleHasMarkSections() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        let markCount = content.components(separatedBy: "MARK:").count - 1
        XCTAssertGreaterThanOrEqual(
            markCount, 4,
            "MultiTurnExample should have at least 4 MARK sections (Part 1-4)"
        )
    }

    func testMultiTurnExampleDoesNotUseForceUnwrap() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            XCTAssertFalse(
                trimmed.contains("try!"),
                "MultiTurnExample should not use 'try!' force-try"
            )
        }
    }

    func testMultiTurnExampleDoesNotExposeRealAPIKeys() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertFalse(
            content.contains("sk-ant-api03") || content.contains("sk-proj-"),
            "MultiTurnExample should not contain real API keys"
        )
    }

    func testMultiTurnExampleUsesLoadDotEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("loadDotEnv()"),
            "MultiTurnExample should use loadDotEnv() helper pattern"
        )
    }

    func testMultiTurnExampleUsesGetEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("getEnv("),
            "MultiTurnExample should use getEnv() helper pattern for API key loading"
        )
    }

    func testMultiTurnExampleUsesAssertions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("assert("),
            "MultiTurnExample should use assert() for key validations"
        )
    }

    // MARK: - AC2: Multi-turn with SessionStore

    func testMultiTurnExampleCreatesSessionStore() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("SessionStore(") || content.contains("SessionStore()"),
            "MultiTurnExample should create a SessionStore instance"
        )
    }

    func testMultiTurnExampleCreatesAgentWithSessionStoreAndSessionId() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("sessionStore"),
            "MultiTurnExample should pass sessionStore to AgentOptions"
        )
        XCTAssertTrue(
            content.contains("sessionId"),
            "MultiTurnExample should pass sessionId to AgentOptions"
        )
    }

    func testMultiTurnExampleExecutesMultiplePrompts() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        // Count occurrences of .prompt( or agent.prompt(
        let promptCount = content.components(separatedBy: ".prompt(").count - 1
            + content.components(separatedBy: "agent.prompt(").count - 1
        XCTAssertGreaterThanOrEqual(
            promptCount, 2,
            "MultiTurnExample should execute at least 2 prompt() calls for multi-turn conversation"
        )
    }

    // MARK: - AC3: Cross-turn Context Retention

    func testMultiTurnExampleDemonstratesCrossTurnContext() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        // Should tell the agent a fact in turn 1 and ask about it in turn 2
        let hasNameFact = content.contains("name is") || content.contains("my name")
            || content.contains("remember") || content.contains("Remember")
        XCTAssertTrue(
            hasNameFact,
            "MultiTurnExample should demonstrate telling the Agent a fact in the first turn"
        )
    }

    func testMultiTurnExampleAssertsContextRetention() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        // Should have an assert that verifies the second response contains the context
        // Look for assert with context check (e.g., assert(response.contains("Nick")))
        let hasAssertWithContext = content.contains("assert(") &&
            (content.contains("contains(") || content.contains("Contains"))
        XCTAssertTrue(
            hasAssertWithContext,
            "MultiTurnExample should assert that the second response contains the expected context"
        )
    }

    func testMultiTurnExampleUsesBypassPermissions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("bypassPermissions") || content.contains(".bypassPermissions"),
            "MultiTurnExample should use permissionMode: .bypassPermissions"
        )
    }

    func testMultiTurnExampleUsesCreateAgent() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent("),
            "MultiTurnExample should create an Agent using createAgent()"
        )
    }

    func testMultiTurnExampleUsesAwait() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("await"),
            "MultiTurnExample should use await for async operations"
        )
    }

    // MARK: - AC4: Message History Inspection

    func testMultiTurnExampleLoadsSessionData() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("sessionStore.load(") || content.contains(".load(sessionId:"),
            "MultiTurnExample should load session via sessionStore.load(sessionId:)"
        )
    }

    func testMultiTurnExampleAccessesMessageCount() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("messageCount"),
            "MultiTurnExample should access metadata.messageCount from SessionData"
        )
    }

    func testMultiTurnExamplePrintsMetadata() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        // Should reference at least model and timestamps
        let hasModel = content.contains("model")
        let hasCreatedAt = content.contains("createdAt")
        let hasUpdatedAt = content.contains("updatedAt")
        XCTAssertTrue(
            hasModel && hasCreatedAt && hasUpdatedAt,
            "MultiTurnExample should print model, createdAt, and updatedAt from session metadata"
        )
    }

    func testMultiTurnExampleAssertsMessageCountGreaterThanZero() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        // Should assert messageCount > 0 or messageCount >= N
        let hasMessageCountAssert = content.contains("messageCount") &&
            content.contains("assert(")
        XCTAssertTrue(
            hasMessageCountAssert,
            "MultiTurnExample should assert that messageCount is positive"
        )
    }

    // MARK: - AC5: Streaming Multi-turn

    func testMultiTurnExampleUsesStream() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".stream(") || content.contains("agent.stream("),
            "MultiTurnExample should use agent.stream() for a streaming turn"
        )
    }

    func testMultiTurnExampleCollectsSDKMessageEvents() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        // Should collect SDKMessage events from stream
        let hasSDKMessage = content.contains("SDKMessage")
        XCTAssertTrue(
            hasSDKMessage,
            "MultiTurnExample should collect SDKMessage events from streaming"
        )
    }

    func testMultiTurnExampleAssertsStreamingResponseNonEmpty() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        // Should assert that the streaming response is non-empty
        // Look for assert near stream-related code
        let streamSectionRange = content.range(of: "stream(")
        XCTAssertNotNil(streamSectionRange, "Should find stream( in example code")
        if let streamRange = streamSectionRange {
            let afterStream = content[streamRange.lowerBound...]
            let hasAssert = afterStream.contains("assert(")
            XCTAssertTrue(
                hasAssert,
                "MultiTurnExample should assert that streaming response is non-empty"
            )
        }
    }

    // MARK: - AC6: Session Cleanup

    func testMultiTurnExampleDeletesSession() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("sessionStore.delete(") || content.contains(".delete(sessionId:"),
            "MultiTurnExample should delete the session via sessionStore.delete(sessionId:)"
        )
    }

    func testMultiTurnExampleAssertsDeletionSucceeded() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        // After delete, should assert it returned true
        let deleteSectionRange = content.range(of: "delete(")
        XCTAssertNotNil(deleteSectionRange, "Should find delete( in example code")
        if let deleteRange = deleteSectionRange {
            let afterDelete = content[deleteRange.lowerBound...]
            let hasAssert = afterDelete.contains("assert(")
            XCTAssertTrue(
                hasAssert,
                "MultiTurnExample should assert that session deletion succeeded"
            )
        }
    }

    func testMultiTurnExampleVerifiesSessionNoLongerExists() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        // After deletion, should verify session is gone (nil check)
        let deleteSectionRange = content.range(of: "delete(")
        XCTAssertNotNil(deleteSectionRange, "Should find delete( in example code")
        if let deleteRange = deleteSectionRange {
            let afterDelete = content[deleteRange.lowerBound...]
            let hasNilCheck = afterDelete.contains("== nil") || afterDelete.contains("!= nil")
                || afterDelete.contains("is nil") || afterDelete.contains("guard let")
            XCTAssertTrue(
                hasNilCheck,
                "MultiTurnExample should verify session no longer exists after deletion"
            )
        }
    }

    // MARK: - AC1: Structure Validation

    func testMultiTurnExampleHasFourParts() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        // Should have four distinct parts
        let partCount = content.components(separatedBy: "Part ").count - 1
            + content.components(separatedBy: "PART ").count - 1
        XCTAssertGreaterThanOrEqual(
            partCount, 4,
            "MultiTurnExample should have at least 4 parts (Multi-turn, History, Streaming, Cleanup)"
        )
    }

    func testMultiTurnExampleUsesSpecificSessionId() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/MultiTurnExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("multi-turn-demo"),
            "MultiTurnExample should use 'multi-turn-demo' as the session ID"
        )
    }
}

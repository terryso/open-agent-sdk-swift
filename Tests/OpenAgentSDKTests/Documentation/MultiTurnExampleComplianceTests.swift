import XCTest
import Foundation

// MARK: - ATDD Tests for Story 15-7: MultiTurnExample
// TDD RED PHASE: These tests will FAIL until Examples/MultiTurnExample/ is created
// and Package.swift is updated with the MultiTurnExample executableTarget.

final class MultiTurnExampleComplianceTests: XCTestCase {

    // MARK: - Helpers

    private func examplePath() -> String {
        return DocumentationTestHelpers.examplesDir() + "/MultiTurnExample/main.swift"
    }

    // MARK: - AC7: Package.swift executableTarget Configured

    func testPackageSwiftContainsMultiTurnExampleTarget() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("MultiTurnExample"),
            "Package.swift should contain MultiTurnExample executable target"
        )
    }

    func testMultiTurnExampleTargetDependsOnOpenAgentSDK() {
        let content = DocumentationTestHelpers.packageSwiftContent()
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
        let content = DocumentationTestHelpers.packageSwiftContent()
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
            atPath: DocumentationTestHelpers.examplesDir() + "/MultiTurnExample",
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

    func testMultiTurnExampleImportsOpenAgentSDK() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "MultiTurnExample should import OpenAgentSDK"
        )
    }

    func testMultiTurnExampleImportsFoundation() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import Foundation"),
            "MultiTurnExample should import Foundation"
        )
    }

    // MARK: - AC1: Code Quality

    func testMultiTurnExampleHasTopLevelDescriptionComment() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "MultiTurnExample should start with a descriptive comment block"
        )
    }

    func testMultiTurnExampleHasMultipleInlineComments() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 5,
            "MultiTurnExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testMultiTurnExampleHasMarkSections() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let markCount = content.components(separatedBy: "MARK:").count - 1
        XCTAssertGreaterThanOrEqual(
            markCount, 4,
            "MultiTurnExample should have at least 4 MARK sections (Part 1-4)"
        )
    }

    func testMultiTurnExampleDoesNotUseForceUnwrap() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
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

    func testMultiTurnExampleDoesNotExposeRealAPIKeys() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertFalse(
            content.contains("sk-ant-api03") || content.contains("sk-proj-"),
            "MultiTurnExample should not contain real API keys"
        )
    }

    func testMultiTurnExampleUsesLoadDotEnvPattern() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("loadDotEnv()"),
            "MultiTurnExample should use loadDotEnv() helper pattern"
        )
    }

    func testMultiTurnExampleUsesGetEnvPattern() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("getEnv("),
            "MultiTurnExample should use getEnv() helper pattern for API key loading"
        )
    }

    func testMultiTurnExampleUsesAssertions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("assert("),
            "MultiTurnExample should use assert() for key validations"
        )
    }

    // MARK: - AC2: Multi-turn with SessionStore

    func testMultiTurnExampleCreatesSessionStore() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("SessionStore(") || content.contains("SessionStore()"),
            "MultiTurnExample should create a SessionStore instance"
        )
    }

    func testMultiTurnExampleCreatesAgentWithSessionStoreAndSessionId() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("sessionStore"),
            "MultiTurnExample should pass sessionStore to AgentOptions"
        )
        XCTAssertTrue(
            content.contains("sessionId"),
            "MultiTurnExample should pass sessionId to AgentOptions"
        )
    }

    func testMultiTurnExampleExecutesMultiplePrompts() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Count occurrences of .prompt( or agent.prompt(
        let promptCount = content.components(separatedBy: ".prompt(").count - 1
            + content.components(separatedBy: "agent.prompt(").count - 1
        XCTAssertGreaterThanOrEqual(
            promptCount, 2,
            "MultiTurnExample should execute at least 2 prompt() calls for multi-turn conversation"
        )
    }

    // MARK: - AC3: Cross-turn Context Retention

    func testMultiTurnExampleDemonstratesCrossTurnContext() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should tell the agent a fact in turn 1 and ask about it in turn 2
        let hasNameFact = content.contains("name is") || content.contains("my name")
            || content.contains("remember") || content.contains("Remember")
        XCTAssertTrue(
            hasNameFact,
            "MultiTurnExample should demonstrate telling the Agent a fact in the first turn"
        )
    }

    func testMultiTurnExampleAssertsContextRetention() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should have an assert that verifies the second response contains the context
        // Look for assert with context check (e.g., assert(response.contains("Nick")))
        let hasAssertWithContext = content.contains("assert(") &&
            (content.contains("contains(") || content.contains("Contains"))
        XCTAssertTrue(
            hasAssertWithContext,
            "MultiTurnExample should assert that the second response contains the expected context"
        )
    }

    func testMultiTurnExampleUsesBypassPermissions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("bypassPermissions") || content.contains(".bypassPermissions"),
            "MultiTurnExample should use permissionMode: .bypassPermissions"
        )
    }

    func testMultiTurnExampleUsesCreateAgent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("createAgent("),
            "MultiTurnExample should create an Agent using createAgent()"
        )
    }

    func testMultiTurnExampleUsesAwait() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("await"),
            "MultiTurnExample should use await for async operations"
        )
    }

    // MARK: - AC4: Message History Inspection

    func testMultiTurnExampleLoadsSessionData() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("sessionStore.load(") || content.contains(".load(sessionId:"),
            "MultiTurnExample should load session via sessionStore.load(sessionId:)"
        )
    }

    func testMultiTurnExampleAccessesMessageCount() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("messageCount"),
            "MultiTurnExample should access metadata.messageCount from SessionData"
        )
    }

    func testMultiTurnExamplePrintsMetadata() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should reference at least model and timestamps
        let hasModel = content.contains("model")
        let hasCreatedAt = content.contains("createdAt")
        let hasUpdatedAt = content.contains("updatedAt")
        XCTAssertTrue(
            hasModel && hasCreatedAt && hasUpdatedAt,
            "MultiTurnExample should print model, createdAt, and updatedAt from session metadata"
        )
    }

    func testMultiTurnExampleAssertsMessageCountGreaterThanZero() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should assert messageCount > 0 or messageCount >= N
        let hasMessageCountAssert = content.contains("messageCount") &&
            content.contains("assert(")
        XCTAssertTrue(
            hasMessageCountAssert,
            "MultiTurnExample should assert that messageCount is positive"
        )
    }

    // MARK: - AC5: Streaming Multi-turn

    func testMultiTurnExampleUsesStream() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".stream(") || content.contains("agent.stream("),
            "MultiTurnExample should use agent.stream() for a streaming turn"
        )
    }

    func testMultiTurnExampleCollectsSDKMessageEvents() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should collect SDKMessage events from stream
        let hasSDKMessage = content.contains("SDKMessage")
        XCTAssertTrue(
            hasSDKMessage,
            "MultiTurnExample should collect SDKMessage events from streaming"
        )
    }

    func testMultiTurnExampleAssertsStreamingResponseNonEmpty() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
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

    func testMultiTurnExampleDeletesSession() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("sessionStore.delete(") || content.contains(".delete(sessionId:"),
            "MultiTurnExample should delete the session via sessionStore.delete(sessionId:)"
        )
    }

    func testMultiTurnExampleAssertsDeletionSucceeded() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
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

    func testMultiTurnExampleVerifiesSessionNoLongerExists() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
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

    func testMultiTurnExampleHasFourParts() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should have four distinct parts
        let partCount = content.components(separatedBy: "Part ").count - 1
            + content.components(separatedBy: "PART ").count - 1
        XCTAssertGreaterThanOrEqual(
            partCount, 4,
            "MultiTurnExample should have at least 4 parts (Multi-turn, History, Streaming, Cleanup)"
        )
    }

    func testMultiTurnExampleUsesSpecificSessionId() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("multi-turn-demo"),
            "MultiTurnExample should use 'multi-turn-demo' as the session ID"
        )
    }
}

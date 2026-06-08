import XCTest
import Foundation

// MARK: - ATDD Tests for Story 15-6: ContextInjectionExample
// TDD RED PHASE: These tests will FAIL until Examples/ContextInjectionExample/ is created
// and Package.swift is updated with the ContextInjectionExample executableTarget.

final class ContextInjectionExampleComplianceTests: XCTestCase {

    // MARK: - Helpers

    private func examplePath() -> String {
        return DocumentationTestHelpers.examplesDir() + "/ContextInjectionExample/main.swift"
    }

    // MARK: - AC8: Package.swift executableTarget Configured

    func testPackageSwiftContainsContextInjectionExampleTarget() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("ContextInjectionExample"),
            "Package.swift should contain ContextInjectionExample executable target"
        )
    }

    func testContextInjectionExampleTargetDependsOnOpenAgentSDK() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("ContextInjectionExample"),
            "Package.swift should contain ContextInjectionExample target before checking dependencies"
        )
        let targetRange = content.range(of: "ContextInjectionExample")
        XCTAssertNotNil(targetRange, "Should find ContextInjectionExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "ContextInjectionExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testContextInjectionExampleTargetSpecifiesCorrectPath() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("ContextInjectionExample"),
            "Package.swift should contain ContextInjectionExample target before checking path"
        )
        let targetRange = content.range(of: "ContextInjectionExample")
        XCTAssertNotNil(targetRange, "Should find ContextInjectionExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/ContextInjectionExample"),
                    "ContextInjectionExample target should specify path: 'Examples/ContextInjectionExample'"
                )
            }
        }
    }

    // MARK: - AC1: ContextInjectionExample Directory and File Existence

    func testContextInjectionExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: DocumentationTestHelpers.examplesDir() + "/ContextInjectionExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/ContextInjectionExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/ContextInjectionExample/ should be a directory")
    }

    func testContextInjectionExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/ContextInjectionExample/main.swift should exist"
        )
    }

    func testContextInjectionExampleImportsOpenAgentSDK() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "ContextInjectionExample should import OpenAgentSDK"
        )
    }

    func testContextInjectionExampleImportsFoundation() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import Foundation"),
            "ContextInjectionExample should import Foundation"
        )
    }

    // MARK: - AC1: Code Quality

    func testContextInjectionExampleHasTopLevelDescriptionComment() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "ContextInjectionExample should start with a descriptive comment block"
        )
    }

    func testContextInjectionExampleHasMultipleInlineComments() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 5,
            "ContextInjectionExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testContextInjectionExampleHasMarkSections() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let markCount = content.components(separatedBy: "MARK:").count - 1
        XCTAssertGreaterThanOrEqual(
            markCount, 5,
            "ContextInjectionExample should have at least 5 MARK sections (Part 1-5)"
        )
    }

    func testContextInjectionExampleDoesNotUseForceUnwrap() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            XCTAssertFalse(
                trimmed.contains("try!"),
                "ContextInjectionExample should not use 'try!' force-try"
            )
        }
    }

    func testContextInjectionExampleDoesNotExposeRealAPIKeys() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertFalse(
            content.contains("sk-ant-api03") || content.contains("sk-proj-"),
            "ContextInjectionExample should not contain real API keys"
        )
    }

    func testContextInjectionExampleUsesLoadDotEnvPattern() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("loadDotEnv()"),
            "ContextInjectionExample should use loadDotEnv() helper pattern"
        )
    }

    func testContextInjectionExampleUsesGetEnvPattern() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("getEnv("),
            "ContextInjectionExample should use getEnv() helper pattern for API key loading"
        )
    }

    func testContextInjectionExampleUsesAssertions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("assert("),
            "ContextInjectionExample should use assert() for key validations"
        )
    }

    // MARK: - AC2: FileCache Configuration and Hit/Miss Stats

    func testContextInjectionExampleCreatesFileCache() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("FileCache("),
            "ContextInjectionExample should create a FileCache instance with custom parameters"
        )
    }

    func testContextInjectionExampleConfiguresFileCacheParams() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should configure at least maxEntries
        XCTAssertTrue(
            content.contains("maxEntries"),
            "ContextInjectionExample should configure FileCache maxEntries parameter"
        )
    }

    func testContextInjectionExampleUsesCacheSet() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".set(") || content.contains("cache.set("),
            "ContextInjectionExample should use cache.set() to store entries"
        )
    }

    func testContextInjectionExampleUsesCacheGet() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".get(") || content.contains("cache.get("),
            "ContextInjectionExample should use cache.get() to retrieve entries"
        )
    }

    func testContextInjectionExamplePrintsCacheStats() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should reference stats object and at least one stat field
        let hasStats = content.contains("stats") || content.contains(".stats")
        let hasStatField = content.contains("hitCount") || content.contains("missCount")
            || content.contains("evictionCount") || content.contains("totalEntries")
            || content.contains("totalSizeBytes")
        XCTAssertTrue(
            hasStats || hasStatField,
            "ContextInjectionExample should print cache statistics (hitCount, missCount, etc.)"
        )
    }

    func testContextInjectionExampleDemonstratesHitAndMiss() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should demonstrate both cache hits and misses
        let hasHitCount = content.contains("hitCount")
        let hasMissCount = content.contains("missCount")
        XCTAssertTrue(
            hasHitCount && hasMissCount,
            "ContextInjectionExample should demonstrate both hit and miss counts"
        )
    }

    // MARK: - AC3: FileCache Invalidation

    func testContextInjectionExampleUsesCacheInvalidate() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".invalidate(") || content.contains("cache.invalidate("),
            "ContextInjectionExample should use cache.invalidate() to remove entries"
        )
    }

    func testContextInjectionExampleVerifiesNilAfterInvalidation() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // After invalidation, should verify the entry is gone (nil check)
        let hasNilCheck = content.contains("== nil") || content.contains("!= nil")
            || content.contains("is nil") || content.contains("guard let")
        XCTAssertTrue(
            hasNilCheck,
            "ContextInjectionExample should verify nil result after cache invalidation"
        )
    }

    func testContextInjectionExampleDemonstratesEviction() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should demonstrate eviction by exceeding maxEntries
        let hasEvictionCount = content.contains("evictionCount")
        XCTAssertTrue(
            hasEvictionCount,
            "ContextInjectionExample should demonstrate eviction with evictionCount"
        )
    }

    // MARK: - AC4: Git Context Collection

    func testContextInjectionExampleCreatesGitContextCollector() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("GitContextCollector(") || content.contains("GitContextCollector()"),
            "ContextInjectionExample should create a GitContextCollector instance"
        )
    }

    func testContextInjectionExampleCallsCollectGitContext() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("collectGitContext("),
            "ContextInjectionExample should call collectGitContext(cwd:ttl:)"
        )
    }

    func testContextInjectionExamplePrintsGitContextBlock() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should print or reference the git-context XML block
        let hasGitContext = content.contains("git-context") || content.contains("<git-context>")
            || content.contains("git context") || content.contains("Git context")
        XCTAssertTrue(
            hasGitContext,
            "ContextInjectionExample should print or reference the git-context XML block"
        )
    }

    func testContextInjectionExampleUsesTTLParameter() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should pass a ttl parameter to collectGitContext
        XCTAssertTrue(
            content.contains("ttl:"),
            "ContextInjectionExample should pass ttl parameter to collectGitContext"
        )
    }

    // MARK: - AC5: Project Document Discovery

    func testContextInjectionExampleCreatesProjectDocumentDiscovery() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("ProjectDocumentDiscovery(") || content.contains("ProjectDocumentDiscovery()"),
            "ContextInjectionExample should create a ProjectDocumentDiscovery instance"
        )
    }

    func testContextInjectionExampleCallsCollectProjectContext() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("collectProjectContext("),
            "ContextInjectionExample should call collectProjectContext()"
        )
    }

    func testContextInjectionExampleAccessesGlobalInstructions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("globalInstructions"),
            "ContextInjectionExample should access globalInstructions from ProjectContextResult"
        )
    }

    func testContextInjectionExampleAccessesProjectInstructions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("projectInstructions"),
            "ContextInjectionExample should access projectInstructions from ProjectContextResult"
        )
    }

    // MARK: - AC6: Custom Project Root

    func testContextInjectionExampleDemonstratesExplicitProjectRoot() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should pass explicitProjectRoot parameter
        XCTAssertTrue(
            content.contains("explicitProjectRoot"),
            "ContextInjectionExample should demonstrate explicitProjectRoot parameter"
        )
    }

    func testContextInjectionExampleDemonstratesAutoDiscovery() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should also demonstrate auto-discovery by passing nil for explicitProjectRoot
        let hasNilRoot = content.contains("explicitProjectRoot: nil")
        XCTAssertTrue(
            hasNilRoot,
            "ContextInjectionExample should demonstrate auto-discovery with explicitProjectRoot: nil"
        )
    }

    // MARK: - AC7: Agent Query with Context Injection

    func testContextInjectionExampleUsesBypassPermissions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("bypassPermissions") || content.contains(".bypassPermissions"),
            "ContextInjectionExample should use permissionMode: .bypassPermissions"
        )
    }

    func testContextInjectionExampleUsesCreateAgent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("createAgent("),
            "ContextInjectionExample should create an Agent using createAgent()"
        )
    }

    func testContextInjectionExampleSetsProjectRoot() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should set projectRoot in AgentOptions
        XCTAssertTrue(
            content.contains("projectRoot"),
            "ContextInjectionExample should set projectRoot in AgentOptions"
        )
    }

    func testContextInjectionExampleExecutesQuery() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("agent.prompt(") || content.contains(".prompt("),
            "ContextInjectionExample should execute an agent query via prompt()"
        )
    }

    func testContextInjectionExampleUsesAwait() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("await"),
            "ContextInjectionExample should use await for async operations"
        )
    }

    func testContextInjectionExampleHasFiveParts() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should have five distinct parts
        let partCount = content.components(separatedBy: "Part ").count - 1
            + content.components(separatedBy: "PART ").count - 1
        XCTAssertGreaterThanOrEqual(
            partCount, 5,
            "ContextInjectionExample should have at least 5 parts (FileCache Config, Invalidation, Git Context, Project Discovery, Agent Query)"
        )
    }
}

import XCTest
import Foundation

// MARK: - ATDD Tests for Story 9-1: Swift-DocC API Documentation
// TDD RED PHASE: These tests will FAIL until documentation infrastructure is implemented.

final class DocCComplianceTests: XCTestCase {

    // MARK: - Helper: Resolve project root

    /// Walk upward from the test bundle to find the directory containing Package.swift.
    private func projectRoot() -> String {
        let fileManager = FileManager.default
        // Start from the test file's directory or current working directory
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

    private func sourcesDir() -> String {
        return projectRoot() + "/Sources/OpenAgentSDK"
    }

    private func doccDir() -> String {
        return sourcesDir() + "/Documentation.docc"
    }

    // MARK: - AC1: DocC Catalog Directory Structure

    func testDocCCatalogDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: doccDir(), isDirectory: &isDir)
        XCTAssertTrue(exists, "Documentation.docc directory should exist at Sources/OpenAgentSDK/Documentation.docc/")
        XCTAssertTrue(isDir.boolValue, "Documentation.docc should be a directory, not a file")
    }

    func testDocCCatalogContainsModuleDocumentation() {
        let moduleDocPath = doccDir() + "/OpenAgentSDK.md"
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: moduleDocPath),
            "OpenAgentSDK.md module documentation should exist in Documentation.docc/"
        )

        // Verify content is non-empty and has a title
        if let content = try? String(contentsOfFile: moduleDocPath, encoding: .utf8), !content.isEmpty {
            XCTAssertTrue(
                content.contains("# "),
                "OpenAgentSDK.md should contain a markdown heading (title)"
            )
        }
    }

    func testDocCCatalogContainsArticles() {
        let fileManager = FileManager.default
        let requiredArticles = [
            "GettingStarted.md",
            "ToolSystem.md",
            "MultiAgent.md",
            "MCPSessionHooks.md"
        ]

        for article in requiredArticles {
            let path = doccDir() + "/" + article
            XCTAssertTrue(
                fileManager.fileExists(atPath: path),
                "\(article) should exist in Documentation.docc/"
            )
        }
    }

    // MARK: - AC2: DocC Plugin Integration

    func testPackageSwiftContainsDocCPluginDependency() {
        let packagePath = projectRoot() + "/Package.swift"
        let content = try? String(contentsOfFile: packagePath, encoding: .utf8)

        XCTAssertNotNil(content, "Package.swift should be readable")

        XCTAssertTrue(
            content!.contains("swift-docc-plugin"),
            "Package.swift should contain swift-docc-plugin as a dependency"
        )
    }

    // MARK: - AC3: All Public Types Have Documentation Comments

    func testPublicDeclarationsHaveDocCComments() {
        // Audit that key source files have /// comments on public declarations.
        // This tests a representative sample of files rather than all 593 declarations.
        let filesToAudit = [
            "Types/ErrorTypes.swift",
            "Types/SDKMessage.swift",
            "Types/ThinkingConfig.swift",
            "Types/TokenUsage.swift",
            "Types/ModelInfo.swift"
        ]

        for file in filesToAudit {
            let filePath = sourcesDir() + "/" + file
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                XCTFail("Could not read \(file)")
                continue
            }

            let lines = content.components(separatedBy: "\n")
            var publicCount = 0
            var documentedCount = 0

            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("public ") && !trimmed.hasPrefix("public init") || trimmed.hasPrefix("public init") {
                    // Check if the preceding line is a /// comment
                    publicCount += 1
                    if index > 0 {
                        let prevTrimmed = lines[index - 1].trimmingCharacters(in: .whitespaces)
                        if prevTrimmed.hasPrefix("///") {
                            documentedCount += 1
                        }
                    }
                }
            }

            if publicCount > 0 {
                let coverage = Double(documentedCount) / Double(publicCount)
                XCTAssertGreaterThanOrEqual(
                    coverage, 0.8,
                    "\(file) should have at least 80% of public declarations documented (found \(documentedCount)/\(publicCount))"
                )
            }
        }
    }

    func testCoreTypesHaveDocCComments() {
        let filesToAudit = [
            "Types/AgentTypes.swift",
            "Types/SDKConfiguration.swift",
            "Types/ToolTypes.swift",
            "Types/PermissionTypes.swift",
            "Types/SessionTypes.swift",
            "Types/HookTypes.swift",
            "Types/TaskTypes.swift"
        ]

        for file in filesToAudit {
            let filePath = sourcesDir() + "/" + file
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                XCTFail("Could not read \(file)")
                continue
            }

            // Count /// lines vs public lines as a coverage ratio
            let docCCommentLines = content.components(separatedBy: "\n")
                .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
                .count
            let publicLines = content.components(separatedBy: "\n")
                .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("public ") }
                .count

            if publicLines > 0 {
                XCTAssertGreaterThan(
                    docCCommentLines, 0,
                    "\(file) should have at least some DocC comments (found \(publicLines) public declarations, 0 /// comments)"
                )
            }
        }
    }

    func testAgentPublicAPIHasDocCComments() {
        let filePath = sourcesDir() + "/Core/Agent.swift"
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            XCTFail("Could not read Core/Agent.swift")
            return
        }

        // Agent class should have DocC comments on its main public methods
        let keyMethods = [
            "func prompt(",
            "func stream(",
            "func setPermissionMode(",
            "func setCanUseTool("
        ]

        for method in keyMethods {
            // Find the method and check if there's a /// comment before it
            let lines = content.components(separatedBy: "\n")
            var found = false
            for (index, line) in lines.enumerated() {
                if line.contains(method) && line.contains("public") {
                    found = true
                    if index > 0 {
                        let prevTrimmed = lines[index - 1].trimmingCharacters(in: .whitespaces)
                        XCTAssertTrue(
                            prevTrimmed.hasPrefix("///"),
                            "Method \(method) should have a /// DocC comment before it"
                        )
                    }
                }
            }
            XCTAssertTrue(found, "Expected to find public \(method) in Agent.swift")
        }
    }

    func testToolBuilderPublicAPIHasDocCComments() {
        let filePath = sourcesDir() + "/Tools/ToolBuilder.swift"
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            XCTFail("Could not read Tools/ToolBuilder.swift")
            return
        }

        // defineTool functions should have DocC comments
        let lines = content.components(separatedBy: "\n")
        var defineToolCount = 0
        var documentedCount = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("public func defineTool") {
                defineToolCount += 1
                if index > 0 {
                    let prevTrimmed = lines[index - 1].trimmingCharacters(in: .whitespaces)
                    if prevTrimmed.hasPrefix("///") {
                        documentedCount += 1
                    }
                }
            }
        }

        XCTAssertGreaterThan(defineToolCount, 0, "ToolBuilder should have public defineTool functions")
        XCTAssertEqual(
            documentedCount, defineToolCount,
            "All \(defineToolCount) defineTool overloads should have DocC comments (only \(documentedCount) documented)"
        )
    }

    func testStoreActorsHaveDocCComments() {
        let storeFiles = [
            "Stores/SessionStore.swift",
            "Stores/TaskStore.swift",
            "Stores/TeamStore.swift",
            "Stores/MailboxStore.swift",
            "Stores/AgentRegistry.swift"
        ]

        for file in storeFiles {
            let filePath = sourcesDir() + "/" + file
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                XCTFail("Could not read \(file)")
                continue
            }

            // Each store actor should have at least one /// comment on a public declaration
            let docCCommentLines = content.components(separatedBy: "\n")
                .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
                .count
            let publicLines = content.components(separatedBy: "\n")
                .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("public ") }
                .count

            if publicLines > 0 {
                XCTAssertGreaterThan(
                    docCCommentLines, 0,
                    "\(file) should have DocC comments on public declarations (found \(publicLines) public declarations)"
                )
            }
        }
    }

    // MARK: - AC4: Module-Level Documentation

    func testOpenAgentSDKMdContainsRequiredSections() {
        let moduleDocPath = doccDir() + "/OpenAgentSDK.md"
        guard let content = try? String(contentsOfFile: moduleDocPath, encoding: .utf8) else {
            XCTFail("OpenAgentSDK.md should exist and be readable")
            return
        }

        // Required sections per AC4
        let requiredContent = [
            "Agent",       // Core concepts
            "Tool",        // Tool system
            "Session"      // Session management
        ]

        for term in requiredContent {
            XCTAssertTrue(
                content.contains(term),
                "OpenAgentSDK.md should mention '\(term)' (core concept)"
            )
        }

        // Should have a code example
        XCTAssertTrue(
            content.contains("```swift"),
            "OpenAgentSDK.md should contain a Swift code example"
        )
    }

    // MARK: - AC8: Getting Started Guide

    func testGettingStartedMdContainsRunnableExample() {
        let gettingStartedPath = doccDir() + "/GettingStarted.md"
        guard let content = try? String(contentsOfFile: gettingStartedPath, encoding: .utf8) else {
            XCTFail("GettingStarted.md should exist and be readable")
            return
        }

        // Should contain a complete runnable example
        XCTAssertTrue(
            content.contains("```swift"),
            "GettingStarted.md should contain Swift code examples"
        )

        // Key concepts for a getting started guide
        let requiredTerms = [
            "createAgent",    // Factory function
            "AgentOptions",   // Configuration
            "prompt"          // Core interaction
        ]

        for term in requiredTerms {
            XCTAssertTrue(
                content.contains(term),
                "GettingStarted.md should demonstrate '\(term)' usage"
            )
        }
    }

    // MARK: - AC5: Tool System Documentation

    func testToolSystemMdDocumentsProtocols() {
        let toolSystemPath = doccDir() + "/ToolSystem.md"
        guard let content = try? String(contentsOfFile: toolSystemPath, encoding: .utf8) else {
            XCTFail("ToolSystem.md should exist and be readable")
            return
        }

        let requiredTopics = [
            "ToolProtocol",    // The protocol itself
            "defineTool",      // Factory function
            "Codable",         // Input type requirement
            "ToolTier"         // Tool hierarchy
        ]

        for topic in requiredTopics {
            XCTAssertTrue(
                content.contains(topic),
                "ToolSystem.md should cover '\(topic)'"
            )
        }

        // Should contain a custom tool creation example
        XCTAssertTrue(
            content.contains("```swift"),
            "ToolSystem.md should contain Swift code examples for tool creation"
        )
    }

    // MARK: - AC9: Code Examples Do Not Expose Real API Keys

    func testDocCArticlesDoNotExposeRealAPIKeys() {
        let fileManager = FileManager.default
        let articlesDir = doccDir()

        guard let files = try? fileManager.contentsOfDirectory(atPath: articlesDir) else {
            XCTFail("Documentation.docc/ directory should exist")
            return
        }

        let markdownFiles = files.filter { $0.hasSuffix(".md") }

        for fileName in markdownFiles {
            let filePath = articlesDir + "/" + fileName
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                continue
            }

            // Should NOT contain patterns that look like real API keys
            // Acceptable: "sk-...", "your-api-key", "YOUR_API_KEY"
            // Unacceptable: actual key patterns like "sk-ant-..." with real-looking content
            let lines = content.components(separatedBy: "\n")
            for line in lines {
                // Check for lines that have a key assignment with a value that's not a placeholder
                if line.contains("apiKey") && line.contains("=") && !line.contains("\"") {
                    // Skip lines without string literals (likely comments)
                    continue
                }
                if line.contains("sk-") && !line.contains("sk-...") && !line.contains("sk-xxx") {
                    // If "sk-" appears, it should be followed by "..." or "xxx" placeholder
                    let afterSk = line.components(separatedBy: "sk-")
                    if afterSk.count > 1 {
                        let remainder = afterSk[1].trimmingCharacters(in: .whitespaces)
                        // Allow: "sk-...", "sk-xxx", "sk-your-key-here"
                        let isPlaceholder = remainder.hasPrefix("...") ||
                            remainder.hasPrefix("xxx") ||
                            remainder.hasPrefix("your") ||
                            remainder.hasPrefix("<")
                        XCTAssertTrue(
                            isPlaceholder,
                            "\(fileName) should not contain a real-looking API key pattern (found 'sk-\(remainder.prefix(20))...')"
                        )
                    }
                }
            }
        }
    }
}

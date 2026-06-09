import XCTest
import Foundation

// MARK: - ATDD Tests for Story 10-6: AdvancedMCPExample (Advanced MCP Tool Example)
// TDD RED PHASE: These tests will FAIL until Examples/AdvancedMCPExample/ is created
// and Package.swift is updated with the AdvancedMCPExample executableTarget.

final class AdvancedMCPExampleComplianceTests: XCTestCase {

    // MARK: - Helpers

    private func examplePath() -> String {
        return DocumentationTestHelpers.examplesDir() + "/AdvancedMCPExample/main.swift"
    }

    // MARK: - AC6: Package.swift executableTarget Configured

    func testPackageSwiftContainsAdvancedMCPExampleTarget() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("AdvancedMCPExample"),
            "Package.swift should contain AdvancedMCPExample executable target"
        )
    }

    func testAdvancedMCPExampleTargetDependsOnOpenAgentSDK() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("AdvancedMCPExample"),
            "Package.swift should contain AdvancedMCPExample target before checking dependencies"
        )
        let targetRange = content.range(of: "AdvancedMCPExample")
        XCTAssertNotNil(targetRange, "Should find AdvancedMCPExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "AdvancedMCPExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testAdvancedMCPExampleTargetDependsOnMCPProduct() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("AdvancedMCPExample"),
            "Package.swift should contain AdvancedMCPExample target before checking MCP dependency"
        )
        let targetRange = content.range(of: "AdvancedMCPExample")
        XCTAssertNotNil(targetRange, "Should find AdvancedMCPExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("MCP"),
                    "AdvancedMCPExample target should depend on MCP product (like MCPIntegration)"
                )
            }
        }
    }

    func testAdvancedMCPExampleTargetSpecifiesCorrectPath() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("AdvancedMCPExample"),
            "Package.swift should contain AdvancedMCPExample target before checking path"
        )
        // Find the executableTarget block containing AdvancedMCPExample by searching
        // for the closing parenthesis of the .executableTarget() call
        let targetRange = content.range(of: "AdvancedMCPExample")
        XCTAssertNotNil(targetRange, "Should find AdvancedMCPExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            // Find the path parameter within the target block
            // Look for the matching closing paren of .executableTarget(
            // by counting open/close parens
            var depth = 0
            var blockEnd: String.Index?
            for (idx, char) in afterTarget.enumerated() {
                if char == "(" { depth += 1 }
                if char == ")" {
                    if depth == 0 {
                        blockEnd = afterTarget.index(afterTarget.startIndex, offsetBy: idx)
                        break
                    }
                    depth -= 1
                }
            }
            if let blockEnd {
                let blockSection = String(afterTarget[..<blockEnd])
                XCTAssertTrue(
                    blockSection.contains("Examples/AdvancedMCPExample"),
                    "AdvancedMCPExample target should specify path: 'Examples/AdvancedMCPExample'"
                )
            }
        }
    }

    // MARK: - AC1: AdvancedMCPExample Directory and File Exist, Compiles

    func testAdvancedMCPExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: DocumentationTestHelpers.examplesDir() + "/AdvancedMCPExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/AdvancedMCPExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/AdvancedMCPExample/ should be a directory")
    }

    func testAdvancedMCPExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/AdvancedMCPExample/main.swift should exist"
        )
    }

    func testAdvancedMCPExampleImportsOpenAgentSDK() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "AdvancedMCPExample should import OpenAgentSDK"
        )
    }

    func testAdvancedMCPExampleImportsFoundation() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import Foundation"),
            "AdvancedMCPExample should import Foundation for ProcessInfo"
        )
    }

    func testAdvancedMCPExampleImportsMCP() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import MCP"),
            "AdvancedMCPExample should import MCP (required for InProcessMCPServer)"
        )
    }

    // MARK: - AC2: Demonstrates defineTool() Creating Custom Tools with Codable Input

    func testAdvancedMCPExampleUsesDefineTool() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("defineTool("),
            "AdvancedMCPExample should use defineTool() to create custom tools"
        )
    }

    func testAdvancedMCPExampleDefinesAtLeastTwoCustomTools() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let defineToolCount = content.components(separatedBy: "defineTool(").count - 1
        XCTAssertGreaterThanOrEqual(
            defineToolCount, 2,
            "AdvancedMCPExample should define at least 2 custom tools using defineTool()"
        )
    }

    func testAdvancedMCPExampleUsesCodableInputStructs() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should define Codable input structs for tools
        XCTAssertTrue(
            content.contains("Codable"),
            "AdvancedMCPExample should define Codable input structs for tool inputs"
        )
    }

    func testAdvancedMCPExampleDefinesToolWithJSONSchema() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Tool definitions should include inputSchema with JSON Schema
        let hasSchema = content.contains("\"type\": \"object\"") ||
            content.contains("\"type\":\"object\"")
        XCTAssertTrue(
            hasSchema,
            "AdvancedMCPExample should define tools with JSON Schema inputSchema"
        )
    }

    func testAdvancedMCPExampleUsesToolExecuteResultVariant() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // At least one tool should use the ToolExecuteResult variant (for error handling demo)
        XCTAssertTrue(
            content.contains("ToolExecuteResult"),
            "AdvancedMCPExample should use the ToolExecuteResult variant of defineTool for at least one tool"
        )
    }

    // MARK: - AC3: Demonstrates InProcessMCPServer Wrapping Tools

    func testAdvancedMCPExampleUsesInProcessMCPServer() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("InProcessMCPServer("),
            "AdvancedMCPExample should use InProcessMCPServer to wrap custom tools"
        )
    }

    func testAdvancedMCPExampleServerNameDoesNotContainDoubleUnderscore() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Extract InProcessMCPServer name parameter and verify no "__"
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("InProcessMCPServer(") {
                // Check if name parameter is on this line or nearby
                if trimmed.contains("name:") {
                    XCTAssertFalse(
                        trimmed.contains("\"") && trimmed.contains("__"),
                        "InProcessMCPServer name should not contain '__' (double underscore)"
                    )
                }
            }
        }
    }

    func testAdvancedMCPExamplePassesToolsToInProcessMCPServer() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // InProcessMCPServer init takes tools: [ToolProtocol]
        let hasServerWithTools = content.contains("InProcessMCPServer(") &&
            content.contains("tools:")
        XCTAssertTrue(
            hasServerWithTools,
            "AdvancedMCPExample should pass tools array to InProcessMCPServer"
        )
    }

    func testAdvancedMCPExampleUsesAsConfig() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("asConfig()"),
            "AdvancedMCPExample should use asConfig() to generate SDK configuration from InProcessMCPServer"
        )
    }

    func testAdvancedMCPExampleUsesAwaitForAsConfig() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // asConfig() is on an actor, so it requires await
        XCTAssertTrue(
            content.contains("await") && content.contains("asConfig()"),
            "AdvancedMCPExample should use 'await' when calling asConfig() (InProcessMCPServer is an actor)"
        )
    }

    // MARK: - AC4: Agent Connects via mcpServers Configuration

    func testAdvancedMCPExampleUsesAgentOptionsWithMcpServers() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("mcpServers:"),
            "AdvancedMCPExample should pass mcpServers: parameter in AgentOptions"
        )
    }

    func testAdvancedMCPExampleMcpServersUsesSDKConfig() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // The mcpServers value should be derived from asConfig() result
        XCTAssertTrue(
            content.contains("McpServerConfig") || content.contains("asConfig()"),
            "AdvancedMCPExample should use McpServerConfig (from asConfig()) for mcpServers"
        )
    }

    func testAdvancedMCPExampleUsesBypassPermissions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".bypassPermissions"),
            "AdvancedMCPExample should use .bypassPermissions to avoid permission prompts"
        )
    }

    func testAdvancedMCPExampleUsesCreateAgent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("createAgent("),
            "AdvancedMCPExample should use createAgent() factory function"
        )
    }

    func testAdvancedMCPExampleUsesAgentPrompt() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("agent.prompt("),
            "AdvancedMCPExample should use agent.prompt() to send queries"
        )
    }

    func testAdvancedMCPExampleUsesAwaitForPrompt() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("await agent.prompt("),
            "AdvancedMCPExample should use 'await agent.prompt()' — the blocking async API"
        )
    }

    // MARK: - AC5: Demonstrates Tool Error Handling

    func testAdvancedMCPExampleHasErrorHandlingTool() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should have at least one tool that can return an error (using ToolExecuteResult)
        // This tool should set isError: true under certain conditions
        XCTAssertTrue(
            content.contains("isError: true") || content.contains("isError:true"),
            "AdvancedMCPExample should have a tool that returns isError: true for error handling demo"
        )
    }

    func testAdvancedMCPExampleCreatesToolExecuteResultWithError() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // ToolExecuteResult(content: "...", isError: true) should appear
        XCTAssertTrue(
            content.contains("ToolExecuteResult(content:") && content.contains("isError:"),
            "AdvancedMCPExample should construct ToolExecuteResult with isError field"
        )
    }

    func testAdvancedMCPExampleDemonstratesErrorHandling() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should have a section/part that demonstrates error handling
        let hasErrorSection = content.contains("Part 4") ||
            content.contains("error") ||
            content.contains("Error") ||
            content.contains("错误")
        XCTAssertTrue(
            hasErrorSection,
            "AdvancedMCPExample should have an error handling demonstration section"
        )
    }

    // MARK: - AC7: Uses Actual Public API Signatures

    func testAdvancedMCPExampleAgentOptionsUsesRealParameterNames() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        if content.contains("AgentOptions(") {
            let validParams = [
                "apiKey:", "model:", "systemPrompt:", "maxTurns:",
                "permissionMode:", "tools:", "mcpServers:"
            ]
            var foundParams = 0
            for param in validParams {
                if content.contains(param) {
                    foundParams += 1
                }
            }
            XCTAssertGreaterThanOrEqual(
                foundParams, 4,
                "AdvancedMCPExample AgentOptions should use at least 4 real parameter names"
            )
        }
    }

    func testAdvancedMCPExampleUsesCreateAgentWithOptions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("createAgent(options:") || content.contains("createAgent(options: "),
            "AdvancedMCPExample should use createAgent(options: AgentOptions(...))"
        )
    }

    func testAdvancedMCPExampleQueryResultMatchesSourceType() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // QueryResult properties should match source: text, usage, numTurns, durationMs, status, totalCostUsd
        let requiredProperties = ["text", "numTurns", "durationMs", "totalCostUsd"]
        for prop in requiredProperties {
            XCTAssertTrue(
                content.contains(prop),
                "AdvancedMCPExample should access QueryResult property '\(prop)' matching source type"
            )
        }
    }

    func testAdvancedMCPExampleDefineToolSignatureMatchesSource() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // defineTool should use: name:, description:, inputSchema:, and execute closure
        // The name parameter should be present
        let hasNameParam = content.contains("name:") && content.contains("description:")
        XCTAssertTrue(
            hasNameParam,
            "AdvancedMCPExample defineTool calls should use name: and description: parameters"
        )
    }

    func testAdvancedMCPExampleInProcessMCPServerInitMatchesSource() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // InProcessMCPServer init: name:, version:, tools:, cwd:
        let hasInitParams = content.contains("InProcessMCPServer(") &&
            (content.contains("version:") || content.contains("tools:"))
        XCTAssertTrue(
            hasInitParams,
            "AdvancedMCPExample should use InProcessMCPServer init matching source signature (name:, version:, tools:, cwd:)"
        )
    }

    // MARK: - AC8: Clear Comments and No Exposed Keys

    func testAdvancedMCPExampleHasTopLevelDescriptionComment() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "AdvancedMCPExample should start with a descriptive comment block"
        )
    }

    func testAdvancedMCPExampleHasMultipleInlineComments() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 5,
            "AdvancedMCPExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testAdvancedMCPExampleDoesNotExposeRealAPIKeys() throws {
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
                        "AdvancedMCPExample should not contain a real-looking API key"
                    )
                }
            }
        }
    }

    func testAdvancedMCPExampleUsesPlaceholderOrEnvVarForAPIKey() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        if content.contains("apiKey:") {
            let usesPlaceholder = content.contains("sk-...") || content.contains("sk-xxx")
            let usesEnvVar = content.contains("ProcessInfo.processInfo.environment") ||
                content.contains("ANTHROPIC_API_KEY")
            XCTAssertTrue(
                usesPlaceholder || usesEnvVar,
                "AdvancedMCPExample should use 'sk-...' placeholder or environment variable for apiKey"
            )
        }
    }

    func testAdvancedMCPExampleDoesNotUseForceUnwrap() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            // Check for try!
            XCTAssertFalse(
                trimmed.contains("try!"),
                "AdvancedMCPExample should not use 'try!' force-try"
            )
        }
    }

    // MARK: - Code Structure (MARK Sections)

    func testAdvancedMCPExampleHasMarkSectionsForParts() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should have at least Part 1 (custom tools) and Part 2 (InProcessMCPServer) sections
        let hasPart1 = content.contains("Part 1") || content.contains("自定义工具") || content.contains("Custom")
        let hasPart2 = content.contains("Part 2") || content.contains("InProcessMCPServer") || content.contains("服务器")
        let hasPart3 = content.contains("Part 3") || content.contains("Agent") || content.contains("agent")
        XCTAssertTrue(
            hasPart1,
            "AdvancedMCPExample should have a Part 1 section for custom tool creation"
        )
        XCTAssertTrue(
            hasPart2,
            "AdvancedMCPExample should have a Part 2 section for InProcessMCPServer"
        )
        XCTAssertTrue(
            hasPart3,
            "AdvancedMCPExample should have a Part 3 section for Agent integration"
        )
    }
}

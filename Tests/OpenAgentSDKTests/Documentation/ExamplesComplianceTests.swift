import XCTest
import Foundation

// MARK: - ATDD Tests for Story 9-3: Runnable Code Examples
// TDD RED PHASE: These tests will FAIL until the Examples/ directory and
// all 5 runnable code examples are created.

final class ExamplesComplianceTests: XCTestCase {

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

    private func examplePath(_ name: String) -> String {
        return examplesDir() + "/" + name + "/main.swift"
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

    // MARK: - AC1: BasicAgent Example Compiles and Runs

    func testBasicAgentDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: examplesDir() + "/BasicAgent", isDirectory: &isDir)
        XCTAssertTrue(exists, "Examples/BasicAgent/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/BasicAgent/ should be a directory")
    }

    func testBasicAgentMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath("BasicAgent")),
            "Examples/BasicAgent/main.swift should exist"
        )
    }

    func testBasicAgentUsesCreateAgent() {
        guard let content = fileContent(examplePath("BasicAgent")) else {
            XCTFail("Examples/BasicAgent/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent("),
            "BasicAgent example should use createAgent() factory function"
        )
    }

    func testBasicAgentUsesBlockingPrompt() {
        guard let content = fileContent(examplePath("BasicAgent")) else {
            XCTFail("Examples/BasicAgent/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("agent.prompt("),
            "BasicAgent example should use agent.prompt() for blocking query"
        )
    }

    func testBasicAgentShowsQueryResultProperties() {
        guard let content = fileContent(examplePath("BasicAgent")) else {
            XCTFail("Examples/BasicAgent/main.swift should be readable")
            return
        }
        // Should demonstrate at least text property on QueryResult
        let hasResultProperty = content.contains(".text") || content.contains("result.text")
        XCTAssertTrue(
            hasResultProperty,
            "BasicAgent example should demonstrate QueryResult properties (e.g., .text)"
        )
    }

    func testBasicAgentImportsOpenAgentSDK() {
        guard let content = fileContent(examplePath("BasicAgent")) else {
            XCTFail("Examples/BasicAgent/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "BasicAgent example should import OpenAgentSDK"
        )
    }

    // MARK: - AC2: StreamingAgent Example Compiles and Runs

    func testStreamingAgentDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: examplesDir() + "/StreamingAgent", isDirectory: &isDir)
        XCTAssertTrue(exists, "Examples/StreamingAgent/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/StreamingAgent/ should be a directory")
    }

    func testStreamingAgentMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath("StreamingAgent")),
            "Examples/StreamingAgent/main.swift should exist"
        )
    }

    func testStreamingAgentUsesAsyncStream() {
        guard let content = fileContent(examplePath("StreamingAgent")) else {
            XCTFail("Examples/StreamingAgent/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("for await") && content.contains("agent.stream("),
            "StreamingAgent example should use 'for await ... in agent.stream(...)' pattern"
        )
    }

    func testStreamingAgentShowsSDKMessagePatternMatching() {
        guard let content = fileContent(examplePath("StreamingAgent")) else {
            XCTFail("Examples/StreamingAgent/main.swift should be readable")
            return
        }
        // Should demonstrate at least .partialMessage and .result pattern matching
        let hasPartialMessage = content.contains(".partialMessage")
        let hasResult = content.contains(".result(")
        XCTAssertTrue(
            hasPartialMessage,
            "StreamingAgent example should handle .partialMessage case"
        )
        XCTAssertTrue(
            hasResult,
            "StreamingAgent example should handle .result case"
        )
    }

    func testStreamingAgentShowsToolUseEvents() {
        guard let content = fileContent(examplePath("StreamingAgent")) else {
            XCTFail("Examples/StreamingAgent/main.swift should be readable")
            return
        }
        // Should demonstrate .toolUse and .toolResult pattern matching
        let hasToolUse = content.contains(".toolUse")
        let hasToolResult = content.contains(".toolResult")
        XCTAssertTrue(
            hasToolUse,
            "StreamingAgent example should handle .toolUse case"
        )
        XCTAssertTrue(
            hasToolResult,
            "StreamingAgent example should handle .toolResult case"
        )
    }

    // MARK: - AC3: CustomTools Example Compiles and Runs

    func testCustomToolsDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: examplesDir() + "/CustomTools", isDirectory: &isDir)
        XCTAssertTrue(exists, "Examples/CustomTools/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/CustomTools/ should be a directory")
    }

    func testCustomToolsMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath("CustomTools")),
            "Examples/CustomTools/main.swift should exist"
        )
    }

    func testCustomToolsUsesDefineTool() {
        guard let content = fileContent(examplePath("CustomTools")) else {
            XCTFail("Examples/CustomTools/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("defineTool("),
            "CustomTools example should use defineTool() function"
        )
    }

    func testCustomToolsDefinesCodableInputStruct() {
        guard let content = fileContent(examplePath("CustomTools")) else {
            XCTFail("Examples/CustomTools/main.swift should be readable")
            return
        }
        // Should define a Codable struct for tool input
        let hasCodableStruct = content.contains("Codable") && content.contains("struct")
        XCTAssertTrue(
            hasCodableStruct,
            "CustomTools example should define a Codable struct for tool input"
        )
    }

    func testCustomToolsDefinesJSONSchema() {
        guard let content = fileContent(examplePath("CustomTools")) else {
            XCTFail("Examples/CustomTools/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("inputSchema:"),
            "CustomTools example should define inputSchema for custom tools"
        )
    }

    func testCustomToolsUsesToolExecuteResult() {
        guard let content = fileContent(examplePath("CustomTools")) else {
            XCTFail("Examples/CustomTools/main.swift should be readable")
            return
        }
        // At least one tool should use ToolExecuteResult return type
        XCTAssertTrue(
            content.contains("ToolExecuteResult"),
            "CustomTools example should demonstrate ToolExecuteResult return type"
        )
    }

    // MARK: - AC4: MCPIntegration Example Compiles and Runs

    func testMCPIntegrationDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: examplesDir() + "/MCPIntegration", isDirectory: &isDir)
        XCTAssertTrue(exists, "Examples/MCPIntegration/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/MCPIntegration/ should be a directory")
    }

    func testMCPIntegrationMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath("MCPIntegration")),
            "Examples/MCPIntegration/main.swift should exist"
        )
    }

    func testMCPIntegrationUsesStdioConfig() {
        guard let content = fileContent(examplePath("MCPIntegration")) else {
            XCTFail("Examples/MCPIntegration/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("McpServerConfig") && content.contains(".stdio("),
            "MCPIntegration example should demonstrate McpServerConfig.stdio() configuration"
        )
        XCTAssertTrue(
            content.contains("McpStdioConfig"),
            "MCPIntegration example should use McpStdioConfig"
        )
    }

    func testMCPIntegrationUsesInProcessMCPServer() {
        guard let content = fileContent(examplePath("MCPIntegration")) else {
            XCTFail("Examples/MCPIntegration/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("InProcessMCPServer"),
            "MCPIntegration example should demonstrate InProcessMCPServer"
        )
        XCTAssertTrue(
            content.contains("McpSdkServerConfig") && content.contains(".sdk("),
            "MCPIntegration example should demonstrate McpServerConfig.sdk() with McpSdkServerConfig"
        )
    }

    func testMCPIntegrationUsesMcpServersInOptions() {
        guard let content = fileContent(examplePath("MCPIntegration")) else {
            XCTFail("Examples/MCPIntegration/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("mcpServers:"),
            "MCPIntegration example should use mcpServers parameter in AgentOptions"
        )
    }

    // MARK: - AC5: SessionsAndHooks Example Compiles and Runs

    func testSessionsAndHooksDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: examplesDir() + "/SessionsAndHooks", isDirectory: &isDir)
        XCTAssertTrue(exists, "Examples/SessionsAndHooks/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/SessionsAndHooks/ should be a directory")
    }

    func testSessionsAndHooksMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath("SessionsAndHooks")),
            "Examples/SessionsAndHooks/main.swift should exist"
        )
    }

    func testSessionsAndHooksUsesSessionStore() {
        guard let content = fileContent(examplePath("SessionsAndHooks")) else {
            XCTFail("Examples/SessionsAndHooks/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("SessionStore"),
            "SessionsAndHooks example should use SessionStore"
        )
        // Should show save or load operations
        let hasSaveOrLoad = content.contains("sessionStore.save(") ||
            content.contains("sessionStore.load(") ||
            content.contains(".save(") ||
            content.contains(".load(")
        XCTAssertTrue(
            hasSaveOrLoad,
            "SessionsAndHooks example should demonstrate SessionStore.save() or .load()"
        )
    }

    func testSessionsAndHooksUsesHookRegistry() {
        guard let content = fileContent(examplePath("SessionsAndHooks")) else {
            XCTFail("Examples/SessionsAndHooks/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("HookRegistry"),
            "SessionsAndHooks example should use HookRegistry"
        )
        XCTAssertTrue(
            content.contains("hookRegistry.register(") || content.contains(".register("),
            "SessionsAndHooks example should demonstrate HookRegistry.register()"
        )
    }

    func testSessionsAndHooksShowsHookDefinition() {
        guard let content = fileContent(examplePath("SessionsAndHooks")) else {
            XCTFail("Examples/SessionsAndHooks/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("HookDefinition"),
            "SessionsAndHooks example should show HookDefinition usage"
        )
    }

    // MARK: - AC6: All Examples Use Actual Public API

    func testAllExamplesImportOpenAgentSDK() {
        let examples = ["BasicAgent", "StreamingAgent", "CustomTools", "MCPIntegration", "SessionsAndHooks"]
        for name in examples {
            guard let content = fileContent(examplePath(name)) else {
                XCTFail("Examples/\(name)/main.swift should be readable")
                continue
            }
            XCTAssertTrue(
                content.contains("import OpenAgentSDK"),
                "\(name) example should import OpenAgentSDK"
            )
        }
    }

    func testAllExamplesUseAgentOptionsCorrectly() {
        // All examples that create agents should use AgentOptions with real parameter names
        let examplesUsingAgent = ["BasicAgent", "StreamingAgent", "CustomTools", "MCPIntegration", "SessionsAndHooks"]
        for name in examplesUsingAgent {
            guard let content = fileContent(examplePath(name)) else {
                XCTFail("Examples/\(name)/main.swift should be readable")
                continue
            }
            if content.contains("AgentOptions(") {
                // If AgentOptions is used, it should use real parameter names
                let validParams = [
                    "apiKey:", "model:", "systemPrompt:", "maxTurns:",
                    "permissionMode:", "tools:", "provider:", "baseURL:",
                    "maxBudgetUsd:", "mcpServers:", "sessionStore:", "sessionId:",
                    "hookRegistry:"
                ]
                var foundParams = 0
                for param in validParams {
                    if content.contains(param) {
                        foundParams += 1
                    }
                }
                XCTAssertGreaterThanOrEqual(
                    foundParams, 1,
                    "\(name) AgentOptions should use at least one real parameter name"
                )
            }
        }
    }

    func testAllExamplesUseCreateAgentFunction() {
        let examplesUsingAgent = ["BasicAgent", "StreamingAgent", "CustomTools", "MCPIntegration", "SessionsAndHooks"]
        for name in examplesUsingAgent {
            guard let content = fileContent(examplePath(name)) else {
                XCTFail("Examples/\(name)/main.swift should be readable")
                continue
            }
            XCTAssertTrue(
                content.contains("createAgent("),
                "\(name) example should use createAgent() function"
            )
        }
    }

    func testDefineToolSignatureMatchesSource() {
        guard let content = fileContent(examplePath("CustomTools")) else {
            XCTFail("Examples/CustomTools/main.swift should be readable")
            return
        }
        // defineTool should use the real parameter names: name:, description:, inputSchema:
        XCTAssertTrue(
            content.contains("name:") && content.contains("description:") && content.contains("inputSchema:"),
            "CustomTools defineTool call should use real parameter names (name:, description:, inputSchema:)"
        )
    }

    func testSDKMessageCasesMatchSource() {
        guard let content = fileContent(examplePath("StreamingAgent")) else {
            XCTFail("Examples/StreamingAgent/main.swift should be readable")
            return
        }
        // SDKMessage cases must match the actual enum cases from SDKMessage.swift
        let requiredCases = [".assistant", ".toolUse", ".toolResult", ".result", ".partialMessage"]
        for caseName in requiredCases {
            XCTAssertTrue(
                content.contains(caseName),
                "StreamingAgent example should handle SDKMessage case \(caseName)"
            )
        }
    }

    func testMCPConfigTypesMatchSource() {
        guard let content = fileContent(examplePath("MCPIntegration")) else {
            XCTFail("Examples/MCPIntegration/main.swift should be readable")
            return
        }
        // McpStdioConfig init uses (command:, args:)
        XCTAssertTrue(
            content.contains("command:"),
            "MCPIntegration should use McpStdioConfig(command:...) with real parameter name"
        )
        // McpSdkServerConfig init uses (name:, version:, server:)
        XCTAssertTrue(
            content.contains("version:"),
            "MCPIntegration should use McpSdkServerConfig(name:, version:, server:...) with real parameter names"
        )
    }

    func testHookTypesMatchSource() {
        guard let content = fileContent(examplePath("SessionsAndHooks")) else {
            XCTFail("Examples/SessionsAndHooks/main.swift should be readable")
            return
        }
        // HookDefinition init uses (command:, handler:, matcher:, timeout:)
        // At minimum should have handler
        XCTAssertTrue(
            content.contains("handler:"),
            "SessionsAndHooks should use HookDefinition with handler: parameter"
        )
    }

    // MARK: - AC7: Each Example Has Clear Comments

    func testAllExamplesHaveTopLevelDescription() {
        let examples = ["BasicAgent", "StreamingAgent", "CustomTools", "MCPIntegration", "SessionsAndHooks"]
        for name in examples {
            guard let content = fileContent(examplePath(name)) else {
                XCTFail("Examples/\(name)/main.swift should be readable")
                continue
            }
            // File should start with a comment block describing its purpose
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertTrue(
                trimmed.hasPrefix("//"),
                "\(name) example should start with a descriptive comment"
            )
        }
    }

    func testAllExamplesHaveInlineComments() {
        let examples = ["BasicAgent", "StreamingAgent", "CustomTools", "MCPIntegration", "SessionsAndHooks"]
        for name in examples {
            guard let content = fileContent(examplePath(name)) else {
                XCTFail("Examples/\(name)/main.swift should be readable")
                continue
            }
            let commentLines = content.components(separatedBy: "\n")
                .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .count
            XCTAssertGreaterThan(
                commentLines, 3,
                "\(name) example should have multiple inline comments (found \(commentLines))"
            )
        }
    }

    // MARK: - AC8: Examples Do Not Expose Real API Keys

    func testNoExampleContainsRealAPIKeys() {
        let examples = ["BasicAgent", "StreamingAgent", "CustomTools", "MCPIntegration", "SessionsAndHooks"]
        for name in examples {
            guard let content = fileContent(examplePath(name)) else {
                XCTFail("Examples/\(name)/main.swift should be readable")
                continue
            }
            let lines = content.components(separatedBy: "\n")
            for line in lines {
                // If "sk-" appears, it must be a placeholder
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
                            "\(name) should not contain a real-looking API key (found 'sk-\(remainder.prefix(20))')"
                        )
                    }
                }
            }
        }
    }

    func testExamplesUsePlaceholderOrEnvVarForAPIKey() {
        let examples = ["BasicAgent", "StreamingAgent", "CustomTools", "MCPIntegration", "SessionsAndHooks"]
        for name in examples {
            guard let content = fileContent(examplePath(name)) else {
                XCTFail("Examples/\(name)/main.swift should be readable")
                continue
            }
            // If apiKey is specified, it should use placeholder or env var
            if content.contains("apiKey:") {
                let usesPlaceholder = content.contains("sk-...") || content.contains("sk-xxx")
                let usesEnvVar = content.contains("ProcessInfo.processInfo.environment") ||
                    content.contains("CODEANY_API_KEY")
                XCTAssertTrue(
                    usesPlaceholder || usesEnvVar,
                    "\(name) should use 'sk-...' placeholder or environment variable for apiKey"
                )
            }
        }
    }

    // MARK: - Package.swift Integration

    func testPackageSwiftContainsBasicAgentTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("BasicAgent"),
            "Package.swift should contain BasicAgent executable target"
        )
    }

    func testPackageSwiftContainsStreamingAgentTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("StreamingAgent"),
            "Package.swift should contain StreamingAgent executable target"
        )
    }

    func testPackageSwiftContainsCustomToolsTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("CustomTools"),
            "Package.swift should contain CustomTools executable target"
        )
    }

    func testPackageSwiftContainsMCPIntegrationTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("MCPIntegration"),
            "Package.swift should contain MCPIntegration executable target"
        )
    }

    func testPackageSwiftContainsSessionsAndHooksTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("SessionsAndHooks"),
            "Package.swift should contain SessionsAndHooks executable target"
        )
    }

    func testAllExampleTargetsDependOnOpenAgentSDK() {
        let content = packageSwiftContent()
        let targets = ["BasicAgent", "StreamingAgent", "CustomTools", "MCPIntegration", "SessionsAndHooks"]
        for target in targets {
            // Find the executableTarget definition for this example
            if content.contains(target) {
                // The target should have OpenAgentSDK as a dependency
                let targetRange = content.range(of: target)
                if let range = targetRange {
                    // Look for the dependencies list near the target name
                    let afterTarget = content[range.lowerBound...]
                    if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                        let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                        XCTAssertTrue(
                            depsSection.contains("OpenAgentSDK"),
                            "\(target) executable target should depend on OpenAgentSDK"
                        )
                    }
                }
            }
        }
    }

    func testMCPIntegrationTargetDependsOnMCP() {
        let content = packageSwiftContent()
        // MCPIntegration should import MCP for InProcessMCPServer
        if content.contains("MCPIntegration") {
            let targetRange = content.range(of: "MCPIntegration")
            if let range = targetRange {
                let afterTarget = content[range.lowerBound...]
                if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                    let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                    XCTAssertTrue(
                        depsSection.contains("MCP"),
                        "MCPIntegration executable target should depend on MCP product"
                    )
                }
            }
        }
    }
}

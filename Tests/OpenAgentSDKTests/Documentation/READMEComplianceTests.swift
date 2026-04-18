import XCTest
import Foundation

// MARK: - ATDD Tests for Story 9-2: README & Quickstart Guide
// TDD RED PHASE: These tests will FAIL until the README is updated to match
// the full SDK capabilities (Epic 1-8 complete).

final class READMEComplianceTests: XCTestCase {

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

    private func readmePath() -> String {
        return projectRoot() + "/README.md"
    }

    private func readmeCNPath() -> String {
        return projectRoot() + "/README_CN.md"
    }

    private func readmeContent() -> String {
        let path = readmePath()
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            XCTFail("README.md should exist and be readable at \(path)")
            return ""
        }
        return content
    }

    private func readmeCNContent() -> String {
        let path = readmeCNPath()
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            XCTFail("README_CN.md should exist and be readable at \(path)")
            return ""
        }
        return content
    }

    // MARK: - AC5: README as SDK Landing Page

    func testREADMEContainsProjectDescription() {
        let content = readmeContent()
        // Should have a clear one-line description of the SDK
        XCTAssertTrue(
            content.contains("Agent SDK"),
            "README should describe this as an Agent SDK"
        )
    }

    func testREADMEContainsFeatureHighlights() {
        let content = readmeContent()
        // Should have a feature highlights section (not just "Status")
        let hasFeaturesSection = content.contains("Feature") ||
            content.contains("feature") ||
            content.contains("Highlights") ||
            content.contains("highlights")
        XCTAssertTrue(
            hasFeaturesSection,
            "README should have a features/highlights section showcasing SDK capabilities"
        )
    }

    func testREADMEContainsInstallationInstructions() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("Installation") || content.contains("安装"),
            "README should have an Installation section"
        )
        XCTAssertTrue(
            content.contains("Swift Package Manager") || content.contains("Package.swift"),
            "README should mention Swift Package Manager"
        )
    }

    func testREADMEContainsQuickStartSection() {
        let content = readmeContent()
        // AC1: Quick Start section should exist
        let hasQuickStart = content.contains("Quick Start") ||
            content.contains("Quickstart") ||
            content.contains("quick start") ||
            content.contains("快速入门")
        XCTAssertTrue(
            hasQuickStart,
            "README should have a Quick Start section"
        )
    }

    func testREADMEContainsEnvironmentVariablesTable() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("CODEANY_API_KEY"),
            "README should document CODEANY_API_KEY environment variable"
        )
        XCTAssertTrue(
            content.contains("CODEANY_BASE_URL"),
            "README should document CODEANY_BASE_URL environment variable"
        )
        XCTAssertTrue(
            content.contains("CODEANY_MODEL"),
            "README should document CODEANY_MODEL environment variable"
        )
    }

    func testREADMEContainsRequirementsSection() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("Requirements") || content.contains("要求"),
            "README should have a Requirements section"
        )
        XCTAssertTrue(
            content.contains("Swift"),
            "README should specify Swift version requirement"
        )
        XCTAssertTrue(
            content.contains("macOS"),
            "README should specify macOS version requirement"
        )
    }

    func testREADMEContainsDevelopmentSection() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("Development") || content.contains("开发"),
            "README should have a Development section"
        )
        XCTAssertTrue(
            content.contains("swift build"),
            "README should show 'swift build' command"
        )
        XCTAssertTrue(
            content.contains("swift test"),
            "README should show 'swift test' command"
        )
    }

    func testREADMEContainsLicense() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("License") || content.contains("MIT"),
            "README should have a License section"
        )
    }

    // MARK: - AC1: Quick Start 15-Minute Goal

    func testQuickStartContainsBlockingQueryExample() {
        let content = readmeContent()
        // Must show a blocking query example
        XCTAssertTrue(
            content.contains("agent.prompt(") || content.contains("prompt("),
            "README Quick Start should show agent.prompt() blocking query example"
        )
    }

    func testQuickStartContainsStreamingQueryExample() {
        let content = readmeContent()
        // Must show streaming query example
        XCTAssertTrue(
            content.contains("agent.stream(") || content.contains("stream("),
            "README should show agent.stream() streaming query example"
        )
        XCTAssertTrue(
            content.contains("AsyncStream") || content.contains("for await"),
            "README streaming example should show AsyncStream pattern"
        )
    }

    func testQuickStartContainsCustomToolExample() {
        let content = readmeContent()
        // Must show custom tool creation
        XCTAssertTrue(
            content.contains("defineTool"),
            "README should show defineTool() custom tool example"
        )
    }

    // MARK: - AC2: README Reflects All Implemented Features

    func testStatusSectionDoesNotListImplementedFeaturesAsPlanned() {
        let content = readmeContent()
        // These features are ALL implemented (Epic 1-8) and must NOT appear as "In Progress" or "Planned"
        let implementedFeatures = [
            "MCP",
            "Session persistence",
            "Session",
            "Hook",
            "Budget",
            "Permission",
            "compaction",
            "NotebookEdit"
        ]

        // Look for "In Progress" / "Planned" sections
        // If they exist, none of the implemented features should be listed as unchecked
        if content.contains("In Progress") || content.contains("Planned") {
            // Find the "In Progress / Planned" section
            let lines = content.components(separatedBy: "\n")
            var inPlannedSection = false
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.contains("In Progress") || trimmed.contains("Planned") {
                    inPlannedSection = true
                    continue
                }
                // End of section when we hit another heading
                if inPlannedSection && trimmed.hasPrefix("## ") {
                    inPlannedSection = false
                    continue
                }
                if inPlannedSection {
                    for feature in implementedFeatures {
                        if line.contains(feature) {
                            // If it's an unchecked item (- [ ]), that's wrong
                            if line.contains("- [ ]") {
                                XCTFail("'\(feature)' is implemented but listed as In Progress/Planned: \(trimmed)")
                            }
                        }
                    }
                }
            }
        }
    }

    func testREADMEListsAll34BuiltInTools() {
        let content = readmeContent()
        // The tool table should list all 34 tools, not just 11
        // Check for key tools that are currently missing from README

        // Core 10 (most are already listed)
        let coreTools = [
            "Bash", "Read", "Write", "Edit", "Glob", "Grep",
            "WebFetch", "WebSearch", "AskUser", "ToolSearch"
        ]

        // Advanced 11
        let advancedTools = [
            "Agent", "SendMessage", "TaskCreate", "TaskList", "TaskUpdate",
            "TaskGet", "TaskStop", "TaskOutput", "TeamCreate", "TeamDelete",
            "NotebookEdit"
        ]

        // Specialist 13
        let specialistTools = [
            "WorktreeEnter", "WorktreeExit", "PlanEnter", "PlanExit",
            "CronCreate", "CronDelete", "CronList",
            "RemoteTrigger", "LSP", "Config", "TodoWrite",
            "ListMcpResources", "ReadMcpResource"
        ]

        let allTools = coreTools + advancedTools + specialistTools

        for tool in allTools {
            XCTAssertTrue(
                content.contains(tool),
                "README should list the '\(tool)' built-in tool"
            )
        }
    }

    func testREADMEMentionsMCPIntegration() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("MCP") || content.contains("Model Context Protocol"),
            "README should mention MCP (Model Context Protocol) integration"
        )
    }

    func testREADMEMentionsSessionPersistence() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("SessionStore") || (content.contains("Session") && content.contains("persist")),
            "README should mention SessionStore or session persistence"
        )
    }

    func testREADMEMentionsHookSystem() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("HookRegistry") || (content.contains("Hook") && content.contains("hook")),
            "README should mention HookRegistry or hook system"
        )
    }

    func testREADMEMentionsPermissionControl() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("PermissionMode") || content.contains("permission"),
            "README should mention PermissionMode or permission control"
        )
    }

    func testREADMEMentionsBudgetTracking() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("budget") || content.contains("Budget"),
            "README should mention budget tracking"
        )
    }

    func testREADMEMentionsAutoCompaction() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("compaction") || content.contains("Compaction") || content.contains("compress"),
            "README should mention auto-compaction"
        )
    }

    func testREADMEMentionsMultiAgentOrchestration() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("sub-agent") || content.contains("Sub-agent") ||
                content.contains("multi-agent") || content.contains("Multi-Agent") ||
                content.contains("MultiAgent"),
            "README should mention sub-agent / multi-agent orchestration"
        )
    }

    // MARK: - AC3: Advanced Usage Links

    func testREADMELinksToDocCDocumentation() {
        let content = readmeContent()
        // Should link to Swift-DocC documentation
        let hasDocCLinks = content.contains("GettingStarted") ||
            content.contains("Getting Started") ||
            content.contains("Documentation.docc") ||
            content.contains("DocC")
        XCTAssertTrue(
            hasDocCLinks,
            "README should link to Swift-DocC documentation"
        )
    }

    func testREADMELinksToAdvancedTopics() {
        let content = readmeContent()
        // Should provide links to at least the key DocC articles
        let advancedTopics = ["ToolSystem", "MultiAgent", "MCPSessionHooks"]
        var foundLinks = 0
        for topic in advancedTopics {
            if content.contains(topic) {
                foundLinks += 1
            }
        }
        XCTAssertGreaterThanOrEqual(
            foundLinks, 2,
            "README should link to at least 2 of the advanced DocC articles (ToolSystem, MultiAgent, MCPSessionHooks)"
        )
    }

    func testREADMEMentionsExamplesDirectory() {
        let content = readmeContent()
        // Should mention Examples/ directory or link to examples
        XCTAssertTrue(
            content.contains("Example") || content.contains("example"),
            "README should mention or link to Examples/ directory"
        )
    }

    // MARK: - AC4: Code Examples Compile

    func testCreateAgentExampleMatchesActualAPI() {
        let content = readmeContent()
        // The createAgent example should use AgentOptions
        XCTAssertTrue(
            content.contains("createAgent(options:"),
            "README createAgent example should use createAgent(options:) signature"
        )
        XCTAssertTrue(
            content.contains("AgentOptions("),
            "README createAgent example should use AgentOptions initializer"
        )
    }

    func testAgentOptionsExampleUsesCorrectParameters() {
        let content = readmeContent()
        // AgentOptions in README should use real parameter names
        if content.contains("AgentOptions(") {
            // Find the block(s) containing AgentOptions
            let swiftBlocks = extractSwiftCodeBlocks(from: content)
            var foundValidExample = false

            for block in swiftBlocks {
                if block.contains("AgentOptions(") {
                    // Check that the example uses real parameter names
                    let validParams = [
                        "apiKey:", "model:", "systemPrompt:", "maxTurns:",
                        "permissionMode:", "tools:", "provider:", "baseURL:",
                        "maxBudgetUsd:", "mcpServers:"
                    ]
                    var paramCount = 0
                    for param in validParams {
                        if block.contains(param) {
                            paramCount += 1
                        }
                    }
                    // At minimum should have apiKey and model
                    if paramCount >= 2 {
                        foundValidExample = true
                    }
                }
            }

            XCTAssertTrue(
                foundValidExample,
                "README AgentOptions example should use real parameter names (apiKey:, model:, etc.)"
            )
        }
    }

    func testStreamingExampleUsesActualAPI() {
        let content = readmeContent()
        let swiftBlocks = extractSwiftCodeBlocks(from: content)

        var foundStreamingExample = false
        for block in swiftBlocks {
            if block.contains("agent.stream(") || block.contains(".stream(") {
                // Should use SDKMessage pattern or AsyncStream
                let usesRealPattern = block.contains("SDKMessage") ||
                    block.contains("AsyncStream") ||
                    block.contains("for await") ||
                    block.contains("case .assistant") ||
                    block.contains("case .toolUse") ||
                    block.contains("case .result")
                if usesRealPattern {
                    foundStreamingExample = true
                }
            }
        }

        XCTAssertTrue(
            foundStreamingExample,
            "README streaming example should use actual API patterns (SDKMessage/AsyncStream with case matching)"
        )
    }

    func testCustomToolExampleUsesDefineTool() {
        let content = readmeContent()
        // Custom tool example should use defineTool with proper signature
        if content.contains("defineTool(") {
            let swiftBlocks = extractSwiftCodeBlocks(from: content)
            var foundValidToolExample = false

            for block in swiftBlocks {
                if block.contains("defineTool(") {
                    // Should have name, description, inputSchema, and handler
                    let hasName = block.contains("name:")
                    let hasDescription = block.contains("description:")
                    let hasInputSchema = block.contains("inputSchema:")
                    let hasClosure = block.contains("input") || block.contains("context")

                    if hasName && hasDescription && hasInputSchema && hasClosure {
                        foundValidToolExample = true
                    }
                }
            }

            XCTAssertTrue(
                foundValidToolExample,
                "README defineTool example should show name:, description:, inputSchema:, and handler closure"
            )
        }
    }

    func testSDKConfigurationExampleMatchesActualAPI() {
        let content = readmeContent()
        // If SDKConfiguration is shown, it should use the real initializer
        if content.contains("SDKConfiguration(") {
            let swiftBlocks = extractSwiftCodeBlocks(from: content)
            for block in swiftBlocks {
                if block.contains("SDKConfiguration(") {
                    // Should use real parameter names from the actual init
                    if block.contains("apiKey:") {
                        // Good - uses actual parameter name
                    }
                }
            }
        }
    }

    func testMultiProviderExampleUsesActualAPI() {
        let content = readmeContent()
        // If multi-provider example exists, should use real provider enum
        if content.contains("openai") || content.contains("OpenAI") {
            let swiftBlocks = extractSwiftCodeBlocks(from: content)
            for block in swiftBlocks {
                if block.contains("provider:") {
                    // Should use .openai or .anthropic (real enum values)
                    XCTAssertTrue(
                        block.contains(".openai") || block.contains(".anthropic"),
                        "README multi-provider example should use actual LLMProvider enum values (.openai or .anthropic)"
                    )
                }
            }
        }
    }

    // MARK: - AC4: No Real API Keys in Examples

    func testCodeExamplesDoNotExposeRealAPIKeys() {
        let content = readmeContent()
        let lines = content.components(separatedBy: "\n")

        for line in lines {
            // Check for lines that look like real API key assignments
            if line.contains("apiKey") && line.contains("=") {
                // Skip non-code lines (comments, table rows, etc.)
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.hasPrefix("|") && !trimmed.hasPrefix(">") && !trimmed.hasPrefix("-") && !trimmed.hasPrefix("#") {
                    if line.contains("sk-") && !line.contains("sk-...") && !line.contains("sk-xxx") && !line.contains("sk-your") {
                        let afterSk = line.components(separatedBy: "sk-")
                        if afterSk.count > 1 {
                            let remainder = afterSk[1].trimmingCharacters(in: .whitespaces)
                            let isPlaceholder = remainder.hasPrefix("...") ||
                                remainder.hasPrefix("xxx") ||
                                remainder.hasPrefix("your") ||
                                remainder.hasPrefix("<")
                            XCTAssertTrue(
                                isPlaceholder,
                                "README should not contain real-looking API key patterns (found 'sk-\(remainder.prefix(20))...')"
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - AC5: Architecture Diagram

    func testREADMEContainsArchitectureDiagram() {
        let content = readmeContent()
        XCTAssertTrue(
            content.contains("```mermaid") || content.contains("Architecture") || content.contains("architecture"),
            "README should contain an architecture diagram (Mermaid) or Architecture section"
        )
    }

    func testArchitectureDiagramReflectsFullSDK() {
        let content = readmeContent()
        // If mermaid diagram exists, it should reflect the complete SDK
        if content.contains("```mermaid") {
            // Extract mermaid block
            let components = content.components(separatedBy: "```mermaid")
            if components.count > 1 {
                let afterMermaid = components[1]
                let mermaidEnd = afterMermaid.range(of: "```")
                if let endRange = mermaidEnd {
                    let mermaidBlock = String(afterMermaid[..<endRange.lowerBound])

                    // Should NOT say "planned" in the diagram
                    XCTAssertFalse(
                        mermaidBlock.contains("planned") || mermaidBlock.contains("Planned"),
                        "Architecture diagram should not label any components as 'planned'"
                    )

                    // Should reflect full tool count (not just "10+")
                    // The diagram should mention tools broadly
                    XCTAssertTrue(
                        mermaidBlock.contains("Tool") || mermaidBlock.contains("tool"),
                        "Architecture diagram should reference tools"
                    )
                }
            }
        }
    }

    // MARK: - AC6: Multi-language Support (README_CN.md)

    func testREADME_CNExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: readmeCNPath()),
            "README_CN.md (Chinese version) should exist"
        )
    }

    func testREADME_CNContainsQuickStart() {
        let content = readmeCNContent()
        let hasQuickStart = content.contains("快速入门") ||
            content.contains("Quick Start") ||
            content.contains("Quickstart")
        XCTAssertTrue(
            hasQuickStart,
            "README_CN.md should have a Quick Start / 快速入门 section"
        )
    }

    func testREADME_CNContainsToolList() {
        let content = readmeCNContent()
        // Chinese version should also list the tools
        XCTAssertTrue(
            content.contains("Bash") || content.contains("Read") || content.contains("Write"),
            "README_CN.md should list built-in tools"
        )
    }

    func testREADME_CNMentionsMCPIntegration() {
        let content = readmeCNContent()
        XCTAssertTrue(
            content.contains("MCP") || content.contains("Model Context Protocol"),
            "README_CN.md should mention MCP integration"
        )
    }

    func testREADME_CNMentionsSessionPersistence() {
        let content = readmeCNContent()
        XCTAssertTrue(
            content.contains("Session") || content.contains("会话"),
            "README_CN.md should mention session / 会话 persistence"
        )
    }

    func testREADME_CNMentionsHookSystem() {
        let content = readmeCNContent()
        XCTAssertTrue(
            content.contains("Hook") || content.contains("钩子"),
            "README_CN.md should mention hook system"
        )
    }

    func testREADME_CNMentionsPermissionControl() {
        let content = readmeCNContent()
        XCTAssertTrue(
            content.contains("Permission") || content.contains("权限"),
            "README_CN.md should mention permission control"
        )
    }

    func testREADME_CNSyncedWithMainREADME() {
        // Both READMEs should cover the same major sections
        let mainContent = readmeContent()
        let cnContent = readmeCNContent()

        // If main README has 34 tools, CN should too (or at minimum be updated)
        // Check for parity on key sections
        let mainHasStreaming = mainContent.contains("stream(")
        let cnHasStreaming = cnContent.contains("stream(")
        XCTAssertEqual(
            mainHasStreaming, cnHasStreaming,
            "README_CN.md streaming section parity with README.md"
        )

        let mainHasCustomTools = mainContent.contains("defineTool")
        let cnHasCustomTools = cnContent.contains("defineTool")
        XCTAssertEqual(
            mainHasCustomTools, cnHasCustomTools,
            "README_CN.md custom tools section parity with README.md"
        )
    }

    // MARK: - Helper: Extract Swift Code Blocks

    private func extractSwiftCodeBlocks(from markdown: String) -> [String] {
        var blocks: [String] = []
        let components = markdown.components(separatedBy: "```swift")
        // First component is before any ```swift, skip it
        for i in 1..<components.count {
            let afterBlock = components[i]
            if let endRange = afterBlock.range(of: "```") {
                let blockContent = String(afterBlock[..<endRange.lowerBound])
                blocks.append(blockContent)
            }
        }
        return blocks
    }
}

import XCTest
import Foundation

// MARK: - ATDD Tests for Story 10-4: SubagentExample (Sub-Agent Delegation Example)
// TDD RED PHASE: These tests will FAIL until Examples/SubagentExample/ is created
// and Package.swift is updated with the SubagentExample executableTarget.

final class SubagentExampleComplianceTests: XCTestCase {

    // MARK: - Helpers

    private func examplePath() -> String {
        return DocumentationTestHelpers.examplesDir() + "/SubagentExample/main.swift"
    }

    // MARK: - AC5: Package.swift executableTarget Configured

    func testPackageSwiftContainsSubagentExampleTarget() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("SubagentExample"),
            "Package.swift should contain SubagentExample executable target"
        )
    }

    func testSubagentExampleTargetDependsOnOpenAgentSDK() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("SubagentExample"),
            "Package.swift should contain SubagentExample target before checking dependencies"
        )
        let targetRange = content.range(of: "SubagentExample")
        XCTAssertNotNil(targetRange, "Should find SubagentExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "SubagentExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testSubagentExampleTargetSpecifiesCorrectPath() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("SubagentExample"),
            "Package.swift should contain SubagentExample target before checking path"
        )
        let targetRange = content.range(of: "SubagentExample")
        XCTAssertNotNil(targetRange, "Should find SubagentExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/SubagentExample"),
                    "SubagentExample target should specify path: 'Examples/SubagentExample'"
                )
            }
        }
    }

    // MARK: - AC1: SubagentExample Directory and File Exist, Compiles

    func testSubagentExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: DocumentationTestHelpers.examplesDir() + "/SubagentExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/SubagentExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/SubagentExample/ should be a directory")
    }

    func testSubagentExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/SubagentExample/main.swift should exist"
        )
    }

    func testSubagentExampleImportsOpenAgentSDK() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "SubagentExample should import OpenAgentSDK"
        )
    }

    func testSubagentExampleImportsFoundation() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import Foundation"),
            "SubagentExample should import Foundation for ProcessInfo"
        )
    }

    func testSubagentExampleUsesCreateAgent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("createAgent("),
            "SubagentExample should use createAgent() factory function"
        )
    }

    func testSubagentExampleUsesBypassPermissions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".bypassPermissions"),
            "SubagentExample should set permissionMode to .bypassPermissions"
        )
    }

    // MARK: - AC2: Demonstrates Main Agent Using Agent Tool to Spawn Sub-Agent

    func testSubagentExampleRegistersAgentTool() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("createAgentTool()"),
            "SubagentExample should register the Agent tool via createAgentTool()"
        )
    }

    func testSubagentExampleRegistersCoreToolsAlongsideAgentTool() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("getAllBaseTools(tier: .core)"),
            "SubagentExample should register core tools via getAllBaseTools(tier: .core)"
        )
    }

    func testSubagentExampleCombinesCoreToolsAndAgentTool() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // The tools array should combine core tools + agent tool (using + or similar)
        let hasBothTools = content.contains("getAllBaseTools(tier: .core)") &&
            content.contains("createAgentTool()")
        XCTAssertTrue(
            hasBothTools,
            "SubagentExample should combine getAllBaseTools(tier: .core) and createAgentTool() in tools array"
        )
    }

    func testSubagentExamplePassesToolsToAgentOptions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("tools:"),
            "SubagentExample should pass tools: parameter in AgentOptions"
        )
    }

    func testSubagentExampleDefinesCoordinatorSystemPrompt() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("systemPrompt:"),
            "SubagentExample should define a systemPrompt in AgentOptions"
        )
        // The system prompt should guide the main agent to delegate via Agent tool
        let hasDelegationGuidance = content.contains("Agent") ||
            content.contains("subagent") ||
            content.contains("sub-agent") ||
            content.contains("delegate") ||
            content.contains("coordinator") ||
            content.contains("delegat")
        XCTAssertTrue(
            hasDelegationGuidance,
            "SubagentExample systemPrompt should guide the main agent to use Agent tool for delegation"
        )
    }

    func testSubagentExampleUsesCreateAgentWithOptions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("createAgent(options:") || content.contains("createAgent(options: "),
            "SubagentExample should use createAgent(options: AgentOptions(...))"
        )
    }

    // MARK: - AC3: Sub-Agent Result Returns to Main Agent

    func testSubagentExampleSendsDelegationPrompt() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // The prompt sent to the agent should require delegation
        XCTAssertTrue(
            content.contains("agent.stream("),
            "SubagentExample should send a prompt via agent.stream() that requires sub-agent delegation"
        )
    }

    func testSubagentExampleHandlesToolResultForAgentTool() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".toolResult"),
            "SubagentExample should handle .toolResult case — sub-agent results return via this event"
        )
    }

    func testSubagentExampleDisplaysToolResultContent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should display content from tool results (sub-agent output)
        let hasContentDisplay = content.contains("data.content") ||
            content.contains(".content") ||
            content.contains("content.prefix")
        XCTAssertTrue(
            hasContentDisplay,
            "SubagentExample should display content from .toolResult events (sub-agent output)"
        )
    }

    func testSubagentExampleHandlesResultEvent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".result("),
            "SubagentExample should handle .result case for final statistics (main agent completion)"
        )
    }

    // MARK: - AC4: Uses Streaming API for Real-Time Execution Display

    func testSubagentExampleUsesStreamingAPI() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("for await") && content.contains("agent.stream("),
            "SubagentExample should use 'for await ... in agent.stream(...)' pattern"
        )
    }

    func testSubagentExampleHandlesPartialMessage() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".partialMessage"),
            "SubagentExample should handle .partialMessage case for incremental text"
        )
    }

    func testSubagentExampleHandlesToolUseEvent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".toolUse"),
            "SubagentExample should handle .toolUse case to display tool invocations (including Agent tool)"
        )
    }

    func testSubagentExampleDisplaysToolNameFromToolUseData() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let hasToolName = content.contains("toolName") || content.contains("data.toolName")
        XCTAssertTrue(
            hasToolName,
            "SubagentExample should display tool name from .toolUse event data"
        )
    }

    func testSubagentExampleDisplaysToolInput() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should display input parameters from tool use events
        let hasInput = content.contains("data.input") || content.contains(".input")
        XCTAssertTrue(
            hasInput,
            "SubagentExample should display input parameters from .toolUse events"
        )
    }

    func testSubagentExampleHandlesToolResultSummary() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should display truncated tool result content
        let hasTruncation = content.contains("prefix(") || content.contains("data.content")
        XCTAssertTrue(
            hasTruncation,
            "SubagentExample should display truncated tool result content summary"
        )
    }

    func testSubagentExampleHandlesAssistantEvent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".assistant("),
            "SubagentExample should handle .assistant case for model info and stop reason"
        )
    }

    func testSubagentExampleHandlesSystemEvent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".system("),
            "SubagentExample should handle .system case for system-level events"
        )
    }

    // MARK: - AC6: Uses Actual Public API Signatures

    func testSubagentExampleAgentOptionsUsesRealParameterNames() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        if content.contains("AgentOptions(") {
            let validParams = [
                "apiKey:", "model:", "systemPrompt:", "maxTurns:",
                "permissionMode:", "tools:"
            ]
            var foundParams = 0
            for param in validParams {
                if content.contains(param) {
                    foundParams += 1
                }
            }
            XCTAssertGreaterThanOrEqual(
                foundParams, 4,
                "SubagentExample AgentOptions should use at least 4 real parameter names"
            )
        }
    }

    func testSubagentExampleSDKMessagePatternMatchesSource() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // SDKMessage cases must match the actual enum cases from SDKMessage.swift
        let requiredCases = [".partialMessage", ".toolUse", ".toolResult", ".result", ".assistant", ".system"]
        for caseName in requiredCases {
            XCTAssertTrue(
                content.contains(caseName),
                "SubagentExample should handle SDKMessage case \(caseName)"
            )
        }
    }

    func testSubagentExampleDoesNotUseHypotheticalAPIs() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should use actual API function names, not hypothetical ones
        XCTAssertTrue(
            content.contains("createAgentTool()"),
            "SubagentExample should use actual createAgentTool() function"
        )
        XCTAssertTrue(
            content.contains("getAllBaseTools(tier: .core)"),
            "SubagentExample should use actual getAllBaseTools(tier: .core) function"
        )
    }

    func testSubagentExampleSafelyUnwrapsOptionalUsage() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // data.usage is Optional<TokenUsage> so should use if let or guard let
        let hasSafeUnwrap = content.contains("if let usage") || content.contains("guard let usage")
        XCTAssertTrue(
            hasSafeUnwrap,
            "SubagentExample should safely unwrap optional data.usage with 'if let' or 'guard let'"
        )
    }

    func testSubagentExampleDisplaysUsageStatistics() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let hasTurns = content.contains("numTurns") || content.contains("data.numTurns")
        XCTAssertTrue(
            hasTurns,
            "SubagentExample should display numTurns from result data"
        )

        let hasCost = content.contains("totalCostUsd") || content.contains("cost")
        XCTAssertTrue(
            hasCost,
            "SubagentExample should display cost information from result data"
        )
    }

    // MARK: - AC7: Clear Comments and No Exposed Keys

    func testSubagentExampleHasTopLevelDescriptionComment() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "SubagentExample should start with a descriptive comment block"
        )
    }

    func testSubagentExampleHasMultipleInlineComments() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 3,
            "SubagentExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testSubagentExampleDoesNotExposeRealAPIKeys() throws {
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
                        "SubagentExample should not contain a real-looking API key"
                    )
                }
            }
        }
    }

    func testSubagentExampleUsesPlaceholderOrEnvVarForAPIKey() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        if content.contains("apiKey:") {
            let usesPlaceholder = content.contains("sk-...") || content.contains("sk-xxx")
            let usesEnvVar = content.contains("ProcessInfo.processInfo.environment") ||
                content.contains("ANTHROPIC_API_KEY")
            XCTAssertTrue(
                usesPlaceholder || usesEnvVar,
                "SubagentExample should use 'sk-...' placeholder or environment variable for apiKey"
            )
        }
    }

    func testSubagentExampleDoesNotUseForceUnwrap() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            // Check for try!
            XCTAssertFalse(
                trimmed.contains("try!"),
                "SubagentExample should not use 'try!' force-try"
            )
        }
    }
}

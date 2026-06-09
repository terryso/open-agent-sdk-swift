import XCTest
import Foundation

// MARK: - ATDD Tests for Story 15-8: OpenAICompatExample
// TDD RED PHASE: These tests will FAIL until Examples/OpenAICompatExample/ is created
// and Package.swift is updated with the OpenAICompatExample executableTarget.

final class OpenAICompatExampleComplianceTests: XCTestCase {

    // MARK: - Helpers

    private func examplePath() -> String {
        return DocumentationTestHelpers.examplesDir() + "/OpenAICompatExample/main.swift"
    }

    // MARK: - AC7: Package.swift executableTarget Configured

    func testPackageSwiftContainsOpenAICompatExampleTarget() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("OpenAICompatExample"),
            "Package.swift should contain OpenAICompatExample executable target"
        )
    }

    func testOpenAICompatExampleTargetDependsOnOpenAgentSDK() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("OpenAICompatExample"),
            "Package.swift should contain OpenAICompatExample target before checking dependencies"
        )
        let targetRange = content.range(of: "OpenAICompatExample")
        XCTAssertNotNil(targetRange, "Should find OpenAICompatExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "OpenAICompatExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testOpenAICompatExampleTargetSpecifiesCorrectPath() {
        let content = DocumentationTestHelpers.packageSwiftContent()
        XCTAssertTrue(
            content.contains("OpenAICompatExample"),
            "Package.swift should contain OpenAICompatExample target before checking path"
        )
        let targetRange = content.range(of: "OpenAICompatExample")
        XCTAssertNotNil(targetRange, "Should find OpenAICompatExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/OpenAICompatExample"),
                    "OpenAICompatExample target should specify path: 'Examples/OpenAICompatExample'"
                )
            }
        }
    }

    // MARK: - AC1: OpenAICompatExample Directory and File Existence

    func testOpenAICompatExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: DocumentationTestHelpers.examplesDir() + "/OpenAICompatExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/OpenAICompatExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/OpenAICompatExample/ should be a directory")
    }

    func testOpenAICompatExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/OpenAICompatExample/main.swift should exist"
        )
    }

    func testOpenAICompatExampleImportsOpenAgentSDK() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "OpenAICompatExample should import OpenAgentSDK"
        )
    }

    func testOpenAICompatExampleImportsFoundation() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("import Foundation"),
            "OpenAICompatExample should import Foundation"
        )
    }

    // MARK: - AC1: Code Quality

    func testOpenAICompatExampleHasTopLevelDescriptionComment() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "OpenAICompatExample should start with a descriptive comment block"
        )
    }

    func testOpenAICompatExampleHasMultipleInlineComments() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 5,
            "OpenAICompatExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testOpenAICompatExampleHasMarkSections() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let markCount = content.components(separatedBy: "MARK:").count - 1
        XCTAssertGreaterThanOrEqual(
            markCount, 4,
            "OpenAICompatExample should have at least 4 MARK sections (Part 1-4)"
        )
    }

    func testOpenAICompatExampleDoesNotUseForceUnwrap() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            XCTAssertFalse(
                trimmed.contains("try!"),
                "OpenAICompatExample should not use 'try!' force-try"
            )
        }
    }

    func testOpenAICompatExampleDoesNotExposeRealAPIKeys() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertFalse(
            content.contains("sk-ant-api03") || content.contains("sk-proj-"),
            "OpenAICompatExample should not contain real API keys"
        )
    }

    func testOpenAICompatExampleUsesLoadDotEnvPattern() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("loadDotEnv()"),
            "OpenAICompatExample should use loadDotEnv() helper pattern"
        )
    }

    func testOpenAICompatExampleUsesGetEnvPattern() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("getEnv("),
            "OpenAICompatExample should use getEnv() helper pattern for API key loading"
        )
    }

    func testOpenAICompatExampleUsesAssertions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("assert("),
            "OpenAICompatExample should use assert() for key validations"
        )
    }

    // MARK: - AC2: OpenAI Provider Configuration

    func testOpenAICompatExampleUsesOpenAIProvider() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".openai"),
            "OpenAICompatExample should use provider: .openai"
        )
    }

    func testOpenAICompatExampleConfiguresBaseURL() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("baseURL:"),
            "OpenAICompatExample should configure baseURL for the OpenAI-compatible endpoint"
        )
    }

    func testOpenAICompatExampleUsesCodeAnyEnvVars() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("CODEANY_API_KEY"),
            "OpenAICompatExample should use CODEANY_API_KEY environment variable"
        )
        XCTAssertTrue(
            content.contains("CODEANY_BASE_URL") || content.contains("CODEANY_MODEL"),
            "OpenAICompatExample should use CODEANY_BASE_URL or CODEANY_MODEL environment variable"
        )
    }

    func testOpenAICompatExampleDetectsUseOpenAIFlag() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("useOpenAI"),
            "OpenAICompatExample should define a useOpenAI flag based on CODEANY_API_KEY detection"
        )
    }

    // MARK: - AC3: Prompt with OpenAI Provider

    func testOpenAICompatExampleUsesCreateAgent() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("createAgent("),
            "OpenAICompatExample should create an Agent using createAgent()"
        )
    }

    func testOpenAICompatExampleUsesBypassPermissions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("bypassPermissions") || content.contains(".bypassPermissions"),
            "OpenAICompatExample should use permissionMode: .bypassPermissions"
        )
    }

    func testOpenAICompatExampleUsesPrompt() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".prompt(") || content.contains("agent.prompt("),
            "OpenAICompatExample should use agent.prompt() for a blocking query"
        )
    }

    func testOpenAICompatExampleUsesAwait() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("await"),
            "OpenAICompatExample should use await for async operations"
        )
    }

    func testOpenAICompatExamplePrintsResponseText() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".text"),
            "OpenAICompatExample should print response text from QueryResult"
        )
    }

    func testOpenAICompatExamplePrintsUsageStats() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("inputTokens") || content.contains("input_tokens"),
            "OpenAICompatExample should print input token usage"
        )
        XCTAssertTrue(
            content.contains("outputTokens") || content.contains("output_tokens"),
            "OpenAICompatExample should print output token usage"
        )
    }

    // MARK: - AC4: Streaming with OpenAI Provider

    func testOpenAICompatExampleUsesStream() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".stream(") || content.contains("agent.stream("),
            "OpenAICompatExample should use agent.stream() for streaming query"
        )
    }

    func testOpenAICompatExampleCollectsSDKMessageEvents() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let hasSDKMessage = content.contains("SDKMessage")
            || content.contains(".partialMessage")
            || content.contains(".result(")
        XCTAssertTrue(
            hasSDKMessage,
            "OpenAICompatExample should collect SDKMessage events (partialMessage, result) from stream"
        )
    }

    func testOpenAICompatExampleHandlesPartialMessage() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".partialMessage"),
            "OpenAICompatExample should handle .partialMessage case in stream"
        )
    }

    func testOpenAICompatExampleHandlesResultCase() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".result("),
            "OpenAICompatExample should handle .result case in stream"
        )
    }

    func testOpenAICompatExampleAssertsStreamingResponseNonEmpty() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Look for assert near stream-related code
        let streamSectionRange = content.range(of: "stream(")
        XCTAssertNotNil(streamSectionRange, "Should find stream( in example code")
        if let streamRange = streamSectionRange {
            let afterStream = content[streamRange.lowerBound...]
            let hasAssert = afterStream.contains("assert(")
            XCTAssertTrue(
                hasAssert,
                "OpenAICompatExample should assert that streaming response is non-empty"
            )
        }
    }

    // MARK: - AC5: Tool Use with OpenAI Provider

    func testOpenAICompatExampleUsesDefineTool() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("defineTool("),
            "OpenAICompatExample should use defineTool() to register a custom tool"
        )
    }

    func testOpenAICompatExampleDefinesCodableInputStruct() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        let hasCodableStruct = content.contains("Codable") && content.contains("struct")
        XCTAssertTrue(
            hasCodableStruct,
            "OpenAICompatExample should define a Codable struct for tool input"
        )
    }

    func testOpenAICompatExampleDefinesInputSchema() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("inputSchema:"),
            "OpenAICompatExample should define inputSchema for the custom tool"
        )
    }

    func testOpenAICompatExampleCreatesAgentWithTools() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("tools:"),
            "OpenAICompatExample should pass tools parameter to AgentOptions"
        )
    }

    func testOpenAICompatExampleTriggersToolCall() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // The example should have a prompt that triggers tool use and prints tool call details
        let hasToolCallPrint = content.contains("tool") && content.contains("Tool")
        XCTAssertTrue(
            hasToolCallPrint,
            "OpenAICompatExample should reference tool call details in output"
        )
    }

    // MARK: - AC6: Provider Comparison

    func testOpenAICompatExampleShowsAnthropicProviderConfig() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains(".anthropic"),
            "OpenAICompatExample should show Anthropic provider configuration for comparison"
        )
    }

    func testOpenAICompatExampleShowsBothProviderOptions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should demonstrate the side-by-side comparison of both providers
        XCTAssertTrue(
            content.contains(".openai") && content.contains(".anthropic"),
            "OpenAICompatExample should show both .openai and .anthropic provider configurations"
        )
    }

    // MARK: - AC1: Structure Validation

    func testOpenAICompatExampleHasFourParts() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        // Should have four distinct parts
        let partCount = content.components(separatedBy: "Part ").count - 1
            + content.components(separatedBy: "PART ").count - 1
        XCTAssertGreaterThanOrEqual(
            partCount, 4,
            "OpenAICompatExample should have at least 4 parts (Config, Prompt, Streaming, Tool Use)"
        )
    }

    func testOpenAICompatExampleUsesAgentOptions() throws {
        let content = try DocumentationTestHelpers.requireFileContent(examplePath())
        XCTAssertTrue(
            content.contains("AgentOptions("),
            "OpenAICompatExample should use AgentOptions to configure the agent"
        )
    }
}

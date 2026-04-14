import XCTest
import Foundation

// MARK: - ATDD Tests for Story 15-8: OpenAICompatExample
// TDD RED PHASE: These tests will FAIL until Examples/OpenAICompatExample/ is created
// and Package.swift is updated with the OpenAICompatExample executableTarget.

final class OpenAICompatExampleComplianceTests: XCTestCase {

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
        return examplesDir() + "/OpenAICompatExample/main.swift"
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

    func testPackageSwiftContainsOpenAICompatExampleTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("OpenAICompatExample"),
            "Package.swift should contain OpenAICompatExample executable target"
        )
    }

    func testOpenAICompatExampleTargetDependsOnOpenAgentSDK() {
        let content = packageSwiftContent()
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
        let content = packageSwiftContent()
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
            atPath: examplesDir() + "/OpenAICompatExample",
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

    func testOpenAICompatExampleImportsOpenAgentSDK() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "OpenAICompatExample should import OpenAgentSDK"
        )
    }

    func testOpenAICompatExampleImportsFoundation() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import Foundation"),
            "OpenAICompatExample should import Foundation"
        )
    }

    // MARK: - AC1: Code Quality

    func testOpenAICompatExampleHasTopLevelDescriptionComment() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "OpenAICompatExample should start with a descriptive comment block"
        )
    }

    func testOpenAICompatExampleHasMultipleInlineComments() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 5,
            "OpenAICompatExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testOpenAICompatExampleHasMarkSections() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        let markCount = content.components(separatedBy: "MARK:").count - 1
        XCTAssertGreaterThanOrEqual(
            markCount, 4,
            "OpenAICompatExample should have at least 4 MARK sections (Part 1-4)"
        )
    }

    func testOpenAICompatExampleDoesNotUseForceUnwrap() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
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

    func testOpenAICompatExampleDoesNotExposeRealAPIKeys() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertFalse(
            content.contains("sk-ant-api03") || content.contains("sk-proj-"),
            "OpenAICompatExample should not contain real API keys"
        )
    }

    func testOpenAICompatExampleUsesLoadDotEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("loadDotEnv()"),
            "OpenAICompatExample should use loadDotEnv() helper pattern"
        )
    }

    func testOpenAICompatExampleUsesGetEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("getEnv("),
            "OpenAICompatExample should use getEnv() helper pattern for API key loading"
        )
    }

    func testOpenAICompatExampleUsesAssertions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("assert("),
            "OpenAICompatExample should use assert() for key validations"
        )
    }

    // MARK: - AC2: OpenAI Provider Configuration

    func testOpenAICompatExampleUsesOpenAIProvider() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".openai"),
            "OpenAICompatExample should use provider: .openai"
        )
    }

    func testOpenAICompatExampleConfiguresBaseURL() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("baseURL:"),
            "OpenAICompatExample should configure baseURL for the OpenAI-compatible endpoint"
        )
    }

    func testOpenAICompatExampleUsesCodeAnyEnvVars() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("CODEANY_API_KEY"),
            "OpenAICompatExample should use CODEANY_API_KEY environment variable"
        )
        XCTAssertTrue(
            content.contains("CODEANY_BASE_URL") || content.contains("CODEANY_MODEL"),
            "OpenAICompatExample should use CODEANY_BASE_URL or CODEANY_MODEL environment variable"
        )
    }

    func testOpenAICompatExampleDetectsUseOpenAIFlag() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("useOpenAI"),
            "OpenAICompatExample should define a useOpenAI flag based on CODEANY_API_KEY detection"
        )
    }

    // MARK: - AC3: Prompt with OpenAI Provider

    func testOpenAICompatExampleUsesCreateAgent() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent("),
            "OpenAICompatExample should create an Agent using createAgent()"
        )
    }

    func testOpenAICompatExampleUsesBypassPermissions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("bypassPermissions") || content.contains(".bypassPermissions"),
            "OpenAICompatExample should use permissionMode: .bypassPermissions"
        )
    }

    func testOpenAICompatExampleUsesPrompt() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".prompt(") || content.contains("agent.prompt("),
            "OpenAICompatExample should use agent.prompt() for a blocking query"
        )
    }

    func testOpenAICompatExampleUsesAwait() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("await"),
            "OpenAICompatExample should use await for async operations"
        )
    }

    func testOpenAICompatExamplePrintsResponseText() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".text"),
            "OpenAICompatExample should print response text from QueryResult"
        )
    }

    func testOpenAICompatExamplePrintsUsageStats() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
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

    func testOpenAICompatExampleUsesStream() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".stream(") || content.contains("agent.stream("),
            "OpenAICompatExample should use agent.stream() for streaming query"
        )
    }

    func testOpenAICompatExampleCollectsSDKMessageEvents() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        let hasSDKMessage = content.contains("SDKMessage")
            || content.contains(".partialMessage")
            || content.contains(".result(")
        XCTAssertTrue(
            hasSDKMessage,
            "OpenAICompatExample should collect SDKMessage events (partialMessage, result) from stream"
        )
    }

    func testOpenAICompatExampleHandlesPartialMessage() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".partialMessage"),
            "OpenAICompatExample should handle .partialMessage case in stream"
        )
    }

    func testOpenAICompatExampleHandlesResultCase() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".result("),
            "OpenAICompatExample should handle .result case in stream"
        )
    }

    func testOpenAICompatExampleAssertsStreamingResponseNonEmpty() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
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

    func testOpenAICompatExampleUsesDefineTool() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("defineTool("),
            "OpenAICompatExample should use defineTool() to register a custom tool"
        )
    }

    func testOpenAICompatExampleDefinesCodableInputStruct() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        let hasCodableStruct = content.contains("Codable") && content.contains("struct")
        XCTAssertTrue(
            hasCodableStruct,
            "OpenAICompatExample should define a Codable struct for tool input"
        )
    }

    func testOpenAICompatExampleDefinesInputSchema() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("inputSchema:"),
            "OpenAICompatExample should define inputSchema for the custom tool"
        )
    }

    func testOpenAICompatExampleCreatesAgentWithTools() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("tools:"),
            "OpenAICompatExample should pass tools parameter to AgentOptions"
        )
    }

    func testOpenAICompatExampleTriggersToolCall() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        // The example should have a prompt that triggers tool use and prints tool call details
        let hasToolCallPrint = content.contains("tool") && content.contains("Tool")
        XCTAssertTrue(
            hasToolCallPrint,
            "OpenAICompatExample should reference tool call details in output"
        )
    }

    // MARK: - AC6: Provider Comparison

    func testOpenAICompatExampleShowsAnthropicProviderConfig() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".anthropic"),
            "OpenAICompatExample should show Anthropic provider configuration for comparison"
        )
    }

    func testOpenAICompatExampleShowsBothProviderOptions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        // Should demonstrate the side-by-side comparison of both providers
        XCTAssertTrue(
            content.contains(".openai") && content.contains(".anthropic"),
            "OpenAICompatExample should show both .openai and .anthropic provider configurations"
        )
    }

    // MARK: - AC1: Structure Validation

    func testOpenAICompatExampleHasFourParts() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        // Should have four distinct parts
        let partCount = content.components(separatedBy: "Part ").count - 1
            + content.components(separatedBy: "PART ").count - 1
        XCTAssertGreaterThanOrEqual(
            partCount, 4,
            "OpenAICompatExample should have at least 4 parts (Config, Prompt, Streaming, Tool Use)"
        )
    }

    func testOpenAICompatExampleUsesAgentOptions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/OpenAICompatExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("AgentOptions("),
            "OpenAICompatExample should use AgentOptions to configure the agent"
        )
    }
}

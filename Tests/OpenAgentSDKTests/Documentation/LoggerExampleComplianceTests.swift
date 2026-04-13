import XCTest
import Foundation

// MARK: - ATDD Tests for Story 15-3: LoggerExample
// TDD RED PHASE: These tests will FAIL until Examples/LoggerExample/ is created
// and Package.swift is updated with the LoggerExample executableTarget.

final class LoggerExampleComplianceTests: XCTestCase {

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
        return examplesDir() + "/LoggerExample/main.swift"
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

    // MARK: - AC9: Package.swift executableTarget Configured

    func testPackageSwiftContainsLoggerExampleTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("LoggerExample"),
            "Package.swift should contain LoggerExample executable target"
        )
    }

    func testLoggerExampleTargetDependsOnOpenAgentSDK() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("LoggerExample"),
            "Package.swift should contain LoggerExample target"
        )
        // Verify the target has OpenAgentSDK dependency
        let lines = content.components(separatedBy: "\n")
        var foundTarget = false
        for line in lines {
            if line.contains("LoggerExample") {
                foundTarget = true
            }
            if foundTarget && line.contains("dependencies:") && line.contains("OpenAgentSDK") {
                return // Pass
            }
            if foundTarget && line.contains(")") && !line.contains("LoggerExample") {
                break
            }
        }
        if foundTarget {
            // Also acceptable: dependency on separate line within the target block
            XCTAssertTrue(
                content.contains("LoggerExample") && content.contains("OpenAgentSDK"),
                "LoggerExample target should depend on OpenAgentSDK"
            )
        }
    }

    func testLoggerExampleTargetSpecifiesCorrectPath() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("Examples/LoggerExample"),
            "Package.swift LoggerExample target should specify path: \"Examples/LoggerExample\""
        )
    }

    // MARK: - AC1: LoggerExample Directory and File Existence

    func testLoggerExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: examplesDir() + "/LoggerExample", isDirectory: &isDir)
        XCTAssertTrue(exists, "Examples/LoggerExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/LoggerExample/ should be a directory")
    }

    func testLoggerExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/LoggerExample/main.swift should exist"
        )
    }

    func testLoggerExampleImportsOpenAgentSDK() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "LoggerExample should import OpenAgentSDK"
        )
    }

    func testLoggerExampleImportsFoundation() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import Foundation"),
            "LoggerExample should import Foundation"
        )
    }

    func testLoggerExampleHasTopLevelDescriptionComment() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        let hasDescription = content.contains("// LoggerExample") || content.contains("LoggerExample ")
        XCTAssertTrue(
            hasDescription,
            "LoggerExample should have a top-level comment describing the example"
        )
    }

    func testLoggerExampleHasMultipleInlineComments() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        let commentCount = content.components(separatedBy: "// ").count - 1
        XCTAssertGreaterThanOrEqual(
            commentCount, 10,
            "LoggerExample should have at least 10 inline comments for educational value"
        )
    }

    func testLoggerExampleHasMarkSections() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        let markCount = content.components(separatedBy: "MARK:").count - 1
        XCTAssertGreaterThanOrEqual(
            markCount, 3,
            "LoggerExample should have at least 3 MARK sections (Part 1, Part 2, Part 3)"
        )
    }

    // MARK: - AC10: Code Quality

    func testLoggerExampleDoesNotUseForceUnwrap() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        // Allow force unwrap only in string interpolation (e.g., "\(someVar!)")
        // Disallow standalone ! that isn't in string interpolation
        let lines = content.components(separatedBy: "\n")
        for (_, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comments and string interpolation
            if trimmed.hasPrefix("//") { continue }
            if trimmed.hasPrefix("/*") { continue }
            // Check for force unwrap (!) outside of string interpolation
            if trimmed.contains("!") && !trimmed.contains("\"") {
                // Could be a boolean negation or force unwrap - check more specifically
                let forceUnwrapPattern = try! NSRegularExpression(pattern: "\\w+!")
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                let matches = forceUnwrapPattern.matches(in: trimmed, range: range)
                for match in matches {
                    let matchStr = String(trimmed[Range(match.range, in: trimmed)!])
                    // Allow common non-force-unwrap patterns
                    if matchStr == "else" || matchStr.hasPrefix("//") { continue }
                    // This is likely a force unwrap - flag it
                    if !matchStr.contains(")") && !matchStr.contains("}") {
                        // Check it's not just "!" at end of condition
                        if trimmed.contains("!= ") { continue }
                    }
                }
            }
        }
        // Simple check: count occurrences of "!" that aren't "!=" or in comments
        let contentNoComments = content
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let forceUnwrapCount = contentNoComments
            .replacingOccurrences(of: "!=", with: "")
            .replacingOccurrences(of: "!!", with: "")
            .components(separatedBy: "!").count - 1
        XCTAssertLessThanOrEqual(
            forceUnwrapCount, 5,
            "LoggerExample should minimize force unwraps (found \(forceUnwrapCount)). Use optional binding instead."
        )
    }

    func testLoggerExampleDoesNotExposeRealAPIKeys() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertFalse(
            content.contains("sk-ant-api03") || content.contains("sk-proj-"),
            "LoggerExample should not contain real API keys"
        )
    }

    func testLoggerExampleUsesLoadDotEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("loadDotEnv()"),
            "LoggerExample should use loadDotEnv() helper for API key loading"
        )
    }

    func testLoggerExampleUsesGetEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("getEnv("),
            "LoggerExample should use getEnv() helper for environment variable access"
        )
    }

    // MARK: - AC2: Log Levels Demonstrated

    func testLoggerExampleDemonstratesAllLogLevels() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("LogLevel") || content.contains("logLevel"),
            "LoggerExample should reference LogLevel"
        )
    }

    func testLoggerExampleDemonstratesLogLevelNone() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".none"),
            "LoggerExample should demonstrate LogLevel.none"
        )
    }

    func testLoggerExampleDemonstratesLogLevelError() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".error"),
            "LoggerExample should demonstrate LogLevel.error"
        )
    }

    func testLoggerExampleDemonstratesLogLevelWarn() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".warn"),
            "LoggerExample should demonstrate LogLevel.warn"
        )
    }

    func testLoggerExampleDemonstratesLogLevelInfo() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".info"),
            "LoggerExample should demonstrate LogLevel.info"
        )
    }

    func testLoggerExampleDemonstratesLogLevelDebug() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".debug"),
            "LoggerExample should demonstrate LogLevel.debug"
        )
    }

    func testLoggerExampleDemonstratesLevelFiltering() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        // The example should show that higher log levels filter out lower level messages
        // Look for patterns like changing level and showing filtered output
        let hasLevelChange = content.contains("Logger.configure") || content.contains("Logger.shared")
        XCTAssertTrue(
            hasLevelChange,
            "LoggerExample should demonstrate level filtering by configuring different levels"
        )
    }

    func testLoggerExampleUsesLoggerConfigureStaticMethod() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("Logger.configure("),
            "LoggerExample should use Logger.configure(level:output:) static method"
        )
    }

    // MARK: - AC3: Console Output

    func testLoggerExampleUsesLogOutputConsole() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".console"),
            "LoggerExample should demonstrate LogOutput.console"
        )
    }

    // MARK: - AC4: File Output

    func testLoggerExampleUsesLogOutputFile() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".file("),
            "LoggerExample should demonstrate LogOutput.file(URL)"
        )
    }

    func testLoggerExampleCreatesTempFileForLogging() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        let hasTempDir = content.contains("temporaryDirectory") || content.contains("tmp") || content.contains("NSTemporaryDirectory")
        XCTAssertTrue(
            hasTempDir,
            "LoggerExample should use a temporary directory for file logging output"
        )
    }

    // MARK: - AC5: Custom Output

    func testLoggerExampleUsesLogOutputCustom() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".custom"),
            "LoggerExample should demonstrate LogOutput.custom closure"
        )
    }

    func testLoggerExampleDemonstratesCustomClosureCapture() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        // Should show capturing logs in a buffer via custom closure
        let hasBufferPattern = content.contains("buffer") || content.contains("append") || content.contains("captured")
        XCTAssertTrue(
            hasBufferPattern,
            "LoggerExample should demonstrate capturing log output in a custom closure"
        )
    }

    // MARK: - AC6: Structured JSON Format

    func testLoggerExampleDemonstratesStructuredJsonFormat() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        // Should reference the structured fields: timestamp, level, module, event, data
        let hasJsonReference = content.contains("JSON") || content.contains("json") || content.contains("timestamp") || content.contains("module")
        XCTAssertTrue(
            hasJsonReference,
            "LoggerExample should reference or demonstrate the structured JSON log format"
        )
    }

    func testLoggerExampleReferencesTimestamp() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("timestamp"),
            "LoggerExample should reference the timestamp field in structured logs"
        )
    }

    func testLoggerExampleReferencesModule() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("module"),
            "LoggerExample should reference the module field in structured logs"
        )
    }

    func testLoggerExampleReferencesEvent() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("event"),
            "LoggerExample should reference the event field in structured logs"
        )
    }

    // MARK: - AC7: Logger.reset() and outputCount

    func testLoggerExampleUsesLoggerReset() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        let resetCount = content.components(separatedBy: "Logger.reset()").count - 1
        XCTAssertGreaterThanOrEqual(
            resetCount, 2,
            "LoggerExample should call Logger.reset() at least twice (between parts)"
        )
    }

    func testLoggerExampleUsesOutputCount() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("outputCount"),
            "LoggerExample should demonstrate Logger.shared.outputCount tracking"
        )
    }

    func testLoggerExampleDemonstratesZeroOverheadNone() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        // Should show that .none level produces zero output
        let hasNoneCheck = content.contains(".none") && content.contains("outputCount")
        XCTAssertTrue(
            hasNoneCheck,
            "LoggerExample should demonstrate that .none level produces zero output (outputCount == 0)"
        )
    }

    // MARK: - AC8: Agent Integration

    func testLoggerExampleUsesSDKConfigurationWithLogLevel() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        // The example may use AgentOptions with logLevel/logOutput directly
        let hasConfig = content.contains("SDKConfiguration")
            || (content.contains("AgentOptions") && content.contains("logLevel"))
            || content.contains("logLevel")
        XCTAssertTrue(
            hasConfig,
            "LoggerExample should configure logLevel (via SDKConfiguration or AgentOptions)"
        )
    }

    func testLoggerExampleCreatesAgentWithLogConfig() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/LoggerExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent("),
            "LoggerExample should create an Agent with logging configuration"
        )
    }
}

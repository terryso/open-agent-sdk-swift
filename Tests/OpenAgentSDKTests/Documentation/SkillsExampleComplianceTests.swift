import XCTest
import Foundation

// MARK: - ATDD Tests for Story 15-1: SkillsExample
// TDD RED PHASE: These tests will FAIL until Examples/SkillsExample/ is created
// and Package.swift is updated with the SkillsExample executableTarget.

final class SkillsExampleComplianceTests: XCTestCase {

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

    private func examplesDir() -> String {
        return projectRoot() + "/Examples"
    }

    private func examplePath() -> String {
        return examplesDir() + "/SkillsExample/main.swift"
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

    // MARK: - AC8: Package.swift executableTarget Configured

    func testPackageSwiftContainsSkillsExampleTarget() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("SkillsExample"),
            "Package.swift should contain SkillsExample executable target"
        )
    }

    func testSkillsExampleTargetDependsOnOpenAgentSDK() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("SkillsExample"),
            "Package.swift should contain SkillsExample target before checking dependencies"
        )
        let targetRange = content.range(of: "SkillsExample")
        XCTAssertNotNil(targetRange, "Should find SkillsExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let depsEnd = afterTarget.range(of: "]", options: .literal) {
                let depsSection = String(afterTarget[..<depsEnd.lowerBound])
                XCTAssertTrue(
                    depsSection.contains("OpenAgentSDK"),
                    "SkillsExample executable target should depend on OpenAgentSDK"
                )
            }
        }
    }

    func testSkillsExampleTargetSpecifiesCorrectPath() {
        let content = packageSwiftContent()
        XCTAssertTrue(
            content.contains("SkillsExample"),
            "Package.swift should contain SkillsExample target before checking path"
        )
        let targetRange = content.range(of: "SkillsExample")
        XCTAssertNotNil(targetRange, "Should find SkillsExample in Package.swift")
        if let targetRange {
            let afterTarget = content[targetRange.lowerBound...]
            if let blockEnd = afterTarget.range(of: ")") {
                let blockSection = String(afterTarget[..<blockEnd.lowerBound])
                XCTAssertTrue(
                    blockSection.contains("Examples/SkillsExample"),
                    "SkillsExample target should specify path: 'Examples/SkillsExample'"
                )
            }
        }
    }

    // MARK: - AC1: SkillsExample Directory and File Exist, Compiles

    func testSkillsExampleDirectoryExists() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(
            atPath: examplesDir() + "/SkillsExample",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists, "Examples/SkillsExample/ directory should exist")
        XCTAssertTrue(isDir.boolValue, "Examples/SkillsExample/ should be a directory")
    }

    func testSkillsExampleMainSwiftExists() {
        let fileManager = FileManager.default
        XCTAssertTrue(
            fileManager.fileExists(atPath: examplePath()),
            "Examples/SkillsExample/main.swift should exist"
        )
    }

    func testSkillsExampleImportsOpenAgentSDK() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import OpenAgentSDK"),
            "SkillsExample should import OpenAgentSDK"
        )
    }

    func testSkillsExampleImportsFoundation() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("import Foundation"),
            "SkillsExample should import Foundation"
        )
    }

    // MARK: - AC2: Built-in Skills Initialization

    func testSkillsExampleCreatesSkillRegistry() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("SkillRegistry"),
            "SkillsExample should create a SkillRegistry instance"
        )
    }

    func testSkillsExampleRegistersAllBuiltInSkills() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // Should reference all five built-in skills: commit, review, simplify, debug, test
        let builtInSkills = ["commit", "review", "simplify", "debug", "test"]
        for skillName in builtInSkills {
            XCTAssertTrue(
                content.contains("BuiltInSkills.\(skillName)"),
                "SkillsExample should register BuiltInSkills.\(skillName)"
            )
        }
    }

    func testSkillsExampleRegistersBuiltInSkillsIntoRegistry() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("registry.register("),
            "SkillsExample should call registry.register() to register skills"
        )
    }

    // MARK: - AC3: List All Registered Skills

    func testSkillsExampleOutputsAllRegisteredSkills() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("allSkills"),
            "SkillsExample should access registry.allSkills to list all registered skills"
        )
    }

    func testSkillsExamplePrintsSkillNameDescriptionAndAliases() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // Should output name, description, and aliases for each skill
        let hasName = content.contains(".name")
        let hasDescription = content.contains(".description")
        let hasAliases = content.contains(".aliases")
        XCTAssertTrue(
            hasName && hasDescription && hasAliases,
            "SkillsExample should print skill name, description, and aliases for all registered skills"
        )
    }

    // MARK: - AC4: List User-Invocable Skills

    func testSkillsExampleOutputsUserInvocableSkills() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("userInvocableSkills"),
            "SkillsExample should access registry.userInvocableSkills to demonstrate filtering"
        )
    }

    func testSkillsExampleDemonstratesFilteringDifference() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // Should show both allSkills and userInvocableSkills to demonstrate the difference
        XCTAssertTrue(
            content.contains("allSkills") && content.contains("userInvocableSkills"),
            "SkillsExample should show both allSkills and userInvocableSkills to demonstrate the filtering difference"
        )
    }

    // MARK: - AC5: Register Custom Skill

    func testSkillsExampleRegistersCustomSkill() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // Should demonstrate creating and registering a custom skill (e.g., "explain")
        // Look for Skill( init pattern after the built-in skills registration
        XCTAssertTrue(
            content.contains("Skill(") && content.contains("register("),
            "SkillsExample should create a custom Skill instance and register it"
        )
    }

    func testSkillsExampleCustomSkillHasPromptTemplate() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("promptTemplate:"),
            "SkillsExample custom skill should define a promptTemplate"
        )
    }

    func testSkillsExampleCustomSkillHasAliases() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // The custom skill should have at least one alias defined
        // Look for aliases: parameter in a Skill( init
        XCTAssertTrue(
            content.contains("aliases:"),
            "SkillsExample custom skill should define aliases"
        )
    }

    func testSkillsExampleCustomSkillAppearsInAllSkills() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // After registering custom skill, should verify it appears in allSkills
        // This is demonstrated by printing allSkills again after registration
        let registerOccurrences = content.components(separatedBy: "register(").count - 1
        XCTAssertGreaterThan(
            registerOccurrences, 5,
            "SkillsExample should have more than 5 register() calls (5 built-in + at least 1 custom)"
        )
    }

    // MARK: - AC6: Find Skill by Name and Alias

    func testSkillsExampleDemonstratesFindByName() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("registry.find("),
            "SkillsExample should demonstrate registry.find() for skill lookup"
        )
    }

    func testSkillsExampleDemonstratesFindByAlias() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // Should find by alias (e.g., "ci" for commit or "eli5" for explain)
        // Look for find() being called with a string that is an alias, not a name
        let findCalls = content.components(separatedBy: "registry.find(")
        var foundAliasLookup = false
        for i in 1..<findCalls.count {
            let call = findCalls[i]
            if let endParen = call.range(of: ")") {
                let arg = String(call[..<endParen.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
                // Known aliases from BuiltInSkills: "ci" for commit, "review-pr"/"cr" for review,
                // "investigate"/"diagnose" for debug, "run-tests" for test
                let knownAliases = ["ci", "cr", "review-pr", "investigate", "diagnose",
                                    "run-tests", "eli5"]
                if knownAliases.contains(arg) {
                    foundAliasLookup = true
                    break
                }
            }
        }
        XCTAssertTrue(
            foundAliasLookup,
            "SkillsExample should demonstrate registry.find() with an alias (not a name)"
        )
    }

    // MARK: - AC7: Agent Invokes Skill via LLM

    func testSkillsExampleCreatesAgentWithSkillTool() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createSkillTool(registry:"),
            "SkillsExample should create the SkillTool via createSkillTool(registry:)"
        )
    }

    func testSkillsExampleAppendsSkillToolToTools() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("getAllBaseTools(tier: .core)"),
            "SkillsExample should get core tools with getAllBaseTools(tier: .core)"
        )
        XCTAssertTrue(
            content.contains("append(") || content.contains(".append(") || content.contains("+="),
            "SkillsExample should append the SkillTool to the tools array"
        )
    }

    func testSkillsExampleCreatesAgentWithOptions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("createAgent(options:") || content.contains("createAgent(options: "),
            "SkillsExample should use createAgent(options: AgentOptions(...))"
        )
    }

    func testSkillsExamplePassesToolsIncludingSkillTool() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("tools:"),
            "SkillsExample should pass tools: parameter in AgentOptions"
        )
    }

    func testSkillsExampleUsesBypassPermissions() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains(".bypassPermissions"),
            "SkillsExample should use .bypassPermissions permissionMode for example purposes"
        )
    }

    func testSkillsExampleSendsQueryToAgent() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("agent.prompt(") || content.contains("agent.stream("),
            "SkillsExample should send a query to the agent using prompt() or stream()"
        )
    }

    func testSkillsExamplePrintsAgentResponse() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // Should print the agent response text
        XCTAssertTrue(
            content.contains(".text"),
            "SkillsExample should print the agent response text"
        )
    }

    func testSkillsExamplePrintsQueryStatistics() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // Should output query statistics: status, turns, duration, cost
        let statsProps = ["numTurns", "durationMs", "totalCostUsd"]
        for prop in statsProps {
            XCTAssertTrue(
                content.contains(prop),
                "SkillsExample should print query statistic '\(prop)'"
            )
        }
    }

    // MARK: - API Key Loading Pattern (follows existing example conventions)

    func testSkillsExampleUsesLoadDotEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("loadDotEnv()"),
            "SkillsExample should use loadDotEnv() helper pattern"
        )
    }

    func testSkillsExampleUsesGetEnvPattern() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("getEnv("),
            "SkillsExample should use getEnv() helper pattern for API key loading"
        )
    }

    func testSkillsExampleDoesNotExposeRealAPIKeys() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
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
                        "SkillsExample should not contain a real-looking API key"
                    )
                }
            }
        }
    }

    // MARK: - Code Quality and Documentation

    func testSkillsExampleHasTopLevelDescriptionComment() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(
            trimmed.hasPrefix("//"),
            "SkillsExample should start with a descriptive comment block"
        )
    }

    func testSkillsExampleHasMultipleInlineComments() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        let commentLines = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .count
        XCTAssertGreaterThan(
            commentLines, 5,
            "SkillsExample should have multiple inline comments (found \(commentLines))"
        )
    }

    func testSkillsExampleHasMarkSections() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // Should have MARK sections for the different parts of the demo
        XCTAssertTrue(
            content.contains("MARK:"),
            "SkillsExample should use MARK section comments for organization"
        )
    }

    func testSkillsExampleDoesNotUseForceUnwrap() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comment lines
            if trimmed.hasPrefix("//") { continue }
            // Check for try!
            XCTAssertFalse(
                trimmed.contains("try!"),
                "SkillsExample should not use 'try!' force-try"
            )
        }
    }

    // MARK: - Uses Actual Public API Signatures

    func testSkillsExampleUsesRealSkillStructInit() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // Custom skill should use real Skill init parameters
        let validParams = ["name:", "description:", "aliases:", "promptTemplate:"]
        var foundParams = 0
        for param in validParams {
            if content.contains(param) {
                foundParams += 1
            }
        }
        XCTAssertGreaterThanOrEqual(
            foundParams, 3,
            "SkillsExample custom Skill should use at least 3 real init parameter names"
        )
    }

    func testSkillsExampleUsesRealQueryResultProperties() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        // QueryResult properties should match source: text, numTurns, durationMs, status, totalCostUsd
        let requiredProperties = ["text", "numTurns", "durationMs", "totalCostUsd"]
        for prop in requiredProperties {
            XCTAssertTrue(
                content.contains(prop),
                "SkillsExample should access QueryResult property '\(prop)' matching source type"
            )
        }
    }

    func testSkillsExampleUsesAwaitForPrompt() {
        guard let content = fileContent(examplePath()) else {
            XCTFail("Examples/SkillsExample/main.swift should be readable")
            return
        }
        XCTAssertTrue(
            content.contains("await agent.prompt(") || content.contains("await agent.stream("),
            "SkillsExample should use 'await agent.prompt()' or 'await agent.stream()'"
        )
    }
}

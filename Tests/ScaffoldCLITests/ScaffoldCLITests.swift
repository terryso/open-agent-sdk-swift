import XCTest
import Foundation
@testable import ScaffoldCLI

// MARK: - ScaffoldCLI Tests

final class ScaffoldCLITests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScaffoldCLITests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir!)
        super.tearDown()
    }

    // MARK: - Argument Parsing

    func test_templateType_basic_fromRawValue() {
        let type = TemplateType(rawValue: "basic")
        XCTAssertEqual(type, .basic)
    }

    func test_templateType_mcpIntegration_fromRawValue() {
        let type = TemplateType(rawValue: "mcp-integration")
        XCTAssertEqual(type, .mcpIntegration)
    }

    func test_templateType_invalid_returnsNil() {
        let type = TemplateType(rawValue: "nonexistent")
        XCTAssertNil(type)
    }

    // MARK: - Project Name Validation (via ScaffoldCLI internals)

    func test_scaffoldError_invalidProjectName_description() {
        let error = ScaffoldError.invalidProjectName("123bad")
        XCTAssertTrue(error.description.contains("Invalid project name"))
        XCTAssertTrue(error.description.contains("123bad"))
    }

    func test_scaffoldError_directoryAlreadyExists_description() {
        let error = ScaffoldError.directoryAlreadyExists("/some/path")
        XCTAssertTrue(error.description.contains("Directory already exists"))
        XCTAssertTrue(error.description.contains("/some/path"))
    }

    // MARK: - File Generation Completeness

    func test_generate_basic_generatesAllFiles() throws {
        let projectName = "MyAgent"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let expectedFiles = [
            "Package.swift",
            ".env.example",
            "README.md",
            "Sources/\(projectName)/main.swift",
            "Sources/\(projectName)/Tools/HelloWorldTool.swift",
            "Sources/\(projectName)/Hooks/SafetyHooks.swift",
            "Sources/\(projectName)/Config/EnvLoader.swift",
            "Prompts/system.md",
        ]

        for file in expectedFiles {
            let url = projectDir.appendingPathComponent(file)
            let exists = FileManager.default.fileExists(atPath: url.path)
            XCTAssertTrue(exists, "Expected file not found: \(file)")

            if exists {
                let content = try String(contentsOf: url, encoding: .utf8)
                XCTAssertFalse(content.isEmpty, "File is empty: \(file)")
            }
        }
    }

    func test_generate_mcpIntegration_generatesAllFiles() throws {
        let projectName = "McpTestAgent"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .mcpIntegration
        )
        try generator.generate()

        let mainSwift = projectDir.appendingPathComponent("Sources/\(projectName)/main.swift")
        let content = try String(contentsOf: mainSwift, encoding: .utf8)

        XCTAssertTrue(content.contains("MCP"), "MCP integration main.swift should mention MCP")
        XCTAssertTrue(content.contains("McpStdioConfig"), "Should contain MCP server config reference")
    }

    // MARK: - Package.swift Content

    func test_generate_packageSwift_containsSDKDependency() throws {
        let projectName = "SdkDepTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let packageSwift = projectDir.appendingPathComponent("Package.swift")
        let content = try String(contentsOf: packageSwift, encoding: .utf8)

        XCTAssertTrue(content.contains("open-agent-sdk-swift"), "Should reference SDK package")
        XCTAssertTrue(content.contains("OpenAgentSDK"), "Should import OpenAgentSDK product")
        XCTAssertTrue(content.contains("swift-tools-version: 6.1"), "Should use swift-tools-version 6.1")
        XCTAssertTrue(content.contains(".macOS(.v14)"), "Should target macOS 14")
        XCTAssertTrue(content.contains(projectName), "Should contain project name")
        XCTAssertTrue(content.contains("executableTarget"), "Should define executable target")
        XCTAssertTrue(content.contains("testTarget"), "Should define test target")
    }

    // MARK: - Template Parameter Substitution

    func test_generate_projectName_substitutedInTemplates() throws {
        let projectName = "CustomAgent"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        // Check Package.swift contains project name
        let packageSwift = projectDir.appendingPathComponent("Package.swift")
        let packageContent = try String(contentsOf: packageSwift, encoding: .utf8)
        XCTAssertTrue(packageContent.contains("name: \"\(projectName)\""), "Package name should match")
        XCTAssertTrue(packageContent.contains("path: \"Sources/\(projectName)\""), "Source path should match")

        // Check README contains project name
        let readme = projectDir.appendingPathComponent("README.md")
        let readmeContent = try String(contentsOf: readme, encoding: .utf8)
        XCTAssertTrue(readmeContent.contains("# \(projectName)"), "README title should contain project name")
    }

    // MARK: - Template Content Verification

    func test_generate_mainSwift_basic_containsCreateAgent() throws {
        let projectName = "AgentTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let mainSwift = projectDir.appendingPathComponent("Sources/\(projectName)/main.swift")
        let content = try String(contentsOf: mainSwift, encoding: .utf8)

        XCTAssertTrue(content.contains("createAgent"), "Should use createAgent API")
        XCTAssertTrue(content.contains("AgentOptions"), "Should use AgentOptions")
        XCTAssertTrue(content.contains("loadDotEnv"), "Should load .env")
        XCTAssertTrue(content.contains("agent.prompt"), "Should call agent.prompt")
        XCTAssertTrue(content.contains("import OpenAgentSDK"), "Should import OpenAgentSDK")
        XCTAssertTrue(content.contains("createExampleTools"), "Should use createExampleTools()")
    }

    func test_generate_helloWorldTool_containsDefineTool() throws {
        let projectName = "ToolTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let toolFile = projectDir.appendingPathComponent("Sources/\(projectName)/Tools/HelloWorldTool.swift")
        let content = try String(contentsOf: toolFile, encoding: .utf8)

        XCTAssertTrue(content.contains("defineTool"), "Should demonstrate defineTool()")
        XCTAssertTrue(content.contains("HelloInput"), "Should define Codable input struct")
        XCTAssertTrue(content.contains("GreetingInput"), "Should define GreetingInput struct")
        XCTAssertTrue(content.contains("ToolExecuteResult"), "Should show ToolExecuteResult usage")
        XCTAssertTrue(content.contains("inputSchema"), "Should define JSON Schema")
        XCTAssertTrue(content.contains("createExampleTools"), "Should export factory function")
        XCTAssertTrue(content.contains("ToolProtocol"), "Should return ToolProtocol type")
    }

    func test_generate_systemPrompt_containsToolGuidance() throws {
        let projectName = "PromptTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let promptFile = projectDir.appendingPathComponent("Prompts/system.md")
        let content = try String(contentsOf: promptFile, encoding: .utf8)

        XCTAssertTrue(content.contains("hello"), "Should describe hello tool")
        XCTAssertTrue(content.contains("greeting"), "Should describe greeting tool")
    }

    func test_generate_readme_containsRequiredSections() throws {
        let projectName = "ReadmeTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let readme = projectDir.appendingPathComponent("README.md")
        let content = try String(contentsOf: readme, encoding: .utf8)

        XCTAssertTrue(content.contains("Quick Start"), "Should have Quick Start section")
        XCTAssertTrue(content.contains("Project Structure"), "Should have project structure section")
        XCTAssertTrue(content.contains("Tool Development Guide"), "Should explain tool development")
        XCTAssertTrue(content.contains("defineTool"), "Should reference defineTool API")
        XCTAssertTrue(content.contains("swift run"), "Should explain how to run")
        XCTAssertTrue(content.contains("SDK Reference"), "Should link to SDK docs")
        XCTAssertTrue(content.contains("sdk-boundary"), "Should reference SDK boundary doc")
    }

    // MARK: - Edge Cases

    func test_generate_overwritesExistingFiles() throws {
        let projectName = "OverwriteTest"
        let projectDir = tempDir.appendingPathComponent(projectName)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Write a file that will be overwritten
        let existingFile = projectDir.appendingPathComponent("Package.swift")
        try "old content".write(to: existingFile, atomically: true, encoding: .utf8)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        // Generator overwrites existing files (validation is in ScaffoldCLI layer)
        try generator.generate()

        let content = try String(contentsOf: existingFile, encoding: .utf8)
        XCTAssertTrue(content.contains("open-agent-sdk-swift"), "File should be overwritten with new content")
    }

    func test_generate_hyphenatedProjectName() throws {
        let projectName = "my-cool-agent"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let packageSwift = projectDir.appendingPathComponent("Package.swift")
        let content = try String(contentsOf: packageSwift, encoding: .utf8)
        XCTAssertTrue(content.contains("name: \"\(projectName)\""))
        XCTAssertTrue(content.contains("path: \"Sources/\(projectName)\""))
    }

    func test_generate_underscoreProjectName() throws {
        let projectName = "my_agent"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let packageSwift = projectDir.appendingPathComponent("Package.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageSwift.path))
    }

    // MARK: - ScaffoldError Coverage

    func test_scaffoldError_fileWriteFailed_description() {
        let error = ScaffoldError.fileWriteFailed("Package.swift: permission denied")
        XCTAssertTrue(error.description.contains("Failed to write file"))
        XCTAssertTrue(error.description.contains("Package.swift"))
    }

    // MARK: - Output Directory Option

    func test_generate_withCustomOutputDirectory() throws {
        let projectName = "OutputTest"
        let outputDir = tempDir.appendingPathComponent("custom-output")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let projectDir = outputDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let packageSwift = projectDir.appendingPathComponent("Package.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageSwift.path))
        let content = try String(contentsOf: packageSwift, encoding: .utf8)
        XCTAssertTrue(content.contains("open-agent-sdk-swift"))
    }

    // MARK: - Story 11.2: Extended Tool Examples

    func test_generate_helloWorldTool_containsCalculatorTool() throws {
        let projectName = "CalcTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let toolFile = projectDir.appendingPathComponent("Sources/\(projectName)/Tools/HelloWorldTool.swift")
        let content = try String(contentsOf: toolFile, encoding: .utf8)

        XCTAssertTrue(content.contains("CalculatorInput"), "Should define CalculatorInput struct")
        XCTAssertTrue(content.contains("calculatorTool"), "Should define calculatorTool")
        XCTAssertTrue(content.contains("calculator"), "Tool name should be 'calculator'")
    }

    func test_generate_helloWorldTool_containsSystemInfoTool() throws {
        let projectName = "SysInfoTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let toolFile = projectDir.appendingPathComponent("Sources/\(projectName)/Tools/HelloWorldTool.swift")
        let content = try String(contentsOf: toolFile, encoding: .utf8)

        XCTAssertTrue(content.contains("systemInfoTool"), "Should define systemInfoTool")
        XCTAssertTrue(content.contains("system_info"), "Tool name should be 'system_info'")
        XCTAssertTrue(content.contains("ProcessInfo"), "Should use ProcessInfo for system data")
    }

    func test_generate_helloWorldTool_containsConfigTool() throws {
        let projectName = "ConfigToolTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let toolFile = projectDir.appendingPathComponent("Sources/\(projectName)/Tools/HelloWorldTool.swift")
        let content = try String(contentsOf: toolFile, encoding: .utf8)

        XCTAssertTrue(content.contains("configTool"), "Should define configTool")
        XCTAssertTrue(content.contains("get_config"), "Tool name should be 'get_config'")
        XCTAssertTrue(content.contains("[String: Any]"), "Should use raw dictionary input")
    }

    func test_generate_createExampleTools_returnsAllTools() throws {
        let projectName = "AllToolsTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let toolFile = projectDir.appendingPathComponent("Sources/\(projectName)/Tools/HelloWorldTool.swift")
        let content = try String(contentsOf: toolFile, encoding: .utf8)

        XCTAssertTrue(content.contains("helloTool, greetingTool, calculatorTool, systemInfoTool, configTool"),
                      "createExampleTools should return all 5 tools")
    }

    // MARK: - Story 11.2: Hooks Template

    func test_generate_basic_generatesHooksFile() throws {
        let projectName = "HooksTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let hooksFile = projectDir.appendingPathComponent("Sources/\(projectName)/Hooks/SafetyHooks.swift")
        let exists = FileManager.default.fileExists(atPath: hooksFile.path)
        XCTAssertTrue(exists, "Hooks file should be generated")

        let content = try String(contentsOf: hooksFile, encoding: .utf8)
        XCTAssertTrue(content.contains("HookRegistry"), "Should reference HookRegistry")
        XCTAssertTrue(content.contains("HookDefinition"), "Should reference HookDefinition")
        XCTAssertTrue(content.contains("HookOutput"), "Should reference HookOutput")
        XCTAssertTrue(content.contains("registerSafetyHooks"), "Should define registerSafetyHooks function")
        XCTAssertTrue(content.contains("registerHooksFromConfig"), "Should define registerHooksFromConfig function")
        XCTAssertTrue(content.contains("preToolUse"), "Should register preToolUse hook")
        XCTAssertTrue(content.contains("postToolUse"), "Should register postToolUse hook")
        XCTAssertTrue(content.contains("matcher"), "Should use matcher for filtering")
    }

    // MARK: - Story 11.2: MCP Integration Template

    func test_generate_mcpIntegration_containsAxionMCP() throws {
        let projectName = "McpAxionTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .mcpIntegration
        )
        try generator.generate()

        let mainSwift = projectDir.appendingPathComponent("Sources/\(projectName)/main.swift")
        let content = try String(contentsOf: mainSwift, encoding: .utf8)

        XCTAssertTrue(content.contains("axion mcp"), "Should reference 'axion mcp' command")
        XCTAssertTrue(content.contains("axion-helper"), "Should use 'axion-helper' as server name")
        XCTAssertTrue(content.contains("McpStdioConfig"), "Should use McpStdioConfig")
        XCTAssertTrue(content.contains("mcpServers"), "Should configure mcpServers")
        XCTAssertTrue(content.contains("mcp__axion-helper__"), "Should explain namespace pattern")
    }

    // MARK: - Story 11.2: README Extended Sections

    func test_generate_readme_containsToolDevelopmentGuide() throws {
        let projectName = "ToolGuideTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let readme = projectDir.appendingPathComponent("README.md")
        let content = try String(contentsOf: readme, encoding: .utf8)

        XCTAssertTrue(content.contains("Tool Development Guide"), "Should have tool development guide")
        XCTAssertTrue(content.contains("Codable"), "Should explain Codable pattern")
        XCTAssertTrue(content.contains("No-Input"), "Should explain No-Input pattern")
        XCTAssertTrue(content.contains("Raw Dictionary"), "Should explain Raw Dictionary pattern")
        XCTAssertTrue(content.contains("ToolExecuteResult"), "Should explain ToolExecuteResult")
    }

    func test_generate_readme_containsHooksSection() throws {
        let projectName = "HooksReadmeTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let readme = projectDir.appendingPathComponent("README.md")
        let content = try String(contentsOf: readme, encoding: .utf8)

        XCTAssertTrue(content.contains("Hooks"), "Should have Hooks section")
        XCTAssertTrue(content.contains("preToolUse"), "Should mention preToolUse")
        XCTAssertTrue(content.contains("registerFromConfig"), "Should show batch registration")
        XCTAssertTrue(content.contains("HookRegistry"), "Should reference HookRegistry")
        XCTAssertTrue(content.contains("matcher"), "Should mention matcher")
    }

    func test_generate_readme_containsMCPIntegrationSection() throws {
        let projectName = "McpReadmeTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let readme = projectDir.appendingPathComponent("README.md")
        let content = try String(contentsOf: readme, encoding: .utf8)

        XCTAssertTrue(content.contains("MCP Server Integration"), "Should have MCP integration section")
        XCTAssertTrue(content.contains("axion mcp"), "Should reference Axion MCP command")
        XCTAssertTrue(content.contains("mcp__"), "Should explain namespace pattern")
        XCTAssertTrue(content.contains("Custom Helper"), "Should mention custom Helper App")
    }

    func test_generate_readme_containsToolPoolAndPermissions() throws {
        let projectName = "PoolPermTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let readme = projectDir.appendingPathComponent("README.md")
        let content = try String(contentsOf: readme, encoding: .utf8)

        XCTAssertTrue(content.contains("Tool Pool Assembly"), "Should have tool pool section")
        XCTAssertTrue(content.contains("assembleToolPool"), "Should reference assembleToolPool")
        XCTAssertTrue(content.contains("Permission Modes"), "Should have permission modes section")
        XCTAssertTrue(content.contains("canUseTool"), "Should mention canUseTool callback")
        XCTAssertTrue(content.contains("allowedTools"), "Should use correct field name 'allowedTools'")
        XCTAssertTrue(content.contains("disallowedTools"), "Should use correct field name 'disallowedTools'")
        XCTAssertTrue(content.contains("CanUseToolResult"), "Should reference CanUseToolResult type")
        XCTAssertTrue(content.contains(".deny("), "Should show .deny() usage in canUseTool")
        XCTAssertTrue(content.contains(".allow()"), "Should show .allow() usage in canUseTool")
    }

    func test_generate_basic_generatesHooksDirectory() throws {
        let projectName = "HooksDirTest"
        let projectDir = tempDir.appendingPathComponent(projectName)

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: .basic
        )
        try generator.generate()

        let hooksDir = projectDir.appendingPathComponent("Sources/\(projectName)/Hooks")
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: hooksDir.path, isDirectory: &isDir)
        XCTAssertTrue(exists && isDir.boolValue, "Hooks directory should be created")
    }
}

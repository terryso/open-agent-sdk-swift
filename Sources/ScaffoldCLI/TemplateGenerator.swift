import Foundation

struct TemplateGenerator {
    let projectName: String
    let projectDir: URL
    let templateType: TemplateType

    func generate() throws {
        try createDirectoryStructure()
        try generatePackageDotSwift()
        try generateMainSwift()
        try generateHelloWorldTool()
        try generateSafetyHooks()
        try generateEnvLoader()
        try generateSystemPrompt()
        try generateEnvExample()
        try generateReadme()
    }

    // MARK: - Directory Structure

    func createDirectoryStructure() throws {
        let fm = FileManager.default
        let dirs = [
            "Sources/\(projectName)/Tools",
            "Sources/\(projectName)/Hooks",
            "Sources/\(projectName)/Config",
            "Prompts",
            "Tests/\(projectName)Tests",
        ]
        for dir in dirs {
            let url = projectDir.appendingPathComponent(dir)
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - Package.swift

    func generatePackageDotSwift() throws {
        let content = """
        // swift-tools-version: 6.1
        import PackageDescription

        let package = Package(
            name: "\(projectName)",
            platforms: [.macOS(.v14)],
            dependencies: [
                .package(
                    url: "https://github.com/terryso/open-agent-sdk-swift",
                    from: "0.2.1"
                )
            ],
            targets: [
                .executableTarget(
                    name: "\(projectName)",
                    dependencies: [
                        .product(name: "OpenAgentSDK", package: "open-agent-sdk-swift")
                    ],
                    path: "Sources/\(projectName)"
                ),
                .testTarget(
                    name: "\(projectName)Tests",
                    dependencies: ["\(projectName)"],
                    path: "Tests/\(projectName)Tests"
                ),
            ]
        )
        """
        try writeFile(content, at: "Package.swift")
    }

    // MARK: - main.swift

    func generateMainSwift() throws {
        let content: String
        switch templateType {
        case .basic:
            content = basicMainSwift
        case .mcpIntegration:
            content = mcpIntegrationMainSwift
        }
        try writeFile(content, at: "Sources/\(projectName)/main.swift")
    }

    // MARK: - HelloWorld Tool

    func generateHelloWorldTool() throws {
        try writeFile(helloWorldToolContent, at: "Sources/\(projectName)/Tools/HelloWorldTool.swift")
    }

    // MARK: - Safety Hooks

    func generateSafetyHooks() throws {
        try writeFile(safetyHooksContent, at: "Sources/\(projectName)/Hooks/SafetyHooks.swift")
    }

    // MARK: - EnvLoader

    func generateEnvLoader() throws {
        try writeFile(envLoaderContent, at: "Sources/\(projectName)/Config/EnvLoader.swift")
    }

    // MARK: - System Prompt

    func generateSystemPrompt() throws {
        try writeFile(systemPromptContent, at: "Prompts/system.md")
    }

    // MARK: - .env.example

    func generateEnvExample() throws {
        try writeFile(envExampleContent, at: ".env.example")
    }

    // MARK: - README

    func generateReadme() throws {
        try writeFile(readmeContent, at: "README.md")
    }

    // MARK: - Helpers

    private func writeFile(_ content: String, at relativePath: String) throws {
        let url = projectDir.appendingPathComponent(relativePath)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ScaffoldError.fileWriteFailed("\(relativePath): \(error.localizedDescription)")
        }
    }
}

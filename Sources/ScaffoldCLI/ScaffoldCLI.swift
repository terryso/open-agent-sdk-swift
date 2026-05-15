import ArgumentParser
import Foundation

@main
struct ScaffoldCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scaffold",
        abstract: "Generate an OpenAgentSDK-based Agent project from templates",
        version: "0.1.0"
    )

    @Argument(help: "Name of the project to generate")
    var projectName: String

    @Option(name: .shortAndLong, help: "Output directory (default: current directory)")
    var output: String?

    @Option(name: .shortAndLong, help: "Template type: basic or mcp-integration")
    var type: TemplateType = .basic

    func run() throws {
        let outputDir = output ?? FileManager.default.currentDirectoryPath
        let projectDir = URL(fileURLWithPath: outputDir).appendingPathComponent(projectName)

        // Validate project name
        guard isValidProjectName(projectName) else {
            throw ScaffoldError.invalidProjectName(projectName)
        }

        // Check if directory already exists
        if FileManager.default.fileExists(atPath: projectDir.path) {
            throw ScaffoldError.directoryAlreadyExists(projectDir.path)
        }

        print("Generating Agent project '\(projectName)' (type: \(type.rawValue))...")
        print("Output: \(projectDir.path)")

        let generator = TemplateGenerator(
            projectName: projectName,
            projectDir: projectDir,
            templateType: type
        )
        try generator.generate()

        print()
        print("Project generated successfully!")
        print()
        print("Next steps:")
        print("  cd \(projectName)")
        print("  cp .env.example .env   # Add your API key")
        print("  swift build")
        print("  swift run \(projectName)")
    }

    private func isValidProjectName(_ name: String) -> Bool {
        let valid = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return !name.isEmpty
            && name.unicodeScalars.allSatisfy { valid.contains($0) }
            && name.first?.isLetter == true
    }
}

enum TemplateType: String, ExpressibleByArgument {
    case basic
    case mcpIntegration = "mcp-integration"
}

enum ScaffoldError: Error, CustomStringConvertible {
    case invalidProjectName(String)
    case directoryAlreadyExists(String)
    case fileWriteFailed(String)

    var description: String {
        switch self {
        case .invalidProjectName(let name):
            return "Invalid project name '\(name)'. Must start with a letter and contain only letters, digits, hyphens, and underscores."
        case .directoryAlreadyExists(let path):
            return "Directory already exists: \(path)"
        case .fileWriteFailed(let message):
            return "Failed to write file: \(message)"
        }
    }
}

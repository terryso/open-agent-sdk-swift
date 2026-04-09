import Foundation
import OpenAgentSDK

// MARK: - LLM-Driven Core Tools E2E Tests

struct CoreToolsE2ETests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("44. LLM-Driven Bash Tool")
        await testLLMDrivenBashTool(apiKey: apiKey, model: model, baseURL: baseURL)

        section("45. LLM-Driven Bash: Error Handling")
        await testLLMDrivenBashToolError(apiKey: apiKey, model: model, baseURL: baseURL)

        section("46. LLM-Driven FileWrite + FileRead")
        await testLLMDrivenFileWriteRead(apiKey: apiKey, model: model, baseURL: baseURL)

        section("47. LLM-Driven Glob Tool")
        await testLLMDrivenGlobTool(apiKey: apiKey, model: model, baseURL: baseURL)

        section("48. LLM-Driven Grep Tool")
        await testLLMDrivenGrepTool(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: Test 44 - Bash Tool

    static func testLLMDrivenBashTool(apiKey: String, model: String, baseURL: String) async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-bash-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let bashTool = createBashTool()
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            cwd: tempDir.path,
            tools: [bashTool]
        ))

        let result = await agent.prompt(
            "Use the Bash tool to run the command: echo 'hello from e2e'"
        )

        if result.status == .success {
            pass("LLM+Bash: agent returns success")
        } else {
            fail("LLM+Bash: agent returns success", "got \(result.status)")
        }

        if result.numTurns >= 2 {
            pass("LLM+Bash: agent uses multiple turns (tool call + response)")
        } else {
            fail("LLM+Bash: agent uses multiple turns", "numTurns=\(result.numTurns)")
        }

        let lower = result.text.lowercased()
        if lower.contains("hello from e2e") || lower.contains("hello") {
            pass("LLM+Bash: response contains command output")
        } else {
            fail("LLM+Bash: response contains command output", "text: \(result.text.prefix(200))")
        }
    }

    // MARK: Test 45 - Bash Error Handling

    static func testLLMDrivenBashToolError(apiKey: String, model: String, baseURL: String) async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-bash-err-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let bashTool = createBashTool()
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            cwd: tempDir.path,
            tools: [bashTool]
        ))

        let result = await agent.prompt(
            "Use the Bash tool to run the command: ls /nonexistent_directory_xyz_12345"
        )

        if result.status == .success {
            pass("LLM+Bash error: agent handles non-zero exit code gracefully")
        } else {
            fail("LLM+Bash error: agent handles non-zero exit code gracefully", "got \(result.status)")
        }
    }

    // MARK: Test 46 - FileWrite + FileRead

    static func testLLMDrivenFileWriteRead(apiKey: String, model: String, baseURL: String) async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-files-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let writeTool = createWriteTool()
        let readTool = createReadTool()
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            permissionMode: .bypassPermissions,
            cwd: tempDir.path,
            tools: [writeTool, readTool]
        ))

        let filePath = tempDir.appendingPathComponent("test.txt").path
        let result = await agent.prompt(
            "Use the Write tool to write the content 'E2E test content' to the file at path \(filePath)."
        )

        if result.status == .success {
            pass("LLM+FileWrite: agent returns success")
        } else {
            fail("LLM+FileWrite: agent returns success", "got \(result.status)")
        }

        // Verify file was actually created
        let content = try? String(contentsOfFile: filePath, encoding: .utf8)
        if content?.contains("E2E test content") == true {
            pass("LLM+FileWrite: file created with correct content")
        } else {
            fail("LLM+FileWrite: file created with correct content", "content: \(content ?? "nil")")
        }
    }

    // MARK: Test 47 - Glob Tool

    static func testLLMDrivenGlobTool(apiKey: String, model: String, baseURL: String) async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-glob-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create test files
        try? "test1".write(toFile: tempDir.appendingPathComponent("file1.swift").path, atomically: true, encoding: .utf8)
        try? "test2".write(toFile: tempDir.appendingPathComponent("file2.swift").path, atomically: true, encoding: .utf8)
        try? "test3".write(toFile: tempDir.appendingPathComponent("readme.md").path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let globTool = createGlobTool()
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            cwd: tempDir.path,
            tools: [globTool]
        ))

        let result = await agent.prompt(
            "Use the Glob tool to search for files matching the pattern '**/*.swift' in the current directory."
        )

        if result.status == .success {
            pass("LLM+Glob: agent returns success")
        } else {
            fail("LLM+Glob: agent returns success", "got \(result.status)")
        }

        if result.numTurns >= 2 {
            pass("LLM+Glob: agent uses multiple turns")
        } else {
            fail("LLM+Glob: agent uses multiple turns", "numTurns=\(result.numTurns)")
        }

        let lower = result.text.lowercased()
        if lower.contains("file1") || lower.contains("file2") || lower.contains(".swift") {
            pass("LLM+Glob: response mentions found files")
        } else {
            fail("LLM+Glob: response mentions found files", "text: \(result.text.prefix(200))")
        }
    }

    // MARK: Test 48 - Grep Tool

    static func testLLMDrivenGrepTool(apiKey: String, model: String, baseURL: String) async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-grep-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let searchContent = """
        import Foundation
        public struct HelloWorld {
            let greeting = "UNIQUE_E2E_MARKER_42"
        }
        """
        try? searchContent.write(toFile: tempDir.appendingPathComponent("Sample.swift").path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let grepTool = createGrepTool()
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3,
            cwd: tempDir.path,
            tools: [grepTool]
        ))

        let result = await agent.prompt(
            "Use the Grep tool to search for the pattern 'UNIQUE_E2E_MARKER_42' in the current directory."
        )

        if result.status == .success {
            pass("LLM+Grep: agent returns success")
        } else {
            fail("LLM+Grep: agent returns success", "got \(result.status)")
        }

        let lower = result.text.lowercased()
        if lower.contains("unique_e2e_marker") || lower.contains("sample") || lower.contains("found") {
            pass("LLM+Grep: response mentions search results")
        } else {
            fail("LLM+Grep: response mentions search results", "text: \(result.text.prefix(200))")
        }
    }
}

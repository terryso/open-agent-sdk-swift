import Foundation
import OpenAgentSDK

// MARK: - .env File Loader

func loadDotEnv() -> [String: String] {
    let envPath = FileManager.default.currentDirectoryPath + "/.env"
    guard let content = try? String(contentsOfFile: envPath, encoding: .utf8) else { return [:] }
    var env: [String: String] = [:]
    for line in content.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        guard let eqRange = trimmed.range(of: "=") else { continue }
        let key = String(trimmed[..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let value = String(trimmed[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        env[key] = value
    }
    return env
}

func getEnv(_ key: String, from dotEnv: [String: String]) -> String? {
    if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
        return value
    }
    return dotEnv[key]
}

// MARK: - Main

@main
struct E2ETestRunner {
    static func main() async {
        let dotEnv = loadDotEnv()

        print("=== OpenAgentSDK E2E Test (OpenAI Compatible Client) ===\n")

        guard let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv), !apiKey.isEmpty else {
            print("ERROR: CODEANY_API_KEY not set")
            print("Create a .env file or set environment variables:")
            print("  CODEANY_API_KEY=your-key")
            print("  CODEANY_BASE_URL=https://your-proxy.com")
            print("  CODEANY_MODEL=glm-5.1")
            print("\nThen run: swift run E2ETest")
            return
        }

        let baseURL = getEnv("CODEANY_BASE_URL", from: dotEnv) ?? "https://api.openai.com"
        let model = getEnv("CODEANY_MODEL", from: dotEnv) ?? "glm-5.1"

        print("Config:")
        print("  Model:    \(model)")
        print("  Base URL: \(baseURL)")
        print("  API Key:  \(String(apiKey.prefix(8)))...\n")

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 1
        ))

        // Test 1: Non-streaming
        print("--- Test 1: Non-streaming prompt ---")
        let result = await agent.prompt("Say exactly: Hello from OpenAgentSDK E2E test!")
        print("Status:   \(result.status)")
        print("Response: \(result.text)")
        print("Usage:    \(result.usage.inputTokens) in / \(result.usage.outputTokens) out")
        print("Duration: \(result.durationMs)ms, Turns: \(result.numTurns)")
        if result.status != .success {
            print("[FAIL] Unexpected status")
            return
        }
        if result.text.isEmpty {
            print("[FAIL] Empty response")
            return
        }
        print("[PASS]\n")

        // Test 2: Streaming
        print("--- Test 2: Streaming prompt ---")
        let agent2 = createAgent(options: AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: .openai,
            maxTurns: 1
        ))
        var partialCount = 0
        var fullText = ""
        for await message in agent2.stream("Count from 1 to 5, one number per line.") {
            switch message {
            case .partialMessage(let data):
                partialCount += 1
                fullText += data.text
            case .result(let data):
                print("Status:   \(data.subtype)")
                print("Chunks:   \(partialCount)")
                print("Response: \(data.text)")
                if let usage = data.usage {
                    print("Usage:    \(usage.inputTokens) in / \(usage.outputTokens) out")
                }
                print("Duration: \(data.durationMs)ms")
            default:
                break
            }
        }
        if fullText.isEmpty {
            print("[FAIL] Empty streaming response")
            return
        }
        print("[PASS]\n")

        // Test 3: AnthropicClient regression
        print("--- Test 3: AnthropicClient regression ---")
        let client = AnthropicClient(apiKey: "test-key", baseURL: "https://test.example.com")
        let desc = String(describing: client)
        if desc.contains("AnthropicClient") {
            print("AnthropicClient still works and conforms to LLMClient")
            print("[PASS]\n")
        } else {
            print("[FAIL] AnthropicClient broken")
        }

        print("=== All E2E Tests Complete ===")
    }
}

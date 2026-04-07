import Foundation
import OpenAgentSDK

// MARK: - Tests 1-4: Basic Agent Operations

struct BasicAgentTests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("1. Basic Non-Streaming Prompt")
        await testBasicNonStreaming(apiKey: apiKey, model: model, baseURL: baseURL)

        section("2. Basic Streaming Prompt")
        await testBasicStreaming(apiKey: apiKey, model: model, baseURL: baseURL)

        section("3. System Prompt Adherence")
        await testSystemPrompt(apiKey: apiKey, model: model, baseURL: baseURL)

        section("4. Multi-Turn Conversation")
        await testMultiTurn(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    // MARK: Test 1

    static func testBasicNonStreaming(apiKey: String, model: String, baseURL: String) async {
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1
        ))

        let result = await agent.prompt("Say exactly: Hello from OpenAgentSDK E2E test!")

        if result.status == .success {
            pass("Non-streaming returns .success status")
        } else {
            fail("Non-streaming returns .success status", "got \(result.status)")
        }

        if !result.text.isEmpty {
            pass("Non-streaming returns non-empty text")
        } else {
            fail("Non-streaming returns non-empty text", "text is empty")
        }

        if result.numTurns >= 1 {
            pass("Non-streaming tracks turn count")
        } else {
            fail("Non-streaming tracks turn count", "numTurns=\(result.numTurns)")
        }

        if result.durationMs > 0 {
            pass("Non-streaming tracks duration")
        } else {
            fail("Non-streaming tracks duration", "durationMs=\(result.durationMs)")
        }
    }

    // MARK: Test 2

    static func testBasicStreaming(apiKey: String, model: String, baseURL: String) async {
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1
        ))

        var partialCount = 0
        var fullText = ""
        var gotResult = false

        for await message in agent.stream("Count from 1 to 5, one number per line.") {
            switch message {
            case .partialMessage(let data):
                partialCount += 1
                fullText += data.text
            case .result(let data):
                gotResult = true
                if data.subtype == .success {
                    pass("Streaming returns .success result subtype")
                } else {
                    fail("Streaming returns .success result subtype", "got \(data.subtype)")
                }
            default:
                break
            }
        }

        if partialCount > 0 {
            pass("Streaming yields partialMessage events (\(partialCount) chunks)")
        } else {
            fail("Streaming yields partialMessage events", "no partials received")
        }

        if gotResult {
            pass("Streaming yields final result event")
        } else {
            fail("Streaming yields final result event")
        }

        if !fullText.isEmpty {
            pass("Streaming accumulates non-empty text")
        } else {
            fail("Streaming accumulates non-empty text")
        }
    }

    // MARK: Test 3

    static func testSystemPrompt(apiKey: String, model: String, baseURL: String) async {
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai,
            systemPrompt: "You must always respond in French. Never use any other language.",
            maxTurns: 1
        ))

        let result = await agent.prompt("Say hello.")

        if result.status == .success {
            pass("System prompt: agent returns success")
        } else {
            fail("System prompt: agent returns success", "got \(result.status)")
        }

        if agent.systemPrompt != nil {
            pass("Agent exposes systemPrompt property")
        } else {
            fail("Agent exposes systemPrompt property")
        }
    }

    // MARK: Test 4

    static func testMultiTurn(apiKey: String, model: String, baseURL: String) async {
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 3
        ))

        let result = await agent.prompt("What is 2+2? Reply with just the number.")

        if result.status == .success {
            pass("Multi-turn agent returns success")
        } else {
            fail("Multi-turn agent returns success", "got \(result.status)")
        }

        if result.text.contains("4") {
            pass("Multi-turn agent returns correct answer")
        } else {
            fail("Multi-turn agent returns correct answer", "text: \(result.text.prefix(100))")
        }
    }
}

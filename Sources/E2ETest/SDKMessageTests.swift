import Foundation
import OpenAgentSDK

// MARK: - Test 21: SDKMessage Streaming Event Types

struct SDKMessageTests {
    static func run(apiKey: String, model: String, baseURL: String) async {
        section("21. SDKMessage Streaming Event Types")
        await testSDKMessageTypes(apiKey: apiKey, model: model, baseURL: baseURL)
    }

    static func testSDKMessageTypes(apiKey: String, model: String, baseURL: String) async {
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey, model: model, baseURL: baseURL,
            provider: .openai, maxTurns: 1
        ))

        var receivedTypes: Set<String> = []

        for await message in agent.stream("Say hello in one word.") {
            switch message {
            case .partialMessage:
                receivedTypes.insert("partialMessage")
            case .result:
                receivedTypes.insert("result")
            case .assistant:
                receivedTypes.insert("assistant")
            case .toolUse:
                receivedTypes.insert("toolUse")
            case .toolResult:
                receivedTypes.insert("toolResult")
            case .system:
                receivedTypes.insert("system")
            case .userMessage, .toolProgress, .hookStarted, .hookProgress, .hookResponse, .taskStarted, .taskProgress, .authStatus, .filesPersisted, .localCommandOutput, .promptSuggestion, .toolUseSummary:
                break
            }
        }

        if receivedTypes.contains("partialMessage") {
            pass("SDKMessage: partialMessage type received")
        } else {
            fail("SDKMessage: partialMessage type received")
        }

        if receivedTypes.contains("result") {
            pass("SDKMessage: result type received")
        } else {
            fail("SDKMessage: result type received")
        }

        if receivedTypes.contains("assistant") {
            pass("SDKMessage: assistant type received")
        } else {
            fail("SDKMessage: assistant type received")
        }
    }
}

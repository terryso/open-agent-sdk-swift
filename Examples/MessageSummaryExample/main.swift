// MessageSummaryExample
//
// 演示 MessageSummary 在 LLMRequestStartedEvent 中的内容预览功能，包括：
//   1. MessageSummary 结构体的 role / contentLength / preview 字段
//   2. 通过 EventBus 订阅 LLMRequestStartedEvent 查看 message summaries
//   3. 多轮对话中观察 message summaries 的变化
//
// Run: swift run MessageSummaryExample
// Prerequisite: set CODEANY_API_KEY or ANTHROPIC_API_KEY in .env or environment

import Foundation
import OpenAgentSDK

@main
struct MessageSummaryExample {
    static func main() async throws {
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║  MessageSummary Example — 消息摘要与内容预览                   ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print()

        let dotEnv = loadDotEnv()
        let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
            ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
            ?? ""
        guard !apiKey.isEmpty else {
            print("  Skipping: set CODEANY_API_KEY or ANTHROPIC_API_KEY to run this example")
            print("  Usage: ANTHROPIC_API_KEY=sk-... swift run MessageSummaryExample")
            return
        }

        let defaultModel = getEnv("ANTHROPIC_MODEL", from: dotEnv)
            ?? getEnv("CODEANY_MODEL", from: dotEnv)
            ?? "claude-sonnet-4-6"
        let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

        try await part1_SyntheticMessageSummary()
        try await part2_LiveEventCapture(apiKey: apiKey, model: defaultModel, useOpenAI: useOpenAI, dotEnv: dotEnv)
    }

    // MARK: - Part 1: MessageSummary 结构体演示

    static func part1_SyntheticMessageSummary() async throws {
        print("--- Part 1: MessageSummary Structure ---")
        print()

        // 创建模拟的 MessageSummary 列表
        let summaries = [
            MessageSummary(role: "user", contentLength: 45, preview: "What is the capital of France?"),
            MessageSummary(role: "assistant", contentLength: 120, preview: "The capital of France is Paris. It has been..."),
            MessageSummary(role: "user", contentLength: 32, preview: "And what about Germany?"),
        ]

        for (i, summary) in summaries.enumerated() {
            print("  Message #\(i + 1):")
            print("    role:          \(summary.role)")
            print("    contentLength: \(summary.contentLength) chars")
            print("    preview:       \"\(summary.preview)\"")
            print()
        }

        // 演示 LLMRequestStartedEvent 包含 MessageSummary
        let event = LLMRequestStartedEvent(
            sessionId: "sess-demo",
            model: "claude-sonnet-4-6",
            systemPromptLength: 85,
            messageCount: 3,
            messages: summaries
        )

        print("  LLMRequestStartedEvent:")
        print("    model:              \(event.model)")
        print("    systemPromptLength: \(event.systemPromptLength)")
        print("    messageCount:       \(event.messageCount)")
        print("    messages:           \(event.messages.count) summaries included")
        print()
    }

    // MARK: - Part 2: 实时 Event 捕获

    static func part2_LiveEventCapture(apiKey: String, model: String, useOpenAI: Bool, dotEnv: [String: String]) async throws {
        print("--- Part 2: Live LLMRequestStartedEvent with MessageSummaries ---")
        print()

        let eventBus = EventBus()
        let eventStream = await eventBus.subscribe(LLMRequestStartedEvent.self)

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : getDefaultAnthropicBaseURL(from: dotEnv),
            provider: useOpenAI ? .openai : .anthropic,
            systemPrompt: "You are a helpful assistant. Keep responses brief.",
            permissionMode: .bypassPermissions,
            eventBus: eventBus
        ))

        // 后台打印 LLMRequestStartedEvent 的 message summaries
        let printer = _Concurrency.Task {
            var requestNum = 0
            for await event in eventStream {
                requestNum += 1
                print("  ┌─ LLM Request #\(requestNum) ─────────────────")
                print("  │ model: \(event.model)")
                print("  │ messages: \(event.messageCount)")
                for (i, msg) in event.messages.enumerated() {
                    print("  │   [\(i + 1)] \(msg.role) (\(msg.contentLength) chars): \"\(msg.preview)\"")
                }
                print("  └─────────────────────────────────────────")
                print()
            }
        }

        print("  Sending first prompt...")
        let result1 = await agent.prompt("What is 2+2?")

        print("  Sending second prompt (multi-turn)...")
        let _ = await agent.prompt("And what is that multiplied by 3?")

        printer.cancel()

        print()
        print("  Final turn count: \(result1.status)")
        print()
        print("=== MessageSummaryExample Completed ===")
    }
}

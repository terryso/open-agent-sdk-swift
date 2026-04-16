// StreamingAgent 示例
//
// 演示 AsyncStream 流式查询和 SDKMessage 事件模式匹配。
// 展示如何处理 partialMessage、toolUse、toolResult、result 等事件。
// 还展示预算追踪功能。
//
// 运行方式：swift run StreamingAgent
// 前提条件：在 .env 文件或环境变量中设置 CODEANY_API_KEY

import Foundation
import OpenAgentSDK

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

// 创建带预算限制的 Agent
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    systemPrompt: "You are a helpful assistant.",
    maxBudgetUsd: 0.50,  // 最多花费 $0.50
    permissionMode: .bypassPermissions
))

print("Streaming query started (budget limit: $0.50)...")
print("---")

// 流式查询：逐事件消费 AsyncStream<SDKMessage>
for await message in agent.stream("Write a haiku about programming.") {
    switch message {
    case .partialMessage(let data):
        // 增量文本片段 — 实时输出
        print(data.text, terminator: "")

    case .assistant(let data):
        // 完整的助手消息 — 包含模型信息和停止原因
        print("\n[Model: \(data.model), Stop: \(data.stopReason)]")

    case .toolUse(let data):
        // 工具调用请求
        print("[Tool Use: \(data.toolName), ID: \(data.toolUseId)]")
        print("  Input: \(data.input)")

    case .toolResult(let data):
        // 工具执行结果
        if data.isError {
            print("[Tool Error: \(data.content)]")
        } else {
            print("[Tool Result: \(data.content.prefix(100))...]")
        }

    case .result(let data):
        // 查询最终结果
        print("---")
        print("Stream completed!")
        print("  Subtype: \(data.subtype)")        // .success, .errorMaxBudgetUsd, etc.
        print("  Turns: \(data.numTurns)")
        print("  Duration: \(data.durationMs)ms")
        print("  Cost: $\(String(format: "%.6f", data.totalCostUsd))")
        if let usage = data.usage {
            print("  Input tokens: \(usage.inputTokens)")
            print("  Output tokens: \(usage.outputTokens)")
        }

        // 检查是否因预算超限而终止
        if data.subtype == SDKMessage.ResultData.Subtype.errorMaxBudgetUsd {
            print("  WARNING: Budget limit reached!")
        }

    case .system(let data):
        // 系统级事件
        print("[System: \(data.subtype) - \(data.message)]")

    case .userMessage, .toolProgress, .hookStarted, .hookProgress, .hookResponse, .taskStarted, .taskProgress, .authStatus, .filesPersisted, .localCommandOutput, .promptSuggestion, .toolUseSummary:
        break
    }
}

print()
print("Stream finished.")

// MultiToolExample 示例
//
// 演示 Agent 如何自主编排多个核心工具（Glob、Bash、Read）完成复杂任务。
// 使用流式 API（agent.stream()）实时展示每个工具调用和执行结果，
// 并在最终输出中包含 token 使用统计和成本信息。
//
// 运行方式：swift run MultiToolExample
// 前提条件：在 .env 文件或环境变量中设置 CODEANY_API_KEY

import Foundation
import OpenAgentSDK

// MARK: - 1. 配置 API 密钥

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

// MARK: - 2. 创建 Agent 并注册全部核心工具

// 系统提示引导 Agent 使用多种工具自主完成复杂分析任务
let systemPrompt = """
You are a code analysis assistant. When asked to analyze a project, you should:
1. Use Glob to discover file patterns and structure
2. Use Bash to run commands like 'find', 'wc -l', or similar for statistics
3. Use Read to examine specific files when needed
Provide a clear, organized summary of your findings.
"""

// 创建 Agent，使用 getAllBaseTools(tier: .core) 注册全部 10 个核心工具
// 核心工具包括：Read, Write, Edit, Glob, Grep, Bash, AskUser, ToolSearch, WebFetch, WebSearch
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? (getEnv("CODEANY_BASE_URL", from: dotEnv) ?? "https://open.bigmodel.cn/api/coding/paas/v4") : nil,
    provider: useOpenAI ? .openai : .anthropic,
    systemPrompt: systemPrompt,
    maxTurns: 15,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core)
))

print("=== MultiTool Example ===")
print("Agent created with all 10 core tools registered.")
print("Model: \(agent.model)")
print("Max turns: \(agent.maxTurns)")
print()
print("Starting multi-tool orchestration task...")
print("---")

// MARK: - 3. 发送需要多步骤编排的任务提示

// 这个提示需要 Agent 自主决定使用 Glob/Bash/Read 等多个工具完成
let prompt = """
Analyze the current project directory structure. Specifically:
1. Find all Swift source files (*.swift) in the project
2. Count the total number of Swift files
3. Report the overall directory structure
Provide a concise summary of the project organization.
"""

// MARK: - 4. 流式消费事件，实时展示工具调用和结果

// 工具调用计数器，用于统计 Agent 使用了哪些工具
var toolCallCount = 0

// 使用 for await 消费 AsyncStream<SDKMessage>
for await message in agent.stream(prompt) {
    switch message {
    case .partialMessage(let data):
        // 增量文本片段 — 实时输出 Agent 的思考过程
        print(data.text, terminator: "")

    case .assistant(let data):
        // 完整的助手消息 — 包含模型信息和停止原因
        print("\n[Model: \(data.model), Stop Reason: \(data.stopReason)]")

    case .toolUse(let data):
        // 工具调用请求 — Agent 自主决定调用某个工具
        toolCallCount += 1
        print("[Tool Call #\(toolCallCount): \(data.toolName)]")
        print("  Tool Use ID: \(data.toolUseId)")
        // 截断过长的输入参数以保持输出可读性
        let inputPreview = data.input.count > 200
            ? String(data.input.prefix(200)) + "..."
            : data.input
        print("  Input: \(inputPreview)")

    case .toolResult(let data):
        // 工具执行结果 — 展示工具返回的内容摘要
        if data.isError {
            print("[Tool Error: \(data.content.prefix(150))]")
        } else {
            // 截断长内容，只显示前 150 个字符的摘要
            let contentPreview = data.content.count > 150
                ? String(data.content.prefix(150)) + "..."
                : data.content
            print("[Tool Result: \(contentPreview)]")
        }

    case .result(let data):
        // 查询最终结果 — 包含完整的统计信息
        print("---")
        print()
        print("=== Task Complete ===")
        print()
        print("Status: \(data.subtype)")
        print("Total turns: \(data.numTurns)")
        print("Duration: \(data.durationMs)ms (\(String(format: "%.1f", Double(data.durationMs) / 1000.0))s)")
        print("Total cost: $\(String(format: "%.6f", data.totalCostUsd))")
        if let usage = data.usage {
            print("Input tokens: \(usage.inputTokens)")
            print("Output tokens: \(usage.outputTokens)")
        }
        print("Tool calls made: \(toolCallCount)")

        // 检查是否因特殊原因终止
        if data.subtype == SDKMessage.ResultData.Subtype.errorMaxTurns {
            print("WARNING: Agent reached maximum turn limit!")
        } else if data.subtype == SDKMessage.ResultData.Subtype.errorMaxBudgetUsd {
            print("WARNING: Budget limit reached!")
        }

    case .system(let data):
        // 系统级事件（如初始化、压缩边界等）
        print("[System Event: \(data.subtype) - \(data.message)]")
    }
}

print()
print("=== Stream Finished ===")
print("MultiTool example completed successfully.")

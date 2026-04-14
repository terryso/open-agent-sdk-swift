// PromptAPIExample 示例
//
// 演示使用 agent.prompt() 阻塞式 API 获取完整响应。
// 本示例注册了全部核心工具（getAllBaseTools(tier: .core)），
// 展示 Agent 在单次 prompt() 调用中自主执行工具后返回的完整 QueryResult。
// 与 BasicAgent 的区别：本示例注册了工具，Agent 可以自主调用工具完成任务。
// 与 MultiToolExample 的区别：本示例使用阻塞式 API，一次性获取最终结果。
//
// 运行方式：swift run PromptAPIExample
// 前提条件：在 .env 文件或环境变量中设置 CODEANY_API_KEY

import Foundation
import OpenAgentSDK

// MARK: - 配置 API Key

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

// MARK: - 创建 Agent 并注册核心工具

// 系统提示引导 Agent 使用工具分析项目结构
let systemPrompt = """
You are a project analysis assistant. When asked to analyze a project, you should:
1. Use Glob to discover file patterns
2. Use Read to examine specific files when needed
3. Use Bash to run commands for statistics if needed
Provide a clear, concise summary of your findings.
"""

// 创建 Agent，使用 getAllBaseTools(tier: .core) 注册全部 10 个核心工具
// 核心工具包括：Read, Write, Edit, Glob, Grep, Bash, AskUser, ToolSearch, WebFetch, WebSearch
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    systemPrompt: systemPrompt,
    maxTurns: 10,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core)
))

print("=== PromptAPIExample ===")
print("Agent created with all core tools registered.")
print("  Model: \(agent.model)")
print("  Max turns: \(agent.maxTurns)")
print()

// MARK: - 发送阻塞式查询

// 使用 agent.prompt() 阻塞式 API — Agent 将自主执行工具并返回最终结果
// prompt() 返回完整的 QueryResult，包含响应文本、工具执行结果、统计信息等
print("Sending blocking prompt...")
print("---")

let result = await agent.prompt(
    "Analyze the project structure in the current directory. Find all Swift source files and provide a brief summary of the project organization."
)

// MARK: - 展示 QueryResult 完整字段

// 检查查询状态 — 演示如何处理可能的错误情况
// QueryStatus 枚举：.success, .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd
if result.status != .success {
    print("⚠ Query completed with status: \(result.status)")
    print("  Response may be incomplete or contain errors.")
    print()
}

// 响应文本 — 包含 Agent 综合工具执行结果后的完整响应
print("=== Agent Response ===")
print(result.text)
print()

// 查询统计信息
print("=== Query Statistics ===")
print("  Status: \(result.status)")
// 轮次数（如果 Agent 调用了工具，轮次 > 1）
print("  Turns: \(result.numTurns)")
// 耗时（毫秒和秒）
print("  Duration: \(result.durationMs)ms (\(String(format: "%.2f", Double(result.durationMs) / 1000.0))s)")
// Token 用量
print("  Input tokens: \(result.usage.inputTokens)")
print("  Output tokens: \(result.usage.outputTokens)")
// 估算成本
print("  Estimated cost: $\(String(format: "%.6f", result.totalCostUsd))")

// BasicAgent 示例
//
// 演示 Agent 创建、单次提示和响应处理。
// 展示 Anthropic 和 OpenAI 兼容 API 两种提供商的使用方式。
//
// 运行方式：swift run BasicAgent
// 前提条件：设置 ANTHROPIC_API_KEY 环境变量（或在代码中指定 apiKey）

import Foundation
import OpenAgentSDK

// MARK: - 方式 1：使用 Anthropic（默认提供商）

// 从环境变量读取 API key，或直接传入
let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "sk-..."

// 创建 Agent，指定模型和系统提示
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: "claude-sonnet-4-6",
    systemPrompt: "You are a helpful assistant. Be concise.",
    maxTurns: 10,
    permissionMode: .bypassPermissions
))

print("Agent created: \(agent)")
print("  Model: \(agent.model)")
print("  Max turns: \(agent.maxTurns)")
print()

// 发送阻塞式查询并等待完整响应
print("Sending prompt...")
let result = await agent.prompt("Explain what an AI agent is in one paragraph.")

// 处理 QueryResult
print("Response: \(result.text)")
print()
print("--- Query Statistics ---")
print("  Status: \(result.status)")           // .success, .errorMaxTurns, etc.
print("  Turns: \(result.numTurns)")
print("  Duration: \(result.durationMs)ms")
print("  Input tokens: \(result.usage.inputTokens)")
print("  Output tokens: \(result.usage.outputTokens)")
print("  Cost: $\(String(format: "%.6f", result.totalCostUsd))")

// MARK: - 方式 2：使用 OpenAI 兼容 API

// OpenAI 兼容提供商支持 GLM、Ollama、OpenRouter 等服务
let openaiAgent = createAgent(options: AgentOptions(
    apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "your-key",
    model: "glm-4-flash",
    baseURL: "https://open.bigmodel.cn/api/paas/v4",
    provider: .openai
))

print()
print("OpenAI-compatible agent created: \(openaiAgent)")

// MARK: - 方式 3：使用环境变量默认配置

// 如果已设置 ANTHROPIC_API_KEY 环境变量，可以省略所有参数
let defaultAgent = createAgent()
print("Default agent: \(defaultAgent)")

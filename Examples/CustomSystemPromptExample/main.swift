// CustomSystemPromptExample 示例
//
// 演示如何使用自定义系统提示（systemPrompt）创建专业化 Agent。
// 本示例以"代码审查专家"角色为例，展示系统提示如何定制 Agent 的行为风格和输出格式。
// 使用阻塞式 agent.prompt() API，适合简单的一问一答场景。
//
// 运行方式：swift run CustomSystemPromptExample
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

// MARK: - 创建专业化 Agent

// 使用自定义 systemPrompt 创建一个代码审查专家 Agent
// 系统提示明确定义了角色、回复风格和输出格式要求
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? (getEnv("CODEANY_BASE_URL", from: dotEnv) ?? "https://open.bigmodel.cn/api/coding/paas/v4") : nil,
    provider: useOpenAI ? .openai : .anthropic,
    systemPrompt: """
    You are a senior code reviewer with 15 years of experience in Swift and system programming.

    Your review style:
    - Be concise and direct — avoid unnecessary praise or filler
    - Focus on correctness, performance, and maintainability
    - Always provide actionable suggestions

    Your output format:
    1. **Summary** — One sentence verdict
    2. **Issues** — Numbered list of problems (if any), each with severity [High/Med/Low]
    3. **Suggestions** — Numbered list of improvements
    4. **Verdict** — APPROVE or REQUEST CHANGES

    Only answer questions related to code, software architecture, or programming.
    If asked about unrelated topics, politely redirect to code review.
    """,
    maxTurns: 10,
    permissionMode: .bypassPermissions
    // 注意：不传 tools 参数（默认为 nil），本示例不注册任何工具，突出系统提示效果
))

print("=== CustomSystemPromptExample ===")
print("Agent created with custom system prompt (Code Review Expert)")
print("  Model: \(agent.model)")
print("  Max turns: \(agent.maxTurns)")
print()

// MARK: - 发送阻塞式查询

// 发送一段代码片段请求审查，验证 Agent 按系统提示中定义的格式回复
let codeSnippet = """
func factorial(_ n: Int) -> Int {
    var result = 1
    for i in 1...n {
        result *= i
    }
    return result
}
"""

print("Sending code review request...")
print("---")
let result = await agent.prompt(
    "Please review this Swift function: \(codeSnippet)"
)

// MARK: - 展示 QueryResult 完整字段

// 响应文本 — 应体现代码审查专家的角色和格式
print("=== Agent Response ===")
print(result.text)
print()

// 查询统计信息
print("=== Query Statistics ===")
print("  Status: \(result.status)")
print("  Turns: \(result.numTurns)")
print("  Duration: \(result.durationMs)ms (\(String(format: "%.2f", Double(result.durationMs) / 1000.0))s)")
print("  Input tokens: \(result.usage.inputTokens)")
print("  Output tokens: \(result.usage.outputTokens)")
print("  Estimated cost: $\(String(format: "%.6f", result.totalCostUsd))")

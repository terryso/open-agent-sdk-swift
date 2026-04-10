// BasicAgent 示例
//
// 演示 Agent 创建、单次提示和响应处理。
// 展示 Anthropic 和 OpenAI 兼容 API 两种提供商的使用方式。
//
// 运行方式：swift run BasicAgent
// 前提条件：在 .env 文件或环境变量中设置 API Key

import Foundation
import OpenAgentSDK

// MARK: - 加载 .env 文件

let dotEnv = loadDotEnv()

// MARK: - 方式 1：使用 Anthropic（默认提供商）

let anthropicKey = getEnv("ANTHROPIC_API_KEY", from: dotEnv)

if let apiKey = anthropicKey, apiKey.hasPrefix("sk-") {
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

    print("Sending prompt...")
    let result = await agent.prompt("Explain what an AI agent is in one paragraph.")

    print("Response: \(result.text)")
    print()
    print("--- Query Statistics ---")
    print("  Status: \(result.status)")
    print("  Turns: \(result.numTurns)")
    print("  Duration: \(result.durationMs)ms")
    print("  Input tokens: \(result.usage.inputTokens)")
    print("  Output tokens: \(result.usage.outputTokens)")
    print("  Cost: $\(String(format: "%.6f", result.totalCostUsd))")
} else {
    print("[SKIP] Anthropic example — ANTHROPIC_API_KEY not set.")
    print("  To enable: export ANTHROPIC_API_KEY=sk-ant-...")
}

// MARK: - 方式 2：使用 OpenAI 兼容 API（GLM、Ollama、OpenRouter 等）

let codeanyKey = getEnv("CODEANY_API_KEY", from: dotEnv)

if let apiKey = codeanyKey, !apiKey.isEmpty {
    let baseURL = getEnv("CODEANY_BASE_URL", from: dotEnv) ?? "https://open.bigmodel.cn/api/coding/paas/v4"
    let model = getEnv("CODEANY_MODEL", from: dotEnv) ?? "glm-5.1"

    let openaiAgent = createAgent(options: AgentOptions(
        apiKey: apiKey,
        model: model,
        baseURL: baseURL,
        provider: .openai
    ))

    print()
    print("OpenAI-compatible agent created: \(openaiAgent)")
} else {
    print("[SKIP] OpenAI-compatible example — CODEANY_API_KEY not set.")
    print("  To enable: export CODEANY_API_KEY=your-key")
}

// MARK: - 方式 3：使用环境变量默认配置

// 任一 key 存在即可省略所有参数
if anthropicKey != nil || codeanyKey != nil {
    let defaultAgent = createAgent()
    print("Default agent: \(defaultAgent)")
} else {
    print()
    print("[ERROR] No API key configured. Please set one of:")
    print("  export ANTHROPIC_API_KEY=sk-ant-...")
    print("  export CODEANY_API_KEY=your-key")
}

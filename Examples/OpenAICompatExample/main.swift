// OpenAICompatExample 示例
//
// 演示如何使用 OpenAI 兼容 API 提供商（DeepSeek, Qwen, vLLM, Ollama, GLM 等），
// 通过同一套 Agent API 与非 Anthropic 后端通信：
//   1. 提供商配置对比：Anthropic vs OpenAI 兼容提供商的 AgentOptions 配置
//   2. 使用 agent.prompt() 发送查询，打印响应文本和用量统计
//   3. 使用 agent.stream() 流式接收响应，收集 partialMessage 和 result 事件
//   4. 自定义工具调用：定义 Codable 输入工具，验证工具调用的格式转换
//
// Demonstrates how to use OpenAI-compatible API providers (DeepSeek, Qwen, vLLM, Ollama, GLM, etc.)
// through the same Agent API to communicate with non-Anthropic backends:
//   1. Provider configuration comparison: Anthropic vs OpenAI-compatible AgentOptions
//   2. Use agent.prompt() to send a query, print response text and usage stats
//   3. Use agent.stream() for streaming response, collect partialMessage and result events
//   4. Custom tool use: define a Codable-input tool, verify tool call format conversion
//
// 运行方式：swift run OpenAICompatExample
// 说明：所有 Parts 都需要有效的 API Key（支持 CODEANY_API_KEY 或 ANTHROPIC_API_KEY）

import Foundation
import OpenAgentSDK

// MARK: - 配置 API Key / Configure API Key

// 加载 .env 文件和环境变量
// Load .env file and environment variables
let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

// 当检测到 CODEANY_API_KEY 时，使用 OpenAI 兼容提供商
// When CODEANY_API_KEY is detected, use OpenAI-compatible provider
let openAIBaseURL = getDefaultOpenAIBaseURL(from: dotEnv)

print("=== OpenAICompatExample ===")
print()

// MARK: - Part 1: Provider Configuration Comparison（提供商配置对比）

print("--- Part 1: Provider Configuration Comparison ---")
print()

// 对比 Anthropic 和 OpenAI 兼容提供商的 AgentOptions 配置
// Compare AgentOptions configuration for Anthropic vs OpenAI-compatible providers

// Anthropic 提供商配置（默认）
// Anthropic provider configuration (default)
// let anthropicOptions = AgentOptions(
//     apiKey: apiKey,
//     model: "claude-sonnet-4-6",
//     provider: .anthropic,
//     permissionMode: .bypassPermissions
// )

// OpenAI 兼容提供商配置
// OpenAI-compatible provider configuration
// let openAIOptions = AgentOptions(
//     apiKey: apiKey,
//     model: "deepseek-chat",
//     baseURL: "https://api.deepseek.com/v1",
//     provider: .openai,
//     permissionMode: .bypassPermissions
// )

// 关键区别：只需设置 provider: .openai 和 baseURL 即可切换提供商
// Key difference: just set provider: .openai and baseURL to switch providers

let currentProvider: String = useOpenAI ? "OpenAI-compatible (\(openAIBaseURL))" : "Anthropic (default)"
print("Current provider: \(currentProvider)")
print("Model: \(defaultModel)")
print("useOpenAI flag: \(useOpenAI)")
print()

// 验证配置：useOpenAI 标志决定了使用哪个提供商
// Verify config: useOpenAI flag determines which provider to use
assert(useOpenAI == (getEnv("CODEANY_API_KEY", from: dotEnv) != nil), "useOpenAI should match CODEANY_API_KEY detection")
print("Assertion: useOpenAI flag matches CODEANY_API_KEY detection: PASS")
print()
print("Part 1: Provider configuration comparison: PASS")
print()

// MARK: - Part 2: Prompt with OpenAI Provider（使用 OpenAI 提供商发送 Prompt）

print("--- Part 2: Prompt with OpenAI Provider ---")
print()

// 创建 Agent，使用 OpenAI 兼容提供商（或 Anthropic 作为回退）
// Create Agent with OpenAI-compatible provider (or Anthropic as fallback)
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? openAIBaseURL : nil,
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions
))

print("[Created Agent with provider: \(useOpenAI ? ".openai" : ".anthropic"), model: \(defaultModel)]")
print()

// 发送简单查询
// Send a simple query
print("[Sending prompt: 'What is 2 + 2? Answer with just the number.']")
let result = await agent.prompt("What is 2 + 2? Answer with just the number.")

print()
print("=== Prompt Result ===")
print("Response text: \(result.text)")
print("Input tokens:  \(result.usage.inputTokens)")
print("Output tokens: \(result.usage.outputTokens)")
print("Duration: \(result.durationMs)ms")
print()

// 验证响应非空
// Assert response is non-empty
assert(!result.text.isEmpty, "Prompt response text should not be empty")
print("Assertion: response text is non-empty: PASS")
print()
print("Part 2: Prompt with OpenAI provider: PASS")
print()

// MARK: - Part 3: Streaming with OpenAI Provider（使用 OpenAI 提供商流式响应）

print("--- Part 3: Streaming with OpenAI Provider ---")
print()

// 使用 stream() 流式接收响应，收集 SDKMessage 事件
// Use stream() for streaming response, collect SDKMessage events
print("[Streaming prompt: 'Count from 1 to 5, one number per line.']")
var streamedText = ""
var streamInputTokens = 0
var streamOutputTokens = 0

for await message in agent.stream("Count from 1 to 5, one number per line.") {
    switch message {
    case .partialMessage(let data):
        // 增量文本片段，实时打印
        // Text delta, print in real time
        streamedText += data.text
        print(data.text, terminator: "")
    case .result(let data):
        // 流式结果统计
        // Streaming result stats
        print()
        print()
        print("=== Stream Result ===")
        print("Subtype: \(data.subtype)")
        print("Turns: \(data.numTurns)")
        print("Duration: \(data.durationMs)ms")
        if let usage = data.usage {
            streamInputTokens = usage.inputTokens
            streamOutputTokens = usage.outputTokens
            print("Input tokens:  \(usage.inputTokens)")
            print("Output tokens: \(usage.outputTokens)")
        }
    default:
        break
    }
}

print()
print("Full streamed text: \(streamedText)")
print()

// 验证流式响应非空
// Assert streaming response is non-empty
assert(!streamedText.isEmpty, "Streamed response should not be empty")
print("Assertion: streaming response is non-empty: PASS")
print()
print("Part 3: Streaming with OpenAI provider: PASS")
print()

// MARK: - Part 4: Tool Use with OpenAI Provider（使用 OpenAI 提供商进行工具调用）

print("--- Part 4: Tool Use with OpenAI Provider ---")
print()

// 定义一个简单的自定义工具，使用 Codable 输入类型
// Define a simple custom tool with Codable input type
struct GreetInput: Codable {
    let name: String
    let language: String?
}

// 使用 defineTool() 注册工具
// Register tool using defineTool()
let greetTool = defineTool(
    name: "greet_person",
    description: "Generate a greeting message for a person",
    inputSchema: [
        "type": "object",
        "properties": [
            "name": ["type": "string", "description": "The person's name"],
            "language": ["type": "string", "description": "Language for greeting, e.g. 'en', 'zh'"]
        ],
        "required": ["name"]
    ],
    isReadOnly: true
) { (input: GreetInput, context: ToolContext) -> String in
    // 根据语言生成问候语
    // Generate greeting based on language
    let lang = input.language ?? "en"
    if lang == "zh" {
        return "你好，\(input.name)！欢迎使用 OpenAgentSDK。"
    } else {
        return "Hello, \(input.name)! Welcome to OpenAgentSDK."
    }
}

print("[Defined greet_tool with Codable GreetInput struct]")

// 创建带有自定义工具的 Agent
// Create Agent with custom tool
let toolAgent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? openAIBaseURL : nil,
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions,
    tools: [greetTool]
))

print("[Created Agent with greet_person tool and \(useOpenAI ? ".openai" : ".anthropic") provider]")
print()

// 发送触发工具调用的 prompt
// Send a prompt that triggers the tool
print("[Sending prompt: 'Please greet Alice using the greet_person tool.']")
let toolResult = await toolAgent.prompt("Please greet Alice using the greet_person tool.")

print()
print("=== Tool Use Result ===")
print("Response text: \(toolResult.text)")
print("Input tokens:  \(toolResult.usage.inputTokens)")
print("Output tokens: \(toolResult.usage.outputTokens)")
print("numTurns:      \(toolResult.numTurns)")
print()

// 验证工具被调用且响应包含问候内容
// Verify tool was called and response contains greeting
let responseContainsGreeting = toolResult.text.lowercased().contains("hello")
    || toolResult.text.lowercased().contains("你好")
    || toolResult.text.lowercased().contains("alice")
assert(responseContainsGreeting, "Tool use response should contain greeting output (hello/Alice)")
print("Assertion: tool use response contains greeting output: PASS")
print()
print("Part 4: Tool use with OpenAI provider: PASS")
print()

print("=== OpenAICompatExample Complete ===")

// SubagentExample 示例
//
// 演示主 Agent 如何通过 Agent 工具（createAgentTool()）委派子代理执行专门任务。
// 主 Agent 作为协调者，接收用户请求后通过 Agent 工具生成子代理（Explore 类型），
// 子代理使用受限的工具集（Read、Glob、Grep、Bash）完成委派任务，
// 结果返回给主 Agent，主 Agent 基于子代理结果生成最终回复。
//
// 运行方式：swift run SubagentExample
// 前提条件：在 .env 文件或环境变量中设置 CODEANY_API_KEY

import Foundation
import OpenAgentSDK

// MARK: - 1. 配置 API 密钥

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."

// MARK: - 2. 创建主 Agent（协调者）并注册 Agent 工具

// 系统提示引导主 Agent 作为协调者，通过 Agent 工具委派子代理执行分析任务
let systemPrompt = """
You are a coordinator agent. When given a task, you should delegate it to a sub-agent \
using the Agent tool. The Agent tool will spawn a specialized agent (e.g., "Explore" type) \
that can use Read, Glob, Grep, and Bash tools to investigate the codebase. \
After the sub-agent returns its findings, summarize the results for the user. \
Always use the Agent tool for investigation tasks rather than doing it yourself.
"""

// 创建主 Agent，注册核心工具 + Agent 工具
// - getAllBaseTools(tier: .core): 10 个核心工具（Read, Write, Edit, Glob, Grep, Bash 等）
// - createAgentTool(): Agent 工具，允许 LLM 生成子代理执行委派任务
// 子代理（如 Explore 类型）仅使用受限工具集：Read, Glob, Grep, Bash
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: "claude-sonnet-4-6",
    systemPrompt: systemPrompt,
    maxTurns: 10,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core) + [createAgentTool()]
))

print("=== SubagentExample ===")
print("Main agent (coordinator) created with Agent tool registered.")
print("  Model: \(agent.model)")
print("  Max turns: \(agent.maxTurns)")
print()
print("The coordinator will delegate analysis to an Explore sub-agent.")
print("---")

// MARK: - 3. 发送需要子代理委派的任务提示

// 这个提示引导主 Agent 使用 Agent 工具委派一个 Explore 类型的子代理
// 子代理将使用 Glob/Grep/Read/Bash 工具分析项目结构
let prompt = """
Explore the current project directory. Find all Swift source files, \
examine the project structure, and provide a summary of the codebase organization. \
Use the Agent tool to delegate this task to an Explore sub-agent.
"""

// MARK: - 4. 流式消费事件，实时展示主 Agent 和子代理的执行过程

// 工具调用计数器，区分 Agent 工具调用和其他工具调用
var agentToolCalls = 0
var otherToolCalls = 0

// 使用 for await 消费 AsyncStream<SDKMessage>
for await message in agent.stream(prompt) {
    switch message {
    case .partialMessage(let data):
        // 增量文本片段 — 实时输出主 Agent 的思考过程
        print(data.text, terminator: "")

    case .assistant(let data):
        // 完整的助手消息 — 包含模型信息和停止原因
        print("\n[Model: \(data.model), Stop Reason: \(data.stopReason)]")

    case .toolUse(let data):
        // 工具调用请求 — 特别标注 Agent 工具调用（子代理委派）
        if data.toolName == "Agent" {
            agentToolCalls += 1
            print("[Sub-agent Delegation #\(agentToolCalls): \(data.toolName)]")
            print("  Tool Use ID: \(data.toolUseId)")
            // 展示子代理的输入参数（prompt, description, subagent_type 等）
            let inputPreview = data.input.count > 300
                ? String(data.input.prefix(300)) + "..."
                : data.input
            print("  Input: \(inputPreview)")
        } else {
            otherToolCalls += 1
            print("[Tool Call: \(data.toolName)]")
            print("  Tool Use ID: \(data.toolUseId)")
            let inputPreview = data.input.count > 200
                ? String(data.input.prefix(200)) + "..."
                : data.input
            print("  Input: \(inputPreview)")
        }

    case .toolResult(let data):
        // 工具执行结果 — 子代理的输出也通过此事件返回
        if data.isError {
            print("[Tool Error: \(data.content.prefix(150))]")
        } else {
            // 截断长内容，只显示前 200 个字符的摘要
            let contentPreview = data.content.count > 200
                ? String(data.content.prefix(200)) + "..."
                : data.content
            print("[Tool Result: \(contentPreview)]")
        }

    case .result(let data):
        // 查询最终结果 — 包含主 Agent 的完整统计信息
        print("---")
        print()
        print("=== Task Complete ===")
        print()
        print("Status: \(data.subtype)")
        print("Total turns: \(data.numTurns)")
        print("Duration: \(data.durationMs)ms (\(String(format: "%.1f", Double(data.durationMs) / 1000.0))s)")
        print("Total cost: $\(String(format: "%.6f", data.totalCostUsd))")
        // data.usage 是 Optional<TokenUsage>，需安全解包
        if let usage = data.usage {
            print("Input tokens: \(usage.inputTokens)")
            print("Output tokens: \(usage.outputTokens)")
        }
        print("Sub-agent delegations: \(agentToolCalls)")
        print("Other tool calls: \(otherToolCalls)")

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
print("SubagentExample completed successfully.")

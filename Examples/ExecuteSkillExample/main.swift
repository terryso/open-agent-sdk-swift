// ExecuteSkillExample 示例
//
// 演示如何使用 Agent.executeSkill() 直接执行技能，跳过 LLM 技能发现环节。
//
// 与 agent.prompt() + SkillTool 的方式不同：
//   - prompt() 方式：LLM 先读取 SkillTool 描述 → 决定调用 Skill → 读取 promptTemplate → 执行（2 轮交互）
//   - executeSkill() 方式：直接将 skill.promptTemplate 注入为用户消息，LLM 立即执行（1 轮交互）
//
// 适用场景：CLI slash command 解析、已知技能名的批量调用、减少 token 开销
//
// 本示例同时演示：
//   1. 从 skillDirectories 自动发现技能（polyv-live-cli）
//   2. 编程式注册自定义技能
//   3. 通过 executeSkill() 直接执行，支持 args 传参、toolRestrictions、modelOverride
//   4. 执行后自动恢复 agent 原始状态（allowedTools、model）
//   5. 通过 executeSkillStream() 流式执行技能，实时接收 SDKMessage 事件
//
// 运行方式：swift run ExecuteSkillExample
// 前提条件：在 .env 文件或环境变量中设置 CODEANY_API_KEY 或 ANTHROPIC_API_KEY

import Foundation
import OpenAgentSDK

// MARK: - 配置 API Key

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("ANTHROPIC_MODEL", from: dotEnv)
    ?? getEnv("CODEANY_MODEL", from: dotEnv)
    ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

print("=== ExecuteSkillExample ===")
print()

// MARK: - Part 1: 创建 Agent 并注册技能

// 编程式注册一个自定义 "greet" 技能
let greetSkill = Skill(
    name: "greet",
    description: "Generate a personalized greeting message",
    aliases: ["hello", "hi"],
    promptTemplate: """
    Generate a warm, personalized greeting message. Be creative and friendly.
    Include a fun fact or an encouraging quote in the greeting.
    """
)

let registry = SkillRegistry()
registry.register(greetSkill)

let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : getDefaultAnthropicBaseURL(from: dotEnv),
    provider: useOpenAI ? .openai : .anthropic,
    maxTurns: 25,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core),
    skillRegistry: registry
))

print("--- Part 1: Agent created with skill registry ---")
print("  Registered skills: \(registry.allSkills.map(\.name).joined(separator: ", "))")
print()

// MARK: - Part 2: executeSkill() 基本用法

print("--- Part 2: Direct executeSkill() (no LLM discovery round-trip) ---")
print("  Calling: agent.executeSkill(\"greet\")")
print()

let result1 = await agent.executeSkill("greet")

print("=== Response ===")
print(result1.text)
print()
print("  Status: \(result1.status)")
print("  Turns: \(result1.numTurns)")
print("  Duration: \(result1.durationMs)ms")
print("  Cost: $\(String(format: "%.6f", result1.totalCostUsd))")
if let errors = result1.errors, !errors.isEmpty {
    print("  Errors: \(errors)")
}
print()

// MARK: - Part 3: 带参数执行 + 别名解析

print("--- Part 3: executeSkill() with args and alias resolution ---")
print("  Calling: agent.executeSkill(\"hello\", args: \"welcome a new team member named Alice\")")
print()

let result2 = await agent.executeSkill("hello", args: "welcome a new team member named Alice")

print("=== Response ===")
print(result2.text)
print()
print("  Status: \(result2.status)")
print("  Cost: $\(String(format: "%.6f", result2.totalCostUsd))")
if let errors = result2.errors, !errors.isEmpty {
    print("  Errors: \(errors)")
}
print()

// MARK: - Part 4: 错误处理

print("--- Part 4: Error Handling ---")

// 技能不存在
let result3 = await agent.executeSkill("nonexistent")
print("  nonexistent skill → status: \(result3.status), error: \(result3.errors?.first ?? "none")")

// 技能不可用
let unavailableSkill = Skill(
    name: "unavailable",
    description: "A skill that is never available",
    isAvailable: { false },
    promptTemplate: "This should never execute"
)
registry.register(unavailableSkill)
let result4 = await agent.executeSkill("unavailable")
print("  unavailable skill → status: \(result4.status), error: \(result4.errors?.first ?? "none")")
print()

// MARK: - Part 5: 带 toolRestrictions 和 modelOverride 的技能

print("--- Part 5: Skill with toolRestrictions and modelOverride ---")

let restrictedSkill = Skill(
    name: "read-only-analysis",
    description: "Analyze using read-only tools with a stronger model",
    toolRestrictions: [.bash, .read, .write],
    modelOverride: defaultModel,
    promptTemplate: "Analyze the current project structure and summarize what you find."
)
registry.register(restrictedSkill)

// 验证执行前后 agent 状态恢复（model 属性是 public 的）
print("  Before executeSkill: model=\(agent.model)")
_ = await agent.executeSkill("read-only-analysis")
print("  After executeSkill:  model=\(agent.model) (restored)")
print()

// MARK: - Part 6: executeSkillStream() 流式执行

print("--- Part 6: Streaming executeSkillStream() ---")
print("  Calling: agent.executeSkillStream(\"greet\")")
print()

let stream = agent.executeSkillStream("greet")
var streamedText = ""
var streamTurns = 0
var streamCost: Double = 0
var streamDuration: Int = 0
for await message in stream {
    switch message {
    case .partialMessage(let data):
        // 实时输出流式文本片段
        print(data.text, terminator: "")
        fflush(stdout)
    case .result(let data):
        streamedText = data.text
        streamTurns = data.numTurns
        streamCost = data.totalCostUsd
        streamDuration = data.durationMs
    default:
        break
    }
}
print()
print()
print("  Status: success")
print("  Turns: \(streamTurns)")
print("  Duration: \(streamDuration)ms")
print("  Cost: $\(String(format: "%.6f", streamCost))")
print()

print("=== ExecuteSkillExample Completed ===")

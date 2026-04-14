// SkillsExample 示例
//
// 演示如何使用 SDK 的技能系统（Skills System），包括：
//   1. 创建 SkillRegistry 并注册所有内置技能（BuiltInSkills）
//   2. 列出所有已注册技能和仅用户可调用技能
//   3. 注册自定义技能并按名称/别名查找
//   4. 配置 Agent 使用 SkillTool，通过 LLM 自动发现并执行技能
//
// 运行方式：swift run SkillsExample
// 前提条件：在 .env 文件或环境变量中设置 CODEANY_API_KEY 或 ANTHROPIC_API_KEY

import Foundation
import OpenAgentSDK

// MARK: - 配置 API Key

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

print("=== SkillsExample ===")
print()

// MARK: - Part 1: 创建 SkillRegistry 并注册内置技能

// 创建技能注册表实例
// SkillRegistry 是线程安全的技能管理器，支持按名称和别名查找技能
let registry = SkillRegistry()

// 注册所有 5 个内置技能：commit、review、simplify、debug、test
// BuiltInSkills 提供预定义的 Skill 实例，开箱即用
registry.register(BuiltInSkills.commit)
registry.register(BuiltInSkills.review)
registry.register(BuiltInSkills.simplify)
registry.register(BuiltInSkills.debug)
registry.register(BuiltInSkills.test)

print("--- Part 1: All Registered Skills (\(registry.allSkills.count)) ---")
// allSkills 返回所有已注册的技能（按注册顺序排列）
for skill in registry.allSkills {
    print("  [\(skill.name)] \(skill.description)")
    print("    Aliases: \(skill.aliases.isEmpty ? "(none)" : skill.aliases.joined(separator: ", "))")
}

print()

// userInvocableSkills 只返回 userInvocable == true 且 isAvailable() == true 的技能
// 这是与 allSkills 的关键区别：allSkills 包含所有技能，
// 而 userInvocableSkills 过滤掉不可用或非用户可调用的技能
print("--- Part 1b: User-Invocable Skills (\(registry.userInvocableSkills.count)) ---")
for skill in registry.userInvocableSkills {
    print("  [\(skill.name)] \(skill.description)")
}

print()

// MARK: - Part 2: 注册自定义技能并查找

// 创建一个自定义 "explain" 技能
// Skill 构造函数接受 name、description、aliases、promptTemplate 等参数
// aliases 允许通过多个名称查找同一技能（如 "eli5" 别名）
let explainSkill = Skill(
    name: "explain",
    description: "Explain code or concepts in simple terms, as if teaching a beginner.",
    aliases: ["eli5"],
    userInvocable: true,
    promptTemplate: """
    You are an expert teacher. Explain the following code or concept in simple, \
    beginner-friendly terms. Use analogies and examples where helpful. \
    Structure your explanation with:
    1. A brief summary in one sentence
    2. A detailed explanation with examples
    3. Key takeaways
    """
)

// 注册自定义技能到注册表
registry.register(explainSkill)

// 验证自定义技能已出现在 allSkills 列表中
print("--- Part 2: After Custom Skill Registration (\(registry.allSkills.count) skills) ---")
for skill in registry.allSkills {
    print("  - \(skill.name)")
}

print()

// 演示通过精确名称查找技能
if let foundByName = registry.find("explain") {
    print("  Found by exact name 'explain': \(foundByName.description)")
}

// 演示通过别名查找技能
// find() 方法同时支持按名称和按别名查找
if let foundByAlias = registry.find("eli5") {
    print("  Found by alias 'eli5': \(foundByAlias.name) -> \(foundByAlias.description)")
}

print()

// MARK: - Part 3: Agent 技能调用

// 创建包含 SkillTool 的工具集
// getAllBaseTools(tier: .core) 返回所有核心工具
// createSkillTool(registry:) 创建技能工具，允许 LLM 发现和执行注册的技能
var tools = getAllBaseTools(tier: .core)
tools.append(createSkillTool(registry: registry))

// 创建 Agent，配置 SkillTool 和核心工具
// 使用 bypassPermissions 模式以便示例运行时无需权限确认
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    systemPrompt: "You are a helpful assistant with access to skills. When the user asks you to use a skill, discover and execute it using the Skill tool.",
    maxTurns: 25,
    permissionMode: .bypassPermissions,
    tools: tools
))

print("--- Part 3: Agent Skill Invocation ---")
print("Sending query to agent: 'Use the commit skill to analyze current changes'")
print()

// 发送查询让 Agent 通过 SkillTool 调用技能
// Agent 会自动发现并执行注册的技能，技能的 promptTemplate 会作为新提示注入
let result = await agent.prompt("Use the commit skill to analyze current changes")

// 打印 Agent 的响应文本
print("=== Agent Response ===")
print(result.text)
print()

// 打印查询统计信息
print("=== Query Statistics ===")
print("  Status: \(result.status)")
print("  Turns: \(result.numTurns)")
print("  Duration: \(result.durationMs)ms (\(String(format: "%.2f", Double(result.durationMs) / 1000.0))s)")
print("  Cost: $\(String(format: "%.6f", result.totalCostUsd))")
print()
print("=== SkillsExample Completed ===")

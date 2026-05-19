// PolyvLiveExample 示例
//
// 演示如何使用 SDK 内置的文件系统技能发现机制加载和执行 SKILL.md 技能。
//
// SDK 自动完成：
//   1. 从 skillDirectories 扫描 SKILL.md 文件
//   2. 解析 YAML frontmatter 提取 name/description/allowed-tools
//   3. 仅加载 SKILL.md Markdown body 作为 prompt（Progressive Disclosure）
//   4. 将 references/ 路径替换为绝对路径，让 Agent 按需加载
//   5. 自动注册为 SDK Skill 并注入 SkillTool（描述包含可用技能列表）
//
// 本示例使用项目内嵌的 .claude/skills/polyv-live-cli 技能目录。
// 无需自定义系统提示词——SkillTool 的描述会自动列出可用技能，
// LLM 即可按需发现并调用。
//
// 运行方式：swift run PolyvLiveExample
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

print("=== PolyvLiveExample ===")
print()

// MARK: - Part 1: 使用 SDK 内置技能发现

// 技能目录：项目内嵌的 .claude/skills 目录
let projectRoot = getEnv("PROJECT_ROOT", from: dotEnv) ?? FileManager.default.currentDirectoryPath
let skillDir = projectRoot + "/.claude/skills"

print("--- Part 1: SDK Auto-Discovery from \(skillDir) ---")

// 创建 Agent，指定 skillDirectories 和 skillNames 即可
// SDK 自动：扫描目录 → 解析 SKILL.md → 注册到 SkillRegistry → 注入 SkillTool
// SkillTool 的描述会自动包含可用技能列表，LLM 无需系统提示词即可发现技能
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    maxTurns: 25,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core),
    skillDirectories: [skillDir],
    skillNames: ["polyv-live-cli"]
))

print("  Skills auto-discovered and SkillTool injected by SDK")
print()

// MARK: - Part 2: Agent 技能调用

print("--- Part 2: Agent Skill Invocation ---")
print("Query: 'List my live streaming channels'")
print()

// 直接用自然语言提问，SDK 自动匹配 polyv-live-cli 技能并执行
let result = await agent.prompt("List my live streaming channels")

print("=== Agent Response ===")
print(result.text)
print()

print("=== Query Statistics ===")
print("  Status: \(result.status)")
print("  Turns: \(result.numTurns)")
print("  Duration: \(result.durationMs)ms (\(String(format: "%.2f", Double(result.durationMs) / 1000.0))s)")
print("  Cost: $\(String(format: "%.6f", result.totalCostUsd))")
print()
print("=== PolyvLiveExample Completed ===")

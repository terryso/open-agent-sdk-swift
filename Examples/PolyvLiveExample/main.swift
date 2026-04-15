// PolyvLiveExample 示例
//
// 演示如何使用 SDK 内置的文件系统技能发现机制加载和执行 SKILL.md 技能。
//
// 新版 SDK 内化了 SkillLoader，自动完成：
//   1. 从标准目录扫描 SKILL.md 文件
//   2. 解析 YAML frontmatter 提取 name/description/allowed-tools
//   3. 仅加载 SKILL.md Markdown body 作为 prompt（Progressive Disclosure）
//   4. 将 references/ 路径替换为绝对路径，让 Agent 按需加载
//   5. 自动注册为 SDK Skill 并注入 SkillTool
//
// 用户只需在 AgentOptions 中指定 skillDirectories 和 skillNames，
// 其余由 SDK 自动处理。
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

// 技能目录：用户可以通过环境变量覆盖默认路径
let defaultSkillDir = NSHomeDirectory() + "/.agents/skills"
let skillDir = getEnv("POLYV_SKILL_DIR", from: dotEnv) ?? defaultSkillDir

print("--- Part 1: SDK Auto-Discovery from \(skillDir) ---")

// 创建 Agent，指定 skillDirectories 让 SDK 自动发现技能
// skillNames 白名单限制只加载 polyv-live-cli
// SDK 会自动：扫描目录 → 解析 SKILL.md → 注册到 SkillRegistry → 注入 SkillTool
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    systemPrompt: """
    You are a helpful assistant with access to skills. When the user asks you to use a skill, \
    discover and execute it using the Skill tool. You have access to a "polyv-live-cli" skill \
    for managing PolyV live streaming services.

    IMPORTANT: When the skill prompt references external documentation files (e.g., paths ending \
    in .md under a references/ directory), use the Read tool to load them ONLY when you need \
    detailed information for a specific operation. Do NOT load all reference files at once.
    """,
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
print("Query: 'List my live streaming channels using the polyv-live-cli skill'")
print()

// 让 Agent 通过 SDK 注入的 SkillTool 调用 polyv-live-cli 技能
let result = await agent.prompt("List my live streaming channels using the polyv-live-cli skill")

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

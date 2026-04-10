// PermissionsExample 示例
//
// 演示如何通过权限策略（PermissionPolicy）和权限模式（PermissionMode）控制 Agent 的工具访问范围。
// 展示三种权限控制模式的对比：
//   1. ToolNameAllowlistPolicy — 基于工具名称白名单限制，只允许指定的工具执行
//   2. ReadOnlyPolicy — 基于工具属性限制，只允许 isReadOnly == true 的工具执行
//   3. bypassPermissions — 不受限模式，允许所有工具自由执行（作为对比）
//
// 运行方式：swift run PermissionsExample
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

// 所有 Agent 共用的系统提示，引导 Agent 使用工具分析项目结构
let systemPrompt = """
You are a project analysis assistant. Use the available tools to examine the project \
structure. Use Glob to discover files, Read to examine file contents, and Grep to search \
for patterns. Provide concise summaries of your findings.
"""

// 所有 Agent 共用的查询提示
let query = "List the Swift source files in the Sources directory using Glob, and briefly describe what you find."

// MARK: - Part 1: ToolNameAllowlistPolicy（工具名称白名单）

// ToolNameAllowlistPolicy 只允许名称在白名单中的工具执行
// 这里限制 Agent 只能使用 Read、Glob、Grep 三个只读工具
// 即使注册了全部核心工具（包括 Write、Edit、Bash 等），Agent 也只能使用白名单中的工具
let allowlistPolicy = ToolNameAllowlistPolicy(allowedToolNames: ["Read", "Glob", "Grep"])

// 通过 canUseTool(policy:) 桥接函数将 PermissionPolicy 转换为 CanUseToolFn 回调
// canUseTool 回调优先于 permissionMode：当回调返回结果时，使用回调的决定；
// 当回调返回 nil 时，回退到 permissionMode 的行为
let allowlistCallback = canUseTool(policy: allowlistPolicy)

// 创建受限 Agent 1：使用 ToolNameAllowlistPolicy
// 注意：即使设置了 canUseTool，也应该合理设置 permissionMode 作为后备
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? (getEnv("CODEANY_BASE_URL", from: dotEnv) ?? "https://open.bigmodel.cn/api/coding/paas/v4") : nil,
    provider: useOpenAI ? .openai : .anthropic,
    systemPrompt: systemPrompt,
    maxTurns: 15,
    permissionMode: .bypassPermissions,
    canUseTool: allowlistCallback,
    tools: getAllBaseTools(tier: .core)
))

print("=== PermissionsExample ===")
print()
print("Part 1: ToolNameAllowlistPolicy")
print("  Allowed tools: Read, Glob, Grep")
print("  Policy type: \(type(of: allowlistPolicy))")
print()

// 使用 await agent.prompt() 阻塞式 API 获取受限 Agent 的响应
let allowlistResult = await agent.prompt(query)

print("--- Allowlist Agent Response ---")
print(allowlistResult.text)
print()
print("  Status: \(allowlistResult.status)")
print("  Turns: \(allowlistResult.numTurns)")
print("  Duration: \(allowlistResult.durationMs)ms")
print("  Cost: $\(String(format: "%.6f", allowlistResult.totalCostUsd))")
print()

// MARK: - Part 2: ReadOnlyPolicy（只读策略）

// ReadOnlyPolicy 基于工具属性（isReadOnly）限制，而非工具名称
// 所有 isReadOnly == true 的工具都可以执行（Read、Glob、Grep、WebFetch、WebSearch 等）
// 但 Write、Edit、Bash 等写入/执行工具会被拒绝
let readOnlyPolicy = ReadOnlyPolicy()

// 同样通过 canUseTool(policy:) 桥接
let readOnlyCallback = canUseTool(policy: readOnlyPolicy)

// 创建受限 Agent 2：使用 ReadOnlyPolicy
let readOnlyAgent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? (getEnv("CODEANY_BASE_URL", from: dotEnv) ?? "https://open.bigmodel.cn/api/coding/paas/v4") : nil,
    provider: useOpenAI ? .openai : .anthropic,
    systemPrompt: systemPrompt,
    maxTurns: 15,
    permissionMode: .bypassPermissions,
    canUseTool: readOnlyCallback,
    tools: getAllBaseTools(tier: .core)
))

print("--- Part 2: ReadOnlyPolicy ---")
print("  Policy type: \(type(of: readOnlyPolicy))")
print("  Allows all tools where isReadOnly == true")
print()

let readOnlyResult = await readOnlyAgent.prompt(query)

print("--- Read-Only Agent Response ---")
print(readOnlyResult.text)
print()
print("  Status: \(readOnlyResult.status)")
print("  Turns: \(readOnlyResult.numTurns)")
print("  Duration: \(readOnlyResult.durationMs)ms")
print("  Cost: $\(String(format: "%.6f", readOnlyResult.totalCostUsd))")
print()

// MARK: - Part 3: bypassPermissions 对比（不受限）

// 不受限 Agent：使用 permissionMode: .bypassPermissions，不设置 canUseTool
// bypassPermissions 跳过所有权限检查，Agent 可以自由使用所有注册的工具
let unrestrictedAgent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? (getEnv("CODEANY_BASE_URL", from: dotEnv) ?? "https://open.bigmodel.cn/api/coding/paas/v4") : nil,
    provider: useOpenAI ? .openai : .anthropic,
    systemPrompt: systemPrompt,
    maxTurns: 15,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core)
))

print("--- Part 3: bypassPermissions (Unrestricted) ---")
print("  Permission mode: bypassPermissions (no canUseTool callback)")
print()

let unrestrictedResult = await unrestrictedAgent.prompt(query)

print("--- Unrestricted Agent Response ---")
print(unrestrictedResult.text)
print()
print("  Status: \(unrestrictedResult.status)")
print("  Turns: \(unrestrictedResult.numTurns)")
print("  Duration: \(unrestrictedResult.durationMs)ms")
print("  Cost: $\(String(format: "%.6f", unrestrictedResult.totalCostUsd))")
print()

// MARK: - 对比总结

print("========================================")
print("=== Permission Modes Comparison ===")
print("========================================")
print()
print("1. ToolNameAllowlistPolicy (Part 1)")
print("   - Restricts by tool name: only Read, Glob, Grep allowed")
print("   - Uses canUseTool(policy:) to bridge policy to callback")
print("   - Behavior: tools not in allowlist are denied")
print()
print("2. ReadOnlyPolicy (Part 2)")
print("   - Restricts by tool property: only isReadOnly == true tools")
print("   - Allows more tools than allowlist (e.g., WebFetch, WebSearch, ToolSearch)")
print("   - Behavior: write/execute tools (Write, Edit, Bash) are denied")
print()
print("3. bypassPermissions (Part 3)")
print("   - No restrictions: all registered tools available")
print("   - No canUseTool callback set")
print("   - Behavior: all tools execute freely without permission checks")
print()
print("Key Takeaway:")
print("  - canUseTool callback takes priority over permissionMode")
print("  - Use ToolNameAllowlistPolicy for precise tool control by name")
print("  - Use ReadOnlyPolicy for attribute-based restriction")
print("  - Use bypassPermissions only when all tools should be unrestricted")
print()
print("=== PermissionsExample Completed ===")

// MCPIntegration 示例
//
// 演示 MCP（Model Context Protocol）服务器集成：
// 1. Stdio 配置 — 连接外部 MCP 服务器（通过子进程 stdin/stdout 通信）
// 2. InProcessMCPServer — 进程内工具暴露（零 MCP 协议开销）
//
// 运行方式：swift run MCPIntegration
// 前提条件：在 .env 文件或环境变量中设置 CODEANY_API_KEY

import Foundation
import OpenAgentSDK
import MCP

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

// MARK: - 1. InProcessMCPServer（进程内工具暴露）

/// 创建一个将在进程内直接暴露的自定义工具
struct EchoInput: Codable {
    let message: String
}

let echoTool = defineTool(
    name: "echo",
    description: "Echo back the input message",
    inputSchema: [
        "type": "object",
        "properties": ["message": ["type": "string"]],
        "required": ["message"]
    ],
    isReadOnly: true
) { (input: EchoInput, context: ToolContext) -> String in
    return "Echo: \(input.message)"
}

/// 创建 InProcessMCPServer — 在进程内暴露工具，无需 MCP 协议开销
/// 注意：name 不能包含 "__"（双下划线）
let inProcessServer = InProcessMCPServer(
    name: "my-tools",        // 将被命名空间为 mcp__my-tools__echo
    version: "1.0.0",
    tools: [echoTool],
    cwd: "/tmp"
)

// 使用 asConfig() 便捷方法生成 SDK 配置（InProcessMCPServer 是 actor，需要 await）
let sdkConfig: [String: McpServerConfig] = [
    "my-tools": await inProcessServer.asConfig()
]

print("InProcessMCPServer created with \(await inProcessServer.getTools().count) tool(s)")

// MARK: - 2. Stdio 配置（外部 MCP 服务器）

/// 配置通过 stdio 连接的外部 MCP 服务器
/// Agent 会启动子进程并通过 stdin/stdout JSON-RPC 通信
let stdioConfig: [String: McpServerConfig] = [
    "filesystem": .stdio(McpStdioConfig(
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    ))
]

print("Stdio MCP config created for filesystem server")
print()

// MARK: - 3. 使用 SDK 配置创建 Agent

// 使用 InProcessMCPServer（SDK 模式）— 推荐用于自定义工具
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    systemPrompt: "You have access to an echo tool via MCP. Use it when asked to echo something.",
    permissionMode: .bypassPermissions,
    mcpServers: sdkConfig  // 注入 MCP 服务器配置
))

print("Agent created with MCP server integration")
print()

// MARK: - 4. 组合使用 SDK 和 Stdio 配置

// 如果需要同时使用 InProcessMCPServer 和外部 Stdio 服务器，
// 可以合并两个配置字典传给 Agent：
//
// var combinedConfig = sdkConfig
// combinedConfig.merge(stdioConfig) { _, new in new }
// let agent = createAgent(options: AgentOptions(..., mcpServers: combinedConfig))

// 如果需要手动构建 McpSdkServerConfig（不使用 asConfig()）：
let manualSdkConfig = McpSdkServerConfig(
    name: "my-tools",
    version: "1.0.0",
    server: inProcessServer
)
let manualConfig: [String: McpServerConfig] = [
    "my-tools": .sdk(manualSdkConfig)
]
print("Manual SDK config: name=\(manualSdkConfig.name), version=\(manualSdkConfig.version)")

// MARK: - 5. 使用 MCP 工具

print()
print("Sending prompt to agent with MCP tools...")
let result = await agent.prompt("Please echo the message 'Hello from MCP!'")

print()
print("Response: \(result.text)")
print()
print("--- Statistics ---")
print("  Status: \(result.status)")
print("  Turns: \(result.numTurns)")
print("  Cost: $\(String(format: "%.6f", result.totalCostUsd))")

// EnvInjectionExample
//
// 演示如何通过 AgentOptions.env 注入自定义环境变量，包括：
//   1. 配置 AgentOptions.env 设置自定义环境变量
//   2. BashTool 自动将 ToolContext.env 注入到子进程
//   3. 自定义工具通过 ToolContext.env 读取注入的环境变量
//
// 运行方式：swift run EnvInjectionExample
// 前提条件：在 .env 文件或环境变量中设置 CODEANY_API_KEY 或 ANTHROPIC_API_KEY

import Foundation
import OpenAgentSDK

@main
struct EnvInjectionExample {
    static func main() async throws {
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║  EnvInjection Example — 环境变量注入子进程                     ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print()

        let dotEnv = loadDotEnv()
        let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
            ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
            ?? ""
        guard !apiKey.isEmpty else {
            print("  Skipping: set CODEANY_API_KEY or ANTHROPIC_API_KEY to run this example")
            print("  Usage: ANTHROPIC_API_KEY=sk-... swift run EnvInjectionExample")
            return
        }

        let defaultModel = getEnv("ANTHROPIC_MODEL", from: dotEnv)
            ?? getEnv("CODEANY_MODEL", from: dotEnv)
            ?? "claude-sonnet-4-6"
        let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

        try await part1_InjectEnvToBashTool(apiKey: apiKey, model: defaultModel, useOpenAI: useOpenAI, dotEnv: dotEnv)
        try await part2_ReadEnvInCustomTool(apiKey: apiKey, model: defaultModel, useOpenAI: useOpenAI, dotEnv: dotEnv)
    }

    // MARK: - Part 1: BashTool 环境变量注入

    static func part1_InjectEnvToBashTool(apiKey: String, model: String, useOpenAI: Bool, dotEnv: [String: String]) async throws {
        print("--- Part 1: BashTool receives injected env vars ---")
        print()

        // 配置 AgentOptions.env 注入自定义环境变量
        // BashTool 会自动将这些变量合并到子进程环境中
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : getDefaultAnthropicBaseURL(from: dotEnv),
            provider: useOpenAI ? .openai : .anthropic,
            systemPrompt: "You execute shell commands and report results concisely.",
            permissionMode: .bypassPermissions,
            env: [
                "MY_APP_STAGE": "staging",
                "MY_APP_REGION": "us-west-2",
                "MY_APP_VERSION": "1.2.3",
            ]
        ))

        print("  Agent configured with custom env:")
        print("    MY_APP_STAGE=staging")
        print("    MY_APP_REGION=us-west-2")
        print("    MY_APP_VERSION=1.2.3")
        print()
        print("  Asking agent to print injected env vars via bash...")
        print()

        let result = await agent.prompt("Run `echo $MY_APP_STAGE $MY_APP_REGION $MY_APP_VERSION` and show the output")

        print("=== Agent Response ===")
        print(result.text)
        print()
        print("  Status: \(result.status)")
        print("  Turns: \(result.numTurns)")
        print()
    }

    // MARK: - Part 2: 自定义工具读取 ToolContext.env

    static func part2_ReadEnvInCustomTool(apiKey: String, model: String, useOpenAI: Bool, dotEnv: [String: String]) async throws {
        print("--- Part 2: Custom tool reads ToolContext.env ---")
        print()

        // 创建一个自定义工具，从 ToolContext.env 读取环境变量
        let envReaderTool = defineTool(
            name: "get_deployment_info",
            description: "Get the current deployment stage, region, and version from environment",
            inputSchema: [
                "type": "object",
                "properties": [:] as [String: Any]
            ],
            isReadOnly: true
        ) { (input: EmptyInput, context: ToolContext) -> String in
            let env = context.env ?? [:]
            let stage = env["MY_APP_STAGE"] ?? "unknown"
            let region = env["MY_APP_REGION"] ?? "unknown"
            let version = env["MY_APP_VERSION"] ?? "unknown"
            return "Deployment: stage=\(stage), region=\(region), version=\(version)"
        }

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : getDefaultAnthropicBaseURL(from: dotEnv),
            provider: useOpenAI ? .openai : .anthropic,
            systemPrompt: "You have access to deployment info via the get_deployment_info tool.",
            permissionMode: .bypassPermissions,
            tools: [envReaderTool],
            env: [
                "MY_APP_STAGE": "production",
                "MY_APP_REGION": "eu-west-1",
                "MY_APP_VERSION": "2.0.0",
            ]
        ))

        print("  Agent with custom tool + injected env:")
        print("    MY_APP_STAGE=production")
        print("    MY_APP_REGION=eu-west-1")
        print("    MY_APP_VERSION=2.0.0")
        print()
        print("  Asking agent to check deployment info...")
        print()

        let result = await agent.prompt("What is the current deployment info?")

        print("=== Agent Response ===")
        print(result.text)
        print()
        print("=== EnvInjectionExample Completed ===")
    }
}

private struct EmptyInput: Codable {}

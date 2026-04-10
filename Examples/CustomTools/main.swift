// CustomTools 示例
//
// 演示 defineTool() 工厂函数、Codable 输入类型和 JSON Schema 定义。
// 包含使用 String 返回和 ToolExecuteResult 返回两种方式的工具。
// 还展示自定义权限回调和 Policy 模式。
//
// 运行方式：swift run CustomTools
// 前提条件：在 .env 文件或环境变量中设置 CODEANY_API_KEY

import Foundation
import OpenAgentSDK

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"

// MARK: - 工具 1：Codable 输入 + String 返回

/// 天气查询工具的输入类型
struct WeatherInput: Codable {
    let city: String
    let unit: String?  // "celsius" or "fahrenheit", 默认 celsius
}

/// 创建天气查询工具 — 使用 Codable struct 作为输入
let weatherTool = defineTool(
    name: "get_weather",
    description: "Get the current weather for a specified city",
    inputSchema: [
        "type": "object",
        "properties": [
            "city": ["type": "string", "description": "City name, e.g. 'Beijing'"],
            "unit": ["type": "string", "description": "Temperature unit: 'celsius' or 'fahrenheit'"]
        ],
        "required": ["city"]
    ],
    isReadOnly: true  // 只读工具 — 不产生副作用
) { (input: WeatherInput, context: ToolContext) -> String in
    // 在真实应用中，这里会调用天气 API
    // 这里使用模拟数据演示
    let unit = input.unit ?? "celsius"
    let temp = unit == "fahrenheit" ? "72F" : "22C"
    return "Weather in \(input.city): Sunny, \(temp)"
}

// MARK: - 工具 2：Codable 输入 + ToolExecuteResult 返回

/// 计算器工具的输入类型
struct CalculatorInput: Codable {
    let expression: String
}

/// 创建计算器工具 — 使用 ToolExecuteResult 明确标记成功或失败
let calculatorTool = defineTool(
    name: "calculate",
    description: "Evaluate a mathematical expression",
    inputSchema: [
        "type": "object",
        "properties": [
            "expression": ["type": "string", "description": "Math expression, e.g. '2 + 3 * 4'"]
        ],
        "required": ["expression"]
    ]
) { (input: CalculatorInput, context: ToolContext) -> ToolExecuteResult in
    // 简单的安全检查
    let forbidden = ["import", "system", "exec", "eval"]
    for word in forbidden {
        if input.expression.contains(word) {
            return ToolExecuteResult(
                content: "Unsafe expression detected: '\(word)'",
                isError: true
            )
        }
    }

    // 简单的模拟计算
    return ToolExecuteResult(
        content: "Result of '\(input.expression)' = 42 (simulated)",
        isError: false
    )
}

// MARK: - 工具 3：无输入工具（No-Input 便捷方法）

/// 创建一个不需要结构化输入的工具
let healthCheckTool = defineTool(
    name: "health_check",
    description: "Check if the service is healthy",
    inputSchema: ["type": "object", "properties": [:]],
    isReadOnly: true
) { (context: ToolContext) -> String in
    return "Service is healthy. Working directory: \(context.cwd)"
}

// MARK: - 创建 Agent 并注册工具

let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    systemPrompt: "You are a helpful assistant with access to weather, calculator, and health check tools.",
    permissionMode: .bypassPermissions,
    tools: [weatherTool, calculatorTool, healthCheckTool]
))

print("Agent created with \(3) custom tools")
print()

// MARK: - 自定义权限控制（三种方式，选择其一）
//
// 注意：每次调用 setCanUseTool / setPermissionMode 都会覆盖之前的权限设置。
// 以下展示三种方式，实际使用时选择最适合的一种即可。

// --- 方式 1：闭包回调（细粒度控制）---
// agent.setCanUseTool { tool, input, context in
//     if tool.name == "calculate" {
//         print("  [Permission] Allowing tool: \(tool.name)")
//     }
//     return .allow()
// }

// --- 方式 2：Policy 模式（可组合的策略）---
// let policy = CompositePolicy(policies: [
//     ReadOnlyPolicy(),                              // 只允许只读工具
//     ToolNameDenylistPolicy(deniedToolNames: ["Bash"])  // 禁止 Bash 工具
// ])
// agent.setCanUseTool(canUseTool(policy: policy))

// --- 方式 3：权限模式（最简单）---
agent.setPermissionMode(.bypassPermissions)  // 绕过所有权限检查（适合开发/测试）

// MARK: - 使用工具

print("Sending prompt with tool access...")
let result = await agent.prompt(
    "What's the weather in Tokyo? Also calculate 15 * 7."
)

print()
print("Response: \(result.text)")
print()
print("--- Statistics ---")
print("  Status: \(result.status)")
print("  Turns: \(result.numTurns)")
print("  Cost: $\(String(format: "%.6f", result.totalCostUsd))")

// AdvancedMCPExample 示例
//
// 演示高级 MCP 工具集成：
// 1. 使用 defineTool() 创建带 Codable 输入结构的自定义工具
// 2. 使用 InProcessMCPServer 将自定义工具打包为进程内 MCP 服务器
// 3. Agent 通过 mcpServers 配置连接 MCP 服务器并调用命名空间工具
// 4. 展示工具返回错误时的处理方式（ToolExecuteResult 的 isError 字段）
//
// 与 MCPIntegration 的区别：
// - MCPIntegration 展示 InProcessMCPServer 创建和 stdio 配置的基础用法
// - 本示例深入展示多工具注册、错误处理和命名空间验证的高级模式
//
// 运行方式：swift run AdvancedMCPExample
// 前提条件：在 .env 文件或环境变量中设置 CODEANY_API_KEY

import Foundation
import OpenAgentSDK
import MCP

// MARK: - 配置 API Key

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"

// MARK: - Part 1: 创建自定义 MCP 工具

// 使用 defineTool() 创建带 Codable 输入结构的自定义工具
// 每个工具都定义了清晰的 JSON Schema，确保 LLM 能正确传递参数

/// 天气查询工具的输入结构
struct WeatherInput: Codable {
    let city: String
}

// 天气查询工具 — 根据城市名返回模拟天气数据（只读工具）
let weatherTool = defineTool(
    name: "get_weather",
    description: "Get the current weather for a given city. Returns simulated weather data.",
    inputSchema: [
        "type": "object",
        "properties": [
            "city": ["type": "string", "description": "The city name to query weather for"]
        ],
        "required": ["city"]
    ],
    isReadOnly: true
) { (input: WeatherInput, context: ToolContext) -> String in
    // 模拟天气数据（实际项目中可调用真实天气 API）
    let weatherData: [String: String] = [
        "Beijing": "Sunny, 22C, humidity 45%",
        "Tokyo": "Cloudy, 18C, humidity 65%",
        "New York": "Rainy, 15C, humidity 80%",
        "London": "Foggy, 12C, humidity 90%",
        "Paris": "Clear, 20C, humidity 50%"
    ]
    let result = weatherData[input.city] ?? "No weather data available for \(input.city)"
    return "Weather in \(input.city): \(result)"
}

/// 单位转换工具的输入结构
struct ConversionInput: Codable {
    let value: Double
    let fromUnit: String
    let toUnit: String
}

// 单位转换工具 — 支持 Celsius/Fahrenheit 和 km/miles 转换（只读工具）
let conversionTool = defineTool(
    name: "convert_unit",
    description: "Convert a value between units. Supports: celsius/fahrenheit, km/miles, kg/lbs.",
    inputSchema: [
        "type": "object",
        "properties": [
            "value": ["type": "number", "description": "The numeric value to convert"],
            "fromUnit": ["type": "string", "description": "The source unit (celsius, fahrenheit, km, miles, kg, lbs)"],
            "toUnit": ["type": "string", "description": "The target unit (celsius, fahrenheit, km, miles, kg, lbs)"]
        ],
        "required": ["value", "fromUnit", "toUnit"]
    ],
    isReadOnly: true
) { (input: ConversionInput, context: ToolContext) -> String in
    let key = "\(input.fromUnit.lowercased())_to_\(input.toUnit.lowercased())"
    let conversions: [String: (Double) -> Double] = [
        "celsius_to_fahrenheit": { v in v * 9 / 5 + 32 },
        "fahrenheit_to_celsius": { v in (v - 32) * 5 / 9 },
        "km_to_miles": { v in v * 0.621371 },
        "miles_to_km": { v in v * 1.60934 },
        "kg_to_lbs": { v in v * 2.20462 },
        "lbs_to_kg": { v in v * 0.453592 }
    ]
    guard let converter = conversions[key] else {
        return "Unsupported conversion: \(input.fromUnit) to \(input.toUnit). Supported units: celsius, fahrenheit, km, miles, kg, lbs"
    }
    let result = converter(input.value)
    return "\(input.value) \(input.fromUnit) = \(String(format: "%.2f", result)) \(input.toUnit)"
}

/// 输入验证工具的输入结构（用于演示错误处理）
struct ValidateInput: Codable {
    let email: String
}

// 输入验证工具 — 使用 ToolExecuteResult 变体，演示错误返回
// 当 email 不包含 "@" 时返回 isError: true
let validationTool = defineTool(
    name: "validate_email",
    description: "Validate an email address. Returns success or error if the email format is invalid.",
    inputSchema: [
        "type": "object",
        "properties": [
            "email": ["type": "string", "description": "The email address to validate"]
        ],
        "required": ["email"]
    ],
    isReadOnly: true
) { (input: ValidateInput, context: ToolContext) -> ToolExecuteResult in
    // 演示错误处理：当 email 不包含 "@" 时返回错误
    if !input.email.contains("@") {
        return ToolExecuteResult(content: "Invalid email format: '\(input.email)' is missing '@' symbol. A valid email must contain '@'.", isError: true)
    }
    // 有效 email 返回成功
    return ToolExecuteResult(content: "Email '\(input.email)' is valid.", isError: false)
}

print("=== AdvancedMCPExample ===")
print("Created 3 custom MCP tools:")
print("  1. get_weather — 查询城市天气（String 返回）")
print("  2. convert_unit — 单位转换（String 返回）")
print("  3. validate_email — 邮箱验证（ToolExecuteResult 返回，含错误处理）")
print()

// MARK: - Part 2: 创建 InProcessMCPServer

// 将所有自定义工具打包为进程内 MCP 服务器
// 注意：name 不能包含 "__"（双下划线），否则会触发 precondition failure
// MCP 工具命名空间格式：mcp__{serverName}__{toolName}
let utilityServer = InProcessMCPServer(
    name: "utility",            // 命名空间前缀：mcp__utility__
    version: "1.0.0",
    tools: [weatherTool, conversionTool, validationTool],
    cwd: "/tmp"
)

// InProcessMCPServer 是 actor，访问其属性和方法需要 await
let toolCount = await utilityServer.getTools().count
print("InProcessMCPServer created:")
print("  Server name: \(await utilityServer.name)")
print("  Version: \(await utilityServer.version)")
print("  Tools registered: \(toolCount)")
print("  Namespace prefix: mcp__utility__")
print()

// 使用 asConfig() 便捷方法生成 SDK 配置
// 返回 McpServerConfig.sdk(McpSdkServerConfig(...))
// InProcessMCPServer 是 actor，asConfig() 需要 await
let mcpConfig: [String: McpServerConfig] = [
    "utility": await utilityServer.asConfig()
]

print("SDK config generated via asConfig()")
print("  Config key: 'utility'")
print("  MCP tools will be namespaced as: mcp__utility__get_weather, mcp__utility__convert_unit, mcp__utility__validate_email")
print()

// MARK: - Part 3: 创建 Agent 并使用 MCP 工具

// 通过 AgentOptions 的 mcpServers 参数注入 MCP 服务器配置
// Agent 将自动发现并使用 MCP 命名空间工具
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    systemPrompt: "You are a helpful assistant with access to weather, unit conversion, and email validation tools via MCP. Use the tools when asked about weather, unit conversions, or email validation.",
    maxTurns: 5,
    permissionMode: .bypassPermissions,
    mcpServers: mcpConfig
))

print("Agent created with MCP server integration")
print()

// 发送需要使用天气查询工具的查询
// LLM 将自动调用 mcp__utility__get_weather 工具
print("--- Query 1: Weather lookup ---")
let weatherResult = await agent.prompt("What is the weather like in Tokyo?")

if weatherResult.status != .success {
    print("Query completed with status: \(weatherResult.status)")
}

print("Response: \(weatherResult.text)")
print()
print("--- Statistics ---")
print("  Status: \(weatherResult.status)")
print("  Turns: \(weatherResult.numTurns)")
print("  Duration: \(weatherResult.durationMs)ms")
print("  Cost: $\(String(format: "%.6f", weatherResult.totalCostUsd))")
print()

// 发送需要使用单位转换工具的查询
// LLM 将自动调用 mcp__utility__convert_unit 工具
print("--- Query 2: Unit conversion ---")
let conversionResult = await agent.prompt("Convert 100 degrees celsius to fahrenheit.")

if conversionResult.status != .success {
    print("Query completed with status: \(conversionResult.status)")
}

print("Response: \(conversionResult.text)")
print()
print("--- Statistics ---")
print("  Status: \(conversionResult.status)")
print("  Turns: \(conversionResult.numTurns)")
print("  Duration: \(conversionResult.durationMs)ms")
print("  Cost: $\(String(format: "%.6f", conversionResult.totalCostUsd))")
print()

// MARK: - Part 4: 工具错误处理演示

// 发送一个会触发验证错误的查询 — 使用无效邮箱格式
// validate_email 工具将返回 isError: true 的 ToolExecuteResult
// Agent 会看到工具返回的错误并告知用户
print("--- Query 3: Error handling (invalid email) ---")
let errorResult = await agent.prompt("Please validate the email address 'not-an-email'.")

if errorResult.status != .success {
    print("Query completed with status: \(errorResult.status)")
}

print("Response: \(errorResult.text)")
print()
print("--- Statistics ---")
print("  Status: \(errorResult.status)")
print("  Turns: \(errorResult.numTurns)")
print("  Duration: \(errorResult.durationMs)ms")
print("  Cost: $\(String(format: "%.6f", errorResult.totalCostUsd))")
print()

// 发送一个有效邮箱的查询，展示成功路径
print("--- Query 4: Successful validation ---")
let successResult = await agent.prompt("Please validate the email address 'user@example.com'.")

if successResult.status != .success {
    print("Query completed with status: \(successResult.status)")
}

print("Response: \(successResult.text)")
print()
print("--- Statistics ---")
print("  Status: \(successResult.status)")
print("  Turns: \(successResult.numTurns)")
print("  Duration: \(successResult.durationMs)ms")
print("  Cost: $\(String(format: "%.6f", successResult.totalCostUsd))")
print()
print("=== AdvancedMCPExample Complete ===")

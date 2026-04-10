# 示例教程

[English](./README.md)

完整可运行的示例，演示 Open Agent SDK 的各项功能。每个示例都是独立的 Swift 可执行程序，一行命令即可运行。

## 前提条件

- **Swift 6.1+** 和 **macOS 13+**
- **API Key** — 设置以下环境变量之一：

```bash
# 方式 1：OpenAI 兼容 API（GLM、Ollama、OpenRouter 等）— 默认
export CODEANY_API_KEY=your-key
export CODEANY_BASE_URL=https://open.bigmodel.cn/api/coding/paas/v4
export CODEANY_MODEL=glm-5.1

# 方式 2：Anthropic API（Claude 模型）
export ANTHROPIC_API_KEY=sk-ant-...
```

> **提示：** 将 `export` 行添加到 `~/.zshrc` 或 `~/.bashrc` 中，使其在每次打开终端时自动生效。也可以复制项目根目录的 `.env` 文件并修改其中的值。

## 快速开始

```bash
# 1. 克隆并进入项目
git clone https://github.com/terryso/open-agent-sdk-swift.git
cd open-agent-sdk-swift

# 2. 构建项目（首次运行需要 — 会下载所有依赖）
swift build

# 3. 运行你的第一个示例
swift run BasicAgent
```

完成！Agent 会向 LLM 发送提示并打印响应。

## 全部示例

### 1. BasicAgent — Agent 创建与简单查询

最简单的示例。创建一个 Agent，发送阻塞式查询，打印响应及使用统计。

```bash
swift run BasicAgent
```

**你将学到：**
- 使用 `createAgent(options:)` 创建 Agent
- 使用 `agent.prompt()` 进行阻塞式查询
- 读取 `QueryResult` 字段（文本、状态、轮次、成本、Token 数）
- 使用 Anthropic 与 OpenAI 兼容提供商

**关键代码：**
```swift
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: "claude-sonnet-4-6",
    systemPrompt: "You are a helpful assistant.",
    permissionMode: .bypassPermissions
))
let result = await agent.prompt("Explain what an AI agent is in one paragraph.")
```

---

### 2. StreamingAgent — 实时流式响应

展示如何使用 `AsyncStream<SDKMessage>` 实时消费 Agent 响应。

```bash
swift run StreamingAgent
```

**你将学到：**
- 使用 `agent.stream()` 进行流式查询
- 事件类型：`partialMessage`、`toolUse`、`toolResult`、`result`、`system`
- 使用 `maxBudgetUsd` 进行预算追踪

**关键代码：**
```swift
for await message in agent.stream("Write a haiku about programming.") {
    switch message {
    case .partialMessage(let data): print(data.text, terminator: "")
    case .result(let data): print("完成: \(data.numTurns) 轮, $\(data.totalCostUsd)")
    default: break
    }
}
```

---

### 3. CustomTools — 定义自定义工具

演示 `defineTool()` 配合 Codable 输入类型、String 与 `ToolExecuteResult` 返回值、以及权限控制。

```bash
swift run CustomTools
```

**你将学到：**
- 使用 `defineTool()` 和 Codable 输入结构体创建工具
- 为工具参数定义 JSON Schema
- String 返回与 `ToolExecuteResult`（成功/错误）返回类型
- 使用 `isReadOnly: true` 标记只读工具
- 三种权限控制方式：闭包回调、Policy 模式、权限模式

**关键代码：**
```swift
struct WeatherInput: Codable { let city: String }

let weatherTool = defineTool(
    name: "get_weather",
    description: "获取指定城市的当前天气",
    inputSchema: [...]
) { (input: WeatherInput, context: ToolContext) -> String in
    return "\(input.city) 的天气：22°C，晴朗"
}
```

---

### 4. CustomSystemPromptExample — 专业化 Agent 角色

展示如何通过系统提示定制 Agent 行为。创建一个"代码审查专家"Agent。

```bash
swift run CustomSystemPromptExample
```

**你将学到：**
- 使用 `systemPrompt` 定义 Agent 角色和输出格式
- 系统提示如何影响响应风格和结构
- 运行领域专用 Agent（代码审查员）

---

### 5. PromptAPIExample — 阻塞式 API 配合内置工具

演示 `agent.prompt()` 配合全部 10 个核心工具。Agent 自主执行工具后返回最终结果。

```bash
swift run PromptAPIExample
```

**你将学到：**
- 使用 `getAllBaseTools(tier: .core)` 注册全部核心工具
- 阻塞式 API 中 Agent 自主使用工具完成任务
- 处理 `QueryResult` 状态和错误情况

**关键代码：**
```swift
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    tools: getAllBaseTools(tier: .core)
))
let result = await agent.prompt("Analyze the project structure...")
```

---

### 6. MultiToolExample — 多工具编排（流式）

展示 Agent 自主协调多个工具（Glob、Bash、Read）的流式查询。

```bash
swift run MultiToolExample
```

**你将学到：**
- 在工具执行过程中使用 `agent.stream()` 流式查询
- 实时处理工具调用和结果事件
- Agent 驱动的多步骤任务编排

---

### 7. SubagentExample — Agent 委派

演示主 Agent 通过 `Agent` 工具将任务委派给子 Agent。

```bash
swift run SubagentExample
```

**你将学到：**
- 使用 `createAgentTool()` 创建协调者 Agent
- 主 Agent 如何生成 Explore 类型的子 Agent
- 子 Agent 使用受限工具集（Read、Glob、Grep、Bash）
- 结果从子 Agent 流回主 Agent

**关键代码：**
```swift
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    tools: getAllBaseTools(tier: .core) + [createAgentTool()]
))
```

---

### 8. PermissionsExample — 权限策略对比

并排运行三个 Agent，每个使用不同的权限策略，演示访问控制机制。

```bash
swift run PermissionsExample
```

**你将学到：**
- `ToolNameAllowlistPolicy` — 仅允许指定名称的工具
- `ReadOnlyPolicy` — 仅允许 `isReadOnly == true` 的工具
- `bypassPermissions` — 不受限访问（作为对比）
- 使用 `canUseTool(policy:)` 将策略桥接为回调

---

### 9. MCPIntegration — MCP 服务器基础

介绍 MCP（Model Context Protocol）集成，包括 `InProcessMCPServer` 和 stdio 配置。

```bash
swift run MCPIntegration
```

**你将学到：**
- 使用自定义工具创建 `InProcessMCPServer`
- MCP 工具命名空间（`mcp__{serverName}__{toolName}`）
- 使用 `asConfig()` 生成 SDK 配置
- 外部工具服务器的 stdio MCP 配置

**关键代码：**
```swift
let server = InProcessMCPServer(name: "my-tools", version: "1.0.0", tools: [echoTool], cwd: "/tmp")
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    mcpServers: ["my-tools": await server.asConfig()]
))
```

---

### 10. AdvancedMCPExample — 多工具 MCP 与错误处理

高级 MCP 示例，包含多工具注册和错误处理模式。

```bash
swift run AdvancedMCPExample
```

**你将学到：**
- 在单个 MCP 服务器中注册多个工具
- 使用 `ToolExecuteResult(isError: true)` 处理错误
- 同一 MCP Agent 执行多个查询
- 命名空间验证（`mcp__utility__get_weather` 等）

---

### 11. SessionsAndHooks — 会话持久化与生命周期钩子

演示会话持久化（保存/恢复对话）和钩子注册表的生命周期事件。

```bash
swift run SessionsAndHooks
```

**你将学到：**
- `SessionStore` 保存/加载/分叉会话
- `HookRegistry` 注册 pre/post 工具执行钩子
- `sessionStart`/`sessionEnd` 生命周期钩子
- 使用 `sessionId` 跨进程恢复会话

**关键代码：**
```swift
let sessionStore = SessionStore()
let hookRegistry = HookRegistry()
await hookRegistry.register(.preToolUse, definition: HookDefinition(
    matcher: "Bash",
    handler: { input in return HookOutput(message: "已阻止", block: true) }
))
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    sessionStore: sessionStore,
    sessionId: "my-session",
    hookRegistry: hookRegistry
))
```

## 示例依赖

| 示例                | 需要 MCP 依赖          | 额外配置                  |
| ------------------- | ---------------------- | ------------------------- |
| BasicAgent          | 否                     | 无                        |
| StreamingAgent      | 否                     | 无                        |
| CustomTools         | 否                     | 无                        |
| CustomSystemPrompt  | 否                     | 无                        |
| PromptAPIExample    | 否                     | 无                        |
| MultiToolExample    | 否                     | 无                        |
| SubagentExample     | 否                     | 无                        |
| PermissionsExample  | 否                     | 无                        |
| MCPIntegration      | 是（`import MCP`）     | 无                        |
| AdvancedMCPExample  | 是（`import MCP`）     | 无                        |
| SessionsAndHooks    | 否                     | 无                        |

所有示例都已作为可执行目标定义在 `Package.swift` 中 — 无需额外配置。

## 推荐学习路径

```
BasicAgent → StreamingAgent → CustomTools → CustomSystemPromptExample
    → PromptAPIExample → MultiToolExample → SubagentExample
    → PermissionsExample → MCPIntegration → AdvancedMCPExample
    → SessionsAndHooks
```

1. **从这里开始：** BasicAgent、StreamingAgent — 理解核心 prompt/stream API
2. **添加工具：** CustomTools、CustomSystemPromptExample — 学习工具定义和提示词定制
3. **使用内置工具：** PromptAPIExample、MultiToolExample — 观察自主使用工具的 Agent
4. **多 Agent：** SubagentExample — 将任务委派给子 Agent
5. **安全控制：** PermissionsExample — 控制 Agent 可以使用哪些工具
6. **MCP 集成：** MCPIntegration、AdvancedMCPExample — 连接外部工具服务器
7. **持久化：** SessionsAndHooks — 保存会话和注册生命周期钩子

## 常见问题

### 构建错误

```bash
# 清理并重新构建
swift package clean
swift build
```

### "No such module 'OpenAgentSDK'"

确保从包含 `Package.swift` 的项目根目录运行。

### API Key 错误

检查环境变量是否已设置：

```bash
echo $ANTHROPIC_API_KEY   # 应打印你的密钥
# 或
echo $CODEANY_API_KEY
```

### 在 Xcode 中运行

```bash
open Package.swift
```

然后从方案选择器中选择任意示例目标，按 Cmd+R 运行。

### 使用 GLM 或其他 OpenAI 兼容提供商

示例默认使用 `ANTHROPIC_API_KEY`，你可以修改代码使用任意 OpenAI 兼容提供商：

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: ProcessInfo.processInfo.environment["CODEANY_API_KEY"] ?? "your-key",
    model: "glm-5.1",
    baseURL: "https://open.bigmodel.cn/api/coding/paas/v4",
    provider: .openai,
    permissionMode: .bypassPermissions
))
```

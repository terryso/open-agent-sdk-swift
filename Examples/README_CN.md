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

---

### 12. SkillsExample — 技能系统（内置与自定义）

演示技能系统 — 注册内置技能（commit、review、simplify、debug、test）、创建自定义技能、通过 LLM 执行技能。

```bash
swift run SkillsExample
```

**你将学到：**
- 通过 `BuiltInSkills` 初始化内置技能
- 使用 `SkillRegistry` 注册和发现技能
- 使用 `Skill(name:description:promptTemplate:toolRestrictions:)` 创建自定义技能
- Agent 通过 `createSkillTool(registry:)` 执行技能

**关键代码：**
```swift
let registry = SkillRegistry()
registry.register(BuiltInSkills.commit)
registry.register(BuiltInSkills.review)

let customSkill = Skill(
    name: "explain", description: "详细解释代码",
    promptTemplate: "读取文件并解释...", toolRestrictions: [.bash, .read]
)
registry.register(customSkill)

let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    tools: getAllBaseTools(tier: .core) + [createSkillTool(registry: registry)]
))
```

---

### 13. SandboxExample — 沙盒配置与强制执行

展示如何配置路径和命令限制，控制 Agent 的文件系统和 Bash 操作。

```bash
swift run SandboxExample
```

**你将学到：**
- 使用 `SandboxSettings` 配置路径白名单/黑名单
- 命令黑名单（`deniedCommands`）和白名单（`allowedCommands`）
- 路径遍历防护和符号链接解析
- Shell 元字符检测，防止绕过

**关键代码：**
```swift
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    sandbox: SandboxSettings(
        allowedReadPaths: ["/project/"],
        allowedWritePaths: ["/project/src/"],
        deniedCommands: ["rm", "sudo"]
    )
))
```

---

### 14. LoggerExample — 结构化日志系统

演示可配置的日志级别（none/error/warn/info/debug）和输出目标（控制台/文件/自定义）用于 SDK 诊断事件。

```bash
swift run LoggerExample
```

**你将学到：**
- 通过 `AgentOptions.logLevel` 配置日志级别
- 输出目标：`.console`、`.file(URL)`、`.custom(closure)`
- 结构化 JSON 日志格式（时间戳、级别、模块、事件、数据）
- `logLevel = .none` 时的零开销验证

**关键代码：**
```swift
Logger.configure(level: .debug, output: .custom { jsonLine in
    print("[SDK 日志] \(jsonLine)")
})
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    logLevel: .debug,
    logOutput: .custom { line in myHandler(line) }
))
```

---

### 15. ModelSwitchingExample — 运行时模型切换

展示如何在对话中动态切换 LLM 模型，支持按模型追踪成本。

```bash
swift run ModelSwitchingExample
```

**你将学到：**
- 使用 `agent.switchModel()` 切换模型
- `QueryResult` 中按模型的 Token 用量和成本明细
- 无效模型名称的错误处理

**关键代码：**
```swift
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey, model: "claude-sonnet-4-6"
))
let result1 = await agent.prompt("简单问题...")

try agent.switchModel("claude-opus-4-6")
let result2 = await agent.prompt("复杂分析...")
// result2.usage 显示各模型的独立成本
```

---

### 16. QueryAbortExample — 查询中断

演示如何使用 Swift 的 `Task.cancel()` 取消正在运行的 Agent 查询并获取部分结果。

```bash
swift run QueryAbortExample
```

**你将学到：**
- 在 Swift `Task` 中启动查询以支持取消
- 使用 `Task.cancel()` 或 `agent.interrupt()` 取消查询
- 处理 `QueryResult.isCancelled` 和部分工具结果
- 通过 `SDKMessage` 事件处理流式取消

**关键代码：**
```swift
let task = Task {
    for await message in agent.stream("长时间任务...") {
        // 处理事件
    }
}
// 延迟后取消
DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
    task.cancel()
}
```

---

### 17. ContextInjectionExample — 文件缓存与上下文注入

展示文件缓存（LRU 淘汰）、Git 状态自动注入和项目文档发现（CLAUDE.md/AGENT.md）。

```bash
swift run ContextInjectionExample
```

**你将学到：**
- 配置 `FileCache` 参数（maxEntries、maxSizeBytes）
- 缓存命中/未命中统计和淘汰追踪
- Git 上下文收集（系统提示中的 `<git-context>` 块）
- 项目文档发现（CLAUDE.md/AGENT.md 的 `<project-instructions>` 块）
- 文件写入后的缓存失效

**关键代码：**
```swift
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    projectRoot: "/path/to/project"
))
// 系统提示自动包含 <git-context> 和 <project-instructions>
```

---

### 18. MultiTurnExample — SessionStore 多轮对话

演示使用 `SessionStore` 实现多轮对话，跨查询保持上下文。

```bash
swift run MultiTurnExample
```

**你将学到：**
- 在同一 Agent 实例上执行连续查询
- 跨轮次的上下文保持（Agent 记住之前的消息）
- 使用 `agent.getMessages()` 查看对话历史
- 多轮对话中的流式支持

**关键代码：**
```swift
let sessionStore = SessionStore()
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    sessionStore: sessionStore,
    sessionId: "conversation-1"
))

// 第一轮
let result1 = await agent.prompt("我的名字是 Nick。")
// 第二轮 — Agent 记住第一轮的名字
let result2 = await agent.prompt("我叫什么名字？")
```

---

### 19. OpenAICompatExample — OpenAI 兼容 API 提供商

展示如何使用 OpenAI 兼容 API（GLM、DeepSeek、Qwen、Ollama、OpenRouter 等）配合相同的 Agent API。

```bash
swift run OpenAICompatExample
```

**你将学到：**
- 配置 `provider: .openai` 和自定义 `baseURL`
- 使用环境变量（`CODEANY_API_KEY`、`CODEANY_BASE_URL`、`CODEANY_MODEL`）
- Anthropic 与 OpenAI 兼容提供商的配置对比
- 在 OpenAI 兼容提供商下运行工具

**关键代码：**
```swift
let agent = createAgent(options: AgentOptions(
    provider: .openai,
    apiKey: ProcessInfo.processInfo.environment["CODEANY_API_KEY"] ?? "",
    model: "glm-5.1",
    baseURL: "https://open.bigmodel.cn/api/coding/paas/v4",
    permissionMode: .bypassPermissions
))
```

---

## 兼容性验证示例

以下 12 个示例验证 Swift SDK 的 API 与 [open-agent-sdk-typescript](https://github.com/codeany-ai/open-agent-sdk-typescript) 完全兼容。每个示例运行结构化的兼容性报告，对比 TypeScript SDK 字段与 Swift 等效项，打印每个字段的 PASS/MISSING 状态。

> **注意：** Compat 示例是验证工具，不是典型用法演示。适合 SDK 维护者和贡献者追踪 API 对齐情况。

### 20. CompatCoreQuery — 核心 Query API 兼容性

验证 Swift SDK 的 `prompt()`/`stream()` API 覆盖 TypeScript SDK 所有核心用法模式。

```bash
swift run CompatCoreQuery
```

**你将学到：**
- TypeScript SDK `query()` 与 Swift `prompt()`/`stream()` 的映射关系
- 阻塞式和流式查询模式
- `QueryResult` 字段对齐（text、usage、turns、cost、status）

---

### 21. CompatToolSystem — 工具系统兼容性

验证 Swift SDK 的工具定义和执行与 TypeScript SDK 的工具系统匹配。

```bash
swift run CompatToolSystem
```

**你将学到：**
- `defineTool()` API 与 TypeScript `tool()` 函数的对齐
- 工具输入 schema、`ToolContext` 和 `ToolExecuteResult` 兼容性
- 工具注册和执行生命周期

---

### 22. CompatMessageTypes — 消息类型兼容性

验证 Swift SDK 的 `SDKMessage` 覆盖 TypeScript SDK 全部 20 种消息子类型。

```bash
swift run CompatMessageTypes
```

**你将学到：**
- 完整的 `SDKMessage` 枚举对齐（partialMessage、toolUse、toolResult、result、system 等）
- 流式事件类型覆盖
- 消息数据字段映射

---

### 23. CompatHooks — 钩子系统兼容性

验证 Swift SDK 的钩子系统支持 TypeScript SDK 全部 18 种 `HookEvents`，Input/Output 类型一致。

```bash
swift run CompatHooks
```

**你将学到：**
- 所有生命周期事件类型（preToolUse、postToolUse、sessionStart、sessionEnd 等）
- `HookDefinition` 匹配器和处理程序 API 对齐
- `HookInput`/`HookOutput` 字段覆盖

---

### 24. CompatMCP — MCP 集成兼容性

验证 Swift SDK 支持 TypeScript SDK 所有 MCP 服务器配置类型和运行时管理。

```bash
swift run CompatMCP
```

**你将学到：**
- 服务器配置类型：stdio、SSE、HTTP、进程内
- `McpStdioConfig`、`McpSseConfig` 字段对齐
- 运行时 MCP 服务器生命周期管理

---

### 25. CompatSessions — 会话管理兼容性

验证 Swift SDK 的会话 API 覆盖 TypeScript SDK 所有会话操作。

```bash
swift run CompatSessions
```

**你将学到：**
- `SessionStore` 操作：save、load、fork、list、rename、tag、delete
- 会话配置选项对齐
- Session ID 管理和自动恢复

---

### 26. CompatQueryMethods — Query 对象方法兼容性

验证 Swift SDK 提供 TypeScript SDK Query 对象的所有运行时控制方法。

```bash
swift run CompatQueryMethods
```

**你将学到：**
- 运行时控制：abort、interrupt、status check
- 查询生命周期方法映射
- 部分结果获取兼容性

---

### 27. CompatOptions — Agent Options 兼容性

验证 Swift SDK 的 `AgentOptions`/`SDKConfiguration` 覆盖 TypeScript SDK 所有 Options 字段。

```bash
swift run CompatOptions
```

**你将学到：**
- 所有 `AgentOptions` 字段及其 TypeScript 等效项
- 配置继承和默认值
- 环境变量映射

---

### 28. CompatPermissions — 权限系统兼容性

验证 Swift SDK 的权限系统覆盖 TypeScript SDK 所有权限类型和操作。

```bash
swift run CompatPermissions
```

**你将学到：**
- 权限模式对齐（bypassPermissions、acceptEdits、default 等）
- 自定义授权回调 API
- 策略组合兼容性

---

### 29. CompatSubagents — 子 Agent 系统兼容性

验证 Swift SDK 的子 Agent 系统覆盖 TypeScript SDK 的 `AgentDefinition` 和 Agent 工具用法。

```bash
swift run CompatSubagents
```

**你将学到：**
- `createAgentTool()` 和 Agent 生成 API 对齐
- 子 Agent 类型支持（Explore、Plan 等）
- Team/Task 协调字段覆盖

---

### 30. CompatThinkingModel — Thinking 与模型配置兼容性

验证 Swift SDK 的 `ThinkingConfig` 和模型配置与 TypeScript SDK 完全兼容。

```bash
swift run CompatThinkingModel
```

**你将学到：**
- `ThinkingConfig` 选项（budget tokens、type）
- `ModelInfo` 字段和模型切换对齐
- 扩展思维和推理控制

---

### 31. CompatSandbox — 沙盒配置兼容性

验证 Swift SDK 的沙盒配置覆盖 TypeScript SDK 所有沙盒选项。

```bash
swift run CompatSandbox
```

**你将学到：**
- `SandboxSettings` 完整字段覆盖（路径、命令、网络、ripgrep）
- `SandboxNetworkConfig` 和 `RipgrepConfig` 对齐
- 路径遍历防护和 Shell 过滤选项

## 示例依赖

| 示例                     | 需要 MCP 依赖          | 额外配置                  |
| ------------------------ | ---------------------- | ------------------------- |
| BasicAgent               | 否                     | 无                        |
| StreamingAgent           | 否                     | 无                        |
| CustomTools              | 否                     | 无                        |
| CustomSystemPrompt       | 否                     | 无                        |
| PromptAPIExample         | 否                     | 无                        |
| MultiToolExample         | 否                     | 无                        |
| SubagentExample          | 否                     | 无                        |
| PermissionsExample       | 否                     | 无                        |
| MCPIntegration           | 是（`import MCP`）     | 无                        |
| AdvancedMCPExample       | 是（`import MCP`）     | 无                        |
| SessionsAndHooks         | 否                     | 无                        |
| SkillsExample            | 否                     | 无                        |
| SandboxExample           | 否                     | 无                        |
| LoggerExample            | 否                     | 无                        |
| ModelSwitchingExample    | 否                     | 无                        |
| QueryAbortExample        | 否                     | 无                        |
| ContextInjectionExample  | 否                     | 无                        |
| MultiTurnExample         | 否                     | 无                        |
| OpenAICompatExample      | 否                     | 无                        |
| PolyvLiveExample         | 否                     | 包含 SKILL.md 的技能目录  |
| CompatCoreQuery          | 否                     | 无                        |
| CompatToolSystem         | 否                     | 无                        |
| CompatMessageTypes       | 否                     | 无                        |
| CompatHooks              | 否                     | 无                        |
| CompatMCP                | 否                     | 无                        |
| CompatSessions           | 否                     | 无                        |
| CompatQueryMethods       | 否                     | 无                        |
| CompatOptions            | 否                     | 无                        |
| CompatPermissions        | 否                     | 无                        |
| CompatSubagents          | 否                     | 无                        |
| CompatThinkingModel      | 否                     | 无                        |
| CompatSandbox            | 否                     | 无                        |

所有示例都已作为可执行目标定义在 `Package.swift` 中 — 无需额外配置。

## 推荐学习路径

```
BasicAgent → StreamingAgent → CustomTools → CustomSystemPromptExample
    → PromptAPIExample → MultiToolExample → SubagentExample
    → PermissionsExample → MCPIntegration → AdvancedMCPExample
    → SessionsAndHooks → SkillsExample → SandboxExample
    → LoggerExample → ModelSwitchingExample → QueryAbortExample
    → ContextInjectionExample → MultiTurnExample → OpenAICompatExample
    → PolyvLiveExample
```

1. **从这里开始：** BasicAgent、StreamingAgent — 理解核心 prompt/stream API
2. **添加工具：** CustomTools、CustomSystemPromptExample — 学习工具定义和提示词定制
3. **使用内置工具：** PromptAPIExample、MultiToolExample — 观察自主使用工具的 Agent
4. **多 Agent：** SubagentExample — 将任务委派给子 Agent
5. **安全控制：** PermissionsExample — 控制 Agent 可以使用哪些工具
6. **MCP 集成：** MCPIntegration、AdvancedMCPExample — 连接外部工具服务器
7. **持久化：** SessionsAndHooks — 保存会话和注册生命周期钩子
8. **技能系统：** SkillsExample、PolyvLiveExample — 注册和执行内置/自定义技能，使用 SKILL.md 自动发现
9. **沙盒与日志：** SandboxExample、LoggerExample — 限制操作范围和捕获日志
10. **高级控制：** ModelSwitchingExample、QueryAbortExample — 运行时模型切换和查询中断
11. **上下文与多轮对话：** ContextInjectionExample、MultiTurnExample — 文件缓存、上下文注入、多轮对话
12. **OpenAI 兼容：** OpenAICompatExample — 使用 DeepSeek、Qwen、Ollama 等 OpenAI 兼容 API
13. **SDK 兼容性验证：** Compat* 示例 — 验证 TypeScript SDK API 对齐（适合 SDK 贡献者）

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

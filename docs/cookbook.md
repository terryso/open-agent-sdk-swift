# OpenAgentSDK Cookbook

> 按场景组织的实战指南 — 从 5 行代码到生产级 Agent

本文档将 SDK 的各项功能按**实际使用场景**组织，每个场景包含可直接运行的代码示例和功能组合说明。

详细的单功能文档请参考：
- [快速开始](getting-started.md) — 安装与环境配置
- [工具开发指南](tool-development-guide.md) — defineTool 与 ToolProtocol
- [Agent 定制指南](agent-customization-guide.md) — AgentOptions、权限、Hook
- [MCP 集成指南](mcp-integration-guide.md) — MCP 协议与传输配置
- [会话与记忆指南](session-memory-guide.md) — SessionStore 与 MemoryStore

---

## 场景索引

| # | 场景 | 核心功能 |
|---|------|----------|
| 1 | [最小可用 Agent](#场景-1最小可用-agent) | `prompt()` |
| 2 | [流式响应与实时处理](#场景-2流式响应与实时处理) | `stream()`、`SDKMessage` |
| 3 | [自定义工具开发](#场景-3自定义工具开发) | `defineTool()`、`ToolProtocol` |
| 4 | [多 LLM 提供商适配](#场景-4多-llm-提供商适配) | `provider`、`baseURL`、`switchModel()` |
| 5 | [权限控制与安全策略](#场景-5权限控制与安全策略) | `PermissionMode`、Policy、Sandbox |
| 6 | [Hook 生命周期管理](#场景-6hook-生命周期管理) | `HookRegistry`、`HookEvent` |
| 7 | [会话持久化与恢复](#场景-7会话持久化与恢复) | `SessionStore`、compaction |
| 8 | [多 Agent 协作编排](#场景-8多-agent-协作编排) | `AgentDefinition`、Team、Task |
| 9 | [MCP 外部工具集成](#场景-9mcp-外部工具集成) | `McpServerConfig`、`InProcessMCPServer` |
| 10 | [Skills 技能系统](#场景-10skills-技能系统) | `Skill`、`SkillRegistry` |
| 11 | [上下文注入与项目感知](#场景-11上下文注入与项目感知) | `projectRoot`、Git、FileCache |
| 12 | [Sandbox 沙箱隔离](#场景-12sandbox-沙箱隔离) | `SandboxSettings`、网络限制 |
| 13 | [结构化输出与深度推理](#场景-13结构化输出与深度推理) | `OutputFormat`、`ThinkingConfig`、`EffortLevel` |
| 14 | [查询中断与 Pause/Resume](#场景-14查询中断与-pauseresume) | `interrupt()`、`pause()`、`resume()` |
| 15 | [日志、监控与调试](#场景-15日志监控与调试) | `LogLevel`、`LogOutput`、成本追踪 |
| 16 | [完整生产级 Agent 配置](#场景-16完整生产级-agent-配置) | 综合配置模板 |

---

## 场景 1：最小可用 Agent

最简单的 Agent 只需要 API Key 和一行 `prompt()` 调用。

```swift
import OpenAgentSDK

let agent = createAgent(options: AgentOptions(apiKey: "sk-..."))
let result = await agent.prompt("用一句话解释 Swift 并发")
print(result.text)
// 输出 token 用量
print("Tokens: \(result.usage.inputTokens) in / \(result.usage.outputTokens) out")
```

**`QueryResult` 关键字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `text` | `String` | Agent 最终回复文本 |
| `usage` | `TokenUsage` | 输入/输出 token 统计 |
| `numTurns` | `Int` | Agent 循环执行轮次 |
| `durationMs` | `Int` | 查询总耗时（毫秒） |
| `status` | `QueryStatus` | 终止状态（success/errorMaxTurns/cancelled 等） |
| `totalCostUsd` | `Double` | 本次查询总成本（美元） |
| `costBreakdown` | `[CostBreakdownEntry]` | 按模型拆分的成本明细 |
| `isCancelled` | `Bool` | 是否被用户取消 |

> 更详细的快速开始教程见 [getting-started.md](getting-started.md)。

---

## 场景 2：流式响应与实时处理

使用 `stream()` 获取 `AsyncStream<SDKMessage>`，实时处理 Agent 的每个执行阶段。

```swift
for await message in agent.stream("读取 Package.swift 并总结") {
    switch message {
    case .partialMessage(let data):
        // 流式文本片段 — 实时打印
        print(data.text, terminator: "")

    case .toolUse(let data):
        // Agent 调用工具
        print("\n[工具调用] \(data.toolName)")

    case .toolResult(let data):
        // 工具返回结果
        if data.isError {
            print("[工具错误] \(data.content)")
        }

    case .result(let data):
        // 查询结束 — 获取完整统计
        print("\n完成: \(data.numTurns) 轮, \(data.durationMs)ms, $\(String(format: "%.4f", data.totalCostUsd))")
        // 按模型的成本拆分
        for entry in data.costBreakdown {
            print("  \(entry.model): $\(String(format: "%.4f", entry.costUsd))")
        }

    case .system(let data):
        // 系统事件（初始化、compaction、暂停等）
        switch data.subtype {
        case .init:
            print("[初始化] 模型: \(data.model ?? "?"), 工具数: \(data.tools?.count ?? 0)")
        case .compactBoundary:
            print("[压缩] \(data.message)")
        default:
            break
        }

    case .toolProgress(let data):
        // 工具执行进度（长时间操作）
        print("[进度] \(data.toolName) - \(data.elapsedTimeSeconds ?? 0)s")

    default:
        break
    }
}
```

### SDKMessage 事件类型一览

| 事件 | 数据类型 | 触发时机 |
|------|---------|----------|
| `.partialMessage` | `PartialData` | 流式文本片段 |
| `.assistant` | `AssistantData` | 完整的助手回复 |
| `.toolUse` | `ToolUseData` | LLM 请求调用工具 |
| `.toolResult` | `ToolResultData` | 工具执行返回结果 |
| `.toolProgress` | `ToolProgressData` | 工具执行中进度 |
| `.result` | `ResultData` | 查询最终结果 |
| `.system` | `SystemData` | 系统级事件 |
| `.userMessage` | `UserMessageData` | 用户消息 |
| `.hookStarted` | `HookStartedData` | Hook 开始执行 |
| `.hookResponse` | `HookResponseData` | Hook 执行完成 |
| `.taskStarted` | `TaskStartedData` | 子任务启动 |
| `.taskProgress` | `TaskProgressData` | 子任务进度 |
| `.promptSuggestion` | `PromptSuggestionData` | 建议的后续提示 |
| `.toolUseSummary` | `ToolUseSummaryData` | 工具使用汇总 |

---

## 场景 3：自定义工具开发

### 3.1 最简工具 — Codable 输入 + 字符串返回

```swift
struct WeatherInput: Codable {
    let city: String
}

let weatherTool = defineTool(
    name: "get_weather",
    description: "获取指定城市的天气信息",
    inputSchema: [
        "type": "object",
        "properties": [
            "city": ["type": "string", "description": "城市名称"]
        ],
        "required": ["city"]
    ]
) { (input: WeatherInput, context: ToolContext) in
    return "\(input.city)：22°C，晴天"
}
```

### 3.2 结构化返回 — ToolExecuteResult

```swift
struct SearchInput: Codable {
    let query: String
    let limit: Int?
}

let searchTool = defineTool(
    name: "search_docs",
    description: "搜索文档库",
    inputSchema: [
        "type": "object",
        "properties": [
            "query": ["type": "string"],
            "limit": ["type": "integer"]
        ],
        "required": ["query"]
    ]
) { (input: SearchInput, context: ToolContext) in
    // 返回结构化结果，可标记为错误
    return ToolExecuteResult(
        content: "找到 3 条结果...",
        isError: false
    )
}
```

### 3.3 无输入工具

```swift
let timeTool = defineTool(
    name: "current_time",
    description: "获取当前时间",
    inputSchema: ["type": "object", "properties": [:]]
) { (context: ToolContext) in
    return Date().description
}
```

### 3.4 使用 ToolContext

`ToolContext` 在工具执行时提供运行时上下文：

```swift
let tool = defineTool(
    name: "read_project_file",
    description: "读取项目文件",
    inputSchema: [
        "type": "object",
        "properties": ["path": ["type": "string"]],
        "required": ["path"]
    ]
) { (input: FileInput, context: ToolContext) in
    // context.cwd — 当前工作目录
    // context.toolUseId — 本次工具调用的唯一 ID
    // context.sessionId — 会话 ID（如有）
    // context.agentSpawner — 子 Agent 生成器（如有）
    // context.memoryStore — 知识存储（如有）
    let fullPath = (context.cwd ?? ".") + "/" + input.path
    return try String(contentsOfFile: fullPath)
}
```

### 3.5 注册到 Agent

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    tools: [weatherTool, searchTool, timeTool, tool]
))
```

> 完整的工具开发说明见 [tool-development-guide.md](tool-development-guide.md)。

---

## 场景 4：多 LLM 提供商适配

### 4.1 Anthropic（默认）

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-ant-...",
    model: "claude-sonnet-4-6",
    provider: .anthropic
))
```

### 4.2 OpenAI 兼容 API（GLM、Ollama、OpenRouter 等）

```swift
let agent = createAgent(options: AgentOptions(
    provider: .openai,
    apiKey: "sk-...",
    model: "gpt-4o",
    baseURL: "https://api.openai.com/v1"
))
```

通过环境变量配置：

```bash
export CODEANY_API_KEY=sk-...
export CODEANY_BASE_URL=https://api.openai.com/v1
export CODEANY_MODEL=gpt-4o
```

### 4.3 运行时动态切换模型

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    model: "claude-sonnet-4-6"
))

// 简单问题用快速模型
let r1 = await agent.prompt("简单问题...")

// 切到强力模型处理复杂任务
try agent.switchModel("claude-opus-4-7")
let r2 = await agent.prompt("分析这段复杂代码...")

// r2.usage 中包含 per-model 的 costBreakdown
for entry in r2.costBreakdown {
    print("\(entry.model): \(entry.inputTokens) in, \(entry.outputTokens) out, $\(entry.costUsd)")
}
```

### 4.4 Fallback Model

配置备用模型，主模型不可用时自动切换：

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    model: "claude-opus-4-7",
    fallbackModel: "claude-sonnet-4-6"  // opus 失败时自动降级
))
```

---

## 场景 5：权限控制与安全策略

### 5.1 六种 PermissionMode 选择

```swift
// 1. default — 所有写操作需要确认
AgentOptions(permissionMode: .default)

// 2. acceptEdits — 文件编辑自动批准，危险操作需确认
AgentOptions(permissionMode: .acceptEdits)

// 3. bypassPermissions — 全部自动批准（开发/测试用）
AgentOptions(permissionMode: .bypassPermissions)

// 4. plan — 只读模式，只允许不修改文件系统的工具
AgentOptions(permissionMode: .plan)

// 5. dontAsk — 自动批准所有操作，不弹确认
AgentOptions(permissionMode: .dontAsk)

// 6. auto — 自动决策，对已知安全操作直接批准
AgentOptions(permissionMode: .auto)
```

| 模式 | 读操作 | 写操作 | 危险命令 | 适用场景 |
|------|--------|--------|----------|----------|
| `.default` | 允许 | 需确认 | 需确认 | 通用开发 |
| `.acceptEdits` | 允许 | 允许 | 需确认 | 信任 Agent 的编辑 |
| `.bypassPermissions` | 允许 | 允许 | 允许 | CI/CD、自动化 |
| `.plan` | 允许 | 拒绝 | 拒绝 | 只读分析 |
| `.dontAsk` | 允许 | 允许 | 允许 | 无人值守 |
| `.auto` | 允许 | 自动 | 自动 | 智能自动决策 |

### 5.2 自定义 CanUseToolFn 回调

```swift
agent.setCanUseTool { tool, input, context in
    if tool.name == "Bash" {
        return .deny("Bash 工具已被禁用")
    }
    if tool.name == "WebFetch" {
        return .deny("禁止访问网络")
    }
    return .allow()
}
```

### 5.3 Policy 组合模式

```swift
// 只读 + 排除特定工具
let policy = CompositePolicy(policies: [
    ReadOnlyPolicy(),
    ToolNameDenylistPolicy(deniedToolNames: ["WebFetch", "WebSearch"])
])
agent.setCanUseTool(canUseTool(policy: policy))

// 白名单模式 — 只允许特定工具
let strictPolicy = ToolNameAllowlistPolicy(allowedToolNames: ["Read", "Glob", "Grep"])
agent.setCanUseTool(canUseTool(policy: strictPolicy))
```

Policy 评估规则：
- `CompositePolicy` 按顺序评估，任何 deny 立即短路
- 子 Policy 返回 `nil` 表示"无意见"，跳过
- 全部 allow/nil 则最终 allow

### 5.4 运行时切换权限

```swift
// 切换到只读模式
agent.setPermissionMode(.plan)

// 切换到全自动
agent.setPermissionMode(.bypassPermissions)
```

> 注意：`setPermissionMode()` 会清除自定义的 `canUseTool` 回调。

---

## 场景 6：Hook 生命周期管理

### 6.1 22 个 HookEvent 分组

| 分组 | 事件 | 触发时机 |
|------|------|----------|
| **工具** | `preToolUse` | 工具执行前 |
| | `postToolUse` | 工具执行成功后 |
| | `postToolUseFailure` | 工具执行失败后 |
| **会话** | `sessionStart` | 会话开始 |
| | `sessionEnd` | 会话结束 |
| **循环** | `stop` | Agent 循环终止 |
| | `userPromptSubmit` | 用户提交 prompt |
| **子 Agent** | `subagentStart` | 子 Agent 启动 |
| | `subagentStop` | 子 Agent 完成 |
| **权限** | `permissionRequest` | 权限检查 |
| | `permissionDenied` | 权限被拒绝 |
| **任务** | `taskCreated` | 任务创建 |
| | `taskCompleted` | 任务完成 |
| **配置** | `configChange` | 配置变更 |
| | `cwdChanged` | 工作目录变更 |
| **文件** | `fileChanged` | 文件变更 |
| **通知** | `notification` | 通知事件 |
| **Compaction** | `preCompact` | 压缩前 |
| | `postCompact` | 压缩后 |
| **协作** | `teammateIdle` | 队友空闲 |
| **初始化** | `setup` | Agent 设置 |
| **Worktree** | `worktreeCreate` | 创建工作树 |
| | `worktreeRemove` | 移除工作树 |

### 6.2 函数 Hook — 工具执行审计

```swift
let hookRegistry = HookRegistry()

// 记录所有工具调用
await hookRegistry.register(.postToolUse, definition: HookDefinition(
    handler: { input in
        print("[审计] \(input.toolName ?? "?") 完成")
        if let output = input.toolOutput {
            print("  输出: \(output)")
        }
        return nil  // nil = 不干预
    }
))
```

### 6.3 函数 Hook — 阻止危险命令

```swift
// 阻止 Bash 执行危险命令
await hookRegistry.register(.preToolUse, definition: HookDefinition(
    matcher: "Bash",  // 只匹配 Bash 工具
    handler: { input in
        if let cmd = input.toolInput as? String, cmd.contains("rm -rf") {
            return HookOutput(
                decision: .block,
                message: "禁止执行 rm -rf 命令",
                reason: "安全策略：不允许递归强制删除"
            )
        }
        return HookOutput(decision: .approve)
    }
))
```

### 6.4 Shell Hook — 外部脚本处理

```swift
// 调用外部脚本处理 Hook（输入通过 stdin JSON 传入）
await hookRegistry.register(.postToolUse, definition: HookDefinition(
    matcher: "Write",
    command: "/usr/local/bin/notify-write.sh",
    timeout: 5000  // 5 秒超时
))
```

### 6.5 HookOutput 决策能力

```swift
// 修改工具输入
HookOutput(
    decision: .approve,
    updatedInput: ["command": "ls -la"],  // 替换原始输入
    reason: "将 ls 替换为 ls -la"
)

// 动态更新权限
HookOutput(
    decision: .approve,
    permissionUpdate: PermissionUpdate(tool: "Bash", behavior: .allow),
    message: "临时允许 Bash"
)

// 发送通知
HookOutput(
    decision: .approve,
    notification: HookNotification(
        title: "文件修改",
        body: "Agent 修改了 main.swift",
        level: .warning
    )
)
```

### 6.6 注册到 Agent

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    hookRegistry: hookRegistry
))
```

---

## 场景 7：会话持久化与恢复

### 7.1 基本持久化

```swift
let sessionStore = SessionStore()

let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    sessionStore: sessionStore,
    sessionId: "user-123-session-1"
))

// 第一次对话 — 自动保存
let r1 = await agent.prompt("记住：我最喜欢的颜色是蓝色")

// 新进程中恢复 — 自动加载历史
let agent2 = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    sessionStore: sessionStore,
    sessionId: "user-123-session-1"
))
let r2 = await agent2.prompt("我最喜欢的颜色是什么？")
// Agent 会回答"蓝色"
```

### 7.2 继续最近的会话

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    sessionStore: sessionStore,
    continueRecentSession: true  // 自动恢复最近一次会话
))
```

### 7.3 Fork 会话 — 从历史节点分支

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    sessionStore: sessionStore,
    sessionId: "original-session",
    forkSession: true  // 复制当前会话到新分支
))
```

### 7.4 从指定消息恢复

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    sessionStore: sessionStore,
    sessionId: "my-session",
    resumeSessionAt: "msg-uuid-456"  // 从该消息之后截断并继续
))
```

### 7.5 临时会话 — 不持久化

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    sessionStore: sessionStore,
    sessionId: "temp-session",
    persistSession: false  // 不写入存储
))
```

### 7.6 Auto-Compaction 自动压缩

当对话长度接近上下文窗口限制时，SDK 自动压缩历史消息。可通过 Hook 监听：

```swift
await hookRegistry.register(.preCompact, definition: HookDefinition(
    handler: { input in
        print("[压缩] 触发: \(input.trigger ?? "auto")")
        return nil
    }
))

await hookRegistry.register(.postCompact, definition: HookDefinition(
    handler: { input in
        print("[压缩] 完成")
        return nil
    }
))
```

---

## 场景 8：多 Agent 协作编排

### 8.1 基本子 Agent

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    tools: getAllBaseTools(tier: .core) + [
        createAgentTool(),
        createSendMessageTool()
    ]
))

// Agent 的 LLM 会通过 AgentTool 自动生成子 Agent
let result = await agent.prompt("用 Explore 类型的子 Agent 搜索项目中的测试文件")
```

### 8.2 AgentDefinition 精细控制

```swift
let definition = AgentDefinition(
    name: "code-reviewer",
    description: "代码审查专家",
    model: "claude-opus-4-7",           // 可指定不同模型
    systemPrompt: "你是严格的代码审查专家，只关注安全和性能问题。",
    tools: ["Read", "Glob", "Grep"],     // 限制可用工具
    maxTurns: 5,                          // 限制轮次
    disallowedTools: ["Bash", "Write"],   // 禁止危险工具
    skills: ["review"]                    // 可用技能
)
```

### 8.3 AgentOutput 三态处理

```swift
// 子 Agent 执行结果有三种形态
switch output {
case .completed(let data):
    // 同步完成 — 获取完整结果
    print("内容: \(data.content)")
    print("工具调用: \(data.totalToolUseCount) 次")
    print("耗时: \(data.totalDurationMs) ms")
    print("Token: \(data.totalTokens)")

case .asyncLaunched(let data):
    // 后台启动 — 继续执行，稍后获取结果
    print("后台 Agent: \(data.agentId)")
    print("输出文件: \(data.outputFile ?? "无")")

case .subAgentEntered(let data):
    // 同步进入 — Agent 正在等待子 Agent 完成
    print("进入子 Agent: \(data.description)")
}
```

### 8.4 Team + Task 多 Agent 管理

```swift
// 配置共享的 Store
let taskStore = TaskStore()
let teamStore = TeamStore()
let mailboxStore = MailboxStore()

let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    taskStore: taskStore,
    teamStore: teamStore,
    mailboxStore: mailboxStore,
    tools: getAllBaseTools(tier: .core) + getAllBaseTools(tier: .advanced)
))

// LLM 会使用 TeamCreate/TaskCreate/SendMessage 等工具进行多 Agent 协作
let result = await agent.prompt("""
    创建一个团队来重构代码：
    1. 创建代码分析子 Agent 找出需要重构的文件
    2. 创建重构子 Agent 执行修改
    3. 创建测试子 Agent 验证结果
""")
```

### 8.5 AgentRegistry — Agent 发现与注册

```swift
let registry = AgentRegistry()

// 注册 Agent 定义
await registry.register(
    AgentRegistryEntry(
        name: "researcher",
        agentType: "Explore",
        description: "快速搜索和探索代码库"
    )
)

// 发现可用 Agent
let agents = await registry.list()
```

---

## 场景 9：MCP 外部工具集成

### 9.1 Stdio 传输 — 启动子进程

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    mcpServers: [
        "filesystem": .stdio(McpStdioConfig(
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
        ))
    ]
))
// MCP 工具自动发现并合并到 Agent 的工具池
```

### 9.2 SSE 传输 — Server-Sent Events

```swift
"remote-tools": .sse(McpTransportConfig(
    url: "http://localhost:3001/sse",
    headers: ["Authorization": "Bearer token123"]
))
```

### 9.3 HTTP 传输 — HTTP POST

```swift
"api-tools": .http(McpTransportConfig(
    url: "http://localhost:8080/mcp"
))
```

### 9.4 SDK 传输 — 进程内直接集成

```swift
// 实现 InProcessMCPServer 协议
actor MyMCPServer: InProcessMCPServer {
    let name = "my-tools"
    let version = "1.0.0"

    func listTools() -> [[String: Any]] {
        return [[
            "name": "calculate",
            "description": "执行计算",
            "inputSchema": ["type": "object", "properties": ["expr": ["type": "string"]]]
        ]]
    }

    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        return "result"
    }
}

let server = MyMCPServer()
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    mcpServers: [
        "my-tools": .sdk(McpSdkServerConfig(name: "my-tools", version: "1.0.0", server: server))
    ]
))
```

### 9.5 ClaudeAI Proxy 传输

```swift
"proxy": .claudeAIProxy(McpClaudeAIProxyConfig(
    url: "https://proxy.example.com/mcp",
    id: "server-123"
))
```

### 9.6 运行时 MCP 管理

```swift
// 查看 MCP 服务器状态
let status = await agent.mcpServerStatus()
for (name, info) in status {
    print("\(name): \(info)")
}

// 重连
try await agent.reconnectMcpServer(name: "filesystem")

// 启用/禁用
try await agent.toggleMcpServer(name: "remote-tools", enabled: false)

// 动态添加
let result = try await agent.setMcpServers([
    "new-server": .stdio(McpStdioConfig(command: "my-server"))
])
```

### 9.7 AgentMCPServer — 将 Agent 暴露为 MCP 服务

```swift
// 将当前 Agent 的工具暴露为 MCP stdio 服务
let mcpServer = AgentMCPServer(agent: agent, serverName: "my-agent-server")
try await mcpServer.start()
// 其他 MCP 客户端可以通过 stdio 连接使用 Agent 的工具
```

---

## 场景 10：Skills 技能系统

### 10.1 内置 Skill

SDK 提供 5 个内置 Skill，通过 `BuiltInSkills` 访问：

| Skill | 别名 | 功能 | 允许的工具 |
|-------|------|------|-----------|
| `commit` | `ci` | 分析变更并建议 commit message | Bash, Read, Glob, Grep |
| `review` | `review-pr`, `cr` | 五维度代码审查 | Bash, Read, Glob, Grep |
| `simplify` | — | 代码简化建议 | Bash, Read, Grep, Glob |
| `debug` | `investigate`, `diagnose` | 错误诊断与根因分析 | Read, Grep, Glob, Bash |
| `test` | `run-tests` | 生成并执行测试用例 | Bash, Read, Write, Glob, Grep |

```swift
let registry = SkillRegistry()
registry.register(BuiltInSkills.commit)
registry.register(BuiltInSkills.review)
registry.register(BuiltInSkills.simplify)
registry.register(BuiltInSkills.debug)
registry.register(BuiltInSkills.test)

let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    skillRegistry: registry,
    tools: getAllBaseTools(tier: .core) + [createSkillTool(registry: registry)]
))
```

### 10.2 自定义 Skill

```swift
let explainSkill = Skill(
    name: "explain",
    description: "详细解释代码实现",
    aliases: ["explain-code"],
    userInvocable: true,
    toolRestrictions: [.read, .glob, .grep],  // 只允许这三个工具
    modelOverride: "claude-opus-4-7",          // 用强力模型
    promptTemplate: """
    阅读指定文件，逐行解释代码实现。包括：
    1. 每个函数的职责和设计意图
    2. 关键数据流和控制流
    3. 潜在的边界条件处理
    """,
    whenToUse: "当用户需要深入理解代码时使用",
    argumentHint: "[file-path]"
)

registry.register(explainSkill)
```

### 10.3 文件系统 Skill 发现

```swift
// 从指定目录自动发现 SKILL.md 定义
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    skillDirectories: ["/path/to/skills"],
    skillNames: ["commit", "review", "custom-skill"],  // 可选过滤
    maxSkillRecursionDepth: 4  // 防止无限递归
))
```

### 10.4 Skill 的运行时可用性检查

```swift
let skill = Skill(
    name: "swift-test",
    description: "运行 Swift 测试",
    promptTemplate: "运行 swift test 并分析结果...",
    isAvailable: {
        FileManager.default.fileExists(atPath: "Package.swift")
    }
)
```

---

## 场景 11：上下文注入与项目感知

### 11.1 Project Root 自动发现

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    projectRoot: "/path/to/project"
))
```

SDK 自动扫描以下文件并注入系统提示：
- `CLAUDE.md` — 项目级指令
- `AGENT.md` — Agent 行为指令
- `.claude/settings.json` — 项目设置

### 11.2 Git 状态注入

设置 `projectRoot` 后，SDK 自动缓存并注入 Git 上下文：

```
<git-context>
Branch: main
Status: 2 modified, 1 untracked
Recent commits: ...
</git-context>
```

可通过 `gitCacheTTL` 控制缓存刷新频率：

```swift
AgentOptions(
    gitCacheTTL: 10.0  // 10 秒内复用缓存，0 = 禁用缓存
)
```

### 11.3 FileCache LRU 缓存

```swift
AgentOptions(
    fileCacheMaxEntries: 200,          // 最大缓存条目数（默认 100）
    fileCacheMaxSizeBytes: 50 * 1024 * 1024,   // 总缓存大小（默认 25MB）
    fileCacheMaxEntrySizeBytes: 10 * 1024 * 1024  // 单文件上限（默认 5MB）
)
```

### 11.4 环境变量注入

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    env: [
        "HOME": "/custom/home",
        "PATH": "/usr/local/bin:/usr/bin",
        "CUSTOM_VAR": "value"
    ]
))
```

---

## 场景 12：Sandbox 沙箱隔离

### 12.1 命令控制

```swift
// Blocklist 模式 — 禁止危险命令
let sandbox = SandboxSettings(
    deniedCommands: ["rm", "sudo", "chmod", "chown", "mkfs"]
)

// Allowlist 模式 — 只允许特定命令
let sandbox = SandboxSettings(
    allowedCommands: ["git", "swift", "xcodebuild", "ls", "cat"]
)
```

### 12.2 路径读写分离

```swift
let sandbox = SandboxSettings(
    allowedReadPaths: ["/project/"],       // 只能读取 /project/ 下的文件
    allowedWritePaths: ["/project/build/"], // 只能写入 /project/build/
    deniedPaths: ["/etc/", "/var/", "/System/"]  // 绝对禁止
)
```

路径检查使用前缀匹配 + 段边界：
- `/project/` 匹配 `/project/src/file.swift`
- `/project/` **不匹配** `/project-backup/file.swift`

### 12.3 网络限制

```swift
let sandbox = SandboxSettings(
    network: SandboxNetworkConfig(
        allowedDomains: ["api.example.com", "github.com"],
        allowLocalBinding: false,
        allowUnixSockets: false,
        httpProxyPort: 8080
    )
)
```

### 12.4 完整沙箱配置

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    sandbox: SandboxSettings(
        allowedReadPaths: ["/project/"],
        allowedWritePaths: ["/project/src/"],
        deniedPaths: ["/etc/", "/var/"],
        deniedCommands: ["rm", "sudo"],
        autoAllowBashIfSandboxed: true,  // 沙箱内自动批准 Bash
        allowNestedSandbox: false,
        allowUnsandboxedCommands: false,
        network: SandboxNetworkConfig(
            allowedDomains: ["api.anthropic.com"]
        )
    )
))
```

---

## 场景 13：结构化输出与深度推理

### 13.1 结构化输出 — JSON Schema

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    systemPrompt: "你是一个数据分析助手。",
    outputFormat: OutputFormat(jsonSchema: [
        "type": "object",
        "properties": [
            "summary": ["type": "string"],
            "confidence": ["type": "number"],
            "categories": [
                "type": "array",
                "items": ["type": "string"]
            ]
        ],
        "required": ["summary", "confidence"]
    ]
))

let result = await agent.prompt("分析这段代码的质量")
// result 中包含结构化输出
```

### 13.2 ThinkingConfig — 深度思考

```swift
// 自适应 — 让模型自己决定是否深度思考
AgentOptions(thinking: .adaptive)

// 指定预算 — 强制深度思考
AgentOptions(thinking: .enabled(budgetTokens: 10000))

// 禁用
AgentOptions(thinking: .disabled)
```

### 13.3 EffortLevel — 推理深度控制

```swift
AgentOptions(effort: .low)     // 1024 tokens, 最快
AgentOptions(effort: .medium)  // 5120 tokens, 平衡
AgentOptions(effort: .high)    // 10240 tokens, 深入
AgentOptions(effort: .max)     // 32768 tokens, 最深
```

### 13.4 组合使用

```swift
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    model: "claude-sonnet-4-6",
    effort: .high,
    thinking: .enabled(budgetTokens: 10240),
    outputFormat: OutputFormat(jsonSchema: [
        "type": "object",
        "properties": [
            "analysis": ["type": "string"],
            "recommendations": ["type": "array", "items": ["type": "string"]],
            "riskLevel": ["type": "string", "enum": ["low", "medium", "high"]]
        ]
    ]),
    maxTokens: 8192
))

let result = await agent.prompt("对这个系统架构进行安全性评估")
```

---

## 场景 14：查询中断与 Pause/Resume

### 14.1 查询中断 — interrupt()

```swift
let task = Task {
    let result = await agent.stream("长时间分析任务...")
    for await message in result {
        // 处理流式消息
    }
}

// 3 秒后取消
Task {
    try? await Task.sleep(nanoseconds: 3_000_000_000)
    agent.interrupt()  // 或 task.cancel()
}
```

`interrupt()` 触发后：
- Agent 返回 `QueryResult`，`isCancelled = true`
- 包含已收集的部分结果
- `status = .cancelled`

### 14.2 Pause/Resume — 人机交互

```swift
// 配置 pause 超时
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    pauseTimeoutMs: 300_000  // 5 分钟超时（默认）
))

// 触发暂停（通常由 LLM 通过 PauseForHumanTool 调用）
agent.pause(reason: "需要人工确认数据库迁移脚本")

// ... 人工审查后 ...
agent.resume(context: "已确认迁移脚本安全，可以继续执行")
```

`PauseResult` 三态：
- `.resumed(context: String)` — 人工恢复，携带上下文
- `.aborted` — 被 `interrupt()` 中断
- `.timedOut` — 超时自动取消

### 14.3 流式场景中的 Pause 事件

```swift
for await message in agent.stream("...") {
    switch message {
    case .system(let data) where data.subtype == .paused:
        print("Agent 暂停: \(data.pausedData?.reason ?? "")")
        // 通知 UI 显示暂停状态
    case .system(let data) where data.subtype == .pausedTimeout:
        print("暂停超时")
    default:
        break
    }
}
```

---

## 场景 15：日志、监控与调试

### 15.1 LogLevel 配置

```swift
AgentOptions(
    logLevel: .none,   // 静默（默认）
    logLevel: .error,  // 只记录错误
    logLevel: .warn,   // 警告 + 错误
    logLevel: .info,   // 信息 + 警告 + 错误
    logLevel: .debug   // 全部日志
)
```

### 15.2 LogOutput — 输出目标

```swift
// 控制台（stderr，默认）
AgentOptions(logOutput: .console)

// 文件
AgentOptions(logOutput: .file(URL(fileURLWithPath: "/var/log/sdk.log")))

// 自定义 — 集成 ELK/Datadog
AgentOptions(logOutput: .custom { jsonLine in
    myLogAggregator.ingest(jsonLine)
})
```

### 15.3 成本追踪

```swift
let result = await agent.prompt("...")

// 总成本
print("总成本: $\(String(format: "%.6f", result.totalCostUsd))")

// 按模型拆分（切换过模型时会有多条）
for entry in result.costBreakdown {
    print("""
    \(entry.model):
      输入: \(entry.inputTokens) tokens
      输出: \(entry.outputTokens) tokens
      成本: $\(String(format: "%.6f", entry.costUsd))
    """)
}

// 预算控制
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    maxBudgetUsd: 0.10  // 超过 $0.10 自动停止
))
```

### 15.4 QueryStatus 诊断

```swift
switch result.status {
case .success:
    print("正常完成")
case .errorMaxTurns:
    print("达到最大轮次限制，考虑增大 maxTurns")
case .errorDuringExecution:
    print("执行错误: \(result.errors ?? [])")
case .errorMaxBudgetUsd:
    print("超出预算限制")
case .cancelled:
    print("用户取消")
}
```

---

## 场景 16：完整生产级 Agent 配置

将多个功能组合为一个生产级 Agent：

```swift
// 1. 创建 Hook 注册表
let hooks = HookRegistry()

// 审计所有工具调用
await hooks.register(.postToolUse, definition: HookDefinition(
    handler: { input in
        auditLogger.log(tool: input.toolName, session: input.sessionId)
        return nil
    }
))

// 阻止危险 Bash 命令
await hooks.register(.preToolUse, definition: HookDefinition(
    matcher: "Bash",
    handler: { input in
        // 检查危险命令模式
        return HookOutput(decision: .approve)
    }
))

// 2. 创建 Skill 注册表
let skills = SkillRegistry()
skills.register(BuiltInSkills.commit)
skills.register(BuiltInSkills.review)
skills.register(BuiltInSkills.debug)
skills.register(BuiltInSkills.test)

// 3. 创建 Session 存储
let sessionStore = SessionStore()

// 4. 创建生产级 Agent
let agent = createAgent(options: AgentOptions(
    // 基础配置
    apiKey: "sk-...",
    model: "claude-sonnet-4-6",
    systemPrompt: "你是一个专业的 Swift 开发助手。遵循项目编码规范，所有修改需通过测试验证。",

    // 循环控制
    maxTurns: 30,
    maxTokens: 16384,
    maxBudgetUsd: 1.0,

    // 推理配置
    effort: .high,
    thinking: .adaptive,

    // 权限与安全
    permissionMode: .acceptEdits,
    sandbox: SandboxSettings(
        deniedCommands: ["rm -rf", "sudo", "mkfs"],
        deniedPaths: ["/etc/", "/System/"],
        allowedWritePaths: ["/project/src/"],
        autoAllowBashIfSandboxed: true,
        network: SandboxNetworkConfig(
            allowedDomains: ["api.anthropic.com", "github.com"]
        )
    ),

    // 上下文
    projectRoot: "/project",
    gitCacheTTL: 10.0,
    cwd: "/project/src",

    // 工具
    tools: getAllBaseTools(tier: .core) + [createSkillTool(registry: skills)],
    mcpServers: [
        "filesystem": .stdio(McpStdioConfig(
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem", "/project"]
        ))
    ],

    // 会话
    sessionStore: sessionStore,
    sessionId: "prod-session-\(UUID().uuidString)",
    persistSession: true,

    // Hook
    hookRegistry: hooks,

    // Skill
    skillRegistry: skills,
    maxSkillRecursionDepth: 4,

    // 文件缓存
    fileCacheMaxEntries: 200,
    fileCacheMaxSizeBytes: 50 * 1024 * 1024,

    // 日志
    logLevel: .info,
    logOutput: .custom { jsonLine in
        // 发送到日志聚合服务
        LogAggregator.shared.ingest(jsonLine)
    },

    // 其他
    fallbackModel: "claude-sonnet-4-6",
    enableFileCheckpointing: true,
    promptSuggestions: true,
    includePartialMessages: true
))
```

### 最佳实践清单

**性能调优：**
- `fileCacheMaxEntries` / `fileCacheMaxSizeBytes` 根据项目大小调整
- `gitCacheTTL` 设为 5-10 秒平衡实时性和性能
- `maxTurns` 建议 20-50，根据任务复杂度调整
- `toolConfig` 可控制工具并发数

**安全加固：**
- 生产环境必须配置 `SandboxSettings`
- 使用 `CompositePolicy` 组合多种权限策略
- 通过 `deniedPaths` 保护系统目录
- `network.allowedDomains` 限制网络访问

**成本控制：**
- 始终设置 `maxBudgetUsd`
- 简单任务用 `effort: .low`，复杂任务用 `.high`
- 利用 `switchModel()` 在不同阶段使用不同模型
- 监控 `costBreakdown` 追踪成本分布

**可靠性：**
- 配置 `fallbackModel` 提高可用性
- 使用 `SessionStore` 保存会话防止丢失
- 通过 `RetryConfig` 控制重试策略
- 设置 `pauseTimeoutMs` 防止无限等待

---

## 附录 A：AgentOptions 完整字段参考

### 基础连接

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `apiKey` | `String?` | `nil` | API 密钥，nil 时从 `CODEANY_API_KEY` 读取 |
| `model` | `String` | `"claude-sonnet-4-6"` | 模型标识符 |
| `baseURL` | `String?` | `nil` | 自定义 API 端点 |
| `provider` | `LLMProvider` | `.anthropic` | 提供商：`.anthropic` 或 `.openai` |
| `fallbackModel` | `String?` | `nil` | 备用模型 |

### 提示词与输出

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `systemPrompt` | `String?` | `nil` | 系统提示词 |
| `systemPromptConfig` | `SystemPromptConfig?` | `nil` | 高级提示词配置（预设模板） |
| `maxTurns` | `Int` | `10` | Agent 循环最大轮次 |
| `maxTokens` | `Int` | `16384` | 单次请求最大输出 token |
| `outputFormat` | `OutputFormat?` | `nil` | 结构化输出 JSON Schema |
| `effort` | `EffortLevel?` | `nil` | 推理深度 (.low/.medium/.high/.max) |
| `thinking` | `ThinkingConfig?` | `nil` | 深度思考配置 |
| `includePartialMessages` | `Bool` | `true` | 是否包含流式部分消息 |
| `promptSuggestions` | `Bool` | `false` | 是否生成后续建议 |

### 预算与限制

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `maxBudgetUsd` | `Double?` | `nil` | 成本上限（美元） |
| `pauseTimeoutMs` | `Int` | `300000` | 暂停超时（毫秒） |

### 权限

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `permissionMode` | `PermissionMode` | `.default` | 权限模式 |
| `canUseTool` | `CanUseToolFn?` | `nil` | 自定义权限回调 |

### 工具

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `tools` | `[ToolProtocol]?` | `nil` | 自定义工具列表 |
| `allowedTools` | `[String]?` | `nil` | 工具白名单 |
| `disallowedTools` | `[String]?` | `nil` | 工具黑名单 |
| `toolConfig` | `ToolConfig?` | `nil` | 工具并发配置 |
| `mcpServers` | `[String: McpServerConfig]?` | `nil` | MCP 服务器配置 |

### 会话

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `sessionStore` | `SessionStore?` | `nil` | 会话存储 |
| `sessionId` | `String?` | `nil` | 会话 ID |
| `continueRecentSession` | `Bool` | `false` | 继续最近会话 |
| `forkSession` | `Bool` | `false` | Fork 当前会话 |
| `resumeSessionAt` | `String?` | `nil` | 从指定消息恢复 |
| `persistSession` | `Bool` | `true` | 是否持久化 |

### Hook 与 Skill

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `hookRegistry` | `HookRegistry?` | `nil` | Hook 注册表 |
| `skillRegistry` | `SkillRegistry?` | `nil` | Skill 注册表 |
| `skillDirectories` | `[String]?` | `nil` | Skill 发现目录 |
| `skillNames` | `[String]?` | `nil` | Skill 名称过滤 |
| `maxSkillRecursionDepth` | `Int` | `4` | Skill 递归深度上限 |

### 上下文与缓存

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `cwd` | `String?` | `nil` | 工作目录 |
| `projectRoot` | `String?` | `nil` | 项目根目录（自动发现 CLAUDE.md） |
| `env` | `[String: String]?` | `nil` | 注入的环境变量 |
| `fileCacheMaxEntries` | `Int` | `100` | 文件缓存最大条目 |
| `fileCacheMaxSizeBytes` | `Int` | `25MB` | 文件缓存总大小 |
| `fileCacheMaxEntrySizeBytes` | `Int` | `5MB` | 单文件缓存上限 |
| `gitCacheTTL` | `TimeInterval` | `5.0` | Git 上下文缓存 TTL |

### 多 Agent

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `agentName` | `String?` | `nil` | Agent 名称（多 Agent 标识） |
| `mailboxStore` | `MailboxStore?` | `nil` | 跨 Agent 消息存储 |
| `teamStore` | `TeamStore?` | `nil` | 团队管理存储 |
| `taskStore` | `TaskStore?` | `nil` | 任务管理存储 |
| `worktreeStore` | `WorktreeStore?` | `nil` | Worktree 存储 |
| `planStore` | `PlanStore?` | `nil` | 计划存储 |
| `cronStore` | `CronStore?` | `nil` | 定时任务存储 |
| `todoStore` | `TodoStore?` | `nil` | Todo 存储 |
| `memoryStore` | `MemoryStoreProtocol?` | `nil` | 跨运行知识存储 |

### 日志与沙箱

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `logLevel` | `LogLevel` | `.none` | 日志级别 |
| `logOutput` | `LogOutput` | `.console` | 日志输出目标 |
| `sandbox` | `SandboxSettings?` | `nil` | 沙箱配置 |

### 扩展配置（TS SDK 兼容）

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `settingSources` | `[SettingSource]?` | `nil` | 设置来源 |
| `plugins` | `[SdkPluginConfig]?` | `nil` | 插件配置 |
| `betas` | `[SdkBeta]?` | `nil` | Beta 特性开关 |
| `strictMcpConfig` | `Bool` | `false` | 严格 MCP 配置校验 |
| `extraArgs` | `[String: String?]?` | `nil` | 额外参数透传 |
| `enableFileCheckpointing` | `Bool` | `false` | 文件检查点（撤销） |
| `retryConfig` | `RetryConfig?` | `nil` | API 重试配置 |

---

## 附录 B：34 内置工具速查表

### Core Tools（10）

| 工具 | 只读 | 说明 |
|------|------|------|
| **Bash** | 否 | 执行 Shell 命令，支持超时 |
| **Read** | 是 | 读取文件内容 |
| **Write** | 否 | 创建或覆盖文件 |
| **Edit** | 否 | 文件内查找替换 |
| **Glob** | 是 | 按模式搜索文件 |
| **Grep** | 是 | 正则搜索文件内容 |
| **WebFetch** | 是 | 抓取网页内容 |
| **WebSearch** | 是 | Web 搜索 |
| **AskUser** | 是 | 向用户提问 |
| **ToolSearch** | 是 | 搜索可用工具 |

### Advanced Tools（11）

| 工具 | 只读 | 说明 |
|------|------|------|
| **Agent** | — | 生成子 Agent（Explore/Plan 等） |
| **SendMessage** | — | Agent 间消息传递 |
| **TaskCreate** | 否 | 创建任务 |
| **TaskList** | 是 | 列出任务 |
| **TaskUpdate** | 否 | 更新任务状态/负责人 |
| **TaskGet** | 是 | 获取任务详情 |
| **TaskStop** | 否 | 停止运行中的任务 |
| **TaskOutput** | 是 | 获取已完成任务的输出 |
| **TeamCreate** | 否 | 创建团队 |
| **TeamDelete** | 否 | 删除团队 |
| **NotebookEdit** | 否 | 编辑 Jupyter Notebook 单元格 |

### Specialist Tools（13）

| 工具 | 只读 | 说明 |
|------|------|------|
| **WorktreeEnter** | 否 | 进入隔离 Worktree |
| **WorktreeExit** | 否 | 退出/移除 Worktree |
| **PlanEnter** | 否 | 进入计划模式 |
| **PlanExit** | 否 | 退出计划模式 |
| **CronCreate** | 否 | 创建定时任务 |
| **CronDelete** | 否 | 删除定时任务 |
| **CronList** | 是 | 列出定时任务 |
| **RemoteTrigger** | — | 触发远程 Webhook |
| **LSP** | 是 | Language Server Protocol 集成 |
| **Config** | 否 | 读写 SDK 配置 |
| **TodoWrite** | 否 | 管理待办事项 |
| **ListMcpResources** | 是 | 列出 MCP 资源 |
| **ReadMcpResource** | 是 | 读取 MCP 资源 |

### 工具加载方式

```swift
// 按层级加载
let coreTools = getAllBaseTools(tier: .core)         // 10 个
let advancedTools = getAllBaseTools(tier: .advanced)  // 11 个
let specialistTools = getAllBaseTools(tier: .specialist) // 13 个

// 组合使用
let allTools = coreTools + advancedTools

// 过滤
let filtered = filterTools(tools: allTools, allowed: ["Read", "Glob", "Grep"], disallowed: ["Bash"])

// 完整工具池组装（基础 + 自定义 + MCP）
let (pool, mcpManager) = await agent.assembleFullToolPool()
```

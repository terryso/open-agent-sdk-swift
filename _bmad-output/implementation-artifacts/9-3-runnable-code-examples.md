# Story 9.3: 可运行的代码示例

Status: done

## Story

作为开发者，
我希望为所有主要功能领域提供可运行的代码示例，
以便我可以通过修改真实代码来学习。

## Acceptance Criteria

1. **AC1: BasicAgent 示例可编译运行** — 给定 `Examples/BasicAgent/main.swift`，当开发者运行 `swift run BasicAgent`（或编译），则代码编译无错误，演示 Agent 创建、单次提示和响应处理（FR50）。示例使用 `createAgent()` + `agent.prompt()` 的阻塞式查询模式。

2. **AC2: StreamingAgent 示例可编译运行** — 给定 `Examples/StreamingAgent/main.swift`，当开发者编译并运行，则代码编译无错误，演示 AsyncStream 消费和 SDKMessage 事件模式匹配（FR50）。使用 `for await message in agent.stream(...)` 模式，展示 `.partialMessage`、`.toolUse`、`.toolResult`、`.result` 事件处理。

3. **AC3: CustomTools 示例可编译运行** — 给定 `Examples/CustomTools/main.swift`，当开发者编译并运行，则代码编译无错误，演示 `defineTool()`、Codable 输入和 JSON Schema（FR50）。包含至少一个使用 Codable struct 输入的自定义工具，以及一个使用 `ToolExecuteResult` 返回类型的自定义工具。

4. **AC4: MCPIntegration 示例可编译运行** — 给定 `Examples/MCPIntegration/main.swift`，当开发者编译并运行，则代码编译无错误，演示 MCP 服务器连接（stdio 配置）和 InProcessMCPServer 进程内工具暴露（FR50）。展示 `McpServerConfig.stdio` 和 `McpServerConfig.sdk` 两种配置方式。

5. **AC5: SessionsAndHooks 示例可编译运行** — 给定 `Examples/SessionsAndHooks/main.swift`，当开发者编译并运行，则代码编译无错误，演示 SessionStore 会话保存/加载和 HookRegistry 钩子注册/执行（FR50）。展示 `SessionStore.save()`/`SessionStore.load()` 和 `HookRegistry.register()` 的使用模式。

6. **AC6: 所有示例使用实际公共 API** — 给定所有 5 个示例文件，当开发者查看代码，则所有 API 调用与当前源码中的公共 API 签名完全匹配。无假设性 API、无过时签名、无编译错误。

7. **AC7: 每个示例有清晰注释和说明** — 给定每个示例的 `main.swift`，当开发者阅读代码，则文件顶部有功能说明注释，关键步骤有行内注释，代码结构清晰易懂。

8. **AC8: 示例不暴露真实 API 密钥** — 给定所有示例代码，当检查密钥使用，则 API 密钥使用 `"sk-..."` 占位符或从环境变量读取（NFR6），不包含任何真实密钥字符串。

## Tasks / Subtasks

- [x] Task 1: 创建 Examples/ 目录结构 (AC: #1-#5)
  - [x] 创建 `Examples/BasicAgent/Package.swift`（或使用顶层 Package.swift 的 executableTarget）
  - [x] 创建 `Examples/StreamingAgent/` 目录
  - [x] 创建 `Examples/CustomTools/` 目录
  - [x] 创建 `Examples/MCPIntegration/` 目录
  - [x] 创建 `Examples/SessionsAndHooks/` 目录
  - [x] 验证 Package.swift 中添加所有 executable target

- [x] Task 2: 实现 BasicAgent 示例 (AC: #1, #6, #7, #8)
  - [x] 编写 Agent 创建代码：`createAgent(options: AgentOptions(...))`
  - [x] 编写阻塞式查询：`let result = await agent.prompt("...")`
  - [x] 展示 `QueryResult` 的 `text`、`usage`、`status` 属性
  - [x] 展示多提供商支持（Anthropic + OpenAI 兼容 API）
  - [x] 添加功能说明和行内注释

- [x] Task 3: 实现 StreamingAgent 示例 (AC: #2, #6, #7, #8)
  - [x] 编写流式查询：`for await message in agent.stream("...")`
  - [x] 展示 SDKMessage 模式匹配：`.partialMessage`、`.assistant`、`.toolUse`、`.toolResult`、`.result`
  - [x] 展示预算追踪：`AgentOptions(maxBudgetUsd: 0.50)` + `.errorMaxBudgetUsd` 处理
  - [x] 添加功能说明和行内注释

- [x] Task 4: 实现 CustomTools 示例 (AC: #3, #6, #7, #8)
  - [x] 编写 Codable 输入 struct：`struct WeatherInput: Codable`
  - [x] 编写 defineTool 调用：`defineTool(name:description:inputSchema:isReadOnly:execute:)`
  - [x] 展示 JSON Schema 定义
  - [x] 展示工具注册：`tools: [myTool]` in AgentOptions
  - [x] 展示自定义权限回调：`canUseTool` 或 `setCanUseTool()`
  - [x] 添加功能说明和行内注释

- [x] Task 5: 实现 MCPIntegration 示例 (AC: #4, #6, #7, #8)
  - [x] 编写 MCP stdio 配置：`McpServerConfig.stdio(McpStdioConfig(...))`
  - [x] 编写 InProcessMCPServer 创建：`InProcessMCPServer(name:tools:cwd:)`
  - [x] 编写 `McpServerConfig.sdk(McpSdkServerConfig(...))` 配置
  - [x] 展示 `mcpServers` 参数在 AgentOptions 中的使用
  - [x] 添加功能说明和行内注释

- [x] Task 6: 实现 SessionsAndHooks 示例 (AC: #5, #6, #7, #8)
  - [x] 编写 SessionStore 使用：创建、save、load、list
  - [x] 编写 HookRegistry 使用：`register(.postToolUse, definition:)`
  - [x] 展示 HookDefinition 的 handler 和 matcher
  - [x] 展示 AgentOptions 中的 sessionStore/hookRegistry 注入
  - [x] 展示会话恢复：`sessionId` 参数 + 自动加载/保存
  - [x] 添加功能说明和行内注释

- [x] Task 7: 验证所有示例可编译 (AC: #6)
  - [x] 运行 `swift build` 确认所有示例目标编译通过
  - [x] 对比每个示例的 API 调用与实际公共 API 签名
  - [x] 修复任何编译错误

- [x] Task 8: 运行完整测试套件确认无回归 (AC: #6)
  - [x] 运行 `swift test` 确认所有现有测试通过

## Dev Notes

### 本 Story 的定位

- Epic 9（文档与开发者体验）的第三个 Story，也是 Epic 9 的最后一个 Story
- **核心目标：** 为 SDK 的所有主要功能领域创建可编译、可运行的代码示例（FR50）
- **前置依赖：** Epic 1-8 全部完成，Story 9-1（Swift-DocC 文档）和 Story 9-2（README）已完成
- **与 Story 9-2 的关系：** README 中的代码片段是简化版本，Examples/ 中的代码是完整的可运行版本

### 实施方案决策

**关键决策：示例如何组织？**

由于 Package.swift 已经有 `OpenAgentSDK` 库目标和 `E2ETest` 可执行目标，示例可以有两种组织方式：

**方案 A（推荐）：在 Package.swift 中添加 executableTarget**
- 在顶层 Package.swift 中为每个示例添加 `.executableTarget`
- 每个 `Examples/{Name}/main.swift` 作为可执行入口
- 优点：开发者可以直接 `swift run BasicAgent` 运行
- 优点：与现有 E2ETest 目标模式一致
- 缺点：Package.swift 会变长

**方案 B（备选）：独立 Package.swift**
- 每个 `Examples/{Name}/` 有自己的 Package.swift
- 优点：完全独立，互不影响
- 缺点：重复配置，开发者需要 cd 进每个目录

**推荐方案 A**：在顶层 Package.swift 中添加 executableTarget，与 E2ETest 模式一致。

### 关键公共 API 签名（必须与源码一致）

以下是从实际源码中提取的公共 API 签名，示例代码必须严格使用这些签名：

**创建 Agent：**
```swift
import OpenAgentSDK

// 方式 1：显式选项
let agent = createAgent(options: AgentOptions(
    apiKey: "sk-...",
    model: "claude-sonnet-4-6",
    systemPrompt: "You are a helpful assistant.",
    maxTurns: 10,
    permissionMode: .bypassPermissions
))

// 方式 2：环境变量
let agent = createAgent()
```

**阻塞式查询：**
```swift
let result = await agent.prompt("Your prompt here")
// result.text: String
// result.usage: TokenUsage (inputTokens, outputTokens)
// result.numTurns: Int
// result.durationMs: Int
// result.status: QueryStatus (.success, .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd)
// result.totalCostUsd: Double
```

**流式查询：**
```swift
for await message in agent.stream("Your prompt") {
    switch message {
    case .partialMessage(let data):
        print(data.text, terminator: "")
    case .assistant(let data):
        print("\n[Model: \(data.model), Stop: \(data.stopReason)]")
    case .toolUse(let data):
        print("[Tool: \(data.toolName)]")
    case .toolResult(let data):
        print("[Result: \(data.content)]")
    case .result(let data):
        print("Done: \(data.subtype), turns: \(data.numTurns), cost: $\(data.totalCostUsd)")
    case .system(let data):
        print("[System: \(data.message)]")
    }
}
```

**自定义工具（String 返回）：**
```swift
struct WeatherInput: Codable {
    let city: String
}

let weatherTool = defineTool(
    name: "get_weather",
    description: "Get weather for a city",
    inputSchema: [
        "type": "object",
        "properties": ["city": ["type": "string", "description": "City name"]],
        "required": ["city"]
    ],
    isReadOnly: true
) { input: WeatherInput, context in
    return "Weather in \(input.city): Sunny, 22C"
}
```

**自定义工具（ToolExecuteResult 返回）：**
```swift
let validateTool = defineTool(
    name: "validate",
    description: "Validates input",
    inputSchema: ["type": "object", "properties": [:]]
) { input: MyInput, context in
    return ToolExecuteResult(content: "Valid!", isError: false)
}
```

**MCP 配置：**
```swift
// Stdio 配置
let mcpConfig: [String: McpServerConfig] = [
    "my-server": .stdio(McpStdioConfig(
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    ))
]

// InProcessMCPServer 配置
let inProcessServer = InProcessMCPServer(
    name: "my-tools",
    version: "1.0.0",
    tools: [myCustomTool],
    cwd: "/tmp"
)
let sdkConfig: [String: McpServerConfig] = [
    "my-tools": .sdk(McpSdkServerConfig(
        name: "my-tools",
        version: "1.0.0",
        server: inProcessServer
    ))
]
```

**会话存储：**
```swift
let sessionStore = SessionStore() // 默认 ~/.open-agent-sdk/sessions/
// SessionStore 是 actor，所有方法需要 await

// 通过 AgentOptions 自动保存/加载
let agent = createAgent(options: AgentOptions(
    sessionStore: sessionStore,
    sessionId: "my-session"
))

// 手动操作（示例中展示）
try await sessionStore.save(sessionId: "my-session", messages: messages, metadata: PartialSessionMetadata(...))
let sessionData = try await sessionStore.load(sessionId: "my-session")
```

**钩子系统：**
```swift
let hookRegistry = HookRegistry()

await hookRegistry.register(.postToolUse, definition: HookDefinition(
    handler: { input in
        print("Tool used: \(input.toolName ?? "unknown")")
        return nil  // nil 表示不修改行为
    }
))

await hookRegistry.register(.preToolUse, definition: HookDefinition(
    matcher: "Bash",  // 只匹配 Bash 工具
    handler: { input in
        return HookOutput(block: true, message: "Bash blocked")
    }
))
```

**权限控制：**
```swift
// 模式切换
agent.setPermissionMode(.bypassPermissions)
agent.setPermissionMode(.acceptEdits)

// 自定义回调
agent.setCanUseTool { tool, input, context in
    if tool.name == "Bash" {
        return .deny("Bash is not allowed")
    }
    return .allow()
}

// Policy 模式
let policy = CompositePolicy(policies: [
    ReadOnlyPolicy(),
    ToolNameDenylistPolicy(deniedToolNames: ["Bash"])
])
agent.setCanUseTool(canUseTool(policy: policy))
```

**多提供商：**
```swift
// Anthropic（默认）
let agent = createAgent(options: AgentOptions(
    provider: .anthropic,
    apiKey: "sk-...",
    model: "claude-sonnet-4-6"
))

// OpenAI 兼容 API（GLM、Ollama、OpenRouter 等）
let agent = createAgent(options: AgentOptions(
    provider: .openai,
    apiKey: "your-key",
    model: "glm-4-flash",
    baseURL: "https://open.bigmodel.cn/api/paas/v4"
))
```

### 前序 Story 的经验教训（必须遵循）

来自 Story 9-1、9-2 和所有前序 Story 的 Dev Notes：

1. **API 密钥不暴露** — 使用 `"sk-..."` 占位符或 `ProcessInfo.processInfo.environment` 读取（NFR6）
2. **代码示例必须与实际 API 一致** — 严格对照源码验证每个 API 调用
3. **`_Concurrency.Task.sleep` 而非 `Task.sleep`** — 项目有自定义 Task 类型冲突（虽然示例中不太可能用到）
4. **不使用 Apple 专属框架** — Foundation 在 macOS 和 Linux 均可用
5. **Agent.options 是 `var`** — 支持 `setPermissionMode()`/`setCanUseTool()` 动态修改
6. **`ToolContext` 有 `toolUseId` 属性** — 由 ToolExecutor 自动填充，自定义工具无需手动创建
7. **`SessionStore` 是 actor** — 所有方法调用需要 `await` 或 `try await`
8. **`HookRegistry` 是 actor** — 所有方法调用需要 `await`
9. **`InProcessMCPServer` 是 actor** — 初始化和使用需要 `await`
10. **`McpSdkServerConfig` 的 `name` 不能包含 `__`** — 会触发 precondition 失败
11. **`import MCP`** — InProcessMCPServer 需要 `import MCP`（来自 mcp-swift-sdk）

### 反模式警告

- **不要**在示例中使用假设性 API — 必须与实际源码公共 API 完全一致
- **不要**暴露真实 API 密钥 — 使用 `"sk-..."` 占位符
- **不要**在示例中实现复杂的业务逻辑 — 保持简洁、聚焦单个功能领域
- **不要**在示例中使用内部 API — 只使用 `public` API
- **不要**修改任何现有源代码 — 本 story 只添加示例文件和更新 Package.swift
- **不要**创建额外的 Package.swift — 在顶层 Package.swift 中添加 executableTarget
- **不要**在示例中添加 `import Foundation` — 除非确实需要 Foundation 类型
- **不要**在示例中使用 `try!` 或 `!` 强制解包 — 使用 `guard let`、`if let` 或 `do/catch`
- **不要**使用 `Task { }` 创建非结构化并发 — 示例应使用简单的 `async/await`

### 模块边界

**本 story 涉及文件：**
- `Package.swift` — 修改：添加 5 个 executableTarget
- `Examples/BasicAgent/main.swift` — 新建
- `Examples/StreamingAgent/main.swift` — 新建
- `Examples/CustomTools/main.swift` — 新建
- `Examples/MCPIntegration/main.swift` — 新建
- `Examples/SessionsAndHooks/main.swift` — 新建

**不涉及任何现有源代码文件变更。**

```
项目根目录/
├── Package.swift                    # 修改：添加 5 个 executableTarget
├── Examples/
│   ├── BasicAgent/
│   │   └── main.swift              # 新建：Agent 创建 + 阻塞式查询
│   ├── StreamingAgent/
│   │   └── main.swift              # 新建：流式查询 + SDKMessage 模式匹配
│   ├── CustomTools/
│   │   └── main.swift              # 新建：defineTool + Codable 输入 + JSON Schema
│   ├── MCPIntegration/
│   │   └── main.swift              # 新建：MCP 服务器连接 + InProcessMCPServer
│   └── SessionsAndHooks/
│       └── main.swift              # 新建：SessionStore + HookRegistry
└── _bmad-output/
    └── implementation-artifacts/
        └── 9-3-runnable-code-examples.md  # 本文件
```

### 测试策略

本 story 不需要单元测试。验证方式：
1. `swift build` 确认所有示例目标编译通过
2. 确认每个示例的 API 调用与当前公共 API 签名匹配
3. 现有测试套件全部通过（无回归）
4. 如果环境允许（有 API key），可手动运行示例验证功能

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 9.3 可运行的代码示例]
- [Source: _bmad-output/planning-artifacts/prd.md#FR50 SDK 为所有主要功能领域提供可运行的代码示例]
- [Source: _bmad-output/planning-artifacts/prd.md#代码示例覆盖] — PRD 中的 8 个示例领域定义
- [Source: _bmad-output/planning-artifacts/architecture.md#Examples 目录结构] — 架构文档定义的 5 个示例
- [Source: _bmad-output/planning-artifacts/architecture.md#文档策略] — 文档策略要求工作示例
- [Source: _bmad-output/project-context.md#Technology Stack & Versions]
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — Agent、createAgent、prompt、stream 实际 API
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions、QueryResult、QueryStatus 实际签名
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift] — SDKMessage 枚举和所有关联类型
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol、ToolResult、ToolContext
- [Source: Sources/OpenAgentSDK/Types/PermissionTypes.swift] — PermissionMode、CanUseToolResult、PermissionPolicy
- [Source: Sources/OpenAgentSDK/Types/MCPConfig.swift] — McpServerConfig、McpStdioConfig、McpSdkServerConfig
- [Source: Sources/OpenAgentSDK/Types/HookTypes.swift] — HookEvent、HookInput、HookOutput、HookDefinition
- [Source: Sources/OpenAgentSDK/Types/SessionTypes.swift] — SessionMetadata、SessionData、PartialSessionMetadata
- [Source: Sources/OpenAgentSDK/Stores/SessionStore.swift] — SessionStore actor 公共 API
- [Source: Sources/OpenAgentSDK/Hooks/HookRegistry.swift] — HookRegistry actor 公共 API
- [Source: Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift] — InProcessMCPServer actor 公共 API
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool 工厂函数签名
- [Source: _bmad-output/implementation-artifacts/9-2-readme-quickstart-guide.md] — 前序 Story 的经验

### Project Structure Notes

- **修改** `Package.swift` — 添加 5 个 executableTarget
- **新建** 5 个示例目录和 main.swift 文件
- 不涉及任何现有源代码文件变更
- 完全对齐架构文档的 `Examples/` 目录结构

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Initial build had 4 issues: missing Foundation import for ProcessInfo, parameter ordering in initializers, actor isolation for InProcessMCPServer.asConfig(), and enum context inference
- All issues resolved: added `import Foundation`, fixed parameter ordering to match init signatures, used `await` for actor methods, used fully qualified `SDKMessage.ResultData.Subtype.errorMaxBudgetUsd`
- ATDD test `testMCPIntegrationUsesInProcessMCPServer` initially failed because example used `asConfig()` instead of explicit `.sdk()` — added manual config with `.sdk(McpSdkServerConfig(...))` to satisfy the check

### Completion Notes List

- Created 5 runnable code examples covering all major SDK features: BasicAgent, StreamingAgent, CustomTools, MCPIntegration, SessionsAndHooks
- All examples use actual public API signatures verified against source code
- All examples compile successfully with `swift build`
- All 1659 tests pass with 0 failures (4 skipped)
- API keys use `"sk-..."` placeholder or environment variable reads
- Each example has clear top-level documentation and inline comments
- Examples follow recommended approach A: executable targets in top-level Package.swift
- MCPIntegration example requires `import MCP` dependency (mcp-swift-sdk)

### File List

- `Package.swift` — Modified: added 5 executableTarget entries (BasicAgent, StreamingAgent, CustomTools, MCPIntegration, SessionsAndHooks)
- `Examples/BasicAgent/main.swift` — New: Agent creation + blocking query + multi-provider support
- `Examples/StreamingAgent/main.swift` — New: AsyncStream streaming + SDKMessage pattern matching + budget tracking
- `Examples/CustomTools/main.swift` — New: defineTool with Codable input + ToolExecuteResult + Policy pattern
- `Examples/MCPIntegration/main.swift` — New: InProcessMCPServer + McpStdioConfig + McpSdkServerConfig
- `Examples/SessionsAndHooks/main.swift` — New: SessionStore + HookRegistry + session restore

### Change Log

- 2026-04-09: Story 9-3 implementation complete — 5 runnable code examples created, all compile, all tests pass (1659/1659)

# Story 10.6: 高级 MCP 工具示例（AdvancedMCPExample）

Status: review

## Story

作为 Swift 开发者，
我希望看到一个使用 `InProcessMCPServer` 创建进程内 MCP 服务器并注册自定义工具的示例，
以便我理解如何通过 MCP 协议构建和暴露自定义工具集。

## Acceptance Criteria

1. **AC1: AdvancedMCPExample 可编译运行** — 给定 `Examples/AdvancedMCPExample/main.swift`，当开发者运行 `swift build`（编译）或 `swift run AdvancedMCPExample`，则代码编译无错误、无警告。示例展示 InProcessMCPServer 创建、自定义工具注册、MCP 命名空间工具调用和错误处理。

2. **AC2: 展示 defineTool() 创建带 Codable 输入的自定义工具** — 给定 AdvancedMCPExample 运行中，则使用 `defineTool()` 创建至少两个自定义工具（如天气查询、单位转换），每个工具都有 Codable 输入结构和 JSON Schema 定义。

3. **AC3: 展示 InProcessMCPServer 封装工具** — 给定 AdvancedMCPExample 运行中，则使用 `InProcessMCPServer(name:version:tools:cwd:)` 将自定义工具打包为进程内 MCP 服务器，服务器名称不含双下划线。

4. **AC4: Agent 通过 mcpServers 配置连接并使用 MCP 工具** — 给定 AdvancedMCPExample 运行中，则 Agent 通过 `AgentOptions` 的 `mcpServers` 参数连接进程内 MCP 服务器。MCP 工具以 `mcp__{serverName}__{toolName}` 命名空间被 LLM 调用。

5. **AC5: 展示工具返回错误时的处理方式** — 给定 AdvancedMCPExample 运行中，则示例包含一个可能返回错误的工具（如无效输入触发错误），展示 `ToolExecuteResult` 的 `isError` 字段和错误内容如何被处理。

6. **AC6: Package.executableTarget 已配置** — 给定更新后的 Package.swift，当包含 `AdvancedMCPExample` executableTarget 且依赖包含 `MCP` 产品（与 MCPIntegration 示例一致），则 `swift build` 编译通过。

7. **AC7: 使用实际公共 API** — 给定所有示例代码，则所有 API 调用与当前源码中的公共 API 签名完全匹配（`defineTool`、`InProcessMCPServer`、`McpSdkServerConfig`、`McpServerConfig`、`AgentOptions`、`createAgent`、`agent.prompt()`、`QueryResult`、`ToolExecuteResult`、`ToolContext`）。无假设性 API、无过时签名。

8. **AC8: 清晰注释和不暴露密钥** — 给定 main.swift 文件，则文件顶部有功能说明注释，关键步骤有行内注释。API 密钥使用 `"sk-..."` 占位符或从环境变量读取（NFR6）。

## Tasks / Subtasks

- [x] Task 1: 更新 Package.swift 添加 AdvancedMCPExample target (AC: #6)
  - [x] 在 targets 数组中添加 `.executableTarget(name: "AdvancedMCPExample", dependencies: ["OpenAgentSDK", .product(name: "MCP", package: "mcp-swift-sdk")], path: "Examples/AdvancedMCPExample")`
  - [x] 注意：与 MCPIntegration 示例一样，需要依赖 MCP 产品，因为 InProcessMCPServer 使用了 `import MCP`

- [x] Task 2: 创建 Examples/AdvancedMCPExample/main.swift (AC: #1, #2, #3, #4, #5, #7, #8)
  - [x] 创建目录 `Examples/AdvancedMCPExample/`
  - [x] 文件顶部注释：功能说明、运行方式、前提条件
  - [x] 导入 Foundation、OpenAgentSDK 和 MCP
  - [x] 从环境变量读取 API key（`ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "sk-..."`）
  - [x] **Part 1: 创建自定义工具** — 使用 `defineTool()` 创建两个带 Codable 输入的工具：
    - 天气查询工具（`WeatherInput: Codable`，含 city 字段）
    - 单位转换工具（`ConversionInput: Codable`，含 value/fromUnit/toUnit 字段）
    - 错误演示工具（`ErrorInput: Codable`，故意对无效输入返回 `ToolExecuteResult` 错误）
  - [x] **Part 2: 创建 InProcessMCPServer** — 将工具打包为进程内 MCP 服务器：
    - 使用 `InProcessMCPServer(name:version:tools:cwd:)` 初始化
    - 使用 `await inProcessServer.asConfig()` 生成 SDK 配置
    - 打印服务器信息（工具数量、命名空间前缀）
  - [x] **Part 3: 创建 Agent 并使用 MCP 工具** — 通过 mcpServers 配置连接：
    - 创建 `AgentOptions`，`mcpServers` 参数传入 SDK 配置
    - 设置 `permissionMode: .bypassPermissions` 避免权限提示
    - 使用 `agent.prompt()` 发送需要使用 MCP 工具的查询
    - 输出响应和统计信息
  - [x] **Part 4: 错误处理演示** — 展示工具错误处理：
    - 发送会触发错误工具的查询
    - 展示 Agent 如何处理工具返回的错误
  - [x] 不使用 `try!` 或 `!` 强制解包

- [x] Task 3: 验证编译通过 (AC: #1, #6, #7)
  - [x] 运行 `swift build` 确认 AdvancedMCPExample 编译通过
  - [x] 验证所有 API 调用与实际公共 API 签名一致

- [x] Task 4: 运行完整测试套件确认无回归 (AC: #7)
  - [x] 运行 `swift test` 确认所有现有测试通过

## Dev Notes

### 本 Story 的定位

- Epic 10（扩展代码示例集）的第六个也是最后一个 Story
- **核心目标：** 创建 AdvancedMCPExample 示例，展示如何通过 `InProcessMCPServer` 和 `defineTool()` 构建自定义 MCP 工具集，并通过 Agent 的 `mcpServers` 配置集成（FR19-FR22、FR50 补充）
- **前置依赖：** Epic 1-9 全部完成，尤其 Story 6-3（进程内 MCP 服务器）、Story 6-4（MCP 工具集成）和 Story 10-1/10-2/10-3/10-4/10-5（已建立扩展示例模式）
- **与已有示例的区别：**
  - MCPIntegration（Epic 9 基础示例）：展示 InProcessMCPServer 创建和 stdio 配置的基础用法
  - **AdvancedMCPExample（本 Story）：** 深入展示 defineTool() + InProcessMCPServer 完整工作流，包括多工具注册、错误处理、命名空间验证 — 是 MCPIntegration 的高级补充

### 关键公共 API 签名（必须与源码一致）

以下是从实际源码中验证的 API 签名：

**defineTool — 返回 String（ToolBuilder.swift）：**
```swift
public func defineTool<Input: Codable>(
    name: String,
    description: String,
    inputSchema: ToolInputSchema,
    isReadOnly: Bool = false,
    execute: @Sendable @escaping (Input, ToolContext) async throws -> String
) -> ToolProtocol
```

**defineTool — 返回 ToolExecuteResult（ToolBuilder.swift）：**
```swift
public func defineTool<Input: Codable>(
    name: String,
    description: String,
    inputSchema: ToolInputSchema,
    isReadOnly: Bool = false,
    execute: @Sendable @escaping (Input, ToolContext) async throws -> ToolExecuteResult
) -> ToolProtocol
```

**ToolExecuteResult 结构（ToolTypes.swift）：**
```swift
public struct ToolExecuteResult: Sendable {
    public let content: String
    public let isError: Bool
}
```

**InProcessMCPServer（Tools/MCP/InProcessMCPServer.swift）：**
```swift
public actor InProcessMCPServer {
    public let name: String
    public let version: String
    public init(name: String, version: String = "1.0.0", tools: [ToolProtocol], cwd: String = "/")
    public func getTools() -> [ToolProtocol]
    public func asConfig() -> McpServerConfig
}
```

**McpServerConfig 枚举（Types/MCPConfig.swift）：**
```swift
public enum McpServerConfig: Sendable, Equatable {
    case stdio(McpStdioConfig)
    case sse(McpSseConfig)
    case http(McpHttpConfig)
    case sdk(McpSdkServerConfig)
}
```

**McpSdkServerConfig（Types/MCPConfig.swift）：**
```swift
public struct McpSdkServerConfig: Sendable, Equatable {
    public let name: String
    public let version: String
    public let server: InProcessMCPServer
    public init(name: String, version: String, server: InProcessMCPServer)
}
```
**注意：** `name` 不能包含 `"__"`（双下划线），否则 precondition 会触发 crash。

**InProcessMCPServer.asConfig() 返回值：**
```swift
// asConfig() 返回 McpServerConfig.sdk(McpSdkServerConfig(...))
// 用法：
let server = InProcessMCPServer(name: "my-tools", tools: [...], cwd: "/tmp")
let config: [String: McpServerConfig] = ["my-tools": await server.asConfig()]
```

**AgentOptions 中的 mcpServers 参数：**
```swift
public struct AgentOptions: Sendable {
    // ...
    public var mcpServers: [String: McpServerConfig]?
    // ...
}
```

**MCP 工具命名空间：** `mcp__{serverName}__{toolName}`
- 示例：服务器名 `"utility"` + 工具名 `"get_weather"` → `mcp__utility__get_weather`

**ToolContext（ToolTypes.swift）：**
```swift
public struct ToolContext: Sendable {
    public let cwd: String
    public let toolUseId: String
}
```

**ToolInputSchema 类型别名：**
```swift
public typealias ToolInputSchema = [String: Any]
```

**AgentOptions 参数顺序（来自 AgentTypes.swift init 签名）：**
`apiKey, model, baseURL, provider, systemPrompt, maxTurns, maxTokens, maxBudgetUsd, thinking, permissionMode, canUseTool, cwd, tools, mcpServers, retryConfig, agentName, mailboxStore, teamStore, taskStore, worktreeStore, planStore, cronStore, todoStore, sessionStore, sessionId, hookRegistry`

**阻塞式 API 查询（Agent.swift）：**
```swift
let result = await agent.prompt("...")
// result: QueryResult — .text, .usage, .numTurns, .durationMs, .status, .totalCostUsd
```

**QueryResult 字段：**
```swift
public struct QueryResult: Sendable {
    public let text: String
    public let usage: TokenUsage
    public let numTurns: Int
    public let durationMs: Int
    public let messages: [SDKMessage]
    public let status: QueryStatus  // .success, .errorMaxTurns, .errorDuringExecution, .errorMaxBudgetUsd
    public let totalCostUsd: Double
}
```

### 示例设计建议

示例应展示完整的 MCP 工具创建 → 封装 → 集成 → 使用工作流：

1. **Part 1 — 创建自定义工具**：使用 `defineTool()` 创建 2-3 个带 Codable 输入的工具：
   - `get_weather`：接受城市名，返回模拟天气数据（只读工具，使用 `isReadOnly: true`）
   - `convert_unit`：接受 value/fromUnit/toUnit，返回转换结果（只读工具）
   - `validate_input`：接受一个值，在特定条件下返回 `ToolExecuteResult` 错误（用于演示错误处理）

2. **Part 2 — 创建 InProcessMCPServer**：将所有工具打包为进程内 MCP 服务器。使用 `asConfig()` 生成配置。打印工具列表和命名空间前缀信息。

3. **Part 3 — Agent 集成**：创建 Agent，通过 `mcpServers` 注入 SDK 配置。发送需要使用 MCP 工具的查询。打印完整响应和统计。

4. **Part 4 — 错误处理**：发送会触发 `validate_input` 错误的查询。展示 Agent 如何接收并处理工具错误（`isError: true` 的 ToolResult）。

**代码结构建议：**
```
// MARK: - Part 1: 创建自定义 MCP 工具
// ... defineTool() 创建 get_weather、convert_unit、validate_input ...

// MARK: - Part 2: 创建 InProcessMCPServer
// ... InProcessMCPServer 初始化、asConfig() ...

// MARK: - Part 3: 创建 Agent 并使用 MCP 工具
// ... AgentOptions + mcpServers + agent.prompt() ...

// MARK: - Part 4: 工具错误处理演示
// ... 触发错误工具、展示错误处理 ...
```

### Package.swift 注意事项

AdvancedMCPExample 需要依赖 MCP 产品，因为 InProcessMCPServer 是 actor，且 `asConfig()` 返回的 `McpServerConfig` 涉及 MCP 类型。参考 MCPIntegration 的配置：
```swift
.executableTarget(
    name: "AdvancedMCPExample",
    dependencies: ["OpenAgentSDK",
        .product(name: "MCP", package: "mcp-swift-sdk"),
    ],
    path: "Examples/AdvancedMCPExample"
),
```

### 前序 Story 的经验教训（必须遵循）

来自 Story 10-1 至 10-5 和 Story 9-3 的 Dev Notes：

1. **API 密钥不暴露** — 使用 `"sk-..."` 占位符或 `ProcessInfo.processInfo.environment` 读取（NFR6）
2. **代码示例必须与实际 API 一致** — 严格对照源码验证每个 API 调用
3. **不使用 Apple 专属框架** — Foundation 在 macOS 和 Linux 均可用
4. **`import Foundation`** — 需要 ProcessInfo 时必须导入 Foundation
5. **`import MCP`** — 本示例需要导入 MCP（与 MCPIntegration 一致）
6. **`InProcessMCPServer` 是 actor** — 调用其方法需要 `await`
7. **`InProcessMCPServer` 名称不能含 `__`** — precondition 会触发 crash
8. **`asConfig()` 是 async 方法** — 必须用 `await` 调用
9. **AgentOptions 参数顺序必须精确匹配** — 参照 AgentTypes.swift 中的 init 签名
10. **`permissionMode: .bypassPermissions`** — 不受限模式下避免权限提示干扰
11. **`ToolExecuteResult` 需显式构造** — `ToolExecuteResult(content: "...", isError: true/false)`
12. **现有 MCPIntegration 示例已展示基础用法** — 本示例应展示高级模式（多工具、错误处理），避免重复基础内容

### 反模式警告

- **不要**使用假设性 API — 必须与实际源码公共 API 完全一致
- **不要**暴露真实 API 密钥 — 使用 `"sk-..."` 占位符
- **不要**使用 `try!` 或 `!` 强制解包 — 使用 `guard let`、`if let`
- **不要**修改任何现有源代码 — 本 story 只添加示例文件和更新 Package.swift
- **不要**创建独立的 Package.swift — 在顶层 Package.swift 中添加 executableTarget
- **不要**在 InProcessMCPServer 名称中使用 `__` — 会触发 precondition failure
- **不要**忘记 `await` 调用 InProcessMCPServer 的方法 — 它是 actor
- **不要**在示例中实现复杂业务逻辑 — 保持简洁、聚焦 MCP 工具工作流
- **不要**使用 `Task { }` 创建非结构化并发 — 使用简单的 `await agent.prompt()`
- **不要**忘记 MCP 产品依赖 — Package.swift 中 AdvancedMCPExample 需要依赖 MCP

### 模块边界

**本 story 涉及文件：**
- `Package.swift` — 修改：添加 1 个 executableTarget（AdvancedMCPExample）
- `Examples/AdvancedMCPExample/main.swift` — 新建：高级 MCP 工具集成示例

**不涉及任何现有源代码文件变更。**

```
项目根目录/
├── Package.swift                                    # 修改：添加 AdvancedMCPExample executableTarget
├── Examples/
│   ├── BasicAgent/main.swift                        # 不修改
│   ├── StreamingAgent/main.swift                    # 不修改
│   ├── CustomTools/main.swift                       # 不修改
│   ├── MCPIntegration/main.swift                    # 不修改（基础 MCP 示例，本示例是其高级补充）
│   ├── SessionsAndHooks/main.swift                  # 不修改
│   ├── MultiToolExample/main.swift                  # 不修改
│   ├── CustomSystemPromptExample/main.swift         # 不修改
│   ├── PromptAPIExample/main.swift                  # 不修改
│   ├── SubagentExample/main.swift                   # 不修改
│   ├── PermissionsExample/main.swift                # 不修改
│   └── AdvancedMCPExample/                          # 新建目录
│       └── main.swift                               # 新建：高级 MCP 工具示例
└── _bmad-output/
    └── implementation-artifacts/
        └── 10-6-advanced-mcp-example.md             # 本文件
```

### 测试策略

本 story 不需要单元测试。验证方式：
1. `swift build` 确认 AdvancedMCPExample 目标编译通过
2. 确认所有 API 调用与当前公共 API 签名匹配
3. 现有测试套件全部通过（无回归）
4. 如果环境允许（有 API key），可手动运行示例验证功能

### Project Structure Notes

- 在顶层 Package.swift 中添加 AdvancedMCPExample executableTarget（与现有 10 个示例一致）
- 新建 `Examples/AdvancedMCPExample/main.swift`
- 不涉及任何现有源代码文件变更
- 完全对齐架构文档的 `Examples/` 目录结构扩展
- 这是 Epic 10 的最后一个 Story，完成后 Epic 10 可标记为 done

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.6 高级 MCP 工具示例] — 验收标准和需求定义
- [Source: _bmad-output/planning-artifacts/prd.md#FR19] — MCP stdio 传输
- [Source: _bmad-output/planning-artifacts/prd.md#FR21] — 进程内 MCP 服务器
- [Source: _bmad-output/planning-artifacts/prd.md#FR22] — MCP 工具与内置工具集成
- [Source: _bmad-output/planning-artifacts/prd.md#FR50] — SDK 为所有主要功能领域提供可运行的代码示例
- [Source: _bmad-output/planning-artifacts/architecture.md#AD5] — MCP 集成架构决策
- [Source: _bmad-output/planning-artifacts/architecture.md#Examples 目录结构] — 架构文档定义的示例结构
- [Source: _bmad-output/project-context.md#Technology Stack & Versions]
- [Source: _bmad-output/implementation-artifacts/10-5-permissions-example.md] — 前序 Story 的经验教训和 API 签名
- [Source: _bmad-output/implementation-artifacts/10-1-multi-tool-example.md] — 示例模式参考
- [Source: Sources/OpenAgentSDK/Types/MCPConfig.swift] — McpServerConfig、McpSdkServerConfig 实际签名
- [Source: Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift] — InProcessMCPServer actor 实际 API
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool() 多种重载实际签名
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolExecuteResult、ToolContext、ToolInputSchema 实际签名
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions、QueryResult、QueryStatus 实际签名
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — Agent、createAgent、prompt 实际 API
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift] — MCP 命名空间规则
- [Source: Examples/MCPIntegration/main.swift] — 基础 MCP 示例参考（避免重复，展示高级模式）
- [Source: Examples/PromptAPIExample/main.swift] — 阻塞式 API 使用模式参考

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Implemented AdvancedMCPExample with 3 custom MCP tools (get_weather, convert_unit, validate_email)
- get_weather: String-returning tool with WeatherInput Codable struct
- convert_unit: String-returning tool with ConversionInput Codable struct, supports 6 unit conversions
- validate_email: ToolExecuteResult-returning tool with ValidateInput Codable struct, demonstrates error handling with isError: true
- InProcessMCPServer wraps all 3 tools with name "utility" (no double underscores)
- asConfig() generates McpServerConfig.sdk configuration for Agent integration
- Agent created with mcpServers parameter, sends 4 queries demonstrating weather, conversion, error, and success paths
- All API signatures verified against actual source code (defineTool, InProcessMCPServer, AgentOptions, ToolExecuteResult)
- Fixed ATDD test testAdvancedMCPExampleTargetSpecifiesCorrectPath - naive ")" parsing failed with .product() dependency containing ")"
- swift build compiles with zero errors and zero warnings
- Full test suite: 2022 tests passing, 4 skipped, 0 failures

### File List

- Package.swift — Modified: added AdvancedMCPExample executableTarget with MCP product dependency
- Examples/AdvancedMCPExample/main.swift — Created: advanced MCP tool integration example
- Tests/OpenAgentSDKTests/Documentation/AdvancedMCPExampleComplianceTests.swift — Modified: fixed testAdvancedMCPExampleTargetSpecifiesCorrectPath parsing logic

## Change Log

- 2026-04-10: Story 10-6 created — AdvancedMCPExample demonstrating InProcessMCPServer, defineTool() custom tools, MCP namespace integration, and tool error handling
- 2026-04-10: Story 10-6 implemented — all 4 tasks completed, 2022 tests passing

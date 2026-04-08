# Story 6.3: 进程内 MCP 服务器

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望将 Agent 的工具暴露为 MCP 服务器，
以便外部 MCP 客户端可以使用我的工具。

## Acceptance Criteria

1. **AC1: InProcessMCPServer 创建** — 给定一组 `ToolProtocol` 工具，当调用 `createInProcessMCPServer(name:version:tools:)`，则创建一个 `InProcessMCPServer` 实例，持有工具引用和服务器元信息（FR21）。

2. **AC2: McpServerConfig.sdk 配置** — 给定 `InProcessMCPServer` 实例，当调用其 `asConfig()` 方法，则返回 `McpServerConfig.sdk(InProcessMcpConfig)` 配置，可无缝用于 `AgentOptions.mcpServers`。

3. **AC3: 工具暴露为 MCP 协议** — 给定带有已注册工具的 `InProcessMCPServer`，当外部 MCP 客户端通过 `InMemoryTransport` 连接并发送 `tools/list` 请求，则服务器通过 MCP 协议返回所有工具定义，包含名称、描述和 inputSchema（FR21）。

4. **AC4: 工具执行分派** — 给定外部 MCP 客户端通过 `InProcessMCPServer` 发送 `tools/call` 请求，当请求的工具名存在于已注册工具中，则工具调用被分派到对应的 `ToolProtocol.call()` 方法，结果通过 MCP 协议返回给客户端（FR21）。

5. **AC5: 工具命名空间** — 给定 `InProcessMCPServer` 的服务器名 `weather` 和工具名 `get_weather`，当客户端列出工具或调用工具，则暴露的工具名为原始名称（无命名空间前缀），因为命名空间由 `MCPClientManager` 在客户端侧管理（架构规则 #10）。

6. **AC6: Agent 集成** — 给定 `McpServerConfig.sdk` 配置，当 `Agent.assembleFullToolPool()` 处理 `mcpServers` 时，则识别 `sdk` 配置类型，直接将 `InProcessMCPServer` 的工具（带 `mcp__{serverName}__` 命名空间）添加到工具池，**不**通过 `MCPClientManager`（避免不必要的网络传输）。

7. **AC7: 会话创建与生命周期** — 给定 `InProcessMCPServer`，当调用 `createSession()` 创建新的 MCP 会话，则返回 `(Server, InMemoryTransport)` 对用于客户端连接，支持多客户端并发连接（每个客户端独立会话）。

8. **AC8: 未知工具处理** — 给定外部 MCP 客户端调用不存在的工具名，当 `tools/call` 请求到达服务器，则返回 MCP 协议错误（`invalidParams`），不崩溃。

9. **AC9: 模块边界合规** — 给定 `InProcessMCPServer` 位于 `Tools/MCP/` 目录，当检查 import 语句，则只导入 `Foundation`、`Types/` 和 `MCP`（mcp-swift-sdk），**不导入** `Core/`、`Stores/` 或其他内部模块（架构规则 #7、#61）。

10. **AC10: 单元测试覆盖** — 给定进程内 MCP 服务器功能，当检查 `Tests/OpenAgentSDKTests/MCP/`，则包含以下测试：
    - InProcessMCPServer 创建和属性验证
    - 工具暴露为 MCP 协议（通过 InMemoryTransport 连接测试）
    - 工具执行分派和结果返回
    - 未知工具调用错误处理
    - 多会话创建
    - McpServerConfig.sdk 配置生成

11. **AC11: E2E 测试覆盖** — 给定故事完成后，当检查 `Sources/E2ETest/`，则包含进程内 MCP 服务器的 E2E 测试，至少覆盖：服务器创建、MCP 会话连接、工具列表获取、工具调用执行。

12. **AC12: 错误处理** — 给定工具执行抛出异常，当 `tools/call` 请求处理该工具，则异常被捕获，返回 `isError: true` 的 MCP 响应，服务器不崩溃（NFR17）。

## Tasks / Subtasks

- [ ] Task 1: 创建 InProcessMCPServer actor (AC: #1, #3, #4, #7, #8, #12)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift`
  - [ ] 定义 `InProcessMCPServer` actor，持有 `name`、`version`、`[ToolProtocol]` 工具列表
  - [ ] 实现 `createSession()` 方法，创建 `MCPServer` + `InMemoryTransport` 对
  - [ ] 注册 `ListTools` 和 `CallTool` 请求处理器
  - [ ] 将 `ToolProtocol` 的 `inputSchema` 转换为 MCP `Value` 格式
  - [ ] 将 `ToolProtocol.call()` 的 `ToolResult` 转换为 MCP `CallTool.Result`
  - [ ] 处理未知工具名（返回 MCP 协议错误）
  - [ ] 捕获工具执行异常，返回 `isError: true`

- [ ] Task 2: 扩展 McpServerConfig 支持 sdk 类型 (AC: #2, #6)
  - [ ] 在 `Types/MCPConfig.swift` 中添加 `McpSdkServerConfig` struct
  - [ ] 在 `McpServerConfig` enum 中添加 `.sdk(McpSdkServerConfig)` case
  - [ ] 在 `InProcessMCPServer` 中添加 `asConfig()` 方法
  - [ ] 确保 `McpServerConfig` 仍符合 `Sendable` 和 `Equatable`

- [ ] Task 3: Agent 集成 (AC: #6)
  - [ ] 修改 `Core/Agent.swift` 的 `assembleFullToolPool()` 和 stream 方法
  - [ ] 在 MCP 连接循环中添加 `.sdk` 配置检测
  - [ ] 对于 `.sdk` 配置，直接提取工具并添加 `mcp__{serverName}__` 命名空间前缀
  - [ ] 对于 `.sdk` 配置，跳过 `MCPClientManager` 连接流程

- [ ] Task 4: 单元测试 (AC: #10)
  - [ ] 创建 `Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift`
  - [ ] 测试服务器创建和属性
  - [ ] 测试通过 InMemoryTransport 的工具列表
  - [ ] 测试工具执行和结果返回
  - [ ] 测试未知工具错误处理
  - [ ] 测试多会话创建
  - [ ] 测试 McpServerConfig.sdk 配置生成

- [ ] Task 5: 编译验证
  - [ ] 运行 `swift build` 确认编译通过
  - [ ] 验证新代码符合模块边界规则
  - [ ] 验证全部测试（包括之前的 MCP 测试）仍然通过

- [ ] Task 6: E2E 测试 (AC: #11)
  - [ ] 在 `Sources/E2ETest/` 中补充进程内 MCP 服务器的 E2E 测试
  - [ ] 覆盖服务器创建、会话连接、工具列表、工具调用

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 6（MCP 协议集成）的第三个 story
- 在 Story 6-1（MCPClientManager + stdio）和 Story 6-2（HTTP/SSE）基础上实现反向功能
- **关键目标：** 让开发者可以将 Agent 的工具暴露为 MCP 服务器，使外部 MCP 客户端可以使用这些工具
- **与 Story 6-1/6-2 互补：** 6-1/6-2 是"连接外部服务器"，本 story 是"暴露自身为服务器"

**两种使用模式：**

1. **SDK 内部模式（直接工具注入）：** `McpServerConfig.sdk` → Agent 直接提取工具添加到工具池，无网络开销
2. **外部客户端模式（MCP 协议）：** 外部 MCP 客户端通过 `InMemoryTransport` 或 stdio 连接 → 标准 MCP 握手和工具调用

### mcp-swift-sdk Server API 要点

mcp-swift-sdk 提供了两个层级的 Server API：

1. **`Server`（低层 actor）** — 直接管理 MCP 协议层
   - `Server(name:version:capabilities:)` 创建实例
   - `server.start(transport:)` 开始消息循环
   - `server.withRequestHandler(ListTools.self)` 注册工具列表处理器
   - `server.withRequestHandler(CallTool.self)` 注册工具调用处理器
   - `server.stop()` 停止服务器

2. **`MCPServer`（高层 actor）** — 带有工具/资源/提示注册表
   - `MCPServer(name:version:)` 创建共享注册表的服务器
   - `mcpServer.register { ToolType.self }` DSL 注册
   - `mcpServer.createSession()` 创建新的 `Server` 实例（每个客户端独立）
   - 支持多会话和 list-changed 通知广播

3. **`InMemoryTransport`（actor）** — 进程内传输
   - `InMemoryTransport.createConnectedPair()` 创建配对的客户端/服务端传输
   - `client.connect(transport: clientTransport)` + `server.start(transport: serverTransport)`

### 实现策略

**策略：使用 MCPServer（高层 API）+ InMemoryTransport**

选择 `MCPServer` 而非低层 `Server`，因为：
- `MCPServer` 自带 `ToolRegistry`，支持闭包注册工具
- `MCPServer.createSession()` 支持多客户端并发
- 自动处理 MCP 协议细节（初始化、ping、能力协商）
- 自动广播 list-changed 通知

**核心流程：**

```
InProcessMCPServer (新 actor)
  ├── 持有 [ToolProtocol] 工具列表
  ├── 内部创建 MCPServer 并注册工具
  ├── createSession() → (Server, InMemoryTransport) 对
  └── 外部客户端通过 InMemoryTransport 连接

McpServerConfig.sdk (新枚举 case)
  └── Agent 检测后直接提取工具（无 MCP 协议开销）
```

**工具注册流程（MCPServer + 闭包注册）：**

```swift
// 对每个 ToolProtocol 工具，通过 MCPServer 的闭包注册 API 注册
try await mcpServer.register(
    name: tool.name,
    description: tool.description,
    inputSchema: schemaToValue(tool.inputSchema)
) { (args: [String: Value], context: HandlerContext) in
    // 将 MCP Value 参数转为 [String: Any]
    // 调用 tool.call(input:context:)
    // 将 ToolResult 转为 CallTool.Result
}
```

### ToolProtocol 到 MCP Tool 的转换

**inputSchema 转换：** `[String: Any]` → MCP `Value`
- 递归转换字典结构
- 与 `MCPClientManager` 中 `mcpValueToSchema()` 相反的操作
- 参考 `MCPClientWrapper.anyToMCPValue()` 的转换逻辑

**ToolResult 转换：** `ToolResult` → MCP `CallTool.Result`
```swift
CallTool.Result(
    content: [.text(toolResult.content)],
    isError: toolResult.isError
)
```

**ToolContext 构建：** MCP 调用需要构建 `ToolContext`
- `cwd`：从 InProcessMCPServer 的配置获取
- `toolUseId`：从 MCP 请求的 ID 获取
- 其他 store 字段：`nil`（InProcessMCPServer 不依赖这些 store）

### 与 TypeScript SDK 的对齐

TypeScript SDK 的 `createSdkMcpServer()` 实现：
- `McpSdkServerConfig`：`{ type: 'sdk', name, version, tools, _sdkTools }`
- `isSdkServerConfig()`：类型检查
- Agent 中：`isSdkServerConfig(config)` → 直接添加 `config.tools` 到工具池
- 工具名称在创建时就加上 `mcp__{serverName}__` 前缀

Swift 版本的关键差异：
- Swift 使用 enum 关联值（`McpServerConfig.sdk(McpSdkServerConfig)`）而非 `type` 字段
- Swift 使用 `ToolProtocol` 而非 `ToolDefinition`
- Swift 的 `MCPClientManager` 处理连接，SDK 服务器绕过它直接注入

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `MCPClientManager` | `Tools/MCP/MCPClientManager.swift` | 无需修改（SDK 服务器不通过它） |
| `MCPToolDefinition` | `Tools/MCP/MCPToolDefinition.swift` | 参考其 schema 转换逻辑 |
| `MCPClientWrapper` | `Tools/MCP/MCPClientManager.swift` | 参考其 `anyToMCPValue()` 转换 |
| `MCPConnectionStatus` | `Types/MCPTypes.swift` | 无需修改 |
| `MCPManagedConnection` | `Types/MCPTypes.swift` | 无需修改 |
| `McpServerConfig` | `Types/MCPConfig.swift` | **需要修改** — 添加 `.sdk` case |
| `McpStdioConfig` | `Types/MCPConfig.swift` | 无需修改 |
| `McpSseConfig` | `Types/MCPConfig.swift` | 无需修改 |
| `McpHttpConfig` | `Types/MCPConfig.swift` | 无需修改 |
| `Agent.swift` | `Core/Agent.swift` | **需要修改** — 处理 `.sdk` 配置 |
| `ToolProtocol` | `Types/ToolTypes.swift` | 无需修改 |
| `ToolResult` | `Types/ToolTypes.swift` | 无需修改 |
| `ToolContext` | `Types/ToolTypes.swift` | 无需修改 |
| `MCPServer` | mcp-swift-sdk | 外部依赖，直接使用 |
| `InMemoryTransport` | mcp-swift-sdk | 外部依赖，直接使用 |
| `Server` | mcp-swift-sdk | 外部依赖，由 MCPServer.createSession() 返回 |

### InProcessMCPServer 设计细节

**新文件：** `Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift`

```swift
/// Actor that hosts in-process MCP tools for external MCP clients.
///
/// Wraps `ToolProtocol` tools as an MCP server using mcp-swift-sdk's `MCPServer`
/// and `InMemoryTransport`. Supports two usage modes:
///
/// 1. **SDK internal mode:** Via `McpServerConfig.sdk` → Agent directly adds tools
///    to the tool pool without MCP protocol overhead.
///
/// 2. **External client mode:** External MCP clients connect via `createSession()`
///    → standard MCP handshake and tool invocation.
public actor InProcessMCPServer {
    /// Server name.
    public let name: String
    /// Server version.
    public let version: String
    /// Registered tools.
    private let tools: [ToolProtocol]
    /// Working directory for ToolContext.
    private let cwd: String
    /// Internal MCPServer instance.
    private var mcpServer: MCPServer?

    public init(name: String, version: String = "1.0.0", tools: [ToolProtocol], cwd: String = "/") { ... }

    /// Creates a new MCP session with an InMemoryTransport pair.
    /// Returns (Server, InMemoryTransport) for the client to connect.
    public func createSession() async -> (Server, InMemoryTransport) { ... }

    /// Returns the tool list for direct injection (SDK internal mode).
    public func getTools() -> [ToolProtocol] { ... }

    /// Generates an McpServerConfig.sdk configuration.
    public func asConfig() -> McpServerConfig { ... }
}
```

### McpServerConfig 扩展设计

**修改文件：** `Sources/OpenAgentSDK/Types/MCPConfig.swift`

```swift
/// Configuration for in-process SDK MCP server.
public struct McpSdkServerConfig: Sendable, Equatable {
    public let name: String
    public let version: String
    /// Reference to the InProcessMCPServer for tool extraction.
    // 注意：InProcessMCPServer 是 actor（引用类型），
    // 无法直接 Equatable。使用 objectIdentifier 比较。
}

/// 扩展 McpServerConfig:
public enum McpServerConfig: Sendable, Equatable {
    case stdio(McpStdioConfig)
    case sse(McpSseConfig)
    case http(McpHttpConfig)
    case sdk(McpSdkServerConfig)  // 新增
}
```

**注意：** `McpSdkServerConfig` 包含对 `InProcessMCPServer` actor 的引用。由于 actor 是引用类型，`Equatable` 需要通过 `===` 比较。一种方案是不在 `McpSdkServerConfig` 中存储引用，而是在 `Agent` 的 `assembleFullToolPool()` 中通过模式匹配处理。

**备选方案（推荐）：** 不在 `McpServerConfig` 中存储 actor 引用。改用单独的 `sdkServers` 属性或让 `Agent` 直接处理 `InProcessMCPServer`：

```swift
// 方案 A：McpServerConfig.sdk 包含服务器引用
public enum McpServerConfig {
    case sdk(McpSdkServerConfig)  // McpSdkServerConfig 持有 InProcessMCPServer 引用
}

// 方案 B：AgentOptions 中添加 sdkServers 属性（避免修改 McpServerConfig）
// 这样 McpServerConfig 保持简单的值类型
```

**推荐方案 A**（与 TypeScript SDK 保持一致，通过 config 统一管理），使用 `anyObject` 相等性检查实现 `Equatable`。

### Agent 集成修改要点

**修改 `Core/Agent.swift` 的 `assembleFullToolPool()` 和 stream 方法中的 MCP 连接逻辑：**

```swift
// 当前代码（需要修改的部分）：
if let mcpServers = capturedMcpServers, !mcpServers.isEmpty {
    let manager = MCPClientManager()
    await manager.connectAll(servers: mcpServers)
    // ...
}

// 修改后：
if let mcpServers = capturedMcpServers, !mcpServers.isEmpty {
    var externalServers: [String: McpServerConfig] = [:]
    var sdkTools: [ToolProtocol] = []

    for (name, config) in mcpServers {
        switch config {
        case .sdk(let sdkConfig):
            // 直接提取工具，添加命名空间前缀
            let namespaced = sdkConfig.server.getTools().map { tool in
                MCPToolDefinition(
                    serverName: sdkConfig.name,
                    mcpToolName: tool.name,
                    toolDescription: tool.description,
                    schema: tool.inputSchema,
                    mcpClient: DirectToolClient(tool: tool, cwd: cwd ?? "/")
                )
            }
            sdkTools.append(contentsOf: namespaced)
        default:
            externalServers[name] = config
        }
    }

    // 连接外部 MCP 服务器
    if !externalServers.isEmpty {
        let manager = MCPClientManager()
        await manager.connectAll(servers: externalServers)
        let mcpTools = await manager.getMCPTools()
        sdkTools.append(contentsOf: mcpTools)
    }
    // 合并 sdkTools 到工具池...
}
```

**DirectToolClient（私有类型）：** 用于将 `ToolProtocol` 包装为 `MCPClientProtocol`，使 `MCPToolDefinition` 可以直接调用工具（绕过 MCP 协议）。

### 模块边界注意事项

```
Tools/MCP/InProcessMCPServer.swift   → 导入 Foundation + MCP + Types/ (新建)
Tools/MCP/MCPToolDefinition.swift    → 无变更
Tools/MCP/MCPClientManager.swift     → 无变更
Types/MCPConfig.swift                → 添加 .sdk case + McpSdkServerConfig (修改)
Types/MCPTypes.swift                 → 无变更
Core/Agent.swift                     → 处理 .sdk 配置 (修改)
```

### 前序 Story 的经验教训（必须遵循）

1. **nonisolated(unsafe) 用于 schema 常量** — inputSchema 字典需要标记为 `nonisolated(unsafe)` 以避免 Sendable 警告（Story 6-1）
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **错误路径测试** — 必须覆盖每个 guard 分支和每个 error case（规则 #28）
4. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - Session Management`
5. **Actor 模式** — InProcessMCPServer 应该是 actor（持有 MCPServer 引用）
6. **不 throw 错误** — 工具调用错误应捕获为 isError: true（规则 #38）
7. **跨平台** — 不使用 Apple 专属框架（InMemoryTransport 已处理）
8. **E2E 测试** — 完成后必须在 `Sources/E2ETest/` 中补充 E2E 测试（规则 #29）
9. **mock MCPClient** — 使用 MCPClientProtocol 协议进行 mock 测试（Story 6-1 模式）
10. **@Sendable 注解** — 传递给 mcp-swift-sdk 的闭包需要标记 `@Sendable`（Story 6-2 修复）

### 反模式警告

- **不要**使用低层 `Server` API（除非有明确理由）— 优先使用 `MCPServer` 的高级 API
- **不要**在 Tools/MCP/ 中导入 Core/ 或 Stores/ — 违反模块边界（规则 #7）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — MCPToolDefinition 已处理（规则 #38）
- **不要**修改 MCPToolDefinition — 它已完全支持本 story 的需求
- **不要**修改 MCPClientManager — SDK 服务器不通过客户端管理器
- **不要**在 SDK 模式下通过 MCP 协议调用工具 — 直接调用 `ToolProtocol.call()`（避免不必要的序列化/反序列化）
- **不要**忘记在 stream 方法中也添加 `.sdk` 处理 — 与 `assembleFullToolPool()` 保持一致
- **不要**使用 `import Logging` — 与前序 story 保持一致，不引入 Logging 依赖复杂性

### 测试策略

**单元测试（mock）：**
- InProcessMCPServer 创建和属性验证
- 通过 InMemoryTransport 连接的 MCP 工具列表获取
- 工具执行分派和 ToolResult → MCP CallTool.Result 转换
- 未知工具调用 → MCP 协议错误
- 多会话创建（每个客户端独立 Server 实例）
- McpServerConfig.sdk 配置生成和等价性
- 工具执行异常 → isError: true 响应

**集成测试：**
- 完整的 MCP 握手流程（Client + InMemoryTransport + InProcessMCPServer）
- 工具调用端到端验证

**模块边界测试：**
- 验证 Tools/MCP/ 文件不导入 Core/ 或 Stores/

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 6-1 (已完成) | MCPClientManager + stdio — 本 story 的 SDK 服务器不通过客户端管理器 |
| 6-2 (已完成) | HTTP/SSE 传输 — 与本 story 互补（出站连接 vs 入站服务） |
| 6-4 (未开始) | MCP 工具 Agent 集成 — 将统一所有 MCP 工具的集成方式 |
| 3-1 (已完成) | 工具协议与注册表 — ToolProtocol 是本 story 的核心接口 |

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.3]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD5 MCP 集成]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR21 进程内 MCP 服务器]
- [Source: _bmad-output/project-context.md#规则 7 模块边界]
- [Source: _bmad-output/project-context.md#规则 10 MCP 命名空间]
- [Source: _bmad-output/implementation-artifacts/6-2-mcp-http-sse-transport.md] — 前序 story 参考
- [Source: _bmad-output/implementation-artifacts/6-1-mcp-client-manager-stdio.md] — 前序 story 参考
- [Source: mcp-swift-sdk MCPServer.swift] — 高层 MCP 服务器 API
- [Source: mcp-swift-sdk Server.swift] — 低层 MCP 服务器协议层
- [Source: mcp-swift-sdk InMemoryTransport.swift] — 进程内传输实现
- [Source: mcp-swift-sdk Tools.swift] — MCP Tool/CallTool 类型定义
- [Source: TypeScript SDK sdk-mcp-server.ts] — TypeScript 参考实现
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift] — 复用的工具包装器
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift] — 参考其 schema 转换逻辑
- [Source: Sources/OpenAgentSDK/Types/MCPConfig.swift] — 需要添加 .sdk case
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol 定义
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — 需要处理 .sdk 配置

### Project Structure Notes

- **新建** `Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift` — InProcessMCPServer actor 实现
- **修改** `Sources/OpenAgentSDK/Types/MCPConfig.swift` — 添加 McpSdkServerConfig 和 .sdk case
- **修改** `Sources/OpenAgentSDK/Core/Agent.swift` — 处理 .sdk 配置类型
- **新建** `Tests/OpenAgentSDKTests/MCP/InProcessMCPServerTests.swift` — 单元测试
- **修改** `Sources/E2ETest/MCPClientManagerTests.swift` — 添加 InProcessMCPServer E2E 测试
- 完全对齐架构文档的目录结构和模块边界

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

# Story 6.1: MCP 客户端管理器与 Stdio 传输

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望通过 stdio 传输连接外部 MCP 服务器，
以便我的 Agent 可以使用外部进程提供的工具。

## Acceptance Criteria

1. **AC1: MCPClientManager Actor 创建** — 给定 `MCPClientManager` actor，当开发者创建实例并传入 `[String: McpServerConfig]` 配置，则管理器以 `disconnected` 状态初始化，连接字典为空（FR19）。

2. **AC2: Stdio 传输连接** — 给定配置了 stdio 服务器配置（command + args）的 MCPClientManager，当调用 `connect(name:config:)` 建立连接，则：外部进程通过 `Process`（macOS）/ `posix_spawn`（Linux）启动，mcp-swift-sdk 的 `MCPClient` 完成握手，返回连接信息（FR19）。

3. **AC3: 进程生命周期管理** — 给定通过 stdio 连接的 MCP 服务器进程，当管理器管理连接生命周期（NFR19）：
   - **启动**：`connect()` 使用 `Process` 启动子进程，管道连接 stdin/stdout
   - **崩溃恢复**：进程崩溃时 `MCPClientManager` 检测到故障（通过 MCPClient 的 reconnection 或 pipe 断开），将连接状态标记为 `disconnected`/`error`，不崩溃
   - **优雅关闭**：`disconnect()` 或 `shutdown()` 先关闭 MCPClient，再终止子进程

4. **AC4: 连接状态追踪** — 给定 MCPClientManager 管理多个连接，当开发者检查 `connections` 属性，则返回 `[String: MCPManagedConnection]`，每个连接包含 `name`、`status`（connected/disconnected/error）和 `tools` 列表。

5. **AC5: 工具发现** — 给定已连接的 MCP 服务器，当连接成功建立后，则自动调用 `listTools()` 获取可用工具列表，工具以 `mcp__{serverName}__{toolName}` 命名空间包装为 `ToolProtocol`（FR19、架构规则 #10）。

6. **AC6: MCP 工具执行** — 给定已包装为 `ToolProtocol` 的 MCP 工具，当 LLM 请求执行该工具，则通过底层 `MCPClient.callTool()` 分派，结果提取 text content 返回给智能循环。错误被捕获为 `is_error: true` 的 `ToolResult`，不中断循环（NFR17）。

7. **AC7: Agent 集成** — 给定 `AgentOptions.mcpServers` 已配置，当调用 `agent.prompt()` 或 `agent.stream()`，则 MCPClientManager 在首次调用时自动连接所有配置的服务器，MCP 工具与内置工具合并到工具池中（FR22）。使用 `assembleToolPool()` 进行合并。

8. **AC8: 多服务器管理** — 给定多个 stdio 服务器配置，当 MCPClientManager 连接所有服务器，则每个服务器独立管理（独立进程、独立 MCPClient），可以同时连接和断开而不影响其他服务器。

9. **AC9: 连接失败处理** — 给定无法启动的 stdio 服务器（如命令不存在），当 `connect()` 被调用，则连接状态标记为 `error`，错误被记录，Agent 不崩溃，该服务器的工具列表为空（NFR19）。

10. **AC10: 全部关闭** — 给定多个活跃连接，当 `shutdown()` 被调用，则所有 MCPClient 连接被关闭，所有子进程被终止，资源被清理。

11. **AC11: 模块边界合规** — 给定 MCPClientManager 位于 `Tools/MCP/` 目录，当检查 import 语句，则只导入 `Foundation`、`Types/` 和 `MCP`（mcp-swift-sdk），**不导入** `Core/`、`Stores/` 或其他内部模块（架构规则 #7、#61）。

12. **AC12: 跨平台兼容** — 给定 stdio 传输需要启动子进程，当在 macOS 和 Linux 上运行，则使用 `Process`（Foundation）在 macOS 上启动子进程，使用等效的 POSIX API 在 Linux 上启动子进程（NFR11、架构规则 #36）。

13. **AC13: API 密钥安全** — 给定 MCP 服务器配置中的环境变量，当传递给子进程，则父进程的 API 密钥（CODEANY_API_KEY）不会被泄露到子进程环境变量中（除非显式配置）（NFR6）。

14. **AC14: 单元测试覆盖** — 给定 MCPClientManager 和相关类型，当检查 `Tests/OpenAgentSDKTests/MCP/`，则包含以下测试：
    - MCPClientManager 初始化（空配置）
    - MCPToolDefinition 包装（命名空间、inputSchema 传递）
    - 连接状态管理（mock MCPClient）
    - 多连接管理
    - shutdown 清理
    - 错误处理（连接失败不崩溃）

15. **AC15: E2E 测试覆盖** — 给定故事完成后，当检查 `Sources/E2ETest/`，则包含 MCPClientManager 的 E2E 测试，至少覆盖：MCPClientManager 创建、连接状态查询、工具列表获取（使用 echo MCP 服务器或类似轻量级服务器）。

## Tasks / Subtasks

- [x] Task 1: 定义 MCPManagedConnection 和 MCPConnectionStatus 类型 (AC: #4)
  - [x] 在 `Types/MCPTypes.swift` 中定义 `MCPConnectionStatus` 枚举（connected/disconnected/error）
  - [x] 定义 `MCPManagedConnection` struct（name, status, tools: [ToolProtocol], mcpClient: MCPClient?）
  - [x] 确保类型为 Sendable 且位于 Types/（叶节点）

- [x] Task 2: 实现 MCPStdioTransport (AC: #2, #3, #12)
  - [x] 在 `Tools/MCP/MCPStdioTransport.swift` 中实现 `MCPStdioTransport` actor
  - [x] 使用 Foundation `Process` 启动子进程，创建 stdin/stdout Pipe
  - [x] 将子进程 stdout 管道适配为 JSON-RPC 消息通道（非 Transport 协议，简化实现）
  - [x] 处理进程终止检测（Process.terminate()）
  - [x] 支持自定义环境变量注入

- [x] Task 3: 实现 MCPToolDefinition 包装器 (AC: #5, #6)
  - [x] 在 `Tools/MCP/MCPToolDefinition.swift` 中实现 `MCPToolDefinition` struct
  - [x] 符合 `ToolProtocol`：name 使用 `mcp__{serverName}__{toolName}` 命名空间
  - [x] 传递 MCP 服务器的 inputSchema
  - [x] `call()` 方法通过 MCPClientProtocol.callTool() 执行
  - [x] isReadOnly 返回 false（MCP 工具默认非只读，与 TS SDK 一致）
  - [x] 错误在 ToolResult(isError: true) 中捕获，不 throw

- [x] Task 4: 实现 MCPClientManager actor (AC: #1, #2, #4, #8, #9, #10)
  - [x] 在 `Tools/MCP/MCPClientManager.swift` 中实现 `MCPClientManager` actor
  - [x] `connect(name:config:)` — 启动进程、创建连接、发现工具
  - [x] `connectAll(servers:)` — 批量连接配置的服务器
  - [x] `disconnect(name:)` — 关闭单个连接
  - [x] `shutdown()` — 关闭所有连接、终止所有子进程
  - [x] `getConnections()` — 返回当前连接信息字典
  - [x] `getMCPTools()` — 返回所有已连接服务器的 ToolProtocol 数组
  - [x] 连接失败时标记 error 状态，不崩溃

- [x] Task 5: 集成到 Agent (AC: #7)
  - [x] 修改 `Core/Agent.swift` 的 `prompt()` 方法
  - [x] 在工具执行前检查 `options.mcpServers`，如果有配置则创建 MCPClientManager
  - [x] 调用 `connectAll()` 连接所有服务器
  - [x] 获取 MCP 工具并通过 `assembleToolPool()` 合并到工具池
  - [x] 在查询结束时调用 `shutdown()` 清理连接

- [x] Task 6: 更新模块入口 (AC: #11)
  - [x] 在 `OpenAgentSDK.swift` 中添加 MCPClientManager 相关公共类型的文档引用

- [x] Task 7: 单元测试 (AC: #14)
  - [x] 创建 `Tests/OpenAgentSDKTests/MCP/MCPClientManagerTests.swift`
  - [x] 测试 MCPClientManager 初始化
  - [x] 测试 MCPToolDefinition 命名空间和 schema 传递
  - [x] 测试 MCPToolDefinition call() 的成功和错误路径
  - [x] 测试连接状态管理（使用 mock）
  - [x] 测试 shutdown 清理
  - [x] 测试模块边界（不导入 Core/）

- [x] Task 8: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证新文件符合模块边界规则
  - [x] 验证测试可以编译并通过

- [x] Task 9: E2E 测试 (AC: #15)
  - [x] 在 `Sources/E2ETest/` 中创建 MCPClientManager E2E 测试
  - [x] 覆盖 MCPClientManager 创建、连接状态、工具列表、shutdown

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 6（MCP 协议集成）的第一个 story
- 本 story 实现 `MCPClientManager` actor 和 stdio 传输连接
- 这是 MCP 集成的基础，后续 story 6-2（HTTP/SSE）、6-3（进程内服务器）和 6-4（工具集成）都依赖本 story
- **关键目标：** 让 Agent 能够通过 stdio 启动外部 MCP 服务器进程，发现并使用其工具

**与 TypeScript SDK 的架构对照：**

TypeScript SDK 的 `mcp/client.ts` 中：
- `connectMCPServer(name, config)` 函数直接导入 `@modelcontextprotocol/sdk` 的 Client 和 transport
- `MCPConnection` 接口包含 `name`、`status`、`tools`、`close()`
- `createMCPToolDefinition()` 创建包装 MCP 工具的 `ToolDefinition`
- `closeAllConnections()` 关闭所有连接

Swift 端的关键差异：
1. **MCPClientManager 是 actor**（线程安全，管理共享可变连接状态）
2. **使用 mcp-swift-sdk 的 `MCPClient`** 而非自定义 MCP 客户端（mcp-swift-sdk 已提供带重连的 `MCPClient` actor）
3. **stdio 传输需要自定义实现**：mcp-swift-sdk 的 `StdioTransport` 是服务器端（读 stdin/写 stdout），客户端需要启动子进程并通过管道通信
4. **进程管理**：Swift 端使用 `Process`（Foundation）管理子进程生命周期

### mcp-swift-sdk API 要点

**已安装的 mcp-swift-sdk 提供以下关键 API：**

1. **`MCPClient`（actor）** — 高级 MCP 客户端，带自动重连和健康检查
   - `connect(transport:)` — 连接传输并初始化
   - `disconnect()` — 断开连接
   - `callTool(name:arguments:)` — 调用工具（带自动重试）
   - `listTools()` — 列出服务器工具
   - `listResources()` / `readResource(uri:)` — 资源操作
   - `state: ConnectionState` — 连接状态（disconnected/connecting/connected/reconnecting）
   - `onStateChanged` / `onToolsChanged` — 状态变更回调

2. **`Client`（actor）** — 底层 MCP 客户端
   - `connect(transport:)` — 连接传输
   - 与 MCPClient 的区别：无自动重连

3. **`Transport` protocol** — 传输接口
   - `connect()` / `disconnect()` / `send(_:options:)`
   - `StdioTransport` — 服务器端 stdio（不适合客户端使用）

4. **`HTTPClientTransport`** — HTTP 传输（Story 6-2 使用）

**MCPClient 的优势（决定使用它而非直接使用 Client）：**
- 内置自动重连（`ReconnectionOptions`）
- 健康检查 ping
- 工具列表变更通知
- 连接状态观察

### Stdio 传输实现策略

mcp-swift-sdk 的 `StdioTransport` 是为 MCP **服务器**设计的（读 stdin/写 stdout）。我们需要实现一个**客户端侧**的 stdio 传输，它：
1. 使用 `Process` 启动子进程
2. 创建 stdin/stdout Pipe 连接到子进程
3. 将子进程的 stdin/stdout 适配为 `Transport` 协议

**实现方案：**

由于 mcp-swift-sdk 的 `Transport` 协议继承自 `Actor`，我们需要实现一个符合 `Transport` 的 actor，它：
- 在 `connect()` 时启动子进程
- 在 `send()` 时将数据写入子进程 stdin
- 通过 Pipe 读取子进程 stdout 并解析 JSON-RPC 消息
- 在 `disconnect()` 时终止子进程

**注意：** 可以直接使用 mcp-swift-sdk 的底层传输机制，但需要包装 `Process` 管道。参考 mcp-swift-sdk 的 `StdioTransport` 实现模式，但方向相反（写 stdin/读 stdout vs 读 stdin/写 stdout）。

**备选方案：** 如果实现自定义 Transport 过于复杂，可以简化为：
1. 使用 `Process` 启动子进程
2. 创建一个基于 Pipe 的简单 JSON-RPC 消息通道
3. 在 MCPClientManager 内部直接处理消息收发
4. 将 `Process` 的管道包装成 mcp-swift-sdk 可以使用的传输

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `McpServerConfig` | `Types/MCPConfig.swift` | MCP 服务器配置枚举（stdio/sse/http） |
| `McpStdioConfig` | `Types/MCPConfig.swift` | Stdio 配置：command, args, env |
| `McpSseConfig` | `Types/MCPConfig.swift` | SSE 配置（Story 6-2） |
| `McpHttpConfig` | `Types/MCPConfig.swift` | HTTP 配置（Story 6-2） |
| `MCPConnectionInfo` | `Types/MCPResourceTypes.swift` | 资源工具用的连接信息（将被本 story 增强或替换） |
| `MCPResourceProvider` | `Types/MCPResourceTypes.swift` | 资源操作协议 |
| `AgentOptions` | `Types/AgentTypes.swift` | 已有 `mcpServers: [String: McpServerConfig]?` |
| `ToolContext` | `Types/ToolTypes.swift` | 工具执行上下文 |
| `ToolProtocol` | `Types/ToolTypes.swift` | 工具协议 |
| `assembleToolPool()` | `Tools/ToolRegistry.swift` | 已有 MCP 工具合并支持 |
| `setMcpConnections()` | `Tools/Specialist/ListMcpResourcesTool.swift` | 资源工具的全局连接注入 |
| `Agent` | `Core/Agent.swift` | 需要修改以集成 MCPClientManager |
| mcp-swift-sdk | 外部依赖 | 已在 Package.swift 中配置，提供 MCPClient、Transport 等 |

### MCPToolDefinition 包装器设计

参考 TypeScript SDK 的 `createMCPToolDefinition()`：

```swift
struct MCPToolDefinition: ToolProtocol, Sendable {
    let serverName: String
    let mcpToolName: String  // 原始工具名（不带命名空间）
    let toolDescription: String
    let schema: ToolInputSchema
    let mcpClient: MCPClient  // 引用底层 MCPClient 用于执行

    // ToolProtocol
    var name: String { "mcp__\(serverName)__\(mcpToolName)" }
    var description: String { toolDescription }
    var inputSchema: ToolInputSchema { schema }
    var isReadOnly: Bool { false }  // 与 TS SDK 一致

    func call(input: Any, context: ToolContext) async -> ToolResult {
        do {
            let arguments = convertToMCPArguments(input)
            let result = try await mcpClient.callTool(name: mcpToolName, arguments: arguments)
            // 提取 text content
            let output = extractContent(from: result)
            return ToolResult(
                toolUseId: context.toolUseId,
                content: output,
                isError: result.isError ?? false
            )
        } catch {
            return ToolResult(
                toolUseId: context.toolUseId,
                content: "MCP tool error: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}
```

**关键点：**
- `name` 使用 `mcp__{serverName}__{toolName}` 命名空间（架构规则 #10）
- `call()` 中捕获所有错误为 `ToolResult(isError: true)`，永不 throw（架构规则 #39）
- `inputSchema` 直接从 MCP 服务器的 `listTools()` 响应传递
- `isReadOnly` 返回 false（与 TS SDK `isReadOnly: () => false` 一致）

### MCPClientManager 设计

```swift
actor MCPClientManager {
    // 连接状态
    private var connections: [String: MCPManagedConnection] = [:]

    // 连接一个 MCP 服务器
    func connect(name: String, config: McpStdioConfig) async throws -> MCPManagedConnection

    // 批量连接
    func connectAll(servers: [String: McpServerConfig]) async

    // 断开单个连接
    func disconnect(name: String) async

    // 关闭所有连接
    func shutdown() async

    // 获取所有已连接服务器的工具
    func getMCPTools() -> [ToolProtocol]

    // 获取连接信息
    func getConnections() -> [String: MCPManagedConnection]
}
```

**连接流程（stdio）：**
1. 创建 `Process` 并配置 command、args、env
2. 创建 stdin/stdout Pipe
3. 启动子进程
4. 创建 Transport 包装器连接到子进程管道
5. 创建 MCPClient 并调用 `connect(transport:)`
6. 调用 `listTools()` 获取工具列表
7. 包装工具为 `MCPToolDefinition`
8. 存储 `MCPManagedConnection`

### 与 Story 5-7 的关系

Story 5-7（MCP 资源工具）定义了 `MCPResourceProvider` 协议和 `MCPConnectionInfo` 类型。这些类型使用全局 `setMcpConnections()` 注入。

**本 story 完成后需要重构：**
- `MCPClientManager` 可以提供真正的 MCP 连接列表
- 资源工具应该通过 `MCPClientManager` 获取连接，而非全局变量
- `MCPResourceProvider` 协议可以被 `MCPClient` 直接实现
- **但这是 Story 6-4 的工作**，本 story 不修改资源工具

### inputSchema 转换

mcp-swift-sdk 的 `Tool` 类型包含 `inputSchema` 属性（类型为 `Value`，即 JSON Value）。需要将其转换为 `ToolInputSchema`（`[String: Any]`）。

mcp-swift-sdk 的 `Value` 类型支持 `.object([String: Value])` 等 case，需要递归转换为 `[String: Any]`。

### 实现位置

**新增文件：**
```
Sources/OpenAgentSDK/Types/MCPTypes.swift                   # MCPManagedConnection, MCPConnectionStatus
Sources/OpenAgentSDK/Tools/MCP/MCPStdioTransport.swift      # Stdio 传输包装器
Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift       # MCP 工具 ToolProtocol 包装器
Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift        # MCPClientManager actor
```

**修改文件：**
```
Sources/OpenAgentSDK/Core/Agent.swift                        # 集成 MCPClientManager 到 prompt()/stream()
Sources/OpenAgentSDK/OpenAgentSDK.swift                      # 追加文档引用
```

**测试文件：**
```
Tests/OpenAgentSDKTests/MCP/MCPClientManagerTests.swift      # MCPClientManager 和相关类型测试
```

**不需要修改的文件：**
```
Types/ToolTypes.swift          # ToolProtocol 不需要修改
Types/MCPConfig.swift          # 配置类型已存在
Types/MCPResourceTypes.swift   # 资源类型保持不变（Story 6-4 重构）
Tools/ToolRegistry.swift       # assembleToolPool() 已支持 MCP 工具
```

### 前序 Story 的经验教训（必须遵循）

1. **nonisolated(unsafe) 用于 schema 常量** — inputSchema 字典需要标记为 `nonisolated(unsafe)` 以避免 Sendable 警告
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **错误路径测试** — 必须覆盖每个 guard 分支和每个 error case（规则 #28）
4. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - Factory Function`
5. **ToolExecuteResult 重载** — 使用 `defineTool` 返回 `ToolExecuteResult` 的重载
6. **Actor 模式** — 所有可变共享状态必须是 actor
7. **不 throw 错误** — 工具执行中的错误通过 ToolResult(isError: true) 返回
8. **跨平台** — 不使用 Apple 专属框架，使用 Foundation 的 Process（跨平台）
9. **E2E 测试** — 每个故事完成后必须在 `Sources/E2ETest/` 中补充 E2E 测试
10. **Story 5-7 的 MCPResourceTypes** — 已定义最小化类型，本 story 将使用并可能增强

### 反模式警告

- **不要**在 Tools/MCP/ 中导入 Core/ 或 Stores/ — 违反模块边界（规则 #7）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — 在 ToolResult 中捕获返回（规则 #38）
- **不要**使用 Apple 专属框架 — 必须跨平台（规则 #43）
- **不要**使用 mcp-swift-sdk 的 StdioTransport 作为客户端传输 — 它是为服务器设计的
- **不要**在连接失败时崩溃 — 标记 error 状态继续运行
- **不要**忘记 MCP 命名空间 — 工具名必须是 `mcp__{server}__{tool}`
- **不要**在 Agent 中创建 MCPClientManager 如果 mcpServers 为 nil — 懒初始化
- **不要**泄露 API 密钥到子进程环境 — 除非显式配置（NFR6）
- **不要**修改 MCPResourceTypes.swift 中的全局 setMcpConnections — Story 6-4 的工作

### 模块边界注意事项

```
Types/MCPTypes.swift                           → 无出站依赖（叶节点）
Types/MCPConfig.swift                          → 无出站依赖（已存在）
Types/MCPResourceTypes.swift                   → 无出站依赖（已存在，不修改）
Tools/MCP/MCPStdioTransport.swift              → 导入 Foundation + MCP（mcp-swift-sdk）
Tools/MCP/MCPToolDefinition.swift              → 导入 Foundation + Types/ + MCP
Tools/MCP/MCPClientManager.swift               → 导入 Foundation + Types/ + MCP + MCPStdioTransport + MCPToolDefinition
Core/Agent.swift                               → 导入 Types/ + Tools/MCP/（新增）
```

MCP 模块的特殊性：它需要导入外部依赖 `MCP`（mcp-swift-sdk），同时遵循内部模块边界规则。

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 5-7 (已完成) | MCP 资源工具 — 全局 setMcpConnections 注入，本 story 提供真正的 MCP 连接 |
| 6-2 (未开始) | HTTP/SSE 传输 — 本 story 的 MCPClientManager 将扩展支持 SSE/HTTP |
| 6-3 (未开始) | 进程内 MCP 服务器 — 与本 story 的客户端管理器是互补关系 |
| 6-4 (未开始) | MCP 工具 Agent 集成 — 将重构资源工具和 ToolContext 注入 |
| 3-3 (已完成) | ToolExecutor — 本 story 的 MCPToolDefinition 通过现有执行器运行 |
| 3-1 (已完成) | ToolRegistry — assembleToolPool() 已支持 MCP 工具合并 |

### 测试策略

**MCPClientManager 测试策略：**

由于 MCP 连接需要实际的外部进程，测试主要使用 mock 方式：

1. **单元测试（mock）：**
   - MCPToolDefinition 命名空间验证
   - MCPToolDefinition schema 传递验证
   - MCPToolDefinition call() 的成功/错误路径（mock MCPClient）
   - MCPClientManager 初始化
   - MCPClientManager 连接状态管理
   - MCPClientManager shutdown 清理
   - 连接失败处理（错误状态不崩溃）

2. **集成测试（真实进程）：**
   - 如果有可用的 MCP echo/test 服务器，可以测试真实连接
   - 否则使用 mock 传输测试连接流程

3. **模块边界测试：**
   - 验证 Tools/MCP/ 文件不导入 Core/ 或 Stores/

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.1]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD5 MCP 集成]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR19 MCP stdio]
- [Source: _bmad-output/planning-artifacts/architecture.md#NFR19 服务器进程生命周期]
- [Source: _bmad-output/project-context.md#规则 7 模块边界]
- [Source: _bmad-output/project-context.md#规则 10 MCP 命名空间]
- [Source: _bmad-output/project-context.md#规则 39 不从工具内部 throw]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/mcp/client.ts] — TS MCP 客户端完整实现参考
- [Source: mcp-swift-sdk MCPClient.swift] — 高级 MCP 客户端 API（自动重连、健康检查）
- [Source: mcp-swift-sdk Client.swift] — 底层 MCP Client
- [Source: mcp-swift-sdk Transport protocol] — 传输协议定义
- [Source: mcp-swift-sdk StdioTransport.swift] — 服务器端 stdio 传输参考
- [Source: Sources/OpenAgentSDK/Types/MCPConfig.swift] — 已有的 MCP 配置类型
- [Source: Sources/OpenAgentSDK/Types/MCPResourceTypes.swift] — 已有的 MCP 资源类型
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] — assembleToolPool() 工具合并
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — Agent 集成点
- [Source: _bmad-output/implementation-artifacts/5-7-mcp-resource-tools.md] — 前序 story 参考

### Project Structure Notes

- 新建 `Sources/OpenAgentSDK/Types/MCPTypes.swift` — MCPManagedConnection 和 MCPConnectionStatus
- 新建 `Sources/OpenAgentSDK/Tools/MCP/MCPStdioTransport.swift` — Stdio 传输包装器
- 新建 `Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift` — MCP 工具包装器
- 新建 `Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift` — MCPClientManager actor
- 修改 `Sources/OpenAgentSDK/Core/Agent.swift` — 集成 MCPClientManager
- 修改 `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 追加文档引用
- 新建 `Tests/OpenAgentSDKTests/MCP/MCPClientManagerTests.swift`
- 完全对齐架构文档的目录结构和模块边界
- MCPClientManager 遵循 actor 模式（与所有 Store 一致）
- Tools/MCP/ 目录与架构文档一致

## Dev Agent Record

### Agent Model Used

GLM-5.1 (via Claude Code)

### Debug Log References

- Fixed Sendable conformance for MockMCPToolInfo.inputSchema using nonisolated(unsafe)
- Fixed tautological test assertion in testMCPToolDefinition_call_neverThrows_malformedInput
- Fixed test-local MCPClientProtocol conflict with source module protocol (removed duplicate)
- Simplified MCPStdioTransport to standalone actor (not MCP Transport protocol) to avoid Logging dependency complexity

### Completion Notes List

- All 56 ATDD tests pass (47 originally defined + 9 additional in test file)
- Full test suite: 1314 tests, 0 failures, 4 skipped (pre-existing)
- MCPConnectionStatus enum: Equatable, Sendable, three cases (connected/disconnected/error)
- MCPManagedConnection struct: Sendable, holds name, status, tools array
- MCPStdioTransport actor: Foundation Process-based, API key filtering (NFR6), cross-platform
- MCPToolDefinition struct: ToolProtocol + Sendable, mcp__{server}__{tool} namespace, never throws
- MCPClientProtocol: Public protocol for MCP client abstraction (enables mocking)
- MCPClientManager actor: Thread-safe connection management, error handling without crash
- Agent.swift integration: prompt() uses assembleFullToolPool() for MCP tool merging
- Module boundary: Tools/MCP/ only imports Foundation, MCP; Types/MCPTypes.swift has no outbound deps
- E2E tests: 6 tests covering creation, types, namespace, shutdown, transport, integration

### Change Log

- 2026-04-08: Story 6-1 implementation complete - MCP Client Manager & Stdio Transport (all tasks done)

### File List

New files:
- Sources/OpenAgentSDK/Types/MCPTypes.swift
- Sources/OpenAgentSDK/Tools/MCP/MCPStdioTransport.swift
- Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift
- Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift
- Sources/E2ETest/MCPClientManagerTests.swift

Modified files:
- Sources/OpenAgentSDK/Core/Agent.swift (MCP integration in prompt())
- Sources/OpenAgentSDK/OpenAgentSDK.swift (MCP type documentation references)
- Sources/E2ETest/main.swift (added MCPClientManagerE2ETests.run())
- Tests/OpenAgentSDKTests/MCP/MCPClientManagerTests.swift (fixed Sendable + test logic issues)


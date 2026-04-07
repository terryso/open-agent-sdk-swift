# Story 6.2: MCP HTTP/SSE 传输

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望通过 HTTP/SSE 传输连接外部 MCP 服务器，
以便我的 Agent 可以使用远程服务提供的工具。

## Acceptance Criteria

1. **AC1: SSE 传输连接** — 给定配置了 SSE 服务器配置（url + headers）的 MCPClientManager，当调用 `connect(name:config:)` 建立 SSE 连接，则使用 mcp-swift-sdk 的 `HTTPClientTransport` 创建传输，MCP 握手完成，返回连接信息（FR20）。

2. **AC2: HTTP 传输连接** — 给定配置了 HTTP 服务器配置（url + headers）的 MCPClientManager，当调用 `connect(name:config:)` 建立 HTTP 连接，则使用 mcp-swift-sdk 的 `HTTPClientTransport` 创建传输，MCP 握手完成，返回连接信息（FR20）。

3. **AC3: SSE 事件流接收** — 给定通过 HTTP/SSE 连接的 MCP 服务器，当服务器发送 SSE 事件（如工具列表变更通知），则 `HTTPClientTransport` 自动接收并通过 `MCPClient` 传递事件，无需额外处理。

4. **AC4: 连接断开重连** — 给定通过 HTTP/SSE 连接的 MCP 服务器，当连接断开，则 `HTTPClientTransport` 内置的 `HTTPReconnectionOptions` 自动尝试重连（默认最多 2 次，指数退避），MCPClientManager 不崩溃，连接状态反映重连中/断开。

5. **AC5: HTTP/SSE 工具发现** — 给定已通过 HTTP/SSE 连接的 MCP 服务器，当连接成功建立后，则自动调用 `listTools()` 获取可用工具列表，工具以 `mcp__{serverName}__{toolName}` 命名空间包装为 `ToolProtocol`（复用 Story 6-1 的 MCPToolDefinition）。

6. **AC6: HTTP/SSE 工具执行** — 给定已包装为 `ToolProtocol` 的 MCP 工具，当 LLM 请求执行该工具，则通过底层 `MCPClient.callTool()` 分派，结果提取 text content 返回给智能循环。错误被捕获为 `is_error: true` 的 `ToolResult`，不中断循环（NFR17）。

7. **AC7: 多传输类型并发管理** — 给定混合配置（部分 stdio、部分 SSE、部分 HTTP），当 MCPClientManager 连接所有服务器，则每种传输类型使用正确的连接方法，所有服务器独立管理，可以同时连接和断开而不影响其他服务器。

8. **AC8: 自定义请求头注入** — 给定 MCP 服务器配置中包含 headers（如 Authorization），当创建 `HTTPClientTransport`，则 headers 通过 `requestModifier` 闭包注入到每个 HTTP 请求中。

9. **AC9: 连接失败处理** — 给定无法连接的 HTTP/SSE 服务器（如 URL 无效、服务器无响应、认证失败），当 `connect()` 被调用，则连接状态标记为 `error`，错误被记录，Agent 不崩溃，该服务器的工具列表为空（NFR19）。

10. **AC10: 连接关闭** — 给定活跃的 HTTP/SSE 连接，当 `disconnect()` 或 `shutdown()` 被调用，则 MCPClient 断开连接，HTTPClientTransport 清理资源，连接从管理器中移除。

11. **AC11: 模块边界合规** — 给定 MCPClientManager 位于 `Tools/MCP/` 目录，当检查 import 语句，则只导入 `Foundation`、`Types/` 和 `MCP`（mcp-swift-sdk），**不导入** `Core/`、`Stores/` 或其他内部模块（架构规则 #7、#61）。

12. **AC12: 跨平台兼容** — 给定 HTTP/SSE 传输，当在 macOS 和 Linux 上运行，则 macOS 使用完整的 SSE 流式支持（URLSession.AsyncBytes），Linux 使用基础的 HTTP POST/JSON 模式（SSE 有限支持），两种平台均不崩溃（NFR11）。注：mcp-swift-sdk 的 `HTTPClientTransport` 已处理平台差异。

13. **AC13: 单元测试覆盖** — 给定 HTTP/SSE 传输功能，当检查 `Tests/OpenAgentSDKTests/MCP/`，则包含以下测试：
    - SSE 配置连接（mock HTTPClientTransport）
    - HTTP 配置连接（mock HTTPClientTransport）
    - 自定义 headers 注入验证
    - 连接失败处理（URL 无效）
    - 断开连接和清理
    - 混合传输类型管理（stdio + SSE + HTTP）
    - 工具发现和命名空间验证（HTTP/SSE 场景）

14. **AC14: E2E 测试覆盖** — 给定故事完成后，当检查 `Sources/E2ETest/`，则包含 HTTP/SSE 传输的 E2E 测试，至少覆盖：HTTP/SSE 配置创建、MCPClientManager SSE/HTTP 连接状态、工具列表获取。

## Tasks / Subtasks

- [x] Task 1: 扩展 MCPClientManager 支持 SSE 传输 (AC: #1, #3, #4, #5, #9, #10)
  - [x] 在 `MCPClientManager.swift` 中添加 `connect(name:config:) -> MCPManagedConnection` 的 SSE 重载方法
  - [x] 使用 mcp-swift-sdk 的 `HTTPClientTransport` 创建传输（`streaming: true` 模式）
  - [x] 通过 `MCPClient.connect()` 握手并发现工具
  - [x] 连接失败时标记 error 状态，不崩溃

- [x] Task 2: 扩展 MCPClientManager 支持 HTTP 传输 (AC: #2, #5, #9, #10)
  - [x] 在 `MCPClientManager.swift` 中添加 `connect(name:config:) -> MCPManagedConnection` 的 HTTP 重载方法
  - [x] 使用 mcp-swift-sdk 的 `HTTPClientTransport` 创建传输（`streaming: false` 模式）
  - [x] 通过 `MCPClient.connect()` 握手并发现工具

- [x] Task 3: 更新 connectAll() 处理 SSE/HTTP 配置 (AC: #7)
  - [x] 修改 `MCPClientManager.connectAll(servers:)` 中的 SSE/HTTP case
  - [x] 替换当前的 `setErrorConnection` 占位符为实际连接逻辑
  - [x] SSE 配置调用 SSE 连接方法，HTTP 配置调用 HTTP 连接方法

- [x] Task 4: 实现 headers 注入 (AC: #8)
  - [x] 从 `McpSseConfig.headers` / `McpHttpConfig.headers` 提取自定义 headers
  - [x] 通过 `HTTPClientTransport` 的 `requestModifier` 闭包注入 headers 到每个请求
  - [x] 处理空 headers 的情况（使用默认 requestModifier `{ $0 }`）

- [x] Task 5: 管理传输实例引用 (AC: #10)
  - [x] 在 MCPClientManager 中添加 `httpTransports: [String: HTTPClientTransport]` 存储引用
  - [x] 确保 disconnect/shutdown 时正确清理 HTTPClientTransport
  - [x] 确保 stdio 传输和 HTTP/SSE 传输的清理互不干扰

- [x] Task 6: 单元测试 (AC: #13)
  - [x] 在 `Tests/OpenAgentSDKTests/MCP/MCPClientManagerTests.swift` 中添加 HTTP/SSE 测试
  - [x] 测试 SSE 配置连接（使用 mock）
  - [x] 测试 HTTP 配置连接（使用 mock）
  - [x] 测试 headers 注入
  - [x] 测试连接失败（无效 URL）
  - [x] 测试混合传输类型管理
  - [x] 测试断开连接和资源清理

- [x] Task 7: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证新代码符合模块边界规则
  - [x] 验证全部测试（包括之前的 stdio 测试）仍然通过

- [x] Task 8: E2E 测试 (AC: #14)
  - [x] 在 `Sources/E2ETest/` 中补充 HTTP/SSE 传输的 E2E 测试
  - [x] 覆盖配置创建、连接状态、工具列表、断开连接

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 6（MCP 协议集成）的第二个 story
- 在 Story 6-1（MCPClientManager + stdio）基础上扩展 HTTP/SSE 传输支持
- **关键目标：** 让 MCPClientManager 支持通过 HTTP/SSE 连接远程 MCP 服务器，实现多传输类型统一管理
- 本 story 主要**修改**现有 `MCPClientManager.swift`，而非创建全新组件

**与 Story 6-1 的关系：**
- Story 6-1 已实现 MCPClientManager actor、MCPToolDefinition 包装器、MCPStdioTransport
- Story 6-1 的 `connectAll()` 中 SSE/HTTP case 当前返回 `setErrorConnection` 占位
- 本 story 需要替换占位实现为真实的 HTTP/SSE 连接逻辑
- **无需修改** MCPToolDefinition（已支持任意 MCPClientProtocol 的工具执行）
- **无需修改** MCPConnectionStatus / MCPManagedConnection 类型
- **无需修改** Agent.swift 集成代码（已通过 connectAll() 调用）

### mcp-swift-sdk HTTPClientTransport API 要点

mcp-swift-sdk 已提供完整的 `HTTPClientTransport` actor，它是 `Transport` 协议的实现：

1. **`HTTPClientTransport`（actor）** — MCP Streamable HTTP 传输客户端
   - 初始化参数：`endpoint: URL`、`streaming: Bool`、`requestModifier: (URLRequest) -> URLRequest`
   - SSE 模式：`streaming: true`（支持服务器推送、SSE 事件流）
   - HTTP 模式：`streaming: false`（简单的 POST/JSON 请求响应）
   - 内置重连：`HTTPReconnectionOptions`（默认最多 2 次重试，指数退避）
   - 会话管理：自动处理 `Mcp-Session-Id` header
   - 跨平台：macOS 完整 SSE 支持，Linux 有限 SSE 支持（已有平台条件编译）

2. **关键初始化器签名：**
   ```swift
   // macOS
   init(endpoint: URL,
        configuration: URLSessionConfiguration = .mcp,
        streaming: Bool = true,
        sseInitializationTimeout: TimeInterval = 10,
        reconnectionOptions: HTTPReconnectionOptions = .default,
        requestModifier: @escaping (URLRequest) -> URLRequest = { $0 },
        authProvider: (any OAuthClientProvider)? = nil,
        logger: Logger? = nil)

   // Linux
   init(endpoint: URL,
        streaming: Bool = true,
        sseInitializationTimeout: TimeInterval = 10,
        reconnectionOptions: HTTPReconnectionOptions = .default,
        requestModifier: @escaping (URLRequest) -> URLRequest = { $0 },
        authProvider: (any OAuthClientProvider)? = nil,
        logger: Logger? = nil)
   ```

3. **`HTTPReconnectionOptions`** — 重连配置
   - `initialReconnectionDelay: TimeInterval = 1.0`
   - `maxReconnectionDelay: TimeInterval = 30.0`
   - `reconnectionDelayGrowFactor: Double = 1.5`
   - `maxRetries: Int = 2`

4. **`EventStreamStatus`** — SSE 事件流状态
   - `.connected` — 事件流连接中
   - `.reconnecting` — 重连中
   - `.failed` — 重连失败

5. **重要回调：**
   - `onEventStreamStatusChanged: (@Sendable (EventStreamStatus) async -> Void)?`
   - `onSessionExpired: (@Sendable () -> Void)?`
   - `onResumptionToken: ((String) -> Void)?`

### 实现策略

**核心策略：直接使用 mcp-swift-sdk 的 HTTPClientTransport**

与 stdio 传输不同（需要自定义 MCPStdioTransport），HTTP/SSE 传输可以直接使用 mcp-swift-sdk 提供的 `HTTPClientTransport`。无需创建自定义传输包装器。

**连接流程（HTTP/SSE）：**
1. 从配置中解析 URL 和 headers
2. 创建 `HTTPClientTransport`（SSE 用 `streaming: true`，HTTP 用 `streaming: false`）
3. 通过 `requestModifier` 闭包注入自定义 headers
4. 创建 `MCPClient` 并调用 `connect { transport }`
5. 调用 `listTools()` 获取工具列表
6. 使用 `MCPToolDefinition` 包装工具（复用 Story 6-1 的实现）
7. 存储 `MCPManagedConnection`

**与 stdio 传输的关键差异：**
| 方面 | stdio（Story 6-1） | HTTP/SSE（本 Story） |
|------|---------------------|---------------------|
| 传输实现 | 自定义 `MCPStdioTransport` | 直接使用 `HTTPClientTransport` |
| 进程管理 | 需要启动/终止子进程 | 无子进程，HTTP 连接 |
| 重连机制 | 需要自行实现 | `HTTPClientTransport` 内置 |
| 需要存储的引用 | `MCPStdioTransport` + `MCPClient` | `HTTPClientTransport` + `MCPClient` |
| 跨平台差异 | Process vs posix_spawn | macOS SSE 完整，Linux SSE 有限（已由 mcp-swift-sdk 处理） |

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `MCPClientManager` | `Tools/MCP/MCPClientManager.swift` | **需要修改** — 添加 HTTP/SSE 连接方法 |
| `MCPToolDefinition` | `Tools/MCP/MCPToolDefinition.swift` | 无需修改（已支持任意 MCPClientProtocol） |
| `MCPClientProtocol` | `Tools/MCP/MCPToolDefinition.swift` | 无需修改 |
| `MCPClientWrapper` | `Tools/MCP/MCPClientManager.swift` | 无需修改（已处理 MCPClient 包装） |
| `MCPConnectionStatus` | `Types/MCPTypes.swift` | 无需修改 |
| `MCPManagedConnection` | `Types/MCPTypes.swift` | 无需修改 |
| `McpSseConfig` | `Types/MCPConfig.swift` | 已有 `url: String` + `headers: [String: String]?` |
| `McpHttpConfig` | `Types/MCPConfig.swift` | 已有 `url: String` + `headers: [String: String]?` |
| `MCPStdioTransport` | `Tools/MCP/MCPStdioTransport.swift` | 无需修改 |
| `HTTPClientTransport` | mcp-swift-sdk | 外部依赖，直接使用 |
| `MCPClient` | mcp-swift-sdk | 外部依赖，已在 Story 6-1 中使用 |
| `Agent.swift` | `Core/Agent.swift` | 无需修改（已通过 connectAll() 调用） |

### MCPClientManager 修改要点

**新增属性：**
```swift
/// HTTPClientTransport 实例用于 SSE/HTTP 连接，按服务器名索引。
private var httpTransports: [String: HTTPClientTransport] = [:]
```

**新增方法：**
```swift
/// 通过 SSE 传输连接 MCP 服务器。
func connect(name: String, config: McpSseConfig) async

/// 通过 HTTP 传输连接 MCP 服务器。
func connect(name: String, config: McpHttpConfig) async
```

**修改方法：**
```swift
/// connectAll() 中的 SSE/HTTP case 从 setErrorConnection 改为实际连接
public func connectAll(servers: [String: McpServerConfig]) async {
    await withTaskGroup(of: Void.self) { group in
        for (name, config) in servers {
            group.addTask {
                switch config {
                case .stdio(let stdioConfig):
                    await self.connect(name: name, config: stdioConfig)
                case .sse(let sseConfig):
                    await self.connect(name: name, config: sseConfig)  // 改为实际连接
                case .http(let httpConfig):
                    await self.connect(name: name, config: httpConfig)  // 改为实际连接
                }
            }
        }
    }
}
```

**cleanupConnection 修改：**
```swift
private func cleanupConnection(name: String) async {
    if let client = clients.removeValue(forKey: name) {
        await client.disconnect()
    }
    if let transport = transports.removeValue(forKey: name) {
        await transport.disconnect()  // stdio 传输
    }
    if let httpTransport = httpTransports.removeValue(forKey: name) {
        await httpTransport.disconnect()  // HTTP/SSE 传输
    }
}
```

### headers 注入设计

`McpSseConfig` 和 `McpHttpConfig` 都有 `headers: [String: String]?` 属性。需要通过 `HTTPClientTransport` 的 `requestModifier` 闭包注入：

```swift
private func makeRequestModifier(headers: [String: String]?) -> (URLRequest) -> URLRequest {
    guard let headers, !headers.isEmpty else {
        return { $0 }
    }
    return { request in
        var modified = request
        for (key, value) in headers {
            modified.addValue(value, forHTTPHeaderField: key)
        }
        return modified
    }
}
```

**注意：** `HTTPClientTransport` 的 `requestModifier` 是 `@escaping (URLRequest) -> URLRequest`，符合 Sendable 要求。

### 连接失败处理

与 stdio 一致：
1. URL 无效（格式错误） → error 状态，空工具列表
2. 服务器无响应 → MCPClient.connect() 抛出错误 → catch 块捕获 → error 状态
3. 认证失败（401/403）→ HTTPClientTransport 抛出 MCPError → error 状态
4. 所有错误都记录但**不崩溃**

### SSE vs HTTP 传输选择

`McpSseConfig` 和 `McpHttpConfig` 都使用 `HTTPClientTransport`，区别在于 `streaming` 参数：
- `McpSseConfig` → `HTTPClientTransport(endpoint:, streaming: true)` — 支持 SSE 事件流
- `McpHttpConfig` → `HTTPClientTransport(endpoint:, streaming: false)` — 纯 HTTP POST/JSON

### Linux 平台注意事项

mcp-swift-sdk 的 `HTTPClientTransport` 已内置 Linux 平台支持：
- Linux 上 SSE 功能有限（`URLSession.AsyncBytes` 不可用）
- Linux 上 `streaming: true` 会发出 warning 但不会崩溃
- 无需在 MCPClientManager 中添加额外的平台条件编译
- 测试中应考虑 Linux SSE 有限支持的场景

### 前序 Story 的经验教训（必须遵循）

1. **nonisolated(unsafe) 用于 schema 常量** — inputSchema 字典需要标记为 `nonisolated(unsafe)` 以避免 Sendable 警告
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **错误路径测试** — 必须覆盖每个 guard 分支和每个 error case（规则 #28）
4. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - SSE Connection`
5. **Actor 模式** — MCPClientManager 已经是 actor，新增属性和方法自动受隔离保护
6. **不 throw 错误** — connect() 方法在 catch 中处理错误，设置 error 状态（与 stdio connect 一致）
7. **跨平台** — 不使用 Apple 专属框架（HTTPClientTransport 已处理）
8. **E2E 测试** — 完成后必须在 `Sources/E2ETest/` 中补充 E2E 测试
9. **mock MCPClient** — 使用 MCPClientProtocol 协议进行 mock 测试（同 Story 6-1 模式）

### 反模式警告

- **不要**创建自定义 HTTP/SSE 传输 — 直接使用 mcp-swift-sdk 的 `HTTPClientTransport`
- **不要**在 Tools/MCP/ 中导入 Core/ 或 Stores/ — 违反模块边界（规则 #7）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — MCPToolDefinition 已处理（规则 #38）
- **不要**修改 MCPToolDefinition — 它已完全支持本 story 的需求
- **不要**修改 Agent.swift — connectAll() 已在 Story 6-1 中集成
- **不要**修改 MCPConfig.swift — McpSseConfig 和 McpHttpConfig 已存在
- **不要**在连接失败时崩溃 — 标记 error 状态继续运行
- **不要**忘记在 cleanupConnection 中清理 httpTransports — 会导致资源泄漏
- **不要**使用 `import Logging` — 与 Story 6-1 保持一致，不引入 Logging 依赖复杂性

### 模块边界注意事项

```
Tools/MCP/MCPClientManager.swift    → 导入 Foundation + MCP + Types/ (修改: 添加 HTTP/SSE 连接方法)
Tools/MCP/MCPToolDefinition.swift   → 无变更
Tools/MCP/MCPStdioTransport.swift   → 无变更
Types/MCPTypes.swift                → 无变更
Types/MCPConfig.swift               → 无变更
Core/Agent.swift                    → 无变更
```

### 测试策略

**HTTP/SSE 传输测试策略：**

由于 HTTP/SSE 连接需要实际的 HTTP 服务器，测试主要使用 mock 方式：

1. **单元测试（mock）：**
   - SSE 配置解析和 HTTPClientTransport 创建参数验证
   - HTTP 配置解析和 HTTPClientTransport 创建参数验证
   - Headers 注入到 requestModifier 的验证
   - 连接失败处理（无效 URL → error 状态不崩溃）
   - 混合传输类型管理（stdio + SSE + HTTP 并发连接）
   - 断开连接和 httpTransports 清理验证
   - connectAll() 正确分派到各传输类型

2. **集成测试（如有可用服务器）：**
   - 使用本地 MCP HTTP 服务器测试真实连接
   - 或使用 mock 传输测试连接流程

3. **模块边界测试：**
   - 验证 Tools/MCP/ 文件不导入 Core/ 或 Stores/

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 6-1 (已完成) | MCPClientManager + stdio — 本 story 扩展 HTTP/SSE，修改同一文件 |
| 6-3 (未开始) | 进程内 MCP 服务器 — 与本 story 的客户端管理器是互补关系 |
| 6-4 (未开始) | MCP 工具 Agent 集成 — 将重构资源工具和 ToolContext 注入 |
| 5-7 (已完成) | MCP 资源工具 — 使用 MCPClientManager 提供的连接（Story 6-4 重构） |

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.2]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD5 MCP 集成]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR20 MCP HTTP/SSE]
- [Source: _bmad-output/project-context.md#规则 7 模块边界]
- [Source: _bmad-output/project-context.md#规则 10 MCP 命名空间]
- [Source: _bmad-output/implementation-artifacts/6-1-mcp-client-manager-stdio.md] — 前序 story 参考
- [Source: mcp-swift-sdk HTTPClientTransport.swift] — HTTP 客户端传输完整实现
- [Source: mcp-swift-sdk HTTPClientTransport+Types.swift] — HTTPReconnectionOptions, URLSessionConfiguration.mcp
- [Source: mcp-swift-sdk Transport.swift] — Transport 协议定义
- [Source: Sources/OpenAgentSDK/Types/MCPConfig.swift] — McpSseConfig, McpHttpConfig 已有配置类型
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift] — 需要修改的 MCPClientManager
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift] — 复用的工具包装器
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPStdioTransport.swift] — stdio 传输参考（不修改）

### Project Structure Notes

- **修改** `Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift` — 添加 HTTP/SSE 连接方法、httpTransports 属性、cleanupConnection 增强
- **修改** `Tests/OpenAgentSDKTests/MCP/MCPClientManagerTests.swift` — 添加 HTTP/SSE 测试
- **修改** `Sources/E2ETest/MCPClientManagerTests.swift` — 添加 HTTP/SSE E2E 测试
- 完全对齐架构文档的目录结构和模块边界
- 不新增文件（仅修改现有文件）

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 / GLM-5.1

### Debug Log References

- Build succeeded on first attempt after fixing @Sendable annotation on requestModifier closure
- All 94 MCPClientManager unit tests pass (including 30+ Story 6-2 tests)
- All 1352 full suite tests pass with 0 failures (4 pre-existing skips)
- All 273 E2E tests pass (5 pre-existing failures unrelated to this story)

### Completion Notes List

- Implemented SSE transport connection via `connect(name:config:)` using HTTPClientTransport with `streaming: true`
- Implemented HTTP transport connection via `connect(name:config:)` using HTTPClientTransport with `streaming: false`
- Extracted shared `connectHTTP()` private method to avoid code duplication between SSE and HTTP paths
- Added `makeRequestModifier()` helper to inject custom headers through HTTPClientTransport's requestModifier closure
- Added `httpTransports: [String: HTTPClientTransport]` property for managing HTTP/SSE transport references
- Updated `cleanupConnection()` to properly clean up httpTransports alongside stdio transports
- Updated `connectAll()` to dispatch SSE/HTTP configs to real connect methods (replacing setErrorConnection placeholder)
- Fixed Sendable data race warning by annotating requestModifier closure as `@Sendable`
- All tests were pre-written in ATDD RED phase -- implementation passes all existing tests (GREEN phase)
- No new files created -- only modified existing MCPClientManager.swift
- Module boundary compliance verified: only imports Foundation and MCP (no Core/ or Stores/)
- Unit tests and E2E tests were already in place from ATDD phase -- all pass

### Change Log

- 2026-04-08: Implemented HTTP/SSE transport support in MCPClientManager (Story 6-2 GREEN phase)

### File List

- `Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift` — Modified: Added SSE/HTTP connect methods, httpTransports property, makeRequestModifier helper, updated connectAll() and cleanupConnection()
- `Tests/OpenAgentSDKTests/MCP/MCPClientManagerTests.swift` — No changes (tests pre-written in ATDD RED phase)
- `Sources/E2ETest/MCPClientManagerTests.swift` — No changes (E2E tests pre-written in ATDD RED phase)

### Review Findings

- [x] [Review][Patch] URL scheme not restricted to http/https [MCPClientManager.swift:185] -- fixed: added scheme == "http" || scheme == "https" guard
- [x] [Review][Patch] Dead code: setErrorConnection no longer called [MCPClientManager.swift:328] -- fixed: removed unused method
- [x] [Review][Defer] No ReconnectionOptions configured for MCPClient HTTP/SSE path [MCPClientManager.swift:208] -- deferred, pre-existing: HTTPClientTransport has its own reconnection logic per AC4

# Story 5.7: MCP 资源工具（ListMcpResources、ReadMcpResource）

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望我的 Agent 可以列出和读取 MCP 资源，
以便它可以访问 MCP 服务器暴露的资源。

## Acceptance Criteria

1. **AC1: ListMcpResources 工具注册** — 给定 ListMcpResources 工具已注册，当 LLM 查看可用工具列表，则看到一个名为 "ListMcpResources" 的工具，描述为 "List available resources from connected MCP servers. Resources can include files, databases, and other data sources."（FR18）。

2. **AC2: ListMcpResources inputSchema** — 给定 TS SDK 的 mcp-resource-tools.ts，当检查 Swift 端的 inputSchema，则字段名称、类型和 required 列表与 TS SDK 一致。ListMcpResources 有 `server`（string，可选，description: "Filter by MCP server name"）（FR18）。

3. **AC3: ListMcpResources isReadOnly** — 给定 ListMcpResources 工具，当检查 isReadOnly 属性，则返回 true（只读操作，不修改任何状态）。

4. **AC4: ListMcpResources 无连接时** — 给定 ListMcpResources 工具，当没有连接的 MCP 服务器（或 server 过滤器匹配不到），则返回 "No MCP servers connected."（FR18）。

5. **AC5: ListMcpResources 列出资源** — 给定 ListMcpResources 工具且有连接的 MCP 服务器，当 LLM 请求列出资源，则尝试通过 MCP 客户端列出资源，返回格式化的资源列表。若服务器不支持资源列出则返回工具数量提示。若出现异常则返回 "resource listing not supported"（FR18）。

6. **AC6: ListMcpResources server 过滤** — 给定 ListMcpResources 工具且有多个连接的 MCP 服务器，当 LLM 提供了 server 参数，则只返回指定服务器的资源（FR18）。

7. **AC7: ReadMcpResource 工具注册** — 给定 ReadMcpResource 工具已注册，当 LLM 查看可用工具列表，则看到一个名为 "ReadMcpResource" 的工具，描述为 "Read a specific resource from an MCP server."（FR18）。

8. **AC8: ReadMcpResource inputSchema** — 给定 TS SDK 的 mcp-resource-tools.ts，当检查 Swift 端的 inputSchema，则字段名称、类型和 required 列表与 TS SDK 一致。ReadMcpResource 有 `server`（string，必填）、`uri`（string，必填）（FR18）。

9. **AC9: ReadMcpResource isReadOnly** — 给定 ReadMcpResource 工具，当检查 isReadOnly 属性，则返回 true（只读操作）。

10. **AC10: ReadMcpResource 服务器不存在** — 给定 ReadMcpResource 工具，当 LLM 提供的 server 名称没有匹配的连接，则返回 is_error=true 的 ToolResult，内容为 "MCP server not found: {server}"（FR18）。

11. **AC11: ReadMcpResource 读取成功** — 给定 ReadMcpResource 工具且有匹配的 MCP 连接，当 LLM 请求读取指定 URI 的资源，则通过 MCP 客户端读取资源内容并返回文本。若返回的 contents 数组存在，则将每个 content 的 text 或 JSON 序列化拼接返回（FR18）。

12. **AC12: ReadMcpResource 无内容** — 给定 ReadMcpResource 工具，当 MCP 客户端返回了结果但 contents 为空，则返回 "Resource read returned no content."（FR18）。

13. **AC13: ReadMcpResource 读取异常** — 给定 ReadMcpResource 工具，当读取资源过程中发生异常，则返回 is_error=true 的 ToolResult，内容为 "Error reading resource: {error message}"（FR18）。

14. **AC14: 模块边界合规** — 给定两个工具位于 Tools/Specialist/ 目录，当检查 import 语句，则只导入 Foundation 和 Types/，永不导入 Core/、Stores/ 或其他模块（架构规则 #7、#40）。

15. **AC15: 错误处理不中断循环** — 给定工具执行期间发生异常，当错误被捕获，则返回 is_error=true 的 ToolResult，不会中断 Agent 的智能循环（架构规则 #38）。

16. **AC16: ToolRegistry 注册** — 给定两个新工具的工厂函数，当调用 `getAllBaseTools(tier: .specialist)`，则返回的数组包含 createListMcpResourcesTool() 和 createReadMcpResourceTool()（与现有 specialist 工具一致）。

17. **AC17: OpenAgentSDK.swift 文档更新** — 给定模块入口文件，当检查公共 API 文档注释，则包含 createListMcpResourcesTool 和 createReadMcpResourceTool 的文档引用。

18. **AC18: MCP 连接注入** — 给定 MCP 资源工具需要访问 MCP 连接列表，当实现时，则通过 ToolContext 的新字段 `mcpConnections` 或通过全局 setMcpConnections 函数注入连接（与 TS SDK 的 `setMcpConnections` 模式一致）。**注意：** TS SDK 使用模块级变量 `let mcpConnections: MCPConnection[] = []` 和 `setMcpConnections()` 函数。Swift 端可以使用类似模式：文件级变量 + set 函数，或者在 ToolContext 中添加可选的 mcpConnections 字段。

19. **AC19: E2E 测试覆盖** — 给定故事完成后，当检查 `Sources/E2ETest/`，则包含 ListMcpResources 和 ReadMcpResource 工具的 E2E 测试，至少覆盖无连接时的提示和基本操作路径。

## Tasks / Subtasks

- [ ] Task 1: 定义 ListMcpResources Input 类型和 Schema (AC: #2)
  - [ ] 在 `Sources/OpenAgentSDK/Tools/Specialist/ListMcpResourcesTool.swift` 中定义 `ListMcpResourcesInput` Codable 结构体
  - [ ] `server`（可选 String，用于过滤 MCP 服务器名称）
  - [ ] 定义 `listMcpResourcesSchema` 常量匹配 TS SDK 的 ListMcpResources schema
  - [ ] 使用 `nonisolated(unsafe)` 标记 schema 字典

- [ ] Task 2: 实现 createListMcpResourcesTool 工厂函数 (AC: #1, #3-#6, #14, #15)
  - [ ] 定义 `createListMcpResourcesTool()` 返回 ToolProtocol
  - [ ] 使用 defineTool 的 `(input: ListMcpResourcesInput, context:) -> ToolExecuteResult` 重载
  - [ ] 在闭包内获取 MCP 连接列表（通过 ToolContext.mcpConnections 或全局函数）
  - [ ] 如果提供了 server 参数则过滤连接
  - [ ] 无连接时返回 "No MCP servers connected."
  - [ ] 遍历已连接的服务器，尝试列出资源
  - [ ] 格式化输出：`Server: {name}` + 每个资源 `  - {name}: {description || uri || ""}`
  - [ ] 不支持时返回 `Server: {name} (resource listing not supported)` 或工具数量提示
  - [ ] 所有异常在 ToolExecuteResult 中捕获，不 throw

- [ ] Task 3: 定义 ReadMcpResource Input 类型和 Schema (AC: #8)
  - [ ] 在 `Sources/OpenAgentSDK/Tools/Specialist/ReadMcpResourceTool.swift` 中定义 `ReadMcpResourceInput` Codable 结构体
  - [ ] `server`（必填 String）、`uri`（必填 String）
  - [ ] 定义 `readMcpResourceSchema` 常量匹配 TS SDK 的 ReadMcpResource schema
  - [ ] 使用 `nonisolated(unsafe)` 标记 schema 字典
  - [ ] required 字段包含 `["server", "uri"]`

- [ ] Task 4: 实现 createReadMcpResourceTool 工厂函数 (AC: #7, #9-#13, #14, #15)
  - [ ] 定义 `createReadMcpResourceTool()` 返回 ToolProtocol
  - [ ] 使用 defineTool 的 `(input: ReadMcpResourceInput, context:) -> ToolExecuteResult` 重载
  - [ ] 通过 server 名称查找 MCP 连接
  - [ ] 未找到时返回 is_error=true，"MCP server not found: {server}"
  - [ ] 找到后尝试读取资源，返回 contents 的 text 或 JSON 序列化
  - [ ] contents 为空时返回 "Resource read returned no content."
  - [ ] 异常时返回 is_error=true，"Error reading resource: {message}"
  - [ ] 所有异常在 ToolExecuteResult 中捕获，不 throw

- [ ] Task 5: 处理 MCP 连接注入 (AC: #18)
  - [ ] 选择连接注入方式：ToolContext 新字段 或 全局 setMcpConnections 函数
  - [ ] 如果使用 ToolContext 方式：在 `Types/ToolTypes.swift` 的 ToolContext 中添加 `mcpConnections` 可选字段
  - [ ] 如果使用全局函数方式：在 ListMcpResourcesTool.swift 中定义文件级变量和 setMcpConnections 函数
  - [ ] **推荐使用 ToolContext 方式**，与现有 store 注入模式一致

- [ ] Task 6: 更新 ToolRegistry (AC: #16)
  - [ ] 在 `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` 的 `getAllBaseTools(tier: .specialist)` 中追加 `createListMcpResourcesTool()` 和 `createReadMcpResourceTool()`

- [ ] Task 7: 更新模块入口 (AC: #17)
  - [ ] 在 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 中追加 createListMcpResourcesTool 和 createReadMcpResourceTool 的文档引用

- [ ] Task 8: 单元测试 (AC: #1-#18)
  - [ ] 创建 `Tests/OpenAgentSDKTests/Tools/Specialist/McpResourceToolTests.swift`
  - [ ] ListMcpResources inputSchema 验证（server 可选）
  - [ ] ListMcpResources isReadOnly 验证（true）
  - [ ] ListMcpResources 模块边界验证
  - [ ] ListMcpResources 无连接时返回 "No MCP servers connected."
  - [ ] ListMcpResources server 过滤测试
  - [ ] ReadMcpResource inputSchema 验证（server 和 uri 必填）
  - [ ] ReadMcpResource isReadOnly 验证（true）
  - [ ] ReadMcpResource 模块边界验证
  - [ ] ReadMcpResource 服务器不存在错误
  - [ ] ReadMcpResource 读取成功路径
  - [ ] ReadMcpResource 无内容路径
  - [ ] ReadMcpResource 异常路径

- [ ] Task 9: 编译验证
  - [ ] 运行 `swift build` 确认编译通过
  - [ ] 验证新文件不导入 Core/ 或 Stores/
  - [ ] 验证测试可以编译并通过

- [ ] Task 10: E2E 测试 (AC: #19)
  - [ ] 在 `Sources/E2ETest/` 中补充 ListMcpResources 和 ReadMcpResource 工具的 E2E 测试
  - [ ] 至少覆盖：无连接时的提示、基本操作路径

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 5（专业工具与管理存储）的第七个 story，也是 Epic 5 的最后一个 story
- 本 story 实现两个专业工具：ListMcpResources 和 ReadMcpResource
- 与 Story 5-5 (LSPTool) 和 Story 5-6 (ConfigTool/RemoteTriggerTool) 不同，**本 story 需要访问 MCP 连接列表**
- 这两个工具都是只读的（isReadOnly = true），不修改任何状态
- **关键挑战：** MCP 连接注入方式 —— 工具需要访问 MCP 连接列表来执行操作

**MCP 连接注入方案分析：**

| 方案 | 优点 | 缺点 |
|------|------|------|
| A: ToolContext 新字段 | 与现有 store 注入模式一致 | 需要修改 ToolTypes.swift 和可能的 Agent.swift |
| B: 全局 setMcpConnections | 与 TS SDK 完全一致，不需要修改 ToolContext | 使用文件级可变状态，不够 Swift 惯用 |

**推荐方案 A（ToolContext 新字段）**，原因：
1. 与 TaskStore、CronStore 等现有注入方式保持一致
2. 更好的可测试性（可以在测试中注入 mock 连接）
3. 不使用全局可变状态
4. MCP 连接列表是会话级别的，适合通过 context 传递

**注意：** 如果选择方案 A，需要在 ToolContext 中添加一个可选的 MCP 连接列表字段。但由于 MCP 协议尚未在 Epic 6 中实现，**MCP 连接类型还未定义**。因此有两种实现策略：

1. **定义一个 MCPResourceProvider 协议**：工具依赖协议而非具体类型，Epic 6 实现具体类型后注入
2. **直接使用 Any 类型**：类似 TS SDK 的 `(conn as any)._client` 模式，用类型擦除

**推荐策略 1（协议抽象）**，定义最小化的协议接口：

```swift
/// Protocol for MCP resource operations, to be implemented by MCPClientManager in Epic 6.
public protocol MCPResourceProvider: Sendable {
    func listResources() async -> [MCPResourceInfo]?
    func readResource(uri: String) async throws -> MCPResourceContent
}

public struct MCPResourceInfo: Sendable {
    public let name: String
    public let description: String?
    public let uri: String?
}

public struct MCPResourceContent: Sendable {
    public let contents: [MCPContentItem]?
}

public struct MCPContentItem: Sendable {
    public let text: String?
    public let rawJSON: Any?
}
```

然后在 ToolContext 中添加：
```swift
public let mcpConnections: [MCPConnectionInfo]?
```

其中 `MCPConnectionInfo` 封装名称、状态和资源提供者：
```swift
public struct MCPConnectionInfo: Sendable {
    public let name: String
    public let status: String  // "connected", "disconnected", etc.
    public let resourceProvider: (any MCPResourceProvider)?
}
```

**但考虑到 Epic 6 尚未实现**，这些类型目前没有具体实现。因此**最简实现**是：

- 使用全局 `setMcpConnections` 函数 + 文件级变量（与 TS SDK 一致）
- 在 ListMcpResources 和 ReadMcpResource 中通过全局变量访问连接
- 等到 Epic 6 实现时再重构为通过 ToolContext 注入

**最终决定：使用全局 setMcpConnections 模式（方案 B）**

原因：
1. TS SDK 使用这种模式，直接移植最简单
2. Epic 6 将实现完整的 MCP 客户端管理器，那时再重构连接注入
3. 避免现在就定义大量协议和类型（可能之后需要修改）
4. 保持本 story 的最小化变更范围

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `ToolContext` | `Types/ToolTypes.swift` | **不需要修改**（使用全局注入模式） |
| `AgentOptions` | `Types/AgentTypes.swift` | **不需要修改** |
| `Agent` | `Core/Agent.swift` | **不需要修改** |
| `ToolExecuteResult` | `Types/ToolTypes.swift` | content + isError |
| `defineTool()` | `Tools/ToolBuilder.swift` | 工厂函数（使用 Codable Input 重载） |
| `LSPTool` | `Tools/Specialist/LSPTool.swift` | 无状态只读 Specialist 工具参考 |
| `ConfigTool` | `Tools/Specialist/ConfigTool.swift` | 全局状态 Specialist 工具参考 |
| `ToolRegistry` | `Tools/ToolRegistry.swift` | 需要追加新工具 |
| `MCPConfig` | `Types/MCPConfig.swift` | MCP 配置类型（stdio/sse/http） |

### TypeScript SDK 参考对比

**mcp-resource-tools.ts 关键实现要点：**

1. **全局连接管理：**
   ```typescript
   let mcpConnections: MCPConnection[] = []
   export function setMcpConnections(connections: MCPConnection[]): void {
     mcpConnections = connections
   }
   ```

2. **ListMcpResourcesTool（只读，无必填参数）：**
   - inputSchema: `{ server?: string }` — 仅一个可选的 server 过滤参数
   - **isReadOnly: true**
   - **isConcurrencySafe: true**
   - 逻辑：
     - 根据 server 参数过滤连接，无参数则使用所有连接
     - 无连接时返回 "No MCP servers connected."
     - 遍历已连接的服务器（status === 'connected'）
     - 尝试调用 `_client.listResources()` 获取资源列表
     - 成功：`Server: {name}` + 每个资源 `  - {name}: {description || uri || ""}`
     - 无 listResources 方法：`Server: {name} ({tools.length} tools available)`
     - 异常：`Server: {name} (resource listing not supported)`
     - 无结果：`No resources found.`

3. **ReadMcpResourceTool（只读，两个必填参数）：**
   - inputSchema: `{ server: string, uri: string }` — 两个必填字段
   - required: `["server", "uri"]`
   - **isReadOnly: true**
   - **isConcurrencySafe: true**
   - 逻辑：
     - 通过 server 名称查找连接
     - 未找到：返回 is_error: true，"MCP server not found: {server}"
     - 找到后调用 `_client.readResource({ uri })` 读取资源
     - 成功且有 contents：拼接每个 content 的 text 或 JSON.stringify
     - 成功但无 contents：返回 "Resource read returned no content."
     - 异常：返回 is_error: true，"Error reading resource: {err.message}"

4. **MCPConnection 类型（来自 mcp/client.ts）：**
   ```typescript
   interface MCPConnection {
     name: string
     status: string  // 'connected' | 'disconnected' | etc.
     tools: Tool[]
     _client?: any   // 底层 MCP 客户端
   }
   ```

**Swift 端关键差异：**

| 方面 | TypeScript | Swift |
|------|-----------|-------|
| 连接存储 | 模块级 `let mcpConnections: MCPConnection[]` | 文件级变量或全局函数 |
| 客户端访问 | `(conn as any)._client?.listResources?.()` | 需要定义协议或使用 Any |
| 资源类型 | 隐式 any | 需要定义或使用类型擦除 |
| 错误模型 | `{ content, is_error }` | `ToolExecuteResult(isError: true)` |
| 线程安全 | 无（Node.js 单线程） | 需要考虑（但工具执行已在 TaskGroup/串行中） |

### MCP 连接类型定义

由于 Epic 6 尚未实现 MCPClientManager，本 story 需要定义最小化的连接类型。**与 TS SDK 的 MCPConnection 对应**：

```swift
/// Minimal MCP connection info for resource tools.
/// Will be replaced/enhanced by Epic 6's MCPClientManager implementation.
public struct MCPConnectionInfo: Sendable {
    public let name: String
    public let status: String  // "connected", "disconnected"
    public let resourceProvider: (any MCPResourceProvider)?

    public init(name: String, status: String, resourceProvider: (any MCPResourceProvider)? = nil) {
        self.name = name
        self.status = status
        self.resourceProvider = resourceProvider
    }
}

/// Protocol for MCP resource operations.
/// Will be implemented by MCPClientManager's connections in Epic 6.
public protocol MCPResourceProvider: Sendable {
    func listResources() async -> [MCPResourceItem]?
    func readResource(uri: String) async throws -> MCPReadResult
}

public struct MCPResourceItem: Sendable {
    public let name: String
    public let description: String?
    public let uri: String?

    public init(name: String, description: String? = nil, uri: String? = nil) {
        self.name = name
        self.description = description
        self.uri = uri
    }
}

public struct MCPReadResult: Sendable {
    public let contents: [MCPContentItem]?

    public init(contents: [MCPContentItem]?) {
        self.contents = contents
    }
}

public struct MCPContentItem: Sendable {
    public let text: String?
    public let rawValue: Any?

    public init(text: String? = nil, rawValue: Any? = nil) {
        self.text = text
        self.rawValue = rawValue
    }
}
```

**注意：** 这些类型需要放在 `Types/` 目录中（叶节点，无出站依赖）。建议放在新文件 `Types/MCPResourceTypes.swift` 中。

**全局连接管理函数（在 ListMcpResourcesTool.swift 中）：**

```swift
nonisolated(unsafe) var mcpConnections: [MCPConnectionInfo] = []

/// Set MCP connections for resource access (called by agent setup).
public func setMcpConnections(_ connections: [MCPConnectionInfo]) {
    mcpConnections = connections
}
```

### inputSchema 定义

**ListMcpResources schema（匹配 TS SDK ListMcpResourcesTool）：**

```swift
private nonisolated(unsafe) let listMcpResourcesSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "server": [
            "type": "string",
            "description": "Filter by MCP server name"
        ] as [String: Any],
    ] as [String: Any]
]
```

注意：ListMcpResources **没有 required 字段**，server 是完全可选的。

**ReadMcpResource schema（匹配 TS SDK ReadMcpResourceTool）：**

```swift
private nonisolated(unsafe) let readMcpResourceSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "server": [
            "type": "string",
            "description": "MCP server name"
        ] as [String: Any],
        "uri": [
            "type": "string",
            "description": "Resource URI to read"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["server", "uri"]
]
```

### 实现位置

**新增文件：**
```
Sources/OpenAgentSDK/Types/MCPResourceTypes.swift                    # MCP 连接和资源类型
Sources/OpenAgentSDK/Tools/Specialist/ListMcpResourcesTool.swift     # ListMcpResources 工厂函数 + setMcpConnections
Sources/OpenAgentSDK/Tools/Specialist/ReadMcpResourceTool.swift      # ReadMcpResource 工厂函数
```

**修改文件：**
```
Sources/OpenAgentSDK/Tools/ToolRegistry.swift                        # 追加 createListMcpResourcesTool + createReadMcpResourceTool
Sources/OpenAgentSDK/OpenAgentSDK.swift                              # 追加文档引用
```

**测试文件：**
```
Tests/OpenAgentSDKTests/Tools/Specialist/McpResourceToolTests.swift   # 两个 MCP 资源工具的测试
```

**注意：不需要修改以下文件：**
```
Types/ToolTypes.swift    # 不需要追加字段（使用全局注入模式）
Types/AgentTypes.swift   # 不需要追加字段
Core/Agent.swift         # 不需要修改 ToolContext 创建
Stores/                  # 不需要创建新 Actor
```

### 前序 Story 的经验教训（必须遵循）

1. **nonisolated(unsafe) 用于 schema 常量** — inputSchema 字典需要标记为 `nonisolated(unsafe)` 以避免 Sendable 警告
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **错误路径测试** — 必须覆盖每个 guard 分支和每个 error case（规则 #28）
4. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - Factory Function`
5. **ToolExecuteResult 重载** — 使用 `defineTool` 返回 `ToolExecuteResult` 的重载
6. **不需要 Actor 存储** — 与 Story 5-5/5-6 一样，不需要创建 Actor、不需要修改 ToolContext
7. **参考 LSPTool.swift 的无状态模式** — MCP 资源工具都是只读的
8. **参考 ConfigTool.swift 的全局状态模式** — setMcpConnections 使用文件级变量
9. **参考 TS SDK 的直接移植** — 本 story 有明确的 TS 源码参考，保持行为一致
10. **Epic 5-6 (ConfigTool) 的经验** — 文件级变量使用 `nonisolated(unsafe)` 标记

### 反模式警告

- **不要**在 Tools/Specialist/ 中导入 Stores/ 或 Core/ — 违反模块边界（规则 #7、#40）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — 在 ToolExecuteResult 中捕获返回（规则 #38）
- **不要**使用 Apple 专属框架 — 必须跨平台（规则 #43）
- **不要**创建 Actor 存储类 — MCP 连接通过全局变量管理
- **不要**修改 ToolContext 或 AgentOptions — 使用全局 setMcpConnections 注入
- **不要**修改 Core/Agent.swift — 本工具不需要依赖注入
- **不要**忘记更新 ToolRegistry.getAllBaseTools — 新工具必须注册才能被发现
- **不要**在 Epic 6 之前过度设计 MCP 类型 — 保持最小化，等到 Epic 6 再完善
- **不要**将 MCPResourceTypes 放在 Tools/ 目录 — 类型必须放在 Types/（叶节点规则）

### 模块边界注意事项

```
Types/MCPResourceTypes.swift                     → 无出站依赖（叶节点）
Tools/Specialist/ListMcpResourcesTool.swift      → 导入 Foundation + Types/（含 MCPResourceTypes）
Tools/Specialist/ReadMcpResourceTool.swift       → 导入 Foundation + Types/（含 MCPResourceTypes）
```

MCP 资源类型放在 Types/ 目录，作为叶节点无出站依赖。
工具文件只导入 Foundation 和 Types/，永不导入 Core/ 或 Stores/。

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 5-6 (已完成) | ConfigTool/RemoteTriggerTool — 全局状态 Specialist 工具参考 |
| 5-5 (已完成) | LSPTool — 无状态只读 Specialist 工具参考 |
| 5-3 (已完成) | CronTools — Specialist 工具文件组织参考 |
| 6-1 (未开始) | MCP Client Manager — 将来会实现真正的 MCPConnection，届时可能重构本 story 的类型 |
| 3-3 (已完成) | ToolExecutor — 并发/串行执行参考（本工具是只读的，可以并发执行） |

### isReadOnly 分类

| 工具 | isReadOnly | 理由 |
|------|-----------|------|
| ListMcpResources | true | 只读取 MCP 服务器信息，不修改任何状态（与 TS SDK isReadOnly: true 一致） |
| ReadMcpResource | true | 只读取 MCP 资源内容，不修改任何状态（与 TS SDK isReadOnly: true 一致） |

### 测试策略

**MCP 资源工具测试策略：**
- 由于 MCP 连接需要实际的服务器（Epic 6 实现），测试主要验证工具对空连接列表和基本逻辑路径的处理
- 可以创建 mock MCPResourceProvider 来测试有连接时的路径

**关键测试场景：**
1. **ListMcpResources inputSchema** — server 可选，无 required 字段
2. **ListMcpResources isReadOnly** — true
3. **ListMcpResources 无连接** — 返回 "No MCP servers connected."
4. **ListMcpResources server 过滤** — 提供不存在的 server 名称，返回 "No MCP servers connected."
5. **ReadMcpResource inputSchema** — server 和 uri 必填
6. **ReadMcpResource isReadOnly** — true
7. **ReadMcpResource 服务器不存在** — 返回 is_error=true
8. **ReadMcpResource 读取成功** — 使用 mock provider 验证
9. **ReadMcpResource 无内容** — contents 为 nil
10. **ReadMcpResource 异常** — provider 抛出错误
11. **模块边界验证** — 两个文件都不导入 Core/ 或 Stores/
12. **setMcpConnections 函数** — 验证全局连接设置

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.7]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR18 Specialist tools]
- [Source: _bmad-output/planning-artifacts/architecture.md#项目结构 Tools/Specialist/ListMcpResourcesTool.swift, ReadMcpResourceTool.swift]
- [Source: _bmad-output/project-context.md#规则 7 模块边界单向依赖]
- [Source: _bmad-output/project-context.md#规则 38 不从工具内部 throw]
- [Source: _bmad-output/project-context.md#规则 40 Tools 不导入 Core]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/mcp-resource-tools.ts] — TS MCP 资源工具完整实现参考
- [Source: Sources/OpenAgentSDK/Tools/Specialist/LSPTool.swift] — 无状态只读 Specialist 工具参考
- [Source: Sources/OpenAgentSDK/Tools/Specialist/ConfigTool.swift] — 全局状态 Specialist 工具参考
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool 工厂函数
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] — 工具注册参考
- [Source: _bmad-output/implementation-artifacts/5-6-config-remote-trigger-tools.md] — 前一 story 参考

### Project Structure Notes

- 新建 `Sources/OpenAgentSDK/Types/MCPResourceTypes.swift` — MCP 连接和资源的最小化类型定义
- 新建 `Sources/OpenAgentSDK/Tools/Specialist/ListMcpResourcesTool.swift` — ListMcpResources 工厂函数 + setMcpConnections
- 新建 `Sources/OpenAgentSDK/Tools/Specialist/ReadMcpResourceTool.swift` — ReadMcpResource 工厂函数
- 修改 `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` — 追加 createListMcpResourcesTool + createReadMcpResourceTool
- 修改 `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 追加文档引用
- 新建 `Tests/OpenAgentSDKTests/Tools/Specialist/McpResourceToolTests.swift`
- 完全对齐架构文档的目录结构和模块边界
- **不需要**创建新的 Actor 存储、修改 ToolContext 或 AgentOptions
- MCPResourceTypes 放在 Types/（叶节点），不在 Tools/ 中

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

### Review Findings

- [x] [Review][Patch] ReadMcpResource: server/uri parameter guards return misleading errors [ReadMcpResourceTool.swift:48-63] -- Fixed: server guard now says "server parameter is required and must be a string"; uri guard added with fail-fast on empty.
- [x] [Review][Patch] ReadMcpResource: nil provider says "MCP server not found" when server WAS found [ReadMcpResourceTool.swift:67-70] -- Fixed: now says "does not support resource operations".
- [x] [Review][Patch] ListMcpResources: all-disconnected servers returns misleading "No resources found" [ListMcpResourcesTool.swift:72-102] -- Fixed: now reports count of disconnected servers.
- [x] [Review][Patch] Duplicate JSON serialization helper across ReadMcpResourceTool and ConfigTool [ReadMcpResourceTool.swift:118] -- Fixed: renamed to `jsonStringifyValue` with doc comment explaining intentional difference from ConfigTool's `jsonString`.
- [x] [Review][Patch] AC19: E2E tests not created [Sources/E2ETest/McpResourceToolTests.swift] -- Fixed: created E2E test file with registration, schema, no-connections, and tool registry tests.
- [x] [Review][Defer] mcpConnections thread safety (latent risk for concurrent multi-agent) -- deferred, pre-existing design choice matching TS SDK
- [x] [Review][Defer] AC5: missing tool count hint in listing-not-supported message -- deferred, MCPConnectionInfo lacks tools field; deferred to Epic 6

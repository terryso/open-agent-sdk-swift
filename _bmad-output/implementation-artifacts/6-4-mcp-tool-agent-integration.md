# Story 6.4: MCP 工具与 Agent 集成

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望 MCP 工具在 Agent 执行期间与内置工具一起出现，
以便 Agent 无缝使用本地和远程工具。

## Acceptance Criteria

1. **AC1: MCP 工具命名空间集成** — 给定 Agent 同时拥有内置工具和已连接的 MCP 服务器（通过 `AgentOptions.mcpServers` 配置），当 `assembleFullToolPool()` 组装工具池时，则 MCP 工具以 `mcp__{serverName}__{toolName}` 的命名空间包含在工具定义中，与内置工具并列（FR22）。

2. **AC2: 外部 MCP 工具分派** — 给定正在执行的 Agent 有 MCP 工具可用，当 LLM 请求一个外部 MCP 工具（通过 stdio/SSE/HTTP 连接的服务器），则工具通过 `MCPClientManager` → `MCPToolDefinition` → `MCPClientProtocol.callTool()` 分派执行，结果返回给智能循环（FR22）。

3. **AC3: SDK 进程内工具直接注入** — 给定 Agent 配置了 `McpServerConfig.sdk`，当 `assembleFullToolPool()` 处理配置时，则 SDK 工具通过 `SdkToolWrapper` 直接注入到工具池（带命名空间前缀），不经过 MCP 协议，零网络开销。

4. **AC4: 混合配置处理** — 给定 `AgentOptions.mcpServers` 包含多种类型（stdio、sse、http、sdk），当 Agent 组装工具池时，则 SDK 配置被 `processMcpConfigs()` 直接提取工具，外部配置通过 `MCPClientManager.connectAll()` 连接发现工具，所有工具合并到统一池中。

5. **AC5: prompt() 阻塞模式集成** — 给定配置了 MCP 服务器的 Agent，当调用 `agent.prompt()` 时，则 `assembleFullToolPool()` 被调用，MCP 工具合并到工具池，LLM API 调用包含所有工具定义（内置 + MCP），工具执行在智能循环中正确分派，MCP 连接在完成后被清理。

6. **AC6: stream() 流式模式集成** — 给定配置了 MCP 服务器的 Agent，当调用 `agent.stream()` 时，则 MCP 工具合并到流式管道的工具池中，LLM API 流式调用包含所有工具定义，工具执行事件（toolUse、toolResult）通过 AsyncStream 正确发出，MCP 连接在流终止时被清理。

7. **AC7: 工具执行错误隔离** — 给定 MCP 工具执行失败（连接断开、超时、服务器错误），当智能循环处理工具结果时，则错误被捕获为 `ToolResult(isError: true)` 返回给 LLM，智能循环不崩溃，Agent 可以继续其他操作（NFR17）。

8. **AC8: 工具池去重** — 给定 MCP 工具名与内置工具名冲突，当 `assembleToolPool()` 执行时，则使用 Dictionary 去重，后注册的工具覆盖先注册的，确保工具名唯一。

9. **AC9: MCP 连接生命周期** — 给定 Agent 开始执行（prompt/stream），当 MCP 连接建立后，则连接在执行期间保持活跃，执行完成后（无论成功或失败）MCP 连接被 `mcpManager.shutdown()` 清理。

10. **AC10: 单元测试覆盖** — 给定 MCP 工具 Agent 集成功能，当检查 `Tests/OpenAgentSDKTests/MCP/`，则包含以下测试：
    - assembleFullToolPool 合并内置 + MCP 工具
    - processMcpConfigs 分离 SDK 和外部配置
    - SdkToolWrapper 命名空间前缀
    - 混合配置（stdio + sdk）工具池组装
    - MCP 连接错误时工具池仍可用
    - 工具池去重验证

11. **AC11: E2E 测试覆盖** — 给定故事完成后，当检查 `Sources/E2ETest/`，则包含 MCP 工具 Agent 集成的 E2E 测试，至少覆盖：混合配置工具池组装、SDK 工具命名空间、模拟 MCP 工具执行分派、错误隔离。

## Tasks / Subtasks

- [ ] Task 1: 审查和加固 processMcpConfigs (AC: #1, #3, #4)
  - [ ] 审查 `Core/Agent.swift` 中 `processMcpConfigs()` 的现有实现
  - [ ] 验证 `.sdk` 配置通过 `SdkToolWrapper` 正确命名空间化
  - [ ] 验证外部配置正确传递给 `MCPClientManager`
  - [ ] 确认 `assembleFullToolPool()` 中 base + custom + MCP 工具合并逻辑正确
  - [ ] 确认 `assembleToolPool()` 去重逻辑正确处理 MCP 工具

- [ ] Task 2: 审查 prompt() MCP 集成路径 (AC: #5, #7, #9)
  - [ ] 验证 `prompt()` 调用 `assembleFullToolPool()` 获取工具池
  - [ ] 验证 LLM API 调用包含合并后的工具定义（`toApiTools(mcpTools)`）
  - [ ] 验证工具执行分派使用合并后的工具池（`registeredTools = mcpTools`）
  - [ ] 验证 MCP 连接清理在所有退出路径（成功、错误、预算超限）执行
  - [ ] 验证 MCP 工具执行错误被隔离为 `ToolResult(isError: true)`

- [ ] Task 3: 审查 stream() MCP 集成路径 (AC: #6, #7, #9)
  - [ ] 验证 `stream()` 的 MCP 连接逻辑（`processMcpConfigs` + `MCPClientManager`）
  - [ ] 验证流式 LLM API 调用包含 MCP 工具定义
  - [ ] 验证流式工具执行使用 `allToolProtocols`（包含 MCP 工具）
  - [ ] 验证 toolUse 和 toolResult 事件正确发出
  - [ ] 验证流终止时 MCP 连接清理（正常终止和错误终止）

- [ ] Task 4: 单元测试 (AC: #10)
  - [ ] 创建 `Tests/OpenAgentSDKTests/MCP/MCPAgentIntegrationTests.swift`
  - [ ] 测试 `processMcpConfigs` 分离 SDK 和外部配置
  - [ ] 测试 `SdkToolWrapper` 命名空间前缀
  - [ ] 测试混合配置工具池组装
  - [ ] 测试 MCP 连接失败时工具池仍可用（空 MCP 工具）
  - [ ] 测试 `assembleToolPool` 去重包含 MCP 命名空间工具
  - [ ] 测试 `MCPToolDefinition.call()` 错误隔离

- [ ] Task 5: E2E 测试 (AC: #11)
  - [ ] 在 `Sources/E2ETest/MCPClientManagerTests.swift` 中添加集成测试
  - [ ] E2E 测试：SDK + 外部（失败）混合配置 → SDK 工具可用
  - [ ] E2E 测试：完整工具池组装验证（内置 + SDK + 外部）
  - [ ] E2E 测试：MCP 工具执行错误隔离
  - [ ] E2E 测试：多 MCP 服务器工具池合并

- [ ] Task 6: 编译验证
  - [ ] 运行 `swift build` 确认编译通过
  - [ ] 验证所有新代码符合模块边界规则
  - [ ] 验证所有现有测试仍通过
  - [ ] 运行 `swift test` 确认无回归

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 6（MCP 协议集成）的第四个也是最后一个 story
- **集成验证 story** — 大部分基础设施已在 Story 6-1（MCPClientManager + stdio）、6-2（HTTP/SSE）、6-3（InProcessMCPServer）中构建
- **关键目标：** 确保 MCP 工具在 Agent 执行期间与内置工具无缝集成，端到端验证整个 MCP 管道

**已实现的基础设施（无需修改）：**

| 组件 | 位置 | 状态 |
|------|------|------|
| `MCPClientManager` | `Tools/MCP/MCPClientManager.swift` | 已完成（Story 6-1/6-2） |
| `MCPToolDefinition` | `Tools/MCP/MCPToolDefinition.swift` | 已完成（Story 6-1） |
| `InProcessMCPServer` | `Tools/MCP/InProcessMCPServer.swift` | 已完成（Story 6-3） |
| `McpServerConfig.sdk` | `Types/MCPConfig.swift` | 已完成（Story 6-3） |
| `SdkToolWrapper` | `Core/Agent.swift` | 已完成（Story 6-3） |
| `processMcpConfigs()` | `Core/Agent.swift` extension | 已完成（Story 6-3） |
| `assembleFullToolPool()` | `Core/Agent.swift` | 已完成（Story 6-3） |
| `assembleToolPool()` | `Tools/ToolRegistry.swift` | 已完成（Story 3-1） |
| `MCPClientProtocol` | `Tools/MCP/MCPToolDefinition.swift` | 已完成（Story 6-1） |
| `MCPTypes.swift` | `Types/MCPTypes.swift` | 已完成（Story 6-1） |

### 本 story 的核心工作

**本 story 主要是审查、验证和补充测试**，而非大量新代码开发。需要：

1. **代码审查** — 审查 `Agent.swift` 中 prompt() 和 stream() 的 MCP 集成路径，确认无遗漏或 bug
2. **补充测试** — 添加专门的集成测试，验证端到端 MCP 工具集成
3. **修复发现的问题** — 如果审查中发现任何问题，进行修复

### 已有的 MCP 集成管道详解

**prompt() 路径（阻塞模式）：**
```
agent.prompt(text)
  → assembleFullToolPool()
    → processMcpConfigs(mcpServers)
      → .sdk 配置 → SdkToolWrapper 命名空间包装（零开销）
      → 其他配置 → externalServers 字典
    → MCPClientManager().connectAll(externalServers)（外部服务器）
    → assembleToolPool(baseTools + customTools + mcpTools)
  → LLM API 调用包含合并工具定义
  → 工具执行使用合并工具池
  → mcpManager.shutdown() 清理（所有退出路径）
```

**stream() 路径（流式模式）：**
```
agent.stream(text)
  → 内联 MCP 连接逻辑（AsyncStream 闭包内）
    → processMcpConfigs(mcpServers)
    → MCPClientManager().connectAll(externalServers)
    → allToolProtocols = capturedToolProtocols + mcpTools
  → 流式 LLM API 调用包含合并工具定义
  → 工具执行使用 allToolProtocols
  → mcpManagerForCleanup?.shutdown()（流终止时）
```

**工具分派管道：**
```
LLM 返回 tool_use 块
  → ToolExecutor.extractToolUseBlocks(contentBlocks)
  → ToolExecutor.executeTools(toolUseBlocks, tools: registeredTools, context:)
    → 对每个 tool_use 块：
      → 按名称在 registeredTools 中查找工具
      → 如果是 MCPToolDefinition → MCPClientProtocol.callTool()
      → 如果是 SdkToolWrapper → 直接 ToolProtocol.call()
      → 如果是内置工具 → 直接 ToolProtocol.call()
    → 并发执行只读工具（TaskGroup, max 10）
    → 串行执行变更工具
  → ToolResult(isError: true) 捕获错误，不崩溃
```

### 需要特别审查的关键点

1. **stream() 中的 MCP 连接清理** — 验证所有流终止路径（正常结束、错误、预算超限、取消）都执行 `mcpManagerForCleanup?.shutdown()`
2. **prompt() 中的 MCP 连接清理** — 验证错误路径（API 错误）也清理 MCP 连接
3. **assembleFullToolPool 中的 baseTools 来源** — 确认 `getAllBaseTools(tier: .core) + getAllBaseTools(tier: .specialist)` 包含了所有层级工具
4. **工具名冲突处理** — 验证 MCP 命名空间 `mcp__{serverName}__{toolName}` 不会与内置工具名冲突
5. **MCPToolDefinition 的 isReadOnly** — 始终返回 `false`，这意味着 MCP 工具不会并发执行。确认这是预期行为（与 TypeScript SDK 一致）

### 已有基础设施不需要修改（确认清单）

- **不要**修改 `MCPClientManager` — 已完整支持 stdio/SSE/HTTP + connectAll + SDK 跳过
- **不要**修改 `MCPToolDefinition` — 已完整支持命名空间、分派、错误隔离
- **不要**修改 `InProcessMCPServer` — 已完整支持工具暴露和会话管理
- **不要**修改 `McpServerConfig` — 已支持所有四种配置类型
- **不要**修改 `ToolRegistry` — `assembleToolPool()` 已支持 MCP 工具合并和去重

### 可能需要的代码变更

如果审查中发现以下问题，需要修复：

1. **`assembleFullToolPool()` 中缺少 advanced tier 工具** — 当前只添加了 `.core` 和 `.specialist`，缺少 `.advanced` tier（但 `getAllBaseTools(tier: .advanced)` 当前返回空数组，所以暂时无影响）
2. **stream() 中 MCP 工具在 auto-compaction 重建时可能丢失** — 验证 auto-compact 后工具定义是否完整
3. **`toApiTools()` 对 SdkToolWrapper 的处理** — 验证包装后的工具 schema 正确传递

### 前序 Story 的经验教训（必须遵循）

1. **nonisolated(unsafe) 用于 schema 常量** — inputSchema 字典需要标记为 `nonisolated(unsafe)` 以避免 Sendable 警告（Story 6-1）
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **错误路径测试** — 必须覆盖每个 guard 分支和每个 error case（规则 #28）
4. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - Tool Pool Assembly`
5. **Actor 模式** — MCPClientManager 是 actor，测试中用 `await` 访问
6. **不 throw 错误** — 工具调用错误应捕获为 isError: true（规则 #38）
7. **跨平台** — 不使用 Apple 专属框架（MCPToolDefinition 使用 Foundation + MCP）
8. **E2E 测试** — 完成后必须在 `Sources/E2ETest/` 中补充 E2E 测试（规则 #29）
9. **mock MCPClient** — 使用 MCPClientProtocol 协议进行 mock 测试（Story 6-1 模式）
10. **@Sendable 注解** — 传递给闭包的参数需要确保 Sendable 兼容（Story 6-2 修复）
11. **assembleToolPool 返回值** — 使用 Dictionary 去重时，值顺序不保证与输入一致，但保证名称唯一

### 反模式警告

- **不要**修改 `MCPClientManager` — 它已完整支持本 story 的需求
- **不要**修改 `MCPToolDefinition` — 它已完整支持命名空间和错误隔离
- **不要**修改 `InProcessMCPServer` — 它已完整支持 SDK 模式和外部客户端模式
- **不要**在 Tools/MCP/ 中导入 Core/ 或 Stores/ — 违反模块边界（规则 #7）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — 错误应捕获为 ToolResult(isError: true)（规则 #38）
- **不要**使用 `import Logging` — 与前序 story 保持一致
- **不要**在 stream() 中遗漏 MCP 连接清理 — 所有退出路径都必须清理

### 测试策略

**单元测试（mock）：**
- `processMcpConfigs` 分离 SDK 和外部配置
- `SdkToolWrapper` 命名空间前缀验证
- `assembleToolPool` 合并内置 + SDK + 外部工具
- `assembleToolPool` 去重包含 MCP 命名空间工具
- MCP 连接失败时工具池仍包含内置工具
- `MCPToolDefinition.call()` 错误隔离
- 混合配置（stdio + sse + http + sdk）工具池组装

**E2E 测试：**
- SDK 工具 + 外部失败服务器 → SDK 工具可用
- 完整工具池组装验证（内置 + SDK + 外部 mock）
- MCP 工具执行端到端（mock MCPClient）
- 多 MCP 服务器工具池合并
- 错误隔离：MCP 工具失败不影响其他工具

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 6-1 (已完成) | MCPClientManager + MCPToolDefinition — 本 story 验证其与 Agent 的集成 |
| 6-2 (已完成) | HTTP/SSE 传输 — 本 story 验证其通过 connectAll 与 Agent 集成 |
| 6-3 (已完成) | InProcessMCPServer + SdkToolWrapper — 本 story 验证其与 Agent 工具池集成 |
| 3-1 (已完成) | 工具协议与注册表 — assembleToolPool 的基础 |
| 3-3 (已完成) | 工具执行器 — MCP 工具分派通过 ToolExecutor |
| 1-5 (已完成) | 智能循环 — prompt() 和 stream() 的 MCP 集成路径 |

### 模块边界

```
Core/Agent.swift                   → processMcpConfigs, assembleFullToolPool, SdkToolWrapper (已实现)
Core/Agent.swift (prompt/stream)   → MCP 连接建立和清理 (已实现)
Tools/MCP/MCPClientManager.swift   → 外部服务器连接管理 (无需修改)
Tools/MCP/MCPToolDefinition.swift  → MCP 工具包装和分派 (无需修改)
Tools/MCP/InProcessMCPServer.swift → SDK 服务器 (无需修改)
Tools/ToolRegistry.swift           → assembleToolPool 去重 (无需修改)
Types/MCPConfig.swift              → 配置类型 (无需修改)
Types/MCPTypes.swift               → 连接状态类型 (无需修改)
```

新测试文件：
```
Tests/OpenAgentSDKTests/MCP/MCPAgentIntegrationTests.swift  (新建)
Sources/E2ETest/MCPClientManagerTests.swift                  (扩展)
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.4]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD5 MCP 集成]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR22 MCP 工具与内置工具并列]
- [Source: _bmad-output/project-context.md#规则 7 模块边界]
- [Source: _bmad-output/project-context.md#规则 10 MCP 命名空间]
- [Source: _bmad-output/implementation-artifacts/6-3-in-process-mcp-server.md] — SdkToolWrapper 和 processMcpConfigs 设计
- [Source: _bmad-output/implementation-artifacts/6-2-mcp-http-sse-transport.md] — HTTP/SSE 集成参考
- [Source: _bmad-output/implementation-artifacts/6-1-mcp-client-manager-stdio.md] — MCPClientManager 集成参考
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — processMcpConfigs, assembleFullToolPool, SdkToolWrapper
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift] — connectAll, getMCPTools, SDK 跳过逻辑
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift] — 命名空间、分派、错误隔离
- [Source: Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift] — SDK 工具暴露
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] — assembleToolPool 去重逻辑

### Project Structure Notes

- **新建** `Tests/OpenAgentSDKTests/MCP/MCPAgentIntegrationTests.swift` — 集成单元测试
- **扩展** `Sources/E2ETest/MCPClientManagerTests.swift` — 添加集成 E2E 测试部分
- 完全对齐架构文档的目录结构和模块边界

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

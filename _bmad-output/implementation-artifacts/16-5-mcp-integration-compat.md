# Story 16.5: MCP 集成完整性验证

Status: pending

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的 MCP 集成支持 TypeScript SDK 的所有服务器配置类型和运行时管理操作，
以便所有 MCP 用法都能在 Swift 中使用。

## Acceptance Criteria

1. **AC1: 示例编译运行** -- 给定 `Examples/CompatMCP/` 目录和 `CompatMCP` 可执行目标，运行 `swift build` 编译无错误和警告。

2. **AC2: 5 种 McpServerConfig 类型验证** -- 逐一检查 Swift SDK 是否支持 TS SDK 的 5 种 MCP 服务器配置：
   - `McpStdioServerConfig`（type: "stdio"、command、args、env）
   - `McpSSEServerConfig`（type: "sse"、url、headers）
   - `McpHttpServerConfig`（type: "http"、url、headers）
   - `McpSdkServerConfigWithInstance`（type: "sdk"、name、instance）
   - `McpClaudeAIProxyServerConfig`（type: "claudeai-proxy"、url、id）
   缺失的类型记录为缺口。

3. **AC3: MCP 运行时管理操作验证** -- 检查 Swift SDK 是否支持 TS SDK 的 MCP 运行时操作：
   - `mcpServerStatus()` — 返回服务器状态（connected/failed/needs-auth/pending/disabled）和工具列表
   - `reconnectMcpServer(name)` — 重连指定服务器
   - `toggleMcpServer(name, enabled)` — 启用/禁用服务器
   - `setMcpServers(servers)` — 动态替换服务器集（返回 added/removed/errors）
   缺失的操作记录为缺口。

4. **AC4: McpServerStatus 类型验证** -- 验证 Swift SDK 的服务器状态类型包含 TS SDK `McpServerStatus` 的所有字段：name、status（5 种状态值）、serverInfo（name+version）、error、config、scope、tools（含 annotations）。

5. **AC5: MCP 工具命名空间验证** -- 验证 MCP 工具使用 `mcp__{serverName}__{toolName}` 命名约定，与 TS SDK 一致。

6. **AC6: MCP 资源操作验证** -- 验证 ListMcpResources 和 ReadMcpResource 工具的输入/输出结构与 TS SDK 一致。

7. **AC7: AgentMcpServerSpec 验证** -- 验证 subagent 的 MCP 配置支持两种模式：字符串引用父级服务器名和内联配置记录。缺失则记录。

8. **AC8: 兼容性报告输出** -- 对所有 MCP 配置类型和操作输出兼容性状态。

## Tasks / Subtasks

- [ ] Task 1: 创建示例目录和文件 (AC: #1)
- [ ] Task 2: McpServerConfig 类型检查 (AC: #2)
  - [ ] 检查 Swift SDK 的 McpTransportConfig 或等价类型
  - [ ] 对比 5 种 TS SDK 配置类型
  - [ ] 记录缺失的配置类型
- [ ] Task 3: 运行时管理操作检查 (AC: #3, #4)
  - [ ] 检查 mcpServerStatus 等价 API
  - [ ] 检查 reconnect/toggle/setMcpServers 等价 API
  - [ ] 检查 McpServerStatus 类型的字段完整性
- [ ] Task 4: MCP 工具和资源验证 (AC: #5, #6)
  - [ ] 连接 stdio MCP 服务器并使用工具
  - [ ] 验证工具命名空间
  - [ ] 验证 ListMcpResources/ReadMcpResource 输入输出
- [ ] Task 5: AgentMcpServerSpec 检查 (AC: #7)
- [ ] Task 6: 生成兼容性报告 (AC: #8)

## Dev Notes

### 参考文档

- [TypeScript SDK] McpServerConfig 全部子类型、McpServerStatus、AgentMcpServerSpec、McpSetServersResult
- [Source] Sources/OpenAgentSDK/MCP/ — MCPClientManager 和相关类型
- [Source] Sources/OpenAgentSDK/Types/McpTypes.swift — MCP 配置类型

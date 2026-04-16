# Story 17.8: MCP 集成增强

Status: backlog

## Story

作为 SDK 开发者，
我希望补齐 Swift SDK 中缺失的 ClaudeAI Proxy 配置和 MCP 运行时管理操作，
以便所有 MCP 用法都能在 Swift 中使用。

## Acceptance Criteria

1. **AC1: McpClaudeAIProxyServerConfig** -- 新增 `McpServerConfig.claudeAIProxy(url:id:)` 配置类型, 对应 TS SDK 的 McpClaudeAIProxyServerConfig (type: "claudeai-proxy").

2. **AC2: mcpServerStatus()** -- Agent 新增 `mcpServerStatus() async -> [String: McpServerStatus]` 方法, 返回每个服务器的连接状态和工具列表.

3. **AC3: reconnectMcpServer()** -- Agent 新增 `reconnectMcpServer(name: String) async throws` 方法, 重连指定 MCP 服务器.

4. **AC4: toggleMcpServer()** -- Agent 新增 `toggleMcpServer(name: String, enabled: Bool) async throws` 方法, 启用/禁用指定服务器.

5. **AC5: setMcpServers()** -- Agent 新增 `setMcpServers(_ servers: [String: McpServerConfig]) async throws -> McpServerUpdateResult` 方法, 动态替换 MCP 服务器集, 返回 added/removed/errors 信息.

6. **AC6: McpServerStatus 类型** -- 新增 McpServerStatus 结构: name, status (connected/failed/needsAuth/pending/disabled), serverInfo, error, tools (含 annotations).

7. **AC7: 构建和测试** -- swift build 零错误零警告，3400+ 测试零回归.

## Tasks / Subtasks

- [ ] Task 1: McpClaudeAIProxyServerConfig (AC: #1)
  - [ ] 在 McpServerConfig 添加 claudeAIProxy case
  - [ ] 支持 url 和 id 参数
  - [ ] 在 MCPClientManager 中处理此配置类型

- [ ] Task 2: MCP 运行时管理方法 (AC: #2-#5)
  - [ ] 在 Agent 中添加 mcpServerStatus() 方法
  - [ ] 添加 reconnectMcpServer() 方法
  - [ ] 添加 toggleMcpServer() 方法
  - [ ] 添加 setMcpServers() 方法
  - [ ] 创建 McpServerUpdateResult 类型

- [ ] Task 3: McpServerStatus 类型 (AC: #6)
  - [ ] 创建 McpServerStatus 结构
  - [ ] 创建 McpServerStatusEnum (5 种状态)
  - [ ] 在 mcpServerStatus() 中填充实际状态

- [ ] Task 4: 验证构建和测试 (AC: #7)

## Dev Notes

### 关键源文件
- `Sources/OpenAgentSDK/Tools/MCP/MCPClientManager.swift` -- MCP 客户端管理
- `Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift` -- 进程内 MCP 服务器
- `Sources/OpenAgentSDK/Types/MCPConfig.swift` -- McpServerConfig, McpTransportConfig

### 缺口来源
- Story 16-5: McpClaudeAIProxyServerConfig MISSING, 3/4 runtime ops MISSING

### 实现策略
- ClaudeAI Proxy 配置可能需要特殊的认证处理
- setMcpServers() 的 diff 逻辑：比较新旧配置，added=新出现的服务器，removed=被删除的服务器
- McpServerStatus 从 MCPClientManager 获取实时连接状态

### References
- [Story 16-5 兼容性报告](_bmad-output/implementation-artifacts/16-5-mcp-integration-compat.md)

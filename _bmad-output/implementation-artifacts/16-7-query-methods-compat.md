# Story 16.7: Query 对象方法兼容性验证

Status: pending

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 提供与 TypeScript SDK Query 对象等价的所有运行时控制方法，
以便开发者可以在查询过程中动态控制 Agent 行为。

## Acceptance Criteria

1. **AC1: 示例编译运行** -- 给定 `Examples/CompatQueryMethods/` 目录和 `CompatQueryMethods` 可执行目标，运行 `swift build` 编译无错误和警告。

2. **AC2: 16 个 Query 方法逐一验证** -- 对 TS SDK Query 对象的每个方法，检查 Swift SDK 是否有等价实现，输出兼容性矩阵：

| TS Query 方法 | Swift 等价 | 状态 |
|---|---|---|
| `interrupt()` | `agent.interrupt()` | 需验证 |
| `rewindFiles(msgId, { dryRun })` | ? | 需验证 |
| `setPermissionMode(mode)` | `agent.setPermissionMode()` | 需验证 |
| `setModel(model?)` | `agent.switchModel()` | 需验证 |
| `initializationResult()` | ? | 需验证 |
| `supportedCommands()` | ? | 需验证 |
| `supportedModels()` | ? | 需验证 |
| `supportedAgents()` | ? | 需验证 |
| `mcpServerStatus()` | ? | 需验证 |
| `reconnectMcpServer(name)` | ? | 需验证 |
| `toggleMcpServer(name, enabled)` | ? | 需验证 |
| `setMcpServers(servers)` | ? | 需验证 |
| `streamInput(stream)` | ? | 需验证 |
| `stopTask(taskId)` | ? | 需验证 |
| `close()` | ? | 需验证 |

3. **AC3: 已有方法功能验证** -- 对 Swift SDK 已有的方法（如 interrupt、switchModel、setPermissionMode），验证其行为与 TS SDK 一致。

4. **AC4: initializationResult 等价验证** -- 如果 Swift SDK 有等价方法，验证返回的数据包含 TS SDK `SDKControlInitializeResponse` 的所有字段：commands（SlashCommand[]）、agents（AgentInfo[]）、output_style、available_output_styles、models（ModelInfo[]）、account（AccountInfo）。

5. **AC5: MCP 管理方法验证** -- 如果 Swift SDK 有等价方法，验证 mcpServerStatus/reconnectMcpServer/toggleMcpServer/setMcpServers 的输入/输出与 TS SDK 一致。

6. **AC6: streamInput 等价验证** -- 检查 Swift SDK 是否支持多轮流式输入（AsyncIterable 输入模式）。如果不支持，记录缺口。

7. **AC7: stopTask 等价验证** -- 检查 Swift SDK 是否支持按 ID 停止后台任务。如果不支持，记录缺口。

8. **AC8: 兼容性报告输出** -- 对 16 个 Query 方法逐一输出兼容性状态。

## Tasks / Subtasks

- [ ] Task 1: 创建示例目录和文件 (AC: #1)
- [ ] Task 2: Query 方法映射检查 (AC: #2)
  - [ ] 列出 TS SDK 的 16 个方法
  - [ ] 在 Swift SDK 中逐一搜索等价 API
  - [ ] 构建兼容性矩阵
- [ ] Task 3: 已有方法功能验证 (AC: #3, #4, #5)
  - [ ] 测试 interrupt/switchModel/setPermissionMode
  - [ ] 检查 initializationResult 等价
  - [ ] 检查 MCP 管理方法
- [ ] Task 4: 缺失方法分析 (AC: #6, #7)
  - [ ] 分析 streamInput 实现方案
  - [ ] 分析 stopTask 实现方案
- [ ] Task 5: 生成兼容性报告 (AC: #8)

## Dev Notes

### 关键关注点

这个 Story 的重点是**发现缺口**。TS SDK 的 Query 对象是一个丰富的运行时控制接口，Swift SDK 可能缺少以下关键方法：

- **P0 缺失风险高**：`initializationResult()`、`supportedModels()`、`mcpServerStatus()`
- **P1 缺失风险中**：`streamInput()`、`setMcpServers()`、`stopTask()`
- **P2 缺失风险低**：`rewindFiles()`（需要 checkpointing）、`supportedCommands()`

### 参考文档

- [TypeScript SDK] Query object、SDKControlInitializeResponse、McpSetServersResult、RewindFilesResult
- [Source] Sources/OpenAgentSDK/Core/Agent.swift — Agent 类的公共方法

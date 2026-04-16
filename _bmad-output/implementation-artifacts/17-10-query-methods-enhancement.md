# Story 17.10: 查询方法增强

Status: backlog

## Story

作为 SDK 开发者，
我希望补齐 Swift SDK 中缺失的 9 个查询控制方法，
以便开发者可以在查询过程中动态控制 Agent 行为。

## Acceptance Criteria

1. **AC1: rewindFiles()** -- Agent 新增 `rewindFiles(to messageId: String, dryRun: Bool = false) async throws -> RewindResult` 方法, 将文件恢复到指定消息时的状态.

2. **AC2: streamInput()** -- Agent 新增 `streamInput(_ input: AsyncStream<String>) -> AsyncStream<SDKMessage>` 方法, 支持多轮流式对话输入.

3. **AC3: stopTask()** -- Agent 新增 `stopTask(taskId: String) async throws` 方法, 按 ID 停止后台任务.

4. **AC4: close()** -- Agent 新增 `close() async throws` 方法, 强制终止查询并清理资源.

5. **AC5: initializationResult()** -- Agent 新增 `initializationResult() -> SDKControlInitializeResponse` 方法, 返回 commands/agents/models/account 信息.

6. **AC6: supportedModels() / supportedAgents()** -- Agent 新增 `supportedModels() -> [ModelInfo]` 和 `supportedAgents() -> [AgentInfo]` 方法.

7. **AC7: setMaxThinkingTokens()** -- Agent 新增 `setMaxThinkingTokens(_ n: Int?)` 方法, 动态调整思考 token 预算.

8. **AC8: 辅助类型** -- 新增 RewindResult, SDKControlInitializeResponse, AgentInfo 等类型.

9. **AC9: 构建和测试** -- swift build 零错误零警告，3400+ 测试零回归.

## Tasks / Subtasks

- [ ] Task 1: rewindFiles (AC: #1)
  - [ ] 创建 RewindResult 类型
  - [ ] 实现 rewindFiles() 方法
  - [ ] 需要文件 checkpointing 支持 (内存中追踪文件变更)

- [ ] Task 2: streamInput (AC: #2)
  - [ ] 实现 streamInput() 方法
  - [ ] 支持多轮流式输入
  - [ ] 输入流结束触发最终响应

- [ ] Task 3: 任务管理方法 (AC: #3, #4)
  - [ ] 实现 stopTask() — 需要后台任务注册表
  - [ ] 实现 close() — 清理所有资源

- [ ] Task 4: 信息查询方法 (AC: #5, #6)
  - [ ] 创建 SDKControlInitializeResponse 类型
  - [ ] 创建 AgentInfo 类型
  - [ ] 实现 initializationResult()
  - [ ] 实现 supportedModels() / supportedAgents()

- [ ] Task 5: setMaxThinkingTokens (AC: #7)
  - [ ] 实现动态 thinking token 调整
  - [ ] 影响下一次 API 调用的 thinking 配置

- [ ] Task 6: 验证构建和测试 (AC: #9)

## Dev Notes

### 关键源文件
- `Sources/OpenAgentSDK/Core/Agent.swift` -- Agent 类，添加新方法的主要位置
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- 新增类型定义

### 缺口来源
- Story 16-7: 16 MISSING query methods, 部分与 17-8 (MCP) 重叠

### 实现策略
- rewindFiles 需要在 Agent loop 中记录每次文件变更的快照
- streamInput 是 stream() 的变体，支持持续输入而非一次性 prompt
- close() 需要取消所有进行中的 Task，关闭 MCP 连接
- initializationResult/supportedModels 返回静态或配置驱动的数据

### References
- [Story 16-7 兼容性报告](_bmad-output/implementation-artifacts/16-7-query-methods-compat.md)

# Story 16.6: 会话管理完整性验证

Status: pending

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的会话管理 API 覆盖 TypeScript SDK 的所有会话操作，
以便所有会话相关功能都能在 Swift 中使用。

## Acceptance Criteria

1. **AC1: 示例编译运行** -- 给定 `Examples/CompatSessions/` 目录和 `CompatSessions` 可执行目标，运行 `swift build` 编译无错误和警告。

2. **AC2: listSessions 等价验证** -- 验证 Swift SDK 有与 TS SDK `listSessions({ dir?, limit?, includeWorktrees? })` 等价的方法，返回 `SDKSessionInfo[]`（含 sessionId、summary、lastModified、fileSize、customTitle、firstPrompt、gitBranch、cwd、tag、createdAt）。

3. **AC3: getSessionMessages 等价验证** -- 验证 Swift SDK 有与 TS SDK `getSessionMessages(sessionId, { dir?, limit?, offset? })` 等价的方法，返回 `SessionMessage[]`（含 type: user/assistant、uuid、session_id、message、parent_tool_use_id）。

4. **AC4: getSessionInfo/renameSession/tagSession 验证** -- 验证 Swift SDK 有与 TS SDK `getSessionInfo(sessionId)`（返回 SDKSessionInfo 或 nil）、`renameSession(sessionId, title)`、`tagSession(sessionId, tag | null)` 等价的方法。

5. **AC5: 会话恢复选项验证** -- 验证 Swift SDK 的 AgentOptions 支持以下会话选项（与 TS SDK Options 对应）：
   - `resume: sessionId` — 恢复会话
   - `continue: true` — 继续最近会话
   - `forkSession: true` — 分叉而非继续
   - `resumeSessionAt: messageUUID` — 从指定消息恢复
   - `sessionId: uuid` — 使用指定 ID
   - `persistSession: false` — 禁用持久化
   缺失选项记录为缺口。

6. **AC6: 跨查询上下文保持验证** -- 使用同一 Agent 实例执行两轮查询，验证第二轮能引用第一轮的内容。

7. **AC7: 兼容性报告输出** -- 对所有会话函数和选项输出兼容性状态。

## Tasks / Subtasks

- [ ] Task 1: 创建示例目录和文件 (AC: #1)
- [ ] Task 2: 会话列表和信息验证 (AC: #2, #3, #4)
  - [ ] 检查 listSessions 等价方法
  - [ ] 检查 getSessionMessages 等价方法
  - [ ] 检查 getSessionInfo/renameSession/tagSession
  - [ ] 验证 SDKSessionInfo 字段完整性
- [ ] Task 3: 会话恢复选项验证 (AC: #5)
  - [ ] 检查 AgentOptions 中的 resume/continue/forkSession 选项
  - [ ] 检查 sessionId/persistSession 选项
  - [ ] 记录缺失选项
- [ ] Task 4: 跨查询上下文验证 (AC: #6)
  - [ ] 第一轮告知事实，第二轮引用
- [ ] Task 5: 生成兼容性报告 (AC: #7)

## Dev Notes

### 参考文档

- [TypeScript SDK] listSessions()、getSessionMessages()、getSessionInfo()、renameSession()、tagSession()、Options 中的 session 相关字段
- [Source] Sources/OpenAgentSDK/Stores/SessionStore.swift — SessionStore actor
- [Source] Sources/OpenAgentSDK/Types/SessionTypes.swift — SDKSessionInfo、SessionMessage

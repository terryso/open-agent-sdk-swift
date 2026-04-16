# Story 17.7: 会话管理增强

Status: backlog

## Story

作为 SDK 开发者，
我希望补齐 Swift SDK 中缺失的 4 个会话恢复选项，
以便开发者可以灵活控制会话生命周期。

## Acceptance Criteria

1. **AC1: continueRecentSession** -- AgentOptions 新增 `continueRecentSession: Bool` (默认 false). 设为 true 时, Agent 自动加载最近的会话历史. 无可恢复会话时按新会话处理.

2. **AC2: forkSession** -- AgentOptions 新增 `forkSession: Bool` (默认 false). 设为 true 时创建会话副本, 原会话保持不变.

3. **AC3: resumeSessionAt** -- AgentOptions 新增 `resumeSessionAt: String?`. 加载会话历史截至指定 UUID 的消息. UUID 不存在时从最近消息恢复.

4. **AC4: persistSession** -- AgentOptions 新增 `persistSession: Bool` (默认 true). 设为 false 时会话仅在内存中, 不写入磁盘.

5. **AC5: 集成验证** -- 测试 continue + fork 组合: continueRecentSession=true + forkSession=true 应分叉最近会话.

6. **AC6: 构建和测试** -- swift build 零错误零警告，3400+ 测试零回归.

## Tasks / Subtasks

- [ ] Task 1: AgentOptions 字段 (AC: #1-#4)
  - [ ] 添加 continueRecentSession, forkSession, resumeSessionAt, persistSession 字段
  - [ ] 所有字段有合理默认值

- [ ] Task 2: continueRecentSession 实现 (AC: #1)
  - [ ] 在 Agent 初始化时检查 continueRecentSession
  - [ ] 通过 SessionStore.list() 找到最近会话
  - [ ] 加载该会话历史到 Agent 上下文

- [ ] Task 3: forkSession 实现 (AC: #2)
  - [ ] 在会话加载时创建副本
  - [ ] 副本使用新 sessionId
  - [ ] 原会话文件不被修改

- [ ] Task 4: resumeSessionAt 实现 (AC: #3)
  - [ ] 在加载会话时按 UUID 截断消息列表
  - [ ] UUID 不存在时的 fallback 逻辑

- [ ] Task 5: persistSession 实现 (AC: #4)
  - [ ] 在 Agent 完成查询后检查 persistSession
  - [ ] false 时跳过 SessionStore.save() 调用

- [ ] Task 6: 集成测试 (AC: #5, #6)

## Dev Notes

### 关键源文件
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` -- AgentOptions
- `Sources/OpenAgentSDK/Core/Agent.swift` -- Agent 初始化和会话加载
- `Sources/OpenAgentSDK/Stores/SessionStore.swift` -- 会话持久化

### 缺口来源
- Story 16-6: 4/6 session options MISSING (continue, forkSession, resumeSessionAt, persistSession)

### 实现策略
- continueRecentSession 和 resume（已有的 sessionId）互斥：两者都设置时 resume 优先
- forkSession 仅在 continue 或 resume 场景下有意义
- persistSession=false 可与任意组合使用，仅控制完成后的保存行为

### References
- [Story 16-6 兼容性报告](_bmad-output/implementation-artifacts/16-6-session-management-compat.md)

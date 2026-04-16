# Story 18.6: 更新 CompatSessions 示例

Status: backlog

## Story

作为 SDK 开发者，
我希望更新 `Examples/CompatSessions/` 使其反映 Epic 17 填补后的兼容性状态，
以便会话管理兼容性报告准确展示对齐程度。

## Acceptance Criteria

1. **AC1: 会话恢复选项 PASS** -- continueRecentSession/forkSession/resumeSessionAt/persistSession 标记为 `[PASS]`.
2. **AC2: 功能验证** -- 示例中实际演示会话恢复/分叉/禁用持久化.
3. **AC3: 构建通过** -- swift build 零错误零警告.

## Tasks / Subtasks

- [ ] Task 1: 更新会话选项验证 (AC: #1)
  - [ ] 测试 continueRecentSession=true 加载最近会话
  - [ ] 测试 forkSession=true 创建副本
  - [ ] 测试 resumeSessionAt 从指定 UUID 恢复
  - [ ] 测试 persistSession=false 禁用持久化

- [ ] Task 2: 更新报告条目 (AC: #1)
- [ ] Task 3: 验证构建 (AC: #3)

## Dev Notes

### 依赖
- Story 17-7 (会话管理增强)

### 关键源文件
- `Examples/CompatSessions/main.swift` — 需要更新的示例

### References
- [Story 16-6 兼容性报告](_bmad-output/implementation-artifacts/16-6-session-management-compat.md)
- [Story 17-7](_bmad-output/implementation-artifacts/17-7-session-management-enhancement.md)

# Story 18.4: 更新 CompatHooks 示例

Status: backlog

## Story

作为 SDK 开发者，
我希望更新 `Examples/CompatHooks/` 使其反映 Epic 17 填补后的兼容性状态，
以便 Hook 系统兼容性报告准确展示对齐程度。

## Acceptance Criteria

1. **AC1: 3 个新 HookEvent PASS** -- setup/worktreeCreate/worktreeRemove 标记为 `[PASS]`.
2. **AC2: HookInput 字段 PASS** -- transcriptPath/permissionMode/agentId/agentType 及 per-event 字段标记为 `[PASS]`.
3. **AC3: HookOutput 字段 PASS** -- systemMessage/reason/updatedInput/additionalContext/permissionDecision 标记为 `[PASS]`.
4. **AC4: 构建通过** -- swift build 零错误零警告.

## Tasks / Subtasks

- [ ] Task 1: 更新 HookEvent 映射表 (AC: #1)
- [ ] Task 2: 更新 HookInput 字段验证 (AC: #2)
- [ ] Task 3: 更新 HookOutput 字段验证 (AC: #3)
- [ ] Task 4: 验证构建 (AC: #4)

## Dev Notes

### 依赖
- Story 17-4 (Hook 系统增强)

### 关键源文件
- `Examples/CompatHooks/main.swift` — 需要更新的示例

### References
- [Story 16-4 兼容性报告](_bmad-output/implementation-artifacts/16-4-hook-system-compat.md)
- [Story 17-4](_bmad-output/implementation-artifacts/17-4-hook-system-enhancement.md)

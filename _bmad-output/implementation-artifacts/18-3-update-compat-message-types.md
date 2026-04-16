# Story 18.3: 更新 CompatMessageTypes 示例

Status: backlog

## Story

作为 SDK 开发者，
我希望更新 `Examples/CompatMessageTypes/` 使其反映 Epic 17 填补后的兼容性状态，
以便消息类型兼容性报告准确展示对齐程度。

## Acceptance Criteria

1. **AC1: 12 个新消息类型 PASS** -- userMessage, toolProgress, hookStarted/Progress/Response, taskStarted/Progress, authStatus, filesPersisted, localCommandOutput, promptSuggestion, toolUseSummary 标记为 `[PASS]`.
2. **AC2: AssistantData 字段 PASS** -- uuid/sessionId/parentToolUseId/error 标记为 `[PASS]`.
3. **AC3: ResultData 字段 PASS** -- structuredOutput/permissionDenials/modelUsage 标记为 `[PASS]`.
4. **AC4: PartialData 字段 PASS** -- parentToolUseId/uuid/sessionId 标记为 `[PASS]`.
5. **AC5: 构建通过** -- swift build 零错误零警告.

## Tasks / Subtasks

- [ ] Task 1: 更新 20 个消息类型映射表 (AC: #1)
  - [ ] 将 12 个 MISSING 条目改为 PASS
  - [ ] 更新 switch 语句覆盖新 case
  - [ ] 为每个新类型添加字段验证

- [ ] Task 2: 更新现有类型字段验证 (AC: #2, #3, #4)
  - [ ] AssistantData 新字段验证
  - [ ] ResultData 新字段验证
  - [ ] PartialData 新字段验证

- [ ] Task 3: 验证构建 (AC: #5)

## Dev Notes

### 依赖
- Story 17-1 (SDKMessage 类型增强) — 所有消息类型和字段补全

### 关键源文件
- `Examples/CompatMessageTypes/main.swift` — 需要更新的示例

### References
- [Story 16-3 兼容性报告](_bmad-output/implementation-artifacts/16-3-message-types-compat.md)
- [Story 17-1](_bmad-output/implementation-artifacts/17-1-sdkmessage-type-enhancement.md)

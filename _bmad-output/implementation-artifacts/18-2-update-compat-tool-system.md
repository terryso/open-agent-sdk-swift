# Story 18.2: 更新 CompatToolSystem 示例

Status: backlog

## Story

作为 SDK 开发者，
我希望更新 `Examples/CompatToolSystem/` 使其反映 Epic 17 填补后的兼容性状态，
以便工具系统兼容性报告准确展示对齐程度。

## Acceptance Criteria

1. **AC1: ToolAnnotations PASS** -- ToolAnnotations 的 4 个 hint 字段 (readOnlyHint, destructiveHint, idempotentHint, openWorldHint) 标记为 `[PASS]`.
2. **AC2: ToolResult 类型化 PASS** -- ToolContent 类型数组 (.text, .image, .resource) 标记为 `[PASS]`.
3. **AC3: BashInput.run_in_background PASS** -- runInBackground 字段标记为 `[PASS]`.
4. **AC4: 构建通过** -- swift build 零错误零警告.

## Tasks / Subtasks

- [ ] Task 1: 更新 ToolAnnotations 验证 (AC: #1)
  - [ ] 使用新 ToolAnnotations 类型创建带 annotations 的自定义工具
  - [ ] 验证 4 个 hint 字段可读写
  - [ ] 更新报告条目

- [ ] Task 2: 更新 ToolContent 验证 (AC: #2)
  - [ ] 使用 typedContent 创建包含多类型内容的 ToolResult
  - [ ] 验证 .text/.image/.resource case
  - [ ] 更新报告条目

- [ ] Task 3: 更新 BashInput 验证 (AC: #3)
  - [ ] 使用 runInBackground 参数执行后台命令
  - [ ] 验证 backgroundTaskId 返回
  - [ ] 更新报告条目

- [ ] Task 4: 验证构建 (AC: #4)

## Dev Notes

### 依赖
- Story 17-3 (工具系统增强)

### 关键源文件
- `Examples/CompatToolSystem/main.swift` — 需要更新的示例

### References
- [Story 16-2 兼容性报告](_bmad-output/implementation-artifacts/16-2-tool-system-compat.md)
- [Story 17-3](_bmad-output/implementation-artifacts/17-3-tool-system-enhancement.md)

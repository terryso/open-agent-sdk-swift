# Story 18.9: 更新 CompatPermissions 示例

Status: backlog

## Story

作为 SDK 开发者，
我希望更新 `Examples/CompatPermissions/` 使其反映 Epic 17 填补后的兼容性状态，
以便权限系统兼容性报告准确展示对齐程度。

## Acceptance Criteria

1. **AC1: PermissionUpdate 操作 PASS** -- addRules/replaceRules/removeRules/setMode/addDirectories/removeDirectories 标记为 `[PASS]`.
2. **AC2: CanUseTool 扩展 PASS** -- ToolPermissionContext (signal/suggestions/blockedPath/decisionReason/toolUseID/agentID) 标记为 `[PASS]`.
3. **AC3: SDKPermissionDenial PASS** -- SDKPermissionDenial 类型和 ResultData.permissionDenials 标记为 `[PASS]`.
4. **AC4: 构建通过** -- swift build 零错误零警告.

## Tasks / Subtasks

- [ ] Task 1: 更新 PermissionUpdate 验证 (AC: #1)
  - [ ] 测试 6 种操作类型
  - [ ] 测试 PermissionBehavior (allow/deny/ask)
  - [ ] 测试 PermissionUpdateDestination (5 种目标)

- [ ] Task 2: 更新 CanUseTool 验证 (AC: #2)
  - [ ] 测试 ToolPermissionContext 新字段
  - [ ] 验证 updatedPermissions 返回

- [ ] Task 3: 更新 PermissionDenial 验证 (AC: #3)
- [ ] Task 4: 验证构建 (AC: #4)

## Dev Notes

### 依赖
- Story 17-5 (权限系统增强)

### 关键源文件
- `Examples/CompatPermissions/main.swift` — 需要更新的示例

### References
- [Story 16-9 兼容性报告](_bmad-output/implementation-artifacts/16-9-permission-system-compat.md)
- [Story 17-5](_bmad-output/implementation-artifacts/17-5-permission-system-enhancement.md)

# Story 17.5: 权限系统增强

Status: backlog

## Story

作为 SDK 开发者，
我希望补齐 Swift SDK 权限系统中缺失的 PermissionUpdate 操作、CanUseTool 扩展参数和 PermissionDenial 类型，
以便所有权限控制模式都能在 Swift 中使用。

## Acceptance Criteria

1. **AC1: PermissionUpdate 操作类型** -- 新增 `PermissionUpdate` 枚举支持 6 种操作: addRules, replaceRules, removeRules (含 rules 数组和 behavior: allow/deny/ask), setMode, addDirectories, removeDirectories. 每种操作支持 destination (userSettings/projectSettings/localSettings/session/cliArg).

2. **AC2: PermissionBehavior 和 PermissionUpdateDestination** -- 新增 `PermissionBehavior` 枚举 (allow/deny/ask), 新增 `PermissionUpdateDestination` 枚举 (userSettings/projectSettings/localSettings/session/cliArg).

3. **AC3: CanUseTool 回调参数扩展** -- 创建 `ToolPermissionContext` 结构包含: signal (取消信号), suggestions ([PermissionUpdate]), blockedPath (String?), decisionReason (String?), toolUseID (String), agentID (String?). CanUseToolFn 签名更新使用此上下文.

4. **AC4: SDKPermissionDenial 类型** -- 新增 `SDKPermissionDenial` 结构包含 toolName, toolUseId, toolInput. 在 ResultData.permissionDenials 中正确填充.

5. **AC5: 构建和测试** -- swift build 零错误零警告，3400+ 测试零回归.

## Tasks / Subtasks

- [ ] Task 1: PermissionUpdate 操作类型 (AC: #1, #2)
  - [ ] 创建 PermissionBehavior 枚举
  - [ ] 创建 PermissionUpdateDestination 枚举
  - [ ] 创建 PermissionUpdate 枚举 (6 种关联值 case)
  - [ ] 在权限系统中集成 PermissionUpdate 处理逻辑

- [ ] Task 2: CanUseTool 扩展 (AC: #3)
  - [ ] 创建 ToolPermissionContext 结构
  - [ ] 更新 CanUseToolFn 签名使用新上下文
  - [ ] 保持现有 CanUseToolFn 向后兼容

- [ ] Task 3: SDKPermissionDenial (AC: #4)
  - [ ] 创建 SDKPermissionDenial 结构
  - [ ] 在权限拒绝时构造 SDKPermissionDenial 实例
  - [ ] 在 ResultData 中添加 permissionDenials 字段（如 17-1 未完成则在此添加）

- [ ] Task 4: 验证构建和测试 (AC: #5)

## Dev Notes

### 关键源文件
- `Sources/OpenAgentSDK/Types/PermissionTypes.swift` -- PermissionMode, CanUseToolFn
- `Sources/OpenAgentSDK/Core/PermissionChecker.swift` -- 权限检查逻辑
- `Sources/OpenAgentSDK/Core/ToolExecutor.swift` -- 工具执行中的权限调用点

### 缺口来源
- Story 16-9: ~15 MISSING (CanUseTool params, PermissionUpdate operations, PermissionUpdateDestination)

### 实现策略
- CanUseToolFn 签名变更需要考虑向后兼容 — 可通过新类型 ToolPermissionContext 封装额外参数
- PermissionUpdate 操作暂存内存（session 级别），不涉及文件系统 settings 写入
- SDKPermissionDenial 与 Story 17-1 的 ResultData.permissionDenials 字段配合使用

### References
- [Story 16-9 兼容性报告](_bmad-output/implementation-artifacts/16-9-permission-system-compat.md)

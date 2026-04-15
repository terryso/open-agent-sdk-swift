# Story 16.9: 权限系统完整性验证

Status: pending

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的权限系统完全覆盖 TypeScript SDK 的所有权限类型和操作，
以便所有权限控制模式都能在 Swift 中使用。

## Acceptance Criteria

1. **AC1: 示例编译运行** -- 给定 `Examples/CompatPermissions/` 目录和 `CompatPermissions` 可执行目标，运行 `swift build` 编译无错误和警告。

2. **AC2: 6 种 PermissionMode 行为验证** -- 对 TS SDK 的 6 种权限模式逐一测试，验证 Swift SDK 的行为一致：
   - `default` — 标准授权流程
   - `acceptEdits` — 自动接受文件编辑
   - `bypassPermissions` — 跳过所有权限检查
   - `plan` — 规划模式，不执行工具
   - `dontAsk` — 不提示，未预批准则拒绝
   - `auto` — 使用模型分类器自动批准或拒绝

3. **AC3: CanUseTool 回调验证** -- 验证 Swift SDK 的 CanUseToolFn 与 TS SDK 的 CanUseTool 签名兼容：
   - 接收参数：toolName、input、signal（AbortSignal）、suggestions（PermissionUpdate[]）、blockedPath、decisionReason、toolUseID、agentID
   - 返回类型：allow（含 updatedInput、updatedPermissions）或 deny（含 message、interrupt）

4. **AC4: PermissionUpdate 操作类型验证** -- 检查 Swift SDK 是否支持 TS SDK 的 6 种 PermissionUpdate 操作：
   - `addRules` — 添加权限规则
   - `replaceRules` — 替换权限规则
   - `removeRules` — 移除权限规则
   - `setMode` — 设置权限模式
   - `addDirectories` — 添加目录
   - `removeDirectories` — 移除目录
   每种操作包含 behavior（allow/deny/ask）和 destination（userSettings/projectSettings/localSettings/session/cliArg）。

5. **AC5: disallowedTools 优先级验证** -- 验证 disallowedTools 的优先级高于 allowedTools 和 permissionMode（包括 bypassPermissions）。

6. **AC6: allowDangerouslySkipPermissions 验证** -- 验证 bypassPermissions 模式是否需要显式确认（对应 TS SDK 的 allowDangerouslySkipPermissions）。

7. **AC7: PermissionDenial 结构验证** -- 验证 Swift SDK 有与 TS SDK `SDKPermissionDenial` 等价的类型（tool_name、tool_use_id、tool_input），并在 SDKResultMessage 的 permission_denials 字段中正确返回。

8. **AC8: 兼容性报告输出** -- 对所有权限类型和操作输出兼容性状态。

## Tasks / Subtasks

- [ ] Task 1: 创建示例目录和文件 (AC: #1)
- [ ] Task 2: PermissionMode 行为对比测试 (AC: #2)
  - [ ] 对每种模式创建 Agent 并执行工具调用
  - [ ] 验证行为差异与 TS SDK 一致
- [ ] Task 3: CanUseTool 回调测试 (AC: #3)
  - [ ] 注册 allow/deny/modify-input 回调
  - [ ] 验证所有参数字段
- [ ] Task 4: PermissionUpdate 类型检查 (AC: #4)
  - [ ] 检查 6 种操作类型
  - [ ] 检查 PermissionBehavior 和 PermissionUpdateDestination
- [ ] Task 5: 优先级和安全性验证 (AC: #5, #6, #7)
  - [ ] 测试 disallowedTools > allowedTools
  - [ ] 检查 bypassPermissions 安全机制
  - [ ] 检查 permission_denials 字段
- [ ] Task 6: 生成兼容性报告 (AC: #8)

## Dev Notes

### 参考文档

- [TypeScript SDK] PermissionMode、CanUseTool、PermissionResult、PermissionUpdate、PermissionBehavior、PermissionUpdateDestination、SDKPermissionDenial
- [Source] Sources/OpenAgentSDK/Types/PermissionTypes.swift — PermissionMode、CanUseToolFn
- [Source] Sources/OpenAgentSDK/Tools/ — 工具权限检查逻辑

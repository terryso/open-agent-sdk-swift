# Story 16.4: Hook 系统完整性验证

Status: pending

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的 Hook 系统覆盖 TypeScript SDK 的所有 18 个事件和对应的输入/输出类型，
以便所有 Hook 用法都能从 TypeScript 迁移到 Swift。

## Acceptance Criteria

1. **AC1: 示例编译运行** -- 给定 `Examples/CompatHooks/` 目录和 `CompatHooks` 可执行目标，运行 `swift build` 编译无错误和警告。

2. **AC2: 18 个 HookEvent 覆盖验证** -- 逐一检查 Swift SDK 的 HookEvent 枚举是否包含 TS SDK 的全部 18 个事件：PreToolUse、PostToolUse、PostToolUseFailure、Notification、UserPromptSubmit、SessionStart、SessionEnd、Stop、SubagentStart、SubagentStop、PreCompact、PermissionRequest、Setup、TeammateIdle、TaskCompleted、ConfigChange、WorktreeCreate、WorktreeRemove。缺失的事件记录为缺口。

3. **AC3: BaseHookInput 字段验证** -- 验证 Swift SDK 的 HookInput 基础字段包含 TS SDK `BaseHookInput` 的所有字段：session_id、transcript_path、cwd、permission_mode、agent_id、agent_type。

4. **AC4: PreToolUse/PostToolUse HookInput 验证** -- 验证 PreToolUse HookInput 包含 tool_name、tool_input、tool_use_id。验证 PostToolUse HookInput 包含 tool_name、tool_input、tool_response、tool_use_id。验证 PostToolUseFailure HookInput 包含 error、is_interrupt。

5. **AC5: 其他 HookInput 类型验证** -- 验证 StopHookInput（stop_hook_active、last_assistant_message）、SubagentStartHookInput（agent_id、agent_type）、SubagentStopHookInput（agent_id、agent_transcript_path、agent_type、last_assistant_message）、PreCompactHookInput（trigger: manual/auto、custom_instructions）、PermissionRequestHookInput（tool_name、tool_input、permission_suggestions）。

6. **AC6: HookCallbackMatcher 验证** -- 验证 Swift SDK 支持 matcher 正则过滤、多个 hook 回调数组、超时配置（默认 30 秒）。

7. **AC7: HookOutput 类型验证** -- 验证 Swift SDK 的 HookOutput 支持 TS SDK SyncHookJSONOutput 的所有关键字段：decision（approve/block）、systemMessage、reason、permissionDecision（allow/deny/ask）、updatedInput、additionalContext。验证 hookSpecificOutput 的 PreToolUse/PostToolUse/PermissionRequest 等变体。

8. **AC8: Hook 实际执行验证** -- 注册 PreToolUse hook 演示 decision: block 拦截工具执行。注册 PostToolUse hook 演示审计日志记录。验证 hook 回调按注册顺序执行。

9. **AC9: 兼容性报告输出** -- 对 18 个事件和所有 HookInput/Output 类型输出兼容性状态。

## Tasks / Subtasks

- [ ] Task 1: 创建示例目录和文件 (AC: #1)
- [ ] Task 2: HookEvent 覆盖检查 (AC: #2)
  - [ ] 定义 TS SDK 的 18 个事件列表
  - [ ] 逐一检查 Swift SDK HookEvent 枚举
  - [ ] 记录缺失事件
- [ ] Task 3: HookInput 字段验证 (AC: #3, #4, #5)
  - [ ] 检查 BaseHookInput 字段
  - [ ] 检查每个事件的专用字段
  - [ ] 记录缺失字段
- [ ] Task 4: HookCallbackMatcher 和 HookOutput 验证 (AC: #6, #7)
  - [ ] 验证 matcher 过滤支持
  - [ ] 验证 timeout 配置
  - [ ] 验证 HookOutput 的所有字段和变体
- [ ] Task 5: 实际 Hook 执行演示 (AC: #8)
  - [ ] 注册 PreToolUse 拦截 hook
  - [ ] 注册 PostToolUse 审计 hook
  - [ ] 执行查询验证 hook 触发
- [ ] Task 6: 生成兼容性报告 (AC: #9)

## Dev Notes

### 参考文档

- [TypeScript SDK] HookEvent、HookCallback、HookInput 全部类型、HookJSONOutput
- [Source] Sources/OpenAgentSDK/Hooks/HookRegistry.swift — HookRegistry actor
- [Source] Sources/OpenAgentSDK/Types/HookTypes.swift — HookEvent、HookInput、HookOutput

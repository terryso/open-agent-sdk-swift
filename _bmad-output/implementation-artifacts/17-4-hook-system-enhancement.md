# Story 17.4: Hook 系统增强

Status: backlog

## Story

作为 SDK 开发者，
我希望补齐 Swift SDK Hook 系统中缺失的 3 个事件和 HookInput/Output 字段，
以便所有 Hook 用法都能从 TS 迁移到 Swift。

## Acceptance Criteria

1. **AC1: 3 个缺失 HookEvent** -- 在 HookEvent enum 中添加 `setup`, `worktreeCreate`, `worktreeRemove`. CaseIterable 自动更新.

2. **AC2: HookInput 基础字段补全** -- HookInput 添加: `transcriptPath: String?`, `permissionMode: String?`, `agentId: String?`, `agentType: String?`.

3. **AC3: Per-event 专用字段** -- 添加事件专用字段: `stopHookActive: Bool?`, `lastAssistantMessage: String?` (Stop), `trigger: String?` (manual/auto), `customInstructions: String?` (PreCompact), `permissionSuggestions: [String]?` (PermissionRequest), `isInterrupt: Bool?` (PostToolUseFailure).

4. **AC4: HookOutput 字段补全** -- HookOutput 添加: `systemMessage: String?`, `reason: String?`, `updatedInput: [String: Any]?`, `additionalContext: String?`. PreToolUse output 支持 `permissionDecision`, PostToolUse output 支持 `updatedMCPToolOutput`.

5. **AC5: 构建和测试** -- swift build 零错误零警告，3400+ 测试零回归.

## Tasks / Subtasks

- [ ] Task 1: 新增 HookEvent case (AC: #1)
- [ ] Task 2: HookInput 字段补全 (AC: #2, #3)
- [ ] Task 3: HookOutput 字段补全 (AC: #4)
- [ ] Task 4: 验证构建和测试 (AC: #5)

## Dev Notes

### 关键源文件
- `Sources/OpenAgentSDK/Types/HookTypes.swift` -- HookEvent, HookInput, HookOutput, HookDefinition
- `Sources/OpenAgentSDK/Hooks/HookRegistry.swift` -- Hook 注册和执行

### 缺口来源
- Story 16-4: 3 MISSING events (Setup, WorktreeCreate, WorktreeRemove), 10+ MISSING fields

### 实现策略
- 所有新增字段均为 optional
- setup 事件在 Agent 初始化时触发
- worktreeCreate/Remove 在工作树操作时触发

### References
- [Story 16-4 兼容性报告](_bmad-output/implementation-artifacts/16-4-hook-system-compat.md)

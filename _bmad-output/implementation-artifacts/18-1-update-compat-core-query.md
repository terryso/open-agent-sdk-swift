# Story 18.1: 更新 CompatCoreQuery 示例

Status: backlog

## Story

作为 SDK 开发者，
我希望更新 `Examples/CompatCoreQuery/` 使其反映 Epic 17 填补后的兼容性状态，
以便兼容性报告准确展示 Swift SDK 与 TS SDK 的对齐程度。

## Acceptance Criteria

1. **AC1: SystemData 字段 PASS** -- SystemData.init 的 session_id/tools/model/permissionMode/mcpServers/cwd 字段在报告中标记为 `[PASS]` (依赖 17-1 补全).
2. **AC2: ResultData 字段 PASS** -- ResultData 的 structuredOutput/permissionDenials/modelUsage/errors 字段标记为 `[PASS]` (依赖 17-1 补全).
3. **AC3: AgentOptions 字段 PASS** -- fallbackModel/env/allowedTools/disallowedTools/effort 等字段标记为 `[PASS]` (依赖 17-2 补全).
4. **AC4: 兼容性报告准确** -- 报告 pass rate 提升, 仅保留真正未实现的字段为 MISSING.
5. **AC5: 构建通过** -- swift build 零错误零警告.

## Tasks / Subtasks

- [ ] Task 1: 更新兼容性报告字段状态 (AC: #1, #2, #3)
  - [ ] 遍历示例中的 CompatEntry 列表
  - [ ] 将已由 Epic 17 填补的 MISSING 条目改为 PASS
  - [ ] 更新 pass rate 计算

- [ ] Task 2: 更新实际验证逻辑 (AC: #4)
  - [ ] 对 SystemData.init 的新字段添加实际值检查
  - [ ] 对 ResultData 的新字段添加实际值检查
  - [ ] 移除对已填补字段的 "MISSING" 记录逻辑

- [ ] Task 3: 验证构建 (AC: #5)

## Dev Notes

### 依赖
- Story 17-1 (SDKMessage 类型增强) — SystemData/ResultData 字段补全
- Story 17-2 (AgentOptions 完整参数) — 配置字段补全

### 关键源文件
- `Examples/CompatCoreQuery/main.swift` — 需要更新的示例
- `Sources/OpenAgentSDK/Types/SDKMessage.swift` — 已由 17-1 更新
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` — 已由 17-2 更新

### References
- [Story 16-1 兼容性报告](_bmad-output/implementation-artifacts/16-1-core-query-api-compat.md)
- [Story 17-1](_bmad-output/implementation-artifacts/17-1-sdkmessage-type-enhancement.md)
- [Story 17-2](_bmad-output/implementation-artifacts/17-2-agent-options-enhancement.md)

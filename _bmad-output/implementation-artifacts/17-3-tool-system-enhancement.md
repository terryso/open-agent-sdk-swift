# Story 17.3: 工具系统增强

Status: backlog

## Story

作为 SDK 开发者，
我希望补齐 Swift SDK 工具系统中缺失的 ToolAnnotations、类型化 ToolResult 和 BashInput.run_in_background，
以便 Swift SDK 的工具系统达到 TS SDK 功能等价。

## Acceptance Criteria

1. **AC1: ToolAnnotations 类型** -- 新增 `ToolAnnotations` 结构包含 `readOnlyHint: Bool`, `destructiveHint: Bool`, `idempotentHint: Bool`, `openWorldHint: Bool`.

2. **AC2: ToolProtocol annotations 属性** -- ToolProtocol 新增 `annotations: ToolAnnotations?` 属性, defineTool() 支持 annotations 参数.

3. **AC3: ToolContent 类型化** -- 新增 `ToolContent` 枚举: `.text(String)`, `.image(data: Data, mimeType: String)`, `.resource(uri: String, name: String?)`. ToolResult 支持 `typedContent: [ToolContent]?` 和向后兼容的 `content: String`.

4. **AC4: ToolExecuteResult 类型化** -- ToolExecuteResult 同步支持 ToolContent 类型化数组.

5. **AC5: BashInput.run_in_background** -- BashInput 新增 `runInBackground: Bool?` 字段, 后台执行返回 backgroundTaskId.

6. **AC6: 构建和测试** -- `swift build` 零错误零警告，3400+ 测试零回归.

## Tasks / Subtasks

- [ ] Task 1: ToolAnnotations 类型 (AC: #1, #2)
  - [ ] 创建 ToolAnnotations 结构体
  - [ ] 在 ToolProtocol 中添加 annotations 属性
  - [ ] 更新 defineTool() 支持 annotations 参数
  - [ ] 更新现有内置工具的 isReadOnly 映射到 ToolAnnotations

- [ ] Task 2: ToolContent 类型化 (AC: #3, #4)
  - [ ] 创建 ToolContent 枚举
  - [ ] 在 ToolResult 中添加 typedContent 属性
  - [ ] 在 ToolExecuteResult 中添加 typedContent 属性
  - [ ] 保持 content: String 向后兼容（从 typedContent.text 拼接）
  - [ ] 更新 ToolBuilder 返回类型

- [ ] Task 3: BashInput.run_in_background (AC: #5)
  - [ ] 在 BashInput 添加 runInBackground: Bool? 字段
  - [ ] BashTool 执行逻辑支持后台模式
  - [ ] 后台执行返回 backgroundTaskId

- [ ] Task 4: 验证构建和测试 (AC: #6)

## Dev Notes

### 关键源文件

- `Sources/OpenAgentSDK/Types/ToolTypes.swift` -- ToolProtocol, ToolResult, ToolExecuteResult
- `Sources/OpenAgentSDK/Tools/ToolBuilder.swift` -- defineTool() 4 个重载
- `Sources/OpenAgentSDK/Tools/Core/BashTool.swift` -- BashInput, BashTool

### Epic 16 缺口数据来源

- Story 16-2: ToolAnnotations MISSING 3 字段, ToolResult content 是 String 不是 array

### 实现策略

- ToolAnnotations 所有字段默认 false
- ToolContent 通过 computed property 实现 content: String 向后兼容
- BashInput.runInBackground 优先级：如果沙盒启用且 runInBackground=true，可能需要特殊处理

### References

- [Story 16-2 兼容性报告](_bmad-output/implementation-artifacts/16-2-tool-system-compat.md)

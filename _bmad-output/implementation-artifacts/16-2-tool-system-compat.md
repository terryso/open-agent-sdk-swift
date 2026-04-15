# Story 16.2: 工具系统兼容性验证

Status: pending

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的工具定义和执行与 TypeScript SDK 完全兼容，
以便 TypeScript SDK 的所有工具用法都能在 Swift 中实现。

## Acceptance Criteria

1. **AC1: 示例编译运行** -- 给定 `Examples/CompatToolSystem/` 目录和 `CompatToolSystem` 可执行目标，运行 `swift build` 编译无错误和警告。

2. **AC2: defineTool 等价验证** -- 给定 TS SDK 的 `tool(name, description, inputSchema, handler, { annotations })` 用法，Swift SDK 的 `defineTool()` 支持等价的参数：name、description、inputSchema（JSON Schema 字典）、执行闭包。

3. **AC3: ToolAnnotations 兼容性** -- 验证 Swift SDK 的 ToolAnnotations 包含 TS SDK 的所有字段：`readOnly`（对应 `readOnlyHint`）、`destructive`（对应 `destructiveHint`）、`idempotent`（对应 `idempotentHint`）、`openWorld`（对应 `openWorldHint`）。

4. **AC4: ToolResult 结构兼容** -- 验证 Swift SDK 的 `ToolResult` 与 TS SDK 的 `CallToolResult` 结构兼容：支持 `content` 数组（text/image 类型）和 `isError` 字段。

5. **AC5: 内置工具输入 Schema 验证** -- 逐一检查 Swift SDK 的内置工具 inputSchema 与 TS SDK `ToolInputSchemas` 的字段名称和类型一致性，覆盖至少：BashInput（command, timeout, description, run_in_background）、FileReadInput（file_path, offset, limit）、FileEditInput（file_path, old_string, new_string, replace_all）、GlobInput（pattern, path）、GrepInput（pattern, path, glob, output_mode 等）。

6. **AC6: 内置工具输出结构验证** -- 检查 Swift SDK 的工具输出与 TS SDK `ToolOutputSchemas` 的一致性，特别是 ReadOutput（支持 type 鉴别：text/image/pdf/notebook）、EditOutput（包含 structuredPatch 信息）、BashOutput（stdout/stderr 分离，backgroundTaskId）。

7. **AC7: createSdkMcpServer 等价验证** -- 如果 Swift SDK 支持进程内 MCP 服务器创建，验证与 TS SDK `createSdkMcpServer()` 的等价性。如果不支持，记录为兼容性缺口。

8. **AC8: 兼容性报告输出** -- 示例运行后输出工具系统各验证点的兼容性状态。

## Tasks / Subtasks

- [ ] Task 1: 创建示例目录和文件 (AC: #1)
  - [ ] 创建 `Examples/CompatToolSystem/main.swift`
  - [ ] 在 Package.swift 添加 `CompatToolSystem` 可执行目标

- [ ] Task 2: 自定义工具定义验证 (AC: #2, #3, #4)
  - [ ] 使用 `defineTool()` 创建带 annotations 的自定义工具
  - [ ] 验证 annotations 四个字段全部可设置
  - [ ] 执行工具并验证 ToolResult 结构

- [ ] Task 3: 内置工具 Schema 验证 (AC: #5)
  - [ ] 获取每个内置工具的 inputSchema
  - [ ] 与 TS SDK ToolInputSchemas 逐字段对比
  - [ ] 记录缺失或不一致的字段

- [ ] Task 4: 工具输出结构验证 (AC: #6)
  - [ ] 执行 Read、Edit、Bash、Glob、Grep 工具
  - [ ] 检查输出结构是否包含 TS SDK 文档中的所有字段
  - [ ] 验证 ReadOutput 的 type 鉴别支持

- [ ] Task 5: MCP 服务器创建验证 (AC: #7)
  - [ ] 尝试创建进程内 MCP 服务器
  - [ ] 记录是否有 createSdkMcpServer 等价 API

- [ ] Task 6: 生成兼容性报告 (AC: #8)

## Dev Notes

### 关键 API 对照

| TypeScript SDK | Swift SDK | 关注点 |
|---|---|---|
| `tool(name, desc, schema, handler, { annotations })` | `defineTool(name:description:inputSchema:handler:)` | 工具定义 |
| `ToolAnnotations { readOnlyHint, destructiveHint, idempotentHint, openWorldHint }` | `ToolAnnotations { readOnly, destructive, idempotent, openWorld }` | 注解元数据 |
| `CallToolResult { content, isError }` | `ToolResult { content, isError }` | 工具结果 |
| `createSdkMcpServer({ name, version, tools })` | `InProcessMCPServer` 或等价 | 进程内 MCP |
| 20 个 ToolInputSchemas | 34 个内置工具的 inputSchema | 输入 Schema |
| 18 个 ToolOutputSchemas | 工具输出结构 | 输出结构 |

### 参考文档

- [TypeScript SDK] tool()、createSdkMcpServer()、ToolInputSchemas、ToolOutputSchemas、ToolAnnotations
- [Source] Sources/OpenAgentSDK/Tools/ — 所有工具实现
- [Source] Sources/OpenAgentSDK/Types/ToolTypes.swift — ToolProtocol、ToolResult

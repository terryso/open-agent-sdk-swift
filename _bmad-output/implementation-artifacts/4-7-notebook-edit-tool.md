# Story 4.7: NotebookEdit 工具

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望我的 Agent 可以编辑 Jupyter Notebook (.ipynb) 单元格，
以便它可以处理数据科学工作流。

## Acceptance Criteria

1. **AC1: NotebookEdit 工具 — replace 模式** — 给定 NotebookEdit 工具已注册且指向一个有效的 .ipynb 文件，当 LLM 请求使用 edit_mode="replace" 替换指定索引的单元格内容，则该单元格的 source 被替换为新内容，cell_type 可选更新，文件写回磁盘（FR17）。

2. **AC2: NotebookEdit 工具 — insert 模式** — 给定 NotebookEdit 工具已注册且指向一个有效的 .ipynb 文件，当 LLM 请求使用 edit_mode="insert" 在指定位置插入新单元格，则在 cell_number 位置插入新的 code 或 markdown 单元格（FR17）。

3. **AC3: NotebookEdit 工具 — delete 模式** — 给定 NotebookEdit 工具已注册且指向一个有效的 .ipynb 文件，当 LLM 请求使用 edit_mode="delete" 删除指定索引的单元格，则该单元格从 cells 数组中移除，文件写回磁盘（FR17）。

4. **AC4: 错误处理 — 无效文件/格式** — 给定 NotebookEdit 工具执行时遇到文件不存在、不是有效 JSON、或缺少 cells 数组的情况，当错误被捕获，则返回 is_error=true 的 ToolResult，不中断智能循环（NFR17，规则 #38）。

5. **AC5: 错误处理 — 越界单元格** — 给定 replace 或 delete 操作的 cell_number 超出 cells 数组范围，当工具执行，则返回 is_error=true 的 ToolResult 提示单元格不存在。

6. **AC6: inputSchema 匹配 TS SDK** — 给定 TS SDK 的 NotebookEdit 工具 schema（notebook-edit.ts），当检查 Swift 端的 inputSchema，则字段名称、类型（file_path、command/cell_number/cell_type/source）、required 列表（file_path、cell_number、command）与 TS SDK 一致。

7. **AC7: isReadOnly 分类** — 给定 NotebookEdit 工具，当检查 isReadOnly 属性，则返回 false（写入操作，有副作用）。

8. **AC8: 模块边界合规** — 给定 NotebookEditTool 位于 Tools/Advanced/ 目录，当检查 import 语句，则只导入 Foundation 和 Types/ 中的类型，永不导入 Core/ 或 Stores/（架构规则 #7、#40）。

9. **AC9: 文件路径解析** — 给定相对路径的 file_path，当工具解析路径，则使用 `resolvePath()` 函数结合 `context.cwd` 解析为绝对路径（NFR14，与 FileReadTool/FileWriteTool 一致）。

10. **AC10: Notebook 格式保持** — 给定写入 .ipynb 文件时，当 JSON 序列化，则使用格式化输出（pretty print）保持可读性，且 source 字段按行拆分为 `[String]` 数组（匹配 nbformat 规范，与 TS SDK 行为一致）。

## Tasks / Subtasks

- [x] Task 1: 实现 NotebookEditTool 工厂函数 (AC: #1, #2, #3, #4, #5, #6, #7, #8, #9, #10)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/Advanced/NotebookEditTool.swift`
  - [x] 定义 `NotebookEditInput` Codable 结构体：`file_path`（必填）、`command`（必填，enum: insert/replace/delete）、`cell_number`（必填，Int）、`cell_type`（可选，enum: code/markdown）、`source`（可选，String）、`cell_id`（可选，String）
  - [x] 定义 JSON inputSchema 匹配 TS SDK 的 NotebookEdit schema
  - [x] `createNotebookEditTool()` 工厂函数返回 ToolProtocol（使用 defineTool + ToolExecuteResult 重载）
  - [x] call 逻辑：(1) 解析 file_path；(2) 读取并解析 .ipynb JSON；(3) 验证 cells 数组存在；(4) 根据 command 执行 insert/replace/delete；(5) 格式化写回文件
  - [x] insert: 在 cell_number 位置插入新单元格（默认 code 类型），source 按行拆分
  - [x] replace: 替换指定单元格的 source，可选更新 cell_type
  - [x] delete: 移除指定索引的单元格
  - [x] 所有错误路径返回 ToolExecuteResult(isError: true)

- [x] Task 2: 更新模块入口 (AC: #8)
  - [x] 在 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 中追加 NotebookEdit 工具的重新导出注释

- [x] Task 3: 单元测试 — NotebookEdit 工具 (AC: #1-#10)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/Advanced/NotebookEditToolTests.swift`
  - [x] insert: 插入 code 单元格、插入 markdown 单元格、在头部/尾部/中间插入、验证 source 按行拆分
  - [x] replace: 替换单元格内容、同时替换 cell_type、只替换内容不改变类型
  - [x] delete: 删除中间单元格、删除首尾单元格、删除唯一单元格
  - [x] 错误路径: 文件不存在、无效 JSON、缺少 cells 数组、cell_number 越界（replace/delete）、command 无效值
  - [x] 通用: inputSchema 验证、isReadOnly 验证（false）、相对路径解析验证、模块边界验证

- [x] Task 4: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证 Tools/Advanced/NotebookEditTool.swift 不导入 Core/ 或 Stores/
  - [x] 验证测试可以编译并通过

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 4（多 Agent 编排）的第七个 story，也是最后一个 story
- 本 story 实现一个高级工具（Advanced tier tool）：NotebookEdit
- 与 TeamCreateTool/TeamDeleteTool 不同：NotebookEdit 不需要访问任何 Store — 它是纯文件系统操作工具
- 与 FileWriteTool/FileReadTool 类似的模式：文件 I/O + resolvePath()

**关键简化 — 无需修改 ToolContext/AgentOptions/Agent.swift：**

NotebookEdit 不需要任何 Store 注入。它只需要 `context.cwd` 来解析相对路径，这在 ToolContext 中已经存在。

因此本 story 只需要创建一个新工具文件 + 更新模块入口注释 — **不需要修改任何现有文件**。

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `resolvePath()` | `Tools/Core/FileReadTool.swift` | 解析相对/绝对路径，跨平台 POSIX 兼容 |
| `ToolContext` | `Types/ToolTypes.swift` | 已包含 cwd 字段（无需修改） |
| `ToolExecuteResult` | `Types/ToolTypes.swift` | content + isError |
| `defineTool()` | `Tools/ToolBuilder.swift` | 工厂函数，使用 CodableTool/StructuredCodableTool |
| `FileManager` | Foundation | 文件读写操作 |

### TypeScript SDK 参考对比

**notebook-edit.ts 关键实现要点：**

1. **读取文件** → JSON.parse → 获取 notebook.cells 数组
2. **验证 cells** → 检查 cells 存在且为 Array
3. **insert 命令**：
   - 创建新单元格对象，默认 cell_type="code"
   - source 按换行拆分为字符串数组，每行末尾加 `\n`（最后一行除外）
   - code 类型包含 outputs: [] 和 execution_count: null
   - markdown 类型不包含 outputs 和 execution_count
   - 使用 `splice(cell_number, 0, newCell)` 在指定位置插入
4. **replace 命令**：
   - 检查 cell_number 是否越界
   - 替换 cells[cell_number].source（同样按行拆分）
   - 如果提供了 cell_type，更新 cells[cell_number].cell_type
5. **delete 命令**：
   - 检查 cell_number 是否越界
   - 使用 `splice(cell_number, 1)` 删除
6. **写回文件** → JSON.stringify(notebook, null, 1)（pretty print，缩进 1 空格）
7. **成功返回** → `"Notebook ${command}: cell ${cell_number} in ${filePath}"`

**Swift 端关键差异：**

| 方面 | TypeScript | Swift |
|------|-----------|-------|
| 文件读取 | fs.readFile | String(contentsOfFile:) |
| JSON 解析 | JSON.parse | JSONSerialization.jsonObject |
| 数组插入 | splice(index, 0, item) | cells.insert(item, at: index) |
| 数组删除 | splice(index, 1) | cells.remove(at: index) |
| JSON 写入 | JSON.stringify(obj, null, 1) | JSONSerialization.data(withJSONObject:options:.prettyPrinted) |
| source 格式 | 按行拆分为 string[]，每行加 \n | 同样处理，按行拆分为 [String] |
| 错误处理 | try/catch 返回 is_error:true | ToolExecuteResult(isError: true) |
| 路径解析 | resolve(context.cwd, input.file_path) | resolvePath(input.file_path, cwd: context.cwd) |

### NotebookEditInput 类型定义

```swift
private struct NotebookEditInput: Codable {
    let file_path: String          // 必填
    let command: String            // 必填: "insert" | "replace" | "delete"
    let cell_number: Int           // 必填，0-based 索引
    let cell_type: String?         // 可选: "code" | "markdown"
    let source: String?            // 可选，单元格内容（insert/replace 时使用）
    let cell_id: String?           // 可选，单元格 ID（保留匹配 TS SDK schema）
}
```

### inputSchema 定义（匹配 TS SDK notebook-edit.ts）

```swift
private nonisolated(unsafe) let notebookEditSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "file_path": [
            "type": "string",
            "description": "The absolute path to the notebook file to edit (must be absolute, not relative)"
        ] as [String: Any],
        "command": [
            "type": "string",
            "enum": ["insert", "replace", "delete"],
            "description": "The edit operation to perform"
        ] as [String: Any],
        "cell_number": [
            "type": "number",
            "description": "Cell index (0-based) to operate on"
        ] as [String: Any],
        "cell_type": [
            "type": "string",
            "enum": ["code", "markdown"],
            "description": "Type of cell (for insert/replace). Defaults to 'code'."
        ] as [String: Any],
        "source": [
            "type": "string",
            "description": "Cell content (for insert/replace)"
        ] as [String: Any],
        "cell_id": [
            "type": "string",
            "description": "Optional cell ID for the cell being edited"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["file_path", "command", "cell_number"]
]
```

### 工厂函数实现要点

**核心实现模式：**
1. 解析 file_path 为绝对路径（使用 resolvePath）
2. 读取文件内容为 String → 解析为 [String: Any] JSON 字典
3. 验证 "cells" 键存在且为 [[String: Any]]
4. 根据 command 分支处理
5. 序列化回 JSON 并写入文件
6. 所有错误在 ToolExecuteResult(isError: true) 中捕获

**source 按行拆分的辅助函数：**
```swift
private func splitSource(_ source: String) -> [String] {
    let lines = source.components(separatedBy: "\n")
    return lines.enumerated().map { index, line in
        index < lines.count - 1 ? line + "\n" : line
    }
}
```

**insert 命令：**
```swift
var newCell: [String: Any] = [
    "cell_type": input.cell_type ?? "code",
    "source": splitSource(input.source ?? ""),
    "metadata": [:]
]
if input.cell_type != "markdown" {
    newCell["outputs"] = [[String: Any]]()
    newCell["execution_count"] = NSNull()
}
cells.insert(newCell, at: input.cell_number)
```

**replace 命令：**
```swift
guard input.cell_number < cells.count else {
    return ToolExecuteResult(content: "Error: Cell \(input.cell_number) does not exist", isError: true)
}
cells[input.cell_number]["source"] = splitSource(input.source ?? "")
if let cellType = input.cell_type {
    cells[input.cell_number]["cell_type"] = cellType
}
```

**delete 命令：**
```swift
guard input.cell_number < cells.count else {
    return ToolExecuteResult(content: "Error: Cell \(input.cell_number) does not exist", isError: true)
}
cells.remove(at: input.cell_number)
```

### 实现位置

**新增文件：**
```
Sources/OpenAgentSDK/Tools/Advanced/NotebookEditTool.swift   # NotebookEdit 工厂函数
```

**修改文件（仅注释更新）：**
```
Sources/OpenAgentSDK/OpenAgentSDK.swift                      # 追加 NotebookEdit 工具的重新导出注释
```

**测试文件：**
```
Tests/OpenAgentSDKTests/Tools/Advanced/NotebookEditToolTests.swift   # NotebookEdit 工具测试
```

**不需要修改的文件：**
```
Sources/OpenAgentSDK/Types/ToolTypes.swift      # ToolContext 不需要新增字段
Sources/OpenAgentSDK/Types/AgentTypes.swift     # AgentOptions 不需要新增字段
Sources/OpenAgentSDK/Core/Agent.swift           # 不需要新增注入逻辑
```

### Story 4-6 的经验教训（必须遵循）

1. **nonisolated(unsafe) 用于 schema 常量** — inputSchema 字典需要标记为 `nonisolated(unsafe)` 以避免 Sendable 警告
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - Factory Function`
4. **Codable 解码测试** — 验证 JSON 字段的解码正确性
5. **ToolExecuteResult 重载** — 使用 `defineTool` 返回 `ToolExecuteResult` 的重载（不是 String 返回的），以便显式控制 isError 标志
6. **向后兼容** — 无需修改现有文件

### 反模式警告

- **不要**在 Tools/Advanced/ 中导入 Stores/ 或 Core/ — 违反模块边界（规则 #7、#40）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — 在 ToolExecuteResult 中捕获返回（规则 #38）
- **不要**使用 Apple 专属框架 — 必须跨平台（规则 #43）
- **不要**修改 ToolContext 或 AgentOptions — NotebookEdit 不需要任何 Store 注入
- **不要**使用同步文件 API — 使用 String(contentsOfFile:) 和 write(toFile:) 在 async 上下文中
- **不要**忽略 source 按行拆分 — nbformat 要求 source 为 [String] 数组，不是单一字符串
- **不要**在 code 类型单元格中省略 outputs 和 execution_count — nbformat 规范要求
- **不要**使用 NSJSONSerialization.prettyPrinted 以外的格式 — TS SDK 使用缩进 1 空格

### 测试策略

**NotebookEditTool 测试策略：**
- 使用临时目录创建测试 .ipynb 文件（FileManager.createTemporaryDirectory）
- 每个测试创建一个最小的有效 notebook JSON 文件
- 测试所有三种命令模式 + 所有错误路径

**关键测试场景：**
1. **insert** — 插入 code 单元格（默认类型）、插入 markdown 单元格、在位置 0 插入、在末尾插入、验证 source 按行拆分（每行末尾有 \n）、验证 code 类型有 outputs 和 execution_count
2. **replace** — 替换单元格内容、同时替换 cell_type、只替换 source 不改变 cell_type、cell_number 越界错误
3. **delete** — 删除中间单元格、删除第一个、删除最后一个、cell_number 越界错误
4. **错误路径** — 文件不存在、无效 JSON（非 JSON 内容）、缺少 cells 字段、notebook 没有 cells 数组
5. **通用** — inputSchema 验证、isReadOnly 验证（false）、相对路径解析验证、模块边界验证（不导入 Core/Stores/）

**测试辅助 — 最小 notebook 结构：**
```swift
private func createTestNotebook(at path: String, cells: [[String: Any]] = []) throws {
    let notebook: [String: Any] = [
        "nbformat": 4,
        "nbformat_minor": 5,
        "metadata": [:],
        "cells": cells
    ]
    let data = try JSONSerialization.data(withJSONObject: notebook, options: .prettyPrinted)
    try data.write(to: URL(fileURLWithPath: path))
}
```

### isReadOnly 分类

| 工具 | isReadOnly | 理由 |
|------|-----------|------|
| NotebookEdit | false | 修改文件系统上的 .ipynb 文件（有副作用） |

isReadOnly 的分类影响 ToolExecutor 的调度策略：这是一个变更工具，将被串行执行（规则 #2、FR12）。

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 3.4 (已完成) | 提供 resolvePath() 函数 + FileWriteTool 文件 I/O 模式参考 |
| 4.1 (已完成) | 提供 TaskStore/MailboxStore 基础 |
| 4.2 (已完成) | 提供 TeamStore/AgentRegistry |
| 4.3 (已完成) | 提供 AgentTool |
| 4.4 (已完成) | 提供 SendMessageTool |
| 4.5 (已完成) | 提供 TaskTools |
| 4.6 (已完成) | 提供 TeamCreateTool/TeamDeleteTool — 本 story 的前一个 story |

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.7]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR17 Tools/Advanced/NotebookEditTool.swift]
- [Source: _bmad-output/planning-artifacts/architecture.md#架构边界 Tools 依赖规则]
- [Source: _bmad-output/project-context.md#规则 7 模块边界单向依赖]
- [Source: _bmad-output/project-context.md#规则 38 不从工具内部 throw]
- [Source: _bmad-output/project-context.md#规则 40 Tools 不导入 Core]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/notebook-edit.ts] — TS NotebookEdit Tool 完整实现参考
- [Source: Sources/OpenAgentSDK/Tools/Core/FileReadTool.swift] — resolvePath() 函数
- [Source: Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift] — 文件写入模式参考
- [Source: Sources/OpenAgentSDK/Tools/Advanced/TeamCreateTool.swift] — 工厂函数参考模式
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool 工厂函数
- [Source: _bmad-output/implementation-artifacts/4-6-team-tools-create-delete.md] — 前一 story 经验

### Project Structure Notes

- 新建 `Sources/OpenAgentSDK/Tools/Advanced/NotebookEditTool.swift` — NotebookEdit 工厂函数
- 修改 `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 追加重新导出注释（createNotebookEditTool 工厂函数）
- 新建 `Tests/OpenAgentSDKTests/Tools/Advanced/NotebookEditToolTests.swift`
- 完全对齐架构文档的目录结构和模块边界
- 无需修改 ToolContext、AgentOptions 或 Agent.swift

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (GLM-5.1)

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented NotebookEditTool with full insert/replace/delete command support
- All 30 ATDD tests pass (32 total with filter match including helper test methods)
- Full regression suite passes: 938 tests, 0 failures, 4 skipped (pre-existing)
- Code cells include outputs: [] and execution_count: null per nbformat spec
- Markdown cells omit outputs and execution_count fields
- Source content split into [String] arrays with trailing \n on all but last line
- All error paths return ToolExecuteResult(isError: true) -- never throws
- Relative paths resolved via resolvePath() consistent with FileReadTool/FileWriteTool
- No Core/ or Stores/ imports -- only Foundation (module boundary compliance)
- No Store injection required -- pure filesystem operation

### File List

- `Sources/OpenAgentSDK/Tools/Advanced/NotebookEditTool.swift` (new) -- NotebookEdit factory function
- `Sources/OpenAgentSDK/OpenAgentSDK.swift` (modified) -- Added re-export comment for createNotebookEditTool
- `Tests/OpenAgentSDKTests/Tools/Advanced/NotebookEditToolTests.swift` (existing, created in ATDD red phase) -- 30 test methods

## Change Log

- 2026-04-07: Implemented NotebookEditTool (story 4-7) -- all 4 tasks completed, 30 ATDD tests passing

# Story 5.5: LSP 工具

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望我的 Agent 可以与语言服务器协议（LSP）服务器交互，
以便它可以获得代码智能功能，如跳转到定义和查找引用。

## Acceptance Criteria

1. **AC1: LSP 工具注册** — 给定 LSP 工具已注册，当 LLM 查看可用工具列表，则看到一个名为 "LSP" 的工具，描述为 "Language Server Protocol operations for code intelligence"，支持操作：goToDefinition、findReferences、hover、documentSymbol、workspaceSymbol、goToImplementation、prepareCallHierarchy、incomingCalls、outgoingCalls（FR18）。

2. **AC2: goToDefinition 操作** — 给定 LSP 工具和有效的 file_path + line + character，当 LLM 请求 goToDefinition，则提取光标位置的符号，使用 grep 搜索定义位置，返回匹配结果或 "No definition found for {symbol}"（FR18）。

3. **AC3: findReferences 操作** — 给定 LSP 工具和有效的 file_path + line + character，当 LLM 请求 findReferences，则提取光标位置的符号，使用 grep 搜索所有引用（最多返回 50 行），返回匹配结果或 "No references found for {symbol}"（FR18）。

4. **AC4: hover 操作** — 给定 LSP 工具，当 LLM 请求 hover，则返回提示信息说明需要运行中的语言服务器，建议使用 Read 工具查看文件内容（FR18）。

5. **AC5: documentSymbol 操作** — 给定 LSP 工具和有效的 file_path，当 LLM 请求 documentSymbol，则使用 grep 搜索文件中的函数、类、接口、类型、常量等声明，返回匹配的符号列表或 "No symbols found"（FR18）。

6. **AC6: workspaceSymbol 操作** — 给定 LSP 工具和有效的 query，当 LLM 请求 workspaceSymbol，则使用 grep 在工作区搜索匹配的符号（最多返回 30 行），返回匹配结果或 "No symbols found for {query}"（FR18）。

7. **AC7: 未知操作错误** — 给定 LSP 工具和未知的 operation 值（如 prepareCallHierarchy、incomingCalls、outgoingCalls），当 LLM 请求该操作，则返回提示 "LSP operation {operation} requires a running language server."（FR18）。

8. **AC8: 参数缺失错误** — 给定 LSP 工具，当 LLM 请求需要 file_path + line 的操作但缺少参数，则返回 is_error=true 的 ToolResult 提示所需参数。workspaceSymbol 缺少 query 时同样返回错误。

9. **AC9: isReadOnly 分类** — 给定 LSP 工具，当检查 isReadOnly 属性，则返回 true（所有操作都是只读查询，不修改任何状态）。

10. **AC10: inputSchema 匹配 TS SDK** — 给定 TS SDK 的 LSP 工具 schema（lsp-tool.ts），当检查 Swift 端的 inputSchema，则字段名称、类型和 required 列表与 TS SDK 一致。LSP 有 `operation`（string，必填，enum: goToDefinition/findReferences/hover/documentSymbol/workspaceSymbol/goToImplementation/prepareCallHierarchy/incomingCalls/outgoingCalls）、`file_path`（string，可选）、`line`（number，可选）、`character`（number，可选）、`query`（string，可选）。

11. **AC11: 模块边界合规** — 给定 LSPTool 位于 Tools/Specialist/ 目录，当检查 import 语句，则只导入 Foundation 和 Types/，永不导入 Core/、Stores/ 或其他模块（架构规则 #7、#40）。

12. **AC12: 错误处理不中断循环** — 给定 LSP 工具执行期间发生异常（如 Process 执行失败、文件不存在），当错误被捕获，则返回 is_error=true 的 ToolResult，不会中断 Agent 的智能循环（架构规则 #38）。

13. **AC13: 跨平台 Process 执行** — 给定 LSP 工具使用 Process 执行 grep 命令，当在 macOS 和 Linux 上运行，则使用 Foundation 的 Process 类执行命令（与 BashTool 跨平台模式一致，规则 #43）。

14. **AC14: 符号提取辅助函数** — 给定有效文件路径、行号和字符位置，当调用 getSymbolAtPosition 辅助函数，则从文件内容中提取光标位置的单词（使用 \b\w+\b 正则匹配），返回符号字符串或 nil。

15. **AC15: 工作目录使用 cwd** — 给定 LSP 工具通过 ToolContext.cwd 获取工作目录，当执行 grep 搜索时，则使用 cwd 作为搜索范围的基础目录（与 TS SDK 使用 context.cwd 一致）。

16. **AC16: 不需要 Actor 存储** — 给定 LSP 工具是无状态的只读查询工具，当实现时，则不需要创建任何新的 Actor 存储类，不需要修改 ToolContext 或 AgentOptions（与 WorktreeTool/PlanTool/CronTool/TodoWriteTool 不同，本工具不需要依赖注入）。

17. **AC17: ToolContext.cwd 依赖** — 给定 LSP 工具通过 context.cwd 获取当前工作目录，当工具执行时，则使用 cwd 作为 grep 搜索的起始目录和文件路径解析的基础。

## Tasks / Subtasks

- [x] Task 1: 实现 LSP Input 类型 (AC: #10)
  - [x] 在 `Sources/OpenAgentSDK/Tools/Specialist/LSPTool.swift` 中定义 `LSPInput` Codable 结构体
  - [x] `operation`（必填 String）、`file_path`（可选 String）、`line`（可选 Int）、`character`（可选 Int）、`query`（可选 String）

- [x] Task 2: 定义 inputSchema (AC: #10)
  - [x] 定义 `lspSchema` 常量匹配 TS SDK 的 LSP schema
  - [x] 使用 `nonisolated(unsafe)` 标记 schema 字典
  - [x] operation enum 包含全部 9 个值

- [x] Task 3: 实现符号提取辅助函数 (AC: #14)
  - [x] 实现 `getSymbolAtPosition(filePath:line:character:)` 函数
  - [x] 读取文件内容，按行分割
  - [x] 使用正则提取光标位置处的单词符号
  - [x] 返回符号字符串或 nil

- [x] Task 4: 实现 Process 执行辅助函数 (AC: #13)
  - [x] 实现 `runGrep(arguments:cwd:timeout:)` 辅助函数
  - [x] 使用 Foundation Process 执行 grep/rg 命令
  - [x] 捕获 stdout 和 stderr
  - [x] 设置超时（10 秒，与 TS SDK 一致）

- [x] Task 5: 实现 createLSPTool 工厂函数 (AC: #1-#9, #11, #12, #15, #16, #17)
  - [x] 定义 `createLSPTool()` 返回 ToolProtocol
  - [x] call 逻辑：switch on operation — goToDefinition/goToImplementation/findReferences/hover/documentSymbol/workspaceSymbol/default
  - [x] goToDefinition + goToImplementation: 验证 file_path + line → getSymbolAtPosition → grep 搜索定义
  - [x] findReferences: 验证 file_path + line → getSymbolAtPosition → grep 搜索引用
  - [x] hover: 返回提示信息
  - [x] documentSymbol: 验证 file_path → grep 搜索声明
  - [x] workspaceSymbol: 验证 query → grep 搜索工作区符号
  - [x] default (prepareCallHierarchy/incomingCalls/outgoingCalls): 返回语言服务器提示

- [x] Task 6: 更新模块入口 (AC: #11)
  - [x] 在 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 中追加 createLSPTool 的文档引用

- [x] Task 7: 单元测试 (AC: #1-#17)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`
  - [x] inputSchema 验证（operation 必填、enum 值完整）
  - [x] isReadOnly 验证（true）
  - [x] 模块边界验证
  - [x] goToDefinition: 参数缺失错误、符号提取、grep 结果返回
  - [x] findReferences: 参数缺失错误、符号提取、grep 结果返回
  - [x] hover: 返回提示信息
  - [x] documentSymbol: 参数缺失错误、符号搜索结果
  - [x] workspaceSymbol: 参数缺失错误、符号搜索结果
  - [x] 未知操作: 返回语言服务器提示
  - [x] Process 错误处理: 返回 is_error=true

- [x] Task 8: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证 Tools/Specialist/LSPTool.swift 不导入 Core/ 或 Stores/
  - [x] 验证测试可以编译并通过

- [x] Task 9: E2E 测试
  - [x] 在 `Sources/E2ETest/` 中补充 LSP 工具的 E2E 测试
  - [x] 至少覆盖 happy path：documentSymbol 和 workspaceSymbol 操作

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 5（专业工具与管理存储）的第五个 story
- 本 story 只实现一个专业工具：LSP（不需要 Actor 存储）
- 与 Story 5-1 到 5-4 不同，本 story **不需要创建 Actor 存储类**
- LSP 工具是无状态的只读查询工具，所有操作基于 grep/ripgrep 回退实现

**本 story 与前序 Story 的关键区别：**

| 方面 | Story 5-1 到 5-4 | Story 5-5 (本 story) |
|------|-------------------|----------------------|
| Actor 存储 | 需要创建新 Actor | 不需要 |
| ToolContext 修改 | 需要追加字段 | 不需要 |
| AgentOptions 修改 | 需要追加字段 | 不需要 |
| Agent.swift 修改 | 需要注入 store | 不需要 |
| 依赖注入 | 通过 ToolContext | 仅使用 cwd |
| isReadOnly | 可变（false/true 混合） | 全部 true |
| 工具数量 | 1-3 个 | 1 个 |

**LSP 工具不需要 Actor 存储的原因：**
1. TS SDK 的 LSP 工具是无状态的 —— 不管理任何共享可变状态
2. 所有操作都是只读查询（grep 搜索），结果直接返回
3. 没有需要跨工具调用持久化的数据
4. 工作目录通过 ToolContext.cwd 获取，无需额外存储

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `ToolContext` | `Types/ToolTypes.swift` | 使用 cwd 字段，**不需要修改** |
| `AgentOptions` | `Types/AgentTypes.swift` | **不需要修改** |
| `Agent` | `Core/Agent.swift` | **不需要修改** |
| `ToolExecuteResult` | `Types/ToolTypes.swift` | content + isError |
| `defineTool()` | `Tools/ToolBuilder.swift` | 工厂函数 |
| `BashTool` | `Tools/Core/BashTool.swift` | Process 执行参考模式 |
| `GrepTool` | `Tools/Core/GrepTool.swift` | grep 搜索参考模式 |

### TypeScript SDK 参考对比

**lsp-tool.ts 关键实现要点：**

1. **LSP 工具（单工具，多操作）：**
   - 使用 `execSync` 执行 grep/ripgrep 命令
   - 9 个操作：goToDefinition, findReferences, hover, documentSymbol, workspaceSymbol, goToImplementation, prepareCallHierarchy, incomingCalls, outgoingCalls
   - **isReadOnly: true**（所有操作都是只读查询）
   - **isConcurrencySafe: true**（无状态，可安全并发）
   - 超时：10 秒

2. **getSymbolAtPosition 辅助函数：**
   - 读取文件内容，按行分割
   - 使用 `\b\w+\b` 正则匹配光标位置的单词
   - 返回符号字符串或 null

3. **goToDefinition / goToImplementation：**
   - 需要 file_path + line（character 可选，默认 0）
   - 提取符号 → 使用 grep 搜索定义（function/class/interface/type/const/let/var/export 关键字）
   - 返回匹配结果或 "No definition found for {symbol}"

4. **findReferences：**
   - 需要 file_path + line（character 可选，默认 0）
   - 提取符号 → 使用 grep 搜索所有引用（head -50 限制）
   - 返回匹配结果或 "No references found for {symbol}"

5. **hover：**
   - 不需要任何参数
   - 直接返回提示信息：需要运行中的语言服务器，建议使用 Read 工具

6. **documentSymbol：**
   - 需要 file_path
   - 使用 grep 搜索文件中的声明行
   - 返回匹配的符号或 "No symbols found"

7. **workspaceSymbol：**
   - 需要 query
   - 使用 grep 在工作区搜索匹配符号（head -30 限制）
   - 返回匹配结果或 "No symbols found for {query}"

8. **prepareCallHierarchy / incomingCalls / outgoingCalls：**
   - 进入 default 分支
   - 返回 "LSP operation {operation} requires a running language server."

9. **错误处理：**
   - 外层 try/catch 捕获 execSync 错误
   - 返回 is_error: true + "LSP error: {message}"

**Swift 端关键差异：**

| 方面 | TypeScript | Swift |
|------|-----------|-------|
| 命令执行 | execSync (child_process) | Foundation Process |
| 文件读取 | fs/promises readFile | String(contentsOfFile:) |
| 超时 | execSync timeout 选项 | Process + DispatchQueue 或 async Task with timeout |
| 错误模型 | { content, is_error } | ToolExecuteResult(isError: true) |
| 线程安全 | 无（单线程 Node.js） | 不需要（无状态） |
| 搜索工具 | rg / grep | 通过 Process 调用 rg / grep |

### 类型定义

**LSP Input 结构体（在 LSPTool.swift 中定义）：**

```swift
/// Input type for the LSP tool.
///
/// Field names match the TS SDK's LSP tool schema.
private struct LSPInput: Codable {
    let operation: String      // 必填
    let file_path: String?     // 可选
    let line: Int?             // 可选（0-based）
    let character: Int?        // 可选（0-based）
    let query: String?         // 可选
}
```

### inputSchema 定义（匹配 TS SDK lsp-tool.ts）

```swift
private nonisolated(unsafe) let lspSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "operation": [
            "type": "string",
            "enum": [
                "goToDefinition",
                "findReferences",
                "hover",
                "documentSymbol",
                "workspaceSymbol",
                "goToImplementation",
                "prepareCallHierarchy",
                "incomingCalls",
                "outgoingCalls"
            ],
            "description": "LSP operation to perform"
        ] as [String: Any],
        "file_path": [
            "type": "string",
            "description": "File path for the operation"
        ] as [String: Any],
        "line": [
            "type": "number",
            "description": "Line number (0-based)"
        ] as [String: Any],
        "character": [
            "type": "number",
            "description": "Character position (0-based)"
        ] as [String: Any],
        "query": [
            "type": "string",
            "description": "Symbol name (for workspace symbol search)"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["operation"]
]
```

### 辅助函数实现要点

**getSymbolAtPosition：**
```swift
private func getSymbolAtPosition(
    filePath: String,
    line: Int,
    character: Int
) -> String? {
    guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
        return nil
    }
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
    guard line >= 0, line < lines.count else { return nil }
    let lineText = String(lines[line])

    // Extract word at position using \b\w+\b
    let regex = try? NSRegularExpression(pattern: "\\b\\w+\\b")
    let range = NSRange(lineText.startIndex..., in: lineText)
    guard let matches = regex?.matches(in: lineText, range: range) else { return nil }

    for match in matches {
        guard let matchRange = Range(match.range, in: lineText) else { continue }
        let matchStart = lineText.distance(from: lineText.startIndex, to: matchRange.lowerBound)
        let matchEnd = lineText.distance(from: lineText.startIndex, to: matchRange.upperBound)
        if matchStart <= character && matchEnd >= character {
            return String(lineText[matchRange])
        }
    }
    return nil
}
```

**runGrep（Process 执行辅助函数）：**
```swift
private func runGrep(
    arguments: [String],
    cwd: String,
    timeout: TimeInterval = 10.0
) -> String? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    process.currentDirectoryURL = URL(fileURLWithPath: cwd)
    process.standardOutput = pipe
    process.standardError = Pipe() // 忽略 stderr

    guard let result = try? process.run(),
          process.waitUntilExitWithTimeout(timeout),
          process.terminationStatus == 0 else {
        return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

注意：Swift 的 Process 没有 `waitUntilExit` 超时参数。需要自行实现超时逻辑，例如使用 DispatchQueue.global().asyncAfter 或 Task.sleep + 检查 process.isRunning。参考 BashTool 的 Process 执行模式。

### 工厂函数实现要点

```swift
public func createLSPTool() -> ToolProtocol {
    return defineTool(
        name: "LSP",
        description: "Language Server Protocol operations for code intelligence. Supports go-to-definition, find-references, hover, and symbol lookup.",
        inputSchema: lspSchema,
        isReadOnly: true
    ) { (input: LSPInput, context: ToolContext) async throws -> ToolExecuteResult in
        let cwd = context.cwd

        do {
            switch input.operation {
            case "goToDefinition", "goToImplementation":
                guard let filePath = input.file_path, input.line != nil else {
                    return ToolExecuteResult(content: "file_path and line required", isError: true)
                }
                guard let symbol = getSymbolAtPosition(
                    filePath: filePath,
                    line: input.line!,
                    character: input.character ?? 0
                ) else {
                    return ToolExecuteResult(content: "Could not identify symbol at position", isError: false)
                }
                // 使用 grep 搜索定义
                let results = runGrep(
                    arguments: ["grep", "-rn", ...],
                    cwd: cwd
                )
                return ToolExecuteResult(
                    content: results ?? "No definition found for \"\(symbol)\"",
                    isError: false
                )

            // ... 其他操作类似

            default:
                return ToolExecuteResult(
                    content: "LSP operation \"\(input.operation)\" requires a running language server.",
                    isError: false
                )
            }
        } catch {
            return ToolExecuteResult(
                content: "LSP error: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}
```

### 实现位置

**新增文件：**
```
Sources/OpenAgentSDK/Tools/Specialist/LSPTool.swift  # LSP 工厂函数 + 辅助函数
```

**修改文件：**
```
Sources/OpenAgentSDK/OpenAgentSDK.swift              # 追加 createLSPTool 文档引用
```

**测试文件：**
```
Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift  # LSP 工具测试
```

**注意：不需要修改以下文件（与 5-1 到 5-4 不同）：**
```
Types/ToolTypes.swift    # 不需要追加字段
Types/AgentTypes.swift   # 不需要追加字段
Core/Agent.swift         # 不需要修改 ToolContext 创建
Stores/                  # 不需要创建新 Actor
```

### 前序 Story 的经验教训（必须遵循）

1. **nonisolated(unsafe) 用于 schema 常量** — inputSchema 字典需要标记为 `nonisolated(unsafe)` 以避免 Sendable 警告
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **错误路径测试** — 必须覆盖每个 guard 分支和每个 error case（规则 #28）
4. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - Factory Function`
5. **Codable 解码测试** — 验证 JSON 字段的解码正确性
6. **ToolExecuteResult 重载** — 使用 `defineTool` 返回 `ToolExecuteResult` 的重载
7. **参考 BashTool 的 Process 执行模式** — LSP 工具使用 Process 执行 grep 命令，应参考 BashTool 中已验证的 Process 使用模式
8. **跨平台 Process 执行** — 使用 `/usr/bin/env` 作为可执行路径（macOS 和 Linux 兼容）

### 反模式警告

- **不要**在 Tools/Specialist/ 中导入 Stores/ 或 Core/ — 违反模块边界（规则 #7、#40）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — 在 ToolExecuteResult 中捕获返回（规则 #38）
- **不要**使用 Apple 专属框架 — 必须跨平台（规则 #43）
- **不要**创建 Actor 存储类 — LSP 工具是无状态的，不需要存储
- **不要**修改 ToolContext 或 AgentOptions — 本工具仅使用 cwd 字段
- **不要**修改 Core/Agent.swift — 本工具不需要依赖注入
- **不要**在 LSPInput 中为 line/character 使用非可选类型 — TS SDK 中这些是可选的
- **不要**忘记 Process 超时 — TS SDK 使用 10 秒超时，Swift 端必须同样设置
- **不要**使用 String(contentsOf: URL) 而不处理错误 — 文件可能不存在

### 模块边界注意事项

```
Tools/Specialist/LSPTool.swift  → 只导入 Foundation + Types/（永不导入 Core/、Stores/）
```

LSP 工具是一个纯粹的只读查询工具，所有依赖通过 `defineTool` 闭包中的 `ToolContext` 参数获取（仅使用 cwd）。

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 5-1 (已完成) | WorktreeTools — Specialist 工具文件组织参考 |
| 5-2 (已完成) | PlanTools — Specialist 工具文件组织参考 |
| 5-3 (已完成) | CronTools — Specialist 工具文件组织参考（**最直接的文件组织参考**） |
| 5-4 (已完成) | TodoWriteTool — Specialist 工具文件组织参考 |
| 3-4 (已完成) | FileReadTool — 文件读取和路径处理参考 |
| 3-5 (已完成) | GrepTool — grep 搜索和 Process 执行参考（**最直接的 Process 执行参考**） |
| 3-6 (已完成) | BashTool — Process 执行、超时、跨平台参考 |

### isReadOnly 分类

| 工具 | isReadOnly | 理由 |
|------|-----------|------|
| LSP | true | 所有操作都是只读查询（grep 搜索），不修改任何文件或状态 |

isReadOnly=true 意味着 LSP 工具是只读工具，可被并发执行（规则 #2、FR12）。这与 TS SDK 的 isReadOnly: () => true 一致。

### 测试策略

**LSP 工具测试策略：**
- LSPTool 不依赖外部 LSP 服务器（回退到 grep 搜索）
- 测试需要创建临时文件用于 documentSymbol 和 goToDefinition 操作
- 测试需要验证 Process 执行的 grep 命令结果

**关键测试场景：**
1. **inputSchema 验证** — operation 必填、enum 包含 9 个值、其他字段可选
2. **isReadOnly 验证** — 返回 true
3. **模块边界验证** — 不导入 Core/ 或 Stores/
4. **goToDefinition** — file_path 缺失错误、line 缺失错误、符号提取成功、无定义结果
5. **goToImplementation** — 同 goToDefinition 逻辑
6. **findReferences** — file_path 缺失错误、符号提取成功、无引用结果
7. **hover** — 返回提示信息（不需要参数）
8. **documentSymbol** — file_path 缺失错误、符号搜索成功、无符号结果
9. **workspaceSymbol** — query 缺失错误、搜索成功、无结果
10. **未知操作** — prepareCallHierarchy/incomingCalls/outgoingCalls 返回提示
11. **Process 错误处理** — grep 命令失败返回 is_error=true

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.5]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR18 Specialist tools]
- [Source: _bmad-output/planning-artifacts/architecture.md#项目结构 Tools/Specialist/LSPTool.swift]
- [Source: _bmad-output/project-context.md#规则 7 模块边界单向依赖]
- [Source: _bmad-output/project-context.md#规则 38 不从工具内部 throw]
- [Source: _bmad-output/project-context.md#规则 40 Tools 不导入 Core]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/lsp-tool.ts] — TS LSP Tool 完整实现参考
- [Source: Sources/OpenAgentSDK/Tools/Specialist/CronTools.swift] — Specialist 工具文件组织参考
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool 工厂函数
- [Source: Sources/OpenAgentSDK/Tools/Core/BashTool.swift] — Process 执行参考模式
- [Source: _bmad-output/implementation-artifacts/5-4-todo-store-tools.md] — 前一 story 参考

### Project Structure Notes

- 新建 `Sources/OpenAgentSDK/Tools/Specialist/LSPTool.swift` — LSP 工厂函数 + 辅助函数
- 修改 `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 追加 createLSPTool 文档引用
- 新建 `Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift`
- 完全对齐架构文档的目录结构和模块边界
- **不需要**创建新的 Actor 存储、修改 ToolContext 或 AgentOptions

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Implemented LSPTool.swift with LSPInput struct, lspSchema, getSymbolAtPosition helper, runGrep async helper (with Process execution via GrepOutputAccumulator for thread safety), and createLSPTool factory function
- All 6 operations implemented: goToDefinition/goToImplementation (grep for definition patterns), findReferences (grep for symbol references, max 50 lines), hover (hint message), documentSymbol (grep for declarations in file), workspaceSymbol (grep workspace for query, max 30 lines), default (language server hint)
- Used async/await pattern with withCheckedContinuation for Process execution, consistent with BashTool's approach
- No Actor store needed -- tool is completely stateless and read-only, using only ToolContext.cwd
- Added createLSPTool documentation reference to OpenAgentSDK.swift
- All 36 ATDD unit tests pass (0 failures)
- Full regression suite passes: 1168 tests, 0 failures, 4 skipped (pre-existing)
- Added E2E test section 34 (LSP Tool Direct Handler Tests) covering metadata, hover, documentSymbol, workspaceSymbol, unknown operations, and missing parameters

### File List

**New files:**
- Sources/OpenAgentSDK/Tools/Specialist/LSPTool.swift

**Modified files:**
- Sources/OpenAgentSDK/OpenAgentSDK.swift (added createLSPTool documentation reference)
- Sources/E2ETest/IntegrationTests.swift (added test 34: LSP Tool Direct Handler Tests)

**Pre-existing test files (unchanged, all pass):**
- Tests/OpenAgentSDKTests/Tools/Specialist/LSPToolTests.swift (36 tests by TEA Agent)

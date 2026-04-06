# Story 3.6: 核心系统工具（Bash、AskUser、ToolSearch）

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望我的 Agent 可以执行 Shell 命令、向我提问以及搜索可用工具，
以便它可以执行系统操作并在执行期间与我交互。

## Acceptance Criteria

1. **AC1: Bash 工具执行 Shell 命令** — 给定已注册的 Bash 工具，当 LLM 请求执行 Shell 命令，则命令通过 POSIX shell 执行，捕获 stdout 和 stderr。命令具有可配置的超时时间（默认 120 秒，最大 600 秒）和基于 `ToolContext.cwd` 的工作目录。

2. **AC2: Bash 工具超时处理** — 给定执行时间超过配置超时的 Bash 命令，当超时到期，则进程被终止并返回包含超时信息的错误结果。

3. **AC3: Bash 工具输出截断** — 给定 Bash 工具返回超过 100,000 字符的输出，当结果被组装，则截断为前 50,000 + 后 50,000 字符（中间标记截断位置）。

4. **AC4: Bash 工具非零退出码** — 给定 Bash 命令以非零退出码结束，当输出被组装，则包含退出码信息但不作为 `isError`（退出码本身是正常输出的一部分）。

5. **AC5: AskUser 工具提问用户** — 给定已注册的 AskUser 工具，当 LLM 在执行期间需要用户输入，则显示问题并将用户的响应返回给 Agent。

6. **AC6: AskUser 工具非交互模式** — 给定 AskUser 工具没有配置问题处理器（questionHandler），当工具被调用，则返回信息性消息说明无可用的用户，Agent 应使用最佳判断继续。

7. **AC7: ToolSearch 工具搜索可用工具** — 给定已注册的 ToolSearch 工具，当 LLM 请求搜索可用工具，则返回匹配的工具名称和描述，帮助 LLM 选择合适的工具。支持关键词搜索和精确名称选择（`select:ToolName`）。

8. **AC8: ToolSearch 工具无结果处理** — 给定 ToolSearch 工具搜索后无匹配结果，当搜索完成，则返回描述性的"无匹配"消息。

9. **AC9: 工具注册到 core 层级** — 给定 `getAllBaseTools(tier: .core)` 调用，当 core 层级工具被请求，则 Bash、AskUser、ToolSearch 工具包含在返回数组中（与已有的 Read、Write、Edit、Glob、Grep 并列）。Bash 为 `isReadOnly: false`，AskUser 和 ToolSearch 为 `isReadOnly: true`。

10. **AC10: POSIX 跨平台 Shell 执行** — 给定 Bash 工具在 macOS 和 Linux 上运行，当执行 Shell 命令，则 macOS 使用 `Process`（Foundation），Linux 使用 `Process` 或 `posix_spawn`，两者行为一致（NFR11、NFR12）。

## Tasks / Subtasks

- [ ] Task 1: 创建 BashTool (AC: #1, #2, #3, #4, #10)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/Core/BashTool.swift`
  - [ ] 定义 `BashInput: Codable` 结构体（command: String, timeout: Int?）
  - [ ] 实现 `createBashTool() -> ToolProtocol` 函数（使用 `defineTool` 的 ToolExecuteResult 返回重载）
  - [ ] 使用 `Process`（Foundation）执行 shell 命令（macOS + Linux 跨平台）
  - [ ] 捕获 stdout 和 stderr 到独立缓冲区
  - [ ] 实现超时机制：默认 120 秒，最大 600 秒，通过 `Timer` 或 `DispatchWorkItem` 实现
  - [ ] 实现输出截断：超过 100,000 字符时截断为前 50,000 + "...(truncated)..." + 后 50,000
  - [ ] 组装输出：stdout + stderr + 退出码（非零时追加）
  - [ ] 设置 `isReadOnly: false`（Bash 是变更工具）
  - [ ] 错误处理：进程启动失败等 → 返回 `isError=true` 的 ToolResult
  - [ ] 使用 `context.cwd` 作为进程工作目录

- [ ] Task 2: 创建 AskUserTool (AC: #5, #6)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/Core/AskUserTool.swift`
  - [ ] 定义 `AskUserInput: Codable` 结构体（question: String, options: [String]?）
  - [ ] 实现 `createAskUserTool() -> ToolProtocol` 函数
  - [ ] 设计问题处理器机制：通过全局 setter 函数或 ToolContext 扩展注入回调
  - [ ] 实现有处理器时的交互流程：调用处理器并返回用户回答
  - [ ] 实现无处理器时的非交互模式：返回信息性消息
  - [ ] 设置 `isReadOnly: true`
  - [ ] 错误处理：用户拒绝回答 → 返回 `isError=true`

- [ ] Task 3: 创建 ToolSearchTool (AC: #7, #8)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/Core/ToolSearchTool.swift`
  - [ ] 定义 `ToolSearchInput: Codable` 结构体（query: String, max_results: Int?）
  - [ ] 实现 `createToolSearchTool() -> ToolProtocol` 函数
  - [ ] 设计可搜索工具列表机制：通过全局 setter 函数注入延迟加载的工具列表
  - [ ] 实现精确名称选择：`query` 以 `select:` 开头时按名称精确匹配
  - [ ] 实现关键词搜索：拆分查询词，匹配工具名称和描述
  - [ ] 默认 `max_results: 5`
  - [ ] 无匹配时返回描述性消息
  - [ ] 无延迟工具时返回"无可用延迟工具"消息
  - [ ] 设置 `isReadOnly: true`

- [ ] Task 4: 更新 ToolRegistry 注册 core 工具 (AC: #9)
  - [ ] 修改 `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` 中的 `getAllBaseTools(tier:)` 函数
  - [ ] 当 `tier == .core` 时，在已有数组中追加 `createBashTool()`、`createAskUserTool()`、`createToolSearchTool()`
  - [ ] 更新函数文档注释

- [ ] Task 5: 单元测试 — BashTool (AC: #1, #2, #3, #4, #10)
  - [ ] 创建 `Tests/OpenAgentSDKTests/Tools/Core/BashToolTests.swift`
  - [ ] `testBash_executesCommand_returnsOutput` — 执行命令返回 stdout
  - [ ] `testBash_capturesStderr` — 捕获 stderr
  - [ ] `testBash_nonZeroExitCode_includedInOutput` — 非零退出码包含在输出中
  - [ ] `testBash_timeout_killsProcess` — 超时终止进程
  - [ ] `testBash_largeOutput_truncated` — 大输出被截断
  - [ ] `testBash_usesCwd` — 使用 context.cwd 作为工作目录
  - [ ] `testBash_isReadOnly_false` — isReadOnly 为 false
  - [ ] `testBash_processError_returnsError` — 进程启动失败返回错误

- [ ] Task 6: 单元测试 — AskUserTool (AC: #5, #6)
  - [ ] 创建 `Tests/OpenAgentSDKTests/Tools/Core/AskUserToolTests.swift`
  - [ ] `testAskUser_withHandler_returnsAnswer` — 有处理器时返回用户回答
  - [ ] `testAskUser_withoutHandler_returnsNonInteractive` — 无处理器时返回非交互消息
  - [ ] `testAskUser_handlerError_returnsError` — 处理器抛出错误时返回 isError
  - [ ] `testAskUser_isReadOnly_true` — isReadOnly 为 true

- [ ] Task 7: 单元测试 — ToolSearchTool (AC: #7, #8)
  - [ ] 创建 `Tests/OpenAgentSDKTests/Tools/Core/ToolSearchToolTests.swift`
  - [ ] `testToolSearch_keywordSearch_returnsMatches` — 关键词搜索返回匹配
  - [ ] `testToolSearch_selectByName_returnsExact` — select: 精确匹配
  - [ ] `testToolSearch_noMatches_returnsDescriptiveMessage` — 无匹配返回描述性消息
  - [ ] `testToolSearch_noDeferredTools_returnsMessage` — 无延迟工具返回消息
  - [ ] `testToolSearch_maxResults_limitsOutput` — max_results 限制输出数量
  - [ ] `testToolSearch_isReadOnly_true` — isReadOnly 为 true

- [ ] Task 8: 单元测试 — ToolRegistry core 层级集成 (AC: #9)
  - [ ] 更新 `Tests/OpenAgentSDKTests/Tools/Core/FileToolsRegistryTests.swift`
  - [ ] `testGetAllBaseTools_coreTier_includesBashAskUserToolSearch` — core 层级包含三个新工具
  - [ ] `testGetAllBaseTools_coreTier_bashIsNotReadOnly` — Bash 的 isReadOnly 为 false
  - [ ] `testGetAllBaseTools_coreTier_askUserToolSearchAreReadOnly` — AskUser 和 ToolSearch 的 isReadOnly 为 true

- [ ] Task 9: 编译验证
  - [ ] 运行 `swift build` 确认编译通过
  - [ ] 运行 `swift test` 确认所有测试通过
  - [ ] 验证 `Tools/Core/` 目录下的文件不导入 `Core/`（模块边界规则）

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- 紧接 Story 3.5（搜索工具 Glob/Grep），实现三个系统交互工具
- Bash 工具用于执行 Shell 命令（**变更工具**，`isReadOnly: false`）
- AskUser 工具用于在执行期间向用户提问（只读工具）
- ToolSearch 工具用于搜索延迟加载的工具（只读工具）
- Bash 是 core 层级中唯一的变更工具，ToolExecutor 会将它串行执行
- AskUser 和 ToolSearch 都是只读工具，会被并发执行
- Story 3.7 将添加最后两个 core 工具（WebFetch、WebSearch），完成全部 10 个核心工具

### 已有基础设施（直接复用）

| 类型 | 位置 | 说明 |
|------|------|------|
| `ToolProtocol` | `Types/ToolTypes.swift` | name, description, inputSchema, isReadOnly, call() |
| `ToolResult` | `Types/ToolTypes.swift` | toolUseId, content, isError |
| `ToolContext` | `Types/ToolTypes.swift` | cwd, toolUseId |
| `ToolExecuteResult` | `Types/ToolTypes.swift` | content, isError 结构化返回 |
| `defineTool()` | `Tools/ToolBuilder.swift` | 三个重载（String/ToolExecuteResult/NoInput） |
| `ToolRegistry` | `Tools/ToolRegistry.swift` | toApiTool, toApiTools, getAllBaseTools, filterTools, assembleToolPool |
| `ToolExecutor` | `Core/ToolExecutor.swift` | 并发/串行调度，isReadOnly=false 的工具串行执行 |

### 实现位置

**新增文件：**
```
Sources/OpenAgentSDK/Tools/Core/BashTool.swift        # Bash Shell 命令执行工具
Sources/OpenAgentSDK/Tools/Core/AskUserTool.swift     # 用户交互提问工具
Sources/OpenAgentSDK/Tools/Core/ToolSearchTool.swift   # 工具搜索发现工具
```

**修改文件：**
```
Sources/OpenAgentSDK/Tools/ToolRegistry.swift          # getAllBaseTools 追加三个工具
```

**测试文件：**
```
Tests/OpenAgentSDKTests/Tools/Core/BashToolTests.swift       # Bash 工具测试
Tests/OpenAgentSDKTests/Tools/Core/AskUserToolTests.swift    # AskUser 工具测试
Tests/OpenAgentSDKTests/Tools/Core/ToolSearchToolTests.swift # ToolSearch 工具测试
```

### 工具工厂函数模式

遵循 Story 3.4-3.5 建立的模式（以 FileReadTool 为参考）：

```swift
// Sources/OpenAgentSDK/Tools/Core/BashTool.swift

import Foundation

// MARK: - Input

struct BashInput: Codable {
    let command: String
    let timeout: Int?
}

// MARK: - Factory

public func createBashTool() -> ToolProtocol {
    return defineTool(
        name: "Bash",
        description: "Execute a bash command and return its output. Use for running shell commands, scripts, and system operations.",
        inputSchema: [
            "type": "object",
            "properties": [
                "command": ["type": "string", "description": "The bash command to execute"],
                "timeout": ["type": "integer", "description": "Optional timeout in milliseconds (max 600000, default 120000)"]
            ],
            "required": ["command"]
        ],
        isReadOnly: false  // Bash 是变更工具
    ) { (input: BashInput, context: ToolContext) async throws -> ToolExecuteResult in
        // 实现...
    }
}
```

**关键模式要点（同 Story 3.4-3.5）：**
- `BashInput` / `AskUserInput` / `ToolSearchInput` 定义为 `internal`（不是 `public`）
- 工厂函数是 `public`，返回 `ToolProtocol`
- Bash 使用 `ToolExecuteResult` 返回重载（需要 isError 标志处理超时、进程错误等）
- AskUser 使用 `ToolExecuteResult` 返回重载（需要 isError 处理用户拒绝）
- ToolSearch 使用 `String` 返回重载（不需要 isError）
- `inputSchema` 使用原始 JSON 字典（规则 #41）
- JSON Schema 字段名使用 snake_case（规则 #17）
- 整型参数使用 `"integer"` 而非 `"number"`（Story 3.4 经验）
- 错误在闭包内 do/catch 捕获

### Bash 工具实现要点

**1. Process 执行（跨平台）**

使用 Foundation 的 `Process` 类（macOS 和 Linux 均可用）：

```swift
private func executeProcess(
    command: String,
    cwd: String,
    timeoutMs: Int
) async -> ToolExecuteResult {
    return await withCheckedContinuation { continuation in
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdoutData = Data()
        var stderrData = Data()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handler in
            stdoutData.append(handler.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handler in
            stderrData.append(handler.availableData)
        }

        // 超时处理
        let timeoutWork = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(timeoutMs), execute: timeoutWork)

        process.terminationHandler = { _ in
            timeoutWork.cancel()
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            // 读取剩余数据
            stdoutData.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            stderrData.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            // 组装输出...
            continuation.resume(returning: result)
        }

        do {
            try process.run()
        } catch {
            continuation.resume(returning: ToolExecuteResult(
                content: "Error starting process: \(error.localizedDescription)",
                isError: true
            ))
        }
    }
}
```

**重要注意事项：**
- `Process` 在 macOS 和 Linux 上均可使用（属于 Foundation）
- 不需要区分 macOS 用 `Process` / Linux 用 `posix_spawn` — Foundation 的 Process 在 Linux 上内部就是 posix_spawn
- 使用 `/bin/bash` 作为可执行文件（两个平台均有）
- 超时通过 `DispatchWorkItem` + `process.terminate()` 实现

**2. 输出组装**

```swift
var output = ""
if !stdout.isEmpty { output += stdout }
if !stderr.isEmpty {
    output += (output.isEmpty ? "" : "\n") + stderr
}
let exitCode = process.terminationStatus
if exitCode != 0 {
    output += "\nExit code: \(exitCode)"
}
// 截断
if output.count > 100000 {
    let head = output.prefix(50000)
    let tail = output.suffix(50000)
    output = String(head) + "\n...(truncated)...\n" + String(tail)
}
```

**3. 超时处理**

- 默认超时：120,000 毫秒（120 秒）
- 最大超时：600,000 毫秒（600 秒 / 10 分钟）
- 使用 `min(input.timeout ?? 120000, 600000)` 确保不超上限
- 超时时使用 `process.terminate()` 终止进程
- 超时终止的进程返回包含超时信息的输出

**4. Bash 是变更工具**

`isReadOnly: false` 意味着：
- ToolExecutor 会将 Bash 串行执行（不与其他变更工具并发）
- 权限系统可能对 Bash 执行要求确认（取决于 PermissionMode）

### AskUser 工具实现要点

**1. 问题处理器机制**

TypeScript SDK 使用模块级变量 + setter 函数。Swift 中采用相同模式：

```swift
// Sources/OpenAgentSDK/Tools/Core/AskUserTool.swift

import Foundation

// MARK: - Question Handler (module-level state)

/// Internal question handler storage.
/// Set by the agent when it has an interactive user connection.
private var questionHandler: (@Sendable (String, [String]?) async throws -> String)?

/// Sets the question handler for AskUser tool.
/// Called by the agent when it has an interactive user connection.
public func setQuestionHandler(
    _ handler: @Sendable @escaping (String, [String]?) async throws -> String
) {
    questionHandler = handler
}

/// Clears the question handler for AskUser tool.
public func clearQuestionHandler() {
    questionHandler = nil
}
```

**2. 工具实现**

```swift
struct AskUserInput: Codable {
    let question: String
    let options: [String]?
}

public func createAskUserTool() -> ToolProtocol {
    return defineTool(
        name: "AskUser",
        description: "Ask the user a question and wait for their response. Use when you need clarification or input from the user.",
        inputSchema: [
            "type": "object",
            "properties": [
                "question": ["type": "string", "description": "The question to ask the user"],
                "options": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Optional list of choices for the user"
                ]
            ],
            "required": ["question"]
        ],
        isReadOnly: true
    ) { (input: AskUserInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let handler = questionHandler else {
            // 非交互模式
            var msg = "[Non-interactive mode] Question: \(input.question)"
            if let options = input.options {
                msg += "\nOptions: \(options.joined(separator: ", "))"
            }
            msg += "\n\nNo user available to answer. Proceeding with best judgment."
            return ToolExecuteResult(content: msg, isError: false)
        }

        do {
            let answer = try await handler(input.question, input.options)
            return ToolExecuteResult(content: answer, isError: false)
        } catch {
            return ToolExecuteResult(
                content: "User declined to answer: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}
```

**3. 线程安全考虑**

- `questionHandler` 是模块级变量，不是 actor 隔离的
- 由于工具执行由 ToolExecutor 调度，且 AskUser 本身执行时间短（只是调用回调），这不构成线程安全问题
- 如果后续发现并发问题，可以改为 actor 隔离的存储

### ToolSearch 工具实现要点

**1. 延迟工具列表机制**

```swift
// Sources/OpenAgentSDK/Tools/Core/ToolSearchTool.swift

import Foundation

// MARK: - Deferred Tools (module-level state)

/// Internal deferred tools storage for search.
private var deferredTools: [ToolProtocol] = []

/// Sets the deferred tools available for search.
/// Called by the agent when it loads additional tool tiers.
public func setDeferredTools(_ tools: [ToolProtocol]) {
    deferredTools = tools
}
```

**2. 搜索逻辑**

```swift
struct ToolSearchInput: Codable {
    let query: String
    let max_results: Int?
}

public func createToolSearchTool() -> ToolProtocol {
    return defineTool(
        name: "ToolSearch",
        description: "Search for additional tools that may be available but not yet loaded. Use keyword search or exact name selection.",
        inputSchema: [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "Search query. Use \"select:ToolName\" for exact match or keywords for search."],
                "max_results": ["type": "integer", "description": "Maximum results to return (default: 5)"]
            ],
            "required": ["query"]
        ],
        isReadOnly: true
    ) { (input: ToolSearchInput, context: ToolContext) async throws -> String in
        let maxResults = input.max_results ?? 5

        if deferredTools.isEmpty {
            return "No deferred tools available."
        }

        if input.query.hasPrefix("select:") {
            // 精确名称选择
            let names = input.query.dropFirst(7).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let matches = deferredTools.filter { names.contains($0.name) }
            if matches.isEmpty {
                return "No tools found matching \"\(input.query)\""
            }
            return formatToolList(matches)
        } else {
            // 关键词搜索
            let keywords = input.query.lowercased().split(separator: " ").map(String.init)
            let matches = deferredTools.filter { tool in
                let searchText = "\(tool.name) \(tool.description)".lowercased()
                return keywords.contains { searchText.contains($0) }
            }
            let limited = Array(matches.prefix(maxResults))
            if limited.isEmpty {
                return "No tools found matching \"\(input.query)\""
            }
            return formatToolList(limited)
        }
    }
}

private func formatToolList(_ tools: [ToolProtocol]) -> String {
    let lines = tools.map { "- \($0.name): \(String($0.description.prefix(200)))" }
    return "Found \(tools.count) tool(s):\n" + lines.joined(separator: "\n")
}
```

### getAllBaseTools 更新

当前 `getAllBaseTools(tier:)` 已有 Read/Write/Edit/Glob/Grep。需要追加三个新工具：

```swift
public func getAllBaseTools(tier: ToolTier) -> [ToolProtocol] {
    switch tier {
    case .core:
        return [
            createReadTool(),
            createWriteTool(),
            createEditTool(),
            createGlobTool(),
            createGrepTool(),
            createBashTool(),
            createAskUserTool(),
            createToolSearchTool(),
            // Story 3.7 将添加: WebFetch, WebSearch
        ]
    case .advanced, .specialist:
        return []
    }
}
```

### 反模式警告

- **不要**从工具执行闭包内部 throw 错误导致循环中断 — 在闭包内 do/catch 并返回 ToolExecuteResult（规则 #38）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**在 `Tools/` 中导入 `Core/` — 工具文件只依赖 Foundation 和 Types（规则 #40）
- **不要**使用 Codable 做 LLM API 通信 — inputSchema 使用原始 `[String: Any]` 字典（规则 #41）
- **不要**使用 Apple 专属框架 — Process 属于 Foundation，非 Apple 专属（规则 #43）
- **不要**在 Bash 中使用 `async let` 或非结构化 `Task` — 使用 withCheckedContinuation（规则 #46）
- **不要**在 Tools/Core/ 中创建 actor — 工具是无状态的 struct/闭包
- **不要**使用 `posix_spawn` 直接调用 — Foundation 的 `Process` 在 Linux 上已经封装了 posix_spawn
- **不要**对 Bash 退出码设置 `isError: true` — 非零退出码是正常输出的一部分，不是工具执行错误
- **不要**使用 `String.count` 做大输出截断的字符计数 — 对大字符串使用 `String.index` 更高效

### 前一 Story 关键经验（Story 3.5 搜索工具）

1. **resolvePath 函数已可用** — 在 `FileReadTool.swift` 中定义的 `resolvePath(_:cwd:)` 是 `internal` 级别，同模块内可复用
2. **CodableTool 模式已验证** — defineTool 的三个返回重载均已正常工作
3. **JSON Schema "integer" 类型** — 整型参数使用 `"integer"` 而非 `"number"`
4. **@unchecked Sendable 模式** — CodableTool/StructuredCodableTool 使用此模式
5. **所有测试使用临时目录** — 使用 `NSTemporaryDirectory()` + UUID 创建隔离测试目录
6. **测试命名约定** — `test{ToolName}_{scenario}_{expectedBehavior}` 格式
7. **Bash 工具不需要 resolvePath** — Bash 直接使用 `context.cwd` 作为进程工作目录
8. **GlobTool 的 matchesGlob 函数** — 已暴露为 internal（GrepTool 也复用了它）

### TypeScript SDK 参考

**bash.ts — Shell 命令执行：**
- 使用 Node.js `child_process.spawn`
- 参数：`command`（必须）、`timeout`（可选，默认 120000，最大 600000）
- 捕获 stdout + stderr + 退出码
- 超过 100,000 字符截断（前 50,000 + "...(truncated)..." + 后 50,000）
- `isReadOnly: false`、`isConcurrencySafe: false`
- 支持通过 `context.abortSignal` 取消

**ask-user.ts — 用户交互提问：**
- 使用模块级变量 `questionHandler` + setter 函数
- 参数：`question`（必须）、`options`（可选）、`allow_multiselect`（可选）
- 有处理器时调用处理器获取回答
- 无处理器时返回非交互模式消息
- `isReadOnly: true`、`isConcurrencySafe: false`（因为等待用户输入会阻塞并发）

**tool-search.ts — 工具搜索发现：**
- 使用模块级变量 `deferredTools` + setter 函数
- 参数：`query`（必须）、`max_results`（可选，默认 5）
- `select:ToolName` 精确选择模式
- 关键词搜索模式：拆分查询词，匹配名称+描述
- 无延迟工具时返回消息
- `isReadOnly: true`、`isConcurrencySafe: true`

### Swift 与 TypeScript 实现差异

| 方面 | TypeScript | Swift |
|------|-----------|-------|
| Shell 执行 | `child_process.spawn` | `Process`（Foundation） |
| 超时 | `spawn` 的 `timeout` 选项 | `DispatchWorkItem` + `process.terminate()` |
| 取消 | `AbortSignal` | 暂不实现（v1.0 范围外，后续 story 可能添加） |
| 模块状态 | 模块级变量 | 模块级变量（同模式） |
| 回调类型 | `(q, opts?) => Promise<string>` | `@Sendable (String, [String]?) async throws -> String` |
| 输出截断 | `Buffer` slice | `String.prefix/suffix` |

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 3.1 (已完成) | 提供 ToolProtocol、ToolRegistry、ToolTier，本 story 消费 |
| 3.2 (已完成) | 提供 defineTool() 工厂函数，本 story 使用创建工具 |
| 3.3 (已完成) | 提供 ToolExecutor 并发/串行调度，Bash(isReadOnly:false) 将被串行执行 |
| 3.4 (已完成) | 提供 resolvePath() 和工具实现模式参考 |
| 3.5 (已完成) | 提供 matchesGlob() 和搜索工具模式参考 |
| 3.7 (后续) | 网络工具（WebFetch、WebSearch），完成 core 层级全部 10 个工具 |

### 测试策略

**Bash 测试使用安全命令：**
```swift
class BashToolTests: XCTestCase {
    // 使用安全的、无副作用的命令进行测试
    // echo, pwd, true, false, cat /dev/null 等
    // 不要使用 rm、mkfs 等危险命令
}
```

**Bash 测试关键验证点：**
- 执行 `echo "hello"` 返回 "hello"
- 执行 `echo err >&2` 捕获 stderr
- 执行 `exit 1` 输出包含退出码
- 执行 `sleep 999` 配合短超时被终止
- 执行产生大量输出的命令验证截断
- 使用 `pwd` 验证工作目录正确
- isReadOnly 为 false

**AskUser 测试关键验证点：**
- 设置处理器后调用返回用户回答
- 不设置处理器返回非交互模式消息
- 处理器抛出错误时返回 isError=true
- isReadOnly 为 true

**ToolSearch 测试关键验证点：**
- 设置延迟工具后关键词搜索返回匹配
- `select:ToolName` 精确匹配
- 无匹配返回描述性消息
- 不设置延迟工具返回"无可用延迟工具"
- max_results 限制输出数量
- isReadOnly 为 true

### 性能考虑

1. **Bash 进程启动** — `Process` 启动开销约 10-50ms（取决于平台），对于 Shell 命令执行是可接受的
2. **输出截断** — 使用 `String.prefix/suffix` 而非 `String.count` + subscript，避免 O(n) 遍历两次
3. **ToolSearch 搜索** — 延迟工具列表通常很小（<50），线性搜索足够快
4. **AskUser** — 响应时间取决于用户，无性能要求

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.6]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD4 工具系统 — ToolProtocol]
- [Source: _bmad-output/planning-artifacts/architecture.md#项目结构 — Tools/Core/BashTool.swift, AskUserTool.swift, ToolSearchTool.swift]
- [Source: _bmad-output/project-context.md#规则 38 工具错误不 throw]
- [Source: _bmad-output/project-context.md#规则 41 不用 Codable 做 LLM 通信]
- [Source: _bmad-output/project-context.md#规则 43 不用 Apple 专属框架]
- [Source: _bmad-output/implementation-artifacts/3-5-core-search-tools-glob-grep.md] — 前一 story
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol, ToolResult, ToolContext
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool, CodableTool, StructuredCodableTool
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] — getAllBaseTools, toApiTool
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/bash.ts] — TS Bash 工具参考
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/ask-user.ts] — TS AskUser 工具参考
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/tool-search.ts] — TS ToolSearch 工具参考

### Project Structure Notes

- 新增 `Sources/OpenAgentSDK/Tools/Core/BashTool.swift`、`AskUserTool.swift`、`ToolSearchTool.swift` — 架构文档已定义此路径
- 修改 `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` — 更新 `getAllBaseTools(tier:)` 函数追加三个工具
- 新增 `Tests/OpenAgentSDKTests/Tools/Core/BashToolTests.swift`、`AskUserToolTests.swift`、`ToolSearchToolTests.swift`
- 更新 `Tests/OpenAgentSDKTests/Tools/Core/FileToolsRegistryTests.swift` — 追加注册测试
- 完全对齐架构文档的目录结构

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

# Story 5.1: WorktreeStore 与 Worktree 工具

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望我的 Agent 可以管理 Git Worktree，
以便它可以在仓库的隔离副本上工作。

## Acceptance Criteria

1. **AC1: WorktreeStore Actor** — 给定 WorktreeStore Actor 实现，当并发创建、查询和退出 worktree 时，则所有操作通过 Actor 隔离实现线程安全（FR44、FR48），且 worktree 状态（id、path、branch、originalCwd、status）被正确追踪。

2. **AC2: EnterWorktree 工具** — 给定 EnterWorktree 工具已注册且 ToolContext 包含 worktreeStore，当 LLM 请求使用给定名称进入 Worktree，则通过 `git worktree add` 创建新的 Git Worktree，WorktreeStore 追踪活跃的 Worktree 状态，工作目录概念上切换到新 worktree（FR44）。

3. **AC3: ExitWorktree 工具** — 给定活跃的 Worktree，当 LLM 请求退出 Worktree 且 action="remove"，则执行 `git worktree remove` 清理 worktree，可选删除分支，WorktreeStore 更新状态。当 action="keep"，则仅从存储中移除追踪但保留文件系统上的 worktree。

4. **AC4: Worktree 不存在错误** — 给定 ExitWorktree 请求但提供的 worktree ID 不在 WorktreeStore 中，当工具执行，则返回 is_error=true 的 ToolResult 提示 worktree 未找到。

5. **AC5: 非 Git 仓库错误** — 给定当前工作目录不是 Git 仓库，当 EnterWorktree 尝试创建 worktree，则返回 is_error=true 的 ToolResult 提示不在 Git 仓库中。

6. **AC6: inputSchema 匹配 TS SDK** — 给定 TS SDK 的 Worktree 工具 schema（worktree-tools.ts），当检查 Swift 端的 inputSchema，则字段名称、类型和 required 列表与 TS SDK 一致。

7. **AC7: isReadOnly 分类** — 给定 EnterWorktree 和 ExitWorktree 工具，当检查 isReadOnly 属性，则两个工具都返回 false（两者都有文件系统副作用）。

8. **AC8: 模块边界合规** — 给定 WorktreeStore 位于 Stores/ 目录，WorktreeTools 位于 Tools/Specialist/ 目录，当检查 import 语句，则 WorktreeStore 只导入 Foundation 和 Types/；WorktreeTools 只导入 Foundation 和 Types/，永不导入 Core/ 或 Stores/（架构规则 #7、#40）。

9. **AC9: 错误处理不中断循环** — 给定 Worktree 工具执行期间发生异常（如 worktreeStore 为 nil、git 命令失败、worktree 不存在），当错误被捕获，则返回 is_error=true 的 ToolResult，不会中断 Agent 的智能循环（架构规则 #38）。

10. **AC10: ToolContext 依赖注入** — 给定 Tools/Specialist/ 不能导入 Stores/ 的架构约束（规则 #7、#40），当 Worktree 工具需要访问 WorktreeStore，则通过 ToolContext 携带的 `worktreeStore` 引用实现跨模块调用（与 SendMessageTool 的 teamStore 注入模式一致）。

11. **AC11: POSIX 跨平台 Shell 执行** — 给定 worktree 操作需要执行 git 命令，当在 macOS 和 Linux 上运行，则使用 `Process`（Foundation）执行 git 命令，捕获 stdout/stderr，不使用 Apple 专属 API（NFR11、NFR12、规则 #35）。

## Tasks / Subtasks

- [x] Task 1: 定义 Worktree 类型 (AC: #1, #8)
  - [x] 在 `Sources/OpenAgentSDK/Types/TaskTypes.swift` 中追加 Worktree 相关类型
  - [x] `WorktreeStatus` 枚举：active, removed
  - [x] `WorktreeEntry` 结构体：id, path, branch, originalCwd, status, createdAt
  - [x] `WorktreeStoreError` 枚举：worktreeNotFound(id), gitCommandFailed(message)

- [x] Task 2: 实现 WorktreeStore Actor (AC: #1, #8, #11)
  - [x] 创建 `Sources/OpenAgentSDK/Stores/WorktreeStore.swift`
  - [x] `create(name:originalCwd:)` — 执行 `git worktree add` 并追踪状态
  - [x] `get(id:)` — 按 ID 获取 worktree
  - [x] `list()` — 列出所有活跃 worktree
  - [x] `remove(id:force:deleteBranch:)` — 执行 `git worktree remove` 并清理
  - [x] `keep(id:)` — 仅移除追踪，保留文件系统
  - [x] `clear()` — 清除所有追踪状态
  - [x] 使用 `Process` 执行 git 命令，捕获 stdout/stderr

- [x] Task 3: 扩展 ToolContext 和 AgentOptions (AC: #10)
  - [x] 在 `Sources/OpenAgentSDK/Types/ToolTypes.swift` 中为 `ToolContext` 追加 `worktreeStore: WorktreeStore?` 字段
  - [x] 更新 init 添加新参数（默认值 nil，保持现有调用兼容）
  - [x] 在 `Sources/OpenAgentSDK/Types/AgentTypes.swift` 中为 `AgentOptions` 追加 `worktreeStore: WorktreeStore?` 字段
  - [x] 更新 init 参数列表追加 `worktreeStore: WorktreeStore? = nil`

- [x] Task 4: 集成到 Agent 创建点 (AC: #10)
  - [x] 修改 `Sources/OpenAgentSDK/Core/Agent.swift` 中 prompt() 和 stream() 方法的 ToolContext 创建点
  - [x] ToolContext 创建时传入 worktreeStore（从 options.worktreeStore 获取）

- [x] Task 5: 实现 EnterWorktreeTool 工厂函数 (AC: #2, #5, #6, #7, #8, #9)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/Specialist/WorktreeTools.swift`
  - [x] 定义 `EnterWorktreeInput` Codable 结构体：`name`（必填）
  - [x] 定义 JSON inputSchema 匹配 TS SDK 的 EnterWorktree schema
  - [x] `createEnterWorktreeTool()` 工厂函数返回 ToolProtocol
  - [x] call 逻辑：(1) 从 context 获取 worktreeStore；(2) 缺少依赖时返回错误；(3) 调用 worktreeStore.create()；(4) 捕获 WorktreeStoreError 返回 isError=true

- [x] Task 6: 实现 ExitWorktreeTool 工厂函数 (AC: #3, #4, #6, #7, #8, #9)
  - [x] 在同一文件 `Sources/OpenAgentSDK/Tools/Specialist/WorktreeTools.swift` 中定义 ExitWorktreeTool
  - [x] 定义 `ExitWorktreeInput` Codable 结构体：`id`（必填）、`action`（可选，"keep" 或 "remove"，默认 "remove"）
  - [x] `createExitWorktreeTool()` 工厂函数
  - [x] call 逻辑：(1) 从 context 获取 worktreeStore；(2) 调用 worktreeStore.remove() 或 keep()；(3) 捕获 WorktreeStoreError 返回 isError=true

- [x] Task 7: 更新模块入口 (AC: #8)
  - [x] 在 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 中追加 WorktreeStore、Worktree 工具的重新导出注释

- [x] Task 8: 单元测试 — WorktreeStore (AC: #1)
  - [x] 创建 `Tests/OpenAgentSDKTests/Stores/WorktreeStoreTests.swift`
  - [x] 测试 create/get/list/remove/keep/clear 方法
  - [x] 测试错误路径：worktreeNotFound、gitCommandFailed
  - [x] 测试 Actor 隔离并发安全

- [x] Task 9: 单元测试 — Worktree 工具 (AC: #2-#9)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/Specialist/WorktreeToolsTests.swift`
  - [x] EnterWorktree: 创建成功、worktreeStore 为 nil 错误、git 命令失败错误
  - [x] ExitWorktree: remove 成功、keep 成功、worktree 不存在错误、worktreeStore 为 nil 错误
  - [x] 通用: inputSchema 验证、isReadOnly 验证（两者都为 false）、模块边界验证

- [x] Task 10: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证 Tools/Specialist/ 中的文件不导入 Core/ 或 Stores/
  - [x] 验证 Stores/ 中的文件只导入 Foundation 和 Types/
  - [x] 验证测试可以编译并通过

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 5（专业工具与管理存储）的第一个 story
- 本 story 实现一个 Actor 存储（WorktreeStore）和两个专业工具（Specialist tier tools）：EnterWorktree、ExitWorktree
- 这是 Epic 5 的基础 story — 后续 PlanStore、CronStore、TodoStore 都遵循相同模式

**架构关键问题 — Tools/ 不能导入 Stores/ 或 Core/：**

与 SendMessageTool（teamStore）、TaskTools（taskStore）的注入模式完全一致，本 story 需要通过 ToolContext 注入 WorktreeStore。

**解决方案：通过 ToolContext 注入 WorktreeStore actor 引用**

```
Types/TaskTypes.swift:         追加 WorktreeEntry, WorktreeStatus, WorktreeStoreError 类型
Types/ToolTypes.swift:         ToolContext 追加 worktreeStore 字段
Types/AgentTypes.swift:        AgentOptions 追加 worktreeStore 字段
Stores/WorktreeStore.swift:    新建 WorktreeStore actor
Core/Agent.swift:              创建 ToolContext 时注入 WorktreeStore
Tools/Specialist/WorktreeTools.swift: 通过 context.worktreeStore 使用
```

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `ToolContext` | `Types/ToolTypes.swift` | 需追加 worktreeStore 字段 |
| `AgentOptions` | `Types/AgentTypes.swift` | 需追加 worktreeStore 字段 |
| `Agent` | `Core/Agent.swift` | prompt()/stream() 需注入 worktreeStore |
| `ToolExecuteResult` | `Types/ToolTypes.swift` | content + isError |
| `defineTool()` | `Tools/ToolBuilder.swift` | 工厂函数 |
| `TeamStore` | `Stores/TeamStore.swift` | Actor 存储实现参考模式 |

### TypeScript SDK 参考对比

**worktree-tools.ts 关键实现要点：**

1. **EnterWorktree**：
   - 使用 `activeWorktrees` Map 追踪活跃 worktree（TS: `Map<string, { path, branch, originalCwd }>`）
   - 生成唯一分支名（如 `worktree-{name}-{random}`）
   - 执行 `git worktree add {path} -b {branch}` 创建 worktree
   - 存储 path、branch、originalCwd 到 Map
   - 返回包含 path 和 branch 的成功消息

2. **ExitWorktree**：
   - 从 Map 中查找 worktree（按 id）
   - 不存在时返回 is_error=true
   - action="remove"（默认）：执行 `git worktree remove --force`，尝试 `git branch -D` 删除分支
   - action="keep"：仅从 Map 中移除追踪
   - 返回操作结果

**Swift 端关键差异：**

| 方面 | TypeScript | Swift |
|------|-----------|-------|
| 存储实现 | 模块级 Map | WorktreeStore Actor |
| ID 追踪 | Map key = id | WorktreeEntry.id |
| 线程安全 | 无（单线程 Node.js） | Actor 隔离 |
| 错误处理 | 直接返回 content string | ToolExecuteResult(isError: true) |
| Shell 执行 | execSync | Process（Foundation） |
| 分支清理 | try/catch 静默失败 | 同样，分支可能有未合并提交 |

### 类型定义

**WorktreeEntry（在 TaskTypes.swift 中追加）：**

```swift
/// Status of a worktree entry.
public enum WorktreeStatus: String, Sendable, Equatable, Codable {
    case active
    case removed
}

/// A worktree entry tracked by the WorktreeStore.
public struct WorktreeEntry: Sendable, Equatable, Codable {
    public let id: String
    public let path: String
    public let branch: String
    public let originalCwd: String
    public let createdAt: String
    public var status: WorktreeStatus

    public init(
        id: String,
        path: String,
        branch: String,
        originalCwd: String,
        createdAt: String,
        status: WorktreeStatus = .active
    ) {
        self.id = id
        self.path = path
        self.branch = branch
        self.originalCwd = originalCwd
        self.createdAt = createdAt
        self.status = status
    }
}

/// Errors thrown by WorktreeStore operations.
public enum WorktreeStoreError: Error, Equatable, LocalizedError, Sendable {
    case worktreeNotFound(id: String)
    case gitCommandFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .worktreeNotFound(let id):
            return "Worktree not found: \(id)"
        case .gitCommandFailed(let message):
            return "Git command failed: \(message)"
        }
    }
}
```

### ToolContext 扩展

```swift
// 在 ToolContext 中追加
public let worktreeStore: WorktreeStore?

public init(
    // ... 现有参数 ...
    worktreeStore: WorktreeStore? = nil
) {
    // ...
    self.worktreeStore = worktreeStore
}
```

### AgentOptions 扩展

```swift
// 在 AgentOptions 中追加
public var worktreeStore: WorktreeStore?
```

更新 `init` 和 `init(from:)` 追加 `worktreeStore: WorktreeStore? = nil`。

### WorktreeStore 实现

```swift
public actor WorktreeStore {
    private var worktrees: [String: WorktreeEntry] = [:]
    private var worktreeCounter: Int = 0
    private let dateFormatter: ISO8601DateFormatter = { ... }()

    public init() {}

    public func create(name: String, originalCwd: String) throws -> WorktreeEntry {
        worktreeCounter += 1
        let id = "worktree_\(worktreeCounter)"
        let branch = "worktree-\(name)"
        let worktreePath = (originalCwd as NSString).appendingPathComponent(".claude/worktrees/\(name)")

        // 执行 git worktree add
        let result = executeGitCommand(
            args: ["worktree", "add", worktreePath, "-b", branch],
            cwd: originalCwd
        )
        guard result.exitCode == 0 else {
            throw WorktreeStoreError.gitCommandFailed(message: result.stderr)
        }

        let entry = WorktreeEntry(
            id: id, path: worktreePath, branch: branch,
            originalCwd: originalCwd,
            createdAt: dateFormatter.string(from: Date())
        )
        worktrees[id] = entry
        return entry
    }

    public func get(id: String) -> WorktreeEntry? { worktrees[id] }
    public func list() -> [WorktreeEntry] { Array(worktrees.values) }

    public func remove(id: String, force: Bool = true) throws -> Bool {
        guard let entry = worktrees[id] else {
            throw WorktreeStoreError.worktreeNotFound(id: id)
        }
        let forceFlag = force ? "--force" : ""
        let args = force ? ["worktree", "remove", entry.path, "--force"] : ["worktree", "remove", entry.path]
        let result = executeGitCommand(args: args, cwd: entry.originalCwd)
        // 即使 remove 失败也尝试清理分支（与 TS SDK 行为一致）
        _ = executeGitCommand(args: ["branch", "-D", entry.branch], cwd: entry.originalCwd)
        worktrees.removeValue(forKey: id)
        return true
    }

    public func keep(id: String) throws -> Bool {
        guard worktrees[id] != nil else {
            throw WorktreeStoreError.worktreeNotFound(id: id)
        }
        worktrees.removeValue(forKey: id)
        return true
    }

    public func clear() { worktrees.removeAll(); worktreeCounter = 0 }

    // 执行 git 命令的辅助方法
    private func executeGitCommand(args: [String], cwd: String) -> (exitCode: Int32, stdout: String, stderr: String) {
        // 使用 Process（macOS/Linux 均支持的 Foundation API）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        // 捕获 stdout/stderr...
    }
}
```

### 工具 Input 类型

```swift
// EnterWorktree
private struct EnterWorktreeInput: Codable {
    let name: String  // 必填
}

// ExitWorktree
private struct ExitWorktreeInput: Codable {
    let id: String          // 必填
    let action: String?     // 可选: "keep" 或 "remove"，默认 "remove"
}
```

### inputSchema 定义（匹配 TS SDK worktree-tools.ts）

**EnterWorktree schema：**
```swift
private nonisolated(unsafe) let enterWorktreeSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "name": [
            "type": "string",
            "description": "Name for the worktree. Used to create branch and directory name."
        ] as [String: Any],
    ] as [String: Any],
    "required": ["name"]
]
```

**ExitWorktree schema：**
```swift
private nonisolated(unsafe) let exitWorktreeSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": [
            "type": "string",
            "description": "Worktree ID to exit from"
        ] as [String: Any],
        "action": [
            "type": "string",
            "enum": ["keep", "remove"],
            "description": "Whether to keep or remove the worktree directory. Default: remove"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]
```

### 工厂函数实现要点

**EnterWorktreeTool：**
```swift
public func createEnterWorktreeTool() -> ToolProtocol {
    return defineTool(
        name: "EnterWorktree",
        description: "Create an isolated git worktree for parallel work. The agent will work in the worktree without affecting the main working tree.",
        inputSchema: enterWorktreeSchema,
        isReadOnly: false
    ) { (input: EnterWorktreeInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let worktreeStore = context.worktreeStore else {
            return ToolExecuteResult(content: "Error: WorktreeStore not available.", isError: true)
        }
        do {
            let entry = try await worktreeStore.create(
                name: input.name,
                originalCwd: context.cwd
            )
            return ToolExecuteResult(
                content: "Worktree created: \(entry.id) at \(entry.path) (branch: \(entry.branch))",
                isError: false
            )
        } catch let error as WorktreeStoreError {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}
```

**ExitWorktreeTool：**
```swift
public func createExitWorktreeTool() -> ToolProtocol {
    return defineTool(
        name: "ExitWorktree",
        description: "Exit and optionally remove a git worktree, returning to the original working directory.",
        inputSchema: exitWorktreeSchema,
        isReadOnly: false
    ) { (input: ExitWorktreeInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let worktreeStore = context.worktreeStore else {
            return ToolExecuteResult(content: "Error: WorktreeStore not available.", isError: true)
        }
        let action = input.action ?? "remove"
        do {
            if action == "keep" {
                _ = try await worktreeStore.keep(id: input.id)
                return ToolExecuteResult(content: "Worktree kept: \(input.id)", isError: false)
            } else {
                _ = try await worktreeStore.remove(id: input.id)
                return ToolExecuteResult(content: "Worktree removed: \(input.id)", isError: false)
            }
        } catch let error as WorktreeStoreError {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}
```

### 实现位置

**新增文件：**
```
Sources/OpenAgentSDK/Stores/WorktreeStore.swift             # WorktreeStore Actor
Sources/OpenAgentSDK/Tools/Specialist/WorktreeTools.swift   # EnterWorktree + ExitWorktree 工厂函数
```

**修改文件：**
```
Sources/OpenAgentSDK/Types/TaskTypes.swift     # 追加 WorktreeEntry, WorktreeStatus, WorktreeStoreError
Sources/OpenAgentSDK/Types/ToolTypes.swift     # 追加 worktreeStore 到 ToolContext
Sources/OpenAgentSDK/Types/AgentTypes.swift    # 追加 worktreeStore 到 AgentOptions
Sources/OpenAgentSDK/Core/Agent.swift          # ToolContext 创建时注入 worktreeStore
Sources/OpenAgentSDK/OpenAgentSDK.swift        # 追加重新导出注释
```

**测试文件：**
```
Tests/OpenAgentSDKTests/Stores/WorktreeStoreTests.swift         # WorktreeStore 测试
Tests/OpenAgentSDKTests/Tools/Specialist/WorktreeToolsTests.swift  # Worktree 工具测试
```

### 前序 Story 的经验教训（必须遵循）

1. **nonisolated(unsafe) 用于 schema 常量** — inputSchema 字典需要标记为 `nonisolated(unsafe)` 以避免 Sendable 警告
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **Actor 测试** — 使用 `await` 访问 actor 隔离方法
4. **错误路径测试** — 必须覆盖每个 guard 分支和每个 error case（规则 #28）
5. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - Factory Function`
6. **Codable 解码测试** — 验证 JSON 字段的解码正确性
7. **ToolExecuteResult 重载** — 使用 `defineTool` 返回 `ToolExecuteResult` 的重载
8. **向后兼容** — ToolContext/AgentOptions 新增字段默认值 nil，不破坏现有代码
9. **ISO8601 日期格式** — 使用 `ISO8601DateFormatter` 带 `.withInternetDateTime, .withFractionalSeconds`

### 反模式警告

- **不要**在 Tools/Specialist/ 中导入 Stores/ 或 Core/ — 违反模块边界（规则 #7、#40）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — 在 ToolExecuteResult 中捕获返回（规则 #38）
- **不要**在 Worktree 工具中直接创建 WorktreeStore — 必须通过 ToolContext 注入
- **不要**使用 Apple 专属框架 — 必须跨平台（规则 #43）
- **不要**使用 `posix_spawn` — 使用 Foundation 的 `Process`（macOS 和 Linux 都支持）
- **不要**在分支删除失败时抛出错误 — 分支可能有未合并提交，静默失败（与 TS SDK 行为一致）
- **不要**修改 ToolContext 的现有 init 签名（会破坏现有代码）— 新增参数默认值 nil 保持兼容
- **不要**将 WorktreeStore 类型定义在 Stores/ 中 — 类型必须定义在 Types/TaskTypes.swift 中（Store 只依赖 Types/）

### 模块边界注意事项

```
Types/TaskTypes.swift                 → 追加 WorktreeEntry, WorktreeStatus, WorktreeStoreError（叶节点）
Types/ToolTypes.swift                 → 追加 worktreeStore 到 ToolContext（叶节点）
Types/AgentTypes.swift                → 追加 worktreeStore 到 AgentOptions
Stores/WorktreeStore.swift            → 只导入 Foundation + Types/（永不导入 Core/ 或 Tools/）
Core/Agent.swift                      → 修改 ToolContext 创建点注入 worktreeStore
Tools/Specialist/WorktreeTools.swift  → 只导入 Foundation + Types/（永不导入 Core/ 或 Stores/）
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 4.1 (已完成) | 提供 TaskStore/MailboxStore 基础 — Actor 存储模式参考 |
| 4.2 (已完成) | 提供 TeamStore/AgentRegistry — Actor 存储模式参考 |
| 4.4 (已完成) | 提供 SendMessageTool + ToolContext 注入 store 的模式 — **直接复用此模式** |
| 4.5 (已完成) | 提供 TaskTools + ToolContext.taskStore 注入模式 |
| 5.2 (后续) | PlanStore 与 Plan 工具 — 类似模式 |
| 5.3 (后续) | CronStore 与 Cron 工具 — 类似模式 |
| 5.4 (后续) | TodoStore 与 TodoWrite 工具 — 类似模式 |

### 测试策略

**WorktreeStore 测试策略：**
- WorktreeStore 中的 git 命令依赖真实 git 环境，测试需在临时 Git 仓库中进行
- 创建临时目录 → `git init` → 作为 originalCwd 使用
- 测试所有方法：create, get, list, remove, keep, clear

**关键测试场景：**
1. **create** — 创建成功验证 ID/path/branch、git 命令失败时抛出 gitCommandFailed
2. **get** — 获取存在的 worktree、获取不存在的返回 nil
3. **list** — 空列表、创建后返回正确数量
4. **remove** — 删除成功、worktree 不存在时抛出 worktreeNotFound
5. **keep** — 保留成功、worktree 不存在时抛出 worktreeNotFound
6. **clear** — 清除后 list 为空

**WorktreeTools 测试策略：**
- 使用 mock 或真实的 WorktreeStore（取决于是否能在测试中创建 git 仓库）
- 如果 git 不可用，测试 worktreeStore 为 nil 的错误路径和 inputSchema 验证
- 每个 Error case 都要测试

**关键工具测试场景：**
1. **EnterWorktree** — worktreeStore 为 nil 时返回错误、inputSchema 验证、isReadOnly 验证
2. **ExitWorktree** — worktreeStore 为 nil 时返回错误、action=remove、action=keep、worktree 不存在错误、inputSchema 验证、isReadOnly 验证
3. **通用** — 模块边界验证（不导入 Core/Stores/）

### isReadOnly 分类

| 工具 | isReadOnly | 理由 |
|------|-----------|------|
| EnterWorktree | false | 创建文件系统上的 git worktree（有副作用） |
| ExitWorktree | false | 删除或修改文件系统上的 git worktree（有副作用） |

isReadOnly 的分类影响 ToolExecutor 的调度策略：两者都是变更工具，将被串行执行（规则 #2、FR12）。

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.1]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR44 WorktreeStore]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR48 Actor-based thread-safe stores]
- [Source: _bmad-output/planning-artifacts/architecture.md#架构边界 Stores 依赖规则]
- [Source: _bmad-output/planning-artifacts/architecture.md#项目结构 Stores/ 和 Tools/Specialist/]
- [Source: _bmad-output/project-context.md#规则 1 Actor 用于共享可变状态]
- [Source: _bmad-output/project-context.md#规则 7 模块边界单向依赖]
- [Source: _bmad-output/project-context.md#规则 38 不从工具内部 throw]
- [Source: _bmad-output/project-context.md#规则 40 Tools 不导入 Core]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/worktree-tools.ts] — TS Worktree Tools 完整实现参考
- [Source: Sources/OpenAgentSDK/Stores/TeamStore.swift] — Actor 存储实现参考模式
- [Source: Sources/OpenAgentSDK/Types/TaskTypes.swift] — 类型定义参考
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolContext（需追加 worktreeStore）
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions（需追加 worktreeStore）
- [Source: Sources/OpenAgentSDK/Tools/Advanced/SendMessageTool.swift] — ToolContext 注入模式参考
- [Source: Sources/OpenAgentSDK/Tools/Advanced/TeamCreateTool.swift] — 工厂函数参考模式
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool 工厂函数
- [Source: _bmad-output/implementation-artifacts/4-7-notebook-edit-tool.md] — 前一 story 经验
- [Source: _bmad-output/implementation-artifacts/4-6-team-tools-create-delete.md] — 前一 story 经验

### Project Structure Notes

- 新建 `Sources/OpenAgentSDK/Stores/WorktreeStore.swift` — WorktreeStore Actor
- 新建 `Sources/OpenAgentSDK/Tools/Specialist/WorktreeTools.swift` — EnterWorktree + ExitWorktree 工厂函数
- 修改 `Sources/OpenAgentSDK/Types/TaskTypes.swift` — 追加 WorktreeEntry, WorktreeStatus, WorktreeStoreError
- 修改 `Sources/OpenAgentSDK/Types/ToolTypes.swift` — 追加 worktreeStore 到 ToolContext
- 修改 `Sources/OpenAgentSDK/Types/AgentTypes.swift` — 追加 worktreeStore 到 AgentOptions
- 修改 `Sources/OpenAgentSDK/Core/Agent.swift` — ToolContext 创建时注入 worktreeStore
- 修改 `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 追加重新导出注释
- 新建 `Tests/OpenAgentSDKTests/Stores/WorktreeStoreTests.swift`
- 新建 `Tests/OpenAgentSDKTests/Tools/Specialist/WorktreeToolsTests.swift`
- 完全对齐架构文档的目录结构和模块边界

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No debug issues encountered. All implementations compiled and tests passed on first run.

### Completion Notes List

- Task 1-7: All implementation files were already in place from a prior session. Verified correctness against story spec.
- Task 8: WorktreeStoreTests — 21 tests covering create/get/list/remove/keep/clear, error paths (worktreeNotFound, gitCommandFailed), Actor concurrency safety, type Codable/Equatable roundtrips.
- Task 9: WorktreeToolsTests — 24 tests covering EnterWorktree/ExitWorktree factory, inputSchema validation, isReadOnly=false, nil store error, non-git directory error, malformed input resilience, ToolContext injection, module boundary validation, and integration workflows (enter-then-remove, enter-then-keep).
- Task 10: swift build passed, all 986 tests in full regression suite passed (0 failures, 4 skipped).
- AC8 verified: WorktreeStore.swift and WorktreeTools.swift only import Foundation — no Core/ or Stores/ imports.

### File List

**New files:**
- Sources/OpenAgentSDK/Stores/WorktreeStore.swift
- Sources/OpenAgentSDK/Tools/Specialist/WorktreeTools.swift
- Tests/OpenAgentSDKTests/Stores/WorktreeStoreTests.swift
- Tests/OpenAgentSDKTests/Tools/Specialist/WorktreeToolsTests.swift

**Modified files:**
- Sources/OpenAgentSDK/Types/TaskTypes.swift — Added WorktreeStatus, WorktreeEntry, WorktreeStoreError
- Sources/OpenAgentSDK/Types/ToolTypes.swift — Added worktreeStore field to ToolContext
- Sources/OpenAgentSDK/Types/AgentTypes.swift — Added worktreeStore field to AgentOptions
- Sources/OpenAgentSDK/Core/Agent.swift — Injected worktreeStore into ToolContext creation points (prompt + stream)
- Sources/OpenAgentSDK/OpenAgentSDK.swift — Added re-export documentation comments

### Change Log

- 2026-04-07: Story 5-1 implementation complete. All 10 tasks verified, 45 tests passing (21 store + 24 tools), full regression suite green (986 tests, 0 failures).

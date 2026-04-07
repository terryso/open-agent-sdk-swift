# Story 4.5: 任务工具（Create/List/Update/Get/Stop/Output）

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望我的 Agent 使用专用工具管理任务，
以便复杂的多步骤工作可以被追踪和协调。

## Acceptance Criteria

1. **AC1: TaskCreate 工具** — 给定 TaskCreate 工具已注册且 ToolContext 包含 taskStore，当 LLM 请求创建带有 subject 的任务，则在 TaskStore 中创建状态为 "pending" 的新任务（FR37），返回包含任务 ID、subject 和 status 的成功结果。

2. **AC2: TaskList 工具** — 给定 TaskList 工具已注册且 ToolContext 包含 taskStore，当 LLM 请求列出任务（可选 status/owner 过滤），则返回所有匹配任务及其 ID、status、subject 和 owner。

3. **AC3: TaskUpdate 工具** — 给定 TaskUpdate 工具已注册且 ToolContext 包含 taskStore，当 LLM 请求更新任务（status/description/owner/output），则任务在 TaskStore 中更新（强制执行状态转换规则），返回更新后的任务信息。

4. **AC4: TaskGet 工具** — 给定 TaskGet 工具已注册且 ToolContext 包含 taskStore，当 LLM 请求获取任务详情，则返回包含所有字段的完整任务信息（FR37）。

5. **AC5: TaskStop 工具** — 给定 TaskStop 工具已注册且 ToolContext 包含 taskStore，当 LLM 请求停止任务，则任务状态更新为 "cancelled"，可选 reason 记录到 output。

6. **AC6: TaskOutput 工具** — 给定 TaskOutput 工具已注册且 ToolContext 包含 taskStore，当 LLM 请求获取任务输出，则返回任务的 output 字段内容（FR37）。

7. **AC7: ToolContext 依赖注入** — 给定 Tools/ 不能导入 Stores/ 的架构约束（规则 #7、#40），当任务工具需要访问 TaskStore，则通过 ToolContext 携带 `taskStore` 引用实现跨模块调用（与 SendMessageTool 的 mailboxStore/teamStore 注入模式一致）。

8. **AC8: 模块边界合规** — 给定所有六个任务工具位于 Tools/Advanced/ 目录，当检查 import 语句，则只导入 Foundation 和 Types/ 中的类型，永不导入 Core/ 或 Stores/（架构规则 #7、#40）。

9. **AC9: 错误处理不中断循环** — 给定任务工具执行期间发生异常（如 taskStore 为 nil、任务不存在、无效状态转换），当错误被捕获，则返回 is_error=true 的 ToolResult，不会中断父 Agent 的智能循环（架构规则 #38）。

10. **AC10: inputSchema 匹配 TS SDK** — 给定 TS SDK 的 Task 工具 schema，当检查 Swift 端的 inputSchema，则字段名称、类型和 required 列表与 TS SDK 一致（参考 task-tools.ts）。

## Tasks / Subtasks

- [ ] Task 1: 扩展 ToolContext 添加 taskStore 字段 (AC: #7)
  - [ ] 在 `Sources/OpenAgentSDK/Types/ToolTypes.swift` 中为 `ToolContext` 追加 `taskStore: TaskStore?` 字段
  - [ ] 更新 init 添加新参数（默认值 nil，保持现有调用兼容）
  - [ ] 保持 Sendable 合规（TaskStore 是 actor，天然 Sendable）

- [ ] Task 2: 实现 TaskCreateTool 工厂函数 (AC: #1, #8, #9, #10)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/Advanced/TaskCreateTool.swift`
  - [ ] 定义 `TaskCreateInput` Codable 结构体：`subject`（必填）、`description`（可选）、`owner`（可选）、`status`（可选，限制为 pending/inProgress）
  - [ ] 定义 JSON inputSchema 匹配 TS SDK 的 TaskCreate schema
  - [ ] `createTaskCreateTool()` 工厂函数返回 ToolProtocol（使用 defineTool + ToolExecuteResult 重载）
  - [ ] call 逻辑：(1) 从 context 获取 taskStore；(2) 缺少依赖时返回错误；(3) 调用 taskStore.create()；(4) 格式化输出

- [ ] Task 3: 实现 TaskListTool 工厂函数 (AC: #2, #8, #9, #10)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/Advanced/TaskListTool.swift`
  - [ ] 定义 `TaskListInput` Codable 结构体：`status`（可选）、`owner`（可选）
  - [ ] `createTaskListTool()` 工厂函数
  - [ ] call 逻辑：(1) 从 context 获取 taskStore；(2) 调用 taskStore.list()；(3) 格式化为 `[id] STATUS - subject (owner: xxx)` 格式

- [ ] Task 4: 实现 TaskUpdateTool 工厂函数 (AC: #3, #8, #9, #10)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/Advanced/TaskUpdateTool.swift`
  - [ ] 定义 `TaskUpdateInput` Codable 结构体：`id`（必填）、`status`/`description`/`owner`/`output`（可选）
  - [ ] `createTaskUpdateTool()` 工厂函数
  - [ ] call 逻辑：(1) 从 context 获取 taskStore；(2) 调用 taskStore.update()；(3) 捕获 TaskStoreError（taskNotFound、invalidStatusTransition）返回 isError=true

- [ ] Task 5: 实现 TaskGetTool 工厂函数 (AC: #4, #8, #9, #10)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/Advanced/TaskGetTool.swift`
  - [ ] 定义 `TaskGetInput` Codable 结构体：`id`（必填）
  - [ ] `createTaskGetTool()` 工厂函数
  - [ ] call 逻辑：(1) 从 context 获取 taskStore；(2) 调用 taskStore.get()；(3) 任务不存在时返回错误

- [ ] Task 6: 实现 TaskStopTool 工厂函数 (AC: #5, #8, #9, #10)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/Advanced/TaskStopTool.swift`
  - [ ] 定义 `TaskStopInput` Codable 结构体：`id`（必填）、`reason`（可选）
  - [ ] `createTaskStopTool()` 工厂函数
  - [ ] call 逻辑：(1) 从 context 获取 taskStore；(2) 调用 taskStore.update(status: .cancelled, output: reason)；(3) 任务不存在时返回错误

- [ ] Task 7: 实现 TaskOutputTool 工厂函数 (AC: #6, #8, #9, #10)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/Advanced/TaskOutputTool.swift`
  - [ ] 定义 `TaskOutputInput` Codable 结构体：`id`（必填）
  - [ ] `createTaskOutputTool()` 工厂函数
  - [ ] call 逻辑：(1) 从 context 获取 taskStore；(2) 调用 taskStore.get()；(3) 返回 output 字段或 "(no output yet)"

- [ ] Task 8: 集成到 Agent 创建点 (AC: #7)
  - [ ] 修改 `Sources/OpenAgentSDK/Core/Agent.swift` 中 prompt() 和 stream() 方法的 ToolContext 创建点
  - [ ] ToolContext 创建时传入 taskStore（从 options.taskStore 获取）
  - [ ] 确保向后兼容：如果 tools 中不包含任务工具，taskStore 可以为 nil

- [ ] Task 9: 扩展 AgentOptions 添加 taskStore 字段 (AC: #7)
  - [ ] 在 `Sources/OpenAgentSDK/Types/AgentTypes.swift` 中为 `AgentOptions` 追加 `taskStore: TaskStore?` 字段
  - [ ] 更新 init 和 `init(from:)` 两个初始化器，添加 taskStore 参数（默认值 nil）

- [ ] Task 10: 更新模块入口 (AC: #8)
  - [ ] 在 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 中追加任务工具的重新导出注释
  - [ ] 确认所有任务工具文件不导入 Core/ 或 Stores/

- [ ] Task 11: 单元测试 — 六个任务工具 (AC: #1-#10)
  - [ ] 创建 `Tests/OpenAgentSDKTests/Tools/Advanced/TaskToolsTests.swift`
  - [ ] TaskCreate: 创建任务（必填 subject、可选字段、验证 taskStore 返回值）
  - [ ] TaskList: 列出全部、按 status 过滤、按 owner 过滤、空列表
  - [ ] TaskUpdate: 更新 status、description、owner、output；任务不存在错误；无效状态转换错误
  - [ ] TaskGet: 获取存在任务、任务不存在错误
  - [ ] TaskStop: 停止任务（状态变为 cancelled）、带 reason、任务不存在错误
  - [ ] TaskOutput: 获取输出、无输出时返回 "(no output yet)"、任务不存在错误
  - [ ] 通用：taskStore 为 nil 时返回错误、inputSchema 验证、isReadOnly 验证、模块边界验证

- [ ] Task 12: 编译验证
  - [ ] 运行 `swift build` 确认编译通过
  - [ ] 验证 Tools/Advanced/ 中的文件不导入 Core/ 或 Stores/
  - [ ] 验证测试可以编译并通过

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 4（多 Agent 编排）的第五个 story，建立在 Story 4-1（TaskStore/MailboxStore）、4-2（TeamStore/AgentRegistry）、4-3（AgentTool）、4-4（SendMessageTool）之上
- 本 story 实现六个高级工具（Advanced tier tools）：TaskCreate、TaskList、TaskUpdate、TaskGet、TaskStop、TaskOutput
- 与 SendMessageTool 类似的架构挑战：Tools/ 不能导入 Stores/ 或 Core/

**架构关键问题 — Tools/ 不能导入 Stores/ 或 Core/：**

与 SendMessageTool 使用 ToolContext 注入 MailboxStore/TeamStore 的模式完全一致，本 story 需要通过 ToolContext 注入 TaskStore。这是已经建立的成熟模式，直接复用即可。

**解决方案：通过 ToolContext 注入 TaskStore actor 引用**

```
Types/ToolTypes.swift:  ToolContext 追加 taskStore 字段
Types/AgentTypes.swift: AgentOptions 追加 taskStore 字段
Core/Agent.swift:       创建 ToolContext 时注入 TaskStore 实例
Tools/Advanced/Task*Tool.swift: 通过 context.taskStore 使用
```

这比 SendMessageTool 更简单，因为：
1. 只需要注入一个 store（TaskStore），而不是两个
2. TaskStore 的方法签名完全匹配工具需求（create/list/update/get 已存在）
3. TaskStore 已有完整的错误类型（TaskStoreError.taskNotFound、TaskStoreError.invalidStatusTransition）

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `TaskStore` | `Stores/TaskStore.swift` | Story 4-1 创建，create/list/get/update/delete/clear 方法 |
| `Task` | `Types/TaskTypes.swift` | id, subject, description, status, owner, createdAt, updatedAt, output, blockedBy, blocks, metadata |
| `TaskStatus` | `Types/TaskTypes.swift` | pending, inProgress, completed, failed, cancelled |
| `TaskStoreError` | `Types/TaskTypes.swift` | taskNotFound(id), invalidStatusTransition(from, to) |
| `ToolContext` | `Types/ToolTypes.swift` | cwd, toolUseId, agentSpawner, mailboxStore, teamStore, senderName；需追加 taskStore |
| `ToolExecuteResult` | `Types/ToolTypes.swift` | content + isError |
| `defineTool()` | `Tools/ToolBuilder.swift` | 工厂函数，使用 CodableTool/StructuredCodableTool |
| `Agent` | `Core/Agent.swift` | prompt()/stream() 方法中的 ToolContext 创建点 |

### TaskStore 方法与工具的映射

| 工具 | TaskStore 方法 | 签名 |
|------|---------------|------|
| TaskCreate | `create(subject:description:owner:status:)` | `-> Task` |
| TaskList | `list(status:owner:)` | `-> [Task]` |
| TaskUpdate | `update(id:status:description:owner:output:)` | `throws -> Task` |
| TaskGet | `get(id:)` | `-> Task?` |
| TaskStop | `update(id:status:output:)` with status=.cancelled | `throws -> Task` |
| TaskOutput | `get(id:)` then return `.output` | `-> Task?` |

**注意 TaskStop 没有独立的 TaskStore 方法** — 它复用 `update()` 方法，传入 `status: .cancelled` 和可选的 `output: "Stopped: \(reason)"`。

### 实现位置

**修改文件：**
```
Sources/OpenAgentSDK/Types/ToolTypes.swift            # 追加 taskStore 到 ToolContext
Sources/OpenAgentSDK/Types/AgentTypes.swift           # 追加 taskStore 到 AgentOptions
Sources/OpenAgentSDK/Core/Agent.swift                 # prompt()/stream() 创建 ToolContext 时注入 taskStore
Sources/OpenAgentSDK/OpenAgentSDK.swift               # 追加重新导出注释
```

**新增文件：**
```
Sources/OpenAgentSDK/Tools/Advanced/TaskCreateTool.swift   # TaskCreate 工厂函数
Sources/OpenAgentSDK/Tools/Advanced/TaskListTool.swift     # TaskList 工厂函数
Sources/OpenAgentSDK/Tools/Advanced/TaskUpdateTool.swift   # TaskUpdate 工厂函数
Sources/OpenAgentSDK/Tools/Advanced/TaskGetTool.swift      # TaskGet 工厂函数
Sources/OpenAgentSDK/Tools/Advanced/TaskStopTool.swift     # TaskStop 工厂函数
Sources/OpenAgentSDK/Tools/Advanced/TaskOutputTool.swift   # TaskOutput 工厂函数
```

**测试文件：**
```
Tests/OpenAgentSDKTests/Tools/Advanced/TaskToolsTests.swift   # 所有六个任务工具的测试
```

### 类型定义

**ToolContext 扩展（在现有定义上追加字段）：**

```swift
public struct ToolContext: Sendable {
    public let cwd: String
    public let toolUseId: String
    public let agentSpawner: (any SubAgentSpawner)?
    public let mailboxStore: MailboxStore?
    public let teamStore: TeamStore?
    public let senderName: String?
    public let taskStore: TaskStore?           // 新增

    public init(
        cwd: String,
        toolUseId: String = "",
        agentSpawner: (any SubAgentSpawner)? = nil,
        mailboxStore: MailboxStore? = nil,
        teamStore: TeamStore? = nil,
        senderName: String? = nil,
        taskStore: TaskStore? = nil            // 新增
    ) { ... }
}
```

**AgentOptions 扩展：**

```swift
public struct AgentOptions: Sendable {
    // ... 现有字段 ...
    public var taskStore: TaskStore?           // 新增：用于任务管理工具
}
```

更新 `init` 和 `init(from:)` 两个初始化器。

**各个工具的 Input 类型（私有 Codable 类型）：**

```swift
// TaskCreateTool.swift
private struct TaskCreateInput: Codable {
    let subject: String       // 必填
    let description: String?  // 可选
    let owner: String?        // 可选
    let status: String?       // 可选，"pending" 或 "in_progress"
}

// TaskListTool.swift
private struct TaskListInput: Codable {
    let status: String?       // 可选过滤
    let owner: String?        // 可选过滤
}

// TaskUpdateTool.swift
private struct TaskUpdateInput: Codable {
    let id: String            // 必填
    let status: String?       // 可选
    let description: String?  // 可选
    let owner: String?        // 可选
    let output: String?       // 可选
}

// TaskGetTool.swift
private struct TaskGetInput: Codable {
    let id: String            // 必填
}

// TaskStopTool.swift
private struct TaskStopInput: Codable {
    let id: String            // 必填
    let reason: String?       // 可选
}

// TaskOutputTool.swift
private struct TaskOutputInput: Codable {
    let id: String            // 必填
}
```

字段命名使用简短名匹配 TS SDK 的 inputSchema 和 LLM 端 JSON 字段（参考 project-context.md 规则 #19）。

### inputSchema 定义（匹配 TS SDK task-tools.ts）

**TaskCreate schema：**
```swift
private nonisolated(unsafe) let taskCreateSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "subject": ["type": "string", "description": "Short task title"] as [String: Any],
        "description": ["type": "string", "description": "Detailed task description"] as [String: Any],
        "owner": ["type": "string", "description": "Task owner/assignee"] as [String: Any],
        "status": ["type": "string", "enum": ["pending", "in_progress"], "description": "Initial status"] as [String: Any],
    ] as [String: Any],
    "required": ["subject"]
]
```

**TaskList schema：**
```swift
private nonisolated(unsafe) let taskListSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "status": ["type": "string", "description": "Filter by status"] as [String: Any],
        "owner": ["type": "string", "description": "Filter by owner"] as [String: Any],
    ] as [String: Any]
    // no required fields
]
```

**TaskUpdate schema：**
```swift
private nonisolated(unsafe) let taskUpdateSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": ["type": "string", "description": "Task ID"] as [String: Any],
        "status": ["type": "string", "enum": ["pending", "in_progress", "completed", "failed", "cancelled"]] as [String: Any],
        "description": ["type": "string", "description": "Updated description"] as [String: Any],
        "owner": ["type": "string", "description": "New owner"] as [String: Any],
        "output": ["type": "string", "description": "Task output/result"] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]
```

**TaskGet schema：**
```swift
private nonisolated(unsafe) let taskGetSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": ["type": "string", "description": "Task ID"] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]
```

**TaskStop schema：**
```swift
private nonisolated(unsafe) let taskStopSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": ["type": "string", "description": "Task ID to stop"] as [String: Any],
        "reason": ["type": "string", "description": "Reason for stopping"] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]
```

**TaskOutput schema：**
```swift
private nonisolated(unsafe) let taskOutputSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": ["type": "string", "description": "Task ID"] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]
```

### 各工具工厂函数实现要点

**通用模式（所有六个工具都遵循）：**
1. 从 `context.taskStore` 获取 TaskStore（guard let，否则返回错误）
2. 解码 `TaskStatus` 时，从 rawValue 字符串构造（`TaskStatus(rawValue: input.status)`）
3. 调用 TaskStore 方法（使用 `await` 访问 actor 隔离方法）
4. 捕获 `TaskStoreError` 返回 isError=true 的结果
5. 成功路径格式化输出

**TaskCreateTool：**
```swift
public func createTaskCreateTool() -> ToolProtocol {
    return defineTool(
        name: "TaskCreate",
        description: "Create a new task for tracking work progress. Tasks help organize multi-step operations.",
        inputSchema: taskCreateSchema,
        isReadOnly: false
    ) { (input: TaskCreateInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        let initialStatus: TaskStatus = input.status.flatMap { TaskStatus(rawValue: $0) } ?? .pending
        let task = await taskStore.create(
            subject: input.subject,
            description: input.description,
            owner: input.owner,
            status: initialStatus
        )
        return ToolExecuteResult(
            content: "Task created: \(task.id) - \"\(task.subject)\" (\(task.status.rawValue))",
            isError: false
        )
    }
}
```

**TaskListTool（isReadOnly=true）：**
```swift
public func createTaskListTool() -> ToolProtocol {
    return defineTool(
        name: "TaskList",
        description: "List all tasks with their status, ownership, and dependencies.",
        inputSchema: taskListSchema,
        isReadOnly: true  // 注意：只读工具
    ) { (input: TaskListInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        let status: TaskStatus? = input.status.flatMap { TaskStatus(rawValue: $0) }
        let tasks = await taskStore.list(status: status, owner: input.owner)
        if tasks.isEmpty {
            return ToolExecuteResult(content: "No tasks found.", isError: false)
        }
        let lines = tasks.map { t in
            "[\(t.id)] \(t.status.rawValue.uppercased()) - \(t.subject)\(t.owner != nil ? " (owner: \(t.owner!))" : "")"
        }
        return ToolExecuteResult(content: lines.joined(separator: "\n"), isError: false)
    }
}
```

**TaskUpdateTool：**
```swift
public func createTaskUpdateTool() -> ToolProtocol {
    return defineTool(
        name: "TaskUpdate",
        description: "Update a task's status, description, or other properties.",
        inputSchema: taskUpdateSchema,
        isReadOnly: false
    ) { (input: TaskUpdateInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        let status: TaskStatus? = input.status.flatMap { TaskStatus(rawValue: $0) }
        do {
            let task = try await taskStore.update(
                id: input.id,
                status: status,
                description: input.description,
                owner: input.owner,
                output: input.output
            )
            return ToolExecuteResult(
                content: "Task updated: \(task.id) - \(task.status.rawValue) - \"\(task.subject)\"",
                isError: false
            )
        } catch let error as TaskStoreError {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}
```

**TaskGetTool（isReadOnly=true）：**
```swift
public func createTaskGetTool() -> ToolProtocol {
    return defineTool(
        name: "TaskGet",
        description: "Get full details of a specific task.",
        inputSchema: taskGetSchema,
        isReadOnly: true  // 只读
    ) { (input: TaskGetInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        guard let task = await taskStore.get(id: input.id) else {
            return ToolExecuteResult(content: "Task not found: \(input.id)", isError: true)
        }
        // 格式化为多行详情
        var lines = [
            "ID: \(task.id)",
            "Subject: \(task.subject)",
            "Status: \(task.status.rawValue)",
        ]
        if let desc = task.description { lines.append("Description: \(desc)") }
        if let owner = task.owner { lines.append("Owner: \(owner)") }
        lines.append("Created: \(task.createdAt)")
        lines.append("Updated: \(task.updatedAt)")
        if let output = task.output { lines.append("Output: \(output)") }
        return ToolExecuteResult(content: lines.joined(separator: "\n"), isError: false)
    }
}
```

**TaskStopTool：**
```swift
public func createTaskStopTool() -> ToolProtocol {
    return defineTool(
        name: "TaskStop",
        description: "Stop/cancel a running task.",
        inputSchema: taskStopSchema,
        isReadOnly: false
    ) { (input: TaskStopInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        let stopOutput = input.reason.map { "Stopped: \($0)" }
        do {
            _ = try await taskStore.update(id: input.id, status: .cancelled, output: stopOutput)
            return ToolExecuteResult(content: "Task stopped: \(input.id)", isError: false)
        } catch let error as TaskStoreError {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}
```

**TaskOutputTool（isReadOnly=true）：**
```swift
public func createTaskOutputTool() -> ToolProtocol {
    return defineTool(
        name: "TaskOutput",
        description: "Get the output/result of a task.",
        inputSchema: taskOutputSchema,
        isReadOnly: true  // 只读
    ) { (input: TaskOutputInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let taskStore = context.taskStore else {
            return ToolExecuteResult(content: "Error: TaskStore not available.", isError: true)
        }
        guard let task = await taskStore.get(id: input.id) else {
            return ToolExecuteResult(content: "Task not found: \(input.id)", isError: true)
        }
        return ToolExecuteResult(content: task.output ?? "(no output yet)", isError: false)
    }
}
```

### ToolContext 注入点（Core/Agent.swift 修改）

在 `Agent.swift` 的 `prompt()` 和 `stream()` 方法中，ToolContext 创建时注入 taskStore：

```swift
// 在 prompt() 和 stream() 方法中的 ToolContext 创建点
let context = ToolContext(
    cwd: options.cwd ?? "",
    agentSpawner: spawner,
    mailboxStore: options.mailboxStore,
    teamStore: options.teamStore,
    senderName: options.agentName,
    taskStore: options.taskStore              // 注入
)
```

在 `stream()` 方法中，还需要在 captured 变量区添加：
```swift
let capturedTaskStore = options.taskStore
```
并在 stream 内的 ToolContext 创建点使用 `capturedTaskStore`。

### AgentOptions 扩展

在 `Types/AgentTypes.swift` 中追加：

```swift
public struct AgentOptions: Sendable {
    // ... 现有字段（包括 agentName, mailboxStore, teamStore）...
    public var taskStore: TaskStore?           // 新增
}
```

更新 `init` 参数列表追加 `taskStore: TaskStore? = nil`。
更新 `init(from:)` 追加 `self.taskStore = nil`。

### TypeScript SDK 参考对比

**task-tools.ts（TypeScript）：**
- 使用模块级 `taskStore` Map + `taskCounter`（Swift 端使用 TaskStore actor）
- 六个独立工具对象，每个有自己的 call() 方法
- TaskUpdate 直接修改 task 对象（TS mutable），无状态转换验证
- TaskStop 直接设置 `task.status = 'cancelled'`，无验证

**Swift 端关键差异：**
| 方面 | TypeScript | Swift |
|------|-----------|-------|
| 存储实现 | 模块级 Map + counter | TaskStore Actor |
| 状态转换验证 | 无（直接赋值） | TaskStore.isValidTransition() 强制执行 |
| 线程安全 | 无（单线程 Node.js） | Actor 隔离 |
| 错误处理 | 直接返回 content | ToolExecuteResult(isError: true) |
| 任务 ID 生成 | `task_${++taskCounter}` | `task_${taskCounter}`（TaskStore 递增） |
| TaskStop 实现 | 直接修改 status | 复用 TaskStore.update()（会验证转换） |

**重要差异 — TaskStop 的行为：**
TS SDK 的 TaskStop 直接将状态设为 "cancelled" 而不验证当前状态。但 Swift 端的 TaskStore.update() 会通过 `isValidTransition()` 验证。如果任务已经是 `completed`/`failed`/`cancelled`（终端状态），TaskStop 会返回 `invalidStatusTransition` 错误。这是 Swift 端的增强，应该保持。

### Story 4-4 的经验教训（必须遵循）

1. **nonisolated(unsafe) 用于 schema 常量** — inputSchema 字典需要标记为 `nonisolated(unsafe)` 以避免 Sendable 警告
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **Actor 测试** — 使用 `await` 访问 actor 隔离方法
4. **错误路径测试** — 必须覆盖每个 guard 分支（规则 #28）
5. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - Factory Function`
6. **Codable 解码测试** — 验证 JSON 字段的解码正确性
7. **向后兼容** — ToolContext 新增字段默认值 nil，不破坏现有代码
8. **ToolExecuteResult 重载** — 使用 `defineTool` 返回 `ToolExecuteResult` 的重载（不是 String 返回的），以便显式控制 isError 标志

### 反模式警告

- **不要**在 Tools/Advanced/ 中导入 Stores/ 或 Core/ — 违反模块边界（规则 #7、#40）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — 在 ToolResult/ToolExecuteResult 中捕获返回（规则 #38）
- **不要**在任务工具中直接创建 TaskStore — 必须通过 ToolContext 注入
- **不要**使用 Apple 专属框架 — 必须跨平台（规则 #43）
- **不要**在 TaskListInput/TaskUpdateInput 中将 TaskStatus 作为 raw type — 使用 String 类型匹配 TS SDK schema，然后在工具内部转换为 TaskStatus enum
- **不要**修改 ToolContext 的现有 init 签名（会破坏现有代码）— 新增参数默认值 nil 保持兼容
- **不要**在 TaskStop 中绕过 TaskStore.update() — 必须使用 update() 而不是直接修改，以保持状态转换验证

### 模块边界注意事项

```
Types/ToolTypes.swift        → 扩展 ToolContext（追加 taskStore 字段，叶节点）
Types/AgentTypes.swift       → 扩展 AgentOptions（追加 taskStore 字段）
Core/Agent.swift             → 修改 ToolContext 创建点，注入 taskStore（内部修改）
Tools/Advanced/TaskCreateTool.swift → 只导入 Foundation + Types/（永不导入 Core/ 或 Stores/）
Tools/Advanced/TaskListTool.swift   → 只导入 Foundation + Types/
Tools/Advanced/TaskUpdateTool.swift → 只导入 Foundation + Types/
Tools/Advanced/TaskGetTool.swift    → 只导入 Foundation + Types/
Tools/Advanced/TaskStopTool.swift   → 只导入 Foundation + Types/
Tools/Advanced/TaskOutputTool.swift → 只导入 Foundation + Types/
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 4.1 (已完成) | 提供 TaskStore（create/list/update/get/delete/clear）|
| 4.2 (已完成) | 提供 TeamStore、AgentRegistry |
| 4.3 (已完成) | 提供 AgentTool + ToolContext.agentSpawner 注入模式 |
| 4.4 (已完成) | 提供 SendMessageTool + ToolContext.mailboxStore/teamStore/senderName 注入模式 — **直接复用此模式** |
| 4.6 (后续) | TeamCreate/Delete 工具可能需要通过任务管理追踪团队创建状态 |

### 测试策略

**TaskTools 测试策略：**
- 使用真实的 TaskStore actor 实例（轻量级，不涉及网络）
- 测试所有成功路径和错误路径
- 每个工具独立测试，然后测试工具间的协作（创建→列表→获取→更新→停止→输出）

**关键测试场景（每个工具）：**
1. **TaskCreate** — 只填 subject、全部可选字段、默认 status、指定 initial status
2. **TaskList** — 无过滤返回全部、按 status 过滤、按 owner 过滤、空列表
3. **TaskUpdate** — 更新 status 成功、更新 description/owner/output、任务不存在错误、无效状态转换错误（completed → pending）
4. **TaskGet** — 获取存在任务的完整信息、任务不存在错误
5. **TaskStop** — 停止 pending 任务成功、带 reason 成功、任务不存在错误、停止已完成任务返回转换错误
6. **TaskOutput** — 获取有 output 的任务、获取无 output 的任务（返回 "(no output yet)"）、任务不存在错误
7. **通用** — taskStore 为 nil 时所有工具返回错误、inputSchema 验证、isReadOnly 验证（TaskList/TaskGet/TaskOutput 为 true，其余为 false）

### isReadOnly 分类

| 工具 | isReadOnly | 理由 |
|------|-----------|------|
| TaskCreate | false | 创建任务（有副作用） |
| TaskList | true | 只读查询 |
| TaskUpdate | false | 修改任务（有副作用） |
| TaskGet | true | 只读查询 |
| TaskStop | false | 修改任务状态（有副作用） |
| TaskOutput | true | 只读查询 |

isReadOnly 的分类影响 ToolExecutor 的调度策略：只读工具可以并发执行，变更工具串行执行（规则 #2、FR12）。

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.5]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR37 Tools/Advanced/Task*Tool.swift]
- [Source: _bmad-output/planning-artifacts/architecture.md#架构边界 Tools 依赖规则]
- [Source: _bmad-output/project-context.md#规则 7 模块边界单向依赖]
- [Source: _bmad-output/project-context.md#规则 38 不从工具内部 throw]
- [Source: _bmad-output/project-context.md#规则 40 Tools 不导入 Core]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/task-tools.ts] — TS Task Tools 完整实现参考
- [Source: Sources/OpenAgentSDK/Stores/TaskStore.swift] — TaskStore actor（create/list/update/get/delete/clear）
- [Source: Sources/OpenAgentSDK/Types/TaskTypes.swift] — Task, TaskStatus, TaskStoreError
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol, ToolContext, ToolExecuteResult
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions, AgentDefinition
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift] — AgentTool 工厂函数参考模式
- [Source: Sources/OpenAgentSDK/Tools/Advanced/SendMessageTool.swift] — SendMessageTool 工厂函数参考模式（直接复用 ToolContext 注入模式）
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool 工厂函数
- [Source: _bmad-output/implementation-artifacts/4-4-send-message-tool.md] — 前一 story 经验

### Project Structure Notes

- 修改 `Sources/OpenAgentSDK/Types/ToolTypes.swift` — 追加 taskStore 到 ToolContext
- 修改 `Sources/OpenAgentSDK/Types/AgentTypes.swift` — 追加 taskStore 到 AgentOptions
- 新建 `Sources/OpenAgentSDK/Tools/Advanced/TaskCreateTool.swift` — TaskCreate 工厂函数
- 新建 `Sources/OpenAgentSDK/Tools/Advanced/TaskListTool.swift` — TaskList 工厂函数
- 新建 `Sources/OpenAgentSDK/Tools/Advanced/TaskUpdateTool.swift` — TaskUpdate 工厂函数
- 新建 `Sources/OpenAgentSDK/Tools/Advanced/TaskGetTool.swift` — TaskGet 工厂函数
- 新建 `Sources/OpenAgentSDK/Tools/Advanced/TaskStopTool.swift` — TaskStop 工厂函数
- 新建 `Sources/OpenAgentSDK/Tools/Advanced/TaskOutputTool.swift` — TaskOutput 工厂函数
- 修改 `Sources/OpenAgentSDK/Core/Agent.swift` — ToolContext 创建时注入 taskStore
- 修改 `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 追加重新导出注释
- 新建 `Tests/OpenAgentSDKTests/Tools/Advanced/TaskToolsTests.swift`
- 完全对齐架构文档的目录结构和模块边界

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

### Review Findings

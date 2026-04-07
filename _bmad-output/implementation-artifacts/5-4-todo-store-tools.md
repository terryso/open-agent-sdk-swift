# Story 5.4: TodoStore 与 TodoWrite 工具

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望我的 Agent 可以管理待办事项，
以便它可以追踪和更新任务进度。

## Acceptance Criteria

1. **AC1: TodoStore Actor** — 给定 TodoStore Actor 实现，当并发添加、切换、移除、列出和清除待办事项时，则所有操作通过 Actor 隔离实现线程安全（FR47、FR48），且待办事项状态（id、text、done、priority）被正确追踪。

2. **AC2: TodoWrite 工具 — add 操作** — 给定 TodoWrite 工具已注册且 ToolContext 包含 todoStore，当 LLM 请求添加带有 text 和可选 priority 的待办事项，则 TodoStore 创建新条目（id 自增，done=false），返回包含 id 和文本的确认消息（FR47）。

3. **AC3: TodoWrite 工具 — toggle 操作** — 给定 TodoWrite 工具已注册，当 LLM 请求切换指定 id 的待办事项完成状态，则 TodoStore 反转 done 标志并返回 "completed" 或 "reopened"。当 id 不存在时，返回 is_error=true 的 ToolResult（FR47）。

4. **AC4: TodoWrite 工具 — remove 操作** — 给定 TodoWrite 工具已注册，当 LLM 请求移除指定 id 的待办事项，则从 TodoStore 中删除该条目并返回确认。当 id 不存在时，返回 is_error=true 的 ToolResult（FR47）。

5. **AC5: TodoWrite 工具 — list 操作** — 给定 TodoWrite 工具已注册，当 LLM 请求列出所有待办事项，则返回 TodoStore 中所有事项的格式化列表。当没有事项时，返回 "No todos." 提示消息（FR47）。

6. **AC6: TodoWrite 工具 — clear 操作** — 给定 TodoWrite 工具已注册，当 LLM 请求清除所有待办事项，则 TodoStore 清除所有状态和计数器，返回 "All todos cleared." 确认消息（FR47）。

7. **AC7: TodoStore 缺失错误** — 给定 ToolContext 中 todoStore 为 nil，当 TodoWrite 工具执行，则返回 is_error=true 的 ToolResult 提示 TodoStore 不可用。

8. **AC8: inputSchema 匹配 TS SDK** — 给定 TS SDK 的 TodoWrite 工具 schema（todo-tool.ts），当检查 Swift 端的 inputSchema，则字段名称、类型和 required 列表与 TS SDK 一致。TodoWrite 有 `action`（string，必填，enum: add/toggle/remove/list/clear）、`text`（string，可选）、`id`（number，可选）、`priority`（string，可选，enum: high/medium/low）。

9. **AC9: isReadOnly 分类** — 给定 TodoWrite 工具，当检查 isReadOnly 属性，则返回 false（修改 TodoStore 状态）。

10. **AC10: 模块边界合规** — 给定 TodoStore 位于 Stores/ 目录，TodoWriteTool 位于 Tools/Specialist/ 目录，当检查 import 语句，则 TodoStore 只导入 Foundation 和 Types/；TodoWriteTool 只导入 Foundation 和 Types/，永不导入 Core/ 或 Stores/（架构规则 #7、#40）。

11. **AC11: 错误处理不中断循环** — 给定 TodoWrite 工具执行期间发生异常（如 todoStore 为 nil、事项不存在），当错误被捕获，则返回 is_error=true 的 ToolResult，不会中断 Agent 的智能循环（架构规则 #38）。

12. **AC12: ToolContext 依赖注入** — 给定 Tools/Specialist/ 不能导入 Stores/ 的架构约束（规则 #7、#40），当 TodoWrite 工具需要访问 TodoStore，则通过 ToolContext 携带的 `todoStore` 引用实现跨模块调用（与 WorktreeTool、PlanTool、CronTool 的注入模式一致）。

13. **AC13: TodoStore 状态查询** — 给定 TodoStore Actor，当调用 `get(id:)` 方法，则返回指定 ID 的事项或 nil。当调用 `list()` 方法，则返回所有事项。当调用 `clear()` 方法，则清除所有状态和计数器。

14. **AC14: action 校验** — 给定 TodoWrite 工具接收到未知的 action 值，当执行 call 方法，则返回 is_error=true 的 ToolResult 提示未知操作。

15. **AC15: add 缺少 text 校验** — 给定 TodoWrite 工具接收到 action=add 但 text 为空或缺失，当执行 call 方法，则返回 is_error=true 的 ToolResult 提示 "text required"。

## Tasks / Subtasks

- [x] Task 1: 定义 Todo 类型 (AC: #1, #10)
  - [x] 在 `Sources/OpenAgentSDK/Types/TaskTypes.swift` 中追加 Todo 相关类型
  - [x] `TodoPriority` 枚举：high, medium, low
  - [x] `TodoItem` 结构体：id (Int), text (String), done (Bool), priority (TodoPriority? 可选)
  - [x] `TodoStoreError` 枚举：todoNotFound(id: Int)

- [x] Task 2: 实现 TodoStore Actor (AC: #1, #13)
  - [x] 创建 `Sources/OpenAgentSDK/Stores/TodoStore.swift`
  - [x] `add(text:priority:)` — 创建新待办事项条目，自动生成递增 ID，done=false
  - [x] `toggle(id:)` — 切换 done 标志，不存在时抛出 todoNotFound
  - [x] `remove(id:)` — 按 ID 删除事项，不存在时抛出 todoNotFound
  - [x] `get(id:)` — 按 ID 获取事项
  - [x] `list()` — 列出所有事项
  - [x] `clear()` — 清除所有状态和计数器

- [x] Task 3: 扩展 ToolContext 和 AgentOptions (AC: #12)
  - [x] 在 `Sources/OpenAgentSDK/Types/ToolTypes.swift` 中为 `ToolContext` 追加 `todoStore: TodoStore?` 字段
  - [x] 更新 init 添加新参数（默认值 nil，保持现有调用兼容）
  - [x] 在 `Sources/OpenAgentSDK/Types/AgentTypes.swift` 中为 `AgentOptions` 追加 `todoStore: TodoStore?` 字段
  - [x] 更新 init 参数列表追加 `todoStore: TodoStore? = nil`

- [x] Task 4: 集成到 Agent 创建点 (AC: #12)
  - [x] 修改 `Sources/OpenAgentSDK/Core/Agent.swift` 中 prompt() 和 stream() 方法的 ToolContext 创建点
  - [x] ToolContext 创建时传入 todoStore（从 options.todoStore 获取）

- [x] Task 5: 实现 TodoWrite 工厂函数 (AC: #2-#9, #11, #14, #15)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/Specialist/TodoWriteTool.swift`
  - [x] 定义 `TodoWriteInput` Codable 结构体：`action`（必填 String）、`text`（可选 String）、`id`（可选 Int）、`priority`（可选 String）
  - [x] 定义 JSON inputSchema 匹配 TS SDK 的 TodoWrite schema
  - [x] `createTodoWriteTool()` 工厂函数返回 ToolProtocol
  - [x] call 逻辑：switch on action — add/toggle/remove/list/clear/default
  - [x] add: 检查 text 非空 → 调用 todoStore.add()
  - [x] toggle: 调用 todoStore.toggle() → 捕获 TodoStoreError 返回 isError=true
  - [x] remove: 调用 todoStore.remove() → 捕获 TodoStoreError 返回 isError=true
  - [x] list: 调用 todoStore.list() → 格式化输出（[x]/[ ] #id text (priority)）
  - [x] clear: 调用 todoStore.clear() → 返回确认
  - [x] default: 返回 is_error=true 的未知操作错误

- [x] Task 6: 更新模块入口 (AC: #10)
  - [x] 在 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 中追加 TodoStore、TodoWrite 工具的重新导出注释

- [x] Task 7: 单元测试 — TodoStore (AC: #1, #13)
  - [x] 创建 `Tests/OpenAgentSDKTests/Stores/TodoStoreTests.swift`
  - [x] 测试 add/toggle/remove/get/list/clear 方法
  - [x] 测试错误路径：todoNotFound
  - [x] 测试 Actor 隔离并发安全

- [x] Task 8: 单元测试 — TodoWrite 工具 (AC: #2-#9, #14, #15)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/Specialist/TodoWriteToolTests.swift`
  - [x] TodoWrite add: 添加成功、text 缺失错误、带 priority 添加、todoStore 为 nil 错误
  - [x] TodoWrite toggle: 切换成功（完成和重新打开）、事项不存在错误、todoStore 为 nil 错误
  - [x] TodoWrite remove: 移除成功、事项不存在错误、todoStore 为 nil 错误
  - [x] TodoWrite list: 列出多个事项、空列表提示、todoStore 为 nil 错误
  - [x] TodoWrite clear: 清除成功、todoStore 为 nil 错误
  - [x] 通用: inputSchema 验证、isReadOnly 验证（false）、模块边界验证、未知 action 错误

- [x] Task 9: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证 Tools/Specialist/ 中的文件不导入 Core/ 或 Stores/
  - [x] 验证 Stores/ 中的文件只导入 Foundation 和 Types/
  - [x] 验证测试可以编译并通过

- [x] Task 10: E2E 测试
  - [x] 在 `Sources/E2ETest/` 中补充 TodoStore 和 TodoWrite 工具的 E2E 测试
  - [x] 至少覆盖 happy path：添加待办 → 列出 → 切换完成 → 移除 → 清除

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 5（专业工具与管理存储）的第四个 story
- 本 story 实现一个 Actor 存储（TodoStore）和一个专业工具：TodoWrite
- 与 Story 5-1 (WorktreeStore)、5-2 (PlanStore)、5-3 (CronStore) 遵循完全相同的模式

**架构关键问题 — Tools/ 不能导入 Stores/ 或 Core/：**

与 WorktreeTool、PlanTool、CronTool 的注入模式完全一致，本 story 需要通过 ToolContext 注入 TodoStore。

**解决方案：通过 ToolContext 注入 TodoStore actor 引用**

```
Types/TaskTypes.swift:         追加 TodoItem, TodoPriority, TodoStoreError 类型
Types/ToolTypes.swift:         ToolContext 追加 todoStore 字段
Types/AgentTypes.swift:        AgentOptions 追加 todoStore 字段
Stores/TodoStore.swift:        新建 TodoStore actor
Core/Agent.swift:              创建 ToolContext 时注入 TodoStore
Tools/Specialist/TodoWriteTool.swift: 通过 context.todoStore 使用
```

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `ToolContext` | `Types/ToolTypes.swift` | 需追加 todoStore 字段 |
| `AgentOptions` | `Types/AgentTypes.swift` | 需追加 todoStore 字段 |
| `Agent` | `Core/Agent.swift` | prompt()/stream() 需注入 todoStore |
| `ToolExecuteResult` | `Types/ToolTypes.swift` | content + isError |
| `defineTool()` | `Tools/ToolBuilder.swift` | 工厂函数 |
| `CronStore` | `Stores/CronStore.swift` | Actor 存储实现参考模式（最近完成的 Story 5-3，**直接复用此模式**） |
| `CronTools` | `Tools/Specialist/CronTools.swift` | Specialist 工具参考模式（Story 5-3） |

### TypeScript SDK 参考对比

**todo-tool.ts 关键实现要点：**

1. **TodoWrite（单工具，多操作）：**
   - 使用模块级 `TodoItem[]` 数组存储待办事项
   - 自动生成 ID（格式：`++todoCounter`，纯整数递增）
   - `action` 字段控制操作类型：add / toggle / remove / list / clear
   - **isReadOnly: false**（所有操作，即使是 list，因为这是一个单工具设计）
   - **isConcurrencySafe: true**（TS SDK 标记为并发安全）

2. **add 操作：**
   - 输入：`text`（必填）、`priority`（可选：high/medium/low）
   - 如果 text 缺失，返回 is_error=true（`text required`）
   - 创建时 `done: false`，`id: ++todoCounter`
   - 返回：`Todo added: #{id} "{text}"`

3. **toggle 操作：**
   - 输入：`id`（必填 number）
   - 反转 done 标志
   - 如果 id 不存在，返回 is_error=true（`Todo #{id} not found`）
   - 返回：`Todo #{id} completed` 或 `Todo #{id} reopened`

4. **remove 操作：**
   - 输入：`id`（必填 number）
   - 从数组中移除
   - 如果 id 不存在，返回 is_error=true（`Todo #{id} not found`）
   - 返回：`Todo #{id} removed`

5. **list 操作：**
   - 无额外输入
   - 如果无事项，返回 "No todos."
   - 格式化每行：`[x] #1 buy groceries (high)` 或 `[ ] #2 write tests`
   - priority 存在时显示在括号中

6. **clear 操作：**
   - 无额外输入
   - 清空数组和计数器
   - 返回 "All todos cleared."

7. **TodoItem 接口：**
   ```typescript
   interface TodoItem {
     id: number
     text: string
     done: boolean
     priority?: 'high' | 'medium' | 'low'
   }
   ```

8. **导出函数：**
   - `getTodos()` — 返回所有事项的副本
   - `clearTodos()` — 清除所有事项（用于测试重置）

**Swift 端关键差异：**

| 方面 | TypeScript | Swift |
|------|-----------|-------|
| 存储实现 | 模块级数组 | TodoStore Actor |
| ID 类型 | number (Int) | Int（保持一致） |
| 线程安全 | 无（单线程 Node.js） | Actor 隔离 |
| 错误处理 | 直接返回 content string | ToolExecuteResult(isError: true) |
| 工具数量 | 1 个（多操作） | 1 个（多操作，与 TS SDK 一致） |
| isReadOnly | false | false |
| 数据存储 | 数组 | 字典 [Int: TodoItem] |

### 类型定义

**TodoPriority 枚举（在 TaskTypes.swift 中追加）：**

```swift
/// Priority level for a todo item.
public enum TodoPriority: String, Sendable, Equatable, Codable, CaseIterable {
    case high
    case medium
    case low
}
```

**TodoItem 结构体（在 TaskTypes.swift 中追加）：**

```swift
/// A todo item tracked by the TodoStore.
public struct TodoItem: Sendable, Equatable, Codable {
    public let id: Int
    public let text: String
    public var done: Bool
    public var priority: TodoPriority?

    public init(
        id: Int,
        text: String,
        done: Bool = false,
        priority: TodoPriority? = nil
    ) {
        self.id = id
        self.text = text
        self.done = done
        self.priority = priority
    }
}
```

**TodoStoreError 枚举（在 TaskTypes.swift 中追加）：**

```swift
/// Errors thrown by TodoStore operations.
public enum TodoStoreError: Error, Equatable, LocalizedError, Sendable {
    case todoNotFound(id: Int)

    public var errorDescription: String? {
        switch self {
        case .todoNotFound(let id):
            return "Todo #\(id) not found"
        }
    }
}
```

### ToolContext 扩展

```swift
// 在 ToolContext 中追加
public let todoStore: TodoStore?

public init(
    // ... 现有参数 ...,
    worktreeStore: WorktreeStore? = nil,
    planStore: PlanStore? = nil,
    cronStore: CronStore? = nil,
    todoStore: TodoStore? = nil
) {
    // ...
    self.todoStore = todoStore
}
```

### AgentOptions 扩展

```swift
// 在 AgentOptions 中追加
public var todoStore: TodoStore?
```

更新 `init` 和 `init(from:)` 追加 `todoStore: TodoStore? = nil`。

### TodoStore 实现

```swift
public actor TodoStore {
    private var items: [Int: TodoItem] = [:]
    private var counter: Int = 0

    public init() {}

    public func add(text: String, priority: TodoPriority? = nil) -> TodoItem {
        counter += 1
        let item = TodoItem(id: counter, text: text, done: false, priority: priority)
        items[counter] = item
        return item
    }

    @discardableResult
    public func toggle(id: Int) throws -> TodoItem {
        guard let item = items[id] else {
            throw TodoStoreError.todoNotFound(id: id)
        }
        let toggled = TodoItem(id: item.id, text: item.text, done: !item.done, priority: item.priority)
        items[id] = toggled
        return toggled
    }

    @discardableResult
    public func remove(id: Int) throws -> TodoItem {
        guard let item = items.removeValue(forKey: id) else {
            throw TodoStoreError.todoNotFound(id: id)
        }
        return item
    }

    public func get(id: Int) -> TodoItem? { items[id] }

    public func list() -> [TodoItem] { Array(items.values).sorted { $0.id < $1.id } }

    public func clear() { items.removeAll(); counter = 0 }
}
```

### 工具 Input 类型

```swift
// TodoWrite — 单一输入类型，多操作
private struct TodoWriteInput: Codable {
    let action: String       // 必填：add / toggle / remove / list / clear
    let text: String?        // 可选：add 操作时使用
    let id: Int?             // 可选：toggle / remove 操作时使用
    let priority: String?    // 可选：add 操作时使用
}
```

### inputSchema 定义（匹配 TS SDK todo-tool.ts）

**TodoWrite schema：**
```swift
private nonisolated(unsafe) let todoWriteSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "action": [
            "type": "string",
            "enum": ["add", "toggle", "remove", "list", "clear"],
            "description": "Operation to perform"
        ] as [String: Any],
        "text": [
            "type": "string",
            "description": "Todo item text (for add)"
        ] as [String: Any],
        "id": [
            "type": "number",
            "description": "Todo item ID (for toggle/remove)"
        ] as [String: Any],
        "priority": [
            "type": "string",
            "enum": ["high", "medium", "low"],
            "description": "Priority level (for add)"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["action"]
]
```

### 工厂函数实现要点

**TodoWriteTool：**
```swift
public func createTodoWriteTool() -> ToolProtocol {
    return defineTool(
        name: "TodoWrite",
        description: "Manage a session todo/checklist. Supports add, toggle, remove, and list operations.",
        inputSchema: todoWriteSchema,
        isReadOnly: false
    ) { (input: TodoWriteInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let todoStore = context.todoStore else {
            return ToolExecuteResult(content: "Error: TodoStore not available.", isError: true)
        }

        switch input.action {
        case "add":
            guard let text = input.text, !text.isEmpty else {
                return ToolExecuteResult(content: "text required", isError: true)
            }
            let priority = input.priority.flatMap { TodoPriority(rawValue: $0) }
            let item = await todoStore.add(text: text, priority: priority)
            return ToolExecuteResult(content: "Todo added: #\(item.id) \"\(item.text)\"", isError: false)

        case "toggle":
            guard let id = input.id else {
                return ToolExecuteResult(content: "id required for toggle", isError: true)
            }
            do {
                let item = try await todoStore.toggle(id: id)
                return ToolExecuteResult(content: "Todo #\(item.id) \(item.done ? "completed" : "reopened")", isError: false)
            } catch let error as TodoStoreError {
                return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
            }

        case "remove":
            guard let id = input.id else {
                return ToolExecuteResult(content: "id required for remove", isError: true)
            }
            do {
                let item = try await todoStore.remove(id: id)
                return ToolExecuteResult(content: "Todo #\(item.id) removed", isError: false)
            } catch let error as TodoStoreError {
                return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
            }

        case "list":
            let items = await todoStore.list()
            if items.isEmpty {
                return ToolExecuteResult(content: "No todos.", isError: false)
            }
            let lines = items.map { t in
                let check = t.done ? "[x]" : "[ ]"
                let prio = t.priority.map { " (\($0.rawValue))" } ?? ""
                return "\(check) #\(t.id) \(t.text)\(prio)"
            }
            return ToolExecuteResult(content: lines.joined(separator: "\n"), isError: false)

        case "clear":
            await todoStore.clear()
            return ToolExecuteResult(content: "All todos cleared.", isError: false)

        default:
            return ToolExecuteResult(content: "Unknown action: \(input.action)", isError: true)
        }
    }
}
```

### 实现位置

**新增文件：**
```
Sources/OpenAgentSDK/Stores/TodoStore.swift             # TodoStore Actor
Sources/OpenAgentSDK/Tools/Specialist/TodoWriteTool.swift # TodoWrite 工厂函数
```

**修改文件：**
```
Sources/OpenAgentSDK/Types/TaskTypes.swift     # 追加 TodoItem, TodoPriority, TodoStoreError
Sources/OpenAgentSDK/Types/ToolTypes.swift     # 追加 todoStore 到 ToolContext
Sources/OpenAgentSDK/Types/AgentTypes.swift    # 追加 todoStore 到 AgentOptions
Sources/OpenAgentSDK/Core/Agent.swift          # ToolContext 创建时注入 todoStore
Sources/OpenAgentSDK/OpenAgentSDK.swift        # 追加重新导出注释
```

**测试文件：**
```
Tests/OpenAgentSDKTests/Stores/TodoStoreTests.swift          # TodoStore 测试
Tests/OpenAgentSDKTests/Tools/Specialist/TodoWriteToolTests.swift  # TodoWrite 工具测试
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
9. **空 Codable 结构体** — 不适用本 story（TodoWriteInput 有 action 字段）
10. **TodoStore.add 不抛出错误** — 与 CronStore.create 类似，add 操作只是追加到字典，无失败场景
11. **ID 类型保持 Int** — TS SDK 使用 number 类型，Swift 端对应 Int。inputSchema 中 id 字段的 type 为 "number"

### 反模式警告

- **不要**在 Tools/Specialist/ 中导入 Stores/ 或 Core/ — 违反模块边界（规则 #7、#40）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — 在 ToolExecuteResult 中捕获返回（规则 #38）
- **不要**在 TodoWrite 工具中直接创建 TodoStore — 必须通过 ToolContext 注入
- **不要**使用 Apple 专属框架 — 必须跨平台（规则 #43）
- **不要**修改 ToolContext 的现有 init 签名（会破坏现有代码）— 新增参数默认值 nil 保持兼容
- **不要**将 TodoItem 类型定义在 Stores/ 中 — 类型必须定义在 Types/TaskTypes.swift 中（Store 只依赖 Types/）
- **不要**将 TodoWrite 拆分为多个工具 — TS SDK 使用单工具多操作设计，Swift 端保持一致
- **不要**为 list 操作单独设置 isReadOnly=true — TS SDK 中整个 TodoWrite 工具 isReadOnly=false
- **不要**将 id 字段类型设为 String — TS SDK 使用 number，Swift 端对应 Int

### 模块边界注意事项

```
Types/TaskTypes.swift                 → 追加 TodoItem, TodoPriority, TodoStoreError（叶节点）
Types/ToolTypes.swift                 → 追加 todoStore 到 ToolContext（叶节点）
Types/AgentTypes.swift                → 追加 todoStore 到 AgentOptions
Stores/TodoStore.swift                → 只导入 Foundation + Types/（永不导入 Core/ 或 Tools/）
Core/Agent.swift                      → 修改 ToolContext 创建点注入 todoStore
Tools/Specialist/TodoWriteTool.swift  → 只导入 Foundation + Types/（永不导入 Core/ 或 Stores/）
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 5-1 (已完成) | WorktreeStore — Actor 存储和 ToolContext 注入模式参考 |
| 5-2 (已完成) | PlanStore — Actor 存储和 ToolContext 注入模式参考 |
| 5-3 (已完成) | CronStore — Actor 存储和 ToolContext 注入模式参考（**最直接的参考**） |
| 4-4 (已完成) | SendMessageTool + ToolContext 注入 store 的模式 |
| 4-5 (已完成) | TaskTools + ToolContext.taskStore 注入模式 |

### TodoStore vs CronStore 关键区别

| 方面 | CronStore (5-3) | TodoStore (5-4) |
|------|-----------------|-----------------|
| 工具数量 | 3 (Create/Delete/List) | 1 (TodoWrite，多操作) |
| 数据存储 | 字典 [String: CronJob] | 字典 [Int: TodoItem] |
| ID 类型 | String（"cron_1"） | Int（1, 2, 3...） |
| 工具设计 | 多工具，每工具一操作 | 单工具，action 字段切换操作 |
| 有 isReadOnly=true 的工具 | 有（CronList） | 无（整个工具 isReadOnly=false） |
| clear 操作 | 有（通过 store 方法） | 有（通过 clear action 暴露给 LLM） |
| toggle 操作 | 无 | 有（切换 done 标志） |
| 错误类型 | cronJobNotFound(id: String) | todoNotFound(id: Int) |

### isReadOnly 分类

| 工具 | isReadOnly | 理由 |
|------|-----------|------|
| TodoWrite | false | 修改 TodoStore 状态（包含 add/toggle/remove/clear 操作） |

isReadOnly=false 意味着 TodoWrite 是变更工具，将被串行执行（规则 #2、FR12）。即使 list 操作是只读的，整个工具仍然标记为 false，因为其他操作会修改状态。

### 测试策略

**TodoStore 测试策略：**
- TodoStore 不依赖外部命令，所有操作都是内存中的状态管理
- 测试更加简单，无需临时 Git 仓库

**关键测试场景：**
1. **add** — 添加成功验证 id/text/done/priority、多次添加生成不同 id、带/不带 priority
2. **toggle** — 切换成功（false→true 和 true→false）、切换不存在的抛出 todoNotFound
3. **remove** — 移除成功、移除不存在的抛出 todoNotFound
4. **get** — 获取存在的事项、获取不存在的返回 nil
5. **list** — 空列表、添加后返回正确数量、按 id 排序
6. **clear** — 清除后 list 为空、清除后 counter 重置
7. **并发安全** — 多个并发操作不导致数据损坏

**TodoWriteTool 测试策略：**
- 使用真实 TodoStore（纯内存，无需 mock）

**关键工具测试场景：**
1. **add** — todoStore 为 nil 时返回错误、添加成功验证返回内容、text 缺失时返回错误、带 priority 添加成功
2. **toggle** — todoStore 为 nil 时返回错误、切换成功（completed/reopened）、事项不存在时返回 is_error=true、id 缺失时返回错误
3. **remove** — todoStore 为 nil 时返回错误、移除成功、事项不存在时返回 is_error=true、id 缺失时返回错误
4. **list** — todoStore 为 nil 时返回错误、空列表返回 "No todos."、有事项时返回格式化列表
5. **clear** — todoStore 为 nil 时返回错误、清除成功
6. **通用** — inputSchema 验证（action 必填、enum 值）、isReadOnly 验证（false）、模块边界验证、未知 action 错误

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.4]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR47 TodoStore]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR48 Actor-based thread-safe stores]
- [Source: _bmad-output/planning-artifacts/architecture.md#架构边界 Stores 依赖规则]
- [Source: _bmad-output/planning-artifacts/architecture.md#项目结构 Stores/ 和 Tools/Specialist/]
- [Source: _bmad-output/project-context.md#规则 1 Actor 用于共享可变状态]
- [Source: _bmad-output/project-context.md#规则 7 模块边界单向依赖]
- [Source: _bmad-output/project-context.md#规则 38 不从工具内部 throw]
- [Source: _bmad-output/project-context.md#规则 40 Tools 不导入 Core]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/todo-tool.ts] — TS TodoWrite Tool 完整实现参考
- [Source: Sources/OpenAgentSDK/Stores/CronStore.swift] — Actor 存储实现参考模式（Story 5-3，最直接参考）
- [Source: Sources/OpenAgentSDK/Tools/Specialist/CronTools.swift] — Specialist 工具参考模式（Story 5-3）
- [Source: Sources/OpenAgentSDK/Types/TaskTypes.swift] — 类型定义参考（需追加 TodoItem, TodoPriority, TodoStoreError）
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolContext（需追加 todoStore）
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions（需追加 todoStore）
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool 工厂函数
- [Source: _bmad-output/implementation-artifacts/5-3-cron-store-tools.md] — 前一 story 完整参考

### Project Structure Notes

- 新建 `Sources/OpenAgentSDK/Stores/TodoStore.swift` — TodoStore Actor
- 新建 `Sources/OpenAgentSDK/Tools/Specialist/TodoWriteTool.swift` — TodoWrite 工厂函数
- 修改 `Sources/OpenAgentSDK/Types/TaskTypes.swift` — 追加 TodoItem, TodoPriority, TodoStoreError
- 修改 `Sources/OpenAgentSDK/Types/ToolTypes.swift` — 追加 todoStore 到 ToolContext
- 修改 `Sources/OpenAgentSDK/Types/AgentTypes.swift` — 追加 todoStore 到 AgentOptions
- 修改 `Sources/OpenAgentSDK/Core/Agent.swift` — ToolContext 创建时注入 todoStore
- 修改 `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 追加重新导出注释
- 新建 `Tests/OpenAgentSDKTests/Stores/TodoStoreTests.swift`
- 新建 `Tests/OpenAgentSDKTests/Tools/Specialist/TodoWriteToolTests.swift`
- 完全对齐架构文档的目录结构和模块边界

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Completed Task 1: TodoItem, TodoPriority, TodoStoreError types already defined in TaskTypes.swift (pre-existing)
- Completed Task 2: TodoStore Actor already implemented in Stores/TodoStore.swift (pre-existing)
- Completed Task 3: ToolContext and AgentOptions already have todoStore field (pre-existing)
- Completed Task 4: Injected todoStore into ToolContext creation in Agent.swift prompt() and stream() methods
- Completed Task 5: Created TodoWriteTool.swift with createTodoWriteTool() factory function implementing all 5 actions (add/toggle/remove/list/clear)
- Completed Task 6: Updated OpenAgentSDK.swift with TodoStore, TodoItem, TodoPriority, TodoStoreError, and createTodoWriteTool documentation
- Completed Task 7: 25 TodoStore unit tests all pass
- Completed Task 8: 33 TodoWriteTool unit tests all pass (including schema validation, isReadOnly, module boundary, and integration lifecycle)
- Completed Task 9: swift build passes, module boundary verified (TodoWriteTool only imports Foundation, TodoStore only imports Foundation)
- Completed Task 10: Added E2E tests (section 30 TodoStore Operations + section 31 Agent+TodoStore Integration)
- Full test suite: 1132 tests, 0 failures, 4 skipped

### File List

**New files:**
- Sources/OpenAgentSDK/Tools/Specialist/TodoWriteTool.swift

**Modified files:**
- Sources/OpenAgentSDK/Core/Agent.swift (injected todoStore into ToolContext in prompt() and stream())
- Sources/OpenAgentSDK/OpenAgentSDK.swift (added TodoStore/TodoWrite doc references)
- Sources/E2ETest/StoreTests.swift (added section 30 TodoStore Operations)
- Sources/E2ETest/IntegrationTests.swift (added section 31 Agent+TodoStore Integration)
- Sources/E2ETest/main.swift (updated section comments)

**Pre-existing files (unchanged, verified correct):**
- Sources/OpenAgentSDK/Types/TaskTypes.swift (TodoItem, TodoPriority, TodoStoreError already present)
- Sources/OpenAgentSDK/Types/ToolTypes.swift (todoStore field already present in ToolContext)
- Sources/OpenAgentSDK/Types/AgentTypes.swift (todoStore field already present in AgentOptions)
- Sources/OpenAgentSDK/Stores/TodoStore.swift (already implemented)
- Tests/OpenAgentSDKTests/Stores/TodoStoreTests.swift (25 tests, all pass)
- Tests/OpenAgentSDKTests/Tools/Specialist/TodoWriteToolTests.swift (33 tests, all pass)

## Change Log

- 2026-04-07: Implemented TodoWriteTool factory function, injected todoStore into Agent.swift, added E2E tests, all 1132 tests passing

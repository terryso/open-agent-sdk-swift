# Story 4.3: Agent 工具（子 Agent 生成）

Status: done

## Story

作为开发者，
我希望我的 Agent 可以生成子 Agent 执行委托任务，
以便复杂任务可以跨专业 Agent 并行化。

## Acceptance Criteria

1. **AC1: AgentTool 注册与执行** — 给定 AgentTool 已注册到 Agent，当父 Agent 的 LLM 请求使用 Agent 工具并传入 prompt 和 description，则创建子 Agent 执行委托任务并返回结果给父 Agent（FR35）。

2. **AC2: 子 Agent 生命周期** — 给定正在执行委托任务的子 Agent，当子 Agent 完成（成功或失败），则父 Agent 接收 ToolResult（成功时包含文本和工具调用摘要，失败时 is_error=true）并继续其智能循环。

3. **AC3: 内置 Agent 类型** — 给定 AgentTool 支持 "Explore" 和 "Plan" 两种内置 agent 类型，当 subagent_type 指定为 Explore 或 Plan，则使用对应的系统提示词和工具集创建子 Agent（Explore/Grep/Glob/Read/Bash）。

4. **AC4: 工具集过滤与递归防护** — 给定父 Agent 的工具列表，当创建子 Agent，则子 Agent 继承父 Agent 的工具但移除 AgentTool 自身（防止无限递归）；AgentDefinition 中指定的 tools 列表进一步限制子 Agent 可用工具。

5. **AC5: 模型继承与覆盖** — 给定父 Agent 的模型配置，当子 Agent 未指定 model 参数，则继承父 Agent 的模型；当指定了 model 参数，则使用指定模型。

6. **AC6: SubAgentSpawner 协议解耦** — 给定 Tools/ 不能导入 Core/ 的架构约束，当 AgentTool 需要创建子 Agent，则通过 Types/ 中定义的 SubAgentSpawner 协议实现跨模块调用，Core/ 提供实现、Tools/ 通过 ToolContext 使用协议。

7. **AC7: AgentDefinition 扩展** — 给定现有 AgentDefinition 类型，当检查其属性，则包含 name、description、model、systemPrompt、tools（工具名列表）、maxTurns 字段，支持内置和自定义 agent 定义。

8. **AC8: 模块边界合规** — 给定 AgentTool.swift 位于 Tools/Advanced/ 目录，当检查 import 语句，则只导入 Foundation 和 Types/ 中的类型，永不导入 Core/（架构规则 #7、#40）。

9. **AC9: 错误处理** — 给定子 Agent 执行期间发生异常，当错误被捕获，则返回 is_error=true 的 ToolResult（内容包含错误描述），不会中断父 Agent 的智能循环（架构规则 #38）。

## Tasks / Subtasks

- [ ] Task 1: 扩展 AgentDefinition 类型 (AC: #7)
  - [ ] 在 `Sources/OpenAgentSDK/Types/AgentTypes.swift` 中追加 `tools: [String]?` 和 `maxTurns: Int?` 字段到 `AgentDefinition`
  - [ ] 保持现有 init 签名兼容（使用默认值 nil）
  - [ ] 新增带 tools 和 maxTurns 参数的 init 重载

- [ ] Task 2: 定义 SubAgentSpawner 协议和 SubAgentResult 类型 (AC: #6)
  - [ ] 在 `Sources/OpenAgentSDK/Types/AgentTypes.swift` 中定义 `SubAgentSpawner` 协议（Sendable，方法 spawn 返回 SubAgentResult）
  - [ ] 定义 `SubAgentResult` 结构体（text: String, toolCalls: [String], isError: Bool，Sendable + Equatable）
  - [ ] SubAgentSpawner.spawn 方法签名：prompt, model, systemPrompt, allowedTools, maxTurns 均为可选

- [ ] Task 3: 扩展 ToolContext (AC: #6)
  - [ ] 在 `Sources/OpenAgentSDK/Types/ToolTypes.swift` 中为 `ToolContext` 追加 `agentSpawner: SubAgentSpawner?` 字段
  - [ ] 更新 init 添加 agentSpawner 参数（默认值 nil，保持现有调用兼容）
  - [ ] 保持 Sendable 合规（SubAgentSpawner 本身是 Sendable 协议）

- [ ] Task 4: 实现 DefaultSubAgentSpawner (AC: #1, #2, #4, #5)
  - [ ] 在 `Sources/OpenAgentSDK/Core/` 下创建 `DefaultSubAgentSpawner.swift`
  - [ ] 实现 `SubAgentSpawner` 协议，内部持有 apiKey、baseURL、parentTools、parentModel
  - [ ] spawn 方法：过滤掉 AgentTool（按名称 "Agent"）、根据 allowedTools 过滤、创建新 AgentOptions、调用 agent.prompt()、收集结果
  - [ ] 错误路径：所有异常捕获并返回 isError=true 的 SubAgentResult

- [ ] Task 5: 定义内置 Agent 定义 (AC: #3)
  - [ ] 在 `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift` 中定义内置 Agent 常量
  - [ ] Explore: systemPrompt="You are a codebase exploration agent...", tools=["Read","Glob","Grep","Bash"]
  - [ ] Plan: systemPrompt="You are a software architect...", tools=["Read","Glob","Grep","Bash"]

- [ ] Task 6: 实现 AgentTool 工厂函数 (AC: #1, #2, #3, #4, #5, #8, #9)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift`
  - [ ] 定义 `AgentToolInput` Codable 结构体：prompt (必填), description (必填), subagent_type (可选), model (可选), name (可选), maxTurns (可选)
  - [ ] 定义 JSON inputSchema 匹配 TS SDK 的 Agent 工具 schema
  - [ ] `createAgentTool()` 工厂函数返回 ToolProtocol（使用 defineTool + ToolExecuteResult 重载）
  - [ ] call 逻辑：(1) 解析 subagent_type 查找 AgentDefinition；(2) 从 ToolContext.agentSpawner 获取 spawner；(3) 如果 spawner 为 nil 返回错误；(4) 调用 spawner.spawn()；(5) 格式化输出（文本 + 工具调用摘要）

- [ ] Task 7: 集成到 ToolContext 创建点 (AC: #6)
  - [ ] 修改 `Sources/OpenAgentSDK/Core/Agent.swift` 中 prompt() 和 stream() 方法
  - [ ] ToolContext 创建时传入 agentSpawner（从 DefaultSubAgentSpawner 创建，持有当前 agent 的配置）
  - [ ] 确保向后兼容：如果 tools 中不包含 AgentTool，agentSpawner 可以为 nil

- [ ] Task 8: 更新模块入口 (AC: #8)
  - [ ] 在 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 中追加 Advanced 工具部分的重新导出
  - [ ] 确认 AgentTool.swift 不导入 Core/

- [ ] Task 9: 单元测试 — AgentTool (AC: #1-#9)
  - [ ] 创建 `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`
  - [ ] 定义 `MockSubAgentSpawner` 实现测试替身
  - [ ] `testCreateAgentTool_returnsToolProtocol` — 工厂函数返回正确类型
  - [ ] `testAgentToolInput_decodeFromJson` — Codable 输入解码正确
  - [ ] `testAgentTool_success_returnsText` — spawner 成功时返回文本结果
  - [ ] `testAgentTool_success_includesToolSummary` — 有工具调用时附加摘要
  - [ ] `testAgentTool_spawnerNil_returnsError` — agentSpawner 为 nil 时返回错误
  - [ ] `testAgentTool_exploreType_usesExploreDefinition` — Explore 类型使用正确定义
  - [ ] `testAgentTool_planType_usesPlanDefinition` — Plan 类型使用正确定义
  - [ ] `testAgentTool_customModel_overridesDefault` — 自定义 model 覆盖默认
  - [ ] `testAgentTool_spawnerError_returnsIsError` — spawner 错误传播为 isError
  - [ ] `testAgentTool_noSpawner_returnsErrorMessage` — 无 spawner 场景处理

- [ ] Task 10: 单元测试 — DefaultSubAgentSpawner (AC: #4, #5)
  - [ ] 在 `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` 中测试
  - [ ] 使用 MockAnthropicClient 避免真实 API 调用
  - [ ] `testSpawn_filtersOutAgentTool` — 子 Agent 工具列表不含 "Agent"
  - [ ] `testSpawn_usesAllowedTools` — allowedTools 过滤生效
  - [ ] `testSpawn_inheritsModel` — 未指定 model 时继承父 Agent 模型
  - [ ] `testSpawn_overridesModel` — 指定 model 时使用指定模型
  - [ ] `testSpawn_error_returnsIsError` — API 错误时返回 isError=true

- [ ] Task 11: 单元测试 — 类型扩展 (AC: #6, #7)
  - [ ] 在 `Tests/OpenAgentSDKTests/Types/AgentTypesTests.swift` 中追加测试
  - [ ] `testAgentDefinition_withToolsAndMaxTurns`
  - [ ] `testAgentDefinition_defaultToolsAndMaxTurns_nil`
  - [ ] `testSubAgentResult_codableRoundTrip`
  - [ ] `testSubAgentResult_isError_true`

- [ ] Task 12: 编译验证
  - [ ] 运行 `swift build` 确认编译通过
  - [ ] 验证 `Tools/Advanced/AgentTool.swift` 不导入 `Core/`
  - [ ] 验证 `Core/DefaultSubAgentSpawner.swift` 可以导入 `Core/` 内部类型
  - [ ] 验证测试可以编译

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 4（多 Agent 编排）的第三个 story，建立在 Story 4-1/4-2 的 Stores/ 和 AgentRegistry 基础之上
- 本 story 实现第一个高级工具（Advanced tier tool）：AgentTool
- 本 story 引入 SubAgentSpawner 协议解决 Tools/ 不能导入 Core/ 的架构约束
- 与 TS SDK 的 agent-tool.ts 对齐，但使用 Swift actor/protocol 模式

**架构关键问题 — Tools/ 不能导入 Core/：**

TypeScript SDK 的 AgentTool 直接 import `QueryEngine` 和 `createProvider`（类似 Core/）。Swift 架构禁止这种依赖方向。

**解决方案：SubAgentSpawner 协议（定义在 Types/，实现在 Core/，使用在 Tools/）**

```
Types/AgentTypes.swift:  protocol SubAgentSpawner (定义)
Core/DefaultSubAgentSpawner.swift: class DefaultSubAgentSpawner (实现)
Tools/Advanced/AgentTool.swift: context.agentSpawner (使用)
```

ToolContext 扩展为携带 `agentSpawner: SubAgentSpawner?`，Core/ 在创建 ToolContext 时注入实现。这遵循了依赖倒置原则（DIP）—— Tools/ 依赖 Types/ 中的抽象，不依赖 Core/ 的具体实现。

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `AgentDefinition` | `Types/AgentTypes.swift` | 已有 name, description, model, systemPrompt；需追加 tools, maxTurns |
| `ToolContext` | `Types/ToolTypes.swift` | 已有 cwd, toolUseId；需追加 agentSpawner |
| `ToolResult` | `Types/ToolTypes.swift` | 复用现有（toolUseId, content, isError） |
| `ToolExecuteResult` | `Types/ToolTypes.swift` | defineTool 返回值（content, isError） |
| `defineTool()` | `Tools/ToolBuilder.swift` | 工厂函数，使用 CodableTool/StructuredCodableTool |
| `Agent` | `Core/Agent.swift` | prompt() 方法执行完整智能循环 |
| `AgentOptions` | `Types/AgentTypes.swift` | 创建子 Agent 的配置 |
| `AgentRegistry` | `Stores/AgentRegistry.swift` | Story 4-2 创建，本 story 可能不直接使用 |
| `ToolExecutor` | `Core/ToolExecutor.swift` | 执行工具并构建 ToolResult |
| `filterTools()` | `Tools/ToolRegistry.swift` | 按 allowed/disallowed 过滤工具列表 |
| `getAllBaseTools()` | `Tools/ToolRegistry.swift` | 获取核心工具列表 |

### 实现位置

**修改文件：**
```
Sources/OpenAgentSDK/Types/AgentTypes.swift           # 追加 tools, maxTurns 到 AgentDefinition；新增 SubAgentSpawner, SubAgentResult
Sources/OpenAgentSDK/Types/ToolTypes.swift            # 追加 agentSpawner 到 ToolContext
Sources/OpenAgentSDK/Core/Agent.swift                 # prompt()/stream() 创建 ToolContext 时注入 agentSpawner
Sources/OpenAgentSDK/OpenAgentSDK.swift               # 追加重新导出
```

**新增文件：**
```
Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift   # SubAgentSpawner 的默认实现
Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift       # AgentTool 工厂函数和内置 Agent 定义
```

**测试文件：**
```
Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift           # AgentTool 测试
Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift        # DefaultSubAgentSpawner 测试
Tests/OpenAgentSDKTests/Types/AgentTypesTests.swift                   # 追加类型测试
```

### 类型定义

**AgentDefinition 扩展（在现有定义上追加字段）：**

```swift
public struct AgentDefinition: Sendable {
    public let name: String
    public let description: String?
    public let model: String?
    public let systemPrompt: String?
    public let tools: [String]?      // 新增：允许的工具名列表
    public let maxTurns: Int?        // 新增：子 Agent 最大轮次

    // 保留现有 init（新增参数默认 nil）
    public init(
        name: String,
        description: String? = nil,
        model: String? = nil,
        systemPrompt: String? = nil,
        tools: [String]? = nil,
        maxTurns: Int? = nil
    ) { ... }
}
```

**SubAgentResult 结构体：**

```swift
/// Result returned from a sub-agent execution.
public struct SubAgentResult: Sendable, Equatable {
    public let text: String
    public let toolCalls: [String]
    public let isError: Bool

    public init(text: String, toolCalls: [String] = [], isError: Bool = false) {
        self.text = text
        self.toolCalls = toolCalls
        self.isError = isError
    }
}
```

**SubAgentSpawner 协议：**

```swift
/// Protocol for spawning sub-agents, defined in Types/ to allow
/// Tools/ to use it without importing Core/.
public protocol SubAgentSpawner: Sendable {
    func spawn(
        prompt: String,
        model: String?,
        systemPrompt: String?,
        allowedTools: [String]?,
        maxTurns: Int?
    ) async -> SubAgentResult
}
```

**ToolContext 扩展：**

```swift
public struct ToolContext: Sendable {
    public let cwd: String
    public let toolUseId: String
    public let agentSpawner: SubAgentSpawner?  // 新增

    public init(
        cwd: String,
        toolUseId: String = "",
        agentSpawner: SubAgentSpawner? = nil   // 新增，默认 nil
    ) { ... }
}
```

**AgentToolInput（私有 Codable 类型）：**

```swift
private struct AgentToolInput: Codable {
    let prompt: String
    let description: String
    let subagent_type: String?
    let model: String?
    let name: String?
    let maxTurns: Int?
}
```

注意字段命名使用 snake_case 匹配 TS SDK 的 inputSchema，但 Swift 的 Codable 自动映射需要在 CodingKeys 中处理。或者直接使用 snake_case 属性名（与 TS SDK 和 LLM 端 JSON 字段一致，参考 project-context.md 规则 #19）。

### DefaultSubAgentSpawner 实现要点

**在 Core/ 中实现，可以访问 Agent、AgentOptions、createAgent：**

```swift
/// Default implementation of SubAgentSpawner that creates real Agent instances.
final class DefaultSubAgentSpawner: SubAgentSpawner, @unchecked Sendable {
    private let apiKey: String
    private let baseURL: String?
    private let parentModel: String
    private let parentTools: [ToolProtocol]

    init(apiKey: String, baseURL: String?, parentModel: String, parentTools: [ToolProtocol]) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.parentModel = parentModel
        self.parentTools = parentTools
    }

    func spawn(
        prompt: String,
        model: String?,
        systemPrompt: String?,
        allowedTools: [String]?,
        maxTurns: Int?
    ) async -> SubAgentResult {
        // 1. 过滤掉 AgentTool（防递归）
        var subTools = parentTools.filter { $0.name != "Agent" }

        // 2. 如果指定了 allowedTools，进一步过滤
        if let allowed = allowedTools, !allowed.isEmpty {
            let allowedSet = Set(allowed)
            subTools = subTools.filter { allowedSet.contains($0.name) }
        }

        // 3. 创建子 Agent
        let options = AgentOptions(
            apiKey: apiKey,
            model: model ?? parentModel,
            baseURL: baseURL,
            systemPrompt: systemPrompt,
            maxTurns: maxTurns ?? 10,
            tools: subTools.isEmpty ? nil : subTools
        )
        let agent = Agent(options: options)

        // 4. 执行并收集结果
        do {
            let result = await agent.prompt(prompt)
            let isError = result.status != .success
            return SubAgentResult(
                text: result.text.isEmpty ? "(Subagent completed with no text output)" : result.text,
                toolCalls: [],  // TODO: Extract from result.messages if needed
                isError: isError
            )
        } catch {
            return SubAgentResult(
                text: "Subagent error: \(error.localizedDescription)",
                toolCalls: [],
                isError: true
            )
        }
    }
}
```

注意：`DefaultSubAgentSpawner` 使用 `@unchecked Sendable` 因为它持有 `[ToolProtocol]` 数组（ToolProtocol 是 Sendable，但数组本身的 Sendable 合规在 Swift 5.9 中可能需要标记）。

### AgentTool 工厂函数实现要点

```swift
/// 内置 Agent 定义
private let BUILTIN_AGENTS: [String: AgentDefinition] = [
    "Explore": AgentDefinition(
        name: "Explore",
        description: "Fast agent specialized for exploring codebases. Use for finding files, searching code, and answering questions about the codebase.",
        systemPrompt: "You are a codebase exploration agent. Search through files and code to answer questions. Be thorough but efficient. Use Glob to find files, Grep to search content, and Read to examine files.",
        tools: ["Read", "Glob", "Grep", "Bash"]
    ),
    "Plan": AgentDefinition(
        name: "Plan",
        description: "Software architect agent for designing implementation plans. Returns step-by-step plans and identifies critical files.",
        systemPrompt: "You are a software architect. Design implementation plans for the given task. Identify critical files, consider trade-offs, and provide step-by-step plans. Use search tools to understand the codebase before planning.",
        tools: ["Read", "Glob", "Grep", "Bash"]
    ),
]

public func createAgentTool() -> ToolProtocol {
    return defineTool(
        name: "Agent",
        description: "Launch a subagent to handle complex, multi-step tasks autonomously. Subagents have their own context and can run specialized tool sets.",
        inputSchema: agentToolSchema,
        isReadOnly: false
    ) { (input: AgentToolInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let spawner = context.agentSpawner else {
            return ToolExecuteResult(
                content: "Error: Agent spawner not available. The Agent tool requires a SubAgentSpawner to be configured.",
                isError: true
            )
        }

        let agentType = input.subagent_type ?? "general-purpose"
        let agentDef = BUILTIN_AGENTS[agentType]

        let result = await spawner.spawn(
            prompt: input.prompt,
            model: input.model ?? agentDef?.model,
            systemPrompt: agentDef?.systemPrompt,
            allowedTools: agentDef?.tools,
            maxTurns: input.maxTurns ?? agentDef?.maxTurns
        )

        var output = result.text
        if !result.toolCalls.isEmpty {
            output += "\n[Tools used: \(result.toolCalls.joined(separator: ", "))]"
        }

        return ToolExecuteResult(content: output, isError: result.isError)
    }
}
```

### ToolContext 注入点（Core/Agent.swift 修改）

在 `Agent.swift` 的 `prompt()` 和 `stream()` 方法中，ToolContext 创建时注入 agentSpawner：

```swift
// 在 prompt() 方法中（替换现有的 ToolContext 创建）
let agentSpawner: SubAgentSpawner? = {
    // 只有当工具列表中包含 "Agent" 工具时才创建 spawner
    let hasAgentTool = registeredTools.contains { $0.name == "Agent" }
    guard hasAgentTool else { return nil }
    return DefaultSubAgentSpawner(
        apiKey: options.apiKey ?? "",
        baseURL: options.baseURL,
        parentModel: model,
        parentTools: registeredTools
    )
}()

// 在工具执行处
let context = ToolContext(cwd: options.cwd ?? "", agentSpawner: agentSpawner)
```

注意：agentSpawner 应该在循环外创建一次（而不是每次工具执行时创建），因为它持有不可变的父 Agent 配置。

### TypeScript SDK 参考对比

**agent-tool.ts（TypeScript）：**
- 直接 import QueryEngine 和 createProvider（等价于 Swift 的 Core/）
- 使用模块级 `registeredAgents` Record（Swift 端使用 AgentRegistry actor）
- 子 Agent 通过 `new QueryEngine({...})` 创建
- 从子 Agent 工具列表中过滤掉 AgentTool 防递归
- 通过 `for await` 消费子 Agent 事件流收集文本和工具调用
- 错误被 try/catch 捕获并返回 is_error ToolResult

**Swift 端关键差异：**
| 方面 | TypeScript | Swift |
|------|-----------|-------|
| 子 Agent 创建 | 直接 new QueryEngine | 通过 SubAgentSpawner 协议解耦 |
| Agent 注册 | 模块级 Record | AgentRegistry Actor（Story 4-2） |
| 递归防护 | filter(t => t.name !== 'Agent') | spawner 内部 filter { $0.name != "Agent" } |
| 结果收集 | for await event 流 | agent.prompt() 返回 QueryResult |
| 工具传递 | getAllBaseTools + filter | parentTools + allowedTools 过滤 |
| 错误处理 | try/catch → is_error | do/catch → SubAgentResult(isError: true) |

### Story 4-2 的经验教训（必须遵循）

1. **ISO8601DateFormatter 缓存** — 本 story 不涉及 formatter
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **Actor 测试** — 使用 `await` 访问 actor 隔离方法
4. **错误路径测试** — 必须覆盖（规则 #28）
5. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - Public API`
6. **CI 环境** — XCTest 在 CI 可用，需确保测试通过

### 反模式警告

- **不要**在 Tools/Advanced/ 中导入 Core/ — 违反模块边界（规则 #7、#40）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — 在 ToolResult/ToolExecuteResult 中捕获返回（规则 #38）
- **不要**在 AgentTool 中直接创建 Agent — 必须通过 SubAgentSpawner 协议
- **不要**将 AgentTool 传入子 Agent 的工具列表 — 必须过滤掉防递归
- **不要**使用 Apple 专属框架 — 必须跨平台（规则 #43）
- **不要**在单元测试中发起真实 API 调用 — 使用 MockSubAgentSpawner
- **不要**修改 ToolContext 的现有 init 签名（会破坏现有代码）— 新增参数默认值 nil 保持兼容

### 模块边界注意事项

```
Types/AgentTypes.swift  → 新增 SubAgentSpawner, SubAgentResult, 扩展 AgentDefinition（叶节点，无出站依赖）
Types/ToolTypes.swift   → 扩展 ToolContext（追加 agentSpawner 字段，叶节点）
Core/DefaultSubAgentSpawner.swift → 导入 Types/（允许：Core 依赖 Types）
Core/Agent.swift → 修改 ToolContext 创建点，注入 spawner（内部修改）
Tools/Advanced/AgentTool.swift → 只导入 Foundation + Types/（永不导入 Core/）
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 4.1 (已完成) | TaskStore 和 MailboxStore 基础设施 |
| 4.2 (已完成) | AgentRegistry 可用于子 Agent 注册（本 story 暂不直接使用，后续 SendMessage 需要） |
| 4.4 (后续) | SendMessage 工具需要通过 AgentRegistry 发现队友 |
| 4.5 (后续) | Task 工具可关联子 Agent 的任务上下文 |
| 4.6 (后续) | Team 工具集使用 TeamStore 的 CRUD |

### 测试策略

**MockSubAgentSpawner（测试替身）：**
```swift
struct MockSubAgentSpawner: SubAgentSpawner {
    let result: SubAgentResult
    private(set) var spawnCalls: [(prompt: String, model: String?, systemPrompt: String?, allowedTools: [String]?, maxTurns: Int?)] = []

    func spawn(prompt: String, model: String?, systemPrompt: String?, allowedTools: [String]?, maxTurns: Int?) async -> SubAgentResult {
        return result
    }
}
```

**AgentTool 测试策略：**
- 所有测试使用 MockSubAgentSpawner，不发起真实 API 调用
- 测试 ToolProtocol 合规（name, description, inputSchema, isReadOnly）
- 测试输入解码（AgentToolInput 的 Codable 解析）
- 测试成功路径：spawner 返回文本 → ToolResult 正确格式
- 测试错误路径：spawner 返回错误 → isError=true
- 测试无 spawner 路径：agentSpawner 为 nil → 错误消息
- 测试内置 Agent 类型映射：Explore 和 Plan 的定义正确传递

**DefaultSubAgentSpawner 测试策略：**
- 使用 MockAnthropicClient（通过 Agent init 的 client 参数注入）
- 测试工具过滤：AgentTool 被移除
- 测试 allowedTools 过滤：只保留指定工具
- 测试模型继承和覆盖
- 测试错误传播

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR35 Tools/Advanced/AgentTool.swift]
- [Source: _bmad-output/planning-artifacts/architecture.md#架构边界 Tools 依赖规则]
- [Source: _bmad-output/project-context.md#规则 7 模块边界单向依赖]
- [Source: _bmad-output/project-context.md#规则 38 不从工具内部 throw]
- [Source: _bmad-output/project-context.md#规则 40 Tools 不导入 Core]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/agent-tool.ts] — TS AgentTool 完整实现参考
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentDefinition, AgentOptions, QueryResult
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol, ToolContext, ToolResult
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool 工厂函数
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — Agent.prompt(), Agent.stream(), ToolContext 创建点
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] — filterTools(), getAllBaseTools()
- [Source: _bmad-output/implementation-artifacts/4-2-team-store-agent-registry.md] — 前一 story 经验

### Project Structure Notes

- 修改 `Sources/OpenAgentSDK/Types/AgentTypes.swift` — 追加 tools, maxTurns 到 AgentDefinition；新增 SubAgentSpawner 协议和 SubAgentResult
- 修改 `Sources/OpenAgentSDK/Types/ToolTypes.swift` — 追加 agentSpawner 到 ToolContext
- 新建 `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift` — SubAgentSpawner 的 Core/ 实现
- 新建 `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift` — AgentTool 工厂和内置 Agent 定义
- 修改 `Sources/OpenAgentSDK/Core/Agent.swift` — ToolContext 创建时注入 agentSpawner
- 修改 `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 追加重新导出
- 新建 `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`
- 新建 `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`
- 新建/追加 `Tests/OpenAgentSDKTests/Types/AgentTypesTests.swift`
- 完全对齐架构文档的目录结构和模块边界

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

### Review Findings

- [x] [Review][Patch] ToolExecutor drops agentSpawner — executeReadOnlyConcurrent and executeMutationsSerial created new ToolContext without passing agentSpawner, functionally breaking sub-agent spawning [ToolExecutor.swift:160,197] — **fixed**
- [x] [Review][Patch] Mis-indented code in stream() DefaultSubAgentSpawner creation [Agent.swift:593-607] — **fixed**
- [x] [Review][Defer] SubAgentResult.toolCalls always empty (hardcoded []) — known limitation, TODO in code, deferred to future enhancement
- [x] [Review][Defer] API key fallback to empty string produces delayed auth failures — pre-existing pattern from original Agent init, not introduced by this change

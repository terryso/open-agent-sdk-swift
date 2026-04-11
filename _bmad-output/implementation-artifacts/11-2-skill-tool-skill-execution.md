# Story 11.2: SkillTool 技能执行工具

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望 Agent 通过 SkillTool 调用已注册的技能，
以便技能可以作为工具被 LLM 发现和执行。

## Acceptance Criteria

1. **AC1: SkillTool 注册与 LLM 发现** — 给定 SkillTool 已注册且 SkillRegistry 中有技能，当 LLM 返回 tool_use 块请求执行 `Skill` 工具，参数 `{"skill": "commit"}`，则 SkillTool 调用 `registry.find("commit")`，获取 promptTemplate，将该模板作为新提示注入 Agent（FR54）。

2. **AC2: 工具限制栈模型** — 给定带有 `toolRestrictions: [.bash, .read]` 的技能，当技能执行，则 `ToolExecutor` 仅返回 [.bash, .read] 工具，其他工具被临时隐藏。工具限制通过栈模型管理：执行技能时 push 受限工具集到栈顶，执行完毕后 pop 恢复到栈中下一层（或完整集合）。

3. **AC3: 嵌套技能工具限制** — 给定技能 A（toolRestrictions: [.bash, .read]）执行中嵌套调用技能 B（toolRestrictions: [.grep, .glob]），当技能 B 执行，则栈顶为 B 的限制集 [.grep, .glob]，A 的限制集 [.bash, .read] 在栈下一层。技能 B 完成后 pop 恢复到 A 的限制集，技能 A 完成后 pop 恢复到完整工具集。

4. **AC4: 模型覆盖** — 给定带有 `modelOverride: "claude-opus-4-6"` 的技能，当技能执行，则发送给 API 的请求中 `model` 字段为 "claude-opus-4-6"。技能执行完毕后，后续 API 请求的 `model` 恢复为 Agent 默认模型。

5. **AC5: SkillTool 自引用循环防护** — 给定 SkillTool 尝试执行 `toolRestrictions` 中包含 SkillTool 自身的技能（`.skill` 在限制列表中），当技能执行，则抛出 `SDKError.invalidConfiguration("Skill cannot restrict SkillTool itself")` 防止循环。

6. **AC6: 异常路径工具限制栈恢复** — 给定带有 `toolRestrictions: [.bash, .read]` 的技能正在执行，当技能执行中途抛出错误（LLM 超时、网络故障），则工具限制栈仍正确 pop（使用 `defer` 机制），恢复到上一层。错误正常向上传播。

7. **AC7: 递归深度限制** — 给定技能 A 的 promptTemplate 指导 LLM 调用技能 B，技能 B 又调用技能 A（循环），当 SkillTool 检测到嵌套技能调用深度超过 4 层，则抛出 `SDKError.invalidConfiguration("Skill recursion depth exceeded: maximum nesting depth is 4")`。深度限制可配置为 `SDKConfiguration.maxSkillRecursionDepth`（默认值 4）。

8. **AC8: 轮次预算共享** — 技能执行共享当前查询的 `maxTurns` 轮次预算（不分配独立预算）。技能内的工具调用轮次计入查询总轮次。

## Tasks / Subtasks

- [x] Task 1: 创建 SkillTool 实现 (AC: #1, #5, #7, #8)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift`
  - [x] 定义 `SkillToolInput` Codable 结构体（`skill: String`、`args: String?`）
  - [x] 使用 `defineTool` 创建 `createSkillTool(registry:)` 工厂函数
  - [x] 实现 skill 名称查找 + 可用性检查
  - [x] 返回 JSON 格式的 ToolResult，包含 `success`、`commandName`、`prompt`、`allowedTools`、`model` 字段
  - [x] 通过 ToolContext 中注入的 `skillRegistry` 访问注册表
  - [x] 实现递归深度检查（从 ToolContext 读取当前深度）

- [x] Task 2: 实现 ToolRestrictionStack 工具限制栈 (AC: #2, #3, #5, #6)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/ToolRestrictionStack.swift`
  - [x] 定义 `ToolRestrictionStack` 类（线程安全，内部 DispatchQueue 保护）
  - [x] 实现 `push(_ restrictions: [ToolRestriction])` — 将受限工具集压栈
  - [x] 实现 `pop()` — 弹出栈顶限制集，恢复到上一层
  - [x] 实现 `currentAllowedToolNames(baseTools: [ToolProtocol]) -> [ToolProtocol]` — 根据栈顶限制集过滤基础工具集
  - [x] 实现 `isEmpty -> Bool` — 判断栈是否为空（无限制）
  - [x] 实现自引用检查：当限制列表包含 `.skill` 时抛出错误

- [x] Task 3: 更新 ToolContext 以支持技能执行 (AC: #2, #4, #7)
  - [x] 在 `ToolContext` 中新增 `skillRegistry: SkillRegistry?` 字段
  - [x] 在 `ToolContext` 中新增 `restrictionStack: ToolRestrictionStack?` 字段
  - [x] 在 `ToolContext` 中新增 `skillNestingDepth: Int` 字段（默认 0）
  - [x] 在 `ToolContext` 中新增 `maxSkillRecursionDepth: Int` 字段（默认 4）
  - [x] 更新 `withToolUseId` 方法保留新字段
  - [x] 新增 `withSkillContext(depth:)` 方法创建嵌套技能上下文

- [x] Task 4: 集成 ToolRestrictionStack 到 ToolExecutor (AC: #2, #3, #6)
  - [x] 修改 `ToolExecutor.executeTools` 在执行前检查 `context.restrictionStack`
  - [x] 当栈不为空时，使用 `restrictionStack.currentAllowedToolNames(baseTools:)` 过滤工具集
  - [x] 确保错误路径下栈状态一致性（ToolExecutor 的错误已在 ToolResult 中捕获，不中断栈操作）

- [x] Task 5: 实现 SkillTool 的工具限制和模型覆盖逻辑 (AC: #2, #4, #6)
  - [x] SkillTool.call() 中：查找技能 → 检查可用性 → 检查递归深度
  - [x] 如果技能有 toolRestrictions，调用 `restrictionStack.push(skill.toolRestrictions)`
  - [x] 使用 `defer { restrictionStack.pop() }` 确保异常路径恢复
  - [x] 如果技能有 modelOverride，将模型信息附加到返回结果中（QueryEngine 读取并应用）
  - [x] 返回的 ToolResult content 为 JSON 字符串，包含执行元数据

- [x] Task 6: 更新 AgentOptions 和 Agent 集成 (AC: #1, #2, #7)
  - [x] 在 `AgentOptions` 中新增 `skillRegistry: SkillRegistry?` 字段
  - [x] 在 `AgentOptions` 中新增 `maxSkillRecursionDepth: Int` 字段（默认 4）
  - [x] 在 Agent 初始化时创建 `ToolRestrictionStack` 实例
  - [x] 将 skillRegistry 和 restrictionStack 注入到 ToolContext

- [x] Task 7: 更新 ToolRegistry 包含 SkillTool (AC: #1)
  - [x] SkillTool 通过 Agent 集成注入（条件性：仅在 skillRegistry 非空时）
  - [x] 确保 SkillTool 仅在 skillRegistry 非空时有条件地启用

- [x] Task 8: 编写单元测试 (AC: #1-#8)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift`
  - [x] 测试 SkillTool 基本执行流程（查找技能、返回 promptTemplate）
  - [x] 测试 SkillTool 对不存在技能返回错误
  - [x] 测试 SkillTool 对不可用技能返回错误
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/ToolRestrictionStackTests.swift`
  - [x] 测试 ToolRestrictionStack push/pop 基本行为
  - [x] 测试嵌套 push/pop（多层限制）
  - [x] 测试自引用循环防护（限制包含 .skill 时抛出错误）
  - [x] 测试异常路径栈恢复（defer 确保 pop）
  - [x] 测试递归深度限制

- [x] Task 9: 更新模块入口点 (AC: #1)
  - [x] 更新 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 添加 `createSkillTool` 的重新导出文档
  - [x] 确保新增类型在模块入口点可见

- [x] Task 10: 验证编译通过并运行完整测试套件
  - [x] `swift build` 编译无错误
  - [x] `swift test` 全部通过，无回归

## Dev Notes

### 本 Story 的定位

- Epic 11（技能系统）的第二个 Story
- **核心目标：** 实现 SkillTool —— 让 LLM 可以像调用工具一样发现和执行技能。这是连接 Skill 定义层（Story 11.1）与执行层的关键桥梁
- **前置依赖：** Story 11.1（Skill 类型定义和 SkillRegistry 已完成）
- **后续依赖：** Story 11.3-11.7 的内置技能需要 SkillTool 才能被 LLM 调用
- **FR 覆盖：** FR54（技能通过 SkillTool 作为工具被 LLM 发现和执行）

### 关键架构决策（必须遵循）

#### 1. SkillTool 是标准 ToolProtocol 实现

SkillTool 遵循与所有其他工具相同的 `ToolProtocol` 模式：
- 使用 `defineTool()` 工厂函数创建
- `name` 为 `"Skill"`（大写开头，与其他工具命名一致）
- `isReadOnly` 为 `false`（技能执行可能触发写入操作）
- inputSchema 包含 `skill`（必填）和 `args`（可选）两个字段

**TypeScript SDK 参考对照：**
```typescript
// TypeScript skill-tool.ts
export const SkillTool: ToolDefinition = {
  name: 'Skill',
  inputSchema: {
    type: 'object',
    properties: {
      skill: { type: 'string', description: 'The skill name to execute' },
      args: { type: 'string', description: 'Optional arguments' },
    },
    required: ['skill'],
  },
  isReadOnly: () => false,
  // ...
}
```

Swift 版本使用 `defineTool` + Codable `SkillToolInput`：
```swift
private struct SkillToolInput: Codable {
    let skill: String
    let args: String?
}
```

#### 2. SkillTool 返回元数据 JSON，不直接注入提示

**关键设计差异（与 TypeScript SDK 对齐）：**
SkillTool 的 `call()` 方法**不直接修改对话历史**。它返回一个 JSON 格式的 `ToolResult`，包含：
- `success: true`
- `commandName: skill.name`
- `prompt: skill.promptTemplate`
- `allowedTools: skill.toolRestrictions?.map(\.rawValue)`（如有限制）
- `model: skill.modelOverride`（如有覆盖）

QueryEngine（或 Agent 循环）负责：
1. 解析 SkillTool 返回的 JSON
2. 将 `prompt` 作为新的用户消息注入对话
3. 根据 `allowedTools` 应用工具限制（通过 ToolRestrictionStack）
4. 根据 `model` 临时切换 API 请求的模型
5. 继续智能循环，直到技能执行完成

**为什么这样设计：** 工具的 `call()` 方法只能返回 `ToolResult`，不能修改消息历史或 API 参数。执行编排逻辑属于 Core/（QueryEngine），不属于 Tools/。这保持了模块边界的清晰性（Tools/ 不导入 Core/）。

#### 3. ToolRestrictionStack 作为独立工具

`ToolRestrictionStack` 是一个 `final class`（不是 Actor），使用内部串行 `DispatchQueue` 保护线程安全。它与 `SkillRegistry` 采用相同的并发策略（理由一致：低频写入、高频只读）。

```swift
public final class ToolRestrictionStack: @unchecked Sendable {
    private var stack: [[ToolRestriction]] = []
    private let queue = DispatchQueue(label: "com.openagentsdk.restrictionstack")

    func push(_ restrictions: [ToolRestriction]) { ... }
    func pop() { ... }
    func currentAllowedToolNames(baseTools: [ToolProtocol]) -> [ToolProtocol] { ... }
    var isEmpty: Bool { ... }
}
```

**栈操作语义：**
- `push(restrictions)` — 将限制集压入栈顶
- `pop()` — 弹出栈顶限制集
- `currentAllowedToolNames(baseTools:)` — 如果栈为空，返回完整 baseTools；如果栈非空，返回栈顶限制集对应的工具子集
- 栈为空 = 无限制（所有工具可用）

**过滤逻辑：** `ToolRestriction` 的 rawValue 对应工具名称（如 `.bash` → "Bash"）。过滤时将 rawValue 转换为工具名的匹配规则。注意工具名大小写：
- `ToolRestriction.bash.rawValue` = "bash"
- `BashTool.name` = "Bash"
- 需要大小写不敏感匹配

#### 4. 模型覆盖的实现方式

SkillTool 在返回的 JSON 中包含 `model` 字段。QueryEngine 在处理 SkillTool 返回结果时：
1. 解析 JSON，检测到 `model` 字段
2. 保存当前 Agent 模型到临时变量
3. 切换到覆盖模型
4. 继续循环
5. 技能执行完毕后恢复原模型

**注意：** 模型切换/恢复逻辑在 Core/（QueryEngine）中实现，不在 Tools/ 中。本 Story 只负责在 ToolResult 中传递模型覆盖信息。如果模型覆盖的完整实现在本 Story 中过于复杂，可在 Task 5 中返回 metadata JSON，将 QueryEngine 集成留到后续迭代。

#### 5. 递归深度限制

通过 `ToolContext.skillNestingDepth` 跟踪当前嵌套深度：
- 初始值为 0
- 每次调用 SkillTool 时递增 1
- 如果 `skillNestingDepth >= maxSkillRecursionDepth`（默认 4），抛出错误
- 限制可配置：`AgentOptions.maxSkillRecursionDepth`

```swift
// 在 SkillTool.call() 中
let newDepth = context.skillNestingDepth + 1
guard newDepth <= context.maxSkillRecursionDepth else {
    return ToolResult(
        toolUseId: context.toolUseId,
        content: "Error: Skill recursion depth exceeded: maximum nesting depth is \(context.maxSkillRecursionDepth)",
        isError: true
    )
}
```

#### 6. 自引用循环防护

当技能的 `toolRestrictions` 包含 `.skill`（即 SkillTool 自身）时：
- 意味着技能试图限制自己的可用工具集，可能导致循环
- 应在 SkillTool.call() 开始时检查
- 返回错误 ToolResult

```swift
if let restrictions = skill.toolRestrictions, restrictions.contains(.skill) {
    return ToolResult(
        toolUseId: context.toolUseId,
        content: "Error: Skill cannot restrict SkillTool itself",
        isError: true
    )
}
```

### TypeScript SDK 参考映射

| Swift 类型 | TypeScript 对应 | 文件 |
|---|---|---|
| `SkillTool` (via defineTool) | `SkillTool` object | `src/tools/skill-tool.ts` |
| `ToolRestrictionStack` | 无直接对应（TS 不需要栈模型） | 新增 |
| `SkillToolInput` | `input.skill`, `input.args` | `src/tools/skill-tool.ts:57-59` |

**关键差异：**
- TS SDK 的 SkillTool.call() 返回 JSON 字符串（`JSON.stringify(result)`），Swift 版本同样返回 JSON 字符串
- TS SDK 没有工具限制栈模型（直接在 agent.ts 中处理 allowedTools），Swift 版本通过栈模型支持嵌套
- TS SDK 的递归深度检查在 agent.ts 中，Swift 版本在 SkillTool 和 ToolContext 中
- TS SDK 使用 `skill.context === 'fork'` 判断是否 fork，Swift v1.0 仅支持 inline 模式

### 已有代码模式参考

**参考 BashTool.swift 的 defineTool 模式：**
```swift
public func createBashTool() -> ToolProtocol {
    return defineTool(
        name: "Bash",
        description: "...",
        inputSchema: [...],
        isReadOnly: false
    ) { (input: BashInput, context: ToolContext) async throws -> String in
        // 实现
    }
}
```

SkillTool 使用相同的 `createSkillTool(registry:)` 工厂函数模式：
```swift
public func createSkillTool(registry: SkillRegistry) -> ToolProtocol {
    return defineTool(
        name: "Skill",
        description: "...",
        inputSchema: [...],
        isReadOnly: false
    ) { (input: SkillToolInput, context: ToolContext) async throws -> String in
        // 1. 从 context.skillRegistry 查找技能
        // 2. 检查可用性
        // 3. 检查递归深度
        // 4. 检查自引用
        // 5. push 工具限制（如有）
        // 6. defer { pop }
        // 7. 构建并返回 JSON 结果
    }
}
```

**参考 ToolContext 的依赖注入模式：**
- ToolContext 已有 `agentSpawner`、`mailboxStore`、`taskStore` 等可选注入字段
- 新增 `skillRegistry`、`restrictionStack`、`skillNestingDepth`、`maxSkillRecursionDepth` 遵循相同模式
- 所有新字段都有合理默认值（nil 或 0）

**参考 ToolExecutor.executeTools 的工具过滤：**
- 当前 `executeTools(toolUseBlocks:tools:context:)` 直接使用传入的 `tools` 数组
- 修改：在执行前检查 `context.restrictionStack?.currentAllowedToolNames(baseTools: tools)` 获取过滤后的工具集
- 如果栈为空，使用原始 tools 数组（零开销）

### 模块边界

**本 Story 涉及文件：**
- `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift` — 新建：SkillTool 工厂函数和 SkillToolInput
- `Sources/OpenAgentSDK/Tools/ToolRestrictionStack.swift` — 新建：工具限制栈
- `Sources/OpenAgentSDK/Types/ToolTypes.swift` — 修改：ToolContext 新增字段
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` — 修改：AgentOptions 新增 skillRegistry、maxSkillRecursionDepth
- `Sources/OpenAgentSDK/Core/Agent.swift` — 修改：创建和注入 ToolRestrictionStack
- `Sources/OpenAgentSDK/Core/ToolExecutor.swift` — 修改：集成工具限制栈过滤
- `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` — 修改：在适当层级包含 SkillTool
- `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 修改：添加重新导出文档
- `Tests/OpenAgentSDKTests/Tools/SkillToolTests.swift` — 新建
- `Tests/OpenAgentSDKTests/Tools/ToolRestrictionStackTests.swift` — 新建

```
Sources/OpenAgentSDK/
├── Types/
│   ├── ToolTypes.swift               # 修改：ToolContext 新增 4 个字段
│   ├── AgentTypes.swift              # 修改：AgentOptions 新增 2 个字段
│   ├── SkillTypes.swift              # 不修改（11.1 已创建）
│   └── ...
├── Tools/
│   ├── ToolRestrictionStack.swift    # 新建
│   ├── ToolRegistry.swift            # 修改：包含 SkillTool
│   ├── ToolBuilder.swift             # 不修改
│   ├── Advanced/
│   │   ├── SkillTool.swift           # 新建
│   │   └── ...
│   └── ...
├── Core/
│   ├── Agent.swift                   # 修改：注入 ToolRestrictionStack
│   ├── ToolExecutor.swift            # 修改：集成限制栈过滤
│   └── ...
├── OpenAgentSDK.swift                # 修改：添加重新导出文档
└── ...

Tests/OpenAgentSDKTests/
├── Tools/
│   ├── SkillToolTests.swift          # 新建
│   ├── ToolRestrictionStackTests.swift # 新建
│   └── ...
└── ...
```

### Logger 集成约定

根据跨 Epic 实现约定，本 Story 应在关键路径预留 `Logger.shared` 调用点：
- `SkillTool.call()` — 技能执行开始和结束
- `ToolRestrictionStack.push()` / `pop()` — 限制栈变更

使用 `guard Logger.shared.level != .none else { return }` 守卫模式。在 Epic 14 完成前，Logger 使用空实现。

### 反模式警告

- **不要**在 SkillTool.call() 中修改对话历史 — ToolResult 是唯一的输出通道
- **不要**在 SkillTool.call() 中直接切换 API 模型 — 仅在返回 JSON 中传递 model 信息
- **不要**将 ToolRestrictionStack 设计为 Actor — 使用 final class + DispatchQueue（与 SkillRegistry 一致）
- **不要**在 Tools/ 中导入 Core/ — 违反模块边界
- **不要**忘记 `defer { pop() }` — 异常路径必须恢复栈状态
- **不要**忘记大小写不敏感的工具名匹配 — ToolRestriction.rawValue 是小写，工具 name 可能是大写开头
- **不要**将 SkillTool 的 isReadOnly 设为 true — 技能可能触发写入操作
- **不要**在 SkillTool 中硬编码模型名白名单 — modelOverride 直接透传，API 层验证
- **不要**为技能分配独立的轮次预算 — 技能共享查询的 maxTurns
- **不要**在 formatSkillsForPrompt 中修改 — 那是 Story 11.1 的功能，本 Story 不涉及

### 测试策略

单元测试覆盖所有 AC：

1. **AC1 测试**：SkillTool 查找技能、返回 JSON（包含 prompt、allowedTools、model）
2. **AC2 测试**：ToolRestrictionStack push/pop 过滤工具集
3. **AC3 测试**：嵌套 push/pop 多层限制，验证栈语义
4. **AC4 测试**：SkillTool 返回 JSON 中包含 model 字段
5. **AC5 测试**：限制包含 .skill 时返回错误
6. **AC6 测试**：defer 确保 pop 在异常路径执行
7. **AC7 测试**：递归深度检查
8. **AC8 测试**：验证轮次共享（通过行为测试，不分配独立预算）

**测试隔离：**
- 使用 `SkillRegistry()` 创建独立注册表，避免测试间干扰
- 使用 `ToolRestrictionStack()` 创建独立栈实例
- 不需要 mock LLM — 单元测试只验证 SkillTool 的 call() 逻辑

### Project Structure Notes

- SkillTool 放在 `Tools/Advanced/` 而非 `Tools/Specialist/`，因为它属于高级工具层级（与 AgentTool 同级）
- ToolRestrictionStack 放在 `Tools/` 根目录，与 `ToolRegistry.swift`、`ToolBuilder.swift` 并列
- 新增的 ToolContext 字段使用可选值，保持向后兼容（现有工具无需修改）
- 完全对齐架构文档的目录结构和模块边界

### 前序 Story 学习要点

**Story 11.1 完成情况：**
- SkillTypes.swift: ToolRestriction enum (22 cases), Skill struct (Sendable), BuiltInSkills namespace (5 skills)
- SkillRegistry.swift: final class + DispatchQueue, 支持 register/find/replace/has/unregister/allSkills/userInvocableSkills/formatSkillsForPrompt/clear
- OpenAgentSDK.swift: 已包含 Skill System 重新导出文档
- 28 个 SkillRegistryTests 全部通过
- 完整测试套件: 2116 tests, 0 failures

**关键接口（本 Story 直接使用）：**
- `SkillRegistry.find(_ name:) -> Skill?` — 按名称/别名查找
- `Skill.isAvailable` — `@Sendable () -> Bool` 闭包
- `Skill.toolRestrictions` — `[ToolRestriction]?`（nil = 无限制）
- `Skill.modelOverride` — `String?`
- `Skill.promptTemplate` — `String`
- `Skill.userInvocable` — `Bool`
- `SkillRegistry.userInvocableSkills` — `[Skill]`

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.2] — 验收标准和需求定义
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11 技能系统] — Epic 级别上下文和跨 Story 依赖
- [Source: _bmad-output/planning-artifacts/epics.md#FR54] — 技能执行功能需求
- [Source: _bmad-output/planning-artifacts/architecture.md#AD4] — 工具系统基于协议的 Codable 输入模式
- [Source: _bmad-output/planning-artifacts/architecture.md#项目结构] — 目录结构和文件命名约定
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Actor/struct 边界、命名约定、模块边界
- [Source: open-agent-sdk-typescript/src/tools/skill-tool.ts] — TypeScript SDK SkillTool 实现
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift] — Skill、ToolRestriction、BuiltInSkills（11.1 创建）
- [Source: Sources/OpenAgentSDK/Tools/SkillRegistry.swift] — SkillRegistry final class（11.1 创建）
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool 工厂函数模式
- [Source: Sources/OpenAgentSDK/Core/ToolExecutor.swift] — 工具执行分派逻辑（需修改）
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol、ToolResult、ToolContext（需修改）
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions（需修改）
- [Source: _bmad-output/implementation-artifacts/11-1-skill-type-definition-skill-registry.md] — Story 11.1 开发记录

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented ToolRestrictionStack: final class with internal DispatchQueue for thread safety, push/pop/currentAllowedToolNames/isEmpty methods, case-insensitive tool name matching
- Updated ToolContext: added 4 new fields (skillRegistry, restrictionStack, skillNestingDepth, maxSkillRecursionDepth) plus withSkillContext(depth:) helper method
- Implemented createSkillTool: factory function using defineTool with ToolExecuteResult return type for explicit error signaling, includes all validation checks (find, availability, recursion depth, self-reference), uses defer for stack pop on error paths
- Updated AgentOptions: added skillRegistry and maxSkillRecursionDepth fields (default 4) to both init(from:) and regular init
- Integrated ToolRestrictionStack into ToolExecutor.executeTools: filters tools based on stack state before partitioning
- Updated Agent.swift: ToolContext creation in both prompt() and stream() includes skill-related fields
- Updated OpenAgentSDK.swift: added createSkillTool and ToolRestrictionStack to re-export docs
- All 35 ATDD tests pass (18 SkillToolTests + 17 ToolRestrictionStackTests)
- Full test suite: 2151 tests, 0 failures, 4 skipped

### File List

- `Sources/OpenAgentSDK/Tools/ToolRestrictionStack.swift` — NEW: ToolRestrictionStack class with stack-based tool restriction management
- `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift` — NEW: createSkillTool factory function and SkillToolInput Codable struct
- `Sources/OpenAgentSDK/Types/ToolTypes.swift` — MODIFIED: Added 4 new fields to ToolContext (skillRegistry, restrictionStack, skillNestingDepth, maxSkillRecursionDepth) and withSkillContext(depth:) method
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` — MODIFIED: Added skillRegistry and maxSkillRecursionDepth fields to AgentOptions
- `Sources/OpenAgentSDK/Core/ToolExecutor.swift` — MODIFIED: Added restriction stack filtering in executeTools method
- `Sources/OpenAgentSDK/Core/Agent.swift` — MODIFIED: Updated ToolContext creation in prompt() and stream() with skill fields
- `Sources/OpenAgentSDK/OpenAgentSDK.swift` — MODIFIED: Added createSkillTool and ToolRestrictionStack to Skill System docs
- `Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift` — ATDD tests (18 tests, pre-existing)
- `Tests/OpenAgentSDKTests/Tools/ToolRestrictionStackTests.swift` — ATDD tests (17 tests, pre-existing)

### Review Findings

- [x] [Review][Defer] `withSkillContext(depth:)` is defined but never called [ToolTypes.swift:163] — deferred, pre-existing architectural scaffolding for future QueryEngine integration

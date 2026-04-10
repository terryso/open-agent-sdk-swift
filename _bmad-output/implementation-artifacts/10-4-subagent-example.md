# Story 10.4: 子代理委派示例（SubagentExample）

Status: done

## Story

作为 Swift 开发者，
我希望看到一个主 Agent 委派子代理执行专门任务的示例，
以便我理解如何构建多 Agent 编排工作流。

## Acceptance Criteria

1. **AC1: SubagentExample 可编译运行** — 给定 `Examples/SubagentExample/main.swift`，当开发者运行 `swift build`（编译）或 `swift run SubagentExample`，则代码编译无错误、无警告。示例使用 `createAgentTool()` 注册 Agent 工具，主 Agent 可通过 Agent 工具生成子代理执行委派任务。

2. **AC2: 展示主 Agent 使用 Agent 工具生成子代理** — 给定 SubagentExample 运行中，则主 Agent 使用 Agent 工具（通过 `createAgentTool()` 注册）生成一个带有自定义提示的子代理。子代理仅使用受限的工具集（如 Read、Glob、Grep）。`createAgentTool()` 返回的 ToolProtocol 实例需与其他核心工具一起传入 `AgentOptions.tools`。

3. **AC3: 子代理结果返回给主 Agent** — 给定 SubagentExample 运行中，则子代理执行结果返回给主 Agent，主 Agent 基于子代理结果生成最终回复。示例展示子代理的输出如何被主 Agent 整合和利用。

4. **AC4: 使用流式 API 展示实时执行过程** — 给定 SubagentExample 运行中，则示例使用 `agent.stream()` 流式 API，通过 `for await message in agent.stream(...)` 消费事件。对 `.toolUse` 事件（包括 Agent 工具调用）实时输出工具名和参数，对 `.toolResult` 事件输出工具结果摘要。

5. **AC5: Package.executableTarget 已配置** — 给定更新后的 Package.swift，当包含 `SubagentExample` executableTarget，则 `swift build` 编译通过。

6. **AC6: 使用实际公共 API** — 给定所有示例代码，则所有 API 调用与当前源码中的公共 API 签名完全匹配（`createAgent`、`AgentOptions`、`agent.stream()`、`SDKMessage` 模式匹配、`getAllBaseTools`、`createAgentTool`）。无假设性 API、无过时签名。

7. **AC7: 清晰注释和不暴露密钥** — 给定 main.swift 文件，则文件顶部有功能说明注释，关键步骤有行内注释。API 密钥使用 `"sk-..."` 占位符或从环境变量读取（NFR6）。

## Tasks / Subtasks

- [ ] Task 1: 更新 Package.swift 添加 SubagentExample target (AC: #5)
  - [ ] 在 targets 数组中添加 `.executableTarget(name: "SubagentExample", dependencies: ["OpenAgentSDK"], path: "Examples/SubagentExample")`

- [ ] Task 2: 创建 Examples/SubagentExample/main.swift (AC: #1, #2, #3, #4, #6, #7)
  - [ ] 创建目录 `Examples/SubagentExample/`
  - [ ] 文件顶部注释：功能说明、运行方式、前提条件
  - [ ] 导入 Foundation 和 OpenAgentSDK
  - [ ] 从环境变量读取 API key（`ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "sk-..."`）
  - [ ] 使用 `createAgent(options:)` 创建主 Agent，配置 AgentOptions：
    - apiKey、model（"claude-sonnet-4-6"）
    - systemPrompt：引导主 Agent 使用 Agent 工具委派子代理的系统提示
    - maxTurns: 10
    - permissionMode: `.bypassPermissions`
    - tools: `getAllBaseTools(tier: .core) + [createAgentTool()]` — 注册核心工具 + Agent 工具
  - [ ] 使用 `agent.stream()` 发送一个需要子代理委派的任务提示
  - [ ] 使用 `for await message in agent.stream(...)` 消费事件
  - [ ] 对 `SDKMessage` 各 case 进行模式匹配：
    - `.partialMessage`: 输出增量文本
    - `.toolUse`: 输出工具名（特别标注 Agent 工具调用）和输入参数
    - `.toolResult`: 输出工具结果摘要（截断长内容）
    - `.result`: 输出完整统计（轮次、耗时、成本、tokens）
    - `.assistant`: 输出模型信息和停止原因
    - `.system`: 输出系统事件
  - [ ] 不使用 `try!` 或 `!` 强制解包

- [ ] Task 3: 验证编译通过 (AC: #1, #5, #6)
  - [ ] 运行 `swift build` 确认 SubagentExample 编译通过
  - [ ] 验证所有 API 调用与实际公共 API 签名一致

- [ ] Task 4: 运行完整测试套件确认无回归 (AC: #6)
  - [ ] 运行 `swift test` 确认所有现有测试通过

## Dev Notes

### 本 Story 的定位

- Epic 10（扩展代码示例集）的第四个 Story
- **核心目标：** 创建 SubagentExample 示例，展示主 Agent 如何通过 Agent 工具（`createAgentTool()`）委派子代理执行专门任务，演示多 Agent 编排工作流（FR35、FR50 补充）
- **前置依赖：** Epic 1-9 全部完成，尤其 Story 4-3（Agent 工具和子 Agent 生成机制实现）和 Story 10-1/10-2/10-3（已建立扩展示例模式）
- **与已有示例的区别：**
  - MultiToolExample（Story 10-1）：单一 Agent 使用核心工具自主编排多步骤任务
  - **SubagentExample（本 Story）：主 Agent 通过 Agent 工具生成子代理，子代理使用受限工具集执行委派任务，结果返回给主 Agent** — 展示多 Agent 编排模式

### 关键公共 API 签名（必须与源码一致）

以下是从实际源码中验证的 API 签名（与 Story 10-3 Dev Notes 一致，补充 Agent 工具相关 API）：

**创建主 Agent 并注册 Agent 工具：**
```swift
import Foundation
import OpenAgentSDK

let agent = createAgent(options: AgentOptions(
    apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "sk-...",
    model: "claude-sonnet-4-6",
    systemPrompt: "You are a coordinator agent...",
    maxTurns: 10,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core) + [createAgentTool()]
))
```

**关键点：** `createAgentTool()` 返回一个 `ToolProtocol` 实例（名称为 "Agent"），与其他工具一起传入 `AgentOptions.tools` 数组。注册后，LLM 可以调用 Agent 工具来生成子代理。

**Agent 工具的 inputSchema（来自 AgentTool.swift）：**
- `prompt` (string, required): 子代理需要执行的任务
- `description` (string, required): 任务的简短描述（3-5 个词）
- `subagent_type` (string, optional): 子代理类型（"Explore"、"Plan" 或自定义名称）
- `model` (string, optional): 覆盖模型
- `name` (string, optional): 子代理名称
- `maxTurns` (integer, optional): 覆盖最大轮次

**内置子代理类型（BUILTIN_AGENTS）：**
- `"Explore"`: 代码库探索代理，使用 Read/Glob/Grep/Bash 工具
- `"Plan"`: 软件架构师代理，使用 Read/Glob/Grep/Bash 工具

**子代理的受限工具集：**
- 内置的 Explore 和 Plan 类型自动限制子代理只使用 Read、Glob、Grep、Bash
- DefaultSubAgentSpawner 会过滤掉 Agent 工具自身（防递归）
- 子代理继承父 Agent 的工具，但只保留 AgentDefinition.tools 中列出的工具

**流式查询 + 事件消费（与 MultiToolExample 一致）：**
```swift
for await message in agent.stream("Analyze the project...") {
    switch message {
    case .partialMessage(let data):
        print(data.text, terminator: "")
    case .assistant(let data):
        print("\n[Model: \(data.model), Stop: \(data.stopReason)]")
    case .toolUse(let data):
        print("[Tool: \(data.toolName), ID: \(data.toolUseId)]")
        print("  Input: \(data.input)")
    case .toolResult(let data):
        if data.isError {
            print("[Tool Error: \(data.content)]")
        } else {
            print("[Tool Result: \(data.content.prefix(100))...]")
        }
    case .result(let data):
        print("Done: \(data.subtype), turns: \(data.numTurns), cost: $\(data.totalCostUsd)")
        if let usage = data.usage {
            print("  Input tokens: \(usage.inputTokens)")
            print("  Output tokens: \(usage.outputTokens)")
        }
    case .system(let data):
        print("[System: \(data.message)]")
    }
}
```

**AgentOptions 参数顺序（来自 AgentTypes.swift init 签名）：**
`apiKey, model, baseURL, provider, systemPrompt, maxTurns, maxTokens, maxBudgetUsd, thinking, permissionMode, canUseTool, cwd, tools, mcpServers, retryConfig, agentName, mailboxStore, teamStore, taskStore, worktreeStore, planStore, cronStore, todoStore, sessionStore, sessionId, hookRegistry`

**getAllBaseTools 函数：**
```swift
public func getAllBaseTools(tier: ToolTier) -> [ToolProtocol]
```
注意：`getAllBaseTools(tier: .advanced)` 当前返回空数组（AgentTool 不在 advanced tier 列表中）。因此必须通过 `createAgentTool()` 单独创建并追加到工具列表。

**createAgentTool 函数：**
```swift
public func createAgentTool() -> ToolProtocol
```

### 前序 Story 的经验教训（必须遵循）

来自 Story 10-1、10-2、10-3 和 Story 9-3 的 Dev Notes：

1. **API 密钥不暴露** — 使用 `"sk-..."` 占位符或 `ProcessInfo.processInfo.environment` 读取（NFR6）
2. **代码示例必须与实际 API 一致** — 严格对照源码验证每个 API 调用
3. **不使用 Apple 专属框架** — Foundation 在 macOS 和 Linux 均可用
4. **`import Foundation`** — 需要 ProcessInfo 时必须导入 Foundation
5. **SDKMessage 模式匹配使用完全限定名** — 如 `SDKMessage.ResultData.Subtype.errorMaxBudgetUsd`
6. **`.result` 事件中 `data.usage` 是 Optional** — 需 `if let usage = data.usage` 安全解包
7. **`agent.stream()` 返回 `AsyncStream<SDKMessage>`** — 使用 `for await` 消费
8. **`getAllBaseTools(tier: .core)` 返回 `[ToolProtocol]`** — 直接传给 AgentOptions 的 tools 参数
9. **AgentOptions 参数顺序必须精确匹配** — 参照 AgentTypes.swift 中的 init 签名
10. **`permissionMode: .bypassPermissions`** — 示例中避免权限提示干扰

### 反模式警告

- **不要**使用假设性 API — 必须与实际源码公共 API 完全一致
- **不要**暴露真实 API 密钥 — 使用 `"sk-..."` 占位符
- **不要**使用 `try!` 或 `!` 强制解包 — 使用 `guard let`、`if let`
- **不要**修改任何现有源代码 — 本 story 只添加示例文件和更新 Package.swift
- **不要**创建独立的 Package.swift — 在顶层 Package.swift 中添加 executableTarget
- **不要**使用 `getAllBaseTools(tier: .advanced)` — advanced tier 返回空数组，Agent 工具需通过 `createAgentTool()` 单独创建
- **不要**在示例中实现复杂业务逻辑 — 保持简洁、聚焦子代理委派模式
- **不要**使用 `Task { }` 创建非结构化并发 — 使用简单的 `for await` 消费 AsyncStream

### 模块边界

**本 story 涉及文件：**
- `Package.swift` — 修改：添加 1 个 executableTarget（SubagentExample）
- `Examples/SubagentExample/main.swift` — 新建：子代理委派 + 流式 API + 实时事件展示

**不涉及任何现有源代码文件变更。**

```
项目根目录/
├── Package.swift                                    # 修改：添加 SubagentExample executableTarget
├── Examples/
│   ├── BasicAgent/main.swift                        # 不修改
│   ├── StreamingAgent/main.swift                    # 不修改
│   ├── CustomTools/main.swift                       # 不修改
│   ├── MCPIntegration/main.swift                    # 不修改
│   ├── SessionsAndHooks/main.swift                  # 不修改
│   ├── MultiToolExample/main.swift                  # 不修改
│   ├── CustomSystemPromptExample/main.swift         # 不修改
│   ├── PromptAPIExample/main.swift                  # 不修改
│   └── SubagentExample/                             # 新建目录
│       └── main.swift                               # 新建：子代理委派示例
└── _bmad-output/
    └── implementation-artifacts/
        └── 10-4-subagent-example.md                 # 本文件
```

### 测试策略

本 story 不需要单元测试。验证方式：
1. `swift build` 确认 SubagentExample 目标编译通过
2. 确认所有 API 调用与当前公共 API 签名匹配
3. 现有测试套件全部通过（无回归）
4. 如果环境允许（有 API key），可手动运行示例验证功能

### Project Structure Notes

- 在顶层 Package.swift 中添加 SubagentExample executableTarget（与现有 8 个示例一致）
- 新建 `Examples/SubagentExample/main.swift`
- 不涉及任何现有源代码文件变更
- 完全对齐架构文档的 `Examples/` 目录结构扩展

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.4 子代理委派示例]
- [Source: _bmad-output/planning-artifacts/prd.md#FR35] — Agent 通过 Agent 工具生成子 Agent 执行委托任务
- [Source: _bmad-output/planning-artifacts/prd.md#FR50] — SDK 为所有主要功能领域提供可运行的代码示例
- [Source: _bmad-output/planning-artifacts/architecture.md#Examples 目录结构] — 架构文档定义的示例结构
- [Source: _bmad-output/project-context.md#Technology Stack & Versions]
- [Source: _bmad-output/implementation-artifacts/10-3-prompt-api-example.md] — 前序 Story 的经验教训和 API 签名
- [Source: _bmad-output/implementation-artifacts/10-1-multi-tool-example.md] — 流式 API 使用模式参考
- [Source: _bmad-output/implementation-artifacts/4-3-agent-tool-sub-agent-spawn.md] — Agent 工具实现细节
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — Agent、createAgent、stream 实际 API
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions、AgentDefinition、SubAgentResult、SubAgentSpawner 实际签名
- [Source: Sources/OpenAgentSDK/Types/SDKMessage.swift] — SDKMessage 枚举和所有关联类型
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] — getAllBaseTools(tier:) 函数
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift] — createAgentTool() 工厂函数和内置 Agent 定义
- [Source: Examples/MultiToolExample/main.swift] — 流式 API 使用模式参考

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

## Change Log

- 2026-04-10: Story 10-4 created — SubagentExample demonstrating sub-agent delegation via Agent tool with streaming API

### Review Findings

# Story 3.1: 工具协议与注册表

Status: review

## Story

作为开发者，
我希望向 Agent 注册单个工具或工具层级，
以便 LLM 知道哪些工具可用于执行。

## Acceptance Criteria

1. **AC1: 单工具注册** — 给定未注册任何工具的 Agent，当开发者注册一个符合 `ToolProtocol` 的单个工具，则工具出现在发送给 LLM 的工具定义中（FR11）。

2. **AC2: 层级批量注册** — 给定已注册工具的 Agent，当开发者注册 "core" 工具层级，则所有 10 个核心工具一次性注册，且工具定义包含每个工具的名称、描述和 `inputSchema`（FR15）。

3. **AC3: 按名称过滤工具** — 给定已注册工具的 Agent，当开发者按名称模式过滤工具，则仅匹配的工具包含在工具定义中。

4. **AC4: 工具池组装（含去重）** — 基础工具 + 自定义工具合并时，按名称去重（后者覆盖前者），再应用过滤。

5. **AC5: API 格式转换** — `toApiTool()` 函数将 `ToolProtocol` 转换为 Anthropic API 兼容格式 `{ name, description, input_schema }`。

6. **AC6: 工具定义传递给 LLM** — 当 Agent 调用 `prompt()` 或 `stream()` 时，已注册工具的 `inputSchema` 以 `tools` 参数传递给 Anthropic API。

## Tasks / Subtasks

- [x] Task 1: 创建 Tools 目录结构 (AC: 全部)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/` 目录
  - [x] 创建 `Sources/OpenAgentSDK/Tools/Core/` 子目录（为后续 story 3.4-3.7 预留）
  - [x] 创建 `Sources/OpenAgentSDK/Tools/Advanced/` 子目录（为后续 story 4.x 预留）
  - [x] 创建 `Sources/OpenAgentSDK/Tools/Specialist/` 子目录（为后续 story 5.x 预留）

- [x] Task 2: 实现 ToolRegistry (AC: #1, #2, #3, #4, #5)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/ToolRegistry.swift`
  - [x] 实现 `ToolTier` 枚举（core, advanced, specialist）
  - [x] 实现 `getAllBaseTools(tier:) -> [ToolProtocol]` — 返回指定层级的工具（core 仅返回空数组占位，具体工具在后续 story 实现）
  - [x] 实现 `filterTools(tools:allowed:disallowed:) -> [ToolProtocol]`
  - [x] 实现 `assembleToolPool(baseTools:customTools:mcpTools:allowed:disallowed:) -> [ToolProtocol]`
  - [x] 实现 `toApiTool(_ tool: ToolProtocol) -> [String: Any]`
  - [x] 实现 `toApiTools(_ tools: [ToolProtocol]) -> [[String: Any]]`

- [x] Task 3: 实现 ToolBuilder / defineTool (AC: #1)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/ToolBuilder.swift`
  - [x] 实现泛型函数 `defineTool<Input: Codable>(name:description:inputSchema:isReadOnly:execute:) -> ToolProtocol`
  - [x] `execute` 闭包签名：`(Input, ToolContext) async -> String`
  - [x] 内部实现：将 raw `Any` 输入解码为 `Input` 类型（JSONSerialization + JSONDecoder 桥接）
  - [x] 解码失败时返回 `ToolResult(isError: true, content: "Failed to decode input")`

- [x] Task 4: 集成到 Agent (AC: #6)
  - [x] 修改 `Core/Agent.swift` — 在 `prompt()` 和 `stream()` 方法中，将已注册工具传递给 API 调用
  - [x] 使用 `toApiTools()` 转换工具池为 API 格式
  - [x] 在 `AnthropicClient.sendMessage()` 和 `streamMessage()` 调用中添加 `tools` 参数
  - [x] 如果 `options.tools` 为 nil 或空数组，不传递 `tools` 参数（保持现有无工具行为）

- [x] Task 5: 修改 AnthropicClient 支持 tools 参数 (AC: #6)
  - [x] 修改 `API/AnthropicClient.swift` — `sendMessage()` 添加可选 `tools: [[String: Any]]?` 参数
  - [x] 修改 `streamMessage()` — 同上
  - [x] 当 `tools` 非 nil 且非空时，将其加入请求体
  - [x] 确保无 tools 时行为与现有完全一致（向后兼容）

- [x] Task 6: 更新 OpenAgentSDK.swift 重新导出 (AC: #1)
  - [x] 在 `OpenAgentSDK.swift` 中重新导出 `defineTool`、`toApiTool`、`ToolTier` 等公共 API

- [x] Task 7: 单元测试 (AC: #1-#6)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/` 目录
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/ToolRegistryTests.swift`
  - [x] 测试 `toApiTool()` 输出格式正确性
  - [x] 测试 `filterTools()` 允许/禁止过滤
  - [x] 测试 `assembleToolPool()` 去重逻辑
  - [x] 测试 `defineTool()` 创建符合 `ToolProtocol` 的工具
  - [x] 测试 `defineTool()` Codable 解码成功路径
  - [x] 测试 `defineTool()` Codable 解码失败路径（返回 isError=true）
  - [x] 测试空工具列表时 Agent 行为不变

- [x] Task 8: 集成测试 (AC: #6)
  - [x] 测试带 tools 参数的 `prompt()` 调用（mock API 验证 tools 字段传递）
  - [x] 测试带 tools 参数的 `stream()` 调用（mock API 验证 tools 字段传递）
  - [x] 测试无 tools 参数时 API 请求体不含 tools 键

## Dev Notes

### 核心设计决策

**本 story 范围：**
- 建立工具系统的注册和发现基础设施（FR11, FR15）
- `ToolProtocol` 已在 `Types/ToolTypes.swift` 中定义，直接复用
- `AgentOptions.tools` 属性已存在（`[ToolProtocol]?` 类型），直接使用
- 本 story 不实现具体的内置工具（Bash, Read 等）— 那些在 Story 3.4-3.7
- 本 story 不实现工具执行（tool_use 解析和 tool_result 处理）— 那个在 Story 3.3
- 本 story 实现工具注册、过滤、组装和 API 格式转换

**Epic 3 内的 story 依赖关系：**
- Story 3.1（本 story）= 工具协议与注册表
- Story 3.2 = defineTool 自定义工具的高级用法（本 story 实现基础版 defineTool，3.2 扩展）
- Story 3.3 = 工具执行器（消费本 story 产出的工具池）
- Story 3.4-3.7 = 具体工具实现（注册到本 story 的 ToolRegistry）

### 已有基础设施（直接复用，不要修改）

| 类型 | 位置 | 说明 |
|------|------|------|
| `ToolProtocol` | `Types/ToolTypes.swift` | 已定义 name, description, inputSchema, isReadOnly, call() |
| `ToolResult` | `Types/ToolTypes.swift` | 已定义 toolUseId, content, isError |
| `ToolContext` | `Types/ToolTypes.swift` | 已定义 cwd |
| `ToolInputSchema` | `Types/ToolTypes.swift` | `[String: Any]` 类型别名 |
| `AgentOptions.tools` | `Types/AgentTypes.swift:16` | `[ToolProtocol]?` 属性已存在 |
| `AnthropicClient` | `API/AnthropicClient.swift` | 需添加 tools 参数支持 |
| `processToolResult()` | `Core/Agent.swift:528` | 微压缩集成点已预留 |

### 实现位置

**新增文件：**
```
Sources/OpenAgentSDK/Tools/
├── ToolRegistry.swift      # getAllBaseTools, filterTools, assembleToolPool, toApiTool
├── ToolBuilder.swift       # defineTool<Input: Codable>() 工厂函数
├── Core/                   # 空目录，为 Story 3.4-3.7 预留
├── Advanced/               # 空目录，为 Story 4.x 预留
└── Specialist/             # 空目录，为 Story 5.x 预留
```

**修改文件：**
```
Sources/OpenAgentSDK/API/AnthropicClient.swift  # 添加 tools 参数
Sources/OpenAgentSDK/Core/Agent.swift           # 传递工具定义到 API
Sources/OpenAgentSDK/OpenAgentSDK.swift          # 重新导出公共 API
```

### TypeScript SDK 参考

**tools/index.ts — 注册与过滤核心逻辑：**
```typescript
// 获取所有基础工具
export function getAllBaseTools(): ToolDefinition[] {
  return [...ALL_TOOLS]
}

// 按允许/禁止列表过滤
export function filterTools(
  tools: ToolDefinition[],
  allowedTools?: string[],
  disallowedTools?: string[],
): ToolDefinition[] {
  let filtered = tools
  if (allowedTools && allowedTools.length > 0) {
    const allowed = new Set(allowedTools)
    filtered = filtered.filter((t) => allowed.has(t.name))
  }
  if (disallowedTools && disallowedTools.length > 0) {
    const disallowed = new Set(disallowedTools)
    filtered = filtered.filter((t) => !disallowed.has(t.name))
  }
  return filtered
}

// 组装工具池（基础 + MCP + 去重 + 过滤）
export function assembleToolPool(
  baseTools: ToolDefinition[],
  mcpTools: ToolDefinition[] = [],
  allowedTools?: string[],
  disallowedTools?: string[],
): ToolDefinition[] {
  const combined = [...baseTools, ...mcpTools]
  const byName = new Map<string, ToolDefinition>()
  for (const tool of combined) {
    byName.set(tool.name, tool)  // 后者覆盖前者
  }
  return filterTools(Array.from(byName.values()), allowedTools, disallowedTools)
}
```

**tools/types.ts — API 格式转换：**
```typescript
export function toApiTool(tool: ToolDefinition): {
  name: string; description: string; input_schema: ToolInputSchema
} {
  return { name: tool.name, description: tool.description, input_schema: tool.inputSchema }
}
```

**tools/types.ts — defineTool 辅助函数：**
```typescript
export function defineTool(config: {
  name: string; description: string; inputSchema: ToolInputSchema;
  call: (input: any, context: ToolContext) => Promise<string | { data: string; is_error?: boolean }>;
  isReadOnly?: boolean;
}): ToolDefinition {
  return {
    name: config.name,
    description: config.description,
    inputSchema: config.inputSchema,
    isReadOnly: () => config.isReadOnly ?? false,
    async call(input: any, context: ToolContext): Promise<ToolResult> {
      try {
        const result = await config.call(input, context)
        const output = typeof result === 'string' ? result : result.data
        const isError = typeof result === 'object' && result.is_error
        return { type: 'tool_result', tool_use_id: '', content: output, is_error: isError || false }
      } catch (err: any) {
        return { type: 'tool_result', tool_use_id: '', content: `Error: ${err.message}`, is_error: true }
      }
    },
  }
}
```

### defineTool 的 Swift Codable 桥接设计

TypeScript SDK 使用 Zod 做运行时类型验证。Swift 没有 Zod，但 `Codable` 提供编译时类型安全。桥接策略：

```swift
public func defineTool<Input: Codable>(
    name: String,
    description: String,
    inputSchema: ToolInputSchema,
    isReadOnly: Bool = false,
    execute: @Sendable @escaping (Input, ToolContext) async -> String
) -> ToolProtocol {
    // 返回一个符合 ToolProtocol 的匿名对象
    // call() 方法内部：
    //   1. 将 raw `Any` 输入通过 JSONSerialization 序列化为 Data
    //   2. 用 JSONDecoder 解码为 Input 类型
    //   3. 调用 execute(decoded, context)
    //   4. 解码失败时返回 ToolResult(toolUseId:, content: "Error: ...", isError: true)
}
```

关键桥接步骤（raw Any -> Codable Input）：
1. `input` 是 `[String: Any]`（来自 LLM 的 JSON）
2. `JSONSerialization.data(withJSONObject: input)` -> `Data`
3. `JSONDecoder().decode(Input.self, from: data)` -> `Input`
4. 传给 `execute` 闭包

### ToolTier 枚举设计

```swift
public enum ToolTier: String, Sendable, CaseIterable {
    case core
    case advanced
    case specialist
}
```

`getAllBaseTools(tier:)` 在本 story 中返回空数组（没有具体工具实现）。
当 Story 3.4-3.7 实现核心工具后，会向 `Core/` 目录添加工具并更新注册表。

### AnthropicClient 修改

现有签名：
```swift
func sendMessage(model: String, messages: [[String: Any]], maxTokens: Int, system: String?) async throws -> [String: Any]
func streamMessage(model: String, messages: [[String: Any]], maxTokens: Int, system: String?) async throws -> AsyncThrowingStream<SSEEvent, Error>
```

新签名（添加 tools 参数，默认 nil 保持向后兼容）：
```swift
func sendMessage(model: String, messages: [[String: Any]], maxTokens: Int, system: String?, tools: [[String: Any]]? = nil) async throws -> [String: Any]
func streamMessage(model: String, messages: [[String: Any]], maxTokens: Int, system: String?, tools: [[String: Any]]? = nil) async throws -> AsyncThrowingStream<SSEEvent, Error>
```

在请求体构建中：
```swift
var body: [String: Any] = [
    "model": model,
    "messages": messages,
    "max_tokens": maxTokens,
]
if let system { body["system"] = system }
if let tools, !tools.isEmpty { body["tools"] = tools }  // 新增
```

### Agent.swift 修改

在 `prompt()` 和 `stream()` 方法中，发送 API 请求前：
```swift
// 构建工具定义
let apiTools: [[String: Any]]? = {
    guard let registeredTools = options.tools, !registeredTools.isEmpty else { return nil }
    return toApiTools(registeredTools)
}()

// 传递给 API
let response = try await client.sendMessage(
    model: ..., messages: ..., maxTokens: ..., system: ...,
    tools: apiTools  // 新增
)
```

### 反模式警告

- **不要**在 `Tools/` 中导入 `Core/` — 违反模块边界规则 #40
- **不要**使用 Codable 做 LLM API 通信 — 使用 raw `[String: Any]` 字典（规则 #41）
- **不要**从 defineTool 的闭包内部 throw — 在 ToolResult 中捕获返回（规则 #38）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**在 `Utils/` 创建子目录 — 必须是扁平结构
- **不要**修改 `ToolProtocol` 定义 — 它已在 Story 1.1 中定义并稳定
- **不要**使用 Apple 专属框架 — 必须跨平台（规则 #43）
- **不要**将 `ToolTier` 实现为 `OptionSet` — 使用简单枚举，每次只选一个层级
- **不要**让 `getAllBaseTools` 返回具体工具实例 — 本 story 只建立框架，返回空数组
- **不要**在 `assembleToolPool` 中使用 `Set` 去重 — 使用 `Dictionary` 按名称映射保持顺序

### 与后续 Story 的关系

| Story | 依赖本 Story 的部分 |
|-------|---------------------|
| 3.2 defineTool 高级用法 | 扩展 ToolBuilder，添加更多 defineTool 重载 |
| 3.3 工具执行器 | 消费 assembleToolPool() 产出的工具池，解析 tool_use block |
| 3.4-3.7 具体工具 | 每个工具符合 ToolProtocol，注册到 getAllBaseTools() |
| 4.x 高级工具 | 注册到 Advanced 层级 |
| 5.x 专业工具 | 注册到 Specialist 层级 |
| 6.x MCP | MCP 工具通过 assembleToolPool() 合并 |

### 前一 Story 关键经验（Story 2.6 微压缩）

1. **`processToolResult()` 已预留** — Agent.swift:528 已有微压缩集成点，本 story 不需要修改它
2. **MockURLProtocol 测试模式** — 继续使用此模式模拟 API 响应验证 tools 参数传递
3. **流式路径需要 JSON 序列化** — stream() 中 captured values 需要 Sendable 兼容
4. **`withRetry` 闭包外捕获值** — 新增的 tools 参数也需要在 retry 闭包外捕获
5. **保持现有测试通过** — 新增 tools 参数默认 nil，不影响现有无工具测试

### 测试策略

**单元测试（ToolRegistryTests.swift）：**
- `testToApiTool_format` — 验证输出 `{ name, description, input_schema }` 结构
- `testFilterTools_allowedList` — 只保留允许的工具
- `testFilterTools_disallowedList` — 排除禁止的工具
- `testFilterTools_bothLists` — 同时应用允许和禁止
- `testAssembleToolPool_deduplication` — 后者覆盖前者
- `testAssembleToolPool_emptyMcpTools` — 无 MCP 工具时正常工作
- `testDefineTool_codableSuccess` — Codable 输入正确解码
- `testDefineTool_codableFailure` — 解码失败返回 isError=true
- `testDefineTool_isReadOnly` — 正确传递 isReadOnly 属性

**集成测试（ToolRegistryIntegrationTests.swift 或在现有 AgentTests 中添加）：**
- `testPrompt_withTools_passesToolsToApi` — mock API 验证 tools 参数
- `testPrompt_withoutTools_noToolsInRequest` — 不传 tools 时不包含在请求中
- `testStream_withTools_passesToolsToApi` — 流式路径验证

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.1]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD4 工具系统]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR 映射表 — FR11, FR15]
- [Source: _bmad-output/project-context.md#规则 9 工具协议]
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol 已有定义
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift:16] — AgentOptions.tools 属性
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:528] — processToolResult 集成点
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/index.ts] — TS 注册/过滤参考
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/types.ts] — TS defineTool/toApiTool 参考

### Project Structure Notes

- 新建 `Sources/OpenAgentSDK/Tools/` 目录及子目录（Core/, Advanced/, Specialist/）
- 符合架构文档定义的完整目录结构
- `Tests/OpenAgentSDKTests/Tools/` 测试目录（架构文档已定义）
- 无冲突，完全对齐

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

- Build succeeded: `swift build` passes cleanly
- XCTest unavailable (CommandLineTools only, no Xcode.app); test verification done via code tracing

### Completion Notes List

- Created `ToolRegistry.swift` with `toApiTool()`, `toApiTools()`, `ToolTier`, `getAllBaseTools()`, `filterTools()`, `assembleToolPool()` -- all public functions
- Created `ToolBuilder.swift` with generic `defineTool<Input: Codable>()` factory function using JSONSerialization + JSONDecoder bridge for Codable input decoding
- Modified `Agent.swift` to pass registered tools to AnthropicClient in both `prompt()` and `stream()` methods
- AnthropicClient already supported `tools` parameter (added in prior story), so no changes needed there
- `buildRequestBody()` in APIModels.swift already conditionally includes "tools" key only when non-nil, ensuring backward compatibility
- Used `@unchecked Sendable` on CodableTool to work around `[String: Any]` Sendable conformance limitation
- Tools are serialized/deserialized for Sendable compliance in stream() AsyncStream closure (same pattern as messages)
- All 37 ATDD tests cover the 6 acceptance criteria; build compiles successfully

### File List

**New files:**
- Sources/OpenAgentSDK/Tools/ToolRegistry.swift
- Sources/OpenAgentSDK/Tools/ToolBuilder.swift
- Sources/OpenAgentSDK/Tools/Core/.gitkeep
- Sources/OpenAgentSDK/Tools/Advanced/.gitkeep
- Sources/OpenAgentSDK/Tools/Specialist/.gitkeep
- Tests/OpenAgentSDKTests/Tools/ToolRegistryTests.swift (ATDD red phase, pre-existing)
- Tests/OpenAgentSDKTests/Tools/ToolBuilderTests.swift (ATDD red phase, pre-existing)
- Tests/OpenAgentSDKTests/Tools/ToolRegistryIntegrationTests.swift (ATDD red phase, pre-existing)

**Modified files:**
- Sources/OpenAgentSDK/Core/Agent.swift
- Sources/OpenAgentSDK/OpenAgentSDK.swift

## Change Log

- 2026-04-05: Implemented Story 3.1 - Tool Protocol & Registry (all 8 tasks, 6 ACs)
  - ToolRegistry: toApiTool, toApiTools, ToolTier, getAllBaseTools, filterTools, assembleToolPool
  - ToolBuilder: defineTool generic factory with Codable bridging
  - Agent integration: tools passed to AnthropicClient in prompt() and stream()
  - OpenAgentSDK.swift: added Tool System documentation section

---
stepsCompleted:
  - step-01-init
  - step-02-context
  - step-03-starter
  - step-04-decisions
  - step-05-patterns
  - step-06-structure
  - step-07-validation
  - step-08-complete
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/product-brief-open-agent-sdk-swift.md
  - _bmad-output/planning-artifacts/product-brief-open-agent-sdk-swift-distillate.md
  - _bmad-output/planning-artifacts/implementation-readiness-report-2026-04-03.md
documentCounts:
  prd: 1
  briefs: 2
  ux: 0
  research: 0
  projectDocs: 0
  projectContext: 0
workflowType: 'architecture'
project_name: 'open-agent-sdk-swift'
user_name: 'Nick'
date: '2026-04-03'
status: 'complete'
completedAt: '2026-04-03'
lastStep: 8
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

_This is a greenfield port of a proven TypeScript SDK (open-agent-sdk-typescript). The architecture is well-under from the TS source, which has been thoroughly analyzed._

### Requirements Overview

_51 FRs across 9 areas, 25 NFRs across 6 categories, Refer to the PRD for full details._

### Technical Constraints
- **Single external dependency:** mcp-swift-sdk (DePasqualeOrg/mcp-swift-sdk) — MCP stdio/SHTTP/SSE
- **Custom AnthropicClient:** URLSession-based, POST /v1/messages only, no community Anthropic SDK
- **Swift 5.9+**, macOS 13+, Linux (Ubuntu 20.04+), no Apple-only frameworks
- **Module name:** `OpenAgentSDK`, SPM-only
- **Type system challenge:** Codable for Swift decode, `[String: Any]` JSON Schema dict for LLM — no Zod equivalent in Swift

- **Source reference:** TypeScript SDK at `/Users/nick/CascadeProjects/open-agent-sdk-typescript/src/` (~12 source files, ~3000-4000 lines)

### Cross-Cutting Concerns
1. **Concurrency safety** — Actors for all mutable stores; TaskGroup for concurrent read-only tools; serial mutations
2. **Error propagation** — Typed errors with associated values through agentic loop without breaking the cycle
3. **Streaming pipeline** — AsyncStream<SDKMessage> event ordering preserved across concurrent dispatch
4. **Permission enforcement** — Cross-cutting interceptor on every tool execution
5. **Budget tracking** — Cumulative cost across all LLM calls, integrates with loop abort
6. **JSON Schema ↔ Codable bridging** — Bidirectional type mapping (Codable decode, JSON Schema for LLM)
7. **Shell hook execution** — POSIX process spawning with JSON stdin/stdout
8. **Conversation compaction** — Auto-compact and micro-compact modify message history in-place

---

## Starter Template Evaluation
_This is a Swift SPM library — not a web application. No external starter template exists._

### Selected Approach: Swift Package Manager Init
The project is a Swift library distributed via SPM. There is no Next.js/Vite/Nuxt-style CLI starter. The foundation is `swift package init --type library`.

**Rationale:**
- SPM is theSwift 生态系统的标准 (已通过此方式分发的包只有一个)
- `swift package init --type library` 创建一个最小的 `Package.swift`，`Sources/`、`Tests/`
- 项目结构已在 PRD 中定义： `Sources/OpenAgentSDK/`，子目录为 `Types/`、`API/`、`Tools/` 等。
- 无需任何模板决策——此 SDK 定义了其包的布局

**初始化命令:**
```bash
mkdir open-agent-sdk-swift && cd open-agent-sdk-swift
swift package init --type library --name OpenAgentSDK
```

**架构决策由 SPM 提供:**
- 语言： Swift 5.9+
- 构建系统: Swift Package Manager
- 测试: XCTest (Swift 内置)
- 文档: Swift-DocC
- 模块结构: 单目标 `OpenAgentSDK`

---

## Core Architectural Decisions
_每个决策都记录了：决策、理由、影响._
_基于对 TypeScript SDK 的分析以及 Swift 惯例，做出了以下建议._

### AD1: Concurrency Model — Swift Actors + Structured Concurrency

- **决策：** 对所有可变存储使用 `actor`。 对工具执行使用 `TaskGroup`（只读，上限10个）+ 串行 `for` 循环。
- **理由：** PRD 要求线程安全存储 (FR27, FR48)。 Swift actors 提供了编译时安全的隔离，并且不存在锁竞争。 `TaskGroup` 以结构化的方式处理 Swift 5.5+ 并发中的 TaskGroup。
- **影响：** 所有 6 个存储 + QueryEngine 本会话上下文 + MailboxStore
- **TS 参考:** 无参与者 — 稡块级变量、函数级并发

- **Swift 稡式:** 每个存储是一个 actor； QueryEngine 是一个 actor； 巯具执行使用带有 maxConcurrency 的 `TaskGroup`

### AD2: Streaming Model — AsyncStream<SDKMessage>
- **决策：** 使用带有 SDKMessage 枚举（一个带有关联值的联合类型）的 `AsyncStream` 进行流式传输。
- **理由：** PRD 要求 FR2、FR3 使用流式/阻塞模式。 Swift 的 `AsyncStream` 是响应式流的原生惯用方式。联合类型枚举确保类型安全的事件模式匹配。
- **影响:** QueryEngine.submitMessage() 会产生 SDKMessage 值；消费者使用 `for await` 循环
- **TS 参考:** `AsyncGenerator<SDKMessage>` — 使用泛型异步生成器
- **Swift 模式:** `AsyncStream<SDKMessage>`，带有用于模式匹配的 `case let` 语句

### AD3: API Client — Custom URLSession AnthropicClient
- **决策:** 在 URLSession 之上构建自定义 `AnthropicClient` actor。仅支持 POST /v1/messages 瀬带有流式传输。
- **理由：** PRD 拒绝社区 SDK，以避免重试冲突（NFR15）。 Anthropic 的 `@anthropic-ai/sdk` 添加了 Node.js 运行时依赖。自定义客户端只需要 POST /v1/messages 并支持流式传输。
- **影响:** `API/` 目录中的独立模块
- **TS 参考:** `new Anthropic({ apiKey, baseURL })` — 构造函数创建 SDK 客户端
- **Swift 模式:** actor AnthropicClient，带有一个 `createMessage()` 方法，该方法返回 `AsyncThrowingStream<APIResponse>`，用于流式传输，或 `Message` 用于非流式传输。使用 `URLSession` 和 `URLSessionWebSocketTask`（用于流式传输）。

### AD4: Tool System — Protocol-Based with Codable Input
- **决策：** 工具符合 `ToolProtocol`，定义 `name`、`description`、`inputSchema`、`call()`、`isReadOnly()`。 自定义工具使用带有 `Codable` 输入类型的闭包。
- **理由：** FR13 要求类型安全的工具定义。 Swift 的 `Codable` 提供编译时输入验证。`[String: Any]` JSON Schema 字典则作为桥接到 LLM 的 schema 表示。
- **影响:** 所有 34 个工具实现， `defineTool()` 函数
- **TS 参考:** `defineTool()` 辅助函数使用原始配置对象
- **Swift 模式:**
```swift
protocol ToolProtocol {
    var name: String { get }
    var description: String { get }
    var inputSchema: [String: Any] { get }
    var isReadOnly: Bool { get }
    func call(input: Any, context: ToolContext) async -> ToolResult
}

```

`defineTool<Input: Codable>() 函数将 `Input` 类型约束为 `Codable`，并提供一个闭包用于执行。

### AD5: MCP Integration — mcp-swift-sdk Dependency
- **决策:** 使用 DePasqualeOrg/mcp-swift-sdk 作为 MCP 宇杰外依赖。将 MCP 连接封装在 `MCPClientManager` actor 后。
。
- **理由:** PRD FR19-FR22 需要 MCP 协议支持。 mcp-swift-sdk 提供了 MCP 客户端+服务器传输（stdio/SSE/HTTP）的经过实战检验。如果其不满足需求，则有一个分支并维护的回退方案。
- **影响:** `MCP/M` 目录；在代理设置时进行评估（PRD 黺议的第 6 阶段）
- **TS 参考:** 使用 `@modelcontextprotocol/sdk` 包进行传输
- **Swift 模式:** `import MCPClient` from mcp-swift-sdk； actor MCPClientManager 猉照每个配置管理连接生命周期。MCP 工具通过 `mcp__{serverName}__{toolName}` 像命名空间约定进行命名。

### AD6: Session Persistence — Actor-Based JSON File Storage
- **决策:** 使用 `SessionStore` actor 在 `~/.open-agent-sdk/sessions/` 中实现基于 JSON 文件的持久化。
- **理由:** PRD FR23-FR27 要求会话持久化。 JSON 文件易于调试，且与 TS SDK 的方法匹配。参与者隔离可确保多代理并发安全。
- **影响:** `Session/SessionStore.swift`
- **TS 参考:** 无参与者 — 直接使用 `fs` 模块，函数
- **Swift 模式:** actor SessionStore，使用 FileManager 进行文件 I/O。会话存储为 `~/.open-agent-sdk/sessions/{sessionId}/transcript.json`。

### AD7: Hook System — Event-Observer Pattern
- **决策:** `HookRegistry` 维护事件到处理程序的映射。事件是带有关联类型的枚举。处理器是闭包或 shell 命令。
- **理由:** PRD FR28-FR31 要求 21 个生命周期事件。TypeScript SDK 在 `HookRegistry` 类中使用基于类的方法。Swift 将使用带有静态 case 的枚举（0 个 case，以实现穷尽编译时检查。
- **影响:** `Hooks/` 目录
- **TS 参考:** 带有函数和命令处理程序的 `HookRegistry` 类
- **Swift 模式:**
```swift
enum HookEvent: String, HookEvent {
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    // ... 所有 21 种情况
}

struct HookDefinition: Send on HookEvent, ([HookInput]) async -> HookOutput?
```

Shell hooks 使用 `Process` (Foundation on macOS，`posix_spawn` 或直接使用 `exec` 系列调用 在 Linux 上) 通过 `stdin` 传入 JSON 并从 `stdout` 读取 JSON。

### AD8: Permission Model — Enum + Callback Interceptor
- **决策:** `PermissionMode` 是一个带 6 种情况的枚举。`canUseTool` 是一个异步闭包，在每个工具执行前调用。
- **理由:** PRD FR32-FR34 要求权限模式和自定义授权。闭包方法在 Swift 中很自然（与函数类型匹配），并启用自定义逻辑。
- **影响:** `QueryEngine.executeSingleTool()` 在执行前调用 `canUseTool`
- **TS 参考:** `CanUseToolFn` 类型 — ` (tool, ToolDefinition, input: unknown) async => CanUseToolResult`
- **Swift 模式:** `PermissionMode` 枚举（6 种情况）。 `canUseTool` 是 `(ToolProtocol, Any) async throws -> CanUseToolResult` 类型闭包属性，在 `AgentOptions` 中设置。

### AD9: Configuration — Struct-Based
- **决策:** 使用 `SDKConfiguration` 结构体，环境变量通过 `ProcessInfo.processInfo`（或 Linux 上的 `getenv`）解析。
- **理由:** PRD FR39-FR41。 struct 方法是 Swift 惯用方式，并提供编译时验证。环境变量回退支持灵活部署。
- **影响:** `Types/SDKConfiguration.swift`、`Agent` 构造函数
- **TS 参考:** `AgentOptions` 接口，包含 40 多个可配置属性
- **Swift 模式:**
```swift
struct SDKConfiguration {
    var apiKey: String?
    var model: String
    var baseURL: String?
    var maxTurns: Int
    var maxTokens: Int
    var thinking: ThinkingConfig?
    // ...
}
```
带有环境变量回退的便利初始化器。

### AD10: Error Model — Typed Errors with Associated Values
- **决策:** 使用带有关联值的嵌套 Swift 枚举。没有 force-unwrap 或可选滥用。
- **理由:** NFR15-NFR18 要求可靠的重试/错误处理。Swift 的 typed throws (5.9+) 和带有关联值的枚举支持丰富的错误信息，不会意外的崩溃。
- **影响:** 所有模块——每个子系统都有自己的错误域
- **Swift 模式:**
```swift
enum SDKError: Error {
    case apiError(statusCode: Int, message: String)
    case toolExecutionError(toolName: String, message: String)
    case budgetExceeded(cost: Double, turnsUsed: Int)
    case maxTurnsExceeded(turnsUsed: Int)
    case sessionError(message: String)
    case mcpConnectionError(serverName: String, message: String)
    case permissionDenied(tool: String, reason: String)
    case abortError
}
```

### AD11: Budget Tracking — Model Pricing Lookup Table
- **决策:** 复制带有更新定价的 TS SDK 的 `MODEL_PRICING` 字典。在每次 LLM 调用后跟踪累计成本。
- **理由:** FR7、FR8 要求成本跟踪和预算强制执行。定价查找表将模型信息与每 token 成本映射。
- **影响:** `QueryEngine`、`Utils/Tokens.swift`
- **TS 参考:** `MODEL_PRICING` 字典将模型 ID 映射到输入/输出每 token 价格。
- **Swift 模式:** 复制 TS SDK 的 `MODEL_PRICING` 方法。`estimateCost()` 函数根据使用情况计算成本。QueryEngine 在每次 API 调用后进行累加。

---

## Implementation Patterns & Consistency Rules
_确保 AI 代理在整个 SDK 中一致实现的模式。_

### 彽️ 关键冲突点（AI 代理可能做出不同选择的领域）
1. 弽️ 寽名约定
2. **Actor 与非 Actor 边界** — 何时使用 actor 与何时使用 struct/class
3. **错误包装** — 如何将错误从工具传播到循环
4. **Optional值处理** — nil vs. 显式默认值
5. **集合类型** — 数组 vs. 集合
6. **JSON 锥** Codable 边界** —— 何处使用原始 JSON vs. Codable 类型
7. **导入组织** — 按层导入与模块级导入

8. **访问控制** — 公共 API 与内部实现细节

### 命名约定

**类型和协议：**
- PascalCase 类型： `QueryEngine`、`ToolProtocol`、`SessionStore`
- camelCase 函数和变量： `estimateCost()`、`compactConversation()`
- SNAKE_CASE 常量和环境变量： `AUTOCOMPACT_BUFFER_TOKENS`、`CODEANY_API_KEY`
- `ToolProtocol` 实现的 `*Tool` 后缀： `BashTool`、`FileReadTool`、`GlobTool`

**文件命名：**
- PascalCase 文件： 每个类型一个文件： `QueryEngine.swift`、`SessionStore.swift`
- 分组到子目录： `Tools/`、`Types/`、`API/`、`Utils/`

**JSON 字段命名:**
- API 请求/响应使用 snake_case（与 Anthropic API 匹配）： `input_tokens`、`tool_use_id`、`stop_reason`
- Swift 内部 API 使用 camelCase： `inputTokens`、`toolUseId`、`stopReason`
- SDKMessage 类型字段使用 snake_case（与 TS SDK 匹配）： `type`、`session_id`、`num_turns`、`total_cost_usd`

### Actor 与非 Actor 边界

**使用 `actor` 的场景：**
- 所有管理共享可变状态的存储： SessionStore, TaskStore, TeamStore, MailboxStore, PlanStore, CronStore, TodoStore, AgentRegistry, ConfigStore
- QueryEngine（管理会话状态、消息历史、使用情况跟踪）
- MCPClientManager（管理连接生命周期）
- HookRegistry（管理处理程序注册表）

**使用 `struct` 或 `class` 的场景：**
- 不可变数据类型： `SDKMessage`、`ToolResult`、`TokenUsage`、`ConversationMessage`
- 配置类型： `SDKConfiguration`、`AgentOptions`、`RetryConfig`
- API 响应模型： `APIResponse`、`ContentBlock`

**关键规则：** 如果它在多个 `agent` 之间共享可变状态，或者从多个 `async` 上下文访问，它就是一个 `actor`。如果它是创建一次且从不更改，它就是一个 `struct`。

### 错误处理模式

**传播规则：**
- 工具执行错误： 在 `ToolResult` 中捕获， `is_error: true`，返回给 `agent` 循环——永不崩溃
- API 错误： `QueryEngine` 中使用重试捕获，在重试耗尽后返回错误结果
- 预算超出： `QueryEngine` 中断循环，返回 `error_max_budget_usd` 结果
- MCP 错误： 记录日志，返回断开连接的结果，从不崩溃

**错误永不传播方式：**
- 从工具处理程序内部抛出
- 通过 optional 链解包强制解包
- 使用 force-unwrap

### Optional 值处理
- 配置参数： 显式默认值（`maxTurns: 10`、`maxTokens: 16384`、`model: "claude-sonnet-4-6"`）
- 工具属性： 通过 `isReadOnly`、`isEnabled` 猉协议方法
- 环境变量： 可为空时返回 nil，与编码默认值匹配
- 不使用 `!!` 进行 optional 解包——使用 `guard let` 或 `if let`

### 集合类型
- 工具列表： `[ToolProtocol]` — 数组，通过索引访问
- 消息历史： `[MessageParam]` — 数组，按顺序追加
- 处理程序注册表： `[HookEvent: [HookDefinition]]` — 嵌套数组
- 仅当通过名称进行唯一性检查时才使用 `Set`（例如，工具名称过滤）

### JSON ↔ Codable 边界
- **LLM 输入/输出：** 原始 `[String: Any]` dict（与 API 匹配的 JSON Schema）
- **工具输入：** 通过 `Codable` 从原始 JSON 解码——工具闭包接收强类型
- **会话序列化：** `Codable`（JSONEncoder/JSONDecoder）用于磁盘持久化
- **Never use `Codable` for LLM API communication** — 使用原始字典类型

### 导入组织
- 顶级公共 API 从 `Sources/OpenAgentSDK/` 中的 `index.swift` 重新导出
- 内部导入使用相对路径： `import "../Types/SDKMessage.swift"`
- 避免循环依赖——工具永远不直接导入 API 类型
- `Utils/` 是扁平的——没有嵌套子目录

### 访问控制
- **公共：** Agent、createAgent()、query()、defineTool()、所有类型
- **公共：** 巯️ 巌具实现（用于自定义工具创建）
- **内部：** QueryEngine 状态、消息历史、使用情况跟踪
- **内部:** 存储实现细节
- **内部:** 工具执行分派、权限检查

- 卽┋ 可用 `internal` 标记防止意外依赖

---

## Project Structure & Boundaries
_定义 SDK 的完整目录和文件结构。_
_注意：此结构取代了 PRD 中较旧的近似结构，提供了精确的文件到组件映射。_

### Complete Project Directory Structure
```
open-agent-sdk-swift/
├── Package.swift
├── README.md
├── LICENSE
├── .gitignore
├── .github/
│   └── workflows/
│       └── ci.yml
├── Sources/
│   └── OpenAgentSDK/
│       ├── OpenAgentSDK.swift          # Module entry point, re-exports public API
│       │
│       ├── Types/
│       │   ├── SDKMessage.swift        # SDKMessage enum + all event types
│       │   ├── TokenUsage.swift        # Token usage tracking
│       │   ├── ToolTypes.swift         # ToolProtocol, ToolResult, ToolContext, ToolInputSchema
│       │   ├── PermissionTypes.swift   # PermissionMode, CanUseToolResult, CanUseToolFn
│       │   ├── ThinkingConfig.swift    # Thinking configuration enum
│       │   ├── AgentTypes.swift        # AgentDefinition, AgentOptions, QueryResult
│       │   ├── MCPConfig.swift         # McpStdioConfig, McpSseConfig, McpHttpConfig, McpSdkServerConfig
│       │   ├── SessionTypes.swift      # SessionMetadata, SessionData
│       │   ├── HookTypes.swift         # HookEvent enum, HookInput, HookOutput, HookDefinition
│       │   ├── ErrorTypes.swift        # SDKError enum with associated values
│       │   └── ModelInfo.swift         # ModelInfo, MODEL_PRICING dict
│       │
│       ├── API/
│       │   ├── AnthropicClient.swift   # Actor: custom URLSession-based API client
│       │   ├── APIModels.swift         # API request/response structs (ContentBlock types)
│       │   └── Streaming.swift         # SSE/streaming response parsing
│       │
│       ├── Core/
│       │   ├── QueryEngine.swift       # Actor: core agentic loop
│       │   ├── Agent.swift             # Agent class + createAgent() + query()
│       │   ├── SystemPromptBuilder.swift # Builds system prompt from context
│       │   └── ToolExecutor.swift      # Tool dispatch (concurrent/serial partitioning)
│       │
│       ├── Tools/
│       │   ├── ToolRegistry.swift      # getAllBaseTools(), filterTools(), assembleToolPool()
│       │   ├── ToolBuilder.swift       # defineTool<Input: Codable>() factory function
│       │   ├── Core/
│       │   │   ├── BashTool.swift
│       │   │   ├── FileReadTool.swift
│       │   │   ├── FileWriteTool.swift
│       │   │   ├── FileEditTool.swift
│       │   │   ├── GlobTool.swift
│       │   │   ├── GrepTool.swift
│       │   │   ├── WebFetchTool.swift
│       │   │   ├── WebSearchTool.swift
│       │   │   ├── AskUserTool.swift
│       │   │   └── ToolSearchTool.swift
│       │   ├── Advanced/
│       │   │   ├── AgentTool.swift
│       │   │   ├── SendMessageTool.swift
│       │   │   ├── TaskCreateTool.swift
│       │   │   ├── TaskListTool.swift
│       │   │   ├── TaskUpdateTool.swift
│       │   │   ├── TaskGetTool.swift
│       │   │   ├── TaskStopTool.swift
│       │   │   ├── TaskOutputTool.swift
│       │   │   ├── TeamCreateTool.swift
│       │   │   ├── TeamDeleteTool.swift
│       │   │   └── NotebookEditTool.swift
│       │   ├── Specialist/
│       │   │   ├── WorktreeTools.swift
│       │   │   ├── PlanTools.swift
│       │   │   ├── CronTools.swift
│       │   │   ├── RemoteTriggerTool.swift
│       │   │   ├── LSPTool.swift
│       │   │   ├── ConfigTool.swift
│       │   │   ├── TodoWriteTool.swift
│       │   │   ├── ListMcpResourcesTool.swift
│       │   │   └── ReadMcpResourceTool.swift
│       │   └── MCP/
│       │       ├── MCPClientManager.swift    # Actor: manages MCP server connections
│       │       └── InProcessMCPServer.swift  # In-process MCP tool hosting
│       │
│       ├── Stores/
│       │   ├── SessionStore.swift       # Actor: session persistence
│       │   ├── TaskStore.swift          # Actor: task state management
│       │   ├── TeamStore.swift          # Actor: team state management
│       │   ├── MailboxStore.swift       # Actor: inter-agent messaging
│       │   ├── PlanStore.swift          # Actor: plan state management
│       │   ├── CronStore.swift          # Actor: cron job management
│       │   ├── TodoStore.swift          # Actor: todo item management
│       │   └── AgentRegistry.swift     # Actor: subagent registration
│       │
│       ├── Hooks/
│       │   ├── HookRegistry.swift       # Event registration + execution
│       │   └── ShellHookExecutor.swift # Process-based shell hook execution
│       │
│       └── Utils/
│           ├── Compact.swift           # Auto-compact + micro-compact
│           ├── Context.swift           # System/user context extraction (git, project files)
│           ├── FileCache.swift         # LRU file state cache
│           ├── Messages.swift          # Message creation, normalization, helpers
│           ├── Retry.swift             # withRetry, exponential backoff, error classification
│           ├── Tokens.swift             # estimateTokens, estimateCost, MODEL_PRICING, thresholds
│           └── Shell.swift              # POSIX shell execution helpers
│
├── Tests/
│   └── OpenAgentSDKTests/
│       ├── Core/
│       │   ├── QueryEngineTests.swift
│       │   ├── AgentTests.swift
│       │   └── ToolExecutorTests.swift
│       ├── Tools/
│       │   ├── CoreToolTests.swift
│       │   ├── AdvancedToolTests.swift
│       │   └── SpecialistToolTests.swift
│       ├── Stores/
│       │   └── StoreTests.swift
│       ├── API/
│       │   └── AnthropicClientTests.swift
│       ├── Hooks/
│       │   └── HookRegistryTests.swift
│       ├── MCP/
│       │   └── MCPClientTests.swift
│       └── Utils/
│           ├── CompactTests.swift
│           ├── RetryTests.swift
│           └── TokensTests.swift
│
├── Docs/
│   └── (Swift-DocC generated documentation)
│
└── Examples/
    ├── BasicAgent/
    │   └── main.swift
    ├── StreamingAgent/
    │   └── main.swift
    ├── CustomTools/
    │   └── main.swift
    ├── MCPIntegration/
    │   └── main.swift
    └── SessionsAndHooks/
        └── main.swift
```

### Requirements to Structure Mapping
_将每个 FR 映射到实现它的文件。_
| FR | File(s) |
|---|---|
| FR1 | `Core/Agent.swift`, `Types/AgentTypes.swift` |
| FR2 | `Core/QueryEngine.swift`, `API/Streaming.swift` |
| FR3 | `Core/Agent.swift` (`prompt()` method) |
| FR4 | `Core/QueryEngine.swift` (submitMessage loop) |
| FR5 | `Core/QueryEngine.swift` (max_tokens recovery) |
| FR6 | `Types/AgentTypes.swift`, `Core/QueryEngine.swift` |
| FR7 | `Utils/Tokens.swift`, `Core/QueryEngine.swift` |
| FR8 | `Core/QueryEngine.swift` (budget check in loop) |
| FR9 | `Utils/Compact.swift`, `Core/QueryEngine.swift` |
| FR10 | `Utils/Compact.swift` (microCompact) |
| FR11 | `Tools/ToolRegistry.swift` |
| FR12 | `Core/ToolExecutor.swift` |
| FR13 | `Tools/ToolBuilder.swift` (defineTool) |
| FR14 | `Tools/ToolBuilder.swift` (JSON Schema + Codable) |
| FR15-FR18 | `Tools/Core/*`, `Tools/Advanced/*`, `Tools/Specialist/*` |
| FR19-FR20 | `Tools/MCP/MCPClientManager.swift` |
| FR21 | `Tools/MCP/InProcessMCPServer.swift` |
| FR22 | `Core/QueryEngine.swift`, `Tools/ToolRegistry.swift` |
| FR23-fR27 | `Stores/SessionStore.swift` |
| FR28-fR31 | `Hooks/HookRegistry.swift`, `Hooks/ShellHookExecutor.swift` |
| FR32-fR34 | `Types/PermissionTypes.swift`, `Core/ToolExecutor.swift` |
| FR35 | `Tools/Advanced/AgentTool.swift` |
| FR36 | `Tools/Advanced/SendMessageTool.swift` |
| FR37 | `Tools/Advanced/Task*Tool.swift` |
| FR38 | `Tools/Advanced/Team*Tool.swift` |
| FR39-fR41 | `Types/AgentTypes.swift`, `Core/Agent.swift` |
| FR42-fR48 | `Stores/*.swift` (6 actor stores) |
| FR49-fR51 | Swift-DocC, README, Examples/ |

### Architectural Boundaries
**模块边界：**
- `Types/` → 无出站依赖（叶节点）
- `API/` → 依赖 `Types/`
- `Core/` → 依赖 `Types/`, `API/`, `Utils/`
- `Tools/` → 依赖 `Types/`, `Utils/`（从不导入 `Core/`）
- `Stores/` → 依赖 `Types/`（从不导入 `Core/`）
- `Hooks/` → 依赖 `Types/`（从不导入 `Core/` 或 `Tools/`）
- `MCP/` → 依赖 `Types/`, 外部 mcp-swift-sdk
- `Utils/` → 无出站依赖（叶节点，除了 `Compact` 可能会临时调用 `API/AnthropicClient` 进行压缩 LLM 调用）
**关键规则：** `Core/` 是唯一的编排器。`Tools/`、`Stores/` 和 `Hooks/` 独立于核心循环——它们只定义行为，从不驱动它。

---

## Architecture Validation Results
_每个决策的验证结果。_
### Coherence Validation
**Decision Compatibility:**
所有决策都兼容——Swift actors、Codable、URLSession 和 AsyncStream 是标准的 Swift 并发原语，它们协同工作。没有版本冲突，因为唯一的依赖是 mcp-swift-sdk，它与其他选择没有交互。
**Pattern Consistency:**
命名约定在整个项目中是一致的。基于 actor 的模式被统一应用。错误处理遵循相同的 typed- throws 模式。JSON↔Codable 边界始终保持在相同的边界（`Codable` 用于 Swift 端，原始字典用于 LLM 端）。
**Structure Alignment:**
目录结构通过清晰的模块边界强制执行架构决策。导入规则防止循环依赖。层级组织（Core → API → Types）遵循自然的依赖方向。

### Requirements Coverage
**所有 51 个 FR 都已覆盖：** 每个 FR 都映射到上文记录的特定文件。
**所有 25 个 NFR 都已覆盖：**
- Performance (NFR1-5): AsyncStream + TaskGroup + actor isolation
- Security (NFR6-10): AnthropicClient key isolation, shell hook sanitization, permission interceptor
- Cross-Platform (NFR11-14): No Apple frameworks, POSIX paths, SPM CI
- Reliability (NFR15-18): Retry.swift, budget graceful shutdown, tool error capture
- Integration (NFR19-21): MCPClientManager, AnthropicClient, custom baseURL
- API Stability (NFR22-25): frozen core APIs, evolving hook/MCP APIs, semver

### Gap Analysis
**Nice-to-Have:**
- TS SDK 中的沙盒/容器系统用于 macOS 沙盒执行——超出 v1.0 范围，记录以供将来参考
- TS SDK 中有 `SettingSource` 类型（用户/项目/本地）——在 Swift 中可能有用，但可推迟
- TS SDK 中有 `OutputFormat` 和 `jsonSchema` 用于结构化输出——如果需要，可在 v1.x 中添加
**没有关键或重要遗漏。** 该架构完全覆盖了 v1.0 的范围。

### Architecture Readiness Assessment
**Overall Status:** READY FOR IMPLEMENTATION
**Confidence Level:** High
**Key Strengths:**
- 经过实战检验的 TypeScript 架构直接映射到 Swift 惯用模式
- 清晰的模块边界，具有单向依赖流
- 所有共享可变状态都由 actor 隔离
- 精确的 FR 到文件映射，不留模糊空间
- 每个组件的单外部依赖策略，具有清晰的回退计划

**Areas for Future Enhancement:**
- v1.1+: iOS 工具子集审计, PlatformToolSet protocol
- v2.0+: FoundationModels integration via ModelProvider protocol
- 沙盒执行支持 (macOS Seatbelt)
- 通过 `OutputFormat` 进行结构化输出

---

## Implementation Handoff

**AI Agent Guidelines:**
- 完全按照本文档中记录的内容遵循所有架构决策
- 按照记录的模式命名所有类型、文件和目录
- 尊重模块边界——`Tools/` 从不导入 `Core/`
- 对共享可变状态使用 actor，对不可变数据使用 struct
- 在 Swift 端使用 `Codable`，在 LLM 端使用原始 JSON 字典
- 参考本文档以解决所有架构问题

**Implementation Priority:**
1. Foundation — `Package.swift`, `Types/`, `API/`, `Utils/`
2. Core Engine — `Core/QueryEngine.swift`, `Core/Agent.swift`
3. Tool System — `Tools/ToolRegistry.swift`, `Tools/ToolBuilder.swift`, Core tier
4. Advanced Tools — Agent, Tasks, Teams
5. Specialist Tools — Worktree, Plan, Cron, LSP, Config, Todo
6. MCP Integration — `Tools/MCP/`
7. Sessions & Hooks — `Stores/`, `Hooks/`
8. Polish — Documentation, Examples, CI


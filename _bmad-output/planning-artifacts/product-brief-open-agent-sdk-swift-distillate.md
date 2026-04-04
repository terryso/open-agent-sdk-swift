---
title: "Product Brief Distillate: OpenAgentSDKSwift"
type: llm-distillate
source: "product-brief-open-agent-sdk-swift.md"
created: "2026-04-03"
purpose: "Token-efficient context for downstream PRD creation"
---

# 产品简报摘要：OpenAgentSDKSwift

## 技术背景

- **源项目**：位于 /Users/nick/CascadeProjects/open-agent-sdk-typescript 的 open-agent-sdk-typescript，npm 包 @codeany/open-agent-sdk v0.1.0，MIT 许可证（版权所有 2025 CodeAny）。尚处于 1.0 之前的阶段，API 可能仍在演进——Swift 移植版应跟踪上游变更。
- **需要谨慎移植的核心 TS 源文件**：engine.ts（521 行，15KB）、agent.ts（426 行，13KB）、types.ts（460 行，12KB）、index.ts（377 行，9KB）。TS 代码总行数估计约 3000-4000 行。
- **平台**：macOS 13+ / Linux，通过 SPM 构建。模块名称 `OpenAgentSDK`。不依赖 Apple 专属框架。
- **唯一的外部依赖**：DePasqualeOrg/mcp-swift-sdk，用于 MCP 协议（stdio/HTTP，客户端+服务器）。必须在第 6 阶段评估其成熟度；备选方案是 fork+维护或原生实现。
- **基于 URLSession 的自定义 AnthropicClient** —— 仅需 POST /v1/messages。避免了社区 SDK 的重试冲突和版本锁定问题。
- **Swift 并发模型**：使用 actor 保护 QueryEngine、SessionStore、TaskStore、TeamStore、AgentRegistry、MailboxStore、PlanStore、CronStore、TodoStore。使用 AsyncStream<SDKMessage> 进行流式传输。使用 TaskGroup 实现只读工具的并发执行（最多 10 个），变更操作采用串行执行。
- **Schema 验证**：Codable + [String: Any] JSON Schema（Swift 中没有 Zod 的等价物）。工具输入通过 Codable 解码；原始 JSON Schema 字典传递给 LLM。
- **环境变量**：CODEANY_API_KEY（必需）、CODEANY_MODEL、CODEANY_BASE_URL。Swift 应支持等效的环境变量或 Info.plist 键。

## 智能体循环设计（QueryEngine 核心）

```
while turnsRemaining > 0 {
  1. Check abort/budget
  2. shouldAutoCompact → compactConversation
  3. microCompactMessages (truncate tool_results >50000 chars)
  4. AnthropicClient.messages.create (withRetry)
  5. Parse TextBlock + ToolUseBlock
  6. yield .assistant event
  7. No ToolUseBlock → break
  8. Partition: readOnly (TaskGroup concurrent, max 10) + mutation (serial)
  9. yield .toolResult event
  10. Append results to messages
}
yield .result (usage + cost)
```

- **最大 token 恢复**：如果 stop_reason 为 'max_tokens'，追加 "Please continue from where you left off." 并最多重试 3 次。
- **预算追踪**：通过 estimateCost(model, usage) 计算总成本。预算超出时触发 'error_max_budget_usd' 结果子类型。成本使用 MODEL_PRICING 查找表。
- **自动压缩缓冲区**：AUTOCOMPACT_BUFFER_TOKENS 常量；阈值 = contextWindow - buffer；LLM 摘要对话内容，替换为 [summary, acknowledgment]。

## 工具分层（已采纳的决策）

- **核心层**（必需，默认加载）：Bash、Read、Write、Edit、Glob、Grep、WebFetch、WebSearch、AskUser、ToolSearch
- **高级层**（多智能体编排）：Agent、SendMessage、TaskCreate/List/Update/Get/Stop/Output、TeamCreate/Delete、NotebookEdit
- **专业层**（CLI/开发者工作流，按需启用）：Worktree Enter/Exit、Plan Enter/Exit、CronCreate/Delete/List、RemoteTrigger、LSP、Config、TodoWrite、ListMcpResources、ReadMcpResource
- 工具通过工具注册机制加载——使用者可按需选择所需层级。

## 钩子系统详情

21 个生命周期事件：PreToolUse、PostToolUse、PostToolUseFailure、SessionStart、SessionEnd、Stop、SubagentStart、SubagentStop、UserPromptSubmit、PermissionRequest、PermissionDenied、TaskCreated、TaskCompleted、ConfigChange、CwdChanged、FileChanged、Notification、PreCompact、PostCompact、TeammateIdle。

- 函数钩子 + Shell 命令钩子，支持正则匹配器
- Shell 钩子：通过 stdin 接收 JSON 格式输入，通过 stdout 返回 JSON 格式的 HookOutput。非 JSON 的 stdout 输出将被视为消息。
- 默认超时时间：30000 毫秒。

## 会话持久化详情

- 路径：~/.open-agent-sdk/sessions/{sessionId}/transcript.json
- 元数据：id、cwd、model、createdAt、updatedAt、messageCount、summary
- 操作：保存、加载、列出、分叉、删除、重命名、标签、追加
- Swift：使用 actor SessionStore 实现线程安全访问

## MCP 服务器类型

- McpStdioConfig（command + args + env）
- McpSseConfig（url + headers）
- McpHttpConfig（url + headers）
- McpSdkServerConfig（进程内工具）

## 权限模式

六种模式：'default'、'acceptEdits'、'bypassPermissions'、'plan'、'dontAsk'、'auto'。canUseTool 回调允许自定义权限逻辑以覆盖模式设置。

## 包结构（约 50+ 个文件）

```
Sources/OpenAgentSDK/
  Types/ (SDKMessage, TokenUsage, ToolTypes, PermissionTypes, ThinkingConfig, AgentTypes, MCPConfig)
  API/ (AnthropicClient, APIModels, ContentBlocks)
  Tools/ (ToolRegistry, ToolBuilder, 34 tool implementations, 6 stores)
  Session/ (SessionStore)
  Hooks/ (HookRegistry, HookTypes)
  MCP/ (MCPClientManager, InProcessMCPServer)
  Utils/ (Compact, Context, FileCache, Messages, Retry, Tokens, Shell)
```

## 竞争格局

- **Apple FoundationModels**：仅在 Apple Silicon 上提供设备端推理 + 工具调用。无云端 LLM、无跨平台支持、无 MCP、无会话持久化。属于互补关系，而非竞争对手。
- **SwiftAgent（Swift 论坛）**：受 FoundationModels 启发，采用 @Generable 工具系统。仅限 Apple 平台，无 MCP，无会话持久化。
- **SwiftAIAgent（GitHub）**：早期阶段，以演示为导向，缺少生产级功能。
- **ClaudeCodeSDK**：CLI 封装器，非原生 SDK。依赖 Claude Code 二进制文件。
- **AnthropicSwiftSDK / AnthropicKit / SwiftAnthropic**：仅作为 API 客户端——无智能体循环、无工具、无会话、无 MCP。
- **mcp-swift-sdk 变体**：仅限 MCP 的库，非智能体框架。

## 已否决的想法

- **使用社区 Anthropic Swift SDK**：已否决，因为仅需 POST /v1/messages；社区 SDK 存在重试冲突和版本锁定问题，会增加智能体循环自身重试策略的复杂性。
- **Zod 等价验证库**：Swift 中不存在可行的等价方案；Codable + 原始 JSON Schema 能以更低的复杂度实现相同效果。
- **在 v1.0 中支持 iOS**：推迟至 v1.1，因为许多工具（Bash、文件操作、MCP stdio、worktree）需要 iOS 沙盒中不可用的文件系统/进程访问权限。需要进行工具子集审计和 PlatformToolSet 协议设计。
- **在 v1.0 中集成 FoundationModels**：已推迟——LLM 提供者抽象已设计为通过基于协议的 ModelProvider 支持后续集成，但 v1.0 专注于 Anthropic Claude 云端 API。

## 待解决问题

- **上游跟踪策略**：Swift SDK 应多紧密地跟踪 TypeScript SDK 的 API 变更？TS SDK 目前为 v0.1.0 且仍在演进。需要一套评估上游变更的流程。
- **mcp-swift-sdk 评估**：必须在第 6 阶段之前评估其成熟度、功能覆盖范围和维护节奏，然后才能确定其作为唯一 MCP 实现的承诺。
- **macOS App Store 兼容性**：Shell 执行和广泛的文件系统访问可能面临 App Store 审核的严格审查。需要记录哪些权限模式和工具子集对 App Store 是安全的。
- **默认配置值**：maxTurns=10、maxTokens=16384、thinking={type:'adaptive'}、model='claude-sonnet-4-6'。Swift 中是否应采用相同的默认值？

## 范围信号

- **v1.0 范围内**：与 TS SDK 的完整功能对等（全部 34 个工具、MCP、钩子、会话、子智能体、权限），跨平台 CI（macOS+Linux），Swift-DocC 文档，可运行的示例。
- **v1.1 范围内**：支持 iOS/iPadOS，提供有限的工具集，PlatformToolSet 协议。
- **v2.0+ 范围内**：FoundationModels 集成（混合本地/云端），SwiftUI 配套包（聊天视图），Vapor/Hummingbird 中间件。
- **不在计划中**：Windows、IDE 扩展、托管服务、可视化 UI/仪表盘、微调模型托管。

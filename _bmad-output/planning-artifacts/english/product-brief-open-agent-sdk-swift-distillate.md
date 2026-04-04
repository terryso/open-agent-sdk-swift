---
title: "Product Brief Distillate: OpenAgentSDKSwift"
type: llm-distillate
source: "product-brief-open-agent-sdk-swift.md"
created: "2026-04-03"
purpose: "Token-efficient context for downstream PRD creation"
---

# Product Brief Distillate: OpenAgentSDKSwift

## Technical Context

- **Source project**: open-agent-sdk-typescript at /Users/nick/CascadeProjects/open-agent-sdk-typescript, npm package @codeany/open-agent-sdk v0.1.0, MIT license (Copyright 2025 CodeAny). Pre-1.0, API may still evolve — Swift port should track upstream changes.
- **Core TS source files to port carefully**: engine.ts (521 lines, 15KB), agent.ts (426 lines, 13KB), types.ts (460 lines, 12KB), index.ts (377 lines, 9KB). Total estimated ~3000-4000 lines of TS.
- **Platforms**: macOS 13+ / Linux via SPM. Module name `OpenAgentSDK`. No Apple-only frameworks.
- **Single external dependency**: DePasqualeOrg/mcp-swift-sdk for MCP protocol (stdio/HTTP, client+server). Must evaluate maturity during Phase 6; fallback is fork+maintain or native implementation.
- **Custom AnthropicClient** on URLSession — only needs POST /v1/messages. Avoids community SDK retry conflicts and version pinning issues.
- **Swift concurrency model**: actors for QueryEngine, SessionStore, TaskStore, TeamStore, AgentRegistry, MailboxStore, PlanStore, CronStore, TodoStore. AsyncStream<SDKMessage> for streaming. TaskGroup for read-only tool concurrency (max 10), serial execution for mutations.
- **Schema validation**: Codable + [String: Any] JSON Schema (no Zod equivalent in Swift). Tool input decoded via Codable; raw JSON Schema dict passed to LLM.
- **Environment variables**: CODEANY_API_KEY (required), CODEANY_MODEL, CODEANY_BASE_URL. Swift should support equivalent env vars or Info.plist keys.

## Agentic Loop Design (QueryEngine Core)

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

- **Max tokens recovery**: If stop_reason is 'max_tokens', append "Please continue from where you left off." and retry up to 3 times.
- **Budget tracking**: totalCost via estimateCost(model, usage). Budget exceeded triggers 'error_max_budget_usd' result subtype. Cost uses MODEL_PRICING lookup table.
- **Auto-compact buffer**: AUTOCOMPACT_BUFFER_TOKENS constant; threshold = contextWindow - buffer; LLM summarizes conversation, replaces with [summary, acknowledgment].

## Tool Tiering (Accepted Decision)

- **Core** (must-have, loaded by default): Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUser, ToolSearch
- **Advanced** (multi-agent orchestration): Agent, SendMessage, TaskCreate/List/Update/Get/Stop/Output, TeamCreate/Delete, NotebookEdit
- **Specialist** (CLI/developer workflow, opt-in): Worktree Enter/Exit, Plan Enter/Exit, CronCreate/Delete/List, RemoteTrigger, LSP, Config, TodoWrite, ListMcpResources, ReadMcpResource
- Tool loading via tool registration — consumers opt into tiers they need.

## Hook System Detail

21 lifecycle events: PreToolUse, PostToolUse, PostToolUseFailure, SessionStart, SessionEnd, Stop, SubagentStart, SubagentStop, UserPromptSubmit, PermissionRequest, PermissionDenied, TaskCreated, TaskCompleted, ConfigChange, CwdChanged, FileChanged, Notification, PreCompact, PostCompact, TeammateIdle.

- Function hooks + shell command hooks with regex matchers
- Shell hooks: input as JSON on stdin, return HookOutput as JSON on stdout. Non-JSON stdout treated as message.
- Default timeout: 30000ms.

## Session Persistence Detail

- Path: ~/.open-agent-sdk/sessions/{sessionId}/transcript.json
- Metadata: id, cwd, model, createdAt, updatedAt, messageCount, summary
- Operations: save, load, list, fork, delete, rename, tag, append
- Swift: actor SessionStore for thread-safe access

## MCP Server Types

- McpStdioConfig (command + args + env)
- McpSseConfig (url + headers)
- McpHttpConfig (url + headers)
- McpSdkServerConfig (in-process tools)

## Permission Modes

Six modes: 'default', 'acceptEdits', 'bypassPermissions', 'plan', 'dontAsk', 'auto'. The canUseTool callback allows custom permission logic overriding the mode.

## Package Structure (~50+ files)

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

## Competitive Landscape

- **Apple FoundationModels**: On-device inference + tool calling on Apple Silicon only. No cloud LLM, no cross-platform, no MCP, no session persistence. Complement, not competitor.
- **SwiftAgent (Swift Forums)**: Inspired by FoundationModels, @Generable tool system. Tied to Apple-only, no MCP, no session persistence.
- **SwiftAIAgent (GitHub)**: Early stage demo-driven, lacks production features.
- **ClaudeCodeSDK**: CLI wrapper, not native SDK. Depends on Claude Code binary.
- **AnthropicSwiftSDK / AnthropicKit / SwiftAnthropic**: API clients only — no agent loop, no tools, no sessions, no MCP.
- **mcp-swift-sdk variants**: MCP-only libraries, not agent frameworks.

## Rejected Ideas

- **Using community Anthropic Swift SDK**: Rejected because only POST /v1/messages is needed; community SDKs have retry conflicts and version pinning issues that complicate the agent loop's own retry strategy.
- **Zod-equivalent validation library**: No viable Swift equivalent exists; Codable + raw JSON Schema achieves the same result with less complexity.
- **iOS support in v1.0**: Deferred to v1.1 because many tools (Bash, file ops, MCP stdio, worktree) require filesystem/process access unavailable in iOS sandbox. Requires tool subset auditing and PlatformToolSet protocol design.
- **FoundationModels integration in v1.0**: Deferred — LLM provider abstraction is designed to support it later via protocol-based ModelProvider, but v1.0 focuses on Anthropic Claude cloud API.

## Open Questions

- **Upstream tracking strategy**: How closely should the Swift SDK track TypeScript SDK API changes? The TS SDK is v0.1.0 and evolving. Need a process for evaluating upstream changes.
- **mcp-swift-sdk evaluation**: Must assess maturity, feature coverage, and maintenance cadence during Phase 6 before committing to it as the sole MCP implementation.
- **macOS App Store compatibility**: Shell execution and broad filesystem access may face App Store review scrutiny. Need to document which permission modes and tool subsets are App Store-safe.
- **Default configuration values**: maxTurns=10, maxTokens=16384, thinking={type:'adaptive'}, model='claude-sonnet-4-6'. Should these be the same defaults in Swift?

## Scope Signals

- **In v1.0**: Full functional parity with TS SDK (all 34 tools, MCP, hooks, sessions, subagents, permissions), cross-platform CI (macOS+Linux), Swift-DocC docs, working examples.
- **In v1.1**: iOS/iPadOS support with limited tool set, PlatformToolSet protocol.
- **In v2.0+**: FoundationModels integration (hybrid local/cloud), SwiftUI companion package (chat views), Vapor/Hummingbird middleware.
- **Not planned**: Windows, IDE extensions, hosted service, visual UI/dashboard, fine-tuned model hosting.

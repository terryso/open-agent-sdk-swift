---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-open-agent-sdk-swift.md
  - _bmad-output/planning-artifacts/product-brief-open-agent-sdk-swift-distillate.md
documentCounts:
  briefs: 2
  research: 0
  projectDocs: 0
  projectContext: 0
classification:
  projectType: developer_tool
  domain: ai_agent_infrastructure
  complexity: medium
  projectContext: greenfield
workflowType: 'prd'
---

# Product Requirements Document - OpenAgentSDKSwift

**Author:** Nick
**Date:** 2026-04-03

## Executive Summary

OpenAgentSDKSwift is a native Swift Package Manager library that brings full AI agent capabilities to the Swift ecosystem — an agentic loop, 34 built-in tools, MCP protocol support, session persistence, and a hook system — all without embedding Node.js as a runtime dependency.

The project originated from a concrete need: building a native macOS app that requires direct SDK access from Swift code. No bridging through Node.js, no API-only clients that leave 80% of the agent stack unimplemented, no CLI wrappers that depend on external binaries. This is the gap every Swift developer hits when they want AI agent capabilities.

The SDK ports a proven TypeScript agent architecture to Swift using idiomatic concurrency primitives: actors for state isolation, AsyncStream for streaming, and Codable for serialization. It targets macOS 13+ and Linux via SPM with a single external dependency (mcp-swift-sdk for MCP protocol). Functional parity is 1:1 with the TypeScript SDK; API design follows Swift conventions.

**Target users:** macOS application developers building AI-powered tools and productivity apps (primary), server-side Swift engineers on Linux (secondary), and AI/ML engineers working in Swift who need to move beyond raw API calls to full agent orchestration (tertiary).

### What Makes This Special

- **Only Swift SDK with full agent capabilities.** No other Swift package offers built-in tools + MCP + session persistence + hooks in a single library. Alternatives are API clients (message completion only) or CLI wrappers (external binary dependency).
- **Proven architecture, managed risk.** The agentic loop, tool system, and session model are battle-tested in TypeScript production. Implementation risk is identified and bounded: dynamic JSON schema handling, tool dispatch, and shell hook execution mapping to Swift's strict type system.
- **Born from real need.** This isn't speculative — it's blocking real native Mac apps right now. Every Swift developer wanting AI agents faces the same wall.
- **Minimal dependency footprint.** One external dependency. Custom Anthropic API client on URLSession avoids community SDK version conflicts and retry strategy collisions.
- **Part of a multi-language SDK family.** TypeScript, Go, Swift — consistent agent philosophy across languages.

## Project Classification

| Dimension | Value |
|---|---|
| **Project Type** | Developer Tool (SDK / Library / Package) |
| **Domain** | AI Agent Infrastructure |
| **Complexity** | Medium |
| **Project Context** | Greenfield (port from TypeScript) |

## Success Criteria

### User Success

- A Swift developer adds `OpenAgentSDK` as an SPM dependency and has a working agent streaming responses within **15 minutes** using the README quickstart.
- The API feels natural to Swift developers — `async/await`, `for await` streaming on `AsyncStream<SDKMessage>`, Codable-based tool definitions. No mental translation from TypeScript required.
- All 34 tools work identically on macOS and Linux — a developer's agent code runs the same on their Mac as on their Linux server.
- Custom tool creation with `defineTool()` takes less than 5 minutes from reading docs to a working tool.

### Business Success

- **200+ GitHub stars** within 6 months of launch, indicating genuine developer interest.
- External developer contributions — issues filed and PRs submitted by developers outside the core team.
- At least **one third-party project** adopting OpenAgentSDKSwift within 6 months.
- Recognized as the go-to Swift agent SDK in community discussions (Swift Forums, Reddit, X).

### Technical Success

- All 34 built-in tools pass unit tests on both macOS 13+ and Linux via GitHub Actions CI.
- Integration test covering the full agentic loop (LLM call → tool execution → result feed → repeat).
- Dual-platform CI green on every PR — no platform-specific regressions.
- Swift-DocC generated API documentation with full coverage.
- Working code examples for every major feature that compile and run.
- Core agent loop and tool system APIs frozen at v1.0; hook and MCP APIs marked as evolving.
- Semver versioning; Swift SDK tracks its own version independent of TypeScript SDK.

### Measurable Outcomes

| Metric | Target | Timeframe |
|---|---|---|
| Quickstart to working agent | < 15 minutes | At launch |
| Test coverage (per phase) | All tools unit-tested | Per phase |
| Dual-platform CI | Green on every PR | At launch |
| GitHub stars | 200+ | 6 months post-launch |
| External adoption | 1+ third-party project | 6 months post-launch |
| API stability | Core APIs frozen at v1.0 | At launch |

## User Journeys

### Journey 1: Sarah — macOS App Developer (Primary User)

**Opening Scene:** Sarah is building a native macOS productivity app — a code review assistant that reads pull requests, analyzes diffs, and posts review comments. She's been prototyping with raw Anthropic API calls via URLSession, but she's spending all her time reimplementing tool execution, conversation management, and error handling. She has 2,000 lines of boilerplate that should be a library.

**Rising Action:** Sarah discovers OpenAgentSDKSwift. She adds it as an SPM dependency. The README quickstart shows her how to create an agent with streaming in 10 lines of Swift. She pastes it into a Playground and watches her first agent response stream back. Then she registers the Read, Glob, and Grep tools to give her agent file-system access — three lines each. She defines a custom `PostCommentTool` using `defineTool()` with a Codable input struct and a JSON Schema definition.

**Climax:** Sarah replaces her 2,000 lines of hand-rolled agent infrastructure with 150 lines of OpenAgentSDKSwift calls. Her agent now has a full tool suite, session persistence so users can resume review conversations, and the auto-compact feature handles long PRs without running out of context. She ships the update to TestFlight the same week.

**Resolution:** Sarah's app feels responsive — streaming responses appear token-by-token in her SwiftUI views via `for await` on AsyncStream. She's no longer fighting infrastructure; she's building features. Her next idea — an agent that manages GitHub issues — takes her a single afternoon because the SDK handles everything.

### Journey 2: Marcus — Server-Side Swift Engineer (Secondary User)

**Opening Scene:** Marcus runs an automated code analysis service on a Linux server using Vapor. He needs an agent that can examine repositories, run static analysis, and generate reports. He's been evaluating Python agent frameworks but doesn't want to add a Python runtime to his Swift stack. Deploying two language runtimes in production adds monitoring overhead, deployment complexity, and team skill fragmentation.

**Rising Action:** Marcus adds OpenAgentSDKSwift to his Vapor project's Package.swift. It resolves on Linux without issues — no Apple-only frameworks. He creates an agent endpoint that receives analysis requests, spawns an agent with Bash and Read tools, and streams progress back to the caller via Server-Sent Events. Session persistence means long-running analyses survive server restarts.

**Climax:** Marcus's service runs the same OpenAgentSDKSwift code on his Mac for development and on Ubuntu for production. When an analysis takes many turns, the auto-compact feature keeps the conversation within context limits automatically. Budget tracking prevents runaway agent loops from burning through API credits.

**Resolution:** Marcus deploys a single Swift binary to production — no Node.js, no Python, no inter-process communication. His team reviews and maintains one codebase. The agent's tool execution is thread-safe via actors, so multiple concurrent analysis requests don't step on each other.

### Journey 3: Wei — AI/ML Engineer Building Custom Tools (Tertiary User)

**Opening Scene:** Wei works on a research team that processes large datasets. He wants to build an AI agent that can read CSV files, run statistical analyses, and generate visualization scripts. He's been writing raw API calls in Swift because Python's agent frameworks feel too heavy for his lightweight data pipeline. He needs a Swift-native way to define domain-specific tools and run an agent loop.

**Rising Action:** Wei uses `defineTool()` to create three custom tools: `AnalyzeCSV`, `RunPythonScript`, and `GenerateChart`. Each tool has a Codable input struct and returns structured output. He configures the agent with a per-request budget of $0.50 and a maximum of 20 turns. He hooks into the `PostToolUse` lifecycle event to log tool execution metrics for his research paper.

**Climax:** Wei's agent autonomously processes datasets — reading files, deciding which analyses to run, interpreting results, and generating charts. The hook system gives him fine-grained observability into every tool call. When the agent hits the budget limit, it gracefully returns a partial result with a cost summary instead of silently failing.

**Resolution:** Wei publishes his data analysis agent as an internal tool. Other researchers extend it by adding their own custom tools via the same `defineTool()` pattern. No one needs to understand the agentic loop internals — they just define tools and the SDK handles the rest.

### Journey Requirements Summary

| Journey | Reveals Requirements For |
|---|---|
| Sarah (macOS app) | Streaming, tool registration, custom tools, session persistence, auto-compact, SwiftUI integration |
| Marcus (server-side) | Linux support, concurrent agents, budget tracking, session survival, SSE streaming |
| Wei (AI/ML custom) | Custom tool definition, hook observability, budget limits, structured tool I/O |

## Innovation & Novel Patterns

### Detected Innovation Areas

1. **First full agent framework in Swift.** No prior Swift package combines an agentic loop, 34 built-in tools, MCP protocol, session persistence, and a hook system. This is a new paradigm for Swift — previously, Swift developers could only consume AI via raw API clients or by bridging to Node.js/Python runtimes.

2. **defineTool() DSL pattern.** The custom tool API uses Swift's type system (Codable + JSON Schema) to create a declarative tool definition experience. Developers write a Codable struct for input, provide a JSON Schema dict for the LLM, and implement a closure for execution. This bridges Swift's strict typing with the LLM's dynamic schema expectations without sacrificing type safety.

3. **Cross-platform agent parity.** The same agent code runs on macOS (GUI apps, CLI tools) and Linux (server-side) with identical behavior. The 34-tool tiering system lets consumers load only what their platform supports — Core tools for minimal agents, Advanced for multi-agent orchestration, Specialist for CLI/developer workflows.

### Competitive Landscape

| Competitor | What It Lacks |
|---|---|
| Apple FoundationModels | No cloud LLM, no cross-platform, no MCP, no session persistence, Apple Silicon only |
| SwiftAgent (Swift Forums) | Tied to Apple-only, no MCP, no session persistence |
| ClaudeCodeSDK | CLI wrapper, depends on external binary |
| AnthropicSwiftSDK / AnthropicKit / SwiftAnthropic | API clients only — no agent loop, tools, sessions, or MCP |
| mcp-swift-sdk variants | MCP-only, not agent frameworks |

### Validation Approach

- **Unit tests per tool** validate functional parity with TypeScript SDK on both macOS and Linux.
- **Integration test** exercises the full agentic loop with real tool execution.
- **Example apps** serve as end-to-end validation: if the quickstart example compiles and runs, the core SDK works.

### Risk Mitigation

| Risk | Mitigation |
|---|---|
| Dynamic JSON schema ↔ Codable bridging | Use `[String: Any]` JSON Schema dict for LLM, Codable for Swift decode; proven pattern from TS Zod→JSON Schema |
| mcp-swift-sdk maturity | Evaluate in Phase 6; fallback is fork+maintain or native MCP implementation |
| Upstream TS SDK API changes | Swift SDK tracks own version; evaluate upstream changes per release |
| macOS App Store compatibility | Document which permission modes and tool subsets are App Store-safe |

## Developer Tool Specific Requirements

### Platform & Distribution

- **Package manager:** Swift Package Manager (SPM) exclusively. No CocoaPods or Carthage support in v1.0.
- **Module name:** `OpenAgentSDK`. Import via `import OpenAgentSDK`.
- **Platforms:** macOS 13+ (Ventura), Linux (Ubuntu 20.04+). No Apple-only frameworks required.
- **Swift version:** Swift 5.9+ (for concurrency and typed throws support).

### API Surface Design

- **Swift-idiomatic:** `async/await` for all asynchronous operations, `AsyncStream<SDKMessage>` for streaming, `actors` for all mutable state stores, `Codable` for all serializable types.
- **Two consumption modes:** Streaming via `agent.stream(prompt)` returning `AsyncStream<SDKMessage>`, blocking via `agent.prompt(prompt)` returning final result.
- **Tool registration:** Type-safe tool definition with `defineTool()`, Codable input decoding, JSON Schema dict for LLM consumption.
- **Error model:** Typed errors using Swift enums with associated values. No force-unwrap or optional abuse.

### Documentation Strategy

- **Swift-DocC** for API reference documentation with full symbol coverage.
- **README** with quickstart guide targeting <15 minutes to first working agent.
- **Working examples** for every major feature area: basic agent, streaming, custom tools, MCP, sessions, hooks, subagents.
- **Migration guide** from raw Anthropic API calls to OpenAgentSDKSwift (common adoption path).

### Code Examples Coverage

| Example | Demonstrates |
|---|---|
| Basic Agent | Agent creation, single prompt, response handling |
| Streaming Agent | AsyncStream consumption, event pattern matching |
| Custom Tools | defineTool(), Codable input, JSON Schema |
| MCP Integration | Connect to external MCP server, expose in-process tools |
| Session Persistence | Save, load, fork, resume conversations |
| Hook System | Register function and shell hooks, lifecycle events |
| Multi-Agent | Agent tool, SendMessage, subagent orchestration |
| Budget & Permissions | Permission modes, budget tracking, canUseTool callback |

## Project Scoping & Phased Development

### MVP Strategy

**Approach:** Platform MVP — establish the complete developer tool foundation with full functional parity against the TypeScript SDK. The SDK is the platform; community adoption is the validation signal.

### Phase 1: MVP (v1.0)

**Core user journeys supported:** Sarah (macOS app), Marcus (server-side), Wei (custom tools).

**Must-have capabilities:**
- Agentic loop with streaming and blocking modes
- All 34 built-in tools across three tiers
- Custom Anthropic API client
- MCP client and in-process MCP server
- Session persistence
- Hook system (21 lifecycle events)
- Custom tool definition
- Subagent support
- Permission modes and budget tracking
- Auto-compact and micro-compact
- All management stores (Task, Team, Worktree, Plan, Cron, Todo)
- Swift-DocC documentation
- GitHub Actions CI (macOS + Linux)
- Working examples

**Implementation phases within MVP:**
1. Foundation — Types, API client, configuration, environment variables
2. Agentic loop — QueryEngine with streaming, retry, auto-compact, budget tracking
3. Tool system — ToolRegistry, ToolBuilder, Core tier tools (10 tools)
4. Advanced tools — Agent, SendMessage, Task tools, Team tools, NotebookEdit
5. Specialist tools — Worktree, Plan, Cron, LSP, Config, Todo, MCP Resource tools
6. MCP integration — MCPClientManager, InProcessMCPServer
7. Sessions & hooks — SessionStore, HookRegistry, all 21 lifecycle events
8. Polish — Documentation, examples, CI hardening, performance pass

### Phase 2: Post-MVP (v1.x)

- Performance profiling and optimization
- Additional example apps (Vapor integration, SwiftUI chat view)
- Community-requested API improvements
- Enhanced error messages and debugging aids
- Upstream TypeScript SDK change evaluation and adoption

### Phase 3: Expansion (v2.0+)

- iOS/iPadOS support with limited tool set, PlatformToolSet protocol
- FoundationModels integration (hybrid local/cloud routing)
- SwiftUI companion package (chat views, message renderers)
- Vapor/Hummingbird middleware for agent endpoints

### Risk Mitigation Strategy

| Risk Category | Risk | Mitigation |
|---|---|---|
| **Technical** | Dynamic JSON ↔ Codable bridging | Validate in Phase 3 with tool system; proven pattern |
| **Technical** | mcp-swift-sdk immaturity | Evaluate in Phase 6; fork/maintain fallback ready |
| **Technical** | Shell hook execution on Linux | Test early in Phase 7; POSIX compatibility verification |
| **Market** | Low community adoption | Ship excellent docs and examples; engage Swift community |
| **Market** | TypeScript SDK divergence | Track own version; evaluate upstream per release |
| **Resource** | Single developer bandwidth | Phased delivery; each phase is independently useful |

## Functional Requirements

### Agentic Loop & LLM Communication

- FR1: Developers can create an agent with a system prompt, model selection, and configuration parameters
- FR2: Developers can send prompts to the agent and receive streaming responses via AsyncStream
- FR3: Developers can send prompts and receive blocking responses with the final result
- FR4: The agent executes the full agentic loop: call LLM, parse tool-use requests, execute tools, feed results back, repeat until completion
- FR5: The agent recovers from max_tokens responses by prompting continuation (up to 3 retries)
- FR6: Developers can set a maximum turn count per agent invocation
- FR7: The agent tracks cumulative token usage and estimated cost per invocation
- FR8: Developers can set a maximum budget (USD) per invocation; the agent stops gracefully when exceeded
- FR9: The agent auto-compacts conversations when approaching context window limits
- FR10: The agent micro-compacts individual tool results exceeding 50,000 characters

### Tool System & Execution

- FR11: Developers can register individual tools or tool tiers with an agent
- FR12: The agent executes read-only tools concurrently (up to 10 in parallel) and mutation tools serially
- FR13: Developers can create custom tools using `defineTool()` with Codable input types and closure-based execution
- FR14: Custom tools provide a JSON Schema definition for LLM consumption alongside Codable Swift decoding
- FR15: The tool system supports 34 built-in tools across Core, Advanced, and Specialist tiers
- FR16: Core tier tools include: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUser, ToolSearch
- FR17: Advanced tier tools include: Agent, SendMessage, TaskCreate/List/Update/Get/Stop/Output, TeamCreate/Delete, NotebookEdit
- FR18: Specialist tier tools include: WorktreeEnter/Exit, PlanEnter/Exit, CronCreate/Delete/List, RemoteTrigger, LSP, Config, TodoWrite, ListMcpResources, ReadMcpResource

### MCP Protocol Support

- FR19: Developers can connect to external MCP servers via stdio transport
- FR20: Developers can connect to external MCP servers via HTTP/SSE transport
- FR21: Developers can expose in-process MCP tools for consumption by external MCP clients
- FR22: MCP tools are available to the agent alongside built-in tools during execution

### Session Management

- FR23: Developers can save agent conversations to persistent storage (JSON)
- FR24: Developers can load and resume previously saved conversations
- FR25: Developers can fork a conversation from any saved point
- FR26: Developers can list, rename, tag, and delete saved sessions
- FR27: Session storage is thread-safe via actor-based access

### Hook System

- FR28: Developers can register function hooks on 21 lifecycle events (PreToolUse, PostToolUse, PostToolUseFailure, SessionStart, SessionEnd, Stop, SubagentStart, SubagentStop, UserPromptSubmit, PermissionRequest, PermissionDenied, TaskCreated, TaskCompleted, ConfigChange, CwdChanged, FileChanged, Notification, PreCompact, PostCompact, TeammateIdle)
- FR29: Developers can register shell command hooks with regex matchers on lifecycle events
- FR30: Shell hooks receive input as JSON on stdin and return output as JSON on stdout
- FR31: Hooks have a configurable timeout (default: 30 seconds)

### Permission & Security Model

- FR32: Developers can set one of six permission modes: default, acceptEdits, bypassPermissions, plan, dontAsk, auto
- FR33: Developers can provide a custom `canUseTool` callback for consumer-defined authorization logic
- FR34: The permission system controls which tools an agent can execute based on the configured mode

### Multi-Agent Orchestration

- FR35: Agents can spawn subagents via the Agent tool for delegated tasks
- FR36: Agents can communicate with teammates via SendMessage
- FR37: Agents can manage tasks using TaskCreate/List/Update/Get/Stop/Output tools
- FR38: Agents can create and manage teams using TeamCreate/Delete tools

### Configuration & Environment

- FR39: Developers can configure the SDK via environment variables (CODEANY_API_KEY, CODEANY_MODEL, CODEANY_BASE_URL)
- FR40: Developers can configure the SDK programmatically via a configuration struct
- FR41: The SDK supports multiple LLM providers via custom base URLs

### Management Stores

- FR42: Agents can manage tasks via a TaskStore (create, list, update, get, stop)
- FR43: Agents can manage teams via a TeamStore (create, delete)
- FR44: Agents can manage worktrees via WorktreeStore
- FR45: Agents can manage plans via PlanStore
- FR46: Agents can manage cron jobs via CronStore
- FR47: Agents can manage todos via TodoStore
- FR48: All stores use actor-based thread-safe access

### Documentation & Developer Experience

- FR49: The SDK provides Swift-DocC generated API documentation
- FR50: The SDK provides working code examples for all major feature areas
- FR51: The SDK provides a README with a quickstart guide

## Non-Functional Requirements

### Performance

- NFR1: Streaming responses begin within 2 seconds of LLM API response receipt (first token)
- NFR2: Tool execution for file-system operations (Read, Write, Edit, Glob, Grep) completes within 500ms for files under 1MB
- NFR3: The agent dispatches up to 10 concurrent read-only tool executions without blocking
- NFR4: Session save and load operations complete within 200ms for conversations under 500 messages
- NFR5: Auto-compact summarization completes within the latency of a single LLM call

### Security

- NFR6: API keys are never logged, printed, or included in error messages
- NFR7: Shell hook execution sanitizes input to prevent command injection
- NFR8: The permission system enforces tool access restrictions before execution
- NFR9: Custom `canUseTool` callbacks receive full tool context for authorization decisions
- NFR10: Session files are stored with user-only read/write permissions (0600)

### Cross-Platform Compatibility

- NFR11: All 34 tools produce identical behavior on macOS 13+ and Linux (Ubuntu 20.04+)
- NFR12: No Apple-only frameworks are required for core SDK functionality
- NFR13: CI pipeline validates dual-platform compatibility on every PR
- NFR14: File path handling is platform-aware (POSIX-compliant)

### Reliability

- NFR15: The agent retries LLM API calls with exponential backoff (up to 3 retries)
- NFR16: Budget exceeded conditions produce a graceful error result, not a crash
- NFR17: Tool execution failures are captured and reported to the agent without terminating the agentic loop
- NFR18: Auto-compact preserves conversation continuity after summarization

### Integration

- NFR19: MCP client connections handle server process lifecycle (start, crash recovery, graceful shutdown)
- NFR20: The Anthropic API client communicates exclusively via POST /v1/messages with streaming support
- NFR21: Custom LLM providers are supported via configurable base URL without SDK modification

### API Stability

- NFR22: Core agent loop and tool system APIs are frozen at v1.0 with no breaking changes
- NFR23: Hook and MCP APIs are marked as evolving and may change between minor versions
- NFR24: The SDK follows semantic versioning (major.minor.patch)
- NFR25: The Swift SDK version is independent of the TypeScript SDK version

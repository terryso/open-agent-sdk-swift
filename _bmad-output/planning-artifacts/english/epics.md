---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
---

# OpenAgentSDKSwift - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for OpenAgentSDKSwift, decomposing the requirements from the PRD and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: Developers can create an agent with a system prompt, model selection, and configuration parameters
FR2: Developers can send prompts to the agent and receive streaming responses via AsyncStream
FR3: Developers can send prompts and receive blocking responses with the final result
FR4: The agent executes the full agentic loop: call LLM, parse tool-use requests, execute tools, feed results back, repeat until completion
FR5: The agent recovers from max_tokens responses by prompting continuation (up to 3 retries)
FR6: Developers can set a maximum turn count per agent invocation
FR7: The agent tracks cumulative token usage and estimated cost per invocation
FR8: Developers can set a maximum budget (USD) per invocation; the agent stops gracefully when exceeded
FR9: The agent auto-compacts conversations when approaching context window limits
FR10: The agent micro-compacts individual tool results exceeding 50,000 characters
FR11: Developers can register individual tools or tool tiers with an agent
FR12: The agent executes read-only tools concurrently (up to 10 in parallel) and mutation tools serially
FR13: Developers can create custom tools using defineTool() with Codable input types and closure-based execution
FR14: Custom tools provide a JSON Schema definition for LLM consumption alongside Codable Swift decoding
FR15: The tool system supports 34 built-in tools across Core, Advanced, and Specialist tiers
FR16: Core tier tools include: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUser, ToolSearch
FR17: Advanced tier tools include: Agent, SendMessage, TaskCreate/List/Update/Get/Stop/Output, TeamCreate/Delete, NotebookEdit
FR18: Specialist tier tools include: WorktreeEnter/Exit, PlanEnter/Exit, CronCreate/Delete/List, RemoteTrigger, LSP, Config, TodoWrite, ListMcpResources, ReadMcpResource
FR19: Developers can connect to external MCP servers via stdio transport
FR20: Developers can connect to external MCP servers via HTTP/SSE transport
FR21: Developers can expose in-process MCP tools for consumption by external MCP clients
FR22: MCP tools are available to the agent alongside built-in tools during execution
FR23: Developers can save agent conversations to persistent storage (JSON)
FR24: Developers can load and resume previously saved conversations
FR25: Developers can fork a conversation from any saved point
FR26: Developers can list, rename, tag, and delete saved sessions
FR27: Session storage is thread-safe via actor-based access
FR28: Developers can register function hooks on 21 lifecycle events
FR29: Developers can register shell command hooks with regex matchers on lifecycle events
FR30: Shell hooks receive input as JSON on stdin and return output as JSON on stdout
FR31: Hooks have a configurable timeout (default: 30 seconds)
FR32: Developers can set one of six permission modes: default, acceptEdits, bypassPermissions, plan, dontAsk, auto
FR33: Developers can provide a custom canUseTool callback for consumer-defined authorization logic
FR34: The permission system controls which tools an agent can execute based on the configured mode
FR35: Agents can spawn subagents via the Agent tool for delegated tasks
FR36: Agents can communicate with teammates via SendMessage
FR37: Agents can manage tasks using TaskCreate/List/Update/Get/Stop/Output tools
FR38: Agents can create and manage teams using TeamCreate/Delete tools
FR39: Developers can configure the SDK via environment variables (CODEANY_API_KEY, CODEANY_MODEL, CODEANY_BASE_URL)
FR40: Developers can configure the SDK programmatically via a configuration struct
FR41: The SDK supports multiple LLM providers via custom base URLs
FR42: Agents can manage tasks via a TaskStore (create, list, update, get, stop)
FR43: Agents can manage teams via a TeamStore (create, delete)
FR44: Agents can manage worktrees via WorktreeStore
FR45: Agents can manage plans via PlanStore
FR46: Agents can manage cron jobs via CronStore
FR47: Agents can manage todos via TodoStore
FR48: All stores use actor-based thread-safe access
FR49: The SDK provides Swift-DocC generated API documentation
FR50: The SDK provides working code examples for all major feature areas
FR51: The SDK provides a README with a quickstart guide

### NonFunctional Requirements

NFR1: Streaming responses begin within 2 seconds of LLM API response receipt (first token)
NFR2: Tool execution for file-system operations (Read, Write, Edit, Glob, Grep) completes within 500ms for files under 1MB
NFR3: The agent dispatches up to 10 concurrent read-only tool executions without blocking
NFR4: Session save and load operations complete within 200ms for conversations under 500 messages
NFR5: Auto-compact summarization completes within the latency of a single LLM call
NFR6: API keys are never logged, printed, or included in error messages
NFR7: Shell hook execution sanitizes input to prevent command injection
NFR8: The permission system enforces tool access restrictions before execution
NFR9: Custom canUseTool callbacks receive full tool context for authorization decisions
NFR10: Session files are stored with user-only read/write permissions (0600)
NFR11: All 34 tools produce identical behavior on macOS 13+ and Linux (Ubuntu 20.04+)
NFR12: No Apple-only frameworks are required for core SDK functionality
NFR13: CI pipeline validates dual-platform compatibility on every PR
NFR14: File path handling is platform-aware (POSIX-compliant)
NFR15: The agent retries LLM API calls with exponential backoff (up to 3 retries)
NFR16: Budget exceeded conditions produce a graceful error result, not a crash
NFR17: Tool execution failures are captured and reported to the agent without terminating the agentic loop
NFR18: Auto-compact preserves conversation continuity after summarization
NFR19: MCP client connections handle server process lifecycle (start, crash recovery, graceful shutdown)
NFR20: The Anthropic API client communicates exclusively via POST /v1/messages with streaming support
NFR21: Custom LLM providers are supported via configurable base URL without SDK modification
NFR22: Core agent loop and tool system APIs are frozen at v1.0 with no breaking changes
NFR23: Hook and MCP APIs are marked as evolving and may change between minor versions
NFR24: The SDK follows semantic versioning (major.minor.patch)
NFR25: The Swift SDK version is independent of the TypeScript SDK version

### Additional Requirements

- Starter template: Swift SPM init (`swift package init --type library --name OpenAgentSDK`) — no external starter template
- Single external dependency: mcp-swift-sdk (DePasqualeOrg/mcp-swift-sdk) for MCP stdio/SHTTP/SSE
- Custom AnthropicClient: URLSession-based, POST /v1/messages only, no community Anthropic SDK
- Swift 5.9+, macOS 13+, Linux (Ubuntu 20.04+), no Apple-only frameworks
- Module name: OpenAgentSDK, SPM-only distribution
- Actor-based concurrency model for all mutable stores and QueryEngine
- Protocol-based tool system with Codable input decoding and JSON Schema dict for LLM
- Typed error model with associated values (SDKError enum)
- Budget tracking with model pricing lookup table
- POSIX shell execution for hooks (Process on macOS, posix_spawn on Linux)
- Conversation compaction: auto-compact + micro-compact
- Implementation priority: Foundation → Core Engine → Tool System → Advanced Tools → Specialist Tools → MCP → Sessions & Hooks → Polish
- 8 actor stores: SessionStore, TaskStore, TeamStore, MailboxStore, PlanStore, CronStore, TodoStore, AgentRegistry
- Module boundaries: Types/ (leaf) → API/ → Core/ → Tools/, Stores/, Hooks/ (independent of Core)
- JSON ↔ Codable boundary: raw [String: Any] for LLM communication, Codable for Swift internal and persistence

### UX Design Requirements

_No UX Design document found — this is a pure SDK library with no user interface._

### FR Coverage Map

FR1: Epic 1 - Create agent with system prompt, model, configuration
FR2: Epic 2 - Streaming responses via AsyncStream
FR3: Epic 1 - Blocking responses with final result
FR4: Epic 1 - Full agentic loop execution
FR5: Epic 2 - max_tokens recovery with continuation prompts
FR6: Epic 1 - Maximum turn count per invocation
FR7: Epic 2 - Cumulative token usage and cost tracking
FR8: Epic 2 - Maximum budget enforcement with graceful stop
FR9: Epic 2 - Auto-compact conversations near context limits
FR10: Epic 2 - Micro-compact large tool results (>50k chars)
FR11: Epic 3 - Register tools and tool tiers
FR12: Epic 3 - Concurrent read-only / serial mutation tool execution
FR13: Epic 3 - Custom tools with defineTool() and Codable
FR14: Epic 3 - JSON Schema for LLM + Codable for Swift
FR15: Epic 3 - 34 built-in tools across three tiers
FR16: Epic 3 - Core tier: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUser, ToolSearch
FR17: Epic 4 - Advanced tier: Agent, SendMessage, Task*, Team*, NotebookEdit
FR18: Epic 5 - Specialist tier: Worktree, Plan, Cron, LSP, Config, Todo, MCP Resources
FR19: Epic 6 - MCP stdio transport
FR20: Epic 6 - MCP HTTP/SSE transport
FR21: Epic 6 - In-process MCP server for external clients
FR22: Epic 6 - MCP tools alongside built-in tools
FR23: Epic 7 - Save conversations to JSON storage
FR24: Epic 7 - Load and resume saved conversations
FR25: Epic 7 - Fork conversation from any saved point
FR26: Epic 7 - List, rename, tag, delete sessions
FR27: Epic 7 - Thread-safe session storage via actor
FR28: Epic 8 - Function hooks on 21 lifecycle events
FR29: Epic 8 - Shell command hooks with regex matchers
FR30: Epic 8 - Shell hooks JSON stdin/stdout protocol
FR31: Epic 8 - Configurable hook timeout (30s default)
FR32: Epic 8 - Six permission modes
FR33: Epic 8 - Custom canUseTool authorization callback
FR34: Epic 8 - Permission-based tool access control
FR35: Epic 4 - Spawn subagents via Agent tool
FR36: Epic 4 - Inter-agent SendMessage communication
FR37: Epic 4 - Task management tools (Create/List/Update/Get/Stop/Output)
FR38: Epic 4 - Team management tools (Create/Delete)
FR39: Epic 1 - Environment variable configuration
FR40: Epic 1 - Programmatic configuration struct
FR41: Epic 1 - Multiple LLM providers via custom base URLs
FR42: Epic 4 - TaskStore for task state management
FR43: Epic 4 - TeamStore for team state management
FR44: Epic 5 - WorktreeStore
FR45: Epic 5 - PlanStore
FR46: Epic 5 - CronStore
FR47: Epic 5 - TodoStore
FR48: Epic 5 - Actor-based thread-safe stores
FR49: Epic 9 - Swift-DocC API documentation
FR50: Epic 9 - Working code examples for all features
FR51: Epic 9 - README with quickstart guide

## Epic List

### Epic 1: Foundation & Agent Setup
Developers can create a configured agent, send prompts, and receive responses through a complete agentic loop. The SDK is initialized with SPM, environment variables work, and programmatic configuration is available. This is the "hello world" epic — after completion, a developer has a working agent that talks to an LLM.
**FRs covered:** FR1, FR3, FR4, FR6, FR39, FR40, FR41

### Epic 2: Streaming & Production-Ready Agent
Developers can stream agent responses in real-time via AsyncStream, track token usage and costs, enforce budgets, recover from max_tokens limits, and auto-compact conversations. The agent is production-ready with graceful error handling and resource management.
**FRs covered:** FR2, FR5, FR7, FR8, FR9, FR10

### Epic 3: Tool System & Core Tools
Developers can register built-in and custom tools with the agent. The tool system supports Codable input types, JSON Schema definitions for LLM consumption, concurrent execution of read-only tools, and serial execution of mutation tools. All 10 core tools (Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUser, ToolSearch) are implemented and functional.
**FRs covered:** FR11, FR12, FR13, FR14, FR15, FR16

### Epic 4: Multi-Agent Orchestration
Developers' agents can spawn subagents for delegated tasks, communicate between agents via SendMessage, and manage tasks and teams through dedicated stores. The Advanced tool tier (Agent, SendMessage, Task*, Team*, NotebookEdit) is complete, enabling multi-agent workflows.
**FRs covered:** FR17, FR35, FR36, FR37, FR38, FR42, FR43

### Epic 5: Specialist Tools & Management Stores
Developers' agents have access to the full Specialist tool tier (Worktree, Plan, Cron, LSP, Config, Todo, MCP Resources) with all backing actor stores (WorktreeStore, PlanStore, CronStore, TodoStore). The complete 34-tool suite is now available.
**FRs covered:** FR18, FR44, FR45, FR46, FR47, FR48

### Epic 6: MCP Protocol Integration
Developers can connect to external MCP servers via stdio and HTTP/SSE transports, and expose in-process tools for consumption by external MCP clients. MCP tools integrate seamlessly alongside built-in tools during agent execution.
**FRs covered:** FR19, FR20, FR21, FR22

### Epic 7: Session Persistence
Developers can save agent conversations to JSON files, load and resume them, fork from any point, and manage sessions (list, rename, tag, delete) with thread-safe actor-based storage.
**FRs covered:** FR23, FR24, FR25, FR26, FR27

### Epic 8: Hook System & Permissions
Developers can register function and shell hooks on 21 agent lifecycle events, control tool execution via six permission modes, and provide custom authorization callbacks. Hooks support configurable timeouts and shell commands communicate via JSON stdin/stdout.
**FRs covered:** FR28, FR29, FR30, FR31, FR32, FR33, FR34

### Epic 9: Documentation & Developer Experience
Developers have Swift-DocC generated API documentation with full symbol coverage, working code examples for every major feature area, and a README quickstart guide that gets them from SPM dependency to working agent in under 15 minutes.
**FRs covered:** FR49, FR50, FR51

---

## Epic 1: Foundation & Agent Setup

Developers can create a configured agent, send prompts, and receive responses through a complete agentic loop. The SDK is initialized with SPM, environment variables work, and programmatic configuration is available.

### Story 1.1: SPM Package & Core Type System

As a Swift developer,
I want to add OpenAgentSDK as an SPM dependency and import it in my project,
So that I can start building AI-powered applications with the SDK.

**Acceptance Criteria:**

**Given** a Swift project with a Package.swift
**When** the developer adds `.package(url: "...", from: "1.0.0")` and `.target(name: "App", dependencies: ["OpenAgentSDK"])`
**Then** `import OpenAgentSDK` compiles without errors
**And** the module exposes core types: SDKMessage, SDKError, TokenUsage, ToolProtocol, PermissionMode, ThinkingConfig, AgentOptions, QueryResult, ModelInfo

**Given** the SDK is imported
**When** the developer references SDKError cases
**Then** all error domains are available: apiError, toolExecutionError, budgetExceeded, maxTurnsExceeded, sessionError, mcpConnectionError, permissionDenied, abortError
**And** each case has associated values with descriptive information

### Story 1.2: Custom Anthropic API Client

As a developer,
I want the SDK to communicate with the Anthropic API using a custom client,
So that my agent can send messages and receive responses without a community SDK dependency.

**Acceptance Criteria:**

**Given** an AnthropicClient configured with an API key
**When** the client sends a POST /v1/messages request with a valid message
**Then** the API returns a response with content blocks and usage information
**And** the API key is never logged, printed, or included in error messages (NFR6)

**Given** an AnthropicClient configured with a custom base URL
**When** the client makes an API request
**Then** the request is sent to the custom base URL instead of api.anthropic.com (FR41)

**Given** the API returns a streaming response
**When** the client processes the SSE stream
**Then** content blocks are parsed incrementally as they arrive
**And** streaming begins within 2 seconds of API response receipt (NFR1)

### Story 1.3: SDK Configuration & Environment Variables

As a developer,
I want to configure the SDK via environment variables or a programmatic struct,
So that I can set API keys, model selection, and base URL without hardcoding values.

**Acceptance Criteria:**

**Given** the environment variables CODEANY_API_KEY, CODEANY_MODEL, and CODEANY_BASE_URL are set
**When** the SDK initializes its configuration
**Then** the values are read from ProcessInfo.processInfo (macOS) / getenv (Linux) and applied (FR39)

**Given** a developer creates an SDKConfiguration struct programmatically
**When** they set apiKey, model, baseURL, maxTurns, and maxTokens
**Then** the configuration is applied to the agent without any environment variable dependency (FR40)

**Given** a developer sets only the apiKey and model
**When** the remaining configuration properties are accessed
**Then** sensible defaults are applied: maxTurns=10, maxTokens=16384, model="claude-sonnet-4-6"

### Story 1.4: Agent Creation & Configuration

As a developer,
I want to create an agent with a system prompt and configuration options,
So that I can customize agent behavior for my specific use case.

**Acceptance Criteria:**

**Given** valid AgentOptions with a system prompt, model, and maxTurns
**When** the developer calls createAgent(options:)
**Then** an Agent instance is returned with the specified configuration (FR1)

**Given** an agent created with default options
**When** the developer inspects the agent's configuration
**Then** defaults are applied: model="claude-sonnet-4-6", maxTurns=10, maxTokens=16384

**Given** an agent created with a custom system prompt
**When** the agent processes a prompt
**Then** the system prompt is included in the API request as the first message

### Story 1.5: Agentic Loop with Blocking Responses

As a developer,
I want to send a prompt to my agent and receive the final complete response,
So that I can get fully processed agent results in a single call.

**Acceptance Criteria:**

**Given** an agent with no tools registered
**When** the developer calls agent.prompt("Explain Swift concurrency")
**Then** the agentic loop executes: sends message to LLM, receives response, returns final result (FR4)
**And** the response includes the assistant's text content and usage statistics (FR3)

**Given** an agent configured with maxTurns=5
**When** the agentic loop executes and reaches 5 turns
**Then** the loop stops and returns a result with the maxTurnsExceeded status (FR6)

**Given** the LLM returns a response with stop_reason="end_turn"
**When** the agentic loop processes this response
**Then** the loop terminates and returns the complete response

---

## Epic 2: Streaming & Production-Ready Agent

Developers can stream agent responses in real-time, track costs, enforce budgets, recover from errors, and auto-compact conversations.

### Story 2.1: Streaming Responses via AsyncStream

As a developer,
I want to consume agent responses as a real-time stream of events,
So that I can display progressive results in my application UI.

**Acceptance Criteria:**

**Given** an agent created with valid configuration
**When** the developer calls agent.stream("Analyze this code")
**Then** an AsyncStream<SDKMessage> is returned immediately (FR2)
**And** SDKMessage events are yielded as they arrive from the LLM

**Given** an active AsyncStream<SDKMessage>
**When** the agent processes a streaming response
**Then** the stream emits typed events: text delta, tool use start, tool result, usage update, and completion
**And** the developer can pattern-match on SDKMessage cases using `case let`

**Given** an active stream that encounters an API error
**When** the error is received from the LLM
**Then** an error event is emitted on the stream and the stream terminates gracefully

### Story 2.2: Token Usage & Cost Tracking

As a developer,
I want to track cumulative token usage and estimated cost per invocation,
So that I can monitor and control my API spending.

**Acceptance Criteria:**

**Given** an agent executing an agentic loop
**When** each LLM API call completes
**Then** input and output token counts are accumulated in the usage tracker (FR7)
**And** estimated cost is calculated using the MODEL_PRICING lookup table

**Given** a completed agent invocation
**When** the developer inspects the QueryResult
**Then** total input tokens, output tokens, and estimated cost in USD are available

**Given** the agent uses different models in sequence
**When** cost is calculated
**Then** each model's pricing is applied correctly based on its token costs

### Story 2.3: Budget Enforcement

As a developer,
I want to set a maximum USD budget per agent invocation,
So that runaway agent loops cannot burn through my API credits.

**Acceptance Criteria:**

**Given** an agent configured with maxBudgetUSD=0.50
**When** the cumulative cost exceeds $0.50 during execution
**Then** the agentic loop stops immediately (FR8)
**And** a graceful error result is returned with cost summary and turns used (NFR16)
**And** the application does not crash

**Given** an agent configured without a budget limit
**When** the agent executes
**Then** cost is tracked but no budget check is performed

### Story 2.4: LLM API Retry & max_tokens Recovery

As a developer,
I want the agent to retry failed API calls and recover from max_tokens responses,
So that transient errors and context limits don't terminate my agent session.

**Acceptance Criteria:**

**Given** an LLM API call that fails with a transient error (429, 500, 502, 503)
**When** the error is caught by the retry mechanism
**Then** the request is retried with exponential backoff up to 3 retries (NFR15)
**And** the SDK does not crash or expose the API key in error messages

**Given** an LLM response with stop_reason="max_tokens"
**When** the agentic loop processes this response
**Then** a continuation prompt is sent to resume generation (FR5)
**And** the conversation continues from where it was cut off
**And** retry continues up to 3 times before returning the partial result

### Story 2.5: Conversation Auto-Compact

As a developer,
I want the agent to automatically compact conversations when approaching context limits,
So that long conversations continue without manual intervention.

**Acceptance Criteria:**

**Given** an agent conversation approaching the context window threshold
**When** the next LLM call would exceed the limit
**Then** the conversation is summarized via an LLM call and the history is replaced with the summary (FR9)
**And** conversation continuity is preserved after summarization (NFR18)

**Given** an auto-compact operation in progress
**When** the compaction completes
**Then** the compacted conversation includes a system message noting the compaction event
**And** the agentic loop continues with the compacted history

### Story 2.6: Tool Result Micro-Compact

As a developer,
I want the agent to automatically compress large tool results,
So that individual tool outputs don't consume excessive context.

**Acceptance Criteria:**

**Given** a tool execution that returns a result exceeding 50,000 characters
**When** the result is added to the conversation
**Then** the result is automatically micro-compacted with a summary preserving key information (FR10)
**And** the compacted result is clearly marked as truncated

**Given** a tool result under 50,000 characters
**When** the result is added to the conversation
**Then** no micro-compaction is performed and the full result is included

---

## Epic 3: Tool System & Core Tools

Developers can register built-in and custom tools. The tool system supports Codable input types, JSON Schema, and concurrent/serial execution. All 10 core tools are implemented.

### Story 3.1: Tool Protocol & Registry

As a developer,
I want to register individual tools or tool tiers with my agent,
So that the LLM knows which tools are available for execution.

**Acceptance Criteria:**

**Given** an agent with no tools registered
**When** the developer registers a single tool conforming to ToolProtocol
**Then** the tool appears in the tool definitions sent to the LLM (FR11)

**Given** an agent with tools registered
**When** the developer registers the "core" tool tier
**Then** all 10 core tools are registered at once
**And** tool definitions include name, description, and inputSchema for each tool (FR15)

**Given** an agent with registered tools
**When** the developer filters tools by name pattern
**Then** only matching tools are included in the tool definitions

### Story 3.2: Custom Tool Definition with defineTool()

As a developer,
I want to create custom tools with Codable input types and closure-based execution,
So that I can extend my agent with domain-specific capabilities.

**Acceptance Criteria:**

**Given** a Codable struct defining the tool input (e.g., struct CSVInput: Codable)
**When** the developer calls defineTool with a name, description, JSON Schema, and execution closure
**Then** a ToolProtocol-conforming tool is created (FR13)
**And** the tool accepts Codable-decoded input in the execution closure
**And** the JSON Schema is provided to the LLM for tool calling (FR14)

**Given** a custom tool defined with defineTool()
**When** the LLM requests the tool with JSON input
**Then** the JSON is decoded into the Codable struct and passed to the execution closure
**And** the tool's ToolResult is returned to the agentic loop

### Story 3.3: Tool Executor with Concurrent/Serial Dispatch

As a developer,
I want the agent to execute read-only tools concurrently and mutation tools serially,
So that file-system operations are safe while maximizing throughput.

**Acceptance Criteria:**

**Given** an agent with multiple read-only tools (Read, Glob, Grep) requested in a single turn
**When** the tool executor dispatches them
**Then** up to 10 read-only tools execute concurrently via TaskGroup (FR12, NFR3)
**And** all results are collected and fed back to the LLM

**Given** an agent with mutation tools (Write, Edit, Bash) requested in a single turn
**When** the tool executor dispatches them
**Then** mutation tools execute serially in order
**And** each mutation completes before the next begins

**Given** a tool execution that fails with an exception
**When** the error is caught by the tool executor
**Then** the error is captured as a ToolResult with is_error=true and returned to the agent (NFR17)
**And** the agentic loop continues without crashing

### Story 3.4: Core File Tools (Read, Write, Edit)

As a developer,
I want my agent to read, create, and modify files on the file system,
So that it can work with source code and configuration files.

**Acceptance Criteria:**

**Given** the Read tool is registered
**When** the LLM requests reading a file at a valid path
**Then** the file contents are returned as a string
**And** file operations under 1MB complete within 500ms (NFR2)

**Given** the Write tool is registered
**When** the LLM requests writing content to a file path
**Then** the file is created or overwritten with the specified content
**And** the parent directory is created if it doesn't exist

**Given** the Edit tool is registered
**When** the LLM requests replacing a string in an existing file
**Then** only the matched portion is replaced and the file is updated
**And** the edit fails gracefully if the old string is not found

**Given** any file tool operating on paths
**When** paths contain special characters or are relative
**Then** paths are resolved correctly using POSIX-compliant handling (NFR14)

### Story 3.5: Core Search Tools (Glob, Grep)

As a developer,
I want my agent to search for files by name pattern and search file contents,
So that it can find relevant files and code in a project.

**Acceptance Criteria:**

**Given** the Glob tool is registered
**When** the LLM requests a glob pattern like "**/*.swift"
**Then** matching file paths are returned sorted by modification time
**And** the search completes within 500ms for typical project sizes (NFR2)

**Given** the Grep tool is registered
**When** the LLM requests searching for a regex pattern in files
**Then** matching lines with file paths and line numbers are returned
**And** the search respects file type filters and directory scoping

### Story 3.6: Core System Tools (Bash, AskUser, ToolSearch)

As a developer,
I want my agent to execute shell commands, ask me questions, and search available tools,
So that it can perform system operations and interact with me during execution.

**Acceptance Criteria:**

**Given** the Bash tool is registered
**When** the LLM requests executing a shell command
**Then** the command is executed via POSIX shell and stdout/stderr are captured
**And** the command has a configurable timeout and working directory

**Given** the AskUser tool is registered
**When** the LLM needs user input during execution
**Then** a question is presented and the user's response is returned to the agent

**Given** the ToolSearch tool is registered
**When** the LLM requests a search of available tools
**Then** matching tool names and descriptions are returned to help the LLM select appropriate tools

### Story 3.7: Core Web Tools (WebFetch, WebSearch)

As a developer,
I want my agent to fetch web content and perform web searches,
So that it can access information from the internet.

**Acceptance Criteria:**

**Given** the WebFetch tool is registered
**When** the LLM requests fetching a URL
**Then** the page content is fetched and returned as text or markdown
**And** the request has a configurable timeout

**Given** the WebSearch tool is registered
**When** the LLM requests a web search query
**Then** search results with titles, URLs, and summaries are returned
**And** results are limited to a configurable maximum count

---

## Epic 4: Multi-Agent Orchestration

Developers' agents can spawn subagents, communicate via messages, and manage tasks and teams through dedicated stores.

### Story 4.1: TaskStore & MailboxStore Foundation

As a developer,
I want agents to manage tasks and exchange messages through thread-safe stores,
So that multi-agent workflows can coordinate reliably.

**Acceptance Criteria:**

**Given** a TaskStore actor
**When** tasks are created, updated, listed, and retrieved concurrently
**Then** all operations are thread-safe via actor isolation (FR42, FR48)
**And** task state transitions (pending → in_progress → completed) are enforced

**Given** a MailboxStore actor
**When** agents send messages to each other
**Then** messages are queued per recipient and delivered in order
**And** the store handles concurrent access from multiple agents safely

### Story 4.2: TeamStore & AgentRegistry

As a developer,
I want agents to create teams and register subagents,
So that I can orchestrate groups of agents working together.

**Acceptance Criteria:**

**Given** a TeamStore actor
**When** teams are created with members and deleted
**Then** team state is managed thread-safely (FR43, FR48)
**And** team members can be listed and their roles identified

**Given** an AgentRegistry actor
**When** subagents are spawned and register themselves
**Then** the registry tracks all active agents by name and ID
**And** agents can discover each other through the registry

### Story 4.3: Agent Tool (Subagent Spawning)

As a developer,
I want my agent to spawn subagents for delegated tasks,
So that complex tasks can be parallelized across specialized agents.

**Acceptance Criteria:**

**Given** the Agent tool is registered
**When** the parent agent requests spawning a subagent with a specific prompt
**Then** a new agent is created and executes the delegated task (FR35)
**And** the subagent's result is returned to the parent agent

**Given** a subagent executing a delegated task
**When** the subagent completes or fails
**Then** the parent agent receives the result or error and continues its loop

### Story 4.4: SendMessage Tool

As a developer,
I want agents to communicate with teammates by sending messages,
So that multi-agent teams can coordinate their work.

**Acceptance Criteria:**

**Given** the SendMessage tool is registered and a team exists
**When** an agent sends a message to a teammate by name
**Then** the message is delivered via the MailboxStore (FR36)
**And** the recipient agent can read and process the message

**Given** an agent sends a broadcast message
**When** the message is sent to all teammates
**Then** each teammate receives the message in their mailbox

### Story 4.5: Task Tools (Create/List/Update/Get/Stop/Output)

As a developer,
I want my agent to manage tasks using dedicated tools,
So that complex multi-step work can be tracked and coordinated.

**Acceptance Criteria:**

**Given** the TaskCreate tool is registered
**When** the LLM requests creating a task with a title and description
**Then** a new task is created in the TaskStore with status "pending" (FR37)

**Given** the TaskList tool is registered
**When** the LLM requests listing tasks
**Then** all tasks with their status and assignees are returned

**Given** the TaskUpdate tool is registered
**When** the LLM requests updating a task's status to "in_progress" or "completed"
**Then** the task state is updated in the TaskStore

**Given** the TaskGet, TaskStop, and TaskOutput tools are registered
**When** the LLM requests task details, stops a task, or retrieves output
**Then** each operation performs correctly against the TaskStore

### Story 4.6: Team Tools (Create/Delete)

As a developer,
I want my agent to create and manage teams of agents,
So that I can organize multi-agent workflows.

**Acceptance Criteria:**

**Given** the TeamCreate tool is registered
**When** the LLM requests creating a team with a name and description
**Then** a new team is created in the TeamStore (FR38)

**Given** the TeamDelete tool is registered
**When** the LLM requests deleting a team
**Then** the team and its state are removed from the TeamStore
**And** all active team members are notified of the deletion

### Story 4.7: NotebookEdit Tool

As a developer,
I want my agent to edit Jupyter notebook cells,
So that it can work with data science workflows.

**Acceptance Criteria:**

**Given** the NotebookEdit tool is registered
**When** the LLM requests editing a cell in a .ipynb file
**Then** the specified cell is replaced, inserted, or deleted (FR17)

**Given** the NotebookEdit tool with edit_mode=insert
**When** the LLM requests inserting a new cell
**Then** a new code or markdown cell is added at the specified position

---

## Epic 5: Specialist Tools & Management Stores

Developers' agents have access to specialist tools with all backing actor stores.

### Story 5.1: WorktreeStore & Worktree Tools

As a developer,
I want my agent to manage git worktrees,
So that it can work on isolated copies of a repository.

**Acceptance Criteria:**

**Given** a WorktreeStore actor and WorktreeEnter/Exit tools registered
**When** the LLM requests entering a worktree with a given name
**Then** a new git worktree is created and the working directory switches to it (FR44)
**And** the store tracks the active worktree state thread-safely (FR48)

**Given** an active worktree
**When** the LLM requests exiting the worktree
**Then** the worktree is optionally kept or removed, and the session returns to the original directory

### Story 5.2: PlanStore & Plan Tools

As a developer,
I want my agent to create and manage implementation plans,
So that complex tasks can be broken into structured steps.

**Acceptance Criteria:**

**Given** a PlanStore actor and PlanEnter/Exit tools registered
**When** the LLM requests entering plan mode
**Then** a plan is created in the PlanStore and the agent enters plan review mode (FR45)
**And** plan state transitions are managed thread-safely (FR48)

**Given** an active plan
**When** the LLM requests exiting plan mode
**Then** the plan is finalized and the agent returns to normal execution mode

### Story 5.3: CronStore & Cron Tools

As a developer,
I want my agent to create and manage scheduled tasks,
So that it can set up recurring or one-shot reminders.

**Acceptance Criteria:**

**Given** a CronStore actor and CronCreate/Delete/List tools registered
**When** the LLM requests creating a cron job with a schedule and prompt
**Then** the job is stored in the CronStore with its cron expression (FR46)
**And** cron state is managed thread-safely (FR48)

**Given** existing cron jobs
**When** the LLM requests listing or deleting them
**Then** the operations perform correctly against the CronStore

### Story 5.4: TodoStore & TodoWrite Tool

As a developer,
I want my agent to manage todo items,
So that it can track and update task progress.

**Acceptance Criteria:**

**Given** a TodoStore actor and TodoWrite tool registered
**When** the LLM requests writing todo items
**Then** the items are stored and managed in the TodoStore (FR47)
**And** todo state is managed thread-safely (FR48)

**Given** existing todos
**When** the LLM requests updating completion status or deleting items
**Then** the TodoStore reflects the changes correctly

### Story 5.5: LSP Tool

As a developer,
I want my agent to interact with Language Server Protocol servers,
So that it can get code intelligence like go-to-definition and references.

**Acceptance Criteria:**

**Given** the LSP tool is registered and an LSP server is configured
**When** the LLM requests a go-to-definition or find-references operation
**Then** the LSP server is queried and the results are returned (FR18)

**Given** the LSP tool with no server configured
**When** the LLM requests an LSP operation
**Then** a descriptive error is returned indicating no server is available

### Story 5.6: Config Tool & RemoteTrigger Tool

As a developer,
I want my agent to manage SDK configuration and trigger remote operations,
So that it can adjust settings and interact with external systems.

**Acceptance Criteria:**

**Given** the Config tool is registered
**When** the LLM requests reading or updating SDK configuration
**Then** configuration changes are applied and persisted (FR18)

**Given** the RemoteTrigger tool is registered
**When** the LLM requests triggering a remote operation
**Then** the trigger is executed and the result is returned (FR18)

### Story 5.7: MCP Resource Tools (ListMcpResources, ReadMcpResource)

As a developer,
I want my agent to list and read MCP resources,
So that it can access resources exposed by MCP servers.

**Acceptance Criteria:**

**Given** the ListMcpResources tool is registered and an MCP server is connected
**When** the LLM requests listing available resources
**Then** resources exposed by the MCP server are returned (FR18)

**Given** the ReadMcpResource tool is registered
**When** the LLM requests reading a specific MCP resource
**Then** the resource content is fetched from the MCP server and returned

---

## Epic 6: MCP Protocol Integration

Developers can connect to external MCP servers and expose in-process tools via MCP.

### Story 6.1: MCP Client Manager & Stdio Transport

As a developer,
I want to connect to external MCP servers via stdio transport,
So that my agent can use tools provided by external processes.

**Acceptance Criteria:**

**Given** an MCPClientManager actor configured with a stdio server config
**When** the manager establishes a connection
**Then** the external process is started and the MCP handshake completes (FR19)
**And** server process lifecycle is managed (start, crash recovery, graceful shutdown) (NFR19)

**Given** a connected MCP server via stdio
**When** the server process crashes
**Then** the MCPClientManager detects the failure and attempts recovery or reports disconnection

### Story 6.2: MCP HTTP/SSE Transport

As a developer,
I want to connect to external MCP servers via HTTP/SSE transport,
So that my agent can use tools provided by remote services.

**Acceptance Criteria:**

**Given** an MCPClientManager actor configured with an HTTP/SSE server config
**When** the manager establishes a connection
**Then** the HTTP connection is opened and the MCP handshake completes (FR20)
**And** SSE events are received for server-initiated messages

**Given** a connected MCP server via HTTP/SSE
**When** the connection drops
**Then** the manager handles reconnection gracefully without crashing

### Story 6.3: In-Process MCP Server

As a developer,
I want to expose my agent's tools as an MCP server,
So that external MCP clients can consume my tools.

**Acceptance Criteria:**

**Given** an InProcessMCPServer with registered tools
**When** an external MCP client connects
**Then** the server exposes tools via the MCP protocol (FR21)
**And** tool execution requests from clients are dispatched to the registered tools

### Story 6.4: MCP Tool Integration with Agent

As a developer,
I want MCP tools to appear alongside built-in tools during agent execution,
So that the agent seamlessly uses both local and remote tools.

**Acceptance Criteria:**

**Given** an agent with both built-in tools and connected MCP servers
**When** the tool pool is assembled
**Then** MCP tools are namespaced as `mcp__{serverName}__{toolName}` and included in tool definitions (FR22)

**Given** an agent executing with MCP tools available
**When** the LLM requests an MCP tool
**Then** the tool is dispatched through the MCPClientManager and the result is returned to the agentic loop

---

## Epic 7: Session Persistence

Developers can save, load, fork, and manage agent conversations with thread-safe storage.

### Story 7.1: SessionStore Actor & JSON Persistence

As a developer,
I want to save agent conversations to JSON files,
So that conversation state persists across application restarts.

**Acceptance Criteria:**

**Given** a SessionStore actor
**When** a conversation is saved with a session ID
**Then** the transcript is serialized to `~/.open-agent-sdk/sessions/{sessionId}/transcript.json` (FR23)
**And** the file is stored with user-only permissions (0600) (NFR10)
**And** the operation completes within 200ms for conversations under 500 messages (NFR4)

**Given** the SessionStore handling concurrent save requests
**When** multiple agents save simultaneously
**Then** all saves complete correctly without data corruption (FR27)

### Story 7.2: Session Load & Resume

As a developer,
I want to load and resume previously saved conversations,
So that agents can continue from where they left off.

**Acceptance Criteria:**

**Given** a previously saved session
**When** the developer loads the session by ID
**Then** the message history is deserialized and the agent resumes with the full context (FR24)
**And** the loaded messages are compatible with the current agentic loop

### Story 7.3: Session Fork

As a developer,
I want to fork a conversation from any saved point,
So that I can explore alternative paths without losing the original conversation.

**Acceptance Criteria:**

**Given** a saved session with multiple messages
**When** the developer forks from a specific message index
**Then** a new session is created with messages up to the fork point (FR25)
**And** the original session is unchanged
**And** the forked session has a new unique ID

### Story 7.4: Session Management (List, Rename, Tag, Delete)

As a developer,
I want to list, rename, tag, and delete saved sessions,
So that I can organize and manage my conversation history.

**Acceptance Criteria:**

**Given** multiple saved sessions
**When** the developer lists sessions
**Then** all sessions with metadata (ID, date, message count, tags) are returned (FR26)

**Given** an existing session
**When** the developer renames or tags the session
**Then** the session metadata is updated without modifying the transcript

**Given** an existing session
**When** the developer deletes the session
**Then** the session directory and all its files are removed

---

## Epic 8: Hook System & Permissions

Developers can register hooks on lifecycle events and control tool execution via permission modes.

### Story 8.1: Hook Event Types & Registry

As a developer,
I want to register hooks on 21 agent lifecycle events,
So that I can observe and react to agent behavior.

**Acceptance Criteria:**

**Given** a HookRegistry actor
**When** the developer registers a function hook on a lifecycle event (e.g., PostToolUse)
**Then** the hook is stored and will be called when the event fires (FR28)
**And** all 21 events are available as typed enum cases with compile-time exhaustiveness checking

**Given** a registered hook on PreToolUse
**When** the agent is about to execute a tool
**Then** the hook is invoked with the tool name and input
**And** the hook's return value can allow, deny, or modify the execution

### Story 8.2: Function Hook Registration & Execution

As a developer,
I want to register async function hooks on lifecycle events,
So that I can run custom logic during agent execution.

**Acceptance Criteria:**

**Given** a function hook registered on SessionStart
**When** a new agent session begins
**Then** the hook receives the session context and can perform initialization logic

**Given** multiple hooks registered on the same event
**When** the event fires
**Then** all hooks are executed in registration order
**And** each hook receives the output of the previous hook if applicable

### Story 8.3: Shell Hook Execution

As a developer,
I want to register shell command hooks with regex matchers,
So that I can run external scripts in response to agent events.

**Acceptance Criteria:**

**Given** a shell hook registered on PostToolUse with a regex matcher
**When** the event fires and the tool name matches the regex
**Then** the shell command is executed via POSIX process spawning (FR29)
**And** the hook receives event data as JSON on stdin and returns output as JSON on stdout (FR30)

**Given** a shell hook with a 30-second timeout
**When** the shell command exceeds the timeout
**Then** the process is terminated and a timeout error is logged (FR31)

**Given** shell hook input containing special characters
**When** the input is passed to the shell command
**Then** input is sanitized to prevent command injection (NFR7)

### Story 8.4: Permission Modes

As a developer,
I want to set one of six permission modes to control tool execution,
So that I can restrict what my agent is allowed to do.

**Acceptance Criteria:**

**Given** an agent configured with permissionMode = .bypassPermissions
**When** any tool is requested by the LLM
**Then** the tool executes without prompting (FR32)

**Given** an agent configured with permissionMode = .default
**When** a mutation tool (Write, Edit, Bash) is requested
**Then** the permission system enforces the default authorization flow (FR34, NFR8)

**Given** all six permission modes (default, acceptEdits, bypassPermissions, plan, dontAsk, auto)
**When** the developer selects each mode
**Then** the permission behavior matches the mode's specification

### Story 8.5: Custom Authorization Callback

As a developer,
I want to provide a custom canUseTool callback,
So that I can implement my own authorization logic for tool execution.

**Acceptance Criteria:**

**Given** an agent with a custom canUseTool closure
**When** the LLM requests executing a tool
**Then** the closure is invoked with the tool definition and input (FR33, NFR9)
**And** the closure's CanUseToolResult determines whether to allow, deny, or prompt the user

**Given** a canUseTool callback that denies execution
**When** the LLM requests a denied tool
**Then** the tool is not executed and a permission denied error is returned to the agent

---

## Epic 9: Documentation & Developer Experience

Developers have full API documentation, working examples, and a quickstart README.

### Story 9.1: Swift-DocC API Documentation

As a developer,
I want comprehensive Swift-DocC generated API documentation,
So that I can understand every public type, method, and property in the SDK.

**Acceptance Criteria:**

**Given** the SDK source code with DocC comments
**When** Swift-DocC generates documentation
**Then** all public types, protocols, methods, and properties are documented (FR49)
**And** the documentation includes usage examples for key APIs

### Story 9.2: README & Quickstart Guide

As a developer,
I want a README with a quickstart guide,
So that I can go from SPM dependency to working agent in under 15 minutes.

**Acceptance Criteria:**

**Given** the README.md in the repository root
**When** a new developer reads the quickstart section
**Then** they can add the SPM dependency, configure an API key, create an agent, and get a response (FR51)
**And** the process takes under 15 minutes for a Swift developer

**Given** the README
**When** the developer looks for advanced usage
**Then** links to examples and DocC documentation are provided

### Story 9.3: Working Code Examples

As a developer,
I want working code examples for all major feature areas,
So that I can learn by modifying real code.

**Acceptance Criteria:**

**Given** the Examples/ directory
**When** the developer compiles and runs any example
**Then** it compiles without errors and demonstrates the documented feature (FR50)

**Given** the following examples exist:
- BasicAgent: Agent creation, single prompt, response handling
- StreamingAgent: AsyncStream consumption, event pattern matching
- CustomTools: defineTool(), Codable input, JSON Schema
- MCPIntegration: Connect to MCP server, expose in-process tools
- SessionsAndHooks: Save/load sessions, register hooks
**When** the developer runs each example
**Then** each demonstrates its feature area end-to-end

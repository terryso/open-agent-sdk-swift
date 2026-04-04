---
title: "Product Brief: OpenAgentSDKSwift"
status: "complete"
created: "2026-04-03"
updated: "2026-04-03T12:00:00Z"
inputs:
  - ~/.claude/plans/hazy-tumbling-globe.md
  - open-agent-sdk-typescript (source project)
---

# Product Brief: OpenAgentSDKSwift

## Executive Summary

OpenAgentSDKSwift is a native Swift package that brings the full power of the Open Agent SDK to the Swift ecosystem. It ports the proven TypeScript agent SDK to Swift, enabling macOS app developers and server-side Swift engineers to build AI agent applications with 34 built-in tools, MCP protocol support, session persistence, and a hook system — all without embedding Node.js as a runtime dependency.

Today, Swift developers who want AI agent capabilities face a grim choice: bridge through Node.js, accept limited community SDKs that only handle API calls, or build everything from scratch. No production-grade Swift agent framework exists. OpenAgentSDKSwift closes that gap by delivering a battle-tested agent architecture, proven in TypeScript, as a first-class Swift citizen using async/await, actors, and AsyncStream.

The AI agent framework market is growing at 45%+ year-over-year (Grand View Research, 2025), yet every major offering is TypeScript or Python-first. With Apple's FoundationModels framework validating Swift as an AI platform and server-side Swift adoption accelerating, the timing is right for a native Swift agent SDK that targets Apple platforms and Linux backends.

## The Problem

Swift developers building AI-powered applications face three compounding frustrations:

1. **No native agent SDK exists.** Every major agent framework — Anthropic Agent SDK, OpenAI Agents SDK, LangGraph, CrewAI — is TypeScript or Python-only. Swift developers are locked out. Apple's FoundationModels framework enables on-device inference with tool calling on Apple Silicon, but it does not provide cloud LLM access, cross-platform support, MCP protocol, or the rich tool ecosystem that agent applications need.

2. **Bridging through Node.js is a dealbreaker.** The closest path today is embedding a Node.js runtime alongside Swift code. This adds deployment complexity, memory overhead, and fragile inter-process communication. For production macOS apps and server deployments, it's a non-starter.

3. **Community Swift SDKs are API clients, not agent frameworks.** Projects like AnthropicSwiftSDK, AnthropicKit, and SwiftAnthropic handle message completion and streaming, but they don't run an agent loop, execute tools, manage sessions, or speak MCP. Developers still have to build 80% of the system themselves. CLI wrappers like ClaudeCodeSDK depend on an external binary rather than providing standalone agent primitives.

The cost of the status quo is real: developers either abandon Swift for AI workloads, or they spend weeks reimplementing what the TypeScript SDK already does well.

## The Solution

OpenAgentSDKSwift is a Swift Package Manager library (`OpenAgentSDK`) that provides the complete agent stack in native Swift:

- **Agentic loop** — The core QueryEngine runs the full cycle: call LLM, parse tool-use requests, execute tools, feed results back, repeat. Streaming via `AsyncStream<SDKMessage>`, blocking via `prompt()`.
- **34 built-in tools** — Organized in three tiers so consumers load only what they need:
  - **Core** (must-have for any agent): Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUser, ToolSearch
  - **Advanced** (multi-agent orchestration): Agent, SendMessage, Task tools (Create/List/Update/Get/Stop/Output), Team tools (Create/Delete), NotebookEdit
  - **Specialist** (CLI/developer workflow): Worktree, Plan, Cron, RemoteTrigger, LSP, Config, TodoWrite, MCP Resource tools
  All tiers ship in the same package; consumers opt in via tool registration.
- **MCP protocol support** — Connect to external MCP servers (stdio/HTTP) and expose in-process MCP tools. Makes the entire growing MCP ecosystem available to Swift developers. Built on mcp-swift-sdk.
- **Session persistence** — JSON-based conversation storage with save, load, fork, and resume. Thread-safe via Swift actors.
- **Hook system** — 21 lifecycle events (pre/post tool use, session start/end, subagent lifecycle, etc.) with function and shell command hooks.
- **Custom tools** — Define tools with closures using `defineTool()`, Codable input decoding, and JSON Schema definitions.
- **Multi-provider LLM routing** — Works with Anthropic Claude by default, supports third-party providers via custom base URLs.
- **Permission and security model** — Six permission modes (default, acceptEdits, bypassPermissions, plan, dontAsk, auto) control which tools an agent can execute. Custom `canUseTool` callback allows consumer-defined authorization logic. Designed for sandboxed macOS app contexts.

Everything is Swift-idiomatic: async/await, actors for state isolation, Codable for serialization, protocol-oriented tool system, and `for await` pattern matching on streaming events.

## What Makes This Different

1. **Only Swift SDK with full agent capabilities.** No other Swift package offers built-in tools + MCP + session persistence + hooks in a single library. The closest alternatives are API clients (message completion only) or CLI wrappers (depend on external binaries). Apple's FoundationModels covers on-device tool calling but not cloud LLMs, cross-platform deployment, or MCP.

2. **Proven architecture, managed translation risk.** This is a port of a working TypeScript SDK with a known architecture — the agentic loop, tool system, and session model are battle-tested in production. The Swift port carries implementation risk (notably around dynamic JSON schema handling, tool dispatch, and the hook shell execution model translating to Swift's strict type system), but the design is proven and the risk surface is identified.

3. **Minimal dependency footprint.** One external dependency (DePasqualeOrg/mcp-swift-sdk for MCP protocol). The Anthropic API client is custom-built on URLSession. No community Anthropic SDK version conflicts, no transitive dependency nightmares. The mcp-swift-sdk dependency will be evaluated for maturity and feature coverage during Phase 6; if it falls short, the fallback is to fork and maintain or implement MCP protocol natively.

4. **Cross-platform by nature.** Targets macOS 13+ and Linux via SPM. No Apple-only frameworks required. Works for native macOS apps and server-side Swift deployments alike.

5. **Part of a multi-language SDK family.** The TypeScript SDK has a Go port already. OpenAgentSDKSwift extends this family to Swift, with a consistent API philosophy across languages.

## Who This Serves

**Primary: macOS application developers** building AI-powered tools, editors, or productivity apps who need agent capabilities without shipping a Node.js runtime to end users. Success for them means dropping in an SPM dependency and having a full agent running in minutes.

**Secondary: Server-side Swift engineers** on Linux (Vapor, Hummingbird) building AI backend services, chatbots, or automated workflows. Success means using the same SDK on the server that they use in their macOS tools.

**Tertiary: AI/ML engineers** working in Swift who want to move beyond raw API calls to full agent orchestration with tool use, session management, and MCP integration.

## Success Criteria

- **Functional parity** — All 34 tools pass unit tests on both macOS and Linux, matching TypeScript SDK behavior
- **Swift-native feel** — API uses async/await, AsyncStream, Codable, and actors; developers familiar with Swift concurrency find it natural. README quickstart produces a working agent in under 15 minutes
- **Dual-platform CI** — GitHub Actions tests pass on both macOS and Linux for every PR
- **Documentation** — Swift-DocC generated docs, working examples for every major feature, README with quickstart
- **Community signals** — 200+ GitHub stars within 6 months of launch; issues/PRs from external developers; adoption in at least one third-party project
- **Test coverage** — Unit tests per phase, integration test for the agentic loop (Phase 3+), example compilation verified in CI
- **API stability** — Core agent loop and tool system APIs are frozen at v1.0; hook and MCP APIs are marked as evolving. Semver versioning; the Swift SDK tracks its own version independent of the TypeScript SDK

## Scope

**In (v1.0):**
- All 34 built-in tools with full test coverage
- Anthropic Claude API client (streaming + blocking)
- MCP client and in-process MCP server
- Session persistence (JSON file storage)
- Hook system (21 lifecycle events, function + shell hooks)
- Custom tool definition via `defineTool()`
- Subagent support (Agent tool, SendMessage)
- Permission modes and budget tracking
- Auto-compact and micro-compact
- Task/Team/Worktree/Plan/Cron management stores
- Swift-DocC documentation
- GitHub Actions CI (macOS + Linux)
- Working examples for all major features

**Out (v1.0):**
- iOS/iPadOS/visionOS support (feasible but deferred — requires auditing tools for filesystem/process sandboxing constraints; targeted for v1.1)
- Windows platform support
- IDE extensions (VS Code, Xcode plugin)
- SwiftUI companion package (chat views, message renderers)
- Hosted service or cloud deployment
- Visual UI or dashboard
- Fine-tuned model hosting
- Token billing or usage metering service
- FoundationModels integration (hybrid local/cloud routing)

## Vision

In 2-3 years, OpenAgentSDKSwift becomes the standard way to build AI agent applications in Swift — the library that every Swift developer reaches for when they need agent capabilities, just as Vapor is for web servers and Core Data is for persistence.

It complements Apple's FoundationModels for on-device inference by providing cloud LLM access, cross-platform support (macOS, Linux, and eventually iOS), and the full MCP ecosystem. The LLM provider abstraction is designed from day one to support a protocol-based `ModelProvider` that can wrap FoundationModels alongside cloud providers, enabling hybrid local/cloud agent orchestration as the SDK matures.

As the AI agent market grows, the SDK evolves from tool-use orchestration to multi-agent collaboration, autonomous workflows, and production-grade agent deployment on Swift infrastructure. The multi-language SDK family (TypeScript, Go, Swift) becomes the go-to open-source agent SDK for developers who value consistency across their stack.

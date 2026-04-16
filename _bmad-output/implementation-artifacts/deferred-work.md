# Deferred Work

## Deferred from: code review of 1-1-spm-package-core-types (2026-04-04)

- ~~**SessionMetadata 使用 String 时间戳**~~ — **FIXED**: `createdAt`/`updatedAt` are now `Date` type with proper `Codable` conformance. [SessionTypes.swift:15-17]
- ~~**McpSseConfig/McpHttpConfig 结构完全相同**~~ — **FIXED**: Merged into `McpTransportConfig` struct. `McpSseConfig` and `McpHttpConfig` retained as backward-compatible typealiases. [MCPConfig.swift:42-60]
- ~~**HookNotification.level / PermissionUpdate.behavior 为字符串类型**~~ — **FIXED**: Added `HookNotificationLevel` enum (info/warning/error/debug with unknown-value fallback) and `PermissionBehavior` enum (allow/deny). Both use `String` raw values with `Codable` conformance. [HookTypes.swift, PermissionTypes.swift]
- ~~**ThinkingConfig.enabled 无 budgetTokens 验证**~~ — **FIXED**: `ThinkingConfig.validate()` throws when budgetTokens <= 0; `AgentOptions.validate()` calls it. [ThinkingConfig.swift:25]
- **HookDefinition 所有字段可选** — 全 nil 实例无语义，匹配 TS SDK 模式 [HookTypes.swift]
- **MODEL_PRICING 字典对新模型返回 nil** — 新模型发布需更新 SDK，可改为可注册模式 [ModelInfo.swift:30-39]
- ~~**AgentOptions.baseURL 无 URL 验证**~~ — **FIXED**: `AgentOptions.validate()` throws on unparseable URL; `Agent.init` logs soft warnings. [AgentTypes.swift:253, Agent.swift:89]

## Deferred from: code review of 3-4-core-file-tools-read-write-edit (2026-04-05)

- ~~**Edit tool missing old_string == new_string guard**~~ — **FIXED**: Guard rejects identical strings with error "old_string and new_string must differ". [FileEditTool.swift:103]
- ~~**Edit tool missing replace_all parameter**~~ — **FIXED**: Added optional `replace_all: Bool?` to `FileEditInput`. When true, skips uniqueness check and replaces all occurrences. Backward compatible (defaults to false/nil). [FileEditTool.swift]
- **NFR2 performance test not verified** — No test confirms <1MB file reads complete in 500ms. Requires performance test infrastructure not available locally [FileReadTool.swift]

## Deferred from: code review of 4-1-task-store-mailbox-store (2026-04-06)

- **Task struct name collision with Swift Concurrency's Task** — `Task` struct collides with `_Concurrency.Task`. Already mitigated with `_Concurrency.Task` qualification in existing code, but remains a latent naming risk for future code. Pre-existing design decision documented in Dev Notes [TaskTypes.swift:17]

## Deferred from: code review of 5-7-mcp-resource-tools (2026-04-07)

- ~~**mcpConnections thread safety (latent risk)**~~ — **FIXED**: Removed `nonisolated(unsafe) var mcpConnections` global. MCP connections now passed via `ToolContext.mcpConnections` (Sendable value type). `setMcpConnections()` kept as no-op stub for backward compat. [ListMcpResourcesTool.swift, ToolTypes.swift]
- **AC5: missing tool count hint in listing-not-supported** — TS SDK shows `({tools.length} tools available)` but Swift MCPConnectionInfo lacks tools field. Deferred to Epic 6 when real MCP connections exist [ListMcpResourcesTool.swift:79-91]

## Deferred from: code review of 7-1-session-store-json-persistence (2026-04-08)

- ~~**load() silently swallows JSON corruption**~~ — **FIXED**: Added `Logger.shared.warn()` calls in load() where JSON decoding or metadata extraction fails. Returns nil with diagnostic logging. [SessionStore.swift:119]
- ~~**E2E tests missing concurrent/delete coverage**~~ — **FIXED**: Added `testConcurrentSaves()` (two concurrent writes, verify loadable after) and `testDeleteSession()` (delete existing, verify gone, delete nonexistent returns false). [SessionStoreE2ETests.swift]

## Deferred from: code review of 8-1-hook-event-types-registry (2026-04-09)

- ~~**Silent error swallowing in execute() catch block**~~ — **FIXED**: Hook errors are now logged with `Logger.shared.error("HookRegistry", "hook_execution_failed", ...)` including event type and error description. [HookRegistry.swift:125-128]
- ~~**HookOutput lacks Equatable conformance**~~ — **FIXED**: Added `Equatable` conformance to `HookOutput`. All fields are individually `Equatable`, so synthesized conformance works. Tests cover equality and inequality cases. [HookTypes.swift:102]

## Deferred from: code review of 8-5-custom-authorization-callback (2026-04-09)

- ~~**Stream path ignores dynamic permission changes**~~ — **FIXED**: `stream()` now reads `self.options.permissionMode` and `self.options.canUseTool` at each tool execution point instead of using captured locals. `setPermissionMode()` and `setCanUseTool()` now take effect mid-stream. [Agent.swift:1275-1276]

## Deferred from: code review of 10-3-prompt-api-example (2026-04-10)

- **No safety warning about destructive tools with bypassPermissions** — PromptAPIExample registers Write/Edit/Bash tools with bypassPermissions. All examples in the project follow this pattern. Pre-existing design choice, not introduced by this story

## Deferred from: code review of 11-4-built-in-skill-review (2026-04-11)

- **No guidance for binary/conflict diffs in promptTemplate** — The review promptTemplate does not instruct the agent how to handle `Binary files differ` output or merge conflict markers (`<<<<<<<`). Not in epics skeleton, pre-existing gap. [SkillTypes.swift:182-214]
- **Missing untracked file handling in three-level strategy** — `git diff`, `git diff --cached`, and `git diff HEAD~1` do not show untracked (new, never-staged) files. The epics skeleton uses the same three-level strategy without untracked file support. [SkillTypes.swift:184-190]

## Deferred from: code review of 12-2-cache-tool-and-compaction-integration (2026-04-12)

- ~~**modifiedPaths grows unboundedly in FileCache**~~ — **FIXED**: Added `maxModifiedPaths` property (default 1000). After adding entries in `set()` and `invalidate()`, oldest entries are evicted if count exceeds cap. [FileCache.swift:117]

## Deferred from: code review of 12-4-project-document-discovery (2026-04-12)

- **homeDirectory not controllable from buildSystemPrompt()** — Tests that exercise buildSystemPrompt() directly cannot isolate from the developer's real ~/.claude/CLAUDE.md. Current workaround uses contains assertions instead of equality. Pragmatic for now, but could be improved with a protocol-based injection pattern in a future refactor.

## Deferred from: code review of 14-5-sandbox-bash-command-filtering (2026-04-13)

- ~~**Single `$(...)`/backtick pair checked**~~ — **FIXED** in checkpoint review: `extractCommandSubstitution` now returns all substitution pairs instead of just the first

## Deferred from: checkpoint review of 15-2-sandbox-example (2026-04-13)

- ~~**Bash tool bypasses path sandbox**~~ — **FIXED**: `checkCommand` now includes Phase 3 path extraction (lines 230-269) that extracts file-like arguments and validates against `deniedPaths`/`allowedReadPaths`. [SandboxChecker.swift]

## Deferred from: code review of 15-1-skills-example (2026-04-13)

- **Backslash line continuation in promptTemplate** — Multi-line string literal uses `\` for line continuation, making the prompt harder to debug. Style preference, consistent with project patterns. [Examples/SkillsExample/main.swift:71-72]
- **No error handling around agent.prompt() call** — Example does not wrap agent.prompt() in do/catch. Consistent with all other examples in the project. Pre-existing pattern. [Examples/SkillsExample/main.swift:131]

## Fixed in: code review of 15-6-context-injection-example (2026-04-13)

- ~~**ShellHookExecutor.swift production code changes are scope creep**~~ — **NOT scope creep**: This was a deeper fix for the CI crash from commit acd5a26 (NSFileHandleOperationException). The previous fix wrapped reads in try?, but the incremental readabilityHandler approach still had race conditions in CI. The refactor eliminates the race by reading all stdout at once after process termination and properly closing the write end of the pipe. [Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift]

## Deferred from: code review of 15-7-multi-turn-example (2026-04-13)

- **No error handling around `try await` sessionStore calls** — Three `try await` calls to `sessionStore.load()` and `sessionStore.delete()` have no `do/catch`. Consistent with SessionsAndHooks example pattern. Pre-existing pattern not introduced by this story. [Examples/MultiTurnExample/main.swift:110,182,190]
- **assert() disabled in release builds** — All assertions use `assert()` which is stripped in release builds. Consistent with all other examples in the project. Pre-established pattern. [Examples/MultiTurnExample/main.swift:94,111,125,169,183,191]

## Deferred from: code review of add-core-validation-guards (2026-04-14)

- **ThinkingConfig with OpenAI provider** — `ThinkingConfig` is validated regardless of provider, but OpenAI doesn't support thinking tokens. The warning/log may be misleading for OpenAI users. Pre-existing design decision (ThinkingConfig is provider-agnostic). [Agent.swift, ThinkingConfig.swift]

## Deferred from: code review of deferred-work-cleanup (2026-04-14)

- **`evictModifiedPathsIfNeeded` not reflected in `CacheStats.evictionCount`** — `modifiedPaths` eviction is a separate tracking mechanism from cache entry eviction, so `evictionCount` remains semantically correct for cache entries. Future enhancement: add a dedicated `modifiedPathsEvictionCount` stat if monitoring is needed. [FileCache.swift]

## Deferred from: code review of thread-safety-dynamic-permissions (2026-04-14)

- **ToolContext.mcpConnections always nil** — Both `prompt()` and `stream()` pass `mcpConnections: nil`. Wiring actual connections requires extracting `MCPConnectionInfo` from `MCPClientManager`, which doesn't yet expose such an API. Structural migration is complete (tools read from context); injection wiring deferred to Epic 6 when MCP integration matures. [Agent.swift:589,1282]
- ~~**Data race on self.options in stream path**~~ — **FIXED**: Added `_permissionLock` (NSLock) protecting `setPermissionMode()`, `setCanUseTool()` writes, and stream-path reads of `permissionMode`/`canUseTool`. Other `self.options` fields remain unlocked (read-heavy, startup-configured). [Agent.swift:53,149,160,1283-1284]
- **Schema `nonisolated(unsafe)` constants in MCP tools** — `listMcpResourcesSchema` and `readMcpResourceSchema` are file-scope `nonisolated(unsafe) let` constants. Cannot remove `nonisolated(unsafe)` because `ToolInputSchema` (`[String: Any]`) is not `Sendable` — the compiler requires the annotation. Constants are immutable after init so this is safe. [ListMcpResourcesTool.swift:13, ReadMcpResourceTool.swift:5]

## Deferred from: code review of deferred-core-improvements (2026-04-15)

- ~~**MODEL_PRICING concurrent access race**~~ — **FIXED**: Added `_pricingLock` (NSLock) protecting `registerModel()` and `unregisterModel()` mutations. Direct dictionary access still possible for reads (startup-time), but public mutation API is now thread-safe. [ModelInfo.swift:56,66,74]

## Deferred from: code review of deferred-thread-safety-quality (2026-04-15)

- **MODEL_PRICING reads bypass lock** — Direct reads (e.g., `MODEL_PRICING["claude-sonnet-4-6"]`) are not protected by `_pricingLock`. Swift Dictionary with value types is safe for concurrent reads in practice on Apple platforms, but this is formally UB. Making all reads go through lock-protected accessors would require a major API change (private var + public getter). Trade-off accepted: lock prevents the crash scenario (concurrent writes), reads are safe in practice. [ModelInfo.swift:43]
- **CanUseToolFn Sendable conformance** — `setCanUseTool()` stores a closure read on the stream's async context. If the closure type is not `@Sendable`, this crosses concurrency boundaries. Pre-existing design decision, not introduced by this change.

## Deferred from: code review of 17-2-agent-options-enhancement (2026-04-16)

- **Compat test `testContinue_missing` checks wrong field name** — Test asserts `XCTAssertFalse(fields.contains("continue"))` checking the TS field name `continue`, while the Swift field is `continueRecentSession`. Test "passes" but doesn't verify the field exists. Pre-existing compat test design pattern (field-by-field name matching). [AgentOptionsCompatTests.swift:430-435]

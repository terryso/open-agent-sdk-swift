# Agent Runtime — Epic 29: Claude Code Skill/Subagent Compatibility

> **状态：提议中**
> **优先级：P1**
> **依赖：** 现有 `Agent` tool、`SubAgentSpawner`、`SkillTool`、filesystem `SkillLoader`
> **Consumer：** Axion Epic 40 (`/bmad-story-pipeline` integration)

## 背景与动机

Claude Code 生态中的 workflow skill 经常通过 `Task(...)` 片段派生子代理，例如：

```text
Task(
  subagent_type: "general-purpose",
  description: "Create story",
  prompt: "Execute /bmad-create-story 1-1 yolo ..."
)
```

Claude Code/Agent SDK 新接口把子代理入口称为 `Agent`，旧 `Task` 形状仍是兼容入口。OpenAgentSDK Swift 当前已经有 `Agent` tool、`SubAgentSpawner`、`SkillTool` 和 direct `executeSkillStream`，但这些能力还不足以完整运行 Claude Code 风格的编排型 skill：

- 只有 `createAgentTool()`，没有工具名为 `Task` 的兼容 alias。
- `Agent.createSubAgentSpawner(...)` 只检测工具池里的 `Agent`，工具池只有 `Task` 时不会注入 spawner。
- `DefaultSubAgentSpawner.filterTools(...)` 只移除 `Agent`，新增 `Task` 后必须同步移除，避免子代理默认递归派生。
- direct skill execution prompt 没有暴露 filesystem skill 的 `baseDir` 和 `supportingFiles`，裸相对路径容易被解析到调用者当前工作目录。
- `allowed-tools` 仍是 enum-only 解析，未知工具名、MCP namespaced tools、custom tools 可能被静默丢弃。
- subagent `tools` / `disallowedTools` 与 skill `allowed-tools` 没有共享同一套工具声明兼容与 diagnostics 路径。

本 Epic 将这些 runtime 能力收敛到 SDK，避免 Axion 或其他宿主重复实现 Claude Code 兼容逻辑。

## 目标

1. **提供 `Task` 兼容入口**：`Task` 是 `Agent` 的 alias，共用 schema、输入解析、执行体和输出格式。
2. **统一 subagent launcher 语义**：工具池中存在 `Agent` 或 `Task` 都能创建 `SubAgentSpawner`；子代理默认移除二者。
3. **让 direct skill execution 具备 skill package context**：prompt 中包含 filesystem skill 的 `baseDir` 和 supporting file 相对路径列表。
4. **保留 Claude Code 工具声明语义**：`allowed-tools`、subagent `tools`、`disallowedTools` 能表达 SDK built-in、MCP namespaced、custom/raw tool names。
5. **避免权限静默放大**：未知或暂不支持的工具声明必须形成 diagnostics，不能被误解为 unrestricted。
6. **保持宿主可组合**：SDK 只提供 tool/schema/filtering/prompt/runtime primitives，不硬编码 Axion 或 BMAD 业务规则。

## 非目标

- 不实现完整 workflow/DAG 引擎。
- 不实现 background subagent、resume subagent、worktree isolation、team coordination 的完整 runtime 语义；本 Epic 只保留字段、传递能力和可诊断状态。
- 不实现完整 `.claude/agents/*.md` 或 `.agents/agents/*.md` filesystem subagent loader。
- 不硬编码 BMAD 旧命令名到新命令名的映射。
- 不在 SDK 中实现 Axion 的 tool profile、dry-run policy、permission UI 或 slash command routing。

## 当前代码事实

- `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift` 定义 private `AgentToolInput`、`agentToolSchema` 和 public `createAgentTool()`。
- `Sources/OpenAgentSDK/Core/Agent.swift` 的 `createSubAgentSpawner(...)` 只判断 `tools.contains { $0.name == "Agent" }`。
- `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift` 的 `filterTools(...)` 默认只过滤 `$0.name != "Agent"`。
- `Sources/OpenAgentSDK/Core/Agent.swift` 的 `resolveSkillForExecution(_:, args:)` 只拼接 `promptTemplate` 和 `User request`。
- `Sources/OpenAgentSDK/Types/SkillTypes.swift` 已有 `Skill.baseDir` 和 `Skill.supportingFiles`，filesystem loader 已填充这些 metadata。
- `Sources/OpenAgentSDK/Skills/SkillLoader.swift` 的 `parseAllowedTools(...)` 只返回 `[ToolRestriction]?`，无法保留 raw MCP/custom names。
- `ToolRestriction` raw value 使用小写/驼峰内部名，而 LLM-facing tool name 使用 `Read`、`WebFetch`、`Skill`、`Agent`、`mcp__server__tool` 等字符串。

## Story 29.1: `Agent` / `Task` 共享子代理入口

As a Claude Code-compatible SDK consumer,
I want `Task` to behave as an alias of `Agent`,
So that existing workflow skills can spawn subagents without rewriting their prompts.

**实施：**

1. 在 `AgentTool.swift` 中抽出共享 factory，例如 private `createSubAgentLauncherTool(name:description:)`。
2. 保持 `createAgentTool()` 返回工具名 `Agent`，现有 public API 不破坏。
3. 新增 public `createTaskTool()`，返回工具名 `Task`，schema 和执行体与 `Agent` 一致。
4. Swift 类型名避免使用裸 `Task`，不要引入 `TaskToolInput`；优先复用或改名为 `SubAgentLauncherInput`。
5. `OpenAgentSDK.swift` public surface 导出 `createTaskTool()`。
6. 更新文档示例，说明 Claude Code `Task(...)` 片段应注册 `createTaskTool()`，新代码可继续使用 `createAgentTool()`。

**Acceptance Criteria:**

**Given** 工具池注册 `createTaskTool()`
**When** LLM 调用 `Task(prompt:, description:)`
**Then** 调用路径与 `Agent` 完全一致
**And** 返回 child agent 文本和 tool summary

**Given** `Task` tool 没有 `ToolContext.agentSpawner`
**When** tool 被调用
**Then** 返回与 `Agent` 等价的明确错误
**And** 错误文案提到 subagent spawner 缺失

## Story 29.2: Spawner Detection 与子代理默认过滤

As an SDK runtime maintainer,
I want subagent spawner injection and child tool filtering to understand both `Agent` and `Task`,
So that aliasing does not create runtime holes or recursive child spawning by default.

**实施：**

1. 更新 `Agent.createSubAgentSpawner(...)`：工具池包含 `Agent` 或 `Task` 时都创建 `DefaultSubAgentSpawner`。
2. 更新 prompt/stream 两条路径中所有 spawner 创建调用，保持行为一致。
3. 更新 `DefaultSubAgentSpawner.filterTools(...)`：默认移除 `Agent` 和 `Task`。
4. 增加一个 helper，例如 `SubAgentLauncherNames.default = ["Agent", "Task"]`，避免硬编码散落。
5. 保留 escape hatch：未来若显式允许递归子代理，应通过明确配置而不是默认继承。

**Acceptance Criteria:**

**Given** 工具池只包含 `Task`
**When** agent 执行需要 tool call 的 prompt
**Then** tool context 中有非空 `agentSpawner`

**Given** 父工具池同时包含 `Agent` 和 `Task`
**When** `DefaultSubAgentSpawner` 创建 child agent
**Then** child tool pool 默认不包含 `Agent`
**And** child tool pool 默认不包含 `Task`

## Story 29.3: Direct Skill Package Context

As a filesystem skill author,
I want direct skill execution to include the skill package location,
So that supporting files are resolved relative to the skill package instead of the process cwd.

**实施：**

1. 在 `Agent.resolveSkillForExecution(_:, args:)` 附近抽出 prompt builder。
2. 当 `Skill.baseDir != nil` 或 `Skill.supportingFiles` 非空时，追加 compact package context。
3. 不内联 supporting file 内容，只列出路径，让 agent 按 skill 指令自行读取。
4. 保持 programmatic skill 无 package metadata 时的现有 prompt 形状。
5. 保持 `User request: <args>` 行为兼容。

**Prompt shape:**

```text
<skill.promptTemplate>

---
Skill package context:
- baseDir: <absolute skill dir>
- supportingFiles:
  - references/workflow-steps.md

Resolve bare supporting-file paths relative to baseDir. Read supporting files only when the skill instructions require them.

---
User request: <args>
```

**Acceptance Criteria:**

**Given** filesystem skill has `baseDir` and `supportingFiles`
**When** `executeSkillStream(skillName, args:)` runs
**Then** generated prompt contains the absolute `baseDir`
**And** generated prompt contains relative supporting file paths

**Given** programmatic skill has no package metadata
**When** `executeSkillStream` runs
**Then** prompt remains backward compatible with current output

## Story 29.4: Tool Declaration Compatibility Model

As a skill/subagent author,
I want tool declarations to preserve Claude Code style tool names, MCP namespaced tools, and custom tools,
So that restrictions do not silently lose intent.

**实施：**

1. Introduce a richer representation, for example:
   - `ToolDeclaration.rawName`
   - `ToolDeclaration.normalizedName`
   - `ToolDeclaration.pattern` for entries like `Bash(git diff:*)`
   - `ToolDeclaration.status` or diagnostics for unsupported entries
2. Keep backward compatibility for `Skill.toolRestrictions` or provide a migration path that existing callers can still consume.
3. Recognize common SDK/Claude names: `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash`, `WebFetch`, `WebSearch`, `ToolSearch`, `AskUser`, `Skill`, `Agent`, `Task`.
4. Preserve MCP namespaced names matching `mcp__<server>__<tool>`.
5. Preserve custom/raw tool names for host-defined tools.
6. Preserve permission pattern text such as `Bash(git diff:*)`; if fine-grained matching is not implemented, diagnostics must say it is parsed but not enforced at pattern granularity.
7. Unknown names must remain visible in parse output or diagnostics; they cannot collapse to `nil` because `nil` currently means unrestricted.

**Acceptance Criteria:**

**Given** `allowed-tools: WebSearch, mcp__github__list_prs, Task`
**When** filesystem skill is loaded
**Then** parse output preserves all three names
**And** `mcp__github__list_prs` is not dropped

**Given** `allowed-tools: UnknownTool`
**When** filesystem skill is loaded
**Then** SDK exposes a diagnostic or unsupported declaration
**And** runtime does not treat the skill as unrestricted solely because the enum parse found no cases

**Given** `allowed-tools: Bash(git diff:*)`
**When** filesystem skill is loaded
**Then** raw pattern text is preserved
**And** unsupported pattern-level enforcement is visible to the caller

## Story 29.5: Shared Filtering for Skill and Subagent Tool Sets

As an SDK consumer,
I want skill `allowed-tools` and subagent `tools` / `disallowedTools` to use the same matching rules,
So that the same declaration means the same thing across direct skills and spawned agents.

**实施：**

1. Add a reusable tool filtering helper that takes:
   - available `[ToolProtocol]`
   - allowed declarations
   - disallowed declarations
   - runtime policy flags if needed
2. Use exact tool name matching for built-in/custom/MCP tools after normalization.
3. Support both SDK internal restriction names and LLM-facing names for backward compatibility.
4. Apply helper in `DefaultSubAgentSpawner.filterTools(...)`.
5. Prepare `ToolRestrictionStack` or equivalent skill execution path to consume the richer declaration model.
6. Return or log diagnostics for declarations that do not match any available tool.

**模块位置（2026-06-14 readiness review 决策）：**

Helper 放在新文件 `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`，包含：
- `struct ToolDeclaration`（Story 29.4 引入的 richer model）
- `struct ToolFilterDiagnostics`（无匹配工具/未知名称/无强制 pattern 匹配的诊断）
- 自由函数 `filterToolsByDeclarations(available:allowed:disallowed:...) -> (filtered: [ToolProtocol], diagnostics: [ToolFilterDiagnostics])`

**理由：** 唯一同时满足"Core/(DefaultSubAgentSpawner) 可调用"且"Tools/(SkillTool、ToolRestrictionStack) 可调用"的位置是 `Types/` 或 `Utils/`。选 `Types/` 是为了让 `ToolDeclaration` 类型与其 filter 函数物理同处（与 `ToolRestriction` 在 `Types/SkillTypes.swift` 的模式一致）。`Core/` 不依赖 `Tools/`，故 helper 不能放在 `Tools/`；同理不能放在 `Core/`（Tools/ 不依赖 Core/）。

**Acceptance Criteria:**

**Given** child subagent declares `allowedTools: ["Read", "Grep", "Glob"]`
**When** child tool pool is built
**Then** only matching read/search tools are present
**And** `Write`, `Edit`, and `Bash` are absent

**Given** skill declares `allowed-tools: mcp__srv__search`
**When** available tools include that MCP tool
**Then** filtering keeps it
**And** does not require a `ToolRestriction` enum case

**Given** declarations mention a missing tool
**When** filtering finishes
**Then** diagnostics list the missing tool name
**And** no unrestricted fallback occurs

## Story 29.6: Diagnostics for Deferred Subagent Fields

As a user of Claude Code-style subagent definitions,
I want unsupported fields to be visible,
So that I can tell whether SDK honored or ignored background/resume/isolation/team/skills/MCP reference behavior.

**实施：**

1. In `AgentTool` / `DefaultSubAgentSpawner`, collect runtime diagnostics for fields that are accepted by schema but not fully wired.
2. Diagnostics should cover at least:
   - `run_in_background`
   - `resume`
   - `isolation`
   - `team_name`
   - `skills`
   - MCP server references that cannot be resolved from parent config
3. Include diagnostics in `SubAgentResult` text or structured metadata if available.
4. Keep inline MCP server configs working as today; reference resolution can remain deferred but must be explicit.

**Acceptance Criteria:**

**Given** tool input sets `run_in_background: true`
**When** runtime still executes foreground
**Then** result includes a diagnostic that background mode is not implemented

**Given** subagent definition references an MCP server by name
**When** parent MCP config is not available to resolver
**Then** result includes a diagnostic that reference resolution is deferred

## Story 29.7: Tests and Documentation

As an SDK maintainer,
I want the compatibility behavior covered by unit tests and docs,
So that host integrations can depend on stable public semantics.

**实施：**

1. Add XCTest coverage for `createTaskTool()` alias behavior in `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` or a focused new test file.
2. Extend `DefaultSubAgentSpawnerTests` for `Task` filtering and `Task`-only spawner detection.
3. Extend `ExecuteSkillStreamTests` for package context prompt assembly.
4. Add parser/filtering tests for MCP/custom/raw tool declarations.
5. Update DocC multi-agent / skills docs and cookbook examples where relevant.
6. E2E tests are optional and must use real environment per SDK repo rules.

**Acceptance Criteria:**

**Given** the SDK test suite runs
**When** this Epic is implemented
**Then** full suite passes
**And** the reported total test count is included in completion notes

**Given** a host registers `createTaskTool()`
**When** docs examples are followed
**Then** the host can run Claude Code-style `Task(...)` workflow snippets without additional SDK patching

## Story 间依赖关系

```text
29.1 Agent/Task shared launcher
  |
  +--> 29.2 Spawner detection and child filtering
  |
  +--> 29.3 Direct skill package context
  |
  +--> 29.4 Tool declaration compatibility
          |
          +--> 29.5 Shared filtering for skills/subagents
                  |
                  +--> 29.6 Diagnostics
                          |
                          +--> 29.7 Tests and documentation
```

## 实现优先级

| Story | 优先级 | 理由 |
| --- | --- | --- |
| 29.1 `Agent` / `Task` 共享入口 | P0 | BMAD/Claude Code workflow skill 的直接 blocker |
| 29.2 Spawner detection 与过滤 | P0 | 没有 spawner 注入时 `Task` alias 无法运行 |
| 29.3 Direct skill package context | P0 | pipeline skill 必须稳定读取 supporting files |
| 29.4 Tool declaration compatibility | P1 | 避免 MCP/custom/unknown 工具声明被静默丢弃 |
| 29.5 Shared filtering | P1 | 让 skill 与 subagent 工具限制一致 |
| 29.6 Diagnostics | P1 | 防止 deferred 字段造成错误预期 |
| 29.7 Tests and documentation | P0 | SDK 公共语义必须可回归 |

## 关键设计约束

- **不要引入名为 `Task` 的 Swift 类型**：项目规则要求避免与 Swift Concurrency `Task` 冲突；tool 名可以是字符串 `"Task"`。
- **Tools/ 不 import Core/**：`AgentTool.swift` 只能依赖 `ToolContext.agentSpawner` 和 Types 层协议；具体 spawner 仍由 Core 注入。
- **跨平台 Foundation only**：不得引入 macOS-only framework。
- **向后兼容**：现有 `createAgentTool()`、`Skill.toolRestrictions`、`ToolRestrictionStack` 使用者不能无迁移路径地破坏。
- **不静默放权**：任何 parse/filter 失败都不能把 restricted skill/subagent 变成 unrestricted。
- **MCP tool name 保持完整**：`mcp__{serverName}__{toolName}` 必须作为可匹配 tool name 传递。

## 与 Axion Epic 40 的边界

SDK Epic 29 负责：

- `createTaskTool()` alias
- `Agent`/`Task` spawner detection
- child tool pool 默认移除 `Agent`/`Task`
- direct skill package context prompt
- richer tool declarations and shared filtering primitives
- deferred field diagnostics

Axion Epic 40 负责：

- 引用包含 Epic 29 的本地 SDK 源码或发布版本
- 在 Axion `AgentBuilder` 注册 `createAgentTool()` / `createTaskTool()`
- 组装 Axion 普通 chat/run/direct skill 的完整 tool profile
- 把 Axion MCP/Web/Search/domain tools 纳入 profile 和 permission policy
- 在 system prompt 中加入 slash skill guidance
- 用 `/bmad-story-pipeline` 做端到端验收

## 延后项

1. Filesystem subagent definition loader (`.claude/agents/*.md`, `.agents/agents/*.md`)。
2. 完整 MCP server reference lookup from parent config。
3. subagent `skills` 字段的完整 child registry wiring。
4. background/resume/isolation/team runtime semantics。
5. Fine-grained Bash permission pattern enforcement。
6. Host-level permission UI and approval workflow。

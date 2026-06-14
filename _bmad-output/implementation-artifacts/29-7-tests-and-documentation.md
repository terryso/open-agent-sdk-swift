# Story 29.7: Tests and Documentation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an SDK maintainer,
I want the Claude Code skill/subagent compatibility behavior covered by consolidated unit tests, integration-level coverage, and updated docs,
so that host integrations can depend on stable, documented public semantics across the whole Epic 29 surface.

## Context & Scope

**这是 Epic 29（Claude Code Skill/Subagent Compatibility）的第 7 个、也是最后一个 story**，位于依赖图中 29.6 的下游（参见 epic 文档 "Story 间依赖关系" 与 "实现优先级"）。29.1 / 29.2 / 29.3 / 29.4 / 29.5 / 29.6 全部 DONE，本 story 不再新增 runtime 能力——它把整个 Epic 29 的公共语义收敛为可回归的测试覆盖与对宿主开放的文档。

**为什么需要这个 story：**

Epic 29 的 6 个前置 story 都已实现，但当前状态有两个缺口：

1. **测试覆盖是分散的、按-story 粒度的。** 每个 story 在自己的 ATDD red-phase 写了一批针对该 story 单点的单测（例如 29.1 在 `AgentToolTests.swift` 写了 `createTaskTool()` 返回 `name == "Task"`；29.5 在 `ToolDeclarationFilterTests.swift` 写了 `filterToolsByDeclarations` 的逐条匹配规则）。**但缺少跨-feature 的整合测试**——例如"注册 `createTaskTool()` 后，一个 Claude Code 风格 `Task(subagent_type:, prompt:)` 片段端到端走通 spawn→filter→execute→diagnostics 渲染"这种贯穿性用例。Epic 29 目标第 1 条要求"A host registering `createTaskTool()` can run Claude Code-style `Task(...)` workflow snippets per docs examples without additional SDK patching"——**目前没有任何测试证明这条端到端成立**。

2. **DocC 与 cookbook 文档未跟上代码。** 经 grep 确认：
   - `Sources/OpenAgentSDK/Documentation.docc/MultiAgent.md` 仍只出现 `createAgentTool()`（第 16 行），**完全没有** `createTaskTool()` / `Task` alias 的说明。宿主读 DocC 看不到"如何注册 Task 兼容入口"。
   - `docs/cookbook.md` 场景 8（多 Agent 协作编排）与场景 10（Skills 技能系统）**完全没有** `createTaskTool()` / `Task` alias、`allowed-tools` 的 `ToolDeclaration` 富模型、或 deferred field diagnostics 的示例。
   - `MultiAgent.md` 没有提到 `SubAgentLauncherNames`（`Agent`/`Task` 都会被剥离）或 `SubAgentFieldDiagnostics`（deferred 字段如何在输出中显现）。

epic 29.7 的两条 acceptance criteria 明确要求这两块缺口必须闭合：
- "Full SDK test suite passes after this epic is implemented, with the total test count reported in completion notes."
- "A host registering `createTaskTool()` can run Claude Code-style `Task(...)` workflow snippets per docs examples without additional SDK patching."

**本 story 做什么：**

1. **整合性单测（Integration-flavored unit tests，mock-based，rule #27）。** 在现有测试文件**扩展**而非新建（rule #56），新增 `// MARK: - Story 29.7: Epic-End Integration Coverage` 区段，覆盖**贯穿多个 29.x feature 的端到端行为**。这是本 story 的测试主体——不是重写已有的单点单测，而是补**它们之间的接缝**。
2. **可选 E2E 测试（real environment，CLAUDE.md rule）。** 在 `Sources/E2ETest/` 新增一个 E2E 测试文件，证明真实的 `Task(subagent_type: "Explore", prompt: ...)` workflow 片段在注册 `createTaskTool()` 后能端到端跑通。**必须用真实 LLM 环境**（不是 mock）——这是项目级规则（CLAUDE.md: "When writing E2E tests, use the real environment (not mocks)"）。**若 CI/本地无 API key 可用，此 E2E 是 optional 的**（epic 原文："E2E tests are optional"）——dev agent 应在 Task 中标注 optional 并在 Completion Notes 说明跳过原因。
3. **DocC 文档更新。** 更新 `MultiAgent.md`，新增 `Task` alias 章节、`SubAgentLauncherNames` 默认剥离说明、`SubAgentFieldDiagnostics` 诊断区块示例。
4. **Cookbook 示例更新。** 在 `docs/cookbook.md` 场景 8（多 Agent）新增 `createTaskTool()` Claude Code 兼容入口子节；场景 10（Skills）新增 `allowed-tools` 富声明（MCP namespaced / pattern / unknown）子节。
5. **全量回归 + 报告总数。** `swift test` 全量通过，completion notes 记录新的总测试数（baseline: Story 29.6 完成时的 **5787 tests passing**）。

**本 story 不做什么（Out of Scope）：**
- **不重写或迁移** 29.1–29.6 已存在的单点单测（它们在各自 story 的 ATDD 步骤写好并已 green）。本 story 只**新增**整合/回归用例。
- **不改任何 runtime 代码**（Sources/OpenAgentSDK/**）——本 story 是纯测试 + 文档 story。如果某个测试发现 runtime bug，**先记录为 dev note + 不修，开 follow-up**（不扩大本 story 范围）。**唯一例外**：如果 DocC 构建因文档语法报错（如 `<doc>` 链接失效），修文档语法本身算本 story 范围内。
- **不实现 epic 延后项**（filesystem subagent loader、MCP reference 解析、background/resume/isolation/team runtime、child skill registry wiring、Bash pattern 强制）——这些在 epic "延后项" 列出，明确留给后续 epic。
- **不为 deferred 字段实现真实 runtime**——29.6 已明确这些只诊断不接线，本 story 不改这个边界。
- **不改 sprint-status 的 epic-29-retrospective**——retrospective 是独立 story（可选），本 story 完成后 epic-29 status 才由 maintainer 手动改为 `done`。

## Acceptance Criteria

1. **AC1: 整合测试 — `createTaskTool()` alias 行为贯穿 spawn→filter→render**
   - **Given** 本 story 实现完成
   - **When** 检查 `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`
   - **Then** 文件包含 `// MARK: - Story 29.7: Epic-End Integration Coverage` 区段
   - **And** 该区段至少含**1 个**测试，断言：注册 `createTaskTool()` 后，mock spawner 收到的 spawn 调用与注册 `createAgentTool()` 时**完全一致**（相同 prompt、相同 subagent_type、相同 maxTurns 等关键字段）——证明 alias 是真正的共享 factory，而非两份独立实现
   - **And** 该测试用 mock spawner（rule #27），不触发真实 LLM

2. **AC2: 整合测试 — `Task`-only 工具池触发 spawner 注入并默认剥离**
   - **Given** 本 story 实现完成
   - **When** 检查 `Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift`（**复用现有 29.2 测试文件**，rule #56）
   - **Then** 文件包含 `// MARK: - Story 29.7: Task-Only Spawner Detection` 区段
   - **And** 该区段至少含**1 个**测试，断言：工具池**只有** `createTaskTool()`（无 `createAgentTool()`）时，`Agent.createSubAgentSpawner(...)` 返回非 nil spawner（Task-only 也触发检测——29.2 AC1 行为）
   - **And** 至少含**1 个**测试，断言：父工具池同时含 `Agent` 和 `Task` 时，child tool pool **两者都被剥离**（`SubAgentLauncherNames.default == ["Agent", "Task"]`——29.2 AC2 行为）

3. **AC3: 整合测试 — direct skill execution 的 package context + ToolDeclaration 协同**
   - **Given** 本 story 实现完成
   - **When** 检查 `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift`（**复用现有 29.3 测试文件**，rule #56）
   - **Then** 文件包含 `// MARK: - Story 29.7: Package Context Integration` 区段
   - **And** 该区段至少含**1 个**测试，断言：filesystem skill 同时有 `baseDir`、`supportingFiles`、**和** `toolDeclarations`（含 MCP namespaced 名）时，生成的 prompt 同时包含 (a) 绝对 baseDir、(b) supporting file 相对路径、(c) "Skill package context:" 标记——证明 29.3 的 prompt 装配不被 29.4 的 declaration 解析干扰

4. **AC4: 整合测试 — parser/filtering 全声明类型保留**
   - **Given** 本 story 实现完成
   - **When** 检查 `Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift` **或** `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift`（**复用现有 29.4/29.5 测试文件**，rule #56）
   - **Then** 含至少**1 个**整合测试，断言：单个 `allowed-tools` 字符串同时含 MCP namespaced (`mcp__github__list_prs`)、SDK name (`Read`)、pattern (`Bash(git diff:*)`)、unknown (`UnknownTool`) 四种声明时，`SkillLoader.parseToolDeclarations` 全部保留为非 nil 元组（29.4 AC1/AC2），且 `filterToolsByDeclarations` 把 available 池中匹配的留下、不匹配的进 `unmatchedDeclarations`、pattern 进 `patternDeclarations`（29.5 AC3）——**单一测试覆盖四种声明 → parse → filter 全链路**

5. **AC5: 整合测试 — deferred field diagnostics 与 tool filter diagnostics 不互相污染**
   - **Given** 本 story 实现完成
   - **When** 检查 `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`（**复用现有 29.6 测试文件**，rule #56）
   - **Then** 含至少**1 个**整合测试，断言：spawn 同时触发 (a) deferred field diagnostic（如 `run_in_background: true`）**和** (b) tool filter diagnostic（如 `allowedTools` 含未匹配的 `UnknownTool`）时，`SubAgentResult.fieldDiagnostics` 只含字段诊断（不含工具过滤诊断），且 AgentTool output 只渲染字段诊断区块——**证明 29.6 的 `fieldDiagnostics` 与 29.5 的 `ToolFilterDiagnostics` 是独立诊断维度**（29.6 Dev Notes 明确此边界，本 story 用测试固化它）

6. **AC6: E2E 测试（可选，real environment）**
   - **Given** 本 story 实现完成
   - **When** 检查 `Sources/E2ETest/`
   - **Then** **二者之一**成立：
     - (a) 新增一个 E2E 测试文件（如 `SubAgentTaskAliasE2ETests.swift`），含至少**1 个**测试，用真实 LLM 环境（`CODEANY_API_KEY` 或等价 env var）注册 `createTaskTool()`，向 agent 发送一个会触发 `Task(subagent_type: "Explore", prompt: "List files in cwd")` 的 prompt，断言子代理实际执行并返回非空文本——**不允许 mock LLM**（CLAUDE.md rule）
     - (b) **或** dev agent 在 Completion Notes 明确记录"跳过 E2E，原因：[具体原因，如 CI 无 API key / 本地 dry-run]"，并在 File List 标注"E2E skipped per epic 'E2E tests are optional' 条款"
   - **And** 若选 (a)，E2E 测试遵循单 action prompt 原则（CLAUDE.md: "use single-action prompts only — never ask the LLM to perform two actions in one call"）

7. **AC7: DocC `MultiAgent.md` 更新**
   - **Given** 本 story 实现完成
   - **When** 检查 `Sources/OpenAgentSDK/Documentation.docc/MultiAgent.md`
   - **Then** 文档**新增**以下内容（不删除现有内容）：
     - 一个介绍 `createTaskTool()` 作为 `createAgentTool()` 的 Claude Code 兼容 alias 的章节（含 Swift 代码示例：`tools: [...] + [createTaskTool()]`）
     - 一段说明：父工具池含 `Agent` 或 `Task` 任一都会触发 `SubAgentSpawner` 注入；child tool pool 默认剥离两者（`SubAgentLauncherNames.default`）
     - 一段说明 + 示例：当子代理 input 含 deferred 字段（`run_in_background`、`isolation` 等），`SubAgentResult.fieldDiagnostics` 会在 tool 输出中渲染 `[Subagent field "X" ignored: ...]` 区块
   - **And** 文档中所有 ``createAgentTool()`` / ``createTaskTool()`` / ``SubAgentFieldDiagnostics`` 等 symbol 引用使用 DocC 双反引号链接语法（`` ` `` 包裹），保证 `swift package generate-documentation` 不报 unresolved-link 警告

8. **AC8: Cookbook 场景 8（多 Agent）与场景 10（Skills）更新**
   - **Given** 本 story 实现完成
   - **When** 检查 `docs/cookbook.md`
   - **Then** 场景 8（多 Agent 协作编排）新增一个子节（如 `### 8.5 Claude Code 风格 Task alias`），含至少**1 个** Swift 示例展示 `createTaskTool()` 注册与 `Task(subagent_type:, description:, prompt:)` 片段用法
   - **And** 场景 10（Skills 技能系统）新增一个子节（如 `### 10.5 allowed-tools 富声明（MCP / pattern / unknown）`），含至少**1 个**示例展示 frontmatter `allowed-tools: WebSearch, mcp__github__list_prs, Bash(git diff:*)` 如何被解析为 `ToolDeclaration` 数组，并说明 unknown 名不会让 skill 变成 unrestricted
   - **And** cookbook 代码示例遵循现有风格（中文注释、Swift 代码块、`getAllBaseTools(tier: .core)` 等既有 helper）

9. **AC9: Build 与全量回归 — 含总测试数**
   - **Given** 本 story 的所有改动完成
   - **When** `swift build` 和 `swift test` 运行
   - **Then** 构建零新警告，全部测试通过
   - **And** 完成记录中**显式包含**新的总测试数（格式如 "all NNNN tests passing"，baseline 5787）

10. **AC10: DocC 构建无新警告**
    - **Given** 本 story 的 DocC 文档改动完成
    - **When** 运行 `swift package generate-documentation`（或 `swift build` 触发的 docc 警告）
    - **Then** DocC 不因本 story 新增的文档链接报 unresolved symbol 警告
    - **And** 若已存在 DocCBuildTests（`Sources/E2ETest/DocCBuildTests.swift`），该测试继续通过

## Tasks / Subtasks

- [x] Task 1: AC1 — `AgentToolTests.swift` 新增 Epic-End 整合区段（AC: #1）
  - [x] 1.1 打开 `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`，在文件末尾（最后一个 `}` 之前）新增 `// MARK: - Story 29.7: Epic-End Integration Coverage` 区段。
  - [x] 1.2 新增测试 `testCreateTaskTool_aliasSharesSpawnCallSemanticsWithAgent`：
    - 构造两个 mock spawner 实例（复用文件顶部已有的 `MockSubAgentSpawner`，AgentToolTests.swift:9-95）。
    - 分别注册 `createAgentTool()` 和 `createTaskTool()`，用相同 input（`prompt`、`subagent_type`、`description`、`maxTurns`）调用两者。
    - 断言两个 mock spawner 收到的 `lastSpawnPrompt`、`lastSpawnSubagentType`（或等价字段，**先 grep MockSubAgentSpawner 确认字段名**）**完全相等**。
    - 这是整合测试：证明 alias 不是两份独立实现，而是共享 `createSubAgentLauncherTool` factory。
  - [x] 1.3 新增测试 `testCreateTaskTool_spawnerMissingErrorMentionsTask`：注册 `createTaskTool()` 但不注入 spawner（`ToolContext.agentSpawner == nil`），断言 error 文案含 "Task spawner not available"（AgentTool.swift:141 的 `\(name)` interpolation 会产生 "Task"——本测试固化这条错误路径对 alias 也成立）。
  - [x] 1.4 **回归保护**：现有 27 个 AgentToolTests 测试（含 29.1 `createTaskTool` 单点测试、29.6 fieldDiagnostics 渲染测试）全部继续通过——本 task 只**新增**，不改现有。

- [x] Task 2: AC2 — `AgentSpawnerDetectionTests.swift` 新增 Task-only 整合区段（AC: #2）
  - [x] 2.1 打开 `Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift`，在文件末尾新增 `// MARK: - Story 29.7: Task-Only Spawner Detection Integration` 区段。
  - [x] 2.2 新增测试 `testTaskOnlyToolPool_triggersSpawnerInjection`：构造一个**只含 `createTaskTool()`**（无 `createAgentTool()`）的工具池，调用 `Agent.createSubAgentSpawner(...)`，断言返回的 spawner 非 nil（用 `XCTUnwrap`）。**复用**该文件已有的 `makeAgentForSpawnerTest(...)` 或等价 helper（**先 grep 确认 helper 名**）。
  - [x] 2.3 新增测试 `testAgentAndTaskBothPresent_childStripsBothLaunchers`：构造父工具池含 `createAgentTool()` + `createTaskTool()` + 几个普通工具（如 `createReadTool()`），用 `DefaultSubAgentSpawner.filterTools(...)` 过滤，断言 child tool pool **既不含 "Agent" 也不含 "Task"**，但保留 `Read`。这覆盖 29.2 AC2 的整合路径（`SubAgentLauncherNames.default == ["Agent", "Task"]`）。
  - [x] 2.4 **回归保护**：现有 6 个 AgentSpawnerDetectionTests 测试（29.2 red-phase）全部继续通过。

- [x] Task 3: AC3 — `ExecuteSkillStreamTests.swift` 新增 package context 整合区段（AC: #3）
  - [x] 3.1 打开 `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift`，在文件末尾新增 `// MARK: - Story 29.7: Package Context Integration` 区段。
  - [x] 3.2 新增测试 `testFilesystemSkill_withBaseDirAndSupportingFilesAndToolDeclarations_assemblesCompletePrompt`：构造一个 filesystem `Skill`，同时设 `baseDir`、`supportingFiles`、`toolDeclarations`（后者含至少一个 MCP namespaced 名如 `mcp__github__list_prs`）。调用 `executeSkillStream`（用 mock LLM client，rule #27），断言生成的 prompt（捕获 mock client 收到的 messages）**同时**包含：(a) 绝对 baseDir 字符串、(b) supporting file 相对路径、(c) `"Skill package context:"` 标记。**证明 29.3 的 prompt 装配与 29.4 的 declaration 解析互不干扰**。
  - [x] 3.3 **回归保护**：现有 14 个 ExecuteSkillStreamTests 测试（29.3 red-phase）全部继续通过。

- [x] Task 4: AC4 — `ToolDeclarationFilterTests.swift` 新增全声明类型整合测试（AC: #4）
  - [x] 4.1 打开 `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift`，在文件末尾新增 `// MARK: - Story 29.7: Full Declaration Spectrum Integration` 区段。
  - [x] 4.2 新增测试 `testParseAndFilter_allFourDeclarationTypes_preservedAndRouted`：
    - 输入 `allowed-tools` 字符串 `"WebSearch, mcp__github__list_prs, Bash(git diff:*), UnknownTool"`（四种声明）。
    - 调用 `SkillLoader.parseToolDeclarations(input)`（**先 grep 确认 import / 调用方式**——该文件可能需 `import` SkillLoader 或直接用 `ToolDeclaration.parse` 逐 token）。**优先**用 `ToolDeclaration.fromToolNames(...)` 逐个 parse 以避免跨模块 import（ToolDeclarationFilterTests 在 Types/ 目录，SkillLoader 在 Skills/——可能需 `@testable import OpenAgentSDK` 已隐含）。
    - 断言 parse 输出含 4 个 declaration，status 分别为 `.recognizedSDK`（WebSearch）、`.recognizedMCP`（mcp__github__list_prs）、`.recognizedSDK` + pattern（Bash）、`.unknown`（UnknownTool）。
    - 构造 available 工具池含 `WebSearch`、`Bash`、`mcp__github__list_prs`（不含 UnknownTool 对应的工具），调用 `filterToolsByDeclarations`。
    - 断言 filtered 含 3 个（WebSearch、Bash、mcp__github__list_prs），`diagnostics.unmatchedDeclarations` 含 1 个（UnknownTool），`diagnostics.patternDeclarations` 含 1 个（Bash with pattern）。
  - [x] 4.3 **回归保护**：现有 ToolDeclarationFilterTests 测试（29.5 red-phase）全部继续通过。

- [x] Task 5: AC5 — `DefaultSubAgentSpawnerTests.swift` 新增双诊断维度整合测试（AC: #5）
  - [x] 5.1 打开 `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`，在文件末尾新增 `// MARK: - Story 29.7: Dual Diagnostics Integration` 区段。
  - [x] 5.2 新增测试 `testSpawn_runInBackgroundAndUnknownAllowedTool_fieldDiagnosticsOnlyContainFields`：
    - spawn 传入 `runInBackground: true`（触发 29.6 字段诊断）**和** `allowedTools: ["Read", "UnknownTool"]`（触发 29.5 工具过滤诊断：UnknownTool 不匹配）。
    - 断言 `result.fieldDiagnostics` 含**恰好 1 条** `fieldName: "run_in_background"`（**不**含工具过滤维度的诊断——`fieldDiagnostics` 是字段维度专用）。
    - 断言该 spawn 路径的 tool filter diagnostics（29.5 的 `ToolFilterDiagnostics`）**不**出现在 `fieldDiagnostics` 里（**注意**：当前 29.5 spawner filter diagnostics 在 spawner boundary 被丢弃——见 29.6 Dev Notes "Boundary with 29.5"——本测试**不**要求 filter diagnostics 出现，只要求它们**不污染** fieldDiagnostics）。
  - [x] 5.3 新增测试 `testAgentTool_outputWithFieldDiagnostics_doesNotLeakToolFilterInfo`：用 `MockSubAgentSpawner` 注入一个返回 `fieldDiagnostics` 的 `SubAgentResult`，调用 `createTaskTool()` 的执行体，断言 output **只**含字段诊断区块（`[Subagent field "..." ignored: ...]`），**不**含任何 `[Tools used:]` 之外的工具过滤信息。
  - [x] 5.4 **回归保护**：现有 33 个 DefaultSubAgentSpawnerTests 测试（29.2/29.5/29.6 red-phase）全部继续通过。

- [x] Task 6: AC6 — E2E 测试（可选，real environment）（AC: #6）
  - [x] 6.1 **决策点**：检查环境是否支持真实 LLM 调用（env var `CODEANY_API_KEY` 或 `ANTHROPIC_API_KEY` 是否存在，或本地是否有 dry-run 机制）。**参考** `Sources/E2ETest/TestHarness.swift` 与现有 E2E 测试（如 `TaskToolsE2ETests.swift`、`BasicAgentTests.swift`）如何获取 client。
  - [x] 6.2 **若环境支持**：在 `Sources/E2ETest/` 新建 `SubAgentTaskAliasE2ETests.swift`：
    - 注册一个父 agent，工具池含 `createTaskTool()` + `createReadTool()` + `createGlobTool()`。
    - 发送一个**单 action prompt**（CLAUDE.md rule: "single-action prompts only"），如 `"Use the Task tool to spawn an Explore subagent that lists Swift files in the current directory. Return the subagent's output."`
    - 断言：父 agent 的响应非空，且含子代理实际执行后的文本（非 error，非 "spawner not available"）。
    - **不允许 mock LLM**——必须真实网络调用。
  - [x] 6.3 **若环境不支持**（无 API key / CI 受限）：在 File List 标注 `Sources/E2ETest/SubAgentTaskAliasE2ETests.swift` **未创建**（或创建一个 `XCTSkip`-style 占位），在 Completion Notes 明确记录"E2E skipped per epic 29.7 'E2E tests are optional' clause; reason: [具体原因]"。**不要**为了过 AC 而写 mock-based E2E（违反 CLAUDE.md rule）。
  - [x] 6.4 **若新增 E2E**：把它注册到 `Sources/E2ETest/main.swift` 的 test runner dispatch（**先 Read main.swift 确认注册模式**）。

- [x] Task 7: AC7 — DocC `MultiAgent.md` 更新（AC: #7）
  - [x] 7.1 Read `Sources/OpenAgentSDK/Documentation.docc/MultiAgent.md` 全文（确认现有结构与 symbol 链接风格）。
  - [x] 7.2 在 "Sub-Agent Spawning" 章节后（约第 36 行后），新增 `## Task Tool: Claude Code-Compatible Alias` 章节：
    - 说明 `createTaskTool()` 是 `createAgentTool()` 的 alias，共享 schema、执行体、输出格式。
    - 含 Swift 示例：`let agent = createAgent(options: AgentOptions(tools: [...] + [createTaskTool()]))`。
    - 说明 Claude Code 风格 `Task(subagent_type:, description:, prompt:)` 片段注册此 tool 后即可运行。
  - [x] 7.3 新增 `## Spawner Detection and Launcher Filtering` 章节（或并入上一节）：
    - 说明父工具池含 `Agent` **或** `Task` 任一都会触发 `SubAgentSpawner` 注入。
    - 说明 child tool pool 默认剥离两者（`SubAgentLauncherNames.default == ["Agent", "Task"]`），避免递归派生。
    - 链接到 ``SubAgentLauncherNames`` symbol（若 public——**先 grep 确认可见性**；若 internal 则用普通反引号不链接）。
  - [x] 7.4 新增 `## Deferred Field Diagnostics` 章节（或并入 Sub-Agent Spawning）：
    - 说明当子代理 input 含 `run_in_background`、`isolation`、`team_name`、`resume`、`skills`、或 MCP server reference 时，SDK 当前**接受但未完整接线**这些字段。
    - 说明这些字段会在 `SubAgentResult.fieldDiagnostics` 中产生诊断，并在 tool 输出中渲染为 `[Subagent field "X" ignored: <reason> (raw value: Y)]` 区块。
    - 链接到 ``SubAgentFieldDiagnostics`` / ``SubAgentFieldDiagnosticReason`` symbol（已在 `OpenAgentSDK.swift` 导出，DocC 可解析）。
  - [x] 7.5 **DocC 链接语法**：所有 SDK symbol 用双反引号 `` `createTaskTool()` `` 形式（DocC 会解析为链接）。**验证**：运行 `swift package generate-documentation` 或 `swift build`（后者会触发 docc 诊断），确认无 unresolved-link 警告。**若 DocCBuildTests**（`Sources/E2ETest/DocCBuildTests.swift`）存在且会被 E2E runner 触发，确保它通过。

- [x] Task 8: AC8 — Cookbook 场景 8 与场景 10 更新（AC: #8）
  - [x] 8.1 Read `docs/cookbook.md` 场景 8（约 `## 场景 8` 到 `## 场景 9`）与场景 10（`## 场景 10` 到 `## 场景 11`）全文，确认现有子节编号（如 8.1-8.4、10.1-10.4）。
  - [x] 8.2 在场景 8 末尾（`## 场景 9` 之前）新增 `### 8.5 Claude Code 风格 Task alias`：
    - 说明 `createTaskTool()` 是 `createAgentTool()` 的 Claude Code 兼容 alias。
    - 含 Swift 示例：注册 `createTaskTool()`，发送会触发 `Task(subagent_type: "Explore", prompt: ...)` 的 prompt。
    - 说明适用场景：移植 Claude Code workflow skill（含 `Task(...)` 片段）到 OpenAgentSDK 时无需改 prompt。
  - [x] 8.3 在场景 10 末尾（`## 场景 11` 之前）新增 `### 10.5 allowed-tools 富声明（MCP / pattern / unknown）`：
    - 说明 frontmatter `allowed-tools` 现支持四种声明：SDK name、MCP namespaced (`mcp__server__tool`)、pattern (`Bash(git diff:*)`)、unknown。
    - 含 frontmatter 示例：`allowed-tools: WebSearch, mcp__github__list_prs, Bash(git diff:*), UnknownTool`。
    - 说明 unknown 名**不会**让 skill 变成 unrestricted（epic "不静默放权" 红线）；它们被保留为 `ToolDeclaration(status: .unknown)` 并可通过 `Skill.toolDeclarationDiagnostics` 观察。
    - 简述 pattern 当前"parsed but not enforced"（fine-grained Bash pattern enforcement 是延后项）。
  - [x] 8.4 **风格一致性**：中文注释、Swift 代码块、复用现有 helper（`getAllBaseTools(tier:)`、`createAgent(options:)` 等）。

- [x] Task 9: AC9 + AC10 — Build、全量回归、DocC 验证（AC: #9, #10）
  - [x] 9.1 `swift build` 成功，零新警告。
  - [x] 9.2 `swift test` 全量通过；**记录新的总测试数**（baseline 5787，预期新增约 6-10 个整合测试）。
  - [x] 9.3 `swift package generate-documentation`（或等价命令）无 unresolved-link 警告。**若 DocCBuildTests 存在**，确保它通过。
  - [x] 9.4 在 Completion Notes 写明："all NNNN tests passing"（NNNN = 实际总数）。

## Dev Notes

### ATDD Artifacts

- **本 story 不强制 ATDD red-phase**（它是测试+文档 story，不是 runtime feature story）。dev agent 可直接写 green 测试。**若**项目 BMAD pipeline 要求 ATDD 步骤先跑（bmad-testarch-atdd skill），dev agent 应在 `Tests/.../` 各文件新增的 `// MARK: - Story 29.7` 区段先写**会 fail 的骨架测试**（如 `XCTFail("not implemented")` 或引用尚不存在的 helper），跑一次确认 red，再实现到 green。**但**由于本 story 测试目标是**已存在的** runtime 行为（29.1-29.6 已实现），测试一开始就是 green——dev agent 应在 ATDD checklist 中说明"本 story 测试验证已实现行为，无 red phase"。

### Architecture Context

这是 **Epic 29 的最后一个 story**，依赖图中位置：

```
29.1 (DONE) --> 29.2 (DONE) --> 29.3 (DONE) --> 29.4 (DONE) --> 29.5 (DONE) --> 29.6 (DONE)
                                                                                          |
                                                                                          +--> 29.7 (THIS STORY)  ← tests + docs consolidation
                                                                                                  |
                                                                                                  +--> epic-29 done (manual)
                                                                                                  +--> epic-29-retrospective (optional, separate)
```

29.7 是 Epic 29 的**收口 story**：不新增 runtime 能力，把整个 epic 的公共语义固化为可回归测试 + 对宿主开放的文档。完成后 maintainer 手动把 `sprint-status.yaml` 的 `epic-29: in-progress → done`。

### CRITICAL: 当前测试覆盖事实（必须先读，避免重复造轮子）

**Epic 29 的 6 个前置 story 已在各自 ATDD red-phase 写了大量单点单测，它们目前全部 green。** 本 story **不是**重写这些测试，而是补**它们之间的整合接缝**。已存在的覆盖（**不要重复**）：

| Story | 测试文件 | 已有测试数 | 覆盖内容 |
|-------|---------|-----------|---------|
| 29.1 | `AgentToolTests.swift` | 5 (29.1 区段) | `createTaskTool()` 返回 name=="Task"、schema 一致、public surface 回归 |
| 29.2 | `AgentSpawnerDetectionTests.swift` + `DefaultSubAgentSpawnerTests.swift` | 6 + N | `SubAgentLauncherNames.default` 含 Agent/Task、filterTools 剥离两者、Task-only 检测 |
| 29.3 | `ExecuteSkillStreamTests.swift` | 14 | package context prompt 装配（baseDir、supportingFiles、programmatic 回退） |
| 29.4 | `SkillLoaderTests.swift` | 15+ (29.4 区段) | `parseToolDeclarations` 保留 MCP/pattern/unknown、不 collapse to unrestricted |
| 29.5 | `ToolDeclarationFilterTests.swift` + `DefaultSubAgentSpawnerTests.swift` | N + N | `filterToolsByDeclarations` 匹配规则、`ToolFilterDiagnostics`、fromToolNames |
| 29.6 | `DefaultSubAgentSpawnerTests.swift` + `AgentToolTests.swift` | 13 + 5 | `collectFieldDiagnostics`、`SubAgentResult.fieldDiagnostics`、AgentTool 渲染 |

**本 story 要补的缺口**（这些是单点单测**没有**覆盖的）：
1. **跨-feature 端到端**：注册 `createTaskTool()` → spawn → filter → diagnostics 渲染的**整条链路**单测（AC1-AC5）。
2. **真实环境 E2E**（AC6，optional）。
3. **文档**（AC7-AC8）—— DocC 与 cookbook 完全没跟上 29.x。

### CRITICAL: 当前文档缺口（必须先读）

**1. `Sources/OpenAgentSDK/Documentation.docc/MultiAgent.md`（233 行）现状：**
- 第 16 行：`tools: getAllBaseTools(tier: .core) + [createAgentTool()]`——**只** `createAgentTool()`，无 `createTaskTool()`。
- 全文 grep `createTaskTool` → **0 命中**。
- 全文 grep `SubAgentLauncherNames` → **0 命中**。
- 全文 grep `SubAgentFieldDiagnostics` → **0 命中**。
- 全文 grep `fieldDiagnostics` → **0 命中**。

**2. `docs/cookbook.md`（2031 行）现状：**
- 场景 8（多 Agent，约 8.1-8.4）：全 grep `createTaskTool` → **0 命中**；`Task alias` → **0 命中**。
- 场景 10（Skills，约 10.1-10.4）：全 grep `ToolDeclaration` → **0 命中**；`mcp__` → **0 命中**；`allowed-tools` 只在 10.2 出现一次（`toolRestrictions: [.read, .glob, .grep]`——是 enum 形式，不是 frontmatter 字符串形式）。

**3. `OpenAgentSDK.swift` 公共导出已就绪**（无需改）：
- 第 59-60 行：`SubAgentFieldDiagnostics` / `SubAgentFieldDiagnosticReason` 已索引。
- 第 62-63 行：`createAgentTool()` / `createTaskTool()` 已索引。
- 第 128-132 行：`ToolDeclaration` / `ToolDeclarationStatus` / `ToolDeclarationDiagnostics` / `ToolFilterDiagnostics` / `filterToolsByDeclarations` 已索引。
- 这些 symbol DocC 都能解析（双反引号链接语法可用）。

### 测试文件选择决策（rule #56 复用现有文件）

本 story **不新建测试文件**（除 optional E2E），全部在现有文件**扩展**：

| AC | 测试文件 | 理由 |
|----|---------|------|
| AC1 | `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` | 已含 29.1 `createTaskTool` 单点测试 + 29.6 渲染测试，本 story 整合测试同属 AgentTool 行为 |
| AC2 | `Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift` | 已含 29.2 `SubAgentLauncherNames` 检测测试，Task-only 整合同属检测路径 |
| AC3 | `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift` | 已含 29.3 package context 测试 |
| AC4 | `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift` | 已含 29.5 filter 测试；全声明类型整合用 `ToolDeclaration.parse` / `fromToolNames` + `filterToolsByDeclarations`（都在 Types/，无需跨模块） |
| AC5 | `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` | 已含 29.2/29.5/29.6 spawner 测试 |
| AC6 | `Sources/E2ETest/SubAgentTaskAliasE2ETests.swift`（**新建，optional**） | E2E 测试惯例在 `Sources/E2ETest/`（rule #29） |

### E2E 决策树（AC6）

```
检查环境是否有真实 LLM access（CODEANY_API_KEY / ANTHROPIC_API_KEY / TestHarness 支持）
├── 有 → 新建 SubAgentTaskAliasE2ETests.swift，写真实 LLM E2E（单 action prompt）
│        ├── 注册到 main.swift test runner
│        └── 跑通，记录到 Completion Notes
└── 无 → 在 Completion Notes 明确记录"E2E skipped per epic 29.7 'E2E tests are optional'"
         File List 标注 E2E 文件未创建
         **不要**写 mock-based E2E（违反 CLAUDE.md rule）
```

**参考现有 E2E 模式**：`Sources/E2ETest/TestHarness.swift`（共享 client 获取）、`Sources/E2ETest/TaskToolsE2ETests.swift`（3 个 E2E 测试，看它如何注册到 main.swift）、`Sources/E2ETest/BasicAgentTests.swift`（最简 E2E 模式）。

### 模块边界合规性（project-context.md #7）

- 整合测试在 `Tests/OpenAgentSDKTests/{Tools/Advanced,Core,Types}/` —— ✅ 测试可 `@testable import OpenAgentSDK` 访问所有 internal。
- E2E 测试在 `Sources/E2ETest/` —— ✅ 独立 executable target，复用 `TestHarness.swift`。
- DocC 文档在 `Sources/OpenAgentSDK/Documentation.docc/` —— ✅ DocC 自动发现。
- Cookbook 在 `docs/` —— ✅ 纯 markdown，无构建约束。
- **不改** `Sources/OpenAgentSDK/**` 任何 runtime 代码（本 story 是纯测试+文档 story）。

### Anti-Patterns to Avoid (project-context.md + CLAUDE.md)

- ❌ **不要重写或迁移 29.1-29.6 已存在的单点单测** —— 它们已 green，本 story 只**新增**整合测试（rule #56 复用现有文件）。
- ❌ **不要为过 AC 而写 mock-based E2E** —— CLAUDE.md rule: "When writing E2E tests, use the real environment (not mocks). Do not create mock-based tests for E2E test files." 若环境不支持真实 LLM，**跳过 E2E 并记录原因**（epic 明确 E2E optional）。
- ❌ **不要在 E2E 测试用 multi-action prompt** —— CLAUDE.md rule: "use single-action prompts only — never ask the LLM to perform two actions in one call"。
- ❌ **不要改 runtime 代码** —— 本 story 是纯测试+文档 story。若测试发现 runtime bug，记录为 dev note + 开 follow-up，不扩大范围。
- ❌ **不要 force-unwrap (`!`)** —— rule #40，用 guard let / if let / `XCTUnwrap`。
- ❌ **不要新建独立单测文件**（除 optional E2E）—— 全部扩展现有文件（rule #56）。
- ❌ **不要在 DocC 用未导出的 symbol 做双反引号链接** —— 会触发 unresolved-link 警告。**先确认 symbol 在 `OpenAgentSDK.swift` 已导出**（已确认：`createTaskTool`、`SubAgentFieldDiagnostics`、`SubAgentFieldDiagnosticReason`、`ToolDeclaration`、`filterToolsByDeclarations` 等都在）。`SubAgentLauncherNames` 若是 internal，用普通反引号（单 `）不链接。
- ❌ **不要忘记记录总测试数** —— AC9 显式要求 completion notes 含 "all NNNN tests passing"。
- ❌ **不要把本 story 当成 retrospective** —— retrospective 是独立 optional story，本 story 完成后 epic-29 才由 maintainer 手动改 done。
- ❌ **不要内联构建 JSONEncoder/JSONDecoder** —— rule #48，用 `EnvUtils.swift` 共享工厂（若测试需要）。
- ❌ **不要手写 tempDir setUp/tearDown** —— rule #50，继承 `TempDirTestCase`（若整合测试需要临时目录）。

### Testing Standards

- XCTest only（rule #23）。
- 单测目录镜像源码（rule #24）。
- mock client 用于涉及 LLM 的整合测试（rule #27）—— 复用 `MockSubAgentSpawner`（AgentToolTests.swift:9-95）、`DefaultSubAgentSpawnerTests` 现有 mock client 模式。
- E2E 用真实环境（CLAUDE.md rule）—— 若不可用则跳过。
- 整合测试优先用 mock 驱动（不触发真实网络），保证 CI 稳定。
- **不补 E2E 到每个 AC**——AC6 是单个 optional E2E，AC1-AC5 是 mock-based 整合单测。
- 全量 `swift test` 必须通过（AC9）。

### Previous Story Intelligence (Story 29.6)

Story 29.6（commit 1c38f6d）完成于 2026-06-14，**5787 tests passing**（baseline）。关键学习对本 story 适用：

- **"诊断双维度边界"已用 Dev Notes 固化，本 story 用测试进一步锁定** —— 29.6 Dev Notes 明确 `SubAgentFieldDiagnostics`（字段维度）与 `ToolFilterDiagnostics`（工具过滤维度）独立。本 story AC5 新增整合测试证明两者不互相污染——把 Dev Notes 的文字约定升级为可回归测试。
- **"mock spawner 可注入 fieldDiagnostics"模式** —— 29.6 给 `MockSubAgentSpawner` 加了 `makeWithDiagnostics(...)` helper（AgentToolTests.swift）。本 story AC1/AC5 复用此 helper 构造整合测试场景。
- **"全量测试数记录"惯例** —— 29.6 Completion Notes 记录 "5787 tests passing"。本 story 沿用此格式，更新为新增后的总数。

### Previous Story Intelligence (Stories 29.1-29.5)

- **29.1**（commit 923bd6b）：`createTaskTool()` alias。本 story AC1 证明 alias 共享 factory（不是两份实现）。
- **29.2**（commit 5dd0ea2）：`SubAgentLauncherNames`。本 story AC2 整合 Task-only 检测 + 双 launcher 剥离。
- **29.3**（commit dc49d54）：skill package context。本 story AC3 整合 package context + toolDeclarations 协同。
- **29.4**（commit 6715e80）：`ToolDeclaration` 模型。本 story AC4 整合四种声明 → parse → filter 全链路。
- **29.5**（commit fe501a1）：`filterToolsByDeclarations` + `ToolFilterDiagnostics`。本 story AC4/AC5 复用。

### Git Intelligence (recent commits)

```
1c38f6d feat(core): surface diagnostics for deferred subagent fields (Story 29-6)
fe501a1 feat(core): unify skill and subagent tool filtering via shared declarations (Story 29-5)
6715e80 feat(skills): add lossless ToolDeclaration compatibility model (Story 29-4)
dc49d54 feat(core): inject skill package context into direct skill execution (Story 29-3)
fbf001c fix(core): propagate sub-agent toolCalls from QueryResult.toolPairs
ee158e9 chore: add BMAD agent workspace config (skills, hooks, AGENTS.md)
5dd0ea2 feat(core): unify Agent/Task spawner detection and child filtering (Story 29-2)
923bd6b feat(tools): add createTaskTool() as Claude Code Task alias (Story 29-1)
```

Epic 29 全部 6 个前置 story 已 commit。本 story 是 epic 收口，无上游 blocker。

### Latest Technical Information

- **Swift 5.9+ / XCTest** —— 整合测试用 `async throws` + `XCTUnwrap` / `XCTAssertEqual` / `XCTAssertNotNil`。
- **DocC 链接语法** —— `` `SymbolName` `` 双反引号解析为 link；单反引号 `` `SymbolName` `` 不解析（用于 internal symbol 或纯代码字体）。DocC 构建 `swift package generate-documentation` 或 `swift package preview-documentation`。
- **E2E target** —— `Sources/E2ETest/` 是独立 executable（`main.swift` 是 entry point），通过 `TestHarness.swift` 获取真实 LLM client。注册新 E2E 到 `main.swift` 的 dispatch。
- **不引入新外部依赖** —— 本 story 只用 Foundation + XCTest + 现有 SDK API。

### Files to Modify/Create

- **MODIFY (追加测试)**: `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`
  - 新增 `// MARK: - Story 29.7: Epic-End Integration Coverage` 区段（Task 1）
- **MODIFY (追加测试)**: `Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift`
  - 新增 `// MARK: - Story 29.7: Task-Only Spawner Detection Integration` 区段（Task 2）
- **MODIFY (追加测试)**: `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift`
  - 新增 `// MARK: - Story 29.7: Package Context Integration` 区段（Task 3）
- **MODIFY (追加测试)**: `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift`
  - 新增 `// MARK: - Story 29.7: Full Declaration Spectrum Integration` 区段（Task 4）
- **MODIFY (追加测试)**: `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`
  - 新增 `// MARK: - Story 29.7: Dual Diagnostics Integration` 区段（Task 5）
- **CREATE (optional)**: `Sources/E2ETest/SubAgentTaskAliasE2ETests.swift`
  - 仅当环境支持真实 LLM（Task 6 决策点）
  - 若创建，**MODIFY** `Sources/E2ETest/main.swift` 注册到 dispatch
- **MODIFY (文档)**: `Sources/OpenAgentSDK/Documentation.docc/MultiAgent.md`
  - 新增 Task alias / Spawner Detection / Deferred Field Diagnostics 章节（Task 7）
- **MODIFY (文档)**: `docs/cookbook.md`
  - 场景 8 新增 `### 8.5 Claude Code 风格 Task alias`（Task 8.2）
  - 场景 10 新增 `### 10.5 allowed-tools 富声明（MCP / pattern / unknown）`（Task 8.3）

**不修改（验证无回归）：**
- `Sources/OpenAgentSDK/**` 任何 runtime 代码（本 story 是纯测试+文档 story）
- `Sources/OpenAgentSDK/OpenAgentSDK.swift`（公共导出已就绪，无需改）
- 29.1-29.6 已存在的单点单测（本 story 只新增整合测试）

### Dependencies and Blockers

**Upstream (DONE):**
- Story 29.1 (`createTaskTool()`) — DONE，commit 923bd6b。
- Story 29.2 (`SubAgentLauncherNames`) — DONE，commit 5dd0ea2。
- Story 29.3 (skill package context) — DONE，commit dc49d54。
- Story 29.4 (`ToolDeclaration` model) — DONE，commit 6715e80。
- Story 29.5 (`filterToolsByDeclarations` + `ToolFilterDiagnostics`) — DONE，commit fe501a1。
- Story 29.6 (`SubAgentFieldDiagnostics`) — DONE，commit 1c38f6d。**5787 tests baseline**。

**Downstream (本 story 解锁):**
- `epic-29: in-progress → done`（maintainer 手动改 sprint-status.yaml）。
- `epic-29-retrospective`（optional，独立 story，本 story 不做）。
- Axion Epic 40 (`/bmad-story-pipeline` integration) 可消费已文档化、已测试的 Epic 29 公共语义。

**No blockers remain.**

### Out of Scope (Deferred to Later Stories / Epics)

- Epic 29 延后项全部 6 项（filesystem subagent loader、MCP reference 解析、background/resume/isolation/team runtime、child skill registry wiring、Bash pattern 强制、permission UI）→ epic 延后项，本 story 不动。
- 把 `ToolFilterDiagnostics`（29.5）也暴露到 `SubAgentResult`（合并双诊断维度）→ follow-up（29.6 Dev Notes 已说明命名清晰区分已足够）。
- Epic 29 retrospective → 独立 optional story（`bmad-retrospective` skill）。
- 为 Epic 29 全部 6 个 feature 各写一个 E2E → 本 story 只 1 个 optional E2E（AC6），其余用 mock-based 整合单测覆盖。

### References

- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#Story 29.7] — story 定义、2 个 AC、实施步骤（createTaskTool alias 测试、Task filtering 测试、package context 测试、parser/filtering 测试、DocC + cookbook 更新、E2E optional）
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#目标] — 目标第 1 条："提供 Task 兼容入口"；第 6 条："保持宿主可组合"
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#实现优先级] — 29.7 优先级 P0："SDK 公共语义必须可回归"
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#Story 间依赖关系] — 29.7 位于 29.6 下游，是 epic 收口
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#关键设计约束] — 不静默放权、向后兼容、MCP tool name 完整
- [Source: _bmad-output/implementation-artifacts/29-6-diagnostics-deferred-subagent-fields.md] — Story 29.6 完成记录（5787 tests, commit 1c38f6d），双诊断维度边界（Dev Notes "Boundary with 29.5 ToolFilterDiagnostics"），`MockSubAgentSpawner.makeWithDiagnostics` helper
- [Source: _bmad-output/implementation-artifacts/29-5-shared-filtering-skills-subagents.md] — Story 29.5 完成记录，`filterToolsByDeclarations` + `ToolFilterDiagnostics` 模式
- [Source: _bmad-output/implementation-artifacts/29-4-tool-declaration-compatibility-model.md] — Story 29.4 完成记录，`ToolDeclaration` 四种 status
- [Source: _bmad-output/implementation-artifacts/29-3-direct-skill-package-context.md] — Story 29.3 完成记录，package context prompt 装配
- [Source: _bmad-output/implementation-artifacts/29-2-spawner-detection-child-filtering.md] — Story 29.2 完成记录，`SubAgentLauncherNames`
- [Source: _bmad-output/implementation-artifacts/29-1-agent-task-shared-subagent-launcher.md] — Story 29.1 完成记录，`createSubAgentLauncherTool` 共享 factory
- [Source: _bmad-output/project-context.md#23] — 测试框架 XCTest，目录镜像源码
- [Source: _bmad-output/project-context.md#24] — 测试组织 `Tests/OpenAgentSDKTests/{Core,Tools,...}/`
- [Source: _bmad-output/project-context.md#27] — 单元测试 mock 外部 API
- [Source: _bmad-output/project-context.md#29] — 故事完成后必须补充 E2E 测试（E2E 在 `Sources/E2ETest/`）
- [Source: _bmad-output/project-context.md#40] — 无 force-unwrap
- [Source: _bmad-output/project-context.md#48] — 不内联 JSONEncoder/Decoder
- [Source: _bmad-output/project-context.md#50] — 测试继承 TempDirTestCase
- [Source: _bmad-output/project-context.md#56] — 复用共享测试基础设施
- [Source: CLAUDE.md#Testing Rules] — E2E 用真实环境不用 mock；单 action prompt；改一处查兄弟路径
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:131-189] — `createSubAgentLauncherTool` 共享 factory（AC1 整合测试目标）
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:203-226] — `createAgentTool()` / `createTaskTool()` public factories
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:35-96] — `AgentToolInput` schema（含 deferred 字段）
- [Source: Sources/OpenAgentSDK/Types/ToolDeclaration.swift:62-282] — `ToolDeclaration` 模型 + `parse(_:)` + `fromToolNames(_:)`（AC4 整合测试目标）
- [Source: Sources/OpenAgentSDK/Types/ToolDeclaration.swift:284-434] — `ToolFilterOptions` / `ToolFilterDiagnostics` / `filterToolsByDeclarations`（AC4/AC5 整合测试目标）
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — `SubAgentFieldDiagnostics` / `SubAgentFieldDiagnosticReason` / `SubAgentResult.fieldDiagnostics`（AC5 整合测试目标）
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift] — `collectFieldDiagnostics` / `filterTools` / `mapQueryResultToSubAgentResult`（AC5 整合测试目标）
- [Source: Sources/OpenAgentSDK/OpenAgentSDK.swift:59-63,128-132] — 公共导出已索引（DocC 链接可用）
- [Source: Sources/OpenAgentSDK/Documentation.docc/MultiAgent.md] — DocC 文档现状（缺 Task alias / SubAgentLauncherNames / fieldDiagnostics）
- [Source: docs/cookbook.md] — Cookbook 现状（场景 8/10 缺 Epic 29 内容）
- [Source: Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift:9-95,599-760] — `MockSubAgentSpawner` + 29.1/29.6 测试区段（本 story 扩展点）
- [Source: Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift:1-200] — 29.2 检测测试（本 story 扩展点）
- [Source: Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift:254-1143] — 29.2/29.5/29.6 spawner 测试（本 story 扩展点）
- [Source: Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift:211-520] — 29.3 package context 测试（本 story 扩展点）
- [Source: Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift:1-360] — 29.5 filter 测试（本 story 扩展点）
- [Source: Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift:588-910] — 29.4 parser 测试（AC4 备选扩展点）
- [Source: Sources/E2ETest/TestHarness.swift] — E2E 共享 client 获取（AC6 参考）
- [Source: Sources/E2ETest/main.swift] — E2E test runner dispatch（AC6 注册点）
- [Source: Sources/E2ETest/TaskToolsE2ETests.swift] — 现有 E2E 模式参考（AC6）
- [Source: Sources/E2ETest/DocCBuildTests.swift] — DocC 构建测试（AC10 回归保护）

## Dev Agent Record

### Agent Model Used

Claude Code (bmad-dev-story skill, yolo mode)

### Debug Log References

- `swift build` — Build complete!, zero new warnings (exit 0).
- `swift test --filter <8 new integration tests>` — 8 passed, 0 failures, 0.388s.
- `swift test` (full suite) — **5795 tests passing**, 0 failures (38.144s). Baseline 5787 (Story 29.6) + 8 new integration tests = 5795.
- `swift package generate-documentation` — exit 0; 0 warnings attributable to this story's MultiAgent.md edits (Task Tool / Spawner Detection / Deferred Field Diagnostics sections). 87 pre-existing warnings remain (Hummingbird `MaximumAvailableConnections`, MCPCore resolution, and Stories 29.4–29.6 source-level doc comments referencing `filterToolsByDeclarations` / `shortHumanReadableText`) — all out of scope per "不改 runtime 代码" story rule.

### Completion Notes List

- **AC1–AC5 (integration tests): DONE.** The 8 ATDD integration tests (written in the prior ATDD red-phase step, green on first run against current main) cover the cross-feature seams: alias shared factory (AC1), Task-only spawner injection + dual-launcher stripping (AC2), package-context + toolDeclarations coexistence (AC3), full four-declaration parse→filter chain (AC4), and dual diagnostic dimension boundary (AC5). All 8 verified passing in isolation and as part of the full suite.
- **AC6 (E2E): SKIPPED per epic clause.** E2E skipped per epic 29.7 "E2E tests are optional" clause; reason: no `CODEANY_API_KEY` / `ANTHROPIC_API_KEY` available in the environment. No mock-based E2E was written (CLAUDE.md rule: "Do not create mock-based tests for E2E test files"). No file created under `Sources/E2ETest/`.
- **AC7 (DocC MultiAgent.md): DONE.** Added 3 new sections after "Sub-Agent Spawning": `## Task Tool: Claude Code-Compatible Alias`, `## Spawner Detection and Launcher Filtering`, `## Deferred Field Diagnostics`. Used double-backtick DocC link syntax for exported symbols (`` `createTaskTool()` ``, `` `createAgentTool()` ``, `` `SubAgentFieldDiagnostics` ``, `` `SubAgentFieldDiagnosticReason` ``, `` `SubAgentResult/fieldDiagnostics` ``, `` `filterToolsByDeclarations(available:allowed:disallowed:options:)` ``, `` `ToolFilterDiagnostics` ``). `SubAgentLauncherNames` is an internal `enum`, so it is referenced with single-backtick code formatting (NOT a DocC link) to avoid unresolved-link warnings.
- **AC8 (cookbook scenarios 8 + 10): DONE.** Added `### 8.6 Claude Code 风格 Task alias` (note: used 8.6, not 8.5 as the spec suggested, because 8.5 was already occupied by AgentRegistry — checked sibling numbering per CLAUDE.md rule) and `### 10.5 allowed-tools 富声明（MCP / pattern / unknown）`. Both follow existing cookbook style: Chinese prose, Swift code blocks, reused helpers (`getAllBaseTools(tier:)`, `createAgent(options:)`, `filterToolsByDeclarations`).
- **AC9 (build + full regression): DONE.** `swift build` zero new warnings; **all 5795 tests passing** (baseline 5787 + 8 new = 5795, matching ATDD checklist prediction exactly).
- **AC10 (DocC no new warnings): DONE.** `swift package generate-documentation` exit 0. Zero warnings from this story's MultiAgent.md edits (verified by grepping DocC output for the new section titles and `createTaskTool` — 0 matches in warning lines). DocCBuildTests.swift compiles cleanly as part of the E2ETest target and its runtime check (exit code 0) is satisfied.
- **Scope discipline:** No `Sources/OpenAgentSDK/**` runtime code modified (verified via `git diff` — only MultiAgent.md, cookbook.md, sprint-status.yaml, and the 5 pre-existing test files changed). The pre-existing DocC warnings in `AgentTypes.swift` and `ToolDeclaration.swift` source doc comments (from Stories 29.4–29.6) were observed but NOT fixed, per the "不改 runtime 代码" rule — flagged here for a future cleanup story.
- **Epic 29 closing note:** This is the last story of Epic 29. With it complete, the maintainer can manually flip `sprint-status.yaml`'s `epic-29: in-progress → done`. The optional `epic-29-retrospective` is a separate story.

### File List

**Tests (extended, not created — project-context rule #56):**
- `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` — added `// MARK: - Story 29.7: Epic-End Integration Coverage` section (2 tests: AC1.a alias-shared-spawn-semantics, AC1.b spawner-missing-error-mentions-Task).
- `Tests/OpenAgentSDKTests/Core/AgentSpawnerDetectionTests.swift` — added `// MARK: - Story 29.7: Task-Only Spawner Detection Integration` section (2 tests: AC2.a Task-only triggers spawner injection, AC2.b Agent+Task both stripped from child pool).
- `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift` — added `// MARK: - Story 29.7: Package Context Integration` section (1 test: AC3.a baseDir + supportingFiles + toolDeclarations coexistence).
- `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift` — added `// MARK: - Story 29.7: Full Declaration Spectrum Integration` section (1 test: AC4.a four declaration types parse→filter single chain).
- `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` — added `// MARK: - Story 29.7: Dual Diagnostics Integration` section (2 tests: AC5.a run_in_background + UnknownTool field-only diagnostics, AC5.b AgentTool output does not leak tool-filter info).

**Documentation (modified):**
- `Sources/OpenAgentSDK/Documentation.docc/MultiAgent.md` — added 3 new sections (Task Tool alias, Spawner Detection and Launcher Filtering, Deferred Field Diagnostics) after the Sub-Agent Spawning section.
- `docs/cookbook.md` — added `### 8.6 Claude Code 风格 Task alias` to scenario 8 and `### 10.5 allowed-tools 富声明（MCP / pattern / unknown）` to scenario 10.

**Story tracking (modified):**
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `29-7-tests-and-documentation: ready-for-dev → review`; `last_updated` bumped.
- `_bmad-output/implementation-artifacts/29-7-tests-and-documentation.md` — Status, Tasks/Subtasks checkboxes, Dev Agent Record, File List, Change Log updated.

**NOT created (E2E skipped):**
- `Sources/E2ETest/SubAgentTaskAliasE2ETests.swift` — NOT created (AC6 skipped: no API key in environment).
- `Sources/E2ETest/main.swift` — NOT modified (no new E2E test to register).

**NOT modified (scope discipline):**
- `Sources/OpenAgentSDK/**` — zero runtime code changes (pure tests + docs story).

## Change Log

| Date       | Version | Description                                                                                                          | Author       |
|------------|---------|----------------------------------------------------------------------------------------------------------------------|--------------|
| 2026-06-14 | 0.1     | Initial story creation (Story 29.7 of Epic 29 — Tests and Documentation, epic收口 story).                            | create-story |
| 2026-06-14 | 0.2     | Dev-story implementation: 8 ATDD integration tests verified (AC1-AC5), E2E skipped (AC6, no API key), DocC MultiAgent.md + cookbook scenarios 8.6/10.5 added (AC7-AC8), full suite 5795 passing (AC9), DocC build clean (AC10). Epic 29 closing story complete. | dev-story |

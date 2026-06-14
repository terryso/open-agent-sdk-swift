# Story 29.5: Shared Filtering for Skill and Subagent Tool Sets

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an SDK consumer,
I want skill `allowed-tools` and subagent `tools` / `disallowedTools` to use the same matching rules,
so that the same declaration means the same thing across direct skills and spawned agents.

## Context & Scope

**这是 Epic 29（Claude Code Skill/Subagent Compatibility）的第 5 个 story**，位于依赖图中 29.4 的下游、29.6 的上游（参见 epic 文档 "Story 间依赖关系"）。29.1 / 29.2 / 29.3 / 29.4 已 DONE，为本 story 提供完整运行时基础：`createTaskTool()` alias、`SubAgentLauncherNames` 检测与过滤、skill package context prompt、以及 29.4 引入的 richer `ToolDeclaration` 数据模型与 `Skill.toolDeclarations` / `Skill.toolDeclarationDiagnostics` 字段。

**为什么需要这个 story：** 29.4 让 skill 能**保留**完整工具声明（MCP namespaced、custom/raw、permission pattern、unknown），但目前**没有任何消费方**用上新模型——四条消费路径仍走旧的 enum-only / `[String]?` 过滤：

1. `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:157-174` 的 `filterTools(allowedTools:disallowedTools:)` —— 用 `[String]?` 做大小写不敏感的 `Set` 匹配。它能正确识别 `Bash` / `Read` / `mcp__srv__search`（因为 exact name 匹配），但**不产 diagnostics**，且**无法感知** 29.4 的 `pattern`（`Bash(git diff:*)` 在 Claude Code 子代理 input 里传的是 base name `Bash`，pattern 在 SDK 这层不强制；但若 host 传 `Bash(git diff:*)` 作为 allowed，旧 Set 匹配会**失配**——因为 `tool.name` 是 `"Bash"` 而非 `"Bash(git diff:*)"`）。
2. `Sources/OpenAgentSDK/Core/Agent.swift:1260-1262`（executeSkill）和 `:1326-1328`（executeSkillStream）—— `options.allowedTools = skill.toolRestrictions?.map(\.rawValue)`。**只读旧字段** `toolRestrictions`，意味着 29.4 修正的"MCP / unknown 不静默放权"在 skill 执行路径**仍未生效**——`skill.toolRestrictions` 仍是 29.4 保留的旧解析器输出（`UnknownTool` → nil → unrestricted bug 仍存在于 executeSkill 路径）。
3. `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift:124-126` —— SkillTool 元数据 `result["allowedTools"]` 仍只暴露 rawValue，丢失 MCP / custom / pattern 信息。
4. `Sources/OpenAgentSDK/Tools/ToolRestrictionStack.swift:42-82` —— 基于 `[ToolRestriction]` 的 stack。29.4 没改它（因为它驱动的是 `executeSkill` 内的 `currentAllowedToolNames`，目前仍走 enum）。

**核心矛盾：** 两条独立消费路径（subagent `filterTools` 与 skill `executeSkill`）目前各自做字符串/enum 匹配，没有**共享规则**。Epic 29.5 AC 要求"skill `allowed-tools` 和 subagent `tools`/`disallowedTools` 使用相同匹配规则"——本 story 通过引入**一个**可复用 helper 解决。

**本 story 做什么：**
1. 在 `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`（29.4 创建的文件）**同文件**新增自由函数 `filterToolsByDeclarations(available:allowed:disallowed:...)` 和诊断载体 `ToolFilterDiagnostics`。这是 epic "模块位置" 决策（2026-06-14 readiness review）的最终落地。
2. 用这个 helper 替换/增强 `DefaultSubAgentSpawner.filterTools(...)` 的 allowed/disallowed 匹配（仍保留 `SubAgentLauncherNames` 默认剥离逻辑不变——那是 29.2 的职责）。
3. 把 skill 执行路径（`Agent.executeSkill` / `executeSkillStream`）从消费 `skill.toolRestrictions` 切换到消费 `skill.toolDeclarations`，让 MCP / custom / unknown 工具声明在 skill 执行时也生效（修正 29.4 Dev Notes 标记的"消费方迁移推迟到 29.5"）。
4. SkillTool 元数据增强：当 `toolDeclarations` 非空时，暴露 richer 声明列表（含 MCP / pattern / unknown 标记）。
5. 返回 diagnostics 让宿主能观察"声明了但无可用工具匹配"的情况，**绝不**回退到 unrestricted。

**本 story 不做什么（Out of Scope）：**
- **不实现 fine-grained Bash permission pattern enforcement**（`Bash(git diff:*)` 的参数级匹配）→ epic 延后项第 5 条。本 story 只**保留 pattern 文本**并继续在 diagnostics 里标 "parsed but not enforced"。Filter 层对 `Bash(git diff:*)` 的处理是：按 base name `Bash` 匹配工具，pattern 存入 diagnostics 提示未强制。
- **不改 deferred subagent 字段诊断**（`run_in_background` / `resume` / `isolation` / `team_name` / `skills` / MCP reference）→ Story 29.6。
- **不改 MCP 工具注册路径**（`mcp__{server}__{tool}` 命名已在 MCPToolDefinition.swift:51 正确产生）。
- **不破坏 `Skill.toolRestrictions` 字段及其现有消费者**（BuiltInSkills 的 `[.bash, .read, ...]` 初始化、`ToolRestrictionStack` 的 enum API）。本 story 提供**新**过滤路径，旧路径作为 fallback 保留。
- **不改 E2E 测试**（E2E 推迟到 Story 29.7，参见 project-context.md #29）。
- **不给 `ToolRestriction` enum 加 `.task` case**（29.4 的 "ToolRestriction gap" 决策延续）—— `Task` 通过 normalizedName 字符串匹配。

## Acceptance Criteria

1. **AC1: Helper 函数存在并位于正确模块**
   - **Given** 本 story 实现完成
   - **When** 检查 `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`
   - **Then** 文件包含 `public struct ToolFilterDiagnostics: Sendable, Equatable`（字段至少含 `unmatchedDeclarations: [ToolDeclaration]`——声明了但无 available tool 匹配的声明，及 `patternDeclarations: [ToolDeclaration]`——含 pattern 但 pattern 未强制的声明）
   - **And** 文件包含 `public func filterToolsByDeclarations(available: [ToolProtocol], allowed: [ToolDeclaration]?, disallowed: [ToolDeclaration]?, options: ToolFilterOptions?) -> (filtered: [ToolProtocol], diagnostics: ToolFilterDiagnostics)`
   - **And** 该函数仅依赖 `Foundation` + `ToolProtocol`（Types/）+ 本文件已有的 `ToolDeclaration` / `ToolRestriction` 类型，无跨层 import（project-context.md #7）

2. **AC2: 子代理工具池按 declarations 过滤**
   - **Given** 子代理声明 `allowedTools: ["Read", "Grep", "Glob"]`（通过 Claude Code `Task(allowed_tools: ...)` 片段传入，由 AgentTool 解析为 `[String]`，再由本 story 转为 `[ToolDeclaration]`）
   - **When** `DefaultSubAgentSpawner.filterTools(...)` 被调用
   - **Then** 子代理工具池**只**含匹配的 read/search 工具
   - **And** `Write`、`Edit`、`Bash` **缺席**
   - **And** `Agent` / `Task` 仍被 `SubAgentLauncherNames` 默认剥离（29.2 行为不变）
   - **And** 返回的 diagnostics 不含 unmatched（三个声明都匹配到了工具）

3. **AC3: MCP 工具声明匹配无需 enum case**
   - **Given** skill 声明 `allowed-tools: mcp__srv__search`
   - **When** available tools 含该 MCP 工具（`MCPToolDefinition.name == "mcp__srv__search"`）
   - **Then** 过滤保留该 MCP 工具
   - **And** **不**要求 `ToolRestriction` enum 有对应 case（MCP 声明 status == `.recognizedMCP`，`toolRestriction == nil`）
   - **And** diagnostics 不报该声明为 unmatched

4. **AC4: 声明了但无可用工具 → diagnostics，绝不 unrestricted**
   - **Given** declarations 含一个 missing tool（如 `allowed-tools: PhantomTool`，available tools 中无此工具）
   - **When** 过滤完成
   - **Then** diagnostics.unmatchedDeclarations 含 `PhantomTool` 声明
   - **And** filtered 结果**不**含该工具（因为它不在 available 中）
   - **And** **不**发生 unrestricted 回退（即：若 allowed declarations 非空，filtered 只含匹配的工具，**绝不**返回全部 available tools）

5. **AC5: skill 执行路径消费 `toolDeclarations`（29.4 消费方迁移）**
   - **Given** filesystem skill 的 `allowed-tools: Bash, mcp__srv__search`（SkillLoader 已在 29.4 把它填入 `skill.toolDeclarations`）
   - **When** `executeSkill(_:args:)` 或 `executeSkillStream(_:args:)` 执行该 skill
   - **Then** 执行期间的工具池由 `filterToolsByDeclarations(available: <当前 agent tools>, allowed: skill.toolDeclarations, ...)` 决定
   - **And** 该 skill 的工具池**保留** `mcp__srv__search`（若 available），而旧的 `skill.toolRestrictions` 路径会**丢弃**它（因为无 enum case）
   - **And** 旧的 `options.allowedTools = restrictions.map(\.rawValue)` 路径**保留作为 fallback**（当 `skill.toolDeclarations == nil` 时，如 programmatic skill 或 29.4 之前创建的 skill）

6. **AC6: SkillTool 元数据暴露 richer 声明**
   - **Given** skill 有 `toolDeclarations` 非空
   - **When** `SkillTool` 返回其元数据 dict
   - **Then** 结果包含 `allowedTools`（raw names 列表，向后兼容现有消费者）
   - **And** 结果**额外**包含 `toolDeclarations`（含每个声明的 `rawName` / `normalizedName` / `status` / `pattern`），让宿主能区分 MCP / SDK / unknown 声明
   - **And** 当 `toolDeclarations` 为 nil 时，元数据行为与现状一致（只暴露 `allowedTools` rawValue）

7. **AC7: 向后兼容 —— 现有行为无回归**
   - **Given** 本 story 的所有改动完成
   - **When** `swift build` 和 `swift test` 运行
   - **Then** `ToolRestrictionStack`（28 个现有测试）、`ExecuteSkillTests` / `ExecuteSkillStreamTests`、`SkillToolTests`、`SkillLoaderTests`、`DefaultSubAgentSpawnerTests`（含 29.2 的 filterTools 测试）、`ToolRegistryTests`（含现有 `filterTools` 测试）全部继续通过
   - **And** 全部 6 个 BuiltInSkills 的 `toolRestrictions: [...]` 初始化无回归
   - **And** `Sources/OpenAgentSDK/Tools/ToolRegistry.swift:113` 的 `public func filterTools(tools:allowed:disallowed:)`（Tools/ 层的旧 helper）**签名不变**——本 story **不删它**（它是 `assembleToolPool` 的内部依赖，且被 `Agent.assembleFullToolPool` 使用）

8. **AC8: Build 与全量回归**
   - **Given** 本 story 的所有改动完成
   - **When** `swift build` 和 `swift test` 运行
   - **Then** 构建零新警告，全部测试通过
   - **And** 完成记录中包含新的总测试数（Story 29.4 baseline: 5738 tests passing）

## Tasks / Subtasks

- [x] Task 1: 引入 `ToolFilterDiagnostics` 与 `filterToolsByDeclarations` helper（AC: #1, #3, #4）
  - [x] 1.1 在 `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`（29.4 已创建，本 story 同文件追加）新增 `public struct ToolFilterDiagnostics: Sendable, Equatable`，字段：
    - `let unmatchedDeclarations: [ToolDeclaration]` —— 声明了但 available tools 中无匹配的声明（含 `.unknown` status 与 `.recognizedSDK`/`.recognizedMCP` 但 available 缺该工具两种情况）
    - `let patternDeclarations: [ToolDeclaration]` —— 含非 nil `pattern` 的声明（"parsed but not enforced" 信号，与 29.4 的 `ToolDeclarationDiagnostics.patternDeclarations` 同源）
    - public init 带两参数
  - [x] 1.2 定义 `public struct ToolFilterOptions: Sendable, Equatable`（可选配置，本 story 可保持 minimal）：
    - `let enforceLauncherStripping: Bool`（default `false`——launcher 剥离由 `DefaultSubAgentSpawner` 负责，不在 helper 内做；helper 只做 allowed/disallowed 匹配）。**注意**：本 story 的 helper **不**默认剥离 `Agent`/`Task`——那是 caller（DefaultSubAgentSpawner）在调用 helper **之前**用 `SubAgentLauncherNames` 做的。这样 helper 保持单一职责。
    - 可暂不引入其他 option（YAGNI）；若需要 case-insensitive flag，本 story 默认 true（与现有 `filterTools` 一致），不暴露为 option。
  - [x] 1.3 实现 `public func filterToolsByDeclarations(available: [ToolProtocol], allowed: [ToolDeclaration]?, disallowed: [ToolDeclaration]?, options: ToolFilterOptions? = nil) -> (filtered: [ToolProtocol], diagnostics: ToolFilterDiagnostics)`：
    - **匹配规则**（核心）：对每个 available tool，其 `tool.name.lowercased()` 与声明的 `normalizedName`（已是 lowercased base）做**精确匹配**。这是"exact tool name matching for built-in/custom/MCP tools after normalization"（epic 实施步骤第 2 条）。
    - **allowed 处理**：若 `allowed` 非空，filtered = available 中 normalizedName 命中 allowed 集的 tools。若 `allowed == nil` 或空，filtered = available（无 allow 约束）。
    - **disallowed 处理**：若 `disallowed` 非空，从 filtered 中移除 normalizedName 命中 disallowed 集的 tools。disallowed 优先级高于 allowed（与现有 `filterTools` 一致）。
    - **diagnostics.unmatchedDeclarations**：遍历 allowed declarations，若其 normalizedName 不在 available tools 的 name 集合中 → 加入 unmatched。**注意**：`.unknown` status 的声明几乎肯定 unmatched（除非 host 注册了同名 custom tool——此时 normalizedName 命中，不算 unmatched）。`.recognizedSDK`/`.recognizedMCP` 若 available 缺该工具也算 unmatched。
    - **diagnostics.patternDeclarations**：allowed + disallowed 中 `pattern != nil` 的声明（去重保持顺序）。
    - **关键**：**绝不**因 allowed 全部 unmatched 而返回全部 available（unrestricted 回退）。若 allowed 非空且全部 unmatched → filtered 为空数组 + diagnostics 列出全部 unmatched。这是 epic "不静默放权" 红线。
  - [x] 1.4 helper 必须是**纯函数**（无 I/O、无 actor、无全局状态），便于单元测试（project-context.md #27）。
  - [x] 1.5 在 `OpenAgentSDK.swift` 的 Skill System 文档区段（约 121-127 行）追加 `ToolFilterDiagnostics` / `filterToolsByDeclarations` 的文档索引（与 29.4 同模式）。

- [x] Task 2: `DefaultSubAgentSpawner.filterTools` 消费 helper（AC: #2, #4, #7）
  - [x] 2.1 在 `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:157-174` 的 `filterTools(allowedTools:disallowedTools:)` 中：
    - **保留**第一行 `parentTools.filter { !SubAgentLauncherNames.contains($0.name) }`（29.2 的 launcher 剥离，本 story **不动**）。
    - 把后续 allowed/disallowed 匹配逻辑替换为调用 `filterToolsByDeclarations`。需要先把 `[String]?` 转成 `[ToolDeclaration]?`：因为子代理 input 传来的是 Claude Code 风格 tool name 字符串（如 `"Read"`、`"mcp__srv__search"`、`"Bash(git diff:*)"`），本 story 复用 SkillLoader 已有的解析能力。**关键决策**（见 Dev Notes "字符串→Declaration 转换"）：新增一个**轻量**转换，或复用 `SkillLoader.parseToolDeclarations` 把字符串列表 join 成逗号分隔串再 parse。**推荐**：在 `ToolDeclaration.swift` 加一个 `public static func fromToolNames(_ names: [String]) -> [ToolDeclaration]` 便利构造（内部复用同样的 tokenize 逻辑，但 SkillLoader 的 `tokenizeToolDeclaration` / `splitBaseAndPattern` / `isMCPNamespacedName` / `ClaudeCodeToolNames` 是 `private static`——**决策**：把这些 helper 提升为 `internal` 或移到 `ToolDeclaration.swift` 作为 file-private shared helpers，让 both SkillLoader 和新转换函数复用。**优先方案**：在 `ToolDeclaration.swift` 新增 `internal static func parse(_ name: String) -> ToolDeclaration` 单 token 解析（封装 tokenize 逻辑），SkillLoader 的 `parseToolDeclarations` 内部改用它，避免逻辑重复。这把解析能力从 SkillLoader 上提到 ToolDeclaration 类型自身）。
    - [x] 2.2 调用 `filterToolsByDeclarations(available: launcherStripped, allowed: allowedDeclarations, disallowed: disallowedDeclarations)`，返回 `(filtered, diagnostics)`。
    - [x] 2.3 **保留** `filterToolsForTesting` internal wrapper（DefaultSubAgentSpawnerTests 依赖它），但其签名可扩展为也返回 diagnostics（或新增 `filterToolsWithDiagnosticsForTesting`）。**优先**：保持 `filterToolsForTesting` 返回 `[ToolProtocol]` 不变（现有 5 个测试依赖），新增 `filterToolsWithDiagnosticsForTesting` 返回完整元组给新测试用。
    - [x] 2.4 diagnostics 目前**不**注入到 `SubAgentResult`（那是 29.6 的 deferred field diagnostics 范围）。本 story 的 spawner diagnostics 可暂存或 log（若 SDK 有 logger），但**不**改 `SubAgentResult` 结构（避免连锁改动）。**决策**：本 story 的 spawner 路径 diagnostics 先丢弃（或仅用于内部断言），29.6 会统一处理 subagent diagnostics surfacing。在 Dev Notes 注明。

- [x] Task 3: skill 执行路径消费 `toolDeclarations`（AC: #5, #7）
  - [x] 3.1 在 `Sources/OpenAgentSDK/Core/Agent.swift:1259-1262`（executeSkill）和 `:1326-1328`（executeSkillStream），把：
    ```swift
    if let restrictions = skill.toolRestrictions {
        options.allowedTools = restrictions.map(\.rawValue)
    }
    ```
    改为优先消费 `toolDeclarations`：
    ```swift
    if let declarations = skill.toolDeclarations {
        // 29.5: richer filtering path — preserves MCP/custom/unknown declarations
        // Apply via filterToolsByDeclarations during tool pool assembly.
        // Store declarations on options or a captured local for assembleFullToolPool to consume.
        options.allowedToolDeclarations = declarations  // NEW field on AgentOptions (Task 3.2)
    } else if let restrictions = skill.toolRestrictions {
        // Fallback: legacy enum-only path (programmatic skills, pre-29.4 skills)
        options.allowedTools = restrictions.map(\.rawValue)
    }
    ```
  - [x] 3.2 **决策**：如何让 `filterToolsByDeclarations` 在 `assembleFullToolPool`（Agent.swift:1009-1057）生效？`assembleToolPool`（ToolRegistry.swift:150）目前接受 `allowed: [String]?`。两个选项：
    - **(a)** 在 `AgentOptions` 新增 `allowedToolDeclarations: [ToolDeclaration]?` 字段，`assembleFullToolPool` 检测它非空时调用 `filterToolsByDeclarations` 替代 `filterTools`。**推荐**——保持 `assembleToolPool` 签名稳定（它被多处调用），过滤决策在 `assembleFullToolPool` 层做。
    - **(b)** 改 `assembleToolPool` 接受 `[ToolDeclaration]?`。**不推荐**——破坏现有签名，影响面大。
    选 (a)。`AgentOptions.allowedToolDeclarations` 默认 nil，`assembleFullToolPool` 在构建 pool 后若该字段非空，用 `filterToolsByDeclarations` 二次过滤。
  - [x] 3.3 在 `assembleFullToolPool`（Agent.swift:1009+）末尾，`return (pool, manager)` 之前，加：
    ```swift
    var finalPool = pool
    if let declarations = options.allowedToolDeclarations, !declarations.isEmpty {
        let (filtered, _) = filterToolsByDeclarations(
            available: pool, allowed: declarations, disallowed: nil
        )
        finalPool = filtered
    }
    return (finalPool, manager)
    ```
    **注意**：disallowed 在 skill 执行路径目前无来源（`Skill` 无 disallowedTools 字段——subagent 才有）。本 story skill 路径只处理 allowed。
  - [x] 3.4 `executeSkill` / `executeSkillStream` 的 defer/onTermination 恢复逻辑要同时恢复 `options.allowedToolDeclarations = nil`（与 `savedAllowedTools` 同模式，新增 `savedAllowedDeclarations`）。
  - [x] 3.5 **回归保护**：`executeSkill` / `executeSkillStream` 现有测试（`ExecuteSkillTests` / `ExecuteSkillStreamTests`）若用 programmatic skill（无 toolDeclarations），走 fallback 路径，行为不变。

- [x] Task 4: SkillTool 元数据增强（AC: #6, #7）
  - [x] 4.1 在 `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift:123-126`，现有：
    ```swift
    if let restrictions = skill.toolRestrictions {
        result["allowedTools"] = restrictions.map(\.rawValue)
    }
    ```
    扩展为：
    ```swift
    if let restrictions = skill.toolRestrictions {
        result["allowedTools"] = restrictions.map(\.rawValue)
    }
    if let declarations = skill.toolDeclarations {
        result["toolDeclarations"] = declarations.map { d in
            [
                "rawName": d.rawName,
                "normalizedName": d.normalizedName,
                "status": d.status.rawValue,
                "pattern": d.pattern as Any?,  // nil-safe
                "hasToolRestriction": d.toolRestriction != nil
            ] as [String: Any]
        }
    }
    ```
    **注意**：`result` 当前是 `[String: String]` 还是 `[String: Any]`？**必须先 Read SkillTool.swift 确认 result dict 类型**。若是 `[String: String]`，新增 `toolDeclarations` 需要改 dict 类型或 JSON-encode 嵌套结构。**优先**：保持 `allowedTools` 为 `[String]`（向后兼容），新增字段若类型受限则 JSON-encode 为 String。Read 后决策。
  - [x] 4.2 SkillTool 现有测试（`SkillToolTests`）验证 `allowedTools` rawValue 不变。新增测试验证 `toolDeclarations` 字段存在且结构正确（当 skill 有 declarations 时）。

- [x] Task 5: 共享解析能力上提到 `ToolDeclaration`（AC: #2，支撑 Task 2 的字符串→Declaration 转换）
  - [x] 5.1 **决策**：SkillLoader.swift:407-507 的 `tokenizeToolDeclaration` / `splitBaseAndPattern` / `isMCPNamespacedName` / `ClaudeCodeToolNames`（均为 `private static`）需要被 Task 2 的 `fromToolNames` 复用。**方案**：在 `ToolDeclaration.swift` 新增 `extension ToolDeclaration`，提供 `static func parse(_ token: String) -> ToolDeclaration`（封装 tokenize 单 token 逻辑），把 SkillLoader 的 4 个 private helper 的**实现**移到 ToolDeclaration.swift（作为 `private` 或 `internal` 函数），SkillLoader 的 `parseToolDeclarations` 内部改为调用 `ToolDeclaration.parse`。这样：
    - SkillLoader 不再持有解析逻辑（瘦身为 caller）
    - ToolDeclaration 成为自洽的"声明 + 解析 + 过滤"模块（epic 模块位置决策的延伸）
    - `fromToolNames` 直接用 `ToolDeclaration.parse`
  - [x] 5.2 **回归保护**：移动后 `SkillLoader.parseToolDeclarations` 的 10 个现有测试（29.4 新增）必须继续通过——行为不变，只是代码位置变了。`SkillLoader.parseAllowedTools`（旧解析器）**完全不动**。
  - [x] 5.3 在 `ToolDeclaration.swift` 新增 `public static func fromToolNames(_ names: [String]) -> [ToolDeclaration]`：对每个 name 调用 `parse`，返回数组。**注意**：names 可能含 `"Bash(git diff:*)"` 这种带 pattern 的形式——`parse` 已处理 splitBaseAndPattern。names 也可能含 `"mcp__srv__search"`——`parse` 已处理 isMCPNamespacedName。

- [x] Task 6: 单元测试（AC: #1-#8）
  - [x] 6.1 新建 `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift`（遵循 rule #23 测试目录镜像源码；ToolDeclaration 在 Types/ → 测试在 Types/）。纯函数测试，无 I/O 无网络（rule #27）。测试 `filterToolsByDeclarations` 与 `ToolFilterDiagnostics`：
    - `testFilter_preservesOnlyAllowedTools` —— available = [Bash, Read, Write], allowed = [parse("Read"), parse("Grep")] → filtered == [Read], diagnostics.unmatched 含 Grep（available 无 Grep）
    - `testFilter_mcpDeclaration_matchesWithoutEnumCase` —— available = [mcp__srv__search tool], allowed = [parse("mcp__srv__search")] → filtered 含该 MCP tool, unmatched 空
    - `testFilter_unknownDeclaration_notUnrestricted` —— available = [Bash, Read], allowed = [parse("PhantomTool")] → filtered == [], unmatched 含 PhantomTool（**绝不**返回全部 available）
    - `testFilter_disallowed_overridesAllowed` —— available = [Bash, Read], allowed = [parse("Bash"), parse("Read")], disallowed = [parse("Bash")] → filtered == [Read]
    - `testFilter_nilAllowed_returnsAll` —— available = [Bash, Read], allowed = nil → filtered == [Bash, Read]
    - `testFilter_patternDeclaration_surfacesInDiagnostics` —— allowed = [parse("Bash(git diff:*)")], available = [Bash] → filtered == [Bash]（按 base name 匹配）, diagnostics.patternDeclarations 含该声明
    - `testFilter_caseInsensitive` —— available = [tool named "Bash"], allowed = [parse("bash")] → filtered 含 Bash
    - `testFromToolNames_preservesOrderAndPattern` —— fromToolNames(["Read", "Bash(git diff:*)", "mcp__srv__search"]) → 3 declarations，顺序保持，pattern 保留
    - `testFilter_emptyAllowed_returnsAll` —— allowed = [] → filtered == available（空 allowed 等同 nil）
  - [x] 6.2 扩展 `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`（遵循 rule #56 复用现有文件），新增 `// MARK: - Story 29.5: Declaration-Based Filtering` 区段：
    - `testFilterTools_declarationBased_keepsOnlyMatching` —— 父池 = [Bash, Read, Write, Agent], allowedTools = ["Read", "Grep"] → filtered == [Read]（Grep 不在父池）, Agent 被剥离
    - `testFilterTools_mcpAllowed_keepsMcp` —— 父池含 MCP tool, allowedTools = ["mcp__srv__search"] → 保留
    - `testFilterTools_unknownAllowed_notUnrestricted` —— allowedTools = ["PhantomTool"] → filtered == []
    - `testFilterTools_launcherStrippingStillWorks` —— 父池 = [Bash, Agent, Task], allowedTools = nil → filtered == [Bash]（Agent + Task 被 SubAgentLauncherNames 剥离，29.2 行为不变）
    - `testFilterTools_patternInAllowed_matchesByBaseName` —— allowedTools = ["Bash(git diff:*)"] → filtered 含 Bash（按 base 匹配，pattern 不强制）
  - [x] 6.3 扩展 `Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift`（若存在；若不存在在 ExecuteSkill*Tests 或新建），验证 SkillTool 元数据 `toolDeclarations` 字段。**先 grep 确认 SkillToolTests.swift 位置**。
  - [x] 6.4 扩展 `Tests/OpenAgentSDKTests/Core/ExecuteSkillTests.swift` 或 `ExecuteSkillStreamTests.swift`，新增：skill 有 `toolDeclarations`（含 MCP）时，执行路径保留 MCP 工具。**注意**：这些测试若涉及真实 LLM 调用，用 mock client（rule #27）；若纯逻辑测试，构造带 declarations 的 Skill 直接调 executeSkill 的内部路径。
  - [x] 6.5 **回归保护**：现有 `ToolRestrictionStackTests`（28 个）、`ToolRegistryTests.filterTools_*`（5+ 个）、`DefaultSubAgentSpawnerTests.filterTools_*`（29.2 的 5 个）、`SkillLoaderTests.parseToolDeclarations_*`（29.4 的 10 个）全部继续通过。
  - [x] 6.6 E2E 推迟到 Story 29.7（rule #29 + epic 29.7）。

- [x] Task 7: 构建与全量回归（AC: #8）
  - [x] 7.1 `swift build` 成功，零新警告
  - [x] 7.2 `swift test` 全量通过；完成记录包含新的总测试数（baseline 5738）
  - [x] 7.3 确认无 Swift 编译器错误引入名为 `Task` 的类型（rule #15）
  - [x] 7.4 确认 `ToolRestrictionStack`、`assembleToolPool`、`filterTools`（ToolRegistry.swift）、`parseAllowedTools`（SkillLoader.swift）签名全部不变（AC7 回归保护）

## Dev Notes

### Architecture Context

这是 **Epic 29 的第 5 个 story**，依赖图中位置：

```
29.1 (DONE) --> 29.2 (DONE)
                |
                +--> 29.3 (DONE)
                |
                +--> 29.4 (DONE)  ← 引入 ToolDeclaration 数据模型 + parseToolDeclarations
                        |
                        +--> 29.5 (THIS STORY)  ← 引入 filterToolsByDeclarations + 消费方迁移
                                |
                                +--> 29.6 (Diagnostics)  ← deferred field diagnostics
                                        |
                                        +--> 29.7 (Tests + docs)
```

29.5 是 Epic 29 的**消费方迁移** story：29.4 让"声明"可表达，29.5 让"过滤"用上新声明，并打通两条独立消费路径（subagent `filterTools` 与 skill `executeSkill`）到同一 helper。

### CRITICAL: 当前代码事实（必须先读）

**1. 已存在的 `filterTools` 自由函数（Tools/ 层）—— 不要与之冲突：**
`Sources/OpenAgentSDK/Tools/ToolRegistry.swift:113-133` 已有 `public func filterTools(tools: [ToolProtocol], allowed: [String]?, disallowed: [String]?) -> [ToolProtocol]`。它是 `assembleToolPool`（ToolRegistry.swift:150）的内部依赖，被 `Agent.assembleFullToolPool`（Agent.swift:1022, 1048）使用。**本 story 不删它**（AC7），而是新增 `filterToolsByDeclarations`（Types/ 层）作为**并行**的 richer 路径。命名区分清晰：`filterTools`（字符串）vs `filterToolsByDeclarations`（声明模型）。

**2. `DefaultSubAgentSpawner.filterTools`（Core/ 层）—— 本 story 改造目标：**
`Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:157-174`。当前实现：
```swift
private func filterTools(allowedTools: [String]?, disallowedTools: [String]?) -> [ToolProtocol] {
    var subTools = parentTools.filter { !SubAgentLauncherNames.contains($0.name) }
    if let allowed = allowedTools, !allowed.isEmpty {
        let allowedSet = Set(allowed)
        subTools = subTools.filter { allowedSet.contains($0.name) }
    }
    if let disallowed = disallowedTools, !disallowed.isEmpty {
        let disallowedSet = Set(disallowed)
        subTools = subTools.filter { !disallowedSet.contains($0.name) }
    }
    return subTools
}
```
**问题**：(a) `allowedSet.contains($0.name)` 是**大小写敏感**的（与 ToolRegistry.filterTools 的 lowercased 不一致！）；(b) `Bash(git diff:*)` 作为 allowed 字符串传入时，`tool.name == "Bash"` 不匹配 `"Bash(git diff:*)"` → Bash 被错误剥离。本 story 用 `filterToolsByDeclarations`（内部 lowercased + base name 匹配）修正这两个问题。

**3. skill 执行路径（Core/Agent.swift）—— 本 story 改造目标：**
- `executeSkill`（:1255-1285）：`if let restrictions = skill.toolRestrictions { options.allowedTools = restrictions.map(\.rawValue) }`。只读旧字段。
- `executeSkillStream`（:1322-1364）：同上。
- `assembleFullToolPool`（:1009-1057）：调用 `assembleToolPool(..., allowed: options.allowedTools, disallowed: options.disallowedTools)`。本 story 在此加 `allowedToolDeclarations` 二次过滤。

**4. SkillTool 元数据（Tools/Advanced/SkillTool.swift:123-126）—— 本 story 增强目标：**
```swift
if let restrictions = skill.toolRestrictions {
    result["allowedTools"] = restrictions.map(\.rawValue)
}
```
**必须先 Read SkillTool.swift 确认 `result` 的 dict 类型**（`[String: String]` vs `[String: Any]`），决定 `toolDeclarations` 嵌套结构的表达方式。

**5. 29.4 已建立的基础（本 story 直接消费）：**
- `Sources/OpenAgentSDK/Types/ToolDeclaration.swift` —— `ToolDeclaration` / `ToolDeclarationStatus` / `ToolDeclarationDiagnostics` 三个 public 类型。本 story 同文件追加 `ToolFilterDiagnostics` + `filterToolsByDeclarations`。
- `Sources/OpenAgentSDK/Types/SkillTypes.swift:85,90` —— `Skill.toolDeclarations: [ToolDeclaration]?` 和 `Skill.toolDeclarationDiagnostics: ToolDeclarationDiagnostics?` 字段（29.4 已填充）。
- `Sources/OpenAgentSDK/Skills/SkillLoader.swift:372-399` —— `parseToolDeclarations(_:) -> (declarations, diagnostics)?`。本 story Task 5 把其内部 `tokenizeToolDeclaration` 等上提到 ToolDeclaration.swift。

### 字符串 → Declaration 转换（Task 2 关键决策）

子代理 input（Claude Code `Task(allowed_tools: ["Read", "Bash(git diff:*)"])`）传来的是 `[String]`，而 `filterToolsByDeclarations` 需要 `[ToolDeclaration]?`。转换路径：

**方案 A（推荐）**：在 `ToolDeclaration.swift` 新增 `public static func fromToolNames(_ names: [String]) -> [ToolDeclaration]`，内部对每个 name 调用 `ToolDeclaration.parse(_:)`（Task 5 从 SkillLoader 上提的 tokenize 逻辑）。DefaultSubAgentSpawner 调用 `ToolDeclaration.fromToolNames(allowedTools ?? [])`。

**方案 B**：DefaultSubAgentSpawner 把 `[String]` join 成逗号分隔串，调 `SkillLoader.parseToolDeclarations`。**不推荐**——Core/ 调 Skills/ 解析器是倒置依赖（Core/ 不应依赖 Skills/ 的内部实现），且 join+split 有损。

选 A。Task 5 的解析上提是前置依赖。

### 模块边界合规性（project-context.md #7）

- `ToolFilterDiagnostics` + `filterToolsByDeclarations` 放 `Types/ToolDeclaration.swift` —— ✅ Types/ 是叶节点，无出站依赖。`filterToolsByDeclarations` 只用 `Foundation` + `ToolProtocol`（Types/）+ `ToolDeclaration`（同文件）。
- `DefaultSubAgentSpawner`（Core/）调用 `Types/` 的 helper —— ✅ Core/ 可 import Types/。
- `SkillTool`（Tools/）读取 `Skill.toolDeclarations`（Types/）—— ✅ Tools/ 可 import Types/。
- **不**把 helper 放 `Tools/ToolRegistry.swift` —— 那样 Core/ 无法调用（Core/ 不 import Tools/，project-context.md #7 反模式 #41）。readiness report ISSUE-2 已确认此决策。
- **不**把 helper 放 `Core/` —— 那样 Tools/（SkillTool 想复用）无法调用。

### MCP 工具命名（project-context.md #10）

MCP 工具 `name` 是 `"mcp__\(serverName)__\(mcpToolName)"`（MCPToolDefinition.swift:51）。`filterToolsByDeclarations` 用 `tool.name.lowercased()` 与 declaration 的 `normalizedName`（对 MCP 声明 = 完整 `mcp__srv__search`，29.4 已保留不截断）匹配。**注意**：MCP serverName/toolName 本身可能含大写（如 `mcp__GitHub__ListPRs`），lowercased 匹配保证 case-insensitive。

### Pattern 处理（不强制，仅诊断）

`Bash(git diff:*)` 的 filter 行为：按 base name `bash` 匹配工具（`tool.name.lowercased() == "bash"` 命中 BashTool）。pattern `git diff:*` **不强制**（epic 延后项第 5 条），但进入 `diagnostics.patternDeclarations` 提示"parsed but not enforced"。这与 29.4 的 `ToolDeclarationDiagnostics.patternDeclarations` 语义一致——本 story 的 `ToolFilterDiagnostics.patternDeclarations` 是 runtime filter 层的同源信号。

### Anti-Patterns to Avoid (project-context.md)

- ❌ **不要删除/改签名 `ToolRegistry.filterTools`（字符串版）** —— 它是 `assembleToolPool` 的依赖，AC7 要求不变。新增 `filterToolsByDeclarations` 并存。
- ❌ **不要让 allowed 全 unmatched 时返回全部 available** —— epic "不静默放权" 红线。空 filtered + diagnostics。
- ❌ **不要在 helper 内剥离 `Agent`/`Task`** —— 那是 `DefaultSubAgentSpawner` 用 `SubAgentLauncherNames` 在调用 helper **前**做的。helper 单一职责：allowed/disallowed 匹配。若在 helper 内剥离，skill 执行路径（也调 helper）会错误剥离子代理能力。
- ❌ **不要 force-unwrap (`!`)** —— rule #40，用 guard let。
- ❌ **不要用 Set** —— declarations 顺序保持 frontmatter/输入顺序（rule #46），用 Array。内部匹配可用 Set 做 O(1) 查找，但结果保持 Array 顺序。
- ❌ **不要给 `ToolRestriction` enum 加 `.task`** —— 29.4 决策延续，`Task` 通过 normalizedName 匹配。
- ❌ **不要改 `Skill.toolRestrictions` 字段或其填充逻辑** —— AC7。新路径用 `toolDeclarations`，旧路径 fallback 保留。
- ❌ **不要改 `parseAllowedTools`（SkillLoader 旧解析器）** —— AC7。Task 5 只移动 `parseToolDeclarations` 的内部 helper，不动旧解析器。
- ❌ **不要写真实网络/文件 I/O 测试** —— helper 是纯函数（rule #27）。
- ❌ **不要新建独立测试文件除非必要** —— DefaultSubAgentSpawnerTests / ExecuteSkillTests 扩展现有（rule #56）。仅 `ToolDeclarationFilterTests.swift` 新建（因为是全新 Types/ 层 helper，镜像源码结构 rule #23）。
- ❌ **不要在 helper 内改 `SubAgentResult` 结构** —— deferred diagnostics surfacing 是 29.6。

### Testing Standards

- XCTest only（rule #23）
- 测试目录镜像源码：
  - `filterToolsByDeclarations` 在 `Types/ToolDeclaration.swift` → 测试 `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift`（新建）
  - `DefaultSubAgentSpawner.filterTools` 改造 → 扩展 `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`
  - `SkillTool` 元数据 → 扩展 `Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift`（先 grep 确认存在）
  - `executeSkill` declarations 路径 → 扩展 `Tests/OpenAgentSDKTests/Core/ExecuteSkillTests.swift` / `ExecuteSkillStreamTests.swift`
- 纯函数测试：`filterToolsByDeclarations` 无副作用，直接断言返回元组
- mock client 用于涉及 LLM 的 executeSkill 测试（rule #27）
- E2E 推迟到 Story 29.7（rule #29）

### Previous Story Intelligence (Story 29.4)

Story 29.4（commit 6715e80）完成于 2026-06-14，5738 tests passing。关键学习对本 story 适用：

- **"同文件追加新类型"模式** —— 29.4 在 `ToolDeclaration.swift` 定义三个类型；本 story 同文件追加 `ToolFilterDiagnostics` + 函数。保持"声明 + 过滤"模块内聚（epic 模块位置决策延伸）。
- **"新增字段有默认值，保留旧字段"迁移模式** —— 29.4 给 `Skill` 加 `toolDeclarations`（默认 nil）；本 story 给 `AgentOptions` 加 `allowedToolDeclarations`（默认 nil），同样保持现有调用方编译。
- **"并行迁移，旧路径 fallback"模式** —— 29.4 保留 `parseAllowedTools` 不改，新增 `parseToolDeclarations`；本 story 保留 `filterTools`（字符串）不改，新增 `filterToolsByDeclarations`。executeSkill 路径优先 declarations，fallback restrictions。
- **"ToolRestriction gap"决策延续** —— `Task` 无 enum case，通过 normalizedName 字符串匹配。本 story 的 helper 不依赖 enum，故 `Task` 声明（若作为 allowed 传入）能匹配到名为 `Task` 的工具。
- **29.4 code review 发现的 3 个 deferred 边缘情况**（commit message 提及，deferred to 29.5）：
  - MCP tool name 含 `__`（如 `mcp__srv__a__b`）—— 29.4 的 `isMCPNamespacedName` 要求 server/tool 各不含 `__`。**本 story 不改这个**（MCPToolDefinition.swift:84 的 precondition 已拒绝含 `__` 的 server/tool 名）。若 29.5 测试发现真实 MCP 工具被误判，作为 follow-up。
  - 逗号在括号内（`Bash(a,b)`）—— split-on-comma 会错误切分。**本 story 不改**（29.4 deferred，pattern enforcement 延后，这类 pattern 当前不强制，split 不完美可接受）。Dev Notes 标注。
  - 重复声明去重 —— `allowed-tools: Bash, Bash`。**本 story filter 行为**：两次匹配同一工具，filtered 含 Bash 一次（available 去重由 `tool.name` 唯一性保证），diagnostics.patternDeclarations 不去重（保留声明顺序）。若需去重 diagnostics，作为 follow-up。

### Previous Story Intelligence (Story 29.1 / 29.2 / 29.3)

- **29.1**（commit 923bd6b）：`createTaskTool()` alias，`"Task"` 是字符串名。本 story 的 `Task` 声明匹配同理（字符串）。
- **29.2**（commit 5dd0ea2）：`SubAgentLauncherNames.default = ["Agent", "Task"]` 集中管理。本 story **保留** launcher 剥离逻辑不变（在 DefaultSubAgentSpawner 调 helper 前做）。
- **29.3**（commit dc49d54）：skill package context prompt。未触碰 filter 路径。

### Git Intelligence (recent commits)

```
6715e80 feat(skills): add lossless ToolDeclaration compatibility model (Story 29-4)
dc49d54 feat(core): inject skill package context into direct skill execution (Story 29-3)
fbf001c fix(core): propagate sub-agent toolCalls from QueryResult.toolPairs
ee158e9 chore: add BMAD agent workspace config (skills, hooks, AGENTS.md)
5dd0ea2 feat(core): unify Agent/Task spawner detection and child filtering (Story 29-2)
```

`6715e80`（29.4）创建了 `ToolDeclaration.swift`、扩展了 `SkillTypes.swift` / `SkillLoader.swift`。本 story 的目标文件（ToolDeclaration.swift 追加、DefaultSubAgentSpawner.swift:157-174、Agent.swift:1009-1057/1255-1364、SkillTool.swift:123-126）自 29.4 以来处于干净状态（29.4 明确不改这些消费方）。

### Latest Technical Information

- **Swift 5.9+** —— helper 是同步纯函数，无 throws/async 需求。`[ToolProtocol]` 是 `Sendable` 兼容的数组（ToolProtocol: Sendable）。
- **`ToolProtocol` 在 Types/** —— helper 可直接 import（同层）。无需跨层依赖。
- **不引入新外部依赖** —— 仅 Foundation + 现有 Types/ 类型。
- **`AgentOptions` 位于 `Sources/OpenAgentSDK/Types/AgentTypes.swift`**（非独立文件）—— Task 3.2 新增字段在此 struct 内。

### `filterToolsByDeclarations` 签名设计参考

```swift
// Sources/OpenAgentSDK/Types/ToolDeclaration.swift (追加)

public struct ToolFilterOptions: Sendable, Equatable {
    /// Whether to also strip subagent launcher tools (Agent/Task).
    /// Default `false` — launcher stripping is the caller's responsibility
    /// (DefaultSubAgentSpawner does it via SubAgentLauncherNames before calling this helper).
    public let enforceLauncherStripping: Bool
    public init(enforceLauncherStripping: Bool = false) {
        self.enforceLauncherStripping = enforceLauncherStripping
    }
}

public struct ToolFilterDiagnostics: Sendable, Equatable {
    /// Declarations that did not match any available tool.
    public let unmatchedDeclarations: [ToolDeclaration]
    /// Declarations carrying a non-nil pattern (parsed but not enforced).
    public let patternDeclarations: [ToolDeclaration]
    public init(unmatchedDeclarations: [ToolDeclaration], patternDeclarations: [ToolDeclaration]) {
        self.unmatchedDeclarations = unmatchedDeclarations
        self.patternDeclarations = patternDeclarations
    }
}

public func filterToolsByDeclarations(
    available: [ToolProtocol],
    allowed: [ToolDeclaration]?,
    disallowed: [ToolDeclaration]?,
    options: ToolFilterOptions? = nil
) -> (filtered: [ToolProtocol], diagnostics: ToolFilterDiagnostics) {
    let opts = options ?? ToolFilterOptions()
    var pool = available
    if opts.enforceLauncherStripping {
        pool = pool.filter { !SubAgentLauncherNames.contains($0.name) }
    }
    // ... allowed/disallowed matching, diagnostics assembly ...
}
```

**注意**：`SubAgentLauncherNames` 在 `Core/DefaultSubAgentSpawner.swift`（Core/），`filterToolsByDeclarations` 在 Types/ **不能** import Core/。故 `enforceLauncherStripping` option 的实现需要 caller 传入剥离函数，或本 story **不实现**这个 option（caller 自己在调 helper 前剥离）。**推荐**：本 story 的 helper **不**含 launcher stripping（caller DefaultSubAgentSpawner 已在调 helper 前用 SubAgentLauncherNames 剥离）。`ToolFilterOptions.enforceLauncherStripping` 字段**移除**（YAGNI），helper 保持单一职责。Dev Notes 更正此设计。

### Files to Modify/Create

- **MODIFY (追加)**: `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`
  - 追加 `ToolFilterDiagnostics` struct
  - 追加 `filterToolsByDeclarations(...)` 自由函数
  - 追加 `ToolDeclaration.parse(_:)` static（从 SkillLoader 上提的 tokenize 单 token 逻辑）
  - 追加 `ToolDeclaration.fromToolNames(_:)` static（Task 2 字符串转换用）
  - 移入 `tokenizeToolDeclaration` / `splitBaseAndPattern` / `isMCPNamespacedName` / `ClaudeCodeToolNames`（从 SkillLoader.swift，改为 internal/private on ToolDeclaration or file-private）
- **MODIFY**: `Sources/OpenAgentSDK/Skills/SkillLoader.swift`
  - `parseToolDeclarations` 内部改用 `ToolDeclaration.parse`（逻辑外移，瘦身）
  - **保留** `parseAllowedTools`（旧）完全不变
- **MODIFY**: `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift`
  - `filterTools(allowedTools:disallowedTools:)` 用 `ToolDeclaration.fromToolNames` + `filterToolsByDeclarations` 替换字符串 Set 匹配
  - 保留 `SubAgentLauncherNames` 剥离（调 helper 前）
  - 保留 `filterToolsForTesting` 签名，新增 `filterToolsWithDiagnosticsForTesting`
- **MODIFY**: `Sources/OpenAgentSDK/Core/Agent.swift`
  - `executeSkill`（:1255-1285）/ `executeSkillStream`（:1322-1364）：优先 `skill.toolDeclarations`，fallback `skill.toolRestrictions`
  - `assembleFullToolPool`（:1009-1057）：末尾加 `allowedToolDeclarations` 二次过滤
- **MODIFY**: `Sources/OpenAgentSDK/Types/AgentTypes.swift`
  - `AgentOptions` 新增 `allowedToolDeclarations: [ToolDeclaration]?`（默认 nil）
- **MODIFY**: `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift`
  - 元数据 dict 新增 `toolDeclarations` 字段（Read 后确认 dict 类型决定表达方式）
- **MODIFY**: `Sources/OpenAgentSDK/OpenAgentSDK.swift`
  - Skill System 文档区段索引 `ToolFilterDiagnostics` / `filterToolsByDeclarations`
- **NEW**: `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift` —— 9+ helper 单元测试
- **MODIFY**: `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` —— 5 declaration-based filter 测试
- **MODIFY**: `Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift`（先 grep 确认存在）—— toolDeclarations 元数据测试
- **MODIFY**: `Tests/OpenAgentSDKTests/Core/ExecuteSkillTests.swift` / `ExecuteSkillStreamTests.swift` —— declarations 路径测试

**不修改（验证无回归）：**
- `Sources/OpenAgentSDK/Tools/ToolRegistry.swift`（`filterTools` / `assembleToolPool` 签名不变）
- `Sources/OpenAgentSDK/Tools/ToolRestrictionStack.swift`（enum-based stack 不变）
- `Sources/OpenAgentSDK/Types/SkillTypes.swift` 的 `ToolRestriction` enum（不加 `.task`）
- 全部 6 个 BuiltInSkills 的 `toolRestrictions: [...]` 初始化

### Dependencies and Blockers

**Upstream (DONE):**
- Story 29.1 (`createTaskTool()`) — DONE，commit 923bd6b。
- Story 29.2 (`SubAgentLauncherNames`) — DONE，commit 5dd0ea2。
- Story 29.3 (skill package context) — DONE，commit dc49d54。
- Story 29.4 (`ToolDeclaration` model + `Skill.toolDeclarations`) — DONE，commit 6715e80。5738 tests baseline。

**Downstream (本 story 解锁):**
- Story 29.6 (Diagnostics) — 依赖本 story 的 `ToolFilterDiagnostics` 模式，扩展到 deferred field diagnostics。
- Story 29.7 (Tests + docs) — 扩展本 story 的 filter 测试覆盖 + E2E。

**No blockers remain.**

### Out of Scope (Deferred to Later Stories)

- Fine-grained Bash permission pattern enforcement → **epic 延后项第 5 条**
- Deferred field diagnostics（run_in_background / resume / isolation / team_name / skills / MCP reference）→ **Story 29.6**
- SubAgentResult 结构化 diagnostics surfacing → **Story 29.6**
- E2E 测试 → **Story 29.7**
- Filesystem subagent loader (`.claude/agents/*.md`) → **future epic**
- Comma-inside-parens / declaration dedup 边缘情况 → **follow-up**（29.4 deferred）

### References

- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#Story 29.5] — story 定义、3 个 AC、实施步骤（helper 签名、exact matching、SDK+LLM 名兼容、DefaultSubAgentSpawner 接入、ToolRestrictionStack 消费、diagnostics）、模块位置决策
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#关键设计约束] — 不静默放权、MCP tool name 完整、向后兼容、不引入 `Task` Swift 类型
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#延后项] — Fine-grained Bash pattern enforcement 延后
- [Source: _bmad-output/implementation-artifacts/29-4-tool-declaration-compatibility-model.md] — Story 29.4 完成记录（5738 tests, commit 6715e80），ToolDeclaration 模型设计、parseToolDeclarations 实现、"消费方迁移推迟到 29.5" 标记
- [Source: _bmad-output/implementation-artifacts/29-4-tool-declaration-compatibility-model.md#Dev Notes] — "ToolRestriction gap"（Task 无 enum case）、MCP 命名约定、模块边界决策
- [Source: _bmad-output/implementation-artifacts/29-2-spawner-detection-child-filtering.md] — Story 29.2 完成记录，SubAgentLauncherNames 集中管理模式
- [Source: _bmad-output/implementation-artifacts/29-1-agent-task-shared-subagent-launcher.md] — Story 29.1 完成记录，"Task 是字符串名非 Swift 类型"模式
- [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-06-14.md] — readiness verdict: READY_WITH_ACTIONS，ISSUE-2（29.5 模块位置）已解决为 `Types/ToolDeclaration.swift`；FR34/NFR8/AD8 traceability
- [Source: _bmad-output/project-context.md#7] — 模块边界（Types/ 叶节点，Core/ 不依赖 Tools/，Tools/ 不依赖 Core/）
- [Source: _bmad-output/project-context.md#10] — MCP 命名约定 mcp__{serverName}__{toolName}
- [Source: _bmad-output/project-context.md#15] — Swift 类型命名（无 `Task` 类型）
- [Source: _bmad-output/project-context.md#23] — 测试目录镜像源码
- [Source: _bmad-output/project-context.md#27] — 单元测试 mock 外部 API
- [Source: _bmad-output/project-context.md#29] — E2E 推迟到 Story 29.7
- [Source: _bmad-output/project-context.md#40] — 无 force-unwrap
- [Source: _bmad-output/project-context.md#41] — Tools/ 不 import Core/
- [Source: _bmad-output/project-context.md#46] — Array 而非 Set 用于有序列表
- [Source: _bmad-output/project-context.md#56] — 复用共享测试基础设施
- [Source: Sources/OpenAgentSDK/Types/ToolDeclaration.swift:1-150] — 29.4 已建的 ToolDeclaration / ToolDeclarationStatus / ToolDeclarationDiagnostics（本 story 同文件追加）
- [Source: Sources/OpenAgentSDK/Skills/SkillLoader.swift:372-507] — parseToolDeclarations + tokenizeToolDeclaration + splitBaseAndPattern + isMCPNamespacedName + ClaudeCodeToolNames（Task 5 上提目标）
- [Source: Sources/OpenAgentSDK/Skills/SkillLoader.swift:326-345] — parseAllowedTools 旧解析器（本 story 不动）
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:157-174] — filterTools 字符串版（Task 2 改造目标）
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:14-23] — SubAgentLauncherNames（29.2，本 story 保留）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:1009-1057] — assembleFullToolPool（Task 3.3 加 declarations 过滤）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:1255-1285] — executeSkill tool restrictions 应用（Task 3.1 改造）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:1322-1364] — executeSkillStream tool restrictions 应用（Task 3.1 改造）
- [Source: Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift:123-126] — SkillTool allowedTools 元数据（Task 4 增强）
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift:113-133] — filterTools 字符串版（本 story 不删，并行存在）
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift:150-178] — assembleToolPool（签名不变）
- [Source: Sources/OpenAgentSDK/Tools/ToolRestrictionStack.swift:42-82] — ToolRestrictionStack（本 story 不改）
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift:49-51] — MCP namespaced name 生成
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift:85,90] — Skill.toolDeclarations / toolDeclarationDiagnostics（29.4 已建）
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions struct（Task 3.2 加字段）
- [Source: Sources/OpenAgentSDK/OpenAgentSDK.swift:121-127] — Skill System 公共 surface 文档区段
- [Source: Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift:254-374] — 29.2 filterTools 测试（Task 6.2 扩展点）
- [Source: Tests/OpenAgentSDKTests/Tools/ToolRegistryTests.swift:185-280] — filterTools 字符串版测试（回归保护）
- [Source: Tests/OpenAgentSDKTests/Tools/ToolRestrictionStackTests.swift] — 28 个 stack 测试（回归保护）

## Dev Agent Record

### Agent Model Used

Claude (bmad-dev-story skill, yolo mode)

### Debug Log References

- `swift build`: clean, 0 errors, 0 new warnings (82 pre-existing warnings unchanged — all in unrelated code paths: `execute(_:input:)` unused results, `sessionStore`/`subtype`/`traceStepIndex` unused vars in Agent.swift).
- ATDD focused run: `swift test --filter "ToolDeclarationFilterTests|DefaultSubAgentSpawnerTests|SkillToolTests|ExecuteSkillTests"` → 70 tests, 0 failures.
- Full regression: `swift test` → 5764 tests, 0 failures (baseline 5738 + 26 new ATDD tests = 5764, matches exactly).

### Completion Notes List

All 7 tasks complete. Implementation summary:

1. **Task 1 (helper + diagnostics)** — Added `ToolFilterDiagnostics`, `ToolFilterOptions`, and `filterToolsByDeclarations(available:allowed:disallowed:options:)` to `Types/ToolDeclaration.swift`. Pure function, no I/O. Matches by lowercased base name; never falls back to unrestricted (Epic 29 red line honored — empty pool + diagnostics when all allowed are unmatched). No `SubAgentLauncherNames` import (launcher stripping stays in the caller).

2. **Task 2 (spawner rewiring)** — `DefaultSubAgentSpawner.filterTools` now strips launchers via `SubAgentLauncherNames` FIRST (29.2 behavior preserved), then converts `[String]?` → `[ToolDeclaration]?` via `ToolDeclaration.fromToolNames` and delegates to the helper. Fixes two bugs in the legacy path: (a) case-sensitivity (`bash` now matches `Bash`), (b) `Bash(git diff:*)` as an allowed entry now matches by base name instead of dropping Bash. Kept `filterToolsForTesting` signature intact for 29.2 regression tests; added `filterToolsWithDiagnosticsForTesting` returning the full tuple for 29.5 tests. Diagnostics discarded at spawner boundary (deferred-field surfacing belongs to 29.6, per Dev Notes).

3. **Task 3 (skill execution path)** — `executeSkill` and `executeSkillStream` now prefer `skill.toolDeclarations` (lossless) and fall back to `skill.toolRestrictions` (enum-only) when declarations are nil. Added `AgentOptions.allowedToolDeclarations: [ToolDeclaration]?` field (default nil, set in both inits). Both skill paths save/restore the new field alongside `savedAllowedTools`. `assembleFullToolPool` now funnels all 3 return paths through a new `applyAllowedDeclarations(to:options:)` helper that applies `filterToolsByDeclarations` when `allowedToolDeclarations` is non-empty.

4. **Task 4 (SkillTool metadata)** — Added a `toolDeclarations` key to the `[String: Any]` result dict when `skill.toolDeclarations != nil`. Each entry carries `rawName`/`normalizedName`/`status`/`hasToolRestriction` plus `pattern` (omitted when nil, nil-safe). Legacy `allowedTools` rawValues preserved for backward compatibility. When declarations are nil, no new key is introduced.

5. **Task 5 (hoist tokenizer)** — Moved `tokenizeToolDeclaration` / `splitBaseAndPattern` / `isMCPNamespacedName` / `ClaudeCodeToolNames` from `SkillLoader.swift` (private static) into `ToolDeclaration.swift` as `ToolDeclaration.parse(_:)` (public) + file-private helpers. `SkillLoader.parseToolDeclarations` now calls `ToolDeclaration.parse`. `parseAllowedTools` (legacy) untouched. Behavior identical — only code location changed.

6. **Task 6 (tests)** — 26 new ATDD tests across 4 files all compile and pass: 15 in the new `ToolDeclarationFilterTests.swift`, 5 in `DefaultSubAgentSpawnerTests` (29.5 section), 2 in `SkillToolTests`, 4 in `ExecuteSkillTests`. All existing regression suites pass: `ToolRestrictionStackTests` (28), `ToolRegistryTests.filterTools_*`, `DefaultSubAgentSpawnerTests` 29.2 filter tests (5), `SkillLoaderTests.parseToolDeclarations_*` (10).

7. **Task 7 (build + regression)** — `swift build` clean (0 new warnings). `swift test` 5764/5764 passing.

### File List

Modified:
- `Sources/OpenAgentSDK/Types/ToolDeclaration.swift` — added `ToolFilterOptions`, `ToolFilterDiagnostics`, `filterToolsByDeclarations`, `ToolDeclaration.parse(_:)`, `ToolDeclaration.fromToolNames(_:)`, and file-private tokenizer helpers (hoisted from SkillLoader).
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` — added `AgentOptions.allowedToolDeclarations: [ToolDeclaration]?`; initialized in both inits.
- `Sources/OpenAgentSDK/Skills/SkillLoader.swift` — `parseToolDeclarations` now calls `ToolDeclaration.parse`; removed the hoisted private `tokenizeToolDeclaration` / `splitBaseAndPattern` / `isMCPNamespacedName` / `ClaudeCodeToolNames` (moved to ToolDeclaration.swift).
- `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift` — `filterTools` rewired to consume `filterToolsByDeclarations` (after `SubAgentLauncherNames` stripping); added `filterToolsWithDiagnosticsForTesting`.
- `Sources/OpenAgentSDK/Core/Agent.swift` — `executeSkill` / `executeSkillStream` prefer `toolDeclarations` (fallback `toolRestrictions`); `assembleFullToolPool` applies declaration filtering via new `applyAllowedDeclarations(to:options:)`.
- `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift` — metadata dict gains `toolDeclarations` when present.
- `Sources/OpenAgentSDK/OpenAgentSDK.swift` — Skill System doc index for `ToolFilterDiagnostics` / `filterToolsByDeclarations`.

Created:
- `Tests/OpenAgentSDKTests/Types/ToolDeclarationFilterTests.swift` — 15 new unit tests for the helper.

Extended (ATDD red-phase tests written in Step 2, now green):
- `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` — 5 new 29.5 tests + `makeStubTool` helper.
- `Tests/OpenAgentSDKTests/Tools/Advanced/SkillToolTests.swift` — 2 new 29.5 tests.
- `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift` — 4 new 29.5 tests.

Unchanged (regression-protected, per AC7): `Tools/ToolRegistry.swift`, `Tools/ToolRestrictionStack.swift`, `Skill.toolRestrictions` enum, all 6 BuiltInSkills initializers.

## Change Log

| Date       | Version | Description                                                        | Author       |
|------------|---------|--------------------------------------------------------------------|--------------|
| 2026-06-14 | 0.1     | Initial story creation (Story 29.5 of Epic 29 — Shared Filtering for Skill and Subagent Tool Sets). | create-story |
| 2026-06-14 | 0.2     | Implemented all 7 tasks. Added `filterToolsByDeclarations` helper + `ToolFilterDiagnostics`; rewired `DefaultSubAgentSpawner.filterTools`; migrated `executeSkill`/`executeSkillStream` to prefer `toolDeclarations`; enriched SkillTool metadata; hoisted tokenizer from SkillLoader to ToolDeclaration. 5764 tests passing (5738 baseline + 26 new ATDD). | dev-story (yolo) |
| 2026-06-14 | 0.3     | Code review (yolo): applied 3 fixes from adversarial review — (1) CRITICAL MCP `normalizedName` casing consistency so mixed-case MCP declarations match the lowercased available set; (2) HIGH `executeSkill`/`executeSkillStream` declaration path now clears `options.allowedTools` to prevent double-filtering that would drop MCP tools when the host had a pre-set allowlist; (3) HIGH `fromToolNames` skips empty/whitespace tokens and trims surrounding whitespace. Added 6 regression tests. 5769 tests passing (5764 + 5 new). | code-review (yolo) |

## Review Findings

Code review run 2026-06-14 (yolo mode) via `bmad-code-review`. Three parallel layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor). All 8 acceptance criteria satisfied; all 5 red lines honored (verified by Acceptance Auditor). 3 patch findings applied; 1 finding deferred; 1 dismissed.

### Patches applied (fixed in code review)

- [x] [Review][Patch] **CRITICAL — MCP `normalizedName` casing asymmetry broke AC3 for mixed-case MCP names** [`Sources/OpenAgentSDK/Types/ToolDeclaration.swift:149`] — `filterToolsByDeclarations` lowercases available tool names (`$0.name.lowercased()`) but the MCP branch of `parse` stored `normalizedName: baseName` verbatim (preserving original case). For any mixed-case MCP declaration (e.g. `mcp__GitHub__ListPRs`), the allow filter never matched and the pool was silently emptied — directly violating the "never silently unrestricted" red line for non-lowercase MCP server/tool names. Fixed by lowercasing `baseName` in the MCP branch (consistent with the SDK and unknown branches). `rawName` still preserves the original case for diagnostics.
- [x] [Review][Patch] **HIGH — declaration path did not clear `options.allowedTools`, causing double-filter regression** [`Sources/OpenAgentSDK/Core/Agent.swift:1288` and `:1360`] — when `executeSkill`/`executeSkillStream` took the `toolDeclarations` branch, they left any pre-existing `options.allowedTools` intact. `assembleFullToolPool` then ran the legacy `assembleToolPool(..., allowed: options.allowedTools, ...)` filter FIRST, which dropped MCP/custom tools from the pool before `applyAllowedDeclarations` could see them — defeating the headline purpose of AC5 whenever the host had a non-nil `allowedTools`. Fixed by setting `options.allowedTools = nil` on the declaration branch (defer/onTermination restore `savedAllowedTools`, so the host's value is preserved across the call).
- [x] [Review][Patch] **HIGH — `fromToolNames` did not filter empty/whitespace tokens** [`Sources/OpenAgentSDK/Types/ToolDeclaration.swift:195`] — empty and whitespace-only entries in a subagent `allowed_tools` list produced phantom `.unknown` declarations that polluted `unmatchedDeclarations`. Fixed by trimming and filtering empty entries before parsing (mirrors `SkillLoader.parseToolDeclarations`'s own filtering).

### Deferred (pre-existing or out-of-scope)

- [x] [Review][Defer] **MEDIUM — restore race on `options` mutations during concurrent `executeSkillStream`** [`Sources/OpenAgentSDK/Core/Agent.swift:1383-1395`] — `Agent` is `@unchecked Sendable` and `options` is a `var` struct; the streaming path has two restore points (Task body completion + `onTermination`) that can race. This pattern was pre-existing for `allowedTools`; Story 29.5 cloned it for `allowedToolDeclarations`. No new category of race introduced. Deferred — addressing it requires architectural work on `Agent`'s concurrency model, out of scope for this story.
- [x] [Review][Defer] **MEDIUM — stray `)` and `__` inside MCP tool names are edge cases the parser does not gracefully normalize** [`Sources/OpenAgentSDK/Types/ToolDeclaration.swift:204-241`] — `parse("Bash)")` leaves the paren in the base name; MCP tool names containing `__` defeat `isMCPNamespacedName`'s strict 2-part check. These are spec-level edge cases (MCP spec does not forbid `__`; Claude Code `Bash)` form is malformed). Deferred — requires parser semantics decisions best made with a broader test corpus.
- [x] [Review][Defer] **LOW — `patternDeclarations` de-dup by `rawName` and `unmatchedDeclarations` not de-duped** [`Sources/OpenAgentSDK/Types/ToolDeclaration.swift:395-415`] — duplicate allowed entries (`["Read", "Read"]`) appear twice in `unmatchedDeclarations`; same-pattern declarations with different casing appear as separate `patternDeclarations`. Diagnostics noise only; filtering behavior is correct. Deferred — cosmetic improvement.

### Dismissed

- [x] [Review][Dismiss] **LOW — `_ = options ?? ToolFilterOptions()` is dead code** — intentional per spec Task 1.2 (the `options:` parameter is reserved for forward extension; `ToolFilterOptions` is an intentionally empty shell per the corrected design decision in Dev Notes). Not a defect.

### Red lines verified honored

1. ✅ `ToolRegistry.filterTools` (Tools/ layer) signature unchanged, not deleted (`Sources/OpenAgentSDK/Tools/ToolRegistry.swift:113`).
2. ✅ No `.task` case added to `ToolRestriction` enum — `Task` matched via `knownClaudeCodeOnly = ["task"]` string set (`Sources/OpenAgentSDK/Types/ToolDeclaration.swift:255`).
3. ✅ Launcher stripping stays in `DefaultSubAgentSpawner` (line 172), NOT in the helper. `filterToolsByDeclarations` contains zero launcher logic.
4. ✅ When allowed declarations are all unmatched, helper returns EMPTY pool (`ToolDeclaration.swift:381` `available.filter { allowedSet.contains(...) }`), never unrestricted fallback.
5. ✅ Sibling code paths consistent — `executeSkill`, `executeSkillStream`, and `assembleFullToolPool` all route through `applyAllowedDeclarations` → `filterToolsByDeclarations`; both skill paths save/restore `savedAllowedDeclarations`.

### Test re-runs after fixes

- `swift build` — clean, 0 new warnings.
- `swift test --filter "ToolDeclarationFilterTests|DefaultSubAgentSpawnerTests|ExecuteSkillTests|ExecuteSkillStreamTests|SkillToolTests|SkillLoaderTests|ToolRegistryTests|SkillTypesTests"` — 185 tests, 0 failures.
- `swift test` (full suite) — 5769 tests, 0 failures (baseline 5764 + 5 new regression tests added during review).

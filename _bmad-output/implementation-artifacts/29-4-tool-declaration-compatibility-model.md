# Story 29.4: Tool Declaration Compatibility Model

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a skill/subagent author,
I want tool declarations (`allowed-tools`, subagent `tools`/`disallowedTools`) to preserve Claude Code-style tool names, MCP namespaced tools, permission patterns, and custom/raw tool names,
so that restrictions do not silently lose intent — and unknown names never collapse to "unrestricted".

## Context & Scope

**这是 Epic 29（Claude Code Skill/Subagent Compatibility）的第 4 个 story**，位于 epic 依赖图中 29.3 的下游、29.5 的上游（参见 epic 文档 "Story 间依赖关系"）。29.1 / 29.2 / 29.3 已 DONE，为本 story 提供完整运行时基础（`createTaskTool()` alias、`SubAgentLauncherNames` 检测、skill package context prompt）。

**为什么需要这个 story：** 当前 `SkillLoader.parseAllowedTools(_:)`（SkillLoader.swift:326-345）只做一件事：用正则 `(\w+)(?:\([^)]*\))?` 提取工具名，**小写化**后与 `ToolRestriction` enum 的 rawValue（`bash`/`read`/`webFetch`/...）做**精确匹配**。不匹配的名字被**静默丢弃**。这导致三类问题：

1. **MCP 工具被丢弃**：`allowed-tools: mcp__github__list_prs` 的 `mcp__github__list_prs` 含双下划线，`\w+` 只抓到第一个下划线前的片段，小写后与任何 enum case 不匹配 → 被丢弃。运行时该工具不可用。
2. **未知工具被丢弃 + 静默放权**：`allowed-tools: UnknownTool` 解析后 `restrictions` 数组为空 → `parseAllowedTools` 返回 `nil`（SkillLoader.swift:344）。而 `nil` 在运行时语义是**unrestricted（全部工具可用）**（SkillTypes.swift:69-70 "nil means all tools are available"、Agent.swift:1260-1262）。这就是 epic 文档反复强调的"不静默放权"红线被违反。
3. **权限 pattern 文本丢失**：`allowed-tools: Bash(git diff:*)` 的 `git diff:*` 部分被 `(?:\([^)]*\))?` 正则的非捕获组吃掉，只剩 `Bash`。pattern 语义（"只允许运行 git diff"）完全丢失，运行时表现为"允许全部 Bash"。

**本 story 做什么：** 引入一个 richer 的 `ToolDeclaration` 模型，能保留 rawName（原始字符串）、normalizedName（规范化名）、pattern（如 `Bash(git diff:*)` 的参数 pattern）、status/diagnostics（支持/不支持）。保留 MCP namespaced names、custom/raw names、permission pattern text。未知名字必须以 diagnostic 形式可见，**绝不能**因 enum 解析无 case 而 collapse 到 `nil`（unrestricted）。

**本 story 不做什么（Out of Scope）：**
- **不实现 shared filtering helper**（`filterToolsByDeclarations(...)`）→ Story 29.5。本 story 只引入**数据模型**和**解析器**，不改 `DefaultSubAgentSpawner.filterTools(...)` 或 `ToolRestrictionStack`。
- **不实现 fine-grained pattern enforcement**（`Bash(git diff:*)` 的实际参数匹配）→ epic 延后项第 5 条。本 story 只**保留 pattern 文本**并**标注 "parsed but not enforced"**。
- **不破坏现有 `Skill.toolRestrictions: [ToolRestriction]?` 消费者**（Agent.swift:1261/1327、SkillTool.swift:125、ToolRestrictionStack、全部 built-in skill、全部测试）。本 story 提供迁移路径：新增字段 + 保留旧字段。
- **不改 E2E 测试**（E2E 推迟到 Story 29.7，参见 project-context.md #29）。
- **不改 MCP 工具注册路径**（`mcp__{server}__{tool}` 命名已在 MCPToolDefinition.swift:51 正确产生，本 story 只是让解析器**认识**这种名字）。

## Acceptance Criteria

1. **AC1: MCP namespaced 工具声明被保留**
   - **Given** filesystem skill 的 `allowed-tools` frontmatter 值为 `WebSearch, mcp__github__list_prs, Task`
   - **When** `SkillLoader.loadSkillFromDirectory(...)` 加载该 skill（调用 `parseAllowedTools`）
   - **Then** 解析输出（`ToolDeclaration` 数组）保留**全部三个**名字
   - **And** `mcp__github__list_prs` **不被丢弃**（其 `rawName == "mcp__github__list_prs"`）
   - **And** `WebSearch` 和 `Task` 同样以 `rawName` 保留

2. **AC2: 未知工具名不 collapse 为 unrestricted**
   - **Given** filesystem skill 的 `allowed-tools` frontmatter 值为 `UnknownTool`（仅含一个无法识别的名字）
   - **When** skill 被 `SkillLoader` 加载
   - **Then** SDK 暴露一个 diagnostic（`ToolDeclaration.status` 或独立 diagnostics 列表），标注 `UnknownTool` 为不支持
   - **And** 运行时**不会**因为 enum 解析无 case 而把该 skill 当作 unrestricted —— 解析输出非 nil（即使所有声明都是 unknown），调用方能据此判定"这是显式受限但无可用工具"而非"无限制"
   - **And** 现有 `Skill.toolRestrictions: [ToolRestriction]?` 字段在该场景下保持其**当前行为**（若 `UnknownTool` 无法映射到 enum，旧字段为 `nil`），但**新增**字段（declarations）非空，提供正确的诊断信号

3. **AC3: Permission pattern 文本被保留并标注**
   - **Given** filesystem skill 的 `allowed-tools` frontmatter 值为 `Bash(git diff:*)`
   - **When** skill 被 `SkillLoader` 加载
   - **Then** raw pattern 文本 `Bash(git diff:*)` 被保留（`ToolDeclaration.rawName` 或 `pattern` 字段）
   - **And** 调用方可见"pattern 已解析但未在 pattern 粒度强制执行"的信号（diagnostic 或 status）
   - **And** `Bash` 部分被正确识别为已知工具（normalizedName == "bash" 或 rawName 识别出 base name）

4. **AC4: 向后兼容 —— 现有 `Skill.toolRestrictions` 字段与全部消费者无回归**
   - **Given** 本 story 的所有改动完成
   - **When** `swift build` 和 `swift test` 运行
   - **Then** `Sources/OpenAgentSDK/Core/Agent.swift:1260-1262`（`options.allowedTools = restrictions.map(\.rawValue)`）和 `:1326-1328` 无需修改即可继续编译并保持现有行为
   - **And** `SkillTool.swift:124-126`、`ToolRestrictionStack.swift` 全部方法签名不变
   - **And** 全部 6 个 BuiltInSkills（commit/review/simplify/debug/test）的 `toolRestrictions: [.bash, .read, ...]` 初始化无回归
   - **And** 全部现有 `SkillLoaderTests`、`ToolRestrictionStackTests`、`ExecuteSkill*Tests`、`SkillToolTests`、`SkillTypesTests` 测试继续通过

5. **AC5: 常见 SDK/Claude 工具名被识别**
   - **Given** `allowed-tools` 含 `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash`, `WebFetch`, `WebSearch`, `ToolSearch`, `AskUser`, `Skill`, `Agent`, `Task` 中的任意子集
   - **When** 被解析
   - **Then** 每个名字的 `ToolDeclaration` 都被标记为"已识别的 SDK built-in"（status == recognized / normalized）
   - **And** 这些名字能同时映射到旧的 `ToolRestriction` enum（用于 `toolRestrictions` 字段向后兼容）—— **注意**：`Agent` 和 `Task` 目前**不在** `ToolRestriction` enum 中（ToolRestriction.swift:12-35 只有 `.agent`，没有 `.task`），本 story 应在解析时处理这个 gap（参见 Dev Notes 的 "ToolRestriction gap" 小节）

6. **AC6: Build 与全量回归**
   - **Given** 本 story 的所有改动完成
   - **When** `swift build` 和 `swift test` 运行
   - **Then** 构建零新警告，全部测试通过
   - **And** 完成记录中包含新的总测试数（Story 29.3 baseline: 5720 tests passing）

## Tasks / Subtasks

- [x] Task 1: 设计并引入 `ToolDeclaration` 模型（AC: #1, #2, #3, #5）
  - [x] 1.1 新建文件 `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`。模块位置选 `Types/` 的理由（来自 epic 29.5 readiness review 决策）：**唯一**同时满足"Core/（DefaultSubAgentSpawner）可调用"且"Tools/（SkillTool）可调用"的层。`Core/` 不依赖 `Tools/`，`Tools/` 不依赖 `Core/`（project-context.md #7），故模型必须放在两者都能 import 的 `Types/`（叶节点）。
  - [x] 1.2 定义 `public struct ToolDeclaration: Sendable, Equatable`，至少包含：
    - `rawName: String` —— frontmatter 中的原始文本片段（如 `"mcp__github__list_prs"`、`"Bash(git diff:*)"`、`"WebSearch"`）
    - `normalizedName: String` —— 规范化后的 base name（小写、去 pattern 括号）。对 `Bash(git diff:*)` → `"bash"`；对 `mcp__github__list_prs` → `"mcp__github__list_prs"`（MCP 全名本身就是 normalized 形式，不应截断）；对 `WebSearch` → `"websearch"`
    - `pattern: String?` —— 参数 pattern（如 `"git diff:*"`），无 pattern 时为 nil
    - `status: ToolDeclarationStatus` —— 枚举：`.recognizedSDK`（映射到 ToolRestriction）/ `.recognizedMCP`（匹配 `mcp__<server>__<tool>`）/ `.recognizedCustom`（host 注册的自定义工具名，本 story 无法在解析时知道，故全部自定义名先标 `.custom`）/ `.unknown`（无法识别）。**关键**：`.unknown` **不是** unrestricted，而是"显式声明但当前不可解析"
    - `toolRestriction: ToolRestriction?` —— 若该声明能映射到现有 enum（如 `Bash` → `.bash`），提供映射；否则 nil（用于向后兼容 `toolRestrictions` 字段）
  - [x] 1.3 定义 `public enum ToolDeclarationStatus: String, Sendable, Equatable`：`case recognizedSDK`, `case recognizedMCP`, `case recognizedCustom`, `case unknown`
  - [x] 1.4 定义 `public struct ToolDeclarationDiagnostics: Sendable, Equatable`（本 story 的诊断载体，为 29.5 的 `ToolFilterDiagnostics` 预留同源模式）：至少 `let unsupportedDeclarations: [ToolDeclaration]`（status == `.unknown`）和 `let patternDeclarations: [ToolDeclaration]`（含 pattern 但 pattern 未强制执行的声明）。
  - [x] 1.5 在 `OpenAgentSDK.swift` public surface 注释（约 121-127 行的 "Skill System" 区段）追加 `ToolDeclaration` / `ToolDeclarationStatus` 的文档索引。**注意**：`@testable import` 已能访问 internal/public，无需手动 `@_exported`，因为这些类型将直接声明为 `public`。

- [x] Task 2: 扩展 `Skill` struct 携带 richer 声明（AC: #4）
  - [x] 2.1 在 `Sources/OpenAgentSDK/Types/SkillTypes.swift` 的 `Skill` struct 中新增**可选**字段 `public let toolDeclarations: [ToolDeclaration]?`（默认 nil）和 `public let toolDeclarationDiagnostics: ToolDeclarationDiagnostics?`（默认 nil）。**必须保持现有 `toolRestrictions: [ToolRestriction]?` 字段不变**（向后兼容，AC4）。
  - [x] 2.2 更新 `Skill.init(...)`：新增 `toolDeclarations: [ToolDeclaration]? = nil` 和 `toolDeclarationDiagnostics: ToolDeclarationDiagnostics? = nil` 参数，放在 `toolRestrictions` 之后、`modelOverride` 之前。**所有现有调用方（6 个 BuiltInSkills、测试 helper、SkillLoader）的 init 调用必须保持编译**——因为新参数有默认值 nil。
  - [x] 2.3 更新 `Skill.withBaseDir(_:)`（SkillTypes.swift:158-174）：复制时携带新字段。
  - [x] 2.4 更新 `Skill.==`（SkillTypes.swift:176-189）：加入 `toolDeclarations` 和 `toolDeclarationDiagnostics` 的相等性判断。
  - [x] 2.5 **不**在 `ToolRestriction` enum 中新增 `.task` case（参见 Dev Notes "ToolRestriction gap"）—— 本 story 通过 `ToolDeclaration.toolRestriction` 映射来处理 `Task`，避免 enum 扩张影响序列化/迁移。

- [x] Task 3: 重写 `parseAllowedTools` 为声明保留解析器（AC: #1, #2, #3, #5）
  - [x] 3.1 在 `Sources/OpenAgentSDK/Skills/SkillLoader.swift` 新增 `static func parseToolDeclarations(_ allowedTools: String?) -> (declarations: [ToolDeclaration], diagnostics: ToolDeclarationDiagnostics)?`。**保留**现有 `parseAllowedTools(_:) -> [ToolRestriction]?` **完全不变**（AC4：现有测试 testParseAllowedTools_* 必须继续通过）。新解析器内部可以调用旧解析器来判定 SDK 可识别名，或独立实现。
  - [x] 3.2 新解析器的正则策略：用 `([^,\s]+(?:\([^)]*\))?)` 按逗号/空格切分，保留每个 token 的完整文本（含括号 pattern）。**注意**：现有正则 `(\w+)(?:\([^)]*\))?` 的 `\w+` 会**截断** `mcp__github__list_prs`（`\w` 含下划线，故实际不截断 —— 验证一下；但 `\w+` 仍会吃掉第一个 `(`，需确认 MCP 名无括号）。对新解析器，优先用 "split on comma then trim" 策略而非全局正则，更稳健地保留含特殊字符的 token。
  - [x] 3.3 对每个 token，识别其 status：
    - 若匹配 `^mcp__[^_]+__[^_]+$`（或更宽松的 `^mcp__.+__.+$`）→ `.recognizedMCP`，normalizedName = rawName（保留全名）
    - 若 base name（去括号后小写）在 `ToolRestriction.allCases.map(\.rawValue)` 中 → `.recognizedSDK`，映射 toolRestriction
    - 若 base name 在已知的 Claude Code LLM-facing 名集合（`Read/Write/Edit/Glob/Grep/Bash/WebFetch/WebSearch/ToolSearch/AskUser/Skill/Agent/Task`，参见 epic 实施步骤第 3 条）中 → 仍标 `.recognizedSDK`（即使 `ToolRestriction` enum 无对应 case，如 `Task`），toolRestriction = nil 但 normalizedName 已规范化
    - 否则 → `.unknown`
  - [x] 3.4 pattern 提取：若 token 含 `(...)`，提取括号内内容为 `pattern`（如 `"git diff:*"`），base name 为括号前部分。
  - [x] 3.5 diagnostics 组装：status == `.unknown` 的 → `unsupportedDeclarations`；pattern != nil 的 → `patternDeclarations`（即使 base 是 recognizedSDK，pattern 仍标"parsed but not enforced"）。
  - [x] 3.6 **关键非 nil 语义**：若 `allowedTools` 非空且非 nil，`parseToolDeclarations` 返回的元组**永远非 nil**（即使所有声明都是 unknown）。这与旧 `parseAllowedTools` 返回 nil（=unrestricted）的语义**相反**，是本 story 修正"静默放权"的核心。

- [x] Task 4: 在 `SkillLoader.loadSkillFromDirectory` 中填充新字段（AC: #1, #2, #3）
  - [x] 4.1 在 SkillLoader.swift:99-114 的 `loadSkillFromDirectory` 中，调用新解析器 `parseToolDeclarations(frontmatter["allowed-tools"])`，将结果填充到 `Skill(toolDeclarations:..., toolDeclarationDiagnostics:...)`。
  - [x] 4.2 **保留**第 99 行 `let toolRestrictions = parseAllowedTools(frontmatter["allowed-tools"])` 不变，仍传给 `Skill(toolRestrictions: toolRestrictions, ...)`（AC4：`Skill.toolRestrictions` 字段保持当前填充逻辑）。
  - [x] 4.3 确认 `Skill` 同时携带 `toolRestrictions`（旧，可能 nil 即 unrestricted）和 `toolDeclarations`（新，非 nil 即"显式声明集"）。**调用方迁移到 `toolDeclarations` 的路径见 29.5**；本 story 仅填充，不强制切换消费方。

- [x] Task 5: 扩展单元测试（AC: #1, #2, #3, #4, #5）
  - [x] 5.1 在 `Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift` 末尾新增 MARK 区段 `// MARK: - Story 29.4: Tool Declaration Compatibility`。新增测试（unit-level，纯解析，无 I/O 无网络，遵守 project-context.md #27）：
    - `testParseToolDeclarations_preservesMCPNamespacedNames` —— 输入 `"WebSearch, mcp__github__list_prs, Task"`，断言 declarations 含全部三个 rawName，`mcp__github__list_prs` 的 status == `.recognizedMCP`
    - `testParseToolDeclarations_unknownToolNotDropped` —— 输入 `"UnknownTool"`，断言 declarations 非空（count == 1），status == `.unknown`，diagnostics.unsupportedDeclarations 含该声明
    - `testParseToolDeclarations_doesNotCollapseToUnrestricted` —— 输入 `"UnknownTool"`，断言 `parseToolDeclarations` 返回**非 nil**（与旧 `parseAllowedTools` 返回 nil 的语义对比）
    - `testParseToolDeclarations_preservesPatternText` —— 输入 `"Bash(git diff:*)"`, 断言 declarations[0].rawName 含 `"git diff:*"`，pattern == `"git diff:*"`，normalizedName == `"bash"`，toolRestriction == `.bash`，diagnostics.patternDeclarations 非空
    - `testParseToolDeclarations_recognizesClaudeCodeNames` —— 输入 `"Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch, ToolSearch, AskUser, Skill, Agent, Task"`，断言每个都被 `.recognizedSDK`，normalizedName 规范化正确
    - `testParseToolDeclarations_mixedKnownUnknownMCP` —— 输入 `"Bash, UnknownTool, mcp__srv__search"`，断言 3 个 declaration，分别 `.recognizedSDK` / `.unknown` / `.recognizedMCP`，diagnostics.unsupportedDeclarations 只含 UnknownTool
    - `testParseToolDeclarations_emptyAndNil` —— 输入 `nil` 和 `""`，断言返回 nil（无声明，与 unrestricted 区分：nil 输入 = 无 frontmatter 字段，仍是 unrestricted；非空但全 unknown = 显式声明但无可用）
  - [x] 5.2 在 `loadSkillFromDirectory_WithAllowedTools` 现有测试旁新增 `testLoadSkillFromDirectory_populatesToolDeclarations`（SkillLoaderTests.swift:315-328 附近）：加载带 `allowed-tools: Bash(npx foo:*), Read, Write` 的 skill，断言 `skill.toolDeclarations?.count == 3`，`skill.toolDeclarationDiagnostics != nil`，同时**旧字段** `skill.toolRestrictions?.count == 3`（向后兼容未破坏）。
  - [x] 5.3 在 `Tests/OpenAgentSDKTests/Types/SkillTypesTests.swift`（若存在）新增/扩展：验证 `Skill.init` 新参数有默认值（现有调用不破坏）、`withBaseDir` 携带新字段、`==` 比较新字段。若该测试文件不存在，**不要新建**——改在 `SkillLoaderTests` 或新建 focused test。**优先**：检查现有 `SkillTypesTests.swift` 是否存在（grep 确认），存在则扩展，遵循 rule #56。
  - [x] 5.4 **关键回归保护**：确认现有 `testParseAllowedTools_WithArguments`、`testParseAllowedTools_EmptyString`、`testParseAllowedTools_Nil`、`testParseAllowedTools_UnknownToolsIgnored`（SkillLoaderTests.swift:491-518）**继续通过**——这些测试断言旧 `parseAllowedTools` 行为，本 story 不改旧解析器。
  - [x] 5.5 E2E 推迟到 Story 29.7（参见 epic 文档 29.7 节，本 story 不写 E2E）。

- [x] Task 6: 构建与全量回归（AC: #6）
  - [x] 6.1 `swift build` 成功，零新警告
  - [x] 6.2 `swift test` 全量通过；完成记录包含新的总测试数（baseline 5720）
  - [x] 6.3 确认无 Swift 编译器错误引入名为 `Task` 的类型（本 story 引入 `ToolDeclaration` / `ToolDeclarationStatus` / `ToolDeclarationDiagnostics`，均无 `Task` 字样 —— rule #15）
  - [x] 6.4 确认现有 `ToolRestrictionStackTests`（28 个测试）、`ExecuteSkillTests` / `ExecuteSkillStreamTests`、`SkillToolTests`、`SkillLoaderTests`（现有 ~35 个）全部继续通过（无回归）

## Dev Notes

### Architecture Context

这是 **Epic 29 的第 4 个 story**，依赖图中位置：

```
29.1 (DONE)  -->  29.2 (DONE)
                  |
                  +--> 29.3 (DONE)
                  |
                  +--> 29.4 (THIS STORY)  ← 引入 ToolDeclaration 数据模型
                          |
                          +--> 29.5 (Shared filtering)  ← 消费 ToolDeclaration + 加 filter 函数
                                  |
                                  +--> 29.6, 29.7
```

29.4 只**引入数据模型 + 解析器 + 在 Skill 上填充新字段**，**不改**任何消费方（Agent.swift 的 `options.allowedTools` 赋值、DefaultSubAgentSpawner.filterTools、ToolRestrictionStack）。这是精心设计的分层：29.4 让"声明"可表达，29.5 让"过滤"用上新声明。混在一起会破坏 AC4（向后兼容）和模块边界。

### CRITICAL: 当前代码事实（必须先读）

**解析器（本 story 重写目标，但旧版保留）：** `Sources/OpenAgentSDK/Skills/SkillLoader.swift:326-345`

```swift
static func parseAllowedTools(_ allowedTools: String?) -> [ToolRestriction]? {
    guard let allowedTools = allowedTools, !allowedTools.isEmpty else { return nil }
    let pattern = #"(\w+)(?:\([^)]*\))?"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
    let range = NSRange(allowedTools.startIndex..., in: allowedTools)
    let matches = regex.matches(in: allowedTools, options: [], range: range)
    var restrictions: [ToolRestriction] = []
    for match in matches {
        guard let toolRange = Range(match.range(at: 1), in: allowedTools) else { continue }
        let toolName = String(allowedTools[toolRange]).lowercased()
        if let restriction = ToolRestriction.allCases.first(where: { $0.rawValue == toolName }) {
            restrictions.append(restriction)
        }
    }
    return restrictions.isEmpty ? nil : restrictions   // ← BUG：空数组 collapse 成 nil = unrestricted
}
```

**"静默放权" bug 路径**：`allowed-tools: UnknownTool` → `matches` 抓到 `UnknownTool` → lowercased → 不匹配任何 enum → `restrictions` 空 → 返回 `nil` → `Skill.toolRestrictions = nil` → Agent.swift:1260 `if let restrictions = skill.toolRestrictions` 不进入 → `options.allowedTools` 不变（=父级全部工具）→ **skill 实际获得全部工具**，违反 epic "不静默放权" 红线。

**消费方（本 story 不改，但新字段为它们准备）：**
- `Sources/OpenAgentSDK/Core/Agent.swift:1260-1262`（executeSkill）和 `:1326-1328`（executeSkillStream）—— `options.allowedTools = restrictions.map(\.rawValue)`。**29.5 会改这里**消费 `toolDeclarations`。
- `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift:124-126` —— `result["allowedTools"] = restrictions.map(\.rawValue)`。29.5 扩展。
- `Sources/OpenAgentSDK/Tools/ToolRestrictionStack.swift:42-82` —— push/currentAllowedToolNames 基于 `ToolRestriction`。29.5 扩展为支持 declaration。
- `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:157-174` —— `filterTools` 基于 `[String]?`。29.5 改为消费 declarations。

### 关键字段（SkillLoader 填充，本 story 扩展）

`Sources/OpenAgentSDK/Types/SkillTypes.swift`：

| 字段 | 类型 | 默认值 | 由谁填充 | 本 story 是否改动 |
|---|---|---|---|---|
| `toolRestrictions` (行 70) | `[ToolRestriction]?` | `nil` | SkillLoader（旧解析器） | **不改填充逻辑**（AC4） |
| `toolDeclarations` (新增) | `[ToolDeclaration]?` | `nil` | SkillLoader（新解析器） | **新增字段 + 填充** |
| `toolDeclarationDiagnostics` (新增) | `ToolDeclarationDiagnostics?` | `nil` | SkillLoader（新解析器） | **新增字段 + 填充** |

### MCP 工具命名约定（project-context.md #10）

MCP 工具使用 `mcp__{serverName}__{toolName}` 命名（MCPToolDefinition.swift:51 `"mcp__\(serverName)__\(mcpToolName)"`）。**关键**：`mcp__github__list_prs` 中的下划线是名字的一部分，**不能**被 `\w+` 截断到 `mcp`（实际上 `\w` 含下划线，所以 `\w+` 会抓到 `mcp__github__list_prs` 整体——但旧解析器后续 `.lowercased()` + enum 匹配会失败）。新解析器需显式识别 `mcp__` 前缀。

serverName 含 `__` 会被 MCPToolDefinition 的 precondition（MCPToolDefinition.swift:84）拒绝，故 `mcp__` 前缀后**最多一个** `__` 分隔符。新解析器的 MCP 识别正则建议：`^mcp__[^_]+(?:_[^_]+)*__[A-Za-z0-9_-]+$` 或更简单 `^mcp__.+__.+$`（接受任何 server/tool 名组合，运行时由 29.5 的 filter 做精确匹配）。

### ToolRestriction gap（`Task` 不在 enum 中）

`ToolRestriction` enum（SkillTypes.swift:12-35）有 `.agent`（行 23）但**没有** `.task`。这是 Story 29.1 引入 `createTaskTool()` 时**故意**避免 enum 扩张的设计（避免破坏 Codable/序列化 + 迁移负担）。本 story 遵循同一决策：

- `ToolDeclaration.toolRestriction: ToolRestriction?` 对 `Agent` 声明 → 映射 `.agent`
- 对 `Task` 声明 → `toolRestriction = nil`，但 `status = .recognizedSDK`，`normalizedName = "task"`（29.5 的 filter 用 normalizedName 做字符串匹配，不依赖 enum）

**不要**在本 story 给 `ToolRestriction` enum 加 `.task` case。这会连锁影响：序列化测试、ToolRestrictionStack 的 CaseIterable 迭代、所有 switch 语句。

### Claude Code LLM-facing 名 vs SDK 内部名

epic 实施步骤第 3 条明确列出要识别的名字：`Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch, ToolSearch, AskUser, Skill, Agent, Task`。

| LLM-facing 名（frontmatter） | ToolRestriction enum case | 备注 |
|---|---|---|
| `Bash` | `.bash` | |
| `Read` | `.read` | |
| `Write` | `.write` | |
| `Edit` | `.edit` | |
| `Glob` | `.glob` | |
| `Grep` | `.grep` | |
| `WebFetch` | `.webFetch` | |
| `WebSearch` | `.webSearch` | |
| `ToolSearch` | `.toolSearch` | |
| `AskUser` | `.askUser` | |
| `Skill` | `.skill` | |
| `Agent` | `.agent` | |
| `Task` | **无** | 29.1 引入，未加 enum case |

新解析器维护这张映射表（可内联为 switch 或字典）。`normalizedName` 统一为小写无括号形式（`"bash"`、`"mcp__github__list_prs"`），便于 29.5 的 filter 做大小写不敏感匹配。

### Module Boundary Compliance (project-context.md #7)

- `ToolDeclaration.swift` 放在 `Types/`（叶节点，无出站依赖）—— ✅ 符合
- `ToolDeclaration` 只依赖 `Foundation`（基础类型 String/Optional）+ `ToolRestriction`（同在 Types/）—— ✅ 无跨层依赖
- `SkillLoader`（Skills/）→ 依赖 `Types/`（Skill, ToolRestriction, 新 ToolDeclaration）—— ✅ Skills/ 可 import Types/
- **不**在 `Tools/` 或 `Core/` 放模型 —— 它们无法互相 import

### Anti-Patterns to Avoid (project-context.md)

- ❌ **不要破坏 `parseAllowedTools` 旧签名/行为** —— 现有 4 个 testParseAllowedTools_* 测试 + loadSkillFromDirectory_WithAllowedTools 必须继续通过（AC4）。新增 `parseToolDeclarations` 并存。
- ❌ **不要让"全 unknown"输入返回 nil** —— 这是本 story 修正的核心 bug（AC2）。`parseToolDeclarations("UnknownTool")` 返回非 nil 元组。
- ❌ **不要给 `ToolRestriction` enum 加 `.task`** —— 见 ToolRestriction gap 小节。
- ❌ **不要 force-unwrap (`!`)** —— rule #40，用 guard let
- ❌ **不要用 Set** —— declarations 顺序必须保持 frontmatter 顺序（rule #46），用 Array
- ❌ **不要内联 JSONEncoder/Decoder** —— 解析器是纯字符串→struct 转换，无序列化（rule #48）
- ❌ **不要命名为 `Task` 开头的类型** —— 如 `TaskDeclaration` 违反 rule #15；用 `ToolDeclaration`
- ❌ **不要在本 story 改 Agent.swift / SkillTool.swift / ToolRestrictionStack.swift / DefaultSubAgentSpawner.swift 的消费逻辑** —— 这是 29.5 的范围。本 story 只填数据。
- ❌ **不要写真实网络/文件 I/O 测试** —— 解析器是纯函数，输入字符串输出 struct（rule #27）
- ❌ **不要新建独立测试文件** —— 复用现有 SkillLoaderTests.swift + SkillTypesTests.swift（rule #56）

### Testing Standards

- XCTest only（rule #23）
- 测试目录结构镜像源码：`parseToolDeclarations` 是 SkillLoader 的 static method → 测试在 `Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift`；`ToolDeclaration` 类型在 Types/ → 若需独立类型测试在 `Tests/OpenAgentSDKTests/Types/`（检查 SkillTypesTests.swift 是否存在并扩展）
- 纯函数测试：`parseToolDeclarations` 无副作用，直接 `let result = SkillLoader.parseToolDeclarations(...)` 断言返回值
- `await` 用于 actor 隔离方法 —— 本 story 无 actor 交互
- E2E 推迟到 Story 29.7（rule #29 + epic 29.7 明确列出 SkillLoader parser tests 是单元测试目标）

### Previous Story Intelligence (Story 29.3)

Story 29.3（commit dc49d54）完成于 2026-06-14，5720 tests passing。关键学习对本 story 适用：

- **"新增字段有默认值，保留旧字段"的迁移模式在 Types/ 工作良好** —— 29.3 没改 SkillTypes（字段已存在）；本 story 是**新增**字段。模式：新参数放末尾 + 默认 nil → 所有现有 init 调用编译通过。
- **不改旧解析器、新增并存函数的"并行迁移"模式** —— 29.3 抽 helper 而非重写内联逻辑；本 story 新增 `parseToolDeclarations` 而**不**改 `parseAllowedTools`。两者都是为了 AC4 向后兼容。
- **mock URL protocol 扩展而非新建是已验证模式**（29.3 的 SkillStreamMockURLProtocol.lastRequestBody）—— 本 story 无需 mock URL protocol（解析器是纯函数），但若要测 `loadSkillFromDirectory` 端到端填充新字段，复用现有 TempDirTestCase + createSkillDir helper（SkillLoaderTests.swift:15-47）。
- **AC6 "全量回归 + 报告总测试数" 是 Epic 29 硬性要求**（参见 epic 29.7 AC 第 1 条）。

### Previous Story Intelligence (Story 29.1 / 29.2)

- **29.1（commit 923bd6b, 5695 tests）**：抽 `createSubAgentLauncherTool(name:description:)` shared factory；Tool 名 `"Task"` 是字符串，Swift 类型用 `SubAgentLauncherInput`（非 `TaskToolInput`）。本 story 同理：类型名用 `ToolDeclaration`（非 `TaskDeclaration`），`"Task"` 是声明里的字符串值。
- **29.2（commit 5dd0ea2, 5706 tests）**：抽 `SubAgentLauncherNames` enum 集中管理 `["Agent", "Task"]`。本 story 的 Claude Code 名识别表可类似集中（但作为 private static let 或 inline switch，避免过度抽象）。

### Git Intelligence (recent commits)

```
dc49d54 feat(core): inject skill package context into direct skill execution (Story 29-3)
fbf001c fix(core): propagate sub-agent toolCalls from QueryResult.toolPairs
ee158e9 chore: add BMAD agent workspace config (skills, hooks, AGENTS.md)
5dd0ea2 feat(core): unify Agent/Task spawner detection and child filtering (Story 29-2)
923bd6b feat(tools): add createTaskTool() as Claude Code Task alias (Story 29-1)
```

`dc49d54`（29.3）只改了 `Agent.swift` 的 `resolveSkillForExecution` 区段，未触碰 SkillLoader.swift 或 SkillTypes.swift —— 本 story 的目标文件（SkillLoader.swift:326-345, SkillTypes.swift:56-189）自 29.1/29.2 以来未被 Epic 29 改动，处于干净状态。

### Latest Technical Information

- **Swift 5.9+ typed throws** —— 解析器是同步纯函数，无 throws 需求（rule #6 不适用）。正则编译用 `try? NSRegularExpression` 容错（与现有 parseAllowedTools 一致）。
- **`NSRegularExpression` 在 Linux 可用** —— Foundation 跨平台（rule #44），SkillLoader.swift 已用此 API。
- **String 切分策略** —— `allowedTools.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }` 比 regex 更稳健地保留含特殊字符的 token（如 `Bash(git diff:*)`）。现有 parseAllowedTools 用 regex 是因为它只关心 base name；新解析器要保留完整 token，切分法更合适。
- **不引入新外部依赖** —— 仅 Foundation + 现有 ToolRestriction 类型。

### ToolDeclaration 数据模型设计参考

```swift
// Sources/OpenAgentSDK/Types/ToolDeclaration.swift

import Foundation

public enum ToolDeclarationStatus: String, Sendable, Equatable {
    case recognizedSDK    // 映射到 ToolRestriction 或已知 Claude Code 名
    case recognizedMCP    // mcp__<server>__<tool>
    case recognizedCustom // host 自定义工具名（本 story 无法在解析时区分 custom vs unknown，可合并到 unknown，由 29.5 filter 时按 available tools 判定）
    case unknown          // 无法识别，但显式声明（非 unrestricted）
}

public struct ToolDeclaration: Sendable, Equatable {
    public let rawName: String              // "Bash(git diff:*)" / "mcp__github__list_prs" / "WebSearch"
    public let normalizedName: String       // "bash" / "mcp__github__list_prs" / "websearch"
    public let pattern: String?             // "git diff:*" / nil
    public let status: ToolDeclarationStatus
    public let toolRestriction: ToolRestriction?  // .bash / nil (Task 无 enum case)
}

public struct ToolDeclarationDiagnostics: Sendable, Equatable {
    public let unsupportedDeclarations: [ToolDeclaration]   // status == .unknown
    public let patternDeclarations: [ToolDeclaration]       // pattern != nil (parsed but not enforced)
}
```

**设计权衡：**
- `recognizedCustom` vs `unknown`：解析时无法知道 host 注册了哪些自定义工具（那是运行时信息）。两种选择：(a) 全部非 MCP、非 SDK、非 Claude Code 名都标 `.unknown`，由 29.5 filter 时若在 available tools 中找到就"升级"为 custom；(b) 引入 `.custom` 但语义模糊。**推荐 (a)**——本 story 标 `.unknown`，diagnostics 暴露，29.5 filter 时区分。这样 `unknown` 含义明确："解析时无法确认"，运行时可能匹配到 custom tool。在 Dev Notes 注明这个语义。

### Files to Modify/Create

- **NEW**: `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`
  - `ToolDeclaration` struct
  - `ToolDeclarationStatus` enum
  - `ToolDeclarationDiagnostics` struct
- **MODIFY**: `Sources/OpenAgentSDK/Types/SkillTypes.swift`
  - `Skill` struct 新增 `toolDeclarations: [ToolDeclaration]?` 和 `toolDeclarationDiagnostics: ToolDeclarationDiagnostics?` 字段
  - `Skill.init(...)` 新增两参数（带默认值 nil）
  - `Skill.withBaseDir(_:)` 复制新字段
  - `Skill.==` 比较新字段
- **MODIFY**: `Sources/OpenAgentSDK/Skills/SkillLoader.swift`
  - 新增 `static func parseToolDeclarations(_:) -> (declarations: [ToolDeclaration], diagnostics: ToolDeclarationDiagnostics)?`
  - `loadSkillFromDirectory`（行 82-115）调用新解析器，填充 Skill 新字段
  - **保留** `parseAllowedTools`（行 326-345）完全不变
- **MODIFY**: `Sources/OpenAgentSDK/OpenAgentSDK.swift`
  - 公共 surface 文档注释（~121-127 Skill System 区段）追加 ToolDeclaration 索引
- **MODIFY**: `Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift`
  - 新增 `// MARK: - Story 29.4: Tool Declaration Compatibility` 区段
  - 新增 ~8 个 parseToolDeclarations 测试 + 1 个 loadSkillFromDirectory 填充测试
- **MODIFY**: `Tests/OpenAgentSDKTests/Types/SkillTypesTests.swift`（若存在）
  - 扩展 Skill init/withBaseDir/== 覆盖新字段

**不修改：**
- `Sources/OpenAgentSDK/Core/Agent.swift`（消费方，29.5 改）
- `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift`（消费方，29.5 改）
- `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift`（消费方，29.5 改）
- `Sources/OpenAgentSDK/Tools/ToolRestrictionStack.swift`（消费方，29.5 改）
- `Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift`（命名已正确，本 story 只让解析器认识）
- `Tests/OpenAgentSDKTests/Tools/ToolRestrictionStackTests.swift`（不改，验证无回归）
- `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift` / `ExecuteSkillStreamTests.swift`（不改，验证无回归）

**无 `.docc` 文档需要更新** —— `ToolDeclaration` 等是 `public`，DocC 会自动收录；本 story 可在 `OpenAgentSDK.swift` 的模块文档注释加一行索引（Task 1.5），但不强制。

### Dependencies and Blockers

**Upstream (DONE):**
- Story 29.1 (`createTaskTool()`) — DONE，commit 923bd6b。`Task` 作为 Claude Code 名需被本 story 识别（即使无 enum case）。
- Story 29.2 (`SubAgentLauncherNames`) — DONE，commit 5dd0ea2。
- Story 29.3 (skill package context) — DONE，commit dc49d54。5720 tests baseline。

**Downstream (本 story 解锁):**
- Story 29.5 (Shared filtering) — **直接依赖**本 story 的 `ToolDeclaration` 模型。29.5 将在 `Types/ToolDeclaration.swift` 同文件加 `filterToolsByDeclarations(...)` 函数和 `ToolFilterDiagnostics`（epic 29.5 "模块位置" 明确）。
- Story 29.7 (Tests) — 扩展本 story 的解析器测试覆盖。

**No blockers remain.**

### Out of Scope (Deferred to Later Stories)

- Shared filtering helper（`filterToolsByDeclarations`）→ **Story 29.5**
- 把消费方（Agent.swift / SkillTool.swift / ToolRestrictionStack / DefaultSubAgentSpawner）切到 `toolDeclarations` → **Story 29.5**
- Fine-grained Bash permission pattern enforcement → **epic 延后项第 5 条**
- Deferred field diagnostics（run_in_background 等）→ **Story 29.6**
- E2E 测试 → **Story 29.7**
- Filesystem subagent loader (`.claude/agents/*.md`) → **future epic**

### References

- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#Story 29.4] — story 定义、3 个 AC、实施步骤（richer representation、向后兼容、识别 Claude 名、MCP namespaced、custom/raw、permission pattern、unknown 不 collapse）
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#Story 29.5] — 模块位置决策：ToolDeclaration 放 `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#当前代码事实] — parseAllowedTools 只返回 [ToolRestriction]? 无法保留 raw MCP/custom names
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#关键设计约束] — 不静默放权、MCP tool name 保持完整、向后兼容
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#延后项] — Fine-grained Bash pattern enforcement 延后
- [Source: _bmad-output/implementation-artifacts/29-3-direct-skill-package-context.md] — Story 29.3 完成记录（5720 tests，commit dc49d54），新增字段有默认值的迁移模式参考
- [Source: _bmad-output/implementation-artifacts/29-2-spawner-detection-child-filtering.md] — Story 29.2 完成记录（5706 tests），集中管理常量（SubAgentLauncherNames）模式参考
- [Source: _bmad-output/implementation-artifacts/29-1-agent-task-shared-subagent-launcher.md] — Story 29.1 完成记录（5695 tests），"Task 是字符串名非 Swift 类型"模式参考
- [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-06-14.md] — readiness verdict: READY_WITH_ACTIONS，Epic 29 已就绪；术语冲突（TaskCreate vs Task）已说明无运行时碰撞
- [Source: _bmad-output/project-context.md#7] — 模块边界（Types/ 叶节点，Core/ 不依赖 Tools/）
- [Source: _bmad-output/project-context.md#10] — MCP 命名约定 mcp__{serverName}__{toolName}
- [Source: _bmad-output/project-context.md#15] — Swift 类型命名（无 `Task` 类型）
- [Source: _bmad-output/project-context.md#27] — 单元测试 mock 外部 API
- [Source: _bmad-output/project-context.md#29] — E2E 推迟到 Story 29.7
- [Source: _bmad-output/project-context.md#40] — 无 force-unwrap
- [Source: _bmad-output/project-context.md#46] — Array 而非 Set 用于有序列表
- [Source: _bmad-output/project-context.md#48] — 无内联 JSONEncoder/Decoder
- [Source: _bmad-output/project-context.md#56] — 复用共享测试基础设施
- [Source: Sources/OpenAgentSDK/Skills/SkillLoader.swift:326-345] — `parseAllowedTools(_:)` 当前实现（"静默放权" bug 源头，Task 3 保留不改）
- [Source: Sources/OpenAgentSDK/Skills/SkillLoader.swift:82-115] — `loadSkillFromDirectory` 当前填充 toolRestrictions（Task 4 扩展点）
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift:12-35] — `ToolRestriction` enum（无 .task case，Task 2.5 遵守）
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift:56-189] — `Skill` struct + init + withBaseDir + ==（Task 2 扩展点）
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift:69-70] — `toolRestrictions` 文档："nil means all tools are available"（unrestricted 语义）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:1260-1262] — executeSkill 消费 toolRestrictions（29.5 改，本 story 不动）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:1326-1328] — executeSkillStream 消费 toolRestrictions（29.5 改）
- [Source: Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift:124-126] — SkillTool 消费 toolRestrictions（29.5 改）
- [Source: Sources/OpenAgentSDK/Tools/ToolRestrictionStack.swift:42-82] — ToolRestrictionStack 基于 ToolRestriction（29.5 改）
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:157-174] — filterTools 基于 [String]?（29.5 改）
- [Source: Sources/OpenAgentSDK/Tools/MCP/MCPToolDefinition.swift:49-51] — MCP namespaced name `mcp__\(serverName)__\(mcpToolName)`
- [Source: Sources/OpenAgentSDK/OpenAgentSDK.swift:121-127] — Skill System 公共 surface 文档区段（Task 1.5 扩展点）
- [Source: Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift:315-328] — 现有 loadSkillFromDirectory_WithAllowedTools 测试（Task 5.2 旁新增）
- [Source: Tests/OpenAgentSDKTests/Skills/SkillLoaderTests.swift:491-518] — 现有 parseAllowedTools 测试（Task 5.4 回归保护）
- [Source: Tests/OpenAgentSDKTests/Tools/ToolRestrictionStackTests.swift:1-327] — 现有 ToolRestrictionStack 测试（Task 6.4 回归保护）

## Dev Agent Record

### Agent Model Used

glm-5.2 (via bmad-dev-story skill, yolo mode)

### Debug Log References

- 初次 `swift build` 成功（零警告），SDK 源码编译通过
- 首轮 `swift test` 出现 1 个测试失败：`testParseToolDeclarations_recognizesClaudeCodeNames` 中 `webFetchDecl?.toolRestriction` 返回 nil
- 根因：`ToolRestriction` enum 的 rawValue 是 camelCase（`webFetch`/`webSearch`/`toolSearch`/`askUser`），而 frontmatter 是 PascalCase（`WebFetch` 等）。初版用 `ToolRestriction(rawValue: lowercasedBase)` 查找，lowercased 后与 camelCase rawValue 不匹配
- 修复：引入 `ClaudeCodeToolNames.restrictionByLowercasedName` 字典（从 `ToolRestriction.allCases` 构建，key 全部 lowercased），实现 case-insensitive 查找
- 另：测试侧发现 3 处 `Skill(...)` 调用把 `toolDeclarations` 放在了 `promptTemplate` 之后，违反 Swift 函数调用参数顺序规则（"argument 'toolDeclarations' must precede argument 'promptTemplate'"）。实现按 story spec Task 2.2 将新参数放在 `toolRestrictions` 之后、`modelOverride` 之前（即 `promptTemplate` 之前），故修正 3 个测试调用点参数顺序以匹配声明顺序（仅测试文件改动，实现侧正确）
- 修复后 `swift test` 全量通过：5735 tests，0 failures（baseline 5720 + 15 新增）

### Completion Notes List

- **Task 1 完成**：新建 `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`，定义三个 public 类型：
  - `ToolDeclarationStatus`（enum，4 个 case：`recognizedSDK` / `recognizedMCP` / `recognizedCustom` / `unknown`，rawValue: String）
  - `ToolDeclaration`（struct，字段：`rawName` / `normalizedName` / `pattern` / `status` / `toolRestriction`）
  - `ToolDeclarationDiagnostics`（struct，字段：`unsupportedDeclarations` / `patternDeclarations`）
  - 全部 Sendable + Equatable，符合 project-context.md 模块边界（Types/ 叶节点）
  - `OpenAgentSDK.swift` Skill System 文档区段已索引新类型
- **Task 2 完成**：`SkillTypes.swift` 扩展 `Skill` struct：
  - 新增 `toolDeclarations: [ToolDeclaration]?` 和 `toolDeclarationDiagnostics: ToolDeclarationDiagnostics?` 字段（默认 nil）
  - `init(...)` 新增两参数（位置：`toolRestrictions` 之后、`modelOverride` 之前，带默认 nil）→ 所有现有调用方（6 BuiltInSkills + 测试 helper + SkillLoader）保持编译
  - `withBaseDir(_:)` 复制新字段
  - `==` 比较新字段
  - **未**给 `ToolRestriction` enum 加 `.task`（Task 2.5 合规）
- **Task 3 完成**：`SkillLoader.swift` 新增 `parseToolDeclarations(_:)`：
  - 用 "split on comma then trim" 策略保留完整 token（含 `Bash(git diff:*)` 这类括号 pattern）
  - MCP 识别：`mcp__<server>__<tool>`（server/tool 各不含 `__`），normalizedName 保留全名
  - SDK 识别：通过 `ClaudeCodeToolNames.restrictionByLowercasedName` 字典做 case-insensitive 查找（解决 `webFetch` camelCase vs `WebFetch` PascalCase 不匹配问题）
  - `Task` 识别：通过 `ClaudeCodeToolNames.knownClaudeCodeOnly`（仅含 `task`），status = `.recognizedSDK`，toolRestriction = nil
  - **保留** `parseAllowedTools(_:)` 完全不变（AC4）
  - **关键非 nil 语义**：非空输入永远返回非 nil 元组（即使全 unknown），修正"静默放权"bug
- **Task 4 完成**：`loadSkillFromDirectory` 同时填充 `toolRestrictions`（旧）+ `toolDeclarations`/`toolDeclarationDiagnostics`（新），消费方迁移推迟到 29.5
- **Task 5 完成**：15 个新测试全部转绿（10 SkillLoader + 5 SkillTypes），4 个回归保护 `testParseAllowedTools_*` 继续通过
- **Task 6 完成**：`swift build` 零警告；`swift test` 全量 5735 tests passing（baseline 5720 + 15 新增）

### File List

**新建：**
- `Sources/OpenAgentSDK/Types/ToolDeclaration.swift` —— `ToolDeclaration` / `ToolDeclarationStatus` / `ToolDeclarationDiagnostics` 三个 public 类型

**修改：**
- `Sources/OpenAgentSDK/Types/SkillTypes.swift` —— `Skill` struct 新增两字段 + init 参数 + withBaseDir + ==
- `Sources/OpenAgentSDK/Skills/SkillLoader.swift` —— 新增 `parseToolDeclarations(_:)` + `tokenizeToolDeclaration` + `isMCPNamespacedName` + `splitBaseAndPattern` + `ClaudeCodeToolNames` 私有命名空间；`loadSkillFromDirectory` 填充新字段；**保留** `parseAllowedTools` 不变
- `Sources/OpenAgentSDK/OpenAgentSDK.swift` —— Skill System 文档区段索引 3 个新类型
- `Tests/OpenAgentSDKTests/Types/SkillTypesTests.swift` —— 3 处 `Skill(...)` 调用参数顺序修正（toolDeclarations 须在 promptTemplate 之前）以匹配 init 声明顺序
- `_bmad-output/implementation-artifacts/sprint-status.yaml` —— 29-4 状态 ready-for-dev → review

**未修改（验证无回归）：**
- `Sources/OpenAgentSDK/Core/Agent.swift`（消费方，29.5 改）
- `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift`（消费方，29.5 改）
- `Sources/OpenAgentSDK/Tools/Advanced/SkillTool.swift`（消费方，29.5 改）
- `Sources/OpenAgentSDK/Tools/ToolRestrictionStack.swift`（消费方，29.5 改）
- 全部 6 个 BuiltInSkills 的 `toolRestrictions: [...]` 初始化（AC4 向后兼容）

## Change Log

| Date       | Version | Description                                                        | Author       |
|------------|---------|--------------------------------------------------------------------|--------------|
| 2026-06-14 | 0.1     | Initial story creation (Story 29.4 of Epic 29 — Tool Declaration Compatibility Model). | create-story |
| 2026-06-14 | 0.2     | GREEN phase implementation: ToolDeclaration model + parseToolDeclarations + Skill new fields. 15 new tests pass, 5735 total. | bmad-dev-story |
| 2026-06-14 | 0.3     | Code review (yolo): 3-layer adversarial review found 3 in-scope correctness fixes (F1 empty-parens phantom pattern, F6 unclosed-paren silent tool demotion, F9 MCP-with-trailing-pattern normalized-name corruption). Fixes applied to `splitBaseAndPattern` + `tokenizeToolDeclaration`; 3 regression tests added. 5 findings deferred to Story 29.5 (MCP `__` in tool name, comma-inside-parens, dedup, malformed paren forms). `swift test` 5738 passing (0 failures). Status → done. | bmad-code-review |

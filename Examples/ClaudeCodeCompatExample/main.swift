// ClaudeCodeCompatExample 示例 / Epic 29 — Claude Code Skill/Subagent Compatibility
//
// 验证 Epic 29（docs/epics/epic-29-claude-code-skill-subagent-compat.md）引入的
// Claude Code 兼容性公共 API 表面——让 Claude Code workflow skill 无需改写即可运行的底层原语。
// Verifies the public API surface introduced by Epic 29: the Claude Code Skill/Subagent
// compatibility primitives that let workflow skills run with minimal rewriting.
//
// 这是「纯验证型」示例：所有断言都是同步公共 SDK 调用，不需要 API Key，
// 因此可在 CI 中无凭证运行，既当可执行文档又当回归门。
// Pure verification example: no API key required. Every check is a synchronous public
// SDK call, so the example runs in CI as executable documentation and a regression gate.
// 任一断言失败即以 exit(1) 退出 —— 真实回归门，而非仅打印 PASS。
//
// 运行方式 / Run: swift run ClaudeCodeCompatExample
// 前提条件 / Prerequisites: 无（不需要 API Key）/ None (no API key needed)

import Foundation
import OpenAgentSDK

// MARK: - Compat Report Tracking / 兼容报告追踪

struct CompatEntry {
    let story: String
    let item: String
    let status: String
    let note: String?
}

nonisolated(unsafe) var compatReport: [CompatEntry] = []

func record(_ story: String, _ item: String, status: String, note: String? = nil) {
    compatReport.append(CompatEntry(story: story, item: item, status: status, note: note))
    let tag = "[" + status + "]"
    print("  \(tag) Story \(story): \(item)\(note.map { " (\($0))" } ?? "")")
}

// 布尔条件驱动的断言：true → PASS，false → MISSING（最终触发 exit(1)）。
// Boolean-condition assertion: true → PASS, false → MISSING (triggers exit(1) at the end).
func recordCheck(_ story: String, _ item: String, _ condition: Bool, note: String? = nil) {
    record(story, item, status: condition ? "PASS" : "MISSING", note: note)
}

// 从工具 schema 中抽取 LLM-facing 属性名 / required 字段集合。
// Extract LLM-facing property names / required field sets from a tool's JSON schema.
func schemaPropertyNames(_ tool: ToolProtocol) -> Set<String> {
    let properties = tool.inputSchema["properties"] as? [String: Any] ?? [:]
    return Set(properties.keys)
}

func schemaRequiredFields(_ tool: ToolProtocol) -> Set<String> {
    if let required = tool.inputSchema["required"] as? [String] {
        return Set(required)
    }
    return []
}

// 用受控的工具池做过滤断言时需要一个稳定可预测的「占位工具」。
// A stable, predictable stub tool for filtering assertions against a controlled pool.
func makeStubTool(_ name: String) -> ToolProtocol {
    defineTool(
        name: name,
        description: "Stub tool for compatibility verification",
        inputSchema: ["type": "object", "properties": [:]],
        isReadOnly: true
    ) { (_: [String: Any], _: ToolContext) async -> ToolExecuteResult in
        ToolExecuteResult(content: "stub", isError: false)
    }
}

func sortedToolNames(_ tools: [ToolProtocol]) -> [String] {
    tools.map { $0.name }.sorted()
}

func sortedRawNames(_ declarations: [ToolDeclaration]) -> [String] {
    declarations.map { $0.rawName }.sorted()
}

// MARK: - AC0: Build Compilation / 编译验证

print("=== AC0: Build Compilation ===")
record("29.x", "ClaudeCodeCompatExample target compiles", status: "PASS",
       note: "Imports only public OpenAgentSDK surface")
print("")

// MARK: - Story 29.1: Task Tool Alias / Task 工具别名

print("=== Story 29.1: Task Tool Alias ===")
print("")

let agentLauncher = createAgentTool()
let taskLauncher = createTaskTool()

recordCheck("29.1", "createAgentTool() returns tool named Agent",
            agentLauncher.name == "Agent",
            note: "name=\(agentLauncher.name), isReadOnly=\(agentLauncher.isReadOnly)")
recordCheck("29.1", "createTaskTool() returns tool named Task",
            taskLauncher.name == "Task",
            note: "name=\(taskLauncher.name), isReadOnly=\(taskLauncher.isReadOnly)")

// 两个工厂委托给同一个 private createSubAgentLauncherTool(name:description:)，
// 因此 schema（属性集合 + required）必须完全一致。
// Both factories delegate to one private createSubAgentLauncherTool(name:description:),
// so their schema (property set + required) must be identical.
let agentProps = schemaPropertyNames(agentLauncher)
let taskProps = schemaPropertyNames(taskLauncher)
let agentRequired = schemaRequiredFields(agentLauncher)
let taskRequired = schemaRequiredFields(taskLauncher)

recordCheck("29.1", "Agent and Task share identical input properties",
            agentProps == taskProps,
            note: "symmetricDifference=\(agentProps.symmetricDifference(taskProps).sorted())")
recordCheck("29.1", "Agent and Task share identical required fields",
            agentRequired == taskRequired,
            note: "required=\(taskRequired.sorted())")

// Claude Code workflow skill 里的 Task(...) 片段依赖这些 LLM-facing 字段。
// Claude Code workflow-skill Task(...) snippets rely on these LLM-facing fields.
let expectedLauncherFields: Set<String> = [
    "prompt", "description", "subagent_type", "model", "name", "maxTurns",
    "run_in_background", "isolation", "team_name", "mode", "resume"
]
let missingLauncherFields = expectedLauncherFields.subtracting(taskProps)
recordCheck("29.1", "Task schema exposes Claude Code launcher fields",
            missingLauncherFields.isEmpty,
            note: "missing=\(missingLauncherFields.sorted())")

print("")

// MARK: - Story 29.2: Launcher Detection Contract / 启动器检测契约

print("=== Story 29.2: Launcher Detection Contract ===")
print("")

// SubAgentLauncherNames 是 Core/ 内部类型，所以这里验证它所治理的「公共可观测行为」：
// Agent 与 Task 能共存于同一工具池，且默认从子代理工具池剥离二者以防递归派生。
// DefaultSubAgentSpawner 在调用共享过滤前会内部剥离这两个 launcher。
// SubAgentLauncherNames is internal to Core/, so this verifies the public observable
// behavior it governs: Agent and Task coexist in one pool, and both are stripped from a
// child pool by default to prevent recursive spawning. DefaultSubAgentSpawner strips
// both internally before delegating to the shared filter.
let launcherPool: [ToolProtocol] = [
    createReadTool(),
    createGlobTool(),
    createAgentTool(),
    createTaskTool(),
]
let launcherNames = sortedToolNames(launcherPool)
recordCheck("29.2", "Agent and Task launcher tools can coexist in one pool",
            launcherNames.contains("Agent") && launcherNames.contains("Task"),
            note: "pool=\(launcherNames)")

let stripLaunchers = ToolDeclaration.fromToolNames(["Agent", "Task"])
let stripResult = filterToolsByDeclarations(
    available: launcherPool,
    allowed: nil,
    disallowed: stripLaunchers
)
let strippedNames = sortedToolNames(stripResult.filtered)
recordCheck("29.2", "Disallowing Agent and Task strips both launcher tools",
            !strippedNames.contains("Agent") && !strippedNames.contains("Task"),
            note: "remaining=\(strippedNames)")

print("")

// MARK: - Story 29.3: Direct Skill Package Context / 直接 Skill 包上下文

print("=== Story 29.3: Direct Skill Package Context ===")
print("")

// 文件系统 skill 携带 baseDir + supportingFiles；运行时会在 prompt 中追加一个紧凑的
// "Skill package context:" 块，让 supporting file 相对 skill 包解析而非进程 cwd。
// 这里验证 Skill 元数据表面；prompt 组装（Agent.buildSkillExecutionPrompt，private）
// 的端到端验证需要 executeSkillStream + API Key，见 Story 29.7 的接线说明。
// A filesystem skill carries baseDir + supportingFiles; the runtime appends a compact
// "Skill package context:" block to the prompt so supporting files resolve relative to the
// skill package, not the process cwd. Here we verify the Skill metadata surface; the prompt
// assembly (Agent.buildSkillExecutionPrompt, private) is exercised end-to-end via
// executeSkillStream + API key — see the Story 29.7 wiring guidance.
//
// ── 运行时为文件系统 skill 生成的 prompt 形状（仅作文档，非断言）──────────────
// Runtime prompt shape emitted for a filesystem skill (documentation only, not asserted):
//
//   <skill.promptTemplate>
//
//   ---
//   Skill package context:
//   - baseDir: /srv/skills/demo-workflow
//   - supportingFiles:
//     - references/workflow-steps.md
//     - templates/output.md
//
//   Resolve bare supporting-file paths relative to baseDir. Read supporting files only
//   when the skill instructions require them.
//
//   ---
//   User request: <args>
//
// 编程式 skill（无包元数据）保持旧 prompt 形状，字符级向后兼容。
// A programmatic skill (no package metadata) keeps the legacy prompt shape char-for-char.
// ──────────────────────────────────────────────────────────────────────────────

let packageSkill = Skill(
    name: "demo-workflow",
    description: "A filesystem skill that ships supporting files",
    promptTemplate: "Execute the workflow described in the supporting files.",
    baseDir: "/srv/skills/demo-workflow",
    supportingFiles: ["references/workflow-steps.md", "templates/output.md"]
)

recordCheck("29.3", "Filesystem skill preserves baseDir",
            packageSkill.baseDir == "/srv/skills/demo-workflow",
            note: "baseDir=\(packageSkill.baseDir ?? "<nil>")")
recordCheck("29.3", "Filesystem skill preserves supporting file paths in order",
            packageSkill.supportingFiles == ["references/workflow-steps.md", "templates/output.md"],
            note: "supportingFiles=\(packageSkill.supportingFiles)")

let programmaticSkill = Skill(
    name: "demo-programmatic",
    promptTemplate: "Answer directly."
)
recordCheck("29.3", "Programmatic skill has no package context",
            programmaticSkill.baseDir == nil && programmaticSkill.supportingFiles.isEmpty,
            note: "baseDir=\(String(describing: programmaticSkill.baseDir)), files=\(programmaticSkill.supportingFiles.count)")

print("")

// MARK: - Story 29.4: Tool Declaration Compatibility Model / 工具声明兼容模型

print("=== Story 29.4: Tool Declaration Compatibility Model ===")
print("")

// ToolDeclaration.parse / fromToolNames 保留了旧 ToolRestriction-only 解析器丢弃的信息：
// MCP namespaced 名称、权限 pattern、未知/自定义名称（绝不塌缩为 unrestricted）。
// ToolDeclaration.parse / fromToolNames preserve info the legacy ToolRestriction-only parser
// dropped: MCP namespaced names, permission patterns, unknown/custom names (never collapse to
// unrestricted).
let declarations = ToolDeclaration.fromToolNames([
    "WebSearch",
    "mcp__github__list_prs",
    "Bash(git diff:*)",
    "UnknownTool",
    "Task",
])
let declarationByRawName = Dictionary(uniqueKeysWithValues: declarations.map { ($0.rawName, $0) })

let webSearch = declarationByRawName["WebSearch"]
recordCheck("29.4", "SDK tool names classify as recognizedSDK",
            webSearch?.status == .recognizedSDK,
            note: "status=\(String(describing: webSearch?.status))")

let mcp = declarationByRawName["mcp__github__list_prs"]
recordCheck("29.4", "MCP namespaced tools are preserved losslessly",
            mcp?.status == .recognizedMCP &&
                mcp?.normalizedName == "mcp__github__list_prs" &&
                mcp?.toolRestriction == nil,
            note: "status=\(String(describing: mcp?.status)), normalized=\(mcp?.normalizedName ?? "<nil>")")

let bashPattern = declarationByRawName["Bash(git diff:*)"]
recordCheck("29.4", "Permission pattern text is preserved",
            bashPattern?.normalizedName == "bash" &&
                bashPattern?.pattern == "git diff:*" &&
                bashPattern?.status == .recognizedSDK,
            note: "base=\(bashPattern?.normalizedName ?? "<nil>"), pattern=\(bashPattern?.pattern ?? "<nil>")")

let unknown = declarationByRawName["UnknownTool"]
recordCheck("29.4", "Unknown names remain explicit declarations",
            unknown?.status == .unknown && unknown?.toolRestriction == nil,
            note: "status=\(String(describing: unknown?.status))")

// Task 是「识别为 SDK 名称但没有 enum case」的代表（"ToolRestriction gap" 设计决策）。
// Task is the representative "recognized SDK name without an enum case" (the "ToolRestriction
// gap" design decision).
let taskDeclaration = declarationByRawName["Task"]
recordCheck("29.4", "Task is recognized without requiring a ToolRestriction case",
            taskDeclaration?.status == .recognizedSDK && taskDeclaration?.toolRestriction == nil,
            note: "status=\(String(describing: taskDeclaration?.status)), restriction=\(String(describing: taskDeclaration?.toolRestriction))")

let parseDiagnostics = ToolDeclarationDiagnostics(
    unsupportedDeclarations: declarations.filter { $0.status == .unknown },
    patternDeclarations: declarations.filter { $0.pattern != nil }
)
recordCheck("29.4", "Declaration diagnostics separate unknown and pattern signals",
            parseDiagnostics.unsupportedDeclarations.map { $0.rawName } == ["UnknownTool"] &&
                parseDiagnostics.patternDeclarations.map { $0.rawName } == ["Bash(git diff:*)"],
            note: "unsupported=\(sortedRawNames(parseDiagnostics.unsupportedDeclarations)), patterns=\(sortedRawNames(parseDiagnostics.patternDeclarations))")

print("")

// MARK: - Story 29.5: Shared Declaration Filtering / 共享声明过滤

print("=== Story 29.5: Shared Declaration Filtering ===")
print("")

// filterToolsByDeclarations 是 skill 直接执行与 spawned subagent 共用的唯一过滤 helper，
// 因此同一份声明在两处含义一致。用受控的 stub 工具池做精确断言。
// filterToolsByDeclarations is the single shared filter used by BOTH direct skill execution
// and spawned subagents, so one declaration means the same thing in both places. A controlled
// stub pool makes the assertion precise.
let availableForFiltering = [
    makeStubTool("WebSearch"),
    makeStubTool("Bash"),
    makeStubTool("mcp__github__list_prs"),
    makeStubTool("CustomHostTool"),
]
let allowedForFiltering = ToolDeclaration.fromToolNames([
    "WebSearch",
    "Bash(git diff:*)",
    "mcp__github__list_prs",
    "CustomHostTool",
    "GhostTool",
])
let filterResult = filterToolsByDeclarations(
    available: availableForFiltering,
    allowed: allowedForFiltering,
    disallowed: nil
)
let filteredNames = sortedToolNames(filterResult.filtered)

// AC: keep matching SDK / MCP / host tools; base-name match (Bash(git diff:*) → Bash).
// AC：保留匹配的 SDK / MCP / host 工具；按基名匹配（Bash(git diff:*) → Bash）。
recordCheck("29.5", "Shared filter keeps matching SDK, MCP, and host tools",
            filteredNames == ["Bash", "CustomHostTool", "WebSearch", "mcp__github__list_prs"],
            note: "filtered=\(filteredNames)")
// AC (红线「不静默放权」): 声明但缺失的工具进入诊断，绝不回退为 unrestricted。
// AC (red line "never silently unrestricted"): declared-but-missing tools become diagnostics,
// never an unrestricted fallback.
recordCheck("29.5", "Unmatched allowed declarations become diagnostics",
            filterResult.diagnostics.unmatchedDeclarations.map { $0.rawName } == ["GhostTool"],
            note: "unmatched=\(sortedRawNames(filterResult.diagnostics.unmatchedDeclarations))")
recordCheck("29.5", "Parsed but unenforced patterns become diagnostics",
            filterResult.diagnostics.patternDeclarations.map { $0.rawName } == ["Bash(git diff:*)"],
            note: "patterns=\(sortedRawNames(filterResult.diagnostics.patternDeclarations))")

// disallowed 优先级高于 allowed。
// disallowed takes priority over allowed.
let denyResult = filterToolsByDeclarations(
    available: getAllBaseTools(tier: .core),
    allowed: ToolDeclaration.fromToolNames(["Read", "Bash"]),
    disallowed: ToolDeclaration.fromToolNames(["Bash"])
)
let denyNames = sortedToolNames(denyResult.filtered)
recordCheck("29.5", "Disallowed declarations override allowed declarations",
            denyNames == ["Read"],
            note: "filtered=\(denyNames)")

print("")

// MARK: - Story 29.6: Deferred Subagent Field Diagnostics / 延迟子代理字段诊断

print("=== Story 29.6: Deferred Subagent Field Diagnostics ===")
print("")

// schema 接受但运行时尚未完整接线的字段，会以 SubAgentFieldDiagnostics 暴露，
// 让调用方区分「SDK 已遵循」与「SDK 已忽略」。每个延迟字段一条诊断。
// Fields accepted by schema but not fully wired at runtime surface as
// SubAgentFieldDiagnostics so callers can tell honored vs ignored. One diagnostic per deferred field.
let deferredFieldDiagnostics = [
    SubAgentFieldDiagnostics(
        fieldName: "run_in_background",
        rawValue: "true",
        reason: .backgroundExecutionNotImplemented
    ),
    SubAgentFieldDiagnostics(
        fieldName: "resume",
        rawValue: "abc123",
        reason: .resumeNotImplemented
    ),
    SubAgentFieldDiagnostics(
        fieldName: "isolation",
        rawValue: "worktree",
        reason: .isolationNotImplemented
    ),
    SubAgentFieldDiagnostics(
        fieldName: "team_name",
        rawValue: "review-team",
        reason: .teamCoordinationNotImplemented
    ),
    SubAgentFieldDiagnostics(
        fieldName: "skills",
        rawValue: "code-review,trace",
        reason: .skillsWiringDeferred
    ),
    SubAgentFieldDiagnostics(
        fieldName: "mcp_server_reference",
        rawValue: "github",
        reason: .mcpReferenceResolutionDeferred
    ),
]

let deferredReasons = Set(deferredFieldDiagnostics.map { $0.reason })
recordCheck("29.6", "All deferred-field diagnostic reasons are representable",
            deferredReasons == Set(SubAgentFieldDiagnosticReason.allCases),
            note: "reasons=\(deferredReasons.map { $0.rawValue }.sorted())")

// 诊断挂载在 SubAgentResult.fieldDiagnostics 上，与 text 分离；nil = 无延迟信号（默认态）。
// Diagnostics ride on SubAgentResult.fieldDiagnostics, separate from text; nil = no signal (default).
let subAgentResult = SubAgentResult(
    text: "Subagent finished",
    toolCalls: ["Read"],
    isError: false,
    fieldDiagnostics: deferredFieldDiagnostics
)
recordCheck("29.6", "SubAgentResult carries field diagnostics separately from text",
            subAgentResult.fieldDiagnostics?.count == deferredFieldDiagnostics.count &&
                subAgentResult.text == "Subagent finished",
            note: "count=\(subAgentResult.fieldDiagnostics?.count ?? 0)")

print("")

// MARK: - Story 29.7: Epic-End Integration Guidance / Epic 端到端接线指引

print("=== Story 29.7: Epic-End Integration Guidance ===")
print("")

// 一个 Claude Code 移植可以只注册 Task（不注册 Agent），工具池仍能正常工作。
// A Claude Code port can register Task alone (without Agent) and the pool still works.
let taskOnlyToolPool = getAllBaseTools(tier: .core) + [createTaskTool()]
let taskOnlyNames = sortedToolNames(taskOnlyToolPool)
recordCheck("29.7", "A Claude Code port can register Task without Agent",
            taskOnlyNames.contains("Task") && !taskOnlyNames.contains("Agent"),
            note: "containsTask=\(taskOnlyNames.contains("Task")), containsAgent=\(taskOnlyNames.contains("Agent"))")

let skillAllowedTools = ToolDeclaration.fromToolNames(["Read", "Grep", "Task"])
let skillFilter = filterToolsByDeclarations(
    available: taskOnlyToolPool,
    allowed: skillAllowedTools,
    disallowed: nil
)
let skillFilterNames = sortedToolNames(skillFilter.filtered)
recordCheck("29.7", "Task declarations flow through the shared filter",
            skillFilterNames == ["Grep", "Read", "Task"],
            note: "filtered=\(skillFilterNames)")

record("29.7", "Recommended registration shape", status: "PASS",
       note: "getAllBaseTools(tier: .core) + [createTaskTool()]")

print("")

// MARK: - Summary / 汇总

print("=== Epic 29 Compatibility Summary ===")
let grouped = Dictionary(grouping: compatReport, by: { $0.status })
let passCount = grouped["PASS"]?.count ?? 0
let partialCount = grouped["PARTIAL"]?.count ?? 0
let missingCount = grouped["MISSING"]?.count ?? 0
let naCount = grouped["N/A"]?.count ?? 0

print("PASS: \(passCount)")
print("PARTIAL: \(partialCount)")
print("MISSING: \(missingCount)")
print("N/A: \(naCount)")

// 任一断言失败 → 非零退出，作为 CI 硬门。
// Any failed assertion → non-zero exit, acting as a hard CI gate.
if missingCount > 0 {
    print("")
    print("Missing checks:")
    for entry in compatReport where entry.status == "MISSING" {
        print("- Story \(entry.story): \(entry.item)")
    }
    exit(1)
}

print("")
print("Claude Code Skill/Subagent compatibility verification completed.")

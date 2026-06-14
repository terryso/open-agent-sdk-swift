# Story 29.6: Diagnostics for Deferred Subagent Fields

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user of Claude Code-style subagent definitions,
I want unsupported fields to be visible in the sub-agent result,
so that I can tell whether the SDK honored or ignored background/resume/isolation/team/skills/MCP reference behavior.

## Context & Scope

**这是 Epic 29（Claude Code Skill/Subagent Compatibility）的第 6 个 story**，位于依赖图中 29.5 的下游、29.7 的上游（参见 epic 文档 "Story 间依赖关系"）。29.1 / 29.2 / 29.3 / 29.4 / 29.5 已 DONE，为本 story 提供完整运行时基础：`createTaskTool()` alias、`SubAgentLauncherNames` 检测与过滤、skill package context prompt、`ToolDeclaration` 数据模型与共享过滤 helper `filterToolsByDeclarations`。

**为什么需要这个 story：** `AgentToolInput`（AgentTool.swift:35-96）的 schema 接受 Claude Code 子代理的全部字段——`run_in_background`、`isolation`、`team_name`、`mode`、`resume`、`subagent_type`，加上 `AgentDefinition.mcpServers` / `AgentDefinition.skills`。`DefaultSubAgentSpawner.spawn(...)`（DefaultSubAgentSpawner.swift:88-151）的**增强**重载接收这些参数，但**显式标注**了未接线行为：

```swift
// DefaultSubAgentSpawner.swift:113-126
switch spec {
case .reference:
    // Reference lookup would require parent MCP config access.
    // For now, references are stored but not resolved at runtime.
    // Full runtime wiring is deferred to a future story.
    break
case .inline(let config):
    ...
}

// DefaultSubAgentSpawner.swift:146-147
// Note: skills, runInBackground, isolation, teamName, and resume
// are declared fields but full runtime wiring is deferred.
```

**当前后果：** 用户在 Claude Code 风格 input 里声明 `run_in_background: true`、`resume: "abc123"`、`isolation: "worktree"`、`team_name: "swarm"`、或 `AgentMcpServerSpec.reference("github-mcp")`，SDK **静默忽略**——前台执行、不恢复、不隔离、不组队、reference 不解析。用户无法区分"SDK 支持"vs"SDK 接受但忽略"。Epic 29 目标第 5 条明确要求："未知或暂不支持的工具声明必须形成 diagnostics，不能被误解为 unrestricted"。**本 story 把这条原则从 tool filtering 扩展到 deferred subagent 字段**。

**本 story 做什么：**
1. 引入 `SubAgentFieldDiagnostics` 公共类型（Types/），承载 deferred 字段的运行时诊断。每个条目含 `fieldName`、`rawValue`（原输入值的字符串形式）、`reason`（为何未接线）。
2. 在 `DefaultSubAgentSpawner.spawn(...)` 的增强重载中**收集**这些字段当它们被显式传入但运行时未接线时（`runInBackground == true`、`resume != nil`、`isolation != nil`、`teamName != nil`、`skills` 非空、`AgentMcpServerSpec.reference` 出现且父配置未解析）。
3. 在 `SubAgentResult` 增加可选 `fieldDiagnostics: [SubAgentFieldDiagnostics]?` 字段（默认 nil，向后兼容）。
4. 在 `AgentTool` 共享 factory 把 `fieldDiagnostics` 渲染进 `output` 文本（在 `result.text` 之后、`[Tools used: ...]` 之前追加诊断区块），让 Claude Code 风格 workflow skill 的使用者能在响应里看到 deferred 行为。
5. `SubAgentSpawner` 协议的增强 `spawn` 重载**签名不变**（仍返回 `SubAgentResult`），diagnostics 通过新增的 `SubAgentResult.fieldDiagnostics` 字段承载。

**本 story 不做什么（Out of Scope）：**
- **不实现 background subagent 的真实运行时语义**（异步派生、output file 轮询）→ epic 延后项第 4 条。
- **不实现 resume subagent**（按 ID 恢复先前 subagent）→ epic 延后项第 4 条。
- **不实现 worktree isolation** → epic 延后项第 4 条；SDK 已有 `WorktreeStore`/`WorktreeCreateTool`，但子代理隔离的完整接线留待后续。
- **不实现 team coordination runtime**（`TeamStore` 已存在但子代理未消费）→ epic 延后项第 4 条。
- **不实现 skills 字段的 child registry wiring**（把父 agent 的 skill registry 注入子代理）→ epic 延后项第 3 条。本 story 仅诊断 `skills != nil` 时"声明了但未接线"。
- **不实现 MCP server reference 从父配置解析的完整路径**（需要 parent MCP config 注入到 spawner）→ epic 延后项第 2 条。本 story 仅诊断 `.reference` 出现时"reference resolution is deferred"。
- **不删/不动 `AgentDefinition` 现有字段**——它是 source of truth，spawner 仍读它。
- **不改 E2E 测试**（E2E 推迟到 Story 29.7，参见 project-context.md #29）。
- **不破坏现有 `SubAgentSpawner` 协议或 `SubAgentResult` 的现有消费者**——`fieldDiagnostics` 默认 nil。

## Acceptance Criteria

1. **AC1: `SubAgentFieldDiagnostics` 类型存在于正确模块**
   - **Given** 本 story 实现完成
   - **When** 检查 `Sources/OpenAgentSDK/Types/AgentTypes.swift`
   - **Then** 文件包含 `public struct SubAgentFieldDiagnostics: Sendable, Equatable`，字段至少含：
     - `fieldName: String`（如 `"run_in_background"`、`"resume"`、`"isolation"`、`"team_name"`、`"skills"`、`"mcp_server_reference"`）
     - `rawValue: String`（用户传入的原值字符串化形式，如 `"true"`、`"abc123"`、`"worktree"`、`"github-mcp"`；多值场景如 `skills: ["commit", "review"]` 用逗号 join）
     - `reason: SubAgentFieldDiagnosticReason`（带 rawValue 的枚举，描述未接线原因）
   - **And** `SubAgentFieldDiagnosticReason` 是 `public enum ... : String, Sendable, Equatable, CaseIterable`，至少含以下 case（rawValue 是稳定字符串供宿主过滤/匹配）：
     - `backgroundExecutionNotImplemented`（`run_in_background: true` 时）
     - `resumeNotImplemented`（`resume` 非空时）
     - `isolationNotImplemented`（`isolation` 非空时）
     - `teamCoordinationNotImplemented`（`team_name` 非空时）
     - `skillsWiringDeferred`（`skills` 非空时）
     - `mcpReferenceResolutionDeferred`（`AgentMcpServerSpec.reference` 出现时）

2. **AC2: `SubAgentResult` 增加可选 `fieldDiagnostics` 字段**
   - **Given** 本 story 实现完成
   - **When** 检查 `SubAgentResult` 定义（AgentTypes.swift:1138-1148）
   - **Then** struct 包含 `public let fieldDiagnostics: [SubAgentFieldDiagnostics]?`
   - **And** 现有 `init(text:toolCalls:isError:)` 保留为便利 init，把 `fieldDiagnostics` 默认设为 nil（向后兼容所有现有调用点）
   - **And** 新增 `init(text:toolCalls:isError:fieldDiagnostics:)`（`fieldDiagnostics` 默认 nil）或扩展旧 init 加 trailing default 参数——二选一，**优先**扩展旧 init 加默认参数，避免 init 数量膨胀

3. **AC3: spawner 收集 deferred 字段诊断**
   - **Given** tool input 设置 `run_in_background: true`（其他 deferred 字段都 nil/空）
   - **When** `DefaultSubAgentSpawner.spawn(...)` 执行
   - **Then** 返回的 `SubAgentResult.fieldDiagnostics` 含**恰好一条** `SubAgentFieldDiagnostics(fieldName: "run_in_background", rawValue: "true", reason: .backgroundExecutionNotImplemented)`
   - **And** runtime 仍执行前台（行为不变），仅诊断声明 deferred

4. **AC4: MCP server reference 出现 → 诊断，inline 仍工作**
   - **Given** subagent 配置 `mcpServers: [.reference("github-mcp")]`（父配置不可达或无 reference 解析能力）
   - **When** spawn 执行
   - **Then** 返回的 `fieldDiagnostics` 含 `SubAgentFieldDiagnostics(fieldName: "mcp_server_reference", rawValue: "github-mcp", reason: .mcpReferenceResolutionDeferred)`
   - **And** inline MCP 配置（`.inline(...)`）**不**产生诊断（它们今天已被正常接线）
   - **And** 如果同一个 `.reference` 多次出现，每条都诊断（不去重，保持可观察）

5. **AC5: 多个 deferred 字段同时出现 → 多条诊断**
   - **Given** tool input 同时设置 `run_in_background: true`、`isolation: "worktree"`、`team_name: "swarm"`
   - **When** spawn 执行
   - **Then** 返回的 `fieldDiagnostics` 含**至少 3 条**，分别对应 `run_in_background` / `isolation` / `team_name`
   - **And** 诊断顺序**确定性**（按本 story Task 1.3 定义的固定顺序：run_in_background → resume → isolation → team_name → skills → mcp_server_reference），便于测试断言

6. **AC6: AgentTool 把 diagnostics 渲染进 output 文本**
   - **Given** spawn 返回的 `SubAgentResult.fieldDiagnostics` 非空
   - **When** `createSubAgentLauncherTool` 的执行体构建 `ToolExecuteResult`（AgentTool.swift:171-178）
   - **Then** output 文本含一个 diagnostics 区块，位于 `result.text` 之后、`[Tools used: ...]`（若有）之前，至少列出每个 diagnostic 的 `fieldName` 与简短 reason 文案（如 `[Subagent field "run_in_background" ignored: background execution is not implemented]`）
   - **And** 当 `fieldDiagnostics` 为 nil 或空数组时，output 文本**不含** diagnostics 区块（行为与 29.5 之前完全一致）

7. **AC7: `skills` 字段诊断**
   - **Given** spawn 传入 `skills: ["commit", "review"]`（非空数组）
   - **When** spawn 执行
   - **Then** `fieldDiagnostics` 含 `SubAgentFieldDiagnostics(fieldName: "skills", rawValue: "commit,review", reason: .skillsWiringDeferred)`
   - **And** `rawValue` 用逗号 join（保留顺序），无前后空格

8. **AC8: 无 deferred 字段 → `fieldDiagnostics` 为 nil**
   - **Given** tool input 不设任何 deferred 字段（`runInBackground`/`resume`/`isolation`/`teamName`/`skills`/reference MCP 都 nil/空）
   - **When** spawn 执行
   - **Then** 返回的 `SubAgentResult.fieldDiagnostics == nil`（**不**是空数组——nil 表示"无诊断"，空数组表示"诊断收集完毕但无条目"，本 story 用 nil 保持向后兼容的"无信号"语义）

9. **AC9: 向后兼容 —— 现有行为无回归**
   - **Given** 本 story 的所有改动完成
   - **When** `swift build` 和 `swift test` 运行
   - **Then** `SubAgentSpawner` 协议签名不变（5 参 + 14 参两个 spawn 重载）
   - **And** 所有现有 `SubAgentResult` 调用点（AgentTool.swift:172-177、`mapQueryResultToSubAgentResult` DefaultSubAgentSpawner.swift:234-245、测试文件中的 mock spawner）继续编译通过（`fieldDiagnostics` 默认 nil）
   - **And** 现有 `AgentToolTests` / `TaskToolsTests` / `DefaultSubAgentSpawnerTests`（含 29.2 filterTools 测试、29.5 declaration 测试）全部继续通过
   - **And** 29.5 的 `ToolFilterDiagnostics`（runtime tool 过滤诊断）**不**与本 story 的 `SubAgentFieldDiagnostics`（deferred subagent 字段诊断）混淆——两者是不同诊断维度，命名清晰区分

10. **AC10: Build 与全量回归**
    - **Given** 本 story 的所有改动完成
    - **When** `swift build` 和 `swift test` 运行
    - **Then** 构建零新警告，全部测试通过
    - **And** 完成记录中包含新的总测试数（Story 29.5 baseline: 5769 tests passing）

## Tasks / Subtasks

- [x] Task 1: 引入 `SubAgentFieldDiagnostics` 类型与 reason 枚举（AC: #1, #2, #9）
  - [x] 1.1 在 `Sources/OpenAgentSDK/Types/AgentTypes.swift` 的 `SubAgentResult` 定义（:1138-1148）**之前**，新增：
    ```swift
    /// Why a deferred subagent field is not wired at runtime (Story 29.6).
    public enum SubAgentFieldDiagnosticReason: String, Sendable, Equatable, CaseIterable {
        case backgroundExecutionNotImplemented
        case resumeNotImplemented
        case isolationNotImplemented
        case teamCoordinationNotImplemented
        case skillsWiringDeferred
        case mcpReferenceResolutionDeferred
    }

    /// Runtime diagnostic for a single subagent field that the SDK accepted by
    /// schema but does not fully wire (Story 29.6).
    public struct SubAgentFieldDiagnostics: Sendable, Equatable {
        public let fieldName: String
        public let rawValue: String
        public let reason: SubAgentFieldDiagnosticReason
        public init(fieldName: String, rawValue: String, reason: SubAgentFieldDiagnosticReason) {
            self.fieldName = fieldName
            self.rawValue = rawValue
            self.reason = reason
        }
    }
    ```
  - [x] 1.2 修改 `SubAgentResult`，加 `fieldDiagnostics: [SubAgentFieldDiagnostics]?` 字段。**优先方案**：扩展现有 `init(text:toolCalls:isError:)` 加 trailing 默认参数 `fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil`，避免新增 init。**注意**：因为 `SubAgentResult` 是 struct 且现有 init 有默认值（`toolCalls: [String] = [], isError: Bool = false`），加 `fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil` 不破坏现有调用点。
    ```swift
    public struct SubAgentResult: Sendable, Equatable {
        public let text: String
        public let toolCalls: [String]
        public let isError: Bool
        public let fieldDiagnostics: [SubAgentFieldDiagnostics]?

        public init(text: String, toolCalls: [String] = [], isError: Bool = false, fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil) {
            self.text = text
            self.toolCalls = toolCalls
            self.isError = isError
            self.fieldDiagnostics = fieldDiagnostics
        }
    }
    ```
  - [x] 1.3 在 `OpenAgentSDK.swift` 公共 surface 文档区段（约 121-127 行的 Skill System 区段附近，或更合适的 Subagent/Multi-Agent 区段），追加 `SubAgentFieldDiagnostics` / `SubAgentFieldDiagnosticReason` 的文档索引。**先 grep `OpenAgentSDK.swift` 确认 Subagent 类型导出区段位置**。

- [x] Task 2: `DefaultSubAgentSpawner.spawn(...)` 收集 diagnostics（AC: #3, #4, #5, #7, #8）
  - [x] 2.1 在 `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:88-151` 的增强 `spawn(...)` 重载中，在 `let subTools = filterTools(...)` 之后、`executeAgent(...)` 之前，新增 diagnostics 收集逻辑。**新增 private helper**：
    ```swift
    private func collectFieldDiagnostics(
        runInBackground: Bool?,
        isolation: String?,
        teamName: String?,
        skills: [String]?,
        resume: String?,
        mcpServers: [AgentMcpServerSpec]?
    ) -> [SubAgentFieldDiagnostics] {
        var diags: [SubAgentFieldDiagnostics] = []
        // 固定顺序（AC5）：run_in_background → resume → isolation → team_name → skills → mcp_server_reference
        if let runInBackground, runInBackground {
            diags.append(SubAgentFieldDiagnostics(
                fieldName: "run_in_background",
                rawValue: String(runInBackground),
                reason: .backgroundExecutionNotImplemented
            ))
        }
        if let resume, !resume.isEmpty {
            diags.append(SubAgentFieldDiagnostics(
                fieldName: "resume",
                rawValue: resume,
                reason: .resumeNotImplemented
            ))
        }
        if let isolation, !isolation.isEmpty {
            diags.append(SubAgentFieldDiagnostics(
                fieldName: "isolation",
                rawValue: isolation,
                reason: .isolationNotImplemented
            ))
        }
        if let teamName, !teamName.isEmpty {
            diags.append(SubAgentFieldDiagnostics(
                fieldName: "team_name",
                rawValue: teamName,
                reason: .teamCoordinationNotImplemented
            ))
        }
        if let skills, !skills.isEmpty {
            diags.append(SubAgentFieldDiagnostics(
                fieldName: "skills",
                rawValue: skills.joined(separator: ","),
                reason: .skillsWiringDeferred
            ))
        }
        if let mcpServers {
            for spec in mcpServers {
                if case .reference(let name) = spec {
                    diags.append(SubAgentFieldDiagnostics(
                        fieldName: "mcp_server_reference",
                        rawValue: name,
                        reason: .mcpReferenceResolutionDeferred
                    ))
                }
            }
        }
        return diags
    }
    ```
  - [x] 2.2 在 `spawn(...)` 主体调用：
    ```swift
    let fieldDiagnostics = collectFieldDiagnostics(
        runInBackground: runInBackground,
        isolation: isolation,
        teamName: teamName,
        skills: skills,
        resume: resume,
        mcpServers: mcpServers
    )
    ```
  - [x] 2.3 修改 `executeAgent(prompt:options:)`（DefaultSubAgentSpawner.swift:210-220）签名，加 trailing 参数 `fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil`，或在 `spawn` 主体里改写为内联 `Agent` 构造与 `mapQueryResultToSubAgentResult` 调用，把 diagnostics 注入。**优先**：扩展 `executeAgent` 签名（最小侵入）：
    ```swift
    private func executeAgent(prompt: String, options: AgentOptions, fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil) async -> SubAgentResult {
        let agent: Agent
        if let client = client {
            agent = Agent(options: options, client: client)
        } else {
            agent = Agent(options: options)
        }
        let result = await agent.prompt(prompt)
        return Self.mapQueryResultToSubAgentResult(result, fieldDiagnostics: fieldDiagnostics)
    }
    ```
  - [x] 2.4 扩展 `mapQueryResultToSubAgentResult`（:234-245）签名加 `fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil`，并把它传给 `SubAgentResult(text:toolCalls:isError:fieldDiagnostics:)`：
    ```swift
    internal static func mapQueryResultToSubAgentResult(
        _ result: QueryResult,
        fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil
    ) -> SubAgentResult {
        let text = result.text.isEmpty
            ? "(Subagent completed with no text output)"
            : result.text
        let toolNames = result.toolPairs.map { $0.toolUse.toolName }
        return SubAgentResult(
            text: text,
            toolCalls: toolNames,
            isError: result.status != .success,
            fieldDiagnostics: fieldDiagnostics
        )
    }
    ```
    **注意**：`mapQueryResultToSubAgentResult` 是 `internal static`，被 DefaultSubAgentSpawnerTests 直接测试。**必须保持现有 2 参调用点编译**——通过 `fieldDiagnostics: nil` 默认值实现。
  - [x] 2.5 在 `spawn` 主体最后，`return await executeAgent(prompt: prompt, options: options, fieldDiagnostics: fieldDiagnostics.isEmpty ? nil : fieldDiagnostics)`。**关键**：当无诊断时传 nil（AC8），非空时传数组（AC3-AC5, AC7）。**不要**传空数组——AC8 要求 nil。

- [x] Task 3: AgentTool 共享 factory 渲染 diagnostics 进 output（AC: #6）
  - [x] 3.1 在 `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:171-178`（`createSubAgentLauncherTool` 的执行体末尾），把：
    ```swift
    var output = result.text
    if !result.toolCalls.isEmpty {
        output += "\n[Tools used: \(result.toolCalls.joined(separator: ", "))]"
    }
    return ToolExecuteResult(content: output, isError: result.isError)
    ```
    改为：
    ```swift
    var output = result.text
    if let diags = result.fieldDiagnostics, !diags.isEmpty {
        // Story 29.6: surface deferred-field diagnostics so callers can see
        // which subagent fields the SDK honored vs ignored.
        let lines = diags.map { diag in
            let reasonText = SubAgentFieldDiagnosticReason.shortHumanReadableText(diag.reason)
            return "[Subagent field \"\(diag.fieldName)\" ignored: \(reasonText) (raw value: \(diag.rawValue))]"
        }
        output += "\n" + lines.joined(separator: "\n")
    }
    if !result.toolCalls.isEmpty {
        output += "\n[Tools used: \(result.toolCalls.joined(separator: ", "))]"
    }
    return ToolExecuteResult(content: output, isError: result.isError)
    ```
  - [x] 3.2 在 `ToolDeclaration.swift` 或 `AgentTypes.swift` 新增一个 `SubAgentFieldDiagnosticReason` 的 human-readable 文本 helper。**决策**：放在 `AgentTypes.swift` 的 `SubAgentFieldDiagnosticReason` extension（同文件内聚）：
    ```swift
    extension SubAgentFieldDiagnosticReason {
        /// Short, human-readable text describing why the field is not wired.
        /// Used by AgentTool to render diagnostics into the tool output.
        internal static func shortHumanReadableText(_ reason: SubAgentFieldDiagnosticReason) -> String {
            switch reason {
            case .backgroundExecutionNotImplemented:
                return "background execution is not implemented"
            case .resumeNotImplemented:
                return "sub-agent resume is not implemented"
            case .isolationNotImplemented:
                return "isolation mode is not implemented"
            case .teamCoordinationNotImplemented:
                return "team coordination is not implemented"
            case .skillsWiringDeferred:
                return "child skill registry wiring is deferred"
            case .mcpReferenceResolutionDeferred:
                return "parent MCP server reference resolution is deferred"
            }
        }
    }
    ```
    `internal` 可见性（AgentTool 在 Tools/，要调它；AgentTypes 在 Types/，两者都能访问 internal 通过 `@testable import` 不需要——AgentTool 是 Sources/ 内部代码，internal 跨文件同模块可见）。**注意**：`AgentTool.swift` 在 Tools/，`AgentTypes.swift` 在 Types/，但两者同属 `OpenAgentSDK` 模块，internal 可见性足够（不需要 public）。**确认**：检查 `OpenAgentSDK.swift` 是否用 `@_implementationOnly import`——如果有 internal helper 的可见性问题再改 public。当前项目用单模块（`OpenAgentSDK` target），internal 跨文件可见。
  - [x] 3.3 **回归保护**：现有 `AgentToolTests` / `TaskToolsTests` 使用 mock spawner 返回 `SubAgentResult(text: ..., toolCalls: ..., isError: ...)`——这些 `fieldDiagnostics` 默认 nil，因此新渲染逻辑**不触发**，output 文本不变。所有现有测试断言继续通过。

- [x] Task 4: `SubAgentSpawner` 协议兼容性（AC: #9）
  - [x] 4.1 `SubAgentSpawner` 协议（AgentTypes.swift:1155-1214）的增强 spawn 重载返回类型仍是 `SubAgentResult`——本 story **不改协议签名**。diagnostics 通过 `SubAgentResult.fieldDiagnostics` 承载，协议自动兼容。
  - [x] 4.2 `SubAgentSpawner` 协议扩展（:1189-1214）的默认实现调用 5 参 spawn——它返回的 `SubAgentResult` 的 `fieldDiagnostics` 为 nil（默认实现不收集 deferred 字段，符合"未接线时 nil"语义）。**不**修改默认实现。

- [x] Task 5: 单元测试（AC: #1-#10）
  - [x] 5.1 扩展 `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`（rule #56 复用现有文件），新增 `// MARK: - Story 29.6: Deferred Field Diagnostics` 区段。**关键**：现有 mock spawner（`MockSubAgentSpawner`，AgentToolTests.swift:9-95）需要扩展为**可注入** `fieldDiagnostics`。**决策**：
    - 选项 A：扩展 `MockSubAgentSpawner.init` 加 `fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil` 参数，spawn 返回时把它塞进 `SubAgentResult`。
    - 选项 B：新增专用 mock `MockSpawnerWithDiagnostics` 用于 29.6 测试，避免改现有 mock（影响 13+ 个现有测试）。
    - **推荐 A**——加默认参数不破坏现有 init 调用点。但需 Read 现有 `MockSubAgentSpawner.init` 确认构造方式。
    测试用例：
    - `testSpawner_backgroundField_emitsDiagnostic` —— 注入 spawn 期望：当 `run_in_background: true` 时，result.fieldDiagnostics 含 backgroundExecutionNotImplemented 条目（**注意**：mock spawner 不会自己收集——这是 DefaultSubAgentSpawner 的职责。本测试应针对**真实** `DefaultSubAgentSpawner`，用 mock client（rule #27）让它返回 canned `QueryResult`。**决策**：本测试放 `DefaultSubAgentSpawnerTests.swift` 而非 AgentToolTests.swift）。
    - `testAgentTool_outputIncludesDiagnosticsBlock` —— mock spawner 返回带 `fieldDiagnostics` 的 SubAgentResult，断言 AgentTool output 含 `[Subagent field "run_in_background" ignored: ...]`。**这个**测试放 AgentToolTests.swift。
    - `testAgentTool_noDiagnostics_outputUnchanged` —— mock spawner 返回 nil fieldDiagnostics，断言 output 不含 diagnostics 区块（向后兼容）。
  - [x] 5.2 扩展 `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`，新增 `// MARK: - Story 29.6: Deferred Field Diagnostics Collection` 区段。**关键**：要测试真实 `DefaultSubAgentSpawner.spawn(...)` 收集逻辑，需要 mock LLM client（rule #27）。**复用**现有 `DefaultSubAgentSpawnerTests` 已有的 mock client 模式（grep 该文件确认现有 mock setup）。测试用例：
    - `testSpawn_runInBackgroundTrue_emitsDiagnostic` —— spawn 传 `runInBackground: true`，断言 result.fieldDiagnostics 含 `fieldName: "run_in_background"` 条目。
    - `testSpawn_runInBackgroundFalseOrNil_noDiagnostic` —— `runInBackground: false` 或 nil 时**无**该字段诊断。
    - `testSpawn_resumeSet_emitsDiagnostic` —— `resume: "abc123"` → 诊断。
    - `testSpawn_isolationSet_emitsDiagnostic` —— `isolation: "worktree"` → 诊断。
    - `testSpawn_teamNameSet_emitsDiagnostic` —— `teamName: "swarm"` → 诊断。
    - `testSpawn_skillsSet_emitsDiagnosticWithCommaJoinedValue` —— `skills: ["commit", "review"]` → `rawValue: "commit,review"`。
    - `testSpawn_mcpReference_emitsDiagnostic` —— `mcpServers: [.reference("github-mcp")]` → 诊断。
    - `testSpawn_mcpInline_noDiagnostic` —— `mcpServers: [.inline(...)]` → **无** mcp_server_reference 诊断。
    - `testSpawn_multipleDeferredFields_allEmittedInOrder` —— 同时设 run_in_background + isolation + team_name + skills + 1 reference，断言 5 条诊断顺序符合 AC5。
    - `testSpawn_noDeferredFields_diagnosticsIsNil` —— 所有 deferred 字段 nil/空，断言 `fieldDiagnostics == nil`（AC8）。
    - `testMapQueryResultToSubAgentResult_propagatesDiagnostics` —— 直接调 internal static `mapQueryResultToSubAgentResult(_:fieldDiagnostics:)`，断言传入的诊断出现在 SubAgentResult。
  - [x] 5.3 **回归保护**：现有 `AgentToolTests`（13+ 测试）、`TaskToolsTests`、`DefaultSubAgentSpawnerTests`（29.2/29.5 测试）全部继续通过。`mapQueryResultToSubAgentResult` 现有 1 参调用点（DefaultSubAgentSpawner.swift:219，但已被 Task 2.3/2.4 改为 2 参）仍编译。
  - [x] 5.4 E2E 推迟到 Story 29.7（rule #29 + epic 29.7）。

- [x] Task 6: 构建与全量回归（AC: #10）
  - [x] 6.1 `swift build` 成功，零新警告
  - [x] 6.2 `swift test` 全量通过；完成记录包含新的总测试数（baseline 5769）
  - [x] 6.3 确认 `SubAgentSpawner` 协议两 spawn 重载签名不变
  - [x] 6.4 确认 `mapQueryResultToSubAgentResult` 现有调用点编译（通过 `fieldDiagnostics` 默认值）

## Dev Notes

### ATDD Artifacts

- Checklist: `_bmad-output/test-artifacts/atdd-checklist-29-6-diagnostics-deferred-subagent-fields.md`
- Unit tests (Core, deferred-field diagnostics collection): `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`
- Unit tests (Tools/Advanced, diagnostics rendering): `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`
- Red-phase status: 19 new tests scaffolded; failing at compile-time until implementation lands (Swift equivalent of TDD red phase — there is no `test.skip()` in XCTest, so red = references missing symbols).

### Architecture Context

这是 **Epic 29 的第 6 个 story**，依赖图中位置：

```
29.1 (DONE) --> 29.2 (DONE) --> 29.3 (DONE) --> 29.4 (DONE) --> 29.5 (DONE)
                                                                          |
                                                                          +--> 29.6 (THIS STORY)  ← deferred field diagnostics
                                                                                  |
                                                                                  +--> 29.7 (Tests + docs)
```

29.6 是 Epic 29 的**诊断 surfacing** story：29.4-29.5 让"工具声明/过滤"有了诊断（`ToolFilterDiagnostics`），29.6 把同样的"可观察 deferred 行为"原则扩展到子代理字段层。

### CRITICAL: 当前代码事实（必须先读）

**1. `AgentToolInput` schema 已接受全部 deferred 字段（AgentTool.swift:35-96）：**
```swift
private struct AgentToolInput: Codable {
    let prompt: String
    let description: String
    let subagent_type: String?
    let model: String?
    let name: String?
    let maxTurns: Int?
    let runInBackground: Bool?           // ← deferred
    let isolation: String?               // ← deferred
    let teamName: String?                // ← deferred
    let mode: String?
    let resume: String?                  // ← deferred
    // skills 不在 input schema —— 它来自 AgentDefinition.skills（host 预配置）
}
```
**注意**：`skills` **不是** `AgentToolInput` 字段——它来自 `AgentDefinition.skills`（AgentTypes.swift:979），由 host 通过 `BUILTIN_AGENTS` 或自定义 def 注入。但 spawner 的 `spawn(skills:...)` 参数（DefaultSubAgentSpawner.swift:96）接受 `[String]?`，本 story 仍诊断它。`AgentTool` 的 `createSubAgentLauncherTool` 执行体（AgentTool.swift:154-169）把 `agentDef?.skills`（来自 BUILTIN_AGENTS 或自定义 def）传给 spawner。**两个 BuiltIn agent（Explore/Plan，AgentTool.swift:8-23）的 `skills` 字段未设**（默认 nil）——故 BuiltIn path 不会触发 skills 诊断；但 host 注册自定义 `AgentDefinition(skills: ["commit"])` 会触发。

**2. `DefaultSubAgentSpawner.spawn(...)` 增强重载（DefaultSubAgentSpawner.swift:88-151）已有 deferred 标记：**
- `:105-108` 注释：`filterTools now returns (filtered, diagnostics); we currently discard diagnostics at the spawner boundary (deferred-field diagnostics surfacing belongs to Story 29.6)`。**本 story 把 29.5 的 spawner 过滤 diagnostics 也接上**——但**决策**：29.5 的 `ToolFilterDiagnostics`（unmatchedDeclarations / patternDeclarations）是**工具过滤**诊断，与本 story 的 **deferred 字段**诊断维度不同。**本 story 不把 `ToolFilterDiagnostics` 也塞进 `SubAgentResult.fieldDiagnostics`**——保持单一诊断维度。如果未来要把两者合并，作为 follow-up（命名上 `fieldDiagnostics` 专门指字段，`filterDiagnostics` 专门指工具，清晰区分）。**Dev Notes 明确此边界**。
- `:112-126` MCP reference 处理：`.reference` case `break`（无解析），`.inline` 正常存入 `resolvedMcpServers`。本 story 在此处加诊断收集（**不**改 reference 解析逻辑——那是 epic 延后项第 2 条）。
- `:146-147` 注释：`Note: skills, runInBackground, isolation, teamName, and resume are declared fields but full runtime wiring is deferred.`。本 story 在此处后（或 `executeAgent` 前）加诊断收集。

**3. `SubAgentResult`（AgentTypes.swift:1138-1148）当前 3 字段：**
```swift
public struct SubAgentResult: Sendable, Equatable {
    public let text: String
    public let toolCalls: [String]
    public let isError: Bool
    public init(text: String, toolCalls: [String] = [], isError: Bool = false) { ... }
}
```
本 story 加 `fieldDiagnostics: [SubAgentFieldDiagnostics]?` 字段 + 扩展 init（加默认参数）。

**4. `mapQueryResultToSubAgentResult`（DefaultSubAgentSpawner.swift:234-245）：**
```swift
internal static func mapQueryResultToSubAgentResult(_ result: QueryResult) -> SubAgentResult {
    let text = result.text.isEmpty ? "(Subagent completed with no text output)" : result.text
    let toolNames = result.toolPairs.map { $0.toolUse.toolName }
    return SubAgentResult(text: text, toolCalls: toolNames, isError: result.status != .success)
}
```
本 story 扩展签名加 `fieldDiagnostics: [SubAgentFieldDiagnostics]? = nil`（Task 2.4）。**注意**：这是 `internal static`，DefaultSubAgentSpawnerTests 直接调它做单元测试（不需驱动完整 LLM 往返，rule #27）。

**5. AgentTool 共享 factory 渲染逻辑（AgentTool.swift:171-178）：**
```swift
var output = result.text
if !result.toolCalls.isEmpty {
    output += "\n[Tools used: \(result.toolCalls.joined(separator: ", "))]"
}
return ToolExecuteResult(content: output, isError: result.isError)
```
本 story 在 `result.text` 之后、`[Tools used: ...]` 之前插入 diagnostics 区块（Task 3.1）。

### `fieldDiagnostics` nil vs 空数组的语义（AC8 决策）

- `nil` = "spawn 期间未收集到任何 deferred 字段诊断"（默认状态，向后兼容）
- `[]`（空数组）= "收集逻辑运行了但无条目"——本 story **不**产生这种状态（collectFieldDiagnostics 要么返回 nil，要么返回非空数组；Task 2.5 把空数组转 nil）

**理由**：测试断言"无诊断"时 `XCTAssertNil(result.fieldDiagnostics)` 比 `XCTAssertEqual(result.fieldDiagnostics?.count, 0)` 更明确。也让 AgentTool 渲染逻辑用 `if let diags = result.fieldDiagnostics, !diags.isEmpty` 简洁。

### 模块边界合规性（project-context.md #7）

- `SubAgentFieldDiagnostics` / `SubAgentFieldDiagnosticReason` 放 `Types/AgentTypes.swift` —— ✅ Types/ 是叶节点，无出站依赖。与 `SubAgentResult` 同文件（types 内聚）。
- `DefaultSubAgentSpawner.collectFieldDiagnostics`（Core/）—— ✅ Core/ 可 import Types/。
- `AgentTool` 渲染逻辑（Tools/）读 `SubAgentResult.fieldDiagnostics`（Types/）—— ✅ Tools/ 可 import Types/。
- `SubAgentFieldDiagnosticReason.shortHumanReadableText`（Types/AgentTypes.swift extension）—— internal 可见性，AgentTool（Tools/）同模块可调。✅
- **不**把 diagnostics 类型放 Core/ —— 那样 Tools/（AgentTool）无法引用（Tools/ 不 import Core/，project-context.md #7 反模式 #41）。

### 与 29.5 `ToolFilterDiagnostics` 的边界（避免混淆）

| 维度 | `ToolFilterDiagnostics`（29.5） | `SubAgentFieldDiagnostics`（29.6，本 story） |
|------|----------------------------------|-----------------------------------------------|
| 关注 | 工具池过滤：哪些声明未匹配可用工具、哪些 pattern 未强制 | 子代理字段：哪些 schema 接受的字段运行时未接线 |
| 产生位置 | `filterToolsByDeclarations`（Types/ToolDeclaration.swift） | `DefaultSubAgentSpawner.collectFieldDiagnostics`（Core/） |
| 承载位置 | `filterToolsByDeclarations` 返回 tuple | `SubAgentResult.fieldDiagnostics` |
| 当前 surfacing | DefaultSubAgentSpawner **丢弃**（29.5 Dev Notes：29.6 处理） | 本 story 注入 SubAgentResult + AgentTool output |
| 未来合并 | 可选 follow-up：把两者都暴露到 SubAgentResult | —— |

**本 story 决策**：**不**修改 29.5 的 `ToolFilterDiagnostics` 丢弃行为——那是工具过滤诊断，与字段诊断维度不同。如果 code review 发现 host 同时需要两类诊断，作为 follow-up（命名清晰区分已足够）。

### MCP reference 解析边界（AC4）

`DefaultSubAgentSpawner` 当前**没有** parent MCP config 引用（构造器 init 不接受它）。即使父 agent 有 `options.mcpServers`，spawner 拿不到。本 story **不**注入 parent MCP config（那是 epic 延后项第 2 条的完整 runtime）——只要 `AgentMcpServerSpec.reference` 出现在 spawn 参数，就诊断 `mcpReferenceResolutionDeferred`。**这意味着即使是未来的"父 MCP config 已可达"场景，只要 spawner 没改造为解析 reference，诊断仍出现**——这是诚实的可观察行为。

### Anti-Patterns to Avoid (project-context.md)

- ❌ **不要实现真实的 background/resume/isolation/team runtime** —— epic 延后项第 4 条。本 story 仅诊断，不改运行时行为。
- ❌ **不要实现 MCP reference 从父配置解析** —— epic 延后项第 2 条。本 story 仅诊断 reference 出现。
- ❌ **不要实现 child skill registry wiring** —— epic 延后项第 3 条。本 story 仅诊断 skills 非空。
- ❌ **不要改 `SubAgentSpawner` 协议签名** —— AC9。diagnostics 通过 `SubAgentResult.fieldDiagnostics` 承载，协议不变。
- ❌ **不要 force-unwrap (`!`)** —— rule #40，用 guard let / if let。
- ❌ **不要用 Set** —— diagnostics 顺序保持确定性（AC5），用 Array（rule #46）。collectFieldDiagnostics 按固定顺序 append。
- ❌ **不要破坏现有 mock spawner 的 init 调用点** —— Task 5.1 选项 A 加默认参数，不改现有 13+ 个 AgentToolTests 调用。
- ❌ **不要把 `ToolFilterDiagnostics`（29.5）塞进 `SubAgentResult.fieldDiagnostics`** —— 不同诊断维度（见上表）。命名清晰区分。
- ❌ **不要在 AgentTool output 把诊断塞进 `[Tools used: ...]` 行** —— 诊断区块是独立段，位于 result.text 之后、[Tools used] 之前。
- ❌ **不要给空 deferred 字段也产生诊断** —— `runInBackground: false`、`resume: ""`、`skills: []` 都**不**诊断（collectFieldDiagnostics 用 truthy 检查）。
- ❌ **不要写真实 LLM/网络 I/O 测试** —— 用 mock client（rule #27）。
- ❌ **不要新建独立测试文件除非必要** —— AgentToolTests / DefaultSubAgentSpawnerTests 扩展现有（rule #56）。
- ❌ **不要把 `mapQueryResultToSubAgentResult` 改成必须传 fieldDiagnostics** —— 加默认参数 nil（AC9 回归保护）。

### Testing Standards

- XCTest only（rule #23）
- 测试目录镜像源码：
  - `SubAgentFieldDiagnostics` / `SubAgentFieldDiagnosticReason` 在 `Types/AgentTypes.swift` → **可选**新建 `Tests/OpenAgentSDKTests/Types/SubAgentFieldDiagnosticsTests.swift`（测试类型本身，如 CaseIterable / Equatable），但**优先**在 `DefaultSubAgentSpawnerTests` 与 `AgentToolTests` 内联测试（rule #56 复用）。
  - `collectFieldDiagnostics` 在 Core/ → 扩展 `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`
  - `AgentTool` 渲染在 Tools/ → 扩展 `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`
- mock client 用于涉及 LLM 的 spawn 测试（rule #27）。复用 `DefaultSubAgentSpawnerTests` 现有 mock 模式。
- 纯函数测试：`collectFieldDiagnostics` 无副作用（输入字段 → 输出诊断数组），直接断言。
- `mapQueryResultToSubAgentResult` 直接调 internal static，不需 LLM 往返。
- E2E 推迟到 Story 29.7（rule #29）。

### Previous Story Intelligence (Story 29.5)

Story 29.5（commit fe501a1）完成于 2026-06-14，5769 tests passing。关键学习对本 story 适用：

- **"新增字段有默认值，保留旧 init"迁移模式** —— 29.5 给 `AgentOptions` 加 `allowedToolDeclarations: [ToolDeclaration]?`（默认 nil）；本 story 给 `SubAgentResult` 加 `fieldDiagnostics: [SubAgentFieldDiagnostics]?`（默认 nil），同样保持现有调用方编译。
- **"internal static 测试钩子"模式** —— 29.5 用 `filterToolsWithDiagnosticsForTesting`（internal）暴露完整 tuple；本 story 复用 `mapQueryResultToSubAgentResult`（已是 internal static），加 `fieldDiagnostics` 默认参数后测试可断言诊断传播。
- **"诊断 nil vs 空数组的语义"** —— 29.5 的 `ToolFilterDiagnostics` 总是非 nil（即使 unmatchedDeclarations/patternDeclarations 都空）；本 story 的 `SubAgentResult.fieldDiagnostics` 用 nil 表示"无诊断"——因为 SubAgentResult 是更大结构，nil 比 [] 语义更明确（"没有 deferred 字段信号" vs "信号收集了但空"）。
- **"code review 发现的边缘情况"** —— 29.5 review 发现 3 个 patch（MCP 大小写、declaration 路径未清 allowedTools、fromToolNames 空白）。本 story 预防类似：collectFieldDiagnostics 的字段 truthy 检查（`runInBackground == true` 而非 `runInBackground != nil`；`!resume.isEmpty` 而非 `resume != nil`）。

### Previous Story Intelligence (Story 29.1 / 29.2 / 29.3 / 29.4)

- **29.1**（commit 923bd6b）：`createTaskTool()` alias。本 story 的 diagnostics 渲染对 `Agent` 和 `Task` 共用 factory（`createSubAgentLauncherTool`），故两者都受益。
- **29.2**（commit 5dd0ea2）：`SubAgentLauncherNames`。本 story 不动 launcher 剥离逻辑。
- **29.3**（commit dc49d54）：skill package context。本 story 不动 skill 执行路径。
- **29.4**（commit 6715e80）：`ToolDeclaration` 模型。本 story 不动解析/过滤逻辑。

### Git Intelligence (recent commits)

```
fe501a1 feat(core): unify skill and subagent tool filtering via shared declarations (Story 29-5)
6715e80 feat(skills): add lossless ToolDeclaration compatibility model (Story 29-4)
dc49d54 feat(core): inject skill package context into direct skill execution (Story 29-3)
fbf001c fix(core): propagate sub-agent toolCalls from QueryResult.toolPairs
ee158e9 chore: add BMAD agent workspace config (skills, hooks, AGENTS.md)
```

`fe501a1`（29.5）改造了 `DefaultSubAgentSpawner.filterTools` 与 `mapQueryResultToSubAgentResult`（后者加 toolCalls 传播）。本 story 的目标文件（AgentTypes.swift 的 SubAgentResult、DefaultSubAgentSpawner.swift 的 spawn/executeAgent/mapQueryResultToSubAgentResult、AgentTool.swift 的渲染）自 29.5 以来处于已知状态。

### Latest Technical Information

- **Swift 5.9+** —— `SubAgentFieldDiagnosticReason` 是 `String` rawValue enum，CaseIterable。collectFieldDiagnostics 是同步纯函数（无 throws/async），便于测试。
- **`SubAgentResult` 是 struct** —— 加字段 + 默认 init 参数是向后兼容的 source change（现有 `SubAgentResult(text:toolCalls:isError:)` 调用点编译通过）。
- **不引入新外部依赖** —— 仅 Foundation + 现有 Types/ 类型。
- **`AgentMcpServerSpec` 是 enum** —— `if case .reference(let name) = spec` pattern matching 提取 reference 名（DefaultSubAgentSpawner.swift:114 已有此模式）。

### `SubAgentFieldDiagnosticReason` 与 human-readable 文本的关系

- `SubAgentFieldDiagnosticReason` rawValue 是**机器可读**稳定字符串（如 `"backgroundExecutionNotImplemented"`），供宿主过滤/匹配/聚合。
- `shortHumanReadableText`（Task 3.2）是**人类可读**文案（如 `"background execution is not implemented"`），用于 AgentTool output 渲染。
- 两者分离：宿主可基于 rawValue 做策略（如"遇到 resumeNotImplemented 时通知用户"），渲染层用 human-readable 文本。
- AC6 的 output 格式示例：`[Subagent field "run_in_background" ignored: background execution is not implemented (raw value: true)]`——`ignored:` 后是 human-readable，`(raw value: ...)` 是诊断的原值。

### Files to Modify/Create

- **MODIFY (追加)**: `Sources/OpenAgentSDK/Types/AgentTypes.swift`
  - 追加 `SubAgentFieldDiagnosticReason` enum（约 :1135 之前，SubAgentResult 之前）
  - 追加 `SubAgentFieldDiagnostics` struct
  - 追加 `SubAgentFieldDiagnosticReason.shortHumanReadableText(_:)` internal static（Task 3.2）
  - 修改 `SubAgentResult`：加 `fieldDiagnostics: [SubAgentFieldDiagnostics]?` 字段 + 扩展 init 加默认参数（Task 1.2）
- **MODIFY**: `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift`
  - 新增 `collectFieldDiagnostics(...)` private helper（Task 2.1）
  - `spawn(...)` 主体调用 collectFieldDiagnostics + 传给 executeAgent（Task 2.2, 2.5）
  - `executeAgent(...)` 加 `fieldDiagnostics` 参数（Task 2.3）
  - `mapQueryResultToSubAgentResult(...)` 加 `fieldDiagnostics` 参数 + 传播到 SubAgentResult（Task 2.4）
- **MODIFY**: `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift`
  - `createSubAgentLauncherTool` 渲染逻辑加 diagnostics 区块（Task 3.1）
- **MODIFY**: `Sources/OpenAgentSDK/OpenAgentSDK.swift`
  - Subagent 类型导出区段索引 `SubAgentFieldDiagnostics` / `SubAgentFieldDiagnosticReason`（Task 1.3）
- **MODIFY**: `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift`
  - `MockSubAgentSpawner` 加 `fieldDiagnostics` 默认参数（Task 5.1 选项 A）
  - 新增 `// MARK: - Story 29.6` 区段：output 渲染测试（Task 5.1）
- **MODIFY**: `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift`
  - 新增 `// MARK: - Story 29.6` 区段：collectFieldDiagnostics / spawn 诊断收集测试（Task 5.2）

**不修改（验证无回归）：**
- `Sources/OpenAgentSDK/Types/ToolDeclaration.swift`（29.5 已完成）
- `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` / `ToolRestrictionStack.swift`（不在范围）
- `Sources/OpenAgentSDK/Skills/SkillLoader.swift`（不在范围）
- `AgentDefinition` 字段（source of truth，不改）
- `SubAgentSpawner` 协议签名（AC9）

### Dependencies and Blockers

**Upstream (DONE):**
- Story 29.1 (`createTaskTool()`) — DONE，commit 923bd6b。
- Story 29.2 (`SubAgentLauncherNames`) — DONE，commit 5dd0ea2。
- Story 29.3 (skill package context) — DONE，commit dc49d54。
- Story 29.4 (`ToolDeclaration` model) — DONE，commit 6715e80。
- Story 29.5 (`filterToolsByDeclarations` + `ToolFilterDiagnostics`) — DONE，commit fe501a1。5769 tests baseline。

**Downstream (本 story 解锁):**
- Story 29.7 (Tests + docs) — 扩展本 story 的诊断测试覆盖 + E2E + DocC 文档。

**No blockers remain.**

### Out of Scope (Deferred to Later Stories / Epics)

- Background subagent runtime（异步派生、output file 轮询）→ **epic 延后项第 4 条**
- Resume subagent（按 ID 恢复）→ **epic 延后项第 4 条**
- Worktree isolation runtime → **epic 延后项第 4 条**
- Team coordination runtime（`TeamStore` 消费）→ **epic 延后项第 4 条**
- Child skill registry wiring（父 skill registry 注入子代理）→ **epic 延后项第 3 条**
- MCP server reference 从父配置解析 → **epic 延后项第 2 条**
- Fine-grained Bash permission pattern enforcement → **epic 延后项第 5 条**
- 把 `ToolFilterDiagnostics`（29.5）也暴露到 `SubAgentResult` → **follow-up**（命名清晰区分已足够）
- Filesystem subagent loader (`.claude/agents/*.md`) → **future epic**
- Host-level permission UI and approval workflow → **future epic**
- E2E 测试 → **Story 29.7**

### References

- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#Story 29.6] — story 定义、2 个 AC、实施步骤（collect diagnostics、6 类字段、SubAgentResult 承载、MCP reference deferred）
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#目标] — 目标第 5 条："未知或暂不支持的工具声明必须形成 diagnostics，不能被误解为 unrestricted"
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#非目标] — 非目标："不实现 background/resume/isolation/team coordination 的完整 runtime 语义；本 Epic 只保留字段、传递能力和可诊断状态"
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#延后项] — 6 项延后（filesystem loader、MCP reference lookup、skills wiring、background/resume/isolation/team、Bash pattern、permission UI）
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#关键设计约束] — 向后兼容、不静默放权
- [Source: _bmad-output/implementation-artifacts/29-5-shared-filtering-skills-subagents.md] — Story 29.5 完成记录（5769 tests, commit fe501a1），ToolFilterDiagnostics 模式、"诊断 nil vs 空数组"决策、"新增字段默认值"迁移模式
- [Source: _bmad-output/implementation-artifacts/29-5-shared-filtering-skills-subagents.md#Dev Notes] — "spawner diagnostics 先丢弃（或仅用于内部断言），29.6 会统一处理 subagent diagnostics surfacing"
- [Source: _bmad-output/implementation-artifacts/29-4-tool-declaration-compatibility-model.md] — Story 29.4 完成记录，"诊断 surfacing 模式"建立
- [Source: _bmad-output/implementation-artifacts/29-2-spawner-detection-child-filtering.md] — Story 29.2 完成记录，SubAgentLauncherNames 模式
- [Source: _bmad-output/implementation-artifacts/29-1-agent-task-shared-subagent-launcher.md] — Story 29.1 完成记录，createSubAgentLauncherTool 共享 factory 模式
- [Source: _bmad-output/project-context.md#7] — 模块边界（Types/ 叶节点，Core/ 不依赖 Tools/，Tools/ 不依赖 Core/）
- [Source: _bmad-output/project-context.md#15] — Swift 类型命名（无 `Task` 类型）
- [Source: _bmad-output/project-context.md#23] — 测试目录镜像源码
- [Source: _bmad-output/project-context.md#27] — 单元测试 mock 外部 API
- [Source: _bmad-output/project-context.md#29] — E2E 推迟到 Story 29.7
- [Source: _bmad-output/project-context.md#40] — 无 force-unwrap
- [Source: _bmad-output/project-context.md#41] — Tools/ 不 import Core/
- [Source: _bmad-output/project-context.md#46] — Array 而非 Set 用于有序列表
- [Source: _bmad-output/project-context.md#56] — 复用共享测试基础设施
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift:958-1007] — AgentDefinition struct（含 mcpServers / skills 字段，本 story 不改）
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift:1009-1027] — AgentMcpServerSpec enum（.reference / .inline，本 story 诊断 .reference）
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift:1138-1148] — SubAgentResult struct（本 story 加 fieldDiagnostics 字段）
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift:1155-1214] — SubAgentSpawner protocol + extension default impl（本 story 不改签名）
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:35-96] — AgentToolInput（schema 已接受 run_in_background/isolation/team_name/resume）
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:131-179] — createSubAgentLauncherTool（本 story 改渲染逻辑）
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:8-23] — BUILTIN_AGENTS（Explore/Plan，skills 字段未设）
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:88-151] — spawn 增强重载（本 story 加 collectFieldDiagnostics 调用）
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:105-108] — 29.5 注释："29.6 会统一处理 subagent diagnostics surfacing"
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:112-126] — MCP reference 处理（.reference break，本 story 在此处诊断）
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:146-147] — deferred fields 注释（本 story 在此处收集诊断）
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:210-220] — executeAgent（本 story 加 fieldDiagnostics 参数）
- [Source: Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:234-245] — mapQueryResultToSubAgentResult（本 story 加 fieldDiagnostics 参数 + 传播）
- [Source: Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift:9-95] — MockSubAgentSpawner（本 story 加 fieldDiagnostics 默认参数）
- [Source: Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift] — 29.2 / 29.5 测试（本 story 扩展 29.6 区段）

## Dev Agent Record

### Agent Model Used

glm-5.2[1m] (via Claude Code dev-story workflow)

### Debug Log References

- `swift build` → Build complete! (75.24s), zero new warnings.
- `swift test --filter "DefaultSubAgentSpawnerTests|AgentToolTests"` → 60 tests, 0 failures.
- `swift test` (full suite) → **5787 tests, 0 failures** (38.6s). Baseline was 5769; delta +18 (= 13 new Core + 5 new AgentTool red-phase tests now green).

### Completion Notes List

- **Types layer (Task 1)** — Added `SubAgentFieldDiagnosticReason` (public enum, String rawValue, CaseIterable, 6 cases) and `SubAgentFieldDiagnostics` (public struct, Sendable+Equatable, fields `fieldName`/`rawValue`/`reason`) to `Sources/OpenAgentSDK/Types/AgentTypes.swift` immediately before `SubAgentResult`. Added `internal static SubAgentFieldDiagnosticReason.shortHumanReadableText(_:)` extension for AgentTool rendering. Extended `SubAgentResult` with `fieldDiagnostics: [SubAgentFieldDiagnostics]?` and added a trailing `fieldDiagnostics: ... = nil` default parameter to its existing `init` — no new init, all existing call sites compile unchanged. Indexed both types in `OpenAgentSDK.swift` Sub-Agent Spawning docs section.
- **Core layer (Task 2)** — Added private `collectFieldDiagnostics(runInBackground:isolation:teamName:skills:resume:mcpServers:)` to `DefaultSubAgentSpawner`. Pure synchronous function emitting in fixed order: `run_in_background` → `resume` → `isolation` → `team_name` → `skills` → `mcp_server_reference`. Truthy checks: `runInBackground == true` (literal `false` is NOT deferred), non-empty string checks for resume/isolation/teamName, non-empty array check for skills (comma-joined, no whitespace), each `.reference` MCP spec emits its own diagnostic (no dedup). Threaded through `executeAgent(prompt:options:fieldDiagnostics:)` and `mapQueryResultToSubAgentResult(_:fieldDiagnostics:)` (both with default `nil` for backward compat). `spawn` coerces `[]` → `nil` (AC8) before passing to `executeAgent`.
- **Tools layer (Task 3)** — Added diagnostics rendering branch in `createSubAgentLauncherTool` (`AgentTool.swift`), inserted between `result.text` and `[Tools used: ...]`. Format: `[Subagent field "X" ignored: <reason prose> (raw value: Y)]`, one line per diagnostic in collection order. Guarded with `if let diags, !diags.isEmpty` so nil/empty yields byte-identical pre-29.6 output.
- **Protocol (Task 4)** — `SubAgentSpawner` protocol and its extension default impl were NOT modified (AC9). Diagnostics ride on `SubAgentResult.fieldDiagnostics`; both spawn overloads still return `SubAgentResult`.
- **Tests (Task 5)** — Red-phase tests (13 in `DefaultSubAgentSpawnerTests`, 5 in `AgentToolTests`) now green. All pre-existing 13+ AgentToolTests, TaskToolsTests, and 29.2/29.5 DefaultSubAgentSpawnerTests continue to pass — `MockSubAgentSpawner.makeWithDiagnostics(...)` static helper added default parameters so existing init call sites compile unchanged.
- **filterToolsWithDiagnosticsForTesting** — Verified this is a pre-existing Story 29-5 testing hook (`DefaultSubAgentSpawner.swift:205`), NOT something this story needs to add. Story 29-6 tests live in a separate `// MARK: - Story 29.6` section and reference only the new `SubAgentFieldDiagnostics` / `fieldDiagnostics:` symbols.
- **Boundary with 29.5 ToolFilterDiagnostics** — Per Dev Notes, the 29.5 spawner-filter diagnostics remain discarded at the spawner boundary. `SubAgentFieldDiagnostics` is a distinct diagnostic dimension (deferred subagent fields), kept separate from `ToolFilterDiagnostics` (tool pool filtering). No silent escalation risk introduced.
- **AC1-AC10 all satisfied.** Full test suite count recorded: 5787 tests passing.

### File List

Modified source files:
- `Sources/OpenAgentSDK/Types/AgentTypes.swift` — added `SubAgentFieldDiagnosticReason` enum + extension (`shortHumanReadableText`), `SubAgentFieldDiagnostics` struct, `SubAgentResult.fieldDiagnostics` field + extended init.
- `Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift` — added `collectFieldDiagnostics(...)` private helper, threaded `fieldDiagnostics` through `spawn` → `executeAgent` → `mapQueryResultToSubAgentResult`.
- `Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift` — added diagnostics rendering block in `createSubAgentLauncherTool` execution body.
- `Sources/OpenAgentSDK/OpenAgentSDK.swift` — indexed new types in Sub-Agent Spawning docs section.

No new test files — red-phase tests were pre-written (ATDD step) in:
- `Tests/OpenAgentSDKTests/Core/DefaultSubAgentSpawnerTests.swift` (13 tests, now green)
- `Tests/OpenAgentSDKTests/Tools/Advanced/AgentToolTests.swift` (5 tests + `MockSubAgentSpawner.makeWithDiagnostics` helper, now green)

Story-management files:
- `_bmad-output/implementation-artifacts/29-6-diagnostics-deferred-subagent-fields.md` — Status, Tasks, Dev Agent Record, File List, Change Log updated.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `29-6-diagnostics-deferred-subagent-fields: ready-for-dev → review`, `last_updated` bumped.

## Change Log

| Date       | Version | Description                                                                                                          | Author       |
|------------|---------|----------------------------------------------------------------------------------------------------------------------|--------------|
| 2026-06-14 | 0.1     | Initial story creation (Story 29.6 of Epic 29 — Diagnostics for Deferred Subagent Fields).                           | create-story |
| 2026-06-14 | 0.2     | Implemented Tasks 1-6 (types + spawner collect + AgentTool render). All 10 ACs satisfied. 5787 tests passing (was 5769). | dev-story |
| 2026-06-14 | 0.3     | Adversarial code review (3 parallel layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor). All 10 ACs verified MET. Build clean, 5787 tests independently re-run and passing. SourceKit diagnostics on ToolDeclaration/ToolFilterDiagnostics/filterToolsByDeclarations (Story 29-5 symbols) confirmed STALE via `swift build`. 6 low-severity robustness items deferred; 3 findings dismissed as out-of-scope/by-design. Status → done. | code-review |

### Review Findings

**Conclusion: PASS — story advances to `done`.**

Build verification: `swift build` → Build complete! (9.43s), zero warnings, zero errors. The SourceKit-reported diagnostics about `ToolDeclaration`/`ToolFilterDiagnostics`/`filterToolsByDeclarations` at `DefaultSubAgentSpawner.swift:268-305` are **STALE** — these are Story 29-5 symbols that compile cleanly in the actual build. No real compilation errors exist.

Test verification: Acceptance Auditor independently re-ran `swift test` → 5787 tests, 0 failures (39.1s). Matches dev claim (5769 baseline + 18 new = 5787).

Acceptance audit: All 10 ACs MET/VERIFIED-BY-TEST. Anti-patterns check: all respected (protocol signature unchanged, no force-unwraps, no Set, mock init call sites preserved, ToolFilterDiagnostics boundary preserved, no real runtime implementation leaked).

Deferred items (low-severity robustness enhancements, none blocking):

- [x] [Review][Defer] Whitespace-only string fields (resume/isolation/team_name) treated as deferred — `!isEmpty` is used, no trimming. Matches spec template (spec lines 196-217 use the same `.isEmpty` check), so not a deviation; a robustness gap if an LLM emits `"isolation": " "`. [Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:206-228]
- [x] [Review][Defer] Whitespace-only elements in `skills` array survive comma-join — `skills.joined(separator: ",")` produces e.g. `"commit,  ,review"` for `["commit","  ","review"]`. Spec AC7 only mandates "no surrounding whitespace on separator", which is satisfied; per-element filtering is an enhancement. [Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:230-235]
- [x] [Review][Defer] Skill name containing a comma breaks `rawValue` round-trip parse — `["a,b","c"]` serializes to `"a,b,c"`, ambiguous with `["a","b","c"]`. `rawValue` is documented as "input value stringified", not a parseable serialization. No realistic trigger (skill names do not contain commas). [Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:233]
- [x] [Review][Defer] Control characters in `rawValue`/`fieldName` not escaped in rendered tool output — a `rawValue` containing `\n` would split a diagnostic across lines, technically breaking the "one diagnostic = one line" invariant asserted by `testAgentTool_multipleDiagnostics_renderedInOrder`. Not a security issue (output is post-execution text to the parent LLM, not parsed instructions). Low likelihood (resume/isolation/team_name come from JSON-decoded `AgentToolInput`). [Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:177-181]
- [x] [Review][Defer] `result.text` ending in a newline produces a spurious blank line before the diagnostics block — unconditional `output += "\n" + ...`. Identical pre-existing behavior for the sibling `[Tools used:]` line; cosmetic regression only. [Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift:172-181]

Dismissed (out of scope / by design):

- `.reference("")` producing a misleading diagnostic — reference names come from host-configured `AgentDefinition.mcpServers`, not free-form LLM input; no realistic trigger. [Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:238-249]
- Inline MCP config failures producing no diagnostics — explicitly by design per the diff comment ("inline configs ARE wired today") and the spec's diagnostic dimension is "deferred schema fields", not "runtime wiring failures". [Sources/OpenAgentSDK/Core/DefaultSubAgentSpawner.swift:238-249]
- Protocol default implementation swallowing diagnostics for non-`DefaultSubAgentSpawner` conformers — spec explicitly scopes this story to `DefaultSubAgentSpawner` (AC9 mandates protocol signature unchanged); the protocol default impl is intentionally unmodified. Known boundary documented in spec scope section. [Sources/OpenAgentSDK/Types/AgentTypes.swift:1270-1295]

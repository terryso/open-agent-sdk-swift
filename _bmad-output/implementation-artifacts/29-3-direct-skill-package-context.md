# Story 29.3: Direct Skill Package Context

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a filesystem skill author,
I want direct skill execution (`executeSkill` / `executeSkillStream`) to include the skill package location (`baseDir` + supporting file paths) in the assembled prompt,
so that supporting files are resolved relative to the skill package directory instead of the process cwd, preventing bare relative paths from being silently resolved to the caller's working directory.

## Context & Scope

**这是 Epic 29（Claude Code Skill/Subagent Compatibility）的第 3 个 story**，与 29.4 (Tool Declaration Compatibility) 是 epic 依赖图中的并行下游分支（参见 epic 文档 "Story 间依赖关系"）。29.1 和 29.2 已经 DONE，为本 story 提供完整的运行时基础（`createTaskTool()` alias + `SubAgentLauncherNames` 检测）。

**为什么需要这个 story：** Filesystem skill（由 `SkillLoader` 从磁盘加载的 skill，例如 `_bmad-output/...` 或 `.claude/skills/...`）在 prompt 中只包含 `promptTemplate`，agent 在执行时若需要读取 `references/workflow-steps.md` 这类 supporting file，只能用裸相对路径，会被解析到 `Process.processInfo.environment["PWD"]` 或 agent 的 `cwd`，而非 skill 所在目录。`Skill.baseDir` 和 `Skill.supportingFiles` 字段已经由 `SkillLoader` 填充，但 `resolveSkillForExecution` 完全没有使用它们。

**本 story 做什么：** 在 `resolveSkillForExecution(_:, args:)` 中，当 `Skill.baseDir != nil` 或 `Skill.supportingFiles` 非空时，在 `promptTemplate` 和 `User request: <args>` 之间追加一段 compact package context（只列路径，**不内联文件内容** —— progressive disclosure 原则，让 agent 用 Read 工具按需读取）。

**本 story 不做什么（Out of Scope）：**
- 不内联 supporting file 内容（违反 progressive disclosure；会撑爆 prompt）
- 不修改 `SkillLoader`（baseDir/supportingFiles 已经正确填充）
- 不修改 `Skill` struct（字段已存在，参见 SkillTypes.swift:96/103）
- 不修改 `executeSkill` / `executeSkillStream` 的 tool restrictions / modelOverride / state restoration 逻辑
- 不修改 programmatic skill（无 baseDir）的现有 prompt 形状 —— 严格向后兼容
- 不改 E2E 测试（E2E 推迟到 Story 29.7，参见 project-context.md #29）

## Acceptance Criteria

1. **AC1: Filesystem skill 包含绝对 baseDir**
   - **Given** 一个 filesystem skill（`baseDir` 非空，例如 `/abs/path/to/skills/foo`），且 `supportingFiles` 含有相对路径（例如 `references/workflow-steps.md`）
   - **When** `executeSkillStream(skillName, args:)` 或 `executeSkill(skillName, args:)` 运行
   - **Then** 发送给 LLM 的 prompt（即 `promptImpl(prompt)` / `stream(prompt)` 的入参）包含**绝对** baseDir（即 `/abs/path/to/skills/foo`）
   - **And** prompt 包含 supporting file 的**相对**路径（即 `references/workflow-steps.md`，不展开为绝对路径）

2. **AC2: Compact context 格式遵循 epic 规定的 prompt shape**
   - **Given** filesystem skill 同时有 `baseDir` 和 `supportingFiles`
   - **When** prompt 被组装
   - **Then** prompt 形状遵循以下顺序：`<promptTemplate>` → `---` → `Skill package context:` 块 → 指导行（"Resolve bare supporting-file paths relative to baseDir..."） → `---` → `User request: <args>`（若有 args）
   - **And** 不包含任何 supporting file 的**文件内容**（只列路径）

3. **AC3: Programmatic skill 保持向后兼容**
   - **Given** 一个 programmatic skill（`baseDir == nil` **且** `supportingFiles` 为空）
   - **When** `executeSkillStream` / `executeSkill` 运行
   - **Then** 组装的 prompt 与本 story 实施前的形状**完全一致**（即 `promptTemplate` + `---` + `User request: <args>`，无任何 "Skill package context" 段落）
   - **And** 现有的 `executeSkill_*` / `executeSkillStream_*` 测试全部继续通过（无回归）

4. **AC4: 仅 baseDir 或仅 supportingFiles 的边缘情况**
   - **Given** 一个 skill 只有 `baseDir`（`supportingFiles` 为空）—— 或反之只有 `supportingFiles`（`baseDir == nil`）
   - **When** prompt 被组装
   - **Then** 仍然追加 "Skill package context:" 块（只要有任一字段非空）
   - **And** 仅渲染存在的字段：缺 `supportingFiles` 时不输出空的 `supportingFiles:` 行；缺 `baseDir` 时输出 `baseDir: <none>` 或省略该行（实现细节由 dev 决定，但**绝对路径仍然可解析** —— 若 baseDir 缺失但 supportingFiles 存在，dev 应输出一条 diagnostic 说明无法解析，或省略 supportingFiles 列表）

5. **AC5: "User request: <args>" 行为兼容**
   - **Given** filesystem skill 带有 `args` 参数
   - **When** prompt 组装
   - **Then** `User request: <args>` 仍然出现在 prompt 末尾（package context 之后），格式与本 story 实施前一致
   - **And** 无 `args` 时 `User request:` 行不出现（保持现有行为，参见 Agent.swift:3214-3218）

6. **AC6: Build 与全量回归**
   - **Given** 本 story 的所有改动完成
   - **When** `swift build` 和 `swift test` 运行
   - **Then** 构建零新警告，全部测试通过
   - **And** 完成记录中包含新的总测试数（Story 29.2 baseline: 5706 tests passing）

## Tasks / Subtasks

- [x] Task 1: 抽出 prompt builder helper（AC: #2, #4）
  - [x] 1.1 在 `Sources/OpenAgentSDK/Core/Agent.swift` `resolveSkillForExecution(_:, args:)`（行 ~3206-3220）附近，抽出一个 private helper，例如 `buildSkillExecutionPrompt(skill: Skill, args: String?) -> String`。Helper 签名必须独立于 `Result` 返回类型，使其只负责 prompt 字符串构造（输入：已验证可用的 `Skill`；输出：完整 prompt 字符串）。
  - [x] 1.2 Helper 内部分支：
    - 若 `skill.baseDir == nil && skill.supportingFiles.isEmpty` → 走 legacy 路径（`promptTemplate` + 可选 `User request:`），输出与本 story 实施前**逐字符一致**
    - 否则 → 在 `promptTemplate` 后插入 package context 块，然后再追加可选 `User request:`
  - [x] 1.3 重构 `resolveSkillForExecution` 调用新 helper（替换行 3213-3218 的内联 `if let args` 逻辑），保持 `.success((skill, prompt))` 返回形状不变。
  - [x] 1.4 不引入新文件，不引入新模块依赖 —— helper 是 `Agent` 类的 private 方法（与 `resolveSkillForExecution` 同一可见性、同一文件、同一 MARK 区域 `// MARK: - Skill Execution Helpers`）。

- [x] Task 2: 实现 package context 块（AC: #1, #2, #4）
  - [x] 2.1 Package context 块的精确文本（参照 epic 文档行 124-139 的 prompt shape）：
    ```
    
    ---
    Skill package context:
    - baseDir: <absolute skill dir>           ← 仅当 skill.baseDir != nil 时输出
    - supportingFiles:                         ← 仅当 !supportingFiles.isEmpty 时输出
      - references/workflow-steps.md          ← 每个 supportingFile 一行，保持原始相对路径
      - scripts/run.sh
    
    Resolve bare supporting-file paths relative to baseDir. Read supporting files only when the skill instructions require them.
    ```
  - [x] 2.2 末尾 `---` 分隔符之后才追加 `User request: <args>`（若有 args），保持 epic prompt shape 的视觉顺序。
  - [x] 2.3 **不展开** supporting file 路径为绝对路径 —— 保留相对形式，由 agent 在运行时用 baseDir 解析（这是 progressive disclosure 设计，参见 SkillTypes.swift:98-103 的文档注释）。
  - [x] 2.4 **不读取** supporting file 内容 —— 只列路径。
  - [x] 2.5 边缘情况处理（AC4）：若 `baseDir == nil` 但 `supportingFiles` 非空，输出 `baseDir: <none>` 并保留 supportingFiles 列表（agent 收到后会看到路径但无法直接解析；这是合理状态，由 skill 作者负责提供 baseDir —— 本 story 不为这种异常情况抛错，只在 prompt 中如实呈现）。若 `baseDir != nil` 但 `supportingFiles` 为空，只输出 `baseDir:` 行，省略 `supportingFiles:` 部分。

- [x] Task 3: 保持向后兼容性（AC: #3, #5）
  - [x] 3.1 确认 programmatic skill（`baseDir == nil && supportingFiles.isEmpty`）的输出路径**逐字符**等于现有实现：`"\(skill.promptTemplate)\n\n---\nUser request: \(args)"`（有 args）或 `skill.promptTemplate`（无 args）。**关键：分隔符 `---` 之前是 `\n\n`，不是 `\n`** —— 参见 Agent.swift:3215 的现有拼接。
  - [x] 3.2 确认无 args 时不输出 `User request:` 行。
  - [x] 3.3 确认现有 `executeSkill_*` / `executeSkillStream_*` 测试全部通过 —— 这些测试使用 `makeTestSkill()`（GitTestHelpers.swift:222-242），其默认构造不传 baseDir/supportingFiles，因此走 legacy 路径。

- [x] Task 4: 扩展单元测试（AC: #1, #2, #3, #4, #5）
  - [x] 4.1 在 `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift` 末尾添加新 MARK 区段：`// MARK: - Story 29.3: Direct Skill Package Context`。
  - [x] 4.2 添加以下测试用例（unit-level，mock-based，无真实网络 I/O，遵守 project-context.md #27）：
    - `testExecuteSkillStream_promptContainsAbsoluteBaseDir_whenFilesystemSkill` —— 注册一个带 `baseDir: "/abs/skill/dir"` 和 `supportingFiles: ["references/workflow-steps.md"]` 的 Skill，调用 `executeSkillStream`，断言发送到 mock URL protocol 的 request body 中包含字符串 `/abs/skill/dir`
    - `testExecuteSkillStream_promptContainsRelativeSupportingFiles` —— 同上 skill，断言 request body 包含 `references/workflow-steps.md`（相对路径，**不是** `/abs/skill/dir/references/workflow-steps.md`）
    - `testExecuteSkillStream_promptDoesNotContainSupportingFileContents` —— 同上 skill，在某个 supporting file 的路径下不写任何内容（或写一个独有 token），断言 prompt 不包含那个 token（验证 progressive disclosure，只列路径不内联内容）
    - `testExecuteSkillStream_promptShape_followsEpicSpec` —— 同上 skill，断言 prompt 顺序：`promptTemplate` 出现在 `Skill package context:` 之前，`Skill package context:` 出现在 `User request:` 之前
    - `testExecuteSkillStream_promptUnchanged_whenProgrammaticSkill` —— 注册一个无 baseDir/supportingFiles 的 Skill（`makeTestSkill(...)` 默认参数），断言 prompt 等于现有形状 `"\(promptTemplate)\n\n---\nUser request: \(args)"`
    - `testExecuteSkillStream_promptUnchanged_whenProgrammaticSkillNoArgs` —— 无 args 时，断言 prompt 等于 `promptTemplate`（无 `User request:` 行）
    - `testExecuteSkillStream_promptHasPackageContext_whenOnlyBaseDir` —— Skill 只有 `baseDir`，无 supportingFiles；断言包含 `baseDir:` 行但不含 `supportingFiles:` 行
    - `testExecuteSkillStream_promptHasPackageContext_whenOnlySupportingFiles` —— Skill 只有 `supportingFiles`，`baseDir == nil`；断言包含 `supportingFiles:` 行（且有 `<none>` 或类似的 baseDir 缺失标识）
  - [x] 4.3 在 `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift` 同步添加对应的非 stream 版本（至少 3 个：baseDir 出现 / 向后兼容 / package context 顺序），保证 `executeSkill` 路径也覆盖。
  - [x] 4.4 **观察策略（关键）：** `resolveSkillForExecution` 是 `private`，无法直接测试。必须通过 mock URL protocol 捕获 LLM 请求 body 来观察。具体做法：
    - 扩展现有 `SkillStreamMockURLProtocol`（ExecuteSkillStreamTests.swift:214-238）—— 添加一个 `nonisolated(unsafe) static var lastRequestBody: Data?`，在 `startLoading()` 中通过 `readRequestBodyFromStream(...)`（MockURLProtocolHelpers.swift:11）读取 `httpBodyStream` 并存入 `lastRequestBody`。测试用例从该变量解析出 JSON 并断言 prompt 内容。
    - 对 `ExecuteSkillTests`（非 stream 路径），需要类似的 mock 捕获。现有 `ExecuteSkillTests.swift` 没有捕获 request body 的 mock —— dev 应在该文件中新增一个独立的 mock URL protocol（命名为 `SkillRequestRecordingURLProtocol`）或扩展现有的，遵守 project-context.md #56（"不要重复实现 mock" —— 优先扩展现有 `SkillStreamMockURLProtocol` 或抽出共享 recording helper）。
  - [x] 4.5 不要新建独立测试文件 —— 复用现有 `ExecuteSkillStreamTests.swift` 和 `ExecuteSkillTests.swift`。
  - [x] 4.6 E2E 推迟到 Story 29.7（参见 epic 文档 29.7 节，本 story 不写 E2E）。

- [x] Task 5: 构建与全量回归（AC: #6）
  - [x] 5.1 `swift build` 成功，零新警告
  - [x] 5.2 `swift test` 全量通过；完成记录包含新的总测试数（baseline 5706）
  - [x] 5.3 确认无 Swift 编译器错误引用 `Task` 类型（本 story 不引入新类型，但 helper 名称不能与 Swift Concurrency `Task` 冲突 —— 建议命名为 `buildSkillExecutionPrompt` 或类似，避免 `Task` 字样）
  - [x] 5.4 确认现有 13 个 `executeSkill*` 测试全部继续通过（ExecuteSkillTests.swift 7 个 + ExecuteSkillStreamTests.swift 6 个，无回归）

## Dev Notes

### Architecture Context

这是 **Epic 29 的第 3 个 story**，是 epic 依赖图中与 29.4 平行的下游分支：

```
29.1 (DONE)  -->  29.2 (DONE)
                  |
                  +--> 29.3 (THIS STORY)
                  |
                  +--> 29.4 (Tool declaration compatibility)
                          |
                          +--> 29.5, 29.6, 29.7
```

29.3 的实施**只触碰** `Sources/OpenAgentSDK/Core/Agent.swift` 的 `// MARK: - Skill Execution Helpers` 区段（行 3194-3220），不依赖 `SubAgentLauncherNames`、`AgentTool`、`DefaultSubAgentSpawner` 等其他 Epic 29 改动。完全独立于 29.4。

### CRITICAL: 当前代码事实（必须先读）

**目标位置：** `Sources/OpenAgentSDK/Core/Agent.swift` 行 3206-3220

```swift
private func resolveSkillForExecution(_ skillName: String, args: String?) -> Result<(Skill, String), SkillResolutionError> {
    guard let skill = options.skillRegistry?.find(skillName) else {
        return .failure(SkillResolutionError(message: "Skill \"\(skillName)\" not found or not registered"))
    }
    guard skill.isAvailable() else {
        return .failure(SkillResolutionError(message: "Skill \"\(skillName)\" is not available in the current environment"))
    }
    let prompt: String
    if let args, !args.isEmpty {
        prompt = "\(skill.promptTemplate)\n\n---\nUser request: \(args)"
    } else {
        prompt = skill.promptTemplate
    }
    return .success((skill, prompt))
}
```

**两个调用方（不需要改动，自动继承 helper 行为）：**
- `executeSkill(_:args:)` 在 Agent.swift:1243 调用 `resolveSkillForExecution`
- `executeSkillStream(_:args:)` 在 Agent.swift:1305 调用 `resolveSkillForExecution`

调用方消费 `(skill, prompt)` 元组中的 `prompt` 字符串，分别传给 `promptImpl(prompt)`（行 1284）和 `stream(prompt)`（行 1338）。这两个调用方**完全不知道** prompt 是怎么组装的，因此 helper 重构对它们透明。

### 关键字段（已存在，本 story 复用）

`Sources/OpenAgentSDK/Types/SkillTypes.swift`：

| 字段 | 类型 | 默认值 | 由谁填充 |
|---|---|---|---|
| `promptTemplate` (行 83) | `String` | 必填 | skill 作者 |
| `baseDir` (行 96) | `String?` | `nil` | `SkillLoader`（filesystem skill）/ programmatic skill 保持 nil |
| `supportingFiles` (行 103) | `[String]` | `[]` | `SkillLoader`（扫描 skill 目录）/ programmatic skill 保持空 |

`baseDir` 的文档注释（SkillTypes.swift:91-96）明确说明："Set by `SkillLoader` when loading skills from the filesystem. `nil` for programmatically created skills. Used by the SkillTool to provide the agent with the skill's location for on-demand reference loading via Read tool." —— 这正是本 story 要兑现的语义。

`supportingFiles` 的文档注释（SkillTypes.swift:98-103）明确说明："Only the paths are recorded; file contents are NOT loaded (progressive disclosure)." —— 本 story 必须遵守：只列路径，不内联内容。

### Prompt Shape 规范（epic 文档行 124-139）

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

**实现注意事项：**
- `<skill.promptTemplate>` 与第一个 `---` 之间用 `\n\n` 分隔（与现有 legacy 拼接 `"\(promptTemplate)\n\n---\n..."` 一致）
- `User request:` 段落的 `---` 前面也是 `\n\n`（保持视觉一致性）
- supporting files 列表每一项前面是 `\n  - `（两空格缩进 + 连字符 + 空格）
- 多个 supporting file 顺序保持 `supportingFiles` 数组的原始顺序（project-context.md #46：Array 顺序确定性）

### Module Boundary Compliance (project-context.md #7)

- helper 是 `Agent`（Core/）的 private 方法，所有依赖都在 Core/ 内部
- `Skill` 类型来自 `Types/SkillTypes.swift`，Core/ 已经 import Types/，无新依赖
- 不修改 Types/（字段已存在）
- 不修改 Tools/（本 story 与 SkillTool 无关 —— SkillTool 是 LLM-facing tool，本 story 改的是 direct execution 路径）
- 不修改 Skills/（SkillLoader 已经正确填充 baseDir/supportingFiles）

### 观察策略详解（Task 4.4 关键）

`resolveSkillForExecution` 是 `private`，无法直接单元测试。**唯一可观察的副作用**是它返回的 `prompt` 字符串最终通过 `promptImpl(prompt)` / `stream(prompt)` 发送给 LLM API（即 Anthropic `/v1/messages` 端点的 request body）。

**捕获方法：** 用 mock URL protocol 拦截请求，读取 `httpBodyStream`，解析 JSON，断言 `messages[0].content[0].text`（system 或第一条 user message）包含期望的 prompt 片段。

**已有基础设施（复用，不要重写）：**
- `readRequestBodyFromStream(_:)` —— MockURLProtocolHelpers.swift:11-27，读取 InputStream 到 Data
- `makeMockURLSession(protocolClass:)` —— MockURLProtocolHelpers.swift:34-37，创建 ephemeral session
- `SkillStreamMockURLProtocol` —— ExecuteSkillStreamTests.swift:214-238，已有 mock URL protocol，需要扩展记录 request body

**推荐扩展模式：**
```swift
private final class SkillStreamMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var mockResponses: [String: (Int, [String: String], Data)] = [:]
    nonisolated(unsafe) static var lastRequestBody: Data?  // ← 新增

    override func startLoading() {
        // 新增：在原有逻辑之前记录 request body
        if let stream = request.httpBodyStream {
            Self.lastRequestBody = readRequestBodyFromStream(stream)
        } else if let body = request.httpBody {
            Self.lastRequestBody = body
        }
        // ... 原有 mock 响应逻辑 ...
    }

    static func reset() {
        mockResponses = [:]
        lastRequestBody = nil  // ← 新增
    }
}
```

测试用例：
```swift
func testExecuteSkillStream_promptContainsAbsoluteBaseDir_whenFilesystemSkill() async {
    let registry = SkillRegistry()
    registry.register(Skill(
        name: "filesystem-skill",
        description: "Test filesystem skill",
        promptTemplate: "Run the workflow",
        baseDir: "/abs/skill/dir",
        supportingFiles: ["references/workflow-steps.md"]
    ))
    setupMockResponse()
    let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
    let agent = Agent(options: AgentOptions(
        apiKey: "test-key", model: "claude-sonnet-4-6",
        tools: getAllBaseTools(tier: .core),
        skillRegistry: registry
    ), client: client)

    let stream = agent.executeSkillStream("filesystem-skill", args: "do thing")
    for await _ in stream {}

    let body = SkillStreamMockURLProtocol.lastRequestBody
    XCTAssertNotNil(body)
    let bodyString = String(data: body!, encoding: .utf8) ?? ""
    XCTAssertTrue(bodyString.contains("/abs/skill/dir"),
                  "Expected prompt to contain absolute baseDir; got: \(bodyString)")
}
```

**注意：** 由于 `request.httpBodyStream` 只能读取一次，且 mock URL protocol 在 `startLoading` 中读完后流就消耗了，dev 需要确认 `readRequestBodyFromStream` 不会破坏后续 Anthropic SDK 对 body 的读取（实际上 URLProtocol 拦截发生在 URLSession 层，body 流归 URLProtocol 所有，Anthropic SDK 不会再次读取 —— 这是安全的）。如果遇到流读取问题，可以读取后重新设置 `request.httpBody`（备份到 `Data` 再赋值给 `URLRequest.httpBody`）。

### Anti-Patterns to Avoid (project-context.md)

- ❌ **不要 force-unwrap (`!`)** —— 测试中用 `guard let body = ... else { XCTFail(...); return }`（rule #40）
- ❌ **不要 throw 从 helper** —— helper 是纯字符串构造，永远返回 String（rule #39 是针对 tool handler，但 helper 也应保持纯函数性）
- ❌ **不要内联 supporting file 内容** —— 只列路径（progressive disclosure，SkillTypes.swift:98-103 文档明确）
- ❌ **不要修改 `executeSkill` / `executeSkillStream` 的 tool restriction / modelOverride / state restoration 逻辑** —— 这些与本 story 无关
- ❌ **不要破坏 legacy 路径** —— programmatic skill（无 baseDir/supportingFiles）的 prompt 必须**逐字符**等于现有输出（AC3）
- ❌ **不要在测试中创建新的 mock URL protocol 类** —— 扩展现有 `SkillStreamMockURLProtocol`（rule #56）
- ❌ **不要写真实网络 I/O 测试** —— 所有测试用 mock URL protocol（rule #27）
- ❌ **不要命名为 `Task` 开头的 helper** —— 例如 `TaskSkillPromptBuilder` 违反 rule #15；用 `buildSkillExecutionPrompt`
- ❌ **不要使用 Set** —— supportingFiles 顺序必须保持，用 Array 迭代（rule #46）

### Testing Standards

- XCTest only（rule #23）
- 测试目录结构镜像源码：`Tests/OpenAgentSDKTests/Tools/Advanced/`（rule #24，与现有 `ExecuteSkillTests.swift` / `ExecuteSkillStreamTests.swift` 同位置）
- 单 action 测试：每个测试调用一次 `executeSkill` / `executeSkillStream`，断言一个 prompt 特征（rule 习惯，与现有测试风格一致）
- `await` 用于 actor 隔离方法（rule #26）
- E2E 推迟到 Story 29.7（rule #29 + epic 29.7 明确列出 ExecuteSkillStreamTests 是单元测试目标）
- 不修改 `makeTestSkill()` helper 的签名 —— 它的默认参数（无 baseDir/supportingFiles）正好用于测试 legacy 路径；filesystem skill 测试直接构造 `Skill(...)` 而非用 helper

### Previous Story Intelligence (Story 29.2)

Story 29.2（commit 5dd0ea2）完成于 2026-06-14，5706 tests passing。关键学习对本 story 适用：

- **抽 helper 而非内联 if-else 的模式在 Core/ 工作良好** —— 29.2 抽了 `SubAgentLauncherNames` enum；本 story 抽 `buildSkillExecutionPrompt` 方法。两者都在 Core/ 内部、private 可见性、与原有 caller 同 MARK 区段。
- **doc comment 更新对维护者重要** —— 29.2 更新了 `createSubAgentSpawner` 和 `filterTools` 的 doc comment；本 story 应更新 `resolveSkillForExecution` 的 doc comment，说明新追加的 package context 行为。
- **mock URL protocol 扩展而非新建是已验证模式** —— 29.2 复用了 `SpawnerMockURLProtocol`；本 story 复用 `SkillStreamMockURLProtocol` 并扩展 `lastRequestBody` 字段。
- **AC6 "全量回归 + 报告总测试数" 是 Epic 29 的硬性要求**（参见 epic 文档 29.7 AC 第 1 条）。

### Previous Story Intelligence (Story 29.1)

Story 29.1（commit 923bd6b）完成于 2026-06-14，5695 tests passing。关键学习：

- **抽 shared factory 在 Tools/Advanced/ 工作良好** —— 29.1 抽了 `createSubAgentLauncherTool(name:description:)`；本 story 抽 `buildSkillExecutionPrompt` 在 Core/。两者都是 "extract from existing inline logic" 重构。
- **测试覆盖 helper 的所有分支是必要的** —— 29.1 测了 AgentToolInput 所有字段；本 story 必须测 legacy 路径、package context 路径、仅 baseDir、仅 supportingFiles 四个分支（见 Task 4.2）。

### Git Intelligence (recent commits)

```
fbf001c fix(core): propagate sub-agent toolCalls from QueryResult.toolPairs
ee158e9 chore: add BMAD agent workspace config (skills, hooks, AGENTS.md)
5dd0ea2 feat(core): unify Agent/Task spawner detection and child filtering (Story 29-2)
923bd6b feat(tools): add createTaskTool() as Claude Code Task alias (Story 29-1)
3a42f5c fix: surface SSE error messages in errorDuringExecution result
```

最近的 `fbf001c` (sub-agent toolCalls propagation) 修改了 `Agent.swift` 但在 `executeSkillStream` 之外的路径；本 story 的目标行（3206-3220）未受影响。`5dd0ea2` 在 `createSubAgentSpawner`（行 3227+）区域，与本 story 的 `resolveSkillForExecution`（行 3206-3220）相邻但不重叠 —— 注意实施时不要混淆这两个 helper。

### Latest Technical Information

- **Swift 5.9+ typed throws** —— 本 helper 是同步纯函数，无 throws 需求（rule #6 不适用）
- **String 拼接性能** —— `supportingFiles.map { "  - \($0)" }.joined(separator: "\n")` 是习惯写法；避免在循环中 `+=` 拼接（性能虽不关键但代码风格统一）
- **跨平台 Foundation only** —— `String`、`[String]`、可选绑定都是 Foundation 标准库，无 macOS-only 风险（rule #44）
- **不引入 JSONEncoder/Decoder** —— helper 不做序列化（rule #48 不适用）

### Files to Modify/Create

- **MODIFY**: `Sources/OpenAgentSDK/Core/Agent.swift`
  - 行 3194-3220 `// MARK: - Skill Execution Helpers` 区段
  - 抽出 `private func buildSkillExecutionPrompt(skill: Skill, args: String?) -> String`
  - 更新 `resolveSkillForExecution` 调用新 helper
  - 更新 `resolveSkillForExecution` 的 doc comment，说明新追加的 package context 行为
- **MODIFY**: `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift`
  - 扩展 `SkillStreamMockURLProtocol`：添加 `nonisolated(unsafe) static var lastRequestBody: Data?`，在 `startLoading()` 中记录 request body，在 `reset()` 中清空
  - 添加 `// MARK: - Story 29.3: Direct Skill Package Context` 区段
  - 添加 8 个新测试方法（Task 4.2 列表）
- **MODIFY**: `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift`
  - 添加对应的非 stream 版本测试（Task 4.3，至少 3 个）
  - 如需 mock 捕获 request body，扩展或新增 `SkillRequestRecordingURLProtocol`（但优先尝试复用 `SkillStreamMockURLProtocol` 模式，rule #56）

**不修改：**
- `Sources/OpenAgentSDK/Types/SkillTypes.swift`（字段已存在）
- `Sources/OpenAgentSDK/Skills/SkillLoader.swift`（已正确填充 baseDir/supportingFiles）
- `Tests/OpenAgentSDKTests/GitTestHelpers.swift`（`makeTestSkill` 默认参数正好用于 legacy 路径测试）

**无 `.docc` 文档需要更新** —— `resolveSkillForExecution` 和新 helper 都是 `private`，不进入 DocC 公共目录。

### Dependencies and Blockers

**Upstream (DONE):**
- Story 29.1 (`createTaskTool()`) — DONE，commit 923bd6b。本 story 不依赖它，但同属 Epic 29。
- Story 29.2 (`SubAgentLauncherNames`) — DONE，commit 5dd0ea2。本 story 不依赖它，目标代码区段相邻。

**Downstream (本 story 解锁):**
- 无直接下游阻塞。Story 29.7 (Tests and Documentation) 会扩展本 story 的测试，但 29.7 是 Epic 收尾 story，本 story 已经自带完整单元测试。
- Axion Epic 40 (`/bmad-story-pipeline` integration) 会消费这个 prompt shape 来运行 BMAD workflow skill —— filesystem skill 的 supporting files（如 `references/workflow-steps.md`）需要 baseDir 才能可靠解析。

**No blockers remain.**

### Out of Scope (Deferred to Later Stories)

- E2E 测试（filesystem skill 端到端读取 supporting file） → **Story 29.7**
- Tool declaration compatibility（保留 MCP/custom/raw tool 名称） → **Story 29.4**
- Shared filtering helper → **Story 29.5**
- Deferred field diagnostics → **Story 29.6**
- Filesystem subagent loader (`.claude/agents/*.md`) → **future epic**
- 修改 `SkillLoader` 来填充更多 metadata → **out of epic 29 scope**

### References

- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#Story 29.3] — story 定义、ACs、实施步骤、prompt shape 规范
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#Story 间依赖关系] — 依赖图显示 29.3 与 29.4 平行
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#当前代码事实] — `resolveSkillForExecution` 当前只拼 promptTemplate + User request
- [Source: docs/epics/epic-29-claude-code-skill-subagent-compat.md#关键设计约束] — 向后兼容、不静默放权
- [Source: _bmad-output/implementation-artifacts/29-1-agent-task-shared-subagent-launcher.md] — Story 29.1 完成记录（5695 tests，commit 923bd6b）
- [Source: _bmad-output/implementation-artifacts/29-2-spawner-detection-child-filtering.md] — Story 29.2 完成记录（5706 tests，commit 5dd0ea2），抽 helper 模式参考
- [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-06-14.md] — readiness verdict: READY_WITH_ACTIONS，Epic 29 已就绪
- [Source: _bmad-output/project-context.md#7] — 模块边界规则（Core/ 依赖 Types/）
- [Source: _bmad-output/project-context.md#15] — Swift 类型命名（无 `Task` 类型）
- [Source: _bmad-output/project-context.md#27] — 单元测试 mock 外部 API
- [Source: _bmad-output/project-context.md#29] — E2E 推迟到 Story 29.7
- [Source: _bmad-output/project-context.md#39-51] — anti-patterns：无 throws、无 force-unwrap、无 Core/ imports from Tools/、无 Apple frameworks、复用 mocks
- [Source: _bmad-output/project-context.md#46] — Array 而非 Set 用于有序列表
- [Source: _bmad-output/project-context.md#56] — 复用共享测试基础设施
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift:83] — `promptTemplate` 字段
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift:91-96] — `baseDir` 字段文档（filesystem skill 才有）
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift:98-103] — `supportingFiles` 字段文档（progressive disclosure）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:3206-3220] — `resolveSkillForExecution(_:, args:)` 当前实现（Task 1 目标）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:1243] — `executeSkill` 调用点（自动继承 helper 改动）
- [Source: Sources/OpenAgentSDK/Core/Agent.swift:1305] — `executeSkillStream` 调用点（自动继承 helper 改动）
- [Source: Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift:1-238] — 现有 stream 测试 + `SkillStreamMockURLProtocol`（Task 4 扩展目标）
- [Source: Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift:1-180] — 现有非 stream 测试（Task 4.3 扩展目标）
- [Source: Tests/OpenAgentSDKTests/GitTestHelpers.swift:222-242] — `makeTestSkill()` helper（默认无 baseDir/supportingFiles，正好用于 legacy 测试）
- [Source: Tests/OpenAgentSDKTests/MockURLProtocolHelpers.swift:11-27] — `readRequestBodyFromStream(_:)` helper（Task 4.4 复用）
- [Source: Tests/OpenAgentSDKTests/MockURLProtocolHelpers.swift:34-37] — `makeMockURLSession(protocolClass:)` helper

## Dev Agent Record

### Agent Model Used

Claude (Anthropic) — Claude Code CLI (BMAD dev-story workflow)

### Debug Log References

- Red-phase verification: `swift test --filter "ExecuteSkillStreamTests|ExecuteSkillTests"` → 11 failures (8 stream + 3 non-stream ATDD tests) as expected before implementation.
- Initial green-phase after helper extraction: 6 failures remained. Root cause: captured HTTP request body is raw JSON bytes (forward slashes escaped as `\/`), so `bodyString.contains("/abs/skill/dir")` did not match `\/abs\/skill\/dir`.
- Fix: introduced shared `extractPromptTextFromRequestBody(_:)` helper in `Tests/OpenAgentSDKTests/MockURLProtocolHelpers.swift` that JSON-decodes the body and concatenates `system` + `messages[].content[].text` fields. ATDD stream/non-stream tests switched to this helper for forward-slash-containing assertions.
- Final: `swift test` → **5720 tests passing, 0 failures, 0 regressions** (baseline 5706 → +14 tests: 8 ATDD stream + 3 ATDD non-stream + 3 pre-existing tests counted in the previous build).

### Completion Notes List

- **Task 1 done.** Extracted `private func buildSkillExecutionPrompt(skill: Skill, args: String?) -> String` on `Agent` (Core/), colocated with `resolveSkillForExecution` under `// MARK: - Skill Execution Helpers`. Helper is a pure string constructor (no I/O, no throws).
- **Task 2 done.** Package-context block follows epic-spec prompt shape exactly: `promptTemplate` → `---` → `Skill package context:` → `- baseDir: <abs>` (or `<none>` when nil) → `- supportingFiles:` + indented entries (only when non-empty) → guidance line. Paths are listed verbatim, not expanded to absolute form (progressive disclosure honored). No file contents are read.
- **Task 3 done.** Legacy path for programmatic skills (`baseDir == nil && supportingFiles.isEmpty`) is character-for-character identical to pre-29.3 output: `"\(promptTemplate)\n\n---\nUser request: \(args)"` (or `promptTemplate` when args is nil/empty). Verified by `testExecuteSkill*_promptUnchanged_whenProgrammaticSkill` and `*_NoArgs` tests, both of which use JSON-escaped substring matching.
- **Task 4 done.** ATDD tests already authored in red phase (8 stream + 3 non-stream) were made green:
  - Stream tests extended `SkillStreamMockURLProtocol` with `lastRequestBody: Data?` capture (per Task 4.4 spec).
  - Non-stream tests introduced a sibling mock `SkillRequestRecordingURLProtocol` (per Task 4.4 fallback — the non-stream path had no body-capturing mock).
  - Added shared `extractPromptTextFromRequestBody(_:)` in `MockURLProtocolHelpers.swift` to handle JSON `\/` escapes in captured bodies (rule #56 — shared infra over duplication).
- **Task 5 done.** `swift build` succeeded with zero new warnings. `swift test` reported **5720/5720 passing**. No `Task`-type name conflict introduced (helper named `buildSkillExecutionPrompt`). All 13 pre-existing `executeSkill*` / `executeSkillStream*` tests still pass.
- AC1–AC6 all satisfied. See Files Modified list below.

### File List

- **MODIFIED**: `Sources/OpenAgentSDK/Core/Agent.swift`
  - Extracted `buildSkillExecutionPrompt(skill:args:)` private helper under `// MARK: - Skill Execution Helpers`.
  - Updated `resolveSkillForExecution` to call the helper (legacy return shape preserved).
  - Updated doc comment on `resolveSkillForExecution` to document the new package-context behavior.
- **MODIFIED**: `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift`
  - ATDD tests (already authored in red phase) switched to `extractPromptTextFromRequestBody` helper for forward-slash-containing assertions. Tests for non-slash markers (`Skill package context:`, `User request:`) kept against raw body for prompt-shape ordering checks.
  - `SkillStreamMockURLProtocol.lastRequestBody` capture (already in place) verified working.
- **MODIFIED**: `Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillTests.swift`
  - ATDD tests (already authored in red phase) switched to `extractPromptTextFromRequestBody` helper where needed.
  - Refactored `driveExecuteSkillAndCaptureBody` into `driveExecuteSkillAndCaptureRawBody` + thin string wrapper.
- **MODIFIED**: `Tests/OpenAgentSDKTests/MockURLProtocolHelpers.swift`
  - Added shared `extractPromptTextFromRequestBody(_:)` helper (rule #56: shared infra). JSON-decodes captured request body and concatenates `system` + `messages[].content[].text` so substring assertions survive JSON `\/` escaping.

## Change Log

| Date       | Version | Description                                                                                                  | Author       |
|------------|---------|--------------------------------------------------------------------------------------------------------------|--------------|
| 2026-06-14 | 0.1     | Initial story creation (Story 29.3 of Epic 29 — Direct Skill Package Context).                               | create-story |
| 2026-06-14 | 0.2     | Implemented: extracted `buildSkillExecutionPrompt` helper; filesystem skill prompt now includes `Skill package context:` block (paths only). All 6 ACs satisfied; 5720/5720 tests passing, 0 regressions. | dev-story |
| 2026-06-14 | 0.3     | Code review (bmad-code-review, 3-layer adversarial): production code byte-verified correct against epic spec (legacy path byte-equal, package-context path byte-equal). Applied 2 test-quality patches: (1) fixed vacuously-true AC2 progressive-disclosure test by seeding a real supporting file containing a unique token; (2) tightened AC4 `only-supportingFiles` assertion from OR-union to pinned `- baseDir: <none>`. Full suite re-run: 5720/5720 passing. Story → done. | code-review |
| 2026-06-14 | 0.4     | Checkpoint preview follow-up: replaced the new progressive-disclosure test's force unwrap with `XCTUnwrap` to comply with project Swift rules. Verified `swift build`, targeted `ExecuteSkill*` tests, and full `swift test` (5720 XCTest + 12 Swift Testing tests, 0 failures). | checkpoint-preview |

### Review Findings

Reviewed by 3 parallel adversarial layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor). Production code (`buildSkillExecutionPrompt`) verified byte-correct against epic spec for both the legacy path and the package-context path. All findings target test quality, not production behavior.

#### Patches (applied)

- [x] [Review][Patch] AC2 progressive-disclosure test was vacuously true — unique token never written anywhere, so `!contains(token)` could never fail. Fix: seed a real supporting file under a temporary `baseDir` containing the token, then assert both the path IS present (positive control) and the token is NOT present (real assertion). [Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift:282-331]
- [x] [Review][Patch] AC4 `only-supportingFiles` test asserted an OR-union (`<none>` | `baseDir: nil` | `baseDir not set`) — the implementation only ever produces `- baseDir: <none>`, so the other two branches could never match yet the test would still pass. Fix: pin the assertion to the actual rendering `- baseDir: <none>`. [Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift:497-501]
- [x] [Checkpoint][Patch] New test setup used a force unwrap when writing the seeded supporting file. Fix: unwrap with `XCTUnwrap` before writing so the test follows the project "no force-unwrap" Swift rule. [Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift:297-299]

#### Deferred (pre-existing or out-of-scope)

- [x] [Review][Defer] `extractPromptTextFromRequestBody` only handles `system as? String` and `content as? [[String:Any]]` with String `text` values; does not handle `system` as block-array form (also valid in Anthropic API) or non-text content blocks. Not a defect for current usage (prompt goes into a single text content block), flagged for future awareness. [Tests/OpenAgentSDKTests/MockURLProtocolHelpers.swift:62-77] — deferred, pre-existing test-infrastructure scope
- [x] [Review][Defer] `nonisolated(unsafe) static var lastRequestBody` in both mock URL protocols is a theoretical race under parallel test execution; `ExecuteSkillTests` lacks `setUp`/`tearDown` and relies on manual `reset()`+`defer`. Not currently flaky under default serial test execution. [Tests/OpenAgentSDKTests/Tools/Advanced/ExecuteSkillStreamTests.swift:513, ExecuteSkillTests.swift:311] — deferred, pre-existing test-infrastructure scope
- [x] [Review][Defer] Package-context path does not escape `\n` or `---` inside `supportingFiles` path entries; a path containing these would produce structurally ambiguous prompt. Extremely unlikely from `SkillLoader` (filesystem scan). [Sources/OpenAgentSDK/Core/Agent.swift:3257-3263] — deferred, would require a separate input-sanitization story
- [x] [Review][Defer] `trimmedArgs` name is misleading — it only checks `isEmpty`, does not trim whitespace, so `args = "   "` produces `User request:    ` with literal trailing spaces. Behavior is byte-equal to pre-29.3 (also used `!args.isEmpty`), so not a regression. [Sources/OpenAgentSDK/Core/Agent.swift:3243] — deferred, pre-existing behavior
- [x] [Review][Defer] AC1 absoluteness is not asserted — tests check the path substring appears, but do not assert it begins with `/`. Current implementation passes the registered value through unchanged (correct). Could be hardened in 29.7. — deferred, hardening for Story 29.7

#### Dismissed (noise / false positive / out of scope)

- Blind Hunter initial "inconsistent isEmpty check on args" finding was self-retracted by the reviewer (false positive on re-read).
- Edge Case Hunter "no dedup of supportingFiles" — by design; spec mandates Array order preservation (project-context.md #46), dedup is SkillLoader's responsibility, not the prompt builder's.
- Edge Case Hunter "guidance text contradicts `<none>` baseDir" — true observation, but the `<none>` rendering is explicitly what the spec's Task 2.5 mandates; the apparent contradiction is a documentation/prompt-quality concern, not a code defect.
- Pre-existing doc-comment change to `configuredSubAgents` (lines 914-930) is from Story 29.1/29.2, not part of 29-3 — out of review scope.

# Story 11.3: 内置技能 — Commit

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望 Agent 具有 Git Commit 技能，
以便它可以分析变更并生成规范的提交信息。

## Acceptance Criteria

1. **AC1: CommitSkill 注册与 promptTemplate 执行 Git 分析** — 给定 CommitSkill 已注册到 SkillRegistry，当 LLM 调用 commit 技能，则技能的 promptTemplate 指导 Agent 执行 `git status --short`、`git diff --cached` 和 `git diff`（未暂存变更）（FR53）。

2. **AC2: 无暂存但有未暂存变更** — 给定有未暂存变更但没有暂存变更（`git diff --cached` 为空，`git diff` 有输出），当 commit 技能执行，则 Agent 输出"没有暂存的变更，请先 git add 相关文件"并列出未暂存的具体文件。

3. **AC3: 无任何变更** — 给定没有暂存变更且没有未暂存变更（`git diff --cached` 和 `git diff` 输出均为空），当 commit 技能执行，则 Agent 输出"没有暂存的变更，请先 git add 相关文件"并建议具体文件。

4. **AC4: 有暂存变更生成提交信息** — 给定有暂存变更，当 commit 技能生成提交信息，则提交信息的 promptTemplate 可被开发者通过 `registry.replace(Skill(name: "commit", promptTemplate: "自定义..."))` 覆盖，且默认模板指导生成祈使语气、标题不超过 72 字符的提交信息。

## Tasks / Subtasks

- [x] Task 1: 更新 BuiltInSkills.commit 的 promptTemplate (AC: #1, #2, #3, #4)
  - [x] 更新 `Sources/OpenAgentSDK/Types/SkillTypes.swift` 中 `BuiltInSkills.commit` 的 `promptTemplate`
  - [x] promptTemplate 必须指导 Agent 执行 `git status --short`、`git diff --cached`、`git diff` 三步分析
  - [x] 包含对无暂存变更的明确处理逻辑（提示 git add）
  - [x] 包含对无任何变更的明确处理逻辑（提示没有需要提交的内容）
  - [x] 提交信息规范：祈使语气、标题不超过 72 字符、多段提交信息格式
  - [x] 明确指出不要实际执行 git commit，只输出建议的提交信息
  - [x] 更新 `description` 字段（如有必要使其更精确）

- [x] Task 2: 更新 BuiltInSkills.commit 的 toolRestrictions 和元数据 (AC: #1, #4)
  - [x] 确认 `toolRestrictions: [.bash, .read, .glob, .grep]` 覆盖 git 命令执行（bash）和文件读取（read、glob、grep）需求
  - [x] 确认 `aliases: ["ci"]` 正确
  - [x] 确认 `userInvocable: true`
  - [x] 确认 `isAvailable` 默认为 `{ true }`（Git 是基本工具，不做额外环境检查）

- [x] Task 3: 编写单元测试 (AC: #1-#4)
  - [x] 创建/更新 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/CommitSkillTests.swift`
  - [x] 测试 BuiltInSkills.commit 的所有属性值（name、aliases、toolRestrictions、userInvocable）
  - [x] 测试 promptTemplate 包含关键指令（git status、git diff --cached、git diff、祈使语气、72 字符限制）
  - [x] 测试 promptTemplate 包含"不要实际执行 git commit"的指令
  - [x] 测试 promptTemplate 包含处理无暂存变更和无变更场景的指令
  - [x] 测试 SkillRegistry 可以注册和查找 BuiltInSkills.commit
  - [x] 测试 registry.replace() 可以覆盖 commit 技能的 promptTemplate

- [x] Task 4: 验证编译通过并运行完整测试套件
  - [x] `swift build` 编译无错误
  - [x] `swift test` 全部通过，无回归

## Dev Notes

### 本 Story 的定位

- Epic 11（技能系统）的第三个 Story
- **核心目标：** 精化 Commit 技能的 promptTemplate，使其完全符合 epics.md 中的验收标准。BuiltInSkills.commit 的基础结构已在 Story 11.1 中创建，本 Story 仅需更新 promptTemplate 文本和补充单元测试
- **前置依赖：** Story 11.1（Skill 类型定义和 SkillRegistry）、Story 11.2（SkillTool 执行工具）
- **后续依赖：** 无直接后续依赖（Story 11.4-11.7 为其他内置技能，独立实现）
- **FR 覆盖：** FR53（内置技能的 promptTemplate 指导 Agent 执行特定工作流）

### 关键发现：当前 promptTemplate 与 epics 要求的差异

**当前 promptTemplate（Story 11.1 中创建的骨架）：**
```
Create a git commit for the current changes. Follow these steps:

1. Run `git status` and `git diff --cached` to understand what's staged
2. If nothing is staged, run `git diff` to see unstaged changes and suggest what to stage
3. Analyze the changes and draft a concise commit message that:
   - Uses imperative mood ("Add feature" not "Added feature")
   - Summarizes the "why" not just the "what"
   - Keeps the first line under 72 characters
   - Adds a body with details if the change is complex
4. Create the commit

Do NOT push to remote unless explicitly asked.
```

**epics.md 要求（必须对齐）：**
1. 步骤 1 使用 `git status --short`（不是 `git status`）-- 更简洁的输出格式
2. 步骤 2 检查 `git diff --cached` 为空时需要运行 `git diff` 查看未暂存变更并**提示用户需要先 git add**
3. 如果两个 diff 都为空（无变更），告知用户"没有需要提交的内容"
4. **不要实际执行 git commit**，只输出建议的提交信息
5. 多段提交信息格式：标题 + 空行 + 详细说明

**需要修改的关键点：**
- 步骤 4 "Create the commit" 必须改为"不要实际执行 git commit，只输出建议的提交信息"
- 增加 `git status --short` 替代 `git status`
- 增加明确的无变更处理逻辑
- 增加多段提交信息格式要求

### TypeScript SDK 参考映射

| Swift 类型/属性 | TypeScript 对应 | 文件 |
|---|---|---|
| `BuiltInSkills.commit` | `registerCommitSkill()` | `src/skills/bundled/commit.ts` |
| `promptTemplate` (静态字符串) | `COMMIT_PROMPT` + `getPrompt(args)` (动态) | `src/skills/bundled/commit.ts` |
| `toolRestrictions: [.bash, .read, .glob, .grep]` | `allowedTools: ['Bash', 'Read', 'Glob', 'Grep']` | `src/skills/bundled/commit.ts` |
| `aliases: ["ci"]` | `aliases: ['ci']` | `src/skills/bundled/commit.ts` |

**关键差异：**
- TS SDK 的 `getPrompt()` 接收 `args` 参数，可追加用户额外指令（`Additional instructions: ${args}`）。Swift v1.0 的 `promptTemplate` 是静态字符串，`args` 由 SkillTool 在运行时处理（SkillTool 11.2 返回的 JSON 中包含 prompt）
- TS SDK 使用 `allowedTools` 白名单（只允许列出的工具），Swift 使用 `toolRestrictions`（语义相同，仅命名差异）
- 两者 COMMIT_PROMPT 文本几乎一致，但 Swift 版本需按 epics.md 要求增加"不要实际执行 git commit"的指令

### 已有代码模式参考

**BuiltInSkills.commit 当前定义（SkillTypes.swift:143-165）：**
```swift
public static var commit: Skill {
    Skill(
        name: "commit",
        description: "Create a git commit with a well-crafted message based on staged changes.",
        aliases: ["ci"],
        userInvocable: true,
        toolRestrictions: [.bash, .read, .glob, .grep],
        promptTemplate: """
        Create a git commit for the current changes. Follow these steps:
        ...
        """
    )
}
```

本 Story 仅需更新 `promptTemplate` 字符串内容，不改变结构、属性或类型定义。

**SkillRegistry 的 replace 方法（已在 11.1 中实现）：**
```swift
registry.replace(Skill(name: "commit", promptTemplate: "自定义模板..."))
```
这是 AC4 的验证方式 -- 开发者可以通过 replace 覆盖 promptTemplate。

### 模块边界

**本 Story 涉及文件：**
- `Sources/OpenAgentSDK/Types/SkillTypes.swift` — 修改：更新 `BuiltInSkills.commit` 的 `promptTemplate`
- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/CommitSkillTests.swift` — 新建：单元测试

```
Sources/OpenAgentSDK/
├── Types/
│   ├── SkillTypes.swift              # 修改：BuiltInSkills.commit promptTemplate
│   └── ...
└── ...

Tests/OpenAgentSDKTests/
├── Tools/
│   ├── BuiltInSkills/
│   │   ├── CommitSkillTests.swift    # 新建
│   │   └── ...
│   └── ...
└── ...
```

### Logger 集成约定

本 Story 不涉及新增 Logger 调用点（仅更新 promptTemplate 文本）。

### 反模式警告

- **不要**在 promptTemplate 中指导 Agent 执行 `git commit` -- 只输出建议的提交信息
- **不要**在 promptTemplate 中指导 Agent 执行 `git push` -- 除非用户明确要求
- **不要**修改 Skill struct、SkillRegistry 或 SkillTool 的任何代码 -- 仅更新 BuiltInSkills.commit 的 promptTemplate 字符串
- **不要**将 CommitSkill 改为动态 prompt 生成 -- 使用静态 promptTemplate（与 TypeScript SDK v1.0 的 COMMIT_PROMPT 对齐）
- **不要**创建新的类型或文件来存放 promptTemplate -- 保持 BuiltInSkills.commit 作为内联定义
- **不要**修改 BuiltInSkills.review、BuiltInSkills.simplify 等其他技能 -- 它们是后续 Story 11.4-11.7 的范围
- **不要**忘记测试 promptTemplate 包含"不要实际执行 git commit"的指令 -- 这是 AC4 的关键验证点
- **不要**在测试中 mock BashTool 来验证 git 命令 -- 单元测试只验证 promptTemplate 文本内容，不验证工具调用行为

### 测试策略

单元测试覆盖所有 AC：

1. **AC1 测试**：promptTemplate 包含 `git status --short`、`git diff --cached`、`git diff` 三个关键指令
2. **AC2 测试**：promptTemplate 包含对"无暂存变更但有未暂存变更"场景的处理指令
3. **AC3 测试**：promptTemplate 包含对"无任何变更"场景的处理指令
4. **AC4 测试**：
   - promptTemplate 包含祈使语气要求
   - promptTemplate 包含 72 字符标题限制
   - promptTemplate 包含"不要实际执行 git commit"的指令
   - registry.replace() 可以覆盖 promptTemplate（验证 SkillRegistry 的 replace 机制对 commit 技能有效）

**测试隔离：**
- 使用 `SkillRegistry()` 创建独立注册表
- 测试 `BuiltInSkills.commit` 返回的 Skill 实例属性
- 不需要 mock LLM 或 BashTool -- 仅验证 promptTemplate 文本内容

### 前序 Story 学习要点

**Story 11.1 完成情况：**
- SkillTypes.swift: ToolRestriction enum (22 cases), Skill struct (Sendable), BuiltInSkills namespace (5 skills)
- SkillRegistry.swift: final class + DispatchQueue, 支持完整的注册、查找、替换、列表 API
- 28 个 SkillRegistryTests 全部通过
- BuiltInSkills.commit 的骨架 promptTemplate 已存在但需要精化

**Story 11.2 完成情况：**
- SkillTool.swift: 通过 defineTool 创建，返回 JSON 格式的 ToolResult
- ToolRestrictionStack.swift: 栈模型管理工具限制
- ToolContext 新增 skillRegistry、restrictionStack、skillNestingDepth、maxSkillRecursionDepth
- 35 个 SkillTool/ToolRestrictionStack 测试通过
- 完整测试套件: 2151 tests, 0 failures, 4 skipped

**关键接口（本 Story 直接使用）：**
- `BuiltInSkills.commit` — 返回 Skill 实例（值类型，每次返回新实例）
- `SkillRegistry.register(_ skill:)` — 注册技能
- `SkillRegistry.replace(_ skill:)` — 替换技能（AC4 验证）
- `SkillRegistry.find(_ name:) -> Skill?` — 按名称或别名查找
- `Skill.promptTemplate` — promptTemplate 字符串属性

### Project Structure Notes

- CommitSkillTests 放在 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/` 子目录下（新建目录），与其他内置技能测试（后续 Story 创建）并列
- 完全对齐架构文档的目录结构：`Tests/OpenAgentSDKTests/Tools/` 下按功能分组

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.3] — 验收标准和需求定义（promptTemplate 骨架和四项 AC）
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11 技能系统] — Epic 级别上下文和跨 Story 依赖
- [Source: _bmad-output/planning-artifacts/epics.md#FR53] — 内置技能功能需求
- [Source: _bmad-output/planning-artifacts/architecture.md#AD4] — 工具系统基于协议的 Codable 输入模式
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Actor/struct 边界、命名约定、反模式
- [Source: open-agent-sdk-typescript/src/skills/bundled/commit.ts] — TypeScript SDK Commit 技能实现（COMMIT_PROMPT 文本和注册逻辑）
- [Source: open-agent-sdk-typescript/src/skills/types.ts] — TypeScript SDK SkillDefinition 接口
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift] — BuiltInSkills.commit 当前定义（需更新 promptTemplate）
- [Source: Sources/OpenAgentSDK/Tools/SkillRegistry.swift] — SkillRegistry（register/replace/find 用于测试）
- [Source: _bmad-output/implementation-artifacts/11-1-skill-type-definition-skill-registry.md] — Story 11.1 开发记录
- [Source: _bmad-output/implementation-artifacts/11-2-skill-tool-skill-execution.md] — Story 11.2 开发记录

## Dev Agent Record

### Agent Model Used

Claude GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Updated `BuiltInSkills.commit` promptTemplate in SkillTypes.swift to meet all 4 ACs
- Key changes to promptTemplate:
  - Replaced `git status` with `git status --short` (AC1)
  - Added explicit `git diff --cached` and `git diff` analysis steps (AC1)
  - Added handling for "nothing is staged" with `git add` suggestion (AC2)
  - Added handling for "no changes at all" with "Nothing to commit" message (AC3)
  - Removed "Create the commit" instruction, replaced with "Do NOT actually execute `git commit`" (AC4)
  - Added imperative mood requirement, 72-char title limit, multi-paragraph format (AC4)
- Updated description from "Create a git commit..." to "Analyze staged and unstaged changes, then suggest..."
- Verified toolRestrictions, aliases, userInvocable, isAlready metadata are correct (Task 2)
- All 26 ATDD tests pass (CommitSkillTests)
- Full test suite: 2177 tests, 0 failures, 4 skipped

### File List

- `Sources/OpenAgentSDK/Types/SkillTypes.swift` — modified: updated BuiltInSkills.commit promptTemplate and description
- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/CommitSkillTests.swift` — pre-existing ATDD tests (26 tests, all pass)

## Change Log

- 2026-04-11: Story implementation complete. Updated promptTemplate to meet AC1-AC4. All 26 ATDD tests pass. Full suite 2177 tests pass, 0 failures.

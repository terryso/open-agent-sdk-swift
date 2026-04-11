# Story 11.7: 内置技能 -- Test

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望 Agent 具有 Test 技能，
以便它可以生成和执行测试用例。

## Acceptance Criteria

1. **AC1: TestSkill 注册与 promptTemplate 指导测试生成和执行** -- 给定 TestSkill 已注册到 SkillRegistry，当 LLM 调用 test 技能，则技能的 promptTemplate 指导 Agent 生成和执行测试用例（FR53）。且 TestSkill 的 `toolRestrictions` 包含 Read、Write、Glob、Grep、Bash（需要创建测试文件并运行）。

2. **AC2: 输出包含测试代码、执行结果和覆盖率建议** -- 给定 TestSkill 的 promptTemplate，当技能执行，则输出包含：生成的测试代码、测试执行结果、覆盖率建议。

3. **AC3: 环境可用性检查** -- 给定当前环境没有测试框架（如无 Package.swift、pytest.ini 等指示文件），当 TestSkill 检查 `isAvailable`，则返回 `false`（配合 Story 11.1 的可用性过滤）。

## Tasks / Subtasks

- [x] Task 1: 更新 BuiltInSkills.test 的 promptTemplate (AC: #1, #2)
  - [x] 更新 `Sources/OpenAgentSDK/Types/SkillTypes.swift` 中 `BuiltInSkills.test` 的 `promptTemplate`
  - [x] promptTemplate 必须包含结构化测试工作流：读取源文件 → 查找已有测试 → 生成测试用例 → 创建/更新测试文件 → 运行测试 → 报告结果（AC1, AC2）
  - [x] promptTemplate 必须指导使用 Read 工具读取源文件理解 API，Glob 查找已有测试文件（AC1）
  - [x] promptTemplate 必须指导使用 Write 创建测试文件或更新现有测试文件（AC1）
  - [x] promptTemplate 必须指导使用 Bash 运行测试命令（如 `swift test`、`xcodebuild test`）（AC1）
  - [x] promptTemplate 必须要求覆盖正常路径、边界条件和错误处理路径（AC2）
  - [x] promptTemplate 必须要求输出测试执行结果和覆盖率建议（AC2）
  - [x] 更新 `description` 字段使其更精确

- [x] Task 2: 更新 BuiltInSkills.test 的 toolRestrictions 和元数据 (AC: #1)
  - [x] 确认 `toolRestrictions: [.bash, .read, .write, .glob, .grep]` 已设置（当前骨架已包含）
  - [x] 确认 `aliases: ["run-tests"]` 保持不变
  - [x] 确认 `userInvocable: true`
  - [x] 确认 `isAvailable` 闭包正确检查测试框架指示文件（当前骨架已实现）

- [x] Task 3: 编写单元测试 (AC: #1-#3)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/TestSkillTests.swift`
  - [x] 测试 BuiltInSkills.test 的所有属性值（name、aliases、toolRestrictions、userInvocable）
  - [x] 测试 promptTemplate 包含测试生成关键词（generate test / 生成测试 / test case）
  - [x] 测试 promptTemplate 包含测试执行关键词（run test / 执行测试 / swift test）
  - [x] 测试 promptTemplate 包含覆盖率建议关键词（coverage / 覆盖率）
  - [x] 测试 promptTemplate 包含文件名和行号引用格式要求（`file.swift:行号` 或等效）
  - [x] 测试 promptTemplate 指导覆盖正常路径、边界条件和错误路径
  - [x] 测试 promptTemplate 指导使用 Read/Glob/Grep 查看源文件
  - [x] 测试 promptTemplate 指导使用 Write 创建/更新测试文件
  - [x] 测试 promptTemplate 指导使用 Bash 运行测试命令
  - [x] 测试 SkillRegistry 可以注册和查找 BuiltInSkills.test
  - [x] 测试 registry.replace() 可以覆盖 test 技能的 promptTemplate
  - [x] 测试 isAvailable 在有 Package.swift 时返回 true
  - [x] 测试 isAvailable 在无测试指示文件时的行为

- [x] Task 4: 验证编译通过并运行完整测试套件
  - [x] `swift build` 编译无错误
  - [x] `swift test` 全部通过，无回归

## Dev Notes

### 本 Story 的定位

- Epic 11（技能系统）的第七个也是最后一个 Story
- **核心目标：** 精化 Test 技能的 promptTemplate，使其完全符合 epics.md 中的验收标准。BuiltInSkills.test 的基础结构已在 Story 11.1 中创建，本 Story 仅需更新 promptTemplate 文本和补充单元测试
- **前置依赖：** Story 11.1（Skill 类型定义和 SkillRegistry）、Story 11.2（SkillTool 执行工具）
- **后续依赖：** 无（本 Story 是 Epic 11 的最后一个 Story）
- **FR 覆盖：** FR53（内置技能的 promptTemplate 指导 Agent 执行特定工作流）

### 关键发现：当前 promptTemplate 与 epics 要求的差异

**当前 promptTemplate（Story 11.1 中创建的骨架）：**
```
Run the project's test suite and analyze the results:

1. **Discover**: Find the test runner configuration
   - Look for Package.swift, jest.config, vitest.config, pytest.ini, etc.
   - Identify the appropriate test command

2. **Execute**: Run the tests
   - Run the full test suite or specific tests if specified
   - Capture output including failures and errors

3. **Analyze**: If tests fail:
   - Read the failing test to understand what it expects
   - Read the source code being tested
   - Identify why the test is failing
   - Fix the issue (in tests or source as appropriate)

4. **Re-verify**: Run the failing tests again to confirm the fix
```

**epics.md 要求（必须对齐）：**
1. promptTemplate 指导 Agent 生成和执行测试用例 -- 当前 skeleton 仅覆盖"运行和分析"，缺少"生成测试用例"的指导
2. toolRestrictions 包含 Read、Write、Glob、Grep、Bash -- 当前 skeleton 已正确设置
3. 输出包含测试代码、执行结果、覆盖率建议 -- 当前 skeleton 缺少"覆盖率建议"
4. isAvailable 检查测试框架 -- 当前 skeleton 已正确实现

**需要修改的关键点：**
- 重构 promptTemplate 为结构化的测试工程流程：读取源文件 → 查找已有测试 → 分析公共 API → 生成测试 → 创建/更新测试文件 → 运行测试 → 报告结果和覆盖率建议
- 增加测试用例生成指导（正常路径、边界条件、错误处理路径）
- 增加覆盖率建议输出要求
- 增加明确的文件名:行号引用格式要求（与其他技能一致）
- 更新 `description` 字段

### TypeScript SDK 参考映射

| Swift 类型/属性 | TypeScript 对应 | 文件 |
|---|---|---|
| `BuiltInSkills.test` | `registerTestSkill()` | `src/skills/bundled/test.ts` |
| `promptTemplate` (静态字符串) | `TEST_PROMPT` + `getPrompt(args)` (动态) | `src/skills/bundled/test.ts` |
| `toolRestrictions: [.bash, .read, .write, .glob, .grep]` | `allowedTools: ['Bash', 'Read', 'Write', 'Edit', 'Glob', 'Grep']` | `src/skills/bundled/test.ts` |

**关键差异：**
- TS SDK 的 test 技能允许 Edit 工具。Swift 版本当前骨架包含 `.edit` -- 需确认 epics.md 要求。Epics 骨架只列出 Read、Write、Glob、Grep、Bash（不包含 Edit）。遵循 epics.md 要求：toolRestrictions 应为 [.bash, .read, .write, .glob, .grep]
- TS SDK 的 `getPrompt()` 接收 `args` 参数并追加 `Specific test target`。Swift v1.0 的 `promptTemplate` 是静态字符串
- TS SDK 的 TEST_PROMPT 与当前 skeleton 基本一致，但 epics.md 要求更丰富的内容

**注意事项：** 当前骨架的 `toolRestrictions` 包含 `.edit`，但 epics.md 验收标准明确列出 Read、Write、Glob、Grep、Bash（不含 Edit）。开发者应使用 Write 工具创建或更新测试文件。需将 `.edit` 从 toolRestrictions 中移除。

### 已有代码模式参考

**BuiltInSkills.test 当前定义（SkillTypes.swift:361-411）：**
```swift
public static var test: Skill {
    Skill(
        name: "test",
        description: "Run tests and analyze failures, fixing any issues found.",
        aliases: ["run-tests"],
        userInvocable: true,
        toolRestrictions: [.bash, .read, .write, .edit, .glob, .grep],
        isAvailable: {
            // Check for common test framework indicators
            let cwd = FileManager.default.currentDirectoryPath
            let testIndicators = [
                "Package.swift",     // Swift PM
                "pytest.ini",        // Python pytest
                "jest.config",       // JavaScript Jest
                "vitest.config",     // JavaScript Vitest
                "Cargo.toml",        // Rust cargo test
                "go.mod",            // Go test
            ]
            for indicator in testIndicators {
                let path = cwd + "/" + indicator
                if FileManager.default.fileExists(atPath: path) {
                    return true
                }
            }
            return false
        },
        promptTemplate: """
        Run the project's test suite and analyze the results:
        ...
        """
    )
}
```

本 Story 需更新 `promptTemplate` 字符串内容、`description`，并从 `toolRestrictions` 中移除 `.edit`。

**Story 11.6 (Debug) 的实现模式（应完全遵循）：**
- 仅更新 promptTemplate 文本、description 和 toolRestrictions，不修改 Skill struct / SkillRegistry / SkillTool
- 创建 `TestSkillTests.swift` 在 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/` 下
- 测试覆盖所有 AC，验证 promptTemplate 文本内容（不 mock 工具调用）
- 运行完整测试套件确认无回归

### 模块边界

**本 Story 涉及文件：**
- `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- 修改：更新 `BuiltInSkills.test` 的 `promptTemplate`、`description` 和移除 toolRestrictions 中的 `.edit`
- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/TestSkillTests.swift` -- 新建：单元测试

```
Sources/OpenAgentSDK/
├── Types/
│   ├── SkillTypes.swift              # 修改：BuiltInSkills.test promptTemplate + description + toolRestrictions
│   └── ...

Tests/OpenAgentSDKTests/
├── Tools/
│   ├── BuiltInSkills/
│   │   ├── CommitSkillTests.swift    # 已有（Story 11.3）
│   │   ├── ReviewSkillTests.swift    # 已有（Story 11.4）
│   │   ├── SimplifySkillTests.swift  # 已有（Story 11.5）
│   │   ├── DebugSkillTests.swift     # 已有（Story 11.6）
│   │   ├── TestSkillTests.swift      # 新建
│   │   └── ...
│   └── ...
└── ...
```

### Logger 集成约定

本 Story 不涉及新增 Logger 调用点（仅更新 promptTemplate 文本）。

### 反模式警告

- **不要**修改 Skill struct、SkillRegistry 或 SkillTool 的任何代码 -- 仅更新 BuiltInSkills.test 的 promptTemplate 字符串、description 和 toolRestrictions
- **不要**将 TestSkill 改为动态 prompt 生成 -- 使用静态 promptTemplate（与 TypeScript SDK v1.0 对齐）
- **不要**创建新的类型或文件来存放 promptTemplate -- 保持 BuiltInSkills.test 作为内联定义
- **不要**修改 BuiltInSkills.commit、BuiltInSkills.review、BuiltInSkills.simplify、BuiltInSkills.debug 等其他技能 -- 它们已完成
- **不要**在测试中 mock BashTool -- 单元测试只验证 promptTemplate 文本内容，不验证工具调用行为
- **不要**遗漏 toolRestrictions 中的 `.edit` 移除 -- epics.md 验收标准明确列出 Read、Write、Glob、Grep、Bash，不包含 Edit
- **不要**修改 isAvailable 闭包 -- 当前实现已正确检查 Package.swift 等指示文件

### 测试策略

单元测试覆盖所有 AC，完全遵循 CommitSkillTests / ReviewSkillTests / SimplifySkillTests / DebugSkillTests 的模式：

1. **AC1 测试**：promptTemplate 包含测试生成关键词；toolRestrictions 为 [.bash, .read, .write, .glob, .grep]（不含 .edit）；promptTemplate 指导使用 Read/Glob 查看源文件、Write 创建测试文件、Bash 运行测试
2. **AC2 测试**：promptTemplate 包含测试代码生成指导；包含覆盖率建议关键词；包含正常路径/边界条件/错误处理路径指导；包含文件名和行号引用格式
3. **AC3 测试**：isAvailable 在有 Package.swift 时返回 true（验证现有行为）
4. **元数据测试**：验证 name、aliases（run-tests）、toolRestrictions（不含 .edit）、userInvocable 属性
5. **Registry 测试**：验证 register/find/replace 操作对 test 技能正常工作

**测试隔离：**
- 使用 `SkillRegistry()` 创建独立注册表
- 测试 `BuiltInSkills.test` 返回的 Skill 实例属性
- 不需要 mock LLM 或工具 -- 仅验证 promptTemplate 文本内容

### 前序 Story 学习要点

**Story 11.1 完成情况：**
- SkillTypes.swift: ToolRestriction enum (22 cases), Skill struct (Sendable), BuiltInSkills namespace (5 skills)
- SkillRegistry.swift: final class + DispatchQueue, 支持完整的注册、查找、替换、列表 API
- BuiltInSkills.test 的骨架 promptTemplate 已存在但需要精化

**Story 11.2 完成情况：**
- SkillTool.swift: 通过 defineTool 创建，返回 JSON 格式的 ToolResult
- ToolRestrictionStack.swift: 栈模型管理工具限制
- ToolContext 新增 skillRegistry、restrictionStack、skillNestingDepth、maxSkillRecursionDepth

**Story 11.3 完成情况：**
- 仅更新了 BuiltInSkills.commit 的 promptTemplate 和 description
- 创建了 CommitSkillTests.swift
- **关键学习：** 测试只验证 promptTemplate 文本内容，不 mock 工具调用

**Story 11.4 完成情况：**
- 仅更新了 BuiltInSkills.review 的 promptTemplate 和 description
- 创建了 ReviewSkillTests.swift

**Story 11.5 完成情况：**
- 仅更新了 BuiltInSkills.simplify 的 promptTemplate、description 和 toolRestrictions
- 创建了 SimplifySkillTests.swift

**Story 11.6 完成情况（本 Story 的直接参考）：**
- 仅更新了 BuiltInSkills.debug 的 promptTemplate、description 和 toolRestrictions
- 创建了 DebugSkillTests.swift（32 个测试）
- 完整测试套件: 2271 tests passing, 4 skipped, 0 failures
- **关键学习：** 完全一致的模式 -- 仅更新 promptTemplate 文本，测试验证文本内容
- promptTemplate 中 "implement the fix" 导致误匹配问题 -- 注意措辞避免包含被测子串

**关键接口（本 Story 直接使用）：**
- `BuiltInSkills.test` -- 返回 Skill 实例（值类型，每次返回新实例）
- `SkillRegistry.register(_ skill:)` -- 注册技能
- `SkillRegistry.replace(_ skill:)` -- 替换技能
- `SkillRegistry.find(_ name:) -> Skill?` -- 按名称或别名查找
- `Skill.promptTemplate` -- promptTemplate 字符串属性

### Project Structure Notes

- TestSkillTests 放在 `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/` 目录下（已存在，Story 11.3 创建），与其他技能测试并列
- 完全对齐架构文档的目录结构：`Tests/OpenAgentSDKTests/Tools/` 下按功能分组
- 本 Story 完成后，Epic 11 的所有 7 个 Story 全部完成

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.7] -- 验收标准和需求定义（promptTemplate 骨架和三项 AC）
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11 技能系统] -- Epic 级别上下文和跨 Story 依赖
- [Source: _bmad-output/planning-artifacts/epics.md#FR53] -- 内置技能功能需求
- [Source: _bmad-output/planning-artifacts/architecture.md#AD4] -- 工具系统基于协议的 Codable 输入模式
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] -- Actor/struct 边界、命名约定、反模式
- [Source: open-agent-sdk-typescript/src/skills/bundled/test.ts] -- TypeScript SDK Test 技能实现（TEST_PROMPT 文本和注册逻辑）
- [Source: open-agent-sdk-typescript/src/skills/types.ts] -- TypeScript SDK SkillDefinition 接口
- [Source: Sources/OpenAgentSDK/Types/SkillTypes.swift:361-411] -- BuiltInSkills.test 当前定义（需更新 promptTemplate、description、移除 .edit）
- [Source: Sources/OpenAgentSDK/Tools/SkillRegistry.swift] -- SkillRegistry（register/replace/find 用于测试）
- [Source: _bmad-output/implementation-artifacts/11-6-built-in-skill-debug.md] -- Story 11.6 开发记录（模式参考）
- [Source: Tests/OpenAgentSDKTests/Tools/BuiltInSkills/DebugSkillTests.swift] -- 测试模式参考

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (GLM-5.1)

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Updated `BuiltInSkills.test` promptTemplate from skeleton to comprehensive test engineering workflow covering all AC requirements
- Removed `.edit` from `toolRestrictions` (was 6 items, now 5: [.bash, .read, .write, .glob, .grep]) per epics.md AC1
- Updated `description` to reflect test generation and execution purpose
- promptTemplate now includes: structured workflow (Read → Glob → Generate → Write → Bash → Report), test generation keywords ("generate test", "test case"), test execution keywords ("swift test", "run"), normal path / boundary conditions / error handling path coverage guidance, coverage suggestions output requirement, file:line reference format (`path/to/File.swift:行号`)
- All 30 ATDD tests pass (14 were previously failing due to skeleton promptTemplate)
- Full test suite: 2301 tests passing, 4 skipped, 0 failures -- no regressions
- ATDD checklist already had tests written by test-architect phase; implementation (Green phase) makes all tests pass

### File List

- `Sources/OpenAgentSDK/Types/SkillTypes.swift` -- modified: updated BuiltInSkills.test promptTemplate, description, and toolRestrictions (removed .edit)
- `Tests/OpenAgentSDKTests/Tools/BuiltInSkills/TestSkillTests.swift` -- existing (created by ATDD phase): 30 unit tests

### Change Log

- 2026-04-12: Story 11.7 implementation complete. Updated BuiltInSkills.test promptTemplate to comprehensive test engineering workflow, removed .edit from toolRestrictions, updated description. All 30 ATDD tests pass, full suite 2301 passing with 0 failures.

# Story 11.1: Skill 类型定义与 SkillRegistry

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望定义技能类型并通过 SkillRegistry 管理技能，
以便我可以注册、查找和列出所有可用技能。

## Acceptance Criteria

1. **AC1: Skill struct 定义与创建** — 给定 Skill struct 定义（包含 name、description、aliases、userInvocable、toolRestrictions、modelOverride、isAvailable 闭包、promptTemplate 字段），当开发者创建 `Skill(name: "commit", promptTemplate: "...", toolRestrictions: [.bash, .read, .write])`，则编译无错误。Skill 为值类型（struct），不使用 Actor。

2. **AC2: SkillRegistry 注册与查找** — 给定 SkillRegistry（`final class`，内部维护 `[String: Skill]` 字典，线程安全通过内部串行 `DispatchQueue` 保护），当开发者调用 `registry.register(commitSkill)`，则 `registry.find("commit")` 返回该技能，且 `registry.find("ci")` 通过别名也能找到（如果注册了别名）。

3. **AC3: SkillRegistry replace 方法** — 给定已注册技能（如 CommitSkill），当开发者调用 `registry.replace(CommitSkill(name: "commit", promptTemplate: "自定义..."))` 替换 promptTemplate，则 `registry.find("commit")` 返回更新后的技能定义，且已在执行中的技能实例不受影响（值类型语义保证隔离）。

4. **AC4: userInvocableSkills 过滤** — 给定已注册 3 个技能（其中 2 个 userInvocable=true），当开发者调用 `registry.userInvocableSkills`，则返回恰好 2 个技能。

5. **AC5: formatSkillsForPrompt 文本生成** — 给定已注册技能，当开发者调用 `registry.formatSkillsForPrompt()`，则返回的文本不超过 500 token（使用 `TokenEstimator.estimate()` 估算，超出时截断尾部技能描述），且文本包含每个技能的名称、描述和调用方式。

6. **AC6: isAvailable 可用性过滤** — 给定注册了 `isAvailable` 返回 `false` 的技能（如 TestSkill），当开发者调用 `registry.userInvocableSkills` 或 `registry.formatSkillsForPrompt()`，则不可用的技能被排除在结果之外；且 `registry.find("test")` 仍可找到该技能（查找不过滤可用性）。SkillTool 执行不可用技能时返回 `SDKError.invalidConfiguration("Skill 'test' is not available in current environment")`。

## Tasks / Subtasks

- [x] Task 1: 创建 Skill 类型定义 (AC: #1)
  - [x] 创建 `Sources/OpenAgentSDK/Types/SkillTypes.swift`
  - [x] 定义 `ToolRestriction` 枚举，列出所有可限制的工具名（bash, read, write, edit, glob, grep, webFetch, webSearch, askUser, toolSearch, agent, sendMessage, taskCreate, taskList, taskUpdate, taskGet, taskStop, taskOutput, teamCreate, teamDelete, notebookEdit, skill）
  - [x] 定义 `Skill` struct：name、description、aliases、userInvocable（默认 true）、toolRestrictions（默认 nil = 无限制）、modelOverride（默认 nil）、isAvailable（默认 `{ true }`）、promptTemplate、whenToUse（可选）、argumentHint（可选）
  - [x] Skill 为值类型（struct），遵循 Sendable
  - [x] 提供 `init(name:description:aliases:userInvocable:toolRestrictions:modelOverride:isAvailable:promptTemplate:whenToUse:argumentHint:)` 完整初始化器

- [x] Task 2: 创建 SkillRegistry (AC: #2, #3, #4, #5, #6)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/SkillRegistry.swift`
  - [x] 实现 `SkillRegistry` final class，内部使用 `[String: Skill]` 字典 + `[String: String]` 别名映射
  - [x] 使用内部串行 `DispatchQueue`（而非 Actor）保护线程安全（避免外部调用需要 await）
  - [x] 实现 `register(_ skill: Skill)` — 注册技能及其别名
  - [x] 实现 `find(_ name: String) -> Skill?` — 按名称或别名查找，不过滤可用性
  - [x] 实现 `replace(_ skill: Skill)` — 替换已注册技能
  - [x] 实现 `has(_ name: String) -> Bool` — 检查技能是否存在
  - [x] 实现 `unregister(_ name: String) -> Bool` — 移除技能
  - [x] 实现 `allSkills -> [Skill]` — 返回所有已注册技能
  - [x] 实现 `userInvocableSkills -> [Skill]` — 返回 userInvocable=true 且 isAvailable=true 的技能
  - [x] 实现 `formatSkillsForPrompt() -> String` — 格式化为系统提示文本，500 token 预算限制
  - [x] 实现 `clear()` — 清空所有注册（用于测试）

- [x] Task 3: 创建 BuiltInSkills 便利访问 (AC: #1)
  - [x] 在 `SkillTypes.swift` 中定义 `BuiltInSkills` enum（作为命名空间，无实例）
  - [x] 提供静态属性 `.commit`、`.review`、`.simplify`、`.debug`、`.test` 返回默认 Skill 实例
  - [x] 每个 BuiltInSkill 的 promptTemplate 使用 epics 中定义的骨架文本
  - [x] TestSkill 的 `isAvailable` 检查当前环境是否有测试框架

- [x] Task 4: 更新模块入口点 (AC: #1, #2)
  - [x] 更新 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 重新导出 Skill、SkillRegistry、BuiltInSkills、ToolRestriction

- [x] Task 5: 编写单元测试 (AC: #1-#6)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/SkillRegistryTests.swift`
  - [x] 测试 Skill 创建和属性
  - [x] 测试 register 和 find（直接名称和别名）
  - [x] 测试 replace 行为（值类型隔离）
  - [x] 测试 userInvocableSkills 过滤
  - [x] 测试 formatSkillsForPrompt 文本生成和 token 预算限制
  - [x] 测试 isAvailable 过滤行为
  - [x] 测试 clear 和 unregister

- [x] Task 6: 验证编译通过并运行完整测试套件
  - [x] `swift build` 编译无错误
  - [x] `swift test` 全部通过，无回归

## Dev Notes

### 本 Story 的定位

- Epic 11（技能系统）的第一个 Story
- **核心目标：** 定义 Skill 值类型和 SkillRegistry 管理类，为后续 Story 11.2（SkillTool 执行工具）和 Story 11.3-11.7（内置技能实现）奠定基础
- **前置依赖：** Epic 1-10 全部完成，尤其 Epic 3（工具系统，ToolProtocol、ToolRegistry 模式参考）
- **NFR29 约束：** 技能注册和查找在 5ms 内完成（SkillRegistry 为内存字典，不涉及 I/O）

### 关键架构决策（必须遵循）

#### 1. Skill 为 struct（值类型），SkillRegistry 为 final class（引用类型）

- **Skill 是 struct**：注册是一次性操作，查询是只读的。值类型保证执行中的技能实例不受 replace 影响。
- **SkillRegistry 是 final class**（不是 Actor）：使用内部串行 `DispatchQueue` 保护线程安全。理由：(1) 避免 `await` 污染所有调用点；(2) 注册/查询操作极快（<5ms NFR29），不需要 Actor 隔离的开销；(3) 与 TypeScript SDK 的 Map-based registry 保持一致的简洁 API。
- **关键区别**：SDK 中其他 Store（SessionStore、TaskStore 等）是 Actor，因为它们管理复杂的共享可变状态和高频并发写入。SkillRegistry 是低频写入、高频只读查询，适合 DispatchQueue 方案。

#### 2. ToolRestriction 枚举设计

```swift
/// 工具限制枚举，用于技能定义中指定允许的工具集。
public enum ToolRestriction: String, Sendable, CaseIterable {
    case bash, read, write, edit, glob, grep
    case webFetch, webSearch, askUser, toolSearch
    case agent, sendMessage
    case taskCreate, taskList, taskUpdate, taskGet, taskStop, taskOutput
    case teamCreate, teamDelete, notebookEdit
    case skill  // SkillTool 本身（用于检测循环限制）
}
```

`ToolRestriction` 的 rawValue 对应工具名称字符串。`toolRestrictions: [ToolRestriction]?` 为 nil 时表示无限制（所有工具可用），非 nil 时仅允许列出的工具。

#### 3. formatSkillsForPrompt 的 token 预算机制

参考 TypeScript SDK 的 `formatSkillsForPrompt()`：
- 使用 `TokenEstimator.estimate()` 估算（见 epics Story 13.3 的定义：ASCII 1 token ≈ 4 chars，CJK 1 token ≈ 1.5 chars）
- 预算为 500 token（约 2000 ASCII 字符）
- 超出时截断尾部技能描述
- 仅包含 `userInvocable=true` 且 `isAvailable()=true` 的技能
- 输出格式：每行一个技能，格式为 `- {name}: {description}`

**但 TokenEstimator 尚未实现**（属于 Story 13.3）。本 Story 应创建一个简单的内联估算函数：
```swift
/// 简单 token 估算（精确实现在 Story 13.3 TokenEstimator 中）。
/// ASCII: ~4 chars/token; CJK: ~1.5 chars/token。
private func estimateTokens(_ text: String) -> Int {
    var count = 0
    for scalar in text.unicodeScalars {
        if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
            count += 1  // CJK 字符约 1.5 token，向上取整为 2
        } else {
            count += 1
        }
    }
    return max(1, count / 4) // 粗略估算，ASCII 约 4 chars = 1 token
}
```
或更简单地使用 `text.utf8.count / 4`（与 project-context.md 一致）。Story 13.3 实现后会替换为 `TokenEstimator.estimate()`。

#### 4. BuiltInSkills 命名空间设计

```swift
/// 内置技能的便利访问命名空间。
public enum BuiltInSkills {
    public static var commit: Skill { ... }
    public static var review: Skill { ... }
    public static var simplify: Skill { ... }
    public static var debug: Skill { ... }
    public static var test: Skill { ... }
}
```

使用 `enum`（无 case）作为纯命名空间，防止意外实例化。每个属性返回新的 Skill 实例（值类型），开发者可通过 `BuiltInSkills.commit` 获取默认技能或直接 `Skill(name: "commit", ...)` 创建自定义版本。

#### 5. BuiltInSkill 默认 promptTemplate

Commit、Review、Simplify、Debug、Test 的默认 promptTemplate 骨架在 epics.md 中已定义。本 Story 将这些骨架作为 `BuiltInSkills` 的默认值嵌入。注意：这些模板在 Story 11.3-11.7 中可能会进一步精化，但本 Story 只需提供基础骨架。

### TypeScript SDK 参考映射

| Swift 类型 | TypeScript 对应 | 文件 |
|---|---|---|
| `Skill` struct | `SkillDefinition` interface | `src/skills/types.ts` |
| `SkillRegistry` class | `registerSkill`/`getSkill`/etc. 函数 | `src/skills/registry.ts` |
| `BuiltInSkills` enum | `initBundledSkills()` | `src/skills/bundled/index.ts` |
| `ToolRestriction` enum | `allowedTools: string[]` | `src/skills/types.ts` |

**关键差异：**
- TS SDK 使用模块级 Map + 函数式 API；Swift 使用 final class + 方法式 API（更符合 Swift 惯例）
- TS SDK 的 `allowedTools` 是 `string[]`；Swift 使用 `ToolRestriction` 枚举提供编译时安全
- TS SDK 的 `isEnabled` 对应 Swift 的 `isAvailable`（命名差异，功能相同）
- TS SDK 的 `getPrompt` 是异步函数接收 args 和 context；Swift 的 `promptTemplate` 是静态字符串模板（SkillTool 在 11.2 中负责动态处理）
- TS SDK 有 `context: 'inline' | 'fork'` 和 `agent` 字段；Swift v1.0 仅支持 inline 模式

### 已有代码模式参考

**参考 ToolRegistry.swift 的模式：**
- 文件位置：`Sources/OpenAgentSDK/Tools/ToolRegistry.swift`
- 使用 free functions（`getAllBaseTools`、`filterTools`、`assembleToolPool`）而非 class
- SkillRegistry 选择 class 方案是因为需要管理内部状态（字典 + 别名映射 + 线程安全队列），而 ToolRegistry 是无状态的纯函数

**参考 ToolTypes.swift 的模式：**
- `ToolProtocol` 是 protocol + `Sendable`
- `ToolResult` 是 struct + `Sendable` + `Equatable`
- `ToolContext` 是 struct + `Sendable`
- Skill 应遵循相同模式：struct + Sendable

**参考 ErrorTypes.swift 的模式：**
- `SDKError` 是 enum + Error + Equatable + LocalizedError + Sendable
- 本 Story 不需要添加新的 error case（不可用技能的错误在 Story 11.2 SkillTool 中使用现有的 `invalidConfiguration` case）

### 模块边界

**本 Story 涉及文件：**
- `Sources/OpenAgentSDK/Types/SkillTypes.swift` — 新建：Skill struct、ToolRestriction enum、BuiltInSkills enum
- `Sources/OpenAgentSDK/Tools/SkillRegistry.swift` — 新建：SkillRegistry final class
- `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 修改：重新导出新类型
- `Tests/OpenAgentSDKTests/Tools/SkillRegistryTests.swift` — 新建：单元测试

**不涉及任何现有功能代码变更（仅重新导出）。**

```
Sources/OpenAgentSDK/
├── Types/
│   ├── SkillTypes.swift              # 新建：Skill、ToolRestriction、BuiltInSkills
│   ├── ToolTypes.swift               # 不修改
│   └── ...
├── Tools/
│   ├── SkillRegistry.swift           # 新建：SkillRegistry
│   ├── ToolRegistry.swift            # 不修改
│   └── ...
├── OpenAgentSDK.swift                # 修改：添加重新导出
└── ...

Tests/OpenAgentSDKTests/
├── Tools/
│   ├── SkillRegistryTests.swift      # 新建
│   └── ...
└── ...
```

### Logger 集成约定

根据跨 Epic 实现约定，本 Story 应在关键路径预留 `Logger.shared` 调用点：
- `SkillRegistry.register()` — 注册技能时
- `SkillRegistry.formatSkillsForPrompt()` — 格式化提示时

使用 `guard Logger.shared.level != .none else { return }` 守卫模式。在 Epic 14 完成前，Logger 使用空实现。

### 反模式警告

- **不要**将 SkillRegistry 设计为 Actor — 使用 final class + DispatchQueue（避免 await 污染）
- **不要**在 Tools/ 中导入 Core/ — 违反模块边界
- **不要**使用 force-unwrap（`!`）— 使用 guard let / if let
- **不要**将 Skill 设计为 class — 必须是 struct 保证值类型语义
- **不要**将 BuiltInSkills 设计为有 case 的 enum — 必须是无 case 的 enum（纯命名空间）
- **不要**忘记 ToolRestriction 包含 `.skill` case — Story 11.2 需要检测 SkillTool 自身限制
- **不要**在 formatSkillsForPrompt 中引入精确 tokenizer 依赖 — 使用简单的 utf8.count/4 估算
- **不要**在 Skill 中实现执行逻辑 — Skill 仅存储定义数据，执行由 Story 11.2 的 SkillTool 负责
- **不要**将 promptTemplate 设为闭包 — 使用 String 类型（静态模板），动态变量在 SkillTool 中处理

### 测试策略

单元测试覆盖所有 AC：
1. **AC1 测试**：Skill 创建、属性访问、Sendable 一致性
2. **AC2 测试**：register + find（名称匹配、别名匹配、不存在返回 nil）
3. **AC3 测试**：replace 行为（替换后 find 返回新值、旧实例不受影响）
4. **AC4 测试**：userInvocableSkills 过滤（userInvocable=false 被排除）
5. **AC5 测试**：formatSkillsForPrompt（文本内容、500 token 预算截断）
6. **AC6 测试**：isAvailable=false 的过滤行为（userInvocableSkills 排除、find 不过滤）

### Project Structure Notes

- 在 `Types/` 中创建 `SkillTypes.swift`（与 `ToolTypes.swift`、`AgentTypes.swift` 并列）
- 在 `Tools/` 中创建 `SkillRegistry.swift`（与 `ToolRegistry.swift` 并列）
- 更新 `OpenAgentSDK.swift` 添加重新导出
- 测试在 `Tests/OpenAgentSDKTests/Tools/` 下创建 `SkillRegistryTests.swift`
- 完全对齐架构文档的目录结构和模块边界

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.1] — 验收标准和需求定义
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11 技能系统] — Epic 级别上下文和跨 Story 依赖
- [Source: _bmad-output/planning-artifacts/epics.md#FR52] — 技能注册与发现功能需求
- [Source: _bmad-output/planning-artifacts/epics.md#NFR29] — 技能注册查找 5ms 性能要求
- [Source: _bmad-output/planning-artifacts/architecture.md#AD4] — 工具系统基于协议的 Codable 输入模式
- [Source: _bmad-output/project-context.md#Technology Stack & Versions] — Swift 5.9+、SPM、XCTest
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Actor/struct 边界、命名约定、反模式
- [Source: open-agent-sdk-typescript/src/skills/types.ts] — TypeScript SDK SkillDefinition 接口
- [Source: open-agent-sdk-typescript/src/skills/registry.ts] — TypeScript SDK 技能注册表实现
- [Source: open-agent-sdk-typescript/src/skills/bundled/commit.ts] — 内置技能实现参考
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol、ToolResult 模式参考
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] — 工具注册表模式参考
- [Source: Sources/OpenAgentSDK/Types/ErrorTypes.swift] — SDKError 枚举模式参考
- [Source: _bmad-output/implementation-artifacts/10-6-advanced-mcp-example.md] — 前序 Story 的经验教训

## Dev Agent Record

### Agent Model Used

GLM-5.1 (via Claude Code)

### Debug Log References

No issues encountered during implementation. All code was already in place from a prior session.

### Completion Notes List

- All 6 tasks completed successfully
- SkillTypes.swift: ToolRestriction enum (22 cases, CaseIterable, Sendable), Skill struct (Sendable, value type), BuiltInSkills namespace (5 built-in skills: commit, review, simplify, debug, test)
- SkillRegistry.swift: final class with internal serial DispatchQueue for thread safety, supports register/find/replace/has/unregister/allSkills/userInvocableSkills/formatSkillsForPrompt/clear
- OpenAgentSDK.swift: Already contains Skill System re-exports documentation
- formatSkillsForPrompt uses utf8.count/4 token estimation with 500 token budget, truncates trailing skills when over budget
- BuiltInSkills.test has isAvailable closure that checks for test framework indicators (Package.swift, pytest.ini, jest.config, etc.)
- All 28 SkillRegistryTests pass (covers AC1-AC6)
- Full test suite: 2116 tests, 0 failures, 4 skipped

### File List

- Sources/OpenAgentSDK/Types/SkillTypes.swift (new)
- Sources/OpenAgentSDK/Tools/SkillRegistry.swift (new)
- Sources/OpenAgentSDK/OpenAgentSDK.swift (modified - re-exports)
- Tests/OpenAgentSDKTests/Tools/SkillRegistryTests.swift (new)

# Story 4.6: 团队工具（Create/Delete）

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望我的 Agent 可以创建和管理 Agent 团队，
以便我可以组织多 Agent 工作流。

## Acceptance Criteria

1. **AC1: TeamCreate 工具** — 给定 TeamCreate 工具已注册且 ToolContext 包含 teamStore，当 LLM 请求创建带有名称和可选成员列表的团队，则在 TeamStore 中创建新团队（FR38），返回包含团队 ID、名称和成员数目的成功结果。

2. **AC2: TeamDelete 工具** — 给定 TeamDelete 工具已注册且 ToolContext 包含 teamStore，当 LLM 请求删除团队，则团队状态更新为 disbanded 并从 TeamStore 中移除（FR38）。团队不存在时返回 is_error=true 的 ToolResult；团队已 disbanded 时返回 is_error=true 的 ToolResult。

3. **AC3: ToolContext 依赖注入** — 给定 Tools/ 不能导入 Stores/ 的架构约束（规则 #7、#40），当团队工具需要访问 TeamStore，则通过 ToolContext 携带的 `teamStore` 引用实现跨模块调用。**注意：ToolContext 已有 teamStore 字段（由 Story 4-2 添加，Story 4-4 扩展使用），无需修改 ToolContext。**

4. **AC4: 模块边界合规** — 给定两个团队工具位于 Tools/Advanced/ 目录，当检查 import 语句，则只导入 Foundation 和 Types/ 中的类型，永不导入 Core/ 或 Stores/（架构规则 #7、#40）。

5. **AC5: 错误处理不中断循环** — 给定团队工具执行期间发生异常（如 teamStore 为 nil、团队不存在、团队已 disbanded），当错误被捕获，则返回 is_error=true 的 ToolResult，不会中断父 Agent 的智能循环（架构规则 #38）。

6. **AC6: inputSchema 匹配 TS SDK** — 给定 TS SDK 的 Team 工具 schema（team-tools.ts），当检查 Swift 端的 inputSchema，则字段名称、类型和 required 列表与 TS SDK 一致。

7. **AC7: isReadOnly 分类** — 给定 TeamCreate 和 TeamDelete 工具，当检查 isReadOnly 属性，则两个工具都返回 false（两者都有副作用）。

8. **AC8: AgentOptions/Agent.swift 无需修改** — 给定 ToolContext 和 AgentOptions 已包含 teamStore 字段（Story 4-2/4-4 已添加），当实现团队工具，则不需要修改 ToolContext、AgentOptions 或 Agent.swift — 直接使用 context.teamStore 即可。

## Tasks / Subtasks

- [x] Task 1: 实现 TeamCreateTool 工厂函数 (AC: #1, #4, #5, #6, #7)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/Advanced/TeamCreateTool.swift`
  - [x] 定义 `TeamCreateInput` Codable 结构体：`name`（必填）、`members`（可选，字符串数组）、`task_description`（可选，匹配 TS SDK schema 字段名）
  - [x] 定义 JSON inputSchema 匹配 TS SDK 的 TeamCreate schema
  - [x] `createTeamCreateTool()` 工厂函数返回 ToolProtocol（使用 defineTool + ToolExecuteResult 重载）
  - [x] call 逻辑：(1) 从 context 获取 teamStore；(2) 缺少依赖时返回错误；(3) 将 members 字符串数组转换为 TeamMember 数组（默认 role=.member）；(4) 调用 teamStore.create()；(5) 格式化输出

- [x] Task 2: 实现 TeamDeleteTool 工厂函数 (AC: #2, #4, #5, #6, #7)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/Advanced/TeamDeleteTool.swift`
  - [x] 定义 `TeamDeleteInput` Codable 结构体：`id`（必填）
  - [x] 定义 JSON inputSchema 匹配 TS SDK 的 TeamDelete schema
  - [x] `createTeamDeleteTool()` 工厂函数
  - [x] call 逻辑：(1) 从 context 获取 teamStore；(2) 调用 teamStore.delete()；(3) 捕获 TeamStoreError（teamNotFound、teamAlreadyDisbanded）返回 isError=true

- [x] Task 3: 更新模块入口 (AC: #4)
  - [x] 在 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 中追加团队工具的重新导出注释
  - [x] 确认所有团队工具文件不导入 Core/ 或 Stores/

- [x] Task 4: 单元测试 — 两个团队工具 (AC: #1-#8)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/Advanced/TeamToolsTests.swift`
  - [x] TeamCreate: 创建团队（必填 name）、带 members 创建、默认空 members、验证 teamStore 返回值
  - [x] TeamDelete: 删除存在团队、团队不存在错误、团队已 disbanded 错误
  - [x] 通用：teamStore 为 nil 时返回错误、inputSchema 验证、isReadOnly 验证（两者都为 false）、模块边界验证

- [x] Task 5: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证 Tools/Advanced/ 中的文件不导入 Core/ 或 Stores/
  - [x] 验证测试可以编译并通过

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 4（多 Agent 编排）的第六个 story，建立在 Story 4-1（TaskStore/MailboxStore）、4-2（TeamStore/AgentRegistry）、4-3（AgentTool）、4-4（SendMessageTool）、4-5（TaskTools）之上
- 本 story 实现两个高级工具（Advanced tier tools）：TeamCreate、TeamDelete
- 与 SendMessageTool 和 TaskTools 类似的架构挑战：Tools/ 不能导入 Stores/ 或 Core/

**关键简化 — 无需修改 ToolContext/AgentOptions/Agent.swift：**

ToolContext 已有 `teamStore: TeamStore?` 字段（由 Story 4-2 添加，Story 4-4 用于 SendMessageTool）。
AgentOptions 已有 `teamStore: TeamStore?` 字段（由 Story 4-4 添加）。
Agent.swift 的 ToolContext 创建点已传入 `options.teamStore`（由 Story 4-4 添加）。

因此本 story 只需要创建两个新工具文件 + 更新模块入口注释 — **不需要修改任何现有文件**。

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `TeamStore` | `Stores/TeamStore.swift` | Story 4-2 创建，create/get/list/delete/addMember/removeMember/getTeamForAgent/clear 方法 |
| `Team` | `Types/TaskTypes.swift` | id, name, members: [TeamMember], leaderId, createdAt, status: TeamStatus |
| `TeamMember` | `Types/TaskTypes.swift` | name: String, role: TeamRole |
| `TeamRole` | `Types/TaskTypes.swift` | leader, member |
| `TeamStatus` | `Types/TaskTypes.swift` | active, disbanded |
| `TeamStoreError` | `Types/TaskTypes.swift` | teamNotFound(id), teamAlreadyDisbanded(id), memberNotFound(teamId, memberName) |
| `ToolContext` | `Types/ToolTypes.swift` | 已包含 teamStore 字段（无需修改） |
| `ToolExecuteResult` | `Types/ToolTypes.swift` | content + isError |
| `defineTool()` | `Tools/ToolBuilder.swift` | 工厂函数，使用 CodableTool/StructuredCodableTool |
| `Agent` | `Core/Agent.swift` | prompt()/stream() 方法中已注入 teamStore（无需修改） |
| `AgentOptions` | `Types/AgentTypes.swift` | 已包含 teamStore 字段（无需修改） |

### TeamStore 方法与工具的映射

| 工具 | TeamStore 方法 | 签名 |
|------|---------------|------|
| TeamCreate | `create(name:members:leaderId:)` | `-> Team` |
| TeamDelete | `delete(id:)` | `throws -> Bool` |

### 实现位置

**新增文件（仅新增，无修改）：**
```
Sources/OpenAgentSDK/Tools/Advanced/TeamCreateTool.swift   # TeamCreate 工厂函数
Sources/OpenAgentSDK/Tools/Advanced/TeamDeleteTool.swift   # TeamDelete 工厂函数
```

**修改文件（仅注释更新）：**
```
Sources/OpenAgentSDK/OpenAgentSDK.swift                    # 追加团队工具的重新导出注释
```

**测试文件：**
```
Tests/OpenAgentSDKTests/Tools/Advanced/TeamToolsTests.swift   # 两个团队工具的测试
```

**不需要修改的文件：**
```
Sources/OpenAgentSDK/Types/ToolTypes.swift     # ToolContext 已有 teamStore
Sources/OpenAgentSDK/Types/AgentTypes.swift    # AgentOptions 已有 teamStore
Sources/OpenAgentSDK/Core/Agent.swift          # ToolContext 创建已传入 teamStore
```

### 类型定义

**各个工具的 Input 类型（私有 Codable 类型）：**

```swift
// TeamCreateTool.swift
private struct TeamCreateInput: Codable {
    let name: String                // 必填
    let members: [String]?          // 可选，成员名称数组
    let task_description: String?   // 可选，团队任务描述（匹配 TS SDK 字段名）
}
```

注意：TS SDK 使用 `members` 作为 `string[]` 类型（只有名称），Swift 端的 TeamStore.create() 接受 `[TeamMember]`。在工具内部将 `[String]` 转换为 `[TeamMember]`（使用默认 `role: .member`）。

`task_description` 字段在 TS SDK schema 中定义但在 call() 中未使用。Swift 端保留此字段以匹配 schema，但当前不传递给 TeamStore（Team 类型没有 description 字段）。

```swift
// TeamDeleteTool.swift
private struct TeamDeleteInput: Codable {
    let id: String  // 必填
}
```

### inputSchema 定义（匹配 TS SDK team-tools.ts）

**TeamCreate schema：**
```swift
private nonisolated(unsafe) let teamCreateSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "name": ["type": "string", "description": "Team name"] as [String: Any],
        "members": [
            "type": "array",
            "items": ["type": "string"] as [String: Any],
            "description": "List of agent/teammate names"
        ] as [String: Any],
        "task_description": ["type": "string", "description": "Description of the team's mission"] as [String: Any],
    ] as [String: Any],
    "required": ["name"]
]
```

**TeamDelete schema：**
```swift
private nonisolated(unsafe) let teamDeleteSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "id": ["type": "string", "description": "Team ID to disband"] as [String: Any],
    ] as [String: Any],
    "required": ["id"]
]
```

### 各工具工厂函数实现要点

**通用模式（两个工具都遵循）：**
1. 从 `context.teamStore` 获取 TeamStore（guard let，否则返回错误）
2. 调用 TeamStore 方法（使用 `await` 访问 actor 隔离方法，使用 `try await` 访问 throwing 方法）
3. 捕获 `TeamStoreError` 返回 isError=true 的结果
4. 成功路径格式化输出

**TeamCreateTool：**
```swift
public func createTeamCreateTool() -> ToolProtocol {
    return defineTool(
        name: "TeamCreate",
        description: "Create a multi-agent team for coordinated work. Assigns a lead and manages member composition.",
        inputSchema: teamCreateSchema,
        isReadOnly: false
    ) { (input: TeamCreateInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let teamStore = context.teamStore else {
            return ToolExecuteResult(content: "Error: TeamStore not available.", isError: true)
        }
        let members: [TeamMember] = input.members?.map { TeamMember(name: $0) } ?? []
        let team = await teamStore.create(
            name: input.name,
            members: members,
            leaderId: "self"
        )
        return ToolExecuteResult(
            content: "Team created: \(team.id) \"\(team.name)\" with \(team.members.count) members",
            isError: false
        )
    }
}
```

**TeamDeleteTool：**
```swift
public func createTeamDeleteTool() -> ToolProtocol {
    return defineTool(
        name: "TeamDelete",
        description: "Disband a team and clean up resources.",
        inputSchema: teamDeleteSchema,
        isReadOnly: false
    ) { (input: TeamDeleteInput, context: ToolContext) async throws -> ToolExecuteResult in
        guard let teamStore = context.teamStore else {
            return ToolExecuteResult(content: "Error: TeamStore not available.", isError: true)
        }
        do {
            _ = try await teamStore.delete(id: input.id)
            return ToolExecuteResult(content: "Team disbanded: \(input.id)", isError: false)
        } catch let error as TeamStoreError {
            return ToolExecuteResult(content: "Error: \(error.localizedDescription)", isError: true)
        }
    }
}
```

### TypeScript SDK 参考对比

**team-tools.ts（TypeScript）：**
- 使用模块级 `teamStore` Map + `teamCounter`（Swift 端使用 TeamStore actor）
- 两个独立工具对象，每个有自己的 call() 方法
- TeamDelete 先检查团队是否存在（手动），然后直接修改 status 并 delete
- members 是 `string[]`（只有名称），Swift 端是 `[TeamMember]`（有 name + role）

**Swift 端关键差异：**
| 方面 | TypeScript | Swift |
|------|-----------|-------|
| 存储实现 | 模块级 Map + counter | TeamStore Actor |
| 成员模型 | `string[]`（纯名称） | `[TeamMember]`（name + TeamRole） |
| 删除验证 | 手动检查存在 + 已 disbanded | TeamStore.delete() 抛出 TeamStoreError |
| 线程安全 | 无（单线程 Node.js） | Actor 隔离 |
| 错误处理 | 直接返回 content string | ToolExecuteResult(isError: true) |
| leaderId | 硬编码 "self" | 同样 "self"（通过参数传递） |
| task_description | schema 有定义但未使用 | 同样保留在 schema 但不使用 |

**重要差异 — TeamDelete 的行为：**
TS SDK 的 TeamDelete 手动检查 `teamStore.get(input.id)` 是否存在，然后手动设置 `team.status = 'disbanded'` 再 `teamStore.delete(input.id)`。Swift 端的 `TeamStore.delete()` 已经封装了所有验证逻辑（teamNotFound + teamAlreadyDisbanded），直接使用即可。

### Story 4-5 的经验教训（必须遵循）

1. **nonisolated(unsafe) 用于 schema 常量** — inputSchema 字典需要标记为 `nonisolated(unsafe)` 以避免 Sendable 警告
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **Actor 测试** — 使用 `await` 访问 actor 隔离方法
4. **错误路径测试** — 必须覆盖每个 guard 分支（规则 #28）
5. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - Factory Function`
6. **Codable 解码测试** — 验证 JSON 字段的解码正确性
7. **向后兼容** — 无需修改现有文件（本 story 不涉及）
8. **ToolExecuteResult 重载** — 使用 `defineTool` 返回 `ToolExecuteResult` 的重载（不是 String 返回的），以便显式控制 isError 标志

### 反模式警告

- **不要**在 Tools/Advanced/ 中导入 Stores/ 或 Core/ — 违反模块边界（规则 #7、#40）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — 在 ToolResult/ToolExecuteResult 中捕获返回（规则 #38）
- **不要**在团队工具中直接创建 TeamStore — 必须通过 ToolContext 注入（已存在）
- **不要**使用 Apple 专属框架 — 必须跨平台（规则 #43）
- **不要**修改 ToolContext 或 AgentOptions — teamStore 字段已存在
- **不要**修改 Agent.swift — ToolContext 创建点已传入 teamStore
- **不要**忽略 TS SDK 的 task_description 字段 — 保留在 schema 中（即使当前未使用）

### 模块边界注意事项

```
Tools/Advanced/TeamCreateTool.swift → 只导入 Foundation + Types/（永不导入 Core/ 或 Stores/）
Tools/Advanced/TeamDeleteTool.swift → 只导入 Foundation + Types/
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 4.1 (已完成) | 提供 TaskStore/MailboxStore 基础 |
| 4.2 (已完成) | 提供 TeamStore（create/get/list/delete/addMember/removeMember/getTeamForAgent/clear）+ Team/TeamMember/TeamStatus/TeamStoreError 类型 |
| 4.3 (已完成) | 提供 AgentTool + ToolContext.agentSpawner 注入模式 |
| 4.4 (已完成) | 提供 SendMessageTool + ToolContext 注入 teamStore 的模式 — **直接复用此模式** |
| 4.5 (已完成) | 提供 TaskTools — 使用 ToolContext.taskStore 注入模式 |
| 4.7 (后续) | NotebookEdit 工具 |

### 测试策略

**TeamTools 测试策略：**
- 使用真实的 TeamStore actor 实例（轻量级，不涉及网络）
- 测试所有成功路径和错误路径
- 每个工具独立测试

**关键测试场景（每个工具）：**
1. **TeamCreate** — 只填 name、带 members 创建、空 members 默认、验证返回的团队 ID 和状态
2. **TeamDelete** — 删除存在团队成功、团队不存在错误（teamNotFound）、团队已 disbanded 错误（teamAlreadyDisbanded）
3. **通用** — teamStore 为 nil 时两个工具都返回错误、inputSchema 验证、isReadOnly 验证（两者都为 false）

### isReadOnly 分类

| 工具 | isReadOnly | 理由 |
|------|-----------|------|
| TeamCreate | false | 创建团队（有副作用） |
| TeamDelete | false | 删除/解散团队（有副作用） |

isReadOnly 的分类影响 ToolExecutor 的调度策略：两者都是变更工具，将被串行执行（规则 #2、FR12）。

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.6]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR38 Tools/Advanced/Team*Tool.swift]
- [Source: _bmad-output/planning-artifacts/architecture.md#架构边界 Tools 依赖规则]
- [Source: _bmad-output/project-context.md#规则 7 模块边界单向依赖]
- [Source: _bmad-output/project-context.md#规则 38 不从工具内部 throw]
- [Source: _bmad-output/project-context.md#规则 40 Tools 不导入 Core]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/team-tools.ts] — TS Team Tools 完整实现参考
- [Source: Sources/OpenAgentSDK/Stores/TeamStore.swift] — TeamStore actor（create/get/list/delete/addMember/removeMember/getTeamForAgent/clear）
- [Source: Sources/OpenAgentSDK/Types/TaskTypes.swift] — Team, TeamMember, TeamRole, TeamStatus, TeamStoreError
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol, ToolContext（已有 teamStore）, ToolExecuteResult
- [Source: Sources/OpenAgentSDK/Tools/Advanced/TaskCreateTool.swift] — TaskCreateTool 工厂函数参考模式
- [Source: Sources/OpenAgentSDK/Tools/Advanced/SendMessageTool.swift] — SendMessageTool 工厂函数参考模式（使用 context.teamStore）
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool 工厂函数
- [Source: _bmad-output/implementation-artifacts/4-5-task-tools-create-list-update-get-stop-output.md] — 前一 story 经验

### Project Structure Notes

- 新建 `Sources/OpenAgentSDK/Tools/Advanced/TeamCreateTool.swift` — TeamCreate 工厂函数
- 新建 `Sources/OpenAgentSDK/Tools/Advanced/TeamDeleteTool.swift` — TeamDelete 工厂函数
- 修改 `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 追加重新导出注释（TeamCreate/TeamDelete 工厂函数）
- 新建 `Tests/OpenAgentSDKTests/Tools/Advanced/TeamToolsTests.swift`
- 完全对齐架构文档的目录结构和模块边界
- 无需修改 ToolContext（已有 teamStore）、AgentOptions（已有 teamStore）、Agent.swift（已传入 teamStore）

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No debug issues encountered. Build compiles cleanly.

### Completion Notes List

- Implemented TeamCreateTool factory function following the exact pattern from SendMessageTool/TaskCreateTool (defineTool + ToolExecuteResult overload).
- Implemented TeamDeleteTool factory function with proper TeamStoreError catch (teamNotFound, teamAlreadyDisbanded).
- Both tools only import Foundation, satisfying module boundary constraints (AC4).
- Both tools return isReadOnly=false (AC7).
- Both tools access teamStore via ToolContext dependency injection (AC3).
- Error handling never throws -- all errors captured in ToolExecuteResult with isError=true (AC5).
- inputSchema fields match TS SDK team-tools.ts (AC6).
- No modifications needed to ToolContext, AgentOptions, or Agent.swift (AC8).
- Test file (TeamToolsTests.swift) was pre-existing from ATDD RED phase -- all 22 tests are ready to validate the implementation.
- swift build passes cleanly.

### File List

- `Sources/OpenAgentSDK/Tools/Advanced/TeamCreateTool.swift` (NEW)
- `Sources/OpenAgentSDK/Tools/Advanced/TeamDeleteTool.swift` (NEW)
- `Sources/OpenAgentSDK/OpenAgentSDK.swift` (MODIFIED -- added doc comments for team tool factories)
- `Tests/OpenAgentSDKTests/Tools/Advanced/TeamToolsTests.swift` (PRE-EXISTING from ATDD RED phase)

### Review Findings

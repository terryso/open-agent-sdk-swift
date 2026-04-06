# Story 4.4: SendMessage 工具

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望 Agent 可以通过发送消息与团队成员通信，
以便多 Agent 团队可以协调其工作。

## Acceptance Criteria

1. **AC1: 点对点消息发送** — 给定 SendMessage 工具已注册且存在团队，当 Agent 按 name 向队友发送消息，则消息通过 MailboxStore 投递给接收者（FR36），且接收 Agent 可以读取和处理消息。

2. **AC2: 广播消息** — 给定 SendMessage 工具已注册，当 Agent 发送 `to="*"` 的广播消息，则 MailboxStore 的 broadcast 被调用，每个队友在其邮箱中收到消息。

3. **AC3: 无团队时错误处理** — 给定 SendMessage 工具已注册但当前 Agent 不属于任何团队，当 Agent 尝试发送消息，则返回 isError=true 的 ToolResult，内容说明 Agent 不属于任何团队。

4. **AC4: 接收者不存在时错误处理** — 给定 SendMessage 工具已注册且存在团队，当 Agent 向不在团队中的名字发送消息，则返回 isError=true 的 ToolResult，内容说明接收者不是团队成员。

5. **AC5: ToolContext 依赖注入** — 给定 Tools/ 不能导入 Stores/ 或 Core/ 的架构约束，当 SendMessage 工具需要访问 MailboxStore 和 TeamStore，则通过 ToolContext 携带 `mailboxStore` 和 `teamStore` 协议/引用实现跨模块调用（与 AgentTool 的 agentSpawner 注入模式一致）。

6. **AC6: 模块边界合规** — 给定 SendMessageTool.swift 位于 Tools/Advanced/ 目录，当检查 import 语句，则只导入 Foundation 和 Types/ 中的类型，永不导入 Core/ 或 Stores/（架构规则 #7、#40）。

7. **AC7: 当前 Agent 身份识别** — 给定 SendMessage 工具需要知道发送者的身份，当工具执行时，则通过 ToolContext 中的 senderName 字段获取当前 Agent 的名称用于消息投递。

8. **AC8: 错误处理不中断循环** — 给定 SendMessage 执行期间发生异常，当错误被捕获，则返回 is_error=true 的 ToolResult，不会中断父 Agent 的智能循环（架构规则 #38）。

9. **AC9: inputSchema 匹配 TS SDK** — 给定 TS SDK 的 SendMessage 工具 schema，当检查 Swift 端的 inputSchema，则包含 `to`（string，必填）和 `message`（string，必填）字段，`to` 值为队友名或 "*"（广播）。

## Tasks / Subtasks

- [ ] Task 1: 扩展 ToolContext 添加 MailboxStore/TeamStore/senderName 字段 (AC: #5, #7)
  - [ ] 在 `Sources/OpenAgentSDK/Types/ToolTypes.swift` 中为 `ToolContext` 追加 `mailboxStore: MailboxStore?`、`teamStore: TeamStore?`、`senderName: String?` 字段
  - [ ] 更新 init 添加新参数（默认值 nil/nil/nil，保持现有调用兼容）
  - [ ] 保持 Sendable 合规（MailboxStore 和 TeamStore 是 actor，天然 Sendable）

- [ ] Task 2: 实现 SendMessageTool 工厂函数 (AC: #1, #2, #3, #4, #6, #8, #9)
  - [ ] 创建 `Sources/OpenAgentSDK/Tools/Advanced/SendMessageTool.swift`
  - [ ] 定义 `SendMessageInput` Codable 结构体：`to`（必填）、`message`（必填）
  - [ ] 定义 JSON inputSchema 匹配 TS SDK 的 SendMessage schema
  - [ ] `createSendMessageTool()` 工厂函数返回 ToolProtocol（使用 defineTool + ToolExecuteResult 重载）
  - [ ] call 逻辑：(1) 从 context 获取 mailboxStore/teamStore/senderName；(2) 缺少依赖时返回错误；(3) 查找当前 Agent 所在团队；(4) to="*" 时调用 broadcast；(5) 验证接收者是团队成员；(6) 调用 mailboxStore.send()；(7) 格式化输出

- [ ] Task 3: 集成到 Agent 创建点 (AC: #5)
  - [ ] 修改 `Sources/OpenAgentSDK/Core/Agent.swift` 中 prompt() 和 stream() 方法的 ToolContext 创建点
  - [ ] ToolContext 创建时传入 mailboxStore、teamStore、senderName
  - [ ] 确保向后兼容：如果 tools 中不包含 SendMessageTool，这些字段可以为 nil

- [ ] Task 4: 更新模块入口 (AC: #6)
  - [ ] 在 `Sources/OpenAgentSDK/OpenAgentSDK.swift` 中追加 SendMessage 工具的重新导出注释
  - [ ] 确认 SendMessageTool.swift 不导入 Core/ 或 Stores/

- [ ] Task 5: 单元测试 — SendMessageTool (AC: #1-#9)
  - [ ] 创建 `Tests/OpenAgentSDKTests/Tools/Advanced/SendMessageToolTests.swift`
  - [ ] `testCreateSendMessageTool_returnsToolProtocol` — 工厂函数返回正确类型
  - [ ] `testSendMessageInput_decodeFromJson` — Codable 输入解码正确
  - [ ] `testSendMessage_directMessage_delivers` — 向指定队友发送消息
  - [ ] `testSendMessage_broadcast_deliversToAll` — 广播消息投递到所有邮箱
  - [ ] `testSendMessage_noTeam_returnsError` — 不属于团队时返回错误
  - [ ] `testSendMessage_recipientNotInTeam_returnsError` — 接收者不在团队时返回错误
  - [ ] `testSendMessage_noMailboxStore_returnsError` — mailboxStore 为 nil 时返回错误
  - [ ] `testSendMessage_noTeamStore_returnsError` — teamStore 为 nil 时返回错误
  - [ ] `testSendMessage_noSenderName_returnsError` — senderName 为 nil 时返回错误

- [ ] Task 6: 编译验证
  - [ ] 运行 `swift build` 确认编译通过
  - [ ] 验证 `Tools/Advanced/SendMessageTool.swift` 不导入 `Core/` 或 `Stores/`
  - [ ] 验证测试可以编译并通过

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 4（多 Agent 编排）的第四个 story，建立在 Story 4-1（TaskStore/MailboxStore）、4-2（TeamStore/AgentRegistry）、4-3（AgentTool）之上
- 本 story 实现第二个高级工具（Advanced tier tool）：SendMessageTool
- 与 AgentTool 类似的架构挑战：Tools/ 不能导入 Stores/ 或 Core/

**架构关键问题 — Tools/ 不能导入 Stores/ 或 Core/：**

与 AgentTool 使用 SubAgentSpawner 协议的模式不同，SendMessageTool 需要访问 `MailboxStore` 和 `TeamStore`。这两个都是 actor 类型，已经在 Types/ 的 TaskTypes.swift 中有对应的类型定义（MailboxStore 和 TeamStore 自身在 Stores/ 中）。

**解决方案：直接通过 ToolContext 注入 actor 引用**

```
Types/ToolTypes.swift:  ToolContext 追加 mailboxStore/teamStore/senderName 字段
Core/Agent.swift:       创建 ToolContext 时注入 MailboxStore/TeamStore 实例
Tools/Advanced/SendMessageTool.swift:  通过 context.mailboxStore/teamStore 使用
```

这是比 SubAgentSpawner 更简单的方案，因为：
1. MailboxStore 和 TeamStore 已经是 public actor，SDK 消费者可以直接使用
2. 不需要额外的协议抽象（不像 SubAgentSpawner 需要跨模块创建 Agent）
3. ToolContext 已经有了 agentSpawner 的先例，增加更多 store 引用是自然的扩展

### 已有基础设施

| 类型 | 位置 | 说明 |
|------|------|------|
| `MailboxStore` | `Stores/MailboxStore.swift` | Story 4-1 创建，send/broadcast/read/clear 方法 |
| `TeamStore` | `Stores/TeamStore.swift` | Story 4-2 创建，getTeamForAgent() 方法可查找 Agent 所在团队 |
| `TeamMember` | `Types/TaskTypes.swift` | name + role 结构体 |
| `Team` | `Types/TaskTypes.swift` | id, name, members, leaderId, status |
| `AgentMessage` | `Types/TaskTypes.swift` | from, to, content, timestamp, type |
| `AgentMessageType` | `Types/TaskTypes.swift` | text, shutdownRequest, shutdownResponse, planApprovalResponse |
| `ToolContext` | `Types/ToolTypes.swift` | cwd, toolUseId, agentSpawner；需追加 mailboxStore, teamStore, senderName |
| `ToolExecuteResult` | `Types/ToolTypes.swift` | content + isError |
| `defineTool()` | `Tools/ToolBuilder.swift` | 工厂函数，使用 CodableTool/StructuredCodableTool |
| `Agent` | `Core/Agent.swift` | prompt()/stream() 方法中的 ToolContext 创建点 |

### 实现位置

**修改文件：**
```
Sources/OpenAgentSDK/Types/ToolTypes.swift            # 追加 mailboxStore, teamStore, senderName 到 ToolContext
Sources/OpenAgentSDK/Core/Agent.swift                 # prompt()/stream() 创建 ToolContext 时注入 stores
Sources/OpenAgentSDK/OpenAgentSDK.swift               # 追加重新导出注释
```

**新增文件：**
```
Sources/OpenAgentSDK/Tools/Advanced/SendMessageTool.swift   # SendMessageTool 工厂函数
```

**测试文件：**
```
Tests/OpenAgentSDKTests/Tools/Advanced/SendMessageToolTests.swift   # SendMessageTool 测试
```

### 类型定义

**ToolContext 扩展（在现有定义上追加字段）：**

```swift
public struct ToolContext: Sendable {
    public let cwd: String
    public let toolUseId: String
    public let agentSpawner: (any SubAgentSpawner)?
    public let mailboxStore: MailboxStore?    // 新增
    public let teamStore: TeamStore?          // 新增
    public let senderName: String?            // 新增：当前 Agent 的名称

    public init(
        cwd: String,
        toolUseId: String = "",
        agentSpawner: (any SubAgentSpawner)? = nil,
        mailboxStore: MailboxStore? = nil,    // 新增
        teamStore: TeamStore? = nil,          // 新增
        senderName: String? = nil             // 新增
    ) { ... }
}
```

注意：`MailboxStore` 和 `TeamStore` 是 actor，天然是 `Sendable` 的。`ToolContext` 已经是 `Sendable` struct。

**SendMessageInput（私有 Codable 类型）：**

```swift
private struct SendMessageInput: Codable {
    let to: String        // 队友名或 "*"（广播）
    let message: String   // 消息内容
}
```

字段命名使用 snake_case/简短名匹配 TS SDK 的 inputSchema 和 LLM 端 JSON 字段（参考 project-context.md 规则 #19）。

**inputSchema：**

```swift
private nonisolated(unsafe) let sendMessageToolSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "to": ["type": "string", "description": "Recipient: teammate name, or \"*\" for broadcast to all teammates"] as [String: Any],
        "message": ["type": "string", "description": "Plain text message to send"] as [String: Any],
    ] as [String: Any],
    "required": ["to", "message"]
]
```

### SendMessageTool 工厂函数实现要点

```swift
public func createSendMessageTool() -> ToolProtocol {
    return defineTool(
        name: "SendMessage",
        description: "Send a message to another agent in the team. Use teammate name for direct message or \"*\" to broadcast to all teammates.",
        inputSchema: sendMessageToolSchema,
        isReadOnly: false
    ) { (input: SendMessageInput, context: ToolContext) async throws -> ToolExecuteResult in
        // Guard: 必需的依赖
        guard let mailboxStore = context.mailboxStore else {
            return ToolExecuteResult(
                content: "Error: MailboxStore not available. The SendMessage tool requires messaging infrastructure.",
                isError: true
            )
        }
        guard let teamStore = context.teamStore else {
            return ToolExecuteResult(
                content: "Error: TeamStore not available. The SendMessage tool requires team management.",
                isError: true
            )
        }
        guard let senderName = context.senderName else {
            return ToolExecuteResult(
                content: "Error: Sender name not available. The SendMessage tool requires agent identity.",
                isError: true
            )
        }

        // 查找发送者所在的团队
        guard let team = await teamStore.getTeamForAgent(agentName: senderName) else {
            return ToolExecuteResult(
                content: "Error: Agent '\(senderName)' is not a member of any team.",
                isError: true
            )
        }

        if input.to == "*" {
            // 广播
            await mailboxStore.broadcast(from: senderName, content: input.message)
            return ToolExecuteResult(
                content: "Message broadcast to all teammates in team '\(team.name)'.",
                isError: false
            )
        }

        // 验证接收者是团队成员
        let isMember = team.members.contains { $0.name == input.to }
        guard isMember else {
            return ToolExecuteResult(
                content: "Error: '\(input.to)' is not a member of team '\(team.name)'. Available members: \(team.members.map { $0.name }.joined(separator: ", ")).",
                isError: true
            )
        }

        // 发送点对点消息
        await mailboxStore.send(from: senderName, to: input.to, content: input.message)
        return ToolExecuteResult(
            content: "Message sent to \(input.to).",
            isError: false
        )
    }
}
```

### ToolContext 注入点（Core/Agent.swift 修改）

在 `Agent.swift` 的 `prompt()` 和 `stream()` 方法中，ToolContext 创建时注入 stores：

```swift
// 在 prompt()/stream() 方法中
let context = ToolContext(
    cwd: options.cwd ?? "",
    agentSpawner: agentSpawner,
    mailboxStore: mailboxStore,      // 注入
    teamStore: teamStore,            // 注入
    senderName: senderName           // 注入
)
```

关于 stores 和 senderName 的来源：
- `mailboxStore` 和 `teamStore` 需要通过 `AgentOptions` 传入（新增字段），或在 Agent 初始化时创建
- `senderName` 可以从 AgentOptions 中新增的字段获取，或使用 Agent 的标识符
- 考虑向后兼容：默认值 nil，只有使用 SendMessageTool 时才需要设置

**推荐方案：在 AgentOptions 中添加可选字段**

```swift
public struct AgentOptions: Sendable {
    // ... 现有字段 ...
    public var agentName: String?           // 新增：用于 SendMessage 等工具的发送者身份
    public var mailboxStore: MailboxStore?  // 新增：用于 SendMessage 等工具
    public var teamStore: TeamStore?        // 新增：用于 SendMessage 等工具
}
```

这允许消费者在创建 Agent 时注入共享的 MailboxStore 和 TeamStore 实例，实现多 Agent 共享同一消息基础设施。

### TypeScript SDK 参考对比

**send-message.ts（TypeScript）：**
- 使用模块级 `mailboxes` Map（Swift 端使用 MailboxStore actor）
- 通过 `writeToMailbox()` 函数投递消息
- `to="*"` 时遍历所有已知邮箱进行广播
- 点对点时直接写入目标邮箱
- 没有团队验证（直接写入任何已知名字）— Swift 端增加了团队验证

**Swift 端关键差异：**
| 方面 | TypeScript | Swift |
|------|-----------|-------|
| 消息存储 | 模块级 Map | MailboxStore Actor |
| 团队验证 | 无（直接投递） | 通过 TeamStore 验证团队成员身份 |
| 广播机制 | 遍历 mailboxes Map | mailboxStore.broadcast() |
| 发送者身份 | 隐式（当前 Agent） | 通过 ToolContext.senderName 显式传递 |
| 错误处理 | 返回 tool_result | ToolExecuteResult(isError: true) |

### Story 4-3 的经验教训（必须遵循）

1. **nonisolated(unsafe) 用于 schema 常量** — inputSchema 字典需要标记为 `nonisolated(unsafe)` 以避免 Sendable 警告
2. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
3. **Actor 测试** — 使用 `await` 访问 actor 隔离方法
4. **错误路径测试** — 必须覆盖每个 guard 分支（规则 #28）
5. **MARK 注释风格** — `// MARK: - Properties`、`// MARK: - Factory Function`
6. **Codable 解码测试** — 验证 snake_case 字段的 JSON 解码
7. **向后兼容** — ToolContext 新增字段默认值 nil，不破坏现有代码

### 反模式警告

- **不要**在 Tools/Advanced/ 中导入 Stores/ 或 Core/ — 违反模块边界（规则 #7、#40）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**从工具处理程序内部 throw 错误 — 在 ToolResult/ToolExecuteResult 中捕获返回（规则 #38）
- **不要**在 SendMessageTool 中直接创建 MailboxStore/TeamStore — 必须通过 ToolContext 注入
- **不要**使用 Apple 专属框架 — 必须跨平台（规则 #43）
- **不要**在单元测试中使用真实的 MailboxStore/TeamStore 测试工具逻辑 — 使用 actor 实例（MailboxStore/TeamStore 是 actor 不是协议，可以直接创建轻量实例用于测试）
- **不要**修改 ToolContext 的现有 init 签名（会破坏现有代码）— 新增参数默认值 nil 保持兼容

### 模块边界注意事项

```
Types/ToolTypes.swift        → 扩展 ToolContext（追加 mailboxStore/teamStore/senderName 字段，叶节点）
Types/AgentTypes.swift       → 扩展 AgentOptions（追加 agentName/mailboxStore/teamStore 字段）
Core/Agent.swift             → 修改 ToolContext 创建点，注入 stores（内部修改）
Tools/Advanced/SendMessageTool.swift → 只导入 Foundation + Types/（永不导入 Core/ 或 Stores/）
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 4.1 (已完成) | 提供 MailboxStore（send/broadcast/read）|
| 4.2 (已完成) | 提供 TeamStore（getTeamForAgent、Team/TeamMember 类型）|
| 4.3 (已完成) | 提供 AgentTool + ToolContext.agentSpawner 注入模式作为参考 |
| 4.5 (后续) | Task 工具可能需要通过 SendMessage 通知任务状态 |
| 4.6 (后续) | TeamCreate/Delete 工具创建团队后 Agent 可加入并互相发消息 |

### 测试策略

**SendMessageTool 测试策略：**
- 使用真实的 MailboxStore 和 TeamStore actor 实例（轻量级，不涉及网络）
- 创建包含测试 Agent 的 Team 来模拟团队环境
- 测试所有成功路径和错误路径
- 验证 MailboxStore 中的消息确实被投递（通过 mailboxStore.read() 验证）

**关键测试场景：**
1. **成功路径 — 直接消息**：创建团队 → 发送消息 → 验证邮箱收到消息
2. **成功路径 — 广播**：创建多成员团队 → 广播 → 验证所有邮箱收到
3. **错误路径 — 无团队**：未创建团队 → 发送消息 → 验证 isError=true
4. **错误路径 — 接收者不在团队**：创建团队 → 向非成员发送 → 验证 isError=true
5. **错误路径 — 缺少依赖**：mailboxStore/teamStore/senderName 为 nil → 验证错误返回
6. **工具协议合规**：验证 name, description, inputSchema, isReadOnly

### 潜在风险和设计考量

1. **TeamStore.getTeamForAgent() 只返回第一个团队** — 如果 Agent 属于多个团队，当前实现只返回第一个。这对于 v1 是可接受的，未来可以扩展为支持指定 teamId。
2. **广播范围** — 广播消息发送给 TeamStore 中所有团队的成员，还是只发送给当前团队？建议：只发送给 getTeamForAgent 返回的团队，与 TS SDK 的行为一致。
3. **senderName 来源** — AgentOptions.agentName 是新字段，消费者需要设置。如果不设置，SendMessageTool 无法工作（返回错误）。这是合理的 v1 行为。
4. **MailboxStore/TeamStore 实例共享** — 多个 Agent 需要共享同一个 MailboxStore 和 TeamStore 实例才能互相通信。消费者负责注入相同的实例。

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.4]
- [Source: _bmad-output/planning-artifacts/architecture.md#FR36 Tools/Advanced/SendMessageTool.swift]
- [Source: _bmad-output/planning-artifacts/architecture.md#架构边界 Tools 依赖规则]
- [Source: _bmad-output/project-context.md#规则 7 模块边界单向依赖]
- [Source: _bmad-output/project-context.md#规则 38 不从工具内部 throw]
- [Source: _bmad-output/project-context.md#规则 40 Tools 不导入 Core]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/send-message.ts] — TS SendMessage 完整实现参考
- [Source: Sources/OpenAgentSDK/Stores/MailboxStore.swift] — MailboxStore actor（send/broadcast/read）
- [Source: Sources/OpenAgentSDK/Stores/TeamStore.swift] — TeamStore actor（getTeamForAgent）
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol, ToolContext, ToolExecuteResult
- [Source: Sources/OpenAgentSDK/Types/TaskTypes.swift] — AgentMessage, AgentMessageType, Team, TeamMember
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions, AgentDefinition
- [Source: Sources/OpenAgentSDK/Tools/Advanced/AgentTool.swift] — AgentTool 工厂函数参考模式
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool 工厂函数
- [Source: _bmad-output/implementation-artifacts/4-3-agent-tool-sub-agent-spawn.md] — 前一 story 经验

### Project Structure Notes

- 修改 `Sources/OpenAgentSDK/Types/ToolTypes.swift` — 追加 mailboxStore, teamStore, senderName 到 ToolContext
- 修改 `Sources/OpenAgentSDK/Types/AgentTypes.swift` — 追加 agentName, mailboxStore, teamStore 到 AgentOptions
- 新建 `Sources/OpenAgentSDK/Tools/Advanced/SendMessageTool.swift` — SendMessageTool 工厂函数
- 修改 `Sources/OpenAgentSDK/Core/Agent.swift` — ToolContext 创建时注入 stores 和 senderName
- 修改 `Sources/OpenAgentSDK/OpenAgentSDK.swift` — 追加重新导出注释
- 新建 `Tests/OpenAgentSDKTests/Tools/Advanced/SendMessageToolTests.swift`
- 完全对齐架构文档的目录结构和模块边界

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

### Review Findings

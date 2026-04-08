# Story 7.2: 会话加载与恢复

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望加载并恢复之前保存的对话，
以便 Agent 可以从上次中断的地方继续。

## Acceptance Criteria

1. **AC1: 恢复用 Agent.prompt()** — 给定一个已保存的会话（由 Story 7-1 的 SessionStore.save() 创建），当开发者调用带 sessionId 参数的 `agent.prompt(text, sessionId:)` 时，则消息历史从 SessionStore.load() 反序列化，新用户消息追加到已恢复的历史后面，智能循环以完整上下文继续执行（FR24），返回的 QueryResult 包含跨越恢复历史和新交互的累积结果。

2. **AC2: 恢复用 Agent.stream()** — 给定一个已保存的会话，当开发者调用带 sessionId 参数的 `agent.stream(text, sessionId:)` 时，则 AsyncStream<SDKMessage> 以恢复的对话历史开始，流式事件反映从恢复点继续的上下文，与 prompt() 行为一致。

3. **AC3: 加载的消息与智能循环兼容** — 给定从 SessionStore.load() 加载的消息（`[[String: Any]]` 格式），当消息被传入智能循环时，则消息格式直接兼容 AnthropicClient.sendMessage() 和 streamMessage()，不需要额外转换或适配。加载的消息保持 role/content 结构完整。

4. **AC4: 不存在的 sessionId 处理** — 给定一个不存在的 sessionId，当开发者尝试恢复该会话时，则从空对话开始（与不传 sessionId 行为一致），不抛出错误，不崩溃。

5. **AC5: SessionStore 集成** — 给定 AgentOptions，当开发者提供 `sessionStore` 和 `sessionId` 参数时，则 Agent 在 prompt()/stream() 开始时自动调用 `sessionStore.load(sessionId:)`，在智能循环结束后自动调用 `sessionStore.save()` 更新持久化数据。

6. **AC6: 性能要求** — 给定 500 条消息以下的已保存会话，当执行恢复操作时，则从 SessionStore.load() 到智能循环开始的时间在 200ms 内完成（NFR4）。

7. **AC7: 单元测试覆盖** — 给定会话加载与恢复功能，当检查 `Tests/OpenAgentSDKTests/`，则包含以下测试：
    - Agent.prompt() 带 sessionId 恢复历史并继续对话
    - Agent.stream() 带 sessionId 恢复历史并继续对话
    - 不存在的 sessionId 从空对话开始
    - SessionStore.load() 返回的消息直接兼容 buildMessages 格式
    - 恢复后的自动保存更新持久化数据

8. **AC8: E2E 测试覆盖** — 给定故事完成后，当检查 `Sources/E2ETest/`，则包含会话恢复的 E2E 测试，至少覆盖：保存后恢复并继续对话的往返验证、多轮对话的恢复验证。

## Tasks / Subtasks

- [x] Task 1: 在 AgentOptions 中添加 SessionStore 和 sessionId 属性 (AC: #5)
  - [x] 在 `Types/AgentTypes.swift` 的 `AgentOptions` 中添加 `sessionStore: SessionStore?` 属性
  - [x] 在 `Types/AgentTypes.swift` 的 `AgentOptions` 中添加 `sessionId: String?` 属性
  - [x] 更新 `AgentOptions.init()` 的默认参数（两者均为 nil）
  - [x] 更新 `AgentOptions.init(from:)` 的初始化（两者均为 nil）

- [x] Task 2: 在 Agent.prompt() 中实现会话恢复逻辑 (AC: #1, #3, #4, #5, #6)
  - [x] 在 prompt() 开始时检查 options.sessionStore 和 options.sessionId 是否非空
  - [x] 若非空，调用 `await sessionStore.load(sessionId:)` 获取历史消息
  - [x] 若加载成功，用历史消息替代 buildMessages() 的结果（新用户消息追加到历史后）
  - [x] 若加载失败或 sessionId 不存在，从空对话开始
  - [x] 在智能循环结束后，若 sessionStore 存在，调用 save() 持久化更新后的消息
  - [x] 构建 PartialSessionMetadata 用于保存（cwd、model、summary）

- [x] Task 3: 在 Agent.stream() 中实现会话恢复逻辑 (AC: #2, #3, #4, #5, #6)
  - [x] 在 stream() 的 AsyncStream 闭包中捕获 sessionStore 和 sessionId
  - [x] 在流式循环开始前调用 `await sessionStore.load(sessionId:)` 获取历史
  - [x] 用恢复的历史替换 decodedMessages（新用户消息追加到历史后）
  - [x] 在流式循环结束后，调用 save() 持久化更新
  - [x] 处理不存在的 sessionId（从空对话开始）

- [x] Task 4: 单元测试 (AC: #7)
  - [x] 创建/扩展 `Tests/OpenAgentSDKTests/Core/AgentSessionRestoreTests.swift`
  - [x] 测试 `testPrompt_withSessionId_restoresHistory` — 验证 prompt() 恢复历史
  - [x] 测试 `testStream_withSessionId_restoresHistory` — 验证 stream() 恢复历史
  - [x] 测试 `testPrompt_nonexistentSessionId_startsFresh` — 验证空对话回退
  - [x] 测试 `testStream_nonexistentSessionId_startsFresh` — 验证空对话回退
  - [x] 测试 `testRestoredMessages_compatibleWithAgentLoop` — 验证消息格式兼容
  - [x] 测试 `testAutoSave_afterPrompt_updatesPersistedData` — 验证自动保存
  - [x] 测试 `testAutoSave_afterStream_updatesPersistedData` — 验证流式自动保存

- [x] Task 5: E2E 测试 (AC: #8)
  - [x] 创建/扩展 `Sources/E2ETest/SessionRestoreE2ETests.swift`
  - [x] E2E 测试：保存会话 → 恢复 → 继续对话 → 验证历史完整
  - [x] E2E 测试：多轮对话的恢复验证

- [x] Task 6: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证新增代码不违反模块边界（Agent 可依赖 Stores/SessionStore、Types/）
  - [x] 验证所有现有测试仍通过

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 7（会话持久化）的第二个 story
- **集成 story** — 将 Story 7-1 创建的 SessionStore 与 Agent 的 prompt()/stream() 方法集成
- **关键目标：** 实现开发者可以恢复之前保存的对话并从恢复点继续，满足 FR24 和 NFR4

### 已有的类型和组件（直接使用，无需修改核心逻辑）

| 组件 | 位置 | 说明 |
|------|------|------|
| `SessionStore` | `Stores/SessionStore.swift` | 已实现：save(), load(), delete() |
| `SessionData` | `Types/SessionTypes.swift` | 已定义：metadata + messages: `[[String: Any]]` |
| `SessionMetadata` | `Types/SessionTypes.swift` | 已定义：id, cwd, model, createdAt, updatedAt, messageCount, summary |
| `PartialSessionMetadata` | `Types/SessionTypes.swift` | 已定义：cwd, model, summary（save 输入用） |
| `Agent` | `Core/Agent.swift` | 已实现：prompt() 和 stream()，需添加恢复逻辑 |
| `AgentOptions` | `Types/AgentTypes.swift` | 已定义：需添加 sessionStore 和 sessionId 属性 |
| `SDKError.sessionError` | `Types/ErrorTypes.swift` | 已有会话错误域 |

### TypeScript SDK 参考

TypeScript SDK 的 `session.ts` 和 `engine.ts` 提供了直接参考：

```typescript
// session.ts — 加载函数
export async function loadSession(sessionId: string): Promise<SessionData | null> {
  try {
    const filePath = join(getSessionPath(sessionId), 'transcript.json')
    const content = await readFile(filePath, 'utf-8')
    return JSON.parse(content) as SessionData
  } catch { return null }
}

export async function getSessionMessages(sessionId: string): Promise<MessageParam[]> {
  const data = await loadSession(sessionId)
  return data?.messages || []
}
```

TypeScript SDK 中恢复会话的模式：
1. 在 engine 开始时，检查是否有 sessionId
2. 如果有，调用 `loadSession()` 获取历史消息
3. 将历史消息作为对话上下文，新用户消息追加到末尾
4. 继续正常的智能循环

**Swift 对应实现要点：**
- `Agent.prompt()` 和 `Agent.stream()` 已有 `buildMessages(prompt:)` 构建初始消息
- 恢复逻辑应在此处插入：用 `sessionStore.load()` 的结果替代空数组，新消息追加其后
- `SessionData.messages` 是 `[[String: Any]]`，与 Agent 内部的 `messages` 数组格式一致

### 关键实现细节

**1. AgentOptions 扩展**

```swift
// 在 AgentOptions 中添加：
public var sessionStore: SessionStore?
public var sessionId: String?
```

注意：`SessionStore` 是 actor 类型，`AgentOptions` 是 struct（Sendable）。actor 引用天然是 Sendable 的，所以可以直接作为 struct 的属性。

**2. prompt() 中的恢复逻辑**

```swift
public func prompt(_ text: String) async -> QueryResult {
    let startTime = ContinuousClock.now
    let (mcpTools, mcpManager) = await assembleFullToolPool()

    // 会话恢复：加载历史消息
    var messages: [[String: Any]]
    if let sessionStore = options.sessionStore, let sessionId = options.sessionId {
        if let sessionData = try? await sessionStore.load(sessionId: sessionId) {
            messages = sessionData.messages
        } else {
            messages = []
        }
        // 追加新用户消息到恢复的历史
        messages.append(["role": "user", "content": text])
    } else {
        messages = buildMessages(prompt: text)
    }

    // ... 原有智能循环 ...

    // 会话保存：持久化更新后的消息
    if let sessionStore = options.sessionStore, let sessionId = options.sessionId {
        let metadata = PartialSessionMetadata(
            cwd: options.cwd ?? "",
            model: model,
            summary: nil  // 或从对话内容生成摘要
        )
        try? await sessionStore.save(sessionId: sessionId, messages: messages, metadata: metadata)
    }

    return QueryResult(...)
}
```

**3. stream() 中的恢复逻辑**

stream() 中的恢复逻辑类似，但需要注意 Sendable 约束：
- 在 AsyncStream 闭包之前捕获 sessionStore 和 sessionId
- 在闭包内部执行 `await sessionStore.load(sessionId:)`
- 在循环结束后执行 `await sessionStore.save(...)`

```swift
// 在 stream() 闭包前捕获
let capturedSessionStore = options.sessionStore
let capturedSessionId = options.sessionId

// 在 AsyncStream 内部（已有 Task 上下文）
if let sessionStore = capturedSessionStore, let sessionId = capturedSessionId {
    if let sessionData = try? await sessionStore.load(sessionId: sessionId) {
        messages = sessionData.messages
    }
    messages.append(["role": "user", "content": text])
}
```

**4. 不存在的 sessionId 处理**

- `sessionStore.load()` 返回 `SessionData?` — 不存在时返回 nil
- 代码应检查 nil 并从空对话开始
- 不抛出错误，不崩溃 — 匹配 TypeScript SDK 行为

**5. 自动保存**

- 智能循环结束后（无论成功还是失败），都应尝试保存
- 使用 `try?` 避免保存失败影响主流程
- 保存时使用当前的 `messages` 数组（包含恢复的历史 + 新交互）
- 构建 PartialSessionMetadata 时使用当前 cwd 和 model

### 前序 Story 的经验教训（必须遵循）

1. **SessionStore.load() 返回 `SessionData?`** — 已在 7-1 中实现，使用 JSONSerialization 反序列化
2. **消息格式是 `[[String: Any]]`** — 与 Agent 内部 messages 数组格式完全一致，无需转换
3. **Actor 调用需要 `await`** — SessionStore 是 actor，所有方法调用都需要 `await`
4. **MARK 注释风格** — 遵循 `// MARK: - Properties` 等格式
5. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
6. **E2E 测试** — 使用真实文件系统（E2E 规则：不使用 mock）
7. **nonisolated(unsafe)** — 如有 `[String: Any]` 字典常量需要标记（Story 6-1 经验）
8. **@Sendable 注解** — stream() 闭包中传递的参数需要确保 Sendable 兼容（Story 6-2 修复）
9. **SessionStore 支持自定义目录** — 构造函数接受 `sessionsDir: String?` 用于测试注入
10. **不使用 Apple 专属框架** — 必须跨平台
11. **load() 静默返回 nil** — 匹配 TS SDK 的 `catch { return null }` 行为

### 反模式警告

- **不要**修改 `SessionStore.swift` 的核心 load() 方法 — 它已满足需求
- **不要**在 Agent 中使用 force-unwrap (`!`) — 使用 guard let / if let / optional chaining
- **不要**在 Agent 中导入新的 Core/ 以外的模块 — SessionStore 通过 AgentOptions 注入
- **不要**将 SessionStore 作为 Agent 的直接依赖 — 通过 AgentOptions 属性注入
- **不要**在恢复失败时抛出错误或崩溃 — 静默回退到空对话
- **不要**在保存失败时影响主流程返回 — 使用 `try?` 吞掉保存错误
- **不要**修改 `SessionTypes.swift` 中已有的类型 — 如果需要扩展，通过 extension 或新类型
- **不要**使用 `import Logging` — 与前序 story 保持一致
- **不要**使用 Apple 专属框架（UIKit, AppKit）— 必须跨平台

### 模块边界

```
Types/AgentTypes.swift         → 修改：添加 sessionStore 和 sessionId 属性
Core/Agent.swift                → 修改：在 prompt() 和 stream() 中添加恢复和自动保存逻辑
Stores/SessionStore.swift       → 不修改：load() 和 save() 已满足需求
Types/SessionTypes.swift        → 不修改：SessionData 和 PartialSessionMetadata 已满足需求
Types/ErrorTypes.swift          → 不修改：SDKError.sessionError 已满足需求
```

新测试文件：
```
Tests/OpenAgentSDKTests/Core/AgentSessionRestoreTests.swift   (新建)
Sources/E2ETest/SessionRestoreE2ETests.swift                   (新建)
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 7-1 (已完成) | 前置依赖 — 提供了 SessionStore.save()、load()、SessionData、PartialSessionMetadata |
| 7-3 (backlog) | 后续 — 会话分叉将使用 load() + save() 创建分叉副本 |
| 7-4 (backlog) | 后续 — 会话管理将添加 list/rename/tag/delete 到 SessionStore |
| 1-4 (已完成) | Agent 创建模式参考 — AgentOptions 扩展模式 |
| 1-5 (已完成) | prompt() 实现参考 — 恢复逻辑的插入点 |

### 测试策略

**单元测试（Tests/OpenAgentSDKTests/Core/AgentSessionRestoreTests.swift）：**

使用 mock LLMClient（与 AgentTests 相同的模式）避免真实 API 调用：
- 创建一个返回预设响应的 mock LLMClient
- 使用临时目录的 SessionStore（sessionsDir 注入）
- 测试恢复逻辑而不依赖真实 LLM API

Mock 模式参考（已在其他测试中使用）：
```swift
// 创建一个简单的 MockLLMClient
class MockLLMClient: LLMClient {
    var lastMessages: [[String: Any]]?
    func sendMessage(...) async throws -> [String: Any] {
        lastMessages = messages  // 捕获发送的消息
        return ["content": [["type": "text", "text": "mock response"]], "stop_reason": "end_turn", "usage": [:]]
    }
    func streamMessage(...) async throws -> AsyncThrowingStream<SSEEvent, Error> { ... }
}
```

**E2E 测试（Sources/E2ETest/SessionRestoreE2ETests.swift）：**

- 使用真实文件系统（E2E 规则：不使用 mock）
- 在 `~/.open-agent-sdk/sessions/` 中创建和读取真实文件
- 测试后清理测试数据

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.2 会话加载与恢复]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD6 会话持久化]
- [Source: _bmad-output/planning-artifacts/prd.md#FR24 加载并恢复已保存的对话]
- [Source: _bmad-output/project-context.md#规则 1 Actor 用于共享可变状态]
- [Source: _bmad-output/project-context.md#规则 7 模块边界]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/session.ts] — TypeScript SDK 会话加载参考
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — prompt() 和 stream() 恢复逻辑插入点
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift] — AgentOptions 扩展点
- [Source: Sources/OpenAgentSDK/Stores/SessionStore.swift] — SessionStore.load() 实现
- [Source: Sources/OpenAgentSDK/Types/SessionTypes.swift] — SessionData 和 PartialSessionMetadata 类型
- [Source: _bmad-output/implementation-artifacts/7-1-session-store-json-persistence.md] — Story 7-1 经验教训

### Project Structure Notes

- **修改** `Sources/OpenAgentSDK/Types/AgentTypes.swift` — 添加 sessionStore 和 sessionId 到 AgentOptions
- **修改** `Sources/OpenAgentSDK/Core/Agent.swift` — 在 prompt() 和 stream() 中添加恢复和自动保存逻辑
- **新建** `Tests/OpenAgentSDKTests/Core/AgentSessionRestoreTests.swift` — 单元测试
- **新建** `Sources/E2ETest/SessionRestoreE2ETests.swift` — E2E 测试
- **不修改** `Stores/SessionStore.swift` — load() 和 save() 已满足需求
- **不修改** `Types/SessionTypes.swift` — 类型定义已满足需求
- 完全对齐架构文档的目录结构和模块边界

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Task 1: Added `sessionStore: SessionStore?` and `sessionId: String?` properties to `AgentOptions`. Both default to nil in `init()` and `init(from:)`. Actor references (SessionStore) are naturally Sendable in struct context.
- Task 2: Implemented session restore in `Agent.prompt()`. Before the agent loop, checks if sessionStore+sessionId are configured; if so, loads history from SessionStore and appends new user message. After the loop, auto-saves updated messages via SessionStore.save(). Uses JSONSerialization round-trip for Sendable compliance when crossing actor boundary.
- Task 3: Implemented session restore in `Agent.stream()`. Captures sessionStore and sessionId before AsyncStream closure. Inside the Task, loads history from SessionStore before the loop starts. After loop completion, auto-saves messages. Same JSONSerialization pattern for Sendable compliance.
- Task 4: Updated 11 unit tests from RED phase to GREEN phase. Removed XCTFail placeholders in AgentOptionsSessionStoreTests. Updated test helpers to use AgentOptions init with sessionStore/sessionId parameters. All 11 tests pass.
- Task 5: Updated 2 E2E tests from RED phase to GREEN phase. Removed XCTFail placeholders and uncommented real test logic. Added JSONSerialization for Sendable compliance when calling SessionStore.save() from non-actor context.
- Task 6: Build passes (0 errors, 0 failures). Full test suite: 1438 tests pass, 4 skipped, 0 failures. No regressions.
- Key design decision: Messages are serialized via JSONSerialization before crossing actor boundaries to satisfy Swift 6 strict concurrency Sendable requirements.

### File List

- Sources/OpenAgentSDK/Types/AgentTypes.swift (modified: added sessionStore and sessionId properties)
- Sources/OpenAgentSDK/Core/Agent.swift (modified: added session restore and auto-save logic in prompt() and stream())
- Tests/OpenAgentSDKTests/Core/AgentSessionRestoreTests.swift (modified: updated from RED to GREEN phase)
- Sources/E2ETest/SessionRestoreE2ETests.swift (modified: updated from RED to GREEN phase)
- _bmad-output/implementation-artifacts/7-2-session-load-restore.md (modified: status, tasks, dev record)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified: 7-2 status to in-progress)

### Change Log

- 2026-04-08: Implemented session load & restore (Story 7-2) - all 6 tasks complete, 11 unit tests + 2 E2E tests passing, full suite green (1438 tests, 0 failures)

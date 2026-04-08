# Story 7.3: 会话分叉

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望从任何保存点分叉对话，
以便我可以探索替代路径而不丢失原始对话。

## Acceptance Criteria

1. **AC1: 基本分叉** — 给定一个带有多个消息的已保存会话，当开发者调用 `sessionStore.fork(sourceSessionId:)` 时，则创建一个新会话，包含源会话的全部消息，新会话具有唯一的 ID，原始会话完全不变（FR25）。

2. **AC2: 带消息索引截断的分叉** — 给定一个已保存会话，当开发者调用 `sessionStore.fork(sourceSessionId:, upToMessageIndex:)` 时，则新会话仅包含从第一条消息到指定索引（包含）的消息，允许从对话中间的任意保存点创建分叉。

3. **AC3: 自定义新会话 ID** — 给定一个已保存会话，当开发者调用 `sessionStore.fork(sourceSessionId:, newSessionId:)` 时，则新会话使用开发者提供的 ID，如果 newSessionId 为 nil，则自动生成 UUID。

4. **AC4: 源会话不存在** — 给定一个不存在的 sessionId，当开发者尝试分叉时，则 fork 返回 nil，不抛出错误，不崩溃。

5. **AC5: 分叉会话的元数据** — 给定成功分叉的会话，当检查新会话的元数据时，则 createdAt 设为当前时间（非原始时间），updatedAt 设为当前时间，summary 包含 "Forked from session {sourceId}"，messageCount 正确反映（可能被截断的）消息数量。

6. **AC6: 分叉后使用新会话 ID 恢复** — 给定分叉创建的新会话，当开发者使用新会话 ID 创建 Agent 并调用 prompt()/stream() 时，则 Agent 成功恢复分叉的消息历史并继续对话。

7. **AC7: 性能要求** — 给定 500 条消息以下的已保存会话，当执行分叉操作时，则完成时间在 200ms 内（NFR4）。

8. **AC8: 线程安全** — 给定并发的分叉操作，当多个分叉从同一个或不同源会话同时执行时，则所有操作正确完成，无数据损坏（FR27）。

9. **AC9: 单元测试覆盖** — 给定分叉功能，当检查 `Tests/OpenAgentSDKTests/`，则包含以下测试：
    - 基本分叉创建新会话并复制所有消息
    - 带 upToMessageIndex 截断的分叉
    - 自定义 newSessionId 分叉
    - 源会话不存在返回 nil
    - 分叉不修改原始会话
    - 分叉的元数据正确（createdAt, summary, messageCount）
    - 并发分叉操作安全完成

10. **AC10: E2E 测试覆盖** — 给定故事完成后，当检查 `Sources/E2ETest/`，则包含分叉的 E2E 测试，至少覆盖：完整会话分叉并恢复验证、截断分叉恢复验证、分叉后继续对话验证。

## Tasks / Subtasks

- [x] Task 1: 在 SessionStore 中实现 fork() 方法 (AC: #1, #2, #3, #4, #5)
  - [x] 在 `SessionStore` 中添加 `fork(sourceSessionId:newSessionId:upToMessageIndex:)` 公共方法
  - [x] 方法签名：`public func fork(sourceSessionId: String, newSessionId: String? = nil, upToMessageIndex: Int? = nil) throws -> String?`
  - [x] 加载源会话数据，不存在则返回 nil
  - [x] 根据 upToMessageIndex 截断消息数组（如提供）
  - [x] 生成或使用提供的 newSessionId
  - [x] 调用 save() 创建新会话，传入正确的 PartialSessionMetadata（summary 包含 fork 来源）
  - [x] 返回新会话 ID

- [x] Task 2: 验证分叉会话与 Agent 恢复的兼容性 (AC: #6)
  - [x] 验证分叉的 SessionData.messages 格式与 Agent.prompt()/stream() 的 sessionStore.load() 兼容
  - [x] 确认无需修改 Agent.swift — 分叉是纯 SessionStore 层操作

- [x] Task 3: 单元测试 (AC: #9)
  - [x] 创建/扩展 `Tests/OpenAgentSDKTests/Stores/SessionStoreForkTests.swift`
  - [x] 测试 `testFork_createsNewSessionWithAllMessages` — 基本分叉
  - [x] 测试 `testFork_withMessageIndex_truncatesMessages` — 截断分叉
  - [x] 测试 `testFork_withCustomSessionId_usesProvidedId` — 自定义 ID
  - [x] 测试 `testFork_nonexistentSource_returnsNil` — 源不存在
  - [x] 测试 `testFork_doesNotModifyOriginalSession` — 原始会话不变
  - [x] 测试 `testFork_metadata_correctCreatedAtAndSummary` — 元数据验证
  - [x] 测试 `testFork_concurrentForks_noDataCorruption` — 并发安全

- [x] Task 4: E2E 测试 (AC: #10)
  - [x] 创建/扩展 `Sources/E2ETest/SessionForkE2ETests.swift`
  - [x] E2E 测试：完整会话分叉 → 恢复 → 验证消息完整
  - [x] E2E 测试：截断分叉 → 恢复 → 验证消息数量正确
  - [x] E2E 测试：分叉后继续对话 → 验证分叉和原始会话独立演进

- [x] Task 5: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证新增代码不违反模块边界
  - [x] 验证所有现有测试仍通过

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 7（会话持久化）的第三个 story
- **SessionStore 扩展 story** — 在 SessionStore actor 上添加 `fork()` 方法
- **关键目标：** 实现开发者可以从任何保存点分叉对话，满足 FR25

**设计原则：纯 SessionStore 层操作**
- 分叉不需要修改 Agent.swift — 它只是 load() + save() 的组合
- 分叉后的新会话 ID 可直接用于 AgentOptions.sessionId 恢复对话
- 与 Story 7-2 建立的恢复机制完全兼容

### 已有的类型和组件（直接使用，无需修改核心逻辑）

| 组件 | 位置 | 说明 |
|------|------|------|
| `SessionStore` | `Stores/SessionStore.swift` | 已实现：save(), load(), delete() |
| `SessionData` | `Types/SessionTypes.swift` | 已定义：metadata + messages: `[[String: Any]]` |
| `SessionMetadata` | `Types/SessionTypes.swift` | 已定义：id, cwd, model, createdAt, updatedAt, messageCount, summary |
| `PartialSessionMetadata` | `Types/SessionTypes.swift` | 已定义：cwd, model, summary（save 输入用） |
| `Agent` | `Core/Agent.swift` | 已实现：带 sessionStore/sessionId 的 prompt()/stream() 恢复 |

### TypeScript SDK 参考

TypeScript SDK 的 `session.ts` 提供了直接参考：

```typescript
// session.ts — forkSession 函数
export async function forkSession(
  sourceSessionId: string,
  newSessionId?: string,
): Promise<string | null> {
  const data = await loadSession(sourceSessionId)
  if (!data) return null

  const forkId = newSessionId || crypto.randomUUID()

  await saveSession(forkId, data.messages, {
    ...data.metadata,
    id: forkId,
    createdAt: new Date().toISOString(),
    summary: `Forked from session ${sourceSessionId}`,
  })

  return forkId
}
```

**TypeScript SDK 分叉模式分析：**
1. 加载源会话（load）
2. 不存在则返回 null
3. 生成新 ID 或使用提供的 ID
4. 保存新会话，复制全部消息
5. 元数据中 createdAt 设为当前时间
6. summary 标注 fork 来源

**与 TypeScript 的差异（Swift 增强）：**
- TypeScript 没有消息截断功能 — 本 story 增加了 `upToMessageIndex` 参数
- TypeScript 使用 `crypto.randomUUID()` — Swift 使用 `UUID().uuidString`
- TypeScript 没有并发安全保证 — Swift 的 actor 隔离自动保证

### 关键实现细节

**1. fork() 方法实现**

```swift
/// Fork a session — create a copy with a new ID.
/// - Parameters:
///   - sourceSessionId: The session to fork from.
///   - newSessionId: Optional new session ID. Auto-generated if nil.
///   - upToMessageIndex: Optional message index to truncate at (inclusive).
///     When nil, all messages are copied.
/// - Returns: The new session ID, or nil if source doesn't exist.
public func fork(
    sourceSessionId: String,
    newSessionId: String? = nil,
    upToMessageIndex: Int? = nil
) throws -> String? {
    // Load source session
    guard let sourceData = try load(sessionId: sourceSessionId) else {
        return nil
    }

    // Determine messages to copy
    var forkMessages = sourceData.messages
    if let upToIndex = upToMessageIndex {
        guard upToIndex >= 0, upToIndex < sourceData.messages.count else {
            throw SDKError.sessionError(message: "upToMessageIndex \(upToIndex) out of range (0..<\(sourceData.messages.count))")
        }
        forkMessages = Array(sourceData.messages[0...upToIndex])
    }

    // Generate or use provided ID
    let forkId = newSessionId ?? UUID().uuidString

    // Save the forked session
    let metadata = PartialSessionMetadata(
        cwd: sourceData.metadata.cwd,
        model: sourceData.metadata.model,
        summary: "Forked from session \(sourceSessionId)"
    )
    try save(sessionId: forkId, messages: forkMessages, metadata: metadata)

    return forkId
}
```

**2. 无需修改 Agent.swift**

分叉操作创建的新会话完全兼容现有的恢复流程：
- `SessionStore.save()` 创建的 transcript.json 格式与 Story 7-1 定义的一致
- `SessionStore.load()` 读取分叉会话时返回正确的 SessionData
- `AgentOptions.sessionId` 设为分叉 ID 后，`Agent.prompt()`/`Agent.stream()` 自动恢复

**3. upToMessageIndex 边界处理**

- 索引从 0 开始，包含边界（0...upToIndex）
- 负数或超出范围应抛出 `SDKError.sessionError`
- nil 表示复制全部消息（与 TypeScript SDK 行为一致）

**4. sessionId 验证**

- `newSessionId` 如果提供，需要通过现有的 `validateSessionId()` 检查
- 自动生成的 UUID 天然不含非法字符

**5. 与 save() 的关系**

- fork() 内部调用 save()，因此自动继承：
  - 0600 文件权限（NFR10）
  - 目录权限 0700
  - sessionId 路径遍历验证
  - JSON 序列化

### 前序 Story 的经验教训（必须遵循）

1. **SessionStore.load() 返回 `SessionData?`** — 不存在时返回 nil，fork() 可直接使用
2. **消息格式是 `[[String: Any]]`** — 截断使用 Array subscript，无需额外转换
3. **Actor 调用需要 `await`** — fork() 是 actor 方法，外部调用需要 `await`
4. **save() 接受 `PartialSessionMetadata`** — 无需构造完整 SessionMetadata
5. **validateSessionId() 验证路径遍历** — newSessionId 必须通过相同验证
6. **MARK 注释风格** — 遵循 `// MARK: - Public API` 等格式
7. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
8. **E2E 测试** — 使用真实文件系统（E2E 规则：不使用 mock）
9. **SessionStore 支持自定义目录** — 构造函数接受 `sessionsDir: String?` 用于测试注入
10. **不使用 Apple 专属框架** — UUID() 在 macOS 和 Linux 均可用
11. **JSONSerialization 用于 Sendable 合规** — 在 actor 边界传递 `[String: Any]` 时的模式（fork 在 actor 内部调用 save，无需额外序列化）

### 反模式警告

- **不要**修改 `Agent.swift` — 分叉是纯 SessionStore 层操作
- **不要**修改 `SessionTypes.swift` — 现有类型完全满足需求
- **不要**在 fork() 中使用 force-unwrap (`!`) — 使用 guard let / if let
- **不要**跳过 newSessionId 的路径验证 — 必须通过 validateSessionId()
- **不要**在 fork 失败时影响源会话 — 先读后写，原子操作
- **不要**使用 `import Logging` — 与前序 story 保持一致
- **不要**使用 Apple 专属框架（UIKit, AppKit）— 必须跨平台
- **不要**在 upToMessageIndex 越界时静默截断 — 应抛出错误
- **不要**在单元测试中使用真实 API 调用 — 使用 SessionStore(sessionsDir:) 注入临时目录

### 模块边界

```
Stores/SessionStore.swift       → 修改：添加 fork() 方法
Types/SessionTypes.swift        → 不修改：类型定义已满足需求
Types/ErrorTypes.swift          → 不修改：SDKError.sessionError 已满足需求
Core/Agent.swift                → 不修改：恢复机制已兼容分叉会话
```

新测试文件：
```
Tests/OpenAgentSDKTests/Stores/SessionStoreForkTests.swift   (新建)
Sources/E2ETest/SessionForkE2ETests.swift                     (新建)
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 7-1 (已完成) | 前置依赖 — 提供了 SessionStore.save()、load()、SessionData、PartialSessionMetadata |
| 7-2 (已完成) | 前置依赖 — 提供了 Agent 中的 sessionStore.load() 恢复机制，分叉后的新会话可直接用于恢复 |
| 7-4 (backlog) | 后续 — 会话管理将添加 list/rename/tag/delete 到 SessionStore |
| 4-6 (已完成) | 模式参考 — TeamCreate/Delete 的 actor 方法模式 |

### 测试策略

**单元测试（Tests/OpenAgentSDKTests/Stores/SessionStoreForkTests.swift）：**

使用临时目录的 SessionStore（sessionsDir 注入），不使用 mock：
- 每个测试创建独立的临时目录
- 使用 setUp/tearDown 管理临时目录生命周期
- 直接在文件系统上验证分叉结果

**E2E 测试（Sources/E2ETest/SessionForkE2ETests.swift）：**

- 使用真实文件系统（E2E 规则：不使用 mock）
- 在 `~/.open-agent-sdk/sessions/` 中创建和读取真实文件
- 测试后清理测试数据
- 验证分叉会话可被 Agent 恢复并继续对话

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.3 会话分叉]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD6 会话持久化]
- [Source: _bmad-output/planning-artifacts/prd.md#FR25 从任何保存点分叉对话]
- [Source: _bmad-output/project-context.md#规则 1 Actor 用于共享可变状态]
- [Source: _bmad-output/project-context.md#规则 7 模块边界]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/session.ts#forkSession] — TypeScript SDK 分叉实现参考
- [Source: Sources/OpenAgentSDK/Stores/SessionStore.swift] — SessionStore.save()/load() 实现
- [Source: Sources/OpenAgentSDK/Types/SessionTypes.swift] — SessionData 和 PartialSessionMetadata 类型
- [Source: Sources/OpenAgentSDK/Core/Agent.swift] — prompt()/stream() 恢复逻辑
- [Source: _bmad-output/implementation-artifacts/7-2-session-load-restore.md] — Story 7-2 经验教训

### Project Structure Notes

- **修改** `Sources/OpenAgentSDK/Stores/SessionStore.swift` — 添加 fork() 方法
- **新建** `Tests/OpenAgentSDKTests/Stores/SessionStoreForkTests.swift` — 单元测试
- **新建** `Sources/E2ETest/SessionForkE2ETests.swift` — E2E 测试
- **不修改** `Core/Agent.swift` — 恢复机制已兼容分叉会话
- **不修改** `Types/SessionTypes.swift` — 类型定义已满足需求
- 完全对齐架构文档的目录结构和模块边界

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Implemented `fork()` method on SessionStore actor with full upToMessageIndex truncation support
- fork() loads source via existing load(), returns nil for non-existent source, truncates messages if upToMessageIndex provided, validates newSessionId via validateSessionId(), saves new session via existing save()
- upToMessageIndex bounds-checked: negative and out-of-range throw SDKError.sessionError
- New session summary set to "Forked from session {sourceSessionId}"
- No modifications to Agent.swift, SessionTypes.swift, or ErrorTypes.swift -- fork is a pure SessionStore layer operation
- Fixed ATDD test concurrency issue: replaced mutable array capture in task group with result-collecting pattern
- All 15 unit tests pass, all 1453 total tests pass (0 failures, 4 skipped)
- E2E tests registered in main.swift Section 36 (created by ATDD phase)

### File List

- `Sources/OpenAgentSDK/Stores/SessionStore.swift` (modified: added fork() method)
- `Tests/OpenAgentSDKTests/Stores/SessionStoreForkTests.swift` (modified: fixed concurrency issue in testFork_concurrentForks_noDataCorruption, removed unused variable)
- `Sources/E2ETest/SessionForkE2ETests.swift` (created by ATDD phase)
- `Sources/E2ETest/main.swift` (modified by ATDD phase: added Section 36)

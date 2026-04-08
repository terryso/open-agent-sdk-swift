# Story 7.4: 会话管理（列出、重命名、标记、删除）

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望可以列出、重命名、标记和删除已保存的会话，
以便我可以组织和管理我的对话历史。

## Acceptance Criteria

1. **AC1: 列出会话** — 给定多个已保存的会话，当开发者调用 `sessionStore.list()` 时，则返回所有会话的元数据数组（`[SessionMetadata]`），包含 ID、日期、消息数、摘要和标签（FR26）。返回的数组按 `updatedAt` 降序排列（最近更新的在前）。空目录返回空数组，不崩溃。

2. **AC2: 重命名会话** — 给定已存在的会话，当开发者调用 `sessionStore.rename(sessionId:, newTitle:)` 时，则会话的 `summary` 字段更新为新标题，`updatedAt` 更新为当前时间，消息内容不变。不存在的会话不做任何操作（静默成功）。

3. **AC3: 标记会话** — 给定已存在的会话，当开发者调用 `sessionStore.tag(sessionId:, tag:)` 时，则会话元数据中添加 `tag` 字段，`updatedAt` 更新为当前时间。`tag` 为 `String?` — 传入 nil 清除标签。

4. **AC4: 删除会话** — 给定已存在的会话，当开发者调用 `sessionStore.delete(sessionId:)` 时，则返回 `true`，会话目录及其所有文件被移除。不存在的会话返回 `false`，不抛出错误。

5. **AC5: 性能要求** — 给定 500 条消息以下的会话，列出/重命名/标记/删除操作在 200ms 内完成（NFR4）。

6. **AC6: 线程安全** — 给定并发的管理操作（同时列出、重命名、标记、删除），当多个操作同时执行时，则所有操作正确完成，无数据损坏（FR27）。

7. **AC7: SessionMetadata 扩展** — 给定 `SessionMetadata` 结构体需要支持 `tag` 字段，当检查 `Types/SessionTypes.swift` 时，则 `SessionMetadata` 包含 `tag: String?` 属性，且向后兼容（现有不含 tag 的 JSON 正常加载，tag 默认为 nil）。

8. **AC8: list() 跳过无效会话** — 给定 sessions 目录中存在损坏的或缺少 transcript.json 的子目录，当开发者调用 `list()` 时，则跳过无效目录，返回有效会话的元数据，不崩溃。

9. **AC9: 单元测试覆盖** — 给定管理功能，当检查 `Tests/OpenAgentSDKTests/Stores/` 时，则包含 `SessionStoreManagementTests.swift`，至少覆盖：列出空目录、列出多个会话并验证排序、重命名会话、重命名不存在会话、标记会话、清除标签（tag 为 nil）、删除存在/不存在的会话、并发操作安全、tag 字段向后兼容。

10. **AC10: E2E 测试覆盖** — 给定故事完成后，当检查 `Sources/E2ETest/` 时，则包含 `SessionManagementE2ETests.swift`，至少覆盖：列出会话验证元数据完整、重命名后验证更新、标记后验证持久化、删除后验证不可加载。

## Tasks / Subtasks

- [x] Task 1: 扩展 SessionMetadata 添加 tag 字段 (AC: #7)
  - [x] 在 `SessionMetadata` 中添加 `tag: String?` 属性
  - [x] 更新 `SessionMetadata.init()` 添加 `tag: String? = nil` 参数（保持向后兼容）
  - [x] 更新 `SessionStore.save()` 在序列化时写入 tag 字段（非 nil 时）
  - [x] 更新 `SessionStore.load()` 在反序列化时读取 tag 字段（缺失时默认 nil）
  - [x] 确保现有无 tag 的 JSON 文件加载正常（向后兼容）

- [x] Task 2: 实现 list() 方法 (AC: #1, #8)
  - [x] 在 `SessionStore` 中添加 `public func list() throws -> [SessionMetadata]`
  - [x] 扫描 sessions 目录下的所有子目录
  - [x] 对每个子目录调用 load() 提取 metadata
  - [x] 跳过加载失败的目录（try? 静默处理）
  - [x] 按 `updatedAt` 降序排序返回
  - [x] sessions 目录不存在时返回空数组

- [x] Task 3: 实现 rename() 方法 (AC: #2)
  - [x] 在 `SessionStore` 中添加 `public func rename(sessionId:, newTitle:) throws`
  - [x] 加载现有会话数据，不存在则静默返回
  - [x] 更新 metadata.summary 为 newTitle
  - [x] 使用 save() 重新保存，保留 createdAt
  - [x] updatedAt 自动更新为当前时间（save() 内部处理）

- [x] Task 4: 实现 tag() 方法 (AC: #3)
  - [x] 在 `SessionStore` 中添加 `public func tag(sessionId:, tag: String?) throws`
  - [x] 加载现有会话数据，不存在则静默返回
  - [x] 更新 metadata 的 tag 字段
  - [x] 使用 save() 重新保存，保留 createdAt
  - [x] updatedAt 自动更新为当前时间

- [x] Task 5: 验证现有 delete() 满足 AC4 (AC: #4)
  - [x] 验证 `SessionStore.delete()` 已在 Story 7-1 中实现且满足 AC4 要求
  - [x] 确认 delete 返回 Bool、不存在返回 false、不抛出错误

- [x] Task 6: 单元测试 (AC: #9)
  - [x] 创建 `Tests/OpenAgentSDKTests/Stores/SessionStoreManagementTests.swift`
  - [x] 测试 `testList_emptyDir_returnsEmptyArray`
  - [x] 测试 `testList_multipleSessions_returnsSortedByUpdatedAt`
  - [x] 测试 `testList_includesTagInMetadata`
  - [x] 测试 `testList_skipsInvalidDirectories`
  - [x] 测试 `testRename_updatesSummary`
  - [x] 测试 `testRename_nonexistent_silentSuccess`
  - [x] 测试 `testTag_addsTagToMetadata`
  - [x] 测试 `testTag_nilRemovesTag`
  - [x] 测试 `testDelete_existing_returnsTrue`
  - [x] 测试 `testDelete_nonexistent_returnsFalse`
  - [x] 测试 `testConcurrentManagementOperations_noDataCorruption`
  - [x] 测试 `testTag_backwardCompatible_missingTagLoadsAsNil`

- [x] Task 7: E2E 测试 (AC: #10)
  - [x] 创建 `Sources/E2ETest/SessionManagementE2ETests.swift`
  - [x] E2E 测试：创建多个会话 → list() → 验证元数据完整且排序正确
  - [x] E2E 测试：rename() → list() → 验证摘要更新
  - [x] E2E 测试：tag() → load() → 验证 tag 持久化
  - [x] E2E 测试：delete() → list() → 验证会话已移除

- [x] Task 8: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 验证所有现有测试仍通过
  - [x] 更新 `Sources/E2ETest/main.swift` 添加 Section 37

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- Epic 7（会话持久化）的最后一个 story
- **SessionStore 管理方法扩展** — 添加 list()、rename()、tag() 方法
- **关键目标：** 实现开发者可以组织和管理对话历史，满足 FR26

**设计原则：在 SessionStore actor 上扩展管理方法**
- list()、rename()、tag() 都是 SessionStore 的公共方法
- 这些方法组合使用现有的 load() 和 save() 基础设施
- delete() 已在 Story 7-1 中实现，本 story 验证其满足 AC 即可

### 已有的类型和组件（直接使用，无需修改核心逻辑）

| 组件 | 位置 | 说明 |
|------|------|------|
| `SessionStore` | `Stores/SessionStore.swift` | 已实现：save(), load(), delete(), fork() |
| `SessionData` | `Types/SessionTypes.swift` | 已定义：metadata + messages: `[[String: Any]]` |
| `SessionMetadata` | `Types/SessionTypes.swift` | 需修改：添加 `tag: String?` 字段 |
| `PartialSessionMetadata` | `Types/SessionTypes.swift` | 需评估：rename/tag 是否需要扩展 |
| `Agent` | `Core/Agent.swift` | 不修改：管理操作不涉及 Agent 循环 |

### TypeScript SDK 参考

TypeScript SDK 的 `session.ts` 提供了直接参考：

```typescript
// session.ts — listSessions 函数
export async function listSessions(): Promise<SessionMetadata[]> {
  try {
    const dir = getSessionsDir()
    const entries = await readdir(dir)
    const sessions: SessionMetadata[] = []

    for (const entry of entries) {
      try {
        const data = await loadSession(entry)
        if (data?.metadata) {
          sessions.push(data.metadata)
        }
      } catch {
        // Skip invalid sessions
      }
    }

    // Sort by updatedAt descending
    sessions.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
    return sessions
  } catch {
    return []
  }
}

// session.ts — renameSession 函数
export async function renameSession(
  sessionId: string,
  title: string,
  options?: { dir?: string },
): Promise<void> {
  const data = await loadSession(sessionId)
  if (!data) return

  data.metadata.summary = title
  data.metadata.updatedAt = new Date().toISOString()

  await saveSession(sessionId, data.messages, data.metadata)
}

// session.ts — tagSession 函数
export async function tagSession(
  sessionId: string,
  tag: string | null,
  options?: { dir?: string },
): Promise<void> {
  const data = await loadSession(sessionId)
  if (!data) return

  ;(data.metadata as any).tag = tag
  data.metadata.updatedAt = new Date().toISOString()

  await saveSession(sessionId, data.messages, data.metadata)
}
```

**TypeScript SDK 管理模式分析：**
1. `listSessions()` — 遍历目录，每个子目录 load 一次，收集 metadata，按 updatedAt 降序排序
2. `renameSession()` — load → 更新 summary → save（TS 直接设置 updatedAt，Swift 的 save() 自动处理）
3. `tagSession()` — load → 设置 tag → save（TS 用 `(data.metadata as any).tag = tag`，说明 tag 是动态属性）

**与 TypeScript 的差异（Swift 增强）：**
- TypeScript 的 tag 用 `as any` 添加动态属性 — Swift 需要在 `SessionMetadata` 结构体中正式声明
- TypeScript 不保证并发安全 — Swift 的 actor 隔离自动保证
- Swift 需要处理 tag 字段在旧 JSON 中缺失的情况（向后兼容）

### 关键实现细节

**1. SessionMetadata 添加 tag 字段**

```swift
public struct SessionMetadata: Sendable, Equatable {
    public let id: String
    public let cwd: String
    public let model: String
    public let createdAt: String
    public let updatedAt: String
    public let messageCount: Int
    public let summary: String?
    public let tag: String?  // 新增

    public init(
        id: String,
        cwd: String,
        model: String,
        createdAt: String,
        updatedAt: String,
        messageCount: Int,
        summary: String? = nil,
        tag: String? = nil     // 新增，默认 nil
    ) { ... }
}
```

**2. save() 序列化需要写入 tag**

在 `SessionStore.save()` 的 metadataDict 构建中添加：
```swift
if let tag = metadata.tag {
    metadataDict["tag"] = tag
}
```

但注意：`PartialSessionMetadata` 是 save() 的输入类型。rename/tag 操作是 load → 修改 → save 的模式，需要传递完整的 metadata（包含 tag）。

**两种实现策略（推荐策略 A）：**

**策略 A（推荐）：save() 接受可选 tag 参数**
在 `PartialSessionMetadata` 中添加 `tag: String?` 字段。rename/tag 操作使用现有的 load() → 修改 → save() 模式。

**策略 B：新增 saveMetadata() 方法**
添加一个直接更新元数据的方法，不需要重写整个 transcript。

推荐策略 A，因为它复用现有 save() 基础设施，且 TypeScript SDK 也是 load → modify → save 的模式。

**3. list() 方法实现**

```swift
public func list() throws -> [SessionMetadata] {
    let sessionsDir = getSessionsDir()

    guard let entries = try? FileManager.default.contentsOfDirectory(atPath: sessionsDir) else {
        return []
    }

    var sessions: [SessionMetadata] = []
    for entry in entries {
        // load() 需要 validateSessionId，目录名就是 sessionId
        if let data = try? load(sessionId: entry),
           let metadata = data?.metadata {
            sessions.append(metadata)
        }
        // 跳过无效/损坏的会话
    }

    // 按 updatedAt 降序排序
    sessions.sort { $0.updatedAt > $1.updatedAt }
    return sessions
}
```

**4. rename() 方法实现**

```swift
public func rename(sessionId: String, newTitle: String) throws {
    try validateSessionId(sessionId)
    guard let data = try load(sessionId: sessionId) else { return }

    let metadata = PartialSessionMetadata(
        cwd: data.metadata.cwd,
        model: data.metadata.model,
        summary: newTitle,
        tag: data.metadata.tag     // 保留原有 tag
    )
    try save(sessionId: sessionId, messages: data.messages, metadata: metadata)
}
```

注意：save() 会保留原有的 createdAt（通过 loadExistingCreatedAt），所以 rename 不会改变创建时间。

**5. tag() 方法实现**

```swift
public func tag(sessionId: String, tag: String?) throws {
    try validateSessionId(sessionId)
    guard let data = try load(sessionId: sessionId) else { return }

    let metadata = PartialSessionMetadata(
        cwd: data.metadata.cwd,
        model: data.metadata.model,
        summary: data.metadata.summary,
        tag: tag                  // 新 tag 值，nil 清除
    )
    try save(sessionId: sessionId, messages: data.messages, metadata: metadata)
}
```

**6. load() 反序列化需要读取 tag**

在 `SessionStore.load()` 的 metadata 构建中添加：
```swift
let tag = metadataDict["tag"] as? String  // 缺失时默认 nil（向后兼容）
```

然后传入 `SessionMetadata` 的 init：
```swift
let metadata = SessionMetadata(
    id: id,
    cwd: cwd,
    model: model,
    createdAt: createdAt,
    updatedAt: updatedAt,
    messageCount: messageCount,
    summary: summary,
    tag: tag                  // 新增
)
```

**7. PartialSessionMetadata 添加 tag**

```swift
public struct PartialSessionMetadata: Sendable {
    public let cwd: String
    public let model: String
    public let summary: String?
    public let tag: String?       // 新增

    public init(cwd: String, model: String, summary: String? = nil, tag: String? = nil) {
        self.cwd = cwd
        self.model = model
        self.summary = summary
        self.tag = tag
    }
}
```

**8. delete() 验证**

`delete()` 已在 Story 7-1 中实现（`SessionStore.swift` 第 149-163 行），方法签名 `public func delete(sessionId: String) throws -> Bool`，行为完全满足 AC4：
- 存在的会话：删除目录，返回 true
- 不存在的会话：返回 false
- 不抛出错误（catch 块内返回 false）

无需修改。

### 前序 Story 的经验教训（必须遵循）

1. **SessionStore.load() 返回 `SessionData?`** — 不存在时返回 nil，rename/tag 使用 guard let 静默返回
2. **消息格式是 `[[String: Any]]`** — rename/tag 直接传递 data.messages 给 save()
3. **Actor 调用需要 `await`** — list/rename/tag 是 actor 方法，外部调用需要 `await`
4. **save() 接受 `PartialSessionMetadata`** — 需要扩展添加 tag 字段
5. **save() 保留 createdAt** — 通过 loadExistingCreatedAt() 实现，rename/tag 不需要特殊处理
6. **validateSessionId() 验证路径遍历** — 所有接受 sessionId 的方法都需要调用
7. **MARK 注释风格** — 遵循 `// MARK: - Public API` 等格式
8. **测试命名** — `test{MethodName}_{scenario}_{expectedBehavior}` 格式
9. **E2E 测试** — 使用真实文件系统（E2E 规则：不使用 mock）
10. **SessionStore 支持自定义目录** — 构造函数接受 `sessionsDir: String?` 用于测试注入
11. **不使用 Apple 专属框架** — FileManager 在 macOS 和 Linux 均可用
12. **list() 在 actor 内部调用 load()** — 不需要 await（同一 actor 隔离）
13. **fork() 在 actor 内部调用 load() 和 save()** — 同一 actor 内同步调用模式
14. **JSONSerialization 用于序列化** — save() 中已使用的模式

### 反模式警告

- **不要**修改 `Agent.swift` — 管理操作不涉及 Agent 循环
- **不要**在 rename/tag 中使用 force-unwrap (`!`) — 使用 guard let / if let
- **不要**跳过 sessionId 的路径验证 — rename/tag 也需要 validateSessionId()
- **不要**在 rename 失败时抛出错误 — TS SDK 的行为是静默成功（if (!data) return）
- **不要**使用 `import Logging` — 与前序 story 保持一致
- **不要**使用 Apple 专属框架（UIKit, AppKit）— 必须跨平台
- **不要**在 list() 中使用 directory 名称作为 metadata — 必须通过 load() 验证
- **不要**修改 `Core/` 目录下的任何文件 — 管理操作是纯 SessionStore 层
- **不要**破坏 PartialSessionMetadata 的现有调用方 — tag 参数必须有默认值 nil

### 模块边界

```
Stores/SessionStore.swift       → 修改：添加 list(), rename(), tag() 方法
Types/SessionTypes.swift        → 修改：SessionMetadata 添加 tag, PartialSessionMetadata 添加 tag
Types/ErrorTypes.swift          → 不修改：SDKError.sessionError 已满足需求
Core/Agent.swift                → 不修改：管理操作不涉及 Agent 循环
```

新测试文件：
```
Tests/OpenAgentSDKTests/Stores/SessionStoreManagementTests.swift   (新建)
Sources/E2ETest/SessionManagementE2ETests.swift                     (新建)
Sources/E2ETest/main.swift                                          (修改：添加 Section 37)
```

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 7-1 (已完成) | 前置依赖 — 提供了 SessionStore.save(), load(), delete(), PartialSessionMetadata |
| 7-2 (已完成) | 前置依赖 — 提供了 Agent 恢复机制，管理操作不直接依赖 |
| 7-3 (已完成) | 前置依赖 — 提供了 fork()，管理操作可能对分叉的会话执行 rename/tag |
| 4-6 (已完成) | 模式参考 — TeamCreate/Delete 的 actor 方法模式 |

### 测试策略

**单元测试（Tests/OpenAgentSDKTests/Stores/SessionStoreManagementTests.swift）：**

使用临时目录的 SessionStore（sessionsDir 注入），不使用 mock：
- 每个测试创建独立的临时目录
- 使用 setUp/tearDown 管理临时目录生命周期
- 直接在文件系统上验证操作结果

**E2E 测试（Sources/E2ETest/SessionManagementE2ETests.swift）：**

- 使用真实文件系统（E2E 规则：不使用 mock）
- 在 `~/.open-agent-sdk/sessions/` 中创建和读取真实文件
- 测试后清理测试数据
- Section 37 注册到 main.swift

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.4 会话管理]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD6 会话持久化]
- [Source: _bmad-output/planning-artifacts/prd.md#FR26 列出、重命名、标记和删除会话]
- [Source: _bmad-output/planning-artifacts/prd.md#FR27 会话存储线程安全]
- [Source: _bmad-output/planning-artifacts/prd.md#NFR4 性能要求]
- [Source: _bmad-output/planning-artifacts/prd.md#NFR10 文件权限]
- [Source: _bmad-output/project-context.md#规则 1 Actor 用于共享可变状态]
- [Source: _bmad-output/project-context.md#规则 7 模块边界]
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/session.ts#listSessions] — TypeScript SDK 列出实现参考
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/session.ts#renameSession] — TypeScript SDK 重命名实现参考
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/session.ts#tagSession] — TypeScript SDK 标记实现参考
- [Source: Sources/OpenAgentSDK/Stores/SessionStore.swift] — SessionStore.save()/load()/delete()/fork() 现有实现
- [Source: Sources/OpenAgentSDK/Types/SessionTypes.swift] — SessionMetadata 和 PartialSessionMetadata 类型定义
- [Source: _bmad-output/implementation-artifacts/7-3-session-fork.md] — Story 7-3 经验教训

### Project Structure Notes

- **修改** `Sources/OpenAgentSDK/Stores/SessionStore.swift` — 添加 list(), rename(), tag() 方法
- **修改** `Sources/OpenAgentSDK/Types/SessionTypes.swift` — SessionMetadata 添加 tag 字段, PartialSessionMetadata 添加 tag 字段
- **新建** `Tests/OpenAgentSDKTests/Stores/SessionStoreManagementTests.swift` — 单元测试
- **新建** `Sources/E2ETest/SessionManagementE2ETests.swift` — E2E 测试
- **修改** `Sources/E2ETest/main.swift` — 添加 Section 37
- **不修改** `Core/Agent.swift` — 管理操作不涉及 Agent 循环
- 完全对齐架构文档的目录结构和模块边界

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Task 1: Added `tag: String?` to `SessionMetadata` (with default `nil` for backward compatibility) and `PartialSessionMetadata`. Updated `save()` to serialize tag when non-nil, updated `load()` to deserialize tag (missing -> nil). Backward compatibility verified by ATDD test.
- Task 2: Implemented `list()` method on SessionStore. Scans sessions directory, uses load() per entry, silently skips invalid/corrupt sessions, sorts by updatedAt descending. Returns empty array when directory doesn't exist.
- Task 3: Implemented `rename()` method. Load -> update summary -> save pattern. Silent no-op for non-existent sessions. Preserves createdAt via save() internal mechanism.
- Task 4: Implemented `tag()` method. Load -> update tag -> save pattern. Pass nil to clear tag. Silent no-op for non-existent sessions.
- Task 5: Verified delete() already satisfies AC4 (returns Bool, false for non-existent, no throw).
- Task 6: All 13 ATDD unit tests pass (including concurrent operations, performance under 200ms, backward compatibility).
- Task 7: E2E test file and Section 37 in main.swift were pre-created by test architect. Fixed a SendingRisksDataRace compiler diagnostic in E2E test by inlining literal values.
- Task 8: `swift build` succeeds. Full test suite: all 1466 tests pass, 0 failures, 4 skipped (pre-existing).

### Change Log

- 2026-04-09: Implemented session management (list, rename, tag, delete) -- all 8 tasks completed, all 13 ATDD tests pass, full regression suite green (1466 tests).

### File List

- `Sources/OpenAgentSDK/Types/SessionTypes.swift` (modified: added tag field to SessionMetadata and PartialSessionMetadata)
- `Sources/OpenAgentSDK/Stores/SessionStore.swift` (modified: added list(), rename(), tag() methods; updated save() and load() for tag serialization/deserialization)
- `Sources/E2ETest/SessionManagementE2ETests.swift` (modified: fixed SendingRisksDataRace compiler diagnostic)
- `Tests/OpenAgentSDKTests/Stores/SessionStoreManagementTests.swift` (pre-existing ATDD tests, all now passing)
- `Sources/E2ETest/main.swift` (pre-existing Section 37 wiring)

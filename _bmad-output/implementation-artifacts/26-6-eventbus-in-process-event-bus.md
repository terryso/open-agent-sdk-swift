# Story 26.6: EventBus — In-Process Event Bus

Status: done

## Story

As a SDK 开发者,
I want 一个进程内的 EventBus actor 支持多 subscriber 和类型过滤订阅,
So that 多个 consumer（CLI output、SSE push、trace、TUI）可以同时消费同一个 event stream.

## Acceptance Criteria

1. **AC1: publish 广播到所有 subscriber**
   - Given EventBus 有 3 个 subscriber 通过 `subscribe()` 订阅
   - When `publish` 一个 `AgentStartedEvent`
   - Then 3 个 subscriber 都通过 `AsyncStream` 收到同一个 event

2. **AC2: 慢 subscriber 不阻塞 publisher**
   - Given EventBus 有 1 个 subscriber 不消费（buffer 堆积）
   - When 连续 `publish` 200 个 event
   - Then subscriber 的 buffer 只保留最新 100 个，`publish` 不被阻塞（不被 await 挂起）

3. **AC3: 类型过滤 subscribe**
   - Given subscriber 调用 `subscribe(ToolStartedEvent.self)`
   - When 先 `publish` 一个 `AgentStartedEvent` 再 `publish` 一个 `ToolStartedEvent`
   - Then subscriber 只收到 `ToolStartedEvent`

4. **AC4: 取消订阅无泄漏**
   - Given subscriber 取消订阅（AsyncStream deinit 或调用 `unsubscribe(_ id:)`）
   - When `publish` 一个 event
   - Then 该 subscriber 不再收到 event，Continuation 被清理，无内存泄漏

5. **AC5: 无 subscriber 时 publish 不报错**
   - Given EventBus 的 subscriber 全部取消
   - When `publish` 一个 event
   - Then 不报错，event 被丢弃

6. **AC6: 不改现有 API**
   - 不修改 `AgentEvent`、`BaseAgentEvent`、`AgentEventCategory`、`SessionFinalStatus` 或任何现有类型
   - 不修改任何 26.1-26.5 已有代码
   - `EventBus` 是纯新增文件

7. **AC7: EventBus 为 actor**
   - `EventBus` 声明为 `public actor`
   - 所有 mutable state（subscriber 字典）由 actor isolation 保护
   - 线程安全

## Tasks / Subtasks

- [x] Task 1: 创建 EventBus actor (AC: #1, #5, #7)
  - [x] 1.1 创建 `Sources/OpenAgentSDK/Core/EventBus.swift`
  - [x] 1.2 定义 `public actor EventBus`
  - [x] 1.3 实现 `subscribe() -> AsyncStream<any AgentEvent>`（bufferingPolicy: .bufferingNewest(100)）
  - [x] 1.4 实现 `publish(_ event: any AgentEvent)` — 遍历所有 continuation yield event
  - [x] 1.5 实现 subscriber 字典 `[UUID: AsyncStream<any AgentEvent>.Continuation]`
  - [x] 1.6 实现 `onTermination` 回调自动清理 subscriber
  - [x] 1.7 在 `onTermination` 中清理对应的类型过滤 Task
- [x] Task 2: 实现类型过滤 subscribe (AC: #3)
  - [x] 2.1 实现 `subscribe<T: AgentEvent>(_ type: T.Type) -> AsyncStream<T>`
  - [x] 2.2 内部创建消费 Task 从全量 stream 读取并做 `as? T` 过滤
  - [x] 2.3 跟踪类型过滤 Task 以便取消时清理
  - [x] 2.4 外层 AsyncStream deinit 时自动取消消费 Task
- [x] Task 3: 实现 unsubscribe 显式取消 (AC: #4)
  - [x] 3.1 实现 `unsubscribe(_ id: UUID)` — 从字典移除 continuation
  - [x] 3.2 在 `subscribe()` 中记录返回 subscriber 的 UUID 供外部调用
  - [x] 3.3 清理关联的类型过滤 Task
- [x] Task 4: 编写单元测试 (AC: #1-#7)
  - [x] 4.1 创建 `Tests/OpenAgentSDKTests/Core/EventBusTests.swift`
  - [x] 4.2 测试 AC1: 多 subscriber 广播
  - [x] 4.3 测试 AC2: 慢 subscriber 不阻塞（200 event publish，验证 buffer 只保留最新 100）
  - [x] 4.4 测试 AC3: 类型过滤 subscribe（ToolStartedEvent 过滤）
  - [x] 4.5 测试 AC4: 取消订阅后不再收到 event
  - [x] 4.6 测试 AC5: 无 subscriber 时 publish 不 crash
  - [x] 4.7 测试 AC7: actor isolation 验证
  - [x] 4.8 测试 subscriber 连续 publish 顺序保证
  - [x] 4.9 测试多个类型过滤 subscriber 共存
  - [x] 4.10 测试 publish 多种 event 类型
  - [x] 4.11 测试 onTermination 自动清理
- [x] Task 5: 编写 E2E 测试 (AC: #1-#7)
  - [x] 5.1 创建 `Sources/E2ETest/EventBusE2ETests.swift`
  - [x] 5.2 E2E 测试: 真实并发场景 — 多 Task 同时 publish 和 subscribe
  - [x] 5.3 E2E 测试: 混合 subscribe（全量 + 类型过滤）同时工作
  - [x] 5.4 E2E 测试: 大量 event 高频 publish 压力测试
  - [x] 5.5 E2E 测试: subscriber 取消后内存回收验证
  - [x] 5.6 E2E 测试: 所有 16 种 event 类型通过 EventBus 发布和接收
  - [x] 5.7 在 `main.swift` 中更新 SECTION 注释（87-126 → 87-126+，追加 SECTION 127-xx）

## Dev Notes

### Architecture Context

本 Story 是 Epic 26 的第六个也是最后一个 Story，在 26.1（AgentEvent protocol + BaseAgentEvent）和 26.2-26.5（16 种具体 event 类型）基础上实现 EventBus actor。

**与 26.1-26.5 的关系：**
- 26.1 定义了 `AgentEvent` protocol（`Sendable` + `Codable`）、`BaseAgentEvent` struct、`AgentEventCategory` enum
- 26.2-26.5 在 `AgentEventTypes.swift` 中定义了 16 种具体 event struct
- EventBus 消费 `any AgentEvent`（existential type），不直接依赖具体 event 类型

**与后续 Story 的关系：**
- Epic 27 Agent Emitter 会在 `AgentOptions` 中注入 `EventBus?`，在 `QueryEngine` 的关键节点 emit events
- Epic 28 EventBus → SSE Bridge 会将 EventBus 作为 EventBroadcaster 的上游

### File Location

- **NEW**: `Sources/OpenAgentSDK/Core/EventBus.swift` — EventBus actor
- **NEW**: `Tests/OpenAgentSDKTests/Core/EventBusTests.swift` — 单元测试
- **NEW**: `Sources/E2ETest/EventBusE2ETests.swift` — E2E 测试
- **UPDATE**: `Sources/E2ETest/main.swift` — 更新 SECTION 注释，追加 EventBus E2E 调用

### Implementation Design

#### 核心: EventBus actor

```swift
import Foundation

/// In-process event bus for broadcasting runtime events to multiple subscribers.
///
/// Uses `AsyncStream` with `.bufferingNewest(100)` to prevent slow consumers
/// from blocking publishers. Supports both full-stream and type-filtered subscriptions.
public actor EventBus {

    /// Internal subscriber entry.
    private struct Subscriber {
        let continuation: AsyncStream<any AgentEvent>.Continuation
        let filterTask: _Concurrency.Task<Void, Never>?
    }

    private var subscribers: [UUID: Subscriber] = [:]

    public init() {}

    /// Subscribe to all events.
    public func subscribe() -> AsyncStream<any AgentEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(100)) { continuation in
            let id = UUID()
            subscribers[id] = Subscriber(continuation: continuation, filterTask: nil)
            continuation.onTermination = { [weak self] _ in
                _Concurrency.Task { await self?.removeSubscriber(id: id) }
            }
        }
    }

    /// Subscribe to events of a specific type.
    public func subscribe<T: AgentEvent>(_ type: T.Type) -> AsyncStream<T> {
        AsyncStream(bufferingPolicy: .bufferingNewest(100)) { continuation in
            let id = UUID()
            // Create a full-stream subscriber and filter in a background Task
            let fullStream = await self.subscribeInternal(id: id)
            let filterTask = _Concurrency.Task {
                for await event in fullStream {
                    if let typed = event as? T {
                        continuation.yield(typed)
                    }
                }
            }
            // Store with filter task for cleanup
            await self.setFilterTask(id: id, task: filterTask)
            continuation.onTermination = { [weak self] _ in
                filterTask.cancel()
                _Concurrency.Task { await self?.removeSubscriber(id: id) }
            }
        }
    }

    /// Publish an event to all subscribers.
    public func publish(_ event: any AgentEvent) {
        for (_, subscriber) in subscribers {
            subscriber.continuation.yield(event)
        }
    }

    /// Unsubscribe by ID.
    public func unsubscribe(_ id: UUID) {
        removeSubscriber(id: id)
    }

    // MARK: - Private

    private func subscribeInternal(id: UUID) -> AsyncStream<any AgentEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(100)) { continuation in
            subscribers[id] = Subscriber(continuation: continuation, filterTask: nil)
            // No onTermination here — lifecycle managed by outer subscribe<T>
        }
    }

    private func setFilterTask(id: UUID, task: _Concurrency.Task<Void, Never>) {
        subscribers[id]?.filterTask = task
    }

    private func removeSubscriber(id: UUID) {
        subscribers[id]?.filterTask?.cancel()
        subscribers.removeValue(forKey: id)
    }
}
```

**关键设计决策：**

1. **bufferingPolicy: .bufferingNewest(100)** — 当 subscriber 的 buffer 满 100 个未消费 event 时，丢弃最老的 event，不阻塞 publisher。Epic 文档明确要求此行为。

2. **类型过滤 subscribe 的实现** — `subscribe<T>` 内部调用 `subscribeInternal` 获取全量 stream，然后创建一个消费 Task 做 `as? T` 过滤。当外层 AsyncStream deinit 时，`onTermination` 取消 filterTask 并移除内部 subscriber。

3. **onTermination 自动清理** — 与 `EventBroadcaster`（`HTTP/EventBroadcaster.swift:37`）使用完全相同的模式：`[weak self]` + `Task { await self?.removeSubscriber(...) }`。

4. **Subscriber struct** — 包含 `continuation` 和可选的 `filterTask`，在 `removeSubscriber` 时一起清理。

5. **actor isolation** — 所有 mutable state（`subscribers` 字典）都在 actor 内部，线程安全。

6. **UUID 作为 subscriber ID** — 每个 subscriber 有唯一 ID，支持显式 `unsubscribe(_ id:)` 调用。

### 与现有 EventBroadcaster 的区别

| | EventBus | EventBroadcaster |
|---|---|---|
| 位置 | `Core/EventBus.swift` | `HTTP/EventBroadcaster.swift` |
| 消费类型 | `any AgentEvent` | `AgentSSEEvent` |
| 订阅模型 | 全量 / 类型过滤 | 按 runId 分组 |
| Buffer 策略 | `.bufferingNewest(100)` | 无 buffer 限制 |
| 持久化 | 无 | 可选 RunPersistenceService |
| 用途 | SDK 内部 runtime event 分发 | HTTP SSE 推送 |

EventBus 是更底层的 SDK 内部基础设施。Epic 28 会将 EventBus 连接到 EventBroadcaster。

### Swift 并发注意事项

- `any AgentEvent` 是 existential type，由于 `AgentEvent: Sendable`，`any AgentEvent` 也是 `Sendable`，可以在 actor boundary 间安全传递
- `AsyncStream<any AgentEvent>` 在 actor isolation 下安全使用
- `onTermination` 回调在非 actor-isolated 上下文执行，需要通过 `Task { await self?.... }` 重新进入 actor
- 类型过滤的 `Task` 在 `removeSubscriber` 中需要 `cancel()`，防止幽灵 Task 继续运行

### Testing Standards

- 新建 `Tests/OpenAgentSDKTests/Core/EventBusTests.swift`（不在现有文件追加，因为是新功能）
- 使用 XCTest 框架（`XCTestCase`），与现有 Core/ 目录下的测试一致
- 测试 `async` 方法使用 `await` 调用 actor 方法
- E2E 测试新建 `Sources/E2ETest/EventBusE2ETests.swift`
- E2E 测试编号从 127 开始（当前最后一个 E2E 测试是 126）

### Project Structure Notes

- `Core/` 目录当前有 3 个文件：`Agent.swift`、`DefaultSubAgentSpawner.swift`、`ToolExecutor.swift`
- `Core/` 依赖 `Types/`（已定义 AgentEvent），模块边界正确
- EventBus 不依赖 `API/`、`HTTP/`、`Tools/`、`Stores/` — 只依赖 `Types/AgentEventTypes.swift`

### Scope Boundaries

**本 Story 只做：**
- `EventBus` actor（publish / subscribe / subscribe<T> / unsubscribe）
- 单元测试
- E2E 测试

**不做（后续 Story）：**
- AgentOptions 注入 EventBus（→ Epic 27 Story 27.1）
- QueryEngine 内部 emit 点（→ Epic 27）
- EventBus → EventBroadcaster 桥接（→ Epic 28）
- 持久化（EventBus 设计为瞬时通道）

### References

- [Source: docs/epics/epic-26-agent-event-types.md#Story 26.6]
- [Source: docs/runtime-event-layer-roadmap.md#S2 — EventBus design]
- [Source: Sources/OpenAgentSDK/HTTP/EventBroadcaster.swift — subscriber 管理模式参考]
- [Source: Sources/OpenAgentSDK/Types/AgentEventTypes.swift — 16 种 event 类型（26.1-26.5）]
- [Source: _bmad-output/project-context.md — rules 1, 7-8, 20-22, 26, 39-45]

## Dev Agent Record

### Agent Model Used

GLM-5.1[1m]

### Debug Log References

- Initial test run hung because `removeSubscriber` did not call `continuation.finish()`, causing `for await` loops to block indefinitely on unsubscribed streams. Fixed by adding `continuation.finish()` to `removeSubscriber`.

### Completion Notes List

- Implemented EventBus as `public actor` with subscriber dictionary protected by actor isolation
- `subscribe()` returns `(id: UUID, stream:)` tuple so callers can later call `unsubscribe(_ id:)`
- `subscribe<T>(T.Type)` creates an internal full-stream subscriber and filters via a background Task
- `removeSubscriber` calls `continuation.finish()` to unblock consumer `for await` loops
- `onTermination` uses `[weak self]` + `Task { await self?.removeSubscriber(id:) }` pattern (matches EventBroadcaster)
- `.bufferingNewest(100)` prevents slow subscribers from blocking publishers
- 11 unit tests covering AC1-AC7, order guarantee, multiple type filters, multi-type publish, onTermination cleanup
- 14 E2E tests (tests 127-140) covering concurrent publish/subscribe, mixed subscriptions, stress test, all 16 event types, plus gap-fill tests for no-subscriber publish, onTermination cleanup, re-subscribe lifecycle, multiple same-type filters, type-filtered buffer overflow, pre-published event exclusion, mid-publish unsubscribe
- All 6425 tests pass, 0 regressions

### File List

- `Sources/OpenAgentSDK/Core/EventBus.swift` (NEW)
- `Tests/OpenAgentSDKTests/Core/EventBusTests.swift` (NEW)
- `Sources/E2ETest/EventBusE2ETests.swift` (NEW)
- `Sources/E2ETest/main.swift` (MODIFIED — added SECTION 127-133)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (MODIFIED — status → in-progress)

## Change Log

- 2026-05-26: Story 26.6 created
- 2026-05-26: Implementation complete — EventBus actor with publish/subscribe/type-filter/unsubscribe, 11 unit tests, 14 E2E tests (127-140), all 6425 tests passing
- 2026-05-26: Code review — fixed `try?` silent error swallowing in E2E tests 135/140, replaced timing-dependent `Task.sleep` with `Task.yield` in unit tests, updated Completion Notes to reflect all 14 E2E tests

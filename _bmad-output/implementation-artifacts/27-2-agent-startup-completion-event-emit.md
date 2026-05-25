# Story 27.2: Agent Startup/Completion Event Emit

Status: done

## Story

As a SDK 开发者,
I want agent 在执行开始和结束时 emit 生命周期事件,
So that 上层可以知道 agent 何时开始、何时完成、是否失败.

## Acceptance Criteria

1. **AC1: AgentStartedEvent 在 stream 开始时 emit**
   - Given Agent 配置了 EventBus
   - When `agent.stream("task")` 被调用
   - Then EventBus 收到 `AgentStartedEvent`（含 sessionId、task）

2. **AC2: AgentCompletedEvent 在正常完成时 emit**
   - Given agent 正常执行完成
   - When stream 结束（end_turn / stop_sequence）
   - Then EventBus 收到 `AgentCompletedEvent`（含 totalSteps、durationMs、resultText）

3. **AC3: AgentFailedEvent 在异常时 emit**
   - Given agent 执行过程中遇到 API error
   - When stream 因 error 退出
   - Then EventBus 收到 `AgentFailedEvent`（含 error、stepsCompleted）

4. **AC4: AgentInterruptedEvent 在被中断时 emit**
   - Given agent 执行过程中被 `interrupt()` 调用
   - When stream 退出
   - Then EventBus 收到 `AgentInterruptedEvent`（含 stepsCompleted）

5. **AC5: AgentResumedEvent 在 resume 时 emit**
   - Given agent 处于 paused 状态
   - When `resume(context:)` 被调用
   - Then EventBus 收到 `AgentResumedEvent`（含 resumeContext）

6. **AC6: 无 EventBus 时零开销**
   - Given Agent 未配置 EventBus（`eventBus == nil`）
   - When 执行 stream 或 prompt
   - Then 行为与当前完全一致，无额外开销（不发 publish，不创建 event struct）

7. **AC7: promptImpl 同样 emit 生命周期事件**
   - Given Agent 配置了 EventBus
   - When `agent.prompt("task")` 被调用并完成
   - Then EventBus 收到 `AgentStartedEvent` 和 `AgentCompletedEvent`（或对应的 failed/interrupted event）

8. **AC8: 现有 E2E 测试全部通过**
   - Given 不注入 EventBus
   - When 运行全部现有 E2E 测试
   - Then 全部通过，无回归

## Tasks / Subtasks

- [x] Task 1: 添加 EventBus emit helper 方法 (AC: #6)
  - [x] 1.1 在 `Agent.swift` 中添加 `private func emitEvent(_ event: any AgentEvent) async` 方法
  - [x] 1.2 方法实现：`guard let eventBus = options.eventBus else { return }; await eventBus.publish(event)`
  - [x] 1.3 确保在 eventBus == nil 时零开销（guard early return，不构造 event struct）

- [x] Task 2: promptImpl 中 emit 生命周期事件 (AC: #1, #2, #3, #4, #7)
  - [x] 2.1 在 `promptImpl()` 的 `let startTime = ContinuousClock.now` 之后（行 ~1302），emit `AgentStartedEvent(sessionId: resolvedSessionId, task: text)` — 注意：resolvedSessionId 在行 ~1321 才确定，所以 emit 点应在 session 解析之后、while loop 之前
  - [x] 2.2 emit 位置应在 `setupPromptPauseHandler()` 之后、`while turnCount < maxTurns` 之前（~行 1398），因为需要 resolvedSessionId
  - [x] 2.3 在 while loop 正常退出且 status == .success 时（行 ~1837 `let isCancelled` 之后），emit `AgentCompletedEvent`
  - [x] 2.4 在 catch block 返回 error 时（行 ~1567 return QueryResult 之前），emit `AgentFailedEvent`
  - [x] 2.5 在 `_interrupted` 导致的 cancelled 退出时（行 ~1401 `status = .cancelled` + break 后），emit `AgentInterruptedEvent`

- [x] Task 3: stream 中 emit 生命周期事件 (AC: #1, #2, #3, #4)
  - [x] 3.1 捕获 `capturedEventBus = options.eventBus` 到 captured variables（在 ~行 1930 附近）
  - [x] 3.2 在 stream Task 开始时、system init event yield 之后（行 ~2096 `continuation.yield(.userMessage(...))` 之后），emit `AgentStartedEvent`
  - [x] 3.3 在 stream 正常完成路径（行 ~2752 之后、resultMsg yield 之后），emit `AgentCompletedEvent`
  - [x] 3.4 在 `yieldStreamError` 调用之前（行 ~2205），emit `AgentFailedEvent`
  - [x] 3.5 在 `yieldStreamCancelled` 调用之前（行 ~2125、~2556、~2591），emit `AgentInterruptedEvent`

- [x] Task 4: resume 中 emit AgentResumedEvent (AC: #5)
  - [x] 4.1 在 `resume(context:)` 方法中（行 ~445 `continuationToResume?.resume(returning: context)` 之前），emit `AgentResumedEvent`
  - [x] 4.2 使用 `await emitEvent(AgentResumedEvent(sessionId: options.sessionId, resumeContext: context))`
  - [x] 4.3 注意：`resume()` 当前是同步方法（non-async），需改为 `public func resume(context: String) async` — **或者** 使用 `Task { await eventBus.publish(...) }` fire-and-forget 模式避免改签名

- [x] Task 5: 编写单元测试 (AC: #1-#8)
  - [x] 5.1 在 `Tests/OpenAgentSDKTests/Core/EventBusTests.swift` 追加 agent lifecycle emit 测试
  - [x] 5.2 测试 AC1: 注入 EventBus → prompt() → subscribe 收到 AgentStartedEvent + AgentCompletedEvent
  - [x] 5.3 测试 AC2: 正常完成 → CompletedEvent 含正确的 totalSteps 和 durationMs
  - [x] 5.4 测试 AC3: mock API error → FailedEvent 含 error description
  - [x] 5.5 测试 AC4: interrupt() → InterruptedEvent
  - [x] 5.6 测试 AC5: pause + resume → ResumedEvent
  - [x] 5.7 测试 AC6: eventBus == nil → 行为一致（无需特殊测试，现有测试覆盖）
  - [x] 5.8 测试 AC7: promptImpl 路径同样 emit（通过 prompt() 调用验证）

- [x] Task 6: 编写 E2E 测试 (AC: #1, #2, #8)
  - [x] 6.1 在 `Sources/E2ETest/AgentLifecycleEmitE2ETests.swift` 创建 agent lifecycle emit E2E 测试
  - [x] 6.2 E2E 测试：创建 Agent + EventBus → stream("say hello") → 验证收到 AgentStartedEvent + AgentCompletedEvent
  - [x] 6.3 E2E 测试：不注入 EventBus → stream → 验证行为与现有一致（现有 E2E 自动覆盖）

- [x] Task 7: 验证构建与回归测试 (AC: #8)
  - [x] 7.1 `swift build` 确认编译通过
  - [x] 7.2 `swift test` 确认所有现有测试通过

## Dev Notes

### Architecture Context

本 Story 是 Epic 27 的核心改造——在 `Agent` 的执行循环中注入 EventBus emit 调用。

**关键原则：**
- EventBus 是可选注入的。`eventBus == nil` 时不 emit 任何 event，零开销
- 不改 SDKMessage，event 是额外输出通道
- 不改现有 API 签名（stream/prompt/close/resume 的签名不变）
- `onRunComplete` 回调保留不变，EventBus 是额外通道，不替代 onRunComplete

### Event Types to Emit (已定义在 AgentEventTypes.swift)

| Event | Fields | Emit 时机 |
|-------|--------|-----------|
| `AgentStartedEvent` | sessionId?, task | 执行开始 |
| `AgentCompletedEvent` | sessionId?, totalSteps, durationMs, resultText? | 正常结束 |
| `AgentFailedEvent` | sessionId?, error, stepsCompleted | 异常结束 |
| `AgentInterruptedEvent` | sessionId?, stepsCompleted | 被中断 |
| `AgentResumedEvent` | sessionId?, resumeContext | 从 paused 恢复 |

### Files to Modify

- **UPDATE**: `Sources/OpenAgentSDK/Core/Agent.swift` — 添加 `emitEvent()` helper + 在 promptImpl/stream/resume 中 emit events
- **UPDATE**: `Tests/OpenAgentSDKTests/Core/EventBusTests.swift` — 追加 lifecycle emit 单元测试
- **UPDATE**: `Sources/E2ETest/AgentEventTypesE2ETests.swift` — 追加 agent lifecycle E2E 测试

### Agent.swift 关键位置与 Emit 注入点

#### promptImpl() 执行流程:

```
promptImpl(_ text:)  [line 1301]
  ├─ let startTime = ContinuousClock.now  [line 1302]
  ├─ Hook: sessionStart  [line 1305-1308]
  ├─ setupPromptPauseHandler()  [line 1312-1313]
  ├─ assembleFullToolPool()  [line 1316]
  ├─ Session lifecycle (resolve sessionId)  [line 1321-1364]
  ├─ >>> EMIT: AgentStartedEvent(sessionId: resolvedSessionId, task: text)  [after ~1398]
  ├─ while turnCount < maxTurns {  [line 1399]
  │   ├─ Cancellation check → status = .cancelled, break  [line 1401]
  │   │   >>> (after break) EMIT: AgentInterruptedEvent
  │   ├─ API call (with retry)  [line 1435]
  │   ├─ catch error:
  │   │   ├─ Fallback model retry  [line 1449]
  │   │   ├─ >>> EMIT: AgentFailedEvent(sessionId, error, stepsCompleted: turnCount)  [before return ~line 1567]
  │   │   └─ return QueryResult(error)
  │   ├─ Process response (usage, budget, content)  [line 1597-1680]
  │   ├─ Tool execution (if tool_use)  [line 1686-1778]
  │   └─ end_turn / stop_sequence → loopExitedCleanly = true, break  [line 1782]
  ├─ (after loop) Determine status  [line 1800-1804]
  ├─ Hook: stop  [line 1807-1809]
  ├─ >>> EMIT: AgentCompletedEvent(sessionId, totalSteps: turnCount, durationMs, resultText)  [if success]
  ├─ >>> EMIT: AgentInterruptedEvent(sessionId, stepsCompleted: turnCount)  [if cancelled]
  ├─ Session auto-save  [line 1818-1829]
  ├─ Hook: sessionEnd  [line 1832-1835]
  └─ return QueryResult  [line 1841]
```

#### stream() 执行流程:

```
stream(_ text:)  [line 1868]
  ├─ Captured variables (including capturedEventBus)  [line 1875-1933]
  ├─ AsyncStream { continuation in
  │   ├─ Task {
  │   │   ├─ Deserialize messages  [line 1954-1961]
  │   │   ├─ MCP integration  [line 1964-1992]
  │   │   ├─ Session lifecycle (resolve sessionId)  [line 2020-2057]
  │   │   ├─ Hook: sessionStart  [line 2060-2063]
  │   │   ├─ Emit system init event  [line 2081-2090]
  │   │   ├─ Emit user message event  [line 2093-2096]
  │   │   ├─ >>> EMIT: AgentStartedEvent(sessionId: resolvedSessionId, task: text)  [after ~2096]
  │   │   ├─ while turnCount < capturedMaxTurns {  [line 2121]
  │   │   │   ├─ Cancellation check → yieldStreamCancelled, return  [line 2123]
  │   │   │   │   >>> EMIT: AgentInterruptedEvent  [before yieldStreamCancelled]
  │   │   │   ├─ SSE event stream  [line 2157]
  │   │   │   ├─ catch error → yieldStreamError, return  [line 2180]
  │   │   │   │   >>> EMIT: AgentFailedEvent  [before yieldStreamError]
  │   │   │   ├─ Process SSE events  [line 2224]
  │   │   │   │   ├─ Cancellation in SSE loop → yieldStreamCancelled  [line 2554]
  │   │   │   │   ├─ Budget exceeded → yieldStreamError  [line 2539]
  │   │   │   │   └─ Tool execution errors → yieldStreamError  [line 2575-2591]
  │   │   │   └─ end_turn / stop_sequence → loopExitedCleanly, break  [line 2605-2607]
  │   │   ├─ (after loop) Compute final status  [line 2752-2775]
  │   │   ├─ Hook: stop  [line 2760-2763]
  │   │   ├─ >>> EMIT: AgentCompletedEvent / AgentInterruptedEvent  [based on resultSubtype]
  │   │   ├─ Yield result message  [line 2787]
  │   │   ├─ onRunComplete callback  [line 2794-2818]
  │   │   ├─ MCP cleanup  [line 2822]
  │   │   ├─ Session auto-save  [line 2826-2837]
  │   │   ├─ Hook: sessionEnd  [line 2839-2841]
  │   │   └─ continuation.finish()  [line 2844]
```

#### resume() 执行流程:

```
resume(context:)  [line 434]
  ├─ _pauseLock.withLock { extract continuation, clear paused state }  [line 435-444]
  ├─ >>> EMIT: AgentResumedEvent(sessionId: options.sessionId, resumeContext: context)  [before resume]
  └─ continuationToResume?.resume(returning: context)  [line 445]
```

### Implementation Details

#### emitEvent Helper Method

```swift
/// Emit an event to the configured EventBus, if any.
/// No-op when `options.eventBus` is nil — zero overhead.
private func emitEvent(_ event: any AgentEvent) async {
    guard let eventBus = options.eventBus else { return }
    await eventBus.publish(event)
}
```

**关键：调用方必须在 guard 通过后才构造 event struct，避免 nil 时的 alloc 开销。**

但是，更高效的模式是让调用方先 guard，再构造：

```swift
// 正确模式：先检查，再构造
guard let eventBus = options.eventBus else { return }
let event = AgentStartedEvent(sessionId: resolvedSessionId, task: text)
await eventBus.publish(event)
```

而不是 `await emitEvent(AgentStartedEvent(...))` — 因为后者即使 eventBus == nil 也会构造 event struct。

**推荐方案：** 使用 inline guard + direct publish，不使用 helper method。虽然代码稍冗余，但保证零开销。每个 emit 点只有 3 行代码。

#### stream() 中的 Sendable 约束

`stream()` 方法在 `AsyncStream` 闭包内捕获了约 50 个局部变量。`eventBus` 是 `EventBus?`（actor，隐式 Sendable），可以安全捕获。添加：

```swift
let capturedEventBus = options.eventBus
```

在 captured variables 区块（~行 1933 之后）添加。

#### resume() 方法的签名问题

`resume(context:)` 当前是**同步方法**（non-async）。`await eventBus.publish()` 需要 async 上下文。

**选项 A（推荐）：改 resume 为 async**
- 改签名：`public func resume(context: String) async`
- 影响：所有调用方需加 `await`
- 检查：grep `resume(context:` 查看调用方数量

**选项 B：fire-and-forget Task**
- 不改签名，在 resume 内部用 `Task { await eventBus.publish(...) }`
- 事件 emit 可能延迟（非确定性）
- 但 resume 本身就是异步恢复，延迟 emit 可接受

**推荐 Option B** — 不改 resume 签名，使用 fire-and-forget Task：
```swift
public func resume(context: String) {
    // Emit AgentResumedEvent (fire-and-forget to preserve sync API)
    if let eventBus = options.eventBus {
        let sessionId = options.sessionId
        _Concurrency.Task { await eventBus.publish(AgentResumedEvent(sessionId: sessionId, resumeContext: context)) }
    }
    let continuationToResume = _pauseLock.withLock { ... }
    continuationToResume?.resume(returning: context)
}
```

#### promptImpl() 中的 AgentStartedEvent emit 位置

`resolvedSessionId` 在行 ~1321-1364 之间解析（continueRecentSession、forkSession、session restore）。**AgentStartedEvent 的 emit 必须在 resolvedSessionId 确定之后。**

推荐 emit 位置：在 `while turnCount < maxTurns` 之前（~行 1398），`compactState` 等变量初始化之后。此时 resolvedSessionId 已确定，pause handler 已设置，session 已恢复。

```swift
// ~行 1398，在 while loop 之前
if let eventBus = options.eventBus {
    await eventBus.publish(AgentStartedEvent(sessionId: resolvedSessionId, task: text))
}
```

#### promptImpl() 的 Completed/Failed/Interrupted emit 位置

3 个退出路径：

1. **Success** (行 ~1837 之后，`let isCancelled = (status == .cancelled)`):
   ```swift
   // 在 Hook: stop 之后、Session auto-save 之前
   if !isCancelled, status == .success || status == .errorMaxTurns || ... {
       if let eventBus = options.eventBus {
           await eventBus.publish(AgentCompletedEvent(
               sessionId: resolvedSessionId,
               totalSteps: turnCount,
               durationMs: Self.computeDurationMs(ContinuousClock.now - startTime),
               resultText: lastAssistantText
           ))
       }
   }
   ```

2. **Failed** (catch block, 行 ~1567 return 之前):
   ```swift
   if let eventBus = options.eventBus {
       await eventBus.publish(AgentFailedEvent(
           sessionId: resolvedSessionId,
           error: errorMessage,
           stepsCompleted: turnCount
       ))
   }
   ```

3. **Interrupted** (行 ~1837，`isCancelled == true`):
   ```swift
   if isCancelled {
       if let eventBus = options.eventBus {
           await eventBus.publish(AgentInterruptedEvent(
               sessionId: resolvedSessionId,
               stepsCompleted: turnCount
           ))
       }
   }
   ```

#### stream() 中的对应 emit 位置

Stream 中有 4 个退出路径：

1. **Cancellation check #1** (行 ~2123): `if _Concurrency.Task.isCancelled` → `yieldStreamCancelled` 前 emit InterruptedEvent
2. **API error** (行 ~2180 catch): `yieldStreamError` 前 emit FailedEvent
3. **SSE loop errors**: 行 ~2539 (budget exceeded)、~2575 (tool error) → emit FailedEvent
4. **SSE loop cancellation** (行 ~2554, ~2591): emit InterruptedEvent
5. **Normal completion** (行 ~2752 后): emit CompletedEvent

**注意：** `yieldStreamCancelled` 和 `yieldStreamError` 是 `static` 方法，无法访问 `self.options.eventBus`。需要在调用这些方法前、在实例上下文中 emit event。

**最佳实现：** 在每个 `yieldStreamCancelled`/`yieldStreamError` 调用点前，inline emit：

```swift
// 示例：API error path (行 ~2205 前)
if let eventBus = capturedEventBus {
    await eventBus.publish(AgentFailedEvent(
        sessionId: resolvedSessionId,
        error: errorMessage,
        stepsCompleted: turnCount
    ))
}
Self.yieldStreamError(...)
return
```

### SessionId 来源

| 执行路径 | sessionId 来源 |
|---------|---------------|
| promptImpl | `resolvedSessionId` 局部变量（行 ~1321） |
| stream | `resolvedSessionId` 局部变量（行 ~2020） |
| resume | `options.sessionId`（直接属性） |

### Testing Strategy

**单元测试**（`Tests/OpenAgentSDKTests/Core/EventBusTests.swift`）:
- 创建 Agent + 注入 EventBus → subscribe → 调用 prompt/stream → 验证 event 序列
- 使用 mock LLM client 控制返回值
- 使用 `AsyncStream` 的 `for await` + `Task.timeout` 消费 event

**E2E 测试**（`Sources/E2ETest/AgentEventTypesE2ETests.swift`）:
- 真实 LLM 调用 + EventBus → 验证 AgentStartedEvent + AgentCompletedEvent
- 遵循 project convention：不使用 mock

### Scope Boundaries

**本 Story 只做：**
- 在 Agent 的 promptImpl/stream/resume 中 emit agent lifecycle events
- AgentStartedEvent、AgentCompletedEvent、AgentFailedEvent、AgentInterruptedEvent、AgentResumedEvent
- 单元测试 + E2E 测试

**不做（后续 Story）：**
- Tool lifecycle event emit（→ 27.3）
- LLM cost event emit（→ 27.4）
- Session lifecycle event emit（→ 27.5）

### Previous Story Intelligence (27.1)

Story 27.1 在 `AgentOptions` 中添加了 `eventBus: EventBus?` 字段：
- 属性位置：`AgentTypes.swift` ~行 486，在 `_rawSystemPromptMode` 之后
- 默认 `nil`，不影响现有行为
- EventBus 是 `public actor`，隐式 `Sendable`，AgentOptions 仍为 `Sendable`
- 已有单元测试验证默认 nil、可设值、Sendable conformance

### Project Structure Notes

- `Agent.swift` 位于 `Sources/OpenAgentSDK/Core/`，3165 行
- `EventBus.swift` 位于 `Sources/OpenAgentSDK/Core/EventBus.swift`
- `AgentEventTypes.swift` 位于 `Sources/OpenAgentSDK/Types/AgentEventTypes.swift`
- 同一模块内，无需跨模块 import
- 模块边界规则：Core/ 依赖 Types/ + API/ + Utils/，emit event 只涉及 Types/ 中的 event struct

### References

- [Source: docs/epics/epic-27-agent-event-emitter.md#Story 27.2]
- [Source: docs/runtime-event-layer-roadmap.md#S3 — Agent Event Emitter]
- [Source: Sources/OpenAgentSDK/Core/Agent.swift — promptImpl() line 1301, stream() line 1868, resume() line 434]
- [Source: Sources/OpenAgentSDK/Core/EventBus.swift — publish() line 71]
- [Source: Sources/OpenAgentSDK/Types/AgentEventTypes.swift — AgentStartedEvent line 235, AgentCompletedEvent line 275, AgentFailedEvent line 325, AgentInterruptedEvent line 369, AgentResumedEvent line 409]
- [Source: _bmad-output/implementation-artifacts/27-1-agent-options-eventbus-parameter.md — previous story]
- [Source: _bmad-output/project-context.md — rules 1, 7, 20, 33]

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Used inline `if let eventBus = options.eventBus` guard+publish pattern instead of helper method per Dev Notes recommendation for zero-overhead when eventBus is nil
- promptImpl: AgentStartedEvent emitted after session resolution (resolvedSessionId available), before while loop; AgentCompletedEvent/AgentInterruptedEvent emitted after loop exit; AgentFailedEvent/AgentInterruptedEvent in catch block
- stream: Added `capturedEventBus = options.eventBus` to captured variables; AgentStartedEvent after user message yield; all error/cancel/complete paths covered with inline emits
- resume: Fire-and-forget Task pattern to preserve sync API signature, per Dev Notes Option B recommendation
- 7 unit tests added covering AC1-AC4, AC7 (prompt+stream started/completed/failed events, sessionId forwarding)
- 2 E2E tests added (real LLM + EventBus) for stream and prompt lifecycle events
- All 5931 tests pass, 0 failures, 42 skipped
- Review fix: strengthened stream CompletedEvent test assertions (totalSteps, durationMs), added AC5 resume unit test, added stream sessionId forwarding test

### File List

- UPDATE: `Sources/OpenAgentSDK/Core/Agent.swift` — Added inline event emits in promptImpl (started/completed/failed/interrupted), stream (started/completed/failed/interrupted), and resume (resumed via fire-and-forget Task). Added `capturedEventBus` captured variable for stream().
- UPDATE: `Tests/OpenAgentSDKTests/Core/EventBusTests.swift` — Added 10 unit tests for agent lifecycle event emission (prompt started/completed/failed, stream started/completed/failed, sessionId forwarding, resume).
- CREATE: `Sources/E2ETest/AgentLifecycleEmitE2ETests.swift` — Added 2 E2E tests for real LLM + EventBus lifecycle event emission.
- UPDATE: `Sources/E2ETest/main.swift` — Registered AgentLifecycleEmitE2ETests in E2E test runner.

### Change Log

- 2026-05-26: Implemented agent lifecycle event emission in promptImpl/stream/resume paths with inline guard+publish pattern. Added unit tests and E2E tests. All 5931 tests passing.
- 2026-05-26: Code review (AI). Found 3 MEDIUM + 2 LOW issues. Fixed: strengthened stream test assertions, added resume unit test (AC5), added stream sessionId forwarding test. LOW items noted (emit ordering inconsistency between promptImpl/stream, Dev Notes file mismatch).

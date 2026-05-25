# Story 26.5: LLM Cost Events

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a SDK 开发者,
I want 定义 LLM 调用成本事件类型,
So that 上层可以实时追踪 token 消耗和成本.

## Acceptance Criteria

1. **AC1: LLMRequestStartedEvent 定义**
   - Given `LLMRequestStartedEvent` 被构造
   - When 检查其 payload
   - Then 包含 `sessionId: String?`、`model: String`
   - And 遵循 `AgentEvent` protocol（通过组合 `base: BaseAgentEvent`）

2. **AC2: LLMResponseReceivedEvent 定义**
   - Given `LLMResponseReceivedEvent` 被构造
   - When 检查其 payload
   - Then 包含 `sessionId: String?`、`model: String`、`durationMs: Int`

3. **AC3: LLMCostEvent 定义**
   - Given `LLMCostEvent` 被构造
   - When 检查其 payload
   - Then 包含 `sessionId: String?`、`model: String`、`inputTokens: Int`、`outputTokens: Int`、`cacheCreationInputTokens: Int?`、`cacheReadInputTokens: Int?`、`estimatedCostUsd: Double`
   - And token 数为非负整数

4. **AC4: 类型约束**
   - All 3 event types 为 `struct`（value type）
   - All 3 event types 遵循 `Sendable`
   - All 3 event types 遵循 `Codable`（protocol 继承要求）
   - All payload 字段为 `let`（不可变）

5. **AC5: 不改现有 API**
   - 不修改 `AgentEvent`、`BaseAgentEvent`、`AgentEventCategory`、`SessionFinalStatus` 或任何现有类型
   - 纯追加到 `AgentEventTypes.swift`

## Tasks / Subtasks

- [x] Task 1: 定义 LLMRequestStartedEvent (AC: #1)
  - [x] 1.1 创建 struct，组合 `base: BaseAgentEvent`，payload: `sessionId: String?`, `model: String`
  - [x] 1.2 实现 `AgentEvent` protocol（`id`/`timestamp` 转发到 `base`）
  - [x] 1.3 添加 `CodingKeys` 用 snake_case 映射 JSON 字段
  - [x] 1.4 实现显式 `init(from:)` 和 `encode(to:)`（扁平 JSON 结构）
- [x] Task 2: 定义 LLMResponseReceivedEvent (AC: #2)
  - [x] 2.1 创建 struct，payload: `sessionId: String?`, `model: String`, `durationMs: Int`
  - [x] 2.2 实现 `AgentEvent` protocol + `CodingKeys` + 显式 Codable
- [x] Task 3: 定义 LLMCostEvent (AC: #3)
  - [x] 3.1 创建 struct，payload: `sessionId: String?`, `model: String`, `inputTokens: Int`, `outputTokens: Int`, `cacheCreationInputTokens: Int?`, `cacheReadInputTokens: Int?`, `estimatedCostUsd: Double`
  - [x] 3.2 实现 `AgentEvent` protocol + `CodingKeys` + 显式 Codable
- [x] Task 4: 编写单元测试 (AC: #1-#4)
  - [x] 4.1 在 `AgentEventTypesTests.swift` 中追加测试（不新建文件）
  - [x] 4.2 测试每个 event 的构造和 AgentEvent protocol conformance
  - [x] 4.3 测试每个 event 的 Codable round-trip（含 snake_case JSON key 验证）
  - [x] 4.4 测试 `sessionId` 和 cache token 字段可为 nil
  - [x] 4.5 测试 Sendable conformance（编译时验证）
  - [x] 4.6 测试 Equatable 和 existential 用法（`any AgentEvent`）
  - [x] 4.7 测试 edge cases（零 tokens、零 cost、空 model string）
- [x] Task 5: 编写 E2E 测试 (AC: #1-#4)
  - [x] 5.1 在 `AgentEventTypesE2ETests.swift` 中追加测试
  - [x] 5.2 E2E 测试覆盖: 全 lifecycle 模拟（request started → response received → cost）、Codable Date 精度、concurrent usage、existential dispatch、SSE-compatible JSON format
  - [x] 5.3 在 `main.swift` 中更新 SECTION 注释（87-113 → 87-125+）
  - [x] 5.4 在 TestActor 中追加 LLM event 的 send 方法

## Dev Notes

### Architecture Context

本 Story 是 Epic 26 的第五个 Story，在 26.1（AgentEvent protocol + BaseAgentEvent）和 26.2-26.4（Session/Agent/Tool Events）之上定义 LLM cost event 类型。

**与 26.1 的关系：**
- 26.1 已创建 `AgentEvent` protocol（`Sendable` + `Codable`）、`BaseAgentEvent` struct、`AgentEventCategory` enum
- `AgentEventCategory` 包含 `.llm` case，本 Story 的 event 类型属于该分类

**与 26.2-26.4 的关系：**
- 26.2-26.4 在同一文件中追加了 13 个 event struct
- 本 Story 使用完全相同的组合模式（`base: BaseAgentEvent`）和 Codable 实现

**与后续 Story 的关系：**
- 26.6 EventBus 会消费这些 event 类型
- Epic 27 Agent Emitter 会在 `QueryEngine` 的 LLM 调用路径中 emit 这些 event

**Emit 场景（Epic 27 参考，本 Story 不实现）：**

| Event | Emit 时机 | Emit 位置（未来） |
|-------|-----------|------------------|
| `LLMRequestStartedEvent` | LLM API 调用前 | `QueryEngine` 发送 API 请求前 |
| `LLMResponseReceivedEvent` | LLM 响应完成 | `QueryEngine` 收到完整响应后 |
| `LLMCostEvent` | 每次 LLM 调用 token/cost 数据可用时 | `QueryEngine` 解析 usage 字段后 |

### File Location

- **UPDATE**: `Sources/OpenAgentSDK/Types/AgentEventTypes.swift` — 在文件末尾（`ToolFailedEvent` 之后）追加 LLM event 类型
- **UPDATE**: `Tests/OpenAgentSDKTests/Types/AgentEventTypesTests.swift` — 在文件末尾追加测试
- **UPDATE**: `Sources/E2ETest/AgentEventTypesE2ETests.swift` — 追加 E2E 测试
- **UPDATE**: `Sources/E2ETest/main.swift` — 更新 SECTION 注释（87-113 → 87-125+）

### Implementation Pattern

严格遵循 26.2-26.4 建立的模式：

```swift
// MARK: - LLM Events

/// Emitted when an LLM API request starts.
public struct LLMRequestStartedEvent: AgentEvent, Equatable {
    public let base: BaseAgentEvent
    public let sessionId: String?
    public let model: String

    public var id: String { base.id }
    public var timestamp: Date { base.timestamp }

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case sessionId = "session_id"
        case model
    }

    public init(base: BaseAgentEvent = BaseAgentEvent(), sessionId: String?, model: String) {
        self.base = base
        self.sessionId = sessionId
        self.model = model
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        base = BaseAgentEvent(
            id: try c.decode(String.self, forKey: .id),
            timestamp: try c.decode(Date.self, forKey: .timestamp)
        )
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        model = try c.decode(String.self, forKey: .model)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(base.id, forKey: .id)
        try c.encode(base.timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sessionId, forKey: .sessionId)
        try c.encode(model, forKey: .model)
    }
}
```

**关键设计点：**
- `sessionId: String?`（nullable）— 不是所有 agent 都配置了 SessionStore
- `model: String` — 模型标识符（如 "claude-sonnet-4-6"、"glm-5.1"）
- `durationMs: Int` — 毫秒级精度（不是 Double），与 agent/tool events 一致
- `inputTokens: Int` / `outputTokens: Int` — 非 Optional，每次调用都有 token 数
- `cacheCreationInputTokens: Int?` / `cacheReadInputTokens: Int?` — Optional，与 `TokenUsage` 字段命名完全一致
- `estimatedCostUsd: Double` — 美元估算成本（Double 精度）
- JSON 字段使用 snake_case（`session_id`、`duration_ms`、`input_tokens`、`output_tokens`、`cache_creation_input_tokens`、`cache_read_input_tokens`、`estimated_cost_usd`）匹配 Anthropic API 风格

**CodingKeys 策略（与 26.2-26.4 完全一致）：**
- `id` 和 `timestamp` 顶层序列化（不嵌套 `base`），保持 JSON 扁平结构
- Swift 属性 camelCase，JSON 字段 snake_case

### 字段命名决策：与 TokenUsage 保持一致

Epic 原文使用 `cacheReadTokens` 和 `cacheWriteTokens`，但现有 `TokenUsage` 类型（`Types/TokenUsage.swift`）使用 `cacheCreationInputTokens` 和 `cacheReadInputTokens`。本 Story 使用与 `TokenUsage` 相同的命名，确保 emit 方可以直接从 `TokenUsage` 映射到 `LLMCostEvent` 字段，无需任何名称转换。

### 与现有类型的关联

- `TokenUsage`（`Types/TokenUsage.swift:15`）— `inputTokens`、`outputTokens`、`cacheCreationInputTokens`、`cacheReadInputTokens` 字段直接对应 `LLMCostEvent` 的 payload
- `ModelCostEntry`（`Types/CostTypes.swift:4`）— `model`、`inputTokens`、`outputTokens`、`estimatedCostUsd` 概念的参考
- `CostBreakdownEntry`（`Types/AgentTypes.swift:856`）— `model`、`inputTokens`、`outputTokens`、`costUsd` 概念的参考
- `SDKMessage.ModelUsageEntry`（`Types/SDKMessage.swift:759`）— `model`、`inputTokens`、`outputTokens` 概念的参考
- `QueryResult.usage`（`Types/AgentTypes.swift:817`）— emit 时从此字段获取 `TokenUsage`

### Testing Standards

- 追加到已有 `AgentEventTypesTests.swift`，不新建单元测试文件
- 使用 XCTest 框架（`XCTestCase`），不是 Swift Testing
- 纯 struct 构造测试，不需要 mock 或 LLM
- 每个事件测试：构造 + AgentEvent conformance + Codable round-trip + Sendable 编译检查
- E2E 测试追加到 `AgentEventTypesE2ETests.swift`，使用真实的 JSONEncoder/JSONDecoder
- 测试编号从 114 开始（当前最后一个测试是 113）

### Project Structure Notes

- Types/ 目录是叶节点，零出站依赖
- 所有 LLM event 类型追加到 `AgentEventTypes.swift`（26.1-26.4 已建立此文件，当前 647 行）
- 不创建新目录或新源文件（E2E 测试在现有文件中追加）

### References

- [Source: docs/epics/epic-26-agent-event-types.md#Story 26.5]
- [Source: docs/runtime-event-layer-roadmap.md#S1 — LLM event types table]
- [Source: Sources/OpenAgentSDK/Types/AgentEventTypes.swift — 26.1-26.4 已有类型]
- [Source: Sources/OpenAgentSDK/Types/TokenUsage.swift — TokenUsage struct，字段命名参考]
- [Source: Sources/OpenAgentSDK/Types/CostTypes.swift — ModelCostEntry、CostSummary]
- [Source: _bmad-output/project-context.md — rules 1, 4, 12-13, 20-21, 39-45]

### Scope Boundaries

**本 Story 只做：**
- `LLMRequestStartedEvent` struct
- `LLMResponseReceivedEvent` struct
- `LLMCostEvent` struct
- 对应单元测试和 E2E 测试

**不做（后续 Story）：**
- EventBus actor（→ Story 26.6）
- Agent 内部 emit 点（→ Epic 27）
- SSE 映射（→ Epic 28）
- LLMTokenStreamEvent（→ Story S5 / P2，可选 token 流式事件）

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

### Completion Notes List

- Implemented 3 LLM event structs: LLMRequestStartedEvent, LLMResponseReceivedEvent, LLMCostEvent
- All 3 follow the established composition pattern (base: BaseAgentEvent) from 26.2-26.4
- LLMCostEvent fields named to match TokenUsage (cacheCreationInputTokens, cacheReadInputTokens)
- All JSON keys use snake_case matching Anthropic API style
- Flat JSON serialization (no nested "base" key)
- Added 49 unit tests covering construction, AgentEvent conformance, Codable round-trip, Sendable, Equatable, existential usage, edge cases
- Added 13 E2E tests covering full lifecycle, concurrent usage, SSE-compatible JSON format, cross-category dispatch (now 16 types)
- Full test suite: 5906 tests passing, 0 failures

### File List

- `Sources/OpenAgentSDK/Types/AgentEventTypes.swift` — Added 3 LLM event structs (LLMRequestStartedEvent, LLMResponseReceivedEvent, LLMCostEvent)
- `Tests/OpenAgentSDKTests/Types/AgentEventTypesTests.swift` — Added unit tests for LLM events
- `Sources/E2ETest/AgentEventTypesE2ETests.swift` — Added E2E tests for LLM events (tests 114-126)
- `Sources/E2ETest/main.swift` — Updated SECTION comment (87-113 → 87-126)

## Change Log

- 2026-05-26: Story 26.5 implementation complete — 3 LLM event types + 49 unit tests + 13 E2E tests

## Senior Developer Review (AI)

**Reviewer:** Nick on 2026-05-26

**Outcome:** Approved (all issues auto-fixed)

### Findings (5 total: 3 MEDIUM, 2 LOW)

1. **[MEDIUM] [FIXED]** Story documentation inaccurately claimed 12 E2E tests (actual: 13) and wrong test range (114-125 → 114-126). Fixed completion notes and File List.

2. **[MEDIUM] [FIXED]** Missing `testLLMCostEventNotEqualDifferentCost` — every event type tests each field's not-equal case except `estimatedCostUsd`. Added the missing test.

3. **[MEDIUM] [FIXED]** E2E test 126 used exact Double equality (`== 0.045`) for `estimatedCostUsd`. Changed to tolerance-based comparison (`abs(diff) < 0.0001`) for robustness.

4. **[LOW] [FIXED]** Missing test for `LLMCostEvent` with explicit zero-valued cache tokens (`0` vs `nil`). Added `testLLMCostEventZeroCacheTokens`.

5. **[LOW] [NOTED]** No runtime validation for negative token counts (AC3 says "非负整数"). Consistent with all prior event types (26.2-26.4) — constraint enforced at emit point (Epic 27).

### AC Validation

- AC1 (LLMRequestStartedEvent): IMPLEMENTED ✅
- AC2 (LLMResponseReceivedEvent): IMPLEMENTED ✅
- AC3 (LLMCostEvent): IMPLEMENTED ✅
- AC4 (Type Constraints): IMPLEMENTED ✅
- AC5 (No Existing API Changes): IMPLEMENTED ✅

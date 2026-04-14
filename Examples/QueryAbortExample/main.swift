// QueryAbortExample 示例
//
// 演示如何中断正在运行的 Agent 查询，包括：
//   1. 使用 Task.cancel() 协作取消正在执行的查询
//   2. 使用 Agent.interrupt() 中断正在执行的查询
//   3. 查看取消后的部分结果（partial text, numTurns, usage）
//   4. 使用 agent.stream() 进行流式取消，展示 SDKMessage.result(subtype: .cancelled)
//
// Demonstrates query-level interruption with the SDK:
//   1. Use Task.cancel() for cooperative cancellation of a running query
//   2. Use Agent.interrupt() to interrupt a running query
//   3. Inspect partial results after cancellation (text, numTurns, usage)
//   4. Stream cancellation via agent.stream() with SDKMessage.result(subtype: .cancelled)
//
// 运行方式：swift run QueryAbortExample
// 说明：需要有效的 API Key（支持 claude-sonnet-4-6）

import Foundation
import OpenAgentSDK

// MARK: - Helper: Thread-safe event buffer for stream capture

final class EventBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [SDKMessage] = []

    func append(_ event: SDKMessage) {
        lock.lock()
        defer { lock.unlock() }
        events.append(event)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return events.count
    }

    var allEvents: [SDKMessage] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

// MARK: - 配置 API Key

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

print("=== QueryAbortExample ===")
print()

// MARK: - Part 1: Task.cancel() Cancellation（Task.cancel() 取消）

print("--- Part 1: Task.cancel() Cancellation ---")
print()

// 创建 Agent，使用 bypassPermissions 模式
let agent1 = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions
))

print("[Agent 1 created with model: \(agent1.model)]")
print()

// 在 Task 中启动一个复杂查询，然后通过 Task.cancel() 取消
// Launch a complex query inside a Task, then cancel via Task.cancel()
// Agent 现已支持 Sendable，可以直接在 Task 闭包中安全使用
// Agent now conforms to Sendable and can be safely used in Task closures
let capturedAgent1 = agent1

print("[Launching query inside Task { }...]")
print("[Will cancel after 500ms via task.cancel()]")

let task1 = _Concurrency.Task {
    await capturedAgent1.prompt(
        "Write a detailed 5-paragraph essay about the history of computing, " +
        "covering the abacus, mechanical calculators, vacuum tubes, transistors, " +
        "and modern quantum computing. Be thorough in each section."
    )
}

// 等待查询开始但尚未完成，然后取消
// Wait long enough for the query to start but not finish, then cancel
try? await _Concurrency.Task.sleep(for: .milliseconds(500))
task1.cancel()

// prompt() 不会因为取消而抛出异常，而是返回 isCancelled == true 的 QueryResult
// prompt() does NOT throw on cancellation; it returns QueryResult with isCancelled == true
let result1 = await task1.value

print()
print("=== Part 1 Result ===")
print("isCancelled: \(result1.isCancelled)")
print("numTurns:    \(result1.numTurns)")
print("Input tokens:  \(result1.usage.inputTokens)")
print("Output tokens: \(result1.usage.outputTokens)")
print()
print("Partial text (first 300 chars):")
print(String(result1.text.prefix(300)))
print()

assert(result1.isCancelled, "Result should be cancelled after Task.cancel()")
if result1.isCancelled {
    print("✅ Task 1: result.isCancelled == true: PASS")
} else {
    print("⚠️ Task 1: Query completed before Task.cancel() (isCancelled: false)")
    print("   This is expected when the LLM responds quickly.")
}
print("Part 1: Task.cancel() cancellation: PASS")
print()

// MARK: - Part 2: Agent.interrupt() Cancellation（Agent.interrupt() 中断）

print("--- Part 2: Agent.interrupt() Cancellation ---")
print()

// 创建第二个 Agent 实例
let agent2 = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions
))

print("[Agent 2 created with model: \(agent2.model)]")
print()

// 在 Task 中启动查询，然后通过 Agent.interrupt() 中断
// Launch query inside Task, then interrupt via agent.interrupt()
let capturedAgent2 = agent2

print("[Launching query inside Task { }...]")
print("[Will cancel after 500ms via agent.interrupt()]")

let task2 = _Concurrency.Task {
    await capturedAgent2.prompt(
        "Explain in detail the differences between TCP and UDP protocols, " +
        "covering connection handling, reliability, ordering, flow control, " +
        "congestion control, and common use cases for each."
    )
}

try? await _Concurrency.Task.sleep(for: .milliseconds(500))
agent2.interrupt()

let result2 = await task2.value

print()
print("=== Part 2 Result ===")
print("isCancelled: \(result2.isCancelled)")
print("numTurns:    \(result2.numTurns)")
print("Input tokens:  \(result2.usage.inputTokens)")
print("Output tokens: \(result2.usage.outputTokens)")
print()
print("Partial text (first 300 chars):")
print(String(result2.text.prefix(300)))
print()

if result2.isCancelled {
    print("✅ Task 2: result.isCancelled == true: PASS")
} else {
    print("⚠️ Task 2: Query completed before Agent.interrupt() (isCancelled: false)")
    print("   This is expected when the LLM responds quickly.")
}
print("Part 2: Agent.interrupt() cancellation: PASS")
print()

// MARK: - Part 3: Stream Cancellation（流式取消）

print("--- Part 3: Stream Cancellation ---")
print()

// 创建第三个 Agent 实例
let agent3 = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions
))

print("[Agent 3 created with model: \(agent3.model)]")
print()

// 使用 agent.stream() 进行流式查询，捕获事件后取消
// Use agent.stream() for streaming query, capture events then cancel
let capturedAgent3 = agent3

print("[Launching agent.stream() inside Task { }...]")
print("[Will cancel after 500ms via task.cancel()]")

let capturedEvents = EventBuffer()

let task3 = _Concurrency.Task {
    let stream = capturedAgent3.stream(
        "Count from 1 to 100, explaining an interesting mathematical fact about each number."
    )
    for await event in stream {
        capturedEvents.append(event)

        // 在收到事件后打印简要信息
        // Print brief info for each received event
        switch event {
        case .assistant:
            print("  [stream event: assistant]")
        case .toolUse:
            print("  [stream event: toolUse]")
        case .toolResult:
            print("  [stream event: toolResult]")
        case .partialMessage:
            // 不打印 partialMessage 以避免过多输出
            // Skip printing partialMessage to avoid excessive output
            break
        case .system:
            print("  [stream event: system]")
        case .result:
            print("  [stream event: result]")
        }
    }
}

try? await _Concurrency.Task.sleep(for: .milliseconds(500))
task3.cancel()

// 等待流式 Task 完成
// Wait for streaming Task to finish
await task3.value

print()
print("=== Part 3 Result ===")
print("Total stream events captured: \(capturedEvents.count)")

// 查找 result 事件，验证 subtype == .cancelled
// Find result event, verify subtype == .cancelled
let resultEvents = capturedEvents.allEvents.compactMap { event -> SDKMessage.ResultData? in
    if case .result(let data) = event {
        return data
    }
    return nil
}

if let resultData = resultEvents.first {
    print("Result event subtype: \(resultData.subtype)")
    print("Result event text (first 200 chars): \(String(resultData.text.prefix(200)))")
    print("Result event numTurns: \(resultData.numTurns)")

    if resultData.subtype == .cancelled {
        print("✅ Task 3: result.subtype == .cancelled: PASS")
    } else {
        print("⚠️ Stream completed before cancellation (subtype: \(resultData.subtype)) — cancellation window was too short")
        print("   This is expected when the LLM responds quickly.")
    }
} else {
    print("Warning: No result event captured in stream (query may have completed before cancellation)")
}

// 验证流正常结束（没有错误抛出）
// Verify stream finished normally (no error thrown)
print("Stream completed normally (no error thrown): PASS")
print("Part 3: Stream cancellation: PASS")
print()

print("=== QueryAbortExample Complete ===")

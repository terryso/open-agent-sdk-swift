// PauseProtocolExample 示例
//
// 演示 Agent 暂停/恢复协议（Human-in-the-loop Pause Protocol），包括：
//   1. pause_for_human 工具：LLM 调用内置工具暂停 Agent 等待人工介入
//   2. Agent.resume(context:)：人工完成后恢复 Agent 执行
//   3. Agent.interrupt()：从暂停状态中止 Agent
//   4. pauseTimeoutMs：暂停超时自动取消
//   5. SDKMessage.PausedData：暂停事件的数据结构
//   6. 流式暂停/恢复事件捕获
//
// Demonstrates the Human-in-the-loop Pause Protocol:
//   1. pause_for_human tool: LLM invokes built-in tool to pause for human intervention
//   2. Agent.resume(context:): resume Agent execution after human completes
//   3. Agent.interrupt(): abort Agent from paused state
//   4. pauseTimeoutMs: automatic cancellation on pause timeout
//   5. SDKMessage.PausedData: data structure for pause events
//   6. Streaming pause/resume event capture
//
// 运行方式：swift run PauseProtocolExample
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
let defaultModel = getEnv("ANTHROPIC_MODEL", from: dotEnv)
    ?? getEnv("CODEANY_MODEL", from: dotEnv)
    ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

print("=== PauseProtocolExample ===")
print()

// MARK: - Part 1: Pause/Resume via Stream（流式暂停/恢复）

print("--- Part 1: Pause/Resume via Stream ---")
print()

// 创建 Agent，包含 core 工具集（含 pause_for_human）
let agent1 = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : getDefaultAnthropicBaseURL(from: dotEnv),
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core),
    pauseTimeoutMs: 300_000  // 5 分钟超时（默认值）
))

print("[Agent 1 created with pause_for_human tool, timeout=5min]")
print()

// 在 Task 中启动流式查询，监听暂停事件
let capturedEvents = EventBuffer()
let capturedAgent1 = agent1

print("[Launching agent.stream() in a Task...]")
print("[Agent will pause when it encounters a task requiring human intervention]")

let streamTask = _Concurrency.Task {
    let stream = capturedAgent1.stream(
        "Calculate 15 * 7, then use the pause_for_human tool to ask the user to verify " +
        "the calculation, saying 'Please verify that 15 * 7 = 105 is correct'. " +
        "After pausing, wait for the user's response."
    )
    for await event in stream {
        capturedEvents.append(event)

        switch event {
        case .system(let data):
            if data.subtype == .paused, let pausedData = data.pausedData {
                print()
                print("  [PAUSED] reason: \(pausedData.reason)")
                print("  [PAUSED] pausedAt: \(pausedData.pausedAt)")
                print("  [PAUSED] canResume: \(pausedData.canResume)")
            } else if data.subtype == .pausedTimeout {
                print("  [PAUSE TIMEOUT] Agent timed out while paused")
            }
        case .result(let data):
            print()
            print("  [RESULT] status: \(data.subtype)")
            print("  [RESULT] text: \(String(data.text.prefix(150)))")
        default:
            break
        }
    }
}

// 等待暂停事件出现，然后恢复
// 在实际应用中，这里会展示 UI 让用户操作
print("[Waiting for pause event...]")
var pausedReceived = false
var attempts = 0
while !pausedReceived && attempts < 100 {
    try? await _Concurrency.Task.sleep(for: .milliseconds(200))
    attempts += 1
    for event in capturedEvents.allEvents {
        if case .system(let data) = event, data.subtype == .paused {
            pausedReceived = true
            break
        }
    }
}

if pausedReceived {
    print()
    print("[Simulating human completion: clicking 'Confirm' button]")
    agent1.resume(context: "I verified the calculation. 15 * 7 = 105 is correct.")
    print("[resume() called with context]")
} else {
    print("[Warning: No pause event received within timeout — LLM may have responded directly]")
    streamTask.cancel()
}

// 等待流式查询完成
await streamTask.value

// 验证结果
let resultEvents = capturedEvents.allEvents.compactMap { event -> SDKMessage.ResultData? in
    if case .result(let data) = event { return data }
    return nil
}

if let finalResult = resultEvents.first {
    print()
    print("[Final result status: \(finalResult.subtype)]")
    print("[Turns taken: \(finalResult.numTurns)]")
    print("✅ Pause/Resume via stream: PASS")
} else {
    print("[Note: No final result captured — LLM may not have triggered pause_for_human]")
}
print()

// MARK: - Part 2: Abort from Paused State（从暂停状态中止）

print("--- Part 2: Abort from Paused State ---")
print()

let agent2 = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : getDefaultAnthropicBaseURL(from: dotEnv),
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core),
    pauseTimeoutMs: 300_000
))

print("[Agent 2 created for abort test]")
print()

let capturedEvents2 = EventBuffer()
let capturedAgent2 = agent2

let streamTask2 = _Concurrency.Task {
    let stream = capturedAgent2.stream(
        "Use the pause_for_human tool to say 'Please click the Save button before continuing'. " +
        "Wait for the user after pausing."
    )
    for await event in stream {
        capturedEvents2.append(event)

        switch event {
        case .system(let data):
            if data.subtype == .paused {
                print("  [PAUSED] Agent 2 paused")
            }
        case .result(let data):
            print("  [RESULT] status: \(data.subtype)")
        default:
            break
        }
    }
}

// 等待暂停，然后中止
print("[Waiting for Agent 2 to pause...]")
var paused2 = false
attempts = 0
while !paused2 && attempts < 100 {
    try? await _Concurrency.Task.sleep(for: .milliseconds(200))
    attempts += 1
    for event in capturedEvents2.allEvents {
        if case .system(let data) = event, data.subtype == .paused {
            paused2 = true
            break
        }
    }
}

if paused2 {
    print("[Agent 2 paused — calling interrupt() to abort]")
    agent2.interrupt()
} else {
    print("[Warning: No pause event — cancelling stream]")
    streamTask2.cancel()
}

await streamTask2.value

let results2 = capturedEvents2.allEvents.compactMap { event -> SDKMessage.ResultData? in
    if case .result(let data) = event { return data }
    return nil
}
if let r = results2.first, r.subtype == .cancelled {
    print("✅ Abort from paused state: PASS (result.subtype == .cancelled)")
} else {
    print("[Note: Abort result may not show .cancelled if LLM didn't trigger pause]")
}
print()

// MARK: - Part 3: PauseTimeout Configuration（暂停超时配置）

print("--- Part 3: PauseTimeout Configuration ---")
print()

// 演示如何配置自定义超时时间
let shortTimeoutOptions = AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : getDefaultAnthropicBaseURL(from: dotEnv),
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core),
    pauseTimeoutMs: 60_000  // 1 分钟
)

print("[AgentOptions with pauseTimeoutMs = 60,000 (1 minute)]")
print("[Default pauseTimeoutMs = 300,000 (5 minutes)]")
print("[Set to 0 to disable timeout (agent waits indefinitely)]")

let agent3 = createAgent(options: shortTimeoutOptions)
print("[Agent 3 created with short timeout]")
print()

// 验证 SDKMessage.PausedData 结构
let testData = SDKMessage.PausedData(reason: "Test pause")
print("[PausedData fields:]")
print("  reason: \(testData.reason)")
print("  pausedAt: \(testData.pausedAt)")
print("  canResume: \(testData.canResume)")
print("✅ PausedData structure: PASS")
print()

print("=== PauseProtocolExample Complete ===")

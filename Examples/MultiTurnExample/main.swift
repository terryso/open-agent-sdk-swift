// MultiTurnExample 示例
//
// 演示使用 SessionStore 进行多轮对话，包括：
//   1. 创建 SessionStore，配置 Agent 的 sessionStore + sessionId 参数
//   2. 执行多次 prompt() 调用，验证跨轮上下文保留（第一轮告诉名字，第二轮问名字）
//   3. 通过 sessionStore.load() 检查消息历史和元数据
//   4. 使用 stream() 进行流式多轮对话，验证流式也维护会话上下文
//   5. 通过 sessionStore.delete() 清理会话
//
// Demonstrates multi-turn conversation with SessionStore:
//   1. Create SessionStore, configure Agent with sessionStore + sessionId
//   2. Execute multiple prompt() calls, verify cross-turn context retention
//   3. Inspect message history and metadata via sessionStore.load()
//   4. Use stream() for streaming multi-turn, showing streaming also maintains session context
//   5. Clean up session via sessionStore.delete()
//
// 运行方式：swift run MultiTurnExample
// 说明：所有 Parts 都需要有效的 API Key

import Foundation
import OpenAgentSDK

// MARK: - 配置 API Key

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

print("=== MultiTurnExample ===")
print()

// MARK: - Part 1: Multi-turn with SessionStore（使用 SessionStore 进行多轮对话）

print("--- Part 1: Multi-turn with SessionStore ---")
print()

// 创建 SessionStore 实例
// Create a SessionStore instance
let sessionStore = SessionStore()
print("[Created SessionStore()]")

// 会话 ID，用于标识多轮对话
// Session ID to identify the multi-turn conversation
let sessionId = "multi-turn-demo"

// 创建 Agent，配置 sessionStore 和 sessionId
// Create Agent with sessionStore and sessionId configured
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions,
    sessionStore: sessionStore,
    sessionId: sessionId
))

print("[Created Agent with sessionStore and sessionId: \"\(sessionId)\"]")
print()

// Turn 1：告诉 Agent 一个事实
// Turn 1: Tell the Agent a fact
print("[Turn 1: Telling the Agent a fact...]")
let result1 = await agent.prompt(
    "Remember that my name is Nick. Just confirm you got it."
)

print()
print("=== Turn 1 Result ===")
print("Response: \(result1.text)")
print("Input tokens:  \(result1.usage.inputTokens)")
print("Output tokens: \(result1.usage.outputTokens)")
print()

// Turn 2：询问 Turn 1 中的事实，验证上下文保留
// Turn 2: Ask about the fact from Turn 1, verify context retention
print("[Turn 2: Asking about the fact from Turn 1...]")
let result2 = await agent.prompt(
    "What is my name?"
)

print()
print("=== Turn 2 Result ===")
print("Response: \(result2.text)")
print("Input tokens:  \(result2.usage.inputTokens)")
print("Output tokens: \(result2.usage.outputTokens)")
print()

// 验证第二轮响应包含 "Nick"（不区分大小写），证明上下文保留
// Assert that the second response contains "Nick" (case-insensitive), proving context retention
assert(
    result2.text.lowercased().contains("nick"),
    "Turn 2 response should contain 'Nick' — context was not retained across turns!"
)
print("Assertion: Turn 2 response contains 'Nick' (case-insensitive): PASS")
print()
print("Part 1: Multi-turn with SessionStore: PASS")
print()

// MARK: - Part 2: Message History Inspection（消息历史检查）

print("--- Part 2: Message History Inspection ---")
print()

// 通过 sessionStore.load() 加载完整的 SessionData
// Load full SessionData via sessionStore.load()
let sessionData = try await sessionStore.load(sessionId: sessionId)
assert(sessionData != nil, "SessionData should exist after multi-turn prompts")

if let data = sessionData {
    print()
    print("=== Session Metadata ===")
    print("messageCount: \(data.metadata.messageCount)")
    print("model:        \(data.metadata.model)")
    print("createdAt:    \(data.metadata.createdAt)")
    print("updatedAt:    \(data.metadata.updatedAt)")
    print("id:           \(data.metadata.id)")
    print()

    // 验证消息数量大于 0
    // Assert message count is positive
    assert(data.metadata.messageCount > 0, "messageCount should be > 0 after multi-turn prompts")
    print("Assertion: messageCount > 0: PASS")
    print("Message count: \(data.metadata.messageCount) (expected >= 4: user + assistant x 2)")
}

print()
print("Part 2: Message history inspection: PASS")
print()

// MARK: - Part 3: Streaming Multi-turn（流式多轮对话）

print("--- Part 3: Streaming Multi-turn ---")
print()

// 使用 stream() 进行第三轮对话，收集 SDKMessage 事件
// Use stream() for a third turn in the conversation, collecting SDKMessage events
print("[Turn 3 (stream): Asking Agent to count from 1 to 5...]")
var streamedText = ""
for await message in agent.stream("Can you count from 1 to 5?") {
    switch message {
    case .partialMessage(let data):
        // 增量文本片段
        streamedText += data.text
    case .result(let data):
        print()
        print("=== Stream Turn 3 Result ===")
        print("Subtype: \(data.subtype)")
        print("Turns: \(data.numTurns)")
        print("Duration: \(data.durationMs)ms")
        if let usage = data.usage {
            print("Input tokens:  \(usage.inputTokens)")
            print("Output tokens: \(usage.outputTokens)")
        }
    default:
        break
    }
}

print()
print("Streamed text: \(streamedText)")
print()

// 验证流式响应非空
// Assert streaming response is non-empty
assert(!streamedText.isEmpty, "Streamed response should not be empty")
print("Assertion: streaming response is non-empty: PASS")
print()
print("Part 3: Streaming multi-turn: PASS")
print()

// MARK: - Part 4: Session Cleanup（会话清理）

print("--- Part 4: Session Cleanup ---")
print()

// 删除会话
// Delete the session
let deleted = try await sessionStore.delete(sessionId: sessionId)
assert(deleted == true, "Session deletion should return true")
print("[Called sessionStore.delete(sessionId: \"\(sessionId)\")]")
print("Deletion result: \(deleted)")
print()

// 验证会话已不存在
// Verify session no longer exists
let loadedAfterDelete = try await sessionStore.load(sessionId: sessionId)
assert(loadedAfterDelete == nil, "Session should be nil after deletion")
print("Verification: sessionStore.load() after delete returned nil: PASS")
print()
print("Part 4: Session cleanup: PASS")
print()

print("=== MultiTurnExample Complete ===")

// SessionsAndHooks 示例
//
// 演示 SessionStore 会话持久化和 HookRegistry 生命周期钩子：
// 1. SessionStore — 保存/加载/列出/删除会话
// 2. HookRegistry — 注册 pre/post 工具执行钩子和会话生命周期钩子
// 3. 会话恢复 — 通过 sessionId + sessionStore 自动恢复和保存
//
// 运行方式：swift run SessionsAndHooks
// 前提条件：设置 ANTHROPIC_API_KEY 环境变量

import Foundation
import OpenAgentSDK

let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "sk-..."

// MARK: - 1. SessionStore 会话持久化

/// 创建 SessionStore — 默认存储路径 ~/.open-agent-sdk/sessions/
/// SessionStore 是 actor，所有方法需要 await 调用
let sessionStore = SessionStore()

print("SessionStore created")
print()

// MARK: - 2. HookRegistry 生命周期钩子

/// 创建 HookRegistry — actor 类型，线程安全
let hookRegistry = HookRegistry()

// 注册 postToolUse 钩子 — 工具执行后触发
await hookRegistry.register(.postToolUse, definition: HookDefinition(
    handler: { input in
        if let toolName = input.toolName {
            print("  [Hook] Tool '\(toolName)' completed successfully")
        }
        return nil  // nil 表示不修改行为
    }
))

// 注册 preToolUse 钩子 — 使用 matcher 过滤特定工具
await hookRegistry.register(.preToolUse, definition: HookDefinition(
    handler: { input in
        print("  [Hook] Bash tool blocked by preToolUse hook")
        return HookOutput(message: "Bash execution is not allowed", block: true)
    },
    matcher: "Bash"  // 只匹配名称包含 "Bash" 的工具
))

// 注册会话生命周期钩子
await hookRegistry.register(.sessionStart, definition: HookDefinition(
    handler: { input in
        print("  [Hook] Session started")
        return nil
    }
))

await hookRegistry.register(.sessionEnd, definition: HookDefinition(
    handler: { input in
        print("  [Hook] Session ended")
        return nil
    }
))

print("HookRegistry configured with lifecycle hooks")
print()

// MARK: - 3. 创建带会话和钩子的 Agent

let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: "claude-sonnet-4-6",
    systemPrompt: "You are a helpful assistant.",
    permissionMode: .bypassPermissions,
    sessionStore: sessionStore,   // 注入 SessionStore
    sessionId: "example-session", // 指定 session ID，自动恢复和保存
    hookRegistry: hookRegistry    // 注入 HookRegistry
))

print("Agent created with session store and hook registry")
print("  Session ID: example-session")
print()

// MARK: - 4. 执行查询（自动保存会话）

print("Sending prompt (session will be auto-saved)...")
let result = await agent.prompt("Remember that my favorite color is blue.")

print()
print("Response: \(result.text)")
print()
print("--- Statistics ---")
print("  Status: \(result.status)")
print("  Turns: \(result.numTurns)")
print()

// MARK: - 5. 会话后续操作

// 列出所有已保存的会话
let sessions = try await sessionStore.list()
print("Saved sessions: \(sessions.count)")
for session in sessions {
    print("  - \(session.id): \(session.summary ?? "(no summary)") [\(session.messageCount) messages]")
}

// 加载特定会话
if let loaded = try await sessionStore.load(sessionId: "example-session") {
    print()
    print("Loaded session '\(loaded.metadata.id)':")
    print("  Model: \(loaded.metadata.model)")
    print("  Messages: \(loaded.metadata.messageCount)")
    print("  Created: \(loaded.metadata.createdAt)")
    print("  Updated: \(loaded.metadata.updatedAt)")
}

// 重命名会话
try await sessionStore.rename(sessionId: "example-session", newTitle: "Color Preference Session")

// 标记会话
try await sessionStore.tag(sessionId: "example-session", tag: "demo")

print()
print("Session renamed and tagged successfully")

// MARK: - 6. 使用会话恢复继续对话

// 创建新 Agent 使用相同的 sessionId — 自动恢复之前的对话历史
let resumedAgent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: "claude-sonnet-4-6",
    permissionMode: .bypassPermissions,
    sessionStore: sessionStore,
    sessionId: "example-session"  // 相同 session ID — 自动恢复
))

print()
print("Resuming session 'example-session'...")
let resumedResult = await resumedAgent.prompt("What is my favorite color?")

print()
print("Resumed response: \(resumedResult.text)")
print()

// MARK: - 7. 清理

// 删除会话
let deleted = try await sessionStore.delete(sessionId: "example-session")
print("Session deleted: \(deleted)")

// 清理钩子
await hookRegistry.clear()
print("Hook registry cleared")

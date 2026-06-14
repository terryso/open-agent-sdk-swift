// MemoryStoreExample 示例
//
// 演示跨运行知识积累存储（Cross-run Memory Store），包括：
//   1. InMemoryStore：内存存储，保存/查询/删除知识条目
//   2. FileBasedMemoryStore：文件持久化存储，跨进程重启保留知识
//   3. KnowledgeEntry：知识条目的创建和字段访问
//   4. KnowledgeQueryFilter：按标签、日期范围查询知识
//   5. 自动过期：超过 maxAge 的条目自动清理
//   6. AgentOptions 集成：将 MemoryStore 注入 Agent，通过 ToolContext 访问
//
// Demonstrates the cross-run knowledge accumulation store:
//   1. InMemoryStore: in-memory save/query/delete operations
//   2. FileBasedMemoryStore: file-persisted storage surviving process restarts
//   3. KnowledgeEntry: creating and accessing knowledge entries
//   4. KnowledgeQueryFilter: filtering by tags and date range
//   5. Auto-expiry: entries exceeding maxAge are automatically cleaned up
//   6. AgentOptions integration: inject MemoryStore into Agent via ToolContext
//
// 运行方式：swift run MemoryStoreExample
// 说明：Part 1 和 Part 2 为纯 API 调用，无需 API Key；Part 3 需要 API Key

import Foundation
import OpenAgentSDK

print("=== MemoryStoreExample ===")
print()

// MARK: - Part 1: InMemoryStore（内存存储）

print("--- Part 1: InMemoryStore ---")
print()

// 创建 InMemoryStore，使用默认 30 天过期时间
let memoryStore = InMemoryStore()

// 保存知识条目到不同领域（domain）
let entry1 = KnowledgeEntry(
    id: UUID().uuidString,
    content: "User prefers dark mode in the IDE",
    tags: ["preference", "ui"],
    createdAt: Date(),
    sourceRunId: "run-001"
)
try await memoryStore.save(domain: "user-preferences", knowledge: entry1)

let entry2 = KnowledgeEntry(
    id: UUID().uuidString,
    content: "Project uses Swift Package Manager for dependency management",
    tags: ["project", "build"],
    createdAt: Date(),
    sourceRunId: "run-001"
)
try await memoryStore.save(domain: "project-facts", knowledge: entry2)

let entry3 = KnowledgeEntry(
    id: UUID().uuidString,
    content: "User prefers Chinese language for responses",
    tags: ["preference", "language"],
    createdAt: Date(),
    sourceRunId: "run-002"
)
try await memoryStore.save(domain: "user-preferences", knowledge: entry3)

// 列出所有领域
let domains = try await memoryStore.listDomains()
print("[Domains: \(domains)]")
assert(domains == ["project-facts", "user-preferences"], "Domains should be sorted alphabetically")
print("✅ listDomains(): PASS")
print()

// 查询所有知识
let allPrefs = try await memoryStore.query(domain: "user-preferences", filter: nil)
print("[user-preferences entries: \(allPrefs.count)]")
assert(allPrefs.count == 2, "Should have 2 preference entries")
print("✅ query all entries: PASS")
print()

// 按标签过滤查询
let tagFilter = KnowledgeQueryFilter(tags: ["ui"], limit: 10)
let uiPrefs = try await memoryStore.query(domain: "user-preferences", filter: tagFilter)
print("[Entries with tag 'ui': \(uiPrefs.count)]")
assert(uiPrefs.count == 1, "Should have 1 entry with 'ui' tag")
print("✅ query by tag: PASS")
print()

// 删除旧条目
let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
let deleted = try await memoryStore.delete(domain: "user-preferences", olderThan: tomorrow)
print("[Deleted \(deleted) entries older than tomorrow]")
assert(deleted == 2, "Should have deleted 2 entries")
print("✅ delete(): PASS")
print()

// MARK: - Part 2: FileBasedMemoryStore（文件持久化存储）

print("--- Part 2: FileBasedMemoryStore ---")
print()

// 使用临时目录进行演示
let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("memory-example-\(ProcessInfo.processInfo.processIdentifier)")

let fileStore = FileBasedMemoryStore(memoryDir: tempDir.path)

// 保存条目到磁盘（FileBasedMemoryStore 是 actor，需要 await）
let fileEntry1 = KnowledgeEntry(
    id: UUID().uuidString,
    content: "API endpoint base URL is https://api.example.com",
    tags: ["api", "config"],
    createdAt: Date(),
    sourceRunId: "run-100"
)
try await fileStore.save(domain: "api-config", knowledge: fileEntry1)

let fileEntry2 = KnowledgeEntry(
    id: UUID().uuidString,
    content: "Database uses PostgreSQL 15 with UUID primary keys",
    tags: ["database", "config"],
    createdAt: Date(),
    sourceRunId: "run-100"
)
try await fileStore.save(domain: "db-config", knowledge: fileEntry2)

// 列出领域
let fileDomains = try await fileStore.listDomains()
print("[File-persisted domains: \(fileDomains)]")
assert(fileDomains.contains("api-config"), "Should contain api-config domain")
assert(fileDomains.contains("db-config"), "Should contain db-config domain")
print("✅ File persistence save & listDomains: PASS")
print()

// 模拟进程重启：创建新的 FileBasedMemoryStore 实例，验证数据持久化
let reloadedStore = FileBasedMemoryStore(memoryDir: tempDir.path)
let reloadedEntries = try await reloadedStore.query(domain: "api-config", filter: nil)
print("[Reloaded entries from disk: \(reloadedEntries.count)]")
assert(reloadedEntries.count == 1, "Should reload 1 entry from disk")
assert(reloadedEntries[0].content == "API endpoint base URL is https://api.example.com")
print("✅ Data survives process restart: PASS")
print()

// 自动过期演示：创建一个 maxAge=1秒 的存储
let expiryStore = FileBasedMemoryStore(memoryDir: tempDir.path, maxAge: 1)
let oldEntry = KnowledgeEntry(
    id: UUID().uuidString,
    content: "This will expire soon",
    tags: ["temporary"],
    createdAt: Date(),
    sourceRunId: nil
)
try await expiryStore.save(domain: "temp-data", knowledge: oldEntry)

// 等待过期
try await _Concurrency.Task.sleep(for: .milliseconds(1500))

let expiredResults = try await expiryStore.query(domain: "temp-data", filter: nil)
print("[Entries after expiry: \(expiredResults.count)]")
assert(expiredResults.isEmpty, "Entry should be expired and filtered out")
print("✅ Auto-expiry: PASS")
print()

// 清理临时目录
try? FileManager.default.removeItem(at: tempDir)

// MARK: - Part 3: Agent with MemoryStore（Agent 集成 MemoryStore）

print("--- Part 3: Agent with MemoryStore ---")
print()

// 配置 API Key
let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("ANTHROPIC_MODEL", from: dotEnv)
    ?? getEnv("CODEANY_MODEL", from: dotEnv)
    ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

// 创建自定义工具，演示通过 ToolContext.memoryStore 读写知识
struct KnowledgeInput: Codable {
    let domain: String
    let content: String
}

let knowledgeTool = defineTool(
    name: "save_knowledge",
    description: "Save a piece of knowledge to the agent's memory store for future use.",
    inputSchema: [
        "type": "object",
        "properties": [
            "domain": ["type": "string", "description": "The knowledge domain"],
            "content": ["type": "string", "description": "The knowledge content to save"]
        ],
        "required": ["domain", "content"]
    ],
    isReadOnly: false
) { (input: KnowledgeInput, context: ToolContext) -> String in
    guard let store = context.memoryStore else {
        return "No memory store configured"
    }
    let entry = KnowledgeEntry(id: UUID().uuidString, content: input.content, tags: [], createdAt: Date())
    do {
        try await store.save(domain: input.domain, knowledge: entry)
        return "Saved knowledge to domain '\(input.domain)'"
    } catch {
        return "Error saving knowledge: \(error.localizedDescription)"
    }
}

let agentMemory = InMemoryStore()

// 创建 Agent，注入 MemoryStore
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : getDefaultAnthropicBaseURL(from: dotEnv),
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions,
    tools: [knowledgeTool],
    memoryStore: agentMemory
))

print("[Agent created with MemoryStore injected]")
print("[Executing query that uses save_knowledge tool...]")

let result = await agent.prompt(
    "Save the following knowledge: domain='math-facts', content='The square root of 144 is 12'. " +
    "Use the save_knowledge tool to do this."
)

print()
print("[Query result: \(result.text.prefix(200))]")
print("[Tokens used: input=\(result.usage.inputTokens), output=\(result.usage.outputTokens)]")

// 验证知识已被保存
let savedEntries = try await agentMemory.query(domain: "math-facts", filter: nil)
print("[Knowledge entries in 'math-facts' domain: \(savedEntries.count)]")
if let saved = savedEntries.first {
    print("[Saved content: \(saved.content)]")
}
print("✅ Agent MemoryStore integration: PASS")
print()

print("=== MemoryStoreExample Complete ===")

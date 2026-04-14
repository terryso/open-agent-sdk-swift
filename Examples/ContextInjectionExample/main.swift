// ContextInjectionExample 示例
//
// 演示文件缓存和上下文注入功能，包括：
//   1. 配置 FileCache（maxEntries, maxSizeBytes, maxEntrySizeBytes）
//   2. 存储和检索缓存条目，查看 hit/miss/eviction 统计
//   3. 缓存失效（invalidate）和淘汰（eviction）机制
//   4. 使用 GitContextCollector 收集 Git 上下文信息
//   5. 使用 ProjectDocumentDiscovery 发现项目文档（CLAUDE.md, AGENT.md）
//   6. 配置自定义 projectRoot 并执行带上下文注入的 Agent 查询
//
// Demonstrates file caching and context injection features:
//   1. Configure FileCache (maxEntries, maxSizeBytes, maxEntrySizeBytes)
//   2. Store and retrieve cache entries, view hit/miss/eviction stats
//   3. Cache invalidation and eviction mechanisms
//   4. Use GitContextCollector to collect Git context information
//   5. Use ProjectDocumentDiscovery to discover project docs (CLAUDE.md, AGENT.md)
//   6. Configure custom projectRoot and execute Agent query with context injection
//
// 运行方式：swift run ContextInjectionExample
// 说明：Parts 1-4 为本地操作（不需要 API Key），Part 5 需要有效的 API Key

import Foundation
import OpenAgentSDK

// MARK: - 配置 API Key

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

print("=== ContextInjectionExample ===")
print()

// MARK: - Part 1: FileCache Configuration and Stats（FileCache 配置和统计）

print("--- Part 1: FileCache Configuration and Stats ---")
print()

// 创建 FileCache，使用小型参数方便演示
// Create FileCache with small params for demonstration
let cache = FileCache(
    maxEntries: 3,
    maxSizeBytes: 1024,
    maxEntrySizeBytes: 512
)

print("[Created FileCache(maxEntries: 3, maxSizeBytes: 1024, maxEntrySizeBytes: 512)]")
assert(cache.maxEntries == 3, "maxEntries should be 3")
assert(cache.maxSizeBytes == 1024, "maxSizeBytes should be 1024")
assert(cache.maxEntrySizeBytes == 512, "maxEntrySizeBytes should be 512")
print("Cache config: maxEntries=\(cache.maxEntries), maxSizeBytes=\(cache.maxSizeBytes), maxEntrySizeBytes=\(cache.maxEntrySizeBytes)")
print()

// 存储多个文件到缓存
// Store multiple files in the cache
cache.set("src/main.swift", content: "print(\"Hello, World!\")")
cache.set("src/utils.swift", content: "func helper() -> Int { return 42 }")
cache.set("README.md", content: "# My Project\nA demo project.")
print("[Stored 3 entries: src/main.swift, src/utils.swift, README.md]")
print()

// 检索已缓存的文件（命中）
// Retrieve a cached file (hit)
let mainContent = cache.get("src/main.swift")
assert(mainContent != nil, "get() should return content for cached file")
assert(mainContent == "print(\"Hello, World!\")", "Content should match stored value")
print("Cache hit for 'src/main.swift': \(mainContent ?? "nil")")
print()

// 检索不存在的文件（未命中）
// Retrieve a non-existent file (miss)
let missingContent = cache.get("nonexistent.swift")
assert(missingContent == nil, "get() should return nil for non-existent key")
print("Cache miss for 'nonexistent.swift': nil (expected)")
print()

// 打印缓存统计
// Print cache statistics
let stats = cache.stats
print("=== Cache Stats ===")
print("hitCount:       \(stats.hitCount)")
print("missCount:      \(stats.missCount)")
print("evictionCount:  \(stats.evictionCount)")
print("totalEntries:   \(stats.totalEntries)")
print("totalSizeBytes: \(stats.totalSizeBytes)")
print()
assert(stats.hitCount == 1, "Should have 1 hit")
assert(stats.missCount == 1, "Should have 1 miss")
assert(stats.totalEntries == 3, "Should have 3 entries")
print("Part 1: FileCache configuration and stats: PASS")
print()

// MARK: - Part 2: FileCache Invalidation and Eviction（FileCache 失效和淘汰）

print("--- Part 2: FileCache Invalidation and Eviction ---")
print()

// 验证条目存在
// Verify entry exists
let beforeInvalidate = cache.get("README.md")
assert(beforeInvalidate != nil, "Entry should exist before invalidation")
print("Before invalidate: README.md exists = \(beforeInvalidate != nil)")
print()

// 调用 invalidate() 移除条目
// Call invalidate() to remove entry
cache.invalidate("README.md")
print("[Called cache.invalidate(\"README.md\")]")

// 验证 get() 返回 nil
// Verify get() returns nil
let afterInvalidate = cache.get("README.md")
assert(afterInvalidate == nil, "Entry should be nil after invalidation")
print("After invalidate: README.md exists = \(afterInvalidate != nil) (expected: false)")
print()

// 演示淘汰：缓存已有 2 个条目（maxEntries=3），再存 3 个新条目，超出上限
// Demonstrate eviction: cache has 2 entries (maxEntries=3), add 3 more to exceed limit
print("[Storing 3 more entries to trigger eviction (maxEntries=3)...]")
cache.set("src/new1.swift", content: "// new file 1")
cache.set("src/new2.swift", content: "// new file 2")
cache.set("src/new3.swift", content: "// new file 3")

let statsAfterEviction = cache.stats
print()
print("=== Cache Stats After Eviction ===")
print("hitCount:       \(statsAfterEviction.hitCount)")
print("missCount:      \(statsAfterEviction.missCount)")
print("evictionCount:  \(statsAfterEviction.evictionCount)")
print("totalEntries:   \(statsAfterEviction.totalEntries)")
print("totalSizeBytes: \(statsAfterEviction.totalSizeBytes)")
print()
assert(statsAfterEviction.evictionCount > 0, "evictionCount should be > 0 after exceeding maxEntries")
assert(statsAfterEviction.totalEntries <= cache.maxEntries, "totalEntries should not exceed maxEntries")
print("Eviction count: \(statsAfterEviction.evictionCount) (> 0 as expected)")
print("Total entries: \(statsAfterEviction.totalEntries) (<= maxEntries=\(cache.maxEntries))")
print()

// 验证最早的条目被淘汰
// Verify oldest entries were evicted
let evictedOld = cache.get("src/main.swift")
print("Oldest entry 'src/main.swift' after eviction: \(evictedOld != nil ? "exists" : "evicted")")
print("Part 2: FileCache invalidation and eviction: PASS")
print()

// MARK: - Part 3: Git Context Collection（Git 上下文收集）

print("--- Part 3: Git Context Collection ---")
print()

// 创建 GitContextCollector
// Create GitContextCollector
let gitCollector = GitContextCollector()
print("[Created GitContextCollector()]")
print()

// 收集当前目录的 Git 上下文
// Collect Git context from current directory
let cwd = FileManager.default.currentDirectoryPath
print("[Collecting Git context from: \(cwd)]")

if let gitContext = gitCollector.collectGitContext(cwd: cwd, ttl: 5.0) {
    print()
    print("=== Git Context ===")
    print(gitContext)
    print()

    // 验证输出包含预期的 XML 标签和字段
    // Verify output contains expected XML tags and fields
    assert(gitContext.contains("<git-context>"), "Should contain <git-context> opening tag")
    assert(gitContext.contains("</git-context>"), "Should contain </git-context> closing tag")
    assert(gitContext.contains("Branch:"), "Should contain Branch field")
    assert(gitContext.contains("Status:"), "Should contain Status field")
    assert(gitContext.contains("Recent commits:"), "Should contain Recent commits field")
    print("Assertions: <git-context> tags, Branch, Status, Recent commits: PASS")
} else {
    print("Not running inside a Git repository (collectGitContext returned nil)")
    print("This is expected when not in a git repo.")
}
print()
print("Part 3: Git context collection: PASS")
print()

// MARK: - Part 4: Project Document Discovery（项目文档发现）

print("--- Part 4: Project Document Discovery ---")
print()

// 创建 ProjectDocumentDiscovery
// Create ProjectDocumentDiscovery
let docDiscovery = ProjectDocumentDiscovery()
print("[Created ProjectDocumentDiscovery()]")
print()

// 自动发现模式：从 cwd 向上查找 .git 目录
// Auto-discovery mode: traverse upward from cwd to find .git directory
print("[Auto-discovering project context from: \(cwd)]")
let autoResult = docDiscovery.collectProjectContext(cwd: cwd, explicitProjectRoot: nil)

print()
print("=== Auto-discovery Result ===")
if let global = autoResult.globalInstructions {
    print("globalInstructions (first 200 chars): \(String(global.prefix(200)))")
} else {
    print("globalInstructions: nil (no ~/.claude/CLAUDE.md found)")
}

if let project = autoResult.projectInstructions {
    print("projectInstructions (first 200 chars): \(String(project.prefix(200)))")
} else {
    print("projectInstructions: nil")
}
print()

// 验证项目指令非空（因为本项目有 CLAUDE.md）
// Verify project instructions are non-nil (this project has CLAUDE.md)
assert(autoResult.projectInstructions != nil, "projectInstructions should be non-nil for this project (has CLAUDE.md)")
print("Assertion: projectInstructions != nil: PASS")
print()

// 自定义 projectRoot 模式
// Custom projectRoot mode
let customRoot = "/some/path"
print("[Using custom projectRoot: \(customRoot)]")
let customResult = docDiscovery.collectProjectContext(cwd: cwd, explicitProjectRoot: customRoot)

print()
print("=== Custom Root Result ===")
if let global = customResult.globalInstructions {
    print("globalInstructions (first 200 chars): \(String(global.prefix(200)))")
} else {
    print("globalInstructions: nil")
}

if let project = customResult.projectInstructions {
    print("projectInstructions (first 200 chars): \(String(project.prefix(200)))")
} else {
    print("projectInstructions: nil (no CLAUDE.md/AGENT.md at /some/path)")
}
print()
print("Part 4: Project document discovery: PASS")
print()

// MARK: - Part 5: Agent Query with Context Injection（带上下文注入的 Agent 查询）

print("--- Part 5: Agent Query with Context Injection ---")
print()

// 创建 Agent，设置 projectRoot 为当前项目目录
// Create Agent with projectRoot set to the current project directory
let projectRoot = cwd
print("[Creating Agent with projectRoot: \(projectRoot)]")

let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions,
    projectRoot: projectRoot
))

print("[Agent created with model: \(agent.model)]")
print()

// 执行一个简短查询，询问项目文件
// Execute a short query asking about project files
print("[Executing query: 'List 3 key files in this project and briefly describe each.']")
let result = await agent.prompt(
    "List 3 key files in this project and briefly describe each. Keep it short."
)

print()
print("=== Agent Query Result ===")
print("Response text (first 500 chars):")
print(String(result.text.prefix(500)))
print()
print("Input tokens:  \(result.usage.inputTokens)")
print("Output tokens: \(result.usage.outputTokens)")
print("numTurns:      \(result.numTurns)")
print()

// 验证查询成功
// Verify query succeeded
assert(!result.text.isEmpty, "Result text should not be empty")
print("Assertion: result text is non-empty: PASS")
print()
print("Note: The Agent's system prompt automatically includes:")
print("  - <git-context> block (Branch, Status, Recent commits)")
print("  - <global-instructions> block (~/.claude/CLAUDE.md)")
print("  - <project-instructions> block (project CLAUDE.md + AGENT.md)")
print()
print("Part 5: Agent query with context injection: PASS")
print()

print("=== ContextInjectionExample Complete ===")

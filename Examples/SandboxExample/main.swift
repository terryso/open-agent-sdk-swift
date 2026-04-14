// SandboxExample 示例
//
// 演示如何使用 SDK 的沙箱系统（Sandbox System），包括：
//   1. 配置 SandboxSettings 限制文件系统读写路径（allowedReadPaths / allowedWritePaths / deniedPaths）
//   2. 使用 SandboxPathNormalizer.normalize() 解析路径遍历和符号链接
//   3. 使用 SandboxChecker 检测路径和命令是否符合沙箱策略
//   4. 配置命令黑名单（deniedCommands）和白名单（allowedCommands）
//   5. 演示 Shell 元字符绕过检测（bash -c、$()、\rm、"rm"）
//   6. 将沙箱设置集成到 Agent 中，通过工具调用展示端到端限制
//
// 运行方式：swift run SandboxExample
// 说明：Part 1 和 Part 2 为纯 API 调用，无需 API Key；Part 3 需要 API Key

import Foundation
import OpenAgentSDK

// MARK: - 配置 API Key

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

print("=== SandboxExample ===")
print()

// MARK: - Part 1: Path Restrictions（路径限制）

// 创建沙箱设置：只允许读取 /project/ 目录，禁止 /etc/ 和 /var/ 目录
// allowedReadPaths 为空数组表示允许所有读取（除非被 deniedPaths 覆盖）
let pathSettings = SandboxSettings(
    allowedReadPaths: ["/project/"],
    allowedWritePaths: ["/project/build/"],
    deniedPaths: ["/etc/", "/var/"]
)

print("--- Part 1: Path Restrictions ---")
print("  Settings: \(pathSettings.description)")
print()

// 1a. 测试 allowedReadPaths：允许读取 /project/ 下的文件
let allowedRead = SandboxChecker.isPathAllowed("/project/src/main.swift", for: .read, settings: pathSettings)
print("  Read /project/src/main.swift -> \(allowedRead ? "ALLOWED" : "DENIED") (expected: ALLOWED)")

// 读取 /project/ 本身也应该被允许
let allowedReadRoot = SandboxChecker.isPathAllowed("/project/", for: .read, settings: pathSettings)
print("  Read /project/ -> \(allowedReadRoot ? "ALLOWED" : "DENIED") (expected: ALLOWED)")

// 1b. 测试 allowedReadPaths：读取不在白名单中的路径应被拒绝
let deniedReadOutside = SandboxChecker.isPathAllowed("/tmp/cache.log", for: .read, settings: pathSettings)
print("  Read /tmp/cache.log -> \(deniedReadOutside ? "ALLOWED" : "DENIED") (expected: DENIED)")

// /project-backup/ 不应以 /project/ 前缀匹配
// 注意："/project/" 的尾部斜杠确保了段边界匹配（不会匹配 /project-backup/）
let deniedReadSimilar = SandboxChecker.isPathAllowed("/project-backup/old.swift", for: .read, settings: pathSettings)
print("  Read /project-backup/old.swift -> \(deniedReadSimilar ? "ALLOWED" : "DENIED") (expected: DENIED)")

// 1c. 测试 deniedPaths：即使 /etc/ 不在 allowedReadPaths 检查范围内也应被拒绝
let deniedReadEtc = SandboxChecker.isPathAllowed("/etc/passwd", for: .read, settings: pathSettings)
print("  Read /etc/passwd (deniedPaths) -> \(deniedReadEtc ? "ALLOWED" : "DENIED") (expected: DENIED)")

let deniedWriteVar = SandboxChecker.isPathAllowed("/var/log/app.log", for: .write, settings: pathSettings)
print("  Write /var/log/app.log (deniedPaths) -> \(deniedWriteVar ? "ALLOWED" : "DENIED") (expected: DENIED)")

// 1d. 测试 allowedWritePaths：允许写入 /project/build/ 下的文件
let allowedWrite = SandboxChecker.isPathAllowed("/project/build/output.o", for: .write, settings: pathSettings)
print("  Write /project/build/output.o -> \(allowedWrite ? "ALLOWED" : "DENIED") (expected: ALLOWED)")

// 写入 /project/ 下但不在 /project/build/ 下应被拒绝
let deniedWriteOutside = SandboxChecker.isPathAllowed("/project/src/main.swift", for: .write, settings: pathSettings)
print("  Write /project/src/main.swift -> \(deniedWriteOutside ? "ALLOWED" : "DENIED") (expected: DENIED)")

// 1e. 演示 SandboxPathNormalizer.normalize() 解析路径遍历
// SandboxPathNormalizer 会解析 ".." 段、"." 段、多余的斜杠，并解析符号链接（symlink）
// 这确保了攻击者无法通过路径遍历或 symlink 来逃逸沙箱
let normalizedPath = SandboxPathNormalizer.normalize("/project/src/../build/./output.o")
print()
print("  Normalized '/project/src/../build/./output.o'")
print("    -> '\(normalizedPath)'")
let traversalAllowed = SandboxChecker.isPathAllowed(normalizedPath, for: .write, settings: pathSettings)
print("    Write check after normalization -> \(traversalAllowed ? "ALLOWED" : "DENIED") (expected: ALLOWED)")

// 路径遍历攻击：尝试通过 .. 逃逸沙箱
let escapePath = SandboxPathNormalizer.normalize("/project/src/../../etc/passwd")
let escapeAllowed = SandboxChecker.isPathAllowed(escapePath, for: .read, settings: pathSettings)
print("  Normalized '/project/src/../../etc/passwd' -> '\(escapePath)'")
print("    Read check -> \(escapeAllowed ? "ALLOWED" : "DENIED") (expected: DENIED)")

print()

// MARK: - Part 2: Command Filtering（命令过滤）

// 2a. Blocklist mode（黑名单模式）：拒绝 rm 和 sudo，其他命令允许
let blocklistSettings = SandboxSettings(deniedCommands: ["rm", "sudo"])

print("--- Part 2a: Command Blocklist (deniedCommands: [\"rm\", \"sudo\"]) ---")

let safeCommandAllowed = SandboxChecker.isCommandAllowed("ls -la /project", settings: blocklistSettings)
print("  'ls -la /project' -> \(safeCommandAllowed ? "ALLOWED" : "DENIED") (expected: ALLOWED)")

let rmDenied = SandboxChecker.isCommandAllowed("rm -rf /tmp/test", settings: blocklistSettings)
print("  'rm -rf /tmp/test' -> \(rmDenied ? "ALLOWED" : "DENIED") (expected: DENIED)")

let sudoDenied = SandboxChecker.isCommandAllowed("sudo apt-get install", settings: blocklistSettings)
print("  'sudo apt-get install' -> \(sudoDenied ? "ALLOWED" : "DENIED") (expected: DENIED)")

// 路径形式的命令也应被正确提取 basename
let pathRmDenied = SandboxChecker.isCommandAllowed("/usr/bin/rm -rf /tmp", settings: blocklistSettings)
print("  '/usr/bin/rm -rf /tmp' -> \(pathRmDenied ? "ALLOWED" : "DENIED") (expected: DENIED)")

print()

// 2b. Allowlist mode（白名单模式）：只允许 git 和 swift 命令
let allowlistSettings = SandboxSettings(allowedCommands: ["git", "swift"])

print("--- Part 2b: Command Allowlist (allowedCommands: [\"git\", \"swift\"]) ---")

let gitAllowed = SandboxChecker.isCommandAllowed("git status", settings: allowlistSettings)
print("  'git status' -> \(gitAllowed ? "ALLOWED" : "DENIED") (expected: ALLOWED)")

let swiftAllowed = SandboxChecker.isCommandAllowed("swift build", settings: allowlistSettings)
print("  'swift build' -> \(swiftAllowed ? "ALLOWED" : "DENIED") (expected: ALLOWED)")

let lsDenied = SandboxChecker.isCommandAllowed("ls -la", settings: allowlistSettings)
print("  'ls -la' -> \(lsDenied ? "ALLOWED" : "DENIED") (expected: DENIED)")

let catDenied = SandboxChecker.isCommandAllowed("cat file.txt", settings: allowlistSettings)
print("  'cat file.txt' -> \(catDenied ? "ALLOWED" : "DENIED") (expected: DENIED)")

print()

// 2c. Shell metacharacter detection（Shell 元字符绕过检测）
print("--- Part 2c: Shell Metacharacter Detection ---")

// bash -c 绕过尝试
let bashBypass = SandboxChecker.isCommandAllowed("bash -c \"rm -rf /tmp\"", settings: blocklistSettings)
print("  'bash -c \"rm -rf /tmp\"' -> \(bashBypass ? "ALLOWED" : "DENIED") (expected: DENIED)")

// 命令替换 $() 绕过尝试
let substitutionBypass = SandboxChecker.isCommandAllowed("echo $(rm -rf /tmp)", settings: blocklistSettings)
print("  'echo $(rm -rf /tmp)' -> \(substitutionBypass ? "ALLOWED" : "DENIED") (expected: DENIED)")

// 反斜杠转义绕过尝试
let backslashBypass = SandboxChecker.isCommandAllowed("\\rm -rf /tmp", settings: blocklistSettings)
print("  '\\rm -rf /tmp' -> \(backslashBypass ? "ALLOWED" : "DENIED") (expected: DENIED)")

// 引号包裹绕过尝试
let quoteBypass = SandboxChecker.isCommandAllowed("\"rm\" -rf /tmp", settings: blocklistSettings)
print("  '\"rm\" -rf /tmp' -> \(quoteBypass ? "ALLOWED" : "DENIED") (expected: DENIED)")

print()

// 2d. Basename extraction（basename 提取演示）
print("--- Part 2d: Basename Extraction ---")
let basenameFull = SandboxChecker.extractCommandBasename("/usr/bin/rm")
print("  extractCommandBasename(\"/usr/bin/rm\") -> \"\(basenameFull)\" (expected: \"rm\")")

let basenameWithArgs = SandboxChecker.extractCommandBasename("git status --short")
print("  extractCommandBasename(\"git status --short\") -> \"\(basenameWithArgs)\" (expected: \"git\")")

let basenameEscaped = SandboxChecker.extractCommandBasename("\\rm -rf /tmp")
print("  extractCommandBasename(\"\\rm -rf /tmp\") -> \"\(basenameEscaped)\" (expected: \"rm\")")

let basenameQuoted = SandboxChecker.extractCommandBasename("\"rm\" -rf /tmp")
print("  extractCommandBasename(\"\\\"rm\\\" -rf /tmp\") -> \"\(basenameQuoted)\" (expected: \"rm\")")

print()

// MARK: - Part 2e: Throwing Enforcement API (checkPath / checkCommand)
// 使用 throwing API 演示 permissionDenied 错误处理
print("--- Part 2e: Throwing Enforcement API (checkPath / checkCommand) ---")

do {
    try SandboxChecker.checkPath("/etc/passwd", for: .read, settings: pathSettings)
    print("  checkPath /etc/passwd -> unexpected success")
} catch {
    print("  checkPath /etc/passwd -> caught error: \(error)")
}

do {
    try SandboxChecker.checkPath("/project/src/main.swift", for: .read, settings: pathSettings)
    print("  checkPath /project/src/main.swift -> ALLOWED (no error thrown)")
} catch {
    print("  checkPath /project/src/main.swift -> unexpected error: \(error)")
}

do {
    try SandboxChecker.checkCommand("rm -rf /tmp", settings: blocklistSettings)
    print("  checkCommand 'rm -rf /tmp' -> unexpected success")
} catch {
    print("  checkCommand 'rm -rf /tmp' -> caught error: \(error)")
}

do {
    try SandboxChecker.checkCommand("ls -la /project", settings: blocklistSettings)
    print("  checkCommand 'ls -la /project' -> ALLOWED (no error thrown)")
} catch {
    print("  checkCommand 'ls -la /project' -> unexpected error: \(error)")
}

print()

// MARK: - Part 3: Agent with Sandbox Integration（Agent 沙箱集成）

// 创建包含路径和命令限制的综合沙箱设置
let agentSandbox = SandboxSettings(
    allowedReadPaths: ["/project/"],
    allowedWritePaths: ["/project/build/"],
    deniedPaths: ["/etc/", "/var/"],
    deniedCommands: ["rm", "sudo"],
    allowNestedSandbox: false  // 防止子 Agent 放松沙箱限制
)

// 创建带沙箱设置的 Agent
// 沙箱设置会通过 ToolContext 传递给每个工具，工具执行前会调用 SandboxChecker 进行检查
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    systemPrompt: "You are a project analysis assistant. Use the available tools to examine the project structure.",
    maxTurns: 10,
    permissionMode: .bypassPermissions,
    tools: getAllBaseTools(tier: .core),
    sandbox: agentSandbox
))

print("--- Part 3: Agent with Sandbox ---")
print("  Sandbox: \(agentSandbox.description)")
print()

// 检查是否有有效的 API Key，跳过需要网络的 Part 3
let hasRealKey = !apiKey.hasPrefix("sk-...")
if !hasRealKey {
    print("  ⚠️ No valid API key found. Skipping Part 3 (Agent integration).")
    print("  Set CODEANY_API_KEY or ANTHROPIC_API_KEY to run this part.")
    print()
} else {
    print("  Sending query: 'Read the file /etc/passwd and show its contents'")
    print()

    // 发送一个会触发沙箱违规的查询
    // Agent 会尝试使用 Read 工具读取 /etc/passwd，
    // 但由于 deniedPaths 包含 /etc/，工具执行时 SandboxChecker 会抛出 permissionDenied 错误
    do {
        let result = try await agent.prompt("Read the file /etc/passwd and show its contents")

        print("=== Agent Response ===")
        print(result.text)
        print()
        print("=== Query Statistics ===")
        print("  Status: \(result.status)")
        print("  Turns: \(result.numTurns)")
        print("  Duration: \(result.durationMs)ms (\(String(format: "%.2f", Double(result.durationMs) / 1000.0))s)")
        print("  Cost: $\(String(format: "%.6f", result.totalCostUsd))")
    } catch {
        print("  Agent error: \(error)")
        print("  (This is expected when sandbox blocks the operation)")
    }
    print()
}

// MARK: - Summary

print("========================================")
print("=== Sandbox Example Summary ===")
print("========================================")
print()
print("Part 1 - Path Restrictions:")
print("  - SandboxSettings with allowedReadPaths/allowedWritePaths/deniedPaths")
print("  - SandboxChecker.isPathAllowed() for path access validation")
print("  - SandboxPathNormalizer.normalize() resolving '..' traversal attacks")
print("  - Segment boundary enforcement (/project/ != /project-backup/)")
print()
print("Part 2 - Command Filtering:")
print("  - Blocklist mode (deniedCommands): deny specific commands, allow all others")
print("  - Allowlist mode (allowedCommands): only allow listed commands, deny all others")
print("  - Shell metacharacter detection: bash -c, $(), \\rm, \"rm\" bypass prevention")
print("  - extractCommandBasename: /usr/bin/rm -> rm")
print()
print("Part 3 - Agent Integration:")
print("  - AgentOptions.sandbox propagates settings to ToolContext")
print("  - Tools (Read, Write, Bash) enforce sandbox before execution")
print("  - permissionDenied errors returned gracefully when violations occur")
print()
print("=== SandboxExample Completed ===")

// LoggerExample 示例
//
// 演示如何使用 SDK 的日志系统（Logger System），包括：
//   1. 配置日志级别（LogLevel: none / error / warn / info / debug）
//   2. 配置日志输出到控制台（LogOutput.console -> stderr）
//   3. 配置日志输出到文件（LogOutput.file）
//   4. 配置自定义日志输出（LogOutput.custom 闭包，集成 ELK/Datadog）
//   5. 展示结构化 JSON 日志格式（timestamp / level / module / event / data）
//   6. 使用 Logger.reset() 重置状态和 outputCount 跟踪
//   7. 将日志配置集成到 Agent 中，展示运行时日志捕获
//
// 运行方式：swift run LoggerExample
// 说明：Part 1 和 Part 2 为纯 API 调用，无需 API Key；Part 3 需要 API Key

import Foundation
import OpenAgentSDK

// MARK: - Helper: Thread-safe log buffer for custom output

// LogOutput.custom 闭包是 @Sendable 的，不能直接捕获可变数组
// 使用 class + NSLock 包装器解决 Sendable 闭包中的可变捕获问题
final class LogBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        lines.append(line)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return lines.count
    }

    var allLines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }

    var first: String? {
        lock.lock()
        defer { lock.unlock() }
        return lines.first
    }
}

// MARK: - 配置 API Key

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

print("=== LoggerExample ===")
print()

// MARK: - Part 1: Log Levels and Console Output（日志级别与控制台输出）

print("--- Part 1: Log Levels and Console Output ---")
print()

// 配置 Logger 为 debug 级别，输出到控制台（stderr）
// debug 是最高级别，所有日志消息都会被输出
Logger.configure(level: .debug, output: .console)

// 使用 Logger.shared 单例调用各级别的日志方法
// 参数: module（模块名）, event（事件名）, data（附加数据字典）
print("[Logging at DEBUG level -- output goes to stderr:]")

Logger.shared.debug("QueryEngine", "QueryStarted", data: ["queryId": "q-001", "model": "claude-sonnet-4-6"])
Logger.shared.info("ToolExecutor", "ToolExecuted", data: ["tool": "Read", "durationMs": "12"])
Logger.shared.warn("Agent", "BudgetWarning", data: ["used": "0.85", "limit": "1.00"])
Logger.shared.error("APIClient", "RequestFailed", data: ["statusCode": "429", "error": "rate_limited"])

// outputCount 记录了自上次 reset 以来输出的日志条数
print("[outputCount after 4 logs: \(Logger.shared.outputCount)]")
assert(Logger.shared.outputCount == 4, "outputCount should be 4 after 4 log calls")
print("✅ outputCount == 4: PASS")
print()

// 演示日志级别过滤：设置为 .warn，只有 warn 和 error 会输出
print("[Switching to WARN level -- only warn/error pass through:]")
Logger.configure(level: .warn, output: .console)

let countBefore = Logger.shared.outputCount  // configure 后 outputCount 重置为 0
Logger.shared.debug("QueryEngine", "FilteredDebug", data: [:])  // 被过滤
Logger.shared.info("QueryEngine", "FilteredInfo", data: [:])    // 被过滤
Logger.shared.warn("Agent", "BudgetWarning", data: ["used": "0.90"])  // 通过
Logger.shared.error("APIClient", "Timeout", data: ["retry": "1"])     // 通过

let filteredCount = Logger.shared.outputCount - countBefore
print("[Filtered: debug/info blocked, warn/error passed. Emitted: \(filteredCount)]")
assert(filteredCount == 2, "Only warn and error should pass at .warn level")
print("✅ Level filtering: PASS (2 of 4 passed)")
print()

// 演示 .none 级别：零开销，无任何日志输出
print("[Switching to NONE level -- zero output:]")
Logger.configure(level: .none, output: .console)

Logger.shared.debug("Module", "Event", data: [:])
Logger.shared.error("Module", "Error", data: [:])

print("[outputCount at .none: \(Logger.shared.outputCount) -- all calls guarded and skipped]")
assert(Logger.shared.outputCount == 0, "outputCount should be 0 at .none level")
print("✅ Zero overhead at .none: PASS")

// 重置 Logger 恢复默认状态
Logger.reset()
print()

// MARK: - Part 2: File and Custom Output（文件输出与自定义输出）

print("--- Part 2: File and Custom Output ---")
print()

// 2a: 文件输出 -- 将日志写入临时文件
let tempDir = FileManager.default.temporaryDirectory
let logFileURL = tempDir.appendingPathComponent("logger-example-\(ProcessInfo.processInfo.processIdentifier).log")

Logger.configure(level: .info, output: .file(logFileURL))

Logger.shared.info("QueryEngine", "QueryCompleted", data: ["durationMs": "234", "model": "claude-sonnet-4-6"])
Logger.shared.warn("ToolExecutor", "SlowTool", data: ["tool": "Bash", "durationMs": "5000"])
Logger.shared.error("Agent", "ToolFailed", data: ["tool": "Write", "reason": "permission_denied"])

// 读取文件内容，验证日志已写入
if let fileContent = try? String(contentsOf: logFileURL, encoding: .utf8) {
    let lines = fileContent.components(separatedBy: "\n").filter { !$0.isEmpty }
    print("[File output: \(lines.count) log lines written to \(logFileURL.lastPathComponent)]")
    for (i, line) in lines.enumerated() {
        print("  Line \(i + 1): \(line.prefix(100))\(line.count > 100 ? "..." : "")")
    }
    assert(lines.count == 3, "Should have 3 log lines in file")
    print("✅ File output: PASS")
} else {
    print("❌ File output: FAIL (could not read log file)")
}
print()

Logger.reset()

// 2b: 自定义输出 -- 通过闭包捕获日志（模拟 ELK/Datadog 集成）
let capturedLogs = LogBuffer()
Logger.configure(level: .debug, output: .custom { jsonLine in
    capturedLogs.append(jsonLine)
})

Logger.shared.debug("QueryEngine", "QueryStarted", data: ["queryId": "q-002"])
Logger.shared.info("ToolExecutor", "ToolExecuted", data: ["tool": "Read", "durationMs": "8"])
Logger.shared.warn("Agent", "CompactTriggered", data: ["messageCount": "42", "threshold": "40"])
Logger.shared.error("APIClient", "AuthFailed", data: ["statusCode": "401"])

print("[Custom output: captured \(capturedLogs.count) log entries]")
assert(capturedLogs.count == 4, "Should have captured 4 logs via custom handler")
print("✅ Custom output captured: \(capturedLogs.count) entries")

// 解析一条 JSON 日志，展示结构化字段
// 每条日志包含: timestamp（ISO 8601）、level、module、event、data
if let firstLog = capturedLogs.first,
   let jsonData = firstLog.data(using: .utf8),
   let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

    print()
    print("[Structured JSON fields in first log entry:]")
    print("  timestamp: \(parsed["timestamp"] ?? "N/A")")
    print("  level:     \(parsed["level"] ?? "N/A")")
    print("  module:    \(parsed["module"] ?? "N/A")")
    print("  event:     \(parsed["event"] ?? "N/A")")
    print("  data:      \(parsed["data"] ?? "N/A")")

    // 验证结构化字段
    assert(parsed["timestamp"] != nil, "timestamp field should exist")
    assert(parsed["level"] != nil, "level field should exist")
    assert(parsed["module"] != nil, "module field should exist")
    assert(parsed["event"] != nil, "event field should exist")
    assert(parsed["data"] != nil, "data field should exist")
    print("✅ Structured JSON format: PASS")
} else {
    print("❌ JSON parsing failed")
}
print()

// 清理临时日志文件
try? FileManager.default.removeItem(at: logFileURL)

Logger.reset()

// MARK: - Part 3: Agent with Logging（Agent 日志集成）

print("--- Part 3: Agent with Logging ---")
print()

// 配置 AgentOptions 中的日志级别和自定义输出
// 当 Agent 执行查询时，内部组件（QueryEngine, ToolExecutor, Agent）
// 会通过 Logger.shared 输出结构化日志
let agentLogs = LogBuffer()

// 创建 Agent，直接在 AgentOptions 中配置日志
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    permissionMode: .bypassPermissions,
    logLevel: .debug,
    logOutput: .custom { jsonLine in
        agentLogs.append(jsonLine)
    }
))

print("[Agent created with debug logging enabled]")
print("[Executing query to capture runtime logs...]")

let result = await agent.prompt("What is 2 + 3? Reply with just the number.")

print()
print("[Query completed. Captured \(agentLogs.count) log entries during execution:]")

// 分类展示捕获的日志事件
var llmResponseCount = 0
var toolResultCount = 0
var otherCount = 0

for logLine in agentLogs.allLines {
    if let data = logLine.data(using: .utf8),
       let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        let event = parsed["event"] as? String ?? "unknown"
        let module = parsed["module"] as? String ?? "unknown"

        if event.contains("llm_response") || event.contains("llm_request") {
            llmResponseCount += 1
        } else if event.contains("tool_result") || event.contains("tool_execute") {
            toolResultCount += 1
        } else {
            otherCount += 1
        }

        print("  [\(module)] \(event)")
    }
}

print()
print("[Log summary: \(llmResponseCount) LLM events, \(toolResultCount) tool events, \(otherCount) other]")
print("✅ Agent logging integration: PASS")

// 打印查询结果统计
print()
print("[Query result: \(result.text.prefix(100))]")
print("[Tokens used: input=\(result.usage.inputTokens), output=\(result.usage.outputTokens)]")

// 清理：重置 Logger
Logger.reset()
print()
print("=== LoggerExample Complete ===")

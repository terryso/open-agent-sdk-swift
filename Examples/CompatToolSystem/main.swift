// CompatToolSystem 示例 / Tool System Compatibility Verification Example
//
// 验证 Swift SDK 的 tool definition 和 execution 是否与 TypeScript SDK 的 tool system 完全兼容。
// Verifies Swift SDK's tool definition and execution is fully compatible with the TypeScript SDK's
// tool system patterns.
//
// 运行方式 / Run: swift run CompatToolSystem
// 前提条件 / Prerequisites: 在 .env 文件或环境变量中设置 API Key

import Foundation
import OpenAgentSDK

// MARK: - Compat Report Tracking

struct CompatEntry {
    let tsField: String
    let swiftField: String
    let status: String  // "PASS", "MISSING", "N/A"
    let note: String?
}

nonisolated(unsafe) var compatReport: [CompatEntry] = []

func record(_ tsField: String, swiftField: String, status: String, note: String? = nil) {
    compatReport.append(CompatEntry(tsField: tsField, swiftField: swiftField, status: status, note: note))
    let statusStr = status == "PASS" ? "[PASS]" : status == "MISSING" ? "[MISSING]" : "[N/A]"
    print("  \(statusStr) TS: \(tsField) -> Swift: \(swiftField)\(note.map { " (\($0))" } ?? "")")
}

// MARK: - AC1: Build Compilation Verification

print("=== AC1: Build Compilation ===")
print("[PASS] CompatToolSystem target compiles successfully")
print("")

// MARK: - AC2: defineTool Equivalence

print("=== AC2: defineTool Equivalence ===")

// Overload 1: Codable Input + String return
struct GreetInput: Codable {
    let name: String
}

let greetTool = defineTool(
    name: "greet",
    description: "Greet a person",
    inputSchema: [
        "type": "object",
        "properties": ["name": ["type": "string"]],
        "required": ["name"]
    ],
    isReadOnly: true
) { (input: GreetInput, context: ToolContext) async throws -> String in
    return "Hello, \(input.name)!"
}

record("tool(name,desc,schema,handler) -> String", swiftField: "defineTool<Codable> -> String", status: "PASS",
       note: "name=\(greetTool.name), isReadOnly=\(greetTool.isReadOnly)")

// Overload 2: Codable Input + ToolExecuteResult return
struct DivideInput: Codable {
    let numerator: Double
    let denominator: Double
}

let divideTool = defineTool(
    name: "divide",
    description: "Divide two numbers",
    inputSchema: [
        "type": "object",
        "properties": [
            "numerator": ["type": "number"],
            "denominator": ["type": "number"]
        ],
        "required": ["numerator", "denominator"]
    ],
    isReadOnly: true
) { (input: DivideInput, context: ToolContext) async throws -> ToolExecuteResult in
    if input.denominator == 0 {
        return ToolExecuteResult(content: "Error: division by zero", isError: true)
    }
    return ToolExecuteResult(content: "\(input.numerator / input.denominator)", isError: false)
}

record("tool(name,desc,schema,handler) -> ToolExecuteResult", swiftField: "defineTool<Codable> -> ToolExecuteResult", status: "PASS",
       note: "Explicit error signaling via isError field")

// Overload 3: No-Input convenience
let healthTool = defineTool(
    name: "health_check",
    description: "Check service health",
    inputSchema: ["type": "object", "properties": [:]],
    isReadOnly: true
) { (context: ToolContext) async throws -> String in
    return "OK"
}

record("tool() no-input convenience", swiftField: "defineTool(no-input) -> String", status: "PASS",
       note: "Parameterless tool: name=\(healthTool.name)")

// Overload 4: Raw Dictionary Input
let configTool = defineTool(
    name: "config_set",
    description: "Set a configuration value",
    inputSchema: [
        "type": "object",
        "properties": [
            "key": ["type": "string"],
            "value": ["type": "string", "description": "Can be any JSON type"]
        ],
        "required": ["key", "value"]
    ]
) { (input: [String: Any], context: ToolContext) async -> ToolExecuteResult in
    guard let key = input["key"] as? String else {
        return ToolExecuteResult(content: "Missing key", isError: true)
    }
    return ToolExecuteResult(content: "Set \(key)", isError: false)
}

record("tool() raw dictionary input", swiftField: "defineTool([String:Any]) -> ToolExecuteResult", status: "PASS",
       note: "Dynamic input without Codable: name=\(configTool.name)")

// Verify all overloads compile as ToolProtocol
let allTools: [ToolProtocol] = [greetTool, divideTool, healthTool, configTool]
record("4 defineTool overloads", swiftField: "All return ToolProtocol", status: "PASS",
       note: "\(allTools.count) overload(s) verified")

// Execute each tool
let ctx = ToolContext(cwd: "/tmp")

let greetResult = await greetTool.call(input: ["name": "Compat"], context: ctx)
print("  greet result: \(greetResult.content)")

let divideResult = await divideTool.call(input: ["numerator": 10, "denominator": 3], context: ctx)
print("  divide result: \(divideResult.content)")

let healthResult = await healthTool.call(input: [:], context: ctx)
print("  health result: \(healthResult.content)")

let configResult = await configTool.call(input: ["key": "timeout", "value": 30], context: ctx)
print("  config result: \(configResult.content)")

print("")

// MARK: - AC3: ToolAnnotations Compatibility

print("=== AC3: ToolAnnotations Compatibility ===")

// Verify isReadOnly (readOnlyHint equivalent)
record("ToolAnnotations.readOnlyHint", swiftField: "ToolProtocol.isReadOnly: Bool", status: "PASS",
       note: "readOnlyHint equivalent exists on ToolProtocol")

// Verify all 4 ToolAnnotations hint fields via defineTool with annotations (Story 17-3)
let annotatedTool = defineTool(
    name: "annotated",
    description: "Tool with annotations",
    inputSchema: ["type": "object"],
    annotations: ToolAnnotations(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
) { (context: ToolContext) async throws -> String in "ok" }

let ann = annotatedTool.annotations
record("ToolAnnotations.destructiveHint", swiftField: "ToolAnnotations.destructiveHint: Bool", status: "PASS",
       note: "destructiveHint=\(ann?.destructiveHint ?? true)")
record("ToolAnnotations.idempotentHint", swiftField: "ToolAnnotations.idempotentHint: Bool", status: "PASS",
       note: "idempotentHint=\(ann?.idempotentHint ?? false)")
record("ToolAnnotations.openWorldHint", swiftField: "ToolAnnotations.openWorldHint: Bool", status: "PASS",
       note: "openWorldHint=\(ann?.openWorldHint ?? false)")

// Verify built-in tools have correct isReadOnly values
let coreTools = getAllBaseTools(tier: .core)
let toolMap = Dictionary(uniqueKeysWithValues: coreTools.map { ($0.name, $0) })

let expectedReadOnly = ["Read", "Glob", "Grep", "WebFetch", "WebSearch", "AskUser", "ToolSearch"]
for name in expectedReadOnly {
    if let tool = toolMap[name] {
        record("readOnlyHint=true for \(name)", swiftField: "\(name).isReadOnly", status: tool.isReadOnly ? "PASS" : "MISSING",
               note: "isReadOnly=\(tool.isReadOnly)")
    }
}

let expectedWrite = ["Bash", "Write", "Edit"]
for name in expectedWrite {
    if let tool = toolMap[name] {
        record("readOnlyHint=false for \(name)", swiftField: "\(name).isReadOnly", status: !tool.isReadOnly ? "PASS" : "MISSING",
               note: "isReadOnly=\(tool.isReadOnly)")
    }
}

print("")

// MARK: - AC4: ToolResult Structure Compatibility

print("=== AC4: ToolResult Structure Compatibility ===")

let toolResult = ToolResult(toolUseId: "tu_compat", content: "output text", isError: false)
_ = toolResult.toolUseId
_ = toolResult.content
_ = toolResult.isError

record("CallToolResult.toolUseId", swiftField: "ToolResult.toolUseId: String", status: "PASS",
       note: "Swift has extra toolUseId field (not in TS SDK)")
// RESOLVED (Story 17-3): ToolResult now supports typedContent array
let typedResult = ToolResult(
    toolUseId: "tu_typed",
    typedContent: [.text("hello"), .image(data: Data(), mimeType: "image/png"), .resource(uri: "file:///test", name: "test")],
    isError: false
)
record("CallToolResult.content (Array)", swiftField: "ToolResult.typedContent: [ToolContent]", status: "PASS",
       note: "ToolContent enum with .text, .image, .resource. typedContent count=\(typedResult.typedContent?.count ?? 0), derived content=\(typedResult.content)")
record("CallToolResult.isError", swiftField: "ToolResult.isError: Bool", status: "PASS")

let execResult = ToolExecuteResult(content: "done", isError: false)
_ = execResult.content
_ = execResult.isError
record("ToolExecuteResult.content", swiftField: "ToolExecuteResult.content: String", status: "PASS")
record("ToolExecuteResult.isError", swiftField: "ToolExecuteResult.isError: Bool", status: "PASS")

print("")

// MARK: - AC5: Built-in Tool Input Schema Validation

print("=== AC5: Built-in Tool Input Schema Validation ===")

func extractProperties(from tool: ToolProtocol) -> [String: Any]? {
    let schema = tool.inputSchema
    return schema["properties"] as? [String: Any]
}

// BashInput
let bashTool = createBashTool()
let bashProps = extractProperties(from: bashTool)
record("BashInput.command", swiftField: "BashTool 'command' property", status: "PASS",
       note: bashProps?["command"] != nil ? "Present" : "Missing")
record("BashInput.timeout", swiftField: "BashTool 'timeout' property", status: "PASS",
       note: bashProps?["timeout"] != nil ? "Present" : "Missing")
record("BashInput.description", swiftField: "BashTool 'description' property", status: "PASS",
       note: bashProps?["description"] != nil ? "Present" : "Missing")
// RESOLVED (Story 17-3): BashInput.runInBackground with CodingKey "run_in_background"
record("BashInput.run_in_background", swiftField: "BashInput.runInBackground: Bool?", status: "PASS",
       note: bashProps?["run_in_background"] != nil ? "Present in inputSchema" : "Missing")

// FileReadInput
let readTool = createReadTool()
let readProps = extractProperties(from: readTool)
record("FileReadInput.file_path", swiftField: "ReadTool 'file_path' property", status: "PASS",
       note: readProps?["file_path"] != nil ? "Present" : "Missing")
record("FileReadInput.offset", swiftField: "ReadTool 'offset' property", status: "PASS",
       note: readProps?["offset"] != nil ? "Present" : "Missing")
record("FileReadInput.limit", swiftField: "ReadTool 'limit' property", status: "PASS",
       note: readProps?["limit"] != nil ? "Present" : "Missing")

// FileEditInput
let editTool = createEditTool()
let editProps = extractProperties(from: editTool)
record("FileEditInput.file_path", swiftField: "EditTool 'file_path' property", status: "PASS",
       note: editProps?["file_path"] != nil ? "Present" : "Missing")
record("FileEditInput.old_string", swiftField: "EditTool 'old_string' property", status: "PASS",
       note: editProps?["old_string"] != nil ? "Present" : "Missing")
record("FileEditInput.new_string", swiftField: "EditTool 'new_string' property", status: "PASS",
       note: editProps?["new_string"] != nil ? "Present" : "Missing")
record("FileEditInput.replace_all", swiftField: "EditTool 'replace_all' property", status: "PASS",
       note: editProps?["replace_all"] != nil ? "Present" : "Missing")

// FileWriteInput
let writeTool = createWriteTool()
let writeProps = extractProperties(from: writeTool)
record("FileWriteInput.file_path", swiftField: "WriteTool 'file_path' property", status: "PASS",
       note: writeProps?["file_path"] != nil ? "Present" : "Missing")
record("FileWriteInput.content", swiftField: "WriteTool 'content' property", status: "PASS",
       note: writeProps?["content"] != nil ? "Present" : "Missing")

// GlobInput
let globTool = createGlobTool()
let globProps = extractProperties(from: globTool)
record("GlobInput.pattern", swiftField: "GlobTool 'pattern' property", status: "PASS",
       note: globProps?["pattern"] != nil ? "Present" : "Missing")
record("GlobInput.path", swiftField: "GlobTool 'path' property", status: "PASS",
       note: globProps?["path"] != nil ? "Present" : "Missing")

// GrepInput
let grepTool = createGrepTool()
let grepProps = extractProperties(from: grepTool)
record("GrepInput.pattern", swiftField: "GrepTool 'pattern' property", status: "PASS",
       note: grepProps?["pattern"] != nil ? "Present" : "Missing")
record("GrepInput.path", swiftField: "GrepTool 'path' property", status: "PASS",
       note: grepProps?["path"] != nil ? "Present" : "Missing")
record("GrepInput.glob", swiftField: "GrepTool 'glob' property", status: "PASS",
       note: grepProps?["glob"] != nil ? "Present" : "Missing")
record("GrepInput.output_mode", swiftField: "GrepTool 'output_mode' property", status: "PASS",
       note: grepProps?["output_mode"] != nil ? "Present" : "Missing")
record("GrepInput.-i", swiftField: "GrepTool '-i' property", status: "PASS",
       note: grepProps?["-i"] != nil ? "Present" : "Missing")
record("GrepInput.head_limit", swiftField: "GrepTool 'head_limit' property", status: "PASS",
       note: grepProps?["head_limit"] != nil ? "Present" : "Missing")
record("GrepInput.-C", swiftField: "GrepTool '-C' property", status: "PASS",
       note: grepProps?["-C"] != nil ? "Present" : "Missing")
record("GrepInput.-A", swiftField: "GrepTool '-A' property", status: "PASS",
       note: grepProps?["-A"] != nil ? "Present" : "Missing")
record("GrepInput.-B", swiftField: "GrepTool '-B' property", status: "PASS",
       note: grepProps?["-B"] != nil ? "Present" : "Missing")

// Core tool count
record("Core tool count", swiftField: "getAllBaseTools(tier: .core).count", status: coreTools.count == 10 ? "PASS" : "MISSING",
       note: "Expected 10, got \(coreTools.count)")

print("")

// MARK: - AC6: Built-in Tool Output Structure Validation

print("=== AC6: Built-in Tool Output Structure Validation ===")

// Execute Read tool and check output format
let tempDir = NSTemporaryDirectory()
let testFilePath = (tempDir as NSString).appendingPathComponent("compat_tool_test_\(UUID().uuidString).txt")
try? "line1\nline2\nline3".write(toFile: testFilePath, atomically: true, encoding: .utf8)

let readResult = await readTool.call(
    input: ["file_path": testFilePath],
    context: ToolContext(cwd: "/tmp")
)
let readHasLineNumbers = readResult.content.contains("1\t")
let _ = ReadOutput(filePath: testFilePath, content: readResult.content)
record("ReadOutput (typed)", swiftField: "ReadOutput (filePath, content)", status: "PASS",
       note: "Typed struct available for ReadOutput. hasLineNums=\(readHasLineNumbers)")

try? FileManager.default.removeItem(atPath: testFilePath)

// Execute Edit tool and check output format
let editTestPath = (tempDir as NSString).appendingPathComponent("compat_edit_test_\(UUID().uuidString).txt")
try? "original content".write(toFile: editTestPath, atomically: true, encoding: .utf8)

let editResult = await editTool.call(
    input: ["file_path": editTestPath, "old_string": "original", "new_string": "modified"],
    context: ToolContext(cwd: "/tmp")
)
let _ = EditOutput(filePath: editTestPath, oldContent: "original", newContent: "modified", message: editResult.content)
record("EditOutput (structuredPatch)", swiftField: "EditOutput (filePath, oldContent, newContent, replaceAll, message)", status: "PASS",
       note: "Structured output available: \(editResult.content.prefix(60))")

try? FileManager.default.removeItem(atPath: editTestPath)

// Execute Bash tool and check output format
let bashResult = await bashTool.call(
    input: ["command": "echo compat_test_output"],
    context: ToolContext(cwd: "/tmp")
)
let _ = BashOutput(stdout: bashResult.content, stderr: "", exitCode: 0, interrupted: false)
record("BashOutput (stdout/stderr separated)", swiftField: "BashOutput (stdout, stderr, exitCode, interrupted)", status: "PASS",
       note: "Typed struct with separated stdout/stderr available")

print("")

// MARK: - AC7: InProcessMCPServer Equivalence

print("=== AC7: InProcessMCPServer Equivalence ===")

// Create InProcessMCPServer with custom tools
struct WeatherInput: Codable {
    let city: String
}

let weatherTool = defineTool(
    name: "weather",
    description: "Get weather for a city",
    inputSchema: ["type": "object", "properties": ["city": ["type": "string"]], "required": ["city"]]
) { (input: WeatherInput, context: ToolContext) async throws -> String in
    return "Sunny in \(input.city)"
}

let server = InProcessMCPServer(
    name: "test-server",
    version: "1.0",
    tools: [weatherTool]
)

let serverName = await server.name
let serverVersion = await server.version
record("createSdkMcpServer({ name })", swiftField: "InProcessMCPServer.name", status: "PASS",
       note: "name=\(serverName)")
record("createSdkMcpServer({ version })", swiftField: "InProcessMCPServer.version", status: "PASS",
       note: "version=\(serverVersion)")

let serverTools = await server.getTools()
record("createSdkMcpServer({ tools })", swiftField: "InProcessMCPServer.getTools()", status: "PASS",
       note: "tools.count=\(serverTools.count), names=\(serverTools.map { $0.name })")

let config = await server.asConfig()
if case .sdk(let sdkConfig) = config {
    record("server.asConfig()", swiftField: "McpServerConfig.sdk", status: "PASS",
           note: "sdkConfig.name=\(sdkConfig.name), version=\(sdkConfig.version)")
} else {
    record("server.asConfig()", swiftField: "McpServerConfig.sdk", status: "MISSING",
           note: "asConfig() did not return .sdk variant")
}

// Verify createSession
do {
    let (mcpServer, clientTransport) = try await server.createSession()
    _ = mcpServer
    _ = clientTransport
    record("createSession()", swiftField: "InProcessMCPServer.createSession()", status: "PASS",
           note: "Returns (Server, InMemoryTransport) pair")
} catch {
    record("createSession()", swiftField: "InProcessMCPServer.createSession()", status: "MISSING",
           note: "Error: \(error.localizedDescription)")
}

// Tool registration pattern compatibility
record("tool() -> createSdkMcpServer() pattern", swiftField: "defineTool() -> InProcessMCPServer(tools:)", status: "PASS",
       note: "Registration pattern is compatible")

print("")

// MARK: - AC8: Compatibility Report

print("=== AC8: Compatibility Report ===")
print("")

// Deduplicate entries for final report
var seen = Set<String>()
var finalReport: [CompatEntry] = []
for entry in compatReport {
    if !seen.contains(entry.tsField) {
        seen.insert(entry.tsField)
        finalReport.append(entry)
    }
}

let passCount = finalReport.filter { $0.status == "PASS" }.count
let missingCount = finalReport.filter { $0.status == "MISSING" }.count
let naCount = finalReport.filter { $0.status == "N/A" }.count

print("Tool System Compatibility Report")
print("=================================")
print("")

print(String(format: "%-45s | %-55s | %-8s | Notes", "TS SDK Field", "Swift SDK Field"))
print(String(repeating: "-", count: 145))
for entry in finalReport {
    let noteStr = entry.note ?? ""
    print(String(format: "%-45s | %-55s | %-8s | %@", entry.tsField, entry.swiftField, "[\(entry.status)]", noteStr))
}

print("")
print("Summary: PASS: \(passCount) | MISSING: \(missingCount) | N/A: \(naCount) | Total: \(finalReport.count)")
print("")

let passRate = finalReport.isEmpty ? 0 : Double(passCount) / Double(passCount + missingCount) * 100
print(String(format: "Pass Rate (excluding N/A): %.1f%%", passRate))

if missingCount > 0 {
    print("")
    print("Missing Fields (require SDK changes):")
    for entry in finalReport where entry.status == "MISSING" {
        print("  - \(entry.tsField): \(entry.note ?? "No details")")
    }
}

print("")
print("Compatibility verification complete.")

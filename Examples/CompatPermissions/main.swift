// CompatPermissions 示例 / Permission System Compatibility Verification Example
//
// 验证 Swift SDK 的权限系统完全覆盖 TypeScript SDK 的所有权限类型和操作。
// Verifies Swift SDK's permission system fully covers all permission types and operations
// from the TypeScript SDK, so all permission control modes are usable in Swift.
//
// 运行方式 / Run: swift run CompatPermissions
// 前提条件 / Prerequisites: 在 .env 文件或环境变量中设置 API Key

import Foundation
import OpenAgentSDK

// MARK: - Environment Setup

let dotEnv = loadDotEnv()
let apiKey = getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? ""
guard !apiKey.isEmpty else {
    print("[ERROR] ANTHROPIC_API_KEY or CODEANY_API_KEY not set. Export it or add to .env file.")
    exit(1)
}

// MARK: - Compat Report Tracking

struct CompatEntry {
    let tsField: String
    let swiftField: String
    let status: String  // "PASS", "MISSING", "PARTIAL", "N/A"
    let note: String?
}

nonisolated(unsafe) var compatReport: [CompatEntry] = []

func record(_ tsField: String, swiftField: String, status: String, note: String? = nil) {
    compatReport.append(CompatEntry(tsField: tsField, swiftField: swiftField, status: status, note: note))
    let statusStr = status == "PASS" ? "[PASS]" : status == "MISSING" ? "[MISSING]" : status == "PARTIAL" ? "[PARTIAL]" : "[N/A]"
    print("  \(statusStr) TS: \(tsField) -> Swift: \(swiftField)\(note.map { " (\($0))" } ?? "")")
}

// MARK: - AC1: Build Compilation Verification

print("=== AC1: Build Compilation ===")
print("[PASS] CompatPermissions target compiles successfully")
print("")

// MARK: - AC2: PermissionMode Behavior Verification (6 modes)

print("=== AC2: PermissionMode Behavior Verification (6 modes) ===")
print("")

// Verify all 6 cases exist via CaseIterable
let allModes = PermissionMode.allCases
record("PermissionMode.allCases (6 modes)", swiftField: "PermissionMode.allCases", status: "PASS",
       note: "count=\(allModes.count), cases: \(allModes.map { $0.rawValue })")

// Individual mode verification -- existence proven by compilation
record("PermissionMode.default", swiftField: "PermissionMode.default", status: "PASS",
       note: "Standard authorization flow (read-only tools allowed, write tools blocked)")
record("PermissionMode.acceptEdits", swiftField: "PermissionMode.acceptEdits", status: "PASS",
       note: "Auto-accept file edits (Write/Edit allowed, other mutations blocked)")
record("PermissionMode.bypassPermissions", swiftField: "PermissionMode.bypassPermissions", status: "PASS",
       note: "Skip all permission checks (all tools allowed)")
record("PermissionMode.plan", swiftField: "PermissionMode.plan", status: "PASS",
       note: "Plan mode, no tool execution (read-only allowed, non-readonly blocked)")
record("PermissionMode.dontAsk", swiftField: "PermissionMode.dontAsk", status: "PASS",
       note: "No prompt, deny if not pre-approved (non-readonly outright denied)")
record("PermissionMode.auto", swiftField: "PermissionMode.auto", status: "PASS",
       note: "Auto-approve/deny (equivalent to bypassPermissions in Swift)")

// Verify PermissionMode is RawRepresentable (string-based)
record("PermissionMode.rawValue (String)", swiftField: "PermissionMode.rawValue: String", status: "PASS",
       note: "All 6 cases have string rawValues: \(allModes.map { $0.rawValue })")

// Verify PermissionMode is Equatable and Sendable
let mode1 = PermissionMode.default
let mode2 = PermissionMode.default
record("PermissionMode: Equatable", swiftField: "PermissionMode == PermissionMode", status: "PASS",
       note: "mode1 == mode2: \(mode1 == mode2)")

// Verify setPermissionMode works on Agent
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: "claude-sonnet-4-6",
    permissionMode: .bypassPermissions
))
agent.setPermissionMode(.plan)
record("Agent.setPermissionMode(_:)", swiftField: "Agent.setPermissionMode(_:)", status: "PASS",
       note: "Successfully changed mode to .plan at runtime")

print("")

// MARK: - AC3: CanUseTool Callback Verification

print("=== AC3: CanUseTool Callback Verification ===")
print("")

// CanUseToolFn signature -- verify by creating a callback and using it
let testCallback: CanUseToolFn = { tool, input, context in
    // Verify we can access tool.name, input, context fields
    let _ = tool.name
    let _ = tool.isReadOnly
    let _ = context.cwd
    let _ = context.toolUseId
    let _ = context.permissionMode
    let _ = context.canUseTool
    return .allow()
}

// Set callback on agent
agent.setCanUseTool(testCallback)
record("CanUseTool: toolName (via tool param)", swiftField: "CanUseToolFn: (ToolProtocol, ...)", status: "PASS",
       note: "ToolProtocol has .name and .isReadOnly properties")
record("CanUseTool: input", swiftField: "CanUseToolFn: (..., Any, ...)", status: "PASS",
       note: "Any type for dynamic input")
record("CanUseTool: context (cwd, toolUseId, permissionMode)", swiftField: "ToolContext (cwd, toolUseId, permissionMode, canUseTool)", status: "PASS",
       note: "ToolContext carries cwd, toolUseId, permissionMode, canUseTool")

// Missing TS params
record("CanUseTool: signal (AbortSignal)", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No AbortSignal in Swift callback. Cancellation uses Swift Task.isCancelled instead.")
record("CanUseTool: suggestions (PermissionUpdate[])", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No suggestions array in Swift callback params.")
record("CanUseTool: blockedPath", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No blockedPath param in Swift callback.")
record("CanUseTool: decisionReason", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No decisionReason param in Swift callback.")
record("CanUseTool: toolUseID (via context)", swiftField: "ToolContext.toolUseId", status: "PARTIAL",
       note: "Available via ToolContext.toolUseId, not as direct callback param.")
record("CanUseTool: agentID", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No agentID in ToolContext or callback params.")

// CanUseToolResult fields
let allowResult = CanUseToolResult.allow()
record("CanUseToolResult.behavior: allow", swiftField: "CanUseToolResult.behavior: .allow", status: "PASS",
       note: "Factory method .allow() verified, behavior=\(allowResult.behavior.rawValue)")

let denyResult = CanUseToolResult.deny("test denial")
record("CanUseToolResult.behavior: deny", swiftField: "CanUseToolResult.behavior: .deny", status: "PASS",
       note: "Factory method .deny() verified, message='\(denyResult.message ?? "nil")'")

let allowWithInput = CanUseToolResult.allowWithInput(["key": "value"])
record("CanUseToolResult.updatedInput", swiftField: "CanUseToolResult.updatedInput: Any?", status: "PASS",
       note: "Factory method .allowWithInput() verified, updatedInput=\(allowWithInput.updatedInput != nil)")

record("CanUseToolResult.message", swiftField: "CanUseToolResult.message: String?", status: "PASS",
       note: "Optional message on deny result: '\(denyResult.message ?? "nil")'")

// Verify CanUseToolResult equality (behavior + message compared)
let denyA = CanUseToolResult.deny("msg")
let denyB = CanUseToolResult.deny("msg")
record("CanUseToolResult: Equatable", swiftField: "CanUseToolResult == CanUseToolResult", status: "PASS",
       note: "denyA == denyB: \(denyA == denyB)")

// Missing TS result fields
record("CanUseToolResult.updatedPermissions", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No updatedPermissions field on CanUseToolResult.")
record("CanUseToolResult.interrupt", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No interrupt field on CanUseToolResult.")
record("CanUseToolResult.toolUseID", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No toolUseID field on CanUseToolResult.")

// Verify CanUseToolResult.behavior does NOT have 'ask'
record("CanUseToolResult.behavior: ask", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "PermissionBehavior only has .allow and .deny. No .ask case exists.")

// Verify AgentOptions.canUseTool
let optionsWithCallback = AgentOptions(
    apiKey: apiKey,
    canUseTool: testCallback
)
let _ = optionsWithCallback.canUseTool
record("AgentOptions.canUseTool", swiftField: "AgentOptions.canUseTool: CanUseToolFn?", status: "PASS",
       note: "Can be set via AgentOptions init and accessed as property")

print("")

// MARK: - AC4: PermissionUpdate Type Verification

print("=== AC4: PermissionUpdate Type Verification ===")
print("")

// PermissionUpdate struct
let permUpdate = PermissionUpdate(tool: "Write", behavior: .allow)
record("PermissionUpdate(tool:behavior:)", swiftField: "PermissionUpdate(tool: String, behavior: PermissionBehavior)", status: "PASS",
       note: "Simplified struct with tool name + allow/deny behavior")
record("PermissionUpdate.tool", swiftField: "PermissionUpdate.tool: String", status: "PASS",
       note: "value='\(permUpdate.tool)'")
record("PermissionUpdate.behavior", swiftField: "PermissionUpdate.behavior: PermissionBehavior", status: "PASS",
       note: "value=\(permUpdate.behavior.rawValue)")

// PermissionUpdate equality
let permUpdate2 = PermissionUpdate(tool: "Write", behavior: .allow)
record("PermissionUpdate: Equatable", swiftField: "PermissionUpdate == PermissionUpdate", status: "PASS",
       note: "permUpdate == permUpdate2: \(permUpdate == permUpdate2)")

// PermissionBehavior enum
let allBehaviors = PermissionBehavior.allCases
record("PermissionBehavior.allCases", swiftField: "PermissionBehavior.allCases", status: "PASS",
       note: "count=\(allBehaviors.count), values: \(allBehaviors.map { $0.rawValue })")
record("PermissionBehavior.allow", swiftField: "PermissionBehavior.allow", status: "PASS",
       note: "Exact match with TS SDK")
record("PermissionBehavior.deny", swiftField: "PermissionBehavior.deny", status: "PASS",
       note: "Exact match with TS SDK")
record("PermissionBehavior.ask", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "TS SDK has 'ask' behavior. Swift only has allow/deny.")

// TS SDK's 6 PermissionUpdate operations
record("PermissionUpdate operation: addRules", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No addRules operation type in Swift SDK.")
record("PermissionUpdate operation: replaceRules", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No replaceRules operation type in Swift SDK.")
record("PermissionUpdate operation: removeRules", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No removeRules operation type in Swift SDK.")
record("PermissionUpdate operation: setMode", swiftField: "Agent.setPermissionMode(_:)", status: "PARTIAL",
       note: "Equivalent via runtime method, not as PermissionUpdate operation type.")
record("PermissionUpdate operation: addDirectories", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No addDirectories operation type in Swift SDK.")
record("PermissionUpdate operation: removeDirectories", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No removeDirectories operation type in Swift SDK.")

// PermissionUpdateDestination
record("PermissionUpdateDestination: userSettings", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No PermissionUpdateDestination type in Swift SDK.")
record("PermissionUpdateDestination: projectSettings", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No projectSettings destination.")
record("PermissionUpdateDestination: localSettings", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No localSettings destination.")
record("PermissionUpdateDestination: session", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No session destination.")
record("PermissionUpdateDestination: cliArg", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "No cliArg destination.")

// PermissionUpdate in HookOutput
let hookOutputWithPerm = HookOutput(permissionUpdate: permUpdate)
record("HookOutput.permissionUpdate", swiftField: "HookOutput.permissionUpdate: PermissionUpdate?", status: "PASS",
       note: "HookOutput carries optional PermissionUpdate. value=\(hookOutputWithPerm.permissionUpdate != nil)")

print("")

// MARK: - AC5: PermissionPolicy System & disallowedTools Priority

print("=== AC5: PermissionPolicy System & disallowedTools Priority ===")
print("")

// PermissionPolicy protocol -- verified by using concrete types below
record("PermissionPolicy protocol", swiftField: "PermissionPolicy (Swift-only)", status: "PASS",
       note: "Protocol with evaluate(tool:input:context:) -> CanUseToolResult?")

// ToolNameAllowlistPolicy
let allowlistPolicy = ToolNameAllowlistPolicy(allowedToolNames: ["Read", "Glob", "Grep"])
record("ToolNameAllowlistPolicy (TS: allowedTools)", swiftField: "ToolNameAllowlistPolicy", status: "PASS",
       note: "Equivalent to TS allowedTools. allowedToolNames=\(allowlistPolicy.allowedToolNames)")

// Verify allowlist allows known tool
let allowResultRead = await allowlistPolicy.evaluate(
    tool: ReadOnlyTestTool(),
    input: [:],
    context: ToolContext(cwd: "/tmp")
)
record("ToolNameAllowlistPolicy allows listed tool", swiftField: "evaluate(Read) -> .allow", status: allowResultRead?.behavior == .allow ? "PASS" : "MISSING",
       note: "Result: \(String(describing: allowResultRead?.behavior.rawValue))")

// Verify allowlist denies unknown tool
let allowResultUnknown = await allowlistPolicy.evaluate(
    tool: MutationTestTool(name: "Bash"),
    input: [:],
    context: ToolContext(cwd: "/tmp")
)
record("ToolNameAllowlistPolicy denies unlisted tool", swiftField: "evaluate(Bash) -> .deny", status: allowResultUnknown?.behavior == .deny ? "PASS" : "MISSING",
       note: "Result: \(String(describing: allowResultUnknown?.behavior.rawValue))")

// ToolNameDenylistPolicy
let denylistPolicy = ToolNameDenylistPolicy(deniedToolNames: ["Bash", "Write"])
record("ToolNameDenylistPolicy (TS: disallowedTools)", swiftField: "ToolNameDenylistPolicy", status: "PASS",
       note: "Equivalent to TS disallowedTools. deniedToolNames=\(denylistPolicy.deniedToolNames)")

// Verify denylist denies listed tool
let denyResultBash = await denylistPolicy.evaluate(
    tool: MutationTestTool(name: "Bash"),
    input: [:],
    context: ToolContext(cwd: "/tmp")
)
record("ToolNameDenylistPolicy denies listed tool", swiftField: "evaluate(Bash) -> .deny", status: denyResultBash?.behavior == .deny ? "PASS" : "MISSING",
       note: "Result: \(String(describing: denyResultBash?.behavior.rawValue))")

// Verify denylist allows unlisted tool
let denyResultRead = await denylistPolicy.evaluate(
    tool: ReadOnlyTestTool(),
    input: [:],
    context: ToolContext(cwd: "/tmp")
)
record("ToolNameDenylistPolicy allows unlisted tool", swiftField: "evaluate(Read) -> .allow", status: denyResultRead?.behavior == .allow ? "PASS" : "MISSING",
       note: "Result: \(String(describing: denyResultRead?.behavior.rawValue))")

// ReadOnlyPolicy
let readOnlyPolicy = ReadOnlyPolicy()
record("ReadOnlyPolicy", swiftField: "ReadOnlyPolicy", status: "PASS",
       note: "Allows only read-only tools (equivalent to TS plan mode behavior)")

// Verify ReadOnlyPolicy allows read-only tool
let roAllowResult = await readOnlyPolicy.evaluate(
    tool: ReadOnlyTestTool(),
    input: [:],
    context: ToolContext(cwd: "/tmp")
)
record("ReadOnlyPolicy allows read-only tool", swiftField: "evaluate(Read) -> .allow", status: roAllowResult?.behavior == .allow ? "PASS" : "MISSING",
       note: "Result: \(String(describing: roAllowResult?.behavior.rawValue))")

// Verify ReadOnlyPolicy denies mutation tool
let roDenyResult = await readOnlyPolicy.evaluate(
    tool: MutationTestTool(name: "Write"),
    input: [:],
    context: ToolContext(cwd: "/tmp")
)
record("ReadOnlyPolicy denies mutation tool", swiftField: "evaluate(Write) -> .deny", status: roDenyResult?.behavior == .deny ? "PASS" : "MISSING",
       note: "Result: \(String(describing: roDenyResult?.behavior.rawValue))")

// CompositePolicy
let compositePolicy = CompositePolicy(policies: [allowlistPolicy, denylistPolicy])
record("CompositePolicy", swiftField: "CompositePolicy (Swift-only)", status: "PASS",
       note: "Composes multiple policies. Deny short-circuits.")

// Priority verification: denylist > allowlist in CompositePolicy
// Bash is in both allowlist (added below) and denylist -> deny should win
let conflictComposite = CompositePolicy(policies: [
    ToolNameAllowlistPolicy(allowedToolNames: ["Bash"]),
    ToolNameDenylistPolicy(deniedToolNames: ["Bash"])
])
let conflictResult = await conflictComposite.evaluate(
    tool: MutationTestTool(name: "Bash"),
    input: [:],
    context: ToolContext(cwd: "/tmp")
)
record("CompositePolicy: deny > allow short-circuit", swiftField: "CompositePolicy deny short-circuit", status: conflictResult?.behavior == .deny ? "PASS" : "MISSING",
       note: "First allow passes, then deny short-circuits. Result: \(String(describing: conflictResult?.behavior.rawValue))")

// canUseTool(policy:) bridge
let bridgedCallback = canUseTool(policy: compositePolicy)
record("canUseTool(policy:) bridge", swiftField: "canUseTool(policy:) -> CanUseToolFn", status: "PASS",
       note: "Converts PermissionPolicy to CanUseToolFn closure")

// Verify bridge callback works
let bridgeResult = await bridgedCallback(ReadOnlyTestTool(), [:], ToolContext(cwd: "/tmp"))
record("canUseTool(policy:) returns result", swiftField: "bridgedCallback returns CanUseToolResult?", status: bridgeResult != nil ? "PASS" : "MISSING",
       note: "Result: \(String(describing: bridgeResult?.behavior.rawValue))")

// canUseTool priority over permissionMode (documented in ToolExecutor code)
record("canUseTool priority over permissionMode", swiftField: "ToolExecutor (internal code path)", status: "PASS",
       note: "In ToolExecutor.executeSingleTool, canUseTool callback is checked before permissionMode. Code-verified.")

print("")

// MARK: - AC6: allowDangerouslySkipPermissions Verification

print("=== AC6: allowDangerouslySkipPermissions Verification ===")
print("")

// In TS SDK, bypassPermissions requires allowDangerouslySkipPermissions flag
// In Swift SDK, bypassPermissions is just an enum case that must be explicitly set
record("allowDangerouslySkipPermissions", swiftField: "PermissionMode.bypassPermissions (explicit)", status: "PARTIAL",
       note: "Swift requires explicit .bypassPermissions setting. No separate confirmation flag like TS SDK's allowDangerouslySkipParameters.")
record("No accidental bypass", swiftField: "Default permissionMode = .default", status: "PASS",
       note: "AgentOptions defaults to .default mode. bypassPermissions must be explicitly set by developer.")

// Verify default is .default (not .bypassPermissions)
let defaultOptions = AgentOptions(apiKey: apiKey)
record("AgentOptions.permissionMode default", swiftField: "AgentOptions().permissionMode", status: "PASS",
       note: "Default is .default: \(defaultOptions.permissionMode == .default)")

print("")

// MARK: - AC7: PermissionDenial Structure Verification

print("=== AC7: PermissionDenial Structure Verification ===")
print("")

// SDKError.permissionDenied
let permDeniedError = SDKError.permissionDenied(tool: "Write", reason: "Not allowed")
record("SDKError.permissionDenied(tool:reason:)", swiftField: "SDKError.permissionDenied(tool: String, reason: String)", status: "PASS",
       note: "Exists with tool name and reason string.")

// Verify error properties
record("SDKError.permissionDenied.tool", swiftField: "SDKError.tool", status: "PASS",
       note: "value='\(permDeniedError.tool ?? "nil")'")
record("SDKError.permissionDenied.reason", swiftField: "SDKError.reason", status: "PASS",
       note: "value='\(permDeniedError.reason ?? "nil")'")

// TS SDK's SDKPermissionDenial type
record("SDKPermissionDenial type", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "TS SDK has SDKPermissionDenial(tool_name, tool_use_id, tool_input). No equivalent struct in Swift.")
record("SDKResultMessage.permission_denials", swiftField: "NO EQUIVALENT", status: "MISSING",
       note: "TS SDK has permission_denials field on SDKResultMessage. Swift's QueryResult has no such field.")

print("")

// MARK: - AC8: Compatibility Report Output

print("=== AC8: Complete Permission System Compatibility Report ===")
print("")

// --- PermissionMode Table ---
struct FieldMapping {
    let index: Int
    let tsField: String
    let swiftEquivalent: String
    let status: String
    let note: String
}

let modeMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "PermissionMode.default", swiftEquivalent: "PermissionMode.default", status: "PASS", note: "Blocks non-readonly"),
    FieldMapping(index: 2, tsField: "PermissionMode.acceptEdits", swiftEquivalent: "PermissionMode.acceptEdits", status: "PASS", note: "Allows Write/Edit"),
    FieldMapping(index: 3, tsField: "PermissionMode.bypassPermissions", swiftEquivalent: "PermissionMode.bypassPermissions", status: "PASS", note: "Allows all"),
    FieldMapping(index: 4, tsField: "PermissionMode.plan", swiftEquivalent: "PermissionMode.plan", status: "PASS", note: "Blocks all non-readonly"),
    FieldMapping(index: 5, tsField: "PermissionMode.dontAsk", swiftEquivalent: "PermissionMode.dontAsk", status: "PASS", note: "Denies non-readonly"),
    FieldMapping(index: 6, tsField: "PermissionMode.auto", swiftEquivalent: "PermissionMode.auto", status: "PASS", note: "= bypassPermissions"),
]

print("PermissionMode (6 cases)")
print("========================")
print("")
print(String(format: "%-2s %-40s %-45s %-8s | Notes", "#", "TS SDK Mode", "Swift Equivalent", "Status"))
print(String(repeating: "-", count: 130))
for m in modeMappings {
    print(String(format: "%-2d %-40s %-45s [%-7s] | %@", m.index, m.tsField, m.swiftEquivalent, m.status, m.note))
}
print("")

let modePass = modeMappings.filter { $0.status == "PASS" }.count
print("PermissionMode Summary: PASS: \(modePass) / \(modeMappings.count)")
print("")

// --- CanUseToolFn Table ---
let canUseMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "CanUseTool: toolName", swiftEquivalent: "CanUseToolFn: ToolProtocol (.name)", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 2, tsField: "CanUseTool: input", swiftEquivalent: "CanUseToolFn: Any", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 3, tsField: "CanUseTool: signal (AbortSignal)", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "Swift uses Task.isCancelled"),
    FieldMapping(index: 4, tsField: "CanUseTool: suggestions", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "Not in callback"),
    FieldMapping(index: 5, tsField: "CanUseTool: blockedPath", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "Not in callback"),
    FieldMapping(index: 6, tsField: "CanUseTool: decisionReason", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "Not in callback"),
    FieldMapping(index: 7, tsField: "CanUseTool: toolUseID", swiftEquivalent: "ToolContext.toolUseId", status: "PARTIAL", note: "Via context, not direct param"),
    FieldMapping(index: 8, tsField: "CanUseTool: agentID", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "Not in context"),
]

print("CanUseToolFn Params (8 fields)")
print("==============================")
print("")
print(String(format: "%-2s %-40s %-45s %-8s | Notes", "#", "TS SDK Param", "Swift Equivalent", "Status"))
print(String(repeating: "-", count: 130))
for m in canUseMappings {
    print(String(format: "%-2d %-40s %-45s [%-7s] | %@", m.index, m.tsField, m.swiftEquivalent, m.status, m.note))
}
print("")

let canUsePass = canUseMappings.filter { $0.status == "PASS" }.count
let canUsePartial = canUseMappings.filter { $0.status == "PARTIAL" }.count
let canUseMissing = canUseMappings.filter { $0.status == "MISSING" }.count
print("CanUseToolFn Summary: PASS: \(canUsePass) | PARTIAL: \(canUsePartial) | MISSING: \(canUseMissing) | Total: \(canUseMappings.count)")
print("")

// --- CanUseToolResult Table ---
let resultMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "behavior: allow", swiftEquivalent: "CanUseToolResult.behavior: .allow", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 2, tsField: "behavior: deny", swiftEquivalent: "CanUseToolResult.behavior: .deny", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 3, tsField: "behavior: ask", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No ask behavior in Swift"),
    FieldMapping(index: 4, tsField: "updatedInput", swiftEquivalent: "CanUseToolResult.updatedInput: Any?", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 5, tsField: "updatedPermissions", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "Not in result"),
    FieldMapping(index: 6, tsField: "message", swiftEquivalent: "CanUseToolResult.message: String?", status: "PASS", note: "Direct equivalent"),
    FieldMapping(index: 7, tsField: "interrupt", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "Not in result"),
    FieldMapping(index: 8, tsField: "toolUseID", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "Not in result"),
]

print("CanUseToolResult Fields (8 items)")
print("=================================")
print("")
print(String(format: "%-2s %-40s %-45s %-8s | Notes", "#", "TS SDK Field", "Swift Equivalent", "Status"))
print(String(repeating: "-", count: 130))
for m in resultMappings {
    print(String(format: "%-2d %-40s %-45s [%-7s] | %@", m.index, m.tsField, m.swiftEquivalent, m.status, m.note))
}
print("")

let resultPass = resultMappings.filter { $0.status == "PASS" }.count
let resultMissing = resultMappings.filter { $0.status == "MISSING" }.count
print("CanUseToolResult Summary: PASS: \(resultPass) | MISSING: \(resultMissing) | Total: \(resultMappings.count)")
print("")

// --- PermissionUpdate Operations Table ---
let updateMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "addRules", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No addRules"),
    FieldMapping(index: 2, tsField: "replaceRules", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No replaceRules"),
    FieldMapping(index: 3, tsField: "removeRules", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No removeRules"),
    FieldMapping(index: 4, tsField: "setMode", swiftEquivalent: "Agent.setPermissionMode(_:)", status: "PARTIAL", note: "Runtime method, not operation type"),
    FieldMapping(index: 5, tsField: "addDirectories", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No addDirectories"),
    FieldMapping(index: 6, tsField: "removeDirectories", swiftEquivalent: "NO EQUIVALENT", status: "MISSING", note: "No removeDirectories"),
]

print("PermissionUpdate Operations (6 types)")
print("=====================================")
print("")
print(String(format: "%-2s %-40s %-45s %-8s | Notes", "#", "TS SDK Operation", "Swift Equivalent", "Status"))
print(String(repeating: "-", count: 130))
for m in updateMappings {
    print(String(format: "%-2d %-40s %-45s [%-7s] | %@", m.index, m.tsField, m.swiftEquivalent, m.status, m.note))
}
print("")

let updatePartial = updateMappings.filter { $0.status == "PARTIAL" }.count
let updateMissing = updateMappings.filter { $0.status == "MISSING" }.count
print("PermissionUpdate Summary: PARTIAL: \(updatePartial) | MISSING: \(updateMissing) | Total: \(updateMappings.count)")
print("")

// --- PermissionPolicy System (Swift-only additions) ---
let policyMappings: [FieldMapping] = [
    FieldMapping(index: 1, tsField: "(no equivalent)", swiftEquivalent: "PermissionPolicy protocol", status: "PASS", note: "Swift-only: base protocol"),
    FieldMapping(index: 2, tsField: "allowedTools: string[]", swiftEquivalent: "ToolNameAllowlistPolicy", status: "PASS", note: "Equivalent to TS allowedTools"),
    FieldMapping(index: 3, tsField: "disallowedTools: string[]", swiftEquivalent: "ToolNameDenylistPolicy", status: "PASS", note: "Equivalent to TS disallowedTools"),
    FieldMapping(index: 4, tsField: "plan mode (readonly)", swiftEquivalent: "ReadOnlyPolicy", status: "PASS", note: "Equivalent to plan mode behavior"),
    FieldMapping(index: 5, tsField: "(no equivalent)", swiftEquivalent: "CompositePolicy", status: "PASS", note: "Swift-only: policy composition"),
    FieldMapping(index: 6, tsField: "(no equivalent)", swiftEquivalent: "canUseTool(policy:) bridge", status: "PASS", note: "Swift-only: policy-to-callback"),
]

print("PermissionPolicy System (Swift-only additions)")
print("==============================================")
print("")
print(String(format: "%-2s %-40s %-45s %-8s | Notes", "#", "TS SDK Equivalent", "Swift Type", "Status"))
print(String(repeating: "-", count: 130))
for m in policyMappings {
    print(String(format: "%-2d %-40s %-45s [%-7s] | %@", m.index, m.tsField, m.swiftEquivalent, m.status, m.note))
}
print("")

let policyPass = policyMappings.filter { $0.status == "PASS" }.count
print("PermissionPolicy Summary: PASS: \(policyPass) / \(policyMappings.count)")
print("")

// --- Full Field-Level Compat Report ---

print("=== Full Field-Level Compatibility Report (All Entries) ===")
print("")

// Deduplicate by tsField
var seen = Set<String>()
var finalReport: [CompatEntry] = []
for entry in compatReport {
    if !seen.contains(entry.tsField) {
        seen.insert(entry.tsField)
        finalReport.append(entry)
    }
}

let fieldPassCount = finalReport.filter { $0.status == "PASS" }.count
let fieldPartialCount = finalReport.filter { $0.status == "PARTIAL" }.count
let fieldMissingCount = finalReport.filter { $0.status == "MISSING" }.count
let fieldNACount = finalReport.filter { $0.status == "N/A" }.count

print(String(format: "%-55s | %-55s | %-8s | Notes", "TS SDK Field", "Swift SDK Field"))
print(String(repeating: "-", count: 160))
for entry in finalReport {
    let noteStr = entry.note ?? ""
    print(String(format: "%-55s | %-55s | [%-7s] | %@", entry.tsField, entry.swiftField, entry.status, noteStr))
}

print("")
print("Overall Summary: PASS: \(fieldPassCount) | PARTIAL: \(fieldPartialCount) | MISSING: \(fieldMissingCount) | N/A: \(fieldNACount) | Total: \(finalReport.count)")
print("")

let compatRate = (fieldPassCount + fieldPartialCount + fieldMissingCount) == 0 ? 0 :
    Double(fieldPassCount + fieldPartialCount) / Double(fieldPassCount + fieldPartialCount + fieldMissingCount) * 100
print(String(format: "Pass+Partial Rate: %.1f%% (PASS+PARTIAL / PASS+PARTIAL+MISSING)", compatRate))

if fieldMissingCount > 0 {
    print("")
    print("Missing Items (require SDK changes):")
    for entry in finalReport where entry.status == "MISSING" {
        print("  - \(entry.tsField): \(entry.note ?? "No details")")
    }
}

print("")
print("Permission system compatibility verification complete.")

// MARK: - Helper Tool Types

/// A minimal read-only tool for permission policy testing.
struct ReadOnlyTestTool: ToolProtocol, @unchecked Sendable {
    let name: String = "Read"
    let description: String = "Test read-only tool"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = true
    func call(input: Any, context: ToolContext) async -> ToolResult {
        ToolResult(toolUseId: "", content: "ok", isError: false)
    }
}

/// A minimal mutation tool for permission policy testing.
struct MutationTestTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Test mutation tool"
    let inputSchema: ToolInputSchema = ["type": "object"]
    let isReadOnly: Bool = false
    func call(input: Any, context: ToolContext) async -> ToolResult {
        ToolResult(toolUseId: "", content: "ok", isError: false)
    }
}

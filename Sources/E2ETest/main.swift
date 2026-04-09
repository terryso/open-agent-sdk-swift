import Foundation
import OpenAgentSDK

// MARK: - Entry Point

let dotEnv = loadDotEnv()

print("=== OpenAgentSDK E2E Test Suite ===\n")

guard let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv), !apiKey.isEmpty else {
    print("ERROR: CODEANY_API_KEY not set")
    print("Create a .env file or set environment variables:")
    print("  CODEANY_API_KEY=your-key")
    print("  CODEANY_BASE_URL=https://your-proxy.com")
    print("  CODEANY_MODEL=glm-5.1")
    print("\nThen run: swift run E2ETest")
    exit(1)
}

let baseURL = getEnv("CODEANY_BASE_URL", from: dotEnv) ?? "https://api.openai.com"
let model = getEnv("CODEANY_MODEL", from: dotEnv) ?? "glm-5.1"

print("Config:")
print("  Model:    \(model)")
print("  Base URL: \(baseURL)")
print("  API Key:  \(String(apiKey.prefix(8)))...\n")

// ================================================================
// SECTION 1-4: Basic Agent Operations
// ================================================================
await BasicAgentTests.run(apiKey: apiKey, model: model, baseURL: baseURL)

// ================================================================
// SECTION 5-8: Tool Execution
// ================================================================
await ToolExecutionTests.run(apiKey: apiKey, model: model, baseURL: baseURL)

// ================================================================
// SECTION 9-10: Budget & Limits
// ================================================================
await BudgetAndLimitsTests.run(apiKey: apiKey, model: model, baseURL: baseURL)

// ================================================================
// SECTION 11-12: Error Handling
// ================================================================
await ErrorHandlingTests.run(baseURL: baseURL)

// ================================================================
// SECTION 13-14: Token & Cost Tracking
// ================================================================
await TrackingTests.run(apiKey: apiKey, model: model, baseURL: baseURL)

// ================================================================
// SECTION 15-16: Tool Registry & Assembly
// ================================================================
ToolRegistryTests.run()

// ================================================================
// MCP Resource Tools (ListMcpResources, ReadMcpResource)
// ================================================================
await McpResourceToolTests.run()

// ================================================================
// MCP Client Manager & Stdio Transport (Story 6-1)
// ================================================================
await MCPClientManagerE2ETests.run()

// SECTION 17-20, 24, 26, 28, 30: Store Operations (incl. WorktreeStore, PlanStore, CronStore, TodoStore)
await StoreTests.run()

// ================================================================
// SECTION 34: SessionStore JSON Persistence (Story 7-1)
// ================================================================
await SessionStoreE2ETests.run()

// ================================================================
// SECTION 35: Session Load & Restore (Story 7-2)
// ================================================================
await SessionRestoreE2ETests.run(apiKey: apiKey, model: model, baseURL: baseURL)

// ================================================================
// SECTION 36: Session Fork (Story 7-3)
// ================================================================
await SessionForkE2ETests.run(apiKey: apiKey, model: model, baseURL: baseURL)

// ================================================================
// SECTION 37: Session Management (Story 7-4)
// ================================================================
await SessionManagementE2ETests.run()

// ================================================================
// SECTION 23, 25, 27, 29, 31, 32, 33: Agent with Stores Integration (incl. LLM-driven TodoWrite, direct handler tests)
// ================================================================
await SDKMessageTests.run(apiKey: apiKey, model: model, baseURL: baseURL)

// ================================================================
// SECTION 22: No-Input Tool
// ================================================================
await NoInputToolTests.run(apiKey: apiKey, model: model, baseURL: baseURL)

// ================================================================
// SECTION 23, 25, 27, 29, 31, 32, 33: Agent with Stores Integration (incl. LLM-driven TodoWrite, direct handler tests)
// ================================================================
await IntegrationTests.run(apiKey: apiKey, model: model, baseURL: baseURL)

// ================================================================
// SECTION 38: HookRegistry (Story 8-1)
// ================================================================
await HookRegistryE2ETests.run()

// ================================================================
// SECTION 39: Hook Integration (Story 8-2)
// ================================================================
await HookIntegrationE2ETests.run(apiKey: apiKey, model: model, baseURL: baseURL)

// ================================================================
// SECTION 40: Shell Hook Execution (Story 8-3)
// ================================================================
await ShellHookExecutionE2ETests.run()

// ================================================================
// Results Summary
// ================================================================
print("\n=== E2E Test Results ===")
print("  Total:  \(Stats.total)")
print("  Passed: \(Stats.passed)")
print("  Failed: \(Stats.failed)")
if Stats.failed == 0 {
    print("\n  All tests passed!")
} else {
    print("\n  \(Stats.failed) test(s) FAILED")
}
print("=== Complete ===")

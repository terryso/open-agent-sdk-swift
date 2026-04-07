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

// SECTION 17-20, 24, 26, 28, 30: Store Operations (incl. WorktreeStore, PlanStore, CronStore, TodoStore)
await StoreTests.run()

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

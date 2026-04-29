// ModelSwitchingExample 示例
//
// 演示如何在运行时动态切换 LLM 模型，包括：
//   1. 使用默认模型（claude-sonnet-4-6）创建 Agent 并执行查询
//   2. 使用 agent.switchModel() 切换到不同模型（claude-opus-4-6）
//   3. 查看每个模型的 costBreakdown（per-model token counts 和 cost）
//   4. 错误处理：传入空字符串时抛出 SDKError.invalidConfiguration
//
// Demonstrates runtime dynamic model switching with the SDK:
//   1. Create Agent with default model (claude-sonnet-4-6) and execute a query
//   2. Switch models at runtime using agent.switchModel("claude-opus-4-6")
//   3. Inspect per-model cost breakdown (CostBreakdownEntry) from QueryResult
//   4. Error handling: SDKError.invalidConfiguration for empty model name
//
// 运行方式：swift run ModelSwitchingExample
// 说明：需要有效的 API Key（支持 claude-sonnet-4-6 和 claude-opus-4-6）

import Foundation
import OpenAgentSDK

// MARK: - 配置 API Key

let dotEnv = loadDotEnv()
let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
    ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
    ?? "sk-..."
let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil
let secondModel = useOpenAI ? "glm-4-plus" : "claude-opus-4-6"

print("=== ModelSwitchingExample ===")
print()

// MARK: - Part 1: Model Switching and Cost Tracking（模型切换与成本跟踪）

print("--- Part 1: Model Switching and Cost Tracking ---")
print()

// 创建 Agent，使用默认模型
let agent = createAgent(options: AgentOptions(
    apiKey: apiKey,
    model: defaultModel,
    baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : nil,
    provider: useOpenAI ? .openai : .anthropic,
    permissionMode: .bypassPermissions
))

print("[Agent created with model: \(agent.model)]")
assert(agent.model == defaultModel, "Agent model should match default model")
print("✅ Agent model == \(defaultModel): PASS")
print()

// 使用默认模型执行第一个查询（简单问题，适合快速/便宜模型）
// Execute first query with default model (simple question for fast/cheap model)
print("[Executing first query with \(agent.model)...]")
let result1 = await agent.prompt("What is 2 + 3? Reply with just the number.")

print()
print("=== Query 1 Result (model: \(agent.model)) ===")
print("Answer: \(result1.text.prefix(200))")
print("Input tokens:  \(result1.usage.inputTokens)")
print("Output tokens: \(result1.usage.outputTokens)")
print("Total cost:    $\(String(format: "%.6f", result1.totalCostUsd))")
print()

// 显示第一次查询的 costBreakdown（per-model entries）
// Display cost breakdown for first query (per-model entries)
print("Cost Breakdown:")
for entry in result1.costBreakdown {
    print("  Model: \(entry.model)")
    print("    Input tokens:  \(entry.inputTokens)")
    print("    Output tokens: \(entry.outputTokens)")
    print("    Cost:          $\(String(format: "%.6f", entry.costUsd))")
}
if result1.costBreakdown.isEmpty {
    print("⚠️ Cost breakdown is empty (API may not report usage)")
} else {
    print("✅ Cost breakdown entries: \(result1.costBreakdown.count)")
}
print()

// 切换到第二个模型
// Switch to second model
print("[Switching model to \(secondModel)...]")
do {
    try agent.switchModel(secondModel)
} catch {
    print("❌ Failed to switch model: \(error)")
    fatalError("Model switch to \(secondModel) should not fail")
}
print("[Agent model after switch: \(agent.model)]")
assert(agent.model == secondModel, "Agent model should be \(secondModel) after switch")
print("✅ Model switched to \(secondModel): PASS")
print()

// 使用新模型执行第二个查询（推理密集型问题）
// Execute second query with opus model (reasoning-heavy question)
print("[Executing second query with \(agent.model)...]")
let result2 = await agent.prompt("Explain the difference between structs and classes in Swift in 2-3 sentences.")

print()
print("=== Query 2 Result (model: \(agent.model)) ===")
print("Answer: \(result2.text.prefix(300))")
print("Input tokens:  \(result2.usage.inputTokens)")
print("Output tokens: \(result2.usage.outputTokens)")
print("Total cost:    $\(String(format: "%.6f", result2.totalCostUsd))")
print()

// 显示第二次查询的 costBreakdown
// Display cost breakdown for second query
print("Cost Breakdown:")
for entry in result2.costBreakdown {
    print("  Model: \(entry.model)")
    print("    Input tokens:  \(entry.inputTokens)")
    print("    Output tokens: \(entry.outputTokens)")
    print("    Cost:          $\(String(format: "%.6f", entry.costUsd))")
}
if result2.costBreakdown.isEmpty {
    print("⚠️ Cost breakdown is empty (API may not report usage)")
} else {
    print("✅ Cost breakdown entries: \(result2.costBreakdown.count)")
}
print()

// 比较两个模型的成本
// Compare costs between models
print("=== Cost Comparison ===")
print("Query 1 (\(result1.costBreakdown.first?.model ?? "unknown")): $\(String(format: "%.6f", result1.totalCostUsd))")
print("Query 2 (\(result2.costBreakdown.first?.model ?? "unknown")): $\(String(format: "%.6f", result2.totalCostUsd))")
print("✅ Model switching and cost tracking: PASS")
print()

// MARK: - Part 2: Error Handling（错误处理）

print("--- Part 2: Error Handling ---")
print()

// 保存当前模型名用于验证
// Save current model name for verification
let modelBeforeError = agent.model
print("[Current model before error test: \(modelBeforeError)]")

// 尝试切换到空字符串模型 -- 应该抛出 SDKError.invalidConfiguration
// Try switching to empty model name -- should throw SDKError.invalidConfiguration
print("[Attempting agent.switchModel(\"\") -- expecting error...]")
do {
    try agent.switchModel("")
    // 如果没有抛出异常，说明测试失败
    print("❌ FAIL: switchModel(\"\") should have thrown an error")
    assertionFailure("switchModel(\"\") should have thrown SDKError.invalidConfiguration")
} catch let error as SDKError {
    if case .invalidConfiguration(let msg) = error {
        print("Caught SDKError.invalidConfiguration: \(msg)")
        assert(msg.contains("empty") || msg.contains("Empty"), "Error message should mention empty model")
        print("✅ Correct error type and message: PASS")
    } else {
        print("❌ FAIL: Caught SDKError but wrong case: \(error)")
    }
} catch {
    print("❌ FAIL: Caught unexpected error type: \(error)")
}

// 验证 Agent 的模型在失败后没有改变
// Verify Agent's model is unchanged after the failed switch
print("[Model after failed switch: \(agent.model)]")
assert(agent.model == modelBeforeError, "Model should be unchanged after failed switch")
print("✅ Model unchanged after error: PASS")
print()

print("=== ModelSwitchingExample Complete ===")

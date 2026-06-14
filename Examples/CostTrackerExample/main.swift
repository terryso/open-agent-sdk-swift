// CostTrackerExample
//
// Demonstrates runtime cost tracking and trace recording for LLM API calls:
//   1. CostTracker: track token usage, estimate cost, enforce budget limits
//   2. TraceRecorder: record execution events as JSONL for observability
//   3. AgentOptions integration: enable via maxBudgetUsd and traceEnabled
//   4. CostSummary: per-model breakdowns and totals
//
// Run: swift run CostTrackerExample
// Note: Part 1-3 are pure API calls, no API key needed; Part 4 needs ANTHROPIC_API_KEY

import Foundation
import OpenAgentSDK

@main
struct CostTrackerExample {
    static func main() async throws {
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║  CostTracker & TraceRecorder Example                        ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print()

        part1_CostTracker()
        try await part2_TraceRecorder()
        part3_BudgetEnforcement()
        try await part4_AgentIntegration()
    }

    // MARK: - Part 1: CostTracker

    static func part1_CostTracker() {
        print("--- Part 1: CostTracker ---")
        print()

        var tracker = CostTracker(model: "claude-sonnet-4-6")

        // Simulate multiple API calls
        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 1500, outputTokens: 800))
        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 2000, outputTokens: 1200))

        // Mixed-model usage (e.g., fallback to haiku)
        tracker.recordUsage(model: "claude-haiku-4-5", usage: TokenUsage(inputTokens: 500, outputTokens: 300))

        let summary = tracker.getSummary()
        print("  Model calls:    \(summary.modelCalls)")
        print("  Total tokens:   \(summary.totalTokens)")
        print("  Estimated cost: $\(String(format: "%.6f", summary.estimatedCostUsd))")
        print()
        print("  Per-model breakdown:")
        for entry in summary.costBreakdown {
            print("    \(entry.model):")
            print("      input=\(entry.inputTokens) output=\(entry.outputTokens) cost=$\(String(format: "%.6f", entry.estimatedCostUsd))")
        }
        print()
    }

    // MARK: - Part 2: TraceRecorder

    static func part2_TraceRecorder() async throws {
        print("--- Part 2: TraceRecorder ---")
        print()

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("openagent-trace-example-\(ProcessInfo.processInfo.processIdentifier)")

        let recorder = try TraceRecorder(runId: "demo-run", baseURL: tmpDir)

        // Record agent lifecycle events
        await recorder.record(event: "run_start", payload: [
            "model": "claude-sonnet-4-6",
            "task": "Summarize this document"
        ])

        await recorder.record(event: "step_start", payload: [
            "tool": "Read",
            "toolUseId": "tu_001"
        ])

        await recorder.record(event: "step_done", payload: [
            "tool": "Read",
            "toolUseId": "tu_001",
            "success": true
        ])

        // Sensitive data is automatically sanitized
        await recorder.record(event: "api_call", payload: [
            "model": "claude-sonnet-4-6",
            "apiKey": "sk-ant-secret-key-12345",  // Will be stripped
            "tokens": 1500
        ])

        await recorder.record(event: "run_done", payload: [
            "status": "success",
            "totalSteps": 3,
            "durationMs": 4500
        ])

        await recorder.close()

        // Read back the trace file
        let traceFile = tmpDir.appendingPathComponent("demo-run/trace.jsonl")
        if let content = try? String(contentsOf: traceFile) {
            print("  Trace output (\(traceFile.path)):")
            for line in content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n") {
                print("    \(line)")
            }
        }
        print()

        // Cleanup
        try? FileManager.default.removeItem(at: tmpDir)
    }

    // MARK: - Part 3: Budget Enforcement

    static func part3_BudgetEnforcement() {
        print("--- Part 3: Budget Enforcement ---")
        print()

        var tracker = CostTracker(model: "claude-sonnet-4-6", maxBudgetUsd: 0.01)

        // Within budget
        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 1000, outputTokens: 500))
        let check1 = tracker.checkBudget()
        print("  After 1500 tokens: \(describeBudget(check1))")

        // Exceed budget with heavy usage
        tracker.recordUsage(model: "claude-sonnet-4-6", usage: TokenUsage(inputTokens: 50000, outputTokens: 30000))
        let check2 = tracker.checkBudget()
        print("  After 81500 tokens: \(describeBudget(check2))")

        let summary = tracker.getSummary()
        print("  Total cost: $\(String(format: "%.6f", summary.estimatedCostUsd)) (limit: $0.010000)")
        print()
    }

    // MARK: - Part 4: Agent Integration

    static func part4_AgentIntegration() async throws {
        print("--- Part 4: Agent Integration ---")
        print()

        let dotEnv = loadDotEnv()
        let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
            ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
            ?? ""
        guard !apiKey.isEmpty else {
            print("  Skipping: set CODEANY_API_KEY or ANTHROPIC_API_KEY to run this part")
            print()
            print("  Usage:")
            print("    ANTHROPIC_API_KEY=sk-... ANTHROPIC_MODEL=claude-sonnet-4-6 swift run CostTrackerExample")
            print("    CODEANY_API_KEY=sk-... CODEANY_MODEL=glm-5.1 swift run CostTrackerExample")
            print()
            return
        }
        let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil
        let model = getEnv("ANTHROPIC_MODEL", from: dotEnv)
            ?? getEnv("CODEANY_MODEL", from: dotEnv)
            ?? "claude-sonnet-4-6"

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("openagent-agent-trace-\(ProcessInfo.processInfo.processIdentifier)")

        let agent = Agent(options: AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : getDefaultAnthropicBaseURL(from: dotEnv),
            provider: useOpenAI ? .openai : .anthropic,
            maxBudgetUsd: 0.50,
            traceEnabled: true
        ))

        print("  Agent configured with:")
        print("    model: \(model)")
        print("    maxBudgetUsd: $0.50")
        print("    traceEnabled: true")
        print()
        print("  Running: \"What is 2+2? Answer briefly.\"")

        let messages = agent.stream("What is 2+2? Answer briefly.")
        for await message in messages {
            switch message {
            case .result(let data):
                print("  Result: \(data.subtype.rawValue)")
                print("  Cost: $\(String(format: "%.6f", data.totalCostUsd))")
                print("  Steps: \(data.numTurns)")
                print("  Duration: \(data.durationMs)ms")
            default:
                break
            }
        }
        print()

        // Cleanup trace files
        try? FileManager.default.removeItem(at: tmpDir)
    }

    // MARK: - Helpers

    static func describeBudget(_ result: BudgetCheckResult) -> String {
        switch result {
        case .ok:
            return "within budget"
        case .budgetExceeded(let current, let limit):
            return "EXCEEDED ($\(String(format: "%.6f", current)) / $\(String(format: "%.2f", limit)))"
        }
    }
}

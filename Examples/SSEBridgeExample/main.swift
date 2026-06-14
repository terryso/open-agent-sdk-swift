// SSEBridgeExample
//
// Demonstrates the SSE Bridge pipeline (Epic 28):
//   EventBus → EventBusBridge → EventBroadcaster → SSE event stream
//
// Also shows real-time token streaming via LLMTokenStreamEvent.
//
// Run: swift run SSEBridgeExample
// Prerequisite: set CODEANY_API_KEY or ANTHROPIC_API_KEY in .env or environment

import Foundation
import OpenAgentSDK

@main
struct SSEBridgeExample {
    static func main() async throws {
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║  SSE Bridge Example — EventBus → SSE Pipeline              ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print()

        let dotEnv = loadDotEnv()
        let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
            ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
            ?? ""
        guard !apiKey.isEmpty else {
            print("  Skipping: set CODEANY_API_KEY or ANTHROPIC_API_KEY to run this example")
            print()
            print("  Usage:")
            print("    ANTHROPIC_API_KEY=sk-... swift run SSEBridgeExample")
            print()
            return
        }

        let defaultModel = getEnv("ANTHROPIC_MODEL", from: dotEnv)
            ?? getEnv("CODEANY_MODEL", from: dotEnv)
            ?? "claude-sonnet-4-6"
        let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

        // ── 1. Build the SSE pipeline ──────────────────────────────

        let eventBus = EventBus()
        let broadcaster = EventBroadcaster()
        let runId = "run-\(UUID().uuidString.prefix(8))"
        let bridge = EventBusBridge(eventBus: eventBus, broadcaster: broadcaster, runId: runId)

        // ── 2. Subscribe to raw EventBus events ───────────────────

        let (_, rawStream) = await eventBus.subscribe()

        // ── 3. Subscribe to SSE events via EventBroadcaster ───────

        let sseStream = await broadcaster.subscribe(runId: runId)

        // ── 4. Start the bridge (EventBus → Broadcaster) ──────────

        await bridge.start {
            print("  [Bridge] Run completed — bridge stopped")
        }

        print("  Pipeline: EventBus → EventBusBridge → EventBroadcaster")
        print("  Run ID:   \(runId)")
        print()

        // ── 5. Background: print raw EventBus events ──────────────

        let rawPrinter = _Concurrency.Task {
            var count = 0
            for await event in rawStream {
                count += 1
                printRawEvent(event, index: count)
            }
        }

        // ── 6. Background: print SSE events ───────────────────────

        let ssePrinter = _Concurrency.Task {
            var seqId = 0
            for await event in sseStream {
                seqId += 1
                if let sseText = try? event.encodeToSSE(sequenceId: seqId) {
                    print("  [SSE #\(seqId)] \(sseText.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        }

        // ── 7. Create Agent with EventBus + token streaming ───────

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey,
            model: defaultModel,
            baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : getDefaultAnthropicBaseURL(from: dotEnv),
            provider: useOpenAI ? .openai : .anthropic,
            systemPrompt: "You are a helpful assistant.",
            permissionMode: .bypassPermissions,
            eventBus: eventBus,
            emitTokenStream: true
        ))

        print("  --- Agent Running ---")
        print("  Prompt: \"Tell me a short fun fact about Swift programming.\"")
        print("  (watch raw EventBus events + SSE events arrive in parallel)")
        print()

        // ── 8. Run the agent ──────────────────────────────────────

        let result = await agent.prompt("Tell me a short fun fact about Swift programming.")

        // Give events time to drain
        try await _Concurrency.Task.sleep(for: .milliseconds(300))
        rawPrinter.cancel()
        ssePrinter.cancel()

        // ── 9. Summary ────────────────────────────────────────────

        print()
        print("  --- Agent Result ---")
        print("  Status:    \(result.status)")
        print("  Turns:     \(result.numTurns)")
        print("  Cost:      $\(String(format: "%.6f", result.totalCostUsd))")
        print("  Response:  \(result.text.prefix(200))")
        print()

        let replayEvents = await broadcaster.getReplayBuffer(runId: runId)
        print("  SSE replay buffer: \(replayEvents.count) events stored")
        for (i, event) in replayEvents.enumerated() {
            print("    [\(i + 1)] \(event.eventType)")
        }
        print()
    }

    // MARK: - Helpers

    static func printRawEvent(_ event: any AgentEvent, index: Int) {
        let tag = String(format: "%3d", index)
        switch event {
        case let e as SessionCreatedEvent:
            print("  [Raw #\(tag)] SessionCreated: task=\"\(e.task)\", model=\(e.model)")
        case let e as AgentStartedEvent:
            print("  [Raw #\(tag)] AgentStarted: task=\"\(e.task)\"")
        case let e as AgentCompletedEvent:
            print("  [Raw #\(tag)] AgentCompleted: steps=\(e.totalSteps), duration=\(e.durationMs)ms")
        case let e as AgentFailedEvent:
            print("  [Raw #\(tag)] AgentFailed: error=\(e.error)")
        case let e as ToolStartedEvent:
            print("  [Raw #\(tag)] ToolStarted: \(e.toolName) (id=\(e.toolUseId))")
        case let e as ToolCompletedEvent:
            print("  [Raw #\(tag)] ToolCompleted: \(e.toolName), duration=\(e.durationMs)ms")
        case let e as ToolFailedEvent:
            print("  [Raw #\(tag)] ToolFailed: \(e.toolName), error=\(e.error)")
        case let e as LLMRequestStartedEvent:
            print("  [Raw #\(tag)] LLMRequestStarted: model=\(e.model)")
        case let e as LLMResponseReceivedEvent:
            print("  [Raw #\(tag)] LLMResponseReceived: model=\(e.model), duration=\(e.durationMs)ms")
        case let e as LLMCostEvent:
            print("  [Raw #\(tag)] LLMCost: in=\(e.inputTokens) out=\(e.outputTokens) cost=$\(String(format: "%.6f", e.estimatedCostUsd))")
        case let e as LLMTokenStreamEvent:
            print("  [Raw #\(tag)] TokenStream: \"\(e.chunk.prefix(40))\"")
        case let e as ToolStreamingEvent:
            print("  [Raw #\(tag)] ToolStreaming: id=\(e.toolUseId)")
        default:
            print("  [Raw #\(tag)] \(type(of: event).self): id=\(event.id)")
        }
    }
}

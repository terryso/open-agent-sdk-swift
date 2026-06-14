// AgentEventBusExample
//
// Demonstrates wiring EventBus into a live Agent to observe real-time
// lifecycle, tool, and LLM cost events during an actual LLM session.
//
// Run: swift run AgentEventBusExample
// Prerequisite: set CODEANY_API_KEY or ANTHROPIC_API_KEY in .env or environment

import Foundation
import OpenAgentSDK

@main
struct AgentEventBusExample {
    static func main() async throws {
        print("╔══════════════════════════════════════════════════════════════╗")
        print("║  Agent + EventBus Example — Live Event Observation          ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print()

        try await runAgentWithEventBus()
    }

    // MARK: - Agent + EventBus Integration

    static func runAgentWithEventBus() async throws {
        let dotEnv = loadDotEnv()
        let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
            ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
            ?? ""
        guard !apiKey.isEmpty else {
            print("  Skipping: set CODEANY_API_KEY or ANTHROPIC_API_KEY to run this example")
            print()
            print("  Usage:")
            print("    ANTHROPIC_API_KEY=sk-... swift run AgentEventBusExample")
            print()
            return
        }

        let defaultModel = getEnv("ANTHROPIC_MODEL", from: dotEnv)
            ?? getEnv("CODEANY_MODEL", from: dotEnv)
            ?? "claude-sonnet-4-6"
        let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil

        // 1. Create EventBus
        let eventBus = EventBus()

        // 2. Subscribe to all events
        let (_, eventStream) = await eventBus.subscribe()

        // 3. Also subscribe to LLMCostEvent specifically — show cost summary at the end
        let costStream = await eventBus.subscribe(LLMCostEvent.self)

        // 4. Define a simple tool so we can observe ToolStarted/ToolCompleted events
        let echoTool = defineTool(
            name: "echo",
            description: "Echo back the input text",
            inputSchema: [
                "type": "object",
                "properties": [
                    "text": ["type": "string", "description": "Text to echo back"]
                ],
                "required": ["text"]
            ],
            isReadOnly: true
        ) { (input: EchoInput, context: ToolContext) -> String in
            return "Echo: \(input.text)"
        }

        // 5. Create Agent with eventBus wired in
        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey,
            model: defaultModel,
            baseURL: useOpenAI ? getDefaultOpenAIBaseURL(from: dotEnv) : getDefaultAnthropicBaseURL(from: dotEnv),
            provider: useOpenAI ? .openai : .anthropic,
            systemPrompt: "You are a helpful assistant. Use the echo tool when the user asks you to echo something.",
            permissionMode: .bypassPermissions,
            tools: [echoTool],
            eventBus: eventBus
        ))

        print("  Agent configured with EventBus enabled")
        print("  Subscribers: 1 (all events) + 1 (LLMCostEvent filter)")
        print()

        // 6. Run event printer in background
        let eventPrinter = _Concurrency.Task {
            var count = 0
            for await event in eventStream {
                count += 1
                describeEvent(event, index: count)
            }
        }

        // 7. Collect costs in background
        let costCollector = _Concurrency.Task {
            var totalCost: Double = 0
            var totalInput = 0
            var totalOutput = 0
            for await cost in costStream {
                totalCost += cost.estimatedCostUsd
                totalInput += cost.inputTokens
                totalOutput += cost.outputTokens
            }
            return (totalCost, totalInput, totalOutput)
        }

        // 8. Run the agent
        print("  Sending prompt: \"Echo 'Hello EventBus!' then tell me a fun fact.\"")
        print("  --- Events ---")
        print()

        let result = await agent.prompt(
            "Echo 'Hello EventBus!' then tell me a fun fact."
        )

        // 9. Give events a moment to drain, then cancel streams
        try await _Concurrency.Task.sleep(for: .milliseconds(200))
        eventPrinter.cancel()
        costCollector.cancel()

        print()
        print("  --- Agent Result ---")
        print("  Status:   \(result.status)")
        print("  Turns:    \(result.numTurns)")
        print("  Cost:     $\(String(format: "%.6f", result.totalCostUsd))")
        print("  Response: \(result.text.prefix(200))")
        print()

        // 10. Show cost summary from EventBus side
        print("  --- EventBus Cost Summary ---")
        let summary = await costCollector.value
        print("  Tokens:   in=\(summary.1) out=\(summary.2)")
        print("  Cost:     $\(String(format: "%.6f", summary.0))")
        print()
    }

    // MARK: - Helpers

    struct EchoInput: Codable {
        let text: String
    }

    static func describeEvent(_ event: any AgentEvent, index: Int) {
        let tag = String(format: "%3d", index)
        switch event {
        case let e as SessionCreatedEvent:
            print("  [\(tag)] SessionCreated: task=\"\(e.task)\", model=\(e.model)")
        case let e as SessionRestoredEvent:
            print("  [\(tag)] SessionRestored: sessionId=\(e.sessionId ?? "-")")
        case let e as SessionClosedEvent:
            print("  [\(tag)] SessionClosed: sessionId=\(e.sessionId ?? "-")")
        case let e as SessionAutoSavedEvent:
            print("  [\(tag)] SessionAutoSaved: sessionId=\(e.sessionId ?? "-")")
        case let e as AgentStartedEvent:
            print("  [\(tag)] AgentStarted: task=\"\(e.task)\"")
        case let e as AgentCompletedEvent:
            print("  [\(tag)] AgentCompleted: steps=\(e.totalSteps), duration=\(e.durationMs)ms")
        case let e as AgentFailedEvent:
            print("  [\(tag)] AgentFailed: error=\(e.error)")
        case let e as AgentInterruptedEvent:
            print("  [\(tag)] AgentInterrupted: sessionId=\(e.sessionId ?? "-")")
        case let e as AgentResumedEvent:
            print("  [\(tag)] AgentResumed: sessionId=\(e.sessionId ?? "-")")
        case let e as ToolStartedEvent:
            print("  [\(tag)] ToolStarted: \(e.toolName) (id=\(e.toolUseId))")
        case let e as ToolStreamingEvent:
            print("  [\(tag)] ToolStreaming: id=\(e.toolUseId) chunk=\(e.chunk.prefix(50))")
        case let e as ToolCompletedEvent:
            print("  [\(tag)] ToolCompleted: \(e.toolName), duration=\(e.durationMs)ms, error=\(e.isError)")
        case let e as ToolFailedEvent:
            print("  [\(tag)] ToolFailed: \(e.toolName), error=\(e.error)")
        case let e as LLMRequestStartedEvent:
            print("  [\(tag)] LLMRequestStarted: model=\(e.model)")
        case let e as LLMResponseReceivedEvent:
            print("  [\(tag)] LLMResponseReceived: model=\(e.model), duration=\(e.durationMs)ms")
        case let e as LLMCostEvent:
            print("  [\(tag)] LLMCost: in=\(e.inputTokens) out=\(e.outputTokens) cost=$\(String(format: "%.6f", e.estimatedCostUsd))")
        case let e as LLMTokenStreamEvent:
            print("  [\(tag)] LLMTokenStream: chunk=\(e.chunk.prefix(50))")
        default:
            print("  [\(tag)] \(type(of: event).self): id=\(event.id)")
        }
    }
}

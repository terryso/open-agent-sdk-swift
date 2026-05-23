import Foundation

// MARK: - PromptEvolverPlugin

/// A `SelfEvolutionPlugin` that analyzes conversations and suggests improvements
/// to the agent's system prompt using LLM-driven evolution.
///
/// The plugin buffers messages during `.syncTurn` phases and triggers evolution
/// analysis at `.sessionEnd`. By default, evolved prompts are returned as
/// suggestions for developer review (not auto-applied).
public actor PromptEvolverPlugin: SelfEvolutionPlugin {

    public nonisolated let name: String = "prompt-evolver"
    public nonisolated let supportedPhases: Set<PluginLifecyclePhase> = [.initialize, .syncTurn, .sessionEnd]

    private var engine: PromptEvolverEngine?
    private var pluginConfig: EvolutionPluginConfig?
    private var evolutionConfig: PromptEvolutionConfig
    private var currentPrompt: String?
    private var accumulatedMessages: [SDKMessage]
    private var autoApply: Bool

    public init(config: EvolutionPluginConfig? = nil, client: LLMClient? = nil) {
        self.pluginConfig = config
        self.accumulatedMessages = []

        // Parse config values with defaults
        var strategies = PromptEvolutionStrategy.allCases
        var evolutionModel = "claude-haiku-4-5-20251001"
        var minConversationLength = 6
        var maxChangesPerEvolution = 5
        var autoApply = false

        if let cfg = config?.config {
            if let model = cfg["evolutionModel"] {
                evolutionModel = model
            }
            if let str = cfg["minConversationLength"], let val = Int(str) {
                minConversationLength = val
            }
            if let str = cfg["maxChangesPerEvolution"], let val = Int(str) {
                maxChangesPerEvolution = val
            }
            if let strategiesStr = cfg["strategies"] {
                let parsed = strategiesStr.split(separator: ",").compactMap { raw in
                    PromptEvolutionStrategy(rawValue: raw.trimmingCharacters(in: .whitespaces))
                }
                if !parsed.isEmpty {
                    strategies = parsed
                }
            }
            if let autoApplyStr = cfg["autoApply"] {
                autoApply = (autoApplyStr.lowercased() == "true")
            }
        }

        self.evolutionConfig = PromptEvolutionConfig(
            strategies: strategies,
            evolutionModel: evolutionModel,
            minConversationLength: minConversationLength,
            maxChangesPerEvolution: maxChangesPerEvolution
        )
        self.autoApply = autoApply

        if let client = client {
            self.engine = PromptEvolverEngine(client: client)
        }

        // Read initial prompt from config if available
        if let cfg = config?.config, let prompt = cfg["currentPrompt"] {
            self.currentPrompt = prompt
        }
    }

    public func initialize(sessionId: String) async throws {
        accumulatedMessages = []
        // Keep config-provided prompt; only clear if no config set it
        if currentPrompt == nil {
            if let cfg = pluginConfig?.config, let prompt = cfg["currentPrompt"] {
                currentPrompt = prompt
            }
        }
    }

    public func onPhase(_ phase: PluginLifecyclePhase, context: PluginContext) async throws -> PluginResult {
        switch phase {
        case .syncTurn:
            accumulatedMessages.append(contentsOf: context.messages)
            // Track the most recent prompt from context (future: extract from context)
            return .none

        case .sessionEnd:
            guard let engine = engine else {
                return .none
            }

            let prompt = currentPrompt ?? ""
            let allMessages = accumulatedMessages + context.messages
            let result = try await engine.evolve(
                currentPrompt: prompt,
                messages: allMessages,
                config: evolutionConfig
            )

            guard result.shouldEvolve, let evolvedPrompt = result.evolvedPrompt else {
                return .none
            }

            if autoApply {
                return .systemPromptBlock(evolvedPrompt)
            } else {
                let suggestion = formatSuggestion(result: result, original: prompt)
                return .systemPromptBlock(suggestion)
            }

        case .initialize:
            return .none

        default:
            return .none
        }
    }

    public func shutdown() async {
        engine = nil
        accumulatedMessages = []
        currentPrompt = nil
        pluginConfig = nil
    }

    // MARK: - Private Helpers

    private func formatSuggestion(result: PromptEvolutionResult, original: String) -> String {
        var lines: [String] = []
        lines.append("[Prompt Evolution Suggestion — confidence: \(String(format: "%.0f%%", result.confidence * 100))]")
        lines.append("")

        for change in result.changes {
            lines.append("[\(change.strategy.rawValue)] \(change.section):")
            lines.append("  Original: \(String(change.original.prefix(100)))\(change.original.count > 100 ? "..." : "")")
            lines.append("  Modified: \(String(change.modified.prefix(100)))\(change.modified.count > 100 ? "..." : "")")
            lines.append("  Rationale: \(change.rationale)")
            lines.append("")
        }

        if let evolvedPrompt = result.evolvedPrompt {
            lines.append("Evolved prompt:")
            lines.append(evolvedPrompt)
        }

        return lines.joined(separator: "\n")
    }
}

import Foundation

/// LLM-based implementation of ``SkillEvolver`` that analyzes skill signals and
/// produces evolved skill definitions using a language model.
///
/// Uses a lightweight model (Haiku by default) for cost-efficient evolution.
/// Delegates LLM calls to the injected ``LLMClient`` — no actor isolation needed.
public struct LLMSkillEvolver: SkillEvolver, Sendable {

    /// The LLM client used for evolution calls.
    public let client: LLMClient

    /// Model identifier for evolution. Defaults to `"claude-haiku-4-5-20251001"`.
    public let evolutionModel: String

    public init(client: LLMClient, evolutionModel: String = "claude-haiku-4-5-20251001") {
        self.client = client
        self.evolutionModel = evolutionModel
    }

    public func evolve(
        skill: Skill,
        signals: [SkillSignal],
        config: SkillEvolutionConfig
    ) async throws -> SkillEvolutionResult {
        // Step 1: Split into applicable and skipped
        var applicable: [SkillSignal] = []
        var skipped: [SkillSignal] = []

        for signal in signals {
            let passesConfidence = signal.confidence >= config.minConfidence
            let passesType: Bool
            if let allowed = config.allowedSignalTypes {
                passesType = allowed.contains(signal.signalType)
            } else {
                passesType = true
            }

            if passesConfidence && passesType && signal.isApplicable(to: skill) {
                applicable.append(signal)
            } else {
                skipped.append(signal)
            }
        }

        // Trim to maxSignalsPerEvolution
        if applicable.count > config.maxSignalsPerEvolution {
            let excess = applicable.suffix(from: config.maxSignalsPerEvolution)
            skipped.append(contentsOf: excess)
            applicable = Array(applicable.prefix(config.maxSignalsPerEvolution))
        }

        // Step 3: Early return if no applicable signals
        guard !applicable.isEmpty else {
            return SkillEvolutionResult(
                evolvedSkill: nil,
                appliedSignals: [],
                skippedSignals: skipped,
                changes: []
            )
        }

        // Step 4: Call LLM
        let systemPrompt = buildSystemPrompt(skill: skill, signals: applicable)
        let userMessage: [String: Any] = ["role": "user", "content": "Analyze the signals above and produce the evolution JSON response."]

        let response: [String: Any]
        do {
            response = try await client.sendMessage(
                model: evolutionModel,
                messages: [userMessage],
                maxTokens: 2048,
                system: systemPrompt,
                tools: nil,
                toolChoice: nil,
                thinking: nil,
                temperature: 0.3
            )
        } catch {
            throw SDKError.apiError(
                statusCode: 0,
                message: "Skill evolution failed: \(error.localizedDescription)"
            )
        }

        // Step 5: Parse response
        let responseText = extractTextFromResponse(response)
        let parsed = parseEvolutionResponse(responseText)

        guard parsed.shouldEvolve, let overrides = parsed.evolvedSkill else {
            return SkillEvolutionResult(
                evolvedSkill: nil,
                appliedSignals: applicable,
                skippedSignals: skipped,
                changes: parsed.changes
            )
        }

        // Step 6: Build evolved skill
        // Skill is a value type — the original is always preserved regardless of
        // config.preserveOriginal. That flag exists for class-based implementations.
        let evolved = buildEvolvedSkill(original: skill, overrides: overrides)

        // Step 7: Handle dryRun
        let finalSkill: Skill? = config.dryRun ? nil : evolved

        return SkillEvolutionResult(
            evolvedSkill: finalSkill,
            appliedSignals: applicable,
            skippedSignals: skipped,
            changes: parsed.changes
        )
    }

    // MARK: - System Prompt Builder (AC3)

    private func buildSystemPrompt(skill: Skill, signals: [SkillSignal]) -> String {
        """
        You are a skill evolution engine. Analyze the current skill definition and \
        applicable signals, then produce a JSON response describing how the skill should evolve.

        ## Current Skill Definition

        - **Name**: \(skill.name)
        - **Description**: \(skill.description)
        - **Prompt Template**: \(skill.promptTemplate)
        - **When to Use**: \(skill.whenToUse ?? "not specified")
        - **Argument Hint**: \(skill.argumentHint ?? "not specified")
        - **Tool Restrictions**: \(skill.toolRestrictions?.map(\.rawValue).joined(separator: ", ") ?? "none")
        - **Aliases**: \(skill.aliases.isEmpty ? "none" : skill.aliases.joined(separator: ", "))
        - **Lifecycle State**: \(skill.lifecycleState?.rawValue ?? "active")

        ## Applicable Signals

        \(serializeSignals(signals))

        ## Evolution Guidance by Signal Type

        - **refinement**: Improve the skill's promptTemplate, description, or whenToUse based on usage feedback. \
        Focus on clarity and effectiveness.
        - **deprecation**: The skill is rarely used or consistently fails. Set lifecycleState to "deprecated" and \
        update the description to explain why.
        - **merge**: Another skill overlaps with this one. Consider combining promptTemplates and updating \
        toolRestrictions to cover both use cases.
        - **split**: The skill is too broad. Focus on narrowing the scope of the current skill — the split \
        counterpart will be created separately.
        - **newSkill**: A new pattern has been observed. Provide a complete definition for a new skill, including \
        promptTemplate, description, whenToUse, and argumentHint.

        ## Priority (Hermes-style)

        1. UPDATE the current skill to handle the signals — preferred approach.
        2. ADD a supporting file if additional context is needed.
        3. CREATE a new skill only as a last resort (for newSkill signals that cannot be handled by updating).

        ## Output Format

        Return a single JSON object with this structure:

        ```json
        {
          "shouldEvolve": true,
          "evolvedSkill": {
            "promptTemplate": "updated template (optional)",
            "description": "updated description (optional)",
            "whenToUse": "updated whenToUse (optional)",
            "argumentHint": "updated hint (optional)",
            "toolRestrictions": ["bash", "read"] ,
            "aliases": ["alias1"] ,
            "lifecycleState": "deprecated" ,
            "supportingFiles": ["relative/path.md"]
          },
          "changes": [
            "Human-readable description of change 1",
            "Human-readable description of change 2"
          ]
        }
        ```

        If no evolution is warranted, return: {"shouldEvolve": false, "changes": []}

        Return ONLY the JSON object. No explanation, no markdown outside the JSON.
        """
    }

    // MARK: - Signal Serialization (AC4)

    private func serializeSignals(_ signals: [SkillSignal]) -> String {
        var lines: [String] = []
        for (index, signal) in signals.enumerated() {
            lines.append("""
                \(index + 1). [\(signal.signalType.rawValue)] \(signal.content) \
                (confidence: \(String(format: "%.2f", signal.confidence)), source: \(signal.source.rawValue))
                """)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - LLM Response Parser (AC5)

    private struct ParsedEvolution {
        let shouldEvolve: Bool
        let evolvedSkill: ParsedSkillOverrides?
        let changes: [String]
    }

    private struct ParsedSkillOverrides {
        let promptTemplate: String?
        let description: String?
        let whenToUse: String?
        let argumentHint: String?
        let toolRestrictions: [String]?
        let aliases: [String]?
        let lifecycleState: SkillLifecycleState?
        let supportingFiles: [String]?
    }

    private func parseEvolutionResponse(_ text: String) -> ParsedEvolution {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return ParsedEvolution(shouldEvolve: false, evolvedSkill: nil, changes: [])
        }

        let jsonText = stripCodeFences(trimmed)

        guard let data = jsonText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            Logger.shared.warn("LLMSkillEvolver", "malformed_json_response", data: [
                "responsePreview": String(text.prefix(200)),
            ])
            return ParsedEvolution(shouldEvolve: false, evolvedSkill: nil, changes: [])
        }

        let shouldEvolve = json["shouldEvolve"] as? Bool ?? false
        let changes = json["changes"] as? [String] ?? []

        guard shouldEvolve, let skillDict = json["evolvedSkill"] as? [String: Any] else {
            return ParsedEvolution(shouldEvolve: shouldEvolve, evolvedSkill: nil, changes: changes)
        }

        let lifecycleState: SkillLifecycleState? = (skillDict["lifecycleState"] as? String).flatMap {
            SkillLifecycleState(rawValue: $0)
        }

        let overrides = ParsedSkillOverrides(
            promptTemplate: skillDict["promptTemplate"] as? String,
            description: skillDict["description"] as? String,
            whenToUse: skillDict["whenToUse"] as? String,
            argumentHint: skillDict["argumentHint"] as? String,
            toolRestrictions: skillDict["toolRestrictions"] as? [String],
            aliases: skillDict["aliases"] as? [String],
            lifecycleState: lifecycleState,
            supportingFiles: skillDict["supportingFiles"] as? [String]
        )

        return ParsedEvolution(shouldEvolve: true, evolvedSkill: overrides, changes: changes)
    }

    // MARK: - Evolved Skill Construction (AC6)

    private func buildEvolvedSkill(original: Skill, overrides: ParsedSkillOverrides) -> Skill {
        let toolRestrictions: [ToolRestriction]? = overrides.toolRestrictions?.compactMap {
            ToolRestriction(rawValue: $0)
        }

        let mergedSupportingFiles: [String] = {
            if let new = overrides.supportingFiles {
                var merged = original.supportingFiles
                for file in new where !merged.contains(file) {
                    merged.append(file)
                }
                return merged
            }
            return original.supportingFiles
        }()

        let mergedAliases: [String] = {
            if let new = overrides.aliases {
                var merged = original.aliases
                for alias in new where !merged.contains(alias) {
                    merged.append(alias)
                }
                return merged
            }
            return original.aliases
        }()

        return Skill(
            name: original.name,
            description: overrides.description ?? original.description,
            aliases: mergedAliases,
            userInvocable: original.userInvocable,
            toolRestrictions: toolRestrictions ?? original.toolRestrictions,
            modelOverride: original.modelOverride,
            isAvailable: original.isAvailable,
            promptTemplate: overrides.promptTemplate ?? original.promptTemplate,
            whenToUse: overrides.whenToUse ?? original.whenToUse,
            argumentHint: overrides.argumentHint ?? original.argumentHint,
            baseDir: original.baseDir,
            supportingFiles: mergedSupportingFiles,
            lifecycleState: overrides.lifecycleState ?? original.lifecycleState
        )
    }

    // MARK: - Response Helpers

    private func stripCodeFences(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            if let newlineRange = trimmed.range(of: "\n", options: [], range: trimmed.startIndex..<trimmed.endIndex) {
                trimmed = String(trimmed[newlineRange.upperBound...])
            } else {
                trimmed = String(trimmed.dropFirst(3))
            }
        }

        if trimmed.hasSuffix("```") {
            trimmed = String(trimmed[..<trimmed.index(trimmed.endIndex, offsetBy: -3)])
        }

        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTextFromResponse(_ response: [String: Any]) -> String {
        guard let content = response["content"] as? [[String: Any]] else {
            return ""
        }
        for block in content {
            if block["type"] as? String == "text",
               let text = block["text"] as? String {
                return text
            }
        }
        return ""
    }
}

import Foundation

/// LLM-based implementation of ``ExperienceExtractor`` that analyzes agent conversations
/// and extracts structured experience signals using a language model.
///
/// Uses a lightweight model (Haiku by default) for cost-efficient extraction.
/// Delegates LLM calls to the injected ``LLMClient`` — no actor isolation needed.
public struct LLMExperienceExtractor: ExperienceExtractor, Sendable {

    /// The LLM client used for extraction calls.
    public let client: LLMClient

    /// Model identifier for extraction. Defaults to `"claude-haiku-4-5-20251001"`.
    public let extractionModel: String

    public init(client: LLMClient, extractionModel: String = "claude-haiku-4-5-20251001") {
        self.client = client
        self.extractionModel = extractionModel
    }

    public func extract(from messages: [SDKMessage], config: ExtractionConfig) async throws -> ExtractionResult {
        let serialized = serializeMessages(messages)

        let systemPrompt = buildSystemPrompt(config: config)
        let userMessage: [String: Any] = ["role": "user", "content": serialized]

        let response: [String: Any]
        do {
            response = try await client.sendMessage(
                model: extractionModel,
                messages: [userMessage],
                maxTokens: 2048,
                system: systemPrompt,
                tools: nil,
                toolChoice: nil,
                thinking: nil,
                temperature: 0.3
            )
        } catch {
            throw SDKError.apiError(statusCode: 0, message: "Experience extraction failed: \(error.localizedDescription)")
        }

        let responseText = extractTextFromResponse(response)
        let parsed = parseExtractionResponse(responseText)

        var filtered: [ExperienceSignal] = []
        var skipped = parsed.parseFailureCount

        for raw in parsed.signals {
            guard raw.confidence >= config.minSignalConfidence else {
                skipped += 1
                continue
            }
            let contentLower = raw.content.lowercased()
            let matchesAntiPattern = config.antiPatternKeywords.contains { keyword in
                contentLower.contains(keyword.lowercased())
            }
            if matchesAntiPattern {
                skipped += 1
                continue
            }
            if filtered.count >= config.maxSignalsPerExtraction {
                skipped += 1
                continue
            }
            filtered.append(
                ExperienceSignal.create(
                    domain: raw.domain,
                    kind: raw.kind,
                    content: raw.content,
                    confidence: raw.confidence,
                    source: .conversation
                )
            )
        }

        return ExtractionResult(
            signals: filtered,
            skippedCount: skipped,
            extractionDate: Date(),
            sourceMessageCount: messages.count
        )
    }

    // MARK: - Message Serialization (AC4)

    private func serializeMessages(_ messages: [SDKMessage]) -> String {
        var lines: [String] = []
        for message in messages {
            switch message {
            case .assistant(let data):
                lines.append("[assistant] \(truncate(data.text))")
            case .userMessage(let data):
                lines.append("[user] \(truncate(data.message))")
            case .toolResult(let data):
                lines.append("[tool_result] \(truncate(data.content))")
            default:
                break
            }
        }
        return lines.joined(separator: "\n")
    }

    private func truncate(_ text: String) -> String {
        if text.count <= 2000 { return text }
        return String(text.prefix(2000)) + "... [truncated]"
    }

    // MARK: - System Prompt (AC3)

    private func buildSystemPrompt(config: ExtractionConfig) -> String {
        var prompt = """
        You are an experience extraction engine. Analyze the following conversation and \
        extract experience signals as a JSON array.

        Each object in the array MUST have these fields:
        - "domain": string — the knowledge domain (e.g., "testing", "navigation", "build")
        - "content": string — a concise description of the experience
        - "kind": string — one of "affordance", "avoid", "observation"
        - "confidence": number — your confidence in this signal, from 0.0 to 1.0

        Guidelines:
        - Be ACTIVE: capture genuine learnings, not just summaries of what happened
        - If the conversation contains no extractable experience, return an empty array []
        - Focus on user identity signals (persona, preferences) and expectation signals (work style, behavior)
        - If a tool failed because of setup state, capture the FIX — never "this tool does not work" as a standalone constraint
        - Do NOT capture transient errors (timeouts, rate limits, connection issues) as experience
        - Do NOT capture environment-specific paths or temporary states
        """

        if let domain = config.domain {
            prompt += "\n\nRestrict extraction to the domain: \"\(domain)\""
        }

        prompt += "\n\nReturn ONLY the JSON array. No explanation, no markdown."
        return prompt
    }

    // MARK: - JSON Parsing (AC5)

    private struct RawSignal {
        let domain: String
        let content: String
        let kind: MemoryKind
        let confidence: Double
    }

    private struct ParsedExtraction {
        let signals: [RawSignal]
        let parseFailureCount: Int
    }

    private func parseExtractionResponse(_ text: String) -> ParsedExtraction {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ParsedExtraction(signals: [], parseFailureCount: 0)
        }

        let jsonText = stripCodeFences(text)

        guard let data = jsonText.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            Logger.shared.warn("LLMExperienceExtractor", "malformed_json_response", data: [
                "responsePreview": String(text.prefix(200)),
            ])
            return ParsedExtraction(signals: [], parseFailureCount: 0)
        }

        var signals: [RawSignal] = []
        var parseFailures = 0
        for item in jsonArray {
            guard let domain = item["domain"] as? String,
                  let content = item["content"] as? String,
                  let kindString = item["kind"] as? String,
                  let kind = MemoryKind(rawValue: kindString),
                  let confidence = item["confidence"] as? Double
            else {
                parseFailures += 1
                continue
            }
            signals.append(RawSignal(domain: domain, content: content, kind: kind, confidence: confidence))
        }
        return ParsedExtraction(signals: signals, parseFailureCount: parseFailures)
    }

    private func stripCodeFences(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip opening fence: ```json or ```
        if trimmed.hasPrefix("```") {
            if let newlineRange = trimmed.range(of: "\n", options: [], range: trimmed.startIndex..<trimmed.endIndex) {
                trimmed = String(trimmed[newlineRange.upperBound...])
            } else {
                trimmed = String(trimmed.dropFirst(3))
            }
        }

        // Strip closing fence: ```
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

import Foundation

/// State tracking for auto-compaction across agent loop iterations.
struct AutoCompactState: Sendable {
    let compacted: Bool
    let turnCounter: Int
    let consecutiveFailures: Int
}

/// Create initial auto-compact state.
func createAutoCompactState() -> AutoCompactState {
    return AutoCompactState(
        compacted: false,
        turnCounter: 0,
        consecutiveFailures: 0
    )
}

/// Estimate total tokens for a message array.
/// Uses 4 characters per token approximation (standard heuristic).
func estimateMessagesTokens(_ messages: [[String: Any]]) -> Int {
    var total = 0
    for msg in messages {
        if let content = msg["content"] as? String {
            total += content.count / 4
        } else if let blocks = msg["content"] as? [[String: Any]] {
            for block in blocks {
                if let text = block["text"] as? String {
                    total += text.count / 4
                } else if let content = block["content"] as? String {
                    total += content.count / 4
                } else {
                    // tool_use, image, etc - rough estimate via JSON serialization
                    if let data = try? JSONSerialization.data(withJSONObject: block),
                       let str = String(data: data, encoding: .utf8) {
                        total += str.count / 4
                    }
                }
            }
        }
    }
    return total
}

/// Get the auto-compact threshold for a model (context window minus buffer).
func getAutoCompactThreshold(model: String) -> Int {
    return getContextWindowSize(model: model) - AUTOCOMPACT_BUFFER_TOKENS
}

/// Check if auto-compaction should trigger.
func shouldAutoCompact(
    messages: [[String: Any]],
    model: String,
    state: AutoCompactState
) -> Bool {
    if state.consecutiveFailures >= 3 { return false }
    let estimatedTokens = estimateMessagesTokens(messages)
    let threshold = getAutoCompactThreshold(model: model)
    return estimatedTokens >= threshold
}

/// Compact conversation by summarizing with the LLM.
func compactConversation(
    client: AnthropicClient,
    model: String,
    messages: [[String: Any]],
    state: AutoCompactState
) async -> (compactedMessages: [[String: Any]], summary: String, state: AutoCompactState) {
    do {
        // Build compaction prompt
        let compactionPrompt = buildCompactionPrompt(messages)

        let retryModel = model
        let response = try await withRetry {
            try await client.sendMessage(
                model: retryModel,
                messages: [
                    ["role": "user", "content": compactionPrompt]
                ],
                maxTokens: 8192,
                system: "You are a conversation summarizer. Create a detailed summary of the conversation that preserves all important context, decisions made, files modified, tool outputs, and current state. The summary should allow the conversation to continue seamlessly."
            )
        }

        // Extract summary text from response
        var summary = ""
        if let content = response["content"] as? [[String: Any]] {
            summary = content
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
        }

        // Replace messages with compact summary
        let compactedMessages: [[String: Any]] = [
            [
                "role": "user",
                "content": "[Previous conversation summary]\n\n\(summary)\n\n[End of summary - conversation continues below]"
            ],
            [
                "role": "assistant",
                "content": "I understand the context from the previous conversation. I'll continue from where we left off."
            ]
        ]

        return (
            compactedMessages: compactedMessages,
            summary: summary,
            state: AutoCompactState(
                compacted: true,
                turnCounter: state.turnCounter,
                consecutiveFailures: 0
            )
        )
    } catch {
        // On failure, return original messages unchanged
        return (
            compactedMessages: messages,
            summary: "",
            state: AutoCompactState(
                compacted: state.compacted,
                turnCounter: state.turnCounter,
                consecutiveFailures: state.consecutiveFailures + 1
            )
        )
    }
}

/// Build a compaction prompt from the message array.
private func buildCompactionPrompt(_ messages: [[String: Any]]) -> String {
    var parts: [String] = ["Please summarize this conversation:\n"]

    for msg in messages {
        let role = msg["role"] as? String == "user" ? "User" : "Assistant"

        if let content = msg["content"] as? String {
            parts.append("\(role): \(String(content.prefix(5000)))")
        } else if let blocks = msg["content"] as? [[String: Any]] {
            var texts: [String] = []
            for block in blocks {
                if let text = block["text"] as? String {
                    texts.append(String(text.prefix(3000)))
                } else if block["type"] as? String == "tool_use" {
                    if let name = block["name"] as? String {
                        texts.append("[Tool: \(name)]")
                    }
                } else if block["type"] as? String == "tool_result" {
                    if let content = block["content"] as? String {
                        texts.append("[Tool Result: \(String(content.prefix(1000)))]")
                    } else {
                        texts.append("[tool result]")
                    }
                }
            }
            if !texts.isEmpty {
                parts.append("\(role): \(texts.joined(separator: "\n"))")
            }
        }
    }

    return parts.joined(separator: "\n\n")
}

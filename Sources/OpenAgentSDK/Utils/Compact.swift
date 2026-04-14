import Foundation

/// State tracking for auto-compaction across agent loop iterations.
struct AutoCompactState: Sendable {
    let compacted: Bool
    let turnCounter: Int
    let consecutiveFailures: Int
    /// Timestamp of the last successful compaction. Used to determine which files
    /// have been modified since the previous compaction.
    let lastCompactTime: Date

    init(
        compacted: Bool = false,
        turnCounter: Int = 0,
        consecutiveFailures: Int = 0,
        lastCompactTime: Date = Date.distantPast
    ) {
        self.compacted = compacted
        self.turnCounter = turnCounter
        self.consecutiveFailures = consecutiveFailures
        self.lastCompactTime = lastCompactTime
    }
}

/// Create initial auto-compact state.
func createAutoCompactState() -> AutoCompactState {
    return AutoCompactState(
        compacted: false,
        turnCounter: 0,
        consecutiveFailures: 0,
        lastCompactTime: Date.distantPast
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
///
/// After a successful compaction, if `sessionMemory` is provided, key decisions
/// and context are extracted from the summary and appended to the session memory
/// FIFO queue. Short summaries (< 200 characters) are stored directly without an
/// additional LLM call.
func compactConversation(
    client: any LLMClient,
    model: String,
    messages: [[String: Any]],
    state: AutoCompactState,
    fileCache: FileCache? = nil,
    sessionMemory: SessionMemory? = nil,
    retryConfig: RetryConfig = .default
) async -> (compactedMessages: [[String: Any]], summary: String, state: AutoCompactState) {
    do {
        // Get recently modified files from cache (if available)
        let modifiedFiles: [String]
        if let cache = fileCache {
            modifiedFiles = cache.getModifiedFiles(since: state.lastCompactTime)
        } else {
            modifiedFiles = []
        }

        // Build compaction prompt
        let compactionPrompt = buildCompactionPrompt(messages, modifiedFiles: modifiedFiles)

        let retryModel = model
        let response = try await withRetry({
            try await client.sendMessage(
                model: retryModel,
                messages: [
                    ["role": "user", "content": compactionPrompt]
                ],
                maxTokens: 8192,
                system: "You are a conversation summarizer. Create a detailed summary of the conversation that preserves all important context, decisions made, files modified, tool outputs, and current state. The summary should allow the conversation to continue seamlessly.",
                tools: nil,
                toolChoice: nil,
                thinking: nil,
                temperature: nil
            )
        }, retryConfig: retryConfig)

        // Extract summary text from response
        var summary = ""
        if let content = response["content"] as? [[String: Any]] {
            summary = content
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
        }

        // Extract session memory entries from the summary
        if !summary.isEmpty, let sessionMemory = sessionMemory {
            await extractSessionMemory(
                client: client,
                model: model,
                summary: summary,
                into: sessionMemory,
                retryConfig: retryConfig
            )
        }

        // Replace messages with compact summary
        let beforeTokens = estimateMessagesTokens(messages)
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

        let afterTokens = estimateMessagesTokens(compactedMessages)

        // Structured log for compact event
        Logger.shared.info("QueryEngine", "compact", data: [
            "trigger": "auto",
            "beforeTokens": String(beforeTokens),
            "afterTokens": String(afterTokens)
        ])

        return (
            compactedMessages: compactedMessages,
            summary: summary,
            state: AutoCompactState(
                compacted: true,
                turnCounter: state.turnCounter,
                consecutiveFailures: 0,
                lastCompactTime: Date()
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
                consecutiveFailures: state.consecutiveFailures + 1,
                lastCompactTime: state.lastCompactTime
            )
        )
    }
}

// MARK: - Session Memory Extraction (Story 13.3)

/// Extract key decisions, preferences, and constraints from a compaction summary
/// and append them to the session memory.
///
/// If the summary is short (< 200 characters), it is stored directly as a single
/// entry without making an additional LLM call. Otherwise, an LLM call extracts
/// structured JSON entries from the summary.
///
/// - Parameters:
///   - client: The LLM client to use for extraction (if needed).
///   - model: The model identifier.
///   - summary: The compaction summary text.
///   - sessionMemory: The session memory to append entries to.
func extractSessionMemory(
    client: any LLMClient,
    model: String,
    summary: String,
    into sessionMemory: SessionMemory,
    retryConfig: RetryConfig = .default
) async {
    // Short summary: store directly without LLM extraction call
    if summary.count < 200 {
        let entry = SessionMemoryEntry(
            category: "decision",
            summary: summary,
            context: "",
            timestamp: Date()
        )
        sessionMemory.append(entry)
        return
    }

    // Long summary: use LLM to extract structured entries
    let extractionPrompt = buildSessionMemoryExtractionPrompt(summary)

    do {
        let retryModel = model
        let response = try await withRetry({
            try await client.sendMessage(
                model: retryModel,
                messages: [
                    ["role": "user", "content": extractionPrompt]
                ],
                maxTokens: 2048,
                system: "You extract key information from conversation summaries as JSON arrays. Output ONLY valid JSON, no markdown fences.",
                tools: nil,
                toolChoice: nil,
                thinking: nil,
                temperature: nil
            )
        }, retryConfig: retryConfig)

        // Extract text from response
        var responseText = ""
        if let content = response["content"] as? [[String: Any]] {
            responseText = content
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
        }

        // Strip markdown code fences if present
        let cleanedJSON = stripMarkdownFences(responseText)
        guard let data = cleanedJSON.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: String]] else {
            // If parsing fails, store the summary directly as fallback
            let entry = SessionMemoryEntry(
                category: "decision",
                summary: summary,
                context: "",
                timestamp: Date()
            )
            sessionMemory.append(entry)
            return
        }

        for item in jsonArray {
            let rawCategory = item["category"] ?? "decision"
            let validCategories: Set<String> = ["decision", "preference", "constraint"]
            let category = validCategories.contains(rawCategory) ? rawCategory : "decision"
            let itemSummary = item["summary"] ?? ""
            let itemContext = item["context"] ?? ""

            guard !itemSummary.isEmpty else { continue }

            let entry = SessionMemoryEntry(
                category: category,
                summary: itemSummary,
                context: itemContext,
                timestamp: Date()
            )
            sessionMemory.append(entry)
        }
    } catch {
        // On extraction failure, store summary directly as fallback
        let entry = SessionMemoryEntry(
            category: "decision",
            summary: summary,
            context: "",
            timestamp: Date()
        )
        sessionMemory.append(entry)
    }
}

/// Build the extraction prompt for session memory.
///
/// - Parameter summary: The compaction summary to extract from.
/// - Returns: The extraction prompt string.
private func buildSessionMemoryExtractionPrompt(_ summary: String) -> String {
    return """
    Analyze the following conversation summary and extract key information as a JSON array.

    Each entry must have:
    - "category": one of "decision", "preference", "constraint"
    - "summary": a one-sentence summary
    - "context": related file path or code snippet (if applicable)

    Rules:
    - Extract ONLY non-obvious, important information
    - Ignore generic pleasantries and routine operations
    - Maximum 5 entries per extraction
    - Each summary must be under 100 characters

    Conversation summary:
    \(summary)
    """
}

/// Strip markdown code fences from a string (e.g., ```json ... ```).
private func stripMarkdownFences(_ text: String) -> String {
    var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if result.hasPrefix("```") {
        // Remove opening fence (and optional language tag)
        if let firstNewline = result.firstIndex(of: "\n") {
            result = String(result[result.index(after: firstNewline)...])
        }
    }
    if result.hasSuffix("```") {
        result = String(result.dropLast(3))
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Micro Compaction (Story 2.6)

/// Threshold (in characters) above which tool results are micro-compacted.
/// Matches the TypeScript SDK default of 50,000 characters.
let MICRO_COMPACT_THRESHOLD = 50_000

/// Check whether a tool result string should be micro-compacted.
///
/// Returns `true` when the content exceeds `MICRO_COMPACT_THRESHOLD` characters
/// and does not already carry a micro-compact marker (prevents double-compaction).
///
/// - Parameter content: The raw tool result text.
/// - Parameter isError: Whether the tool result is an error (errors are never compacted).
/// - Returns: `true` when micro-compaction should be attempted.
func shouldMicroCompact(content: String, isError: Bool = false) -> Bool {
    guard !isError else { return false }
    guard content.count > MICRO_COMPACT_THRESHOLD else { return false }
    // Do not re-compact content that was already micro-compacted
    return !content.hasPrefix("[微压缩]")
}

/// Compress a large tool result using the LLM.
///
/// On success the returned string contains a `[微压缩]` header with length
/// metadata followed by the LLM-generated summary. On failure the original content
/// is returned unchanged.
///
/// The LLM call is wrapped with `withRetry` for resilience. Costs from this call
/// are **not** added to the caller's `totalCostUsd` (internal operation).
///
/// - Parameters:
///   - client: The Anthropic client to use for the summarization call.
///   - model: The model identifier.
///   - content: The raw tool result text to compress.
/// - Returns: The compressed string (with header) on success, or the original content on failure.
func microCompact(
    client: any LLMClient,
    model: String,
    content: String,
    retryConfig: RetryConfig = .default
) async -> String {
    do {
        let prompt = buildMicroCompactPrompt(content)

        let response = try await withRetry({
            try await client.sendMessage(
                model: model,
                messages: [
                    ["role": "user", "content": prompt]
                ],
                maxTokens: 8192,
                system: "You are a content summarizer for tool results. Compress the following tool output while preserving: 1. File paths and names 2. Error messages and stack traces (in full) 3. Key-value pairs (keys in full, values summarized if >200 chars) 4. Structure and formatting cues (headers, lists, indentation levels) 5. Any numeric data or metrics 6. The first and last 200 characters of any code blocks. Remove: verbose logging output (keep first/last lines), redundant file content listings, whitespace and padding, repeated patterns (note the count and show one example). Output the compressed version directly.",
                tools: nil,
                toolChoice: nil,
                thinking: nil,
                temperature: nil
            )
        }, retryConfig: retryConfig)

        // Extract summary text from response
        var summary = ""
        if let responseContent = response["content"] as? [[String: Any]] {
            summary = responseContent
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
        }

        guard !summary.isEmpty else {
            return content
        }

        // Structured log for micro-compact event
        Logger.shared.debug("QueryEngine", "compact", data: [
            "trigger": "micro",
            "originalSize": String(content.count),
            "compressedSize": String(summary.count)
        ])

        return "[微压缩] 原始长度: \(content.count), 压缩后长度: \(summary.count)\n\n\(summary)"
    } catch {
        // On failure, preserve original content unchanged
        return content
    }
}

/// Build the user prompt sent to the LLM for micro-compaction.
///
/// Takes a truncated view of the content (first + last 25,000 characters) so
/// the prompt itself does not blow past context limits.
private func buildMicroCompactPrompt(_ content: String) -> String {
    let previewLength = 25_000
    // shouldMicroCompact guarantees content.count > 50_000, so we always preview.
    // Show first and last 25K chars to keep the prompt within context limits.
    let head = String(content.prefix(previewLength))
    let tail = String(content.suffix(previewLength))
    return """
    Compress the following tool output, preserving all key information.
    The content is \(content.count) characters long; showing first \(previewLength) and last \(previewLength) characters.

    --- BEGIN (first \(previewLength) chars) ---
    \(head)
    --- MIDDLE OMITTED (\(content.count - previewLength * 2) chars) ---
    \(tail)
    --- END ---
    """
}

/// Build a compaction prompt from the message array.
///
/// - Parameters:
///   - messages: The conversation messages to summarize.
///   - modifiedFiles: Optional list of recently modified file paths to include in the prompt.
/// - Returns: The compaction prompt string.
private func buildCompactionPrompt(_ messages: [[String: Any]], modifiedFiles: [String] = []) -> String {
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

    // Append recently modified files section if available
    if !modifiedFiles.isEmpty {
        let fileList = modifiedFiles.joined(separator: ", ")
        parts.append("Recently modified files since last compaction: [\(fileList)]")
    }

    return parts.joined(separator: "\n\n")
}

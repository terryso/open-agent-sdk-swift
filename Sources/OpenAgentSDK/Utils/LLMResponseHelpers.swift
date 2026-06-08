import Foundation

// MARK: - LLM Response Helpers

/// Shared helpers for parsing LLM API responses.
///
/// These are used by multiple LLM-calling components (skill evolver, experience
/// extractor, prompt evolver, streaming dispatchers) to extract text content,
/// strip code fences, and parse JSON strings from raw API response dictionaries.

/// Extract the first text block from an LLM response dictionary.
///
/// Iterates response content blocks looking for `type: "text"` and returns
/// the first matching text string. Returns `""` if no text block is found.
///
/// - Parameter response: The raw LLM API response dictionary.
/// - Returns: The first text content string, or `""` if none found.
func extractFirstTextFromResponse(_ response: [String: Any]) -> String {
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

/// Strip markdown code fences from LLM output.
///
/// Removes surrounding ` ``` ` / ` ```json ` fences that LLMs commonly add
/// around structured output. Handles both opening fence with optional language
/// tag and closing fence.
///
/// - Parameter text: The raw LLM output, possibly wrapped in code fences.
/// - Returns: The text with code fences removed and whitespace trimmed.
func stripCodeFences(_ text: String) -> String {
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

/// Parse a JSON string into a `[String: Any]` dictionary.
///
/// Returns `nil` if the string is empty, cannot be converted to UTF-8 data,
/// or is not valid JSON / not a JSON object. Used by SSE event dispatchers,
/// tool input parsers, and OpenAI response converters.
///
/// - Parameter jsonString: The JSON string to parse.
/// - Returns: The parsed dictionary, or `nil` on failure.
func parseJSONToDict(_ jsonString: String) -> [String: Any]? {
    guard !jsonString.isEmpty,
          let data = jsonString.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
}

/// Parse an LLM response (possibly wrapped in code fences) as a JSON object.
///
/// Handles the common 3-step pipeline used by skill evolver, prompt evolver, and
/// experience extractor: trim whitespace → strip code fences → parse JSON object.
///
/// - Parameter text: The raw LLM response text.
/// - Returns: The parsed `[String: Any]` dictionary, or `nil` on failure.
func parseLLMResponseAsObject(_ text: String) -> [String: Any]? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return parseJSONToDict(stripCodeFences(trimmed))
}

/// Parse an LLM response (possibly wrapped in code fences) as a JSON array.
///
/// Handles the common 3-step pipeline: trim whitespace → strip code fences → parse JSON array.
///
/// - Parameter text: The raw LLM response text.
/// - Returns: The parsed `[[String: Any]]` array, or `nil` on failure.
func parseLLMResponseAsArray(_ text: String) -> [[String: Any]]? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard let data = stripCodeFences(trimmed).data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
}

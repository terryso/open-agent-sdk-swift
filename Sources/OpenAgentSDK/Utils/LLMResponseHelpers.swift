import Foundation

// MARK: - LLM Response Helpers

/// Shared helpers for parsing LLM API responses.
///
/// These are used by multiple LLM-calling components (skill evolver, experience
/// extractor, prompt evolver) to extract text content and strip code fences from
/// raw API response dictionaries.

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

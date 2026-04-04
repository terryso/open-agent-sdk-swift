import Foundation

// MARK: - SSE Event Type

/// Represents a Server-Sent Event from the Anthropic Messages API streaming endpoint.
///
/// Uses `@unchecked Sendable` because associated values contain `[String: Any]` dictionaries
/// parsed from JSON. These are immutable, value-type dictionaries that do not have shared
/// mutable state concerns.
public enum SSEEvent: @unchecked Sendable {
    case messageStart(message: [String: Any])
    case contentBlockStart(index: Int, contentBlock: [String: Any])
    case contentBlockDelta(index: Int, delta: [String: Any])
    case contentBlockStop(index: Int)
    case messageDelta(delta: [String: Any], usage: [String: Any])
    case messageStop
    case ping
    case error(data: [String: Any])
}

// MARK: - Request Building Helpers

/// Builds the request body dictionary for an Anthropic Messages API call.
func buildRequestBody(
    model: String,
    messages: [[String: Any]],
    maxTokens: Int,
    stream: Bool,
    system: String? = nil,
    tools: [[String: Any]]? = nil,
    toolChoice: [String: Any]? = nil,
    thinking: [String: Any]? = nil,
    temperature: Double? = nil
) -> [String: Any] {
    var body: [String: Any] = [
        "model": model,
        "messages": messages,
        "max_tokens": maxTokens,
        "stream": stream
    ]

    if let system {
        body["system"] = system
    }
    if let tools {
        body["tools"] = tools
    }
    if let toolChoice {
        body["tool_choice"] = toolChoice
    }
    if let thinking {
        body["thinking"] = thinking
    }
    if let temperature {
        body["temperature"] = temperature
    }

    return body
}

// MARK: - Response Parsing Helpers

/// Parses a JSON data response into a dictionary.
func parseResponse(data: Data) throws -> [String: Any] {
    guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
          let dict = jsonObject as? [String: Any] else {
        throw SDKError.apiError(statusCode: 0, message: "Failed to parse response JSON")
    }
    return dict
}

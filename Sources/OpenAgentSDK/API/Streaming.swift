import Foundation

// MARK: - SSE Line Parser

/// Parses raw SSE text lines into (event, data) pairs.
struct SSELineParser {

    /// Parses a block of SSE text into individual event/data pairs.
    /// Each SSE event is separated by a blank line ("\n\n").
    /// Within an event, lines are "event: xxx" and "data: {...}".
    static func parse(text: String) -> [(event: String, data: String)] {
        var results: [(event: String, data: String)] = []
        var currentEvent: String?
        var currentData: String?

        let lines = text.components(separatedBy: "\n")

        for line in lines {
            if line.isEmpty {
                // End of event block
                if let event = currentEvent, let data = currentData {
                    results.append((event: event, data: data))
                } else if let data = currentData {
                    // Default event type is "message" per SSE spec, but Anthropic always sends explicit event types
                    results.append((event: currentEvent ?? "message", data: data))
                }
                currentEvent = nil
                currentData = nil
                continue
            }

            if line.hasPrefix("event:") {
                currentEvent = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                currentData = String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces)
            }
        }

        // Handle last event if file doesn't end with blank line
        if let event = currentEvent, let data = currentData {
            results.append((event: event, data: data))
        }

        return results
    }
}

// MARK: - SSE Event Dispatcher

/// Converts parsed (event, data) pairs into SSEEvent enum values.
struct SSEEventDispatcher {

    /// Maps a parsed SSE event string and JSON data string into an SSEEvent.
    static func dispatch(event: String, data: String) -> SSEEvent? {
        switch event {
        case "message_start":
            guard let dict = parseJSONDict(data),
                  let message = dict["message"] as? [String: Any] else {
                return nil
            }
            return .messageStart(message: message)

        case "content_block_start":
            guard let dict = parseJSONDict(data),
                  let index = dict["index"] as? Int,
                  let contentBlock = dict["content_block"] as? [String: Any] else {
                return nil
            }
            return .contentBlockStart(index: index, contentBlock: contentBlock)

        case "content_block_delta":
            guard let dict = parseJSONDict(data),
                  let index = dict["index"] as? Int,
                  let delta = dict["delta"] as? [String: Any] else {
                return nil
            }
            return .contentBlockDelta(index: index, delta: delta)

        case "content_block_stop":
            guard let dict = parseJSONDict(data),
                  let index = dict["index"] as? Int else {
                return nil
            }
            return .contentBlockStop(index: index)

        case "message_delta":
            guard let dict = parseJSONDict(data),
                  let delta = dict["delta"] as? [String: Any],
                  let usage = dict["usage"] as? [String: Any] else {
                return nil
            }
            return .messageDelta(delta: delta, usage: usage)

        case "message_stop":
            return .messageStop

        case "ping":
            return .ping

        case "error":
            guard let dict = parseJSONDict(data) else {
                return nil
            }
            return .error(data: dict)

        default:
            return nil
        }
    }

    /// Safely parses a JSON string into a dictionary.
    private static func parseJSONDict(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
}

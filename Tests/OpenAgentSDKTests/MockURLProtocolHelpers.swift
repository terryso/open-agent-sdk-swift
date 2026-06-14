import Foundation

/// Reads all available bytes from an InputStream into Data.
///
/// Used by MockURLProtocol subclasses to capture request body data
/// from `httpBodyStream` when `httpBody` is nil (e.g., streaming requests).
///
/// - Parameter stream: The input stream to read from. The stream is opened
///   and closed automatically.
/// - Returns: The accumulated data, or nil if a read error occurs.
func readRequestBodyFromStream(_ stream: InputStream) -> Data? {
    stream.open()
    defer { stream.close() }

    let bufferSize = 4096
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: bufferSize)

    while stream.hasBytesAvailable {
        let bytesRead = stream.read(&buffer, maxLength: bufferSize)
        if bytesRead < 0 { return nil }
        if bytesRead == 0 { break }
        data.append(buffer, count: bytesRead)
    }

    return data
}

/// Creates a URLSession with an ephemeral configuration that routes all
/// requests through the given mock URLProtocol subclass.
///
/// - Parameter protocolClass: The URLProtocol subclass to intercept requests.
/// - Returns: A configured URLSession ready for mock-based testing.
func makeMockURLSession(protocolClass: URLProtocol.Type) -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [protocolClass]
    return URLSession(configuration: config)
}

/// Extracts the assembled prompt text from a captured Anthropic `/v1/messages`
/// request body.
///
/// Mock URL protocols capture the **raw JSON bytes** of the request (including
/// `\/` forward-slash escapes), so substring assertions against the raw body
/// fail whenever the expected text contains `/`. This helper JSON-decodes the
/// body and pulls out the concatenation of all message `content` text fields
/// plus the `system` field, so tests can assert prompt content character-for-
/// character regardless of JSON escaping.
///
/// Story 29.3 uses this to verify the prompt assembled by
/// `resolveSkillForExecution` (which is `private`) — the request body is the
/// only observable side effect.
///
/// - Parameter body: The raw captured request body.
/// - Returns: The decoded prompt text, or nil if the body is not valid JSON
///   in the expected Anthropic request shape.
func extractPromptTextFromRequestBody(_ body: Data) -> String? {
    guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
        return nil
    }
    var pieces: [String] = []
    if let system = json["system"] as? String {
        pieces.append(system)
    }
    if let messages = json["messages"] as? [[String: Any]] {
        for message in messages {
            if let content = message["content"] {
                if let text = content as? String {
                    pieces.append(text)
                } else if let blocks = content as? [[String: Any]] {
                    for block in blocks {
                        if let text = block["text"] as? String {
                            pieces.append(text)
                        }
                    }
                }
            }
        }
    }
    return pieces.joined(separator: "\n")
}

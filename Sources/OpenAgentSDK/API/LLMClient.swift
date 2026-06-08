import Foundation

/// A protocol defining the interface for LLM API clients.
///
/// Concrete implementations handle the specifics of different LLM provider APIs
/// (Anthropic, OpenAI-compatible, etc.) while presenting a uniform interface to the Agent.
public protocol LLMClient: Sendable {
    /// Send a non-streaming message request and return the full response.
    ///
    /// The response dictionary uses Anthropic-format structure for compatibility
    /// with the Agent's processing logic.
    nonisolated func sendMessage(
        model: String,
        messages: [[String: Any]],
        maxTokens: Int,
        system: String?,
        tools: [[String: Any]]?,
        toolChoice: [String: Any]?,
        thinking: [String: Any]?,
        temperature: Double?
    ) async throws -> [String: Any]

    /// Send a streaming message request and return an async stream of SSE events.
    ///
    /// The stream yields ``SSEEvent`` values using Anthropic-format event types
    /// for compatibility with the Agent's streaming logic.
    nonisolated func streamMessage(
        model: String,
        messages: [[String: Any]],
        maxTokens: Int,
        system: String?,
        tools: [[String: Any]]?,
        toolChoice: [String: Any]?,
        thinking: [String: Any]?,
        temperature: Double?
    ) async throws -> AsyncThrowingStream<SSEEvent, Error>
}

// MARK: - Shared LLM Client Helpers

/// Performs a URL request, mapping `URLError` to `SDKError` with API-key-safe messages.
///
/// Both `AnthropicClient` and `OpenAIClient` use this to centralize the
/// timeout→408 mapping and API-key sanitization in error paths.
func performLLMRequest(
    _ request: URLRequest,
    urlSession: URLSession,
    apiKey: String
) async throws -> (Data, URLResponse) {
    do {
        return try await urlSession.data(for: request)
    } catch let error as URLError {
        let statusCode = error.code == .timedOut ? 408 : 0
        let safeMessage = error.localizedDescription.replacingOccurrences(of: apiKey, with: "***")
        throw SDKError.apiError(statusCode: statusCode, message: safeMessage)
    }
}

/// Validates an HTTP response, throwing `SDKError` for non-2xx status codes.
///
/// Extracts the error message from the JSON response body when available,
/// and sanitizes the API key from error messages for security.
func validateLLMHTTPResponse(
    _ response: URLResponse?,
    data: Data?,
    apiKey: String
) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
        throw SDKError.apiError(statusCode: 0, message: "Invalid response")
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        var errorMessage = "HTTP \(httpResponse.statusCode)"

        if let data,
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            errorMessage = message
        }

        let safeMessage = errorMessage.replacingOccurrences(of: apiKey, with: "***")
        throw SDKError.apiError(statusCode: httpResponse.statusCode, message: safeMessage)
    }
}

/// Builds a JSON POST `URLRequest` with the given URL, body, and headers.
///
/// Centralizes the URLRequest creation, header application, and JSON body serialization
/// that is shared between `AnthropicClient` and `OpenAIClient`.
///
/// - Parameters:
///   - url: The target URL for the request.
///   - body: The request body as a JSON-serializable dictionary.
///   - headers: HTTP headers to set on the request.
///   - timeout: Request timeout interval in seconds. Defaults to 300.
/// - Returns: A configured `URLRequest` ready to send.
/// - Throws: ``SDKError/apiError(statusCode:message:)`` if JSON serialization fails.
func buildJSONPostRequest(
    url: URL,
    body: [String: Any],
    headers: [String: String],
    timeout: TimeInterval = 300
) throws -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = timeout
    for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
    }
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
    } catch {
        throw SDKError.apiError(statusCode: 0, message: "Failed to serialize request body")
    }
    return request
}

/// Resolves a base URL from an optional custom string, falling back to a default.
///
/// If the custom string is nil or produces an invalid URL, the default is used.
func resolveBaseURL(custom: String?, default defaultURL: String) -> URL {
    let urlString = custom ?? defaultURL
    if let parsedURL = URL(string: urlString) {
        return parsedURL
    }
    return URL(string: defaultURL)!
}

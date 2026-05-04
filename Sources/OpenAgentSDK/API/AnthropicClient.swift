import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Custom Anthropic API client implemented as an actor for safe concurrency.
/// Communicates directly with the Anthropic Messages API using URLSession.
public actor AnthropicClient: LLMClient {

    // MARK: - Properties

    /// The API key for authentication. Stored privately to prevent accidental exposure.
    private let apiKey: String

    /// The base URL for API requests. Defaults to https://api.anthropic.com
    private let baseURL: URL

    /// The URLSession used for network requests.
    private let urlSession: URLSession

    // MARK: - Initialization

    /// Creates a new AnthropicClient.
    ///
    /// - Parameters:
    ///   - apiKey: The Anthropic API key for authentication.
    ///   - baseURL: Optional custom base URL. Defaults to `https://api.anthropic.com`.
    ///   - urlSession: Optional custom URLSession (useful for testing).
    public init(apiKey: String, baseURL: String? = nil, urlSession: URLSession? = nil) {
        self.apiKey = apiKey

        let urlString = baseURL ?? "https://api.anthropic.com"
        if let parsedURL = URL(string: urlString) {
            self.baseURL = parsedURL
        } else {
            self.baseURL = URL(string: "https://api.anthropic.com")!
        }

        if let urlSession {
            self.urlSession = urlSession
        } else {
            self.urlSession = URLSession.shared
        }
    }

    // MARK: - Non-Streaming Message

    /// Sends a non-streaming message request to the Anthropic API.
    ///
    /// - Parameters:
    ///   - model: The model to use (e.g., "claude-sonnet-4-6").
    ///   - messages: Array of message dictionaries with "role" and "content" keys.
    ///   - maxTokens: Maximum number of tokens to generate.
    ///   - system: Optional system prompt.
    ///   - tools: Optional array of tool definitions.
    ///   - toolChoice: Optional tool choice configuration.
    ///   - thinking: Optional thinking configuration.
    ///   - temperature: Optional temperature value.
    /// - Returns: The full API response as a dictionary.
    public nonisolated func sendMessage(
        model: String,
        messages: [[String: Any]],
        maxTokens: Int,
        system: String? = nil,
        tools: [[String: Any]]? = nil,
        toolChoice: [String: Any]? = nil,
        thinking: [String: Any]? = nil,
        temperature: Double? = nil
    ) async throws -> [String: Any] {
        let body = buildRequestBody(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            stream: false,
            system: system,
            tools: tools,
            toolChoice: toolChoice,
            thinking: thinking,
            temperature: temperature
        )

        let request = try buildRequest(body: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            let statusCode: Int
            if error.code == .timedOut {
                statusCode = 408
            } else {
                statusCode = 0
            }
            let safeMessage = error.localizedDescription.replacingOccurrences(of: apiKey, with: "***")
            throw SDKError.apiError(statusCode: statusCode, message: safeMessage)
        }

        try validateHTTPResponse(response, data: data)

        return try parseResponse(data: data)
    }

    // MARK: - Streaming Message

    /// Sends a streaming message request to the Anthropic API.
    ///
    /// Returns an `AsyncThrowingStream` that yields `SSEEvent` values as they arrive.
    ///
    /// - Parameters: Same as `sendMessage`.
    /// - Returns: An async throwing stream of SSEEvent values.
    public nonisolated func streamMessage(
        model: String,
        messages: [[String: Any]],
        maxTokens: Int,
        system: String? = nil,
        tools: [[String: Any]]? = nil,
        toolChoice: [String: Any]? = nil,
        thinking: [String: Any]? = nil,
        temperature: Double? = nil
    ) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        let body = buildRequestBody(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            stream: true,
            system: system,
            tools: tools,
            toolChoice: toolChoice,
            thinking: thinking,
            temperature: temperature
        )

        let request = try buildRequest(body: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            let statusCode: Int
            if error.code == .timedOut {
                statusCode = 408
            } else {
                statusCode = 0
            }
            let safeMessage = error.localizedDescription.replacingOccurrences(of: apiKey, with: "***")
            throw SDKError.apiError(statusCode: statusCode, message: safeMessage)
        }

        try validateHTTPResponse(response, data: nil)

        guard let responseText = String(data: data, encoding: .utf8) else {
            throw SDKError.apiError(statusCode: 0, message: "Empty streaming response")
        }

        let parsedEvents = SSELineParser.parse(text: responseText)

        return AsyncThrowingStream { continuation in
            for parsed in parsedEvents {
                if let event = SSEEventDispatcher.dispatch(event: parsed.event, data: parsed.data) {
                    continuation.yield(event)
                }
            }
            continuation.finish()
        }
    }

    // MARK: - Private Helpers

    /// Builds a URLRequest for the Messages API endpoint.
    private nonisolated func buildRequest(body: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: baseURL.absoluteString + "/v1/messages") else {
            throw SDKError.apiError(statusCode: 0, message: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw SDKError.apiError(statusCode: 0, message: "Failed to serialize request body")
        }

        return request
    }

    /// Validates an HTTP response, throwing SDKError for non-2xx status codes.
    private nonisolated func validateHTTPResponse(_ response: URLResponse?, data: Data?) throws {
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

            // Security: ensure API key is never included in error messages
            let safeMessage = errorMessage.replacingOccurrences(of: apiKey, with: "***")
            throw SDKError.apiError(statusCode: httpResponse.statusCode, message: safeMessage)
        }
    }
}

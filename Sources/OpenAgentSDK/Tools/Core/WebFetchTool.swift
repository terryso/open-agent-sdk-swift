import Foundation

// MARK: - Input

/// Input type for the WebFetch tool.
private struct WebFetchInput: Codable {
    let url: String
    let headers: [String: String]?
}

// MARK: - Constants

private enum WebFetchConstants {
    static let defaultTimeout: TimeInterval = 30
    static let truncationLimit = 100_000
}

// MARK: - Factory

/// Creates the WebFetch tool for fetching content from URLs.
///
/// The WebFetch tool retrieves content from a given URL via HTTP GET and returns
/// the response as text. Key behaviors:
///
/// - **HTML processing**: For `text/html` responses, strips `<script>` and `<style>`
///   blocks, removes all HTML tags, and cleans up excess whitespace.
/// - **Non-HTML**: Returns raw text for other content types (JSON, plain text, etc.).
/// - **Timeout**: Default 30 seconds, configurable via `URLSessionConfiguration`.
/// - **Output truncation**: Responses exceeding 100,000 characters are truncated
///   with a `...(truncated)` marker appended.
/// - **HTTP errors**: Non-2xx status codes return `isError: true` with status info.
/// - **Network errors**: DNS failures, timeouts, TLS errors return `isError: true`
///   with error description. The tool never crashes.
/// - **Cross-platform**: Uses Foundation's `URLSession` (works on macOS and Linux).
/// - **User-Agent**: Sets `Mozilla/5.0 (compatible; AgentSDK/1.0)`.
///
/// - Returns: A `ToolProtocol` instance for the WebFetch tool.
public func createWebFetchTool(session: URLSession? = nil) -> ToolProtocol {
    // Use provided session or create default with timeout
    let urlSession: URLSession
    if let session {
        urlSession = session
    } else {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = WebFetchConstants.defaultTimeout
        urlSession = URLSession(configuration: config)
    }

    return defineTool(
        name: "WebFetch",
        description:
            "Fetch content from a URL and return it as text. " +
            "Supports HTML pages, JSON APIs, and plain text. " +
            "Strips HTML tags for readability.",
        inputSchema: [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "The URL to fetch content from"
                ],
                "headers": [
                    "type": "object",
                    "description": "Optional HTTP headers to include in the request"
                ]
            ],
            "required": ["url"]
        ],
        isReadOnly: true
    ) { (input: WebFetchInput, context: ToolContext) async throws -> ToolExecuteResult in
        // Validate URL
        guard let url = URL(string: input.url) else {
            return ToolExecuteResult(
                content: "Error: Invalid URL: \(input.url)",
                isError: true
            )
        }

        // Build request
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (compatible; AgentSDK/1.0)", forHTTPHeaderField: "User-Agent")
        if let headers = input.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Execute request
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return ToolExecuteResult(
                content: "Error fetching \(input.url): \(error.localizedDescription)",
                isError: true
            )
        }

        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            return ToolExecuteResult(
                content: "Error: Invalid response type",
                isError: true
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            return ToolExecuteResult(
                content: "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))",
                isError: true
            )
        }

        // Decode response text
        let text = String(data: data, encoding: .utf8) ?? ""

        // Process content based on Content-Type
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        var processedText = text

        if contentType.contains("text/html") {
            processedText = processHtmlContent(processedText)
        }

        // Handle empty response
        if processedText.isEmpty {
            return ToolExecuteResult(content: "(empty response)", isError: false)
        }

        // Truncate if needed
        if processedText.count > WebFetchConstants.truncationLimit {
            processedText = String(processedText.prefix(WebFetchConstants.truncationLimit)) + "\n...(truncated)"
        }

        return ToolExecuteResult(content: processedText, isError: false)
    }
}

// MARK: - HTML Processing

/// Processes HTML content by stripping script/style blocks, removing HTML tags,
/// and cleaning up excess whitespace.
///
/// - Parameter html: The raw HTML string.
/// - Returns: Cleaned plain text.
private func processHtmlContent(_ html: String) -> String {
    var result = html

    // Remove script blocks
    result = result.replacingOccurrences(
        of: "<script[^>]*>[\\s\\S]*?</script>",
        with: "",
        options: .regularExpression,
        range: nil
    )

    // Remove style blocks
    result = result.replacingOccurrences(
        of: "<style[^>]*>[\\s\\S]*?</style>",
        with: "",
        options: .regularExpression,
        range: nil
    )

    // Remove all HTML tags
    result = result.replacingOccurrences(
        of: "<[^>]+>",
        with: " ",
        options: .regularExpression,
        range: nil
    )

    // Clean up whitespace
    result = result.replacingOccurrences(
        of: "\\s+",
        with: " ",
        options: .regularExpression,
        range: nil
    ).trimmingCharacters(in: .whitespacesAndNewlines)

    return result
}

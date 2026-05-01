import Foundation

// MARK: - Input

/// Input type for the WebSearch tool.
private struct WebSearchInput: Codable {
    let query: String
    let num_results: Int?
}

// MARK: - Constants

private enum WebSearchConstants {
    static let defaultNumResults = 5
    static let defaultTimeout: TimeInterval = 15
    static let userAgent = "Mozilla/5.0 (compatible; AgentSDK/1.0)"
}

// MARK: - Search Result

/// Represents a single parsed search result from DuckDuckGo HTML.
private struct SearchResult {
    let title: String
    let url: String
    let snippet: String
}

// MARK: - Factory

/// Creates the WebSearch tool for performing web searches via DuckDuckGo.
///
/// The WebSearch tool executes search queries using the DuckDuckGo HTML search
/// interface (no API key required). Key behaviors:
///
/// - **Search engine**: Uses `https://html.duckduckgo.com/html/?q={query}`.
/// - **Result parsing**: Extracts title, URL, and snippet from search results.
/// - **Result limit**: Defaults to 5 results; configurable via `num_results`.
/// - **No results**: Returns a descriptive message (not an error).
/// - **Error handling**: Network and HTTP errors return `isError: true`.
/// - **Cross-platform**: Uses Foundation's `URLSession` (works on macOS and Linux).
///
/// - Returns: A `ToolProtocol` instance for the WebSearch tool.
public func createWebSearchTool(session: URLSession? = nil) -> ToolProtocol {
    // Use provided session or create default with timeout
    let urlSession: URLSession
    if let session {
        urlSession = session
    } else {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = WebSearchConstants.defaultTimeout
        urlSession = URLSession(configuration: config)
    }

    return defineTool(
        name: "WebSearch",
        description:
            "Search the web using DuckDuckGo and return results with titles, URLs, and snippets. " +
            "No API key required.",
        inputSchema: [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "The search query"
                ],
                "num_results": [
                    "type": "integer",
                    "description": "Number of results to return (default 5)"
                ]
            ],
            "required": ["query"]
        ],
        isReadOnly: true
    ) { (input: WebSearchInput, context: ToolContext) async throws -> ToolExecuteResult in
        // Build search URL
        let encodedQuery = input.query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input.query
        guard let searchUrl = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)") else {
            return ToolExecuteResult(
                content: "Error: Invalid search query",
                isError: true
            )
        }

        // Build request
        var request = URLRequest(url: searchUrl)
        request.setValue(WebSearchConstants.userAgent, forHTTPHeaderField: "User-Agent")

        // Execute search
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return ToolExecuteResult(
                content: "Search error: \(error.localizedDescription)",
                isError: true
            )
        }

        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            return ToolExecuteResult(
                content: "Search failed: HTTP \(httpResponse.statusCode)",
                isError: true
            )
        }

        // Parse HTML response
        let html = String(data: data, encoding: .utf8) ?? ""
        let results = parseDuckDuckGoResults(html)

        // Handle no results
        if results.isEmpty {
            return ToolExecuteResult(
                content: "No results found for \"\(input.query)\"",
                isError: false
            )
        }

        // Format results (clamp num_results to [1, results.count])
        let requested = max(1, input.num_results ?? WebSearchConstants.defaultNumResults)
        let numResults = min(requested, results.count)
        var formatted: [String] = []
        for i in 0..<numResults {
            var entry = "\(i + 1). \(results[i].title)\n   \(results[i].url)"
            if !results[i].snippet.isEmpty {
                entry += "\n   \(results[i].snippet)"
            }
            formatted.append(entry)
        }

        return ToolExecuteResult(content: formatted.joined(separator: "\n\n"), isError: false)
    }
}

// MARK: - DuckDuckGo HTML Parsing

/// Parses DuckDuckGo HTML search results to extract titles, URLs, and snippets.
///
/// Uses regular expressions to extract search result links (class `result__a`)
/// and snippets (class `result__snippet`), filtering out internal DuckDuckGo links.
///
/// - Parameter html: The raw HTML from DuckDuckGo search.
/// - Returns: An array of `SearchResult` with title, URL, and snippet.
private func parseDuckDuckGoResults(_ html: String) -> [SearchResult] {
    let resultRegex: NSRegularExpression
    let snippetRegex: NSRegularExpression

    do {
        resultRegex = try NSRegularExpression(
            pattern: "<a rel=\"nofollow\" class=\"result__a\" href=\"([^\"]*)\"[^>]*>([\\s\\S]*?)</a>",
            options: [.caseInsensitive]
        )
        snippetRegex = try NSRegularExpression(
            pattern: "<a class=\"result__snippet\"[^>]*>([\\s\\S]*?)</a>",
            options: [.caseInsensitive]
        )
    } catch {
        return []
    }

    let fullRange = NSRange(html.startIndex..., in: html)

    // Collect all link and snippet matches with their positions
    struct LocatedLink {
        let url: String
        let title: String
        let rangeEnd: Int // character position where this match ends in the HTML
    }

    struct LocatedSnippet {
        let text: String
        let rangeStart: Int // character position where this match starts in the HTML
    }

    // Extract links with positions
    var links: [LocatedLink] = []
    let resultMatches = resultRegex.matches(in: html, options: [], range: fullRange)
    for match in resultMatches {
        guard match.numberOfRanges >= 3,
              let urlRange = Range(match.range(at: 1), in: html),
              let titleRange = Range(match.range(at: 2), in: html) else {
            continue
        }
        let rawUrl = String(html[urlRange])
        let title = stripHtmlTags(String(html[titleRange]))

        // Extract real URL from DDG redirect (uddg parameter)
        let url = extractRealUrl(from: rawUrl)

        // Filter out DuckDuckGo internal links (nav, settings, etc.)
        if !url.contains("duckduckgo.com") {
            links.append(LocatedLink(
                url: url,
                title: title,
                rangeEnd: match.range.location + match.range.length
            ))
        }
    }

    // Extract snippets with positions
    var snippets: [LocatedSnippet] = []
    let snippetMatches = snippetRegex.matches(in: html, options: [], range: fullRange)
    for match in snippetMatches {
        guard match.numberOfRanges >= 2,
              let snippetRange = Range(match.range(at: 1), in: html) else {
            continue
        }
        let snippet = stripHtmlTags(String(html[snippetRange]))
        snippets.append(LocatedSnippet(
            text: snippet,
            rangeStart: match.range.location
        ))
    }

    // Pair each link with the nearest snippet that follows it in document order
    var results: [SearchResult] = []
    var snippetIndex = 0
    for link in links {
        // Advance to the first snippet at or after this link's end position
        while snippetIndex < snippets.count && snippets[snippetIndex].rangeStart < link.rangeEnd {
            snippetIndex += 1
        }
        let snippet: String
        if snippetIndex < snippets.count {
            snippet = snippets[snippetIndex].text
            snippetIndex += 1
        } else {
            snippet = ""
        }
        results.append(SearchResult(
            title: link.title,
            url: link.url,
            snippet: snippet
        ))
    }

    return results
}

/// Extracts the real URL from a DuckDuckGo redirect link.
///
/// DDG wraps result URLs in `//duckduckgo.com/l/?uddg={encodedUrl}&rut=...`.
/// This extracts the `uddg` parameter. If the URL is not a redirect,
/// it is returned as-is.
private func extractRealUrl(from rawUrl: String) -> String {
    guard let comps = URLComponents(string: rawUrl.hasPrefix("//") ? "https:\(rawUrl)" : rawUrl),
          let uddg = comps.queryItems?.first(where: { $0.name == "uddg" })?.value,
          !uddg.isEmpty else {
        return rawUrl
    }
    return uddg
}

/// Removes all HTML tags from a string.
///
/// - Parameter text: The text containing HTML tags.
/// - Returns: The text with all HTML tags removed.
private func stripHtmlTags(_ text: String) -> String {
    return text.replacingOccurrences(
        of: "<[^>]+>",
        with: "",
        options: .regularExpression,
        range: nil
    ).trimmingCharacters(in: .whitespacesAndNewlines)
}

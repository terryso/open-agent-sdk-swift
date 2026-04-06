import Foundation

/// OpenAI-compatible API client that translates between Anthropic-format interface
/// and OpenAI chat completion API format.
///
/// Use this client to connect to any OpenAI-compatible LLM provider (OpenAI, GLM,
/// Ollama, or proxy gateways like one-api/new-api).
///
/// The client accepts Anthropic-format parameters from the Agent and internally
/// converts requests to OpenAI format and responses back to Anthropic format,
/// so the Agent's processing logic works unchanged.
public actor OpenAIClient: LLMClient {

    // MARK: - Properties

    private let apiKey: String
    private let baseURL: URL
    private let urlSession: URLSession

    // MARK: - Initialization

    /// Creates a new OpenAIClient.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for authentication (sent as `Bearer` token).
    ///   - baseURL: The base URL for the API. Defaults to `https://api.openai.com`.
    ///   - urlSession: Optional custom URLSession (useful for testing).
    public init(apiKey: String, baseURL: String? = nil, urlSession: URLSession? = nil) {
        self.apiKey = apiKey

        let urlString = baseURL ?? "https://api.openai.com/v1"
        if let parsedURL = URL(string: urlString) {
            self.baseURL = parsedURL
        } else {
            self.baseURL = URL(string: "https://api.openai.com/v1")!
        }

        if let urlSession {
            self.urlSession = urlSession
        } else {
            self.urlSession = URLSession.shared
        }
    }

    // MARK: - LLMClient Conformance

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
        let openAIMessages = Self.convertMessages(messages: messages, system: system)
        let openAITools = tools.map { Self.convertTools($0) }

        var body: [String: Any] = [
            "model": model,
            "messages": openAIMessages,
            "max_tokens": maxTokens,
            "stream": false,
        ]
        if let openAITools {
            body["tools"] = openAITools
        }
        if let toolChoice {
            body["tool_choice"] = Self.convertToolChoice(toolChoice)
        }
        if let temperature {
            body["temperature"] = temperature
        }

        let request = try buildRequest(body: body)
        let (data, response) = try await sendRequest(request, urlSession: urlSession)
        try validateHTTPResponse(response, data: data, apiKey: apiKey)

        return try Self.convertResponse(data: data)
    }

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
        let openAIMessages = Self.convertMessages(messages: messages, system: system)
        let openAITools = tools.map { Self.convertTools($0) }

        var body: [String: Any] = [
            "model": model,
            "messages": openAIMessages,
            "max_tokens": maxTokens,
            "stream": true,
        ]
        if let openAITools {
            body["tools"] = openAITools
        }
        if let toolChoice {
            body["tool_choice"] = Self.convertToolChoice(toolChoice)
        }
        if let temperature {
            body["temperature"] = temperature
        }

        let request = try buildRequest(body: body)
        let (data, response) = try await sendRequest(request, urlSession: urlSession)
        try validateHTTPResponse(response, data: data, apiKey: apiKey)

        guard let responseText = String(data: data, encoding: .utf8) else {
            throw SDKError.apiError(statusCode: 0, message: "Empty streaming response")
        }

        let chunks = Self.parseOpenAISSEChunks(text: responseText)
        let events = Self.convertStreamChunksToEvents(chunks: chunks, model: model)

        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    // MARK: - Request Building

    private nonisolated func buildRequest(body: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: baseURL.absoluteString + "/chat/completions") else {
            throw SDKError.apiError(statusCode: 0, message: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw SDKError.apiError(statusCode: 0, message: "Failed to serialize request body")
        }

        return request
    }

    // MARK: - Network

    private nonisolated func sendRequest(
        _ request: URLRequest,
        urlSession: URLSession
    ) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch let error as URLError {
            let statusCode = error.code == .timedOut ? 408 : 0
            let safeMessage = error.localizedDescription.replacingOccurrences(of: apiKey, with: "***")
            throw SDKError.apiError(statusCode: statusCode, message: safeMessage)
        }
    }

    private nonisolated func validateHTTPResponse(
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

    // MARK: - Message Conversion (Anthropic → OpenAI)

    /// Converts Anthropic-format messages to OpenAI-format messages.
    ///
    /// Key difference: Anthropic packs multiple tool_result blocks into a single user message,
    /// while OpenAI requires each tool result as a separate "tool" role message.
    /// This method expands accordingly.
    private static func convertMessages(
        messages: [[String: Any]],
        system: String?
    ) -> [[String: Any]] {
        var result: [[String: Any]] = []

        // Prepend system message if provided
        if let system {
            result.append(["role": "system", "content": system])
        }

        for msg in messages {
            guard let role = msg["role"] as? String else { continue }
            let content = msg["content"]

            switch role {
            case "user":
                let expanded = convertUserMessage(content: content)
                result.append(contentsOf: expanded)

            case "assistant":
                if let converted = convertAssistantContent(content) {
                    result.append(converted)
                }

            default:
                result.append(msg)
            }
        }

        return result
    }

    /// Convert a user message. May expand into multiple OpenAI messages if it contains tool_results.
    private static func convertUserMessage(content: Any?) -> [[String: Any]] {
        guard let blocks = content as? [[String: Any]] else {
            // Plain string content
            return [["role": "user", "content": content ?? ""]]
        }

        // Check for tool_result blocks
        let toolResults = blocks.filter { $0["type"] as? String == "tool_result" }
        if !toolResults.isEmpty {
            // Each tool_result becomes a separate "tool" role message in OpenAI
            return toolResults.map { block in
                let toolCallId = block["tool_use_id"] as? String ?? ""
                let resultContent: Any
                if let blockContent = block["content"] {
                    resultContent = blockContent
                } else {
                    resultContent = ""
                }
                return [
                    "role": "tool",
                    "tool_call_id": toolCallId,
                    "content": resultContent,
                ] as [String: Any]
            }
        }

        // Plain text blocks — join and return as single user message
        let texts = blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
        return [["role": "user", "content": texts.joined()]]
    }

    /// Convert assistant message content. Handles tool_use blocks.
    private static func convertAssistantContent(_ content: Any?) -> [String: Any]? {
        guard let blocks = content as? [[String: Any]] else {
            if let text = content as? String {
                return ["role": "assistant", "content": text]
            }
            return ["role": "assistant", "content": ""]
        }

        // Extract text content
        let textParts = blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
        let textContent = textParts.joined()

        // Extract tool_use blocks → OpenAI tool_calls
        let toolUseBlocks = blocks.filter { $0["type"] as? String == "tool_use" }

        var result: [String: Any] = ["role": "assistant"]

        if toolUseBlocks.isEmpty {
            result["content"] = textContent
        } else {
            result["content"] = textContent.isEmpty ? nil : textContent
            result["tool_calls"] = toolUseBlocks.enumerated().map { index, block in
                let inputDict = block["input"] as? [String: Any] ?? [:]
                let arguments = (try? JSONSerialization.data(withJSONObject: inputDict, options: []))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                return [
                    "id": block["id"] as? String ?? "call_\(index)",
                    "type": "function",
                    "function": [
                        "name": block["name"] as? String ?? "",
                        "arguments": arguments,
                    ],
                ] as [String: Any]
            }
        }

        return result
    }

    // MARK: - Tool Conversion (Anthropic → OpenAI)

    /// Converts Anthropic tool definitions to OpenAI function calling format.
    private static func convertTools(_ tools: [[String: Any]]) -> [[String: Any]] {
        tools.map { tool in
            var function: [String: Any] = [:]
            if let name = tool["name"] as? String {
                function["name"] = name
            }
            if let description = tool["description"] as? String {
                function["description"] = description
            }
            if let schema = tool["input_schema"] as? [String: Any] {
                function["parameters"] = schema
            }
            return [
                "type": "function",
                "function": function,
            ] as [String: Any]
        }
    }

    /// Converts Anthropic tool_choice to OpenAI tool_choice format.
    private static func convertToolChoice(_ choice: [String: Any]) -> Any {
        if let type = choice["type"] as? String {
            switch type {
            case "auto":
                return "auto"
            case "any":
                return "required"
            case "tool":
                if let name = choice["name"] as? String {
                    return ["type": "function", "function": ["name": name]] as [String: Any]
                }
            default:
                break
            }
        }
        return "auto"
    }

    // MARK: - Response Conversion (OpenAI → Anthropic)

    /// Converts an OpenAI chat completion response to Anthropic format.
    private static func convertResponse(data: Data) throws -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw SDKError.apiError(statusCode: 0, message: "Failed to parse response JSON")
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw SDKError.apiError(statusCode: 0, message: "Missing choices in response")
        }

        var content: [[String: Any]] = []

        // Text content
        if let text = message["content"] as? String, !text.isEmpty {
            content.append(["type": "text", "text": text])
        }

        // Tool calls → tool_use blocks
        if let toolCalls = message["tool_calls"] as? [[String: Any]] {
            for toolCall in toolCalls {
                let id = toolCall["id"] as? String ?? ""
                let function = toolCall["function"] as? [String: Any] ?? [:]
                let name = function["name"] as? String ?? ""
                let argumentsStr = function["arguments"] as? String ?? "{}"
                let input = parseInputJson(argumentsStr)

                content.append([
                    "type": "tool_use",
                    "id": id,
                    "name": name,
                    "input": input,
                ] as [String: Any])
            }
        }

        // Map finish_reason → stop_reason
        let finishReason = firstChoice["finish_reason"] as? String ?? ""
        let stopReason = mapStopReason(finishReason)

        // Map usage
        var usage: [String: Any] = ["input_tokens": 0, "output_tokens": 0]
        if let openAIUsage = json["usage"] as? [String: Any] {
            usage = [
                "input_tokens": openAIUsage["prompt_tokens"] as? Int ?? 0,
                "output_tokens": openAIUsage["completion_tokens"] as? Int ?? 0,
            ]
        }

        return [
            "id": json["id"] as? String ?? "",
            "type": "message",
            "role": "assistant",
            "content": content,
            "model": json["model"] as? String ?? "",
            "stop_reason": stopReason,
            "usage": usage,
        ] as [String: Any]
    }

    private static func mapStopReason(_ finishReason: String) -> String {
        switch finishReason {
        case "stop": return "end_turn"
        case "tool_calls": return "tool_use"
        case "length": return "max_tokens"
        default: return finishReason
        }
    }

    // MARK: - SSE Parsing (OpenAI Format)

    /// Parses OpenAI SSE text into individual chunk dictionaries.
    /// OpenAI format: `data: {...}\n\n` with `data: [DONE]` terminator.
    private static func parseOpenAISSEChunks(text: String) -> [[String: Any]] {
        var chunks: [[String: Any]] = []
        let lines = text.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data:"), trimmed != "data: [DONE]" else { continue }

            let jsonStr = String(trimmed.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces)
            guard let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                continue
            }
            chunks.append(json)
        }

        return chunks
    }

    // MARK: - Stream Conversion (OpenAI chunks → Anthropic SSEEvents)

    /// Converts a sequence of OpenAI streaming chunks into Anthropic-format SSEEvents.
    private static func convertStreamChunksToEvents(
        chunks: [[String: Any]],
        model: String
    ) -> [SSEEvent] {
        var events: [SSEEvent] = []
        var blockIndex = 0
        var totalOutputTokens = 0
        var textBlockOpen = true

        // messageStart
        events.append(.messageStart(message: [
            "id": "",
            "type": "message",
            "role": "assistant",
            "content": [],
            "model": model,
            "stop_reason": nil as Any?,
            "usage": ["input_tokens": 0, "output_tokens": 0],
        ]))

        // contentBlockStart for text
        events.append(.contentBlockStart(index: blockIndex, contentBlock: [
            "type": "text",
            "text": "",
        ]))

        // Track tool call index → content block index
        var toolBlockMap: [Int: Int] = [:]
        var toolBlockOpen: [Int: Bool] = [:]

        for chunk in chunks {
            guard let choices = chunk["choices"] as? [[String: Any]],
                  let firstChoice = choices.first else { continue }

            let delta = firstChoice["delta"] as? [String: Any] ?? [:]
            let finishReason = firstChoice["finish_reason"] as? String

            // Handle tool calls
            if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                for tc in toolCalls {
                    let tcIndex = tc["index"] as? Int ?? 0

                    // New tool call — emit contentBlockStart
                    if let id = tc["id"] as? String,
                       let function = tc["function"] as? [String: Any],
                       let name = function["name"] as? String {
                        // Close text block if still open
                        if textBlockOpen {
                            events.append(.contentBlockStop(index: blockIndex))
                            blockIndex += 1
                            textBlockOpen = false
                        }

                        toolBlockMap[tcIndex] = blockIndex
                        toolBlockOpen[tcIndex] = true

                        events.append(.contentBlockStart(index: blockIndex, contentBlock: [
                            "type": "tool_use",
                            "id": id,
                            "name": name,
                            "input": [:],
                        ]))
                        blockIndex += 1
                    }

                    // Accumulate arguments
                    if let function = tc["function"] as? [String: Any],
                       let arguments = function["arguments"] as? String,
                       !arguments.isEmpty {
                        let bIdx = toolBlockMap[tcIndex] ?? blockIndex
                        events.append(.contentBlockDelta(index: bIdx, delta: [
                            "type": "input_json_delta",
                            "partial_json": arguments,
                        ]))
                    }
                }
            }

            // Handle text content
            if let text = delta["content"] as? String, !text.isEmpty {
                events.append(.contentBlockDelta(index: 0, delta: [
                    "type": "text_delta",
                    "text": text,
                ]))
            }

            // Handle finish
            if let finishReason {
                // Close any open tool blocks
                for (tcIdx, _) in toolBlockOpen {
                    if toolBlockOpen[tcIdx] == true, let bIdx = toolBlockMap[tcIdx] {
                        events.append(.contentBlockStop(index: bIdx))
                    }
                }
                // Close text block if still open
                if textBlockOpen {
                    events.append(.contentBlockStop(index: 0))
                }

                let stopReason = mapStopReason(finishReason)

                // Extract usage from chunk if available
                if let chunkUsage = chunk["usage"] as? [String: Any] {
                    totalOutputTokens = chunkUsage["completion_tokens"] as? Int ?? totalOutputTokens
                }

                events.append(.messageDelta(delta: [
                    "stop_reason": stopReason,
                ], usage: [
                    "input_tokens": 0,
                    "output_tokens": totalOutputTokens,
                ]))

                events.append(.messageStop)
            }
        }

        // Safety: ensure messageStop is always emitted
        let hasMessageStop = events.contains { event in
            if case .messageStop = event { return true }
            return false
        }
        if !hasMessageStop {
            if textBlockOpen {
                events.append(.contentBlockStop(index: 0))
            }
            events.append(.messageDelta(delta: ["stop_reason": "end_turn"], usage: ["input_tokens": 0, "output_tokens": totalOutputTokens]))
            events.append(.messageStop)
        }

        return events
    }

    // MARK: - Helpers

    private static func parseInputJson(_ jsonString: String) -> [String: Any] {
        guard !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return [:]
        }
        return dict
    }
}

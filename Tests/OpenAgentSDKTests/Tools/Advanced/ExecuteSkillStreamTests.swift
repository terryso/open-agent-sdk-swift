import XCTest
@testable import OpenAgentSDK

/// Tests for Agent.executeSkillStream() — streaming direct skill execution.
final class ExecuteSkillStreamTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SkillStreamMockURLProtocol.reset()
    }

    override func tearDown() {
        SkillStreamMockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeMockSession() -> URLSession { makeMockURLSession(protocolClass: SkillStreamMockURLProtocol.self) }

    private func makeStreamingResponse(text: String = "ok") -> Data {
        let events = """
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_test","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-6","usage":{"input_tokens":10,"output_tokens":0}}}

        event: content_block_start
        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"\(text)"}}

        event: content_block_stop
        data: {"type":"content_block_stop","index":0}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":\(text.count)}}

        event: message_stop
        data: {"type":"message_stop"}

        """
        return Data(events.utf8)
    }

    private func setupMockResponse() {
        let data = makeStreamingResponse()
        SkillStreamMockURLProtocol.mockResponses = [
            "https://api.anthropic.com/v1/messages": (200, ["content-type": "text/event-stream"], data)
        ]
    }

    // MARK: - Helper: Create a test skill

    private func makeSkill(
        name: String = "test_skill",
        description: String = "A test skill",
        aliases: [String] = [],
        toolRestrictions: [ToolRestriction]? = nil,
        modelOverride: String? = nil,
        isAvailable: @escaping @Sendable () -> Bool = { true },
        promptTemplate: String = "Test prompt template"
    ) -> Skill {
        Skill(
            name: name,
            description: description,
            aliases: aliases,
            toolRestrictions: toolRestrictions,
            modelOverride: modelOverride,
            isAvailable: isAvailable,
            promptTemplate: promptTemplate
        )
    }

    // MARK: - Error Cases

    /// Returns error result when skill is not found in registry.
    func testExecuteSkillStream_notFound_returnsError() async {
        let registry = SkillRegistry()
        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        let stream = agent.executeSkillStream("nonexistent")
        var messages: [SDKMessage] = []
        for await message in stream {
            messages.append(message)
        }

        // Should yield exactly one .result message with errorDuringExecution
        let resultMessages = messages.compactMap { msg -> SDKMessage.ResultData? in
            if case .result(let data) = msg { return data }
            return nil
        }
        XCTAssertEqual(resultMessages.count, 1)
        XCTAssertEqual(resultMessages[0].subtype, .errorDuringExecution)
        XCTAssertTrue((resultMessages[0].errors?.first ?? "").contains("not found"))
    }

    /// Returns error result when skill is registered but not available.
    func testExecuteSkillStream_notAvailable_returnsError() async {
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "unavailable",
            isAvailable: { false }
        ))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        let stream = agent.executeSkillStream("unavailable")
        var messages: [SDKMessage] = []
        for await message in stream {
            messages.append(message)
        }

        let resultMessages = messages.compactMap { msg -> SDKMessage.ResultData? in
            if case .result(let data) = msg { return data }
            return nil
        }
        XCTAssertEqual(resultMessages.count, 1)
        XCTAssertEqual(resultMessages[0].subtype, .errorDuringExecution)
        XCTAssertTrue((resultMessages[0].errors?.first ?? "").contains("not available"))
    }

    /// Returns empty stream when agent is closed.
    func testExecuteSkillStream_agentClosed_returnsEmpty() async {
        let registry = SkillRegistry()
        registry.register(makeSkill(name: "closed-test"))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        try? await agent.close()
        let stream = agent.executeSkillStream("closed-test")
        var messages: [SDKMessage] = []
        for await message in stream {
            messages.append(message)
        }

        XCTAssertTrue(messages.isEmpty)
    }

    // MARK: - State Restoration

    /// Restores allowedTools after streaming skill execution.
    func testExecuteSkillStream_restoresAllowedTools() async {
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "restricted-skill",
            toolRestrictions: [.bash, .read],
            promptTemplate: "Do restricted things"
        ))

        setupMockResponse()
        let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry,
            allowedTools: ["Bash", "Read", "Write"]
        ), client: client)

        XCTAssertEqual(agent.options.allowedTools, ["Bash", "Read", "Write"])

        let stream = agent.executeSkillStream("restricted-skill")
        for await _ in stream {}

        XCTAssertEqual(agent.options.allowedTools, ["Bash", "Read", "Write"])
    }

    /// Restores model after streaming skill execution when skill has modelOverride.
    func testExecuteSkillStream_restoresModel() async {
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "opus-skill",
            modelOverride: "claude-opus-4-6",
            promptTemplate: "Do opus things"
        ))

        setupMockResponse()
        let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ), client: client)

        XCTAssertEqual(agent.model, "claude-sonnet-4-6")

        let stream = agent.executeSkillStream("opus-skill")
        for await _ in stream {}

        XCTAssertEqual(agent.model, "claude-sonnet-4-6")
    }

    /// Does not change model when skill has no modelOverride.
    func testExecuteSkillStream_noModelOverride_keepsModel() async {
        let registry = SkillRegistry()
        registry.register(makeSkill(
            name: "basic-skill",
            modelOverride: nil,
            promptTemplate: "Do basic things"
        ))

        setupMockResponse()
        let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ), client: client)

        XCTAssertEqual(agent.model, "claude-sonnet-4-6")
        let stream = agent.executeSkillStream("basic-skill")
        for await _ in stream {}
        XCTAssertEqual(agent.model, "claude-sonnet-4-6")
    }
}

// MARK: - Mock URL Protocol

private final class SkillStreamMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var mockResponses: [String: (Int, [String: String], Data)] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url?.absoluteString,
              let mock = Self.mockResponses[url] else {
            client?.urlProtocol(self, didFailWithError: NSError(
                domain: "SkillStreamMock", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No mock for \(request.url?.absoluteString ?? "nil")"]
            ))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: mock.0, httpVersion: "HTTP/1.1", headerFields: mock.1)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: mock.2)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func reset() { mockResponses = [:] }
}

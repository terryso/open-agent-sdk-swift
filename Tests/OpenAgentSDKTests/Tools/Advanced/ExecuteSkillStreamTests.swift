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
        registry.register(makeTestSkill(
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
        registry.register(makeTestSkill(name: "closed-test"))

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
        registry.register(makeTestSkill(
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
        registry.register(makeTestSkill(
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
        registry.register(makeTestSkill(
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

    // MARK: - Story 29.3: Direct Skill Package Context

    /// AC1: Filesystem skill prompt contains the absolute baseDir.
    func testExecuteSkillStream_promptContainsAbsoluteBaseDir_whenFilesystemSkill() async {
        let registry = SkillRegistry()
        registry.register(Skill(
            name: "filesystem-skill",
            description: "Test filesystem skill",
            promptTemplate: "Run the workflow",
            baseDir: "/abs/skill/dir",
            supportingFiles: ["references/workflow-steps.md"]
        ))

        setupMockResponse()
        let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ), client: client)

        let stream = agent.executeSkillStream("filesystem-skill", args: "do thing")
        for await _ in stream {}

        guard let body = SkillStreamMockURLProtocol.lastRequestBody else {
            XCTFail("No request body captured; mock did not intercept the streaming request")
            return
        }
        // Use JSON-decoded prompt text so forward slashes match cleanly
        // (raw body bytes contain JSON `\/` escapes that would defeat substring checks).
        let promptText = extractPromptTextFromRequestBody(body) ?? ""
        XCTAssertTrue(promptText.contains("/abs/skill/dir"),
                      "Expected prompt to contain absolute baseDir; got: \(promptText)")
    }

    /// AC1: Filesystem skill prompt lists supporting files in relative form (not absolute).
    func testExecuteSkillStream_promptContainsRelativeSupportingFiles() async {
        let registry = SkillRegistry()
        registry.register(Skill(
            name: "filesystem-skill",
            description: "Test filesystem skill",
            promptTemplate: "Run the workflow",
            baseDir: "/abs/skill/dir",
            supportingFiles: ["references/workflow-steps.md"]
        ))

        setupMockResponse()
        let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ), client: client)

        let stream = agent.executeSkillStream("filesystem-skill", args: "do thing")
        for await _ in stream {}

        guard let body = SkillStreamMockURLProtocol.lastRequestBody else {
            XCTFail("No request body captured")
            return
        }
        let promptText = extractPromptTextFromRequestBody(body) ?? ""
        XCTAssertTrue(promptText.contains("references/workflow-steps.md"),
                      "Expected prompt to list supporting file as relative path; got: \(promptText)")
        XCTAssertFalse(promptText.contains("/abs/skill/dir/references/workflow-steps.md"),
                       "Supporting file must NOT be expanded to an absolute path (progressive disclosure); got: \(promptText)")
    }

    /// AC2: Prompt must NOT inline supporting file contents (progressive disclosure).
    ///
    /// Seeds a real supporting file under a temporary baseDir containing a unique token,
    /// then asserts the assembled prompt lists the file PATH but does NOT inline its
    /// CONTENTS. Without seeding the file, the assertion would be vacuously true — the
    /// token would exist nowhere, so `!contains(token)` could never fail regardless of
    /// whether the implementation inlines file contents.
    func testExecuteSkillStream_promptDoesNotContainSupportingFileContents() async throws {
        let uniqueToken = "UNIQUE_TOKEN_29_3_PROG_DISC"
        // Create a real skill package directory with a supporting file that contains
        // the unique token. This makes the absence assertion meaningful: if the
        // implementation regressed to inlining file contents, the token would appear.
        let tmpRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-29.3-progdisc-\(UUID().uuidString)", isDirectory: true)
        let refsDir = tmpRoot.appendingPathComponent("references", isDirectory: true)
        try FileManager.default.createDirectory(at: refsDir, withIntermediateDirectories: true)
        let supportingFile = refsDir.appendingPathComponent("workflow-steps.md")
        let supportingData = try XCTUnwrap(uniqueToken.data(using: .utf8))
        try supportingData.write(to: supportingFile)
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        let registry = SkillRegistry()
        registry.register(Skill(
            name: "filesystem-skill",
            description: "Test filesystem skill",
            promptTemplate: "Run the workflow",
            baseDir: tmpRoot.path,
            supportingFiles: ["references/workflow-steps.md"]
        ))

        setupMockResponse()
        let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ), client: client)

        let stream = agent.executeSkillStream("filesystem-skill", args: "do thing")
        for await _ in stream {}

        guard let body = SkillStreamMockURLProtocol.lastRequestBody else {
            XCTFail("No request body captured")
            return
        }
        // Use JSON-decoded prompt text so forward slashes in paths match cleanly
        // (raw body bytes contain JSON `\/` escapes that defeat substring checks).
        let promptText = extractPromptTextFromRequestBody(body) ?? ""
        // Positive control: the supporting file PATH must appear.
        XCTAssertTrue(promptText.contains("references/workflow-steps.md"),
                      "Prompt must list the supporting file path; got: \(promptText)")
        // The real assertion: the supporting file CONTENTS (the unique token) must NOT appear.
        XCTAssertFalse(promptText.contains(uniqueToken),
                       "Prompt must NOT inline supporting file contents — only paths should be listed (progressive disclosure); got: \(promptText)")
    }

    /// AC2: Prompt shape follows epic spec ordering: promptTemplate → "Skill package context:" → "User request:".
    func testExecuteSkillStream_promptShape_followsEpicSpec() async {
        let registry = SkillRegistry()
        registry.register(Skill(
            name: "filesystem-skill",
            description: "Test filesystem skill",
            promptTemplate: "TEMPLATE_MARKER_29_3",
            baseDir: "/abs/skill/dir",
            supportingFiles: ["references/workflow-steps.md"]
        ))

        setupMockResponse()
        let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ), client: client)

        let stream = agent.executeSkillStream("filesystem-skill", args: "do thing")
        for await _ in stream {}

        guard let body = SkillStreamMockURLProtocol.lastRequestBody else {
            XCTFail("No request body captured")
            return
        }
        let bodyString = String(data: body, encoding: .utf8) ?? ""
        guard let templateRange = bodyString.range(of: "TEMPLATE_MARKER_29_3") else {
            XCTFail("promptTemplate not found in body; got: \(bodyString)")
            return
        }
        guard let contextRange = bodyString.range(of: "Skill package context:") else {
            XCTFail("'Skill package context:' marker not found; got: \(bodyString)")
            return
        }
        guard let userRequestRange = bodyString.range(of: "User request:") else {
            XCTFail("'User request:' marker not found; got: \(bodyString)")
            return
        }
        XCTAssertLessThan(templateRange.lowerBound, contextRange.lowerBound,
                          "promptTemplate must appear before 'Skill package context:'; got: \(bodyString)")
        XCTAssertLessThan(contextRange.lowerBound, userRequestRange.lowerBound,
                          "'Skill package context:' must appear before 'User request:'; got: \(bodyString)")
    }

    /// AC3: Programmatic skill (no baseDir/supportingFiles) keeps prompt shape unchanged (regression guard).
    func testExecuteSkillStream_promptUnchanged_whenProgrammaticSkill() async {
        let template = "Do programmatic things"
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "programmatic-skill",
            promptTemplate: template
        ))

        setupMockResponse()
        let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ), client: client)

        let stream = agent.executeSkillStream("programmatic-skill", args: "do thing")
        for await _ in stream {}

        guard let body = SkillStreamMockURLProtocol.lastRequestBody else {
            XCTFail("No request body captured")
            return
        }
        let bodyString = String(data: body, encoding: .utf8) ?? ""
        // Body is JSON, so embedded newlines are encoded as the two-char sequence `\n`.
        // Match the JSON-escaped form so the assertion survives serialization.
        let expectedLegacy = "\(template)\\n\\n---\\nUser request: do thing"
        XCTAssertTrue(bodyString.contains(expectedLegacy),
                      "Programmatic skill must keep legacy prompt shape exactly; expected substring:\n\(expectedLegacy)\n-- got: \(bodyString)")
        XCTAssertFalse(bodyString.contains("Skill package context:"),
                       "Programmatic skill must NOT contain 'Skill package context:'; got: \(bodyString)")
    }

    /// AC3/AC5: Programmatic skill with no args — prompt equals promptTemplate (no 'User request:' line).
    func testExecuteSkillStream_promptUnchanged_whenProgrammaticSkillNoArgs() async {
        let template = "Do programmatic things without args"
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "programmatic-skill-noargs",
            promptTemplate: template
        ))

        setupMockResponse()
        let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ), client: client)

        let stream = agent.executeSkillStream("programmatic-skill-noargs")
        for await _ in stream {}

        guard let body = SkillStreamMockURLProtocol.lastRequestBody else {
            XCTFail("No request body captured")
            return
        }
        let bodyString = String(data: body, encoding: .utf8) ?? ""
        XCTAssertTrue(bodyString.contains(template),
                      "Expected prompt to contain template; got: \(bodyString)")
        XCTAssertFalse(bodyString.contains("User request:"),
                       "Must NOT emit 'User request:' when args is nil; got: \(bodyString)")
        XCTAssertFalse(bodyString.contains("Skill package context:"),
                       "Programmatic skill must NOT contain 'Skill package context:'; got: \(bodyString)")
    }

    /// AC4: Skill with only baseDir (no supportingFiles) — emits baseDir line, omits supportingFiles section.
    func testExecuteSkillStream_promptHasPackageContext_whenOnlyBaseDir() async {
        let registry = SkillRegistry()
        registry.register(Skill(
            name: "basedir-only-skill",
            description: "Skill with baseDir only",
            promptTemplate: "Run workflow",
            baseDir: "/abs/basedir/only",
            supportingFiles: []
        ))

        setupMockResponse()
        let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ), client: client)

        let stream = agent.executeSkillStream("basedir-only-skill", args: "do thing")
        for await _ in stream {}

        guard let body = SkillStreamMockURLProtocol.lastRequestBody else {
            XCTFail("No request body captured")
            return
        }
        let promptText = extractPromptTextFromRequestBody(body) ?? ""
        XCTAssertTrue(promptText.contains("/abs/basedir/only"),
                      "Prompt must contain baseDir; got: \(promptText)")
        XCTAssertTrue(promptText.contains("Skill package context:"),
                      "Prompt must contain 'Skill package context:' block when baseDir is set; got: \(promptText)")
        XCTAssertFalse(promptText.contains("supportingFiles:"),
                       "Prompt must NOT emit 'supportingFiles:' line when list is empty; got: \(promptText)")
    }

    /// AC4: Skill with only supportingFiles (baseDir nil) — emits supportingFiles section, flags missing baseDir.
    func testExecuteSkillStream_promptHasPackageContext_whenOnlySupportingFiles() async {
        let registry = SkillRegistry()
        registry.register(Skill(
            name: "supporting-only-skill",
            description: "Skill with supportingFiles only",
            promptTemplate: "Run workflow",
            baseDir: nil,
            supportingFiles: ["references/steps.md"]
        ))

        setupMockResponse()
        let client = AnthropicClient(apiKey: "test-key", urlSession: makeMockSession())
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ), client: client)

        let stream = agent.executeSkillStream("supporting-only-skill", args: "do thing")
        for await _ in stream {}

        guard let body = SkillStreamMockURLProtocol.lastRequestBody else {
            XCTFail("No request body captured")
            return
        }
        let promptText = extractPromptTextFromRequestBody(body) ?? ""
        XCTAssertTrue(promptText.contains("references/steps.md"),
                      "Prompt must contain supportingFiles entry; got: \(promptText)")
        XCTAssertTrue(promptText.contains("Skill package context:"),
                      "Prompt must contain 'Skill package context:' block when supportingFiles non-empty; got: \(promptText)")
        // When baseDir is nil, the implementation surfaces this with the literal
        // '- baseDir: <none>' rendering (Agent.swift `skill.baseDir ?? "<none>"`).
        // Pin the assertion to the actual rendering so a regression to a different
        // marker (e.g. "baseDir: nil") would fail the test rather than silently pass.
        XCTAssertTrue(promptText.contains("- baseDir: <none>"),
                      "Prompt must render missing baseDir as '- baseDir: <none>'; got: \(promptText)")
    }
}

// MARK: - Mock URL Protocol

private final class SkillStreamMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var mockResponses: [String: (Int, [String: String], Data)] = [:]

    /// Captures the most recent HTTP request body sent to the mock.
    /// Story 29.3 uses this to assert prompt content delivered to the LLM
    /// (since `resolveSkillForExecution` is `private`, the request body is
    /// the only observable side effect).
    nonisolated(unsafe) static var lastRequestBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // Capture request body before serving mock response. Prefer httpBodyStream
        // (used by AnthropicClient for streaming requests), fall back to httpBody.
        // The stream is owned by URLProtocol at this layer, so reading it does not
        // disturb the SDK's downstream consumption.
        if let stream = request.httpBodyStream {
            Self.lastRequestBody = readRequestBodyFromStream(stream)
        } else if let body = request.httpBody {
            Self.lastRequestBody = body
        }

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

    static func reset() {
        mockResponses = [:]
        lastRequestBody = nil
    }
}

import XCTest
@testable import OpenAgentSDK

/// Tests for Agent.executeSkill() — direct skill execution bypassing LLM skill-discovery.
final class ExecuteSkillTests: XCTestCase {

    // MARK: - Error Cases

    /// Returns error when skill is not found in registry.
    func testExecuteSkill_notFound_returnsError() async {
        let registry = SkillRegistry()
        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        let result = await agent.executeSkill("nonexistent")
        XCTAssertEqual(result.status, .errorDuringExecution)
        XCTAssertTrue((result.errors?.first ?? "").contains("not found"),
                       "Expected 'not found' error, got: \(String(describing: result.errors))")
    }

    /// Returns error when skill is registered but not available.
    func testExecuteSkill_notAvailable_returnsError() async {
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

        let result = await agent.executeSkill("unavailable")
        XCTAssertEqual(result.status, .errorDuringExecution)
        XCTAssertTrue((result.errors?.first ?? "").contains("not available"),
                       "Expected 'not available' error, got: \(String(describing: result.errors))")
    }

    /// Returns error when agent is closed.
    func testExecuteSkill_agentClosed_returnsError() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(name: "commit"))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        try? await agent.close()
        let result = await agent.executeSkill("commit")
        XCTAssertEqual(result.status, .errorDuringExecution)
        XCTAssertTrue((result.errors?.first ?? "").contains("already closed"))
    }

    // MARK: - Skill Resolution

    /// Resolves skill by alias.
    func testExecuteSkill_resolvesByAlias() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "commit",
            aliases: ["ci"],
            promptTemplate: "Create a commit"
        ))

        XCTAssertNotNil(registry.find("ci"))
    }

    // MARK: - State Restoration

    /// Restores allowedTools after skill execution.
    func testExecuteSkill_restoresAllowedTools() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "restricted-skill",
            toolRestrictions: [.bash, .read],
            promptTemplate: "Do restricted things"
        ))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry,
            allowedTools: ["Bash", "Read", "Write"]
        ))

        XCTAssertEqual(agent.options.allowedTools, ["Bash", "Read", "Write"])

        _ = await agent.executeSkill("restricted-skill")

        XCTAssertEqual(agent.options.allowedTools, ["Bash", "Read", "Write"])
    }

    /// Restores model after skill execution when skill has modelOverride.
    func testExecuteSkill_restoresModel() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "opus-skill",
            modelOverride: "claude-opus-4-6",
            promptTemplate: "Do opus things"
        ))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        XCTAssertEqual(agent.model, "claude-sonnet-4-6")

        _ = await agent.executeSkill("opus-skill")

        XCTAssertEqual(agent.model, "claude-sonnet-4-6")
    }

    /// Does not change model when skill has no modelOverride.
    func testExecuteSkill_noModelOverride_keepsModel() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "basic-skill",
            modelOverride: nil,
            promptTemplate: "Do basic things"
        ))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        XCTAssertEqual(agent.model, "claude-sonnet-4-6")
        _ = await agent.executeSkill("basic-skill")
        XCTAssertEqual(agent.model, "claude-sonnet-4-6")
    }

    // MARK: - Tool Restriction Filtering

    /// When skill has toolRestrictions, they are applied during execution and restored after.
    func testExecuteSkill_toolRestrictions_appliedDuringExecution() async {
        let registry = SkillRegistry()
        registry.register(makeTestSkill(
            name: "restricted",
            toolRestrictions: [.bash, .read],
            promptTemplate: "Restricted execution"
        ))

        let agent = createAgent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ))

        XCTAssertNil(agent.options.allowedTools)

        _ = await agent.executeSkill("restricted")

        XCTAssertNil(agent.options.allowedTools)
    }

    // MARK: - Story 29.3: Direct Skill Package Context

    /// Shared helper: registers a skill, drives `executeSkill` through a mock AnthropicClient
    /// that captures the request body via `SkillRequestRecordingURLProtocol`. Returns the
    /// captured body as raw `Data` (or fails the test if no body was captured).
    ///
    /// Callers should pass the result to `extractPromptTextFromRequestBody(_:)` for substring
    /// assertions on the assembled prompt (raw body bytes contain JSON `\/` escapes that defeat
    /// naive substring checks).
    private func driveExecuteSkillAndCaptureRawBody(
        skill: Skill,
        args: String? = "do thing",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> Data {
        let registry = SkillRegistry()
        registry.register(skill)

        let data = SkillRequestRecordingURLProtocol.makeNonStreamingResponse()
        SkillRequestRecordingURLProtocol.mockResponses = [
            "https://api.anthropic.com/v1/messages": (200, ["content-type": "application/json"], data)
        ]

        let client = AnthropicClient(
            apiKey: "test-key",
            urlSession: makeMockURLSession(protocolClass: SkillRequestRecordingURLProtocol.self)
        )
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry
        ), client: client)

        _ = await agent.executeSkill(skill.name, args: args)

        guard let body = SkillRequestRecordingURLProtocol.lastRequestBody else {
            XCTFail("No request body captured for executeSkill; mock did not intercept", file: file, line: line)
            return Data()
        }
        return body
    }

    /// Shared helper: returns the captured body as a UTF-8 string (raw bytes, including
    /// JSON escape sequences). Used for legacy regression checks that assert on the raw
    /// JSON-escaped form.
    private func driveExecuteSkillAndCaptureBody(
        skill: Skill,
        args: String? = "do thing",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> String {
        let body = await driveExecuteSkillAndCaptureRawBody(skill: skill, args: args, file: file, line: line)
        return String(data: body, encoding: .utf8) ?? ""
    }

    /// AC1 (non-stream): Filesystem skill prompt contains the absolute baseDir.
    func testExecuteSkill_promptContainsAbsoluteBaseDir_whenFilesystemSkill() async {
        SkillRequestRecordingURLProtocol.reset()
        defer { SkillRequestRecordingURLProtocol.reset() }

        let skill = Skill(
            name: "filesystem-skill",
            description: "Test filesystem skill",
            promptTemplate: "Run the workflow",
            baseDir: "/abs/skill/dir",
            supportingFiles: ["references/workflow-steps.md"]
        )
        let rawBody = await driveExecuteSkillAndCaptureRawBody(skill: skill)
        let promptText = extractPromptTextFromRequestBody(rawBody) ?? ""

        XCTAssertTrue(promptText.contains("/abs/skill/dir"),
                      "Expected prompt to contain absolute baseDir; got: \(promptText)")
        XCTAssertTrue(promptText.contains("references/workflow-steps.md"),
                      "Expected prompt to list supporting file as relative path; got: \(promptText)")
    }

    /// AC3 (non-stream): Programmatic skill keeps legacy prompt shape exactly (regression guard).
    func testExecuteSkill_promptUnchanged_whenProgrammaticSkill() async {
        SkillRequestRecordingURLProtocol.reset()
        defer { SkillRequestRecordingURLProtocol.reset() }

        let template = "Do programmatic things"
        let skill = makeTestSkill(name: "programmatic-skill", promptTemplate: template)
        let bodyString = await driveExecuteSkillAndCaptureBody(skill: skill, args: "do thing")

        // Body is JSON, so embedded newlines are encoded as the two-char sequence `\n`.
        // Match the JSON-escaped form so the assertion survives serialization.
        let expectedLegacy = "\(template)\\n\\n---\\nUser request: do thing"
        XCTAssertTrue(bodyString.contains(expectedLegacy),
                      "Programmatic skill must keep legacy prompt shape exactly; expected substring:\n\(expectedLegacy)\n-- got: \(bodyString)")
        XCTAssertFalse(bodyString.contains("Skill package context:"),
                       "Programmatic skill must NOT contain 'Skill package context:'; got: \(bodyString)")
    }

    /// AC2 (non-stream): Prompt shape ordering: promptTemplate → "Skill package context:" → "User request:".
    func testExecuteSkill_promptShape_followsEpicSpec() async {
        SkillRequestRecordingURLProtocol.reset()
        defer { SkillRequestRecordingURLProtocol.reset() }

        let skill = Skill(
            name: "filesystem-skill",
            description: "Test filesystem skill",
            promptTemplate: "TEMPLATE_MARKER_29_3_NS",
            baseDir: "/abs/skill/dir",
            supportingFiles: ["references/workflow-steps.md"]
        )
        let bodyString = await driveExecuteSkillAndCaptureBody(skill: skill, args: "do thing")

        guard let templateRange = bodyString.range(of: "TEMPLATE_MARKER_29_3_NS") else {
            XCTFail("promptTemplate not found; got: \(bodyString)")
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
}

// MARK: - Mock URL Protocol (non-stream, request-body recording)

/// Mock URL protocol for non-streaming `executeSkill` tests.
///
/// Captures the outgoing HTTP request body (so Story 29.3 tests can assert
/// prompt content delivered to the LLM) and returns a minimal non-streaming
/// Anthropic `/v1/messages` JSON response. Mirrors the recording pattern used
/// by `SkillStreamMockURLProtocol` in `ExecuteSkillStreamTests.swift`.
private final class SkillRequestRecordingURLProtocol: URLProtocol {
    nonisolated(unsafe) static var mockResponses: [String: (Int, [String: String], Data)] = [:]
    nonisolated(unsafe) static var lastRequestBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let stream = request.httpBodyStream {
            Self.lastRequestBody = readRequestBodyFromStream(stream)
        } else if let body = request.httpBody {
            Self.lastRequestBody = body
        }

        guard let url = request.url?.absoluteString,
              let mock = Self.mockResponses[url] else {
            client?.urlProtocol(self, didFailWithError: NSError(
                domain: "SkillRequestRecordingMock", code: -1,
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

    /// Minimal valid non-streaming Anthropic `/v1/messages` response.
    static func makeNonStreamingResponse() -> Data {
        let json = """
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "model": "claude-sonnet-4-6",
          "content": [{"type": "text", "text": "ok"}],
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 10, "output_tokens": 2}
        }
        """
        return Data(json.utf8)
    }
}

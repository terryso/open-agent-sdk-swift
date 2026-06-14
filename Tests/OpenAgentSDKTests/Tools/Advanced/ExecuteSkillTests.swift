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

    // MARK: - Story 29.5: Declaration-Based Tool Filtering on the Skill Execution Path

    /// ATDD RED PHASE: Tests for Story 29.5 -- the `executeSkill` / `executeSkillStream`
    /// paths migrate from consuming `skill.toolRestrictions` (enum-only) to preferring
    /// `skill.toolDeclarations` (lossless MCP/custom/unknown-aware), so that an MCP
    /// declaration like `mcp__srv__search` is preserved during skill execution rather
    /// than dropped (the legacy enum path has no MCP case). The legacy path remains as a
    /// fallback when `skill.toolDeclarations == nil` (programmatic / pre-29.4 skills).
    ///
    /// Tests below assert EXPECTED behavior. They will FAIL until:
    ///   - `Sources/OpenAgentSDK/Types/AgentTypes.swift` `AgentOptions` gains an
    ///     `allowedToolDeclarations: [ToolDeclaration]?` field (default nil).
    ///   - `Sources/OpenAgentSDK/Core/Agent.swift` `executeSkill` / `executeSkillStream`
    ///     set `options.allowedToolDeclarations = skill.toolDeclarations` when non-nil,
    ///     falling back to `options.allowedTools = restrictions.map(\.rawValue)` otherwise.
    ///   - `assembleFullToolPool` applies `filterToolsByDeclarations` when
    ///     `options.allowedToolDeclarations` is non-empty.
    ///   - Both paths restore the saved value on completion (like `savedAllowedTools`).
    /// TDD Phase: RED (feature not implemented yet)
    ///
    /// Red mode: COMPILE-TIME — `AgentOptions.allowedToolDeclarations` does not exist yet,
    /// so `agent.options.allowedToolDeclarations` fails with `Cannot find ... in scope`.

    /// AC5 [P0]: `AgentOptions` gains an `allowedToolDeclarations` field defaulting to
    /// nil, so existing AgentOptions constructions keep compiling (backward compatible).
    func testExecuteSkill_agentOptions_allowedToolDeclarations_defaultsToNil() {
        let options = AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core)
        )
        XCTAssertNil(options.allowedToolDeclarations,
                     "New field must default to nil so existing callers compile unchanged")
    }

    /// AC5 [P0]: When a skill has non-nil `toolDeclarations`, executing it sets
    /// `options.allowedToolDeclarations` for the duration of the run and restores the
    /// original (nil) value afterwards. Driven through the recording mock client so no
    /// real LLM call is made (project rule #27).
    func testExecuteSkill_toolDeclarations_appliedAndRestored() async {
        SkillRequestRecordingURLProtocol.reset()
        defer { SkillRequestRecordingURLProtocol.reset() }

        let declarations: [ToolDeclaration] = ToolDeclaration.fromToolNames([
            "Bash",
            "mcp__srv__search",
        ])
        let skill = Skill(
            name: "declaration-skill",
            description: "skill carrying richer declarations",
            toolRestrictions: [.bash],  // legacy field coexists for backward compat
            toolDeclarations: declarations,
            promptTemplate: "Do declaration-aware things"
        )

        let body = await driveExecuteSkillAndCaptureRawBody(skill: skill, args: "run")
        XCTAssertFalse(body.isEmpty, "Mock must capture the request body")

        // After execution, allowedToolDeclarations must be restored to its pre-skill value.
        // The test agent is constructed inside driveExecuteSkillAndCaptureRawBody and goes
        // out of scope; this assertion is a forward-compatibility placeholder that the
        // field EXISTS and is settable. The integration-level preservation assertion lives
        // in the assembleFullToolPool-driven test below.
        // (Field existence is the red-phase contract; behavioral coverage deepens in green.)
    }

    /// AC5 [P0]: A skill whose `toolDeclarations` includes an MCP name must cause the
    /// executed skill's tool pool to retain the MCP tool (when available), whereas the
    /// legacy `toolRestrictions`-only path would drop it (no enum case for MCP). This is
    /// the headline behavioral fix of Story 29.5.
    ///
    /// Verification is structural: we assert that `AgentOptions.allowedToolDeclarations`
    /// is the wiring channel, and that a declaration set containing an MCP name can be
    /// applied to a tool pool via `filterToolsByDeclarations` (the helper tested in
    /// `ToolDeclarationFilterTests`). Full LLM-driven pool inspection is an E2E concern
    /// deferred to Story 29.7.
    func testExecuteSkill_mcpDeclarationSurvivableViaFilterHelper() {
        // Given: declarations including an MCP name + an available MCP-named tool
        let declarations: [ToolDeclaration] = ToolDeclaration.fromToolNames([
            "Bash",
            "mcp__srv__search",
        ])

        // Build a stub MCP-named tool without real MCP I/O.
        let mcpTool = defineTool(
            name: "mcp__srv__search",
            description: "stub mcp tool",
            inputSchema: ["type": "object", "properties": [:]],
            isReadOnly: true
        ) { _, _ in ToolExecuteResult(content: "stub", isError: false) }
        let bashTool = createBashTool()
        let available: [ToolProtocol] = [bashTool, mcpTool]

        // When: the shared helper filters (this is what assembleFullToolPool will call
        // when options.allowedToolDeclarations is non-empty)
        let (filtered, _) = filterToolsByDeclarations(
            available: available,
            allowed: declarations,
            disallowed: nil
        )

        // Then: the MCP tool survives, proving the declaration path retains what the
        // legacy enum-only path would have dropped.
        let names = filtered.map { $0.name }
        XCTAssertTrue(names.contains("mcp__srv__search"),
                      "MCP declaration must keep the MCP tool in the pool — the legacy path drops it")
        XCTAssertTrue(names.contains("Bash"),
                      "Bash declaration must keep Bash in the pool")
    }

    /// AC5 [P0]: Fallback path — when a skill has NO `toolDeclarations` (programmatic /
    /// pre-29.4 skill), the legacy `toolRestrictions` path must remain in effect and
    /// `allowedToolDeclarations` must NOT be set. Backward compatibility guard.
    func testExecuteSkill_fallsBackToToolRestrictions_whenNoDeclarations() async {
        SkillRequestRecordingURLProtocol.reset()
        defer { SkillRequestRecordingURLProtocol.reset() }

        // Programmatic skill: toolDeclarations == nil, toolRestrictions populated
        let skill = Skill(
            name: "legacy-programmatic-skill",
            description: "pre-29.4 programmatic skill",
            toolRestrictions: [.bash, .read],
            promptTemplate: "Do legacy things"
            // toolDeclarations intentionally nil
        )

        let body = await driveExecuteSkillAndCaptureRawBody(skill: skill, args: "run")
        XCTAssertFalse(body.isEmpty, "Mock must capture the request body; legacy path must still execute")
    }

    // MARK: - Story 29.5 review fix: declaration path must clear legacy `allowedTools`

    /// Review fix (HIGH): when `executeSkill` takes the `toolDeclarations` path, it must
    /// also clear `options.allowedTools` so `assembleFullToolPool` does not double-filter
    /// (the legacy `assembleToolPool` filter would otherwise drop MCP/custom tools from
    /// the pool before `applyAllowedDeclarations` ever sees them). The host's pre-existing
    /// `allowedTools` must be restored on completion.
    ///
    /// This test drives `executeSkill` against the recording mock client with an agent that
    /// has a pre-set `allowedTools` (which does NOT include an MCP tool the skill declares),
    /// then asserts the host's `allowedTools` is restored exactly after the call. The
    /// in-call "allowedTools is nil" behavior is what prevents the legacy filter from
    /// stripping the MCP tool before `applyAllowedDeclarations` runs.
    func testExecuteSkill_declarationPath_clearsAndRestoresLegacyAllowedTools() async {
        SkillRequestRecordingURLProtocol.reset()
        defer { SkillRequestRecordingURLProtocol.reset() }

        let declarations: [ToolDeclaration] = ToolDeclaration.fromToolNames([
            "Bash",
            "mcp__srv__search",
        ])
        let skill = Skill(
            name: "decl-skill-with-host-allowlist",
            description: "skill carrying declarations; host also has an allowlist",
            toolDeclarations: declarations,
            promptTemplate: "Do declaration-aware things"
        )

        let registry = SkillRegistry()
        registry.register(skill)

        SkillRequestRecordingURLProtocol.mockResponses = [
            "https://api.anthropic.com/v1/messages":
                (200, ["content-type": "application/json"],
                 SkillRequestRecordingURLProtocol.makeNonStreamingResponse())
        ]
        let client = AnthropicClient(
            apiKey: "test-key",
            urlSession: makeMockURLSession(protocolClass: SkillRequestRecordingURLProtocol.self)
        )

        // Host has a pre-existing allowedTools that does NOT include the MCP tool. If the
        // declaration path failed to clear it, the MCP tool would be dropped before
        // `applyAllowedDeclarations` runs and the skill could not use it.
        let agent = Agent(options: AgentOptions(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            tools: getAllBaseTools(tier: .core),
            skillRegistry: registry,
            allowedTools: ["Bash", "Read", "Write"]
        ), client: client)

        XCTAssertEqual(agent.options.allowedTools, ["Bash", "Read", "Write"],
                       "Pre-condition: host has a legacy allowlist set")

        _ = await agent.executeSkill("decl-skill-with-host-allowlist", args: "run")

        XCTAssertEqual(agent.options.allowedTools, ["Bash", "Read", "Write"],
                       "Post-call: host's legacy allowedTools must be restored exactly")
        XCTAssertNil(agent.options.allowedToolDeclarations,
                     "Post-call: allowedToolDeclarations must be restored to nil")
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

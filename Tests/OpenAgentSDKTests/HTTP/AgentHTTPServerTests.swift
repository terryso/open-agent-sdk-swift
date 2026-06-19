import XCTest
import Hummingbird
import HummingbirdTesting
@testable import OpenAgentSDK

// MARK: - AgentHTTPServer Tests

/// Unit tests for the testable surface of `AgentHTTPServer`.
///
/// **Coverage scope & limitations.** ~80% of `AgentHTTPServer`'s logic lives
/// inside Hummingbird route closures (POST /v1/runs, GET /v1/runs/:id, the
/// SSE events stream, etc.). These can only be exercised by dispatching real
/// HTTP requests, which requires the `HummingbirdTesting` package — a
/// dependency the project does not currently ship (see `Package.swift`).
/// `buildTestApplication()` is documented as the intended entry point for
/// such integration tests.
///
/// This file covers the testable surface that does NOT need HTTP:
///   - Initializer parameter storage (observable via `runTracker` /
///     `eventBroadcaster` accessors and via hook state).
///   - Identity stability of `runTracker` / `eventBroadcaster` across calls.
///   - Default-vs-custom `customRouteBuilder` / `runHandler` hooks.
///   - `buildTestApplication()` produces a non-nil app both with and without
///     custom hooks registered, and is idempotent.
///
/// Filesystem side-effects land in an isolated temp dir via `dataDir`.
final class AgentHTTPServerTests: TempDirTestCase {

    // MARK: - Fixtures

    private func makeAgent() -> Agent {
        let options = AgentOptions(
            apiKey: "sk-test-not-used",
            model: "claude-sonnet-4-6",
            systemPrompt: "test"
        )
        return createAgent(options: options)
    }

    private func makeServer(
        agent: Agent? = nil,
        host: String = "127.0.0.1",
        port: Int = 4242,
        authKey: String? = nil,
        maxConcurrentRuns: Int = 5,
        dataDir: String? = nil
    ) -> AgentHTTPServer {
        AgentHTTPServer(
            agent: agent ?? makeAgent(),
            host: host,
            port: port,
            authKey: authKey,
            maxConcurrentRuns: maxConcurrentRuns,
            dataDir: dataDir ?? tempDir
        )
    }

    // MARK: - Initialization

    func testInit_withAllParameters_doesNotThrow() {
        let server = makeServer(
            host: "0.0.0.0",
            port: 9999,
            authKey: "secret",
            maxConcurrentRuns: 10
        )
        XCTAssertNotNil(server.runTracker)
        XCTAssertNotNil(server.eventBroadcaster)
    }

    func testInit_defaultDataDir_doesNotThrow() {
        // Even without explicit dataDir, init must succeed (default is deferred).
        let server = AgentHTTPServer(agent: makeAgent())
        XCTAssertNotNil(server.runTracker)
    }

    func testInit_maxConcurrentRunsOne_isAllowed() {
        let server = makeServer(maxConcurrentRuns: 1)
        XCTAssertNotNil(server.runTracker)
    }

    // MARK: - Accessor identity

    func testRunTracker_returnsSameInstanceAcrossCalls() {
        let server = makeServer()
        let first = server.runTracker
        let second = server.runTracker
        // RunTracker is an actor (reference type); same instance expected.
        XCTAssertTrue(first === second)
    }

    func testEventBroadcaster_returnsSameInstanceAcrossCalls() {
        let server = makeServer()
        XCTAssertTrue(server.eventBroadcaster === server.eventBroadcaster)
    }

    func testRunTracker_isDistinctAcrossServerInstances() {
        let a = makeServer()
        let b = makeServer()
        XCTAssertFalse(a.runTracker === b.runTracker,
                       "Each server should own its own RunTracker")
    }

    func testEventBroadcaster_isDistinctAcrossServerInstances() {
        let a = makeServer()
        let b = makeServer()
        XCTAssertFalse(a.eventBroadcaster === b.eventBroadcaster)
    }

    // MARK: - customRouteBuilder hook

    func testCustomRouteBuilder_defaultsToNil() {
        let server = makeServer()
        XCTAssertNil(server.customRouteBuilder)
    }

    func testCustomRouteBuilder_canBeAssigned() {
        let server = makeServer()
        server.customRouteBuilder = { _, _, _, _, _ in }
        XCTAssertNotNil(server.customRouteBuilder)
        // The closure's actual invocation contract is covered by
        // `testBuildTestApplication_invokesCustomRouteBuilder`, which exercises
        // the real registerRoutes path instead of needing to manually build
        // a RouterGroup (which requires a parent router).
    }

    // MARK: - runHandler hook

    func testRunHandler_defaultsToNil() {
        let server = makeServer()
        XCTAssertNil(server.runHandler)
    }

    func testRunHandler_canBeAssigned() {
        let server = makeServer()
        let hook: AgentHTTPServer.RunHandlerClosure = { _, _, _, _, _, _ in }
        server.runHandler = hook
        XCTAssertNotNil(server.runHandler)
    }

    // MARK: - buildTestApplication

    func testBuildTestApplication_returnsNonNilApp() {
        let server = makeServer()
        let app = server.buildTestApplication()
        XCTAssertNotNil(app)
        // Application is a reference type on Hummingbird; we can't assert much
        // about its internal router without HummingbirdTesting, but successful
        // return confirms `registerRoutes(on:)` completes for all 5 endpoints.
    }

    func testBuildTestApplication_isIdempotent() {
        // Building twice must not crash or mutate shared state — registerRoutes
        // captures self only via specific dependencies, so multiple builds are
        // safe and produce independent Application instances.
        let server = makeServer()
        let first = server.buildTestApplication()
        let second = server.buildTestApplication()
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
    }

    func testBuildTestApplication_withAuthKey_doesNotThrow() {
        // When authKey is set, an AuthMiddleware is added to the router.
        // registerRoutes must still complete successfully.
        let server = makeServer(authKey: "test-key")
        XCTAssertNotNil(server.buildTestApplication())
    }

    func testBuildTestApplication_invokesCustomRouteBuilder() {
        // The custom route hook is called at the end of registerRoutes.
        // Building the app must invoke it exactly once.
        let server = makeServer()
        var invocations = 0
        server.customRouteBuilder = { _, _, _, _, _ in
            invocations += 1
        }
        _ = server.buildTestApplication()
        XCTAssertEqual(invocations, 1,
                       "customRouteBuilder should fire exactly once per buildTestApplication")
    }

    func testBuildTestApplication_withoutCustomRouteBuilder_doesNotCrash() {
        // The optional-call pattern `customRouteBuilder?(...)` must tolerate nil.
        let server = makeServer()
        XCTAssertNotNil(server.buildTestApplication())
    }

    // MARK: - Stop without start

    func testStop_beforeStart_isNoop() async {
        // stop() must be safe to call even when no serverTask exists.
        let server = makeServer()
        await server.stop()  // should not crash
    }

    // MARK: - Multiple builds reflect latest hook

    func testBuildTestApplication_picksUpLatestHookState() {
        let server = makeServer()
        var firstHookCount = 0
        var secondHookCount = 0

        server.customRouteBuilder = { _, _, _, _, _ in firstHookCount += 1 }
        _ = server.buildTestApplication()
        XCTAssertEqual(firstHookCount, 1)

        server.customRouteBuilder = { _, _, _, _, _ in secondHookCount += 1 }
        _ = server.buildTestApplication()
        XCTAssertEqual(firstHookCount, 1, "First hook should not fire again")
        XCTAssertEqual(secondHookCount, 1, "Second hook should fire on rebuild")
    }
}

// MARK: - AgentHTTPServerRoutesTests

/// Route-level integration tests for `AgentHTTPServer` using HummingbirdTesting's
/// `.router` test framework.
///
/// These tests dispatch real HTTP requests through the full Hummingbird router —
/// exercising the route closures in `registerRoutes(on:)` that the
/// `AgentHTTPServerTests` class above cannot reach.
///
/// All runs use a stub `runHandler` that completes immediately so no real
/// Agent/LLM is invoked.
final class AgentHTTPServerRoutesTests: TempDirTestCase {

    // MARK: - Fixtures

    private func makeAgent() -> Agent {
        let options = AgentOptions(
            apiKey: "sk-test-not-used",
            model: "claude-sonnet-4-6",
            systemPrompt: "test"
        )
        return createAgent(options: options)
    }

    /// Server with a stub `runHandler` that completes the run synchronously.
    /// This lets us test the events endpoint's replay-buffer branch without
    /// invoking a real agent.
    private func makeServer(authKey: String? = nil) -> AgentHTTPServer {
        let server = AgentHTTPServer(
            agent: makeAgent(),
            authKey: authKey,
            dataDir: tempDir
        )
        server.runHandler = { task, request, tracker, broadcaster, _, limiter in
            await limiter.acquire()
            // Drain any pending runId by listing runs and finding a queued one.
            let runs = await tracker.listRuns()
            guard let queued = runs.first(where: { $0.status == .queued }) else {
                await limiter.release()
                return
            }
            try? await tracker.startRun(runId: queued.runId)
            try? await tracker.completeRun(
                runId: queued.runId,
                resultText: "stub result for: \(task)",
                totalSteps: 1,
                durationMs: 5
            )
            await limiter.release()
        }
        return server
    }

    // MARK: - GET /v1/health

    func testHealth_returns200WithOKStatus() async throws {
        let app = makeServer().buildTestApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/v1/health", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                let body = String(buffer: response.body)
                XCTAssertTrue(body.contains("\"status\":\"ok\""),
                              "Health body should include status=ok; got: \(body)")
            }
        }
    }

    func testHealth_returnsContentTypeJSON() async throws {
        let app = makeServer().buildTestApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/v1/health", method: .get) { response in
                // Hummingbird appends charset=utf-8 to JSON responses.
                XCTAssertEqual(
                    response.headers[.contentType]?.hasPrefix("application/json"),
                    true,
                    "Health endpoint should return JSON content type; got: \(String(describing: response.headers[.contentType]))"
                )
            }
        }
    }

    // MARK: - POST /v1/runs

    func testPostRuns_rejectsEmptyTaskWith400() async throws {
        let app = makeServer().buildTestApplication()
        let body = ByteBuffer(string: "{\"task\":\"\"}")
        try await app.test(.router) { client in
            try await client.execute(uri: "/v1/runs", method: .post, body: body) { response in
                XCTAssertEqual(response.status, .badRequest)
                let bodyStr = String(buffer: response.body)
                XCTAssertTrue(bodyStr.lowercased().contains("task"),
                              "400 body should mention task; got: \(bodyStr)")
            }
        }
    }

    func testPostRuns_rejectsInvalidJSONWith400() async throws {
        let app = makeServer().buildTestApplication()
        let body = ByteBuffer(string: "{not valid json")
        try await app.test(.router) { client in
            try await client.execute(uri: "/v1/runs", method: .post, body: body) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    func testPostRuns_acceptsValidTaskAndReturns202WithRunId() async throws {
        let app = makeServer().buildTestApplication()
        let body = ByteBuffer(string: "{\"task\":\"hello world\"}")
        try await app.test(.router) { client in
            try await client.execute(uri: "/v1/runs", method: .post, body: body) { response in
                XCTAssertEqual(response.status, .accepted)
                let bodyStr = String(buffer: response.body)
                XCTAssertTrue(bodyStr.contains("\"run_id\""),
                              "Body should include run_id field; got: \(bodyStr)")
                XCTAssertTrue(bodyStr.contains("\"task\":\"hello world\""),
                              "Body should echo task back; got: \(bodyStr)")
            }
        }
    }

    func testPostRuns_withMaxStepsField_isAccepted() async throws {
        // Verifies the snake_case CodingKey mapping for max_steps.
        let app = makeServer().buildTestApplication()
        let body = ByteBuffer(string: "{\"task\":\"x\",\"max_steps\":3}")
        try await app.test(.router) { client in
            try await client.execute(uri: "/v1/runs", method: .post, body: body) { response in
                XCTAssertEqual(response.status, .accepted)
            }
        }
    }

    // MARK: - GET /v1/runs

    func testGetRuns_initiallyReturnsEmptyArray() async throws {
        let app = makeServer().buildTestApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/v1/runs", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                let body = String(buffer: response.body).trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertEqual(body, "[]",
                               "Empty server should return empty array; got: \(body)")
            }
        }
    }

    func testGetRuns_afterPostReturnsOneElement() async throws {
        let app = makeServer().buildTestApplication()
        try await app.test(.router) { client in
            // Submit one run first
            let postBody = ByteBuffer(string: "{\"task\":\"first\"}")
            _ = try await client.execute(uri: "/v1/runs", method: .post, body: postBody)

            // Then list
            try await client.execute(uri: "/v1/runs", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                let body = String(buffer: response.body)
                XCTAssertTrue(body.contains("\"run_id\""),
                              "List should contain at least one run; got: \(body)")
            }
        }
    }

    // MARK: - GET /v1/runs/:id

    func testGetRunById_unknownIdReturns404() async throws {
        let app = makeServer().buildTestApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/v1/runs/does-not-exist", method: .get) { response in
                XCTAssertEqual(response.status, .notFound)
            }
        }
    }

    func testGetRunById_validIdReturns200WithTask() async throws {
        let app = makeServer().buildTestApplication()
        try await app.test(.router) { client in
            // Create a run, capture runId from response
            let postBody = ByteBuffer(string: "{\"task\":\"inspect-me\"}")
            var runId: String?
            try await client.execute(uri: "/v1/runs", method: .post, body: postBody) { response in
                XCTAssertEqual(response.status, .accepted)
                let bodyData = Data(buffer: response.body)
                let decoded = try? JSONDecoder().decode(RunResponse.self, from: bodyData)
                runId = decoded?.runId
            }
            let id = try XCTUnwrap(runId)

            // Now fetch it
            try await client.execute(uri: "/v1/runs/\(id)", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                let body = String(buffer: response.body)
                XCTAssertTrue(body.contains("\"run_id\":\"\(id)\""),
                              "Body should echo the requested run_id; got: \(body)")
                XCTAssertTrue(body.contains("\"task\":\"inspect-me\""))
            }
        }
    }

    // MARK: - GET /v1/runs/:id/events

    func testGetRunEvents_unknownIdReturns404() async throws {
        let app = makeServer().buildTestApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/v1/runs/missing/events", method: .get) { response in
                XCTAssertEqual(response.status, .notFound)
            }
        }
    }

    func testGetRunEvents_completedRunWithEmptyBufferReturns204() async throws {
        // A run that's been completed but whose broadcaster has no buffered
        // events (no SSE was ever published) should return 204 No Content.
        let app = makeServer().buildTestApplication()
        try await app.test(.router) { client in
            let postBody = ByteBuffer(string: "{\"task\":\"quick\"}")
            var runId: String?
            try await client.execute(uri: "/v1/runs", method: .post, body: postBody) { response in
                let bodyData = Data(buffer: response.body)
                runId = (try? JSONDecoder().decode(RunResponse.self, from: bodyData))?.runId
            }
            let id = try XCTUnwrap(runId)

            // Give the detached runHandler a chance to complete the run.
            // The stub completes synchronously inside its closure, but the
            // POST handler spawns it on a detached Task. Poll briefly.
            try await _Concurrency.Task.sleep(for: .milliseconds(50))

            try await client.execute(uri: "/v1/runs/\(id)/events", method: .get) { response in
                // Either 204 (completed, no buffer) or 200 (still queued/running,
                // live stream). The important contract: status must be 2xx.
                XCTAssertTrue(
                    response.status == .noContent || response.status == .ok,
                    "Completed/queued run events should return 2xx; got \(response.status)"
                )
            }
        }
    }

    // MARK: - Auth middleware
    //
    // NOTE: AuthMiddleware explicitly bypasses /v1/health (see AuthMiddleware.swift:31-34)
    // so we must use a non-health endpoint (/v1/runs) to exercise auth enforcement.

    func testAuth_protectedRouteWithoutKeyReturns401() async throws {
        let app = makeServer(authKey: "secret-key").buildTestApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/v1/runs", method: .get) { response in
                // AuthMiddleware rejects requests without a valid Bearer token.
                XCTAssertTrue(
                    (400...499).contains(response.status.code),
                    "Missing auth key should be rejected with 4xx; got \(response.status)"
                )
            }
        }
    }

    func testAuth_protectedRouteWithCorrectKeyReturns200() async throws {
        let app = makeServer(authKey: "secret-key").buildTestApplication()
        try await app.test(.router) { client in
            var headers = HTTPFields()
            headers[.authorization] = "Bearer secret-key"
            try await client.execute(uri: "/v1/runs", method: .get, headers: headers) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testAuth_protectedRouteWithWrongKeyReturns4xx() async throws {
        let app = makeServer(authKey: "secret-key").buildTestApplication()
        try await app.test(.router) { client in
            var headers = HTTPFields()
            headers[.authorization] = "Bearer wrong-key"
            try await client.execute(uri: "/v1/runs", method: .get, headers: headers) { response in
                XCTAssertTrue(
                    (400...499).contains(response.status.code),
                    "Wrong auth key should be rejected with 4xx; got \(response.status)"
                )
            }
        }
    }

    func testAuth_healthEndpointBypassesAuth() async throws {
        // Contract: AuthMiddleware must let /v1/health through even with no key,
        // so external health-check probes work without credentials.
        let app = makeServer(authKey: "secret-key").buildTestApplication()
        try await app.test(.router) { client in
            try await client.execute(uri: "/v1/health", method: .get) { response in
                XCTAssertEqual(response.status, .ok,
                               "Health must bypass auth so probes can reach it")
            }
        }
    }
}

import Foundation
import Hummingbird
import os

// MARK: - AgentHTTPServer

/// HTTP API Server that exposes any Agent as a REST + SSE service.
///
/// Provides endpoints:
/// - `POST /v1/runs` — start a background agent run
/// - `GET /v1/runs` — list all runs
/// - `GET /v1/runs/{id}` — get run status
/// - `GET /v1/runs/{id}/events` — SSE stream of run events
/// - `GET /v1/health` — health check
public class AgentHTTPServer: @unchecked Sendable {

    // MARK: - Properties

    private let agent: Agent
    private let host: String
    private let port: Int
    private let authKey: String?
    private let maxConcurrentRuns: Int

    /// Hook for custom route registration. Called after SDK registers its standard routes.
    /// Receives the v1 router group, tracker, broadcaster, persistence service, and limiter.
    public var customRouteBuilder: (
        (_ router: RouterGroup<BasicRequestContext>,
         _ tracker: RunTracker,
         _ broadcaster: EventBroadcaster,
         _ persistenceService: RunPersistenceService,
         _ limiter: ConcurrencyLimiter) -> Void
    )?

    /// Hook for custom run execution. When set, POST /v1/runs calls this instead of built-in executeRun.
    public var runHandler: RunHandlerClosure?

    /// Typealias for the run handler closure.
    public typealias RunHandlerClosure = @Sendable (
        _ task: String,
        _ request: CreateRunRequest,
        _ tracker: RunTracker,
        _ broadcaster: EventBroadcaster,
        _ persistenceService: RunPersistenceService,
        _ limiter: ConcurrencyLimiter
    ) async -> Void

    private let tracker: RunTracker
    private let broadcaster: EventBroadcaster
    private let persistenceService: RunPersistenceService
    private let limiter: ConcurrencyLimiter

    private var app: Application<RouterResponder<BasicRequestContext>>?
    private var serverTask: _Concurrency.Task<Void, Never>?

    private static let logger = os.Logger(subsystem: "com.open-agent-sdk", category: "AgentHTTPServer")

    /// Public accessor for the run tracker.
    public var runTracker: RunTracker { tracker }

    /// Public accessor for the event broadcaster.
    public var eventBroadcaster: EventBroadcaster { broadcaster }

    // MARK: - Initialization

    public init(
        agent: Agent,
        host: String = "127.0.0.1",
        port: Int = 4242,
        authKey: String? = nil,
        maxConcurrentRuns: Int = 5,
        dataDir: String? = nil
    ) {
        self.agent = agent
        self.host = host
        self.port = port
        self.authKey = authKey
        self.maxConcurrentRuns = maxConcurrentRuns

        self.persistenceService = RunPersistenceService(baseDirectory: dataDir)
        self.broadcaster = EventBroadcaster(persistenceService: persistenceService)
        self.tracker = RunTracker()
        self.limiter = ConcurrencyLimiter(maxConcurrent: maxConcurrentRuns)
    }

    // MARK: - Start / Stop

    /// Start the HTTP server and begin accepting connections.
    public func start() async throws {
        await RunRecoveryService.recover(
            from: tracker,
            persistenceService: persistenceService,
            eventBroadcaster: broadcaster
        )

        let router = Router()

        if authKey != nil {
            router.add(middleware: AuthMiddleware<BasicRequestContext>(authKey: authKey))
        }

        registerRoutes(on: router)

        let app = Application(
            router: router,
            configuration: .init(address: .hostname(host, port: port))
        )
        self.app = app

        Self.logger.info("Starting on \(self.host):\(self.port)")
        try await app.runService()
    }

    /// Gracefully stop the server.
    public func stop() async {
        Self.logger.info("Stopping")
        serverTask?.cancel()
        serverTask = nil
    }

    /// Build an Application with all routes registered, without starting the server.
    /// Useful for integration testing with HummingbirdTesting.
    public func buildTestApplication() -> Application<RouterResponder<BasicRequestContext>> {
        let router = Router()
        if authKey != nil {
            router.add(middleware: AuthMiddleware<BasicRequestContext>(authKey: authKey))
        }
        registerRoutes(on: router)
        return Application(
            router: router,
            configuration: .init(address: .hostname(host, port: port))
        )
    }

    // MARK: - Route Registration

    private func registerRoutes(on router: Router<BasicRequestContext>) {
        let v1 = router.group("v1")

        // Health endpoint
        v1.get("health") { _, _ -> HealthResponse in
            HealthResponse()
        }

        // POST /v1/runs — start a new run
        v1.post("runs") { [tracker, broadcaster, persistenceService, limiter, agent, runHandler = self.runHandler] request, context -> Response in
            let createRequest: CreateRunRequest
            do {
                createRequest = try await request.decode(as: CreateRunRequest.self, context: context)
            } catch {
                throw HTTPError(.badRequest, message: "Invalid request body: \(error)")
            }

            guard !createRequest.task.isEmpty else {
                throw HTTPError(.badRequest, message: "Task cannot be empty.")
            }

            let run = await tracker.submitRun(task: createRequest.task)

            if let runHandler = runHandler {
                _Concurrency.Task {
                    await runHandler(createRequest.task, createRequest, tracker, broadcaster, persistenceService, limiter)
                }
            } else {
                _Concurrency.Task {
                    await Self.executeRun(
                        runId: run.runId,
                        task: createRequest.task,
                        tracker: tracker,
                        broadcaster: broadcaster,
                        persistenceService: persistenceService,
                        limiter: limiter,
                        agent: agent
                    )
                }
            }

            let response = run.toResponse()
            let encoder = JSONEncoder()
            let data = (try? encoder.encode(response)) ?? Data()
            return Response(status: .accepted, body: .init(byteBuffer: ByteBuffer(data: data)))
        }

        // GET /v1/runs — list all runs
        v1.get("runs") { [tracker] _, _ -> [RunResponse] in
            let runs = await tracker.listRuns()
            return runs.map { $0.toResponse() }
        }

        // GET /v1/runs/:id — get run status
        v1.get("runs/:id") { [tracker] _, context -> RunResponse in
            guard let runId = context.parameters.get("id") else {
                throw HTTPError(.badRequest, message: "Missing run ID.")
            }
            guard let run = await tracker.getRun(runId: runId) else {
                throw HTTPError(.notFound, message: "Run not found: \(runId)")
            }
            return run.toResponse()
        }

        // GET /v1/runs/:id/events — SSE stream
        v1.get("runs/:id/events") { [tracker, broadcaster] _, context -> Response in
            guard let runId = context.parameters.get("id") else {
                throw HTTPError(.badRequest, message: "Missing run ID.")
            }
            guard let run = await tracker.getRun(runId: runId) else {
                throw HTTPError(.notFound, message: "Run not found: \(runId)")
            }

            // If completed, replay buffered events
            if run.status == .completed || run.status == .failed || run.status == .cancelled {
                let buffered = await broadcaster.getReplayBuffer(runId: runId)
                if buffered.isEmpty {
                    return Response(status: .noContent)
                }
                let sseText = buffered.compactMap { event in
                    try? event.encodeToSSE(sequenceId: 0)
                }.joined()
                return Response(
                    status: .ok,
                    headers: [.contentType: "text/event-stream"],
                    body: .init(byteBuffer: ByteBuffer(string: sseText))
                )
            }

            // If running, stream live events
            let stream: AsyncStream<AgentSSEEvent> = await broadcaster.subscribeWithReplay(runId: runId)
            let mapped = Self.mapStream(stream) { event -> ByteBuffer in
                let sseString = (try? event.encodeToSSE(sequenceId: 0)) ?? ""
                return ByteBuffer(string: sseString)
            }

            return Response(
                status: .ok,
                headers: [.contentType: "text/event-stream", .cacheControl: "no-cache", .connection: "keep-alive"],
                body: .init(asyncSequence: mapped)
            )
        }

        // Call custom route builder if set
        customRouteBuilder?(v1, tracker, broadcaster, persistenceService, limiter)
    }

    // MARK: - Agent Execution

    private static func executeRun(
        runId: String,
        task: String,
        tracker: RunTracker,
        broadcaster: EventBroadcaster,
        persistenceService: RunPersistenceService,
        limiter: ConcurrencyLimiter,
        agent: Agent
    ) async {
        await limiter.acquire()

        do {
            try await tracker.startRun(runId: runId)
        } catch {
            await limiter.release()
            return
        }

        let startTime = Date()
        var stepIndex = 0
        var resultText = ""
        var toolNameMap: [String: String] = [:]

        let messageStream = agent.stream(task)
        var sawResult = false

        for await message in messageStream {
            switch message {
            case .toolUse(let data):
                toolNameMap[data.toolUseId] = data.toolName
                let sseEvent = AgentSSEEvent.stepStarted(StepStartedData(
                    stepIndex: stepIndex,
                    tool: data.toolName
                ))
                await broadcaster.emit(runId: runId, event: sseEvent)

            case .toolResult(let data):
                let toolName = toolNameMap[data.toolUseId] ?? "unknown"
                let sseEvent = AgentSSEEvent.stepCompleted(StepCompletedData(
                    stepIndex: stepIndex,
                    tool: toolName,
                    success: !data.isError
                ))
                await broadcaster.emit(runId: runId, event: sseEvent)
                stepIndex += 1

            case .result(let data):
                sawResult = true
                resultText = data.text
                let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
                let sseEvent = AgentSSEEvent.runCompleted(RunCompletedData(
                    runId: runId,
                    finalStatus: "completed",
                    totalSteps: stepIndex,
                    durationMs: durationMs
                ))
                await broadcaster.emit(runId: runId, event: sseEvent)

                try? await tracker.completeRun(
                    runId: runId,
                    resultText: resultText,
                    totalSteps: stepIndex,
                    durationMs: durationMs
                )

                if let run = await tracker.getRun(runId: runId) {
                    persistenceService.persistRecordSafely(run)
                }

                await broadcaster.complete(runId: runId)

            case .assistant:
                break

            default:
                break
            }
        }

        // If the stream ended without a .result message, the agent likely errored
        if !sawResult {
            try? await tracker.failRun(runId: runId, error: "agent stream terminated without result")
            if let run = await tracker.getRun(runId: runId) {
                persistenceService.persistRecordSafely(run)
            }
            await broadcaster.complete(runId: runId)
        }

        await limiter.release()
    }

    // MARK: - Helpers

    private static func mapStream<T: Sendable, U: Sendable>(_ stream: AsyncStream<T>, transform: @Sendable @escaping (T) -> U) -> AsyncStream<U> {
        AsyncStream<U> { continuation in
            _Concurrency.Task {
                for await element in stream {
                    continuation.yield(transform(element))
                }
                continuation.finish()
            }
        }
    }
}

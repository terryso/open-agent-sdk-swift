import Foundation
import OpenAgentSDK

// MARK: - Tests 87-92: Agent Event Types E2E Tests (Story 26.2)

/// E2E tests for session lifecycle event types: construction, Codable round-trip,
/// concurrent usage, existential dispatch, and JSON format validation.
/// No mocks — uses real JSONEncoder/JSONDecoder and real concurrency primitives.
struct AgentEventTypesE2ETests {
    static func run() async {
        section("87-92. Agent Event Types (E2E — Story 26.2)")
        await testSessionCreatedEvent_fullLifecycle()
        await testSessionRestoredEvent_codableRoundTrip()
        await testSessionClosedEvent_allStatuses()
        await testSessionAutoSavedEvent_concurrentUsage()
        await testSessionEvents_existentialDispatch()
        await testSessionEvents_jsonFormatSseCompatible()
        section("93-101. Agent Lifecycle Events (E2E — Story 26.3)")
        await testAgentStartedEvent_fullLifecycle()
        await testAgentCompletedEvent_codableRoundTrip()
        await testAgentFailedEvent_concurrentUsage()
        await testAgentInterruptedEvent_concurrentUsage()
        await testAgentEvents_existentialDispatch()
        await testAgentEvents_jsonFormatSseCompatible()
        await testAgentStartedEvent_concurrentUsage()
        await testAgentCompletedEvent_concurrentUsage()
        await testAgentResumedEvent_concurrentUsage()
        section("102-113. Tool Lifecycle Events (E2E — Story 26.4)")
        await testToolStartedEvent_fullLifecycle()
        await testToolStreamingEvent_codableRoundTrip()
        await testToolCompletedEvent_concurrentUsage()
        await testToolFailedEvent_concurrentUsage()
        await testToolEvents_existentialDispatch()
        await testToolEvents_jsonFormatSseCompatible()
        await testToolStartedEvent_concurrentUsage()
        await testToolStreamingEvent_concurrentUsage()
        await testToolCompletedEvent_codableRoundTrip()
        await testToolFailedEvent_codableRoundTrip()
        await testToolFullLifecycle_sequence()
        await testCrossCategoryExistentialDispatch()
        section("114-126. LLM Cost Events (E2E — Story 26.5)")
        await testLLMRequestStartedEvent_fullLifecycle()
        await testLLMResponseReceivedEvent_codableRoundTrip()
        await testLLMCostEvent_fullLifecycle()
        await testLLMCostEvent_nilCacheTokens()
        await testLLMRequestStartedEvent_concurrentUsage()
        await testLLMResponseReceivedEvent_concurrentUsage()
        await testLLMCostEvent_concurrentUsage()
        await testLLMEvents_existentialDispatch()
        await testLLMEvents_jsonFormatSseCompatible()
        await testLLMFullLifecycle_sequence()
        await testLLMCostEvent_datePrecision()
        await testCrossCategoryExistentialDispatch_withLLM()
        await testLLMCostEvent_mixedCacheTokensAndJsonTypes()
    }

    // MARK: Test 87: SessionCreatedEvent full lifecycle

    /// AC1 [P0]: Construct, serialize, deserialize, verify all fields survive round-trip.
    static func testSessionCreatedEvent_fullLifecycle() async {
        let event = SessionCreatedEvent(
            sessionId: "e2e-sess-created-\(UUID().uuidString)",
            task: "Build a real-time event system",
            model: "claude-sonnet-4-6"
        )

        // Verify construction
        guard !event.id.isEmpty else {
            fail("SessionCreatedEvent lifecycle", "id is empty")
            return
        }
        guard event.sessionId != nil else {
            fail("SessionCreatedEvent lifecycle", "sessionId should not be nil")
            return
        }

        // Encode → JSON → Decode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(SessionCreatedEvent.self, from: data)

            guard decoded.id == event.id else {
                fail("SessionCreatedEvent lifecycle", "id mismatch: \(decoded.id) != \(event.id)")
                return
            }
            guard decoded.sessionId == event.sessionId else {
                fail("SessionCreatedEvent lifecycle", "sessionId mismatch")
                return
            }
            guard decoded.task == event.task else {
                fail("SessionCreatedEvent lifecycle", "task mismatch")
                return
            }
            guard decoded.model == event.model else {
                fail("SessionCreatedEvent lifecycle", "model mismatch")
                return
            }
            pass("87. SessionCreatedEvent full lifecycle (construct → encode → decode → verify)")
        } catch {
            fail("SessionCreatedEvent lifecycle", "Codable error: \(error)")
        }
    }

    // MARK: Test 88: SessionRestoredEvent Codable round-trip with real Date

    /// AC2 [P0]: Verify Date precision survives serialization (originalCreatedAt).
    static func testSessionRestoredEvent_codableRoundTrip() async {
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let event = SessionRestoredEvent(
            sessionId: "e2e-sess-restored-\(UUID().uuidString)",
            messageCount: 42,
            originalCreatedAt: originalDate
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(SessionRestoredEvent.self, from: data)

            guard decoded.messageCount == 42 else {
                fail("SessionRestoredEvent Codable", "messageCount mismatch: \(decoded.messageCount)")
                return
            }
            // ISO 8601 round-trip should preserve the timestamp within 1 second
            let delta = abs(decoded.originalCreatedAt.timeIntervalSince(originalDate))
            guard delta < 1.0 else {
                fail("SessionRestoredEvent Codable", "Date drift: \(delta)s")
                return
            }
            pass("88. SessionRestoredEvent Codable round-trip with Date precision")
        } catch {
            fail("SessionRestoredEvent Codable", "error: \(error)")
        }
    }

    // MARK: Test 89: SessionClosedEvent all final statuses

    /// AC3 [P0]: Create events for each SessionFinalStatus, serialize, verify status survives.
    static func testSessionClosedEvent_allStatuses() async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for status in SessionFinalStatus.allCases {
            let event = SessionClosedEvent(sessionId: "e2e-close-\(status.rawValue)", finalStatus: status)
            do {
                let data = try encoder.encode(event)
                let decoded = try decoder.decode(SessionClosedEvent.self, from: data)
                guard decoded.finalStatus == status else {
                    fail("SessionClosedEvent status \(status.rawValue)", "status mismatch: \(decoded.finalStatus)")
                    return
                }
            } catch {
                fail("SessionClosedEvent status \(status.rawValue)", "error: \(error)")
                return
            }
        }
        pass("89. SessionClosedEvent all 3 final statuses round-trip correctly")
    }

    // MARK: Test 90: SessionAutoSavedEvent concurrent usage

    /// AC4, AC5 [P0]: Events cross actor boundaries safely (Sendable in practice).
    static func testSessionAutoSavedEvent_concurrentUsage() async {
        let event = SessionAutoSavedEvent(sessionId: "e2e-autosave-\(UUID().uuidString)", messageCount: 99)
        let retrieved = await Self.testActor.sendAutoSaved(event)
        guard retrieved.messageCount == 99, retrieved.sessionId == event.sessionId else {
            fail("SessionAutoSavedEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("90. SessionAutoSavedEvent concurrent usage across actor boundary")
    }

    // MARK: Test 91: All session events as existential AgentEvent

    /// AC5 [P0]: All 4 event types work as `any AgentEvent` — the pattern EventBus will use.
    static func testSessionEvents_existentialDispatch() async {
        let events: [any AgentEvent] = [
            SessionCreatedEvent(sessionId: "e2e-ex-1", task: "dispatch test", model: "test-model"),
            SessionRestoredEvent(sessionId: "e2e-ex-2", messageCount: 10, originalCreatedAt: Date()),
            SessionClosedEvent(sessionId: "e2e-ex-3", finalStatus: .completed),
            SessionAutoSavedEvent(sessionId: "e2e-ex-4", messageCount: 5),
        ]

        for event in events {
            guard !event.id.isEmpty else {
                fail("Existential dispatch", "event has empty id: \(type(of: event))")
                return
            }
        }

        // Encode as existential (type-erased) — verify each can be stored and accessed
        func dispatch(_ event: any AgentEvent) -> String { event.id }
        let ids = events.map { dispatch($0) }
        guard ids.count == 4, ids.allSatisfy({ !$0.isEmpty }) else {
            fail("Existential dispatch", "id extraction failed")
            return
        }
        pass("91. All 4 session events work as existential AgentEvent")
    }

    // MARK: Test 92: JSON format SSE-compatible (flat structure, snake_case)

    /// AC1-AC4 [P0]: Verify JSON output matches expected SSE format (flat, snake_case keys).
    static func testSessionEvents_jsonFormatSseCompatible() async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // SessionCreatedEvent
        do {
            let event = SessionCreatedEvent(sessionId: "s1", task: "sse test", model: "m")
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["id"] != nil else { fail("SSE format SessionCreated", "missing 'id'"); return }
            guard json["timestamp"] != nil else { fail("SSE format SessionCreated", "missing 'timestamp'"); return }
            guard json["session_id"] != nil else { fail("SSE format SessionCreated", "missing 'session_id'"); return }
            guard json["task"] != nil else { fail("SSE format SessionCreated", "missing 'task'"); return }
            guard json["model"] != nil else { fail("SSE format SessionCreated", "missing 'model'"); return }
            // Should NOT have nested "base" key
            guard json["base"] == nil else { fail("SSE format SessionCreated", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format SessionCreated", "error: \(error)")
            return
        }

        // SessionClosedEvent
        do {
            let event = SessionClosedEvent(sessionId: "s2", finalStatus: .failed)
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["final_status"] != nil else { fail("SSE format SessionClosed", "missing 'final_status'"); return }
            guard json["base"] == nil else { fail("SSE format SessionClosed", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format SessionClosed", "error: \(error)")
            return
        }

        // SessionRestoredEvent
        do {
            let event = SessionRestoredEvent(sessionId: "s3", messageCount: 7, originalCreatedAt: Date())
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["message_count"] != nil else { fail("SSE format SessionRestored", "missing 'message_count'"); return }
            guard json["original_created_at"] != nil else { fail("SSE format SessionRestored", "missing 'original_created_at'"); return }
            guard json["base"] == nil else { fail("SSE format SessionRestored", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format SessionRestored", "error: \(error)")
            return
        }

        // SessionAutoSavedEvent
        do {
            let event = SessionAutoSavedEvent(sessionId: "s4", messageCount: 3)
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["message_count"] != nil else { fail("SSE format SessionAutoSaved", "missing 'message_count'"); return }
            guard json["base"] == nil else { fail("SSE format SessionAutoSaved", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format SessionAutoSaved", "error: \(error)")
            return
        }

        pass("92. JSON format SSE-compatible (flat, snake_case, no nested base)")
    }

    // MARK: - Tests 93-101: Agent Lifecycle Events (Story 26.3)

    // MARK: Test 93: AgentStartedEvent full lifecycle

    static func testAgentStartedEvent_fullLifecycle() async {
        let event = AgentStartedEvent(
            sessionId: "e2e-agent-start-\(UUID().uuidString)",
            task: "Analyze codebase and generate report"
        )

        guard !event.id.isEmpty else {
            fail("AgentStartedEvent lifecycle", "id is empty")
            return
        }
        guard event.sessionId != nil else {
            fail("AgentStartedEvent lifecycle", "sessionId should not be nil")
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(AgentStartedEvent.self, from: data)

            guard decoded.id == event.id else {
                fail("AgentStartedEvent lifecycle", "id mismatch")
                return
            }
            guard decoded.sessionId == event.sessionId else {
                fail("AgentStartedEvent lifecycle", "sessionId mismatch")
                return
            }
            guard decoded.task == event.task else {
                fail("AgentStartedEvent lifecycle", "task mismatch")
                return
            }
            pass("93. AgentStartedEvent full lifecycle (construct → encode → decode → verify)")
        } catch {
            fail("AgentStartedEvent lifecycle", "Codable error: \(error)")
        }
    }

    // MARK: Test 94: AgentCompletedEvent Codable round-trip with Date precision

    static func testAgentCompletedEvent_codableRoundTrip() async {
        let event = AgentCompletedEvent(
            sessionId: "e2e-agent-comp-\(UUID().uuidString)",
            totalSteps: 12,
            durationMs: 5432,
            resultText: "Analysis complete"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(AgentCompletedEvent.self, from: data)

            guard decoded.totalSteps == 12 else {
                fail("AgentCompletedEvent Codable", "totalSteps mismatch: \(decoded.totalSteps)")
                return
            }
            guard decoded.durationMs == 5432 else {
                fail("AgentCompletedEvent Codable", "durationMs mismatch: \(decoded.durationMs)")
                return
            }
            guard decoded.resultText == "Analysis complete" else {
                fail("AgentCompletedEvent Codable", "resultText mismatch")
                return
            }
            let delta = abs(decoded.timestamp.timeIntervalSince(event.timestamp))
            guard delta < 1.0 else {
                fail("AgentCompletedEvent Codable", "Date drift: \(delta)s")
                return
            }
            pass("94. AgentCompletedEvent Codable round-trip with Date precision")
        } catch {
            fail("AgentCompletedEvent Codable", "error: \(error)")
        }
    }

    // MARK: Test 95: AgentFailedEvent concurrent usage

    static func testAgentFailedEvent_concurrentUsage() async {
        let event = AgentFailedEvent(
            sessionId: "e2e-agent-fail-\(UUID().uuidString)",
            error: "API rate limit exceeded",
            stepsCompleted: 3
        )
        let retrieved = await Self.testActor.sendFailed(event)
        guard retrieved.error == "API rate limit exceeded", retrieved.stepsCompleted == 3 else {
            fail("AgentFailedEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("95. AgentFailedEvent concurrent usage across actor boundary")
    }

    // MARK: Test 96: AgentInterruptedEvent concurrent usage

    static func testAgentInterruptedEvent_concurrentUsage() async {
        let event = AgentInterruptedEvent(
            sessionId: "e2e-agent-int-\(UUID().uuidString)",
            stepsCompleted: 7
        )
        let retrieved = await Self.testActor.sendInterrupted(event)
        guard retrieved.stepsCompleted == 7, retrieved.sessionId == event.sessionId else {
            fail("AgentInterruptedEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("96. AgentInterruptedEvent concurrent usage across actor boundary")
    }

    // MARK: Test 97: All agent events as existential AgentEvent

    static func testAgentEvents_existentialDispatch() async {
        let events: [any AgentEvent] = [
            AgentStartedEvent(sessionId: "e2e-ex-a1", task: "start"),
            AgentCompletedEvent(sessionId: "e2e-ex-a2", totalSteps: 5, durationMs: 1000, resultText: "done"),
            AgentFailedEvent(sessionId: "e2e-ex-a3", error: "fail", stepsCompleted: 2),
            AgentInterruptedEvent(sessionId: "e2e-ex-a4", stepsCompleted: 3),
            AgentResumedEvent(sessionId: "e2e-ex-a5", resumeContext: "resume"),
        ]

        for event in events {
            guard !event.id.isEmpty else {
                fail("Agent existential dispatch", "event has empty id: \(type(of: event))")
                return
            }
        }

        func dispatch(_ event: any AgentEvent) -> String { event.id }
        let ids = events.map { dispatch($0) }
        guard ids.count == 5, ids.allSatisfy({ !$0.isEmpty }) else {
            fail("Agent existential dispatch", "id extraction failed")
            return
        }
        pass("97. All 5 agent events work as existential AgentEvent")
    }

    // MARK: Test 98: Agent events JSON format SSE-compatible

    static func testAgentEvents_jsonFormatSseCompatible() async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // AgentStartedEvent
        do {
            let event = AgentStartedEvent(sessionId: "s1", task: "sse test")
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["id"] != nil else { fail("SSE format AgentStarted", "missing 'id'"); return }
            guard json["timestamp"] != nil else { fail("SSE format AgentStarted", "missing 'timestamp'"); return }
            guard json["session_id"] != nil else { fail("SSE format AgentStarted", "missing 'session_id'"); return }
            guard json["task"] != nil else { fail("SSE format AgentStarted", "missing 'task'"); return }
            guard json["base"] == nil else { fail("SSE format AgentStarted", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format AgentStarted", "error: \(error)")
            return
        }

        // AgentCompletedEvent
        do {
            let event = AgentCompletedEvent(sessionId: "s2", totalSteps: 3, durationMs: 500, resultText: "ok")
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["total_steps"] != nil else { fail("SSE format AgentCompleted", "missing 'total_steps'"); return }
            guard json["duration_ms"] != nil else { fail("SSE format AgentCompleted", "missing 'duration_ms'"); return }
            guard json["result_text"] != nil else { fail("SSE format AgentCompleted", "missing 'result_text'"); return }
            guard json["base"] == nil else { fail("SSE format AgentCompleted", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format AgentCompleted", "error: \(error)")
            return
        }

        // AgentFailedEvent
        do {
            let event = AgentFailedEvent(sessionId: "s3", error: "err", stepsCompleted: 1)
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["error"] != nil else { fail("SSE format AgentFailed", "missing 'error'"); return }
            guard json["steps_completed"] != nil else { fail("SSE format AgentFailed", "missing 'steps_completed'"); return }
            guard json["base"] == nil else { fail("SSE format AgentFailed", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format AgentFailed", "error: \(error)")
            return
        }

        // AgentInterruptedEvent
        do {
            let event = AgentInterruptedEvent(sessionId: "s4", stepsCompleted: 2)
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["steps_completed"] != nil else { fail("SSE format AgentInterrupted", "missing 'steps_completed'"); return }
            guard json["base"] == nil else { fail("SSE format AgentInterrupted", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format AgentInterrupted", "error: \(error)")
            return
        }

        // AgentResumedEvent
        do {
            let event = AgentResumedEvent(sessionId: "s5", resumeContext: "ctx")
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["resume_context"] != nil else { fail("SSE format AgentResumed", "missing 'resume_context'"); return }
            guard json["base"] == nil else { fail("SSE format AgentResumed", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format AgentResumed", "error: \(error)")
            return
        }

        pass("98. Agent events JSON format SSE-compatible (flat, snake_case, no nested base)")
    }

    // MARK: Test 99: AgentStartedEvent concurrent usage

    static func testAgentStartedEvent_concurrentUsage() async {
        let event = AgentStartedEvent(
            sessionId: "e2e-agent-conc-start-\(UUID().uuidString)",
            task: "Concurrent boundary test"
        )
        let retrieved = await Self.testActor.sendStarted(event)
        guard retrieved.task == "Concurrent boundary test", retrieved.sessionId == event.sessionId else {
            fail("AgentStartedEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("99. AgentStartedEvent concurrent usage across actor boundary")
    }

    // MARK: Test 100: AgentCompletedEvent concurrent usage

    static func testAgentCompletedEvent_concurrentUsage() async {
        let event = AgentCompletedEvent(
            sessionId: "e2e-agent-conc-comp-\(UUID().uuidString)",
            totalSteps: 8,
            durationMs: 3200,
            resultText: "All done"
        )
        let retrieved = await Self.testActor.sendCompleted(event)
        guard retrieved.totalSteps == 8, retrieved.durationMs == 3200, retrieved.resultText == "All done" else {
            fail("AgentCompletedEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("100. AgentCompletedEvent concurrent usage across actor boundary")
    }

    // MARK: Test 101: AgentResumedEvent concurrent usage

    static func testAgentResumedEvent_concurrentUsage() async {
        let event = AgentResumedEvent(
            sessionId: "e2e-agent-conc-res-\(UUID().uuidString)",
            resumeContext: "Resuming from checkpoint"
        )
        let retrieved = await Self.testActor.sendResumed(event)
        guard retrieved.resumeContext == "Resuming from checkpoint", retrieved.sessionId == event.sessionId else {
            fail("AgentResumedEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("101. AgentResumedEvent concurrent usage across actor boundary")
    }

    // MARK: - Tests 102-109: Tool Lifecycle Events (Story 26.4)

    // MARK: Test 102: ToolStartedEvent full lifecycle

    static func testToolStartedEvent_fullLifecycle() async {
        let event = ToolStartedEvent(
            sessionId: "e2e-tool-start-\(UUID().uuidString)",
            toolName: "BashTool",
            toolUseId: "toolu_\(UUID().uuidString)",
            input: "{\"command\":\"ls -la\"}"
        )

        guard !event.id.isEmpty else {
            fail("ToolStartedEvent lifecycle", "id is empty")
            return
        }
        guard event.sessionId != nil else {
            fail("ToolStartedEvent lifecycle", "sessionId should not be nil")
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(ToolStartedEvent.self, from: data)

            guard decoded.id == event.id else {
                fail("ToolStartedEvent lifecycle", "id mismatch")
                return
            }
            guard decoded.toolName == "BashTool" else {
                fail("ToolStartedEvent lifecycle", "toolName mismatch")
                return
            }
            guard decoded.input == event.input else {
                fail("ToolStartedEvent lifecycle", "input mismatch")
                return
            }
            pass("102. ToolStartedEvent full lifecycle (construct → encode → decode → verify)")
        } catch {
            fail("ToolStartedEvent lifecycle", "Codable error: \(error)")
        }
    }

    // MARK: Test 103: ToolStreamingEvent Codable round-trip

    static func testToolStreamingEvent_codableRoundTrip() async {
        let event = ToolStreamingEvent(
            sessionId: "e2e-tool-stream-\(UUID().uuidString)",
            toolUseId: "toolu_stream_\(UUID().uuidString)",
            chunk: "partial output data chunk"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(ToolStreamingEvent.self, from: data)

            guard decoded.chunk == "partial output data chunk" else {
                fail("ToolStreamingEvent Codable", "chunk mismatch: \(decoded.chunk)")
                return
            }
            let delta = abs(decoded.timestamp.timeIntervalSince(event.timestamp))
            guard delta < 1.0 else {
                fail("ToolStreamingEvent Codable", "Date drift: \(delta)s")
                return
            }
            pass("103. ToolStreamingEvent Codable round-trip with Date precision")
        } catch {
            fail("ToolStreamingEvent Codable", "error: \(error)")
        }
    }

    // MARK: Test 104: ToolCompletedEvent concurrent usage

    static func testToolCompletedEvent_concurrentUsage() async {
        let event = ToolCompletedEvent(
            sessionId: "e2e-tool-comp-\(UUID().uuidString)",
            toolUseId: "toolu_comp_\(UUID().uuidString)",
            toolName: "FileReadTool",
            durationMs: 1250,
            isError: false
        )
        let retrieved = await Self.testActor.sendToolCompleted(event)
        guard retrieved.durationMs == 1250, retrieved.isError == false, retrieved.toolName == "FileReadTool" else {
            fail("ToolCompletedEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("104. ToolCompletedEvent concurrent usage across actor boundary")
    }

    // MARK: Test 105: ToolFailedEvent concurrent usage

    static func testToolFailedEvent_concurrentUsage() async {
        let event = ToolFailedEvent(
            sessionId: "e2e-tool-fail-\(UUID().uuidString)",
            toolUseId: "toolu_fail_\(UUID().uuidString)",
            toolName: "BashTool",
            error: "Permission denied"
        )
        let retrieved = await Self.testActor.sendToolFailed(event)
        guard retrieved.error == "Permission denied", retrieved.toolName == "BashTool" else {
            fail("ToolFailedEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("105. ToolFailedEvent concurrent usage across actor boundary")
    }

    // MARK: Test 106: All tool events as existential AgentEvent

    static func testToolEvents_existentialDispatch() async {
        let events: [any AgentEvent] = [
            ToolStartedEvent(sessionId: "e2e-ex-t1", toolName: "BashTool", toolUseId: "tu-1", input: nil),
            ToolStreamingEvent(sessionId: "e2e-ex-t2", toolUseId: "tu-2", chunk: "data"),
            ToolCompletedEvent(sessionId: "e2e-ex-t3", toolUseId: "tu-3", toolName: "FileTool", durationMs: 100, isError: false),
            ToolFailedEvent(sessionId: "e2e-ex-t4", toolUseId: "tu-4", toolName: "BashTool", error: "fail"),
        ]

        for event in events {
            guard !event.id.isEmpty else {
                fail("Tool existential dispatch", "event has empty id: \(type(of: event))")
                return
            }
        }

        func dispatch(_ event: any AgentEvent) -> String { event.id }
        let ids = events.map { dispatch($0) }
        guard ids.count == 4, ids.allSatisfy({ !$0.isEmpty }) else {
            fail("Tool existential dispatch", "id extraction failed")
            return
        }
        pass("106. All 4 tool events work as existential AgentEvent")
    }

    // MARK: Test 107: Tool events JSON format SSE-compatible

    static func testToolEvents_jsonFormatSseCompatible() async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // ToolStartedEvent
        do {
            let event = ToolStartedEvent(sessionId: "s1", toolName: "BashTool", toolUseId: "tu-1", input: "inp")
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["id"] != nil else { fail("SSE format ToolStarted", "missing 'id'"); return }
            guard json["timestamp"] != nil else { fail("SSE format ToolStarted", "missing 'timestamp'"); return }
            guard json["session_id"] != nil else { fail("SSE format ToolStarted", "missing 'session_id'"); return }
            guard json["tool_name"] != nil else { fail("SSE format ToolStarted", "missing 'tool_name'"); return }
            guard json["tool_use_id"] != nil else { fail("SSE format ToolStarted", "missing 'tool_use_id'"); return }
            guard json["input"] != nil else { fail("SSE format ToolStarted", "missing 'input'"); return }
            guard json["base"] == nil else { fail("SSE format ToolStarted", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format ToolStarted", "error: \(error)")
            return
        }

        // ToolStreamingEvent
        do {
            let event = ToolStreamingEvent(sessionId: "s2", toolUseId: "tu-2", chunk: "chunk")
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["tool_use_id"] != nil else { fail("SSE format ToolStreaming", "missing 'tool_use_id'"); return }
            guard json["chunk"] != nil else { fail("SSE format ToolStreaming", "missing 'chunk'"); return }
            guard json["base"] == nil else { fail("SSE format ToolStreaming", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format ToolStreaming", "error: \(error)")
            return
        }

        // ToolCompletedEvent
        do {
            let event = ToolCompletedEvent(sessionId: "s3", toolUseId: "tu-3", toolName: "BashTool", durationMs: 500, isError: true)
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["tool_name"] != nil else { fail("SSE format ToolCompleted", "missing 'tool_name'"); return }
            guard json["duration_ms"] != nil else { fail("SSE format ToolCompleted", "missing 'duration_ms'"); return }
            guard json["is_error"] != nil else { fail("SSE format ToolCompleted", "missing 'is_error'"); return }
            guard json["base"] == nil else { fail("SSE format ToolCompleted", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format ToolCompleted", "error: \(error)")
            return
        }

        // ToolFailedEvent
        do {
            let event = ToolFailedEvent(sessionId: "s4", toolUseId: "tu-4", toolName: "FileTool", error: "not found")
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["tool_name"] != nil else { fail("SSE format ToolFailed", "missing 'tool_name'"); return }
            guard json["error"] != nil else { fail("SSE format ToolFailed", "missing 'error'"); return }
            guard json["base"] == nil else { fail("SSE format ToolFailed", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format ToolFailed", "error: \(error)")
            return
        }

        pass("107. Tool events JSON format SSE-compatible (flat, snake_case, no nested base)")
    }

    // MARK: Test 108: ToolStartedEvent concurrent usage

    static func testToolStartedEvent_concurrentUsage() async {
        let event = ToolStartedEvent(
            sessionId: "e2e-tool-conc-start-\(UUID().uuidString)",
            toolName: "GrepTool",
            toolUseId: "toolu_start_\(UUID().uuidString)",
            input: "{\"pattern\":\"TODO\"}"
        )
        let retrieved = await Self.testActor.sendToolStarted(event)
        guard retrieved.toolName == "GrepTool", retrieved.input == "{\"pattern\":\"TODO\"}" else {
            fail("ToolStartedEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("108. ToolStartedEvent concurrent usage across actor boundary")
    }

    // MARK: Test 109: ToolStreamingEvent concurrent usage

    static func testToolStreamingEvent_concurrentUsage() async {
        let event = ToolStreamingEvent(
            sessionId: "e2e-tool-conc-stream-\(UUID().uuidString)",
            toolUseId: "toolu_stream_\(UUID().uuidString)",
            chunk: "streaming output"
        )
        let retrieved = await Self.testActor.sendToolStreaming(event)
        guard retrieved.chunk == "streaming output", retrieved.sessionId == event.sessionId else {
            fail("ToolStreamingEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("109. ToolStreamingEvent concurrent usage across actor boundary")
    }

    // MARK: Test 110: ToolCompletedEvent Codable round-trip with Date precision

    static func testToolCompletedEvent_codableRoundTrip() async {
        let event = ToolCompletedEvent(
            sessionId: "e2e-tool-comp-rt-\(UUID().uuidString)",
            toolUseId: "toolu_rt_\(UUID().uuidString)",
            toolName: "GrepTool",
            durationMs: 4200,
            isError: false
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(ToolCompletedEvent.self, from: data)

            guard decoded.toolUseId == event.toolUseId else {
                fail("ToolCompletedEvent Codable", "toolUseId mismatch")
                return
            }
            guard decoded.toolName == "GrepTool" else {
                fail("ToolCompletedEvent Codable", "toolName mismatch: \(decoded.toolName)")
                return
            }
            guard decoded.durationMs == 4200 else {
                fail("ToolCompletedEvent Codable", "durationMs mismatch: \(decoded.durationMs)")
                return
            }
            guard decoded.isError == false else {
                fail("ToolCompletedEvent Codable", "isError mismatch: \(decoded.isError)")
                return
            }
            guard decoded.sessionId == event.sessionId else {
                fail("ToolCompletedEvent Codable", "sessionId mismatch")
                return
            }
            let delta = abs(decoded.timestamp.timeIntervalSince(event.timestamp))
            guard delta < 1.0 else {
                fail("ToolCompletedEvent Codable", "Date drift: \(delta)s")
                return
            }
            pass("110. ToolCompletedEvent Codable round-trip with Date precision")
        } catch {
            fail("ToolCompletedEvent Codable", "error: \(error)")
        }
    }

    // MARK: Test 111: ToolFailedEvent Codable round-trip with Date precision

    static func testToolFailedEvent_codableRoundTrip() async {
        let event = ToolFailedEvent(
            sessionId: "e2e-tool-fail-rt-\(UUID().uuidString)",
            toolUseId: "toolu_failrt_\(UUID().uuidString)",
            toolName: "BashTool",
            error: "Command timed out after 30s"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(ToolFailedEvent.self, from: data)

            guard decoded.toolUseId == event.toolUseId else {
                fail("ToolFailedEvent Codable", "toolUseId mismatch")
                return
            }
            guard decoded.toolName == "BashTool" else {
                fail("ToolFailedEvent Codable", "toolName mismatch: \(decoded.toolName)")
                return
            }
            guard decoded.error == "Command timed out after 30s" else {
                fail("ToolFailedEvent Codable", "error mismatch: \(decoded.error)")
                return
            }
            guard decoded.sessionId == event.sessionId else {
                fail("ToolFailedEvent Codable", "sessionId mismatch")
                return
            }
            let delta = abs(decoded.timestamp.timeIntervalSince(event.timestamp))
            guard delta < 1.0 else {
                fail("ToolFailedEvent Codable", "Date drift: \(delta)s")
                return
            }
            pass("111. ToolFailedEvent Codable round-trip with Date precision")
        } catch {
            fail("ToolFailedEvent Codable", "error: \(error)")
        }
    }

    // MARK: Test 112: Full tool lifecycle sequence (Started → Streaming → Completed)

    static func testToolFullLifecycle_sequence() async {
        let toolUseId = "toolu_lifecycle_\(UUID().uuidString)"
        let sessionId = "e2e-lifecycle-\(UUID().uuidString)"

        let started = ToolStartedEvent(
            sessionId: sessionId,
            toolName: "FileReadTool",
            toolUseId: toolUseId,
            input: "{\"path\":\"/tmp/test.txt\"}"
        )
        let stream1 = ToolStreamingEvent(
            sessionId: sessionId,
            toolUseId: toolUseId,
            chunk: "line 1 of file\n"
        )
        let stream2 = ToolStreamingEvent(
            sessionId: sessionId,
            toolUseId: toolUseId,
            chunk: "line 2 of file\n"
        )
        let completed = ToolCompletedEvent(
            sessionId: sessionId,
            toolUseId: toolUseId,
            toolName: "FileReadTool",
            durationMs: 85,
            isError: false
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            // Verify all events share the same toolUseId
            let events: [any AgentEvent] = [started, stream1, stream2, completed]
            for event in events {
                guard !event.id.isEmpty else {
                    fail("Lifecycle sequence", "event has empty id")
                    return
                }
            }

            // Round-trip each event
            let decodedStarted = try decoder.decode(ToolStartedEvent.self, from: encoder.encode(started))
            let decodedStream1 = try decoder.decode(ToolStreamingEvent.self, from: encoder.encode(stream1))
            let decodedStream2 = try decoder.decode(ToolStreamingEvent.self, from: encoder.encode(stream2))
            let decodedCompleted = try decoder.decode(ToolCompletedEvent.self, from: encoder.encode(completed))

            // Verify toolUseId consistency across the lifecycle
            guard decodedStarted.toolUseId == toolUseId else {
                fail("Lifecycle sequence", "started toolUseId mismatch")
                return
            }
            guard decodedStream1.toolUseId == toolUseId, decodedStream2.toolUseId == toolUseId else {
                fail("Lifecycle sequence", "streaming toolUseId mismatch")
                return
            }
            guard decodedCompleted.toolUseId == toolUseId else {
                fail("Lifecycle sequence", "completed toolUseId mismatch")
                return
            }

            // Verify all share the same sessionId
            guard decodedStarted.sessionId == sessionId,
                  decodedCompleted.toolName == "FileReadTool",
                  decodedCompleted.durationMs == 85,
                  decodedCompleted.isError == false else {
                fail("Lifecycle sequence", "completed event field mismatch")
                return
            }

            // Verify streaming chunks are distinct
            guard decodedStream1.chunk != decodedStream2.chunk else {
                fail("Lifecycle sequence", "streaming chunks should be distinct")
                return
            }
            guard decodedStream1.chunk == "line 1 of file\n", decodedStream2.chunk == "line 2 of file\n" else {
                fail("Lifecycle sequence", "chunk content mismatch")
                return
            }

            pass("112. Full tool lifecycle sequence (Started → Streaming → Completed) with shared toolUseId")
        } catch {
            fail("Lifecycle sequence", "Codable error: \(error)")
        }
    }

    // MARK: Test 113: Cross-category existential dispatch (all 13 event types)

    static func testCrossCategoryExistentialDispatch() async {
        let events: [any AgentEvent] = [
            // Session events (4)
            SessionCreatedEvent(sessionId: "cross-1", task: "cross test", model: "m"),
            SessionRestoredEvent(sessionId: "cross-2", messageCount: 1, originalCreatedAt: Date()),
            SessionClosedEvent(sessionId: "cross-3", finalStatus: .completed),
            SessionAutoSavedEvent(sessionId: "cross-4", messageCount: 2),
            // Agent events (5)
            AgentStartedEvent(sessionId: "cross-5", task: "start"),
            AgentCompletedEvent(sessionId: "cross-6", totalSteps: 1, durationMs: 100, resultText: "done"),
            AgentFailedEvent(sessionId: "cross-7", error: "fail", stepsCompleted: 0),
            AgentInterruptedEvent(sessionId: "cross-8", stepsCompleted: 1),
            AgentResumedEvent(sessionId: "cross-9", resumeContext: "resume"),
            // Tool events (4)
            ToolStartedEvent(sessionId: "cross-10", toolName: "BashTool", toolUseId: "tu-1", input: nil),
            ToolStreamingEvent(sessionId: "cross-11", toolUseId: "tu-2", chunk: "data"),
            ToolCompletedEvent(sessionId: "cross-12", toolUseId: "tu-3", toolName: "FileTool", durationMs: 50, isError: false),
            ToolFailedEvent(sessionId: "cross-13", toolUseId: "tu-4", toolName: "GrepTool", error: "err"),
        ]

        guard events.count == 13 else {
            fail("Cross-category dispatch", "expected 13 events, got \(events.count)")
            return
        }

        for event in events {
            guard !event.id.isEmpty else {
                fail("Cross-category dispatch", "event has empty id: \(type(of: event))")
                return
            }
        }

        // Dispatch through a type-erased function (simulates EventBus pattern)
        func dispatch(_ event: any AgentEvent) -> String { event.id }
        let ids = events.map { dispatch($0) }
        guard ids.count == 13, ids.allSatisfy({ !$0.isEmpty }) else {
            fail("Cross-category dispatch", "id extraction failed")
            return
        }

        // Verify all IDs are unique
        let uniqueIds = Set(ids)
        guard uniqueIds.count == 13 else {
            fail("Cross-category dispatch", "IDs should all be unique, got \(uniqueIds.count) unique out of \(ids.count)")
            return
        }

        pass("113. Cross-category existential dispatch (all 13 event types: session + agent + tool)")
    }

    // MARK: - Tests 114-125: LLM Cost Events (Story 26.5)

    // MARK: Test 114: LLMRequestStartedEvent full lifecycle with Date precision

    static func testLLMRequestStartedEvent_fullLifecycle() async {
        let event = LLMRequestStartedEvent(
            sessionId: "e2e-llm-start-\(UUID().uuidString)",
            model: "claude-sonnet-4-6"
        )

        guard !event.id.isEmpty else {
            fail("LLMRequestStartedEvent lifecycle", "id is empty")
            return
        }
        guard event.sessionId != nil else {
            fail("LLMRequestStartedEvent lifecycle", "sessionId should not be nil")
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(LLMRequestStartedEvent.self, from: data)

            guard decoded.id == event.id else {
                fail("LLMRequestStartedEvent lifecycle", "id mismatch")
                return
            }
            guard decoded.sessionId == event.sessionId else {
                fail("LLMRequestStartedEvent lifecycle", "sessionId mismatch")
                return
            }
            guard decoded.model == "claude-sonnet-4-6" else {
                fail("LLMRequestStartedEvent lifecycle", "model mismatch")
                return
            }
            let delta = abs(decoded.timestamp.timeIntervalSince(event.timestamp))
            guard delta < 1.0 else {
                fail("LLMRequestStartedEvent lifecycle", "Date drift: \(delta)s")
                return
            }
            pass("114. LLMRequestStartedEvent full lifecycle with Date precision (construct → encode → decode → verify)")
        } catch {
            fail("LLMRequestStartedEvent lifecycle", "Codable error: \(error)")
        }
    }

    // MARK: Test 115: LLMResponseReceivedEvent Codable round-trip with Date precision

    static func testLLMResponseReceivedEvent_codableRoundTrip() async {
        let event = LLMResponseReceivedEvent(
            sessionId: "e2e-llm-resp-\(UUID().uuidString)",
            model: "glm-5.1",
            durationMs: 4200
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(LLMResponseReceivedEvent.self, from: data)

            guard decoded.model == "glm-5.1" else {
                fail("LLMResponseReceivedEvent Codable", "model mismatch: \(decoded.model)")
                return
            }
            guard decoded.durationMs == 4200 else {
                fail("LLMResponseReceivedEvent Codable", "durationMs mismatch: \(decoded.durationMs)")
                return
            }
            let delta = abs(decoded.timestamp.timeIntervalSince(event.timestamp))
            guard delta < 1.0 else {
                fail("LLMResponseReceivedEvent Codable", "Date drift: \(delta)s")
                return
            }
            pass("115. LLMResponseReceivedEvent Codable round-trip with Date precision")
        } catch {
            fail("LLMResponseReceivedEvent Codable", "error: \(error)")
        }
    }

    // MARK: Test 116: LLMCostEvent full lifecycle with all fields

    static func testLLMCostEvent_fullLifecycle() async {
        let event = LLMCostEvent(
            sessionId: "e2e-llm-cost-\(UUID().uuidString)",
            model: "claude-opus-4-7",
            inputTokens: 5000,
            outputTokens: 2000,
            cacheCreationInputTokens: 1000,
            cacheReadInputTokens: 500,
            estimatedCostUsd: 0.15
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(LLMCostEvent.self, from: data)

            guard decoded.inputTokens == 5000 else {
                fail("LLMCostEvent lifecycle", "inputTokens mismatch: \(decoded.inputTokens)")
                return
            }
            guard decoded.outputTokens == 2000 else {
                fail("LLMCostEvent lifecycle", "outputTokens mismatch: \(decoded.outputTokens)")
                return
            }
            guard decoded.cacheCreationInputTokens == 1000 else {
                fail("LLMCostEvent lifecycle", "cacheCreationInputTokens mismatch")
                return
            }
            guard decoded.cacheReadInputTokens == 500 else {
                fail("LLMCostEvent lifecycle", "cacheReadInputTokens mismatch")
                return
            }
            guard abs(decoded.estimatedCostUsd - 0.15) < 0.0001 else {
                fail("LLMCostEvent lifecycle", "estimatedCostUsd mismatch: \(decoded.estimatedCostUsd)")
                return
            }
            pass("116. LLMCostEvent full lifecycle (all fields including cache tokens)")
        } catch {
            fail("LLMCostEvent lifecycle", "Codable error: \(error)")
        }
    }

    // MARK: Test 117: LLMCostEvent with nil cache tokens

    static func testLLMCostEvent_nilCacheTokens() async {
        let event = LLMCostEvent(
            sessionId: "e2e-llm-cost-nil-\(UUID().uuidString)",
            model: "glm-5.1",
            inputTokens: 500,
            outputTokens: 200,
            cacheCreationInputTokens: nil,
            cacheReadInputTokens: nil,
            estimatedCostUsd: 0.01
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(LLMCostEvent.self, from: data)

            guard decoded.cacheCreationInputTokens == nil else {
                fail("LLMCostEvent nil cache", "cacheCreationInputTokens should be nil")
                return
            }
            guard decoded.cacheReadInputTokens == nil else {
                fail("LLMCostEvent nil cache", "cacheReadInputTokens should be nil")
                return
            }
            guard decoded.inputTokens == 500, decoded.outputTokens == 200 else {
                fail("LLMCostEvent nil cache", "token counts mismatch")
                return
            }
            pass("117. LLMCostEvent with nil cache tokens round-trips correctly")
        } catch {
            fail("LLMCostEvent nil cache", "error: \(error)")
        }
    }

    // MARK: Test 118: LLMRequestStartedEvent concurrent usage

    static func testLLMRequestStartedEvent_concurrentUsage() async {
        let event = LLMRequestStartedEvent(
            sessionId: "e2e-llm-conc-start-\(UUID().uuidString)",
            model: "claude-sonnet-4-6"
        )
        let retrieved = await Self.testActor.sendLLMRequestStarted(event)
        guard retrieved.model == "claude-sonnet-4-6", retrieved.sessionId == event.sessionId else {
            fail("LLMRequestStartedEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("118. LLMRequestStartedEvent concurrent usage across actor boundary")
    }

    // MARK: Test 119: LLMResponseReceivedEvent concurrent usage

    static func testLLMResponseReceivedEvent_concurrentUsage() async {
        let event = LLMResponseReceivedEvent(
            sessionId: "e2e-llm-conc-resp-\(UUID().uuidString)",
            model: "glm-5.1",
            durationMs: 3200
        )
        let retrieved = await Self.testActor.sendLLMResponseReceived(event)
        guard retrieved.durationMs == 3200, retrieved.model == "glm-5.1" else {
            fail("LLMResponseReceivedEvent concurrent", "data corrupted after actor crossing")
            return
        }
        pass("119. LLMResponseReceivedEvent concurrent usage across actor boundary")
    }

    // MARK: Test 120: LLMCostEvent concurrent usage

    static func testLLMCostEvent_concurrentUsage() async {
        let event = LLMCostEvent(
            sessionId: "e2e-llm-conc-cost-\(UUID().uuidString)",
            model: "claude-opus-4-7",
            inputTokens: 8000,
            outputTokens: 3000,
            cacheCreationInputTokens: 2000,
            cacheReadInputTokens: 1000,
            estimatedCostUsd: 0.25
        )
        let retrieved = await Self.testActor.sendLLMCost(event)
        guard retrieved.inputTokens == 8000, retrieved.outputTokens == 3000 else {
            fail("LLMCostEvent concurrent", "token counts corrupted after actor crossing")
            return
        }
        guard retrieved.cacheCreationInputTokens == 2000, retrieved.cacheReadInputTokens == 1000 else {
            fail("LLMCostEvent concurrent", "cache tokens corrupted after actor crossing")
            return
        }
        pass("120. LLMCostEvent concurrent usage across actor boundary")
    }

    // MARK: Test 121: All LLM events as existential AgentEvent

    static func testLLMEvents_existentialDispatch() async {
        let events: [any AgentEvent] = [
            LLMRequestStartedEvent(sessionId: "e2e-ex-llm1", model: "claude-sonnet-4-6"),
            LLMResponseReceivedEvent(sessionId: "e2e-ex-llm2", model: "glm-5.1", durationMs: 1000),
            LLMCostEvent(sessionId: "e2e-ex-llm3", model: "claude-opus-4-7", inputTokens: 2000, outputTokens: 1000, cacheCreationInputTokens: 500, cacheReadInputTokens: 200, estimatedCostUsd: 0.08),
        ]

        for event in events {
            guard !event.id.isEmpty else {
                fail("LLM existential dispatch", "event has empty id: \(type(of: event))")
                return
            }
        }

        func dispatch(_ event: any AgentEvent) -> String { event.id }
        let ids = events.map { dispatch($0) }
        guard ids.count == 3, ids.allSatisfy({ !$0.isEmpty }) else {
            fail("LLM existential dispatch", "id extraction failed")
            return
        }
        pass("121. All 3 LLM events work as existential AgentEvent")
    }

    // MARK: Test 122: LLM events JSON format SSE-compatible

    static func testLLMEvents_jsonFormatSseCompatible() async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // LLMRequestStartedEvent
        do {
            let event = LLMRequestStartedEvent(sessionId: "s1", model: "claude-sonnet-4-6")
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["id"] != nil else { fail("SSE format LLMRequestStarted", "missing 'id'"); return }
            guard json["timestamp"] != nil else { fail("SSE format LLMRequestStarted", "missing 'timestamp'"); return }
            guard json["session_id"] != nil else { fail("SSE format LLMRequestStarted", "missing 'session_id'"); return }
            guard json["model"] != nil else { fail("SSE format LLMRequestStarted", "missing 'model'"); return }
            guard json["base"] == nil else { fail("SSE format LLMRequestStarted", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format LLMRequestStarted", "error: \(error)")
            return
        }

        // LLMResponseReceivedEvent
        do {
            let event = LLMResponseReceivedEvent(sessionId: "s2", model: "glm-5.1", durationMs: 500)
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["duration_ms"] != nil else { fail("SSE format LLMResponseReceived", "missing 'duration_ms'"); return }
            guard json["base"] == nil else { fail("SSE format LLMResponseReceived", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format LLMResponseReceived", "error: \(error)")
            return
        }

        // LLMCostEvent
        do {
            let event = LLMCostEvent(sessionId: "s3", model: "claude-opus-4-7", inputTokens: 1000, outputTokens: 500, cacheCreationInputTokens: 100, cacheReadInputTokens: 50, estimatedCostUsd: 0.05)
            let data = try encoder.encode(event)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            guard json["input_tokens"] != nil else { fail("SSE format LLMCost", "missing 'input_tokens'"); return }
            guard json["output_tokens"] != nil else { fail("SSE format LLMCost", "missing 'output_tokens'"); return }
            guard json["cache_creation_input_tokens"] != nil else { fail("SSE format LLMCost", "missing 'cache_creation_input_tokens'"); return }
            guard json["cache_read_input_tokens"] != nil else { fail("SSE format LLMCost", "missing 'cache_read_input_tokens'"); return }
            guard json["estimated_cost_usd"] != nil else { fail("SSE format LLMCost", "missing 'estimated_cost_usd'"); return }
            guard json["base"] == nil else { fail("SSE format LLMCost", "should not have nested 'base'"); return }
        } catch {
            fail("SSE format LLMCost", "error: \(error)")
            return
        }

        pass("122. LLM events JSON format SSE-compatible (flat, snake_case, no nested base)")
    }

    // MARK: Test 123: Full LLM lifecycle sequence (RequestStarted → ResponseReceived → Cost)

    static func testLLMFullLifecycle_sequence() async {
        let sessionId = "e2e-llm-lifecycle-\(UUID().uuidString)"

        let started = LLMRequestStartedEvent(
            sessionId: sessionId,
            model: "claude-sonnet-4-6"
        )
        let response = LLMResponseReceivedEvent(
            sessionId: sessionId,
            model: "claude-sonnet-4-6",
            durationMs: 3500
        )
        let cost = LLMCostEvent(
            sessionId: sessionId,
            model: "claude-sonnet-4-6",
            inputTokens: 5000,
            outputTokens: 2000,
            cacheCreationInputTokens: 1000,
            cacheReadInputTokens: 500,
            estimatedCostUsd: 0.15
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decodedStarted = try decoder.decode(LLMRequestStartedEvent.self, from: encoder.encode(started))
            let decodedResponse = try decoder.decode(LLMResponseReceivedEvent.self, from: encoder.encode(response))
            let decodedCost = try decoder.decode(LLMCostEvent.self, from: encoder.encode(cost))

            // All share same sessionId
            guard decodedStarted.sessionId == sessionId,
                  decodedResponse.sessionId == sessionId,
                  decodedCost.sessionId == sessionId else {
                fail("LLM lifecycle sequence", "sessionId mismatch across events")
                return
            }

            // All share same model
            guard decodedStarted.model == "claude-sonnet-4-6",
                  decodedResponse.model == "claude-sonnet-4-6",
                  decodedCost.model == "claude-sonnet-4-6" else {
                fail("LLM lifecycle sequence", "model mismatch across events")
                return
            }

            // Verify response fields
            guard decodedResponse.durationMs == 3500 else {
                fail("LLM lifecycle sequence", "durationMs mismatch")
                return
            }

            // Verify cost fields
            guard decodedCost.inputTokens == 5000,
                  decodedCost.outputTokens == 2000,
                  decodedCost.cacheCreationInputTokens == 1000,
                  decodedCost.cacheReadInputTokens == 500 else {
                fail("LLM lifecycle sequence", "cost token fields mismatch")
                return
            }

            pass("123. Full LLM lifecycle sequence (RequestStarted → ResponseReceived → Cost)")
        } catch {
            fail("LLM lifecycle sequence", "Codable error: \(error)")
        }
    }

    // MARK: Test 124: LLMCostEvent Codable Date precision

    static func testLLMCostEvent_datePrecision() async {
        let event = LLMCostEvent(
            sessionId: "e2e-llm-date-\(UUID().uuidString)",
            model: "glm-5.1",
            inputTokens: 100,
            outputTokens: 50,
            cacheCreationInputTokens: nil,
            cacheReadInputTokens: nil,
            estimatedCostUsd: 0.001
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(LLMCostEvent.self, from: data)

            let delta = abs(decoded.timestamp.timeIntervalSince(event.timestamp))
            guard delta < 1.0 else {
                fail("LLMCostEvent Date precision", "Date drift: \(delta)s")
                return
            }
            pass("124. LLMCostEvent Codable Date precision preserved")
        } catch {
            fail("LLMCostEvent Date precision", "error: \(error)")
        }
    }

    // MARK: Test 125: Cross-category existential dispatch including LLM events (16 types)

    static func testCrossCategoryExistentialDispatch_withLLM() async {
        let events: [any AgentEvent] = [
            // Session events (4)
            SessionCreatedEvent(sessionId: "cross-1", task: "cross test", model: "m"),
            SessionRestoredEvent(sessionId: "cross-2", messageCount: 1, originalCreatedAt: Date()),
            SessionClosedEvent(sessionId: "cross-3", finalStatus: .completed),
            SessionAutoSavedEvent(sessionId: "cross-4", messageCount: 2),
            // Agent events (5)
            AgentStartedEvent(sessionId: "cross-5", task: "start"),
            AgentCompletedEvent(sessionId: "cross-6", totalSteps: 1, durationMs: 100, resultText: "done"),
            AgentFailedEvent(sessionId: "cross-7", error: "fail", stepsCompleted: 0),
            AgentInterruptedEvent(sessionId: "cross-8", stepsCompleted: 1),
            AgentResumedEvent(sessionId: "cross-9", resumeContext: "resume"),
            // Tool events (4)
            ToolStartedEvent(sessionId: "cross-10", toolName: "BashTool", toolUseId: "tu-1", input: nil),
            ToolStreamingEvent(sessionId: "cross-11", toolUseId: "tu-2", chunk: "data"),
            ToolCompletedEvent(sessionId: "cross-12", toolUseId: "tu-3", toolName: "FileTool", durationMs: 50, isError: false),
            ToolFailedEvent(sessionId: "cross-13", toolUseId: "tu-4", toolName: "GrepTool", error: "err"),
            // LLM events (3)
            LLMRequestStartedEvent(sessionId: "cross-14", model: "claude-sonnet-4-6"),
            LLMResponseReceivedEvent(sessionId: "cross-15", model: "glm-5.1", durationMs: 500),
            LLMCostEvent(sessionId: "cross-16", model: "claude-opus-4-7", inputTokens: 1000, outputTokens: 500, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, estimatedCostUsd: 0.05),
        ]

        guard events.count == 16 else {
            fail("Cross-category with LLM", "expected 16 events, got \(events.count)")
            return
        }

        for event in events {
            guard !event.id.isEmpty else {
                fail("Cross-category with LLM", "event has empty id: \(type(of: event))")
                return
            }
        }

        func dispatch(_ event: any AgentEvent) -> String { event.id }
        let ids = events.map { dispatch($0) }
        guard ids.count == 16, ids.allSatisfy({ !$0.isEmpty }) else {
            fail("Cross-category with LLM", "id extraction failed")
            return
        }

        let uniqueIds = Set(ids)
        guard uniqueIds.count == 16 else {
            fail("Cross-category with LLM", "IDs should all be unique, got \(uniqueIds.count) unique out of \(ids.count)")
            return
        }

        pass("125. Cross-category existential dispatch (all 16 event types: session + agent + tool + LLM)")
    }

    // MARK: Test 126: LLMCostEvent mixed nil/non-nil cache tokens + JSON value types

    static func testLLMCostEvent_mixedCacheTokensAndJsonTypes() async {
        // Test 1: One cache token nil, other present
        let event = LLMCostEvent(
            sessionId: "e2e-llm-mixed-\(UUID().uuidString)",
            model: "claude-sonnet-4-6",
            inputTokens: 2000,
            outputTokens: 800,
            cacheCreationInputTokens: 500,
            cacheReadInputTokens: nil,
            estimatedCostUsd: 0.045
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(LLMCostEvent.self, from: data)

            guard decoded.cacheCreationInputTokens == 500 else {
                fail("LLMCostEvent mixed cache", "cacheCreationInputTokens should be 500, got \(String(describing: decoded.cacheCreationInputTokens))")
                return
            }
            guard decoded.cacheReadInputTokens == nil else {
                fail("LLMCostEvent mixed cache", "cacheReadInputTokens should be nil")
                return
            }
            guard decoded.inputTokens == 2000 else {
                fail("LLMCostEvent mixed cache", "inputTokens mismatch")
                return
            }
            guard abs(decoded.estimatedCostUsd - 0.045) < 0.0001 else {
                fail("LLMCostEvent mixed cache", "estimatedCostUsd mismatch: \(decoded.estimatedCostUsd)")
                return
            }

            // Test 2: Verify JSON value types (Int fields are numbers, Double is number)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            guard json["input_tokens"] is Int else {
                fail("LLMCostEvent JSON types", "input_tokens should be Int")
                return
            }
            guard json["output_tokens"] is Int else {
                fail("LLMCostEvent JSON types", "output_tokens should be Int")
                return
            }
            guard json["cache_creation_input_tokens"] is Int else {
                fail("LLMCostEvent JSON types", "cache_creation_input_tokens should be Int")
                return
            }
            guard json["estimated_cost_usd"] is Double else {
                fail("LLMCostEvent JSON types", "estimated_cost_usd should be Double")
                return
            }
            // nil field should be absent from JSON
            guard json["cache_read_input_tokens"] == nil else {
                fail("LLMCostEvent JSON types", "cache_read_input_tokens should be absent when nil")
                return
            }

            pass("126. LLMCostEvent mixed nil/non-nil cache tokens + JSON value types verified")
        } catch {
            fail("LLMCostEvent mixed cache", "error: \(error)")
        }
    }
}

// MARK: - E2E Test Helpers

private extension AgentEventTypesE2ETests {
    actor TestActor {
        func sendAutoSaved(_ event: SessionAutoSavedEvent) -> SessionAutoSavedEvent { event }
        func sendStarted(_ event: AgentStartedEvent) -> AgentStartedEvent { event }
        func sendCompleted(_ event: AgentCompletedEvent) -> AgentCompletedEvent { event }
        func sendFailed(_ event: AgentFailedEvent) -> AgentFailedEvent { event }
        func sendInterrupted(_ event: AgentInterruptedEvent) -> AgentInterruptedEvent { event }
        func sendResumed(_ event: AgentResumedEvent) -> AgentResumedEvent { event }
        func sendToolStarted(_ event: ToolStartedEvent) -> ToolStartedEvent { event }
        func sendToolStreaming(_ event: ToolStreamingEvent) -> ToolStreamingEvent { event }
        func sendToolCompleted(_ event: ToolCompletedEvent) -> ToolCompletedEvent { event }
        func sendToolFailed(_ event: ToolFailedEvent) -> ToolFailedEvent { event }
        func sendLLMRequestStarted(_ event: LLMRequestStartedEvent) -> LLMRequestStartedEvent { event }
        func sendLLMResponseReceived(_ event: LLMResponseReceivedEvent) -> LLMResponseReceivedEvent { event }
        func sendLLMCost(_ event: LLMCostEvent) -> LLMCostEvent { event }
    }
    static let testActor = TestActor()
}

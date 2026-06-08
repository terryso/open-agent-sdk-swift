import Foundation
import OpenAgentSDK

// MARK: - Session Search E2E Tests (Story 23.2: SessionSearchPlugin)

struct SessionSearchE2ETests {
    static func run() async {
        section("76. SessionSearchEngine: Multi-Session Discover E2E")
        await testDiscoverE2E()

        section("77. SessionSearchEngine: Scroll Context Window E2E")
        await testScrollE2E()

        section("78. SessionSearchEngine: Browse Session Listing E2E")
        await testBrowseE2E()

        section("79. SessionSearchPlugin + PluginRegistry Lifecycle E2E")
        await testPluginRegistryLifecycleE2E()

        section("80. SessionSearchPlugin: Tool Schema & Config E2E")
        await testPluginToolSchemaAndConfigE2E()
    }

    // MARK: - Helpers

    private static func msgs(_ pairs: (String, String)...) -> [[String: Any]] {
        pairs.map { ["type": $0.0, "message": $0.1] }
    }

    // MARK: - Test 76: Multi-Session Discover E2E

    private static func testDiscoverE2E() async {
        let tempDir = makeTempDir(prefix: "e2e-session-search")
        defer { cleanup(tempDir) }

        do {
            let store = SessionStore(sessionsDir: tempDir)
            let engine = SessionSearchEngine()

            // Seed 3 sessions with overlapping content
            try await store.save(sessionId: "alpha", messages: msgs(
                ("user", "How do I implement a binary search tree?"),
                ("assistant", "A binary search tree is a data structure..."),
                ("user", "What about balanced BST variants?")
            ), metadata: PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "BST Discussion"))

            try await store.save(sessionId: "beta", messages: msgs(
                ("user", "Debugging search functionality in production"),
                ("assistant", "Let me help you debug the search feature."),
                ("user", "The search returns no results"),
                ("assistant", "Check your index configuration.")
            ), metadata: PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "Search Debug"))

            try await store.save(sessionId: "gamma", messages: msgs(
                ("user", "Explain linear search algorithm"),
                ("assistant", "Linear search iterates through elements one by one."),
                ("user", "When should I prefer binary search over linear search?")
            ), metadata: PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "Algorithms"))

            // Discover "search" — should match all 3 sessions
            let query = SessionSearchQuery(mode: .discover, query: "search", limit: 10)
            let results = try await engine.search(query, store: store)

            if results.count == 3 {
                pass("Discover E2E: found matches in all 3 sessions")
            } else {
                fail("Discover E2E: found matches in all 3 sessions", "count=\(results.count)")
            }

            for result in results {
                if result.mode == .discover && result.matchedSessionId != nil {
                    pass("Discover E2E: result has mode=discover and sessionId for \(result.matchedSessionId ?? "")")
                } else {
                    fail("Discover E2E: result has mode=discover and sessionId", "mode=\(result.mode)")
                }
            }

            // Each result should have a context window with surrounding messages
            let allHaveContext = results.allSatisfy { $0.messages.count >= 1 }
            if allHaveContext {
                pass("Discover E2E: all results have context messages")
            } else {
                fail("Discover E2E: all results have context messages")
            }

            // Verify case-insensitive search
            let upperQuery = SessionSearchQuery(mode: .discover, query: "SEARCH", limit: 10)
            let upperResults = try await engine.search(upperQuery, store: store)
            if upperResults.count == 3 {
                pass("Discover E2E: case-insensitive search works")
            } else {
                fail("Discover E2E: case-insensitive search works", "count=\(upperResults.count)")
            }

            // Verify limit enforcement
            let limitedQuery = SessionSearchQuery(mode: .discover, query: "search", limit: 2)
            let limitedResults = try await engine.search(limitedQuery, store: store)
            if limitedResults.count == 2 {
                pass("Discover E2E: limit=2 returns exactly 2 results")
            } else {
                fail("Discover E2E: limit=2 returns exactly 2 results", "count=\(limitedResults.count)")
            }

            // Verify no-match returns empty
            let noMatchQuery = SessionSearchQuery(mode: .discover, query: "nonexistent_xyzzy", limit: 10)
            let noMatchResults = try await engine.search(noMatchQuery, store: store)
            if noMatchResults.isEmpty {
                pass("Discover E2E: no-match query returns empty")
            } else {
                fail("Discover E2E: no-match query returns empty", "count=\(noMatchResults.count)")
            }

            // Verify totalMatches counts correctly
            let binaryQuery = SessionSearchQuery(mode: .discover, query: "binary", limit: 10)
            let binaryResults = try await engine.search(binaryQuery, store: store)
            if let firstResult = binaryResults.first {
                if firstResult.matchedSessionId == "alpha" && firstResult.totalMatches == 2 {
                    pass("Discover E2E: totalMatches counts multiple matches in one session")
                } else {
                    fail("Discover E2E: totalMatches counts multiple matches",
                         "session=\(firstResult.matchedSessionId ?? "") matches=\(firstResult.totalMatches ?? 0)")
                }
            }
        } catch {
            fail("Discover E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 77: Scroll Context Window E2E

    private static func testScrollE2E() async {
        let tempDir = makeTempDir(prefix: "e2e-session-search")
        defer { cleanup(tempDir) }

        do {
            let store = SessionStore(sessionsDir: tempDir)
            let engine = SessionSearchEngine()

            // Create a session with 25 messages
            var messages: [[String: Any]] = []
            for i in 0..<25 {
                messages.append(["type": "user", "message": "Message \(i)"])
            }
            try await store.save(sessionId: "scroll-test", messages: messages,
                metadata: PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "Scroll"))

            // Scroll around message 12 (center of 25)
            let query = SessionSearchQuery(mode: .scroll, sessionId: "scroll-test", aroundMessageIndex: 12, limit: 10)
            let results = try await engine.search(query, store: store)

            if results.count == 1 {
                pass("Scroll E2E: returns single result")
            } else {
                fail("Scroll E2E: returns single result", "count=\(results.count)")
            }

            if let result = results.first {
                // ±10 window around index 12 = messages 2..22 = 21 messages
                if result.messages.count == 21 {
                    pass("Scroll E2E: context window has 21 messages (±10 around index 12)")
                } else {
                    fail("Scroll E2E: context window has 21 messages", "count=\(result.messages.count)")
                }

                if result.matchedMessageIndex == 12 {
                    pass("Scroll E2E: matchedMessageIndex is 12")
                } else {
                    fail("Scroll E2E: matchedMessageIndex is 12", "index=\(result.matchedMessageIndex ?? -1)")
                }

                if result.totalMatches == nil {
                    pass("Scroll E2E: totalMatches is nil")
                } else {
                    fail("Scroll E2E: totalMatches is nil", "got \(result.totalMatches ?? 0)")
                }
            }

            // Scroll near start (index 1)
            let startQuery = SessionSearchQuery(mode: .scroll, sessionId: "scroll-test", aroundMessageIndex: 1, limit: 10)
            let startResults = try await engine.search(startQuery, store: store)
            if let result = startResults.first {
                if result.messages.count == 12 {
                    pass("Scroll E2E: near-start scroll clamped correctly (0..11 = 12 messages)")
                } else {
                    fail("Scroll E2E: near-start scroll clamped", "count=\(result.messages.count)")
                }
            }

            // Scroll near end (index 24)
            let endQuery = SessionSearchQuery(mode: .scroll, sessionId: "scroll-test", aroundMessageIndex: 24, limit: 10)
            let endResults = try await engine.search(endQuery, store: store)
            if let result = endResults.first {
                if result.messages.count == 11 {
                    pass("Scroll E2E: near-end scroll clamped correctly (14..24 = 11 messages)")
                } else {
                    fail("Scroll E2E: near-end scroll clamped", "count=\(result.messages.count)")
                }
            }

            // Scroll nonexistent session
            let noQuery = SessionSearchQuery(mode: .scroll, sessionId: "nonexistent", aroundMessageIndex: 0, limit: 10)
            let noResults = try await engine.search(noQuery, store: store)
            if noResults.isEmpty {
                pass("Scroll E2E: nonexistent session returns empty")
            } else {
                fail("Scroll E2E: nonexistent session returns empty", "count=\(noResults.count)")
            }
        } catch {
            fail("Scroll E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 78: Browse Session Listing E2E

    private static func testBrowseE2E() async {
        let tempDir = makeTempDir(prefix: "e2e-session-search")
        defer { cleanup(tempDir) }

        do {
            let store = SessionStore(sessionsDir: tempDir)
            let engine = SessionSearchEngine()

            // Seed 5 sessions
            for i in 0..<5 {
                try await store.save(sessionId: "session-\(i)", messages: msgs(
                    ("user", "Content \(i)")
                ), metadata: PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "Session \(i)"))
            }

            // Browse all
            let allQuery = SessionSearchQuery(mode: .browse, limit: 10)
            let allResults = try await engine.search(allQuery, store: store)

            if allResults.count == 5 {
                pass("Browse E2E: returns all 5 sessions")
            } else {
                fail("Browse E2E: returns all 5 sessions", "count=\(allResults.count)")
            }

            // All browse results should have empty messages
            let allEmpty = allResults.allSatisfy { $0.messages.isEmpty }
            if allEmpty {
                pass("Browse E2E: all results have empty messages")
            } else {
                fail("Browse E2E: all results have empty messages")
            }

            // All should have matchedSessionId
            let allHaveId = allResults.allSatisfy { $0.matchedSessionId != nil }
            if allHaveId {
                pass("Browse E2E: all results have matchedSessionId")
            } else {
                fail("Browse E2E: all results have matchedSessionId")
            }

            // Browse with limit
            let limQuery = SessionSearchQuery(mode: .browse, limit: 3)
            let limResults = try await engine.search(limQuery, store: store)
            if limResults.count == 3 {
                pass("Browse E2E: limit=3 returns 3 sessions")
            } else {
                fail("Browse E2E: limit=3 returns 3 sessions", "count=\(limResults.count)")
            }

            // Browse empty directory
            let emptyDir = makeTempDir(prefix: "e2e-session-search")
            defer { cleanup(emptyDir) }
            let emptyStore = SessionStore(sessionsDir: emptyDir)
            let emptyQuery = SessionSearchQuery(mode: .browse, limit: 10)
            let emptyResults = try await engine.search(emptyQuery, store: emptyStore)
            if emptyResults.isEmpty {
                pass("Browse E2E: empty directory returns empty results")
            } else {
                fail("Browse E2E: empty directory returns empty results", "count=\(emptyResults.count)")
            }
        } catch {
            fail("Browse E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 79: Plugin + PluginRegistry Lifecycle E2E

    private static func testPluginRegistryLifecycleE2E() async {
        do {
            let registry = PluginRegistry()

            // Register plugin
            let plugin = SessionSearchPlugin()
            try await registry.register(plugin)

            if await registry.pluginNames == ["session-search"] {
                pass("Registry E2E: plugin registered")
            } else {
                fail("Registry E2E: plugin registered", "names=\(await registry.pluginNames)")
            }

            // Initialize all plugins
            try await registry.initializeAll(sessionId: "e2e-test-session")

            // Dispatch initialize phase
            let initContext = PluginContext(
                sessionId: "e2e-test-session",
                messages: [],
                model: "test",
                provider: .anthropic
            )
            let initResults = await registry.dispatch(.initialize, context: initContext)
            if initResults.count == 1 && initResults[0] == .none {
                pass("Registry E2E: initialize dispatch returns .none")
            } else {
                fail("Registry E2E: initialize dispatch returns .none", "count=\(initResults.count)")
            }

            // Dispatch prefetch with no query
            let noQueryContext = PluginContext(
                sessionId: "e2e-test-session",
                messages: [],
                currentQuery: nil,
                model: "test",
                provider: .anthropic
            )
            let noQueryResults = await registry.dispatch(.prefetch, context: noQueryContext)
            if noQueryResults.count == 1 {
                if case .toolSchemas(let schemaList) = noQueryResults[0] {
                    if schemaList.schemas.count == 1 {
                        pass("Registry E2E: prefetch with no query returns tool schemas")
                    } else {
                        fail("Registry E2E: tool schemas count", "count=\(schemaList.schemas.count)")
                    }
                } else {
                    fail("Registry E2E: prefetch returns toolSchemas", "got \(noQueryResults[0])")
                }
            } else {
                fail("Registry E2E: prefetch returns 1 result", "count=\(noQueryResults.count)")
            }

            // Dispatch unsupported phase (syncTurn)
            let syncContext = PluginContext(
                sessionId: "e2e-test-session",
                messages: [],
                model: "test",
                provider: .anthropic
            )
            let syncResults = await registry.dispatch(.syncTurn, context: syncContext)
            if syncResults.isEmpty {
                pass("Registry E2E: unsupported phase returns no results")
            } else {
                fail("Registry E2E: unsupported phase returns no results", "count=\(syncResults.count)")
            }

            // Shutdown all
            await registry.shutdownAll()

            // After shutdown, prefetch should return .none
            let afterShutdownContext = PluginContext(
                sessionId: "e2e-test-session",
                messages: [],
                currentQuery: nil,
                model: "test",
                provider: .anthropic
            )
            let afterResults = await registry.dispatch(.prefetch, context: afterShutdownContext)
            if afterResults.count == 1 && afterResults[0] == .none {
                pass("Registry E2E: after shutdown, prefetch returns .none")
            } else {
                fail("Registry E2E: after shutdown, prefetch returns .none", "result=\(afterResults)")
            }

            // Test duplicate registration rejection
            let registry2 = PluginRegistry()
            let plugin2a = SessionSearchPlugin()
            let plugin2b = SessionSearchPlugin()
            try await registry2.register(plugin2a)
            do {
                try await registry2.register(plugin2b)
                fail("Registry E2E: duplicate registration throws", "no error thrown")
            } catch {
                pass("Registry E2E: duplicate registration throws error")
            }
        } catch {
            fail("Registry E2E: unexpected error", error.localizedDescription)
        }
    }

    // MARK: - Test 80: Tool Schema & Config E2E

    private static func testPluginToolSchemaAndConfigE2E() async {
        do {
            // Test tool schema structure
            let plugin = SessionSearchPlugin()
            try await plugin.initialize(sessionId: "schema-test")

            let context = PluginContext(
                sessionId: "schema-test",
                messages: [],
                currentQuery: nil,
                model: "test",
                provider: .anthropic
            )
            let result = try await plugin.onPhase(.prefetch, context: context)

            if case .toolSchemas(let schemaList) = result {
                let schema = schemaList.schemas[0]

                if schema["title"] as? String == "session_search" {
                    pass("Schema E2E: title is session_search")
                } else {
                    fail("Schema E2E: title is session_search", "got \(schema["title"] ?? "")")
                }

                if let properties = schema["properties"] as? [String: Any] {
                    let hasQuery = properties["query"] != nil
                    let hasSessionId = properties["session_id"] != nil
                    let hasMode = properties["mode"] != nil

                    if hasQuery && hasSessionId && hasMode {
                        pass("Schema E2E: has query, session_id, and mode properties")
                    } else {
                        fail("Schema E2E: has all properties", "query=\(hasQuery) session_id=\(hasSessionId) mode=\(hasMode)")
                    }

                    // Verify mode has enum constraint
                    if let modeProp = properties["mode"] as? [String: Any],
                       let enumValues = modeProp["enum"] as? [String],
                       enumValues == ["discover", "scroll", "browse"] {
                        pass("Schema E2E: mode has correct enum values")
                    } else {
                        fail("Schema E2E: mode has correct enum values")
                    }
                } else {
                    fail("Schema E2E: has properties dict")
                }

                if let required = schema["required"] as? [String], required == ["mode"] {
                    pass("Schema E2E: required fields are correct")
                } else {
                    fail("Schema E2E: required fields are correct", "got \(schema["required"] ?? "")")
                }
            } else {
                fail("Schema E2E: result is toolSchemas")
            }

            await plugin.shutdown()

            // Test config: autoSearch disabled
            let disabledConfig = EvolutionPluginConfig(name: "session-search", config: ["autoSearch": "false"])
            let disabledPlugin = SessionSearchPlugin(config: disabledConfig)
            try await disabledPlugin.initialize(sessionId: "config-test")

            let queryContext = PluginContext(
                sessionId: "config-test",
                messages: [],
                currentQuery: "test query",
                model: "test",
                provider: .anthropic
            )
            let disabledResult = try await disabledPlugin.onPhase(.prefetch, context: queryContext)
            if case .toolSchemas = disabledResult {
                pass("Config E2E: autoSearch=false always returns toolSchemas")
            } else {
                fail("Config E2E: autoSearch=false always returns toolSchemas", "got \(disabledResult)")
            }

            await disabledPlugin.shutdown()

            // Test config: maxResults
            let maxResultsConfig = EvolutionPluginConfig(name: "session-search", config: ["maxResults": "3"])
            let maxResultsPlugin = SessionSearchPlugin(config: maxResultsConfig)
            try await maxResultsPlugin.initialize(sessionId: "config-test-2")

            // Plugin initializes correctly with custom config
            // name is nonisolated — no await needed
            let name = maxResultsPlugin.name
            if name == "session-search" {
                pass("Config E2E: plugin with maxResults config initializes correctly")
            } else {
                fail("Config E2E: plugin with maxResults config initializes", "name=\(name)")
            }

            await maxResultsPlugin.shutdown()
        } catch {
            fail("Schema/Config E2E: unexpected error", error.localizedDescription)
        }
    }
}

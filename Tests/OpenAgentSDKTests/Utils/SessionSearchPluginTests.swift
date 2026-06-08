import XCTest
@testable import OpenAgentSDK

final class SessionSearchPluginTests: TempDirTestCase {

    // MARK: - Plugin Identity

    func testPluginName() async {
        let plugin = SessionSearchPlugin()
        let name = await plugin.name
        XCTAssertEqual(name, "session-search")
    }

    func testSupportedPhases() async {
        let plugin = SessionSearchPlugin()
        let phases = await plugin.supportedPhases
        XCTAssertEqual(phases, [.initialize, .prefetch])
    }

    // MARK: - Lifecycle

    func testInitializeSetsStore() async throws {
        let plugin = SessionSearchPlugin()
        try await plugin.initialize(sessionId: "test-session")
        // After init, onPhase should work (store is set)
        let context = PluginContext(
            sessionId: "test-session",
            messages: [],
            currentQuery: nil,
            model: "test",
            provider: .anthropic
        )
        let result = try await plugin.onPhase(.prefetch, context: context)
        // Should return tool schemas (no auto-search since no query)
        if case .toolSchemas = result {
            // expected
        } else {
            XCTFail("Expected toolSchemas, got \(result)")
        }
    }

    func testShutdownClearsState() async throws {
        let plugin = SessionSearchPlugin()
        try await plugin.initialize(sessionId: "test-session")
        await plugin.shutdown()
        // After shutdown, prefetch should return .none (store is nil)
        let context = PluginContext(
            sessionId: "test-session",
            messages: [],
            currentQuery: nil,
            model: "test",
            provider: .anthropic
        )
        let result = try await plugin.onPhase(.prefetch, context: context)
        XCTAssertEqual(result, .none)
    }

    // MARK: - onPhase

    func testOnPhaseInitializeReturnsNone() async throws {
        let plugin = SessionSearchPlugin()
        let context = PluginContext(
            sessionId: "test",
            messages: [],
            model: "test",
            provider: .anthropic
        )
        let result = try await plugin.onPhase(.initialize, context: context)
        XCTAssertEqual(result, .none)
    }

    func testOnPhaseUnsupportedReturnsNone() async throws {
        let plugin = SessionSearchPlugin()
        try await plugin.initialize(sessionId: "test")
        let context = PluginContext(
            sessionId: "test",
            messages: [],
            model: "test",
            provider: .anthropic
        )
        let result = try await plugin.onPhase(.syncTurn, context: context)
        XCTAssertEqual(result, .none)
    }

    func testOnPhasePrefetchReturnsToolSchemasWhenNoQuery() async throws {
        let plugin = SessionSearchPlugin()
        try await plugin.initialize(sessionId: "test")
        let context = PluginContext(
            sessionId: "test",
            messages: [],
            currentQuery: nil,
            model: "test",
            provider: .anthropic
        )
        let result = try await plugin.onPhase(.prefetch, context: context)

        if case .toolSchemas(let schemaList) = result {
            XCTAssertEqual(schemaList.schemas.count, 1)
            let schema = schemaList.schemas[0]
            XCTAssertEqual(schema["title"] as? String, "session_search")
            XCTAssertNotNil(schema["properties"])
        } else {
            XCTFail("Expected toolSchemas, got \(result)")
        }
    }

    func testOnPhasePrefetchAutoSearchReturnsSystemPromptBlock() async throws {
        // Seed a session in a temp directory via config
        let store = SessionStore(sessionsDir: tempDir)
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "Seeded")
        try await store.save(sessionId: "seeded-session", messages: [
            ["type": "user", "message": "Hello unique search term xyz"]
        ], metadata: metadata)

        let config = EvolutionPluginConfig(name: "session-search", config: ["sessionsDir": tempDir])
        let plugin = SessionSearchPlugin(config: config)
        try await plugin.initialize(sessionId: "test")

        let context = PluginContext(
            sessionId: "test",
            messages: [],
            currentQuery: "unique search term xyz",
            model: "test",
            provider: .anthropic
        )
        let result = try await plugin.onPhase(.prefetch, context: context)

        if case .systemPromptBlock(let text) = result {
            XCTAssertTrue(text.contains("seeded-session"), "System prompt block should contain the seeded session ID")
            XCTAssertTrue(text.contains("[Session Search Results]"), "System prompt block should have header")
        } else {
            XCTFail("Expected systemPromptBlock with auto-search results, got \(result)")
        }
    }

    func testOnPhasePrefetchAutoSearchFallsBackWhenNoMatches() async throws {
        let config = EvolutionPluginConfig(name: "session-search", config: ["sessionsDir": tempDir])
        let plugin = SessionSearchPlugin(config: config)
        try await plugin.initialize(sessionId: "test")

        let context = PluginContext(
            sessionId: "test",
            messages: [],
            currentQuery: "search term that won't match anything",
            model: "test",
            provider: .anthropic
        )
        let result = try await plugin.onPhase(.prefetch, context: context)

        // No sessions exist in the temp dir, so auto-search returns empty → falls through to toolSchemas
        if case .toolSchemas = result {
            // expected
        } else {
            XCTFail("Expected toolSchemas when auto-search finds nothing, got \(result)")
        }
    }

    func testOnPhasePrefetchWithAutoSearchDisabled() async throws {
        let config = EvolutionPluginConfig(name: "session-search", config: ["autoSearch": "false"])
        let plugin = SessionSearchPlugin(config: config)
        try await plugin.initialize(sessionId: "test")

        let context = PluginContext(
            sessionId: "test",
            messages: [],
            currentQuery: "should not trigger search",
            model: "test",
            provider: .anthropic
        )
        let result = try await plugin.onPhase(.prefetch, context: context)

        // autoSearch disabled → always return tool schemas
        if case .toolSchemas = result {
            // expected
        } else {
            XCTFail("Expected toolSchemas when autoSearch is disabled, got \(result)")
        }
    }

    // MARK: - Config Parsing

    func testConfigMaxResults() async throws {
        let config = EvolutionPluginConfig(name: "session-search", config: ["maxResults": "3"])
        let plugin = SessionSearchPlugin(config: config)
        try await plugin.initialize(sessionId: "test")
        let name = await plugin.name
        XCTAssertEqual(name, "session-search")
    }

    func testConfigDefaults() async throws {
        let plugin = SessionSearchPlugin()
        try await plugin.initialize(sessionId: "test")
        // No config → uses defaults. Verify the plugin works with defaults.
        let context = PluginContext(
            sessionId: "test",
            messages: [],
            currentQuery: nil,
            model: "test",
            provider: .anthropic
        )
        let result = try await plugin.onPhase(.prefetch, context: context)
        if case .toolSchemas = result {
            // expected
        } else {
            XCTFail("Expected toolSchemas")
        }
    }

    func testConfigSessionsDir() async throws {
        let config = EvolutionPluginConfig(name: "session-search", config: ["sessionsDir": tempDir])
        let plugin = SessionSearchPlugin(config: config)
        try await plugin.initialize(sessionId: "test")

        // Seed data in the temp dir and verify auto-search finds it
        let store = SessionStore(sessionsDir: tempDir)
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "Config test")
        try await store.save(sessionId: "config-session", messages: [
            ["type": "user", "message": "config dir search term"]
        ], metadata: metadata)

        let context = PluginContext(
            sessionId: "test",
            messages: [],
            currentQuery: "config dir search term",
            model: "test",
            provider: .anthropic
        )
        let result = try await plugin.onPhase(.prefetch, context: context)

        if case .systemPromptBlock(let text) = result {
            XCTAssertTrue(text.contains("config-session"))
        } else {
            XCTFail("Expected systemPromptBlock with config sessionsDir, got \(result)")
        }
    }

    func testConfigContextWindow() async throws {
        let config = EvolutionPluginConfig(name: "session-search", config: ["contextWindow": "3"])
        let plugin = SessionSearchPlugin(config: config)
        // Just verify init doesn't crash — engine tests cover the context window behavior
        let name = await plugin.name
        XCTAssertEqual(name, "session-search")
    }

    // MARK: - SelfEvolutionPlugin Conformance

    func testConformsToSelfEvolutionPlugin() async {
        let plugin: any SelfEvolutionPlugin = SessionSearchPlugin()
        XCTAssertEqual(plugin.name, "session-search")
        XCTAssertEqual(plugin.supportedPhases, [.initialize, .prefetch])
    }
}

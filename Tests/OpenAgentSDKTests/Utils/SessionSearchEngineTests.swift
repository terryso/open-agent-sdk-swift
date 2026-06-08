import XCTest
@testable import OpenAgentSDK

private func msgs(_ pairs: (String, String)...) -> [[String: Any]] {
    pairs.map { ["type": $0.0, "message": $0.1] }
}

final class SessionSearchEngineTests: TempDirTestCase {

    private var store: SessionStore!

    override func setUp() {
        super.setUp()
        store = SessionStore(sessionsDir: tempDir)
    }

    // MARK: - Discover

    func testDiscoverFindsMatchingSession() async throws {
        let m1 = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S1")
        try await store.save(sessionId: "sess-1", messages: msgs(
            ("user", "Hello world"),
            ("assistant", "Hi there"),
            ("user", "How are you?")
        ), metadata: m1)
        let m2 = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S2")
        try await store.save(sessionId: "sess-2", messages: msgs(("user", "Goodbye")), metadata: m2)

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .discover, query: "Hello", limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].matchedSessionId, "sess-1")
        XCTAssertEqual(results[0].matchedMessageIndex, 0)
    }

    func testDiscoverContextWindow() async throws {
        var messages: [[String: Any]] = []
        for i in 0..<12 {
            messages.append(["type": "user", "message": "Message \(i)"])
        }
        messages[5] = ["type": "user", "message": "FINDME target"]

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S")
        try await store.save(sessionId: "sess-ctx", messages: messages, metadata: metadata)

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .discover, query: "FINDME", limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].messages.count, 11)
        XCTAssertEqual(results[0].matchedMessageIndex, 5)
    }

    func testDiscoverCustomContextWindow() async throws {
        var messages: [[String: Any]] = []
        for i in 0..<20 {
            messages.append(["type": "user", "message": "Message \(i)"])
        }
        messages[10] = ["type": "user", "message": "FINDME target"]

        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S")
        try await store.save(sessionId: "sess-custom-ctx", messages: messages, metadata: metadata)

        let engine = SessionSearchEngine(discoverContextWindow: 3)
        let query = SessionSearchQuery(mode: .discover, query: "FINDME", limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 1)
        // ±3 context window: indices 7..13 = 7 messages
        XCTAssertEqual(results[0].messages.count, 7)
        XCTAssertEqual(results[0].matchedMessageIndex, 10)
    }

    func testDiscoverNoMatchesReturnsEmpty() async throws {
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S")
        try await store.save(sessionId: "sess-empty", messages: msgs(("user", "Nothing to see here")), metadata: metadata)

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .discover, query: "nonexistent", limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertTrue(results.isEmpty)
    }

    func testDiscoverCaseInsensitive() async throws {
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S")
        try await store.save(sessionId: "sess-ci", messages: msgs(("user", "Hello World")), metadata: metadata)

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .discover, query: "hello world", limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 1)
    }

    func testDiscoverRespectsLimit() async throws {
        for i in 0..<5 {
            let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S\(i)")
            try await store.save(sessionId: "sess-\(i)", messages: msgs(("user", "unique keyword match \(i)")), metadata: metadata)
        }

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .discover, query: "unique keyword match", limit: 3)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 3)
    }

    func testDiscoverCountsTotalMatches() async throws {
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S")
        try await store.save(sessionId: "sess-multi", messages: msgs(
            ("user", "alpha keyword beta"),
            ("assistant", "gamma"),
            ("user", "delta keyword epsilon")
        ), metadata: metadata)

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .discover, query: "keyword", limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].totalMatches, 2)
    }

    func testDiscoverHasMoreWhenMoreResultsExist() async throws {
        for i in 0..<5 {
            let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S\(i)")
            try await store.save(sessionId: "sess-more-\(i)", messages: msgs(("user", "hasmore keyword \(i)")), metadata: metadata)
        }

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .discover, query: "hasmore keyword", limit: 2)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[1].hasMore, "Last result should have hasMore=true when results were truncated")
    }

    func testDiscoverHasMoreFalseWhenAllResultsReturned() async throws {
        for i in 0..<3 {
            let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S\(i)")
            try await store.save(sessionId: "sess-exact-\(i)", messages: msgs(("user", "exact keyword \(i)")), metadata: metadata)
        }

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .discover, query: "exact keyword", limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 3)
        XCTAssertFalse(results.last?.hasMore ?? true, "hasMore should be false when all matching sessions are returned")
    }

    // MARK: - Scroll

    func testScrollReturnsContextWindow() async throws {
        var messages: [[String: Any]] = []
        for i in 0..<30 {
            messages.append(["type": "user", "message": "Msg \(i)"])
        }
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S")
        try await store.save(sessionId: "sess-scroll", messages: messages, metadata: metadata)

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .scroll, sessionId: "sess-scroll", aroundMessageIndex: 15, limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].messages.count, 21)
        XCTAssertEqual(results[0].matchedMessageIndex, 15)
    }

    func testScrollCustomContextWindow() async throws {
        var messages: [[String: Any]] = []
        for i in 0..<30 {
            messages.append(["type": "user", "message": "Msg \(i)"])
        }
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S")
        try await store.save(sessionId: "sess-scroll-custom", messages: messages, metadata: metadata)

        let engine = SessionSearchEngine(scrollContextWindow: 5)
        let query = SessionSearchQuery(mode: .scroll, sessionId: "sess-scroll-custom", aroundMessageIndex: 15, limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 1)
        // ±5 window: indices 10..20 = 11 messages
        XCTAssertEqual(results[0].messages.count, 11)
    }

    func testScrollClampsAtBoundaries() async throws {
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S")
        try await store.save(sessionId: "sess-boundary", messages: msgs(
            ("user", "Msg 0"),
            ("user", "Msg 1"),
            ("user", "Msg 2")
        ), metadata: metadata)

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .scroll, sessionId: "sess-boundary", aroundMessageIndex: 0, limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].messages.count, 3)
    }

    func testScrollInvalidSessionReturnsEmpty() async throws {
        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .scroll, sessionId: "nonexistent", aroundMessageIndex: 0, limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertTrue(results.isEmpty)
    }

    func testScrollEmptySessionReturnsEmptyMessages() async throws {
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S")
        try await store.save(sessionId: "sess-empty-scroll", messages: [], metadata: metadata)

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .scroll, sessionId: "sess-empty-scroll", aroundMessageIndex: 0, limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].messages.isEmpty)
    }

    // MARK: - Browse

    func testBrowseReturnsSessions() async throws {
        let m1 = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "A")
        try await store.save(sessionId: "sess-a", messages: msgs(("user", "A")), metadata: m1)
        let m2 = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "B")
        try await store.save(sessionId: "sess-b", messages: msgs(("user", "B")), metadata: m2)

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .browse, limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.mode == .browse })
        XCTAssertTrue(results.allSatisfy { $0.messages.isEmpty })
        XCTAssertNotNil(results[0].matchedSessionId)
        XCTAssertNotNil(results[1].matchedSessionId)
    }

    func testBrowseRespectsLimit() async throws {
        for i in 0..<5 {
            let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S\(i)")
            try await store.save(sessionId: "sess-br-\(i)", messages: msgs(("user", "Browse \(i)")), metadata: metadata)
        }

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .browse, limit: 3)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 3)
    }

    func testBrowseHasMoreWhenMoreResultsExist() async throws {
        for i in 0..<5 {
            let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S\(i)")
            try await store.save(sessionId: "sess-brmore-\(i)", messages: msgs(("user", "Browse \(i)")), metadata: metadata)
        }

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .browse, limit: 3)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[2].hasMore, "Last result should have hasMore=true when more sessions exist")
        XCTAssertFalse(results[0].hasMore, "Non-last results should have hasMore=false")
        XCTAssertFalse(results[1].hasMore, "Non-last results should have hasMore=false")
    }

    func testBrowseHasMoreFalseWhenAllReturned() async throws {
        for i in 0..<3 {
            let metadata = PartialSessionMetadata(cwd: "/tmp", model: "test", summary: "S\(i)")
            try await store.save(sessionId: "sess-brexact-\(i)", messages: msgs(("user", "Browse \(i)")), metadata: metadata)
        }

        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .browse, limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertEqual(results.count, 3)
        XCTAssertFalse(results.last?.hasMore ?? true, "hasMore should be false when all sessions are returned")
    }

    func testBrowseEmptyDirReturnsEmpty() async throws {
        let engine = SessionSearchEngine()
        let query = SessionSearchQuery(mode: .browse, limit: 10)
        let results = try await engine.search(query, store: store)

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Validation

    func testInvalidQueryThrows() async {
        let engine = SessionSearchEngine()
        let invalidQuery = SessionSearchQuery(mode: .discover, query: nil)
        do {
            _ = try await engine.search(invalidQuery, store: store)
            XCTFail("Expected error")
        } catch {
            // expected
        }
    }
}

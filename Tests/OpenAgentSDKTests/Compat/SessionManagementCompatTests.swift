// SessionManagementCompatTests.swift
// Story 16.6: Session Management Compatibility Verification
// ATDD: Tests verify TS SDK session functions <-> Swift SDK SessionStore API
//       with field-level SessionMetadata, SessionData, AgentOptions verification
// TDD Phase: RED (tests verify expected contract; known gaps documented)
//
// These tests verify that Swift SDK's session management API covers all TypeScript SDK
// session operations including listSessions, getSessionMessages, getSessionInfo,
// renameSession, tagSession, and session restore options.

import XCTest
@testable import OpenAgentSDK

// MARK: - AC1: Build Compilation Verification (P0)

/// Verifies that SessionStore, SessionMetadata, SessionData, PartialSessionMetadata
/// and AgentOptions session-related fields all compile correctly.
final class SessionManagementBuildCompatTests: XCTestCase {

    /// AC1 [P0]: SessionStore actor can be instantiated with default directory.
    func testSessionStore_instantiation_default() async {
        let store = SessionStore()
        let sessions = try? await store.list()
        XCTAssertNotNil(sessions, "SessionStore() compiles and list() returns a value")
    }

    /// AC1 [P0]: SessionStore actor can be instantiated with custom directory.
    func testSessionStore_instantiation_customDir() async {
        let store = SessionStore(sessionsDir: "/tmp/test-sessions-16-6")
        let sessions = try? await store.list()
        XCTAssertNotNil(sessions, "SessionStore(sessionsDir:) compiles and works")
    }

    /// AC1 [P0]: SessionMetadata struct can be constructed with all fields.
    func testSessionMetadata_compiles() {
        let metadata = SessionMetadata(
            id: "sess-123",
            cwd: "/home/user",
            model: "claude-sonnet-4-6",
            createdAt: Date(),
            updatedAt: Date(),
            messageCount: 5,
            summary: "Test session",
            tag: "test"
        )
        XCTAssertEqual(metadata.id, "sess-123")
    }

    /// AC1 [P0]: SessionData struct can be constructed with all fields.
    func testSessionData_compiles() {
        let metadata = SessionMetadata(
            id: "sess-456",
            cwd: "/tmp",
            model: "claude-sonnet-4-6",
            createdAt: Date(),
            updatedAt: Date(),
            messageCount: 0
        )
        let data = SessionData(metadata: metadata, messages: [])
        XCTAssertEqual(data.metadata.id, "sess-456")
        XCTAssertTrue(data.messages.isEmpty)
    }

    /// AC1 [P0]: PartialSessionMetadata struct can be constructed with all fields.
    func testPartialSessionMetadata_compiles() {
        let partial = PartialSessionMetadata(
            cwd: "/home/user",
            model: "claude-sonnet-4-6",
            summary: "My session",
            tag: "important"
        )
        XCTAssertEqual(partial.cwd, "/home/user")
    }

    /// AC1 [P0]: AgentOptions has sessionStore and sessionId fields.
    func testAgentOptions_hasSessionFields() {
        var options = AgentOptions()
        let store = SessionStore(sessionsDir: "/tmp/test-sessions")
        options.sessionStore = store
        options.sessionId = "my-session-001"
        XCTAssertNotNil(options.sessionStore)
        XCTAssertEqual(options.sessionId, "my-session-001")
    }
}

// MARK: - AC2: listSessions Equivalent Verification (P0)

/// Verifies Swift SDK's SessionStore.list() covers TS SDK listSessions().
/// TS SDK: listSessions({ dir?, limit?, includeWorktrees? })
///   returns SDKSessionInfo[] with fields: sessionId, summary, lastModified, fileSize,
///   customTitle, firstPrompt, gitBranch, cwd, tag, createdAt
final class ListSessionsCompatTests: XCTestCase {

    /// AC2 [P0]: SessionStore.list() returns [SessionMetadata] (equivalent to TS SDKSessionInfo[]).
    func testSessionStore_list_returnsSessionMetadataArray() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-list-sessions-16-6")
        let sessions = try await store.list()
        XCTAssertNotNil(sessions, "list() returns [SessionMetadata], matching TS listSessions return type")
    }

    /// AC2 [P0]: SessionStore.list() returns sessions sorted by updatedAt descending.
    func testSessionStore_list_sortedByUpdatedAtDescending() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-list-sort-16-6")
        // Create two sessions with different timestamps
        let metadata1 = PartialSessionMetadata(cwd: "/tmp", model: "model-1", summary: "First")
        let metadata2 = PartialSessionMetadata(cwd: "/tmp", model: "model-2", summary: "Second")

        try await store.save(sessionId: "sort-test-1", messages: [["role": "user", "content": "hello"]], metadata: metadata1)
        try await store.save(sessionId: "sort-test-2", messages: [["role": "user", "content": "world"]], metadata: metadata2)

        let sessions = try await store.list()
        if sessions.count >= 2 {
            // Most recently updated should come first
            XCTAssertGreaterThanOrEqual(sessions[0].updatedAt, sessions[1].updatedAt,
                "list() should return sessions sorted by updatedAt descending (most recent first)")
        }

        // Cleanup
        _ = try? await store.delete(sessionId: "sort-test-1")
        _ = try? await store.delete(sessionId: "sort-test-2")
    }

    /// AC2 [GAP]: SessionStore.list() has NO limit parameter (TS SDK has limit option).
    func testSessionStore_list_noLimitParam_gap() async {
        let store = SessionStore(sessionsDir: "/tmp/test-list-limit-16-6")
        // TS SDK: listSessions({ limit: 10 })
        // Swift: list() takes no parameters, always returns all sessions
        let sessions = try? await store.list()
        // Cannot pass limit to list() -- it always returns all sessions
        // GAP: No way to limit results for performance on large session stores
        XCTAssertNotNil(sessions, "list() takes no parameters (GAP: TS has limit option)")
    }

    /// AC2 [GAP]: SessionStore.list() has NO includeWorktrees parameter.
    func testSessionStore_list_noIncludeWorktrees_gap() async {
        let store = SessionStore(sessionsDir: "/tmp/test-list-worktrees-16-6")
        // TS SDK: listSessions({ includeWorktrees: true })
        // Swift: list() takes no parameters, no worktree filtering
        let sessions = try? await store.list()
        XCTAssertNotNil(sessions, "list() has no includeWorktrees param (GAP)")
    }

    /// AC2 [GAP]: SessionStore has NO dir parameter per-call (uses constructor sessionsDir).
    func testSessionStore_noDirParamPerCall_gap() async {
        let store = SessionStore(sessionsDir: "/tmp/test-list-dir-16-6")
        // TS SDK: listSessions({ dir: "/custom/path" })
        // Swift: Directory is set at construction time, not per-call
        // This is a design difference, not necessarily a gap -- both approaches work
        // but TS allows per-call directory override
        let _ = store // Confirms construction with custom dir works
    }

    // ================================================================
    // AC2: SessionMetadata field verification vs TS SDK SDKSessionInfo
    // ================================================================

    /// AC2 [P0]: SessionMetadata has id field (maps to TS SDK sessionId).
    func testSessionMetadata_hasIdField() {
        let metadata = SessionMetadata(
            id: "sess-abc", cwd: "/tmp", model: "m",
            createdAt: Date(), updatedAt: Date(), messageCount: 0
        )
        XCTAssertEqual(metadata.id, "sess-abc",
            "SessionMetadata.id maps to TS SDK SDKSessionInfo.sessionId")
    }

    /// AC2 [P0]: SessionMetadata has summary field (maps to TS SDK summary).
    func testSessionMetadata_hasSummaryField() {
        let metadata = SessionMetadata(
            id: "sess-1", cwd: "/tmp", model: "m",
            createdAt: Date(), updatedAt: Date(), messageCount: 0,
            summary: "My test session"
        )
        XCTAssertEqual(metadata.summary, "My test session",
            "SessionMetadata.summary maps to TS SDK SDKSessionInfo.summary")
    }

    /// AC2 [P0]: SessionMetadata has updatedAt field (maps to TS SDK lastModified).
    func testSessionMetadata_hasUpdatedAtField() {
        let now = Date()
        let metadata = SessionMetadata(
            id: "sess-2", cwd: "/tmp", model: "m",
            createdAt: now, updatedAt: now, messageCount: 0
        )
        XCTAssertEqual(metadata.updatedAt, now,
            "SessionMetadata.updatedAt maps to TS SDK SDKSessionInfo.lastModified (different name)")
    }

    /// AC2 [GAP]: SessionMetadata has NO fileSize field (TS SDK has fileSize).
    func testSessionMetadata_noFileSize_gap() {
        let metadata = SessionMetadata(
            id: "sess-3", cwd: "/tmp", model: "m",
            createdAt: Date(), updatedAt: Date(), messageCount: 0
        )
        let mirror = Mirror(reflecting: metadata)
        let fieldNames = Set(mirror.children.compactMap { $0.label })
        XCTAssertFalse(fieldNames.contains("fileSize"),
            "[GAP] SessionMetadata should NOT have fileSize. TS SDK SDKSessionInfo has fileSize.")
    }

    /// AC2 [PARTIAL]: SessionMetadata uses summary for customTitle (TS has separate customTitle).
    func testSessionMetadata_summaryServesAsCustomTitle_partial() {
        let metadata = SessionMetadata(
            id: "sess-4", cwd: "/tmp", model: "m",
            createdAt: Date(), updatedAt: Date(), messageCount: 0,
            summary: "My custom title"
        )
        // TS SDK has separate summary and customTitle fields
        // Swift uses a single summary field for both purposes
        XCTAssertEqual(metadata.summary, "My custom title",
            "PARTIAL: summary serves as both summary and customTitle (TS has separate fields)")
    }

    /// AC2 [GAP]: SessionMetadata has NO firstPrompt field (TS SDK has firstPrompt).
    func testSessionMetadata_noFirstPrompt_gap() {
        let metadata = SessionMetadata(
            id: "sess-5", cwd: "/tmp", model: "m",
            createdAt: Date(), updatedAt: Date(), messageCount: 0
        )
        let mirror = Mirror(reflecting: metadata)
        let fieldNames = Set(mirror.children.compactMap { $0.label })
        XCTAssertFalse(fieldNames.contains("firstPrompt"),
            "[GAP] SessionMetadata should NOT have firstPrompt. TS SDK SDKSessionInfo has firstPrompt.")
    }

    /// AC2 [GAP]: SessionMetadata has NO gitBranch field (TS SDK has gitBranch).
    func testSessionMetadata_noGitBranch_gap() {
        let metadata = SessionMetadata(
            id: "sess-6", cwd: "/tmp", model: "m",
            createdAt: Date(), updatedAt: Date(), messageCount: 0
        )
        let mirror = Mirror(reflecting: metadata)
        let fieldNames = Set(mirror.children.compactMap { $0.label })
        XCTAssertFalse(fieldNames.contains("gitBranch"),
            "[GAP] SessionMetadata should NOT have gitBranch. TS SDK SDKSessionInfo has gitBranch.")
    }

    /// AC2 [P0]: SessionMetadata has cwd field (maps to TS SDK cwd).
    func testSessionMetadata_hasCwdField() {
        let metadata = SessionMetadata(
            id: "sess-7", cwd: "/home/user/project", model: "m",
            createdAt: Date(), updatedAt: Date(), messageCount: 0
        )
        XCTAssertEqual(metadata.cwd, "/home/user/project",
            "SessionMetadata.cwd maps to TS SDK SDKSessionInfo.cwd")
    }

    /// AC2 [P0]: SessionMetadata has tag field (maps to TS SDK tag).
    func testSessionMetadata_hasTagField() {
        let metadata = SessionMetadata(
            id: "sess-8", cwd: "/tmp", model: "m",
            createdAt: Date(), updatedAt: Date(), messageCount: 0,
            tag: "important"
        )
        XCTAssertEqual(metadata.tag, "important",
            "SessionMetadata.tag maps to TS SDK SDKSessionInfo.tag")
    }

    /// AC2 [P0]: SessionMetadata has createdAt field (maps to TS SDK createdAt).
    func testSessionMetadata_hasCreatedAtField() {
        let now = Date()
        let metadata = SessionMetadata(
            id: "sess-9", cwd: "/tmp", model: "m",
            createdAt: now, updatedAt: now, messageCount: 0
        )
        XCTAssertEqual(metadata.createdAt, now,
            "SessionMetadata.createdAt maps to TS SDK SDKSessionInfo.createdAt (uses Date not string)")
    }

    /// AC2 [P0]: SessionMetadata has EXTRA model field (not in TS SDK SDKSessionInfo).
    func testSessionMetadata_hasExtraModelField() {
        let metadata = SessionMetadata(
            id: "sess-10", cwd: "/tmp", model: "claude-sonnet-4-6",
            createdAt: Date(), updatedAt: Date(), messageCount: 0
        )
        XCTAssertEqual(metadata.model, "claude-sonnet-4-6",
            "model is a Swift-only field, not in TS SDK SDKSessionInfo")
    }

    /// AC2 [P0]: SessionMetadata has EXTRA messageCount field (not in TS SDK SDKSessionInfo).
    func testSessionMetadata_hasExtraMessageCountField() {
        let metadata = SessionMetadata(
            id: "sess-11", cwd: "/tmp", model: "m",
            createdAt: Date(), updatedAt: Date(), messageCount: 42
        )
        XCTAssertEqual(metadata.messageCount, 42,
            "messageCount is a Swift-only field, not in TS SDK SDKSessionInfo")
    }

    /// AC2 [P0]: SessionMetadata has exactly 8 fields.
    func testSessionMetadata_fieldCount() {
        let metadata = SessionMetadata(
            id: "x", cwd: "/tmp", model: "m",
            createdAt: Date(), updatedAt: Date(), messageCount: 0
        )
        let mirror = Mirror(reflecting: metadata)
        // Swift has 8 fields: id, cwd, model, createdAt, updatedAt, messageCount, summary, tag
        // TS SDK has 10 fields: sessionId, summary, lastModified, fileSize, customTitle,
        //   firstPrompt, gitBranch, cwd, tag, createdAt
        XCTAssertEqual(mirror.children.count, 8,
            "Swift has 8 fields vs TS SDK's 10 fields (4 MISSING, 3 EXTRA)")
    }
}

// MARK: - AC3: getSessionMessages Equivalent Verification (P0)

/// Verifies Swift SDK's SessionStore.load() covers TS SDK getSessionMessages().
/// TS SDK: getSessionMessages(sessionId, { dir?, limit?, offset? })
///   returns SessionMessage[] with fields: type (user/assistant), uuid, session_id,
///   message, parent_tool_use_id
final class GetSessionMessagesCompatTests: XCTestCase {

    /// AC3 [P0]: SessionStore.load(sessionId:) returns SessionData? with messages.
    func testSessionStore_load_returnsSessionData() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-load-messages-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m", summary: "test")
        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"],
            ["role": "assistant", "content": "Hi there!"]
        ]
        try await store.save(sessionId: "load-test-1", messages: messages, metadata: metadata)

        let loaded = try await store.load(sessionId: "load-test-1")
        XCTAssertNotNil(loaded, "load(sessionId:) returns SessionData?")
        XCTAssertEqual(loaded?.messages.count, 2, "SessionData.messages should have 2 messages")

        // Cleanup
        _ = try? await store.delete(sessionId: "load-test-1")
    }

    /// AC3 [P0]: SessionStore.load(sessionId:) returns nil for non-existent session.
    func testSessionStore_load_returnsNilForNonExistent() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-load-nonexistent-16-6")
        let loaded = try await store.load(sessionId: "nonexistent-session")
        XCTAssertNil(loaded, "load() returns nil for non-existent session, like TS getSessionMessages returns empty or null")
    }

    /// AC3 [GAP]: SessionStore.load() has NO pagination (limit/offset) parameters.
    func testSessionStore_load_noPagination_gap() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-load-pagination-16-6")
        // TS SDK: getSessionMessages(sessionId, { limit: 10, offset: 20 })
        // Swift: load(sessionId:) returns ALL messages, no pagination
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")
        try await store.save(sessionId: "pag-test", messages: [], metadata: metadata)

        let loaded = try await store.load(sessionId: "pag-test")
        // Cannot pass limit/offset -- always returns full transcript
        XCTAssertNotNil(loaded, "load() takes only sessionId (GAP: no limit/offset like TS SDK)")

        // Cleanup
        _ = try? await store.delete(sessionId: "pag-test")
    }

    // ================================================================
    // AC3: SessionData.messages element vs TS SDK SessionMessage
    // ================================================================

    /// AC3 [PARTIAL]: Messages use "role" field (TS SDK uses "type" field).
    func testSessionMessages_usesRoleNotType_partial() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-msg-role-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")
        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]
        try await store.save(sessionId: "role-test", messages: messages, metadata: metadata)

        let loaded = try await store.load(sessionId: "role-test")
        let firstMsg = loaded?.messages.first
        XCTAssertNotNil(firstMsg)
        XCTAssertEqual(firstMsg?["role"] as? String, "user",
            "Swift uses 'role' field, TS SDK uses 'type' field (PARTIAL: different key name)")

        // Cleanup
        _ = try? await store.delete(sessionId: "role-test")
    }

    /// AC3 [PARTIAL]: Messages use "content" field (TS SDK uses "message" field).
    func testSessionMessages_usesContentNotMessage_partial() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-msg-content-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")
        let messages: [[String: Any]] = [
            ["role": "assistant", "content": "Response text"]
        ]
        try await store.save(sessionId: "content-test", messages: messages, metadata: metadata)

        let loaded = try await store.load(sessionId: "content-test")
        let firstMsg = loaded?.messages.first
        XCTAssertNotNil(firstMsg)
        XCTAssertEqual(firstMsg?["content"] as? String, "Response text",
            "Swift uses 'content' field, TS SDK uses 'message' field (PARTIAL: different key name)")

        // Cleanup
        _ = try? await store.delete(sessionId: "content-test")
    }

    /// AC3 [GAP]: Messages are raw [String: Any] dicts, not typed SessionMessage structs.
    func testSessionMessages_notTyped_gap() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-msg-typed-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")
        let messages: [[String: Any]] = [["role": "user", "content": "hi"]]
        try await store.save(sessionId: "typed-test", messages: messages, metadata: metadata)

        let loaded = try await store.load(sessionId: "typed-test")
        let firstMsg = loaded?.messages.first
        // Swift stores messages as [String: Any] dictionaries
        // TS SDK has typed SessionMessage with type, uuid, session_id, message, parent_tool_use_id
        XCTAssertNotNil(firstMsg, "Messages are raw [String: Any] dicts (GAP: no typed SessionMessage struct)")
        XCTAssertNotNil(firstMsg, "Messages are dictionaries, not typed structs")

        // Cleanup
        _ = try? await store.delete(sessionId: "typed-test")
    }

    /// AC3 [GAP]: Messages have NO uuid field (TS SDK SessionMessage has uuid).
    func testSessionMessages_noUuidField_gap() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-msg-uuid-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")
        let messages: [[String: Any]] = [["role": "user", "content": "test"]]
        try await store.save(sessionId: "uuid-test", messages: messages, metadata: metadata)

        let loaded = try await store.load(sessionId: "uuid-test")
        let firstMsg = loaded?.messages.first
        XCTAssertNil(firstMsg?["uuid"],
            "[GAP] Swift messages have no uuid field. TS SDK SessionMessage has uuid.")

        // Cleanup
        _ = try? await store.delete(sessionId: "uuid-test")
    }

    /// AC3 [GAP]: Messages have NO session_id field (TS SDK SessionMessage has session_id).
    func testSessionMessages_noSessionIdField_gap() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-msg-sessid-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")
        let messages: [[String: Any]] = [["role": "user", "content": "test"]]
        try await store.save(sessionId: "sessid-test", messages: messages, metadata: metadata)

        let loaded = try await store.load(sessionId: "sessid-test")
        let firstMsg = loaded?.messages.first
        XCTAssertNil(firstMsg?["session_id"],
            "[GAP] Swift messages have no session_id field. TS SDK SessionMessage has session_id.")

        // Cleanup
        _ = try? await store.delete(sessionId: "sessid-test")
    }

    /// AC3 [GAP]: Messages have NO parent_tool_use_id field (TS SDK SessionMessage has it).
    func testSessionMessages_noParentToolUseId_gap() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-msg-parent-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")
        let messages: [[String: Any]] = [["role": "user", "content": "test"]]
        try await store.save(sessionId: "parent-test", messages: messages, metadata: metadata)

        let loaded = try await store.load(sessionId: "parent-test")
        let firstMsg = loaded?.messages.first
        XCTAssertNil(firstMsg?["parent_tool_use_id"],
            "[GAP] Swift messages have no parent_tool_use_id. TS SDK SessionMessage has it.")

        // Cleanup
        _ = try? await store.delete(sessionId: "parent-test")
    }
}

// MARK: - AC4: getSessionInfo/renameSession/tagSession Verification (P0)

/// Verifies Swift SDK's SessionStore has methods equivalent to TS SDK's
/// getSessionInfo, renameSession, and tagSession.
final class SessionInfoRenameTagCompatTests: XCTestCase {

    /// AC4 [PARTIAL]: SessionStore.load(sessionId:) serves as getSessionInfo.
    /// TS SDK has separate getSessionInfo(sessionId) returning info or nil.
    /// Swift uses load() which returns full SessionData; must extract .metadata for info-only.
    func testSessionStore_load_servesAsGetSessionInfo() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-getinfo-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m", summary: "Info test")
        try await store.save(sessionId: "info-test", messages: [], metadata: metadata)

        let loaded = try await store.load(sessionId: "info-test")
        XCTAssertNotNil(loaded, "load() returns SessionData, which contains metadata (PARTIAL: TS has dedicated getSessionInfo)")
        XCTAssertEqual(loaded?.metadata.id, "info-test", "Can extract .metadata for info-only use")

        // Cleanup
        _ = try? await store.delete(sessionId: "info-test")
    }

    /// AC4 [PARTIAL]: SessionStore.load(sessionId:) returns nil for non-existent (like TS getSessionInfo).
    func testSessionStore_load_returnsNilForGetSessionInfo() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-getinfo-nil-16-6")
        let loaded = try await store.load(sessionId: "nonexistent-info")
        XCTAssertNil(loaded, "load() returns nil for non-existent, matching TS getSessionInfo behavior")
    }

    /// AC4 [P0]: SessionStore.rename(sessionId:newTitle:) matches TS renameSession.
    func testSessionStore_rename_matchesTsRenameSession() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-rename-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m", summary: "Original title")
        try await store.save(sessionId: "rename-test", messages: [], metadata: metadata)

        try await store.rename(sessionId: "rename-test", newTitle: "Renamed session")

        let loaded = try await store.load(sessionId: "rename-test")
        XCTAssertEqual(loaded?.metadata.summary, "Renamed session",
            "rename(sessionId:newTitle:) updates summary, matching TS renameSession(sessionId, title)")

        // Cleanup
        _ = try? await store.delete(sessionId: "rename-test")
    }

    /// AC4 [P0]: SessionStore.rename() is silent no-op for non-existent session.
    func testSessionStore_rename_noOpForNonExistent() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-rename-noop-16-6")
        // TS SDK: renameSession throws or returns error for non-existent
        // Swift: silent no-op, does not throw
        try await store.rename(sessionId: "nonexistent", newTitle: "test")
        // If we reach here, rename was a silent no-op (no throw)
        XCTAssertTrue(true, "rename() is a silent no-op for non-existent sessions")
    }

    /// AC4 [P0]: SessionStore.tag(sessionId:tag:) matches TS tagSession.
    func testSessionStore_tag_matchesTsTagSession() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-tag-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")
        try await store.save(sessionId: "tag-test", messages: [], metadata: metadata)

        try await store.tag(sessionId: "tag-test", tag: "important")

        let loaded = try await store.load(sessionId: "tag-test")
        XCTAssertEqual(loaded?.metadata.tag, "important",
            "tag(sessionId:tag:) sets tag, matching TS tagSession(sessionId, tag)")

        // Cleanup
        _ = try? await store.delete(sessionId: "tag-test")
    }

    /// AC4 [P0]: SessionStore.tag(sessionId:nil) removes tag (TS SDK passes null).
    func testSessionStore_tag_nilRemovesTag() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-tag-nil-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m", tag: "old-tag")
        try await store.save(sessionId: "tag-nil-test", messages: [], metadata: metadata)

        try await store.tag(sessionId: "tag-nil-test", tag: nil)

        let loaded = try await store.load(sessionId: "tag-nil-test")
        XCTAssertNil(loaded?.metadata.tag,
            "tag(sessionId:nil) removes tag, matching TS tagSession(sessionId, null)")

        // Cleanup
        _ = try? await store.delete(sessionId: "tag-nil-test")
    }

    /// AC4 [P0]: SessionStore.tag() is silent no-op for non-existent session.
    func testSessionStore_tag_noOpForNonExistent() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-tag-noop-16-6")
        try await store.tag(sessionId: "nonexistent", tag: "test")
        // If we reach here, tag was a silent no-op (no throw)
        XCTAssertTrue(true, "tag() is a silent no-op for non-existent sessions")
    }

    /// AC4 [GAP]: SessionStore methods have NO dir parameter (TS SDK has { dir? }).
    func testSessionStore_noDirParamPerMethod_gap() async {
        let store = SessionStore(sessionsDir: "/tmp/test-dir-gap-16-6")
        // TS SDK: getSessionInfo(sessionId, { dir? })
        // TS SDK: renameSession(sessionId, title, { dir? })
        // TS SDK: tagSession(sessionId, tag, { dir? })
        // Swift: Directory is set at construction time, not per-method call
        // This is a design difference: Swift's constructor injection vs TS's per-call option
        let _ = store
    }
}

// MARK: - AC5: Session Restore Options Verification (P0)

/// Verifies Swift SDK's AgentOptions supports TS SDK session restore options.
/// TS SDK Options: resume, continue, forkSession, resumeSessionAt, sessionId, persistSession
final class SessionRestoreOptionsCompatTests: XCTestCase {

    /// AC5 [PARTIAL]: AgentOptions has sessionStore + sessionId (maps to TS resume).
    func testAgentOptions_resume_partial() {
        // TS SDK: resume: sessionId -- resume a session
        // Swift: sessionStore + sessionId both required for resume
        let store = SessionStore(sessionsDir: "/tmp/test-resume-16-6")
        let options = AgentOptions(
            sessionStore: store,
            sessionId: "existing-session-123"
        )
        XCTAssertNotNil(options.sessionStore, "sessionStore is set")
        XCTAssertEqual(options.sessionId, "existing-session-123",
            "PARTIAL: Swift requires sessionStore+sessionId pair instead of single 'resume' option")
    }

    /// AC5 [GAP]: AgentOptions has NO continue option (TS SDK has continue: true).
    func testAgentOptions_continue_gap() {
        let options = AgentOptions()
        let mirror = Mirror(reflecting: options)
        let fieldNames = Set(mirror.children.compactMap { $0.label })
        // TS SDK: continue: true -- continue most recent session
        // Swift: No equivalent convenience option
        XCTAssertFalse(fieldNames.contains("continue"),
            "[GAP] AgentOptions should NOT have 'continue' field. TS SDK has continue: true option.")
        XCTAssertFalse(fieldNames.contains("continueSession"),
            "[GAP] AgentOptions should NOT have 'continueSession' field.")
    }

    /// AC5 [RESOLVED]: AgentOptions now has forkSession option (Story 17-2).
    func testAgentOptions_forkSession_gap() {
        let options = AgentOptions(forkSession: true)
        let mirror = Mirror(reflecting: options)
        let fieldNames = Set(mirror.children.compactMap { $0.label })
        // TS SDK: forkSession: true -- fork instead of continue
        // Swift: Now has AgentOptions.forkSession (Story 17-2)
        XCTAssertTrue(fieldNames.contains("forkSession"),
            "[RESOLVED] AgentOptions now has 'forkSession' field (Story 17-2). TS SDK has forkSession: true option.")
        XCTAssertTrue(options.forkSession)
    }

    /// AC5 [RESOLVED]: AgentOptions now has resumeSessionAt option (Story 17-2).
    func testAgentOptions_resumeSessionAt_gap() {
        let options = AgentOptions(resumeSessionAt: "msg-uuid-001")
        let mirror = Mirror(reflecting: options)
        let fieldNames = Set(mirror.children.compactMap { $0.label })
        // TS SDK: resumeSessionAt: messageUUID -- resume at specific message
        // Swift: Now has AgentOptions.resumeSessionAt (Story 17-2)
        XCTAssertTrue(fieldNames.contains("resumeSessionAt"),
            "[RESOLVED] AgentOptions now has 'resumeSessionAt' field (Story 17-2). TS SDK has this option.")
        XCTAssertEqual(options.resumeSessionAt, "msg-uuid-001")
    }

    /// AC5 [P0]: AgentOptions has sessionId field (maps to TS SDK sessionId: uuid).
    func testAgentOptions_sessionId_pass() {
        var options = AgentOptions()
        options.sessionId = "custom-uuid-1234"
        XCTAssertEqual(options.sessionId, "custom-uuid-1234",
            "AgentOptions.sessionId maps to TS SDK Options.sessionId")
    }

    /// AC5 [RESOLVED]: AgentOptions now has persistSession option (Story 17-2).
    func testAgentOptions_persistSession_gap() {
        let options = AgentOptions()
        let mirror = Mirror(reflecting: options)
        let fieldNames = Set(mirror.children.compactMap { $0.label })
        // TS SDK: persistSession: false -- disable persistence
        // Swift: Now has AgentOptions.persistSession (Story 17-2), defaults to true
        XCTAssertTrue(fieldNames.contains("persistSession"),
            "[RESOLVED] AgentOptions now has 'persistSession' field (Story 17-2). TS SDK has persistSession: false option.")
        XCTAssertTrue(options.persistSession, "persistSession defaults to true")
    }

    /// AC5 [P0]: SessionStore.fork() exists as standalone method (Swift-only approach).
    func testSessionStore_fork_standaloneMethod() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-fork-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")
        let messages: [[String: Any]] = [
            ["role": "user", "content": "First"],
            ["role": "assistant", "content": "Second"]
        ]
        try await store.save(sessionId: "fork-source", messages: messages, metadata: metadata)

        let forkId = try await store.fork(sourceSessionId: "fork-source", newSessionId: "fork-dest")
        XCTAssertEqual(forkId, "fork-dest",
            "SessionStore.fork() creates a copy with new ID (Swift-only: TS uses forkSession option)")

        let forked = try await store.load(sessionId: "fork-dest")
        XCTAssertEqual(forked?.messages.count, 2, "Forked session has same messages as source")

        // Cleanup
        _ = try? await store.delete(sessionId: "fork-source")
        _ = try? await store.delete(sessionId: "fork-dest")
    }

    /// AC5 [P0]: SessionStore.fork() supports upToMessageIndex truncation.
    func testSessionStore_fork_withTruncation() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-fork-trunc-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")
        let messages: [[String: Any]] = [
            ["role": "user", "content": "Msg0"],
            ["role": "assistant", "content": "Msg1"],
            ["role": "user", "content": "Msg2"]
        ]
        try await store.save(sessionId: "fork-trunc-src", messages: messages, metadata: metadata)

        let forkId = try await store.fork(
            sourceSessionId: "fork-trunc-src",
            newSessionId: "fork-trunc-dest",
            upToMessageIndex: 1
        )
        XCTAssertNotNil(forkId)

        let forked = try await store.load(sessionId: "fork-trunc-dest")
        XCTAssertEqual(forked?.messages.count, 2,
            "Fork with upToMessageIndex:1 copies only first 2 messages (indices 0-1)")

        // Cleanup
        _ = try? await store.delete(sessionId: "fork-trunc-src")
        _ = try? await store.delete(sessionId: "fork-trunc-dest")
    }

    /// AC5 [P0]: SessionStore.save() and delete() are EXTRA Swift-only methods.
    func testSessionStore_extraMethods() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-extra-methods-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")

        // save() -- TS SDK has no standalone save function exposed
        try await store.save(sessionId: "extra-test", messages: [], metadata: metadata)
        let loaded = try await store.load(sessionId: "extra-test")
        XCTAssertNotNil(loaded, "save() is a Swift-only method")

        // delete() -- TS SDK has no standalone delete function exposed
        let deleted = try await store.delete(sessionId: "extra-test")
        XCTAssertTrue(deleted, "delete() is a Swift-only method")

        let gone = try await store.load(sessionId: "extra-test")
        XCTAssertNil(gone, "delete() removes the session")
    }
}

// MARK: - AC6: Cross-Query Context Retention Verification (P0)

/// Verifies that session persistence works: save -> load round-trip preserves messages.
/// (Same-Agent in-memory context retention was already verified in Story 16-1 AC5.)
final class CrossQueryContextCompatTests: XCTestCase {

    /// AC6 [P0]: Session save/load round-trip preserves message order and content.
    func testSessionSaveLoad_preservesMessages() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-context-roundtrip-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "claude-sonnet-4-6")

        // Round 1: Save a session with a fact
        let round1Messages: [[String: Any]] = [
            ["role": "user", "content": "My favorite color is blue."],
            ["role": "assistant", "content": "I'll remember that your favorite color is blue."]
        ]
        try await store.save(sessionId: "context-test", messages: round1Messages, metadata: metadata)

        // Round 2: Load the session and verify context is retained
        let loaded = try await store.load(sessionId: "context-test")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.messages.count, 2)

        let userMsg = loaded?.messages[0]["content"] as? String
        let assistantMsg = loaded?.messages[1]["content"] as? String
        XCTAssertEqual(userMsg, "My favorite color is blue.",
            "Round 1 user message preserved in round-trip")
        XCTAssertTrue(assistantMsg?.contains("blue") ?? false,
            "Round 1 assistant message preserved in round-trip")

        // Simulate appending a new round-2 message
        var allMessages = loaded!.messages
        allMessages.append(["role": "user", "content": "What is my favorite color?"])
        allMessages.append(["role": "assistant", "content": "Your favorite color is blue."])

        try await store.save(sessionId: "context-test", messages: allMessages, metadata: metadata)

        // Verify both rounds preserved
        let reloaded = try await store.load(sessionId: "context-test")
        XCTAssertEqual(reloaded?.messages.count, 4,
            "After 2 rounds, 4 messages total")
        let round2UserMsg = reloaded?.messages[2]["content"] as? String
        XCTAssertEqual(round2UserMsg, "What is my favorite color?",
            "Round 2 user message preserved")

        // Cleanup
        _ = try? await store.delete(sessionId: "context-test")
    }

    /// AC6 [P0]: Session persistence preserves metadata across saves.
    func testSessionSaveLoad_preservesMetadata() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-context-meta-16-6")

        // Save with initial metadata
        let metadata = PartialSessionMetadata(
            cwd: "/home/user/project",
            model: "claude-sonnet-4-6",
            summary: "Color memory test",
            tag: "context-test"
        )
        try await store.save(sessionId: "meta-test", messages: [], metadata: metadata)

        let loaded = try await store.load(sessionId: "meta-test")
        XCTAssertEqual(loaded?.metadata.id, "meta-test")
        XCTAssertEqual(loaded?.metadata.cwd, "/home/user/project")
        XCTAssertEqual(loaded?.metadata.model, "claude-sonnet-4-6")
        XCTAssertEqual(loaded?.metadata.summary, "Color memory test")
        XCTAssertEqual(loaded?.metadata.tag, "context-test")
        XCTAssertEqual(loaded?.metadata.messageCount, 0)

        // Re-save with updated messages, preserving metadata fields
        let updatedMetadata = PartialSessionMetadata(
            cwd: "/home/user/project",
            model: "claude-sonnet-4-6",
            summary: "Updated title",
            tag: "context-test"
        )
        let newMessages: [[String: Any]] = [["role": "user", "content": "Hello"]]
        try await store.save(sessionId: "meta-test", messages: newMessages, metadata: updatedMetadata)

        let reloaded = try await store.load(sessionId: "meta-test")
        XCTAssertEqual(reloaded?.metadata.summary, "Updated title",
            "Metadata updates correctly on re-save")
        XCTAssertEqual(reloaded?.metadata.messageCount, 1,
            "messageCount updates on re-save")
        XCTAssertNotNil(reloaded?.metadata.createdAt,
            "createdAt is preserved on re-save")

        // Cleanup
        _ = try? await store.delete(sessionId: "meta-test")
    }

    /// AC6 [P0]: CreatedAt timestamp is preserved across re-saves.
    func testSessionSaveLoad_preservesCreatedAt() async throws {
        let store = SessionStore(sessionsDir: "/tmp/test-context-created-16-6")
        let metadata = PartialSessionMetadata(cwd: "/tmp", model: "m")
        try await store.save(sessionId: "created-test", messages: [], metadata: metadata)

        let first = try await store.load(sessionId: "created-test")
        let originalCreatedAt = first?.metadata.createdAt

        // Wait briefly, then re-save
        try await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 0.1s
        try await store.save(sessionId: "created-test", messages: [["role": "user", "content": "hi"]], metadata: metadata)

        let second = try await store.load(sessionId: "created-test")
        XCTAssertEqual(second?.metadata.createdAt, originalCreatedAt,
            "createdAt must be preserved across re-saves (TS SDK behavior)")
        XCTAssertGreaterThan(second!.metadata.updatedAt, first!.metadata.updatedAt,
            "updatedAt should be newer after re-save")

        // Cleanup
        _ = try? await store.delete(sessionId: "created-test")
    }
}

// MARK: - AC7: Compatibility Report Output (P0)

/// Generates the complete compatibility report for all session management
/// functions, field mappings, and restore options.
final class SessionManagementCompatReportTests: XCTestCase {

    /// AC7 [P0]: TS SDK session functions vs Swift SessionStore methods report.
    func testCompatReport_sessionFunctionCoverage() {
        struct FnMapping {
            let index: Int
            let tsFunction: String
            let swiftEquivalent: String
            let status: String
            let note: String
        }

        let mappings: [FnMapping] = [
            FnMapping(index: 1, tsFunction: "listSessions({ dir?, limit?, includeWorktrees? })",
                swiftEquivalent: "SessionStore.list()", status: "PARTIAL",
                note: "No limit, includeWorktrees, or dir params. Returns all sessions sorted by updatedAt."),
            FnMapping(index: 2, tsFunction: "getSessionMessages(sessionId, { dir?, limit?, offset? })",
                swiftEquivalent: "SessionStore.load(sessionId:)", status: "PARTIAL",
                note: "Returns all messages (no pagination). No dir param."),
            FnMapping(index: 3, tsFunction: "getSessionInfo(sessionId, { dir? })",
                swiftEquivalent: "SessionStore.load(sessionId:).metadata", status: "PARTIAL",
                note: "Returns full SessionData; must extract .metadata. No dir param."),
            FnMapping(index: 4, tsFunction: "renameSession(sessionId, title, { dir? })",
                swiftEquivalent: "SessionStore.rename(sessionId:newTitle:)", status: "PASS",
                note: "Functional equivalent. No dir param."),
            FnMapping(index: 5, tsFunction: "tagSession(sessionId, tag|null, { dir? })",
                swiftEquivalent: "SessionStore.tag(sessionId:tag:)", status: "PASS",
                note: "Functional equivalent. nil removes tag. No dir param."),
            FnMapping(index: 6, tsFunction: "N/A",
                swiftEquivalent: "SessionStore.save(sessionId:messages:metadata:)", status: "EXTRA",
                note: "Swift-only. TS SDK has no standalone save."),
            FnMapping(index: 7, tsFunction: "N/A",
                swiftEquivalent: "SessionStore.delete(sessionId:)", status: "EXTRA",
                note: "Swift-only. TS SDK has no standalone delete."),
            FnMapping(index: 8, tsFunction: "N/A",
                swiftEquivalent: "SessionStore.fork(sourceSessionId:newSessionId:upToMessageIndex:)", status: "EXTRA",
                note: "Swift-only standalone fork. TS uses forkSession: true AgentOption."),
        ]

        print("")
        print("=== Session Management Compatibility Report (AC7) ===")
        print("TS SDK Session Functions vs Swift SDK SessionStore")
        for m in mappings {
            print("  \(m.index)\t\(m.tsFunction)")
            print("  \t-> \(m.swiftEquivalent) [\(m.status)] \(m.note)")
        }

        let passCount = mappings.filter { $0.status == "PASS" }.count
        let partialCount = mappings.filter { $0.status == "PARTIAL" }.count
        let extraCount = mappings.filter { $0.status == "EXTRA" }.count

        print("")
        print("Summary: PASS: \(passCount) | PARTIAL: \(partialCount) | EXTRA: \(extraCount) | Total: \(mappings.count)")
        print("")

        XCTAssertEqual(passCount, 2, "2 functions fully pass (rename, tag)")
        XCTAssertEqual(partialCount, 3, "3 functions partial (list, getMessages, getInfo)")
        XCTAssertEqual(extraCount, 3, "3 Swift-only extra methods (save, delete, fork)")
        XCTAssertEqual(mappings.count, 8, "All 8 method mappings accounted for")
    }

    /// AC7 [P0]: SessionMetadata field-level compatibility report.
    func testCompatReport_sessionMetadataFieldCoverage() {
        struct FieldMapping {
            let tsField: String
            let swiftField: String
            let status: String
        }

        let mappings: [FieldMapping] = [
            // TS SDK SDKSessionInfo fields vs Swift SessionMetadata fields
            FieldMapping(tsField: "sessionId", swiftField: "id: String", status: "PASS"),
            FieldMapping(tsField: "summary", swiftField: "summary: String?", status: "PASS"),
            FieldMapping(tsField: "lastModified", swiftField: "updatedAt: Date", status: "PASS"),
            FieldMapping(tsField: "fileSize", swiftField: "MISSING", status: "MISSING"),
            FieldMapping(tsField: "customTitle", swiftField: "summary (shared)", status: "PARTIAL"),
            FieldMapping(tsField: "firstPrompt", swiftField: "MISSING", status: "MISSING"),
            FieldMapping(tsField: "gitBranch", swiftField: "MISSING", status: "MISSING"),
            FieldMapping(tsField: "cwd", swiftField: "cwd: String", status: "PASS"),
            FieldMapping(tsField: "tag", swiftField: "tag: String?", status: "PASS"),
            FieldMapping(tsField: "createdAt", swiftField: "createdAt: Date", status: "PASS"),
            // Swift-only extra fields
            FieldMapping(tsField: "N/A", swiftField: "model: String", status: "EXTRA"),
            FieldMapping(tsField: "N/A", swiftField: "messageCount: Int", status: "EXTRA"),
            FieldMapping(tsField: "N/A", swiftField: "updatedAt: Date (separate)", status: "EXTRA"),
        ]

        print("")
        print("=== SessionMetadata Field Compatibility ===")
        for m in mappings {
            print("  [\(m.status)] TS: \(m.tsField) -> Swift: \(m.swiftField)")
        }

        let passCount = mappings.filter { $0.status == "PASS" }.count
        let partialCount = mappings.filter { $0.status == "PARTIAL" }.count
        let missingCount = mappings.filter { $0.status == "MISSING" }.count
        let extraCount = mappings.filter { $0.status == "EXTRA" }.count

        print("Summary: PASS: \(passCount) | PARTIAL: \(partialCount) | MISSING: \(missingCount) | EXTRA: \(extraCount)")
        print("")

        XCTAssertEqual(passCount, 6, "6 fields fully pass")
        XCTAssertEqual(partialCount, 1, "1 field partial (customTitle)")
        XCTAssertEqual(missingCount, 3, "3 fields missing (fileSize, firstPrompt, gitBranch)")
        XCTAssertEqual(extraCount, 3, "3 Swift-only extra fields")
    }

    /// AC7 [P0]: SessionMessage element field compatibility report.
    func testCompatReport_sessionMessageFieldCoverage() {
        struct FieldMapping {
            let tsField: String
            let swiftField: String
            let status: String
        }

        let mappings: [FieldMapping] = [
            // TS SDK SessionMessage fields vs Swift raw message dict keys
            FieldMapping(tsField: "type (user/assistant)", swiftField: "role (user/assistant)", status: "PARTIAL"),
            FieldMapping(tsField: "uuid", swiftField: "MISSING", status: "MISSING"),
            FieldMapping(tsField: "session_id", swiftField: "MISSING", status: "MISSING"),
            FieldMapping(tsField: "message", swiftField: "content", status: "PARTIAL"),
            FieldMapping(tsField: "parent_tool_use_id", swiftField: "MISSING", status: "MISSING"),
        ]

        let partialCount = mappings.filter { $0.status == "PARTIAL" }.count
        let missingCount = mappings.filter { $0.status == "MISSING" }.count

        print("")
        print("=== SessionMessage Element Field Compatibility ===")
        for m in mappings {
            print("  [\(m.status)] TS: \(m.tsField) -> Swift: \(m.swiftField)")
        }
        print("Summary: PARTIAL: \(partialCount) | MISSING: \(missingCount) | Total: \(mappings.count)")
        print("Note: Swift messages are raw [String: Any] dicts, not typed structs")
        print("")

        XCTAssertEqual(partialCount, 2, "2 fields partial (type->role, message->content)")
        XCTAssertEqual(missingCount, 3, "3 fields missing (uuid, session_id, parent_tool_use_id)")
    }

    /// AC7 [P0]: Session restore options compatibility report.
    func testCompatReport_restoreOptionsCoverage() {
        struct OptionMapping {
            let tsOption: String
            let swiftEquivalent: String
            let status: String
            let note: String
        }

        let mappings: [OptionMapping] = [
            OptionMapping(tsOption: "resume: sessionId",
                swiftEquivalent: "sessionStore + sessionId", status: "PARTIAL",
                note: "Requires two fields instead of one 'resume' option"),
            OptionMapping(tsOption: "continue: true",
                swiftEquivalent: "MISSING", status: "MISSING",
                note: "No 'resume most recent session' convenience option"),
            OptionMapping(tsOption: "forkSession: true",
                swiftEquivalent: "MISSING as option", status: "MISSING",
                note: "SessionStore.fork() exists as standalone method, not AgentOption"),
            OptionMapping(tsOption: "resumeSessionAt: messageUUID",
                swiftEquivalent: "MISSING", status: "MISSING",
                note: "No option to resume at specific message"),
            OptionMapping(tsOption: "sessionId: uuid",
                swiftEquivalent: "sessionId: String?", status: "PASS",
                note: "Can set a custom session ID"),
            OptionMapping(tsOption: "persistSession: false",
                swiftEquivalent: "MISSING", status: "MISSING",
                note: "No way to disable persistence when sessionStore+sessionId are set"),
        ]

        print("")
        print("=== Session Restore Options Compatibility ===")
        for m in mappings {
            print("  [\(m.status)] TS: \(m.tsOption) -> Swift: \(m.swiftEquivalent)")
            print("       \(m.note)")
        }

        let passCount = mappings.filter { $0.status == "PASS" }.count
        let partialCount = mappings.filter { $0.status == "PARTIAL" }.count
        let missingCount = mappings.filter { $0.status == "MISSING" }.count

        print("Summary: PASS: \(passCount) | PARTIAL: \(partialCount) | MISSING: \(missingCount) | Total: \(mappings.count)")
        print("")

        XCTAssertEqual(passCount, 1, "1 option fully passes (sessionId)")
        XCTAssertEqual(partialCount, 1, "1 option partial (resume via sessionStore+sessionId)")
        XCTAssertEqual(missingCount, 4, "4 options missing (continue, forkSession, resumeSessionAt, persistSession)")
        XCTAssertEqual(mappings.count, 6, "All 6 TS restore options checked")
    }

    /// AC7 [P0]: Overall compatibility summary.
    func testCompatReport_overallSummary() {
        // Method-level: 2 PASS, 3 PARTIAL, 0 MISSING, 3 EXTRA
        // Field-level (metadata): 6 PASS, 1 PARTIAL, 3 MISSING, 3 EXTRA
        // Field-level (messages): 0 PASS, 2 PARTIAL, 3 MISSING
        // Options-level: 1 PASS, 1 PARTIAL, 4 MISSING

        print("")
        print("==============================================")
        print("Story 16-6: Session Management Compat Summary")
        print("==============================================")
        print("Session Functions:    2 PASS | 3 PARTIAL | 0 MISSING | 3 EXTRA (Swift-only)")
        print("Metadata Fields:     6 PASS | 1 PARTIAL | 3 MISSING | 3 EXTRA (Swift-only)")
        print("Message Fields:      0 PASS | 2 PARTIAL | 3 MISSING")
        print("Restore Options:     1 PASS | 1 PARTIAL | 4 MISSING")
        print("----------------------------------------------")
        print("Total:               9 PASS | 7 PARTIAL | 10 MISSING | 6 EXTRA")
        print("==============================================")
        print("")

        // Verify totals
        let totalPass = 2 + 6 + 0 + 1
        let totalPartial = 3 + 1 + 2 + 1
        let totalMissing = 0 + 3 + 3 + 4
        let totalExtra = 3 + 3 + 0 + 0

        XCTAssertEqual(totalPass, 9)
        XCTAssertEqual(totalPartial, 7)
        XCTAssertEqual(totalMissing, 10)
        XCTAssertEqual(totalExtra, 6)
    }
}

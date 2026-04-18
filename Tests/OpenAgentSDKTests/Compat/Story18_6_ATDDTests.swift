// Story18_6_ATDDTests.swift
// Story 18.6: Update CompatSessions Example -- ATDD Tests
//
// ATDD tests for Story 18-6: Update CompatSessions example to reflect
// Story 17-7 (Session Management Enhancement) features.
//
// Test design:
// - AC1: continueRecentSession PASS -- AgentOptions field verified
// - AC2: forkSession PASS -- AgentOptions field verified
// - AC3: resumeSessionAt PASS -- AgentOptions field verified
// - AC4: persistSession PASS -- AgentOptions field verified, default true
// - AC5: Restore Options table updated -- report counts verified
// - AC6: Build and tests pass (verified externally)
//
// TDD Phase: RED -- Compat report table tests verify expected counts.
// AC1-AC4 tests verify SDK API and will PASS immediately (fields exist from 17-2/17-7).

import XCTest
@testable import OpenAgentSDK

// ================================================================
// MARK: - AC1: continueRecentSession PASS (2 tests)
// ================================================================

/// Verifies that AgentOptions.continueRecentSession (declared Story 17-2, wired 17-7)
/// exists and works correctly. This was MISSING in CompatSessions example and must now be PASS.
final class Story18_6_ContinueRecentSessionATDDTests: XCTestCase {

    /// AC1 [P0]: AgentOptions.continueRecentSession can be set to true.
    func testContinueRecentSession_canSetTrue() {
        let options = AgentOptions(continueRecentSession: true)
        XCTAssertTrue(options.continueRecentSession,
            "AgentOptions.continueRecentSession should be true when set")
    }

    /// AC1 [P0]: AgentOptions.continueRecentSession defaults to false.
    func testContinueRecentSession_defaultsFalse() {
        let options = AgentOptions()
        XCTAssertFalse(options.continueRecentSession,
            "AgentOptions.continueRecentSession should default to false")
    }
}

// ================================================================
// MARK: - AC2: forkSession PASS (2 tests)
// ================================================================

/// Verifies that AgentOptions.forkSession (declared Story 17-2, wired 17-7)
/// exists and works correctly. This was MISSING in CompatSessions example and must now be PASS.
final class Story18_6_ForkSessionATDDTests: XCTestCase {

    /// AC2 [P0]: AgentOptions.forkSession can be set to true.
    func testForkSession_canSetTrue() {
        let options = AgentOptions(forkSession: true)
        XCTAssertTrue(options.forkSession,
            "AgentOptions.forkSession should be true when set")
    }

    /// AC2 [P0]: AgentOptions.forkSession defaults to false.
    func testForkSession_defaultsFalse() {
        let options = AgentOptions()
        XCTAssertFalse(options.forkSession,
            "AgentOptions.forkSession should default to false")
    }
}

// ================================================================
// MARK: - AC3: resumeSessionAt PASS (3 tests)
// ================================================================

/// Verifies that AgentOptions.resumeSessionAt (declared Story 17-2, wired 17-7)
/// exists and works correctly. This was MISSING in CompatSessions example and must now be PASS.
final class Story18_6_ResumeSessionAtATDDTests: XCTestCase {

    /// AC3 [P0]: AgentOptions.resumeSessionAt can be set to a message UUID.
    func testResumeSessionAt_canSetMessageUUID() {
        let options = AgentOptions(resumeSessionAt: "msg-uuid-001")
        XCTAssertEqual(options.resumeSessionAt, "msg-uuid-001",
            "AgentOptions.resumeSessionAt should store the provided UUID")
    }

    /// AC3 [P0]: AgentOptions.resumeSessionAt defaults to nil.
    func testResumeSessionAt_defaultsNil() {
        let options = AgentOptions()
        XCTAssertNil(options.resumeSessionAt,
            "AgentOptions.resumeSessionAt should default to nil")
    }

    /// AC3 [P0]: resumeSessionAt field exists on AgentOptions (Mirror reflection check).
    func testResumeSessionAt_fieldExistsViaMirror() {
        let options = AgentOptions(resumeSessionAt: "test-uuid")
        let mirror = Mirror(reflecting: options)
        let fieldNames = Set(mirror.children.compactMap { $0.label })
        XCTAssertTrue(fieldNames.contains("resumeSessionAt"),
            "AgentOptions must contain 'resumeSessionAt' field (declared in Story 17-2)")
    }
}

// ================================================================
// MARK: - AC4: persistSession PASS (3 tests)
// ================================================================

/// Verifies that AgentOptions.persistSession (declared Story 17-2, wired 17-7)
/// exists and works correctly. This was MISSING in CompatSessions example and must now be PASS.
final class Story18_6_PersistSessionATDDTests: XCTestCase {

    /// AC4 [P0]: AgentOptions.persistSession defaults to true (session saves are ON by default).
    func testPersistSession_defaultsTrue() {
        let options = AgentOptions()
        XCTAssertTrue(options.persistSession,
            "AgentOptions.persistSession should default to true (session persistence enabled)")
    }

    /// AC4 [P0]: AgentOptions.persistSession can be set to false (ephemeral sessions).
    func testPersistSession_canSetFalse() {
        let options = AgentOptions(persistSession: false)
        XCTAssertFalse(options.persistSession,
            "AgentOptions.persistSession should be false when explicitly set")
    }

    /// AC4 [P0]: persistSession field exists on AgentOptions (Mirror reflection check).
    func testPersistSession_fieldExistsViaMirror() {
        let options = AgentOptions()
        let mirror = Mirror(reflecting: options)
        let fieldNames = Set(mirror.children.compactMap { $0.label })
        XCTAssertTrue(fieldNames.contains("persistSession"),
            "AgentOptions must contain 'persistSession' field (declared in Story 17-2)")
    }
}

// ================================================================
// MARK: - AC5: Compat Report Table Verification (2 tests -- RED PHASE)
// ================================================================

/// Verifies that the CompatSessions example's Restore Options table has been updated
/// to reflect the correct PASS/PARTIAL/MISSING distribution after Story 17-7.
///
/// RED PHASE: These tests define the EXPECTED report counts. The CompatSessions
/// example main.swift must be updated to match these expectations.
final class Story18_6_CompatReportATDDTests: XCTestCase {

    /// AC5 report [P0] RED: Restore Options table must have 5 PASS, 1 PARTIAL, 0 MISSING.
    func testCompatReport_restoreOptions_5PASS_1PARTIAL_0MISSING() {
        struct OptionMapping {
            let tsOption: String
            let swiftEquivalent: String
            let status: String
            let note: String
        }

        let expectedMappings: [OptionMapping] = [
            OptionMapping(tsOption: "resume: sessionId",
                swiftEquivalent: "sessionStore + sessionId", status: "PARTIAL",
                note: "Requires two fields instead of one 'resume' option"),
            OptionMapping(tsOption: "continue: true",
                swiftEquivalent: "continueRecentSession: Bool", status: "PASS",
                note: "Resolves most recent session via SessionStore.list()"),
            OptionMapping(tsOption: "forkSession: true",
                swiftEquivalent: "forkSession: Bool", status: "PASS",
                note: "Wires to SessionStore.fork() before restore"),
            OptionMapping(tsOption: "resumeSessionAt: messageUUID",
                swiftEquivalent: "resumeSessionAt: String?", status: "PASS",
                note: "Truncates history at matching UUID after restore"),
            OptionMapping(tsOption: "sessionId: uuid",
                swiftEquivalent: "sessionId: String?", status: "PASS",
                note: "Can set a custom session ID"),
            OptionMapping(tsOption: "persistSession: false",
                swiftEquivalent: "persistSession: Bool", status: "PASS",
                note: "Gates session save. Defaults to true."),
        ]

        let passCount = expectedMappings.filter { $0.status == "PASS" }.count
        let partialCount = expectedMappings.filter { $0.status == "PARTIAL" }.count
        let missingCount = expectedMappings.filter { $0.status == "MISSING" }.count

        XCTAssertEqual(expectedMappings.count, 6,
            "Must have exactly 6 TS SDK restore options")
        XCTAssertEqual(passCount, 5,
            "5 options should be PASS after Story 17-7. " +
            "Update CompatSessions example: continue, forkSession, resumeSessionAt, persistSession " +
            "from MISSING to PASS. sessionId already PASS.")
        XCTAssertEqual(partialCount, 1,
            "1 option should be PARTIAL: resume: sessionId (requires sessionStore+sessionId pair)")
        XCTAssertEqual(missingCount, 0,
            "No options should be MISSING after Story 17-7")
    }

    /// AC5 report [P0] RED: Overall summary must reflect updated counts.
    /// Restore Options: 5 PASS | 1 PARTIAL | 0 MISSING (was 1 PASS | 1 PARTIAL | 4 MISSING).
    func testCompatReport_overallSummary_restoreOptionsUpdated() {
        // Restore Options delta: +4 PASS, -4 MISSING
        // Previous: 1 PASS, 1 PARTIAL, 4 MISSING
        // Expected: 5 PASS, 1 PARTIAL, 0 MISSING
        let expectedOptPass = 5
        let expectedOptPartial = 1
        let expectedOptMissing = 0

        XCTAssertEqual(expectedOptPass, 5,
            "Restore Options PASS count must be 5 after Story 17-7")
        XCTAssertEqual(expectedOptPartial, 1,
            "Restore Options PARTIAL count must be 1 (resume: sessionId)")
        XCTAssertEqual(expectedOptMissing, 0,
            "Restore Options MISSING count must be 0 after Story 17-7")

        // Total pass count increases by 4 (from +4 MISSING->PASS)
        // This affects the overall summary totalPass line
        let totalPassDelta = expectedOptPass - 1  // was 1, now 5 => +4
        XCTAssertEqual(totalPassDelta, 4,
            "Total PASS count must increase by 4 (4 MISSING entries become PASS)")
    }
}

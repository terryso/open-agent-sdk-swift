import XCTest
@testable import OpenAgentSDK

// MARK: - ToolContext FileCache ATDD Tests (Story 12.1)

/// ATDD RED PHASE: Tests for Story 12.1 -- ToolContext fileCache property addition.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `ToolContext` adds `fileCache: FileCache?` optional property
///   - `withToolUseId()` and `withSkillContext()` preserve fileCache reference
/// TDD Phase: RED (feature not implemented yet)
final class ToolContextFileCacheTests: XCTestCase {

    // MARK: - AC5: ToolContext fileCache Property

    /// AC5 [P0]: Default fileCache is nil (does not break existing code).
    func testToolContext_fileCache_DefaultNil() {
        // Given: a ToolContext created without fileCache
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-1")

        // Then: fileCache is nil
        XCTAssertNil(context.fileCache,
                     "fileCache should default to nil")
    }

    /// AC5 [P0]: fileCache can be injected via init.
    func testToolContext_fileCache_Injected() {
        // Given: a FileCache instance
        let cache = FileCache()

        // When: creating ToolContext with fileCache
        let context = ToolContext(
            cwd: "/tmp",
            toolUseId: "test-2",
            fileCache: cache
        )

        // Then: fileCache is set
        XCTAssertNotNil(context.fileCache,
                        "fileCache should not be nil when injected")
        // Verify it's the same instance (reference type)
        XCTAssertTrue(context.fileCache === cache,
                      "fileCache should be the same instance")
    }

    /// AC5 [P0]: withToolUseId() preserves fileCache reference.
    func testToolContext_withToolUseId_PreservesFileCache() {
        // Given: a ToolContext with fileCache
        let cache = FileCache()
        let original = ToolContext(
            cwd: "/tmp",
            toolUseId: "old-id",
            fileCache: cache
        )

        // When: creating a copy with new toolUseId
        let copy = original.withToolUseId("new-id")

        // Then: fileCache is preserved
        XCTAssertNotNil(copy.fileCache,
                        "fileCache should be preserved in withToolUseId copy")
        XCTAssertTrue(copy.fileCache === cache,
                      "fileCache should be same instance after withToolUseId")
        XCTAssertEqual(copy.toolUseId, "new-id",
                       "toolUseId should be updated")
    }

    /// AC5 [P0]: withSkillContext() preserves fileCache reference.
    func testToolContext_withSkillContext_PreservesFileCache() {
        // Given: a ToolContext with fileCache
        let cache = FileCache()
        let original = ToolContext(
            cwd: "/tmp",
            toolUseId: "test-3",
            fileCache: cache
        )

        // When: creating a copy with new skill context
        let copy = original.withSkillContext(depth: 2)

        // Then: fileCache is preserved
        XCTAssertNotNil(copy.fileCache,
                        "fileCache should be preserved in withSkillContext copy")
        XCTAssertTrue(copy.fileCache === cache,
                      "fileCache should be same instance after withSkillContext")
        XCTAssertEqual(copy.skillNestingDepth, 2,
                       "skillNestingDepth should be updated")
    }

    /// ToolContext equality works with fileCache field.
    func testToolContext_Equatable_WithFileCache() {
        // Given: two ToolContexts with same fileCache instance
        let cache = FileCache()
        let a = ToolContext(cwd: "/tmp", toolUseId: "t1", fileCache: cache)
        let b = ToolContext(cwd: "/tmp", toolUseId: "t1", fileCache: cache)

        // Then: they are equal (same cwd, toolUseId, and fileCache reference)
        XCTAssertEqual(a.toolUseId, b.toolUseId,
                       "toolUseId should match")
        XCTAssertTrue(a.fileCache === b.fileCache,
                      "fileCache should be same reference")
    }
}

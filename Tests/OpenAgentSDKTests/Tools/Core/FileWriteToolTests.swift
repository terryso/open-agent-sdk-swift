import XCTest
@testable import OpenAgentSDK

// MARK: - FileWriteTool ATDD Tests (Story 3.4)

/// ATDD RED PHASE: Tests for Story 3.4 — FileWriteTool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Sources/OpenAgentSDK/Tools/Core/FileWriteTool.swift` is created
///   - `createWriteTool() -> ToolProtocol` is implemented
///   - The tool writes content to files, creating parent dirs as needed
///   - POSIX path resolution against ToolContext.cwd works
/// TDD Phase: RED (feature not implemented yet)
final class FileWriteToolTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-FileWrite-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates the Write tool via the public factory function.
    private func makeWriteTool() -> ToolProtocol {
        return createWriteTool()
    }

    /// Calls the tool with a dictionary input and returns the ToolResult.
    private func callTool(
        _ tool: ToolProtocol,
        input: [String: Any],
        cwd: String? = nil
    ) async -> ToolResult {
        let context = ToolContext(
            cwd: cwd ?? tempDir,
            toolUseId: "test-\(UUID().uuidString)"
        )
        return await tool.call(input: input, context: context)
    }

    // MARK: - AC4: Write tool creates a new file

    /// AC4 [P0]: Writing to a new file path creates the file with the given content.
    func testWriteFile_createsNewFile() async {
        // Given: a path to a new file
        let filePath = (tempDir! as NSString).appendingPathComponent("newfile.txt")
        let tool = makeWriteTool()

        // When: writing content
        let result = await callTool(
            tool,
            input: ["file_path": filePath, "content": "hello world"]
        )

        // Then: the file exists with the correct content
        XCTAssertFalse(result.isError,
                       "Write should succeed, got: \(result.content)")
        let readContent = try? String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(readContent, "hello world",
                       "File should contain the written content")
    }

    // MARK: - AC4: Write tool overwrites existing file

    /// AC4 [P0]: Writing to an existing file overwrites its content.
    func testWriteFile_overwritesExistingFile() async {
        // Given: an existing file with initial content
        let filePath = (tempDir! as NSString).appendingPathComponent("existing.txt")
        try! "old content".write(toFile: filePath, atomically: true, encoding: .utf8)
        let tool = makeWriteTool()

        // When: writing new content
        let result = await callTool(
            tool,
            input: ["file_path": filePath, "content": "new content"]
        )

        // Then: file is overwritten
        XCTAssertFalse(result.isError,
                       "Overwrite should succeed, got: \(result.content)")
        let readContent = try? String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(readContent, "new content",
                       "File should contain the new content")
        XCTAssertNotEqual(readContent, "old content",
                          "File should not contain the old content")
    }

    // MARK: - AC4: Write tool creates parent directories

    /// AC4 [P0]: Writing to a path with non-existent parent dirs creates them.
    func testWriteFile_createsParentDirectories() async {
        // Given: a path with two levels of non-existent directories
        let filePath = (tempDir! as NSString)
            .appendingPathComponent("deep/nested/dir/file.txt")
        let tool = makeWriteTool()

        // When: writing content
        let result = await callTool(
            tool,
            input: ["file_path": filePath, "content": "deeply nested"]
        )

        // Then: file and all parent directories are created
        XCTAssertFalse(result.isError,
                       "Write with parent dir creation should succeed, got: \(result.content)")
        let readContent = try? String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(readContent, "deeply nested",
                       "File should contain the written content")
    }

    // MARK: - AC7: POSIX path resolution

    /// AC7 [P0]: Relative paths are resolved against ToolContext.cwd.
    func testWriteFile_relativePath_resolvesAgainstCwd() async {
        // Given: a relative path and cwd
        let tool = makeWriteTool()

        // When: writing with a relative path
        let result = await callTool(
            tool,
            input: ["file_path": "relative.txt", "content": "relative write"],
            cwd: tempDir
        )

        // Then: file is created at cwd + relative path
        XCTAssertFalse(result.isError,
                       "Relative path write should succeed, got: \(result.content)")
        let absolutePath = (tempDir! as NSString).appendingPathComponent("relative.txt")
        let readContent = try? String(contentsOfFile: absolutePath, encoding: .utf8)
        XCTAssertEqual(readContent, "relative write",
                       "File should be created at resolved absolute path")
    }

    // MARK: - AC4: Write tool handles invalid paths

    /// AC4 [P1]: Writing to an invalid/unwritable path returns an error.
    func testWriteFile_invalidPath_returnsError() async {
        // Given: an unwritable path (root-level directory as file)
        let invalidPath = "/cannot_write_here_\(UUID().uuidString).txt"
        let tool = makeWriteTool()

        // When: writing to the invalid path
        let result = await callTool(
            tool,
            input: ["file_path": invalidPath, "content": "should fail"]
        )

        // Then: returns error
        XCTAssertTrue(result.isError,
                      "Writing to invalid path should return isError=true, got: \(result.content)")
    }

    // MARK: - Write tool properties

    /// AC8 [P1]: Write tool should NOT be marked as isReadOnly.
    func testWriteTool_isNotReadOnly() {
        let tool = makeWriteTool()
        XCTAssertFalse(tool.isReadOnly,
                       "Write tool should NOT be marked as read-only")
    }

    /// AC8 [P0]: Write tool should have the correct name.
    func testWriteTool_hasCorrectName() {
        let tool = makeWriteTool()
        XCTAssertEqual(tool.name, "Write",
                       "Write tool should be named 'Write'")
    }

    /// AC8 [P0]: Write tool should have file_path and content in required schema fields.
    func testWriteTool_hasRequiredFieldsInSchema() {
        let tool = makeWriteTool()
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required,
                        "inputSchema should have 'required' array")
        XCTAssertTrue(required!.contains("file_path"),
                      "'file_path' should be in required fields")
        XCTAssertTrue(required!.contains("content"),
                      "'content' should be in required fields")
    }
}

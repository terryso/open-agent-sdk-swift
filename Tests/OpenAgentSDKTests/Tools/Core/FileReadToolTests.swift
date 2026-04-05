import XCTest
@testable import OpenAgentSDK

// MARK: - FileReadTool ATDD Tests (Story 3.4)

/// ATDD RED PHASE: Tests for Story 3.4 — FileReadTool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Sources/OpenAgentSDK/Tools/Core/FileReadTool.swift` is created
///   - `createReadTool() -> ToolProtocol` is implemented
///   - The tool reads files with line-numbered output (cat -n style)
///   - Directory detection, image file detection, and pagination are implemented
///   - POSIX path resolution against ToolContext.cwd works
/// TDD Phase: RED (feature not implemented yet)
final class FileReadToolTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-FileRead-\(UUID().uuidString)")
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

    /// Creates the Read tool via the public factory function.
    private func makeReadTool() -> ToolProtocol {
        return createReadTool()
    }

    /// Writes a test file and returns its path.
    @discardableResult
    private func writeTestFile(name: String, content: String) -> String {
        let path = (tempDir as NSString).appendingPathComponent(name)
        try! content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
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

    // MARK: - AC1: Read tool reads file content with line numbers

    /// AC1 [P0]: Reading a valid text file returns content with line numbers.
    func testReadFile_returnsContentWithLineNumbers() async {
        // Given: a file with known content
        let content = "line one\nline two\nline three"
        let filePath = writeTestFile(name: "sample.txt", content: content)
        let tool = makeReadTool()

        // When: reading the file
        let result = await callTool(tool, input: ["file_path": filePath])

        // Then: content is returned with line numbers (tab-separated)
        XCTAssertFalse(result.isError,
                       "Reading a valid file should not return an error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("1\t"),
                      "Output should contain line number 1")
        XCTAssertTrue(result.content.contains("line one"),
                      "Output should contain the file content")
        XCTAssertTrue(result.content.contains("2\t"),
                      "Output should contain line number 2")
        XCTAssertTrue(result.content.contains("line two"),
                      "Output should contain second line content")
    }

    // MARK: - AC2: Read tool handles directories

    /// AC2 [P0]: Reading a directory path returns an error suggesting Bash ls.
    func testReadFile_directory_returnsError() async {
        // Given: the temp directory itself (not a file)
        let tool = makeReadTool()

        // When: reading a directory
        let result = await callTool(tool, input: ["file_path": tempDir!])

        // Then: error with message about using ls
        XCTAssertTrue(result.isError,
                      "Reading a directory should return isError=true")
        XCTAssertTrue(
            result.content.lowercased().contains("directory") ||
            result.content.lowercased().contains("is a dir"),
            "Error should mention directory, got: \(result.content)"
        )
    }

    // MARK: - AC2: Read tool handles image files

    /// AC2 [P1]: Reading an image file returns a descriptive message, not binary.
    func testReadFile_imageFile_returnsDescription() async {
        // Given: a file with .png extension
        let filePath = writeTestFile(name: "photo.png", content: "fake-image-data")

        let tool = makeReadTool()

        // When: reading the image file
        let result = await callTool(tool, input: ["file_path": filePath])

        // Then: returns descriptive message, not raw content
        XCTAssertTrue(
            result.content.contains("Image") ||
            result.content.contains("image"),
            "Image file should return descriptive message, got: \(result.content)"
        )
        XCTAssertFalse(result.content.contains("fake-image-data"),
                       "Should not return raw binary content")
    }

    /// AC2 [P1]: Reading a .jpg file returns a descriptive message.
    func testReadFile_jpgFile_returnsDescription() async {
        // Given: a file with .jpg extension
        let filePath = writeTestFile(name: "photo.jpg", content: "fake-jpg-data")
        let tool = makeReadTool()

        // When: reading the jpg file
        let result = await callTool(tool, input: ["file_path": filePath])

        // Then: returns descriptive message
        XCTAssertTrue(
            result.content.contains("Image") ||
            result.content.contains("image"),
            "JPG file should return descriptive message, got: \(result.content)"
        )
    }

    // MARK: - AC3: Read tool supports pagination (offset/limit)

    /// AC3 [P0]: Reading with offset and limit returns only the specified range.
    func testReadFile_withOffsetAndLimit_returnsPartialContent() async {
        // Given: a file with 10 lines
        let lines = (1...10).map { "line \($0)" }.joined(separator: "\n")
        let filePath = writeTestFile(name: "paginated.txt", content: lines)
        let tool = makeReadTool()

        // When: reading with offset=2 and limit=3
        let result = await callTool(
            tool,
            input: ["file_path": filePath, "offset": 2, "limit": 3]
        )

        // Then: only lines 3-5 are returned (0-based offset)
        XCTAssertFalse(result.isError,
                       "Paginated read should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("line 3"),
                      "Should contain line 3 (offset=2, 0-based)")
        XCTAssertTrue(result.content.contains("line 4"),
                      "Should contain line 4")
        XCTAssertTrue(result.content.contains("line 5"),
                      "Should contain line 5")
        XCTAssertFalse(result.content.contains("line 1"),
                       "Should not contain line 1 (before offset)")
        XCTAssertFalse(result.content.contains("line 6"),
                       "Should not contain line 6 (after limit)")
    }

    /// AC3 [P1]: Default limit is 2000 lines when not specified.
    func testReadFile_defaultLimit_2000() async {
        // Given: a file with more than 2000 lines
        let lines = (1...2500).map { "line \($0)" }.joined(separator: "\n")
        let filePath = writeTestFile(name: "longfile.txt", content: lines)
        let tool = makeReadTool()

        // When: reading without limit
        let result = await callTool(
            tool,
            input: ["file_path": filePath]
        )

        // Then: at most 2000 lines returned
        XCTAssertFalse(result.isError,
                       "Read should not error, got: \(result.content)")
        // The output should NOT contain line 2001 (0-based offset default 0, limit default 2000)
        XCTAssertFalse(result.content.contains("line 2001"),
                       "Default limit of 2000 should cut off after 2000 lines")
    }

    // MARK: - AC1: Read tool handles non-existent files

    /// AC1 [P0]: Reading a non-existent file returns an error.
    func testReadFile_nonExistentFile_returnsError() async {
        // Given: a path to a file that does not exist
        let nonExistentPath = (tempDir! as NSString).appendingPathComponent("no_such_file.txt")
        let tool = makeReadTool()

        // When: reading the non-existent file
        let result = await callTool(tool, input: ["file_path": nonExistentPath])

        // Then: returns error
        XCTAssertTrue(result.isError,
                      "Reading non-existent file should return isError=true")
    }

    // MARK: - AC7: POSIX path resolution

    /// AC7 [P0]: Relative paths are resolved against ToolContext.cwd.
    func testReadFile_relativePath_resolvesAgainstCwd() async {
        // Given: a file in a subdirectory
        let subDir = (tempDir! as NSString).appendingPathComponent("subdir")
        try! FileManager.default.createDirectory(
            atPath: subDir,
            withIntermediateDirectories: true
        )
        let filePath = (subDir as NSString).appendingPathComponent("rel.txt")
        try! "relative content".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = makeReadTool()

        // When: reading with a relative path and cwd set to tempDir
        let result = await callTool(
            tool,
            input: ["file_path": "subdir/rel.txt"],
            cwd: tempDir
        )

        // Then: file is found and read correctly
        XCTAssertFalse(result.isError,
                       "Relative path should resolve against cwd, got: \(result.content)")
        XCTAssertTrue(result.content.contains("relative content"),
                      "Should read the file content at relative path")
    }

    /// AC7 [P1]: Path with .. is resolved correctly.
    func testReadFile_pathWithDotDot_resolvesCorrectly() async {
        // Given: a file in tempDir
        writeTestFile(name: "dotdot.txt", content: "resolved content")
        let tool = makeReadTool()

        // When: reading with path containing ..
        let subDir = (tempDir! as NSString).appendingPathComponent("sub")
        let relativePath = "sub/../dotdot.txt"
        let result = await callTool(
            tool,
            input: ["file_path": relativePath],
            cwd: tempDir
        )

        // Then: file is found
        XCTAssertFalse(result.isError,
                       "Path with .. should resolve, got: \(result.content)")
        XCTAssertTrue(result.content.contains("resolved content"),
                      "Should read the file at resolved path")
    }

    // MARK: - Read tool is read-only

    /// AC8 [P1]: Read tool should be marked as isReadOnly.
    func testReadTool_isReadOnly() {
        let tool = makeReadTool()
        XCTAssertTrue(tool.isReadOnly,
                      "Read tool should be marked as read-only")
    }

    // MARK: - Read tool has correct name and schema

    /// AC8 [P0]: Read tool should have the correct name.
    func testReadTool_hasCorrectName() {
        let tool = makeReadTool()
        XCTAssertEqual(tool.name, "Read",
                       "Read tool should be named 'Read'")
    }

    /// AC8 [P0]: Read tool should have file_path in required schema fields.
    func testReadTool_hasFilepathInRequiredSchema() {
        let tool = makeReadTool()
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required,
                        "inputSchema should have 'required' array")
        XCTAssertTrue(required!.contains("file_path"),
                      "'file_path' should be in required fields")
    }
}

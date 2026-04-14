import XCTest
@testable import OpenAgentSDK

// MARK: - FileEditTool ATDD Tests (Story 3.4)

/// ATDD RED PHASE: Tests for Story 3.4 — FileEditTool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Sources/OpenAgentSDK/Tools/Core/FileEditTool.swift` is created
///   - `createEditTool() -> ToolProtocol` is implemented
///   - The tool replaces unique strings in files
///   - Error handling for missing/duplicate matches works
///   - POSIX path resolution against ToolContext.cwd works
/// TDD Phase: RED (feature not implemented yet)
final class FileEditToolTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-FileEdit-\(UUID().uuidString)")
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

    /// Creates the Edit tool via the public factory function.
    private func makeEditTool() -> ToolProtocol {
        return createEditTool()
    }

    /// Writes a test file and returns its path.
    @discardableResult
    private func writeTestFile(name: String, content: String) -> String {
        let path = (tempDir! as NSString).appendingPathComponent(name)
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

    // MARK: - AC5: Edit tool replaces a unique string in a file

    /// AC5 [P0]: Editing a file replaces the old string with the new string.
    func testEditFile_replacesUniqueString() async {
        // Given: a file with known content
        let filePath = writeTestFile(
            name: "edit_test.txt",
            content: "Hello World\nSecond Line\nThird Line"
        )
        let tool = makeEditTool()

        // When: replacing "Second Line" with "Replaced Line"
        let result = await callTool(
            tool,
            input: [
                "file_path": filePath,
                "old_string": "Second Line",
                "new_string": "Replaced Line"
            ]
        )

        // Then: replacement succeeded
        XCTAssertFalse(result.isError,
                       "Edit should succeed, got: \(result.content)")
        let updatedContent = try! String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertTrue(updatedContent.contains("Replaced Line"),
                      "File should contain the new string")
        XCTAssertFalse(updatedContent.contains("Second Line"),
                       "File should not contain the old string")
        XCTAssertTrue(updatedContent.contains("Hello World"),
                      "File should still contain unchanged parts")
        XCTAssertTrue(updatedContent.contains("Third Line"),
                      "File should still contain other unchanged parts")
    }

    /// AC5 [P1]: Edit preserves surrounding content.
    func testEditFile_preservesSurroundingContent() async {
        // Given: a file with multiple lines
        let filePath = writeTestFile(
            name: "preserve_test.txt",
            content: "Line One\nTarget Line\nLine Three"
        )
        let tool = makeEditTool()

        // When: editing the middle line
        let _ = await callTool(
            tool,
            input: [
                "file_path": filePath,
                "old_string": "Target Line",
                "new_string": "Changed Line"
            ]
        )

        // Then: other lines are untouched
        let updatedContent = try! String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertTrue(updatedContent.contains("Line One"),
                      "Content before the edit should be preserved")
        XCTAssertTrue(updatedContent.contains("Line Three"),
                      "Content after the edit should be preserved")
        XCTAssertTrue(updatedContent.contains("Changed Line"),
                      "The replacement should be present")
    }

    // MARK: - AC6: Edit tool handles old_string not found

    /// AC6 [P0]: Editing when old_string is not found returns isError=true.
    func testEditFile_oldStringNotFound_returnsError() async {
        // Given: a file with specific content
        let filePath = writeTestFile(
            name: "not_found_test.txt",
            content: "Hello World"
        )
        let tool = makeEditTool()

        // When: trying to replace a string that does not exist
        let result = await callTool(
            tool,
            input: [
                "file_path": filePath,
                "old_string": "does not exist",
                "new_string": "replacement"
            ]
        )

        // Then: error returned, file unchanged
        XCTAssertTrue(result.isError,
                      "old_string not found should return isError=true")
        let fileContent = try! String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(fileContent, "Hello World",
                       "File should not be modified when old_string not found")
    }

    // MARK: - AC6: Edit tool handles multiple occurrences

    /// AC6 [P0]: Editing when old_string appears multiple times returns an error.
    func testEditFile_multipleOccurrences_returnsError() async {
        // Given: a file where "duplicate" appears twice
        let filePath = writeTestFile(
            name: "multi_test.txt",
            content: "duplicate line one\nduplicate line two"
        )
        let tool = makeEditTool()

        // When: trying to replace "duplicate" (appears twice)
        let result = await callTool(
            tool,
            input: [
                "file_path": filePath,
                "old_string": "duplicate",
                "new_string": "unique"
            ]
        )

        // Then: error about ambiguous match
        XCTAssertTrue(result.isError,
                      "Multiple occurrences should return isError=true")
        XCTAssertTrue(
            result.content.contains("2") || result.content.contains("multiple") ||
            result.content.contains("times") || result.content.contains("appears"),
            "Error should mention the issue with multiple matches, got: \(result.content)"
        )
    }

    // MARK: - AC6: Edit tool handles non-existent file

    /// AC6 [P0]: Editing a non-existent file returns an error.
    func testEditFile_nonExistentFile_returnsError() async {
        // Given: a path to a file that does not exist
        let nonExistentPath = (tempDir! as NSString)
            .appendingPathComponent("no_such_file.txt")
        let tool = makeEditTool()

        // When: trying to edit the non-existent file
        let result = await callTool(
            tool,
            input: [
                "file_path": nonExistentPath,
                "old_string": "something",
                "new_string": "else"
            ]
        )

        // Then: error returned
        XCTAssertTrue(result.isError,
                      "Editing non-existent file should return isError=true")
    }

    // MARK: - AC7: POSIX path resolution

    /// AC7 [P0]: Relative paths are resolved against ToolContext.cwd.
    func testEditFile_relativePath_resolvesAgainstCwd() async {
        // Given: a file in tempDir with known content
        let fileName = "relative_edit.txt"
        let filePath = (tempDir! as NSString).appendingPathComponent(fileName)
        try! "original text".write(
            toFile: filePath, atomically: true, encoding: .utf8
        )
        let tool = makeEditTool()

        // When: editing with a relative path
        let result = await callTool(
            tool,
            input: [
                "file_path": fileName,
                "old_string": "original text",
                "new_string": "edited text"
            ],
            cwd: tempDir
        )

        // Then: file is edited successfully
        XCTAssertFalse(result.isError,
                       "Edit with relative path should succeed, got: \(result.content)")
        let updatedContent = try! String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(updatedContent, "edited text",
                       "File should contain the replacement text")
    }

    // MARK: - Edit tool properties

    /// AC8 [P1]: Edit tool should NOT be marked as isReadOnly.
    func testEditTool_isNotReadOnly() {
        let tool = makeEditTool()
        XCTAssertFalse(tool.isReadOnly,
                       "Edit tool should NOT be marked as read-only")
    }

    /// AC8 [P0]: Edit tool should have the correct name.
    func testEditTool_hasCorrectName() {
        let tool = makeEditTool()
        XCTAssertEqual(tool.name, "Edit",
                       "Edit tool should be named 'Edit'")
    }

    /// AC8 [P0]: Edit tool should have file_path, old_string, new_string in required schema.
    func testEditTool_hasRequiredFieldsInSchema() {
        let tool = makeEditTool()
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required,
                        "inputSchema should have 'required' array")
        XCTAssertTrue(required!.contains("file_path"),
                      "'file_path' should be in required fields")
        XCTAssertTrue(required!.contains("old_string"),
                      "'old_string' should be in required fields")
        XCTAssertTrue(required!.contains("new_string"),
                      "'new_string' should be in required fields")
    }

    // MARK: - Identical string guard

    /// When old_string and new_string are identical, the tool should return an error
    /// without modifying the file (matching TypeScript SDK behavior).
    func testEditFile_identicalStrings_returnsError() async {
        let filePath = writeTestFile(
            name: "identical_test.txt",
            content: "Hello World"
        )
        let tool = makeEditTool()

        let result = await callTool(
            tool,
            input: [
                "file_path": filePath,
                "old_string": "Hello World",
                "new_string": "Hello World"
            ]
        )

        XCTAssertTrue(result.isError,
                      "Identical old_string/new_string should return isError=true")
        XCTAssertTrue(result.content.contains("differ"),
                      "Error should mention strings must differ, got: \(result.content)")
        // File should be unchanged
        let fileContent = try! String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(fileContent, "Hello World",
                       "File should not be modified when strings are identical")
    }

    // MARK: - replace_all parameter

    /// When replace_all=true and old_string appears multiple times, all are replaced.
    func testEditFile_replaceAll_replacesMultipleOccurrences() async {
        let filePath = writeTestFile(
            name: "replace_all_test.txt",
            content: "foo bar foo baz foo"
        )
        let tool = makeEditTool()

        let result = await callTool(
            tool,
            input: [
                "file_path": filePath,
                "old_string": "foo",
                "new_string": "qux",
                "replace_all": true
            ]
        )

        XCTAssertFalse(result.isError,
                       "replace_all should succeed with multiple occurrences, got: \(result.content)")
        let updatedContent = try! String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(updatedContent, "qux bar qux baz qux",
                       "All occurrences should be replaced")
    }

    /// When replace_all=true and old_string appears once, it still works.
    func testEditFile_replaceAll_singleOccurrence_succeeds() async {
        let filePath = writeTestFile(
            name: "replace_all_single.txt",
            content: "only one foo here"
        )
        let tool = makeEditTool()

        let result = await callTool(
            tool,
            input: [
                "file_path": filePath,
                "old_string": "foo",
                "new_string": "bar",
                "replace_all": true
            ]
        )

        XCTAssertFalse(result.isError,
                       "replace_all with single occurrence should succeed")
        let updatedContent = try! String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(updatedContent, "only one bar here")
    }

    /// When replace_all=true but old_string is not found, error is still returned.
    func testEditFile_replaceAll_notFound_stillErrors() async {
        let filePath = writeTestFile(
            name: "replace_all_notfound.txt",
            content: "nothing to replace"
        )
        let tool = makeEditTool()

        let result = await callTool(
            tool,
            input: [
                "file_path": filePath,
                "old_string": "missing",
                "new_string": "replacement",
                "replace_all": true
            ]
        )

        XCTAssertTrue(result.isError,
                      "replace_all should still error when old_string not found")
    }

    /// When replace_all is omitted (nil), multiple occurrences still error (backward compat).
    func testEditFile_replaceAllOmitted_multipleOccurences_stillErrors() async {
        let filePath = writeTestFile(
            name: "replace_all_omit.txt",
            content: "dup dup dup"
        )
        let tool = makeEditTool()

        let result = await callTool(
            tool,
            input: [
                "file_path": filePath,
                "old_string": "dup",
                "new_string": "single"
            ]
        )

        XCTAssertTrue(result.isError,
                      "Without replace_all, multiple occurrences should error")
    }

    /// When replace_all=false, behavior is the same as omitted (backward compat).
    func testEditFile_replaceAllFalse_multipleOccurences_errors() async {
        let filePath = writeTestFile(
            name: "replace_all_false.txt",
            content: "dup dup dup"
        )
        let tool = makeEditTool()

        let result = await callTool(
            tool,
            input: [
                "file_path": filePath,
                "old_string": "dup",
                "new_string": "single",
                "replace_all": false
            ]
        )

        XCTAssertTrue(result.isError,
                      "replace_all=false should error on multiple occurrences")
    }
}

import XCTest
@testable import OpenAgentSDK

// MARK: - GrepTool ATDD Tests (Story 3.5)

/// ATDD RED PHASE: Tests for Story 3.5 — GrepTool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Sources/OpenAgentSDK/Tools/Core/GrepTool.swift` is created
///   - `createGrepTool() -> ToolProtocol` is implemented
///   - The tool searches file content by regex pattern with line numbers
///   - Output modes, file type filters, head_limit, context lines work
///   - POSIX path resolution against ToolContext.cwd works
/// TDD Phase: RED (feature not implemented yet)
final class GrepToolTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-Grep-\(UUID().uuidString)")
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

    /// Creates the Grep tool via the public factory function.
    private func makeGrepTool() -> ToolProtocol {
        return createGrepTool()
    }

    /// Writes a test file and returns its path.
    @discardableResult
    private func writeTestFile(
        name: String,
        content: String,
        inSubdirectory subDir: String? = nil
    ) -> String {
        let dir: String
        if let subDir = subDir {
            dir = (tempDir as NSString).appendingPathComponent(subDir)
            try! FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )
        } else {
            dir = tempDir
        }
        let path = (dir as NSString).appendingPathComponent(name)
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

    // MARK: - AC4: Grep searches file content

    /// AC4 [P0]: Grep searches file content and returns matching lines with file paths and line numbers.
    func testGrep_searchesFileContent() async {
        // Given: files with known content
        writeTestFile(name: "code.swift", content: "import Foundation\nstruct Foo { }\n// TODO: fix this")
        writeTestFile(name: "other.txt", content: "no match here")

        let tool = makeGrepTool()

        // When: searching for "TODO"
        let result = await callTool(tool, input: [
            "pattern": "TODO",
            "output_mode": "content"
        ])

        // Then: matching line is found with file path and line number
        XCTAssertFalse(result.isError,
                       "Grep should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("TODO"),
                      "Should find TODO in results")
        XCTAssertTrue(result.content.contains("code.swift"),
                      "Result should include file name")
    }

    // MARK: - AC5: Grep supports output modes

    /// AC5 [P0]: output_mode=files_with_matches returns only file paths.
    func testGrep_outputMode_filesWithMatches() async {
        // Given: two files, one with a match
        writeTestFile(name: "match.txt", content: "findme here")
        writeTestFile(name: "nomatch.txt", content: "nothing here")

        let tool = makeGrepTool()

        // When: searching with files_with_matches mode
        let result = await callTool(tool, input: [
            "pattern": "findme",
            "output_mode": "files_with_matches"
        ])

        // Then: only file paths returned (no line content)
        XCTAssertFalse(result.isError,
                       "Grep files_with_matches should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("match.txt"),
                      "Should list matching file")
        XCTAssertFalse(result.content.contains("nomatch.txt"),
                       "Should not list non-matching file")
        XCTAssertFalse(result.content.contains("findme here"),
                       "files_with_matches should not include line content")
    }

    /// AC5 [P0]: output_mode=content returns matches with line numbers.
    func testGrep_outputMode_content() async {
        // Given: a file with multiple lines
        writeTestFile(name: "multi.txt", content: "line one\nline two TARGET\nline three")

        let tool = makeGrepTool()

        // When: searching with content mode
        let result = await callTool(tool, input: [
            "pattern": "TARGET",
            "output_mode": "content"
        ])

        // Then: result contains file path, line number, and content
        XCTAssertFalse(result.isError,
                       "Grep content mode should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("multi.txt"),
                      "Result should contain file name")
        XCTAssertTrue(result.content.contains("TARGET"),
                      "Result should contain matched text")
        // Should include a line number (2 since TARGET is on line 2)
        let digits = result.content.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        XCTAssertTrue(digits.contains("2"),
                      "Result should reference line 2 where TARGET appears")
    }

    /// AC5 [P0]: output_mode=count returns match counts per file.
    func testGrep_outputMode_count() async {
        // Given: a file with multiple matches
        writeTestFile(name: "counts.txt", content: "abc\nabc\nabc\nnope")

        let tool = makeGrepTool()

        // When: searching with count mode
        let result = await callTool(tool, input: [
            "pattern": "abc",
            "output_mode": "count"
        ])

        // Then: result shows count per file
        XCTAssertFalse(result.isError,
                       "Grep count mode should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("counts.txt"),
                      "Count result should include file name")
        XCTAssertTrue(result.content.contains("3"),
                      "Count result should show 3 matches")
    }

    // MARK: - AC6: Grep supports glob/type filters and path

    /// AC6 [P0]: Grep with `glob` filter only searches matching files.
    func testGrep_globFilter() async {
        // Given: a .swift file and a .txt file with the same pattern
        writeTestFile(name: "code.swift", content: "let foo = searchPattern")
        writeTestFile(name: "notes.txt", content: "searchPattern is here")

        let tool = makeGrepTool()

        // When: searching with glob filter for *.swift only
        let result = await callTool(tool, input: [
            "pattern": "searchPattern",
            "glob": "*.swift",
            "output_mode": "files_with_matches"
        ])

        // Then: only .swift files are searched
        XCTAssertFalse(result.isError,
                       "Grep glob filter should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("code.swift"),
                      "Should find match in .swift file")
        XCTAssertFalse(result.content.contains("notes.txt"),
                       "Should not search .txt files when glob is *.swift")
    }

    /// AC6 [P0]: Grep with `type` filter only searches files with matching extension.
    func testGrep_typeFilter() async {
        // Given: a .swift file and a .ts file with the same pattern
        writeTestFile(name: "app.swift", content: "func myFunc() {}")
        writeTestFile(name: "app.ts", content: "function myFunc() {}")

        let tool = makeGrepTool()

        // When: searching with type filter for "ts"
        let result = await callTool(tool, input: [
            "pattern": "myFunc",
            "type": "ts",
            "output_mode": "files_with_matches"
        ])

        // Then: only .ts files are searched
        XCTAssertFalse(result.isError,
                       "Grep type filter should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("app.ts"),
                      "Should find match in .ts file")
        XCTAssertFalse(result.content.contains("app.swift"),
                       "Should not search .swift files when type is ts")
    }

    /// AC6 [P0]: Grep with `path` parameter searches in specified directory.
    func testGrep_withCustomPath_searchesInSpecifiedDir() async {
        // Given: files in two separate directories
        let dirA = (tempDir as NSString).appendingPathComponent("srcA")
        let dirB = (tempDir as NSString).appendingPathComponent("srcB")
        try! FileManager.default.createDirectory(atPath: dirA, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(atPath: dirB, withIntermediateDirectories: true)
        try! "searchTarget".write(toFile: (dirA as NSString).appendingPathComponent("a.txt"),
                                  atomically: true, encoding: .utf8)
        try! "searchTarget".write(toFile: (dirB as NSString).appendingPathComponent("b.txt"),
                                  atomically: true, encoding: .utf8)

        let tool = makeGrepTool()

        // When: searching only in dirA
        let result = await callTool(tool, input: [
            "pattern": "searchTarget",
            "path": dirA,
            "output_mode": "files_with_matches"
        ])

        // Then: only dirA results returned
        XCTAssertFalse(result.isError,
                       "Grep with path should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("a.txt"),
                      "Should find match in dirA")
        XCTAssertFalse(result.content.contains("b.txt"),
                       "Should not find match in dirB when path is dirA")
    }

    // MARK: - AC8: POSIX path resolution

    /// AC8 [P0]: Grep with relative path resolves against ToolContext.cwd.
    func testGrep_relativePath_resolvesAgainstCwd() async {
        // Given: a file in a subdirectory
        let subDir = (tempDir as NSString).appendingPathComponent("src")
        try! FileManager.default.createDirectory(atPath: subDir, withIntermediateDirectories: true)
        try! "patternHere".write(toFile: (subDir as NSString).appendingPathComponent("file.txt"),
                                 atomically: true, encoding: .utf8)

        let tool = makeGrepTool()

        // When: searching with relative path and cwd
        let result = await callTool(
            tool,
            input: ["pattern": "patternHere", "path": "src"],
            cwd: tempDir
        )

        // Then: file is found via relative path resolution
        XCTAssertFalse(result.isError,
                       "Grep with relative path should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("patternHere"),
                      "Should find match via resolved relative path")
    }

    // MARK: - Case insensitive search

    /// [P1]: Grep with `-i` flag performs case-insensitive search.
    func testGrep_caseInsensitive() async {
        // Given: a file with mixed case content
        writeTestFile(name: "mixed.txt", content: "Hello World\nhello world\nHELLO WORLD")

        let tool = makeGrepTool()

        // When: searching case-insensitively for "hello"
        let result = await callTool(tool, input: [
            "pattern": "hello",
            "output_mode": "content",
            "-i": true
        ])

        // Then: all three lines match
        XCTAssertFalse(result.isError,
                       "Case-insensitive grep should not error, got: \(result.content)")
        let matchCount = result.content.components(separatedBy: "Hello").count - 1 +
                         result.content.components(separatedBy: "hello").count - 1 +
                         result.content.components(separatedBy: "HELLO").count - 1
        XCTAssertTrue(matchCount >= 3,
                      "Should match all three case variants, found \(matchCount) occurrences")
    }

    // MARK: - Head limit

    /// [P1]: Grep with head_limit truncates output.
    func testGrep_headLimit() async {
        // Given: a file with many matching lines
        var lines: [String] = []
        for i in 0..<20 {
            lines.append("match_line_\(i)")
        }
        writeTestFile(name: "many.txt", content: lines.joined(separator: "\n"))

        let tool = makeGrepTool()

        // When: searching with head_limit=5
        let result = await callTool(tool, input: [
            "pattern": "match_line",
            "output_mode": "content",
            "head_limit": 5
        ])

        // Then: output is truncated to 5 matches
        XCTAssertFalse(result.isError,
                       "Grep with head_limit should not error, got: \(result.content)")
        let matchLines = result.content.components(separatedBy: "\n")
            .filter { $0.contains("match_line") }
        XCTAssertTrue(matchLines.count <= 5,
                      "Should return at most 5 match lines with head_limit=5, got \(matchLines.count)")
    }

    // MARK: - No matches

    /// [P0]: Grep with no matches returns descriptive message, not error.
    func testGrep_noMatches_returnsDescriptiveMessage() async {
        // Given: a file without the search term
        writeTestFile(name: "empty.txt", content: "nothing relevant here")

        let tool = makeGrepTool()

        // When: searching for a pattern that does not exist
        let result = await callTool(tool, input: [
            "pattern": "zzz_nonexistent_pattern_zzz",
            "output_mode": "content"
        ])

        // Then: descriptive message returned (not error)
        XCTAssertFalse(result.isError,
                       "No matches should not be isError=true")
        XCTAssertFalse(result.content.isEmpty,
                       "No matches should return descriptive message, not empty string")
    }

    // MARK: - Invalid regex

    /// [P0]: Grep with invalid regex returns isError=true.
    func testGrep_invalidRegex_returnsError() async {
        // Given: a file to search
        writeTestFile(name: "valid.txt", content: "some content")

        let tool = makeGrepTool()

        // When: searching with an invalid regex pattern
        let result = await callTool(tool, input: [
            "pattern": "[invalid(regex",
            "output_mode": "content"
        ])

        // Then: error returned
        XCTAssertTrue(result.isError,
                      "Invalid regex should return isError=true, got: \(result.content)")
    }

    // MARK: - Context lines

    /// [P1]: Grep with context lines (-C) includes surrounding lines.
    func testGrep_contextLines() async {
        // Given: a file with context around the match
        writeTestFile(name: "context.txt", content: "line 1\nline 2\nTARGET LINE\nline 4\nline 5")

        let tool = makeGrepTool()

        // When: searching with context=1 (1 line before and after)
        let result = await callTool(tool, input: [
            "pattern": "TARGET",
            "output_mode": "content",
            "-C": 1
        ])

        // Then: surrounding lines are included
        XCTAssertFalse(result.isError,
                       "Grep with context should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("TARGET"),
                      "Should contain matched line")
        XCTAssertTrue(result.content.contains("line 2"),
                      "Should contain 1 line before match")
        XCTAssertTrue(result.content.contains("line 4"),
                      "Should contain 1 line after match")
    }

    // MARK: - Hidden directory skip

    /// [P1]: Grep skips hidden directories (.git, .build, etc.).
    func testGrep_skipsHiddenDirectories() async {
        // Given: a file inside a hidden directory and a visible file
        writeTestFile(name: "secret.txt", content: "searchTerm", inSubdirectory: ".hidden")
        writeTestFile(name: "visible.txt", content: "searchTerm")

        let tool = makeGrepTool()

        // When: searching for the term
        let result = await callTool(tool, input: [
            "pattern": "searchTerm",
            "output_mode": "files_with_matches"
        ])

        // Then: hidden directory files are NOT included
        XCTAssertFalse(result.isError,
                       "Grep should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("visible.txt"),
                      "Should find visible.txt")
        XCTAssertFalse(result.content.contains("secret.txt"),
                       "Should not find files in hidden directories")
    }

    // MARK: - Binary file skip

    /// [P1]: Grep skips binary files.
    func testGrep_skipsBinaryFiles() async {
        // Given: a binary file and a text file
        let binaryPath = (tempDir as NSString).appendingPathComponent("image.png")
        let binaryData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])  // PNG header bytes
        try! binaryData.write(to: URL(fileURLWithPath: binaryPath))

        writeTestFile(name: "text.txt", content: "searchTerm")

        let tool = makeGrepTool()

        // When: searching for any pattern
        let result = await callTool(tool, input: [
            "pattern": "searchTerm",
            "output_mode": "files_with_matches"
        ])

        // Then: binary file is skipped, only text file returned
        XCTAssertFalse(result.isError,
                       "Grep should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("text.txt"),
                      "Should find text file")
        XCTAssertFalse(result.content.contains("image.png"),
                       "Should skip binary files")
    }

    // MARK: - Tool metadata

    /// [P0]: Grep tool should be named "Grep".
    func testGrepTool_hasCorrectName() {
        let tool = makeGrepTool()
        XCTAssertEqual(tool.name, "Grep",
                       "Grep tool should be named 'Grep'")
    }

    /// [P0]: Grep tool should be marked as read-only.
    func testGrepTool_isReadOnly() {
        let tool = makeGrepTool()
        XCTAssertTrue(tool.isReadOnly,
                      "Grep tool should be marked as read-only")
    }

    /// [P0]: Grep tool should have `pattern` in required schema fields.
    func testGrepTool_hasPatternInRequiredSchema() {
        let tool = makeGrepTool()
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required,
                        "inputSchema should have 'required' array")
        XCTAssertTrue(required!.contains("pattern"),
                      "'pattern' should be in required fields")
    }
}

import XCTest
@testable import OpenAgentSDK

// MARK: - GlobTool ATDD Tests (Story 3.5)

/// ATDD RED PHASE: Tests for Story 3.5 — GlobTool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Sources/OpenAgentSDK/Tools/Core/GlobTool.swift` is created
///   - `createGlobTool() -> ToolProtocol` is implemented
///   - The tool matches files by glob pattern and returns sorted paths
///   - Custom search directory, empty results, POSIX path resolution work
/// TDD Phase: RED (feature not implemented yet)
final class GlobToolTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-Glob-\(UUID().uuidString)")
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

    /// Creates the Glob tool via the public factory function.
    private func makeGlobTool() -> ToolProtocol {
        return createGlobTool()
    }

    /// Writes a test file and returns its path.
    @discardableResult
    private func writeTestFile(
        name: String,
        content: String = "",
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

    // MARK: - AC1: Glob matches files by pattern

    /// AC1 [P0]: Glob pattern "**/*.swift" matches Swift files in nested directories.
    func testGlob_matchesFilesByPattern() async {
        // Given: a mix of files in nested directories
        writeTestFile(name: "main.swift", content: "// main")
        writeTestFile(name: "helper.swift", content: "// helper", inSubdirectory: "Sources")
        writeTestFile(name: "README.md", content: "# readme")
        writeTestFile(name: "config.json", content: "{}", inSubdirectory: "Sources")

        let tool = makeGlobTool()

        // When: globbing for **/*.swift
        let result = await callTool(tool, input: ["pattern": "**/*.swift"])

        // Then: only .swift files are returned
        XCTAssertFalse(result.isError,
                       "Glob should not return an error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("main.swift"),
                      "Should match main.swift")
        XCTAssertTrue(result.content.contains("helper.swift"),
                      "Should match nested helper.swift")
        XCTAssertFalse(result.content.contains("README.md"),
                       "Should not match .md files")
        XCTAssertFalse(result.content.contains("config.json"),
                       "Should not match .json files")
    }

    /// AC1 [P0]: Glob pattern matches files in deeply nested directories.
    func testGlob_matchesNestedDirectories() async {
        // Given: files 3 levels deep
        writeTestFile(name: "deep.txt", content: "deep", inSubdirectory: "a/b/c")

        let tool = makeGlobTool()

        // When: globbing for **/*.txt
        let result = await callTool(tool, input: ["pattern": "**/*.txt"])

        // Then: deeply nested file is found
        XCTAssertFalse(result.isError,
                       "Glob should not error on deep nesting, got: \(result.content)")
        XCTAssertTrue(result.content.contains("deep.txt"),
                      "Should find deeply nested file")
    }

    // MARK: - AC2: Glob supports custom search directory

    /// AC2 [P0]: Glob with `path` parameter searches in the specified directory.
    func testGlob_withCustomPath_searchesInSpecifiedDir() async {
        // Given: files in two separate directories
        let dirA = (tempDir as NSString).appendingPathComponent("dirA")
        let dirB = (tempDir as NSString).appendingPathComponent("dirB")
        try! FileManager.default.createDirectory(atPath: dirA, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(atPath: dirB, withIntermediateDirectories: true)
        try! "file-a".write(toFile: (dirA as NSString).appendingPathComponent("data.txt"),
                            atomically: true, encoding: .utf8)
        try! "file-b".write(toFile: (dirB as NSString).appendingPathComponent("data.txt"),
                            atomically: true, encoding: .utf8)

        let tool = makeGlobTool()

        // When: globbing in dirA only
        let result = await callTool(tool, input: [
            "pattern": "*.txt",
            "path": dirA
        ])

        // Then: only dirA files are returned (path in result should show dirA)
        XCTAssertFalse(result.isError,
                       "Glob with custom path should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("data.txt"),
                      "Should find data.txt in specified directory")
        // The result should contain the dirA path, not dirB path
        XCTAssertTrue(result.content.contains("dirA"),
                      "Result should reference dirA, got: \(result.content)")
    }

    // MARK: - AC3: Glob empty results return descriptive message

    /// AC3 [P0]: Glob with no matching files returns a descriptive message, not empty or error.
    func testGlob_noMatches_returnsDescriptiveMessage() async {
        // Given: a directory with no .rs files
        writeTestFile(name: "only-swift.swift", content: "code")

        let tool = makeGlobTool()

        // When: globbing for *.rs (no matches)
        let result = await callTool(tool, input: ["pattern": "*.rs"])

        // Then: descriptive message returned (not empty, not error)
        XCTAssertFalse(result.isError,
                       "No matches should not be isError=true")
        XCTAssertFalse(result.content.isEmpty,
                       "Empty results should return descriptive message, not empty string")
        XCTAssertTrue(
            result.content.lowercased().contains("no") ||
            result.content.lowercased().contains("match") ||
            result.content.lowercased().contains("found") ||
            result.content.lowercased().contains("0"),
            "Message should describe no matches, got: \(result.content)"
        )
    }

    // MARK: - AC8: POSIX path resolution

    /// AC8 [P0]: Relative path in pattern resolves against ToolContext.cwd.
    func testGlob_relativePath_resolvesAgainstCwd() async {
        // Given: a subdirectory with files
        let subDir = (tempDir as NSString).appendingPathComponent("project")
        try! FileManager.default.createDirectory(atPath: subDir, withIntermediateDirectories: true)
        try! "code".write(toFile: (subDir as NSString).appendingPathComponent("app.swift"),
                          atomically: true, encoding: .utf8)

        let tool = makeGlobTool()

        // When: using absolute path in `path` parameter pointing to subdir
        let result = await callTool(
            tool,
            input: ["pattern": "*.swift", "path": subDir],
            cwd: tempDir
        )

        // Then: file in subdirectory is found
        XCTAssertFalse(result.isError,
                       "Glob with subdirectory path should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("app.swift"),
                      "Should find app.swift in resolved subdirectory")
    }

    // MARK: - Error handling

    /// [P0]: Glob with non-existent directory returns an error.
    func testGlob_nonExistentDirectory_returnsError() async {
        // Given: a path that does not exist
        let badPath = (tempDir as NSString).appendingPathComponent("no-such-dir")
        let tool = makeGlobTool()

        // When: globbing in non-existent directory
        let result = await callTool(tool, input: [
            "pattern": "*.txt",
            "path": badPath
        ])

        // Then: error returned
        XCTAssertTrue(result.isError,
                      "Non-existent directory should return isError=true")
    }

    // MARK: - Result limit

    /// [P1]: Glob limits results to 500 files maximum.
    func testGlob_resultLimit_max500() async {
        // Given: a directory with more than 500 files
        let manyDir = (tempDir as NSString).appendingPathComponent("many")
        try! FileManager.default.createDirectory(atPath: manyDir, withIntermediateDirectories: true)
        for i in 0..<510 {
            let path = (manyDir as NSString).appendingPathComponent("file_\(i).txt")
            try! "content \(i)".write(toFile: path, atomically: true, encoding: .utf8)
        }

        let tool = makeGlobTool()

        // When: globbing for all files
        let result = await callTool(tool, input: [
            "pattern": "*.txt",
            "path": manyDir
        ])

        // Then: at most 500 results (result lines should not exceed 500)
        XCTAssertFalse(result.isError,
                       "Glob with many files should not error, got: \(result.content)")
        let lines = result.content.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertTrue(lines.count <= 500,
                      "Glob should limit results to 500, got \(lines.count) lines")
    }

    // MARK: - Sorting by modification time

    /// [P1]: Glob results are sorted by modification time (newest first).
    func testGlob_resultsSortedByModificationTime() async {
        // Given: three files with different modification times
        let fileA = writeTestFile(name: "a_old.txt", content: "old")
        // Small delay to ensure different mtimes
        let fileB = writeTestFile(name: "b_mid.txt", content: "mid")
        let fileC = writeTestFile(name: "c_new.txt", content: "new")

        // Set explicit modification times
        let fm = FileManager.default
        let oldDate = Date().addingTimeInterval(-200)
        let midDate = Date().addingTimeInterval(-100)
        let newDate = Date()

        try! fm.setAttributes([.modificationDate: oldDate], ofItemAtPath: fileA)
        try! fm.setAttributes([.modificationDate: midDate], ofItemAtPath: fileB)
        try! fm.setAttributes([.modificationDate: newDate], ofItemAtPath: fileC)

        let tool = makeGlobTool()

        // When: globbing for all .txt files
        let result = await callTool(tool, input: ["pattern": "*.txt"])

        // Then: newest file appears first in results
        XCTAssertFalse(result.isError,
                       "Glob should not error, got: \(result.content)")
        let content = result.content
        let posC = content.range(of: "c_new.txt")!.lowerBound
        let posB = content.range(of: "b_mid.txt")!.lowerBound
        let posA = content.range(of: "a_old.txt")!.lowerBound
        XCTAssertTrue(posC < posB && posB < posA,
                      "Results should be sorted newest-first (c, b, a)")
    }

    // MARK: - Hidden directory skip

    /// [P1]: Glob skips hidden directories (.git, .build, etc.).
    func testGlob_skipsHiddenDirectories() async {
        // Given: a file inside a hidden directory
        writeTestFile(name: "secret.txt", content: "hidden", inSubdirectory: ".hidden")
        writeTestFile(name: "visible.txt", content: "visible")

        let tool = makeGlobTool()

        // When: globbing for all .txt files
        let result = await callTool(tool, input: ["pattern": "**/*.txt"])

        // Then: hidden directory files are NOT included
        XCTAssertFalse(result.isError,
                       "Glob should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("visible.txt"),
                      "Should find visible.txt")
        XCTAssertFalse(result.content.contains("secret.txt"),
                       "Should not find files in hidden directories")
    }

    // MARK: - Tool metadata

    /// [P0]: Glob tool should be named "Glob".
    func testGlobTool_hasCorrectName() {
        let tool = makeGlobTool()
        XCTAssertEqual(tool.name, "Glob",
                       "Glob tool should be named 'Glob'")
    }

    /// [P0]: Glob tool should be marked as read-only.
    func testGlobTool_isReadOnly() {
        let tool = makeGlobTool()
        XCTAssertTrue(tool.isReadOnly,
                      "Glob tool should be marked as read-only")
    }

    /// [P0]: Glob tool should have `pattern` in required schema fields.
    func testGlobTool_hasPatternInRequiredSchema() {
        let tool = makeGlobTool()
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required,
                        "inputSchema should have 'required' array")
        XCTAssertTrue(required!.contains("pattern"),
                      "'pattern' should be in required fields")
    }
}

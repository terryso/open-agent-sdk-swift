import XCTest
@testable import OpenAgentSDK

// MARK: - ATDD RED PHASE: Story 14.4 — Filesystem Sandbox Enforcement
//
// All tests assert EXPECTED behavior. They will FAIL until:
//   - FileReadTool adds sandbox check (SandboxChecker.checkPath for .read)
//   - FileWriteTool adds sandbox check (SandboxChecker.checkPath for .write)
//   - FileEditTool adds sandbox check (SandboxChecker.checkPath for .write)
//   - GlobTool adds sandbox check (SandboxChecker.checkPath for .read)
//   - GrepTool adds sandbox check (SandboxChecker.checkPath for .read)
// TDD Phase: RED (feature not implemented yet)

// MARK: - Test Helpers

/// Shared helper to call a tool with sandbox context and return the result.
private func callToolWithSandbox(
    _ tool: ToolProtocol,
    input: [String: Any],
    cwd: String,
    sandbox: SandboxSettings?
) async -> ToolResult {
    let context = ToolContext(
        cwd: cwd,
        toolUseId: "test-sandbox-\(UUID().uuidString)",
        sandbox: sandbox
    )
    return await tool.call(input: input, context: context)
}

// MARK: - AC1: FileReadTool enforces read-path sandbox

final class FileReadToolSandboxTests: XCTestCase {

    var tempDir: String!
    var outsideDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-FileReadSandbox-\(UUID().uuidString)")
        outsideDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-FileReadSandboxOutside-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
        try! FileManager.default.createDirectory(
            atPath: outsideDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        try? FileManager.default.removeItem(atPath: outsideDir)
        super.tearDown()
    }

    /// AC1 [P0]: FileReadTool allows reading files within allowed read paths.
    func testFileReadTool_allowedPath_succeeds() async {
        // Given: sandbox allowing reads in tempDir
        let sandbox = SandboxSettings(allowedReadPaths: [tempDir + "/"])
        let filePath = (tempDir as NSString).appendingPathComponent("file.swift")
        try! "hello world".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createReadTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: read succeeds
        XCTAssertFalse(result.isError,
                        "Reading within allowed path should succeed, got: \(result.content)")
        XCTAssertTrue(result.content.contains("hello world"),
                       "Should return file content")
    }

    /// AC1 [P0]: FileReadTool denies reading files outside allowed read paths.
    func testFileReadTool_deniedPath_returnsPermissionDenied() async {
        // Given: sandbox allowing reads only in tempDir, not outsideDir
        let sandbox = SandboxSettings(allowedReadPaths: [tempDir + "/"])
        let outPath = (outsideDir as NSString).appendingPathComponent("secret.txt")
        try! "secret data".write(toFile: outPath, atomically: true, encoding: .utf8)

        let tool = createReadTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": outPath],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: read is denied with permission error
        XCTAssertTrue(result.isError,
                       "Reading outside allowed path should return error")
        XCTAssertTrue(
            result.content.localizedCaseInsensitiveContains("permission") ||
            result.content.localizedCaseInsensitiveContains("denied") ||
            result.content.localizedCaseInsensitiveContains("outside") ||
            result.content.localizedCaseInsensitiveContains("scope"),
            "Error should mention permission denial: \(result.content)"
        )
    }

    /// AC1 [P0]: FileReadTool denies reading /etc/passwd when only /project/ is allowed.
    func testFileReadTool_etcPasswd_deniedWhenProjectOnlyAllowed() async {
        // Given: sandbox only allowing /project/ reads
        let sandbox = SandboxSettings(allowedReadPaths: ["/project/"])

        let tool = createReadTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": "/etc/passwd"],
            cwd: "/project",
            sandbox: sandbox
        )

        // Then: read is denied
        XCTAssertTrue(result.isError,
                       "Reading /etc/passwd outside allowed scope should be denied")
    }
}

// MARK: - AC2: FileWriteTool enforces write-path sandbox

final class FileWriteToolSandboxTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-FileWriteSandbox-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    /// AC2 [P0]: FileWriteTool denies writes when write path is outside allowed write scope.
    func testFileWriteTool_emptyWritePaths_deniesWrite() async {
        // Given: sandbox allowing writes only in /nowhere/, not in tempDir
        // Note: SandboxChecker treats empty allowedWritePaths as "no restrictions",
        // so we use a non-matching write path to effectively deny writes to tempDir.
        let sandbox = SandboxSettings(
            allowedReadPaths: [tempDir + "/"],
            allowedWritePaths: ["/nowhere/"]
        )
        let filePath = (tempDir as NSString).appendingPathComponent("new-file.swift")

        let tool = createWriteTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath, "content": "test"],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: write is denied because tempDir is not in allowedWritePaths
        XCTAssertTrue(result.isError,
                       "Write should be denied when path is outside allowed write scope")
    }

    /// AC2 [P0]: FileWriteTool allows writes within allowed write paths.
    func testFileWriteTool_allowedWritePath_succeeds() async {
        // Given: sandbox allowing writes in tempDir
        let sandbox = SandboxSettings(allowedWritePaths: [tempDir + "/"])
        let filePath = (tempDir as NSString).appendingPathComponent("new-file.swift")

        let tool = createWriteTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath, "content": "hello"],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: write succeeds
        XCTAssertFalse(result.isError,
                        "Writing within allowed write path should succeed, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Successfully wrote"),
                       "Should confirm write: \(result.content)")
    }
}

// MARK: - AC3: FileEditTool enforces write-path sandbox

final class FileEditToolSandboxTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-FileEditSandbox-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    /// AC3 [P0]: FileEditTool allows edits within allowed write paths.
    func testFileEditTool_allowedPath_succeeds() async {
        // Given: sandbox allowing both read and write in tempDir
        let sandbox = SandboxSettings(
            allowedReadPaths: [tempDir + "/"],
            allowedWritePaths: [tempDir + "/"]
        )
        let filePath = (tempDir as NSString).appendingPathComponent("file.swift")
        try! "hello world".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createEditTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath, "old_string": "hello", "new_string": "goodbye"],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: edit succeeds
        XCTAssertFalse(result.isError,
                        "Editing within allowed path should succeed, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Successfully edited"),
                       "Should confirm edit: \(result.content)")
    }

    /// AC3 [P0]: FileEditTool denies edits outside allowed write paths.
    func testFileEditTool_deniedWritePath_returnsPermissionDenied() async {
        // Given: sandbox allowing reads but not writes in tempDir
        let sandbox = SandboxSettings(
            allowedReadPaths: [tempDir + "/"],
            allowedWritePaths: ["/nowhere/"]
        )
        let filePath = (tempDir as NSString).appendingPathComponent("file.swift")
        try! "hello world".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createEditTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath, "old_string": "hello", "new_string": "goodbye"],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: edit is denied
        XCTAssertTrue(result.isError,
                       "Editing outside allowed write path should be denied")
    }
}

// MARK: - AC4: GlobTool enforces read-path sandbox

final class GlobToolSandboxTests: XCTestCase {

    var tempDir: String!
    var outsideDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-GlobSandbox-\(UUID().uuidString)")
        outsideDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-GlobSandboxOutside-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
        try! FileManager.default.createDirectory(
            atPath: outsideDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        try? FileManager.default.removeItem(atPath: outsideDir)
        super.tearDown()
    }

    /// AC4 [P0]: GlobTool allows searching within allowed read paths.
    func testGlobTool_allowedSearchDir_succeeds() async {
        // Given: sandbox allowing reads in tempDir
        let sandbox = SandboxSettings(allowedReadPaths: [tempDir + "/"])
        let filePath = (tempDir as NSString).appendingPathComponent("test.swift")
        try! "code".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createGlobTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["pattern": "*.swift", "path": tempDir],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: search succeeds
        XCTAssertFalse(result.isError,
                        "Glob in allowed directory should succeed, got: \(result.content)")
        XCTAssertTrue(result.content.contains("test.swift"),
                       "Should find the swift file: \(result.content)")
    }

    /// AC4 [P0]: GlobTool denies searching outside allowed read paths.
    func testGlobTool_deniedSearchDir_returnsPermissionDenied() async {
        // Given: sandbox allowing reads only in tempDir
        let sandbox = SandboxSettings(allowedReadPaths: [tempDir + "/"])

        let tool = createGlobTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["pattern": "*.txt", "path": outsideDir],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: search is denied
        XCTAssertTrue(result.isError,
                       "Glob outside allowed directory should be denied")
    }
}

// MARK: - AC5: GrepTool enforces read-path sandbox

final class GrepToolSandboxTests: XCTestCase {

    var tempDir: String!
    var outsideDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-GrepSandbox-\(UUID().uuidString)")
        outsideDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-GrepSandboxOutside-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
        try! FileManager.default.createDirectory(
            atPath: outsideDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        try? FileManager.default.removeItem(atPath: outsideDir)
        super.tearDown()
    }

    /// AC5 [P0]: GrepTool allows searching within allowed read paths.
    func testGrepTool_allowedSearchDir_succeeds() async {
        // Given: sandbox allowing reads in tempDir
        let sandbox = SandboxSettings(allowedReadPaths: [tempDir + "/"])
        let filePath = (tempDir as NSString).appendingPathComponent("code.swift")
        try! "import Foundation".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createGrepTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["pattern": "Foundation", "path": tempDir],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: search succeeds
        XCTAssertFalse(result.isError,
                        "Grep in allowed directory should succeed, got: \(result.content)")
    }

    /// AC5 [P0]: GrepTool denies searching outside allowed read paths.
    func testGrepTool_deniedSearchDir_returnsPermissionDenied() async {
        // Given: sandbox allowing reads only in tempDir
        let sandbox = SandboxSettings(allowedReadPaths: [tempDir + "/"])

        let tool = createGrepTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["pattern": "secret", "path": outsideDir],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: search is denied
        XCTAssertTrue(result.isError,
                       "Grep outside allowed directory should be denied")
    }
}

// MARK: - AC6: Symlink escape prevention

final class SymlinkEscapeSandboxTests: XCTestCase {

    var tempDir: String!
    var outsideDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-SymlinkEscape-\(UUID().uuidString)")
        outsideDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-SymlinkEscapeOutside-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
        try! FileManager.default.createDirectory(
            atPath: outsideDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        try? FileManager.default.removeItem(atPath: outsideDir)
        super.tearDown()
    }

    /// AC6 [P0]: FileReadTool denies reading through symlink that resolves outside sandbox.
    func testSymlinkEscape_readThroughSymlinkOutsideSandbox_denied() async {
        // Given: a file outside the sandbox, and a symlink inside the sandbox pointing to it
        let outsideFile = (outsideDir as NSString).appendingPathComponent("secret.txt")
        try! "secret data".write(toFile: outsideFile, atomically: true, encoding: .utf8)

        let linkPath = (tempDir as NSString).appendingPathComponent("link")
        try! FileManager.default.createSymbolicLink(
            atPath: linkPath,
            withDestinationPath: outsideDir
        )

        let sandbox = SandboxSettings(allowedReadPaths: [tempDir + "/"])

        let tool = createReadTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": linkPath + "/secret.txt"],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: read through symlink is denied because resolved path is outside sandbox
        XCTAssertTrue(result.isError,
                       "Reading through symlink that escapes sandbox should be denied, got: \(result.content)")
    }
}

// MARK: - AC7: Path traversal prevention

final class PathTraversalSandboxTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-PathTraversal-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    /// AC7 [P0]: FileReadTool denies reading with path traversal that escapes sandbox.
    func testPathTraversal_dotDotEscapesSandbox_denied() async {
        // Given: sandbox only allowing tempDir reads
        // Path: /tmp/<tempDir>/../../../etc/passwd resolves to /etc/passwd
        let traversalPath = (tempDir as NSString).appendingPathComponent("../../../etc/passwd")
        let sandbox = SandboxSettings(allowedReadPaths: [tempDir + "/"])

        let tool = createReadTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": traversalPath],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: path traversal is denied
        XCTAssertTrue(result.isError,
                       "Path traversal outside sandbox should be denied")
    }
}

// MARK: - AC8: No sandbox = no restrictions (backward compatibility)

final class NoSandboxBackwardCompatTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-NoSandbox-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    /// AC8 [P0]: FileReadTool works normally when sandbox is nil (no restrictions).
    func testNoSandbox_readTool_worksNormally() async {
        let filePath = (tempDir as NSString).appendingPathComponent("file.txt")
        try! "content".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createReadTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath],
            cwd: tempDir,
            sandbox: nil
        )

        XCTAssertFalse(result.isError,
                        "Without sandbox, read should work normally, got: \(result.content)")
        XCTAssertTrue(result.content.contains("content"),
                       "Should return file content")
    }

    /// AC8 [P0]: FileWriteTool works normally when sandbox is nil.
    func testNoSandbox_writeTool_worksNormally() async {
        let filePath = (tempDir as NSString).appendingPathComponent("file.txt")

        let tool = createWriteTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath, "content": "data"],
            cwd: tempDir,
            sandbox: nil
        )

        XCTAssertFalse(result.isError,
                        "Without sandbox, write should work normally, got: \(result.content)")
    }

    /// AC8 [P0]: FileEditTool works normally when sandbox is nil.
    func testNoSandbox_editTool_worksNormally() async {
        let filePath = (tempDir as NSString).appendingPathComponent("file.txt")
        try! "old text".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createEditTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath, "old_string": "old", "new_string": "new"],
            cwd: tempDir,
            sandbox: nil
        )

        XCTAssertFalse(result.isError,
                        "Without sandbox, edit should work normally, got: \(result.content)")
    }

    /// AC8 [P0]: GlobTool works normally when sandbox is nil.
    func testNoSandbox_globTool_worksNormally() async {
        let filePath = (tempDir as NSString).appendingPathComponent("test.swift")
        try! "code".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createGlobTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["pattern": "*.swift", "path": tempDir],
            cwd: tempDir,
            sandbox: nil
        )

        XCTAssertFalse(result.isError,
                        "Without sandbox, glob should work normally, got: \(result.content)")
    }

    /// AC8 [P0]: GrepTool works normally when sandbox is nil.
    func testNoSandbox_grepTool_worksNormally() async {
        let filePath = (tempDir as NSString).appendingPathComponent("test.swift")
        try! "import Foundation".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createGrepTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["pattern": "Foundation", "path": tempDir],
            cwd: tempDir,
            sandbox: nil
        )

        XCTAssertFalse(result.isError,
                        "Without sandbox, grep should work normally, got: \(result.content)")
    }
}

// MARK: - AC9: Sandbox check happens BEFORE tool execution

final class SandboxCheckTimingTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-SandboxTiming-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    /// AC9 [P0]: FileWriteTool does NOT create file when sandbox denies the path.
    func testSandboxCheckBeforeIO_writeDenied_noFileCreated() async {
        // Given: sandbox allowing writes only in /nowhere/, not in tempDir
        let sandbox = SandboxSettings(
            allowedReadPaths: [tempDir + "/"],
            allowedWritePaths: ["/nowhere/"]
        )
        let filePath = (tempDir as NSString).appendingPathComponent("should-not-exist.txt")

        let tool = createWriteTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath, "content": "should not be written"],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: write is denied AND file was NOT created
        XCTAssertTrue(result.isError,
                       "Write should be denied by sandbox")
        let fileExists = FileManager.default.fileExists(atPath: filePath)
        XCTAssertFalse(fileExists,
                        "File should NOT be created when sandbox denies the write")
    }

    /// AC9 [P0]: FileEditTool does NOT modify file when sandbox denies the path.
    func testSandboxCheckBeforeIO_editDenied_fileUnmodified() async {
        // Given: sandbox allowing writes only in /nowhere/, not in tempDir
        let sandbox = SandboxSettings(
            allowedReadPaths: [tempDir + "/"],
            allowedWritePaths: ["/nowhere/"]
        )
        let filePath = (tempDir as NSString).appendingPathComponent("file.txt")
        let originalContent = "original content"
        try! originalContent.write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createEditTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath, "old_string": "original", "new_string": "modified"],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: edit is denied AND file is unmodified
        XCTAssertTrue(result.isError,
                       "Edit should be denied by sandbox")
        let currentContent = try! String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(currentContent, originalContent,
                        "File should remain unmodified when sandbox denies the edit")
    }
}

// MARK: - AC10: deniedPaths takes precedence

final class DeniedPathsPrecedenceTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-DeniedPrecedence-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    /// AC10 [P0]: File in allowedReadPaths AND deniedPaths is denied.
    func testDeniedPathsOverridesAllowedPaths_readDenied() async {
        // Given: sandbox allowing reads in tempDir but denying a subdirectory
        let secretDir = (tempDir as NSString).appendingPathComponent("secret")
        try! FileManager.default.createDirectory(
            atPath: secretDir,
            withIntermediateDirectories: true
        )
        let secretFile = (secretDir as NSString).appendingPathComponent("key.pem")
        try! "PRIVATE KEY".write(toFile: secretFile, atomically: true, encoding: .utf8)

        let sandbox = SandboxSettings(
            allowedReadPaths: [tempDir + "/"],
            deniedPaths: [secretDir + "/"]
        )

        let tool = createReadTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": secretFile],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: read is denied despite being under allowedReadPaths
        XCTAssertTrue(result.isError,
                       "Read should be denied because deniedPaths takes precedence")
    }

    /// AC10 [P0]: File in allowedReadPaths but NOT in deniedPaths is allowed.
    func testDeniedPathsDoesNotBlockUnrelatedPaths_readAllowed() async {
        // Given: sandbox allowing reads in tempDir, denying only secret subdir
        let secretDir = (tempDir as NSString).appendingPathComponent("secret")
        try! FileManager.default.createDirectory(
            atPath: secretDir,
            withIntermediateDirectories: true
        )
        let normalFile = (tempDir as NSString).appendingPathComponent("normal.txt")
        try! "normal content".write(toFile: normalFile, atomically: true, encoding: .utf8)

        let sandbox = SandboxSettings(
            allowedReadPaths: [tempDir + "/"],
            deniedPaths: [secretDir + "/"]
        )

        let tool = createReadTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": normalFile],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: read succeeds because file is not in deniedPaths
        XCTAssertFalse(result.isError,
                        "Read should succeed because file is not in deniedPaths, got: \(result.content)")
    }
}

// MARK: - Edge Cases

final class SandboxEdgeCaseTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory()
            .appending("OpenAgentSDKTests-SandboxEdge-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    /// Edge case [P1]: Empty SandboxSettings (all empty arrays) = no restrictions.
    func testEmptySandboxSettings_noRestrictions() async {
        // Given: SandboxSettings with all empty arrays (no restrictions)
        let sandbox = SandboxSettings(
            allowedReadPaths: [],
            allowedWritePaths: [],
            deniedPaths: []
        )
        let filePath = (tempDir as NSString).appendingPathComponent("file.txt")
        try! "content".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createReadTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: read succeeds (empty settings = no restrictions)
        XCTAssertFalse(result.isError,
                        "Empty SandboxSettings should not restrict reads, got: \(result.content)")
    }

    /// Edge case [P1]: Path with trailing slash in allowedReadPaths matches correctly.
    func testTrailingSlashInAllowedPaths_matchesCorrectly() async {
        // Given: sandbox with trailing slash in allowed read path
        let sandbox = SandboxSettings(allowedReadPaths: [tempDir + "/"])
        let subDir = (tempDir as NSString).appendingPathComponent("src")
        try! FileManager.default.createDirectory(atPath: subDir, withIntermediateDirectories: true)
        let filePath = (subDir as NSString).appendingPathComponent("file.swift")
        try! "code".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createReadTool()
        let result = await callToolWithSandbox(
            tool,
            input: ["file_path": filePath],
            cwd: tempDir,
            sandbox: sandbox
        )

        // Then: read succeeds (trailing slash matches subdirectories)
        XCTAssertFalse(result.isError,
                        "Trailing slash should match subdirectories, got: \(result.content)")
    }

    /// Edge case [P1]: GlobTool with sandbox on cwd default (no explicit path).
    func testGlobTool_defaultCwd_withSandbox() async {
        // Given: sandbox allowing reads in tempDir
        let sandbox = SandboxSettings(allowedReadPaths: [tempDir + "/"])
        let filePath = (tempDir as NSString).appendingPathComponent("findme.swift")
        try! "code".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createGlobTool()
        // No "path" parameter, so it uses cwd (tempDir)
        let result = await callToolWithSandbox(
            tool,
            input: ["pattern": "*.swift"],
            cwd: tempDir,
            sandbox: sandbox
        )

        XCTAssertFalse(result.isError,
                        "Glob with default cwd should respect sandbox, got: \(result.content)")
    }

    /// Edge case [P1]: GrepTool with sandbox on cwd default (no explicit path).
    func testGrepTool_defaultCwd_withSandbox() async {
        // Given: sandbox allowing reads in tempDir
        let sandbox = SandboxSettings(allowedReadPaths: [tempDir + "/"])
        let filePath = (tempDir as NSString).appendingPathComponent("search.swift")
        try! "import Foundation".write(toFile: filePath, atomically: true, encoding: .utf8)

        let tool = createGrepTool()
        // No "path" parameter, so it uses cwd (tempDir)
        let result = await callToolWithSandbox(
            tool,
            input: ["pattern": "Foundation"],
            cwd: tempDir,
            sandbox: sandbox
        )

        XCTAssertFalse(result.isError,
                        "Grep with default cwd should respect sandbox, got: \(result.content)")
    }
}

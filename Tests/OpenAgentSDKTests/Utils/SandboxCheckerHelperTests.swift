import XCTest
@testable import OpenAgentSDK

// MARK: - SandboxCheckerHelperTests

/// Direct unit tests for SandboxChecker's public helper methods:
/// - extractCommandBasename() — quote/slash stripping and basename extraction
/// - extractFilePaths() — tokenization and path detection from command strings
///
/// These methods are tested indirectly via BashSandboxTests, but this file provides
/// direct unit tests covering all documented patterns and edge cases.
final class SandboxCheckerHelperTests: XCTestCase {

    // MARK: - extractCommandBasename — documented patterns

    /// "rm -rf /tmp/test" -> "rm"
    func testExtractBasename_commandWithArgs_returnsFirstToken() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("rm -rf /tmp/test"), "rm")
    }

    /// "/usr/bin/rm -rf" -> "rm"
    func testExtractBasename_fullPath_returnsLastPathComponent() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("/usr/bin/rm -rf"), "rm")
    }

    /// "rm" -> "rm" (bare command, no args)
    func testExtractBasename_bareCommand_returnsCommand() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("rm"), "rm")
    }

    /// "\\rm" -> "rm" (leading backslash stripped)
    func testExtractBasename_leadingBackslash_stripsBackslash() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("\\rm"), "rm")
    }

    /// "\\rm -rf /tmp" -> "rm" (backslash + args)
    func testExtractBasename_leadingBackslashWithArgs_stripsAndExtracts() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("\\rm -rf /tmp"), "rm")
    }

    /// "\"rm\" -rf" -> "rm" (double quotes stripped)
    func testExtractBasename_doubleQuoted_stripsQuotes() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("\"rm\" -rf"), "rm")
    }

    /// "'rm' -rf" -> "rm" (single quotes stripped)
    func testExtractBasename_singleQuoted_stripsQuotes() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("'rm' -rf"), "rm")
    }

    // MARK: - extractCommandBasename — edge cases

    /// Full path with backslash prefix: "\\usr/bin/rm" -> "rm"
    func testExtractBasename_backslashFullPath_stripsAndExtractsBasename() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("\\/usr/bin/rm"), "rm")
    }

    /// Command with leading/trailing whitespace
    func testExtractBasename_whitespaceTrimmed() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("  git status  "), "git")
    }

    /// Full path with args and trailing whitespace
    func testExtractBasename_fullPathWithArgsAndWhitespace() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("  /usr/local/bin/node --version  "), "node")
    }

    /// Empty string returns empty
    func testExtractBasename_emptyString() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename(""), "")
    }

    /// Only whitespace returns empty
    func testExtractBasename_onlyWhitespace() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("   "), "")
    }

    /// Command with tab separators
    func testExtractBasename_tabSeparators() {
        XCTAssertEqual(SandboxChecker.extractCommandBasename("git\tstatus"), "git")
    }

    // MARK: - extractFilePaths — documented patterns

    /// "cat /etc/passwd" -> ["/etc/passwd"]
    func testExtractFilePaths_absolutePath() {
        let paths = SandboxChecker.extractFilePaths(from: "cat /etc/passwd")
        XCTAssertEqual(paths, ["/etc/passwd"])
    }

    /// "ls -la /tmp/file.txt" -> ["/tmp/file.txt"]
    func testExtractFilePaths_withFlags_skipsFlags() {
        let paths = SandboxChecker.extractFilePaths(from: "ls -la /tmp/file.txt")
        XCTAssertEqual(paths, ["/tmp/file.txt"])
    }

    /// "cp src.txt dst.txt" -> [] (no absolute/relative indicators)
    func testExtractFilePaths_noPathIndicators_returnsEmpty() {
        let paths = SandboxChecker.extractFilePaths(from: "cp src.txt dst.txt")
        // Neither src.txt nor dst.txt starts with /, ./, ~/ or contains /
        XCTAssertEqual(paths, [])
    }

    /// "git status" -> [] (no path arguments)
    func testExtractFilePaths_noPaths_returnsEmpty() {
        let paths = SandboxChecker.extractFilePaths(from: "git status")
        XCTAssertEqual(paths, [])
    }

    /// "rm -rf /" -> ["/"]
    func testExtractFilePaths_rootPath() {
        let paths = SandboxChecker.extractFilePaths(from: "rm -rf /")
        XCTAssertEqual(paths, ["/"])
    }

    // MARK: - extractFilePaths — relative paths

    /// "cat ./relative/path.txt" -> ["./relative/path.txt"]
    func testExtractFilePaths_dotSlashRelative() {
        let paths = SandboxChecker.extractFilePaths(from: "cat ./relative/path.txt")
        XCTAssertEqual(paths, ["./relative/path.txt"])
    }

    /// "cat ~/file.txt" -> ["~/file.txt"]
    func testExtractFilePaths_tildeHome() {
        let paths = SandboxChecker.extractFilePaths(from: "cat ~/file.txt")
        XCTAssertEqual(paths, ["~/file.txt"])
    }

    /// "cat path/to/file.txt" -> ["path/to/file.txt"] (contains /)
    func testExtractFilePaths_pathWithSlash() {
        let paths = SandboxChecker.extractFilePaths(from: "cat path/to/file.txt")
        XCTAssertEqual(paths, ["path/to/file.txt"])
    }

    // MARK: - extractFilePaths — multiple paths

    /// "cp /src/file.txt /dst/file.txt" -> ["/src/file.txt", "/dst/file.txt"]
    func testExtractFilePaths_multipleAbsolutePaths() {
        let paths = SandboxChecker.extractFilePaths(from: "cp /src/file.txt /dst/file.txt")
        XCTAssertEqual(paths, ["/src/file.txt", "/dst/file.txt"])
    }

    /// "ls -la /tmp /var" -> ["/tmp", "/var"]
    func testExtractFilePaths_multiplePathsWithFlags() {
        let paths = SandboxChecker.extractFilePaths(from: "ls -la /tmp /var")
        XCTAssertEqual(paths, ["/tmp", "/var"])
    }

    // MARK: - extractFilePaths — edge cases

    /// Command only (no arguments) returns empty
    func testExtractFilePaths_commandOnly_returnsEmpty() {
        let paths = SandboxChecker.extractFilePaths(from: "git")
        XCTAssertEqual(paths, [])
    }

    /// All arguments are flags -> returns empty
    func testExtractFilePaths_allFlags_returnsEmpty() {
        let paths = SandboxChecker.extractFilePaths(from: "git -v --version -h")
        XCTAssertEqual(paths, [])
    }

    /// Mixed flags and paths
    func testExtractFilePaths_mixedFlagsAndPaths() {
        let paths = SandboxChecker.extractFilePaths(from: "grep -r --include=*.swift TODO /project/src")
        XCTAssertEqual(paths, ["/project/src"])
    }

    /// Empty command returns empty
    func testExtractFilePaths_emptyCommand_returnsEmpty() {
        let paths = SandboxChecker.extractFilePaths(from: "")
        XCTAssertEqual(paths, [])
    }

    /// Whitespace-only command returns empty
    func testExtractFilePaths_whitespaceOnly_returnsEmpty() {
        let paths = SandboxChecker.extractFilePaths(from: "   ")
        XCTAssertEqual(paths, [])
    }

    // MARK: - extractFilePaths — quoted paths

    /// Paths in double quotes are extracted (quotes stripped by tokenizer).
    func testExtractFilePaths_quotedPath() {
        let paths = SandboxChecker.extractFilePaths(from: "cat \"/tmp/my file.txt\"")
        XCTAssertEqual(paths, ["/tmp/my file.txt"])
    }

    /// Paths in single quotes are extracted.
    func testExtractFilePaths_singleQuotedPath() {
        let paths = SandboxChecker.extractFilePaths(from: "cat '/tmp/my file.txt'")
        XCTAssertEqual(paths, ["/tmp/my file.txt"])
    }
}

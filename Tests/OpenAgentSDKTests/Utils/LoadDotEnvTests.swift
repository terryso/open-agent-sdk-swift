import XCTest
@testable import OpenAgentSDK

final class LoadDotEnvTests: XCTestCase {

    // MARK: - Test Helpers

    private func createTempDotEnv(content: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenAgentSDK_LoadDotEnvTests_\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent(".env")
        try! content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - loadDotEnv with custom path

    func testLoadDotEnv_basicKeyValue() {
        let file = createTempDotEnv(content: "MY_KEY=my_value\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env["MY_KEY"], "my_value")
    }

    func testLoadDotEnv_multipleKeys() {
        let file = createTempDotEnv(content: "KEY1=val1\nKEY2=val2\nKEY3=val3\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env.count, 3)
        XCTAssertEqual(env["KEY1"], "val1")
        XCTAssertEqual(env["KEY2"], "val2")
        XCTAssertEqual(env["KEY3"], "val3")
    }

    func testLoadDotEnv_skipsComments() {
        let file = createTempDotEnv(content: "# This is a comment\nKEY=val\n# Another comment\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env.count, 1)
        XCTAssertEqual(env["KEY"], "val")
    }

    func testLoadDotEnv_skipsEmptyLines() {
        let file = createTempDotEnv(content: "KEY1=val1\n\n\nKEY2=val2\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env.count, 2)
    }

    func testLoadDotEnv_skipsWhitespaceOnlyLines() {
        let file = createTempDotEnv(content: "KEY1=val1\n   \n\t\nKEY2=val2\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env.count, 2)
    }

    func testLoadDotEnv_skipsMalformedLines_noEquals() {
        let file = createTempDotEnv(content: "THIS_IS_NOT_KEY_VALUE\nKEY=val\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env.count, 1)
        XCTAssertEqual(env["KEY"], "val")
    }

    func testLoadDotEnv_emptyValue() {
        let file = createTempDotEnv(content: "EMPTY_KEY=\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env["EMPTY_KEY"], "")
    }

    func testLoadDotEnv_valueWithEquals() {
        let file = createTempDotEnv(content: "CONNECTION_STRING=host=localhost;port=5432\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env["CONNECTION_STRING"], "host=localhost;port=5432")
    }

    func testLoadDotEnv_whitespaceAroundKeyAndValue() {
        let file = createTempDotEnv(content: "  KEY  =  value  \n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env["KEY"], "value")
    }

    func testLoadDotEnv_duplicateKeys_lastWins() {
        let file = createTempDotEnv(content: "DUP=first\nDUP=second\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env["DUP"], "second", "Last value should win for duplicate keys")
    }

    func testLoadDotEnv_nonExistentFile_returnsEmpty() {
        let env = loadDotEnv(path: "/nonexistent/path/.env")
        XCTAssertTrue(env.isEmpty, "Non-existent file should return empty dictionary")
    }

    func testLoadDotEnv_emptyFile_returnsEmpty() {
        let file = createTempDotEnv(content: "")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertTrue(env.isEmpty)
    }

    func testLoadDotEnv_onlyCommentsAndEmptyLines() {
        let file = createTempDotEnv(content: "# comment\n\n# another\n  \n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertTrue(env.isEmpty)
    }

    func testLoadDotEnv_valueWithQuotes() {
        let file = createTempDotEnv(content: "QUOTED=\"hello world\"\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        // Quotes are preserved (loadDotEnv does not strip quotes)
        XCTAssertEqual(env["QUOTED"], "\"hello world\"")
    }

    func testLoadDotEnv_valueWithSpecialChars() {
        let file = createTempDotEnv(content: "SPECIAL=key=val&foo=bar\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env["SPECIAL"], "key=val&foo=bar")
    }

    func testLoadDotEnv_commentWithHashInValue() {
        // Line starting with # is a comment, but # in a value is part of the value
        let file = createTempDotEnv(content: "URL=https://example.com#anchor\n#comment\n")
        defer { cleanup(file) }

        let env = loadDotEnv(path: file.path)
        XCTAssertEqual(env["URL"], "https://example.com#anchor")
    }

    // MARK: - getEnv with dotEnv fallback

    func testGetEnv_fromDotEnv_prefersProcessEnv() {
        setenv("LOAD_DOT_ENV_TEST", "process-value", 1)
        defer { unsetenv("LOAD_DOT_ENV_TEST") }

        let dotEnv: [String: String] = ["LOAD_DOT_ENV_TEST": "dotenv-value"]
        let result = getEnv("LOAD_DOT_ENV_TEST", from: dotEnv)

        XCTAssertEqual(result, "process-value", "Process env should take priority")
    }

    func testGetEnv_fromDotEnv_fallsBackToDotEnv() {
        let dotEnv: [String: String] = ["MY_MISSING_KEY": "dotenv-fallback"]
        let result = getEnv("MY_MISSING_KEY", from: dotEnv)

        XCTAssertEqual(result, "dotenv-fallback", "Should fall back to dotEnv when not in process env")
    }

    func testGetEnv_fromDotEnv_notInEither_returnsNil() {
        let dotEnv: [String: String] = [:]
        let result = getEnv("DEFINITELY_NOT_IN_EITHER_XYZ123", from: dotEnv)

        XCTAssertNil(result)
    }

    func testGetEnv_fromDotEnv_emptyProcessEnv_fallsBack() {
        setenv("LOAD_DOT_ENV_EMPTY_TEST", "", 1)
        defer { unsetenv("LOAD_DOT_ENV_EMPTY_TEST") }

        let dotEnv: [String: String] = ["LOAD_DOT_ENV_EMPTY_TEST": "fallback"]
        let result = getEnv("LOAD_DOT_ENV_EMPTY_TEST", from: dotEnv)

        XCTAssertEqual(result, "fallback", "Empty process env should fall back to dotEnv")
    }

    func testGetEnv_fromDotEnv_emptyDotEnvValue_returnsValue() {
        let dotEnv: [String: String] = ["MY_EMPTY_KEY": ""]
        let result = getEnv("MY_EMPTY_KEY", from: dotEnv)

        // The dotEnv value is "", which is truthy (not empty check in from: overload)
        // The overload only checks process env for empty; dotEnv is returned as-is
        XCTAssertEqual(result, "")
    }

    func testGetEnv_fromDotEnv_emptyDictionary() {
        let result = getEnv("ANY_KEY", from: [:])
        XCTAssertNil(result)
    }
}

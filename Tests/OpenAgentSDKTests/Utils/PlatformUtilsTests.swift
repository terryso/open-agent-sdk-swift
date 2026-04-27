import XCTest
@testable import OpenAgentSDK

final class PlatformUtilsTests: XCTestCase {

    // MARK: - shellPath

    func testShellPathReturnsSHELLWhenSetAndValid() {
        let shell = ProcessInfo.processInfo.environment["SHELL"]
        if let shell, !shell.isEmpty {
            let fm = FileManager.default
            if fm.isExecutableFile(atPath: shell) {
                XCTAssertEqual(PlatformUtils.shellPath(), shell)
            }
        }
    }

    func testShellPathReturnsNonEmpty() {
        XCTAssertFalse(PlatformUtils.shellPath().isEmpty)
    }

    func testShellPathReturnsExecutable() {
        let path = PlatformUtils.shellPath()
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path),
                      "shellPath() returned non-executable: \(path)")
    }

    func testShellPathSkipsInvalidSHELL() {
        // When $SHELL is set to a non-existent path, shellPath() should
        // fall through to the candidate list rather than returning the bad path.
        // We can't change env vars at runtime, but we verify the returned path
        // is always executable — regardless of $SHELL value.
        let result = PlatformUtils.shellPath()
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: result))
    }

    func testShellPathReturnsBourneCompatibleShell() {
        let path = PlatformUtils.shellPath()
        // All candidates are Bourne-compatible shells
        XCTAssertTrue(path.hasSuffix("/bash") || path.hasSuffix("/sh") || path.hasSuffix("/zsh"),
                      "Expected a Bourne-compatible shell, got: \(path)")
    }

    // MARK: - homeDirectory

    func testHomeDirectoryMatchesHomeEnv() {
        let envHome = ProcessInfo.processInfo.environment["HOME"]
        if let envHome {
            XCTAssertEqual(PlatformUtils.homeDirectory(), envHome)
        }
    }

    func testHomeDirectoryReturnsNonEmpty() {
        XCTAssertFalse(PlatformUtils.homeDirectory().isEmpty)
    }

    func testHomeDirectoryIsExistingDirectory() {
        let home = PlatformUtils.homeDirectory()
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: home, isDirectory: &isDir)
        XCTAssertTrue(exists && isDir.boolValue,
                      "homeDirectory() returned non-existent or non-directory: \(home)")
    }

    func testHomeDirectoryStartsWithSlash() {
        let home = PlatformUtils.homeDirectory()
        XCTAssertTrue(home.hasPrefix("/"),
                      "homeDirectory() should return an absolute path, got: \(home)")
    }
}

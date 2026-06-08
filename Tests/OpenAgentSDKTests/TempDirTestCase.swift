import Foundation
import XCTest

/// Base test case class that provides an isolated temporary directory
/// which is automatically created in setUp and removed in tearDown.
///
/// Use this instead of XCTestCase directly when tests need a tempDir
/// for filesystem-based operations.
class TempDirTestCase: XCTestCase {

    /// Isolated temporary directory path, created fresh for each test.
    /// Automatically cleaned up in tearDown.
    private(set) var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        super.tearDown()
    }
}

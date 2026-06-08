import XCTest
import Foundation

/// Shared helpers for documentation compliance tests.
///
/// Each documentation test file previously duplicated these identical helper methods.
/// Extracted here to eliminate ~500 lines of cross-file duplication across 17 test files.
///
/// Uses `file: String = #file` default parameters so `#file` resolves to the *caller's*
/// file path at each call site, not this helper file's path.
struct DocumentationTestHelpers {

    /// Walk upward from the caller's file to find the directory containing Package.swift.
    static func projectRoot(file: String = #file) -> String {
        let fileManager = FileManager.default
        let testFileDir = URL(fileURLWithPath: file).deletingLastPathComponent().path
        var dir = testFileDir
        for _ in 0..<10 {
            let packagePath = dir + "/Package.swift"
            if fileManager.fileExists(atPath: packagePath) {
                return dir
            }
            let parent = URL(fileURLWithPath: dir).deletingLastPathComponent().path
            if parent == dir { break }
            dir = parent
        }
        return testFileDir
    }

    static func examplesDir(file: String = #file) -> String {
        return projectRoot(file: file) + "/Examples"
    }

    static func fileContent(_ path: String) -> String? {
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    /// Reads file content, failing the test if the file cannot be read.
    /// - Throws: Triggers an XCTFail and throws if the file is unreadable.
    static func requireFileContent(_ path: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        return try XCTUnwrap(fileContent(path), "Could not read file at \(path)", file: file, line: line)
    }

    static func packageSwiftContent(file: String = #file) -> String {
        let path = projectRoot(file: file) + "/Package.swift"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            XCTFail("Package.swift should be readable")
            return ""
        }
        return content
    }
}

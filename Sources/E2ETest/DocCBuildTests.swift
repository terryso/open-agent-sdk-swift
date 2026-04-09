import Foundation

// MARK: - SECTION 43: DocC Documentation Build (Story 9-1)

struct DocCBuildTests {
    static func run() async {
        section("SECTION 43: DocC Documentation Build (Story 9-1)")

        // AC2 & AC10: swift package generate-documentation builds successfully
        await testDocumentationBuildsSuccessfully()
    }

    static func testDocumentationBuildsSuccessfully() async {
        let testName = "Documentation builds without errors (AC2, AC10)"

        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "package", "generate-documentation"]
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        do {
            try process.run()
            process.waitUntilExit()

            let _ = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                pass(testName)
            } else {
                fail(testName, "Exit code: \(process.terminationStatus). stderr: \(errorOutput.suffix(200))")
            }
        } catch {
            fail(testName, "Failed to run swift package generate-documentation: \(error)")
        }
    }
}

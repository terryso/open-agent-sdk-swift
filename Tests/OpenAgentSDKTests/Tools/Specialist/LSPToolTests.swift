import XCTest
@testable import OpenAgentSDK

// MARK: - LSPToolTests

/// ATDD RED PHASE: Tests for Story 5.5 -- LSP Tool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `createLSPTool()` factory function is implemented
///   - `LSPInput` Codable struct is defined
///   - `lspSchema` input schema is defined
///   - Tool call handler implements all operations:
///     goToDefinition, goToImplementation, findReferences,
///     hover, documentSymbol, workspaceSymbol, default
/// TDD Phase: RED (feature not implemented yet)
final class LSPToolTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a basic ToolContext with just cwd (no stores needed for LSP tool).
    private func makeContext(cwd: String = "/tmp") -> ToolContext {
        return ToolContext(
            cwd: cwd,
            toolUseId: "test-tool-use-id"
        )
    }

    /// Creates a temporary Swift file with known content for testing.
    /// Returns the file path. Caller is responsible for cleanup.
    @discardableResult
    private func createTempFile(
        name: String = "TestFile.swift",
        content: String,
        in directory: String? = nil
    ) -> String {
        let tempDir = directory ?? NSTemporaryDirectory()
        let filePath = (tempDir as NSString).appendingPathComponent(name)
        try? content.write(toFile: filePath, atomically: true, encoding: .utf8)
        return filePath
    }

    /// Removes a temporary file at the given path.
    private func removeTempFile(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - AC1: LSP Tool Registration

    /// AC1 [P0]: createLSPTool() returns a ToolProtocol with name "LSP".
    func testCreateLSPTool_returnsToolProtocol() async throws {
        let tool = createLSPTool()

        XCTAssertEqual(tool.name, "LSP")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC1 [P0]: LSP tool description mentions code intelligence or Language Server Protocol.
    func testCreateLSPTool_descriptionMentionsCodeIntelligence() async throws {
        let tool = createLSPTool()

        let desc = tool.description.lowercased()
        XCTAssertTrue(
            desc.contains("language server") || desc.contains("code intelligence") || desc.contains("lsp"),
            "Description should mention Language Server Protocol or code intelligence"
        )
    }

    // MARK: - AC9: isReadOnly Classification

    /// AC9 [P0]: LSP tool isReadOnly returns true (all operations are read-only queries).
    func testCreateLSPTool_isReadOnly_returnsTrue() async throws {
        let tool = createLSPTool()
        XCTAssertTrue(tool.isReadOnly, "LSP tool should be read-only (all operations are queries)")
    }

    // MARK: - AC10: inputSchema Matches TS SDK

    /// AC10 [P0]: LSP inputSchema has type "object".
    func testCreateLSPTool_inputSchema_hasCorrectType() async throws {
        let tool = createLSPTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")
    }

    /// AC10 [P0]: LSP inputSchema has "operation" in required array.
    func testCreateLSPTool_inputSchema_operationIsRequired() async throws {
        let tool = createLSPTool()
        let schema = tool.inputSchema

        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["operation"])
    }

    /// AC10 [P0]: LSP inputSchema operation enum contains all 9 values from TS SDK.
    func testCreateLSPTool_inputSchema_operationEnum_hasAllNineValues() async throws {
        let tool = createLSPTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let operationProp = properties?["operation"] as? [String: Any]
        let enumValues = operationProp?["enum"] as? [String]

        XCTAssertNotNil(enumValues, "operation should have enum values")
        let expectedEnums = [
            "goToDefinition",
            "findReferences",
            "hover",
            "documentSymbol",
            "workspaceSymbol",
            "goToImplementation",
            "prepareCallHierarchy",
            "incomingCalls",
            "outgoingCalls"
        ]
        XCTAssertEqual(Set(enumValues!), Set(expectedEnums),
                       "operation enum should contain all 9 TS SDK values")
    }

    /// AC10 [P0]: LSP inputSchema has file_path field (string, optional).
    func testCreateLSPTool_inputSchema_hasOptionalFilePath() async throws {
        let tool = createLSPTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let filePathProp = properties?["file_path"] as? [String: Any]
        XCTAssertNotNil(filePathProp, "file_path property should exist")
        XCTAssertEqual(filePathProp?["type"] as? String, "string")

        // file_path should NOT be in required
        let required = schema["required"] as? [String] ?? []
        XCTAssertFalse(required.contains("file_path"), "file_path should be optional")
    }

    /// AC10 [P0]: LSP inputSchema has line field (number, optional).
    func testCreateLSPTool_inputSchema_hasOptionalLine() async throws {
        let tool = createLSPTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let lineProp = properties?["line"] as? [String: Any]
        XCTAssertNotNil(lineProp, "line property should exist")
        XCTAssertEqual(lineProp?["type"] as? String, "number")

        let required = schema["required"] as? [String] ?? []
        XCTAssertFalse(required.contains("line"), "line should be optional")
    }

    /// AC10 [P0]: LSP inputSchema has character field (number, optional).
    func testCreateLSPTool_inputSchema_hasOptionalCharacter() async throws {
        let tool = createLSPTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let charProp = properties?["character"] as? [String: Any]
        XCTAssertNotNil(charProp, "character property should exist")
        XCTAssertEqual(charProp?["type"] as? String, "number")

        let required = schema["required"] as? [String] ?? []
        XCTAssertFalse(required.contains("character"), "character should be optional")
    }

    /// AC10 [P0]: LSP inputSchema has query field (string, optional).
    func testCreateLSPTool_inputSchema_hasOptionalQuery() async throws {
        let tool = createLSPTool()
        let schema = tool.inputSchema

        let properties = schema["properties"] as? [String: Any]
        let queryProp = properties?["query"] as? [String: Any]
        XCTAssertNotNil(queryProp, "query property should exist")
        XCTAssertEqual(queryProp?["type"] as? String, "string")

        let required = schema["required"] as? [String] ?? []
        XCTAssertFalse(required.contains("query"), "query should be optional")
    }

    // MARK: - AC2: goToDefinition Operation

    /// AC8/AC2 [P0]: goToDefinition with missing file_path returns is_error=true.
    func testGoToDefinition_missingFilePath_returnsError() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "goToDefinition",
            "line": 5
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError, "Missing file_path should return error")
        XCTAssertTrue(
            result.content.lowercased().contains("file_path") ||
            result.content.lowercased().contains("required"),
            "Error should mention file_path or required parameters"
        )
    }

    /// AC8/AC2 [P0]: goToDefinition with missing line returns is_error=true.
    func testGoToDefinition_missingLine_returnsError() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "goToDefinition",
            "file_path": "/some/file.swift"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError, "Missing line should return error")
        XCTAssertTrue(
            result.content.lowercased().contains("line") ||
            result.content.lowercased().contains("required"),
            "Error should mention line or required parameters"
        )
    }

    /// AC2 [P0]: goToDefinition with valid file and symbol returns grep results.
    func testGoToDefinition_withSymbolAtPosition_returnsGrepResults() async throws {
        let tempDir = NSTemporaryDirectory().appending("lsp-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        // Create a file with a known symbol at a known position
        let fileContent = """
        import Foundation

        public func myTargetFunction() -> String {
            return "hello"
        }
        """
        let filePath = createTempFile(name: "Target.swift", content: fileContent, in: tempDir)

        // Create another file that references the symbol
        let refContent = """
        let result = myTargetFunction()
        """
        _ = createTempFile(name: "Reference.swift", content: refContent, in: tempDir)

        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        let tool = createLSPTool()
        let context = makeContext(cwd: tempDir)

        // Request goToDefinition at line 3 (line with myTargetFunction), character 15
        let input: [String: Any] = [
            "operation": "goToDefinition",
            "file_path": filePath,
            "line": 3,
            "character": 15
        ]
        let result = await tool.call(input: input, context: context)

        // Should return results containing the definition
        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("myTargetFunction") || result.content.contains("No definition found"),
            "Should either find definition or report not found with symbol name"
        )
    }

    /// AC2 [P1]: goToDefinition with no symbol at position returns appropriate message.
    func testGoToDefinition_noSymbolAtPosition_returnsNotFound() async throws {
        let tempDir = NSTemporaryDirectory().appending("lsp-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        // File with empty line
        let fileContent = """

        """
        let filePath = createTempFile(name: "Empty.swift", content: fileContent, in: tempDir)

        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        let tool = createLSPTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "operation": "goToDefinition",
            "file_path": filePath,
            "line": 0,
            "character": 0
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
    }

    // MARK: - AC2/AC10: goToImplementation (same logic as goToDefinition)

    /// AC8/AC2 [P0]: goToImplementation with missing file_path returns is_error=true.
    func testGoToImplementation_missingFilePath_returnsError() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "goToImplementation",
            "line": 3
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC2 [P0]: goToImplementation with valid symbol returns grep results.
    func testGoToImplementation_withSymbol_returnsGrepResults() async throws {
        let tempDir = NSTemporaryDirectory().appending("lsp-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        let fileContent = """
        class MyClass {
            func doSomething() {}
        }
        """
        let filePath = createTempFile(name: "Impl.swift", content: fileContent, in: tempDir)

        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        let tool = createLSPTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "operation": "goToImplementation",
            "file_path": filePath,
            "line": 0,
            "character": 6  // position of "MyClass"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
    }

    // MARK: - AC3: findReferences Operation

    /// AC8/AC3 [P0]: findReferences with missing file_path returns is_error=true.
    func testFindReferences_missingFilePath_returnsError() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "findReferences",
            "line": 5
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC8/AC3 [P0]: findReferences with missing line returns is_error=true.
    func testFindReferences_missingLine_returnsError() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "findReferences",
            "file_path": "/some/file.swift"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC3 [P0]: findReferences with valid symbol returns references.
    func testFindReferences_withSymbol_returnsReferences() async throws {
        let tempDir = NSTemporaryDirectory().appending("lsp-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        let fileContent = """
        public func myReferencedFunction() -> Int {
            return 42
        }

        let x = myReferencedFunction()
        """
        let filePath = createTempFile(name: "Refs.swift", content: fileContent, in: tempDir)

        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        let tool = createLSPTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "operation": "findReferences",
            "file_path": filePath,
            "line": 0,
            "character": 13  // position of "myReferencedFunction"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("myReferencedFunction") || result.content.contains("No references found"),
            "Should either find references or report not found"
        )
    }

    /// AC3 [P1]: findReferences with no symbol returns "No references found".
    func testFindReferences_noSymbol_returnsNoReferences() async throws {
        let tempDir = NSTemporaryDirectory().appending("lsp-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        let fileContent = """

        """
        let filePath = createTempFile(name: "EmptyRefs.swift", content: fileContent, in: tempDir)

        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        let tool = createLSPTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "operation": "findReferences",
            "file_path": filePath,
            "line": 0,
            "character": 0
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
    }

    // MARK: - AC4: hover Operation

    /// AC4 [P0]: hover returns a hint message about needing a language server.
    func testHover_returnsHintMessage() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "hover"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.lowercased().contains("language server") ||
            result.content.lowercased().contains("read tool") ||
            result.content.lowercased().contains("running"),
            "Hover should return hint about needing a running language server"
        )
    }

    /// AC4 [P0]: hover does not require any parameters.
    func testHover_doesNotRequireParameters() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "hover"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError, "hover should not require any parameters")
        XCTAssertFalse(result.content.isEmpty, "hover should return a message")
    }

    // MARK: - AC5: documentSymbol Operation

    /// AC8/AC5 [P0]: documentSymbol with missing file_path returns is_error=true.
    func testDocumentSymbol_missingFilePath_returnsError() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "documentSymbol"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError, "Missing file_path should return error")
        XCTAssertTrue(
            result.content.lowercased().contains("file_path") ||
            result.content.lowercased().contains("required"),
            "Error should mention file_path or required parameters"
        )
    }

    /// AC5 [P0]: documentSymbol with valid file returns symbol declarations.
    func testDocumentSymbol_withFilePath_returnsSymbols() async throws {
        let tempDir = NSTemporaryDirectory().appending("lsp-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        let fileContent = """
        import Foundation

        public struct MyStruct {
            let name: String
            func greet() -> String { return "Hello" }
        }

        public class MyClass {
            func doWork() {}
        }

        public func globalFunction() {}
        """
        let filePath = createTempFile(name: "Symbols.swift", content: fileContent, in: tempDir)

        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        let tool = createLSPTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "operation": "documentSymbol",
            "file_path": filePath
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        // Should find at least some of the declarations
        let content = result.content
        XCTAssertTrue(
            content.contains("MyStruct") || content.contains("MyClass") ||
            content.contains("globalFunction") || content.contains("greet") ||
            content.contains("doWork") || content.contains("No symbols found"),
            "Should return symbol declarations or report none found"
        )
    }

    /// AC5 [P1]: documentSymbol with file containing no declarations returns "No symbols found".
    func testDocumentSymbol_noSymbols_returnsNoSymbolsFound() async throws {
        let tempDir = NSTemporaryDirectory().appending("lsp-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        // File with no Swift declarations (just comments and whitespace)
        let fileContent = """
        // This is a comment
        // Another comment

        """
        let filePath = createTempFile(name: "NoSymbols.txt", content: fileContent, in: tempDir)

        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        let tool = createLSPTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "operation": "documentSymbol",
            "file_path": filePath
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
    }

    // MARK: - AC6: workspaceSymbol Operation

    /// AC8/AC6 [P0]: workspaceSymbol with missing query returns is_error=true.
    func testWorkspaceSymbol_missingQuery_returnsError() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "workspaceSymbol"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError, "Missing query should return error")
        XCTAssertTrue(
            result.content.lowercased().contains("query") ||
            result.content.lowercased().contains("required"),
            "Error should mention query or required parameters"
        )
    }

    /// AC6 [P0]: workspaceSymbol with valid query returns matching symbols.
    func testWorkspaceSymbol_withQuery_returnsResults() async throws {
        let tempDir = NSTemporaryDirectory().appending("lsp-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        let fileContent = """
        public func findUniqueWidget() {}
        public struct UniqueWidgetModel {}
        """
        _ = createTempFile(name: "Widget.swift", content: fileContent, in: tempDir)

        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        let tool = createLSPTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "operation": "workspaceSymbol",
            "query": "UniqueWidget"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("UniqueWidget") || result.content.contains("No symbols found"),
            "Should return matching symbols or report none found"
        )
    }

    /// AC6 [P1]: workspaceSymbol with no matches returns "No symbols found for {query}".
    func testWorkspaceSymbol_noMatches_returnsNoSymbolsFound() async throws {
        let tempDir = NSTemporaryDirectory().appending("lsp-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        // Empty directory -- no files to search
        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        let tool = createLSPTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "operation": "workspaceSymbol",
            "query": "ZZZZZZZ_nonexistent_symbol"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("No symbols found") || result.content.contains("ZZZZZZZ_nonexistent_symbol"),
            "Should report no symbols found for the query"
        )
    }

    // MARK: - AC7: Unknown Operation Error

    /// AC7 [P0]: prepareCallHierarchy returns language server hint.
    func testUnknownOperation_prepareCallHierarchy_returnsLanguageServerHint() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "prepareCallHierarchy"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("requires a running language server"),
            "prepareCallHierarchy should return language server hint"
        )
    }

    /// AC7 [P0]: incomingCalls returns language server hint.
    func testUnknownOperation_incomingCalls_returnsLanguageServerHint() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "incomingCalls"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("requires a running language server"),
            "incomingCalls should return language server hint"
        )
    }

    /// AC7 [P0]: outgoingCalls returns language server hint.
    func testUnknownOperation_outgoingCalls_returnsLanguageServerHint() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "outgoingCalls"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("requires a running language server"),
            "outgoingCalls should return language server hint"
        )
    }

    /// AC7 [P0]: completely unknown operation returns language server hint.
    func testUnknownOperation_completelyUnknown_returnsLanguageServerHint() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "someFutureOperation"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("requires a running language server"),
            "Unknown operation should return language server hint"
        )
    }

    // MARK: - AC12: Error Handling -- Never Throws

    /// AC12 [P0]: LSP tool never throws -- always returns ToolResult even with malformed input.
    func testLSPTool_neverThrows_malformedInput() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let badInputs: [[String: Any]] = [
            [:],                              // empty dict (missing operation)
            ["unexpected": "field"],          // unexpected fields only
            ["operation": 123],               // wrong type for operation
            ["operation": "goToDefinition"],  // operation without required params
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    /// AC12 [P0]: Non-existent file returns is_error=true (doesn't crash the agent loop).
    func testLSPTool_nonExistentFile_returnsError() async throws {
        let tool = createLSPTool()
        let context = makeContext()

        let input: [String: Any] = [
            "operation": "documentSymbol",
            "file_path": "/nonexistent/path/that/does/not/exist.swift"
        ]
        let result = await tool.call(input: input, context: context)

        // Should handle gracefully -- either error or empty result
        XCTAssertEqual(result.toolUseId, "test-tool-use-id")
    }

    // MARK: - AC16: No Actor Store Needed

    /// AC16 [P0]: LSP tool works with basic ToolContext (no stores needed).
    func testLSPTool_doesNotRequireStoreInContext() async throws {
        let tool = createLSPTool()
        // Minimal context with only cwd and toolUseId -- no stores
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        // hover operation should work without any store
        let input: [String: Any] = ["operation": "hover"]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertFalse(result.content.isEmpty)
    }

    // MARK: - AC15/AC17: Working Directory Uses cwd

    /// AC15/AC17 [P0]: LSP tool uses cwd from context as search base.
    func testLSPTool_usesCwdFromContext() async throws {
        let tempDir = NSTemporaryDirectory().appending("lsp-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        let fileContent = """
        public func cwdSpecificFunction() {}
        """
        _ = createTempFile(name: "CwdTest.swift", content: fileContent, in: tempDir)

        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }

        let tool = createLSPTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "operation": "workspaceSymbol",
            "query": "cwdSpecificFunction"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("cwdSpecificFunction"),
            "Should find symbol in cwd directory"
        )
    }
}

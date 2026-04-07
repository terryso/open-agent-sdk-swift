import Foundation
import XCTest
@testable import OpenAgentSDK

// MARK: - NotebookEditToolTests

/// ATDD RED PHASE: Tests for Story 4.7 -- NotebookEdit Tool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `createNotebookEditTool()` factory function is implemented
///   - NotebookEditInput Codable struct is defined
///   - NotebookEditTool.swift is created in Tools/Advanced/
/// TDD Phase: RED (feature not implemented yet)
final class NotebookEditToolTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a ToolContext with a temp directory as cwd.
    private func makeContext(cwd: String = "/tmp") -> ToolContext {
        return ToolContext(
            cwd: cwd,
            toolUseId: "test-tool-use-id"
        )
    }

    /// Creates a minimal valid .ipynb notebook at the given path.
    private func createTestNotebook(at path: String, cells: [[String: Any]] = []) throws {
        let notebook: [String: Any] = [
            "nbformat": 4,
            "nbformat_minor": 5,
            "metadata": [String: Any](),
            "cells": cells
        ]
        let data = try JSONSerialization.data(withJSONObject: notebook, options: .prettyPrinted)
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// Reads a .ipynb file and returns the parsed dictionary.
    private func readNotebook(at path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
    }

    /// Creates a temporary directory for test files.
    private func createTempDirectory() throws -> String {
        let tempDir = NSTemporaryDirectory()
            .appending("NotebookEditTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return tempDir
    }

    /// Creates a sample cell dictionary.
    private func makeCell(
        type: String = "code",
        source: [String] = [],
        outputs: [[String: Any]]? = nil,
        executionCount: Any? = NSNull()
    ) -> [String: Any] {
        var cell: [String: Any] = [
            "cell_type": type,
            "source": source,
            "metadata": [String: Any]()
        ]
        if type == "code" {
            cell["outputs"] = outputs ?? [[String: Any]]()
            cell["execution_count"] = executionCount
        }
        return cell
    }

    // MARK: - AC1: NotebookEdit Tool -- replace mode

    // MARK: AC1 -- Factory

    /// AC1 [P0]: createNotebookEditTool() returns a ToolProtocol with name "NotebookEdit".
    func testCreateNotebookEditTool_returnsToolProtocol() async throws {
        let tool = createNotebookEditTool()

        XCTAssertEqual(tool.name, "NotebookEdit")
        XCTAssertFalse(tool.description.isEmpty)
    }

    /// AC1 [P0]: NotebookEdit is NOT read-only (modifies .ipynb files, causing side effects).
    /// Also covers AC7.
    func testCreateNotebookEditTool_isNotReadOnly() async throws {
        let tool = createNotebookEditTool()
        XCTAssertFalse(tool.isReadOnly)
    }

    // MARK: AC1 -- Replace behavior

    /// AC1 [P0]: Replacing a cell's source content succeeds.
    func testNotebookEdit_replace_source_updatesCell() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["print('hello')\n"]),
            makeCell(type: "code", source: ["print('world')\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "replace",
            "cell_number": 0,
            "source": "print('updated')"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        // Verify the file was updated
        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        let source = updatedCells[0]["source"] as! [String]
        XCTAssertEqual(source, ["print('updated')"])
    }

    /// AC1 [P0]: Replacing a cell also updates cell_type when provided.
    func testNotebookEdit_replace_withCellType_updatesType() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["x = 1\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "replace",
            "cell_number": 0,
            "source": "# Markdown cell",
            "cell_type": "markdown"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        XCTAssertEqual(updatedCells[0]["cell_type"] as? String, "markdown")
    }

    /// AC1 [P1]: Replace preserves cell_type when not specified.
    func testNotebookEdit_replace_preservesCellType() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["old\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "replace",
            "cell_number": 0,
            "source": "new code"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        // cell_type should remain "code"
        XCTAssertEqual(updatedCells[0]["cell_type"] as? String, "code")
    }

    // MARK: - AC2: NotebookEdit Tool -- insert mode

    /// AC2 [P0]: Inserting a code cell at position 0 succeeds.
    func testNotebookEdit_insert_codeCell_atHead() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["existing\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "insert",
            "cell_number": 0,
            "source": "import numpy"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        XCTAssertEqual(updatedCells.count, 2)
        XCTAssertEqual(updatedCells[0]["cell_type"] as? String, "code")
        let source = updatedCells[0]["source"] as! [String]
        XCTAssertEqual(source, ["import numpy"])
    }

    /// AC2 [P0]: Inserting a markdown cell succeeds.
    func testNotebookEdit_insert_markdownCell() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        try createTestNotebook(at: notebookPath, cells: [])

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "insert",
            "cell_number": 0,
            "cell_type": "markdown",
            "source": "# Title"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        XCTAssertEqual(updatedCells.count, 1)
        XCTAssertEqual(updatedCells[0]["cell_type"] as? String, "markdown")
        let source = updatedCells[0]["source"] as! [String]
        XCTAssertEqual(source, ["# Title"])
    }

    /// AC2 [P0]: Inserted code cell has outputs and execution_count fields.
    func testNotebookEdit_insert_codeCell_hasOutputsAndExecutionCount() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        try createTestNotebook(at: notebookPath, cells: [])

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "insert",
            "cell_number": 0,
            "source": "x = 1"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        let insertedCell = updatedCells[0]

        // Code cells must have outputs (empty array) and execution_count (null)
        XCTAssertNotNil(insertedCell["outputs"])
        let outputs = insertedCell["outputs"] as? [[String: Any]]
        XCTAssertEqual(outputs?.count, 0)

        // execution_count should be NSNull (null in JSON)
        XCTAssertTrue(insertedCell["execution_count"] is NSNull)
    }

    /// AC2 [P1]: Inserted markdown cell does NOT have outputs or execution_count.
    func testNotebookEdit_insert_markdownCell_noOutputsFields() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        try createTestNotebook(at: notebookPath, cells: [])

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "insert",
            "cell_number": 0,
            "cell_type": "markdown",
            "source": "# Header"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        let insertedCell = updatedCells[0]

        // Markdown cells should NOT have outputs or execution_count
        XCTAssertNil(insertedCell["outputs"])
        XCTAssertNil(insertedCell["execution_count"])
    }

    /// AC2 [P0]: Inserting at the end of the cells array works.
    func testNotebookEdit_insert_atEnd() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["a\n"]),
            makeCell(type: "code", source: ["b\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "insert",
            "cell_number": 2,
            "source": "c"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        XCTAssertEqual(updatedCells.count, 3)
        let source = updatedCells[2]["source"] as! [String]
        XCTAssertEqual(source, ["c"])
    }

    /// AC2 [P0]: Default cell_type is "code" when not specified for insert.
    func testNotebookEdit_insert_defaultCellTypeIsCode() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        try createTestNotebook(at: notebookPath, cells: [])

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "insert",
            "cell_number": 0,
            "source": "x = 1"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        XCTAssertEqual(updatedCells[0]["cell_type"] as? String, "code")
    }

    // MARK: - AC3: NotebookEdit Tool -- delete mode

    /// AC3 [P0]: Deleting a middle cell succeeds.
    func testNotebookEdit_delete_middleCell() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["first\n"]),
            makeCell(type: "code", source: ["middle\n"]),
            makeCell(type: "code", source: ["last\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "delete",
            "cell_number": 1
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        XCTAssertEqual(updatedCells.count, 2)
        let source0 = updatedCells[0]["source"] as! [String]
        let source1 = updatedCells[1]["source"] as! [String]
        XCTAssertEqual(source0, ["first\n"])
        XCTAssertEqual(source1, ["last\n"])
    }

    /// AC3 [P0]: Deleting the first cell succeeds.
    func testNotebookEdit_delete_firstCell() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["first\n"]),
            makeCell(type: "code", source: ["second\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "delete",
            "cell_number": 0
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        XCTAssertEqual(updatedCells.count, 1)
        let source = updatedCells[0]["source"] as! [String]
        XCTAssertEqual(source, ["second\n"])
    }

    /// AC3 [P0]: Deleting the last cell succeeds.
    func testNotebookEdit_delete_lastCell() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["first\n"]),
            makeCell(type: "code", source: ["last\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "delete",
            "cell_number": 1
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        XCTAssertEqual(updatedCells.count, 1)
        let source = updatedCells[0]["source"] as! [String]
        XCTAssertEqual(source, ["first\n"])
    }

    /// AC3 [P0]: Deleting the only cell leaves an empty cells array.
    func testNotebookEdit_delete_onlyCell_leavesEmpty() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["only\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "delete",
            "cell_number": 0
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        XCTAssertTrue(updatedCells.isEmpty)
    }

    // MARK: - AC4: Error Handling -- invalid file/format

    /// AC4 [P0]: Operating on a non-existent file returns isError=true.
    func testNotebookEdit_fileNotFound_returnsError() async throws {
        let tool = createNotebookEditTool()
        let context = makeContext()

        let input: [String: Any] = [
            "file_path": "/tmp/nonexistent-\(UUID().uuidString).ipynb",
            "command": "replace",
            "cell_number": 0,
            "source": "test"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(
            result.content.contains("not found") ||
            result.content.contains("Not found") ||
            result.content.contains("Error") ||
            result.content.contains("No such file")
        )
    }

    /// AC4 [P0]: Operating on invalid JSON returns isError=true.
    func testNotebookEdit_invalidJSON_returnsError() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/bad.ipynb"
        try "this is not json".write(toFile: notebookPath, atomically: true, encoding: .utf8)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "replace",
            "cell_number": 0,
            "source": "test"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC4 [P0]: Operating on JSON without "cells" array returns isError=true.
    func testNotebookEdit_missingCellsKey_returnsError() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/nocells.ipynb"
        let data = try JSONSerialization.data(
            withJSONObject: ["nbformat": 4, "metadata": [String: Any]()],
            options: .prettyPrinted
        )
        try data.write(to: URL(fileURLWithPath: notebookPath))

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "replace",
            "cell_number": 0,
            "source": "test"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(
            result.content.contains("cells") ||
            result.content.contains("Cells")
        )
    }

    /// AC4 [P0]: Operating on JSON where "cells" is not an array returns isError=true.
    func testNotebookEdit_cellsNotArray_returnsError() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/badcells.ipynb"
        let data = try JSONSerialization.data(
            withJSONObject: ["nbformat": 4, "cells": "not an array"],
            options: .prettyPrinted
        )
        try data.write(to: URL(fileURLWithPath: notebookPath))

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "replace",
            "cell_number": 0,
            "source": "test"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    // MARK: - AC5: Error Handling -- out-of-bounds cell_number

    /// AC5 [P0]: Replace with out-of-bounds cell_number returns isError=true.
    func testNotebookEdit_replace_outOfBounds_returnsError() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["only\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "replace",
            "cell_number": 5,
            "source": "test"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(
            result.content.contains("does not exist") ||
            result.content.contains("out of range") ||
            result.content.contains("invalid") ||
            result.content.contains("Cell 5")
        )
    }

    /// AC5 [P0]: Delete with out-of-bounds cell_number returns isError=true.
    func testNotebookEdit_delete_outOfBounds_returnsError() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["only\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "delete",
            "cell_number": 99
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC5 [P0]: Replace on empty notebook (0 cells) returns isError=true.
    func testNotebookEdit_replace_emptyNotebook_returnsError() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/empty.ipynb"
        try createTestNotebook(at: notebookPath, cells: [])

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "replace",
            "cell_number": 0,
            "source": "test"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC5 [P0]: Insert with negative cell_number returns isError=true.
    func testNotebookEdit_insert_negativeCellNumber_returnsError() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [
            makeCell(type: "code", source: ["existing\n"])
        ]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "insert",
            "cell_number": -1,
            "source": "new cell"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("negative") || result.content.contains("cannot be negative"))
    }

    /// AC5 [P0]: Replace with negative cell_number returns isError=true (no crash).
    func testNotebookEdit_replace_negativeCellNumber_returnsError() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [makeCell(type: "code", source: ["test\n"])]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "replace",
            "cell_number": -1,
            "source": "updated"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    /// AC5 [P0]: Delete with negative cell_number returns isError=true (no crash).
    func testNotebookEdit_delete_negativeCellNumber_returnsError() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [makeCell(type: "code", source: ["test\n"])]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "delete",
            "cell_number": -1
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    // MARK: - AC6: inputSchema matches TS SDK

    /// AC6 [P0]: NotebookEdit inputSchema has correct structure.
    func testCreateNotebookEditTool_hasValidInputSchema() async throws {
        let tool = createNotebookEditTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")

        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        // Verify "file_path" field
        let filePathProp = properties?["file_path"] as? [String: Any]
        XCTAssertNotNil(filePathProp)
        XCTAssertEqual(filePathProp?["type"] as? String, "string")

        // Verify "command" field
        let commandProp = properties?["command"] as? [String: Any]
        XCTAssertNotNil(commandProp)
        XCTAssertEqual(commandProp?["type"] as? String, "string")
        let commandEnum = commandProp?["enum"] as? [String]
        XCTAssertEqual(commandEnum, ["insert", "replace", "delete"])

        // Verify "cell_number" field
        let cellNumberProp = properties?["cell_number"] as? [String: Any]
        XCTAssertNotNil(cellNumberProp)
        XCTAssertEqual(cellNumberProp?["type"] as? String, "number")

        // Verify "cell_type" field (optional)
        let cellTypeProp = properties?["cell_type"] as? [String: Any]
        XCTAssertNotNil(cellTypeProp)
        XCTAssertEqual(cellTypeProp?["type"] as? String, "string")
        let cellTypeEnum = cellTypeProp?["enum"] as? [String]
        XCTAssertEqual(cellTypeEnum, ["code", "markdown"])

        // Verify "source" field (optional)
        let sourceProp = properties?["source"] as? [String: Any]
        XCTAssertNotNil(sourceProp)
        XCTAssertEqual(sourceProp?["type"] as? String, "string")

        // Verify "cell_id" field (optional)
        let cellIdProp = properties?["cell_id"] as? [String: Any]
        XCTAssertNotNil(cellIdProp)
        XCTAssertEqual(cellIdProp?["type"] as? String, "string")

        // Verify required fields
        let required = schema["required"] as? [String]
        XCTAssertEqual(required, ["file_path", "command", "cell_number"])
    }

    // MARK: - AC7: isReadOnly classification

    /// AC7 [P0]: NotebookEdit isReadOnly returns false.
    func testNotebookEditTool_isReadOnly_false() async throws {
        let tool = createNotebookEditTool()
        XCTAssertFalse(tool.isReadOnly, "NotebookEdit should not be read-only (it writes to disk)")
    }

    // MARK: - AC8: Module boundary compliance

    /// AC8 [P1]: NotebookEditTool does not import Core/ or Stores/.
    /// Verified by design: tool only uses Foundation + Types/ (ToolContext, ToolExecuteResult).
    /// This test ensures the factory function can operate without any store injection.
    func testNotebookEditTool_moduleBoundary_noStoreRequired() async throws {
        let tool = createNotebookEditTool()

        // Tool should work with a plain ToolContext (no store injection needed)
        let context = ToolContext(cwd: "/tmp", toolUseId: "test-id")

        // Verify the tool was created successfully
        XCTAssertEqual(tool.name, "NotebookEdit")
        XCTAssertNotNil(context.cwd)
    }

    // MARK: - AC9: File path resolution

    /// AC9 [P0]: Relative file_path is resolved against context.cwd.
    func testNotebookEdit_relativePath_resolvesAgainstCwd() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        // Create notebook in a subdirectory
        let subDir = tempDir + "/subdir"
        try FileManager.default.createDirectory(
            atPath: subDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let cells = [
            makeCell(type: "code", source: ["test\n"])
        ]
        try createTestNotebook(at: subDir + "/notebook.ipynb", cells: cells)

        let tool = createNotebookEditTool()
        // Use cwd=tempDir, pass relative path "subdir/notebook.ipynb"
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": "subdir/notebook.ipynb",
            "command": "replace",
            "cell_number": 0,
            "source": "updated"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        // Verify the file was updated at the correct absolute path
        let updated = try readNotebook(at: subDir + "/notebook.ipynb")
        let updatedCells = updated["cells"] as! [[String: Any]]
        let source = updatedCells[0]["source"] as! [String]
        XCTAssertEqual(source, ["updated"])
    }

    // MARK: - AC10: Notebook format preservation

    /// AC10 [P0]: Source is split into [String] array (nbformat compliance).
    func testNotebookEdit_sourceSplit_multiLine() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        try createTestNotebook(at: notebookPath, cells: [])

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "insert",
            "cell_number": 0,
            "source": "line1\nline2\nline3"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)

        let updated = try readNotebook(at: notebookPath)
        let updatedCells = updated["cells"] as! [[String: Any]]
        let source = updatedCells[0]["source"] as! [String]

        // Source should be split: ["line1\n", "line2\n", "line3"]
        // Each line except the last should have a trailing \n
        XCTAssertEqual(source.count, 3)
        XCTAssertEqual(source[0], "line1\n")
        XCTAssertEqual(source[1], "line2\n")
        XCTAssertEqual(source[2], "line3")
    }

    /// AC10 [P0]: Written file uses pretty-printed JSON (readable format).
    func testNotebookEdit_output_prettyPrinted() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        try createTestNotebook(at: notebookPath, cells: [])

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "insert",
            "cell_number": 0,
            "source": "x = 1"
        ]
        _ = await tool.call(input: input, context: context)

        // Read the raw file content and verify it's pretty-printed (has newlines/indentation)
        let rawContent = try String(contentsOfFile: notebookPath, encoding: .utf8)
        XCTAssertTrue(rawContent.contains("\n"), "Output should be pretty-printed (contain newlines)")
        XCTAssertTrue(rawContent.contains("  ") || rawContent.contains("\t"),
                       "Output should be indented (pretty-printed)")
    }

    // MARK: - Error Handling: Never throws

    /// AC4 [P0]: NotebookEdit never throws -- always returns ToolResult even with malformed input.
    func testNotebookEdit_neverThrows_malformedInput() async throws {
        let tool = createNotebookEditTool()
        let context = makeContext()

        let badInputs: [[String: Any]] = [
            [:],  // missing all fields
            ["file_path": 123],  // wrong type
            ["file_path": "/tmp/test.ipynb", "command": "invalid", "cell_number": 0],  // invalid command
        ]

        for input in badInputs {
            let result = await tool.call(input: input, context: context)
            // Tool should always return a ToolResult, never throw
            XCTAssertEqual(result.toolUseId, "test-tool-use-id")
        }
    }

    /// AC4 [P0]: NotebookEdit returns isError for invalid command value.
    func testNotebookEdit_invalidCommand_returnsError() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [makeCell(type: "code", source: ["test\n"])]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "unknown_command",
            "cell_number": 0,
            "source": "test"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertTrue(result.isError)
    }

    // MARK: - Success message format

    /// AC1 [P1]: Replace success message mentions command and cell number.
    func testNotebookEdit_replace_successMessage_format() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [makeCell(type: "code", source: ["old\n"])]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "replace",
            "cell_number": 0,
            "source": "new"
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        // Should contain meaningful success info (command name + cell number)
        XCTAssertTrue(
            result.content.contains("replace") ||
            result.content.contains("Replace") ||
            result.content.contains("cell") ||
            result.content.contains("0")
        )
    }

    /// AC3 [P1]: Delete success message mentions the deleted cell.
    func testNotebookEdit_delete_successMessage_format() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let notebookPath = tempDir + "/test.ipynb"
        let cells = [makeCell(type: "code", source: ["to-delete\n"])]
        try createTestNotebook(at: notebookPath, cells: cells)

        let tool = createNotebookEditTool()
        let context = makeContext(cwd: tempDir)

        let input: [String: Any] = [
            "file_path": notebookPath,
            "command": "delete",
            "cell_number": 0
        ]
        let result = await tool.call(input: input, context: context)

        XCTAssertFalse(result.isError)
        XCTAssertTrue(
            result.content.contains("delete") ||
            result.content.contains("Delete")
        )
    }
}

import Foundation

// MARK: - NotebookEditTool Input

/// Input type for the NotebookEdit tool.
///
/// Field names match the TS SDK's NotebookEdit schema.
private struct NotebookEditInput: Codable {
    let file_path: String          // Required
    let command: String            // Required: "insert" | "replace" | "delete"
    let cell_number: Int           // Required, 0-based index
    let cell_type: String?         // Optional: "code" | "markdown"
    let source: String?            // Optional, cell content (used for insert/replace)
    let cell_id: String?           // Optional, cell ID (reserved for TS SDK schema matching)
}

// MARK: - NotebookEditTool Schema

private nonisolated(unsafe) let notebookEditSchema: ToolInputSchema = [
    "type": "object",
    "properties": [
        "file_path": [
            "type": "string",
            "description": "The absolute path to the notebook file to edit (must be absolute, not relative)"
        ] as [String: Any],
        "command": [
            "type": "string",
            "enum": ["insert", "replace", "delete"],
            "description": "The edit operation to perform"
        ] as [String: Any],
        "cell_number": [
            "type": "number",
            "description": "Cell index (0-based) to operate on"
        ] as [String: Any],
        "cell_type": [
            "type": "string",
            "enum": ["code", "markdown"],
            "description": "Type of cell (for insert/replace). Defaults to 'code'."
        ] as [String: Any],
        "source": [
            "type": "string",
            "description": "Cell content (for insert/replace)"
        ] as [String: Any],
        "cell_id": [
            "type": "string",
            "description": "Optional cell ID for the cell being edited"
        ] as [String: Any],
    ] as [String: Any],
    "required": ["file_path", "command", "cell_number"]
]

// MARK: - Source Split Helper

/// Splits source string into a `[String]` array per nbformat specification.
/// Each line except the last gets a trailing `\n`.
private func splitSource(_ source: String) -> [String] {
    let lines = source.components(separatedBy: "\n")
    return lines.enumerated().map { index, line in
        index < lines.count - 1 ? line + "\n" : line
    }
}

// MARK: - Factory Function

/// Creates the NotebookEdit tool for editing Jupyter Notebook (.ipynb) cells.
///
/// The NotebookEdit tool supports three commands:
/// - **insert**: Insert a new cell at the specified index (defaults to code type).
/// - **replace**: Replace a cell's source content and optionally its cell_type.
/// - **delete**: Remove a cell at the specified index.
///
/// **Architecture:** This tool only uses `Foundation` and `Types/` types.
/// It does not require any Store injection — it operates purely on the filesystem
/// using `context.cwd` for path resolution, consistent with FileReadTool/FileWriteTool.
///
/// - Returns: A ``ToolProtocol`` instance for the NotebookEdit tool.
public func createNotebookEditTool() -> ToolProtocol {
    return defineTool(
        name: "NotebookEdit",
        description:
            "Edit Jupyter Notebook (.ipynb) cells. Supports insert, replace, and delete operations. " +
            "Source content is split into line arrays per nbformat specification. " +
            "Relative paths are resolved against the current working directory.",
        inputSchema: notebookEditSchema,
        isReadOnly: false
    ) { (input: NotebookEditInput, context: ToolContext) async throws -> ToolExecuteResult in
        // Step 1: Resolve file path
        let resolvedPath = resolvePath(input.file_path, cwd: context.cwd)

        // Step 2: Read file content
        let fileContent: String
        do {
            fileContent = try String(contentsOfFile: resolvedPath, encoding: .utf8)
        } catch {
            return ToolExecuteResult(
                content: "Error: File not found or cannot be read: \(resolvedPath)",
                isError: true
            )
        }

        // Step 3: Parse JSON
        let notebook: [String: Any]
        do {
            guard let data = fileContent.data(using: .utf8) else {
                return ToolExecuteResult(
                    content: "Error: Failed to encode file content as UTF-8",
                    isError: true
                )
            }
            guard let parsed = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return ToolExecuteResult(
                    content: "Error: Notebook is not a valid JSON object",
                    isError: true
                )
            }
            notebook = parsed
        } catch {
            return ToolExecuteResult(
                content: "Error: Invalid JSON in notebook file: \(error.localizedDescription)",
                isError: true
            )
        }

        // Step 4: Validate cells array exists
        guard let cells = notebook["cells"] as? [[String: Any]] else {
            return ToolExecuteResult(
                content: "Error: Notebook does not contain a valid 'cells' array",
                isError: true
            )
        }

        // Step 5: Execute command
        var mutableCells = cells

        switch input.command {
        case "insert":
            let cellType = input.cell_type ?? "code"
            var newCell: [String: Any] = [
                "cell_type": cellType,
                "source": splitSource(input.source ?? ""),
                "metadata": [String: Any]()
            ]
            // Code cells include outputs and execution_count; markdown cells do not
            if cellType != "markdown" {
                newCell["outputs"] = [[String: Any]]()
                newCell["execution_count"] = NSNull()
            }
            // Guard against negative cell_number (would crash Array.insert)
            guard input.cell_number >= 0 else {
                return ToolExecuteResult(
                    content: "Error: Cell number cannot be negative: \(input.cell_number)",
                    isError: true
                )
            }
            // Clamp insert position to valid range
            let insertIndex = min(input.cell_number, mutableCells.count)
            mutableCells.insert(newCell, at: insertIndex)

        case "replace":
            guard input.cell_number >= 0, input.cell_number < mutableCells.count else {
                return ToolExecuteResult(
                    content: "Error: Cell \(input.cell_number) does not exist (notebook has \(mutableCells.count) cells)",
                    isError: true
                )
            }
            mutableCells[input.cell_number]["source"] = splitSource(input.source ?? "")
            if let cellType = input.cell_type {
                mutableCells[input.cell_number]["cell_type"] = cellType
            }

        case "delete":
            guard input.cell_number >= 0, input.cell_number < mutableCells.count else {
                return ToolExecuteResult(
                    content: "Error: Cell \(input.cell_number) does not exist (notebook has \(mutableCells.count) cells)",
                    isError: true
                )
            }
            mutableCells.remove(at: input.cell_number)

        default:
            return ToolExecuteResult(
                content: "Error: Invalid command '\(input.command)'. Must be 'insert', 'replace', or 'delete'.",
                isError: true
            )
        }

        // Step 6: Write back to file
        var outputNotebook = notebook
        outputNotebook["cells"] = mutableCells

        do {
            let outputData = try JSONSerialization.data(
                withJSONObject: outputNotebook,
                options: .prettyPrinted
            )
            try outputData.write(to: URL(fileURLWithPath: resolvedPath))
        } catch {
            return ToolExecuteResult(
                content: "Error: Failed to write notebook: \(error.localizedDescription)",
                isError: true
            )
        }

        return ToolExecuteResult(
            content: "Notebook \(input.command): cell \(input.cell_number) in \(resolvedPath)",
            isError: false
        )
    }
}

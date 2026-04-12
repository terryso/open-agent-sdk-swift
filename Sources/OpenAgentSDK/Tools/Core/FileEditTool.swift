import Foundation

// MARK: - Input

/// Input type for the Edit tool.
private struct FileEditInput: Codable {
    let file_path: String
    let old_string: String
    let new_string: String
}

// MARK: - Factory

/// Creates the Edit tool for replacing strings in files on the filesystem.
///
/// The Edit tool performs a targeted string replacement in an existing file.
/// The `old_string` must appear exactly once in the file; if it appears zero
/// or multiple times, an error is returned. This ensures replacements are
/// unambiguous and prevents unintended modifications.
/// Relative paths are resolved against `ToolContext.cwd`.
///
/// - Returns: A `ToolProtocol` instance for the Edit tool.
public func createEditTool() -> ToolProtocol {
    return defineTool(
        name: "Edit",
        description:
            "Replace a specific string in a file. " +
            "The old_string must be unique in the file (exactly one occurrence). " +
            "If old_string is not found or appears multiple times, an error is returned. " +
            "Relative paths are resolved against the current working directory.",
        inputSchema: [
            "type": "object",
            "properties": [
                "file_path": [
                    "type": "string",
                    "description": "The absolute path to the file to edit"
                ],
                "old_string": [
                    "type": "string",
                    "description": "The text to replace"
                ],
                "new_string": [
                    "type": "string",
                    "description": "The text to replace it with"
                ]
            ],
            "required": ["file_path", "old_string", "new_string"]
        ],
        isReadOnly: false
    ) { (input: FileEditInput, context: ToolContext) async throws -> ToolExecuteResult in
        let resolvedPath = resolvePath(input.file_path, cwd: context.cwd)
        let fileManager = FileManager.default

        // Check file exists and is not a directory
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDir)
        if !exists {
            return ToolExecuteResult(
                content: "Error: File not found: \(resolvedPath)",
                isError: true
            )
        }
        if isDir.boolValue {
            return ToolExecuteResult(
                content: "Error: \(resolvedPath) is a directory, not a file.",
                isError: true
            )
        }

        // Read file content
        let content: String
        do {
            content = try String(contentsOfFile: resolvedPath, encoding: .utf8)
        } catch {
            return ToolExecuteResult(
                content: "Error: Failed to read file '\(resolvedPath)': \(error.localizedDescription)",
                isError: true
            )
        }

        // Check for unique match
        guard !input.old_string.isEmpty else {
            return ToolExecuteResult(
                content: "Error: old_string must not be empty.",
                isError: true
            )
        }
        let occurrences = content.components(separatedBy: input.old_string).count - 1
        if occurrences == 0 {
            return ToolExecuteResult(
                content: "Error: old_string not found in \(resolvedPath)",
                isError: true
            )
        }
        if occurrences > 1 {
            return ToolExecuteResult(
                content: "Error: old_string appears \(occurrences) times in \(resolvedPath). Provide more context to make the match unique.",
                isError: true
            )
        }

        // Perform replacement
        let newContent = content.replacingOccurrences(
            of: input.old_string,
            with: input.new_string
        )

        // Write updated content
        do {
            try newContent.write(
                toFile: resolvedPath,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            return ToolExecuteResult(
                content: "Error: Failed to write file '\(resolvedPath)': \(error.localizedDescription)",
                isError: true
            )
        }

        // Invalidate cache entry after successful edit (AC5)
        context.fileCache?.invalidate(resolvedPath)

        return ToolExecuteResult(
            content: "Successfully edited \(resolvedPath)",
            isError: false
        )
    }
}

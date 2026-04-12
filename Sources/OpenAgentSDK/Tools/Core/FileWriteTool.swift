import Foundation

// MARK: - Input

/// Input type for the Write tool.
private struct FileWriteInput: Codable {
    let file_path: String
    let content: String
}

// MARK: - Factory

/// Creates the Write tool for writing content to files on the filesystem.
///
/// The Write tool creates or overwrites a file at the specified path.
/// If parent directories do not exist, they are created automatically.
/// Writes are performed atomically to ensure data integrity.
/// Relative paths are resolved against `ToolContext.cwd`.
///
/// - Returns: A `ToolProtocol` instance for the Write tool.
public func createWriteTool() -> ToolProtocol {
    return defineTool(
        name: "Write",
        description:
            "Write content to a file on the filesystem. " +
            "Creates the file if it does not exist, or overwrites it if it does. " +
            "Parent directories are created automatically if they do not exist. " +
            "Relative paths are resolved against the current working directory.",
        inputSchema: [
            "type": "object",
            "properties": [
                "file_path": [
                    "type": "string",
                    "description": "The absolute path to the file to write"
                ],
                "content": [
                    "type": "string",
                    "description": "The content to write to the file"
                ]
            ],
            "required": ["file_path", "content"]
        ],
        isReadOnly: false
    ) { (input: FileWriteInput, context: ToolContext) async throws -> ToolExecuteResult in
        let resolvedPath = resolvePath(input.file_path, cwd: context.cwd)

        // Sandbox: enforce write-path restrictions before file I/O
        if let sandbox = context.sandbox {
            try SandboxChecker.checkPath(resolvedPath, for: .write, settings: sandbox)
        }

        let fileManager = FileManager.default

        // Cancellation check: skip all file operations if task is already cancelled (FR60)
        if _Concurrency.Task.isCancelled {
            return ToolExecuteResult(
                content: "Error: Write cancelled before execution",
                isError: true
            )
        }

        // Create parent directories if they do not exist
        let directory = (resolvedPath as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: directory) {
            do {
                try fileManager.createDirectory(
                    atPath: directory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                return ToolExecuteResult(
                    content: "Error: Failed to create parent directory '\(directory)': \(error.localizedDescription)",
                    isError: true
                )
            }
        }

        // Write file atomically
        do {
            try input.content.write(
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

        // Invalidate cache entry after successful write (AC5)
        context.fileCache?.invalidate(resolvedPath)

        return ToolExecuteResult(
            content: "Successfully wrote \(input.content.count) characters to \(resolvedPath)",
            isError: false
        )
    }
}

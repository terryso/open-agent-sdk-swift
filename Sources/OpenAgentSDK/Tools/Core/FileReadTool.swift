import Foundation

// MARK: - Input

/// Input type for the Read tool.
private struct FileReadInput: Codable {
    let file_path: String
    let offset: Int?
    let limit: Int?
}

// MARK: - Factory

/// Creates the Read tool for reading file contents from the filesystem.
///
/// The Read tool returns file contents with line numbers in `cat -n` style
/// (line number followed by a tab, then the line content). It supports
/// pagination via `offset` (0-based) and `limit` parameters.
///
/// Special handling:
/// - Directories return an error suggesting `ls` instead.
/// - Image files (png/jpg/jpeg/gif/webp/bmp/svg) return a descriptive message.
/// - Relative paths are resolved against `ToolContext.cwd`.
///
/// - Returns: A `ToolProtocol` instance for the Read tool.
public func createReadTool() -> ToolProtocol {
    return defineTool(
        name: "Read",
        description:
            "Read a file from the filesystem. Returns content with line numbers. " +
            "Supports offset (0-based) and limit for pagination. " +
            "Relative paths are resolved against the current working directory.",
        inputSchema: [
            "type": "object",
            "properties": [
                "file_path": [
                    "type": "string",
                    "description": "The absolute path to the file to read"
                ],
                "offset": [
                    "type": "integer",
                    "description": "Line number to start reading from (0-based)"
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of lines to read"
                ]
            ],
            "required": ["file_path"]
        ],
        isReadOnly: true
    ) { (input: FileReadInput, context: ToolContext) async throws -> ToolExecuteResult in
        let resolvedPath = resolvePath(input.file_path, cwd: context.cwd)
        let fileManager = FileManager.default

        // Check if path is a directory
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDir)
        if isDir.boolValue {
            return ToolExecuteResult(
                content: "Error: \(resolvedPath) is a directory, not a file. Use Bash with 'ls' to list directory contents.",
                isError: true
            )
        }

        if !exists {
            return ToolExecuteResult(
                content: "Error: File not found: \(resolvedPath)",
                isError: true
            )
        }

        // Check for image file extensions
        let imageExtensions: Set<String> = [
            "png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"
        ]
        let ext = (resolvedPath as NSString).pathExtension.lowercased()
        if imageExtensions.contains(ext) {
            let attrs = try fileManager.attributesOfItem(atPath: resolvedPath)
            let size = attrs[.size] as? UInt64 ?? 0
            return ToolExecuteResult(
                content: "[Image file: \(resolvedPath) (\(size) bytes)]",
                isError: false
            )
        }

        // Read file content
        let content = try String(contentsOfFile: resolvedPath, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")

        // Apply pagination
        let startIndex = max(input.offset ?? 0, 0)
        let maxLimit = max(input.limit ?? 2000, 1)
        let clampedStart = min(startIndex, lines.count)
        let endIndex = min(clampedStart + maxLimit, lines.count)
        let selectedLines = Array(lines[clampedStart..<endIndex])

        // Format with line numbers (cat -n style: lineNum\tcontent)
        let numbered = selectedLines.enumerated().map { (index, line) in
            "\(clampedStart + index + 1)\t\(line)"
        }.joined(separator: "\n")

        return ToolExecuteResult(content: numbered, isError: false)
    }
}

// MARK: - Path Resolution Helper

/// Resolves a file path against a current working directory.
///
/// If the path is already absolute (starts with `/`), it is standardized.
/// Otherwise, it is resolved relative to `cwd` and then standardized.
/// Uses `NSString.standardizingPath` for POSIX-compliant handling of `.`, `..`,
/// and redundant slashes.
///
/// - Parameters:
///   - path: The file path to resolve (absolute or relative).
///   - cwd: The current working directory for resolving relative paths.
/// - Returns: The resolved absolute path.
func resolvePath(_ path: String, cwd: String) -> String {
    if path.hasPrefix("/") {
        return (path as NSString).standardizingPath
    }
    return ((cwd as NSString).appendingPathComponent(path) as NSString).standardizingPath
}

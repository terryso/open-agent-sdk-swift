import Foundation

// MARK: - Input

/// Input type for the Grep tool.
private struct GrepInput: Codable {
    let pattern: String
    let path: String?
    let glob: String?
    let type: String?
    let output_mode: String?
    let i: Bool?
    let head_limit: Int?
    let context: Int?
    let A: Int?   // lines after
    let B: Int?   // lines before

    private enum CodingKeys: String, CodingKey {
        case pattern, path, glob, type, output_mode
        case i = "-i"
        case head_limit
        case context = "-C"
        case A = "-A"
        case B = "-B"
    }

    // Computed: effective context lines before/after
    var linesAfter: Int {
        if let context = context, context > 0 { return max(context, 0) }
        return max(A ?? 0, 0)
    }

    var linesBefore: Int {
        if let context = context, context > 0 { return max(context, 0) }
        return max(B ?? 0, 0)
    }

    var caseInsensitive: Bool { i ?? false }

    var effectiveOutputMode: String { output_mode ?? "files_with_matches" }

    var effectiveHeadLimit: Int { max(head_limit ?? 250, 0) }
}

// MARK: - Factory

/// Creates the Grep tool for searching file contents with regex patterns.
///
/// The Grep tool searches files for lines matching a regular expression pattern
/// and returns results in various output modes. It supports file type filtering,
/// case-insensitive search, context lines, and output limits.
///
/// Special handling:
/// - Hidden directories (starting with `.`) are skipped during traversal.
/// - Binary files (determined by extension) are skipped.
/// - Invalid regex patterns return `isError: true`.
/// - Relative paths in the `path` parameter are resolved against `ToolContext.cwd`.
/// - No matches returns a descriptive message instead of an empty string or error.
///
/// - Returns: A `ToolProtocol` instance for the Grep tool.
public func createGrepTool() -> ToolProtocol {
    return defineTool(
        name: "Grep",
        description:
            "Search file contents using a regular expression pattern. " +
            "Returns matching lines with file paths and line numbers. " +
            "Supports output modes: files_with_matches (default), content, count. " +
            "Supports glob and type filters, case-insensitive search, context lines, " +
            "and head_limit for output truncation. " +
            "Relative paths are resolved against the current working directory.",
        inputSchema: [
            "type": "object",
            "properties": [
                "pattern": [
                    "type": "string",
                    "description": "The regular expression pattern to search for"
                ],
                "path": [
                    "type": "string",
                    "description": "The directory to search in (defaults to cwd)"
                ],
                "glob": [
                    "type": "string",
                    "description": "Glob pattern to filter files (e.g., \"*.swift\")"
                ],
                "type": [
                    "type": "string",
                    "description": "File extension to search (e.g., \"swift\", \"ts\")"
                ],
                "output_mode": [
                    "type": "string",
                    "description": "Output format: \"files_with_matches\", \"content\", or \"count\" (default: files_with_matches)"
                ],
                "-i": [
                    "type": "boolean",
                    "description": "Case-insensitive search"
                ],
                "head_limit": [
                    "type": "integer",
                    "description": "Maximum number of results to return (default: 250)"
                ],
                "-C": [
                    "type": "integer",
                    "description": "Number of context lines before and after match"
                ],
                "-A": [
                    "type": "integer",
                    "description": "Number of lines after match"
                ],
                "-B": [
                    "type": "integer",
                    "description": "Number of lines before match"
                ]
            ],
            "required": ["pattern"]
        ],
        isReadOnly: true
    ) { (input: GrepInput, context: ToolContext) async throws -> ToolExecuteResult in
        let searchDir: String
        if let customPath = input.path {
            searchDir = resolvePath(customPath, cwd: context.cwd)
        } else {
            searchDir = context.cwd
        }

        // Sandbox: enforce read-path restrictions before directory enumeration
        if let sandbox = context.sandbox {
            try SandboxChecker.checkPath(searchDir, for: .read, settings: sandbox)
        }

        let fileManager = FileManager.default

        // Check that search directory exists
        var isDir: ObjCBool = false
        let dirExists = fileManager.fileExists(atPath: searchDir, isDirectory: &isDir)
        if !dirExists || !isDir.boolValue {
            return ToolExecuteResult(
                content: "Error: Directory not found: \(searchDir)",
                isError: true
            )
        }

        // Validate regex pattern
        let regexOptions: NSRegularExpression.Options = input.caseInsensitive
            ? [.caseInsensitive]
            : []
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: input.pattern, options: regexOptions)
        } catch {
            return ToolExecuteResult(
                content: "Error: Invalid regular expression: \(error.localizedDescription)",
                isError: true
            )
        }

        // Collect files to search
        var filesToSearch: [String] = []
        guard let enumerator = fileManager.enumerator(atPath: searchDir) else {
            return ToolExecuteResult(
                content: "Error: Failed to enumerate directory: \(searchDir)",
                isError: true
            )
        }

        // Binary file extensions to skip
        let binaryExtensions: Set<String> = [
            "png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "ico",
            "pdf", "zip", "gz", "tar", "rar", "7z",
            "class", "jar", "war", "o", "so", "dylib", "dll", "exe",
            "woff", "woff2", "ttf", "eot",
            "mp3", "mp4", "avi", "mov", "wav", "flac",
            "dat", "bin", "pyc"
        ]

        while let relativePath = enumerator.nextObject() as? String {
            // Skip hidden directories and common large directories
            let components = relativePath.components(separatedBy: "/")
            let shouldSkip = components.contains { component in
                component.hasPrefix(".") || component == "node_modules"
            }
            if shouldSkip {
                // Skip descending into this directory entirely
                let fullPath = (searchDir as NSString).appendingPathComponent(relativePath)
                var itemIsDir: ObjCBool = false
                fileManager.fileExists(atPath: fullPath, isDirectory: &itemIsDir)
                if itemIsDir.boolValue {
                    enumerator.skipDescendants()
                }
                continue
            }

            let fullPath = (searchDir as NSString).appendingPathComponent(relativePath)

            // Skip directories
            var itemIsDir: ObjCBool = false
            fileManager.fileExists(atPath: fullPath, isDirectory: &itemIsDir)
            if itemIsDir.boolValue {
                continue
            }

            // Skip binary files by extension
            let ext = (relativePath as NSString).pathExtension.lowercased()
            if binaryExtensions.contains(ext) {
                continue
            }

            // Apply file type filters
            if !grepMatchesFileType(relativePath, glob: input.glob, type: input.type) {
                continue
            }

            filesToSearch.append(fullPath)
        }

        // Search files and collect results
        let outputMode = input.effectiveOutputMode
        let headLimit = input.effectiveHeadLimit
        let linesBefore = input.linesBefore
        let linesAfter = input.linesAfter

        var matchedFiles: [String] = []            // for files_with_matches
        var contentResults: [String] = []          // for content mode
        var countResults: [String] = []            // for count mode
        var totalOutputLines = 0

        for filePath in filesToSearch {
            // Read file content
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                continue
            }

            let lines = content.components(separatedBy: "\n")
            var matchCount = 0
            var matchedLineNumbers: [Int] = []

            // Find all matching lines
            for (lineIndex, line) in lines.enumerated() {
                let lineRange = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, range: lineRange) != nil {
                    matchCount += 1
                    matchedLineNumbers.append(lineIndex)
                }
            }

            if matchCount == 0 {
                continue
            }

            switch outputMode {
            case "files_with_matches":
                matchedFiles.append(filePath)

            case "content":
                for lineNum in matchedLineNumbers {
                    if totalOutputLines >= headLimit && headLimit > 0 {
                        break
                    }

                    // Add context lines before
                    let beforeStart = max(0, lineNum - linesBefore)
                    for ctxLineNum in beforeStart..<lineNum {
                        if totalOutputLines >= headLimit && headLimit > 0 { break }
                        let lineContent = lines[ctxLineNum]
                        contentResults.append("\(filePath):\(ctxLineNum + 1):\(lineContent)")
                        totalOutputLines += 1
                    }

                    if totalOutputLines >= headLimit && headLimit > 0 { break }

                    // Add matched line
                    let lineContent = lines[lineNum]
                    contentResults.append("\(filePath):\(lineNum + 1):\(lineContent)")
                    totalOutputLines += 1

                    // Add context lines after
                    let afterEnd = min(lines.count, lineNum + linesAfter + 1)
                    for ctxLineNum in (lineNum + 1)..<afterEnd {
                        if totalOutputLines >= headLimit && headLimit > 0 { break }
                        let lineContent = lines[ctxLineNum]
                        contentResults.append("\(filePath):\(ctxLineNum + 1):\(lineContent)")
                        totalOutputLines += 1
                    }
                }

            case "count":
                if countResults.count < headLimit || headLimit == 0 {
                    countResults.append("\(filePath):\(matchCount)")
                }

            default:
                matchedFiles.append(filePath)
            }

            // Early exit if we have enough output
            if outputMode == "files_with_matches" && matchedFiles.count >= headLimit && headLimit > 0 {
                break
            }
            if totalOutputLines >= headLimit && headLimit > 0 && outputMode == "content" {
                break
            }
        }

        // Build result string
        let resultContent: String
        switch outputMode {
        case "files_with_matches":
            if matchedFiles.isEmpty {
                return ToolExecuteResult(
                    content: "No files matched the pattern \"\(input.pattern)\".",
                    isError: false
                )
            }
            resultContent = matchedFiles.joined(separator: "\n")

        case "content":
            if contentResults.isEmpty {
                return ToolExecuteResult(
                    content: "No matches found for pattern \"\(input.pattern)\".",
                    isError: false
                )
            }
            resultContent = contentResults.joined(separator: "\n")

        case "count":
            if countResults.isEmpty {
                return ToolExecuteResult(
                    content: "No matches found for pattern \"\(input.pattern)\".",
                    isError: false
                )
            }
            resultContent = countResults.joined(separator: "\n")

        default:
            if matchedFiles.isEmpty {
                return ToolExecuteResult(
                    content: "No files matched the pattern \"\(input.pattern)\".",
                    isError: false
                )
            }
            resultContent = matchedFiles.joined(separator: "\n")
        }

        return ToolExecuteResult(content: resultContent, isError: false)
    }
}

// MARK: - File Type Filter

/// Checks if a file path matches the glob and/or type filters.
///
/// - Parameters:
///   - filePath: The relative file path to check.
///   - glob: Optional glob pattern for filtering files (e.g., `"*.swift"`).
///   - type: Optional file extension to filter (e.g., `"swift"`, `"ts"`).
/// - Returns: `true` if the file matches all provided filters.
private func grepMatchesFileType(_ filePath: String, glob: String?, type: String?) -> Bool {
    if let type = type {
        let ext = (filePath as NSString).pathExtension.lowercased()
        if ext != type.lowercased() { return false }
    }
    if let glob = glob {
        let fileName = (filePath as NSString).lastPathComponent
        return matchesGlob(fileName, pattern: glob)
    }
    return true
}

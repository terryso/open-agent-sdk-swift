import Foundation

// MARK: - Input

/// Input type for the Glob tool.
private struct GlobInput: Codable {
    let pattern: String
    let path: String?
}

// MARK: - Factory

/// Creates the Glob tool for finding files matching a glob pattern.
///
/// The Glob tool searches for files matching a glob pattern (e.g., `"**/*.swift"`,
/// `"src/**/*.js"`) and returns matching file paths sorted by modification time
/// (newest first). Results are limited to 500 matches.
///
/// Special handling:
/// - Hidden directories (starting with `.`) are skipped during traversal.
/// - Directories that are typically large (`node_modules`) are skipped.
/// - Relative paths in the `path` parameter are resolved against `ToolContext.cwd`.
/// - No matches returns a descriptive message instead of an empty string or error.
///
/// - Returns: A `ToolProtocol` instance for the Glob tool.
public func createGlobTool() -> ToolProtocol {
    return defineTool(
        name: "Glob",
        description:
            "Find files matching a glob pattern. Returns matching file paths sorted by " +
            "modification time (newest first). Supports patterns like \"**/*.swift\", " +
            "\"src/**/*.js\". Results are limited to 500 matches. " +
            "Relative paths are resolved against the current working directory.",
        inputSchema: [
            "type": "object",
            "properties": [
                "pattern": [
                    "type": "string",
                    "description": "The glob pattern to match files against"
                ],
                "path": [
                    "type": "string",
                    "description": "The directory to search in (defaults to cwd)"
                ]
            ],
            "required": ["pattern"]
        ],
        isReadOnly: true
    ) { (input: GlobInput, context: ToolContext) async throws -> ToolExecuteResult in
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

        // Collect matching files
        let maxResults = 500
        var matchesWithDates: [(path: String, modDate: Date)] = []

        guard let enumerator = fileManager.enumerator(atPath: searchDir) else {
            return ToolExecuteResult(
                content: "Error: Failed to enumerate directory: \(searchDir)",
                isError: true
            )
        }

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

            // Skip directories (only match files)
            var itemIsDir: ObjCBool = false
            fileManager.fileExists(atPath: fullPath, isDirectory: &itemIsDir)
            if itemIsDir.boolValue {
                continue
            }

            // Check if file matches glob pattern
            if matchesGlob(relativePath, pattern: input.pattern) {
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                   let modDate = attrs[.modificationDate] as? Date {
                    matchesWithDates.append((fullPath, modDate))
                } else {
                    matchesWithDates.append((fullPath, Date.distantPast))
                }
            }
        }

        // Handle empty results
        if matchesWithDates.isEmpty {
            return ToolExecuteResult(
                content: "No files matched the pattern \"\(input.pattern)\".",
                isError: false
            )
        }

        // Sort by modification time (newest first) then truncate to maxResults
        matchesWithDates.sort { $0.modDate > $1.modDate }
        if matchesWithDates.count > maxResults {
            matchesWithDates = Array(matchesWithDates.prefix(maxResults))
        }

        let resultContent = matchesWithDates.map { $0.path }.joined(separator: "\n")
        return ToolExecuteResult(content: resultContent, isError: false)
    }
}

// MARK: - Glob Pattern Matching

/// Matches a file path against a glob pattern.
///
/// Converts the glob pattern to a regular expression:
/// - `**` matches any depth of path components (including zero)
/// - `*` matches any characters except `/`
/// - `?` matches a single character except `/`
/// - Other characters are escaped as needed
///
/// - Parameters:
///   - path: The relative file path to test.
///   - pattern: The glob pattern (e.g., `"**/*.swift"`).
/// - Returns: `true` if the path matches the pattern.
func matchesGlob(_ path: String, pattern: String) -> Bool {
    var regexPattern = ""
    var i = pattern.startIndex

    while i < pattern.endIndex {
        let char = pattern[i]
        let nextIndex = pattern.index(after: i)

        if char == "*" && nextIndex < pattern.endIndex && pattern[nextIndex] == "*" {
            // ** -> match any depth (including zero path segments)
            regexPattern += ".*"
            i = pattern.index(after: nextIndex)
            // Skip trailing / after ** so **/*.swift works correctly
            if i < pattern.endIndex && pattern[i] == "/" {
                regexPattern += "/?"
                i = pattern.index(after: i)
            }
        } else if char == "*" {
            // * -> match any characters except /
            regexPattern += "[^/]*"
            i = nextIndex
        } else if char == "?" {
            // ? -> match single character except /
            regexPattern += "[^/]"
            i = nextIndex
        } else if "{}[]().^$+|\\".contains(char) {
            // Escape regex special characters
            regexPattern += "\\\(char)"
            i = nextIndex
        } else {
            regexPattern.append(char)
            i = nextIndex
        }
    }

    guard let regex = try? NSRegularExpression(pattern: "^" + regexPattern + "$") else {
        return false
    }
    let fullRange = NSRange(path.startIndex..., in: path)
    return regex.firstMatch(in: path, range: fullRange) != nil
}

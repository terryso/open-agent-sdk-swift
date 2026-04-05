import Foundation

// MARK: - defineTool Factory Function

/// Creates a `ToolProtocol` from a generic Codable input type and an execute closure.
///
/// This factory function bridges the LLM's raw JSON input (received as `[String: Any]`)
/// to Swift's type-safe `Codable` system. The `call()` method on the returned tool
/// performs the following steps:
/// 1. Casts the raw `Any` input to `[String: Any]`
/// 2. Serializes the dictionary to JSON `Data` via `JSONSerialization`
/// 3. Decodes the data into the `Input` type via `JSONDecoder`
/// 4. Invokes the `execute` closure with the decoded input and context
///
/// If any step fails (non-dictionary input, serialization failure, or decoding error),
/// the tool returns a `ToolResult` with `isError: true` instead of crashing.
///
/// - Parameters:
///   - name: The tool's unique name identifier.
///   - description: A human-readable description of the tool.
///   - inputSchema: The JSON Schema describing the tool's input format.
///   - isReadOnly: Whether the tool only reads data without side effects. Defaults to `false`.
///   - execute: A closure that takes the decoded `Input` and a `ToolContext`,
///     returning the tool's output as a `String`.
/// - Returns: A `ToolProtocol` instance that performs Codable bridging in its `call()` method.
public func defineTool<Input: Codable>(
    name: String,
    description: String,
    inputSchema: ToolInputSchema,
    isReadOnly: Bool = false,
    execute: @Sendable @escaping (Input, ToolContext) async -> String
) -> ToolProtocol {
    return CodableTool(
        name: name,
        description: description,
        inputSchema: inputSchema,
        isReadOnly: isReadOnly,
        execute: execute
    )
}

// MARK: - CodableTool (Internal Implementation)

/// Internal implementation of `ToolProtocol` that bridges raw JSON to Codable types.
///
/// This struct captures the generic `Input` type and `execute` closure, performing
/// JSONSerialization + JSONDecoder bridging in its `call()` method.
///
/// Uses `@unchecked Sendable` because `inputSchema` contains `[String: Any]` dictionaries
/// that are immutable, value-type dictionaries without shared mutable state concerns.
private struct CodableTool<Input: Codable>: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema
    let isReadOnly: Bool

    private let executeClosure: @Sendable (Input, ToolContext) async -> String

    init(
        name: String,
        description: String,
        inputSchema: ToolInputSchema,
        isReadOnly: Bool,
        execute: @Sendable @escaping (Input, ToolContext) async -> String
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.isReadOnly = isReadOnly
        self.executeClosure = execute
    }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        // Step 1: Cast raw input to dictionary
        guard let dict = input as? [String: Any] else {
            return ToolResult(
                toolUseId: "",
                content: "Error: Expected dictionary input, got \(type(of: input))",
                isError: true
            )
        }

        // Step 2: Serialize dictionary to JSON Data
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: dict, options: [])
        } catch {
            return ToolResult(
                toolUseId: "",
                content: "Error: Failed to serialize input - \(error.localizedDescription)",
                isError: true
            )
        }

        // Step 3: Decode JSON Data into Codable Input type
        let decoded: Input
        do {
            decoded = try JSONDecoder().decode(Input.self, from: data)
        } catch {
            return ToolResult(
                toolUseId: "",
                content: "Failed to decode input: \(error.localizedDescription)",
                isError: true
            )
        }

        // Step 4: Invoke execute closure with decoded input
        let result = await executeClosure(decoded, context)
        return ToolResult(
            toolUseId: "",
            content: result,
            isError: false
        )
    }
}

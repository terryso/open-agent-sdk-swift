import Foundation

// MARK: - defineTool Factory Function (String return)

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
/// If any step fails (non-dictionary input, serialization failure, decoding error,
/// or closure throwing an exception), the tool returns a `ToolResult` with
/// `isError: true` instead of crashing the agent loop.
///
/// - Parameters:
///   - name: The tool's unique name identifier.
///   - description: A human-readable description of the tool.
///   - inputSchema: The JSON Schema describing the tool's input format.
///   - isReadOnly: Whether the tool only reads data without side effects. Defaults to `false`.
///   - annotations: Optional hints describing the tool's behavior. Defaults to `nil`.
///   - execute: A closure that takes the decoded `Input` and a `ToolContext`,
///     returning the tool's output as a `String`.
/// - Returns: A `ToolProtocol` instance that performs Codable bridging in its `call()` method.
public func defineTool<Input: Codable>(
    name: String,
    description: String,
    inputSchema: ToolInputSchema,
    isReadOnly: Bool = false,
    annotations: ToolAnnotations? = nil,
    execute: @Sendable @escaping (Input, ToolContext) async throws -> String
) -> ToolProtocol {
    return CodableTool(
        name: name,
        description: description,
        inputSchema: inputSchema,
        isReadOnly: isReadOnly,
        annotations: annotations,
        execute: execute
    )
}

// MARK: - defineTool Factory Function (ToolExecuteResult return)

/// Creates a `ToolProtocol` from a generic Codable input type and a structured execute closure.
///
/// This overload accepts a closure that returns ``ToolExecuteResult`` instead of a plain
/// `String`, allowing the closure to explicitly signal success or error via the
/// ``ToolExecuteResult/isError`` field.
///
/// - Parameters:
///   - name: The tool's unique name identifier.
///   - description: A human-readable description of the tool.
///   - inputSchema: The JSON Schema describing the tool's input format.
///   - isReadOnly: Whether the tool only reads data without side effects. Defaults to `false`.
///   - annotations: Optional hints describing the tool's behavior. Defaults to `nil`.
///   - execute: A closure that takes the decoded `Input` and a `ToolContext`,
///     returning a ``ToolExecuteResult`` with content and isError fields.
/// - Returns: A `ToolProtocol` instance that performs Codable bridging in its `call()` method.
public func defineTool<Input: Codable>(
    name: String,
    description: String,
    inputSchema: ToolInputSchema,
    isReadOnly: Bool = false,
    annotations: ToolAnnotations? = nil,
    execute: @Sendable @escaping (Input, ToolContext) async throws -> ToolExecuteResult
) -> ToolProtocol {
    return StructuredCodableTool(
        name: name,
        description: description,
        inputSchema: inputSchema,
        isReadOnly: isReadOnly,
        annotations: annotations,
        execute: execute
    )
}

// MARK: - defineTool Factory Function (No-Input convenience)

/// Creates a `ToolProtocol` without a Codable input type.
///
/// This convenience overload is for tools that do not require structured input
/// (e.g., health checks, list operations). The execute closure receives only
/// a ``ToolContext`` and returns a `String`.
///
/// - Parameters:
///   - name: The tool's unique name identifier.
///   - description: A human-readable description of the tool.
///   - inputSchema: The JSON Schema describing the tool's input format (typically empty object).
///   - isReadOnly: Whether the tool only reads data without side effects. Defaults to `false`.
///   - annotations: Optional hints describing the tool's behavior. Defaults to `nil`.
///   - execute: A closure that takes a ``ToolContext`` and returns the tool's output as a `String`.
/// - Returns: A `ToolProtocol` instance that ignores input and invokes the closure with context only.
public func defineTool(
    name: String,
    description: String,
    inputSchema: ToolInputSchema,
    isReadOnly: Bool = false,
    annotations: ToolAnnotations? = nil,
    execute: @Sendable @escaping (ToolContext) async throws -> String
) -> ToolProtocol {
    return NoInputTool(
        name: name,
        description: description,
        inputSchema: inputSchema,
        isReadOnly: isReadOnly,
        annotations: annotations,
        execute: execute
    )
}

// MARK: - RawInputTool (Internal Implementation — Raw Dictionary Input)

/// Internal implementation of `ToolProtocol` for closures that receive raw `[String: Any]` input.
///
/// Unlike `CodableTool`, this implementation skips Codable decoding and passes the raw
/// dictionary directly to the execute closure. This is needed for tools whose input schema
/// contains fields of arbitrary type (e.g., `value` in ConfigTool that can be any JSON type).
private struct RawInputTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema
    let isReadOnly: Bool
    let annotations: ToolAnnotations?

    private let executeClosure: @Sendable ([String: Any], ToolContext) async -> ToolExecuteResult

    init(
        name: String,
        description: String,
        inputSchema: ToolInputSchema,
        isReadOnly: Bool,
        annotations: ToolAnnotations?,
        execute: @Sendable @escaping ([String: Any], ToolContext) async -> ToolExecuteResult
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.isReadOnly = isReadOnly
        self.annotations = annotations
        self.executeClosure = execute
    }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        guard let dict = input as? [String: Any] else {
            return ToolResult(
                toolUseId: context.toolUseId,
                content: "Error: Expected dictionary input, got \(type(of: input))",
                isError: true
            )
        }

        let result = await executeClosure(dict, context)
        if let typedContent = result.typedContent {
            return ToolResult(
                toolUseId: context.toolUseId,
                typedContent: typedContent,
                isError: result.isError
            )
        }
        return ToolResult(
            toolUseId: context.toolUseId,
            content: result.content,
            isError: result.isError
        )
    }
}

// MARK: - defineTool Factory Function (Raw Dictionary Input)

/// Creates a `ToolProtocol` from a closure that receives raw `[String: Any]` input.
///
/// This overload skips Codable decoding and passes the raw dictionary directly to the
/// execute closure. Use this for tools whose input schema contains fields of arbitrary
/// type (e.g., `value` in ConfigTool that can be string, number, boolean, array, object, or null).
///
/// - Parameters:
///   - name: The tool's unique name identifier.
///   - description: A human-readable description of the tool.
///   - inputSchema: The JSON Schema describing the tool's input format.
///   - isReadOnly: Whether the tool only reads data without side effects. Defaults to `false`.
///   - annotations: Optional hints describing the tool's behavior. Defaults to `nil`.
///   - execute: A closure that takes a raw `[String: Any]` dictionary and a `ToolContext`,
///     returning a ``ToolExecuteResult`` with content and isError fields.
/// - Returns: A `ToolProtocol` instance that passes raw input to the closure.
public func defineTool(
    name: String,
    description: String,
    inputSchema: ToolInputSchema,
    isReadOnly: Bool = false,
    annotations: ToolAnnotations? = nil,
    execute: @Sendable @escaping ([String: Any], ToolContext) async -> ToolExecuteResult
) -> ToolProtocol {
    return RawInputTool(
        name: name,
        description: description,
        inputSchema: inputSchema,
        isReadOnly: isReadOnly,
        annotations: annotations,
        execute: execute
    )
}

// MARK: - CodableTool (Internal Implementation — String return)

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
    let annotations: ToolAnnotations?

    private let executeClosure: @Sendable (Input, ToolContext) async throws -> String

    init(
        name: String,
        description: String,
        inputSchema: ToolInputSchema,
        isReadOnly: Bool,
        annotations: ToolAnnotations?,
        execute: @Sendable @escaping (Input, ToolContext) async throws -> String
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.isReadOnly = isReadOnly
        self.annotations = annotations
        self.executeClosure = execute
    }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        // Step 1: Cast raw input to dictionary
        guard let dict = input as? [String: Any] else {
            return ToolResult(
                toolUseId: context.toolUseId,
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
                toolUseId: context.toolUseId,
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
                toolUseId: context.toolUseId,
                content: "Failed to decode input: \(error.localizedDescription)",
                isError: true
            )
        }

        // Step 4: Invoke execute closure with decoded input (wrapped in do/catch)
        do {
            let result = try await executeClosure(decoded, context)
            return ToolResult(
                toolUseId: context.toolUseId,
                content: result,
                isError: false
            )
        } catch {
            return ToolResult(
                toolUseId: context.toolUseId,
                content: "Error: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}

// MARK: - StructuredCodableTool (Internal Implementation — ToolExecuteResult return)

/// Internal implementation of `ToolProtocol` for closures returning ``ToolExecuteResult``.
///
/// Similar to ``CodableTool`` but maps the structured result to ``ToolResult``,
/// preserving the ``ToolExecuteResult/isError`` flag from the closure.
private struct StructuredCodableTool<Input: Codable>: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema
    let isReadOnly: Bool
    let annotations: ToolAnnotations?

    private let executeClosure: @Sendable (Input, ToolContext) async throws -> ToolExecuteResult

    init(
        name: String,
        description: String,
        inputSchema: ToolInputSchema,
        isReadOnly: Bool,
        annotations: ToolAnnotations?,
        execute: @Sendable @escaping (Input, ToolContext) async throws -> ToolExecuteResult
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.isReadOnly = isReadOnly
        self.annotations = annotations
        self.executeClosure = execute
    }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        // Step 1: Cast raw input to dictionary
        guard let dict = input as? [String: Any] else {
            return ToolResult(
                toolUseId: context.toolUseId,
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
                toolUseId: context.toolUseId,
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
                toolUseId: context.toolUseId,
                content: "Failed to decode input: \(error.localizedDescription)",
                isError: true
            )
        }

        // Step 4: Invoke execute closure and map structured result to ToolResult
        do {
            let result = try await executeClosure(decoded, context)
            if let typedContent = result.typedContent {
                return ToolResult(
                    toolUseId: context.toolUseId,
                    typedContent: typedContent,
                    isError: result.isError
                )
            }
            return ToolResult(
                toolUseId: context.toolUseId,
                content: result.content,
                isError: result.isError
            )
        } catch {
            return ToolResult(
                toolUseId: context.toolUseId,
                content: "Error: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}

// MARK: - NoInputTool (Internal Implementation — No Codable Input)

/// Internal implementation of `ToolProtocol` for tools that do not require structured input.
///
/// The `call()` method ignores the input dictionary and invokes the closure with
/// only the ``ToolContext``.
private struct NoInputTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema
    let isReadOnly: Bool
    let annotations: ToolAnnotations?

    private let executeClosure: @Sendable (ToolContext) async throws -> String

    init(
        name: String,
        description: String,
        inputSchema: ToolInputSchema,
        isReadOnly: Bool,
        annotations: ToolAnnotations?,
        execute: @Sendable @escaping (ToolContext) async throws -> String
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.isReadOnly = isReadOnly
        self.annotations = annotations
        self.executeClosure = execute
    }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        do {
            let result = try await executeClosure(context)
            return ToolResult(
                toolUseId: context.toolUseId,
                content: result,
                isError: false
            )
        } catch {
            return ToolResult(
                toolUseId: context.toolUseId,
                content: "Error: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}

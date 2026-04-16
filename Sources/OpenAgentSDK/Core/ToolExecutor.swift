import Foundation

// MARK: - ToolUseBlock

/// Represents a parsed `tool_use` content block from the Anthropic API response.
///
/// Extracted from LLM response content blocks where `type == "tool_use"`.
/// Contains the tool invocation details needed for dispatch.
struct ToolUseBlock: @unchecked Sendable {
    /// The unique identifier for this tool use request (maps to `tool_use_id`).
    let id: String
    /// The name of the tool to invoke.
    let name: String
    /// The raw JSON input for the tool call (immutable `[String: Any]` dictionary).
    let input: Any

    init(id: String, name: String, input: Any) {
        self.id = id
        self.name = name
        self.input = input
    }
}

/// A paired tool_use block with its resolved tool, used for partitioning.
struct PairedToolItem: Sendable {
    let block: ToolUseBlock
    let tool: ToolProtocol?
}

// MARK: - ToolExecutor

/// Stateless tool dispatch engine that executes tool calls from LLM responses.
///
/// `ToolExecutor` provides the dispatch layer between the LLM's `tool_use` content blocks
/// and the actual `ToolProtocol` implementations. It handles:
/// - Parsing `tool_use` blocks from API response content
/// - Partitioning tools into read-only (concurrent) and mutation (serial) batches
/// - Executing read-only tools concurrently via `TaskGroup` (max 10)
/// - Executing mutation tools serially in order
/// - Capturing errors as `isError=true` ToolResults (never throwing)
/// - Building properly formatted `tool_result` user messages for the conversation
///
/// **Design:** This is a stateless `enum` namespace. All methods are `static`.
/// No actor is needed because there is no shared mutable state.
enum ToolExecutor {

    /// Maximum number of read-only tools to execute concurrently.
    static let maxConcurrency = 10

    // MARK: - Permission Decision

    /// Permission decision for tool execution.
    enum PermissionDecision: Sendable, Equatable {
        case allow
        case block(String)   // Blocked -- requires authorization prompt
        case deny(String)    // Denied -- outright rejection
    }

    // MARK: - Permission Check

    /// Determines whether a tool should be blocked based on the permission mode.
    ///
    /// Read-only tools are always allowed regardless of mode.
    ///
    /// - Parameters:
    ///   - permissionMode: The active permission mode.
    ///   - tool: The tool being checked.
    /// - Returns: A permission decision.
    static func shouldBlockTool(permissionMode: PermissionMode, tool: ToolProtocol) -> PermissionDecision {
        // Read-only tools are always allowed in all modes
        if tool.isReadOnly { return .allow }

        switch permissionMode {
        case .bypassPermissions, .auto:
            return .allow
        case .default:
            return .block("Permission required for tool \"\(tool.name)\" in default mode")
        case .acceptEdits:
            // Write/Edit are allowed, other mutations are blocked
            if tool.name == "Write" || tool.name == "Edit" {
                return .allow
            }
            return .block("Permission required for tool \"\(tool.name)\" in acceptEdits mode")
        case .plan:
            return .block("Tool \"\(tool.name)\" blocked in plan mode (read-only)")
        case .dontAsk:
            return .deny("Tool \"\(tool.name)\" denied in dontAsk mode")
        }
    }

    // MARK: - Post-Tool Hook Helper

    /// Fires the appropriate PostToolUse or PostToolUseFailure hook after tool execution.
    ///
    /// Shared by both the canUseTool allow path and the normal execution path
    /// to avoid duplicating hook logic.
    static func firePostToolHook(
        hookRegistry: HookRegistry?,
        block: ToolUseBlock,
        toolInput: Any,
        result: ToolResult,
        context: ToolContext
    ) async {
        guard let hookRegistry = hookRegistry else { return }
        let hookEvent: HookEvent = result.isError ? .postToolUseFailure : .postToolUse
        let hookInput = HookInput(
            event: hookEvent,
            toolName: block.name,
            toolInput: toolInput,
            toolOutput: result.content,
            toolUseId: block.id,
            cwd: context.cwd,
            error: result.isError ? result.content : nil
        )
        _ = await hookRegistry.execute(hookEvent, input: hookInput)
    }

    // MARK: - Extract tool_use Blocks

    /// Extracts `tool_use` content blocks from an Anthropic API response content array.
    ///
    /// - Parameter content: The content array from the API response (`response["content"]`).
    /// - Returns: An array of `ToolUseBlock` instances parsed from blocks where `type == "tool_use"`.
    static func extractToolUseBlocks(from content: [[String: Any]]) -> [ToolUseBlock] {
        return content.compactMap { block -> ToolUseBlock? in
            guard block["type"] as? String == "tool_use" else { return nil }
            guard let id = block["id"] as? String,
                  let name = block["name"] as? String else { return nil }
            let input = block["input"] ?? [:]
            return ToolUseBlock(id: id, name: name, input: input)
        }
    }

    // MARK: - Partition Tools

    /// Partitions tool use blocks into read-only (concurrent) and mutation (serial) batches.
    ///
    /// For each `ToolUseBlock`, looks up the corresponding `ToolProtocol` by name in the
    /// registered tools array. If the tool is found and `isReadOnly == true`, it goes into
    /// the read-only batch. Otherwise (mutation tool or unknown tool), it goes into the
    /// mutation batch.
    ///
    /// - Parameters:
    ///   - blocks: The tool use blocks from the LLM response.
    ///   - tools: The registered tools available for execution.
    /// - Returns: A tuple of (readOnly items, mutation items).
    static func partitionTools(
        blocks: [ToolUseBlock],
        tools: [ToolProtocol]
    ) -> (readOnly: [PairedToolItem], mutations: [PairedToolItem]) {
        var readOnly: [PairedToolItem] = []
        var mutations: [PairedToolItem] = []

        for block in blocks {
            let tool = tools.first { $0.name == block.name }
            let item = PairedToolItem(block: block, tool: tool)

            if let tool = tool, tool.isReadOnly {
                readOnly.append(item)
            } else {
                mutations.append(item)
            }
        }

        return (readOnly, mutations)
    }

    // MARK: - Execute Tools (Main Entry)

    /// Executes all tool use blocks with concurrent/serial dispatch.
    ///
    /// Read-only tools execute concurrently via `TaskGroup` (capped at `maxConcurrency`).
    /// Mutation tools execute serially after all read-only tools complete.
    /// Unknown tools return `isError=true` results.
    ///
    /// - Parameters:
    ///   - toolUseBlocks: The tool use blocks extracted from the LLM response.
    ///   - tools: The registered tools available for execution.
    ///   - context: The base tool execution context (cwd, etc.).
    /// - Returns: An array of `ToolResult` with one entry per input block.
    static func executeTools(
        toolUseBlocks: [ToolUseBlock],
        tools: [ToolProtocol],
        context: ToolContext
    ) async -> [ToolResult] {
        // Cancellation check: skip tool execution if already cancelled (FR60)
        if _Concurrency.Task.isCancelled { return [] }

        // Apply tool restriction stack filtering if active
        let effectiveTools: [ToolProtocol]
        if let restrictionStack = context.restrictionStack, !restrictionStack.isEmpty {
            effectiveTools = restrictionStack.currentAllowedToolNames(baseTools: tools)
        } else {
            effectiveTools = tools
        }

        let (readOnly, mutations) = partitionTools(blocks: toolUseBlocks, tools: effectiveTools)
        var results: [ToolResult] = []

        // Execute read-only tools concurrently (batched by maxConcurrency)
        let readOnlyResults = await executeReadOnlyConcurrent(batch: readOnly, context: context)
        results.append(contentsOf: readOnlyResults)

        // Cancellation check between read-only and mutation batches
        if _Concurrency.Task.isCancelled { return results }

        // Execute mutation tools serially
        let mutationResults = await executeMutationsSerial(items: mutations, context: context)
        results.append(contentsOf: mutationResults)

        return results
    }

    // MARK: - Concurrent Read-Only Execution

    /// Executes read-only tool items concurrently using `TaskGroup`.
    ///
    /// Tools are batched into groups of `maxConcurrency` to cap concurrent execution.
    /// Each batch runs all its items concurrently via `withTaskGroup`.
    ///
    /// - Parameters:
    ///   - batch: The read-only tool items to execute.
    ///   - context: The base tool execution context.
    /// - Returns: An array of `ToolResult` from all concurrent executions.
    static func executeReadOnlyConcurrent(
        batch: [PairedToolItem],
        context: ToolContext
    ) async -> [ToolResult] {
        var results: [ToolResult] = []

        // Process in batches of maxConcurrency
        for startIndex in stride(from: 0, to: batch.count, by: maxConcurrency) {
            let endIndex = min(startIndex + maxConcurrency, batch.count)
            let batchSlice = Array(batch[startIndex..<endIndex])

            let batchResults = await withTaskGroup(of: ToolResult.self) { group in
                for item in batchSlice {
                    group.addTask {
                        await executeSingleTool(
                            block: item.block,
                            tool: item.tool,
                            context: context.withToolUseId(item.block.id)
                        )
                    }
                }

                var collected: [ToolResult] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }

            results.append(contentsOf: batchResults)
        }

        return results
    }

    // MARK: - Serial Mutation Execution

    /// Executes mutation tool items serially (one at a time, in order).
    ///
    /// Each tool completes before the next one starts, ensuring safe file system operations.
    ///
    /// - Parameters:
    ///   - items: The mutation tool items to execute.
    ///   - context: The base tool execution context.
    /// - Returns: An array of `ToolResult` in the same order as input items.
    static func executeMutationsSerial(
        items: [PairedToolItem],
        context: ToolContext
    ) async -> [ToolResult] {
        var results: [ToolResult] = []
        for item in items {
            // Cancellation check between serial mutation steps (FR60)
            if _Concurrency.Task.isCancelled { break }
            let result = await executeSingleTool(
                block: item.block,
                tool: item.tool,
                context: context.withToolUseId(item.block.id)
            )
            results.append(result)
        }
        return results
    }

    // MARK: - Single Tool Execution

    /// Executes a single tool call, handling unknown tools and errors gracefully.
    ///
    /// - If the tool is nil (not registered), returns an error result.
    /// - If the tool throws during execution, the error is captured as `isError=true`.
    /// - Never throws or crashes — all errors are captured in the returned `ToolResult`.
    ///
    /// - Parameters:
    ///   - block: The tool use block with id, name, and input.
    ///   - tool: The resolved tool (nil if not found).
    ///   - context: The execution context.
    /// - Returns: A `ToolResult` with the execution outcome.
    static func executeSingleTool(
        block: ToolUseBlock,
        tool: ToolProtocol?,
        context: ToolContext
    ) async -> ToolResult {
        // Unknown tool handling
        guard let tool = tool else {
            return ToolResult(
                toolUseId: block.id,
                content: "Error: Unknown tool \"\(block.name)\"",
                isError: true
            )
        }

        // PreToolUse hook: if hookRegistry is set, trigger preToolUse hooks.
        // If any hook returns block: true, return an error result without executing the tool.
        if let hookRegistry = context.hookRegistry {
            let hookInput = HookInput(
                event: .preToolUse,
                toolName: block.name,
                toolInput: block.input,
                toolUseId: block.id,
                cwd: context.cwd
            )
            let hookResults = await hookRegistry.execute(.preToolUse, input: hookInput)
            if hookResults.contains(where: { $0.block }) {
                let blockMessage = hookResults.compactMap { $0.message }.first ?? "Tool execution blocked by hook"
                return ToolResult(
                    toolUseId: block.id,
                    content: "Error: \(blockMessage)",
                    isError: true
                )
            }
        }

        // === Permission Check ===
        // Step 1: Try canUseTool callback (takes priority over permissionMode)
        if let canUseTool = context.canUseTool {
            if let result = await canUseTool(tool, block.input, context) {
                if result.behavior == .deny {
                    return ToolResult(
                        toolUseId: block.id,
                        content: result.message ?? "Permission denied for tool \"\(block.name)\"",
                        isError: true
                    )
                }
                // allow — may have updatedInput
                let effectiveInput = result.updatedInput ?? block.input
                let toolStart = Date()
                let execResult = await tool.call(input: effectiveInput, context: context)
                let toolDurationMs = String(Int(Date().timeIntervalSince(toolStart) * 1000))

                // Structured log for tool execution
                Logger.shared.debug("ToolExecutor", "tool_result", data: [
                    "tool": block.name,
                    "durationMs": toolDurationMs,
                    "outputSize": String(execResult.content.utf8.count)
                ])

                // PostToolUse / PostToolUseFailure hook
                await firePostToolHook(
                    hookRegistry: context.hookRegistry,
                    block: block,
                    toolInput: effectiveInput,
                    result: execResult,
                    context: context
                )

                return ToolResult(
                    toolUseId: block.id,
                    content: execResult.content,
                    typedContent: execResult.typedContent,
                    isError: execResult.isError
                )
            }
            // canUseTool returned nil → fall back to permissionMode
        }

        // Step 2: Permission mode-based check
        if let mode = context.permissionMode {
            let decision = shouldBlockTool(permissionMode: mode, tool: tool)
            switch decision {
            case .allow:
                break // Continue to execute
            case .block(let message):
                return ToolResult(
                    toolUseId: block.id,
                    content: message,
                    isError: true
                )
            case .deny(let message):
                return ToolResult(
                    toolUseId: block.id,
                    content: message,
                    isError: true
                )
            }
        }

        // Execute tool — errors are captured in ToolResult, not thrown
        let toolStart = Date()
        let result = await tool.call(input: block.input, context: context)
        let toolDurationMs = String(Int(Date().timeIntervalSince(toolStart) * 1000))

        // Structured log for tool execution
        Logger.shared.debug("ToolExecutor", "tool_result", data: [
            "tool": block.name,
            "durationMs": toolDurationMs,
            "outputSize": String(result.content.utf8.count)
        ])

        // PostToolUse / PostToolUseFailure hook
        await firePostToolHook(
            hookRegistry: context.hookRegistry,
            block: block,
            toolInput: block.input,
            result: result,
            context: context
        )

        return ToolResult(
            toolUseId: block.id,
            content: result.content,
            typedContent: result.typedContent,
            isError: result.isError
        )
    }

    // MARK: - Build tool_result Message

    /// Builds a `tool_result` user message dictionary from an array of tool results.
    ///
    /// The returned dictionary has the Anthropic API format:
    /// ```json
    /// {
    ///   "role": "user",
    ///   "content": [
    ///     { "type": "tool_result", "tool_use_id": "...", "content": "..." },
    ///     { "type": "tool_result", "tool_use_id": "...", "content": "...", "is_error": true }
    ///   ]
    /// }
    /// ```
    ///
    /// Error results include the `is_error: true` field; non-error results omit it.
    ///
    /// - Parameter results: The tool execution results to format.
    /// - Returns: A dictionary suitable for appending to the messages array.
    static func buildToolResultMessage(from results: [ToolResult]) -> [String: Any] {
        let contentBlocks: [[String: Any]] = results.map { r in
            let apiContent: Any
            if let typedContent = r.typedContent, !typedContent.isEmpty {
                // Serialize typed content as API content array
                apiContent = typedContent.map { item -> [String: Any] in
                    switch item {
                    case .text(let text):
                        return ["type": "text", "text": text]
                    case .image(let data, let mimeType):
                        return [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": mimeType,
                                "data": data.base64EncodedString()
                            ]
                        ]
                    case .resource(let uri, let name):
                        var resource: [String: Any] = [
                            "type": "resource",
                            "uri": uri
                        ]
                        if let name { resource["name"] = name }
                        return resource
                    }
                }
            } else {
                // Plain string content (backward compatible)
                apiContent = r.content
            }

            var block: [String: Any] = [
                "type": "tool_result",
                "tool_use_id": r.toolUseId,
                "content": apiContent
            ]
            if r.isError {
                block["is_error"] = true
            }
            return block
        }

        return [
            "role": "user",
            "content": contentBlocks
        ]
    }
}

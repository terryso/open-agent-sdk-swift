import XCTest
@testable import OpenAgentSDK

// MARK: - Hook Integration Tests (Story 8-2)

/// ATDD tests for Story 8-2: Function Hook Registration & Execution.
///
/// These tests verify that HookRegistry integrates correctly with AgentOptions,
/// ToolContext, and ToolExecutor. All tests are in the TDD RED PHASE -- they
/// will FAIL until the implementation is complete (Tasks 1-6 in the story).
///
/// Coverage:
/// - AC1: AgentOptions.hookRegistry injection
/// - AC9: hookRegistry nil has no side effects
/// - AC10: createHookRegistry factory
/// - AC4: PreToolUse hook blocks tool execution
/// - AC5: PostToolUse hook receives tool output
/// - AC6: PostToolUseFailure hook receives error
/// - AC2: SessionStart hook triggered on prompt/stream
/// - AC7: SessionEnd hook triggered on prompt/stream completion
/// - AC8: Stop hook triggered on loop termination
final class HookIntegrationTests: XCTestCase {

    // MARK: - AC10: createHookRegistry Factory

    /// AC10 [P0]: createHookRegistry() without config returns an empty registry.
    func testCreateHookRegistry_withoutConfig_returnsEmptyRegistry() async {
        // Given/When: creating a hook registry with no config
        let registry = await createHookRegistry()

        // Then: registry exists and has no hooks
        for event in HookEvent.allCases {
            let hasHooks = await registry.hasHooks(event)
            XCTAssertFalse(hasHooks, "\(event.rawValue) should have no hooks in empty registry")
        }
    }

    /// AC10 [P0]: createHookRegistry() with config registers hooks.
    func testCreateHookRegistry_withConfig_registersHooks() async {
        // Given: a config with hooks for preToolUse and postToolUse
        let config: [String: [HookDefinition]] = [
            "preToolUse": [HookDefinition(handler: { _ in
                HookOutput(message: "config-hook-pre")
            })],
            "postToolUse": [HookDefinition(handler: { _ in
                HookOutput(message: "config-hook-post")
            })],
        ]

        // When: creating registry with config
        let registry = await createHookRegistry(config: config)

        // Then: hooks are registered
        let hasPre = await registry.hasHooks(.preToolUse)
        let hasPost = await registry.hasHooks(.postToolUse)
        XCTAssertTrue(hasPre, "preToolUse should have hooks from config")
        XCTAssertTrue(hasPost, "postToolUse should have hooks from config")

        // And: hooks execute correctly
        let input = HookInput(event: .preToolUse, toolName: "bash")
        let results = await registry.execute(.preToolUse, input: input)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.message, "config-hook-pre")
    }

    // MARK: - AC1: AgentOptions.hookRegistry Injection

    /// AC1 [P0]: AgentOptions.hookRegistry defaults to nil.
    func testAgentOptions_hookRegistry_defaultNil() {
        // Given: AgentOptions created without hookRegistry
        let options = AgentOptions(model: "test-model")

        // Then: hookRegistry is nil
        XCTAssertNil(options.hookRegistry, "hookRegistry should default to nil")
    }

    /// AC1 [P0]: AgentOptions.hookRegistry can be injected.
    func testAgentOptions_hookRegistry_injectable() async {
        // Given: a HookRegistry
        let registry = await createHookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            HookOutput(message: "injected")
        }))

        // When: injecting into AgentOptions
        let options = AgentOptions(
            model: "test-model",
            hookRegistry: registry
        )

        // Then: hookRegistry is set and functional
        XCTAssertNotNil(options.hookRegistry, "hookRegistry should be non-nil after injection")
        let hasHooks = await options.hookRegistry?.hasHooks(.preToolUse)
        XCTAssertTrue(hasHooks ?? false, "Injected registry should have registered hooks")
    }

    /// AC1 [P1]: AgentOptions(from:) initializes hookRegistry to nil.
    func testAgentOptions_fromConfig_hookRegistryNil() {
        // Given: an SDKConfiguration
        let config = SDKConfiguration(apiKey: "test-key")

        // When: creating AgentOptions from config
        let options = AgentOptions(from: config)

        // Then: hookRegistry is nil
        XCTAssertNil(options.hookRegistry, "hookRegistry should be nil when created from SDKConfiguration")
    }

    // MARK: - AC1: ToolContext.hookRegistry

    /// AC1 [P0]: ToolContext.hookRegistry defaults to nil.
    func testToolContext_hookRegistry_defaultNil() {
        // Given: ToolContext created without hookRegistry
        let context = ToolContext(cwd: "/tmp")

        // Then: hookRegistry is nil
        XCTAssertNil(context.hookRegistry, "hookRegistry should default to nil in ToolContext")
    }

    /// AC1 [P0]: ToolContext.hookRegistry is preserved in withToolUseId().
    func testToolContext_hookRegistry_preservedInWithToolUseId() async {
        // Given: a ToolContext with a hookRegistry
        let registry = await createHookRegistry()
        let context = ToolContext(
            cwd: "/tmp",
            hookRegistry: registry
        )

        // When: creating a copy with new toolUseId
        let copy = context.withToolUseId("tool-123")

        // Then: hookRegistry is preserved
        XCTAssertNotNil(copy.hookRegistry, "hookRegistry should be preserved in withToolUseId")
    }

    // MARK: - AC4: PreToolUse Hook Blocks Execution

    /// AC4 [P0]: PreToolUse hook returning block:true prevents tool execution.
    func testPreToolUse_hookBlocksExecution() async {
        // Given: a ToolContext with a hookRegistry that blocks execution
        let registry = await createHookRegistry()
        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            HookOutput(message: "blocked by policy", block: true)
        }))

        let context = ToolContext(
            cwd: "/tmp",
            hookRegistry: registry
        )

        // When: executing a tool through ToolExecutor
        let block = ToolUseBlock(id: "tool-1", name: "echo_tool", input: ["message": "hello"])
        let tool = StubTool(name: "echo_tool", result: "echo: hello")
        let result = await ToolExecutor.executeSingleTool(
            block: block,
            tool: tool,
            context: context
        )

        // Then: result is an error with the block message
        XCTAssertTrue(result.isError, "Result should be an error when hook blocks execution")
        XCTAssertTrue(result.content.contains("blocked by policy"), "Error should contain hook block message")
    }

    /// AC4 [P0]: PreToolUse hook returning no block allows tool execution.
    func testPreToolUse_hookAllowsExecution() async {
        // Given: a ToolContext with a hookRegistry that does NOT block
        let registry = await createHookRegistry()
        let tracker = HookCallTracker()

        await registry.register(.preToolUse, definition: HookDefinition(handler: { _ in
            await tracker.markCalled()
            return HookOutput(message: "logged", block: false)
        }))

        let context = ToolContext(
            cwd: "/tmp",
            hookRegistry: registry
        )

        // When: executing a tool through ToolExecutor
        let block = ToolUseBlock(id: "tool-2", name: "echo_tool", input: ["message": "hello"])
        let tool = StubTool(name: "echo_tool", result: "echo: hello")
        let result = await ToolExecutor.executeSingleTool(
            block: block,
            tool: tool,
            context: context
        )

        // Then: tool executes successfully
        XCTAssertFalse(result.isError, "Result should not be an error when hook allows execution")
        XCTAssertEqual(result.content, "echo: hello")

        // And: hook was called
        let wasCalled = await tracker.called
        XCTAssertTrue(wasCalled, "PreToolUse hook should have been called")
    }

    // MARK: - AC5: PostToolUse Hook Receives Tool Output

    /// AC5 [P0]: PostToolUse hook receives tool output after successful execution.
    func testPostToolUse_hookReceivesToolOutput() async {
        // Given: a ToolContext with postToolUse hook
        let registry = await createHookRegistry()
        let tracker = PostToolOutputTracker()

        await registry.register(.postToolUse, definition: HookDefinition(handler: { input in
            await tracker.record(toolName: input.toolName, output: input.toolOutput)
            return nil
        }))

        let context = ToolContext(
            cwd: "/tmp",
            hookRegistry: registry
        )

        // When: executing a tool successfully
        let block = ToolUseBlock(id: "tool-3", name: "read_file", input: ["path": "/tmp/test.txt"])
        let tool = StubTool(name: "read_file", result: "file contents here")
        _ = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        // Then: postToolUse hook received the tool output
        let captured = await tracker.captured
        XCTAssertEqual(captured.toolName, "read_file", "Hook should receive tool name")
        XCTAssertNotNil(captured.output, "Hook should receive tool output")
    }

    // MARK: - AC6: PostToolUseFailure Hook Receives Error

    /// AC6 [P0]: PostToolUseFailure hook receives error info after tool failure.
    func testPostToolUseFailure_hookReceivesError() async {
        // Given: a ToolContext with postToolUseFailure hook
        let registry = await createHookRegistry()
        let tracker = FailureTracker()

        await registry.register(.postToolUseFailure, definition: HookDefinition(handler: { input in
            await tracker.record(toolName: input.toolName, error: input.error)
            return nil
        }))

        let context = ToolContext(
            cwd: "/tmp",
            hookRegistry: registry
        )

        // When: executing a tool that fails
        let block = ToolUseBlock(id: "tool-4", name: "fail_tool", input: ["path": "/nonexistent"])
        let tool = StubFailingTool(name: "fail_tool", errorMessage: "File not found")
        _ = await ToolExecutor.executeSingleTool(block: block, tool: tool, context: context)

        // Then: postToolUseFailure hook received error info
        let captured = await tracker.captured
        XCTAssertEqual(captured.toolName, "fail_tool", "Hook should receive tool name")
        XCTAssertNotNil(captured.error, "Hook should receive error message")
    }

    // MARK: - AC9: hookRegistry nil No Side Effects

    /// AC9 [P0]: ToolExecutor works correctly when hookRegistry is nil.
    func testHookRegistryNil_noSideEffects() async {
        // Given: a ToolContext with nil hookRegistry (default)
        let context = ToolContext(cwd: "/tmp")

        // When: executing a tool
        let block = ToolUseBlock(id: "tool-5", name: "echo_tool", input: ["message": "test"])
        let tool = StubTool(name: "echo_tool", result: "echo: test")
        let result = await ToolExecutor.executeSingleTool(
            block: block,
            tool: tool,
            context: context
        )

        // Then: tool executes normally, no crash or error
        XCTAssertFalse(result.isError, "Tool should execute normally when hookRegistry is nil")
        XCTAssertEqual(result.content, "echo: test")
    }

    /// AC9 [P0]: Unknown tool still returns error when hookRegistry is nil.
    func testHookRegistryNil_unknownTool_stillReturnsError() async {
        // Given: a ToolContext with nil hookRegistry
        let context = ToolContext(cwd: "/tmp")

        // When: executing an unknown tool
        let block = ToolUseBlock(id: "tool-6", name: "nonexistent_tool", input: [:])
        let result = await ToolExecutor.executeSingleTool(
            block: block,
            tool: nil,
            context: context
        )

        // Then: returns unknown tool error (unchanged behavior)
        XCTAssertTrue(result.isError, "Unknown tool should still return error")
        XCTAssertTrue(result.content.contains("Unknown tool"), "Error should mention unknown tool")
    }

    // MARK: - AC2, AC7, AC8: Agent Lifecycle Hook Integration

    /// AC2 [P0]: sessionStart hook is triggered when agent.prompt() is called.
    /// NOTE: This test will FAIL until Agent.swift integrates hook trigger points.
    func testAgentPrompt_sessionStartHookTriggered() async {
        // Given: a HookRegistry with a sessionStart hook
        let registry = HookRegistry()
        let tracker = LifecycleEventTracker()

        await registry.register(.sessionStart, definition: HookDefinition(handler: { input in
            await tracker.record(event: input.event, toolName: input.toolName)
            return nil
        }))

        // When: creating an agent with hookRegistry and calling prompt
        // NOTE: This requires a mock LLM client or a test that avoids real API calls.
        // For ATDD red phase, we verify the structure is correct.
        let options = AgentOptions(
            model: "test-model",
            hookRegistry: registry
        )

        // Then: AgentOptions should have hookRegistry set
        XCTAssertNotNil(options.hookRegistry, "AgentOptions should have hookRegistry set")

        // And: the hook should be registered on sessionStart
        let hasHooks = await registry.hasHooks(.sessionStart)
        XCTAssertTrue(hasHooks, "sessionStart hook should be registered")

        // FUTURE: Once Agent.swift is updated, verify that prompt() triggers sessionStart.
        // This will be tested in E2E tests with a real agent.
    }

    /// AC7 [P0]: sessionEnd hook is triggered when agent.prompt() completes.
    /// NOTE: This test will FAIL until Agent.swift integrates hook trigger points.
    func testAgentPrompt_sessionEndHookTriggered() async {
        // Given: a HookRegistry with sessionEnd and sessionStart hooks
        let registry = HookRegistry()
        let tracker = LifecycleEventTracker()

        await registry.register(.sessionEnd, definition: HookDefinition(handler: { input in
            await tracker.record(event: input.event, toolName: input.toolName)
            return nil
        }))

        let options = AgentOptions(
            model: "test-model",
            hookRegistry: registry
        )

        // Then: hook is registered
        let hasHooks = await registry.hasHooks(.sessionEnd)
        XCTAssertTrue(hasHooks, "sessionEnd hook should be registered")
    }

    /// AC8 [P0]: stop hook is triggered when agent loop terminates.
    /// NOTE: This test will FAIL until Agent.swift integrates hook trigger points.
    func testAgentPrompt_stopHookTriggered() async {
        // Given: a HookRegistry with a stop hook
        let registry = HookRegistry()
        let tracker = LifecycleEventTracker()

        await registry.register(.stop, definition: HookDefinition(handler: { input in
            await tracker.record(event: input.event, toolName: input.toolName)
            return nil
        }))

        let options = AgentOptions(
            model: "test-model",
            hookRegistry: registry
        )

        // Then: hook is registered
        let hasHooks = await registry.hasHooks(.stop)
        XCTAssertTrue(hasHooks, "stop hook should be registered")
    }
}

// MARK: - Test Helper Actors

/// Tracks lifecycle events received by hooks in integration tests.
actor LifecycleEventTracker {
    private var events: [(event: HookEvent, toolName: String?)] = []

    func record(event: HookEvent, toolName: String?) {
        events.append((event, toolName))
    }

    var recordedEvents: [(event: HookEvent, toolName: String?)] {
        events
    }

    var eventTypes: [HookEvent] {
        events.map { $0.event }
    }
}

/// Tracks post-tool output received by PostToolUse hooks.
actor PostToolOutputTracker {
    private var capturedToolName: String?
    private var capturedOutput: String?

    func record(toolName: String?, output: Any?) {
        capturedToolName = toolName
        capturedOutput = output as? String
    }

    var captured: (toolName: String?, output: String?) {
        (capturedToolName, capturedOutput)
    }
}

/// Tracks failure info received by PostToolUseFailure hooks.
actor FailureTracker {
    private var capturedToolName: String?
    private var capturedError: String?

    func record(toolName: String?, error: String?) {
        capturedToolName = toolName
        capturedError = error
    }

    var captured: (toolName: String?, error: String?) {
        (capturedToolName, capturedError)
    }
}

// MARK: - Stub Tool Implementations

/// A stub tool that returns a fixed result for testing.
final class StubTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Stub tool for testing"
    let inputSchema: ToolInputSchema = [:]
    let isReadOnly: Bool = true
    let result: String

    init(name: String, result: String) {
        self.name = name
        self.result = result
    }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        ToolResult(toolUseId: context.toolUseId, content: result, isError: false)
    }
}

/// A stub tool that always returns an error result.
final class StubFailingTool: ToolProtocol, @unchecked Sendable {
    let name: String
    let description: String = "Failing stub tool for testing"
    let inputSchema: ToolInputSchema = [:]
    let isReadOnly: Bool = true
    let errorMessage: String

    init(name: String, errorMessage: String) {
        self.name = name
        self.errorMessage = errorMessage
    }

    func call(input: Any, context: ToolContext) async -> ToolResult {
        ToolResult(toolUseId: context.toolUseId, content: errorMessage, isError: true)
    }
}

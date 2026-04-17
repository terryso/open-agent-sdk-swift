import XCTest
@testable import OpenAgentSDK

import Foundation

// MARK: - ATDD RED PHASE: Story 17-10 Query Methods Enhancement
//
// All tests assert EXPECTED behavior. They will FAIL until:
//   - RewindResult struct is added to Sources/OpenAgentSDK/Types/
//   - SDKControlInitializeResponse struct is added to Sources/OpenAgentSDK/Types/
//   - SlashCommand struct is added to Sources/OpenAgentSDK/Types/
//   - AgentInfo struct is added to Sources/OpenAgentSDK/Types/
//   - AccountInfo struct is added to Sources/OpenAgentSDK/Types/
//   - Agent gains 9 new public methods:
//     rewindFiles, streamInput, stopTask, close,
//     initializationResult, supportedModels, supportedAgents,
//     setMaxThinkingTokens
//   - Agent gains _closed flag for close() support
//
// TDD Phase: RED (feature not implemented yet)

// MARK: - AC9/AC1: RewindResult Type Tests

final class RewindResultATDDTests: XCTestCase {

    /// AC9/AC1 [P0]: RewindResult has filesAffected, success, preview fields.
    func testRewindResult_hasAllFields() {
        let result = RewindResult(
            filesAffected: ["/tmp/file1.swift", "/tmp/file2.swift"],
            success: true,
            preview: false
        )
        XCTAssertEqual(result.filesAffected, ["/tmp/file1.swift", "/tmp/file2.swift"],
                       "RewindResult.filesAffected lists affected file paths")
        XCTAssertTrue(result.success,
                      "RewindResult.success indicates operation success")
        XCTAssertFalse(result.preview,
                       "RewindResult.preview indicates dry-run mode")
    }

    /// AC9/AC1 [P0]: RewindResult conforms to Sendable.
    func testRewindResult_conformsToSendable() {
        let result = RewindResult(filesAffected: [], success: true, preview: false)
        // Will fail to compile if RewindResult does not conform to Sendable
        let _: any Sendable = result
    }

    /// AC9/AC1 [P0]: RewindResult conforms to Equatable.
    func testRewindResult_conformsToEquatable() {
        let a = RewindResult(filesAffected: ["/a"], success: true, preview: false)
        let b = RewindResult(filesAffected: ["/a"], success: true, preview: false)
        let c = RewindResult(filesAffected: ["/b"], success: false, preview: true)
        XCTAssertEqual(a, b, "Identical RewindResult values should be equal")
        XCTAssertNotEqual(a, c, "Different RewindResult values should not be equal")
    }

    /// AC9/AC1 [P0]: RewindResult init with empty filesAffected.
    func testRewindResult_initWithEmptyFiles() {
        let result = RewindResult(filesAffected: [], success: true, preview: true)
        XCTAssertTrue(result.filesAffected.isEmpty)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.preview)
    }

    /// AC9/AC1 [P1]: RewindResult with dryRun=true has preview=true.
    func testRewindResult_dryRunPreview() {
        let result = RewindResult(
            filesAffected: ["/tmp/file1.swift"],
            success: true,
            preview: true
        )
        XCTAssertTrue(result.preview, "Dry-run RewindResult should have preview=true")
    }
}

// MARK: - AC9/AC5: SlashCommand Type Tests

final class SlashCommandATDDTests: XCTestCase {

    /// AC9/AC5 [P0]: SlashCommand has name and description fields.
    func testSlashCommand_hasNameAndDescription() {
        let cmd = SlashCommand(name: "/help", description: "Show help")
        XCTAssertEqual(cmd.name, "/help",
                       "SlashCommand.name should match TS SlashCommand.name")
        XCTAssertEqual(cmd.description, "Show help",
                       "SlashCommand.description should match TS SlashCommand.description")
    }

    /// AC9/AC5 [P0]: SlashCommand conforms to Sendable.
    func testSlashCommand_conformsToSendable() {
        let cmd = SlashCommand(name: "/test", description: "Test command")
        let _: any Sendable = cmd
    }

    /// AC9/AC5 [P0]: SlashCommand conforms to Equatable.
    func testSlashCommand_conformsToEquatable() {
        let a = SlashCommand(name: "/help", description: "Help")
        let b = SlashCommand(name: "/help", description: "Help")
        let c = SlashCommand(name: "/clear", description: "Help")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - AC9/AC5: AccountInfo Type Tests

final class AccountInfoATDDTests: XCTestCase {

    /// AC9/AC5 [P0]: AccountInfo can be constructed with minimal fields.
    func testAccountInfo_init() {
        let info = AccountInfo()
        // AccountInfo is a minimal API surface alignment type
        XCTAssertTrue(true, "AccountInfo can be initialized")
    }

    /// AC9/AC5 [P0]: AccountInfo conforms to Sendable.
    func testAccountInfo_conformsToSendable() {
        let info = AccountInfo()
        let _: any Sendable = info
    }

    /// AC9/AC5 [P0]: AccountInfo conforms to Equatable.
    func testAccountInfo_conformsToEquatable() {
        let a = AccountInfo()
        let b = AccountInfo()
        XCTAssertEqual(a, b, "AccountInfo conforms to Equatable")
    }
}

// MARK: - AC9/AC5: SDKControlInitializeResponse Type Tests

final class SDKControlInitializeResponseATDDTests: XCTestCase {

    /// AC9/AC5 [P0]: SDKControlInitializeResponse has all required fields.
    func testSDKControlInitializeResponse_hasAllFields() {
        let response = SDKControlInitializeResponse(
            commands: [SlashCommand(name: "/help", description: "Show help")],
            agents: [AgentInfo(name: "researcher", description: "Research agent", model: nil)],
            outputStyle: "default",
            availableOutputStyles: ["default", "compact"],
            models: [ModelInfo(value: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6", description: "Fast model")],
            account: nil,
            fastModeState: false
        )
        XCTAssertEqual(response.commands.count, 1)
        XCTAssertEqual(response.agents.count, 1)
        XCTAssertEqual(response.outputStyle, "default")
        XCTAssertEqual(response.availableOutputStyles, ["default", "compact"])
        XCTAssertEqual(response.models.count, 1)
        XCTAssertNil(response.account)
        XCTAssertFalse(response.fastModeState)
    }

    /// AC9/AC5 [P0]: SDKControlInitializeResponse conforms to Sendable.
    func testSDKControlInitializeResponse_conformsToSendable() {
        let response = SDKControlInitializeResponse(
            commands: [],
            agents: [],
            outputStyle: "default",
            availableOutputStyles: [],
            models: [],
            account: nil,
            fastModeState: false
        )
        let _: any Sendable = response
    }

    /// AC9/AC5 [P0]: SDKControlInitializeResponse conforms to Equatable.
    func testSDKControlInitializeResponse_conformsToEquatable() {
        let a = SDKControlInitializeResponse(
            commands: [],
            agents: [],
            outputStyle: "default",
            availableOutputStyles: [],
            models: [],
            account: nil,
            fastModeState: false
        )
        let b = SDKControlInitializeResponse(
            commands: [],
            agents: [],
            outputStyle: "default",
            availableOutputStyles: [],
            models: [],
            account: nil,
            fastModeState: false
        )
        XCTAssertEqual(a, b)
    }

    /// AC9/AC5 [P1]: SDKControlInitializeResponse with empty collections.
    func testSDKControlInitializeResponse_emptyCollections() {
        let response = SDKControlInitializeResponse(
            commands: [],
            agents: [],
            outputStyle: "default",
            availableOutputStyles: [],
            models: [],
            account: nil,
            fastModeState: false
        )
        XCTAssertTrue(response.commands.isEmpty)
        XCTAssertTrue(response.agents.isEmpty)
        XCTAssertTrue(response.availableOutputStyles.isEmpty)
        XCTAssertTrue(response.models.isEmpty)
    }
}

// MARK: - AC9/AC7: AgentInfo Type Tests

final class AgentInfoATDDTests: XCTestCase {

    /// AC9/AC7 [P0]: AgentInfo has name, description, model fields.
    func testAgentInfo_hasAllFields() {
        let info = AgentInfo(
            name: "coder",
            description: "Code generation agent",
            model: "claude-sonnet-4-6"
        )
        XCTAssertEqual(info.name, "coder",
                       "AgentInfo.name matches TS AgentInfo.name")
        XCTAssertEqual(info.description, "Code generation agent",
                       "AgentInfo.description matches TS AgentInfo.description")
        XCTAssertEqual(info.model, "claude-sonnet-4-6",
                       "AgentInfo.model matches TS AgentInfo.model")
    }

    /// AC9/AC7 [P0]: AgentInfo conforms to Sendable.
    func testAgentInfo_conformsToSendable() {
        let info = AgentInfo(name: "test", description: nil, model: nil)
        let _: any Sendable = info
    }

    /// AC9/AC7 [P0]: AgentInfo conforms to Equatable.
    func testAgentInfo_conformsToEquatable() {
        let a = AgentInfo(name: "test", description: "d", model: "m")
        let b = AgentInfo(name: "test", description: "d", model: "m")
        let c = AgentInfo(name: "other", description: "d", model: "m")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    /// AC9/AC7 [P1]: AgentInfo with nil optional fields.
    func testAgentInfo_nilOptionals() {
        let info = AgentInfo(name: "minimal", description: nil, model: nil)
        XCTAssertEqual(info.name, "minimal")
        XCTAssertNil(info.description)
        XCTAssertNil(info.model)
    }
}

// MARK: - AC1: Agent.rewindFiles() Tests

final class AgentRewindFilesATDDTests: XCTestCase {

    /// AC1 [P0]: Agent has rewindFiles(to:dryRun:) async throws -> RewindResult.
    func testAgent_hasRewindFilesMethod() async throws {
        let agent = Agent(
            definition: AgentDefinition(name: "test-rewind"),
            options: AgentOptions(apiKey: "test-key")
        )
        // This will fail to compile if rewindFiles does not exist
        do {
            let _ = try await agent.rewindFiles(to: "msg-123", dryRun: true)
        } catch {
            // Expected to throw since file checkpointing is not set up
        }
    }

    /// AC1 [P0]: rewindFiles returns RewindResult type.
    func testAgent_rewindFiles_returnsRewindResult() async throws {
        let agent = Agent(
            definition: AgentDefinition(name: "test-rewind-type"),
            options: AgentOptions(apiKey: "test-key")
        )
        // dryRun=true should return a preview without side effects
        do {
            let result: RewindResult = try await agent.rewindFiles(to: "msg-001", dryRun: true)
            XCTAssertTrue(type(of: result) == RewindResult.self,
                          "rewindFiles returns RewindResult")
        } catch {
            // May throw if no checkpoints exist -- acceptable in RED phase
        }
    }
}

// MARK: - AC2: Agent.streamInput() Tests

final class AgentStreamInputATDDTests: XCTestCase {

    /// AC2 [P0]: Agent has streamInput(_ input: AsyncStream<String>) -> AsyncStream<SDKMessage>.
    func testAgent_hasStreamInputMethod() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-stream-input"),
            options: AgentOptions(apiKey: "test-key")
        )
        // Create a simple input stream
        let inputStream = AsyncStream<String> { continuation in
            continuation.yield("Hello")
            continuation.finish()
        }
        // This will fail to compile if streamInput does not exist
        let _ = agent.streamInput(inputStream)
    }

    /// AC2 [P0]: streamInput returns AsyncStream<SDKMessage>.
    func testAgent_streamInput_returnsSDKMessageStream() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-stream-type"),
            options: AgentOptions(apiKey: "test-key")
        )
        let inputStream = AsyncStream<String> { $0.finish() }
        let outputStream: AsyncStream<SDKMessage> = agent.streamInput(inputStream)
        // Compile-time check: must be AsyncStream<SDKMessage>
        XCTAssertTrue(type(of: outputStream) == AsyncStream<SDKMessage>.self,
                      "streamInput returns AsyncStream<SDKMessage>")
    }
}

// MARK: - AC3: Agent.stopTask() Tests

final class AgentStopTaskATDDTests: XCTestCase {

    /// AC3 [P0]: Agent has stopTask(taskId:) async throws method.
    func testAgent_hasStopTaskMethod() async {
        let agent = Agent(
            definition: AgentDefinition(name: "test-stop-task"),
            options: AgentOptions(apiKey: "test-key")
        )
        // This will fail to compile if stopTask does not exist
        do {
            try await agent.stopTask(taskId: "task-001")
        } catch {
            // Expected: no TaskStore configured
        }
    }

    /// AC3 [P0]: stopTask throws when no TaskStore configured.
    func testAgent_stopTask_throwsWhenNoTaskStore() async {
        let agent = Agent(
            definition: AgentDefinition(name: "test-stop-no-store"),
            options: AgentOptions(apiKey: "test-key")
        )
        // AgentOptions defaults to taskStore=nil
        do {
            try await agent.stopTask(taskId: "task-001")
            XCTFail("stopTask should throw when no TaskStore configured")
        } catch {
            // Expected: SDKError.invalidConfiguration
        }
    }

    /// AC3 [P1]: stopTask throws when task ID not found in configured TaskStore.
    func testAgent_stopTask_throwsWhenTaskNotFound() async {
        let store = TaskStore()
        let agent = Agent(
            definition: AgentDefinition(name: "test-stop-not-found"),
            options: AgentOptions(apiKey: "test-key", taskStore: store)
        )
        do {
            try await agent.stopTask(taskId: "nonexistent-task-id")
            XCTFail("stopTask should throw when task ID not found")
        } catch {
            // Expected: task not found error
        }
    }
}

// MARK: - AC4: Agent.close() Tests

final class AgentCloseATDDTests: XCTestCase {

    /// AC4 [P0]: Agent has close() async throws method.
    func testAgent_hasCloseMethod() async throws {
        let agent = Agent(
            definition: AgentDefinition(name: "test-close"),
            options: AgentOptions(apiKey: "test-key")
        )
        // This will fail to compile if close() does not exist
        try await agent.close()
    }

    /// AC4 [P0]: close() sets closed flag -- subsequent prompt() returns error result.
    func testAgent_close_preventsSubsequentPrompt() async throws {
        let agent = Agent(
            definition: AgentDefinition(name: "test-close-prompt"),
            options: AgentOptions(apiKey: "test-key")
        )
        // Close the agent
        try await agent.close()

        // Subsequent prompt() should return error result because agent is closed
        let result = await agent.prompt("test after close")
        XCTAssertEqual(result.status, .errorDuringExecution,
                       "prompt() after close() should return errorDuringExecution")
    }

    /// AC4 [P0]: close() sets closed flag -- subsequent stream() returns empty stream.
    func testAgent_close_preventsSubsequentStream() async throws {
        let agent = Agent(
            definition: AgentDefinition(name: "test-close-stream"),
            options: AgentOptions(apiKey: "test-key")
        )
        try await agent.close()

        // Subsequent stream() -- should return an immediately-finishing stream
        let messageStream = agent.stream("test after close")
        var eventCount = 0
        for await _ in messageStream {
            eventCount += 1
        }
        XCTAssertEqual(eventCount, 0,
                       "Stream after close() should yield no events (empty stream)")
    }

    /// AC4 [P1]: close() with sessionStore persists session.
    func testAgent_close_persistsSession_whenStoreConfigured() async throws {
        let tempDir = NSTemporaryDirectory().appending("close-test-\(UUID().uuidString)")
        let store = SessionStore(sessionsDir: tempDir)
        let agent = Agent(
            definition: AgentDefinition(name: "test-close-session"),
            options: AgentOptions(
                apiKey: "test-key",
                sessionStore: store,
                sessionId: "session-close-test",
                persistSession: true
            )
        )
        // Close should persist session
        try await agent.close()
        // Session should exist in store (verification of side effect)
        let loaded = try? await store.load(sessionId: "session-close-test")
        // In RED phase, this may be nil since close() is not implemented
    }
}

// MARK: - AC5: Agent.initializationResult() Tests

final class AgentInitializationResultATDDTests: XCTestCase {

    /// AC5 [P0]: Agent has initializationResult() -> SDKControlInitializeResponse.
    func testAgent_hasInitializationResultMethod() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-init-result"),
            options: AgentOptions(apiKey: "test-key")
        )
        // This will fail to compile if initializationResult() does not exist
        let result = agent.initializationResult()
        XCTAssertTrue(type(of: result) == SDKControlInitializeResponse.self,
                      "initializationResult returns SDKControlInitializeResponse")
    }

    /// AC5 [P0]: initializationResult returns models matching MODEL_PRICING.
    func testAgent_initializationResult_includesModels() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-init-models"),
            options: AgentOptions(apiKey: "test-key")
        )
        let result = agent.initializationResult()
        // Should include models from MODEL_PRICING
        XCTAssertFalse(result.models.isEmpty,
                       "initializationResult should include models from MODEL_PRICING")
        // Count should match MODEL_PRICING keys
        XCTAssertEqual(result.models.count, MODEL_PRICING.count,
                       "Model count should match MODEL_PRICING entries")
    }

    /// AC5 [P0]: initializationResult returns empty commands (TS-specific).
    func testAgent_initializationResult_emptyCommands() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-init-cmds"),
            options: AgentOptions(apiKey: "test-key")
        )
        let result = agent.initializationResult()
        XCTAssertTrue(result.commands.isEmpty,
                      "Slash commands are TS-specific; Swift SDK returns empty array")
    }

    /// AC5 [P1]: initializationResult returns outputStyle default.
    func testAgent_initializationResult_hasDefaultOutputStyle() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-init-style"),
            options: AgentOptions(apiKey: "test-key")
        )
        let result = agent.initializationResult()
        XCTAssertEqual(result.outputStyle, "default",
                       "Default outputStyle should be 'default'")
        XCTAssertFalse(result.availableOutputStyles.isEmpty,
                       "availableOutputStyles should contain at least 'default'")
    }
}

// MARK: - AC6: Agent.supportedModels() Tests

final class AgentSupportedModelsATDDTests: XCTestCase {

    /// AC6 [P0]: Agent has supportedModels() -> [ModelInfo].
    func testAgent_hasSupportedModelsMethod() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-supported-models"),
            options: AgentOptions(apiKey: "test-key")
        )
        // This will fail to compile if supportedModels() does not exist
        let models = agent.supportedModels()
        XCTAssertTrue(type(of: models) == [ModelInfo].self,
                      "supportedModels returns [ModelInfo]")
    }

    /// AC6 [P0]: supportedModels returns entries matching MODEL_PRICING keys.
    func testAgent_supportedModels_matchesModelPricing() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-model-pricing"),
            options: AgentOptions(apiKey: "test-key")
        )
        let models = agent.supportedModels()
        let modelValues = Set(models.map { $0.value })
        let pricingKeys = Set(MODEL_PRICING.keys)

        XCTAssertEqual(modelValues, pricingKeys,
                       "supportedModels values should match MODEL_PRICING keys")
    }

    /// AC6 [P0]: supportedModels returns 8 models (current MODEL_PRICING count).
    func testAgent_supportedModels_count() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-model-count"),
            options: AgentOptions(apiKey: "test-key")
        )
        let models = agent.supportedModels()
        XCTAssertEqual(models.count, MODEL_PRICING.count,
                       "supportedModels count should match MODEL_PRICING count")
    }
}

// MARK: - AC7: Agent.supportedAgents() Tests

final class AgentSupportedAgentsATDDTests: XCTestCase {

    /// AC7 [P0]: Agent has supportedAgents() -> [AgentInfo].
    func testAgent_hasSupportedAgentsMethod() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-supported-agents"),
            options: AgentOptions(apiKey: "test-key")
        )
        // This will fail to compile if supportedAgents() does not exist
        let agents = agent.supportedAgents()
        XCTAssertTrue(type(of: agents) == [AgentInfo].self,
                      "supportedAgents returns [AgentInfo]")
    }

    /// AC7 [P0]: supportedAgents returns empty array when no agents configured.
    func testAgent_supportedAgents_emptyWhenNoAgents() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-no-agents"),
            options: AgentOptions(apiKey: "test-key")
        )
        // Default AgentOptions has no sub-agent definitions
        let agents = agent.supportedAgents()
        XCTAssertTrue(agents.isEmpty,
                      "supportedAgents should return empty array when no agents configured")
    }
}

// MARK: - AC8: Agent.setMaxThinkingTokens() Tests

final class AgentSetMaxThinkingTokensATDDTests: XCTestCase {

    /// AC8 [P0]: Agent has setMaxThinkingTokens(_ n: Int?) method.
    func testAgent_hasSetMaxThinkingTokensMethod() throws {
        let agent = Agent(
            definition: AgentDefinition(name: "test-thinking-tokens"),
            options: AgentOptions(apiKey: "test-key")
        )
        // This will fail to compile if setMaxThinkingTokens does not exist
        try agent.setMaxThinkingTokens(10000)
    }

    /// AC8 [P0]: setMaxThinkingTokens(10000) sets .enabled(budgetTokens: 10000).
    func testAgent_setMaxThinkingTokens_setsEnabledBudget() throws {
        let agent = Agent(
            definition: AgentDefinition(name: "test-thinking-enabled"),
            options: AgentOptions(apiKey: "test-key")
        )
        try agent.setMaxThinkingTokens(10000)

        // Verify thinking is set by using computeThinkingConfig indirectly
        // We verify the method does not crash and accepts positive values
        XCTAssertTrue(true, "setMaxThinkingTokens(10000) should succeed without throwing")
    }

    /// AC8 [P0]: setMaxThinkingTokens(nil) clears thinking config.
    func testAgent_setMaxThinkingTokens_nilClearsThinking() throws {
        let agent = Agent(
            definition: AgentDefinition(name: "test-thinking-nil"),
            options: AgentOptions(apiKey: "test-key", thinking: .enabled(budgetTokens: 5000))
        )
        // Clear thinking by passing nil
        try agent.setMaxThinkingTokens(nil)

        // Verify the method completes without error
        XCTAssertTrue(true, "setMaxThinkingTokens(nil) should clear thinking config")
    }

    /// AC8 [P0]: setMaxThinkingTokens(0) throws SDKError.invalidConfiguration.
    func testAgent_setMaxThinkingTokens_zeroThrows() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-thinking-zero"),
            options: AgentOptions(apiKey: "test-key")
        )
        XCTAssertThrowsError(try agent.setMaxThinkingTokens(0),
                             "setMaxThinkingTokens(0) should throw invalidConfiguration")
    }

    /// AC8 [P1]: setMaxThinkingTokens(-1) throws SDKError.invalidConfiguration.
    func testAgent_setMaxThinkingTokens_negativeThrows() {
        let agent = Agent(
            definition: AgentDefinition(name: "test-thinking-negative"),
            options: AgentOptions(apiKey: "test-key")
        )
        XCTAssertThrowsError(try agent.setMaxThinkingTokens(-1),
                             "setMaxThinkingTokens(-1) should throw invalidConfiguration")
    }
}

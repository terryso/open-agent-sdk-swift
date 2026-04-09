---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-09'
inputDocuments:
  - _bmad-output/implementation-artifacts/9-3-runnable-code-examples.md
  - Sources/OpenAgentSDK/Core/Agent.swift
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Sources/OpenAgentSDK/Types/SDKMessage.swift
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Types/MCPConfig.swift
  - Sources/OpenAgentSDK/Types/HookTypes.swift
  - Sources/OpenAgentSDK/Types/SessionTypes.swift
  - Sources/OpenAgentSDK/Tools/ToolBuilder.swift
  - Sources/OpenAgentSDK/Tools/MCP/InProcessMCPServer.swift
  - Sources/OpenAgentSDK/Stores/SessionStore.swift
  - Sources/OpenAgentSDK/Hooks/HookRegistry.swift
  - Package.swift
---

# ATDD Checklist: Story 9-3 -- Runnable Code Examples

## TDD Red Phase (Current)

**All 45 tests FAIL until the Examples/ directory and all 5 runnable code examples are created.** Tests reference files and API usage patterns that do not yet exist:

1. No `Examples/` directory or any example subdirectories exist
2. No `BasicAgent`, `StreamingAgent`, `CustomTools`, `MCPIntegration`, `SessionsAndHooks` targets in Package.swift
3. All file-existence checks fail immediately
4. All content-verification tests fail because files cannot be read

These will resolve once Tasks 1-7 are implemented.

### Compilation Errors (Expected)

None. The test file compiles correctly (`swift build --build-tests` passes). Runtime failures are expected because the example files do not yet exist.

### Test Run Results

```
Executed 45 tests, with 76 failures (0 unexpected) in 0.637 seconds
```

All 45 tests fail as expected. Zero unexpected failures.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest (unit tests only)
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | BasicAgent example compiles and runs | P0 | Unit | `testBasicAgentDirectoryExists`, `testBasicAgentMainSwiftExists`, `testBasicAgentUsesCreateAgent`, `testBasicAgentUsesBlockingPrompt`, `testBasicAgentShowsQueryResultProperties`, `testBasicAgentImportsOpenAgentSDK` |
| AC2 | StreamingAgent example compiles and runs | P0 | Unit | `testStreamingAgentDirectoryExists`, `testStreamingAgentMainSwiftExists`, `testStreamingAgentUsesAsyncStream`, `testStreamingAgentShowsSDKMessagePatternMatching`, `testStreamingAgentShowsToolUseEvents` |
| AC3 | CustomTools example compiles and runs | P0 | Unit | `testCustomToolsDirectoryExists`, `testCustomToolsMainSwiftExists`, `testCustomToolsUsesDefineTool`, `testCustomToolsDefinesCodableInputStruct`, `testCustomToolsDefinesJSONSchema`, `testCustomToolsUsesToolExecuteResult` |
| AC4 | MCPIntegration example compiles and runs | P0 | Unit | `testMCPIntegrationDirectoryExists`, `testMCPIntegrationMainSwiftExists`, `testMCPIntegrationUsesStdioConfig`, `testMCPIntegrationUsesInProcessMCPServer`, `testMCPIntegrationUsesMcpServersInOptions` |
| AC5 | SessionsAndHooks example compiles and runs | P0 | Unit | `testSessionsAndHooksDirectoryExists`, `testSessionsAndHooksMainSwiftExists`, `testSessionsAndHooksUsesSessionStore`, `testSessionsAndHooksUsesHookRegistry`, `testSessionsAndHooksShowsHookDefinition` |
| AC6 | All examples use actual public API | P0 | Unit | `testAllExamplesImportOpenAgentSDK`, `testAllExamplesUseAgentOptionsCorrectly`, `testAllExamplesUseCreateAgentFunction`, `testDefineToolSignatureMatchesSource`, `testSDKMessageCasesMatchSource`, `testMCPConfigTypesMatchSource`, `testHookTypesMatchSource` |
| AC7 | Each example has clear comments | P1 | Unit | `testAllExamplesHaveTopLevelDescription`, `testAllExamplesHaveInlineComments` |
| AC8 | Examples do not expose real API keys | P0 | Unit | `testNoExampleContainsRealAPIKeys`, `testExamplesUsePlaceholderOrEnvVarForAPIKey` |
| Package | Package.swift contains all targets | P0 | Unit | `testPackageSwiftContainsBasicAgentTarget`, `testPackageSwiftContainsStreamingAgentTarget`, `testPackageSwiftContainsCustomToolsTarget`, `testPackageSwiftContainsMCPIntegrationTarget`, `testPackageSwiftContainsSessionsAndHooksTarget`, `testAllExampleTargetsDependOnOpenAgentSDK`, `testMCPIntegrationTargetDependsOnMCP` |

## Test Summary

- **Total Tests:** 45 (all unit, documentation/file compliance)
- **Unit Tests:** 45 (all in `Tests/OpenAgentSDKTests/Documentation/ExamplesComplianceTests.swift`)
- **E2E Tests:** 0 (not applicable -- file-creation story; compilation verification is done via `swift build`)
- **All tests will FAIL until Examples/ directory and example files are created**

## Unit Test Plan (Tests/OpenAgentSDKTests/Documentation/ExamplesComplianceTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testBasicAgentDirectoryExists` | AC1 | P0 | Examples/BasicAgent/ directory exists |
| 2 | `testBasicAgentMainSwiftExists` | AC1 | P0 | Examples/BasicAgent/main.swift file exists |
| 3 | `testBasicAgentUsesCreateAgent` | AC1 | P0 | BasicAgent uses createAgent() factory |
| 4 | `testBasicAgentUsesBlockingPrompt` | AC1 | P0 | BasicAgent uses agent.prompt() blocking query |
| 5 | `testBasicAgentShowsQueryResultProperties` | AC1 | P0 | BasicAgent demonstrates QueryResult.text |
| 6 | `testBasicAgentImportsOpenAgentSDK` | AC1 | P0 | BasicAgent imports OpenAgentSDK |
| 7 | `testStreamingAgentDirectoryExists` | AC2 | P0 | Examples/StreamingAgent/ directory exists |
| 8 | `testStreamingAgentMainSwiftExists` | AC2 | P0 | Examples/StreamingAgent/main.swift file exists |
| 9 | `testStreamingAgentUsesAsyncStream` | AC2 | P0 | StreamingAgent uses for await / agent.stream() |
| 10 | `testStreamingAgentShowsSDKMessagePatternMatching` | AC2 | P0 | StreamingAgent handles .partialMessage and .result |
| 11 | `testStreamingAgentShowsToolUseEvents` | AC2 | P0 | StreamingAgent handles .toolUse and .toolResult |
| 12 | `testCustomToolsDirectoryExists` | AC3 | P0 | Examples/CustomTools/ directory exists |
| 13 | `testCustomToolsMainSwiftExists` | AC3 | P0 | Examples/CustomTools/main.swift file exists |
| 14 | `testCustomToolsUsesDefineTool` | AC3 | P0 | CustomTools uses defineTool() function |
| 15 | `testCustomToolsDefinesCodableInputStruct` | AC3 | P0 | CustomTools defines Codable input struct |
| 16 | `testCustomToolsDefinesJSONSchema` | AC3 | P0 | CustomTools defines inputSchema |
| 17 | `testCustomToolsUsesToolExecuteResult` | AC3 | P0 | CustomTools uses ToolExecuteResult return type |
| 18 | `testMCPIntegrationDirectoryExists` | AC4 | P0 | Examples/MCPIntegration/ directory exists |
| 19 | `testMCPIntegrationMainSwiftExists` | AC4 | P0 | Examples/MCPIntegration/main.swift file exists |
| 20 | `testMCPIntegrationUsesStdioConfig` | AC4 | P0 | MCPIntegration uses McpServerConfig.stdio() |
| 21 | `testMCPIntegrationUsesInProcessMCPServer` | AC4 | P0 | MCPIntegration uses InProcessMCPServer and .sdk() |
| 22 | `testMCPIntegrationUsesMcpServersInOptions` | AC4 | P0 | MCPIntegration uses mcpServers: in AgentOptions |
| 23 | `testSessionsAndHooksDirectoryExists` | AC5 | P0 | Examples/SessionsAndHooks/ directory exists |
| 24 | `testSessionsAndHooksMainSwiftExists` | AC5 | P0 | Examples/SessionsAndHooks/main.swift file exists |
| 25 | `testSessionsAndHooksUsesSessionStore` | AC5 | P0 | SessionsAndHooks uses SessionStore with save/load |
| 26 | `testSessionsAndHooksUsesHookRegistry` | AC5 | P0 | SessionsAndHooks uses HookRegistry.register() |
| 27 | `testSessionsAndHooksShowsHookDefinition` | AC5 | P0 | SessionsAndHooks shows HookDefinition usage |
| 28 | `testAllExamplesImportOpenAgentSDK` | AC6 | P0 | All 5 examples import OpenAgentSDK |
| 29 | `testAllExamplesUseAgentOptionsCorrectly` | AC6 | P0 | AgentOptions uses real parameter names |
| 30 | `testAllExamplesUseCreateAgentFunction` | AC6 | P0 | All examples use createAgent() |
| 31 | `testDefineToolSignatureMatchesSource` | AC6 | P0 | defineTool uses name:, description:, inputSchema: |
| 32 | `testSDKMessageCasesMatchSource` | AC6 | P0 | SDKMessage cases match source enum |
| 33 | `testMCPConfigTypesMatchSource` | AC6 | P0 | MCP config types use real init params |
| 34 | `testHookTypesMatchSource` | AC6 | P0 | Hook types use real parameter names |
| 35 | `testAllExamplesHaveTopLevelDescription` | AC7 | P1 | Each example starts with a descriptive comment |
| 36 | `testAllExamplesHaveInlineComments` | AC7 | P1 | Each example has multiple inline comments |
| 37 | `testNoExampleContainsRealAPIKeys` | AC8 | P0 | No example contains real-looking API keys |
| 38 | `testExamplesUsePlaceholderOrEnvVarForAPIKey` | AC8 | P0 | API keys use placeholder or env var |
| 39 | `testPackageSwiftContainsBasicAgentTarget` | Package | P0 | Package.swift has BasicAgent target |
| 40 | `testPackageSwiftContainsStreamingAgentTarget` | Package | P0 | Package.swift has StreamingAgent target |
| 41 | `testPackageSwiftContainsCustomToolsTarget` | Package | P0 | Package.swift has CustomTools target |
| 42 | `testPackageSwiftContainsMCPIntegrationTarget` | Package | P0 | Package.swift has MCPIntegration target |
| 43 | `testPackageSwiftContainsSessionsAndHooksTarget` | Package | P0 | Package.swift has SessionsAndHooks target |
| 44 | `testAllExampleTargetsDependOnOpenAgentSDK` | Package | P0 | All targets depend on OpenAgentSDK |
| 45 | `testMCPIntegrationTargetDependsOnMCP` | Package | P0 | MCPIntegration target depends on MCP product |

## Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `Tests/OpenAgentSDKTests/Documentation/ExamplesComplianceTests.swift` | Created | 45 unit tests for Examples compliance |

## Next Steps (TDD Green Phase)

After implementing the feature (Tasks 1-8):

1. **Task 1:** Create Examples/ directory structure and update Package.swift with 5 executableTarget entries
2. **Task 2:** Implement BasicAgent example (createAgent + blocking prompt)
3. **Task 3:** Implement StreamingAgent example (AsyncStream + SDKMessage pattern matching)
4. **Task 4:** Implement CustomTools example (defineTool + Codable input + ToolExecuteResult)
5. **Task 5:** Implement MCPIntegration example (McpServerConfig.stdio + InProcessMCPServer + .sdk)
6. **Task 6:** Implement SessionsAndHooks example (SessionStore + HookRegistry + HookDefinition)
7. **Task 7:** Run `swift build` -- verify all example targets compile
8. **Task 8:** Run `swift test` -- verify ExamplesComplianceTests pass and no regressions

---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-16'
story_id: '17-1'
inputDocuments:
  - '_bmad-output/implementation-artifacts/17-1-sdkmessage-type-enhancement.md'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Tests/OpenAgentSDKTests/Core/SDKMessageTests.swift'
  - 'Tests/OpenAgentSDKTests/Types/SDKMessageDeepTests.swift'
  - 'Tests/OpenAgentSDKTests/Compat/MessageTypesCompatTests.swift'
---

# ATDD Checklist — Story 17.1: SDKMessage Type Enhancement

## Test Stack

- **Detected stack**: backend (Swift Package Manager, XCTest)
- **Framework**: XCTest
- **TDD Phase**: RED (tests fail because feature is not implemented)

## Acceptance Criteria to Test Mapping

| AC | Description | Priority | Test Count | Test Class |
|----|-------------|----------|------------|------------|
| AC1 | Add 12 new SDKMessage cases | P0 | 15 | SDKMessageNewCasesATDDTests |
| AC2 | Complete AssistantData fields (uuid, sessionId, parentToolUseId, error with 7 subtypes) | P0 | 7 | AssistantDataEnhancementATDDTests |
| AC3 | Complete ResultData fields (structuredOutput, permissionDenials, modelUsage, errorMaxStructuredOutputRetries) | P0 | 8 | ResultDataEnhancementATDDTests |
| AC4 | Complete SystemData init fields (sessionId, tools, model, permissionMode, mcpServers, cwd + 7 new subtypes) | P0 | 16 | SystemDataEnhancementATDDTests |
| AC5 | Complete PartialData fields (parentToolUseId, uuid, sessionId) | P0 | 5 | PartialDataEnhancementATDDTests |
| AC6 | Sendable conformance for all new types | P0 | 3 | SendableConformanceATDDTests |
| AC7 | Zero regression (backward compatibility) | P0/P1 | 2 | ZeroRegressionATDDTests |
| AC8 | AsyncStream integration | P1 | 2 | AsyncStreamIntegrationATDDTests |

## Test File Created

| File | Path | Test Count | Status |
|------|------|------------|--------|
| SDKMessageEnhancementATDDTests.swift | `Tests/OpenAgentSDKTests/Types/SDKMessageEnhancementATDDTests.swift` | 58 | RED (fails compilation — types don't exist yet) |

## Detailed Test Inventory

### SDKMessageNewCasesATDDTests (15 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testUserMessage_caseConstruction | P0 | AC1 | .userMessage case with UserMessageData (uuid, sessionId, message, parentToolUseId, isSynthetic, toolUseResult) |
| 2 | testUserMessage_optionalFieldsNil | P0 | AC1 | UserMessageData optional fields accept nil |
| 3 | testToolProgress_caseConstruction | P0 | AC1 | .toolProgress case with ToolProgressData (toolUseId, toolName, parentToolUseId, elapsedTimeSeconds) |
| 4 | testToolProgress_optionalParentNil | P1 | AC1 | ToolProgressData optional parentToolUseId can be nil |
| 5 | testHookStarted_caseConstruction | P0 | AC1 | .hookStarted case with HookStartedData (hookId, hookName, hookEvent) |
| 6 | testHookProgress_caseConstruction | P0 | AC1 | .hookProgress case with HookProgressData (hookId, hookName, hookEvent, stdout, stderr) |
| 7 | testHookResponse_caseConstruction | P0 | AC1 | .hookResponse case with HookResponseData (hookId, hookName, hookEvent, output, exitCode, outcome) |
| 8 | testTaskStarted_caseConstruction | P0 | AC1 | .taskStarted case with TaskStartedData (taskId, taskType, description) |
| 9 | testTaskProgress_caseConstruction | P0 | AC1 | .taskProgress case with TaskProgressData (taskId, taskType, usage) |
| 10 | testAuthStatus_caseConstruction | P0 | AC1 | .authStatus case with AuthStatusData (status, message) |
| 11 | testFilesPersisted_caseConstruction | P0 | AC1 | .filesPersisted case with FilesPersistedData (filePaths) |
| 12 | testLocalCommandOutput_caseConstruction | P0 | AC1 | .localCommandOutput case with LocalCommandOutputData (output, command) |
| 13 | testPromptSuggestion_caseConstruction | P0 | AC1 | .promptSuggestion case with PromptSuggestionData (suggestions) |
| 14 | testToolUseSummary_caseConstruction | P0 | AC1 | .toolUseSummary case with ToolUseSummaryData (toolUseCount, tools) |
| 15 | testSDKMessage_has18Cases_exhaustiveSwitch | P0 | AC1 | Exhaustive switch on all 18 SDKMessage cases |

### AssistantDataEnhancementATDDTests (7 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testAssistantData_uuidField | P0 | AC2 | uuid field exists and is settable |
| 2 | testAssistantData_sessionIdField | P0 | AC2 | sessionId field exists and is settable |
| 3 | testAssistantData_parentToolUseIdField | P0 | AC2 | parentToolUseId field exists and is settable |
| 4 | testAssistantData_errorField | P0 | AC2 | error field with AssistantError enum |
| 5 | testAssistantError_all7Subtypes | P0 | AC2 | AssistantError has exactly 7 subtypes |
| 6 | testAssistantData_backwardCompatibility | P0 | AC2 | Original 3-field init still works |
| 7 | testAssistantError_rawValues | P1 | AC2 | AssistantError raw values match TS SDK |

### ResultDataEnhancementATDDTests (8 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testResultData_errorMaxStructuredOutputRetries_subtype | P0 | AC3 | New subtype errorMaxStructuredOutputRetries |
| 2 | testResultData_structuredOutputField | P0 | AC3 | structuredOutput field (Any? JSON-compatible) |
| 3 | testResultData_permissionDenialsField | P0 | AC3 | permissionDenials field with SDKPermissionDenial |
| 4 | testSDKPermissionDenial_fields | P0 | AC3 | SDKPermissionDenial has toolName, toolUseId, toolInput |
| 5 | testResultData_modelUsageField | P0 | AC3 | modelUsage field with ModelUsageEntry |
| 6 | testResultData_modelUsage_coexistsWith_costBreakdown | P1 | AC3 | modelUsage and costBreakdown coexist |
| 7 | testResultData_backwardCompatibility | P0 | AC3 | Original init still works |
| 8 | testResultData_allSubtypes | P0 | AC3 | All 6 subtypes present |

### SystemDataEnhancementATDDTests (16 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testSystemData_sessionIdField | P0 | AC4 | sessionId field |
| 2 | testSystemData_toolsField | P0 | AC4 | tools field with ToolInfo array |
| 3 | testSystemData_modelField | P0 | AC4 | model field |
| 4 | testSystemData_permissionModeField | P0 | AC4 | permissionMode field |
| 5 | testSystemData_mcpServersField | P0 | AC4 | mcpServers field with McpServerInfo array |
| 6 | testSystemData_cwdField | P0 | AC4 | cwd field |
| 7 | testSystemData_taskStartedSubtype | P0 | AC4 | taskStarted subtype |
| 8 | testSystemData_taskProgressSubtype | P0 | AC4 | taskProgress subtype |
| 9 | testSystemData_hookStartedSubtype | P0 | AC4 | hookStarted subtype |
| 10 | testSystemData_hookProgressSubtype | P0 | AC4 | hookProgress subtype |
| 11 | testSystemData_hookResponseSubtype | P0 | AC4 | hookResponse subtype |
| 12 | testSystemData_filesPersistedSubtype | P0 | AC4 | filesPersisted subtype |
| 13 | testSystemData_localCommandOutputSubtype | P0 | AC4 | localCommandOutput subtype |
| 14 | testSystemData_allSubtypes | P0 | AC4 | All 12 subtypes present |
| 15 | testSystemData_backwardCompatibility | P0 | AC4 | Original 2-field init still works |
| 16 | testToolInfo_fields | P0 | AC4 | ToolInfo struct |
| 17 | testMcpServerInfo_fields | P0 | AC4 | McpServerInfo struct |

### PartialDataEnhancementATDDTests (5 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testPartialData_parentToolUseIdField | P0 | AC5 | parentToolUseId field |
| 2 | testPartialData_uuidField | P0 | AC5 | uuid field |
| 3 | testPartialData_sessionIdField | P0 | AC5 | sessionId field |
| 4 | testPartialData_allNewFields | P0 | AC5 | All new fields together |
| 5 | testPartialData_backwardCompatibility | P0 | AC5 | Original text-only init still works |

### SendableConformanceATDDTests (3 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testAllNewTypes_areSendable | P0 | AC6 | All 12 new data types conform to Sendable |
| 2 | testSupportingTypes_areSendable | P0 | AC6 | AssistantError, SDKPermissionDenial, ModelUsageEntry, ToolInfo, McpServerInfo |
| 3 | testEnhancedTypes_stillSendable | P0 | AC6 | Enhanced existing types still conform |

### ZeroRegressionATDDTests (2 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testOriginalCases_backwardCompat | P0 | AC7 | Original init signatures still work |
| 2 | testTextProperty_originalCases | P1 | AC7 | text computed property for all original cases |

### AsyncStreamIntegrationATDDTests (2 tests)

| # | Test Name | Priority | AC | What It Verifies |
|---|-----------|----------|----|-----------------|
| 1 | testAsyncStream_newMessageTypes | P1 | AC8 | New message types yieldable through AsyncStream |
| 2 | testAsyncStream_enhancedTypes | P1 | AC8 | Enhanced existing types through AsyncStream |

## Priority Distribution

| Priority | Count |
|----------|-------|
| P0 | 48 |
| P1 | 10 |
| **Total** | **58** |

## New Types Required by Tests

| Type | Kind | Parent | Fields |
|------|------|--------|--------|
| UserMessageData | struct | SDKMessage | uuid: String?, sessionId: String?, message: String, parentToolUseId: String?, isSynthetic: Bool?, toolUseResult: String? |
| ToolProgressData | struct | SDKMessage | toolUseId: String, toolName: String, parentToolUseId: String?, elapsedTimeSeconds: Double? |
| HookStartedData | struct | SDKMessage | hookId: String, hookName: String, hookEvent: String |
| HookProgressData | struct | SDKMessage | hookId: String, hookName: String, hookEvent: String, stdout: String?, stderr: String? |
| HookResponseData | struct | SDKMessage | hookId: String, hookName: String, hookEvent: String, output: String?, exitCode: Int?, outcome: String? |
| TaskStartedData | struct | SDKMessage | taskId: String, taskType: String, description: String |
| TaskProgressData | struct | SDKMessage | taskId: String, taskType: String, usage: TokenUsage? |
| AuthStatusData | struct | SDKMessage | status: String, message: String |
| FilesPersistedData | struct | SDKMessage | filePaths: [String] |
| LocalCommandOutputData | struct | SDKMessage | output: String, command: String |
| PromptSuggestionData | struct | SDKMessage | suggestions: [String] |
| ToolUseSummaryData | struct | SDKMessage | toolUseCount: Int, tools: [String] |
| AssistantError | enum | SDKMessage | 7 cases: authenticationFailed, billingError, rateLimit, invalidRequest, serverError, maxOutputTokens, unknown |
| SDKPermissionDenial | struct | SDKMessage | toolName: String, toolUseId: String, toolInput: String |
| ModelUsageEntry | struct | SDKMessage | model: String, inputTokens: Int, outputTokens: Int |
| ToolInfo | struct | SDKMessage | name: String, description: String |
| McpServerInfo | struct | SDKMessage | name: String, command: String |

## TDD Red Phase Confirmation

**Status: RED** -- All 58 tests fail to compile because:
1. 12 new SDKMessage cases don't exist (userMessage, toolProgress, hookStarted, etc.)
2. 12 new data structs don't exist (UserMessageData, ToolProgressData, etc.)
3. New fields on existing types don't exist (AssistantData.uuid, ResultData.structuredOutput, etc.)
4. New enums don't exist (AssistantError with 7 subtypes)
5. New subtypes on SystemData.Subtype and ResultData.Subtype don't exist

Compilation errors confirm these tests exercise code that has NOT been implemented yet.

## Key Risks & Assumptions

1. **Type alias for Any?**: structuredOutput is typed `Any?` which is not Equatable. Tests verify it's settable but not equality.
2. **ModelUsageEntry vs CostBreakdownEntry**: ModelUsageEntry is a new type (without costUsd), distinct from CostBreakdownEntry.
3. **Backward compatibility**: All new fields are optional. Tests verify original init signatures still compile.
4. **Exhaustive switch**: Adding 12 new cases will break existing `switch` statements in production code. Implementation must update all switch sites.
5. **AsyncStream tests**: These are basic yieldability tests. Full Agent.swift integration tests will be added during development.

## Next Steps

1. Run `/bmad-dev-story 17-1` to implement the feature (TDD green phase)
2. All 58 ATDD tests should transition from RED to GREEN
3. Run full test suite (3650+ tests) to verify zero regression (AC7)

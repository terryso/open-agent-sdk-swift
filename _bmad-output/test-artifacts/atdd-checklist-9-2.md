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
  - _bmad-output/implementation-artifacts/9-2-readme-quickstart-guide.md
  - README.md
  - README_CN.md
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Sources/OpenAgentSDK/Core/Agent.swift
  - Sources/OpenAgentSDK/Tools/ToolBuilder.swift
  - Sources/OpenAgentSDK/Types/SDKConfiguration.swift
---

# ATDD Checklist: Story 9-2 -- README & Quickstart Guide

## TDD Red Phase (Current)

**All tests will FAIL until the README is updated to reflect the full SDK capabilities.** Tests reference content, structure, and API signatures that do not yet exist in the current README:

1. README lists only 11 built-in tools -- should list all 34
2. README marks MCP, Session, Hooks, Budget, Permission, Auto-compaction, NotebookEdit as "In Progress / Planned" -- all are implemented
3. README lacks feature highlights, advanced usage sections, DocC links
4. README_CN.md is outdated and does not reflect full SDK capabilities
5. Architecture diagram labels MCP as "planned"

These will resolve once Tasks 1-4 are implemented.

### Compilation Errors (Expected)

None. The test file compiles correctly. Runtime failures are expected because the README content does not meet the acceptance criteria.

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest (unit), custom harness (E2E)
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | README Quick Start -- 15-minute goal | P0 | Unit | `testQuickStartContainsBlockingQueryExample`, `testQuickStartContainsStreamingQueryExample`, `testQuickStartContainsCustomToolExample`, `testREADMEContainsQuickStartSection` |
| AC2 | README reflects all implemented features | P0 | Unit | `testStatusSectionDoesNotListImplementedFeaturesAsPlanned`, `testREADMEListsAll34BuiltInTools`, `testREADMEMentionsMCPIntegration`, `testREADMEMentionsSessionPersistence`, `testREADMEMentionsHookSystem`, `testREADMEMentionsPermissionControl`, `testREADMEMentionsBudgetTracking`, `testREADMEMentionsAutoCompaction`, `testREADMEMentionsMultiAgentOrchestration` |
| AC3 | Advanced usage links | P1 | Unit | `testREADMELinksToDocCDocumentation`, `testREADMELinksToAdvancedTopics`, `testREADMEMentionsExamplesDirectory` |
| AC4 | Code examples compile | P0 | Unit | `testCreateAgentExampleMatchesActualAPI`, `testAgentOptionsExampleUsesCorrectParameters`, `testStreamingExampleUsesActualAPI`, `testCustomToolExampleUsesDefineTool`, `testSDKConfigurationExampleMatchesActualAPI`, `testMultiProviderExampleUsesActualAPI`, `testCodeExamplesDoNotExposeRealAPIKeys` |
| AC5 | README as SDK landing page | P0 | Unit | `testREADMEContainsProjectDescription`, `testREADMEContainsFeatureHighlights`, `testREADMEContainsInstallationInstructions`, `testREADMEContainsEnvironmentVariablesTable`, `testREADMEContainsRequirementsSection`, `testREADMEContainsDevelopmentSection`, `testREADMEContainsLicense`, `testREADMEContainsArchitectureDiagram`, `testArchitectureDiagramReflectsFullSDK` |
| AC6 | Multi-language support (README_CN.md) | P1 | Unit | `testREADME_CNExists`, `testREADME_CNContainsQuickStart`, `testREADME_CNContainsToolList`, `testREADME_CNMentionsMCPIntegration`, `testREADME_CNMentionsSessionPersistence`, `testREADME_CNMentionsHookSystem`, `testREADME_CNMentionsPermissionControl`, `testREADME_CNSyncedWithMainREADME` |

## Test Summary

- **Total Tests:** 32 (all unit, documentation compliance)
- **Unit Tests:** 32 (all in `Tests/OpenAgentSDKTests/Documentation/READMEComplianceTests.swift`)
- **E2E Tests:** 0 (not applicable -- documentation-only story)
- **All tests will FAIL until README is updated** (missing sections, outdated content, incomplete tool list)

## Unit Test Plan (Tests/OpenAgentSDKTests/Documentation/READMEComplianceTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testREADMEContainsProjectDescription` | AC5 | P0 | README has project description |
| 2 | `testREADMEContainsFeatureHighlights` | AC5 | P0 | README has features/highlights section |
| 3 | `testREADMEContainsInstallationInstructions` | AC5 | P0 | README has Installation section with SPM |
| 4 | `testREADMEContainsQuickStartSection` | AC1 | P0 | README has Quick Start section |
| 5 | `testREADMEContainsEnvironmentVariablesTable` | AC5 | P0 | README documents all 3 env vars |
| 6 | `testREADMEContainsRequirementsSection` | AC5 | P0 | README specifies Swift and macOS requirements |
| 7 | `testREADMEContainsDevelopmentSection` | AC5 | P0 | README shows swift build/test commands |
| 8 | `testREADMEContainsLicense` | AC5 | P0 | README has MIT license |
| 9 | `testQuickStartContainsBlockingQueryExample` | AC1 | P0 | Quick Start shows agent.prompt() |
| 10 | `testQuickStartContainsStreamingQueryExample` | AC1 | P0 | Quick Start shows agent.stream() with AsyncStream |
| 11 | `testQuickStartContainsCustomToolExample` | AC1 | P0 | Quick Start shows defineTool() |
| 12 | `testStatusSectionDoesNotListImplementedFeaturesAsPlanned` | AC2 | P0 | No Epic 1-8 features marked as In Progress/Planned |
| 13 | `testREADMEListsAll34BuiltInTools` | AC2 | P0 | Tool table lists all 34 tools (Core 10 + Advanced 11 + Specialist 13) |
| 14 | `testREADMEMentionsMCPIntegration` | AC2 | P0 | README mentions MCP |
| 15 | `testREADMEMentionsSessionPersistence` | AC2 | P0 | README mentions SessionStore |
| 16 | `testREADMEMentionsHookSystem` | AC2 | P0 | README mentions HookRegistry |
| 17 | `testREADMEMentionsPermissionControl` | AC2 | P0 | README mentions PermissionMode |
| 18 | `testREADMEMentionsBudgetTracking` | AC2 | P0 | README mentions budget tracking |
| 19 | `testREADMEMentionsAutoCompaction` | AC2 | P0 | README mentions auto-compaction |
| 20 | `testREADMEMentionsMultiAgentOrchestration` | AC2 | P0 | README mentions sub-agent/multi-agent |
| 21 | `testREADMELinksToDocCDocumentation` | AC3 | P1 | README links to Swift-DocC docs |
| 22 | `testREADMELinksToAdvancedTopics` | AC3 | P1 | README links to advanced DocC articles |
| 23 | `testREADMEMentionsExamplesDirectory` | AC3 | P1 | README mentions Examples/ directory |
| 24 | `testCreateAgentExampleMatchesActualAPI` | AC4 | P0 | createAgent example uses real signature |
| 25 | `testAgentOptionsExampleUsesCorrectParameters` | AC4 | P0 | AgentOptions example uses real parameter names |
| 26 | `testStreamingExampleUsesActualAPI` | AC4 | P0 | Streaming example uses real SDKMessage pattern |
| 27 | `testCustomToolExampleUsesDefineTool` | AC4 | P0 | defineTool example has name, description, inputSchema, handler |
| 28 | `testSDKConfigurationExampleMatchesActualAPI` | AC4 | P0 | SDKConfiguration example uses real init |
| 29 | `testMultiProviderExampleUsesActualAPI` | AC4 | P0 | Multi-provider example uses real LLMProvider enum |
| 30 | `testCodeExamplesDoNotExposeRealAPIKeys` | AC4 | P0 | No real API key patterns in examples |
| 31 | `testREADMEContainsArchitectureDiagram` | AC5 | P0 | README has Mermaid architecture diagram |
| 32 | `testArchitectureDiagramReflectsFullSDK` | AC5 | P0 | Diagram does not label components as "planned" |

## Chinese README Tests (README_CN.md)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 33 | `testREADME_CNExists` | AC6 | P1 | README_CN.md file exists |
| 34 | `testREADME_CNContainsQuickStart` | AC6 | P1 | CN version has Quick Start section |
| 35 | `testREADME_CNContainsToolList` | AC6 | P1 | CN version lists built-in tools |
| 36 | `testREADME_CNMentionsMCPIntegration` | AC6 | P1 | CN version mentions MCP |
| 37 | `testREADME_CNMentionsSessionPersistence` | AC6 | P1 | CN version mentions session persistence |
| 38 | `testREADME_CNMentionsHookSystem` | AC6 | P1 | CN version mentions hook system |
| 39 | `testREADME_CNMentionsPermissionControl` | AC6 | P1 | CN version mentions permission control |
| 40 | `testREADME_CNSyncedWithMainREADME` | AC6 | P1 | CN version has parity with main README sections |

## Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `Tests/OpenAgentSDKTests/Documentation/READMEComplianceTests.swift` | Created | 40 unit tests for README compliance |

## Next Steps (TDD Green Phase)

After implementing the feature (Tasks 1-4):

1. **Task 1:** Audit current README vs actual features gap
2. **Task 2:** Rewrite README.md with full SDK capabilities
3. **Task 3:** Sync README_CN.md with updated content
4. **Task 4:** Verify all code examples match actual public API signatures
5. Run `swift test` -- verify READMEComplianceTests pass
6. Run full test suite -- verify no regressions
7. Run `swift build` -- verify compilation

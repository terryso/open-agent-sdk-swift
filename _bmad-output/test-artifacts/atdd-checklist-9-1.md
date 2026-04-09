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
  - _bmad-output/implementation-artifacts/9-1-swift-docc-api-docs.md
  - Sources/OpenAgentSDK/OpenAgentSDK.swift
  - Package.swift
  - Sources/OpenAgentSDK/Types/*.swift
  - Sources/OpenAgentSDK/Core/Agent.swift
  - Sources/OpenAgentSDK/Tools/ToolBuilder.swift
  - Sources/OpenAgentSDK/Tools/ToolRegistry.swift
  - Sources/OpenAgentSDK/Stores/*.swift
  - Sources/OpenAgentSDK/Hooks/*.swift
  - Sources/OpenAgentSDK/Tools/MCP/*.swift
---

# ATDD Checklist: Story 9-1 -- Swift-DocC API Documentation

## TDD Red Phase (Current)

**All tests will FAIL until the implementation is complete.** Tests reference files and structures that do not yet exist:

1. `Documentation.docc/` directory does not exist yet
2. `swift-docc-plugin` dependency not added to `Package.swift`
3. DocC article files (`OpenAgentSDK.md`, `GettingStarted.md`, `ToolSystem.md`, `MultiAgent.md`, `MCPSessionHooks.md`) do not exist
4. Many public declarations lack DocC `///` comments

These will resolve once Tasks 1-8 are implemented.

### Compilation Errors (Expected)

All errors stem from:
1. `Documentation.docc/` directory and catalog files not created
2. `Package.swift` does not include `swift-docc-plugin` dependency
3. Public declarations missing `///` summary comments

## Stack Detection

- **Detected Stack:** backend (Swift Package Manager, no frontend indicators)
- **Test Framework:** XCTest (unit), custom harness (E2E)
- **Generation Mode:** AI Generation (backend -- no browser recording needed)

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Level | Test Scenarios |
|----|-------------|----------|------------|----------------|
| AC1 | DocC directory structure | P0 | Unit | `testDocCCatalogDirectoryExists`, `testDocCCatalogContainsModuleDocumentation`, `testDocCCatalogContainsArticles` |
| AC2 | DocC plugin integration | P0 | Unit | `testPackageSwiftContainsDocCPluginDependency` |
| AC3 | All public types have documentation comments | P0 | Unit | `testPublicDeclarationsHaveDocCComments` (audit across all source files) |
| AC4 | Module-level documentation | P1 | Unit | `testOpenAgentSDKMdContainsRequiredSections` |
| AC5 | Tool system documentation | P1 | Unit | `testToolSystemMdContainsRequiredSections` |
| AC6 | Multi-agent documentation | P1 | Unit | `testMultiAgentMdContainsRequiredSections` |
| AC7 | MCP and session hooks documentation | P1 | Unit | `testMCPSessionHooksMdContainsRequiredSections` |
| AC8 | Getting started guide | P1 | Unit | `testGettingStartedMdContainsRunnableExample` |
| AC9 | Code examples validation | P1 | Unit | `testDocCArticlesContainSwiftCodeBlocks`, `testCodeExamplesDoNotExposeRealAPIKeys` |
| AC10 | Documentation build without warnings | P0 | E2E | `testDocumentationBuildsSuccessfully` |

## Test Summary

- **Total Tests:** 14 (13 unit + 1 E2E)
- **Unit Tests:** 13 (all in `Tests/OpenAgentSDKTests/Documentation/DocCComplianceTests.swift`)
- **E2E Tests:** 1 (in `Sources/E2ETest/DocCBuildTests.swift`)
- **All tests will FAIL until feature is implemented** (missing files/directories/dependencies)

## Unit Test Plan (Tests/OpenAgentSDKTests/Documentation/DocCComplianceTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testDocCCatalogDirectoryExists` | AC1 | P0 | Documentation.docc directory exists in Sources/OpenAgentSDK/ |
| 2 | `testDocCCatalogContainsModuleDocumentation` | AC1 | P0 | OpenAgentSDK.md exists in Documentation.docc/ |
| 3 | `testDocCCatalogContainsArticles` | AC1 | P0 | All required article files exist (GettingStarted.md, ToolSystem.md, MultiAgent.md, MCPSessionHooks.md) |
| 4 | `testPackageSwiftContainsDocCPluginDependency` | AC2 | P0 | Package.swift includes swift-docc-plugin dependency |
| 5 | `testPublicDeclarationsHaveDocCComments` | AC3 | P0 | All public declarations in key source files have /// comments |
| 6 | `testCoreTypesHaveDocCComments` | AC3 | P0 | Public types in Types/ have documentation comments |
| 7 | `testAgentPublicAPIHasDocCComments` | AC3 | P0 | Agent class public methods have documentation comments |
| 8 | `testToolBuilderPublicAPIHasDocCComments` | AC3 | P0 | defineTool() overloads have documentation comments |
| 9 | `testStoreActorsHaveDocCComments` | AC3 | P0 | Store actor public methods have documentation comments |
| 10 | `testOpenAgentSDKMdContainsRequiredSections` | AC4 | P1 | Module doc contains overview, concepts, quick-start, feature list |
| 11 | `testGettingStartedMdContainsRunnableExample` | AC8 | P1 | GettingStarted.md contains a complete runnable Swift code example |
| 12 | `testToolSystemMdDocumentsProtocols` | AC5 | P1 | ToolSystem.md covers ToolProtocol, defineTool, Codable input, tool tiers |
| 13 | `testDocCArticlesDoNotExposeRealAPIKeys` | AC9 | P1 | No doc article contains hardcoded API keys (only placeholder patterns) |

## E2E Test Plan (Sources/E2ETest/DocCBuildTests.swift)

| # | Test Method | AC | Priority | Description |
|---|-------------|-----|----------|-------------|
| 1 | `testDocumentationBuildsSuccessfully` | AC2, AC10 | P0 | `swift package generate-documentation` exits with code 0 |

## Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `Tests/OpenAgentSDKTests/Documentation/DocCComplianceTests.swift` | Created | 13 unit tests |
| `Sources/E2ETest/DocCBuildTests.swift` | Created | 1 E2E test |
| `Sources/E2ETest/main.swift` | Modified | Added Section 43 |

## Next Steps (TDD Green Phase)

After implementing the feature (Tasks 1-8):

1. **Task 1:** Add swift-docc-plugin dependency to Package.swift, create Documentation.docc/ directory with OpenAgentSDK.md
2. **Task 2:** Audit and complete DocC comments in Types/*.swift
3. **Task 3:** Audit and complete DocC comments in Core/ and API/
4. **Task 4:** Audit and complete DocC comments in Tools/
5. **Task 5:** Audit and complete DocC comments in Stores/
6. **Task 6:** Audit and complete DocC comments in Hooks/ and MCP/
7. **Task 7:** Write DocC article files (GettingStarted.md, ToolSystem.md, MultiAgent.md, MCPSessionHooks.md)
8. **Task 8:** Verify documentation builds without warnings
9. Run `swift build` -- verify compilation
10. Run `swift test` -- verify unit tests pass
11. Run `swift run E2ETest` -- verify E2E tests pass
12. Run full test suite and report total count

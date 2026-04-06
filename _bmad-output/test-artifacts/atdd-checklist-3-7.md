---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-06'
inputDocuments:
  - _bmad-output/implementation-artifacts/3-7-core-web-tools-web-fetch-web-search.md
  - _bmad-output/planning-artifacts/english/epics.md
  - Sources/OpenAgentSDK/Types/ToolTypes.swift
  - Sources/OpenAgentSDK/Tools/ToolBuilder.swift
  - Sources/OpenAgentSDK/Tools/ToolRegistry.swift
  - Sources/OpenAgentSDK/Tools/Core/BashTool.swift
  - Tests/OpenAgentSDKTests/Tools/Core/BashToolTests.swift
  - Tests/OpenAgentSDKTests/Tools/Core/ToolSearchToolTests.swift
  - Tests/OpenAgentSDKTests/Tools/Core/FileToolsRegistryTests.swift
---

# ATDD Checklist: Story 3.7 -- Core Web Tools (WebFetch, WebSearch)

## TDD Red Phase (Current)

**Phase:** RED -- All tests assert expected behavior and will FAIL until implementation is complete.

- **Stack detected:** backend (Swift SPM, XCTest)
- **Generation mode:** AI generation (backend project, no browser recording needed)
- **Execution mode:** sequential (yolo mode)

## Test Files Generated

| # | File | Tests | Level | TDD Phase |
|---|------|-------|-------|-----------|
| 1 | `Tests/OpenAgentSDKTests/Tools/Core/WebFetchToolTests.swift` | 17 | Unit | RED |
| 2 | `Tests/OpenAgentSDKTests/Tools/Core/WebSearchToolTests.swift` | 11 | Unit | RED |
| 3 | `Tests/OpenAgentSDKTests/Tools/Core/FileToolsRegistryTests.swift` | +4 (updated) | Integration | RED |
| | **Total** | **32** | | |

## Acceptance Criteria Coverage

| AC | Description | Priority | Test Names | Test Level |
|----|-------------|----------|------------|------------|
| AC1 | WebFetch fetches URL content | P0 | `testWebFetch_fetchesUrl_returnsContent` | Unit |
| AC2 | WebFetch HTML content processing | P0 | `testWebFetch_htmlContent_stripsTags`, `testWebFetch_htmlContent_stripsScriptBlocks`, `testWebFetch_htmlContent_stripsStyleBlocks`, `testWebFetch_nonHtmlContent_returnsRawText` | Unit |
| AC3 | WebFetch output truncation | P0 | `testWebFetch_largeOutput_truncated` | Unit |
| AC4 | WebFetch HTTP error handling | P0 | `testWebFetch_httpError_returnsError`, `testWebFetch_httpError500_returnsError` | Unit |
| AC5 | WebFetch network error handling | P0 | `testWebFetch_networkError_returnsError`, `testWebFetch_invalidUrl_returnsError`, `testWebFetch_networkError_doesNotCrash` | Unit |
| AC6 | WebSearch executes search queries | P0 | `testWebSearch_returnsResults`, `testWebSearch_resultsContainUrls`, `testWebSearch_resultsFormattedCorrectly` | Unit |
| AC7 | WebSearch result count limiting | P0 | `testWebSearch_numResults_limitsOutput`, `testWebSearch_defaultNumResults_isFive` | Unit |
| AC8 | WebSearch no results handling | P0 | `testWebSearch_noResults_returnsMessage` | Unit |
| AC9 | Tools registered in core tier | P0 | `testGetAllBaseTools_coreTier_includesWebFetchAndWebSearch`, `testGetAllBaseTools_coreTier_webToolsAreReadOnly`, `testGetAllBaseTools_coreTier_includesAllTenTools`, `testGetAllBaseTools_coreTier_returnsTenTools` | Integration |
| AC10 | Cross-platform network requests | P0 | Verified by URLSession usage in WebFetch/WebSearch tests (Foundation-based) | Unit |

## Edge Cases and Error Scenarios

| Scenario | Test | Risk |
|----------|------|------|
| HTTP 404 error | `testWebFetch_httpError_returnsError` | P0 |
| HTTP 500 error | `testWebFetch_httpError500_returnsError` | P0 |
| DNS resolution failure | `testWebFetch_networkError_returnsError` | P0 |
| Invalid URL format | `testWebFetch_invalidUrl_returnsError` | P0 |
| Multiple network errors (no crash) | `testWebFetch_networkError_doesNotCrash` | P0 |
| Empty response body | `testWebFetch_emptyResponse_returnsMessage` | P0 |
| Custom headers | `testWebFetch_customHeaders_included` | P0 |
| User-Agent header set | `testWebFetch_setsUserAgent` | P0 |
| Large output truncation | `testWebFetch_largeOutput_truncated` | P0 |
| num_results=2 limiting | `testWebSearch_numResults_limitsOutput` | P0 |
| Default num_results=5 | `testWebSearch_defaultNumResults_isFive` | P1 |
| Schema has correct properties | `testWebFetchTool_hasCorrectSchemaProperties`, `testWebSearchTool_hasCorrectSchemaProperties` | P0 |
| num_results uses integer type | `testWebSearchTool_numResultsSchema_isInteger` | P0 |
| Required fields in schema | `testWebFetchTool_hasUrlInRequiredSchema`, `testWebSearchTool_hasQueryInRequiredSchema` | P0 |
| Tool names correct | `testWebFetchTool_hasCorrectName`, `testWebSearchTool_hasCorrectName` | P0 |
| isReadOnly=true | `testWebFetchTool_isReadOnly_true`, `testWebSearchTool_isReadOnly_true` | P0 |
| Core tier returns 10 tools | `testGetAllBaseTools_coreTier_includesAllTenTools`, `testGetAllBaseTools_coreTier_returnsTenTools` | P0 |

## Test Strategy

- **Unit tests** for each tool's core behavior (WebFetch, WebSearch)
- **Integration tests** for ToolRegistry registration, schema validation, and isReadOnly properties
- WebFetch tests use real HTTP endpoints (httpbin.org, example.com) for network validation
- WebSearch tests use real DuckDuckGo searches for end-to-end validation
- Error paths verified via `ToolResult.isError` flag checks
- HTML processing tested with real HTML pages (example.com)
- All tests follow existing naming convention: `test{ToolName}_{scenario}_{expectedBehavior}`
- Factory function pattern: `createWebFetchTool() -> ToolProtocol`, `createWebSearchTool() -> ToolProtocol`

## Implementation Endpoints

The following Swift source files need to be created/modified:

1. **Create** `Sources/OpenAgentSDK/Tools/Core/WebFetchTool.swift` -- `createWebFetchTool() -> ToolProtocol`
2. **Create** `Sources/OpenAgentSDK/Tools/Core/WebSearchTool.swift` -- `createWebSearchTool() -> ToolProtocol`
3. **Modify** `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` -- Update `getAllBaseTools(tier:)` to include `createWebFetchTool()` and `createWebSearchTool()` for `.core` tier

## Red Phase Verification

- `createWebFetchTool` symbol does NOT exist in `Sources/` -- confirmed via grep
- `createWebSearchTool` symbol does NOT exist in `Sources/` -- confirmed via grep
- `getAllBaseTools(tier: .core)` currently returns 8 tools (not 10) -- confirmed via ToolRegistry.swift
- Tests will fail at link time with unresolved symbols -- expected TDD red phase behavior
- `swift build` compiles the library successfully (tests cannot run until symbols are defined)

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Run `swift build` to verify compilation
2. Run `swift test` to verify all tests PASS
3. If tests fail:
   - Fix implementation (feature bug), OR
   - Fix test (test bug)
4. Commit passing tests alongside implementation

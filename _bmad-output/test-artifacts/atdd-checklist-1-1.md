---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-04'
inputDocuments:
  - _bmad-output/implementation-artifacts/1-1-spm-package-core-types.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/epics.md
  - .claude/skills/bmad-testarch-atdd/resources/knowledge/test-quality.md
  - .claude/skills/bmad-testarch-atdd/resources/knowledge/test-levels-framework.md
  - .claude/skills/bmad-testarch-atdd/resources/knowledge/test-priorities-matrix.md
---

# ATDD Checklist — Story 1.1: SPM Package & Core Type System

## Step 1: Preflight & Context

- **Stack:** backend (Swift 6.2.4, XCTest)
- **Story:** 1-1-spm-package-core-types.md
- **Acceptance Criteria:** 7 ACs (AC1–AC7)
- **Test Framework:** XCTest (Swift built-in, configured via Package.swift)
- **Dev Environment:** Swift 6.2.4 on macOS arm64
- **Knowledge Loaded:** test-quality, test-levels-framework, test-priorities-matrix

## Step 2: Generation Mode

- **Mode:** AI Generation (sequential)
- **Reason:** Backend Swift project — no browser recording needed
- **Source:** Story acceptance criteria + architecture documentation

## Step 3: Test Strategy

### AC → Scenario Mapping

| AC | Scenarios | Level | Priority |
|---|---|---|---|
| AC1 | SPM import compiles | Integration (build) | P0 |
| AC2 | 11 core types accessible | Unit | P0 |
| AC3 | SDKError 8 cases + LocalizedError + Equatable | Unit | P0 |
| AC4 | SDKMessage 5 variants + associated data | Unit | P0 |
| AC5 | PermissionMode 6 cases | Unit | P1 |
| AC6 | AgentOptions defaults | Unit | P1 |
| AC7 | swift build succeeds | Integration (build) | P1 |

## Step 4: Test Generation (RED PHASE)

### Files Generated

| File | AC Coverage | Priority | Tests |
|---|---|---|---|
| `Tests/OpenAgentSDKTests/Core/SDKErrorTests.swift` | AC3 | P0 | 17 |
| `Tests/OpenAgentSDKTests/Core/SDKMessageTests.swift` | AC4 | P0 | 15 |
| `Tests/OpenAgentSDKTests/Core/CoreTypesTests.swift` | AC2, AC5, AC6 | P0/P1 | 25 |
| **Total** | | | **57** |

### TDD Status: RED

All 57 tests are designed to fail. They reference types that do not exist yet:
- `SDKError` — 8 cases with associated values
- `SDKMessage` — 5 variants with nested data types
- `TokenUsage` — struct with Codable + operators
- `PermissionMode` — 6-case enum
- `ThinkingConfig` — 3-case enum
- `AgentOptions` — struct with default values
- `QueryResult`, `ModelInfo`, `MODEL_PRICING`
- `ToolProtocol`, `ToolResult`, `ToolContext`

## Step 5: Validation

- [x] Prerequisites satisfied (Swift 6.2.4, XCTest, Story 1.1)
- [x] Test files created in correct directory structure
- [x] Checklist covers all 7 acceptance criteria (AC1-AC7)
- [x] All tests fail before implementation (compile errors)
- [x] Temp artifacts stored in `_bmad-output/test-artifacts/`
- [x] No orphaned browser processes (N/A — backend)

### Risks & Assumptions

- Test APIs reference architecture doc conventions — property names may differ in implementation
- `SDKMessage.AssistantData`, nested subtypes may be structured differently
- AC7 (dual platform) validated by `swift build`, not unit tests

### Next Steps

1. Implement Story 1.1 to make tests pass (TDD green phase)
2. Run `swift test` to verify all 57 tests pass
3. Refactor if needed (TDD refactor phase)

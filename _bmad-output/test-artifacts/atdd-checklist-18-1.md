---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-18'
inputDocuments:
  - '_bmad-output/implementation-artifacts/18-1-update-compat-core-query.md'
  - 'Examples/CompatCoreQuery/main.swift'
  - 'Tests/OpenAgentSDKTests/Compat/CoreQueryCompatTests.swift'
  - 'Sources/OpenAgentSDK/Types/SDKMessage.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
story_id: '18-1'
communication_language: 'zh'
detected_stack: 'backend'
generation_mode: 'ai-generation'
---

# ATDD Checklist: Story 18-1 Update CompatCoreQuery Example

## Story Summary

Story 18-1 updates `Examples/CompatCoreQuery/main.swift` and `Tests/OpenAgentSDKTests/Compat/CoreQueryCompatTests.swift` to change MISSING entries to PASS for all fields that Epic 17 implemented. This is a pure update story -- no new production code.

**As a** SDK developer
**I want** to update the CompatCoreQuery example and compat tests to reflect Epic 17 features
**So that** the compatibility report accurately shows current Swift SDK vs TS SDK alignment

## Stack Detection

- **Detected stack:** `backend` (Swift Package Manager project, XCTest)
- **Test framework:** XCTest (Swift built-in)
- **Test level:** Unit tests for compat report field mapping verification

## Generation Mode

- **Mode:** AI Generation (backend project, no browser testing needed)

## Acceptance Criteria

1. **AC1:** SystemData fields PASS -- sessionId, tools, model, permissionMode, mcpServers, cwd verified
2. **AC2:** ResultData fields PASS -- structuredOutput, permissionDenials, modelUsage verified; errors remains MISSING
3. **AC3:** AgentOptions fields PASS -- fallbackModel, effort, allowedTools, disallowedTools, streamInput() verified
4. **AC4:** Compat test report updated -- CompatReportTests updates MISSING entries to PASS for resolved fields
5. **AC5:** Build and tests pass -- zero errors, zero warnings, all tests pass

## Test Strategy: Acceptance Criteria to Test Mapping

### AC1: SystemData Fields Verification (6 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | SystemData.sessionId is accessible and populated | Unit | P0 | PASS |
| 2 | SystemData.tools is accessible (type-level) | Unit | P0 | PASS |
| 3 | SystemData.model is accessible and populated | Unit | P0 | PASS |
| 4 | SystemData.permissionMode is accessible (type-level) | Unit | P0 | PASS |
| 5 | SystemData.mcpServers is accessible (type-level) | Unit | P0 | PASS |
| 6 | SystemData.cwd is accessible (type-level) | Unit | P0 | PASS |

### AC2: ResultData Fields Verification (4 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | ResultData.structuredOutput is accessible (type-level) | Unit | P0 | PASS |
| 2 | ResultData.permissionDenials is accessible (type-level) | Unit | P0 | PASS |
| 3 | ResultData.modelUsage is accessible (type-level) | Unit | P0 | PASS |
| 4 | ResultData does NOT have errors field (remains MISSING) | Unit | P0 | PASS |

### AC3: AgentOptions / streamInput Verification (6 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | AgentOptions.fallbackModel field exists | Unit | P0 | PASS |
| 2 | AgentOptions.effort field exists (EffortLevel) | Unit | P0 | PASS |
| 3 | AgentOptions.allowedTools field exists | Unit | P0 | PASS |
| 4 | AgentOptions.disallowedTools field exists | Unit | P0 | PASS |
| 5 | Agent.streamInput() method exists | Unit | P0 | PASS |
| 6 | streamInput returns AsyncStream<SDKMessage> | Unit | P0 | PASS |

### AC4: Compat Report Updated (8 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | session_id must be PASS (currently MISSING) | Unit | P0 | **FAIL (RED)** |
| 2 | tools must be PASS (currently MISSING) | Unit | P0 | **FAIL (RED)** |
| 3 | model (on SystemData) must be PASS (currently MISSING) | Unit | P0 | **FAIL (RED)** |
| 4 | structuredOutput must be PASS (currently MISSING) | Unit | P0 | **FAIL (RED)** |
| 5 | permissionDenials must be PASS (currently MISSING) | Unit | P0 | **FAIL (RED)** |
| 6 | errors must remain MISSING | Unit | P0 | PASS |
| 7 | durationApiMs must remain MISSING | Unit | P0 | PASS |
| 8 | Pass count must be >= 20 | Unit | P0 | PASS (validates expected count) |

### AC5: Build Verification (2 tests)
| # | Test Scenario | Level | Priority | Status |
|---|---|---|---|---|
| 1 | SystemData init compiles with all Epic 17 fields | Unit | P0 | PASS |
| 2 | ResultData init compiles with all Epic 17 fields | Unit | P0 | PASS |

## Failing Tests Created (RED Phase)

### Unit Tests (26 tests total)

**File:** `Tests/OpenAgentSDKTests/Compat/Story18_1_ATDDTests.swift`

**Test Classes:**
- `SystemDataFieldsATDDTests` (6 tests) -- AC1: all PASS (fields exist)
- `ResultDataFieldsATDDTests` (4 tests) -- AC2: all PASS (fields exist + gap confirmed)
- `AgentOptionsStreamInputATDDTests` (6 tests) -- AC3: all PASS (fields exist)
- `CompatReportUpdateATDDTests` (8 tests) -- AC4: **5 FAIL, 3 PASS** (RED phase)
- `Story18_1_BuildVerificationATDDTests` (2 tests) -- AC5: all PASS (compilation check)

**RED Phase Status:** 5 tests fail because:
- `CompatReportTests.testCompatReport_fieldMapping` still marks session_id, tools, model as MISSING
- `CompatReportTests.testCompatReport_fieldMapping` still marks structuredOutput, permissionDenials as MISSING
- The compat report has NOT been updated to add PASS entries for permissionMode, mcpServers, cwd, modelUsage, streamInput
- `Examples/CompatCoreQuery/main.swift` still records MISSING for resolved fields

## Implementation Checklist

### Test: CompatReportUpdateATDDTests (5 failing tests)

**Tasks to make these tests pass:**

- [ ] In `CoreQueryCompatTests.swift` (`CompatReportTests.testCompatReport_fieldMapping`):
  - Change `session_id` from `("session_id", "SystemData.message (embedded)", "MISSING")` to `("session_id", "SystemData.sessionId", "PASS")`
  - Change `tools` from `("tools", "Not exposed on SystemData", "MISSING")` to `("tools", "SystemData.tools ([ToolInfo])", "PASS")`
  - Change `model (on SystemData)` from `("model (on SystemData)", "Not exposed on SystemData", "MISSING")` to `("model (on SystemData)", "SystemData.model", "PASS")`
  - Change `structuredOutput` from `("structuredOutput", "Not available", "MISSING")` to `("structuredOutput", "ResultData.structuredOutput (SendableStructuredOutput?)", "PASS")`
  - Change `permissionDenials` from `("permissionDenials", "Not available", "MISSING")` to `("permissionDenials", "ResultData.permissionDenials ([SDKPermissionDenial]?)", "PASS")`
  - Add PASS entries for: `permissionMode`, `mcpServers`, `cwd` (SystemData), `modelUsage` (ResultData), `AsyncIterable input` (Agent.streamInput)
  - Update passCount assertion from `>= 12` to `>= 20`

- [ ] In `Examples/CompatCoreQuery/main.swift`:
  - Update SystemData verification section (lines 153-158) to use PASS for session_id, tools, model
  - Add PASS records for permissionMode, mcpServers, cwd
  - Update Known Gaps section (lines 369-376) to change structuredOutput, permissionDenials to PASS
  - Add modelUsage as PASS
  - Change AsyncIterable input from MISSING to PASS for streamInput()
  - Keep `errors: [String]` and `durationApiMs` as MISSING

**Estimated Effort:** 1 hour

## Running Tests

```bash
# Run all ATDD tests for this story
swift test --filter "SystemDataFieldsATDD" --filter "ResultDataFieldsATDD" --filter "AgentOptionsStreamInputATDD" --filter "CompatReportUpdateATDD" --filter "Story18_1_BuildVerificationATDD"

# Build only (verify compilation)
swift build --build-tests

# Run full test suite (verify no regression)
swift test
```

## Red-Green-Refactor Workflow

### RED Phase (Complete)

- 26 tests written
- 5 tests FAIL (compat report still marks resolved fields as MISSING)
- 21 tests PASS (type existence verification)
- No test bugs -- all failures are due to outdated compat report entries

### GREEN Phase (DEV Team - Next Steps)

1. Update `CompatReportTests.testCompatReport_fieldMapping` -- change MISSING to PASS for resolved fields, add new PASS entries
2. Update `Examples/CompatCoreQuery/main.swift` -- change MISSING records to PASS for resolved fields
3. Build and verify tests compile
4. Run ATDD tests to confirm GREEN (all 26 pass)

### REFACTOR Phase (After All Tests Pass)

1. Run full test suite (4200+ tests, zero regression)
2. Verify pass count in compat report is >= 20
3. Keep ATDD test file as regression tests

## Key Risks and Assumptions

1. **Risk:** Updating CompatReportTests passCount may break if other stories also modify it
   - **Mitigation:** Use >= 20 assertion, not exact count
2. **Assumption:** All Epic 17 fields are genuinely accessible (confirmed via SDKMessage.swift source)
3. **Note:** errors and durationApiMs must remain MISSING -- they are genuinely not implemented
4. **Note:** This is a pure update story -- zero production code changes, only example/test updates

## Notes

- This is the first story in Epic 18
- All features being verified were implemented by Epic 17 stories (17-1, 17-2, 17-10)
- The ATDD tests serve as a safety net to ensure compat report accurately reflects current SDK state
- No new source files needed -- only modifications to existing example and test files
- The RED phase correctly fails on 5 compat report assertions, not on type-existence checks

---
**Generated by BMad TEA Agent** - 2026-04-18

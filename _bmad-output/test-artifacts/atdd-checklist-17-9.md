---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-17'
storyId: '17-9'
storyTitle: 'Sandbox Config Enhancement'
tddPhase: 'RED'
inputDocuments:
  - '_bmad-output/implementation-artifacts/17-9-sandbox-config-enhancement.md'
  - 'Sources/OpenAgentSDK/Types/SandboxSettings.swift'
  - 'Sources/OpenAgentSDK/Tools/Core/BashTool.swift'
  - 'Sources/OpenAgentSDK/Utils/SandboxChecker.swift'
  - 'Sources/OpenAgentSDK/Types/ToolTypes.swift'
  - 'Tests/OpenAgentSDKTests/Utils/SandboxSettingsTests.swift'
---

# ATDD Checklist: Story 17-9 Sandbox Config Enhancement

## Preflight Summary

- **Story:** 17-9 Sandbox Config Enhancement
- **Stack:** Backend (Swift)
- **Framework:** XCTest
- **Mode:** AI Generation (backend, no browser)
- **TDD Phase:** RED (failing tests before implementation)

## Acceptance Criteria -> Test Mapping

### AC1: SandboxNetworkConfig type (7 fields)

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 1.1 | SandboxNetworkConfig default init has safe defaults | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 1.2 | SandboxNetworkConfig explicit init with all 7 fields | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 1.3 | SandboxNetworkConfig conforms to Sendable | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 1.4 | SandboxNetworkConfig conforms to Equatable | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 1.5 | SandboxNetworkConfig partial config (proxy ports only) | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |
| 1.6 | SandboxNetworkConfig nil proxy ports | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |
| 1.7 | SandboxNetworkConfig has exactly 7 fields | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |

### AC2: SandboxSettings.network field

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 2.1 | SandboxSettings has network field defaulting to nil | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 2.2 | SandboxSettings can set network config | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 2.3 | SandboxSettings.network with full config preserves values | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 2.4 | SandboxSettings equality includes network field | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |
| 2.5 | SandboxSettings equality includes ripgrep field | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |

### AC3: autoAllowBashIfSandboxed field

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 3.1 | SandboxSettings has autoAllowBashIfSandboxed defaulting to false | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 3.2 | SandboxSettings can set autoAllowBashIfSandboxed to true | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |

### AC4: allowUnsandboxedCommands field

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 4.1 | SandboxSettings has allowUnsandboxedCommands defaulting to false | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 4.2 | SandboxSettings can set allowUnsandboxedCommands to true | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |

### AC5: ignoreViolations field

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 5.1 | SandboxSettings has ignoreViolations defaulting to nil | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 5.2 | SandboxSettings can set ignoreViolations with category suppression | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 5.3 | ignoreViolations with multiple categories | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |
| 5.4 | ignoreViolations empty dict vs nil distinction | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |
| 5.5 | ignoreViolations empty array values | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |

### AC6: enableWeakerNestedSandbox field

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 6.1 | SandboxSettings has enableWeakerNestedSandbox defaulting to false | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 6.2 | SandboxSettings can set enableWeakerNestedSandbox to true | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 6.3 | enableWeakerNestedSandbox and allowNestedSandbox are independent | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 6.4 | Both nested sandbox fields have different semantics | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |

### AC7: RipgrepConfig type + ripgrep field

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 7.1 | RipgrepConfig init with command field | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 7.2 | RipgrepConfig init with command and args | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 7.3 | RipgrepConfig conforms to Sendable | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 7.4 | RipgrepConfig conforms to Equatable | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 7.5 | RipgrepConfig empty args vs nil args | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |
| 7.6 | SandboxSettings has ripgrep field defaulting to nil | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 7.7 | SandboxSettings can set ripgrep config | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |

### AC8: SandboxSettings init update

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 8.1 | No-arg init backward compatible (all new fields have defaults) | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 8.2 | Init with all new fields at once | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 8.3 | Init preserves original parameter order | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |
| 8.4 | SandboxSettings has exactly 12 fields (6 existing + 6 new) | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 8.5 | Description includes network when set | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |
| 8.6 | Description includes autoAllowBashIfSandboxed when true | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |
| 8.7 | Description includes ripgrep when set | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |
| 8.8 | Description includes ignoreViolations when set | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |
| 8.9 | Description includes enableWeakerNestedSandbox when true | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |

### AC9: autoAllowBashIfSandboxed behavior

| # | Test Scenario | Level | Priority | Test File | Status |
|---|---|---|---|---|---|
| 9.1 | autoAllowBashIfSandboxed usable as permission bypass signal | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 9.2 | autoAllowBashIfSandboxed does not bypass SandboxChecker | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 9.3 | autoAllowBashIfSandboxed false preserves existing behavior | Unit | P0 | SandboxConfigEnhancementATDDTests.swift | RED |
| 9.4 | ToolContext.sandbox carries autoAllowBashIfSandboxed | Unit | P1 | SandboxConfigEnhancementATDDTests.swift | RED |

## Test File Summary

| File | Tests | Classes |
|---|---|---|
| SandboxConfigEnhancementATDDTests.swift | 45 | 8 |
| **Total** | **45** | **8** |

## TDD Red Phase Status

- **45 tests FAIL** (RED -- new types and fields not yet implemented)
- All failures are EXPECTED (TDD red phase)
- **4055+ baseline tests** (from 17-8 completion)
- **0 regressions** expected in existing tests
- **swift build** passes (production code unaffected)
- **swift build --build-tests** fails (test code references unimplemented types)

### RED Tests (45 failures, all expected)

1. `testSandboxNetworkConfig_defaultInit_hasSafeDefaults` - SandboxNetworkConfig type does not exist
2. `testSandboxNetworkConfig_explicitInit_allFieldsSet` - SandboxNetworkConfig type does not exist
3. `testSandboxNetworkConfig_conformsToSendable` - SandboxNetworkConfig type does not exist
4. `testSandboxNetworkConfig_conformsToEquatable` - SandboxNetworkConfig type does not exist
5. `testSandboxNetworkConfig_partialConfig_proxyPortsOnly` - SandboxNetworkConfig type does not exist
6. `testSandboxNetworkConfig_nilProxyPorts` - SandboxNetworkConfig type does not exist
7. `testSandboxNetworkConfig_hasSevenFields` - SandboxNetworkConfig type does not exist
8. `testRipgrepConfig_initWithCommand` - RipgrepConfig type does not exist
9. `testRipgrepConfig_initWithCommandAndArgs` - RipgrepConfig type does not exist
10. `testRipgrepConfig_conformsToSendable` - RipgrepConfig type does not exist
11. `testRipgrepConfig_conformsToEquatable` - RipgrepConfig type does not exist
12. `testRipgrepConfig_emptyArgs_vsNilArgs` - RipgrepConfig type does not exist
13. `testSandboxSettings_hasNetworkField_defaultNil` - SandboxSettings.network field does not exist
14. `testSandboxSettings_canSetNetworkConfig` - SandboxSettings.network field does not exist
15. `testSandboxSettings_hasAutoAllowBashIfSandboxed_defaultFalse` - SandboxSettings.autoAllowBashIfSandboxed field does not exist
16. `testSandboxSettings_canSetAutoAllowBashIfSandboxed` - SandboxSettings.autoAllowBashIfSandboxed field does not exist
17. `testSandboxSettings_hasAllowUnsandboxedCommands_defaultFalse` - SandboxSettings.allowUnsandboxedCommands field does not exist
18. `testSandboxSettings_canSetAllowUnsandboxedCommands` - SandboxSettings.allowUnsandboxedCommands field does not exist
19. `testSandboxSettings_hasIgnoreViolations_defaultNil` - SandboxSettings.ignoreViolations field does not exist
20. `testSandboxSettings_canSetIgnoreViolations` - SandboxSettings.ignoreViolations field does not exist
21. `testSandboxSettings_hasEnableWeakerNestedSandbox_defaultFalse` - SandboxSettings.enableWeakerNestedSandbox field does not exist
22. `testSandboxSettings_canSetEnableWeakerNestedSandbox` - SandboxSettings.enableWeakerNestedSandbox field does not exist
23. `testSandboxSettings_hasRipgrepField_defaultNil` - SandboxSettings.ripgrep field does not exist
24. `testSandboxSettings_canSetRipgrepConfig` - SandboxSettings.ripgrep field does not exist
25. `testSandboxSettings_noArgInit_backwardCompatible` - New fields not in SandboxSettings
26. `testSandboxSettings_initWithAllNewFields` - New fields not in SandboxSettings
27. `testSandboxSettings_initParameterOrder_preserved` - New init params not added yet
28. `testSandboxSettings_hasTwelveFields` - 6 new fields not yet added
29. `testSandboxSettings_description_includesNetwork` - Description not updated
30. `testSandboxSettings_description_includesAutoAllowBashIfSandboxed` - Description not updated
31. `testSandboxSettings_description_includesRipgrep` - Description not updated
32. `testSandboxSettings_description_includesIgnoreViolations` - Description not updated
33. `testSandboxSettings_description_includesEnableWeakerNestedSandbox` - Description not updated
34. `testNestedSandboxFields_areIndependent` - enableWeakerNestedSandbox field does not exist
35. `testNestedSandboxFields_differentSemantics` - enableWeakerNestedSandbox field does not exist
36. `testAutoAllowBashIfSandboxed_canBeUsedAsPermissionBypassSignal` - autoAllowBashIfSandboxed field does not exist
37. `testAutoAllowBashIfSandboxed_doesNotBypassSandboxChecker` - autoAllowBashIfSandboxed field does not exist
38. `testAutoAllowBashIfSandboxed_false_preservesExistingBehavior` - autoAllowBashIfSandboxed field does not exist
39. `testToolContext_sandboxWithAutoAllow_signalsPermissionBypass` - autoAllowBashIfSandboxed field does not exist
40. `testIgnoreViolations_multipleCategories` - ignoreViolations field does not exist
41. `testIgnoreViolations_emptyDict_vsNil` - ignoreViolations field does not exist
42. `testIgnoreViolations_emptyArrayValues` - ignoreViolations field does not exist
43. `testSandboxSettings_network_fullConfiguration` - SandboxSettings.network field does not exist
44. `testSandboxSettings_equality_includesNetwork` - SandboxSettings.network field does not exist
45. `testSandboxSettings_equality_includesRipgrep` - SandboxSettings.ripgrep field does not exist

## Implementation Checklist

### AC1: SandboxNetworkConfig type (Tests 1.1-1.7)

**File:** `Sources/OpenAgentSDK/Types/SandboxSettings.swift`

**Tasks to make these tests pass:**

- [ ] Add `SandboxNetworkConfig` struct with 7 fields: allowedDomains, allowManagedDomainsOnly, allowLocalBinding, allowUnixSockets, allowAllUnixSockets, httpProxyPort, socksProxyPort
- [ ] All fields have default values (empty arrays, false, nil)
- [ ] Struct conforms to Sendable, Equatable
- [ ] Add DocC documentation

### AC7: RipgrepConfig type (Tests 7.1-7.5)

**File:** `Sources/OpenAgentSDK/Types/SandboxSettings.swift`

**Tasks to make these tests pass:**

- [ ] Add `RipgrepConfig` struct with command: String and args: [String]? fields
- [ ] args defaults to nil
- [ ] Struct conforms to Sendable, Equatable
- [ ] Add DocC documentation

### AC2-AC6, AC8: SandboxSettings new fields (Tests 2.1-8.9)

**File:** `Sources/OpenAgentSDK/Types/SandboxSettings.swift`

**Tasks to make these tests pass:**

- [ ] Add `autoAllowBashIfSandboxed: Bool` (default false) to SandboxSettings
- [ ] Add `allowUnsandboxedCommands: Bool` (default false) to SandboxSettings
- [ ] Add `ignoreViolations: [String: [String]]?` (default nil) to SandboxSettings
- [ ] Add `enableWeakerNestedSandbox: Bool` (default false) to SandboxSettings
- [ ] Add `network: SandboxNetworkConfig?` (default nil) to SandboxSettings
- [ ] Add `ripgrep: RipgrepConfig?` (default nil) to SandboxSettings
- [ ] Update `init()` with new parameters (all with defaults, backward-compatible)
- [ ] Update `description` computed property to include new fields
- [ ] Verify existing call sites compile without changes (all new params have defaults)
- [ ] Do NOT remove `allowNestedSandbox` -- it has different semantics from `enableWeakerNestedSandbox`

### AC9: autoAllowBashIfSandboxed behavior (Tests 9.1-9.4)

**File:** `Sources/OpenAgentSDK/Tools/Core/BashTool.swift`

**Tasks to make these tests pass:**

- [ ] In BashTool, add logic: if `context.sandbox?.autoAllowBashIfSandboxed == true`, skip canUseTool check
- [ ] SandboxChecker.checkCommand() still enforces command restrictions
- [ ] Preserve existing behavior when field is false (default)

### AC10: Build and Test

- [ ] `swift build` zero errors zero warnings
- [ ] All 4055+ existing tests pass
- [ ] All 45 new ATDD tests pass
- [ ] Zero regressions

## Running Tests

```bash
# Build only (check compilation of production code)
swift build

# Check test compilation (will fail in RED phase)
swift build --build-tests

# Run specific test classes (after implementation)
swift test --filter SandboxNetworkConfigATDDTests
swift test --filter RipgrepConfigATDDTests
swift test --filter SandboxSettingsNewFieldsATDDTests
swift test --filter SandboxSettingsDescriptionATDDTests
swift test --filter SandboxNestedSandboxDistinctionATDDTests
swift test --filter AutoAllowBashIfSandboxedATDDTests
swift test --filter IgnoreViolationsATDDTests
swift test --filter SandboxNetworkIntegrationATDDTests

# Run all ATDD tests for this story
swift test --filter SandboxConfigEnhancementATDD

# Run full test suite
swift test
```

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**Tests written:** 45 failing tests across 8 test classes
**Files created:** `Tests/OpenAgentSDKTests/Utils/SandboxConfigEnhancementATDDTests.swift`
**Checklist saved:** `_bmad-output/test-artifacts/atdd-checklist-17-9.md`

### GREEN Phase (DEV Team - Next Steps)

1. Start with AC1 types (SandboxNetworkConfig) -- pure type, no wiring
2. Then AC7 (RipgrepConfig) -- pure type, no wiring
3. Then AC2-AC6, AC8 (add 6 fields to SandboxSettings, update init and description) -- extend existing struct
4. Then AC9 (wire autoAllowBashIfSandboxed into BashTool) -- behavior change
5. Update CompatSandbox example from MISSING to PASS
6. Run full test suite (4055+ baseline + 45 new tests)

### Compat Test Updates (Task 6 in story)

**File:** `Examples/CompatSandbox/main.swift`

**Tasks to update gap assertions:**

- [ ] Update SandboxNetworkConfig entries from MISSING to PASS (7 fields)
- [ ] Update autoAllowBashIfSandboxed from MISSING to PASS
- [ ] Update allowUnsandboxedCommands from MISSING to PASS
- [ ] Update ignoreViolations from MISSING to PASS
- [ ] Update enableWeakerNestedSandbox from PARTIAL to PASS
- [ ] Update ripgrep from MISSING to PASS
- [ ] Verify report summary reflects improvements

## Notes

- New types go in `Sources/OpenAgentSDK/Types/SandboxSettings.swift` (same file as existing SandboxSettings)
- No new source files needed
- No Package.swift changes needed
- allowNestedSandbox (existing) and enableWeakerNestedSandbox (new) must coexist -- different semantics
- ignoreViolations is stored but enforcement in SandboxChecker is out of scope for this story
- allowUnsandboxedCommands is declarative (stores config intent, runtime escape hatch is future work)
- Per CLAUDE.md: no mock-based E2E tests

---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
inputDocuments:
  - _bmad-output/implementation-artifacts/1-4-agent-creation-config.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/architecture.md
  - Sources/OpenAgentSDK/Types/AgentTypes.swift
  - Sources/OpenAgentSDK/Types/SDKConfiguration.swift
  - Sources/OpenAgentSDK/API/AnthropicClient.swift
  - Sources/OpenAgentSDK/Types/ErrorTypes.swift
  - Tests/OpenAgentSDKTests/Utils/SDKConfigurationTests.swift
  - Tests/OpenAgentSDKTests/API/AnthropicClientTests.swift
storyId: '1-4'
date: '2026-04-04'
lastStep: 'step-04c-aggregate'
lastSaved: '2026-04-04'
---

# ATDD Checklist: Story 1.4 — Agent Creation and Configuration

## TDD Red Phase (Current)

- [x] Failing tests generated
- [x] All tests assert EXPECTED behavior (not placeholders)
- [x] Test file created: `Tests/OpenAgentSDKTests/Core/AgentCreationTests.swift`

## Test Summary

| Category | Test Count | Status |
|----------|-----------|--------|
| Unit Tests | 23 | RED (will fail until feature implemented) |
| **Total** | **23** | **RED** |

## Acceptance Criteria Coverage

### AC1: createAgent Factory Function (FR1) — 5 tests [P0]

| Test | Priority | Status |
|------|----------|--------|
| `testCreateAgentWithValidOptionsReturnsAgent` | P0 | RED |
| `testCreateAgentHasSpecifiedModel` | P0 | RED |
| `testCreateAgentHasSpecifiedSystemPrompt` | P0 | RED |
| `testCreateAgentHasSpecifiedMaxTurns` | P0 | RED |
| `testCreateAgentHasSpecifiedMaxTokens` | P0 | RED |

### AC2: Default Values Applied — 4 tests [P0]

| Test | Priority | Status |
|------|----------|--------|
| `testDefaultModelIsClaudeSonnet` | P0 | RED |
| `testDefaultMaxTurns` | P0 | RED |
| `testDefaultMaxTokens` | P0 | RED |
| `testDefaultSystemPromptIsNil` | P0 | RED |

### AC3: System Prompt Integration — 3 tests [P1]

| Test | Priority | Status |
|------|----------|--------|
| `testAgentStoresCustomSystemPrompt` | P1 | RED |
| `testAgentWithNilSystemPrompt` | P1 | RED |
| `testAgentWithEmptySystemPrompt` | P1 | RED |

### AC4: AnthropicClient Integration (AD3, FR41) — 3 tests [P0]

| Test | Priority | Status |
|------|----------|--------|
| `testAgentCreatedWithAPIKey` | P0 | RED |
| `testAgentCreatedWithCustomBaseURL` | P0 | RED |
| `testAgentCreatedWithoutAPIKey` | P0 | RED |

### AC5: SDKConfiguration Merge (FR39 + FR40) — 3 tests [P1]

| Test | Priority | Status |
|------|----------|--------|
| `testCreateAgentWithNilOptionsUsesResolvedConfig` | P1 | RED |
| `testExplicitOptionsOverrideConfig` | P1 | RED |
| `testAgentFromSDKConfigurationCarriesValues` | P1 | RED |

### AC6: Agent Public API (NFR6) — 5 tests [P0]

| Test | Priority | Status |
|------|----------|--------|
| `testAgentExposesReadOnlyModelProperty` | P0 | RED |
| `testAgentExposesReadOnlySystemPromptProperty` | P0 | RED |
| `testAgentDoesNotExposeAPIKeyDirectly` | P0 | RED |
| `testAgentDescriptionDoesNotLeakAPIKey` | P0 | RED |
| `testAgentIsClassNotActor` | P0 | RED |

## Priority Coverage

| Priority | Count | Percentage |
|----------|-------|------------|
| P0 | 17 | 74% |
| P1 | 6 | 26% |
| P2 | 0 | 0% |
| P3 | 0 | 0% |

## Test Strategy

- **Stack**: Backend (Swift SPM library)
- **Framework**: XCTest
- **Test Level**: Unit tests (Agent class is a unit under test)
- **Mock Strategy**: No mocks needed — Agent stores immutable configuration and creates AnthropicClient internally. Tests verify public API surface and configuration propagation.

## Implementation Guidance

### Files to Create

1. `Sources/OpenAgentSDK/Core/Agent.swift` — Agent class + createAgent() factory function

### Expected Agent Public API

```swift
public class Agent {
    public let model: String
    public let systemPrompt: String?
    public let maxTurns: Int
    public let maxTokens: Int

    let options: AgentOptions
    let client: AnthropicClient

    public init(options: AgentOptions)
}

public func createAgent(options: AgentOptions? = nil) -> Agent
```

### Key Design Decisions

- Agent is a **class** (not actor) — holds immutable configuration
- `createAgent(options: nil)` falls back to `SDKConfiguration.resolved()`
- API key NOT exposed as public property (NFR6)
- AnthropicClient created internally in init

### Files to Update

1. `Sources/OpenAgentSDK/OpenAgentSDK.swift` — Add Agent and createAgent to module exports

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Create `Sources/OpenAgentSDK/Core/Agent.swift` with the Agent class
2. Implement `createAgent()` factory function
3. Update `OpenAgentSDK.swift` for module exports
4. Run `swift test` — verify tests PASS (green phase)
5. If any tests fail: fix implementation or test as needed
6. Commit passing tests

## Knowledge Fragments Used

- test-quality.md (deterministic tests, explicit assertions, < 300 lines)
- data-factories.md (factory patterns for test data)
- test-healing-patterns.md (failure pattern awareness)

## Environment Note

The XCTest module is not available in the current CLI-only toolchain environment (xcodebuild not configured). Tests will compile and run correctly once Xcode developer tools are properly configured. This is an environment setup issue, not a test design issue. The TDD red phase is confirmed by the fact that `Agent`, `createAgent`, and their properties do not exist in the codebase.

---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
lastStep: step-04-generate-tests
lastSaved: '2026-04-10'
storyId: '10-1'
storyTitle: 'Multi-Tool Orchestration Example (MultiToolExample)'
inputDocuments:
  - _bmad-output/implementation-artifacts/10-1-multi-tool-example.md
  - _bmad-output/planning-artifacts/epics.md
  - Sources/OpenAgentSDK/Tools/ToolRegistry.swift
  - Sources/OpenAgentSDK/Types/SDKMessage.swift
  - Sources/OpenAgentSDK/Core/Agent.swift
  - Examples/StreamingAgent/main.swift
  - Examples/BasicAgent/main.swift
  - Tests/OpenAgentSDKTests/Documentation/ExamplesComplianceTests.swift
  - Package.swift
---

# ATDD Checklist — Story 10-1: MultiToolExample

## Story Summary

Create `Examples/MultiToolExample/main.swift` demonstrating Agent multi-tool orchestration using Glob, Bash, Read via streaming API with real-time event display.

## Stack Detection

- **Detected Stack:** `backend` (Swift SPM project, no frontend/browser components)
- **Test Framework:** XCTest
- **Test Directory:** `Tests/OpenAgentSDKTests/`

## Generation Mode

- **Mode:** AI Generation (backend project, no browser recording needed)
- **Reason:** Acceptance criteria are clear; scenarios are standard code example validation

## Test Strategy — Acceptance Criteria Mapping

| AC # | Description | Test Level | Priority | Test Scenarios |
|------|-------------|-----------|----------|----------------|
| AC1  | MultiToolExample compiles and runs | Unit (file + Package.swift analysis) | P0 | Directory exists, main.swift exists, uses correct APIs |
| AC2  | Uses streaming API for real-time events | Unit (code analysis) | P0 | Uses agent.stream(), for await, SDKMessage pattern matching |
| AC3  | Demonstrates multi-tool orchestration | Unit (code analysis) | P0 | Uses getAllBaseTools(tier: .core), system prompt guides multi-step task |
| AC4  | Final output includes task summary and statistics | Unit (code analysis) | P1 | Handles .result event, shows usage/cost/duration |
| AC5  | Package.swift executableTarget configured | Unit (file analysis) | P0 | Package.swift contains MultiToolExample target |
| AC6  | Uses actual public API signatures | Unit (code analysis) | P0 | All API calls match source code signatures |
| AC7  | Clear comments, no exposed keys | Unit (code analysis) | P1 | Top-level description, inline comments, placeholder API key |

## Test File

- **File:** `Tests/OpenAgentSDKTests/Documentation/MultiToolExampleComplianceTests.swift`
- **Class:** `MultiToolExampleComplianceTests`
- **Total Tests:** 18

## TDD Red Phase Status

All tests are designed to FAIL until the MultiToolExample feature is implemented:
- MultiToolExample directory and main.swift do not exist yet
- Package.swift does not contain MultiToolExample target yet

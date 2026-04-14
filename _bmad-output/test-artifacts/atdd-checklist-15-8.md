---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests', 'step-04c-aggregate', 'step-05-validate-and-complete']
lastStep: 'step-05-validate-and-complete'
lastSaved: '2026-04-14'
workflowType: 'testarch-atdd'
inputDocuments:
  - '_bmad-output/implementation-artifacts/15-8-openai-compat-example.md'
  - 'Sources/OpenAgentSDK/API/OpenAIClient.swift'
  - 'Sources/OpenAgentSDK/Types/AgentTypes.swift'
  - 'Sources/OpenAgentSDK/Core/Agent.swift'
  - 'Tests/OpenAgentSDKTests/Documentation/MultiTurnExampleComplianceTests.swift'
---

# ATDD Checklist - Epic 15, Story 8: OpenAICompatExample

**Date:** 2026-04-14
**Author:** TEA Agent (yolo mode)
**Primary Test Level:** Unit / Static Analysis (Swift backend project, example compliance tests)

---

## Story Summary

Create a runnable OpenAICompatExample program that demonstrates how to use the OpenAI-compatible API provider with the SDK. Shows provider configuration (side-by-side Anthropic vs OpenAI), prompt() with OpenAI provider, streaming via stream() with OpenAI provider, and tool use through the OpenAI provider. This is an example/documentation story, not a new feature.

**As a** developer
**I want** a runnable example demonstrating how to use the OpenAI-compatible API provider with the SDK
**So that** I can use non-Anthropic backends (DeepSeek, Qwen, vLLM, Ollama, GLM, etc.) with the same Agent API

---

## Acceptance Criteria

1. **AC1:** Example compiles and runs -- directory exists with main.swift, no build errors
2. **AC2:** OpenAI provider configuration -- demonstrates creating Agent with `provider: .openai` and `baseURL`, uses CODEANY_API_KEY/CODEANY_BASE_URL/CODEANY_MODEL env vars
3. **AC3:** Prompt with OpenAI provider -- demonstrates `agent.prompt()` using OpenAI-compatible provider, prints response text and usage stats
4. **AC4:** Streaming with OpenAI provider -- demonstrates `agent.stream()` with OpenAI-compatible provider, collects SDKMessage events (partialMessage, result), prints streamed text and usage stats
5. **AC5:** Tool use with OpenAI provider -- demonstrates registering custom tool via `defineTool()` with Codable input, having Agent call it through OpenAI-compatible provider
6. **AC6:** Provider comparison -- demonstrates side-by-side AgentOptions configuration for Anthropic vs OpenAI providers
7. **AC7:** Package.swift updated with OpenAICompatExample executableTarget following existing pattern

---

## Failing Tests Created (RED Phase)

### Compliance Tests - OpenAICompatExampleComplianceTests (39 tests, 42 assertions)

**File:** `Tests/OpenAgentSDKTests/Documentation/OpenAICompatExampleComplianceTests.swift`

| # | Test Name | AC | Priority | Status | Expected Failure |
|---|-----------|-----|----------|--------|------------------|
| 1 | testPackageSwiftContainsOpenAICompatExampleTarget | AC7 | P0 | RED | Package.swift missing OpenAICompatExample target |
| 2 | testOpenAICompatExampleTargetDependsOnOpenAgentSDK | AC7 | P0 | RED | Package.swift missing dependency |
| 3 | testOpenAICompatExampleTargetSpecifiesCorrectPath | AC7 | P0 | RED | Package.swift missing path |
| 4 | testOpenAICompatExampleDirectoryExists | AC1 | P0 | RED | Examples/OpenAICompatExample/ does not exist |
| 5 | testOpenAICompatExampleMainSwiftExists | AC1 | P0 | RED | main.swift does not exist |
| 6 | testOpenAICompatExampleImportsOpenAgentSDK | AC1 | P0 | RED | File not found |
| 7 | testOpenAICompatExampleImportsFoundation | AC1 | P0 | RED | File not found |
| 8 | testOpenAICompatExampleHasTopLevelDescriptionComment | AC1 | P1 | RED | File not found |
| 9 | testOpenAICompatExampleHasMultipleInlineComments | AC1 | P1 | RED | File not found |
| 10 | testOpenAICompatExampleHasMarkSections | AC1 | P1 | RED | File not found |
| 11 | testOpenAICompatExampleDoesNotUseForceUnwrap | AC1 | P0 | RED | File not found |
| 12 | testOpenAICompatExampleDoesNotExposeRealAPIKeys | AC1 | P0 | RED | File not found |
| 13 | testOpenAICompatExampleUsesLoadDotEnvPattern | AC1 | P1 | RED | File not found |
| 14 | testOpenAICompatExampleUsesGetEnvPattern | AC1 | P1 | RED | File not found |
| 15 | testOpenAICompatExampleUsesAssertions | AC1 | P0 | RED | File not found |
| 16 | testOpenAICompatExampleUsesOpenAIProvider | AC2 | P0 | RED | File not found |
| 17 | testOpenAICompatExampleConfiguresBaseURL | AC2 | P0 | RED | File not found |
| 18 | testOpenAICompatExampleUsesCodeAnyEnvVars | AC2 | P0 | RED | File not found |
| 19 | testOpenAICompatExampleDetectsUseOpenAIFlag | AC2 | P0 | RED | File not found |
| 20 | testOpenAICompatExampleUsesCreateAgent | AC3 | P0 | RED | File not found |
| 21 | testOpenAICompatExampleUsesBypassPermissions | AC3 | P0 | RED | File not found |
| 22 | testOpenAICompatExampleUsesPrompt | AC3 | P0 | RED | File not found |
| 23 | testOpenAICompatExampleUsesAwait | AC3 | P0 | RED | File not found |
| 24 | testOpenAICompatExamplePrintsResponseText | AC3 | P0 | RED | File not found |
| 25 | testOpenAICompatExamplePrintsUsageStats | AC3 | P0 | RED | File not found |
| 26 | testOpenAICompatExampleUsesStream | AC4 | P0 | RED | File not found |
| 27 | testOpenAICompatExampleCollectsSDKMessageEvents | AC4 | P0 | RED | File not found |
| 28 | testOpenAICompatExampleHandlesPartialMessage | AC4 | P0 | RED | File not found |
| 29 | testOpenAICompatExampleHandlesResultCase | AC4 | P0 | RED | File not found |
| 30 | testOpenAICompatExampleAssertsStreamingResponseNonEmpty | AC4 | P0 | RED | File not found |
| 31 | testOpenAICompatExampleUsesDefineTool | AC5 | P0 | RED | File not found |
| 32 | testOpenAICompatExampleDefinesCodableInputStruct | AC5 | P0 | RED | File not found |
| 33 | testOpenAICompatExampleDefinesInputSchema | AC5 | P0 | RED | File not found |
| 34 | testOpenAICompatExampleCreatesAgentWithTools | AC5 | P0 | RED | File not found |
| 35 | testOpenAICompatExampleTriggersToolCall | AC5 | P0 | RED | File not found |
| 36 | testOpenAICompatExampleShowsAnthropicProviderConfig | AC6 | P0 | RED | File not found |
| 37 | testOpenAICompatExampleShowsBothProviderOptions | AC6 | P0 | RED | File not found |
| 38 | testOpenAICompatExampleHasFourParts | AC1 | P1 | RED | File not found |
| 39 | testOpenAICompatExampleUsesAgentOptions | AC3 | P0 | RED | File not found |

**Note:** 39 test methods produce 42 assertion failures because some tests contain multiple assertions (testOpenAICompatExampleTargetDependsOnOpenAgentSDK, testOpenAICompatExampleUsesCodeAnyEnvVars, testOpenAICompatExamplePrintsUsageStats, testOpenAICompatExampleCollectsSDKMessageEvents).

---

## Test Strategy

### Test Level Selection

This is a **Swift backend project** (SPM with XCTest). The OpenAICompatExample is a documentation/example artifact, not a runtime feature. Test levels:
- **Compliance / static analysis tests** for all ACs -- verify file existence, code content, API usage patterns
- **No E2E tests** (no real LLM calls needed; compliance tests only check source code)
- **No unit tests for new logic** (no new SDK types introduced in this story)

### Approach

1. Tests verify that `Examples/OpenAICompatExample/main.swift` exists and contains correct content
2. Content-based assertions check for specific API names (.openai, .anthropic, baseURL:, provider:, defineTool, .prompt(), .stream(), SDKMessage, .partialMessage, .result, tools:, inputSchema:, etc.)
3. Package.swift assertions verify executableTarget configuration
4. Code quality checks (no force unwrap, no hardcoded API keys, comments, MARK sections)
5. Pattern matching ensures example demonstrates all 4 parts (Config Comparison, Prompt, Streaming, Tool Use)
6. Tests follow the same compliance-test pattern as MultiTurnExampleComplianceTests

### Priority Framework

| Priority | Count | Rationale |
|----------|-------|-----------|
| P0 | 35 | Core ACs: file existence, API usage, key demonstrations |
| P1 | 4 | Supporting: comments, MARK sections, conventions, loadDotEnv/getEnv |

### Coverage Matrix

| AC | Tests | Levels |
|----|-------|--------|
| AC1 (Directory/file existence, compiles) | 15 | Compliance (file exists, imports, comments, quality, assertions, 4 parts, MARK) |
| AC2 (OpenAI provider configuration) | 4 | Compliance (.openai, baseURL, env vars, useOpenAI flag) |
| AC3 (Prompt with OpenAI provider) | 6 | Compliance (createAgent, bypassPermissions, prompt, await, response text, usage stats) |
| AC4 (Streaming with OpenAI provider) | 5 | Compliance (stream, SDKMessage events, partialMessage, result, assert non-empty) |
| AC5 (Tool use with OpenAI provider) | 5 | Compliance (defineTool, Codable struct, inputSchema, tools param, tool call output) |
| AC6 (Provider comparison) | 2 | Compliance (.anthropic config, both providers side-by-side) |
| AC7 (Package.swift target) | 3 | Compliance (target, dependency, path) |

---

## Implementation Checklist

### Task 1: Add OpenAICompatExample executableTarget to Package.swift (AC: #7)

**File:** `Package.swift` (MODIFY)

**Tests this makes pass:**
- testPackageSwiftContainsOpenAICompatExampleTarget
- testOpenAICompatExampleTargetDependsOnOpenAgentSDK
- testOpenAICompatExampleTargetSpecifiesCorrectPath

**Implementation steps:**
- [ ] Add `.executableTarget(name: "OpenAICompatExample", dependencies: ["OpenAgentSDK"], path: "Examples/OpenAICompatExample")` to targets array after MultiTurnExample

### Task 2: Create Examples/OpenAICompatExample/main.swift (AC: #1-#6)

**File:** `Examples/OpenAICompatExample/main.swift` (NEW)

**Tests this makes pass:** All 39 compliance tests

**Implementation steps:**
- [ ] Create directory `Examples/OpenAICompatExample/`
- [ ] Create `main.swift` with Chinese + English header comment block
- [ ] Part 1: Provider Configuration Comparison
  - [ ] Use `loadDotEnv()` and `getEnv()` to load CODEANY_API_KEY, CODEANY_BASE_URL, CODEANY_MODEL
  - [ ] Set `useOpenAI` flag when CODEANY_API_KEY is present
  - [ ] Show both Anthropic and OpenAI AgentOptions side-by-side
  - [ ] Print current provider and base URL being used
- [ ] Part 2: Prompt with OpenAI Provider
  - [ ] Create Agent with `provider: .openai`, `baseURL:`, `permissionMode: .bypassPermissions`
  - [ ] Execute `agent.prompt()` with a simple query (e.g., "What is 2 + 2? Answer with just the number.")
  - [ ] Print response text, input/output tokens
  - [ ] Assert response is non-empty
- [ ] Part 3: Streaming with OpenAI Provider
  - [ ] Use `agent.stream()` for a streaming query (e.g., "Count from 1 to 5, one number per line.")
  - [ ] Collect `SDKMessage` events: `.partialMessage` for text deltas, `.result` for final stats
  - [ ] Print streamed text and usage stats
  - [ ] Assert streamed text is non-empty
- [ ] Part 4: Tool Use with OpenAI Provider
  - [ ] Define a simple Codable struct for tool input
  - [ ] Register tool via `defineTool()` with `inputSchema:`
  - [ ] Create Agent with OpenAI provider + custom tool
  - [ ] Prompt that triggers tool use
  - [ ] Print tool call details and final response
  - [ ] Assert tool was used and response contains output
- [ ] Use `loadDotEnv()` and `getEnv()` patterns for API key
- [ ] Add MARK section comments for each part
- [ ] Add inline comments explaining each concept
- [ ] Ensure no force unwraps
- [ ] Ensure no real API keys hardcoded

### Task 3: Verify build and full test suite

- [ ] `swift build` compiles with no errors (including OpenAICompatExample target)
- [ ] `swift test` all pass, no regressions

---

## Running Tests

```bash
# Run all tests for this story (will fail until implementation)
swift test --filter "OpenAICompatExampleComplianceTests"

# Build only (quick compilation check)
swift build --build-tests

# Run full test suite (verify no regressions)
swift test
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**
- 39 compliance tests written in 1 test file, all failing because the example file does not exist yet
- Tests cover all 7 acceptance criteria
- Tests use same helper pattern as MultiTurnExampleComplianceTests (projectRoot, fileContent)
- Tests verify both structural (file exists, Package.swift) and content (API usage, patterns)

**Verification:**
- Tests do NOT pass (OpenAICompatExample directory doesn't exist -- expected for RED phase)
- Failures are clean: "Examples/OpenAICompatExample/ directory should exist"
- No crashes or unexpected behavior
- 39 tests produce 42 assertion failures (some tests have 2 assertions)

---

### GREEN Phase (DEV Team - Next Steps)

**DEV Agent Responsibilities:**

1. **Start with Task 1** (Package.swift update) -- makes 3 tests pass
2. **Then Task 2** (Create OpenAICompatExample/main.swift) -- makes remaining 36 tests pass
3. **Finally Task 3** -- verify full suite passes

**Key Principles:**
- Follow the MultiTurnExample pattern for structure (Chinese + English header, MARK sections, 4-part layout)
- Use `provider: .openai` and `baseURL:` in AgentOptions for the OpenAI-compatible provider
- The `useOpenAI` flag pattern: `let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil`
- When `useOpenAI` is true, set provider to `.openai` and use CODEANY_BASE_URL
- When `useOpenAI` is false, set provider to `.anthropic` (fallback)
- Use `.openai` provider for Parts 2-4; show `.anthropic` config in Part 1 only
- Use `assert()` for key validations to support compliance test verification
- Keep prompts short and simple to minimize cost/latency
- Tool use with OpenAI provider is critical to demonstrate format translation works

---

### REFACTOR Phase (DEV Team - After All Tests Pass)

1. Run full test suite -- all tests pass
2. Review code quality (readability, consistency with existing examples)
3. Ensure the example runs correctly: `swift run OpenAICompatExample`
4. Verify the example gracefully handles missing API key

---

## Key Risks and Assumptions

1. **Assumption: LLMProvider.openai and OpenAIClient are stable and public** -- implemented in earlier epics
2. **Assumption: OpenAI-compatible endpoints support chat/completions** -- the client appends `/chat/completions` to baseURL
3. **Assumption: Tool use format translation works** -- OpenAIClient handles tool_use/tool_result conversion between Anthropic and OpenAI formats
4. **Risk: API key availability** -- Parts 2-4 require API calls. The example should use the loadDotEnv/getEnv fallback pattern.
5. **Risk: Streaming SSE conversion** -- OpenAI SSE chunks need to be parsed and converted to Anthropic-format SSEEvents. The OpenAIClient handles this.
6. **Risk: Tool use with non-Anthropic backends** -- Not all OpenAI-compatible backends support function calling equally. The example should use a simple tool.
7. **Assumption: Same loadDotEnv/getEnv pattern as other examples** -- All Epic 15 examples use this pattern for API key management.

---

**Generated by BMad TEA Agent** - 2026-04-14

# Story 15.8: OpenAICompatExample

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want a runnable example demonstrating how to use the OpenAI-compatible API provider with the SDK,
so that I can use non-Anthropic backends (DeepSeek, Qwen, vLLM, Ollama, GLM, etc.) with the same Agent API.

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/OpenAICompatExample/` directory with a `main.swift` file and corresponding `OpenAICompatExample` executable target in Package.swift, when running `swift build`, then it compiles with no errors and no warnings.

2. **AC2: OpenAI provider configuration** -- Given the example code, when reading the code, it demonstrates creating an Agent with `provider: .openai` and a `baseURL` pointing to an OpenAI-compatible endpoint (e.g., `https://open.bigmodel.cn/api/coding/paas/v4`). The example uses `CODEANY_API_KEY`, `CODEANY_BASE_URL`, and `CODEANY_MODEL` environment variables for configuration.

3. **AC3: Prompt with OpenAI provider** -- Given the example code, when reading the code, it demonstrates sending a prompt via `agent.prompt()` using the OpenAI-compatible provider, printing the response text and usage stats. The response shows successful communication with the non-Anthropic backend.

4. **AC4: Streaming with OpenAI provider** -- Given the example code, when reading the code, it demonstrates using `agent.stream()` with the OpenAI-compatible provider, collecting `SDKMessage` events (partialMessage, result), and printing streamed text and usage stats. This verifies the SSE stream conversion works correctly.

5. **AC5: Tool use with OpenAI provider** -- Given the example code, when reading the code, it demonstrates registering a custom tool (e.g., `defineTool()` with a simple Codable input) and having the Agent call it through the OpenAI-compatible provider. This verifies the tool_use/tool_result conversion between OpenAI and Anthropic formats works end-to-end.

6. **AC6: Provider comparison** -- Given the example code, when reading the code, it demonstrates the configuration difference between Anthropic provider (default) and OpenAI-compatible provider, showing side-by-side `AgentOptions` configuration for both.

7. **AC7: Package.swift updated** -- Given the Package.swift file, when adding the `OpenAICompatExample` executable target, it follows the exact same pattern as existing examples (e.g., `MultiTurnExample`).

## Tasks / Subtasks

- [ ] Task 1: Create example directory and file (AC: #1, #7)
  - [ ] Create `Examples/OpenAICompatExample/main.swift`
  - [ ] Add `.executableTarget(name: "OpenAICompatExample", dependencies: ["OpenAgentSDK"], path: "Examples/OpenAICompatExample")` to Package.swift

- [ ] Task 2: Write Part 1 -- Provider Configuration (AC: #2, #6)
  - [ ] Chinese + English header comment block
  - [ ] Load API key and configuration from environment variables using `loadDotEnv()` / `getEnv()`
  - [ ] Show both Anthropic and OpenAI provider `AgentOptions` configurations side by side
  - [ ] Print current provider and base URL being used

- [ ] Task 3: Write Part 2 -- Prompt with OpenAI Provider (AC: #3)
  - [ ] Create Agent with `provider: .openai` and `baseURL`
  - [ ] Execute `agent.prompt()` with a simple query
  - [ ] Print response text, input/output tokens, and duration
  - [ ] Assert response is non-empty

- [ ] Task 4: Write Part 3 -- Streaming with OpenAI Provider (AC: #4)
  - [ ] Use `agent.stream()` for a streaming query
  - [ ] Collect `SDKMessage` events: `.partialMessage` for text deltas, `.result` for final stats
  - [ ] Print streamed text and usage stats
  - [ ] Assert streamed text is non-empty

- [ ] Task 5: Write Part 4 -- Tool Use with OpenAI Provider (AC: #5)
  - [ ] Define a simple custom tool using `defineTool()` with Codable input
  - [ ] Create Agent with OpenAI provider and the custom tool
  - [ ] Send a prompt that triggers the tool
  - [ ] Print tool call details and final response
  - [ ] Assert tool was called and response contains tool output

- [ ] Task 6: Verify build (AC: #1)
  - [ ] `swift build` compiles with no errors/warnings

## Dev Notes

### Position in Epic and Project

- **Epic 15** (SDK Examples Supplement), eighth and final story
- **Core goal:** Create a runnable example demonstrating OpenAI-compatible API provider usage
- **Prerequisites:** The `OpenAIClient` implementation exists in `Sources/OpenAgentSDK/API/OpenAIClient.swift`, `LLMProvider.openai` enum case exists in `AgentTypes.swift`
- **FR coverage:** FR50 supplement (illustration, not new feature)
- **This is a pure example story** -- no new production code, only an example file and Package.swift update

### Critical API Surface

**LLMProvider** (`Sources/OpenAgentSDK/Types/AgentTypes.swift` lines 3-12):

```swift
public enum LLMProvider: String, Sendable, Equatable {
    case anthropic
    case openai
}
```

**AgentOptions relevant fields** (`Sources/OpenAgentSDK/Types/AgentTypes.swift`):

```swift
public var apiKey: String?
public var model: String
public var baseURL: String?      // nil uses provider default
public var provider: LLMProvider  // defaults to .anthropic
```

**Agent client selection** (`Sources/OpenAgentSDK/Core/Agent.swift` lines 88-102):

```swift
switch options.provider {
case .openai:
    self.client = OpenAIClient(
        apiKey: apiKey,
        baseURL: options.baseURL
    )
case .anthropic:
    self.client = AnthropicClient(
        apiKey: apiKey,
        baseURL: options.baseURL
    )
}
```

**OpenAIClient** (`Sources/OpenAgentSDK/API/OpenAIClient.swift`):

- Accepts `apiKey`, optional `baseURL` (defaults to `https://api.openai.com/v1`), optional custom `URLSession`
- Translates Anthropic-format messages to OpenAI chat completion format
- Translates OpenAI responses back to Anthropic format
- Supports streaming via SSE with chunk-to-event conversion
- Endpoint: `{baseURL}/chat/completions`

### Key Architecture Details

The SDK uses a **format translation layer** approach:

1. **Agent-facing interface**: `LLMClient` protocol uses Anthropic-format dictionaries everywhere
2. **OpenAIClient internals**: Converts Anthropic message format to OpenAI format before sending, converts responses back after receiving
3. **Message conversion**: Anthropic `tool_result` blocks in user messages become separate `role: "tool"` messages in OpenAI format; Anthropic `tool_use` blocks in assistant messages become `tool_calls` arrays
4. **Stream conversion**: OpenAI SSE chunks (`data: {...}`) are parsed and converted to Anthropic-format `SSEEvent` types

This means the Agent's tool execution loop, session management, and all other features work identically regardless of provider.

### Example Pattern to Follow

Follow the exact same patterns as existing examples (SkillsExample, SandboxExample, LoggerExample, ModelSwitchingExample, ContextInjectionExample, MultiTurnExample):

1. **Header comment** -- Chinese + English header block listing what the example demonstrates
2. **API key loading** -- Use `loadDotEnv()` and `getEnv()` helper pattern:
   ```swift
   let dotEnv = loadDotEnv()
   let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
       ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
       ?? "sk-..."
   let defaultModel = getEnv("CODEANY_MODEL", from: dotEnv) ?? "claude-sonnet-4-6"
   let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil
   ```
3. **MARK sections** -- Use `// MARK: - Part N: Title` for each section
4. **Agent creation** -- Use `createAgent(options:)` with `permissionMode: .bypassPermissions`
5. **Output formatting** -- Print sections with clear headers, show pass/fail results
6. **Assertions** -- Use `assert()` for key validations so compliance tests can verify

### Important Implementation Details

1. **Environment variable detection pattern** -- The `useOpenAI` flag is set when `CODEANY_API_KEY` is present. When true, the example uses `provider: .openai` with the CODEANY base URL. When false, it falls back to `provider: .anthropic`. This is the same pattern used by all examples in Epic 15.

2. **Base URL for OpenAI-compatible providers** -- Common endpoints:
   - GLM (ZhiPu AI): `https://open.bigmodel.cn/api/coding/paas/v4`
   - DeepSeek: `https://api.deepseek.com/v1`
   - Ollama local: `http://localhost:11434/v1`
   - OpenAI: `https://api.openai.com/v1` (default)

3. **The example should focus on provider configuration** -- The key educational value is showing how to switch from Anthropic to OpenAI-compatible APIs with minimal code changes (just `provider: .openai` and `baseURL`).

4. **Tool use is important to demonstrate** -- Since `OpenAIClient` handles complex format translation for tool calls, demonstrating that tool use works with the OpenAI provider is a critical validation point.

5. **Custom tool for Part 4** -- Use a simple `defineTool()` with a Codable struct, like a "calculate" tool or "greet" tool. Keep it simple to minimize cost.

6. **Keep prompts simple** -- Use short, simple prompts to minimize cost and latency:
   - Part 2 (prompt): "What is 2 + 2? Answer with just the number."
   - Part 3 (stream): "Count from 1 to 5, one number per line."
   - Part 4 (tool): A prompt that triggers the custom tool.

### Example Structure (4 Parts)

```
Part 1: Provider Configuration Comparison
  - Show AgentOptions for Anthropic vs OpenAI side-by-side
  - Load env vars, print current configuration

Part 2: Prompt with OpenAI Provider
  - Create Agent with provider: .openai and baseURL
  - Execute agent.prompt() with simple query
  - Print response and stats
  - Assert non-empty response

Part 3: Streaming with OpenAI Provider
  - Use agent.stream() for streaming query
  - Collect SDKMessage events
  - Print streamed text and stats
  - Assert non-empty streamed text

Part 4: Tool Use with OpenAI Provider
  - Define custom tool via defineTool()
  - Create Agent with OpenAI provider + custom tool
  - Prompt that triggers tool use
  - Print tool call details and response
  - Assert tool was used
```

### File Locations

```
Examples/OpenAICompatExample/
  main.swift                     # NEW: Example source code
Package.swift                    # MODIFY: Add OpenAICompatExample executable target
```

### Package.swift Change

Add after the `MultiTurnExample` target:

```swift
.executableTarget(
    name: "OpenAICompatExample",
    dependencies: ["OpenAgentSDK"],
    path: "Examples/OpenAICompatExample"
),
```

### Testing Strategy

- **Compilation test:** `swift build` must succeed with no errors and no warnings
- **Manual smoke test:** `swift run OpenAICompatExample` should output all 4 parts (requires API key and compatible endpoint)
- **No new unit tests needed** -- this is an example, not production code
- **Compliance tests** will be auto-generated to verify acceptance criteria via code pattern checks (file existence, import, provider usage, assert statements)

### Previous Story Intelligence (Story 15.7: MultiTurnExample)

- **Pattern confirmed:** Chinese + English header comment block, MARK sections, `loadDotEnv()`/`getEnv()` for API key, `createAgent` with `permissionMode: .bypassPermissions`
- **File structure:** Single `main.swift` file in `Examples/<Name>/` directory
- **Package.swift pattern:** `.executableTarget(name: "...", dependencies: ["OpenAgentSDK"], path: "Examples/...")`
- **Build verified:** `swift build` compiles with no errors/warnings
- **assert() usage:** Use assert() for key validations to support compliance test verification
- **Case-insensitive assertion:** Use `.lowercased().contains()` for string checks to avoid LLM response variation issues
- **Test suite:** 2916 tests, 0 failures, 4 skipped after previous story -- run full suite after changes

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 15.8] -- Full acceptance criteria for OpenAICompatExample
- [Source: Sources/OpenAgentSDK/API/OpenAIClient.swift] -- OpenAI-compatible client implementation with format translation
- [Source: Sources/OpenAgentSDK/API/LLMClient.swift] -- LLMClient protocol definition
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#L3-12] -- LLMProvider enum (anthropic, openai)
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L88-102] -- Provider-based client selection in Agent init
- [Source: Examples/MultiTurnExample/main.swift] -- Latest pattern: Chinese+English header, MARK sections, 4-part structure
- [Source: Package.swift] -- Existing executable target definitions to follow
- [Source: Sources/OpenAgentSDK/Utils/EnvUtils.swift] -- loadDotEnv() and getEnv() helpers

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

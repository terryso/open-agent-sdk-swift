# Story 15.7: MultiTurnExample

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want a runnable example demonstrating multi-turn conversation with an Agent,
so that I can understand how to maintain context across multiple prompt calls.

## Acceptance Criteria

1. **AC1: Example compiles and runs** -- Given `Examples/MultiTurnExample/` directory with a `main.swift` file and corresponding `MultiTurnExample` executable target in Package.swift, when running `swift build`, then it compiles with no errors and no warnings.

2. **AC2: Multi-turn with SessionStore** -- Given the example code, when reading the code, it demonstrates creating a `SessionStore`, creating an Agent with `sessionStore` and `sessionId` parameters, and executing multiple `prompt()` calls on the same Agent. The session store automatically persists and restores conversation history between calls.

3. **AC3: Cross-turn context retention** -- Given the example code, when reading the code, it demonstrates the Agent retaining context across turns: the first prompt tells the Agent "my name is Nick", and the second prompt asks "what is my name?". The example asserts that the second response contains "Nick", proving context is maintained.

4. **AC4: Message history inspection** -- Given the example code, when reading the code, it demonstrates loading the session via `sessionStore.load(sessionId:)` to retrieve the full `SessionData`, and printing the message count and metadata (model, createdAt, updatedAt).

5. **AC5: Streaming multi-turn** -- Given the example code, when reading the code, it demonstrates using `agent.stream()` for a third turn in the conversation, collecting `SDKMessage` events, and showing that streaming also maintains session context (the session is auto-saved after stream completion just like prompt).

6. **AC6: Session cleanup** -- Given the example code, when reading the code, it demonstrates deleting the session via `sessionStore.delete(sessionId:)` after the multi-turn conversation is complete, verifying the session is cleaned up.

7. **AC7: Package.swift updated** -- Given the Package.swift file, when adding the `MultiTurnExample` executable target, it follows the exact same pattern as existing examples (e.g., `ContextInjectionExample`).

## Tasks / Subtasks

- [x] Task 1: Create example directory and file (AC: #1, #7)
  - [x] Create `Examples/MultiTurnExample/main.swift`
  - [x] Add `.executableTarget(name: "MultiTurnExample", dependencies: ["OpenAgentSDK"], path: "Examples/MultiTurnExample")` to Package.swift

- [x] Task 2: Write Part 1 -- Multi-turn with SessionStore (AC: #2, #3)
  - [x] Create `SessionStore()` instance
  - [x] Create Agent with `sessionStore` and `sessionId: "multi-turn-demo"` parameters
  - [x] Execute first prompt: tell the Agent a fact (e.g., "my name is Nick")
  - [x] Print first result text and usage stats
  - [x] Execute second prompt: ask a question that references the first turn (e.g., "what is my name?")
  - [x] Assert that the second response contains the expected context ("Nick")
  - [x] Print second result text and usage stats

- [x] Task 3: Write Part 2 -- Message History Inspection (AC: #4)
  - [x] Call `sessionStore.load(sessionId: "multi-turn-demo")` to get `SessionData`
  - [x] Print `metadata.messageCount` (should be >= 4: user + assistant x2)
  - [x] Print `metadata.model`, `metadata.createdAt`, `metadata.updatedAt`
  - [x] Assert message count > 0

- [x] Task 4: Write Part 3 -- Streaming Multi-turn (AC: #5)
  - [x] Create a new Agent (or reuse existing) with the same `sessionStore` + `sessionId`
  - [x] Use `agent.stream()` for a third prompt in the conversation
  - [x] Collect `SDKMessage` events and print the final text
  - [x] Assert that streaming response is non-empty

- [x] Task 5: Write Part 4 -- Session Cleanup (AC: #6)
  - [x] Call `sessionStore.delete(sessionId: "multi-turn-demo")`
  - [x] Assert deletion returned `true`
  - [x] Verify session no longer exists via `sessionStore.load()` returning `nil`

- [x] Task 6: Verify build (AC: #1)
  - [x] `swift build` compiles with no errors/warnings

## Dev Notes

### Position in Epic and Project

- **Epic 15** (SDK Examples Supplement), seventh story
- **Core goal:** Create a runnable example demonstrating multi-turn conversation using `SessionStore` + `sessionId` for cross-prompt context retention
- **Prerequisites:** Epic 7 (Session Persistence) is DONE -- `SessionStore` and `SessionData` types exist
- **FR coverage:** FR52-FR64 example (illustration, not new feature)
- **This is a pure example story** -- no new production code, only an example file and Package.swift update

### Critical API Surface

**SessionStore** (`Sources/OpenAgentSDK/Stores/SessionStore.swift`):

```swift
public actor SessionStore {
    public init(sessionsDir: String? = nil)
    public func save(sessionId: String, messages: [[String: Any]], metadata: PartialSessionMetadata) throws
    public func load(sessionId: String) throws -> SessionData?
    public func delete(sessionId: String) throws -> Bool
    public func list() throws -> [SessionMetadata]
}
```

**SessionData** (`Sources/OpenAgentSDK/Types/SessionTypes.swift`):

```swift
public struct SessionData: @unchecked Sendable {
    public let metadata: SessionMetadata
    public let messages: [[String: Any]]
}

public struct SessionMetadata: Sendable, Equatable {
    public let id: String
    public let cwd: String
    public let model: String
    public let createdAt: String
    public let updatedAt: String
    public let messageCount: Int
    public let summary: String?
    public let tag: String?
}
```

**Agent multi-turn mechanism** (`Sources/OpenAgentSDK/Core/Agent.swift`):

The Agent's `prompt()` method (lines 294-653) automatically:
1. **Before prompt:** If `sessionStore` + `sessionId` are configured, loads existing messages from the session store via `sessionStore.load(sessionId:)` and appends the new user message to the restored history
2. **After prompt:** Saves the updated messages (including all new user/assistant exchanges) back to the session store via `sessionStore.save(sessionId:messages:metadata:)`
3. The same mechanism works for `stream()` (lines 680-1370)

This means calling `prompt()` multiple times on the same Agent (or different Agents with the same `sessionStore`+`sessionId`) automatically maintains conversation context.

**AgentOptions relevant fields** (`Sources/OpenAgentSDK/Types/AgentTypes.swift` lines 86-90):

```swift
public var sessionStore: SessionStore?  // default nil
public var sessionId: String?          // default nil
```

### Key Difference from SessionsAndHooks Example

The existing `Examples/SessionsAndHooks/main.swift` already demonstrates session persistence with hooks. **MultiTurnExample must NOT duplicate SessionsAndHooks.** The key differences:

| Aspect | SessionsAndHooks | MultiTurnExample |
|--------|-----------------|------------------|
| Focus | HookRegistry + SessionStore lifecycle | Multi-turn context retention |
| Hooks | Heavy hook usage (pre/post tool, lifecycle) | No hooks |
| Session mgmt | Save/load/list/rename/tag/delete | Just load + delete |
| Core demo | Hook mechanism | Cross-turn memory |
| Turns | 2 prompts (save + resume with new Agent) | 3+ turns on same Agent + stream |

MultiTurnExample focuses on the **conversation flow** aspect: showing that context persists across turns and the Agent "remembers" what was said earlier.

### Example Pattern to Follow

Follow the exact same patterns as existing examples (SkillsExample, SandboxExample, LoggerExample, ModelSwitchingExample, ContextInjectionExample):

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

1. **SessionStore is an actor** -- All methods require `await`. Use `try await` for `save`, `load`, `delete`, `list`.

2. **Same Agent, multiple prompts** -- The simplest multi-turn pattern is calling `prompt()` multiple times on the same Agent instance that has `sessionStore` + `sessionId` configured. The Agent auto-saves after each prompt and auto-loads before the next.

3. **Streaming also auto-saves** -- The `stream()` method has the same session auto-save logic. This is a good demonstration point for Part 3.

4. **Use a unique sessionId** -- Use `"multi-turn-demo"` as the sessionId. Clean it up at the end (delete).

5. **Keep prompts simple** -- Use short, simple prompts for the multi-turn demo to minimize cost and latency:
   - Turn 1: "Remember that my name is Nick. Just confirm you got it."
   - Turn 2: "What is my name?"
   - Turn 3 (stream): "Can you count from 1 to 5?"

6. **Message count assertion** -- After 3 turns, the session should have at least 6 messages (3 user + 3 assistant). Use `assert(messageCount >= 6)` as a loose check since there may be tool-use rounds.

7. **Delete session at the end** -- Clean up the demo session to avoid polluting the user's session storage.

### Example Structure (4 Parts)

```
Part 1: Multi-turn with SessionStore
  - Create SessionStore
  - Create Agent with sessionStore + sessionId
  - Turn 1: Tell the Agent a fact
  - Turn 2: Ask about the fact from Turn 1
  - Assert context retention

Part 2: Message History Inspection
  - Load session from SessionStore
  - Print messageCount, model, timestamps
  - Assert messageCount > 0

Part 3: Streaming Multi-turn
  - Use stream() for a third turn
  - Collect SDKMessage events
  - Assert non-empty response

Part 4: Session Cleanup
  - Delete the demo session
  - Verify deletion succeeded
```

### File Locations

```
Examples/MultiTurnExample/
  main.swift                     # NEW: Example source code
Package.swift                    # MODIFY: Add MultiTurnExample executable target
```

### Package.swift Change

Add after the `ContextInjectionExample` target:

```swift
.executableTarget(
    name: "MultiTurnExample",
    dependencies: ["OpenAgentSDK"],
    path: "Examples/MultiTurnExample"
),
```

### Testing Strategy

- **Compilation test:** `swift build` must succeed with no errors and no warnings
- **Manual smoke test:** `swift run MultiTurnExample` should output all 4 parts (requires API key)
- **No new unit tests needed** -- this is an example, not production code
- **Compliance tests** will be auto-generated to verify acceptance criteria via code pattern checks (file existence, import, API usage patterns, assert statements)

### Previous Story Intelligence (Story 15.6: ContextInjectionExample)

- **Pattern confirmed:** Chinese + English header comment block, MARK sections, `loadDotEnv()`/`getEnv()` for API key, `createAgent` with `permissionMode: .bypassPermissions`
- **File structure:** Single `main.swift` file in `Examples/<Name>/` directory
- **Package.swift pattern:** `.executableTarget(name: "...", dependencies: ["OpenAgentSDK"], path: "Examples/...")`
- **Build verified:** `swift build` compiles with no errors/warnings
- **assert() usage:** Use assert() for key validations to support compliance test verification
- **Test suite:** 2881 tests, 0 failures, 4 skipped after previous story -- run full suite after changes

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 15.7] -- Full acceptance criteria for MultiTurnExample
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 7] -- Session persistence design
- [Source: Sources/OpenAgentSDK/Stores/SessionStore.swift] -- SessionStore actor with save/load/delete/list
- [Source: Sources/OpenAgentSDK/Types/SessionTypes.swift] -- SessionMetadata, SessionData, PartialSessionMetadata
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L312-324] -- Session restore logic (load before prompt)
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L635-647] -- Session auto-save logic (save after prompt)
- [Source: Sources/OpenAgentSDK/Core/Agent.swift#L680] -- stream() method (also supports session auto-save)
- [Source: Sources/OpenAgentSDK/Types/AgentTypes.swift#L86-90] -- sessionStore, sessionId fields
- [Source: Examples/SessionsAndHooks/main.swift] -- Existing session example (for reference, but DO NOT duplicate)
- [Source: Examples/ContextInjectionExample/main.swift] -- Latest pattern: Chinese+English header, MARK sections, 5-part structure
- [Source: Package.swift] -- Existing executable target definitions to follow

## Dev Agent Record

### Agent Model Used

GLM-5.1

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Task 1: Created `Examples/MultiTurnExample/main.swift` with Chinese + English header comment block. Added `.executableTarget` to Package.swift following existing example patterns.
- Task 2: Implemented Part 1 -- creates SessionStore, Agent with sessionStore + sessionId, executes 2 prompts demonstrating cross-turn context retention. Asserts second response contains "Nick".
- Task 3: Implemented Part 2 -- loads SessionData via sessionStore.load(), prints metadata (messageCount, model, createdAt, updatedAt), asserts messageCount > 0.
- Task 4: Implemented Part 3 -- uses agent.stream() for a third turn, collects SDKMessage events (partialMessage, result), asserts non-empty response.
- Task 5: Implemented Part 4 -- calls sessionStore.delete(), asserts deletion returned true, verifies session is nil after deletion.
- Task 6: Build verified -- `swift build` compiles with no errors or warnings.
- All 35 ATDD compliance tests pass. Full test suite: 2916 tests, 0 failures, 4 skipped.

### File List

- `Examples/MultiTurnExample/main.swift` -- NEW: Multi-turn conversation example source code
- `Package.swift` -- MODIFIED: Added MultiTurnExample executable target

### Review Findings

- [x] [Review][Patch] Case-sensitive "Nick" assertion fragile against LLM response variation [Examples/MultiTurnExample/main.swift:95] -- Fixed: changed to `.lowercased().contains("nick")` for case-insensitive check.
- [x] [Review][Defer] No error handling around `try await` sessionStore calls [Examples/MultiTurnExample/main.swift:110,182,190] -- deferred, pre-existing (consistent with SessionsAndHooks pattern).
- [x] [Review][Defer] assert() disabled in release builds [Examples/MultiTurnExample/main.swift:94,111,125,169,183,191] -- deferred, pre-existing (established example pattern).

## Change Log

- 2026-04-14: Story 15-7 implementation complete. Created MultiTurnExample demonstrating SessionStore-based multi-turn conversation with context retention, message history inspection, streaming multi-turn, and session cleanup.
- 2026-04-14: Code review. Fixed case-sensitive "Nick" assertion. Deferred 2 pre-existing pattern items.

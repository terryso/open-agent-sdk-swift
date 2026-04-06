---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-07'
storyId: '4-4'
detectedStack: 'backend'
generationMode: 'ai-generation'
testFramework: 'XCTest'
---

# ATDD Test Checklist — Story 4.4: SendMessage Tool

## Test Strategy

| Level | AC | Priority | File |
|-------|-----|----------|------|
| Unit | #1 Direct message delivery | P0 | SendMessageToolTests.swift |
| Unit | #2 Broadcast message delivery | P0 | SendMessageToolTests.swift |
| Unit | #3 No team returns error | P0 | SendMessageToolTests.swift |
| Unit | #4 Recipient not in team returns error | P0 | SendMessageToolTests.swift |
| Unit | #5 ToolContext with mailboxStore/teamStore/senderName | P0 | SendMessageToolTests.swift |
| Unit | #6 Module boundary — no Core/Stores imports | P0 | SendMessageToolTests.swift |
| Unit | #7 Sender identity from ToolContext | P0 | SendMessageToolTests.swift |
| Unit | #8 Error handling does not throw | P0 | SendMessageToolTests.swift |
| Unit | #9 inputSchema matches TS SDK | P0 | SendMessageToolTests.swift |
| Unit | #1 Factory returns valid ToolProtocol | P0 | SendMessageToolTests.swift |
| Unit | #1 Input Codable decode | P0 | SendMessageToolTests.swift |
| Unit | #5 Missing mailboxStore returns error | P0 | SendMessageToolTests.swift |
| Unit | #5 Missing teamStore returns error | P0 | SendMessageToolTests.swift |
| Unit | #7 Missing senderName returns error | P0 | SendMessageToolTests.swift |
| Unit | #1 Direct message — verify mailbox content | P0 | SendMessageToolTests.swift |
| Unit | #2 Broadcast — verify all mailboxes | P0 | SendMessageToolTests.swift |
| Unit | #4 Error message lists available members | P1 | SendMessageToolTests.swift |
| Unit | #9 isReadOnly is false | P1 | SendMessageToolTests.swift |
| Unit | #5 ToolContext backward compatibility | P0 | SendMessageToolTests.swift |
| Unit | #8 Malformed input returns ToolResult | P0 | SendMessageToolTests.swift |
| Unit | #1 Send to self succeeds | P1 | SendMessageToolTests.swift |

## Test Files Generated

1. `Tests/OpenAgentSDKTests/Tools/Advanced/SendMessageToolTests.swift` — 21 tests

**Total: 21 tests**

## TDD Status: RED PHASE

All tests assert EXPECTED behavior that does not exist yet. They will FAIL until:
- `ToolContext` gains `mailboxStore`, `teamStore`, and `senderName` fields
- `createSendMessageTool()` factory function is implemented in `Tools/Advanced/SendMessageTool.swift`
- The factory function correctly wires up MailboxStore and TeamStore via ToolContext

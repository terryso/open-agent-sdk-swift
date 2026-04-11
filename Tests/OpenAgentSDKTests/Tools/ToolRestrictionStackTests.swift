import XCTest
@testable import OpenAgentSDK

// MARK: - ToolRestrictionStack Tests (Story 11.2, ATDD RED PHASE)

/// ATDD RED PHASE: Tests for Story 11.2 -- ToolRestrictionStack.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `ToolRestrictionStack` class is implemented in Tools/ToolRestrictionStack.swift
///   - Implements `push(_:)`, `pop()`, `currentAllowedToolNames(baseTools:)`, `isEmpty`
///   - Thread-safe via internal DispatchQueue (final class + @unchecked Sendable)
///   - Case-insensitive tool name matching between ToolRestriction.rawValue and ToolProtocol.name
/// TDD Phase: RED (feature not implemented yet)
final class ToolRestrictionStackTests: XCTestCase {

    // MARK: - Helper: Create a mock tool

    /// Creates a simple mock tool with the given name for testing.
    private func makeTool(name: String) -> ToolProtocol {
        defineTool(
            name: name,
            description: "Mock \(name) tool",
            inputSchema: ["type": "object", "properties": [:]],
            isReadOnly: true
        ) { (_: EmptyInput, _: ToolContext) in
            return "mock"
        }
    }

    // MARK: - Helper: Empty Codable struct for mock tools

    private struct EmptyInput: Codable {}

    // MARK: - Helper: Create base tools array

    /// Creates a standard set of mock tools for testing.
    private func makeBaseTools() -> [ToolProtocol] {
        return [
            makeTool(name: "Bash"),
            makeTool(name: "Read"),
            makeTool(name: "Write"),
            makeTool(name: "Edit"),
            makeTool(name: "Glob"),
            makeTool(name: "Grep"),
            makeTool(name: "Skill")
        ]
    }

    // MARK: - AC2: Basic Push/Pop Behavior

    /// AC2 [P0]: ToolRestrictionStack starts empty.
    func testStack_initialState_isEmpty() {
        // Given: a new stack
        let stack = ToolRestrictionStack()

        // Then: stack is empty
        XCTAssertTrue(stack.isEmpty, "New stack should be empty")
    }

    /// AC2 [P0]: After push, stack is not empty.
    func testStack_afterPush_isNotEmpty() {
        // Given: a new stack
        let stack = ToolRestrictionStack()

        // When: pushing restrictions
        stack.push([.bash, .read])

        // Then: stack is not empty
        XCTAssertFalse(stack.isEmpty, "Stack should not be empty after push")
    }

    /// AC2 [P0]: After push then pop, stack is empty again.
    func testStack_pushPop_isEmpty() {
        // Given: a stack with pushed restrictions
        let stack = ToolRestrictionStack()
        stack.push([.bash, .read])

        // When: popping
        stack.pop()

        // Then: stack is empty
        XCTAssertTrue(stack.isEmpty, "Stack should be empty after push then pop")
    }

    /// AC2 [P0]: currentAllowedToolNames returns full baseTools when stack is empty.
    func testCurrentAllowedTools_emptyStack_returnsAllTools() {
        // Given: an empty stack and base tools
        let stack = ToolRestrictionStack()
        let baseTools = makeBaseTools()

        // When: getting allowed tools with empty stack
        let allowed = stack.currentAllowedToolNames(baseTools: baseTools)

        // Then: all base tools are returned
        XCTAssertEqual(allowed.count, baseTools.count, "Empty stack should return all base tools")
        let allowedNames = Set(allowed.map(\.name))
        let baseNames = Set(baseTools.map(\.name))
        XCTAssertEqual(allowedNames, baseNames)
    }

    /// AC2 [P0]: currentAllowedToolNames filters base tools when stack has restrictions.
    func testCurrentAllowedTools_withRestrictions_filtersTools() {
        // Given: a stack with restrictions for bash and read only
        let stack = ToolRestrictionStack()
        let baseTools = makeBaseTools()

        // When: pushing restrictions
        stack.push([.bash, .read])
        let allowed = stack.currentAllowedToolNames(baseTools: baseTools)

        // Then: only Bash and Read are returned
        let allowedNames = Set(allowed.map(\.name))
        XCTAssertEqual(allowedNames, Set(["Bash", "Read"]),
                        "Only restricted tools should be allowed, got: \(allowedNames)")
    }

    /// AC2 [P1]: Tool name matching is case-insensitive (ToolRestriction.bash -> "Bash" tool).
    func testCurrentAllowedTools_caseInsensitiveMatching() {
        // Given: a stack with lowercase restriction
        let stack = ToolRestrictionStack()
        let baseTools = makeBaseTools()

        // When: pushing [.bash] (rawValue = "bash") and tools have "Bash"
        stack.push([.bash])
        let allowed = stack.currentAllowedToolNames(baseTools: baseTools)

        // Then: the "Bash" tool is found despite case difference
        let allowedNames = allowed.map(\.name)
        XCTAssertTrue(allowedNames.contains("Bash"),
                       "Case-insensitive match should find 'Bash' tool for .bash restriction")
        XCTAssertEqual(allowedNames.count, 1)
    }

    /// AC2 [P1]: Popping after single push restores full tool set.
    func testStack_popRestores_fullToolSet() {
        // Given: a stack with pushed restrictions
        let stack = ToolRestrictionStack()
        let baseTools = makeBaseTools()
        stack.push([.bash])

        // When: popping
        stack.pop()
        let allowed = stack.currentAllowedToolNames(baseTools: baseTools)

        // Then: all tools are available again
        XCTAssertEqual(allowed.count, baseTools.count, "Pop should restore full tool set")
    }

    // MARK: - AC3: Nested Push/Pop (Stack Semantics)

    /// AC3 [P0]: Nested push/pop preserves stack semantics.
    /// Skill A [.bash, .read] then Skill B [.grep, .glob] -> top is B's restrictions.
    func testStack_nestedPush_topIsLastPushed() {
        // Given: a stack
        let stack = ToolRestrictionStack()
        let baseTools = makeBaseTools()

        // When: pushing A's restrictions then B's restrictions
        stack.push([.bash, .read])       // Skill A
        stack.push([.grep, .glob])       // Skill B (nested)

        let allowed = stack.currentAllowedToolNames(baseTools: baseTools)

        // Then: top of stack is B's restrictions
        let allowedNames = Set(allowed.map(\.name))
        XCTAssertEqual(allowedNames, Set(["Grep", "Glob"]),
                        "Nested push should make B's restrictions the top of the stack")
    }

    /// AC3 [P0]: After popping inner skill, outer skill's restrictions are active.
    func testStack_nestedPop_innerRestores() {
        // Given: a stack with nested pushes
        let stack = ToolRestrictionStack()
        let baseTools = makeBaseTools()
        stack.push([.bash, .read])       // Skill A
        stack.push([.grep, .glob])       // Skill B

        // When: popping B (inner skill completes)
        stack.pop()
        let allowed = stack.currentAllowedToolNames(baseTools: baseTools)

        // Then: A's restrictions are active
        let allowedNames = Set(allowed.map(\.name))
        XCTAssertEqual(allowedNames, Set(["Bash", "Read"]),
                        "After popping inner, outer skill's restrictions should be active")
    }

    /// AC3 [P0]: After popping both skills, full tool set is restored.
    func testStack_nestedPopBoth_restoresFullSet() {
        // Given: a stack with two levels
        let stack = ToolRestrictionStack()
        let baseTools = makeBaseTools()
        stack.push([.bash, .read])
        stack.push([.grep, .glob])

        // When: popping both
        stack.pop()  // Pop inner
        stack.pop()  // Pop outer

        // Then: full tool set is restored
        XCTAssertTrue(stack.isEmpty)
        let allowed = stack.currentAllowedToolNames(baseTools: baseTools)
        XCTAssertEqual(allowed.count, baseTools.count)
    }

    /// AC3 [P1]: Triple nesting maintains correct LIFO order.
    func testStack_tripleNesting_LIFO() {
        // Given: a stack
        let stack = ToolRestrictionStack()
        let baseTools = makeBaseTools()

        // When: pushing three levels
        stack.push([.bash])              // Level 1
        stack.push([.read])              // Level 2
        stack.push([.write, .glob])      // Level 3

        let level3Allowed = Set(stack.currentAllowedToolNames(baseTools: baseTools).map(\.name))
        XCTAssertEqual(level3Allowed, Set(["Write", "Glob"]))

        stack.pop()
        let level2Allowed = Set(stack.currentAllowedToolNames(baseTools: baseTools).map(\.name))
        XCTAssertEqual(level2Allowed, Set(["Read"]))

        stack.pop()
        let level1Allowed = Set(stack.currentAllowedToolNames(baseTools: baseTools).map(\.name))
        XCTAssertEqual(level1Allowed, Set(["Bash"]))

        stack.pop()
        XCTAssertTrue(stack.isEmpty)
    }

    // MARK: - AC5: Self-Reference Check (ToolRestrictionStack perspective)

    /// AC5 [P0]: Pushing restrictions containing .skill should be detected.
    /// The check happens in SkillTool, but the stack should handle it if needed.
    func testStack_pushWithSkillRestriction_canBeDetected() {
        // Given: a stack
        let stack = ToolRestrictionStack()

        // When: pushing restrictions that include .skill
        // This should succeed in the stack itself (the check is in SkillTool)
        stack.push([.bash, .read, .skill])

        // Then: the stack accepts it (SkillTool checks self-reference before push)
        XCTAssertFalse(stack.isEmpty)
    }

    // MARK: - AC6: Error Path Stack Recovery (defer semantics)

    /// AC6 [P0]: Pop on empty stack does not crash (graceful handling).
    func testStack_popOnEmpty_doesNotCrash() {
        // Given: an empty stack
        let stack = ToolRestrictionStack()

        // When/Then: popping empty stack does not crash
        stack.pop()
        stack.pop()
        XCTAssertTrue(stack.isEmpty, "Popping empty stack should be a no-op")
    }

    /// AC6 [P1]: Multiple pops beyond pushes do not crash.
    func testStack_overPopping_doesNotCrash() {
        // Given: a stack with one push
        let stack = ToolRestrictionStack()
        stack.push([.bash])

        // When: popping more times than pushed
        stack.pop()
        stack.pop()
        stack.pop()

        // Then: no crash, still empty
        XCTAssertTrue(stack.isEmpty)
    }

    // MARK: - Thread Safety

    /// [P1]: Concurrent push/pop operations do not crash.
    func testStack_concurrentOperations_doNotCrash() {
        // Given: a stack
        let stack = ToolRestrictionStack()
        let baseTools = makeBaseTools()

        // When: performing concurrent push/pop operations
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            if i % 2 == 0 {
                stack.push([.bash, .read])
            } else {
                let _ = stack.currentAllowedToolNames(baseTools: baseTools)
            }
            if i % 3 == 0 {
                stack.pop()
            }
        }

        // Then: no crash (test passes if we get here)
    }

    // MARK: - Edge Cases

    /// [P1]: Empty restrictions array push (no tools allowed).
    func testStack_emptyRestrictions_noToolsAllowed() {
        // Given: a stack
        let stack = ToolRestrictionStack()
        let baseTools = makeBaseTools()

        // When: pushing empty restrictions
        stack.push([])

        // Then: no tools are allowed
        let allowed = stack.currentAllowedToolNames(baseTools: baseTools)
        XCTAssertTrue(allowed.isEmpty, "Empty restriction set should allow no tools")
    }

    /// [P1]: Restriction for non-existent tool name returns empty for that match.
    func testStack_nonExistentTool_notIncluded() {
        // Given: a stack with restriction for a tool not in baseTools
        let stack = ToolRestrictionStack()
        let baseTools = makeBaseTools()

        // When: pushing restriction for webFetch which is not in baseTools
        stack.push([.webFetch])

        // Then: no tools match (webFetch not in our base tools)
        let allowed = stack.currentAllowedToolNames(baseTools: baseTools)
        XCTAssertTrue(allowed.isEmpty, "Non-existent tool restriction should yield empty result")
    }
}

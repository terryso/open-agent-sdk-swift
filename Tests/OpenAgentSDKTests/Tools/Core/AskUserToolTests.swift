import XCTest
@testable import OpenAgentSDK

// MARK: - AskUserTool ATDD Tests (Story 3.6)

/// ATDD RED PHASE: Tests for Story 3.6 — AskUserTool.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Sources/OpenAgentSDK/Tools/Core/AskUserTool.swift` is created
///   - `createAskUserTool() -> ToolProtocol` is implemented
///   - The tool asks the user a question via a handler mechanism
///   - Non-interactive mode returns informational message when no handler set
///   - Handler errors return isError=true
/// TDD Phase: RED (feature not implemented yet)
final class AskUserToolTests: XCTestCase {

    override func tearDown() {
        // Clean up handler state between tests
        clearQuestionHandler()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates the AskUser tool via the public factory function.
    private func makeAskUserTool() -> ToolProtocol {
        return createAskUserTool()
    }

    /// Calls the tool with a dictionary input and returns the ToolResult.
    private func callTool(
        _ tool: ToolProtocol,
        input: [String: Any],
        cwd: String? = nil
    ) async -> ToolResult {
        let context = ToolContext(
            cwd: cwd ?? NSTemporaryDirectory(),
            toolUseId: "test-\(UUID().uuidString)"
        )
        return await tool.call(input: input, context: context)
    }

    // MARK: - AC5: AskUser tool asks the user a question

    /// AC5 [P0]: AskUser tool with handler returns the user's answer.
    func testAskUser_withHandler_returnsAnswer() async {
        // Given: a question handler that returns a fixed answer
        setQuestionHandler { question, options in
            return "my answer is 42"
        }

        let tool = makeAskUserTool()

        // When: asking a question
        let result = await callTool(tool, input: [
            "question": "What is the answer?"
        ])

        // Then: the handler's response is returned
        XCTAssertFalse(result.isError,
                       "AskUser with handler should not error, got: \(result.content)")
        XCTAssertEqual(result.content, "my answer is 42",
                       "Should return the handler's answer")
    }

    /// AC5 [P0]: AskUser tool passes options to the handler.
    func testAskUser_withHandler_passesOptions() async {
        // Given: a handler that echoes back the options
        setQuestionHandler { question, options in
            if let options = options {
                return "Options: " + options.joined(separator: ", ")
            }
            return "No options"
        }

        let tool = makeAskUserTool()

        // When: asking a question with options
        let result = await callTool(tool, input: [
            "question": "Pick one",
            "options": ["red", "green", "blue"]
        ])

        // Then: options are passed through to the handler
        XCTAssertFalse(result.isError,
                       "AskUser with options should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("red"),
                      "Should include option 'red'")
        XCTAssertTrue(result.content.contains("green"),
                      "Should include option 'green'")
        XCTAssertTrue(result.content.contains("blue"),
                      "Should include option 'blue'")
    }

    // MARK: - AC6: AskUser tool non-interactive mode

    /// AC6 [P0]: AskUser tool without handler returns non-interactive mode message.
    func testAskUser_withoutHandler_returnsNonInteractive() async {
        // Given: no question handler is set (cleared in tearDown)
        clearQuestionHandler()

        let tool = makeAskUserTool()

        // When: asking a question without a handler
        let result = await callTool(tool, input: [
            "question": "What should I do?"
        ])

        // Then: a non-interactive mode message is returned (not isError)
        XCTAssertFalse(result.isError,
                       "Non-interactive mode should NOT be isError=true, got: \(result.content)")
        XCTAssertFalse(result.content.isEmpty,
                       "Should return a non-empty message in non-interactive mode")
        // The message should indicate that no user is available
        XCTAssertTrue(
            result.content.lowercased().contains("non-interactive") ||
            result.content.lowercased().contains("no user") ||
            result.content.lowercased().contains("not available"),
            "Message should indicate non-interactive or no user available, got: \(result.content)"
        )
    }

    /// AC6 [P1]: AskUser tool in non-interactive mode includes the question in the message.
    func testAskUser_withoutHandler_includesQuestionInMessage() async {
        // Given: no question handler
        clearQuestionHandler()

        let tool = makeAskUserTool()

        // When: asking a specific question
        let result = await callTool(tool, input: [
            "question": "Should I deploy to production?"
        ])

        // Then: the question text appears in the response
        XCTAssertFalse(result.isError,
                       "Non-interactive should not error, got: \(result.content)")
        XCTAssertTrue(result.content.contains("Should I deploy to production?"),
                      "Non-interactive message should echo the question, got: \(result.content)")
    }

    // MARK: - Error handling

    /// [P0]: AskUser tool returns isError=true when the handler throws an error.
    func testAskUser_handlerError_returnsError() async {
        // Given: a handler that throws an error
        setQuestionHandler { question, options in
            throw NSError(domain: "AskUserTest", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "User declined to answer"
            ])
        }

        let tool = makeAskUserTool()

        // When: asking a question with the throwing handler
        let result = await callTool(tool, input: [
            "question": "Answer me!"
        ])

        // Then: error result returned
        XCTAssertTrue(result.isError,
                      "Handler error should return isError=true, got: \(result.content)")
        XCTAssertTrue(
            result.content.lowercased().contains("declined") ||
            result.content.lowercased().contains("error"),
            "Error message should describe the failure, got: \(result.content)"
        )
    }

    // MARK: - Tool metadata

    /// [P0]: AskUser tool should be named "AskUser".
    func testAskUserTool_hasCorrectName() {
        let tool = makeAskUserTool()
        XCTAssertEqual(tool.name, "AskUser",
                       "AskUser tool should be named 'AskUser'")
    }

    /// [P0]: AskUser tool should be marked as read-only.
    func testAskUserTool_isReadOnly_true() {
        let tool = makeAskUserTool()
        XCTAssertTrue(tool.isReadOnly,
                      "AskUser tool should be marked as read-only")
    }

    /// [P0]: AskUser tool should have `question` in required schema fields.
    func testAskUserTool_hasQuestionInRequiredSchema() {
        let tool = makeAskUserTool()
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        XCTAssertNotNil(required,
                        "inputSchema should have 'required' array")
        XCTAssertTrue(required!.contains("question"),
                      "'question' should be in required fields")
    }
}

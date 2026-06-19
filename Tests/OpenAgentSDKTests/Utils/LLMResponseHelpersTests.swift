import XCTest
@testable import OpenAgentSDK

// MARK: - LLMResponseHelpers Tests

/// Unit tests for the shared LLM response parsing helpers in
/// `Sources/OpenAgentSDK/Utils/LLMResponseHelpers.swift`.
///
/// These helpers are consumed by:
/// - `API/Streaming.swift` (SSE event dispatch)
/// - `API/OpenAIClient.swift` (tool input parsing)
/// - `Core/Agent.swift` (tool-use input decoding)
/// - `Utils/Compact.swift` (compaction response parsing)
/// - `Utils/LLMSkillEvolver.swift`, `Utils/PromptEvolverEngine.swift`,
///   `Utils/LLMExperienceExtractor.swift` (evolution pipelines)
///
/// Covers all five public helpers across happy paths, edge cases, and
/// malformed-input regressions.
final class LLMResponseHelpersTests: XCTestCase {

    // MARK: - extractFirstTextFromResponse

    func testExtractFirstText_returnsFirstTextBlock() {
        let response: [String: Any] = [
            "content": [
                ["type": "text", "text": "hello world"],
                ["type": "text", "text": "second block"]
            ]
        ]
        XCTAssertEqual(extractFirstTextFromResponse(response), "hello world")
    }

    func testExtractFirstText_skipsNonTextBlocks() {
        let response: [String: Any] = [
            "content": [
                ["type": "tool_use", "id": "t1", "name": "foo", "input": [:]],
                ["type": "text", "text": "after tool"]
            ]
        ]
        XCTAssertEqual(extractFirstTextFromResponse(response), "after tool")
    }

    func testExtractFirstText_returnsEmptyWhenNoTextBlock() {
        let response: [String: Any] = [
            "content": [
                ["type": "tool_use", "id": "t1", "name": "foo", "input": [:]]
            ]
        ]
        XCTAssertEqual(extractFirstTextFromResponse(response), "")
    }

    func testExtractFirstText_returnsEmptyWhenContentMissing() {
        XCTAssertEqual(extractFirstTextFromResponse([:]), "")
    }

    func testExtractFirstText_returnsEmptyWhenContentNotArray() {
        XCTAssertEqual(extractFirstTextFromResponse(["content": "wrong shape"]), "")
    }

    func testExtractFirstText_returnsEmptyWhenContentEmpty() {
        XCTAssertEqual(extractFirstTextFromResponse(["content": [[String: Any]]()]), "")
    }

    func testExtractFirstText_skipsBlockWithMissingTextField() {
        let response: [String: Any] = [
            "content": [
                ["type": "text"],
                ["type": "text", "text": "fallback"]
            ]
        ]
        XCTAssertEqual(extractFirstTextFromResponse(response), "fallback")
    }

    // MARK: - stripCodeFences

    func testStripCodeFences_plainFenceWithNewlines() {
        XCTAssertEqual(stripCodeFences("```\nhello\n```"), "hello")
    }

    func testStripCodeFences_fenceWithLanguageTag() {
        XCTAssertEqual(stripCodeFences("```json\n{\"a\":1}\n```"), "{\"a\":1}")
    }

    func testStripCodeFences_preservesMultilineContent() {
        let input = "```\nline1\nline2\nline3\n```"
        XCTAssertEqual(stripCodeFences(input), "line1\nline2\nline3")
    }

    func testStripCodeFences_noFenceReturnsTrimmed() {
        XCTAssertEqual(stripCodeFences("  plain text  "), "plain text")
    }

    func testStripCodeFences_emptyString() {
        XCTAssertEqual(stripCodeFences(""), "")
    }

    func testStripCodeFences_onlyWhitespace() {
        XCTAssertEqual(stripCodeFences("   \n  \t "), "")
    }

    func testStripCodeFences_openFenceWithNoNewline() {
        // "```foo" → dropFirst(3) → "foo"
        XCTAssertEqual(stripCodeFences("```foo"), "foo")
    }

    func testStripCodeFences_openFenceWithNewlineNoCloseFence() {
        XCTAssertEqual(stripCodeFences("```json\ncontent"), "content")
    }

    func testStripCodeFences_closeFenceWithoutOpenFenceIsStripped() {
        // The hasSuffix check is independent of the hasPrefix check: a trailing
        // "```" gets stripped even without a matching opening fence. This is a
        // documented boundary behavior consumers should be aware of.
        XCTAssertEqual(stripCodeFences("content```"), "content")
    }

    func testStripCodeFences_yamlFenceTag() {
        let yaml = "```yaml\nname: foo\n```"
        XCTAssertEqual(stripCodeFences(yaml), "name: foo")
    }

    func testStripCodeFences_trimsWhitespaceAroundFence() {
        XCTAssertEqual(stripCodeFences("\n\n  ```\nbody\n```  \n"), "body")
    }

    // MARK: - parseJSONToDict

    func testParseJSONToDict_validObject() {
        let result = parseJSONToDict("{\"a\":1,\"b\":\"x\"}")
        XCTAssertEqual(result?["a"] as? Int, 1)
        XCTAssertEqual(result?["b"] as? String, "x")
    }

    func testParseJSONToDict_emptyStringReturnsNil() {
        XCTAssertNil(parseJSONToDict(""))
    }

    func testParseJSONToDict_invalidJSONReturnsNil() {
        XCTAssertNil(parseJSONToDict("{not json"))
    }

    func testParseJSONToDict_arrayReturnsNil() {
        // Top-level arrays are not dictionaries.
        XCTAssertNil(parseJSONToDict("[1,2,3]"))
    }

    func testParseJSONToDict_nestedObject() {
        let result = parseJSONToDict("{\"outer\":{\"inner\":42}}")
        let inner = result?["outer"] as? [String: Any]
        XCTAssertEqual(inner?["inner"] as? Int, 42)
    }

    func testParseJSONToDict_unicodeContent() {
        let result = parseJSONToDict("{\"name\":\"中文\"}")
        XCTAssertEqual(result?["name"] as? String, "中文")
    }

    func testParseJSONToDict_emptyObject() {
        let result = parseJSONToDict("{}")
        XCTAssertEqual(result?.count, 0)
    }

    // MARK: - parseLLMResponseAsObject

    func testParseLLMResponseAsObject_plainJSON() {
        let result = parseLLMResponseAsObject("{\"k\":\"v\"}")
        XCTAssertEqual(result?["k"] as? String, "v")
    }

    func testParseLLMResponseAsObject_fencedJSON() {
        let result = parseLLMResponseAsObject("```\n{\"k\":1}\n```")
        XCTAssertEqual(result?["k"] as? Int, 1)
    }

    func testParseLLMResponseAsObject_fencedJSONWithLanguageTag() {
        let result = parseLLMResponseAsObject("```json\n{\"k\":2}\n```")
        XCTAssertEqual(result?["k"] as? Int, 2)
    }

    func testParseLLMResponseAsObject_trimsSurroundingWhitespace() {
        let result = parseLLMResponseAsObject("\n   {\"k\":3}   \n")
        XCTAssertEqual(result?["k"] as? Int, 3)
    }

    func testParseLLMResponseAsObject_emptyStringReturnsNil() {
        XCTAssertNil(parseLLMResponseAsObject(""))
    }

    func testParseLLMResponseAsObject_onlyWhitespaceReturnsNil() {
        XCTAssertNil(parseLLMResponseAsObject("   \n\t  "))
    }

    func testParseLLMResponseAsObject_invalidJSONReturnsNil() {
        XCTAssertNil(parseLLMResponseAsObject("```json\n{not valid\n```"))
    }

    func testParseLLMResponseAsObject_arrayReturnsNil() {
        // Top-level arrays are not objects.
        XCTAssertNil(parseLLMResponseAsObject("[1,2,3]"))
    }

    // MARK: - parseLLMResponseAsArray

    func testParseLLMResponseAsArray_plainArray() {
        let result = parseLLMResponseAsArray("[{\"a\":1},{\"b\":2}]")
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?[0]["a"] as? Int, 1)
        XCTAssertEqual(result?[1]["b"] as? Int, 2)
    }

    func testParseLLMResponseAsArray_fencedArrayOfObjects() {
        // Return type is [[String: Any]], so elements must be JSON objects.
        let result = parseLLMResponseAsArray("```\n[{\"a\":1},{\"b\":2},{\"c\":3}]\n```")
        XCTAssertEqual(result?.count, 3)
        XCTAssertEqual(result?[0]["a"] as? Int, 1)
        XCTAssertEqual(result?[2]["c"] as? Int, 3)
    }

    func testParseLLMResponseAsArray_primitiveArrayReturnsNil() {
        // Top-level array of primitives cannot be cast to [[String: Any]].
        XCTAssertNil(parseLLMResponseAsArray("[1,2,3]"))
    }

    func testParseLLMResponseAsArray_fencedArrayWithLanguageTag() {
        let result = parseLLMResponseAsArray("```json\n[{\"x\":true}]\n```")
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?[0]["x"] as? Bool, true)
    }

    func testParseLLMResponseAsArray_emptyArray() {
        let result = parseLLMResponseAsArray("[]")
        XCTAssertEqual(result?.count, 0)
    }

    func testParseLLMResponseAsArray_emptyStringReturnsNil() {
        XCTAssertNil(parseLLMResponseAsArray(""))
    }

    func testParseLLMResponseAsArray_objectReturnsNil() {
        // Top-level objects are not arrays.
        XCTAssertNil(parseLLMResponseAsArray("{\"a\":1}"))
    }

    func testParseLLMResponseAsArray_invalidJSONReturnsNil() {
        XCTAssertNil(parseLLMResponseAsArray("[not valid"))
    }

    func testParseLLMResponseAsArray_onlyWhitespaceReturnsNil() {
        XCTAssertNil(parseLLMResponseAsArray("  \n\t "))
    }

    // MARK: - Integration: helpers compose the documented 3-step pipeline

    func testPipeline_composeExtractThenParse() {
        // Simulates the evolver pipeline: extract text → strip fences → parse JSON.
        let response: [String: Any] = [
            "content": [
                ["type": "text", "text": "```json\n{\"action\":\"update\",\"reason\":\"x\"}\n```"]
            ]
        ]
        let text = extractFirstTextFromResponse(response)
        guard let parsed = parseLLMResponseAsObject(text) else {
            XCTFail("Pipeline should yield a valid object")
            return
        }
        XCTAssertEqual(parsed["action"] as? String, "update")
        XCTAssertEqual(parsed["reason"] as? String, "x")
    }
}

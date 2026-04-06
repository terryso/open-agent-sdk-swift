import XCTest
@testable import OpenAgentSDK

final class TokenUsageTests: XCTestCase {

    // MARK: - Initialization

    func testInit_defaultOptionalsNil() {
        let usage = TokenUsage(inputTokens: 10, outputTokens: 5)
        XCTAssertEqual(usage.inputTokens, 10)
        XCTAssertEqual(usage.outputTokens, 5)
        XCTAssertNil(usage.cacheCreationInputTokens)
        XCTAssertNil(usage.cacheReadInputTokens)
    }

    func testInit_withOptionals() {
        let usage = TokenUsage(
            inputTokens: 100,
            outputTokens: 50,
            cacheCreationInputTokens: 20,
            cacheReadInputTokens: 10
        )
        XCTAssertEqual(usage.cacheCreationInputTokens, 20)
        XCTAssertEqual(usage.cacheReadInputTokens, 10)
    }

    // MARK: - totalTokens

    func testTotalTokens_basic() {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        XCTAssertEqual(usage.totalTokens, 150)
    }

    func testTotalTokens_zeroInput() {
        let usage = TokenUsage(inputTokens: 0, outputTokens: 50)
        XCTAssertEqual(usage.totalTokens, 50)
    }

    func testTotalTokens_zeroBoth() {
        let usage = TokenUsage(inputTokens: 0, outputTokens: 0)
        XCTAssertEqual(usage.totalTokens, 0)
    }

    // MARK: - Addition

    func testAddition_bothOptionalsNil() {
        let a = TokenUsage(inputTokens: 10, outputTokens: 5)
        let b = TokenUsage(inputTokens: 20, outputTokens: 10)
        let sum = a + b
        XCTAssertEqual(sum.inputTokens, 30)
        XCTAssertEqual(sum.outputTokens, 15)
        XCTAssertNil(sum.cacheCreationInputTokens)
        XCTAssertNil(sum.cacheReadInputTokens)
    }

    func testAddition_bothOptionalsPresent() {
        let a = TokenUsage(inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: 3, cacheReadInputTokens: 2)
        let b = TokenUsage(inputTokens: 20, outputTokens: 10, cacheCreationInputTokens: 7, cacheReadInputTokens: 8)
        let sum = a + b
        XCTAssertEqual(sum.cacheCreationInputTokens, 10)
        XCTAssertEqual(sum.cacheReadInputTokens, 10)
    }

    func testAddition_leftOptionalOnly() {
        let a = TokenUsage(inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: 3)
        let b = TokenUsage(inputTokens: 20, outputTokens: 10)
        let sum = a + b
        XCTAssertEqual(sum.cacheCreationInputTokens, 3)
        XCTAssertNil(sum.cacheReadInputTokens)
    }

    func testAddition_rightOptionalOnly() {
        let a = TokenUsage(inputTokens: 10, outputTokens: 5)
        let b = TokenUsage(inputTokens: 20, outputTokens: 10, cacheReadInputTokens: 4)
        let sum = a + b
        XCTAssertNil(sum.cacheCreationInputTokens)
        XCTAssertEqual(sum.cacheReadInputTokens, 4)
    }

    func testAddition_isCommutative() {
        let a = TokenUsage(inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: 3)
        let b = TokenUsage(inputTokens: 20, outputTokens: 10, cacheCreationInputTokens: 7)
        XCTAssertEqual(a + b, b + a)
    }

    // MARK: - Equality

    func testEquality_same() {
        let a = TokenUsage(inputTokens: 10, outputTokens: 5)
        let b = TokenUsage(inputTokens: 10, outputTokens: 5)
        XCTAssertEqual(a, b)
    }

    func testEquality_differentInputTokens() {
        let a = TokenUsage(inputTokens: 10, outputTokens: 5)
        let b = TokenUsage(inputTokens: 20, outputTokens: 5)
        XCTAssertNotEqual(a, b)
    }

    func testEquality_differentOptionals() {
        let a = TokenUsage(inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: 1)
        let b = TokenUsage(inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: 2)
        XCTAssertNotEqual(a, b)
    }

    func testEquality_nilVsNonNil() {
        let a = TokenUsage(inputTokens: 10, outputTokens: 5)
        let b = TokenUsage(inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: 1)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Codable

    func testEncode_snakeCaseKeys() throws {
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: 10, cacheReadInputTokens: 5)
        let data = try JSONEncoder().encode(usage)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["input_tokens"] as? Int, 100)
        XCTAssertEqual(json["output_tokens"] as? Int, 50)
        XCTAssertEqual(json["cache_creation_input_tokens"] as? Int, 10)
        XCTAssertEqual(json["cache_read_input_tokens"] as? Int, 5)
    }

    func testDecode_snakeCaseKeys() throws {
        let json = """
        {"input_tokens": 200, "output_tokens": 100}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: json)
        XCTAssertEqual(decoded.inputTokens, 200)
        XCTAssertEqual(decoded.outputTokens, 100)
        XCTAssertNil(decoded.cacheCreationInputTokens)
        XCTAssertNil(decoded.cacheReadInputTokens)
    }

    func testDecode_partialOptionals() throws {
        let json = """
        {"input_tokens": 100, "output_tokens": 50, "cache_creation_input_tokens": 5}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: json)
        XCTAssertEqual(decoded.cacheCreationInputTokens, 5)
        XCTAssertNil(decoded.cacheReadInputTokens)
    }

    func testRoundTrip_withOptionals() throws {
        let original = TokenUsage(inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: 10, cacheReadInputTokens: 5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testRoundTrip_withoutOptionals() throws {
        let original = TokenUsage(inputTokens: 100, outputTokens: 50)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

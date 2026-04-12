import XCTest
@testable import OpenAgentSDK

// MARK: - TokenEstimator Tests

/// ATDD RED PHASE: Tests for Story 13.3 -- Session Memory Compression Layer.
/// TokenEstimator provides language-aware token estimation for Claude models.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Utils/TokenEstimator.swift` is created with `TokenEstimator` enum + `estimate(_:)` static method
/// TDD Phase: RED (feature not implemented yet)
final class TokenEstimatorTests: XCTestCase {

    // MARK: - AC5: ASCII Token Estimation

    /// AC5 [P0]: Pure ASCII text uses 1 token = 4 characters.
    func testEstimate_PureASCII_ReturnsCorrectTokenCount() {
        // "Hello, World!" = 13 characters, 13/4 = 3 (integer division)
        let text = "Hello, World!"
        let tokens = TokenEstimator.estimate(text)

        XCTAssertEqual(tokens, text.utf8.count / 4,
                       "Pure ASCII should use 1 token per 4 characters: expected \(text.utf8.count / 4), got \(tokens)")
    }

    /// AC5 [P0]: Empty string returns 0 tokens.
    func testEstimate_EmptyString_ReturnsZero() {
        let tokens = TokenEstimator.estimate("")

        XCTAssertEqual(tokens, 0,
                       "Empty string should return 0 tokens")
    }

    /// AC5 [P1]: Single ASCII character returns 0 tokens (1/4 = 0 in integer division).
    func testEstimate_SingleASCIIChar_ReturnsZero() {
        let tokens = TokenEstimator.estimate("a")

        XCTAssertEqual(tokens, 0,
                       "Single ASCII char (1/4 = 0) should return 0 tokens")
    }

    /// AC5 [P1]: Exactly 4 ASCII characters returns 1 token.
    func testEstimate_FourASCIIChars_ReturnsOne() {
        let tokens = TokenEstimator.estimate("abcd")

        XCTAssertEqual(tokens, 1,
                       "4 ASCII chars should return 1 token")
    }

    /// AC5 [P0]: Long ASCII text returns correct estimate.
    func testEstimate_LongASCII_ReturnsCorrectCount() {
        let text = String(repeating: "a", count: 4000) // 4000 chars -> 1000 tokens
        let tokens = TokenEstimator.estimate(text)

        XCTAssertEqual(tokens, 1000,
                       "4000 ASCII chars should estimate 1000 tokens")
    }

    // MARK: - AC5: CJK Token Estimation

    /// AC5 [P0]: Pure CJK text uses 1 token = 1.5 characters.
    func testEstimate_PureCJK_ReturnsCorrectTokenCount() {
        // 3 CJK characters: 3 * 1.5 = 4.5, rounded = 4 or 5
        let text = "你好世"
        let tokens = TokenEstimator.estimate(text)

        // 3 CJK chars * 1.5 = 4.5 -> should be at least 4
        XCTAssertGreaterThanOrEqual(tokens, 4,
                                    "3 CJK chars should estimate at least 4 tokens (3 * 1.5 = 4.5)")
        XCTAssertLessThanOrEqual(tokens, 5,
                                 "3 CJK chars should estimate at most 5 tokens")
    }

    /// AC5 [P0]: Single CJK character uses ~1.5 tokens (rounded to 1 or 2).
    func testEstimate_SingleCJKChar_ReturnsApproximatelyOnePointFive() {
        let text = "中"
        let tokens = TokenEstimator.estimate(text)

        // 1 CJK char * 1.5 = 1.5 -> rounded to 1 or 2
        XCTAssertGreaterThanOrEqual(tokens, 1,
                                    "1 CJK char should estimate at least 1 token")
        XCTAssertLessThanOrEqual(tokens, 2,
                                 "1 CJK char should estimate at most 2 tokens")
    }

    /// AC5 [P1]: Long CJK text returns correct estimate.
    func testEstimate_LongCJK_ReturnsCorrectCount() {
        // 100 CJK characters -> ~150 tokens
        let text = String(repeating: "中", count: 100)
        let tokens = TokenEstimator.estimate(text)

        XCTAssertEqual(tokens, 150,
                       "100 CJK chars should estimate 150 tokens (100 * 1.5)")
    }

    // MARK: - AC5: Mixed Text Estimation

    /// AC5 [P0]: Mixed ASCII + CJK text is estimated by segmenting and summing.
    func testEstimate_MixedASCIIAndCJK_SegmentsAndSums() {
        // "Hello" = 5 ASCII chars -> 5/4 = 1 token
        // "你好" = 2 CJK chars -> 2 * 1.5 = 3 tokens
        // Total: 1 + 3 = 4 tokens
        let text = "Hello你好"
        let tokens = TokenEstimator.estimate(text)

        // ASCII portion: 5 chars / 4 = 1 token
        // CJK portion: 2 chars * 1.5 = 3 tokens
        // Total: ~4 tokens
        XCTAssertEqual(tokens, 4,
                       "'Hello你好' should estimate 4 tokens (5/4 + 2*1.5 = 1 + 3)")
    }

    /// AC5 [P1]: Mixed text with multiple CJK/ASCII segments.
    func testEstimate_MultipleSegments_SumsCorrectly() {
        // "AB" = 2 ASCII -> 2/4 = 0 tokens
        // "中" = 1 CJK -> 1.5 tokens -> 1 (or 2)
        // "CD" = 2 ASCII -> 2/4 = 0 tokens
        // "文" = 1 CJK -> 1.5 tokens -> 1 (or 2)
        let text = "AB中CD文"
        let tokens = TokenEstimator.estimate(text)

        // At minimum should count CJK characters
        XCTAssertGreaterThan(tokens, 0,
                             "Mixed text with CJK should estimate more than 0 tokens")
    }

    /// AC5 [P1]: Text with numbers (ASCII) estimated correctly.
    func testEstimate_NumbersTreatedAsASCII() {
        let text = "12345678" // 8 ASCII digits -> 2 tokens
        let tokens = TokenEstimator.estimate(text)

        XCTAssertEqual(tokens, 2,
                       "8 ASCII digits should estimate 2 tokens (8/4)")
    }

    /// AC5 [P2]: Korean characters (Hangul) estimated as CJK-equivalent.
    func testEstimate_HangulCharacters_EstimatedAsCJK() {
        let text = "한글" // 2 Hangul characters
        let tokens = TokenEstimator.estimate(text)

        // Hangul is in Unicode range similar to CJK, should be estimated similarly
        XCTAssertGreaterThan(tokens, 0,
                             "Hangul characters should estimate more than 0 tokens")
    }

    // MARK: - AC5: Edge Cases

    /// AC5 [P2]: Whitespace-only text estimated as ASCII.
    func testEstimate_WhitespaceOnly_TreatedAsASCII() {
        let text = "    " // 4 spaces -> 1 token
        let tokens = TokenEstimator.estimate(text)

        XCTAssertEqual(tokens, 1,
                       "4 whitespace chars should estimate 1 token")
    }

    /// AC5 [P2]: Emoji estimated (not CJK, not ASCII -- should still return positive).
    func testEstimate_Emoji_ReturnsPositiveTokens() {
        let text = "🎉" // Emoji
        let tokens = TokenEstimator.estimate(text)

        XCTAssertGreaterThan(tokens, 0,
                             "Emoji should estimate at least 1 token")
    }
}

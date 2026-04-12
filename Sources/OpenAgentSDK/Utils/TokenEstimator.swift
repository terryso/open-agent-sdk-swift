import Foundation

/// Language-aware token estimation for Claude models.
///
/// Uses character-based heuristics to estimate token counts without external
/// dependencies. Provides reasonable approximations for budget enforcement:
/// - **ASCII characters:** 1 token per 4 characters
/// - **CJK characters:** 1 token per 1.5 characters
/// - **Mixed text:** Segmented by character category, estimated, then summed
///
/// Zero instances -- purely a namespace for the static `estimate(_:)` method.
enum TokenEstimator {

    /// Estimate the token count for a given text string.
    ///
    /// The estimation segments the text into ASCII and CJK (Chinese/Japanese/Korean)
    /// runs, applies per-category ratios, and sums the results.
    ///
    /// - Parameter text: The text to estimate tokens for.
    /// - Returns: An approximate token count (always >= 0).
    public static func estimate(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        var otherUtf8Bytes = 0
        var cjkCharCount = 0

        for scalar in text.unicodeScalars {
            let value = scalar.value
            // CJK Unified Ideographs: U+4E00..U+9FFF
            // CJK Unified Ideographs Extension A: U+3400..U+4DBF
            // CJK Compatibility Ideographs: U+F900..U+FAFF
            // Hangul Syllables: U+AC00..U+D7AF
            // Hiragana: U+3040..U+309F
            // Katakana: U+30A0..U+30FF
            if (value >= 0x4E00 && value <= 0x9FFF) ||
               (value >= 0x3400 && value <= 0x4DBF) ||
               (value >= 0xF900 && value <= 0xFAFF) ||
               (value >= 0xAC00 && value <= 0xD7AF) ||
               (value >= 0x3040 && value <= 0x309F) ||
               (value >= 0x30A0 && value <= 0x30FF) {
                cjkCharCount += 1
            } else {
                // For all other characters (ASCII, emoji, Cyrillic, etc.),
                // count their UTF-8 byte representation. This ensures that
                // multi-byte characters like emoji still produce positive
                // token estimates (e.g., a 4-byte emoji = 1 token).
                otherUtf8Bytes += scalar.utf8.count
            }
        }

        let otherTokens = otherUtf8Bytes / 4
        let cjkTokens = Int(Double(cjkCharCount) * 1.5)

        return otherTokens + cjkTokens
    }
}

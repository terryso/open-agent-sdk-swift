import XCTest
@testable import OpenAgentSDK

final class ThinkingConfigTests: XCTestCase {

    // MARK: - Case Construction

    func testAdaptive() {
        let config = ThinkingConfig.adaptive
        if case .adaptive = config {
            // pass
        } else {
            XCTFail("Expected .adaptive case")
        }
    }

    func testEnabled() {
        let config = ThinkingConfig.enabled(budgetTokens: 10000)
        if case .enabled(let tokens) = config {
            XCTAssertEqual(tokens, 10000)
        } else {
            XCTFail("Expected .enabled case")
        }
    }

    func testDisabled() {
        let config = ThinkingConfig.disabled
        if case .disabled = config {
            // pass
        } else {
            XCTFail("Expected .disabled case")
        }
    }

    // MARK: - Equatable

    func testEquality_adaptive() {
        XCTAssertEqual(ThinkingConfig.adaptive, ThinkingConfig.adaptive)
    }

    func testEquality_enabled_sameBudget() {
        XCTAssertEqual(
            ThinkingConfig.enabled(budgetTokens: 5000),
            ThinkingConfig.enabled(budgetTokens: 5000)
        )
    }

    func testInequality_enabled_differentBudget() {
        XCTAssertNotEqual(
            ThinkingConfig.enabled(budgetTokens: 5000),
            ThinkingConfig.enabled(budgetTokens: 10000)
        )
    }

    func testEquality_disabled() {
        XCTAssertEqual(ThinkingConfig.disabled, ThinkingConfig.disabled)
    }

    func testInequality_differentCases() {
        XCTAssertNotEqual(ThinkingConfig.adaptive, ThinkingConfig.disabled)
        XCTAssertNotEqual(ThinkingConfig.adaptive, ThinkingConfig.enabled(budgetTokens: 10000))
        XCTAssertNotEqual(ThinkingConfig.disabled, ThinkingConfig.enabled(budgetTokens: 10000))
    }

    // MARK: - Sendable

    func testSendable() {
        let configs: [ThinkingConfig] = [.adaptive, .enabled(budgetTokens: 1000), .disabled]
        // Should compile if Sendable
        _ = configs
    }

    // MARK: - Budget Tokens Edge Cases

    func testEnabled_zeroBudget() {
        let config = ThinkingConfig.enabled(budgetTokens: 0)
        if case .enabled(let tokens) = config {
            XCTAssertEqual(tokens, 0)
        } else {
            XCTFail("Expected .enabled case")
        }
    }

    func testEnabled_largeBudget() {
        let config = ThinkingConfig.enabled(budgetTokens: 1_000_000)
        if case .enabled(let tokens) = config {
            XCTAssertEqual(tokens, 1_000_000)
        } else {
            XCTFail("Expected .enabled case")
        }
    }

    // MARK: - Exhaustive Switch

    func testExhaustiveSwitch() {
        let configs: [ThinkingConfig] = [.adaptive, .enabled(budgetTokens: 100), .disabled]
        for config in configs {
            switch config {
            case .adaptive:
                break
            case .enabled:
                break
            case .disabled:
                break
            }
        }
    }

    // MARK: - Validation

    func testValidate_enabledZeroBudget_throws() {
        let config = ThinkingConfig.enabled(budgetTokens: 0)
        XCTAssertThrowsError(try config.validate()) { error in
            guard let sdkError = error as? SDKError,
                  case .invalidConfiguration(let msg) = sdkError else {
                XCTFail("Expected SDKError.invalidConfiguration, got \(error)")
                return
            }
            XCTAssertTrue(msg.contains("positive"),
                          "Error message should mention 'positive', got: \(msg)")
        }
    }

    func testValidate_enabledNegativeBudget_throws() {
        let config = ThinkingConfig.enabled(budgetTokens: -5)
        XCTAssertThrowsError(try config.validate()) { error in
            guard let sdkError = error as? SDKError,
                  case .invalidConfiguration = sdkError else {
                XCTFail("Expected SDKError.invalidConfiguration, got \(error)")
                return
            }
        }
    }

    func testValidate_enabledPositiveBudget_succeeds() {
        let config = ThinkingConfig.enabled(budgetTokens: 10000)
        XCTAssertNoThrow(try config.validate(),
                         "Positive budgetTokens should not throw")
    }

    func testValidate_adaptive_succeeds() {
        XCTAssertNoThrow(try ThinkingConfig.adaptive.validate(),
                         ".adaptive should not throw")
    }

    func testValidate_disabled_succeeds() {
        XCTAssertNoThrow(try ThinkingConfig.disabled.validate(),
                         ".disabled should not throw")
    }
}

import XCTest
@testable import OpenAgentSDK

// MARK: - AC1, AC2, AC5: RetryConfig Defaults

/// ATDD RED PHASE: Tests for Story 2.4 — RetryConfig and retry utility unit tests.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `Utils/Retry.swift` is created with RetryConfig, isRetryableError, getRetryDelay, withRetry
/// TDD Phase: RED (feature not implemented yet)
final class RetryConfigTests: XCTestCase {

    // MARK: - RetryConfig Defaults

    /// [P1]: RetryConfig.default has maxRetries = 3 (NFR15).
    func testDefaultMaxRetriesIsThree() throws {
        let config = RetryConfig.default
        XCTAssertEqual(config.maxRetries, 3,
                       "Default maxRetries should be 3 per NFR15")
    }

    /// [P1]: RetryConfig.default has baseDelayMs = 2000.
    func testDefaultBaseDelayMs() throws {
        let config = RetryConfig.default
        XCTAssertEqual(config.baseDelayMs, 2000,
                       "Default baseDelayMs should be 2000ms")
    }

    /// [P1]: RetryConfig.default has maxDelayMs = 30000.
    func testDefaultMaxDelayMs() throws {
        let config = RetryConfig.default
        XCTAssertEqual(config.maxDelayMs, 30000,
                       "Default maxDelayMs should be 30000ms")
    }

    /// [P1]: RetryConfig.default has correct retryable status codes.
    func testDefaultRetryableStatusCodes() throws {
        let config = RetryConfig.default
        XCTAssertTrue(config.retryableStatusCodes.contains(429),
                      "429 (rate limit) should be retryable")
        XCTAssertTrue(config.retryableStatusCodes.contains(500),
                      "500 (internal error) should be retryable")
        XCTAssertTrue(config.retryableStatusCodes.contains(502),
                      "502 (bad gateway) should be retryable")
        XCTAssertTrue(config.retryableStatusCodes.contains(503),
                      "503 (service unavailable) should be retryable")
        XCTAssertTrue(config.retryableStatusCodes.contains(529),
                      "529 (overloaded) should be retryable")
        XCTAssertEqual(config.retryableStatusCodes.count, 5,
                       "Should have exactly 5 retryable status codes")
    }

    /// [P1]: Custom RetryConfig values are respected.
    func testCustomRetryConfig() throws {
        let config = RetryConfig(
            maxRetries: 5,
            baseDelayMs: 500,
            maxDelayMs: 10000,
            retryableStatusCodes: [429, 500]
        )
        XCTAssertEqual(config.maxRetries, 5)
        XCTAssertEqual(config.baseDelayMs, 500)
        XCTAssertEqual(config.maxDelayMs, 10000)
        XCTAssertEqual(config.retryableStatusCodes.count, 2)
    }
}

// MARK: - AC1, AC5: isRetryableError

final class IsRetryableErrorTests: XCTestCase {

    /// [P0]: HTTP 429 (rate limit) is retryable.
    func testHTTP429IsRetryable() {
        let error = SDKError.apiError(statusCode: 429, message: "Rate limit exceeded")
        XCTAssertTrue(isRetryableError(error),
                      "HTTP 429 should be retryable")
    }

    /// [P0]: HTTP 500 (internal server error) is retryable.
    func testHTTP500IsRetryable() {
        let error = SDKError.apiError(statusCode: 500, message: "Internal server error")
        XCTAssertTrue(isRetryableError(error),
                      "HTTP 500 should be retryable")
    }

    /// [P0]: HTTP 502 (bad gateway) is retryable.
    func testHTTP502IsRetryable() {
        let error = SDKError.apiError(statusCode: 502, message: "Bad gateway")
        XCTAssertTrue(isRetryableError(error),
                      "HTTP 502 should be retryable")
    }

    /// [P0]: HTTP 503 (service unavailable) is retryable.
    func testHTTP503IsRetryable() {
        let error = SDKError.apiError(statusCode: 503, message: "Service unavailable")
        XCTAssertTrue(isRetryableError(error),
                      "HTTP 503 should be retryable")
    }

    /// [P0]: HTTP 529 (overloaded) is retryable.
    func testHTTP529IsRetryable() {
        let error = SDKError.apiError(statusCode: 529, message: "Overloaded")
        XCTAssertTrue(isRetryableError(error),
                      "HTTP 529 should be retryable")
    }

    /// [P0]: HTTP 400 (bad request) is NOT retryable (AC5).
    func testHTTP400IsNotRetryable() {
        let error = SDKError.apiError(statusCode: 400, message: "Bad request")
        XCTAssertFalse(isRetryableError(error),
                       "HTTP 400 should NOT be retryable")
    }

    /// [P0]: HTTP 401 (unauthorized) is NOT retryable (AC5).
    func testHTTP401IsNotRetryable() {
        let error = SDKError.apiError(statusCode: 401, message: "Unauthorized")
        XCTAssertFalse(isRetryableError(error),
                       "HTTP 401 should NOT be retryable")
    }

    /// [P0]: HTTP 403 (forbidden) is NOT retryable (AC5).
    func testHTTP403IsNotRetryable() {
        let error = SDKError.apiError(statusCode: 403, message: "Forbidden")
        XCTAssertFalse(isRetryableError(error),
                       "HTTP 403 should NOT be retryable")
    }

    /// [P0]: Non-SDKError types are NOT retryable.
    func testNonSDKErrorIsNotRetryable() {
        let error = NSError(domain: "test", code: -1, userInfo: nil)
        XCTAssertFalse(isRetryableError(error),
                       "Non-SDKError types should NOT be retryable")
    }
}

// MARK: - getRetryDelay

final class GetRetryDelayTests: XCTestCase {

    /// [P1]: Exponential backoff — attempt 1 delay > attempt 0 delay.
    func testExponentialBackoffIncreases() {
        // Use a fixed config without jitter for deterministic testing.
        // Since jitter is random, we test the general pattern over multiple samples.
        // getRetryDelay includes jitter, so we test that higher attempts tend to produce higher delays.
        let config = RetryConfig(
            maxRetries: 3,
            baseDelayMs: 2000,
            maxDelayMs: 30000,
            retryableStatusCodes: [429]
        )

        // The base delay without jitter is: baseDelayMs * 2^attempt
        // attempt 0: 2000ms, attempt 1: 4000ms, attempt 2: 8000ms
        // With +/-25% jitter, the relationship should still hold on average.
        // For deterministic test, we verify the delay is in a reasonable range.
        let delay0 = getRetryDelay(attempt: 0, config: config)
        let delay1 = getRetryDelay(attempt: 1, config: config)
        let delay2 = getRetryDelay(attempt: 2, config: config)

        // attempt 0: ~2000ms +/- 25% = 1500..2500ms => 1.5B..2.5B nanoseconds
        XCTAssertGreaterThan(delay0, 1_000_000_000,
                             "Attempt 0 delay should be > 1s")
        XCTAssertLessThan(delay0, 3_000_000_000,
                          "Attempt 0 delay should be < 3s")

        // attempt 1: ~4000ms +/- 25% = 3000..5000ms => 3B..5B nanoseconds
        XCTAssertGreaterThan(delay1, 2_500_000_000,
                             "Attempt 1 delay should be > 2.5s")
        XCTAssertLessThan(delay1, 5_500_000_000,
                          "Attempt 1 delay should be < 5.5s")

        // attempt 2: ~8000ms +/- 25% = 6000..10000ms => 6B..10B nanoseconds
        XCTAssertGreaterThan(delay2, 5_000_000_000,
                             "Attempt 2 delay should be > 5s")
        XCTAssertLessThan(delay2, 11_000_000_000,
                          "Attempt 2 delay should be < 11s")
    }

    /// [P1]: Delay does not exceed maxDelayMs.
    func testDelayDoesNotExceedMax() {
        let config = RetryConfig(
            maxRetries: 10,
            baseDelayMs: 2000,
            maxDelayMs: 5000,
            retryableStatusCodes: [429]
        )

        // Even at high attempt numbers, delay should not exceed maxDelayMs
        for attempt in 0...20 {
            let delay = getRetryDelay(attempt: attempt, config: config)
            let maxDelayNs = UInt64(config.maxDelayMs) * 1_000_000
            XCTAssertLessThanOrEqual(delay, maxDelayNs,
                                     "Delay at attempt \(attempt) should not exceed maxDelayMs")
        }
    }

    /// [P1]: Custom config values are respected.
    func testCustomConfigDelay() {
        let config = RetryConfig(
            maxRetries: 3,
            baseDelayMs: 100,
            maxDelayMs: 1000,
            retryableStatusCodes: [429]
        )

        let delay = getRetryDelay(attempt: 0, config: config)
        // base 100ms +/- 25% = 75..125ms = 75M..125M nanoseconds
        XCTAssertGreaterThan(delay, 50_000_000,
                             "Custom base delay should be respected")
        XCTAssertLessThan(delay, 200_000_000,
                          "Custom base delay should not be too high")
    }
}

// MARK: - AC1, AC2, AC5: withRetry

final class WithRetryTests: XCTestCase {

    /// [P0]: Success on first attempt returns immediately.
    func testSuccessOnFirstAttempt() async throws {
        var callCount = 0
        let result = try await withRetry {
            callCount += 1
            return 42
        }
        XCTAssertEqual(result, 42,
                       "Should return the operation result")
        XCTAssertEqual(callCount, 1,
                       "Should call operation exactly once on success")
    }

    /// [P0]: Retryable error x2 then success returns result after retries.
    func testRetryableErrorThenSuccess() async throws {
        // Use fast config to avoid long waits in tests
        let fastConfig = RetryConfig(
            maxRetries: 3,
            baseDelayMs: 1,
            maxDelayMs: 1,
            retryableStatusCodes: [429, 500, 502, 503, 529]
        )

        var callCount = 0
        let result = try await withRetry({
            callCount += 1
            if callCount < 3 {
                throw SDKError.apiError(statusCode: 503, message: "Service unavailable")
            }
            return "success"
        }, retryConfig: fastConfig)
        XCTAssertEqual(result, "success",
                       "Should return success result after retries")
        XCTAssertEqual(callCount, 3,
                       "Should have called operation 3 times (2 failures + 1 success)")
    }

    /// [P0]: Non-retryable error throws immediately without retry (AC5).
    func testNonRetryableErrorThrowsImmediately() async throws {
        let fastConfig = RetryConfig(
            maxRetries: 3,
            baseDelayMs: 1,
            maxDelayMs: 1,
            retryableStatusCodes: [429, 500, 502, 503, 529]
        )

        var callCount = 0
        do {
            _ = try await withRetry({
                callCount += 1
                throw SDKError.apiError(statusCode: 401, message: "Unauthorized")
            }, retryConfig: fastConfig)
            XCTFail("Should have thrown an error")
        } catch let error as SDKError {
            XCTAssertEqual(error, .apiError(statusCode: 401, message: "Unauthorized"),
                           "Should throw the original non-retryable error")
            XCTAssertEqual(callCount, 1,
                           "Should call operation exactly once for non-retryable error")
        }
    }

    /// [P0]: All retries exhausted throws last error (AC1 exhaust).
    func testAllRetriesExhausted() async throws {
        let fastConfig = RetryConfig(
            maxRetries: 3,
            baseDelayMs: 1,
            maxDelayMs: 1,
            retryableStatusCodes: [429, 500, 502, 503, 529]
        )

        var callCount = 0
        do {
            _ = try await withRetry({
                callCount += 1
                throw SDKError.apiError(statusCode: 429, message: "Rate limit")
            }, retryConfig: fastConfig)
            XCTFail("Should have thrown after all retries exhausted")
        } catch let error as SDKError {
            XCTAssertEqual(error, .apiError(statusCode: 429, message: "Rate limit"),
                           "Should throw the last retryable error after exhaustion")
            // maxRetries=3, so 4 attempts total (initial + 3 retries)
            XCTAssertEqual(callCount, 4,
                           "Should attempt maxRetries+1 times (1 initial + 3 retries = 4)")
        }
    }
}

import Foundation

/// Configuration for retry behavior on transient API errors.
///
/// Provides sensible defaults matching NFR15: up to 3 retries with exponential
/// backoff starting at 2 seconds, capped at 30 seconds. Retryable status codes
/// cover the standard transient server errors (429, 500, 502, 503, 529).
public struct RetryConfig: Sendable {
    /// Maximum number of retry attempts (not counting the initial call).
    public let maxRetries: Int

    /// Base delay in milliseconds for exponential backoff.
    public let baseDelayMs: Int

    /// Maximum delay in milliseconds (caps the exponential growth).
    public let maxDelayMs: Int

    /// HTTP status codes that qualify for automatic retry.
    public let retryableStatusCodes: Set<Int>

    /// Default configuration per NFR15.
    public static let `default` = RetryConfig(
        maxRetries: 3,
        baseDelayMs: 2000,
        maxDelayMs: 30000,
        retryableStatusCodes: [429, 500, 502, 503, 529]
    )

    public init(maxRetries: Int = 3, baseDelayMs: Int = 2000, maxDelayMs: Int = 30000, retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 529]) {
        precondition(maxRetries >= 0, "maxRetries must be non-negative")
        precondition(baseDelayMs >= 0, "baseDelayMs must be non-negative")
        precondition(maxDelayMs >= 0, "maxDelayMs must be non-negative")
        self.maxRetries = maxRetries
        self.baseDelayMs = baseDelayMs
        self.maxDelayMs = maxDelayMs
        self.retryableStatusCodes = retryableStatusCodes
    }
}

/// Determine whether an error qualifies for automatic retry.
///
/// Only `SDKError.apiError` with a status code in the configured retryable set
/// is considered retryable. All other errors (including non-SDK errors) are
/// not retried.
///
/// - Parameter error: The error to evaluate.
/// - Parameter config: The retry configuration to use for status code lookup.
///   Defaults to `RetryConfig.default`.
/// - Returns: `true` if the error is retryable, `false` otherwise.
func isRetryableError(
    _ error: Error,
    config: RetryConfig = .default
) -> Bool {
    guard let sdkError = error as? SDKError,
          case .apiError(let statusCode, _) = sdkError else {
        return false
    }
    return config.retryableStatusCodes.contains(statusCode)
}

/// Calculate the delay before the next retry attempt.
///
/// Uses exponential backoff: `baseDelayMs * 2^attempt`, plus a random jitter
/// of +/- 25% to avoid thundering-herd effects. The result is capped at
/// `maxDelayMs`.
///
/// - Parameters:
///   - attempt: The zero-based retry attempt index.
///   - config: The retry configuration. Defaults to `RetryConfig.default`.
/// - Returns: The delay in nanoseconds, suitable for `Task.sleep(nanoseconds:)`.
func getRetryDelay(
    attempt: Int,
    config: RetryConfig = .default
) -> UInt64 {
    let delay = config.baseDelayMs * (1 << attempt)
    let jitterMs = Int(Double(delay) * 0.25 * (Double.random(in: -1...1)))
    let totalMs = max(0, min(delay + jitterMs, config.maxDelayMs))
    return UInt64(totalMs) * 1_000_000
}

/// Execute an async operation with automatic retry on transient errors.
///
/// Wraps the supplied closure and retries it up to `retryConfig.maxRetries`
/// times when an `SDKError.apiError` with a retryable status code is thrown.
/// Non-retryable errors propagate immediately.
///
/// - Parameters:
///   - operation: The async throwing closure to execute.
///   - retryConfig: Retry parameters. Defaults to `RetryConfig.default`.
/// - Returns: The value returned by `operation` on success.
/// - Throws: The last encountered error when all retries are exhausted,
///   or the original error when it is not retryable.
func withRetry<T>(
    _ operation: () async throws -> T,
    retryConfig: RetryConfig = .default
) async throws -> T {
    var lastError: Error?
    for attempt in 0...retryConfig.maxRetries {
        do {
            return try await operation()
        } catch {
            lastError = error
            if !isRetryableError(error, config: retryConfig) || attempt == retryConfig.maxRetries {
                throw error
            }
            let delayNs = getRetryDelay(attempt: attempt, config: retryConfig)
            try await _Concurrency.Task.sleep(nanoseconds: delayNs)
        }
    }
    guard let error = lastError else {
        fatalError("withRetry exited loop without an error — this should be unreachable")
    }
    throw error
}

import XCTest
@testable import OpenAgentSDK

// MARK: - LLMClient Shared Helpers Tests

/// Unit tests for the four shared helpers in
/// `Sources/OpenAgentSDK/API/LLMClient.swift`.
///
/// Coverage map:
/// - `buildJSONPostRequest` (pure): header propagation, timeout defaults,
///   body serialization, serialization failure.
/// - `resolveBaseURL` (pure): nil fallback, valid override, invalid-override
///   fallback.
/// - `validateLLMHTTPResponse` (pure): 2xx acceptance, non-2xx error extraction
///   from JSON body, API-key sanitization, non-HTTP response rejection.
/// - `performLLMRequest` (uses URLSession): success path, `URLError.timedOut`
///   → status 408, other URLError → status 0, API-key sanitization in error.
///
/// Network paths use `URLProtocol` mocks (no real network). The error-injecting
/// mock is local to this file to avoid perturbing `MockURLProtocol` shared by
/// `AnthropicClientTests` / `OpenAIClientTests`.
final class LLMClientTests: XCTestCase {

    // MARK: - Local mock for URLError injection

    /// `URLProtocol` subclass that fails every request with a configured `URLError`.
    ///
    /// Used to exercise `performLLMRequest`'s error path without touching the
    /// network. Unlike `MockURLProtocol` (shared by client tests), this one
    /// only emits errors, so it cannot accidentally regress those suites.
    final class FailingURLProtocol: URLProtocol {
        nonisolated(unsafe) static var errorToThrow: URLError?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let err = FailingURLProtocol.errorToThrow
                ?? URLError(.unknown)
            client?.urlProtocol(self, didFailWithError: err)
        }

        override func stopLoading() {}

        static func reset() {
            errorToThrow = nil
        }
    }

    override func tearDown() {
        FailingURLProtocol.reset()
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - buildJSONPostRequest

    func testBuildJSONPostRequest_setsMethodToPOST() throws {
        let request = try buildJSONPostRequest(
            url: URL(string: "https://example.com/api")!,
            body: ["k": "v"],
            headers: ["X-Custom": "1"]
        )
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testBuildJSONPostRequest_defaultTimeoutIs300() throws {
        let request = try buildJSONPostRequest(
            url: URL(string: "https://example.com/")!,
            body: [:],
            headers: [:]
        )
        XCTAssertEqual(request.timeoutInterval, 300, accuracy: 0.001)
    }

    func testBuildJSONPostRequest_customTimeoutIsApplied() throws {
        let request = try buildJSONPostRequest(
            url: URL(string: "https://example.com/")!,
            body: [:],
            headers: [:],
            timeout: 42
        )
        XCTAssertEqual(request.timeoutInterval, 42, accuracy: 0.001)
    }

    func testBuildJSONPostRequest_allHeadersAreApplied() throws {
        let request = try buildJSONPostRequest(
            url: URL(string: "https://example.com/")!,
            body: [:],
            headers: [
                "Authorization": "Bearer secret",
                "Content-Type": "application/json",
                "X-Custom-Header": "value",
            ]
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom-Header"), "value")
    }

    func testBuildJSONPostRequest_serializesBodyAsJSON() throws {
        let request = try buildJSONPostRequest(
            url: URL(string: "https://example.com/")!,
            body: ["model": "claude-sonnet-4-6", "max_tokens": 100],
            headers: [:]
        )
        let body = try XCTUnwrap(request.httpBody)
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(decoded["model"] as? String, "claude-sonnet-4-6")
        XCTAssertEqual(decoded["max_tokens"] as? Int, 100)
    }

    // Note: `buildJSONPostRequest`'s `catch` branch (for JSONSerialization
    // failure) is effectively unreachable with a `[String: Any]` body — NaN
    // and Inf trigger an Objective-C NSInvalidArgumentException, which Swift
    // cannot catch via `do/catch`. So we don't test that branch directly;
    // the catch is dead defensive code, kept for parity with the function's
    // documented contract.

    // MARK: - resolveBaseURL

    func testResolveBaseURL_returnsDefaultWhenCustomIsNil() {
        let url = resolveBaseURL(custom: nil, default: "https://api.anthropic.com")
        XCTAssertEqual(url.absoluteString, "https://api.anthropic.com")
    }

    func testResolveBaseURL_returnsCustomWhenValid() {
        let url = resolveBaseURL(
            custom: "https://gateway.example.com",
            default: "https://api.anthropic.com"
        )
        XCTAssertEqual(url.absoluteString, "https://gateway.example.com")
    }

    func testResolveBaseURL_fallsBackToDefaultWhenCustomIsInvalid() {
        // "http://[" is malformed IPv6 → URL(string:) returns nil.
        let url = resolveBaseURL(custom: "http://[", default: "https://api.anthropic.com")
        XCTAssertEqual(url.absoluteString, "https://api.anthropic.com")
    }

    func testResolveBaseURL_acceptsCustomWithPort() {
        let url = resolveBaseURL(
            custom: "http://localhost:11434",
            default: "https://api.openai.com"
        )
        XCTAssertEqual(url.absoluteString, "http://localhost:11434")
    }

    // MARK: - validateLLMHTTPResponse

    private func makeHTTPResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com/")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
    }

    func testValidateResponse_accepts200() {
        XCTAssertNoThrow(
            try validateLLMHTTPResponse(
                makeHTTPResponse(statusCode: 200),
                data: nil,
                apiKey: "sk-secret"
            )
        )
    }

    func testValidateResponse_acceptsAll2xx() {
        for code in [201, 204, 299] {
            XCTAssertNoThrow(
                try validateLLMHTTPResponse(
                    makeHTTPResponse(statusCode: code),
                    data: nil,
                    apiKey: "sk-secret"
                ),
                "Status \(code) should be accepted"
            )
        }
    }

    func testValidateResponse_rejects300() {
        XCTAssertThrowsError(
            try validateLLMHTTPResponse(
                makeHTTPResponse(statusCode: 300),
                data: nil,
                apiKey: "sk-secret"
            )
        )
    }

    func testValidateResponse_rejects404AndExtractsErrorMessageFromBody() {
        let body = try! JSONSerialization.data(
            withJSONObject: ["error": ["message": "model not found"]]
        )
        do {
            _ = try validateLLMHTTPResponse(
                makeHTTPResponse(statusCode: 404),
                data: body,
                apiKey: "sk-secret"
            )
            XCTFail("Should have thrown")
        } catch let error as SDKError {
            XCTAssertEqual(error.statusCode, 404)
            XCTAssertEqual(error.message, "model not found")
        } catch {
            XCTFail("Expected SDKError, got \(error)")
        }
    }

    func testValidateResponse_rejects500AndFallsBackToHTTPStatusWhenBodyIsNotJSON() {
        let body = "Internal Server Error".data(using: .utf8)
        do {
            _ = try validateLLMHTTPResponse(
                makeHTTPResponse(statusCode: 500),
                data: body,
                apiKey: "sk-secret"
            )
            XCTFail("Should have thrown")
        } catch let error as SDKError {
            XCTAssertEqual(error.statusCode, 500)
            XCTAssertEqual(error.message, "HTTP 500")
        } catch {
            XCTFail("Expected SDKError, got \(error)")
        }
    }

    func testValidateResponse_fallsBackWhenJSONHasNoErrorMessageField() {
        let body = try! JSONSerialization.data(
            withJSONObject: ["some": ["unrelated": "field"]]
        )
        do {
            _ = try validateLLMHTTPResponse(
                makeHTTPResponse(statusCode: 502),
                data: body,
                apiKey: "sk-secret"
            )
            XCTFail("Should have thrown")
        } catch let error as SDKError {
            XCTAssertEqual(error.message, "HTTP 502")
        } catch {
            XCTFail("Expected SDKError, got \(error)")
        }
    }

    func testValidateResponse_sanitizesApiKeyFromErrorMessage() {
        let apiKey = "sk-test-api-key-12345"
        let body = try! JSONSerialization.data(
            withJSONObject: ["error": ["message": "Auth failed for \(apiKey)"]]
        )
        do {
            _ = try validateLLMHTTPResponse(
                makeHTTPResponse(statusCode: 401),
                data: body,
                apiKey: apiKey
            )
            XCTFail("Should have thrown")
        } catch let error as SDKError {
            XCTAssertFalse(error.message.contains(apiKey),
                           "API key must not appear in error message; got: \(error.message)")
            XCTAssertTrue(error.message.contains("***"))
        } catch {
            XCTFail("Expected SDKError, got \(error)")
        }
    }

    func testValidateResponse_throwsOnNilResponse() {
        XCTAssertThrowsError(
            try validateLLMHTTPResponse(nil, data: nil, apiKey: "sk-secret")
        ) { error in
            guard let sdkError = error as? SDKError else {
                XCTFail("Expected SDKError, got \(error)")
                return
            }
            XCTAssertEqual(sdkError.message, "Invalid response")
        }
    }

    func testValidateResponse_throwsOnNonHTTPResponse() {
        let nonHTTP = URLResponse(
            url: URL(string: "https://example.com/")!,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        XCTAssertThrowsError(
            try validateLLMHTTPResponse(nonHTTP, data: nil, apiKey: "sk-secret")
        ) { error in
            guard let sdkError = error as? SDKError else {
                XCTFail("Expected SDKError, got \(error)")
                return
            }
            XCTAssertEqual(sdkError.message, "Invalid response")
        }
    }

    // MARK: - performLLMRequest: success path

    func testPerformLLMRequest_returnsDataAndResponseOnSuccess() async throws {
        let url = "https://fake.example.com/success"
        let responseBody = "{\"ok\":true}".data(using: .utf8)!
        MockURLProtocol.mockResponses[url] = (
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: responseBody
        )

        let session = makeMockURLSession(protocolClass: MockURLProtocol.self)
        let request = URLRequest(url: URL(string: url)!)

        let (data, response) = try await performLLMRequest(
            request,
            urlSession: session,
            apiKey: "sk-test"
        )
        XCTAssertEqual(data, responseBody)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    // MARK: - performLLMRequest: URLError mapping

    func testPerformLLMRequest_mapsTimedOutToStatus408() async {
        FailingURLProtocol.errorToThrow = URLError(.timedOut)
        let session = makeMockURLSession(protocolClass: FailingURLProtocol.self)
        let request = URLRequest(url: URL(string: "https://fake.example.com/t")!)

        do {
            _ = try await performLLMRequest(request, urlSession: session, apiKey: "sk-test")
            XCTFail("Should have thrown")
        } catch let error as SDKError {
            XCTAssertEqual(error.statusCode, 408,
                           "URLError.timedOut must map to HTTP 408")
        } catch {
            XCTFail("Expected SDKError, got \(error)")
        }
    }

    func testPerformLLMRequest_mapsOtherURLErrorsToStatus0() async {
        // NotConnected, cannotFindHost, etc. should NOT be 408.
        FailingURLProtocol.errorToThrow = URLError(.notConnectedToInternet)
        let session = makeMockURLSession(protocolClass: FailingURLProtocol.self)
        let request = URLRequest(url: URL(string: "https://fake.example.com/x")!)

        do {
            _ = try await performLLMRequest(request, urlSession: session, apiKey: "sk-test")
            XCTFail("Should have thrown")
        } catch let error as SDKError {
            XCTAssertEqual(error.statusCode, 0,
                           "Non-timeout URLError should map to status 0")
        } catch {
            XCTFail("Expected SDKError, got \(error)")
        }
    }

    func testPerformLLMRequest_sanitizesApiKeyFromErrorMessage() async {
        let apiKey = "sk-super-secret-98765"
        FailingURLProtocol.errorToThrow = URLError(
            .timedOut,
            userInfo: [NSLocalizedDescriptionKey: "timed out loading \(apiKey)"]
        )
        let session = makeMockURLSession(protocolClass: FailingURLProtocol.self)
        let request = URLRequest(url: URL(string: "https://fake.example.com/sanitize")!)

        do {
            _ = try await performLLMRequest(request, urlSession: session, apiKey: apiKey)
            XCTFail("Should have thrown")
        } catch let error as SDKError {
            XCTAssertFalse(error.message.contains(apiKey),
                           "API key must not leak into error message; got: \(error.message)")
            XCTAssertTrue(error.message.contains("***"))
        } catch {
            XCTFail("Expected SDKError, got \(error)")
        }
    }

    func testPerformLLMRequest_doesNotSanitizeWhenApiKeyIsEmpty() async {
        // Edge case: empty apiKey must not blank out the whole error message.
        FailingURLProtocol.errorToThrow = URLError(
            .timedOut,
            userInfo: [NSLocalizedDescriptionKey: "network timeout occurred"]
        )
        let session = makeMockURLSession(protocolClass: FailingURLProtocol.self)
        let request = URLRequest(url: URL(string: "https://fake.example.com/empty")!)

        do {
            _ = try await performLLMRequest(request, urlSession: session, apiKey: "")
            XCTFail("Should have thrown")
        } catch let error as SDKError {
            XCTAssertFalse(error.message.isEmpty,
                           "With empty apiKey, message should not be wiped; got: '\(error.message)'")
            XCTAssertEqual(error.statusCode, 408)
        } catch {
            XCTFail("Expected SDKError, got \(error)")
        }
    }
}

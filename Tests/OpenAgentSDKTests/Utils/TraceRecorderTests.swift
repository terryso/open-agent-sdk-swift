import XCTest
@testable import OpenAgentSDK

final class TraceRecorderTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("TraceRecorderTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - File creation and JSONL format

    func testCreatesJSONLFile() async throws {
        let recorder = try TraceRecorder(runId: "test-run", baseURL: tempDir)
        await recorder.record(event: "step_start", payload: ["tool": "Bash"])
        await recorder.close()

        let fileURL = tempDir.appendingPathComponent("test-run/trace.jsonl")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(content.isEmpty)

        let lines = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 1)

        let json = try JSONSerialization.jsonObject(with: lines[0].data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(json["event"] as? String, "step_start")
        XCTAssertEqual(json["tool"] as? String, "Bash")
        XCTAssertNotNil(json["ts"])
    }

    func testAutoTimestampAndEventFields() async throws {
        let recorder = try TraceRecorder(runId: "ts-test", baseURL: tempDir)
        await recorder.record(event: "run_done", payload: ["status": "success"])
        await recorder.close()

        let fileURL = tempDir.appendingPathComponent("ts-test/trace.jsonl")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let json = try JSONSerialization.jsonObject(with: content.data(using: .utf8)!) as! [String: Any]

        let ts = json["ts"] as? String
        XCTAssertNotNil(ts)
        // ISO8601 format should contain date-time separator
        XCTAssertTrue(ts!.contains("T") || ts!.contains("-"))
        XCTAssertEqual(json["event"] as? String, "run_done")
    }

    func testMultipleRecords() async throws {
        let recorder = try TraceRecorder(runId: "multi-test", baseURL: tempDir)
        await recorder.record(event: "step_start", payload: ["tool": "Bash", "toolUseId": "tu_1"])
        await recorder.record(event: "step_done", payload: ["tool": "Bash", "success": true, "toolUseId": "tu_1"])
        await recorder.close()

        let fileURL = tempDir.appendingPathComponent("multi-test/trace.jsonl")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
    }

    // MARK: - Sanitization

    func testSanitizationStripsSensitiveKeys() async throws {
        let recorder = try TraceRecorder(runId: "sanitize-test", baseURL: tempDir)
        await recorder.record(event: "test", payload: [
            "apiKey": "sk-12345",
            "api_key": "secret-key",
            "secret": "my-secret",
            "token": "my-token",
            "password": "my-password",
            "credential": "my-cred",
            "authorization": "Bearer xxx",
            "safe_key": "safe_value"
        ])
        await recorder.close()

        let fileURL = tempDir.appendingPathComponent("sanitize-test/trace.jsonl")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let json = try JSONSerialization.jsonObject(with: content.data(using: .utf8)!) as! [String: Any]

        // Stripped keys should not appear
        XCTAssertNil(json["apiKey"])
        XCTAssertNil(json["api_key"])
        XCTAssertNil(json["secret"])
        XCTAssertNil(json["token"])
        XCTAssertNil(json["password"])
        XCTAssertNil(json["credential"])
        XCTAssertNil(json["authorization"])
        // Safe key should remain
        XCTAssertEqual(json["safe_key"] as? String, "safe_value")
    }

    func testSanitizationRedactsSensitivePatterns() async throws {
        let recorder = try TraceRecorder(runId: "redact-test", baseURL: tempDir)
        await recorder.record(event: "test", payload: [
            "model": "claude-sonnet-4-6",
            "key_input": "sk-ant-apikey12345",
            "another_input": "key-abcdefg"
        ])
        await recorder.close()

        let fileURL = tempDir.appendingPathComponent("redact-test/trace.jsonl")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let json = try JSONSerialization.jsonObject(with: content.data(using: .utf8)!) as! [String: Any]

        XCTAssertEqual(json["model"] as? String, "claude-sonnet-4-6")
        XCTAssertEqual(json["key_input"] as? String, "[REDACTED]")
        XCTAssertEqual(json["another_input"] as? String, "[REDACTED]")
    }

    // MARK: - Close and cleanup

    func testCloseIsIdempotent() async throws {
        let recorder = try TraceRecorder(runId: "close-test", baseURL: tempDir)
        await recorder.record(event: "test", payload: [:])
        await recorder.close()
        await recorder.close() // Should not crash
    }

    // MARK: - Default base URL

    func testDefaultBaseURL() {
        let url = TraceRecorder.defaultBaseURL()
        XCTAssertTrue(url.path.hasSuffix(".open-agent-sdk/traces"))
    }
}

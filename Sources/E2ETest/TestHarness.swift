import Foundation
import OpenAgentSDK

// MARK: - Test Counters

struct Stats: Sendable {
    nonisolated(unsafe) static var total = 0
    nonisolated(unsafe) static var passed = 0
    nonisolated(unsafe) static var failed = 0
}

func pass(_ name: String) {
    Stats.total += 1
    Stats.passed += 1
    print("  [PASS] \(name)")
}

func fail(_ name: String, _ reason: String = "") {
    Stats.total += 1
    Stats.failed += 1
    print("  [FAIL] \(name)\(reason.isEmpty ? "" : " — \(reason)")")
}

func section(_ title: String) {
    print("\n--- \(title) ---")
}

// MARK: - .env File Loader

func loadDotEnv() -> [String: String] {
    let envPath = FileManager.default.currentDirectoryPath + "/.env"
    guard let content = try? String(contentsOfFile: envPath, encoding: .utf8) else { return [:] }
    var env: [String: String] = [:]
    for line in content.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        guard let eqRange = trimmed.range(of: "=") else { continue }
        let key = String(trimmed[..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let value = String(trimmed[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        env[key] = value
    }
    return env
}

func getEnv(_ key: String, from dotEnv: [String: String]) -> String? {
    if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
        return value
    }
    return dotEnv[key]
}

// MARK: - Shared Tool Input Types

struct CalculatorInput: Codable {
    let expression: String
}

struct EchoInput: Codable {
    let message: String
}

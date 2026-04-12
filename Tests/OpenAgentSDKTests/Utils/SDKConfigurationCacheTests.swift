import XCTest
@testable import OpenAgentSDK

// MARK: - SDKConfiguration Cache Params ATDD Tests (Story 12.1)

/// ATDD RED PHASE: Tests for Story 12.1 -- SDKConfiguration cache parameter additions.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `SDKConfiguration` adds `fileCacheMaxEntries`, `fileCacheMaxSizeBytes`, `fileCacheMaxEntrySizeBytes`
/// TDD Phase: RED (feature not implemented yet)
final class SDKConfigurationCacheTests: XCTestCase {

    // MARK: - AC2: SDKConfiguration Cache Parameters

    /// AC2 [P0]: Default cache parameter values match story spec.
    func testSDKConfiguration_DefaultCacheParams() {
        // Given: a default SDKConfiguration
        let config = SDKConfiguration()

        // Then: default values match spec
        XCTAssertEqual(config.fileCacheMaxEntries, 100,
                       "Default fileCacheMaxEntries should be 100")
        XCTAssertEqual(config.fileCacheMaxSizeBytes, 25 * 1024 * 1024,
                       "Default fileCacheMaxSizeBytes should be 25MB")
        XCTAssertEqual(config.fileCacheMaxEntrySizeBytes, 5 * 1024 * 1024,
                       "Default fileCacheMaxEntrySizeBytes should be 5MB")
    }

    /// AC2 [P0]: Custom cache parameter values override defaults.
    func testSDKConfiguration_CustomCacheParams() {
        // Given: a custom SDKConfiguration
        let config = SDKConfiguration(
            apiKey: "sk-test",
            model: "claude-sonnet-4-6",
            baseURL: nil,
            maxTurns: 10,
            maxTokens: 16384,
            fileCacheMaxEntries: 50,
            fileCacheMaxSizeBytes: 10 * 1024 * 1024,
            fileCacheMaxEntrySizeBytes: 2 * 1024 * 1024
        )

        // Then: custom values are used
        XCTAssertEqual(config.fileCacheMaxEntries, 50,
                       "Custom fileCacheMaxEntries should be 50")
        XCTAssertEqual(config.fileCacheMaxSizeBytes, 10 * 1024 * 1024,
                       "Custom fileCacheMaxSizeBytes should be 10MB")
        XCTAssertEqual(config.fileCacheMaxEntrySizeBytes, 2 * 1024 * 1024,
                       "Custom fileCacheMaxEntrySizeBytes should be 2MB")
    }

    /// AC2 [P0]: Equatable auto-synthesis works with new fields.
    func testSDKConfiguration_CacheParams_Equatable() {
        // Given: two configurations with same cache params
        let a = SDKConfiguration(fileCacheMaxEntries: 50,
                                  fileCacheMaxSizeBytes: 10 * 1024 * 1024,
                                  fileCacheMaxEntrySizeBytes: 2 * 1024 * 1024)
        let b = SDKConfiguration(fileCacheMaxEntries: 50,
                                  fileCacheMaxSizeBytes: 10 * 1024 * 1024,
                                  fileCacheMaxEntrySizeBytes: 2 * 1024 * 1024)

        // Then: they are equal
        XCTAssertEqual(a, b,
                       "Configurations with same cache params should be equal")

        // And: different cache params make them unequal
        let c = SDKConfiguration(fileCacheMaxEntries: 100)
        XCTAssertNotEqual(a, c,
                          "Configurations with different cache params should not be equal")
    }

    /// AC2 [P0]: New fields appear in description and debugDescription.
    func testSDKConfiguration_CacheParams_InDescription() {
        // Given: a configuration with custom cache params
        let config = SDKConfiguration(
            fileCacheMaxEntries: 50,
            fileCacheMaxSizeBytes: 10 * 1024 * 1024,
            fileCacheMaxEntrySizeBytes: 2 * 1024 * 1024
        )

        // Then: description includes cache params
        XCTAssertTrue(config.description.contains("fileCacheMaxEntries"),
                      "description should contain fileCacheMaxEntries")
        XCTAssertTrue(config.description.contains("fileCacheMaxSizeBytes"),
                      "description should contain fileCacheMaxSizeBytes")
        XCTAssertTrue(config.description.contains("fileCacheMaxEntrySizeBytes"),
                      "description should contain fileCacheMaxEntrySizeBytes")

        // And: debugDescription also includes them
        XCTAssertTrue(config.debugDescription.contains("fileCacheMaxEntries"),
                      "debugDescription should contain fileCacheMaxEntries")
    }
}

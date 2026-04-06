import XCTest
@testable import OpenAgentSDK

final class EnvUtilsTests: XCTestCase {

    // MARK: - getEnv

    func testGetEnv_existingVariable() {
        setenv("OPENAGENTSDK_TEST_VAR", "hello", 1)
        defer { unsetenv("OPENAGENTSDK_TEST_VAR") }

        let value = getEnv("OPENAGENTSDK_TEST_VAR")
        XCTAssertEqual(value, "hello")
    }

    func testGetEnv_unsetVariable() {
        let value = getEnv("OPENAGENTSDK_DEFINITELY_NOT_SET_XYZ")
        XCTAssertNil(value)
    }

    func testGetEnv_emptyString() {
        setenv("OPENAGENTSDK_TEST_EMPTY", "", 1)
        defer { unsetenv("OPENAGENTSDK_TEST_EMPTY") }

        let value = getEnv("OPENAGENTSDK_TEST_EMPTY")
        XCTAssertNil(value, "Empty values should be treated as nil")
    }

    func testGetEnv_valueWithSpaces() {
        setenv("OPENAGENTSDK_TEST_SPACES", "  hello world  ", 1)
        defer { unsetenv("OPENAGENTSDK_TEST_SPACES") }

        let value = getEnv("OPENAGENTSDK_TEST_SPACES")
        XCTAssertEqual(value, "  hello world  ")
    }
}

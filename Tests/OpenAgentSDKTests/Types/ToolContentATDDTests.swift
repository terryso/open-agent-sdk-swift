import XCTest
@testable import OpenAgentSDK

// MARK: - ToolContent ATDD Tests (Story 17-3)

/// ATDD RED PHASE: Tests for Story 17-3 AC2 -- Typed ToolResult content.
/// All tests assert EXPECTED behavior. They will FAIL until:
///   - `ToolContent` enum is created with `.text`, `.image`, `.resource` cases
///   - `ToolResult` gains `typedContent: [ToolContent]?` property
///   - `ToolResult.content` remains backward-compatible (computed from typedContent or stored)
///   - `ToolExecuteResult` gains `typedContent: [ToolContent]?` property
///   - `ToolContent` conforms to `Sendable` and `Equatable`
/// TDD Phase: RED (feature not implemented yet)
final class ToolContentATDDTests: XCTestCase {

    // MARK: - AC2: ToolContent enum existence

    /// AC2 [P0]: ToolContent.text case exists and holds a String value.
    func testToolContent_TextCase_HoldsString() {
        // Given: TS SDK has TextBlock with text content
        // When: creating a .text ToolContent
        let content = ToolContent.text("Hello, world!")

        // Then: it holds the string value
        if case .text(let text) = content {
            XCTAssertEqual(text, "Hello, world!")
        } else {
            XCTFail("Expected .text case")
        }
    }

    /// AC2 [P0]: ToolContent.image case exists and holds data + mimeType.
    func testToolContent_ImageCase_HoldsDataAndMimeType() {
        // Given: TS SDK has ImageBlock with data and mimeType
        // When: creating an .image ToolContent
        let imageData = Data("fake-image".utf8)
        let content = ToolContent.image(data: imageData, mimeType: "image/png")

        // Then: it holds both data and mimeType
        if case .image(let data, let mimeType) = content {
            XCTAssertEqual(data, imageData)
            XCTAssertEqual(mimeType, "image/png")
        } else {
            XCTFail("Expected .image case")
        }
    }

    /// AC2 [P0]: ToolContent.resource case exists and holds uri + optional name.
    func testToolContent_ResourceCase_HoldsUriAndName() {
        // Given: TS SDK has ResourceBlock with uri and name
        // When: creating a .resource ToolContent with name
        let content = ToolContent.resource(uri: "file:///path/to/resource", name: "resource.txt")

        // Then: it holds both uri and name
        if case .resource(let uri, let name) = content {
            XCTAssertEqual(uri, "file:///path/to/resource")
            XCTAssertEqual(name, "resource.txt")
        } else {
            XCTFail("Expected .resource case")
        }
    }

    /// AC2 [P1]: ToolContent.resource with nil name.
    func testToolContent_ResourceCase_NilName() {
        // When: creating a .resource ToolContent without name
        let content = ToolContent.resource(uri: "file:///path/to/resource", name: nil)

        // Then: name is nil
        if case .resource(_, let name) = content {
            XCTAssertNil(name)
        } else {
            XCTFail("Expected .resource case")
        }
    }

    // MARK: - AC2: ToolContent Sendable conformance

    /// AC2 [P0]: ToolContent conforms to Sendable.
    func testToolContent_ConformsToSendable() {
        // Given: ToolContent instances
        let text = ToolContent.text("sendable")
        let image = ToolContent.image(data: Data(), mimeType: "image/jpeg")
        let resource = ToolContent.resource(uri: "uri://test", name: "test")

        // Then: all can be used as Sendable
        let _: any Sendable = text
        let _: any Sendable = image
        let _: any Sendable = resource
    }

    // MARK: - AC2: ToolContent Equatable conformance

    /// AC2 [P0]: ToolContent conforms to Equatable.
    func testToolContent_ConformsToEquatable() {
        // Given: identical ToolContent pairs
        let textA = ToolContent.text("hello")
        let textB = ToolContent.text("hello")
        XCTAssertEqual(textA, textB)

        let imageA = ToolContent.image(data: Data([1, 2, 3]), mimeType: "image/png")
        let imageB = ToolContent.image(data: Data([1, 2, 3]), mimeType: "image/png")
        XCTAssertEqual(imageA, imageB)

        let resourceA = ToolContent.resource(uri: "uri://a", name: "a")
        let resourceB = ToolContent.resource(uri: "uri://a", name: "a")
        XCTAssertEqual(resourceA, resourceB)
    }

    /// AC2 [P0]: ToolContent inequality works across different cases and values.
    func testToolContent_Inequality() {
        // Different text values
        XCTAssertNotEqual(ToolContent.text("a"), ToolContent.text("b"))

        // Different mime types
        XCTAssertNotEqual(
            ToolContent.image(data: Data(), mimeType: "image/png"),
            ToolContent.image(data: Data(), mimeType: "image/jpeg")
        )

        // Different URIs
        XCTAssertNotEqual(
            ToolContent.resource(uri: "uri://a", name: nil),
            ToolContent.resource(uri: "uri://b", name: nil)
        )

        // Different cases
        XCTAssertNotEqual(ToolContent.text("a"), ToolContent.resource(uri: "a", name: nil))
    }

    // MARK: - AC2: ToolResult with typedContent

    /// AC2 [P0]: ToolResult can be created with typedContent.
    func testToolResult_CreatedWithTypedContent() {
        // Given: typed content array
        let typedContent: [ToolContent] = [
            .text("First part"),
            .text("Second part")
        ]

        // When: creating ToolResult with typedContent
        let result = ToolResult(
            toolUseId: "tu_1",
            typedContent: typedContent,
            isError: false
        )

        // Then: typedContent is stored
        XCTAssertNotNil(result.typedContent)
        XCTAssertEqual(result.typedContent?.count, 2)
    }

    /// AC2 [P0]: ToolResult.content returns concatenated text when typedContent is set.
    func testToolResult_ContentDerivesFromTypedContent() {
        // Given: typedContent with multiple .text items
        let typedContent: [ToolContent] = [
            .text("Hello"),
            .text(" "),
            .text("World")
        ]

        // When: creating ToolResult with typedContent
        let result = ToolResult(
            toolUseId: "tu_1",
            typedContent: typedContent,
            isError: false
        )

        // Then: content returns concatenation of .text items
        XCTAssertEqual(result.content, "Hello World",
                        "content should derive from concatenated .text items in typedContent")
    }

    /// AC2 [P0]: ToolResult.content returns stored string when typedContent is nil.
    func testToolResult_ContentFallsBackToStoredString() {
        // Given: ToolResult created with old init (no typedContent)
        let result = ToolResult(toolUseId: "tu_1", content: "legacy content", isError: false)

        // Then: content returns the stored string
        XCTAssertEqual(result.content, "legacy content")
        XCTAssertNil(result.typedContent,
                      "Old init should result in nil typedContent")
    }

    /// AC2 [P0]: Existing ToolResult init remains backward-compatible.
    func testToolResult_BackwardCompatInit() {
        // Given: the original init signature
        let result = ToolResult(toolUseId: "tu_abc", content: "plain text", isError: false)

        // Then: all fields work as before
        XCTAssertEqual(result.toolUseId, "tu_abc")
        XCTAssertEqual(result.content, "plain text")
        XCTAssertFalse(result.isError)
        XCTAssertNil(result.typedContent)
    }

    /// AC2 [P1]: ToolResult typedContent with mixed content types.
    func testToolResult_TypedContent_MixedTypes() {
        // Given: typedContent with text, image, and resource
        let typedContent: [ToolContent] = [
            .text("Here is the result:"),
            .image(data: Data([0x89, 0x50]), mimeType: "image/png"),
            .resource(uri: "file:///data.csv", name: "data.csv")
        ]

        // When: creating ToolResult
        let result = ToolResult(
            toolUseId: "tu_mixed",
            typedContent: typedContent,
            isError: false
        )

        // Then: all content types are preserved
        XCTAssertEqual(result.typedContent?.count, 3)

        // And: content returns only .text items concatenated
        XCTAssertEqual(result.content, "Here is the result:",
                        "content should only concatenate .text items, skipping non-text")
    }

    // MARK: - AC2: ToolExecuteResult with typedContent

    /// AC2 [P0]: ToolExecuteResult can be created with typedContent.
    func testToolExecuteResult_CreatedWithTypedContent() {
        // Given: typed content array
        let typedContent: [ToolContent] = [
            .text("Operation succeeded"),
            .image(data: Data(), mimeType: "image/png")
        ]

        // When: creating ToolExecuteResult with typedContent
        let result = ToolExecuteResult(typedContent: typedContent, isError: false)

        // Then: typedContent is stored
        XCTAssertNotNil(result.typedContent)
        XCTAssertEqual(result.typedContent?.count, 2)
    }

    /// AC2 [P0]: ToolExecuteResult.content derives from typedContent.
    func testToolExecuteResult_ContentDerivesFromTypedContent() {
        // Given: typedContent with text items
        let typedContent: [ToolContent] = [.text("result text")]

        // When: creating ToolExecuteResult with typedContent
        let result = ToolExecuteResult(typedContent: typedContent, isError: false)

        // Then: content derives from typedContent
        XCTAssertEqual(result.content, "result text")
    }

    /// AC2 [P0]: ToolExecuteResult existing init remains backward-compatible.
    func testToolExecuteResult_BackwardCompatInit() {
        // Given: the original init signature
        let result = ToolExecuteResult(content: "plain result", isError: false)

        // Then: works as before
        XCTAssertEqual(result.content, "plain result")
        XCTAssertFalse(result.isError)
        XCTAssertNil(result.typedContent,
                      "Old init should result in nil typedContent")
    }

    /// AC2 [P1]: ToolExecuteResult content falls back when typedContent has no text.
    func testToolExecuteResult_ContentWithNoTextItems() {
        // Given: typedContent with only non-text items
        let typedContent: [ToolContent] = [
            .image(data: Data(), mimeType: "image/png")
        ]

        // When: creating ToolExecuteResult
        let result = ToolExecuteResult(typedContent: typedContent, isError: false)

        // Then: content is empty string (no .text items to concatenate)
        XCTAssertEqual(result.content, "",
                        "content should be empty when no .text items in typedContent")
    }

    // MARK: - AC2: ToolResult Equatable with typedContent

    /// AC2 [P1]: ToolResult equality considers typedContent.
    func testToolResult_Equality_WithTypedContent() {
        // Given: two ToolResults with same typedContent
        let typed: [ToolContent] = [.text("same")]
        let a = ToolResult(toolUseId: "tu_1", typedContent: typed, isError: false)
        let b = ToolResult(toolUseId: "tu_1", typedContent: typed, isError: false)

        // Then: they are equal
        XCTAssertEqual(a, b)
    }

    /// AC2 [P1]: ToolResult inequality with different typedContent.
    func testToolResult_Inequality_WithDifferentTypedContent() {
        // Given: two ToolResults with different typedContent
        let a = ToolResult(toolUseId: "tu_1", typedContent: [.text("a")], isError: false)
        let b = ToolResult(toolUseId: "tu_1", typedContent: [.text("b")], isError: false)

        // Then: they are not equal
        XCTAssertNotEqual(a, b)
    }
}

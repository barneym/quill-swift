import XCTest
@testable import QuillSwift

/// Tests for MarkdownDocument
final class DocumentTests: XCTestCase {

    // MARK: - Initialization Tests

    func testEmptyDocumentInitialization() {
        let doc = MarkdownDocument()
        XCTAssertEqual(doc.text, "")
    }

    func testDocumentWithText() {
        let doc = MarkdownDocument(text: "# Hello")
        XCTAssertEqual(doc.text, "# Hello")
    }

    // MARK: - Content Types

    func testReadableContentTypes() {
        let types = MarkdownDocument.readableContentTypes
        XCTAssertFalse(types.isEmpty)
        XCTAssertTrue(types.contains(.markdown))
    }

    func testWritableContentTypes() {
        let types = MarkdownDocument.writableContentTypes
        XCTAssertFalse(types.isEmpty)
        XCTAssertTrue(types.contains(.markdown))
    }

    // MARK: - Text Manipulation

    func testTextModification() {
        var doc = MarkdownDocument(text: "Original")
        doc.text = "Modified"
        XCTAssertEqual(doc.text, "Modified")
    }

    func testMultilineContent() {
        let content = """
        # Heading

        Paragraph with **bold** and *italic*.

        - List item 1
        - List item 2
        """

        let doc = MarkdownDocument(text: content)
        XCTAssertTrue(doc.text.contains("# Heading"))
        XCTAssertTrue(doc.text.contains("**bold**"))
        XCTAssertTrue(doc.text.contains("- List item"))
    }

    // MARK: - Edge Cases

    func testUnicodeContent() {
        let content = "# 日本語見出し\n\nEmoji: 🎉🚀💡"
        let doc = MarkdownDocument(text: content)
        XCTAssertEqual(doc.text, content)
    }

    func testLargeContent() {
        let largeContent = String(repeating: "Line of text.\n", count: 10000)
        let doc = MarkdownDocument(text: largeContent)
        XCTAssertEqual(doc.text.count, largeContent.count)
    }
}

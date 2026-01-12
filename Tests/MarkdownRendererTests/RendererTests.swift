import XCTest
@testable import MarkdownRenderer

/// Tests for MarkdownRenderer
final class RendererTests: XCTestCase {

    // MARK: - Basic Rendering

    func testEmptyDocument() {
        let html = MarkdownRenderer.renderHTML(from: "")
        XCTAssertEqual(html, "")
    }

    func testHeading1() {
        let html = MarkdownRenderer.renderHTML(from: "# Hello")
        XCTAssertTrue(html.contains("<h1>Hello</h1>"))
    }

    func testHeading2() {
        let html = MarkdownRenderer.renderHTML(from: "## Hello")
        XCTAssertTrue(html.contains("<h2>Hello</h2>"))
    }

    func testParagraph() {
        let html = MarkdownRenderer.renderHTML(from: "Hello world")
        XCTAssertTrue(html.contains("<p>Hello world</p>"))
    }

    func testMultipleParagraphs() {
        let html = MarkdownRenderer.renderHTML(from: "First\n\nSecond")
        XCTAssertTrue(html.contains("<p>First</p>"))
        XCTAssertTrue(html.contains("<p>Second</p>"))
    }

    // MARK: - Inline Formatting

    func testBold() {
        let html = MarkdownRenderer.renderHTML(from: "This is **bold** text")
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
    }

    func testItalic() {
        let html = MarkdownRenderer.renderHTML(from: "This is *italic* text")
        XCTAssertTrue(html.contains("<em>italic</em>"))
    }

    func testInlineCode() {
        let html = MarkdownRenderer.renderHTML(from: "Use `code` here")
        XCTAssertTrue(html.contains("<code>code</code>"))
    }

    // MARK: - Links and Images

    func testLink() {
        let html = MarkdownRenderer.renderHTML(from: "[Example](https://example.com)")
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">Example</a>"))
    }

    func testImage() {
        let html = MarkdownRenderer.renderHTML(from: "![Alt](image.png)")
        XCTAssertTrue(html.contains("<img src=\"image.png\" alt=\"Alt\">"))
    }

    // MARK: - Lists

    func testUnorderedList() {
        let markdown = """
        - Item 1
        - Item 2
        - Item 3
        """
        let html = MarkdownRenderer.renderHTML(from: markdown)
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>"))
        XCTAssertTrue(html.contains("Item 1"))
    }

    func testOrderedList() {
        let markdown = """
        1. First
        2. Second
        3. Third
        """
        let html = MarkdownRenderer.renderHTML(from: markdown)
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<li>"))
        XCTAssertTrue(html.contains("First"))
    }

    // MARK: - Code Blocks

    func testFencedCodeBlock() {
        // Note: Multiline string literals with proper formatting
        let markdown = "```swift\nfunc hello() {\n    print(\"Hello\")\n}\n```"
        let html = MarkdownRenderer.renderHTML(from: markdown)
        XCTAssertTrue(html.contains("<pre><code"))
        XCTAssertTrue(html.contains("language-swift"))
        // Code content may be syntax highlighted, check for key parts
        XCTAssertTrue(html.contains("func") && html.contains("hello"))
    }

    // MARK: - Blockquotes

    func testBlockquote() {
        let html = MarkdownRenderer.renderHTML(from: "> This is a quote")
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("This is a quote"))
    }

    // MARK: - HTML Escaping

    func testHTMLEscapingInText() {
        // Test that special characters in regular text are escaped
        let html = MarkdownRenderer.renderHTML(from: "Compare a < b and c > d")
        XCTAssertTrue(html.contains("&lt;"))
        XCTAssertTrue(html.contains("&gt;"))
    }

    func testAmpersandEscaping() {
        let html = MarkdownRenderer.renderHTML(from: "Tom & Jerry")
        XCTAssertTrue(html.contains("&amp;"))
    }

    func testRawHTMLHandling() {
        // Raw HTML in markdown is parsed as InlineHTML
        // Our current renderer strips it (security by default)
        // This test documents current behavior
        let html = MarkdownRenderer.renderHTML(from: "<script>alert('xss')</script>")
        // Raw HTML should not appear in output (stripped or sanitized)
        XCTAssertFalse(html.contains("alert"))
    }

    // MARK: - Parsing

    func testParse() {
        let document = MarkdownRenderer.parse("# Hello\n\nWorld")
        // Just verify it doesn't crash and returns a document
        XCTAssertNotNil(document)
    }
}

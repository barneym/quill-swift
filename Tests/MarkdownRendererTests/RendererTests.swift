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
        XCTAssertTrue(html.contains("<img src=\"image.png\" alt=\"Alt\""), html)
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

// MARK: - Obsidian Checkboxes

final class CheckboxRenderingTests: XCTestCase {

    private func render(_ markdown: String) -> String {
        MarkdownRenderer.renderHTML(from: markdown)
    }

    func testRegisteredAlternateCheckboxesRenderWithDataTask() {
        let cases: [(id: String, name: String)] = [
            ("W", "Waiting"), ("D", "Delegated"), ("F", "Follow-up"), ("b", "Bookmark"),
            (">", "Rescheduled"), ("<", "Scheduled"), ("*", "Starred"), ("s", "Someday/Maybe"),
        ]
        for (id, name) in cases {
            let html = render("- [\(id)] item text")
            let escaped = id.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            XCTAssertTrue(html.contains("class=\"task-list-item extended-checkbox\""), "\(id): \(html)")
            XCTAssertTrue(html.contains("data-task=\"\(escaped)\""), "\(id): \(html)")
            XCTAssertTrue(html.contains("data-checkbox-id=\"\(escaped)\""), "\(id): \(html)")
            XCTAssertTrue(html.contains("title=\"\(name)\""), "\(id): \(html)")
            XCTAssertTrue(html.contains("<span class=\"checkbox-symbol\"></span>item text</li>"), "\(id): \(html)")
            XCTAssertFalse(html.contains("[\(escaped)]"), "marker must not leak: \(html)")
            XCTAssertFalse(html.contains("style="), "CSS owns presentation: \(html)")
        }
    }

    func testQuoteMarkerIsEscaped() {
        let html = render("- [\"] quoted")
        XCTAssertTrue(html.contains("data-task=\"&quot;\""), html)
        XCTAssertTrue(html.contains("title=\"Quote\""), html)
    }

    func testUnknownMarkerRendersAsGenericCheckbox() {
        let html = render("- [z] something\n- [7] speech")
        XCTAssertTrue(html.contains("data-task=\"z\""), html)
        XCTAssertTrue(html.contains("data-task=\"7\""), html)
        XCTAssertTrue(html.contains("<span class=\"checkbox-symbol\"></span>something</li>"), html)
        XCTAssertFalse(html.contains("[z] something"), html)
        XCTAssertTrue(html.contains("title=\"Custom [z]\""), html)
    }

    func testStandardCheckboxesKeepInputPath() {
        let html = render("- [ ] todo\n- [x] done\n- [X] also done\n- [b] bookmark")
        XCTAssertEqual(html.components(separatedBy: "<input type=\"checkbox\" class=\"task-checkbox\"").count - 1, 3, html)
        XCTAssertTrue(html.contains("data-task=\" \" data-checkbox-status=\"pending\""), html)
        XCTAssertTrue(html.contains("data-task=\"x\" data-checkbox-status=\"complete\""), html)
        // Extended items carry no <input>, so the preview's click index stays aligned
        let extended = html.components(separatedBy: "extended-checkbox").dropFirst().joined()
        XCTAssertFalse(extended.contains("<input"), html)
    }

    func testNonMarkersAreLeftAlone() {
        XCTAssertFalse(render("- [b](https://example.com) link").contains("extended-checkbox"))
        XCTAssertFalse(render("- [ab] two chars").contains("extended-checkbox"))
        XCTAssertFalse(render("- [b]no space").contains("extended-checkbox"))
        XCTAssertFalse(render("[b] not a list").contains("extended-checkbox"))
    }

    func testMarkerSplitAcrossTextNodesKeepsInlineContent() {
        let html = render("- [*] a **bold** star")
        XCTAssertTrue(html.contains("<span class=\"checkbox-symbol\"></span>a <strong>bold</strong> star</li>"), html)
    }

    func testLooseExtendedItemKeepsParagraph() {
        let html = render("- [!] first\n\n- [?] second")
        XCTAssertTrue(html.contains("<p><span class=\"checkbox-symbol\"></span>first</p>"), html)
    }

    func testRegistryResolvesMarkers() {
        let registry = CheckboxRegistry.shared
        XCTAssertEqual(registry.resolvedType(forMarker: "X").id, "x")
        XCTAssertEqual(registry.resolvedType(forMarker: "M").name, "Meeting")
        XCTAssertEqual(registry.resolvedType(forMarker: "q").presentation, .filled)
        for id in ["-", "!", "?", "*", "/", "<", ">", "\"", "b", "c", "d", "f", "i", "I", "k", "l", "n", "p", "S", "u", "w",
                   "W", "D", "R", "M", "s", "E", "P", "F", "H"] {
            XCTAssertNotNil(registry.type(forId: id), "missing \(id)")
        }
    }

    func testStylesheetHasRulePerTypeInBothAppearances() {
        let light = CheckboxRegistry.shared.stylesheet(isDark: false)
        let dark = CheckboxRegistry.shared.stylesheet(isDark: true)
        XCTAssertTrue(light.contains(".task-list-item.extended-checkbox[data-task=\"W\"] > .checkbox-symbol::after"), light)
        XCTAssertTrue(light.contains(".task-list-item.extended-checkbox[data-task=\"\\\"\"]"), light)
        XCTAssertTrue(light.contains("#d20f39"), "Latte red")
        XCTAssertTrue(dark.contains("#f38ba8"), "Mocha red")
        XCTAssertTrue(light.contains("url(\"data:image/svg+xml,%3Csvg"), light)
        XCTAssertFalse(light.contains("<svg"), "SVG must be URL-encoded")
    }
}

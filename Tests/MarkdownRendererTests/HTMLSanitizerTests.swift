import XCTest
@testable import MarkdownRenderer

final class HTMLSanitizerTests: XCTestCase {

    private func clean(_ html: String) -> String { HTMLSanitizer.sanitize(html) }

    // MARK: - Dropped

    func testScriptAndContentRemoved() {
        XCTAssertEqual(clean("a<script>alert('x')</script>b"), "ab")
        XCTAssertEqual(clean("<SCRIPT type=\"text/javascript\">x()</SCRIPT>"), "")
    }

    func testStyleIframeFormRemoved() {
        XCTAssertEqual(clean("<style>body{display:none}</style>"), "")
        XCTAssertEqual(clean("<iframe src=\"https://evil\"></iframe>"), "")
        XCTAssertEqual(clean("<form action=\"x\"><input name=a></form>"), "")
    }

    func testUnclosedScriptSwallowsRest() {
        XCTAssertEqual(clean("ok<script>never closed"), "ok")
    }

    func testEventHandlersAndStyleStripped() {
        XCTAssertEqual(clean("<img src=\"a.png\" onerror=\"alert(1)\" style=\"x\">"), "<img src=\"a.png\">")
        XCTAssertEqual(clean("<div onclick=alert(1)>t</div>"), "<div>t</div>")
    }

    func testJavascriptURLsRemovedIncludingObfuscated() {
        XCTAssertEqual(clean("<a href=\"javascript:alert(1)\">x</a>"), "<a>x</a>")
        XCTAssertEqual(clean("<a href=\"JaVaScRiPt:alert(1)\">x</a>"), "<a>x</a>")
        XCTAssertEqual(clean("<a href=\"java\tscript:alert(1)\">x</a>"), "<a>x</a>")
        XCTAssertEqual(clean("<a href=\"&#106;avascript:alert(1)\">x</a>"), "<a>x</a>")
        XCTAssertEqual(clean("<a href=\"javascript&colon;alert(1)\">x</a>"), "<a>x</a>")
        XCTAssertEqual(clean("<img src=\"data:text/html,<script>\">"), "<img>")
    }

    func testCommentsRemoved() {
        XCTAssertEqual(clean("a<!-- <script>x</script> -->b"), "ab")
    }

    func testUnknownTagsDroppedButTextKept() {
        XCTAssertEqual(clean("<blink>hi</blink>"), "hi")
    }

    // MARK: - Kept

    func testSizedImageKept() {
        XCTAssertEqual(
            clean("<img src=\"docs/shot.png\" alt=\"Shot\" width=\"300\">"),
            "<img src=\"docs/shot.png\" alt=\"Shot\" width=\"300\">"
        )
    }

    func testSafeLinksAndDataImagesKept() {
        XCTAssertEqual(clean("<a href=\"https://example.com/a:b\">x</a>"), "<a href=\"https://example.com/a:b\">x</a>")
        XCTAssertEqual(clean("<a href=\"notes/a:b.md\">x</a>"), "<a href=\"notes/a:b.md\">x</a>")
        XCTAssertEqual(clean("<a href=\"#top\">x</a>"), "<a href=\"#top\">x</a>")
        XCTAssertEqual(clean("<img src=\"data:image/png;base64,AAAA\">"), "<img src=\"data:image/png;base64,AAAA\">")
    }

    func testReadmeStyleMarkupKept() {
        XCTAssertEqual(clean("<p align=\"center\"><kbd>⌘</kbd><br/></p>"), "<p align=\"center\"><kbd>⌘</kbd><br /></p>")
        XCTAssertEqual(clean("<details open><summary>More</summary>"), "<details open><summary>More</summary>")
    }

    func testLoneAngleBracketEscaped() {
        XCTAssertEqual(clean("a < b"), "a &lt; b")
    }

    // MARK: - Policies

    func testEscapePolicyShowsSource() {
        XCTAssertEqual(HTMLSanitizer.render("<b>x</b>", policy: .escape), "&lt;b&gt;x&lt;/b&gt;")
    }

    func testStripPolicy() {
        XCTAssertEqual(HTMLSanitizer.render("<b>x</b>", policy: .strip), "")
    }
}

// MARK: - Renderer Integration

final class RawHTMLRenderingTests: XCTestCase {

    func testSafeByDefault() {
        let html = MarkdownRenderer.renderHTML(from: "<div onclick=\"x()\">hi</div>\n\n<script>alert(1)</script>\n")
        XCTAssertFalse(html.contains("onclick"), html)
        XCTAssertFalse(html.contains("alert"), html)
        XCTAssertTrue(html.contains("<div>hi</div>"), html)
    }

    func testSizedHTMLImageStillRenders() {
        let html = MarkdownRenderer.renderHTML(from: "<img src=\"a.png\" width=\"300\">\n")
        XCTAssertTrue(html.contains("<img src=\"a.png\" width=\"300\">"), html)
    }

    func testEscapePolicyShowsHTMLAsText() {
        var options = MarkdownRenderer.Options()
        options.rawHTMLPolicy = .escape
        let html = MarkdownRenderer.renderHTML(from: "<b>x</b>\n", options: options)
        XCTAssertEqual(html, "<p>&lt;b&gt;x&lt;/b&gt;</p>\n")
    }

    func testMarkdownJavascriptLinkLosesHref() {
        let html = MarkdownRenderer.renderHTML(from: "[click](javascript:alert(1))")
        XCTAssertTrue(html.contains("<a>click</a>"), html)
    }

    func testObsidianImageSize() {
        XCTAssertTrue(MarkdownRenderer.renderHTML(from: "![Shot|300](a.png)").contains("<img src=\"a.png\" alt=\"Shot\" width=\"300\""))
        XCTAssertTrue(MarkdownRenderer.renderHTML(from: "![|300x200](a.png)").contains("alt=\"\" width=\"300\" height=\"200\""))
        // A bar that isn't a size stays in the alt text
        XCTAssertTrue(MarkdownRenderer.renderHTML(from: "![a|b](a.png)").contains("alt=\"a|b\""))
    }
}

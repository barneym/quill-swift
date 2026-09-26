import XCTest
@testable import MarkdownRenderer

/// Tests for hard/soft line breaks, clean (clipboard) HTML, and source-line annotations.
final class LineBreakAndCleanHTMLTests: XCTestCase {

    // MARK: - Line Breaks (CommonMark §6.7 / §6.8)

    func testTwoTrailingSpacesProduceHardBreak() {
        let html = MarkdownRenderer.renderHTML(from: "first  \nsecond")
        XCTAssertEqual(html, "<p>first<br>\nsecond</p>\n")
    }

    func testMoreThanTwoTrailingSpacesProduceHardBreak() {
        let html = MarkdownRenderer.renderHTML(from: "first     \nsecond")
        XCTAssertEqual(html, "<p>first<br>\nsecond</p>\n")
    }

    func testBackslashProducesHardBreak() {
        let html = MarkdownRenderer.renderHTML(from: "first\\\nsecond")
        XCTAssertEqual(html, "<p>first<br>\nsecond</p>\n")
    }

    func testSingleTrailingSpaceIsSoftBreak() {
        // One space is not enough for a hard break; stays in the same paragraph
        let html = MarkdownRenderer.renderHTML(from: "first \nsecond")
        XCTAssertEqual(html, "<p>first\nsecond</p>\n")
    }

    func testPlainNewlineIsSoftBreakNotNewParagraph() {
        let html = MarkdownRenderer.renderHTML(from: "first\nsecond")
        XCTAssertEqual(html, "<p>first\nsecond</p>\n")
    }

    func testTrailingSpacesOnLastLineOfParagraphAreIgnored() {
        let html = MarkdownRenderer.renderHTML(from: "only  \n\nnext")
        XCTAssertEqual(html, "<p>only</p>\n<p>next</p>\n")
    }

    func testHardBreakInsideListItem() {
        let html = MarkdownRenderer.renderHTML(from: "- first  \n  second")
        XCTAssertTrue(html.contains("first<br>\nsecond"), html)
    }

    // MARK: - Clean HTML

    private func clean(_ markdown: String) -> String {
        var options = MarkdownRenderer.Options()
        options.cleanHTML = true
        return MarkdownRenderer.renderHTML(from: markdown, options: options)
    }

    func testCleanCodeBlockIsBarePreCode() {
        let html = clean("```swift\nlet x = 1\n```")
        XCTAssertEqual(html, "<pre><code>let x = 1\n</code></pre>\n")
    }

    func testCleanHTMLHasNoPresentationAttributes() {
        let markdown = """
        # Title

        Some **bold** and `code`.

        - [ ] todo
        - [x] done
        - [/] in progress

        ![alt](pic.png)

        | a | b |
        |---|--:|
        | 1 | 2 |
        """
        let html = clean(markdown)
        for forbidden in ["class=", "style=", "<span", "<input", "loading=", "data-"] {
            XCTAssertFalse(html.contains(forbidden), "found \(forbidden) in:\n\(html)")
        }
        XCTAssertTrue(html.contains("<li>&#x2610; todo</li>"), html)
        XCTAssertFalse(html.contains("<li>&#x2610; <p>"), "tight list items must not wrap in <p>")
        XCTAssertTrue(html.contains("<li>&#x2611; done</li>"), html)
        XCTAssertTrue(html.contains("<img src=\"pic.png\" alt=\"alt\">"), html)
        XCTAssertTrue(html.contains("<code>code</code>"), html)
    }

    func testCleanHTMLIgnoresSourceLines() {
        var options = MarkdownRenderer.Options()
        options.cleanHTML = true
        options.includeSourceLines = true
        XCTAssertFalse(MarkdownRenderer.renderHTML(from: "# Hi", options: options).contains("data-line"))
    }

    // MARK: - Source Lines

    private func withLines(_ markdown: String) -> String {
        var options = MarkdownRenderer.Options()
        options.includeSourceLines = true
        options.highlightCodeBlocks = false
        return MarkdownRenderer.renderHTML(from: markdown, options: options)
    }

    func testSourceLinesAreZeroBasedAndSpanBlocks() {
        let html = withLines("# Title\n\nline one\nline two\n\n```\ncode\n```\n")
        XCTAssertTrue(html.contains("<h1 data-line=\"0\" data-line-end=\"0\">"), html)
        XCTAssertTrue(html.contains("<p data-line=\"2\" data-line-end=\"3\">"), html)
        XCTAssertTrue(html.contains("<pre data-line=\"5\" data-line-end=\"7\">"), html)
    }

    func testSourceLinesOffByDefault() {
        XCTAssertFalse(MarkdownRenderer.renderHTML(from: "# Hi\n\ntext").contains("data-line"))
    }
}

// MARK: - List Tightness

final class ListTightnessTests: XCTestCase {

    func testTightListHasNoParagraphTags() {
        let html = MarkdownRenderer.renderHTML(from: "- a\n- b\n")
        XCTAssertEqual(html, "<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n")
    }

    func testLooseListKeepsParagraphTags() {
        let html = MarkdownRenderer.renderHTML(from: "- a\n\n- b\n")
        XCTAssertEqual(html, "<ul>\n<li><p>a</p>\n</li>\n<li><p>b</p>\n</li>\n</ul>\n")
    }

    func testTightChecklistKeepsTextOnCheckboxLine() {
        let html = MarkdownRenderer.renderHTML(from: "- [ ] task\n- [x] done\n")
        XCTAssertFalse(html.contains("<p>"), html)
    }

    func testTightNestedList() {
        let html = MarkdownRenderer.renderHTML(from: "- a\n  - b\n- c\n")
        XCTAssertFalse(html.contains("<p>"), html)
    }
}

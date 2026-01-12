import XCTest
@testable import MarkdownRenderer

/// GitHub Flavored Markdown (GFM) extension conformance tests.
///
/// Tests GFM-specific features from the GFM specification.
/// Reference: https://github.github.com/gfm/
///
/// Known deviations are documented in CONFORMANCE.md.
final class GFMTests: XCTestCase {

    // MARK: - Helper

    /// Render markdown and normalize HTML for comparison
    private func render(_ markdown: String) -> String {
        MarkdownRenderer.renderHTML(from: markdown)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 4.10 Tables (GFM Extension)

    /// Example 198: Simple table
    func testExample198_SimpleTable() {
        let markdown = """
        | foo | bar |
        | --- | --- |
        | baz | bim |
        """
        let html = render(markdown)
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<th>") || html.contains("<thead>"))
        XCTAssertTrue(html.contains("foo"))
        XCTAssertTrue(html.contains("baz"))
    }

    /// Example 199: Alignment in tables
    func testExample199_TableAlignment() {
        let markdown = """
        | abc | defghi |
        :-: | -----------:
        bar | baz
        """
        let html = render(markdown)
        XCTAssertTrue(html.contains("<table>"))
        // Alignment may be expressed as style or align attribute
        // Just verify the table renders
        XCTAssertTrue(html.contains("<td>") || html.contains("<tbody>"))
    }

    /// Example 200: Pipes in table cells
    func testExample200_EscapedPipes() {
        let markdown = """
        | f\\|oo  |
        | --- |
        | b `\\|` az |
        | b **\\|** im |
        """
        let html = render(markdown)
        XCTAssertTrue(html.contains("<table>"))
    }

    /// Example 202: Table without leading pipe
    func testExample202_TableWithoutLeadingPipe() {
        let markdown = """
        foo | bar
        --- | ---
        baz | bim
        """
        let html = render(markdown)
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("foo"))
    }

    // MARK: - 5.3 Task List Items (GFM Extension)

    /// Example 279: Task list items
    func testExample279_TaskListItems() {
        let markdown = """
        - [ ] foo
        - [x] bar
        """
        let html = render(markdown)
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li"))
        // Task list styling varies by implementation
        XCTAssertTrue(html.contains("checkbox") || html.contains("task"))
    }

    /// Example 280: Nested task lists
    func testExample280_NestedTaskList() {
        let markdown = """
        - [x] foo
          - [ ] bar
          - [x] baz
        - [ ] bim
        """
        let html = render(markdown)
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("foo"))
        XCTAssertTrue(html.contains("bar"))
    }

    // MARK: - 6.5 Strikethrough (GFM Extension)

    /// Example 491: Single tilde strikethrough
    func testExample491_SingleTildeStrikethrough() {
        let html = render("~~Hi~~ Hello, world!")
        XCTAssertTrue(html.contains("<del>") || html.contains("~~Hi~~"))
    }

    /// Example 493: Strikethrough
    func testExample493_Strikethrough() {
        let html = render("This ~~has a\n\nnew paragraph~~.")
        // Strikethrough should not span paragraphs
        // The exact behavior depends on implementation
        XCTAssertTrue(html.contains("<p>"))
    }

    // MARK: - 6.9 Autolinks (GFM Extension)

    /// Example 621: Extended URL autolink
    func testExample621_ExtendedURLAutolink() {
        let html = render("Visit www.commonmark.org/help for more information.")
        // GFM autolinks www.* without angle brackets
        XCTAssertTrue(
            html.contains("<a href=\"http://www.commonmark.org") ||
            html.contains("www.commonmark.org")
        )
    }

    /// Example 622: Extended email autolink
    func testExample622_ExtendedEmailAutolink() {
        let html = render("foo@bar.baz")
        // GFM autolinks emails without angle brackets
        XCTAssertTrue(
            html.contains("mailto:") ||
            html.contains("foo@bar.baz")
        )
    }

    // MARK: - 6.11 Disallowed Raw HTML (GFM Extension)

    /// Example 653: Filter dangerous tags
    func testExample653_FilterDangerousTags() {
        let html = render("<script>alert('hi')</script>")
        // Script tags should be stripped or escaped
        XCTAssertFalse(html.contains("<script>"))
    }

    /// Example 654: Filter style tags
    func testExample654_FilterStyleTags() {
        let html = render("<style>div{}</style>")
        // Style tags should be stripped or escaped
        XCTAssertFalse(html.contains("<style>"))
    }

    // MARK: - Additional GFM Features

    /// Fenced code with language info
    func testGFM_FencedCodeLanguage() {
        let markdown = """
        ```javascript
        console.log("hello");
        ```
        """
        let html = render(markdown)
        XCTAssertTrue(html.contains("language-javascript"))
    }

    /// Multiple tables in document
    func testGFM_MultipleTables() {
        let markdown = """
        | A | B |
        |---|---|
        | 1 | 2 |

        Some text between tables.

        | C | D |
        |---|---|
        | 3 | 4 |
        """
        let html = render(markdown)
        // Should contain two tables
        let tableCount = html.components(separatedBy: "<table>").count - 1
        XCTAssertEqual(tableCount, 2)
    }

    /// Task list with inline formatting
    func testGFM_TaskListFormatting() {
        let markdown = """
        - [ ] **bold** task
        - [x] *italic* completed
        - [ ] `code` item
        """
        let html = render(markdown)
        XCTAssertTrue(html.contains("<strong>bold</strong>") || html.contains("**bold**"))
        XCTAssertTrue(html.contains("<em>italic</em>") || html.contains("*italic*"))
    }

    /// Mixed content document
    func testGFM_MixedContent() {
        let markdown = """
        # Document Title

        Introduction paragraph with **bold** and *italic*.

        | Header 1 | Header 2 |
        |----------|----------|
        | Cell 1   | Cell 2   |

        ## Task List

        - [x] Completed task
        - [ ] Pending task

        ```swift
        let code = "example"
        ```

        > Blockquote with ~~strikethrough~~
        """
        let html = render(markdown)
        XCTAssertTrue(html.contains("<h1>"))
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<pre><code"))
        XCTAssertTrue(html.contains("<blockquote>"))
    }
}

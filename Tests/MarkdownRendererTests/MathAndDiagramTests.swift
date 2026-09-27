import XCTest
@testable import MarkdownRenderer

/// Math extraction (`$…$`, `$$…$$`, ```math), Mermaid source blocks and
/// Obsidian plugin captions.
final class MathAndDiagramTests: XCTestCase {

    private func render(_ markdown: String, math: Bool = true, lines: Bool = false, clean: Bool = false) -> String {
        var options = MarkdownRenderer.Options()
        options.renderMath = math
        options.includeSourceLines = lines
        options.cleanHTML = clean
        options.highlightCodeBlocks = false
        return MarkdownRenderer.renderHTML(from: markdown, options: options)
    }

    private func inline(_ tex: String) -> String {
        "<span class=\"qs-math\" data-display=\"false\">\(tex)</span>"
    }

    private func display(_ tex: String) -> String {
        "<span class=\"qs-math\" data-display=\"true\">\(tex)</span>"
    }

    // MARK: - Inline math

    func testInlineMath() {
        XCTAssertEqual(render("Euler: $e^{i\\pi}+1=0$."), "<p>Euler: \(inline("e^{i\\pi}+1=0")).</p>\n")
    }

    func testMarkdownDoesNotMangleTeX() {
        // Underscores would be emphasis, \\ an escaped backslash, | a table cell
        let html = render("$a_b_c$ and $x\\\\y$ and $|v|$")
        XCTAssertEqual(html, "<p>\(inline("a_b_c")) and \(inline("x\\\\y")) and \(inline("|v|"))</p>\n")
    }

    func testCurrencyIsNotMath() {
        XCTAssertEqual(render("It costs $5 and $10 today."), "<p>It costs $5 and $10 today.</p>\n")
    }

    func testClosingDollarFollowedByDigitIsNotMath() {
        XCTAssertEqual(render("From $x$1 up"), "<p>From $x$1 up</p>\n")
    }

    func testOpeningDollarFollowedBySpaceIsNotMath() {
        XCTAssertEqual(render("a $ b$ c"), "<p>a $ b$ c</p>\n")
    }

    func testClosingDollarPrecededBySpaceIsNotMath() {
        XCTAssertEqual(render("a $b $ c"), "<p>a $b $ c</p>\n")
    }

    func testEscapedDollarIsLiteral() {
        XCTAssertEqual(render("Price \\$5 and \\$x\\$"), "<p>Price $5 and $x$</p>\n")
        XCTAssertEqual(render("$a \\$ b$"), "<p>\(inline("a \\$ b"))</p>\n")
    }

    func testInlineMathDoesNotSpanLines() {
        XCTAssertEqual(render("$a\nb$"), "<p>$a\nb$</p>\n")
    }

    func testNoMathInCodeSpan() {
        XCTAssertEqual(render("Use `$x$` or $y$"), "<p>Use <code>$x$</code> or \(inline("y"))</p>\n")
    }

    func testCodeSpanInsideDollarsBlocksMath() {
        XCTAssertEqual(render("$a `b` c$"), "<p>$a <code>b</code> c$</p>\n")
    }

    func testNoMathInFencedCode() {
        let html = render("```\n$x$ and $$y$$\n```\n\n$z$")
        XCTAssertEqual(html, "<pre><code>$x$ and $$y$$\n</code></pre>\n<p>\(inline("z"))</p>\n")
    }

    func testNoMathInIndentedCode() {
        let html = render("Text\n\n    $x$ code\n\nafter $y$")
        XCTAssertTrue(html.contains("<pre><code>$x$ code\n</code></pre>"), html)
        XCTAssertTrue(html.contains(inline("y")), html)
    }

    func testHTMLIsEscapedInsideMath() {
        XCTAssertEqual(render("$a<b>c$"), "<p>\(inline("a&lt;b&gt;c"))</p>\n")
        XCTAssertEqual(render("$x<y$ and $y>z$"), "<p>\(inline("x&lt;y")) and \(inline("y&gt;z"))</p>\n")
    }

    func testNoMathInHTMLBlock() {
        XCTAssertEqual(render("<div>$x$</div>").trimmingCharacters(in: .whitespacesAndNewlines), "<div>$x$</div>")
    }

    func testMathInHeadingAndListAndTable() {
        XCTAssertEqual(render("# Area $\\pi r^2$"), "<h1>Area \(inline("\\pi r^2"))</h1>\n")
        XCTAssertTrue(render("- item $x_1$").contains("<li>item \(inline("x_1"))</li>"))
        let table = render("| a | b |\n|---|---|\n| $|x|$ | 2 |")
        XCTAssertTrue(table.contains("<td>\(inline("|x|"))</td>"), table)
    }

    func testMathDisabledLeavesSourceUntouched() {
        // Without math, markdown applies inside dollars as usual
        XCTAssertEqual(render("$a*b*c$", math: false), "<p>$a<em>b</em>c$</p>\n")
        XCTAssertEqual(render("```math\nx\n```", math: false), "<pre><code class=\"language-math\">x\n</code></pre>\n")
    }

    func testDocumentMentioningPlaceholderPrefixIsSafe() {
        XCTAssertEqual(render("QSMATHPH0X and $y$"), "<p>QSMATHPH0X and \(inline("y"))</p>\n")
    }

    // MARK: - Display math

    func testSingleLineDisplayMath() {
        XCTAssertEqual(render("$$x^2$$"), "<div class=\"qs-math-block\">\(display("x^2"))</div>\n")
    }

    func testMultiLineDisplayMath() {
        let html = render("$$\n\\sum_{i=1}^n i\n$$")
        XCTAssertEqual(html, "<div class=\"qs-math-block\">\(display("\n\\sum_{i=1}^n i\n"))</div>\n")
    }

    func testDisplayMathInsideParagraph() {
        let html = render("Before $$x$$ after")
        XCTAssertEqual(html, "<p>Before \(display("x")) after</p>\n")
    }

    func testDisplayMathDoesNotCrossBlankLine() {
        XCTAssertEqual(render("$$\nx\n\ny\n$$"), "<p>$$\nx</p>\n<p>y\n$$</p>\n")
    }

    func testDisplayMathInBlockquote() {
        let html = render("> $$\n> a_1\n> $$")
        XCTAssertTrue(html.contains(display("\na_1\n")), html)
        XCTAssertFalse(html.contains("&gt;"), html)
    }

    func testMathFenceIsDisplayMath() {
        let html = render("```math\n\\frac{a}{b}\n```", lines: true)
        XCTAssertEqual(html, "<div class=\"qs-math-block\" data-line=\"0\" data-line-end=\"2\">\(display("\\frac{a}{b}"))</div>\n")
    }

    // MARK: - Source lines (scroll sync)

    func testMultiLineDisplayMathKeepsLineNumbers() {
        let markdown = "Intro\n\n$$\na\nb\n$$\n\nAfter $x$\n\n## Heading"
        let html = render(markdown, lines: true)
        XCTAssertTrue(html.contains("<p data-line=\"0\" data-line-end=\"0\">Intro</p>"), html)
        XCTAssertTrue(html.contains("<div class=\"qs-math-block\" data-line=\"2\" data-line-end=\"5\">"), html)
        XCTAssertTrue(html.contains("<p data-line=\"7\" data-line-end=\"7\">After"), html)
        XCTAssertTrue(html.contains("<h2 data-line=\"9\" data-line-end=\"9\">Heading</h2>"), html)
    }

    func testLineNumbersMatchWithAndWithoutMath() {
        let markdown = "# T\n\n$$\n1\n2\n3\n$$\ntext\n\n- a $b$\n- c\n\n> $$\n> q\n> $$\n\nend"
        let pattern = try! NSRegularExpression(pattern: "<(p|h1|li|ul|blockquote)[^>]*data-line=\"(\\d+)\"")
        func starts(_ html: String) -> [String] {
            pattern.matches(in: html, range: NSRange(html.startIndex..., in: html)).map {
                (html as NSString).substring(with: $0.range(at: 1)) + ":" + (html as NSString).substring(with: $0.range(at: 2))
            }
        }
        let withMath = starts(render(markdown, lines: true))
        XCTAssertTrue(withMath.contains("p:7"), "\(withMath)")   // "text" after the $$ block
        XCTAssertTrue(withMath.contains("li:9"), "\(withMath)")
        XCTAssertTrue(withMath.contains("p:16"), "\(withMath)")  // "end"
    }

    // MARK: - Clean HTML

    func testCleanHTMLKeepsLiteralTeX() {
        XCTAssertEqual(render("Area $a_b$ here", clean: true), "<p>Area $a_b$ here</p>\n")
        XCTAssertEqual(render("$$\nx < y\n$$", clean: true), "<p>$$\nx &lt; y\n$$</p>\n")
        XCTAssertEqual(render("```math\nx\n```", clean: true), "<p>$$\nx\n$$</p>\n")
        XCTAssertFalse(render("$x$ and $$y$$", clean: true).contains("qs-math"))
    }

    // MARK: - Mermaid

    func testMermaidIsNotHighlighted() {
        var options = MarkdownRenderer.Options()
        options.includeSourceLines = true
        let html = MarkdownRenderer.renderHTML(from: "```mermaid\ngraph TD\n  A-->B\n```", options: options)
        XCTAssertEqual(html, "<pre data-line=\"0\" data-line-end=\"3\" class=\"mermaid-source\"><code class=\"language-mermaid\">graph TD\n  A--&gt;B\n</code></pre>\n")
    }

    func testMermaidInCleanHTMLIsPlainCode() {
        XCTAssertEqual(render("```mermaid\nA-->B\n```", clean: true), "<pre><code>A--&gt;B\n</code></pre>\n")
    }

    // MARK: - Obsidian plugin blocks

    func testDataviewBlockHasCaption() {
        let html = render("```dataview\nTABLE file.name\n```")
        XCTAssertEqual(html, "<div class=\"qs-block-caption\">Obsidian Dataview query</div>\n<pre><code class=\"language-dataview\">TABLE file.name\n</code></pre>\n")
        XCTAssertTrue(render("```dataviewjs\ndv.list()\n```").contains(">Obsidian Dataview query<"))
        XCTAssertTrue(render("```tasks\nnot done\n```").contains(">Obsidian Tasks query<"))
    }

    func testPluginCaptionNotInCleanHTML() {
        XCTAssertEqual(render("```dataview\nLIST\n```", clean: true), "<pre><code>LIST\n</code></pre>\n")
    }
}

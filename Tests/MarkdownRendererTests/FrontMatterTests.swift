import XCTest
@testable import MarkdownRenderer

final class FrontMatterTests: XCTestCase {

    let vaultExample = """
    ---
    type: reference
    description: "Naglfar NAS Urd share, folder group B (Code and Software). Detail page for [[Reference/Naglfar NAS Index]]."
    provenance: source-grounded
    sources: ["Reference/Naglfar NAS Index/urd-dirs.tsv", "Reference/Naglfar NAS Index/urd-markers.tsv"]
    last-synthesized: 2026-09-06
    tags: [reference, nas, naglfar, index]
    ---

    # Folders B
    """

    func testDetectsAndParsesVaultFrontMatter() throws {
        let (fm, body) = try XCTUnwrap(FrontMatter.split(vaultExample))
        XCTAssertEqual(fm.lineCount, 8)
        let props = try XCTUnwrap(fm.properties)
        XCTAssertEqual(props.map(\.key), ["type", "description", "provenance", "sources", "last-synthesized", "tags"])
        XCTAssertEqual(props[1].values.first, "Naglfar NAS Urd share, folder group B (Code and Software). Detail page for [[Reference/Naglfar NAS Index]].")
        XCTAssertEqual(props[3].values, ["Reference/Naglfar NAS Index/urd-dirs.tsv", "Reference/Naglfar NAS Index/urd-markers.tsv"])
        XCTAssertEqual(props[5].values, ["reference", "nas", "naglfar", "index"])
        XCTAssertTrue(props[5].isList)
        // Line numbers preserved: body has the same number of lines, heading on line 9
        XCTAssertEqual(body.split(separator: "\n", omittingEmptySubsequences: false).count,
                       vaultExample.split(separator: "\n", omittingEmptySubsequences: false).count)
        XCTAssertEqual(body.split(separator: "\n", omittingEmptySubsequences: false)[9], "# Folders B")
    }

    func testBlockListsAndTrailingSpaces() throws {
        let md = "---\ntitle: Hello   \naliases:\n  - One\n  - \"Two\"\n---\ntext"
        let props = try XCTUnwrap(FrontMatter.split(md)?.frontMatter.properties)
        XCTAssertEqual(props[0].values, ["Hello"])
        XCTAssertEqual(props[1].values, ["One", "Two"])
    }

    func testNestedYamlFallsBackToRaw() throws {
        let md = "---\nauthor:\n  name: Barney\n  url: x\n---\n"
        let fm = try XCTUnwrap(FrontMatter.split(md)?.frontMatter)
        XCTAssertNil(fm.properties)
        XCTAssertTrue(fm.html(lineAttributes: "").contains("<pre><code>author:"))
    }

    func testNotFrontMatter() {
        XCTAssertNil(FrontMatter.split("# Title\n---\n"))          // not at the top
        XCTAssertNil(FrontMatter.split("---\n---\ntext"))           // empty pair = rules
        XCTAssertNil(FrontMatter.split("---\ntype: x\nno close"))  // unterminated
        XCTAssertNil(FrontMatter.split("----\na: b\n----\n"))       // not exactly ---
    }

    func testHTMLEscapesValues() throws {
        let md = "---\ntitle: <b>x</b> & y\n---\n"
        let html = try XCTUnwrap(FrontMatter.split(md)).frontMatter.html(lineAttributes: "")
        XCTAssertTrue(html.contains("<td>&lt;b&gt;x&lt;/b&gt; &amp; y</td>"), html)
    }
}

final class FrontMatterRenderingTests: XCTestCase {
    let md = "---\ntype: reference\ntags: [a, b]\n---\n\n# Title\n"

    func testRendersPropertiesNotHeading() {
        let html = MarkdownRenderer.renderHTML(from: md)
        XCTAssertTrue(html.hasPrefix("<div class=\"qs-frontmatter\"><table>"), html)
        XCTAssertFalse(html.contains("<h2>"), html)
        XCTAssertFalse(html.contains("<hr"), html)
        XCTAssertTrue(html.contains("<h1>Title</h1>"), html)
    }

    func testSourceLinesStayAligned() {
        var options = MarkdownRenderer.Options()
        options.includeSourceLines = true
        let html = MarkdownRenderer.renderHTML(from: md, options: options)
        XCTAssertTrue(html.contains("<div class=\"qs-frontmatter\" data-line=\"0\" data-line-end=\"3\">"), html)
        XCTAssertTrue(html.contains("<h1 data-line=\"5\" data-line-end=\"5\">"), html)
    }

    func testCleanHTMLOmitsFrontMatter() {
        var options = MarkdownRenderer.Options()
        options.cleanHTML = true
        XCTAssertEqual(MarkdownRenderer.renderHTML(from: md, options: options), "<h1>Title</h1>\n")
    }

    func testMathInFrontMatterIgnored() {
        var options = MarkdownRenderer.Options()
        options.renderMath = true
        let html = MarkdownRenderer.renderHTML(from: "---\nprice: $5 and $x$\n---\ntext\n", options: options)
        XCTAssertTrue(html.contains("<td>$5 and $x$</td>"), html)
    }
}

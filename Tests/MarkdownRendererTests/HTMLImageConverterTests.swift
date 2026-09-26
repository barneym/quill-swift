import XCTest
@testable import MarkdownRenderer

final class HTMLImageConverterTests: XCTestCase {

    private func convert(_ markdown: String) -> (String, HTMLImageConverter.Result) {
        let result = HTMLImageConverter.convert(markdown)
        return (HTMLImageConverter.apply(result, to: markdown), result)
    }

    func testInlineImageConverted() {
        let (text, result) = convert("See <img src=\"a.png\" alt=\"A\"> here.")
        XCTAssertEqual(text, "See ![A](a.png) here.")
        XCTAssertEqual(result.convertedCount, 1)
        XCTAssertEqual(result.keptCount, 0)
    }

    func testBlockImageConvertedWithTitle() {
        let (text, _) = convert("# T\n\n<img src=\"dir/pic one.png\" alt=\"x]y\" title='Hi \"there\"'>\n\nAfter\n")
        XCTAssertEqual(text, "# T\n\n![x\\]y](<dir/pic one.png> \"Hi \\\"there\\\"\")\n\nAfter\n")
    }

    func testSizedImageUsesObsidianSyntax() {
        XCTAssertEqual(convert("<img src=\"a.png\" alt=\"A\" width=\"300\">\n").0, "![A|300](a.png)\n")
        XCTAssertEqual(convert("<img src=\"a.png\" width=\"300px\" height=\"200\">\n").0, "![|300x200](a.png)\n")
    }

    func testNonPixelOrStyledImageKept() {
        for source in ["<img src=\"a.png\" width=\"50%\">\n", "<img src=\"a.png\" style=\"float:left\">\n"] {
            let (text, result) = convert(source)
            XCTAssertEqual(text, source)
            XCTAssertEqual(result.convertedCount, 0)
            XCTAssertEqual(result.keptCount, 1)
        }
    }

    func testImageInsideLargerHTMLBlockKept() {
        let source = "<p align=\"center\"><img src=\"a.png\"></p>\n"
        let (text, result) = convert(source)
        XCTAssertEqual(text, source)
        XCTAssertEqual(result.keptCount, 1)
    }

    func testCodeIsNeverTouched() {
        let source = "`<img src=\"a.png\">`\n\n```html\n<img src=\"b.png\">\n```\n"
        let (text, result) = convert(source)
        XCTAssertEqual(text, source)
        XCTAssertEqual(result.convertedCount + result.keptCount, 0)
    }

    func testMultiByteTextBeforeImage() {
        let (text, _) = convert("Café ☕️ <img src=\"c.png\" alt=\"c\"> ok")
        XCTAssertEqual(text, "Café ☕️ ![c](c.png) ok")
    }
}

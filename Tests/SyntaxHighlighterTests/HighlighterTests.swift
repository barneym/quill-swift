import XCTest
@testable import SyntaxHighlighter

/// Tests for SyntaxHighlighter
final class HighlighterTests: XCTestCase {

    // MARK: - Basic Highlighting

    func testHighlightSwift() {
        let code = "func hello() { print(\"Hello\") }"
        let result = SyntaxHighlighter.highlight(
            code: code,
            language: .swift
        )

        XCTAssertEqual(result.source, code)
        XCTAssertEqual(result.language, .swift)
        XCTAssertFalse(result.html.isEmpty)
    }

    func testHighlightJavaScript() {
        let code = "function hello() { console.log('Hello'); }"
        let result = SyntaxHighlighter.highlight(
            code: code,
            language: .javascript
        )

        XCTAssertEqual(result.source, code)
        XCTAssertEqual(result.language, .javascript)
    }

    // MARK: - Language Detection

    func testLanguageIdentifierSwift() {
        let lang = SyntaxHighlighter.Language(identifier: "swift")
        XCTAssertEqual(lang, .swift)
    }

    func testLanguageIdentifierJS() {
        let lang = SyntaxHighlighter.Language(identifier: "js")
        XCTAssertEqual(lang, .javascript)
    }

    func testLanguageIdentifierPy() {
        let lang = SyntaxHighlighter.Language(identifier: "py")
        XCTAssertEqual(lang, .python)
    }

    func testLanguageIdentifierBash() {
        let lang = SyntaxHighlighter.Language(identifier: "bash")
        XCTAssertEqual(lang, .shell)
    }

    func testLanguageIdentifierUnknown() {
        let lang = SyntaxHighlighter.Language(identifier: "unknown_lang_xyz")
        XCTAssertNil(lang)
    }

    func testLanguageIdentifierCaseInsensitive() {
        let lang1 = SyntaxHighlighter.Language(identifier: "SWIFT")
        let lang2 = SyntaxHighlighter.Language(identifier: "Swift")
        let lang3 = SyntaxHighlighter.Language(identifier: "swift")

        XCTAssertEqual(lang1, .swift)
        XCTAssertEqual(lang2, .swift)
        XCTAssertEqual(lang3, .swift)
    }

    // MARK: - Highlight with Identifier

    func testHighlightWithIdentifier() {
        let code = "let x = 5"
        let result = SyntaxHighlighter.highlight(
            code: code,
            languageIdentifier: "swift"
        )

        XCTAssertEqual(result.language, .swift)
    }

    func testHighlightWithNilIdentifier() {
        let code = "some code"
        let result = SyntaxHighlighter.highlight(
            code: code,
            languageIdentifier: nil
        )

        XCTAssertEqual(result.language, .plaintext)
    }

    func testHighlightWithUnknownIdentifier() {
        let code = "some code"
        let result = SyntaxHighlighter.highlight(
            code: code,
            languageIdentifier: "unknown_xyz"
        )

        XCTAssertEqual(result.language, .plaintext)
    }

    // MARK: - Output Formats

    func testHTMLOutput() {
        let result = SyntaxHighlighter.highlight(
            code: "let x = 5",
            language: .swift
        )

        XCTAssertTrue(result.html.contains("<code"))
        XCTAssertTrue(result.html.contains("language-swift"))
    }

    func testAttributedStringOutput() {
        let result = SyntaxHighlighter.highlight(
            code: "let x = 5",
            language: .swift
        )

        let attrStr = result.attributedString
        XCTAssertFalse(String(attrStr.characters).isEmpty)
    }

    // MARK: - HTML Escaping

    func testHTMLEscapingInOutput() {
        let code = "if (a < b && c > d) {}"
        let result = SyntaxHighlighter.highlight(
            code: code,
            language: .javascript
        )

        // Should escape < and > in HTML output
        XCTAssertTrue(result.html.contains("&lt;"))
        XCTAssertTrue(result.html.contains("&gt;"))
        XCTAssertFalse(result.html.contains(" < "))
        XCTAssertFalse(result.html.contains(" > "))
    }

    // MARK: - Themes

    func testThemeCSS() {
        let lightCSS = SyntaxHighlighter.Theme.defaultLight.css
        let darkCSS = SyntaxHighlighter.Theme.defaultDark.css

        XCTAssertFalse(lightCSS.isEmpty)
        XCTAssertFalse(darkCSS.isEmpty)
        XCTAssertTrue(lightCSS.contains(".highlight-keyword"))
        XCTAssertTrue(darkCSS.contains(".highlight-keyword"))
    }

    // MARK: - Edge Cases

    func testEmptyCode() {
        let result = SyntaxHighlighter.highlight(
            code: "",
            language: .swift
        )

        XCTAssertEqual(result.source, "")
        XCTAssertFalse(result.html.isEmpty)  // Should still have code wrapper
    }

    func testMultilineCode() {
        let code = """
        func hello() {
            print("Line 1")
            print("Line 2")
        }
        """
        let result = SyntaxHighlighter.highlight(
            code: code,
            language: .swift
        )

        XCTAssertTrue(result.source.contains("Line 1"))
        XCTAssertTrue(result.source.contains("Line 2"))
    }
}

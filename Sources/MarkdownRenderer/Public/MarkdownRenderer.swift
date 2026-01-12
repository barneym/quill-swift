import Foundation
import Markdown

/// A standalone markdown rendering library.
///
/// Provides parsing (via swift-markdown) and rendering to HTML or AttributedString.
/// Designed for reuse outside of QuillSwift.
///
/// ## Usage
///
/// ```swift
/// // Render to HTML
/// let html = MarkdownRenderer.renderHTML(from: "# Hello")
///
/// // Render to AttributedString
/// let attributed = MarkdownRenderer.renderAttributedString(from: "# Hello")
/// ```
public struct MarkdownRenderer {

    // MARK: - Configuration

    /// Rendering options
    public struct Options {
        /// Enable HTML sanitization (default: true)
        public var sanitize: Bool = true

        /// Enabled markdown extensions
        public var extensions: Set<Extension> = [.gfm]

        /// Use dark theme for code highlighting (default: false)
        public var isDarkTheme: Bool = false

        /// Enable syntax highlighting for code blocks (default: true)
        public var highlightCodeBlocks: Bool = true

        public init() {}
    }

    /// Supported markdown extensions
    public enum Extension: String, CaseIterable {
        case gfm           // GitHub Flavored Markdown
        case customCheckboxes  // Extended checkbox syntax
        case footnotes     // Reference-style footnotes
        case math          // KaTeX math
        case mermaid       // Mermaid diagrams
    }

    // MARK: - Rendering

    /// Render markdown to HTML
    ///
    /// - Parameters:
    ///   - markdown: The markdown source text
    ///   - options: Rendering options (optional)
    /// - Returns: Rendered HTML string
    public static func renderHTML(
        from markdown: String,
        options: Options = Options()
    ) -> String {
        let document = Document(parsing: markdown)
        var renderer = HTMLRenderer(
            isDarkTheme: options.isDarkTheme,
            highlightCode: options.highlightCodeBlocks
        )
        return renderer.render(document)
    }

    /// Render markdown to AttributedString
    ///
    /// - Parameters:
    ///   - markdown: The markdown source text
    ///   - options: Rendering options (optional)
    /// - Returns: Rendered AttributedString
    public static func renderAttributedString(
        from markdown: String,
        options: Options = Options()
    ) -> AttributedString {
        // Phase 0: Stub implementation
        // TODO(#2): Implement AttributedString rendering
        return AttributedString(markdown)
    }

    /// Parse markdown to AST without rendering
    ///
    /// - Parameter markdown: The markdown source text
    /// - Returns: Parsed document
    public static func parse(_ markdown: String) -> Document {
        return Document(parsing: markdown)
    }
}

// MARK: - HTML Renderer

/// Walks the markdown AST and produces HTML
struct HTMLRenderer: MarkupWalker {
    var html = ""

    /// Whether to use dark theme for code highlighting
    let isDarkTheme: Bool

    /// Whether to apply syntax highlighting to code blocks
    let highlightCode: Bool

    // Track current table's column alignments for cell rendering
    private var currentTableAlignments: [Table.ColumnAlignment?] = []

    init(isDarkTheme: Bool = false, highlightCode: Bool = true) {
        self.isDarkTheme = isDarkTheme
        self.highlightCode = highlightCode
    }

    mutating func render(_ document: Document) -> String {
        html = ""
        currentTableAlignments = []
        visit(document)
        return html
    }

    mutating func visitDocument(_ document: Document) -> () {
        descendInto(document)
    }

    mutating func visitHeading(_ heading: Heading) -> () {
        html += "<h\(heading.level)>"
        descendInto(heading)
        html += "</h\(heading.level)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> () {
        html += "<p>"
        descendInto(paragraph)
        html += "</p>\n"
    }

    mutating func visitText(_ text: Text) -> () {
        html += escapeHTML(text.string)
    }

    mutating func visitStrong(_ strong: Strong) -> () {
        html += "<strong>"
        descendInto(strong)
        html += "</strong>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
        html += "<em>"
        descendInto(emphasis)
        html += "</em>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> () {
        html += "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
        let language = codeBlock.language ?? ""
        let code = codeBlock.code

        // Build the opening tag
        if language.isEmpty {
            html += "<pre><code>"
        } else {
            html += "<pre><code class=\"language-\(escapeHTML(language))\">"
        }

        // Apply syntax highlighting if enabled
        if highlightCode {
            let highlightedCode = CodeBlockHighlighter.shared.highlightToHTML(
                code,
                language: language.isEmpty ? nil : language,
                isDark: isDarkTheme
            )
            html += highlightedCode
        } else {
            html += escapeHTML(code)
        }

        html += "</code></pre>\n"
    }

    mutating func visitLink(_ link: Link) -> () {
        html += "<a href=\"\(escapeHTML(link.destination ?? ""))\">"
        descendInto(link)
        html += "</a>"
    }

    mutating func visitImage(_ image: Image) -> () {
        let src = escapeHTML(image.source ?? "")
        let alt = escapeHTML(image.plainText)
        html += "<img src=\"\(src)\" alt=\"\(alt)\">"
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> () {
        html += "<ul>\n"
        descendInto(list)
        html += "</ul>\n"
    }

    mutating func visitOrderedList(_ list: OrderedList) -> () {
        html += "<ol>\n"
        descendInto(list)
        html += "</ol>\n"
    }

    mutating func visitListItem(_ item: ListItem) -> () {
        // Check for built-in checkbox first
        if let checkbox = item.checkbox {
            // Map built-in checkbox to our type system
            let checkboxType = checkbox == .checked ? CheckboxType.complete : CheckboxType.pending
            html += renderCheckboxListItem(checkboxType: checkboxType)
            descendInto(item)
            html += "</li>\n"
        } else if let customCheckbox = parseExtendedCheckbox(from: item) {
            // Handle extended checkbox syntax [/], [-], [?], [!], etc.
            html += renderCheckboxListItem(checkboxType: customCheckbox.type)
            // Render content without the checkbox marker
            renderListItemContentWithoutCheckbox(item, markerLength: customCheckbox.markerLength)
            html += "</li>\n"
        } else {
            html += "<li>"
            descendInto(item)
            html += "</li>\n"
        }
    }

    /// Parse extended checkbox syntax from list item content
    private func parseExtendedCheckbox(from item: ListItem) -> (type: CheckboxType, markerLength: Int)? {
        // Get the plain text of the first inline element
        guard let firstChild = item.children.first(where: { $0 is Paragraph }) as? Paragraph,
              let text = firstChild.children.first(where: { $0 is Text }) as? Text else {
            return nil
        }

        let content = text.string

        // Check for extended checkbox pattern: [X] where X is not 'x' or ' '
        // Pattern: starts with [, single character, ] followed by space
        guard content.count >= 4,
              content.hasPrefix("["),
              content[content.index(content.startIndex, offsetBy: 2)] == "]",
              content[content.index(content.startIndex, offsetBy: 3)] == " " else {
            return nil
        }

        let checkboxChar = String(content[content.index(content.startIndex, offsetBy: 1)])

        // Skip standard checkboxes (handled by swift-markdown)
        if checkboxChar == "x" || checkboxChar == "X" || checkboxChar == " " {
            return nil
        }

        // Look up the checkbox type
        guard let checkboxType = CheckboxRegistry.shared.type(forId: checkboxChar) else {
            return nil
        }

        return (type: checkboxType, markerLength: 4) // "[X] " = 4 characters
    }

    /// Render a checkbox list item opener with SF Symbol
    private func renderCheckboxListItem(checkboxType: CheckboxType) -> String {
        let color = checkboxType.cssColor(isDark: isDarkTheme)
        let symbol = checkboxType.symbol
        let name = escapeHTML(checkboxType.name)

        // Use SF Symbol image tag with fallback unicode
        let symbolDisplay = sfSymbolToUnicode(symbol)

        return """
        <li class="task-list-item custom-checkbox" data-checkbox-id="\(escapeHTML(checkboxType.id))" title="\(name)"><span class="checkbox-symbol" style="color: \(color);">\(symbolDisplay)</span>
        """
    }

    /// Render list item content, skipping the checkbox marker
    private mutating func renderListItemContentWithoutCheckbox(_ item: ListItem, markerLength: Int) {
        // We need to render children but skip the first N characters of the first text node
        for child in item.children {
            if let paragraph = child as? Paragraph {
                var isFirst = true
                for inline in paragraph.children {
                    if isFirst, let text = inline as? Text {
                        // Skip the checkbox marker
                        let content = text.string
                        if content.count > markerLength {
                            let remaining = String(content.dropFirst(markerLength))
                            html += escapeHTML(remaining)
                        }
                        isFirst = false
                    } else {
                        visit(inline)
                        isFirst = false
                    }
                }
            } else {
                visit(child)
            }
        }
    }

    /// Convert SF Symbol name to unicode fallback
    private func sfSymbolToUnicode(_ symbol: String) -> String {
        // Map common SF Symbols to unicode equivalents for HTML rendering
        let symbolMap: [String: String] = [
            "checkmark.square.fill": "&#x2611;",     // ☑
            "square": "&#x2610;",                     // ☐
            "circle.lefthalf.filled": "&#x25D0;",   // ◐
            "minus.square": "&#x229F;",              // ⊟
            "questionmark.circle": "&#x2753;",      // ❓
            "exclamationmark.triangle": "&#x26A0;", // ⚠
            "xmark.circle": "&#x2717;",             // ✗
            "circle.fill": "&#x25CF;",              // ●
        ]

        return symbolMap[symbol] ?? "&#x25A1;" // Default: white square
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> () {
        html += "<blockquote>\n"
        descendInto(blockQuote)
        html += "</blockquote>\n"
    }

    mutating func visitThematicBreak(_ break: ThematicBreak) -> () {
        html += "<hr>\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> () {
        html += "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> () {
        html += "<br>\n"
    }

    // MARK: - GFM: Tables

    mutating func visitTable(_ table: Table) -> () {
        // Store column alignments for use in visitTableCell
        currentTableAlignments = table.columnAlignments
        html += "<table>\n"
        descendInto(table)
        html += "</table>\n"
        currentTableAlignments = []
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> () {
        html += "<thead>\n<tr>\n"
        descendInto(tableHead)
        html += "</tr>\n</thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> () {
        html += "<tbody>\n"
        descendInto(tableBody)
        html += "</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> () {
        html += "<tr>\n"
        descendInto(tableRow)
        html += "</tr>\n"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> () {
        let tag: String
        // Check if this cell is in the table head
        if tableCell.parent is Table.Head {
            tag = "th"
        } else {
            tag = "td"
        }

        // Get alignment from the stored column alignments
        var alignAttr = ""
        let columnIndex = tableCell.indexInParent
        if columnIndex < currentTableAlignments.count {
            switch currentTableAlignments[columnIndex] {
            case .left:
                alignAttr = " align=\"left\""
            case .center:
                alignAttr = " align=\"center\""
            case .right:
                alignAttr = " align=\"right\""
            case nil:
                break
            }
        }

        html += "<\(tag)\(alignAttr)>"
        descendInto(tableCell)
        html += "</\(tag)>\n"
    }

    // MARK: - GFM: Strikethrough

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> () {
        html += "<del>"
        descendInto(strikethrough)
        html += "</del>"
    }

    // MARK: - Inline HTML

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> () {
        // Security: Strip raw HTML by default
        // TODO: Add sanitizer option to allow safe HTML elements
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> () {
        // Security: Strip raw HTML blocks by default
        // TODO: Add sanitizer option to allow safe HTML blocks
    }

    // MARK: - Helpers

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

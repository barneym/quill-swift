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
        // Phase 0: Stub implementation
        // TODO(#1): Implement full HTML rendering
        let document = Document(parsing: markdown)
        var renderer = HTMLRenderer()
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

    // Track current table's column alignments for cell rendering
    private var currentTableAlignments: [Table.ColumnAlignment?] = []

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
        if language.isEmpty {
            html += "<pre><code>"
        } else {
            html += "<pre><code class=\"language-\(language)\">"
        }
        html += escapeHTML(codeBlock.code)
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
        if let checkbox = item.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            html += "<li class=\"task-list-item\"><input type=\"checkbox\" disabled\(checked)>"
            descendInto(item)
            html += "</li>\n"
        } else {
            html += "<li>"
            descendInto(item)
            html += "</li>\n"
        }
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

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

        /// Allow raw HTML in markdown (default: true for editor preview)
        /// When true, inline HTML and HTML blocks are rendered as-is
        public var allowRawHTML: Bool = true

        /// Annotate block elements with `data-line` / `data-line-end` attributes
        /// holding their 0-based source line span (default: false).
        /// Used by the preview for source ↔ preview scroll synchronization.
        public var includeSourceLines: Bool = false

        /// Produce minimal, presentation-free HTML (default: false).
        ///
        /// Intended for clipboard use, where rich-text editors (Google Docs, etc.)
        /// honor any styling they find. Emits only the structural tags a markdown
        /// construct implies: no classes, inline styles, syntax-highlighting spans,
        /// or form controls. Code blocks are a bare `<pre><code>` so the target
        /// editor picks its own fixed-width font. Implies `highlightCodeBlocks = false`.
        public var cleanHTML: Bool = false

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
            highlightCode: options.highlightCodeBlocks && !options.cleanHTML,
            allowRawHTML: options.allowRawHTML,
            includeSourceLines: options.includeSourceLines && !options.cleanHTML,
            cleanHTML: options.cleanHTML
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

    /// Whether to allow raw HTML pass-through
    let allowRawHTML: Bool

    /// Whether to emit data-line attributes for scroll sync
    let includeSourceLines: Bool

    /// Whether to emit minimal, presentation-free HTML
    let cleanHTML: Bool

    // Track current table's column alignments for cell rendering
    private var currentTableAlignments: [Table.ColumnAlignment?] = []

    init(
        isDarkTheme: Bool = false,
        highlightCode: Bool = true,
        allowRawHTML: Bool = true,
        includeSourceLines: Bool = false,
        cleanHTML: Bool = false
    ) {
        self.isDarkTheme = isDarkTheme
        self.highlightCode = highlightCode
        self.allowRawHTML = allowRawHTML
        self.includeSourceLines = includeSourceLines
        self.cleanHTML = cleanHTML
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
        html += "<h\(heading.level)\(lineAttributes(heading))>"
        descendInto(heading)
        html += "</h\(heading.level)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> () {
        // CommonMark: paragraphs in tight list items render without <p> tags
        if let item = paragraph.parent as? ListItem, let list = item.parent, Self.isTightList(list) {
            descendInto(paragraph)
            if paragraph.indexInParent < item.childCount - 1 {
                html += "\n"
            }
            return
        }
        html += "<p\(lineAttributes(paragraph))>"
        descendInto(paragraph)
        html += "</p>\n"
    }

    /// A list is loose if any of its items, or any blocks inside an item,
    /// are separated by a blank line (CommonMark §5.3).
    static func isTightList(_ list: Markup) -> Bool {
        func separatedByBlankLine(_ children: [Markup]) -> Bool {
            zip(children, children.dropFirst()).contains { previous, next in
                guard let end = previous.range?.upperBound, let start = next.range?.lowerBound else {
                    return false
                }
                // A range ending at column 1 stops before that line's content
                let lastLine = end.column <= 1 ? end.line - 1 : end.line
                return start.line > lastLine + 1
            }
        }
        let items = Array(list.children)
        if separatedByBlankLine(items) { return false }
        return !items.contains { separatedByBlankLine(Array($0.children)) }
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
        if language.isEmpty || cleanHTML {
            html += "<pre\(lineAttributes(codeBlock))><code>"
        } else {
            html += "<pre\(lineAttributes(codeBlock))><code class=\"language-\(escapeHTML(language))\">"
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
        let title = image.title.map { " title=\"\(escapeHTML($0))\"" } ?? ""

        if cleanHTML {
            html += "<img src=\"\(src)\" alt=\"\(alt)\"\(title)>"
            return
        }

        // Add responsive class for proper sizing in preview
        // CSS should handle max-width: 100% and proper table cell fitting.
        // Images load eagerly: lazy loading leaves off-screen images at zero
        // height, which shifts layout after scroll sync has positioned the view.
        html += "<img src=\"\(src)\" alt=\"\(alt)\"\(title) class=\"md-image\">"
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> () {
        html += "<ul\(lineAttributes(list))>\n"
        descendInto(list)
        html += "</ul>\n"
    }

    mutating func visitOrderedList(_ list: OrderedList) -> () {
        // Include start attribute if list doesn't start at 1
        let startAttr = list.startIndex != 1 ? " start=\"\(list.startIndex)\"" : ""
        html += "<ol\(startAttr)\(lineAttributes(list))>\n"
        descendInto(list)
        html += "</ol>\n"
    }

    mutating func visitListItem(_ item: ListItem) -> () {
        // Check for built-in checkbox first (standard [ ] and [x] syntax)
        if let checkbox = item.checkbox {
            // Standard checkboxes use HTML input elements
            let isChecked = checkbox == .checked
            html += renderStandardCheckboxListItem(isChecked: isChecked, item: item)
            descendInto(item)
            html += "</li>\n"
        } else if let customCheckbox = parseExtendedCheckbox(from: item) {
            // Handle extended checkbox syntax [/], [-], [?], [!], etc.
            // Extended checkboxes use SF Symbol unicode fallbacks
            html += renderExtendedCheckboxListItem(checkboxType: customCheckbox.type, item: item)
            // Render content without the checkbox marker
            renderListItemContentWithoutCheckbox(item, markerLength: customCheckbox.markerLength)
            html += "</li>\n"
        } else {
            html += "<li\(lineAttributes(item))>"
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

    /// Render a standard checkbox list item opener with HTML input element
    private func renderStandardCheckboxListItem(isChecked: Bool, item: ListItem) -> String {
        if cleanHTML {
            // Plain glyphs survive pasting into rich-text editors; form controls don't
            return "<li>\(isChecked ? "&#x2611;" : "&#x2610;") "
        }
        let checkedAttr = isChecked ? " checked" : ""
        let status = isChecked ? "complete" : "pending"
        return """
        <li class="task-list-item" data-checkbox-status="\(status)"\(lineAttributes(item))><input type="checkbox" class="task-checkbox"\(checkedAttr) disabled>
        """
    }

    /// Render an extended checkbox list item opener with SF Symbol unicode
    private func renderExtendedCheckboxListItem(checkboxType: CheckboxType, item: ListItem) -> String {
        if cleanHTML {
            return "<li>\(sfSymbolToUnicode(checkboxType.symbol)) "
        }
        let color = checkboxType.cssColor(isDark: isDarkTheme)
        let symbol = checkboxType.symbol
        let name = escapeHTML(checkboxType.name)

        // Use SF Symbol image tag with fallback unicode
        let symbolDisplay = sfSymbolToUnicode(symbol)

        return """
        <li class="task-list-item extended-checkbox" data-checkbox-id="\(escapeHTML(checkboxType.id))" title="\(name)"\(lineAttributes(item))><span class="checkbox-symbol" style="color: \(color);">\(symbolDisplay)</span>
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
        html += "<blockquote\(lineAttributes(blockQuote))>\n"
        descendInto(blockQuote)
        html += "</blockquote>\n"
    }

    mutating func visitThematicBreak(_ break: ThematicBreak) -> () {
        html += "<hr\(lineAttributes(`break`))>\n"
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
        html += "<table\(lineAttributes(table))>\n"
        descendInto(table)
        html += "</table>\n"
        currentTableAlignments = []
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> () {
        html += "<thead>\n<tr\(lineAttributes(tableHead))>\n"
        descendInto(tableHead)
        html += "</tr>\n</thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> () {
        html += "<tbody>\n"
        descendInto(tableBody)
        html += "</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> () {
        html += "<tr\(lineAttributes(tableRow))>\n"
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
        if allowRawHTML {
            // Pass through raw HTML as-is
            html += inlineHTML.rawHTML
        }
        // When allowRawHTML is false, HTML is stripped (no output)
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> () {
        if allowRawHTML {
            // Pass through raw HTML block as-is
            html += htmlBlock.rawHTML
            html += "\n"
        }
        // When allowRawHTML is false, HTML blocks are stripped (no output)
    }

    // MARK: - Helpers

    /// ` data-line="…" data-line-end="…"` for a block's 0-based source line span,
    /// or an empty string when source lines are disabled or unknown.
    private func lineAttributes(_ markup: Markup) -> String {
        guard includeSourceLines, let range = markup.range else { return "" }
        let start = range.lowerBound.line - 1
        // A range ending at column 1 stops before that line's first character
        let endLine = range.upperBound.column <= 1 ? range.upperBound.line - 1 : range.upperBound.line
        let end = max(start, endLine - 1)
        return " data-line=\"\(start)\" data-line-end=\"\(end)\""
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

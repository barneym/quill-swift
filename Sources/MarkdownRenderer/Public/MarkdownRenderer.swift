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

        /// Allow raw HTML in markdown (default: true). When false, raw HTML is
        /// removed entirely; when true, it is rendered per `rawHTMLPolicy`.
        public var allowRawHTML: Bool = true

        /// How allowed raw HTML is rendered (default: `.safe`, an allowlist of
        /// harmless tags — no scripts, styles, frames, forms or event handlers)
        public var rawHTMLPolicy: RawHTMLPolicy = .safe

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
        let document = Document(parsing: protectingTaskMarkers(in: markdown))
        var renderer = HTMLRenderer(
            isDarkTheme: options.isDarkTheme,
            highlightCode: options.highlightCodeBlocks && !options.cleanHTML,
            rawHTMLPolicy: options.allowRawHTML ? options.rawHTMLPolicy : .strip,
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

    /// Backslash-escape punctuation task markers (`- [*]`, `- [_]`, `- [~]` …)
    /// so the checkbox rule wins over emphasis and other inline syntax, as in
    /// Obsidian: in `- [*] foo*` the `*` would otherwise open emphasis. Escaped
    /// punctuation parses as the literal character, so the checkbox reads the
    /// same. Fenced code is left alone, and only characters are inserted within
    /// lines, so line numbers (scroll sync) are unchanged.
    static func protectingTaskMarkers(in markdown: String) -> String {
        guard markdown.contains("]") else { return markdown }
        var output: [Substring] = []
        var fence: (char: Character, length: Int)?
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            let indent = line.count - trimmed.count
            if let open = fence {
                let run = trimmed.prefix { $0 == open.char }
                if indent <= 3, run.count >= open.length,
                   trimmed.dropFirst(run.count).allSatisfy({ $0.isWhitespace }) {
                    fence = nil
                }
                output.append(line)
                continue
            }
            if indent <= 3, let first = trimmed.first, first == "`" || first == "~" {
                let run = trimmed.prefix { $0 == first }
                if run.count >= 3 {
                    fence = (first, run.count)
                    output.append(line)
                    continue
                }
            }
            output.append(Self.escapingTaskMarker(in: line))
        }
        return output.joined(separator: "\n")
    }

    private static let taskMarkerPattern = try! NSRegularExpression(
        pattern: #"^((?:[ \t]*>[ \t]?)*[ \t]*(?:[-*+]|\d{1,9}[.)])[ \t]+)\[([!-/:-@^-`{-~])\](?=[ \t]|$)"#
    )

    private static func escapingTaskMarker(in line: Substring) -> Substring {
        let text = String(line)
        let range = NSRange(text.startIndex..., in: text)
        guard let match = taskMarkerPattern.firstMatch(in: text, range: range),
              let markerRange = Range(match.range(at: 2), in: text) else {
            return line
        }
        return Substring(text[..<markerRange.lowerBound] + "\\" + text[markerRange.lowerBound...])
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
    let rawHTMLPolicy: RawHTMLPolicy

    /// Whether to emit data-line attributes for scroll sync
    let includeSourceLines: Bool

    /// Whether to emit minimal, presentation-free HTML
    let cleanHTML: Bool

    // Track current table's column alignments for cell rendering
    private var currentTableAlignments: [Table.ColumnAlignment?] = []

    init(
        isDarkTheme: Bool = false,
        highlightCode: Bool = true,
        rawHTMLPolicy: RawHTMLPolicy = .safe,
        includeSourceLines: Bool = false,
        cleanHTML: Bool = false
    ) {
        self.isDarkTheme = isDarkTheme
        self.highlightCode = highlightCode
        self.rawHTMLPolicy = rawHTMLPolicy
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
        let destination = link.destination ?? ""
        // Unsafe schemes (javascript:, data:, …) lose their href but keep their text
        html += HTMLSanitizer.isSafeURL(destination) ? "<a href=\"\(escapeHTML(destination))\">" : "<a>"
        descendInto(link)
        html += "</a>"
    }

    mutating func visitImage(_ image: Image) -> () {
        let source = image.source ?? ""
        let src = HTMLSanitizer.isSafeURL(source, allowImageData: true) ? escapeHTML(source) : ""
        let (altText, size) = Self.splitObsidianSize(image.plainText)
        let alt = escapeHTML(altText)
        let title = image.title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
        let sizeAttributes = (size.width.map { " width=\"\($0)\"" } ?? "") + (size.height.map { " height=\"\($0)\"" } ?? "")

        if cleanHTML {
            html += "<img src=\"\(src)\" alt=\"\(alt)\"\(title)\(sizeAttributes)>"
            return
        }

        // Add responsive class for proper sizing in preview
        // CSS should handle max-width: 100% and proper table cell fitting.
        // Images load eagerly: lazy loading leaves off-screen images at zero
        // height, which shifts layout after scroll sync has positioned the view.
        html += "<img src=\"\(src)\" alt=\"\(alt)\"\(title)\(sizeAttributes) class=\"md-image\">"
    }

    /// Obsidian image size syntax: `![alt|300](src)` or `![alt|300x200](src)`.
    static func splitObsidianSize(_ alt: String) -> (alt: String, size: (width: Int?, height: Int?)) {
        guard let bar = alt.lastIndex(of: "|") else { return (alt, (nil, nil)) }
        let spec = alt[alt.index(after: bar)...].trimmingCharacters(in: .whitespaces)
        let parts = spec.split(separator: "x", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), let width = Int(parts[0]), width >= 0 else { return (alt, (nil, nil)) }
        var height: Int?
        if parts.count == 2 {
            guard let value = Int(parts[1]) else { return (alt, (nil, nil)) }
            height = value
        }
        let text = String(alt[..<bar]).trimmingCharacters(in: .whitespaces)
        return (text, (width > 0 ? width : nil, height))
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
            // Standard checkboxes use HTML input elements (the preview makes them
            // clickable; ContentView.toggleCheckboxInSource counts the same set)
            let isChecked = checkbox == .checked
            html += renderStandardCheckboxListItem(isChecked: isChecked, item: item)
            descendInto(item)
            html += "</li>\n"
        } else if let extended = parseExtendedCheckbox(from: item) {
            // Obsidian-style alternate checkbox: [/], [-], [?], [b], ... or any
            // other single character (Obsidian treats every `[c]` as a task)
            html += renderExtendedCheckboxListItem(checkboxType: extended.type, item: item)
            renderListItemContentWithoutCheckbox(item, markerLength: extended.markerLength)
            html += "</li>\n"
        } else {
            html += "<li\(lineAttributes(item))>"
            descendInto(item)
            html += "</li>\n"
        }
    }

    /// Parse an extended checkbox marker (`[c] ` for any single character `c`
    /// other than the standard ` `, `x`, `X`) at the start of a list item.
    private func parseExtendedCheckbox(from item: ListItem) -> (type: CheckboxType, markerLength: Int)? {
        guard let paragraph = item.child(at: 0) as? Paragraph else { return nil }

        // The parser can split "[*] " across several Text nodes (brackets and
        // emphasis delimiters become separate nodes), so join the leading text
        var prefix = ""
        for inline in paragraph.children {
            guard let text = inline as? Text else { break }
            prefix += text.string
            if prefix.count >= 4 { break }
        }

        let chars = Array(prefix.prefix(4))
        guard chars.count >= 3, chars[0] == "[", chars[2] == "]" else { return nil }
        let markerLength: Int
        if chars.count == 4 {
            guard chars[3] == " " else { return nil }
            markerLength = 4
        } else {
            // A bare "- [c]" with no text after it
            guard paragraph.childCount == 1 else { return nil }
            markerLength = 3
        }

        var marker = chars[1]
        // Smart punctuation turns `["]` into `[”]`; map curly quotes back to the
        // markdown characters (Obsidian's `"` Quote type)
        switch marker {
        case "\u{201C}", "\u{201D}": marker = "\""
        case "\u{2018}", "\u{2019}": marker = "'"
        default: break
        }
        // Standard checkboxes are handled by swift-markdown; skip whitespace/brackets
        if marker == "x" || marker == "X" || marker.isWhitespace || marker == "[" || marker == "]" {
            return nil
        }

        return (CheckboxRegistry.shared.resolvedType(forMarker: String(marker)), markerLength)
    }

    /// Render a standard checkbox list item opener with HTML input element
    private func renderStandardCheckboxListItem(isChecked: Bool, item: ListItem) -> String {
        if cleanHTML {
            // Keep the markdown marker as text: no editor turns pasted HTML into
            // native checkboxes, and literal markers survive for scripted fix-ups
            return "<li>\(isChecked ? "[x]" : "[ ]") "
        }
        let checkedAttr = isChecked ? " checked" : ""
        let status = isChecked ? "complete" : "pending"
        let task = isChecked ? "x" : " "
        return """
        <li class="task-list-item" data-task="\(task)" data-checkbox-status="\(status)"\(lineAttributes(item))><input type="checkbox" class="task-checkbox"\(checkedAttr) disabled>
        """
    }

    /// Render an extended checkbox list item opener (the `.checkbox-symbol` span
    /// is emitted with the content). Presentation (icon, color)
    /// comes from CSS keyed on `data-task` (see `CheckboxRegistry.stylesheet`).
    private func renderExtendedCheckboxListItem(checkboxType: CheckboxType, item: ListItem) -> String {
        let id = escapeHTML(checkboxType.id)
        if cleanHTML {
            return "<li>[\(id)] "
        }
        let name = escapeHTML(checkboxType.name)
        return """
        <li class="task-list-item extended-checkbox" data-task="\(id)" data-checkbox-id="\(id)" title="\(name)"\(lineAttributes(item))>
        """
    }

    /// Render list item content, skipping the checkbox marker at the start of
    /// the first paragraph (which may span several leading Text nodes)
    private mutating func renderListItemContentWithoutCheckbox(_ item: ListItem, markerLength: Int) {
        for child in item.children {
            guard child.indexInParent == 0, let paragraph = child as? Paragraph else {
                visit(child)
                continue
            }

            let isTight = item.parent.map(Self.isTightList) ?? true
            if !isTight {
                html += "<p\(lineAttributes(paragraph))>"
            }
            // The symbol goes inside the first paragraph so it stays on the text's
            // line in loose lists too (clean HTML emitted the literal marker instead)
            if !cleanHTML {
                html += "<span class=\"checkbox-symbol\"></span>"
            }

            var remaining = markerLength
            for inline in paragraph.children {
                if remaining > 0, let text = inline as? Text {
                    let content = text.string
                    if content.count <= remaining {
                        remaining -= content.count
                    } else {
                        html += escapeHTML(String(content.dropFirst(remaining)))
                        remaining = 0
                    }
                } else {
                    remaining = 0
                    visit(inline)
                }
            }

            if isTight {
                if paragraph.indexInParent < item.childCount - 1 {
                    html += "\n"
                }
            } else {
                html += "</p>\n"
            }
        }
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
        html += HTMLSanitizer.render(inlineHTML.rawHTML, policy: rawHTMLPolicy)
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> () {
        let rendered = HTMLSanitizer.render(htmlBlock.rawHTML, policy: rawHTMLPolicy)
        guard !rendered.isEmpty else { return }
        html += rawHTMLPolicy == .escape ? "<p>\(rendered)</p>\n" : rendered + "\n"
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

import AppKit
import MarkdownRenderer

/// Exports markdown documents to standalone HTML files.
///
/// Creates complete HTML documents with:
/// - Inlined CSS styling matching preview appearance
/// - User theme customizations applied
/// - Proper encoding and meta tags
/// - Optional syntax highlighting for code blocks
@MainActor
struct HTMLExporter {

    // MARK: - Properties

    /// The markdown text to export
    let markdown: String

    /// The document title (filename without extension)
    let title: String

    /// Whether to use dark theme
    let isDark: Bool

    /// User font size setting
    let previewFontSize: CGFloat

    /// User line height setting
    let previewLineHeight: CGFloat

    /// User custom CSS
    let customCSS: String

    // MARK: - Initialization

    init(markdown: String, title: String, isDark: Bool = false) {
        self.markdown = markdown
        self.title = title
        self.isDark = isDark
        // Capture values from ThemeManager at init time
        let themeManager = ThemeManager.shared
        self.previewFontSize = themeManager.previewFontSize
        self.previewLineHeight = themeManager.previewLineHeight
        self.customCSS = themeManager.customCSS
    }

    // MARK: - Export

    /// Generate a complete standalone HTML document
    func generateHTML() -> String {
        // Render markdown to HTML body
        var options = MarkdownRenderer.Options()
        options.isDarkTheme = isDark
        let bodyContent = MarkdownRenderer.renderHTML(from: markdown, options: options)

        // Get theme CSS
        let themeCSS = isDark ? Self.darkThemeCSS : Self.lightThemeCSS

        // Build variable overrides from user settings
        var customVars = ""
        customVars += "--qs-font-size: \(Int(previewFontSize))px;\n"
        customVars += "--qs-line-height: \(previewLineHeight);\n"

        let variableOverrides = customVars.isEmpty ? "" : """
        :root {
            \(customVars)
        }
        """

        let userCSS = customCSS

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta name="generator" content="QuillSwift">
            <title>\(escapeHTML(title))</title>
            <style>
        \(Self.baseCSS)
        \(themeCSS)
        \(variableOverrides)
        \(userCSS)
            </style>
        </head>
        <body>
            <article class="markdown-body">
        \(bodyContent)
            </article>
        </body>
        </html>
        """
    }

    /// Export to a file at the specified URL
    func export(to url: URL) throws {
        let html = generateHTML()
        try html.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Copy HTML to clipboard
    func copyToClipboard() {
        let html = generateHTML()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(html, forType: .html)
        pasteboard.setString(html, forType: .string)
    }

    // MARK: - Helpers

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Show Save Panel

    /// Show save panel and export HTML
    static func showExportPanel(
        markdown: String,
        title: String,
        isDark: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(title).html"
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        panel.message = "Export document as HTML"

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(false)
                return
            }

            let exporter = HTMLExporter(markdown: markdown, title: title, isDark: isDark)
            do {
                try exporter.export(to: url)
                completion(true)
            } catch {
                print("Failed to export HTML: \(error)")
                completion(false)
            }
        }
    }
}

// MARK: - CSS Definitions

extension HTMLExporter {

    /// Base CSS (theme-independent)
    static let baseCSS = """
    /* Reset and base styles */
    * {
        box-sizing: border-box;
    }

    html {
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
    }

    body {
        margin: 0;
        padding: 0;
        font-family: var(--qs-font-body);
        font-size: var(--qs-font-size);
        line-height: var(--qs-line-height);
        color: var(--qs-color-text);
        background-color: var(--qs-color-background);
    }

    .markdown-body {
        max-width: 800px;
        margin: 0 auto;
        padding: 24px 32px;
    }

    /* Headings */
    h1, h2, h3, h4, h5, h6 {
        margin-top: 1.5em;
        margin-bottom: 0.5em;
        font-weight: 600;
        line-height: 1.25;
        color: var(--qs-color-heading);
    }

    h1 { font-size: 2em; border-bottom: 1px solid var(--qs-color-border); padding-bottom: 0.3em; }
    h2 { font-size: 1.5em; border-bottom: 1px solid var(--qs-color-border); padding-bottom: 0.3em; }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    h5 { font-size: 0.875em; }
    h6 { font-size: 0.85em; color: var(--qs-color-secondary); }

    /* Paragraphs */
    p {
        margin-top: 0;
        margin-bottom: 1em;
    }

    /* Links */
    a {
        color: var(--qs-color-link);
        text-decoration: none;
    }

    a:hover {
        text-decoration: underline;
    }

    /* Lists */
    ul, ol {
        margin-top: 0;
        margin-bottom: 1em;
        padding-left: 2em;
    }

    li {
        margin-bottom: 0.25em;
    }

    /* Code */
    code {
        font-family: var(--qs-font-mono);
        font-size: 0.875em;
        padding: 0.2em 0.4em;
        background-color: var(--qs-color-code-bg);
        border-radius: 3px;
    }

    pre {
        margin-top: 0;
        margin-bottom: 1em;
        padding: 16px;
        overflow-x: auto;
        background-color: var(--qs-color-code-bg);
        border-radius: 6px;
    }

    pre code {
        padding: 0;
        background-color: transparent;
        font-size: 0.875em;
        line-height: 1.45;
    }

    /* Blockquotes */
    blockquote {
        margin: 0 0 1em 0;
        padding: 0 1em;
        border-left: 4px solid var(--qs-color-border);
        color: var(--qs-color-secondary);
    }

    /* Horizontal rule */
    hr {
        height: 0.25em;
        padding: 0;
        margin: 24px 0;
        background-color: var(--qs-color-border);
        border: 0;
    }

    /* Tables */
    table {
        border-spacing: 0;
        border-collapse: collapse;
        margin-top: 0;
        margin-bottom: 1em;
        width: max-content;
        max-width: 100%;
        overflow: auto;
    }

    th, td {
        padding: 6px 13px;
        border: 1px solid var(--qs-color-border);
    }

    th {
        font-weight: 600;
        background-color: var(--qs-color-table-header);
    }

    tr:nth-child(2n) {
        background-color: var(--qs-color-table-row-alt);
    }

    /* Images */
    img {
        max-width: 100%;
        height: auto;
    }

    /* Task lists */
    .task-list-item {
        list-style-type: none;
        margin-left: -1.5em;
    }

    .task-list-item input[type="checkbox"] {
        margin-right: 0.5em;
    }

    /* Custom checkboxes */
    .task-list-item .checkbox-symbol {
        display: inline-block;
        width: 1.2em;
        text-align: center;
        margin-right: 0.4em;
    }

    .task-list-item.custom-checkbox input[type="checkbox"] {
        display: none;
    }

    /* Strong and emphasis */
    strong { font-weight: 600; }
    em { font-style: italic; }
    del { text-decoration: line-through; }

    /* Print styles */
    @media print {
        body {
            background-color: white !important;
            color: black !important;
        }
        .markdown-body {
            max-width: none;
            padding: 0;
        }
        pre {
            white-space: pre-wrap;
            word-wrap: break-word;
        }
    }
    """

    /// Light theme CSS variables
    static let lightThemeCSS = """
    :root {
        --qs-font-body: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        --qs-font-mono: ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, monospace;
        --qs-font-size: 16px;
        --qs-line-height: 1.6;

        --qs-color-text: #24292f;
        --qs-color-heading: #1f2328;
        --qs-color-secondary: #57606a;
        --qs-color-background: #ffffff;
        --qs-color-link: #0969da;
        --qs-color-border: #d0d7de;
        --qs-color-code-bg: #f6f8fa;
        --qs-color-table-header: #f6f8fa;
        --qs-color-table-row-alt: #f6f8fa;
    }
    """

    /// Dark theme CSS variables
    static let darkThemeCSS = """
    :root {
        --qs-font-body: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        --qs-font-mono: ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, monospace;
        --qs-font-size: 16px;
        --qs-line-height: 1.6;

        --qs-color-text: #c9d1d9;
        --qs-color-heading: #e6edf3;
        --qs-color-secondary: #8b949e;
        --qs-color-background: #0d1117;
        --qs-color-link: #58a6ff;
        --qs-color-border: #30363d;
        --qs-color-code-bg: #161b22;
        --qs-color-table-header: #161b22;
        --qs-color-table-row-alt: #161b22;
    }
    """
}

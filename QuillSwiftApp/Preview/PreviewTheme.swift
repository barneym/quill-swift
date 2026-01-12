import AppKit

/// Handles CSS theming for the preview view.
///
/// Provides light and dark themes that follow system appearance,
/// with CSS variable system for customization.
struct PreviewTheme {

    // MARK: - Properties

    /// The CSS content for this theme
    let css: String

    /// Whether this is a dark theme
    let isDark: Bool

    // MARK: - Initialization

    init(css: String, isDark: Bool) {
        self.css = css
        self.isDark = isDark
    }

    // MARK: - Theme Instances

    /// Default theme that follows system appearance
    static var `default`: PreviewTheme {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .dark : .light
    }

    /// Light theme
    static let light = PreviewTheme(css: lightCSS, isDark: false)

    /// Dark theme
    static let dark = PreviewTheme(css: darkCSS, isDark: true)

    // MARK: - HTML Wrapping

    /// Wraps HTML content in a complete HTML document with styling
    func wrapHTML(_ bodyContent: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
            \(baseCSS)
            \(css)
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
}

// MARK: - Base CSS

private let baseCSS = """
/* Reset and base styles */
* {
    box-sizing: border-box;
}

html {
    font-size: 16px;
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
    margin-top: var(--qs-spacing-heading);
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
    margin-bottom: var(--qs-spacing-paragraph);
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
    margin-bottom: var(--qs-spacing-paragraph);
    padding-left: 2em;
}

li {
    margin-bottom: 0.25em;
}

li > p {
    margin-bottom: 0.5em;
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
    margin-bottom: var(--qs-spacing-paragraph);
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
    margin: 0 0 var(--qs-spacing-paragraph) 0;
    padding: 0 1em;
    border-left: 4px solid var(--qs-color-border);
    color: var(--qs-color-secondary);
}

blockquote > :first-child {
    margin-top: 0;
}

blockquote > :last-child {
    margin-bottom: 0;
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
    margin-bottom: var(--qs-spacing-paragraph);
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
    border-radius: var(--qs-image-border-radius);
}

/* Task lists (checkboxes) */
.task-list-item {
    list-style-type: none;
    margin-left: -1.5em;
}

.task-list-item input[type="checkbox"] {
    margin-right: 0.5em;
    vertical-align: middle;
}

/* Custom checkboxes with SF Symbol fallback */
.task-list-item.custom-checkbox {
    position: relative;
}

.task-list-item .checkbox-symbol {
    display: inline-block;
    width: 1.2em;
    text-align: center;
    margin-right: 0.4em;
    font-size: 1.1em;
    vertical-align: middle;
    cursor: default;
}

/* Hide standard checkbox for custom types */
.task-list-item.custom-checkbox input[type="checkbox"] {
    display: none;
}

/* Strong and emphasis */
strong {
    font-weight: 600;
}

em {
    font-style: italic;
}

/* Strikethrough */
del {
    text-decoration: line-through;
}

/* Inline elements */
kbd {
    display: inline-block;
    padding: 3px 5px;
    font-size: 0.75em;
    font-family: var(--qs-font-mono);
    line-height: 1;
    color: var(--qs-color-text);
    background-color: var(--qs-color-code-bg);
    border: 1px solid var(--qs-color-border);
    border-radius: 3px;
    box-shadow: inset 0 -1px 0 var(--qs-color-border);
}

mark {
    background-color: var(--qs-color-highlight);
    padding: 0.1em 0.2em;
}
"""

// MARK: - Light Theme CSS

private let lightCSS = """
:root {
    /* Typography */
    --qs-font-body: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    --qs-font-mono: ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, monospace;
    --qs-font-size: 16px;
    --qs-line-height: 1.6;

    /* Colors - Light theme */
    --qs-color-text: #24292f;
    --qs-color-heading: #1f2328;
    --qs-color-secondary: #57606a;
    --qs-color-background: #ffffff;
    --qs-color-link: #0969da;
    --qs-color-border: #d0d7de;
    --qs-color-code-bg: #f6f8fa;
    --qs-color-table-header: #f6f8fa;
    --qs-color-table-row-alt: #f6f8fa;
    --qs-color-highlight: #fff8c5;

    /* Spacing */
    --qs-spacing-paragraph: 1em;
    --qs-spacing-heading: 1.5em;

    /* Images */
    --qs-image-border-radius: 4px;
}
"""

// MARK: - Dark Theme CSS

private let darkCSS = """
:root {
    /* Typography */
    --qs-font-body: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    --qs-font-mono: ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, monospace;
    --qs-font-size: 16px;
    --qs-line-height: 1.6;

    /* Colors - Dark theme */
    --qs-color-text: #c9d1d9;
    --qs-color-heading: #e6edf3;
    --qs-color-secondary: #8b949e;
    --qs-color-background: #0d1117;
    --qs-color-link: #58a6ff;
    --qs-color-border: #30363d;
    --qs-color-code-bg: #161b22;
    --qs-color-table-header: #161b22;
    --qs-color-table-row-alt: #161b22;
    --qs-color-highlight: #634c00;

    /* Spacing */
    --qs-spacing-paragraph: 1em;
    --qs-spacing-heading: 1.5em;

    /* Images */
    --qs-image-border-radius: 4px;
}
"""

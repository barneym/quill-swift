import AppKit
import MarkdownRenderer

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
        wrapHTML(bodyContent, fontSize: nil, lineHeight: nil, customCSS: nil)
    }

    /// Wraps HTML content with custom theme settings from ThemeManager
    func wrapHTML(
        _ bodyContent: String,
        fontSize: CGFloat?,
        lineHeight: CGFloat?,
        customCSS: String?,
        enableMermaid: Bool = false,
        enableMath: Bool = false
    ) -> String {
        // Build custom variable overrides if settings provided
        var variableOverrides = ""
        if let fontSize = fontSize {
            variableOverrides += "--qs-font-size: \(Int(fontSize))px;\n"
        }
        if let lineHeight = lineHeight {
            variableOverrides += "--qs-line-height: \(lineHeight);\n"
        }

        let overrideCSS = variableOverrides.isEmpty ? "" : """
        :root {
            \(variableOverrides)
        }
        """

        let userCSS = customCSS ?? ""

        // Include Mermaid script if enabled (themed to match the page)
        let mermaidScript = enableMermaid ? mermaidScriptContent(isDark: isDark) : ""

        // Include KaTeX scripts if enabled
        let mathScript = enableMath ? katexScriptContent : ""
        let mathCSS = enableMath ? katexCSSContent : ""

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            \(PreviewSecurity.contentSecurityPolicyTag)
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \(mathCSS)
            <style>
            \(baseCSS)
            \(css)
            \(diagramAndMathCSS)
            \(CheckboxRegistry.shared.stylesheet(isDark: isDark))
            \(overrideCSS)
            \(userCSS)
            </style>
        </head>
        <body>
            <article class="markdown-body">
            \(bodyContent)
            </article>
            \(checkboxScript)
            \(mermaidScript)
            \(mathScript)
        </body>
        </html>
        """
    }
}

// MARK: - Checkbox Interaction Script

private let checkboxScript = """
<script nonce="\(PreviewSecurity.scriptNonce)">
(function() {
    // Find all task list checkboxes and make them interactive
    const checkboxes = document.querySelectorAll('.task-list-item input[type="checkbox"].task-checkbox');

    checkboxes.forEach((checkbox, index) => {
        // Remove disabled attribute to make clickable
        checkbox.removeAttribute('disabled');
        checkbox.style.cursor = 'pointer';

        // Add click handler
        checkbox.addEventListener('change', function(e) {
            // Prevent default and handle manually
            const isChecked = this.checked;

            // Send message to Swift
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.checkboxToggle) {
                window.webkit.messageHandlers.checkboxToggle.postMessage({
                    index: index,
                    checked: isChecked
                });
            }
        });
    });
})();
</script>
"""

// MARK: - Base CSS

private let baseCSS = """
/* YAML front matter shown as a properties table (like Obsidian's Properties) */
.qs-frontmatter {
    margin: 0 0 1.5em 0;
    padding: 0.4em 0.8em;
    border: 1px solid var(--qs-color-border);
    border-radius: 6px;
    font-size: 0.85em;
    color: var(--qs-color-secondary);
}
.qs-frontmatter table { border: none; margin: 0; width: 100%; border-collapse: collapse; }
.qs-frontmatter tr, .qs-frontmatter tr:nth-child(2n) { background: transparent; }
.qs-frontmatter th, .qs-frontmatter td { border: none; padding: 0.15em 0.6em 0.15em 0; vertical-align: top; text-align: left; }
.qs-frontmatter th { font-weight: 600; white-space: nowrap; width: 1%; background: transparent; }
.qs-frontmatter td { word-break: break-word; }
.qs-frontmatter pre { margin: 0; background: transparent; padding: 0; }
.qs-property-item {
    display: inline-block;
    padding: 0 0.5em;
    margin: 0.1em 0.2em 0.1em 0;
    border-radius: 999px;
    background: var(--qs-color-code-bg);
    border: 1px solid var(--qs-color-border);
}

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

/* Markdown images with responsive sizing */
img.md-image {
    max-width: 100%;
    height: auto;
    display: inline-block;
    cursor: pointer;
    transition: transform 0.2s ease;
}

img.md-image:hover {
    opacity: 0.9;
}

/* Images in table cells should fit properly */
td img.md-image,
th img.md-image {
    max-width: 200px;
    max-height: 150px;
    object-fit: contain;
}

/* Task lists (checkboxes) */
.task-list-item {
    list-style-type: none;
    margin-left: -1.5em;
    position: relative;
}

/* Checkbox boxes and icons: CheckboxRegistry.stylesheet(isDark:), appended in wrapHTML */
.task-list-item .checkbox-symbol {
    cursor: default;
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
    --qs-color-error-text: #cf222e;
    --qs-color-error-bg: #ffebe9;
    --qs-color-error-border: #ff818266;

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
    --qs-color-error-text: #ff7b72;
    --qs-color-error-bg: #f851491a;
    --qs-color-error-border: #f8514966;

    /* Spacing */
    --qs-spacing-paragraph: 1em;
    --qs-spacing-heading: 1.5em;

    /* Images */
    --qs-image-border-radius: 4px;
}
"""

// MARK: - Bundled Libraries

/// Mermaid and KaTeX ship inside the app (`PreviewAssets`, a folder reference
/// copied verbatim into Resources) and load from their `file:` URLs: the
/// preview page is a temporary file with read access to `/` (see
/// `PreviewView.Coordinator.load`), so it works offline and never contacts a CDN.
enum PreviewAssets {
    /// `…/QuillSwift.app/Contents/Resources/PreviewAssets`, if bundled
    static let folderURL: URL? = Bundle.main.url(forResource: "PreviewAssets", withExtension: nil)

    static func url(_ relativePath: String) -> String? {
        guard let folderURL else { return nil }
        let url = folderURL.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url.absoluteString.replacingOccurrences(of: "\"", with: "%22")
    }

    static let mermaidJS = url("mermaid/mermaid.min.js")
    static let katexJS = url("katex/katex.min.js")
    static let katexCSS = url("katex/katex.min.css")
}

// MARK: - Mermaid Diagram Script

/// Renders ```mermaid blocks (`pre > code.language-mermaid`, emitted unhighlighted
/// by the renderer) into `.mermaid-diagram` containers that keep the block's
/// source-line anchors. Errors show in a small box instead of breaking the page.
private func mermaidScriptContent(isDark: Bool) -> String {
    guard let src = PreviewAssets.mermaidJS else { return "" }
    return """
    <script nonce="\(PreviewSecurity.scriptNonce)" src="\(src)"></script>
    <script nonce="\(PreviewSecurity.scriptNonce)">
    (function() {
        if (typeof mermaid === 'undefined') { return; }
        mermaid.initialize({
            startOnLoad: false,
            securityLevel: 'strict',
            theme: \(isDark ? "'dark'" : "'default'"),
            themeVariables: \(isDark ? mermaidDarkThemeVariables : mermaidLightThemeVariables),
            maxTextSize: 50000,
            flowchart: { useMaxWidth: true },
            sequence: { useMaxWidth: true }
        });

        function showError(container, message) {
            container.classList.add('mermaid-error');
            container.textContent = '';
            var title = document.createElement('div');
            title.className = 'mermaid-error-title';
            title.textContent = 'Mermaid diagram could not be rendered';
            var detail = document.createElement('pre');
            detail.textContent = String(message || 'Unknown error').trim();
            container.appendChild(title);
            container.appendChild(detail);
        }

        var queue = Promise.resolve();
        document.querySelectorAll('pre > code.language-mermaid').forEach(function(codeBlock, index) {
            var pre = codeBlock.parentElement;
            var content = codeBlock.textContent;

            var container = document.createElement('div');
            container.className = 'mermaid-diagram';
            container.id = 'mermaid-' + index;
            // Keep source-line anchors for scroll sync
            if (pre.dataset.line !== undefined) {
                container.dataset.line = pre.dataset.line;
                container.dataset.lineEnd = pre.dataset.lineEnd;
            }
            pre.parentNode.replaceChild(container, pre);

            if (content.length > 50000) {
                showError(container, 'Diagram too large (max 50 KB)');
                return;
            }

            // One diagram at a time: Mermaid's renderer shares layout state
            queue = queue.then(function() {
                var id = 'mermaid-svg-' + index;
                return mermaid.render(id, content).then(function(result) {
                    container.innerHTML = result.svg;
                }).catch(function(err) {
                    showError(container, err && (err.message || err.str) || err);
                    // A failed render can leave its scratch element behind
                    ['d' + id, id].forEach(function(leftover) {
                        var el = document.getElementById(leftover);
                        if (el && !container.contains(el)) { el.remove(); }
                    });
                });
            });
        });
    })();
    </script>
    """
}

private let diagramAndMathCSS = """
.mermaid-diagram {
    display: flex;
    justify-content: center;
    margin: 1em 0;
    overflow-x: auto;
}
.mermaid-diagram svg {
    max-width: 100%;
    height: auto;
}
.mermaid-diagram.mermaid-error {
    display: block;
    padding: 8px 12px;
    border: 1px solid var(--qs-color-error-border);
    border-radius: 6px;
    background-color: var(--qs-color-error-bg);
    font-size: 0.875em;
}
.mermaid-error-title {
    font-weight: 600;
    color: var(--qs-color-error-text);
    margin-bottom: 4px;
}
.mermaid-diagram.mermaid-error pre {
    margin: 0;
    padding: 0;
    background: transparent;
    white-space: pre-wrap;
    font-size: 0.85em;
    color: var(--qs-color-secondary);
}

/* Math: .qs-math spans from the renderer, typeset by KaTeX */
.qs-math[data-display="true"] { display: block; }
.qs-math-block { margin: 0 0 var(--qs-spacing-paragraph) 0; }
.katex-display { overflow-x: auto; overflow-y: hidden; padding: 2px 0; }
.qs-math-block .katex-display { margin: 0.5em 0; }

/* Obsidian plugin blocks (Dataview, Tasks): shown as code with a caption */
.qs-block-caption {
    font-size: 0.75em;
    font-weight: 500;
    color: var(--qs-color-secondary);
    margin: 0 0 4px 2px;
    letter-spacing: 0.02em;
}
.qs-block-caption + pre { margin-top: 0; }
"""

// MARK: - KaTeX Math Script

private var katexCSSContent: String {
    guard let href = PreviewAssets.katexCSS else { return "" }
    return "<link rel=\"stylesheet\" href=\"\(href)\">"
}

/// Typesets each `.qs-math` span the renderer emitted (the renderer already
/// found the math, so no delimiter scanning of page text happens here).
private var katexScriptContent: String {
    guard let src = PreviewAssets.katexJS else { return "" }
    return """
    <script nonce="\(PreviewSecurity.scriptNonce)" src="\(src)"></script>
    <script nonce="\(PreviewSecurity.scriptNonce)">
    (function() {
        if (typeof katex === 'undefined') { return; }
        document.querySelectorAll('.qs-math').forEach(function(el) {
            var tex = el.textContent;
            try {
                katex.render(tex, el, {
                    displayMode: el.getAttribute('data-display') === 'true',
                    throwOnError: false,
                    errorColor: '#cc0000',
                    strict: false,
                    trust: false,
                    maxSize: 10,
                    maxExpand: 1000
                });
            } catch (err) {
                el.textContent = tex;
                el.title = String(err && err.message || err);
            }
        });
    })();
    </script>
    """
}

// MARK: - Content Security Policy

/// Defense in depth for the preview page: even if hostile markup got past the
/// renderer's sanitizer, only QuillSwift's own scripts (carrying this launch's
/// nonce) may run — the bundled Mermaid/KaTeX files carry it too, so no
/// script runs on its location alone. Styles and fonts may also come from
/// `file:` (KaTeX's stylesheet and fonts in the app bundle); nothing loads from
/// the network except images. Injected WKUserScripts are not subject to page CSP.
enum PreviewSecurity {
    /// UserDefaults key for Settings → Preview → "Render HTML in Markdown"
    static let renderRawHTMLKey = "renderRawHTML"

    /// Stable for the process so re-renders produce identical HTML (the
    /// preview only reloads when its HTML changes)
    static let scriptNonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")

    static var contentSecurityPolicyTag: String {
        let policy = [
            "default-src 'none'",
            "script-src 'nonce-\(scriptNonce)'",
            "style-src 'unsafe-inline' file:",
            "font-src file: data:",
            "img-src * data: blob: file:",
            "media-src * data: blob: file:",
            "connect-src 'none'",
            "frame-src 'none'",
            "object-src 'none'",
            "form-action 'none'",
            // The app sets <base> to the document's folder (sanitizer strips any in content)
            "base-uri file:"
        ].joined(separator: "; ")
        return "<meta http-equiv=\"Content-Security-Policy\" content=\"\(policy)\">"
    }
}

// MARK: - Mermaid Palettes

/// Series colors (pie slices, git branches, journey/timeline sections).
/// Mermaid's `dark` theme derives them by darkening its primary color, leaving
/// near-black slices on a dark page, and the `default` theme mixes near-white
/// and neon fills. Both modes use Catppuccin Mocha pastels (the palette of the
/// user's Obsidian theme and QuillSwift's checkboxes) with dark labels.
private let mermaidSeries = ["#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#94e2d5", "#89dceb",
                                 "#89b4fa", "#cba6f7", "#f5c2e7", "#b4befe", "#eba0ac", "#f2cdcd"]

private let mermaidFont = "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif"

/// Theme variables for the series palette; `ink` is the label/title color
private func mermaidThemeVariables(isDark: Bool) -> String {
    let labelOnFill = "#1e1e2e"
    let ink = isDark ? "#cdd6f4" : "#1f2328"
    var vars: [String] = ["fontFamily: \"\(mermaidFont)\""]
    for (i, color) in mermaidSeries.enumerated() {
        vars.append("pie\(i + 1): '\(color)'")
        vars.append("cScale\(i): '\(color)'")
        vars.append("cScaleLabel\(i): '\(labelOnFill)'")
        if i < 8 {
            vars.append("git\(i): '\(color)'")
            vars.append("gitBranchLabel\(i): '\(labelOnFill)'")
        }
    }
    vars += [
        "pieSectionTextColor: '\(labelOnFill)'",
        "pieStrokeColor: '\(isDark ? "#11111b" : "#ffffff")'", "pieStrokeWidth: '1px'",
        "pieOuterStrokeColor: '\(isDark ? "#45475a" : "#d0d7de")'",
        "pieTitleTextColor: '\(ink)'", "pieLegendTextColor: '\(ink)'", "pieOpacity: '1'"
    ]
    return "{ " + vars.joined(separator: ", ") + " }"
}

private let mermaidDarkThemeVariables = mermaidThemeVariables(isDark: true)
private let mermaidLightThemeVariables = mermaidThemeVariables(isDark: false)

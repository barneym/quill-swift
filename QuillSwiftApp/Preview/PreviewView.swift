import SwiftUI
import WebKit

/// A SwiftUI wrapper around WKWebView for displaying rendered markdown preview.
///
/// The preview is read-only and supports:
/// - Rendered HTML content
/// - Light/dark theme following system appearance
/// - User-customizable font size, line height, and CSS
/// - Clickable links that open in the default browser
/// - Scroll sync with source editor
/// - Clickable checkboxes that update source markdown
struct PreviewView: NSViewRepresentable {

    // MARK: - Properties

    /// The HTML content to display
    let html: String

    /// The base URL for resolving relative links (typically document directory)
    let baseURL: URL?

    /// The CSS theme to apply
    let theme: PreviewTheme

    /// User font size override (from ThemeManager)
    var fontSize: CGFloat?

    /// User line height override (from ThemeManager)
    var lineHeight: CGFloat?

    /// User custom CSS (from ThemeManager)
    var customCSS: String?

    /// Optional callback to receive webView reference for scroll sync
    var onWebViewReady: ((WKWebView) -> Void)?

    /// Callback when a checkbox is toggled (checkbox index, new checked state)
    var onCheckboxToggle: ((Int, Bool) -> Void)?

    /// Enable Mermaid diagram rendering
    var enableMermaid: Bool = false

    /// Enable Math/LaTeX rendering
    var enableMath: Bool = false

    /// Called after each page load completes (scroll sync, find re-run)
    var onLoadFinished: ((WKWebView) -> Void)?

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Enable JavaScript for internal scroll sync commands
        // Navigation security is handled by the navigation delegate
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        // Prevent arbitrary network requests
        configuration.websiteDataStore = .nonPersistent()

        // Add script message handler for checkbox toggling
        let contentController = configuration.userContentController
        contentController.add(context.coordinator, name: "checkboxToggle")

        // Page helpers: scroll sync, in-page find, and clean clipboard HTML
        for script in [ScrollSync.previewScript, PreviewScripts.find, PreviewScripts.cleanCopy] {
            contentController.addUserScript(
                WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)

        // Set up navigation delegate for link handling
        webView.navigationDelegate = context.coordinator

        // Disable scrolling bounce for cleaner feel
        webView.enclosingScrollView?.hasVerticalScroller = true

        // Allow inspector for debugging during development
        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif

        // Store reference in coordinator for scroll sync
        context.coordinator.webView = webView

        // Store the callbacks
        context.coordinator.onCheckboxToggle = onCheckboxToggle
        context.coordinator.onLoadFinished = onLoadFinished

        // Notify parent of webView for scroll sync
        DispatchQueue.main.async {
            onWebViewReady?(webView)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onCheckboxToggle = onCheckboxToggle
        context.coordinator.onLoadFinished = onLoadFinished

        let fullHTML = theme.wrapHTML(
            html,
            fontSize: fontSize,
            lineHeight: lineHeight,
            customCSS: customCSS,
            enableMermaid: enableMermaid,
            enableMath: enableMath
        )

        // Only reload if content has actually changed
        // This prevents scroll position reset on unrelated SwiftUI updates
        guard fullHTML != context.coordinator.lastLoadedHTML else {
            return
        }

        // Capture current scroll position before reloading
        webView.evaluateJavaScript("window.pageYOffset || document.documentElement.scrollTop") { result, _ in
            if let offset = result as? CGFloat, offset > 0 {
                context.coordinator.pendingScrollOffset = offset
            }
        }

        // Store the new HTML and reload
        context.coordinator.lastLoadedHTML = fullHTML
        webView.loadHTMLString(fullHTML, baseURL: baseURL)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    /// Handles navigation events, link clicks, and checkbox interactions
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

        /// Reference to the webView for scroll sync
        weak var webView: WKWebView?

        /// Last loaded HTML to detect changes
        var lastLoadedHTML: String?

        /// Pending scroll position to restore after load
        var pendingScrollOffset: CGFloat?

        /// Callback for checkbox toggle events
        var onCheckboxToggle: ((Int, Bool) -> Void)?

        /// Callback after a page load completes
        var onLoadFinished: ((WKWebView) -> Void)?

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "checkboxToggle",
                  let body = message.body as? [String: Any],
                  let index = body["index"] as? Int,
                  let checked = body["checked"] as? Bool else {
                return
            }

            // Notify the parent view of the checkbox toggle
            DispatchQueue.main.async { [weak self] in
                self?.onCheckboxToggle?(index, checked)
            }
        }

        // MARK: - WKNavigationDelegate

        /// Restore scroll position after page finishes loading
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Restore scroll position if we have one pending
            if let offset = pendingScrollOffset, offset > 0 {
                // Small delay to ensure content is laid out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    webView.evaluateJavaScript("window.scrollTo(0, \(offset));", completionHandler: nil)
                    self?.pendingScrollOffset = nil
                }
            }
            onLoadFinished?(webView)
        }

        /// Handle link clicks - open external links in default browser
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow initial page load
            guard navigationAction.navigationType == .linkActivated else {
                decisionHandler(.allow)
                return
            }

            // Get the URL being navigated to
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            // Handle different URL schemes
            switch url.scheme?.lowercased() {
            case "http", "https":
                // Open external links in default browser
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)

            case "mailto":
                // Open mail links in default mail client
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)

            case "file":
                // Handle local file links
                handleLocalFileLink(url, webView: webView)
                decisionHandler(.cancel)

            case nil:
                // Fragment-only links (anchors) - allow navigation
                if url.absoluteString.hasPrefix("#") {
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                }

            default:
                // Block other schemes for security
                decisionHandler(.cancel)
            }
        }

        /// Handle clicks on local file links
        /// Open a `file:` link like Obsidian: markdown in QuillSwift, folders in
        /// Finder, other files in their default app.
        ///
        /// Everything goes through Launch Services, which grants the sandbox
        /// access to the target. Checking the path ourselves first (the old
        /// `fileExists` guard) fails in the sandbox for anything the user hasn't
        /// opened, e.g. a folder on a NAS share, so those clicks did nothing.
        private func handleLocalFileLink(_ url: URL, webView: WKWebView) {
            let ext = url.pathExtension.lowercased()
            if ["md", "markdown", "mdown", "mkd", "mkdn"].contains(ext) {
                NSWorkspace.shared.open(
                    [url],
                    withApplicationAt: Bundle.main.bundleURL,
                    configuration: NSWorkspace.OpenConfiguration()
                ) { _, error in
                    if let error { Self.reportUnopenable(url, error: error) }
                }
            } else {
                NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                    if let error { Self.reportUnopenable(url, error: error) }
                }
            }
        }

        private static func reportUnopenable(_ url: URL, error: Error) {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Couldn’t open “\(url.lastPathComponent)”."
                alert.informativeText = "\(url.path)\n\n\(error.localizedDescription)"
                alert.runModal()
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when a markdown file link is clicked in preview
    static let openMarkdownFile = Notification.Name("openMarkdownFile")
}

// MARK: - Preview

#Preview {
    PreviewView(
        html: """
        <h1>Hello World</h1>
        <p>This is a <strong>test</strong> preview with <em>formatting</em>.</p>
        <ul>
            <li>Item 1</li>
            <li>Item 2</li>
        </ul>
        <pre><code>let x = 5</code></pre>
        """,
        baseURL: nil,
        theme: PreviewTheme.default
    )
    .frame(width: 600, height: 400)
}

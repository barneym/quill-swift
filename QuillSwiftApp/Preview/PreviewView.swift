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
        contentController.add(context.coordinator, name: "openLocalLink")

        // Page helpers: scroll sync, in-page find, and clean clipboard HTML
        for script in [ScrollSync.previewScript, PreviewScripts.find, PreviewScripts.cleanCopy, PreviewScripts.localLinks] {
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
            if message.name == "openLocalLink" {
                guard let string = message.body as? String, let url = URL(string: string), url.isFileURL else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let webView = self?.webView else { return }
                    self?.handleLocalFileLink(url, webView: webView)
                }
                return
            }
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
        /// Open a `file:` link: markdown in QuillSwift, folders in Finder, other
        /// files in their default app.
        ///
        /// QuillSwift is sandboxed, so it can only open paths the user has opened
        /// or picked. Markdown links therefore go through History's bookmark when
        /// there is one, then a direct open, then an Open panel at the file (one
        /// click grants access). Anything else that the sandbox won't open is
        /// shown in Finder instead, which always works.
        private func handleLocalFileLink(_ url: URL, webView: WKWebView) {
            let ext = url.pathExtension.lowercased()
            if ["md", "markdown", "mdown", "mkd", "mkdn"].contains(ext) {
                Task { @MainActor in
                    if let entry = HistoryStore.shared.entries.first(where: { $0.path == url.path && $0.bookmark != nil }) {
                        HistoryStore.shared.open(entry)
                        return
                    }
                    NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                        if error != nil {
                            DispatchQueue.main.async { Self.askToOpen(url) }
                        }
                    }
                }
            } else {
                NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                    if error != nil {
                        DispatchQueue.main.async { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    }
                }
            }
        }

        /// Ask the user to confirm a markdown file the sandbox can't open yet.
        private static func askToOpen(_ url: URL) {
            let panel = NSOpenPanel()
            panel.directoryURL = url.deletingLastPathComponent()
            panel.message = "Select “\(url.lastPathComponent)” and click Open to let QuillSwift open it."
            panel.prompt = "Open"
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let chosen = panel.url else { return }
            NSDocumentController.shared.openDocument(withContentsOf: chosen, display: true) { _, _, _ in }
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
